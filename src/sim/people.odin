package sim

person_at :: proc(w: ^World, id: i32) -> ^Person {
	if id < 0 || int(id) >= int(w.person_count) {
		return nil
	}
	return &w.people[id]
}

life_stage :: proc(p: ^Person) -> Life_Stage {
	if p == nil || !p.alive {
		return .Elder
	}
	y := p.age_days / DAYS_PER_YEAR
	switch {
	case y < YEARS_INFANT:
		return .Infant
	case y < YEARS_CHILD:
		return .Child
	case y < YEARS_YOUTH:
		return .Youth
	case y < YEARS_ELDER:
		return .Adult
	}
	return .Elder
}

life_stage_name :: proc(s: Life_Stage) -> string {
	switch s {
	case .Infant: return "infant"
	case .Child:  return "child"
	case .Youth:  return "youth"
	case .Adult:  return "adult"
	case .Elder:  return "elder"
	}
	return "?"
}

sex_name :: proc(s: Sex) -> string {
	switch s {
	case .Male:   return "man"
	case .Female: return "woman"
	}
	return "?"
}

age_years :: proc(p: ^Person) -> i32 {
	if p == nil do return 0
	return p.age_days / DAYS_PER_YEAR
}

// Mouths to feed, as a fraction of one adult daily nutrition. 1000 = 1 adult.
person_need_milli :: proc(p: ^Person) -> i32 {
	if p == nil || !p.alive {
		return 0
	}
	base: i32
	switch life_stage(p) {
	case .Infant:
		base = 400
	case .Child:
		base = 700
	case .Youth:
		base = 900
	case .Adult:
		base = 1000
	case .Elder:
		base = 850
	}
	if p.pregnant {
		base = base * 12 / 10
	}
	return base
}

person_nutrition_need :: proc(w: ^World, p: ^Person) -> i64 {
	return w.cfg.nutrition_per_day * i64(person_need_milli(p)) / 1000
}

household_daily_need :: proc(w: ^World, h: ^Household) -> i64 {
	s: i64
	for i: i32 = 0; i < h.member_count; i += 1 {
		p := person_at(w, h.members[i])
		if p != nil && p.alive {
			s += person_nutrition_need(w, p)
		}
	}
	if s <= 0 {
		return w.cfg.nutrition_per_day
	}
	return s
}

household_fuel_need :: proc(w: ^World, h: ^Household) -> i64 {
	n := living_members(w, h)
	extra := n - 2
	if extra < 0 do extra = 0
	return w.cfg.fuel_per_day + i64(extra) * 80
}

living_members :: proc(w: ^World, h: ^Household) -> i32 {
	n: i32
	for i: i32 = 0; i < h.member_count; i += 1 {
		p := person_at(w, h.members[i])
		if p != nil && p.alive {
			n += 1
		}
	}
	return n
}

work_blocks_for :: proc(p: ^Person) -> i32 {
	if p == nil || !p.alive {
		return 0
	}
	switch life_stage(p) {
	case .Infant, .Child:
		return 0
	case .Youth, .Elder:
		return 1
	case .Adult:
		if p.pregnant && p.pregnancy_days > PREGNANCY_DAYS - 60 {
			return 1
		}
		if p.health < 3500 {
			return 1
		}
		return 2
	}
	return 0
}

can_work :: proc(p: ^Person) -> bool {
	return work_blocks_for(p) > 0
}

// Cap on work + walking + visiting for the day. Sleep and home time are separate.
work_minutes_cap :: proc(cfg: Config, p: ^Person) -> i32 {
	blocks := work_blocks_for(p)
	if blocks <= 0 {
		return 0
	}
	cap := cfg.labor_minutes
	if blocks == 1 {
		cap = cap * 6 / 10
	}
	if p.health < 5000 && blocks == 2 {
		cap = cap * 8 / 10
	}
	if cap < 120 {
		cap = 120
	}
	return cap
}

person_sleep_minutes :: proc(cfg: Config, p: ^Person) -> i32 {
	if p == nil || !p.alive {
		return cfg.sleep_base
	}
	s := cfg.sleep_base
	switch life_stage(p) {
	case .Infant:
		s = cfg.sleep_base + 240
	case .Child:
		s = cfg.sleep_base + 120
	case .Youth:
		s += cfg.sleep_youth_extra
	case .Adult:
	case .Elder:
		s += cfg.sleep_elder_extra
	}
	if p.health < 4000 {
		s += cfg.sleep_sick_extra
	} else if p.health < 6000 {
		s += cfg.sleep_sick_extra / 2
	}
	if p.pregnant && p.pregnancy_days > PREGNANCY_DAYS - 90 {
		s += 60
	}
	day := cfg.day_minutes
	if day <= 0 do day = DAY_MINUTES
	if s < 360 do s = 360
	if s > day - 240 do s = day - 240
	if s < 0 do s = 0
	return s
}

// Wake after the night portion of sleep; sleep_start is when they must be home.
person_wake_window :: proc(cfg: Config, p: ^Person) -> (wake, sleep_start: i32) {
	day := cfg.day_minutes
	if day <= 0 do day = DAY_MINUTES
	sleep := person_sleep_minutes(cfg, p)
	pre := sleep * 3 / 4
	wake = pre
	sleep_start = day - (sleep - pre)
	if sleep_start <= wake + 240 {
		sleep_start = wake + 240
		if sleep_start > day {
			sleep_start = day
		}
	}
	return
}

// Walking speeds stay close; distance is what makes trips long.
person_walk_speed_bp :: proc(p: ^Person) -> i32 {
	if p == nil || !p.alive {
		return BP_SCALE
	}
	sp: i32 = 10000
	switch life_stage(p) {
	case .Infant, .Child:
		sp = 7000
	case .Youth:
		sp = 9200
	case .Adult:
		sp = 10000
	case .Elder:
		sp = 8200
	}
	con := clamp_i32(p.constitution, 8000, 12000)
	sp = sp * con / 10000
	if p.health < 5000 {
		sp = sp * (5000 + p.health) / 10000
	}
	if p.pregnant && p.pregnancy_days > PREGNANCY_DAYS - 90 {
		sp = sp * 78 / 100
	}
	return clamp_i32(sp, 5500, 12000)
}

person_walk_minutes :: proc(cfg: Config, p: ^Person, ax, ay, bx, by: i32) -> i32 {
	return walk_minutes(cfg, ax, ay, bx, by, person_walk_speed_bp(p))
}

apply_travel_fatigue :: proc(w: ^World, p: ^Person) {
	if p == nil || !p.alive {
		return
	}
	extra := p.minutes_travel - w.cfg.travel_fatigue_after
	if extra <= 0 {
		return
	}
	per := w.cfg.travel_fatigue_per
	if per < 1 do per = 1
	loss := extra / per
	if life_stage(p) == .Elder {
		loss = loss + loss / 2
	}
	if p.health > loss + 1 {
		p.health -= loss
	} else if p.health > 1 {
		p.health = 1
	}
}

member_slot_of :: proc(h: ^Household, id: i32) -> i32 {
	if h == nil {
		return 0
	}
	for s: i32 = 0; s < h.member_count; s += 1 {
		if h.members[s] == id {
			return s
		}
	}
	return 0
}

person_home_milli :: proc(h: ^Household, p: ^Person) -> (i32, i32) {
	return member_home_milli(h, member_slot_of(h, p.id))
}

actor_skill :: proc(h: ^Household, p: ^Person, k: Skill_Kind) -> i32 {
	if p != nil {
		return p.skills[k]
	}
	return h.skills[k]
}

map_milli :: proc(cell: Vec2i) -> (i32, i32) {
	return cell.x * 1000, cell.y * 1000
}

member_home_milli :: proc(h: ^Household, slot: i32) -> (i32, i32) {
	hx, hy := map_milli(h.home)
	// Spread living walkers around the hut so they do not stack.
	ox := ((slot % 3) - 1) * 220
	oy := ((slot / 3) % 3 - 1) * 180
	return hx + ox, hy + oy
}

path_reset :: proc(p: ^Person, x, y: i32) {
	p.path_n = 1
	p.path[0] = Path_Pt{x = x, y = y, t = 0, doing = .Sleep, activity = .Rest}
	p.trade_hh = -1
}

path_free_slot :: proc(p: ^Person) {
	if p.path_n < PATH_MAX {
		return
	}
	// Drop one redundant hold (same cell, later t wins) so a new keyframe fits.
	for i: i32 = 1; i < p.path_n; i += 1 {
		if p.path[i].x == p.path[i - 1].x && p.path[i].y == p.path[i - 1].y {
			p.path[i - 1].t = p.path[i].t
			for j: i32 = i; j < p.path_n - 1; j += 1 {
				p.path[j] = p.path[j + 1]
			}
			p.path_n -= 1
			return
		}
	}
	p.path_n = PATH_MAX - 1
}

path_push :: proc(p: ^Person, x, y, t: i32, doing: Person_Doing = .At_Home, activity: Activity = .Rest) {
	if p.path_n <= 0 {
		path_reset(p, x, y)
		p.path[0].t = t
		p.path[0].doing = doing
		p.path[0].activity = activity
		return
	}
	last := p.path[p.path_n - 1]
	tt := t
	if tt < last.t {
		tt = last.t
	}
	if last.x == x && last.y == y && tt == last.t && last.doing == doing {
		return
	}
	if p.path_n >= PATH_MAX {
		path_free_slot(p)
	}
	if p.path_n >= PATH_MAX {
		p.path[PATH_MAX - 1] = Path_Pt{x = x, y = y, t = tt, doing = doing, activity = activity}
		return
	}
	p.path[p.path_n] = Path_Pt{x = x, y = y, t = tt, doing = doing, activity = activity}
	p.path_n += 1
}

person_now :: proc(p: ^Person, u: f32, world_sum: f32 = 0) -> (doing: Person_Doing, activity: Activity, walking: bool) {
	doing = .Sleep
	activity = .Rest
	if p == nil || p.path_n <= 0 {
		return
	}
	_, _, rt := person_at_view_u(p, u, world_sum)
	t := i32(rt + 0.5)
	if t <= p.path[0].t || p.path_n == 1 {
		return p.path[0].doing, p.path[0].activity, false
	}
	for i: i32 = 1; i < p.path_n; i += 1 {
		b := p.path[i]
		a := p.path[i - 1]
		if t <= b.t {
			dist := octile_milli(a.x, a.y, b.x, b.y)
			if dist > VIEW_SAME_DIST {
				return .Walking, b.activity, true
			}
			return b.doing, b.activity, false
		}
	}
	last := p.path[p.path_n - 1]
	return last.doing, last.activity, false
}

lerp_i32 :: proc(a, b, s, span: i32) -> i32 {
	if span <= 0 {
		return b
	}
	return a + i32((i64(b) - i64(a)) * i64(s) / i64(span))
}

lerp_f32 :: proc(a, b, s, span: f32) -> f32 {
	if span <= 0 {
		return b
	}
	return a + (b - a) * (s / span)
}

// True sim-minute interpolation (t is 0..10000 through the 1440-minute day).
person_pos_milli :: proc(p: ^Person, t: i32) -> (i32, i32) {
	x, y, _ := person_at_real_t(p, t)
	return x, y
}

person_view_pos_milli :: proc(p: ^Person, vis_t: i32, world_sum: f32 = 0) -> (i32, i32) {
	u := f32(vis_t) / 10000
	x, y, _ := person_at_view_u(p, u, world_sum)
	return i32(x + 0.5), i32(y + 0.5)
}

person_view_pos_f32 :: proc(p: ^Person, u: f32, world_sum: f32 = 0) -> (f32, f32) {
	x, y, _ := person_at_view_u(p, u, world_sum)
	return x, y
}

person_view_real_t :: proc(p: ^Person, vis_t: i32, world_sum: f32 = 0) -> i32 {
	u := f32(vis_t) / 10000
	_, _, rt := person_at_view_u(p, u, world_sum)
	return i32(rt + 0.5)
}

person_view_real_t_u :: proc(p: ^Person, u: f32, world_sum: f32 = 0) -> i32 {
	_, _, rt := person_at_view_u(p, u, world_sum)
	return i32(rt + 0.5)
}

VIEW_MOVE_PER_CELL :: f32(620)
VIEW_MIN_MOVE :: f32(400)
VIEW_MIN_HOLD :: f32(90)
VIEW_STILL_SCALE :: f32(0.16)
VIEW_SAME_DIST :: i32(280)

person_at_real_t :: proc(p: ^Person, t: i32) -> (x, y, real_t: i32) {
	if p == nil || p.path_n <= 0 {
		return 0, 0, 0
	}
	if p.path_n == 1 || t <= p.path[0].t {
		return p.path[0].x, p.path[0].y, p.path[0].t
	}
	for i: i32 = 1; i < p.path_n; i += 1 {
		b := p.path[i]
		a := p.path[i - 1]
		if t <= b.t {
			span := b.t - a.t
			s := t - a.t
			return lerp_i32(a.x, b.x, s, span), lerp_i32(a.y, b.y, s, span), lerp_i32(a.t, b.t, s, span)
		}
	}
	last := p.path[p.path_n - 1]
	return last.x, last.y, last.t
}

// Collapse hut-scatter / duplicate holds so playback is walk → stand → walk,
// not a chain of one-frame twitches.
collapse_path :: proc(p: ^Person, out: []Path_Pt) -> i32 {
	if p == nil || p.path_n <= 0 {
		return 0
	}
	n: i32 = 0
	for i: i32 = 0; i < p.path_n; i += 1 {
		pt := p.path[i]
		if n > 0 {
			last := out[n - 1]
			dist := octile_milli(last.x, last.y, pt.x, pt.y)
			if dist <= VIEW_SAME_DIST {
				if n >= 2 {
					prev := out[n - 2]
					if octile_milli(prev.x, prev.y, last.x, last.y) <= VIEW_SAME_DIST {
						out[n - 1] = pt
						out[n - 1].x = last.x
						out[n - 1].y = last.y
						continue
					}
				}
				pt.x = last.x
				pt.y = last.y
				out[n] = pt
				n += 1
				continue
			}
		}
		out[n] = pt
		n += 1
		if n >= i32(len(out)) {
			break
		}
	}
	return n
}

view_seg_weight :: proc(a, b: Path_Pt) -> f32 {
	dist := octile_milli(a.x, a.y, b.x, b.y)
	dt := b.t - a.t
	if dt < 0 do dt = 0
	if dist > VIEW_SAME_DIST {
		wt := f32(dist) * VIEW_MOVE_PER_CELL / 1000
		if wt < VIEW_MIN_MOVE do wt = VIEW_MIN_MOVE
		return wt
	}
	wt := f32(dt) * VIEW_STILL_SCALE
	if dt > 0 && wt < VIEW_MIN_HOLD do wt = VIEW_MIN_HOLD
	if wt < 1 do wt = 1
	return wt
}

person_view_sum :: proc(p: ^Person) -> f32 {
	if p == nil || p.path_n <= 0 {
		return 0
	}
	pts: [PATH_MAX]Path_Pt
	n := collapse_path(p, pts[:])
	if n <= 1 {
		return 0
	}
	sum: f32
	for i: i32 = 0; i < n - 1; i += 1 {
		sum += view_seg_weight(pts[i], pts[i + 1])
	}
	return sum
}

world_view_scale :: proc(w: ^World) -> f32 {
	if w == nil {
		return 1
	}
	best: f32 = 1
	for i: i32 = 0; i < w.person_count; i += 1 {
		p := &w.people[i]
		if !p.alive do continue
		s := person_view_sum(p)
		if s > best do best = s
	}
	return best
}

person_at_view_u :: proc(p: ^Person, u: f32, world_sum: f32 = 0) -> (x, y, real_t: f32) {
	if p == nil || p.path_n <= 0 {
		return 0, 0, 0
	}
	uu := u
	if uu < 0 do uu = 0
	if uu > 1 do uu = 1

	pts: [PATH_MAX]Path_Pt
	n := collapse_path(p, pts[:])
	if n <= 0 {
		return 0, 0, 0
	}
	if n == 1 || uu <= 0 {
		a := pts[0]
		return f32(a.x), f32(a.y), f32(a.t)
	}

	wts: [PATH_MAX]f32
	sum: f32
	seg := n - 1
	for i: i32 = 0; i < seg; i += 1 {
		wts[i] = view_seg_weight(pts[i], pts[i + 1])
		sum += wts[i]
	}
	if sum <= 0 {
		a := pts[0]
		return f32(a.x), f32(a.y), f32(a.t)
	}

	scale := world_sum
	if scale < sum {
		scale = sum
	}
	target := uu * scale
	if target >= sum {
		last := pts[n - 1]
		return f32(last.x), f32(last.y), f32(last.t)
	}
	acc: f32
	for i: i32 = 0; i < seg; i += 1 {
		next := acc + wts[i]
		if target <= next || i == seg - 1 {
			span := wts[i]
			s := target - acc
			if s < 0 do s = 0
			if s > span do s = span
			a := pts[i]
			b := pts[i + 1]
			return lerp_f32(f32(a.x), f32(b.x), s, span), lerp_f32(f32(a.y), f32(b.y), s, span), lerp_f32(f32(a.t), f32(b.t), s, span)
		}
		acc = next
	}
	last := pts[n - 1]
	return f32(last.x), f32(last.y), f32(last.t)
}

init_person_skills :: proc(w: ^World, p: ^Person) {
	for s in 0 ..< SKILL_COUNT {
		p.skills[s] = rng_range_i32(&w.rng, w.cfg.skill_start_min, w.cfg.skill_start_max)
	}
	side := rng_range_i32(&w.rng, w.cfg.gender_side_bonus_min, w.cfg.gender_side_bonus_max)
	switch p.sex {
	case .Male:
		p.skills[Skill_Kind.Hunt] += rng_range_i32(&w.rng, w.cfg.male_hunt_bonus_min, w.cfg.male_hunt_bonus_max)
		p.skills[Skill_Kind.Stone] += side
		p.skills[Skill_Kind.Forage] -= side / 2
	case .Female:
		p.skills[Skill_Kind.Forage] += rng_range_i32(&w.rng, w.cfg.female_forage_bonus_min, w.cfg.female_forage_bonus_max)
		p.skills[Skill_Kind.Craft] += side
		p.skills[Skill_Kind.Hunt] -= side / 2
	}
	boost_i := rng_range_i32(&w.rng, 0, SKILL_COUNT - 1)
	boost := rng_range_i32(&w.rng, w.cfg.skill_boost_min, w.cfg.skill_boost_max)
	p.skills[boost_i] += boost
	for s in 0 ..< SKILL_COUNT {
		p.skills[s] = clamp_i32(p.skills[s], w.cfg.skill_min, w.cfg.skill_max)
	}
}

spawn_person :: proc(w: ^World, h: ^Household, sex: Sex, age_days, health, constitution: i32) -> i32 {
	if h.member_count >= MAX_MEMBERS {
		return -1
	}
	if int(w.person_count) >= len(w.people) {
		return -1
	}
	id := w.person_count
	p := &w.people[id]
	w.person_count += 1
	p^ = Person{}
	p.id = id
	p.household = h.id
	p.sex = sex
	p.alive = true
	p.age_days = age_days
	p.constitution = clamp_i32(constitution, 4000, HEALTH_MAX)
	p.health = clamp_i32(health, 1, HEALTH_MAX)
	p.intent_activity = .Rest
	p.intent_cell = h.home
	p.intent_partner = -1
	p.trade_hh = -1
	p.father_id = -1
	p.mother_id = -1
	p.spouse_id = -1
	p.natal_household = h.id
	init_person_skills(w, p)
	slot := h.member_count
	h.members[slot] = id
	h.member_count += 1
	hx, hy := member_home_milli(h, slot)
	path_reset(p, hx, hy)
	path_push(p, hx, hy, 10000)
	return id
}

sync_household_from_members :: proc(w: ^World, h: ^Household) {
	if h == nil || !h.exists {
		return
	}
	n := i32(0)
	for i: i32 = 0; i < h.member_count; i += 1 {
		p := person_at(w, h.members[i])
		if p != nil && p.alive {
			h.members[n] = h.members[i]
			n += 1
		}
	}
	h.member_count = n
	n_live := living_members(w, h)
	if n_live <= 0 {
		if h.alive {
			kill_household(w, h)
		}
		return
	}
	h.alive = true
	sum_h: i32
	sum_sk: [SKILL_COUNT]i32
	n_sk: i32
	for i: i32 = 0; i < h.member_count; i += 1 {
		p := person_at(w, h.members[i])
		if p == nil || !p.alive do continue
		sum_h += p.health
		if work_blocks_for(p) > 0 {
			for s in 0 ..< SKILL_COUNT {
				sum_sk[s] += p.skills[s]
			}
			n_sk += 1
		}
	}
	h.health = sum_h / n_live
	if n_sk > 0 {
		for s in 0 ..< SKILL_COUNT {
			h.skills[s] = sum_sk[s] / n_sk
		}
	}
	need := household_daily_need(w, h)
	h.preferred_food_nutrition = need * i64(h.pref_days_milli) / 1000
}

kill_person :: proc(w: ^World, p: ^Person) {
	if p == nil || !p.alive {
		return
	}
	p.alive = false
	p.health = 0
	p.pregnant = false
	w.acc.deaths += 1
	w.total_deaths += 1
	push_event(w, Event{kind = .Person_Died, h1 = p.household, h2 = p.id, qty_a = i64(p.age_days)})
	h := &w.households[p.household]
	sync_household_from_members(w, h)
}

learn_person_skill :: proc(w: ^World, p: ^Person, sk: Skill_Kind) {
	if p == nil || !p.alive do return
	p.skills[sk] = clamp_i32(p.skills[sk] + w.cfg.learning_bp, w.cfg.skill_min, w.cfg.skill_max)
}

age_and_health_environment :: proc(w: ^World, p: ^Person, food_got, food_need: i64, fuel_ok: bool) {
	if p == nil || !p.alive {
		return
	}
	dh: i32
	if food_need <= 0 || food_got >= food_need {
		dh += w.cfg.health_recover
	} else if food_got > 0 {
		dh += w.cfg.health_partial_food
	} else {
		dh += w.cfg.health_no_food
	}
	st := life_stage(p)
	if st == .Infant && food_got < food_need {
		dh = dh * 3 / 2
	}
	if st == .Child && food_got <= 0 {
		dh = dh * 5 / 4
	}
	if !fuel_ok {
		dh += w.cfg.health_no_fuel
	}
	years := age_years(p)
	if years >= w.cfg.age_frailty_start_year {
		dh -= (years - w.cfg.age_frailty_start_year) * 4
	}
	if years >= 70 {
		dh -= (years - 70) * 8
	}
	// Drift toward inherited constitution when fed.
	if dh > 0 && p.health > p.constitution {
		dh = dh / 2
	}
	p.health = clamp_i32(p.health + dh, 0, HEALTH_MAX)
	if p.health <= 0 {
		kill_person(w, p)
	}
}

pick_father :: proc(w: ^World, h: ^Household, mother_id: i32) -> i32 {
	best: i32 = -1
	best_age: i32 = -1
	for i: i32 = 0; i < h.member_count; i += 1 {
		p := person_at(w, h.members[i])
		if p == nil || !p.alive || p.id == mother_id do continue
		if p.sex != .Male do continue
		if life_stage(p) == .Infant || life_stage(p) == .Child do continue
		if p.age_days > best_age {
			best_age = p.age_days
			best = p.id
		}
	}
	return best
}

try_conceive :: proc(w: ^World, h: ^Household) {
	if !h.alive || h.member_count >= w.cfg.max_members {
		return
	}
	if living_members(w, h) >= w.cfg.max_members {
		return
	}
	need := household_daily_need(w, h)
	days := food_days_milli(nutrition_of(h.inv, w.cfg), need)
	food_f: i32
	switch {
	case days < 1000:
		return
	case days < 2000:
		food_f = 3000
	case days < 3000:
		food_f = 7000
	case:
		food_f = 10000
	}

	for i: i32 = 0; i < h.member_count; i += 1 {
		m := person_at(w, h.members[i])
		if m == nil || !m.alive || m.sex != .Female || m.pregnant {
			continue
		}
		y := age_years(m)
		if y < YEARS_FERTILE_MIN || y > YEARS_FERTILE_MAX {
			continue
		}
		if m.health < 5000 {
			continue
		}
		if !has_living_spouse(w, m) {
			continue
		}
		fid := m.spouse_id
		f := person_at(w, fid)
		if f == nil || !f.alive || f.sex != .Male || f.household != m.household || f.health < 4000 {
			continue
		}
		bp := w.cfg.conceive_bp
		bp = i32(i64(bp) * i64(m.health) / i64(HEALTH_MAX) * i64(f.health) / i64(HEALTH_MAX) * i64(food_f) / 10000)
		if bp < 1 do continue
		if rng_chance_bp(&w.rng, bp) {
			m.pregnant = true
			m.pregnancy_days = 0
			m.preg_food_days_acc = 0
			m.preg_days_counted = 0
		}
	}
}

finish_pregnancy :: proc(w: ^World, h: ^Household, mother: ^Person) {
	mother.pregnant = false
	days_c := mother.preg_days_counted
	avg_food: i64 = 2000
	if days_c > 0 {
		avg_food = mother.preg_food_days_acc / i64(days_c)
	}
	mother.pregnancy_days = 0
	if h.member_count >= MAX_MEMBERS || int(w.person_count) >= len(w.people) {
		return
	}
	father_con: i32 = mother.constitution
	dad := person_at(w, mother.spouse_id)
	if dad != nil {
		father_con = dad.constitution
	}
	inherited := (mother.constitution * 7 + father_con * 7) / 20
	rnd := rng_range_i32(&w.rng, 7000, 13000)
	con := (inherited * 7 + rnd * 3) / 10
	nut_mod: i32
	switch {
	case avg_food < 1000:
		nut_mod = -2200
	case avg_food < 2000:
		nut_mod = -900
	case avg_food < 3000:
		nut_mod = -200
	case avg_food > 4500:
		nut_mod = 400
	}
	jitter := rng_range_i32(&w.rng, -700, 700)
	health := clamp_i32(con + nut_mod + jitter, 1500, HEALTH_MAX)
	sex: Sex = .Male
	if rng_chance_bp(&w.rng, 5000) {
		sex = .Female
	}
	cid := spawn_person(w, h, sex, 0, health, con)
	if cid < 0 {
		return
	}
	child := person_at(w, cid)
	if child != nil {
		child.mother_id = mother.id
		if dad != nil {
			child.father_id = dad.id
		}
		child.natal_household = h.id
	}
	w.acc.births += 1
	push_event(w, Event{kind = .Person_Born, h1 = h.id, h2 = cid, qty_a = i64(health), qty_b = avg_food})
}

tick_people :: proc(w: ^World) {
	for i: i32 = 0; i < w.person_count; i += 1 {
		p := &w.people[i]
		if !p.alive do continue
		p.age_days += 1
		h := &w.households[p.household]
		if p.pregnant && p.alive {
			p.pregnancy_days += 1
			if p.pregnancy_days >= w.cfg.pregnancy_days {
				finish_pregnancy(w, h, p)
			}
		}
	}
}

first_mobile_member :: proc(w: ^World, h: ^Household) -> i32 {
	for i: i32 = 0; i < h.member_count; i += 1 {
		p := person_at(w, h.members[i])
		if p != nil && p.alive && work_blocks_for(p) > 0 {
			return p.id
		}
	}
	return -1
}

package sim

has_living_spouse :: proc(w: ^World, p: ^Person) -> bool {
	if p == nil || p.spouse_id < 0 {
		return false
	}
	s := person_at(w, p.spouse_id)
	return s != nil && s.alive
}

is_marriageable :: proc(w: ^World, p: ^Person) -> bool {
	if p == nil || !p.alive || has_living_spouse(w, p) {
		return false
	}
	if p.health < 4000 {
		return false
	}
	y := age_years(p)
	switch p.sex {
	case .Male:
		return y >= w.cfg.marry_age_male_min && y <= w.cfg.marry_age_male_max
	case .Female:
		return y >= w.cfg.marry_age_female_min && y <= w.cfg.marry_age_female_max
	}
	return false
}

share_a_parent :: proc(a, b: ^Person) -> bool {
	if a == nil || b == nil || a.id == b.id {
		return false
	}
	if a.father_id >= 0 && a.father_id == b.father_id {
		return true
	}
	if a.mother_id >= 0 && a.mother_id == b.mother_id {
		return true
	}
	return false
}

is_parent_child :: proc(a, b: ^Person) -> bool {
	if a == nil || b == nil {
		return false
	}
	return a.father_id == b.id || a.mother_id == b.id || b.father_id == a.id || b.mother_id == a.id
}

is_avuncular :: proc(w: ^World, a, b: ^Person) -> bool {
	if w == nil || a == nil || b == nil {
		return false
	}
	check :: proc(w: ^World, person, maybe_uncle: ^Person) -> bool {
		if person == nil || maybe_uncle == nil {
			return false
		}
		fa := person_at(w, person.father_id)
		if fa != nil && maybe_uncle.id != fa.id && share_a_parent(maybe_uncle, fa) {
			return true
		}
		mo := person_at(w, person.mother_id)
		if mo != nil && maybe_uncle.id != mo.id && share_a_parent(maybe_uncle, mo) {
			return true
		}
		return false
	}
	return check(w, a, b) || check(w, b, a)
}

is_first_cousin :: proc(w: ^World, a, b: ^Person) -> bool {
	if w == nil || a == nil || b == nil || a.id == b.id {
		return false
	}
	pa := [2]^Person{person_at(w, a.father_id), person_at(w, a.mother_id)}
	pb := [2]^Person{person_at(w, b.father_id), person_at(w, b.mother_id)}
	for i in 0 ..< 2 {
		for j in 0 ..< 2 {
			x, y := pa[i], pb[j]
			if x == nil || y == nil || x.id == y.id {
				continue
			}
			if share_a_parent(x, y) {
				return true
			}
		}
	}
	return false
}

// Siblings, parent/child, and aunt/uncle–niece/nephew are always forbidden.
// First cousins follow marry_allow_cousins (later a church/law culture knob).
are_close_kin :: proc(w: ^World, a, b: ^Person) -> bool {
	if a == nil || b == nil || a.id == b.id {
		return true
	}
	if is_parent_child(a, b) {
		return true
	}
	if share_a_parent(a, b) {
		return true
	}
	if is_avuncular(w, a, b) {
		return true
	}
	if !w.cfg.marry_allow_cousins && is_first_cousin(w, a, b) {
		return true
	}
	return false
}

link_spouses :: proc(a, b: ^Person) {
	if a == nil || b == nil {
		return
	}
	a.spouse_id = b.id
	b.spouse_id = a.id
}

remove_member :: proc(h: ^Household, pid: i32) {
	n: i32 = 0
	for i: i32 = 0; i < h.member_count; i += 1 {
		if h.members[i] != pid {
			h.members[n] = h.members[i]
			n += 1
		}
	}
	h.member_count = n
}

add_member :: proc(h: ^Household, pid: i32) -> bool {
	if h.member_count >= MAX_MEMBERS {
		return false
	}
	h.members[h.member_count] = pid
	h.member_count += 1
	return true
}

can_host :: proc(w: ^World, h: ^Household, extra: i32) -> bool {
	if h == nil || !h.exists {
		return false
	}
	if !h.alive && living_members(w, h) == 0 {
		return false
	}
	return living_members(w, h) + extra <= w.cfg.max_members && h.member_count + extra <= MAX_MEMBERS
}

combined_goods :: proc(w: ^World, a, b: ^Household, g: Good) -> i64 {
	s: i64
	if a != nil && a.exists {
		s += a.inv.qty[g]
	}
	if b != nil && b.exists && (a == nil || a.id != b.id) {
		s += b.inv.qty[g]
	}
	return s
}

can_afford_hut :: proc(w: ^World, man_h, woman_h: ^Household) -> bool {
	return combined_goods(w, man_h, woman_h, .Wood) >= w.cfg.hut_wood_cost &&
		combined_goods(w, man_h, woman_h, .Stone) >= w.cfg.hut_stone_cost
}

pay_from_two :: proc(a, b: ^Household, g: Good, need: i64) -> bool {
	if need <= 0 {
		return true
	}
	have_a: i64
	have_b: i64
	if a != nil do have_a = a.inv.qty[g]
	if b != nil && (a == nil || b.id != a.id) do have_b = b.inv.qty[g]
	if have_a + have_b < need {
		return false
	}
	from_a := need * have_a / (have_a + have_b)
	if have_b == 0 {
		from_a = need
	}
	from_b := need - from_a
	if a != nil {
		a.inv.qty[g] -= from_a
	}
	if b != nil && (a == nil || b.id != a.id) {
		b.inv.qty[g] -= from_b
	}
	return true
}

home_cell_taken :: proc(w: ^World, x, y: i32, except: i32) -> bool {
	for &h in w.households {
		if !h.exists do continue
		if h.id == except do continue
		if h.home.x == x && h.home.y == y {
			return true
		}
	}
	return false
}

find_new_home_cell :: proc(w: ^World, near_a, near_b: Vec2i) -> (Vec2i, bool) {
	for attempt in 0 ..< 80 {
		src := near_a
		if attempt % 2 == 1 {
			src = near_b
		}
		jx := rng_range_i32(&w.rng, -8, 8)
		jy := rng_range_i32(&w.rng, -8, 8)
		x := clamp_i32(src.x + jx, 1, w.cfg.map_w - 2)
		y := clamp_i32(src.y + jy, 1, w.cfg.map_h - 2)
		if home_cell_taken(w, x, y, -1) {
			continue
		}
		return Vec2i{x, y}, true
	}
	for y: i32 = 1; y < w.cfg.map_h - 1; y += 1 {
		for x: i32 = 1; x < w.cfg.map_w - 1; x += 1 {
			if !home_cell_taken(w, x, y, -1) {
				return Vec2i{x, y}, true
			}
		}
	}
	return {}, false
}

alloc_household :: proc(w: ^World) -> ^Household {
	for i in 0 ..< len(w.households) {
		h := &w.households[i]
		if !h.exists {
			h^ = Household{}
			h.id = i32(i)
			h.exists = true
			return h
		}
	}
	return nil
}

choose_residence :: proc(w: ^World, man, woman: ^Person) -> (Residence, bool) {
	mh := &w.households[man.household]
	wh := &w.households[woman.household]
	wf := w.cfg.residence_father_bp
	wm := w.cfg.residence_mother_bp
	wn := w.cfg.residence_new_bp
	if !can_host(w, mh, 1) {
		wf = 0
	}
	if !can_host(w, wh, 1) {
		wm = 0
	}
	if living_members(w, mh) >= w.cfg.residence_crowd {
		if wf > 0 do wf /= 2
		wn += 2500
	}
	if living_members(w, wh) >= w.cfg.residence_crowd {
		if wm > 0 do wm /= 2
		wn += 1800
	}
	if can_afford_hut(w, mh, wh) {
		wn += 2200
	} else {
		wn /= 3
	}
	if wf < 0 do wf = 0
	if wm < 0 do wm = 0
	if wn < 0 do wn = 0
	total := wf + wm + wn
	if total <= 0 {
		if can_afford_hut(w, mh, wh) {
			return .New, true
		}
		return .Father, false
	}
	pick := rng_range_i32(&w.rng, 1, total)
	if pick <= wf {
		return .Father, true
	}
	if pick <= wf + wm {
		return .Mother, true
	}
	if !can_afford_hut(w, mh, wh) {
		if wf > 0 do return .Father, true
		if wm > 0 do return .Mother, true
		return .Father, false
	}
	return .New, true
}

found_household :: proc(w: ^World, man, woman: ^Person) -> ^Household {
	mh := &w.households[man.household]
	wh := &w.households[woman.household]
	if !can_afford_hut(w, mh, wh) {
		return nil
	}
	cell, ok := find_new_home_cell(w, mh.home, wh.home)
	if !ok {
		return nil
	}
	h := alloc_household(w)
	if h == nil {
		return nil
	}
	if !pay_from_two(mh, wh, .Wood, w.cfg.hut_wood_cost) || !pay_from_two(mh, wh, .Stone, w.cfg.hut_stone_cost) {
		h.exists = false
		h.alive = false
		return nil
	}
	h.alive = true
	h.home = cell
	h.hut_variant = u8(rng_range_i32(&w.rng, 0, 2))
	h.pref_days_milli = (mh.pref_days_milli + wh.pref_days_milli) / 2
	h.trade_openness = (mh.trade_openness + wh.trade_openness) / 2
	h.risk_preference = (mh.risk_preference + wh.risk_preference) / 2
	h.inferred_role = .Generalist
	h.prev_inferred_role = .Generalist
	move_qty :: proc(src: ^Household, dst: ^Household, g: Good, want: i64) {
		if want <= 0 do return
		q := min(src.inv.qty[g], want)
		src.inv.qty[g] -= q
		dst.inv.qty[g] += q
	}
	move_qty(mh, h, .Berries, mh.inv.qty[Good.Berries] / 5)
	move_qty(wh, h, .Berries, wh.inv.qty[Good.Berries] / 5)
	move_qty(mh, h, .Meat, mh.inv.qty[Good.Meat] / 5)
	move_qty(wh, h, .Meat, wh.inv.qty[Good.Meat] / 5)
	move_qty(mh, h, .Wood, max(i64(400), mh.inv.qty[Good.Wood] / 8))
	push_event(w, Event{kind = .Household_Founded, h1 = h.id, h2 = man.id, cell = cell, qty_a = i64(woman.id)})
	return h
}

move_person_to_household :: proc(w: ^World, p: ^Person, dest: ^Household) {
	if p == nil || dest == nil || p.household == dest.id {
		return
	}
	old := &w.households[p.household]
	remove_member(old, p.id)
	if !add_member(dest, p.id) {
		add_member(old, p.id)
		return
	}
	p.household = dest.id
	p.intent_cell = dest.home
	sync_household_from_members(w, old)
	sync_household_from_members(w, dest)
}

settle_marriage :: proc(w: ^World, man, woman: ^Person, place: Residence) -> bool {
	dest: ^Household
	switch place {
	case .Father:
		dest = &w.households[man.household]
		if !can_host(w, dest, 1) {
			return false
		}
		move_person_to_household(w, woman, dest)
	case .Mother:
		dest = &w.households[woman.household]
		if !can_host(w, dest, 1) {
			return false
		}
		move_person_to_household(w, man, dest)
	case .New:
		dest = found_household(w, man, woman)
		if dest == nil {
			return false
		}
		move_person_to_household(w, man, dest)
		move_person_to_household(w, woman, dest)
	}
	link_spouses(man, woman)
	w.acc.marriages += 1
	w.total_marriages += 1
	push_event(w, Event{
		kind = .Married,
		h1 = man.id,
		h2 = woman.id,
		qty_a = i64(dest.id),
		qty_b = i64(u8(place)),
		cell = dest.home,
	})
	// Walk to the new home this afternoon.
	dx, dy := map_milli(dest.home)
	path_push(man, dx, dy, 9000, .Walking, .Rest)
	path_push(woman, dx, dy, 9000, .Walking, .Rest)
	return true
}

pick_marriage_candidate :: proc(w: ^World, p: ^Person) -> i32 {
	best: i32 = -1
	total: u64 = 0
	h := &w.households[p.household]
	for i: i32 = 0; i < w.person_count; i += 1 {
		o := &w.people[i]
		if o.id == p.id || !o.alive do continue
		if o.sex == p.sex do continue
		if !is_marriageable(w, o) do continue
		if are_close_kin(w, p, o) do continue
		oh := &w.households[o.household]
		if !oh.exists || !oh.alive do continue
		milli := octile_milli(h.home.x, h.home.y, oh.home.x, oh.home.y)
		dist := milli / 1000
		if dist > w.cfg.marry_radius {
			continue
		}
		prox := i32(w.cfg.marry_radius + 2) - dist
		if prox < 1 do prox = 1
		wt := u64(prox)
		total += wt
		if total > 0 && rng_next_u64(&w.rng) % total < wt {
			best = o.id
		}
	}
	return best
}

try_marry_pair :: proc(w: ^World, a, b: ^Person) -> bool {
	if a == nil || b == nil || a.sex == b.sex {
		return false
	}
	if !is_marriageable(w, a) || !is_marriageable(w, b) || are_close_kin(w, a, b) {
		return false
	}
	man := a
	woman := b
	if a.sex == .Female {
		man, woman = b, a
	}
	if man.sex != .Male || woman.sex != .Female {
		return false
	}
	gap := abs_i32(age_years(man) - age_years(woman))
	bp := w.cfg.marry_bp
	bp = i32(i64(bp) * i64(man.health) / i64(HEALTH_MAX) * i64(woman.health) / i64(HEALTH_MAX))
	if gap > 10 {
		bp = bp * 4 / 10
	} else if gap > 6 {
		bp = bp * 7 / 10
	}
	if bp < 1 {
		return false
	}
	if !rng_chance_bp(&w.rng, bp) {
		return false
	}
	place, ok := choose_residence(w, man, woman)
	if !ok {
		return false
	}
	return settle_marriage(w, man, woman, place)
}

run_marriage_phase :: proc(w: ^World) {
	n := w.person_count
	if n <= 0 {
		return
	}
	for i: i32 = 0; i < n; i += 1 {
		w.person_order[i] = i
	}
	rng_shuffle_i32(&w.rng, w.person_order[:n])
	for idx in w.person_order[:n] {
		p := &w.people[idx]
		if !is_marriageable(w, p) {
			continue
		}
		enc := w.cfg.marry_encounters
		for _ in 0 ..< enc {
			if has_living_spouse(w, p) {
				break
			}
			cid := pick_marriage_candidate(w, p)
			if cid < 0 {
				break
			}
			o := person_at(w, cid)
			if try_marry_pair(w, p, o) {
				break
			}
		}
	}
}

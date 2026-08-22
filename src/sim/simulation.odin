package sim

sim_day :: proc(w: ^World) {
	w.acc = {}
	day := w.cfg.day_minutes
	if day <= 0 do day = DAY_MINUTES

	regen_resources(w)

	for &h in w.households {
		if h.exists && h.alive {
			decay_memories(w, &h)
			sync_household_from_members(w, &h)
		}
	}

	for &h in w.households {
		if h.exists {
			h.labor_today = {}
			h.visits_today = 0
		}
	}

	for i: i32 = 0; i < w.person_count; i += 1 {
		begin_person_day(w, &w.people[i], day)
	}

	max_bouts := w.cfg.max_bouts
	if max_bouts < 1 do max_bouts = 1
	n := w.person_count
	for _bout: i32 = 0; _bout < max_bouts; _bout += 1 {
		if n <= 0 do break
		for i: i32 = 0; i < n; i += 1 {
			w.person_order[i] = i
		}
		rng_shuffle_i32(&w.rng, w.person_order[:n])
		for idx in w.person_order[:n] {
			run_person_bout(w, &w.people[idx], day)
		}
	}

	for i: i32 = 0; i < w.person_count; i += 1 {
		end_person_day(w, &w.people[i], day)
	}

	for &h in w.households {
		if h.exists {
			consume_food_and_fuel(w, &h)
		}
	}
	for &h in w.households {
		if h.exists {
			spoil_food(w, &h)
		}
	}

	tick_people(w)
	run_marriage_phase(w)
	for &h in w.households {
		if h.exists && h.alive {
			try_conceive(w, &h)
			sync_household_from_members(w, &h)
		}
	}

	for &h in w.households {
		if h.exists && h.alive {
			update_labor_history(&h)
			update_specialization(w, &h)
		}
	}

	m := compute_metrics(w)
	push_metrics(w, m)

	assert_invariants(w)

	w.day += 1
}

begin_person_day :: proc(w: ^World, p: ^Person, day: i32) {
	h := &w.households[p.household]
	hx, hy := person_home_milli(h, p)
	path_reset(p, hx, hy)
	p.intent_activity = .Rest
	p.intent_cell = h.home
	p.intent_partner = -1
	p.blocks_this_day = 0
	p.minutes_sleep = 0
	p.minutes_home = 0
	p.minutes_work = 0
	p.minutes_travel = 0
	p.minutes_visit = 0
	p.visits_today = 0
	p.trade_hh = -1
	p.clock = 0

	if !p.alive {
		path_push(p, hx, hy, 10000)
		p.minutes_home = day
		p.clock = day
		p.sleep_start = day
		p.wake_min = 0
		return
	}

	wake, sleep_start := person_wake_window(w.cfg, p)
	p.wake_min = wake
	p.sleep_start = sleep_start

	if !can_work(p) || !h.alive {
		p.minutes_sleep = person_sleep_minutes(w.cfg, p)
		if p.minutes_sleep > day do p.minutes_sleep = day
		p.minutes_home = day - p.minutes_sleep
		path_push(p, hx, hy, 10000)
		p.clock = day
		return
	}

	path_push(p, hx, hy, clock_to_t(wake, day))
	p.minutes_sleep += wake
	p.clock = wake

	morn := w.cfg.morning_home
	if p.clock + morn > p.sleep_start {
		morn = p.sleep_start - p.clock
	}
	if morn < 0 do morn = 0
	if morn > 0 {
		p.clock += morn
		p.minutes_home += morn
		path_push(p, hx, hy, clock_to_t(p.clock, day))
	}
}

run_person_bout :: proc(w: ^World, p: ^Person, day: i32) {
	if !p.alive || !can_work(p) {
		return
	}
	h := &w.households[p.household]
	if !h.exists || !h.alive {
		return
	}
	remaining := p.sleep_start - p.clock
	away := p.minutes_work + p.minutes_travel + p.minutes_visit
	left_cap := work_minutes_cap(w.cfg, p) - away
	if left_cap < remaining {
		remaining = left_cap
	}
	if remaining < w.cfg.min_bout {
		return
	}

	plan_work_block(w, h, p, remaining)
	p.blocks_this_day += 1

	idx := p.last_decision.chosen_index
	if idx < 0 || idx >= p.last_decision.candidate_count {
		idx = 0
	}
	chosen := p.last_decision.candidates[idx]
	work := chosen.work_min
	execute_activity(w, h, p.intent_activity, p.intent_cell, p, work, p.intent_partner)
	apply_bout_path(w, p, h, p.intent_activity, p.intent_cell, work, p.intent_partner, day)
}

apply_bout_path :: proc(w: ^World, p: ^Person, h: ^Household, a: Activity, cell: Vec2i, work_min: i32, partner: i32, day: i32) {
	hx, hy := person_home_milli(h, p)
	labor := work_min
	if labor < 0 do labor = 0

	switch a {
	case .Rest:
		p.clock += labor
		p.minutes_home += labor
		path_push(p, hx, hy, clock_to_t(p.clock, day))
	case .Craft_Spear:
		p.clock += labor
		p.minutes_work += labor
		path_push(p, hx, hy, clock_to_t(p.clock, day))
	case .Visit:
		ox, oy := hx, hy
		if partner >= 0 && partner < i32(len(w.households)) {
			ox, oy = map_milli(w.households[partner].home)
		} else {
			ox, oy = map_milli(cell)
		}
		one := person_walk_minutes(w.cfg, p, h.home.x, h.home.y, cell.x, cell.y)
		linger := labor
		if linger <= 0 do linger = w.cfg.visit_linger
		p.clock += one
		p.minutes_travel += one
		path_push(p, ox, oy, clock_to_t(p.clock, day))
		p.clock += linger
		p.minutes_visit += linger
		path_push(p, ox, oy, clock_to_t(p.clock, day))
		p.clock += one
		p.minutes_travel += one
		path_push(p, hx, hy, clock_to_t(p.clock, day))
	case .Forage, .Hunt, .Gather_Wood, .Gather_Stone:
		wx, wy := map_milli(cell)
		one := person_walk_minutes(w.cfg, p, h.home.x, h.home.y, cell.x, cell.y)
		p.clock += one
		p.minutes_travel += one
		path_push(p, wx, wy, clock_to_t(p.clock, day))
		p.clock += labor
		p.minutes_work += labor
		path_push(p, wx, wy, clock_to_t(p.clock, day))
		p.clock += one
		p.minutes_travel += one
		path_push(p, hx, hy, clock_to_t(p.clock, day))
	}
	if p.clock > day {
		p.clock = day
	}
}

end_person_day :: proc(w: ^World, p: ^Person, day: i32) {
	if !p.alive {
		return
	}
	h := &w.households[p.household]
	hx, hy := person_home_milli(h, p)
	if p.clock < p.sleep_start {
		stay := p.sleep_start - p.clock
		p.minutes_home += stay
		p.clock = p.sleep_start
		path_push(p, hx, hy, clock_to_t(p.clock, day))
	}
	if p.clock < day {
		p.minutes_sleep += day - p.clock
		p.clock = day
	}
	path_push(p, hx, hy, 10000)
	apply_travel_fatigue(w, p)
	w.acc.travel_minutes_total += p.minutes_travel
}

sim_days :: proc(w: ^World, n: i32) {
	for _ in 0 ..< n {
		sim_day(w)
	}
}

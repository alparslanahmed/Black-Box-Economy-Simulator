package analysis

import "core:fmt"
import sim "../sim"

run_self_tests :: proc() -> bool {
	failed := 0
	if !test_determinism() {
		fmt.println("FAIL determinism")
		failed += 1
	} else {
		fmt.println("PASS determinism")
	}
	if !test_different_seeds() {
		fmt.println("FAIL different-seeds")
		failed += 1
	} else {
		fmt.println("PASS different-seeds")
	}
	if !test_inventory_conservation() {
		fmt.println("FAIL inventory-conservation")
		failed += 1
	} else {
		fmt.println("PASS inventory-conservation")
	}
	if !test_no_trade() {
		fmt.println("FAIL no-trade")
		failed += 1
	} else {
		fmt.println("PASS no-trade")
	}
	if !test_production_extracts_stock() {
		fmt.println("FAIL production")
		failed += 1
	} else {
		fmt.println("PASS production")
	}
	if !test_barter_requires_mutual_gain() {
		fmt.println("FAIL barter-mutual-gain")
		failed += 1
	} else {
		fmt.println("PASS barter-mutual-gain")
	}
	if !test_travel_scales_with_distance() {
		fmt.println("FAIL travel-distance")
		failed += 1
	} else {
		fmt.println("PASS travel-distance")
	}
	if !test_view_motion_no_teleport() {
		fmt.println("FAIL view-motion")
		failed += 1
	} else {
		fmt.println("PASS view-motion")
	}
	if !test_cousin_marriage_knob() {
		fmt.println("FAIL cousin-marriage")
		failed += 1
	} else {
		fmt.println("PASS cousin-marriage")
	}
	if failed == 0 {
		fmt.println("all self-tests passed")
		return true
	}
	fmt.printf("%d self-tests failed\n", failed)
	return false
}

test_determinism :: proc() -> bool {
	cfg := sim.default_config()
	cfg.household_count = 40
	seed: u64 = 123456789
	w1 := sim.world_create(seed, cfg, true)
	sim.sim_days(w1, 1000)
	h1 := sim.state_hash(w1)
	sim.world_destroy(w1)

	w2 := sim.world_create(seed, cfg, true)
	sim.sim_days(w2, 1000)
	h2 := sim.state_hash(w2)
	sim.world_destroy(w2)

	if h1 != h2 {
		fmt.printf("  hashes %v vs %v\n", h1, h2)
		return false
	}
	return true
}

test_different_seeds :: proc() -> bool {
	cfg := sim.default_config()
	cfg.household_count = 20
	w1 := sim.world_create(111, cfg, true)
	w2 := sim.world_create(222, cfg, true)
	sim.sim_days(w1, 80)
	sim.sim_days(w2, 80)
	h1 := sim.state_hash(w1)
	h2 := sim.state_hash(w2)
	sim.world_destroy(w1)
	sim.world_destroy(w2)
	if h1 == h2 {
		fmt.printf("  expected different hashes, both %v\n", h1)
		return false
	}
	return true
}

test_inventory_conservation :: proc() -> bool {
	cfg := sim.default_config()
	cfg.household_count = 10
	w := sim.world_create(99, cfg, true)
	defer sim.world_destroy(w)
	a := &w.households[0]
	b := &w.households[1]
	a.alive = true
	b.alive = true
	a.health = sim.HEALTH_MAX
	b.health = sim.HEALTH_MAX
	a.inv = {}
	b.inv = {}
	a.spear_durability = 0
	b.spear_durability = 0
	a.skills[sim.Skill_Kind.Hunt] = 12000
	a.skills[sim.Skill_Kind.Craft] = 8000
	b.skills[sim.Skill_Kind.Hunt] = 8000
	a.preferred_food_nutrition = 3 * cfg.nutrition_per_day
	b.preferred_food_nutrition = 3 * cfg.nutrition_per_day
	a.inv.qty[sim.Good.Meat] = 40 * sim.QTY_SCALE
	a.inv.qty[sim.Good.Wood] = 8 * sim.QTY_SCALE
	b.inv.qty[sim.Good.Stone] = 10 * sim.QTY_SCALE
	// A is well fed (meat) and has no stone / no spear → wants stone.
	// B is starving with stone → wants meat.
	meat0 := a.inv.qty[sim.Good.Meat] + b.inv.qty[sim.Good.Meat]
	stone0 := a.inv.qty[sim.Good.Stone] + b.inv.qty[sim.Good.Stone]
	res := sim.attempt_barter(w, a, b)
	meat1 := a.inv.qty[sim.Good.Meat] + b.inv.qty[sim.Good.Meat]
	stone1 := a.inv.qty[sim.Good.Stone] + b.inv.qty[sim.Good.Stone]
	if meat0 != meat1 || stone0 != stone1 {
		fmt.printf("  totals changed meat %v->%v stone %v->%v\n", meat0, meat1, stone0, stone1)
		return false
	}
	if !res.success {
		fmt.println("  expected a successful trade in the controlled setup")
		return false
	}
	if a.inv.qty[sim.Good.Meat] + b.inv.qty[sim.Good.Meat] != 40 * sim.QTY_SCALE {
		return false
	}
	return true
}

test_no_trade :: proc() -> bool {
	cfg := sim.default_config()
	cfg.household_count = 20
	w := sim.world_create(7, cfg, false)
	defer sim.world_destroy(w)
	sim.sim_days(w, 120)
	if w.exchanges.count != 0 {
		fmt.printf("  exchanges recorded with trade disabled: %v\n", w.exchanges.count)
		return false
	}
	// last-day successful trades
	m := sim.latest_metrics(w)
	if m.successful_trades != 0 {
		fmt.printf("  successful trades=%d with trade disabled\n", m.successful_trades)
		return false
	}
	return true
}

test_production_extracts_stock :: proc() -> bool {
	cfg := sim.default_config()
	cfg.household_count = 10
	w := sim.world_create(3, cfg, false)
	defer sim.world_destroy(w)
	h := &w.households[0]
	h.alive = true
	found := sim.find_best_resource_cell(w, h, sim.Resource_Kind.Berry, h.skills[sim.Skill_Kind.Forage], cfg.forage_yield_per_min)
	if !found.found {
		fmt.println("  no berry cell found")
		return false
	}
	c := sim.cell_at_pos(w, found.cell)
	stock0 := c.berry_stock
	inv0 := h.inv.qty[sim.Good.Berries]
	sim.execute_activity(w, h, sim.Activity.Forage, found.cell)
	c = sim.cell_at_pos(w, found.cell)
	delta_stock := stock0 - c.berry_stock
	delta_inv := h.inv.qty[sim.Good.Berries] - inv0
	if delta_inv != delta_stock {
		fmt.printf("  extraction mismatch stock %v inv %v\n", delta_stock, delta_inv)
		return false
	}
	if delta_inv < 0 {
		return false
	}
	return true
}

test_barter_requires_mutual_gain :: proc() -> bool {
	cfg := sim.default_config()
	cfg.household_count = 8
	w := sim.world_create(5, cfg, true)
	defer sim.world_destroy(w)
	a := &w.households[0]
	b := &w.households[1]
	a.alive = true
	b.alive = true
	a.inv = {}
	b.inv = {}
	a.health = sim.HEALTH_MAX
	b.health = sim.HEALTH_MAX
	// A has meat, B has nothing B wants to give that A wants.
	a.inv.qty[sim.Good.Meat] = 8 * sim.QTY_SCALE
	b.inv.qty[sim.Good.Wood] = 0
	res := sim.attempt_barter(w, a, b)
	if res.success {
		fmt.println("  trade succeeded without the other side having goods")
		return false
	}
	return true
}

test_travel_scales_with_distance :: proc() -> bool {
	cfg := sim.default_config()
	near := sim.walk_minutes(cfg, 0, 0, 1, 0)
	far := sim.walk_minutes(cfg, 0, 0, 10, 0)
	if near <= 0 {
		fmt.println("  1-cell walk should take time")
		return false
	}
	if far < near * 8 {
		fmt.printf("  walk 1-cell=%d 10-cell=%d (far should scale)\n", near, far)
		return false
	}
	rt := sim.travel_minutes(cfg, 0, 0, 4, 0)
	one := sim.walk_minutes(cfg, 0, 0, 4, 0)
	if rt != one * 2 {
		fmt.printf("  round-trip %d != 2 * one-way %d\n", rt, one)
		return false
	}
	cfg.household_count = 16
	w := sim.world_create(42, cfg, true)
	defer sim.world_destroy(w)
	sim.sim_days(w, 6)
	day := cfg.day_minutes
	any_travel := false
	any_work := false
	any_idle_trader := false
	visits: i32
	workers: i32
	for i: i32 = 0; i < w.person_count; i += 1 {
		p := &w.people[i]
		if !p.alive do continue
		sum := p.minutes_sleep + p.minutes_home + p.minutes_work + p.minutes_travel + p.minutes_visit
		if sum < day - 20 || sum > day + 20 {
			fmt.printf("  person %d time sum %d want %d (sleep %d home %d walk %d work %d visit %d)\n",
				p.id, sum, day, p.minutes_sleep, p.minutes_home, p.minutes_travel, p.minutes_work, p.minutes_visit)
			return false
		}
		if sim.can_work(p) {
			workers += 1
			if p.minutes_work > 0 do any_work = true
			if p.minutes_travel > 0 do any_travel = true
			if p.visits_today == 0 do any_idle_trader = true
			visits += p.visits_today
		}
	}
	if !any_travel || !any_work {
		fmt.println("  expected some walking and some work after a few days")
		return false
	}
	if workers > 4 && !any_idle_trader {
		fmt.println("  every worker visited a neighbor; trade should be a choice, not automatic")
		return false
	}
	_ = visits
	return true
}

test_view_motion_no_teleport :: proc() -> bool {
	cfg := sim.default_config()
	cfg.household_count = 16
	w := sim.world_create(42, cfg, true)
	defer sim.world_destroy(w)
	sim.sim_days(w, 5)
	// 0.005 of visual day is a bit more than one frame at 0.25x / 60fps.
	step: f32 = 0.005
	max_jump := f32(1800) // 1.8 cells in milli
	for i: i32 = 0; i < w.person_count; i += 1 {
		p := &w.people[i]
		if !p.alive || !sim.can_work(p) do continue
		if p.path_n < 2 do continue
		px, py := sim.person_view_pos_f32(p, 0)
		u: f32 = step
		for u <= 1.0001 {
			if u > 1 do u = 1
			x, y := sim.person_view_pos_f32(p, u)
			dx := x - px
			dy := y - py
			if dx < 0 do dx = -dx
			if dy < 0 do dy = -dy
			jump := dx + dy
			if jump > max_jump {
				fmt.printf("  person %d jumped %.0f milli (%.2f cells) at u=%.3f path_n=%d\n",
					p.id, jump, jump / 1000, u, p.path_n)
				return false
			}
			px, py = x, y
			if u >= 1 do break
			u += step
		}
	}
	return true
}

test_cousin_marriage_knob :: proc() -> bool {
	cfg := sim.default_config()
	cfg.household_count = 8
	w := sim.world_create(11, cfg, true)
	defer sim.world_destroy(w)
	if w.person_count < 5 {
		fmt.println("  need 5 people")
		return false
	}
	a := &w.people[0]
	b := &w.people[1]
	c := &w.people[2]
	d := &w.people[3]
	f := &w.people[4]
	a.sex = .Male
	b.sex = .Male
	c.sex = .Male
	d.sex = .Female
	f.sex = .Male
	f.father_id = -1
	f.mother_id = -1
	a.father_id = f.id
	a.mother_id = -1
	b.father_id = f.id
	b.mother_id = -1
	c.father_id = a.id
	c.mother_id = -1
	d.father_id = b.id
	d.mother_id = -1
	if !sim.share_a_parent(a, b) {
		fmt.println("  expected A,B siblings")
		return false
	}
	if !sim.are_close_kin(w, a, b) {
		fmt.println("  siblings must be forbidden")
		return false
	}
	if !sim.is_first_cousin(w, c, d) {
		fmt.println("  expected C,D first cousins")
		return false
	}
	w.cfg.marry_allow_cousins = true
	if sim.are_close_kin(w, c, d) {
		fmt.println("  cousins should be allowed when knob is on")
		return false
	}
	w.cfg.marry_allow_cousins = false
	if !sim.are_close_kin(w, c, d) {
		fmt.println("  cousins should be forbidden when knob is off")
		return false
	}
	if !sim.are_close_kin(w, a, c) {
		fmt.println("  parent-child must stay forbidden")
		return false
	}
	if !sim.is_avuncular(w, b, c) || !sim.are_close_kin(w, b, c) {
		fmt.println("  uncle-niece/nephew must stay forbidden")
		return false
	}
	return true
}

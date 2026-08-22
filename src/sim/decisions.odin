package sim

plan_work_block :: proc(w: ^World, h: ^Household, actor: ^Person = nil, available: i32 = 0) {
	d: Decision
	rest_cell := h.home
	if !h.alive || (actor != nil && (!actor.alive || work_blocks_for(actor) <= 0)) {
		d.chosen = .Rest
		d.candidate_count = 1
		d.candidates[0] = Decision_Candidate{
			activity = .Rest,
			feasible = true,
			target_cell = rest_cell,
			partner = -1,
			work_min = max(available, 0),
		}
		apply_plan(h, actor, d)
		return
	}

	budget := available
	if budget <= 0 {
		budget = w.cfg.block_minutes
	}

	acts := [DECISION_CANDIDATES]Activity{.Forage, .Hunt, .Gather_Wood, .Gather_Stone, .Craft_Spear, .Rest, .Visit}
	best_i := 0
	best_score: i64 = min(i64)
	n: i32 = 0
	rest_i: i32 = 5

	for a, i in acts {
		c := score_activity(w, h, a, actor, budget)
		if c.partner == 0 && a != .Visit {
			c.partner = -1
		}
		d.candidates[i] = c
		n += 1
		if a == .Rest {
			rest_i = i32(i)
		}
		if c.feasible && c.total_score > best_score {
			best_score = c.total_score
			best_i = i
		}
	}
	d.candidate_count = n
	d.chosen_index = i32(best_i)
	d.chosen = d.candidates[best_i].activity
	if !d.candidates[best_i].feasible {
		d.chosen = .Rest
		d.chosen_index = rest_i
	}
	apply_plan(h, actor, d)
}

apply_plan :: proc(h: ^Household, actor: ^Person, d: Decision) {
	h.last_decision = d
	h.intent_activity = d.chosen
	idx := d.chosen_index
	if idx < 0 || idx >= d.candidate_count {
		idx = 0
	}
	h.intent_cell = d.candidates[idx].target_cell
	if actor != nil {
		actor.last_decision = d
		actor.intent_activity = d.chosen
		actor.intent_cell = d.candidates[idx].target_cell
		actor.intent_partner = d.candidates[idx].partner
	}
}

score_activity :: proc(w: ^World, h: ^Household, a: Activity, actor: ^Person = nil, available: i32 = 0) -> Decision_Candidate {
	c: Decision_Candidate
	c.activity = a
	c.target_cell = h.home
	c.partner = -1
	budget := available
	if budget <= 0 {
		budget = w.cfg.block_minutes
	}

	hp := h.health
	if actor != nil {
		hp = actor.health
	}
	if a == .Rest {
		c.feasible = true
		c.work_min = min(i32(180), budget)
		if hp < 5000 {
			c.work_min = budget
		}
		c.total_score = 40
		if hp < 7000 {
			nut := nutrition_of(h.inv, w.cfg)
			need := household_daily_need(w, h)
			if nut >= need {
				c.food_need = 180
				c.total_score += 180
			}
		}
		if actor != nil && actor.pregnant {
			c.total_score += 120
		}
		if budget < w.cfg.min_bout {
			c.total_score += 400
		}
		// After a full work day, staying home beats a leftover social walk.
		if actor != nil {
			away := actor.minutes_work + actor.minutes_travel + actor.minutes_visit
			if away >= w.cfg.labor_minutes / 2 {
				c.total_score += 280
			}
			if away >= w.cfg.labor_minutes * 3 / 4 {
				c.total_score += 220
			}
		}
		return c
	}
	if a == .Visit {
		return score_visit(w, h, actor, budget)
	}

	sk, has_sk := activity_to_skill(a)
	skill := actor_skill(h, actor, sk) if has_sk else SKILL_AVERAGE
	yield_per_min := activity_yield_per_min(w, a)

	if a == .Craft_Spear {
		return score_craft(w, h, skill, actor, budget)
	}

	rk, has_r := activity_resource(a)
	if !has_r {
		c.feasible = false
		return c
	}

	found := find_best_resource_cell(w, h, rk, skill, yield_per_min, budget, actor)
	if !found.found {
		c.feasible = false
		c.travel = -400
		c.total_score = -1000
		return c
	}
	c.feasible = true
	c.target_cell = found.cell
	c.work_min = found.effective
	per := i64(w.cfg.travel_score_per_min)
	if per < 1 do per = 12
	c.travel = -i64(found.travel) * per
	if found.travel > 90 {
		c.travel -= i64(found.travel - 90) * 6
	}

	exp_qty := expected_output_qty(w, h, a, found, skill)
	c.expected_output = exp_qty

	before := utility_current(w, h)
	inv := h.inv
	dur := h.spear_durability
	g, has_g := activity_output_good(a)
	if has_g && a != .Hunt {
		inv.qty[g] += exp_qty
	}

	need := household_daily_need(w, h)
	food_before := food_utility(nutrition_of(h.inv, w.cfg), h.preferred_food_nutrition, need)
	fuel_before := fuel_utility(h.inv.qty[Good.Wood], household_fuel_need(w, h))
	hunt_sk := actor_skill(h, actor, .Hunt)
	tool_before := spear_utility(h.inv, h.spear_durability, hunt_sk, w.cfg)

	if a == .Hunt {
		pr := hunt_success_bp(w, h, hunt_sk)
		success_inv := h.inv
		success_inv.qty[Good.Meat] += hunt_yield_qty(w, h, found, skill)
		fail_inv := h.inv
		u_s := utility_of(w, h, success_inv, dur)
		u_f := utility_of(w, h, fail_inv, dur)
		expected_u := (u_s * i64(pr) + u_f * i64(BP_SCALE - pr)) / i64(BP_SCALE)
		delta := expected_u - before

		food_s := food_utility(nutrition_of(success_inv, w.cfg), h.preferred_food_nutrition, need)
		c.food_need = (food_s - food_before) * i64(pr) / i64(BP_SCALE)
		c.risk = delta - (u_s - before) * i64(pr) / i64(BP_SCALE)
		aversion := i64(12000 - h.risk_preference)
		if aversion < 2000 do aversion = 2000
		c.risk = c.risk * aversion / 10000
		days := food_days_milli(nutrition_of(h.inv, w.cfg), need)
		c.expected_output = hunt_yield_qty(w, h, found, skill) * i64(pr) / i64(BP_SCALE)
		c.skill = i64(skill - SKILL_AVERAGE) * 12 / 10
		c.trade_demand = trade_demand_component(h, .Meat, c.expected_output, days)
		c.input = 0
		c.tool = 0
		if has_usable_spear(h) {
			c.tool = 220
		}
		c.total_score = c.food_need + c.fuel_need + c.tool + c.input + c.trade_demand + c.skill + c.travel + c.risk
		return c
	}

	after := utility_of(w, h, inv, dur)
	food_after := food_utility(nutrition_of(inv, w.cfg), h.preferred_food_nutrition, need)
	fuel_after := fuel_utility(inv.qty[Good.Wood], household_fuel_need(w, h))
	tool_after := spear_utility(inv, dur, hunt_sk, w.cfg)

	c.food_need = food_after - food_before
	c.fuel_need = fuel_after - fuel_before
	c.tool = tool_after - tool_before
	if a == .Gather_Stone {
		c.input = stone_utility(inv, h) - stone_utility(h.inv, h)
	}
	if a == .Gather_Wood {
		c.input += wood_craft_utility(inv, h, w.cfg) - wood_craft_utility(h.inv, h, w.cfg)
	}
	days := food_days_milli(nutrition_of(h.inv, w.cfg), need)
	c.trade_demand = trade_demand_component(h, g, exp_qty, days)
	c.skill = i64(skill - SKILL_AVERAGE) * 12 / 10
	c.tool += tool_plan_component(w, h, a, days, actor)
	_ = after
	c.total_score = c.food_need + c.fuel_need + c.tool + c.input + c.trade_demand + c.skill + c.travel + c.risk
	return c
}

tool_plan_component :: proc(w: ^World, h: ^Household, a: Activity, food_days: i64, actor: ^Person = nil) -> i64 {
	if spear_count(h.inv) > 0 {
		return 0
	}
	if food_days < 1000 {
		return 0
	}
	hunt := actor_skill(h, actor, .Hunt)
	craft := actor_skill(h, actor, .Craft)
	if hunt < 8500 && craft < 10800 {
		return 0
	}
	need_stone := h.inv.qty[Good.Stone] < w.cfg.spear_stone_cost
	fuel_reserve := w.cfg.fuel_per_day * 4
	need_wood := h.inv.qty[Good.Wood] < fuel_reserve + w.cfg.spear_wood_cost
	switch a {
	case .Gather_Stone:
		if need_stone do return 4200
	case .Gather_Wood:
		if need_wood do return 3200
	case .Forage, .Hunt, .Craft_Spear, .Rest, .Visit:
	}
	return 0
}

score_craft :: proc(w: ^World, h: ^Household, skill: i32, actor: ^Person = nil, available: i32 = 0) -> Decision_Candidate {
	c: Decision_Candidate
	c.activity = .Craft_Spear
	c.target_cell = h.home
	c.partner = -1
	work := available
	if work <= 0 || work > w.cfg.block_minutes {
		work = w.cfg.block_minutes
	}
	c.work_min = work
	if h.inv.qty[Good.Wood] < w.cfg.spear_wood_cost || h.inv.qty[Good.Stone] < w.cfg.spear_stone_cost {
		c.feasible = false
		c.total_score = -800
		c.input = -200
		return c
	}
	c.feasible = true
	progress := i32(i64(work) * i64(skill) / i64(SKILL_AVERAGE))
	will_finish := h.craft_progress + progress >= w.cfg.craft_progress_needed

	before := utility_current(w, h)
	inv := h.inv
	dur := h.spear_durability
	c.input = -80
	if will_finish {
		inv.qty[Good.Wood] -= w.cfg.spear_wood_cost
		inv.qty[Good.Stone] -= w.cfg.spear_stone_cost
		inv.qty[Good.Spear] += QTY_SCALE
		if dur <= 0 {
			dur = w.cfg.spear_durability_max
		}
		c.expected_output = QTY_SCALE
		c.tool = spear_utility(inv, dur, actor_skill(h, actor, .Hunt), w.cfg) -
			spear_utility(h.inv, h.spear_durability, actor_skill(h, actor, .Hunt), w.cfg)
		c.fuel_need = fuel_utility(inv.qty[Good.Wood], household_fuel_need(w, h)) -
			fuel_utility(h.inv.qty[Good.Wood], household_fuel_need(w, h))
		c.input += stone_utility(inv, h) - stone_utility(h.inv, h)
	} else {
		need := spear_utility(
			Inventory{qty = {0, 0, 0, 0, QTY_SCALE}},
			w.cfg.spear_durability_max,
			actor_skill(h, actor, .Hunt),
			w.cfg,
		) - spear_utility(h.inv, h.spear_durability, actor_skill(h, actor, .Hunt), w.cfg)
		frac := i64(progress) * 1000 / i64(w.cfg.craft_progress_needed)
		c.tool = need * frac / 1800
		c.expected_output = 0
	}

	days := food_days_milli(nutrition_of(h.inv, w.cfg), household_daily_need(w, h))
	c.trade_demand = trade_demand_component(h, .Spear, QTY_SCALE if will_finish else 0, days)
	c.skill = i64(skill - SKILL_AVERAGE) * 12 / 10
	if days < 1000 {
		c.food_need = -2800 // don't craft while starving
	} else if days < 1300 {
		c.food_need = -700
	}
	_ = before
	c.total_score = c.food_need + c.fuel_need + c.tool + c.input + c.trade_demand + c.skill + c.travel + c.risk
	return c
}

score_visit :: proc(w: ^World, h: ^Household, actor: ^Person, available: i32) -> Decision_Candidate {
	c: Decision_Candidate
	c.activity = .Visit
	c.target_cell = h.home
	c.partner = -1
	c.work_min = w.cfg.visit_linger

	if !w.trade_enabled || actor == nil || !actor.alive {
		c.feasible = false
		c.total_score = -2000
		return c
	}
	if actor.visits_today >= w.cfg.max_visits_per_day || h.visits_today >= 1 {
		c.feasible = false
		c.total_score = -1800
		return c
	}
	linger := w.cfg.visit_linger
	if linger < 15 do linger = 15
	if available < linger + 2 {
		c.feasible = false
		c.total_score = -1600
		return c
	}

	need := household_daily_need(w, h)
	days := food_days_milli(nutrition_of(h.inv, w.cfg), need)
	speed := person_walk_speed_bp(actor)
	per := i64(w.cfg.travel_score_per_min)
	if per < 1 do per = 12

	// You do not see the other camp's stores. You walk because YOU need
	// something and YOU can spare something, and maybe you remember a neighbor.
	need_strength: i64
	surplus_strength: i64
	food_need_part: i64
	best_surplus_good := Good.Wood
	best_surplus: i64 = -1
	for g in Good {
		def := good_def(g)
		if def.min_trade_qty > 0 {
			rec := marginal_receive(w, h, g, def.min_trade_qty * 2)
			// A first spear is hugely useful at home, but that is not a reason
			// to walk to every neighbor every day hoping they have one.
			if g == .Spear {
				rec = min(rec, 1400)
			}
			if rec > need_strength {
				need_strength = rec
			}
			if g == .Berries || g == .Meat {
				if rec > food_need_part do food_need_part = rec
			}
		}
		if h.inv.qty[g] >= def.min_trade_qty {
			give_cost := marginal_give(w, h, g, def.min_trade_qty)
			spare := 1100 - min(give_cost, 1100)
			if spare < 0 do spare = 0
			// Only real surplus: giving it barely hurts.
			if give_cost > 700 {
				spare = spare / 4
			}
			spare += i64(h.observed_demand[g]) / 3
			if spare > best_surplus {
				best_surplus = spare
				best_surplus_good = g
				surplus_strength = spare
			}
		}
	}
	if need_strength < 700 || surplus_strength < 400 {
		c.feasible = false
		c.total_score = -1400
		return c
	}

	best_id: i32 = -1
	best_score: i64 = min(i64)
	best_cell := h.home
	best_travel: i32
	best_demand: i64
	found := false

	for i in 0 ..< len(w.households) {
		o := &w.households[i]
		if !o.exists || !o.alive || o.id == h.id {
			continue
		}
		milli := octile_milli(h.home.x, h.home.y, o.home.x, o.home.y)
		dist := milli / 1000
		if dist > w.cfg.trade_radius {
			continue
		}
		one := walk_minutes(w.cfg, h.home.x, h.home.y, o.home.x, o.home.y, speed)
		cost := one * 2 + linger
		if cost > available {
			continue
		}

		travel_pen := i64(one * 2) * per
		if one * 2 > 60 {
			travel_pen += i64(one * 2 - 60) * 10
		}
		// Hungry people will not wander far unless they are going for food.
		if days < 1200 && food_need_part < 800 {
			travel_pen = travel_pen * 2
		} else if days < 1200 {
			travel_pen = travel_pen * 5 / 4
		}

		openness := i64(h.trade_openness + o.trade_openness) / 50
		known: i64
		ntr := int(h.recent_trade_count)
		for k := 0; k < ntr; k += 1 {
			idx := (int(h.recent_trade_head) - ntr + k + TRADE_MEMORY) % TRADE_MEMORY
			tr := h.recent_trades[idx]
			if tr.partner == o.id && tr.success {
				known += 320
			}
		}
		mem := i64(h.observed_demand[best_surplus_good]) / 3
		// Work first on a normal day; leftover evening walks need a stronger reason.
		opp: i64 = 900
		if actor.blocks_this_day == 0 && days >= 1200 {
			opp += 500
		}
		if actor.minutes_work + actor.minutes_travel >= w.cfg.labor_minutes / 2 {
			opp += 400
		}

		s := need_strength * 5 / 10 + surplus_strength + openness + known + mem - travel_pen - opp
		if s < 700 {
			continue
		}
		if !found || s > best_score {
			found = true
			best_score = s
			best_id = o.id
			best_cell = o.home
			best_travel = one * 2
			best_demand = known + mem
		}
	}

	if !found || best_id < 0 {
		c.feasible = false
		c.total_score = -1500
		return c
	}

	c.feasible = true
	c.partner = best_id
	c.target_cell = best_cell
	c.work_min = linger
	c.travel = -i64(best_travel) * per
	if best_travel > 60 {
		c.travel -= i64(best_travel - 60) * 10
	}
	c.food_need = min(food_need_part * 6 / 10, 5000)
	c.trade_demand = best_demand
	c.total_score = best_score
	return c
}

trade_demand_component :: proc(h: ^Household, g: Good, expected_qty: i64, food_days_milli: i64) -> i64 {
	if expected_qty <= 0 {
		return 0
	}
	mem := i64(h.observed_demand[g])
	if mem <= 0 {
		return 0
	}
	attention: i64 = 10000
	if food_days_milli < 2000 {
		attention = 2500
	} else if food_days_milli < 3000 {
		attention = 6000
	}
	return mem * expected_qty * attention / (QTY_SCALE * 10000 * 4)
}

activity_yield_per_min :: proc(w: ^World, a: Activity) -> i64 {
	switch a {
	case .Forage:       return w.cfg.forage_yield_per_min
	case .Gather_Wood:  return w.cfg.wood_yield_per_min
	case .Gather_Stone: return w.cfg.stone_yield_per_min
	case .Hunt:         return w.cfg.hunt_yield_spear / 200 // search heuristic only
	case .Craft_Spear, .Rest, .Visit:
		return 0
	}
	return 0
}

expected_output_qty :: proc(w: ^World, h: ^Household, a: Activity, found: Find_Result, skill: i32) -> i64 {
	ypm := activity_yield_per_min(w, a)
	raw := i64(found.effective) * ypm * i64(skill) / i64(SKILL_AVERAGE)
	return min(raw, found.stock)
}

hunt_success_bp :: proc(w: ^World, h: ^Household, hunt_skill: i32 = 0) -> i32 {
	base := w.cfg.hunt_p_no_spear
	if has_usable_spear(h) {
		base = w.cfg.hunt_p_spear
	}
	sk := hunt_skill
	if sk == 0 {
		sk = h.skills[Skill_Kind.Hunt]
	}
	delta := sk - SKILL_AVERAGE
	p := base + delta * w.cfg.hunt_skill_p_scale / SKILL_AVERAGE
	return clamp_i32(p, 1200, 9000)
}

hunt_yield_qty :: proc(w: ^World, h: ^Household, found: Find_Result, skill: i32) -> i64 {
	base := w.cfg.hunt_yield_no_spear
	if has_usable_spear(h) {
		base = w.cfg.hunt_yield_spear
	}
	y := base * i64(skill) / i64(SKILL_AVERAGE)
	y = y * i64(found.effective) / i64(w.cfg.block_minutes)
	return min(y, found.stock)
}

sort_decision_candidates :: proc(d: ^Decision) {
	n := int(d.candidate_count)
	for i in 0 ..< n {
		best := i
		for j := i + 1; j < n; j += 1 {
			if d.candidates[j].total_score > d.candidates[best].total_score {
				best = j
			}
		}
		if best != i {
			d.candidates[i], d.candidates[best] = d.candidates[best], d.candidates[i]
			if i32(i) == d.chosen_index {
				d.chosen_index = i32(best)
			} else if i32(best) == d.chosen_index {
				d.chosen_index = i32(i)
			}
		}
	}
}

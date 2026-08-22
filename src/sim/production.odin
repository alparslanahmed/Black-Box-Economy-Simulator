package sim

execute_activity :: proc(w: ^World, h: ^Household, a: Activity, cell: Vec2i, actor: ^Person = nil, work_min: i32 = 0, partner: i32 = -1) {
	if a == .Rest {
		return
	}
	if a == .Visit {
		execute_visit(w, h, actor, partner)
		push_event(w, Event{kind = .Work_Completed, h1 = h.id, h2 = partner, activity = a, cell = cell})
		return
	}

	labor := work_min
	if labor <= 0 {
		travel := travel_minutes(w.cfg, h.home.x, h.home.y, cell.x, cell.y)
		labor = w.cfg.block_minutes - travel
	}
	if labor < 0 {
		labor = 0
	}

	sk, ok := activity_to_skill(a)
	if ok && labor > 0 {
		h.labor_today[sk] += labor
		if actor != nil {
			learn_person_skill(w, actor, sk)
		} else {
			learn_skill(w, h, sk)
		}
	}

	forage_sk := actor_skill(h, actor, .Forage)
	wood_sk := actor_skill(h, actor, .Wood)
	stone_sk := actor_skill(h, actor, .Stone)

	switch a {
	case .Forage:
		gather_from_map(w, h, cell, .Berry, .Berries, w.cfg.forage_yield_per_min, forage_sk, labor)
	case .Gather_Wood:
		gather_from_map(w, h, cell, .Wood, .Wood, w.cfg.wood_yield_per_min, wood_sk, labor)
	case .Gather_Stone:
		gather_from_map(w, h, cell, .Stone, .Stone, w.cfg.stone_yield_per_min, stone_sk, labor)
	case .Hunt:
		execute_hunt(w, h, cell, actor, labor)
	case .Craft_Spear:
		execute_craft(w, h, actor, labor)
	case .Rest, .Visit:
	}

	push_event(w, Event{kind = .Work_Completed, h1 = h.id, h2 = partner, activity = a, cell = cell})
}

execute_visit :: proc(w: ^World, h: ^Household, actor: ^Person, partner: i32) {
	if !w.trade_enabled || h == nil || !h.alive {
		return
	}
	if partner < 0 || partner >= i32(len(w.households)) {
		return
	}
	other := &w.households[partner]
	if !other.exists || !other.alive {
		return
	}
	res := attempt_barter(w, h, other)
	record_attempt(w, h, other, res)
	h.visits_today += 1
	if actor != nil {
		actor.trade_hh = partner
		actor.visits_today += 1
	}
	w.acc.visits += 1
}

gather_from_map :: proc(w: ^World, h: ^Household, cell: Vec2i, r: Resource_Kind, g: Good, ypm: i64, skill: i32, work_min: i32) {
	if !in_bounds(w, cell.x, cell.y) || work_min <= 0 {
		return
	}
	raw := i64(work_min) * ypm * i64(skill) / i64(SKILL_AVERAGE)
	got := extract_stock(w, cell, r, raw)
	if got > 0 {
		add_good(&h.inv, g, got)
		w.acc.produced[g] += got
	}
}

execute_hunt :: proc(w: ^World, h: ^Household, cell: Vec2i, actor: ^Person = nil, work_min: i32 = 0) {
	eff := work_min
	if eff <= 0 {
		travel := travel_minutes(w.cfg, h.home.x, h.home.y, cell.x, cell.y)
		eff = w.cfg.block_minutes - travel
	}
	if eff <= 0 {
		return
	}
	used_spear := has_usable_spear(h)
	skill := actor_skill(h, actor, .Hunt)
	p := hunt_success_bp(w, h, skill)
	success := rng_chance_bp(&w.rng, p)

	if used_spear {
		consume_spear_durability(w, h)
	}

	if !success {
		push_event(w, Event{kind = .Hunt_Failed, h1 = h.id, cell = cell})
		return
	}

	base := w.cfg.hunt_yield_no_spear
	if used_spear {
		base = w.cfg.hunt_yield_spear
	}
	y := base * i64(skill) / i64(SKILL_AVERAGE)
	y = y * i64(eff) / i64(w.cfg.block_minutes)
	got := extract_stock(w, cell, .Game, y)
	if got > 0 {
		add_good(&h.inv, .Meat, got)
		w.acc.produced[Good.Meat] += got
	}
	push_event(w, Event{kind = .Hunt_Succeeded, h1 = h.id, cell = cell, qty_a = got, good_a = .Meat})
}

execute_craft :: proc(w: ^World, h: ^Household, actor: ^Person = nil, work_min: i32 = 0) {
	if h.inv.qty[Good.Wood] < w.cfg.spear_wood_cost || h.inv.qty[Good.Stone] < w.cfg.spear_stone_cost {
		return
	}
	labor := work_min
	if labor <= 0 {
		labor = w.cfg.block_minutes
	}
	skill := actor_skill(h, actor, .Craft)
	h.craft_progress += i32(i64(labor) * i64(skill) / i64(SKILL_AVERAGE))
	if h.craft_progress >= w.cfg.craft_progress_needed {
		if !remove_good(&h.inv, .Wood, w.cfg.spear_wood_cost) {
			return
		}
		if !remove_good(&h.inv, .Stone, w.cfg.spear_stone_cost) {
			add_good(&h.inv, .Wood, w.cfg.spear_wood_cost)
			return
		}
		grant_spear(w, h)
		h.craft_progress -= w.cfg.craft_progress_needed
		if h.craft_progress < 0 {
			h.craft_progress = 0
		}
		w.acc.produced[Good.Spear] += QTY_SCALE
		push_event(w, Event{kind = .Spear_Crafted, h1 = h.id, good_a = .Spear, qty_a = QTY_SCALE})
	}
}

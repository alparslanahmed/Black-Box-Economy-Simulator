package sim

has_usable_spear :: proc(h: ^Household) -> bool {
	return h.inv.qty[Good.Spear] >= QTY_SCALE && h.spear_durability > 0
}

consume_food_and_fuel :: proc(w: ^World, h: ^Household) {
	if h == nil || !h.exists || !h.alive {
		return
	}
	need := household_daily_need(w, h)
	days_before := food_days_milli(nutrition_of(h.inv, w.cfg), need)
	for i: i32 = 0; i < h.member_count; i += 1 {
		p := person_at(w, h.members[i])
		if p != nil && p.alive && p.pregnant {
			p.preg_food_days_acc += days_before
			p.preg_days_counted += 1
		}
	}

	got: i64
	remain := need
	meat_nut := h.inv.qty[Good.Meat] * w.cfg.meat_nutrition / QTY_SCALE
	if meat_nut > 0 && remain > 0 {
		take_nut := min(meat_nut, remain)
		take_qty := take_nut * QTY_SCALE / w.cfg.meat_nutrition
		if take_qty > h.inv.qty[Good.Meat] {
			take_qty = h.inv.qty[Good.Meat]
		}
		h.inv.qty[Good.Meat] -= take_qty
		got += take_qty * w.cfg.meat_nutrition / QTY_SCALE
		remain -= take_qty * w.cfg.meat_nutrition / QTY_SCALE
	}
	if remain > 0 {
		berry_nut := h.inv.qty[Good.Berries] * w.cfg.berry_nutrition / QTY_SCALE
		take_nut := min(berry_nut, remain)
		take_qty := take_nut * QTY_SCALE / w.cfg.berry_nutrition
		if take_qty > h.inv.qty[Good.Berries] {
			take_qty = h.inv.qty[Good.Berries]
		}
		h.inv.qty[Good.Berries] -= take_qty
		got += take_qty * w.cfg.berry_nutrition / QTY_SCALE
		remain -= take_qty * w.cfg.berry_nutrition / QTY_SCALE
	}

	fuel_need := household_fuel_need(w, h)
	fuel_ok := remove_good(&h.inv, .Wood, fuel_need)
	if !fuel_ok {
		h.inv.qty[Good.Wood] = 0
	}

	hungry_hh := false
	for i: i32 = 0; i < h.member_count; i += 1 {
		p := person_at(w, h.members[i])
		if p == nil || !p.alive do continue
		pn := person_nutrition_need(w, p)
		share: i64
		if need > 0 {
			share = got * pn / need
		}
		if share < pn {
			hungry_hh = true
		}
		age_and_health_environment(w, p, share, pn, fuel_ok)
	}
	if hungry_hh {
		w.acc.hungry += 1
		push_event(w, Event{kind = .Hunger, h1 = h.id, qty_a = got, qty_b = need - got})
	}
	sync_household_from_members(w, h)
	h.last_food_nutrition = nutrition_of(h.inv, w.cfg)
}

spoil_food :: proc(w: ^World, h: ^Household) {
	if h == nil || !h.exists {
		return
	}
	spoil :: proc(qty: i64, bp: i32) -> i64 {
		if qty <= 0 || bp <= 0 {
			return 0
		}
		lost := qty * i64(bp) / 10000
		if lost < 1 && qty > 0 && bp > 0 {
			// deterministic fractional leftover via leftover qty itself; keep at least
			// 1 unit loss when stock is large enough to matter
			if qty >= 20 {
				lost = 1
			}
		}
		if lost > qty {
			lost = qty
		}
		return lost
	}
	lb := spoil(h.inv.qty[Good.Berries], w.cfg.berry_spoil_bp)
	lm := spoil(h.inv.qty[Good.Meat], w.cfg.meat_spoil_bp)
	h.inv.qty[Good.Berries] -= lb
	h.inv.qty[Good.Meat] -= lm
	lost := lb + lm
	if lost > 0 {
		w.acc.food_spoiled += lost
		push_event(w, Event{kind = .Food_Spoiled, h1 = h.id, qty_a = lb, qty_b = lm, good_a = .Berries, good_b = .Meat})
	}
}

kill_household :: proc(w: ^World, h: ^Household) {
	if !h.alive {
		return
	}
	h.alive = false
	h.health = 0
	h.intent_activity = .Rest
	push_event(w, Event{kind = .Household_Died, h1 = h.id})
}

learn_skill :: proc(w: ^World, h: ^Household, sk: Skill_Kind) {
	h.skills[sk] = clamp_i32(h.skills[sk] + w.cfg.learning_bp, w.cfg.skill_min, w.cfg.skill_max)
}

decay_memories :: proc(w: ^World, h: ^Household) {
	keep := i32(BP_SCALE) - w.cfg.memory_decay_bp
	if keep < 0 do keep = 0
	for g in Good {
		h.observed_demand[g] = i32(i64(h.observed_demand[g]) * i64(keep) / 10000)
	}
}

note_demand :: proc(h: ^Household, g: Good, amount: i32) {
	v := h.observed_demand[g] + amount
	if v > 20000 do v = 20000
	if v < 0 do v = 0
	h.observed_demand[g] = v
}

update_labor_history :: proc(h: ^Household) {
	idx := h.labor_hist_idx
	h.labor_hist[idx] = h.labor_today
	h.labor_hist_idx = (idx + 1) % LABOR_HISTORY_DAYS
	h.labor_today = {}
}

labor_totals_30 :: proc(h: ^Household) -> (tot: [SKILL_COUNT]i32, sum: i32) {
	for d in 0 ..< LABOR_HISTORY_DAYS {
		for s in 0 ..< SKILL_COUNT {
			tot[s] += h.labor_hist[d][s]
			sum += h.labor_hist[d][s]
		}
	}
	return
}

update_specialization :: proc(w: ^World, h: ^Household) {
	tot, sum := labor_totals_30(h)
	if sum <= 0 {
		h.specialization_bp = 0
		h.inferred_role = .Generalist
		return
	}
	best_s := 0
	best := tot[0]
	for s in 1 ..< SKILL_COUNT {
		if tot[s] > best {
			best = tot[s]
			best_s = s
		}
	}
	h.specialization_bp = i32(i64(best) * 10000 / i64(sum))
	role: Role = .Generalist
	if h.specialization_bp >= w.cfg.specialization_role_bp {
		role = role_from_activity(Activity(u8(best_s)))
	}
	if role != h.inferred_role && w.day >= LABOR_HISTORY_DAYS {
		push_event(w, Event{kind = .Specialization_Changed, h1 = h.id, role = role, activity = Activity(u8(best_s))})
	}
	h.prev_inferred_role = h.inferred_role
	h.inferred_role = role
}

record_recent_trade :: proc(h: ^Household, rec: Trade_Record) {
	h.recent_trades[h.recent_trade_head] = rec
	h.recent_trade_head = (h.recent_trade_head + 1) % TRADE_MEMORY
	if h.recent_trade_count < TRADE_MEMORY {
		h.recent_trade_count += 1
	}
}

consume_spear_durability :: proc(w: ^World, h: ^Household) {
	if h.inv.qty[Good.Spear] < QTY_SCALE {
		h.spear_durability = 0
		return
	}
	h.spear_durability -= w.cfg.spear_durability_per_hunt
	if h.spear_durability <= 0 {
		h.inv.qty[Good.Spear] -= QTY_SCALE
		if h.inv.qty[Good.Spear] < 0 {
			h.inv.qty[Good.Spear] = 0
		}
		push_event(w, Event{kind = .Spear_Broke, h1 = h.id, activity = .Hunt})
		if h.inv.qty[Good.Spear] >= QTY_SCALE {
			h.spear_durability = w.cfg.spear_durability_max
		} else {
			h.spear_durability = 0
		}
	}
}

grant_spear :: proc(w: ^World, h: ^Household) {
	h.inv.qty[Good.Spear] += QTY_SCALE
	if h.spear_durability <= 0 {
		h.spear_durability = w.cfg.spear_durability_max
	}
}

nearby_households :: proc(w: ^World, cell: Vec2i, radius: i32) -> i32 {
	n: i32
	for h in w.households {
		if !h.alive do continue
		if octile_milli(h.home.x, h.home.y, cell.x, cell.y) <= radius * 1000 {
			n += 1
		}
	}
	return n
}

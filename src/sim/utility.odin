package sim

// Direct household utility of a hypothetical inventory. Used for both
// production scoring and barter. Contains NO exchange-value / proto-money term.

utility_of :: proc(w: ^World, h: ^Household, inv: Inventory, spear_dur: i32) -> i64 {
	cfg := w.cfg
	u: i64
	nut := nutrition_of(inv, cfg)
	u += food_utility(nut, h.preferred_food_nutrition, cfg.nutrition_per_day)
	u += fuel_utility(inv.qty[Good.Wood], cfg.fuel_per_day)
	u += spear_utility(inv, spear_dur, h.skills[Skill_Kind.Hunt], cfg)
	u += stone_utility(inv, h)
	u += wood_craft_utility(inv, h, cfg)
	return u
}

utility_current :: proc(w: ^World, h: ^Household) -> i64 {
	return utility_of(w, h, h.inv, h.spear_durability)
}

food_utility :: proc(nutrition, preferred, daily: i64) -> i64 {
	if daily <= 0 {
		return 0
	}
	days := nutrition * 1000 / daily // 1000 = 1 day
	pref := preferred * 1000 / daily
	if pref < 4000 {
		pref = 4000
	}
	u: i64
	d0 := min(days, 1000)
	u += d0 * 90 // 0-1 day: extreme
	if days > 1000 {
		d1 := min(days, 2000) - 1000
		u += d1 * 12 // 1-2 days: high, but other work can compete
	}
	if days > 2000 {
		d2 := min(days, 4000) - 2000
		u += d2 * 6
	}
	if days > 4000 {
		d3 := min(days, pref) - 4000
		if d3 < 0 do d3 = 0
		u += d3 * 3
	}
	hi := max(pref, 4000)
	if days > hi {
		u += (days - hi) / 4
	}
	return u
}

fuel_utility :: proc(wood, daily: i64) -> i64 {
	if daily <= 0 {
		return 0
	}
	days := wood * 1000 / daily
	u: i64
	d0 := min(days, 1000)
	u += d0 * 22
	if days > 1000 {
		d1 := min(days, 4000) - 1000
		u += d1 * 6
	}
	if days > 4000 {
		d2 := min(days, 10000) - 4000
		u += d2 * 1
	}
	if days > 10000 {
		u += (days - 10000) / 20
	}
	return u
}

spear_utility :: proc(inv: Inventory, spear_dur: i32, hunt_skill: i32, cfg: Config) -> i64 {
	n := spear_count(inv)
	if n <= 0 {
		return 0
	}
	dur := spear_dur
	if dur <= 0 {
		dur = cfg.spear_durability_max / 2
	}
	first := i64(25000) * i64(hunt_skill) / i64(SKILL_AVERAGE) * i64(dur) / i64(cfg.spear_durability_max)
	extra: i64 = 0
	if n >= 2 {
		extra = 3500 * (n - 1)
	}
	return first + extra
}

stone_utility :: proc(inv: Inventory, h: ^Household) -> i64 {
	stone := inv.qty[Good.Stone]
	craft := h.skills[Skill_Kind.Craft]
	hunt := h.skills[Skill_Kind.Hunt]
	wants_tool := spear_count(inv) == 0 && (hunt >= 9000 || craft >= 10500)
	if wants_tool {
		if stone < QTY_SCALE {
			return stone * 12 / 100 // high MU for the first unit
		}
		return 1200 + (stone - QTY_SCALE) / 20
	}
	return stone / 15
}

wood_craft_utility :: proc(inv: Inventory, h: ^Household, cfg: Config) -> i64 {
	// Fuel utility already counts wood. Extra only for the next spear's wood.
	if spear_count(inv) > 0 {
		return 0
	}
	wood := inv.qty[Good.Wood]
	reserve := cfg.fuel_per_day * 4
	spare := wood - reserve
	if spare <= 0 {
		return 0
	}
	if spare < QTY_SCALE {
		return spare / 8
	}
	return 120 + spare / 40
}

marginal_receive :: proc(w: ^World, h: ^Household, g: Good, qty: i64) -> i64 {
	if qty <= 0 {
		return 0
	}
	before := utility_current(w, h)
	inv := h.inv
	dur := h.spear_durability
	inv.qty[g] += qty
	if g == .Spear && dur <= 0 {
		dur = w.cfg.spear_durability_max
	}
	after := utility_of(w, h, inv, dur)
	return after - before
}

marginal_give :: proc(w: ^World, h: ^Household, g: Good, qty: i64) -> i64 {
	if qty <= 0 || h.inv.qty[g] < qty {
		return 0
	}
	before := utility_current(w, h)
	inv := h.inv
	dur := h.spear_durability
	inv.qty[g] -= qty
	if g == .Spear && spear_count(inv) <= 0 {
		dur = 0
	}
	after := utility_of(w, h, inv, dur)
	return before - after // positive = cost of giving
}

directly_wants :: proc(w: ^World, h: ^Household, g: Good) -> bool {
	step := good_def(g).min_trade_qty
	if step <= 0 {
		step = 200
	}
	return marginal_receive(w, h, g, step) > 0
}

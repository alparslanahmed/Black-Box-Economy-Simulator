package sim

// Direct household utility of a hypothetical inventory. Used for both
// production scoring and barter. Contains NO exchange-value / proto-money term.

func UtilityOf(w *World, h *Household, Inv Inventory, spear_dur i32, spare_durability i64) i64 {
	Cfg := w.Cfg
	var u i64
	nut := NutritionOf(Inv, Cfg)
	u += FoodUtility(nut, h.PreferredFoodNutrition, HouseholdDailyNeed(w, h))
	u += FuelUtility(Inv.Qty[Wood], HouseholdFuelNeed(w, h))
	Reserve := spare_durability
	if Reserve < 0 {
		Reserve = SpearCondition(h).Reserve
		added_spares := max(SpearCount(Inv)-1, 0) - max(SpearCount(h.Inv)-1, 0)
		Reserve += added_spares * i64(Cfg.SpearDurabilityMax)
	}
	u += SpearUtility(Inv, spear_dur, h.Skills[Hunt], Cfg, Reserve)
	u += StoneUtility(Inv, h)
	u += WoodCraftUtility(Inv, h, HouseholdFuelNeed(w, h))
	return u
}

func UtilityCurrent(w *World, h *Household) i64 {
	return UtilityOf(w, h, h.Inv, h.SpearDurability, -1)
}

func FoodUtility(Nutrition i64, preferred i64, daily i64) i64 {
	if daily <= 0 {
		return 0
	}
	days := Nutrition * 1000 / daily // 1000 = 1 day
	pref := preferred * 1000 / daily
	if pref < 4000 {
		pref = 4000
	}
	var u i64
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
		if d3 < 0 {
			d3 = 0
		}
		u += d3 * 3
	}
	hi := max(pref, 4000)
	if days > hi {
		u += (days - hi) / 4
	}
	return u
}

func FuelUtility(wood i64, daily i64) i64 {
	if daily <= 0 {
		return 0
	}
	days := wood * 1000 / daily
	var u i64
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

func SpearUtility(Inv Inventory, spear_dur i32, hunt_skill i32, Cfg Config, spare_durability i64) i64 {
	N := SpearCount(Inv)
	if N <= 0 {
		return 0
	}
	dur := spear_dur
	first := i64(25000) * i64(hunt_skill) / i64(SKILL_AVERAGE) * i64(dur) / i64(Cfg.SpearDurabilityMax)
	var extra i64 = 0
	if N >= 2 {
		Reserve := spare_durability
		if Reserve < 0 {
			Reserve = (N - 1) * i64(Cfg.SpearDurabilityMax)
		}
		extra = 3500 * Reserve / i64(Cfg.SpearDurabilityMax)
	}
	return first + extra
}

func StoneUtility(Inv Inventory, h *Household) i64 {
	stone := Inv.Qty[Stone]
	craft := h.Skills[Craft]
	hunt := h.Skills[Hunt]
	wants_tool := SpearCount(Inv) == 0 && (hunt >= 9000 || craft >= 10500)
	if wants_tool {
		if stone < QTY_SCALE {
			return stone * 1200 / QTY_SCALE // continuous at the first whole unit
		}
		return 1200 + (stone-QTY_SCALE)/20
	}
	return stone / 15
}

func WoodCraftUtility(Inv Inventory, h *Household, daily_fuel i64) i64 {
	// Fuel utility already counts wood. Extra only for the next spear's wood.
	if SpearCount(Inv) > 0 {
		return 0
	}
	wood := Inv.Qty[Wood]
	Reserve := daily_fuel * 4
	spare := wood - Reserve
	if spare <= 0 {
		return 0
	}
	if spare < QTY_SCALE {
		return spare / 8
	}
	return 120 + spare/40
}

func MarginalReceive(w *World, h *Household, g Good, Qty i64) i64 {
	if Qty <= 0 {
		return 0
	}
	before := UtilityCurrent(w, h)
	Inv := h.Inv
	dur := h.SpearDurability
	Inv.Qty[g] += Qty
	if g == Spear && dur <= 0 {
		dur = w.Cfg.SpearDurabilityMax
	}
	after := UtilityOf(w, h, Inv, dur, -1)
	return after - before
}

func MarginalGive(w *World, h *Household, g Good, Qty i64) i64 {
	if Qty <= 0 || h.Inv.Qty[g] < Qty {
		return 0
	}
	before := UtilityCurrent(w, h)
	Inv := h.Inv
	dur := h.SpearDurability
	Inv.Qty[g] -= Qty
	Reserve := SpearCondition(h).Reserve
	if g == Spear {
		State, _ := PreviewSpearTransfer(h, nil, Qty)
		dur = State.Active
		Reserve = State.Reserve
	}
	after := UtilityOf(w, h, Inv, dur, Reserve)
	return before - after // positive = cost of giving
}

func DirectlyWants(w *World, h *Household, g Good) bool {
	step := DescribeGood(g).MinTradeQty
	if step <= 0 {
		step = 200
	}
	return MarginalReceive(w, h, g, step) > 0
}

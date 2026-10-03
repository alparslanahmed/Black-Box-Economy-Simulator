package sim

func HasUsableSpear(h *Household) bool {
	return h.Inv.Qty[Spear] >= QTY_SCALE && h.SpearDurability > 0
}

func ConsumeFoodAndFuel(w *World, h *Household) {
	if h == nil || !h.Exists || !h.Alive {
		return
	}
	need := HouseholdDailyNeed(w, h)
	days_before := FoodDaysMilli(NutritionOf(h.Inv, w.Cfg), need)
	for i := i32(0); i < h.MemberCount; i += 1 {
		p := PersonAt(w, h.Members[i])
		if p != nil && p.Alive && p.Pregnant {
			p.PregFoodDaysAcc += days_before
			p.PregDaysCounted += 1
		}
	}

	var got i64
	remain := need
	meat_nut := h.Inv.Qty[Meat] * w.Cfg.MeatNutrition / QTY_SCALE
	if meat_nut > 0 && remain > 0 {
		take_nut := min(meat_nut, remain)
		take_qty := take_nut * QTY_SCALE / w.Cfg.MeatNutrition
		if take_qty > h.Inv.Qty[Meat] {
			take_qty = h.Inv.Qty[Meat]
		}
		h.Inv.Qty[Meat] -= take_qty
		got += take_qty * w.Cfg.MeatNutrition / QTY_SCALE
		remain -= take_qty * w.Cfg.MeatNutrition / QTY_SCALE
	}
	if remain > 0 {
		berry_nut := h.Inv.Qty[Berries] * w.Cfg.BerryNutrition / QTY_SCALE
		take_nut := min(berry_nut, remain)
		take_qty := take_nut * QTY_SCALE / w.Cfg.BerryNutrition
		if take_qty > h.Inv.Qty[Berries] {
			take_qty = h.Inv.Qty[Berries]
		}
		h.Inv.Qty[Berries] -= take_qty
		got += take_qty * w.Cfg.BerryNutrition / QTY_SCALE
		remain -= take_qty * w.Cfg.BerryNutrition / QTY_SCALE
	}

	FuelNeed := HouseholdFuelNeed(w, h)
	fuel_ok := RemoveGood(&h.Inv, Wood, FuelNeed)
	if !fuel_ok {
		h.Inv.Qty[Wood] = 0
	}

	hungry_hh := false
	// Death compacts h.members. Visit the original members exactly once.
	Members := h.Members
	MemberCount := h.MemberCount
	for i := i32(0); i < MemberCount; i += 1 {
		p := PersonAt(w, Members[i])
		if p == nil || !p.Alive {
			continue
		}
		pn := PersonNutritionNeed(w, p)
		var share i64
		if need > 0 {
			share = got * pn / need
		}
		if share < pn {
			hungry_hh = true
		}
		AgeAndHealthEnvironment(w, p, share, pn, fuel_ok)
	}
	if hungry_hh {
		w.Acc.Hungry += 1
		PushEvent(w, Event{Kind: Hunger, H1: h.Id, QtyA: got, QtyB: need - got})
	}
	SyncHouseholdFromMembers(w, h)
	h.LastFoodNutrition = NutritionOf(h.Inv, w.Cfg)
}

func SpoilFood(w *World, h *Household) {
	if h == nil || !h.Exists {
		return
	}
	Spoil := func(Qty i64, bp i32) i64 {
		if Qty <= 0 || bp <= 0 {
			return 0
		}
		lost := Qty * i64(bp) / 10000
		if lost < 1 && Qty > 0 && bp > 0 {
			// deterministic fractional leftover via leftover qty itself; keep at least
			// 1 unit loss when stock is large enough to matter
			if Qty >= 20 {
				lost = 1
			}
		}
		if lost > Qty {
			lost = Qty
		}
		return lost
	}
	lb := Spoil(h.Inv.Qty[Berries], w.Cfg.BerrySpoilBp)
	lm := Spoil(h.Inv.Qty[Meat], w.Cfg.MeatSpoilBp)
	h.Inv.Qty[Berries] -= lb
	h.Inv.Qty[Meat] -= lm
	lost := lb + lm
	if lost > 0 {
		w.Acc.FoodSpoiled += lost
		PushEvent(w, Event{Kind: Food_Spoiled, H1: h.Id, QtyA: lb, QtyB: lm, GoodA: Berries, GoodB: Meat})
	}
}

func KillHousehold(w *World, h *Household) {
	if !h.Alive {
		return
	}
	h.Alive = false
	h.Health = 0
	h.IntentActivity = Rest
	PushEvent(w, Event{Kind: Household_Died, H1: h.Id})
}

func LearnSkill(w *World, h *Household, sk SkillKind) {
	h.Skills[sk] = ClampI32(h.Skills[sk]+w.Cfg.LearningBp, w.Cfg.SkillMin, w.Cfg.SkillMax)
}

func DecayMemories(w *World, h *Household) {
	keep := i32(BP_SCALE) - w.Cfg.MemoryDecayBp
	if keep < 0 {
		keep = 0
	}
	for g := 0; g < GOOD_COUNT; g++ {
		h.ObservedDemand[g] = i32(i64(h.ObservedDemand[g]) * i64(keep) / 10000)
	}
}

func NoteDemand(h *Household, g Good, amount i32) {
	V := h.ObservedDemand[g] + amount
	if V > 20000 {
		V = 20000
	}
	if V < 0 {
		V = 0
	}
	h.ObservedDemand[g] = V
}

func UpdateLaborHistory(h *Household) {
	idx := h.LaborHistIdx
	h.LaborHist[idx] = h.LaborToday
	h.LaborHistIdx = (idx + 1) % LABOR_HISTORY_DAYS
	h.LaborToday = [SKILL_COUNT]i32{}
}

func LaborTotals30(h *Household) (tot [SKILL_COUNT]i32, sum i32) {
	for d := 0; d < LABOR_HISTORY_DAYS; d++ {
		for s := 0; s < SKILL_COUNT; s++ {
			tot[s] += h.LaborHist[d][s]
			sum += h.LaborHist[d][s]
		}
	}
	return
}

func UpdateSpecialization(w *World, h *Household) {
	tot, sum := LaborTotals30(h)
	if sum <= 0 {
		h.SpecializationBp = 0
		h.InferredRole = Generalist
		return
	}
	best_s := 0
	best := tot[0]
	for s := 1; s < SKILL_COUNT; s++ {
		if tot[s] > best {
			best = tot[s]
			best_s = s
		}
	}
	h.SpecializationBp = i32(i64(best) * 10000 / i64(sum))
	var Role Role = Generalist
	if h.SpecializationBp >= w.Cfg.SpecializationRoleBp {
		Role = RoleFromActivity(Activity(u8(best_s)))
	}
	if Role != h.InferredRole && w.Day >= LABOR_HISTORY_DAYS {
		PushEvent(w, Event{Kind: Specialization_Changed, H1: h.Id, Role: Role, Activity: Activity(u8(best_s))})
	}
	h.PrevInferredRole = h.InferredRole
	h.InferredRole = Role
}

func RecordRecentTrade(h *Household, rec TradeRecord) {
	h.RecentTrades[h.RecentTradeHead] = rec
	h.RecentTradeHead = (h.RecentTradeHead + 1) % TRADE_MEMORY
	if h.RecentTradeCount < TRADE_MEMORY {
		h.RecentTradeCount += 1
	}
}

func ConsumeSpearDurability(w *World, h *Household) {
	if h.Inv.Qty[Spear] < QTY_SCALE {
		h.SpearDurability = 0
		return
	}
	h.SpearDurability -= w.Cfg.SpearDurabilityPerHunt
	if h.SpearDurability <= 0 {
		h.Inv.Qty[Spear] -= QTY_SCALE
		if h.Inv.Qty[Spear] < 0 {
			h.Inv.Qty[Spear] = 0
		}
		PushEvent(w, Event{Kind: Spear_Broke, H1: h.Id, Activity: Hunt})
		if h.Inv.Qty[Spear] >= QTY_SCALE {
			h.SpearDurability = pop(&h.SpareSpears)
		} else {
			h.SpearDurability = 0
		}
	}
}

func GrantSpear(w *World, h *Household) {
	ReceiveSpear(h, w.Cfg.SpearDurabilityMax)
}

func NearbyHouseholds(w *World, Cell Vec2i, radius i32) i32 {
	var N i32
	for _, h := range w.Households {
		if !h.Alive {
			continue
		}
		if OctileMilli(h.Home.X, h.Home.Y, Cell.X, Cell.Y) <= radius*1000 {
			N += 1
		}
	}
	return N
}

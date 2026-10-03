package sim

func PlanWorkBlock(w *World, h *Household, actor *Person, available i32) {
	var d Decision
	rest_cell := h.Home
	if !h.Alive || (actor != nil && (!actor.Alive || WorkBlocksFor(actor, w.Cfg) <= 0)) {
		d.Chosen = Rest
		d.CandidateCount = 1
		d.Candidates[0] = DecisionCandidate{
			Activity:   Rest,
			Feasible:   true,
			TargetCell: rest_cell,
			Partner:    -1,
			WorkMin:    max(available, 0),
		}
		ApplyPlan(h, actor, d)
		return
	}

	budget := available
	if budget <= 0 {
		budget = w.Cfg.BlockMinutes
	}

	acts := [DECISION_CANDIDATES]Activity{Forage, Hunt, Gather_Wood, Gather_Stone, Craft_Spear, Rest, Visit}
	best_i := 0
	var best_score i64 = i64(-9223372036854775808)
	var N i32 = 0
	var rest_i i32 = 5

	for i, a := range acts {
		c := ScoreActivity(w, h, a, actor, budget)
		if c.Partner == 0 && a != Visit {
			c.Partner = -1
		}
		d.Candidates[i] = c
		N += 1
		if a == Rest {
			rest_i = i32(i)
		}
		if c.Feasible && c.TotalScore > best_score {
			best_score = c.TotalScore
			best_i = i
		}
	}
	d.CandidateCount = N
	d.ChosenIndex = i32(best_i)
	d.Chosen = d.Candidates[best_i].Activity
	if !d.Candidates[best_i].Feasible {
		d.Chosen = Rest
		d.ChosenIndex = rest_i
	}
	ApplyPlan(h, actor, d)
}

func ApplyPlan(h *Household, actor *Person, d Decision) {
	h.LastDecision = d
	h.IntentActivity = d.Chosen
	idx := d.ChosenIndex
	if idx < 0 || idx >= d.CandidateCount {
		idx = 0
	}
	h.IntentCell = d.Candidates[idx].TargetCell
	if actor != nil {
		actor.LastDecision = d
		actor.IntentActivity = d.Chosen
		actor.IntentCell = d.Candidates[idx].TargetCell
		actor.IntentPartner = d.Candidates[idx].Partner
	}
}

func ScoreActivity(w *World, h *Household, a Activity, actor *Person, available i32) DecisionCandidate {
	var c DecisionCandidate
	c.Activity = a
	c.TargetCell = h.Home
	c.Partner = -1
	budget := available
	if budget <= 0 {
		budget = w.Cfg.BlockMinutes
	}

	hp := h.Health
	if actor != nil {
		hp = actor.Health
	}
	if a == Rest {
		c.Feasible = true
		c.WorkMin = min(i32(180), budget)
		if hp < 5000 {
			c.WorkMin = budget
		}
		c.TotalScore = 40
		if hp < 7000 {
			nut := NutritionOf(h.Inv, w.Cfg)
			need := HouseholdDailyNeed(w, h)
			if nut >= need {
				c.FoodNeed = 180
				c.TotalScore += 180
			}
		}
		if actor != nil && actor.Pregnant {
			c.TotalScore += 120
		}
		if budget < w.Cfg.MinBout {
			c.TotalScore += 400
		}
		// After a full work day, staying home beats a leftover social walk.
		if actor != nil {
			away := actor.MinutesWork + actor.MinutesTravel + actor.MinutesVisit
			if away >= w.Cfg.LaborMinutes/2 {
				c.TotalScore += 280
			}
			if away >= w.Cfg.LaborMinutes*3/4 {
				c.TotalScore += 220
			}
		}
		return c
	}
	if a == Visit {
		return ScoreVisit(w, h, actor, budget)
	}

	sk, has_sk := ActivityToSkill(a)
	Skill := choose(has_sk, ActorSkill(h, actor, sk), SKILL_AVERAGE)
	yield_per_min := ActivityYieldPerMin(w, a)

	if a == Craft_Spear {
		return ScoreCraft(w, h, Skill, actor, budget)
	}

	rk, has_r := ActivityResource(a)
	if !has_r {
		c.Feasible = false
		return c
	}

	Found := FindBestResourceCell(w, h, rk, Skill, yield_per_min, budget, actor)
	if !Found.Found {
		c.Feasible = false
		c.Travel = -400
		c.TotalScore = -1000
		return c
	}
	c.Feasible = true
	c.TargetCell = Found.Cell
	c.WorkMin = Found.Effective
	per := i64(w.Cfg.TravelScorePerMin)
	if per < 1 {
		per = 12
	}
	c.Travel = -i64(Found.Travel) * per
	if Found.Travel > 90 {
		c.Travel -= i64(Found.Travel-90) * 6
	}

	exp_qty := ExpectedOutputQty(w, h, a, Found, Skill)
	c.ExpectedOutput = exp_qty

	Inv := h.Inv
	dur := h.SpearDurability
	g, has_g := ActivityOutputGood(a)
	if has_g && a != Hunt {
		Inv.Qty[g] += exp_qty
	}

	need := HouseholdDailyNeed(w, h)
	food_before := FoodUtility(NutritionOf(h.Inv, w.Cfg), h.PreferredFoodNutrition, need)
	fuel_before := FuelUtility(h.Inv.Qty[Wood], HouseholdFuelNeed(w, h))
	hunt_sk := ActorSkill(h, actor, Hunt)
	tool_before := SpearUtility(h.Inv, h.SpearDurability, hunt_sk, w.Cfg, SpearCondition(h).Reserve)

	if a == Hunt {
		pr := HuntSuccessBp(w, h, hunt_sk)
		success_inv := h.Inv
		success_inv.Qty[Meat] += HuntYieldQty(w, h, Found, Skill)
		FailInv := h.Inv
		u_s := UtilityOf(w, h, success_inv, dur, -1)
		u_f := UtilityOf(w, h, FailInv, dur, -1)
		food_s := FoodUtility(NutritionOf(success_inv, w.Cfg), h.PreferredFoodNutrition, need)
		c.FoodNeed = (food_s - food_before) * i64(pr) / i64(BP_SCALE)
		// Penalize the spread of the two outcomes, weighted by failure probability.
		// Expected utility already accounts for the mean; this is risk aversion.
		spread := max(i64(0), u_s-u_f)
		aversion := i64(12000 - h.RiskPreference)
		if aversion < 2000 {
			aversion = 2000
		}
		c.Risk = -spread * i64(pr) / i64(BP_SCALE) * i64(BP_SCALE-pr) / i64(BP_SCALE) * aversion / 10000
		days := FoodDaysMilli(NutritionOf(h.Inv, w.Cfg), need)
		c.ExpectedOutput = HuntYieldQty(w, h, Found, Skill) * i64(pr) / i64(BP_SCALE)
		c.Skill = i64(Skill-SKILL_AVERAGE) * 12 / 10
		c.TradeDemand = TradeDemandComponent(h, Meat, c.ExpectedOutput, days)
		c.Input = 0
		c.Tool = 0
		if HasUsableSpear(h) {
			c.Tool = 220
		}
		c.TotalScore = c.FoodNeed + c.FuelNeed + c.Tool + c.Input + c.TradeDemand + c.Skill + c.Travel + c.Risk
		return c
	}

	food_after := FoodUtility(NutritionOf(Inv, w.Cfg), h.PreferredFoodNutrition, need)
	fuel_after := FuelUtility(Inv.Qty[Wood], HouseholdFuelNeed(w, h))
	tool_after := SpearUtility(Inv, dur, hunt_sk, w.Cfg, SpearCondition(h).Reserve)

	c.FoodNeed = food_after - food_before
	c.FuelNeed = fuel_after - fuel_before
	c.Tool = tool_after - tool_before
	if a == Gather_Stone {
		c.Input = StoneUtility(Inv, h) - StoneUtility(h.Inv, h)
	}
	if a == Gather_Wood {
		fuel := HouseholdFuelNeed(w, h)
		c.Input += WoodCraftUtility(Inv, h, fuel) - WoodCraftUtility(h.Inv, h, fuel)
	}
	days := FoodDaysMilli(NutritionOf(h.Inv, w.Cfg), need)
	c.TradeDemand = TradeDemandComponent(h, g, exp_qty, days)
	c.Skill = i64(Skill-SKILL_AVERAGE) * 12 / 10
	c.Tool += ToolPlanComponent(w, h, a, days, actor)
	c.TotalScore = c.FoodNeed + c.FuelNeed + c.Tool + c.Input + c.TradeDemand + c.Skill + c.Travel + c.Risk
	return c
}

func ToolPlanComponent(w *World, h *Household, a Activity, food_days i64, actor *Person) i64 {
	if SpearCount(h.Inv) > 0 {
		return 0
	}
	if food_days < 1000 {
		return 0
	}
	hunt := ActorSkill(h, actor, Hunt)
	craft := ActorSkill(h, actor, Craft)
	if hunt < 8500 && craft < 10800 {
		return 0
	}
	need_stone := h.Inv.Qty[Stone] < w.Cfg.SpearStoneCost
	fuel_reserve := HouseholdFuelNeed(w, h) * 4
	need_wood := h.Inv.Qty[Wood] < fuel_reserve+w.Cfg.SpearWoodCost
	switch a {
	case Gather_Stone:
		if need_stone {
			return 4200
		}
	case Gather_Wood:
		if need_wood {
			return 3200
		}
	case Forage, Hunt, Craft_Spear, Rest, Visit:
	}
	return 0
}

func ScoreCraft(w *World, h *Household, Skill i32, actor *Person, available i32) DecisionCandidate {
	var c DecisionCandidate
	c.Activity = Craft_Spear
	c.TargetCell = h.Home
	c.Partner = -1
	work := available
	if work <= 0 || work > w.Cfg.BlockMinutes {
		work = w.Cfg.BlockMinutes
	}
	c.WorkMin = work
	if h.Inv.Qty[Wood] < w.Cfg.SpearWoodCost || h.Inv.Qty[Stone] < w.Cfg.SpearStoneCost {
		c.Feasible = false
		c.TotalScore = -800
		c.Input = -200
		return c
	}
	c.Feasible = true
	progress := i32(i64(work) * i64(Skill) / i64(SKILL_AVERAGE))
	will_finish := h.CraftProgress+progress >= w.Cfg.CraftProgressNeeded

	Inv := h.Inv
	dur := h.SpearDurability
	c.Input = -80
	if will_finish {
		Inv.Qty[Wood] -= w.Cfg.SpearWoodCost
		Inv.Qty[Stone] -= w.Cfg.SpearStoneCost
		Inv.Qty[Spear] += QTY_SCALE
		if dur <= 0 {
			dur = w.Cfg.SpearDurabilityMax
		}
		c.ExpectedOutput = QTY_SCALE
		Reserve := SpearCondition(h).Reserve
		if SpearCount(h.Inv) > 0 {
			Reserve += i64(w.Cfg.SpearDurabilityMax)
		}
		c.Tool = SpearUtility(Inv, dur, ActorSkill(h, actor, Hunt), w.Cfg, Reserve) -
			SpearUtility(h.Inv, h.SpearDurability, ActorSkill(h, actor, Hunt), w.Cfg, SpearCondition(h).Reserve)
		c.FuelNeed = FuelUtility(Inv.Qty[Wood], HouseholdFuelNeed(w, h)) -
			FuelUtility(h.Inv.Qty[Wood], HouseholdFuelNeed(w, h))
		c.Input += StoneUtility(Inv, h) - StoneUtility(h.Inv, h)
	} else {
		need := SpearUtility(Inventory{Qty: [GOOD_COUNT]i64{0, 0, 0, 0, QTY_SCALE}}, w.Cfg.SpearDurabilityMax, ActorSkill(h, actor, Hunt), w.Cfg, -1) - SpearUtility(h.Inv, h.SpearDurability, ActorSkill(h, actor, Hunt), w.Cfg, SpearCondition(h).Reserve)
		frac := i64(progress) * 1000 / i64(w.Cfg.CraftProgressNeeded)
		c.Tool = need * frac / 1800
		c.ExpectedOutput = 0
	}

	days := FoodDaysMilli(NutritionOf(h.Inv, w.Cfg), HouseholdDailyNeed(w, h))
	c.TradeDemand = TradeDemandComponent(h, Spear, choose(will_finish, i64(QTY_SCALE), i64(0)), days)
	c.Skill = i64(Skill-SKILL_AVERAGE) * 12 / 10
	if days < 1000 {
		c.FoodNeed = -2800 // don't craft while starving
	} else if days < 1300 {
		c.FoodNeed = -700
	}
	c.TotalScore = c.FoodNeed + c.FuelNeed + c.Tool + c.Input + c.TradeDemand + c.Skill + c.Travel + c.Risk
	return c
}

func ScoreVisit(w *World, h *Household, actor *Person, available i32) DecisionCandidate {
	var c DecisionCandidate
	c.Activity = Visit
	c.TargetCell = h.Home
	c.Partner = -1
	c.WorkMin = w.Cfg.VisitLinger

	if !w.TradeEnabled || actor == nil || !actor.Alive {
		c.Feasible = false
		c.TotalScore = -2000
		return c
	}
	if actor.VisitsToday >= w.Cfg.MaxVisitsPerDay || h.VisitsToday >= 1 {
		c.Feasible = false
		c.TotalScore = -1800
		return c
	}
	linger := w.Cfg.VisitLinger
	if linger < 15 {
		linger = 15
	}
	if available < linger+2 {
		c.Feasible = false
		c.TotalScore = -1600
		return c
	}

	need := HouseholdDailyNeed(w, h)
	days := FoodDaysMilli(NutritionOf(h.Inv, w.Cfg), need)
	speed := PersonWalkSpeedBp(actor, w.Cfg)
	per := i64(w.Cfg.TravelScorePerMin)
	if per < 1 {
		per = 12
	}

	// You do not see the other camp's stores. You walk because YOU need
	// something and YOU can spare something, and maybe you remember a neighbor.
	var need_strength i64
	var surplus_strength i64
	var food_need_part i64
	best_surplus_good := Wood
	var best_surplus i64 = -1
	for g := 0; g < GOOD_COUNT; g++ {
		def := DescribeGood(g)
		if def.MinTradeQty > 0 {
			rec := MarginalReceive(w, h, g, def.MinTradeQty*2)
			// A first spear is hugely useful at home, but that is not a reason
			// to walk to every neighbor every day hoping they have one.
			if g == Spear {
				rec = min(rec, 1400)
			}
			if rec > need_strength {
				need_strength = rec
			}
			if g == Berries || g == Meat {
				if rec > food_need_part {
					food_need_part = rec
				}
			}
		}
		if h.Inv.Qty[g] >= def.MinTradeQty {
			give_cost := MarginalGive(w, h, g, def.MinTradeQty)
			spare := 1100 - min(give_cost, 1100)
			if spare < 0 {
				spare = 0
			}
			// Only real surplus: giving it barely hurts.
			if give_cost > 700 {
				spare = spare / 4
			}
			spare += i64(h.ObservedDemand[g]) / 3
			if spare > best_surplus {
				best_surplus = spare
				best_surplus_good = g
				surplus_strength = spare
			}
		}
	}
	if need_strength < 700 || surplus_strength < 400 {
		c.Feasible = false
		c.TotalScore = -1400
		return c
	}

	var best_id i32 = -1
	var best_score i64 = i64(-9223372036854775808)
	best_cell := h.Home
	var best_travel i32
	var best_demand i64
	Found := false

	for i := 0; i < len(w.Households); i++ {
		o := &w.Households[i]
		if !o.Exists || !o.Alive || o.Id == h.Id {
			continue
		}
		milli := OctileMilli(h.Home.X, h.Home.Y, o.Home.X, o.Home.Y)
		dist := milli / 1000
		if dist > w.Cfg.TradeRadius {
			continue
		}
		one := WalkMinutes(w.Cfg, h.Home.X, h.Home.Y, o.Home.X, o.Home.Y, speed)
		cost := one*2 + linger
		if cost > available {
			continue
		}

		travel_pen := i64(one*2) * per
		if one*2 > 60 {
			travel_pen += i64(one*2-60) * 10
		}
		// Hungry people will not wander far unless they are going for food.
		if days < 1200 && food_need_part < 800 {
			travel_pen = travel_pen * 2
		} else if days < 1200 {
			travel_pen = travel_pen * 5 / 4
		}

		openness := i64(h.TradeOpenness+o.TradeOpenness) / 50
		var known i64
		ntr := int(h.RecentTradeCount)
		for k := 0; k < ntr; k += 1 {
			idx := (int(h.RecentTradeHead) - ntr + k + TRADE_MEMORY) % TRADE_MEMORY
			tr := h.RecentTrades[idx]
			if tr.Partner == o.Id && tr.Success {
				known += 320
			}
		}
		mem := i64(h.ObservedDemand[best_surplus_good]) / 3
		// Work first on a normal day; leftover evening walks need a stronger reason.
		var opp i64 = 900
		if actor.BlocksThisDay == 0 && days >= 1200 {
			opp += 500
		}
		if actor.MinutesWork+actor.MinutesTravel >= w.Cfg.LaborMinutes/2 {
			opp += 400
		}

		s := need_strength*5/10 + surplus_strength + openness + known + mem - travel_pen - opp
		if s < 700 {
			continue
		}
		if !Found || s > best_score {
			Found = true
			best_score = s
			best_id = o.Id
			best_cell = o.Home
			best_travel = one * 2
			best_demand = known + mem
		}
	}

	if !Found || best_id < 0 {
		c.Feasible = false
		c.TotalScore = -1500
		return c
	}

	c.Feasible = true
	c.Partner = best_id
	c.TargetCell = best_cell
	c.WorkMin = linger
	c.Travel = -i64(best_travel) * per
	if best_travel > 60 {
		c.Travel -= i64(best_travel-60) * 10
	}
	c.FoodNeed = min(food_need_part*6/10, 5000)
	c.TradeDemand = best_demand
	c.TotalScore = best_score
	return c
}

func TradeDemandComponent(h *Household, g Good, expected_qty i64, FoodDaysMilli i64) i64 {
	if expected_qty <= 0 {
		return 0
	}
	mem := i64(h.ObservedDemand[g])
	if mem <= 0 {
		return 0
	}
	var attention i64 = 10000
	if FoodDaysMilli < 2000 {
		attention = 2500
	} else if FoodDaysMilli < 3000 {
		attention = 6000
	}
	return mem * expected_qty * attention / (QTY_SCALE * 10000 * 4)
}

func ActivityYieldPerMin(w *World, a Activity) i64 {
	switch a {
	case Forage:
		return w.Cfg.ForageYieldPerMin
	case Gather_Wood:
		return w.Cfg.WoodYieldPerMin
	case Gather_Stone:
		return w.Cfg.StoneYieldPerMin
	case Hunt:
		return w.Cfg.HuntYieldSpear / 200 // search heuristic only
	case Craft_Spear, Rest, Visit:
		return 0
	}
	return 0
}

func ExpectedOutputQty(w *World, h *Household, a Activity, Found FindResult, Skill i32) i64 {
	ypm := ActivityYieldPerMin(w, a)
	raw := i64(Found.Effective) * ypm * i64(Skill) / i64(SKILL_AVERAGE)
	return min(raw, Found.Stock)
}

func HuntSuccessBp(w *World, h *Household, hunt_skill i32) i32 {
	base := w.Cfg.HuntPNoSpear
	if HasUsableSpear(h) {
		base = w.Cfg.HuntPSpear
	}
	sk := hunt_skill
	if sk == 0 {
		sk = h.Skills[Hunt]
	}
	delta := sk - SKILL_AVERAGE
	p := base + delta*w.Cfg.HuntSkillPScale/SKILL_AVERAGE
	return ClampI32(p, 1200, 9000)
}

func HuntYieldQty(w *World, h *Household, Found FindResult, Skill i32) i64 {
	base := w.Cfg.HuntYieldNoSpear
	if HasUsableSpear(h) {
		base = w.Cfg.HuntYieldSpear
	}
	Y := base * i64(Skill) / i64(SKILL_AVERAGE)
	Y = Y * i64(Found.Effective) / i64(w.Cfg.BlockMinutes)
	return min(Y, Found.Stock)
}

func SortDecisionCandidates(d *Decision) {
	N := int(d.CandidateCount)
	for i := 0; i < N; i++ {
		best := i
		for j := i + 1; j < N; j += 1 {
			if d.Candidates[j].TotalScore > d.Candidates[best].TotalScore {
				best = j
			}
		}
		if best != i {
			d.Candidates[i], d.Candidates[best] = d.Candidates[best], d.Candidates[i]
			if i32(i) == d.ChosenIndex {
				d.ChosenIndex = i32(best)
			} else if i32(best) == d.ChosenIndex {
				d.ChosenIndex = i32(i)
			}
		}
	}
}

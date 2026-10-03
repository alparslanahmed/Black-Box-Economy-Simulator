package sim

func ExecuteActivity(w *World, h *Household, a Activity, Cell Vec2i, actor *Person, WorkMin i32, Partner i32) {
	if a == Rest {
		return
	}
	if a == Visit {
		ExecuteVisit(w, h, actor, Partner)
		PushEvent(w, Event{Kind: Work_Completed, H1: h.Id, H2: Partner, Activity: a, Cell: Cell})
		return
	}

	labor := WorkMin
	if labor <= 0 {
		Travel := TravelMinutes(w.Cfg, h.Home.X, h.Home.Y, Cell.X, Cell.Y)
		labor = w.Cfg.BlockMinutes - Travel
	}
	if labor < 0 {
		labor = 0
	}

	sk, ok := ActivityToSkill(a)
	if ok && labor > 0 {
		h.LaborToday[sk] += labor
		if actor != nil {
			LearnPersonSkill(w, actor, sk)
		} else {
			LearnSkill(w, h, sk)
		}
	}

	forage_sk := ActorSkill(h, actor, Forage)
	wood_sk := ActorSkill(h, actor, Wood)
	stone_sk := ActorSkill(h, actor, Stone)

	switch a {
	case Forage:
		GatherFromMap(w, h, Cell, Berry, Berries, w.Cfg.ForageYieldPerMin, forage_sk, labor)
	case Gather_Wood:
		GatherFromMap(w, h, Cell, Wood, Wood, w.Cfg.WoodYieldPerMin, wood_sk, labor)
	case Gather_Stone:
		GatherFromMap(w, h, Cell, Stone, Stone, w.Cfg.StoneYieldPerMin, stone_sk, labor)
	case Hunt:
		ExecuteHunt(w, h, Cell, actor, labor)
	case Craft_Spear:
		ExecuteCraft(w, h, actor, labor)
	case Rest, Visit:
	}

	PushEvent(w, Event{Kind: Work_Completed, H1: h.Id, H2: Partner, Activity: a, Cell: Cell})
}

func ExecuteVisit(w *World, h *Household, actor *Person, Partner i32) {
	if !w.TradeEnabled || h == nil || !h.Alive {
		return
	}
	if Partner < 0 || Partner >= i32(len(w.Households)) {
		return
	}
	other := &w.Households[Partner]
	if !other.Exists || !other.Alive {
		return
	}
	res := AttemptBarter(w, h, other)
	RecordAttempt(w, h, other, res)
	h.VisitsToday += 1
	if actor != nil {
		actor.TradeHh = Partner
		actor.VisitsToday += 1
	}
	w.Acc.Visits += 1
}

func GatherFromMap(w *World, h *Household, Cell Vec2i, r ResourceKind, g Good, ypm i64, Skill i32, WorkMin i32) {
	if !InBounds(w, Cell.X, Cell.Y) || WorkMin <= 0 {
		return
	}
	raw := i64(WorkMin) * ypm * i64(Skill) / i64(SKILL_AVERAGE)
	got := ExtractStock(w, Cell, r, raw)
	if got > 0 {
		AddGood(&h.Inv, g, got)
		w.Acc.Produced[g] += got
	}
}

func ExecuteHunt(w *World, h *Household, Cell Vec2i, actor *Person, WorkMin i32) {
	eff := WorkMin
	if eff <= 0 {
		Travel := TravelMinutes(w.Cfg, h.Home.X, h.Home.Y, Cell.X, Cell.Y)
		eff = w.Cfg.BlockMinutes - Travel
	}
	if eff <= 0 {
		return
	}
	used_spear := HasUsableSpear(h)
	Skill := ActorSkill(h, actor, Hunt)
	p := HuntSuccessBp(w, h, Skill)
	Success := RngChanceBp(&w.Rng, p)

	if used_spear {
		ConsumeSpearDurability(w, h)
	}

	if !Success {
		PushEvent(w, Event{Kind: Hunt_Failed, H1: h.Id, Cell: Cell})
		return
	}

	base := w.Cfg.HuntYieldNoSpear
	if used_spear {
		base = w.Cfg.HuntYieldSpear
	}
	Y := base * i64(Skill) / i64(SKILL_AVERAGE)
	Y = Y * i64(eff) / i64(w.Cfg.BlockMinutes)
	got := ExtractStock(w, Cell, Game, Y)
	if got > 0 {
		AddGood(&h.Inv, Meat, got)
		w.Acc.Produced[Meat] += got
	}
	PushEvent(w, Event{Kind: Hunt_Succeeded, H1: h.Id, Cell: Cell, QtyA: got, GoodA: Meat})
}

func ExecuteCraft(w *World, h *Household, actor *Person, WorkMin i32) {
	if h.Inv.Qty[Wood] < w.Cfg.SpearWoodCost || h.Inv.Qty[Stone] < w.Cfg.SpearStoneCost {
		return
	}
	labor := WorkMin
	if labor <= 0 {
		labor = w.Cfg.BlockMinutes
	}
	Skill := ActorSkill(h, actor, Craft)
	h.CraftProgress += i32(i64(labor) * i64(Skill) / i64(SKILL_AVERAGE))
	if h.CraftProgress >= w.Cfg.CraftProgressNeeded {
		if !RemoveGood(&h.Inv, Wood, w.Cfg.SpearWoodCost) {
			return
		}
		if !RemoveGood(&h.Inv, Stone, w.Cfg.SpearStoneCost) {
			AddGood(&h.Inv, Wood, w.Cfg.SpearWoodCost)
			return
		}
		GrantSpear(w, h)
		h.CraftProgress -= w.Cfg.CraftProgressNeeded
		if h.CraftProgress < 0 {
			h.CraftProgress = 0
		}
		w.Acc.Produced[Spear] += QTY_SCALE
		PushEvent(w, Event{Kind: Spear_Crafted, H1: h.Id, GoodA: Spear, QtyA: QTY_SCALE})
	}
}

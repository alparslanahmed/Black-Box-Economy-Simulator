package sim

func SimDay(w *World) {
	w.Acc = DayAcc{}
	Day := w.Cfg.DayMinutes
	if Day <= 0 {
		Day = DAY_MINUTES
	}

	RegenResources(w)

	for index_h := range w.Households {
		h := &w.Households[index_h]
		if h.Exists && h.Alive {
			DecayMemories(w, h)
			SyncHouseholdFromMembers(w, h)
		}
	}

	for index_h := range w.Households {
		h := &w.Households[index_h]
		if h.Exists {
			h.LaborToday = [SKILL_COUNT]i32{}
			h.VisitsToday = 0
		}
	}

	for i := i32(0); i < w.PersonCount; i += 1 {
		BeginPersonDay(w, &w.People[i], Day)
	}

	MaxBouts := w.Cfg.MaxBouts
	if MaxBouts < 1 {
		MaxBouts = 1
	}
	N := w.PersonCount
	for _bout := i32(0); _bout < MaxBouts; _bout += 1 {
		if N <= 0 {
			break
		}
		for i := i32(0); i < N; i += 1 {
			w.PersonOrder[i] = i
		}
		RngShuffleI32(&w.Rng, w.PersonOrder[:N])
		for _, idx := range w.PersonOrder[:N] {
			RunPersonBout(w, &w.People[idx], Day)
		}
	}

	for i := i32(0); i < w.PersonCount; i += 1 {
		EndPersonDay(w, &w.People[i], Day)
	}

	for index_h := range w.Households {
		h := &w.Households[index_h]
		if h.Exists {
			ConsumeFoodAndFuel(w, h)
		}
	}
	for index_h := range w.Households {
		h := &w.Households[index_h]
		if h.Exists {
			SpoilFood(w, h)
		}
	}

	TickPeople(w)
	RunMarriagePhase(w)
	for index_h := range w.Households {
		h := &w.Households[index_h]
		if h.Exists && h.Alive {
			TryConceive(w, h)
			SyncHouseholdFromMembers(w, h)
		}
	}

	for index_h := range w.Households {
		h := &w.Households[index_h]
		if h.Exists && h.Alive {
			UpdateLaborHistory(h)
			UpdateSpecialization(w, h)
		}
	}

	m := ComputeMetrics(w)
	PushMetrics(w, m)

	AssertInvariants(w)

	w.Day += 1
}

func BeginPersonDay(w *World, p *Person, Day i32) {
	h := &w.Households[p.Household]
	hx, hy := PersonHomeMilli(h, p)
	PathReset(p, hx, hy)
	p.IntentActivity = Rest
	p.IntentCell = h.Home
	p.IntentPartner = -1
	p.BlocksThisDay = 0
	p.MinutesSleep = 0
	p.MinutesHome = 0
	p.MinutesWork = 0
	p.MinutesTravel = 0
	p.MinutesVisit = 0
	p.VisitsToday = 0
	p.TradeHh = -1
	p.Clock = 0

	if !p.Alive {
		PathPush(p, hx, hy, 10000, Sleep, Rest)
		p.MinutesHome = Day
		p.Clock = Day
		p.SleepStart = Day
		p.WakeMin = 0
		return
	}

	wake, SleepStart := PersonWakeWindow(w.Cfg, p)
	p.WakeMin = wake
	p.SleepStart = SleepStart

	if !CanWork(p, w.Cfg) || !h.Alive {
		p.MinutesSleep = PersonSleepMinutes(w.Cfg, p)
		if p.MinutesSleep > Day {
			p.MinutesSleep = Day
		}
		p.MinutesHome = Day - p.MinutesSleep
		PathPush(p, hx, hy, ClockToT(wake, Day), Sleep, Rest)
		PathPush(p, hx, hy, 10000, At_Home, Rest)
		p.Clock = Day
		return
	}

	PathPush(p, hx, hy, ClockToT(wake, Day), Sleep, Rest)
	p.MinutesSleep += wake
	p.Clock = wake

	morn := w.Cfg.MorningHome
	if p.Clock+morn > p.SleepStart {
		morn = p.SleepStart - p.Clock
	}
	if morn < 0 {
		morn = 0
	}
	if morn > 0 {
		p.Clock += morn
		p.MinutesHome += morn
		PathPush(p, hx, hy, ClockToT(p.Clock, Day), At_Home, Rest)
	}
}

func RunPersonBout(w *World, p *Person, Day i32) {
	if !p.Alive || !CanWork(p, w.Cfg) {
		return
	}
	h := &w.Households[p.Household]
	if !h.Exists || !h.Alive {
		return
	}
	remaining := p.SleepStart - p.Clock
	away := p.MinutesWork + p.MinutesTravel + p.MinutesVisit
	left_cap := WorkMinutesCap(w.Cfg, p) - away
	if left_cap < remaining {
		remaining = left_cap
	}
	if remaining < w.Cfg.MinBout {
		return
	}

	PlanWorkBlock(w, h, p, remaining)
	p.BlocksThisDay += 1

	idx := p.LastDecision.ChosenIndex
	if idx < 0 || idx >= p.LastDecision.CandidateCount {
		idx = 0
	}
	Chosen := p.LastDecision.Candidates[idx]
	work := Chosen.WorkMin
	ExecuteActivity(w, h, p.IntentActivity, p.IntentCell, p, work, p.IntentPartner)
	ApplyBoutPath(w, p, h, p.IntentActivity, p.IntentCell, work, p.IntentPartner, Day)
}

func ApplyBoutPath(w *World, p *Person, h *Household, a Activity, Cell Vec2i, WorkMin i32, Partner i32, Day i32) {
	hx, hy := PersonHomeMilli(h, p)
	labor := WorkMin
	if labor < 0 {
		labor = 0
	}

	switch a {
	case Rest:
		p.Clock += labor
		p.MinutesHome += labor
		PathPush(p, hx, hy, ClockToT(p.Clock, Day), At_Home, Rest)
	case Craft_Spear:
		p.Clock += labor
		p.MinutesWork += labor
		PathPush(p, hx, hy, ClockToT(p.Clock, Day), Working, Craft_Spear)
	case Visit:
		ox, oy := hx, hy
		if Partner >= 0 && Partner < i32(len(w.Households)) {
			ox, oy = MapMilli(w.Households[Partner].Home)
		} else {
			ox, oy = MapMilli(Cell)
		}
		one := PersonWalkMinutes(w.Cfg, p, h.Home.X, h.Home.Y, Cell.X, Cell.Y)
		linger := labor
		if linger <= 0 {
			linger = w.Cfg.VisitLinger
		}
		p.Clock += one
		p.MinutesTravel += one
		PathPush(p, ox, oy, ClockToT(p.Clock, Day), Visiting, Visit)
		p.Clock += linger
		p.MinutesVisit += linger
		PathPush(p, ox, oy, ClockToT(p.Clock, Day), Visiting, Visit)
		p.Clock += one
		p.MinutesTravel += one
		PathPush(p, hx, hy, ClockToT(p.Clock, Day), At_Home, Rest)
	case Forage, Hunt, Gather_Wood, Gather_Stone:
		wx, wy := MapMilli(Cell)
		one := PersonWalkMinutes(w.Cfg, p, h.Home.X, h.Home.Y, Cell.X, Cell.Y)
		p.Clock += one
		p.MinutesTravel += one
		PathPush(p, wx, wy, ClockToT(p.Clock, Day), Working, a)
		p.Clock += labor
		p.MinutesWork += labor
		PathPush(p, wx, wy, ClockToT(p.Clock, Day), Working, a)
		p.Clock += one
		p.MinutesTravel += one
		PathPush(p, hx, hy, ClockToT(p.Clock, Day), At_Home, Rest)
	}
	if p.Clock > Day {
		p.Clock = Day
	}
}

func EndPersonDay(w *World, p *Person, Day i32) {
	if !p.Alive {
		return
	}
	h := &w.Households[p.Household]
	hx, hy := PersonHomeMilli(h, p)
	if p.Clock < p.SleepStart {
		stay := p.SleepStart - p.Clock
		p.MinutesHome += stay
		p.Clock = p.SleepStart
		PathPush(p, hx, hy, ClockToT(p.Clock, Day), At_Home, Rest)
	}
	if p.Clock < Day {
		p.MinutesSleep += Day - p.Clock
		p.Clock = Day
	}
	PathPush(p, hx, hy, 10000, Sleep, Rest)
	ApplyTravelFatigue(w, p)
	w.Acc.TravelMinutesTotal += p.MinutesTravel
}

func SimDays(w *World, N i32) {
	for iteration1 := 0; iteration1 < N; iteration1++ {
		SimDay(w)
	}
}

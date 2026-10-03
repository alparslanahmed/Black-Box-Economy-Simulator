package sim

func PersonAt(w *World, Id i32) *Person {
	if Id < 0 || int(Id) >= int(w.PersonCount) {
		return nil
	}
	return &w.People[Id]
}

func LifeStageOf(p *Person, DaysPerYear i32) LifeStage {
	if p == nil || !p.Alive {
		return Elder
	}
	Y := p.AgeDays / DaysPerYear
	switch {
	case Y < YEARS_INFANT:
		return Infant
	case Y < YEARS_CHILD:
		return Child
	case Y < YEARS_YOUTH:
		return Youth
	case Y < YEARS_ELDER:
		return Adult
	}
	return Elder
}

func LifeStageName(s LifeStage) string {
	switch s {
	case Infant:
		return "infant"
	case Child:
		return "child"
	case Youth:
		return "youth"
	case Adult:
		return "adult"
	case Elder:
		return "elder"
	}
	return "?"
}

func SexName(s Sex) string {
	switch s {
	case Male:
		return "man"
	case Female:
		return "woman"
	}
	return "?"
}

func AgeYears(p *Person, DaysPerYear i32) i32 {
	if p == nil {
		return 0
	}
	return p.AgeDays / DaysPerYear
}

// Mouths to feed, as a fraction of one adult daily nutrition. 1000 = 1 adult.
func PersonNeedMilli(p *Person, Cfg Config) i32 {
	if p == nil || !p.Alive {
		return 0
	}
	var base i32
	switch LifeStageOf(p, Cfg.DaysPerYear) {
	case Infant:
		base = 400
	case Child:
		base = 700
	case Youth:
		base = 900
	case Adult:
		base = 1000
	case Elder:
		base = 850
	}
	if p.Pregnant {
		base = base * 12 / 10
	}
	return base
}

func PersonNutritionNeed(w *World, p *Person) i64 {
	return w.Cfg.NutritionPerDay * i64(PersonNeedMilli(p, w.Cfg)) / 1000
}

func HouseholdDailyNeed(w *World, h *Household) i64 {
	var s i64
	for i := i32(0); i < h.MemberCount; i += 1 {
		p := PersonAt(w, h.Members[i])
		if p != nil && p.Alive {
			s += PersonNutritionNeed(w, p)
		}
	}
	if s <= 0 {
		return w.Cfg.NutritionPerDay
	}
	return s
}

func HouseholdFuelNeed(w *World, h *Household) i64 {
	N := LivingMembers(w, h)
	extra := N - 2
	if extra < 0 {
		extra = 0
	}
	return w.Cfg.FuelPerDay + i64(extra)*80
}

func LivingMembers(w *World, h *Household) i32 {
	var N i32
	for i := i32(0); i < h.MemberCount; i += 1 {
		p := PersonAt(w, h.Members[i])
		if p != nil && p.Alive {
			N += 1
		}
	}
	return N
}

func WorkBlocksFor(p *Person, Cfg Config) i32 {
	if p == nil || !p.Alive {
		return 0
	}
	switch LifeStageOf(p, Cfg.DaysPerYear) {
	case Infant, Child:
		return 0
	case Youth, Elder:
		return 1
	case Adult:
		if p.Pregnant && p.PregnancyDays > Cfg.PregnancyDays-60 {
			return 1
		}
		if p.Health < 3500 {
			return 1
		}
		return 2
	}
	return 0
}

func CanWork(p *Person, Cfg Config) bool {
	return WorkBlocksFor(p, Cfg) > 0
}

// Cap on work + walking + visiting for the day. Sleep and home time are separate.
func WorkMinutesCap(Cfg Config, p *Person) i32 {
	blocks := WorkBlocksFor(p, Cfg)
	if blocks <= 0 {
		return 0
	}
	cap := Cfg.LaborMinutes
	if blocks == 1 {
		cap = cap * 6 / 10
	}
	if p.Health < 5000 && blocks == 2 {
		cap = cap * 8 / 10
	}
	if cap < 120 {
		cap = 120
	}
	return cap
}

func PersonSleepMinutes(Cfg Config, p *Person) i32 {
	if p == nil || !p.Alive {
		return Cfg.SleepBase
	}
	s := Cfg.SleepBase
	switch LifeStageOf(p, Cfg.DaysPerYear) {
	case Infant:
		s = Cfg.SleepBase + 240
	case Child:
		s = Cfg.SleepBase + 120
	case Youth:
		s += Cfg.SleepYouthExtra
	case Adult:
	case Elder:
		s += Cfg.SleepElderExtra
	}
	if p.Health < 4000 {
		s += Cfg.SleepSickExtra
	} else if p.Health < 6000 {
		s += Cfg.SleepSickExtra / 2
	}
	if p.Pregnant && p.PregnancyDays > Cfg.PregnancyDays-90 {
		s += 60
	}
	Day := Cfg.DayMinutes
	if Day <= 0 {
		Day = DAY_MINUTES
	}
	if s < 360 {
		s = 360
	}
	if s > Day-240 {
		s = Day - 240
	}
	if s < 0 {
		s = 0
	}
	return s
}

// Wake after the night portion of sleep; sleep_start is when they must be home.
func PersonWakeWindow(Cfg Config, p *Person) (wake i32, SleepStart i32) {
	Day := Cfg.DayMinutes
	if Day <= 0 {
		Day = DAY_MINUTES
	}
	sleep := PersonSleepMinutes(Cfg, p)
	pre := sleep * 3 / 4
	wake = pre
	SleepStart = Day - (sleep - pre)
	if SleepStart <= wake+240 {
		SleepStart = wake + 240
		if SleepStart > Day {
			SleepStart = Day
		}
	}
	return
}

// Walking speeds stay close; distance is what makes trips long.
func PersonWalkSpeedBp(p *Person, Cfg Config) i32 {
	if p == nil || !p.Alive {
		return BP_SCALE
	}
	var sp i32 = 10000
	switch LifeStageOf(p, Cfg.DaysPerYear) {
	case Infant, Child:
		sp = 7000
	case Youth:
		sp = 9200
	case Adult:
		sp = 10000
	case Elder:
		sp = 8200
	}
	con := ClampI32(p.Constitution, 8000, 12000)
	sp = sp * con / 10000
	if p.Health < 5000 {
		sp = sp * (5000 + p.Health) / 10000
	}
	if p.Pregnant && p.PregnancyDays > Cfg.PregnancyDays-90 {
		sp = sp * 78 / 100
	}
	return ClampI32(sp, 5500, 12000)
}

func PersonWalkMinutes(Cfg Config, p *Person, ax i32, ay i32, bx i32, by i32) i32 {
	return WalkMinutes(Cfg, ax, ay, bx, by, PersonWalkSpeedBp(p, Cfg))
}

func ApplyTravelFatigue(w *World, p *Person) {
	if p == nil || !p.Alive {
		return
	}
	extra := p.MinutesTravel - w.Cfg.TravelFatigueAfter
	if extra <= 0 {
		return
	}
	per := w.Cfg.TravelFatiguePer
	if per < 1 {
		per = 1
	}
	loss := extra / per
	if LifeStageOf(p, w.Cfg.DaysPerYear) == Elder {
		loss = loss + loss/2
	}
	if p.Health > loss+1 {
		p.Health -= loss
	} else if p.Health > 1 {
		p.Health = 1
	}
}

func MemberSlotOf(h *Household, Id i32) i32 {
	if h == nil {
		return 0
	}
	for s := i32(0); s < h.MemberCount; s += 1 {
		if h.Members[s] == Id {
			return s
		}
	}
	return 0
}

func PersonHomeMilli(h *Household, p *Person) (i32, i32) {
	return MemberHomeMilli(h, MemberSlotOf(h, p.Id))
}

func ActorSkill(h *Household, p *Person, k SkillKind) i32 {
	if p != nil {
		return p.Skills[k]
	}
	return h.Skills[k]
}

func MapMilli(Cell Vec2i) (i32, i32) {
	return Cell.X * 1000, Cell.Y * 1000
}

func MemberHomeMilli(h *Household, slot i32) (i32, i32) {
	hx, hy := MapMilli(h.Home)
	// Spread living walkers around the hut so they do not stack.
	ox := ((slot % 3) - 1) * 220
	oy := ((slot/3)%3 - 1) * 180
	return hx + ox, hy + oy
}

func PathReset(p *Person, X i32, Y i32) {
	p.PathN = 1
	p.Path[0] = PathPt{X: X, Y: Y, T: 0, Doing: Sleep, Activity: Rest}
	p.TradeHh = -1
}

func PathFreeSlot(p *Person) {
	if p.PathN < PATH_MAX {
		return
	}
	// Drop one redundant hold (same cell, later t wins) so a new keyframe fits.
	for i := i32(1); i < p.PathN; i += 1 {
		if p.Path[i].X == p.Path[i-1].X && p.Path[i].Y == p.Path[i-1].Y {
			p.Path[i-1].T = p.Path[i].T
			for j := i32(i); j < p.PathN-1; j += 1 {
				p.Path[j] = p.Path[j+1]
			}
			p.PathN -= 1
			return
		}
	}
	p.PathN = PATH_MAX - 1
}

func PathPush(p *Person, X i32, Y i32, T i32, Doing PersonDoing, Activity Activity) {
	if p.PathN <= 0 {
		PathReset(p, X, Y)
		p.Path[0].T = T
		p.Path[0].Doing = Doing
		p.Path[0].Activity = Activity
		return
	}
	last := p.Path[p.PathN-1]
	tt := T
	if tt < last.T {
		tt = last.T
	}
	if last.X == X && last.Y == Y && tt == last.T && last.Doing == Doing {
		return
	}
	if p.PathN >= PATH_MAX {
		PathFreeSlot(p)
	}
	if p.PathN >= PATH_MAX {
		p.Path[PATH_MAX-1] = PathPt{X: X, Y: Y, T: tt, Doing: Doing, Activity: Activity}
		return
	}
	p.Path[p.PathN] = PathPt{X: X, Y: Y, T: tt, Doing: Doing, Activity: Activity}
	p.PathN += 1
}

func PersonNow(p *Person, u f32, world_sum f32) (Doing PersonDoing, Activity Activity, walking bool) {
	Doing = Sleep
	Activity = Rest
	if p == nil || p.PathN <= 0 {
		return
	}
	_, _, rt := PersonAtViewU(p, u, world_sum)
	T := i32(rt + 0.5)
	if T <= p.Path[0].T || p.PathN == 1 {
		return p.Path[0].Doing, p.Path[0].Activity, false
	}
	for i := i32(1); i < p.PathN; i += 1 {
		b := p.Path[i]
		a := p.Path[i-1]
		if T <= b.T {
			dist := OctileMilli(a.X, a.Y, b.X, b.Y)
			if dist > VIEW_SAME_DIST {
				return Walking, b.Activity, true
			}
			return b.Doing, b.Activity, false
		}
	}
	last := p.Path[p.PathN-1]
	return last.Doing, last.Activity, false
}

func LerpI32(a i32, b i32, s i32, span i32) i32 {
	if span <= 0 {
		return b
	}
	return a + i32((i64(b)-i64(a))*i64(s)/i64(span))
}

func LerpF32(a f32, b f32, s f32, span f32) f32 {
	if span <= 0 {
		return b
	}
	return a + (b-a)*(s/span)
}

// True sim-minute interpolation (t is 0..10000 through the 1440-minute day).
func PersonPosMilli(p *Person, T i32) (i32, i32) {
	X, Y, _ := PersonAtRealT(p, T)
	return X, Y
}

func PersonViewPosMilli(p *Person, vis_t i32, world_sum f32) (i32, i32) {
	u := f32(vis_t) / 10000
	X, Y, _ := PersonAtViewU(p, u, world_sum)
	return i32(X + 0.5), i32(Y + 0.5)
}

func PersonViewPosF32(p *Person, u f32, world_sum f32) (f32, f32) {
	X, Y, _ := PersonAtViewU(p, u, world_sum)
	return X, Y
}

func PersonViewRealT(p *Person, vis_t i32, world_sum f32) i32 {
	u := f32(vis_t) / 10000
	_, _, rt := PersonAtViewU(p, u, world_sum)
	return i32(rt + 0.5)
}

func PersonViewRealTU(p *Person, u f32, world_sum f32) i32 {
	_, _, rt := PersonAtViewU(p, u, world_sum)
	return i32(rt + 0.5)
}

const VIEW_MOVE_PER_CELL = 620
const VIEW_MIN_MOVE = 400
const VIEW_MIN_HOLD = 90
const VIEW_STILL_SCALE = 0.16
const VIEW_SAME_DIST = 280

func PersonAtRealT(p *Person, T i32) (X i32, Y i32, real_t i32) {
	if p == nil || p.PathN <= 0 {
		return 0, 0, 0
	}
	if p.PathN == 1 || T <= p.Path[0].T {
		return p.Path[0].X, p.Path[0].Y, p.Path[0].T
	}
	for i := i32(1); i < p.PathN; i += 1 {
		b := p.Path[i]
		a := p.Path[i-1]
		if T <= b.T {
			span := b.T - a.T
			s := T - a.T
			return LerpI32(a.X, b.X, s, span), LerpI32(a.Y, b.Y, s, span), LerpI32(a.T, b.T, s, span)
		}
	}
	last := p.Path[p.PathN-1]
	return last.X, last.Y, last.T
}

// Collapse hut-scatter / duplicate holds so playback is walk → stand → walk,
// not a chain of one-frame twitches.
func CollapsePath(p *Person, out []PathPt) i32 {
	if p == nil || p.PathN <= 0 {
		return 0
	}
	var N i32 = 0
	for i := i32(0); i < p.PathN; i += 1 {
		pt := p.Path[i]
		if N > 0 {
			last := out[N-1]
			dist := OctileMilli(last.X, last.Y, pt.X, pt.Y)
			if dist <= VIEW_SAME_DIST {
				if N >= 2 {
					prev := out[N-2]
					if OctileMilli(prev.X, prev.Y, last.X, last.Y) <= VIEW_SAME_DIST {
						out[N-1] = pt
						out[N-1].X = last.X
						out[N-1].Y = last.Y
						continue
					}
				}
				pt.X = last.X
				pt.Y = last.Y
				out[N] = pt
				N += 1
				continue
			}
		}
		out[N] = pt
		N += 1
		if N >= i32(len(out)) {
			break
		}
	}
	return N
}

func ViewSegWeight(a PathPt, b PathPt) f32 {
	dist := OctileMilli(a.X, a.Y, b.X, b.Y)
	dt := b.T - a.T
	if dt < 0 {
		dt = 0
	}
	if dist > VIEW_SAME_DIST {
		wt := f32(dist) * VIEW_MOVE_PER_CELL / 1000
		if wt < VIEW_MIN_MOVE {
			wt = VIEW_MIN_MOVE
		}
		return wt
	}
	wt := f32(dt) * VIEW_STILL_SCALE
	if dt > 0 && wt < VIEW_MIN_HOLD {
		wt = VIEW_MIN_HOLD
	}
	if wt < 1 {
		wt = 1
	}
	return wt
}

func PersonViewSum(p *Person) f32 {
	if p == nil || p.PathN <= 0 {
		return 0
	}
	var pts [PATH_MAX]PathPt
	N := CollapsePath(p, pts[:])
	if N <= 1 {
		return 0
	}
	var sum f32
	for i := i32(0); i < N-1; i += 1 {
		sum += ViewSegWeight(pts[i], pts[i+1])
	}
	return sum
}

func WorldViewScale(w *World) f32 {
	if w == nil {
		return 1
	}
	var best f32 = 1
	for i := i32(0); i < w.PersonCount; i += 1 {
		p := &w.People[i]
		if !p.Alive {
			continue
		}
		s := PersonViewSum(p)
		if s > best {
			best = s
		}
	}
	return best
}

func PersonAtViewU(p *Person, u f32, world_sum f32) (X f32, Y f32, real_t f32) {
	if p == nil || p.PathN <= 0 {
		return 0, 0, 0
	}
	uu := u
	if uu < 0 {
		uu = 0
	}
	if uu > 1 {
		uu = 1
	}

	var pts [PATH_MAX]PathPt
	N := CollapsePath(p, pts[:])
	if N <= 0 {
		return 0, 0, 0
	}
	if N == 1 || uu <= 0 {
		a := pts[0]
		return f32(a.X), f32(a.Y), f32(a.T)
	}

	var wts [PATH_MAX]f32
	var sum f32
	seg := N - 1
	for i := i32(0); i < seg; i += 1 {
		wts[i] = ViewSegWeight(pts[i], pts[i+1])
		sum += wts[i]
	}
	if sum <= 0 {
		a := pts[0]
		return f32(a.X), f32(a.Y), f32(a.T)
	}

	scale := world_sum
	if scale < sum {
		scale = sum
	}
	target := uu * scale
	if target >= sum {
		last := pts[N-1]
		return f32(last.X), f32(last.Y), f32(last.T)
	}
	var Acc f32
	for i := i32(0); i < seg; i += 1 {
		next := Acc + wts[i]
		if target <= next || i == seg-1 {
			span := wts[i]
			s := target - Acc
			if s < 0 {
				s = 0
			}
			if s > span {
				s = span
			}
			a := pts[i]
			b := pts[i+1]
			return LerpF32(f32(a.X), f32(b.X), s, span), LerpF32(f32(a.Y), f32(b.Y), s, span), LerpF32(f32(a.T), f32(b.T), s, span)
		}
		Acc = next
	}
	last := pts[N-1]
	return f32(last.X), f32(last.Y), f32(last.T)
}

func InitPersonSkills(w *World, p *Person) {
	for s := 0; s < SKILL_COUNT; s++ {
		p.Skills[s] = RngRangeI32(&w.Rng, w.Cfg.SkillStartMin, w.Cfg.SkillStartMax)
	}
	side := RngRangeI32(&w.Rng, w.Cfg.GenderSideBonusMin, w.Cfg.GenderSideBonusMax)
	switch p.Sex {
	case Male:
		p.Skills[Hunt] += RngRangeI32(&w.Rng, w.Cfg.MaleHuntBonusMin, w.Cfg.MaleHuntBonusMax)
		p.Skills[Stone] += side
		p.Skills[Forage] -= side / 2
	case Female:
		p.Skills[Forage] += RngRangeI32(&w.Rng, w.Cfg.FemaleForageBonusMin, w.Cfg.FemaleForageBonusMax)
		p.Skills[Craft] += side
		p.Skills[Hunt] -= side / 2
	}
	boost_i := RngRangeI32(&w.Rng, 0, SKILL_COUNT-1)
	boost := RngRangeI32(&w.Rng, w.Cfg.SkillBoostMin, w.Cfg.SkillBoostMax)
	p.Skills[boost_i] += boost
	for s := 0; s < SKILL_COUNT; s++ {
		p.Skills[s] = ClampI32(p.Skills[s], w.Cfg.SkillMin, w.Cfg.SkillMax)
	}
}

func SpawnPerson(w *World, h *Household, Sex Sex, AgeDays i32, Health i32, Constitution i32) i32 {
	if h.MemberCount >= w.Cfg.MaxMembers {
		return -1
	}
	if int(w.PersonCount) >= len(w.People) {
		GrowPeople(w)
	}
	Id := w.PersonCount
	p := &w.People[Id]
	w.PersonCount += 1
	*p = Person{}
	p.Id = Id
	p.Household = h.Id
	p.Sex = Sex
	p.Alive = true
	p.AgeDays = AgeDays
	p.Constitution = ClampI32(Constitution, 4000, HEALTH_MAX)
	p.Health = ClampI32(Health, 1, HEALTH_MAX)
	p.IntentActivity = Rest
	p.IntentCell = h.Home
	p.IntentPartner = -1
	p.TradeHh = -1
	p.FatherId = -1
	p.MotherId = -1
	p.SpouseId = -1
	p.PregnancyFatherId = -1
	p.NatalHousehold = h.Id
	InitPersonSkills(w, p)
	slot := h.MemberCount
	h.Members[slot] = Id
	h.MemberCount += 1
	hx, hy := MemberHomeMilli(h, slot)
	PathReset(p, hx, hy)
	PathPush(p, hx, hy, 10000, At_Home, Rest)
	return Id
}

func SyncHouseholdFromMembers(w *World, h *Household) {
	if h == nil || !h.Exists {
		return
	}
	N := i32(0)
	for i := i32(0); i < h.MemberCount; i += 1 {
		p := PersonAt(w, h.Members[i])
		if p != nil && p.Alive {
			h.Members[N] = h.Members[i]
			N += 1
		}
	}
	h.MemberCount = N
	n_live := LivingMembers(w, h)
	if n_live <= 0 {
		if h.Alive {
			KillHousehold(w, h)
		}
		return
	}
	h.Alive = true
	var sum_h i32
	var sum_sk [SKILL_COUNT]i32
	var n_sk i32
	for i := i32(0); i < h.MemberCount; i += 1 {
		p := PersonAt(w, h.Members[i])
		if p == nil || !p.Alive {
			continue
		}
		sum_h += p.Health
		if WorkBlocksFor(p, w.Cfg) > 0 {
			for s := 0; s < SKILL_COUNT; s++ {
				sum_sk[s] += p.Skills[s]
			}
			n_sk += 1
		}
	}
	h.Health = sum_h / n_live
	if n_sk > 0 {
		for s := 0; s < SKILL_COUNT; s++ {
			h.Skills[s] = sum_sk[s] / n_sk
		}
	}
	need := HouseholdDailyNeed(w, h)
	h.PreferredFoodNutrition = need * i64(h.PrefDaysMilli) / 1000
}

func KillPerson(w *World, p *Person) {
	if p == nil || !p.Alive {
		return
	}
	p.Alive = false
	p.Health = 0
	p.Pregnant = false
	p.PregnancyFatherId = -1
	w.Acc.Deaths += 1
	w.TotalDeaths += 1
	PushEvent(w, Event{Kind: Person_Died, H1: p.Household, H2: p.Id, QtyA: i64(p.AgeDays)})
	h := &w.Households[p.Household]
	SyncHouseholdFromMembers(w, h)
}

func LearnPersonSkill(w *World, p *Person, sk SkillKind) {
	if p == nil || !p.Alive {
		return
	}
	p.Skills[sk] = ClampI32(p.Skills[sk]+w.Cfg.LearningBp, w.Cfg.SkillMin, w.Cfg.SkillMax)
}

func AgeAndHealthEnvironment(w *World, p *Person, food_got i64, FoodNeed i64, fuel_ok bool) {
	if p == nil || !p.Alive {
		return
	}
	var dh i32
	if FoodNeed <= 0 || food_got >= FoodNeed {
		dh += w.Cfg.HealthRecover
	} else if food_got > 0 {
		dh += w.Cfg.HealthPartialFood
	} else {
		dh += w.Cfg.HealthNoFood
	}
	st := LifeStageOf(p, w.Cfg.DaysPerYear)
	if st == Infant && food_got < FoodNeed {
		dh = dh * 3 / 2
	}
	if st == Child && food_got <= 0 {
		dh = dh * 5 / 4
	}
	if !fuel_ok {
		dh += w.Cfg.HealthNoFuel
	}
	years := AgeYears(p, w.Cfg.DaysPerYear)
	if years >= w.Cfg.AgeFrailtyStartYear {
		dh -= (years - w.Cfg.AgeFrailtyStartYear) * 4
	}
	if years >= 70 {
		dh -= (years - 70) * 8
	}
	// Drift toward inherited constitution when fed.
	if dh > 0 && p.Health > p.Constitution {
		dh = dh / 2
	}
	p.Health = ClampI32(p.Health+dh, 0, HEALTH_MAX)
	if p.Health <= 0 {
		KillPerson(w, p)
	}
}

func PickFather(w *World, h *Household, MotherId i32) i32 {
	var best i32 = -1
	var best_age i32 = -1
	for i := i32(0); i < h.MemberCount; i += 1 {
		p := PersonAt(w, h.Members[i])
		if p == nil || !p.Alive || p.Id == MotherId {
			continue
		}
		if p.Sex != Male {
			continue
		}
		if LifeStageOf(p, w.Cfg.DaysPerYear) == Infant || LifeStageOf(p, w.Cfg.DaysPerYear) == Child {
			continue
		}
		if p.AgeDays > best_age {
			best_age = p.AgeDays
			best = p.Id
		}
	}
	return best
}

func TryConceive(w *World, h *Household) {
	if !h.Alive || h.MemberCount >= w.Cfg.MaxMembers {
		return
	}
	if LivingMembers(w, h) >= w.Cfg.MaxMembers {
		return
	}
	need := HouseholdDailyNeed(w, h)
	days := FoodDaysMilli(NutritionOf(h.Inv, w.Cfg), need)
	var food_f i32
	switch {
	case days < 1000:
		return
	case days < 2000:
		food_f = 3000
	case days < 3000:
		food_f = 7000
	default:
		food_f = 10000
	}

	for i := i32(0); i < h.MemberCount; i += 1 {
		m := PersonAt(w, h.Members[i])
		if m == nil || !m.Alive || m.Sex != Female || m.Pregnant {
			continue
		}
		Y := AgeYears(m, w.Cfg.DaysPerYear)
		if Y < YEARS_FERTILE_MIN || Y > YEARS_FERTILE_MAX {
			continue
		}
		if m.Health < 5000 {
			continue
		}
		if !HasLivingSpouse(w, m) {
			continue
		}
		fid := m.SpouseId
		f := PersonAt(w, fid)
		if f == nil || !f.Alive || f.Sex != Male || f.Household != m.Household || f.Health < 4000 {
			continue
		}
		bp := w.Cfg.ConceiveBp
		bp = i32(i64(bp) * i64(m.Health) / i64(HEALTH_MAX) * i64(f.Health) / i64(HEALTH_MAX) * i64(food_f) / 10000)
		if bp < 1 {
			continue
		}
		if RngChanceBp(&w.Rng, bp) {
			m.Pregnant = true
			m.PregnancyDays = 0
			m.PregFoodDaysAcc = 0
			m.PregDaysCounted = 0
			m.PregnancyFatherId = fid
		}
	}
}

func FinishPregnancy(w *World, h *Household, mother *Person) {
	mother.Pregnant = false
	days_c := mother.PregDaysCounted
	var avg_food i64 = 2000
	if days_c > 0 {
		avg_food = mother.PregFoodDaysAcc / i64(days_c)
	}
	mother.PregnancyDays = 0
	if h.MemberCount >= w.Cfg.MaxMembers {
		return
	}
	var father_con i32 = mother.Constitution
	dad := PersonAt(w, mother.PregnancyFatherId)
	if dad != nil {
		father_con = dad.Constitution
	}
	inherited := (mother.Constitution + father_con) / 2
	rnd := RngRangeI32(&w.Rng, 7000, 13000)
	con := (inherited*7 + rnd*3) / 10
	var nut_mod i32
	switch {
	case avg_food < 1000:
		nut_mod = -2200
	case avg_food < 2000:
		nut_mod = -900
	case avg_food < 3000:
		nut_mod = -200
	case avg_food > 4500:
		nut_mod = 400
	}
	jitter := RngRangeI32(&w.Rng, -700, 700)
	Health := ClampI32(con+nut_mod+jitter, 1500, HEALTH_MAX)
	var Sex Sex = Male
	if RngChanceBp(&w.Rng, 5000) {
		Sex = Female
	}
	// spawn_person may grow the people array; preserve IDs before that happens.
	MotherId := mother.Id
	FatherId := mother.PregnancyFatherId
	mother.PregnancyFatherId = -1
	cid := SpawnPerson(w, h, Sex, 0, Health, con)
	if cid < 0 {
		return
	}
	child := PersonAt(w, cid)
	if child != nil {
		child.MotherId = MotherId
		child.FatherId = FatherId
		child.NatalHousehold = h.Id
	}
	w.Acc.Births += 1
	PushEvent(w, Event{Kind: Person_Born, H1: h.Id, H2: cid, QtyA: i64(Health), QtyB: avg_food})
}

func TickPeople(w *World) {
	// Newborns start at age zero and are first ticked the following day.
	N := w.PersonCount
	for i := i32(0); i < N; i += 1 {
		p := &w.People[i]
		if !p.Alive {
			continue
		}
		p.AgeDays += 1
		h := &w.Households[p.Household]
		if p.Pregnant && p.Alive {
			p.PregnancyDays += 1
			if p.PregnancyDays >= w.Cfg.PregnancyDays {
				FinishPregnancy(w, h, p)
			}
		}
	}
}

func FirstMobileMember(w *World, h *Household) i32 {
	for i := i32(0); i < h.MemberCount; i += 1 {
		p := PersonAt(w, h.Members[i])
		if p != nil && p.Alive && WorkBlocksFor(p, w.Cfg) > 0 {
			return p.Id
		}
	}
	return -1
}

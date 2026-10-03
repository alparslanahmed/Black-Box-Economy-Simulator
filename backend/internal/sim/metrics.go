package sim

import "slices"

func ComputeMetrics(w *World) DayMetrics {
	var m DayMetrics
	m.Day = w.Day
	m.Year = w.Day / w.Cfg.DaysPerYear
	m.Produced = w.Acc.Produced
	m.TradeAttempts = w.Acc.TradeAttempts
	m.SuccessfulTrades = w.Acc.SuccessfulTrades
	m.FailNoDc = w.Acc.FailNoDc
	m.FailNoGain = w.Acc.FailNoGain
	m.FailInv = w.Acc.FailInv
	m.BarterQtyTotal = w.Acc.BarterQtyTotal
	m.FoodSpoiled = w.Acc.FoodSpoiled
	m.Deaths = w.Acc.Deaths
	m.Hungry = w.Acc.Hungry
	m.Visits = w.Acc.Visits
	m.TravelMinutesTotal = w.Acc.TravelMinutesTotal
	if m.TradeAttempts > 0 {
		m.TradeSuccessBp = i32(i64(m.SuccessfulTrades) * 10000 / i64(m.TradeAttempts))
	}

	healths := make([]i32, int(w.PersonCount))
	var hn int
	var food_days_sum i64
	var spec_sum i32
	var skill_sum [SKILL_COUNT]i64
	var spear_owners i32
	var FoodTotal i64

	for index_h := range w.Households {
		h := &w.Households[index_h]
		if !h.Exists || !h.Alive {
			continue
		}
		m.AliveHouseholds += 1
		nut := NutritionOf(h.Inv, w.Cfg)
		FoodTotal += nut
		need := HouseholdDailyNeed(w, h)
		food_days_sum += FoodDaysMilli(nut, need)
		// household median filled after people loop
		spec_sum += h.SpecializationBp
		m.RoleCounts[h.InferredRole] += 1
		if SpearCount(h.Inv) > 0 {
			spear_owners += 1
		}
		for s := 0; s < SKILL_COUNT; s++ {
			skill_sum[s] += i64(h.Skills[s])
		}
	}
	m.FoodTotal = FoodTotal
	m.Births = w.Acc.Births
	m.Marriages = w.Acc.Marriages
	m.Alive = AliveCount(w)
	var of_marry_age i32
	for i := i32(0); i < w.PersonCount; i += 1 {
		p := &w.People[i]
		if !p.Alive {
			continue
		}
		healths[hn] = p.Health
		hn += 1
		single := !HasLivingSpouse(w, p)
		if single {
			m.Unmarried += 1
		}
		Y := AgeYears(p, w.Cfg.DaysPerYear)
		in_age := false
		switch p.Sex {
		case Male:
			in_age = Y >= w.Cfg.MarryAgeMaleMin && Y <= w.Cfg.MarryAgeMaleMax
		case Female:
			in_age = Y >= w.Cfg.MarryAgeFemaleMin && Y <= w.Cfg.MarryAgeFemaleMax
		}
		if in_age {
			of_marry_age += 1
			if single {
				m.UnmarriedMarriageable += 1
			}
		}
		if p.Sex == Female && Y >= YEARS_FERTILE_MIN && Y <= YEARS_FERTILE_MAX {
			m.FertileWomen += 1
		}
	}
	if m.Alive > 0 {
		m.UnmarriedBp = i32(i64(m.Unmarried) * 10000 / i64(m.Alive))
	}
	if of_marry_age > 0 {
		m.UnmarriedMarriageableBp = i32(i64(m.UnmarriedMarriageable) * 10000 / i64(of_marry_age))
	}
	if m.AliveHouseholds > 0 {
		m.FoodDaysAvgMilli = food_days_sum / i64(m.AliveHouseholds)
		m.SpecAvgBp = spec_sum / m.AliveHouseholds
		m.SpearOwnBp = i32(i64(spear_owners) * 10000 / i64(m.AliveHouseholds))
		for s := 0; s < SKILL_COUNT; s++ {
			m.AvgSkill[s] = i32(skill_sum[s] / i64(m.AliveHouseholds))
		}
	}
	if hn > 0 {
		slices.Sort(healths[:hn])
		m.MedianHealth = healths[hn/2]
	}
	m.ResourceStock = TotalResourceStock(w)
	FillBarterRatios(w, &m)
	FillFertilityRates(w, &m)
	return m
}

func FillFertilityRates(w *World, m *DayMetrics) {
	Year := w.Cfg.DaysPerYear
	if Year <= 0 {
		Year = DAYS_PER_YEAR
	}
	Births := i64(m.Births)
	pop_sum := i64(m.Alive)
	fertile_sum := i64(m.FertileWomen)
	var days i32 = 1
	have := i32(w.Metrics.Count)
	take := Year - 1
	if take > have {
		take = have
	}
	for k := i32(0); k < take; k += 1 {
		prev := MetricsAt(&w.Metrics, u32(have-1-k))
		Births += i64(prev.Births)
		pop_sum += i64(prev.Alive)
		fertile_sum += i64(prev.FertileWomen)
		days += 1
	}
	m.BirthRateDays = days
	if days <= 0 {
		return
	}
	pop_avg := pop_sum / i64(days)
	fertile_avg := fertile_sum / i64(days)
	births_year := Births * i64(Year) / i64(days)
	if pop_avg > 0 {
		m.CbrMilli = i32(births_year * 1000 * 1000 / pop_avg)
	}
	span := YEARS_FERTILE_MAX - YEARS_FERTILE_MIN + 1
	if fertile_avg > 0 && span > 0 {
		m.TfrMilli = i32(births_year * 1000 * i64(span) / fertile_avg)
	}
}

func PushMetrics(w *World, m DayMetrics) {
	w.Metrics.Items[w.Metrics.Head] = m
	w.Metrics.Head = (w.Metrics.Head + 1) % METRICS_CAP
	if w.Metrics.Count < METRICS_CAP {
		w.Metrics.Count += 1
	}
}

func MetricsAt(buf *MetricsBuf, logical u32) DayMetrics {
	var start u32
	if buf.Count < METRICS_CAP {
		start = 0
	} else {
		start = buf.Head
	}
	return buf.Items[(start+logical)%METRICS_CAP]
}

func LatestMetrics(w *World) DayMetrics {
	if w.Metrics.Count == 0 {
		return DayMetrics{}
	}
	return MetricsAt(&w.Metrics, w.Metrics.Count-1)
}

func FillBarterRatios(w *World, m *DayMetrics) {
	for g := 0; g < GOOD_COUNT; g++ {
		m.BerriesPerUnit[g] = -1
		m.UnitPerBerry[g] = -1
	}
	window := w.Cfg.RatioWindowDays
	n_ex := w.Exchanges.Count
	if n_ex == 0 {
		return
	}
	var start u32
	if n_ex < EXCHANGE_CAP {
		start = 0
	} else {
		start = w.Exchanges.Head
	}

	Collect := func(w *World, start u32, n_ex u32, window i32, other Good) (berries_per i64, units_per_berry i64, ok bool) {
		var ratios_b [EXCHANGE_CAP]i64
		var ratios_u [EXCHANGE_CAP]i64
		N := 0
		day0 := w.Day - window + 1
		for i := u32(0); i < n_ex; i += 1 {
			e := w.Exchanges.Items[(start+i)%EXCHANGE_CAP]
			if e.Day < day0 {
				continue
			}
			var berry_q i64
			var other_q i64
			if e.G0 == Berries && e.G1 == other {
				berry_q = e.Q0
				other_q = e.Q1
			} else if e.G1 == Berries && e.G0 == other {
				berry_q = e.Q1
				other_q = e.Q0
			} else {
				continue
			}
			if berry_q <= 0 || other_q <= 0 {
				continue
			}
			ratios_b[N] = berry_q * QTY_SCALE / other_q
			ratios_u[N] = other_q * QTY_SCALE / berry_q
			N += 1
		}
		if N == 0 {
			return 0, 0, false
		}
		slices.Sort(ratios_b[:N])
		slices.Sort(ratios_u[:N])
		if N%2 == 0 {
			return (ratios_b[N/2-1] + ratios_b[N/2]) / 2,
				(ratios_u[N/2-1] + ratios_u[N/2]) / 2, true
		}
		return ratios_b[N/2], ratios_u[N/2], true
	}

	for g := 0; g < GOOD_COUNT; g++ {
		if g == Berries {
			continue
		}
		bp, up, ok := Collect(w, start, n_ex, window, g)
		if ok {
			m.BerriesPerUnit[g] = bp
			m.UnitPerBerry[g] = up
		}
	}
}

func TopSpecialized(w *World, dest []i32) int {
	N := 0
	ids := make([]i32, len(w.Households))
	for i := 0; i < len(w.Households); i++ {
		if w.Households[i].Exists && w.Households[i].Alive {
			ids[N] = i32(i)
			N += 1
		}
	}
	ids = ids[:N]
	for i := 0; i < N; i++ {
		best := i
		for j := i + 1; j < N; j += 1 {
			if w.Households[ids[j]].SpecializationBp > w.Households[ids[best]].SpecializationBp {
				best = j
			}
		}
		ids[i], ids[best] = ids[best], ids[i]
	}
	out := min(N, len(dest))
	for i := 0; i < out; i++ {
		dest[i] = ids[i]
	}
	return out
}

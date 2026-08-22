package sim

import "core:slice"

compute_metrics :: proc(w: ^World) -> Day_Metrics {
	m: Day_Metrics
	m.day = w.day
	m.year = w.day / w.cfg.days_per_year
	m.produced = w.acc.produced
	m.trade_attempts = w.acc.trade_attempts
	m.successful_trades = w.acc.successful_trades
	m.fail_no_dc = w.acc.fail_no_dc
	m.fail_no_gain = w.acc.fail_no_gain
	m.fail_inv = w.acc.fail_inv
	m.barter_qty_total = w.acc.barter_qty_total
	m.food_spoiled = w.acc.food_spoiled
	m.deaths = w.acc.deaths
	m.hungry = w.acc.hungry
	m.visits = w.acc.visits
	m.travel_minutes_total = w.acc.travel_minutes_total
	if m.trade_attempts > 0 {
		m.trade_success_bp = i32(i64(m.successful_trades) * 10000 / i64(m.trade_attempts))
	}

	healths := make([]i32, int(w.person_count), context.temp_allocator)
	hn: int
	food_days_sum: i64
	spec_sum: i32
	skill_sum: [SKILL_COUNT]i64
	spear_owners: i32
	food_total: i64

	for &h in w.households {
		if !h.exists || !h.alive {
			continue
		}
		m.alive_households += 1
		nut := nutrition_of(h.inv, w.cfg)
		food_total += nut
		need := household_daily_need(w, &h)
		food_days_sum += food_days_milli(nut, need)
		// household median filled after people loop
		spec_sum += h.specialization_bp
		m.role_counts[h.inferred_role] += 1
		if spear_count(h.inv) > 0 {
			spear_owners += 1
		}
		for s in 0 ..< SKILL_COUNT {
			skill_sum[s] += i64(h.skills[s])
		}
	}
	m.food_total = food_total
	m.births = w.acc.births
	m.marriages = w.acc.marriages
	m.alive = alive_count(w)
	of_marry_age: i32
	for i: i32 = 0; i < w.person_count; i += 1 {
		p := &w.people[i]
		if !p.alive do continue
		healths[hn] = p.health
		hn += 1
		single := !has_living_spouse(w, p)
		if single {
			m.unmarried += 1
		}
		y := age_years(p)
		in_age := false
		switch p.sex {
		case .Male:
			in_age = y >= w.cfg.marry_age_male_min && y <= w.cfg.marry_age_male_max
		case .Female:
			in_age = y >= w.cfg.marry_age_female_min && y <= w.cfg.marry_age_female_max
		}
		if in_age {
			of_marry_age += 1
			if single {
				m.unmarried_marriageable += 1
			}
		}
		if p.sex == .Female && y >= YEARS_FERTILE_MIN && y <= YEARS_FERTILE_MAX {
			m.fertile_women += 1
		}
	}
	if m.alive > 0 {
		m.unmarried_bp = i32(i64(m.unmarried) * 10000 / i64(m.alive))
	}
	if of_marry_age > 0 {
		m.unmarried_marriageable_bp = i32(i64(m.unmarried_marriageable) * 10000 / i64(of_marry_age))
	}
	if m.alive_households > 0 {
		m.food_days_avg_milli = food_days_sum / i64(m.alive_households)
		m.spec_avg_bp = spec_sum / m.alive_households
		m.spear_own_bp = i32(i64(spear_owners) * 10000 / i64(m.alive_households))
		for s in 0 ..< SKILL_COUNT {
			m.avg_skill[s] = i32(skill_sum[s] / i64(m.alive_households))
		}
	}
	if hn > 0 {
		slice.sort(healths[:hn])
		m.median_health = healths[hn / 2]
	}
	m.resource_stock = total_resource_stock(w)
	fill_barter_ratios(w, &m)
	fill_fertility_rates(w, &m)
	return m
}

fill_fertility_rates :: proc(w: ^World, m: ^Day_Metrics) {
	year := w.cfg.days_per_year
	if year <= 0 do year = DAYS_PER_YEAR
	births := i64(m.births)
	pop_sum := i64(m.alive)
	fertile_sum := i64(m.fertile_women)
	days: i32 = 1
	have := i32(w.metrics.count)
	take := year - 1
	if take > have do take = have
	for k: i32 = 0; k < take; k += 1 {
		prev := metrics_at(&w.metrics, u32(have - 1 - k))
		births += i64(prev.births)
		pop_sum += i64(prev.alive)
		fertile_sum += i64(prev.fertile_women)
		days += 1
	}
	m.birth_rate_days = days
	if days <= 0 {
		return
	}
	pop_avg := pop_sum / i64(days)
	fertile_avg := fertile_sum / i64(days)
	births_year := births * i64(year) / i64(days)
	if pop_avg > 0 {
		m.cbr_milli = i32(births_year * 1000 * 1000 / pop_avg)
	}
	span := YEARS_FERTILE_MAX - YEARS_FERTILE_MIN + 1
	if fertile_avg > 0 && span > 0 {
		m.tfr_milli = i32(births_year * 1000 * i64(span) / fertile_avg)
	}
}

push_metrics :: proc(w: ^World, m: Day_Metrics) {
	w.metrics.items[w.metrics.head] = m
	w.metrics.head = (w.metrics.head + 1) % METRICS_CAP
	if w.metrics.count < METRICS_CAP {
		w.metrics.count += 1
	}
}

metrics_at :: proc(buf: ^Metrics_Buf, logical: u32) -> Day_Metrics {
	start: u32
	if buf.count < METRICS_CAP {
		start = 0
	} else {
		start = buf.head
	}
	return buf.items[(start + logical) % METRICS_CAP]
}

latest_metrics :: proc(w: ^World) -> Day_Metrics {
	if w.metrics.count == 0 {
		return {}
	}
	return metrics_at(&w.metrics, w.metrics.count - 1)
}

fill_barter_ratios :: proc(w: ^World, m: ^Day_Metrics) {
	for g in Good {
		m.berries_per_unit[g] = -1
		m.unit_per_berry[g] = -1
	}
	window := w.cfg.ratio_window_days
	n_ex := w.exchanges.count
	if n_ex == 0 {
		return
	}
	start: u32
	if n_ex < EXCHANGE_CAP {
		start = 0
	} else {
		start = w.exchanges.head
	}

	collect :: proc(w: ^World, start: u32, n_ex: u32, window: i32, other: Good) -> (berries_per: i64, units_per_berry: i64, ok: bool) {
		ratios_b: [256]i64
		ratios_u: [256]i64
		n := 0
		day0 := w.day - window
		for i: u32 = 0; i < n_ex && n < 256; i += 1 {
			e := w.exchanges.items[(start + i) % EXCHANGE_CAP]
			if e.day < day0 {
				continue
			}
			berry_q: i64
			other_q: i64
			if e.g0 == .Berries && e.g1 == other {
				berry_q = e.q0
				other_q = e.q1
			} else if e.g1 == .Berries && e.g0 == other {
				berry_q = e.q1
				other_q = e.q0
			} else {
				continue
			}
			if berry_q <= 0 || other_q <= 0 {
				continue
			}
			ratios_b[n] = berry_q * QTY_SCALE / other_q
			ratios_u[n] = other_q * QTY_SCALE / berry_q
			n += 1
		}
		if n == 0 {
			return 0, 0, false
		}
		slice.sort(ratios_b[:n])
		slice.sort(ratios_u[:n])
		return ratios_b[n / 2], ratios_u[n / 2], true
	}

	for g in Good {
		if g == .Berries {
			continue
		}
		bp, up, ok := collect(w, start, n_ex, window, g)
		if ok {
			m.berries_per_unit[g] = bp
			m.unit_per_berry[g] = up
		}
	}
}

top_specialized :: proc(w: ^World, dest: []i32) -> int {
	n := 0
	ids := make([]i32, len(w.households), context.temp_allocator)
	for i in 0 ..< len(w.households) {
		if w.households[i].exists && w.households[i].alive {
			ids[n] = i32(i)
			n += 1
		}
	}
	ids = ids[:n]
	for i in 0 ..< n {
		best := i
		for j := i + 1; j < n; j += 1 {
			if w.households[ids[j]].specialization_bp > w.households[ids[best]].specialization_bp {
				best = j
			}
		}
		ids[i], ids[best] = ids[best], ids[i]
	}
	out := min(n, len(dest))
	for i in 0 ..< out {
		dest[i] = ids[i]
	}
	return out
}

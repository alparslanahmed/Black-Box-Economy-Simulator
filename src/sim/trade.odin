package sim

TRADE_STEPS :: 10

Trade_Result :: struct {
	success: bool,
	fail:    Trade_Fail,
	gave_g:  Good,
	got_g:   Good,
	gave_q:  i64,
	got_q:   i64,
}

attempt_barter :: proc(w: ^World, a: ^Household, b: ^Household) -> Trade_Result {
	res: Trade_Result
	if !w.trade_enabled || !a.alive || !b.alive {
		res.fail = .Dead_Or_Disabled
		return res
	}

	a_has := false
	b_has := false
	for g in Good {
		if a.inv.qty[g] >= good_def(g).min_trade_qty do a_has = true
		if b.inv.qty[g] >= good_def(g).min_trade_qty do b_has = true
	}
	if !a_has || !b_has {
		res.fail = .Insufficient_Inventory
		return res
	}

	a_wants: [GOOD_COUNT]bool
	b_wants: [GOOD_COUNT]bool
	any_a, any_b := false, false
	for g in Good {
		a_wants[g] = b.inv.qty[g] >= good_def(g).min_trade_qty && directly_wants(w, a, g)
		b_wants[g] = a.inv.qty[g] >= good_def(g).min_trade_qty && directly_wants(w, b, g)
		if a_wants[g] do any_a = true
		if b_wants[g] do any_b = true
	}
	if !any_a || !any_b {
		res.fail = .No_Double_Coincidence
		// still learn what the other requested
		for g in Good {
			if a_wants[g] do note_demand(b, g, w.cfg.memory_gain_fail)
			if b_wants[g] do note_demand(a, g, w.cfg.memory_gain_fail)
		}
		return res
	}

	u_a0 := utility_current(w, a)
	u_b0 := utility_current(w, b)

	best_min: i64 = -1
	found := false
	best_ga, best_gb: Good
	best_qa, best_qb: i64

	for ga in Good {
		if !b_wants[ga] do continue
		steps_a := qty_steps(a.inv.qty[ga], ga)
		if steps_a.n == 0 do continue
		for gb in Good {
			if ga == gb do continue
			if !a_wants[gb] do continue
			steps_b := qty_steps(b.inv.qty[gb], gb)
			if steps_b.n == 0 do continue
			for ia in 0 ..< steps_a.n {
				qa := steps_a.v[ia]
				if qa <= 0 || qa > a.inv.qty[ga] do continue
				for ib in 0 ..< steps_b.n {
					qb := steps_b.v[ib]
					if qb <= 0 || qb > b.inv.qty[gb] do continue
					inv_a := a.inv
					inv_b := b.inv
					dur_a := a.spear_durability
					dur_b := b.spear_durability
					inv_a.qty[ga] -= qa
					inv_a.qty[gb] += qb
					inv_b.qty[gb] -= qb
					inv_b.qty[ga] += qa
					if ga == .Spear && spear_count(inv_a) <= 0 do dur_a = 0
					if gb == .Spear && spear_count(inv_b) <= 0 do dur_b = 0
					if gb == .Spear && a.spear_durability <= 0 do dur_a = w.cfg.spear_durability_max
					if ga == .Spear && b.spear_durability <= 0 do dur_b = w.cfg.spear_durability_max
					gain_a := utility_of(w, a, inv_a, dur_a) - u_a0
					gain_b := utility_of(w, b, inv_b, dur_b) - u_b0
					if gain_a <= 0 || gain_b <= 0 {
						continue
					}
					mn := min(gain_a, gain_b)
					better := false
					if !found || mn > best_min {
						better = true
					} else if mn == best_min {
						// deterministic tie-break
						if u8(ga) < u8(best_ga) || (ga == best_ga && (u8(gb) < u8(best_gb) || (gb == best_gb && (qa < best_qa || (qa == best_qa && qb < best_qb))))) {
							better = true
						}
					}
					if better {
						found = true
						best_min = mn
						best_ga, best_gb = ga, gb
						best_qa, best_qb = qa, qb
					}
				}
			}
		}
	}

	if !found {
		res.fail = .No_Mutual_Gain
		for g in Good {
			if a_wants[g] do note_demand(b, g, w.cfg.memory_gain_request)
			if b_wants[g] do note_demand(a, g, w.cfg.memory_gain_request)
		}
		return res
	}

	// Execute transfer. Goods are conserved.
	if !remove_good(&a.inv, best_ga, best_qa) || !remove_good(&b.inv, best_gb, best_qb) {
		res.fail = .Insufficient_Inventory
		return res
	}
	add_good(&a.inv, best_gb, best_qb)
	add_good(&b.inv, best_ga, best_qa)
	if best_ga == .Spear {
		if spear_count(a.inv) <= 0 {
			a.spear_durability = 0
		}
		if b.spear_durability <= 0 {
			b.spear_durability = w.cfg.spear_durability_max
		}
	}
	if best_gb == .Spear {
		if spear_count(b.inv) <= 0 {
			b.spear_durability = 0
		}
		if a.spear_durability <= 0 {
			a.spear_durability = w.cfg.spear_durability_max
		}
	}

	res.success = true
	res.gave_g = best_ga
	res.got_g = best_gb
	res.gave_q = best_qa
	res.got_q = best_qb

	note_demand(a, best_gb, w.cfg.memory_gain_success)
	note_demand(b, best_ga, w.cfg.memory_gain_success)
	note_demand(a, best_ga, w.cfg.memory_gain_request / 2)
	note_demand(b, best_gb, w.cfg.memory_gain_request / 2)
	return res
}

Qty_Steps :: struct {
	v: [TRADE_STEPS]i64,
	n: int,
}

qty_steps :: proc(have: i64, g: Good) -> Qty_Steps {
	s: Qty_Steps
	def := good_def(g)
	if have < def.min_trade_qty {
		return s
	}
	if !def.divisible {
		units := have / QTY_SCALE
		if units >= 1 {
			s.v[s.n] = QTY_SCALE
			s.n += 1
		}
		if units >= 2 && s.n < TRADE_STEPS {
			s.v[s.n] = 2 * QTY_SCALE
			s.n += 1
		}
		return s
	}
	cap := have
	if cap > 12 * QTY_SCALE {
		cap = 12 * QTY_SCALE
	}
	for i: i64 = 1; i <= TRADE_STEPS; i += 1 {
		q := cap * i / TRADE_STEPS
		if q < def.min_trade_qty {
			continue
		}
		if s.n > 0 && s.v[s.n - 1] == q {
			continue
		}
		s.v[s.n] = q
		s.n += 1
		if s.n >= TRADE_STEPS {
			break
		}
	}
	if s.n == 0 && have >= def.min_trade_qty {
		s.v[0] = min(have, def.min_trade_qty)
		s.n = 1
	}
	return s
}

record_attempt :: proc(w: ^World, a: ^Household, b: ^Household, res: Trade_Result) {
	w.acc.trade_attempts += 1
	if res.success {
		w.acc.successful_trades += 1
		w.acc.barter_qty_total += res.gave_q + res.got_q
		push_event(w, Event{
			kind = .Trade_Completed,
			h1 = a.id,
			h2 = b.id,
			good_a = res.gave_g,
			good_b = res.got_g,
			qty_a = res.gave_q,
			qty_b = res.got_q,
		})
		rec_a := Trade_Record{
			day = w.day, partner = b.id,
			gave_good = res.gave_g, got_good = res.got_g,
			gave_qty = res.gave_q, got_qty = res.got_q,
			success = true,
		}
		rec_b := Trade_Record{
			day = w.day, partner = a.id,
			gave_good = res.got_g, got_good = res.gave_g,
			gave_qty = res.got_q, got_qty = res.gave_q,
			success = true,
		}
		record_recent_trade(a, rec_a)
		record_recent_trade(b, rec_b)
		push_exchange(w, Exchange{
			day = w.day,
			g0 = res.gave_g, q0 = res.gave_q,
			g1 = res.got_g, q1 = res.got_q,
			h0 = a.id, h1 = b.id,
		})
	} else {
		switch res.fail {
		case .No_Double_Coincidence: w.acc.fail_no_dc += 1
		case .No_Mutual_Gain:        w.acc.fail_no_gain += 1
		case .Insufficient_Inventory: w.acc.fail_inv += 1
		case .Dead_Or_Disabled, .None:
		}
		push_event(w, Event{
			kind = .Trade_Failed,
			h1 = a.id,
			h2 = b.id,
			fail = res.fail,
		})
		record_recent_trade(a, Trade_Record{day = w.day, partner = b.id, success = false, fail = res.fail})
	}
}

push_exchange :: proc(w: ^World, e: Exchange) {
	w.exchanges.items[w.exchanges.head] = e
	w.exchanges.head = (w.exchanges.head + 1) % EXCHANGE_CAP
	if w.exchanges.count < EXCHANGE_CAP {
		w.exchanges.count += 1
	}
}

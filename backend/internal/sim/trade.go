package sim

const TRADE_STEPS = 10

type TradeResult struct {
	Success bool      `json:"success"`
	Fail    TradeFail `json:"fail"`
	GaveG   Good      `json:"gave_g"`
	GotG    Good      `json:"got_g"`
	GaveQ   i64       `json:"gave_q"`
	GotQ    i64       `json:"got_q"`
}

func AttemptBarter(w *World, a *Household, b *Household) TradeResult {
	var res TradeResult
	if !w.TradeEnabled || a == nil || b == nil || a == b || !a.Alive || !b.Alive {
		res.Fail = Dead_Or_Disabled
		return res
	}

	a_has := false
	b_has := false
	for g := 0; g < GOOD_COUNT; g++ {
		if a.Inv.Qty[g] >= DescribeGood(g).MinTradeQty {
			a_has = true
		}
		if b.Inv.Qty[g] >= DescribeGood(g).MinTradeQty {
			b_has = true
		}
	}
	if !a_has || !b_has {
		res.Fail = Insufficient_Inventory
		return res
	}

	var a_wants [GOOD_COUNT]bool
	var b_wants [GOOD_COUNT]bool
	any_a, any_b := false, false
	for g := 0; g < GOOD_COUNT; g++ {
		a_wants[g] = b.Inv.Qty[g] >= DescribeGood(g).MinTradeQty && DirectlyWants(w, a, g)
		b_wants[g] = a.Inv.Qty[g] >= DescribeGood(g).MinTradeQty && DirectlyWants(w, b, g)
		if a_wants[g] {
			any_a = true
		}
		if b_wants[g] {
			any_b = true
		}
	}
	if !any_a || !any_b {
		res.Fail = No_Double_Coincidence
		// still learn what the other requested
		for g := 0; g < GOOD_COUNT; g++ {
			if a_wants[g] {
				NoteDemand(b, g, w.Cfg.MemoryGainFail)
			}
			if b_wants[g] {
				NoteDemand(a, g, w.Cfg.MemoryGainFail)
			}
		}
		return res
	}

	u_a0 := UtilityCurrent(w, a)
	u_b0 := UtilityCurrent(w, b)

	var best_min i64 = -1
	Found := false
	var best_ga, best_gb Good
	var best_qa, best_qb i64

	for ga := 0; ga < GOOD_COUNT; ga++ {
		if !b_wants[ga] {
			continue
		}
		steps_a := TradeQtySteps(a.Inv.Qty[ga], ga)
		if steps_a.N == 0 {
			continue
		}
		for gb := 0; gb < GOOD_COUNT; gb++ {
			if ga == gb {
				continue
			}
			if !a_wants[gb] {
				continue
			}
			steps_b := TradeQtySteps(b.Inv.Qty[gb], gb)
			if steps_b.N == 0 {
				continue
			}
			for ia := 0; ia < steps_a.N; ia++ {
				qa := steps_a.V[ia]
				if qa <= 0 || qa > a.Inv.Qty[ga] {
					continue
				}
				for ib := 0; ib < steps_b.N; ib++ {
					qb := steps_b.V[ib]
					if qb <= 0 || qb > b.Inv.Qty[gb] {
						continue
					}
					inv_a := a.Inv
					inv_b := b.Inv
					tools_a := SpearCondition(a)
					tools_b := SpearCondition(b)
					inv_a.Qty[ga] -= qa
					inv_a.Qty[gb] += qb
					inv_b.Qty[gb] -= qb
					inv_b.Qty[ga] += qa
					if ga == Spear {
						tools_a, tools_b = PreviewSpearTransfer(a, b, qa)
					}
					if gb == Spear {
						tools_b, tools_a = PreviewSpearTransfer(b, a, qb)
					}
					gain_a := UtilityOf(w, a, inv_a, tools_a.Active, tools_a.Reserve) - u_a0
					gain_b := UtilityOf(w, b, inv_b, tools_b.Active, tools_b.Reserve) - u_b0
					if gain_a <= 0 || gain_b <= 0 {
						continue
					}
					mn := min(gain_a, gain_b)
					better := false
					if !Found || mn > best_min {
						better = true
					} else if mn == best_min {
						// deterministic tie-break
						if u8(ga) < u8(best_ga) || (ga == best_ga && (u8(gb) < u8(best_gb) || (gb == best_gb && (qa < best_qa || (qa == best_qa && qb < best_qb))))) {
							better = true
						}
					}
					if better {
						Found = true
						best_min = mn
						best_ga, best_gb = ga, gb
						best_qa, best_qb = qa, qb
					}
				}
			}
		}
	}

	if !Found {
		res.Fail = No_Mutual_Gain
		for g := 0; g < GOOD_COUNT; g++ {
			if a_wants[g] {
				NoteDemand(b, g, w.Cfg.MemoryGainRequest)
			}
			if b_wants[g] {
				NoteDemand(a, g, w.Cfg.MemoryGainRequest)
			}
		}
		return res
	}

	// Validate both legs before mutating either inventory.
	if a.Inv.Qty[best_ga] < best_qa || b.Inv.Qty[best_gb] < best_qb {
		res.Fail = Insufficient_Inventory
		return res
	}
	TransferGood(a, b, best_ga, best_qa)
	TransferGood(b, a, best_gb, best_qb)

	res.Success = true
	res.GaveG = best_ga
	res.GotG = best_gb
	res.GaveQ = best_qa
	res.GotQ = best_qb

	// Learn what the other household bought from us.
	NoteDemand(a, best_ga, w.Cfg.MemoryGainSuccess)
	NoteDemand(b, best_gb, w.Cfg.MemoryGainSuccess)
	return res
}

type QtySteps struct {
	V [TRADE_STEPS]i64 `json:"v"`
	N int              `json:"n"`
}

func TradeQtySteps(have i64, g Good) QtySteps {
	var s QtySteps
	def := DescribeGood(g)
	if have < def.MinTradeQty {
		return s
	}
	if !def.Divisible {
		units := have / QTY_SCALE
		if units >= 1 {
			s.V[s.N] = QTY_SCALE
			s.N += 1
		}
		if units >= 2 && s.N < TRADE_STEPS {
			s.V[s.N] = 2 * QTY_SCALE
			s.N += 1
		}
		return s
	}
	cap := have
	if cap > 12*QTY_SCALE {
		cap = 12 * QTY_SCALE
	}
	for i := i64(1); i <= TRADE_STEPS; i += 1 {
		q := cap * i / TRADE_STEPS
		if q < def.MinTradeQty {
			continue
		}
		if s.N > 0 && s.V[s.N-1] == q {
			continue
		}
		s.V[s.N] = q
		s.N += 1
		if s.N >= TRADE_STEPS {
			break
		}
	}
	if s.N == 0 && have >= def.MinTradeQty {
		s.V[0] = min(have, def.MinTradeQty)
		s.N = 1
	}
	return s
}

func RecordAttempt(w *World, a *Household, b *Household, res TradeResult) {
	w.Acc.TradeAttempts += 1
	if res.Success {
		w.Acc.SuccessfulTrades += 1
		w.Acc.BarterQtyTotal += res.GaveQ + res.GotQ
		PushEvent(w, Event{
			Kind:  Trade_Completed,
			H1:    a.Id,
			H2:    b.Id,
			GoodA: res.GaveG,
			GoodB: res.GotG,
			QtyA:  res.GaveQ,
			QtyB:  res.GotQ,
		})
		rec_a := TradeRecord{
			Day: w.Day, Partner: b.Id,
			GaveGood: res.GaveG, GotGood: res.GotG,
			GaveQty: res.GaveQ, GotQty: res.GotQ,
			Success: true,
		}
		rec_b := TradeRecord{
			Day: w.Day, Partner: a.Id,
			GaveGood: res.GotG, GotGood: res.GaveG,
			GaveQty: res.GotQ, GotQty: res.GaveQ,
			Success: true,
		}
		RecordRecentTrade(a, rec_a)
		RecordRecentTrade(b, rec_b)
		PushExchange(w, Exchange{
			Day: w.Day,
			G0:  res.GaveG, Q0: res.GaveQ,
			G1: res.GotG, Q1: res.GotQ,
			H0: a.Id, H1: b.Id,
		})
	} else {
		switch res.Fail {
		case No_Double_Coincidence:
			w.Acc.FailNoDc += 1
		case No_Mutual_Gain:
			w.Acc.FailNoGain += 1
		case Insufficient_Inventory:
			w.Acc.FailInv += 1
		case Dead_Or_Disabled, None:
		}
		PushEvent(w, Event{
			Kind: Trade_Failed,
			H1:   a.Id,
			H2:   b.Id,
			Fail: res.Fail,
		})
		RecordRecentTrade(a, TradeRecord{Day: w.Day, Partner: b.Id, Success: false, Fail: res.Fail})
	}
}

func PushExchange(w *World, e Exchange) {
	w.Exchanges.Items[w.Exchanges.Head] = e
	w.Exchanges.Head = (w.Exchanges.Head + 1) % EXCHANGE_CAP
	if w.Exchanges.Count < EXCHANGE_CAP {
		w.Exchanges.Count += 1
	}
}

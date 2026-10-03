package sim

import (
	"compress/gzip"
	"encoding/json"
	"os"
	"testing"
)

func testWorld() *World {
	c := DefaultConfig()
	c.HouseholdCount = 10
	return WorldCreate(123, c, true, 10000)
}
func clearInventory(h *Household) { h.Inv = Inventory{}; h.SpareSpears = nil; h.SpearDurability = 0 }

// This fixture is emitted by the corrected Odin executable, not by this port.
// It covers every authoritative field after 1000 days, including PCG state,
// births, paths, all decision candidates, memories, resources and ring buffers.
func TestOdinParity(t *testing.T) {
	f, err := os.Open("testdata/odin-seed-98765-day-1000.json.gz")
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	z, err := gzip.NewReader(f)
	if err != nil {
		t.Fatal(err)
	}
	defer z.Close()
	var expected World
	if err = json.NewDecoder(z).Decode(&expected); err != nil {
		t.Fatal(err)
	}
	actual := WorldCreate(expected.Seed, expected.Cfg, expected.TradeEnabled, expected.BerryRegenScaleBp)
	SimDays(actual, expected.Day)
	if StateHash(actual) != StateHash(&expected) {
		t.Fatalf("Go state differs from Odin: got %d want %d; RNG %d/%d", StateHash(actual), StateHash(&expected), actual.Rng.State, expected.Rng.State)
	}
	if actual.Events != expected.Events {
		t.Fatal("event history differs from Odin")
	}
}

func TestDeterminismAndSeeds(t *testing.T) {
	a, b, c := testWorld(), testWorld(), WorldCreate(124, DefaultConfig(), true, 10000)
	SimDays(a, 30)
	SimDays(b, 30)
	SimDays(c, 30)
	if StateHash(a) != StateHash(b) || StateHash(a) == StateHash(c) {
		t.Fatal("determinism/seed")
	}
}
func TestHouseholdNeeds(t *testing.T) {
	w := testWorld()
	h := &w.Households[0]
	clearInventory(h)
	h.Inv.Qty[Berries] = 12000
	if HouseholdDailyNeed(w, h) != 12000 || MarginalGive(w, h, Berries, 6000) != 45000 {
		t.Fatal("family food valuation")
	}
	SpawnPerson(w, h, Male, 0, 9000, 9000)
	h.Inv.Qty[Wood] = 330
	u := UtilityCurrent(w, h)
	h.Inv.Qty[Wood] = 0
	if u-UtilityCurrent(w, h) != 22000 {
		t.Fatal("family fuel valuation")
	}
}
func TestDeathsDoNotSkipMembers(t *testing.T) {
	w := testWorld()
	h := &w.Households[0]
	ids := h.Members
	clearInventory(h)
	h.Inv.Qty[Wood] = 1000
	w.People[ids[0]].Health = 100
	w.People[ids[1]].Health = 100
	ConsumeFoodAndFuel(w, h)
	if w.Acc.Deaths != 2 || h.MemberCount != 0 {
		t.Fatal("member skipped on death")
	}
}
func TestWornSpearTrade(t *testing.T) {
	w := testWorld()
	a, b := &w.Households[0], &w.Households[1]
	clearInventory(a)
	clearInventory(b)
	ReceiveSpear(a, 10)
	b.Inv.Qty[Meat] = 40000
	b.Inv.Qty[Wood] = 8000
	a.ObservedDemand = [GOOD_COUNT]int{}
	b.ObservedDemand = [GOOD_COUNT]int{}
	ua, ub := UtilityCurrent(w, a), UtilityCurrent(w, b)
	totals := a.Inv.Qty
	for g := range totals {
		totals[g] += b.Inv.Qty[g]
	}
	r := AttemptBarter(w, a, b)
	if !r.Success || b.SpearDurability != 10 || UtilityCurrent(w, a) <= ua || UtilityCurrent(w, b) <= ub {
		t.Fatal("worn tool or mutual benefit")
	}
	for g := range totals {
		if a.Inv.Qty[g]+b.Inv.Qty[g] != totals[g] {
			t.Fatal("goods lost")
		}
	}
	if a.ObservedDemand[r.GaveG] != w.Cfg.MemoryGainSuccess || a.ObservedDemand[r.GotG] != 0 || b.ObservedDemand[r.GotG] != w.Cfg.MemoryGainSuccess {
		t.Fatal("demand learned backwards")
	}
	AssertInvariants(w)
}
func TestSpareLifetimes(t *testing.T) {
	w := testWorld()
	a, b := &w.Households[0], &w.Households[1]
	clearInventory(a)
	clearInventory(b)
	ReceiveSpear(a, 1)
	ReceiveSpear(a, 70)
	ReceiveSpear(b, 30)
	ga, gb := PreviewSpearTransfer(a, b, 2000)
	TransferGood(a, b, Spear, 2000)
	if SpearCondition(a) != ga || SpearCondition(b) != gb || gb.Active+int(gb.Reserve) != 101 {
		t.Fatal("condition lost")
	}
	for range 3 {
		ConsumeSpearDurability(w, b)
	}
	if b.SpearDurability != 1 {
		t.Fatal("first spare")
	}
	ConsumeSpearDurability(w, b)
	if b.SpearDurability != 70 {
		t.Fatal("second spare")
	}
	for range 7 {
		ConsumeSpearDurability(w, b)
	}
	AssertInvariants(w)
}
func TestNoOneSidedTrade(t *testing.T) {
	w := testWorld()
	a, b := &w.Households[0], &w.Households[1]
	clearInventory(a)
	clearInventory(b)
	a.Inv.Qty[Berries] = 100000
	if AttemptBarter(w, a, b).Success {
		t.Fatal("gift allowed")
	}
	a.Inv.Qty = [GOOD_COUNT]int64{12000, 0, 1000, 0, 0}
	b.Inv = a.Inv
	a.Skills = [SKILL_COUNT]int{10000, 10000, 10000, 10000, 10000}
	b.Skills = a.Skills
	a.PreferredFoodNutrition = 36000
	b.PreferredFoodNutrition = 36000
	before := a.Inv
	if AttemptBarter(w, a, b).Success || a.Inv != before || b.Inv != before {
		t.Fatal("non-beneficial exchange")
	}
}
func TestCSVPrecision(t *testing.T) {
	for q, want := range map[int64]string{0: "0.000", 1: "0.001", 999: "0.999", 1000: "1.000", 1500: "1.500", -1: "NA"} {
		if QuantityCSV(q) != want {
			t.Fatal(q)
		}
	}
}
func TestRiskPreference(t *testing.T) {
	w := testWorld()
	h := &w.Households[0]
	clearInventory(h)
	h.Inv.Qty[Berries] = 12000
	p := &w.People[h.Members[0]]
	h.RiskPreference = 3500
	a := ScoreActivity(w, h, Hunt, p, 600)
	h.RiskPreference = 8000
	b := ScoreActivity(w, h, Hunt, p, 600)
	if !a.Feasible || !b.Feasible || a.Risk >= b.Risk || b.Risk >= 0 || a.TotalScore >= b.TotalScore {
		t.Fatal("risk preference ignored")
	}
}
func TestConceptionFatherAndInheritance(t *testing.T) {
	w := testWorld()
	h := &w.Households[0]
	m, f := &w.People[h.Members[1]], &w.People[h.Members[0]]
	m.AgeDays = 25 * w.Cfg.DaysPerYear
	m.Health = 10000
	f.Health = 10000
	m.Constitution = 10000
	f.Constitution = 10000
	h.Inv.Qty[Berries] = 100000
	w.Cfg.ConceiveBp = 10000
	TryConceive(w, h)
	fid := f.Id
	if !m.Pregnant || m.PregnancyFatherId != fid {
		t.Fatal("conception")
	}
	KillPerson(w, f)
	replacement := &w.People[w.Households[1].Members[0]]
	replacement.Constitution = 4000
	MovePersonToHousehold(w, replacement, h)
	LinkSpouses(m, replacement)
	rng := w.Rng
	want := ClampI32((70000+RngRangeI32(&rng, 7000, 13000)*3)/10, 4000, 10000)
	FinishPregnancy(w, h, m)
	child := &w.People[w.PersonCount-1]
	if child.FatherId != fid || child.Constitution != want {
		t.Fatal("parentage/inheritance")
	}
}
func TestPopulationGrowth(t *testing.T) {
	w := testWorld()
	h := &w.Households[0]
	capacity := len(w.People)
	for w.PersonCount < capacity {
		id := SpawnPerson(w, h, Male, 0, 9000, 9000)
		if id < 0 {
			t.Fatal("spawn")
		}
		KillPerson(w, &w.People[id])
	}
	mid, fid := h.Members[1], h.Members[0]
	m := &w.People[mid]
	m.Pregnant = true
	m.PregnancyDays = w.Cfg.PregnancyDays - 1
	m.PregnancyFatherId = fid
	TickPeople(w)
	child := w.People[capacity]
	if w.PersonCount != capacity+1 || child.AgeDays != 0 || child.MotherId != mid || child.FatherId != fid {
		t.Fatal("storage growth/birthday")
	}
	SimDay(w)
	AssertInvariants(w)
}
func TestSupportedHouseholdCounts(t *testing.T) {
	for _, n := range []int{401, 1000} {
		cfg := DefaultConfig()
		cfg.HouseholdCount = n
		w := WorldCreate(1, cfg, false, 10000)
		if AliveHouseholds(w) != n || w.PersonCount != 2*n {
			t.Fatal(n)
		}
		AssertInvariants(w)
	}
}
func TestZeroRegeneration(t *testing.T) {
	w := testWorld()
	w.BerryRegenScaleBp = 0
	for i := range w.Cells {
		w.Cells[i].BerryStock = 0
	}
	RegenResources(w)
	if TotalResourceStock(w)[0] != 0 {
		t.Fatal("zero override")
	}
	cfg := DefaultConfig()
	cfg.BerryRegenBp = 0
	w = WorldCreate(1, cfg, true, 10000)
	for i := range w.Cells {
		w.Cells[i].BerryStock = 0
	}
	RegenResources(w)
	if TotalResourceStock(w)[0] != 0 {
		t.Fatal("zero config")
	}
}
func TestWindowMedian(t *testing.T) {
	w := testWorld()
	for range EXCHANGE_CAP {
		PushExchange(w, Exchange{Day: -100, G0: Berries, G1: Meat, Q0: 50000, Q1: 1000})
	}
	for range 256 {
		PushExchange(w, Exchange{Day: 0, G0: Berries, G1: Meat, Q0: 1000, Q1: 1000})
	}
	for range 257 {
		PushExchange(w, Exchange{Day: 1, G0: Berries, G1: Meat, Q0: 10000, Q1: 1000})
	}
	w.Day = 1
	var m DayMetrics
	FillBarterRatios(w, &m)
	if m.BerriesPerUnit[Meat] != 10000 {
		t.Fatal("truncated median")
	}
	w.Day = w.Cfg.RatioWindowDays + 1
	FillBarterRatios(w, &m)
	if m.BerriesPerUnit[Meat] != -1 {
		t.Fatal("expired trade")
	}
}
func TestAncestors(t *testing.T) {
	w := testWorld()
	a, b, c, d := &w.People[0], &w.People[2], &w.People[4], &w.People[6]
	b.FatherId = a.Id
	c.FatherId = b.Id
	d.FatherId = c.Id
	if !AreCloseKin(w, a, c) || !AreCloseKin(w, c, a) || !AreCloseKin(w, a, d) || AreCloseKin(w, a, &w.People[8]) {
		t.Fatal("ancestor marriage")
	}
}
func TestConfiguredTime(t *testing.T) {
	cfg := DefaultConfig()
	cfg.DaysPerYear = 180
	cfg.PregnancyDays = 180
	w := WorldCreate(1, cfg, true, 10000)
	p := &w.People[0]
	p.AgeDays = 15 * 180
	if LifeStageOf(p, 180) != Youth {
		t.Fatal("year length")
	}
	p.AgeDays = 25 * 180
	p.Health = 10000
	speed, sleep := PersonWalkSpeedBp(p, cfg), PersonSleepMinutes(cfg, p)
	p.Pregnant = true
	p.PregnancyDays = 130
	if WorkBlocksFor(p, cfg) != 1 || PersonWalkSpeedBp(p, cfg) >= speed || PersonSleepMinutes(cfg, p) != sleep+60 {
		t.Fatal("pregnancy length")
	}
}
func TestStateHashAndCapacity(t *testing.T) {
	w := testWorld()
	before := StateHash(w)
	GrowPeople(w)
	if StateHash(w) != before {
		t.Fatal("capacity included")
	}
	w.People[0].Household++
	if StateHash(w) == before {
		t.Fatal("household omitted")
	}
	w.People[0].Household--
	w.People[1].PregFoodDaysAcc++
	if StateHash(w) == before {
		t.Fatal("pregnancy omitted")
	}
}
func TestTravelAndProduction(t *testing.T) {
	w := testWorld()
	before := TotalResourceStock(w)
	SimDay(w)
	var any bool
	for i := 0; i < w.PersonCount; i++ {
		p := &w.People[i]
		if p.MinutesSleep+p.MinutesHome+p.MinutesTravel+p.MinutesWork+p.MinutesVisit != w.Cfg.DayMinutes {
			t.Fatal("time conservation")
		}
		any = any || p.MinutesWork > 0
	}
	if !any || LatestMetrics(w).Produced[Berries] == 0 || before == TotalResourceStock(w) {
		t.Fatal("production")
	}
}
func TestDisabledTrade(t *testing.T) {
	w := testWorld()
	w.TradeEnabled = false
	SimDays(w, 30)
	if w.Exchanges.Count != 0 {
		t.Fatal("trade disabled")
	}
}

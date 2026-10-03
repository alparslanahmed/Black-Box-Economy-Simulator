package engine

import (
	"blackbox/internal/protocol"
	"blackbox/internal/sim"
	"fmt"
	"strconv"
)

// Presentation values are derived here; the client does not decide food needs,
// occupations, eligibility, paths, event meaning or any economic outcome.
func (e *Engine) snapshot() *protocol.Snapshot {
	w := e.world
	s := &protocol.Snapshot{WorldID: e.id, Revision: e.revision, Seed: strconv.FormatUint(w.Seed, 10), Day: w.Day, Hash: strconv.FormatUint(sim.StateHash(w), 16), Config: w.Cfg, Runtime: e.runtime, TradeEnabled: w.TradeEnabled, BerryRegenBP: w.BerryRegenScaleBp, Metrics: sim.LatestMetrics(w), ViewScale: sim.WorldViewScale(w), TotalDeaths: w.TotalDeaths, TotalMarriages: w.TotalMarriages}
	if w.Metrics.Count == 0 {
		s.Metrics = sim.ComputeMetrics(w)
	}
	s.Cells = make([]protocol.Tile, len(w.Cells))
	for i, c := range w.Cells {
		berryRegen := c.BerryRegen * int64(w.BerryRegenScaleBp) / 10000
		if berryRegen < 1 && c.BerryRegen > 0 && w.BerryRegenScaleBp > 0 {
			berryRegen = 1
		}
		s.Cells[i] = protocol.Tile{Terrain: c.Terrain, Stock: [4]int64{c.BerryStock, c.GameStock, c.WoodStock, c.StoneStock}, Capacity: [4]int64{c.BerryMax, c.GameMax, c.WoodMax, c.StoneMax}, Regen: [4]int64{berryRegen, c.GameRegen, c.WoodRegen, 0}}
	}
	s.Households = make([]protocol.HouseholdView, 0)
	householdEvents := make(map[int][]protocol.EventView)
	for i := int(w.Events.Count) - 1; i >= 0; i-- {
		ev := sim.EventAt(&w.Events, uint32(i))
		for _, id := range eventHouseholds(ev) {
			if len(householdEvents[id]) < 8 {
				householdEvents[id] = append(householdEvents[id], eventView(w, ev))
			}
		}
	}
	names := []string{"Willow", "Amber", "Mosswood", "Stonebridge", "Fernhill", "Oakheart", "Briar", "Pinecrest", "Meadow", "Ember", "Alder", "Hazel"}
	for i := range w.Households {
		h := &w.Households[i]
		if !h.Exists {
			continue
		}
		// Keep the transport's generated Array type accurate without mutating
		// the authoritative world's nil/empty slice representation.
		copyH := *h
		if copyH.SpareSpears == nil {
			copyH.SpareSpears = []int{}
		}
		s.Households = append(s.Households, protocol.HouseholdView{Data: copyH, Name: fmt.Sprintf("%s Family %d", names[h.Id%len(names)], h.Id/len(names)+1), Role: sim.RoleName(h.InferredRole), FoodDays: sim.FoodDaysMilli(sim.NutritionOf(h.Inv, w.Cfg), sim.HouseholdDailyNeed(w, h)), DailyNeed: sim.HouseholdDailyNeed(w, h), FuelNeed: sim.HouseholdFuelNeed(w, h)})
		recent := householdEvents[h.Id]
		if recent == nil {
			recent = []protocol.EventView{}
		}
		s.Households[len(s.Households)-1].Events = recent
	}
	s.People = make([]protocol.PersonView, 0, w.PersonCount)
	for i := 0; i < w.PersonCount; i++ {
		p := &w.People[i]
		pts := make([]sim.PathPt, sim.PATH_MAX)
		n := sim.CollapsePath(p, pts)
		times := make([]float32, n)
		for j := 1; j < n; j++ {
			times[j] = times[j-1] + sim.ViewSegWeight(pts[j-1], pts[j])/s.ViewScale
		}
		s.People = append(s.People, protocol.PersonView{Data: *p, Label: sim.PersonLabel(w, p.Id), Stage: sim.LifeStageName(sim.LifeStageOf(p, w.Cfg.DaysPerYear)), Age: sim.AgeYears(p, w.Cfg.DaysPerYear), WorkCap: sim.WorkMinutesCap(w.Cfg, p), ViewPath: pts[:n], ViewTimes: times})
	}
	s.History = make([]sim.DayMetrics, 0, min(int(w.Metrics.Count), 180))
	for i := max(int(w.Metrics.Count)-180, 0); i < int(w.Metrics.Count); i++ {
		s.History = append(s.History, sim.MetricsAt(&w.Metrics, uint32(i)))
	}
	s.Events = make([]protocol.EventView, 0, 100)
	// Prefer meaningful transitions over repeating daily work/spoilage chatter.
	for i := int(w.Events.Count) - 1; i >= 0 && len(s.Events) < 100; i-- {
		ev := sim.EventAt(&w.Events, uint32(i))
		if ev.Kind == sim.Work_Completed || ev.Kind == sim.Food_Spoiled {
			continue
		}
		s.Events = append(s.Events, eventView(w, ev))
	}
	s.Exchanges = make([]sim.Exchange, 0)
	start := uint32(0)
	if w.Exchanges.Count == sim.EXCHANGE_CAP {
		start = w.Exchanges.Head
	}
	for i := max(int(w.Exchanges.Count)-100, 0); i < int(w.Exchanges.Count); i++ {
		s.Exchanges = append(s.Exchanges, w.Exchanges.Items[(start+uint32(i))%sim.EXCHANGE_CAP])
	}
	return s
}

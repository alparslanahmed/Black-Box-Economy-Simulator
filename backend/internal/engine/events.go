package engine

import (
	"blackbox/internal/protocol"
	"blackbox/internal/sim"
)

// H1/H2 have different meanings for birth, marriage, trade and map events.
// Resolve them here so a resource depletion never appears in household zero.
func eventHouseholds(ev sim.Event) []int {
	ids := []int{}
	switch ev.Kind {
	case sim.Resource_Depleted:
	case sim.Married:
		ids = append(ids, int(ev.QtyA))
	case sim.Trade_Completed, sim.Trade_Failed:
		ids = append(ids, ev.H1, ev.H2)
	default:
		ids = append(ids, ev.H1)
	}
	return ids
}

func eventView(w *sim.World, ev sim.Event) protocol.EventView {
	return protocol.EventView{Data: ev, Text: sim.FormatLifeEvent(w, ev), Category: sim.EventCategory(ev.Kind), Households: eventHouseholds(ev)}
}

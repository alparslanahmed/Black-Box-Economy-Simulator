package engine

import (
	"blackbox/internal/protocol"
	"blackbox/internal/sim"
	"fmt"
	"testing"
	"time"
)

func TestViewCommandsDoNotStopTime(t *testing.T) {
	e, _, ctx := runningEngine(t)
	e.Submit(ctx, protocol.Command{Type: "play", RequestID: "start"})
	// Sustained observer input used to reset the tick budget to zero each time.
	until := time.Now().Add(2500 * time.Millisecond)
	for i := 0; time.Now().Before(until); i++ {
		e.Submit(ctx, protocol.Command{Type: "view", RequestID: fmt.Sprint("view-", i), View: &protocol.ViewState{Overlay: "overview", InspectorTab: "inventory", Zoom: 1, SelectedPerson: -1}})
		time.Sleep(75 * time.Millisecond)
	}
	e.Submit(ctx, protocol.Command{Type: "pause", RequestID: "stop"})
	if current(t, e).Day < 1 {
		t.Fatal("observer input prevented simulation progress")
	}
}
func TestPresentationUsesCorrectEventIdentitiesAndTimes(t *testing.T) {
	w := sim.WorldCreate(1, sim.DefaultConfig(), true, 10000)
	if len(eventView(w, sim.Event{Kind: sim.Resource_Depleted}).Households) != 0 {
		t.Fatal("map event assigned to household zero")
	}
	ids := eventView(w, sim.Event{Kind: sim.Married, H1: 5, H2: 7, QtyA: 3}).Households
	if len(ids) != 1 || ids[0] != 3 {
		t.Fatal("person IDs used as household IDs")
	}
	sim.SimDay(w)
	e := Engine{world: w, runtime: defaultRuntime()}
	s := e.snapshot()
	for i, p := range s.People {
		if s.Households[0].Data.SpareSpears == nil {
			t.Fatal("null array violates protocol")
		}
		for j, u := range p.ViewTimes {
			x, y := sim.PersonViewPosF32(&w.People[i], u, s.ViewScale)
			if abs(x-float32(p.ViewPath[j].X)) > 1 || abs(y-float32(p.ViewPath[j].Y)) > 1 {
				t.Fatal("playback differs from original timing")
			}
		}
	}
}
func abs(n float32) float32 {
	if n < 0 {
		return -n
	}
	return n
}

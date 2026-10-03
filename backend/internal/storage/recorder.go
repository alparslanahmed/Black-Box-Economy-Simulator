package storage

import (
	"blackbox/internal/protocol"
	"blackbox/internal/sim"
	"context"
	"github.com/google/uuid"
)

// Recorder is for batch/headless runs. It retains daily observations outside
// the simulation's bounded rings, then commits them with a complete checkpoint.
type Recorder struct {
	Store     *Store
	ID        string
	revision  uint64
	days      []sim.DayMetrics
	events    []sim.Event
	exchanges []sim.Exchange
}

func NewRecorder(s *Store) *Recorder { return &Recorder{Store: s, ID: uuid.NewString()} }
func (r *Recorder) Capture(w *sim.World) {
	r.days = append(r.days, sim.LatestMetrics(w))
	day := w.Day - 1
	for j := uint32(0); j < w.Events.Count; j++ {
		e := sim.EventAt(&w.Events, j)
		if e.Day == day {
			r.events = append(r.events, e)
		}
	}
	start := uint32(0)
	if w.Exchanges.Count == sim.EXCHANGE_CAP {
		start = w.Exchanges.Head
	}
	for j := uint32(0); j < w.Exchanges.Count; j++ {
		e := w.Exchanges.Items[(start+j)%sim.EXCHANGE_CAP]
		if e.Day == day {
			r.exchanges = append(r.exchanges, e)
		}
	}
}
func (r *Recorder) Flush(ctx context.Context, w *sim.World) error {
	state := protocol.Runtime{Paused: true, Speed: 1, View: protocol.ViewState{Overlay: "overview", InspectorTab: "inventory", Panel: "overview", SelectedPerson: -1, Zoom: 1}}
	if err := r.Store.Save(ctx, r.ID, r.revision+1, Checkpoint{World: w, Runtime: state}, nil, r.days, r.events, r.exchanges); err != nil {
		return err
	}
	r.revision++
	r.days = nil
	r.events = nil
	r.exchanges = nil
	return nil
}

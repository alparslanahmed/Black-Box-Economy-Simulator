package storage

import (
	"blackbox/internal/protocol"
	"blackbox/internal/sim"
	"context"
	"path/filepath"
	"testing"
)

func TestCompleteResume(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "world.db")
	s, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	cfg := sim.DefaultConfig()
	cfg.HouseholdCount = 10
	w := sim.WorldCreate(17, cfg, true, 10000)
	sim.SimDays(w, 20)
	runtime := protocol.Runtime{Paused: true, Speed: 20, View: protocol.ViewState{Overlay: "trade", SelectedHousehold: 3, SelectedPerson: 7, Zoom: 1.25}}
	m := sim.LatestMetrics(w)
	events := []sim.Event{sim.EventAt(&w.Events, w.Events.Count-1)}
	cmd := protocol.Command{Type: "step", RequestID: "durable-command", Days: 20}
	if err = s.Save(ctx, "world-a", 1, Checkpoint{World: w, Runtime: runtime}, &cmd, []sim.DayMetrics{m}, events, nil); err != nil {
		t.Fatal(err)
	}
	if err = s.Close(); err != nil {
		t.Fatal(err)
	}
	s, err = Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	c, rev, err := s.Load(ctx, "world-a")
	if err != nil {
		t.Fatal(err)
	}
	if rev != 1 || c.Runtime != runtime || sim.StateHash(c.World) != sim.StateHash(w) {
		t.Fatal("incomplete checkpoint")
	}
	if c.World.Events != w.Events {
		t.Fatal("event ring not persisted")
	}
	sim.SimDays(w, 10)
	sim.SimDays(c.World, 10)
	if sim.StateHash(c.World) != sim.StateHash(w) {
		t.Fatal("reloaded world diverges")
	}
	seen, err := s.Seen(ctx, cmd.RequestID)
	if err != nil || !seen {
		t.Fatal("command audit missing")
	}
	var n int64
	s.DB.Model(&EventRecord{}).Where("world_id = ?", "world-a").Count(&n)
	if n != 1 {
		t.Fatal("event history missing")
	}
	csv, err := s.CSV(ctx, "world-a")
	if err != nil || csv != sim.CSVHeader+sim.MetricsCSV(m) {
		t.Fatal("CSV history missing", err)
	}
}

func TestFailedCommitIsAtomic(t *testing.T) {
	s, err := Open(filepath.Join(t.TempDir(), "world.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	ctx := context.Background()
	w := sim.WorldCreate(1, sim.DefaultConfig(), true, 10000)
	c := Checkpoint{World: w}
	cmd := protocol.Command{Type: "pause", RequestID: "duplicate"}
	if err = s.Save(ctx, "a", 1, c, &cmd, nil, nil, nil); err != nil {
		t.Fatal(err)
	}
	sim.SimDay(w)
	if err = s.Save(ctx, "a", 2, c, &cmd, []sim.DayMetrics{sim.LatestMetrics(w)}, nil, nil); err == nil {
		t.Fatal("duplicate command should roll back whole transaction")
	}
	loaded, rev, err := s.Load(ctx, "a")
	if err != nil || rev != 1 || loaded.World.Day != 0 {
		t.Fatal("partial commit", err)
	}
	var n int64
	s.DB.Model(&MetricRecord{}).Count(&n)
	if n != 0 {
		t.Fatal("metrics committed without world")
	}
}

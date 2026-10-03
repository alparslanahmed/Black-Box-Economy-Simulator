package storage

import (
	"blackbox/internal/sim"
	"context"
	"testing"
)

func TestArchivesAndStaleWriter(t *testing.T) {
	s, err := Open(":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	ctx := context.Background()
	w := sim.WorldCreate(1, sim.DefaultConfig(), true, 10000)
	events := make([]sim.Event, 205)
	for i := range events {
		events[i] = sim.Event{Kind: sim.Person_Born, Day: i, H1: 1}
	}
	days := make([]sim.DayMetrics, 4100)
	for i := range days {
		days[i] = sim.DayMetrics{Day: i, Alive: i + 1}
	}
	if err = s.Save(ctx, "a", 1, Checkpoint{World: w}, nil, days, events, nil); err != nil {
		t.Fatal(err)
	}
	first, cursor, more, err := s.Events(ctx, "a", 0, "People")
	if err != nil || len(first) != 100 || !more || first[0].Day != 204 {
		t.Fatal("bad first event page", err)
	}
	second, _, _, err := s.Events(ctx, "a", cursor, "People")
	if err != nil || len(second) != 100 || second[0].Day != 104 {
		t.Fatal("event pages overlap", err)
	}
	empty, _, _, err := s.Events(ctx, "a", 0, "Trade")
	if err != nil || len(empty) != 0 {
		t.Fatal("category filter ignored")
	}
	page, err := s.History(ctx, "a", 0)
	if err != nil || len(page.Items) != 4096 || page.Before != 4 || !page.HasMore {
		t.Fatal("bad history page", err)
	}
	older, err := s.History(ctx, "a", page.Before)
	if err != nil || len(older.Items) != 4 || older.HasMore || older.Items[0].Day != 0 {
		t.Fatal("lost historical metrics", err)
	}
	if err = s.Save(ctx, "a", 1, Checkpoint{World: w}, nil, nil, nil, nil); err == nil {
		t.Fatal("stale writer overwrote newer revision")
	}
}
func TestCorruptCheckpointRejected(t *testing.T) {
	w := sim.WorldCreate(1, sim.DefaultConfig(), true, 10000)
	data, err := Encode(Checkpoint{World: w})
	if err != nil {
		t.Fatal(err)
	}
	data[len(data)-6] ^= 0xff
	if _, err = Decode(data); err == nil {
		t.Fatal("corrupt gzip checksum accepted")
	}
	w.Cfg.DaysPerYear = 0
	data, _ = Encode(Checkpoint{World: w})
	if _, err = Decode(data); err == nil {
		t.Fatal("invalid saved config accepted")
	}
}

package engine

import (
	"blackbox/internal/protocol"
	"blackbox/internal/storage"
	"context"
	"encoding/json"
	"fmt"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func runningEngine(t *testing.T) (*Engine, *storage.Store, context.Context) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	s, err := storage.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	e, err := New(ctx, s)
	if err != nil {
		t.Fatal(err)
	}
	go e.Run(ctx)
	t.Cleanup(func() { cancel(); e.Wait(); s.Close() })
	return e, s, ctx
}
func current(t *testing.T, e *Engine) *protocol.Snapshot {
	t.Helper()
	ch, unsub := e.Subscribe()
	defer unsub()
	select {
	case data := <-ch:
		var m protocol.Message
		if err := json.Unmarshal(data, &m); err != nil {
			t.Fatal(err)
		}
		return m.Snapshot
	case <-time.After(10 * time.Second):
		t.Fatal("no snapshot")
	}
	return nil
}

func TestCommandsAreDurableIdempotentAndConcurrent(t *testing.T) {
	e, s, ctx := runningEngine(t)
	c := protocol.Command{Type: "step", RequestID: "step-once", Days: 2}
	if r := e.Submit(ctx, c); r.Type != "ack" {
		t.Fatal(r)
	}
	if r := e.Submit(ctx, c); r.Type != "ack" {
		t.Fatal(r)
	}
	if current(t, e).Day != 2 {
		t.Fatal("retry advanced time twice")
	}
	// Simultaneous clients are serialized without lost updates or shared writes.
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			r := e.Submit(ctx, protocol.Command{Type: "step", RequestID: fmt.Sprintf("concurrent-%d", i), Days: 1})
			if r.Type != "ack" {
				t.Error(r)
			}
		}(i)
	}
	wg.Wait()
	snap := current(t, e)
	if snap.Day != 10 {
		t.Fatal("lost concurrent command", snap.Day)
	}
	loaded, rev, err := s.Load(ctx, snap.WorldID)
	if err != nil || rev != snap.Revision || loaded.World.Day != 10 {
		t.Fatal("ack preceded durable commit", err)
	}
	var n int64
	s.DB.Model(&storage.MetricRecord{}).Count(&n)
	if n != 10 {
		t.Fatal("every daily metric must be kept", n)
	}
}

func TestInvalidCommandsAndSlowViewer(t *testing.T) {
	e, _, ctx := runningEngine(t)
	ch, unsub := e.Subscribe()
	defer unsub()
	_ = ch // deliberately do not consume
	for _, c := range []protocol.Command{{Type: "new_world", RequestID: "bad-seed", Seed: "-1", Households: 40}, {Type: "step", RequestID: "bad-step", Days: -2}, {Type: "speed", RequestID: "bad-speed"}, {Type: "unknown", RequestID: "bad-type"}} {
		if r := e.Submit(ctx, c); r.Type != "error" {
			t.Fatal("accepted invalid command", r)
		}
	}
	if r := e.Submit(ctx, protocol.Command{Type: "step", RequestID: "slow-viewer-step", Days: 3}); r.Type != "ack" {
		t.Fatal(r)
	}
	if current(t, e).Day != 3 {
		t.Fatal("slow viewer blocked world")
	}
}

func TestDatabaseFailureRollsBackSimulation(t *testing.T) {
	e, s, ctx := runningEngine(t)
	before := current(t, e)
	if err := s.DB.Exec("PRAGMA query_only=ON").Error; err != nil {
		t.Fatal(err)
	}
	r := e.Submit(ctx, protocol.Command{Type: "step", RequestID: "failed-step", Days: 2})
	if r.Type != "error" {
		t.Fatal("write failure acknowledged")
	}
	after := current(t, e)
	if after.Day != before.Day || after.Hash != before.Hash || !after.Runtime.Paused {
		t.Fatal("failed write left uncommitted state")
	}
	if err := s.DB.Exec("PRAGMA query_only=OFF").Error; err != nil {
		t.Fatal(err)
	}
	if r = e.Submit(ctx, protocol.Command{Type: "step", RequestID: "recovered-step", Days: 1}); r.Type != "ack" {
		t.Fatal(r)
	}
}

func TestNewWorldKeepsPreviousWorld(t *testing.T) {
	e, s, ctx := runningEngine(t)
	before := current(t, e)
	if r := e.Submit(ctx, protocol.Command{Type: "new_world", RequestID: "new-world", Seed: "18446744073709551615", Households: 10}); r.Type != "ack" {
		t.Fatal(r)
	}
	after := current(t, e)
	if before.WorldID == after.WorldID || after.Seed != "18446744073709551615" {
		t.Fatal("seed precision or world identity")
	}
	worlds, err := s.List(ctx)
	if err != nil || len(worlds) != 2 {
		t.Fatal("old world overwritten", err)
	}
	if r := e.Submit(ctx, protocol.Command{Type: "load_world", RequestID: "load-world", WorldID: before.WorldID}); r.Type != "ack" {
		t.Fatal(r)
	}
	if current(t, e).Hash != before.Hash {
		t.Fatal("loading changes simulation")
	}
}

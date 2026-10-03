// Package engine serializes simulation commands in one owner goroutine. Socket
// readers/writers, SQLite commits and independent experiments run concurrently;
// random draws and competing claims on resources retain their original order.
package engine

import (
	"blackbox/internal/protocol"
	"blackbox/internal/sim"
	"blackbox/internal/storage"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strconv"
	"sync"
	"time"

	"github.com/google/uuid"
)

type request struct {
	command protocol.Command
	reply   chan protocol.Message
}
type commitJob struct {
	id         string
	revision   uint64
	checkpoint storage.Checkpoint
	command    *protocol.Command
	days       []sim.DayMetrics
	events     []sim.Event
	exchanges  []sim.Exchange
	done       chan error
}

type Engine struct {
	store    *storage.Store
	world    *sim.World
	runtime  protocol.Runtime
	id       string
	revision uint64
	requests chan request
	commits  chan commitJob
	done     chan struct{}
	mu       sync.Mutex
	latest   []byte
	subs     map[chan []byte]struct{}
}

func New(ctx context.Context, store *storage.Store) (*Engine, error) {
	e := &Engine{store: store, requests: make(chan request, 64), commits: make(chan commitJob, 1), done: make(chan struct{}), subs: make(map[chan []byte]struct{})}
	id, err := store.Active(ctx)
	if err != nil {
		return nil, err
	}
	if id != "" {
		c, rev, err := store.Load(ctx, id)
		if err != nil {
			return nil, fmt.Errorf("load active world: %w", err)
		}
		e.world, e.runtime, e.id, e.revision = c.World, c.Runtime, id, rev
	} else {
		e.id = uuid.NewString()
		e.world = sim.WorldCreate(12345, sim.DefaultConfig(), true, 10000)
		e.runtime = defaultRuntime()
		e.revision = 1
		if err = store.Save(ctx, e.id, e.revision, storage.Checkpoint{World: e.world, Runtime: e.runtime}, nil, nil, nil, nil); err != nil {
			return nil, err
		}
	}
	e.publish()
	return e, nil
}

func defaultRuntime() protocol.Runtime {
	return protocol.Runtime{Paused: true, Speed: 1, View: protocol.ViewState{Overlay: "overview", SelectedHousehold: 0, SelectedPerson: -1, InspectorTab: "inventory", Panel: "overview", Zoom: 1}}
}

func (e *Engine) Run(ctx context.Context) {
	defer close(e.done)
	var writer sync.WaitGroup
	writer.Add(1)
	go func() {
		defer writer.Done()
		for j := range e.commits {
			j.done <- e.store.Save(ctx, j.id, j.revision, j.checkpoint, j.command, j.days, j.events, j.exchanges)
		}
	}()
	defer func() { close(e.commits); writer.Wait() }()
	ticker := time.NewTicker(20 * time.Millisecond)
	defer ticker.Stop()
	last := time.Now()
	budget := 0.0
	for {
		select {
		case <-ctx.Done():
			return
		case r := <-e.requests:
			response := e.handle(ctx, r.command)
			r.reply <- response
			switch r.command.Type {
			case "play", "pause", "speed", "step", "new_world", "reset", "load_world":
				last = time.Now()
				budget = 0
			}
		case now := <-ticker.C:
			elapsed := now.Sub(last).Seconds()
			last = now
			if e.runtime.Paused {
				budget = 0
				continue
			}
			budget += elapsed * e.runtime.Speed
			if budget < 1 {
				continue
			}
			// At high requested speeds work in small batches, allowing input
			// and shutdown between commits. No simulated days are discarded.
			n := min(int(budget), 10)
			budget -= float64(n)
			if err := e.advance(ctx, n, nil); err != nil {
				e.runtime.Paused = true
				e.broadcastError(err)
			}
		}
	}
}

func (e *Engine) Wait() { <-e.done }

func (e *Engine) Submit(ctx context.Context, c protocol.Command) protocol.Message {
	r := request{command: c, reply: make(chan protocol.Message, 1)}
	select {
	case e.requests <- r:
	case <-ctx.Done():
		return fail(c, ctx.Err())
	case <-e.done:
		return fail(c, errors.New("server stopped"))
	}
	select {
	case m := <-r.reply:
		return m
	case <-ctx.Done():
		return fail(c, ctx.Err())
	case <-e.done:
		return fail(c, errors.New("server stopped"))
	}
}

func fail(c protocol.Command, err error) protocol.Message {
	return protocol.Message{Version: protocol.Version, Type: "error", RequestID: c.RequestID, Error: err.Error()}
}

func (e *Engine) handle(ctx context.Context, c protocol.Command) (response protocol.Message) {
	response = protocol.Message{Version: protocol.Version, Type: "ack", RequestID: c.RequestID}
	defer func() {
		if v := recover(); v != nil {
			e.rollback(ctx)
			response = fail(c, fmt.Errorf("simulation command failed: %v", v))
		}
	}()
	if c.RequestID == "" || len(c.RequestID) > 100 {
		return fail(c, errors.New("request_id must contain 1–100 characters"))
	}
	if c.Type == "snapshot" {
		e.publish()
		return response
	}
	if c.Type == "list_worlds" {
		worlds, err := e.store.List(ctx)
		if err != nil {
			return fail(c, err)
		}
		response.Type = "worlds"
		response.Worlds = worlds
		return response
	}
	if c.Type == "export_csv" {
		csv, err := e.store.CSV(ctx, e.id)
		if err != nil {
			return fail(c, err)
		}
		response.Type = "csv"
		response.CSV = csv
		return response
	}
	if c.Type == "events" {
		rows, before, more, err := e.store.Events(ctx, e.id, c.Before, c.Category)
		if err != nil {
			return fail(c, err)
		}
		page := &protocol.EventPage{Items: make([]protocol.EventView, 0, len(rows)), Before: before, HasMore: more}
		for _, ev := range rows {
			page.Items = append(page.Items, eventView(e.world, ev))
		}
		response.Type, response.Events = "events", page
		return response
	}
	if c.Type == "history" {
		page, err := e.store.History(ctx, e.id, c.Before)
		if err != nil {
			return fail(c, err)
		}
		response.Type, response.History = "history", page
		return response
	}
	seen, err := e.store.Seen(ctx, c.RequestID)
	if err != nil {
		return fail(c, err)
	}
	if seen {
		e.publish()
		return response
	}
	if c.Type != "load_world" && c.WorldID != "" && c.WorldID != e.id {
		return fail(c, errors.New("the active world changed; retry in the current world"))
	}
	oldID := e.id
	switch c.Type {
	case "play":
		e.runtime.Paused = false
	case "pause":
		e.runtime.Paused = true
	case "speed":
		if c.Speed == nil || math.IsNaN(*c.Speed) || math.IsInf(*c.Speed, 0) || *c.Speed < 0.25 || *c.Speed > 1000 {
			return fail(c, errors.New("speed must be between 0.25 and 1000"))
		}
		e.runtime.Speed = *c.Speed
	case "step":
		if c.Days < 1 || c.Days > 100 {
			return fail(c, errors.New("step days must be between 1 and 100"))
		}
		e.runtime.Paused = true
		if err = e.advance(ctx, c.Days, &c); err != nil {
			return fail(c, err)
		}
		return response
	case "trade":
		if c.Trade == nil {
			return fail(c, errors.New("trade is required"))
		}
		e.world.TradeEnabled = *c.Trade
	case "regeneration":
		if c.BerryRegenBP == nil || *c.BerryRegenBP < 0 || *c.BerryRegenBP > 100000 {
			return fail(c, errors.New("regeneration must be 0–100000 basis points"))
		}
		e.world.BerryRegenScaleBp = *c.BerryRegenBP
	case "view":
		if c.View == nil {
			return fail(c, errors.New("view is required"))
		}
		if !validView(*c.View, e.world) {
			return fail(c, errors.New("invalid view selection"))
		}
		if c.View.Zoom < 0.2 || c.View.Zoom > 4 || math.IsNaN(c.View.Zoom) || math.IsInf(c.View.Zoom, 0) || math.IsNaN(c.View.CameraX) || math.IsNaN(c.View.CameraY) || math.Abs(c.View.CameraX) > 100000 || math.Abs(c.View.CameraY) > 100000 {
			return fail(c, errors.New("invalid camera"))
		}
		e.runtime.View = *c.View
	case "new_world", "reset":
		cfg := e.world.Cfg
		seed := e.world.Seed
		trade := e.world.TradeEnabled
		regen := e.world.BerryRegenScaleBp
		if c.Type == "new_world" {
			var err error
			seed, err = strconv.ParseUint(c.Seed, 10, 64)
			if err != nil {
				return fail(c, errors.New("seed must be an unsigned 64-bit integer"))
			}
			cfg = sim.DefaultConfig()
			cfg.HouseholdCount = c.Households
			if ok, reason := sim.ValidateConfig(cfg); !ok {
				return fail(c, errors.New(reason))
			}
			trade = true
			regen = 10000
			if c.Trade != nil {
				trade = *c.Trade
			}
			if c.BerryRegenBP != nil {
				regen = *c.BerryRegenBP
			}
			if regen < 0 || regen > 100000 {
				return fail(c, errors.New("invalid regeneration"))
			}
		}
		e.world = sim.WorldCreate(seed, cfg, trade, regen)
		e.runtime = defaultRuntime()
		e.id = uuid.NewString()
		e.revision = 0
	case "load_world":
		checkpoint, rev, err := e.store.Load(ctx, c.WorldID)
		if err != nil {
			return fail(c, errors.New("saved world could not be loaded"))
		}
		e.world, e.runtime, e.id, e.revision = checkpoint.World, checkpoint.Runtime, c.WorldID, rev
		e.runtime.Paused = true
	default:
		return fail(c, errors.New("unknown command: "+c.Type))
	}
	if err = e.commit(ctx, &c, nil, nil, nil); err != nil {
		e.id = oldID
		e.rollback(ctx)
		return fail(c, err)
	}
	e.publish()
	return response
}

func (e *Engine) advance(ctx context.Context, n int, c *protocol.Command) (err error) {
	defer func() {
		if v := recover(); v != nil {
			e.rollback(ctx)
			err = fmt.Errorf("simulation stopped: %v", v)
		}
	}()
	days := make([]sim.DayMetrics, 0, n)
	events := []sim.Event{}
	exchanges := []sim.Exchange{}
	for i := 0; i < n; i++ {
		day := e.world.Day
		sim.SimDay(e.world)
		days = append(days, sim.LatestMetrics(e.world))
		for j := uint32(0); j < e.world.Events.Count; j++ {
			ev := sim.EventAt(&e.world.Events, j)
			if ev.Day == day {
				events = append(events, ev)
			}
		}
		start := uint32(0)
		if e.world.Exchanges.Count == sim.EXCHANGE_CAP {
			start = e.world.Exchanges.Head
		}
		for j := uint32(0); j < e.world.Exchanges.Count; j++ {
			ev := e.world.Exchanges.Items[(start+j)%sim.EXCHANGE_CAP]
			if ev.Day == day {
				exchanges = append(exchanges, ev)
			}
		}
	}
	if err = e.commit(ctx, c, days, events, exchanges); err != nil {
		e.rollback(ctx)
		return err
	}
	e.publish()
	return nil
}

func (e *Engine) commit(ctx context.Context, c *protocol.Command, days []sim.DayMetrics, events []sim.Event, exchanges []sim.Exchange) error {
	done := make(chan error, 1)
	j := commitJob{id: e.id, revision: e.revision + 1, checkpoint: storage.Checkpoint{World: e.world, Runtime: e.runtime}, command: c, days: days, events: events, exchanges: exchanges, done: done}
	select {
	case e.commits <- j:
	case <-ctx.Done():
		return ctx.Err()
	}
	// The writer reads the exclusively owned world while the owner waits.
	// Never return before it is done: that would race the next mutation.
	err := <-done
	if err == nil {
		e.revision++
	}
	return err
}

func (e *Engine) rollback(ctx context.Context) {
	c, rev, err := e.store.Load(ctx, e.id)
	if err == nil {
		e.world, e.runtime, e.revision = c.World, c.Runtime, rev
	}
	e.runtime.Paused = true
	e.publish()
}

func (e *Engine) Subscribe() (chan []byte, func()) {
	e.mu.Lock()
	defer e.mu.Unlock()
	ch := make(chan []byte, 1)
	e.subs[ch] = struct{}{}
	if e.latest != nil {
		ch <- e.latest
	}
	return ch, func() { e.mu.Lock(); delete(e.subs, ch); e.mu.Unlock() }
}

func (e *Engine) broadcast(data []byte, latest bool) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if latest {
		e.latest = data
	}
	for ch := range e.subs {
		select {
		case ch <- data:
		default:
			select {
			case <-ch:
			default:
			}
			select {
			case ch <- data:
			default:
			}
		}
	}
}
func (e *Engine) publish() {
	data, err := json.Marshal(protocol.Message{Version: protocol.Version, Type: "snapshot", Snapshot: e.snapshot()})
	if err != nil {
		panic(err)
	}
	e.broadcast(data, true)
}
func (e *Engine) broadcastError(err error) {
	data, _ := json.Marshal(protocol.Message{Version: protocol.Version, Type: "error", Error: "Simulation paused: " + err.Error()})
	e.broadcast(data, false)
}

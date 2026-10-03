package storage

import (
	"blackbox/internal/sim"
	"context"
	"encoding/json"
)

// Keyset pagination retains access to every event after the simulation's
// bounded in-memory ring wraps. IDs, never SQL fragments, come from the client.
func (s *Store) Events(ctx context.Context, world string, before uint64, category string) ([]sim.Event, uint64, bool, error) {
	q := s.DB.WithContext(ctx).Where("world_id = ?", world)
	if before > 0 {
		q = q.Where("id < ?", before)
	}
	if category != "" && category != "All" {
		// With sparse categories SQLite may prefer the cursor-only index and
		// scan millions of rows to satisfy ORDER BY. Seek each kind instead.
		q = q.Table("event_records INDEXED BY idx_events_world_kind_cursor")
		kinds := []int{}
		for k := sim.Work_Completed; k <= sim.Household_Founded; k++ {
			if sim.EventCategory(k) == category {
				kinds = append(kinds, k)
			}
		}
		q = q.Where("kind IN ?", kinds)
	}
	var rows []EventRecord
	if err := q.Order("id DESC").Limit(101).Find(&rows).Error; err != nil {
		return nil, 0, false, err
	}
	more := len(rows) > 100
	if more {
		rows = rows[:100]
	}
	out := make([]sim.Event, 0, len(rows))
	var cursor uint64
	for _, r := range rows {
		var ev sim.Event
		if err := json.Unmarshal(r.Data, &ev); err != nil {
			return nil, 0, false, err
		}
		out = append(out, ev)
		cursor = r.ID
	}
	return out, cursor, more, nil
}

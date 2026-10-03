package storage

import (
	"blackbox/internal/protocol"
	"blackbox/internal/sim"
	"context"
	"encoding/json"
	"slices"
)

// Keep large history pages off the high-frequency live snapshot channel.
func (s *Store) History(ctx context.Context, world string, before uint64) (*protocol.HistoryPage, error) {
	q := s.DB.WithContext(ctx).Where("world_id = ?", world)
	if before > 0 {
		q = q.Where("day < ?", before)
	}
	var rows []MetricRecord
	if err := q.Order("day DESC").Limit(4097).Find(&rows).Error; err != nil {
		return nil, err
	}
	page := &protocol.HistoryPage{Items: make([]sim.DayMetrics, 0, len(rows)), HasMore: len(rows) > 4096}
	if page.HasMore {
		rows = rows[:4096]
	}
	for _, r := range rows {
		var m sim.DayMetrics
		if err := json.Unmarshal(r.Data, &m); err != nil {
			return nil, err
		}
		page.Items = append(page.Items, m)
		page.Before = uint64(m.Day)
	}
	slices.Reverse(page.Items)
	return page, nil
}

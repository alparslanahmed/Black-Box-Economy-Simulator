// Package storage owns the durable SQLite boundary. A command is acknowledged
// only after its resulting world and audit record commit in one transaction.
package storage

import (
	"blackbox/internal/protocol"
	"blackbox/internal/sim"
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"gorm.io/gorm/logger"
)

const SchemaVersion = 1

type WorldRecord struct {
	ID            string `gorm:"primaryKey"`
	SchemaVersion int
	Seed          string
	Day           int
	People        int
	Households    int
	Revision      uint64
	State         []byte
	UpdatedAt     time.Time
}
type Setting struct {
	Key   string `gorm:"primaryKey"`
	Value string
}
type MetricRecord struct {
	WorldID string `gorm:"primaryKey"`
	Day     int    `gorm:"primaryKey"`
	Data    []byte
}
type EventRecord struct {
	ID      uint64 `gorm:"primaryKey;autoIncrement"`
	WorldID string `gorm:"index:idx_events_world_day"`
	Day     int    `gorm:"index:idx_events_world_day"`
	Kind    int
	Data    []byte
}
type ExchangeRecord struct {
	ID      uint64 `gorm:"primaryKey;autoIncrement"`
	WorldID string `gorm:"index"`
	Day     int
	Data    []byte
}
type CommandRecord struct {
	ID        uint64 `gorm:"primaryKey;autoIncrement"`
	WorldID   string `gorm:"index"`
	RequestID string `gorm:"uniqueIndex"`
	Day       int
	Data      []byte
	CreatedAt time.Time
}

// A checkpoint contains every field needed to continue, including PCG state,
// deceased ancestors, pregnancy history, demand memory and individual tools.
type Checkpoint struct {
	World   *sim.World       `json:"world"`
	Runtime protocol.Runtime `json:"runtime"`
}

type Store struct{ DB *gorm.DB }

func Open(path string) (*Store, error) {
	if path != ":memory:" {
		if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
			return nil, err
		}
	}
	db, err := gorm.Open(sqlite.Open(path), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent), NowFunc: func() time.Time { return time.Now().UTC() }})
	if err != nil {
		return nil, err
	}
	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}
	sqlDB.SetMaxOpenConns(1) // SQLite has one writer; bounded goroutines queue writes.
	for _, sql := range []string{"PRAGMA journal_mode=WAL", "PRAGMA synchronous=FULL", "PRAGMA foreign_keys=ON", "PRAGMA busy_timeout=5000"} {
		if err = db.Exec(sql).Error; err != nil {
			sqlDB.Close()
			return nil, err
		}
	}
	if err = db.AutoMigrate(&WorldRecord{}, &Setting{}, &MetricRecord{}, &EventRecord{}, &ExchangeRecord{}, &CommandRecord{}, &ExperimentRecord{}); err != nil {
		sqlDB.Close()
		return nil, err
	}
	// Archive pagination must seek by world/cursor (and kind), not sort all
	// daily events. Long runs can contain millions of observations.
	for _, index := range []string{
		"CREATE INDEX IF NOT EXISTS idx_events_world_cursor ON event_records(world_id, id)",
		"CREATE INDEX IF NOT EXISTS idx_events_world_kind_cursor ON event_records(world_id, kind, id)",
	} {
		if err = db.Exec(index).Error; err != nil {
			sqlDB.Close()
			return nil, err
		}
	}
	return &Store{DB: db}, nil
}

func (s *Store) Close() error {
	db, err := s.DB.DB()
	if err != nil {
		return err
	}
	return db.Close()
}

func Encode(c Checkpoint) ([]byte, error) {
	var b bytes.Buffer
	z, _ := gzip.NewWriterLevel(&b, gzip.BestSpeed)
	if err := json.NewEncoder(z).Encode(c); err != nil {
		return nil, err
	}
	if err := z.Close(); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}
func Decode(data []byte) (Checkpoint, error) {
	var c Checkpoint
	z, err := gzip.NewReader(bytes.NewReader(data))
	if err != nil {
		return c, err
	}
	defer z.Close()
	data, err = io.ReadAll(io.LimitReader(z, (256<<20)+1))
	if err != nil {
		return c, err
	}
	if len(data) > 256<<20 {
		return c, errors.New("checkpoint exceeds size limit")
	}
	if err = json.Unmarshal(data, &c); err != nil {
		return c, err
	}
	if c.World == nil {
		return c, errors.New("checkpoint has no world")
	}
	w := c.World
	if ok, reason := sim.ValidateConfig(w.Cfg); !ok {
		return c, fmt.Errorf("invalid saved config: %s", reason)
	}
	if len(w.Cells) != w.Cfg.MapW*w.Cfg.MapH || w.PersonCount < 0 || w.PersonCount > len(w.People) || w.Events.Count > sim.EVENT_CAP || w.Events.Head >= sim.EVENT_CAP || w.Metrics.Count > sim.METRICS_CAP || w.Metrics.Head >= sim.METRICS_CAP || w.Exchanges.Count > sim.EXCHANGE_CAP || w.Exchanges.Head >= sim.EXCHANGE_CAP {
		return c, errors.New("invalid saved world dimensions or ring buffers")
	}
	return c, nil
}

func (s *Store) Active(ctx context.Context) (string, error) {
	var v Setting
	err := s.DB.WithContext(ctx).First(&v, "key = ?", "active_world").Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return "", nil
	}
	return v.Value, err
}
func (s *Store) Load(ctx context.Context, id string) (Checkpoint, uint64, error) {
	var row WorldRecord
	if err := s.DB.WithContext(ctx).First(&row, "id = ?", id).Error; err != nil {
		return Checkpoint{}, 0, err
	}
	if row.SchemaVersion != SchemaVersion {
		return Checkpoint{}, 0, fmt.Errorf("unsupported world schema %d", row.SchemaVersion)
	}
	c, err := Decode(row.State)
	return c, row.Revision, err
}
func (s *Store) List(ctx context.Context) ([]protocol.WorldSummary, error) {
	var rows []WorldRecord
	err := s.DB.WithContext(ctx).Select("id, seed, day, people, households, updated_at").Order("updated_at desc").Find(&rows).Error
	sort.SliceStable(rows, func(i, j int) bool { return rows[i].UpdatedAt.After(rows[j].UpdatedAt) })
	result := make([]protocol.WorldSummary, 0, len(rows))
	for _, r := range rows {
		result = append(result, protocol.WorldSummary{ID: r.ID, Seed: r.Seed, Day: r.Day, People: r.People, Households: r.Households, UpdatedAt: r.UpdatedAt.UTC().Format(time.RFC3339)})
	}
	return result, err
}

func (s *Store) Seen(ctx context.Context, requestID string) (bool, error) {
	if requestID == "" {
		return false, nil
	}
	var n int64
	err := s.DB.WithContext(ctx).Model(&CommandRecord{}).Where("request_id = ?", requestID).Count(&n).Error
	return n > 0, err
}

func (s *Store) Save(ctx context.Context, id string, revision uint64, c Checkpoint, command *protocol.Command, days []sim.DayMetrics, events []sim.Event, exchanges []sim.Exchange) error {
	data, err := Encode(c)
	if err != nil {
		return err
	}
	w := c.World
	row := WorldRecord{ID: id, SchemaVersion: SchemaVersion, Seed: strconv.FormatUint(w.Seed, 10), Day: w.Day, People: sim.AliveCount(w), Households: sim.AliveHouseholds(w), Revision: revision, State: data, UpdatedAt: time.Now().UTC()}
	return s.DB.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		write := tx.Clauses(clause.OnConflict{UpdateAll: true, Where: clause.Where{Exprs: []clause.Expression{clause.Expr{SQL: "world_records.revision = ?", Vars: []any{revision - 1}}}}}).Create(&row)
		if write.Error != nil {
			return write.Error
		}
		if write.RowsAffected != 1 {
			return errors.New("world was changed by another server; reload before continuing")
		}
		if err := tx.Clauses(clause.OnConflict{UpdateAll: true}).Create(&Setting{Key: "active_world", Value: id}).Error; err != nil {
			return err
		}
		for _, m := range days {
			b, err := json.Marshal(m)
			if err != nil {
				return err
			}
			if err = tx.Clauses(clause.OnConflict{UpdateAll: true}).Create(&MetricRecord{WorldID: id, Day: m.Day, Data: b}).Error; err != nil {
				return err
			}
		}
		erows := make([]EventRecord, 0, len(events))
		for _, e := range events {
			b, err := json.Marshal(e)
			if err != nil {
				return err
			}
			erows = append(erows, EventRecord{WorldID: id, Day: e.Day, Kind: e.Kind, Data: b})
		}
		if len(erows) > 0 {
			if err := tx.CreateInBatches(erows, 100).Error; err != nil {
				return err
			}
		}
		for _, e := range exchanges {
			b, err := json.Marshal(e)
			if err != nil {
				return err
			}
			if err = tx.Create(&ExchangeRecord{WorldID: id, Day: e.Day, Data: b}).Error; err != nil {
				return err
			}
		}
		if command != nil {
			b, err := json.Marshal(command)
			if err != nil {
				return err
			}
			if err = tx.Create(&CommandRecord{WorldID: id, RequestID: command.RequestID, Day: w.Day, Data: b, CreatedAt: time.Now().UTC()}).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *Store) CSV(ctx context.Context, id string) (string, error) {
	var b strings.Builder
	b.WriteString(sim.CSVHeader)
	rows, err := s.DB.WithContext(ctx).Model(&MetricRecord{}).Where("world_id = ?", id).Order("day").Rows()
	if err != nil {
		return "", err
	}
	defer rows.Close()
	for rows.Next() {
		var row MetricRecord
		if err = s.DB.ScanRows(rows, &row); err != nil {
			return "", err
		}
		var m sim.DayMetrics
		if err = json.Unmarshal(row.Data, &m); err != nil {
			return "", err
		}
		b.WriteString(sim.MetricsCSV(m))
	}
	return b.String(), rows.Err()
}

package storage

import (
	"blackbox/internal/experiments"
	"context"
	"encoding/json"
	"time"
)

type ExperimentRecord struct {
	ID        string
	Kind      string
	Options   []byte
	Results   []byte
	CSV       string
	CreatedAt time.Time
}

func (s *Store) SaveExperiment(ctx context.Context, id string, options experiments.Options, results []experiments.Result) error {
	o, err := json.Marshal(options)
	if err != nil {
		return err
	}
	r, err := json.Marshal(results)
	if err != nil {
		return err
	}
	return s.DB.WithContext(ctx).Create(&ExperimentRecord{ID: id, Kind: options.Kind, Options: o, Results: r, CSV: experiments.CSV(options.Kind, results), CreatedAt: time.Now().UTC()}).Error
}

package main

import (
	"blackbox/internal/experiments"
	"blackbox/internal/storage"
	"context"
	"flag"
	"fmt"
	"github.com/google/uuid"
	"os"
	"os/signal"
	"runtime"
)

func run() error {
	kind := flag.String("kind", "trade", "trade or scarcity")
	days := flag.Int("days", 0, "days per world (trade: 720, scarcity: 360)")
	seeds := flag.Int("seeds", 0, "paired seeds (trade: 20, scarcity: 8)")
	households := flag.Int("households", 40, "initial households")
	workers := flag.Int("workers", min(runtime.GOMAXPROCS(0), 4), "independent concurrent worlds (1–64)")
	db := flag.String("db", "data/blackbox.db", "SQLite results database")
	csv := flag.String("csv", "", "optional CSV export path")
	flag.Parse()
	if *days == 0 {
		*days = 720
		if *kind == "scarcity" {
			*days = 360
		}
	}
	if *seeds == 0 {
		*seeds = 20
		if *kind == "scarcity" {
			*seeds = 8
		}
	}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()
	opts := experiments.Options{Kind: *kind, Days: *days, Seeds: *seeds, Households: *households, Workers: *workers}
	fmt.Printf("Running %s: %d paired seeds × %d days, %d workers\n", *kind, *seeds, *days, *workers)
	results, err := experiments.Run(ctx, opts)
	if err != nil {
		return err
	}
	store, err := storage.Open(*db)
	if err != nil {
		return err
	}
	defer store.Close()
	id := uuid.NewString()
	if err = store.SaveExperiment(ctx, id, opts, results); err != nil {
		return err
	}
	if *csv != "" {
		if err = os.WriteFile(*csv, []byte(experiments.CSV(*kind, results)), 0644); err != nil {
			return err
		}
	}
	for _, r := range results {
		fmt.Printf("seed=%s trade=%t regen=%d alive=%d deaths=%d food_days=%.3f spec=%.4f\n", r.Seed, r.Trade, r.RegenBP, r.Alive, r.Deaths, float64(r.FoodDays)/1000, float64(r.Specialization)/10000)
	}
	fmt.Printf("Saved experiment %s to %s\n", id, *db)
	return nil
}
func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

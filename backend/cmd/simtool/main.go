// simtool runs the same authoritative simulation without a server or renderer.
package main

import (
	"blackbox/internal/sim"
	"blackbox/internal/storage"
	"bufio"
	"context"
	"flag"
	"fmt"
	"os"
)

func main() {
	seed := flag.Uint64("seed", 12345, "deterministic world seed")
	days := flag.Int("days", 500, "days to simulate")
	households := flag.Int("households", 40, "initial households (1–1000)")
	trade := flag.Bool("trade", true, "enable voluntary barter")
	regen := flag.Int("berry-regen-bp", 10000, "berry regeneration scale; zero disables it")
	csvPath := flag.String("csv", "", "write every day's metrics")
	dbPath := flag.String("db", "data/headless.db", "SQLite checkpoint/history database; empty disables persistence for benchmarks")
	flag.Parse()
	cfg := sim.DefaultConfig()
	cfg.HouseholdCount = *households
	if ok, reason := sim.ValidateConfig(cfg); !ok {
		fmt.Fprintln(os.Stderr, reason)
		os.Exit(1)
	}
	if *days < 0 || *regen < 0 {
		fmt.Fprintln(os.Stderr, "days and regeneration must be nonnegative")
		os.Exit(1)
	}
	w := sim.WorldCreate(*seed, cfg, *trade, *regen)
	var recorder *storage.Recorder
	if *dbPath != "" {
		store, err := storage.Open(*dbPath)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		defer store.Close()
		recorder = storage.NewRecorder(store)
	}
	var f *os.File
	var writer *bufio.Writer
	if *csvPath != "" {
		var err error
		f, err = os.Create(*csvPath)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		writer = bufio.NewWriter(f)
		if _, err = writer.WriteString(sim.CSVHeader); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}
	for i := 0; i < *days; i++ {
		sim.SimDay(w)
		if recorder != nil {
			recorder.Capture(w)
			if (i+1)%25 == 0 {
				if err := recorder.Flush(context.Background(), w); err != nil {
					fmt.Fprintln(os.Stderr, err)
					os.Exit(1)
				}
			}
		}
		if writer != nil {
			if _, err := writer.WriteString(sim.MetricsCSV(sim.LatestMetrics(w))); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
		}
	}
	if recorder != nil {
		if *days == 0 || *days%25 != 0 {
			if err := recorder.Flush(context.Background(), w); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
		}
		fmt.Printf("saved_world=%s database=%s\n", recorder.ID, *dbPath)
	}
	if writer != nil {
		if err := writer.Flush(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if err := f.Close(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}
	fmt.Printf("day=%d people=%d households=%d hash=%d\n", w.Day, sim.AliveCount(w), sim.AliveHouseholds(w), sim.StateHash(w))
}

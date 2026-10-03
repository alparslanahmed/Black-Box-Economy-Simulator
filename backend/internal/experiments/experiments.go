// Package experiments runs independent seeded worlds in a bounded worker pool.
// Each job owns its RNG and world; output order never depends on scheduling.
package experiments

import (
	"blackbox/internal/sim"
	"context"
	"fmt"
	"strconv"
	"strings"
	"sync"
)

type Options struct {
	Kind       string
	Days       int
	Seeds      int
	Households int
	Workers    int
}
type Result struct {
	Seed             string
	Trade            bool
	RegenBP          int
	Alive            int
	Deaths           int
	FoodDays         int64
	Specialization   int
	ProducedFood     int64
	ProducedSpears   int64
	SuccessfulTrades int
	Hungry           int
	MeatBerryRatio   int64
	Hash             string
}

func Run(ctx context.Context, o Options) ([]Result, error) {
	if o.Kind != "trade" && o.Kind != "scarcity" {
		return nil, fmt.Errorf("experiment must be trade or scarcity")
	}
	if o.Days < 1 || o.Seeds < 1 || o.Seeds > 10000 || o.Workers < 1 || o.Workers > 64 {
		return nil, fmt.Errorf("days/seeds/workers must be positive; seeds <= 10000, workers <= 64")
	}
	cfg := sim.DefaultConfig()
	cfg.HouseholdCount = o.Households
	if ok, reason := sim.ValidateConfig(cfg); !ok {
		return nil, fmt.Errorf("%s", reason)
	}
	out := make([]Result, o.Seeds*2)
	jobs := make(chan int)
	var wg sync.WaitGroup
	for worker := 0; worker < min(o.Workers, len(out)); worker++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				if ctx.Err() != nil {
					return
				}
				seed, trade, regen := uint64(10001+(i/2)*9973), i%2 == 0, 10000
				if o.Kind == "scarcity" {
					seed, trade = uint64(424242+(i/2)*8191), true
					if i%2 == 1 {
						regen = 5000
					}
				}
				w := sim.WorldCreate(seed, cfg, trade, regen)
				var food, spears int64
				for d := 0; d < o.Days; d++ {
					if ctx.Err() != nil {
						return
					}
					sim.SimDay(w)
					m := sim.LatestMetrics(w)
					// Accumulate while running so experiments beyond METRICS_CAP retain totals.
					food += m.Produced[sim.Berries] + m.Produced[sim.Meat]
					spears += m.Produced[sim.Spear]
				}
				m := sim.LatestMetrics(w)
				out[i] = Result{Seed: strconv.FormatUint(seed, 10), Trade: trade, RegenBP: regen, Alive: m.Alive, Deaths: w.TotalDeaths, FoodDays: m.FoodDaysAvgMilli, Specialization: m.SpecAvgBp, ProducedFood: food, ProducedSpears: spears, SuccessfulTrades: m.SuccessfulTrades, Hungry: m.Hungry, MeatBerryRatio: m.BerriesPerUnit[sim.Meat], Hash: strconv.FormatUint(sim.StateHash(w), 16)}
			}
		}()
	}
dispatch:
	for i := range out {
		select {
		case jobs <- i:
		case <-ctx.Done():
			break dispatch
		}
	}
	close(jobs)
	wg.Wait()
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

func CSV(kind string, rows []Result) string {
	var b strings.Builder
	if kind == "trade" {
		b.WriteString("seed,trade,alive,deaths,food_days,spec,produced_food_qty,produced_spears,successful_trades,hungry_last\n")
	} else {
		b.WriteString("seed,berry_regen_bp,alive,deaths,food_days,spec,berries_per_meat,hungry_last\n")
	}
	for _, r := range rows {
		if kind == "trade" {
			fmt.Fprintf(&b, "%s,%t,%d,%d,%.3f,%.4f,%d,%d,%d,%d\n", r.Seed, r.Trade, r.Alive, r.Deaths, float64(r.FoodDays)/1000, float64(r.Specialization)/10000, r.ProducedFood, r.ProducedSpears, r.SuccessfulTrades, r.Hungry)
		} else {
			ratio := ""
			if r.MeatBerryRatio >= 0 {
				ratio = fmt.Sprintf("%.3f", float64(r.MeatBerryRatio)/1000)
			}
			fmt.Fprintf(&b, "%s,%d,%d,%d,%.3f,%.4f,%s,%d\n", r.Seed, r.RegenBP, r.Alive, r.Deaths, float64(r.FoodDays)/1000, float64(r.Specialization)/10000, ratio, r.Hungry)
		}
	}
	return b.String()
}

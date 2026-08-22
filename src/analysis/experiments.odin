package analysis

import "core:fmt"
import "core:os"
import "core:strings"
import sim "../sim"

run_trade_experiment :: proc(days: i32 = 720, n_seeds: i32 = 20, households: i32 = 40) {
	fmt.printf("=== TRADE ON vs TRADE OFF  seeds=%d days=%d households=%d ===\n", n_seeds, days, households)
	cfg := sim.default_config()
	cfg.household_count = households

	b: strings.Builder
	strings.builder_init(&b)
	defer strings.builder_destroy(&b)
	strings.write_string(&b, "seed,trade,alive,deaths,food_days,spec,produced_food_qty,produced_spears,successful_trades,hungry_last\n")

	sum_alive: [2]i64
	sum_spec: [2]i64
	sum_food: [2]i64
	sum_deaths: [2]i64
	sum_prod: [2]i64

	base_seed: u64 = 10001
	for i: i32 = 0; i < n_seeds; i += 1 {
		seed := base_seed + u64(i) * 9973
		for t in 0 ..< 2 {
			trade := t == 0
			w := sim.world_create(seed, cfg, trade)
			sim.sim_days(w, days)
			m := sim.latest_metrics(w)
			prod_food, prod_spear: i64
			for k: u32 = 0; k < w.metrics.count; k += 1 {
				row := sim.metrics_at(&w.metrics, k)
				prod_food += row.produced[sim.Good.Berries] + row.produced[sim.Good.Meat]
				prod_spear += row.produced[sim.Good.Spear]
			}
			idx := t
			sum_alive[idx] += i64(m.alive)
			sum_spec[idx] += i64(m.spec_avg_bp)
			sum_food[idx] += m.food_days_avg_milli
			sum_deaths[idx] += i64(w.total_deaths)
			sum_prod[idx] += prod_food
			fmt.printf(
				"seed %v trade=%v alive=%d deaths=%d food_days=%.2f spec=%.2f food_prod=%s spears=%s trades_last=%d\n",
				seed, trade, m.alive, w.total_deaths,
				f64(m.food_days_avg_milli) / 1000.0,
				f64(m.spec_avg_bp) / 10000.0,
				sim.format_qty(prod_food),
				sim.format_qty(prod_spear),
				m.successful_trades,
			)
			strings.write_string(&b, fmt.tprintf(
				"%v,%v,%d,%d,%.3f,%.4f,%d,%d,%d,%d\n",
				seed, trade, m.alive, w.total_deaths,
				f64(m.food_days_avg_milli) / 1000.0,
				f64(m.spec_avg_bp) / 10000.0,
				prod_food, prod_spear, m.successful_trades, m.hungry,
			))
			sim.world_destroy(w)
		}
	}

	n := i64(n_seeds)
	fmt.println("\n--- averages ---")
	label := [2]string{"TRADE ON", "TRADE OFF"}
	for t in 0 ..< 2 {
		fmt.printf(
			"%s  alive=%.2f  deaths=%.2f  food_days=%.2f  spec=%.3f  food_prod=%s\n",
			label[t],
			f64(sum_alive[t]) / f64(n),
			f64(sum_deaths[t]) / f64(n),
			f64(sum_food[t]) / f64(n) / 1000.0,
			f64(sum_spec[t]) / f64(n) / 10000.0,
			sim.format_qty(sum_prod[t] / n),
		)
	}
	err := os.write_entire_file("build/experiment_trade.csv", transmute([]u8)strings.to_string(b))
	if err != nil {
		fmt.eprintf("failed to write build/experiment_trade.csv: %v\n", err)
	} else {
		fmt.println("wrote build/experiment_trade.csv")
	}
}

run_scarcity_experiment :: proc(days: i32 = 360, n_seeds: i32 = 8, households: i32 = 40) {
	fmt.printf("=== BERRY REGEN 100%% vs 50%%  seeds=%d days=%d ===\n", n_seeds, days)
	cfg := sim.default_config()
	cfg.household_count = households
	base_seed: u64 = 424242
	for i: i32 = 0; i < n_seeds; i += 1 {
		seed := base_seed + u64(i) * 8191
		for scale, tag in ([2]i32{10000, 5000}) {
			_ = tag
			w := sim.world_create(seed, cfg, true, scale)
			sim.sim_days(w, days)
			m := sim.latest_metrics(w)
			fmt.printf(
				"seed %v regen=%d%% alive=%d deaths=%d food_days=%.2f spec=%.2f meat/berry=%s hungry=%d\n",
				seed, scale / 100, m.alive, w.total_deaths,
				f64(m.food_days_avg_milli) / 1000.0,
				f64(m.spec_avg_bp) / 10000.0,
				ratio_csv(m.berries_per_unit[sim.Good.Meat]),
				m.hungry,
			)
			sim.world_destroy(w)
		}
	}
}

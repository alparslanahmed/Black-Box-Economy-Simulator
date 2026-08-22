package analysis

import "core:fmt"
import sim "../sim"

Headless_Opts :: struct {
	seed:            u64,
	days:            i32,
	households:      i32,
	trade:           bool,
	csv_path:        string,
	berry_regen_bp:  i32,
	print_every:     i32,
}

run_headless :: proc(opts: Headless_Opts) -> bool {
	cfg := sim.default_config()
	if opts.households > 0 {
		cfg.household_count = opts.households
	}
	ok, err := sim.validate_config(cfg)
	if !ok {
		fmt.eprintf("invalid config: %s\n", err)
		return false
	}
	scale := opts.berry_regen_bp if opts.berry_regen_bp > 0 else sim.BP_SCALE
	w := sim.world_create(opts.seed, cfg, opts.trade, scale)
	defer sim.world_destroy(w)

	sink: Csv_Sink
	if opts.csv_path != "" {
		sink = csv_sink_open(opts.csv_path)
	}
	defer if opts.csv_path != "" {
		if !csv_sink_close(&sink) {
			fmt.eprintf("failed to write CSV %s\n", opts.csv_path)
		} else {
			fmt.printf("wrote %s\n", opts.csv_path)
		}
	}

	every := opts.print_every if opts.print_every > 0 else 50
	fmt.printf(
		"headless seed=%v days=%d households=%d trade=%v berry_regen_bp=%d\n",
		opts.seed, opts.days, cfg.household_count, opts.trade, scale,
	)

	for d: i32 = 0; d < opts.days; d += 1 {
		sim.sim_day(w)
		m := sim.latest_metrics(w)
		if opts.csv_path != "" {
			csv_sink_row(&sink, m)
		}
		if d % every == 0 || d == opts.days - 1 {
			fmt.printf(
				"day %d  people=%d  camps=%d  food_days=%.2f  health=%d  visits=%d  trades=%d/%d  spec=%.2f  hungry=%d  deaths=%d  births=%d  wed_total=%d  hash=%v\n",
				m.day,
				m.alive,
				m.alive_households,
				f64(m.food_days_avg_milli) / 1000.0,
				m.median_health,
				m.visits,
				m.successful_trades,
				m.trade_attempts,
				f64(m.spec_avg_bp) / 10000.0,
				m.hungry,
				w.total_deaths,
				m.births,
				w.total_marriages,
				sim.state_hash(w),
			)
		}
	}
	return true
}

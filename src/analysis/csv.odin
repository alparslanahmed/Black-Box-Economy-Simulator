package analysis

import "core:fmt"
import "core:os"
import "core:strings"
import sim "../sim"

csv_header :: "day,year,alive_households,food_total,food_days_average,median_health,berries_produced,meat_produced,wood_produced,stone_produced,spears_produced,trade_attempts,successful_trades,trade_success_rate,specialization_average,hunters,foragers,wood_gatherers,stone_gatherers,toolmakers,generalists,hungry_households,deaths_today,berries_resource_stock,game_resource_stock,wood_resource_stock,stone_resource_stock,meat_per_berry,wood_per_berry,stone_per_berry,spear_per_berry,people,births_today\n"

qty_csv :: proc(q: i64) -> string {
	if q < 0 {
		return "NA"
	}
	whole := q / sim.QTY_SCALE
	frac := (q % sim.QTY_SCALE) / 10
	return fmt.tprintf("%d.%03d", whole, frac)
}

ratio_csv :: proc(q: i64) -> string {
	if q < 0 {
		return "NA"
	}
	whole := q / sim.QTY_SCALE
	frac := (q % sim.QTY_SCALE) / 10
	return fmt.tprintf("%d.%03d", whole, frac)
}

metrics_csv_row :: proc(m: sim.Day_Metrics) -> string {
	food_days := f64(m.food_days_avg_milli) / 1000.0
	success_rate := f64(m.trade_success_bp) / 10000.0
	spec := f64(m.spec_avg_bp) / 10000.0
	return fmt.tprintf(
		"%d,%d,%d,%s,%.3f,%d,%s,%s,%s,%s,%s,%d,%d,%.4f,%.4f,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%d,%d\n",
		m.day,
		m.year,
		m.alive_households,
		qty_csv(m.food_total),
		food_days,
		m.median_health,
		qty_csv(m.produced[sim.Good.Berries]),
		qty_csv(m.produced[sim.Good.Meat]),
		qty_csv(m.produced[sim.Good.Wood]),
		qty_csv(m.produced[sim.Good.Stone]),
		qty_csv(m.produced[sim.Good.Spear]),
		m.trade_attempts,
		m.successful_trades,
		success_rate,
		spec,
		m.role_counts[sim.Role.Hunter],
		m.role_counts[sim.Role.Forager],
		m.role_counts[sim.Role.Wood_Gatherer],
		m.role_counts[sim.Role.Stone_Gatherer],
		m.role_counts[sim.Role.Toolmaker],
		m.role_counts[sim.Role.Generalist],
		m.hungry,
		m.deaths,
		qty_csv(m.resource_stock[0]),
		qty_csv(m.resource_stock[1]),
		qty_csv(m.resource_stock[2]),
		qty_csv(m.resource_stock[3]),
		ratio_csv(m.unit_per_berry[sim.Good.Meat]),
		ratio_csv(m.unit_per_berry[sim.Good.Wood]),
		ratio_csv(m.unit_per_berry[sim.Good.Stone]),
		ratio_csv(m.unit_per_berry[sim.Good.Spear]),
		m.alive,
		m.births,
	)
}

csv_write_world :: proc(path: string, w: ^sim.World) -> bool {
	b: strings.Builder
	strings.builder_init(&b)
	defer strings.builder_destroy(&b)
	strings.write_string(&b, csv_header)
	n := w.metrics.count
	for i: u32 = 0; i < n; i += 1 {
		m := sim.metrics_at(&w.metrics, i)
		strings.write_string(&b, metrics_csv_row(m))
	}
	err := os.write_entire_file(path, transmute([]u8)strings.to_string(b))
	return err == nil
}

Csv_Sink :: struct {
	path:    string,
	builder: strings.Builder,
	ok:      bool,
}

csv_sink_open :: proc(path: string) -> Csv_Sink {
	s: Csv_Sink
	s.path = path
	s.ok = true
	strings.builder_init(&s.builder)
	strings.write_string(&s.builder, csv_header)
	return s
}

csv_sink_row :: proc(s: ^Csv_Sink, m: sim.Day_Metrics) {
	if !s.ok || s.path == "" {
		return
	}
	strings.write_string(&s.builder, metrics_csv_row(m))
}

csv_sink_close :: proc(s: ^Csv_Sink) -> bool {
	if !s.ok || s.path == "" {
		strings.builder_destroy(&s.builder)
		return s.path == ""
	}
	err := os.write_entire_file(s.path, transmute([]u8)strings.to_string(s.builder))
	strings.builder_destroy(&s.builder)
	return err == nil
}

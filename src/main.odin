package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "analysis"
import "game"
import "sim"

Args :: struct {
	headless:       bool,
	test:           bool,
	help:           bool,
	experiment:     string,
	seed:           u64,
	seed_set:       bool,
	days:           i32,
	households:     i32,
	trade:          bool,
	csv_path:       string,
	berry_regen_bp: i32,
	gui:            bool,
}

parse_args :: proc() -> Args {
	a := Args{
		seed = 12345,
		days = 500,
		households = sim.HOUSEHOLDS_DEFAULT,
		trade = true,
		berry_regen_bp = sim.BP_SCALE,
		gui = true,
	}
	args := os.args
	for i := 1; i < len(args); i += 1 {
		s := args[i]
		eat :: proc(i: ^int, args: []string) -> string {
			if i^ + 1 >= len(args) {
				return ""
			}
			i^ += 1
			return args[i^]
		}
		switch s {
		case "-h", "--help":
			a.help = true
		case "--headless":
			a.headless = true
			a.gui = false
		case "--test":
			a.test = true
			a.gui = false
		case "--trade":
			v := eat(&i, args)
			a.trade = parse_bool(v, true)
		case "--no-trade":
			a.trade = false
		case "--seed":
			v := eat(&i, args)
			if n, ok := strconv.parse_u64(v); ok {
				a.seed = n
				a.seed_set = true
			}
		case "--days":
			v := eat(&i, args)
			if n, ok := strconv.parse_i64(v); ok {
				a.days = i32(n)
			}
		case "--households":
			v := eat(&i, args)
			if n, ok := strconv.parse_i64(v); ok {
				a.households = i32(n)
			}
		case "--csv":
			a.csv_path = eat(&i, args)
		case "--experiment":
			a.experiment = eat(&i, args)
			a.gui = false
		case "--berry-regen-bp":
			v := eat(&i, args)
			if n, ok := strconv.parse_i64(v); ok {
				a.berry_regen_bp = i32(n)
			}
		case:
			if strings.has_prefix(s, "--seed=") {
				if n, ok := strconv.parse_u64(s[7:]); ok {
					a.seed = n
					a.seed_set = true
				}
			} else if strings.has_prefix(s, "--days=") {
				if n, ok := strconv.parse_i64(s[7:]); ok {
					a.days = i32(n)
				}
			} else if strings.has_prefix(s, "--households=") {
				if n, ok := strconv.parse_i64(s[13:]); ok {
					a.households = i32(n)
				}
			} else if strings.has_prefix(s, "--csv=") {
				a.csv_path = s[6:]
			} else if strings.has_prefix(s, "--trade=") {
				a.trade = parse_bool(s[8:], true)
			} else if strings.has_prefix(s, "--experiment=") {
				a.experiment = s[13:]
				a.gui = false
			} else {
				fmt.eprintf("unknown argument: %s\n", s)
			}
		}
	}
	return a
}

parse_bool :: proc(v: string, default: bool) -> bool {
	switch v {
	case "1", "true", "True", "yes", "on", "ON":
		return true
	case "0", "false", "False", "no", "off", "OFF":
		return false
	}
	return default
}

print_help :: proc() {
	fmt.println(`Black Box Economy Simulator v0.01 — primitive barter society

Usage:
  blackbox.exe [options]
  blackbox.exe --headless --seed 12345 --days 5000
  blackbox.exe --test
  blackbox.exe --experiment trade
  blackbox.exe --experiment scarcity

Options:
  --headless              run without a window
  --seed N                world seed (default 12345)
  --days N                simulated days in headless mode (default 500)
  --households N          10–100 typical (default 40)
  --trade true|false      allow barter (default true)
  --no-trade              shorthand for --trade false
  --csv PATH              write daily metrics CSV
  --berry-regen-bp N      scale berry regeneration (10000 = 100%)
  --experiment trade      20 seeds × 720 days, trade on vs off
  --experiment scarcity   berry regen 100% vs 50%
  --test                  run built-in determinism / conservation tests
  --help                  this text

Without flags, the observer GUI starts.`)
}

main :: proc() {
	args := parse_args()
	if args.help {
		print_help()
		return
	}
	if args.test {
		ok := analysis.run_self_tests()
		if !ok {
			os.exit(1)
		}
		return
	}
	if args.experiment != "" {
		switch args.experiment {
		case "trade":
			analysis.run_trade_experiment()
		case "scarcity":
			analysis.run_scarcity_experiment()
		case:
			fmt.eprintf("unknown experiment '%s' (trade|scarcity)\n", args.experiment)
			os.exit(1)
		}
		return
	}
	if args.headless || !args.gui {
		if args.days <= 0 {
			args.days = 500
		}
		ok := analysis.run_headless(analysis.Headless_Opts{
			seed = args.seed,
			days = args.days,
			households = args.households,
			trade = args.trade,
			csv_path = args.csv_path,
			berry_regen_bp = args.berry_regen_bp,
		})
		if !ok {
			os.exit(1)
		}
		return
	}

	game.run(args.seed, args.households, args.trade)
}

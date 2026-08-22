package game

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:time"
import rl "vendor:raylib"
import sim "../sim"

Screen :: enum {
	Setup,
	Sim,
}

App :: struct {
	screen:     Screen,
	world:      ^sim.World,
	assets:     Assets,
	cam:        Cam,
	cam_ready:  bool,

	seed_buf:   [32]u8,
	seed_len:   int,
	seed_focus: bool,
	hh_count:   i32,
	trade:      bool,

	paused:     bool,
	speed:      f32,
	acc:        f32,
	day_anim:   f32,
	view_scale: f32,
	follow:     bool,

	overlay:    sim.Overlay_Kind,
	res_kind:   sim.Resource_Kind,

	selected_hh: i32,
	selected_person: i32,
	selected_cell: sim.Vec2i,
	has_cell:   bool,

	bottom_tab: i32,
	insp_scroll: f32,
	event_scroll: f32,
	event_filter: u8,
	people_scroll: f32,
	people_filter: u8,
	prod_on:    [5]bool,
	numeraire:  sim.Good,

	left_on:    bool,
	right_on:   bool,
	bottom_on:  bool,
}

run :: proc(seed: u64, households: i32, trade: bool) {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1600, 900, "Black Box Economy Simulator  v0.01")
	rl.SetWindowMinSize(1280, 720)
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	app: App
	app.screen = .Setup
	app.hh_count = clamp_i32(households, sim.HOUSEHOLDS_MIN, sim.HOUSEHOLDS_UI_MAX)
	app.trade = trade
	app.speed = 0.25
	app.paused = true
	app.selected_hh = -1
	app.selected_person = -1
	app.follow = false
	app.left_on = true
	app.right_on = true
	app.bottom_on = true
	app.prod_on = {true, true, true, true, true}
	app.numeraire = .Berries
	s := fmt.tprintf("%v", seed)
	app.seed_len = min(len(s), len(app.seed_buf) - 1)
	copy(app.seed_buf[:], s[:app.seed_len])

	load_ui_font()
	defer unload_ui_font()
	load_assets(&app.assets)
	defer unload_assets(&app.assets)

	for !rl.WindowShouldClose() {
		ui_consumed = false
		ui_tooltip = ""
		free_all(context.temp_allocator)

		rl.BeginDrawing()
		rl.ClearBackground(COL_BG)
		switch app.screen {
		case .Setup:
			update_setup(&app)
			draw_setup(&app)
		case .Sim:
			update_sim(&app)
			draw_sim(&app)
		}
		draw_tooltip()
		rl.EndDrawing()
	}
	if app.world != nil {
		sim.world_destroy(app.world)
	}
}

seed_value :: proc(app: ^App) -> u64 {
	s := string(app.seed_buf[:app.seed_len])
	if n, ok := strconv.parse_u64(strings.trim_space(s)); ok {
		return n
	}
	return 12345
}

start_world :: proc(app: ^App) {
	if app.world != nil {
		sim.world_destroy(app.world)
		app.world = nil
	}
	cfg := sim.default_config()
	cfg.household_count = clamp_i32(app.hh_count, sim.HOUSEHOLDS_MIN, sim.HOUSEHOLDS_UI_MAX)
	ok, err := sim.validate_config(cfg)
	if !ok {
		fmt.eprintf("config: %s\n", err)
		return
	}
	app.world = sim.world_create(seed_value(app), cfg, app.trade)
	app.screen = .Sim
	app.paused = true
	app.acc = 0
	app.day_anim = 0
	app.selected_hh = -1
	app.selected_person = -1
	app.follow = false
	app.has_cell = false
	app.cam_ready = false
	app.insp_scroll = 0
}

update_setup :: proc(app: ^App) {
	if rl.IsKeyPressed(.ENTER) {
		start_world(app)
	}
}

draw_setup :: proc(app: ^App) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	panel := rl.Rectangle{sw / 2 - 280, sh / 2 - 220, 560, 440}
	draw_panel(panel)
	draw_text("BLACK BOX ECONOMY", i32(panel.x) + 28, i32(panel.y) + 22, 28, COL_ACCENT)
	draw_text("v0.01  —  primitive barter laboratory", i32(panel.x) + 28, i32(panel.y) + 62, 16, COL_DIM)
	draw_text("You are an observer. Watch, click, investigate.", i32(panel.x) + 28, i32(panel.y) + 92, 16, COL_TEXT)

	y := panel.y + 130
	x := panel.x + 28
	draw_text("World seed", i32(x), i32(y), 14, COL_DIM)
	y += 20
	field := rl.Rectangle{x, y, 240, 28}
	if in_rec(field) && rl.IsMouseButtonPressed(.LEFT) {
		app.seed_focus = true
		ui_consumed = true
	} else if rl.IsMouseButtonPressed(.LEFT) && !in_rec(field) {
		app.seed_focus = false
	}
	rl.DrawRectangleRec(field, COL_PANEL2)
	rl.DrawRectangleLinesEx(field, 1, COL_ACCENT if app.seed_focus else COL_BORDER)
	draw_text(string(app.seed_buf[:app.seed_len]), i32(field.x) + 8, i32(field.y) + 6, 16, COL_TEXT)
	if app.seed_focus {
		ch := rl.GetCharPressed()
		for ch != 0 {
			if ch >= '0' && ch <= '9' && app.seed_len < 20 {
				app.seed_buf[app.seed_len] = u8(ch)
				app.seed_len += 1
			}
			ch = rl.GetCharPressed()
		}
		if rl.IsKeyPressed(.BACKSPACE) && app.seed_len > 0 {
			app.seed_len -= 1
		}
	}
	if button({x + 256, y, 140, 28}, "RANDOMIZE SEED") {
		n := u64(time.time_to_unix_nano(time.now()))
		s := fmt.tprintf("%v", n % 1_000_000_000_000)
		app.seed_len = min(len(s), 20)
		copy(app.seed_buf[:], s[:app.seed_len])
	}

	y += 50
	draw_text("Households", i32(x), i32(y), 14, COL_DIM)
	y += 20
	if button({x, y, 32, 28}, "-") {
		app.hh_count = clamp_i32(app.hh_count - 1, sim.HOUSEHOLDS_MIN, sim.HOUSEHOLDS_UI_MAX)
	}
	draw_text(fmt.tprintf("%d", app.hh_count), i32(x) + 48, i32(y) + 6, 18, COL_TEXT)
	if button({x + 100, y, 32, 28}, "+") {
		app.hh_count = clamp_i32(app.hh_count + 1, sim.HOUSEHOLDS_MIN, sim.HOUSEHOLDS_UI_MAX)
	}
	draw_text("10–100", i32(x) + 150, i32(y) + 8, 13, COL_DIM)

	y += 50
	draw_text("Experimental", i32(x), i32(y), 14, COL_DIM)
	y += 22
	if checkbox({x, y, 220, 22}, "Trade enabled", app.trade, "When off, households cannot exchange goods. No hidden productivity bonus.") {
		app.trade = !app.trade
	}

	y += 50
	if button({x, y, 220, 36}, "START SIMULATION", true) {
		start_world(app)
	}
}

layout :: proc(app: ^App) -> (top, left, mapr, right, bottom: rl.Rectangle) {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	top_h: f32 = 58
	bot_h: f32 = 250 if app.bottom_on else 32
	left_w: f32 = 180 if app.left_on else 28
	right_w: f32 = 380 if app.right_on else 28
	top = {0, 0, sw, top_h}
	bottom = {0, sh - bot_h, sw, bot_h}
	left = {0, top_h, left_w, sh - top_h - bot_h}
	right = {sw - right_w, top_h, right_w, sh - top_h - bot_h}
	mapr = {left_w, top_h, sw - left_w - right_w, sh - top_h - bot_h}
	return
}

update_sim :: proc(app: ^App) {
	if rl.IsKeyPressed(.SPACE) {
		app.paused = !app.paused
	}
	if rl.IsKeyPressed(.ZERO) do app.speed = 0.25
	if rl.IsKeyPressed(.ONE) do app.speed = 1
	if rl.IsKeyPressed(.TWO) do app.speed = 5
	if rl.IsKeyPressed(.THREE) do app.speed = 20
	if rl.IsKeyPressed(.FOUR) do app.speed = 100
	if rl.IsKeyPressed(.FIVE) do app.speed = 1000
	if rl.IsKeyPressed(.L) && app.selected_person >= 0 {
		app.follow = !app.follow
	}

	_, _, mapr, _, _ := layout(app)
	if !app.cam_ready && app.world != nil {
		cam_init(&app.cam, app.world.cfg.map_w, app.world.cfg.map_h, mapr)
		app.cam_ready = true
	}
	if app.world != nil {
		app.view_scale = sim.world_view_scale(app.world)
		pan_keys := rl.IsKeyDown(.W) || rl.IsKeyDown(.A) || rl.IsKeyDown(.S) || rl.IsKeyDown(.D) ||
			rl.IsKeyDown(.UP) || rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.RIGHT)
		cam_update(&app.cam, mapr, app.world.cfg.map_w, app.world.cfg.map_h)
		if app.follow && (pan_keys || app.cam.drag_moved) {
			app.follow = false
		}
		if app.follow {
			cam_follow_person(app, mapr)
		}
		handle_map_click(app, mapr)
	}

	if app.world != nil && !app.paused {
		app.day_anim += rl.GetFrameTime() * f32(app.speed)
		steps := 0
		for app.day_anim >= 1 && steps < 250 {
			sim.sim_day(app.world)
			app.day_anim -= 1
			steps += 1
		}
		app.acc = app.day_anim
		if steps > 0 {
			app.view_scale = sim.world_view_scale(app.world)
		}
	}
}

draw_sim :: proc(app: ^App) {
	top, left, mapr, right, bottom := layout(app)
	draw_topbar(app, top)
	draw_map(app, mapr)
	draw_left(app, left)
	if app.right_on {
		draw_inspector(app, right)
	} else {
		draw_panel(right)
		if button({right.x + 4, right.y + 8, 20, 20}, ">") {
			app.right_on = true
		}
	}
	if app.bottom_on {
		draw_bottom(app, bottom)
	} else {
		draw_panel(bottom)
		if button({bottom.x + 8, bottom.y + 4, 80, 20}, "ANALYTICS") {
			app.bottom_on = true
		}
	}
}

draw_topbar :: proc(app: ^App, r: rl.Rectangle) {
	rl.DrawRectangleRec(r, COL_PANEL)
	rl.DrawLineEx({r.x, r.y + r.height}, {r.x + r.width, r.y + r.height}, 1, COL_BORDER)
	x: f32 = 12
	draw_text("BLACK BOX", i32(x), i32(r.y) + 14, 20, COL_ACCENT)
	x += 140
	if app.world != nil {
		m := sim.latest_metrics(app.world)
		day := app.world.day
		year := day / app.world.cfg.days_per_year
		doy := day % app.world.cfg.days_per_year
		ty := i32(r.y) + 16
		draw_text(fmt.tprintf("Year %d  Day %d", year, doy), i32(x), ty, 16, COL_TEXT)
		x += 168
		clock_min := view_clock_minutes(app)
		draw_text(fmt_clock_min(clock_min), i32(x), ty, 16, COL_ACCENT)
		if in_rec({x, r.y, 52, r.height}) {
			ui_tooltip = "Time of day for the followed person (or the average). Playback spends more time on walking so travel is visible; night is compressed."
		}
		x += 64
		draw_text(fmt.tprintf("People %d", m.alive), i32(x), ty, 16, COL_TEXT)
		x += 108
		draw_text(fmt.tprintf("Single %s", fmt_bp(m.unmarried_bp)), i32(x), ty, 16, COL_TEXT)
		if in_rec({x, r.y, 100, r.height}) {
			ui_tooltip = fmt.tprintf(
				"Share of living people with no living spouse, including children. Among marriageable ages, %s are unmarried (%d people).",
				fmt_bp(m.unmarried_marriageable_bp), m.unmarried_marriageable,
			)
		}
		x += 108
		draw_text(fmt.tprintf("TFR %s", fmt_tfr(m.tfr_milli)), i32(x), ty, 16, COL_TEXT)
		if in_rec({x, r.y, 88, r.height}) {
			ui_tooltip = fmt.tprintf(
				"Total fertility rate: %s children per woman if the last %d days held for ages 16–42. Crude birth rate: %s per year. Replacement is about 2.1.",
				fmt_tfr(m.tfr_milli), m.birth_rate_days, fmt_cbr(m.cbr_milli),
			)
		}
		x += 92
		draw_text(fmt.tprintf("Camps %d", m.alive_households), i32(x), ty, 16, COL_TEXT)
		x += 100
		draw_text(fmt.tprintf("Food %s", fmt_days(m.food_days_avg_milli)), i32(x), ty, 16, COL_TEXT)
		if in_rec({x, r.y, 100, r.height}) {
			ui_tooltip = "Average food reserve in days of nutrition across living households."
		}
		x += 112
		draw_text(fmt.tprintf("Visits %d", m.visits), i32(x), ty, 16, COL_TEXT)
		if in_rec({x, r.y, 88, r.height}) {
			ui_tooltip = "Neighbor visits today. A visit is a chosen walk to another camp, not an automatic daily market."
		}
		x += 96
		draw_text(fmt.tprintf("Trade %s", fmt_bp(m.trade_success_bp)), i32(x), ty, 16, COL_TEXT)
		if in_rec({x, r.y, 100, r.height}) {
			ui_tooltip = "Share of today's neighbor visits that produced a mutually beneficial barter. People walk only when need and desire beat working at home."
		}
		x += 112
		draw_text(fmt.tprintf("Spec %s", fmt_bp(m.spec_avg_bp)), i32(x), ty, 16, COL_TEXT)
		if in_rec({x, r.y, 90, r.height}) {
			ui_tooltip = "Specialization: share of productive labor spent on this household's most common activity during the last 30 days. Average across households."
		}
		if app.follow && app.selected_person >= 0 {
			x += 96
			draw_text(fmt.tprintf("LOCK #%d", app.selected_person), i32(x), ty, 16, COL_ACCENT)
		}
	}

	bx := r.width - 12
	step :: proc(bx: ^f32, label: string, active: bool, tip: string) -> bool {
		w := f32(measure(label, 14) + 22)
		bx^ -= w + 6
		return button({bx^, 12, w, 34}, label, active, tip)
	}
	if step(&bx, "NEW", false, "Return to setup and pick a new seed.") {
		app.screen = .Setup
		app.paused = true
	}
	if step(&bx, "RESTART", false, "Rebuild this world from the same seed.") {
		if app.world != nil {
			app.hh_count = app.world.cfg.household_count
			app.trade = app.world.trade_enabled
			s := fmt.tprintf("%v", app.world.seed)
			app.seed_len = min(len(s), 20)
			copy(app.seed_buf[:], s[:app.seed_len])
			start_world(app)
		}
	}
	if step(&bx, "1000x", app.speed == 1000, "1000 simulated days per real second. Key 5.") do app.speed = 1000
	if step(&bx, "100x", app.speed == 100, "100 simulated days per real second. Key 4.") do app.speed = 100
	if step(&bx, "20x", app.speed == 20, "20 days / sec") do app.speed = 20
	if step(&bx, "5x", app.speed == 5, "5 days / sec") do app.speed = 5
	if step(&bx, "1x", app.speed == 1, "1 day / sec") do app.speed = 1
	if step(&bx, "0.25x", app.speed == 0.25, "One simulated day every 4 seconds. Key 0.") do app.speed = 0.25
	if step(&bx, "PAUSE" if app.paused else "RUN", app.paused, "SPACE also pauses") {
		app.paused = !app.paused
	}
}

draw_left :: proc(app: ^App, r: rl.Rectangle) {
	draw_panel(r, "" if app.left_on else "")
	if !app.left_on {
		if button({r.x + 4, r.y + 8, 20, 20}, ">") {
			app.left_on = true
		}
		return
	}
	if button({r.x + r.width - 24, r.y + 6, 18, 18}, "<") {
		app.left_on = false
		return
	}
	draw_text("OVERLAYS", i32(r.x) + 10, i32(r.y) + 10, 16, COL_ACCENT)
	y := r.y + 36
	x := r.x + 8
	bw := r.width - 16
	item :: proc(app: ^App, x, y, bw: f32, label: string, k: sim.Overlay_Kind, tip: string) -> f32 {
		if button({x, y, bw, 28}, label, app.overlay == k, tip) {
			app.overlay = k
		}
		return y + 32
	}
	y = item(app, x, y, bw, "NORMAL", .Normal, "Terrain and camps.")
	y = item(app, x, y, bw, "RESOURCES", .Resources, "Tint cells by remaining stock of the selected resource.")
	if app.overlay == .Resources {
		rk := [4]sim.Resource_Kind{.Berry, .Game, .Wood, .Stone}
		labs := [4]string{"Berries", "Game", "Wood", "Stone"}
		for i in 0 ..< 4 {
			if button({x + 8, y, bw - 8, 24}, labs[i], app.res_kind == rk[i]) {
				app.res_kind = rk[i]
			}
			y += 28
		}
		y += 6
	}
	y = item(app, x, y, bw, "TRADE", .Trade, "Recent successful barters as fading lines between homes.")
	y = item(app, x, y, bw, "SPECIALIZATION", .Specialization, "Color camps by inferred dominant activity. Label is analytics only.")
	y = item(app, x, y, bw, "FOOD SECURITY", .Food_Security, "Household food reserve in days. Shape plus color so it is not color-only.")
	y += 8
	draw_legend(app, {x, y, bw, 140})
	if button({x, r.y + r.height - 32, bw, 22}, "Hide analytics") {
		app.bottom_on = !app.bottom_on
	}
	if button({x, r.y + r.height - 58, bw, 22}, "Hide inspector") {
		app.right_on = !app.right_on
	}
}

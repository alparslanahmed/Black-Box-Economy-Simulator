package game

import "core:fmt"
import rl "vendor:raylib"
import sim "../sim"

draw_bottom :: proc(app: ^App, r: rl.Rectangle) {
	draw_panel(r)
	tabs := [7]string{"OVERVIEW", "PRODUCTION", "TRADE", "BARTER RATIOS", "SPECIALIZATION", "PEOPLE", "EVENTS"}
	tx := r.x + 8
	ty := r.y + 8
	for t, i in tabs {
		br := rl.Rectangle{tx, ty, f32(measure(t, 14) + 20), 28}
		if button(br, t, app.bottom_tab == i32(i)) {
			app.bottom_tab = i32(i)
		}
		tx += br.width + 8
	}
	body := rl.Rectangle{r.x + 8, r.y + 42, r.width - 16, r.height - 50}
	if app.world == nil {
		draw_text("Start a simulation.", i32(body.x), i32(body.y), 14, COL_DIM)
		return
	}
	switch app.bottom_tab {
	case 0:
		draw_overview(app, body)
	case 1:
		draw_production(app, body)
	case 2:
		draw_trade_tab(app, body)
	case 3:
		draw_barter_tab(app, body)
	case 4:
		draw_spec_tab(app, body)
	case 5:
		draw_people_tab(app, body)
	case 6:
		draw_events_tab(app, body)
	}
}

collect_f32 :: proc(w: ^sim.World, get: proc(m: sim.Day_Metrics) -> f32, dest: []f32) -> int {
	n := int(w.metrics.count)
	if n > len(dest) do n = len(dest)
	start := w.metrics.count - u32(n)
	for i in 0 ..< n {
		m := sim.metrics_at(&w.metrics, start + u32(i))
		dest[i] = get(m)
	}
	return n
}

plot :: proc(r: rl.Rectangle, values: []f32, n: int, col: rl.Color, title: string) {
	rl.DrawRectangleRec(r, {20, 18, 16, 255})
	rl.DrawRectangleLinesEx(r, 1, COL_BORDER)
	draw_text(title, i32(r.x) + 8, i32(r.y) + 6, 14, COL_DIM)
	if n < 2 do return
	minv, maxv := values[0], values[0]
	for i in 1 ..< n {
		if values[i] < minv do minv = values[i]
		if values[i] > maxv do maxv = values[i]
	}
	if maxv - minv < 0.0001 {
		maxv = minv + 1
	}
	pad_top: f32 = 26
	inner := rl.Rectangle{r.x + 4, r.y + pad_top, r.width - 8, r.height - pad_top - 4}
	for i in 1 ..< n {
		t0 := f32(i - 1) / f32(n - 1)
		t1 := f32(i) / f32(n - 1)
		y0 := 1 - (values[i - 1] - minv) / (maxv - minv)
		y1 := 1 - (values[i] - minv) / (maxv - minv)
		p0 := rl.Vector2{inner.x + t0 * inner.width, inner.y + y0 * inner.height}
		p1 := rl.Vector2{inner.x + t1 * inner.width, inner.y + y1 * inner.height}
		rl.DrawLineEx(p0, p1, 1.6, col)
	}
}

draw_overview :: proc(app: ^App, r: rl.Rectangle) {
	buf: [4096]f32
	n := collect_f32(app.world, proc(m: sim.Day_Metrics) -> f32 { return f32(m.alive) }, buf[:])
	w := (r.width - 16) / 3
	plot({r.x, r.y, w, r.height}, buf[:n], n, COL_ACCENT, "Living people")
	n = collect_f32(app.world, proc(m: sim.Day_Metrics) -> f32 { return f32(m.food_days_avg_milli) / 1000 }, buf[:])
	plot({r.x + w + 8, r.y, w, r.height}, buf[:n], n, COL_GOOD, "Avg food reserve (days)")
	n = collect_f32(app.world, proc(m: sim.Day_Metrics) -> f32 { return f32(m.median_health) }, buf[:])
	plot({r.x + 2 * w + 16, r.y, w, r.height}, buf[:n], n, {200, 120, 100, 255}, "Median health")
}

draw_production :: proc(app: ^App, r: rl.Rectangle) {
	labels := [5]string{"Berries", "Meat", "Wood", "Stone", "Spears"}
	cols := [5]rl.Color{{150, 70, 100, 255}, {170, 80, 70, 255}, {130, 100, 60, 255}, {140, 140, 145, 255}, {210, 170, 80, 255}}
	tx := r.x
	for i in 0 ..< 5 {
		br := rl.Rectangle{tx, r.y, 96, 26}
		if button(br, labels[i], app.prod_on[i]) {
			app.prod_on[i] = !app.prod_on[i]
		}
		tx += 104
	}
	plot_r := rl.Rectangle{r.x, r.y + 34, r.width, r.height - 34}
	rl.DrawRectangleRec(plot_r, {20, 18, 16, 255})
	rl.DrawRectangleLinesEx(plot_r, 1, COL_BORDER)
	buf: [4096]f32
	any_on := false
	for i in 0 ..< 5 {
		if app.prod_on[i] {
			any_on = true
			break
		}
	}
	if !any_on {
		draw_text("Toggle series above.", i32(plot_r.x) + 8, i32(plot_r.y) + 8, 13, COL_DIM)
		return
	}
	// overlay each enabled series with its own min/max — use global max among enabled
	n := int(app.world.metrics.count)
	if n > 4096 do n = 4096
	start := app.world.metrics.count - u32(n)
	maxv: f32 = 1
	for i in 0 ..< 5 {
		if !app.prod_on[i] do continue
		for k in 0 ..< n {
			m := sim.metrics_at(&app.world.metrics, start + u32(k))
			v := f32(m.produced[i]) / 1000
			if v > maxv do maxv = v
		}
	}
	inner := rl.Rectangle{plot_r.x + 4, plot_r.y + 4, plot_r.width - 8, plot_r.height - 8}
	for i in 0 ..< 5 {
		if !app.prod_on[i] do continue
		for k in 0 ..< n {
			m := sim.metrics_at(&app.world.metrics, start + u32(k))
			buf[k] = f32(m.produced[i]) / 1000
		}
		if n < 2 do continue
		for k in 1 ..< n {
			t0 := f32(k - 1) / f32(n - 1)
			t1 := f32(k) / f32(n - 1)
			y0 := 1 - buf[k - 1] / maxv
			y1 := 1 - buf[k] / maxv
			p0 := rl.Vector2{inner.x + t0 * inner.width, inner.y + y0 * inner.height}
			p1 := rl.Vector2{inner.x + t1 * inner.width, inner.y + y1 * inner.height}
			rl.DrawLineEx(p0, p1, 1.6, cols[i])
		}
	}
}

draw_trade_tab :: proc(app: ^App, r: rl.Rectangle) {
	buf: [4096]f32
	w := (r.width - 16) / 3
	n := collect_f32(app.world, proc(m: sim.Day_Metrics) -> f32 { return f32(m.trade_attempts) }, buf[:])
	plot({r.x, r.y, w, r.height - 36}, buf[:n], n, COL_DIM, "Attempts / day")
	n = collect_f32(app.world, proc(m: sim.Day_Metrics) -> f32 { return f32(m.successful_trades) }, buf[:])
	plot({r.x + w + 8, r.y, w, r.height - 36}, buf[:n], n, COL_GOOD, "Successful / day")
	n = collect_f32(app.world, proc(m: sim.Day_Metrics) -> f32 { return f32(m.trade_success_bp) / 100 }, buf[:])
	plot({r.x + 2 * w + 16, r.y, w, r.height - 36}, buf[:n], n, COL_ACCENT, "Success rate %")
	m := sim.latest_metrics(app.world)
	draw_text(
		fmt.tprintf(
			"Failed today — no double coincidence: %d    no mutual bundle: %d    insufficient inventory: %d",
			m.fail_no_dc, m.fail_no_gain, m.fail_inv,
		),
		i32(r.x), i32(r.y + r.height) - 26, 15, COL_DIM,
	)
}

draw_barter_tab :: proc(app: ^App, r: rl.Rectangle) {
	draw_text("Analytical numeraire (player-only, agents never see this):", i32(r.x), i32(r.y), 15, COL_DIM)
	if in_rec({r.x, r.y, 400, 16}) {
		ui_tooltip = "Observed Barter Ratio: median ratio from actual direct exchanges. Agents do not know this global statistic."
	}
	gx := r.x
	gy := r.y + 22
	for g in sim.Good {
		br := rl.Rectangle{gx, gy, 92, 26}
		if button(br, sim.good_def(g).display_name, app.numeraire == g) {
			app.numeraire = g
		}
		gx += 88
	}
	m := sim.latest_metrics(app.world)
	y := gy + 32
	draw_text("Recent direct medians vs berries (N/A if no direct trades):", i32(r.x), i32(y), 15, COL_DIM)
	y += 20
	show :: proc(x: f32, y: ^f32, name: string, berries_per: i64) {
		if berries_per < 0 {
			draw_text(fmt.tprintf("1 %s  ≈  N/A", name), i32(x), i32(y^), 15, COL_TEXT)
		} else {
			draw_text(fmt.tprintf("1 %s  ≈  %s berries", name, fmt_qty(berries_per)), i32(x), i32(y^), 15, COL_TEXT)
		}
		y^ += 20
	}
	show(r.x, &y, "meat", m.berries_per_unit[sim.Good.Meat])
	show(r.x, &y, "wood", m.berries_per_unit[sim.Good.Wood])
	show(r.x, &y, "stone", m.berries_per_unit[sim.Good.Stone])
	show(r.x, &y, "spear", m.berries_per_unit[sim.Good.Spear])
	if app.numeraire != .Berries {
		draw_text("Time series currently plotted in berry units only in v0.01.", i32(r.x), i32(y) + 8, 12, COL_DIM)
	}
	buf: [4096]f32
	n := collect_f32(app.world, proc(m: sim.Day_Metrics) -> f32 {
		v := m.berries_per_unit[sim.Good.Meat]
		if v < 0 do return 0
		return f32(v) / 1000
	}, buf[:])
	plot({r.x + 360, r.y + 50, r.width - 370, r.height - 60}, buf[:n], n, COL_ACCENT, "Meat ≈ berries (0 if N/A)")
}

draw_spec_tab :: proc(app: ^App, r: rl.Rectangle) {
	buf: [4096]f32
	n := collect_f32(app.world, proc(m: sim.Day_Metrics) -> f32 { return f32(m.spec_avg_bp) / 100 }, buf[:])
	plot({r.x, r.y, r.width * 0.45, r.height}, buf[:n], n, COL_ACCENT, "Average specialization %")
	m := sim.latest_metrics(app.world)
	x := r.x + r.width * 0.47
	y := r.y + 4
	draw_text("Inferred roles now", i32(x), i32(y), 14, COL_ACCENT)
	y += 20
	names := [6]string{"Generalists", "Foragers", "Hunters", "Wood gatherers", "Stone gatherers", "Toolmakers"}
	for i in 0 ..< 6 {
		draw_text(fmt.tprintf("%-18s %d", names[i], m.role_counts[i]), i32(x), i32(y), 15, COL_TEXT)
		y += 22
	}
	y += 8
	draw_text("Most specialized", i32(x), i32(y), 14, COL_ACCENT)
	y += 18
	ids: [5]i32
	k := sim.top_specialized(app.world, ids[:])
	for i in 0 ..< k {
		h := app.world.households[ids[i]]
		label := fmt.tprintf("#%d  %s  %s", h.id, sim.role_name(h.inferred_role), fmt_bp(h.specialization_bp))
		br := rl.Rectangle{x, y, 280, 26}
		if button(br, label, app.selected_hh == h.id) {
			app.selected_hh = h.id
			app.has_cell = false
		}
		y += 30
	}
}

Event_Filter :: enum u8 {
	All,
	Trade,
	Production,
	Scarcity,
	Health,
	People,
	Specialization,
}

draw_events_tab :: proc(app: ^App, r: rl.Rectangle) {
	filters := [7]string{"All", "Trade", "Production", "Scarcity", "Health", "People", "Specialization"}
	tx := r.x
	for f, i in filters {
		br := rl.Rectangle{tx, r.y, 108, 26}
		if button(br, f, app.event_filter == u8(i)) {
			app.event_filter = u8(i)
		}
		tx += 114
	}
	body := rl.Rectangle{r.x, r.y + 32, r.width, r.height - 32}
	if in_rec(body) {
		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			ui_consumed = true
			app.event_scroll -= wheel * 18
		}
	}
	if app.event_scroll < 0 do app.event_scroll = 0
	scissor(body)
	y := body.y - app.event_scroll
	n := app.world.events.count
	shown: i32 = 0
	for i: u32 = 0; i < n; i += 1 {
		logical := n - 1 - i
		e := sim.event_at(&app.world.events, logical)
		if !event_pass(app.event_filter, e.kind) do continue
		line := sim.format_life_event(app.world, e) if sim.event_is_people(e.kind) else sim.format_event(e)
		col := COL_ACCENT if e.kind == .Married else COL_TEXT
		if e.kind == .Person_Died || e.kind == .Household_Died {
			col = COL_CRIT
		}
		draw_text(line, i32(body.x), i32(y), 15, col)
		y += 22
		shown += 1
		if y > body.y + body.height + 40 do break
	}
	rl.EndScissorMode()
	if shown == 0 {
		draw_text("No events in this filter yet.", i32(body.x), i32(body.y) + 8, 13, COL_DIM)
	}
}

event_pass :: proc(filter: u8, k: sim.Event_Kind) -> bool {
	if filter == 0 do return true
	cat := sim.event_category(k)
	switch Event_Filter(filter) {
	case .All:
		return true
	case .Trade:
		return cat == "Trade"
	case .Production:
		return cat == "Production"
	case .Scarcity:
		return cat == "Scarcity"
	case .Health:
		return cat == "Health"
	case .People:
		return cat == "People"
	case .Specialization:
		return cat == "Specialization"
	}
	return true
}

people_event_pass :: proc(filter: u8, k: sim.Event_Kind) -> bool {
	if !sim.event_is_people(k) do return false
	switch filter {
	case 0:
		return true
	case 1:
		return k == .Married
	case 2:
		return k == .Person_Born
	case 3:
		return k == .Person_Died
	case 4:
		return k == .Household_Founded || k == .Household_Died
	}
	return true
}

abandoned_count :: proc(w: ^sim.World) -> i32 {
	n: i32
	for h in w.households {
		if h.exists && !h.alive {
			n += 1
		}
	}
	return n
}

select_life_event :: proc(app: ^App, e: sim.Event) {
	app.has_cell = false
	app.insp_scroll = 0
	switch e.kind {
	case .Married:
		app.selected_person = e.h1
		app.selected_hh = i32(e.qty_a)
		app.follow = true
	case .Person_Born:
		app.selected_person = e.h2
		app.selected_hh = e.h1
		app.follow = true
	case .Person_Died:
		app.selected_person = e.h2
		app.selected_hh = e.h1
		app.follow = false
	case .Household_Founded:
		app.selected_hh = e.h1
		app.selected_person = e.h2
		app.follow = false
	case .Household_Died:
		app.selected_hh = e.h1
		app.selected_person = -1
		app.follow = false
	case .Work_Completed, .Hunt_Succeeded, .Hunt_Failed, .Resource_Depleted, .Spear_Crafted, .Spear_Broke,
		.Trade_Completed, .Trade_Failed, .Food_Spoiled, .Hunger, .Specialization_Changed:
	}
}

draw_people_tab :: proc(app: ^App, r: rl.Rectangle) {
	w := app.world
	m := sim.latest_metrics(w)
	abandoned := abandoned_count(w)
	draw_text(
		fmt.tprintf(
			"Weddings %d    Births today %d    Deaths %d    Abandoned camps %d    People %d",
			w.total_marriages, m.births, w.total_deaths, abandoned, m.alive,
		),
		i32(r.x), i32(r.y), 15, COL_TEXT,
	)

	filters := [5]string{"All life", "Marriages", "Births", "Deaths", "Camps"}
	tx := r.x
	fy := r.y + 26
	for f, i in filters {
		br := rl.Rectangle{tx, fy, f32(measure(f, 14) + 22), 26}
		if button(br, f, app.people_filter == u8(i), "Marriages, births, deaths and new or abandoned camps.") {
			app.people_filter = u8(i)
		}
		tx += br.width + 8
	}

	list := rl.Rectangle{r.x, r.y + 58, r.width, r.height - 58}
	if in_rec(list) {
		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			ui_consumed = true
			app.people_scroll -= wheel * 18
		}
	}
	if app.people_scroll < 0 do app.people_scroll = 0
	scissor(list)
	y := list.y - app.people_scroll
	n := w.events.count
	shown: i32 = 0
	for i: u32 = 0; i < n; i += 1 {
		logical := n - 1 - i
		e := sim.event_at(&w.events, logical)
		if !people_event_pass(app.people_filter, e.kind) do continue
		line := sim.format_life_event(w, e)
		col := COL_TEXT
		switch e.kind {
		case .Married:
			col = COL_ACCENT
		case .Person_Born, .Household_Founded:
			col = COL_GOOD
		case .Person_Died, .Household_Died:
			col = COL_CRIT
		case .Work_Completed, .Hunt_Succeeded, .Hunt_Failed, .Resource_Depleted, .Spear_Crafted, .Spear_Broke,
			.Trade_Completed, .Trade_Failed, .Food_Spoiled, .Hunger, .Specialization_Changed:
		}
		row := rl.Rectangle{list.x, y - 2, list.width, 22}
		if in_rec(row) {
			ui_consumed = true
			rl.DrawRectangleRec(row, {48, 40, 32, 180})
			if rl.IsMouseButtonPressed(.LEFT) {
				select_life_event(app, e)
			}
		}
		draw_text(line, i32(list.x), i32(y), 15, col)
		y += 22
		shown += 1
		if y > list.y + list.height + 40 do break
	}
	rl.EndScissorMode()
	if shown == 0 {
		msg := "No marriages, births or deaths recorded yet."
		if app.people_filter == 1 {
			msg = "No marriages yet. Founding couples start already married; new weddings take years."
		}
		draw_text(msg, i32(list.x), i32(list.y) + 8, 14, COL_DIM)
	}
}

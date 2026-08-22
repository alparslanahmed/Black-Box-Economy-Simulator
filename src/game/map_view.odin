package game

import "core:fmt"
import rl "vendor:raylib"
import sim "../sim"

CELL_PX :: 32

Cam :: struct {
	x, y: f32,
	zoom: f32,
	drag: bool,
	drag_moved: bool,
	last: rl.Vector2,
}

cam_init :: proc(c: ^Cam, map_w, map_h: i32, view: rl.Rectangle) {
	c.zoom = 0.85
	world_w := f32(map_w) * CELL_PX
	world_h := f32(map_h) * CELL_PX
	c.x = world_w * 0.5 - view.width / (2 * c.zoom)
	c.y = world_h * 0.5 - view.height / (2 * c.zoom)
}

cam_update :: proc(c: ^Cam, view: rl.Rectangle, map_w, map_h: i32) {
	dt := rl.GetFrameTime()
	speed: f32 = 900 / c.zoom
	if rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT) {
		speed *= 2.2
	}
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) do c.y -= speed * dt
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) do c.y += speed * dt
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) do c.x -= speed * dt
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do c.x += speed * dt

	wheel := rl.GetMouseWheelMove()
	if wheel != 0 && in_rec(view) && !ui_consumed {
		old := c.zoom
		c.zoom = clamp_f32(c.zoom + wheel * 0.12, 0.28, 4.0)
		m := rl.GetMousePosition()
		wx := c.x + (m.x - view.x) / old
		wy := c.y + (m.y - view.y) / old
		c.x = wx - (m.x - view.x) / c.zoom
		c.y = wy - (m.y - view.y) / c.zoom
	}

	over := in_rec(view) && !ui_consumed
	want_pan := rl.IsMouseButtonDown(.MIDDLE) || rl.IsMouseButtonDown(.RIGHT) || rl.IsMouseButtonDown(.LEFT)
	if over && !c.drag && (rl.IsMouseButtonPressed(.MIDDLE) || rl.IsMouseButtonPressed(.RIGHT) || rl.IsMouseButtonPressed(.LEFT)) {
		c.drag = true
		c.drag_moved = false
		c.last = rl.GetMousePosition()
	}
	if c.drag && want_pan {
		m := rl.GetMousePosition()
		dx := m.x - c.last.x
		dy := m.y - c.last.y
		if dx * dx + dy * dy > 36 {
			c.drag_moved = true
		}
		// Left-click only pans after the cursor actually moves, so clicks still select.
		do_pan := c.drag_moved || rl.IsMouseButtonDown(.MIDDLE) || rl.IsMouseButtonDown(.RIGHT)
		if do_pan {
			c.x -= dx / c.zoom
			c.y -= dy / c.zoom
			ui_consumed = true
		}
		c.last = m
	}
	if !want_pan {
		c.drag = false
	}

	world_w := f32(map_w) * CELL_PX
	world_h := f32(map_h) * CELL_PX
	view_w := view.width / c.zoom
	view_h := view.height / c.zoom
	pad: f32 = 220
	min_x := -pad
	max_x := world_w - view_w + pad
	if max_x < min_x {
		min_x = world_w - view_w - pad
		max_x = pad
	}
	min_y := -pad
	max_y := world_h - view_h + pad
	if max_y < min_y {
		min_y = world_h - view_h - pad
		max_y = pad
	}
	c.x = clamp_f32(c.x, min_x, max_x)
	c.y = clamp_f32(c.y, min_y, max_y)
}

cam_follow_person :: proc(app: ^App, view: rl.Rectangle) {
	if app.world == nil || app.selected_person < 0 {
		app.follow = false
		return
	}
	p := sim.person_at(app.world, app.selected_person)
	if p == nil || !p.alive {
		app.follow = false
		return
	}
	mx, my := sim.person_view_pos_f32(p, person_anim_u(app))
	wx := mx / 1000.0 * CELL_PX
	wy := my / 1000.0 * CELL_PX
	app.cam.x = wx - view.width / (2 * app.cam.zoom)
	app.cam.y = wy - view.height / (2 * app.cam.zoom)
}

world_to_screen :: proc(c: Cam, view: rl.Rectangle, wx, wy: f32) -> rl.Vector2 {
	return {view.x + (wx - c.x) * c.zoom, view.y + (wy - c.y) * c.zoom}
}

screen_to_cell :: proc(c: Cam, view: rl.Rectangle, mx, my: f32) -> (sim.Vec2i, bool) {
	wx := c.x + (mx - view.x) / c.zoom
	wy := c.y + (my - view.y) / c.zoom
	cx := i32(wx / CELL_PX)
	cy := i32(wy / CELL_PX)
	if wx < 0 || wy < 0 {
		return {}, false
	}
	return {cx, cy}, true
}

cell_screen_rect :: proc(c: Cam, view: rl.Rectangle, x, y: i32) -> rl.Rectangle {
	p := world_to_screen(c, view, f32(x) * CELL_PX, f32(y) * CELL_PX)
	s := CELL_PX * c.zoom
	return {p.x, p.y, s, s}
}

draw_map :: proc(app: ^App, view: rl.Rectangle) {
	w := app.world
	if w == nil do return
	rl.DrawRectangleRec(view, COL_MAP_VOID)
	scissor(view)
	defer rl.EndScissorMode()

	cs := CELL_PX * app.cam.zoom
	x0 := i32(app.cam.x / CELL_PX) - 1
	y0 := i32(app.cam.y / CELL_PX) - 1
	x1 := i32((app.cam.x + view.width / app.cam.zoom) / CELL_PX) + 1
	y1 := i32((app.cam.y + view.height / app.cam.zoom) / CELL_PX) + 1
	x0 = max(x0, 0)
	y0 = max(y0, 0)
	x1 = min(x1, w.cfg.map_w - 1)
	y1 = min(y1, w.cfg.map_h - 1)

	for y := y0; y <= y1; y += 1 {
		for x := x0; x <= x1; x += 1 {
			r := cell_screen_rect(app.cam, view, x, y)
			c := sim.cell_at(w, x, y)
			col := MEADOW_COL
			switch c.terrain {
			case .Meadow: col = MEADOW_COL
			case .Forest: col = FOREST_COL
			case .Rocky:  col = ROCK_COL
			}
			if app.assets.terrain_ok[c.terrain] {
				draw_tex(app.assets.terrain[c.terrain], r, rl.WHITE)
			} else {
				rl.DrawRectangleRec(r, col)
			}

			if app.overlay == .Resources {
				st, mx: i64
				switch app.res_kind {
				case .Berry:
					st, mx = c.berry_stock, c.berry_max
				case .Game:
					st, mx = c.game_stock, c.game_max
				case .Wood:
					st, mx = c.wood_stock, c.wood_max
				case .Stone:
					st, mx = c.stone_stock, c.stone_max
				}
				t := f32(0)
				if mx > 0 do t = f32(st) / f32(mx)
				tint := rl.Color{u8(40 + t * 180), u8(50 + t * 90), u8(30), u8(70 + t * 90)}
				rl.DrawRectangleRec(r, tint)
			}
		}
	}

	if app.overlay == .Trade {
		draw_trade_lines(app, view)
	}

	for &h in w.households {
		if h.exists {
			draw_household_marker(app, view, &h)
		}
	}
	draw_people(app, view)

	if app.has_cell {
		r := cell_screen_rect(app.cam, view, app.selected_cell.x, app.selected_cell.y)
		rl.DrawRectangleLinesEx(r, 2, COL_ACCENT)
	}
	if app.selected_hh >= 0 && int(app.selected_hh) < len(w.households) {
		h := &w.households[app.selected_hh]
		r := cell_screen_rect(app.cam, view, h.home.x, h.home.y)
		rl.DrawRectangleLinesEx({r.x - 2, r.y - 2, r.width + 4, r.height + 4}, 2, COL_ACCENT)
		rl.DrawCircleLines(i32(r.x + r.width / 2), i32(r.y + r.height / 2), r.width * 0.7, COL_ACCENT)
	}
}

draw_household_marker :: proc(app: ^App, view: rl.Rectangle, h: ^sim.Household) {
	r := cell_screen_rect(app.cam, view, h.home.x, h.home.y)
	cx := r.x + r.width * 0.5
	cy := r.y + r.height * 0.5
	s := r.width * 0.9
	dest := rl.Rectangle{cx - s / 2, cy - s / 2, s, s}

	tint := rl.WHITE
	if !h.alive {
		tint = {80, 80, 80, 180}
	} else if app.overlay == .Specialization {
		tint = ROLE_COL[h.inferred_role]
	} else if app.overlay == .Food_Security {
		need := sim.household_daily_need(app.world, h)
		days := sim.food_days_milli(sim.nutrition_of(h.inv, app.world.cfg), need)
		pref := sim.food_days_milli(h.preferred_food_nutrition, need)
		if days < 1000 {
			tint = COL_CRIT
		} else if days < 2000 {
			tint = COL_WARN
		} else if days < pref {
			tint = COL_GOOD
		} else {
			tint = {150, 190, 210, 255}
		}
	}

	v := int(h.hut_variant) % 3
	if app.assets.hut_ok[v] {
		draw_tex(app.assets.huts[v], dest, tint)
	} else {
		rl.DrawCircleV({cx, cy}, s * 0.35, tint if h.alive else {70, 70, 70, 255})
		rl.DrawCircleLines(i32(cx), i32(cy), s * 0.35, COL_BORDER)
	}

	if h.alive {
		if app.overlay == .Food_Security {
			days := sim.food_days_milli(sim.nutrition_of(h.inv, app.world.cfg), sim.household_daily_need(app.world, h))
			shape_col := rl.BLACK
			if days < 1000 {
				rl.DrawCircleV({cx, cy - s * 0.45}, 4, COL_CRIT)
			} else if days < 2000 {
				rl.DrawTriangle({cx, cy - s * 0.55}, {cx - 5, cy - s * 0.4}, {cx + 5, cy - s * 0.4}, COL_WARN)
			} else {
				rl.DrawRectangleRec({cx - 4, cy - s * 0.52, 8, 8}, COL_GOOD)
			}
			_ = shape_col
		}
		nut_days := sim.food_days_milli(sim.nutrition_of(h.inv, app.world.cfg), sim.household_daily_need(app.world, h))
		if nut_days < 1000 {
			draw_text("!", i32(cx) - 4, i32(cy - s * 0.75), 16, COL_CRIT)
		}
		act := h.intent_activity
		if act != .Rest {
			ir := rl.Rectangle{cx + s * 0.15, cy - s * 0.55, s * 0.42, s * 0.42}
			ai := int(u8(act))
			if ai < sim.PRODUCTIVE_ACTIVITY_COUNT && app.assets.activity_ok[ai] {
				draw_tex(app.assets.activity[ai], ir, rl.WHITE)
			} else {
				rl.DrawCircleV({ir.x + ir.width / 2, ir.y + ir.height / 2}, ir.width * 0.35, COL_ACCENT)
			}
		}
	}
}

person_anim_u :: proc(app: ^App) -> f32 {
	u := app.day_anim
	if u < 0 do u = 0
	if u > 1 do u = 1
	if app.speed >= 20 do u = 0.55
	if app.paused && app.day_anim <= 0.001 {
		u = 0
	}
	return u
}

person_anim_t :: proc(app: ^App) -> i32 {
	return i32(person_anim_u(app) * 10000)
}

view_clock_minutes :: proc(app: ^App) -> i32 {
	if app.world == nil {
		return 0
	}
	day := app.world.cfg.day_minutes
	if day <= 0 do day = sim.DAY_MINUTES
	u := person_anim_u(app)
	rt: i32
	n: i32
	if app.selected_person >= 0 {
		p := sim.person_at(app.world, app.selected_person)
		if p != nil && p.alive {
			rt = sim.person_view_real_t_u(p, u)
			n = 1
		}
	}
	if n == 0 {
		for i: i32 = 0; i < app.world.person_count; i += 1 {
			p := &app.world.people[i]
			if !p.alive do continue
			if sim.life_stage(p) == .Infant do continue
			rt += sim.person_view_real_t_u(p, u)
			n += 1
		}
	}
	if n <= 0 {
		m := i32(u * f32(day))
		if m >= day do m = day - 1
		if m < 0 do m = 0
		return m
	}
	m := i32(i64(rt) * i64(day) / (i64(n) * 10000))
	if m >= day do m = day - 1
	if m < 0 do m = 0
	return m
}

person_screen_pos :: proc(app: ^App, view: rl.Rectangle, p: ^sim.Person) -> rl.Vector2 {
	mx, my := sim.person_view_pos_f32(p, person_anim_u(app))
	return world_to_screen(app.cam, view, mx / 1000.0 * CELL_PX, my / 1000.0 * CELL_PX)
}

token_radius :: proc(app: ^App, st: sim.Life_Stage) -> f32 {
	base := 7.5 * app.cam.zoom
	if base < 5 do base = 5
	switch st {
	case .Child:
		return base * 0.72
	case .Youth:
		return base * 0.86
	case .Elder:
		return base * 0.92
	case .Infant:
		return base * 0.5
	case .Adult:
		return base
	}
	return base
}

token_fill :: proc(p: ^sim.Person, st: sim.Life_Stage) -> rl.Color {
	if st == .Child {
		return {242, 196, 46, 255}
	}
	if st == .Youth {
		if p.sex == .Male do return {86, 168, 214, 255}
		return {232, 120, 150, 255}
	}
	if st == .Elder {
		if p.sex == .Male do return {186, 196, 210, 255}
		return {214, 186, 198, 255}
	}
	if p.sex == .Male {
		return {36, 122, 204, 255}
	}
	return {220, 56, 96, 255}
}

draw_person_token :: proc(sp: rl.Vector2, r: f32, p: ^sim.Person, selected: bool) {
	st := sim.life_stage(p)
	fill := token_fill(p, st)
	// Dark halo so the marker never melts into grass/rock.
	rl.DrawCircleV(sp, r + 3, {16, 14, 12, 230})
	rl.DrawCircleV(sp, r + 1.6, {252, 248, 236, 255})
	rl.DrawCircleV(sp, r, fill)
	if selected {
		rl.DrawCircleLines(i32(sp.x), i32(sp.y), r + 5, COL_ACCENT)
		rl.DrawCircleLines(i32(sp.x), i32(sp.y), r + 6, COL_ACCENT)
	}
	ink := rl.Color{16, 14, 12, 255}
	if p.sex == .Male {
		// Mars: short arrow out of the top-right.
		rl.DrawLineEx({sp.x + r * 0.18, sp.y - r * 0.18}, {sp.x + r * 0.72, sp.y - r * 0.72}, 2, ink)
		rl.DrawTriangle(
			{sp.x + r * 0.72, sp.y - r * 0.72},
			{sp.x + r * 0.28, sp.y - r * 0.72},
			{sp.x + r * 0.72, sp.y - r * 0.28},
			ink,
		)
	} else {
		// Venus: cross below.
		rl.DrawLineEx({sp.x, sp.y + r * 0.15}, {sp.x, sp.y + r * 0.78}, 2.2, ink)
		rl.DrawLineEx({sp.x - r * 0.28, sp.y + r * 0.42}, {sp.x + r * 0.28, sp.y + r * 0.42}, 2.2, ink)
	}
	if p.pregnant {
		rl.DrawCircleV({sp.x + r * 0.55, sp.y + r * 0.15}, r * 0.28, {252, 230, 140, 255})
		rl.DrawCircleLines(i32(sp.x + r * 0.55), i32(sp.y + r * 0.15), r * 0.28, ink)
	}
}

draw_people :: proc(app: ^App, view: rl.Rectangle) {
	w := app.world
	for i: i32 = 0; i < w.person_count; i += 1 {
		p := &w.people[i]
		if !p.alive do continue
		st := sim.life_stage(p)
		if st == .Infant {
			continue
		}
		sp := person_screen_pos(app, view, p)
		r := token_radius(app, st)
		draw_person_token(sp, r, p, app.selected_person == p.id)
	}
}

draw_trade_lines :: proc(app: ^App, view: rl.Rectangle) {
	w := app.world
	n := w.exchanges.count
	if n == 0 do return
	start: u32 = 0
	if n >= sim.EXCHANGE_CAP {
		start = w.exchanges.head
	}
	for i: u32 = 0; i < n; i += 1 {
		e := w.exchanges.items[(start + i) % sim.EXCHANGE_CAP]
		age := w.day - e.day
		if age < 0 || age > 8 do continue
		if int(e.h0) >= len(w.households) || int(e.h1) >= len(w.households) do continue
		a := w.households[e.h0]
		b := w.households[e.h1]
		pa := world_to_screen(app.cam, view, (f32(a.home.x) + 0.5) * CELL_PX, (f32(a.home.y) + 0.5) * CELL_PX)
		pb := world_to_screen(app.cam, view, (f32(b.home.x) + 0.5) * CELL_PX, (f32(b.home.y) + 0.5) * CELL_PX)
		thick := 1.2 + f32(e.q0 + e.q1) / 8000
		if thick > 5 do thick = 5
		alpha := u8(clamp_i32(220 - age * 24, 40, 220))
		rl.DrawLineEx(pa, pb, thick, {212, 160, 80, alpha})
	}
}

handle_map_click :: proc(app: ^App, view: rl.Rectangle) {
	if app.world == nil || !in_rec(view) do return
	if !rl.IsMouseButtonReleased(.LEFT) do return
	if app.cam.drag_moved do return
	m := rl.GetMousePosition()

	// People first — they sit on top of huts and cells.
	best_id: i32 = -1
	best_d: f32 = 18 * 18
	for i: i32 = 0; i < app.world.person_count; i += 1 {
		p := &app.world.people[i]
		if !p.alive do continue
		st := sim.life_stage(p)
		if st == .Infant do continue
		sp := person_screen_pos(app, view, p)
		dx := m.x - sp.x
		dy := m.y - sp.y
		d := dx * dx + dy * dy
		hit := token_radius(app, st) + 10
		if d <= hit * hit && d < best_d {
			best_d = d
			best_id = p.id
		}
	}
	if best_id >= 0 {
		p := sim.person_at(app.world, best_id)
		app.selected_person = best_id
		app.selected_hh = p.household
		app.has_cell = false
		app.insp_scroll = 0
		app.follow = true
		return
	}

	cell, ok := screen_to_cell(app.cam, view, m.x, m.y)
	if !ok || !sim.in_bounds(app.world, cell.x, cell.y) {
		app.selected_hh = -1
		app.selected_person = -1
		app.follow = false
		app.has_cell = false
		return
	}
	found := false
	for &h in app.world.households {
		if h.home.x == cell.x && h.home.y == cell.y {
			app.selected_hh = h.id
			app.selected_person = -1
			app.follow = false
			app.has_cell = false
			found = true
			break
		}
	}
	if !found {
		app.selected_hh = -1
		app.selected_person = -1
		app.follow = false
		app.selected_cell = cell
		app.has_cell = true
	}
}

draw_legend :: proc(app: ^App, r: rl.Rectangle) {
	y := r.y + 8
	x := r.x + 10
	switch app.overlay {
	case .Specialization:
		draw_text("Roles (inferred)", i32(x), i32(y), 14, COL_DIM)
		y += 22
		names := [6]string{"Generalist", "Forager", "Hunter", "Wood", "Stone", "Toolmaker"}
		for i in 0 ..< 6 {
			rl.DrawRectangleRec({x, y, 12, 12}, ROLE_COL[i])
			draw_text(names[i], i32(x) + 18, i32(y) - 2, 14, COL_TEXT)
			y += 20
		}
	case .Food_Security:
		draw_text("Food reserve", i32(x), i32(y), 14, COL_DIM)
		y += 22
		rl.DrawCircleV({x + 6, y + 6}, 6, COL_CRIT)
		draw_text("critical <1d  (circle)", i32(x) + 18, i32(y) - 2, 14, COL_TEXT)
		y += 20
		rl.DrawTriangle({x + 6, y}, {x, y + 12}, {x + 12, y + 12}, COL_WARN)
		draw_text("low 1-2d  (triangle)", i32(x) + 18, i32(y) - 2, 14, COL_TEXT)
		y += 20
		rl.DrawRectangleRec({x, y, 12, 12}, COL_GOOD)
		draw_text("stable  (square)", i32(x) + 18, i32(y) - 2, 14, COL_TEXT)
		y += 20
		rl.DrawRectangleRec({x, y, 12, 12}, {150, 190, 210, 255})
		draw_text("surplus  (square)", i32(x) + 18, i32(y) - 2, 14, COL_TEXT)
	case .Resources:
		draw_text("Abundance tint", i32(x), i32(y), 14, COL_DIM)
	case .Trade:
		draw_text("Lines: last 8 days", i32(x), i32(y), 14, COL_DIM)
		draw_text("of successful barter.", i32(x), i32(y) + 20, 14, COL_TEXT)
	case .Normal:
		draw_text("Drag map to pan", i32(x), i32(y), 14, COL_DIM)
		draw_text("WASD / arrows too", i32(x), i32(y) + 20, 14, COL_DIM)
		draw_text("Wheel zooms", i32(x), i32(y) + 40, 14, COL_DIM)
		draw_text("Click a person", i32(x), i32(y) + 60, 14, COL_DIM)
	}
	_ = fmt.tprintf
}

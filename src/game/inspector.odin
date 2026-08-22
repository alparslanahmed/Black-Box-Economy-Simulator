package game

import "core:fmt"
import rl "vendor:raylib"
import sim "../sim"

draw_inspector :: proc(app: ^App, r: rl.Rectangle) {
	draw_panel(r, "INSPECTOR")
	inner := rl.Rectangle{r.x + 10, r.y + 34, r.width - 20, r.height - 44}
	if in_rec(r) {
		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			ui_consumed = true
			app.insp_scroll -= wheel * 28
		}
	}
	if app.insp_scroll < 0 do app.insp_scroll = 0

	scissor(inner)
	y := inner.y - app.insp_scroll
	x := inner.x
	w := inner.width

	if app.selected_person >= 0 && app.world != nil {
		y = draw_person_inspector(app, app.selected_person, x, y, w)
		y += 12
		if app.selected_hh >= 0 && int(app.selected_hh) < len(app.world.households) {
			y = draw_household_inspector(app, app.selected_hh, x, y, w)
		}
	} else if app.selected_hh >= 0 && app.world != nil && int(app.selected_hh) < len(app.world.households) {
		y = draw_household_inspector(app, app.selected_hh, x, y, w)
	} else if app.has_cell && app.world != nil {
		y = draw_cell_inspector(app, app.selected_cell, x, y, w)
	} else {
		draw_text("Click a person, hut, or map cell.", i32(x), i32(y) + 8, 14, COL_DIM)
		draw_text("Drag with the mouse to pan. WASD also pans.", i32(x), i32(y) + 32, 14, COL_DIM)
		y += 60
	}
	rl.EndScissorMode()

	content_h := y - (inner.y - app.insp_scroll)
	max_scroll := max(f32(0), content_h - inner.height + 12)
	if app.insp_scroll > max_scroll do app.insp_scroll = max_scroll
}

draw_person_inspector :: proc(app: ^App, id: i32, x, y0, w: f32) -> f32 {
	p := sim.person_at(app.world, id)
	if p == nil {
		return y0
	}
	y := y0
	st := sim.life_stage(p)
	who := sim.sex_name(p.sex)
	draw_text(fmt.tprintf("Person #%d  %s", p.id, who), i32(x), i32(y), 18, COL_TEXT if p.alive else COL_CRIT)
	if button({x + w - 92, y, 90, 26}, "UNLOCK" if app.follow else "LOCK", app.follow, "Camera follows this person (L). Drag or WASD to release.") {
		app.follow = !app.follow
	}
	y += 30
	draw_text(fmt.tprintf("Household #%d", p.household), i32(x), i32(y), 15, COL_ACCENT)
	y += 22
	draw_text(fmt.tprintf("Stage: %s", sim.life_stage_name(st)), i32(x), i32(y), 15, COL_TEXT)
	y += 20
	draw_text(fmt.tprintf("Age: %d years  (%d days)", sim.age_years(p), p.age_days), i32(x), i32(y), 15, COL_TEXT)
	y += 22
	if sim.has_living_spouse(app.world, p) {
		sp := sim.person_at(app.world, p.spouse_id)
		draw_text(fmt.tprintf("Married to person #%d (%s, household %d)", sp.id, sim.sex_name(sp.sex), sp.household), i32(x), i32(y), 15, COL_ACCENT)
		y += 20
	} else if sim.is_marriageable(app.world, p) {
		draw_text("Unmarried — of marriageable age", i32(x), i32(y), 15, COL_DIM)
		y += 20
	} else {
		draw_text("Unmarried", i32(x), i32(y), 15, COL_DIM)
		y += 20
	}
	draw_text(fmt.tprintf("Born in household #%d", p.natal_household), i32(x), i32(y), 14, COL_DIM)
	y += 20
	if st == .Infant {
		draw_text("Inside the hut — does not walk the map.", i32(x), i32(y), 14, COL_DIM)
		y += 20
	}
	if p.pregnant {
		left := app.world.cfg.pregnancy_days - p.pregnancy_days
		if left < 0 do left = 0
		draw_text(fmt.tprintf("Pregnant  (%d days remaining)", left), i32(x), i32(y), 15, COL_WARN)
		y += 20
	}

	draw_text("Health", i32(x), i32(y), 14, COL_DIM)
	y += 18
	bar(x, y, w, 10, f32(p.health) / f32(sim.HEALTH_MAX), COL_GOOD if p.health > 5000 else COL_CRIT)
	draw_text(fmt.tprintf("%d", p.health), i32(x + w) - 48, i32(y) - 16, 14, COL_TEXT)
	y += 20
	draw_text(fmt.tprintf("Inherited constitution %d", p.constitution), i32(x), i32(y), 14, COL_DIM)
	if in_rec({x, y - 2, w, 18}) {
		ui_tooltip = "Baseline from parents plus chance. Pregnancy nutrition can shift birth health away from this."
	}
	y += 22

	doing, act_now, walking := sim.person_now(p, person_anim_u(app), app.view_scale)
	draw_text(fmt.tprintf("Now: %s", sim.person_now_label(doing, act_now, walking)), i32(x), i32(y), 15, COL_ACCENT)
	if in_rec({x, y, w, 18}) {
		ui_tooltip = "What this person is doing at the current time of day on the map."
	}
	y += 22
	draw_text(fmt.tprintf("Last bout: %s", sim.activity_name(p.intent_activity)), i32(x), i32(y), 15, COL_TEXT)
	y += 22
	if p.intent_activity != .Rest && p.intent_activity != .Visit {
		draw_text(fmt.tprintf("Target cell (%d, %d)", p.intent_cell.x, p.intent_cell.y), i32(x), i32(y), 14, COL_DIM)
		y += 20
	}
	if p.intent_activity == .Visit && p.intent_partner >= 0 {
		draw_text(fmt.tprintf("Visited household #%d", p.intent_partner), i32(x), i32(y), 14, COL_DIM)
		y += 20
	}

	draw_text("TODAY'S TIME", i32(x), i32(y), 16, COL_ACCENT)
	if in_rec({x, y, w, 20}) {
		ui_tooltip = "A 1440-minute day. Walking uses real distance at near-average human speed, so far camps take longer. Trade is a visit, not a daily automatic."
	}
	y += 22
	draw_text(fmt.tprintf("Sleep %s   Home %s", fmt_mins(p.minutes_sleep), fmt_mins(p.minutes_home)), i32(x), i32(y), 14, COL_TEXT)
	y += 20
	draw_text(fmt.tprintf("Walk %s   Work %s   Visit %s", fmt_mins(p.minutes_travel), fmt_mins(p.minutes_work), fmt_mins(p.minutes_visit)), i32(x), i32(y), 14, COL_TEXT)
	y += 22
	draw_text(fmt.tprintf("Bouts %d   Wake %s   Sleep at %s", p.blocks_this_day, fmt_clock_min(p.wake_min), fmt_clock_min(p.sleep_start)), i32(x), i32(y), 14, COL_DIM)
	y += 22

	d := p.last_decision
	draw_text("WHY THIS ACTION?", i32(x), i32(y), 16, COL_ACCENT)
	y += 22
	n := int(d.candidate_count)
	if n <= 0 {
		draw_text("No scored work this bout (child, infant, or resting).", i32(x), i32(y), 14, COL_DIM)
		y += 20
	} else {
		order: [sim.DECISION_CANDIDATES]int
		if n > sim.DECISION_CANDIDATES do n = sim.DECISION_CANDIDATES
		for i in 0 ..< n do order[i] = i
		for i in 0 ..< n {
			best := i
			for j := i + 1; j < n; j += 1 {
				if d.candidates[order[j]].total_score > d.candidates[order[best]].total_score {
					best = j
				}
			}
			order[i], order[best] = order[best], order[i]
		}
		for k in 0 ..< min(n, sim.DECISION_CANDIDATES) {
			c := d.candidates[order[k]]
			mark := "  "
			if c.activity == d.chosen do mark = "> "
			col := COL_TEXT if c.feasible else COL_DIM
			draw_text(fmt.tprintf("%s%s  %d", mark, sim.activity_name(c.activity), c.total_score), i32(x), i32(y), 14, col)
			y += 20
		}
		ch := d.candidates[d.chosen_index]
		y += 6
		draw_text("Score components", i32(x), i32(y), 14, COL_DIM)
		y += 20
		row :: proc(x: f32, y: ^f32, name: string, v: i64) {
			col := COL_GOOD if v >= 0 else COL_CRIT
			draw_text(fmt.tprintf("%s  %+d", name, v), i32(x), i32(y^), 14, col)
			y^ += 18
		}
		row(x, &y, "Food need", ch.food_need)
		row(x, &y, "Fuel need", ch.fuel_need)
		row(x, &y, "Tool", ch.tool)
		row(x, &y, "Inputs", ch.input)
		row(x, &y, "Local demand", ch.trade_demand)
		row(x, &y, "Skill", ch.skill)
		row(x, &y, "Travel", ch.travel)
		row(x, &y, "Risk", ch.risk)
	}

	draw_text("Personal skills", i32(x), i32(y), 16, COL_ACCENT)
	y += 22
	sk_names := [5]string{"Foraging", "Hunting", "Wood gathering", "Stone gathering", "Spear crafting"}
	for s in 0 ..< 5 {
		draw_text(sk_names[s], i32(x), i32(y), 14, COL_DIM)
		y += 18
		t := f32(p.skills[s]) / f32(sim.SKILL_AVERAGE) / 2
		bar(x, y, w, 8, t, COL_ACCENT)
		draw_text(fmt.tprintf("%.2fx", f64(p.skills[s]) / 10000.0), i32(x + w) - 52, i32(y) - 16, 14, COL_TEXT)
		y += 16
	}
	y += 8
	draw_text("Household below", i32(x), i32(y), 14, COL_DIM)
	y += 18
	return y
}

draw_household_inspector :: proc(app: ^App, id: i32, x, y0, w: f32) -> f32 {
	h := &app.world.households[id]
	y := y0
	title := fmt.tprintf("Household #%d  %s", h.id, "alive" if h.alive else "abandoned")
	draw_text(title, i32(x), i32(y), 18, COL_TEXT if h.alive else COL_CRIT)
	y += 28
	if !h.alive {
		draw_text("Last residents died. The hut still stands on this cell.", i32(x), i32(y), 14, COL_DIM)
		y += 20
		draw_text("Food left inside spoils. Wood, stone and tools remain.", i32(x), i32(y), 14, COL_DIM)
		y += 22
	}
	draw_text(fmt.tprintf("Role (inferred): %s", sim.role_name(h.inferred_role)), i32(x), i32(y), 16, COL_ACCENT)
	y += 22
	draw_text(fmt.tprintf("Location (%d, %d)", h.home.x, h.home.y), i32(x), i32(y), 15, COL_DIM)
	y += 22
	draw_text(fmt.tprintf("Specialization %s", fmt_bp(h.specialization_bp)), i32(x), i32(y), 15, COL_TEXT)
	if in_rec({x, y - 2, w, 20}) {
		ui_tooltip = "Share of productive labor spent on this household's most common activity during the last 30 days."
	}
	y += 24

	draw_text("People", i32(x), i32(y), 16, COL_ACCENT)
	y += 24
	for mi: i32 = 0; mi < h.member_count; mi += 1 {
		p := sim.person_at(app.world, h.members[mi])
		if p == nil do continue
		st := sim.life_stage(p)
		status := "dead"
		if p.alive {
			status = sim.life_stage_name(st)
			if p.pregnant {
				status = fmt.tprintf("pregnant %dd", p.pregnancy_days)
			}
		}
		who := sim.life_stage_name(st)
		if st == .Adult || st == .Elder {
			who = sim.sex_name(p.sex)
		}
		act := ""
		if p.alive && st != .Infant {
			d, a, wk := sim.person_now(p, person_anim_u(app), app.view_scale)
			act = fmt.tprintf("  %s", sim.person_now_label(d, a, wk))
		}
		if st == .Infant && p.alive {
			act = "  (in hut)"
		}
		if sim.has_living_spouse(app.world, p) {
			act = fmt.tprintf("%s  wed #%d", act, p.spouse_id)
		}
		col := COL_TEXT if p.alive else COL_CRIT
		if app.selected_person == p.id {
			col = COL_ACCENT
		}
		row := rl.Rectangle{x, y - 2, w, 18}
		if in_rec(row) {
			ui_consumed = true
			if rl.IsMouseButtonPressed(.LEFT) {
				app.selected_person = p.id
				app.selected_hh = h.id
				app.has_cell = false
				app.follow = true
			}
		}
		draw_text(
			fmt.tprintf("%s age %d  hp %d  %s%s", who, sim.age_years(p), p.health, status, act),
			i32(x), i32(y), 14, col,
		)
		y += 20
	}
	y += 8

	draw_text("Health (household avg)", i32(x), i32(y), 14, COL_DIM)
	y += 20
	bar(x, y, w, 10, f32(h.health) / f32(sim.HEALTH_MAX), COL_GOOD if h.health > 5000 else COL_CRIT)
	draw_text(fmt.tprintf("%d", h.health), i32(x + w) - 48, i32(y) - 18, 14, COL_TEXT)
	y += 22

	draw_text("Inventory", i32(x), i32(y), 16, COL_ACCENT)
	y += 24
	goods := [5]sim.Good{.Berries, .Meat, .Wood, .Stone, .Spear}
	for g in goods {
		draw_good_icon(&app.assets, g, {x, y, 22, 22})
		label := fmt.tprintf("%s  %s", sim.good_def(g).display_name, fmt_qty(h.inv.qty[g]))
		if g == .Spear && h.inv.qty[g] >= sim.QTY_SCALE {
			label = fmt.tprintf("%s  (durability %d/%d)", label, h.spear_durability, app.world.cfg.spear_durability_max)
		}
		draw_text(label, i32(x) + 30, i32(y) + 2, 15, COL_TEXT)
		y += 26
	}

	nut := sim.nutrition_of(h.inv, app.world.cfg)
	need := sim.household_daily_need(app.world, h)
	days := sim.food_days_milli(nut, need)
	pref := sim.food_days_milli(h.preferred_food_nutrition, need)
	y += 6
	draw_text("Survival", i32(x), i32(y), 16, COL_ACCENT)
	y += 24
	draw_text(fmt.tprintf("Food reserve: %s  (prefer %s)", fmt_days(days), fmt_days(pref)), i32(x), i32(y), 15, COL_TEXT)
	y += 22
	draw_text(fmt.tprintf("Daily fuel: %s wood", fmt_qty(app.world.cfg.fuel_per_day)), i32(x), i32(y), 15, COL_DIM)
	y += 26

	draw_text("Skills", i32(x), i32(y), 16, COL_ACCENT)
	y += 24
	sk_names := [5]string{"Foraging", "Hunting", "Wood gathering", "Stone gathering", "Spear crafting"}
	for s in 0 ..< 5 {
		draw_text(sk_names[s], i32(x), i32(y), 14, COL_DIM)
		y += 20
		t := f32(h.skills[s]) / f32(sim.SKILL_AVERAGE) / 2
		bar(x, y, w, 8, t, COL_ACCENT)
		draw_text(fmt.tprintf("%.2fx", f64(h.skills[s]) / 10000.0), i32(x + w) - 52, i32(y) - 18, 14, COL_TEXT)
		y += 16
	}

	y += 10
	draw_text("WHY THIS ACTION?", i32(x), i32(y), 16, COL_ACCENT)
	if in_rec({x, y, w, 20}) {
		ui_tooltip = "Candidate scores for the most recent work bout. Travel is real walk time. Visit is walking to a neighbor to barter — only if need and desire beat staying home to work. Components are not prices."
	}
	y += 24
	d := h.last_decision
	draw_text(fmt.tprintf("Chosen: %s", sim.activity_name(d.chosen)), i32(x), i32(y), 15, COL_TEXT)
	y += 24

	order: [sim.DECISION_CANDIDATES]int
	n := int(d.candidate_count)
	if n > sim.DECISION_CANDIDATES do n = sim.DECISION_CANDIDATES
	for i in 0 ..< n do order[i] = i
	for i in 0 ..< n {
		best := i
		for j := i + 1; j < n; j += 1 {
			if d.candidates[order[j]].total_score > d.candidates[order[best]].total_score {
				best = j
			}
		}
		order[i], order[best] = order[best], order[i]
	}
	for k in 0 ..< min(n, sim.DECISION_CANDIDATES) {
		c := d.candidates[order[k]]
		mark := "  "
		if c.activity == d.chosen do mark = "► "
		col := COL_TEXT if c.feasible else COL_DIM
		draw_text(fmt.tprintf("%s%s  %d", mark, sim.activity_name(c.activity), c.total_score), i32(x), i32(y), 15, col)
		y += 22
	}

	chosen := d.candidates[d.chosen_index]
	y += 8
	draw_text("Score components", i32(x), i32(y), 15, COL_DIM)
	y += 22
	comp :: proc(x: f32, y: ^f32, name: string, v: i64) {
		col := COL_GOOD if v >= 0 else COL_CRIT
		draw_text(fmt.tprintf("%-22s %+d", name, v), i32(x), i32(y^), 15, col)
		y^ += 22
	}
	yy := y
	comp(x, &yy, "Food need", chosen.food_need)
	comp(x, &yy, "Fuel need", chosen.fuel_need)
	comp(x, &yy, "Tool / spear", chosen.tool)
	comp(x, &yy, "Inputs", chosen.input)
	comp(x, &yy, "Local demand", chosen.trade_demand)
	comp(x, &yy, "Skill", chosen.skill)
	comp(x, &yy, "Travel", chosen.travel)
	comp(x, &yy, "Risk", chosen.risk)
	draw_text(fmt.tprintf("Expected output %s", fmt_qty(chosen.expected_output)), i32(x), i32(yy), 14, COL_DIM)
	yy += 22
	draw_text(fmt.tprintf("Target cell (%d, %d)", chosen.target_cell.x, chosen.target_cell.y), i32(x), i32(yy), 14, COL_DIM)
	y = yy + 26

	draw_text("Labor last 30 days", i32(x), i32(y), 16, COL_ACCENT)
	y += 24
	tot, sum := sim.labor_totals_30(h)
	names := [5]string{"Forage", "Hunt", "Wood", "Stone", "Craft"}
	if sum <= 0 {
		draw_text("No productive labor recorded yet.", i32(x), i32(y), 14, COL_DIM)
		y += 22
	} else {
		for s in 0 ..< 5 {
			bp := i32(i64(tot[s]) * 10000 / i64(sum))
			draw_text(fmt.tprintf("%s  %s", names[s], fmt_bp(bp)), i32(x), i32(y), 14, COL_TEXT)
			y += 20
			bar(x, y, w, 8, f32(bp) / 10000, ROLE_COL[s + 1 if s < 5 else 0])
			y += 16
		}
	}

	y += 10
	draw_text("Recent trades", i32(x), i32(y), 16, COL_ACCENT)
	y += 24
	if h.recent_trade_count == 0 {
		draw_text("None yet.", i32(x), i32(y), 14, COL_DIM)
		y += 22
	} else {
		ntr := int(h.recent_trade_count)
		for k := ntr - 1; k >= 0; k -= 1 {
			idx := (int(h.recent_trade_head) - ntr + k + sim.TRADE_MEMORY) % sim.TRADE_MEMORY
			tr := h.recent_trades[idx]
			if tr.success {
				draw_text(
					fmt.tprintf("Day %d  gave %s %s", tr.day, fmt_qty(tr.gave_qty), sim.good_name(tr.gave_good)),
					i32(x), i32(y), 14, COL_TEXT,
				)
				y += 20
				draw_text(
					fmt.tprintf("     got %s %s  from #%d", fmt_qty(tr.got_qty), sim.good_name(tr.got_good), tr.partner),
					i32(x), i32(y), 14, COL_DIM,
				)
				y += 22
			} else {
				draw_text(fmt.tprintf("Day %d  failed vs #%d", tr.day, tr.partner), i32(x), i32(y), 14, COL_DIM)
				y += 22
			}
		}
	}

	y += 10
	draw_text("LOCAL KNOWLEDGE", i32(x), i32(y), 16, COL_ACCENT)
	if in_rec({x, y, w, 20}) {
		ui_tooltip = "What this household has learned people tend to request. Not a global market price. Agents never see the observed median ratios."
	}
	y += 24
	draw_text("Observed demand memory", i32(x), i32(y), 14, COL_DIM)
	y += 22
	for g in sim.Good {
		draw_text(fmt.tprintf("%-8s  %d", sim.good_def(g).display_name, h.observed_demand[g]), i32(x), i32(y), 15, COL_TEXT)
		y += 22
	}
	return y + 12
}

draw_cell_inspector :: proc(app: ^App, cell: sim.Vec2i, x, y0, w: f32) -> f32 {
	c := sim.cell_at(app.world, cell.x, cell.y)
	y := y0
	draw_text(fmt.tprintf("Cell (%d, %d)", cell.x, cell.y), i32(x), i32(y), 18, COL_TEXT)
	y += 28
	draw_text(fmt.tprintf("Terrain: %s", sim.terrain_name(c.terrain)), i32(x), i32(y), 16, COL_ACCENT)
	y += 26
	row :: proc(x: f32, y: ^f32, name: string, st, mx, regen, ext: i64) {
		draw_text(name, i32(x), i32(y^), 16, COL_TEXT)
		y^ += 22
		draw_text(fmt.tprintf("%s / %s", fmt_qty(st), fmt_qty(mx)), i32(x), i32(y^), 15, COL_DIM)
		y^ += 20
		draw_text(fmt.tprintf("regen %s/day   extracted today %s", fmt_qty(regen), fmt_qty(ext)), i32(x), i32(y^), 14, COL_DIM)
		y^ += 22
		t: f32 = 0
		if mx > 0 do t = f32(st) / f32(mx)
		bar(x, y^, 200, 7, t, COL_GOOD)
		y^ += 16
	}
	row(x, &y, "Berries", c.berry_stock, c.berry_max, c.berry_regen, c.extracted[0])
	row(x, &y, "Game", c.game_stock, c.game_max, c.game_regen, c.extracted[1])
	row(x, &y, "Wood", c.wood_stock, c.wood_max, c.wood_regen, c.extracted[2])
	row(x, &y, "Stone (no regen)", c.stone_stock, c.stone_max, 0, c.extracted[3])
	near := sim.nearby_households(app.world, cell, 8)
	draw_text(fmt.tprintf("Households within 8 cells: %d", near), i32(x), i32(y), 15, COL_TEXT)
	y += 18
	return y
}

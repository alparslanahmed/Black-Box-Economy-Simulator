package sim

regen_resources :: proc(w: ^World) {
	scale := i64(w.berry_regen_scale_bp)
	for &c in w.cells {
		c.extracted = {}
		if c.berry_max > 0 {
			add := c.berry_regen * scale / 10000
			if add < 1 && c.berry_regen > 0 && scale > 0 {
				add = 1
			}
			c.berry_stock = min(c.berry_max, c.berry_stock + add)
		}
		if c.game_max > 0 {
			c.game_stock = min(c.game_max, c.game_stock + c.game_regen)
		}
		if c.wood_max > 0 {
			c.wood_stock = min(c.wood_max, c.wood_stock + c.wood_regen)
		}
	}
}

stock_of :: proc(c: ^Cell, r: Resource_Kind) -> i64 {
	switch r {
	case .Berry: return c.berry_stock
	case .Game:  return c.game_stock
	case .Wood:  return c.wood_stock
	case .Stone: return c.stone_stock
	}
	return 0
}

max_of :: proc(c: ^Cell, r: Resource_Kind) -> i64 {
	switch r {
	case .Berry: return c.berry_max
	case .Game:  return c.game_max
	case .Wood:  return c.wood_max
	case .Stone: return c.stone_max
	}
	return 0
}

extract_stock :: proc(w: ^World, cell: Vec2i, r: Resource_Kind, want: i64) -> i64 {
	if want <= 0 || !in_bounds(w, cell.x, cell.y) {
		return 0
	}
	c := cell_at_pos(w, cell)
	have := stock_of(c, r)
	got := min(have, want)
	if got <= 0 {
		return 0
	}
	switch r {
	case .Berry:
		c.berry_stock -= got
		c.extracted[0] += got
		if c.berry_stock == 0 {
			push_event(w, Event{kind = .Resource_Depleted, cell = cell, good_a = .Berries, qty_a = got})
		}
	case .Game:
		c.game_stock -= got
		c.extracted[1] += got
		if c.game_stock == 0 {
			push_event(w, Event{kind = .Resource_Depleted, cell = cell, good_a = .Meat, qty_a = got})
		}
	case .Wood:
		c.wood_stock -= got
		c.extracted[2] += got
		if c.wood_stock == 0 {
			push_event(w, Event{kind = .Resource_Depleted, cell = cell, good_a = .Wood, qty_a = got})
		}
	case .Stone:
		c.stone_stock -= got
		c.extracted[3] += got
		if c.stone_stock == 0 {
			push_event(w, Event{kind = .Resource_Depleted, cell = cell, good_a = .Stone, qty_a = got})
		}
	}
	return got
}

total_resource_stock :: proc(w: ^World) -> [4]i64 {
	s: [4]i64
	for &c in w.cells {
		s[0] += c.berry_stock
		s[1] += c.game_stock
		s[2] += c.wood_stock
		s[3] += c.stone_stock
	}
	return s
}

Find_Result :: struct {
	cell:      Vec2i,
	travel:    i32,
	stock:     i64,
	effective: i32,
	found:     bool,
}

find_best_resource_cell :: proc(w: ^World, h: ^Household, r: Resource_Kind, skill: i32, yield_per_min: i64, available: i32 = 0, actor: ^Person = nil) -> Find_Result {
	res: Find_Result
	best: i64 = -1
	home := h.home
	radius := w.cfg.search_radius
	x0 := max(i32(0), home.x - radius)
	x1 := min(w.cfg.map_w - 1, home.x + radius)
	y0 := max(i32(0), home.y - radius)
	y1 := min(w.cfg.map_h - 1, home.y + radius)
	radius_milli := radius * 1000
	budget := available
	if budget <= 0 {
		budget = w.cfg.block_minutes
	}
	max_work := w.cfg.block_minutes
	speed := person_walk_speed_bp(actor)

	for y := y0; y <= y1; y += 1 {
		for x := x0; x <= x1; x += 1 {
			milli := octile_milli(home.x, home.y, x, y)
			if milli > radius_milli {
				continue
			}
			one := walk_minutes(w.cfg, home.x, home.y, x, y, speed)
			travel := one * 2
			if travel >= budget {
				continue
			}
			eff := budget - travel
			if eff > max_work {
				eff = max_work
			}
			if eff <= 0 {
				continue
			}
			c := cell_at(w, x, y)
			st := stock_of(c, r)
			if st <= 0 {
				continue
			}
			raw := i64(eff) * yield_per_min * i64(skill) / i64(SKILL_AVERAGE)
			got := min(raw, st)
			score := got * 1000 / i64(1000 + travel)
			if score > best {
				best = score
				res = Find_Result{
					cell = {x, y},
					travel = travel,
					stock = st,
					effective = eff,
					found = true,
				}
			}
		}
	}
	return res
}

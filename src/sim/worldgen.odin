package sim

hash_u32 :: proc(x, y, seed: u32) -> u32 {
	h := seed
	h ~= x * 374761393
	h ~= y * 668265263
	h = (h ~ (h >> 13)) * 1274126177
	return h ~ (h >> 16)
}

// Integer value noise in 0..10000
value_noise :: proc(x, y: i32, seed: u32, freq: i32) -> i32 {
	if freq < 1 {
		return 5000
	}
	fx := x
	fy := y
	ix := fx / freq
	iy := fy / freq
	if fx < 0 {
		ix = (fx - freq + 1) / freq
	}
	if fy < 0 {
		iy = (fy - freq + 1) / freq
	}
	tx := fx - ix * freq
	ty := fy - iy * freq
	n00 := i32(hash_u32(u32(ix), u32(iy), seed) % 10001)
	n10 := i32(hash_u32(u32(ix + 1), u32(iy), seed) % 10001)
	n01 := i32(hash_u32(u32(ix), u32(iy + 1), seed) % 10001)
	n11 := i32(hash_u32(u32(ix + 1), u32(iy + 1), seed) % 10001)
	a := n00 + (n10 - n00) * tx / freq
	b := n01 + (n11 - n01) * tx / freq
	return a + (b - a) * ty / freq
}

fbm2 :: proc(x, y: i32, seed: u32) -> i32 {
	n := value_noise(x, y, seed, 16) * 50
	n += value_noise(x, y, seed ~ 0xA5A5, 8) * 30
	n += value_noise(x, y, seed ~ 0x3C3C, 4) * 15
	n += value_noise(x, y, seed ~ 0x1111, 2) * 5
	return n / 100
}

generate_terrain :: proc(w: ^World) {
	seed := u32(w.seed ~ (w.seed >> 32))
	meadow, forest, rocky: i32

	for y: i32 = 0; y < w.cfg.map_h; y += 1 {
		for x: i32 = 0; x < w.cfg.map_w; x += 1 {
			c := cell_at(w, x, y)
			forest_n := fbm2(x, y, seed)
			rock_n := fbm2(x + 40, y - 17, seed ~ 0x51F15)
			moist := fbm2(x - 9, y + 23, seed ~ 0xC0FFEE)

			t: Terrain
			if rock_n > 7200 && moist < 6200 {
				t = .Rocky
				rocky += 1
			} else if forest_n > 5400 {
				t = .Forest
				forest += 1
			} else {
				t = .Meadow
				meadow += 1
			}
			c.terrain = t
			fill_cell_resources(w, c, t, x, y)
		}
	}

	total := meadow + forest + rocky
	if total <= 0 {
		return
	}
	// If rocky is a tiny speckle, leave it. Proportions are advisory; clustered
	// noise is the source of truth.
}

fill_cell_resources :: proc(w: ^World, c: ^Cell, t: Terrain, x, y: i32) {
	rng := &w.rng
	vary :: proc(rng: ^RNG, base, spread_bp: i32) -> i64 {
		v := rng_range_i32(rng, 10000 - spread_bp, 10000 + spread_bp)
		return i64(base) * i64(v) / 10000
	}

	switch t {
	case .Meadow:
		c.berry_max = vary(rng, 7000, 2500)
		c.game_max = vary(rng, 3500, 2500)
		c.wood_max = vary(rng, 1800, 3000)
		c.stone_max = vary(rng, 400, 4000)
	case .Forest:
		c.berry_max = vary(rng, 4200, 2500)
		c.game_max = vary(rng, 9000, 2500)
		c.wood_max = vary(rng, 14000, 2500)
		c.stone_max = vary(rng, 300, 4000)
	case .Rocky:
		c.berry_max = vary(rng, 1200, 3000)
		c.game_max = vary(rng, 1400, 3000)
		c.wood_max = vary(rng, 500, 4000)
		c.stone_max = vary(rng, 14000, 2500)
	}

	c.berry_regen = c.berry_max * i64(w.cfg.berry_regen_bp) / 10000
	c.game_regen = c.game_max * i64(w.cfg.game_regen_bp) / 10000
	c.wood_regen = c.wood_max * i64(w.cfg.wood_regen_bp) / 10000
	if c.berry_regen < 1 && c.berry_max > 0 do c.berry_regen = 1
	if c.game_regen < 1 && c.game_max > 0 do c.game_regen = 1
	if c.wood_regen < 1 && c.wood_max > 0 do c.wood_regen = 1

	fill :: proc(rng: ^RNG, mx: i64) -> i64 {
		if mx <= 0 do return 0
		pct := rng_range_i32(rng, 6000, 10000)
		return mx * i64(pct) / 10000
	}
	c.berry_stock = fill(rng, c.berry_max)
	c.game_stock = fill(rng, c.game_max)
	c.wood_stock = fill(rng, c.wood_max)
	c.stone_stock = fill(rng, c.stone_max)
}

place_households :: proc(w: ^World) {
	n := w.cfg.household_count
	if n <= 0 {
		return
	}

	// Pick a handful of loose cluster centers biased toward different terrains.
	n_clusters := clamp_i32(3 + n / 25, 3, 6)
	centers := make([]Vec2i, n_clusters)
	defer delete(centers)

	best_forest, best_rock, best_meadow: Vec2i
	best_f, best_r, best_m: i64 = -1, -1, -1
	for y: i32 = 2; y < w.cfg.map_h - 2; y += 1 {
		for x: i32 = 2; x < w.cfg.map_w - 2; x += 1 {
			c := cell_at(w, x, y)
			switch c.terrain {
			case .Forest:
				score := c.wood_max + c.game_max
				if score > best_f {
					best_f = score
					best_forest = {x, y}
				}
			case .Rocky:
				if c.stone_max > best_r {
					best_r = c.stone_max
					best_rock = {x, y}
				}
			case .Meadow:
				if c.berry_max > best_m {
					best_m = c.berry_max
					best_meadow = {x, y}
				}
			}
		}
	}

	if n_clusters > 0 do centers[0] = best_meadow if best_m >= 0 else {w.cfg.map_w / 3, w.cfg.map_h / 2}
	if n_clusters > 1 do centers[1] = best_forest if best_f >= 0 else {w.cfg.map_w / 2, w.cfg.map_h / 3}
	if n_clusters > 2 do centers[2] = best_rock if best_r >= 0 else {2 * w.cfg.map_w / 3, 2 * w.cfg.map_h / 3}
	for i: i32 = 3; i < n_clusters; i += 1 {
		centers[i] = {
			rng_range_i32(&w.rng, 4, w.cfg.map_w - 5),
			rng_range_i32(&w.rng, 4, w.cfg.map_h - 5),
		}
	}

	occupied := make([]u8, len(w.cells))
	defer delete(occupied)

	for i: i32 = 0; i < n; i += 1 {
		center := centers[i % n_clusters]
		placed := false
		for attempt in 0 ..< 80 {
			jx := rng_range_i32(&w.rng, -7, 7)
			jy := rng_range_i32(&w.rng, -6, 6)
			x := clamp_i32(center.x + jx, 1, w.cfg.map_w - 2)
			y := clamp_i32(center.y + jy, 1, w.cfg.map_h - 2)
			idx := cell_index(w, x, y)
			if occupied[idx] != 0 {
				continue
			}
			occupied[idx] = 1
			init_household(w, i, x, y)
			placed = true
			break
		}
		if !placed {
			// fallback: first free cell
			for y: i32 = 0; y < w.cfg.map_h && !placed; y += 1 {
				for x: i32 = 0; x < w.cfg.map_w && !placed; x += 1 {
					idx := cell_index(w, x, y)
					if occupied[idx] == 0 {
						occupied[idx] = 1
						init_household(w, i, x, y)
						placed = true
					}
				}
			}
		}
	}
}

init_household :: proc(w: ^World, idx, x, y: i32) {
	h := &w.households[idx]
	h.id = idx
	h.exists = true
	h.alive = true
	h.home = {x, y}
	h.hut_variant = u8(rng_range_i32(&w.rng, 0, 2))
	h.health = rng_range_i32(&w.rng, 9000, HEALTH_MAX)
	h.spear_durability = 0
	h.craft_progress = 0
	h.inferred_role = .Generalist
	h.prev_inferred_role = .Generalist
	h.member_count = 0

	pref_days := rng_range_i32(&w.rng, w.cfg.preferred_food_days_min, w.cfg.preferred_food_days_max)
	h.pref_days_milli = pref_days
	h.trade_openness = rng_range_i32(&w.rng, 5500, 10000)
	h.risk_preference = rng_range_i32(&w.rng, 3500, 8000)

	man_years := rng_range_i32(&w.rng, 20, 40)
	delta := rng_range_i32(&w.rng, -6, 6)
	woman_years := clamp_i32(man_years + delta, 20, 40)
	man_con := rng_range_i32(&w.rng, 8500, HEALTH_MAX)
	woman_con := rng_range_i32(&w.rng, 8500, HEALTH_MAX)
	man_h := clamp_i32(man_con + rng_range_i32(&w.rng, -400, 400), 8000, HEALTH_MAX)
	woman_h := clamp_i32(woman_con + rng_range_i32(&w.rng, -400, 400), 8000, HEALTH_MAX)
	mid := spawn_person(w, h, .Male, man_years * DAYS_PER_YEAR, man_h, man_con)
	wid := spawn_person(w, h, .Female, woman_years * DAYS_PER_YEAR, woman_h, woman_con)
	if mid >= 0 && wid >= 0 {
		link_spouses(person_at(w, mid), person_at(w, wid))
	}
	sync_household_from_members(w, h)

	food_days := rng_range_i32(&w.rng, w.cfg.start_food_days_min, w.cfg.start_food_days_max)
	total_nut := household_daily_need(w, h) * i64(food_days) / 1000
	meat_share := rng_range_i32(&w.rng, 2000, 6000)
	meat_nut := total_nut * i64(meat_share) / 10000
	berry_nut := total_nut - meat_nut
	h.inv.qty[Good.Berries] = berry_nut * QTY_SCALE / w.cfg.berry_nutrition
	h.inv.qty[Good.Meat] = meat_nut * QTY_SCALE / w.cfg.meat_nutrition
	h.inv.qty[Good.Wood] = rng_range_i64(&w.rng, w.cfg.start_wood_min, w.cfg.start_wood_max)
	if rng_chance_bp(&w.rng, 4500) {
		h.inv.qty[Good.Stone] = rng_range_i64(&w.rng, 0, QTY_SCALE)
	} else {
		h.inv.qty[Good.Stone] = 0
	}
	if rng_chance_bp(&w.rng, w.cfg.start_spear_chance_bp) {
		h.inv.qty[Good.Spear] = QTY_SCALE
		h.spear_durability = rng_range_i32(&w.rng, 40, w.cfg.spear_durability_max)
	}

	h.last_food_nutrition = nutrition_of(h.inv, w.cfg)
}

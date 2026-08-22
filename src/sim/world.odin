package sim

world_create :: proc(seed: u64, cfg: Config, trade_enabled: bool, berry_regen_scale_bp: i32 = BP_SCALE) -> ^World {
	ok, err := validate_config(cfg)
	if !ok {
		panic(err)
	}

	w := new(World)
	w.seed = seed
	w.cfg = cfg
	w.trade_enabled = trade_enabled
	w.berry_regen_scale_bp = berry_regen_scale_bp if berry_regen_scale_bp > 0 else BP_SCALE
	w.day = 0
	rng_seed(&w.rng, seed)

	n_cells := int(cfg.map_w * cfg.map_h)
	w.cells = make([]Cell, n_cells)
	hh_cap := int(cfg.household_count) * 4
	if hh_cap < 64 do hh_cap = 64
	if hh_cap > 400 do hh_cap = 400
	w.households = make([]Household, hh_cap)
	people_cap := hh_cap * int(MAX_MEMBERS)
	if people_cap < 16 do people_cap = 16
	w.people = make([]Person, people_cap)
	w.person_count = 0
	w.order = make([]i32, hh_cap)
	w.person_order = make([]i32, people_cap)
	for i in 0 ..< int(cfg.household_count) {
		w.order[i] = i32(i)
	}

	generate_terrain(w)
	place_households(w)
	return w
}

world_destroy :: proc(w: ^World) {
	if w == nil {
		return
	}
	delete(w.cells)
	delete(w.households)
	delete(w.people)
	delete(w.order)
	delete(w.person_order)
	free(w)
}

in_bounds :: proc(w: ^World, x, y: i32) -> bool {
	return x >= 0 && y >= 0 && x < w.cfg.map_w && y < w.cfg.map_h
}

cell_index :: proc(w: ^World, x, y: i32) -> int {
	return int(y * w.cfg.map_w + x)
}

cell_at :: proc(w: ^World, x, y: i32) -> ^Cell {
	return &w.cells[cell_index(w, x, y)]
}

cell_at_pos :: proc(w: ^World, p: Vec2i) -> ^Cell {
	return cell_at(w, p.x, p.y)
}

alive_count :: proc(w: ^World) -> i32 {
	n: i32
	for i: i32 = 0; i < w.person_count; i += 1 {
		if w.people[i].alive {
			n += 1
		}
	}
	return n
}

alive_households :: proc(w: ^World) -> i32 {
	n: i32
	for h in w.households {
		if h.exists && h.alive {
			n += 1
		}
	}
	return n
}

state_hash :: proc(w: ^World) -> u64 {
	h: u64 = 14695981039346656037
	mix :: proc(h: u64, x: u64) -> u64 {
		return (h ~ x) * 1099511628211
	}
	h = mix(h, w.seed)
	h = mix(h, u64(w.day))
	h = mix(h, w.rng.state)
	h = mix(h, u64(w.trade_enabled))
	h = mix(h, u64(i32(w.berry_regen_scale_bp)))
	h = mix(h, u64(len(w.households)))
	h = mix(h, u64(w.cfg.map_w))
	h = mix(h, u64(w.cfg.map_h))

	for hh in w.households {
		h = mix(h, u64(u8(hh.exists)))
		h = mix(h, u64(u8(hh.alive)))
		h = mix(h, u64(hh.id))
		h = mix(h, u64(hh.health))
		h = mix(h, u64(i32(hh.home.x) + 1000 * hh.home.y))
		h = mix(h, u64(hh.spear_durability))
		h = mix(h, u64(hh.craft_progress))
		for g in Good {
			h = mix(h, u64(hh.inv.qty[g]))
		}
		for s in 0 ..< SKILL_COUNT {
			h = mix(h, u64(hh.skills[s]))
		}
		for d in 0 ..< GOOD_COUNT {
			h = mix(h, u64(hh.observed_demand[d]))
		}
		h = mix(h, u64(hh.member_count))
	}
	h = mix(h, u64(w.person_count))
	for i: i32 = 0; i < w.person_count; i += 1 {
		p := w.people[i]
		h = mix(h, u64(u8(p.alive)))
		h = mix(h, u64(p.id))
		h = mix(h, u64(u8(p.sex)))
		h = mix(h, u64(p.age_days))
		h = mix(h, u64(p.health))
		h = mix(h, u64(p.constitution))
		h = mix(h, u64(u8(p.pregnant)))
		h = mix(h, u64(p.pregnancy_days))
		h = mix(h, u64(p.spouse_id))
		h = mix(h, u64(p.natal_household))
		h = mix(h, u64(p.mother_id))
		h = mix(h, u64(p.father_id))
		for s in 0 ..< SKILL_COUNT {
			h = mix(h, u64(p.skills[s]))
		}
	}

	for c in w.cells {
		h = mix(h, u64(u8(c.terrain)))
		h = mix(h, u64(c.berry_stock))
		h = mix(h, u64(c.game_stock))
		h = mix(h, u64(c.wood_stock))
		h = mix(h, u64(c.stone_stock))
	}

	h = mix(h, u64(w.acc.successful_trades))
	h = mix(h, u64(w.acc.trade_attempts))
	h = mix(h, u64(w.exchanges.count))
	h = mix(h, u64(w.total_deaths))
	return h
}

assert_invariants :: proc(w: ^World) {
	for &h in w.households {
		if !h.exists {
			continue
		}
		for g in Good {
			if h.inv.qty[g] < 0 {
				panic("negative inventory")
			}
		}
		if h.health < 0 || h.health > HEALTH_MAX {
			panic("health out of range")
		}
		if h.spear_durability < 0 || h.spear_durability > w.cfg.spear_durability_max {
			panic("spear durability out of range")
		}
		if h.spear_durability > 0 && h.inv.qty[Good.Spear] < QTY_SCALE && h.alive {
			// durability without a spear is illegal except mid-break handling
			if h.inv.qty[Good.Spear] == 0 && h.spear_durability != 0 {
				panic("durability without spear")
			}
		}
		if !h.alive {
			// dead households may keep leftover inventory; they must not act
		}
	}
	for i: i32 = 0; i < w.person_count; i += 1 {
		p := &w.people[i]
		if p.health < 0 || p.health > HEALTH_MAX {
			panic("person health out of range")
		}
		if p.alive && (p.household < 0 || int(p.household) >= len(w.households)) {
			panic("person household id")
		}
	}
	for &c in w.cells {
		if c.berry_stock < 0 || c.game_stock < 0 || c.wood_stock < 0 || c.stone_stock < 0 {
			panic("negative resource stock")
		}
		if c.berry_stock > c.berry_max + 1 ||
		   c.game_stock > c.game_max + 1 ||
		   c.wood_stock > c.wood_max + 1 ||
		   c.stone_stock > c.stone_max + 1 {
			panic("resource stock exceeds capacity")
		}
	}
}

world_reset_same_seed :: proc(w: ^World) -> ^World {
	seed := w.seed
	cfg := w.cfg
	trade := w.trade_enabled
	scale := w.berry_regen_scale_bp
	world_destroy(w)
	return world_create(seed, cfg, trade, scale)
}

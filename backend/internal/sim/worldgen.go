package sim

func HashU32(X u32, Y u32, Seed u32) u32 {
	h := Seed
	h ^= X * 374761393
	h ^= Y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return h ^ (h >> 16)
}

// Integer value noise in 0..10000
func ValueNoise(X i32, Y i32, Seed u32, freq i32) i32 {
	if freq < 1 {
		return 5000
	}
	fx := X
	fy := Y
	ix := fx / freq
	iy := fy / freq
	if fx < 0 {
		ix = (fx - freq + 1) / freq
	}
	if fy < 0 {
		iy = (fy - freq + 1) / freq
	}
	tx := fx - ix*freq
	ty := fy - iy*freq
	n00 := i32(HashU32(u32(ix), u32(iy), Seed) % 10001)
	n10 := i32(HashU32(u32(ix+1), u32(iy), Seed) % 10001)
	n01 := i32(HashU32(u32(ix), u32(iy+1), Seed) % 10001)
	n11 := i32(HashU32(u32(ix+1), u32(iy+1), Seed) % 10001)
	a := n00 + (n10-n00)*tx/freq
	b := n01 + (n11-n01)*tx/freq
	return a + (b-a)*ty/freq
}

func Fbm2(X i32, Y i32, Seed u32) i32 {
	N := ValueNoise(X, Y, Seed, 16) * 50
	N += ValueNoise(X, Y, Seed^0xA5A5, 8) * 30
	N += ValueNoise(X, Y, Seed^0x3C3C, 4) * 15
	N += ValueNoise(X, Y, Seed^0x1111, 2) * 5
	return N / 100
}

func GenerateTerrain(w *World) {
	Seed := u32(w.Seed ^ (w.Seed >> 32))
	var meadow, forest, rocky i32

	for Y := i32(0); Y < w.Cfg.MapH; Y += 1 {
		for X := i32(0); X < w.Cfg.MapW; X += 1 {
			c := CellAt(w, X, Y)
			forest_n := Fbm2(X, Y, Seed)
			rock_n := Fbm2(X+40, Y-17, Seed^0x51F15)
			moist := Fbm2(X-9, Y+23, Seed^0xC0FFEE)

			var T Terrain
			if rock_n > 7200 && moist < 6200 {
				T = Rocky
				rocky += 1
			} else if forest_n > 5400 {
				T = Forest
				forest += 1
			} else {
				T = Meadow
				meadow += 1
			}
			c.Terrain = T
			FillCellResources(w, c, T, X, Y)
		}
	}

	total := meadow + forest + rocky
	if total <= 0 {
		return
	}
	// If rocky is a tiny speckle, leave it. Proportions are advisory; clustered
	// noise is the source of truth.
}

func FillCellResources(w *World, c *Cell, T Terrain, X i32, Y i32) {
	Rng := &w.Rng
	Vary := func(Rng *RNG, base i32, spread_bp i32) i64 {
		V := RngRangeI32(Rng, 10000-spread_bp, 10000+spread_bp)
		return i64(base) * i64(V) / 10000
	}

	switch T {
	case Meadow:
		c.BerryMax = Vary(Rng, 7000, 2500)
		c.GameMax = Vary(Rng, 3500, 2500)
		c.WoodMax = Vary(Rng, 1800, 3000)
		c.StoneMax = Vary(Rng, 400, 4000)
	case Forest:
		c.BerryMax = Vary(Rng, 4200, 2500)
		c.GameMax = Vary(Rng, 9000, 2500)
		c.WoodMax = Vary(Rng, 14000, 2500)
		c.StoneMax = Vary(Rng, 300, 4000)
	case Rocky:
		c.BerryMax = Vary(Rng, 1200, 3000)
		c.GameMax = Vary(Rng, 1400, 3000)
		c.WoodMax = Vary(Rng, 500, 4000)
		c.StoneMax = Vary(Rng, 14000, 2500)
	}

	c.BerryRegen = c.BerryMax * i64(w.Cfg.BerryRegenBp) / 10000
	c.GameRegen = c.GameMax * i64(w.Cfg.GameRegenBp) / 10000
	c.WoodRegen = c.WoodMax * i64(w.Cfg.WoodRegenBp) / 10000
	if c.BerryRegen < 1 && c.BerryMax > 0 && w.Cfg.BerryRegenBp > 0 {
		c.BerryRegen = 1
	}
	if c.GameRegen < 1 && c.GameMax > 0 && w.Cfg.GameRegenBp > 0 {
		c.GameRegen = 1
	}
	if c.WoodRegen < 1 && c.WoodMax > 0 && w.Cfg.WoodRegenBp > 0 {
		c.WoodRegen = 1
	}

	Fill := func(Rng *RNG, mx i64) i64 {
		if mx <= 0 {
			return 0
		}
		pct := RngRangeI32(Rng, 6000, 10000)
		return mx * i64(pct) / 10000
	}
	c.BerryStock = Fill(Rng, c.BerryMax)
	c.GameStock = Fill(Rng, c.GameMax)
	c.WoodStock = Fill(Rng, c.WoodMax)
	c.StoneStock = Fill(Rng, c.StoneMax)
}

func PlaceHouseholds(w *World) {
	N := w.Cfg.HouseholdCount
	if N <= 0 {
		return
	}

	// Pick a handful of loose cluster centers biased toward different terrains.
	n_clusters := ClampI32(3+N/25, 3, 6)
	centers := make([]Vec2i, n_clusters)

	var best_forest, best_rock, best_meadow Vec2i
	var best_f, best_r, best_m i64 = -1, -1, -1
	for Y := i32(2); Y < w.Cfg.MapH-2; Y += 1 {
		for X := i32(2); X < w.Cfg.MapW-2; X += 1 {
			c := CellAt(w, X, Y)
			switch c.Terrain {
			case Forest:
				score := c.WoodMax + c.GameMax
				if score > best_f {
					best_f = score
					best_forest = Vec2i{X, Y}
				}
			case Rocky:
				if c.StoneMax > best_r {
					best_r = c.StoneMax
					best_rock = Vec2i{X, Y}
				}
			case Meadow:
				if c.BerryMax > best_m {
					best_m = c.BerryMax
					best_meadow = Vec2i{X, Y}
				}
			}
		}
	}

	if n_clusters > 0 {
		centers[0] = choose(best_m >= 0, best_meadow, Vec2i{w.Cfg.MapW / 3, w.Cfg.MapH / 2})
	}
	if n_clusters > 1 {
		centers[1] = choose(best_f >= 0, best_forest, Vec2i{w.Cfg.MapW / 2, w.Cfg.MapH / 3})
	}
	if n_clusters > 2 {
		centers[2] = choose(best_r >= 0, best_rock, Vec2i{2 * w.Cfg.MapW / 3, 2 * w.Cfg.MapH / 3})
	}
	for i := i32(3); i < n_clusters; i += 1 {
		centers[i] = Vec2i{
			RngRangeI32(&w.Rng, 4, w.Cfg.MapW-5),
			RngRangeI32(&w.Rng, 4, w.Cfg.MapH-5),
		}
	}

	occupied := make([]u8, len(w.Cells))

	for i := i32(0); i < N; i += 1 {
		center := centers[i%n_clusters]
		placed := false
		for attempt := 0; attempt < 80; attempt++ {
			jx := RngRangeI32(&w.Rng, -7, 7)
			jy := RngRangeI32(&w.Rng, -6, 6)
			X := ClampI32(center.X+jx, 1, w.Cfg.MapW-2)
			Y := ClampI32(center.Y+jy, 1, w.Cfg.MapH-2)
			idx := CellIndex(w, X, Y)
			if occupied[idx] != 0 {
				continue
			}
			occupied[idx] = 1
			InitHousehold(w, i, X, Y)
			placed = true
			break
		}
		if !placed {
			// fallback: first free cell
			for Y := i32(0); Y < w.Cfg.MapH && !placed; Y += 1 {
				for X := i32(0); X < w.Cfg.MapW && !placed; X += 1 {
					idx := CellIndex(w, X, Y)
					if occupied[idx] == 0 {
						occupied[idx] = 1
						InitHousehold(w, i, X, Y)
						placed = true
					}
				}
			}
		}
	}
}

func InitHousehold(w *World, idx i32, X i32, Y i32) {
	h := &w.Households[idx]
	h.Id = idx
	h.Exists = true
	h.Alive = true
	h.Home = Vec2i{X, Y}
	h.HutVariant = u8(RngRangeI32(&w.Rng, 0, 2))
	h.Health = RngRangeI32(&w.Rng, 9000, HEALTH_MAX)
	h.SpearDurability = 0
	h.CraftProgress = 0
	h.InferredRole = Generalist
	h.PrevInferredRole = Generalist
	h.MemberCount = 0

	pref_days := RngRangeI32(&w.Rng, w.Cfg.PreferredFoodDaysMin, w.Cfg.PreferredFoodDaysMax)
	h.PrefDaysMilli = pref_days
	h.TradeOpenness = RngRangeI32(&w.Rng, 5500, 10000)
	h.RiskPreference = RngRangeI32(&w.Rng, 3500, 8000)

	man_years := RngRangeI32(&w.Rng, 20, 40)
	delta := RngRangeI32(&w.Rng, -6, 6)
	woman_years := ClampI32(man_years+delta, 20, 40)
	man_con := RngRangeI32(&w.Rng, 8500, HEALTH_MAX)
	woman_con := RngRangeI32(&w.Rng, 8500, HEALTH_MAX)
	man_h := ClampI32(man_con+RngRangeI32(&w.Rng, -400, 400), 8000, HEALTH_MAX)
	woman_h := ClampI32(woman_con+RngRangeI32(&w.Rng, -400, 400), 8000, HEALTH_MAX)
	mid := SpawnPerson(w, h, Male, man_years*w.Cfg.DaysPerYear, man_h, man_con)
	wid := SpawnPerson(w, h, Female, woman_years*w.Cfg.DaysPerYear, woman_h, woman_con)
	if mid >= 0 && wid >= 0 {
		LinkSpouses(PersonAt(w, mid), PersonAt(w, wid))
	}
	SyncHouseholdFromMembers(w, h)

	food_days := RngRangeI32(&w.Rng, w.Cfg.StartFoodDaysMin, w.Cfg.StartFoodDaysMax)
	total_nut := HouseholdDailyNeed(w, h) * i64(food_days) / 1000
	meat_share := RngRangeI32(&w.Rng, 2000, 6000)
	meat_nut := total_nut * i64(meat_share) / 10000
	berry_nut := total_nut - meat_nut
	h.Inv.Qty[Berries] = berry_nut * QTY_SCALE / w.Cfg.BerryNutrition
	h.Inv.Qty[Meat] = meat_nut * QTY_SCALE / w.Cfg.MeatNutrition
	h.Inv.Qty[Wood] = RngRangeI64(&w.Rng, w.Cfg.StartWoodMin, w.Cfg.StartWoodMax)
	if RngChanceBp(&w.Rng, 4500) {
		h.Inv.Qty[Stone] = RngRangeI64(&w.Rng, 0, QTY_SCALE)
	} else {
		h.Inv.Qty[Stone] = 0
	}
	if RngChanceBp(&w.Rng, w.Cfg.StartSpearChanceBp) {
		h.Inv.Qty[Spear] = QTY_SCALE
		h.SpearDurability = RngRangeI32(&w.Rng, min(i32(40), w.Cfg.SpearDurabilityMax), w.Cfg.SpearDurabilityMax)
	}

	h.LastFoodNutrition = NutritionOf(h.Inv, w.Cfg)
}

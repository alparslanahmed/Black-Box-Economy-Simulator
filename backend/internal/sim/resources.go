package sim

func RegenResources(w *World) {
	scale := i64(w.BerryRegenScaleBp)
	for index_c := range w.Cells {
		c := &w.Cells[index_c]
		c.Extracted = [4]i64{}
		if c.BerryMax > 0 {
			add := c.BerryRegen * scale / 10000
			if add < 1 && c.BerryRegen > 0 && scale > 0 {
				add = 1
			}
			c.BerryStock = min(c.BerryMax, c.BerryStock+add)
		}
		if c.GameMax > 0 {
			c.GameStock = min(c.GameMax, c.GameStock+c.GameRegen)
		}
		if c.WoodMax > 0 {
			c.WoodStock = min(c.WoodMax, c.WoodStock+c.WoodRegen)
		}
	}
}

func StockOf(c *Cell, r ResourceKind) i64 {
	switch r {
	case Berry:
		return c.BerryStock
	case Game:
		return c.GameStock
	case Wood:
		return c.WoodStock
	case Stone:
		return c.StoneStock
	}
	return 0
}

func MaxOf(c *Cell, r ResourceKind) i64 {
	switch r {
	case Berry:
		return c.BerryMax
	case Game:
		return c.GameMax
	case Wood:
		return c.WoodMax
	case Stone:
		return c.StoneMax
	}
	return 0
}

func ExtractStock(w *World, Cell Vec2i, r ResourceKind, want i64) i64 {
	if want <= 0 || !InBounds(w, Cell.X, Cell.Y) {
		return 0
	}
	c := CellAtPos(w, Cell)
	have := StockOf(c, r)
	got := min(have, want)
	if got <= 0 {
		return 0
	}
	switch r {
	case Berry:
		c.BerryStock -= got
		c.Extracted[0] += got
		if c.BerryStock == 0 {
			PushEvent(w, Event{Kind: Resource_Depleted, Cell: Cell, GoodA: Berries, QtyA: got})
		}
	case Game:
		c.GameStock -= got
		c.Extracted[1] += got
		if c.GameStock == 0 {
			PushEvent(w, Event{Kind: Resource_Depleted, Cell: Cell, GoodA: Meat, QtyA: got})
		}
	case Wood:
		c.WoodStock -= got
		c.Extracted[2] += got
		if c.WoodStock == 0 {
			PushEvent(w, Event{Kind: Resource_Depleted, Cell: Cell, GoodA: Wood, QtyA: got})
		}
	case Stone:
		c.StoneStock -= got
		c.Extracted[3] += got
		if c.StoneStock == 0 {
			PushEvent(w, Event{Kind: Resource_Depleted, Cell: Cell, GoodA: Stone, QtyA: got})
		}
	}
	return got
}

func TotalResourceStock(w *World) [4]i64 {
	var s [4]i64
	for index_c := range w.Cells {
		c := &w.Cells[index_c]
		s[0] += c.BerryStock
		s[1] += c.GameStock
		s[2] += c.WoodStock
		s[3] += c.StoneStock
	}
	return s
}

type FindResult struct {
	Cell      Vec2i `json:"cell"`
	Travel    i32   `json:"travel"`
	Stock     i64   `json:"stock"`
	Effective i32   `json:"effective"`
	Found     bool  `json:"found"`
}

func FindBestResourceCell(w *World, h *Household, r ResourceKind, Skill i32, yield_per_min i64, available i32, actor *Person) FindResult {
	var res FindResult
	var best i64 = -1
	Home := h.Home
	radius := w.Cfg.SearchRadius
	x0 := max(i32(0), Home.X-radius)
	x1 := min(w.Cfg.MapW-1, Home.X+radius)
	y0 := max(i32(0), Home.Y-radius)
	y1 := min(w.Cfg.MapH-1, Home.Y+radius)
	radius_milli := radius * 1000
	budget := available
	if budget <= 0 {
		budget = w.Cfg.BlockMinutes
	}
	max_work := w.Cfg.BlockMinutes
	speed := PersonWalkSpeedBp(actor, w.Cfg)

	for Y := y0; Y <= y1; Y += 1 {
		for X := x0; X <= x1; X += 1 {
			milli := OctileMilli(Home.X, Home.Y, X, Y)
			if milli > radius_milli {
				continue
			}
			one := WalkMinutes(w.Cfg, Home.X, Home.Y, X, Y, speed)
			Travel := one * 2
			if Travel >= budget {
				continue
			}
			eff := budget - Travel
			if eff > max_work {
				eff = max_work
			}
			if eff <= 0 {
				continue
			}
			c := CellAt(w, X, Y)
			st := StockOf(c, r)
			if st <= 0 {
				continue
			}
			raw := i64(eff) * yield_per_min * i64(Skill) / i64(SKILL_AVERAGE)
			got := min(raw, st)
			score := got * 1000 / i64(1000+Travel)
			if score > best {
				best = score
				res = FindResult{
					Cell:      Vec2i{X, Y},
					Travel:    Travel,
					Stock:     st,
					Effective: eff,
					Found:     true,
				}
			}
		}
	}
	return res
}

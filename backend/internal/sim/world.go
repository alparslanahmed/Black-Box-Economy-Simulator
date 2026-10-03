package sim

func WorldCreate(Seed u64, Cfg Config, TradeEnabled bool, BerryRegenScaleBp i32) *World {
	ok, err := ValidateConfig(Cfg)
	if !ok {
		panic(err)
	}

	w := new(World)
	w.Seed = Seed
	w.Cfg = Cfg
	w.TradeEnabled = TradeEnabled
	assert(BerryRegenScaleBp >= 0, "berry regeneration scale must be nonnegative")
	w.BerryRegenScaleBp = BerryRegenScaleBp
	w.Day = 0
	RngSeed(&w.Rng, Seed)

	n_cells := int(Cfg.MapW * Cfg.MapH)
	w.Cells = make([]Cell, n_cells)
	hh_cap := int(Cfg.HouseholdCount) * 4
	if hh_cap < 64 {
		hh_cap = 64
	}
	if hh_cap > 400 {
		hh_cap = 400
	}
	if hh_cap < int(Cfg.HouseholdCount) {
		hh_cap = int(Cfg.HouseholdCount)
	}
	w.Households = make([]Household, hh_cap)
	people_cap := hh_cap * int(MAX_MEMBERS)
	if people_cap < 16 {
		people_cap = 16
	}
	w.People = make([]Person, people_cap)
	w.PersonCount = 0
	w.Order = make([]i32, hh_cap)
	w.PersonOrder = make([]i32, people_cap)
	for i := 0; i < int(Cfg.HouseholdCount); i++ {
		w.Order[i] = i32(i)
	}

	GenerateTerrain(w)
	PlaceHouseholds(w)
	return w
}

// People keep permanent IDs for genealogy. Growth invalidates ^Person pointers;
// callers of spawn_person must reacquire them by ID after a possible birth.
func GrowPeople(w *World) {
	capacity := max(len(w.People)*2, 16)
	People := make([]Person, capacity)
	copy(People, w.People)
	w.People = People
	Order := make([]i32, capacity)
	copy(Order, w.PersonOrder)
	w.PersonOrder = Order
}

// WorldDestroy is retained for port parity; Go manages the allocations.
func WorldDestroy(w *World) {}

func InBounds(w *World, X i32, Y i32) bool {
	return X >= 0 && Y >= 0 && X < w.Cfg.MapW && Y < w.Cfg.MapH
}

func CellIndex(w *World, X i32, Y i32) int {
	return int(Y*w.Cfg.MapW + X)
}

func CellAt(w *World, X i32, Y i32) *Cell {
	return &w.Cells[CellIndex(w, X, Y)]
}

func CellAtPos(w *World, p Vec2i) *Cell {
	return CellAt(w, p.X, p.Y)
}

func AliveCount(w *World) i32 {
	var N i32
	for i := i32(0); i < w.PersonCount; i += 1 {
		if w.People[i].Alive {
			N += 1
		}
	}
	return N
}

func AliveHouseholds(w *World) i32 {
	var N i32
	for _, h := range w.Households {
		if h.Exists && h.Alive {
			N += 1
		}
	}
	return N
}

// Hash values field by field: no padding, allocation addresses or unused slots.
// Reflection makes new fields in Config, Person and Household participate too.
func StateHash(w *World) u64 {
	var h u64 = 14695981039346656037
	h = hash_state_value(h, w.Seed)
	h = hash_state_value(h, w.Day)
	h = hash_state_value(h, w.Rng)
	h = hash_state_value(h, w.Cfg)
	h = hash_state_value(h, w.TradeEnabled)
	h = hash_state_value(h, w.BerryRegenScaleBp)
	h = hash_state_value(h, w.Households)
	h = hash_state_value(h, w.People[:w.PersonCount])
	h = hash_state_value(h, w.Cells)
	h = hash_state_value(h, w.Acc)
	h = hash_state_value(h, w.TotalDeaths)
	h = hash_state_value(h, w.TotalMarriages)
	h = hash_state_value(h, w.Metrics.Count)
	for i := u32(0); i < w.Metrics.Count; i += 1 {
		h = hash_state_value(h, MetricsAt(&w.Metrics, i))
	}
	h = hash_state_value(h, w.Exchanges.Count)
	var start u32 = 0
	if w.Exchanges.Count == EXCHANGE_CAP {
		start = w.Exchanges.Head
	}
	for i := u32(0); i < w.Exchanges.Count; i += 1 {
		h = hash_state_value(h, w.Exchanges.Items[(start+i)%EXCHANGE_CAP])
	}
	return h
}

func AssertInvariants(w *World) {
	for index_h := range w.Households {
		h := &w.Households[index_h]
		if !h.Exists {
			continue
		}
		for g := 0; g < GOOD_COUNT; g++ {
			if h.Inv.Qty[g] < 0 {
				panic("negative inventory")
			}
		}
		if h.Health < 0 || h.Health > HEALTH_MAX {
			panic("health out of range")
		}
		if h.SpearDurability < 0 || h.SpearDurability > w.Cfg.SpearDurabilityMax {
			panic("spear durability out of range")
		}
		assert(i64(len(h.SpareSpears)) == max(SpearCount(h.Inv)-1, 0), "spear count and condition disagree")
		for _, durability := range h.SpareSpears {
			assert(durability > 0 && durability <= w.Cfg.SpearDurabilityMax, "invalid spare spear condition")
		}
		assert(h.Inv.Qty[Spear]%QTY_SCALE == 0, "fractional spear")
		assert(SpearCount(h.Inv) == 0 || h.SpearDurability > 0, "spear without condition")
		for i := i32(0); i < h.MemberCount; i += 1 {
			p := PersonAt(w, h.Members[i])
			assert(p != nil && p.Alive && p.Household == h.Id, "household membership mismatch")
			for j := i32(0); j < i; j += 1 {
				assert(h.Members[j] != p.Id, "duplicate household member")
			}
		}
		if h.SpearDurability > 0 && h.Inv.Qty[Spear] < QTY_SCALE && h.Alive {
			// durability without a spear is illegal except mid-break handling
			if h.Inv.Qty[Spear] == 0 && h.SpearDurability != 0 {
				panic("durability without spear")
			}
		}
		if !h.Alive {
			// dead households may keep leftover inventory; they must not act
		}
	}
	for i := i32(0); i < w.PersonCount; i += 1 {
		p := &w.People[i]
		if p.Health < 0 || p.Health > HEALTH_MAX {
			panic("person health out of range")
		}
		if p.Alive && (p.Household < 0 || int(p.Household) >= len(w.Households)) {
			panic("person household id")
		}
		if p.Alive {
			h := &w.Households[p.Household]
			Found := false
			for j := i32(0); j < h.MemberCount; j += 1 {
				if h.Members[j] == p.Id {
					Found = true
				}
			}
			assert(h.Exists && h.Alive && Found, "living person missing from household")
		}
	}
	for index_c := range w.Cells {
		c := &w.Cells[index_c]
		if c.BerryStock < 0 || c.GameStock < 0 || c.WoodStock < 0 || c.StoneStock < 0 {
			panic("negative resource stock")
		}
		if c.BerryStock > c.BerryMax+1 ||
			c.GameStock > c.GameMax+1 ||
			c.WoodStock > c.WoodMax+1 ||
			c.StoneStock > c.StoneMax+1 {
			panic("resource stock exceeds capacity")
		}
	}
}

func WorldResetSameSeed(w *World) *World {
	Seed := w.Seed
	Cfg := w.Cfg
	trade := w.TradeEnabled
	scale := w.BerryRegenScaleBp
	WorldDestroy(w)
	return WorldCreate(Seed, Cfg, trade, scale)
}

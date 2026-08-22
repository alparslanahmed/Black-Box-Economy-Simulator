package sim

Good_Def :: struct {
	id:               Good,
	display_name:     string,
	nutrition:        i64,
	daily_spoilage_bp: i32,
	min_trade_qty:    i64,
	is_tool:          bool,
	is_food:          bool,
	divisible:        bool,
}

good_def :: proc(g: Good) -> Good_Def {
	switch g {
	case .Berries:
		return Good_Def{
			id = .Berries,
			display_name = "Berries",
			nutrition = 1 * QTY_SCALE,
			daily_spoilage_bp = 2200,
			min_trade_qty = 200,
			is_food = true,
			divisible = true,
		}
	case .Meat:
		return Good_Def{
			id = .Meat,
			display_name = "Meat",
			nutrition = 2500,
			daily_spoilage_bp = 3000,
			min_trade_qty = 200,
			is_food = true,
			divisible = true,
		}
	case .Wood:
		return Good_Def{
			id = .Wood,
			display_name = "Wood",
			min_trade_qty = 200,
			divisible = true,
		}
	case .Stone:
		return Good_Def{
			id = .Stone,
			display_name = "Stone",
			min_trade_qty = 200,
			divisible = true,
		}
	case .Spear:
		return Good_Def{
			id = .Spear,
			display_name = "Spear",
			min_trade_qty = QTY_SCALE,
			is_tool = true,
			divisible = false,
		}
	}
	return Good_Def{}
}

nutrition_of :: proc(inv: Inventory, cfg: Config) -> i64 {
	return inv.qty[Good.Berries] * cfg.berry_nutrition / QTY_SCALE +
		inv.qty[Good.Meat] * cfg.meat_nutrition / QTY_SCALE
}

food_days_milli :: proc(nutrition, daily: i64) -> i64 {
	if daily <= 0 {
		return 0
	}
	return nutrition * 1000 / daily
}

spear_count :: proc(inv: Inventory) -> i64 {
	return inv.qty[Good.Spear] / QTY_SCALE
}

add_good :: proc(inv: ^Inventory, g: Good, qty: i64) {
	if qty <= 0 {
		return
	}
	inv.qty[g] += qty
}

remove_good :: proc(inv: ^Inventory, g: Good, qty: i64) -> bool {
	if qty <= 0 {
		return true
	}
	if inv.qty[g] < qty {
		return false
	}
	inv.qty[g] -= qty
	return true
}

inventory_total_qty :: proc(inv: Inventory) -> i64 {
	s: i64
	for g in Good {
		s += inv.qty[g]
	}
	return s
}

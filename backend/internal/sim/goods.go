package sim

type GoodDef struct {
	Id              Good   `json:"id"`
	DisplayName     string `json:"display_name"`
	Nutrition       i64    `json:"nutrition"`
	DailySpoilageBp i32    `json:"daily_spoilage_bp"`
	MinTradeQty     i64    `json:"min_trade_qty"`
	IsTool          bool   `json:"is_tool"`
	IsFood          bool   `json:"is_food"`
	Divisible       bool   `json:"divisible"`
}

func DescribeGood(g Good) GoodDef {
	switch g {
	case Berries:
		return GoodDef{
			Id:              Berries,
			DisplayName:     "Berries",
			Nutrition:       1 * QTY_SCALE,
			DailySpoilageBp: 2200,
			MinTradeQty:     200,
			IsFood:          true,
			Divisible:       true,
		}
	case Meat:
		return GoodDef{
			Id:              Meat,
			DisplayName:     "Meat",
			Nutrition:       2500,
			DailySpoilageBp: 3000,
			MinTradeQty:     200,
			IsFood:          true,
			Divisible:       true,
		}
	case Wood:
		return GoodDef{
			Id:          Wood,
			DisplayName: "Wood",
			MinTradeQty: 200,
			Divisible:   true,
		}
	case Stone:
		return GoodDef{
			Id:          Stone,
			DisplayName: "Stone",
			MinTradeQty: 200,
			Divisible:   true,
		}
	case Spear:
		return GoodDef{
			Id:          Spear,
			DisplayName: "Spear",
			MinTradeQty: QTY_SCALE,
			IsTool:      true,
			Divisible:   false,
		}
	}
	return GoodDef{}
}

func NutritionOf(Inv Inventory, Cfg Config) i64 {
	return Inv.Qty[Berries]*Cfg.BerryNutrition/QTY_SCALE +
		Inv.Qty[Meat]*Cfg.MeatNutrition/QTY_SCALE
}

func FoodDaysMilli(Nutrition i64, daily i64) i64 {
	if daily <= 0 {
		return 0
	}
	return Nutrition * 1000 / daily
}

func SpearCount(Inv Inventory) i64 {
	return Inv.Qty[Spear] / QTY_SCALE
}

func AddGood(Inv *Inventory, g Good, Qty i64) {
	if Qty <= 0 {
		return
	}
	Inv.Qty[g] += Qty
}

func RemoveGood(Inv *Inventory, g Good, Qty i64) bool {
	if Qty <= 0 {
		return true
	}
	if Inv.Qty[g] < Qty {
		return false
	}
	Inv.Qty[g] -= Qty
	return true
}

func InventoryTotalQty(Inv Inventory) i64 {
	var s i64
	for g := 0; g < GOOD_COUNT; g++ {
		s += Inv.Qty[g]
	}
	return s
}

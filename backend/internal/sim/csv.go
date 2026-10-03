package sim

import "fmt"

// CSV columns and fixed-point units match the original analysis exporter.
const CSVHeader = "day,year,alive_households,food_total,food_days_average,median_health,berries_produced,meat_produced,wood_produced,stone_produced,spears_produced,trade_attempts,successful_trades,trade_success_rate,specialization_average,hunters,foragers,wood_gatherers,stone_gatherers,toolmakers,generalists,hungry_households,deaths_today,berries_resource_stock,game_resource_stock,wood_resource_stock,stone_resource_stock,meat_per_berry,wood_per_berry,stone_per_berry,spear_per_berry,people,births_today\n"

func QuantityCSV(q int64) string {
	if q < 0 {
		return "NA"
	}
	return fmt.Sprintf("%d.%03d", q/QTY_SCALE, q%QTY_SCALE)
}

func MetricsCSV(m DayMetrics) string {
	q := QuantityCSV
	return fmt.Sprintf("%d,%d,%d,%s,%.3f,%d,%s,%s,%s,%s,%s,%d,%d,%.4f,%.4f,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%d,%d\n",
		m.Day, m.Year, m.AliveHouseholds, q(m.FoodTotal), float64(m.FoodDaysAvgMilli)/1000, m.MedianHealth,
		q(m.Produced[Berries]), q(m.Produced[Meat]), q(m.Produced[Wood]), q(m.Produced[Stone]), q(m.Produced[Spear]),
		m.TradeAttempts, m.SuccessfulTrades, float64(m.TradeSuccessBp)/10000, float64(m.SpecAvgBp)/10000,
		m.RoleCounts[Hunter], m.RoleCounts[Forager], m.RoleCounts[Wood_Gatherer], m.RoleCounts[Stone_Gatherer], m.RoleCounts[Toolmaker], m.RoleCounts[Generalist], m.Hungry, m.Deaths,
		q(m.ResourceStock[0]), q(m.ResourceStock[1]), q(m.ResourceStock[2]), q(m.ResourceStock[3]), q(m.UnitPerBerry[Meat]), q(m.UnitPerBerry[Wood]), q(m.UnitPerBerry[Stone]), q(m.UnitPerBerry[Spear]), m.Alive, m.Births)
}

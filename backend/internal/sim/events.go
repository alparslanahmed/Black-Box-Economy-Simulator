package sim

import "fmt"

func PushEvent(w *World, e Event) {
	ev := e
	ev.Day = w.Day
	w.Events.Items[w.Events.Head] = ev
	w.Events.Head = (w.Events.Head + 1) % EVENT_CAP
	if w.Events.Count < EVENT_CAP {
		w.Events.Count += 1
	}
}

func EventAt(buf *EventBuf, logical_index u32) Event {
	// 0 = oldest
	var start u32
	if buf.Count < EVENT_CAP {
		start = 0
	} else {
		start = buf.Head
	}
	i := (start + logical_index) % EVENT_CAP
	return buf.Items[i]
}

func FormatQty(q i64) string {
	if q < 0 {
		return fmt.Sprintf("-%s", FormatQty(-q))
	}
	whole := q / QTY_SCALE
	frac := (q % QTY_SCALE) / 100
	if frac == 0 {
		return fmt.Sprintf("%d", whole)
	}
	return fmt.Sprintf("%d.%d", whole, frac)
}

func FormatEvent(e Event, DaysPerYear i32) string {
	switch e.Kind {
	case Work_Completed:
		if e.Activity == Visit && e.H2 >= 0 {
			return fmt.Sprintf("Day %d — Household %d walked to household %d to visit.", e.Day, e.H1, e.H2)
		}
		return fmt.Sprintf("Day %d — Household %d completed %s.", e.Day, e.H1, ActivityName(e.Activity))
	case Hunt_Succeeded:
		return fmt.Sprintf("Day %d — Household %d succeeded in a hunt and brought back %s meat.", e.Day, e.H1, FormatQty(e.QtyA))
	case Hunt_Failed:
		return fmt.Sprintf("Day %d — Household %d failed a hunt.", e.Day, e.H1)
	case Resource_Depleted:
		return fmt.Sprintf("Day %d — %s stock at (%d, %d) is exhausted.", e.Day, GoodName(e.GoodA), e.Cell.X, e.Cell.Y)
	case Spear_Crafted:
		return fmt.Sprintf("Day %d — Household %d finished crafting a spear.", e.Day, e.H1)
	case Spear_Broke:
		return fmt.Sprintf("Day %d — Household %d's spear broke while hunting.", e.Day, e.H1)
	case Trade_Completed:
		return fmt.Sprintf(
			"Day %d — Household %d traded %s %s to Household %d for %s %s.",
			e.Day, e.H1, FormatQty(e.QtyA), GoodName(e.GoodA),
			e.H2, FormatQty(e.QtyB), GoodName(e.GoodB),
		)
	case Trade_Failed:
		reason := "unknown reason"
		switch e.Fail {
		case None:
			reason = "unknown reason"
		case No_Double_Coincidence:
			reason = "no double coincidence of wants"
		case No_Mutual_Gain:
			reason = "no mutually beneficial bundle"
		case Insufficient_Inventory:
			reason = "insufficient inventory"
		case Dead_Or_Disabled:
			reason = "a household was not able to trade"
		}
		return fmt.Sprintf("Day %d — Household %d and Household %d failed to trade (%s).", e.Day, e.H1, e.H2, reason)
	case Food_Spoiled:
		return fmt.Sprintf("Day %d — Household %d lost %s berries and %s meat to spoilage.", e.Day, e.H1, FormatQty(e.QtyA), FormatQty(e.QtyB))
	case Hunger:
		return fmt.Sprintf("Day %d — Household %d went hungry.", e.Day, e.H1)
	case Household_Died:
		return fmt.Sprintf("Day %d — The last people of household %d died. The hut stands empty.", e.Day, e.H1)
	case Specialization_Changed:
		return fmt.Sprintf("Day %d — Household %d is now primarily specializing as a %s.", e.Day, e.H1, RoleName(e.Role))
	case Person_Born:
		return fmt.Sprintf("Day %d — A child was born in household %d (health %d).", e.Day, e.H1, e.QtyA)
	case Person_Died:
		years := e.QtyA / i64(DaysPerYear)
		return fmt.Sprintf("Day %d — A person in household %d died at age %d.", e.Day, e.H1, years)
	case Married:
		place := ResidencePlaceName(e.QtyB)
		return fmt.Sprintf("Day %d — Person #%d married person #%d and settled in %s (household #%d).", e.Day, e.H1, e.H2, place, e.QtyA)
	case Household_Founded:
		return fmt.Sprintf("Day %d — Household #%d founded a new camp at (%d, %d).", e.Day, e.H1, e.Cell.X, e.Cell.Y)
	}
	return fmt.Sprintf("Day %d — event", e.Day)
}

func ResidencePlaceName(V i64) string {
	switch V {
	case 0:
		return "the husband's camp"
	case 1:
		return "the wife's camp"
	case 2:
		return "a newly built camp"
	}
	return "a camp"
}

func PersonLabel(w *World, Id i32) string {
	p := PersonAt(w, Id)
	if p == nil {
		return fmt.Sprintf("person #%d", Id)
	}
	who := SexName(p.Sex)
	st := LifeStageOf(p, w.Cfg.DaysPerYear)
	if st == Infant || st == Child || st == Youth {
		who = LifeStageName(st)
	}
	if !p.Alive {
		return fmt.Sprintf("%s #%d (dead, age %d)", who, p.Id, AgeYears(p, w.Cfg.DaysPerYear))
	}
	return fmt.Sprintf("%s #%d (age %d)", who, p.Id, AgeYears(p, w.Cfg.DaysPerYear))
}

func FormatLifeEvent(w *World, e Event) string {
	switch e.Kind {
	case Married:
		place := ResidencePlaceName(e.QtyB)
		return fmt.Sprintf(
			"Day %d — %s married %s. They live in %s, household #%d.",
			e.Day, PersonLabel(w, e.H1), PersonLabel(w, e.H2), place, e.QtyA,
		)
	case Person_Born:
		return fmt.Sprintf(
			"Day %d — %s was born in household #%d (birth health %d).",
			e.Day, PersonLabel(w, e.H2), e.H1, e.QtyA,
		)
	case Person_Died:
		years := e.QtyA / i64(w.Cfg.DaysPerYear)
		return fmt.Sprintf(
			"Day %d — %s died at age %d (household #%d).",
			e.Day, PersonLabel(w, e.H2), years, e.H1,
		)
	case Household_Founded:
		return fmt.Sprintf(
			"Day %d — %s and %s built household #%d at (%d, %d).",
			e.Day, PersonLabel(w, e.H2), PersonLabel(w, i32(e.QtyA)), e.H1, e.Cell.X, e.Cell.Y,
		)
	case Household_Died:
		return fmt.Sprintf("Day %d — Household #%d is abandoned. The hut still stands.", e.Day, e.H1)
	case Work_Completed, Hunt_Succeeded, Hunt_Failed, Resource_Depleted, Spear_Crafted, Spear_Broke,
		Trade_Completed, Trade_Failed, Food_Spoiled, Hunger, Specialization_Changed:
		return FormatEvent(e, w.Cfg.DaysPerYear)
	}
	return FormatEvent(e, w.Cfg.DaysPerYear)
}

func EventIsPeople(k EventKind) bool {
	switch k {
	case Married, Person_Born, Person_Died, Household_Founded, Household_Died:
		return true
	}
	return false
}

func EventCategory(k EventKind) string {
	switch k {
	case Trade_Completed, Trade_Failed:
		return "Trade"
	case Work_Completed, Hunt_Succeeded, Hunt_Failed, Spear_Crafted, Spear_Broke:
		return "Production"
	case Resource_Depleted, Food_Spoiled:
		return "Scarcity"
	case Hunger:
		return "Health"
	case Household_Died, Person_Died, Person_Born, Married, Household_Founded:
		return "People"
	case Specialization_Changed:
		return "Specialization"
	}
	return "Other"
}

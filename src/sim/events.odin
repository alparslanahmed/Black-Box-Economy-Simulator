package sim

import "core:fmt"

push_event :: proc(w: ^World, e: Event) {
	ev := e
	ev.day = w.day
	w.events.items[w.events.head] = ev
	w.events.head = (w.events.head + 1) % EVENT_CAP
	if w.events.count < EVENT_CAP {
		w.events.count += 1
	}
}

event_at :: proc(buf: ^Event_Buf, logical_index: u32) -> Event {
	// 0 = oldest
	start: u32
	if buf.count < EVENT_CAP {
		start = 0
	} else {
		start = buf.head
	}
	i := (start + logical_index) % EVENT_CAP
	return buf.items[i]
}

format_qty :: proc(q: i64, allocator := context.temp_allocator) -> string {
	if q < 0 {
		return fmt.tprintf("-%s", format_qty(-q, allocator))
	}
	whole := q / QTY_SCALE
	frac := (q % QTY_SCALE) / 100
	if frac == 0 {
		return fmt.tprintf("%d", whole)
	}
	return fmt.tprintf("%d.%d", whole, frac)
}

format_event :: proc(e: Event, allocator := context.temp_allocator) -> string {
	switch e.kind {
	case .Work_Completed:
		if e.activity == .Visit && e.h2 >= 0 {
			return fmt.tprintf("Day %d — Household %d walked to household %d to visit.", e.day, e.h1, e.h2)
		}
		return fmt.tprintf("Day %d — Household %d completed %s.", e.day, e.h1, activity_name(e.activity))
	case .Hunt_Succeeded:
		return fmt.tprintf("Day %d — Household %d succeeded in a hunt and brought back %s meat.", e.day, e.h1, format_qty(e.qty_a))
	case .Hunt_Failed:
		return fmt.tprintf("Day %d — Household %d failed a hunt.", e.day, e.h1)
	case .Resource_Depleted:
		return fmt.tprintf("Day %d — %s stock at (%d, %d) is exhausted.", e.day, good_name(e.good_a), e.cell.x, e.cell.y)
	case .Spear_Crafted:
		return fmt.tprintf("Day %d — Household %d finished crafting a spear.", e.day, e.h1)
	case .Spear_Broke:
		return fmt.tprintf("Day %d — Household %d's spear broke while hunting.", e.day, e.h1)
	case .Trade_Completed:
		return fmt.tprintf(
			"Day %d — Household %d traded %s %s to Household %d for %s %s.",
			e.day, e.h1, format_qty(e.qty_a), good_name(e.good_a),
			e.h2, format_qty(e.qty_b), good_name(e.good_b),
		)
	case .Trade_Failed:
		reason := "unknown reason"
		switch e.fail {
		case .None: reason = "unknown reason"
		case .No_Double_Coincidence: reason = "no double coincidence of wants"
		case .No_Mutual_Gain: reason = "no mutually beneficial bundle"
		case .Insufficient_Inventory: reason = "insufficient inventory"
		case .Dead_Or_Disabled: reason = "a household was not able to trade"
		}
		return fmt.tprintf("Day %d — Household %d and Household %d failed to trade (%s).", e.day, e.h1, e.h2, reason)
	case .Food_Spoiled:
		return fmt.tprintf("Day %d — Household %d lost %s berries and %s meat to spoilage.", e.day, e.h1, format_qty(e.qty_a), format_qty(e.qty_b))
	case .Hunger:
		return fmt.tprintf("Day %d — Household %d went hungry.", e.day, e.h1)
	case .Household_Died:
		return fmt.tprintf("Day %d — The last people of household %d died. The hut stands empty.", e.day, e.h1)
	case .Specialization_Changed:
		return fmt.tprintf("Day %d — Household %d is now primarily specializing as a %s.", e.day, e.h1, role_name(e.role))
	case .Person_Born:
		return fmt.tprintf("Day %d — A child was born in household %d (health %d).", e.day, e.h1, e.qty_a)
	case .Person_Died:
		years := e.qty_a / i64(DAYS_PER_YEAR)
		return fmt.tprintf("Day %d — A person in household %d died at age %d.", e.day, e.h1, years)
	case .Married:
		place := residence_place_name(e.qty_b)
		return fmt.tprintf("Day %d — Person #%d married person #%d and settled in %s (household #%d).", e.day, e.h1, e.h2, place, e.qty_a)
	case .Household_Founded:
		return fmt.tprintf("Day %d — Household #%d founded a new camp at (%d, %d).", e.day, e.h1, e.cell.x, e.cell.y)
	}
	return fmt.tprintf("Day %d — event", e.day)
}

residence_place_name :: proc(v: i64) -> string {
	switch v {
	case 0:
		return "the husband's camp"
	case 1:
		return "the wife's camp"
	case 2:
		return "a newly built camp"
	}
	return "a camp"
}

person_label :: proc(w: ^World, id: i32, allocator := context.temp_allocator) -> string {
	p := person_at(w, id)
	if p == nil {
		return fmt.tprintf("person #%d", id)
	}
	who := sex_name(p.sex)
	st := life_stage(p)
	if st == .Infant || st == .Child || st == .Youth {
		who = life_stage_name(st)
	}
	if !p.alive {
		return fmt.tprintf("%s #%d (dead, age %d)", who, p.id, age_years(p))
	}
	return fmt.tprintf("%s #%d (age %d)", who, p.id, age_years(p))
}

format_life_event :: proc(w: ^World, e: Event, allocator := context.temp_allocator) -> string {
	switch e.kind {
	case .Married:
		place := residence_place_name(e.qty_b)
		return fmt.tprintf(
			"Day %d — %s married %s. They live in %s, household #%d.",
			e.day, person_label(w, e.h1), person_label(w, e.h2), place, e.qty_a,
		)
	case .Person_Born:
		return fmt.tprintf(
			"Day %d — %s was born in household #%d (birth health %d).",
			e.day, person_label(w, e.h2), e.h1, e.qty_a,
		)
	case .Person_Died:
		years := e.qty_a / i64(DAYS_PER_YEAR)
		return fmt.tprintf(
			"Day %d — %s died at age %d (household #%d).",
			e.day, person_label(w, e.h2), years, e.h1,
		)
	case .Household_Founded:
		return fmt.tprintf(
			"Day %d — %s and %s built household #%d at (%d, %d).",
			e.day, person_label(w, e.h2), person_label(w, i32(e.qty_a)), e.h1, e.cell.x, e.cell.y,
		)
	case .Household_Died:
		return fmt.tprintf("Day %d — Household #%d is abandoned. The hut still stands.", e.day, e.h1)
	case .Work_Completed, .Hunt_Succeeded, .Hunt_Failed, .Resource_Depleted, .Spear_Crafted, .Spear_Broke,
		.Trade_Completed, .Trade_Failed, .Food_Spoiled, .Hunger, .Specialization_Changed:
		return format_event(e)
	}
	return format_event(e)
}

event_is_people :: proc(k: Event_Kind) -> bool {
	#partial switch k {
	case .Married, .Person_Born, .Person_Died, .Household_Founded, .Household_Died:
		return true
	}
	return false
}

event_category :: proc(k: Event_Kind) -> string {
	switch k {
	case .Trade_Completed, .Trade_Failed:
		return "Trade"
	case .Work_Completed, .Hunt_Succeeded, .Hunt_Failed, .Spear_Crafted, .Spear_Broke:
		return "Production"
	case .Resource_Depleted, .Food_Spoiled:
		return "Scarcity"
	case .Hunger:
		return "Health"
	case .Household_Died, .Person_Died, .Person_Born, .Married, .Household_Founded:
		return "People"
	case .Specialization_Changed:
		return "Specialization"
	}
	return "Other"
}

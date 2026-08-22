package sim

Good :: enum u8 {
	Berries,
	Meat,
	Wood,
	Stone,
	Spear,
}

Activity :: enum u8 {
	Forage,
	Hunt,
	Gather_Wood,
	Gather_Stone,
	Craft_Spear,
	Rest,
	Visit,
}

Skill_Kind :: enum u8 {
	Forage,
	Hunt,
	Wood,
	Stone,
	Craft,
}

Terrain :: enum u8 {
	Meadow,
	Forest,
	Rocky,
}

Resource_Kind :: enum u8 {
	Berry,
	Game,
	Wood,
	Stone,
}

Role :: enum u8 {
	Generalist,
	Forager,
	Hunter,
	Wood_Gatherer,
	Stone_Gatherer,
	Toolmaker,
}

Trade_Fail :: enum u8 {
	None,
	No_Double_Coincidence,
	No_Mutual_Gain,
	Insufficient_Inventory,
	Dead_Or_Disabled,
}

Event_Kind :: enum u8 {
	Work_Completed,
	Hunt_Succeeded,
	Hunt_Failed,
	Resource_Depleted,
	Spear_Crafted,
	Spear_Broke,
	Trade_Completed,
	Trade_Failed,
	Food_Spoiled,
	Hunger,
	Household_Died,
	Specialization_Changed,
	Person_Born,
	Person_Died,
	Married,
	Household_Founded,
}

Residence :: enum u8 {
	Father,
	Mother,
	New,
}

Sex :: enum u8 {
	Male,
	Female,
}

Life_Stage :: enum u8 {
	Infant,
	Child,
	Youth,
	Adult,
	Elder,
}

PATH_MAX :: 32
MAX_MEMBERS :: 8

Path_Pt :: struct {
	x, y: i32, // milli-cells
	t:    i32, // 0..10_000 through the day
}

Person :: struct {
	id:           i32,
	household:    i32,
	sex:          Sex,
	alive:        bool,
	age_days:     i32,
	health:       i32,
	constitution: i32, // inherited baseline, 10000 = average

	skills: [SKILL_COUNT]i32,

	pregnant:                 bool,
	pregnancy_days:           i32,
	preg_food_days_acc:       i64, // sum of household food-days-milli
	preg_days_counted:        i32,
	father_id:                i32,
	mother_id:                i32,
	spouse_id:                i32, // -1 if no living marriage
	natal_household:          i32,

	intent_activity: Activity,
	intent_cell:     Vec2i,
	intent_partner:  i32, // household id for Visit, else -1
	last_decision:   Decision,
	blocks_this_day: i32,

	clock:         i32, // minute of the current day while planning
	wake_min:      i32,
	sleep_start:   i32,
	minutes_sleep: i32,
	minutes_home:  i32,
	minutes_work:  i32,
	minutes_travel: i32,
	minutes_visit: i32,
	visits_today:  i32,

	path:     [PATH_MAX]Path_Pt,
	path_n:   i32,
	trade_hh: i32, // -1 none; partner household visited today
}

Overlay_Kind :: enum u8 {
	Normal,
	Resources,
	Trade,
	Specialization,
	Food_Security,
}

Vec2i :: struct {
	x, y: i32,
}

Inventory :: struct {
	qty: [GOOD_COUNT]i64,
}

Cell :: struct {
	terrain: Terrain,
	berry_stock, berry_max, berry_regen: i64,
	game_stock,  game_max,  game_regen:  i64,
	wood_stock,  wood_max,  wood_regen:  i64,
	stone_stock, stone_max:              i64,
	extracted: [4]i64, // berry, game, wood, stone today
}

Decision_Candidate :: struct {
	activity:        Activity,
	total_score:     i64,
	food_need:       i64,
	fuel_need:       i64,
	tool:            i64,
	input:           i64,
	trade_demand:    i64,
	skill:           i64,
	travel:          i64,
	risk:            i64,
	target_cell:     Vec2i,
	expected_output: i64,
	feasible:        bool,
	partner:         i32, // household id for Visit, else -1
	work_min:        i32, // labor, linger, or rest minutes planned for this bout
}

Decision :: struct {
	chosen:          Activity,
	chosen_index:    i32,
	candidates:      [DECISION_CANDIDATES]Decision_Candidate,
	candidate_count: i32,
}

Trade_Record :: struct {
	day:       i32,
	partner:   i32,
	gave_good: Good,
	got_good:  Good,
	gave_qty:  i64,
	got_qty:   i64,
	success:   bool,
	fail:      Trade_Fail,
}

Exchange :: struct {
	day:     i32,
	g0, g1:  Good,
	q0, q1:  i64,
	h0, h1:  i32,
}

Event :: struct {
	day:         i32,
	kind:        Event_Kind,
	h1, h2:      i32,
	good_a:      Good,
	good_b:      Good,
	qty_a:       i64,
	qty_b:       i64,
	cell:        Vec2i,
	activity:    Activity,
	fail:        Trade_Fail,
	role:        Role,
}

Event_Buf :: struct {
	items: [EVENT_CAP]Event,
	head:  u32,
	count: u32,
}

Exchange_Buf :: struct {
	items: [EXCHANGE_CAP]Exchange,
	head:  u32,
	count: u32,
}

Day_Metrics :: struct {
	day:                 i32,
	year:                i32,
	alive:               i32, // living people
	alive_households:    i32,
	births:              i32,
	marriages:           i32,
	unmarried:           i32, // living, no living spouse
	unmarried_bp:        i32, // of living people
	unmarried_marriageable: i32,
	unmarried_marriageable_bp: i32, // of living marriageable people
	fertile_women:       i32,
	cbr_milli:           i32, // crude birth rate; 28000 = 28.0 births per 1000 people per year
	tfr_milli:           i32, // total fertility; 2100 = 2.10 children per woman
	birth_rate_days:     i32, // trailing window used for CBR/TFR
	food_total:          i64,
	food_days_avg_milli: i64,
	median_health:       i32,
	produced:            [GOOD_COUNT]i64,
	trade_attempts:      i32,
	successful_trades:   i32,
	trade_success_bp:    i32,
	fail_no_dc:          i32,
	fail_no_gain:        i32,
	fail_inv:            i32,
	barter_qty_total:    i64,
	spec_avg_bp:         i32,
	role_counts:         [ROLE_COUNT]i32,
	hungry:              i32,
	deaths:              i32,
	visits:              i32,
	travel_minutes_total: i32,
	food_spoiled:        i64,
	resource_stock:      [4]i64,
	spear_own_bp:        i32,
	avg_skill:           [SKILL_COUNT]i32,
	berries_per_unit:    [GOOD_COUNT]i64, // QTY_SCALE = 1.0 berries per 1 unit; -1 = N/A
	unit_per_berry:      [GOOD_COUNT]i64, // for CSV *per_berry columns; -1 = N/A
}

Metrics_Buf :: struct {
	items: [METRICS_CAP]Day_Metrics,
	head:  u32,
	count: u32,
}

Day_Acc :: struct {
	produced:          [GOOD_COUNT]i64,
	trade_attempts:    i32,
	successful_trades: i32,
	fail_no_dc:        i32,
	fail_no_gain:      i32,
	fail_inv:          i32,
	barter_qty_total:  i64,
	food_spoiled:      i64,
	deaths:            i32,
	hungry:            i32,
	births:            i32,
	marriages:         i32,
	visits:            i32,
	travel_minutes_total: i32,
}

Household :: struct {
	id:    i32,
	exists: bool, // slot allocated (new camps reuse empty slots)
	alive: bool,
	home:  Vec2i,
	hut_variant: u8,
	health: i32, // average of living members, overlay/analytics

	members:      [MAX_MEMBERS]i32,
	member_count: i32,

	inv: Inventory,
	spear_durability: i32,

	skills: [SKILL_COUNT]i32, // average of working-age members

	preferred_food_nutrition: i64,
	pref_days_milli:          i32,
	trade_openness:           i32,
	risk_preference:          i32,

	craft_progress: i32,

	observed_demand: [GOOD_COUNT]i32,

	labor_hist:     [LABOR_HISTORY_DAYS][SKILL_COUNT]i32,
	labor_hist_idx: i32,
	labor_today:    [SKILL_COUNT]i32,

	recent_trades:      [TRADE_MEMORY]Trade_Record,
	recent_trade_count: i32,
	recent_trade_head:  i32,

	last_decision:    Decision,
	intent_activity:  Activity,
	intent_cell:      Vec2i,
	visits_today:     i32,

	inferred_role:      Role,
	prev_inferred_role: Role,
	specialization_bp:  i32,

	last_food_nutrition: i64,
}

World :: struct {
	seed:          u64,
	rng:           RNG,
	day:           i32,
	cfg:           Config,
	trade_enabled: bool,
	berry_regen_scale_bp: i32, // 10000 = as configured

	cells:      []Cell,
	households: []Household,
	people:     []Person,
	person_count: i32,
	order:      []i32,
	person_order: []i32,

	events:    Event_Buf,
	metrics:   Metrics_Buf,
	exchanges: Exchange_Buf,
	acc:       Day_Acc,

	total_deaths: i32,
	total_marriages: i32,
}

activity_is_productive :: proc(a: Activity) -> bool {
	return a != .Rest && a != .Visit
}

activity_to_skill :: proc(a: Activity) -> (Skill_Kind, bool) {
	if a == .Rest || a == .Visit {
		return .Forage, false
	}
	return Skill_Kind(u8(a)), true
}

activity_output_good :: proc(a: Activity) -> (Good, bool) {
	switch a {
	case .Forage:       return .Berries, true
	case .Hunt:         return .Meat, true
	case .Gather_Wood:  return .Wood, true
	case .Gather_Stone: return .Stone, true
	case .Craft_Spear:  return .Spear, true
	case .Rest, .Visit: return .Berries, false
	}
	return .Berries, false
}

activity_resource :: proc(a: Activity) -> (Resource_Kind, bool) {
	switch a {
	case .Forage:       return .Berry, true
	case .Hunt:         return .Game, true
	case .Gather_Wood:  return .Wood, true
	case .Gather_Stone: return .Stone, true
	case .Craft_Spear, .Rest, .Visit:
		return .Berry, false
	}
	return .Berry, false
}

role_from_activity :: proc(a: Activity) -> Role {
	switch a {
	case .Forage:       return .Forager
	case .Hunt:         return .Hunter
	case .Gather_Wood:  return .Wood_Gatherer
	case .Gather_Stone: return .Stone_Gatherer
	case .Craft_Spear:  return .Toolmaker
	case .Rest, .Visit: return .Generalist
	}
	return .Generalist
}

good_name :: proc(g: Good) -> string {
	switch g {
	case .Berries: return "berries"
	case .Meat:    return "meat"
	case .Wood:    return "wood"
	case .Stone:   return "stone"
	case .Spear:   return "spear"
	}
	return "?"
}

activity_name :: proc(a: Activity) -> string {
	switch a {
	case .Forage:       return "Forage"
	case .Hunt:         return "Hunt"
	case .Gather_Wood:  return "Gather wood"
	case .Gather_Stone: return "Gather stone"
	case .Craft_Spear:  return "Craft spear"
	case .Rest:         return "Rest"
	case .Visit:        return "Visit neighbor"
	}
	return "?"
}

role_name :: proc(r: Role) -> string {
	switch r {
	case .Generalist:     return "Generalist"
	case .Forager:        return "Forager"
	case .Hunter:         return "Hunter"
	case .Wood_Gatherer:  return "Wood Gatherer"
	case .Stone_Gatherer: return "Stone Gatherer"
	case .Toolmaker:      return "Toolmaker"
	}
	return "?"
}

terrain_name :: proc(t: Terrain) -> string {
	switch t {
	case .Meadow: return "Meadow"
	case .Forest: return "Forest"
	case .Rocky:  return "Rocky"
	}
	return "?"
}

clamp_i32 :: proc(v, lo, hi: i32) -> i32 {
	if v < lo do return lo
	if v > hi do return hi
	return v
}

clamp_i64 :: proc(v, lo, hi: i64) -> i64 {
	if v < lo do return lo
	if v > hi do return hi
	return v
}

abs_i32 :: proc(v: i32) -> i32 {
	if v < 0 do return -v
	return v
}

octile_milli :: proc(ax, ay, bx, by: i32) -> i32 {
	dx := abs_i32(ax - bx)
	dy := abs_i32(ay - by)
	mn := min(dx, dy)
	mx := max(dx, dy)
	return 1414 * mn + 1000 * (mx - mn)
}

// One-way walk time in minutes at the given speed (10000 = average adult).
walk_minutes :: proc(cfg: Config, ax, ay, bx, by: i32, speed_bp: i32 = BP_SCALE) -> i32 {
	milli := octile_milli(ax, ay, bx, by)
	if milli <= 0 {
		return 0
	}
	sp := speed_bp
	if sp < 4000 do sp = 4000
	if sp > 14000 do sp = 14000
	mins := milli * cfg.minutes_per_cell * 10000 / (1000 * sp)
	if mins < 1 do mins = 1
	return mins
}

// Round-trip at average adult speed. Used by household-level search.
travel_minutes :: proc(cfg: Config, ax, ay, bx, by: i32) -> i32 {
	return walk_minutes(cfg, ax, ay, bx, by, BP_SCALE) * 2
}

clock_to_t :: proc(clock, day_minutes: i32) -> i32 {
	if day_minutes <= 0 {
		return 0
	}
	if clock <= 0 {
		return 0
	}
	if clock >= day_minutes {
		return 10000
	}
	return clock * 10000 / day_minutes
}

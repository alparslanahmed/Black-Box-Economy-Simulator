package sim

// Tunable economic constants. Authoritative simulation uses only these values
// plus the world seed — never frame time, never renderer state.
//
// Quantity: 1000 = 1 physical unit
// Basis points: 10000 = 100%
// Skill: 10000 = average (1.0x)
// Health: 10000 = full
// Time: integer minutes

QTY_SCALE :: i64(1000)
BP_SCALE :: i32(10_000)
SKILL_AVERAGE :: i32(10_000)
HEALTH_MAX :: i32(10_000)

MAP_W_DEFAULT :: i32(80)
MAP_H_DEFAULT :: i32(60)

HOUSEHOLDS_MIN :: i32(10)
HOUSEHOLDS_DEFAULT :: i32(40)
HOUSEHOLDS_UI_MAX :: i32(100)

LABOR_PER_DAY :: i32(600)
BLOCK_MINUTES :: i32(300)
BLOCKS_PER_DAY :: 2
DAY_MINUTES :: i32(1440)
SLEEP_BASE :: i32(480)
MAX_BOUTS :: i32(4)

DAYS_PER_MONTH :: i32(30)
DAYS_PER_YEAR :: i32(360)

EVENT_CAP :: 32768
METRICS_CAP :: 4096
EXCHANGE_CAP :: 2048
TRADE_MEMORY :: 10
LABOR_HISTORY_DAYS :: 30
DECISION_CANDIDATES :: 7
ENCOUNTERS_PER_DAY :: 3

GOOD_COUNT :: 5
SKILL_COUNT :: 5
PRODUCTIVE_ACTIVITY_COUNT :: 5
ROLE_COUNT :: 6

SPEAR_DURABILITY_MAX :: i32(100)

YEARS_INFANT :: i32(2)
YEARS_CHILD :: i32(12)
YEARS_YOUTH :: i32(16)
YEARS_ELDER :: i32(50)
YEARS_FERTILE_MIN :: i32(16)
YEARS_FERTILE_MAX :: i32(42)
PREGNANCY_DAYS :: i32(270)

Config :: struct {
	map_w: i32,
	map_h: i32,
	household_count: i32,

	labor_minutes:        i32, // adult cap on work + travel + visit
	block_minutes:        i32, // typical outdoor work stint, not including walking
	days_per_year:        i32,
	day_minutes:          i32,
	sleep_base:           i32,
	sleep_elder_extra:    i32,
	sleep_youth_extra:    i32,
	sleep_sick_extra:     i32,
	morning_home:         i32,
	visit_linger:         i32,
	max_bouts:            i32,
	max_visits_per_day:   i32,
	min_bout:             i32,
	travel_fatigue_after: i32,
	travel_fatigue_per:   i32,
	travel_score_per_min: i32,

	nutrition_per_day:    i64,
	fuel_per_day:         i64,
	berry_nutrition:      i64,
	meat_nutrition:       i64,
	berry_spoil_bp:       i32,
	meat_spoil_bp:        i32,

	health_recover:       i32,
	health_partial_food:  i32,
	health_no_food:       i32,
	health_no_fuel:       i32,

	forage_yield_per_min: i64,
	wood_yield_per_min:   i64,
	stone_yield_per_min:  i64,
	hunt_yield_no_spear:  i64,
	hunt_yield_spear:     i64,
	hunt_p_no_spear:      i32,
	hunt_p_spear:         i32,
	hunt_skill_p_scale:   i32,

	spear_durability_max:     i32,
	spear_durability_per_hunt: i32,
	craft_progress_needed:    i32,
	spear_wood_cost:          i64,
	spear_stone_cost:         i64,

	search_radius:        i32,
	minutes_per_cell:     i32, // one-way minutes at average adult walk speed
	encounters_per_day:   i32,
	trade_radius:         i32,
	memory_decay_bp:      i32,
	memory_gain_request:  i32,
	memory_gain_success:  i32,
	memory_gain_fail:     i32,

	skill_start_min:      i32,
	skill_start_max:      i32,
	skill_boost_min:      i32,
	skill_boost_max:      i32,
	skill_min:            i32,
	skill_max:            i32,
	learning_bp:          i32,

	preferred_food_days_min: i32, // milli-days, 1000 = 1 day
	preferred_food_days_max: i32,

	start_food_days_min:  i32,
	start_food_days_max:  i32,
	start_wood_min:       i64,
	start_wood_max:       i64,
	start_spear_chance_bp: i32,

	berry_regen_bp:       i32, // percent of max per day
	game_regen_bp:        i32,
	wood_regen_bp:        i32,

	specialization_role_bp: i32, // 5500 = 55%
	ratio_window_days:      i32,

	male_hunt_bonus_min:    i32,
	male_hunt_bonus_max:    i32,
	female_forage_bonus_min: i32,
	female_forage_bonus_max: i32,
	gender_side_bonus_min:  i32,
	gender_side_bonus_max:  i32,

	conceive_bp:            i32,
	pregnancy_days:         i32,
	max_members:            i32,
	age_frailty_start_year: i32,

	// Later these map onto "culture". They are just knobs for now.
	marry_age_male_min:     i32,
	marry_age_male_max:     i32,
	marry_age_female_min:   i32,
	marry_age_female_max:   i32,
	marry_bp:               i32, // per nearby encounter
	marry_radius:           i32,
	marry_encounters:       i32,
	marry_allow_cousins:    bool, // church/law can later set this false
	residence_father_bp:    i32, // patrilocal weight
	residence_mother_bp:    i32, // matrilocal
	residence_new_bp:       i32, // neolocal
	residence_crowd:        i32, // living members that push toward a new hut
	hut_wood_cost:          i64,
	hut_stone_cost:         i64,
}

default_config :: proc() -> Config {
	return Config{
		map_w = MAP_W_DEFAULT,
		map_h = MAP_H_DEFAULT,
		household_count = HOUSEHOLDS_DEFAULT,

		labor_minutes = LABOR_PER_DAY,
		block_minutes = BLOCK_MINUTES,
		days_per_year = DAYS_PER_YEAR,
		day_minutes = DAY_MINUTES,
		sleep_base = SLEEP_BASE,
		sleep_elder_extra = 60,
		sleep_youth_extra = 30,
		sleep_sick_extra = 90,
		morning_home = 90,
		visit_linger = 45,
		max_bouts = MAX_BOUTS,
		max_visits_per_day = 1,
		min_bout = 50,
		travel_fatigue_after = 160,
		travel_fatigue_per = 30,
		travel_score_per_min = 12,

		nutrition_per_day = 6 * QTY_SCALE,
		fuel_per_day = 250,
		berry_nutrition = 1 * QTY_SCALE,
		meat_nutrition = 2500,
		berry_spoil_bp = 1800,
		meat_spoil_bp = 2600,

		health_recover = 80,
		health_partial_food = -110,
		health_no_food = -260,
		health_no_fuel = -35,

		forage_yield_per_min = 18,
		wood_yield_per_min = 12,
		stone_yield_per_min = 10,
		hunt_yield_no_spear = 1800,
		hunt_yield_spear = 4000,
		hunt_p_no_spear = 4000,
		hunt_p_spear = 7600,
		hunt_skill_p_scale = 4000,

		spear_durability_max = SPEAR_DURABILITY_MAX,
		spear_durability_per_hunt = 10,
		craft_progress_needed = 300,
		spear_wood_cost = QTY_SCALE,
		spear_stone_cost = QTY_SCALE,

		search_radius = 14,
		minutes_per_cell = 5,
		encounters_per_day = ENCOUNTERS_PER_DAY,
		trade_radius = 22,
		memory_decay_bp = 800,
		memory_gain_request = 180,
		memory_gain_success = 320,
		memory_gain_fail = 90,

		skill_start_min = 7000,
		skill_start_max = 13000,
		skill_boost_min = 1000,
		skill_boost_max = 3000,
		skill_min = 5000,
		skill_max = 20000,
		learning_bp = 2,

		preferred_food_days_min = 3000,
		preferred_food_days_max = 6000,

		start_food_days_min = 2000,
		start_food_days_max = 4000,
		start_wood_min = 800,
		start_wood_max = 2500,
		start_spear_chance_bp = 2500,

		berry_regen_bp = 900,
		game_regen_bp = 280,
		wood_regen_bp = 110,

		specialization_role_bp = 5500,
		ratio_window_days = 30,

		male_hunt_bonus_min = 1600,
		male_hunt_bonus_max = 2800,
		female_forage_bonus_min = 1600,
		female_forage_bonus_max = 2800,
		gender_side_bonus_min = 400,
		gender_side_bonus_max = 1200,

		conceive_bp = 6,
		pregnancy_days = PREGNANCY_DAYS,
		max_members = MAX_MEMBERS,
		age_frailty_start_year = 55,

		marry_age_male_min = 18,
		marry_age_male_max = 55,
		marry_age_female_min = 16,
		marry_age_female_max = 48,
		marry_bp = 80,
		marry_radius = 18,
		marry_encounters = 2,
		marry_allow_cousins = true,
		residence_father_bp = 7000,
		residence_mother_bp = 1200,
		residence_new_bp = 1800,
		residence_crowd = 5,
		hut_wood_cost = 3500,
		hut_stone_cost = 1000,
	}
}

validate_config :: proc(cfg: Config) -> (ok: bool, err: string) {
	if cfg.map_w < 8 || cfg.map_h < 8 {
		return false, "map dimensions too small"
	}
	if cfg.map_w > 256 || cfg.map_h > 256 {
		return false, "map dimensions too large for this prototype"
	}
	if cfg.household_count < 1 {
		return false, "household count must be at least 1"
	}
	if cfg.household_count > 1000 {
		return false, "household count exceeds prototype safety cap (1000)"
	}
	if cfg.nutrition_per_day <= 0 || cfg.fuel_per_day <= 0 {
		return false, "daily needs must be positive"
	}
	if cfg.block_minutes <= 0 || cfg.labor_minutes <= 0 {
		return false, "labor minutes must be positive"
	}
	if cfg.day_minutes < 240 {
		return false, "day must have enough minutes"
	}
	if cfg.minutes_per_cell <= 0 {
		return false, "minutes per cell must be positive"
	}
	if cfg.max_bouts < 1 {
		return false, "max bouts must be at least 1"
	}
	return true, ""
}

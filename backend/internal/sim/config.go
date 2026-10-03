package sim

// Tunable economic constants. Authoritative simulation uses only these values
// plus the world seed — never frame time, never renderer state.
//
// Quantity: 1000 = 1 physical unit
// Basis points: 10000 = 100%
// Skill: 10000 = average (1.0x)
// Health: 10000 = full
// Time: integer minutes

const QTY_SCALE = 1000
const BP_SCALE = 10_000
const SKILL_AVERAGE = 10_000
const HEALTH_MAX = 10_000

const MAP_W_DEFAULT = 80
const MAP_H_DEFAULT = 60

const HOUSEHOLDS_MIN = 10
const HOUSEHOLDS_DEFAULT = 40
const HOUSEHOLDS_UI_MAX = 100

const LABOR_PER_DAY = 600
const BLOCK_MINUTES = 300
const BLOCKS_PER_DAY = 2
const DAY_MINUTES = 1440
const SLEEP_BASE = 480
const MAX_BOUTS = 4

const DAYS_PER_MONTH = 30
const DAYS_PER_YEAR = 360

const EVENT_CAP = 32768
const METRICS_CAP = 4096
const EXCHANGE_CAP = 2048
const TRADE_MEMORY = 10
const LABOR_HISTORY_DAYS = 30
const DECISION_CANDIDATES = 7
const ENCOUNTERS_PER_DAY = 3

const GOOD_COUNT = 5
const SKILL_COUNT = 5
const PRODUCTIVE_ACTIVITY_COUNT = 5
const ROLE_COUNT = 6

const SPEAR_DURABILITY_MAX = 100

const YEARS_INFANT = 2
const YEARS_CHILD = 12
const YEARS_YOUTH = 16
const YEARS_ELDER = 50
const YEARS_FERTILE_MIN = 16
const YEARS_FERTILE_MAX = 42
const PREGNANCY_DAYS = 270

type Config struct {
	MapW           i32 `json:"map_w"`
	MapH           i32 `json:"map_h"`
	HouseholdCount i32 `json:"household_count"`

	LaborMinutes       i32 `json:"labor_minutes"` // adult cap on work + travel + visit
	BlockMinutes       i32 `json:"block_minutes"` // typical outdoor work stint, not including walking
	DaysPerYear        i32 `json:"days_per_year"`
	DayMinutes         i32 `json:"day_minutes"`
	SleepBase          i32 `json:"sleep_base"`
	SleepElderExtra    i32 `json:"sleep_elder_extra"`
	SleepYouthExtra    i32 `json:"sleep_youth_extra"`
	SleepSickExtra     i32 `json:"sleep_sick_extra"`
	MorningHome        i32 `json:"morning_home"`
	VisitLinger        i32 `json:"visit_linger"`
	MaxBouts           i32 `json:"max_bouts"`
	MaxVisitsPerDay    i32 `json:"max_visits_per_day"`
	MinBout            i32 `json:"min_bout"`
	TravelFatigueAfter i32 `json:"travel_fatigue_after"`
	TravelFatiguePer   i32 `json:"travel_fatigue_per"`
	TravelScorePerMin  i32 `json:"travel_score_per_min"`

	NutritionPerDay i64 `json:"nutrition_per_day"`
	FuelPerDay      i64 `json:"fuel_per_day"`
	BerryNutrition  i64 `json:"berry_nutrition"`
	MeatNutrition   i64 `json:"meat_nutrition"`
	BerrySpoilBp    i32 `json:"berry_spoil_bp"`
	MeatSpoilBp     i32 `json:"meat_spoil_bp"`

	HealthRecover     i32 `json:"health_recover"`
	HealthPartialFood i32 `json:"health_partial_food"`
	HealthNoFood      i32 `json:"health_no_food"`
	HealthNoFuel      i32 `json:"health_no_fuel"`

	ForageYieldPerMin i64 `json:"forage_yield_per_min"`
	WoodYieldPerMin   i64 `json:"wood_yield_per_min"`
	StoneYieldPerMin  i64 `json:"stone_yield_per_min"`
	HuntYieldNoSpear  i64 `json:"hunt_yield_no_spear"`
	HuntYieldSpear    i64 `json:"hunt_yield_spear"`
	HuntPNoSpear      i32 `json:"hunt_p_no_spear"`
	HuntPSpear        i32 `json:"hunt_p_spear"`
	HuntSkillPScale   i32 `json:"hunt_skill_p_scale"`

	SpearDurabilityMax     i32 `json:"spear_durability_max"`
	SpearDurabilityPerHunt i32 `json:"spear_durability_per_hunt"`
	CraftProgressNeeded    i32 `json:"craft_progress_needed"`
	SpearWoodCost          i64 `json:"spear_wood_cost"`
	SpearStoneCost         i64 `json:"spear_stone_cost"`

	SearchRadius      i32 `json:"search_radius"`
	MinutesPerCell    i32 `json:"minutes_per_cell"` // one-way minutes at average adult walk speed
	EncountersPerDay  i32 `json:"encounters_per_day"`
	TradeRadius       i32 `json:"trade_radius"`
	MemoryDecayBp     i32 `json:"memory_decay_bp"`
	MemoryGainRequest i32 `json:"memory_gain_request"`
	MemoryGainSuccess i32 `json:"memory_gain_success"`
	MemoryGainFail    i32 `json:"memory_gain_fail"`

	SkillStartMin i32 `json:"skill_start_min"`
	SkillStartMax i32 `json:"skill_start_max"`
	SkillBoostMin i32 `json:"skill_boost_min"`
	SkillBoostMax i32 `json:"skill_boost_max"`
	SkillMin      i32 `json:"skill_min"`
	SkillMax      i32 `json:"skill_max"`
	LearningBp    i32 `json:"learning_bp"`

	PreferredFoodDaysMin i32 `json:"preferred_food_days_min"` // milli-days, 1000 = 1 day
	PreferredFoodDaysMax i32 `json:"preferred_food_days_max"`

	StartFoodDaysMin   i32 `json:"start_food_days_min"`
	StartFoodDaysMax   i32 `json:"start_food_days_max"`
	StartWoodMin       i64 `json:"start_wood_min"`
	StartWoodMax       i64 `json:"start_wood_max"`
	StartSpearChanceBp i32 `json:"start_spear_chance_bp"`

	BerryRegenBp i32 `json:"berry_regen_bp"` // percent of max per day
	GameRegenBp  i32 `json:"game_regen_bp"`
	WoodRegenBp  i32 `json:"wood_regen_bp"`

	SpecializationRoleBp i32 `json:"specialization_role_bp"` // 5500 = 55%
	RatioWindowDays      i32 `json:"ratio_window_days"`

	MaleHuntBonusMin     i32 `json:"male_hunt_bonus_min"`
	MaleHuntBonusMax     i32 `json:"male_hunt_bonus_max"`
	FemaleForageBonusMin i32 `json:"female_forage_bonus_min"`
	FemaleForageBonusMax i32 `json:"female_forage_bonus_max"`
	GenderSideBonusMin   i32 `json:"gender_side_bonus_min"`
	GenderSideBonusMax   i32 `json:"gender_side_bonus_max"`

	ConceiveBp          i32 `json:"conceive_bp"`
	PregnancyDays       i32 `json:"pregnancy_days"`
	MaxMembers          i32 `json:"max_members"`
	AgeFrailtyStartYear i32 `json:"age_frailty_start_year"`

	// Later these map onto "culture". They are just knobs for now.
	MarryAgeMaleMin   i32  `json:"marry_age_male_min"`
	MarryAgeMaleMax   i32  `json:"marry_age_male_max"`
	MarryAgeFemaleMin i32  `json:"marry_age_female_min"`
	MarryAgeFemaleMax i32  `json:"marry_age_female_max"`
	MarryBp           i32  `json:"marry_bp"` // per nearby encounter
	MarryRadius       i32  `json:"marry_radius"`
	MarryEncounters   i32  `json:"marry_encounters"`
	MarryAllowCousins bool `json:"marry_allow_cousins"` // church/law can later set this false
	ResidenceFatherBp i32  `json:"residence_father_bp"` // patrilocal weight
	ResidenceMotherBp i32  `json:"residence_mother_bp"` // matrilocal
	ResidenceNewBp    i32  `json:"residence_new_bp"`    // neolocal
	ResidenceCrowd    i32  `json:"residence_crowd"`     // living members that push toward a new hut
	HutWoodCost       i64  `json:"hut_wood_cost"`
	HutStoneCost      i64  `json:"hut_stone_cost"`
}

func DefaultConfig() Config {
	return Config{
		MapW:           MAP_W_DEFAULT,
		MapH:           MAP_H_DEFAULT,
		HouseholdCount: HOUSEHOLDS_DEFAULT,

		LaborMinutes:       LABOR_PER_DAY,
		BlockMinutes:       BLOCK_MINUTES,
		DaysPerYear:        DAYS_PER_YEAR,
		DayMinutes:         DAY_MINUTES,
		SleepBase:          SLEEP_BASE,
		SleepElderExtra:    60,
		SleepYouthExtra:    30,
		SleepSickExtra:     90,
		MorningHome:        90,
		VisitLinger:        45,
		MaxBouts:           MAX_BOUTS,
		MaxVisitsPerDay:    1,
		MinBout:            50,
		TravelFatigueAfter: 160,
		TravelFatiguePer:   30,
		TravelScorePerMin:  12,

		NutritionPerDay: 6 * QTY_SCALE,
		FuelPerDay:      250,
		BerryNutrition:  1 * QTY_SCALE,
		MeatNutrition:   2500,
		BerrySpoilBp:    1800,
		MeatSpoilBp:     2600,

		HealthRecover:     80,
		HealthPartialFood: -110,
		HealthNoFood:      -260,
		HealthNoFuel:      -35,

		ForageYieldPerMin: 18,
		WoodYieldPerMin:   12,
		StoneYieldPerMin:  10,
		HuntYieldNoSpear:  1800,
		HuntYieldSpear:    4000,
		HuntPNoSpear:      4000,
		HuntPSpear:        7600,
		HuntSkillPScale:   4000,

		SpearDurabilityMax:     SPEAR_DURABILITY_MAX,
		SpearDurabilityPerHunt: 10,
		CraftProgressNeeded:    300,
		SpearWoodCost:          QTY_SCALE,
		SpearStoneCost:         QTY_SCALE,

		SearchRadius:      14,
		MinutesPerCell:    5,
		EncountersPerDay:  ENCOUNTERS_PER_DAY,
		TradeRadius:       22,
		MemoryDecayBp:     800,
		MemoryGainRequest: 180,
		MemoryGainSuccess: 320,
		MemoryGainFail:    90,

		SkillStartMin: 7000,
		SkillStartMax: 13000,
		SkillBoostMin: 1000,
		SkillBoostMax: 3000,
		SkillMin:      5000,
		SkillMax:      20000,
		LearningBp:    2,

		PreferredFoodDaysMin: 3000,
		PreferredFoodDaysMax: 6000,

		StartFoodDaysMin:   2000,
		StartFoodDaysMax:   4000,
		StartWoodMin:       800,
		StartWoodMax:       2500,
		StartSpearChanceBp: 2500,

		BerryRegenBp: 900,
		GameRegenBp:  280,
		WoodRegenBp:  110,

		SpecializationRoleBp: 5500,
		RatioWindowDays:      30,

		MaleHuntBonusMin:     1600,
		MaleHuntBonusMax:     2800,
		FemaleForageBonusMin: 1600,
		FemaleForageBonusMax: 2800,
		GenderSideBonusMin:   400,
		GenderSideBonusMax:   1200,

		ConceiveBp:          6,
		PregnancyDays:       PREGNANCY_DAYS,
		MaxMembers:          MAX_MEMBERS,
		AgeFrailtyStartYear: 55,

		MarryAgeMaleMin:   18,
		MarryAgeMaleMax:   55,
		MarryAgeFemaleMin: 16,
		MarryAgeFemaleMax: 48,
		MarryBp:           80,
		MarryRadius:       18,
		MarryEncounters:   2,
		MarryAllowCousins: true,
		ResidenceFatherBp: 7000,
		ResidenceMotherBp: 1200,
		ResidenceNewBp:    1800,
		ResidenceCrowd:    5,
		HutWoodCost:       3500,
		HutStoneCost:      1000,
	}
}

func ValidateConfig(Cfg Config) (ok bool, err string) {
	if Cfg.MapW < 8 || Cfg.MapH < 8 {
		return false, "map dimensions too small"
	}
	if Cfg.MapW > 256 || Cfg.MapH > 256 {
		return false, "map dimensions too large for this prototype"
	}
	if Cfg.HouseholdCount < 1 {
		return false, "household count must be at least 1"
	}
	if Cfg.HouseholdCount > 1000 {
		return false, "household count exceeds prototype safety cap (1000)"
	}
	if Cfg.HouseholdCount > Cfg.MapW*Cfg.MapH {
		return false, "households exceed available map cells"
	}
	if Cfg.DaysPerYear <= 0 || Cfg.PregnancyDays <= 0 {
		return false, "year and pregnancy lengths must be positive"
	}
	if Cfg.MaxMembers < 2 || Cfg.MaxMembers > MAX_MEMBERS {
		return false, "household member limit must be between 2 and MAX_MEMBERS"
	}
	if Cfg.SpearDurabilityMax <= 0 || Cfg.SpearDurabilityPerHunt <= 0 || Cfg.CraftProgressNeeded <= 0 {
		return false, "tool durability and craft requirements must be positive"
	}
	if Cfg.BerryNutrition <= 0 || Cfg.MeatNutrition <= 0 || Cfg.RatioWindowDays <= 0 {
		return false, "nutrition values and ratio window must be positive"
	}
	if Cfg.NutritionPerDay <= 0 || Cfg.FuelPerDay <= 0 {
		return false, "daily needs must be positive"
	}
	if Cfg.BlockMinutes <= 0 || Cfg.LaborMinutes <= 0 {
		return false, "labor minutes must be positive"
	}
	if Cfg.DayMinutes < 240 {
		return false, "day must have enough minutes"
	}
	if Cfg.MinutesPerCell <= 0 {
		return false, "minutes per cell must be positive"
	}
	if Cfg.MaxBouts < 1 {
		return false, "max bouts must be at least 1"
	}
	return true, ""
}

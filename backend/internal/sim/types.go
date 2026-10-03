package sim

type Good = int

const (
	Berries = 0
	Meat    = 1
	Wood    = 2
	Stone   = 3
	Spear   = 4
)

type Activity = int

const (
	Forage       = 0
	Hunt         = 1
	Gather_Wood  = 2
	Gather_Stone = 3
	Craft_Spear  = 4
	Rest         = 5
	Visit        = 6
)

type SkillKind = int

const (
	Craft = 4
)

type Terrain = int

const (
	Meadow = 0
	Forest = 1
	Rocky  = 2
)

type ResourceKind = int

const (
	Berry = 0
	Game  = 1
)

type Role = int

const (
	Generalist     = 0
	Forager        = 1
	Hunter         = 2
	Wood_Gatherer  = 3
	Stone_Gatherer = 4
	Toolmaker      = 5
)

type TradeFail = int

const (
	None                   = 0
	No_Double_Coincidence  = 1
	No_Mutual_Gain         = 2
	Insufficient_Inventory = 3
	Dead_Or_Disabled       = 4
)

type EventKind = int

const (
	Work_Completed         = 0
	Hunt_Succeeded         = 1
	Hunt_Failed            = 2
	Resource_Depleted      = 3
	Spear_Crafted          = 4
	Spear_Broke            = 5
	Trade_Completed        = 6
	Trade_Failed           = 7
	Food_Spoiled           = 8
	Hunger                 = 9
	Household_Died         = 10
	Specialization_Changed = 11
	Person_Born            = 12
	Person_Died            = 13
	Married                = 14
	Household_Founded      = 15
)

type Residence = int

const (
	Father = 0
	Mother = 1
	New    = 2
)

type Sex = int

const (
	Male   = 0
	Female = 1
)

type LifeStage = int

const (
	Infant = 0
	Child  = 1
	Youth  = 2
	Adult  = 3
	Elder  = 4
)

const PATH_MAX = 32
const MAX_MEMBERS = 8

type PersonDoing = int

const (
	Sleep    = 0
	At_Home  = 1
	Walking  = 2
	Working  = 3
	Visiting = 4
)

type PathPt struct {
	X        i32         `json:"x"` // milli-cells
	Y        i32         `json:"y"` // milli-cells
	T        i32         `json:"t"` // 0..10_000 through the day
	Doing    PersonDoing `json:"doing"`
	Activity Activity    `json:"activity"`
}

type Person struct {
	Id           i32  `json:"id"`
	Household    i32  `json:"household"`
	Sex          Sex  `json:"sex"`
	Alive        bool `json:"alive"`
	AgeDays      i32  `json:"age_days"`
	Health       i32  `json:"health"`
	Constitution i32  `json:"constitution"` // inherited baseline, 10000 = average

	Skills [SKILL_COUNT]i32 `json:"skills"`

	Pregnant          bool `json:"pregnant"`
	PregnancyDays     i32  `json:"pregnancy_days"`
	PregFoodDaysAcc   i64  `json:"preg_food_days_acc"` // sum of household food-days-milli
	PregDaysCounted   i32  `json:"preg_days_counted"`
	PregnancyFatherId i32  `json:"pregnancy_father_id"` // biological father captured at conception
	FatherId          i32  `json:"father_id"`
	MotherId          i32  `json:"mother_id"`
	SpouseId          i32  `json:"spouse_id"` // -1 if no living marriage
	NatalHousehold    i32  `json:"natal_household"`

	IntentActivity Activity `json:"intent_activity"`
	IntentCell     Vec2i    `json:"intent_cell"`
	IntentPartner  i32      `json:"intent_partner"` // household id for Visit, else -1
	LastDecision   Decision `json:"last_decision"`
	BlocksThisDay  i32      `json:"blocks_this_day"`

	Clock         i32 `json:"clock"` // minute of the current day while planning
	WakeMin       i32 `json:"wake_min"`
	SleepStart    i32 `json:"sleep_start"`
	MinutesSleep  i32 `json:"minutes_sleep"`
	MinutesHome   i32 `json:"minutes_home"`
	MinutesWork   i32 `json:"minutes_work"`
	MinutesTravel i32 `json:"minutes_travel"`
	MinutesVisit  i32 `json:"minutes_visit"`
	VisitsToday   i32 `json:"visits_today"`

	Path    [PATH_MAX]PathPt `json:"path"`
	PathN   i32              `json:"path_n"`
	TradeHh i32              `json:"trade_hh"` // -1 none; partner household visited today
}

type OverlayKind = int

const (
	Normal         = 0
	Resources      = 1
	Trade          = 2
	Specialization = 3
	Food_Security  = 4
)

type Vec2i struct {
	X i32 `json:"x"`
	Y i32 `json:"y"`
}

type Inventory struct {
	Qty [GOOD_COUNT]i64 `json:"qty"`
}

type Cell struct {
	Terrain    Terrain `json:"terrain"`
	BerryStock i64     `json:"berry_stock"`
	BerryMax   i64     `json:"berry_max"`
	BerryRegen i64     `json:"berry_regen"`
	GameStock  i64     `json:"game_stock"`
	GameMax    i64     `json:"game_max"`
	GameRegen  i64     `json:"game_regen"`
	WoodStock  i64     `json:"wood_stock"`
	WoodMax    i64     `json:"wood_max"`
	WoodRegen  i64     `json:"wood_regen"`
	StoneStock i64     `json:"stone_stock"`
	StoneMax   i64     `json:"stone_max"`
	Extracted  [4]i64  `json:"extracted"` // berry, game, wood, stone today
}

type DecisionCandidate struct {
	Activity       Activity `json:"activity"`
	TotalScore     i64      `json:"total_score"`
	FoodNeed       i64      `json:"food_need"`
	FuelNeed       i64      `json:"fuel_need"`
	Tool           i64      `json:"tool"`
	Input          i64      `json:"input"`
	TradeDemand    i64      `json:"trade_demand"`
	Skill          i64      `json:"skill"`
	Travel         i64      `json:"travel"`
	Risk           i64      `json:"risk"`
	TargetCell     Vec2i    `json:"target_cell"`
	ExpectedOutput i64      `json:"expected_output"`
	Feasible       bool     `json:"feasible"`
	Partner        i32      `json:"partner"`  // household id for Visit, else -1
	WorkMin        i32      `json:"work_min"` // labor, linger, or rest minutes planned for this bout
}

type Decision struct {
	Chosen         Activity                               `json:"chosen"`
	ChosenIndex    i32                                    `json:"chosen_index"`
	Candidates     [DECISION_CANDIDATES]DecisionCandidate `json:"candidates"`
	CandidateCount i32                                    `json:"candidate_count"`
}

type TradeRecord struct {
	Day      i32       `json:"day"`
	Partner  i32       `json:"partner"`
	GaveGood Good      `json:"gave_good"`
	GotGood  Good      `json:"got_good"`
	GaveQty  i64       `json:"gave_qty"`
	GotQty   i64       `json:"got_qty"`
	Success  bool      `json:"success"`
	Fail     TradeFail `json:"fail"`
}

type Exchange struct {
	Day i32  `json:"day"`
	G0  Good `json:"g0"`
	G1  Good `json:"g1"`
	Q0  i64  `json:"q0"`
	Q1  i64  `json:"q1"`
	H0  i32  `json:"h0"`
	H1  i32  `json:"h1"`
}

type Event struct {
	Day      i32       `json:"day"`
	Kind     EventKind `json:"kind"`
	H1       i32       `json:"h1"`
	H2       i32       `json:"h2"`
	GoodA    Good      `json:"good_a"`
	GoodB    Good      `json:"good_b"`
	QtyA     i64       `json:"qty_a"`
	QtyB     i64       `json:"qty_b"`
	Cell     Vec2i     `json:"cell"`
	Activity Activity  `json:"activity"`
	Fail     TradeFail `json:"fail"`
	Role     Role      `json:"role"`
}

type EventBuf struct {
	Items [EVENT_CAP]Event `json:"items"`
	Head  u32              `json:"head"`
	Count u32              `json:"count"`
}

type ExchangeBuf struct {
	Items [EXCHANGE_CAP]Exchange `json:"items"`
	Head  u32                    `json:"head"`
	Count u32                    `json:"count"`
}

type DayMetrics struct {
	Day                     i32              `json:"day"`
	Year                    i32              `json:"year"`
	Alive                   i32              `json:"alive"` // living people
	AliveHouseholds         i32              `json:"alive_households"`
	Births                  i32              `json:"births"`
	Marriages               i32              `json:"marriages"`
	Unmarried               i32              `json:"unmarried"`    // living, no living spouse
	UnmarriedBp             i32              `json:"unmarried_bp"` // of living people
	UnmarriedMarriageable   i32              `json:"unmarried_marriageable"`
	UnmarriedMarriageableBp i32              `json:"unmarried_marriageable_bp"` // of living marriageable people
	FertileWomen            i32              `json:"fertile_women"`
	CbrMilli                i32              `json:"cbr_milli"`       // crude birth rate; 28000 = 28.0 births per 1000 people per year
	TfrMilli                i32              `json:"tfr_milli"`       // total fertility; 2100 = 2.10 children per woman
	BirthRateDays           i32              `json:"birth_rate_days"` // trailing window used for CBR/TFR
	FoodTotal               i64              `json:"food_total"`
	FoodDaysAvgMilli        i64              `json:"food_days_avg_milli"`
	MedianHealth            i32              `json:"median_health"`
	Produced                [GOOD_COUNT]i64  `json:"produced"`
	TradeAttempts           i32              `json:"trade_attempts"`
	SuccessfulTrades        i32              `json:"successful_trades"`
	TradeSuccessBp          i32              `json:"trade_success_bp"`
	FailNoDc                i32              `json:"fail_no_dc"`
	FailNoGain              i32              `json:"fail_no_gain"`
	FailInv                 i32              `json:"fail_inv"`
	BarterQtyTotal          i64              `json:"barter_qty_total"`
	SpecAvgBp               i32              `json:"spec_avg_bp"`
	RoleCounts              [ROLE_COUNT]i32  `json:"role_counts"`
	Hungry                  i32              `json:"hungry"`
	Deaths                  i32              `json:"deaths"`
	Visits                  i32              `json:"visits"`
	TravelMinutesTotal      i32              `json:"travel_minutes_total"`
	FoodSpoiled             i64              `json:"food_spoiled"`
	ResourceStock           [4]i64           `json:"resource_stock"`
	SpearOwnBp              i32              `json:"spear_own_bp"`
	AvgSkill                [SKILL_COUNT]i32 `json:"avg_skill"`
	BerriesPerUnit          [GOOD_COUNT]i64  `json:"berries_per_unit"` // QTY_SCALE = 1.0 berries per 1 unit; -1 = N/A
	UnitPerBerry            [GOOD_COUNT]i64  `json:"unit_per_berry"`   // for CSV *per_berry columns; -1 = N/A
}

type MetricsBuf struct {
	Items [METRICS_CAP]DayMetrics `json:"items"`
	Head  u32                     `json:"head"`
	Count u32                     `json:"count"`
}

type DayAcc struct {
	Produced           [GOOD_COUNT]i64 `json:"produced"`
	TradeAttempts      i32             `json:"trade_attempts"`
	SuccessfulTrades   i32             `json:"successful_trades"`
	FailNoDc           i32             `json:"fail_no_dc"`
	FailNoGain         i32             `json:"fail_no_gain"`
	FailInv            i32             `json:"fail_inv"`
	BarterQtyTotal     i64             `json:"barter_qty_total"`
	FoodSpoiled        i64             `json:"food_spoiled"`
	Deaths             i32             `json:"deaths"`
	Hungry             i32             `json:"hungry"`
	Births             i32             `json:"births"`
	Marriages          i32             `json:"marriages"`
	Visits             i32             `json:"visits"`
	TravelMinutesTotal i32             `json:"travel_minutes_total"`
}

type Household struct {
	Id         i32   `json:"id"`
	Exists     bool  `json:"exists"` // slot allocated (new camps reuse empty slots)
	Alive      bool  `json:"alive"`
	Home       Vec2i `json:"home"`
	HutVariant u8    `json:"hut_variant"`
	Health     i32   `json:"health"` // average of living members, overlay/analytics

	Members     [MAX_MEMBERS]i32 `json:"members"`
	MemberCount i32              `json:"member_count"`

	Inv             Inventory `json:"inv"`
	SpearDurability i32       `json:"spear_durability"`
	SpareSpears     []i32     `json:"spare_spears"` // individual durability; last spare is used/sold next

	Skills [SKILL_COUNT]i32 `json:"skills"` // average of working-age members

	PreferredFoodNutrition i64 `json:"preferred_food_nutrition"`
	PrefDaysMilli          i32 `json:"pref_days_milli"`
	TradeOpenness          i32 `json:"trade_openness"`
	RiskPreference         i32 `json:"risk_preference"`

	CraftProgress i32 `json:"craft_progress"`

	ObservedDemand [GOOD_COUNT]i32 `json:"observed_demand"`

	LaborHist    [LABOR_HISTORY_DAYS][SKILL_COUNT]i32 `json:"labor_hist"`
	LaborHistIdx i32                                  `json:"labor_hist_idx"`
	LaborToday   [SKILL_COUNT]i32                     `json:"labor_today"`

	RecentTrades     [TRADE_MEMORY]TradeRecord `json:"recent_trades"`
	RecentTradeCount i32                       `json:"recent_trade_count"`
	RecentTradeHead  i32                       `json:"recent_trade_head"`

	LastDecision   Decision `json:"last_decision"`
	IntentActivity Activity `json:"intent_activity"`
	IntentCell     Vec2i    `json:"intent_cell"`
	VisitsToday    i32      `json:"visits_today"`

	InferredRole     Role `json:"inferred_role"`
	PrevInferredRole Role `json:"prev_inferred_role"`
	SpecializationBp i32  `json:"specialization_bp"`

	LastFoodNutrition i64 `json:"last_food_nutrition"`
}

type World struct {
	Seed              u64    `json:"seed"`
	Rng               RNG    `json:"rng"`
	Day               i32    `json:"day"`
	Cfg               Config `json:"cfg"`
	TradeEnabled      bool   `json:"trade_enabled"`
	BerryRegenScaleBp i32    `json:"berry_regen_scale_bp"` // 10000 = as configured

	Cells       []Cell      `json:"cells"`
	Households  []Household `json:"households"`
	People      []Person    `json:"people"`
	PersonCount i32         `json:"person_count"`
	Order       []i32       `json:"order"`
	PersonOrder []i32       `json:"person_order"`

	Events    EventBuf    `json:"events"`
	Metrics   MetricsBuf  `json:"metrics"`
	Exchanges ExchangeBuf `json:"exchanges"`
	Acc       DayAcc      `json:"acc"`

	TotalDeaths    i32 `json:"total_deaths"`
	TotalMarriages i32 `json:"total_marriages"`
}

func ActivityIsProductive(a Activity) bool {
	return a != Rest && a != Visit
}

func ActivityToSkill(a Activity) (SkillKind, bool) {
	if a == Rest || a == Visit {
		return Forage, false
	}
	return SkillKind(u8(a)), true
}

func ActivityOutputGood(a Activity) (Good, bool) {
	switch a {
	case Forage:
		return Berries, true
	case Hunt:
		return Meat, true
	case Gather_Wood:
		return Wood, true
	case Gather_Stone:
		return Stone, true
	case Craft_Spear:
		return Spear, true
	case Rest, Visit:
		return Berries, false
	}
	return Berries, false
}

func ActivityResource(a Activity) (ResourceKind, bool) {
	switch a {
	case Forage:
		return Berry, true
	case Hunt:
		return Game, true
	case Gather_Wood:
		return Wood, true
	case Gather_Stone:
		return Stone, true
	case Craft_Spear, Rest, Visit:
		return Berry, false
	}
	return Berry, false
}

func RoleFromActivity(a Activity) Role {
	switch a {
	case Forage:
		return Forager
	case Hunt:
		return Hunter
	case Gather_Wood:
		return Wood_Gatherer
	case Gather_Stone:
		return Stone_Gatherer
	case Craft_Spear:
		return Toolmaker
	case Rest, Visit:
		return Generalist
	}
	return Generalist
}

func GoodName(g Good) string {
	switch g {
	case Berries:
		return "berries"
	case Meat:
		return "meat"
	case Wood:
		return "wood"
	case Stone:
		return "stone"
	case Spear:
		return "spear"
	}
	return "?"
}

func ActivityName(a Activity) string {
	switch a {
	case Forage:
		return "Forage"
	case Hunt:
		return "Hunt"
	case Gather_Wood:
		return "Gather wood"
	case Gather_Stone:
		return "Gather stone"
	case Craft_Spear:
		return "Craft spear"
	case Rest:
		return "Rest"
	case Visit:
		return "Visit neighbor"
	}
	return "?"
}

func PersonNowLabel(Doing PersonDoing, Activity Activity, walking bool) string {
	if walking {
		switch Activity {
		case Forage:
			return "Walking to forage"
		case Hunt:
			return "Walking to hunt"
		case Gather_Wood:
			return "Walking to gather wood"
		case Gather_Stone:
			return "Walking to gather stone"
		case Craft_Spear:
			return "Walking home"
		case Rest:
			return "Walking home"
		case Visit:
			return "Walking to a neighbor"
		}
		return "Walking"
	}
	switch Doing {
	case Sleep:
		return "Sleeping"
	case At_Home:
		return "At home"
	case Walking:
		return "Walking"
	case Working:
		return ActivityName(Activity)
	case Visiting:
		return "Visiting a neighbor"
	}
	return "?"
}

func RoleName(r Role) string {
	switch r {
	case Generalist:
		return "Generalist"
	case Forager:
		return "Forager"
	case Hunter:
		return "Hunter"
	case Wood_Gatherer:
		return "Wood Gatherer"
	case Stone_Gatherer:
		return "Stone Gatherer"
	case Toolmaker:
		return "Toolmaker"
	}
	return "?"
}

func TerrainName(T Terrain) string {
	switch T {
	case Meadow:
		return "Meadow"
	case Forest:
		return "Forest"
	case Rocky:
		return "Rocky"
	}
	return "?"
}

func ClampI32(V i32, lo i32, hi i32) i32 {
	if V < lo {
		return lo
	}
	if V > hi {
		return hi
	}
	return V
}

func ClampI64(V i64, lo i64, hi i64) i64 {
	if V < lo {
		return lo
	}
	if V > hi {
		return hi
	}
	return V
}

func AbsI32(V i32) i32 {
	if V < 0 {
		return -V
	}
	return V
}

func OctileMilli(ax i32, ay i32, bx i32, by i32) i32 {
	dx := AbsI32(ax - bx)
	dy := AbsI32(ay - by)
	mn := min(dx, dy)
	mx := max(dx, dy)
	return 1414*mn + 1000*(mx-mn)
}

// One-way walk time in minutes at the given speed (10000 = average adult).
func WalkMinutes(Cfg Config, ax i32, ay i32, bx i32, by i32, speed_bp i32) i32 {
	milli := OctileMilli(ax, ay, bx, by)
	if milli <= 0 {
		return 0
	}
	sp := speed_bp
	if sp < 4000 {
		sp = 4000
	}
	if sp > 14000 {
		sp = 14000
	}
	mins := milli * Cfg.MinutesPerCell * 10000 / (1000 * sp)
	if mins < 1 {
		mins = 1
	}
	return mins
}

// Round-trip at average adult speed. Used by household-level search.
func TravelMinutes(Cfg Config, ax i32, ay i32, bx i32, by i32) i32 {
	return WalkMinutes(Cfg, ax, ay, bx, by, BP_SCALE) * 2
}

func ClockToT(Clock i32, DayMinutes i32) i32 {
	if DayMinutes <= 0 {
		return 0
	}
	if Clock <= 0 {
		return 0
	}
	if Clock >= DayMinutes {
		return 10000
	}
	return Clock * 10000 / DayMinutes
}

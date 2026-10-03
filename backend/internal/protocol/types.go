// Package protocol is the single source of truth for the WebSocket contract.
// Run go generate ./... to regenerate the frontend TypeScript definitions.
package protocol

import "blackbox/internal/sim"

//go:generate go run ../../../cmd/typegen

const Version = 1

type ViewState struct {
	Overlay           string  `json:"overlay"`
	SelectedHousehold int     `json:"selected_household"`
	SelectedPerson    int     `json:"selected_person"`
	InspectorTab      string  `json:"inspector_tab"`
	Panel             string  `json:"panel"`
	CameraX           float64 `json:"camera_x"`
	CameraY           float64 `json:"camera_y"`
	Zoom              float64 `json:"zoom"`
	SelectedCell      *int    `json:"selected_cell,omitempty"`
	ResourceKind      int     `json:"resource_kind,omitempty"`
}

type Runtime struct {
	Paused bool      `json:"paused"`
	Speed  float64   `json:"speed"`
	View   ViewState `json:"view"`
}

type Command struct {
	Type         string     `json:"type"`
	RequestID    string     `json:"request_id"`
	Seed         string     `json:"seed,omitempty"`
	Households   int        `json:"households,omitempty"`
	WorldID      string     `json:"world_id,omitempty"`
	Days         int        `json:"days,omitempty"`
	Speed        *float64   `json:"speed,omitempty"`
	Trade        *bool      `json:"trade,omitempty"`
	BerryRegenBP *int       `json:"berry_regen_bp,omitempty"`
	View         *ViewState `json:"view,omitempty"`
	Before       uint64     `json:"before,omitempty"`
	Category     string     `json:"category,omitempty"`
}

type Tile struct {
	Terrain  int      `json:"terrain"`
	Stock    [4]int64 `json:"stock"`
	Capacity [4]int64 `json:"capacity"`
	Regen    [4]int64 `json:"regen"`
}

type HouseholdView struct {
	Data      sim.Household `json:"data"`
	Name      string        `json:"name"`
	Role      string        `json:"role"`
	FoodDays  int64         `json:"food_days"`
	DailyNeed int64         `json:"daily_need"`
	FuelNeed  int64         `json:"fuel_need"`
	Events    []EventView   `json:"events"`
}

type PersonView struct {
	Data      sim.Person   `json:"data"`
	Label     string       `json:"label"`
	Stage     string       `json:"stage"`
	Age       int          `json:"age"`
	WorkCap   int          `json:"work_cap"`
	ViewPath  []sim.PathPt `json:"view_path"`
	ViewTimes []float32    `json:"view_times"`
}

type EventView struct {
	Data       sim.Event `json:"data"`
	Text       string    `json:"text"`
	Category   string    `json:"category"`
	Households []int     `json:"households"`
}

type EventPage struct {
	Items   []EventView `json:"items"`
	Before  uint64      `json:"before"`
	HasMore bool        `json:"has_more"`
}

type HistoryPage struct {
	Items   []sim.DayMetrics `json:"items"`
	Before  uint64           `json:"before"`
	HasMore bool             `json:"has_more"`
}

type WorldSummary struct {
	ID         string `json:"id"`
	Seed       string `json:"seed"`
	Day        int    `json:"day"`
	People     int    `json:"people"`
	Households int    `json:"households"`
	UpdatedAt  string `json:"updated_at"`
}

type Snapshot struct {
	WorldID        string           `json:"world_id"`
	Revision       uint64           `json:"revision"`
	Seed           string           `json:"seed"`
	Day            int              `json:"day"`
	Hash           string           `json:"hash"`
	Config         sim.Config       `json:"config"`
	Runtime        Runtime          `json:"runtime"`
	TradeEnabled   bool             `json:"trade_enabled"`
	BerryRegenBP   int              `json:"berry_regen_bp"`
	Cells          []Tile           `json:"cells"`
	Households     []HouseholdView  `json:"households"`
	People         []PersonView     `json:"people"`
	Metrics        sim.DayMetrics   `json:"metrics"`
	History        []sim.DayMetrics `json:"history"`
	Events         []EventView      `json:"events"`
	Exchanges      []sim.Exchange   `json:"exchanges"`
	ViewScale      float32          `json:"view_scale"`
	TotalDeaths    int              `json:"total_deaths"`
	TotalMarriages int              `json:"total_marriages"`
}

type Message struct {
	Version   int            `json:"version"`
	Type      string         `json:"type"`
	RequestID string         `json:"request_id,omitempty"`
	Error     string         `json:"error,omitempty"`
	Snapshot  *Snapshot      `json:"snapshot,omitempty"`
	Worlds    []WorldSummary `json:"worlds,omitempty"`
	CSV       string         `json:"csv,omitempty"`
	Events    *EventPage     `json:"events,omitempty"`
	History   *HistoryPage   `json:"history,omitempty"`
}

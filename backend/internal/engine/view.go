package engine

import (
	"blackbox/internal/protocol"
	"blackbox/internal/sim"
	"slices"
)

func validView(v protocol.ViewState, w *sim.World) bool {
	if v.ResourceKind < 0 || v.ResourceKind > 3 {
		return false
	}
	if !slices.Contains([]string{"overview", "resources", "trade", "households", "specialization", "terrain", "food"}, v.Overlay) {
		return false
	}
	if !slices.Contains([]string{"inventory", "skills", "trade", "details"}, v.InspectorTab) {
		return false
	}
	if v.SelectedPerson < -1 || v.SelectedPerson >= w.PersonCount || v.SelectedHousehold < -1 || v.SelectedHousehold >= len(w.Households) {
		return false
	}
	if v.SelectedHousehold >= 0 && !w.Households[v.SelectedHousehold].Exists {
		return false
	}
	return v.SelectedCell == nil || *v.SelectedCell >= 0 && *v.SelectedCell < len(w.Cells)
}

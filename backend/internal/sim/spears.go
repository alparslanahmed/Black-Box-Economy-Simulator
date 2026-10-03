package sim

// Quantity remains in Inventory. The active spear and every spare retain their
// own condition, including when two worn spears meet in the same household.
type SpearState struct {
	Active  i32 `json:"active"`
	Reserve i64 `json:"reserve"`
}

func SpearCondition(h *Household) SpearState {
	s := SpearState{Active: h.SpearDurability}
	for _, durability := range h.SpareSpears {
		s.Reserve += i64(durability)
	}
	return s
}

func SpearGivenCondition(h *Household, index int) i32 {
	if index < len(h.SpareSpears) {
		return h.SpareSpears[len(h.SpareSpears)-1-index]
	}
	return h.SpearDurability
}

func PreviewSpearTransfer(from *Household, to *Household, Qty i64) (giver SpearState, receiver SpearState) {
	giver = SpearCondition(from)
	if to != nil {
		receiver = SpearCondition(to)
	}
	units := int(Qty / QTY_SCALE)
	for i := 0; i < units; i++ {
		dur := SpearGivenCondition(from, i)
		if i < len(from.SpareSpears) {
			giver.Reserve -= i64(dur)
		} else {
			giver.Active = 0
		}
		if receiver.Active == 0 {
			receiver.Active = dur
		} else {
			receiver.Reserve += i64(dur)
		}
	}
	return
}

func ReceiveSpear(h *Household, durability i32) {
	assert(durability > 0)
	if SpearCount(h.Inv) == 0 {
		h.SpearDurability = durability
	} else {
		h.SpareSpears = append(h.SpareSpears, durability)
	}
	h.Inv.Qty[Spear] += QTY_SCALE
}

func TakeSpear(h *Household) i32 {
	assert(SpearCount(h.Inv) > 0)
	dur := h.SpearDurability
	if len(h.SpareSpears) > 0 {
		dur = pop(&h.SpareSpears)
	} else {
		h.SpearDurability = 0
	}
	h.Inv.Qty[Spear] -= QTY_SCALE
	return dur
}

func TransferGood(from *Household, to *Household, good Good, Qty i64) {
	assert(Qty > 0 && from.Inv.Qty[good] >= Qty)
	if good == Spear {
		assert(Qty%QTY_SCALE == 0)
		for iteration1 := 0; iteration1 < int(Qty/QTY_SCALE); iteration1++ {
			ReceiveSpear(to, TakeSpear(from))
		}
	} else {
		from.Inv.Qty[good] -= Qty
		to.Inv.Qty[good] += Qty
	}
}

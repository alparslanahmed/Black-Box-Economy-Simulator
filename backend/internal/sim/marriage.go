package sim

func HasLivingSpouse(w *World, p *Person) bool {
	if p == nil || p.SpouseId < 0 {
		return false
	}
	s := PersonAt(w, p.SpouseId)
	return s != nil && s.Alive
}

func IsMarriageable(w *World, p *Person) bool {
	if p == nil || !p.Alive || HasLivingSpouse(w, p) {
		return false
	}
	if p.Health < 4000 {
		return false
	}
	Y := AgeYears(p, w.Cfg.DaysPerYear)
	switch p.Sex {
	case Male:
		return Y >= w.Cfg.MarryAgeMaleMin && Y <= w.Cfg.MarryAgeMaleMax
	case Female:
		return Y >= w.Cfg.MarryAgeFemaleMin && Y <= w.Cfg.MarryAgeFemaleMax
	}
	return false
}

func ShareAParent(a *Person, b *Person) bool {
	if a == nil || b == nil || a.Id == b.Id {
		return false
	}
	if a.FatherId >= 0 && a.FatherId == b.FatherId {
		return true
	}
	if a.MotherId >= 0 && a.MotherId == b.MotherId {
		return true
	}
	return false
}

func IsParentChild(a *Person, b *Person) bool {
	if a == nil || b == nil {
		return false
	}
	return a.FatherId == b.Id || a.MotherId == b.Id || b.FatherId == a.Id || b.MotherId == a.Id
}

func IsAvuncular(w *World, a *Person, b *Person) bool {
	if w == nil || a == nil || b == nil {
		return false
	}
	Check := func(w *World, person *Person, maybe_uncle *Person) bool {
		if person == nil || maybe_uncle == nil {
			return false
		}
		fa := PersonAt(w, person.FatherId)
		if fa != nil && maybe_uncle.Id != fa.Id && ShareAParent(maybe_uncle, fa) {
			return true
		}
		mo := PersonAt(w, person.MotherId)
		if mo != nil && maybe_uncle.Id != mo.Id && ShareAParent(maybe_uncle, mo) {
			return true
		}
		return false
	}
	return Check(w, a, b) || Check(w, b, a)
}

func IsFirstCousin(w *World, a *Person, b *Person) bool {
	if w == nil || a == nil || b == nil || a.Id == b.Id {
		return false
	}
	pa := [2]*Person{PersonAt(w, a.FatherId), PersonAt(w, a.MotherId)}
	pb := [2]*Person{PersonAt(w, b.FatherId), PersonAt(w, b.MotherId)}
	for i := 0; i < 2; i++ {
		for j := 0; j < 2; j++ {
			X, Y := pa[i], pb[j]
			if X == nil || Y == nil || X.Id == Y.Id {
				continue
			}
			if ShareAParent(X, Y) {
				return true
			}
		}
	}
	return false
}

func IsAncestor(w *World, ancestor *Person, descendant *Person) bool {
	if ancestor == nil || descendant == nil {
		return false
	}
	// Parents are allocated before their children. This also bounds traversal
	// for malformed records rather than recursing indefinitely through a cycle.
	for _, Id := range [2]i32{descendant.FatherId, descendant.MotherId} {
		if Id == ancestor.Id {
			return true
		}
		if Id < 0 || Id >= descendant.Id {
			continue
		}
		if IsAncestor(w, ancestor, PersonAt(w, Id)) {
			return true
		}
	}
	return false
}

// Direct ancestors, siblings, and aunt/uncle–niece/nephew are always forbidden.
// First cousins follow marry_allow_cousins (later a church/law culture knob).
func AreCloseKin(w *World, a *Person, b *Person) bool {
	if a == nil || b == nil || a.Id == b.Id {
		return true
	}
	if IsParentChild(a, b) || IsAncestor(w, a, b) || IsAncestor(w, b, a) {
		return true
	}
	if ShareAParent(a, b) {
		return true
	}
	if IsAvuncular(w, a, b) {
		return true
	}
	if !w.Cfg.MarryAllowCousins && IsFirstCousin(w, a, b) {
		return true
	}
	return false
}

func LinkSpouses(a *Person, b *Person) {
	if a == nil || b == nil {
		return
	}
	a.SpouseId = b.Id
	b.SpouseId = a.Id
}

func RemoveMember(h *Household, pid i32) {
	var N i32 = 0
	for i := i32(0); i < h.MemberCount; i += 1 {
		if h.Members[i] != pid {
			h.Members[N] = h.Members[i]
			N += 1
		}
	}
	h.MemberCount = N
}

func AddMember(h *Household, pid i32) bool {
	if h.MemberCount >= MAX_MEMBERS {
		return false
	}
	h.Members[h.MemberCount] = pid
	h.MemberCount += 1
	return true
}

func CanHost(w *World, h *Household, extra i32) bool {
	if h == nil || !h.Exists {
		return false
	}
	if !h.Alive && LivingMembers(w, h) == 0 {
		return false
	}
	return LivingMembers(w, h)+extra <= w.Cfg.MaxMembers && h.MemberCount+extra <= MAX_MEMBERS
}

func CombinedGoods(w *World, a *Household, b *Household, g Good) i64 {
	var s i64
	if a != nil && a.Exists {
		s += a.Inv.Qty[g]
	}
	if b != nil && b.Exists && (a == nil || a.Id != b.Id) {
		s += b.Inv.Qty[g]
	}
	return s
}

func CanAffordHut(w *World, man_h *Household, woman_h *Household) bool {
	return CombinedGoods(w, man_h, woman_h, Wood) >= w.Cfg.HutWoodCost &&
		CombinedGoods(w, man_h, woman_h, Stone) >= w.Cfg.HutStoneCost
}

func PayFromTwo(a *Household, b *Household, g Good, need i64) bool {
	if need <= 0 {
		return true
	}
	var have_a i64
	var have_b i64
	if a != nil {
		have_a = a.Inv.Qty[g]
	}
	if b != nil && (a == nil || b.Id != a.Id) {
		have_b = b.Inv.Qty[g]
	}
	if have_a+have_b < need {
		return false
	}
	from_a := need * have_a / (have_a + have_b)
	if have_b == 0 {
		from_a = need
	}
	from_b := need - from_a
	if a != nil {
		a.Inv.Qty[g] -= from_a
	}
	if b != nil && (a == nil || b.Id != a.Id) {
		b.Inv.Qty[g] -= from_b
	}
	return true
}

func HomeCellTaken(w *World, X i32, Y i32, except i32) bool {
	for index_h := range w.Households {
		h := &w.Households[index_h]
		if !h.Exists {
			continue
		}
		if h.Id == except {
			continue
		}
		if h.Home.X == X && h.Home.Y == Y {
			return true
		}
	}
	return false
}

func FindNewHomeCell(w *World, near_a Vec2i, near_b Vec2i) (Vec2i, bool) {
	for attempt := 0; attempt < 80; attempt++ {
		src := near_a
		if attempt%2 == 1 {
			src = near_b
		}
		jx := RngRangeI32(&w.Rng, -8, 8)
		jy := RngRangeI32(&w.Rng, -8, 8)
		X := ClampI32(src.X+jx, 1, w.Cfg.MapW-2)
		Y := ClampI32(src.Y+jy, 1, w.Cfg.MapH-2)
		if HomeCellTaken(w, X, Y, -1) {
			continue
		}
		return Vec2i{X, Y}, true
	}
	for Y := i32(1); Y < w.Cfg.MapH-1; Y += 1 {
		for X := i32(1); X < w.Cfg.MapW-1; X += 1 {
			if !HomeCellTaken(w, X, Y, -1) {
				return Vec2i{X, Y}, true
			}
		}
	}
	return Vec2i{}, false
}

func AllocHousehold(w *World) *Household {
	for i := 0; i < len(w.Households); i++ {
		h := &w.Households[i]
		if !h.Exists {
			*h = Household{}
			h.Id = i32(i)
			h.Exists = true
			return h
		}
	}
	return nil
}

func ChooseResidence(w *World, man *Person, woman *Person) (Residence, bool) {
	mh := &w.Households[man.Household]
	wh := &w.Households[woman.Household]
	wf := w.Cfg.ResidenceFatherBp
	wm := w.Cfg.ResidenceMotherBp
	wn := w.Cfg.ResidenceNewBp
	if !CanHost(w, mh, 1) {
		wf = 0
	}
	if !CanHost(w, wh, 1) {
		wm = 0
	}
	if LivingMembers(w, mh) >= w.Cfg.ResidenceCrowd {
		if wf > 0 {
			wf /= 2
		}
		wn += 2500
	}
	if LivingMembers(w, wh) >= w.Cfg.ResidenceCrowd {
		if wm > 0 {
			wm /= 2
		}
		wn += 1800
	}
	if CanAffordHut(w, mh, wh) {
		wn += 2200
	} else {
		wn /= 3
	}
	if wf < 0 {
		wf = 0
	}
	if wm < 0 {
		wm = 0
	}
	if wn < 0 {
		wn = 0
	}
	total := wf + wm + wn
	if total <= 0 {
		if CanAffordHut(w, mh, wh) {
			return New, true
		}
		return Father, false
	}
	pick := RngRangeI32(&w.Rng, 1, total)
	if pick <= wf {
		return Father, true
	}
	if pick <= wf+wm {
		return Mother, true
	}
	if !CanAffordHut(w, mh, wh) {
		if wf > 0 {
			return Father, true
		}
		if wm > 0 {
			return Mother, true
		}
		return Father, false
	}
	return New, true
}

func FoundHousehold(w *World, man *Person, woman *Person) *Household {
	mh := &w.Households[man.Household]
	wh := &w.Households[woman.Household]
	if !CanAffordHut(w, mh, wh) {
		return nil
	}
	Cell, ok := FindNewHomeCell(w, mh.Home, wh.Home)
	if !ok {
		return nil
	}
	h := AllocHousehold(w)
	if h == nil {
		return nil
	}
	if !PayFromTwo(mh, wh, Wood, w.Cfg.HutWoodCost) || !PayFromTwo(mh, wh, Stone, w.Cfg.HutStoneCost) {
		h.Exists = false
		h.Alive = false
		return nil
	}
	h.Alive = true
	h.Home = Cell
	h.HutVariant = u8(RngRangeI32(&w.Rng, 0, 2))
	h.PrefDaysMilli = (mh.PrefDaysMilli + wh.PrefDaysMilli) / 2
	h.TradeOpenness = (mh.TradeOpenness + wh.TradeOpenness) / 2
	h.RiskPreference = (mh.RiskPreference + wh.RiskPreference) / 2
	h.InferredRole = Generalist
	h.PrevInferredRole = Generalist
	MoveQty := func(src *Household, dst *Household, g Good, want i64) {
		if want <= 0 {
			return
		}
		q := min(src.Inv.Qty[g], want)
		src.Inv.Qty[g] -= q
		dst.Inv.Qty[g] += q
	}
	MoveQty(mh, h, Berries, mh.Inv.Qty[Berries]/5)
	MoveQty(wh, h, Berries, wh.Inv.Qty[Berries]/5)
	MoveQty(mh, h, Meat, mh.Inv.Qty[Meat]/5)
	MoveQty(wh, h, Meat, wh.Inv.Qty[Meat]/5)
	MoveQty(mh, h, Wood, max(i64(400), mh.Inv.Qty[Wood]/8))
	PushEvent(w, Event{Kind: Household_Founded, H1: h.Id, H2: man.Id, Cell: Cell, QtyA: i64(woman.Id)})
	return h
}

func MovePersonToHousehold(w *World, p *Person, dest *Household) {
	if p == nil || dest == nil || p.Household == dest.Id {
		return
	}
	old := &w.Households[p.Household]
	RemoveMember(old, p.Id)
	if !AddMember(dest, p.Id) {
		AddMember(old, p.Id)
		return
	}
	p.Household = dest.Id
	p.IntentCell = dest.Home
	SyncHouseholdFromMembers(w, old)
	SyncHouseholdFromMembers(w, dest)
}

func SettleMarriage(w *World, man *Person, woman *Person, place Residence) bool {
	var dest *Household
	switch place {
	case Father:
		dest = &w.Households[man.Household]
		if !CanHost(w, dest, 1) {
			return false
		}
		MovePersonToHousehold(w, woman, dest)
	case Mother:
		dest = &w.Households[woman.Household]
		if !CanHost(w, dest, 1) {
			return false
		}
		MovePersonToHousehold(w, man, dest)
	case New:
		dest = FoundHousehold(w, man, woman)
		if dest == nil {
			return false
		}
		MovePersonToHousehold(w, man, dest)
		MovePersonToHousehold(w, woman, dest)
	}
	LinkSpouses(man, woman)
	w.Acc.Marriages += 1
	w.TotalMarriages += 1
	PushEvent(w, Event{
		Kind: Married,
		H1:   man.Id,
		H2:   woman.Id,
		QtyA: i64(dest.Id),
		QtyB: i64(u8(place)),
		Cell: dest.Home,
	})
	// Walk to the new home this afternoon.
	dx, dy := MapMilli(dest.Home)
	PathPush(man, dx, dy, 9000, Walking, Rest)
	PathPush(woman, dx, dy, 9000, Walking, Rest)
	return true
}

func PickMarriageCandidate(w *World, p *Person) i32 {
	var best i32 = -1
	var total u64 = 0
	h := &w.Households[p.Household]
	for i := i32(0); i < w.PersonCount; i += 1 {
		o := &w.People[i]
		if o.Id == p.Id || !o.Alive {
			continue
		}
		if o.Sex == p.Sex {
			continue
		}
		if !IsMarriageable(w, o) {
			continue
		}
		if AreCloseKin(w, p, o) {
			continue
		}
		oh := &w.Households[o.Household]
		if !oh.Exists || !oh.Alive {
			continue
		}
		milli := OctileMilli(h.Home.X, h.Home.Y, oh.Home.X, oh.Home.Y)
		dist := milli / 1000
		if dist > w.Cfg.MarryRadius {
			continue
		}
		prox := i32(w.Cfg.MarryRadius+2) - dist
		if prox < 1 {
			prox = 1
		}
		wt := u64(prox)
		total += wt
		if total > 0 && RngNextU64(&w.Rng)%total < wt {
			best = o.Id
		}
	}
	return best
}

func TryMarryPair(w *World, a *Person, b *Person) bool {
	if a == nil || b == nil || a.Sex == b.Sex {
		return false
	}
	if !IsMarriageable(w, a) || !IsMarriageable(w, b) || AreCloseKin(w, a, b) {
		return false
	}
	man := a
	woman := b
	if a.Sex == Female {
		man, woman = b, a
	}
	if man.Sex != Male || woman.Sex != Female {
		return false
	}
	gap := AbsI32(AgeYears(man, w.Cfg.DaysPerYear) - AgeYears(woman, w.Cfg.DaysPerYear))
	bp := w.Cfg.MarryBp
	bp = i32(i64(bp) * i64(man.Health) / i64(HEALTH_MAX) * i64(woman.Health) / i64(HEALTH_MAX))
	if gap > 10 {
		bp = bp * 4 / 10
	} else if gap > 6 {
		bp = bp * 7 / 10
	}
	if bp < 1 {
		return false
	}
	if !RngChanceBp(&w.Rng, bp) {
		return false
	}
	place, ok := ChooseResidence(w, man, woman)
	if !ok {
		return false
	}
	return SettleMarriage(w, man, woman, place)
}

func RunMarriagePhase(w *World) {
	N := w.PersonCount
	if N <= 0 {
		return
	}
	for i := i32(0); i < N; i += 1 {
		w.PersonOrder[i] = i
	}
	RngShuffleI32(&w.Rng, w.PersonOrder[:N])
	for _, idx := range w.PersonOrder[:N] {
		p := &w.People[idx]
		if !IsMarriageable(w, p) {
			continue
		}
		enc := w.Cfg.MarryEncounters
		for iteration1 := 0; iteration1 < enc; iteration1++ {
			if HasLivingSpouse(w, p) {
				break
			}
			cid := PickMarriageCandidate(w, p)
			if cid < 0 {
				break
			}
			o := PersonAt(w, cid)
			if TryMarryPair(w, p, o) {
				break
			}
		}
	}
}

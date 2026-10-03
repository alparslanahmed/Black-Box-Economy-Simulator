package sim

// Project-owned PCG-XSH-RR 32-bit generator.
// Simulation randomness MUST go through this. Rendering and UI never call it.

type RNG struct {
	State u64 `json:"state"`
}

func RngSeed(Rng *RNG, Seed u64) {
	Rng.State = Seed + 1
	_ = RngNextU32(Rng)
}

func RngNextU32(Rng *RNG) u32 {
	old := Rng.State
	Rng.State = old*6364136223846793005 + 1442695040888963407
	xorshifted := u32(((old >> 18) ^ old) >> 27)
	rot := u32(old >> 59)
	return (xorshifted >> rot) | (xorshifted << ((-rot) & 31))
}

func RngNextU64(Rng *RNG) u64 {
	hi := u64(RngNextU32(Rng))
	lo := u64(RngNextU32(Rng))
	return (hi << 32) | lo
}

// Inclusive range [lo, hi]. If hi < lo the bounds are swapped.
func RngRangeI32(Rng *RNG, lo i32, hi i32) i32 {
	a, b := lo, hi
	if b < a {
		a, b = b, a
	}
	span := u32(b-a) + 1
	return a + i32(RngNextU32(Rng)%span)
}

func RngRangeI64(Rng *RNG, lo i64, hi i64) i64 {
	a, b := lo, hi
	if b < a {
		a, b = b, a
	}
	span := u64(b-a) + 1
	return a + i64(RngNextU64(Rng)%span)
}

func RngChanceBp(Rng *RNG, bp i32) bool {
	if bp <= 0 {
		return false
	}
	if bp >= BP_SCALE {
		return true
	}
	return RngRangeI32(Rng, 0, BP_SCALE-1) < bp
}

func RngShuffleI32(Rng *RNG, Items []i32) {
	N := len(Items)
	if N < 2 {
		return
	}
	for i := N - 1; i > 0; i -= 1 {
		j := int(RngNextU32(Rng) % u32(i+1))
		Items[i], Items[j] = Items[j], Items[i]
	}
}

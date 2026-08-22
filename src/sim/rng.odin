package sim

// Project-owned PCG-XSH-RR 32-bit generator.
// Simulation randomness MUST go through this. Rendering and UI never call it.

RNG :: struct {
	state: u64,
}

rng_seed :: proc(rng: ^RNG, seed: u64) {
	rng.state = seed + 1
	_ = rng_next_u32(rng)
}

rng_next_u32 :: proc(rng: ^RNG) -> u32 {
	old := rng.state
	rng.state = old * 6364136223846793005 + 1442695040888963407
	xorshifted := u32(((old >> 18) ~ old) >> 27)
	rot := u32(old >> 59)
	return (xorshifted >> rot) | (xorshifted << ((-rot) & 31))
}

rng_next_u64 :: proc(rng: ^RNG) -> u64 {
	hi := u64(rng_next_u32(rng))
	lo := u64(rng_next_u32(rng))
	return (hi << 32) | lo
}

// Inclusive range [lo, hi]. If hi < lo the bounds are swapped.
rng_range_i32 :: proc(rng: ^RNG, lo, hi: i32) -> i32 {
	a, b := lo, hi
	if b < a {
		a, b = b, a
	}
	span := u32(b - a) + 1
	return a + i32(rng_next_u32(rng) % span)
}

rng_range_i64 :: proc(rng: ^RNG, lo, hi: i64) -> i64 {
	a, b := lo, hi
	if b < a {
		a, b = b, a
	}
	span := u64(b - a) + 1
	return a + i64(rng_next_u64(rng) % span)
}

rng_chance_bp :: proc(rng: ^RNG, bp: i32) -> bool {
	if bp <= 0 {
		return false
	}
	if bp >= BP_SCALE {
		return true
	}
	return rng_range_i32(rng, 0, BP_SCALE - 1) < bp
}

rng_shuffle_i32 :: proc(rng: ^RNG, items: []i32) {
	n := len(items)
	if n < 2 {
		return
	}
	for i := n - 1; i > 0; i -= 1 {
		j := int(rng_next_u32(rng) % u32(i + 1))
		items[i], items[j] = items[j], items[i]
	}
}

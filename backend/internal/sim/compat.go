package sim

// Integer units and comments are preserved from the Odin implementation.
// Go owns allocations. int is 64 bit on the supported amd64/arm64 targets;
// PCG and terrain hashing retain explicit uint32/uint64 wraparound.
type i32 = int
type i64 = int64
type u8 = uint8
type u32 = uint32
type u64 = uint64
type f32 = float32

func choose[T any](condition bool, a, b T) T {
	if condition {
		return a
	}
	return b
}
func assert(ok bool, message ...string) {
	if !ok {
		if len(message) > 0 {
			panic(message[0])
		}
		panic("simulation invariant")
	}
}
func pop[T any](s *[]T) T { n := len(*s) - 1; v := (*s)[n]; *s = (*s)[:n]; return v }

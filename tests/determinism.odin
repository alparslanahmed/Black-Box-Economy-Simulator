package tests

import "core:testing"
import analysis "../src/analysis"

@(test)
test_determinism :: proc(t: ^testing.T) {
	testing.expect(t, analysis.test_determinism(), "same seed must hash identically after 1000 days")
}

@(test)
test_different_seeds :: proc(t: ^testing.T) {
	testing.expect(t, analysis.test_different_seeds(), "different seeds must diverge")
}

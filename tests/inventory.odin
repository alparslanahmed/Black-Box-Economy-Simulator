package tests

import "core:testing"
import analysis "../src/analysis"

@(test)
test_inventory_conservation :: proc(t: ^testing.T) {
	testing.expect(t, analysis.test_inventory_conservation(), "barter must conserve goods")
}

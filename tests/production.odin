package tests

import "core:testing"
import analysis "../src/analysis"

@(test)
test_production_extracts_stock :: proc(t: ^testing.T) {
	testing.expect(t, analysis.test_production_extracts_stock(), "production must extract real stock")
}

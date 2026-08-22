package tests

import "core:testing"
import analysis "../src/analysis"

@(test)
test_no_trade :: proc(t: ^testing.T) {
	testing.expect(t, analysis.test_no_trade(), "trade_enabled=false must complete zero trades")
}

@(test)
test_barter_requires_mutual_gain :: proc(t: ^testing.T) {
	testing.expect(t, analysis.test_barter_requires_mutual_gain(), "barter requires mutual benefit")
}

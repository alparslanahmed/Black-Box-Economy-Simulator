package experiments

import (
	"context"
	"reflect"
	"testing"
)

func TestParallelExperimentsMatchSerial(t *testing.T) {
	for _, kind := range []string{"trade", "scarcity"} {
		opts := Options{Kind: kind, Days: 25, Seeds: 3, Households: 10, Workers: 1}
		serial, err := Run(context.Background(), opts)
		if err != nil {
			t.Fatal(err)
		}
		opts.Workers = 4
		parallel, err := Run(context.Background(), opts)
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(serial, parallel) {
			t.Fatal("worker scheduling changed deterministic results")
		}
	}
}
func TestCancellationAndValidation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := Run(ctx, Options{Kind: "trade", Days: 100, Seeds: 5, Households: 10, Workers: 4}); err == nil {
		t.Fatal("ignored cancellation")
	}
	if _, err := Run(context.Background(), Options{Kind: "trade", Workers: 0}); err == nil {
		t.Fatal("accepted invalid options")
	}
}

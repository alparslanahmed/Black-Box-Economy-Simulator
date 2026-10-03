package sim

import (
	"math"
	"reflect"
)

// Hash values rather than addresses, padding or unused capacity. This includes
// every model field automatically, so new decision state cannot be forgotten.
func hash_state_value(hash uint64, value any) uint64 {
	return hashValue(hash, reflect.ValueOf(value))
}

func hashValue(h uint64, v reflect.Value) uint64 {
	mix := func(n uint64, bytes int) {
		for i := 0; i < bytes; i++ {
			h = (h ^ (n & 255)) * 1099511628211
			n >>= 8
		}
	}
	switch v.Kind() {
	case reflect.Bool:
		if v.Bool() {
			mix(1, 1)
		} else {
			mix(0, 1)
		}
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		mix(uint64(v.Int()), 8)
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		mix(v.Uint(), 8)
	case reflect.Float32, reflect.Float64:
		mix(math.Float64bits(v.Float()), 8)
	case reflect.Struct:
		for i := 0; i < v.NumField(); i++ {
			h = hashValue(h, v.Field(i))
		}
	case reflect.Array, reflect.Slice:
		mix(uint64(v.Len()), 8)
		for i := 0; i < v.Len(); i++ {
			h = hashValue(h, v.Index(i))
		}
	default:
		panic("unsupported simulation state in hash: " + v.Kind().String())
	}
	return h
}

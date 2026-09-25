class_name DetRng
extends RefCounted
## Deterministic, platform-independent 32-bit xorshift RNG.
## Only shifts, xors and masked additions are used, so the integer sequence is
## identical on every platform and engine build (no reliance on engine RNG).

const MASK := 0xFFFFFFFF

var state: int = 0x6D2B79F5


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	state = DetRng.hash32(seed_value)
	if state == 0:
		state = 0x6D2B79F5


## Integer avalanche hash (no multiplication, so no 64-bit overflow concerns).
static func hash32(v: int) -> int:
	var x := ((v & MASK) ^ ((v >> 32) & MASK) ^ 0x9E3779B9) & MASK
	for i in 5:
		x = (x + 0x7F4A7C15 + i * 0x1B873593) & MASK
		x ^= (x << 13) & MASK
		x ^= x >> 17
		x ^= (x << 5) & MASK
	return x


## Combine a base seed with an index (e.g. match seed + ball number).
static func derive(base_seed: int, index: int, salt: int = 0) -> int:
	return DetRng.hash32(DetRng.hash32(base_seed ^ salt) + index * 0x2545F491)


func next_u32() -> int:
	var x := state
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	state = x & MASK
	return state


## Uniform float in [0, 1).
func next_float() -> float:
	return float(next_u32()) / 4294967296.0


func range_f(a: float, b: float) -> float:
	return a + (b - a) * next_float()


func range_i(a: int, b: int) -> int:
	## Inclusive integer range.
	return a + int(next_u32() % (b - a + 1))


func chance(p: float) -> bool:
	return next_float() < p

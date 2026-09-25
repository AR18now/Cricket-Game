class_name DeliveryGenerator
extends RefCounted
## Builds seeded deliveries from a bowler profile. Difficulty is bounded: it can raise
## pace by at most MAX_PACE_BOOST and never changes timing windows, bat reach or catching.

const MAX_PACE_BOOST := 0.12

## Tutorial deliveries: slow, straight, good length. Level 0..2 adds modest pace.
const TUTORIAL_SPEEDS := [13.5, 15.0, 17.5]


static func generate(profile: BowlerProfile, seed_value: int, tuning: GameTuning, difficulty: float = 0.0) -> Delivery:
	var rng := DetRng.new(seed_value)
	var d := Delivery.new()
	d.seed = seed_value
	d.bowler_id = profile.id
	d.gravity = tuning.gravity
	d.restitution = tuning.bounce_restitution
	d.retention = tuning.pitch_retention
	d.release = Vector3(tuning.release_x, profile.release_y, tuning.release_height)
	var boost := 1.0 + MAX_PACE_BOOST * clampf(difficulty, 0.0, 1.0)
	if rng.chance(profile.slower_chance):
		d.kind = "slower"
		d.speed = rng.range_f(profile.slower_min, profile.slower_max)
	else:
		d.kind = "stock"
		d.speed = rng.range_f(profile.speed_min, profile.speed_max) * boost
	d.line_y = rng.range_f(profile.line_min, profile.line_max)
	if profile.deviation_max > 0.0:
		d.deviation = rng.range_f(-profile.deviation_max, profile.deviation_max)
		d.kind = "spin" if profile.style == "spin" else "seam"
	# Pick a length whose contact heights stay within bat reach; retry deterministically.
	var ok := false
	for attempt in 10:
		d.length = rng.range_f(profile.length_min, profile.length_max)
		d.build()
		if is_playable(d, tuning):
			ok = true
			break
	if not ok:
		d.length = 5.0
		d.build()
	if d.kind == "stock":
		if d.length <= 3.6:
			d.kind = "full"
		elif d.length >= 7.5:
			d.kind = "short"
	return d


static func tutorial(level: int, seed_value: int, tuning: GameTuning) -> Delivery:
	var d := Delivery.new()
	d.seed = seed_value
	d.kind = "tutorial"
	d.bowler_id = "ayaan"
	d.gravity = tuning.gravity
	d.restitution = tuning.bounce_restitution
	d.retention = tuning.pitch_retention
	d.release = Vector3(tuning.release_x, 0.3, tuning.release_height)
	d.speed = TUTORIAL_SPEEDS[clampi(level, 0, TUTORIAL_SPEEDS.size() - 1)]
	d.length = 5.2
	d.line_y = 0.02
	return d.build()


## A delivery is playable when the ball's height stays inside bat reach across the
## whole contact zone, so every miss is genuinely a timing miss.
static func is_playable(d: Delivery, tuning: GameTuning) -> bool:
	for x in [tuning.contact_x_early, tuning.contact_x_ideal, tuning.contact_x_late, tuning.contact_x_edge]:
		var t := d.time_at_x(x)
		if t == INF:
			return false
		var z := d.pos_at(t).z
		if z < tuning.min_contact_height or z > tuning.max_contact_height:
			return false
	return true

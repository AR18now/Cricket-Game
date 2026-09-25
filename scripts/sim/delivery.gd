class_name Delivery
extends RefCounted
## Pseudo-3D delivery with an analytic, piecewise-ballistic path.
## World frame: x along the pitch (batter stumps at x = 0, bowler end negative),
## y lateral (+ = off side, toward the camera), z height above ground.
## Because the path is analytic, stump and contact checks are exact (no tunnelling).

const STUMPS_HALF_WIDTH := 0.1143
const STUMPS_HEIGHT := 0.711
const BALL_RADIUS := 0.036
const POPPING_CREASE_X := -1.22
const BOWLING_STUMPS_X := -20.12

var seed := 0
var kind := "stock"
var bowler_id := ""
var speed := 22.0
var length := 5.0
var line_y := 0.0
var deviation := 0.0
var release := Vector3(-18.7, 0.35, 2.05)
var restitution := 0.52
var retention := 0.9
var gravity := 9.81

## Array of {t0: float, p0: Vector3, v: Vector3}
var segments: Array = []
var t_bounce := 0.0


func build() -> Delivery:
	segments.clear()
	var plan := Vector2(0.0 - release.x, line_y - release.y).normalized()
	var vx := plan.x * speed
	var vy := plan.y * speed
	var bounce_x := -length
	var t1 := (bounce_x - release.x) / vx
	var vz0 := (0.5 * gravity * t1 * t1 - release.z) / t1
	segments.append({"t0": 0.0, "p0": release, "v": Vector3(vx, vy, vz0)})
	t_bounce = t1
	var p := Vector3(bounce_x, release.y + vy * t1, 0.0)
	var v := Vector3(vx * retention, vy * retention + deviation, -(vz0 - gravity * t1) * restitution)
	var t := t1
	for i in 4:
		segments.append({"t0": t, "p0": p, "v": v})
		var air := 2.0 * v.z / gravity
		if air < 0.02 or p.x > 6.0:
			break
		t += air
		p = Vector3(p.x + v.x * air, p.y + v.y * air, 0.0)
		v = Vector3(v.x * 0.85, v.y * 0.85, v.z * 0.45)
	return self


func _segment_index(t: float) -> int:
	var idx := 0
	for i in segments.size():
		if segments[i]["t0"] <= t:
			idx = i
	return idx


func pos_at(t: float) -> Vector3:
	var s: Dictionary = segments[_segment_index(t)]
	var tau := t - float(s["t0"])
	var p0: Vector3 = s["p0"]
	var v: Vector3 = s["v"]
	var is_last: bool = s == segments[segments.size() - 1]
	var z := p0.z + v.z * tau - 0.5 * gravity * tau * tau
	if is_last and z < 0.0:
		z = 0.0
	return Vector3(p0.x + v.x * tau, p0.y + v.y * tau, maxf(z, 0.0))


func vel_at(t: float) -> Vector3:
	var s: Dictionary = segments[_segment_index(t)]
	var tau := t - float(s["t0"])
	var v: Vector3 = s["v"]
	return Vector3(v.x, v.y, v.z - gravity * tau)


## Exact time at which the ball's centre reaches plane x (x velocity is positive and
## constant inside each segment, so this is a linear solve per segment).
func time_at_x(x: float) -> float:
	for i in segments.size():
		var s: Dictionary = segments[i]
		var p0: Vector3 = s["p0"]
		var v: Vector3 = s["v"]
		var t_end := INF
		if i + 1 < segments.size():
			t_end = segments[i + 1]["t0"]
		var tau := (x - p0.x) / v.x
		var t := float(s["t0"]) + tau
		if tau >= 0.0 and t <= t_end:
			return t
	return INF


func stumps_time() -> float:
	return time_at_x(0.0)


func hits_stumps() -> bool:
	var p := pos_at(stumps_time())
	return absf(p.y) <= STUMPS_HALF_WIDTH + BALL_RADIUS and p.z <= STUMPS_HEIGHT + BALL_RADIUS


func speed_kmh() -> int:
	return int(round(speed * 3.6))


func to_dict() -> Dictionary:
	return {"seed": seed, "kind": kind, "bowler": bowler_id, "speed": speed, "length": length,
		"line": line_y, "deviation": deviation}

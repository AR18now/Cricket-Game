class_name Poses
extends RefCounted
## Keyframe poses and procedural cycles for CricketerRig. Angles: radians from straight
## down, positive toward the facing direction. "hands" = IK target from the shoulder (m).


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a.keys():
		out[k] = a[k]
	for k in b.keys():
		if a.has(k):
			var va = a[k]
			var vb = b[k]
			if va is Vector2 and vb is Vector2:
				out[k] = va.lerp(vb, t)
			elif (va is float or va is int) and (vb is float or vb is int):
				out[k] = lerpf(float(va), float(vb), t)
			else:
				out[k] = vb if t >= 0.5 else va
		else:
			out[k] = b[k]
	return out


static func ease_io(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# --- Batting -----------------------------------------------------------------

static func bat_stance(t: float) -> Dictionary:
	return {"lean": 0.34, "thigh_f": 0.24, "shin_f": -0.08, "thigh_b": -0.18, "shin_b": -0.34,
		"hands": Vector2(0.2, -0.5 + 0.01 * sin(t * 2.0)), "bat": -0.32 + 0.06 * maxf(0.0, sin(t * 3.1)),
		"head": 0.12, "bob": 0.008 * sin(t * 2.0)}


static func bat_backlift() -> Dictionary:
	return {"lean": 0.3, "thigh_f": 0.22, "shin_f": -0.1, "thigh_b": -0.2, "shin_b": -0.36,
		"hands": Vector2(-0.02, -0.2), "bat": -2.35, "head": 0.14}


static func bat_contact(bat_angle: float, hand_rise: float) -> Dictionary:
	return {"lean": 0.52, "thigh_f": 0.66, "shin_f": 0.14, "thigh_b": -0.5, "shin_b": -0.78,
		"hands": Vector2(0.4, -0.56 + hand_rise), "bat": bat_angle, "head": 0.2}


static func bat_follow() -> Dictionary:
	return {"lean": 0.22, "thigh_f": 0.52, "shin_f": 0.12, "thigh_b": -0.36, "shin_b": -0.95,
		"hands": Vector2(0.12, 0.2), "bat": 2.75, "head": 0.0}


## u: 0 = backlift, CONTACT_U = bat in the hitting zone, 1 = follow-through.
const CONTACT_U := 0.3


static func bat_swing(u: float, bat_angle: float = 0.1, hand_rise: float = 0.0) -> Dictionary:
	var c := bat_contact(bat_angle, hand_rise)
	if u <= CONTACT_U:
		var k := u / CONTACT_U
		return blend(bat_backlift(), c, k * k)
	var k2 := (u - CONTACT_U) / (1.0 - CONTACT_U)
	return blend(c, bat_follow(), 1.0 - (1.0 - k2) * (1.0 - k2))


## Bat angle that puts the sweet spot at the ball's height (m) for the contact pose.
static func bat_angle_for_height(z: float) -> float:
	var hands_z := 0.86 + maxf(0.0, z - 0.45) * 0.45
	var c := clampf((hands_z - z) / 0.56, -1.0, 1.0)
	return acos(c)


static func hand_rise_for_height(z: float) -> float:
	return maxf(0.0, z - 0.45) * 0.45


# --- Locomotion --------------------------------------------------------------

static func run(phase: float, amp: float = 1.0, carrying_bat: bool = false) -> Dictionary:
	var s := sin(phase)
	var c := cos(phase)
	var tf := 0.72 * s * amp
	var tb := -0.72 * s * amp
	var p := {
		"lean": 0.28 * amp + 0.04, "thigh_f": tf, "shin_f": tf - (0.25 + 1.0 * maxf(0.0, -s)) * amp,
		"thigh_b": tb, "shin_b": tb - (0.25 + 1.0 * maxf(0.0, s)) * amp,
		"arm_f_up": -0.75 * s * amp, "arm_f_lo": -0.75 * s * amp + 1.3 * amp,
		"arm_b_up": 0.75 * s * amp, "arm_b_lo": 0.75 * s * amp + 1.3 * amp,
		"bob": 0.05 * absf(c) * amp, "head": -0.05,
	}
	if carrying_bat:
		p["hands"] = Vector2(0.32, -0.38 + 0.03 * s)
		p["bat"] = 1.15
	return p


static func walk(phase: float, carrying_bat: bool = false) -> Dictionary:
	var p := run(phase, 0.45, carrying_bat)
	p["lean"] = 0.06
	return p


static func dejected(phase: float) -> Dictionary:
	var p := walk(phase, true)
	p["head"] = -0.45
	p["lean"] = 0.18
	p["hands"] = Vector2(0.18, -0.5)
	p["bat"] = 0.2
	return p


static func celebrate(t: float, with_bat: bool = false) -> Dictionary:
	var s := absf(sin(t * 5.0))
	var p := {"lean": -0.05, "thigh_f": 0.1, "shin_f": 0.0, "thigh_b": -0.1, "shin_b": -0.05,
		"arm_f_up": 2.7 + 0.2 * s, "arm_f_lo": 2.9, "arm_b_up": 2.6 - 0.2 * s, "arm_b_lo": 2.8,
		"bob": 0.06 * s}
	if with_bat:
		p["hands"] = Vector2(0.05, 0.55)
		p["bat"] = PI - 0.2
	return p


# --- Fielding ----------------------------------------------------------------

static func field_ready(t: float) -> Dictionary:
	return {"lean": 0.55, "thigh_f": 0.55, "shin_f": -0.25, "thigh_b": -0.1, "shin_b": -0.62,
		"arm_f_up": 0.75, "arm_f_lo": 0.3, "arm_b_up": 0.6, "arm_b_lo": 0.25, "head": 0.25,
		"bob": 0.01 * sin(t * 2.4)}


static func field_idle(t: float) -> Dictionary:
	return {"lean": 0.08, "thigh_f": 0.1, "shin_f": 0.0, "thigh_b": -0.08, "shin_b": -0.02,
		"arm_f_up": 0.2 + 0.05 * sin(t * 1.3), "arm_f_lo": 0.5, "arm_b_up": -0.15, "arm_b_lo": 0.2,
		"head": 0.05 * sin(t * 0.7)}


static func catch_high(u: float) -> Dictionary:
	var up := {"lean": -0.08, "thigh_f": 0.2, "shin_f": 0.0, "thigh_b": -0.2, "shin_b": -0.3,
		"arm_f_up": 2.75, "arm_f_lo": 2.9, "arm_b_up": 2.55, "arm_b_lo": 2.8, "head": 0.4}
	return blend(field_ready(0.0), up, ease_io(u))


static func pick_up(u: float) -> Dictionary:
	var down := {"lean": 1.05, "thigh_f": 0.9, "shin_f": -0.2, "thigh_b": -0.3, "shin_b": -0.9,
		"arm_f_up": 1.2, "arm_f_lo": 0.6, "arm_b_up": 1.1, "arm_b_lo": 0.5, "head": 0.3}
	return blend(field_ready(0.0), down, ease_io(u))


static func throw_arm(u: float) -> Dictionary:
	var wind := {"lean": -0.15, "thigh_f": 0.5, "shin_f": 0.1, "thigh_b": -0.4, "shin_b": -0.6,
		"arm_f_up": 1.4, "arm_f_lo": 1.6, "arm_b_up": -2.2, "arm_b_lo": -2.6, "head": 0.1}
	var rel := {"lean": 0.45, "thigh_f": 0.55, "shin_f": 0.2, "thigh_b": -0.5, "shin_b": -0.9,
		"arm_f_up": 0.2, "arm_f_lo": 0.4, "arm_b_up": 1.9, "arm_b_lo": 1.7, "head": 0.1}
	if u < 0.55:
		return blend(field_ready(0.0), wind, ease_io(u / 0.55))
	return blend(wind, rel, ease_io((u - 0.55) / 0.45))


static func keeper_crouch(t: float) -> Dictionary:
	return {"lean": 0.42, "thigh_f": 1.25, "shin_f": -0.75, "thigh_b": 1.1, "shin_b": -0.9,
		"arm_f_up": 0.9, "arm_f_lo": 1.25, "arm_b_up": 0.8, "arm_b_lo": 1.2, "head": 0.1,
		"bob": 0.005 * sin(t * 2.0)}


static func keeper_rise(u: float) -> Dictionary:
	var up := {"lean": 0.25, "thigh_f": 0.4, "shin_f": -0.3, "thigh_b": 0.2, "shin_b": -0.5,
		"arm_f_up": 1.3, "arm_f_lo": 1.5, "arm_b_up": 1.2, "arm_b_lo": 1.45, "head": 0.1}
	return blend(keeper_crouch(0.0), up, ease_io(u))


static func umpire(t: float) -> Dictionary:
	return {"lean": 0.12, "thigh_f": 0.12, "shin_f": 0.0, "thigh_b": -0.1, "shin_b": -0.02,
		"arm_f_up": 0.3, "arm_f_lo": 1.2, "arm_b_up": 0.25, "arm_b_lo": 1.15, "head": 0.05 * sin(t * 0.5)}


static func umpire_signal(kind: String, t: float) -> Dictionary:
	var p := umpire(t)
	match kind:
		"six":
			p["arm_f_up"] = PI
			p["arm_f_lo"] = PI
			p["arm_b_up"] = -PI
			p["arm_b_lo"] = -PI
		"four":
			var w := sin(t * 8.0) * 0.5
			p["arm_f_up"] = PI * 0.5 + w
			p["arm_f_lo"] = PI * 0.5 + w
		"out":
			p["arm_f_up"] = PI
			p["arm_f_lo"] = PI
	return p


# --- Bowling (right-arm, facing +x) -----------------------------------------

static func bowl_gather(u: float) -> Dictionary:
	return {"lean": -0.12, "thigh_f": 0.95, "shin_f": 0.15, "thigh_b": -0.15, "shin_b": -0.85,
		"arm_f_up": lerpf(0.5, 2.7, u), "arm_f_lo": lerpf(0.8, 2.9, u),
		"arm_b_up": lerpf(-0.3, -0.7, u), "arm_b_lo": lerpf(-0.1, -0.5, u), "head": 0.1}


## u 0..1 through the delivery stride; release at u = 1.
static func bowl_stride(u: float) -> Dictionary:
	var e := u * u
	var arm := lerpf(-0.7, -PI - 0.25, e)
	return {"lean": lerpf(-0.15, 0.3, e), "thigh_f": 0.48, "shin_f": 0.26, "thigh_b": -0.55, "shin_b": -0.95,
		"arm_f_up": lerpf(2.7, 0.3, e), "arm_f_lo": lerpf(2.9, 0.6, e),
		"arm_b_up": arm, "arm_b_lo": arm - 0.06, "head": 0.15}


static func bowl_follow(u: float) -> Dictionary:
	var e := 1.0 - (1.0 - u) * (1.0 - u)
	var arm := lerpf(-PI - 0.25, -2.0 * PI + 0.55, e)
	return {"lean": lerpf(0.3, 0.75, sin(e * PI * 0.9)), "thigh_f": lerpf(0.48, 0.1, e), "shin_f": lerpf(0.26, -0.1, e),
		"thigh_b": lerpf(-0.55, 0.6, e), "shin_b": lerpf(-0.95, 0.1, e),
		"arm_f_up": lerpf(0.3, -0.5, e), "arm_f_lo": lerpf(0.6, -0.2, e),
		"arm_b_up": arm, "arm_b_lo": arm + 0.3 * e, "head": 0.1}

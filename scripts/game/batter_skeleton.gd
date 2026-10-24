class_name BatterSkeleton
extends RefCounted
## A right-handed batter as a real 3D skeleton (metres, world frame: x along the pitch with
## the bowler at -x, y lateral with the off side at +y, z up). Poses are keyed in a local
## frame - l: toward the bowler, f: the way the chest faces in the stance (off side),
## u: up - and every limb is solved with two-bone IK, so nothing stretches and knees and
## elbows bend like a person's. The batter's-eye view projects these joints through its
## perspective camera; the swing timing matches the side view (Poses.CONTACT_U).

const THIGH := 0.45
const SHIN := 0.44
const ANKLE_H := 0.08
const UPPER_ARM := 0.3
const FOREARM := 0.27
const SPINE := 0.5
const HEAD_R := 0.11
const BAT_LEN := 0.86
const GRIP_GAP := 0.11       # top hand to bottom hand along the handle
const SWEET := 0.6           # sweet spot, metres from the top hand along the bat

const L := Vector3(-1, 0, 0)
const F := Vector3(0, 1, 0)
const U := Vector3(0, 0, 1)

# Hands path through the swing (local l, f, u) and bat angle in the swing plane
# (0 = toe straight down, +90 = toward the bowler, 180 = up, -90 = toward the keeper).
const STANCE_HANDS := Vector3(0.0, 0.3, 0.82)
const BACKLIFT_HANDS := Vector3(-0.12, 0.17, 1.1)
const MIDFOLLOW_HANDS := Vector3(0.42, 0.3, 0.98)
const FOLLOW_HANDS := Vector3(0.16, 0.06, 1.46)
const PHI_STANCE := -10.0
const PHI_BACKLIFT := -142.0
const PHI_MIDDOWN := -78.0
const PHI_MIDFOLLOW := 98.0
const PHI_FOLLOW := 205.0


static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


static func catmull(p0, p1, p2, p3, t: float):
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Samples a smooth curve through keys at parameter s in [0, keys.size() - 1].
static func spline(keys: Array, s: float):
	var n := keys.size()
	s = clampf(s, 0.0, float(n - 1))
	var i := mini(int(floor(s)), n - 2)
	var t := s - i
	return catmull(keys[maxi(i - 1, 0)], keys[i], keys[i + 1], keys[mini(i + 2, n - 1)], t)


## Two-bone IK: joint between a and c with bone lengths l1, l2, bending toward pole.
static func ik(a: Vector3, c: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var d := a.distance_to(c)
	var dir := (c - a) / maxf(d, 0.0001)
	d = clampf(d, absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var end := a + dir * d
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - x * x))
	var pp := pole - dir * pole.dot(dir)
	if pp.length() < 0.0001:
		pp = U - dir * U.dot(dir)
	return [a + dir * x + pp.normalized() * h, end]


## Swing-plane direction for bat angle phi (degrees) with a sideways tilt toward f.
static func bat_dir(phi_deg: float, tilt: float) -> Vector3:
	var p := deg_to_rad(phi_deg)
	return Vector3(sin(p), tilt, -cos(p)).normalized()   # local (l, f, u)


## Local (l, f, u) -> world, with the body root at (root.x, root.y) on the ground.
static func to_world(root: Vector2, v: Vector3) -> Vector3:
	return Vector3(root.x - v.x, root.y + v.y, v.z)


static func dir_world(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## Local hands position and bat (phi, tilt) that put the sweet spot on a local target.
static func contact_solution(target: Vector3) -> Dictionary:
	# Higher balls are met with a flatter bat (pull/cut), lower ones with a vertical bat.
	var du := clampf(0.5 - maxf(0.0, target.z - 0.55) * 1.1, -0.15, 0.52)
	var horiz := sqrt(maxf(0.0, SWEET * SWEET - du * du))
	var dl := horiz * 0.12   # hands just ahead of the blade
	var df := sqrt(maxf(0.0, horiz * horiz - dl * dl))
	var hands := target + Vector3(dl, -df, du)
	var d := (target - hands).normalized()
	return {"hands": hands, "phi": rad_to_deg(atan2(d.x, -d.z)), "tilt": d.y / maxf(0.2, Vector2(d.x, d.z).length())}


## Full skeleton for clock t. `o` keys: swing_time, swing_dur, contact_u, target (Vector3
## world or null), stumps_t, bowled, base (Vector2), look (Vector3 world), runup_t.
static func solve(t: float, o: Dictionary) -> Dictionary:
	# Self-correct the swing: measure where the sweet spot lands at the contact frame and
	# shift/crouch the body by the error (a few iterations), so the bat really meets the ball.
	if not o.has("_corr") and float(o.get("swing_time", -1.0)) >= 0.0 and o.get("target", null) is Vector3:
		var corr := Vector3.ZERO
		var tc: float = float(o["swing_time"]) + float(o.get("swing_dur", 0.34)) * float(o.get("contact_u", 0.3))
		for it in 3:
			var oi := o.duplicate()
			oi["_corr"] = corr
			var jc := solve(tc, oi)
			corr += (o["target"] as Vector3) - (jc["bat_sweet"] as Vector3)
			corr = Vector3(clampf(corr.x, -0.6, 0.6), clampf(corr.y, -0.3, 0.3), clampf(corr.z, -0.28, 0.15))
		var o2 := o.duplicate()
		o2["_corr"] = corr
		return solve(t, o2)
	var base: Vector2 = o.get("base", Vector2(-1.05, -0.42))
	var swing_t: float = o.get("swing_time", -1.0)
	var dur: float = o.get("swing_dur", 0.34)
	var cu: float = o.get("contact_u", 0.3)
	var stumps_t: float = o.get("stumps_t", 99.0)
	var runup: float = o.get("runup_t", 2.0)
	# ---- idle: breathing, weight shift, two bat taps while the bowler runs in -------
	var breath := sin(t * 1.7) * 0.007
	var sway := sin(t * 0.55) * 0.012
	var tap := 0.0
	if t > -runup + 0.3 and t < -0.75:
		tap = pow(maxf(0.0, sin((t + runup) * TAU * 0.9)), 6.0)
	var pelvis := Vector3(0.02 + sway, -0.06, 0.86 + breath * 0.5)
	var front := Vector3(0.25, 0.0, 0.0)
	var back := Vector3(-0.2, 0.02, 0.0)
	var front_yaw := 0.28
	var back_yaw := -0.05
	var back_heel := 0.0
	var lean := 0.34
	var bend := 0.05
	var twist := 0.12
	var hands := STANCE_HANDS + Vector3(0, 0, 0.05 * tap + breath)
	var phi := PHI_STANCE - 10.0 * tap
	var tilt := 0.15
	var elbow_mix := 0.0   # 0 = stance/backlift elbows, 1 = follow-through elbows
	# ---- trigger (back and across) and backlift as the bowler delivers --------------
	var trig := smoother((t + 0.62) / 0.36)
	back = back.lerp(Vector3(-0.25, 0.1, 0.0), trig)
	front = front.lerp(Vector3(0.22, 0.04, 0.0), trig)
	pelvis = pelvis.lerp(Vector3(-0.01, -0.01, 0.84), trig)
	var lift := smoother((t + 0.45) / 0.42)
	hands = hands.lerp(BACKLIFT_HANDS, lift)
	phi = lerpf(phi, PHI_BACKLIFT, lift)
	tilt = lerpf(tilt, 0.28, lift)
	lean = lerpf(lean, 0.3, lift)
	twist = lerpf(twist, 0.04, lift)
	# Loaded and waiting: knees settle, hands breathe - never a frozen statue.
	if lift > 0.99:
		var wait := t + 0.03
		pelvis.z -= 0.025 * smooth(wait / 0.5)
		hands += Vector3(0.0, 0.0, 0.012 * sin(t * 9.0) * smooth(wait / 0.3))
	# Forward press as the ball arrives (real batters move before they hit), so the
	# stride doesn't all have to happen in the 0.1 s downswing.
	var ideal_t: float = o.get("ideal_t", 99.0)
	var press := smoother((t - (ideal_t - 0.4)) / 0.3) * 0.5
	if swing_t >= 0.0 and swing_t < t:
		press = minf(press, smoother((swing_t - (ideal_t - 0.4)) / 0.3) * 0.5)
	front = front.lerp(Vector3(0.42, 0.05, 0.0), press)
	pelvis = pelvis.lerp(Vector3(0.1, -0.01, 0.82), press)
	var root_shift := 0.0
	if swing_t >= 0.0 and t >= swing_t:
		var u := clampf((t - swing_t) / dur, 0.0, 1.0)
		var target_w = o.get("target", null)
		var target_l := Vector3(0.55, 0.42, 0.45)
		if target_w is Vector3:
			target_l = Vector3(base.x - target_w.x, target_w.y - base.y, target_w.z)
		# Reach the ball: stride length scales with how far forward contact is; beyond
		# that the whole body shifts (lunging or getting back), like the side view.
		var stride := clampf(target_l.x - 0.3, -0.15, 0.55)
		var cs := contact_solution(target_l)
		var c_hands: Vector3 = cs["hands"]
		var reach := 0.24 + stride
		var full_shift := clampf(c_hands.x - (reach + 0.12), -0.35, 0.9)
		c_hands.x -= full_shift
		var corr: Vector3 = o.get("_corr", Vector3.ZERO)
		var ce := smoother(u / cu)
		c_hands.y += corr.y
		root_shift = (full_shift - corr.x) * ce
		var s := 0.0
		if u <= cu:
			s = 2.0 * pow(u / cu, 1.2)
		else:
			s = 2.0 + 2.0 * (1.0 - pow(1.0 - (u - cu) / (1.0 - cu), 2.2))
		# Mid-downswing halfway along an outward arc, so the hands keep an even speed.
		var mid := BACKLIFT_HANDS.lerp(c_hands, 0.5) + Vector3(0.0, 0.07, -0.04)
		var hkeys := [BACKLIFT_HANDS, mid, c_hands, MIDFOLLOW_HANDS + Vector3(stride * 0.4, 0, 0), FOLLOW_HANDS + Vector3(stride * 0.3, 0, 0)]
		hands = spline(hkeys, s)
		phi = spline([PHI_BACKLIFT, PHI_MIDDOWN, float(cs["phi"]), PHI_MIDFOLLOW, PHI_FOLLOW], s)
		tilt = spline([0.28, 0.3, float(cs["tilt"]), 0.15, -0.35], s)
		var step := smoother(u / (cu * 0.85))
		var fl := Vector3(0.22 + stride + 0.12, 0.05, 0.0)
		front = front.lerp(fl, step)
		front.z = 0.07 * sin(PI * step)          # foot lifts as it strides
		front_yaw = lerpf(front_yaw, 0.55, step)
		var weight := smoother((u - 0.05) / 0.4)
		pelvis = pelvis.lerp(Vector3(0.15 + stride * 0.55, 0.0, 0.8), weight)
		pelvis.z += corr.z * ce
		lean = lerpf(lean, 0.46 + maxf(0.0, -corr.z) * 0.8, ce) - 0.22 * smoother((u - cu) / (1.0 - cu))
		bend = lerpf(bend, 0.16, smoother(u / cu))
		twist = lerpf(twist, 0.32, smoother(u / cu)) + 0.8 * smoother((u - cu) / (1.0 - cu))
		var pivot := smoother((u - cu) / (1.0 - cu))
		back_heel = 0.12 * pivot
		back_yaw = lerpf(back_yaw, 0.95, pivot)
		back = back.lerp(Vector3(-0.12, 0.06, 0.0), pivot * 0.6)
		elbow_mix = smoother((u - cu) / (1.0 - cu))
		# Hold the follow-through, then relax the bat a little.
		var ts := t - swing_t - dur
		if ts > 0.0:
			var relax := smooth(ts / 0.8)
			hands = hands.lerp(FOLLOW_HANDS + Vector3(0.12, 0.12, -0.25), relax * 0.6)
			phi = lerpf(phi, 150.0, relax * 0.6)
			twist = lerpf(twist, 0.6, relax * 0.5)
	elif swing_t < 0.0 and t > stumps_t + 0.1:
		# Left alone (or beaten): bring the bat back down.
		var down := smoother((t - stumps_t - 0.1) / 0.55)
		hands = hands.lerp(STANCE_HANDS, down)
		phi = lerpf(phi, PHI_STANCE, down)
		tilt = lerpf(tilt, 0.15, down)
	var dejected := 0.0
	if bool(o.get("bowled", false)) and t > stumps_t + 0.3:
		dejected = smoother((t - stumps_t - 0.3) / 0.5)
		lean = lerpf(lean, 0.5, dejected)
		hands = hands.lerp(Vector3(0.05, 0.25, 0.7), dejected)
		phi = lerpf(phi, 20.0, dejected)
		pelvis.z += 0.04 * dejected
	var root := Vector2(base.x - root_shift, base.y)
	return _build(root, pelvis, front, back, front_yaw, back_yaw, back_heel, lean, bend, twist, hands, phi, tilt, elbow_mix, dejected, o.get("look", Vector3(-20, 0, 1.8)))


static func _build(root: Vector2, pelvis_l: Vector3, front_l: Vector3, back_l: Vector3, front_yaw: float, back_yaw: float, back_heel: float, lean: float, bend: float, twist: float, hands_l: Vector3, phi: float, tilt: float, elbow_mix: float, dejected: float, look: Vector3) -> Dictionary:
	var j := {}
	var W := func(v: Vector3) -> Vector3: return to_world(root, v)
	var D := func(v: Vector3) -> Vector3: return dir_world(v)
	# Body axes after the shoulder twist (opening the chest toward the bowler).
	var fwd := (F * cos(twist) + Vector3(1, 0, 0) * sin(twist))       # local
	var side := (Vector3(1, 0, 0) * cos(twist) - F * sin(twist))      # local: left shoulder dir
	var pel_side := (Vector3(1, 0, 0) * cos(twist * 0.45) - F * sin(twist * 0.45))
	var spine := (U * cos(lean) + fwd * sin(lean)).normalized()
	spine = (spine + side * bend).normalized()
	var pelvis: Vector3 = W.call(pelvis_l)
	j["pelvis"] = pelvis
	j["spine"] = D.call(spine)
	j["side"] = D.call(side)
	j["fwd"] = D.call(fwd)
	j["pel_side"] = D.call(pel_side)
	j["hip_l"] = W.call(pelvis_l + pel_side * 0.1)
	j["hip_r"] = W.call(pelvis_l - pel_side * 0.1)
	# Legs: foot placement (ankle above the ground), knees bend over the toes.
	for leg in [["l", front_l, front_yaw, 0.0], ["r", back_l, back_yaw, back_heel]]:
		var k: String = leg[0]
		var fp: Vector3 = leg[1]
		var yaw: float = leg[2]
		var heel: float = leg[3]
		var toe_dir := (F * cos(yaw) + Vector3(1, 0, 0) * sin(yaw)).normalized()
		var toe_l := fp + toe_dir * 0.15
		var heel_l := fp - toe_dir * 0.07 + Vector3(0, 0, heel)
		var ankle_l := fp + Vector3(0, 0, ANKLE_H + heel * 0.8) - toe_dir * 0.01
		var hip_w: Vector3 = j["hip_" + k]
		var pole: Vector3 = D.call((toe_dir + Vector3(0, 0, 0.15)).normalized())
		var sol := ik(hip_w, W.call(ankle_l), THIGH, SHIN, pole)
		j["knee_" + k] = sol[0]
		j["ankle_" + k] = sol[1]
		j["toe_" + k] = W.call(toe_l)
		j["heel_" + k] = W.call(heel_l)
		j["toe_dir_" + k] = D.call(toe_dir)
	# Torso, shoulders, neck, head.
	var neck_base_l := pelvis_l + spine * SPINE
	j["chest"] = W.call(pelvis_l + spine * 0.33)
	j["neck_base"] = W.call(neck_base_l)
	j["sh_l"] = W.call(neck_base_l - spine * 0.05 + side * 0.19)
	j["sh_r"] = W.call(neck_base_l - spine * 0.05 - side * 0.19)
	var neck_dir := (spine + U).normalized()
	var neck_top: Vector3 = W.call(neck_base_l + neck_dir * 0.1)
	j["neck_top"] = neck_top
	var look_dir := (look - neck_top).normalized()
	look_dir = look_dir.lerp(Vector3(0, 0, -1), dejected * 0.7).normalized()
	j["look"] = look_dir
	j["head"] = neck_top + (Vector3(0, 0, 1) * 0.85 + look_dir * 0.3).normalized() * HEAD_R
	# Bat: top (left) hand on the handle, bottom (right) hand below it.
	var bd: Vector3 = D.call(bat_dir(phi, tilt))
	var hand_top: Vector3 = W.call(hands_l)
	var hand_bot := hand_top + bd * GRIP_GAP
	var pole_l: Vector3 = D.call((Vector3(1, 0, 0) * 0.8 + F * 0.3 - U * 0.5).normalized().lerp(Vector3(0.6, -0.2, -0.8).normalized(), elbow_mix))
	var pole_r: Vector3 = D.call((-U * 0.9 - F * 0.4 - Vector3(1, 0, 0) * 0.2).normalized().lerp(Vector3(0.7, 0.4, 0.3).normalized(), elbow_mix))
	# Both hands must stay on the handle: if either arm cannot reach, ease the grip toward
	# that shoulder (as a real batter's hands drift), then solve the arms.
	var reach := UPPER_ARM + FOREARM - 0.004
	for it in 4:
		var dl_: float = j["sh_l"].distance_to(hand_top)
		if dl_ > reach:
			hand_top += (j["sh_l"] - hand_top).normalized() * (dl_ - reach)
		hand_bot = hand_top + bd * GRIP_GAP
		var dr_: float = j["sh_r"].distance_to(hand_bot)
		if dr_ > reach:
			hand_top += (j["sh_r"] - hand_bot).normalized() * (dr_ - reach)
	hand_bot = hand_top + bd * GRIP_GAP
	var sl := ik(j["sh_l"], hand_top, UPPER_ARM, FOREARM, pole_l)
	j["el_l"] = sl[0]
	j["wr_l"] = sl[1]
	hand_top = sl[1]
	hand_bot = hand_top + bd * GRIP_GAP
	var sr := ik(j["sh_r"], hand_bot, UPPER_ARM, FOREARM, pole_r)
	j["el_r"] = sr[0]
	j["wr_r"] = sr[1]
	j["hand_top"] = hand_top
	j["hand_bot"] = sr[1]
	j["bat_dir"] = bd
	j["bat_top"] = hand_top - bd * 0.07
	j["bat_shoulder"] = hand_top + bd * 0.27
	j["bat_toe"] = hand_top + bd * (BAT_LEN - 0.07)
	j["bat_sweet"] = hand_top + bd * SWEET
	# Face normal: the direction the swing is moving the blade, opened a touch.
	var p := deg_to_rad(phi)
	var face_l := Vector3(cos(p), 0.25, sin(p)).normalized()
	var face: Vector3 = D.call(face_l)
	face = (face - bd * face.dot(bd)).normalized()
	j["bat_face"] = face
	j["bat_width"] = bd.cross(face).normalized()
	return j

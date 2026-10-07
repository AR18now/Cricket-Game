class_name CricketerRig
extends Node2D
## Procedural, layered cartoon cricketer. Poses are dictionaries of joint angles (radians,
## measured from straight down, positive = toward the facing direction) or IK hand targets.
## Everything is drawn with vector shapes, so kits recolour freely.

const S := Proj.S
const THIGH := 0.46
const SHIN := 0.46
const TORSO := 0.54
const NECK := 0.07
const HEAD_R := 0.115
const UPPER_ARM := 0.31
const FOREARM := 0.29
const BAT_LEN := 0.86
const HANDLE := 0.27

var facing := -1.0
var pose: Dictionary = {}
var shirt := Color(0.07, 0.42, 0.33)
var trousers := Color(0.95, 0.94, 0.9)
var skin := Color(0.72, 0.5, 0.36)
var hair := Color(0.1, 0.08, 0.07)
var headgear := "cap"   # cap | helmet | hat | hair
var cap_color := Color(0.07, 0.42, 0.33)
var has_bat := false
var has_pads := false
var gloves := false
var keeper_gloves := false
var lift := 0.0
var show_shadow := true
var name_tag := ""
var tag_strong := false
var ball_in_hand := false
var outline := Color(0.12, 0.09, 0.08, 0.95)
var beard := false
var _font: Font

const DEFAULT_POSE := {
	"lean": 0.05, "thigh_f": 0.08, "shin_f": 0.0, "thigh_b": -0.08, "shin_b": -0.02,
	"arm_f_up": 0.15, "arm_f_lo": 0.35, "arm_b_up": -0.1, "arm_b_lo": 0.1, "head": 0.0,
}


func _ready() -> void:
	_font = ThemeDB.fallback_font
	if pose.is_empty():
		pose = DEFAULT_POSE.duplicate()


func set_pose(p: Dictionary) -> void:
	pose = p
	queue_redraw()


static func dir_down(a: float, f: float) -> Vector2:
	# Metres, y up.
	return Vector2(sin(a) * f, -cos(a))


static func dir_up(a: float, f: float) -> Vector2:
	return Vector2(sin(a) * f, cos(a))


static func _g(p: Dictionary, k: String, d: float = 0.0) -> float:
	return float(p.get(k, DEFAULT_POSE.get(k, d)))


## Joint positions in metres (x forward-signed, y up) relative to the feet origin.
func joints(p: Dictionary = pose) -> Dictionary:
	var f := facing
	var leg_f: float = THIGH * cos(_g(p, "thigh_f")) + SHIN * cos(_g(p, "shin_f"))
	var leg_b: float = THIGH * cos(_g(p, "thigh_b")) + SHIN * cos(_g(p, "shin_b"))
	var hip := Vector2(float(p.get("root_x", 0.0)) * f, maxf(leg_f, leg_b) + lift + float(p.get("bob", 0.0)))
	var j := {}
	j["hip"] = hip
	j["knee_f"] = hip + dir_down(_g(p, "thigh_f"), f) * THIGH
	j["foot_f"] = j["knee_f"] + dir_down(_g(p, "shin_f"), f) * SHIN
	j["knee_b"] = hip + dir_down(_g(p, "thigh_b"), f) * THIGH
	j["foot_b"] = j["knee_b"] + dir_down(_g(p, "shin_b"), f) * SHIN
	var shoulder: Vector2 = hip + dir_up(_g(p, "lean"), f) * TORSO
	j["shoulder"] = shoulder
	j["neck"] = shoulder + dir_up(_g(p, "lean") * 0.6 + _g(p, "head"), f) * NECK
	j["head"] = j["neck"] + dir_up(_g(p, "lean") * 0.5 + _g(p, "head"), f) * HEAD_R
	if p.has("hands"):
		var h: Vector2 = p["hands"]
		var target := shoulder + Vector2(h.x * f, h.y)
		j["hand_f"] = target
		j["hand_b"] = target + Vector2(0.02 * f, -0.09)
		j["elbow_f"] = _ik_elbow(shoulder + Vector2(0.04 * f, 0.0), target, 1.0)
		j["elbow_b"] = _ik_elbow(shoulder - Vector2(0.04 * f, 0.0), j["hand_b"], 1.0)
	else:
		j["elbow_f"] = shoulder + dir_down(_g(p, "arm_f_up"), f) * UPPER_ARM
		j["hand_f"] = j["elbow_f"] + dir_down(_g(p, "arm_f_lo"), f) * FOREARM
		j["elbow_b"] = shoulder + dir_down(_g(p, "arm_b_up"), f) * UPPER_ARM
		j["hand_b"] = j["elbow_b"] + dir_down(_g(p, "arm_b_lo"), f) * FOREARM
	if has_bat:
		var ba: float = _g(p, "bat", -0.3)
		var hands: Vector2 = (j["hand_f"] + j["hand_b"]) * 0.5
		j["bat_grip"] = hands + dir_down(ba, f) * 0.04
		j["bat_shoulder"] = hands + dir_down(ba, f) * HANDLE
		j["bat_tip"] = hands + dir_down(ba, f) * BAT_LEN
	return j


func _ik_elbow(a: Vector2, b: Vector2, bend: float) -> Vector2:
	var d := clampf(a.distance_to(b), 0.05, UPPER_ARM + FOREARM - 0.001)
	var cos_a := (UPPER_ARM * UPPER_ARM + d * d - FOREARM * FOREARM) / (2.0 * UPPER_ARM * d)
	var ang := acos(clampf(cos_a, -1.0, 1.0))
	var base := (b - a).normalized()
	# Elbows bend downward/backward.
	var side := -facing * bend
	return a + base.rotated(ang * side) * UPPER_ARM


static func px(m: Vector2) -> Vector2:
	return Vector2(m.x * S, -m.y * S)


## Hand position in canvas pixels relative to this node (used to place the ball in hand).
func hand_px(which: String = "b") -> Vector2:
	return px(joints()["hand_" + which])


## Light comes from the upper-left of the screen.
const LIGHT := Vector2(-0.6, -0.8)


func _seg(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	_taper(a, b, w, w, c)


## Tapered limb segment in metres (w0 at a, w1 at b) with soft shading.
func _taper(a: Vector2, b: Vector2, w0: float, w1: float, c: Color, shade: bool = true) -> void:
	var pa := px(a)
	var pb := px(b)
	var d := pb - pa
	if d.length() < 0.01:
		draw_circle(pa, w0 * 0.5 * S, c, true, -1.0, true)
		return
	var n := Vector2(-d.y, d.x).normalized()
	var h0 := w0 * 0.5 * S
	var h1 := w1 * 0.5 * S
	# Soft edge (darker tone of the same colour, not a black cartoon outline)
	var e := 1.4
	var edge := c.darkened(0.5)
	draw_colored_polygon(PackedVector2Array([pa + n * (h0 + e), pb + n * (h1 + e), pb - n * (h1 + e), pa - n * (h0 + e)]), edge)
	draw_circle(pa, h0 + e, edge, true, -1.0, true)
	draw_circle(pb, h1 + e, edge, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([pa + n * h0, pb + n * h1, pb - n * h1, pa - n * h0]), c)
	draw_circle(pa, h0, c, true, -1.0, true)
	draw_circle(pb, h1, c, true, -1.0, true)
	if shade:
		var lit := n if n.dot(LIGHT) > 0.0 else -n
		var hi := Color(1, 1, 1, 0.16)
		var lo := Color(0, 0, 0, 0.16)
		draw_colored_polygon(PackedVector2Array([pa + lit * h0 * 0.85, pb + lit * h1 * 0.85, pb + lit * h1 * 0.25, pa + lit * h0 * 0.25]), hi)
		draw_colored_polygon(PackedVector2Array([pa - lit * h0 * 0.95, pb - lit * h1 * 0.95, pb - lit * h1 * 0.45, pa - lit * h0 * 0.45]), lo)


func _limbs(j: Dictionary, grow: float, far: bool, col_mul: float) -> void:
	if grow > 0.0:
		return   # soft edges are drawn per segment now
	var side := "b" if far else "f"
	var tr := trousers.darkened(col_mul)
	var hip: Vector2 = j["hip"]
	var knee: Vector2 = j["knee_" + side]
	var foot: Vector2 = j["foot_" + side]
	# Thigh (thick at hip), shin with calf.
	_taper(hip, knee, 0.18, 0.12, tr)
	var calf := knee.lerp(foot, 0.35)
	_taper(knee, calf, 0.12, 0.125, tr)
	_taper(calf, foot, 0.125, 0.08, tr)
	# Trouser crease
	draw_line(px(hip.lerp(knee, 0.2)), px(knee.lerp(foot, 0.85)), tr.darkened(0.12), 1.0, true)
	if has_pads:
		var pad := Color(0.97, 0.96, 0.92).darkened(col_mul)
		var top := knee.lerp(hip, 0.2)
		var bot := foot.lerp(knee, 0.1)
		_taper(top, bot, 0.17, 0.14, pad)
		# Vertical ridges + knee roll
		var dd := (px(bot) - px(top)).normalized()
		var nn := Vector2(-dd.y, dd.x)
		for r in [-0.35, 0.0, 0.35]:
			draw_line(px(top) + nn * r * 0.15 * S, px(bot) + nn * r * 0.13 * S, pad.darkened(0.18), 1.2, true)
		draw_circle(px(knee), 0.08 * S, pad.darkened(0.06), true, -1.0, true)
	# Shoe: heel-to-toe shape with a sole.
	var f := facing
	var shoe := Color(0.94, 0.94, 0.95).darkened(col_mul) if has_pads else Color(0.2, 0.18, 0.18).darkened(col_mul)
	var heel := px(foot + Vector2(-0.05 * f, 0.02))
	var toe := px(foot + Vector2(0.17 * f, 0.0))
	var up := px(foot + Vector2(0.02 * f, 0.08))
	draw_colored_polygon(PackedVector2Array([heel, up, toe, toe + Vector2(0, 3.0), heel + Vector2(0, 3.0)]), shoe)
	draw_line(heel + Vector2(0, 3.0), toe + Vector2(0, 3.0), Color(0.15, 0.13, 0.12), 2.0, true)


func _arm(j: Dictionary, grow: float, side: String, col_mul: float) -> void:
	if grow > 0.0:
		return
	var sh := shirt.darkened(col_mul)
	var sk := skin.darkened(col_mul)
	var shoulder: Vector2 = j["shoulder"]
	var elbow: Vector2 = j["elbow_" + side]
	var hand: Vector2 = j["hand_" + side]
	# Upper arm: short sleeve over skin.
	_taper(shoulder, elbow, 0.12, 0.085, sk)
	var sleeve_end := shoulder.lerp(elbow, 0.62)
	_taper(shoulder, sleeve_end, 0.135, 0.11, sh)
	draw_line(px(sleeve_end) + Vector2(-3, 0).rotated((px(elbow) - px(shoulder)).angle() + PI * 0.5), px(sleeve_end) + Vector2(3, 0).rotated((px(elbow) - px(shoulder)).angle() + PI * 0.5), sh.darkened(0.25), 2.0, true)
	_taper(elbow, hand, 0.085, 0.062, sk)
	if gloves:
		var g := Color(0.96, 0.95, 0.92).darkened(col_mul)
		draw_circle(px(hand), 0.065 * S, g.darkened(0.4), true, -1.0, true)
		draw_circle(px(hand), 0.058 * S, g, true, -1.0, true)
		draw_line(px(hand) + Vector2(-3, -2), px(hand) + Vector2(3, -2), g.darkened(0.25), 1.0, true)
		draw_line(px(hand) + Vector2(-3, 1), px(hand) + Vector2(3, 1), g.darkened(0.25), 1.0, true)
	elif keeper_gloves:
		var kg := Color(0.95, 0.75, 0.2).darkened(col_mul)
		draw_circle(px(hand), 0.085 * S, kg.darkened(0.4), true, -1.0, true)
		draw_circle(px(hand), 0.078 * S, kg, true, -1.0, true)
	else:
		draw_circle(px(hand), 0.045 * S, sk, true, -1.0, true)


func _torso(j: Dictionary, grow: float) -> void:
	if grow > 0.0:
		return
	var hip: Vector2 = j["hip"]
	var sh: Vector2 = j["shoulder"]
	var axis := (sh - hip)
	var up := axis.normalized()
	var fwd := Vector2(up.y, -up.x) * -facing   # perpendicular, pointing to the facing side
	if fwd.x * facing < 0.0:
		fwd = -fwd
	# Front (chest) and back profiles along the spine: [t, front, back] in metres.
	var prof := [[0.0, 0.12, 0.13], [0.3, 0.11, 0.11], [0.62, 0.155, 0.12], [0.86, 0.14, 0.12], [1.0, 0.1, 0.1]]
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	for p in prof:
		var c: Vector2 = hip + axis * float(p[0])
		front.append(px(c + fwd * float(p[1])))
		back.append(px(c - fwd * float(p[2])))
	var poly := PackedVector2Array()
	poly.append_array(front)
	for k in range(back.size() - 1, -1, -1):
		poly.append(back[k])
	var edge := PackedVector2Array()
	var cen := px(hip.lerp(sh, 0.5))
	for v in poly:
		edge.append(cen + (v - cen) * 1.04 + (v - cen).normalized() * 1.2)
	draw_colored_polygon(edge, shirt.darkened(0.5))
	draw_colored_polygon(poly, shirt)
	# Shading: light on the upper-left side of the chest, shadow at the back/lower edge.
	var lit_side := front if (px(fwd) - px(Vector2.ZERO)).dot(LIGHT) > 0.0 else back
	var dark_side := back if lit_side == front else front
	var hl := PackedVector2Array()
	for k in lit_side.size():
		hl.append(lit_side[k].lerp(cen, 0.0))
	for k in range(lit_side.size() - 1, -1, -1):
		hl.append(lit_side[k].lerp(cen, 0.35))
	draw_colored_polygon(hl, Color(1, 1, 1, 0.12))
	var dl := PackedVector2Array()
	for k in dark_side.size():
		dl.append(dark_side[k])
	for k in range(dark_side.size() - 1, -1, -1):
		dl.append(dark_side[k].lerp(cen, 0.3))
	draw_colored_polygon(dl, Color(0, 0, 0, 0.14))
	# Waistband/belt and collar
	draw_line(px(hip + fwd * 0.12 + up * 0.03), px(hip - fwd * 0.13 + up * 0.03), trousers.darkened(0.2), 0.03 * S, true)
	draw_line(px(sh + fwd * 0.04), px(sh - up * 0.08 + fwd * 0.07), shirt.lightened(0.45), 2.0, true)
	draw_line(px(sh - fwd * 0.06), px(sh - up * 0.06), shirt.lightened(0.45), 2.0, true)


func _head(j: Dictionary) -> void:
	var f := facing
	var neck_b: Vector2 = j["shoulder"]
	var hc: Vector2 = j["head"]
	_taper(neck_b, j["neck"], 0.1, 0.085, skin.darkened(0.08), false)
	var h := px(hc)
	var r := HEAD_R * S
	var sk := skin
	# Skull + jaw (slightly oval, jaw forward), soft edge
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var rx := r * (1.0 if cos(a) * f < 0.0 else 1.05)
		var ry := r * (1.08 if sin(a) > 0.0 else 1.0)
		pts.append(h + Vector2(cos(a) * rx, sin(a) * ry))
	var e := PackedVector2Array()
	for v in pts:
		e.append(h + (v - h) * 1.0 + (v - h).normalized() * 1.3)
	draw_colored_polygon(e, sk.darkened(0.45))
	draw_colored_polygon(pts, sk)
	# Nose + chin on the facing side; ear on the back half.
	draw_colored_polygon(PackedVector2Array([h + Vector2(f * r * 0.92, -r * 0.15), h + Vector2(f * r * 1.22, r * 0.18), h + Vector2(f * r * 0.92, r * 0.24)]), sk.darkened(0.06))
	draw_circle(h + Vector2(-f * r * 0.15, r * 0.05), r * 0.2, sk.darkened(0.12), true, -1.0, true)
	draw_circle(h + Vector2(f * r * 0.55, -r * 0.08), 1.5, Color(0.1, 0.07, 0.06), true, -1.0, true)
	draw_line(h + Vector2(f * r * 0.38, -r * 0.3), h + Vector2(f * r * 0.8, -r * 0.32), hair.lightened(0.05), 1.6, true)
	draw_line(h + Vector2(f * r * 0.62, r * 0.55), h + Vector2(f * r * 0.85, r * 0.5), sk.darkened(0.3), 1.2, true)
	if beard:
		var bd := PackedVector2Array([h + Vector2(-f * r * 0.1, r * 0.35), h + Vector2(f * r * 0.95, r * 0.4), h + Vector2(f * r * 0.7, r * 1.1), h + Vector2(-f * r * 0.05, r * 0.9)])
		draw_colored_polygon(bd, hair.lightened(0.05))
	# Shade the back of the head slightly.
	draw_circle(h + Vector2(-f * r * 0.35, r * 0.2), r * 0.55, Color(0, 0, 0, 0.07), true, -1.0, true)
	match headgear:
		"helmet":
			var dome := PackedVector2Array()
			for i in 15:
				var a := PI * 0.95 + PI * 1.05 * i / 14.0  # ends level so the visor never crosses the dome
				dome.append(h + Vector2(f * cos(a) * (r + 3.5), sin(a) * (r + 3.5) - 1.0))  # mirrored with facing
			dome.append(h + Vector2(f * (r + 9.0), -r * 0.05))
			dome.append(h + Vector2(-f * (r * 0.2), r * 0.1))
			draw_colored_polygon(dome, cap_color)
			draw_polyline(dome, cap_color.darkened(0.5), 1.5, true)
			draw_arc(h + Vector2(-f * r * 0.1, -r * 0.2), r * 0.7, PI * 1.15, PI * 1.6, 8, cap_color.lightened(0.35), 2.0, true)
			# Grille (steel) in front of the face + neck guard
			for k in 4:
				var gx := h.x + f * (r * 0.5 + k * 2.4)
				draw_line(Vector2(gx, h.y - r * 0.05), Vector2(gx + f * 1.2, h.y + r * 0.95), Color(0.78, 0.8, 0.84), 1.3, true)
			draw_line(h + Vector2(f * r * 0.45, r * 0.45), h + Vector2(f * (r + 6.0), r * 0.45), Color(0.78, 0.8, 0.84), 1.3, true)
			draw_rect(Rect2(h + Vector2(-f * r * 1.05 - (2.0 if f > 0 else 0.0), r * 0.15), Vector2(4.0, r * 0.7)), cap_color.darkened(0.2))
		"cap":
			var cap := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				cap.append(h + Vector2(cos(a) * (r + 1.8), sin(a) * (r + 1.8) - 1.0))
			draw_colored_polygon(cap, cap_color)
			draw_arc(h + Vector2(0, -1.0), r * 0.7, PI * 1.2, PI * 1.55, 6, cap_color.lightened(0.3), 1.5, true)
			draw_colored_polygon(PackedVector2Array([h + Vector2(f * r * 0.3, -r * 0.25), h + Vector2(f * (r + 9.0), -r * 0.12), h + Vector2(f * (r + 8.0), -r * 0.02), h + Vector2(f * r * 0.3, -r * 0.1)]), cap_color.darkened(0.25))
		"hat":
			draw_colored_polygon(PackedVector2Array([h + Vector2(-r - 7.0, -r * 0.3), h + Vector2(r + 7.0, -r * 0.3), h + Vector2(r + 5.0, -r * 0.18), h + Vector2(-r - 5.0, -r * 0.18)]), Color(0.96, 0.95, 0.9))
			draw_rect(Rect2(h + Vector2(-r * 0.78, -r * 1.25), Vector2(r * 1.56, r * 0.95)), Color(0.96, 0.95, 0.9))
			draw_line(h + Vector2(-r * 0.78, -r * 0.45), h + Vector2(r * 0.78, -r * 0.45), Color(0.2, 0.2, 0.25), 2.0, true)
		_:
			var hr := PackedVector2Array()
			for i in 13:
				var a := PI * 0.9 + PI * 1.2 * i / 12.0
				hr.append(h + Vector2(cos(a) * (r + 1.5), sin(a) * (r + 1.5)))
			hr.append(h + Vector2(-f * r * 0.85, r * 0.35))
			hr.append(h + Vector2(-f * r * 0.2, -r * 0.2))
			draw_colored_polygon(hr, hair)
			draw_arc(h + Vector2(-f * r * 0.2, -r * 0.3), r * 0.6, PI * 1.2, PI * 1.6, 6, hair.lightened(0.2), 1.5, true)


func _bat(j: Dictionary) -> void:
	var grip: Vector2 = px(j["bat_grip"])
	var sh: Vector2 = px(j["bat_shoulder"])
	var tip: Vector2 = px(j["bat_tip"])
	var d := (tip - sh).normalized()
	var n := Vector2(-d.y, d.x)
	var w := 0.055 * S
	var blade := PackedVector2Array([sh + n * w * 0.75, sh + d * w * 2.0 + n * w, tip - d * 2.0 + n * w, tip + n * w * 0.6, tip - n * w * 0.6, tip - d * 2.0 - n * w, sh + d * w * 2.0 - n * w, sh - n * w * 0.75])
	var edge := PackedVector2Array()
	var c := (sh + tip) * 0.5
	for v in blade:
		edge.append(v + (v - c).normalized() * 1.4)
	draw_colored_polygon(edge, Color(0.45, 0.33, 0.2))
	draw_colored_polygon(blade, Color(0.93, 0.83, 0.6))
	draw_colored_polygon(PackedVector2Array([sh + n * w * 0.7, tip + n * w * 0.9, tip + n * w * 0.2, sh + n * w * 0.15]), Color(1, 1, 1, 0.18))
	draw_line(sh - n * w * 0.5, tip - n * w * 0.6, Color(0.78, 0.64, 0.42), 1.5, true)
	# Grain and sticker band
	draw_line(sh + d * w * 3.0 - n * w * 0.9, sh + d * w * 3.0 + n * w * 0.9, Color(0.1, 0.42, 0.3), 2.5, true)
	draw_line(grip - d * 3.0, sh, Color(0.2, 0.1, 0.08), 0.034 * S + 2.0, true)
	draw_line(grip - d * 3.0, sh, Color(0.12, 0.38, 0.28), 0.034 * S, true)
	for k in 4:
		var q := (grip - d * 3.0).lerp(sh, 0.15 + k * 0.2)
		draw_line(q - n * 2.5, q + n * 2.5, Color(0.08, 0.25, 0.18), 1.0, true)


func _draw() -> void:
	var j := joints()
	if show_shadow:
		# Soft contact shadow, longer than wide, cast slightly away from the light.
		var shadow_alpha := clampf(0.3 - lift * 0.3, 0.08, 0.3)
		draw_set_transform(Vector2(6.0, 1.0), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 0.5 * S, Color(0.0, 0.0, 0.0, shadow_alpha * 0.5), true, -1.0, true)
		draw_circle(Vector2.ZERO, 0.32 * S, Color(0.0, 0.0, 0.0, shadow_alpha * 0.7), true, -1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bat_behind := has_bat and float(pose.get("bat_layer", 1.0)) < 0.0
	if bat_behind:
		_bat(j)
	_limbs(j, 0.0, true, 0.18)
	_arm(j, 0.0, "b", 0.18)
	_torso(j, 0.0)
	_limbs(j, 0.0, false, 0.0)
	_head(j)
	if has_bat and not bat_behind:
		_bat(j)
	_arm(j, 0.0, "f", 0.0)
	if ball_in_hand:
		draw_circle(px(j["hand_b"]), 4.0, Color(0.1, 0.08, 0.05), true, -1.0, true)
		draw_circle(px(j["hand_b"]), 3.0, Color(1.0, 0.93, 0.4), true, -1.0, true)
	if name_tag != "":
		var top := px(j["head"]) + Vector2(0, -HEAD_R * S - 16.0)
		var fs := 15
		var tw := _font.get_string_size(name_tag, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var bg := Color(0.04, 0.2, 0.16, 0.85) if tag_strong else Color(0.1, 0.1, 0.1, 0.55)
		draw_rect(Rect2(top + Vector2(-tw * 0.5 - 6.0, -14.0), Vector2(tw + 12.0, 19.0)), bg)
		if tag_strong:
			draw_rect(Rect2(top + Vector2(-tw * 0.5 - 6.0, 5.0), Vector2(tw + 12.0, 2.0)), Color(0.98, 0.8, 0.3))
		draw_string(_font, top + Vector2(-tw * 0.5, 0.0), name_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))

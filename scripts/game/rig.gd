class_name CricketerRig
extends Node2D
## Procedural, layered cartoon cricketer. Poses are dictionaries of joint angles (radians,
## measured from straight down, positive = toward the facing direction) or IK hand targets.
## Everything is drawn with vector shapes, so kits recolour freely.

const S := Proj.S
const THIGH := 0.46
const SHIN := 0.46
const TORSO := 0.56
const NECK := 0.07
const HEAD_R := 0.125
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


func _seg(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	var pa := px(a)
	var pb := px(b)
	var wp := w * S
	draw_line(pa, pb, c, wp, true)
	draw_circle(pa, wp * 0.5, c, true, -1.0, true)
	draw_circle(pb, wp * 0.5, c, true, -1.0, true)


func _limbs(j: Dictionary, grow: float, far: bool, col_mul: float) -> void:
	var o := grow
	var tr := trousers.darkened(col_mul) if grow == 0.0 else outline
	var sh := shirt.darkened(col_mul) if grow == 0.0 else outline
	var sk := skin.darkened(col_mul) if grow == 0.0 else outline
	var side := "b" if far else "f"
	# leg
	_seg(j["hip"], j["knee_" + side], 0.15 + o, tr)
	_seg(j["knee_" + side], j["foot_" + side], 0.13 + o, tr)
	if has_pads:
		var pad := Color(0.97, 0.96, 0.92).darkened(col_mul) if grow == 0.0 else outline
		_seg(j["knee_" + side].lerp(j["hip"], 0.15), j["foot_" + side].lerp(j["knee_" + side], 0.12), 0.16 + o, pad)
	var foot: Vector2 = j["foot_" + side]
	var shoe := Color(0.16, 0.14, 0.14) if grow == 0.0 else outline
	_seg(foot + Vector2(-0.03 * facing, 0.03), foot + Vector2(0.13 * facing, 0.03), 0.08 + o, shoe)


func _arm(j: Dictionary, grow: float, side: String, col_mul: float) -> void:
	var sh := shirt.darkened(col_mul) if grow == 0.0 else outline
	var sk := skin.darkened(col_mul) if grow == 0.0 else outline
	_seg(j["shoulder"], j["elbow_" + side], 0.1 + grow, sh)
	_seg(j["elbow_" + side], j["hand_" + side], 0.085 + grow, sk)
	var hand_col := sk
	if (gloves or keeper_gloves) and grow == 0.0:
		hand_col = Color(0.96, 0.95, 0.9).darkened(col_mul) if gloves else Color(0.95, 0.75, 0.2).darkened(col_mul)
	var hr := (0.075 if keeper_gloves else 0.055) + grow * 0.5
	draw_circle(px(j["hand_" + side]), hr * S, hand_col, true, -1.0, true)


func _torso(j: Dictionary, grow: float) -> void:
	var c := shirt if grow == 0.0 else outline
	_seg(j["hip"] + dir_up(0.0, facing) * 0.08, j["shoulder"], 0.3 + grow, c)
	if grow == 0.0:
		# Trousers waist band and a small kit trim for readability.
		_seg(j["hip"], j["hip"] + dir_up(pose.get("lean", 0.0), facing) * 0.06, 0.28, trousers)
		var trim := shirt.lightened(0.35)
		_seg(j["shoulder"] + Vector2(0.0, -0.06), j["shoulder"] + Vector2(0.0, -0.06) + dir_down(pose.get("lean", 0.0), facing) * 0.18, 0.05, trim)


func _head(j: Dictionary) -> void:
	var h := px(j["head"])
	var r := HEAD_R * S
	draw_circle(px(j["neck"]), 0.06 * S, skin.darkened(0.1), true, -1.0, true)
	draw_circle(h, r + 0.035 * S, outline, true, -1.0, true)
	draw_circle(h, r, skin, true, -1.0, true)
	var f := facing
	match headgear:
		"helmet":
			var dome := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				dome.append(h + Vector2(cos(a) * (r + 3.0), sin(a) * (r + 3.0) - 1.0))
			dome.append(h + Vector2(f * (r + 6.0), -1.0))
			draw_colored_polygon(dome, cap_color)
			draw_polyline(dome, outline, 2.0, true)
			# Grille
			for k in 3:
				var gx := h.x + f * (r * 0.55 + k * 2.2)
				draw_line(Vector2(gx, h.y - 1.0), Vector2(gx + f * 1.5, h.y + r * 0.85), Color(0.75, 0.75, 0.78), 1.4, true)
		"cap":
			var cap := PackedVector2Array()
			for i in 11:
				var a := PI + PI * i / 10.0
				cap.append(h + Vector2(cos(a) * (r + 1.5), sin(a) * (r + 1.5) - 0.5))
			draw_colored_polygon(cap, cap_color)
			draw_line(h + Vector2(f * r * 0.2, -r * 0.2), h + Vector2(f * (r + 7.0), -r * 0.1), cap_color.darkened(0.25), 3.0, true)
		"hat":
			draw_line(h + Vector2(-r - 5.0, -r * 0.35), h + Vector2(r + 5.0, -r * 0.35), Color(0.95, 0.93, 0.85), 3.0, true)
			draw_rect(Rect2(h + Vector2(-r * 0.75, -r * 1.2), Vector2(r * 1.5, r * 0.85)), Color(0.95, 0.93, 0.85))
		_:
			var hr := PackedVector2Array()
			for i in 11:
				var a := PI + PI * i / 10.0
				hr.append(h + Vector2(cos(a) * (r + 1.0), sin(a) * (r + 1.0) + 1.0))
			hr.append(h + Vector2(-f * r * 0.9, r * 0.3))
			draw_colored_polygon(hr, hair)
	# Eye and ear (facing cue).
	draw_circle(h + Vector2(f * r * 0.5, -r * 0.05), 1.4, Color(0.1, 0.07, 0.06), true, -1.0, true)


func _bat(j: Dictionary) -> void:
	var grip: Vector2 = px(j["bat_grip"])
	var sh: Vector2 = px(j["bat_shoulder"])
	var tip: Vector2 = px(j["bat_tip"])
	var d := (tip - sh).normalized()
	var n := Vector2(-d.y, d.x)
	var w := 0.055 * S
	var blade := PackedVector2Array([sh + n * w * 0.7, tip + n * w, tip - n * w, sh - n * w * 0.7])
	var edge := PackedVector2Array([sh + n * (w * 0.7 + 1.5), tip + n * (w + 1.5) + d * 1.5, tip - n * (w + 1.5) + d * 1.5, sh - n * (w * 0.7 + 1.5)])
	draw_colored_polygon(edge, outline)
	draw_colored_polygon(blade, Color(0.93, 0.82, 0.58))
	draw_line(sh + n * w * 0.2, tip + n * w * 0.25, Color(0.82, 0.68, 0.45), 1.5, true)
	draw_line(grip - d * 3.0, sh, outline, 0.03 * S + 2.0, true)
	draw_line(grip - d * 3.0, sh, Color(0.75, 0.15, 0.12), 0.03 * S, true)


func _draw() -> void:
	var j := joints()
	if show_shadow:
		var sw := 0.42 * S
		var shadow_alpha := clampf(0.32 - lift * 0.3, 0.08, 0.32)
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, sw, Color(0.0, 0.0, 0.0, shadow_alpha), true, -1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bat_behind := has_bat and float(pose.get("bat_layer", 1.0)) < 0.0
	if bat_behind:
		_bat(j)
	# Outline pass (silhouette), then fills far -> near.
	_limbs(j, 0.05, true, 0.0)
	_arm(j, 0.05, "b", 0.0)
	_torso(j, 0.05)
	_limbs(j, 0.05, false, 0.0)
	_limbs(j, 0.0, true, 0.22)
	_arm(j, 0.0, "b", 0.2)
	_torso(j, 0.0)
	_limbs(j, 0.0, false, 0.0)
	_head(j)
	if has_bat and not bat_behind:
		_bat(j)
	_arm(j, 0.05, "f", 0.0)
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

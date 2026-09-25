class_name StumpsView
extends Node2D
## Three stumps + two bails. Stumps are fanned slightly in screen space for readability.
## `broken_t` >= 0 animates a bowled dismissal (bails fly, stumps splay).

var broken_t := -1.0
var facing := 1.0


func _draw() -> void:
	var h := Delivery.STUMPS_HEIGHT * Proj.S
	var wood := Color(0.96, 0.9, 0.74)
	var ink := Color(0.15, 0.1, 0.08)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2(0, 0), 12.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bt := maxf(broken_t, 0.0)
	for i in 3:
		var base := Vector2((i - 1) * 5.0, (i - 1) * 1.5)
		var tilt := 0.0
		if broken_t >= 0.0:
			tilt = minf(bt * 6.0, 1.0) * (0.55 if i == 1 else (0.3 if i == 2 else -0.2)) * facing
		var top := base + Vector2(sin(tilt) * h, -cos(tilt) * h)
		draw_line(base, top, ink, 5.0, true)
		draw_line(base, top, wood, 3.0, true)
	# Bails
	for k in 2:
		var p := Vector2(-2.5 + k * 5.0, -h - 1.0)
		if broken_t >= 0.0:
			var tt := minf(bt, 1.2)
			p += Vector2((18.0 + k * 10.0) * tt * facing, -60.0 * tt + 120.0 * tt * tt)
		draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), ink, 4.0, true)
		draw_line(p + Vector2(-2.5, 0), p + Vector2(2.5, 0), wood, 2.0, true)

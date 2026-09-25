class_name BallShadow
extends Node2D
## Ground shadow for the ball: shrinks and fades with height; a thin stalk links a high
## ball to its shadow so the landing point is readable.


func _draw() -> void:
	var h: float = get_meta("h", 0.0)
	var z: float = get_meta("z", 1.0)
	var s := 1.0 / maxf(z, 0.05)
	var r := (6.0 * s) * clampf(1.0 - h * 0.04, 0.5, 1.0)
	var a := clampf(0.45 - h * 0.02, 0.18, 0.45)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r, Color(0.05, 0.03, 0.02, a), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if h > 1.5:
		var top := Vector2(0, -h * Proj.S)
		var n := int(h * 2.0)
		for i in n:
			var y0 := -float(i) / n * h * Proj.S
			if i % 2 == 0:
				draw_line(Vector2(0, y0), Vector2(0, y0 - h * Proj.S / n), Color(1, 1, 1, 0.18), 1.2 * s)

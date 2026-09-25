class_name NearWall
extends Node2D
## Low foreground courtyard wall with spectators, drawn in front of play (bottom of view).

var rng_seed := 99


func _draw() -> void:
	var rng := DetRng.new(rng_seed)
	var y := GroundView.NEAR_WALL_Y
	var a := Proj.to_screen(Vector3(GroundView.X_MIN, y, 0.0)) - position
	var b := Proj.to_screen(Vector3(GroundView.X_MAX, y, 1.3)) - position
	var rect := Rect2(Vector2(a.x, b.y), Vector2(b.x - a.x, a.y - b.y + 1400.0))
	# Spectators sitting on/behind the wall.
	var x := GroundView.X_MIN + 1.0
	while x < GroundView.X_MAX:
		if rng.chance(0.55):
			var p := Proj.to_screen(Vector3(x, y + 0.3, 1.3)) - position
			var shirt: Color = [GroundView.EMERALD, Color(0.95, 0.93, 0.88), GroundView.TERRACOTTA, Color(0.3, 0.45, 0.7), Color(0.55, 0.2, 0.35)][rng.range_i(0, 4)]
			draw_rect(Rect2(p + Vector2(-16, -44), Vector2(32, 50)), GroundView.INK)
			draw_rect(Rect2(p + Vector2(-14, -42), Vector2(28, 48)), shirt.darkened(0.2))
			draw_circle(p + Vector2(0, -56), 13.0, GroundView.INK)
			draw_circle(p + Vector2(0, -56), 11.0, Color(0.55, 0.38, 0.28))
			draw_circle(p + Vector2(0, -60), 10.0, Color(0.1, 0.08, 0.07))
		x += rng.range_f(1.2, 2.6)
	draw_rect(rect, GroundView.BRICK_DARK)
	var row := 0
	var ry := rect.position.y
	while ry < rect.end.y:
		draw_line(Vector2(rect.position.x, ry), Vector2(rect.end.x, ry), GroundView.MORTAR.darkened(0.3), 1.5)
		var bx := rect.position.x + (0.0 if row % 2 == 0 else 20.0)
		while bx < rect.end.x:
			draw_line(Vector2(bx, ry), Vector2(bx, ry + 14.0), GroundView.MORTAR.darkened(0.35), 1.5)
			bx += 40.0
		ry += 14.0
		row += 1
	draw_rect(Rect2(rect.position + Vector2(0, -8), Vector2(rect.size.x, 12)), GroundView.PLASTER.darkened(0.2))

class_name MenuShade
extends Control
## Soft gradients so the menu reads clearly over the living ground: from the left in
## landscape (the card side), from the bottom and a little from the top in portrait.

var portrait := false:
	set(v):
		if v != portrait:
			portrait = v
			queue_redraw()


func _draw() -> void:
	var dark := Color(0.01, 0.1, 0.08, 0.82)
	var clear := Color(0.01, 0.1, 0.08, 0.0)
	if portrait:
		var top := size.y * 0.3
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, top), Vector2(0, top)]),
			PackedColorArray([Color(0.01, 0.1, 0.08, 0.55), Color(0.01, 0.1, 0.08, 0.55), clear, clear]))
		var y0 := size.y * 0.42
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([clear, clear, dark, dark]))
		return
	var w := minf(size.x * 0.62, 820.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)]),
		PackedColorArray([dark, clear, clear, dark]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

class_name MenuShade
extends Control
## Left-side gradient so menu text stays legible over the living ground.


func _draw() -> void:
	var w := minf(size.x * 0.62, 820.0)
	var dark := Color(0.01, 0.1, 0.08, 0.8)
	var clear := Color(0.01, 0.1, 0.08, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)]),
		PackedColorArray([dark, clear, clear, dark]))

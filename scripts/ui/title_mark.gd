class_name TitleMark
extends Control
## Vector word-mark for the provisional title (no bitmap logo). Bat + ball emblem.


func _draw() -> void:
	var f := UiTheme.font("black")
	var h := size.y
	# Emblem: tape ball crossing a bat.
	var c := Vector2(h * 0.45, h * 0.5)
	draw_circle(c, h * 0.42, UiTheme.EMERALD)
	draw_arc(c, h * 0.42, 0, TAU, 48, UiTheme.GOLD, 4.0, true)
	var d := Vector2(0.55, -0.83)
	var n := Vector2(-d.y, d.x)
	var bat := PackedVector2Array([c - d * h * 0.3 + n * 9, c + d * h * 0.18 + n * 11, c + d * h * 0.18 - n * 11, c - d * h * 0.3 - n * 9])
	draw_colored_polygon(bat, Color(0.93, 0.82, 0.58))
	draw_line(c + d * h * 0.18, c + d * h * 0.33, UiTheme.TERRACOTTA, 7.0, true)
	var bc := c + Vector2(h * 0.14, h * 0.12)
	draw_circle(bc, h * 0.1, UiTheme.INK)
	draw_circle(bc, h * 0.085, Color(1.0, 0.95, 0.52))
	draw_line(bc + Vector2(-h * 0.08, -h * 0.02), bc + Vector2(h * 0.08, h * 0.03), Color(0.85, 0.12, 0.12), h * 0.04, true)
	var x := h * 0.98
	draw_string(f, Vector2(x + 3, h * 0.5 + 3), "POCKET", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.36), UiTheme.INK)
	draw_string(f, Vector2(x, h * 0.5), "POCKET", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.36), UiTheme.OFF_WHITE)
	draw_string(f, Vector2(x + 3, h * 0.9 + 3), "BOUNDARY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.36), UiTheme.INK)
	draw_string(f, Vector2(x, h * 0.9), "BOUNDARY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.36), UiTheme.GOLD)

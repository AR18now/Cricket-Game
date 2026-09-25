class_name TimingMeter
extends Control
## Early <- | PERFECT | -> Late meter showing where the swing landed.

var dt_ms := 0.0
var has_value := false
var cat := ""


func _ready() -> void:
	custom_minimum_size = Vector2(240, 30)


func set_value(c: ContactResult) -> void:
	dt_ms = c.dt_ms
	cat = c.category
	has_value = c.swung
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var mid := w * 0.5
	var f := UiTheme.font("bold")
	draw_rect(Rect2(0, h * 0.35, w, 8), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(mid - 16, h * 0.35 - 3, 32, 14), UiTheme.GOLD.darkened(0.1))
	draw_string(f, Vector2(0, h), "EARLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.SAND)
	draw_string(f, Vector2(w - 36, h), "LATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.SAND)
	if has_value:
		var x := clampf(mid + dt_ms / 150.0 * mid, 4.0, w - 4.0)
		var tri := PackedVector2Array([Vector2(x - 8, 0), Vector2(x + 8, 0), Vector2(x, 14)])
		draw_colored_polygon(tri, UiTheme.OFF_WHITE)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), UiTheme.INK, 2.0, true)

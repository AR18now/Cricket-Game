class_name TitleMark
extends Control
## Word-mark for the title, with the app icon as its emblem.

const ICON := preload("res://assets/icons/icon_192.png")


func _draw() -> void:
	var f := UiTheme.font("black")
	var h := size.y
	# Emblem: the app icon itself (rounded square, rendered from icon.svg).
	var side := h * 0.88
	draw_texture_rect(ICON, Rect2(Vector2(h * 0.02, (h - side) * 0.5), Vector2(side, side)), false)
	var x := h * 0.98
	draw_string(f, Vector2(x + 3, h * 0.5 + 3), "TAP TAP", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.36), UiTheme.INK)
	draw_string(f, Vector2(x, h * 0.5), "TAP TAP", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.36), UiTheme.OFF_WHITE)
	draw_string(f, Vector2(x + 3, h * 0.9 + 3), "CRICKET", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.36), UiTheme.INK)
	draw_string(f, Vector2(x, h * 0.9), "CRICKET", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.36), UiTheme.GOLD)

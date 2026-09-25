class_name IconButton
extends Button
## Button with a crisp vector icon (no font glyph dependency). Text is used as the
## accessible tooltip / label.

var icon_kind := "pause"   # pause | sound_on | sound_off | back | gear | card | replay
var accent := UiTheme.OFF_WHITE


static func make(kind: String, tip: String, size: float = 64.0) -> IconButton:
	var b := IconButton.new()
	b.icon_kind = kind
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_ALL
	var sb := UiTheme.panel_box(UiTheme.PANEL, int(size * 0.3), UiTheme.GOLD.darkened(0.3), 2)
	b.add_theme_stylebox_override("normal", sb)
	var h := sb.duplicate()
	h.border_color = UiTheme.GOLD
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	return b


func set_kind(kind: String) -> void:
	icon_kind = kind
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.22
	var col := accent
	match icon_kind:
		"pause":
			draw_rect(Rect2(c + Vector2(-s * 0.9, -s), Vector2(s * 0.6, s * 2)), col)
			draw_rect(Rect2(c + Vector2(s * 0.3, -s), Vector2(s * 0.6, s * 2)), col)
		"sound_on", "sound_off":
			var body := PackedVector2Array([c + Vector2(-s * 1.1, -s * 0.45), c + Vector2(-s * 0.5, -s * 0.45), c + Vector2(s * 0.2, -s * 1.1),
				c + Vector2(s * 0.2, s * 1.1), c + Vector2(-s * 0.5, s * 0.45), c + Vector2(-s * 1.1, s * 0.45)])
			draw_colored_polygon(body, col)
			if icon_kind == "sound_on":
				draw_arc(c + Vector2(s * 0.3, 0), s * 0.7, -0.9, 0.9, 12, col, 3.0, true)
				draw_arc(c + Vector2(s * 0.3, 0), s * 1.2, -0.9, 0.9, 12, col, 3.0, true)
			else:
				draw_line(c + Vector2(s * 0.5, -s * 0.6), c + Vector2(s * 1.4, s * 0.6), UiTheme.DANGER, 4.0, true)
				draw_line(c + Vector2(s * 1.4, -s * 0.6), c + Vector2(s * 0.5, s * 0.6), UiTheme.DANGER, 4.0, true)
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(s * 0.5, -s), c + Vector2(-s * 0.5, 0), c + Vector2(s * 0.5, s)]), col, 5.0, true)
		"gear":
			draw_arc(c, s * 0.9, 0, TAU, 24, col, 4.0, true)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.9, c + Vector2(cos(a), sin(a)) * s * 1.35, col, 4.0, true)
			draw_circle(c, s * 0.3, col)
		"card":
			for i in 3:
				draw_line(c + Vector2(-s, -s * 0.7 + i * s * 0.7), c + Vector2(s, -s * 0.7 + i * s * 0.7), col, 4.0, true)
		"camera":
			draw_rect(Rect2(c + Vector2(-s * 1.2, -s * 0.7), Vector2(s * 1.8, s * 1.4)), col, false, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.6, -s * 0.2), c + Vector2(s * 1.3, -s * 0.7), c + Vector2(s * 1.3, s * 0.7), c + Vector2(s * 0.6, s * 0.2)]), col)
			draw_circle(c + Vector2(-s * 0.3, 0), s * 0.35, col)
		"replay":
			draw_arc(c, s, 0.6, TAU - 0.2, 20, col, 4.0, true)
			var tip := c + Vector2(cos(0.6), sin(0.6)) * s
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.5, -s * 0.1), tip + Vector2(s * 0.4, -s * 0.2), tip + Vector2(0, s * 0.5)]), col)

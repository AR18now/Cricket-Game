class_name SwingButton
extends Control
## The main batting control. Fires on press-down (lowest latency). Glows while the batting
## window is open, squashes when pressed and bursts when a swing is accepted.
## Tapping anywhere else on the field also swings; this is the clear, thumb-sized target.

signal swing_pressed

var ready_glow := 0.0     # 0..1, driven by the controller's batting window
var _press := 0.0
var _burst := -1.0
var _t := 0.0
var active := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(176, 176)
	tooltip_text = "Swing (tap, click or Space)"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press = 1.0
		swing_pressed.emit()
		accept_event()


func accepted() -> void:
	_burst = 0.0


func _process(delta: float) -> void:
	_t += delta
	_press = maxf(0.0, _press - delta * 7.0)
	if _burst >= 0.0:
		_burst += delta
		if _burst > 0.4:
			_burst = -1.0
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42 * (1.0 - 0.07 * _press)
	var glow := ready_glow if active else 0.0
	# Soft drop shadow
	for i in 4:
		draw_circle(c + Vector2(0, 6), r + 10.0 - i * 3.0, Color(0, 0, 0, 0.08))
	# Ready glow halo (pulses gently while the ball can be hit)
	if glow > 0.01:
		var p := 0.5 + 0.5 * sin(_t * 9.0)
		for i in 5:
			draw_circle(c, r + 6.0 + i * 5.0 + p * 4.0, Color(1.0, 0.8, 0.3, 0.07 * glow))
	# Body: radial gradient emerald
	var steps := 14
	for i in steps:
		var k := float(i) / steps
		var col := UiTheme.EMERALD_DEEP.lerp(UiTheme.EMERALD.lightened(0.18), k)
		if glow > 0.0:
			col = col.lerp(UiTheme.TERRACOTTA, 0.35 * glow * k)
		draw_circle(c + Vector2(0, -r * 0.08 * k), r * (1.0 - k * 0.55), col, true, -1.0, true)
	# Gloss highlight
	draw_circle(c + Vector2(-r * 0.25, -r * 0.35), r * 0.32, Color(1, 1, 1, 0.08), true, -1.0, true)
	# Rim
	var rim := UiTheme.GOLD.darkened(0.25).lerp(UiTheme.GOLD.lightened(0.2), glow)
	draw_arc(c, r, 0, TAU, 64, UiTheme.INK, 9.0, true)
	draw_arc(c, r, 0, TAU, 64, rim, 5.0 + 2.0 * glow, true)
	# Bat icon
	var d := Vector2(0.62, -0.78)
	var n := Vector2(-d.y, d.x)
	var base := c + Vector2(-r * 0.18, r * 0.22)
	var blade := PackedVector2Array([base + n * 9.0, base + d * r * 0.58 + n * 11.0, base + d * r * 0.58 - n * 11.0, base - n * 9.0])
	draw_colored_polygon(blade, Color(0.95, 0.85, 0.6))
	var outline := blade.duplicate()
	outline.append(blade[0])
	draw_polyline(outline, UiTheme.INK, 2.5, true)
	draw_line(base - d * r * 0.02, base - d * r * 0.26, UiTheme.INK, 9.0, true)
	draw_line(base - d * r * 0.02, base - d * r * 0.26, UiTheme.TERRACOTTA, 6.0, true)
	var bc := c + Vector2(r * 0.3, r * 0.1)
	draw_circle(bc, r * 0.14, UiTheme.INK, true, -1.0, true)
	draw_circle(bc, r * 0.11, Color(1.0, 0.95, 0.52), true, -1.0, true)
	draw_line(bc + Vector2(-r * 0.1, -r * 0.03), bc + Vector2(r * 0.1, r * 0.04), Color(0.85, 0.12, 0.12), r * 0.05, true)
	# Label
	var f := UiTheme.font("black")
	var fs := int(r * 0.24)
	var tw := f.get_string_size("SWING", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-tw * 0.5 + 2, r * 0.66 + 2), "SWING", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.INK)
	draw_string(f, c + Vector2(-tw * 0.5, r * 0.66), "SWING", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.OFF_WHITE)
	# Accepted burst
	if _burst >= 0.0:
		var k2 := _burst / 0.4
		draw_arc(c, r + 10.0 + 40.0 * k2, 0, TAU, 48, Color(1.0, 0.9, 0.5, 1.0 - k2), 5.0 * (1.0 - k2) + 1.0, true)

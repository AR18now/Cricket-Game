class_name MilestoneCelebration
extends Control
## Fifty / hundred celebration: the screen dims, golden rays turn behind a big "50" or
## "100", "FIFTY!" / "HUNDRED!" lands, then the innings line (balls, fours, sixes), with
## sparkles. It never takes input (a tap skips the pause through the controller) and
## fades itself out. Reduced motion: no rays or sparkles, just the card.

const DUR := 3.0

var t := -1.0
var runs := 50
var reduced_motion := false
var _number: Label
var _title: Label
var _sub: Label
var _box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", -6)
	add_child(_box)
	_number = _big_label(150, UiTheme.GOLD)
	_title = _big_label(64, UiTheme.OFF_WHITE)
	_sub = UiTheme.label("", 24, UiTheme.SAND, "bold")
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_outline_color", UiTheme.INK)
	_sub.add_theme_constant_override("outline_size", 6)
	for l in [_number, _title, _sub]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(l)
	visible = false


func _big_label(fs: int, col: Color) -> Label:
	var l := UiTheme.label("", fs, col, "black")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", UiTheme.INK)
	l.add_theme_constant_override("outline_size", 14)
	return l


static func title_for(m: int) -> String:
	match m:
		50: return "FIFTY!"
		100: return "HUNDRED!"
		150: return "ONE-FIFTY!"
		200: return "DOUBLE HUNDRED!"
	return "%d UP!" % m


## batter: scorecard row {name, runs, balls, fours, sixes}.
func play(m: int, batter: Dictionary) -> void:
	runs = m
	_number.text = str(m)
	_title.text = title_for(m)
	_sub.text = "%s  -  %d off %d balls  -  %d x 4   %d x 6" % [String(batter.get("name", "")),
		int(batter.get("runs", m)), int(batter.get("balls", 0)), int(batter.get("fours", 0)), int(batter.get("sixes", 0))]
	t = 0.0
	visible = true
	queue_redraw()


func stop() -> void:
	t = -1.0
	visible = false


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	if t > DUR:
		stop()
		return
	_layout()
	queue_redraw()


## The card sits in the upper part of the screen so the batter (framed below it by the
## camera) is seen raising his bat.
func center_y() -> float:
	return maxf(size.y * 0.34, 260.0)


func _ease_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


func _alpha() -> float:
	return clampf(t / 0.15, 0.0, 1.0) * clampf((DUR - t) / 0.4, 0.0, 1.0)


func _layout() -> void:
	var bs := _box.get_combined_minimum_size()
	_box.size = bs
	_box.position = Vector2((size.x - bs.x) * 0.5, center_y() - bs.y * 0.5)
	_box.pivot_offset = bs * 0.5
	var a := _alpha()
	if reduced_motion:
		_box.scale = Vector2.ONE
		_number.modulate.a = a
		_title.modulate.a = a
		_sub.modulate.a = a
		return
	# Number pops in, title drops in after it, the innings line fades up last.
	var s := lerpf(0.3, 1.0, _ease_back(t / 0.4))
	_number.pivot_offset = _number.size * 0.5
	_number.scale = Vector2(s, s) * (1.0 + 0.03 * sin(t * 6.0) * float(t > 0.4))
	_number.modulate.a = a * clampf(t / 0.12, 0.0, 1.0)
	var tt := clampf((t - 0.3) / 0.3, 0.0, 1.0)
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2.ONE * lerpf(1.6, 1.0, _ease_back(tt))
	_title.modulate.a = a * tt
	_sub.modulate.a = a * clampf((t - 0.6) / 0.3, 0.0, 1.0)


func _draw() -> void:
	if t < 0.0:
		return
	var a := _alpha()
	var c := Vector2(size.x * 0.5, center_y())
	# Dim the game behind (not fully: the batter raising his bat stays visible).
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.05, 0.04, 0.5 * a))
	if reduced_motion:
		return
	# Slowly turning golden rays.
	var rays := 18
	var r_out := size.length() * 0.6
	var rot := t * 0.35
	for i in rays:
		var a0 := rot + TAU * i / rays
		var a1 := a0 + TAU / rays * 0.45
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r_out, c + Vector2(cos(a1), sin(a1)) * r_out]),
			Color(UiTheme.GOLD.r, UiTheme.GOLD.g, UiTheme.GOLD.b, 0.13 * a))
	# Soft glow behind the number.
	for k in 4:
		draw_circle(c, (180.0 - k * 35.0) * clampf(t / 0.3, 0.0, 1.0), Color(1.0, 0.85, 0.4, 0.07 * a), true, -1.0, true)
	# Twinkling sparkles around the card.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + runs
	for i in 26:
		var p := c + Vector2(rng.randf_range(-1, 1) * size.x * 0.42, rng.randf_range(-1, 1) * size.y * 0.38)
		var tw := maxf(0.0, sin(t * rng.randf_range(4.0, 8.0) + rng.randf() * TAU))
		var r := rng.randf_range(3.0, 7.0) * tw
		if r > 0.5:
			var col := Color(1.0, 0.95, 0.7, 0.9 * a * tw)
			draw_line(p - Vector2(r * 2.2, 0), p + Vector2(r * 2.2, 0), col, 2.0, true)
			draw_line(p - Vector2(0, r * 2.2), p + Vector2(0, r * 2.2), col, 2.0, true)
			draw_circle(p, r * 0.6, col, true, -1.0, true)

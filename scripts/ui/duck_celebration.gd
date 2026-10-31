class_name DuckCelebration
extends Control
## Out for a duck (0): a simple white duck walks across the screen from left to right
## and is gone, under a big "DUCK!" (out first ball: "GOLDEN DUCK!", same duck). Never
## takes input.

const DUR := 3.0
const QUACKS := [0.0, 0.22, 0.46]   # beak-open times, matching duck_out.wav (+ start delay)
const START := 0.35                  # the duck has walked in before the first quack

var t := -1.0
var golden := false
var reduced_motion := false
var _title: Label
var _sub: Label
var _box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", -4)
	add_child(_box)
	_title = UiTheme.outline(UiTheme.label("DUCK!", 84, Color(1.0, 0.86, 0.25), "black"), 14)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_title)
	_sub = UiTheme.outline(UiTheme.label("Out for 0", 30, UiTheme.OFF_WHITE, "black"), 8)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_sub)
	visible = false


func play(is_golden: bool) -> void:
	golden = is_golden
	_title.text = "GOLDEN DUCK!" if golden else "DUCK!"
	_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if golden else Color(1.0, 0.92, 0.45))
	_sub.text = "Out first ball - for 0" if golden else "Out for 0"
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
	var bs := _box.get_combined_minimum_size()
	_box.size = bs
	_box.position = Vector2((size.x - bs.x) * 0.5, size.y * 0.2)
	_box.pivot_offset = bs * 0.5
	var a := _alpha()
	var pop := clampf(t / 0.3, 0.0, 1.0)
	_box.scale = Vector2.ONE * (1.0 if reduced_motion else lerpf(1.6, 1.0, 1.0 - pow(1.0 - pop, 3.0)))
	_box.modulate.a = a * pop
	queue_redraw()


func _alpha() -> float:
	return clampf(t / 0.12, 0.0, 1.0) * clampf((DUR - t) / 0.4, 0.0, 1.0)


func _quacking() -> float:
	# 0..1 beak opening, peaking at each quack.
	var q := 0.0
	for qt in QUACKS:
		var d: float = t - START - qt
		if d >= 0.0 and d < 0.17:
			q = maxf(q, sin(PI * d / 0.17))
	return q


## A simple duck: white body, orange bill and feet, a dot eye. It walks across the
## screen from left to right (a little waddle, bill opening on each quack) and is gone.
func _draw() -> void:
	if t < 0.0:
		return
	var a := _alpha()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.4 * a))
	var s := minf(size.x / 720.0, size.y / 1100.0)
	var u := clampf(t / DUR, 0.0, 1.0)
	var x := lerpf(-170.0 * s, size.x + 170.0 * s, u) if not reduced_motion else size.x * 0.5
	var step := sin(t * 14.0) if not reduced_motion else 0.0
	var c := Vector2(x, size.y * 0.58 - absf(step) * 6.0 * s)
	var white := Color(0.98, 0.98, 0.96, a)
	var orange := Color(1.0, 0.58, 0.12, a)
	var ink := Color(0.08, 0.07, 0.06, a)
	# Shadow
	draw_set_transform(c + Vector2(0, 92) * s, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 100 * s, Color(0, 0, 0, 0.25 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Feet (alternate steps)
	for side in [-1.0, 1.0]:
		var fx: float = c.x + side * 22 * s
		var lift: float = maxf(0.0, side * step) * 10.0 * s
		var fy: float = c.y + 90 * s - lift
		draw_line(Vector2(fx, c.y + 50 * s), Vector2(fx, fy), orange, 7 * s, true)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 6 * s, fy), Vector2(fx + 30 * s, fy), Vector2(fx + 22 * s, fy + 9 * s), Vector2(fx - 6 * s, fy + 9 * s)]), orange)
	# Body + tail + head
	draw_colored_polygon(PackedVector2Array([c + Vector2(-70, -10) * s, c + Vector2(-112, -46) * s, c + Vector2(-80, -36) * s]), white)
	draw_set_transform(c, 0.0, Vector2(1.3, 0.85))
	draw_circle(Vector2.ZERO, 72 * s, white, true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var hc := c + Vector2(62, -70) * s
	draw_circle(hc, 42 * s, white, true, -1.0, true)
	# Wing (a simple curve)
	draw_arc(c + Vector2(-12, -6) * s, 40 * s, 0.25, PI - 0.25, 16, Color(0.78, 0.78, 0.76, a), 5 * s, true)
	# Bill: opens a little on each quack
	var q := _quacking() if not reduced_motion else 0.0
	var b := hc + Vector2(36, 4) * s
	draw_colored_polygon(PackedVector2Array([b + Vector2(0, -10) * s, b + Vector2(46, -6) * s, b + Vector2(46, 0) * s, b + Vector2(0, 2) * s]), orange)
	draw_colored_polygon(PackedVector2Array([b + Vector2(0, 2) * s, b + Vector2(40, 2 + q * 12) * s, b + Vector2(38, 8 + q * 14) * s, b + Vector2(0, 10) * s]), orange.darkened(0.12))
	# Eye
	draw_circle(hc + Vector2(14, -10) * s, 6 * s, ink, true, -1.0, true)

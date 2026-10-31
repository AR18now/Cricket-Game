class_name DuckCelebration
extends Control
## Out for a duck (0): a cartoon duck waddles on, quacks three times (beak opens in time
## with the sound), then droops its head and sheds a tear, under a big "DUCK!". Out
## first ball = a golden duck with a crown. Never takes input; fades itself out.

const DUR := 3.2
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


func _draw() -> void:
	if t < 0.0:
		return
	var a := _alpha()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.45 * a))
	var s := minf(size.x / 720.0, size.y / 1100.0) * 1.15   # duck scale
	var home := Vector2(size.x * 0.5, size.y * 0.56)
	# Waddle in from the left, then stand (bobbing).
	var walk := clampf(t / START, 0.0, 1.0)
	var x := lerpf(-160.0 * s, home.x, 1.0 - pow(1.0 - walk, 2.0)) if not reduced_motion else home.x
	var waddle := sin(t * 14.0) * (1.0 - walk) if not reduced_motion else 0.0
	var sad := clampf((t - START - 0.75) / 0.5, 0.0, 1.0)   # head droops after the quacks
	var c := Vector2(x, home.y + absf(waddle) * -6.0 * s)
	var body_col := Color(1.0, 0.78, 0.15) if golden else Color(1.0, 0.9, 0.3)
	var shade_col := body_col.darkened(0.25)
	var orange := Color(1.0, 0.55, 0.12)
	var ink := Color(0.1, 0.07, 0.04, a)
	var mod := func(col: Color) -> Color: return Color(col.r, col.g, col.b, col.a * a)
	# Shadow
	draw_set_transform(c + Vector2(0, 92 * s), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 95 * s, Color(0, 0, 0, 0.3 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Feet (waddling)
	for side in [-1.0, 1.0]:
		var lift: float = maxf(0.0, side * waddle) * 10.0 * s
		var fp := c + Vector2(side * 30 * s, 88 * s - lift)
		draw_colored_polygon(PackedVector2Array([fp + Vector2(-26, 0) * s, fp + Vector2(28, -4) * s, fp + Vector2(20, 8) * s, fp + Vector2(-22, 8) * s]), mod.call(orange))
	# Tail and body
	draw_colored_polygon(PackedVector2Array([c + Vector2(-95, -10) * s, c + Vector2(-140, -55) * s, c + Vector2(-80, -40) * s]), mod.call(shade_col))
	draw_set_transform(c, waddle * 0.08, Vector2(1.25, 0.95))
	draw_circle(Vector2.ZERO, 82 * s + 3, ink, true, -1.0, true)
	draw_circle(Vector2.ZERO, 82 * s, mod.call(body_col), true, -1.0, true)
	draw_circle(Vector2(10, 28) * s, 50 * s, mod.call(body_col.lightened(0.18)), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Wing (flaps while quacking, then hangs)
	var flap := _quacking() * 0.5 if not reduced_motion else 0.0
	draw_set_transform(c + Vector2(-18, 0) * s, -0.3 - flap + sad * 0.35, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 46 * s, mod.call(shade_col), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Head (droops when sad)
	var hc := c + Vector2(62, -78 + sad * 26) * s
	draw_circle(hc, 50 * s + 3, ink, true, -1.0, true)
	draw_circle(hc, 50 * s, mod.call(body_col), true, -1.0, true)
	# Beak: opens with each quack
	var q := _quacking()
	var bk := hc + Vector2(40, 8 + sad * 6) * s
	draw_colored_polygon(PackedVector2Array([bk + Vector2(-4, -12) * s, bk + Vector2(52, -4 - q * 14) * s, bk + Vector2(-2, 2) * s]), mod.call(orange))
	draw_colored_polygon(PackedVector2Array([bk + Vector2(-4, 4) * s, bk + Vector2(46, 8 + q * 16) * s, bk + Vector2(-2, 16) * s]), mod.call(orange.darkened(0.15)))
	# Eye: wide while quacking, sad (half-closed lid) after
	var ec := hc + Vector2(14, -10) * s
	draw_circle(ec, 13 * s, Color(1, 1, 1, a), true, -1.0, true)
	draw_circle(ec + Vector2(3, 2) * s, 7 * s, ink, true, -1.0, true)
	if sad > 0.0:
		draw_rect(Rect2(ec + Vector2(-14, -15) * s, Vector2(28, 14 * sad) * s), mod.call(body_col))
		draw_line(ec + Vector2(-14, -1 + 14 * sad - 14) * s, ec + Vector2(14, -4 + 14 * sad - 14) * s, ink, 3.0 * s, true)
		# Tear rolls down
		var tear_t := clampf((t - START - 1.0) / 1.0, 0.0, 1.0)
		var tp := ec + Vector2(6, 16 + tear_t * 60) * s
		draw_circle(tp, 7 * s, Color(0.45, 0.75, 1.0, 0.9 * a * (1.0 - tear_t * 0.5)), true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([tp + Vector2(-6, -2) * s, tp + Vector2(0, -14) * s, tp + Vector2(6, -2) * s]), Color(0.45, 0.75, 1.0, 0.9 * a * (1.0 - tear_t * 0.5)))
	# Golden duck: a little crown
	if golden:
		var cr := hc + Vector2(-6, -48) * s
		var gold := Color(1.0, 0.82, 0.2, a)
		draw_colored_polygon(PackedVector2Array([cr + Vector2(-30, 10) * s, cr + Vector2(-30, -16) * s, cr + Vector2(-15, -2) * s, cr + Vector2(0, -24) * s,
			cr + Vector2(15, -2) * s, cr + Vector2(30, -16) * s, cr + Vector2(30, 10) * s]), gold)
		for tip in [Vector2(-30, -16), Vector2(0, -24), Vector2(30, -16)]:
			draw_circle(cr + tip * s, 5 * s, Color(0.9, 0.2, 0.25, a), true, -1.0, true)
	# "Quack!" bubbles
	for k in QUACKS.size():
		var d: float = t - START - QUACKS[k]
		if d >= 0.0 and d < 0.5 and not reduced_motion:
			var f := UiTheme.font("black")
			var fs := int(30 * s)
			var tw := f.get_string_size("QUACK!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var bp := hc + Vector2(30 + k * 14, -70 - d * 110 - k * 24) * s
			bp.x = clampf(bp.x, 10.0, size.x - tw - 10.0)
			var al := a * (1.0 - d / 0.5)
			draw_string(f, bp + Vector2(2, 2), "QUACK!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, al))
			draw_string(f, bp, "QUACK!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, al))

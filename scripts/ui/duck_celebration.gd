class_name DuckCelebration
extends Control
## Out for a duck (0): a cartoon duck waddles on, quacks three times (beak opens in time
## with the sound), then droops its head and sheds a tear, under a big "DUCK!". Out
## first ball = a golden duck with a crown. Never takes input; fades itself out.

const DUR := 3.4
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


## Local duck coordinates (facing right, ~320 units long) -> screen.
var _c := Vector2.ZERO
var _s := 1.0
var _rot := 0.0


func _p(x: float, y: float) -> Vector2:
	return _c + Vector2(x, y).rotated(_rot) * _s


func _poly(pts: Array, col: Color, outline := true) -> void:
	var pa := PackedVector2Array()
	for v in pts:
		pa.append(_p(v.x, v.y))
	draw_colored_polygon(pa, col)
	if outline:
		pa.append(pa[0])
		draw_polyline(pa, Color(0.08, 0.06, 0.05, col.a), 3.0, true)


func _ellipse(cx: float, cy: float, rx: float, ry: float, col: Color, outline := true, n := 28) -> void:
	var pts := []
	for i in n:
		var an := TAU * i / n
		pts.append(Vector2(cx + cos(an) * rx, cy + sin(an) * ry))
	_poly(pts, col, outline)


func _draw() -> void:
	if t < 0.0:
		return
	var a := _alpha()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.45 * a))
	_s = minf(size.x / 720.0, size.y / 1100.0) * 1.05
	var home := Vector2(size.x * 0.46, size.y * 0.6)
	# Timeline: waddle in -> quack x3 -> droop and cry -> trudge off to the pavilion.
	var leave_at := DUR - 0.9
	var walk_in := clampf(t / START, 0.0, 1.0)
	var walk_out := clampf((t - leave_at) / 0.85, 0.0, 1.0)
	var x := home.x
	if not reduced_motion:
		x = lerpf(-200.0 * _s, home.x, 1.0 - pow(1.0 - walk_in, 2.0)) + walk_out * walk_out * (size.x * 0.75)
	var walking := (walk_in < 1.0 or walk_out > 0.0) and not reduced_motion
	var step := sin(t * 15.0) if walking else 0.0
	var sad := clampf((t - START - 0.75) / 0.5, 0.0, 1.0)
	_c = Vector2(x, home.y - absf(step) * 7.0 * _s)
	_rot = step * 0.05
	var gold := golden
	var body := Color(1.0, 0.8, 0.22, a) if gold else Color(0.74, 0.74, 0.72, a)
	var wing := Color(0.93, 0.66, 0.12, a) if gold else Color(0.58, 0.58, 0.57, a)
	var chest := Color(0.98, 0.62, 0.15, a) if gold else Color(0.55, 0.31, 0.2, a)
	var head := Color(0.98, 0.72, 0.1, a) if gold else Color(0.06, 0.45, 0.25, a)
	var bill := Color(1.0, 0.86, 0.3, a) if not gold else Color(1.0, 0.93, 0.6, a)
	var feet := Color(1.0, 0.5, 0.1, a)
	# Ground shadow
	draw_set_transform(_p(0, 112), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 150 * _s, Color(0, 0, 0, 0.28 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Cricket bat dragged behind (tucked under the wing, toe on the ground)
	_poly([Vector2(-20, 18), Vector2(-150, 104), Vector2(-160, 92), Vector2(-30, 8)], Color(0.93, 0.82, 0.58, a))
	_poly([Vector2(-14, 4), Vector2(18, -18), Vector2(24, -10), Vector2(-8, 12)], Color(0.2, 0.2, 0.22, a))
	# Legs + webbed feet (alternate while walking)
	for leg in [[-18.0, 1.0], [26.0, -1.0]]:
		var lx: float = leg[0]
		var lift := maxf(0.0, step * float(leg[1])) * 16.0
		var fy := 108.0 - lift
		_poly([Vector2(lx - 5, 55), Vector2(lx + 5, 55), Vector2(lx + 5, fy - 6), Vector2(lx - 5, fy - 6)], feet, false)
		_poly([Vector2(lx - 16, fy), Vector2(lx + 30, fy - 4), Vector2(lx + 36, fy + 6), Vector2(lx + 22, fy + 2), Vector2(lx + 18, fy + 9), Vector2(lx + 6, fy + 4), Vector2(lx - 2, fy + 10), Vector2(lx - 18, fy + 8)], feet)
	# Curled tail, body, chest
	_poly([Vector2(-108, -6), Vector2(-160, -40), Vector2(-150, -62), Vector2(-136, -48), Vector2(-104, -40)], body)
	_ellipse(-4, 6, 122, 70, body)
	_ellipse(70, 0, 58, 60, chest)
	# Wing with the blue/teal patch
	_ellipse(-26, -6, 78, 40, wing)
	if not gold:
		_poly([Vector2(-60, 4), Vector2(-10, 0), Vector2(-14, 16), Vector2(-62, 20)], Color(0.2, 0.36, 0.78, a), false)
	# Neck with a white ring, then the head (droops when sad)
	var hy := -132.0 + sad * 42.0
	var hx := 96.0 + sad * 10.0
	_poly([Vector2(58, -40), Vector2(92, -44), Vector2(hx + 14, hy + 20), Vector2(hx - 24, hy + 24)], head)
	if not gold:
		_poly([Vector2(62, -52), Vector2(96, -56), Vector2(94, -46), Vector2(60, -42)], Color(0.97, 0.97, 0.95, a), false)
	_ellipse(hx, hy, 42, 36, head)
	draw_circle(_p(hx - 12, hy - 14), 10 * _s, Color(1, 1, 1, 0.25 * a), true, -1.0, true)
	# Flat duck bill: the lower half opens with each quack
	var q := _quacking()
	var bx := hx + 32.0
	var by := hy + 4.0
	_poly([Vector2(bx - 4, by - 12), Vector2(bx + 50, by - 9), Vector2(bx + 58, by - 2), Vector2(bx + 52, by + 2), Vector2(bx - 2, by + 2)], bill)
	_poly([Vector2(bx - 2, by + 2), Vector2(bx + 48, by + 3 + q * 16), Vector2(bx + 44, by + 10 + q * 18), Vector2(bx - 2, by + 10)], bill.darkened(0.12))
	draw_circle(_p(bx + 14, by - 6), 2.5 * _s, Color(0.1, 0.07, 0.04, a), true, -1.0, true)
	# Eye: bright while quacking, sad heavy lid after
	var ec := Vector2(hx + 12, hy - 10)
	draw_circle(_p(ec.x, ec.y), 10 * _s, Color(1, 1, 1, a), true, -1.0, true)
	draw_circle(_p(ec.x + 3, ec.y + 2), 5.5 * _s, Color(0.08, 0.06, 0.05, a), true, -1.0, true)
	if sad > 0.0:
		_poly([Vector2(ec.x - 12, ec.y - 12), Vector2(ec.x + 12, ec.y - 12), Vector2(ec.x + 12, ec.y - 12 + 12 * sad), Vector2(ec.x - 12, ec.y - 10 + 12 * sad)], head, false)
		draw_line(_p(ec.x - 12, ec.y - 10 + 12 * sad), _p(ec.x + 12, ec.y - 12 + 12 * sad), Color(0.08, 0.06, 0.05, a), 3.0, true)
		var tear_t := clampf((t - START - 1.0) / 1.0, 0.0, 1.0)
		var tp := _p(ec.x + 4, ec.y + 14 + tear_t * 56)
		var tc := Color(0.45, 0.75, 1.0, 0.9 * a * (1.0 - tear_t * 0.4))
		draw_circle(tp, 6.5 * _s, tc, true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([tp + Vector2(-5.5, -2) * _s, tp + Vector2(0, -13) * _s, tp + Vector2(5.5, -2) * _s]), tc)
	# Golden duck: a little crown
	if gold:
		var cy := hy - 34.0
		var crown := Color(1.0, 0.84, 0.2, a)
		_poly([Vector2(hx - 26, cy + 8), Vector2(hx - 26, cy - 16), Vector2(hx - 13, cy - 2), Vector2(hx, cy - 22), Vector2(hx + 13, cy - 2), Vector2(hx + 26, cy - 16), Vector2(hx + 26, cy + 8)], crown)
		for tip in [Vector2(hx - 26, cy - 16), Vector2(hx, cy - 22), Vector2(hx + 26, cy - 16)]:
			draw_circle(_p(tip.x, tip.y), 4.5 * _s, Color(0.9, 0.2, 0.25, a), true, -1.0, true)
	# "QUACK!" bubbles from the bill
	for k in QUACKS.size():
		var d: float = t - START - QUACKS[k]
		if d >= 0.0 and d < 0.5 and not reduced_motion:
			var f := UiTheme.font("black")
			var fs := int(30 * _s)
			var tw := f.get_string_size("QUACK!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var bp := _p(bx + 30 + k * 10, by - 60 - d * 110 - k * 24)
			bp.x = clampf(bp.x, 10.0, size.x - tw - 10.0)
			var al := a * (1.0 - d / 0.5)
			draw_string(f, bp + Vector2(2, 2), "QUACK!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, al))
			draw_string(f, bp, "QUACK!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, al))

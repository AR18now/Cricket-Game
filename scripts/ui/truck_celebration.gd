class_name TruckCelebration
extends Control
## Boundary celebration: a decorated truck-art lorry drives across the screen with the
## result painted on its side. Purely presentational; never blocks input. Reduced motion
## shows it parked (no driving/swinging) and fades it out.

signal horn

const DUR := 2.8
const RED := Color(0.86, 0.15, 0.2)
const YELLOW := Color(0.99, 0.8, 0.15)
const GREEN := Color(0.04, 0.55, 0.32)
const BLUE := Color(0.14, 0.4, 0.86)
const PINK := Color(0.95, 0.35, 0.62)
const ORANGE := Color(0.98, 0.52, 0.12)
const WHITE := Color(0.99, 0.98, 0.95)
const INK := Color(0.1, 0.07, 0.06)

var kind := ""          # "six" | "four"
var t := -1.0
var reduced_motion := false
var _horned := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func play(which: String) -> void:
	kind = which
	t = 0.0
	_horned = false
	visible = true


func stop() -> void:
	t = -1.0
	visible = false


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	if not _horned and t > 0.7:
		_horned = true
		horn.emit()
	if t > DUR:
		stop()
	queue_redraw()


func _x_pos(w: float, L: float) -> float:
	# Enter from the right, ease to a brief stop in the centre, then drive off left.
	var cx := (w - L) * 0.5
	if reduced_motion:
		return cx
	if t < 0.9:
		var u := t / 0.9
		return lerpf(w + 40.0, cx, 1.0 - pow(1.0 - u, 3.0))
	if t < 1.7:
		return cx
	var u2 := (t - 1.7) / (DUR - 1.7)
	return lerpf(cx, -L - 80.0, u2 * u2)


func _draw() -> void:
	if t < 0.0:
		return
	var sc := clampf(size.x / 1280.0, 0.7, 1.4)
	var L := 540.0 * sc
	var ground_y := size.y * 0.78
	var x0 := _x_pos(size.x, L)
	var alpha := 1.0
	if reduced_motion:
		alpha = clampf((DUR - t) / 0.6, 0.0, 1.0)
	var moving := not reduced_motion and (t < 0.9 or t > 1.7)
	var bob := 0.0 if not moving else sin(t * 30.0) * 1.5
	draw_set_transform(Vector2(x0, ground_y + bob), 0.0, Vector2(sc, sc))
	var m := Color(1, 1, 1, alpha)
	# Ground shadow + dust
	draw_set_transform(Vector2(x0 + L * 0.5, ground_y + 4.0), 0.0, Vector2(sc * 1.0, sc * 0.12))
	draw_circle(Vector2.ZERO, 280.0, Color(0, 0, 0, 0.3 * alpha))
	draw_set_transform(Vector2(x0, ground_y + bob), 0.0, Vector2(sc, sc))
	if moving:
		for i in 5:
			var dx := 540.0 + i * 26.0 + fmod(t * 200.0, 26.0)
			draw_circle(Vector2(dx, -12.0 - i * 3.0), 12.0 + i * 3.0, Color(0.85, 0.75, 0.6, 0.35 * alpha * (1.0 - i / 5.0)))
	_body(m)
	_wheels(m)
	_chains(m)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _poly(pts: Array, c: Color, m: Color, outline := true) -> void:
	var p := PackedVector2Array(pts)
	draw_colored_polygon(p, c * m)
	if outline:
		p.append(p[0])
		draw_polyline(p, INK * m, 3.0, true)


func _rect(r: Rect2, c: Color, m: Color, outline := true) -> void:
	draw_rect(r, c * m)
	if outline:
		draw_rect(r, INK * m, false, 3.0)


func _flower(c: Vector2, r: float, petal: Color, m: Color) -> void:
	for i in 6:
		var a := TAU * i / 6.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.45, petal * m)
	draw_circle(c, r * 0.35, YELLOW * m)
	draw_circle(c, r * 0.15, INK * m)


func _body(m: Color) -> void:
	# Chassis
	_rect(Rect2(20, -64, 500, 20), Color(0.18, 0.16, 0.16), m)
	# Cargo box panels
	_rect(Rect2(160, -222, 360, 162), Color(0.55, 0.3, 0.14), m)
	# Top frieze with triangles
	_rect(Rect2(160, -222, 360, 26), BLUE, m)
	for i in 18:
		var x := 162.0 + i * 20.0
		_poly([Vector2(x, -196), Vector2(x + 10, -218), Vector2(x + 20, -196)], [YELLOW, PINK, WHITE][i % 3], m, false)
	# Text board
	var board := Rect2(186, -190, 310, 82)
	_rect(board.grow(6), RED, m)
	_rect(board, WHITE, m)
	var f := UiTheme.font("black")
	var big := "CHHAKKA!" if kind == "six" else "CHAUKA!"
	var small := "SIX" if kind == "six" else "FOUR"
	var fs := 52
	var tw := f.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(board.position.x + (board.size.x - tw) * 0.5 + 3, -128 + 3), big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK * m)
	draw_string(f, Vector2(board.position.x + (board.size.x - tw) * 0.5, -128), big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, (GREEN if kind == "four" else RED) * m)
	var sw := f.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(f, Vector2(board.position.x + (board.size.x - sw) * 0.5, -112), small, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BLUE * m)
	# Flowers either side of the board
	_flower(Vector2(172, -150), 12.0, PINK, m)
	_flower(Vector2(508, -150), 12.0, ORANGE, m)
	# Bottom band: chamak-patti diamonds
	_rect(Rect2(160, -100, 360, 36), GREEN, m)
	for i in 15:
		var x2 := 172.0 + i * 23.0
		_poly([Vector2(x2, -82), Vector2(x2 + 10, -96), Vector2(x2 + 20, -82), Vector2(x2 + 10, -68)], [YELLOW, WHITE, RED, BLUE][i % 4], m, false)
	# Cab
	_poly([Vector2(26, -64), Vector2(26, -140), Vector2(48, -176), Vector2(158, -176), Vector2(158, -64)], YELLOW, m)
	_poly([Vector2(40, -140), Vector2(56, -166), Vector2(110, -166), Vector2(110, -140)], Color(0.6, 0.85, 0.98), m)
	_rect(Rect2(118, -164, 32, 44), Color(0.6, 0.85, 0.98), m)
	# Driver waving from the window
	draw_circle(Vector2(134, -144), 11.0, Color(0.62, 0.43, 0.3) * m)
	var wave := sin(t * 12.0) * 0.5 if not reduced_motion else 0.0
	draw_line(Vector2(146, -136), Vector2(146, -136) + Vector2(sin(-0.6 + wave), -cos(-0.6 + wave)) * 34.0, Color(0.62, 0.43, 0.3) * m, 7.0, true)
	# Cab decorations
	_flower(Vector2(70, -104), 14.0, RED, m)
	_rect(Rect2(26, -86, 132, 12), RED, m, false)
	for i in 6:
		draw_circle(Vector2(38 + i * 22, -80), 4.0, WHITE * m)
	# Crown ("taj") above the cab with mirror dots
	var crown := [Vector2(20, -176), Vector2(20, -206), Vector2(46, -226), Vector2(64, -210), Vector2(90, -246),
		Vector2(116, -210), Vector2(134, -226), Vector2(164, -206), Vector2(164, -176)]
	_poly(crown, RED, m)
	_poly([Vector2(34, -182), Vector2(46, -210), Vector2(64, -196), Vector2(90, -228), Vector2(116, -196), Vector2(134, -210), Vector2(150, -182)], GREEN, m, false)
	for p in [Vector2(46, -198), Vector2(90, -214), Vector2(134, -198), Vector2(68, -188), Vector2(112, -188)]:
		draw_circle(p, 5.0, WHITE * m)
		draw_circle(p, 2.5, Color(0.7, 0.9, 1.0) * m)
	# Bunting on top of the cargo box
	for i in 12:
		var bx := 170.0 + i * 29.0
		_poly([Vector2(bx, -222), Vector2(bx + 22, -222), Vector2(bx + 11, -240 - (4.0 * sin(t * 8.0 + i) if not reduced_motion else 0.0))], [GREEN, YELLOW, PINK, BLUE][i % 4], m, false)
	# Headlight + bumper
	_rect(Rect2(6, -70, 34, 14), Color(0.8, 0.82, 0.85), m)
	draw_circle(Vector2(30, -96), 9.0, Color(1.0, 0.95, 0.7) * m)


func _wheels(m: Color) -> void:
	var spin := 0.0 if reduced_motion else -t * 14.0
	for wx in [92.0, 390.0, 452.0]:
		var c := Vector2(wx, -30)
		draw_circle(c, 32.0, INK * m)
		draw_circle(c, 24.0, Color(0.25, 0.25, 0.27) * m)
		draw_circle(c, 13.0, RED * m)
		for k in 4:
			var a := spin + k * PI * 0.5
			draw_line(c, c + Vector2(cos(a), sin(a)) * 12.0, YELLOW * m, 3.0, true)


func _chains(m: Color) -> void:
	# Hanging bell chains ("jhanjar") under the cargo box, swinging with motion.
	var swing := 0.0 if reduced_motion else sin(t * 9.0) * 6.0
	for seg in 5:
		var a := Vector2(176.0 + seg * 66.0, -60.0)
		var b := a + Vector2(56.0, 0.0)
		for i in 9:
			var u := i / 8.0
			var p := a.lerp(b, u) + Vector2(swing * sin(u * PI), sin(u * PI) * 18.0)
			draw_circle(p, 3.2, Color(0.95, 0.8, 0.3) * m)
		draw_circle(a.lerp(b, 0.5) + Vector2(swing, 26.0), 6.0, Color(0.95, 0.75, 0.2) * m)

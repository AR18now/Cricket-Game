class_name GroundView
extends Node2D
## Static ground plane for a venue: courtyard floor, field, pitch, creases, boundary
## chalk and the far-side buildings. Drawn once (cached) in world pixel space.

var venue: VenueConfig
const FAR_WALL_Y := -37.0
const NEAR_WALL_Y := 36.0
const X_MIN := -95.0
const X_MAX := 70.0

const BRICK := Color(0.66, 0.33, 0.22)
const BRICK_DARK := Color(0.5, 0.24, 0.17)
const MORTAR := Color(0.83, 0.7, 0.58)
const PLASTER := Color(0.93, 0.86, 0.72)
const EMERALD := Color(0.04, 0.4, 0.3)
const GOLD := Color(0.98, 0.78, 0.33)
const TERRACOTTA := Color(0.8, 0.4, 0.26)
const SAND := Color(0.9, 0.78, 0.58)
const INK := Color(0.12, 0.09, 0.08)


func setup(v: VenueConfig) -> void:
	venue = v
	queue_redraw()


func g(x: float, y: float) -> Vector2:
	return Proj.ground(x, y)


func w3(x: float, y: float, z: float) -> Vector2:
	return Proj.to_screen(Vector3(x, y, z))


func _draw() -> void:
	if venue == null:
		return
	var rng := DetRng.new(20260925)
	_draw_buildings(rng)
	_draw_courtyard_floor()
	_draw_field(rng)
	_draw_pitch()


# ---------------------------------------------------------------- backdrop
func _draw_buildings(rng: DetRng) -> void:
	# Houses behind the far wall: facades rise in z from the wall line.
	var x := X_MIN
	var palette := [PLASTER, Color(0.87, 0.74, 0.6), Color(0.95, 0.9, 0.8), Color(0.78, 0.55, 0.42), Color(0.86, 0.8, 0.66)]
	var yb := FAR_WALL_Y - 4.0
	while x < X_MAX:
		var w := rng.range_f(9.0, 15.0)
		var h := rng.range_f(7.0, 11.5)
		var col: Color = palette[rng.range_i(0, palette.size() - 1)]
		var base_l := w3(x, yb, 0.0)
		var top_r := w3(x + w, yb, h)
		var rect := Rect2(Vector2(base_l.x, top_r.y), Vector2(top_r.x - base_l.x, base_l.y - top_r.y))
		draw_rect(rect, col)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 10.0)), col.darkened(0.18))
		# Parapet line
		draw_rect(Rect2(rect.position + Vector2(0, -6), Vector2(rect.size.x, 8.0)), col.lightened(0.1))
		# Windows with warm evening glow + a balcony
		var floors := int(h / 3.2)
		for fl in floors:
			var wz := 1.6 + fl * 3.2
			var nwin := int(w / 3.2)
			for wi in nwin:
				var wx := x + 1.2 + wi * 3.2
				var p := w3(wx, yb, wz + 1.6)
				var lit := rng.chance(0.45)
				var wc := Color(1.0, 0.82, 0.45) if lit else Color(0.25, 0.22, 0.26)
				draw_rect(Rect2(p, Vector2(1.3 * Proj.S, 1.6 * Proj.S)), INK)
				draw_rect(Rect2(p + Vector2(3, 3), Vector2(1.3 * Proj.S - 6, 1.6 * Proj.S - 6)), wc)
				# window grille arch
				draw_line(p + Vector2(1.3 * Proj.S * 0.5, 3), p + Vector2(1.3 * Proj.S * 0.5, 1.6 * Proj.S - 3), INK, 2.0)
			if fl == 0 and rng.chance(0.5):
				var bp := w3(x + 1.0, yb, wz + 3.0)
				draw_rect(Rect2(bp, Vector2((w - 2.0) * Proj.S, 6.0)), EMERALD.darkened(0.2))
				for k in int(w * 2):
					draw_line(bp + Vector2(k * 22.0, 0), bp + Vector2(k * 22.0, 22.0), EMERALD.darkened(0.3), 2.0)
		# Rooftop: water tank, spectators
		var roof_z := h
		if rng.chance(0.5):
			var tp := w3(x + w * rng.range_f(0.2, 0.7), yb - 1.0, roof_z)
			draw_rect(Rect2(tp + Vector2(-38, -64), Vector2(76, 64)), Color(0.18, 0.2, 0.22))
			draw_rect(Rect2(tp + Vector2(-34, -60), Vector2(68, 8)), Color(0.28, 0.3, 0.32))
			draw_rect(Rect2(tp + Vector2(-44, -70), Vector2(88, 8)), Color(0.15, 0.16, 0.18))
		var nspec := rng.range_i(2, 6)
		for s in nspec:
			var sx := x + rng.range_f(0.8, w - 0.8)
			_spectator(w3(sx, yb, roof_z), rng)
		x += w + rng.range_f(-0.5, 0.8)
	# Tea stall against the far wall (left side).
	_tea_stall(-44.0)
	# Far courtyard wall (brick) in front of the houses.
	_brick_wall(FAR_WALL_Y, 3.0, X_MIN, X_MAX, true)
	# Bunting strung high between rooftops (above any ball path, behind the field).
	for b in 3:
		var bx0 := -70.0 + b * 45.0
		_bunting(Vector3(bx0, FAR_WALL_Y - 3.0, 10.5), Vector3(bx0 + 42.0, FAR_WALL_Y - 3.0, 10.0), rng)


func _spectator(base: Vector2, rng: DetRng) -> void:
	var skin: Color = [Color(0.72, 0.5, 0.36), Color(0.6, 0.42, 0.3), Color(0.8, 0.6, 0.45)][rng.range_i(0, 2)]
	var shirt: Color = [EMERALD, Color(0.95, 0.93, 0.88), TERRACOTTA, Color(0.3, 0.45, 0.7), GOLD.darkened(0.2), Color(0.55, 0.2, 0.35)][rng.range_i(0, 5)]
	var hgt := rng.range_f(0.85, 1.1)
	var body := Rect2(base + Vector2(-12, -52 * hgt), Vector2(24, 52 * hgt))
	draw_rect(body.grow(2), INK)
	draw_rect(body, shirt)
	var head := base + Vector2(0, -52 * hgt - 10)
	draw_circle(head, 11.0, INK)
	draw_circle(head, 9.0, skin)
	draw_circle(head + Vector2(0, -3), 9.0, Color(0.1, 0.08, 0.07), true)
	draw_circle(head + Vector2(0, 2), 8.0, skin)
	if rng.chance(0.3):
		# arm raised / waving
		draw_line(base + Vector2(10, -48 * hgt), base + Vector2(22, -80 * hgt), shirt, 6.0)


func _tea_stall(x0: float) -> void:
	var y := FAR_WALL_Y + 1.5
	var a := w3(x0, y, 0.0)
	var b := w3(x0 + 7.0, y, 2.6)
	# Counter
	draw_rect(Rect2(Vector2(a.x, b.y + 40), Vector2(b.x - a.x, a.y - b.y - 40)), Color(0.45, 0.28, 0.18))
	draw_rect(Rect2(Vector2(a.x, b.y + 40), Vector2(b.x - a.x, 10)), Color(0.6, 0.4, 0.26))
	# Striped awning
	var aw_l := w3(x0 - 0.5, y + 0.8, 3.0)
	var aw_r := w3(x0 + 7.5, y + 0.8, 3.0)
	var stripes := 10
	for i in stripes:
		var t0 := float(i) / stripes
		var t1 := float(i + 1) / stripes
		var p0 := aw_l.lerp(aw_r, t0)
		var p1 := aw_l.lerp(aw_r, t1)
		var poly := PackedVector2Array([p0 + Vector2(0, -34), p1 + Vector2(0, -34), p1 + Vector2(0, 8), p0 + Vector2(0, 8)])
		draw_colored_polygon(poly, TERRACOTTA if i % 2 == 0 else Color(0.97, 0.93, 0.84))
	draw_line(aw_l + Vector2(0, 8), aw_r + Vector2(0, 8), INK, 3.0)
	# Posts
	draw_line(w3(x0, y + 0.8, 0.0), aw_l + Vector2(20, 8), Color(0.35, 0.22, 0.14), 6.0)
	draw_line(w3(x0 + 7.0, y + 0.8, 0.0), aw_r + Vector2(-20, 8), Color(0.35, 0.22, 0.14), 6.0)
	# Kettle and cups
	var k := w3(x0 + 2.0, y, 1.3)
	draw_circle(k + Vector2(0, -14), 16.0, Color(0.72, 0.72, 0.74))
	draw_rect(Rect2(k + Vector2(-6, -38), Vector2(12, 10)), Color(0.5, 0.5, 0.52))
	draw_line(k + Vector2(14, -14), k + Vector2(30, -26), Color(0.62, 0.62, 0.64), 5.0)
	for c in 4:
		var cp := w3(x0 + 3.6 + c * 0.7, y, 1.3)
		draw_rect(Rect2(cp + Vector2(-5, -14), Vector2(10, 14)), Color(0.97, 0.95, 0.9))
	# Painted sign (reviewed text: "CHAI")
	var sp := w3(x0 + 1.4, y + 0.8, 3.9)
	draw_rect(Rect2(sp, Vector2(4.2 * Proj.S, 42)), EMERALD)
	draw_rect(Rect2(sp + Vector2(4, 4), Vector2(4.2 * Proj.S - 8, 34)), EMERALD.lightened(0.1))
	draw_string(ThemeDB.fallback_font, sp + Vector2(4.2 * Proj.S * 0.5 - 34, 32), "CHAI", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, GOLD)
	# Stall keeper
	var sk := w3(x0 + 5.5, y - 0.6, 0.0)
	_spectator(sk + Vector2(0, -60), DetRng.new(3))


func _brick_wall(y: float, h: float, x0: float, x1: float, coping: bool) -> void:
	var a := w3(x0, y, 0.0)
	var b := w3(x1, y, h)
	var rect := Rect2(Vector2(a.x, b.y), Vector2(b.x - a.x, a.y - b.y))
	draw_rect(rect, BRICK)
	var row_h := 13.0
	var rows := int(rect.size.y / row_h)
	for r in rows:
		var ry := rect.position.y + r * row_h
		draw_line(Vector2(rect.position.x, ry), Vector2(rect.end.x, ry), MORTAR.darkened(0.15), 1.5)
		var off := 0.0 if r % 2 == 0 else 19.0
		var bx := rect.position.x + off
		while bx < rect.end.x:
			draw_line(Vector2(bx, ry), Vector2(bx, ry + row_h), MORTAR.darkened(0.2), 1.5)
			bx += 38.0
	if coping:
		draw_rect(Rect2(rect.position + Vector2(0, -8), Vector2(rect.size.x, 12)), PLASTER.darkened(0.08))
	# Evening light gradient on the wall
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.5)), Color(1.0, 0.7, 0.4, 0.12))


func _bunting(a: Vector3, b: Vector3, rng: DetRng) -> void:
	var n := 26
	var prev := w3(a.x, a.y, a.z)
	var cols := [EMERALD, GOLD, Color(0.97, 0.95, 0.9), TERRACOTTA]
	for i in range(1, n + 1):
		var t := float(i) / n
		var sag := sin(t * PI) * 1.4
		var p := w3(lerpf(a.x, b.x, t), a.y, lerpf(a.z, b.z, t) - sag)
		draw_line(prev, p, Color(0.2, 0.18, 0.16), 1.5, true)
		if i < n:
			var tri := PackedVector2Array([p + Vector2(-9, 0), p + Vector2(9, 0), p + Vector2(0, 20)])
			draw_colored_polygon(tri, cols[i % cols.size()])
		prev = p


# ---------------------------------------------------------------- ground plane
func _draw_courtyard_floor() -> void:
	var poly := PackedVector2Array([g(X_MIN, FAR_WALL_Y), g(X_MAX, FAR_WALL_Y), g(X_MAX, NEAR_WALL_Y + 140.0), g(X_MIN, NEAR_WALL_Y + 140.0)])
	draw_colored_polygon(poly, Color(0.72, 0.45, 0.32))
	# Brick paving pattern (herringbone-ish rows)
	var y := FAR_WALL_Y
	var row := 0
	while y < NEAR_WALL_Y + 6.0:
		draw_line(g(X_MIN, y), g(X_MAX, y), Color(0.6, 0.36, 0.25, 0.55), 1.5)
		var x := X_MIN + (0.0 if row % 2 == 0 else 0.6)
		while x < X_MAX:
			draw_line(g(x, y), g(x, y + 0.9), Color(0.6, 0.36, 0.25, 0.45), 1.2)
			x += 1.2
		y += 0.9
		row += 1


func _ellipse_points(scale: float, n: int = 96) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(g(venue.boundary_center.x + cos(a) * venue.boundary_rx * scale, venue.boundary_center.y + sin(a) * venue.boundary_ry * scale))
	return pts


func _draw_field(rng: DetRng) -> void:
	# Outer apron then the playing field (packed earth), with soft concentric wear.
	draw_colored_polygon(_ellipse_points(1.05), venue.ground_edge_color)
	draw_colored_polygon(_ellipse_points(1.0), venue.ground_color.darkened(0.05))
	draw_colored_polygon(_ellipse_points(0.82), venue.ground_color)
	draw_colored_polygon(_ellipse_points(0.45), venue.ground_color.lightened(0.04))
	# Texture: grass tufts and pebbles, deterministic.
	for i in 900:
		var a := rng.range_f(0.0, TAU)
		var r := sqrt(rng.next_float()) * 0.98
		var wx := venue.boundary_center.x + cos(a) * venue.boundary_rx * r
		var wy := venue.boundary_center.y + sin(a) * venue.boundary_ry * r
		if absf(wy) < 2.2 and wx > -22.0 and wx < 2.5:
			continue
		var p := g(wx, wy)
		if rng.chance(0.6):
			var gc := Color(0.42, 0.5, 0.22, rng.range_f(0.35, 0.7))
			draw_line(p, p + Vector2(-3, -7), gc, 2.0)
			draw_line(p, p + Vector2(2, -8), gc, 2.0)
			draw_line(p, p + Vector2(5, -5), gc, 2.0)
		else:
			draw_circle(p, rng.range_f(1.5, 3.0), Color(0.55, 0.4, 0.28, 0.5))
	# Boundary: chalk line (slightly rough) with small markers.
	var chalk := _ellipse_points(1.0, 160)
	chalk.append(chalk[0])
	draw_polyline(chalk, Color(0.3, 0.2, 0.15, 0.35), 9.0, true)
	draw_polyline(chalk, venue.boundary_color, 5.0, true)
	for i in 24:
		var a := TAU * i / 24.0
		var p := g(venue.boundary_center.x + cos(a) * venue.boundary_rx, venue.boundary_center.y + sin(a) * venue.boundary_ry)
		var cone := PackedVector2Array([p + Vector2(-7, 2), p + Vector2(7, 2), p + Vector2(0, -16)])
		draw_colored_polygon(cone, TERRACOTTA)
		draw_line(p + Vector2(-4, -6), p + Vector2(4, -6), Color(1, 1, 1), 2.0)


func _draw_pitch() -> void:
	var hw := 1.52
	var x0 := -22.0
	var x1 := 2.0
	var poly := PackedVector2Array([g(x0, -hw), g(x1, -hw), g(x1, hw), g(x0, hw)])
	draw_colored_polygon(poly, Color(0.55, 0.42, 0.3, 0.5))
	var inner := PackedVector2Array([g(x0 + 0.1, -hw + 0.1), g(x1 - 0.1, -hw + 0.1), g(x1 - 0.1, hw - 0.1), g(x0 + 0.1, hw - 0.1)])
	draw_colored_polygon(inner, venue.pitch_color)
	# Worn patches at the batting/bowling ends and on a good length.
	for c in [Vector2(-1.3, 0.0), Vector2(-18.9, 0.3), Vector2(-5.5, 0.1)]:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(g(c.x + cos(a) * 1.3, c.y + sin(a) * 0.9))
		draw_colored_polygon(pts, venue.pitch_color.darkened(0.12))
	var white := Color(0.98, 0.97, 0.94)
	for end_x in [0.0, Delivery.BOWLING_STUMPS_X]:
		var sgn := 1.0 if end_x == 0.0 else -1.0
		var pop: float = end_x - 1.22 * sgn
		draw_line(g(pop, -1.83), g(pop, 1.83), white, 3.0, true)          # popping crease
		draw_line(g(end_x, -1.32), g(end_x, 1.32), white, 2.0, true)      # bowling crease
		for yy in [-1.32, 1.32]:
			draw_line(g(end_x + 0.3 * sgn, yy), g(pop - 1.0 * sgn, yy), white, 2.0, true)  # return creases

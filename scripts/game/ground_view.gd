class_name GroundView
extends Node2D
## Static ground plane for a venue: textured striped grass, pitch, creases, rope and
## the stadium around it. Drawn once (cached) in world pixel space.

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
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()


func g(x: float, y: float) -> Vector2:
	return Proj.ground(x, y)


func w3(x: float, y: float, z: float) -> Vector2:
	return Proj.to_screen(Vector3(x, y, z))


func _draw() -> void:
	if venue == null:
		return
	_draw_outfield()
	_draw_field()
	_draw_pitch()
	# The stadium: far-side and end stands, roof, sightscreen; the near side keeps only
	# its boundary boards (stands there would hide play from this camera).
	Stadium.draw(self, venue, func(p: Vector3) -> Vector2: return Proj.to_screen(p),
		func(p: Vector3) -> float: return -p.y + p.z * 0.01, func(_p: Vector3) -> bool: return true,
		func(c: Color) -> Color: return c, {"low_near": true, "towers": false})


## Textured, striped grass over the whole ground (the projection is affine, so one
## textured polygon per stripe maps exactly).
func _draw_outfield() -> void:
	if BatterView.grass_tex == null:
		BatterView.grass_tex = load("res://assets/textures/grass.png")
		BatterView.pitch_tex = load("res://assets/textures/pitch.png")
	var light := venue.ground_color.lightened(0.07)
	var dark := venue.ground_color.darkened(0.06)
	var y := venue.boundary_center.y - venue.boundary_ry - 8.0
	var idx := 0
	while y < NEAR_WALL_Y + 40.0:
		var c: Color = light if idx % 2 == 0 else dark
		c = Color(c.r / BatterView.GRASS_TEX_MEAN, c.g / BatterView.GRASS_TEX_MEAN, c.b / BatterView.GRASS_TEX_MEAN)
		var q := [Vector2(X_MIN, y), Vector2(X_MAX, y), Vector2(X_MAX, y + 4.0), Vector2(X_MIN, y + 4.0)]
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for p in q:
			pts.append(g(p.x, p.y))
			uvs.append(Vector2(p.x, p.y) / BatterView.GRASS_TILE_M)
		draw_polygon(pts, PackedColorArray([c, c, c, c]), uvs, BatterView.grass_tex)
		y += 4.0
		idx += 1


func _ellipse_points(scale: float, n: int = 96) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(g(venue.boundary_center.x + cos(a) * venue.boundary_rx * scale, venue.boundary_center.y + sin(a) * venue.boundary_ry * scale))
	return pts


func _draw_field() -> void:
	# Inner fielding circle (dashed white) around the pitch.
	var ring := PackedVector2Array()
	for k in 180:
		var a := TAU * k / 180.0
		ring.append(g(-10.0 + cos(a) * 24.0, sin(a) * 19.0))
	for k in range(0, 180, 3):
		draw_line(ring[k], ring[(k + 1) % 180], Color(1, 1, 1, 0.28), 1.5, true)
	# Boundary rope with a soft shadow.
	var rope := _ellipse_points(1.0, 160)
	rope.append(rope[0])
	draw_polyline(rope, Color(0, 0, 0, 0.25), 10.0, true)
	draw_polyline(rope, venue.boundary_color, 6.0, true)
	draw_polyline(rope, Color(0.8, 0.15, 0.15, 0.9), 2.0, true)


func _draw_pitch() -> void:
	var hw := 1.52
	var x0 := -22.0
	var x1 := 2.0
	# Pitch texture: v runs from the batter's end (x1) to the bowler's end (x0).
	var wc := Color(1, 1, 1)
	draw_polygon(PackedVector2Array([g(x1, -hw), g(x1, hw), g(x0, hw), g(x0, -hw)]), PackedColorArray([wc, wc, wc, wc]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), BatterView.pitch_tex)
	var white := Color(0.98, 0.97, 0.94)
	for end_x in [0.0, Delivery.BOWLING_STUMPS_X]:
		var sgn := 1.0 if end_x == 0.0 else -1.0
		var pop: float = end_x - 1.22 * sgn
		draw_line(g(pop, -1.83), g(pop, 1.83), white, 3.0, true)          # popping crease
		draw_line(g(end_x, -1.32), g(end_x, 1.32), white, 2.0, true)      # bowling crease
		for yy in [-1.32, 1.32]:
			draw_line(g(end_x + 0.3 * sgn, yy), g(pop - 1.0 * sgn, yy), white, 2.0, true)  # return creases

class_name Stadium
extends RefCounted
## A cricket stadium around the boundary, drawn into a cached (static) canvas layer by
## either camera: boundary boards, a concrete front wall, tiers packed with a crowd
## (one small tileable texture), a roof canopy, a white sightscreen behind the bowler and
## four floodlight towers. World metres; each camera passes its own projection.
##
##   proj:  Callable(Vector3) -> Vector2   world -> screen
##   depth: Callable(Vector3) -> float     larger = farther (drawn first)
##   keep:  Callable(Vector3) -> bool      skip parts behind the camera
##   lit:   Callable(Color) -> Color       atmosphere lighting
## opts: {"low_near": bool (side camera: no stands on the near side), "lights_on": bool}

const SEG := 64
const BOARD_R := 1.06
const WALL_R := 1.11
const TIER_R0 := 1.13
const TIER_R1 := 1.5
const ROOF_R0 := 1.44
const ROOF_R1 := 1.6
const TIER_Z0 := 1.6
const TIER_Z1 := 12.5
const ROOF_Z := 15.0

static var crowd_tex: Texture2D


static func at(v: VenueConfig, s: float, a: float, z: float) -> Vector3:
	return Vector3(v.boundary_center.x + cos(a) * v.boundary_rx * s, v.boundary_center.y + sin(a) * v.boundary_ry * s, z)


static func draw(ci: CanvasItem, v: VenueConfig, proj: Callable, depth: Callable, keep: Callable, lit: Callable, opts: Dictionary = {}) -> void:
	if crowd_tex == null:
		crowd_tex = load("res://assets/textures/crowd.png")
	var parts: Array = []   # [depth, kind, data]
	var low_near: bool = opts.get("low_near", false)
	for i in SEG:
		var a0 := TAU * i / SEG
		var a1 := TAU * (i + 1) / SEG
		var am := (a0 + a1) * 0.5
		if not (keep.call(at(v, BOARD_R, a0, 0.0)) and keep.call(at(v, BOARD_R, a1, 0.0))):
			continue
		var near_side := low_near and sin(am) > 0.25
		parts.append([depth.call(at(v, BOARD_R, am, 0.5)), "board", [a0, a1]])
		var whole: bool = keep.call(at(v, ROOF_R1, a0, 0.0)) and keep.call(at(v, ROOF_R1, a1, 0.0))
		if whole and not near_side:
			parts.append([depth.call(at(v, (TIER_R0 + TIER_R1) * 0.5, am, 6.0)), "tier", [a0, a1, i]])
			parts.append([depth.call(at(v, (ROOF_R0 + ROOF_R1) * 0.5, am, ROOF_Z)) + 0.5, "roof", [a0, a1]])
	# Sightscreen behind the bowler's end (white, in front of the stand).
	var ss := at(v, 1.09, PI, 3.5)
	if keep.call(ss):
		parts.append([depth.call(ss) - 0.1, "screen", []])
	for ang in [PI - 0.8, PI + 0.8, 0.8, -0.8]:
		var base := at(v, 1.66, ang, 0.0)
		if opts.get("towers", true) and keep.call(base) and not (low_near and sin(ang) > 0.25):
			parts.append([depth.call(base) + 1.0, "tower", [ang]])
	parts.sort_custom(func(p, q): return p[0] > q[0])
	for p in parts:
		var d: Array = p[2]
		match p[1]:
			"board":
				_board(ci, v, proj, lit, d[0], d[1])
			"tier":
				_tier(ci, v, proj, lit, d[0], d[1], int(d[2]))
			"roof":
				_roof(ci, v, proj, lit, d[0], d[1])
			"screen":
				_screen(ci, v, proj, lit)
			"tower":
				_tower(ci, v, proj, lit, d[0], bool(opts.get("lights_on", false)))


static func _quad(ci: CanvasItem, proj: Callable, pts: Array, col: Color) -> void:
	var pa := PackedVector2Array()
	for q in pts:
		pa.append(proj.call(q))
	ci.draw_colored_polygon(pa, col)


static func _board(ci: CanvasItem, v: VenueConfig, proj: Callable, lit: Callable, a0: float, a1: float) -> void:
	var p0 := at(v, BOARD_R, a0, 0.0)
	var p1 := at(v, BOARD_R, a1, 0.0)
	_quad(ci, proj, [p0, p1, p1 + Vector3(0, 0, 0.9), p0 + Vector3(0, 0, 0.9)], lit.call(Color(0.1, 0.17, 0.3)))
	_quad(ci, proj, [p0 + Vector3(0, 0, 0.78), p1 + Vector3(0, 0, 0.78), p1 + Vector3(0, 0, 0.9), p0 + Vector3(0, 0, 0.9)], lit.call(Color(0.85, 0.85, 0.82)))


static func _tier(ci: CanvasItem, v: VenueConfig, proj: Callable, lit: Callable, a0: float, a1: float, i: int) -> void:
	# Concrete front wall, then the raked seating with the crowd texture.
	var w0 := at(v, WALL_R, a0, 0.0)
	var w1 := at(v, WALL_R, a1, 0.0)
	_quad(ci, proj, [w0, w1, w1 + Vector3(0, 0, TIER_Z0), w0 + Vector3(0, 0, TIER_Z0)], lit.call(Color(0.62, 0.62, 0.6)))
	var pts := PackedVector2Array([proj.call(at(v, TIER_R0, a0, TIER_Z0)), proj.call(at(v, TIER_R0, a1, TIER_Z0)),
		proj.call(at(v, TIER_R1, a1, TIER_Z1)), proj.call(at(v, TIER_R1, a0, TIER_Z1))])
	# About half a metre per seat and ~20 rows up the rake.
	var u0 := float(i) * 0.15
	var u1 := u0 + 0.15
	var uvs := PackedVector2Array([Vector2(u0, 2.5), Vector2(u1, 2.5), Vector2(u1, 0.0), Vector2(u0, 0.0)])
	var c: Color = lit.call(Color(0.9, 0.9, 0.93))   # a touch of haze
	ci.draw_polygon(pts, PackedColorArray([c, c, c, c]), uvs, crowd_tex)
	# Aisle / stairway every few sections
	if i % 4 == 0:
		ci.draw_line(proj.call(at(v, TIER_R0, a0, TIER_Z0)), proj.call(at(v, TIER_R1, a0, TIER_Z1)), lit.call(Color(0.7, 0.7, 0.68)), 2.0, true)


static func _roof(ci: CanvasItem, v: VenueConfig, proj: Callable, lit: Callable, a0: float, a1: float) -> void:
	_quad(ci, proj, [at(v, ROOF_R0, a0, ROOF_Z), at(v, ROOF_R0, a1, ROOF_Z), at(v, ROOF_R1, a1, ROOF_Z + 1.4), at(v, ROOF_R1, a0, ROOF_Z + 1.4)], lit.call(Color(0.86, 0.87, 0.88)))
	_quad(ci, proj, [at(v, ROOF_R0, a0, ROOF_Z - 0.35), at(v, ROOF_R0, a1, ROOF_Z - 0.35), at(v, ROOF_R0, a1, ROOF_Z), at(v, ROOF_R0, a0, ROOF_Z)], lit.call(Color(0.35, 0.36, 0.4)))
	var mid := (a0 + a1) * 0.5
	ci.draw_line(proj.call(at(v, TIER_R1, mid, TIER_Z1)), proj.call(at(v, ROOF_R0 + 0.04, mid, ROOF_Z)), lit.call(Color(0.42, 0.43, 0.46)), 2.0, true)


static func _screen(ci: CanvasItem, v: VenueConfig, proj: Callable, lit: Callable) -> void:
	var c := v.boundary_center
	var x := c.x - v.boundary_rx * 1.09
	_quad(ci, proj, [Vector3(x, -7.5, 0.0), Vector3(x, 7.5, 0.0), Vector3(x, 7.5, 6.0), Vector3(x, -7.5, 6.0)], lit.call(Color(0.97, 0.97, 0.95)))
	_quad(ci, proj, [Vector3(x + 0.05, -7.7, 5.8), Vector3(x + 0.05, 7.7, 5.8), Vector3(x + 0.05, 7.7, 6.2), Vector3(x + 0.05, -7.7, 6.2)], lit.call(Color(0.55, 0.56, 0.6)))


static func _tower(ci: CanvasItem, v: VenueConfig, proj: Callable, lit: Callable, ang: float, on: bool) -> void:
	var b := at(v, 1.66, ang, 0.0)
	var top := b + Vector3(0, 0, 30.0)
	var pb: Vector2 = proj.call(b)
	var pt: Vector2 = proj.call(top)
	var wpx := maxf(2.0, (pb - pt).length() * 0.02)
	ci.draw_line(pb, pt, lit.call(Color(0.5, 0.51, 0.55)), wpx, true)
	var side := Vector3(-sin(ang), cos(ang), 0.0) * 3.2
	var head := [top - side + Vector3(0, 0, -1.2), top + side + Vector3(0, 0, -1.2), top + side + Vector3(0, 0, 1.4), top - side + Vector3(0, 0, 1.4)]
	_quad(ci, proj, head, lit.call(Color(0.25, 0.26, 0.3)))
	var lamp: Color = Color(1.0, 0.98, 0.88) if on else lit.call(Color(0.75, 0.76, 0.78))
	var inner := [top - side * 0.85 + Vector3(0, 0, -0.9), top + side * 0.85 + Vector3(0, 0, -0.9), top + side * 0.85 + Vector3(0, 0, 1.1), top - side * 0.85 + Vector3(0, 0, 1.1)]
	_quad(ci, proj, inner, lamp)
	if on:
		var c: Vector2 = proj.call(top)
		var r := (pb - pt).length() * 0.18
		for k in range(4, 0, -1):
			ci.draw_circle(c, r * k * 0.5, Color(1.0, 0.97, 0.85, 0.07), true, -1.0, true)

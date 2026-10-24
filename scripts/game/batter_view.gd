class_name BatterView
extends Node2D
## "Batter's eye" camera: perspective view from just behind the striker looking down the
## pitch at the bowler and the whole ground. Renders from the same resolved simulation
## data as the side view (WorldView), so both views always agree. Used for the delivery;
## the side camera takes over after contact to follow the ball into the field.

const CAM := Vector3(5.6, 0.35, 2.25)
const PITCH_DEG := 7.0
const BALL_R := 0.1   # exaggerated for readability

var w: WorldView
var F := 900.0
var W := 1280.0
var H := 720.0
var _ca := cos(deg_to_rad(PITCH_DEG))
var _sa := sin(deg_to_rad(PITCH_DEG))
var _tufts: Array = []
var _buildings: Array = []
## Static backdrop (sky, stands, ground, pitch) is cached on its own canvas item and only
## redrawn when the screen size or atmosphere changes; actors/ball redraw every frame.
var static_layer: Node2D
var _ci: CanvasItem
var _static_key := ""
var _trail: Array = []
var _hand_screen := Vector2.INF


func setup(world: WorldView) -> void:
	w = world
	static_layer = Node2D.new()
	static_layer.show_behind_parent = true
	add_child(static_layer)
	static_layer.draw.connect(_draw_static)
	var r := DetRng.new(4242)
	for i in 260:
		var a := r.range_f(0.0, TAU)
		var rr := sqrt(r.next_float()) * 0.97
		var p := Vector2(w.venue.boundary_center.x + cos(a) * w.venue.boundary_rx * rr, w.venue.boundary_center.y + sin(a) * w.venue.boundary_ry * rr)
		if absf(p.y) < 2.0 and p.x > -22.5 and p.x < 2.5:
			continue
		_tufts.append(p)
	# Stands / houses: far end and both sides, each {a: Vector2, b: Vector2, h, col, seed}
	var palette := [Color(0.93, 0.86, 0.72), Color(0.87, 0.74, 0.6), Color(0.95, 0.9, 0.8), Color(0.78, 0.55, 0.42), Color(0.86, 0.8, 0.66)]
	var x := -70.0
	while x < 6.0:
		var wd := r.range_f(8.0, 13.0)
		_buildings.append({"a": Vector2(x, -44.0), "b": Vector2(x + wd, -44.0), "h": r.range_f(8.0, 13.0), "col": palette[r.range_i(0, 4)], "seed": r.next_u32()})
		_buildings.append({"a": Vector2(x, 44.0), "b": Vector2(x + wd, 44.0), "h": r.range_f(8.0, 13.0), "col": palette[r.range_i(0, 4)], "seed": r.next_u32()})
		x += wd
	var y := -44.0
	while y < 44.0:
		var wd2 := r.range_f(8.0, 13.0)
		_buildings.append({"a": Vector2(-62.0, y), "b": Vector2(-62.0, y + wd2), "h": r.range_f(9.0, 15.0), "col": palette[r.range_i(0, 4)], "seed": r.next_u32()})
		y += wd2


# ------------------------------------------------------------------ projection
func depth_of(p: Vector3) -> float:
	var d := CAM.x - p.x
	var h := p.z - CAM.z
	return d * _ca - h * _sa


func project(p: Vector3) -> Vector2:
	var d := CAM.x - p.x
	var lat := p.y - CAM.y
	var h := p.z - CAM.z
	var depth := maxf(d * _ca - h * _sa, 0.6)
	var v := d * _sa + h * _ca
	return Vector2(W * 0.5 + F * lat / depth, H * 0.5 - F * v / depth)


func scale_at(p: Vector3) -> float:
	return F / maxf(depth_of(p), 0.6)


func _lit(c: Color) -> Color:
	var a := w.atm.ambient
	return Color(c.r * a.r, c.g * a.g, c.b * a.b, c.a)


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


# ------------------------------------------------------------------ drawing
func invalidate() -> void:
	_static_key = ""


func _draw_static() -> void:
	_ci = static_layer
	_sky()
	_stands()
	_ground()
	_pitch()


func _draw() -> void:
	var vs := get_viewport_rect().size
	W = vs.x
	H = vs.y
	F = H * 1.25
	var key := "%d:%d:%s" % [int(W), int(H), w.atm.id]
	if key != _static_key:
		_static_key = key
		static_layer.queue_redraw()
	_actors()
	_ball()


func _sky() -> void:
	var atm := w.atm
	var bands := 20
	var horizon := H * 0.5 - F * tan(deg_to_rad(PITCH_DEG))
	for i in bands:
		var t0 := float(i) / bands
		_ci.draw_rect(Rect2(0, horizon * t0, W, horizon / bands + 1.0), atm.sky_top.lerp(atm.sky_bottom, t0))
	if atm.stars:
		var r := DetRng.new(9)
		for i in 60:
			_ci.draw_circle(Vector2(r.next_float() * W, r.next_float() * horizon * 0.8), 1.2, Color(1, 1, 1, 0.6))
	if atm.sun:
		var sp := Vector2(W * 0.8, horizon * (0.35 if atm.id == "day" else 0.85))
		for k in range(5, 0, -1):
			_ci.draw_circle(sp, 34.0 * k, Color(atm.sun_color.r, atm.sun_color.g, atm.sun_color.b, 0.04))
		_ci.draw_circle(sp, 28.0, atm.sun_color)
	elif atm.moon:
		_ci.draw_circle(Vector2(W * 0.8, horizon * 0.3), 20.0, Color(0.93, 0.93, 0.86))


func _stands() -> void:
	# Sort far -> near by depth of the building centre.
	var list := _buildings.duplicate()
	list.sort_custom(func(a, b): return depth_of(Vector3((a["a"].x + a["b"].x) * 0.5, (a["a"].y + a["b"].y) * 0.5, 0)) > depth_of(Vector3((b["a"].x + b["b"].x) * 0.5, (b["a"].y + b["b"].y) * 0.5, 0)))
	for bld in list:
		var a: Vector2 = bld["a"]
		var b: Vector2 = bld["b"]
		if CAM.x - maxf(a.x, b.x) < 1.5:
			continue
		var h: float = bld["h"]
		var col: Color = _lit(bld["col"])
		var quad := PackedVector2Array([project(Vector3(a.x, a.y, 0)), project(Vector3(b.x, b.y, 0)), project(Vector3(b.x, b.y, h)), project(Vector3(a.x, a.y, h))])
		_ci.draw_colored_polygon(quad, col)
		_ci.draw_polyline(PackedVector2Array([quad[3], quad[2]]), _lit(col.darkened(0.3)), 3.0)
		# Windows (glow at night/evening)
		var r := DetRng.new(int(bld["seed"]))
		var floors := int(h / 3.2)
		var cols := int(a.distance_to(b) / 3.0)
		for fl in floors:
			for c in cols:
				var u0 := (c + 0.3) / cols
				var u1 := (c + 0.7) / cols
				var z0 := 1.2 + fl * 3.2
				var p0 := a.lerp(b, u0)
				var p1 := a.lerp(b, u1)
				var win := PackedVector2Array([project(Vector3(p0.x, p0.y, z0)), project(Vector3(p1.x, p1.y, z0)), project(Vector3(p1.x, p1.y, z0 + 1.5)), project(Vector3(p0.x, p0.y, z0 + 1.5))])
				var lit := r.chance(0.45)
				var wc := Color(1.0, 0.84, 0.5) if (lit and w.atm.window_glow) else _lit(Color(0.25, 0.22, 0.26))
				_ci.draw_colored_polygon(win, wc)
		# Rooftop spectators
		var n := r.range_i(2, 6)
		for s in n:
			var u := r.range_f(0.1, 0.9)
			var p := a.lerp(b, u)
			var base := project(Vector3(p.x, p.y, h))
			var k := scale_at(Vector3(p.x, p.y, h))
			var shirt: Color = [GroundView.EMERALD, Color(0.95, 0.93, 0.88), GroundView.TERRACOTTA, Color(0.3, 0.45, 0.7), GroundView.GOLD.darkened(0.2)][r.range_i(0, 4)]
			_ci.draw_rect(Rect2(base + Vector2(-0.22 * k, -0.9 * k), Vector2(0.44 * k, 0.9 * k)), _lit(shirt))
			_ci.draw_circle(base + Vector2(0, -1.05 * k), 0.16 * k, _lit(Color(0.6, 0.42, 0.3)))
	# Brick boundary walls on three sides
	for seg in [[Vector2(-58, -37), Vector2(4, -37)], [Vector2(-58, 37), Vector2(4, 37)], [Vector2(-58, -37), Vector2(-58, 37)]]:
		var a2: Vector2 = seg[0]
		var b2: Vector2 = seg[1]
		var steps := 12
		for i in steps:
			var p0 := a2.lerp(b2, float(i) / steps)
			var p1 := a2.lerp(b2, float(i + 1) / steps)
			if CAM.x - maxf(p0.x, p1.x) < 1.2:
				continue
			var q := PackedVector2Array([project(Vector3(p0.x, p0.y, 0)), project(Vector3(p1.x, p1.y, 0)), project(Vector3(p1.x, p1.y, 3.0)), project(Vector3(p0.x, p0.y, 3.0))])
			_ci.draw_colored_polygon(q, _lit(GroundView.BRICK))
			_ci.draw_line(q[3], q[2], _lit(GroundView.PLASTER), 3.0)
	# Bunting across the far end
	var prev := Vector2.ZERO
	for i in 41:
		var u := i / 40.0
		var p := project(Vector3(-56.0, lerpf(-36.0, 36.0, u), 9.0 - sin(u * PI * 3.0) * 0.8))
		if i > 0:
			_ci.draw_line(prev, p, _lit(Color(0.2, 0.18, 0.16)), 1.5)
			var tri := PackedVector2Array([p + Vector2(-5, 0), p + Vector2(5, 0), p + Vector2(0, 11)])
			_ci.draw_colored_polygon(tri, _lit([GroundView.EMERALD, GroundView.GOLD, Color(0.97, 0.95, 0.9), GroundView.TERRACOTTA][i % 4]))
		prev = p
	if w.atm.floodlights:
		for t in [Vector2(-44.0, -34.0), Vector2(-50.0, 34.0)]:
			var b3 := project(Vector3(t.x, t.y, 0))
			var top := project(Vector3(t.x, t.y, 22))
			_ci.draw_line(b3, top, _lit(Color(0.3, 0.3, 0.34)), 6.0)
			_ci.draw_rect(Rect2(top + Vector2(-34, -26), Vector2(68, 30)), Color(0.2, 0.2, 0.24))
			for k2 in range(5, 0, -1):
				_ci.draw_circle(top + Vector2(0, -10), 26.0 * k2, Color(1.0, 0.97, 0.8, 0.06))
			_ci.draw_rect(Rect2(top + Vector2(-30, -22), Vector2(60, 22)), Color(1.0, 0.98, 0.9))


func _ellipse_pts(scale: float, n: int = 72) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var v := w.venue
	for i in n:
		var a := TAU * i / n
		pts.append(project(Vector3(v.boundary_center.x + cos(a) * v.boundary_rx * scale, v.boundary_center.y + sin(a) * v.boundary_ry * scale, 0.0)))
	return pts


func _ground() -> void:
	var horizon := H * 0.5 - F * tan(deg_to_rad(PITCH_DEG))
	_ci.draw_rect(Rect2(0, horizon - 2.0, W, H - horizon + 2.0), _lit(Color(0.72, 0.45, 0.32)))
	var v := w.venue
	_ci.draw_colored_polygon(_ellipse_pts(1.03), _lit(v.ground_edge_color.darkened(0.1)))
	_ci.draw_colored_polygon(_ellipse_pts(1.0), _lit(v.ground_edge_color))
	# Mown stripes, clipped to what is in front of the camera, then projected.
	var front := PackedVector2Array([Vector2(-200, -200), Vector2(CAM.x - 1.0, -200), Vector2(CAM.x - 1.0, 200), Vector2(-200, 200)])
	for st in GroundView.grass_stripes(v, 0.97):
		for poly in Geometry2D.intersect_polygons(st["poly"], front):
			var pp := PackedVector2Array()
			for q in poly:
				pp.append(project(Vector3(q.x, q.y, 0.0)))
			_ci.draw_colored_polygon(pp, _lit(v.ground_color.lightened(0.06) if st["light"] else v.ground_color.darkened(0.04)))
	if w.atm.floodlights:
		_ci.draw_colored_polygon(_ellipse_pts(0.55), Color(1.0, 1.0, 0.9, 0.06))
	var rope := _ellipse_pts(1.0, 120)
	# Only draw the rope segments in front of the camera.
	for i in rope.size():
		var a := TAU * i / 120.0
		var wx := v.boundary_center.x + cos(a) * v.boundary_rx
		if CAM.x - wx > 1.5:
			var j := (i + 1) % rope.size()
			var a2 := TAU * j / 120.0
			if CAM.x - (v.boundary_center.x + cos(a2) * v.boundary_rx) > 1.5:
				_ci.draw_line(rope[i], rope[j], _lit(v.boundary_color), 3.0, true)
	for p in _tufts:
		if CAM.x - p.x < 2.0:
			continue
		var s := project(Vector3(p.x, p.y, 0))
		var k := scale_at(Vector3(p.x, p.y, 0))
		var gc := _lit(w.venue.ground_color.darkened(0.2))
		gc.a = 0.7
		_ci.draw_line(s, s + Vector2(-0.06 * k, -0.12 * k), gc, maxf(1.0, 0.02 * k))
		_ci.draw_line(s, s + Vector2(0.05 * k, -0.14 * k), gc, maxf(1.0, 0.02 * k))


func _pitch() -> void:
	var hw := 1.52
	var q := PackedVector2Array([project(Vector3(-22.0, -hw, 0)), project(Vector3(-22.0, hw, 0)), project(Vector3(1.8, hw, 0)), project(Vector3(1.8, -hw, 0))])
	_ci.draw_colored_polygon(q, _lit(w.venue.pitch_color))
	for c in [Vector2(-1.3, 0.0), Vector2(-5.5, 0.1), Vector2(-18.9, 0.3)]:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(project(Vector3(c.x + cos(a) * 1.3, c.y + sin(a) * 0.8, 0)))
		_ci.draw_colored_polygon(pts, _lit(w.venue.pitch_color.darkened(0.1)))
	var white := _lit(Color(0.98, 0.97, 0.94))
	for end_x in [0.0, Delivery.BOWLING_STUMPS_X]:
		var sgn := 1.0 if end_x == 0.0 else -1.0
		var pop: float = end_x - 1.22 * sgn
		_ci.draw_line(project(Vector3(pop, -1.83, 0)), project(Vector3(pop, 1.83, 0)), white, maxf(1.5, 0.05 * scale_at(Vector3(pop, 0, 0))), true)
		_ci.draw_line(project(Vector3(end_x, -1.32, 0)), project(Vector3(end_x, 1.32, 0)), white, maxf(1.0, 0.035 * scale_at(Vector3(end_x, 0, 0))), true)
		for yy in [-1.32, 1.32]:
			_ci.draw_line(project(Vector3(end_x + 0.3 * sgn, yy, 0)), project(Vector3(pop - 1.0 * sgn, yy, 0)), white, 1.5, true)


# ------------------------------------------------------------------ actors
func _actors() -> void:
	var t := w.clock
	var items: Array = []   # [depth, callable]
	for i in range(2, w.specs.size()):
		var s: FielderSpec = w.specs[i]
		if CAM.x - s.pos.x < 3.0:
			continue
		var fp := Vector3(s.pos.x, s.pos.y, 0)
		items.append([depth_of(fp), _figure.bind(fp, w.fielding_kit, {"crouch": 0.35 if t > -0.8 else 0.0, "front": true, "t": t + i, "cap": true})])
	items.append([depth_of(Vector3(WorldView.UMPIRE_POS.x, WorldView.UMPIRE_POS.y, 0)), _figure.bind(Vector3(WorldView.UMPIRE_POS.x, WorldView.UMPIRE_POS.y, 0), Color(0.95, 0.93, 0.88), {"front": true, "t": t, "hat": true, "trousers": Color(0.2, 0.2, 0.25)})])
	if w.two_batters:
		var ns := Vector3(WorldView.NON_STRIKER_BASE.x + 1.2 * Poses.ease_io((t + 0.6) / 1.0), WorldView.NON_STRIKER_BASE.y, 0)
		items.append([depth_of(ns), _figure.bind(ns, w.batting_kit, {"front": true, "t": t, "helmet": true, "bat": true, "pads": true, "trousers": WorldView.trouser_colour(w.batting_kit)})])
	items.append([depth_of(Vector3(Delivery.BOWLING_STUMPS_X, 0, 0)), _stumps.bind(Vector3(Delivery.BOWLING_STUMPS_X, 0, 0), -1.0)])
	if w.delivery != null and w.profile != null:
		var root := w._run_up_root(t)
		var bp := Vector3(root.x, root.y, 0)
		items.append([depth_of(bp), _bowler.bind(bp, t)])
	items.sort_custom(func(a, b): return a[0] > b[0])
	for it in items:
		it[1].call()
	_batter(t)
	var bowled_t := -1.0
	if w.resolved != null and w.resolved.outcome.kind == BallOutcome.BOWLED and t >= w.delivery.stumps_time():
		bowled_t = t - w.delivery.stumps_time()
	_stumps(Vector3(0, 0, 0), bowled_t)


## Screen-space tapered segment with soft edge and side shading (for perspective figures).
func _tq(a: Vector2, b: Vector2, w0: float, w1: float, c: Color) -> void:
	var d := b - a
	if d.length() < 0.5:
		draw_circle(a, w0 * 0.5, c, true, -1.0, true)
		return
	var n := Vector2(-d.y, d.x).normalized()
	var e := c.darkened(0.5)
	draw_colored_polygon(PackedVector2Array([a + n * (w0 * 0.5 + 1.2), b + n * (w1 * 0.5 + 1.2), b - n * (w1 * 0.5 + 1.2), a - n * (w0 * 0.5 + 1.2)]), e)
	draw_circle(a, w0 * 0.5 + 1.2, e, true, -1.0, true)
	draw_circle(b, w1 * 0.5 + 1.2, e, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5]), c)
	draw_circle(a, w0 * 0.5, c, true, -1.0, true)
	draw_circle(b, w1 * 0.5, c, true, -1.0, true)
	var lit := n if n.x < 0.0 else -n
	draw_colored_polygon(PackedVector2Array([a + lit * w0 * 0.42, b + lit * w1 * 0.42, b + lit * w1 * 0.1, a + lit * w0 * 0.1]), Color(1, 1, 1, 0.14))
	draw_colored_polygon(PackedVector2Array([a - lit * w0 * 0.48, b - lit * w1 * 0.48, b - lit * w1 * 0.2, a - lit * w0 * 0.2]), Color(0, 0, 0, 0.14))


## Torso as a trapezoid (hips -> shoulders) with soft shading.
func _torso_shape(hipc: Vector2, shc: Vector2, hw: float, sw: float, c: Color) -> void:
	var up := (shc - hipc).normalized()
	var n := Vector2(-up.y, up.x)
	var mid := hipc.lerp(shc, 0.6)
	var poly := PackedVector2Array([hipc + n * hw * 0.5, mid + n * sw * 0.47, shc + n * sw * 0.5, shc - n * sw * 0.5, mid - n * sw * 0.47, hipc - n * hw * 0.5])
	var edge := PackedVector2Array()
	var cen := hipc.lerp(shc, 0.5)
	for v in poly:
		edge.append(v + (v - cen).normalized() * 1.3)
	draw_colored_polygon(edge, c.darkened(0.5))
	draw_colored_polygon(poly, c)
	draw_colored_polygon(PackedVector2Array([poly[3], poly[4], poly[5], hipc - n * hw * 0.15, shc - n * sw * 0.2]), Color(1, 1, 1, 0.1))
	draw_colored_polygon(PackedVector2Array([poly[0], poly[1], poly[2], shc + n * sw * 0.25, hipc + n * hw * 0.2]), Color(0, 0, 0, 0.13))


func _figure(p: Vector3, kit: Color, o: Dictionary) -> void:
	var k := scale_at(p)
	var base := project(p)
	var t: float = o.get("t", 0.0)
	var crouch: float = o.get("crouch", 0.0)
	var run: float = o.get("run", 0.0)
	var phase: float = o.get("phase", 0.0)
	var skin: Color = _lit(o.get("skin", Color(0.7, 0.5, 0.36)))
	var trousers: Color = _lit(o.get("trousers", Color(0.95, 0.94, 0.9)))
	var shirt := _lit(kit)
	var ink := Color(0.1, 0.08, 0.07)
	var hip_h := 0.92 - crouch * 0.3
	var sh_h := hip_h + 0.52
	var lw := maxf(2.0, 0.13 * k)
	# Shadow
	draw_set_transform(base, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 0.4 * k, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Legs (running lifts alternate feet; toward-camera stride shown as lift + spread)
	for side in [-1.0, 1.0]:
		var lift := maxf(0.0, sin(phase + (0.0 if side < 0.0 else PI))) * 0.35 * run
		var hip := base + Vector2(side * 0.1 * k, -hip_h * k)
		var foot := base + Vector2(side * (0.13 + crouch * 0.1) * k, -lift * k)
		var knee := hip.lerp(foot, 0.5) + Vector2(side * crouch * 0.12 * k, -lift * 0.3 * k)
		_tq(hip, knee, 0.17 * k, 0.12 * k, trousers)
		_tq(knee, foot, 0.12 * k, 0.08 * k, trousers)
		if o.get("pads", false):
			_tq(knee.lerp(hip, 0.15), foot, 0.16 * k, 0.13 * k, _lit(Color(0.97, 0.96, 0.92)))
		draw_colored_polygon(PackedVector2Array([foot + Vector2(-0.07 * k, 0), foot + Vector2(0.07 * k, 0), foot + Vector2(0.06 * k, -0.06 * k), foot + Vector2(-0.06 * k, -0.06 * k)]), Color(0.18, 0.16, 0.16))
	# Torso (broader shoulders) + collar
	var hipc := base + Vector2(0, -hip_h * k)
	var shc := base + Vector2(0, -sh_h * k)
	_torso_shape(hipc + Vector2(0, 0.04 * k), shc, 0.3 * k, 0.42 * k, shirt)
	draw_line(hipc + Vector2(-0.15 * k, 0.02 * k), hipc + Vector2(0.15 * k, 0.02 * k), trousers.darkened(0.25), maxf(1.0, 0.03 * k), true)
	if o.get("front", false):
		draw_colored_polygon(PackedVector2Array([shc + Vector2(-0.06 * k, 0), shc + Vector2(0.06 * k, 0), shc + Vector2(0, 0.08 * k)]), shirt.lightened(0.4))
	# Arms with short sleeves
	var arm_l: float = o.get("arm_l", 0.35 + crouch)
	var arm_r: float = o.get("arm_r", 0.35 + crouch)
	if run > 0.0:
		arm_l = 0.3 + 0.5 * sin(phase)
		arm_r = 0.3 - 0.5 * sin(phase)
	for side in [-1.0, 1.0]:
		var sh := shc + Vector2(side * 0.2 * k, 0.04 * k)
		var ang: float = arm_l if side < 0.0 else arm_r
		var hand := sh + Vector2(side * sin(ang) * 0.58 * k, cos(ang) * 0.58 * k)
		var elbow := sh.lerp(hand, 0.52)
		_tq(sh, elbow, 0.11 * k, 0.085 * k, skin)
		_tq(sh, sh.lerp(elbow, 0.6), 0.13 * k, 0.11 * k, shirt)
		_tq(elbow, hand, 0.085 * k, 0.065 * k, skin)
	if o.has("windmill"):
		var phi: float = o["windmill"]
		var sh2 := shc + Vector2(0.2 * k, 0.04 * k)
		var hand2 := sh2 + Vector2(0.08 * k * sin(phi), cos(phi) * 0.6 * k)
		_tq(sh2, sh2.lerp(hand2, 0.55), 0.11 * k, 0.085 * k, skin)
		_tq(sh2, sh2.lerp(hand2, 0.3), 0.13 * k, 0.11 * k, shirt)
		_tq(sh2.lerp(hand2, 0.55), hand2, 0.085 * k, 0.065 * k, skin)
		if o.get("ball_in_hand", false):
			draw_circle(hand2, maxf(3.0, 0.07 * k), Color(1.0, 0.95, 0.5))
		if o.get("track_hand", false):
			_hand_screen = hand2
	if o.get("bat", false):
		var hb := shc + Vector2(0.15 * k, 0.45 * k)
		draw_line(hb, hb + Vector2(0.05 * k, 0.8 * k), ink, 0.12 * k + 2.0, true)
		draw_line(hb, hb + Vector2(0.05 * k, 0.8 * k), _lit(Color(0.93, 0.82, 0.58)), 0.12 * k, true)
	# Neck + head (oval), hair or headgear, simple face when facing the camera
	var hc := shc + Vector2(0, -0.19 * k)
	_tq(shc, hc + Vector2(0, 0.06 * k), 0.1 * k, 0.09 * k, skin)
	var hr := 0.115 * k
	draw_set_transform(hc, 0.0, Vector2(0.92, 1.08))
	draw_circle(Vector2.ZERO, hr + 1.3, skin.darkened(0.45), true, -1.0, true)
	draw_circle(Vector2.ZERO, hr, skin, true, -1.0, true)
	draw_circle(Vector2(hr * 0.3, hr * 0.15), hr * 0.65, Color(0, 0, 0, 0.08), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if o.get("helmet", false):
		draw_arc(hc, hr * 1.12, PI * 0.95, TAU + 0.05, 18, _lit(kit.darkened(0.25)), 0.12 * k, true)
	elif o.get("hat", false):
		draw_rect(Rect2(hc + Vector2(-0.19 * k, -0.11 * k), Vector2(0.38 * k, 0.04 * k)), _lit(Color(0.96, 0.95, 0.9)))
		draw_rect(Rect2(hc + Vector2(-0.1 * k, -0.2 * k), Vector2(0.2 * k, 0.1 * k)), _lit(Color(0.96, 0.95, 0.9)))
	elif o.get("cap", false):
		draw_arc(hc, hr * 1.02, PI, TAU, 16, _lit(kit.darkened(0.25)), 0.09 * k, true)
		draw_line(hc + Vector2(-0.07 * k, -0.06 * k), hc + Vector2(0.07 * k, -0.06 * k), _lit(kit.darkened(0.35)), maxf(1.0, 0.03 * k), true)
	else:
		draw_arc(hc, hr * 0.98, PI * 0.95, TAU + 0.05, 16, Color(0.08, 0.06, 0.05), 0.08 * k, true)
	if o.get("front", false) and k > 22.0:
		draw_circle(hc + Vector2(-0.04 * k, 0.0), maxf(1.0, 0.014 * k), ink)
		draw_circle(hc + Vector2(0.04 * k, 0.0), maxf(1.0, 0.014 * k), ink)
		draw_line(hc + Vector2(-0.035 * k, 0.06 * k), hc + Vector2(0.035 * k, 0.06 * k), skin.darkened(0.35), maxf(1.0, 0.01 * k), true)
		if o.get("beard", false):
			draw_arc(hc + Vector2(0, 0.02 * k), hr * 0.85, 0.2, PI - 0.2, 10, Color(0.1, 0.08, 0.06), 0.05 * k, true)


func _bowler(p: Vector3, t: float) -> void:
	var T := w.profile.run_up_time
	var o := {"front": true, "t": t, "skin": w.profile.skin_tone}
	if t < -T:
		o["ball_in_hand"] = true
	elif t < -0.55:
		o["run"] = 1.0
		o["phase"] = WorldView.RUN_SPEED * (t + T) * 1.35
	elif t < -0.3:
		o["arm_l"] = PI * 0.85
		o["windmill"] = 0.4
		o["ball_in_hand"] = true
	elif t < 0.0:
		var u := (t + 0.3) / 0.3
		o["arm_l"] = lerpf(PI * 0.85, 0.3, u * u)
		o["windmill"] = lerpf(0.3, PI + 0.25, u * u)
		o["ball_in_hand"] = true
		o["track_hand"] = true
	elif t < 0.7:
		var u2 := t / 0.7
		o["windmill"] = lerpf(PI + 0.25, TAU - 0.3, 1.0 - (1.0 - u2) * (1.0 - u2))
		o["crouch"] = 0.3 * sin(u2 * PI)
	else:
		o["crouch"] = 0.35
	_figure(p, w.fielding_kit, o)


## The striker: a 3D skeleton (BatterSkeleton) seen through this camera - side-on, as a
## real right-hander looks from behind the stumps - drawn as shaded, rounded body parts.
func _batter(t: float) -> void:
	var j := BatterSkeleton.solve(t, _skeleton_opts(t))
	_batter_shadow(j)
	var shirt := w.batting_kit
	var trousers := WorldView.trouser_colour(w.batting_kit)
	var skin := w.skin_tone_batter
	var white := Color(0.96, 0.95, 0.92)
	var parts: Array = []   # [depth, callable]
	for s in ["l", "r"]:
		var hip: Vector3 = j["hip_" + s]
		var knee: Vector3 = j["knee_" + s]
		var ankle: Vector3 = j["ankle_" + s]
		parts.append([depth_of(hip.lerp(knee, 0.5)), _cap3.bind(hip, knee, 0.088, 0.062, trousers)])
		parts.append([depth_of(knee.lerp(ankle, 0.5)) + 0.01, _cap3.bind(knee, ankle, 0.058, 0.045, trousers)])
		parts.append([depth_of(knee.lerp(ankle, 0.5)) - 0.03, _pad.bind(j, s, white)])
		parts.append([depth_of(j["toe_" + s]) - 0.02, _shoe.bind(j, s, white)])
		var sh: Vector3 = j["sh_" + s]
		var el: Vector3 = j["el_" + s]
		var wr: Vector3 = j["wr_" + s]
		parts.append([depth_of(sh.lerp(el, 0.5)) - 0.02, _arm_upper.bind(sh, el, skin, shirt)])
		parts.append([depth_of(el.lerp(wr, 0.5)) - 0.03, _cap3.bind(el, wr, 0.046, 0.038, skin)])
	parts.append([depth_of(j["chest"]), _torso3.bind(j, shirt, trousers)])
	parts.append([depth_of(j["head"]), _head3.bind(j, skin)])
	parts.append([depth_of(j["bat_sweet"]), _bat3.bind(j)])
	for h in ["hand_top", "hand_bot"]:
		parts.append([depth_of(j[h]) - 0.08, _glove.bind(j[h], j["bat_dir"], white, shirt)])
	parts.sort_custom(func(a, b): return a[0] > b[0])
	for p in parts:
		p[1].call()
	_bat_trail(j)


func _skeleton_opts(t: float) -> Dictionary:
	var o := {"swing_time": w.swing_time, "swing_dur": WorldView.SWING_DUR, "contact_u": Poses.CONTACT_U,
		"base": WorldView.STRIKER_BASE, "runup_t": w.profile.run_up_time if w.profile else 2.0}
	var look := Vector3(-18.0, 0.0, 1.9)
	if w.delivery != null:
		o["stumps_t"] = w.delivery.stumps_time()
		o["ideal_t"] = w.delivery.time_at_x(w.tuning.contact_x_ideal)
		if t < 0.0:
			var r := w._run_up_root(t)
			look = Vector3(r.x, r.y, 2.0)
		else:
			var bp := w.ball_world(t)
			if bp != Vector3.INF:
				look = bp
	o["look"] = look
	if w.resolved != null:
		if w.resolved.contact.is_contact():
			o["target"] = w.resolved.contact.contact_pos
		o["bowled"] = w.resolved.outcome.kind == BallOutcome.BOWLED
	if not o.has("target") and w.delivery != null and w.swing_time >= 0.0:
		var p := w.delivery.pos_at(w.swing_time + w.tuning.swing_to_contact)
		o["target"] = Vector3(p.x, p.y, clampf(p.z, 0.1, 1.2))
	return o


const LIGHT2 := Vector2(-0.55, -0.83)


static func _shade(c: Color, k: float) -> Color:
	return c.lightened(0.2 * k) if k > 0.0 else c.darkened(0.42 * -k)


## Filled convex outline with per-vertex lighting from its centre (rounded, lit look).
func _lit_poly(pts: PackedVector2Array, c: Color, edge := true) -> void:
	if pts.size() < 3:
		return
	var cen := Vector2.ZERO
	for v in pts:
		cen += v
	cen /= pts.size()
	if edge:
		var e := PackedVector2Array()
		for v in pts:
			e.append(v + (v - cen).normalized() * 1.3)
		draw_colored_polygon(e, c.darkened(0.55))
	var cols := PackedColorArray()
	for v in pts:
		cols.append(_shade(c, (v - cen).normalized().dot(LIGHT2)))
	draw_polygon(pts, cols)


func _hull(pts: PackedVector2Array) -> PackedVector2Array:
	var h := Geometry2D.convex_hull(pts)
	if h.size() > 1 and h[0] == h[h.size() - 1]:
		h.remove_at(h.size() - 1)
	return h


## Shaded capsule between two 3D points (radii in metres, perspective-scaled).
func _cap3(a: Vector3, b: Vector3, ra: float, rb: float, col: Color) -> void:
	var c := _lit(col)
	var pa := project(a)
	var pb := project(b)
	var r0 := ra * scale_at(a)
	var r1 := rb * scale_at(b)
	var d := pb - pa
	var ang := d.angle() if d.length() > 0.01 else 0.0
	var pts := PackedVector2Array()
	for i in 9:
		var q := ang + PI * 0.5 + PI * i / 8.0
		pts.append(pa + Vector2(cos(q), sin(q)) * r0)
	for i in 9:
		var q := ang - PI * 0.5 + PI * i / 8.0
		pts.append(pb + Vector2(cos(q), sin(q)) * r1)
	var e := PackedVector2Array()
	var cols := PackedColorArray()
	for i in pts.size():
		var cen := pa if i < 9 else pb
		var nrm := (pts[i] - cen).normalized()
		e.append(pts[i] + nrm * 1.2)
		cols.append(_shade(c, nrm.dot(LIGHT2)))
	draw_colored_polygon(e, c.darkened(0.55))
	draw_polygon(pts, cols)


func _arm_upper(sh: Vector3, el: Vector3, skin: Color, shirt: Color) -> void:
	_cap3(sh, el, 0.052, 0.044, skin)
	# Shoulder (deltoid) under the sleeve, then the sleeve itself.
	_cap3(sh + Vector3(0, 0, 0.01), sh.lerp(el, 0.3), 0.075, 0.066, shirt)
	_cap3(sh, sh.lerp(el, 0.58), 0.066, 0.058, shirt)


## Ground shadow: one soft shape (no double-darkening) plus contact shadows under the shoes.
func _batter_shadow(j: Dictionary) -> void:
	var off := Vector2(0.32, 0.28)   # metres of shadow travel per metre of height
	var pts := PackedVector2Array()
	for k in ["toe_l", "heel_l", "toe_r", "heel_r", "knee_l", "knee_r", "pelvis", "sh_l", "sh_r", "head", "hand_top", "el_l", "el_r"]:
		var p: Vector3 = j[k]
		pts.append(project(Vector3(p.x + p.z * off.x, p.y + p.z * off.y, 0.0)))
	var h := _hull(pts)
	if h.size() >= 3:
		draw_colored_polygon(h, Color(0, 0, 0, 0.16 * w.atm.ambient.v))
	for s in ["l", "r"]:
		var c := project(j["toe_" + s].lerp(j["heel_" + s], 0.5) * Vector3(1, 1, 0))
		var k := scale_at(j["ankle_" + s])
		draw_set_transform(c, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, 0.13 * k, Color(0, 0, 0, 0.22), true, -1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pad(j: Dictionary, s: String, white: Color) -> void:
	var knee: Vector3 = j["knee_" + s]
	var ankle: Vector3 = j["ankle_" + s]
	var fwd: Vector3 = j["toe_dir_" + s]
	var top := knee + Vector3(0, 0, 0.08) + fwd * 0.035
	var bot := ankle + fwd * 0.045 + Vector3(0, 0, -0.02)
	_cap3(top, bot, 0.078, 0.068, white)
	var c := _lit(white)
	var pt := project(top)
	var pb := project(bot)
	var d := (pb - pt).normalized()
	var n := Vector2(-d.y, d.x)
	var k := scale_at(knee)
	# Vertical ridges (canes) down the pad face.
	for r in [-0.035, 0.0, 0.035]:
		draw_line(pt + n * r * k + d * 0.06 * k, pb + n * r * k * 0.85, c.darkened(0.16), maxf(1.0, 0.008 * k), true)
	# Knee roll and the straps around the back of the calf.
	draw_set_transform(project(knee + Vector3(0, 0, 0.03) + fwd * 0.04), d.angle() + PI * 0.5, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 0.07 * k, c.darkened(0.08), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for f in [0.3, 0.62, 0.9]:
		var q := pt.lerp(pb, f)
		draw_line(q - n * 0.075 * k, q + n * 0.075 * k, _lit(Color(0.25, 0.25, 0.28)), maxf(1.2, 0.014 * k), true)


func _shoe(j: Dictionary, s: String, white: Color) -> void:
	var toe: Vector3 = j["toe_" + s]
	var heel: Vector3 = j["heel_" + s]
	var fwd: Vector3 = (toe - heel).normalized()
	var side := fwd.cross(Vector3(0, 0, 1)).normalized()
	var pts := PackedVector2Array()
	for p in [heel, toe]:
		for sd in [-0.045, 0.045]:
			for h in [0.0, 0.085 if p == heel else 0.05]:
				pts.append(project(p + side * sd + Vector3(0, 0, h)))
	_lit_poly(_hull(pts), _lit(white))
	# Sole
	var sole := PackedVector2Array([project(heel + side * 0.045), project(toe + side * 0.045), project(toe - side * 0.045), project(heel - side * 0.045)])
	draw_polyline(sole, _lit(Color(0.3, 0.3, 0.32)), maxf(1.2, 0.012 * scale_at(toe)), true)


func _torso3(j: Dictionary, shirt: Color, trousers: Color) -> void:
	var pel: Vector3 = j["pelvis"]
	var spine: Vector3 = j["spine"]
	var side: Vector3 = j["side"]
	var fwd: Vector3 = j["fwd"]
	var pside: Vector3 = j["pel_side"]
	var pfwd := Vector3(0, 0, 1).cross(pside).normalized() * -1.0
	if pfwd.dot(fwd) < 0.0:
		pfwd = -pfwd
	# Hips / seat in trousers.
	var hip_pts := PackedVector2Array()
	for ring in [[pel - spine * 0.06, 0.17, 0.13], [pel + spine * 0.1, 0.16, 0.12]]:
		for i in 14:
			var a := TAU * i / 14.0
			hip_pts.append(project(ring[0] + pside * cos(a) * ring[1] + pfwd * sin(a) * ring[2]))
	_lit_poly(_hull(hip_pts), _lit(trousers))
	# Shirt: waist -> chest -> shoulders, a rounded volume.
	var pts := PackedVector2Array()
	for ring in [[0.1, 0.16, 0.12], [0.24, 0.175, 0.14], [0.36, 0.205, 0.15], [0.45, 0.215, 0.12]]:
		var c: Vector3 = pel + spine * float(ring[0])
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(project(c + side * cos(a) * float(ring[1]) + fwd * sin(a) * float(ring[2])))
	var hull := _hull(pts)
	_lit_poly(hull, _lit(shirt))
	# Fabric folds on the shaded side and the collar.
	var k := scale_at(j["chest"])
	var a0 := project(pel + spine * 0.14 - side * 0.12)
	var a1 := project(pel + spine * 0.4 - side * 0.15)
	draw_line(a0, a1, _lit(shirt).darkened(0.25), maxf(1.0, 0.01 * k), true)
	draw_line(project(pel + spine * 0.16 + fwd * 0.08), project(pel + spine * 0.3 + fwd * 0.11), _lit(shirt).darkened(0.18), maxf(1.0, 0.008 * k), true)
	var nb: Vector3 = j["neck_base"]
	var collar := PackedVector2Array()
	for i in 13:
		var a := TAU * i / 12.0
		collar.append(project(nb + side * cos(a) * 0.075 + fwd * sin(a) * 0.065))
	draw_polyline(collar, _lit(shirt).lightened(0.3), maxf(1.2, 0.016 * k), true)
	# Belt line
	draw_line(project(pel + spine * 0.1 + pside * 0.16), project(pel + spine * 0.1 - pside * 0.16), _lit(trousers).darkened(0.35), maxf(1.0, 0.012 * k), true)


func _head3(j: Dictionary, skin: Color) -> void:
	var hc: Vector3 = j["head"]
	var look: Vector3 = j["look"]
	var k := scale_at(hc)
	var sk := _lit(skin)
	var helmet := _lit(w.batting_kit.darkened(0.55))
	var up := Vector3(0, 0, 1)
	var fwd_h := Vector3(look.x, look.y, 0.0).normalized()
	var side := fwd_h.cross(up).normalized()
	# Neck and nape.
	_cap3(j["neck_base"], j["neck_top"], 0.055, 0.05, skin)
	# Grille bars sit in front of the face (far side from this camera) - draw first.
	var steel := _lit(Color(0.72, 0.74, 0.78))
	for i in 5:
		var a := -0.75 + 1.5 * i / 4.0
		var dirv := (fwd_h * cos(a) + side * sin(a)).normalized()
		var top := hc + dirv * 0.135 + up * 0.0
		var bot := hc + dirv * 0.13 - up * 0.13 + fwd_h * 0.02
		draw_line(project(top), project(bot), steel, maxf(1.0, 0.009 * k), true)
	draw_line(project(hc + (fwd_h - side * 0.6).normalized() * 0.14 - up * 0.07), project(hc + (fwd_h + side * 0.6).normalized() * 0.14 - up * 0.07), steel, maxf(1.0, 0.009 * k), true)
	# Head (skin: ear, cheek, jaw).
	var head_pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		head_pts.append(project(hc + side * cos(a) * 0.095 + up * sin(a) * 0.12 + fwd_h * 0.02))
	_lit_poly(_hull(head_pts), sk)
	draw_set_transform(project(hc - fwd_h * 0.01 - side * 0.09 - up * 0.01), 0.0, Vector2(0.7, 1.0))
	draw_circle(Vector2.ZERO, 0.026 * k, sk.darkened(0.15), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Helmet shell: covers the top and back of the head, peak over the eyes.
	var shell := PackedVector2Array()
	var sc := hc + up * 0.018
	for i in 22:
		for jj in 6:
			var lon := TAU * i / 22.0
			var lat := -0.25 + 1.45 * jj / 5.0
			var dirv := (fwd_h * cos(lon) * cos(lat) + side * sin(lon) * cos(lat) + up * sin(lat))
			if dirv.dot(fwd_h) > 0.55 and lat < 0.35:
				continue   # face opening
			shell.append(project(sc + dirv * 0.138))
	var sh_hull := _hull(shell)
	_lit_poly(sh_hull, helmet)
	# Peak
	var peak := PackedVector2Array()
	for i in 9:
		var a := -0.9 + 1.8 * i / 8.0
		var dirv := (fwd_h * cos(a) + side * sin(a))
		peak.append(project(sc + dirv * 0.135 + up * 0.035))
	for i in 9:
		var a := 0.9 - 1.8 * i / 8.0
		var dirv := (fwd_h * cos(a) + side * sin(a))
		peak.append(project(sc + dirv * 0.19 + up * 0.02))
	peak = _hull(peak)
	if peak.size() >= 3:
		draw_colored_polygon(peak, helmet.darkened(0.2))
	# Highlight, vents and the neck (stem) guard at the back.
	var hl := project(sc + (up * 0.8 - fwd_h * 0.3 - side * 0.4).normalized() * 0.12)
	draw_circle(hl, 0.03 * k, Color(1, 1, 1, 0.16), true, -1.0, true)
	for v: float in [-0.35, 0.0, 0.35]:
		var vd := (up * 0.75 - fwd_h * 0.55 + side * v).normalized()
		draw_circle(project(sc + vd * 0.137), maxf(1.0, 0.009 * k), helmet.darkened(0.5), true, -1.0, true)
	var back := -fwd_h
	for sd: float in [-0.035, 0.035]:
		var a := sc + back * 0.12 + side * sd - up * 0.1
		var b := a - up * 0.05 + back * 0.01
		_cap3(a, b, 0.012, 0.011, w.batting_kit.darkened(0.45))
	# Chin strap catches the light under the ear.
	draw_line(project(hc - side * 0.09 - up * 0.02), project(hc - side * 0.06 + fwd_h * 0.05 - up * 0.11), _lit(Color(0.85, 0.85, 0.85)), maxf(1.0, 0.007 * k), true)


func _glove(h: Vector3, bd: Vector3, white: Color, accent: Color) -> void:
	_cap3(h - bd * 0.03, h + bd * 0.045, 0.048, 0.045, white)
	var k := scale_at(h)
	var c := _lit(white)
	var pa := project(h - bd * 0.03)
	var pb := project(h + bd * 0.045)
	var d := (pb - pa).normalized()
	var n := Vector2(-d.y, d.x)
	for f in [0.2, 0.5, 0.8]:
		var q := pa.lerp(pb, f)
		draw_line(q - n * 0.04 * k, q + n * 0.04 * k, c.darkened(0.2), maxf(1.0, 0.007 * k), true)
	# Kit-coloured cuff
	var cuff := project(h - bd * 0.04)
	draw_line(cuff - n * 0.045 * k, cuff + n * 0.045 * k, _lit(accent), maxf(1.5, 0.018 * k), true)


func _bat3(j: Dictionary) -> void:
	var bd: Vector3 = j["bat_dir"]
	var face: Vector3 = j["bat_face"]
	var wv: Vector3 = j["bat_width"]
	var top: Vector3 = j["bat_top"]
	var shoulder: Vector3 = j["bat_shoulder"]
	var toe: Vector3 = j["bat_toe"]
	var k := scale_at(j["bat_sweet"])
	# Handle with rubber grip.
	_cap3(top, shoulder, 0.017, 0.016, Color(0.12, 0.13, 0.13))
	var grip := _lit(Color(0.1, 0.32, 0.24))
	draw_line(project(top), project(top.lerp(shoulder, 0.8)), grip, maxf(2.0, 0.026 * k), true)
	# Blade: box from shoulder to toe, face toward `face`, spine on the back.
	var hw := 0.054
	var corners := PackedVector2Array()
	var faces_cam := face.dot((CAM - j["bat_sweet"]).normalized()) > 0.0
	for p in [shoulder + bd * 0.02, toe]:
		for sd in [-hw, hw]:
			corners.append(project(p + wv * sd))
			corners.append(project(p + wv * sd - face * 0.035))
		corners.append(project(p - face * 0.06))
	var willow := _lit(Color(0.92, 0.82, 0.6))
	_lit_poly(_hull(corners), willow.darkened(0.12))
	var fp := PackedVector2Array()
	var off := Vector3.ZERO if faces_cam else -face * 0.06
	for p in [[shoulder + bd * 0.02, -hw], [shoulder + bd * 0.02, hw], [toe, hw], [toe, -hw]]:
		fp.append(project(p[0] + wv * p[1] * (1.0 if faces_cam else 0.4) + off))
	fp = _hull(fp)
	if fp.size() >= 3:
		draw_colored_polygon(fp, willow if faces_cam else willow.darkened(0.2))
	if faces_cam:
		# Maker's sticker band and grain on the face.
		var s0 := shoulder.lerp(toe, 0.12)
		var s1 := shoulder.lerp(toe, 0.3)
		var band := _hull(PackedVector2Array([project(s0 - wv * hw * 0.9), project(s0 + wv * hw * 0.9), project(s1 + wv * hw * 0.9), project(s1 - wv * hw * 0.9)]))
		if band.size() >= 3:
			draw_colored_polygon(band, _lit(w.batting_kit))
		for g in [-0.5, 0.0, 0.5]:
			draw_line(project(shoulder.lerp(toe, 0.35) + wv * hw * g), project(toe + wv * hw * g * 0.9), willow.darkened(0.08), 1.0, true)
	else:
		# Spine ridge down the back of the blade.
		draw_line(project(shoulder + bd * 0.05 - face * 0.06), project(toe - face * 0.05), willow.lightened(0.15), maxf(1.0, 0.01 * k), true)


func _bat_trail(j: Dictionary) -> void:
	var a := project(j["bat_sweet"])
	var b := project(j["bat_toe"])
	var u := -1.0
	if w.swing_time >= 0.0 and w.clock >= w.swing_time:
		u = (w.clock - w.swing_time) / WorldView.SWING_DUR
	if u > 0.05 and u < 0.75 and not w.reduced_motion:
		_trail.append([a, b])
		if _trail.size() > 7:
			_trail.pop_front()
		for i in range(1, _trail.size()):
			var a0: Array = _trail[i - 1]
			var a1: Array = _trail[i]
			var al := float(i) / _trail.size() * 0.35
			draw_colored_polygon(PackedVector2Array([a0[0], a0[1], a1[1], a1[0]]), Color(1.0, 0.97, 0.85, al))
	else:
		_trail.clear()


func _stumps(p: Vector3, broken_t: float) -> void:
	var k := scale_at(p)
	var ink := Color(0.1, 0.08, 0.07)
	var wood := _lit(Color(0.96, 0.9, 0.74))
	var h := Delivery.STUMPS_HEIGHT
	var bt := maxf(broken_t, 0.0)
	for i in 3:
		var off := (i - 1) * 0.1143
		var base := project(Vector3(p.x, p.y + off, 0))
		var tilt := 0.0
		if broken_t >= 0.0:
			tilt = minf(bt * 6.0, 1.0) * [-0.4, 0.2, 0.5][i]
		var top := base + Vector2(sin(tilt), -cos(tilt)) * h * k
		draw_line(base, top, ink, maxf(2.0, 0.045 * k) + 2.0, true)
		draw_line(base, top, wood, maxf(1.5, 0.045 * k), true)
	for j in 2:
		var bp := project(Vector3(p.x, p.y + (j - 0.5) * 0.114, h + 0.01))
		if broken_t >= 0.0:
			var tt := minf(bt, 1.0)
			bp += Vector2((j - 0.5) * 60.0 * tt, -140.0 * tt + 220.0 * tt * tt) * (k / 100.0)
		draw_line(bp + Vector2(-0.05 * k, 0), bp + Vector2(0.05 * k, 0), ink, maxf(2.0, 0.03 * k) + 2.0, true)
		draw_line(bp + Vector2(-0.05 * k, 0), bp + Vector2(0.05 * k, 0), wood, maxf(1.5, 0.03 * k), true)


## Screen position of the ball; right after release it eases out of the bowler's hand.
func _ball_screen(t: float, p: Vector3) -> Vector2:
	var sp := project(p)
	if t >= 0.0 and t < 0.1 and _hand_screen != Vector2.INF:
		var u := t / 0.1
		return _hand_screen.lerp(sp, u * u * (3.0 - 2.0 * u))
	return sp


func _ball() -> void:
	var bp := w.ball_world(w.clock)
	if bp == Vector3.INF or CAM.x - bp.x < 0.8:
		return
	var k := scale_at(bp)
	var r := maxf(5.0, BALL_R * k)
	var g := project(Vector3(bp.x, bp.y, 0))
	draw_set_transform(g, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, r * 1.1, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var s := _ball_screen(w.clock, bp)
	# Motion trail from the exact path a few milliseconds back (smooth at any frame rate).
	if not w.reduced_motion:
		var steps := 6
		for i in range(steps, 0, -1):
			var tp := w.clock - i * 0.012
			var pp := w.ball_world(tp)
			if pp == Vector3.INF or CAM.x - pp.x < 0.8:
				continue
			var a := 0.32 * (1.0 - float(i) / (steps + 1))
			draw_circle(_ball_screen(tp, pp), r * (1.0 - i * 0.08), Color(1.0, 0.95, 0.6, a), true, -1.0, true)
	# Bounce dust
	if w.delivery != null:
		var age := w.clock - w.delivery.t_bounce
		if age >= 0.0 and age < 0.4:
			var dp := project(w.delivery.pos_at(w.delivery.t_bounce))
			for i in 5:
				var a := -PI * (0.15 + 0.7 * i / 4.0)
				draw_circle(dp + Vector2(cos(a), sin(a) * 0.5) * (4.0 + 26.0 * age / 0.4), 4.0 * (1.0 - age / 0.4) + 1.0, Color(0.85, 0.72, 0.55, 0.6 * (1.0 - age / 0.4)))
	draw_circle(s, r + 2.0, Color(0.08, 0.06, 0.05), true, -1.0, true)
	draw_circle(s, r, Color(1.0, 0.95, 0.52), true, -1.0, true)
	draw_line(s + Vector2(-r * 0.95, -r * 0.2), s + Vector2(r * 0.95, r * 0.25), Color(0.85, 0.12, 0.12), r * 0.55, true)
	draw_circle(s + Vector2(-r * 0.35, -r * 0.4), r * 0.28, Color(1, 1, 1, 0.8), true, -1.0, true)
	if w.resolved != null and w.resolved.contact.is_contact():
		var age2 := w.clock - w.resolved.contact.t_contact
		if age2 >= 0.0 and age2 < 0.22:
			var cp := project(w.resolved.contact.contact_pos)
			var kk := age2 / 0.22
			var perfect := w.resolved.contact.category == ContactResult.PERFECT
			draw_circle(cp, (18.0 + 60.0 * kk) * (1.3 if perfect else 1.0), Color(1.0, 0.95, 0.7, 0.45 * (1.0 - kk)))
			draw_arc(cp, (24.0 + 90.0 * kk) * (1.3 if perfect else 1.0), 0, TAU, 32, Color(1.0, 0.85, 0.35, 1.0 - kk), 4.0, true)
		if age2 >= 0.0 and age2 < 0.15:
			for i in 8:
				var a2 := TAU * i / 8.0
				draw_line(s + Vector2(cos(a2), sin(a2)) * (r + 4.0 + 30.0 * age2 / 0.15), s + Vector2(cos(a2), sin(a2)) * (r + 12.0 + 40.0 * age2 / 0.15), Color(1.0, 0.95, 0.7, 1.0 - age2 / 0.15), 3.0, true)

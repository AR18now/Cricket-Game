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


func setup(world: WorldView) -> void:
	w = world
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
func _draw() -> void:
	var vs := get_viewport_rect().size
	W = vs.x
	H = vs.y
	F = H * 1.25
	_sky()
	_stands()
	_ground()
	_pitch()
	_actors()
	_ball()


func _sky() -> void:
	var atm := w.atm
	var bands := 20
	var horizon := H * 0.5 - F * tan(deg_to_rad(PITCH_DEG))
	for i in bands:
		var t0 := float(i) / bands
		draw_rect(Rect2(0, horizon * t0, W, horizon / bands + 1.0), atm.sky_top.lerp(atm.sky_bottom, t0))
	if atm.stars:
		var r := DetRng.new(9)
		for i in 60:
			draw_circle(Vector2(r.next_float() * W, r.next_float() * horizon * 0.8), 1.2, Color(1, 1, 1, 0.6))
	if atm.sun:
		var sp := Vector2(W * 0.8, horizon * (0.35 if atm.id == "day" else 0.85))
		for k in range(5, 0, -1):
			draw_circle(sp, 34.0 * k, Color(atm.sun_color.r, atm.sun_color.g, atm.sun_color.b, 0.04))
		draw_circle(sp, 28.0, atm.sun_color)
	elif atm.moon:
		draw_circle(Vector2(W * 0.8, horizon * 0.3), 20.0, Color(0.93, 0.93, 0.86))


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
		draw_colored_polygon(quad, col)
		draw_polyline(PackedVector2Array([quad[3], quad[2]]), _lit(col.darkened(0.3)), 3.0)
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
				draw_colored_polygon(win, wc)
		# Rooftop spectators
		var n := r.range_i(2, 6)
		for s in n:
			var u := r.range_f(0.1, 0.9)
			var p := a.lerp(b, u)
			var base := project(Vector3(p.x, p.y, h))
			var k := scale_at(Vector3(p.x, p.y, h))
			var shirt: Color = [GroundView.EMERALD, Color(0.95, 0.93, 0.88), GroundView.TERRACOTTA, Color(0.3, 0.45, 0.7), GroundView.GOLD.darkened(0.2)][r.range_i(0, 4)]
			draw_rect(Rect2(base + Vector2(-0.22 * k, -0.9 * k), Vector2(0.44 * k, 0.9 * k)), _lit(shirt))
			draw_circle(base + Vector2(0, -1.05 * k), 0.16 * k, _lit(Color(0.6, 0.42, 0.3)))
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
			draw_colored_polygon(q, _lit(GroundView.BRICK))
			draw_line(q[3], q[2], _lit(GroundView.PLASTER), 3.0)
	# Bunting across the far end
	var prev := Vector2.ZERO
	for i in 41:
		var u := i / 40.0
		var p := project(Vector3(-56.0, lerpf(-36.0, 36.0, u), 9.0 - sin(u * PI * 3.0) * 0.8))
		if i > 0:
			draw_line(prev, p, _lit(Color(0.2, 0.18, 0.16)), 1.5)
			var tri := PackedVector2Array([p + Vector2(-5, 0), p + Vector2(5, 0), p + Vector2(0, 11)])
			draw_colored_polygon(tri, _lit([GroundView.EMERALD, GroundView.GOLD, Color(0.97, 0.95, 0.9), GroundView.TERRACOTTA][i % 4]))
		prev = p
	if w.atm.floodlights:
		for t in [Vector2(-44.0, -34.0), Vector2(-50.0, 34.0)]:
			var b3 := project(Vector3(t.x, t.y, 0))
			var top := project(Vector3(t.x, t.y, 22))
			draw_line(b3, top, _lit(Color(0.3, 0.3, 0.34)), 6.0)
			draw_rect(Rect2(top + Vector2(-34, -26), Vector2(68, 30)), Color(0.2, 0.2, 0.24))
			for k2 in range(5, 0, -1):
				draw_circle(top + Vector2(0, -10), 26.0 * k2, Color(1.0, 0.97, 0.8, 0.06))
			draw_rect(Rect2(top + Vector2(-30, -22), Vector2(60, 22)), Color(1.0, 0.98, 0.9))


func _ellipse_pts(scale: float, n: int = 72) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var v := w.venue
	for i in n:
		var a := TAU * i / n
		pts.append(project(Vector3(v.boundary_center.x + cos(a) * v.boundary_rx * scale, v.boundary_center.y + sin(a) * v.boundary_ry * scale, 0.0)))
	return pts


func _ground() -> void:
	var horizon := H * 0.5 - F * tan(deg_to_rad(PITCH_DEG))
	draw_rect(Rect2(0, horizon - 2.0, W, H - horizon + 2.0), _lit(Color(0.72, 0.45, 0.32)))
	var v := w.venue
	draw_colored_polygon(_ellipse_pts(1.03), _lit(v.ground_edge_color))
	draw_colored_polygon(_ellipse_pts(1.0), _lit(v.ground_color.darkened(0.04)))
	draw_colored_polygon(_ellipse_pts(0.72), _lit(v.ground_color))
	draw_colored_polygon(_ellipse_pts(0.4), _lit(v.ground_color.lightened(0.04)))
	if w.atm.floodlights:
		draw_colored_polygon(_ellipse_pts(0.55), Color(1.0, 1.0, 0.9, 0.06))
	var rope := _ellipse_pts(1.0, 120)
	# Only draw the rope segments in front of the camera.
	for i in rope.size():
		var a := TAU * i / 120.0
		var wx := v.boundary_center.x + cos(a) * v.boundary_rx
		if CAM.x - wx > 1.5:
			var j := (i + 1) % rope.size()
			var a2 := TAU * j / 120.0
			if CAM.x - (v.boundary_center.x + cos(a2) * v.boundary_rx) > 1.5:
				draw_line(rope[i], rope[j], _lit(v.boundary_color), 3.0, true)
	for p in _tufts:
		if CAM.x - p.x < 2.0:
			continue
		var s := project(Vector3(p.x, p.y, 0))
		var k := scale_at(Vector3(p.x, p.y, 0))
		var gc := _lit(Color(0.42, 0.5, 0.22, 0.6))
		draw_line(s, s + Vector2(-0.06 * k, -0.12 * k), gc, maxf(1.0, 0.02 * k))
		draw_line(s, s + Vector2(0.05 * k, -0.14 * k), gc, maxf(1.0, 0.02 * k))


func _pitch() -> void:
	var hw := 1.52
	var q := PackedVector2Array([project(Vector3(-22.0, -hw, 0)), project(Vector3(-22.0, hw, 0)), project(Vector3(1.8, hw, 0)), project(Vector3(1.8, -hw, 0))])
	draw_colored_polygon(q, _lit(w.venue.pitch_color))
	for c in [Vector2(-1.3, 0.0), Vector2(-5.5, 0.1), Vector2(-18.9, 0.3)]:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(project(Vector3(c.x + cos(a) * 1.3, c.y + sin(a) * 0.8, 0)))
		draw_colored_polygon(pts, _lit(w.venue.pitch_color.darkened(0.1)))
	var white := _lit(Color(0.98, 0.97, 0.94))
	for end_x in [0.0, Delivery.BOWLING_STUMPS_X]:
		var sgn := 1.0 if end_x == 0.0 else -1.0
		var pop: float = end_x - 1.22 * sgn
		draw_line(project(Vector3(pop, -1.83, 0)), project(Vector3(pop, 1.83, 0)), white, maxf(1.5, 0.05 * scale_at(Vector3(pop, 0, 0))), true)
		draw_line(project(Vector3(end_x, -1.32, 0)), project(Vector3(end_x, 1.32, 0)), white, maxf(1.0, 0.035 * scale_at(Vector3(end_x, 0, 0))), true)
		for yy in [-1.32, 1.32]:
			draw_line(project(Vector3(end_x + 0.3 * sgn, yy, 0)), project(Vector3(pop - 1.0 * sgn, yy, 0)), white, 1.5, true)


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
		items.append([depth_of(ns), _figure.bind(ns, w.batting_kit, {"front": true, "t": t, "helmet": true, "bat": true, "pads": true})])
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
		var hip := base + Vector2(side * 0.11 * k, -hip_h * k)
		var foot := base + Vector2(side * (0.14 + crouch * 0.1) * k, -lift * k)
		var knee := hip.lerp(foot, 0.5) + Vector2(side * crouch * 0.12 * k, -lift * 0.3 * k)
		draw_line(hip, knee, ink, lw + 3.0, true)
		draw_line(knee, foot, ink, lw + 3.0, true)
		draw_line(hip, knee, trousers, lw, true)
		draw_line(knee, foot, trousers, lw, true)
		if o.get("pads", false):
			draw_line(knee, foot, _lit(Color(0.97, 0.96, 0.92)), lw * 1.2, true)
		draw_circle(foot, lw * 0.6, ink)
	# Torso
	var hipc := base + Vector2(0, -hip_h * k)
	var shc := base + Vector2(0, -sh_h * k)
	draw_line(hipc, shc, ink, 0.34 * k + 3.0, true)
	draw_line(hipc, shc, shirt, 0.34 * k, true)
	# Arms
	var arm_l: float = o.get("arm_l", 0.35 + crouch)
	var arm_r: float = o.get("arm_r", 0.35 + crouch)
	if run > 0.0:
		arm_l = 0.3 + 0.5 * sin(phase)
		arm_r = 0.3 - 0.5 * sin(phase)
	for side in [-1.0, 1.0]:
		var sh := shc + Vector2(side * 0.19 * k, 0.04 * k)
		var ang: float = arm_l if side < 0.0 else arm_r
		var hand := sh + Vector2(side * sin(ang) * 0.58 * k, cos(ang) * 0.58 * k)
		draw_line(sh, hand, ink, lw * 0.8 + 3.0, true)
		draw_line(sh, hand, shirt, lw * 0.8, true)
		draw_circle(hand, lw * 0.5, skin)
	if o.has("windmill"):
		var phi: float = o["windmill"]
		var sh2 := shc + Vector2(0.19 * k, 0.04 * k)
		var hand2 := sh2 + Vector2(0.08 * k * sin(phi), cos(phi) * 0.6 * k)
		draw_line(sh2, hand2, ink, lw * 0.8 + 3.0, true)
		draw_line(sh2, hand2, shirt, lw * 0.8, true)
		draw_circle(hand2, lw * 0.5, skin)
		if o.get("ball_in_hand", false):
			draw_circle(hand2, maxf(3.0, 0.07 * k), Color(1.0, 0.95, 0.5))
	if o.get("bat", false):
		var hb := shc + Vector2(0.15 * k, 0.45 * k)
		draw_line(hb, hb + Vector2(0.05 * k, 0.8 * k), ink, 0.12 * k + 2.0, true)
		draw_line(hb, hb + Vector2(0.05 * k, 0.8 * k), _lit(Color(0.93, 0.82, 0.58)), 0.12 * k, true)
	# Head
	var hc := shc + Vector2(0, -0.17 * k)
	draw_circle(hc, 0.13 * k + 1.5, ink)
	draw_circle(hc, 0.13 * k, skin)
	if o.get("helmet", false):
		draw_arc(hc, 0.14 * k, PI, TAU, 16, _lit(kit.darkened(0.2)), 0.1 * k, true)
	elif o.get("hat", false):
		draw_rect(Rect2(hc + Vector2(-0.2 * k, -0.12 * k), Vector2(0.4 * k, 0.05 * k)), _lit(Color(0.95, 0.93, 0.85)))
	elif o.get("cap", false):
		draw_arc(hc, 0.13 * k, PI, TAU, 16, _lit(kit.darkened(0.2)), 0.08 * k, true)
	else:
		draw_arc(hc, 0.12 * k, PI, TAU, 16, Color(0.1, 0.08, 0.07), 0.07 * k, true)
	if o.get("front", false) and k > 25.0:
		draw_circle(hc + Vector2(-0.045 * k, 0.0), maxf(1.0, 0.015 * k), ink)
		draw_circle(hc + Vector2(0.045 * k, 0.0), maxf(1.0, 0.015 * k), ink)


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
	elif t < 0.7:
		var u2 := t / 0.7
		o["windmill"] = lerpf(PI + 0.25, TAU - 0.3, 1.0 - (1.0 - u2) * (1.0 - u2))
		o["crouch"] = 0.3 * sin(u2 * PI)
	else:
		o["crouch"] = 0.35
	_figure(p, w.fielding_kit, o)


## The striker seen from behind: big, near the camera, left of the stumps.
func _batter(t: float) -> void:
	var p := Vector3(WorldView.STRIKER_BASE.x, WorldView.STRIKER_BASE.y, 0)
	var k := scale_at(p)
	var base := project(p)
	var ink := Color(0.1, 0.08, 0.07)
	var shirt := _lit(w.batting_kit)
	var trousers := _lit(Color(0.95, 0.94, 0.9))
	var pad := _lit(Color(0.97, 0.96, 0.92))
	var lw := 0.16 * k
	# Swing progress (same timing as the side view).
	var u := -1.0
	if w.swing_time >= 0.0 and t >= w.swing_time:
		u = clampf((t - w.swing_time) / WorldView.SWING_DUR, 0.0, 1.0)
	var lift := 0.0
	if t > -0.5:
		lift = Poses.ease_io((t + 0.5) / 0.4)
	var step := 0.0
	if u >= 0.0:
		step = Poses.ease_io(clampf(u / Poses.CONTACT_U, 0.0, 1.0)) * 0.25
	draw_set_transform(base, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 0.45 * k, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var hip := base + Vector2(0, -0.88 * k)
	var sh := base + Vector2(-step * 0.2 * k, -1.4 * k)
	for side in [-1.0, 1.0]:
		var foot := base + Vector2(side * 0.2 * k + (step * 0.3 * k if side < 0.0 else 0.0), -(step * 0.6 * k if side < 0.0 else 0.0))
		var h2 := hip + Vector2(side * 0.1 * k, 0)
		draw_line(h2, foot, ink, lw + 4.0, true)
		draw_line(h2, foot, trousers, lw, true)
		draw_line(h2.lerp(foot, 0.45), foot, pad, lw * 1.25, true)
		draw_circle(foot, lw * 0.55, ink)
	draw_line(hip, sh, ink, 0.4 * k + 4.0, true)
	draw_line(hip, sh, shirt, 0.4 * k, true)
	# Name + number on the back of the shirt.
	var name := w.striker_label.get_slice(" ", 0).to_upper()
	var f := UiTheme.font("black")
	var fs := int(0.1 * k)
	if fs >= 8:
		var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, hip.lerp(sh, 0.7) + Vector2(-tw * 0.5, 0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _lit(UiTheme.GOLD))
		var nw := f.get_string_size("7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs * 2).x
		draw_string(f, hip.lerp(sh, 0.32) + Vector2(-nw * 0.5, 0), "7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs * 2, _lit(UiTheme.GOLD))
	# Bat & hands: stance (down-right) -> backlift (up-right) -> contact (down, away) -> follow (up-left)
	var a_stance := deg_to_rad(165.0)
	var a_back := deg_to_rad(35.0)
	var a_contact := deg_to_rad(190.0)
	var a_follow := deg_to_rad(-50.0)
	var ang := lerp_angle(a_stance, a_back, lift)
	var hands := sh + Vector2(0.18 * k, 0.5 * k).lerp(Vector2(0.28 * k, 0.05 * k), lift)
	var fore := 1.0
	if u >= 0.0:
		if u <= Poses.CONTACT_U:
			var q := u / Poses.CONTACT_U
			ang = lerpf(a_back, a_contact, q * q)
			hands = sh + Vector2(0.28 * k, 0.05 * k).lerp(Vector2(0.05 * k, 0.55 * k), q)
			fore = lerpf(1.0, 0.45, q)
		else:
			var q2 := (u - Poses.CONTACT_U) / (1.0 - Poses.CONTACT_U)
			ang = lerp_angle(a_contact, a_follow, 1.0 - (1.0 - q2) * (1.0 - q2))
			hands = sh + Vector2(0.05 * k, 0.55 * k).lerp(Vector2(-0.3 * k, -0.05 * k), q2)
			fore = lerpf(0.45, 1.0, q2)
	var dir := Vector2(sin(ang), -cos(ang))
	var tip := hands + dir * 0.86 * k * fore
	var sh_bat := hands + dir * 0.27 * k * fore
	draw_line(sh, hands, ink, lw * 0.8 + 3.0, true)
	draw_line(sh, hands, shirt, lw * 0.8, true)
	draw_line(hands, sh_bat, ink, 0.05 * k + 3.0, true)
	draw_line(hands, sh_bat, _lit(Color(0.75, 0.15, 0.12)), 0.05 * k, true)
	draw_line(sh_bat, tip, ink, 0.13 * k + 4.0, true)
	draw_line(sh_bat, tip, _lit(Color(0.93, 0.82, 0.58)), 0.13 * k, true)
	draw_circle(hands, 0.08 * k, _lit(Color(0.96, 0.95, 0.9)))
	# Helmet from behind
	var hc := sh + Vector2(0, -0.2 * k)
	draw_circle(hc, 0.17 * k + 2.0, ink)
	draw_circle(hc, 0.17 * k, _lit(w.batting_kit.darkened(0.25)))
	draw_arc(hc, 0.12 * k, PI * 1.1, PI * 1.9, 12, _lit(w.batting_kit.lightened(0.2)), 0.03 * k, true)


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
	var s := project(bp)
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
		if age2 >= 0.0 and age2 < 0.15:
			for i in 8:
				var a2 := TAU * i / 8.0
				draw_line(s + Vector2(cos(a2), sin(a2)) * (r + 4.0 + 30.0 * age2 / 0.15), s + Vector2(cos(a2), sin(a2)) * (r + 12.0 + 40.0 * age2 / 0.15), Color(1.0, 0.95, 0.7, 1.0 - age2 / 0.15), 3.0, true)

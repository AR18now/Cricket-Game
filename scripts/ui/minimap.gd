class_name Minimap
extends Control
## Top-down field map: boundary, pitch, fielders, the ball and the current shot path.
## Makes field placements and "why was that safe / out" readable at a glance.

var world: WorldView
var shot_path: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(210, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _map(p: Vector2) -> Vector2:
	var v := world.venue
	var sx := (size.x - 16.0) / (v.boundary_rx * 2.0)
	var sy := (size.y - 16.0) / (v.boundary_ry * 2.0)
	var s := minf(sx, sy)
	var c := size * 0.5
	return c + (p - v.boundary_center) * s


func _draw() -> void:
	if world == null or world.venue == null:
		return
	var v := world.venue
	draw_style_box(UiTheme.panel_box(Color(0.02, 0.15, 0.12, 0.72), 12), Rect2(Vector2.ZERO, size))
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(_map(v.boundary_center + Vector2(cos(a) * v.boundary_rx, sin(a) * v.boundary_ry)))
	draw_colored_polygon(pts, Color(0.62, 0.5, 0.34, 0.9))
	pts.append(pts[0])
	draw_polyline(pts, UiTheme.OFF_WHITE, 2.0, true)
	draw_line(_map(Vector2(-20.12, 0)), _map(Vector2(0, 0)), Color(0.93, 0.85, 0.66), 4.0)
	# Shot path
	if shot_path.size() > 1:
		var sp := PackedVector2Array()
		for p in shot_path:
			sp.append(_map(p))
		draw_polyline(sp, UiTheme.GOLD, 2.5, true)
	# Fielders
	for i in world.specs.size():
		var fp: Vector2 = world.specs[i].pos
		if i < world.fielder_rigs.size():
			var r: CricketerRig = world.fielder_rigs[i]
			fp = Proj.to_world_ground(r.position)
		draw_circle(_map(fp), 5.0, UiTheme.INK)
		draw_circle(_map(fp), 3.8, Color(0.45, 0.65, 1.0))
	# Batter
	draw_circle(_map(Vector2(-1.0, -0.4)), 5.5, UiTheme.INK)
	draw_circle(_map(Vector2(-1.0, -0.4)), 4.2, UiTheme.GOLD)
	# Ball
	var b := world.ball_world(world.clock) if not world.menu_mode else Vector3.INF
	if b != Vector3.INF:
		draw_circle(_map(Vector2(b.x, b.y)), 4.5, UiTheme.INK)
		draw_circle(_map(Vector2(b.x, b.y)), 3.2, Color(1.0, 0.95, 0.5))

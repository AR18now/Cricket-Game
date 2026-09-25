class_name ShotMap
extends Control
## Wagon wheel generated from the recorded shot trajectories in the event log.

var events: Array = []
var venue: VenueConfig


func _draw() -> void:
	if venue == null:
		return
	draw_style_box(UiTheme.panel_box(Color(0, 0, 0, 0.25), 10), Rect2(Vector2.ZERO, size))
	var s := minf((size.x - 12.0) / (venue.boundary_rx * 2.0), (size.y - 12.0) / (venue.boundary_ry * 2.0))
	var c := size * 0.5
	var m := func(p: Vector2) -> Vector2: return c + (p - venue.boundary_center) * s
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(m.call(venue.boundary_center + Vector2(cos(a) * venue.boundary_rx, sin(a) * venue.boundary_ry)))
	draw_colored_polygon(pts, Color(0.62, 0.5, 0.34, 0.6))
	draw_polyline(pts, UiTheme.OFF_WHITE, 1.5, true)
	for e in events:
		var shot: Array = e.get("shot", [])
		if shot.size() < 2:
			continue
		var col := Color(1, 1, 1, 0.7)
		match String(e["kind"]):
			"six": col = UiTheme.GOLD
			"four": col = Color(0.5, 0.85, 1.0)
			"caught": col = UiTheme.DANGER
		var line := PackedVector2Array()
		for p in shot:
			line.append(m.call(Vector2(p[0], p[1])))
		draw_polyline(line, col, 2.0, true)
	draw_string(UiTheme.font("regular"), Vector2(8, size.y - 8), "Shot map", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.SAND)

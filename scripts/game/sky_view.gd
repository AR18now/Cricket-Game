class_name SkyView
extends Node2D
## Screen-space evening sky with slow parallax city silhouette, sun glow and a few kites.
## Lives on a CanvasLayer behind the world; `cam_offset` is fed from the camera.

var venue: VenueConfig
var cam_offset := Vector2.ZERO
var time := 0.0
var reduced_motion := false


func setup(v: VenueConfig) -> void:
	venue = v
	queue_redraw()


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	if venue == null:
		return
	var size := get_viewport_rect().size
	var top := venue.sky_top
	var bottom := venue.sky_bottom
	var bands := 24
	for i in bands:
		var t0 := float(i) / bands
		var c := top.lerp(bottom, pow(t0, 1.3))
		draw_rect(Rect2(0, size.y * t0, size.x, size.y / bands + 1.0), c)
	# Sun glow low on the horizon.
	var sun := Vector2(size.x * 0.78 - cam_offset.x * 0.02, size.y * 0.52 - cam_offset.y * 0.02)
	for r in range(6, 0, -1):
		draw_circle(sun, 40.0 * r, Color(1.0, 0.85, 0.55, 0.035))
	draw_circle(sun, 34.0, Color(1.0, 0.9, 0.7, 0.9))
	# Distant city silhouette (parallax 0.05)
	var ox := fposmod(-cam_offset.x * 0.05, 240.0)
	var base_y := size.y * 0.62 - cam_offset.y * 0.04
	var sil := Color(0.36, 0.25, 0.34, 0.75)
	var x := -240.0 + ox
	var k := 0
	while x < size.x + 240.0:
		var h := 40.0 + float((k * 37) % 70)
		var w := 60.0 + float((k * 53) % 50)
		draw_rect(Rect2(x, base_y - h, w, h + size.y), sil)
		if k % 5 == 2:
			draw_rect(Rect2(x + w * 0.4, base_y - h - 30.0, 6.0, 30.0), sil)
		x += w
		k += 1
	# Kites drifting (subtle life; static when reduced motion is on)
	var tt := 0.0 if reduced_motion else time
	for i in 3:
		var kp := Vector2(size.x * (0.2 + 0.28 * i) + sin(tt * 0.4 + i) * 20.0 - cam_offset.x * 0.08,
			size.y * (0.16 + 0.07 * i) + cos(tt * 0.6 + i * 2.0) * 8.0 - cam_offset.y * 0.05)
		var kc: Color = [Color(0.9, 0.3, 0.25), Color(0.1, 0.5, 0.38), Color(0.97, 0.8, 0.3)][i]
		var kite := PackedVector2Array([kp + Vector2(0, -12), kp + Vector2(9, 0), kp + Vector2(0, 14), kp + Vector2(-9, 0)])
		draw_colored_polygon(kite, kc)
		var tail := PackedVector2Array()
		for s in 6:
			tail.append(kp + Vector2(sin(tt * 2.0 + s) * 4.0, 14.0 + s * 7.0))
		draw_polyline(tail, Color(0.2, 0.15, 0.2, 0.6), 1.2, true)
		draw_line(kp + Vector2(0, 14), kp + Vector2(-60.0 - i * 30.0, 300.0), Color(1, 1, 1, 0.15), 1.0, true)

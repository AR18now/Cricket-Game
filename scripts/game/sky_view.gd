class_name SkyView
extends Node2D
## Screen-space sky: gradient, sun or moon + stars, clouds, slow parallax city silhouette
## and a few kites. Colours come from the current Atmosphere.

var venue: VenueConfig
var atm: Atmosphere = Atmosphere.make("evening")
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
	var size := get_viewport_rect().size
	var bands := 28
	for i in bands:
		var t0 := float(i) / bands
		draw_rect(Rect2(0, size.y * t0, size.x, size.y / bands + 1.0), atm.sky_top.lerp(atm.sky_bottom, pow(t0, 1.3)))
	var tt := 0.0 if reduced_motion else time
	if atm.stars:
		var r := DetRng.new(77)
		for i in 90:
			var p := Vector2(r.next_float() * size.x, r.next_float() * size.y * 0.6)
			var tw := 0.5 + 0.5 * sin(tt * (1.0 + r.next_float() * 2.0) + i)
			draw_circle(p, 1.0 + r.next_float() * 1.2, Color(1, 1, 1, 0.35 + 0.5 * tw))
	var body := Vector2(size.x * 0.78 - cam_offset.x * 0.02, size.y * atm.sun_height - cam_offset.y * 0.02)
	if atm.sun:
		for r2 in range(6, 0, -1):
			draw_circle(body, 40.0 * r2, Color(atm.sun_color.r, atm.sun_color.g, atm.sun_color.b, 0.035))
		draw_circle(body, 34.0, Color(atm.sun_color, 0.95))
	elif atm.moon:
		draw_circle(body, 60.0, Color(0.8, 0.85, 1.0, 0.06))
		draw_circle(body, 26.0, Color(0.93, 0.93, 0.86))
		draw_circle(body + Vector2(9, -6), 22.0, atm.sky_top.lerp(atm.sky_bottom, 0.2))
	if atm.clouds > 0.0:
		var cr := DetRng.new(5)
		var n := int(4 + atm.clouds * 8)
		for i in n:
			var cx := fposmod(cr.next_float() * size.x * 1.4 + tt * (6.0 + i) - cam_offset.x * 0.03, size.x * 1.4) - size.x * 0.2
			var cy := size.y * (0.08 + cr.next_float() * 0.35)
			var col := Color(1, 1, 1, 0.55) if atm.id == "day" else Color(0.45, 0.48, 0.55, 0.85)
			for k in 5:
				draw_circle(Vector2(cx + k * 38.0, cy + sin(k * 1.7) * 10.0), 34.0 + (k % 2) * 14.0, col)
	# Distant city silhouette (parallax 0.05)
	var ox := fposmod(-cam_offset.x * 0.05, 240.0)
	var base_y := size.y * 0.62 - cam_offset.y * 0.04
	var sil := atm.sky_bottom.darkened(0.45)
	sil.a = 0.8
	var x := -240.0 + ox
	var k2 := 0
	while x < size.x + 240.0:
		var h := 40.0 + float((k2 * 37) % 70)
		var w := 60.0 + float((k2 * 53) % 50)
		draw_rect(Rect2(x, base_y - h, w, h + size.y), sil)
		if atm.window_glow and k2 % 2 == 0:
			draw_rect(Rect2(x + w * 0.3, base_y - h * 0.6, 5.0, 6.0), Color(1.0, 0.85, 0.5, 0.7))
		x += w
		k2 += 1
	if atm.rain or atm.id == "night":
		return
	for i in 3:
		var kp := Vector2(size.x * (0.2 + 0.28 * i) + sin(tt * 0.4 + i) * 20.0 - cam_offset.x * 0.08,
			size.y * (0.16 + 0.07 * i) + cos(tt * 0.6 + i * 2.0) * 8.0 - cam_offset.y * 0.05)
		var kc: Color = [Color(0.9, 0.3, 0.25), Color(0.1, 0.5, 0.38), Color(0.97, 0.8, 0.3)][i]
		draw_colored_polygon(PackedVector2Array([kp + Vector2(0, -12), kp + Vector2(9, 0), kp + Vector2(0, 14), kp + Vector2(-9, 0)]), kc)
		var tail := PackedVector2Array()
		for s in 6:
			tail.append(kp + Vector2(sin(tt * 2.0 + s) * 4.0, 14.0 + s * 7.0))
		draw_polyline(tail, Color(0.2, 0.15, 0.2, 0.6), 1.2, true)

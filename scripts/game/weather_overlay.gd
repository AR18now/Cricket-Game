class_name WeatherOverlay
extends Node2D
## Screen-space rain streaks + light haze. Deterministic, cheap, fewer streaks in reduced motion.

var atm: Atmosphere
var time := 0.0
var reduced_motion := false


func _process(delta: float) -> void:
	time += delta
	visible = atm != null and atm.rain
	if visible:
		queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.65, 0.72, 0.12))
	var n := 70 if reduced_motion else 170
	var speed := 380.0 if reduced_motion else 900.0
	for i in n:
		var r := DetRng.new(i * 7 + 3)
		var x0 := r.next_float() * (size.x + 200.0)
		var y0 := r.next_float() * size.y
		var y := fposmod(y0 + time * speed * (0.8 + r.next_float() * 0.4), size.y + 60.0) - 30.0
		var x := fposmod(x0 - (y / size.y) * 120.0, size.x + 200.0) - 100.0
		var len := 14.0 + r.next_float() * 14.0
		draw_line(Vector2(x, y), Vector2(x - len * 0.25, y + len), Color(0.85, 0.9, 1.0, 0.35), 1.4, true)

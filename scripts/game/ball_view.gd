class_name BallView
extends Node2D
## Tape ball: vivid, outlined, constant on-screen size regardless of zoom, with a ground
## shadow, a height stalk when lofted, and a short fading trail.

var world_pos := Vector3.ZERO
var zoom := 1.0
var visible_ball := true
var trail: Array = []
var trail_enabled := true
var shadow_node: Node2D


func set_ball(p: Vector3, z: float) -> void:
	world_pos = p
	zoom = z
	position = Proj.to_screen(p)
	if trail_enabled:
		trail.append(position)
		if trail.size() > 9:
			trail.pop_front()
	queue_redraw()
	if shadow_node:
		shadow_node.position = Proj.ground(p.x, p.y)
		shadow_node.set_meta("h", p.z)
		shadow_node.set_meta("z", zoom)
		shadow_node.visible = visible_ball
		shadow_node.queue_redraw()


func clear_trail() -> void:
	trail.clear()


func _draw() -> void:
	if not visible_ball:
		return
	var s := 1.0 / maxf(zoom, 0.05)
	var r := 5.5 * s
	# Trail
	for i in trail.size():
		var a := float(i + 1) / float(trail.size() + 1)
		draw_circle(trail[i] - position, r * 0.6 * a, Color(1.0, 0.95, 0.6, 0.18 * a), true, -1.0, true)
	if world_pos.z > 2.5:
		draw_circle(Vector2.ZERO, r * 2.1, Color(1.0, 0.95, 0.55, 0.25), false, 1.5 * s, true)
	draw_circle(Vector2.ZERO, r + 1.6 * s, Color(0.08, 0.06, 0.05), true, -1.0, true)
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.95, 0.52), true, -1.0, true)
	# Red electrical-tape band.
	draw_line(Vector2(-r * 0.95, -r * 0.2), Vector2(r * 0.95, r * 0.25), Color(0.85, 0.12, 0.12), r * 0.55, true)
	draw_circle(Vector2(-r * 0.35, -r * 0.4), r * 0.28, Color(1, 1, 1, 0.8), true, -1.0, true)

class_name Floodlights
extends Node2D
## Four floodlight towers around the ground with additive glow and soft pools of light.
## Drawn in world space so they move correctly with the camera.

const TOWERS := [Vector2(-44.0, -34.0), Vector2(26.0, -34.0), Vector2(-50.0, 34.0), Vector2(30.0, 34.0)]
var on := false
var glow: Node2D


func _ready() -> void:
	glow = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	glow.z_index = 30
	add_child(glow)
	glow.draw.connect(_draw_glow)


func set_on(v: bool) -> void:
	on = v
	visible = v
	queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	if not on:
		return
	for t in TOWERS:
		if t.y > 0:
			continue   # near towers are off-screen behind the camera side; far ones visible
		var base := Proj.to_screen(Vector3(t.x, t.y, 0.0))
		var top := Proj.to_screen(Vector3(t.x, t.y, 22.0))
		draw_line(base, top, Color(0.25, 0.26, 0.3), 10.0)
		for k in 5:
			var y := base.y + (top.y - base.y) * k / 5.0
			draw_line(Vector2(base.x - 8, y), Vector2(base.x + 8, y - 30), Color(0.3, 0.3, 0.34), 3.0)
		draw_rect(Rect2(top + Vector2(-60, -50), Vector2(120, 56)), Color(0.18, 0.18, 0.22))
		for i in 4:
			for j in 2:
				draw_rect(Rect2(top + Vector2(-54 + i * 28, -44 + j * 24), Vector2(22, 18)), Color(1.0, 0.98, 0.9))


func _draw_glow() -> void:
	if not on:
		return
	# Light pool on the field + halos on the lamp heads.
	var c := Proj.ground(-9.0, 0.0)
	glow.draw_set_transform(c, 0.0, Vector2(1.0, 0.32))
	for r in range(6, 0, -1):
		glow.draw_circle(Vector2.ZERO, 420.0 * r, Color(0.16, 0.16, 0.12, 0.05))
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for t in TOWERS:
		if t.y > 0:
			continue
		var top := Proj.to_screen(Vector3(t.x, t.y, 22.0)) + Vector2(0, -22)
		for r2 in range(5, 0, -1):
			glow.draw_circle(top, 50.0 * r2, Color(0.35, 0.33, 0.25, 0.07))
		glow.draw_circle(top, 40.0, Color(0.9, 0.88, 0.7, 0.5))

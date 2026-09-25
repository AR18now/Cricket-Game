class_name WorldEffects
extends Node2D
## Restrained, time-driven effects: bounce dust, contact spark, rope flash.

var items: Array = []   # {kind, pos: Vector3, t: float}
var clock := 0.0
var reduced_motion := false


func clear() -> void:
	items.clear()
	queue_redraw()


func render(w: WorldView, t: float) -> void:
	clock = t
	reduced_motion = w.reduced_motion
	items.clear()
	if w.delivery != null:
		items.append({"kind": "dust", "pos": w.delivery.pos_at(w.delivery.t_bounce), "t": w.delivery.t_bounce})
	if w.resolved != null and w.resolved.contact.is_contact():
		var c := w.resolved.contact
		items.append({"kind": "spark", "pos": c.contact_pos, "t": c.t_contact})
		var s := w.resolved.shot
		if s.first_bounce_t < INF and (not s.is_boundary() or s.first_bounce_t < s.boundary_t):
			items.append({"kind": "dust", "pos": s.ball_pos_at(s.first_bounce_t), "t": c.t_contact + s.first_bounce_t})
		if s.is_boundary():
			items.append({"kind": "rope", "pos": s.samples[s.samples.size() - 1], "t": c.t_contact + s.boundary_t})
	queue_redraw()


func _draw() -> void:
	for it in items:
		var age: float = clock - float(it["t"])
		var p: Vector3 = it["pos"]
		match it["kind"]:
			"dust":
				if age >= 0.0 and age < 0.45:
					var g := Proj.ground(p.x, p.y)
					var k := age / 0.45
					for i in 5:
						var a := -PI * (0.15 + 0.7 * i / 4.0)
						var off := Vector2(cos(a), sin(a) * 0.5) * (6.0 + 22.0 * k)
						draw_circle(g + off, 5.0 * (1.0 - k) + 1.0, Color(0.85, 0.72, 0.55, 0.55 * (1.0 - k)))
			"spark":
				if age >= 0.0 and age < 0.18 and not reduced_motion:
					var sp := Proj.to_screen(p)
					var k2 := age / 0.18
					for i in 8:
						var a2 := TAU * i / 8.0
						draw_line(sp + Vector2(cos(a2), sin(a2)) * (6.0 + 10.0 * k2), sp + Vector2(cos(a2), sin(a2)) * (12.0 + 18.0 * k2), Color(1.0, 0.95, 0.7, 1.0 - k2), 3.0, true)
			"rope":
				if age >= 0.0 and age < 1.2:
					var gp := Proj.ground(p.x, p.y)
					var k3 := age / 1.2
					draw_arc(gp, 30.0 + 60.0 * k3, 0.0, TAU, 32, Color(1.0, 0.85, 0.35, 0.8 * (1.0 - k3)), 5.0, true)

class_name Confetti
extends Control
## Lightweight screen-space confetti (boundaries, milestones, new best). Pure drawing, no
## input; disabled in reduced-motion mode.

const COLORS := [Color(0.04, 0.55, 0.32), Color(0.99, 0.79, 0.33), Color(0.98, 0.97, 0.93),
	Color(0.82, 0.41, 0.27), Color(0.95, 0.35, 0.62), Color(0.2, 0.45, 0.9)]

var reduced_motion := false
var _p: Array = []   # {pos, vel, rot, spin, col, size, life}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func burst(at: Vector2, count: int = 70, power: float = 1.0) -> void:
	if reduced_motion:
		return
	for i in count:
		var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		var sp := _rng.randf_range(280.0, 720.0) * power
		_p.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * sp, "rot": _rng.randf() * TAU,
			"spin": _rng.randf_range(-9.0, 9.0), "col": COLORS[_rng.randi() % COLORS.size()],
			"size": _rng.randf_range(6.0, 12.0), "life": _rng.randf_range(1.3, 2.0)})


func clear() -> void:
	_p.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _p.is_empty():
		return
	for q in _p:
		q["vel"] = q["vel"] * (1.0 - 1.6 * delta) + Vector2(0, 900.0 * delta)
		q["pos"] += q["vel"] * delta
		q["rot"] += q["spin"] * delta
		q["life"] -= delta
	_p = _p.filter(func(q): return q["life"] > 0.0 and q["pos"].y < size.y + 40.0)
	queue_redraw()


func _draw() -> void:
	for q in _p:
		var c: Color = q["col"]
		c.a = clampf(q["life"] / 0.5, 0.0, 1.0)
		var s: float = q["size"]
		draw_set_transform(q["pos"], q["rot"], Vector2(1.0, 0.55 + 0.45 * absf(sin(q["rot"] * 1.7))))
		draw_rect(Rect2(-s * 0.5, -s * 0.3, s, s * 0.6), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

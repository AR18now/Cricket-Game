class_name SwingPad
extends Control
## Large, thumb-friendly swing affordance. The whole play area accepts taps; this pad
## teaches the action and pulses when a swing is accepted.

var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func pulse() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	draw_circle(c, r + 6.0 * _pulse, Color(0.02, 0.15, 0.12, 0.6))
	draw_arc(c, r, 0, TAU, 48, UiTheme.GOLD, 4.0, true)
	draw_arc(c, r * 0.72 + 10.0 * _pulse, 0, TAU, 48, Color(1, 1, 1, 0.5 + 0.5 * _pulse), 2.0, true)
	var f := UiTheme.font("black")
	draw_string(f, c + Vector2(-50, 4), "SWING", HORIZONTAL_ALIGNMENT_CENTER, 100, 26, UiTheme.OFF_WHITE)
	draw_string(UiTheme.font("regular"), c + Vector2(-50, 28), "tap / Space", HORIZONTAL_ALIGNMENT_CENTER, 100, 15, UiTheme.SAND)

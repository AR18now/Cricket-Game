class_name SwingGate
extends RefCounted
## Accepts at most one swing per delivery and only inside the batting window.
## Rapid repeated taps, taps before release and taps after the window are ignored.

var open_time := 0.0
var close_time := 0.0
var swing_time := -1.0
var armed := false
var ignored := 0


func arm(open_t: float, close_t: float) -> void:
	open_time = open_t
	close_time = close_t
	swing_time = -1.0
	armed = true
	ignored = 0


func disarm() -> void:
	armed = false


## Returns "accepted", "too_soon", "already" or "closed".
func try_swing(t: float) -> String:
	if not armed:
		ignored += 1
		return "closed"
	if swing_time >= 0.0:
		ignored += 1
		return "already"
	if t < open_time:
		ignored += 1
		return "too_soon"
	if t > close_time:
		ignored += 1
		return "closed"
	swing_time = t
	return "accepted"

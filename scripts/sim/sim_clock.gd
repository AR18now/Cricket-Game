class_name SimClock
extends RefCounted
## Delivery clock advanced by real frame deltas while not paused. Input timestamps are
## taken at event time (sub-frame) and mapped onto this clock, so contact timing does
## not depend on the render frame rate.

var time := 0.0
var paused := false
var _stamp_usec := 0


func reset(t: float, now_usec: int) -> void:
	time = t
	_stamp_usec = now_usec


func advance(delta: float, now_usec: int) -> void:
	if not paused:
		time += delta
	_stamp_usec = now_usec


## Sim time of an input that arrived at now_usec (after the last advance()).
## `scale` is the engine time scale (slow motion), so input stays consistent with delta.
func time_of_input(now_usec: int, scale: float = 1.0) -> float:
	if paused:
		return time
	return time + float(now_usec - _stamp_usec) / 1000000.0 * scale


func set_paused(p: bool, now_usec: int) -> void:
	paused = p
	_stamp_usec = now_usec

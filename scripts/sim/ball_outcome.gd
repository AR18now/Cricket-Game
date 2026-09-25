class_name BallOutcome
extends RefCounted
## The single authoritative result of one legal delivery.

const DOT := "dot"
const RUNS := "runs"
const FOUR := "four"
const SIX := "six"
const BOWLED := "bowled"
const CAUGHT := "caught"

var kind := DOT
var runs := 0
var wicket := false
var fielder_name := ""
var fielder_position := ""
var timing := ContactResult.NONE
var dt_ms := 0.0
var angle_deg := 0.0
var distance := 0.0
var max_height := 0.0
var t_settle := 0.0           # sim seconds after release when the result is final
var explanation := ""
var delivery_kind := "stock"
var speed_kmh := 0
var shot_points: Array = []   # sparse plan-view points for the shot map (Vector2)


func is_boundary() -> bool:
	return kind == FOUR or kind == SIX


func to_event() -> Dictionary:
	var pts: Array = []
	for p in shot_points:
		pts.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	return {
		"kind": kind, "runs": runs, "wicket": wicket, "fielder": fielder_name,
		"fielder_position": fielder_position, "timing": timing, "dt_ms": snappedf(dt_ms, 0.1),
		"angle": snappedf(angle_deg, 0.1), "distance": snappedf(distance, 0.1),
		"delivery": delivery_kind, "kmh": speed_kmh, "why": explanation, "shot": pts,
	}

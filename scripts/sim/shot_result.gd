class_name ShotResult
extends RefCounted
## Complete, pre-resolved timeline of a struck ball. Rendering and replay only read it.

const RUNS := "runs"
const FOUR := "four"
const SIX := "six"
const CAUGHT := "caught"

var outcome := RUNS
var runs := 0
var dt := 1.0 / 120.0
var samples := PackedVector3Array()   # ball position per fixed step from contact
var first_bounce_t := INF
var boundary_t := INF
var collector := -1                   # fielder index that caught / stopped the ball
var t_collect := INF
var collect_pos := Vector3.ZERO
var t_back := INF                     # ball returned to the stumps
var throw_to := Vector2.ZERO
var t_settle := 0.0                   # when the outcome is final on screen
var run_times: Array = []             # completion time of each run
var fielder_targets: Array = []       # per fielder: {"target": Vector2, "t_start": float, "arrive": float}
var max_height := 0.0
var carry := 0.0                      # plan distance of first landing (or boundary crossing)
var distance := 0.0                   # plan distance where the ball ended / was collected


func ball_pos_at(t: float) -> Vector3:
	if samples.is_empty():
		return Vector3.ZERO
	var tc := t
	if outcome == CAUGHT or outcome == RUNS:
		tc = minf(t, t_collect)
	var f := tc / dt
	var i := int(floor(f))
	if i >= samples.size() - 1:
		return samples[samples.size() - 1]
	if i < 0:
		return samples[0]
	return samples[i].lerp(samples[i + 1], f - float(i))


func is_boundary() -> bool:
	return outcome == FOUR or outcome == SIX

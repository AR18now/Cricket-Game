class_name ContactResult
extends RefCounted
## Result of comparing the swing time against the delivery's analytic path.

enum Stance { AUTO, GROUNDED, LOFTED }

const NONE := "none"          # no swing
const MISS_EARLY := "miss_early"
const MISS_LATE := "miss_late"
const PERFECT := "perfect"
const GOOD := "good"
const EARLY := "early"
const LATE := "late"
const EDGE := "edge"

var swung := false
var category := NONE
var dt_ms := 0.0           # bat arrival minus ideal contact (negative = early)
var t_swing := -1.0
var t_contact := -1.0
var contact_pos := Vector3.ZERO
var launch_vel := Vector3.ZERO
var angle_deg := 0.0       # 0 = straight back past bowler, + = off side, - = leg side
var elevation_deg := 0.0
var exit_speed := 0.0
var stance := Stance.AUTO


func is_contact() -> bool:
	return category in [PERFECT, GOOD, EARLY, LATE, EDGE]


func timing_label() -> String:
	match category:
		PERFECT: return "PERFECT"
		GOOD: return "GOOD" if dt_ms <= 0.0 else "GOOD"
		EARLY: return "EARLY"
		LATE: return "LATE"
		EDGE: return "EDGE"
		MISS_EARLY: return "TOO EARLY"
		MISS_LATE: return "TOO LATE"
	return "NO SHOT"

class_name MatchState
extends RefCounted
## Owns the event log for one innings. Each delivery id can be recorded only once,
## so a resumed/replayed delivery can never be counted twice.

var rules: MatchRules
var seed := 0
var events: Array = []
var bowler_names := {}
var card: Scorecard
var _recorded_ids := {}


func _init(r: MatchRules = null, seed_value: int = 1) -> void:
	rules = r if r != null else MatchRules.new()
	seed = seed_value
	card = Scorecard.build(rules, events, bowler_names)


func next_ball_index() -> int:
	return events.size()


func current_bowler_id() -> String:
	var over_idx := events.size() / 6
	var list := rules.bowlers_by_over
	if over_idx < list.size():
		return list[over_idx]
	var start := clampi(rules.bowler_cycle_start, 0, list.size() - 1)
	return list[start + (over_idx - list.size()) % (list.size() - start)]


## Difficulty follows the score (Classic):
##   0-49 runs   : very easy - slow balls just outside off stump (a miss is not bowled),
##                 mistimed shots stay on the ground, wide timing windows. Level 1.
##   50-99 runs  : the help fades out and the bowlers build up to their real pace.
##                 Levels 2-4.
##   100+ runs   : extra pace, swing/spin and variation, harder every 25 runs. Levels 5-8.
const EASY_RUNS := 50
const MID_RUNS := 100
const HARD_SPAN := 150      # runs after 100 to reach full difficulty
const MAX_LEVEL := 8
const EASY_WINDOW := 2.2    # timing-window multiplier while fully assisted


func _runs() -> int:
	return card.runs


func level() -> int:
	if not rules.progressive:
		return 1
	var r := _runs()
	if r < EASY_RUNS:
		return 1
	if r < MID_RUNS:
		return 2 + (r - EASY_RUNS) * 3 / (MID_RUNS - EASY_RUNS)
	return mini(5 + (r - MID_RUNS) / 25, MAX_LEVEL)


## 0..1 progress through 50-99 runs (0 below 50, 1 from 100).
func mid_progress() -> float:
	return clampf(float(_runs() - EASY_RUNS) / float(MID_RUNS - EASY_RUNS), 0.0, 1.0)


## 1 = full beginner help (0-49 runs), fading to 0 by 100 runs.
func assist() -> float:
	if not rules.progressive:
		return 0.0
	var u := mid_progress()
	return 1.0 - u * u * (3.0 - 2.0 * u)


## Extra pace / movement on top of the bowler's real pace (100+ runs).
func difficulty() -> float:
	if rules.progressive:
		return clampf(float(_runs() - MID_RUNS) / HARD_SPAN, 0.0, 1.0)
	return clampf(events.size() * rules.difficulty_ramp, 0.0, 1.0)


## Timing-window multiplier for the next ball.
func window_scale() -> float:
	return rules.window_scale * lerpf(1.0, EASY_WINDOW, assist())


## 0 = gentle (slow, straight) balls, 1 = the bowler's real pace.
func ease_in() -> float:
	if not rules.progressive:
		return 1.0
	var u := mid_progress()
	return u * u * (3.0 - 2.0 * u)


## Records a settled outcome. Returns false (and changes nothing) for duplicates or
## after the innings is complete.
func record(delivery_id: int, outcome: BallOutcome, bowler_id: String) -> bool:
	if _recorded_ids.has(delivery_id) or card.complete:
		return false
	_recorded_ids[delivery_id] = true
	var e := outcome.to_event()
	e["id"] = delivery_id
	e["bowler"] = bowler_id
	e["striker"] = card.batters[card.striker]["name"]
	events.append(e)
	card = Scorecard.build(rules, events, bowler_names)
	return true


func is_complete() -> bool:
	return card.complete

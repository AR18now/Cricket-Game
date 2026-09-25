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
	return rules.bowlers_by_over[over_idx % rules.bowlers_by_over.size()]


func difficulty() -> float:
	return clampf(events.size() * rules.difficulty_ramp, 0.0, 1.0)


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

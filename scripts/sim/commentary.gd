class_name Commentary
extends RefCounted
## Event-driven banter/commentary selection. Lines are only eligible when their
## condition matches the authoritative outcome and match context, so a six line can
## never play on a four and a last-ball line always matches the real requirement.
## Mirrors VOICE_SCRIPT.csv (clip paths are attached there once recorded/reviewed).

const LINES := [
	# id, event, condition, text
	["intro_1", "first_ball", "", "Ready? Eyes on the ball!"],
	["six_1", "six", "", "What a shot! That's six!"],
	["six_2", "six", "", "That clears the rope!"],
	["six_3", "six", "", "That's gone onto the rooftops!"],
	["four_1", "four", "", "Four! Beautifully timed!"],
	["four_2", "four", "", "Races away to the rope!"],
	["four_3", "four", "", "Nobody's stopping that one!"],
	["perfect_runs", "runs", "timing=perfect", "Sweetly struck!"],
	["runs_1", "runs", "runs>=2", "Run hard, they'll get two!"],
	["runs_2", "runs", "runs==1", "Push for one, keep it moving."],
	["runs_3", "runs", "runs==3", "Three! Great running!"],
	["dot_early", "dot", "timing=miss_early", "A little early that time."],
	["dot_late", "dot", "timing=miss_late", "Just a touch late."],
	["dot_none", "dot", "timing=none", "Left that one alone."],
	["dot_field", "dot", "", "Well fielded, no run."],
	["bowled_1", "bowled", "", "Oh no, the stumps are down!"],
	["bowled_2", "bowled", "", "Bowled! Focus on the next one."],
	["caught_1", "caught", "", "Taken! What a catch."],
	["caught_2", "caught", "", "Up in the air and held."],
	["edge_1", "edge", "", "That's taken the edge!"],
	["last_ball_4", "last_ball", "needed==4", "Four needed off the last ball!"],
	["last_ball_6", "last_ball", "needed==6", "Six needed off the last ball!"],
	["last_ball_1", "last_ball", "needed==1", "Just one needed off the last ball!"],
	["last_ball_n", "last_ball", "needed>=2", "Last ball - everything on it!"],
	["win_1", "won", "", "Victory! Hero of the neighbourhood!"],
	["lost_1", "lost", "", "Never mind - one more match!"],
	["tied_1", "tied", "", "All square! What a contest!"],
]

var cooldown_balls := 1
var _last_id := ""
var _last_event_ball := {}
var _rng: DetRng


func _init(seed_value: int = 7) -> void:
	_rng = DetRng.new(seed_value)


## Returns {"id", "text"} or {} when nothing is eligible / on cooldown.
func pick(event: String, ctx: Dictionary, ball_index: int = 0) -> Dictionary:
	if _last_event_ball.has(event) and ball_index - int(_last_event_ball[event]) < cooldown_balls \
			and event not in ["six", "four", "bowled", "caught", "won", "lost", "tied", "last_ball", "first_ball"]:
		return {}
	var eligible: Array = []
	for l in LINES:
		if l[1] == event and Commentary.condition_ok(String(l[2]), ctx):
			eligible.append(l)
	if eligible.is_empty():
		return {}
	# Most specific wins: exact-match conditions beat ranges, which beat generic lines.
	var best := 0
	for l in eligible:
		best = maxi(best, Commentary.specificity(String(l[2])))
	eligible = eligible.filter(func(l): return Commentary.specificity(String(l[2])) == best)
	var choices: Array = eligible.filter(func(l): return l[0] != _last_id)
	if choices.is_empty():
		choices = eligible
	var line: Array = choices[_rng.range_i(0, choices.size() - 1)]
	_last_id = line[0]
	_last_event_ball[event] = ball_index
	# The spoken clip is vo_<id>; the text doubles as its caption.
	return {"id": line[0], "text": line[3], "event": event}


static func specificity(cond: String) -> int:
	if cond.is_empty():
		return 0
	if cond.contains("==") or (cond.contains("=") and not cond.contains(">=") and not cond.contains("<=")):
		return 2
	return 1


static func condition_ok(cond: String, ctx: Dictionary) -> bool:
	if cond.is_empty():
		return true
	for op in [">=", "<=", "==", "="]:
		var idx := cond.find(op)
		if idx > 0:
			var key := cond.substr(0, idx)
			var rhs := cond.substr(idx + op.length())
			if not ctx.has(key):
				return false
			var lhs = ctx[key]
			if op == "=":
				return str(lhs) == rhs
			var a := float(lhs)
			var b := float(rhs)
			match op:
				">=": return a >= b
				"<=": return a <= b
				"==": return is_equal_approx(a, b)
	return false


## Maps an outcome to the commentary event it may trigger.
static func event_for(o: BallOutcome) -> String:
	match o.kind:
		BallOutcome.SIX: return "six"
		BallOutcome.FOUR: return "four"
		BallOutcome.BOWLED: return "bowled"
		BallOutcome.CAUGHT: return "caught"
		BallOutcome.RUNS: return "edge" if o.timing == ContactResult.EDGE else "runs"
	return "dot"

class_name Commentary
extends RefCounted
## Event-driven banter/commentary selection. Lines are only eligible when their
## condition matches the authoritative outcome and match context, so a six line can
## never play on a four and a last-ball line always matches the real requirement.
## Mirrors VOICE_SCRIPT.csv (clip paths are attached there once recorded/reviewed).

const LINES := [
	# id, event, condition, text - short calls only: what happened, nothing else.
	["six", "six", "", "Six!"],
	["four", "four", "", "Four!"],
	["run_1", "runs", "runs==1", "One run"],
	["run_2", "runs", "runs==2", "Two runs"],
	["run_3", "runs", "runs==3", "Three runs"],
	["dot", "dot", "", "Dot ball"],
	["bowled", "bowled", "", "Bowled! Out!"],
	["caught", "caught", "", "Caught out!"],
	["duck", "duck", "", "Out for a duck!"],
	["golden_duck", "golden_duck", "", "Golden duck!"],
	["fifty", "fifty", "", "Fifty!"],
	["hundred", "hundred", "", "Hundred!"],
	["milestone", "milestone", "", "Another fifty!"],
	["won", "won", "", "Match won!"],
	["lost", "lost", "", "Match lost"],
	["tied", "tied", "", "Match tied"],
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
		BallOutcome.RUNS: return "runs"
	return "dot"

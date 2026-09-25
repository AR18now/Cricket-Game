class_name Commentary
extends RefCounted
## Event-driven banter/commentary selection. Lines are only eligible when their
## condition matches the authoritative outcome and match context, so a six line can
## never play on a four and a last-ball line always matches the real requirement.
## Mirrors VOICE_SCRIPT.csv (clip paths are attached there once recorded/reviewed).

const LINES := [
	# id, event, condition, roman_urdu, english
	["intro_1", "first_ball", "", "Tayyar? Ball pe nazar!", "Ready? Eyes on the ball!"],
	["six_1", "six", "", "Kya shot hai! Seedha chhakka!", "What a shot! That's six!"],
	["six_2", "six", "", "Seedha boundary ke paar!", "That clears the rope!"],
	["six_3", "six", "", "Chhat pe gayi ball!", "That's gone onto the rooftops!"],
	["four_1", "four", "", "Chauka! Zabardast timing!", "Four! Beautifully timed!"],
	["four_2", "four", "", "Ball rassi tak daud gayi!", "Races away to the rope!"],
	["four_3", "four", "", "Koi nahi rok sakta isse!", "Nobody's stopping that one!"],
	["perfect_runs", "runs", "timing=perfect", "Kya timing hai!", "Sweetly struck!"],
	["runs_1", "runs", "runs>=2", "Bhaago, bhaago! Do run!", "Run hard, they'll get two!"],
	["runs_2", "runs", "runs==1", "Ek run, strike ghumao.", "Push for one, keep it moving."],
	["runs_3", "runs", "runs==3", "Teen run! Kya daud hai!", "Three! Great running!"],
	["dot_early", "dot", "timing=miss_early", "Is dafa thora jaldi.", "A little early that time."],
	["dot_late", "dot", "timing=miss_late", "Thora der ho gayi.", "Just a touch late."],
	["dot_none", "dot", "timing=none", "Ball ko jaane diya.", "Left that one alone."],
	["dot_field", "dot", "", "Achhi fielding, koi run nahi.", "Well fielded, no run."],
	["bowled_1", "bowled", "", "Arre! Stumps ur gaye!", "Oh no, the stumps are down!"],
	["bowled_2", "bowled", "", "Bowled! Agli ball pe dhyan.", "Bowled! Focus on the next one."],
	["caught_1", "caught", "", "Pakar liya! Kya catch hai.", "Taken! What a catch."],
	["caught_2", "caught", "", "Hawa mein thi, pakri gayi.", "Up in the air and held."],
	["edge_1", "edge", "", "Bat ka kinara laga!", "That's taken the edge!"],
	["last_ball_4", "last_ball", "needed==4", "Aakhri ball, chaar runs chahiye!", "Four needed off the last ball!"],
	["last_ball_6", "last_ball", "needed==6", "Aakhri ball, chhakka chahiye!", "Six needed off the last ball!"],
	["last_ball_1", "last_ball", "needed==1", "Aakhri ball, bas ek run!", "Just one needed off the last ball!"],
	["last_ball_n", "last_ball", "needed>=2", "Aakhri ball! Sab kuch is pe hai.", "Last ball - everything on it!"],
	["win_1", "won", "", "Jeet gaye! Mohallay ka hero!", "Victory! Hero of the neighbourhood!"],
	["lost_1", "lost", "", "Koi baat nahi, ek aur match!", "Never mind - one more match!"],
	["tied_1", "tied", "", "Barabar! Kya muqabla tha!", "All square! What a contest!"],
]

var language := "roman_urdu"  # roman_urdu | english
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
	return {"id": line[0], "text": line[3] if language == "roman_urdu" else line[4], "event": event}


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

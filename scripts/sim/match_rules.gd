class_name MatchRules
extends RefCounted
## Format of one innings. All modes share the same scoring engine.

const PRACTICE := "practice"
const QUICK := "quick"
const ENDLESS := "endless"
const TUTORIAL := "tutorial"
const CHALLENGE := "challenge"
const CLASSIC := "classic"

var mode := QUICK
var overs := 2               # 0 = unlimited
var max_wickets := 3         # 0 = dismissals do not end the innings (practice)
var target := 0              # runs needed to win; 0 = no chase
var two_batters := true      # strike rotation between a striker and non-striker
var batting_team := "Pindi Falcons"
var batting_short := "PIN"
var fielding_team := "Karachi Comets"
var fielding_short := "KAR"
var batters: Array = ["Ayaan", "Bilal", "Zain", "Faisal"]
var bowlers_by_over: Array = ["daniyal", "hamza"]   # bowler ids, cycled per over
var difficulty_ramp := 0.0   # difficulty added per legal ball (endless), clamped to 1
var window_scale := 1.0
## Over index where the bowler list starts repeating (earlier entries are an intro).
var bowler_cycle_start := 0
## Progressive (Doodle-style) pacing: balls to reach full pace, then balls to max boost.
var progressive := false
var ease_balls := 36
var ramp_balls := 72
var title := "Quick Match"


static func quick_match(target_runs: int, player_name: String = "Ayaan") -> MatchRules:
	var r := MatchRules.new()
	r.mode = QUICK
	r.title = "Quick Match"
	r.overs = 2
	r.max_wickets = 3
	r.target = target_runs
	r.two_batters = true
	r.batters = [player_name, "Bilal", "Zain", "Faisal"]
	r.bowlers_by_over = ["daniyal", "hamza"]
	return r


## The main mode: keep batting until out (1 wicket); pace starts gentle and builds up.
static func classic(player_name: String = "Ayaan", bowling: String = "mixed", seed_value: int = 1) -> MatchRules:
	var r := MatchRules.new()
	r.mode = CLASSIC
	r.title = "Classic"
	r.overs = 0
	r.max_wickets = 1
	r.target = 0
	r.two_batters = false
	r.batters = [player_name]
	r.progressive = true
	match bowling:
		"pace":
			r.bowlers_by_over = ["hamza"]
		"spin":
			r.bowlers_by_over = ["saad"]
		_:
			r.bowlers_by_over = MatchRules.surprise_bowlers(seed_value)
			r.bowler_cycle_start = 1
	return r


## A gentle opening over from the coach, then a random mix of fast, medium and spin
## bowlers over by over (never the same bowler twice in a row), different every match.
static func surprise_bowlers(seed_value: int, overs: int = 24) -> Array:
	var pool := ["hamza", "daniyal", "saad"]   # fast, medium, spin
	var rng := DetRng.new(seed_value)
	var out := ["ayaan_coach"]
	var last := ""
	for i in overs:
		var pick: String = pool[rng.range_i(0, pool.size() - 1)]
		if pick == last:
			pick = pool[(pool.find(pick) + 1 + rng.range_i(0, 1)) % pool.size()]
		out.append(pick)
		last = pick
	return out


static func endless(player_name: String = "Ayaan") -> MatchRules:
	var r := MatchRules.new()
	r.mode = ENDLESS
	r.title = "Endless"
	r.overs = 0
	r.max_wickets = 1
	r.target = 0
	r.two_batters = false
	r.batters = [player_name]
	r.bowlers_by_over = ["daniyal", "hamza", "saad"]
	r.difficulty_ramp = 1.0 / 60.0
	return r


static func practice(player_name: String = "Ayaan", bowler_id: String = "daniyal") -> MatchRules:
	var r := MatchRules.new()
	r.mode = PRACTICE
	r.title = "Practice"
	r.overs = 0
	r.max_wickets = 0
	r.two_batters = false
	r.batters = [player_name]
	r.bowlers_by_over = [bowler_id]
	r.window_scale = 1.25
	return r


static func opening_challenge(player_name: String = "Ayaan") -> MatchRules:
	var r := MatchRules.new()
	r.mode = CHALLENGE
	r.title = "First Challenge"
	r.overs = 1
	r.max_wickets = 2
	r.target = 6
	r.two_batters = false
	r.batters = [player_name, "Bilal"]
	r.bowlers_by_over = ["ayaan_coach"]
	r.window_scale = 1.3
	return r


func total_balls() -> int:
	return overs * 6

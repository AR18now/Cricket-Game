class_name Scorecard
extends RefCounted
## Derives every statistic from the authoritative event log. The HUD, scorecard,
## result banner and commentary all read this, so they can never disagree.

var runs := 0
var wickets := 0
var legal_balls := 0
var fours := 0
var sixes := 0
var batters: Array = []      # {name, runs, balls, fours, sixes, out, how, order}
var bowlers: Array = []      # {id, name, balls, runs, wickets}
var fall_of_wickets: Array = []  # {score, wickets, overs, batter}
var striker := 0
var non_striker := -1
var this_over: Array = []    # symbols for the current over
var complete := false
var result := ""             # won | lost | tied | ended | ""
var result_text := ""
var runs_needed := 0
var balls_left := -1


static func build(rules: MatchRules, events: Array, bowler_names: Dictionary = {}) -> Scorecard:
	var sc := Scorecard.new()
	for i in rules.batters.size():
		sc.batters.append({"name": rules.batters[i], "runs": 0, "balls": 0, "fours": 0, "sixes": 0,
			"out": false, "how": "", "batted": i < (2 if rules.two_batters else 1)})
	sc.striker = 0
	sc.non_striker = 1 if rules.two_batters and rules.batters.size() > 1 else -1
	var next_in := 2 if rules.two_batters else 1
	var bowler_index := {}
	for e in events:
		var bid: String = e["bowler"]
		if not bowler_index.has(bid):
			bowler_index[bid] = sc.bowlers.size()
			sc.bowlers.append({"id": bid, "name": bowler_names.get(bid, bid), "balls": 0, "runs": 0, "wickets": 0})
		var bw: Dictionary = sc.bowlers[bowler_index[bid]]
		var bat: Dictionary = sc.batters[sc.striker]
		var r: int = e["runs"]
		sc.legal_balls += 1
		sc.runs += r
		bat["balls"] += 1
		bat["runs"] += r
		bw["balls"] += 1
		bw["runs"] += r
		if e["kind"] == BallOutcome.FOUR:
			bat["fours"] += 1
			sc.fours += 1
		elif e["kind"] == BallOutcome.SIX:
			bat["sixes"] += 1
			sc.sixes += 1
		if sc.legal_balls % 6 == 1:
			sc.this_over.clear()
		sc.this_over.append(_symbol(e))
		if e["wicket"]:
			sc.wickets += 1
			bw["wickets"] += 1
			if rules.max_wickets > 0:
				bat["out"] = true
				bat["how"] = _how_out(e, bw["name"])
				sc.fall_of_wickets.append({"score": sc.runs, "wickets": sc.wickets,
					"overs": Overs.text(sc.legal_balls), "batter": bat["name"]})
				if next_in < sc.batters.size() and sc.wickets < rules.max_wickets:
					# New batter always takes strike (current Laws of Cricket, 18.11).
					sc.striker = next_in
					sc.batters[next_in]["batted"] = true
					next_in += 1
		elif rules.two_batters and r % 2 == 1:
			var tmp := sc.striker
			sc.striker = sc.non_striker
			sc.non_striker = tmp
		sc._evaluate(rules)
		if sc.complete:
			break
		if rules.two_batters and sc.legal_balls % 6 == 0:
			var tmp2 := sc.striker
			sc.striker = sc.non_striker
			sc.non_striker = tmp2
	sc._evaluate(rules)
	return sc


func _evaluate(rules: MatchRules) -> void:
	var total := rules.total_balls()
	balls_left = total - legal_balls if total > 0 else -1
	runs_needed = maxi(0, rules.target - runs) if rules.target > 0 else 0
	complete = false
	result = ""
	# Precedence: reaching the target wins even on the final ball.
	if rules.target > 0 and runs >= rules.target:
		complete = true
		result = "won"
		var in_hand := rules.max_wickets - wickets
		result_text = "%s won with %d wicket%s in hand and %d ball%s to spare" % [
			rules.batting_team, in_hand, "" if in_hand == 1 else "s", balls_left, "" if balls_left == 1 else "s"]
		return
	var all_out := rules.max_wickets > 0 and wickets >= rules.max_wickets
	var no_balls := total > 0 and legal_balls >= total
	if all_out or no_balls:
		complete = true
		if rules.target > 0:
			if runs == rules.target - 1:
				result = "tied"
				result_text = "Scores level - match tied"
			else:
				result = "lost"
				result_text = "Challenge target not reached - %d more run%s needed" % [runs_needed, "" if runs_needed == 1 else "s"]
		else:
			result = "ended"
			result_text = "Innings over: %d run%s from %d ball%s" % [runs, "" if runs == 1 else "s", legal_balls, "" if legal_balls == 1 else "s"]


static func _symbol(e: Dictionary) -> String:
	if e["wicket"]:
		return "W"
	if e["runs"] == 0:
		return "."
	return str(e["runs"])


static func _how_out(e: Dictionary, bowler_name: String) -> String:
	if e["kind"] == BallOutcome.BOWLED:
		return "b %s" % bowler_name
	if e["kind"] == BallOutcome.CAUGHT:
		if e["fielder"] == bowler_name:
			return "c & b %s" % bowler_name
		return "c %s b %s" % [e["fielder"], bowler_name]
	return "out"


func overs_text() -> String:
	return Overs.text(legal_balls)


func striker_line() -> String:
	var s: Dictionary = batters[striker]
	return "%s %d(%d)" % [s["name"], s["runs"], s["balls"]]


func non_striker_line() -> String:
	if non_striker < 0:
		return ""
	var s: Dictionary = batters[non_striker]
	return "%s %d(%d)" % [s["name"], s["runs"], s["balls"]]

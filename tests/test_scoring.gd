extends TestCase


func _o(kind: String, runs: int, wicket: bool = false, fielder: String = "") -> BallOutcome:
	var o := BallOutcome.new()
	o.kind = kind
	o.runs = runs
	o.wicket = wicket
	o.fielder_name = fielder
	return o


func _runs(r: int) -> BallOutcome:
	return _o(BallOutcome.DOT if r == 0 else (BallOutcome.FOUR if r == 4 else (BallOutcome.SIX if r == 6 else BallOutcome.RUNS)), r)


func _play(st: MatchState, seq: Array) -> void:
	for x in seq:
		var o: BallOutcome = x if x is BallOutcome else _runs(int(x))
		st.record(st.events.size(), o, st.current_bowler_id())


func test_legal_balls_and_over_rollover() -> void:
	var st := MatchState.new(MatchRules.quick_match(100), 1)
	_play(st, [0, 0, 0, 0, 0])
	eq(st.card.overs_text(), "0.5")
	_play(st, [0, 0, 0, 0, 0, 0])
	eq(st.card.overs_text(), "1.5")
	check(not st.is_complete(), "not complete at 1.5")
	_play(st, [0])
	eq(st.card.overs_text(), "2.0")
	check(st.is_complete(), "two overs done")
	eq(st.card.result, "lost")


func test_strike_rotation_odd_runs_and_over_end() -> void:
	var rules := MatchRules.quick_match(100, "Ayaan")
	rules.overs = 5
	var st := MatchState.new(rules, 1)
	_play(st, [1])
	eq(st.card.batters[st.card.striker]["name"], "Bilal", "single swaps strike")
	_play(st, [2])
	eq(st.card.batters[st.card.striker]["name"], "Bilal", "two keeps strike")
	_play(st, [3])
	eq(st.card.batters[st.card.striker]["name"], "Ayaan", "three swaps strike")
	_play(st, [4, 6])
	eq(st.card.batters[st.card.striker]["name"], "Ayaan", "boundaries keep strike")
	_play(st, [0])  # sixth ball -> over ends -> swap
	eq(st.card.batters[st.card.striker]["name"], "Bilal", "end of over swaps strike")
	# Single off the last ball of an over: swap twice -> same batter keeps strike.
	_play(st, [0, 0, 0, 0, 0, 1])
	eq(st.card.batters[st.card.striker]["name"], "Bilal", "single off last ball: odd swap + over swap")
	var bil: Dictionary = st.card.batters[1]
	var aya: Dictionary = st.card.batters[0]
	eq(aya["runs"] + bil["runs"], st.card.runs, "batter runs sum to total")
	eq(aya["balls"] + bil["balls"], st.card.legal_balls, "batter balls sum to legal balls")


func test_no_strike_swap_after_innings_ends() -> void:
	var st := MatchState.new(MatchRules.quick_match(100, "Ayaan"), 1)
	_play(st, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
	check(st.is_complete(), "innings over at 2.0")
	eq(st.card.batters[st.card.striker]["name"], "Ayaan", "odd run swap only; no over-end swap after completion")


func test_wicket_brings_new_batter_on_strike() -> void:
	var st := MatchState.new(MatchRules.quick_match(100, "Ayaan"), 1)
	_play(st, [1])  # Bilal on strike
	_play(st, [_o(BallOutcome.BOWLED, 0, true)])
	eq(st.card.batters[1]["out"], true, "Bilal out")
	eq(st.card.batters[1]["how"], "b Daniyal".replace("Daniyal", st.card.bowlers[0]["name"]))
	eq(st.card.batters[st.card.striker]["name"], "Zain", "new batter takes strike")
	eq(st.card.batters[st.card.non_striker]["name"], "Ayaan", "survivor stays at non-striker end")
	eq(st.card.fall_of_wickets.size(), 1)
	eq(st.card.fall_of_wickets[0]["score"], 1)


func test_three_wickets_end_innings() -> void:
	var st := MatchState.new(MatchRules.quick_match(100), 1)
	_play(st, [_o(BallOutcome.BOWLED, 0, true), _o(BallOutcome.CAUGHT, 0, true, "Imran"), _o(BallOutcome.BOWLED, 0, true)])
	check(st.is_complete(), "all out after three wickets")
	eq(st.card.result, "lost")
	check(not st.record(99, _runs(6), "hamza"), "no recording after completion")
	eq(st.card.runs, 0)


func test_target_reached_on_last_ball_wins() -> void:
	var st := MatchState.new(MatchRules.quick_match(10), 1)
	_play(st, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4])
	eq(st.card.balls_left, 1)
	eq(st.card.runs_needed, 6)
	eq(Overs.required_rate(st.card.runs_needed, st.card.balls_left), 36.0)
	_play(st, [6])
	eq(st.card.result, "won", "target reached off the final ball wins")
	eq(st.card.balls_left, 0)


func test_tie_and_loss_wording() -> void:
	var st := MatchState.new(MatchRules.quick_match(10), 1)
	_play(st, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 5])
	eq(st.card.result, "tied", "scores level")
	var st2 := MatchState.new(MatchRules.quick_match(10), 1)
	_play(st2, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4])
	eq(st2.card.result, "lost")
	check(st2.card.result_text.contains("2 more runs"), "loss explains the shortfall")


func test_win_mid_over_stops_innings() -> void:
	var st := MatchState.new(MatchRules.quick_match(7), 1)
	_play(st, [6, 1])
	eq(st.card.result, "won")
	check(st.card.result_text.contains("3 wickets in hand"), st.card.result_text)
	check(st.card.result_text.contains("10 balls"), st.card.result_text)


func test_duplicate_delivery_ids_ignored() -> void:
	var st := MatchState.new(MatchRules.quick_match(100), 1)
	check(st.record(5, _runs(4), "daniyal"), "first record")
	check(not st.record(5, _runs(4), "daniyal"), "duplicate rejected")
	eq(st.card.runs, 4)
	eq(st.card.legal_balls, 1)


func test_bowler_figures_and_economy() -> void:
	var st := MatchState.new(MatchRules.quick_match(100), 1)
	_play(st, [1, 0, 4, 0, _o(BallOutcome.CAUGHT, 0, true, "Imran"), 2])
	_play(st, [6])
	var b0: Dictionary = st.card.bowlers[0]
	var b1: Dictionary = st.card.bowlers[1]
	eq(b0["id"], "daniyal")
	eq(b0["balls"], 6)
	eq(b0["runs"], 7)
	eq(b0["wickets"], 1)
	near(Overs.economy(b0["runs"], b0["balls"]), 7.0, 0.001)
	eq(b1["id"], "hamza", "bowler changes each over")
	eq(Overs.text(b1["balls"]), "0.1")
	near(Overs.economy(b1["runs"], b1["balls"]), 36.0, 0.001, "economy from legal balls")


func test_single_batter_endless_rules() -> void:
	var st := MatchState.new(MatchRules.endless("Ayaan"), 1)
	_play(st, [1, 1, 1, 0, 0, 0, 3])
	eq(st.card.striker, 0, "single batter keeps strike in endless")
	eq(st.card.non_striker, -1)
	_play(st, [_o(BallOutcome.BOWLED, 0, true)])
	check(st.is_complete(), "one wicket ends endless")
	eq(st.card.result, "ended")


func test_practice_never_ends() -> void:
	var st := MatchState.new(MatchRules.practice(), 1)
	for i in 40:
		_play(st, [_o(BallOutcome.BOWLED, 0, true) if i % 3 == 0 else _runs(i % 5)])
	check(not st.is_complete(), "practice continues")


func test_scorecard_totals_match_event_log() -> void:
	var st := MatchState.new(MatchRules.quick_match(200), 3)
	var rng := DetRng.new(3)
	for i in 12:
		var r := rng.range_i(0, 6)
		if r == 5:
			_play(st, [_o(BallOutcome.CAUGHT, 0, true, "Imran")])
		else:
			_play(st, [r])
		if st.is_complete():
			break
	var total := 0
	var fours := 0
	var sixes := 0
	for e in st.events:
		total += int(e["runs"])
		fours += 1 if e["kind"] == BallOutcome.FOUR else 0
		sixes += 1 if e["kind"] == BallOutcome.SIX else 0
	eq(st.card.runs, total, "total = sum of events")
	var bat_runs := 0
	var bowl_runs := 0
	for b in st.card.batters:
		bat_runs += int(b["runs"])
	for b in st.card.bowlers:
		bowl_runs += int(b["runs"])
	eq(bat_runs, total, "batting card sums")
	eq(bowl_runs, total, "bowling card sums (no extras)")
	eq(st.card.fours, fours)
	eq(st.card.sixes, sixes)

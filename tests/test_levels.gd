extends TestCase
## Difficulty levels: up every 12 balls or 25 runs, capped at 8; harder but still playable.


func _record(st: MatchState, kind: String, runs: int, id: int) -> void:
	var o := BallOutcome.new()
	o.kind = kind
	o.runs = runs
	st.record(id, o, "hamza")


func test_level_rises_with_balls_and_runs() -> void:
	var st := MatchState.new(MatchRules.classic(), 1)
	eq(st.level(), 1, "starts at level 1")
	for i in 12:
		_record(st, BallOutcome.DOT, 0, i)
	eq(st.level(), 2, "12 balls -> level 2")
	var st2 := MatchState.new(MatchRules.classic(), 2)
	for i in 5:
		_record(st2, BallOutcome.SIX, 6, i)
	eq(st2.level(), 2, "25+ runs (in 5 balls) -> level 2")
	for i in 200:
		_record(st, BallOutcome.DOT, 0, 100 + i)
	eq(st.level(), MatchState.MAX_LEVEL, "capped at the top level")
	near(st.difficulty(), 1.0, 1e-6, "top level = full difficulty")


func test_top_level_is_faster_but_every_ball_is_playable() -> void:
	var tuning := TestCase.tuning()
	var prof: BowlerProfile = load("res://data/bowlers/hamza.tres")
	var slow := 0.0
	var fast := 0.0
	for i in 200:
		var d1 := DeliveryGenerator.generate(prof, 5000 + i, tuning, 0.0, 1.0)
		var d8 := DeliveryGenerator.generate(prof, 5000 + i, tuning, 1.0, 1.0)
		if d1.kind != "slower" and d8.kind != "slower":   # compare normal deliveries
			slow += d1.speed
			fast += d8.speed
		check(DeliveryGenerator.is_playable(d8, tuning), "top-level ball %d is hittable" % i)
		check(d8.speed_kmh() <= 145, "never absurdly fast (%d km/h)" % d8.speed_kmh())
	check(fast / slow > 1.3, "top level normal balls clearly faster (x%.2f)" % (fast / slow))

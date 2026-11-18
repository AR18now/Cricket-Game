extends TestCase
## Difficulty follows the score: very easy to 50, rising to 100, harder after; capped at 8.


func _record(st: MatchState, kind: String, runs: int, id: int) -> void:
	var o := BallOutcome.new()
	o.kind = kind
	o.runs = runs
	st.record(id, o, "hamza")


func _to_runs(st: MatchState, target: int, id0: int) -> void:
	var i := 0
	while st.card.runs < target:
		var left := target - st.card.runs
		if left >= 6:
			_record(st, BallOutcome.SIX, 6, id0 + i)
		else:
			_record(st, BallOutcome.RUNS, 1, id0 + i)
		i += 1


func test_difficulty_follows_the_score() -> void:
	var st := MatchState.new(MatchRules.classic(), 1)
	eq(st.level(), 1, "starts at level 1")
	near(st.assist(), 1.0, 1e-6, "full beginner help at the start")
	near(st.ease_in(), 0.0, 1e-6, "gentle bowling at the start")
	near(st.difficulty(), 0.0, 1e-6, "no extra pace at the start")
	for i in 60:
		_record(st, BallOutcome.DOT, 0, 500 + i)
	eq(st.level(), 1, "dot balls alone don't raise the level (it follows runs)")
	_to_runs(st, 49, 1000)
	eq(st.level(), 1, "still level 1 on 49")
	near(st.assist(), 1.0, 1e-6, "still full help on 49")
	_to_runs(st, 50, 2000)
	eq(st.level(), 2, "50 runs -> level 2")
	_to_runs(st, 75, 3000)
	check(st.assist() < 1.0 and st.assist() > 0.0, "help fading between 50 and 100")
	check(st.ease_in() > 0.0 and st.ease_in() < 1.0, "pace building between 50 and 100")
	eq(st.level(), 3, "75 runs -> level 3")
	_to_runs(st, 100, 4000)
	eq(st.level(), 5, "100 runs -> level 5")
	near(st.assist(), 0.0, 1e-6, "no help from 100")
	near(st.ease_in(), 1.0, 1e-6, "real pace from 100")
	_to_runs(st, 175, 5000)
	check(st.difficulty() > 0.4, "harder again after 100")
	_to_runs(st, 400, 6000)
	eq(st.level(), MatchState.MAX_LEVEL, "capped at the top level")
	near(st.difficulty(), 1.0, 1e-6, "full difficulty eventually")


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

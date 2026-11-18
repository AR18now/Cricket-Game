extends TestCase
## First-match tutorial (any hit = four or six, can't be out) and the beginner help for
## the first 50 runs (no bowled from a miss, mistimed shots on the ground, perfect = six).

var pindi: VenueConfig = load("res://data/venues/pindi.tres")


func _fielders(t: GameTuning) -> Array:
	return FielderSpec.from_layout(pindi.field_layout, ["B", "K", "1", "2", "3", "4", "5", "6", "7", "8", "9"], t)


func test_tutorial_any_tap_is_four_or_six() -> void:
	var t := TestCase.tuning()
	var f := _fielders(t)
	var sixes := 0
	var n := 0
	for s in 40:
		var d := DeliveryGenerator.tutorial_ball(9000 + s, t)
		var open := ContactResolver.window_open_time(d, t)
		var close := ContactResolver.window_close_time(d, t)
		var k := 0
		while k <= 12:
			var tap := lerpf(open, close, k / 12.0)
			var r := BallResolver.resolve_tutorial(d, tap, f, pindi, t)
			check(r.outcome.is_boundary(), "tutorial tap %.0f%% through the window -> boundary (got %s)" % [k / 12.0 * 100.0, r.outcome.kind])
			check(not r.outcome.wicket, "never out in the tutorial")
			if r.outcome.kind == BallOutcome.SIX:
				sixes += 1
			n += 1
			k += 1
		var none := BallResolver.resolve_tutorial(d, -1.0, f, pindi, t)
		check(not none.outcome.wicket, "leaving a tutorial ball is not out")
	check(sixes > n / 4, "plenty of sixes for good timing (%d of %d)" % [sixes, n])


func test_easy_stage_balls_miss_the_stumps_and_shots_are_safe() -> void:
	var t := TestCase.tuning()
	var f := _fielders(t)
	var outs := 0
	var total := 0
	for id in ["ayaan_coach", "daniyal", "hamza", "saad"]:
		var prof: BowlerProfile = load("res://data/bowlers/%s.tres" % id)
		for s in 60:
			var d := DeliveryGenerator.generate(prof, 7000 + s, t, 0.0, 0.0, 1.0)
			check(not d.hits_stumps(), "%s easy-stage ball %d misses the stumps" % [id, s])
			check(DeliveryGenerator.is_playable(d, t), "%s easy-stage ball %d is hittable" % [id, s])
			var ideal := d.time_at_x(t.contact_x_ideal) - t.swing_to_contact
			for off in [-0.12, -0.08, -0.05, -0.02, 0.0, 0.02, 0.05, 0.08, 0.12]:
				var r := BallResolver.resolve(d, ideal + off, 0, f, pindi, t, MatchState.EASY_WINDOW, true)
				total += 1
				if r.outcome.wicket:
					outs += 1
			total += 1
			if BallResolver.resolve(d, -1.0, 0, f, pindi, t, MatchState.EASY_WINDOW, true).outcome.wicket:
				outs += 1
	check(outs * 100 <= total, "beginner help: at most 1%% of balls are out (%d of %d)" % [outs, total])


func test_95_percent_reach_50() -> void:
	# Simulated casual and new players (human-like timing mistakes, see tools/sim_curve.gd).
	var sim = load("res://tools/sim_curve.gd")
	var t := TestCase.tuning()
	var bowlers := {}
	for id in ["ayaan_coach", "daniyal", "hamza", "saad"]:
		bowlers[id] = load("res://data/bowlers/%s.tres" % id)
	for model in ["new", "casual"]:
		var out50 := 0
		var out_late := 0
		var n := 120
		for i in n:
			var res: Dictionary = sim.run_innings(sim.MODELS[model], 50000 + i, t, pindi, bowlers, false)
			if res["out"] and int(res["runs"]) < 50:
				out50 += 1
			if res["out"]:
				out_late += 1
		check(out50 * 20 <= n, "%s players: 95%%+ not out before 50 (out: %d of %d)" % [model, out50, n])
		check(out_late * 2 >= n, "%s players: the game does get hard later (out eventually: %d of %d)" % [model, out_late, n])

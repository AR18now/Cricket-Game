extends SceneTree
## Difficulty curve report: simulates thousands of Classic innings with human-like
## timing mistakes and reports how far players get.
##   godot --headless --path . --script res://tools/sim_curve.gd
##
## Player models (timing error of the tap, in ms, around the ideal moment):
##   new     : sd 75 ms, 4% wild taps (+-150..350 ms), 2% no tap at all
##   casual  : sd 55 ms, 3% wild taps, 1% no tap
##   good    : sd 35 ms, 1% wild taps
## Wild taps model looking away / panic; "no tap" models freezing on a ball.

static var DIAG := {}

const MODELS := {
	"new": {"sd": 75.0, "wild": 0.04, "none": 0.02},
	"casual": {"sd": 55.0, "wild": 0.03, "none": 0.01},
	"good": {"sd": 35.0, "wild": 0.01, "none": 0.0},
}


static func run_innings(model: Dictionary, seed_value: int, tuning: GameTuning, venue: VenueConfig,
		bowlers: Dictionary, tutorial: bool, max_balls := 400) -> Dictionary:
	var rules := MatchRules.classic("You", "mixed", seed_value)
	var st := MatchState.new(rules, seed_value)
	var rng := DetRng.new(seed_value * 7919 + 17)
	var names := ["Bowler", "Keeper", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9"]
	var fielders := FielderSpec.from_layout(venue.field_layout, names, tuning)
	var balls := 0
	var tut := 6 if tutorial else 0
	while not st.is_complete() and balls < max_balls:
		var idx := st.next_ball_index()
		var seed := DetRng.derive(st.seed, idx)
		var prof: BowlerProfile = bowlers[st.current_bowler_id()]
		var in_tut := tut > 0
		var d: Delivery
		if in_tut:
			d = DeliveryGenerator.tutorial_ball(seed, tuning)
		else:
			d = DeliveryGenerator.generate(prof, seed, tuning, st.difficulty(), st.ease_in(), st.assist())
		var ideal := d.time_at_x(tuning.contact_x_ideal) - tuning.swing_to_contact
		var sw := -1.0
		var u := rng.next_float()
		if u >= float(model["none"]):
			var err := rng.gaussian() * float(model["sd"]) / 1000.0
			if rng.next_float() < float(model["wild"]):
				err = (1.0 if rng.chance(0.5) else -1.0) * rng.range_f(0.15, 0.35)
			sw = maxf(ideal + err, ContactResolver.window_open_time(d, tuning))
			if sw > ContactResolver.window_close_time(d, tuning) + 0.3:
				sw = -1.0
		var r: BallResolver
		if in_tut:
			r = BallResolver.resolve_tutorial(d, sw, fielders, venue, tuning)
			tut -= 1
		else:
			r = BallResolver.resolve(d, sw, 0, fielders, venue, tuning, st.window_scale(), DetRng.new(DetRng.derive(d.seed, 7, 0x5AFE)).chance(st.assist()))
		st.record(idx, r.outcome, prof.id)
		balls += 1
		if r.outcome.wicket and st.card.runs < 50:
			var key := "%s/%s/%s" % [r.outcome.kind, r.outcome.timing, d.kind]
			DIAG[key] = DIAG.get(key, 0) + 1
	return {"runs": st.card.runs, "out": st.is_complete(), "balls": balls}


func _initialize() -> void:
	var tuning: GameTuning = load("res://data/tuning_default.tres")
	var venue: VenueConfig = load("res://data/venues/pindi.tres")
	var bowlers := {}
	for id in ["ayaan_coach", "daniyal", "hamza", "saad"]:
		bowlers[id] = load("res://data/bowlers/%s.tres" % id)
	var n := int(OS.get_environment("SIM_N")) if OS.get_environment("SIM_N") != "" else 400
	var tut_list := [false, true] if OS.get_environment("SIM_TUT") == "" else [OS.get_environment("SIM_TUT") == "1"]
	for tutorial in tut_list:
		print("== tutorial %s (%d innings per player model)" % ["ON" if tutorial else "OFF", n])
		for name in MODELS:
			var scores: Array = []
			var out50 := 0
			var out100 := 0
			for i in n:
				var res := run_innings(MODELS[name], 1000 + i, tuning, venue, bowlers, tutorial)
				var runs: int = res["runs"]
				scores.append(runs)
				if res["out"] and runs < 50:
					out50 += 1
				if res["out"] and runs < 100:
					out100 += 1
			scores.sort()
			if OS.get_environment("SIM_DIAG") != "":
				print("    outs before 50 by kind/timing/ball: ", DIAG)
			DIAG.clear()
			print("  %-7s out before 50: %5.1f%%   out before 100: %5.1f%%   median %d   p90 %d" % [
				name, 100.0 * out50 / n, 100.0 * out100 / n, scores[n / 2], scores[int(n * 0.9)]])
	quit()

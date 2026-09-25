extends SceneTree
## Balance report: outcome distribution by timing offset / stance / bowler.
## godot --headless --path . --script res://tools/sim_stats.gd


func _initialize() -> void:
	var t: GameTuning = load("res://data/tuning_default.tres")
	var v: VenueConfig = load("res://data/venues/pindi.tres")
	var names := ["Hamza", "Usman", "Imran", "Kashif", "Rizwan", "Tariq", "Nadeem", "Sohail", "Asif", "Waqar"]
	var field := FielderSpec.from_layout(v.field_layout, names, t)
	for bid in ["ayaan_coach", "daniyal", "hamza", "saad"]:
		var b: BowlerProfile = load("res://data/bowlers/%s.tres" % bid)
		for stance in [0, 1, 2]:
			print("== %s stance=%s" % [bid, ["AUTO", "GROUNDED", "LOFTED"][stance]])
			for off in [-90, -60, -40, -25, -10, 0, 10, 25, 40, 60, 90]:
				var c := {}
				var n := 200
				var runs := 0
				for s in n:
					var d := DeliveryGenerator.generate(b, s * 97 + 13, t, 0.0)
					var sw: float = d.time_at_x(t.contact_x_ideal) - t.swing_to_contact + float(off) / 1000.0
					var r := BallResolver.resolve(d, sw, stance, field, v, t)
					var k: String = r.outcome.kind
					if k == "runs":
						k = str(r.outcome.runs)
					c[k] = c.get(k, 0) + 1
					runs += r.outcome.runs
				var line := "  dt=%4d  avg=%.2f  " % [off, float(runs) / n]
				for key in ["bowled", "dot", "1", "2", "3", "four", "six", "caught"]:
					line += "%s:%3d%% " % [key, int(100.0 * c.get(key, 0) / n)]
				print(line)
	quit()

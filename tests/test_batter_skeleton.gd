extends TestCase
## The batter's-eye batsman is a 3D skeleton: bones keep their length, the hands stay on
## the bat, the bat meets the ball at contact, and nothing teleports between frames.

const DUR := 0.34
const CU := 0.3


func _opts(swing_t: float, target, bowled := false) -> Dictionary:
	return {"swing_time": swing_t, "swing_dur": DUR, "contact_u": CU, "target": target,
		"stumps_t": 0.75, "bowled": bowled, "base": Vector2(-1.05, -0.42), "look": Vector3(-15, 0, 1.0),
		"runup_t": 2.2, "ideal_t": swing_t + DUR * CU if swing_t >= 0.0 else 0.72}


func _bones_ok(j: Dictionary, label: String) -> void:
	for s in ["l", "r"]:
		near(j["hip_" + s].distance_to(j["knee_" + s]), BatterSkeleton.THIGH, 0.002, label + " thigh " + s)
		near(j["knee_" + s].distance_to(j["ankle_" + s]), BatterSkeleton.SHIN, 0.002, label + " shin " + s)
		near(j["sh_" + s].distance_to(j["el_" + s]), BatterSkeleton.UPPER_ARM, 0.002, label + " upper arm " + s)
		near(j["el_" + s].distance_to(j["wr_" + s]), BatterSkeleton.FOREARM, 0.002, label + " forearm " + s)
		check(j["toe_" + s].z >= -0.001, label + " toe above ground " + s)
		check(j["ankle_" + s].distance_to(j["toe_" + s]) < 0.3, label + " ankle stays over the shoe " + s)
	near(j["hand_bot"].distance_to(j["hand_top"] + j["bat_dir"] * BatterSkeleton.GRIP_GAP), 0.0, 0.04, label + " bottom hand on the handle")
	check(j["bat_toe"].z > -0.06, label + " bat not through the ground")


func test_bones_hold_through_a_whole_ball() -> void:
	for target in [Vector3(-1.6, 0.0, 0.35), Vector3(-2.2, 0.15, 0.2), Vector3(-0.8, -0.1, 1.0), null]:
		var o := _opts(0.62, target)
		var t := -2.4
		while t < 1.6:
			_bones_ok(BatterSkeleton.solve(t, o), "t=%.2f %s" % [t, str(target)])
			t += 0.05


func test_sweet_spot_meets_the_ball() -> void:
	for target in [Vector3(-1.6, 0.0, 0.35), Vector3(-1.6, 0.12, 0.6), Vector3(-1.9, -0.1, 0.25), Vector3(-1.3, 0.05, 0.8)]:
		var o := _opts(0.62, target)
		var j := BatterSkeleton.solve(0.62 + DUR * CU, o)
		var miss: float = j["bat_sweet"].distance_to(target)
		check(miss < 0.2, "sweet spot within 20 cm of %s (was %.2f m)" % [str(target), miss])


func test_motion_is_continuous() -> void:
	var o := _opts(0.55, Vector3(-1.6, 0.0, 0.4))
	var prev := BatterSkeleton.solve(-2.4, o)
	var t := -2.4
	var dt := 1.0 / 120.0
	var worst := 0.0
	var worst_key := ""
	while t < 1.4:
		t += dt
		var j := BatterSkeleton.solve(t, o)
		for k in ["pelvis", "head", "hand_top", "knee_l", "ankle_l", "el_r"]:
			var jump: float = j[k].distance_to(prev[k])
			if jump > worst:
				worst = jump
				worst_key = "%s at t=%.3f" % [k, t]
		# The bat toe moves fastest (a real swing); still no teleports.
		check(j["bat_toe"].distance_to(prev["bat_toe"]) < 0.4, "bat toe continuous at t=%.3f" % t)
		prev = j
	check(worst < 0.12, "no body joint jumps more than 12 cm in a frame (worst %.3f: %s)" % [worst, worst_key])


func test_left_ball_bat_comes_back_down() -> void:
	var o := _opts(-1.0, null)
	var high := BatterSkeleton.solve(0.3, o)
	var later := BatterSkeleton.solve(1.6, o)
	check(high["bat_toe"].z > 0.9, "bat raised in the backlift")
	check(later["bat_toe"].z < 0.15, "bat grounded again after leaving the ball")

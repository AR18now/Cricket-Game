extends TestCase


func test_single_swing_per_delivery() -> void:
	var g := SwingGate.new()
	g.arm(0.5, 1.2)
	eq(g.try_swing(0.2), "too_soon")
	eq(g.try_swing(0.8), "accepted")
	eq(g.try_swing(0.81), "already")
	eq(g.try_swing(0.82), "already")
	eq(g.swing_time, 0.8, "first accepted swing kept")
	eq(g.ignored, 3)


func test_taps_after_window_or_disarmed_ignored() -> void:
	var g := SwingGate.new()
	g.arm(0.5, 1.2)
	eq(g.try_swing(1.3), "closed")
	g.disarm()
	eq(g.try_swing(0.8), "closed")
	eq(g.swing_time, -1.0)


func test_clock_independent_of_frame_rate() -> void:
	# The same real input moment maps to the same sim time at 20, 60 and 144 fps.
	var results: Array = []
	for fps in [20.0, 60.0, 144.0]:
		var c := SimClock.new()
		var usec := 0
		c.reset(-2.0, usec)
		var dt: float = 1.0 / fps
		var tap_usec := 2_345_678
		while usec + int(dt * 1_000_000.0) <= tap_usec:
			usec += int(dt * 1_000_000.0)
			c.advance(float(int(dt * 1_000_000.0)) / 1_000_000.0, usec)
		results.append(c.time_of_input(tap_usec))
	near(results[0], results[1], 1e-6, "20 vs 60 fps")
	near(results[1], results[2], 1e-6, "60 vs 144 fps")
	near(results[0], 0.345678, 1e-6, "absolute")


func test_pause_freezes_clock() -> void:
	var c := SimClock.new()
	c.reset(0.0, 0)
	c.advance(0.5, 500_000)
	c.set_paused(true, 500_000)
	c.advance(1.0, 1_500_000)
	near(c.time, 0.5, 1e-9, "paused advance ignored")
	near(c.time_of_input(9_000_000), 0.5, 1e-9, "input while paused maps to pause time")
	c.set_paused(false, 2_000_000)
	c.advance(0.1, 2_100_000)
	near(c.time, 0.6, 1e-9)


func test_time_scale_consistency() -> void:
	var c := SimClock.new()
	c.reset(0.0, 0)
	near(c.time_of_input(1_000_000, 0.25), 0.25, 1e-9, "slow motion scales input time")


func test_same_seed_same_ball_outcome() -> void:
	var t := tuning()
	var v := venue()
	var fl := field(t)
	var d1 := DeliveryGenerator.generate(bowler("hamza"), 4242, t, 0.2)
	var d2 := DeliveryGenerator.generate(bowler("hamza"), 4242, t, 0.2)
	var r1 := BallResolver.resolve(d1, swing_for(d1, t, 12.0), 0, fl, v, t)
	var r2 := BallResolver.resolve(d2, swing_for(d2, t, 12.0), 0, fl, v, t)
	eq(r1.outcome.to_event(), r2.outcome.to_event(), "replayable")

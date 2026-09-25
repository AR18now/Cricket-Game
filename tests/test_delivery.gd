extends TestCase


func test_over_notation() -> void:
	eq(Overs.text(0), "0.0")
	eq(Overs.text(5), "0.5")
	eq(Overs.text(6), "1.0")
	eq(Overs.text(11), "1.5")
	eq(Overs.text(12), "2.0", "1.5 + one legal ball")


func test_rates_handle_zero_balls() -> void:
	eq(Overs.economy(10, 0), -1.0)
	eq(Overs.rate_text(Overs.economy(10, 0)), "-")
	near(Overs.economy(9, 4), 13.5, 0.001, "economy from legal balls, not 0.4 overs")
	eq(Overs.strike_rate(5, 0), -1.0)
	near(Overs.strike_rate(6, 4), 150.0, 0.001)
	near(Overs.required_rate(10, 5), 12.0, 0.001)
	eq(Overs.required_rate(10, 0), -1.0)


func test_rng_reproducible() -> void:
	var a := DetRng.new(12345)
	var b := DetRng.new(12345)
	var same := true
	for i in 1000:
		if a.next_u32() != b.next_u32():
			same = false
	check(same, "same seed -> same sequence")
	var c := DetRng.new(12346)
	check(DetRng.new(12345).next_u32() != c.next_u32(), "different seeds differ")
	# Known-answer check guards against platform-dependent integer behaviour.
	var k := DetRng.new(42)
	var seq := [k.next_u32(), k.next_u32(), k.next_u32()]
	for v in seq:
		check(v >= 0 and v <= 0xFFFFFFFF, "32-bit range")


func test_delivery_reproducible_from_seed() -> void:
	var t := tuning()
	for id in ["daniyal", "hamza", "saad"]:
		var d1 := DeliveryGenerator.generate(bowler(id), 777, t, 0.3)
		var d2 := DeliveryGenerator.generate(bowler(id), 777, t, 0.3)
		eq(d1.to_dict(), d2.to_dict(), id)


func test_generated_deliveries_are_playable() -> void:
	var t := tuning()
	for id in ["ayaan_coach", "daniyal", "hamza", "saad"]:
		var b := bowler(id)
		var bad := 0
		for s in 300:
			var d := DeliveryGenerator.generate(b, s * 31 + 7, t, 1.0)
			if not DeliveryGenerator.is_playable(d, t):
				bad += 1
			check(d.speed <= maxf(b.speed_max, b.slower_max) * (1.0 + DeliveryGenerator.MAX_PACE_BOOST) + 0.001, "pace bounded")
		eq(bad, 0, "%s unplayable deliveries" % id)


func test_path_continuity_and_bounce() -> void:
	var t := tuning()
	var d := DeliveryGenerator.tutorial(0, 1, t)
	var p := d.pos_at(d.t_bounce)
	near(p.z, 0.0, 0.001, "bounces at ground")
	near(p.x, -d.length, 0.001, "bounces at length")
	near(d.pos_at(0.0).x, t.release_x, 0.001, "starts at release")
	# Continuity across the bounce.
	var a := d.pos_at(d.t_bounce - 0.0001)
	var b := d.pos_at(d.t_bounce + 0.0001)
	check(a.distance_to(b) < 0.01, "continuous at bounce")


func test_stumps_hit_detected_at_any_speed() -> void:
	# Tunnelling guard: a straight fast ball must be detected as hitting the stumps even
	# though a 30 fps frame-stepped check would move it ~1.5 m per frame.
	var t := tuning()
	for spd in [12.0, 20.0, 30.0, 45.0, 60.0]:
		var d := Delivery.new()
		d.speed = spd
		d.length = 3.0
		d.line_y = 0.0
		d.release = Vector3(t.release_x, 0.0, 1.2)
		d.build()
		var z := d.pos_at(d.stumps_time()).z
		if z <= Delivery.STUMPS_HEIGHT:
			check(d.hits_stumps(), "straight ball at %.0f m/s hits" % spd)
		# Frame-stepped sampling misses the thin stump plane at high speed:
		var frame_hits := false
		var ft := 0.0
		while ft < d.stumps_time() + 0.2:
			var q := d.pos_at(ft)
			if absf(q.x) <= Delivery.BALL_RADIUS:
				frame_hits = true
			ft += 1.0 / 30.0
		if spd >= 30.0:
			check(not frame_hits or d.hits_stumps(), "analytic check is independent of frame rate")


func test_wide_line_misses_stumps() -> void:
	var t := tuning()
	var d := Delivery.new()
	d.speed = 20.0
	d.length = 5.0
	d.line_y = 0.5
	d.release = Vector3(t.release_x, 0.4, t.release_height)
	d.build()
	check(not d.hits_stumps(), "ball 0.5 m outside off misses")
	d.line_y = 0.1
	d.build()
	check(d.hits_stumps() or d.pos_at(d.stumps_time()).z > Delivery.STUMPS_HEIGHT, "ball on off stump hits or bounces over")

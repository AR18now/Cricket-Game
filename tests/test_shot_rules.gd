extends TestCase


func _sim(launch: Vector3, fielders: Array = [], at: Vector3 = Vector3(-1.6, 0.0, 0.6)) -> ShotResult:
	var t := tuning()
	return ShotSim.simulate(contact_with(launch, at), fielders, venue(), t)


func _fielder(p: Vector2, t: GameTuning) -> FielderSpec:
	var f := FielderSpec.make("F", p, "fielder", t)
	f.position_name = "test"
	return f


func test_six_crosses_rope_in_the_air() -> void:
	var s := _sim(Vector3(-24.0, 0.0, 16.0))
	eq(s.outcome, ShotResult.SIX)
	eq(s.runs, 6)
	check(s.first_bounce_t == INF or s.first_bounce_t > s.boundary_t, "no bounce before the rope")


func test_four_touches_ground_first() -> void:
	var s := _sim(Vector3(-30.0, 0.0, 2.0))
	eq(s.outcome, ShotResult.FOUR)
	eq(s.runs, 4)
	check(s.first_bounce_t < s.boundary_t, "bounced before the rope")


func test_catch_requires_no_prior_bounce() -> void:
	var t := tuning()
	# Find where a lofted ball comes down, put a fielder there -> caught.
	var probe := _sim(Vector3(-16.0, 0.0, 9.0))
	var land := probe.ball_pos_at(probe.first_bounce_t - 0.05)
	var f := _fielder(Vector2(land.x, land.y), t)
	var caught := _sim(Vector3(-16.0, 0.0, 9.0), [f])
	eq(caught.outcome, ShotResult.CAUGHT, "fielder under the ball catches it")
	check(caught.t_collect < caught.first_bounce_t, "catch before bounce")
	# A static fielder that the ball only reaches after its first bounce cannot catch it,
	# even if the ball hops up to catchable height again.
	var hop_i := -1
	var land_p := probe.ball_pos_at(probe.first_bounce_t)
	for i in range(int(probe.first_bounce_t / probe.dt) + 2, probe.samples.size()):
		var sp: Vector3 = probe.samples[i]
		if sp.z > t.catch_min_height + 0.05 and Vector2(sp.x - land_p.x, sp.y - land_p.y).length() > t.catch_reach + 1.0:
			hop_i = i
			break
	if hop_i >= 0:
		var hp: Vector3 = probe.samples[hop_i]
		var statue := _fielder(Vector2(hp.x, hp.y), t)
		statue.speed = 0.001
		statue.reaction = 0.0
		var s2 := _sim(Vector3(-16.0, 0.0, 9.0), [statue])
		check(s2.outcome != ShotResult.CAUGHT, "ball that already bounced is not a catch")
		check(s2.collector == 0 and s2.t_collect > s2.first_bounce_t, "fielded after the bounce instead")
	else:
		check(false, "expected a post-bounce hop in the probe trajectory")


func test_fielder_speed_is_bounded() -> void:
	var t := tuning()
	# A fielder 30 m away cannot catch a ball that lands in 1.5 s.
	var probe := _sim(Vector3(-16.0, 0.0, 9.0))
	var land := probe.ball_pos_at(probe.first_bounce_t - 0.02)
	var far := _fielder(Vector2(land.x, land.y + 30.0), t)
	var s := _sim(Vector3(-16.0, 0.0, 9.0), [far])
	check(s.outcome != ShotResult.CAUGHT, "no teleporting catches")
	if s.collector >= 0:
		var needed := far.pos.distance_to(Vector2(s.collect_pos.x, s.collect_pos.y)) - t.stop_reach
		check(needed <= far.speed * maxf(0.0, s.t_collect - far.reaction) + 0.05, "collector respected max speed")


func test_catch_beats_boundary_only_inside_rope() -> void:
	var t := tuning()
	# A fielder standing just inside the rope under a flat six-bound ball catches it
	# if the ball is catchable height there; otherwise it is six.
	var high := _sim(Vector3(-24.0, 0.0, 16.0))
	var f := _fielder(Vector2(-40.0, 0.0), t)
	var s := _sim(Vector3(-24.0, 0.0, 16.0), [f])
	var p := high.ball_pos_at(high.boundary_t * 0.95)
	if p.z > t.catch_max_height:
		eq(s.outcome, ShotResult.SIX, "too high to catch -> six")


func test_running_model_dot_single_double_triple() -> void:
	var t := tuning()
	# Runs are decided by when the ball can be returned; verify each band exists and
	# matches the documented formula.
	var results := {}
	for spd in [4.0, 8.0, 12.0, 15.0, 18.0, 21.0, 24.0]:
		for fx in [-10.0, -18.0, -26.0, -34.0]:
			var f := _fielder(Vector2(fx, 14.0), t)
			var s := _sim(Vector3(-spd * 0.7, spd * 0.7, 0.3), [f])
			if s.outcome == ShotResult.RUNS:
				results[s.runs] = true
				var expected := 0
				for k in range(1, t.max_runs + 1):
					if t.first_run_time + (k - 1) * t.next_run_time + t.run_safety <= s.t_back:
						expected = k
				eq(s.runs, expected, "runs follow the return time")
				check(s.runs <= t.max_runs, "never more than max runs")
	check(results.has(0), "dot possible")
	check(results.has(1), "single possible")
	check(results.has(2) or results.has(3), "twos/threes possible")


func test_shot_sim_is_deterministic() -> void:
	var a := _sim(Vector3(-20.0, 5.0, 6.0), [_fielder(Vector2(-20, 8), tuning())])
	var b := _sim(Vector3(-20.0, 5.0, 6.0), [_fielder(Vector2(-20, 8), tuning())])
	eq(a.samples, b.samples, "identical trajectories")
	eq(a.outcome, b.outcome)
	eq(a.runs, b.runs)


func test_resolver_consistency_many_balls() -> void:
	# Every resolved ball has exactly one outcome consistent with its trajectory.
	var t := tuning()
	var v := venue()
	var fl := field(t)
	var n := 0
	for bid in ["daniyal", "hamza", "saad"]:
		for s in 60:
			var d := DeliveryGenerator.generate(bowler(bid), s * 13 + 5, t, 0.5)
			for off in [-120.0, -50.0, -15.0, 0.0, 20.0, 60.0, 200.0]:
				var r := BallResolver.resolve(d, swing_for(d, t, off), s % 3, fl, v, t)
				var o := r.outcome
				n += 1
				match o.kind:
					BallOutcome.BOWLED:
						check(not r.contact.is_contact() and d.hits_stumps(), "bowled only when unplayed ball hits stumps")
						check(o.wicket and o.runs == 0, "bowled scores nothing")
					BallOutcome.CAUGHT:
						check(r.shot.t_collect < r.shot.first_bounce_t, "caught before bounce")
						check(o.runs == 0 and o.wicket, "no runs on a catch")
					BallOutcome.SIX:
						check(r.shot.first_bounce_t > r.shot.boundary_t, "six never bounced")
						eq(o.runs, 6)
					BallOutcome.FOUR:
						check(r.shot.first_bounce_t < r.shot.boundary_t, "four bounced first")
						eq(o.runs, 4)
					BallOutcome.RUNS, BallOutcome.DOT:
						check(not o.wicket, "no wicket with runs")
						check(o.runs >= 0 and o.runs <= t.max_runs, "runs in range")
						if not r.contact.is_contact():
							check(not d.hits_stumps(), "unplayed dot ball missed the stumps")
	check(n > 1000, "exercised many balls")

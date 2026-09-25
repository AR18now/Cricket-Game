class_name ShotSim
extends RefCounted
## Deterministic fixed-step flight + fielding resolution for a struck ball.
## Rules implemented (see GAME_RULES.md):
##  * SIX  - crosses the rope without touching the ground after the shot.
##  * FOUR - reaches the rope after touching the ground.
##  * CAUGHT - a fielder reaches the ball (within reach, catchable height) before its
##    first bounce, inside the boundary, respecting reaction delay and max speed.
##  * Runs - automatic running: batters complete only runs that finish before the ball
##    can be returned to the stumps (plus a safety margin). Maximum 3.


static func simulate(contact: ContactResult, fielders: Array, venue: VenueConfig, tuning: GameTuning) -> ShotResult:
	var res := ShotResult.new()
	res.dt = 1.0 / tuning.sim_hz
	var dt := res.dt
	var pos := contact.contact_pos
	var vel := contact.launch_vel
	var bounced := false
	var rolling := false
	var t := 0.0
	var crossed := false
	res.samples.append(pos)
	var steps := int(tuning.max_shot_time / dt)
	for i in steps:
		# Integrate one fixed step.
		if rolling:
			var h := Vector2(vel.x, vel.y)
			var sp := h.length()
			sp = maxf(0.0, sp - venue.roll_decel * dt)
			h = h.normalized() * sp if sp > 0.0 else Vector2.ZERO
			vel = Vector3(h.x, h.y, 0.0)
			pos += vel * dt
		else:
			var spd := vel.length()
			vel -= vel * (tuning.air_drag * spd * dt)
			vel.z -= tuning.gravity * dt
			pos += vel * dt
			if pos.z <= 0.0:
				pos.z = 0.0
				if not bounced:
					bounced = true
					res.first_bounce_t = t + dt
					res.carry = Vector2(pos.x, pos.y).length()
				vel = Vector3(vel.x * tuning.bounce_friction, vel.y * tuning.bounce_friction, -vel.z * tuning.ground_restitution)
				if vel.z < 1.2:
					vel.z = 0.0
					rolling = true
		t += dt
		res.samples.append(pos)
		res.max_height = maxf(res.max_height, pos.z)
		if not venue.is_inside(Vector2(pos.x, pos.y)):
			crossed = true
			res.boundary_t = t
			res.outcome = ShotResult.FOUR if bounced else ShotResult.SIX
			if not bounced:
				res.carry = Vector2(pos.x, pos.y).length()
			break
		if rolling and Vector2(vel.x, vel.y).length() < tuning.stop_speed:
			break
	_resolve_fielding(res, fielders, venue, tuning, crossed)
	return res


static func _reach_time(f: FielderSpec, target: Vector2, reach: float) -> float:
	var d := maxf(0.0, f.pos.distance_to(target) - reach)
	return f.reaction + d / f.speed


static func _resolve_fielding(res: ShotResult, fielders: Array, venue: VenueConfig, tuning: GameTuning, crossed: bool) -> void:
	var dt := res.dt
	var n := res.samples.size()
	var best_i := -1
	var best_f := -1
	var best_catch := false
	# Earliest legal interception across every fielder (catch before first bounce, else stop).
	for i in n:
		var t := i * dt
		if t < 0.08:
			continue
		var p: Vector3 = res.samples[i]
		var plan := Vector2(p.x, p.y)
		var airborne := t < res.first_bounce_t
		var catchable := airborne and p.z >= tuning.catch_min_height and p.z <= tuning.catch_max_height
		var stoppable := p.z <= tuning.stop_max_height
		if not catchable and not stoppable:
			continue
		for fi in fielders.size():
			var f: FielderSpec = fielders[fi]
			var reach := tuning.catch_reach if catchable else tuning.stop_reach
			var avail := f.speed * maxf(0.0, t - f.reaction)
			if f.pos.distance_to(plan) <= reach + avail:
				best_i = i
				best_f = fi
				best_catch = catchable
				break
		if best_i >= 0:
			break
	if best_i < 0 and crossed:
		res.runs = 4 if res.outcome == ShotResult.FOUR else 6
		res.t_settle = res.boundary_t + 0.9
		res.distance = Vector2(res.samples[n - 1].x, res.samples[n - 1].y).length()
		_chase_plans(res, fielders, res.samples[n - 1], -1, res.boundary_t)
		return
	var t_collect := 0.0
	var collect_p := Vector3.ZERO
	if best_i >= 0:
		t_collect = best_i * dt
		collect_p = res.samples[best_i]
	else:
		# Ball stopped inside the field untouched: nearest fielder walks/runs to it.
		collect_p = res.samples[n - 1]
		var t_stop := (n - 1) * dt
		var best_t := INF
		for fi in fielders.size():
			var tt := maxf(t_stop, _reach_time(fielders[fi], Vector2(collect_p.x, collect_p.y), tuning.stop_reach))
			if tt < best_t:
				best_t = tt
				best_f = fi
		t_collect = best_t
	res.collector = best_f
	res.t_collect = t_collect
	res.collect_pos = collect_p
	res.distance = Vector2(collect_p.x, collect_p.y).length()
	if best_catch:
		res.outcome = ShotResult.CAUGHT
		res.runs = 0
		res.t_settle = t_collect + 1.1
		_chase_plans(res, fielders, collect_p, best_f, t_collect)
		return
	res.outcome = ShotResult.RUNS
	var plan_c := Vector2(collect_p.x, collect_p.y)
	var keeper_end := Vector2(0.0, 0.0)
	var bowler_end := Vector2(Delivery.BOWLING_STUMPS_X, 0.0)
	res.throw_to = keeper_end if plan_c.distance_to(keeper_end) <= plan_c.distance_to(bowler_end) else bowler_end
	res.t_back = t_collect + tuning.pickup_time + plan_c.distance_to(res.throw_to) / tuning.throw_speed
	var runs := 0
	for k in range(1, tuning.max_runs + 1):
		var done := tuning.first_run_time + (k - 1) * tuning.next_run_time
		if done + tuning.run_safety <= res.t_back:
			runs = k
			res.run_times.append(done)
	res.runs = runs
	res.t_settle = maxf(res.t_back, res.run_times[runs - 1] if runs > 0 else 0.0) + 0.4
	_chase_plans(res, fielders, collect_p, best_f, t_collect)


## Movement plans for rendering: the collector runs to the interception point; the
## nearest other fielder backs up at bounded speed. Nobody moves before reacting.
static func _chase_plans(res: ShotResult, fielders: Array, target: Vector3, collector: int, t_end: float) -> void:
	res.fielder_targets.clear()
	var tp := Vector2(target.x, target.y)
	var backup := -1
	var backup_d := INF
	for fi in fielders.size():
		var f: FielderSpec = fielders[fi]
		if fi != collector and f.role != "keeper":
			var d := f.pos.distance_to(tp)
			if d < backup_d:
				backup_d = d
				backup = fi
	for fi in fielders.size():
		var f: FielderSpec = fielders[fi]
		var plan := {"target": f.pos, "t_start": f.reaction, "arrive": f.reaction}
		if fi == collector or fi == backup:
			var goal := tp
			if fi == backup:
				goal = f.pos.lerp(tp, 0.6)
			var dist := f.pos.distance_to(goal)
			var reach := 1.0 if fi == collector else 0.0
			var travel := maxf(0.0, dist - reach)
			var max_travel := f.speed * maxf(0.0, t_end - f.reaction) if fi == collector else travel
			travel = minf(travel, max_travel) if fi == collector else travel
			var dir := (goal - f.pos).normalized() if dist > 0.001 else Vector2.ZERO
			plan["target"] = f.pos + dir * travel
			plan["arrive"] = f.reaction + travel / f.speed
		res.fielder_targets.append(plan)

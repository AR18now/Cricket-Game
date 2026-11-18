class_name BallResolver
extends RefCounted
## Resolves a full delivery (swing or no swing) into exactly one BallOutcome.
## Pure logic: used identically by gameplay, replays and headless tests.

var delivery: Delivery
var contact: ContactResult
var shot: ShotResult   # null when there was no contact
var outcome: BallOutcome


## `safe`: beginner help - a perfect hit clears the rope; any other contact is kept on
## the ground.
static func resolve(d: Delivery, swing_time: float, stance: int, fielders: Array,
		venue: VenueConfig, tuning: GameTuning, window_scale: float = 1.0, safe: bool = false) -> BallResolver:
	var r := BallResolver.new()
	r.delivery = d
	r.contact = ContactResolver.resolve(d, swing_time, stance, tuning, window_scale)
	if safe and r.contact.is_contact():
		if r.contact.category == ContactResult.PERFECT:
			# Beginner help: a perfectly timed hit is rewarded - it clears the rope.
			r.shot = _force_boundary(r.contact, true, fielders, venue, tuning)
			return _finish(r, fielders)
		# Anything less than perfect stays on the ground (no easy catches).
		r.contact = ContactResolver.resolve(d, swing_time, ContactResult.Stance.GROUNDED, tuning, window_scale)
		if r.contact.category == ContactResult.EDGE:
			# An edge is angled down into the ground, so it can't carry to the keeper.
			var c := r.contact
			var a := deg_to_rad(c.angle_deg)
			var e := deg_to_rad(-28.0)
			c.elevation_deg = -28.0
			c.launch_vel = Vector3(-cos(a) * cos(e) * c.exit_speed, sin(a) * cos(e) * c.exit_speed, sin(e) * c.exit_speed)
	if r.contact.is_contact():
		r.shot = ShotSim.simulate(r.contact, fielders, venue, tuning)
	return _finish(r, fielders)


## Tutorial (first six balls of the first match): any swing that meets the ball goes for
## FOUR (or SIX when the timing is good), so new players learn the tap with a big reward.
## The batter swings at the player's tap; only the launch is chosen so the ball finds
## the rope (searching a few directions/heights deterministically). No swing = the ball
## passes outside off stump (never out).
static func resolve_tutorial(d: Delivery, swing_time: float, fielders: Array,
		venue: VenueConfig, tuning: GameTuning) -> BallResolver:
	var r := BallResolver.new()
	r.delivery = d
	if swing_time >= 0.0:
		swing_time = tutorial_swing_time(d, swing_time, tuning)
	r.contact = ContactResolver.resolve(d, swing_time, ContactResult.Stance.AUTO, tuning, tuning.tutorial_window_scale * 1.4)
	if r.contact.is_contact():
		var want_six := r.contact.category in [ContactResult.PERFECT, ContactResult.GOOD]
		r.shot = _force_boundary(r.contact, want_six, fielders, venue, tuning)
	return _finish(r, fielders)


## Tutorial help: an early tap is held until just before the ideal moment, so the bat
## still meets the ball (the swing starts a little later than the tap).
static func tutorial_swing_time(d: Delivery, tap_time: float, tuning: GameTuning) -> float:
	var ideal := d.time_at_x(tuning.contact_x_ideal) - tuning.swing_to_contact
	return maxf(tap_time, ideal - 0.06)


static func _force_boundary(c: ContactResult, want_six: bool, fielders: Array, venue: VenueConfig, tuning: GameTuning) -> ShotResult:
	var base_angle := clampf(c.angle_deg, -70.0, 70.0) if c.category != ContactResult.EDGE else c.angle_deg
	var offsets := [0.0, 8.0, -8.0, 16.0, -16.0, 24.0, -24.0, 34.0, -34.0, 45.0, -45.0]
	var tries: Array = []   # [elevation deg, speed m/s, want]
	if want_six:
		for e in [33.0, 38.0, 29.0, 43.0]:
			tries.append([e, 31.0, ShotResult.SIX])
	for e in [3.0, 5.0, 8.0]:
		tries.append([e, 33.0, ShotResult.FOUR])
	if not want_six:
		for e in [33.0, 38.0]:
			tries.append([e, 31.0, ShotResult.SIX])
	var fallback: ShotResult = null
	for tr in tries:
		for off in offsets:
			var a := deg_to_rad(base_angle + float(off))
			var e_rad := deg_to_rad(float(tr[0]))
			var sp: float = tr[1]
			c.angle_deg = rad_to_deg(a)
			c.elevation_deg = tr[0]
			c.exit_speed = sp
			c.launch_vel = Vector3(-cos(a) * cos(e_rad) * sp, sin(a) * cos(e_rad) * sp, sin(e_rad) * sp)
			var shot := ShotSim.simulate(c, fielders, venue, tuning)
			if shot.outcome == tr[2]:
				return shot
			if fallback == null and shot.is_boundary():
				fallback = shot
	return fallback if fallback != null else ShotSim.simulate(c, fielders, venue, tuning)


static func _finish(r: BallResolver, fielders: Array) -> BallResolver:
	var d := r.delivery
	var o := BallOutcome.new()
	o.timing = r.contact.category
	o.dt_ms = r.contact.dt_ms
	o.delivery_kind = d.kind
	o.speed_kmh = d.speed_kmh()
	if r.contact.is_contact():
		o.angle_deg = r.contact.angle_deg
		o.distance = r.shot.distance
		o.max_height = r.shot.max_height
		o.t_settle = r.contact.t_contact + r.shot.t_settle
		var end_t := r.shot.boundary_t if r.shot.is_boundary() else r.shot.t_collect
		var steps := 8
		for k in steps + 1:
			var p := r.shot.ball_pos_at(end_t * float(k) / steps)
			o.shot_points.append(Vector2(p.x, p.y))
		match r.shot.outcome:
			ShotResult.SIX:
				o.kind = BallOutcome.SIX
				o.runs = 6
				o.explanation = "Cleared the rope on the full"
			ShotResult.FOUR:
				o.kind = BallOutcome.FOUR
				o.runs = 4
				o.explanation = "Raced to the rope along the ground" if r.shot.first_bounce_t < 1.0 else "Bounced before the rope"
			ShotResult.CAUGHT:
				var f: FielderSpec = fielders[r.shot.collector]
				o.kind = BallOutcome.CAUGHT
				o.wicket = true
				o.fielder_name = f.name
				o.fielder_position = f.position_name
				o.explanation = "Caught at %s before the ball touched the ground (%.1f m high)" % [
					f.position_name, r.shot.collect_pos.z]
			_:
				o.runs = r.shot.runs
				o.kind = BallOutcome.RUNS if o.runs > 0 else BallOutcome.DOT
				var f2: FielderSpec = fielders[r.shot.collector]
				o.fielder_name = f2.name
				o.fielder_position = f2.position_name
				if o.runs == 0:
					o.explanation = "%s cut it off quickly - no safe run" % f2.position_name.capitalize()
				else:
					o.explanation = "Fielded at %s - %d safe run%s" % [f2.position_name, o.runs, "" if o.runs == 1 else "s"]
	else:
		var t_st := d.stumps_time()
		o.t_settle = t_st + 0.6
		if d.hits_stumps():
			o.kind = BallOutcome.BOWLED
			o.wicket = true
			match r.contact.category:
				ContactResult.MISS_EARLY:
					o.explanation = "Bowled! Swung %d ms too early - the ball hit the stumps" % int(absf(o.dt_ms))
				ContactResult.MISS_LATE:
					o.explanation = "Bowled! Swung %d ms too late - the ball hit the stumps" % int(absf(o.dt_ms))
				_:
					o.explanation = "Bowled! No shot offered and the ball hit the stumps"
		else:
			o.kind = BallOutcome.DOT
			var side := "off stump" if d.pos_at(t_st).y > 0.0 else "leg stump"
			if d.pos_at(t_st).z > Delivery.STUMPS_HEIGHT:
				side = "the bails"
			o.explanation = "Missed - the ball passed over %s" % side if side == "the bails" else "Missed - the ball passed outside %s" % side
	r.outcome = o
	return r

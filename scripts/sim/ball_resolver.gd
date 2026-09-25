class_name BallResolver
extends RefCounted
## Resolves a full delivery (swing or no swing) into exactly one BallOutcome.
## Pure logic: used identically by gameplay, replays and headless tests.

var delivery: Delivery
var contact: ContactResult
var shot: ShotResult   # null when there was no contact
var outcome: BallOutcome


static func resolve(d: Delivery, swing_time: float, stance: int, fielders: Array,
		venue: VenueConfig, tuning: GameTuning, window_scale: float = 1.0) -> BallResolver:
	var r := BallResolver.new()
	r.delivery = d
	r.contact = ContactResolver.resolve(d, swing_time, stance, tuning, window_scale)
	var o := BallOutcome.new()
	o.timing = r.contact.category
	o.dt_ms = r.contact.dt_ms
	o.delivery_kind = d.kind
	o.speed_kmh = d.speed_kmh()
	if r.contact.is_contact():
		r.shot = ShotSim.simulate(r.contact, fielders, venue, tuning)
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
				o.explanation = "Caught by %s at %s before the ball touched the ground (%.1f m high)" % [
					f.name, f.position_name, r.shot.collect_pos.z]
			_:
				o.runs = r.shot.runs
				o.kind = BallOutcome.RUNS if o.runs > 0 else BallOutcome.DOT
				var f2: FielderSpec = fielders[r.shot.collector]
				o.fielder_name = f2.name
				o.fielder_position = f2.position_name
				if o.runs == 0:
					o.explanation = "%s (%s) cut it off quickly - no safe run" % [f2.name, f2.position_name]
				else:
					o.explanation = "%s (%s) fielded it - %d safe run%s" % [f2.name, f2.position_name, o.runs, "" if o.runs == 1 else "s"]
	else:
		var t_st := d.stumps_time()
		o.t_settle = t_st + 0.9
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

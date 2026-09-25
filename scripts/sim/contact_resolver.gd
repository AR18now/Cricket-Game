class_name ContactResolver
extends RefCounted
## Timing -> contact. Contact happens exactly where the analytic ball is when the bat
## arrives, so the drawn path and the recorded result always agree.


## Earliest sim time at which a tap is accepted as a swing (earlier taps are ignored).
static func window_open_time(d: Delivery, tuning: GameTuning) -> float:
	return maxf(0.0, d.time_at_x(tuning.contact_x_ideal) - tuning.swing_to_contact - tuning.batting_window_lead)


## Latest sim time at which a tap can still produce contact.
static func window_close_time(d: Delivery, tuning: GameTuning) -> float:
	return d.time_at_x(tuning.contact_x_edge) - tuning.swing_to_contact


static func resolve(d: Delivery, swing_time: float, stance: int, tuning: GameTuning,
		window_scale: float = 1.0) -> ContactResult:
	var r := ContactResult.new()
	r.stance = stance
	r.t_swing = swing_time
	if swing_time < 0.0:
		r.category = ContactResult.NONE
		return r
	r.swung = true
	var t_ideal := d.time_at_x(tuning.contact_x_ideal)
	var t_early := d.time_at_x(tuning.contact_x_early)
	var t_late := d.time_at_x(tuning.contact_x_late)
	var t_edge := d.time_at_x(tuning.contact_x_edge)
	var t_bat := swing_time + tuning.swing_to_contact
	var dt := t_bat - t_ideal
	r.dt_ms = dt * 1000.0
	r.t_contact = t_bat
	if t_bat < t_early:
		r.category = ContactResult.MISS_EARLY
		return r
	if t_bat > t_edge:
		r.category = ContactResult.MISS_LATE
		return r
	var ball := d.pos_at(t_bat)
	if ball.z > tuning.bat_reach_height:
		r.category = ContactResult.MISS_LATE if dt > 0.0 else ContactResult.MISS_EARLY
		return r
	r.contact_pos = ball
	var early_span := t_ideal - t_early
	var late_span := t_late - t_ideal
	var perfect_w := minf(tuning.perfect_ms * window_scale / 1000.0, 0.5 * minf(early_span, late_span))
	var good_w := minf(tuning.good_ms * window_scale / 1000.0, 0.8 * minf(early_span, late_span))
	if t_bat > t_late:
		r.category = ContactResult.EDGE
	elif absf(dt) <= perfect_w:
		r.category = ContactResult.PERFECT
	elif absf(dt) <= good_w:
		r.category = ContactResult.GOOD
	elif dt < 0.0:
		r.category = ContactResult.EARLY
	else:
		r.category = ContactResult.LATE
	_launch(r, d, dt, early_span, late_span, t_late, t_edge, tuning, window_scale)
	return r


static func _launch(r: ContactResult, d: Delivery, dt: float, early_span: float, late_span: float,
		t_late: float, t_edge: float, tuning: GameTuning, window_scale: float) -> void:
	var rng := DetRng.new(DetRng.derive(d.seed, int(round(r.dt_ms * 10.0)), 0x51A7))
	var cat := r.category
	var angle := 0.0
	if cat == ContactResult.EDGE:
		# Thin edge behind square on the off side: thicker (earlier) edges go squarer.
		var e := clampf((r.t_contact - t_late) / maxf(t_edge - t_late, 0.001), 0.0, 1.0)
		angle = lerpf(128.0, 172.0, e)
	else:
		# Perfect timing goes back down the "V"; later/earlier timing opens the face /
		# closes it progressively towards square on the off / leg side.
		var span := early_span if dt < 0.0 else late_span
		var pw := minf(tuning.perfect_ms * window_scale / 1000.0, 0.5 * minf(early_span, late_span))
		var mag := absf(dt)
		if mag <= pw:
			angle = dt / pw * tuning.perfect_direction_deg
		else:
			var u := clampf((mag - pw) / maxf(span - pw, 0.001), 0.0, 1.0)
			angle = signf(dt) * lerpf(tuning.perfect_direction_deg, tuning.max_direction_deg, u)
		angle += r.contact_pos.y * tuning.line_direction_deg_per_m
		angle += rng.range_f(-tuning.direction_jitter_deg, tuning.direction_jitter_deg)
	var elev_table: Dictionary = tuning.elevation_auto
	if r.stance == ContactResult.Stance.GROUNDED:
		elev_table = tuning.elevation_grounded
	elif r.stance == ContactResult.Stance.LOFTED:
		elev_table = tuning.elevation_lofted
	var elev: float = elev_table.get(cat, 5.0)
	if r.stance != ContactResult.Stance.GROUNDED:
		elev += (r.contact_pos.z - 0.5) * tuning.elevation_per_contact_height
	elev += rng.range_f(-tuning.elevation_jitter_deg, tuning.elevation_jitter_deg)
	elev = clampf(elev, 0.5, 55.0)
	var incoming := d.vel_at(r.t_contact)
	var sf: float = tuning.speed_factor.get(cat, 0.5)
	var exit := tuning.exit_speed_base * sf + Vector2(incoming.x, incoming.y).length() * tuning.exit_speed_incoming_factor
	r.angle_deg = angle
	r.elevation_deg = elev
	r.exit_speed = exit
	var a := deg_to_rad(angle)
	var e_rad := deg_to_rad(elev)
	r.launch_vel = Vector3(-cos(a) * cos(e_rad) * exit, sin(a) * cos(e_rad) * exit, sin(e_rad) * exit)

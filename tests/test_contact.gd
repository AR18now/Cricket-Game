extends TestCase


func _d() -> Delivery:
	var d := Delivery.new()
	d.speed = 20.0
	d.length = 5.0
	d.line_y = 0.0
	d.release = Vector3(-18.7, 0.3, 2.05)
	return d.build()


func test_categories_at_boundaries() -> void:
	var t := tuning()
	var d := _d()
	var ideal := d.time_at_x(t.contact_x_ideal)
	var early_span := ideal - d.time_at_x(t.contact_x_early)
	var late_span := d.time_at_x(t.contact_x_late) - ideal
	var pw := minf(t.perfect_ms / 1000.0, 0.5 * minf(early_span, late_span))
	var gw := minf(t.good_ms / 1000.0, 0.8 * minf(early_span, late_span))
	var cases := [
		[0.0, ContactResult.PERFECT], [pw * 1000.0 - 0.5, ContactResult.PERFECT], [-(pw * 1000.0 - 0.5), ContactResult.PERFECT],
		[pw * 1000.0 + 0.5, ContactResult.GOOD], [gw * 1000.0 - 0.5, ContactResult.GOOD], [-(gw * 1000.0 - 0.5), ContactResult.GOOD],
		[-(gw * 1000.0 + 0.5), ContactResult.EARLY], [gw * 1000.0 + 0.5, ContactResult.LATE],
		[-(early_span * 1000.0 - 0.5), ContactResult.EARLY], [-(early_span * 1000.0 + 0.5), ContactResult.MISS_EARLY],
		[late_span * 1000.0 - 0.5, ContactResult.LATE], [late_span * 1000.0 + 0.5, ContactResult.EDGE],
	]
	for c in cases:
		var r := ContactResolver.resolve(d, swing_for(d, t, c[0]), 0, t)
		eq(r.category, c[1], "dt=%.1f" % c[0])
	var t_edge := d.time_at_x(t.contact_x_edge)
	var beyond := (t_edge - ideal) * 1000.0 + 0.5
	eq(ContactResolver.resolve(d, swing_for(d, t, beyond), 0, t).category, ContactResult.MISS_LATE, "past the edge window")


func test_no_swing_is_none() -> void:
	var r := ContactResolver.resolve(_d(), -1.0, 0, tuning())
	eq(r.category, ContactResult.NONE)
	check(not r.swung, "no swing")


func test_contact_happens_where_ball_is() -> void:
	var t := tuning()
	var d := _d()
	for off in [-60.0, -20.0, 0.0, 15.0, 40.0]:
		var r := ContactResolver.resolve(d, swing_for(d, t, off), 0, t)
		if r.is_contact():
			check(r.contact_pos.distance_to(d.pos_at(r.t_contact)) < 1e-4, "contact point on the drawn path (off=%.0f)" % off)


func test_direction_follows_timing() -> void:
	var t := tuning()
	var d := _d()
	var early := ContactResolver.resolve(d, swing_for(d, t, -45.0), 0, t)
	var late := ContactResolver.resolve(d, swing_for(d, t, 45.0), 0, t)
	var perfect := ContactResolver.resolve(d, swing_for(d, t, 0.0), 0, t)
	check(early.angle_deg < -10.0, "early goes to the leg side (%.1f)" % early.angle_deg)
	check(late.angle_deg > 10.0, "late goes to the off side (%.1f)" % late.angle_deg)
	check(absf(perfect.angle_deg) <= t.perfect_direction_deg + t.direction_jitter_deg + 1.0, "perfect goes straight (%.1f)" % perfect.angle_deg)


func test_stance_changes_elevation() -> void:
	var t := tuning()
	var d := _d()
	var g := ContactResolver.resolve(d, swing_for(d, t, 0.0), ContactResult.Stance.GROUNDED, t)
	var l := ContactResolver.resolve(d, swing_for(d, t, 0.0), ContactResult.Stance.LOFTED, t)
	check(g.elevation_deg < 6.0, "grounded stays low")
	check(l.elevation_deg > g.elevation_deg + 15.0, "lofted goes up")


func test_windows_do_not_depend_on_difficulty_or_bowler_identity() -> void:
	# Fairness: identical delivery geometry -> identical windows regardless of match state.
	var t := tuning()
	var a := _d()
	var b := _d()
	b.bowler_id = "hamza"
	b.seed = 999
	eq(ContactResolver.window_open_time(a, t), ContactResolver.window_open_time(b, t))
	eq(ContactResolver.window_close_time(a, t), ContactResolver.window_close_time(b, t))


func test_window_open_before_ideal_tap() -> void:
	var t := tuning()
	var d := _d()
	var ideal_tap := d.time_at_x(t.contact_x_ideal) - t.swing_to_contact
	check(ContactResolver.window_open_time(d, t) < ideal_tap, "window opens before the ideal tap")
	check(ContactResolver.window_close_time(d, t) > ideal_tap, "window closes after the ideal tap")

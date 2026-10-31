extends Node
## DEVELOPMENT ONLY (excluded from release exports; only loaded in debug builds).
## Drives the real game through injected input events, captures screenshots of the
## running build and asserts on state. Usage (needs a display, e.g. xvfb-run):
##   godot --path . -- --harness=capture --out=/abs/dir
##   godot --path . -- --harness=smoke

var app
var out_dir := "user://captures"
var mode := "capture"
var failures: Array = []
var log_lines: Array = []


func run(main_node) -> void:
	app = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--harness="):
			mode = a.substr(10)
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Isolate the harness from any real player save.
	var save = get_node("/root/Save")
	save.configure(OS.get_user_data_dir() + "/harness_save")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/harness_save")
	save.data = save.defaults()
	if "--portrait" in OS.get_cmdline_user_args():
		save.data["settings"]["orientation"] = "portrait"
	save.save()
	app._apply_settings()
	app.controller.swing_feedback.connect(func(r): _log("swing_feedback=" + r + " t=" + str(app.controller.clock.time)))
	# Slow the game down so frame-quantised waits can place real input events precisely
	# (software rendering in CI/containers runs at a low frame rate).
	Engine.time_scale = 0.2
	call_deferred("_go")


func _go() -> void:
	match mode:
		"smoke":
			await _smoke()
		"quick":
			await _quick_tour()
		"visual":
			await _visual_tour()
		"feel":
			await _feel_tour()
		"approach":
			await _approach_shots()
		"restart":
			await _restart_check()
		"hints":
			await _hints_check()
		"look":
			await _look_tour()
		"batter":
			await _batter_sheet()
		"screens":
			await _screens_tour()
		"perf":
			await _perf()
		"themes":
			await _themes_tour()
		"milestone":
			await _milestone_check()
		"store":
			await _store_shots()
		_:
			await _capture_tour()
	_finish()


func _log(s: String) -> void:
	print("[harness] ", s)
	log_lines.append(s)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		_log("FAIL: " + msg)
	else:
		_log("ok: " + msg)


func _finish() -> void:
	var f := FileAccess.open(out_dir + "/harness_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.close()
	_log("DONE failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func eq(a, b, msg: String) -> void:
	check(a == b, "%s (got %s)" % [msg, str(a)])


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, false).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out_dir + "/" + name + ".png"
	img.save_png(p)
	_log("screenshot " + p)


func press_space() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func tap_at(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


## Waits until the controller clock reaches t (sim seconds) for the current delivery.
func until_clock(t: float, timeout: float = 8.0) -> void:
	var start := Time.get_ticks_msec()
	while app.controller.clock.time < t and Time.get_ticks_msec() - start < timeout * 1000.0 / Engine.time_scale:
		await get_tree().process_frame


## Injects a real Space key event so that it is timestamped at sim time `t`.
func swing_at(t: float) -> void:
	var c = app.controller
	await until_clock(t - 0.06)
	var sc: float = Engine.time_scale * c._clock_speed
	var now_t: float = c.clock.time_of_input(Time.get_ticks_usec(), sc)
	var need_us := (t - now_t) / sc * 1000000.0
	if need_us > 0.0:
		OS.delay_usec(int(need_us))
	press_space()
	Input.flush_buffered_events()


func until_phase(p: int, timeout: float = 12.0) -> void:
	var start := Time.get_ticks_msec()
	while app.controller.phase != p and Time.get_ticks_msec() - start < timeout * 1000.0 / Engine.time_scale:
		await get_tree().process_frame


func ideal_swing() -> float:
	var c = app.controller
	return c.delivery.time_at_x(c.tuning.contact_x_ideal) - c.tuning.swing_to_contact


## Plays one delivery, swinging `offset_ms` after the ideal tap (NAN = no swing).
func play_ball(offset_ms: float, capture_prefix: String = "") -> BallOutcome:
	var c = app.controller
	await until_phase(MatchController.Phase.RUNUP)
	if capture_prefix != "":
		await until_clock(-0.25)
		await shot(capture_prefix + "_runup")
	if not is_nan(offset_ms):
		await swing_at(ideal_swing() + offset_ms / 1000.0)
		await frames(1)
		var fo = get_viewport().gui_get_focus_owner()
		_log("swing registered=%s focus=%s" % [str(c.gate.swing_time), str(fo)])
		# Rapid extra taps must be ignored (one swing per delivery).
		await frames(1)
		press_space()
		press_space()
	if capture_prefix != "" and not is_nan(offset_ms):
		await until_clock(ideal_swing() + 0.3)
		await shot(capture_prefix + "_contact")
		await until_clock(ideal_swing() + 1.1)
		await shot(capture_prefix + "_flight")
	await until_phase(MatchController.Phase.OUTCOME)
	if capture_prefix != "":
		await wait(0.3)
		await shot(capture_prefix + "_outcome")
	var o: BallOutcome = c.resolver.outcome
	_log("ball: swing=%s timing=%s dt=%.1fms -> %s (%d) : %s" % [str(offset_ms), o.timing, o.dt_ms, o.kind, o.runs, o.explanation])
	return o


func _capture_tour() -> void:
	await wait(1.6)
	check(app.screen == app.Screen.MENU, "menu shown after identity mark")
	await shot("01_menu")
	# First launch: PLAY starts the tutorial nets.
	app.menu.play_btn.pressed.emit()
	await frames(2)
	check(app.screen == app.Screen.TUTORIAL, "first PLAY starts tutorial")
	await wait(0.4)
	await shot("02_tutorial_ready")
	var c = app.controller
	await until_phase(MatchController.Phase.FLIGHT)
	await until_clock(ideal_swing() - 0.25)
	await shot("03_tutorial_ring")
	var n_before: int = c.gate.ignored
	var o := await play_ball(0.0, "04_tutorial")
	check(c.gate.ignored >= n_before + 2, "rapid extra taps ignored")
	check(o.timing != ContactResult.NONE, "injected Space produced a swing")
	# Skip through remaining tutorial balls with good timing.
	for i in 3:
		if app.screen != app.Screen.TUTORIAL:
			break
		await play_ball(5.0)
		press_space()
	await wait(2.0)
	# First challenge begins with a rule card.
	check(app.screen == app.Screen.MATCH, "tutorial leads to the first challenge")
	await shot("05_rule_card")
	app._close_overlay()
	# Quick match chase: start directly to capture the HUD.
	app.start_mode("quick")
	await wait(0.2)
	app._close_overlay()
	await play_ball(0.0, "06_quick")
	press_space()
	await play_ball(40.0, "07_quick")
	press_space()
	await play_ball(-55.0, "08_quick")
	await wait(0.2)
	await shot("09_chase_hud")
	app.open_pause()
	await frames(3)
	await shot("10_pause")
	app.open_settings()
	await frames(3)
	await shot("11_settings")
	app._close_overlay()
	await frames(2)
	app.open_scorecard()
	await frames(3)
	await shot("12_scorecard")
	app._close_overlay()
	# Endless: play until dismissed -> final result screen.
	app.start_mode("endless")
	await wait(0.2)
	app._close_overlay()
	for i in 12:
		if app.screen != app.Screen.MATCH:
			break
		var off: float = [0.0, 30.0, NAN, -200.0][i % 4]
		await play_ball(off)
		press_space()
	await wait(2.5)
	await shot("13_result")
	check(app.screen == app.Screen.RESULT, "endless ends on a wicket and shows the result")


## Game-time seconds (real time scaled by the harness slow-down).
func game_now() -> float:
	return Time.get_ticks_msec() / 1000.0 * Engine.time_scale


func _feel_tour() -> void:
	await wait(1.6)
	app.start_mode("classic")
	var c = app.controller
	var starts: Array = []
	c.delivery_started.connect(func(_i): starts.append(game_now()))
	c.phase_changed.connect(func(ph): _log("  phase %s at %.2f (clock %.2f)" % [MatchController.Phase.keys()[ph], game_now(), c.clock.time]))
	c.timing_revealed.connect(func(_x): _log("  reveal at %.2f (clock %.2f) settle_t=%.2f" % [game_now(), c.clock.time, c.resolver.outcome.t_settle]))
	await until_phase(MatchController.Phase.FLIGHT)
	await swing_at(ideal_swing())
	await until_clock(ideal_swing() + c.tuning.swing_to_contact + 0.03)
	await shot("f01_impact")
	await until_clock(ideal_swing() + c.tuning.swing_to_contact + 0.45)
	await shot("f02_ball_flying_batter_view")
	await until_phase(MatchController.Phase.OUTCOME)
	await wait(0.35)
	await shot("f03_celebration")
	_log("ball 1: %s" % c.resolver.outcome.kind)
	await until_phase(MatchController.Phase.FLIGHT)
	await swing_at(ideal_swing() + 45.0 / 1000.0 * 1000.0 / 1000.0)
	await until_phase(MatchController.Phase.OUTCOME)
	await wait(0.15)
	await shot("f04_banner")
	_log("ball 2: %s %d" % [c.resolver.outcome.kind, c.resolver.outcome.runs])
	# Pace: three more balls auto-played (swing late-ish), measure start-to-start time.
	for i in 2:
		await until_phase(MatchController.Phase.FLIGHT)
		await swing_at(ideal_swing() + 0.02)
		await until_phase(MatchController.Phase.OUTCOME)
	await until_phase(MatchController.Phase.READY)
	var gaps: Array = []
	for i in range(1, starts.size()):
		gaps.append(snappedf(starts[i] - starts[i - 1], 0.01))
	_log("seconds between deliveries (game time, auto-continue, no taps to skip): %s" % str(gaps))
	check(c.state.card.wickets <= 1, "classic has at most one wicket")


func _visual_tour() -> void:
	var save = get_node("/root/Save")
	await wait(1.6)
	await shot("v01_menu")
	app.start_mode("classic")
	await wait(0.2)
	# Batter's-eye run-up + ring, then the side camera takes the ball; truck on a boundary.
	var c = app.controller
	await until_phase(MatchController.Phase.FLIGHT)
	await until_clock(ideal_swing() - 0.12)
	await shot("v02_batter_view_flight")
	await swing_at(ideal_swing())
	await until_clock(ideal_swing() + 0.2)
	await shot("v03_contact")
	await until_clock(ideal_swing() + 1.2)
	await shot("v04_side_follow")
	await until_phase(MatchController.Phase.OUTCOME)
	await wait(1.0)
	await shot("v05_outcome_truck")
	_log("first ball: %s" % c.resolver.outcome.kind)
	for tod in ["night", "rain", "day"]:
		save.set_setting("time_of_day", tod)
		app.start_mode("classic")
		await until_phase(MatchController.Phase.RUNUP)
		await until_clock(-0.35)
		await shot("v06_%s_runup" % tod)
		await swing_at(ideal_swing())
		await until_clock(ideal_swing() + 1.0)
		await shot("v07_%s_side" % tod)
	save.set_setting("time_of_day", "evening")
	save.set_setting("view", "side")
	app.start_mode("classic")
	await until_phase(MatchController.Phase.FLIGHT)
	await until_clock(ideal_swing() - 0.1)
	await shot("v08_side_view_flight")
	save.set_setting("view", "batter")
	# Result screen from a scripted innings (same event pipeline as live play).
	var st := MatchState.new(MatchRules.classic("Ayaan"), 5)
	for r in [1, 4, 0, 6, 2, 1, 0, 4, 6, 1]:
		var o := BallOutcome.new()
		o.runs = r
		o.kind = BallOutcome.DOT if r == 0 else (BallOutcome.FOUR if r == 4 else (BallOutcome.SIX if r == 6 else BallOutcome.RUNS))
		st.record(st.events.size(), o, st.current_bowler_id())
	var w := BallOutcome.new()
	w.kind = BallOutcome.BOWLED
	w.wicket = true
	st.record(st.events.size(), w, st.current_bowler_id())
	st.record(st.events.size(), w, st.current_bowler_id())
	var cr := ClassicResult.new()
	cr.build(st, 12, app.venue)
	app._open_overlay(cr)
	await frames(3)
	await shot("v09_result")


func _quick_tour() -> void:
	await wait(1.6)
	await shot("q01_menu")
	app.start_mode("quick")
	await wait(0.2)
	await shot("q02_rule_card")
	app._close_overlay()
	await play_ball(0.0, "q03")
	press_space()
	await play_ball(35.0, "q04")
	await wait(0.2)
	app.open_scorecard()
	await frames(3)
	await shot("q05_scorecard")
	app._close_overlay()
	app.open_pause()
	await frames(3)
	await shot("q06_pause")
	_log("fps=%d (software rendering under Xvfb; not representative of devices)" % Engine.get_frames_per_second())


func _look_tour() -> void:
	var save = get_node("/root/Save")
	await wait(1.6)
	await shot("l01_menu")
	app.start_mode("classic")
	var c = app.controller
	await until_phase(MatchController.Phase.RUNUP)
	await until_clock(-0.2)
	await shot("l02_batter_view_runup")
	await until_phase(MatchController.Phase.FLIGHT)
	await swing_at(c.ideal_tap_time() + 0.035)
	await until_clock(c.ideal_tap_time() + 1.4)
	await shot("l03_side_view")
	await until_phase(MatchController.Phase.OUTCOME)
	await wait(0.3)
	await shot("l04_outcome")
	save.set_setting("view", "side")
	press_space()
	await until_phase(MatchController.Phase.FLIGHT)
	await until_clock(c.ideal_tap_time() - 0.1)
	await shot("l05_side_delivery")
	save.set_setting("view", "batter")
	save.set_setting("time_of_day", "night")
	app.start_mode("classic")
	await until_phase(MatchController.Phase.RUNUP)
	await until_clock(-0.15)
	await shot("l06_night")
	save.set_setting("time_of_day", "evening")


func _hints_check() -> void:
	var save = get_node("/root/Save")
	save.set_setting("hints", true)
	await wait(1.6)
	app.start_mode("classic")
	var c = app.controller
	check(c.hints, "hints enabled from the menu setting")
	await until_phase(MatchController.Phase.FLIGHT)
	await until_clock(c.ideal_tap_time() - 0.03)
	_log("clock speed near ideal tap: %.2f" % c._clock_speed)
	check(c._clock_speed < 0.7, "ball slows down near the hit moment")
	await shot("h01_hit_now")
	await swing_at(c.ideal_tap_time())
	await until_phase(MatchController.Phase.OUTCOME)
	_log("hinted swing: %s dt=%.1f ms" % [c.resolver.contact.category, c.resolver.contact.dt_ms])
	check(absf(c.resolver.contact.dt_ms) < 15.0, "tap on the cue is timed precisely under slow-motion")
	save.set_setting("hints", false)


func _restart_check() -> void:
	await wait(1.6)
	var c = app.controller
	c.phase_changed.connect(func(ph): _log("phase %s clock %.2f screen %s" % [MatchController.Phase.keys()[ph], c.clock.time, str(app.screen)]))
	app.start_mode("classic")
	for i in 30:
		if app.screen != app.Screen.MATCH:
			break
		await until_phase(MatchController.Phase.FLIGHT)
		await swing_at(ideal_swing() - 0.40)
		await until_phase(MatchController.Phase.OUTCOME)
		var fo = get_viewport().gui_get_focus_owner()
		_log("outcome %s screen %s overlay %s focus %s %s" % [c.resolver.outcome.kind, str(app.screen), str(app.overlay), str(fo), (fo.text if fo is Button else "")])
		if c.state.is_complete():
			break
		press_space()
		await frames(3)
	await wait(2.5)
	check(app.screen == app.Screen.RESULT, "out in classic shows the result screen")
	var ov = app.overlay
	if ov != null and ov.has_signal("play_again"):
		ov.play_again.emit()
	await wait(0.3)
	var t_before: float = c.clock.time
	await wait(1.5)
	check(c.clock.time > t_before + 0.5, "after Play again the delivery clock runs (bowler comes in)")
	await until_phase(MatchController.Phase.FLIGHT)
	check(c.phase == MatchController.Phase.FLIGHT, "after Play again the ball is bowled")


func _approach_shots() -> void:
	await wait(1.6)
	app.start_mode("classic")
	await until_phase(MatchController.Phase.FLIGHT)
	var c = app.controller
	var ideal: float = ideal_swing() + c.tuning.swing_to_contact
	await until_clock(ideal - 0.3)
	await shot("a01_ball_approach")
	await until_clock(ideal - 0.12)
	await shot("a02_ball_near_bat")


func _smoke() -> void:
	await wait(1.6)
	_log("sizes ui_root=%s hud=%s menu=%s vp=%s" % [str(app.ui_root.size), str(app.hud.size), str(app.menu.size), str(get_viewport().get_visible_rect().size)])
	app.start_mode("quick")
	await wait(0.2)
	app._close_overlay()
	var c = app.controller
	var recorded_before: int = c.state.events.size()
	# Camera follows how the phone is held ("Auto" view is the default).
	await until_phase(MatchController.Phase.FLIGHT)
	eq(app.world.effective_view(), "batter", "always the batter's view")
	check(app.world._bv_on, "batter's-eye camera on during the delivery")
	await swing_at(ideal_swing())
	await until_phase(MatchController.Phase.OUTCOME)
	press_space()
	recorded_before = c.state.events.size()
	await play_ball(0.0)
	check(c.state.events.size() == recorded_before + 1, "exactly one event recorded per delivery")
	# Pause mid-delivery freezes the clock.
	press_space()
	await until_phase(MatchController.Phase.FLIGHT)
	app.open_pause()
	var t0: float = c.clock.time
	await wait(0.5)
	check(absf(c.clock.time - t0) < 0.0001, "clock frozen while paused")
	app._close_overlay()
	await until_phase(MatchController.Phase.OUTCOME)
	check(c.state.events.size() == recorded_before + 2, "resumed delivery recorded once")
	# Instant replay must have no side effects.
	var runs_before: int = c.state.card.runs
	c.auto_continue = false
	c.start_replay()
	check(c.phase == MatchController.Phase.REPLAY, "replay started")
	await shot("smoke_replay")
	await until_phase(MatchController.Phase.OUTCOME)
	check(c.state.events.size() == recorded_before + 2 and c.state.card.runs == runs_before, "replay recorded nothing")
	c.auto_continue = true
	# Regression: get out in Classic, then "Play again" must start a running delivery.
	app.start_mode("classic")
	await wait(0.2)
	for i in 30:
		if app.screen != app.Screen.MATCH:
			break
		await until_phase(MatchController.Phase.FLIGHT)
		await swing_at(ideal_swing() - 0.40)   # far too early: miss, so we are out soon
		await until_phase(MatchController.Phase.OUTCOME)
		if c.state.is_complete():
			break
		press_space()
		await frames(2)
	await wait(2.5)
	check(app.screen == app.Screen.RESULT, "out in classic shows the result screen")
	var ov = app.overlay
	if ov != null and ov.has_signal("play_again"):
		ov.play_again.emit()
	await wait(0.3)
	var t_before: float = c.clock.time
	await wait(1.5)
	check(c.clock.time > t_before + 0.5, "after Play again the delivery clock runs (bowler comes in)")
	await until_phase(MatchController.Phase.FLIGHT)
	check(c.phase == MatchController.Phase.FLIGHT, "after Play again the ball is bowled")
	await _voice_check()


## Commentary is spoken: each line resolves to a real clip .
func _voice_check() -> void:
	var c = app.controller
	app.start_mode("quick")
	await wait(0.2)
	app._close_overlay()
	var spoken := []
	c.commentary_line.connect(func(line): spoken.append(app.audio.voice_clip_for(line)))
	for i in 2:
		await play_ball(0.0)
	_log("spoken clips: " + str(spoken))
	check(not spoken.is_empty() and spoken.all(func(k): return String(k).begins_with("vo_")), "every commentary line has a voice clip")


## Freezes a delivery and renders the striker at key moments (stance, taps, trigger,
## backlift, downswing, contact, follow-through, left ball) for visual review.
func _batter_sheet() -> void:
	await wait(1.6)
	var save = get_node("/root/Save")
	save.set_setting("view", "batter")
	app.start_mode("classic")
	var c = app.controller
	await until_phase(MatchController.Phase.RUNUP)
	await frames(2)
	c.set_process(false)
	var wv = app.world
	var ideal: float = wv.delivery.time_at_x(wv.tuning.contact_x_ideal)
	var sw: float = ideal - wv.tuning.swing_to_contact
	var shots := [["b01_stance", -2.0, -1.0], ["b02_tap", -1.45, -1.0], ["b03_trigger", -0.35, -1.0],
		["b04_backlift", 0.2, -1.0], ["b05_downswing", sw + 0.05, sw], ["b06_contact", sw + 0.1, sw],
		["b07_follow_mid", sw + 0.2, sw], ["b08_follow", sw + 0.4, sw], ["b09_hold", sw + 0.9, sw],
		["b10_left_alone", wv.delivery.stumps_time() + 0.7, -1.0]]
	for s in shots:
		wv.swing_time = s[2]
		wv.resolved = null
		wv.render(s[1])
		wv.batter_view.visible = true
		wv.batter_view.modulate.a = 1.0
		await frames(3)
		await shot(s[0])
	wv.set_view_mode("side")
	for s in [["s01_stance", -2.0, -1.0], ["s02_tap", -1.45, -1.0], ["s03_backlift", 0.2, -1.0], ["s04_contact", sw + 0.1, sw], ["s05_follow", sw + 0.4, sw]]:
		wv.swing_time = s[2]
		wv.render(s[1])
		for i in 20:
			wv.update_camera(0.05)
		await frames(3)
		await shot(s[0])
	wv.set_view_mode("batter")
	c.set_process(true)


## Every overlay and celebration in the current orientation (run with --portrait too).
func _screens_tour() -> void:
	await wait(1.6)
	await shot("u01_menu")
	app.open_settings()
	await wait(0.3)
	await shot("u02_settings")
	app.overlay.licences.emit()
	await wait(0.3)
	check(app.overlay is LicencesPanel, "credits & licences screen opens from settings")
	check(LicencesPanel.notices().contains("Godot Engine") and LicencesPanel.notices().contains("Open Font License"), "licence notices include Godot (MIT) and Lato (OFL)")
	await shot("u02b_licences")
	eq(app.handle_back(), "closed", "back closes the licences screen")
	app._close_overlay()
	app.start_mode("classic")
	await wait(0.2)
	app._close_overlay()
	var c = app.controller
	# Hit until a boundary brings the truck out (or 6 balls).
	for i in 6:
		var o: BallOutcome = await play_ball(0.0)
		if o.is_boundary():
			break
	await wait(0.1)
	await shot("u03_after_boundary")
	app.hud.truck.play("six")
	await wait(0.8)
	await shot("u03b_truck")
	eq(app.handle_back(), "paused", "back during a match pauses it (does not quit)")
	await wait(0.3)
	check(app.overlay is PauseMenu, "pause menu showing after back")
	await shot("u04_pause")
	eq(app.handle_back(), "closed", "back again resumes")
	for i in 30:
		if app.screen != app.Screen.MATCH:
			break
		await until_phase(MatchController.Phase.FLIGHT)
		await swing_at(ideal_swing() - 0.40)
		await until_phase(MatchController.Phase.OUTCOME)
		if c.state.is_complete():
			break
		press_space()
		await frames(2)
	await wait(2.5)
	await shot("u05_result")
	app.show_menu()
	await wait(0.6)
	await shot("u06_menu_returning")


## CPU cost per frame (wall clock, uncapped) across real deliveries in both camera views
## and on the menu. Run headless so GPU rasterisation isn't counted; swings are sent once
## per ball at about the right time, with no busy-waiting.
func _perf() -> void:
	await wait(1.6)
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	OS.low_processor_usage_mode_sleep_usec = 0
	var save = get_node("/root/Save")
	var c = app.controller
	var results := {}
	for view in ["menu", "batter", "side"]:
		var samples := []
		var last := Time.get_ticks_usec()
		if view == "menu":
			for i in 600:
				await get_tree().process_frame
				var now := Time.get_ticks_usec()
				samples.append((now - last) / 1000.0)
				last = now
		else:
			save.set_setting("view", view)
			app.start_mode("classic")
			await get_tree().process_frame
			app._close_overlay()
			var swung := -1
			var balls := 0
			last = Time.get_ticks_usec()
			while balls < 6 and samples.size() < 60000:
				await get_tree().process_frame
				var now := Time.get_ticks_usec()
				samples.append((now - last) / 1000.0)
				last = now
				if app.screen != app.Screen.MATCH:
					app.start_mode("classic")
					await get_tree().process_frame
					app._close_overlay()
					last = Time.get_ticks_usec()
					continue
				if c.phase == MatchController.Phase.FLIGHT and swung != c.state.events.size() and c.clock.time >= c.ideal_tap_time() - 0.01:
					swung = c.state.events.size()
					c.swing_input(Time.get_ticks_usec())
				if c.phase == MatchController.Phase.OUTCOME and swung == c.state.events.size() - 1:
					balls += 1
					swung = -2
					press_space()
					last = Time.get_ticks_usec()
		samples.sort()
		var avg := 0.0
		for v in samples:
			avg += v
		avg /= maxf(1.0, samples.size())
		var p95: float = samples[int(samples.size() * 0.95)]
		var p99: float = samples[int(samples.size() * 0.99)]
		results[view] = p95
		_log("%s: CPU ms per frame avg %.2f  p95 %.2f  p99 %.2f  max %.2f  (%d frames)" % [view, avg, p95, p99, samples[samples.size() - 1], samples.size()])
	Engine.time_scale = 0.2
	check(results["batter"] < 4.0 and results["side"] < 4.0, "CPU time per frame stays small in play (p95 < 4 ms on this machine)")


## Puts the batter on 47 / 97 and hits until a fifty / hundred: checks the celebration
## shows, the game waits for it, and captures it.
func _milestone_check() -> void:
	await wait(1.6)
	var c = app.controller
	for target in [50, 100]:
		app.start_mode("classic")
		await wait(0.2)
		app._close_overlay()
		var got := [0]   # lambdas capture locals by value: use a container
		var conn := func(m, _b): got[0] = m
		c.milestone_reached.connect(conn)
		# Earlier sixes recorded straight into the ball-by-ball log (the scorecard is
		# rebuilt from it), leaving the batter a few short of the milestone.
		var pre := int((target - 6) / 6)
		for k in pre:
			var o := BallOutcome.new()
			o.kind = BallOutcome.SIX
			o.runs = 6
			c.state.record(900000 + k, o, "harness")
		for i in 6:
			await play_ball(0.0)
			if got[0] > 0 or app.screen != app.Screen.MATCH:
				break
		c.milestone_reached.disconnect(conn)
		check(got[0] == target, "reached %d (got %d)" % [target, got[0]])
		check(app.hud.milestone_fx.visible, "celebration screen shows for %d" % target)
		await wait(0.12)
		await shot("m_%d_a" % target)
		await wait(0.75)
		await shot("m_%d_b" % target)
		check(c.phase == MatchController.Phase.OUTCOME, "game waits during the celebration")


## Store screenshots: menu, batter's view waiting, the hit, a six with the truck, a fifty.
func _store_shots() -> void:
	await wait(1.6)
	await shot("s1_menu")
	var c = app.controller
	app.start_mode("classic")
	await wait(0.2)
	app._close_overlay()
	await until_phase(MatchController.Phase.RUNUP)
	await until_clock(0.15)
	await shot("s2_batters_eye")
	app.hud.visible = false
	get_node("/root/Save").set_setting("view", "batter")   # the feature graphic uses the batter's eye
	await frames(3)
	await shot("x_clean_batters_eye")   # no HUD: used for the feature graphic
	get_node("/root/Save").set_setting("view", "auto")
	app.hud.visible = true
	await until_phase(MatchController.Phase.FLIGHT)
	await swing_at(ideal_swing())
	await until_clock(ideal_swing() + 0.12)
	await shot("s3_hit")
	await until_phase(MatchController.Phase.OUTCOME)
	app.hud.truck.play("six")
	await wait(0.8)
	await shot("s4_six_truck")
	press_space()
	var pre := 7
	for k in pre:
		var o := BallOutcome.new()
		o.kind = BallOutcome.SIX
		o.runs = 6
		c.state.record(910000 + k, o, "harness")
	var got := [0]
	var conn := func(m, _b): got[0] = m
	c.milestone_reached.connect(conn)
	for i in 4:
		await play_ball(0.0)
		if got[0] > 0:
			break
	c.milestone_reached.disconnect(conn)
	await wait(0.85)
	await shot("s5_fifty")


## Every colour theme: the menu, a delivery and the moment after a hit (fielders chasing).
func _themes_tour() -> void:
	await wait(1.6)
	var save = get_node("/root/Save")
	for id in UiTheme.THEME_IDS:
		save.set_setting("theme", id)
		await wait(0.4)
		check(UiTheme.theme_id == id, "theme %s applied" % id)
		await shot("t_%s_1_menu" % id)
	save.set_setting("theme", "emerald")
	await wait(0.3)
	app.start_mode("classic")
	await wait(0.2)
	app._close_overlay()
	var c = app.controller
	await until_phase(MatchController.Phase.FLIGHT)
	await swing_at(ideal_swing() + 0.03)
	await until_clock(ideal_swing() + 0.9)
	check(app.world._bv_on, "still the batter's view after the hit")
	await shot("t_emerald_2_after_hit")
	await until_phase(MatchController.Phase.OUTCOME)
	for id in ["royal", "sunset", "midnight"]:
		save.set_setting("theme", id)
		await wait(0.3)
		await shot("t_%s_2_game" % id)
	save.set_setting("theme", "emerald")

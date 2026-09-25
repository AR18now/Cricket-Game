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
	save.save()
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
	var now_t: float = c.clock.time_of_input(Time.get_ticks_usec(), Engine.time_scale)
	var need_us := (t - now_t) / Engine.time_scale * 1000000.0
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


func _smoke() -> void:
	await wait(1.6)
	_log("sizes ui_root=%s hud=%s menu=%s vp=%s" % [str(app.ui_root.size), str(app.hud.size), str(app.menu.size), str(get_viewport().get_visible_rect().size)])
	app.start_mode("quick")
	await wait(0.2)
	app._close_overlay()
	var c = app.controller
	var recorded_before: int = c.state.events.size()
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

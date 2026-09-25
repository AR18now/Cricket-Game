extends Node
## App root: living ground + match controller + UI screens.
## Flow (first launch): identity mark -> menu -> tutorial (3 balls) -> first challenge
## -> result -> optional name/kit -> menu. Returning players: menu -> PLAY = quick match.

enum Screen { SPLASH, MENU, MATCH, RESULT, TUTORIAL }

var tuning: GameTuning
var venue: VenueConfig
var world: WorldView
var controller: MatchController
var ui: CanvasLayer
var ui_root: Control
var hud: Hud
var menu: MainMenu
var overlay: Control
var screen := Screen.SPLASH
var current_mode := "quick"
var _splash: Control
var _harness: Node
var save: Node
var audio: Node


func _ready() -> void:
	save = get_node("/root/Save")
	audio = get_node("/root/Audio")
	tuning = load("res://data/tuning_default.tres")
	venue = load("res://data/venues/pindi.tres")
	world = WorldView.new()
	add_child(world)
	world.build(venue, tuning)
	world.setup_fielders(FielderSpec.from_layout(venue.field_layout, [], tuning))
	controller = MatchController.new()
	add_child(controller)
	controller.setup(world, tuning, venue)
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UiTheme.build()
	ui.add_child(ui_root)
	hud = Hud.new()
	ui_root.add_child(hud)
	hud.build(controller, world)
	hud.visible = false
	hud.pause_pressed.connect(open_pause)
	hud.mute_pressed.connect(toggle_mute)
	hud.card_pressed.connect(open_scorecard)
	hud.replay_pressed.connect(func(): controller.start_replay())
	hud.stance_changed.connect(func(s): controller.stance = s)
	menu = MainMenu.new()
	ui_root.add_child(menu)
	menu.build()
	menu.visible = false
	menu.play_pressed.connect(_on_play)
	menu.mode_pressed.connect(start_mode)
	menu.settings_pressed.connect(open_settings)
	menu.mute_pressed.connect(toggle_mute)
	controller.match_over.connect(_on_match_over)
	controller.tutorial_step.connect(_on_tutorial_step)
	controller.commentary_line.connect(func(line): audio.say(line, "Bilal"))
	controller.ball_settled.connect(_on_ball_settled)
	audio.caption.connect(func(text, speaker): hud.show_caption(text, speaker))
	save.changed.connect(_apply_settings)
	_apply_settings()
	get_tree().root.size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	world.render_menu(0.0)
	_show_splash()
	if OS.is_debug_build():
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--harness"):
				var hs = load("res://scripts/dev/dev_harness.gd")
				if hs:
					_harness = hs.new()
					add_child(_harness)
					_harness.run(self)
				break


func _apply_settings() -> void:
	var s: Dictionary = save.data["settings"]
	world.reduced_motion = bool(s["reduced_motion"])
	world.effects.reduced_motion = world.reduced_motion
	controller.commentary.language = String(s["language"])
	hud.set_muted(bool(s["muted"]))
	hud.set_stance_available(bool(save.data["stance_unlocked"]))
	var kit_idx := int(save.data["profile"]["kit"])
	world.set_batting_kit(OnboardingPanel.KITS[clampi(kit_idx, 0, OnboardingPanel.KITS.size() - 1)])
	if menu.visible:
		menu.refresh(save.data)


func _apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		ui_root.offset_left = 0
		ui_root.offset_right = 0
		ui_root.offset_top = 0
		ui_root.offset_bottom = 0
		return
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var vp := get_viewport().get_visible_rect().size
	if win.x <= 0 or win.y <= 0:
		return
	var k := Vector2(vp.x / win.x, vp.y / win.y)
	ui_root.offset_left = safe.position.x * k.x
	ui_root.offset_top = safe.position.y * k.y
	ui_root.offset_right = -(win.x - safe.end.x) * k.x
	ui_root.offset_bottom = -(win.y - safe.end.y) * k.y


# ------------------------------------------------------------------ screens
func _show_splash() -> void:
	screen = Screen.SPLASH
	_splash = Control.new()
	_splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.EMERALD_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash.add_child(bg)
	var l := UiTheme.label("DevTorque", 54, UiTheme.GOLD, "black")
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	_splash.add_child(l)
	ui_root.add_child(_splash)
	audio.play("sting_open", "Music", -6.0, 0.0)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(_splash, "modulate:a", 0.0, 0.35)
	tw.tween_callback(_end_splash)


func _end_splash() -> void:
	if is_instance_valid(_splash):
		_splash.queue_free()
	show_menu()


func show_menu() -> void:
	screen = Screen.MENU
	controller.phase = MatchController.Phase.IDLE
	controller.set_paused(false)
	_close_overlay()
	hud.visible = false
	hud.hide_transient()
	menu.visible = true
	menu.refresh(save.data)
	world.menu_mode = true
	audio.start_ambience(venue.id)
	audio.start_music()
	audio.set_crowd_intensity(0.2)
	menu.play_btn.call_deferred("grab_focus")


func _process(delta: float) -> void:
	if screen == Screen.MENU or screen == Screen.SPLASH:
		world.render_menu(delta)


func _on_play() -> void:
	if not bool(save.data["tutorial_done"]):
		start_tutorial()
	else:
		start_mode("quick")


func start_tutorial() -> void:
	current_mode = "tutorial"
	var r := MatchRules.practice(_player_name())
	r.mode = MatchRules.TUTORIAL
	r.title = "Nets"
	_begin(r, true)


func start_mode(mode: String) -> void:
	current_mode = mode
	var name := _player_name()
	var seed_value := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	var r: MatchRules
	match mode:
		"practice":
			r = MatchRules.practice(name)
			r.bowlers_by_over = ["daniyal", "hamza", "saad"]
		"endless":
			r = MatchRules.endless(name)
		"challenge_first":
			r = MatchRules.opening_challenge(name)
		_:
			var rng := DetRng.new(seed_value)
			r = MatchRules.quick_match(16 + rng.range_i(0, 8), name)
	_begin(r, false, seed_value)
	if mode in ["quick", "challenge_first", "endless"]:
		_show_rule_card(r)


func _begin(r: MatchRules, tutorial: bool, seed_value: int = 1) -> void:
	_close_overlay()
	menu.visible = false
	hud.visible = true
	hud.hide_transient()
	screen = Screen.TUTORIAL if tutorial else Screen.MATCH
	world.snap_camera_to_delivery()
	audio.stop_music()
	audio.set_crowd_intensity(0.35)
	controller.stance = hud.stance if hud.stance_unlocked else ContactResult.Stance.AUTO
	controller.start_match(r, seed_value, tutorial)


func _show_rule_card(r: MatchRules) -> void:
	var o := OverlayPanel.new()
	o.title(r.title, 40)
	var lines: Array = []
	match r.mode:
		MatchRules.QUICK:
			lines = ["Chase the challenge target of %d in %d overs." % [r.target, r.overs],
				"Arcade squad: 2 batters at the crease, 3 wickets in hand.",
				"Odd runs and the end of each over swap the strike.",
				"Timing sets direction: early = leg side, late = off side, perfect = straight."]
		MatchRules.CHALLENGE:
			lines = ["Score %d runs from %d balls. You have %d wickets." % [r.target, r.overs * 6, r.max_wickets],
				"Gentle deliveries - time your tap as the ball arrives."]
		MatchRules.ENDLESS:
			lines = ["One wicket. Bat as long as you can.", "Bowlers rotate every over and get gradually quicker (bounded)."]
	for l in lines:
		var lab := UiTheme.label(l, 21, UiTheme.OFF_WHITE, "regular")
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		o.body.add_child(lab)
	var b := o.add_button("Let's go", func(): _close_overlay(), 28)
	_open_overlay(o)
	b.call_deferred("grab_focus")


func _player_name() -> String:
	return String(save.data["profile"]["display_name"])


# ------------------------------------------------------------------ overlays
func _open_overlay(o: Control) -> void:
	_close_overlay()
	overlay = o
	ui_root.add_child(o)
	controller.set_paused(true)


func _close_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	if screen == Screen.MATCH or screen == Screen.TUTORIAL:
		controller.set_paused(false)


func open_pause() -> void:
	if screen != Screen.MATCH and screen != Screen.TUTORIAL:
		return
	if overlay != null:
		return
	var p := PauseMenu.new()
	var card := controller.state.card
	p.build("%s   %d/%d  (%s ov)" % [controller.rules.title, card.runs, card.wickets, card.overs_text()])
	p.resume.connect(_close_overlay)
	p.settings.connect(open_settings)
	p.restart.connect(func(): start_mode(current_mode) if current_mode != "tutorial" else start_tutorial())
	p.quit_to_menu.connect(show_menu)
	_open_overlay(p)


func open_settings() -> void:
	var was_match := screen == Screen.MATCH or screen == Screen.TUTORIAL
	var s := SettingsPanel.new()
	ui_root.add_child(s)
	s.build()
	_close_overlay()
	overlay = s
	controller.set_paused(true)
	s.closed.connect(func():
		_close_overlay()
		if was_match:
			open_pause())
	s.replay_tutorial.connect(func():
		_close_overlay()
		start_tutorial())


func open_scorecard() -> void:
	if controller.state == null or overlay != null or screen != Screen.MATCH:
		return
	var p := ScorecardPanel.new()
	p.build(controller.state, false)
	p.closed.connect(_close_overlay)
	_open_overlay(p)


func toggle_mute() -> void:
	save.set_setting("muted", not bool(save.data["settings"]["muted"]))


# ------------------------------------------------------------------ match events
func _on_ball_settled(o: BallOutcome, _card: Scorecard) -> void:
	if bool(save.data["settings"]["haptics"]) and (o.wicket or o.is_boundary()):
		Input.vibrate_handheld(40 if o.wicket else 25)
	if o.kind == BallOutcome.SIX or o.kind == BallOutcome.FOUR:
		audio.set_crowd_intensity(0.8)
	else:
		audio.set_crowd_intensity(0.35)


func _on_tutorial_step(level: int, success: bool) -> void:
	if success:
		hud.hint(["Shabash! That's contact.", "Great - you're getting it.", "Well played!"][clampi(level, 0, 2)], 1.6)
	else:
		hud.hint("Missed - watch the ring and tap as it closes. Try again!", 2.2)


func _on_match_over(state: MatchState) -> void:
	if current_mode == "tutorial":
		hud.hint("Nets done! Now a small challenge...", 2.0)
		await get_tree().create_timer(1.2).timeout
		start_mode("challenge_first")
		return
	screen = Screen.RESULT
	var card := state.card
	var rid := "%s-%d" % [current_mode, state.seed]
	var mode := current_mode
	save.apply_result_once(rid, func(d: Dictionary): _apply_progress(d, mode, card))
	audio.play("sting_win" if card.result == "won" else "sting_lose", "Music", -3.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	var p := ScorecardPanel.new()
	var headline := ""
	if mode == "endless":
		headline = "%d RUNS" % card.runs
		if card.runs >= int(save.data["best"]["endless_runs"]) and card.runs > 0:
			headline += "  -  NEW BEST!"
	p.build(state, true, headline)
	p.play_again.connect(func(): start_mode(mode if mode != "challenge_first" else "quick"))
	p.to_menu.connect(func():
		if mode == "challenge_first" and not bool(save.data["profile"]["onboarded"]):
			_show_onboarding()
		else:
			show_menu())
	_open_overlay(p)


static func _apply_progress(d: Dictionary, mode: String, card: Scorecard) -> void:
	d["best"]["sixes"] = int(d["best"]["sixes"]) + card.sixes
	d["best"]["fours"] = int(d["best"]["fours"]) + card.fours
	match mode:
		"quick":
			d["best"]["quick_played"] = int(d["best"]["quick_played"]) + 1
			if card.result == "won":
				d["best"]["quick_wins"] = int(d["best"]["quick_wins"]) + 1
		"endless":
			if card.runs > int(d["best"]["endless_runs"]):
				d["best"]["endless_runs"] = card.runs
				d["best"]["endless_balls"] = card.legal_balls
		"challenge_first":
			d["tutorial_done"] = true
			d["stance_unlocked"] = true
			d["challenges"]["first"] = {"done": true, "result": card.result}


func _show_onboarding() -> void:
	var o := OnboardingPanel.new()
	o.build(_player_name(), int(save.data["profile"]["kit"]))
	o.done.connect(func(n: String, kit: int):
		save.data["profile"]["display_name"] = n.left(16)
		save.data["profile"]["kit"] = kit
		save.data["profile"]["onboarded"] = true
		save.save()
		show_menu())
	_open_overlay(o)


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if overlay == null and (screen == Screen.MATCH or screen == Screen.TUTORIAL):
					controller.swing_input(Time.get_ticks_usec())
					get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_P:
				if overlay != null and (screen == Screen.MATCH or screen == Screen.TUTORIAL) and overlay is PauseMenu:
					_close_overlay()
				else:
					open_pause()
			KEY_F3:
				if OS.is_debug_build():
					hud.show_debug = not hud.show_debug
			KEY_M:
				toggle_mute()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if overlay == null and (screen == Screen.MATCH or screen == Screen.TUTORIAL):
			controller.swing_input(Time.get_ticks_usec())
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			# Pause safely mid-delivery; nothing is recorded until a ball settles.
			if (screen == Screen.MATCH or screen == Screen.TUTORIAL) and overlay == null and _harness == null:
				open_pause()

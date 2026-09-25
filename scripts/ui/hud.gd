class_name Hud
extends Control
## Compact, glanceable match HUD. Everything is derived from the authoritative Scorecard.

signal pause_pressed
signal mute_pressed
signal view_pressed
signal card_pressed
signal replay_pressed
signal swing_pressed

var controller: MatchController
var world: WorldView
var score_panel: PanelContainer
var score_label: Label
var sub_label: Label
var chase_label: Label
var over_row: HBoxContainer
var bowler_panel: PanelContainer
var bowler_label: Label
var speed_label: Label
var buttons: HBoxContainer
var card_btn: IconButton
var mute_btn: IconButton
var timing_panel: PanelContainer
var timing_label: Label
var timing_meter: TimingMeter
var banner: PanelContainer
var banner_title: Label
var banner_sub: Label
var caption_panel: PanelContainer
var caption_label: Label
var hint_label: Label
var toast: PanelContainer
var toast_label: Label
var swing_btn: SwingButton
var minimap: Minimap
var guide: GuideOverlay
var truck: TruckCelebration
var replay_btn: Button
var replay_tag: Label
var debug_label: Label
var show_debug := false
var stance := 0
var stance_unlocked := false
var best_runs := 0
var _caption_until := 0.0
var _timing_until := 0.0
var _hint_until := 0.0
var _toast_until := 0.0
var _last_bowler := ""


func build(c: MatchController, w: WorldView) -> void:
	controller = c
	world = w
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide = GuideOverlay.new()
	guide.world = w
	guide.controller = c
	add_child(guide)
	# --- Score pill (top centre)
	score_panel = PanelContainer.new()
	score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.02, 0.15, 0.12, 0.82), 24, UiTheme.GOLD.darkened(0.3), 2))
	add_child(score_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	score_panel.add_child(sv)
	score_label = UiTheme.label("0", 46, UiTheme.OFF_WHITE, "black")
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(score_label)
	sub_label = UiTheme.label("", 18, UiTheme.SAND)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(sub_label)
	chase_label = UiTheme.label("", 18, UiTheme.GOLD)
	chase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(chase_label)
	over_row = HBoxContainer.new()
	over_row.alignment = BoxContainer.ALIGNMENT_CENTER
	over_row.add_theme_constant_override("separation", 6)
	sv.add_child(over_row)
	# --- Bowler card (top left)
	bowler_panel = PanelContainer.new()
	bowler_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bowler_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.02, 0.15, 0.12, 0.72), 16))
	add_child(bowler_panel)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	bowler_panel.add_child(bv)
	bowler_label = UiTheme.label("", 20, UiTheme.OFF_WHITE)
	bv.add_child(bowler_label)
	speed_label = UiTheme.label("", 17, UiTheme.SAND, "regular")
	bv.add_child(speed_label)
	# --- Buttons (top right)
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	add_child(buttons)
	card_btn = IconButton.make("card", "Scorecard", 60)
	card_btn.pressed.connect(func(): card_pressed.emit())
	buttons.add_child(card_btn)
	var view_btn := IconButton.make("camera", "Switch camera view", 60)
	view_btn.pressed.connect(func(): view_pressed.emit())
	buttons.add_child(view_btn)
	mute_btn = IconButton.make("sound_on", "Mute / unmute", 60)
	mute_btn.pressed.connect(func(): mute_pressed.emit())
	buttons.add_child(mute_btn)
	var pause_btn := IconButton.make("pause", "Pause", 60)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	buttons.add_child(pause_btn)
	minimap = Minimap.new()
	minimap.world = w
	add_child(minimap)
	# --- Timing feedback
	timing_panel = PanelContainer.new()
	timing_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timing_panel.visible = false
	add_child(timing_panel)
	var tv := VBoxContainer.new()
	timing_panel.add_child(tv)
	timing_label = UiTheme.label("", 30, UiTheme.GOLD, "black")
	timing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(timing_label)
	timing_meter = TimingMeter.new()
	tv.add_child(timing_meter)
	# --- Outcome banner
	banner = PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	banner.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.02, 0.15, 0.12, 0.88), 20, UiTheme.GOLD, 3))
	add_child(banner)
	var bbox := VBoxContainer.new()
	bbox.add_theme_constant_override("separation", 0)
	banner.add_child(bbox)
	banner_title = UiTheme.label("", 50, UiTheme.GOLD, "black")
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bbox.add_child(banner_title)
	banner_sub = UiTheme.label("", 19, UiTheme.OFF_WHITE, "regular")
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.custom_minimum_size = Vector2(460, 0)
	bbox.add_child(banner_sub)
	# --- Truck celebration (behind banner/buttons)
	truck = TruckCelebration.new()
	add_child(truck)
	move_child(truck, 1)
	truck.stop()
	# --- Caption (banter)
	caption_panel = PanelContainer.new()
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_panel.visible = false
	caption_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.98, 0.95, 0.86, 0.95), 16, UiTheme.EMERALD, 2))
	add_child(caption_panel)
	caption_label = UiTheme.label("", 21, UiTheme.INK)
	caption_panel.add_child(caption_label)
	# --- Toast (new bowler, weather notes)
	toast = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.visible = false
	toast.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.82, 0.41, 0.27, 0.95), 14, UiTheme.GOLD, 2))
	add_child(toast)
	toast_label = UiTheme.label("", 20, UiTheme.OFF_WHITE)
	toast.add_child(toast_label)
	# --- Hint
	hint_label = UiTheme.label("", 24, UiTheme.OFF_WHITE)
	hint_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	hint_label.add_theme_constant_override("outline_size", 7)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_label)
	# --- Swing button (bottom right, thumb reach)
	swing_btn = SwingButton.new()
	swing_btn.swing_pressed.connect(func(): swing_pressed.emit())
	add_child(swing_btn)
	replay_btn = UiTheme.button("Replay", 22, 150)
	replay_btn.visible = false
	replay_btn.pressed.connect(func(): replay_pressed.emit())
	add_child(replay_btn)
	replay_tag = UiTheme.label("REPLAY  -  tap to skip", 26, UiTheme.GOLD, "black")
	replay_tag.add_theme_color_override("font_outline_color", UiTheme.INK)
	replay_tag.add_theme_constant_override("outline_size", 6)
	replay_tag.visible = false
	add_child(replay_tag)
	debug_label = UiTheme.label("", 16, Color(0.8, 1.0, 0.8), "regular")
	debug_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	debug_label.add_theme_constant_override("outline_size", 4)
	debug_label.visible = false
	add_child(debug_label)
	c.ball_settled.connect(_on_settled)
	c.timing_revealed.connect(_on_timing)
	c.delivery_started.connect(_on_delivery)
	c.swing_feedback.connect(_on_swing_feedback)
	c.phase_changed.connect(_on_phase)
	resized.connect(_layout)
	_layout()


func set_stance_available(on: bool) -> void:
	stance_unlocked = on


func set_muted(m: bool) -> void:
	mute_btn.set_kind("sound_off" if m else "sound_on")


func _is_classic() -> bool:
	return controller.rules != null and controller.rules.mode == MatchRules.CLASSIC


func _layout() -> void:
	var m := 16.0
	var s := size
	var ss := score_panel.get_combined_minimum_size()
	score_panel.size = ss
	score_panel.position = Vector2((s.x - ss.x) * 0.5, m)
	bowler_panel.size = bowler_panel.get_combined_minimum_size()
	bowler_panel.position = Vector2(m, m)
	var bs := buttons.get_combined_minimum_size()
	buttons.position = Vector2(s.x - bs.x - m, m)
	minimap.size = Vector2(210, 150)
	minimap.position = Vector2(s.x - 210.0 - m, m + 72.0)
	swing_btn.size = Vector2(190, 190)
	swing_btn.position = Vector2(s.x - 190.0 - m, s.y - 190.0 - m)
	hint_label.size = Vector2(s.x, 40)
	hint_label.position = Vector2(0, s.y * 0.7)
	debug_label.position = Vector2(m, s.y * 0.42)
	if banner.visible:
		replay_btn.position = Vector2(s.x * 0.5 - 75.0, banner.position.y + banner.size.y + 12.0)
	else:
		replay_btn.position = Vector2(m, s.y - 58.0 - m)
	replay_tag.position = Vector2((s.x - replay_tag.get_combined_minimum_size().x) * 0.5, ss.y + 28.0)
	var ts := toast.get_combined_minimum_size()
	toast.size = ts
	toast.position = Vector2((s.x - ts.x) * 0.5, ss.y + 28.0)


func _process(_d: float) -> void:
	_layout()
	var now := Time.get_ticks_msec() / 1000.0
	if caption_panel.visible and now > _caption_until:
		caption_panel.visible = false
	if timing_panel.visible and now > _timing_until:
		timing_panel.visible = false
	if hint_label.text != "" and now > _hint_until:
		hint_label.text = ""
	if toast.visible and now > _toast_until:
		toast.visible = false
	if caption_panel.visible:
		var cs := caption_panel.get_combined_minimum_size()
		caption_panel.size = cs
		caption_panel.position = Vector2((size.x - cs.x) * 0.5, size.y - cs.y - 24.0)
	if banner.visible:
		var bs := banner.get_combined_minimum_size()
		banner.size = bs
		banner.position = Vector2((size.x - bs.x) * 0.5, size.y * 0.3)
	if timing_panel.visible:
		var ts := timing_panel.get_combined_minimum_size()
		timing_panel.size = ts
		var anchor := world.screen_of(Vector3(-1.0, -0.4, 2.6))
		timing_panel.position = Vector2(clampf(anchor.x - ts.x * 0.5, 16.0, size.x - ts.x - 16.0), clampf(anchor.y - ts.y, 200.0, size.y - ts.y - 16.0))
	# Swing button glows while the ball can actually be hit.
	var g := controller.gate
	var t := controller.clock.time
	var open := g.armed and g.swing_time < 0.0 and t >= g.open_time and t <= g.close_time and not controller.paused
	swing_btn.ready_glow = move_toward(swing_btn.ready_glow, 1.0 if open else 0.0, _d * 6.0)
	if show_debug and controller.delivery != null:
		debug_label.visible = true
		var info := controller.debug_info()
		debug_label.text = "FPS %d\nphase %s  t=%.3f\nseed %d  %s %.1f m/s len %.2f\nwindow [%.3f, %.3f] swing %.3f\ntiming %s dt=%.1f ms -> %s" % [
			Engine.get_frames_per_second(), info["phase"], info["clock"], info["seed"], controller.delivery.kind,
			controller.delivery.speed, controller.delivery.length, info["window"][0], info["window"][1], info["swing"],
			info["timing"], info["dt_ms"], info["outcome"]]
	else:
		debug_label.visible = false


func refresh() -> void:
	var st := controller.state
	if st == null:
		return
	var card := st.card
	var r := st.rules
	var classic := _is_classic()
	minimap.visible = not classic and controller.tutorial_level < 0
	card_btn.visible = not classic
	chase_label.visible = false
	if controller.tutorial_level >= 0:
		score_label.text = "Nets"
		sub_label.text = "Practice ball %d of %d" % [controller.tutorial_level + 1, DeliveryGenerator.TUTORIAL_SPEEDS.size()]
	elif classic:
		score_label.text = "%d" % card.runs if card.wickets == 0 else "%d / %d" % [card.runs, card.wickets]
		var left := r.max_wickets - card.wickets
		sub_label.text = "%d balls  -  %d wicket%s left  -  Best %d" % [card.legal_balls, left, "" if left == 1 else "s", maxi(best_runs, card.runs)]
	else:
		score_label.text = "%s  %d/%d" % [r.batting_short, card.runs, card.wickets]
		var overs := "Overs %s" % card.overs_text()
		if r.overs > 0:
			overs += " / %d" % r.overs
		sub_label.text = overs
		if r.target > 0 and not card.complete:
			chase_label.visible = true
			chase_label.text = "Need %d from %d" % [card.runs_needed, card.balls_left]
			if card.balls_left == 1:
				chase_label.text = "LAST BALL - need %d" % card.runs_needed
	if controller.profile != null:
		var p := controller.profile
		bowler_label.text = "%s \"%s\"" % [p.display_name, p.nickname]
		if controller.delivery != null:
			speed_label.text = "%s  -  %d km/h" % [p.style.capitalize(), controller.delivery.speed_kmh()]
	for ch in over_row.get_children():
		ch.queue_free()
	var syms: Array = card.this_over if card.legal_balls % 6 != 0 or controller.phase == MatchController.Phase.OUTCOME else []
	for i in 6:
		over_row.add_child(OverChip.make(syms[i] if i < syms.size() else ""))


func _on_phase(p: int) -> void:
	var outcome := p == MatchController.Phase.OUTCOME
	replay_btn.visible = outcome and controller.tutorial_level < 0 and controller.resolver != null
	replay_tag.visible = p == MatchController.Phase.REPLAY
	if p == MatchController.Phase.REPLAY:
		banner.visible = false
		timing_panel.visible = false
		truck.stop()
	elif outcome and controller.resolver != null and banner_title.text != "":
		banner.visible = true


func _on_delivery(info: Dictionary) -> void:
	banner.visible = false
	refresh()
	var p: BowlerProfile = info["bowler"]
	if _last_bowler != "" and p.id != _last_bowler and controller.tutorial_level < 0:
		show_toast("New bowler: %s \"%s\" - %s" % [p.display_name, p.nickname, p.cue_line])
	_last_bowler = p.id
	var first_time := not bool(_setting("tutorial_seen", false))
	var n: int = controller.state.events.size() if controller.state else 0
	guide.enabled = false
	if controller.tutorial_level >= 0:
		var msgs := ["Tap SWING (or anywhere, or Space) as the ball reaches the ring.",
			"Same again - tap as the ring closes.", "A little quicker now. No ring this time!"]
		hint(msgs[clampi(controller.tutorial_level, 0, 2)], 4.0)
		guide.enabled = controller.tutorial_level < 2
	elif _is_classic() and first_time and n < 3:
		guide.enabled = true
		if n == 0:
			hint("Tap SWING as the ball reaches the ring!", 4.0)
	elif controller.rules.mode == MatchRules.PRACTICE:
		guide.enabled = bool(_setting("timing_guide", true))


func _setting(key: String, def):
	var save := get_node_or_null("/root/Save")
	if save == null:
		return def
	if key == "tutorial_seen":
		return save.data.get("tutorial_done", false)
	return save.data["settings"].get(key, def)


func _on_swing_feedback(res: String) -> void:
	if res == "accepted":
		guide.tap_pulse_t = controller.clock.time
		swing_btn.accepted()
	elif res == "too_soon":
		hint("Wait for it...", 0.8)


func _on_timing(c: ContactResult) -> void:
	timing_label.text = c.timing_label()
	var col := UiTheme.GOLD
	if c.category in [ContactResult.MISS_EARLY, ContactResult.MISS_LATE, ContactResult.NONE]:
		col = UiTheme.OFF_WHITE
	timing_label.add_theme_color_override("font_color", col)
	timing_meter.set_value(c)
	timing_panel.visible = c.category != ContactResult.NONE
	_timing_until = Time.get_ticks_msec() / 1000.0 + 1.6


func _on_settled(o: BallOutcome, _card: Scorecard) -> void:
	refresh()
	var title := ""
	match o.kind:
		BallOutcome.SIX: title = "SIX!"
		BallOutcome.FOUR: title = "FOUR!"
		BallOutcome.BOWLED: title = "BOWLED"
		BallOutcome.CAUGHT: title = "CAUGHT"
		BallOutcome.RUNS: title = "%d RUN%s" % [o.runs, "" if o.runs == 1 else "S"]
		_: title = "DOT BALL"
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", UiTheme.GOLD if not o.wicket else UiTheme.OFF_WHITE)
	banner_sub.text = o.explanation
	# Boundaries get the truck instead of a big banner (less clutter, more fun).
	banner.visible = not o.is_boundary()
	if o.is_boundary():
		truck.play("six" if o.kind == BallOutcome.SIX else "four")
	minimap.shot_path = o.shot_points if o.shot_points.size() > 1 else []


func show_caption(text: String, speaker: String) -> void:
	caption_label.text = "%s:  %s" % [speaker, text]
	caption_panel.visible = true
	_caption_until = Time.get_ticks_msec() / 1000.0 + 2.8


func show_toast(text: String) -> void:
	toast_label.text = text
	toast.visible = true
	_toast_until = Time.get_ticks_msec() / 1000.0 + 3.0


func hint(text: String, seconds: float) -> void:
	hint_label.text = text
	_hint_until = Time.get_ticks_msec() / 1000.0 + seconds


func hide_transient() -> void:
	banner.visible = false
	timing_panel.visible = false
	caption_panel.visible = false
	toast.visible = false
	hint_label.text = ""
	truck.stop()

class_name Hud
extends Control
## Compact match HUD. Everything is derived from the authoritative Scorecard.

signal pause_pressed
signal mute_pressed
signal stance_changed(stance: int)
signal card_pressed

var controller: MatchController
var world: WorldView
var score_label: Label
var sub_label: Label
var chase_label: Label
var batters_label: Label
var bowler_label: Label
var over_row: HBoxContainer
var timing_panel: PanelContainer
var timing_label: Label
var timing_meter: TimingMeter
var banner: PanelContainer
var banner_title: Label
var banner_sub: Label
var caption_panel: PanelContainer
var caption_label: Label
var hint_label: Label
var stance_btn: Button
var swing_pad: SwingPad
var minimap: Minimap
var guide: GuideOverlay
var mute_btn: IconButton
var pause_btn: IconButton
var debug_label: Label
var show_debug := false
var _caption_until := 0.0
var _timing_until := 0.0
var _hint_until := 0.0
var stance := 0
var stance_unlocked := false


func build(c: MatchController, w: WorldView) -> void:
	controller = c
	world = w
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide = GuideOverlay.new()
	guide.world = w
	guide.controller = c
	add_child(guide)
	# --- Score panel (top-left)
	var sp := PanelContainer.new()
	sp.position = Vector2(0, 0)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	sp.add_child(sv)
	score_label = UiTheme.label("PIN 0/0", 40, UiTheme.OFF_WHITE, "black")
	sv.add_child(score_label)
	sub_label = UiTheme.label("Overs 0.0", 20, UiTheme.SAND)
	sv.add_child(sub_label)
	chase_label = UiTheme.label("", 20, UiTheme.GOLD)
	sv.add_child(chase_label)
	batters_label = UiTheme.label("", 19, UiTheme.OFF_WHITE, "regular")
	sv.add_child(batters_label)
	sp.set_meta("anchor", "tl")
	# --- Bowler + this over (top-centre)
	var bp := PanelContainer.new()
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bp)
	var bv := VBoxContainer.new()
	bp.add_child(bv)
	bowler_label = UiTheme.label("", 20, UiTheme.SAND)
	bowler_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(bowler_label)
	over_row = HBoxContainer.new()
	over_row.alignment = BoxContainer.ALIGNMENT_CENTER
	over_row.add_theme_constant_override("separation", 6)
	bv.add_child(over_row)
	bp.set_meta("anchor", "tc")
	# --- Buttons (top-right)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	add_child(br)
	var card_btn := IconButton.make("card", "Scorecard", 60)
	card_btn.pressed.connect(func(): card_pressed.emit())
	br.add_child(card_btn)
	mute_btn = IconButton.make("sound_on", "Mute / unmute", 60)
	mute_btn.pressed.connect(func(): mute_pressed.emit())
	br.add_child(mute_btn)
	pause_btn = IconButton.make("pause", "Pause", 60)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	br.add_child(pause_btn)
	br.set_meta("anchor", "tr")
	minimap = Minimap.new()
	minimap.world = w
	add_child(minimap)
	minimap.set_meta("anchor", "tr2")
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
	banner.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.02, 0.15, 0.12, 0.9), 18, UiTheme.GOLD, 3))
	add_child(banner)
	var bbox := VBoxContainer.new()
	banner.add_child(bbox)
	banner_title = UiTheme.label("", 56, UiTheme.GOLD, "black")
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bbox.add_child(banner_title)
	banner_sub = UiTheme.label("", 21, UiTheme.OFF_WHITE, "regular")
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.custom_minimum_size = Vector2(520, 0)
	bbox.add_child(banner_sub)
	# --- Caption (commentary / banter)
	caption_panel = PanelContainer.new()
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_panel.visible = false
	caption_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.98, 0.95, 0.86, 0.95), 16, UiTheme.EMERALD, 2))
	add_child(caption_panel)
	caption_label = UiTheme.label("", 22, UiTheme.INK)
	caption_panel.add_child(caption_label)
	# --- Hint
	hint_label = UiTheme.label("", 24, UiTheme.OFF_WHITE)
	hint_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint_label)
	# --- Stance toggle (bottom-left)
	stance_btn = UiTheme.button("Shot: AUTO", 22)
	stance_btn.pressed.connect(_cycle_stance)
	stance_btn.visible = false
	add_child(stance_btn)
	# --- Swing pad (bottom-right): visual affordance; tapping anywhere also swings.
	swing_pad = SwingPad.new()
	add_child(swing_pad)
	debug_label = UiTheme.label("", 16, Color(0.8, 1.0, 0.8), "regular")
	debug_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	debug_label.add_theme_constant_override("outline_size", 4)
	debug_label.visible = false
	add_child(debug_label)
	c.ball_settled.connect(_on_settled)
	c.timing_revealed.connect(_on_timing)
	c.delivery_started.connect(_on_delivery)
	c.swing_feedback.connect(_on_swing_feedback)
	resized.connect(_layout)
	_layout()


func _cycle_stance() -> void:
	stance = (stance + 1) % 3
	_update_stance_text()
	stance_changed.emit(stance)


func _update_stance_text() -> void:
	stance_btn.text = "Shot: " + ["AUTO", "GROUNDED", "LOFTED"][stance]


func set_stance_available(on: bool) -> void:
	stance_unlocked = on
	stance_btn.visible = on


func set_muted(m: bool) -> void:
	mute_btn.set_kind("sound_off" if m else "sound_on")


func _layout() -> void:
	var m := 16.0
	var s := size
	for c in get_children():
		if not (c is Control) or not c.has_meta("anchor"):
			continue
		var cs: Vector2 = c.get_combined_minimum_size()
		match String(c.get_meta("anchor")):
			"tl": c.position = Vector2(m, m)
			"tc": c.position = Vector2((s.x - cs.x) * 0.5, m)
			"tr": c.position = Vector2(s.x - cs.x - m, m)
			"tr2": c.position = Vector2(s.x - 210.0 - m, m + 72.0)
	minimap.size = Vector2(210, 150)
	stance_btn.position = Vector2(m, s.y - 58.0 - m)
	swing_pad.size = Vector2(150, 150)
	swing_pad.position = Vector2(s.x - 150.0 - m * 2.0, s.y - 150.0 - m * 2.0)
	hint_label.size = Vector2(s.x, 40)
	hint_label.position = Vector2(0, s.y * 0.72)
	debug_label.position = Vector2(m, s.y * 0.42)


func _process(_d: float) -> void:
	_layout()
	var now := Time.get_ticks_msec() / 1000.0
	if caption_panel.visible and now > _caption_until:
		caption_panel.visible = false
	if timing_panel.visible and now > _timing_until:
		timing_panel.visible = false
	if hint_label.text != "" and now > _hint_until:
		hint_label.text = ""
	if caption_panel.visible:
		var cs := caption_panel.get_combined_minimum_size()
		caption_panel.size = cs
		caption_panel.position = Vector2((size.x - cs.x) * 0.5, size.y - cs.y - 24.0)
	if banner.visible:
		var bs := banner.get_combined_minimum_size()
		banner.size = bs
		banner.position = Vector2((size.x - bs.x) * 0.5, size.y * 0.2)
	if timing_panel.visible:
		var ts := timing_panel.get_combined_minimum_size()
		timing_panel.size = ts
		var anchor := world.screen_of(Vector3(-1.0, -0.4, 2.6))
		timing_panel.position = Vector2(clampf(anchor.x - ts.x * 0.5, 16.0, size.x - ts.x - 16.0), clampf(anchor.y - ts.y, 200.0, size.y - ts.y - 16.0))
	if show_debug and controller.delivery != null:
		debug_label.visible = true
		var info := controller.debug_info()
		debug_label.text = "FPS %d  frame %.1f ms\nphase %s  t=%.3f\nseed %d  %s %.1f m/s len %.2f\nwindow [%.3f, %.3f] swing %.3f\ntiming %s dt=%.1f ms -> %s" % [
			Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second()), info["phase"], info["clock"],
			info["seed"], controller.delivery.kind, controller.delivery.speed, controller.delivery.length,
			info["window"][0], info["window"][1], info["swing"], info["timing"], info["dt_ms"], info["outcome"]]
	else:
		debug_label.visible = false


func refresh() -> void:
	var st := controller.state
	if st == null:
		return
	var card := st.card
	var r := st.rules
	if controller.tutorial_level >= 0:
		score_label.text = "Nets"
		sub_label.text = "Tutorial ball %d of %d" % [controller.tutorial_level + 1, DeliveryGenerator.TUTORIAL_SPEEDS.size()]
		chase_label.text = ""
		batters_label.text = ""
	else:
		score_label.text = "%s  %d/%d" % [r.batting_short, card.runs, card.wickets]
		var overs := "Overs %s" % card.overs_text()
		if r.overs > 0:
			overs += " / %d" % r.overs
		if r.mode == MatchRules.PRACTICE:
			overs = "Practice  -  %d balls  -  %d sixes, %d fours" % [card.legal_balls, card.sixes, card.fours]
		elif r.mode == MatchRules.ENDLESS:
			overs += "   One wicket"
		sub_label.text = overs
		if r.target > 0 and not card.complete:
			var rr := Overs.required_rate(card.runs_needed, card.balls_left)
			chase_label.text = "Challenge target %d  -  need %d from %d%s" % [r.target, card.runs_needed, card.balls_left,
				"  (RRR %s)" % Overs.rate_text(rr) if rr > 0 else ""]
			if card.balls_left == 1:
				chase_label.text = "LAST BALL  -  need %d" % card.runs_needed
			elif card.balls_left <= 6:
				chase_label.text = "LAST OVER  -  " + chase_label.text
		else:
			chase_label.text = ""
		var bl := "> " + card.striker_line()
		if card.non_striker >= 0:
			bl += "      " + card.non_striker_line()
		batters_label.text = bl
	if controller.profile != null:
		var p := controller.profile
		var kmh := controller.delivery.speed_kmh() if controller.delivery else 0
		bowler_label.text = "%s \"%s\"  -  %s" % [p.display_name, p.nickname, p.style]
	for ch in over_row.get_children():
		ch.queue_free()
	var syms: Array = card.this_over if card.legal_balls % 6 != 0 or controller.phase == MatchController.Phase.OUTCOME else []
	for i in 6:
		var sym: String = syms[i] if i < syms.size() else ""
		over_row.add_child(OverChip.make(sym))


func _on_delivery(_info: Dictionary) -> void:
	banner.visible = false
	refresh()
	swing_pad.visible = controller.tutorial_level >= 0 or (controller.state and controller.state.events.size() < 3)
	if controller.tutorial_level >= 0:
		var msgs := ["Tap anywhere (or press Space) when the ball reaches the ring.",
			"Same again - tap as the ring closes.", "A little quicker now. No ring this time!"]
		hint(msgs[clampi(controller.tutorial_level, 0, 2)], 4.0)
		guide.enabled = controller.tutorial_level < 2
	else:
		guide.enabled = controller.rules.mode == MatchRules.PRACTICE and bool(_setting("timing_guide", true))


func _setting(key: String, def):
	var save := get_node_or_null("/root/Save")
	return save.data["settings"].get(key, def) if save else def


func _on_swing_feedback(res: String) -> void:
	if res == "accepted":
		guide.tap_pulse_t = controller.clock.time
		swing_pad.pulse()
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
	banner_sub.text = o.explanation + "\nTap to continue"
	banner.visible = true
	if o.shot_points.size() > 1:
		minimap.shot_path = o.shot_points
	else:
		minimap.shot_path = []


func show_caption(text: String, speaker: String) -> void:
	caption_label.text = "%s:  %s" % [speaker, text]
	caption_panel.visible = true
	_caption_until = Time.get_ticks_msec() / 1000.0 + 2.8


func hint(text: String, seconds: float) -> void:
	hint_label.text = text
	_hint_until = Time.get_ticks_msec() / 1000.0 + seconds


func hide_transient() -> void:
	banner.visible = false
	timing_panel.visible = false
	caption_panel.visible = false
	hint_label.text = ""

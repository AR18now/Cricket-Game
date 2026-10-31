class_name MainMenu
extends Control
## The welcome screen: the living ground behind, a friendly greeting, your best score and
## one big PLAY. Only one optional choice (time of day / weather) - everything else is
## automatic (bowlers mix fast and spin by themselves; the camera follows how the phone is
## held) or tucked away in Settings.
##  Landscape: a card on the left, the ground visible on the right.
##  Portrait: the logo at the top, the ground in the middle, the card at the bottom (thumb).

signal play_pressed
signal settings_pressed
signal mute_pressed
signal option_changed(key: String, value: String)


var play_btn: Button
var best_label: Label
var mute_btn: IconButton
var chips := {}
var reduced_motion := false
var portrait := false
var _pulse: Tween
var _values := {"time_of_day": "evening", "theme": "emerald"}
var _shade: MenuShade
var _card: PanelContainer
var _logo_top: TitleMark      # portrait: logo above the scene
var _logo_card: TitleMark     # landscape: logo inside the card
var _greet: Label
var _best_box: PanelContainer
var _best_num: Label
var _best_sub: Label
var _foot: Label
var _top_right: HBoxContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func build() -> void:
	_shade = MenuShade.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_logo_top = TitleMark.new()
	_logo_top.custom_minimum_size = Vector2(520, 140)
	_logo_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo_top)
	# --- The card
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.panel_bg(0.84), 30, UiTheme.GOLD.darkened(0.25), 2))
	add_child(_card)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 26)
	_card.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	m.add_child(col)
	_logo_card = TitleMark.new()
	_logo_card.custom_minimum_size = Vector2(440, 118)
	_logo_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_logo_card)
	_greet = UiTheme.label("", 30, UiTheme.OFF_WHITE, "black")
	_greet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_greet)
	# Best score badge (or a friendly first-time tip).
	_best_box = PanelContainer.new()
	_best_box.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.99, 0.79, 0.33, 0.12), 18, UiTheme.GOLD.darkened(0.1), 2))
	col.add_child(_best_box)
	var bb := HBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_CENTER
	bb.add_theme_constant_override("separation", 14)
	_best_box.add_child(bb)
	var best_tag := UiTheme.label("BEST", 20, UiTheme.GOLD, "black")
	bb.add_child(best_tag)
	_best_num = UiTheme.label("", 40, UiTheme.GOLD, "black")
	bb.add_child(_best_num)
	_best_sub = UiTheme.label("", 20, UiTheme.SAND, "regular")
	bb.add_child(_best_sub)
	best_label = UiTheme.label("", 21, UiTheme.SAND, "regular")
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(best_label)
	# PLAY
	play_btn = UiTheme.button("PLAY", 54, 420)
	play_btn.custom_minimum_size = Vector2(420, 112)
	var sb := UiTheme.panel_box(UiTheme.TERRACOTTA, 30, UiTheme.GOLD, 4)
	play_btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = UiTheme.TERRACOTTA.lightened(0.12)
	play_btn.add_theme_stylebox_override("hover", sbh)
	play_btn.add_theme_stylebox_override("pressed", sbh)
	play_btn.add_theme_stylebox_override("focus", sbh)
	play_btn.pressed.connect(func(): _tap(); play_pressed.emit())
	col.add_child(play_btn)
	# Two optional choices: time of day / weather, and the colour theme.
	var pills := HBoxContainer.new()
	pills.alignment = BoxContainer.ALIGNMENT_CENTER
	pills.add_theme_constant_override("separation", 12)
	col.add_child(pills)
	for key in ["time_of_day", "theme"]:
		var tb := UiTheme.button("", 20, 230)
		tb.custom_minimum_size = Vector2(230, 54)
		tb.add_theme_stylebox_override("normal", UiTheme.panel_box(Color(1, 1, 1, 0.08), 27, Color(1, 1, 1, 0.25), 1))
		var k: String = key
		tb.pressed.connect(func(): _cycle(k))
		pills.add_child(tb)
		chips[key] = tb
	# --- Top-right: sound + settings
	_top_right = HBoxContainer.new()
	_top_right.add_theme_constant_override("separation", 10)
	add_child(_top_right)
	mute_btn = IconButton.make("sound_on", "Mute / unmute", 64)
	mute_btn.pressed.connect(func(): mute_pressed.emit())
	_top_right.add_child(mute_btn)
	var gear := IconButton.make("gear", "Settings", 64)
	gear.pressed.connect(func(): _tap(); settings_pressed.emit())
	_top_right.add_child(gear)
	_foot = UiTheme.label("Offline - no account, no ads", 16, Color(1, 1, 1, 0.65), "regular")
	add_child(_foot)
	_update_chips()
	start_pulse()


## Gentle "breathing" on the PLAY button so the main action is obvious.
func start_pulse() -> void:
	if _pulse:
		_pulse.kill()
	play_btn.scale = Vector2.ONE
	if reduced_motion:
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(play_btn, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(play_btn, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


func _cycle(key: String) -> void:
	_tap()
	var list: Array = Atmosphere.IDS if key == "time_of_day" else UiTheme.THEME_IDS
	var i := list.find(_values[key])
	_values[key] = list[(i + 1) % list.size()]
	_update_chips()
	var b: Button = chips[key]
	if not reduced_motion:
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(0.9, 0.9)
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	option_changed.emit(key, _values[key])


func _update_chips() -> void:
	if chips.is_empty():
		return
	chips["time_of_day"].text = "Time: %s  >" % Atmosphere.LABELS[_values["time_of_day"]]
	chips["theme"].text = "Theme: %s  >" % UiTheme.theme_label(_values["theme"])


func _tap() -> void:
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play("ui_tap", "UI", -6.0)


func refresh(save_data: Dictionary) -> void:
	var b: Dictionary = save_data["best"]
	var s: Dictionary = save_data["settings"]
	_values["time_of_day"] = String(s.get("time_of_day", "evening"))
	_values["theme"] = String(s.get("theme", "emerald"))
	_update_chips()
	var played := int(b["classic_played"]) > 0
	_greet.text = "Welcome back!" if played else "Welcome!"
	_best_box.visible = played
	_best_num.text = str(int(b["classic_runs"]))
	_best_sub.text = "(%d balls)" % int(b["classic_balls"])
	best_label.text = "Ready to bat? Beat your best!" if played else "Tap PLAY and time your swing.\nThe first balls are gentle."
	mute_btn.set_kind("sound_off" if s["muted"] else "sound_on")


func _process(_d: float) -> void:
	_shade.portrait = portrait
	_top_right.position = Vector2(size.x - _top_right.get_combined_minimum_size().x - 20.0, 18.0)
	_logo_top.visible = portrait
	_logo_card.visible = not portrait
	var cs: Vector2
	if portrait:
		# Logo at the top, the living ground in the middle, the card at the bottom.
		var w := minf(size.x - 32.0, 600.0)
		_card.custom_minimum_size = Vector2(w, 0)
		play_btn.custom_minimum_size = Vector2(w - 52.0, 116)
		cs = _card.get_combined_minimum_size()
		_card.size = cs
		_card.position = Vector2((size.x - cs.x) * 0.5, size.y - cs.y - 58.0)
		var lw := minf(size.x - 40.0, 560.0)
		_logo_top.custom_minimum_size = Vector2(lw, lw * 0.27)
		_logo_top.size = _logo_top.custom_minimum_size
		_logo_top.position = Vector2((size.x - lw) * 0.5 + lw * 0.06, maxf(90.0, size.y * 0.09))
		_foot.position = Vector2((size.x - _foot.get_combined_minimum_size().x) * 0.5, size.y - 40.0)
	else:
		# A card on the left; the ground and the batter stay visible on the right.
		_card.custom_minimum_size = Vector2(520, 0)
		play_btn.custom_minimum_size = Vector2(468, 112)
		cs = _card.get_combined_minimum_size()
		_card.size = cs
		_card.position = Vector2(40.0, maxf(16.0, (size.y - cs.y) * 0.5))
		_foot.position = Vector2(48.0, size.y - 34.0)
	play_btn.pivot_offset = play_btn.size * 0.5

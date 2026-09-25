class_name MainMenu
extends Control
## Menu over the living ground. One big Play action; other modes one tap away.

signal play_pressed
signal mode_pressed(mode: String)
signal settings_pressed
signal mute_pressed

var play_btn: Button
var best_label: Label
var mute_btn: IconButton
var subtitle: Label


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func build() -> void:
	var shade := MenuShade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.position = Vector2(64, 64)
	col.name = "MenuColumn"
	add_child(col)
	var logo := TitleMark.new()
	logo.custom_minimum_size = Vector2(560, 150)
	col.add_child(logo)
	subtitle = UiTheme.label("From the neighbourhood pitch to the floodlights", 22, UiTheme.SAND, "regular")
	col.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap)
	play_btn = UiTheme.button("PLAY", 40, 380)
	play_btn.custom_minimum_size = Vector2(380, 92)
	var sb := UiTheme.panel_box(UiTheme.TERRACOTTA, 22, UiTheme.GOLD, 3)
	play_btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = UiTheme.TERRACOTTA.lightened(0.1)
	play_btn.add_theme_stylebox_override("hover", sbh)
	play_btn.add_theme_stylebox_override("pressed", sbh)
	play_btn.pressed.connect(func(): _tap(); play_pressed.emit())
	col.add_child(play_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for m in [["Quick Match", "quick"], ["Practice", "practice"], ["Endless", "endless"]]:
		var b := UiTheme.button(m[0], 22, 170)
		var id: String = m[1]
		b.pressed.connect(func(): _tap(); mode_pressed.emit(id))
		row.add_child(b)
	best_label = UiTheme.label("", 20, UiTheme.OFF_WHITE, "regular")
	col.add_child(best_label)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 10)
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-160, 20)
	add_child(tr)
	mute_btn = IconButton.make("sound_on", "Mute / unmute", 64)
	mute_btn.pressed.connect(func(): mute_pressed.emit())
	tr.add_child(mute_btn)
	var gear := IconButton.make("gear", "Settings", 64)
	gear.pressed.connect(func(): _tap(); settings_pressed.emit())
	tr.add_child(gear)
	var foot := UiTheme.label("Offline - no account needed.  A DevTorque game (working title).", 16, Color(1, 1, 1, 0.7), "regular")
	foot.name = "Foot"
	add_child(foot)


func _tap() -> void:
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play("ui_tap", "UI", -6.0)


func refresh(save_data: Dictionary) -> void:
	var b: Dictionary = save_data["best"]
	var parts: Array = []
	if int(b["endless_runs"]) > 0:
		parts.append("Endless best: %d" % int(b["endless_runs"]))
	if int(b["quick_played"]) > 0:
		parts.append("Quick Match wins: %d / %d" % [int(b["quick_wins"]), int(b["quick_played"])])
	best_label.text = "   ".join(parts)
	play_btn.text = "PLAY" if save_data["tutorial_done"] else "PLAY  -  first ball"
	mute_btn.set_kind("sound_off" if save_data["settings"]["muted"] else "sound_on")


func _process(_d: float) -> void:
	# Keep clusters anchored for any aspect ratio / safe area.
	for c in get_children():
		if c is HBoxContainer:
			c.position = Vector2(size.x - c.get_combined_minimum_size().x - 24.0, 20.0)
	var col := get_node("MenuColumn") as Control
	col.position = Vector2(64, maxf(24.0, (size.y - col.get_combined_minimum_size().y) * 0.42))
	var foot := get_node("Foot") as Control
	foot.position = Vector2(64, size.y - 40.0)

class_name MainMenu
extends Control
## One big PLAY over the living ground, plus three optional choices that remember
## themselves: bowlers (mixed / pace / spin), time & weather, and camera view.

signal play_pressed
signal settings_pressed
signal mute_pressed
signal option_changed(key: String, value: String)

const BOWLING := ["mixed", "pace", "spin"]
const BOWLING_LABEL := {"mixed": "Mixed", "pace": "Fast", "spin": "Spin"}
const VIEWS := ["batter", "side"]
const VIEW_LABEL := {"batter": "Batter's eye", "side": "Side-on"}

var play_btn: Button
var best_label: Label
var mute_btn: IconButton
var chips := {}
var _values := {"bowling": "mixed", "time_of_day": "evening", "view": "batter"}


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func build() -> void:
	var shade := MenuShade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.name = "MenuColumn"
	add_child(col)
	var logo := TitleMark.new()
	logo.custom_minimum_size = Vector2(560, 150)
	col.add_child(logo)
	col.add_child(UiTheme.label("From the neighbourhood pitch to the floodlights", 22, UiTheme.SAND, "regular"))
	play_btn = UiTheme.button("PLAY", 48, 420)
	play_btn.custom_minimum_size = Vector2(420, 104)
	var sb := UiTheme.panel_box(UiTheme.TERRACOTTA, 26, UiTheme.GOLD, 4)
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
	for key in ["bowling", "time_of_day", "view"]:
		var b := UiTheme.button("", 20, 132)
		b.custom_minimum_size = Vector2(132, 64)
		var k: String = key
		b.pressed.connect(func(): _cycle(k))
		row.add_child(b)
		chips[key] = b
	best_label = UiTheme.label("", 21, UiTheme.OFF_WHITE, "regular")
	col.add_child(best_label)
	var tr := HBoxContainer.new()
	tr.name = "TopRight"
	tr.add_theme_constant_override("separation", 10)
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
	_update_chips()


func _cycle(key: String) -> void:
	_tap()
	var list: Array = BOWLING if key == "bowling" else (Atmosphere.IDS if key == "time_of_day" else VIEWS)
	var i := list.find(_values[key])
	_values[key] = list[(i + 1) % list.size()]
	_update_chips()
	option_changed.emit(key, _values[key])


func _update_chips() -> void:
	if chips.is_empty():
		return
	chips["bowling"].text = "Bowlers\n" + BOWLING_LABEL[_values["bowling"]]
	chips["time_of_day"].text = "Time\n" + Atmosphere.LABELS[_values["time_of_day"]]
	chips["view"].text = "View\n" + VIEW_LABEL[_values["view"]]


func _tap() -> void:
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play("ui_tap", "UI", -6.0)


func refresh(save_data: Dictionary) -> void:
	var b: Dictionary = save_data["best"]
	var s: Dictionary = save_data["settings"]
	for k in _values.keys():
		_values[k] = String(s.get(k, _values[k]))
	_update_chips()
	best_label.text = "Best score: %d  (%d balls)" % [int(b["classic_runs"]), int(b["classic_balls"])] if int(b["classic_played"]) > 0 else "Tap PLAY - the first balls are gentle."
	mute_btn.set_kind("sound_off" if s["muted"] else "sound_on")


func _process(_d: float) -> void:
	var tr := get_node("TopRight") as Control
	tr.position = Vector2(size.x - tr.get_combined_minimum_size().x - 24.0, 20.0)
	var col := get_node("MenuColumn") as Control
	col.position = Vector2(64, maxf(24.0, (size.y - col.get_combined_minimum_size().y) * 0.42))
	var foot := get_node("Foot") as Control
	foot.position = Vector2(64, size.y - 40.0)

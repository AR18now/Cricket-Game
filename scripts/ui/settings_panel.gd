class_name SettingsPanel
extends OverlayPanel
## Persistent audio/accessibility settings.

signal closed
signal replay_tutorial
signal licences


func build() -> void:
	var save := get_node("/root/Save")
	title("Settings", 36)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for s in [["Master volume", "master"], ["Music", "music"], ["Sound effects", "sfx"], ["Commentary", "voice"]]:
		grid.add_child(UiTheme.label(s[0], 22))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(save.data["settings"][s[1]])
		sl.custom_minimum_size = Vector2(280, 36)
		var key: String = s[1]
		sl.value_changed.connect(func(v): save.set_setting(key, v))
		grid.add_child(sl)
	for s in [["Mute all", "muted"], ["Captions", "captions"], ["Reduced motion", "reduced_motion"], ["Vibration", "haptics"], ["Practice timing guide", "timing_guide"], ["Hints (HIT NOW cue)", "hints"]]:
		grid.add_child(UiTheme.label(s[0], 22))
		var cb := CheckButton.new()
		cb.button_pressed = bool(save.data["settings"][s[1]])
		var key2: String = s[1]
		cb.toggled.connect(func(v): save.set_setting(key2, v))
		grid.add_child(cb)
	grid.add_child(UiTheme.label("Theme", 22))
	var th := Button.new()
	th.text = UiTheme.theme_label(String(save.data["settings"].get("theme", "emerald")))
	th.pressed.connect(func():
		var cur := UiTheme.THEME_IDS.find(String(save.data["settings"].get("theme", "emerald")))
		var next: String = UiTheme.THEME_IDS[(cur + 1) % UiTheme.THEME_IDS.size()]
		save.set_setting("theme", next)
		th.text = UiTheme.theme_label(next))
	grid.add_child(th)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	var rt := UiTheme.button("Replay tutorial", 20, 180)
	rt.pressed.connect(func(): replay_tutorial.emit())
	row.add_child(rt)
	var lic := UiTheme.button("Credits & licences", 18, 200)
	lic.pressed.connect(func(): licences.emit())
	row.add_child(lic)
	var done := UiTheme.button("Done", 22, 160)
	done.pressed.connect(func(): closed.emit())
	row.add_child(done)
	done.call_deferred("grab_focus")


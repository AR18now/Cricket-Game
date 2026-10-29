class_name LicencesPanel
extends OverlayPanel
## Credits and the licence notices that must ship with the app: Godot Engine (MIT, plus
## its third-party components) and the Lato font (SIL OFL 1.1). Everything else in the
## game (art, sounds, music, placeholder voices) was made for it.

signal closed


func build() -> void:
	title("Credits & licences", 32)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(minf(600.0, get_viewport_rect().size.x - 80.0), minf(420.0, get_viewport_rect().size.y - 220.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 15)
	text.text = notices()
	scroll.add_child(text)
	var done := UiTheme.button("Done", 24, 220)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func(): closed.emit())
	body.add_child(done)
	done.call_deferred("grab_focus")


static func notices() -> String:
	var parts: Array[String] = []
	parts.append("Pocket Boundary - a cricket game made for this project. Characters, grounds, art, sound effects, music and placeholder commentary voices were created for the game (voices synthesised with eSpeak NG).")
	parts.append("Made with Godot Engine (godotengine.org).\n\n" + Engine.get_license_text())
	var tp := []
	for c in Engine.get_copyright_info():
		var names := []
		for part in c["parts"]:
			names.append(", ".join(part["copyright"]) + " (" + String(part["license"]) + ")")
		tp.append("- %s: %s" % [c["name"], "; ".join(names)])
	parts.append("Godot third-party components:\n" + "\n".join(tp))
	var ofl := ""
	var f := FileAccess.open("res://assets/fonts/OFL.txt", FileAccess.READ)
	if f:
		ofl = f.get_as_text()
	parts.append("Lato font by Lukasz Dziedzic, licensed under the SIL Open Font License 1.1.\n\n" + ofl)
	return "\n\n".join(parts)

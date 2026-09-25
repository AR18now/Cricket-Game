class_name PauseMenu
extends OverlayPanel

signal resume
signal settings
signal quit_to_menu
signal restart


func build(summary: String) -> void:
	title("Paused", 44)
	var s := UiTheme.label(summary, 20, UiTheme.SAND, "regular")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(s)
	var r := add_button("Resume", func(): resume.emit(), 28)
	add_button("Restart match", func(): restart.emit())
	add_button("Settings", func(): settings.emit())
	add_button("Main menu", func(): quit_to_menu.emit())
	r.call_deferred("grab_focus")

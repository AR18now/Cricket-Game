class_name GuideOverlay
extends Control
## Practice/tutorial timing guide: a ring that closes onto the hitting zone exactly when
## a tap would produce ideal contact. Also shows the accepted-input pulse on the batter.

var world: WorldView
var controller: MatchController
var enabled := true
var tap_pulse_t := -10.0
var shot_guide := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if controller == null or controller.delivery == null or world.menu_mode:
		return
	var t := controller.clock.time
	var tuning := controller.tuning
	var d := controller.delivery
	var ideal_tap := d.time_at_x(tuning.contact_x_ideal) - tuning.swing_to_contact
	var zone := world.screen_of(Vector3(tuning.contact_x_ideal, 0.0, d.pos_at(ideal_tap + tuning.swing_to_contact).z))
	var z := world.cam.zoom.x
	if enabled and controller.resolver == null and controller.phase in [MatchController.Phase.RUNUP, MatchController.Phase.FLIGHT]:
		var lead := ideal_tap - t
		if lead < 1.0 and lead > -0.05:
			var r := 16.0 + maxf(0.0, lead) * 160.0
			var a := clampf(1.0 - lead, 0.2, 1.0)
			draw_arc(zone, r, 0.0, TAU, 48, Color(1.0, 0.85, 0.35, a), 4.0, true)
			draw_arc(zone, 16.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 3.0, true)
			if lead < 0.06:
				draw_circle(zone, 16.0, Color(1.0, 0.85, 0.35, 0.35))
	# Accepted-input feedback: a quick ring on the batter so a tap never feels ignored.
	var age := t - tap_pulse_t
	if age >= 0.0 and age < 0.3:
		var bp := world.screen_of(Vector3(-1.0, -0.4, 1.0))
		draw_arc(bp, 30.0 + age * 120.0, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - age / 0.3)), 3.0, true)

class_name RunInset
extends Control
## Picture-in-picture close-up of the batsmen running between the wickets, shown while
## the main (wide) camera follows the ball. A second camera on the same 2D world:
## only drawn while the batsmen are running.

const ZOOM := 1.05
var world: WorldView
var _sub: SubViewport
var _cam: Camera2D
var _shown := false
var _alpha := 0.0
var reduced_motion := false


func setup(w: WorldView) -> void:
	world = w
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.GOLD, 16, UiTheme.GOLD, 0))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 4
	box.offset_top = 4
	box.offset_right = -4
	box.offset_bottom = -4
	add_child(box)
	_sub = SubViewport.new()
	_sub.world_2d = w.get_viewport().world_2d   # same world, own camera
	_sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sub.disable_3d = true
	_sub.handle_input_locally = false
	_sub.gui_disable_input = true
	box.add_child(_sub)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(ZOOM, ZOOM)
	_sub.add_child(_cam)   # the only camera in this viewport, so it is the current one
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.GOLD, 8, UiTheme.GOLD, 0))
	var tag := UiTheme.label(" RUNNING ", 17, UiTheme.INK, "black")
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(tag)
	chip.position = Vector2(12, 10)
	add_child(chip)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	if world == null:
		return
	var want := world.running_now()
	if want != _shown:
		_shown = want
		_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS if want else SubViewport.UPDATE_DISABLED
		if want:
			visible = true
			_cam.position = _focus()
			_cam.reset_smoothing()
	var target := 1.0 if _shown else 0.0
	_alpha = target if reduced_motion else move_toward(_alpha, target, delta / 0.2)
	modulate.a = _alpha
	if _alpha <= 0.0 and not _shown:
		visible = false
		return
	# Locked on your batsman (the striker), who moves smoothly anyway - no lag.
	_cam.position = _focus()


func _focus() -> Vector2:
	return world.striker.position + Vector2(0, -42)   # centre of the figure

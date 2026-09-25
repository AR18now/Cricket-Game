class_name OverlayPanel
extends Control
## Full-screen dimmed overlay hosting a centred panel. Blocks gameplay input while open.

var panel: PanelContainer
var body: VBoxContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.06, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.02, 0.16, 0.12, 0.97), 22, UiTheme.GOLD.darkened(0.2), 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)


func title(text: String, size: int = 40) -> Label:
	var l := UiTheme.label(text, size, UiTheme.GOLD, "black")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)
	return l


func add_button(text: String, cb: Callable, size: int = 26) -> Button:
	var b := UiTheme.button(text, size, 360)
	b.pressed.connect(func():
		var a := get_node_or_null("/root/Audio")
		if a: a.play("ui_tap", "UI", -6.0)
		cb.call())
	body.add_child(b)
	return b

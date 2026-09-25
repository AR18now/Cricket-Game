class_name OnboardingPanel
extends OverlayPanel
## Offered only after the first challenge: display name + kit colour, with defaults + Skip.

signal done(name: String, kit: int)

const KITS := [Color(0.03, 0.42, 0.32), Color(0.8, 0.4, 0.25), Color(0.2, 0.36, 0.7), Color(0.55, 0.2, 0.38), Color(0.12, 0.12, 0.14)]
const KIT_NAMES := ["Emerald", "Terracotta", "Indigo", "Plum", "Charcoal"]

var name_edit: LineEdit
var kit := 0


func build(current: String, current_kit: int) -> void:
	kit = current_kit
	title("Your cricketer", 38)
	var hint := UiTheme.label("Optional - stays on this device only.", 18, UiTheme.SAND, "regular")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(hint)
	name_edit = LineEdit.new()
	name_edit.text = current
	name_edit.max_length = 16
	name_edit.placeholder_text = "Display name"
	name_edit.custom_minimum_size = Vector2(380, 54)
	body.add_child(name_edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var kit_label := UiTheme.label("Kit: " + KIT_NAMES[kit], 20)
	for i in KITS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		b.tooltip_text = KIT_NAMES[i]
		b.add_theme_stylebox_override("normal", UiTheme.panel_box(KITS[i], 28, UiTheme.OFF_WHITE, 2))
		b.add_theme_stylebox_override("hover", UiTheme.panel_box(KITS[i].lightened(0.15), 28, UiTheme.GOLD, 4))
		var idx := i
		b.pressed.connect(func():
			kit = idx
			kit_label.text = "Kit: " + KIT_NAMES[idx])
		row.add_child(b)
	kit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(kit_label)
	var br := HBoxContainer.new()
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_theme_constant_override("separation", 12)
	body.add_child(br)
	var skip := UiTheme.button("Skip", 24, 180)
	skip.pressed.connect(func(): done.emit(current, current_kit))
	br.add_child(skip)
	var ok := UiTheme.button("Save", 24, 180)
	ok.pressed.connect(func():
		var n := name_edit.text.strip_edges()
		done.emit(n if n != "" else current, kit))
	br.add_child(ok)

class_name UiTheme
extends RefCounted
## Palette + Theme built in code (see docs/STYLE_GUIDE.md).

const EMERALD := Color(0.03, 0.36, 0.27)
const EMERALD_DEEP := Color(0.02, 0.17, 0.13)
const SAND := Color(0.95, 0.87, 0.7)
const OFF_WHITE := Color(0.98, 0.97, 0.93)
const TERRACOTTA := Color(0.82, 0.41, 0.27)
const GOLD := Color(0.99, 0.79, 0.33)
const INK := Color(0.08, 0.07, 0.06)
const PANEL := Color(0.02, 0.15, 0.12, 0.88)
const DANGER := Color(0.86, 0.3, 0.24)

static var _font_black: Font
static var _font_bold: Font
static var _font_regular: Font


static func font(weight: String = "bold") -> Font:
	if _font_bold == null:
		_font_black = load("res://assets/fonts/Lato-Black.ttf")
		_font_bold = load("res://assets/fonts/Lato-Bold.ttf")
		_font_regular = load("res://assets/fonts/Lato-Regular.ttf")
	match weight:
		"black": return _font_black
		"regular": return _font_regular
	return _font_bold


static func panel_box(bg: Color = PANEL, radius: int = 14, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font("bold")
	t.default_font_size = 22
	var normal := panel_box(EMERALD, 16, GOLD.darkened(0.3), 2)
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	var hover := normal.duplicate()
	hover.bg_color = EMERALD.lightened(0.12)
	hover.border_color = GOLD
	var pressed := normal.duplicate()
	pressed.bg_color = EMERALD_DEEP
	pressed.border_color = GOLD
	var focus := normal.duplicate()
	focus.draw_center = false
	focus.border_color = GOLD
	focus.set_border_width_all(4)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.2, 0.22, 0.21, 0.8)
	disabled.border_color = Color(0.4, 0.4, 0.4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", OFF_WHITE)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", OFF_WHITE)
	t.set_font_size("font_size", "Button", 24)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_color("font_color", "Label", OFF_WHITE)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	# Sliders / checks
	var grab := StyleBoxFlat.new()
	grab.bg_color = GOLD
	grab.set_corner_radius_all(10)
	var track := panel_box(Color(1, 1, 1, 0.18), 6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := panel_box(GOLD.darkened(0.15), 6)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var le := panel_box(Color(1, 1, 1, 0.1), 10, GOLD.darkened(0.3), 2)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", panel_box(Color(1, 1, 1, 0.14), 10, GOLD, 2))
	t.set_color("font_color", "LineEdit", OFF_WHITE)
	t.set_font_size("font_size", "LineEdit", 26)
	t.set_color("font_color", "CheckButton", OFF_WHITE)
	t.set_color("font_hover_color", "CheckButton", GOLD)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", panel_box(Color(0, 0, 0, 0), 8, GOLD, 2))
	t.set_stylebox("panel", "TabContainer", panel_box(Color(0, 0, 0, 0.0)))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


static func label(text: String, size: int = 22, color: Color = OFF_WHITE, weight: String = "bold") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, size: int = 24, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(min_w, 58)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func signed_rate(v: float) -> String:
	return Overs.rate_text(v)

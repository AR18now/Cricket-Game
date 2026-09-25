class_name OverChip
extends PanelContainer
## One ball of the current over. Uses text + shape (not colour alone).


static func make(sym: String) -> OverChip:
	var c := OverChip.new()
	c.custom_minimum_size = Vector2(38, 38)
	var bg := Color(1, 1, 1, 0.08)
	var fg := UiTheme.OFF_WHITE
	var border := Color(1, 1, 1, 0.25)
	match sym:
		"W":
			bg = UiTheme.DANGER
			border = UiTheme.OFF_WHITE
		"4", "6":
			bg = UiTheme.GOLD
			fg = UiTheme.INK
			border = UiTheme.OFF_WHITE
		"":
			pass
		_:
			bg = UiTheme.EMERALD
	c.add_theme_stylebox_override("panel", UiTheme.panel_box(bg, 19, border, 2))
	var l := UiTheme.label("-" if sym == "." else sym, 18, fg, "black")
	if sym == "":
		l.text = " "
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c

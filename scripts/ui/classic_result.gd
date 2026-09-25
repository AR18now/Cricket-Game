class_name ClassicResult
extends OverlayPanel
## Simple, celebratory end-of-innings screen for the main mode. One big "Play again".

signal play_again
signal to_menu


func build(state: MatchState, prev_best: int, venue: VenueConfig) -> void:
	var card := state.card
	var new_best := card.runs > prev_best and card.runs > 0
	var t := title("NEW BEST!" if new_best else "INNINGS OVER", 40)
	if not new_best:
		t.add_theme_color_override("font_color", UiTheme.SAND)
	var big := UiTheme.label(str(card.runs), 96, UiTheme.GOLD, "black")
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(big)
	var line := UiTheme.label("runs from %d balls   -   %d x 4   %d x 6   -   Best %d" % [card.legal_balls, card.fours, card.sixes, maxi(prev_best, card.runs)], 22, UiTheme.OFF_WHITE, "regular")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(line)
	var how := ""
	for b in card.batters:
		if b["out"]:
			how += "%s %d (%d) - %s\n" % [b["name"], b["runs"], b["balls"], b["how"]]
	var hl := UiTheme.label(how.strip_edges(), 18, UiTheme.SAND, "regular")
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(hl)
	var map := ShotMap.new()
	map.events = state.events
	map.venue = venue
	map.custom_minimum_size = Vector2(300, 150)
	var mc := CenterContainer.new()
	mc.add_child(map)
	body.add_child(mc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var again := UiTheme.button("PLAY AGAIN", 32, 300)
	again.custom_minimum_size = Vector2(300, 80)
	var sb := UiTheme.panel_box(UiTheme.TERRACOTTA, 22, UiTheme.GOLD, 3)
	again.add_theme_stylebox_override("normal", sb)
	again.add_theme_stylebox_override("hover", sb)
	again.pressed.connect(func(): play_again.emit())
	row.add_child(again)
	var menu := UiTheme.button("Menu", 24, 160)
	menu.custom_minimum_size = Vector2(160, 80)
	menu.pressed.connect(func(): to_menu.emit())
	row.add_child(menu)
	again.call_deferred("grab_focus")

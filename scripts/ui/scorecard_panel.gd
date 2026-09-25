class_name ScorecardPanel
extends OverlayPanel
## Full scorecard / result view, derived entirely from the event log.

signal play_again
signal to_menu
signal closed


func build(state: MatchState, final: bool, headline: String = "") -> void:
	var card := state.card
	var r := state.rules
	if final:
		var t := title(headline if headline != "" else _result_title(card), 44)
		if card.result == "lost":
			t.add_theme_color_override("font_color", UiTheme.OFF_WHITE)
		var sub := UiTheme.label(card.result_text if card.result_text != "" else "", 21, UiTheme.SAND, "regular")
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(sub)
	else:
		title("Scorecard", 34)
	var head := UiTheme.label("%s   %d/%d  (%s ov)%s" % [r.batting_team, card.runs, card.wickets, card.overs_text(),
		("     Challenge target: %d" % r.target) if r.target > 0 else ""], 24)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(head)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	body.add_child(cols)
	# Batting
	var bat := GridContainer.new()
	bat.columns = 7
	bat.add_theme_constant_override("h_separation", 14)
	for h in ["Batter", "", "R", "B", "4s", "6s", "SR"]:
		bat.add_child(UiTheme.label(h, 17, UiTheme.GOLD))
	for b in card.batters:
		var how := "not out" if not b["out"] else String(b["how"])
		if not b["batted"]:
			how = "did not bat"
		bat.add_child(UiTheme.label(String(b["name"]), 19))
		bat.add_child(UiTheme.label(how, 15, UiTheme.SAND, "regular"))
		for v in [b["runs"], b["balls"], b["fours"], b["sixes"]]:
			bat.add_child(UiTheme.label(str(v) if b["batted"] else "-", 19, UiTheme.OFF_WHITE, "regular"))
		bat.add_child(UiTheme.label(Overs.rate_text(Overs.strike_rate(b["runs"], b["balls"])) if b["batted"] else "-", 19, UiTheme.OFF_WHITE, "regular"))
	cols.add_child(bat)
	var right := VBoxContainer.new()
	cols.add_child(right)
	var bowl := GridContainer.new()
	bowl.columns = 5
	bowl.add_theme_constant_override("h_separation", 14)
	for h in ["Bowler", "O", "R", "W", "Econ"]:
		bowl.add_child(UiTheme.label(h, 17, UiTheme.GOLD))
	for b in card.bowlers:
		bowl.add_child(UiTheme.label(String(b["name"]), 19))
		bowl.add_child(UiTheme.label(Overs.text(b["balls"]), 19, UiTheme.OFF_WHITE, "regular"))
		bowl.add_child(UiTheme.label(str(b["runs"]), 19, UiTheme.OFF_WHITE, "regular"))
		bowl.add_child(UiTheme.label(str(b["wickets"]), 19, UiTheme.OFF_WHITE, "regular"))
		bowl.add_child(UiTheme.label(Overs.rate_text(Overs.economy(b["runs"], b["balls"])), 19, UiTheme.OFF_WHITE, "regular"))
	right.add_child(bowl)
	var fow_parts: Array = []
	for f in card.fall_of_wickets:
		fow_parts.append("%d-%d (%s, %s ov)" % [f["score"], f["wickets"], f["batter"], f["overs"]])
	var fow := UiTheme.label("Fall of wickets: " + (", ".join(fow_parts) if fow_parts.size() > 0 else "none"), 16, UiTheme.SAND, "regular")
	fow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fow.custom_minimum_size = Vector2(360, 0)
	right.add_child(fow)
	var extras := UiTheme.label("Extras: 0 (arcade format has no wides/no-balls)   Boundaries: %d x4, %d x6" % [card.fours, card.sixes], 16, UiTheme.SAND, "regular")
	extras.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extras.custom_minimum_size = Vector2(360, 0)
	right.add_child(extras)
	var map := ShotMap.new()
	map.events = state.events
	map.venue = load("res://data/venues/pindi.tres")
	map.custom_minimum_size = Vector2(260, 150)
	right.add_child(map)
	# Ball-by-ball
	var bb := HFlowContainer.new()
	bb.add_theme_constant_override("h_separation", 4)
	bb.add_theme_constant_override("v_separation", 4)
	bb.custom_minimum_size = Vector2(900, 0)
	var i := 0
	for e in state.events:
		if i > 0 and i % 6 == 0:
			var sep := UiTheme.label("|", 20, UiTheme.GOLD)
			bb.add_child(sep)
		bb.add_child(OverChip.make(Scorecard._symbol(e)))
		i += 1
	body.add_child(UiTheme.label("Ball by ball", 17, UiTheme.GOLD))
	body.add_child(bb)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	if final:
		var again := UiTheme.button("Play again", 28, 260)
		again.pressed.connect(func(): play_again.emit())
		row.add_child(again)
		var menu := UiTheme.button("Menu", 24, 200)
		menu.pressed.connect(func(): to_menu.emit())
		row.add_child(menu)
		again.call_deferred("grab_focus")
	else:
		var close := UiTheme.button("Close", 24, 220)
		close.pressed.connect(func(): closed.emit())
		row.add_child(close)
		close.call_deferred("grab_focus")


static func _result_title(card: Scorecard) -> String:
	match card.result:
		"won": return "YOU WON!"
		"lost": return "SO CLOSE"
		"tied": return "MATCH TIED"
	return "INNINGS OVER"

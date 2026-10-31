extends TestCase


func test_event_mapping() -> void:
	var o := BallOutcome.new()
	o.kind = BallOutcome.FOUR
	eq(Commentary.event_for(o), "four")
	o.kind = BallOutcome.SIX
	eq(Commentary.event_for(o), "six")


func test_short_calls_only() -> void:
	var c := Commentary.new(1)
	eq(c.pick("six", {"runs": 6}, 0)["text"], "Six!")
	eq(c.pick("four", {"runs": 4}, 1)["text"], "Four!")
	eq(c.pick("runs", {"runs": 1}, 2)["text"], "One run")
	eq(c.pick("runs", {"runs": 2}, 3)["text"], "Two runs")
	eq(c.pick("runs", {"runs": 3}, 4)["text"], "Three runs")
	eq(c.pick("dot", {"runs": 0}, 5)["text"], "Dot ball")
	eq(c.pick("bowled", {}, 6)["text"], "Bowled! Out!")
	eq(c.pick("caught", {}, 7)["text"], "Caught out!")
	eq(c.pick("fifty", {}, 8)["text"], "Fifty!")
	eq(c.pick("hundred", {}, 9)["text"], "Hundred!")
	check(c.pick("first_ball", {}, 10).is_empty(), "no chatter before the ball")
	check(c.pick("last_ball", {"needed": 4}, 11).is_empty(), "no chatter on the last ball")
	for l in Commentary.LINES:
		check(String(l[3]).split(" ").size() <= 4, "short call: " + String(l[3]))


func test_edge_runs_are_called_as_runs() -> void:
	var o := BallOutcome.new()
	o.kind = BallOutcome.RUNS
	o.runs = 1
	o.timing = ContactResult.EDGE
	eq(Commentary.event_for(o), "runs")


func test_conditions() -> void:
	check(Commentary.condition_ok("runs>=2", {"runs": 3}), ">=")
	check(not Commentary.condition_ok("runs>=2", {"runs": 1}), ">= false")
	check(Commentary.condition_ok("timing=perfect", {"timing": "perfect"}), "=")
	check(not Commentary.condition_ok("needed==4", {}), "missing key is ineligible")


func test_voice_script_covers_lines() -> void:
	var f := FileAccess.open("res://VOICE_SCRIPT.csv", FileAccess.READ)
	check(f != null, "VOICE_SCRIPT.csv exists")
	if f == null:
		return
	var text := f.get_as_text()
	for l in Commentary.LINES:
		check(text.contains(String(l[0])), "voice script lists %s" % l[0])


func test_every_line_has_a_voice_clip() -> void:
	for l in Commentary.LINES:
		var path := "res://assets/audio/vo_%s.wav" % l[0]
		check(ResourceLoader.exists(path), "clip exists: " + path)
		check(l.size() == 4, "one (English) text per line: " + String(l[0]))

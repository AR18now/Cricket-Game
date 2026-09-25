extends TestCase


func test_event_mapping() -> void:
	var o := BallOutcome.new()
	o.kind = BallOutcome.FOUR
	eq(Commentary.event_for(o), "four")
	o.kind = BallOutcome.SIX
	eq(Commentary.event_for(o), "six")


func test_six_line_never_on_four() -> void:
	var c := Commentary.new(1)
	for i in 30:
		var l := c.pick("four", {"runs": 4}, i)
		if not l.is_empty():
			check(String(l["id"]).begins_with("four"), "four event only picks four lines")


func test_last_ball_line_matches_requirement() -> void:
	var c := Commentary.new(2)
	var l := c.pick("last_ball", {"needed": 4}, 0)
	eq(l["id"], "last_ball_4")
	l = c.pick("last_ball", {"needed": 1}, 1)
	eq(l["id"], "last_ball_1")
	c.language = "english"
	l = c.pick("last_ball", {"needed": 6}, 2)
	eq(l["text"], "Six needed off the last ball!")
	l = c.pick("last_ball", {"needed": 3}, 3)
	eq(l["id"], "last_ball_n", "generic line when no exact clip")


func test_conditions() -> void:
	check(Commentary.condition_ok("runs>=2", {"runs": 3}), ">=")
	check(not Commentary.condition_ok("runs>=2", {"runs": 1}), ">= false")
	check(Commentary.condition_ok("timing=perfect", {"timing": "perfect"}), "=")
	check(not Commentary.condition_ok("needed==4", {}), "missing key is ineligible")


func test_no_immediate_repeat() -> void:
	var c := Commentary.new(5)
	var last := ""
	for i in 20:
		var l := c.pick("six", {}, i * 3)
		check(l["id"] != last, "no immediate repeat")
		last = l["id"]


func test_voice_script_covers_lines() -> void:
	var f := FileAccess.open("res://VOICE_SCRIPT.csv", FileAccess.READ)
	check(f != null, "VOICE_SCRIPT.csv exists")
	if f == null:
		return
	var text := f.get_as_text()
	for l in Commentary.LINES:
		check(text.contains(String(l[0])), "voice script lists %s" % l[0])

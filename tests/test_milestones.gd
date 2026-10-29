extends TestCase
## 50s and 100s: detected exactly once, on the ball that passes them.


func test_milestone_crossing() -> void:
	eq(MatchController.milestone_crossed(48, 52), 50, "48 -> 52 passes fifty")
	eq(MatchController.milestone_crossed(44, 50), 50, "exactly fifty counts")
	eq(MatchController.milestone_crossed(50, 54), 0, "already past fifty")
	eq(MatchController.milestone_crossed(96, 102), 100, "hundred")
	eq(MatchController.milestone_crossed(147, 153), 150, "one-fifty")
	eq(MatchController.milestone_crossed(30, 36), 0, "nothing below fifty")
	eq(MatchController.milestone_crossed(49, 49), 0, "a dot ball on 49")


func test_milestone_titles_and_lines() -> void:
	eq(MilestoneCelebration.title_for(50), "FIFTY!")
	eq(MilestoneCelebration.title_for(100), "HUNDRED!")
	var c := Commentary.new(3)
	check(String(c.pick("fifty", {}, 0)["id"]).begins_with("fifty"), "fifty has its own commentary")
	check(String(c.pick("hundred", {}, 1)["id"]).begins_with("hundred"), "hundred has its own commentary")

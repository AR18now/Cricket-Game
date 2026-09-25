class_name Overs
extends RefCounted
## Cricket over notation helpers. 11 legal balls = "1.5"; one more = "2.0" (never "1.6").


static func text(legal_balls: int) -> String:
	return "%d.%d" % [legal_balls / 6, legal_balls % 6]


## Economy from legal balls (not decimal overs). Returns -1 when no balls bowled.
static func economy(runs: int, legal_balls: int) -> float:
	if legal_balls <= 0:
		return -1.0
	return float(runs) * 6.0 / float(legal_balls)


static func strike_rate(runs: int, balls: int) -> float:
	if balls <= 0:
		return -1.0
	return float(runs) * 100.0 / float(balls)


## Runs per over required from the balls that actually remain. -1 when not applicable.
static func required_rate(runs_needed: int, balls_left: int) -> float:
	if balls_left <= 0 or runs_needed <= 0:
		return -1.0
	return float(runs_needed) * 6.0 / float(balls_left)


static func rate_text(v: float) -> String:
	return "-" if v < 0.0 else "%.2f" % v

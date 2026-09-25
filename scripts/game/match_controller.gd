class_name MatchController
extends Node
## Explicit per-delivery state machine:
##   READY -> RUNUP -> FLIGHT -> (SHOT) -> OUTCOME -> READY ... -> OVER
## The ball outcome is resolved once (at the swing, or when the batting window closes)
## and recorded exactly once when it settles on screen. Pausing freezes the sim clock.

signal phase_changed(phase: int)
signal delivery_started(info: Dictionary)
signal swing_feedback(result: String)
signal timing_revealed(contact: ContactResult)
signal ball_settled(outcome: BallOutcome, card: Scorecard)
signal match_over(state: MatchState)
signal tutorial_step(level: int, success: bool)
signal commentary_line(line: Dictionary)

enum Phase { IDLE, READY, RUNUP, FLIGHT, OUTCOME, OVER, REPLAY }

const READY_PAUSE := 0.9
const OUTCOME_HOLD := 1.5
const OUTCOME_HOLD_BIG := 2.2

var world: WorldView
var tuning: GameTuning
var venue: VenueConfig
var bowlers: Dictionary = {}
var rules: MatchRules
var state: MatchState
var phase := Phase.IDLE
var clock := SimClock.new()
var gate := SwingGate.new()
var delivery: Delivery
var profile: BowlerProfile
var resolver: BallResolver
var fielders: Array = []
var delivery_id := 0
var stance := ContactResult.Stance.AUTO
var tutorial_level := -1
var tutorial_attempts := 0
var fielding_names := ["Imran", "Kashif", "Rizwan", "Tariq", "Nadeem", "Sohail", "Asif", "Waqar"]
var keeper_name := "Usman"
var commentary := Commentary.new(11)
var paused := false
var auto_continue := true
var _fired := {}
var _outcome_at := 0.0
var _recorded := false
var _revealed := false
var _last_usec := 0
var replay_t := 0.0
var _replay_end := 0.0
var replays_shown := 0


func setup(w: WorldView, t: GameTuning, v: VenueConfig) -> void:
	world = w
	tuning = t
	venue = v
	for id in ["ayaan_coach", "daniyal", "hamza", "saad"]:
		bowlers[id] = load("res://data/bowlers/%s.tres" % id)


func bowler_name(id: String) -> String:
	var b: BowlerProfile = bowlers.get(id)
	return b.display_name if b else id


func start_match(r: MatchRules, seed_value: int, tutorial: bool = false) -> void:
	rules = r
	state = MatchState.new(r, seed_value)
	for id in bowlers.keys():
		state.bowler_names[id] = bowlers[id].display_name
	state.card = Scorecard.build(r, [], state.bowler_names)
	commentary = Commentary.new(seed_value)
	commentary.language = String(_setting("language", "roman_urdu"))
	tutorial_level = 0 if tutorial else -1
	tutorial_attempts = 0
	world.two_batters = r.two_batters
	paused = false
	_next_delivery()


func _setting(key: String, def):
	var save := get_node_or_null("/root/Save")
	if save == null:
		return def
	return save.data["settings"].get(key, def)


func _next_delivery() -> void:
	if state.is_complete():
		_set_phase(Phase.OVER)
		match_over.emit(state)
		return
	delivery_id = state.next_ball_index() + (1000 * tutorial_attempts if tutorial_level >= 0 else 0)
	var seed_value := DetRng.derive(state.seed, delivery_id)
	if tutorial_level >= 0:
		profile = bowlers["ayaan_coach"]
		delivery = DeliveryGenerator.tutorial(tutorial_level, seed_value, tuning)
	else:
		profile = bowlers[state.current_bowler_id()]
		delivery = DeliveryGenerator.generate(profile, seed_value, tuning, state.difficulty())
	var names := [profile.display_name, keeper_name]
	names.append_array(fielding_names)
	fielders = FielderSpec.from_layout(venue.field_layout, names, tuning)
	if world.specs.size() != fielders.size():
		world.setup_fielders(fielders)
	else:
		world.specs = fielders
	var card := state.card
	var st_name: String = card.batters[card.striker]["name"]
	var ns_name := ""
	if card.non_striker >= 0:
		ns_name = card.batters[card.non_striker]["name"]
	world.begin_delivery(delivery, profile, "%s %d*" % [st_name, card.batters[card.striker]["runs"]],
		"%s %d*" % [ns_name, card.batters[card.non_striker]["runs"]] if ns_name != "" else "")
	resolver = null
	_recorded = false
	_revealed = false
	_fired.clear()
	var ready_t := -profile.run_up_time - READY_PAUSE
	clock.reset(ready_t, Time.get_ticks_usec())
	gate.arm(ContactResolver.window_open_time(delivery, tuning), ContactResolver.window_close_time(delivery, tuning))
	world.render(ready_t)
	_set_phase(Phase.READY)
	var info := {"bowler": profile, "delivery": delivery, "ball": state.next_ball_index(), "tutorial": tutorial_level}
	delivery_started.emit(info)
	# Situation commentary (eligibility is checked against the real requirement).
	if tutorial_level == 0 and tutorial_attempts == 0:
		_say("first_ball", {})
	elif rules.target > 0 and card.balls_left == 1:
		_say("last_ball", {"needed": card.runs_needed})


func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func window_scale() -> float:
	if tutorial_level >= 0:
		return tuning.tutorial_window_scale
	return rules.window_scale


## Called for every swing input (tap, click, key). `usec` is the event arrival time.
func swing_input(usec: int) -> String:
	if paused:
		return "paused"
	if phase == Phase.REPLAY:
		_end_replay()
		return "replay_end"
	if phase == Phase.OUTCOME and _recorded and clock.time - _outcome_at > 0.35:
		skip_outcome()
		return "skip"
	if phase != Phase.RUNUP and phase != Phase.FLIGHT and phase != Phase.READY:
		return "closed"
	var t := clock.time_of_input(usec, Engine.time_scale)
	var res := gate.try_swing(t)
	if res == "accepted":
		resolver = BallResolver.resolve(delivery, t, stance, fielders, venue, tuning, window_scale())
		world.set_resolved(resolver, t)
		_play("swing", "Impacts", -6.0)
	swing_feedback.emit(res)
	return res


## Instant replay: re-renders the recorded timeline at half speed. It never re-simulates,
## never records events and never grants rewards; it returns to the same OUTCOME phase.
func start_replay() -> void:
	if phase != Phase.OUTCOME or not _recorded or resolver == null:
		return
	var key_t := resolver.contact.t_contact if resolver.contact.is_contact() else delivery.stumps_time()
	replay_t = maxf(-0.5, key_t - 1.1)
	_replay_end = resolver.outcome.t_settle
	replays_shown += 1
	world.ball.clear_trail()
	_set_phase(Phase.REPLAY)


func _end_replay() -> void:
	_outcome_at = clock.time
	world.render(clock.time)
	_set_phase(Phase.OUTCOME)


func skip_outcome() -> void:
	if phase == Phase.OUTCOME and _recorded:
		_advance_after_outcome()


func set_paused(p: bool) -> void:
	paused = p
	clock.set_paused(p, Time.get_ticks_usec())


func _process(delta: float) -> void:
	if phase == Phase.IDLE or phase == Phase.OVER or paused:
		return
	if phase == Phase.REPLAY:
		replay_t += delta * 0.5
		world.render(replay_t)
		world.update_camera(delta)
		if replay_t >= _replay_end:
			_end_replay()
		return
	var prev := clock.time
	clock.advance(delta, Time.get_ticks_usec())
	var t := clock.time
	if phase == Phase.READY and t >= -profile.run_up_time:
		_set_phase(Phase.RUNUP)
	if phase == Phase.RUNUP and t >= 0.0:
		_set_phase(Phase.FLIGHT)
	# Batting window closed without a swing: resolve as "no shot".
	if resolver == null and t > gate.close_time:
		gate.disarm()
		resolver = BallResolver.resolve(delivery, -1.0, stance, fielders, venue, tuning, window_scale())
		world.set_resolved(resolver, -1.0)
	world.render(t)
	world.update_camera(delta)
	_audio_events(prev, t)
	if resolver != null and not _revealed:
		var reveal_t := resolver.contact.t_contact if resolver.contact.is_contact() else delivery.stumps_time()
		if t >= reveal_t:
			_revealed = true
			timing_revealed.emit(resolver.contact)
	if resolver != null and not _recorded and t >= resolver.outcome.t_settle:
		_settle()
	if phase == Phase.OUTCOME and _recorded and auto_continue:
		var hold := OUTCOME_HOLD_BIG if (resolver.outcome.is_boundary() or resolver.outcome.wicket) else OUTCOME_HOLD
		if t - _outcome_at >= hold:
			_advance_after_outcome()


func _settle() -> void:
	_recorded = true
	_outcome_at = clock.time
	var o := resolver.outcome
	if tutorial_level >= 0:
		var ok := resolver.contact.is_contact()
		tutorial_step.emit(tutorial_level, ok)
	else:
		state.record(delivery_id, o, profile.id)
	world.umpire_signal = "six" if o.kind == BallOutcome.SIX else ("four" if o.kind == BallOutcome.FOUR else ("out" if o.wicket else ""))
	_set_phase(Phase.OUTCOME)
	ball_settled.emit(o, state.card)
	var ev := Commentary.event_for(o)
	var ctx := {"runs": o.runs, "timing": o.timing, "needed": state.card.runs_needed, "balls_left": state.card.balls_left}
	if state.card.complete and tutorial_level < 0:
		if state.card.result in ["won", "lost", "tied"]:
			ev = state.card.result
	_say(ev, ctx)


func _advance_after_outcome() -> void:
	if tutorial_level >= 0:
		if resolver.contact.is_contact() or tutorial_attempts >= 2:
			tutorial_level += 1
			tutorial_attempts = 0
		else:
			tutorial_attempts += 1
		if tutorial_level >= DeliveryGenerator.TUTORIAL_SPEEDS.size():
			tutorial_level = -1
			_set_phase(Phase.OVER)
			match_over.emit(state)
			return
	_next_delivery()


func _say(event: String, ctx: Dictionary) -> void:
	var line := commentary.pick(event, ctx, state.events.size())
	if not line.is_empty():
		commentary_line.emit(line)


func _crossed(prev: float, t: float, at: float) -> bool:
	return prev < at and t >= at


func _once(key: String) -> bool:
	if _fired.has(key):
		return false
	_fired[key] = true
	return true


func _play(key: String, bus: String, db: float = 0.0) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play(key, bus, db)


func _audio_events(prev: float, t: float) -> void:
	# Run-up footsteps.
	if phase == Phase.RUNUP and t < -0.3:
		var step := 0.32
		if int(floor(prev / step)) != int(floor(t / step)):
			_play("step", "Impacts", -12.0)
	if _crossed(prev, t, delivery.t_bounce) and _once("pitch"):
		_play("bounce", "Impacts", -4.0)
	if resolver == null:
		return
	var c := resolver.contact
	var o := resolver.outcome
	if c.is_contact():
		if _crossed(prev, t, c.t_contact) and _once("bat"):
			if c.category == ContactResult.EDGE:
				_play("bat_edge", "Impacts", -2.0)
			else:
				_play("bat_hit", "Impacts", 0.0 if c.category == ContactResult.PERFECT else -3.0)
			if resolver.shot.max_height > 8.0:
				_play("anticipation", "Crowd", -6.0)
		var s := resolver.shot
		var ts_prev := prev - c.t_contact
		var ts := t - c.t_contact
		if s.first_bounce_t < INF and _crossed(ts_prev, ts, s.first_bounce_t) and (not s.is_boundary() or s.first_bounce_t < s.boundary_t) and _once("land"):
			_play("bounce", "Impacts", -6.0)
		if s.is_boundary() and _crossed(ts_prev, ts, s.boundary_t) and _once("rope"):
			_play("cheer_big" if o.kind == BallOutcome.SIX else "cheer_small", "Crowd", 0.0)
			_play("sting_boundary", "Music", -4.0)
		if s.t_collect < INF and _crossed(ts_prev, ts, s.t_collect) and _once("collect"):
			if o.kind == BallOutcome.CAUGHT:
				_play("catch", "Impacts", 0.0)
				_play("groan", "Crowd", -2.0)
				_play("sting_wicket", "Music", -4.0)
			else:
				_play("catch", "Impacts", -10.0)
	else:
		var ts2 := delivery.stumps_time()
		if _crossed(prev, t, ts2) and _once("stumps"):
			if o.kind == BallOutcome.BOWLED:
				_play("stumps", "Impacts", 0.0)
				_play("groan", "Crowd", -2.0)
				_play("sting_wicket", "Music", -4.0)
		var tk := delivery.time_at_x(2.7)
		if o.kind != BallOutcome.BOWLED and _crossed(prev, t, tk) and _once("keeper"):
			_play("catch", "Impacts", -8.0)


## Debug/test introspection.
func debug_info() -> Dictionary:
	return {
		"phase": Phase.keys()[phase], "clock": clock.time, "seed": delivery.seed if delivery else 0,
		"delivery": delivery.to_dict() if delivery else {}, "window": [gate.open_time, gate.close_time],
		"swing": gate.swing_time, "timing": resolver.contact.category if resolver else "",
		"dt_ms": resolver.contact.dt_ms if resolver else 0.0, "outcome": resolver.outcome.kind if resolver else "",
		"ideal_swing": delivery.time_at_x(tuning.contact_x_ideal) - tuning.swing_to_contact if delivery else 0.0,
	}

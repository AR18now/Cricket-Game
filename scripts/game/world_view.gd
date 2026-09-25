class_name WorldView
extends Node2D
## Presentation of the living ground. `render(t)` draws the complete scene for a clock
## value using only resolved simulation data, so the picture can never disagree with the
## recorded outcome, and replays are just render() with an older clock.

const STRIKER_BASE := Vector2(-1.05, -0.42)
const NON_STRIKER_BASE := Vector2(-19.9, -1.1)
const UMPIRE_POS := Vector2(-21.8, -1.4)
const RUN_SPEED := 6.4
const SWING_DUR := 0.34
const DELIVERY_CAM := Vector2(-9.5, 0.0)

var venue: VenueConfig
var tuning: GameTuning
var sky_layer: CanvasLayer
var sky: SkyView
var ground: GroundView
var actors: Node2D
var effects: WorldEffects
var ball: BallView
var ball_shadow: BallShadow
var cam: Camera2D
var near_wall: NearWall
var stumps_bat: StumpsView
var stumps_bowl: StumpsView
var bowler: CricketerRig
var striker: CricketerRig
var non_striker: CricketerRig
var keeper: CricketerRig
var umpire: CricketerRig
var fielder_rigs: Array = []   # aligned with specs (0 = bowler, 1 = keeper)

var delivery: Delivery
var profile: BowlerProfile
var specs: Array = []
var swing_time := -1.0
var resolved: BallResolver
var clock := -3.0
var reduced_motion := false
var menu_mode := true
var idle_t := 0.0
var release_root := Vector2(-19.1, 0.4)
var bowler_hand := Vector2(0.4, 2.0)
var cam_center := Vector2.ZERO
var cam_zoom := 0.9
var show_tags := true
var striker_label := ""
var non_striker_label := ""
var batting_kit := Color(0.05, 0.42, 0.32)
var fielding_kit := Color(0.2, 0.42, 0.75)
var two_batters := true
var umpire_signal := ""
var atm: Atmosphere = Atmosphere.make("evening")
var canvas_mod: CanvasModulate
var floodlights: Floodlights
var weather_layer: CanvasLayer
var weather: WeatherOverlay
var view_mode := "batter"
var batter_layer: CanvasLayer
var batter_view: BatterView
var signal_t := 0.0


func build(v: VenueConfig, t: GameTuning) -> void:
	venue = v
	tuning = t
	sky_layer = CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	sky = SkyView.new()
	sky_layer.add_child(sky)
	sky.setup(v)
	ground = GroundView.new()
	ground.z_index = -20
	add_child(ground)
	ground.setup(v)
	ball_shadow = BallShadow.new()
	ball_shadow.z_index = -5
	add_child(ball_shadow)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	stumps_bat = StumpsView.new()
	stumps_bat.position = Proj.ground(0.0, 0.0)
	actors.add_child(stumps_bat)
	stumps_bowl = StumpsView.new()
	stumps_bowl.position = Proj.ground(Delivery.BOWLING_STUMPS_X, 0.0)
	stumps_bowl.facing = -1.0
	actors.add_child(stumps_bowl)
	striker = _rig(batting_kit, "helmet", true)
	striker.has_pads = true
	striker.gloves = true
	non_striker = _rig(batting_kit, "helmet", true)
	non_striker.has_pads = true
	non_striker.gloves = true
	non_striker.facing = 1.0
	bowler = _rig(fielding_kit, "hair", false)
	bowler.facing = 1.0
	keeper = _rig(fielding_kit, "cap", false)
	keeper.keeper_gloves = true
	keeper.has_pads = true
	umpire = _rig(Color(0.95, 0.93, 0.88), "hat", false)
	umpire.trousers = Color(0.2, 0.2, 0.25)
	umpire.facing = 1.0
	near_wall = NearWall.new()
	near_wall.position = Proj.ground(0.0, GroundView.NEAR_WALL_Y)
	actors.add_child(near_wall)
	ball = BallView.new()
	ball.z_index = 10
	ball.shadow_node = ball_shadow
	add_child(ball)
	effects = WorldEffects.new()
	effects.z_index = 12
	add_child(effects)
	floodlights = Floodlights.new()
	floodlights.z_index = -15
	add_child(floodlights)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	weather_layer = CanvasLayer.new()
	weather_layer.layer = 4
	add_child(weather_layer)
	weather = WeatherOverlay.new()
	weather_layer.add_child(weather)
	batter_layer = CanvasLayer.new()
	batter_layer.layer = 2
	add_child(batter_layer)
	batter_view = BatterView.new()
	batter_layer.add_child(batter_view)
	batter_view.setup(self)
	batter_view.visible = false
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	set_atmosphere(atm)
	_compute_release_root()


func set_view_mode(m: String) -> void:
	view_mode = m if m in ["batter", "side"] else "batter"


## Batter's-eye view covers the delivery; the side camera takes the ball into the field.
func batter_view_active(t: float) -> bool:
	if view_mode != "batter" or menu_mode or delivery == null:
		return false
	if resolved == null:
		return true
	if resolved.contact.is_contact():
		return t < resolved.contact.t_contact + 0.12
	return t < delivery.stumps_time() + 0.8


func set_atmosphere(a: Atmosphere) -> void:
	atm = a
	sky.atm = a
	canvas_mod.color = a.ambient
	floodlights.set_on(a.floodlights)
	weather.atm = a
	# Keep the ball vivid regardless of ambient light.
	ball.modulate = Color(minf(1.0 / a.ambient.r, 1.8), minf(1.0 / a.ambient.g, 1.8), minf(1.0 / a.ambient.b, 1.8))


func _rig(kit: Color, headgear: String, bat: bool) -> CricketerRig:
	var r := CricketerRig.new()
	r.shirt = kit
	r.cap_color = kit.darkened(0.15)
	r.headgear = headgear
	r.has_bat = bat
	actors.add_child(r)
	return r


func _compute_release_root() -> void:
	var probe := CricketerRig.new()
	probe.facing = 1.0
	var j := probe.joints(Poses.bowl_stride(1.0))
	bowler_hand = j["hand_b"]
	probe.free()


## Apply a squad's look to the fielding side for this match.
func set_fielding_side(names: Array, kit: Color) -> void:
	fielding_kit = kit
	for r in [bowler, keeper]:
		r.shirt = kit
		r.cap_color = kit.darkened(0.15)


func set_batting_kit(kit: Color) -> void:
	batting_kit = kit
	for r in [striker, non_striker]:
		r.shirt = kit
		r.cap_color = kit.darkened(0.25)


func setup_fielders(fielder_specs: Array) -> void:
	specs = fielder_specs
	for i in range(2, fielder_rigs.size()):
		if fielder_rigs[i] is CricketerRig and not (fielder_rigs[i] in [bowler, keeper]):
			fielder_rigs[i].queue_free()
	fielder_rigs = [bowler, keeper]
	var skins := [Color(0.72, 0.5, 0.36), Color(0.6, 0.42, 0.3), Color(0.8, 0.6, 0.45), Color(0.66, 0.46, 0.33)]
	for i in range(2, specs.size()):
		var r := _rig(fielding_kit, ["cap", "hair", "cap", "hair"][i % 4], false)
		r.skin = skins[i % skins.size()]
		fielder_rigs.append(r)


## Starts presenting a new delivery (resolved stays null until the swing/deadline).
func begin_delivery(d: Delivery, p: BowlerProfile, striker_name: String, non_striker_name: String) -> void:
	delivery = d
	profile = p
	swing_time = -1.0
	resolved = null
	menu_mode = false
	umpire_signal = ""
	striker_label = striker_name
	non_striker_label = non_striker_name
	stumps_bat.broken_t = -1.0
	stumps_bat.queue_redraw()
	bowler.skin = p.skin_tone
	bowler.hair = p.hair_color
	ball.clear_trail()
	effects.clear()


func set_resolved(r: BallResolver, swing_t: float) -> void:
	resolved = r
	swing_time = swing_t


# ------------------------------------------------------------------ render
func render(t: float) -> void:
	clock = t
	_render_bowler(t)
	_render_batters(t)
	_render_keeper(t)
	_render_fielders(t)
	_render_umpire(t)
	_render_ball(t)
	_render_stumps(t)
	effects.render(self, t)
	var bv := batter_view_active(t)
	if bv and not batter_view.visible:
		snap_camera_to_delivery()
	batter_view.visible = bv
	for r in actors.get_children():
		if r is CricketerRig:
			r.queue_redraw()


func render_menu(delta: float) -> void:
	idle_t += delta
	menu_mode = true
	batter_view.visible = false
	striker.position = Proj.ground_v(STRIKER_BASE)
	striker.facing = -1.0
	striker.set_pose(Poses.bat_stance(idle_t))
	striker.name_tag = ""
	non_striker.position = Proj.ground_v(NON_STRIKER_BASE)
	non_striker.set_pose(Poses.bat_stance(idle_t + 1.0))
	non_striker.name_tag = ""
	non_striker.visible = true
	bowler.position = Proj.ground(-23.0, 0.8)
	bowler.facing = 1.0
	bowler.ball_in_hand = true
	bowler.set_pose(Poses.field_idle(idle_t))
	keeper.position = Proj.ground(3.2, 0.1)
	keeper.facing = -1.0
	keeper.set_pose(Poses.keeper_crouch(idle_t))
	umpire.position = Proj.ground_v(UMPIRE_POS)
	umpire.set_pose(Poses.umpire(idle_t))
	for i in range(2, fielder_rigs.size()):
		var r: CricketerRig = fielder_rigs[i]
		var s: FielderSpec = specs[i]
		r.position = Proj.ground_v(s.pos)
		r.facing = -1.0 if s.pos.x > -8.0 else 1.0
		r.set_pose(Poses.field_idle(idle_t + i))
	ball.visible_ball = false
	ball_shadow.visible = false
	ball.queue_redraw()
	# Slow drifting overview camera.
	var drift := 0.0 if reduced_motion else sin(idle_t * 0.12) * 6.0
	cam_center = Proj.ground(-10.0 + drift, 3.0) + Vector2(0, -160)
	cam_zoom = 0.62
	cam.position = cam_center
	cam.zoom = Vector2(cam_zoom, cam_zoom)
	sky.cam_offset = cam.position


func _run_up_root(t: float) -> Vector2:
	var x_rel := delivery.release.x - bowler_hand.x
	var y := delivery.release.y + 0.15
	var T := profile.run_up_time
	if t >= 0.0:
		var goal: Vector2 = specs[0].pos if specs.size() > 0 else Vector2(-15.0, 2.2)
		var u := Poses.ease_io(t / 0.9)
		return Vector2(x_rel, y).lerp(goal, u)
	if t >= -0.3:
		return Vector2(x_rel - 0.9 * (-t / 0.3), y)
	if t >= -0.55:
		return Vector2(x_rel - 0.9 - 1.5 * ((-t - 0.3) / 0.25), y)
	var run_start := x_rel - 2.4 - RUN_SPEED * (T - 0.55)
	var u2 := clampf((t + T) / (T - 0.55), 0.0, 1.0)
	return Vector2(lerpf(run_start, x_rel - 2.4, u2), y)


func _render_bowler(t: float) -> void:
	var T := profile.run_up_time
	var root := _run_up_root(t)
	var shot := resolved.shot if resolved != null else null
	var t_contact := resolved.contact.t_contact if (resolved != null and resolved.contact.is_contact()) else INF
	bowler.facing = 1.0
	bowler.ball_in_hand = t < 0.0
	bowler.lift = 0.0
	if t < -T - 0.6:
		bowler.set_pose(Poses.field_idle(t))
		root = _run_up_root(-T)
	elif t < -T:
		bowler.set_pose(Poses.field_idle(t))
		root = _run_up_root(-T)
	elif t < -0.55:
		var dist := RUN_SPEED * (t + T)
		bowler.set_pose(Poses.run(dist * 1.35, clampf((t + T) * 2.5, 0.35, 1.0)))
	elif t < -0.3:
		var u := (t + 0.55) / 0.25
		bowler.lift = sin(u * PI) * 0.3
		bowler.set_pose(Poses.bowl_gather(u))
	elif t < 0.0:
		bowler.set_pose(Poses.bowl_stride((t + 0.3) / 0.3))
	elif t < 0.9 or shot == null or t < t_contact:
		bowler.set_pose(Poses.bowl_follow(clampf(t / 0.7, 0.0, 1.0)) if t < 0.7 else Poses.field_ready(t))
	if shot != null and t >= t_contact:
		_render_fielder_in_shot(0, bowler, t - t_contact, shot)
		return
	bowler.position = Proj.ground_v(root)


func _render_batters(t: float) -> void:
	striker.visible = true
	striker.facing = -1.0
	var base := STRIKER_BASE
	var pose := Poses.bat_stance(t)
	var root_shift := 0.0
	striker.name_tag = striker_label if show_tags and t < -profile.run_up_time + 0.8 else ""
	striker.tag_strong = true
	non_striker.visible = two_batters
	non_striker.name_tag = non_striker_label if show_tags and two_batters and t < -profile.run_up_time + 0.8 else ""
	non_striker.tag_strong = false
	if t > -0.5:
		pose = Poses.blend(Poses.bat_stance(t), Poses.bat_backlift(), Poses.ease_io((t + 0.5) / 0.4))
	var contact := resolved.contact if resolved != null else null
	var shot := resolved.shot if resolved != null else null
	var outcome := resolved.outcome if resolved != null else null
	if swing_time >= 0.0 and t >= swing_time:
		var u := (t - swing_time) / SWING_DUR
		var z := 0.4
		var target_x := tuning.contact_x_ideal
		if contact != null and contact.is_contact():
			z = contact.contact_pos.z
			target_x = contact.contact_pos.x
		elif delivery != null:
			z = clampf(delivery.pos_at(swing_time + tuning.swing_to_contact).z, 0.1, 1.2)
		var ba := Poses.bat_angle_for_height(z)
		var rise := Poses.hand_rise_for_height(z)
		pose = Poses.bat_swing(clampf(u, 0.0, 1.0), ba, rise)
		# Step into the shot so the bat's sweet spot meets the ball where contact happened.
		var cp := Poses.bat_contact(ba, rise)
		var j := striker.joints(cp)
		var sweet: Vector2 = j["bat_shoulder"].lerp(j["bat_tip"], 0.55)
		var need := (target_x - base.x - sweet.x) / striker.facing
		root_shift = clampf(need, -0.3, 1.5) * Poses.ease_io(clampf(u / Poses.CONTACT_U, 0.0, 1.0))
		pose["root_x"] = root_shift
	var ns_pos := NON_STRIKER_BASE
	var ns_pose := Poses.bat_stance(t + 1.3)
	non_striker.facing = 1.0
	if t > -0.6 and t < 0.6:
		# Backing up as the ball is delivered.
		var bu := Poses.ease_io((t + 0.6) / 1.0)
		ns_pos.x += bu * 1.2
		ns_pose = Poses.walk(bu * 5.0, true)
	elif t >= 0.6:
		ns_pos.x += 1.2
		ns_pose = Poses.bat_stance(t)
	var t_contact := contact.t_contact if (contact != null and contact.is_contact()) else INF
	var st_pos := base
	if shot != null and t >= t_contact:
		var ts := t - t_contact
		var runs := shot.run_times.size()
		if outcome.kind == BallOutcome.RUNS or outcome.kind == BallOutcome.DOT:
			if runs > 0 and ts > 0.25:
				var a_end := base.x - 0.3
				var b_end := NON_STRIKER_BASE.x + 1.2
				var sp := _run_position(ts, shot.run_times, a_end, b_end)
				var np := _run_position(ts, shot.run_times, b_end, a_end)
				st_pos = Vector2(sp.x, base.y - 0.6)
				ns_pos = Vector2(np.x, NON_STRIKER_BASE.y + 0.4)
				striker.facing = sp.y
				non_striker.facing = np.y
				pose = Poses.run(absf(sp.x) * 1.35, 1.0 if sp.z > 0.5 else 0.2, true)
				ns_pose = Poses.run(absf(np.x) * 1.35, 1.0 if np.z > 0.5 else 0.2, true)
				if sp.z < 0.5:
					pose = Poses.bat_stance(t)
					ns_pose = Poses.bat_stance(t)
				pose.erase("root_x")
			elif ts > SWING_DUR:
				pose = Poses.blend(Poses.bat_follow(), Poses.bat_stance(t), Poses.ease_io((ts - SWING_DUR) / 0.6))
				pose["root_x"] = root_shift * clampf(1.0 - (ts - SWING_DUR) / 0.6, 0.0, 1.0)
		elif outcome.is_boundary():
			var tb := shot.boundary_t
			if ts > tb:
				pose = Poses.celebrate(ts - tb, true)
				ns_pose = Poses.celebrate(ts - tb + 0.3, true)
		elif outcome.kind == BallOutcome.CAUGHT and ts > shot.t_collect + 0.2:
			var wt := ts - shot.t_collect - 0.2
			pose = Poses.dejected(wt * 5.0)
			striker.facing = 1.0
			st_pos = base + Vector2(wt * 1.1, wt * 0.9)
	elif outcome != null and outcome.kind == BallOutcome.BOWLED and t > delivery.stumps_time() + 0.35:
		var wt2 := t - delivery.stumps_time() - 0.35
		pose = Poses.dejected(wt2 * 5.0)
		striker.facing = 1.0
		st_pos = base + Vector2(wt2 * 1.1, wt2 * 0.9)
	elif swing_time < 0.0 and delivery != null and t > delivery.stumps_time() + 0.1:
		pose = Poses.blend(Poses.bat_backlift(), Poses.bat_stance(t), Poses.ease_io((t - delivery.stumps_time()) / 0.6))
	striker.position = Proj.ground_v(st_pos)
	striker.set_pose(pose)
	non_striker.position = Proj.ground_v(ns_pos)
	non_striker.set_pose(ns_pose)


## Runner position for automatic running: returns (x, facing, moving 0/1).
func _run_position(ts: float, run_times: Array, from_x: float, to_x: float) -> Vector3:
	var start := 0.25
	var a := from_x
	var b := to_x
	for k in run_times.size():
		var end: float = run_times[k]
		if ts <= end:
			var u := clampf((ts - start) / (end - start), 0.0, 1.0)
			var x := lerpf(a, b, Poses.ease_io(u))
			return Vector3(x, signf(b - a), 1.0)
		start = end
		var tmp := a
		a = b
		b = tmp
	return Vector3(a, signf(b - a), 0.0)


func _render_keeper(t: float) -> void:
	keeper.facing = -1.0
	var shot := resolved.shot if resolved != null else null
	var contact := resolved.contact if resolved != null else null
	if shot != null and contact.is_contact() and t >= contact.t_contact:
		_render_fielder_in_shot(1, keeper, t - contact.t_contact, shot)
		return
	keeper.position = Proj.ground(3.2, 0.1)
	var pose := Poses.keeper_crouch(t)
	if delivery != null and t > 0.0:
		var ts := delivery.stumps_time()
		pose = Poses.keeper_rise(clampf((t - (ts - 0.35)) / 0.35, 0.0, 1.0))
	keeper.set_pose(pose)


func _render_umpire(t: float) -> void:
	umpire.position = Proj.ground_v(UMPIRE_POS)
	umpire.facing = 1.0
	if umpire_signal != "":
		umpire.set_pose(Poses.umpire_signal(umpire_signal, t))
	else:
		umpire.set_pose(Poses.umpire(t))


func _render_fielders(t: float) -> void:
	var shot := resolved.shot if resolved != null else null
	var contact := resolved.contact if resolved != null else null
	for i in range(2, fielder_rigs.size()):
		var r: CricketerRig = fielder_rigs[i]
		var s: FielderSpec = specs[i]
		if shot != null and contact.is_contact() and t >= contact.t_contact:
			_render_fielder_in_shot(i, r, t - contact.t_contact, shot)
			continue
		r.position = Proj.ground_v(s.pos)
		r.facing = -1.0 if s.pos.x > -3.0 else 1.0
		r.set_pose(Poses.field_ready(t + i) if t > -0.8 else Poses.field_idle(t + i))


func _fielder_pos(i: int, ts: float, shot: ShotResult) -> Vector2:
	var s: FielderSpec = specs[i]
	if i >= shot.fielder_targets.size():
		return s.pos
	var plan: Dictionary = shot.fielder_targets[i]
	var target: Vector2 = plan["target"]
	var t0: float = plan["t_start"]
	if ts <= t0:
		return s.pos
	var dist := s.pos.distance_to(target)
	var moved := minf(dist, s.speed * (ts - t0))
	return s.pos.move_toward(target, moved)


func _render_fielder_in_shot(i: int, r: CricketerRig, ts: float, shot: ShotResult) -> void:
	var s: FielderSpec = specs[i]
	var p := _fielder_pos(i, ts, shot)
	var plan: Dictionary = shot.fielder_targets[i] if i < shot.fielder_targets.size() else {}
	var moving := false
	if not plan.is_empty():
		var target: Vector2 = plan["target"]
		moving = ts > float(plan["t_start"]) and p.distance_to(target) > 0.05
		if moving:
			r.facing = 1.0 if target.x > s.pos.x else -1.0
	r.position = Proj.ground_v(p)
	if i == shot.collector and ts >= shot.t_collect:
		var tc := ts - shot.t_collect
		if shot.outcome == ShotResult.CAUGHT:
			r.set_pose(Poses.catch_high(clampf(tc / 0.2, 0.0, 1.0)) if tc < 0.8 else Poses.celebrate(tc, false))
		elif tc < tuning.pickup_time:
			r.set_pose(Poses.pick_up(clampf(tc / 0.2, 0.0, 1.0)))
		else:
			r.facing = 1.0 if shot.throw_to.x > p.x else -1.0
			r.set_pose(Poses.throw_arm(clampf((tc - tuning.pickup_time + 0.15) / 0.4, 0.0, 1.0)))
	elif moving:
		r.set_pose(Poses.run(p.distance_to(s.pos) * 1.35, 1.0))
	else:
		r.set_pose(Poses.field_ready(ts + i))


func _render_stumps(t: float) -> void:
	if resolved != null and resolved.outcome.kind == BallOutcome.BOWLED:
		var ts := delivery.stumps_time()
		stumps_bat.broken_t = t - ts if t >= ts else -1.0
	else:
		stumps_bat.broken_t = -1.0
	stumps_bat.queue_redraw()


func ball_world(t: float) -> Vector3:
	if delivery == null or t < 0.0:
		return Vector3.INF
	var contact := resolved.contact if resolved != null else null
	var shot := resolved.shot if resolved != null else null
	if contact != null and contact.is_contact() and t >= contact.t_contact:
		return _shot_ball(t - contact.t_contact, shot)
	var ts := delivery.stumps_time()
	if resolved != null and resolved.outcome.kind == BallOutcome.BOWLED and t >= ts:
		var p := delivery.pos_at(ts)
		var k := minf(t - ts, 0.6)
		return Vector3(p.x + k * 1.2, p.y + k * 0.8, maxf(0.0, p.z + k * 1.5 - 5.0 * k * k))
	var t_keep := delivery.time_at_x(2.7)
	if t >= t_keep:
		var j := keeper.joints()
		var hp: Vector2 = j["hand_f"]
		return Vector3(3.2 + hp.x, 0.1, maxf(0.1, hp.y))
	return delivery.pos_at(t)


func _shot_ball(ts: float, shot: ShotResult) -> Vector3:
	if shot.is_boundary():
		if ts <= shot.boundary_t:
			return shot.ball_pos_at(ts)
		# Continue past the rope for presentation only (outcome already settled).
		var n := shot.samples.size()
		var p1: Vector3 = shot.samples[n - 1]
		var p0: Vector3 = shot.samples[maxi(0, n - 2)]
		var v := (p1 - p0) / shot.dt
		var e := minf(ts - shot.boundary_t, 1.2)
		if shot.outcome == ShotResult.SIX:
			var z := p1.z + v.z * e - 0.5 * tuning.gravity * e * e
			if z <= 0.0:
				var tl := (v.z + sqrt(maxf(0.0, v.z * v.z + 2.0 * tuning.gravity * p1.z))) / tuning.gravity
				var land := p1 + Vector3(v.x, v.y, 0) * tl
				return Vector3(land.x, land.y, 0.0)
			return Vector3(p1.x + v.x * e, p1.y + v.y * e, z)
		var hv := Vector2(v.x, v.y)
		var sp := maxf(0.0, hv.length() - venue.roll_decel * e * 3.0)
		var d := (hv.length() + sp) * 0.5 * e
		var dir := hv.normalized()
		return Vector3(p1.x + dir.x * d, p1.y + dir.y * d, 0.0)
	if ts <= shot.t_collect:
		return shot.ball_pos_at(ts)
	var c := shot.collector
	var fp := _fielder_pos(c, ts, shot)
	if shot.outcome == ShotResult.CAUGHT:
		return Vector3(fp.x, fp.y, 2.0)
	var tp := ts - shot.t_collect
	if tp < tuning.pickup_time:
		return Vector3(fp.x, fp.y, lerpf(0.1, 1.6, tp / tuning.pickup_time))
	var from := Vector3(fp.x, fp.y, 1.8)
	var to := Vector3(shot.throw_to.x, shot.throw_to.y, 0.9)
	var dur := maxf(0.05, shot.t_back - shot.t_collect - tuning.pickup_time)
	var u := clampf((tp - tuning.pickup_time) / dur, 0.0, 1.0)
	var p := from.lerp(to, u)
	p.z += sin(u * PI) * from.distance_to(to) * 0.12
	return p


func _render_ball(t: float) -> void:
	var p := ball_world(t)
	if p == Vector3.INF:
		ball.visible_ball = false
		ball_shadow.visible = false
		ball.queue_redraw()
		return
	ball.visible_ball = true
	ball.trail_enabled = not reduced_motion
	ball.set_ball(p, cam.zoom.x)


# ------------------------------------------------------------------ camera
func delivery_camera() -> Dictionary:
	return {"center": Proj.ground_v(DELIVERY_CAM) + Vector2(0, -150), "zoom": 0.9}


func update_camera(delta: float) -> void:
	var goal := delivery_camera()
	var center: Vector2 = goal["center"]
	var zoom: float = goal["zoom"]
	var contact := resolved.contact if resolved != null else null
	if contact != null and contact.is_contact() and clock >= contact.t_contact:
		var bp := ball_world(clock)
		if bp != Vector3.INF:
			var plan := Vector2(bp.x, bp.y)
			var d := plan.length()
			if reduced_motion:
				# No continuous panning: a steady overview of the whole ground.
				center = Proj.ground(-8.0, 0.0) + Vector2(0, -60)
				zoom = 0.36
			else:
				zoom = clampf(0.92 - d * 0.017, 0.36, 0.9)
				var focus := Proj.to_screen(Vector3(bp.x, bp.y, bp.z * 0.6))
				center = Proj.ground(-2.0, 0.0).lerp(focus, 0.72) + Vector2(0, -60)
	var rate := 3.2
	if reduced_motion:
		cam_center = center
		cam_zoom = zoom
	else:
		var k := 1.0 - exp(-rate * delta)
		cam_center = cam_center.lerp(center, k)
		cam_zoom = lerpf(cam_zoom, zoom, k)
	# Never lose the ball: clamp the camera so the ball stays inside the view.
	var bpos := ball_world(clock)
	if bpos != Vector3.INF:
		var vs := get_viewport_rect().size / cam_zoom
		var sp := Proj.to_screen(bpos)
		var margin := vs * 0.12
		cam_center.x = clampf(cam_center.x, sp.x - vs.x * 0.5 + margin.x, sp.x + vs.x * 0.5 - margin.x)
		cam_center.y = clampf(cam_center.y, sp.y - vs.y * 0.5 + margin.y, sp.y + vs.y * 0.5 - margin.y)
	cam.position = cam_center
	cam.zoom = Vector2(cam_zoom, cam_zoom)
	sky.cam_offset = cam.position
	sky.reduced_motion = reduced_motion
	weather.reduced_motion = reduced_motion


func snap_camera_to_delivery() -> void:
	var goal := delivery_camera()
	cam_center = goal["center"]
	cam_zoom = goal["zoom"]


## Canvas (screen) position of a world point, for HUD overlays.
func screen_of(p: Vector3) -> Vector2:
	if batter_view.visible:
		return batter_view.project(p)
	return get_viewport().get_canvas_transform() * Proj.to_screen(p)

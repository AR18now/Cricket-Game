extends Node
## Event-driven audio: separate buses (Music, SFX{Ambience, Crowd, Impacts, UI}, Voice),
## pooled one-shots with variation, no-immediate-repeat variants, ducking under voice,
## and captions for every spoken line so audio is never required to understand play.

signal caption(text: String, speaker: String)

const BUSES := ["Music", "SFX", "Ambience", "Crowd", "Impacts", "UI", "Voice"]
const PARENT := {"Music": "Master", "SFX": "Master", "Voice": "Master",
	"Ambience": "SFX", "Crowd": "SFX", "Impacts": "SFX", "UI": "SFX"}
const POOL := 10

var _streams := {}
var _pool: Array = []
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _last_variant := {}
var _rng := RandomNumberGenerator.new()
var captions_enabled := true
var _voice_until := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = _loop_player("Music")
	_ambience = _loop_player("Ambience")
	_crowd = _loop_player("Crowd")
	_load_streams()
	apply_settings()
	if Engine.has_singleton("Save") or get_node_or_null("/root/Save"):
		get_node("/root/Save").changed.connect(apply_settings)


func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
	for b in BUSES:
		AudioServer.set_bus_send(AudioServer.get_bus_index(b), PARENT[b])
	# Gentle limiter on master to avoid clipping when many events stack.
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, lim)


func _loop_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _load_streams() -> void:
	var dir := DirAccess.open("res://assets/audio")
	if dir == null:
		return
	for f in dir.get_files():
		var name := f
		if name.ends_with(".import"):
			name = name.trim_suffix(".import")
		if not name.ends_with(".wav"):
			continue
		var key := name.get_basename()
		if _streams.has(key):
			continue
		var s = load("res://assets/audio/" + name)
		if s != null:
			_streams[key] = s


func has_sound(key: String) -> bool:
	return _streams.has(key) or _streams.has(key + "_1")


func apply_settings() -> void:
	var save := get_node_or_null("/root/Save")
	if save == null:
		return
	var s: Dictionary = save.data["settings"]
	_set_vol("Master", float(s["master"]))
	_set_vol("Music", float(s["music"]))
	_set_vol("SFX", float(s["sfx"]))
	_set_vol("Voice", float(s["voice"]))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), bool(s["muted"]))
	captions_enabled = bool(s["captions"])


func _set_vol(bus: String, lin: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))
	AudioServer.set_bus_mute(idx, lin <= 0.001)


func _pick(key: String) -> AudioStream:
	if _streams.has(key):
		return _streams[key]
	var variants: Array = []
	var i := 1
	while _streams.has("%s_%d" % [key, i]):
		variants.append(i)
		i += 1
	if variants.is_empty():
		return null
	var last: int = _last_variant.get(key, -1)
	var choices := variants.filter(func(v): return v != last)
	if choices.is_empty():
		choices = variants
	var pick: int = choices[_rng.randi_range(0, choices.size() - 1)]
	_last_variant[key] = pick
	return _streams["%s_%d" % [key, pick]]


func play(key: String, bus: String = "SFX", volume_db: float = 0.0, pitch_var: float = 0.04) -> void:
	var s := _pick(key)
	if s == null:
		return
	var player: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			player = p
			break
	if player == null:
		# Steal the oldest non-impact voice so bat/ball impacts are never cut.
		for p in _pool:
			if p.bus != "Impacts":
				player = p
				break
		if player == null:
			player = _pool[0]
	player.stream = s
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	player.play()


func _loop(player: AudioStreamPlayer, key: String, volume_db: float) -> void:
	var s = _streams.get(key)
	if s == null:
		player.stop()
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	if player.stream != s or not player.playing:
		player.stream = s
		player.play()
	player.volume_db = volume_db


func start_ambience(venue_id: String) -> void:
	_loop(_ambience, "amb_" + venue_id, -8.0)
	_loop(_crowd, "crowd_loop", -14.0)


func start_music(key: String = "music_loop") -> void:
	_loop(_music, key, -10.0)


func stop_music() -> void:
	_music.stop()


func set_crowd_intensity(k: float) -> void:
	_crowd.volume_db = lerpf(-16.0, -6.0, clampf(k, 0.0, 1.0))


## Spoken line: plays a reviewed clip if one exists, otherwise caption only.
func say(line: Dictionary, speaker: String = "Bilal") -> void:
	if line.is_empty():
		return
	var clip_key := "vo_" + String(line.get("id", ""))
	if _streams.has(clip_key):
		play(clip_key, "Voice", 0.0, 0.0)
		_duck(1.6)
	if captions_enabled:
		caption.emit(String(line.get("text", "")), speaker)


func _duck(seconds: float) -> void:
	var idx := AudioServer.get_bus_index("Music")
	var t := create_tween()
	var save := get_node_or_null("/root/Save")
	var base := linear_to_db(maxf(float(save.data["settings"]["music"]) if save else 1.0, 0.0001))
	t.tween_method(func(v): AudioServer.set_bus_volume_db(idx, v), base, base - 8.0, 0.1)
	t.tween_interval(seconds)
	t.tween_method(func(v): AudioServer.set_bus_volume_db(idx, v), base - 8.0, base, 0.4)


func stop_all_voice() -> void:
	for p in _pool:
		if p.bus == "Voice":
			p.stop()

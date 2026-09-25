extends Node
## Local, versioned, atomic save. Write order: save.tmp -> (save.json -> save.bak) -> save.json.
## Loading tries save.json, then save.tmp, then save.bak, validating each; anything
## unreadable falls back to defaults so the game always starts.

signal changed

const SCHEMA_VERSION := 2
const MAX_APPLIED := 64

var dir_path := "user://"
var data: Dictionary = {}
var last_load_source := ""


func _ready() -> void:
	load_or_default()


func configure(dir: String) -> void:
	dir_path = dir if dir.ends_with("/") else dir + "/"


func _p(name: String) -> String:
	return dir_path + name


static func defaults() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"settings": {"master": 1.0, "music": 0.6, "sfx": 1.0, "voice": 1.0, "muted": false,
			"captions": true, "reduced_motion": false, "haptics": true, "language": "roman_urdu",
			"timing_guide": true},
		"profile": {"display_name": "Ayaan", "kit": 0, "onboarded": false},
		"tutorial_done": false,
		"stance_unlocked": false,
		"best": {"endless_runs": 0, "endless_balls": 0, "quick_wins": 0, "quick_played": 0,
			"quick_best_margin": 0, "sixes": 0, "fours": 0},
		"challenges": {},
		"unlocks": ["kit_emerald"],
		"applied_results": [],
	}


func load_or_default() -> void:
	for name in ["save.json", "save.tmp", "save.bak"]:
		var d = _read(_p(name))
		if d is Dictionary:
			var v = validate(d)
			if v is Dictionary:
				data = v
				last_load_source = name
				return
	data = defaults()
	last_load_source = "defaults"


func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed


## Returns a sanitised, migrated copy or null if the data is unusable.
static func validate(d: Dictionary):
	if not d.has("version") and not d.has("settings"):
		return null
	var out := migrate(d.duplicate(true))
	var base := defaults()
	_merge_types(base, out)
	base["version"] = SCHEMA_VERSION
	# Clamp numeric settings.
	for k in ["master", "music", "sfx", "voice"]:
		base["settings"][k] = clampf(float(base["settings"][k]), 0.0, 1.0)
	var dn := String(base["profile"]["display_name"]).strip_edges().left(16)
	base["profile"]["display_name"] = dn if dn != "" else "Ayaan"
	for k in base["best"].keys():
		base["best"][k] = maxi(0, int(base["best"][k]))
	return base


## Upgrades older schemas in place.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v < 1:
		# v0 (prototype) stored a flat "high_score".
		if d.has("high_score"):
			d["best"] = {"endless_runs": int(d["high_score"])}
			d.erase("high_score")
		v = 1
	if v < 2:
		# v1 had "tutorial" as a nested dict.
		if d.has("tutorial") and d["tutorial"] is Dictionary:
			d["tutorial_done"] = bool(d["tutorial"].get("done", false))
			d.erase("tutorial")
		v = 2
	d["version"] = v
	return d


## Copies values from src into dst where the key exists in dst and the type matches.
static func _merge_types(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if not dst.has(k):
			if k == "challenges":
				continue
			continue
		var dv = dst[k]
		var sv = src[k]
		if dv is Dictionary and sv is Dictionary:
			if k == "challenges":
				dst[k] = sv.duplicate(true)
			else:
				_merge_types(dv, sv)
		elif dv is Array and sv is Array:
			dst[k] = sv.duplicate(true)
		elif (dv is float or dv is int) and (sv is float or sv is int):
			dst[k] = sv if dv is float else int(sv)
		elif typeof(dv) == typeof(sv):
			dst[k] = sv


func save() -> bool:
	var text := JSON.stringify(data, "\t")
	var tmp := _p("save.tmp")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot open temp file")
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# Verify what reached disk before replacing the good copy.
	var check = _read(tmp)
	if not (check is Dictionary):
		push_warning("Save: verification failed")
		return false
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	if dir.file_exists("save.json"):
		if dir.file_exists("save.bak"):
			dir.remove("save.bak")
		dir.rename("save.json", "save.bak")
	var err := dir.rename("save.tmp", "save.json")
	changed.emit()
	return err == OK


func setting(key: String):
	return data["settings"].get(key)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save()


## Applies a reward/progress update exactly once per result id (replays, resumes and
## double callbacks can never duplicate rewards).
func apply_result_once(result_id: String, fn: Callable) -> bool:
	var applied: Array = data["applied_results"]
	if result_id in applied:
		return false
	fn.call(data)
	applied.append(result_id)
	while applied.size() > MAX_APPLIED:
		applied.pop_front()
	save()
	return true

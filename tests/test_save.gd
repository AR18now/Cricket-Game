extends TestCase

var SaveScript = load("res://scripts/services/save_service.gd")


func _dir(name: String) -> String:
	var d := OS.get_user_data_dir() + "/test_saves/" + name
	DirAccess.make_dir_recursive_absolute(d)
	for f in ["save.json", "save.tmp", "save.bak"]:
		if FileAccess.file_exists(d + "/" + f):
			DirAccess.remove_absolute(d + "/" + f)
	return d


func _svc(dir: String):
	var s = SaveScript.new()
	s.configure(dir)
	return s


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_defaults_when_empty() -> void:
	var s = _svc(_dir("empty"))
	s.load_or_default()
	eq(s.last_load_source, "defaults")
	eq(s.data["version"], SaveScript.SCHEMA_VERSION)
	s.free()


func test_roundtrip_and_backup() -> void:
	var d := _dir("roundtrip")
	var s = _svc(d)
	s.load_or_default()
	s.data["best"]["endless_runs"] = 42
	check(s.save(), "first save")
	s.data["best"]["endless_runs"] = 50
	check(s.save(), "second save")
	check(FileAccess.file_exists(d + "/save.bak"), "backup kept")
	var s2 = _svc(d)
	s2.load_or_default()
	eq(s2.data["best"]["endless_runs"], 50)
	s.free()
	s2.free()


func test_corrupt_main_falls_back_to_backup() -> void:
	var d := _dir("corrupt")
	var s = _svc(d)
	s.load_or_default()
	s.data["best"]["quick_wins"] = 7
	s.save()
	s.data["best"]["quick_wins"] = 8
	s.save()
	_write(d + "/save.json", "{ this is not json")
	var s2 = _svc(d)
	s2.load_or_default()
	eq(s2.last_load_source, "save.bak")
	eq(s2.data["best"]["quick_wins"], 7, "recovered previous good copy")
	s.free()
	s2.free()


func test_interrupted_write_recovers_tmp() -> void:
	# Crash after writing tmp and moving main to bak, before the final rename.
	var d := _dir("interrupted")
	var good: Dictionary = SaveScript.defaults()
	good["best"]["endless_runs"] = 99
	_write(d + "/save.tmp", JSON.stringify(good))
	var old: Dictionary = SaveScript.defaults()
	old["best"]["endless_runs"] = 10
	_write(d + "/save.bak", JSON.stringify(old))
	var s = _svc(d)
	s.load_or_default()
	eq(s.last_load_source, "save.tmp")
	eq(s.data["best"]["endless_runs"], 99)
	s.free()


func test_truncated_tmp_ignored() -> void:
	var d := _dir("truncated")
	var old: Dictionary = SaveScript.defaults()
	old["best"]["endless_runs"] = 12
	_write(d + "/save.json", JSON.stringify(old))
	_write(d + "/save.tmp", "{\"version\": 2, \"settings\": {")
	var s = _svc(d)
	s.load_or_default()
	eq(s.last_load_source, "save.json")
	eq(s.data["best"]["endless_runs"], 12)
	s.free()


func test_migration_from_v0_and_v1() -> void:
	var v0 := {"settings": {"music": 0.3}, "high_score": 77}
	var m = SaveScript.validate(v0)
	eq(m["best"]["endless_runs"], 77, "v0 high score migrated")
	near(m["settings"]["music"], 0.3, 0.0001)
	var v1 := {"version": 1, "settings": {}, "tutorial": {"done": true}}
	var m1 = SaveScript.validate(v1)
	eq(m1["tutorial_done"], true, "v1 tutorial flag migrated")
	eq(m1["version"], SaveScript.SCHEMA_VERSION)


func test_validation_sanitises() -> void:
	var bad := {"version": 2, "settings": {"master": 9.0, "muted": "yes"}, "profile": {"display_name": "   "},
		"best": {"endless_runs": -5, "sixes": "lots"}}
	var v = SaveScript.validate(bad)
	near(v["settings"]["master"], 1.0, 0.0001, "clamped")
	eq(v["settings"]["muted"], false, "wrong type ignored")
	eq(v["profile"]["display_name"], "Ayaan", "blank name -> default")
	eq(v["best"]["endless_runs"], 0, "negative clamped")
	eq(v["best"]["sixes"], 0, "wrong type ignored")
	eq(SaveScript.validate({"foo": 1}), null, "unrelated JSON rejected")


func test_rewards_applied_once() -> void:
	var s = _svc(_dir("rewards"))
	s.load_or_default()
	var inc := func(d: Dictionary): d["best"]["quick_wins"] = int(d["best"]["quick_wins"]) + 1
	check(s.apply_result_once("quick-1", inc), "applied")
	check(not s.apply_result_once("quick-1", inc), "duplicate ignored")
	eq(s.data["best"]["quick_wins"], 1)
	s.free()

extends SceneTree
## Headless test runner: godot --headless --path . --script res://tests/run_tests.gd
## Optional filter: -- --filter=test_scoring


var _elapsed := 0.0


## Watchdog: never hang CI if a test stalls.
func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > 240.0:
		printerr("Test run timed out")
		quit(2)
	return false


func _initialize() -> void:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var total_checks := 0
	var all_failures: Array = []
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	var ran := 0
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")) or f == "test_case.gd":
			continue
		if filter != "" and not f.contains(filter):
			continue
		var script = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			all_failures.append("%s: failed to load/parse" % f)
			print("  FAIL %s (parse/load error)" % f)
			continue
		var inst = script.new()
		var methods: Array = []
		for m in inst.get_method_list():
			if String(m["name"]).begins_with("test_"):
				methods.append(String(m["name"]))
		methods.sort()
		for m in methods:
			inst.current = f.get_basename() + "." + m
			var before: int = inst.failures.size()
			var r = inst.call(m)
			if r is Object and r.get_class() == "GDScriptFunctionState":
				await r.completed
			ran += 1
			var ok: bool = inst.failures.size() == before
			print("  %s %s" % ["PASS" if ok else "FAIL", inst.current])
		total_checks += inst.checks
		all_failures.append_array(inst.failures)
	print("")
	for fl in all_failures:
		printerr("FAILED: ", fl)
	print("Tests: %d  Checks: %d  Failures: %d" % [ran, total_checks, all_failures.size()])
	quit(1 if all_failures.size() > 0 else 0)

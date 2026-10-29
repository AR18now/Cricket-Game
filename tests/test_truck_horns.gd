extends TestCase
## The truck plays a different Pakistani horn each time it appears (never twice in a row).


func test_horn_variants_rotate_without_repeats() -> void:
	var a = load("res://scripts/services/audio_director.gd").new()
	a._load_streams()
	check(not a._streams.has("truck_horn"), "no single fixed horn")
	var n := 0
	while a._streams.has("truck_horn_%d" % (n + 1)):
		n += 1
	check(n >= 6, "at least six different horns (found %d)" % n)
	var last = null
	var seen := {}
	for i in 60:
		var s = a._pick("truck_horn")
		check(s != null, "a horn is picked")
		check(s != last, "never the same horn twice in a row")
		seen[s] = true
		last = s
	check(seen.size() == n, "every horn gets played over 60 trucks (%d of %d)" % [seen.size(), n])
	a.free()

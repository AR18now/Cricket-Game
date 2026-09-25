class_name FielderSpec
extends RefCounted
## A fielder's starting state for one delivery. Movement limits come from GameTuning.

var name := ""
var position_name := ""
var role := "fielder"  # fielder | keeper | bowler
var pos := Vector2.ZERO
var speed := 6.6
var reaction := 0.34


static func make(n: String, p: Vector2, r: String, tuning: GameTuning) -> FielderSpec:
	var f := FielderSpec.new()
	f.name = n
	f.pos = p
	f.role = r
	f.speed = tuning.fielder_speed
	f.reaction = tuning.fielder_reaction
	if r == "keeper":
		f.speed = tuning.fielder_speed * 0.7
		f.reaction = tuning.fielder_reaction * 0.8
	elif r == "bowler":
		f.reaction = tuning.fielder_reaction + 0.25
	return f


## Builds the fielding side from a venue layout. Names come from the fielding squad.
static func from_layout(layout: Array, names: Array, tuning: GameTuning) -> Array:
	var out: Array = []
	for i in layout.size():
		var entry: Array = layout[i]
		var n: String = names[i] if i < names.size() else String(entry[0])
		var f := FielderSpec.make(n, Vector2(entry[1], entry[2]), String(entry[3]), tuning)
		f.position_name = String(entry[0])
		out.append(f)
	return out

class_name TestCase
extends RefCounted
## Minimal assertion base (no external test framework dependency).

var failures: Array = []
var checks := 0
var current := ""


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a, b, msg: String = "") -> void:
	check(a == b, "%s expected %s got %s" % [msg, str(b), str(a)])


func near(a: float, b: float, tol: float, msg: String = "") -> void:
	check(absf(a - b) <= tol, "%s expected %.4f±%.4f got %.4f" % [msg, b, tol, a])


static func tuning() -> GameTuning:
	return load("res://data/tuning_default.tres").duplicate()


static func venue() -> VenueConfig:
	return load("res://data/venues/pindi.tres")


static func bowler(id: String) -> BowlerProfile:
	return load("res://data/bowlers/%s.tres" % id)


static func field(t: GameTuning) -> Array:
	var v := venue()
	return FielderSpec.from_layout(v.field_layout, ["Hamza", "Usman", "Imran", "Kashif", "Rizwan", "Tariq", "Nadeem", "Sohail", "Asif", "Waqar"], t)


## Swing time (sim s) that makes the bat arrive dt_ms after the ideal contact moment.
static func swing_for(d: Delivery, t: GameTuning, dt_ms: float) -> float:
	return d.time_at_x(t.contact_x_ideal) - t.swing_to_contact + dt_ms / 1000.0


## A delivery whose ball flies at a fixed launch (bypasses timing) for rule tests.
static func contact_with(launch: Vector3, at: Vector3 = Vector3(-1.6, 0.0, 0.6)) -> ContactResult:
	var c := ContactResult.new()
	c.swung = true
	c.category = ContactResult.GOOD
	c.contact_pos = at
	c.launch_vel = launch
	return c

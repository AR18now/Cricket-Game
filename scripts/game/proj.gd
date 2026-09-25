class_name Proj
extends RefCounted
## Fixed oblique projection from the pseudo-3D world (metres) to 2D canvas pixels.
## x runs along the pitch (screen right = toward the batter / keeper), y is lateral
## depth (compressed by DEPTH), z is height (straight up the screen).

const S := 48.0       # pixels per metre
const DEPTH := 0.24   # lateral foreshortening


static func to_screen(p: Vector3) -> Vector2:
	return Vector2(p.x * S, p.y * S * DEPTH - p.z * S)


static func ground(x: float, y: float) -> Vector2:
	return Vector2(x * S, y * S * DEPTH)


static func ground_v(p: Vector2) -> Vector2:
	return Vector2(p.x * S, p.y * S * DEPTH)


## Inverse for a point on the ground plane.
static func to_world_ground(s: Vector2) -> Vector2:
	return Vector2(s.x / S, s.y / (S * DEPTH))

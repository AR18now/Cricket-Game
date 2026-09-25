class_name VenueConfig
extends Resource
## A ground: boundary shape, surface behaviour, fielding layout and presentation palette.

@export var id := "pindi"
@export var display_name := "Pindi Courtyard"
@export var boundary_center := Vector2(-8.0, 0.0)
@export var boundary_rx := 42.0
@export var boundary_ry := 31.0
## Rolling deceleration of the ball on this surface (m/s^2).
@export var roll_decel := 2.6
## Fielder layout: [name, x, y, role]
@export var field_layout: Array = []
@export var sky_top := Color(0.2, 0.18, 0.35)
@export var sky_bottom := Color(0.98, 0.62, 0.36)
@export var ground_color := Color(0.78, 0.62, 0.42)
@export var ground_edge_color := Color(0.62, 0.45, 0.3)
@export var pitch_color := Color(0.86, 0.74, 0.56)
@export var boundary_color := Color(0.97, 0.95, 0.9)
@export_multiline var description := ""


## Normalised elliptical "radius": < 1 inside the boundary, >= 1 on/over the rope.
func boundary_metric(p: Vector2) -> float:
	var d := p - boundary_center
	return sqrt((d.x / boundary_rx) * (d.x / boundary_rx) + (d.y / boundary_ry) * (d.y / boundary_ry))


func is_inside(p: Vector2) -> bool:
	return boundary_metric(p) < 1.0


## Distance from the batter's stumps to the rope along a shot direction.
func boundary_distance(dir: Vector2) -> float:
	var lo := 0.0
	var hi := 200.0
	for i in 40:
		var mid := (lo + hi) * 0.5
		if is_inside(dir * mid):
			lo = mid
		else:
			hi = mid
	return lo

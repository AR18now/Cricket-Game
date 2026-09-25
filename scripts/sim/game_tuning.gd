class_name GameTuning
extends Resource
## All tunable gameplay values in one resource (see data/tuning_default.tres).
## Units: metres, seconds, m/s, degrees unless stated otherwise.

@export_group("Batting contact")
## Delay between an accepted tap and the bat reaching the hitting zone (animation matches).
@export var swing_to_contact := 0.10
## Ball x (along pitch, batter stumps at 0) where contact is ideal.
@export var contact_x_ideal := -1.6
## Earliest ball position the bat can still meet (further = swung too early).
@export var contact_x_early := -2.9
## Latest position for a middled (non-edge) contact.
@export var contact_x_late := -0.5
## Latest position for any contact (between late and edge = thin edge).
@export var contact_x_edge := -0.22
## Highest ball the bat can reach at contact.
@export var bat_reach_height := 1.55
@export var perfect_ms := 26.0
@export var good_ms := 55.0
## Tutorial deliveries widen the perfect/good windows by this factor.
@export var tutorial_window_scale := 1.5
## Seconds before ideal contact at which taps start counting as a swing.
@export var batting_window_lead := 0.55

@export_group("Shot launch")
@export var exit_speed_base := 25.0
@export var exit_speed_incoming_factor := 0.22
@export var speed_factor := {"perfect": 1.0, "good": 0.86, "early": 0.64, "late": 0.6, "edge": 0.5}
@export var max_direction_deg := 82.0
## Perfect contacts are hit within this many degrees of straight (the "V").
@export var perfect_direction_deg := 15.0
@export var line_direction_deg_per_m := 22.0
@export var direction_jitter_deg := 5.0
@export var elevation_jitter_deg := 1.5
## Launch elevation (degrees) per stance and timing category.
@export var elevation_auto := {"perfect": 22.0, "good": 6.0, "early": 12.0, "late": 3.0, "edge": 10.0}
@export var elevation_grounded := {"perfect": 2.5, "good": 2.0, "early": 4.0, "late": 1.0, "edge": 6.0}
@export var elevation_lofted := {"perfect": 28.0, "good": 22.0, "early": 24.0, "late": 16.0, "edge": 18.0}
@export var elevation_per_contact_height := 9.0

@export_group("Ball physics")
@export var gravity := 9.81
@export var air_drag := 0.0032
@export var ground_restitution := 0.36
@export var bounce_friction := 0.7
@export var stop_speed := 0.35
@export var sim_hz := 120.0
@export var max_shot_time := 14.0

@export_group("Fielding")
@export var fielder_reaction := 0.34
@export var fielder_speed := 6.6
@export var catch_reach := 1.35
@export var catch_min_height := 0.12
@export var catch_max_height := 2.6
@export var stop_reach := 1.0
@export var stop_max_height := 1.2
@export var pickup_time := 0.6
@export var throw_speed := 20.0

@export_group("Running (arcade automatic running)")
@export var first_run_time := 2.7
@export var next_run_time := 2.0
@export var run_safety := 0.2
@export var max_runs := 3

@export_group("Delivery")
@export var release_x := -18.7
@export var release_height := 2.05
@export var bounce_restitution := 0.52
@export var pitch_retention := 0.9
@export var min_contact_height := 0.12
@export var max_contact_height := 1.4

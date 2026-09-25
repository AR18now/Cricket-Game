class_name BowlerProfile
extends Resource
## A fictional bowler's learnable behaviour. Every field maps to implemented delivery parameters.

@export var id := "bowler"
@export var display_name := "Bowler"
@export var nickname := ""
@export var style := "medium"  # pace | medium | spin | tutorial
@export var speed_min := 20.0  # m/s (horizontal release speed)
@export var speed_max := 24.0
@export var slower_chance := 0.0
@export var slower_min := 16.0
@export var slower_max := 18.0
@export var length_min := 3.5  # metres from batter stumps where the ball pitches
@export var length_max := 7.0
@export var line_min := -0.15  # lateral aim at the stumps (m, + = off side)
@export var line_max := 0.3
@export var deviation_max := 0.0  # sideways m/s added off the pitch (seam / spin)
@export var release_y := 0.35
@export var run_up_time := 1.9
@export var kit_color := Color(0.8, 0.35, 0.2)
@export var skin_tone := Color(0.72, 0.5, 0.36)
@export var hair_color := Color(0.1, 0.08, 0.07)
@export var cue_line := ""
@export_multiline var description := ""

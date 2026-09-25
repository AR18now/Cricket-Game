class_name Atmosphere
extends RefCounted
## Time-of-day / weather preset shared by both camera views.
## Rain also makes the outfield slower (documented in GAME_RULES.md).

const IDS := ["day", "evening", "night", "rain"]
const LABELS := {"day": "Day", "evening": "Evening", "night": "Night", "rain": "Rain"}

var id := "evening"
var sky_top := Color(0.23, 0.2, 0.38)
var sky_bottom := Color(0.98, 0.64, 0.38)
var ambient := Color(1, 1, 1)
var sun := true
var sun_color := Color(1.0, 0.9, 0.7)
var sun_height := 0.52        # fraction of screen height
var moon := false
var stars := false
var clouds := 0.0             # 0..1 cloud cover
var floodlights := false
var rain := false
var window_glow := false
var roll_decel_mult := 1.0
var ambience := "amb_pindi"
var ball_boost := 1.0         # ball colour compensation so it stays vivid


static func make(which: String) -> Atmosphere:
	var a := Atmosphere.new()
	a.id = which if which in IDS else "evening"
	match a.id:
		"day":
			a.sky_top = Color(0.33, 0.58, 0.9)
			a.sky_bottom = Color(0.8, 0.9, 0.97)
			a.ambient = Color(1.0, 1.0, 1.0)
			a.sun_color = Color(1.0, 0.98, 0.85)
			a.sun_height = 0.16
			a.clouds = 0.35
		"evening":
			a.sky_top = Color(0.23, 0.2, 0.38)
			a.sky_bottom = Color(0.98, 0.64, 0.38)
			a.ambient = Color(1.0, 0.93, 0.86)
			a.window_glow = true
		"night":
			a.sky_top = Color(0.01, 0.02, 0.07)
			a.sky_bottom = Color(0.08, 0.1, 0.22)
			a.ambient = Color(0.7, 0.73, 0.88)
			a.sun = false
			a.moon = true
			a.stars = true
			a.floodlights = true
			a.window_glow = true
			a.ambience = "amb_night"
			a.ball_boost = 1.5
		"rain":
			a.sky_top = Color(0.3, 0.34, 0.4)
			a.sky_bottom = Color(0.56, 0.6, 0.64)
			a.ambient = Color(0.76, 0.79, 0.86)
			a.sun = false
			a.clouds = 1.0
			a.floodlights = true
			a.rain = true
			a.window_glow = true
			a.roll_decel_mult = 1.4
			a.ambience = "amb_rain"
			a.ball_boost = 1.25
	return a

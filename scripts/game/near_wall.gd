class_name NearWall
extends Node2D
## Foreground of the wide view (bottom of the screen): the front rows of the near stand
## behind a padded boundary wall with advertising-style boards. Drawn once (cached).

const BOARD := Color(0.1, 0.17, 0.3)
const TRIM := Color(0.85, 0.85, 0.82)
static var crowd_tex: Texture2D


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	if crowd_tex == null:
		crowd_tex = load("res://assets/textures/crowd.png")
	var y := GroundView.NEAR_WALL_Y
	var a := Proj.to_screen(Vector3(GroundView.X_MIN, y, 0.0)) - position
	var b := Proj.to_screen(Vector3(GroundView.X_MAX, y, 1.3)) - position
	var rect := Rect2(Vector2(a.x, b.y), Vector2(b.x - a.x, a.y - b.y + 1400.0))
	# Seated crowd filling the stand below the wall (seen from above and behind).
	var crowd := Rect2(rect.position + Vector2(0, 46), Vector2(rect.size.x, rect.size.y - 46))
	var tile := Vector2(1024, 256)
	var uv1 := Vector2(crowd.size.x / tile.x, crowd.size.y / tile.y)
	var pts := PackedVector2Array([crowd.position, Vector2(crowd.end.x, crowd.position.y), crowd.end, Vector2(crowd.position.x, crowd.end.y)])
	var cc := Color(0.62, 0.62, 0.66)   # under the stand roof's shade
	draw_polygon(pts, PackedColorArray([cc, cc, cc, cc]), PackedVector2Array([Vector2.ZERO, Vector2(uv1.x, 0), uv1, Vector2(0, uv1.y)]), crowd_tex)
	# Shadow cast by the wall onto the first rows.
	draw_rect(Rect2(crowd.position, Vector2(crowd.size.x, 26)), Color(0, 0, 0, 0.3))
	# Boundary boards: navy panels with a white trim.
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 46)), BOARD)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7)), TRIM)
	draw_rect(Rect2(rect.position + Vector2(0, 40), Vector2(rect.size.x, 6)), Color(0.05, 0.08, 0.15))
	var x := rect.position.x
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y + 7), Vector2(x, rect.position.y + 40), Color(0.2, 0.28, 0.45), 2.0)
		x += 260.0

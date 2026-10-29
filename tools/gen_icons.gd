extends SceneTree
## Store and launcher icons rendered from icon.svg (run: godot --headless -s tools/gen_icons.gd).
##  icon_1024.png         App Store: full-bleed square, no transparency (Apple rounds it)
##  icon_512_play.png     Google Play listing icon (Play applies its own mask)
##  icon_192.png          Android legacy launcher icon (rounded)
##  adaptive_fg_432.png   Android adaptive foreground (art inside the 66% safe zone)
##  adaptive_bg_432.png   Android adaptive background (solid brand green)
##  adaptive_mono_432.png Android 13+ themed (monochrome) icon

const OUT := "res://assets/icons/"


func _render(svg: String, px: int) -> Image:
	var img := Image.new()
	img.load_svg_from_string(svg, px / 256.0)
	return img


func _init() -> void:
	var f := FileAccess.open("res://icon.svg", FileAccess.READ)
	var svg := f.get_as_text()
	var full := svg.replace('rx="56"', 'rx="0"')
	var img := _render(full, 1024)
	img.convert(Image.FORMAT_RGB8)   # no alpha channel for the App Store
	img.save_png(OUT + "icon_1024.png")
	_render(full, 512).save_png(OUT + "icon_512_play.png")
	_render(svg, 192).save_png(OUT + "icon_192.png")
	# Adaptive layers: background = the green square; foreground = the badge scaled into
	# the central safe zone on transparency.
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color("#08594a"))
	bg.save_png(OUT + "adaptive_bg_432.png")
	var badge := svg.replace('<rect width="256" height="256" rx="56" fill="#08594a"/>', "")
	badge = badge.replace('viewBox="0 0 256 256"', 'viewBox="-24 -24 304 304"')   # badge fills the 66% safe zone
	var fg := _render(badge, 432)
	fg.save_png(OUT + "adaptive_fg_432.png")
	# Themed icon: ring + bat + ball silhouette (the disc itself left open).
	var mono_svg := badge.replace('fill="#0b6b57"', 'fill="none"')
	var mono := _render(mono_svg, 432)
	for y in mono.get_height():
		for x in mono.get_width():
			var c := mono.get_pixel(x, y)
			mono.set_pixel(x, y, Color(1, 1, 1, c.a))
	mono.save_png(OUT + "adaptive_mono_432.png")
	print("icons written")
	quit()

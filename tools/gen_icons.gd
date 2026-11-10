extends SceneTree
## Store and launcher icons rendered from icon.svg (run: godot --headless -s tools/gen_icons.gd).
##  icon_1024.png         App Store: full-bleed square, no transparency (Apple rounds it)
##  icon_512_play.png     Google Play listing icon (Play applies its own mask)
##  icon_192.png          Android legacy launcher icon (rounded)
##  adaptive_fg_432.png   Android adaptive foreground (art inside the 66% safe zone)
##  adaptive_bg_432.png   Android adaptive background (stadium-green backdrop)
##  adaptive_mono_432.png Android 13+ themed (monochrome) icon

const OUT := "res://assets/icons/"


func _render(svg: String, px: int) -> Image:
	var img := Image.new()
	img.load_svg_from_string(svg, px / 256.0)
	return img


func _init() -> void:
	var f := FileAccess.open("res://icon.svg", FileAccess.READ)
	var svg := f.get_as_text()
	# icon.svg marks its background between <!--BG--> and <!--/BG-->.
	var b0 := svg.find("<!--BG-->")
	var b1 := svg.find("<!--/BG-->") + "<!--/BG-->".length()
	var background := svg.substr(b0, b1 - b0)
	var full := svg.replace('rx="56"', 'rx="0"')
	var img := _render(full, 1024)
	img.convert(Image.FORMAT_RGB8)   # no alpha channel for the App Store
	img.save_png(OUT + "icon_1024.png")
	var play := _render(full, 512)
	play.convert(Image.FORMAT_RGBA8)   # Play asks for a 32-bit PNG (full square, opaque)
	play.save_png(OUT + "icon_512_play.png")
	_render(svg, 192).save_png(OUT + "icon_192.png")
	# Adaptive layers: background = the stadium backdrop (square); foreground = bat and
	# ball scaled into the central safe zone on transparency.
	var bg_svg := svg.substr(0, b0) + background.replace('rx="56"', 'rx="0"') + "</svg>"
	_render(bg_svg, 432).save_png(OUT + "adaptive_bg_432.png")
	var badge := svg.substr(0, b0) + svg.substr(b1)
	badge = badge.replace('viewBox="0 0 256 256"', 'viewBox="-28 -28 312 312"')   # fits the 66% safe zone
	var fg := _render(badge, 432)
	fg.save_png(OUT + "adaptive_fg_432.png")
	# Themed icon (Android 13+): the bat-and-ball silhouette in one colour.
	var mono := _render(badge, 432)
	for y in mono.get_height():
		for x in mono.get_width():
			var c := mono.get_pixel(x, y)
			mono.set_pixel(x, y, Color(1, 1, 1, c.a))
	mono.save_png(OUT + "adaptive_mono_432.png")
	print("icons written")
	quit()

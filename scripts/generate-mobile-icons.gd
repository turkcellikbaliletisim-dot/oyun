extends SceneTree
func _initialize() -> void:
	var svg = FileAccess.get_file_as_string("res://oyun/icon.svg")
	for size in [192, 432, 1024]:
		var image = Image.new()
		if image.load_svg_from_string(svg, float(size) / 512) != OK:
			quit(1)
			return
		image.convert(Image.FORMAT_RGB8)
		image.save_png("res://native/mobile-assets/app-icon-%d.png" % size)
	quit()

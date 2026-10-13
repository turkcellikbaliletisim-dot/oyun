extends SceneTree
## Normalize generated artwork for predictable mobile memory use.
func _initialize() -> void:
	var assets = {
		"hero_player_alt3.png": Vector2i(512, 512),
		"hero_player_alt4.png": Vector2i(512, 512),
		"hero_player_alt5.png": Vector2i(512, 512),
		"splash_clean.png": Vector2i(1242, 2688),
		"badge_rank_bronze.png": Vector2i(128, 128),
		"badge_rank_silver.png": Vector2i(128, 128),
		"badge_rank_gold.png": Vector2i(128, 128)
	}
	for file in assets:
		var path = "res://native/skin/" + file
		if not FileAccess.file_exists(path):
			continue
		var image = Image.load_from_file(path)
		if image == null:
			push_error("Artwork unreadable: " + file)
			quit(1)
			return
		var dimensions: Vector2i = assets[file]
		if image.get_size() != dimensions:
			image.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
			image.save_png(path)
		print(file, " ", image.get_size())
	quit()

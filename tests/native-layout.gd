extends SceneTree
var failures = 0
var stage = ""
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func check_bounds(node: Node, width: float) -> void:
	if node is Control and node.is_visible_in_tree() and not node.has_meta("decor"):
		if node is Button and not node.has_meta("card_overlay"):
			check(node.size.y <= 160, "Touch button is unusably tall: " + node.text)
		var rect = node.get_global_rect()
		check(rect.position.x >= -1 and rect.end.x <= width + 1, node.get_class() + " " + str(node.name) + " [" + str(node.get("text")) + "] overflows in " + stage + " at " + str(width) + ": " + str(rect))
	if node is ScrollContainer and node.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return
	for child in node.get_children():
		check_bounds(child, width)
func snapshot(name: String, dimensions: Vector2i) -> void:
	if OS.get_environment("DESTAN_NATIVE_VISUAL") == "1" and (dimensions == Vector2i(390, 844) or dimensions == Vector2i(844, 390)):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png((OS.get_environment("DESTAN_SNAPSHOT_DIR") if not OS.get_environment("DESTAN_SNAPSHOT_DIR").is_empty() else "/tmp") + "/destan-mobile-" + name + ("-landscape" if dimensions.x > 600 else "") + ".png")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	app.poll.stop()
	await app.connect_account()
	check(not app.account.is_empty(), "Layout test account failed")
	for dimensions in [Vector2i(390, 844), Vector2i(360, 800), Vector2i(844, 390), Vector2i(1280, 900)]:
		if OS.get_environment("DESTAN_NATIVE_VISUAL") == "1":
			DisplayServer.window_set_size(dimensions)
		root.size = dimensions
		app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app.room = {}
		app.view = "lobby"
		app.render()
		for frame in range(5):
			await process_frame
		check(app.get_combined_minimum_size().x <= dimensions.x, "Shell overflows at " + str(dimensions) + " " + str(app.get_combined_minimum_size()))
		check_bounds(app.shell_margin, app.get_viewport_rect().size.x)
		stage = "lobby"
		await snapshot("lobby", dimensions)
		for uga_view in ["uga_heroes", "uga_totems", "uga_chests", "uga_missions", "uga_rebirth", "uga_online", "duel"]:
			app.view = uga_view
			app.render()
			for frame in range(4):
				await process_frame
			stage = uga_view
			check(app.get_combined_minimum_size().x <= dimensions.x, "Shell overflows in " + uga_view + " at " + str(dimensions) + " " + str(app.get_combined_minimum_size()))
			check_bounds(app.shell_margin, app.get_viewport_rect().size.x)
		app.view = "lobby"
		app.render()
		app.open_tab("story")
		for frame in range(5):
			await process_frame
		stage = "story"
		check_bounds(app.shell_margin, app.get_viewport_rect().size.x)
		await snapshot("story", dimensions)
		app.show_collection()
		for frame in range(5):
			await process_frame
		check(app.content.get_combined_minimum_size().x <= dimensions.x - 24, "Collection overflows at " + str(dimensions))
		check_bounds(app.shell_margin, app.get_viewport_rect().size.x)
		stage = "collection"
		await snapshot("collection", dimensions)
		app.gallery_open = false
		app.view = "deck"
		app.render()
		for frame in range(5):
			await process_frame
		stage = "deck"
		check_bounds(app.shell_margin, app.get_viewport_rect().size.x)
		await snapshot("deck", dimensions)
		app.view = "lobby"
		app.show_collection()
		app.gallery_open = false
		app.view = "deck"
		app.render()
		for frame in range(5):
			await process_frame
		check_bounds(app.shell_margin, app.get_viewport_rect().size.x)
		app.view = "lobby"
		await app.mutate("solo", {"chapterId": 1})
		for frame in range(5):
			await process_frame
		check_bounds(app.shell_margin, app.get_viewport_rect().size.x)
		stage = "match"
		await snapshot("match", dimensions)
		await app.move({"type": "mulligan", "indices": []})
		for frame in range(5):
			await process_frame
		check_bounds(app.shell_margin, app.get_viewport_rect().size.x)
		stage = "match-play"
		await snapshot("match-play", dimensions)
		await app.leave_match()
	print("Mobile layout failures: ", failures)
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)

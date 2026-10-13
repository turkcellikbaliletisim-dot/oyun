extends SceneTree
# Bot'a karşı bir hikâye maçını otomatik oynar ve her hamlede ekran görüntüsü kaydeder.
var shot = 0
func snap(app) -> void:
	var dir = OS.get_environment("DESTAN_FRAMES_DIR")
	var finished = app.room.get("state") != null and app.room.state.status == "finished"
	var count = 30 if finished else (6 if app.room.is_empty() else 14)
	if OS.get_environment("DESTAN_REPEAT") != "":
		count = int(OS.get_environment("DESTAN_REPEAT"))
	for repeat in count:
		await create_timer(0.07).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/f%04d.png" % [dir, shot])
		shot += 1
func _initialize() -> void:
	call_deferred("run")
func pick(legal: Array) -> Dictionary:
	for kind in ["mulligan", "play", "attack", "scry", "discard", "end"]:
		for action in legal:
			if action.type == kind:
				if kind == "mulligan":
					return {"type": "mulligan", "indices": []}
				return action
	return {}
func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var size = Vector2i(844, 390)
	if OS.get_environment("DESTAN_SIZE") == "portrait":
		size = Vector2i(390, 844)
	var factor = int(OS.get_environment("DESTAN_SCALE")) if OS.get_environment("DESTAN_SCALE") != "" else 1
	if factor > 1:
		DisplayServer.window_set_size(size * factor)
		root.size = size * factor
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.content_scale_size = size
	else:
		DisplayServer.window_set_size(size)
		root.size = size
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	app.poll.stop()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await app.connect_account()
	app.render()
	await snap(app)
	await app.mutate("solo", {"chapterId": int(OS.get_environment("DESTAN_CHAPTER")) if OS.get_environment("DESTAN_CHAPTER") != "" else 1})
	await snap(app)
	var guard = 0
	while app.room.get("state") != null and app.room.state.status != "finished" and guard < (int(OS.get_environment("DESTAN_MOVES")) if OS.get_environment("DESTAN_MOVES") != "" else 200):
		guard += 1
		var action = pick(app.room.get("actions", []))
		if action.is_empty():
			break
		await app.move(action)
		await snap(app)
	print("Oynanan hamle: ", guard, " · sonuç: ", app.room.state.status if app.room.get("state") != null else "?")
	quit(0)

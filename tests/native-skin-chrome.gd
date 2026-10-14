extends SceneTree
## Focused regression checks for the additional presentation layer.
var failures = 0
var measurements: Array = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in range(5):
		await process_frame

func snapshot(tag: String, dimensions: Vector2i) -> void:
	if OS.get_environment("DESTAN_NATIVE_VISUAL") != "1":
		return
	var directory = OS.get_environment("DESTAN_SNAPSHOT_DIR")
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	var path = directory.path_join("chrome-%s-%dx%d.png" % [tag, dimensions.x, dimensions.y])
	check(root.get_texture().get_image().save_png(path) == OK, "Could not save screenshot")

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	app.poll.stop()
	await app.connect_account()
	check(not app.account.is_empty(), "Skin test account bootstrap failed")
	if app.account.is_empty():
		app.queue_free()
		await settle()
		quit(1)
		return
	check(is_instance_valid(app.chrome_background), "PNG backdrop was not installed")
	check(is_instance_valid(app.chrome_connection), "Connection icon was not installed")
	check(is_instance_valid(app.chrome_navigation), "Navigation artwork was not installed")
	check(app.chrome_background.texture == app.skin_art("backdrop.png"), "Backdrop is still the SVG")
	check(app.nav_buttons.size() == 4, "Expected exactly four navigation buttons")
	check(app.chrome_navigation.get_meta("socket_count") == 4, "Expected four artwork sockets")
	for dimensions in [Vector2i(360, 800), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 900)]:
		if OS.get_environment("DESTAN_NATIVE_VISUAL") == "1":
			DisplayServer.window_set_size(dimensions)
		root.size = dimensions
		app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for tab in ["play", "story", "collection", "deck"]:
			app.nav_buttons[tab].pressed.emit()
			await settle()
			check(app.chrome_navigation.is_visible_in_tree(), "Navigation did not reappear in " + tab)
			var active_count = 0
			for key in app.chrome_highlights:
				var halo: Control = app.chrome_highlights[key]
				if halo.visible:
					active_count += 1
				check(halo.visible == (key == tab), "Wrong highlighted tab: " + key)
				var button: Button = app.nav_buttons[key]
				check(button.size.x >= 44 and button.size.y >= 44, "Navigation touch target too small")
				var rect = button.get_global_rect()
				check(rect.position.x >= -1 and rect.end.x <= dimensions.x + 1, "Navigation overflows horizontally")
				check(rect.position.y >= -1 and rect.end.y <= dimensions.y + 1, "Navigation overflows vertically")
			check(active_count == 1, "Expected one active halo")
			measurements.append({"width": dimensions.x, "height": dimensions.y, "tab": tab, "active_halos": active_count, "navigation_height": app.chrome_navigation.size.y})
			await snapshot(tab, dimensions)
		app.open_tab("play")
		await settle()
		for state in [false, true]:
			app.connected = state
			await settle()
			var expected = "icon_net_ok.png" if state else "icon_net_bad.png"
			check(app.chrome_connection.texture == app.skin_art(expected), "Connection state icon is stale")
			check(not app.connection_indicator.visible, "ON/OFF label is still visible with icon")
			check(app.chrome_connection.visible, "Connection icon is hidden")
			await snapshot("connected" if state else "disconnected", dimensions)
		# Explicitly test the child/parent visibility transition used by matches.
		app.nav_bar.hide()
		await settle()
		check(not app.chrome_navigation.visible, "Hidden navigation still takes layout space")
		app.nav_bar.show()
		app.sync_navigation_visibility()
		await settle()
		check(app.chrome_navigation.is_visible_in_tree(), "Navigation remains hidden after show")
	app.open_tab("play")
	await app.mutate("solo", {"chapterId": 1})
	await settle()
	check(not app.room.is_empty(), "Skin test match did not start")
	check(not app.chrome_navigation.visible, "Navigation artwork remains visible during a match")
	await app.leave_match()
	await settle()
	check(app.chrome_navigation.is_visible_in_tree(), "Navigation did not return after leaving match")
	var directory = OS.get_environment("DESTAN_SNAPSHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var report = FileAccess.open(directory.path_join("skin-chrome-checks.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"failures": failures, "measurements": measurements, "physical_device_test": false}, "  ") + "\n")
			report.close()
	app.poll.stop()
	app.queue_free()
	await settle()
	print("Skin chrome regression failures: ", failures)
	quit(1 if failures else 0)

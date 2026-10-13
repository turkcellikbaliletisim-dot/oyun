extends SceneTree
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var geometry = load("res://native/mobile_geometry.gd")
	var safe = geometry.safe_margins(Vector2(844, 390), Vector2(2532, 1170), Rect2(132, 0, 2310, 1110))
	check(safe.x >= 44 and safe.x <= 45 and safe.y == 12 and safe.z >= 30 and safe.z <= 31 and safe.w >= 20 and safe.w <= 21, "Physical notch/gesture area was not scaled into canvas coordinates")
	check(geometry.safe_margins(Vector2(844, 390), Vector2.ZERO, Rect2()) == Vector4(12, 12, 12, 12), "Invalid screen dimensions did not use safe fallback")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(844, 390)
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	app.poll.stop()
	await app.connect_account()
	check(app.network_panel.visible and not app.network_panel.get_parent().visible, "Connected settings contents must remain visible inside the hidden panel")
	app.network_panel.get_parent().show()
	check(app.address.is_visible_in_tree(), "Server address disappeared when opening settings")
	app.network_panel.get_parent().hide()
	var loading = app.show_loading_screen(true)
	app.loading_progress(loading, 0.25, "Hazırlanıyor")
	var fill = loading.get_meta("loading_fill")
	check(is_equal_approx(fill.size.x, float(loading.get_meta("loading_width")) * 0.25), "Progress fill does not reflect completed work")
	await app.prepare_startup(loading)
	check(is_equal_approx(fill.size.x, float(loading.get_meta("loading_width"))), "Startup did not complete its resource stages")
	await create_timer(0.3).timeout
	check(not is_instance_valid(loading), "Startup overlay was not released after completion")
	var button = app.button("Deneme düğmesi", app.content, func(): pass)
	app.dress_button(button, "button_gold.png", Color.WHITE, Color.WHITE)
	button.mouse_entered.emit()
	button.mouse_exited.emit()
	button.button_down.emit()
	button.button_up.emit()
	check(button.get_signal_connection_list("mouse_entered").size() == 1, "Re-skinning duplicated callbacks")
	app.connected = false
	var previous_match = app.room.duplicate(true)
	await app.mutate("solo", {"chapterId": 1})
	check(app.room == previous_match, "Disconnected UI created a match")
	await app.attempt_reconnect()
	check(app.connected, "Reconnect did not restore account")
	await app.mutate("solo", {"chapterId": 1})
	var match_id = app.room.id
	app.shell_margin.add_theme_constant_override("margin_left", 44)
	app.shell_margin.add_theme_constant_override("margin_right", 30)
	app.shell_margin.add_theme_constant_override("margin_bottom", 20)
	app.render()
	for frame in range(5):
		await process_frame
	check(app.arena.size.x <= 770, "Battlefield ignored safe horizontal margins")
	app.drag_active = true
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not app.drag_active and app.poll.is_stopped() and app.reconnect_timer.is_stopped(), "Pause did not stop drag/network timers")
	check(Engine.max_fps == 10, "Background FPS was not reduced")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await create_timer(0.1).timeout
	check(app.room.id == match_id and Engine.max_fps == 60, "Resume lost the match or foreground frame rate")
	print("Mobile lifecycle failures: ", failures)
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)

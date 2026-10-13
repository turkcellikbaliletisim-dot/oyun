extends SceneTree
# UGACHA ekran görüntüleri: DESTAN_SHOT_DIR klasörüne yazar (görsel kontrol için).
var dir = OS.get_environment("DESTAN_SHOT_DIR")
func shot(name: String, wait: float = 0.5) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var size = Vector2i(390, 844)
	DisplayServer.window_set_size(size * 2)
	root.size = size * 2
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = size
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	app.poll.stop()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await app.connect_account()
	app.view = "lobby"
	app.render()
	await shot("h1-merkez", 1.0)
	app.scroll.scroll_vertical = 600
	await shot("h2-merkez-alt")
	for v in ["uga_heroes", "uga_totems", "uga_chests", "uga_missions", "uga_rebirth"]:
		app.view = v
		app.render()
		await shot(v)
	var ui = app.uga_ui()
	ui.start_run(0)
	var b = ui.battle
	b.speed = 3
	b.auto_on = true
	await shot("b1-savas", 6.0)
	await shot("b2-savas", 8.0)
	b.sim.wave = 9
	await shot("b3-savas", 12.0)
	b.sim.castle_hp = 0
	await shot("b4-son", 3.0)
	await shot("r1-sonuc", 1.0)
	app.queue_free()
	await process_frame
	quit(0)

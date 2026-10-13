extends SceneTree
# Yüksek çözünürlüklü ekran görüntüleri: DESTAN_SHOT_DIR, DESTAN_SCALE (varsayılan 3), DESTAN_SIZE=portrait|land
func shot(name: String) -> void:
	for i in 6:
		await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("DESTAN_SHOT_DIR"), name])
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var size = Vector2i(390, 844) if OS.get_environment("DESTAN_SIZE") != "land" else Vector2i(844, 390)
	var factor = int(OS.get_environment("DESTAN_SCALE")) if OS.get_environment("DESTAN_SCALE") != "" else 3
	DisplayServer.window_set_size(size * factor)
	root.size = size * factor
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = size
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	app.poll.stop()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await app.connect_account()
	app.render()
	await shot("1-lobby")
	app.open_tab("story")
	await shot("2-yolculuk")
	app.show_collection()
	await shot("3-kartlar")
	app.view = "deck"
	app.gallery_open = false
	app.render()
	await shot("4-deste")
	app.view = "lobby"
	app.gallery_open = false
	app.render_social()
	await shot("5-arkadas")
	app.network_panel.get_parent().visible = true
	app.view = "lobby"
	app.render()
	await shot("6-ayarlar")
	app.network_panel.get_parent().visible = false
	app.render_profile()
	await shot("7-hesap")
	app.view = "lobby"
	app.render_social()
	await shot("5b-arkadas-giris")
	app.show_collection()
	app.network_panel.get_parent().visible = false
	app.show_pack_reveal()
	await create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/8-sandik.png" % OS.get_environment("DESTAN_SHOT_DIR"))
	quit(0)

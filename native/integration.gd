extends SceneTree

var failures = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func run() -> void:
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	app.poll.stop()
	await app.connect_account()
	if not check(not app.account.is_empty(), "Native account bootstrap failed"):
		quit(1)
		return
	var id = app.account.id
	var recovery = app.recovery_key
	check(recovery.length() == 64, "One-time recovery key missing")
	check(app.cards.size() == 40, "Card source must include forty cards")
	for card_id in range(1, 41):
		var texture = app.texture_for(card_id)
		check(texture.atlas != null and texture.region.size == Vector2(768, 512), "Invalid illustrated atlas cell")
	app.show_collection()
	check(app.content.get_child_count() >= 4, "Native collection did not render")
	if OS.get_environment("DESTAN_NATIVE_VISUAL") == "1":
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/destan-godot-collection.png")
	app.gallery_open = false
	await app.mutate("solo", {"chapterId": 1})
	if not check(not app.room.is_empty(), "Native story did not start"):
		quit(1)
		return
	check(app.room.state.players[0].hand.has(1.0), "Pinned chapter card missing")
	await app.move({"type": "mulligan", "indices": []})
	var steps = 0
	while app.room.status != "finished" and steps < 160:
		var options: Array = app.room.actions
		if not check(not options.is_empty(), "Solo native client has no legal action"):
			break
		var plays = options.filter(func(action): return action.type == "play")
		var attacks = options.filter(func(action): return action.type == "attack")
		var action: Dictionary = options[options.size() - 1]
		if not plays.is_empty():
			action = plays[0]
		elif not attacks.is_empty():
			action = attacks[0]
		var version = app.room.version
		await app.move(action)
		if not check(app.room.version > version, "Native action was not applied exactly once"):
			break
		steps += 1
		if steps == 6 and OS.get_environment("DESTAN_NATIVE_VISUAL") == "1":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/destan-godot-match.png")
	check(app.room.status == "finished", "Native story did not complete")
	check(app.room.state.winner == 0, "Native tutorial should be winnable")
	await app.refresh()
	check(app.account.profile.chapterRewards.has(1.0), "Native story reward missing")
	check(app.account.profile.freePacks == 1, "Native tutorial pack reward wrong")
	var replay = await app.api("matches/" + app.room.id + "/replay")
	check(replay.has("initial") and replay.initial.has("entropy"), "Completed native match replay missing")
	await app.mutate("collection/pack", {}, true)
	check(app.account.profile.freePacks == 0, "Native pack did not consume exactly once")
	app.show_pack_reveal()
	check(app.get_child_count() > 0, "Pack reveal overlay missing")
	app.room = {}
	await app.connect_account()
	check(app.account.id == id and app.room.status == "finished", "Native cookie reconnect lost match")
	app.cookie = ""
	var restored = await app.api("recover", HTTPClient.METHOD_POST, {"key": recovery})
	check(restored.get("id") == id, "Native account recovery failed")
	check(restored.get("profile", {}).get("freePacks") == 0, "Recovery duplicated pack reward")
	app.muted = false
	app.play_sound()
	check(app.audio.stream != null, "Native sound stream missing")
	for skin_file in ["logo.png", "divider.png", "scrollbar.png", "end_turn_ready.png", "button_red.png", "icon_net_ok.png", "icon_net_bad.png", "toast_banner.png", "tooltip_panel.png", "target_ring.png", "drag_arrow.png", "chest_closed.png", "chest_open.png", "pack_reveal_burst.png", "scene_play.png", "scene_chest.png"]:
		check(app.skin(skin_file) != null, "Skin file not loadable: " + skin_file)
	await create_timer(0.2).timeout
	app.queue_free()
	await process_frame
	await process_frame
	print("Godot: 40 atlases, native UI, full tutorial, legal moves, reward/pack, replay, reconnect and recovery verified.")
	quit(1 if failures else 0)

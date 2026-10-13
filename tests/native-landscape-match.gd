extends SceneTree
## Geometry fixtures below are NOT simulated gameplay or device acceptance.
## Existing native-touch and integration tests still exercise server-authorized moves.
var failures = 0
var cases: Array = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for frame in range(7):
		await process_frame
func snapshot(app, caption: String, dimensions: Vector2i) -> void:
	cases.append({"scenario": caption, "viewport": [dimensions.x, dimensions.y], "fixture_only": caption != "mulligan"})
	if OS.get_environment("DESTAN_NATIVE_VISUAL") == "1":
		await RenderingServer.frame_post_draw
		var directory = OS.get_environment("DESTAN_SNAPSHOT_DIR")
		if directory.is_empty():
			directory = "/tmp"
		root.get_texture().get_image().save_png(directory + "/match-" + caption + "-%dx%d.png" % [dimensions.x, dimensions.y])
func assert_regions(app, dimensions: Vector2i) -> void:
	var areas: Dictionary = app.match_regions
	check(not areas.is_empty(), "Missing landscape layout: " + str(dimensions))
	if areas.is_empty():
		return
	var bounds: Rect2 = areas.bounds
	for key in ["foe", "own", "hand", "rail", "left"]:
		check(bounds.grow(1).encloses(areas[key]), "Region outside arena: " + key)
	var keys = ["foe", "own", "hand", "rail", "left"]
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			check(not areas[keys[i]].intersects(areas[keys[j]]), "Overlapping regions: " + keys[i] + "/" + keys[j])
	check(app.arena.get_global_rect().end.y <= dimensions.y + 1, "Match extends below viewport")
	for p in 2:
		var lane: Rect2 = areas.own if p == 0 else areas.foe
		for unit in app.room.state.players[p].board:
			var node: Control = app.unit_nodes[int(unit.uid)]
			var local = Rect2(node.global_position - app.arena.global_position, node.size)
			check(lane.encloses(local), "Unit cut off or crossing lane: " + str(unit.uid))
			check(node.size.x >= 44, "Unit tap area narrower than 44 px")
			check(absf(node.size.y / node.size.x - 1.34) < 0.08, "Distorted card ratio")
	var rail: Control = app.arena.get_node("LandscapeCommandRail")
	for node in rail.find_children("*", "Button", true, false):
		if node.is_visible_in_tree():
			check(node.size.y >= 44, "Command tap area shorter than 44 px")
			check(node.get_global_rect().position.x >= rail.global_position.x - 1 and node.get_global_rect().end.x <= rail.get_global_rect().end.x + 1, "Command extends into battlefield")
	check(not app.chrome_navigation.is_visible_in_tree(), "Navigation consumes landscape battlefield")
func populate_fixture(app, original: Dictionary, template: Dictionary) -> void:
	app.room = original.duplicate(true)
	app.room.status = "playing"
	app.room.state.status = "playing"
	app.room.state.active = 0
	app.room.state.turn = 12
	app.room.deadline = null
	app.room.actions = [{"type": "end"}]
	for p in 2:
		app.room.state.players[p].board = []
		app.room.state.players[p].energy = 8
		app.room.state.players[p].maxEnergy = 8
		for index in 5:
			var unit = template.duplicate(true)
			var id = [1, 5, 15, 18, 25][index]
			unit.id = id
			unit.uid = 100 + p * 10 + index
			unit.attack = int(app.cards[id].attack)
			unit.hp = int(app.cards[id].hp)
			unit.maxHp = unit.hp
			unit.tempAttack = 0
			unit.exhausted = false
			app.room.state.players[p].board.append(unit)
			if p == 0:
				app.room.actions.append({"type": "attack", "uid": unit.uid, "target": "hero:1"})
				app.room.actions.append({"type": "attack", "uid": unit.uid, "target": "unit:110"})
	app.room.state.players[0].hand = [1, 2, 3, 28, 29, 30, 25]
	for index in 7:
		app.room.actions.append({"type": "play", "index": index})
	app.selected = []
	app.focus = {}
	app.prev_state = {}
func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	await app.connect_account()
	app.poll.stop()
	check(not app.account.is_empty(), "Landscape test account failed")
	await app.mutate("solo", {"chapterId": 1})
	var opening = app.room.duplicate(true)
	await app.move({"type": "mulligan", "indices": []})
	var plays: Array = app.room.actions.filter(func(action): return action.type == "play" and not action.has("target"))
	check(not plays.is_empty(), "Fixture template unavailable")
	if plays.is_empty():
		quit(1)
		return
	await app.move(plays[0])
	var template: Dictionary = app.room.state.players[0].board[0].duplicate(true)
	var real_room = app.room.duplicate(true)
	for dimensions in [Vector2i(667, 375), Vector2i(740, 360), Vector2i(844, 390), Vector2i(1280, 720)]:
		if OS.get_environment("DESTAN_NATIVE_VISUAL") == "1":
			DisplayServer.window_set_size(dimensions)
		root.size = dimensions
		app.gallery_open = false
		app.view = "lobby"
		app.room = opening.duplicate(true)
		app.prev_state = {}
		app.render()
		await settle()
		assert_regions(app, dimensions)
		await snapshot(app, "mulligan", dimensions)
		populate_fixture(app, real_room, template)
		app.render()
		await settle()
		assert_regions(app, dimensions)
		await snapshot(app, "full-board", dimensions)
		check(app.unit_nodes.size() == 10, "Full board fixture must render 5 + 5 warriors")
		app.focus = {"id": 1, "unit": app.room.state.players[0].board[0]}
		app.selected = app.room.actions.filter(func(action): return action.type == "attack" and int(action.uid) == 100)
		app.prev_state = {}
		app.render()
		await settle()
		assert_regions(app, dimensions)
		await snapshot(app, "targeting", dimensions)
		app.focus = {}
		app.selected = []
		app.room.actions = []
		app.room.state.active = 1
		app.prev_state = {}
		app.render()
		await settle()
		assert_regions(app, dimensions)
		await snapshot(app, "opponent-turn", dimensions)
		app.room.status = "finished"
		app.room.state.status = "finished"
		app.room.state.winner = 0
		app.prev_state = {}
		app.render()
		await settle()
		var result: Control = app.arena.get_node("LandscapeResult")
		check(app.arena.get_global_rect().encloses(result.get_global_rect()), "Result and continue button clipped in landscape")
		await snapshot(app, "result", dimensions)
	app.room = real_room
	app.prev_state = {}
	app.poll.stop()
	if app.music_player != null:
		app.music_player.stop()
	app.audio.stop()
	var directory = OS.get_environment("DESTAN_SNAPSHOT_DIR")
	if not directory.is_empty():
		var report = FileAccess.open(directory + "/landscape-match-checks.json", FileAccess.WRITE)
		report.store_string(JSON.stringify({"failures": failures, "cases": cases, "physical_device_test": false, "fixture_limits": {"board_per_side": 5, "hand": 7}}, "  "))
	app.queue_free()
	await process_frame
	await process_frame
	print("Landscape match failures: ", failures)
	quit(1 if failures else 0)

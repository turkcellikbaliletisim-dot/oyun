extends SceneTree
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func hand_card(node: Node, index: int) -> Control:
	if node.has_meta("hand_index") and node.get_meta("hand_index") == index:
		return node
	for child in node.get_children():
		var found = hand_card(child, index)
		if found != null:
			return found
	return null
func drag(app, card: Control, target: Vector2) -> void:
	# A rendered card can disappear while network/tween frames are awaited.
	# Keep its semantic identity, then resolve the live node after settling.
	var hand_index = int(card.get_meta("hand_index", -1))
	var uid = -1
	for key in app.unit_nodes:
		if app.unit_nodes[key] == card:
			uid = int(key)
	if OS.get_environment("DESTAN_INTERACTION_STRESS") == "1":
		app.render.call_deferred()
	for frame in range(5):
		await process_frame
	card = app.unit_nodes.get(uid) if uid >= 0 else hand_card(app, hand_index)
	if not is_instance_valid(card):
		check(false, "Current draggable card was not rendered")
		return
	var origin = card.get_global_rect().get_center()
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = origin
	Input.parse_input_event(press)
	await process_frame
	check(not app.drag_options.is_empty(), "Press did not select a draggable card")
	var motion = InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = target
	Input.parse_input_event(motion)
	await process_frame
	check(app.drag_active, "Card drag did not activate")
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = target
	Input.parse_input_event(release)
	for attempt in range(30):
		await create_timer(0.02).timeout
		if not app.busy:
			break
func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(844, 390)
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	app.poll.stop()
	await app.connect_account()
	await app.mutate("solo", {"chapterId": 1})
	await app.move({"type": "mulligan", "indices": []})
	for frame in range(5):
		await process_frame
	var plays = app.room.actions.filter(func(action): return action.type == "play" and not action.has("target"))
	check(not plays.is_empty(), "No initial untargeted card")
	if not plays.is_empty():
		var version = app.room.version
		var card = hand_card(app, int(plays[0].index))
		check(card != null, "Hand card is missing")
		if card != null:
			await drag(app, card, Vector2(5, 5))
			check(app.room.version == version, "Dropping outside the board played a card")
			card = hand_card(app, int(plays[0].index))
			await drag(app, card, app.arena.get_global_rect().position + Vector2(350, 145))
			check(app.room.version > version, "Drag did not apply a legal card play")
			check(not app.drag_active and app.drag_options.is_empty(), "Drag state was not cleared")
	await app.move({"type": "end"})
	for frame in range(5):
		await process_frame
	var attacks = app.room.actions.filter(func(action): return action.type == "attack" and action.get("target") == "hero:1")
	check(not attacks.is_empty(), "Tutorial warrior cannot attack enemy hero")
	if not attacks.is_empty():
		var version = app.room.version
		var hp = int(app.room.state.players[1].hp)
		await drag(app, app.unit_nodes[int(attacks[0].uid)], app.hero_nodes[1].get_global_rect().get_center())
		check(app.room.version > version and int(app.room.state.players[1].hp) < hp, "Drag attack did not damage the enemy hero")
	print("Mobile input failures: ", failures)
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)

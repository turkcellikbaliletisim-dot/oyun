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
func touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	await process_frame
func drag(app, card: Control, destination: Vector2, cancel: bool = false) -> void:
	for frame in range(5):
		await process_frame
	var origin = card.get_global_rect().get_center()
	await touch(0, origin, true)
	await touch(1, origin + Vector2(20, 0), true)
	var event = InputEventScreenDrag.new()
	event.index = 0
	event.position = destination
	event.relative = destination - origin
	Input.parse_input_event(event)
	await process_frame
	check(app.drag_active, "Native screen drag did not activate without mouse emulation")
	await touch(1, origin + Vector2(20, 0), false)
	check(app.drag_active, "Second finger canceled the primary drag")
	await touch(0, destination, false, cancel)
	for attempt in range(30):
		await create_timer(0.02).timeout
		if not app.busy:
			break
func run() -> void:
	Input.emulate_mouse_from_touch = false
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
	check(not plays.is_empty(), "No touch-test card")
	if not plays.is_empty():
		var version = app.room.version
		var card = hand_card(app, int(plays[0].index))
		var destination = app.arena.get_global_rect().position + Vector2(350, 140)
		await drag(app, card, destination, true)
		check(app.room.version == version and not app.drag_active, "Canceled touch applied a move or left a drag")
		card = hand_card(app, int(plays[0].index))
		await drag(app, card, destination)
		check(app.room.version > version and not app.drag_active, "Native touch did not play the card exactly once")
	await app.move({"type": "end"})
	for frame in range(5):
		await process_frame
	var attacks = app.room.actions.filter(func(action): return action.type == "attack" and action.get("target") == "hero:1")
	check(not attacks.is_empty(), "No touch-test attack")
	if not attacks.is_empty():
		var hp = int(app.room.state.players[1].hp)
		await drag(app, app.unit_nodes[int(attacks[0].uid)], app.hero_nodes[1].get_global_rect().get_center())
		check(int(app.room.state.players[1].hp) < hp, "Native touch attack did not damage the hero")
	print("Native touch failures: ", failures)
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)

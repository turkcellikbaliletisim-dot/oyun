extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	for attempt in range(80):
		if not app.account.is_empty():
			break
		await create_timer(0.2).timeout
	if app.account.is_empty() or app.endpoint != "http://127.0.0.1:8080":
		push_error("Mac startup connection failed: " + app.endpoint + " · " + app.notice.text)
		quit(1)
		return
	print("Mac startup connected to Docker: ", app.endpoint)
	app.queue_free()
	await process_frame
	quit(0)

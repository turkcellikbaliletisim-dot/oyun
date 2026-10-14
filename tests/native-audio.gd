extends SceneTree
var failures = 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var spec = JSON.parse_string(FileAccess.get_file_as_string("res://native/skin/audio/spec.json"))
	for target in spec.assets:
		var stream = load("res://native/skin/audio/" + str(target.file))
		if not stream is AudioStreamOggVorbis:
			push_error("Godot cannot load OGG/Vorbis: " + str(target.file))
			failures += 1
		elif absf(stream.get_length() - float(target.seconds)) > 0.025:
			push_error("Godot duration differs from requested duration: " + str(target.file))
			failures += 1
		stream = null
	await process_frame
	print("Godot audio import/duration failures: ", failures)
	quit(1 if failures else 0)

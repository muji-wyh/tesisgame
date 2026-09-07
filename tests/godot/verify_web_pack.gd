extends SceneTree


func _initialize() -> void:
	var failures := 0
	var words: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	if not words is Array or words.size() < 5:
		printerr("The startup pack must contain a playable vocabulary.")
		quit(1)
		return
	for word in words:
		var stream: AudioStream = load("res://" + word.audio)
		if stream == null or stream.get_length() <= 0.0:
			printerr("Word pronunciation is missing from the startup pack: " + word.audio)
			failures += 1
	var excluded := OS.get_cmdline_user_args()
	if excluded.is_empty():
		printerr("Pass the optional audio resource paths to verify their exclusion.")
		failures += 1
	for resource_path in excluded:
		if ResourceLoader.exists(resource_path) or FileAccess.file_exists(resource_path):
			printerr("Optional audio is still bundled: " + resource_path)
			failures += 1
	print("Startup pack: %d word pronunciations, %d optional paths checked, %d failures." % [words.size(), excluded.size(), failures])
	quit(1 if failures else 0)

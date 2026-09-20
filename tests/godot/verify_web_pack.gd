extends SceneTree


func _initialize() -> void:
	var failures := 0
	var words: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	if not words is Array or words.size() < 5:
		printerr("The startup pack must contain a playable vocabulary.")
		quit(1)
		return
	for word in words:
		var picture: Texture2D = load("res://" + word.image)
		if picture == null or picture.get_width() <= 0 or picture.get_height() <= 0:
			printerr("Word picture is missing from the startup pack: " + word.image)
			failures += 1
		var stream: AudioStream = load("res://" + word.audio)
		if stream == null or stream.get_length() <= 0.0:
			printerr("Word pronunciation is missing from the startup pack: " + word.audio)
			failures += 1
	var excluded := OS.get_cmdline_user_args()
	for path in load("res://scripts/game_audio.gd").PIP_SOUND_PATHS:
		var greeting: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if greeting == null or greeting.get_length() < 0.1 or greeting.get_length() > 0.6:
			printerr("A Pip greeting is missing or invalid in the startup pack: " + path)
			failures += 1
	if excluded.has("--require-pop-slices"):
		excluded.remove_at(excluded.find("--require-pop-slices"))
		var paths: Array = load("res://scripts/game_audio.gd").POP_SLICE_PATHS
		for path in paths:
			var slice: AudioStream = load(path) if ResourceLoader.exists(path) else null
			if slice == null or slice.get_length() < 0.25 or slice.get_length() > 0.42:
				printerr("A random Voice Pop slice is missing or invalid in the startup pack: " + path)
				failures += 1
		print("Voice Pop: %d random slice sounds checked in the startup pack." % paths.size())
	if excluded.has("--require-pop-slice"):
		excluded.remove_at(excluded.find("--require-pop-slice"))
		var path := "res://assets/imported-audio/pop-slice.wav"
		var effect: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if effect == null or effect.get_length() < 0.06 or effect.get_length() > 0.15:
			printerr("The imported Voice Pop slice sound is missing or invalid in the startup pack.")
			failures += 1
		else:
			print("Voice Pop slice sound is bundled for immediate playback.")
	if excluded.is_empty():
		printerr("Pass the optional audio resource paths to verify their exclusion.")
		failures += 1
	for resource_path in excluded:
		if ResourceLoader.exists(resource_path) or FileAccess.file_exists(resource_path):
			printerr("Optional audio is still bundled: " + resource_path)
			failures += 1
	print("Startup pack: %d word pronunciations, %d optional paths checked, %d failures." % [words.size(), excluded.size(), failures])
	quit(1 if failures else 0)

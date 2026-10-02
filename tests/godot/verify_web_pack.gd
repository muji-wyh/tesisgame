extends SceneTree


func _initialize() -> void:
	_verify.call_deferred()


func _verify() -> void:
	var failures := 0
	var catalog = load("res://scripts/game_data.gd").new()
	if not catalog.load_all():
		printerr("The startup pack must contain every gameplay catalog: " + catalog.error)
		quit(1)
		return
	var chest_frames: int = 0
	for style in catalog.chests.styles.values():
		for frame in style.get("frames", []):
			var texture: Texture2D = load("res://" + str(frame))
			if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
				printerr("A downloaded chest frame is missing from the startup pack: " + str(frame))
				failures += 1
			chest_frames += 1
	print("Treasure: %d chest types and %d downloaded opening frames checked in the startup pack." % [catalog.chests.styles.size(), chest_frames])
	var giant_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/talk_quest/monsters/giants-manifest.json"))
	if not giant_manifest is Dictionary or giant_manifest.get("creatures", []).size() != 3:
		printerr("Talk Quest requires the three acquired giant creature records in its startup pack.")
		failures += 1
	else:
		for creature: Dictionary in giant_manifest.creatures:
			var packed: PackedScene = load(str(creature.resource)) as PackedScene
			if packed == null:
				printerr("A Talk Quest giant model is missing from the startup pack: " + str(creature.id))
				failures += 1
		print("Talk Quest: three giant creatures and their framing manifest checked in the startup pack.")
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
	var required := OS.get_cmdline_user_args()
	var themes := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]
	var effects := ["select", "correct", "wrong", "loss"]
	for theme in themes:
		effects.append(theme + "-arrive")
	for effect in effects:
		var path: String = "res://assets/audio/sfx/" + effect + ".wav"
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if stream == null or stream.get_length() <= 0.0:
			printerr("A game effect is missing or invalid in the startup pack: " + path)
			failures += 1
	for path in load("res://scripts/game_audio.gd").PIP_SOUND_PATHS:
		var greeting: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if greeting == null or greeting.get_length() < 0.1 or greeting.get_length() > 0.6:
			printerr("A Pip greeting is missing or invalid in the startup pack: " + path)
			failures += 1
	if required.has("--require-pop-slices"):
		required.remove_at(required.find("--require-pop-slices"))
		var paths: Array = load("res://scripts/game_audio.gd").POP_SLICE_PATHS
		for path in paths:
			var slice: AudioStream = load(path) if ResourceLoader.exists(path) else null
			if slice == null or slice.get_length() < 0.25 or slice.get_length() > 0.42:
				printerr("A random Voice Pop slice is missing or invalid in the startup pack: " + path)
				failures += 1
		print("Voice Pop: %d random slice sounds checked in the startup pack." % paths.size())
	if required.has("--require-pop-reference"):
		required.remove_at(required.find("--require-pop-reference"))
		var controller = load("res://scripts/game_audio.gd").new()
		root.add_child(controller)
		var paths: Array = controller.POP_REFERENCE_PATHS
		if paths.size() != 3 or controller._pop_slice_paths != paths:
			printerr("The complete Voice Pop reference bank must be selected in the startup pack.")
			failures += 1
		for path in paths:
			var slice: AudioStreamWAV = (load(path) as AudioStreamWAV) if ResourceLoader.exists(path) else null
			if slice == null or slice.mix_rate != 44100 or slice.stereo \
				or slice.format != AudioStreamWAV.FORMAT_16_BITS or slice.loop_mode != AudioStreamWAV.LOOP_DISABLED \
				or slice.get_length() < 0.20 or slice.get_length() > 0.50:
				printerr("A Voice Pop reference slice is missing or invalid in the startup pack: " + path)
				failures += 1
		controller.free()
		print("Voice Pop: %d reference slice variants checked and selected in the startup pack." % paths.size())
	if required.has("--require-pop-slice"):
		required.remove_at(required.find("--require-pop-slice"))
		var path := "res://assets/imported-audio/pop-slice.wav"
		var effect: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if effect == null or effect.get_length() < 0.06 or effect.get_length() > 0.15:
			printerr("The imported Voice Pop slice sound is missing or invalid in the startup pack.")
			failures += 1
		else:
			print("Voice Pop slice sound is bundled for immediate playback.")
	if required.is_empty() or required.size() % 2 != 0:
		printerr("Pass every required audio source and imported resource path to verify the bundled audio.")
		failures += 1
	for resource_path in required:
		var stream: AudioStream = load(resource_path) if ResourceLoader.exists(resource_path) else null
		if stream == null or stream.get_length() <= 0.0:
			printerr("Required audio is missing or invalid in the startup pack: " + resource_path)
			failures += 1
	for theme in ["ocean", "space", "jungle", "candy"]:
		for cue in ["arrive", "open"]:
			var path: String = "res://assets/audio/voice/" + theme + "-" + cue + ".wav"
			if ResourceLoader.exists(path) or FileAccess.file_exists(path):
				printerr("A retired voice prompt is still bundled: " + path)
				failures += 1
	for theme in themes:
		var path: String = "res://assets/audio/sfx/" + theme + "-open.wav"
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			printerr("A replaced opening jingle is still bundled: " + path)
			failures += 1
	var retired_reports := ["round-fallback", "high-five", "highlights-one", "highlights-two",
		"no-highlights", "practice-next", "practice", "ready", "repeat-next", "repeat"]
	for value in range(21):
		retired_reports.append("round-%d" % value)
		if value > 0:
			retired_reports.append("combo-%d" % value)
	for report in retired_reports:
		var path: String = "res://assets/audio/pop/" + report + ".wav"
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			printerr("A retired Voice Pop report is still bundled: " + path)
			failures += 1
	for path in ["res://scripts/celebration.gd", "res://assets/chests/particles/ring.png",
		"res://assets/chests/particles/sparkle3.png", "res://assets/chests/particles/lightray1.png",
		"res://assets/chests/particles/explosion_spike01.png", "res://assets/chests/particles/magic_orb2.png"]:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			printerr("A retired collectible effect is still bundled: " + path)
			failures += 1
	print("Startup pack: %d word pronunciations, %d game effects, %d required audio paths checked, %d failures." % [words.size(), effects.size(), required.size(), failures])
	quit(1 if failures else 0)

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
	var chest_models: int = 0
	var model_sources: Dictionary = {}
	for style in catalog.chests.styles.values():
		if style.has("frames"):
			printerr("A retired low-resolution chest frame sequence is still selected in the startup pack.")
			failures += 1
		if style.has("model"):
			var resource_path: String = "res://" + str(style.model)
			var packed: PackedScene = load(resource_path) as PackedScene
			if packed == null:
				printerr("A live chest model is missing from the startup pack: " + resource_path)
				failures += 1
			else:
				var instance: Node = packed.instantiate()
				if instance == null or instance.find_children("*", "MeshInstance3D", true, false).is_empty():
					printerr("A live chest model has no renderable geometry in the startup pack: " + resource_path)
					failures += 1
				if instance != null:
					instance.free()
			model_sources[resource_path] = true
			chest_models += 1
	if catalog.chests.styles.size() != 8 or chest_models != 5 or model_sources.size() != 5:
		printerr("The startup pack must preserve the three original chest styles and five distinct live models.")
		failures += 1
	print("Treasure: %d chest types and %d live animated models checked in the startup pack." % [catalog.chests.styles.size(), chest_models])
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
	var map_art: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/talk_quest/map/manifest.json"))
	if not map_art is Dictionary or map_art.get("backgrounds", []).size() != 3 or map_art.get("landmarks", []).size() != 14:
		printerr("Talk Quest requires three sourced maps and fourteen destination illustrations in its startup pack.")
		failures += 1
	else:
		var map_paths: Array = map_art.backgrounds.duplicate()
		map_paths.append_array(map_art.landmarks)
		map_paths.append_array(map_art.ui.values())
		for path: String in map_paths:
			var illustration: Texture2D = load(path) as Texture2D
			if illustration == null or illustration.get_width() <= 0 or illustration.get_height() <= 0:
				printerr("A sourced map illustration is missing from the startup pack: " + path)
				failures += 1
		print("Talk Quest: sourced chapter maps, landmarks, and navigation artwork checked in the startup pack.")
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
	var treasure_manifest_path := "res://assets/talk_quest/treasure/manifest.json"
	var treasure_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(treasure_manifest_path))
	if not treasure_manifest is Dictionary or not treasure_manifest.get("runtimeFiles") is Array or treasure_manifest.runtimeFiles.size() != 7:
		printerr("The sourced Talk Quest treasure-room inventory is missing from the startup pack.")
		failures += 1
	else:
		for entry: Dictionary in treasure_manifest.runtimeFiles:
			var art: Texture2D = load(str(entry.file)) as Texture2D
			if art == null or art.get_width() <= 0 or art.get_height() <= 0:
				printerr("Treasure-room art is missing from the startup pack: " + str(entry.file))
				failures += 1
	for path in ["res://scripts/celebration.gd", "res://assets/chests/particles/ring.png",
		"res://assets/chests/particles/sparkle3.png", "res://assets/chests/particles/lightray1.png",
		"res://assets/chests/particles/explosion_spike01.png", "res://assets/chests/particles/magic_orb2.png"]:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			printerr("A retired collectible effect is still bundled: " + path)
			failures += 1
	print("Startup pack: %d word pronunciations, %d game effects, %d required audio paths checked, %d failures." % [words.size(), effects.size(), required.size(), failures])
	quit(1 if failures else 0)

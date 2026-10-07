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
	failures += _verify_excluded_content_absent()
	for name in ["body", "heading"]:
		var font: Font = load("res://assets/fonts/" + name + ".tres") as Font
		if font == null or font.get_string_size("Pip and Words").x <= 0.0:
			printerr("An active interface font is missing from the startup pack: " + name)
			failures += 1
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
	failures += _verify_phrases(words)
	var required := OS.get_cmdline_user_args()
	var themes := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]
	var effects := ["select", "correct"]
	for theme in themes:
		effects.append(theme + "-arrive")
	for effect in effects:
		var path: String = "res://assets/audio/sfx/" + effect + ".wav"
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if stream == null or stream.get_length() <= 0.0:
			printerr("A game effect is missing or invalid in the startup pack: " + path)
			failures += 1
	for path: String in load("res://scripts/game_audio.gd").PAIR_FEEDBACK_PATHS.values():
		var stream: AudioStreamWAV = load(path) if ResourceLoader.exists(path) else null
		if stream == null or stream.mix_rate != 44100 or stream.format != AudioStreamWAV.FORMAT_16_BITS \
			or stream.loop_mode != AudioStreamWAV.LOOP_DISABLED or stream.get_length() < 0.7 or stream.get_length() > 1.0:
			printerr("A supplied pair feedback effect is missing or invalid in the startup pack: " + path)
			failures += 1
	var ui_click_path := "res://assets/imported-audio/ui-click/select.wav"
	var ui_click: AudioStreamWAV = load(ui_click_path) if ResourceLoader.exists(ui_click_path) else null
	if ui_click == null or ui_click.stereo or ui_click.mix_rate != 44100 or ui_click.format != AudioStreamWAV.FORMAT_16_BITS \
		or ui_click.loop_mode != AudioStreamWAV.LOOP_DISABLED or ui_click.get_length() < 0.03 or ui_click.get_length() > 0.15:
		printerr("The supplied menu click is missing or invalid in the startup pack: " + ui_click_path)
		failures += 1
	for path in ["res://assets/audio/voice/wrong.wav", "res://assets/audio/voice/loss.wav",
		"res://assets/audio/sfx/wrong.wav", "res://assets/audio/sfx/loss.wav", "res://assets/audio/sfx/match-voice-hit.wav"]:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			printerr("A retired Match sound is still bundled: " + path)
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


func _verify_phrases(words: Array) -> int:
	var failures := 0
	var phrase_data = load("res://scripts/phrase_data.gd")
	var game_data = load("res://scripts/game_data.gd")
	if phrase_data == null or not FileAccess.file_exists("res://phrases.json"):
		printerr("The startup pack must contain the Phrase Builder catalog and loader.")
		return 1
	var phrases: Array[Dictionary] = phrase_data.entries()
	for age_band in ["4-6", "7-9", "10-plus"]:
		if phrase_data.for_age(age_band).size() < 3:
			printerr("The startup pack needs at least three valid phrases for age level " + age_band + ".")
			failures += 1
	var vocabulary: Dictionary = {}
	for word: Dictionary in words:
		vocabulary[str(word.id)] = word
	for phrase: Dictionary in phrases:
		var phrase_words: PackedStringArray = []
		for word_id: String in phrase.words:
			if not vocabulary.has(word_id):
				printerr("A phrase references a word missing from the startup pack: " + phrase.id + " / " + word_id)
				failures += 1
				continue
			var word: Dictionary = vocabulary[word_id]
			phrase_words.append(str(word.text))
			if game_data.word_level(word) > game_data.word_level(phrase):
				printerr("A phrase exceeds its vocabulary age level: " + phrase.id + " / " + word_id)
				failures += 1
		if " ".join(phrase_words) != phrase.text or not vocabulary.has(phrase.picture_id):
			printerr("A phrase has inconsistent text or a missing picture reference: " + phrase.id)
			failures += 1
		var audio_path: String = "res://" + str(phrase.audio)
		var stream: AudioStream = load(audio_path) if ResourceLoader.exists(audio_path) else null
		if stream == null or stream.get_length() <= 0.0:
			printerr("A whole-phrase recording is missing or invalid in the startup pack: " + audio_path)
			failures += 1
	for cue in ["intro", "try-again", "complete"]:
		var audio_path: String = "res://assets/audio/voice/phrase-" + cue + ".wav"
		var stream: AudioStream = load(audio_path) if ResourceLoader.exists(audio_path) else null
		if stream == null or stream.get_length() <= 0.0:
			printerr("A Phrase Builder prompt is missing or invalid in the startup pack: " + audio_path)
			failures += 1
	print("Phrase Builder: %d phrases, vocabulary references, age levels, and three spoken cues checked in the startup pack." % phrases.size())
	return failures


func _verify_excluded_content_absent() -> int:
	var failures := 0
	var build_only_sources := ["res://assets/fonts/Nunito-600.ttf", "res://assets/fonts/Nunito-800.ttf",
		"res://assets/images/mascots/outfits/wardrobe.svg"]
	var build_only_imports := ["Nunito-600.ttf-", "Nunito-800.ttf-", "wardrobe.svg-"]
	var pending: Array[String] = ["res://"]
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		var access := DirAccess.open(directory)
		if access == null:
			printerr("Could not inspect the startup pack directory: " + directory)
			failures += 1
			continue
		access.include_hidden = true
		for file: String in access.get_files():
			var path := directory.path_join(file)
			if path.contains("talk_quest") or path.contains("assets/audio/quest/"):
				printerr("Retired Talk Quest content is still bundled: " + path)
				failures += 1
			var build_only: bool = build_only_sources.has(path.trim_suffix(".import"))
			if directory == "res://.godot/imported":
				for prefix: String in build_only_imports:
					build_only = build_only or file.begins_with(prefix)
			if build_only:
				printerr("A build-only source or imported copy is still bundled: " + path)
				failures += 1
		for child: String in access.get_directories():
			pending.append(directory.path_join(child))
	print("Excluded content: complete startup pack inventory checked, %d remaining resources." % failures)
	return failures

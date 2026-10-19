extends SceneTree


func _initialize() -> void:
	_verify.call_deferred()


func _verify() -> void:
	var failures := 0
	var required := OS.get_cmdline_user_args()
	var words: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	if not words is Array or words.size() < 5:
		printerr("The startup pack must contain a playable vocabulary index.")
		quit(1)
		return
	failures += _verify_excluded_content_absent()
	if not required.has("--vocabulary-manifest") or required.find("--vocabulary-manifest") + 1 >= required.size():
		printerr("Pass the vocabulary pack manifest to verify deferred resources.")
		quit(1)
		return
	var vocabulary_index: int = required.find("--vocabulary-manifest")
	if _verify_vocabulary_packs(required[vocabulary_index + 1], words):
		quit(1)
		return
	required.remove_at(vocabulary_index + 1)
	required.remove_at(vocabulary_index)
	# Native verification preserves GameData's strict local asset checks. The
	# deferred resources have been proved absent and mounted before this load.
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
	var confetti := load("res://assets/images/jelly-match/confetti.png") as Texture2D
	if confetti == null or confetti.get_size() != Vector2(512, 512):
		printerr("The reviewed Jelly chest-upgrade confetti atlas is missing from the startup pack.")
		failures += 1
	for filename: String in ["gold-coin.png", "gold-coins.png"]:
		var coin_path: String = "res://assets/coins/" + filename
		var coin: Texture2D = load(coin_path) if ResourceLoader.exists(coin_path) else null
		var expected_size: Vector2 = Vector2(128, 128) if filename == "gold-coin.png" else Vector2(256, 256)
		if coin == null or coin.get_size() != expected_size:
			printerr("The reviewed coin artwork is missing or incorrectly sized in the startup pack: " + coin_path)
			failures += 1
	for name in ["body", "heading"]:
		var font: Font = load("res://assets/fonts/" + name + ".tres") as Font
		if font == null or font.get_string_size("Grow with Pip").x <= 0.0:
			printerr("An active interface font is missing from the startup pack: " + name)
			failures += 1
	failures += _verify_word_library(catalog.words)
	for word in words:
		var stream: AudioStream = load("res://" + word.audio)
		if stream == null or stream.get_length() <= 0.0:
			printerr("Word pronunciation is missing from the mounted vocabulary packs: " + word.audio)
			failures += 1
	failures += _verify_phrases(words)
	failures += _verify_growth()
	failures += _verify_growth_morphology(words)
	failures += _verify_word_motion(catalog.words)
	if required.has("--audio-manifest"):
		var manifest_index: int = required.find("--audio-manifest")
		if manifest_index + 1 >= required.size():
			printerr("Required audio verification needs a manifest path.")
			quit(1)
			return
		var paths: Variant = JSON.parse_string(FileAccess.get_file_as_string(required[manifest_index + 1]))
		required.remove_at(manifest_index + 1)
		required.remove_at(manifest_index)
		if not paths is Array or paths.is_empty() or paths.any(func(value: Variant) -> bool: return not value is String):
			printerr("Required audio verification needs a nonempty list of resource paths.")
			quit(1)
			return
		for path: String in paths:
			required.append(path)
	var themes := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]
	var chest_bank = load("res://scripts/chest_sound_bank.gd")
	for cue: String in chest_bank.CUES:
		var cue_path: String = "res://assets/audio/chest-kenney/%s.wav" % cue
		var cue_stream: AudioStreamWAV = load(cue_path) if ResourceLoader.exists(cue_path) else null
		if cue_stream == null or cue_stream.stereo or cue_stream.mix_rate != 44100 \
			or cue_stream.format != AudioStreamWAV.FORMAT_16_BITS or cue_stream.loop_mode != AudioStreamWAV.LOOP_DISABLED \
			or absf(cue_stream.get_length() - float(chest_bank.KENNEY_DURATIONS[cue])) > 1.0 / 44100.0:
			printerr("A Kenney chest cue is missing or invalid in the startup pack: " + cue_path)
			failures += 1
		for theme: String in themes:
			if chest_bank.path_for(theme, cue) != cue_path:
				printerr("Every theme must use the reviewed Kenney chest bank: %s / %s" % [theme, cue])
				failures += 1
	# Jelly and celebration feedback still use these supplied recordings directly.
	for cue: String in chest_bank.REFERENCE_CUES:
		var cue_path: String = "res://assets/imported-audio/chest-reference/%s.wav" % cue
		var cue_stream: AudioStreamWAV = load(cue_path) if ResourceLoader.exists(cue_path) else null
		var cue_seconds: float = 1.5 if cue == "release" else (1.2 if cue == "reward" else 0.24)
		if cue_stream == null or cue_stream.stereo or cue_stream.mix_rate != 44100 \
			or cue_stream.format != AudioStreamWAV.FORMAT_16_BITS or cue_stream.loop_mode != AudioStreamWAV.LOOP_DISABLED \
			or absf(cue_stream.get_length() - cue_seconds) > 1.0 / 44100.0:
			printerr("A retained supplied feedback recording is missing or invalid in the startup pack: " + cue_path)
			failures += 1
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
	print("Web packs: %d word pronunciations, %d game effects, %d required audio paths checked, %d failures." % [words.size(), effects.size(), required.size(), failures])
	quit(1 if failures else 0)


func _verify_vocabulary_packs(path: String, words: Array) -> int:
	var supplied: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/vocabulary-packs.json"))
	if not supplied is Dictionary or supplied.get("schema") != 2 or not supplied.get("packs") is Dictionary \
		or not catalog is Dictionary or catalog.get("schema") != 1 or not catalog.get("ages") is Dictionary:
		printerr("Deferred vocabulary manifests must be complete.")
		return 1
	var failures := 0
	var deferred: Dictionary = {}
	var phrases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://phrases.json"))
	for age in range(3, 13):
		var id := str(age)
		if not supplied.packs.has(id) or not catalog.ages.has(id):
			printerr("Every curriculum age needs a vocabulary pack: " + id)
			return 1
		var cohort: Dictionary = catalog.ages[id]
		var expected_words: Dictionary = {}
		var expected_phrases: Array[String] = []
		var expected_sources: Dictionary = {}
		for word: Dictionary in words:
			if int(word.min_age) == age:
				expected_words[str(word.id)] = true
		for phrase: Dictionary in phrases:
			if int(phrase.min_age) == age:
				expected_phrases.append(str(phrase.id))
				expected_sources["res://" + str(phrase.audio)] = true
				for word_id: String in phrase.words:
					expected_words[word_id] = true
		var word_ids: Array = expected_words.keys()
		word_ids.sort()
		expected_phrases.sort()
		if cohort.get("word_ids") != word_ids or cohort.get("phrase_ids") != expected_phrases:
			printerr("An age pack must contain its exact cohort and complete phrase dependencies: " + id)
			failures += 1
		for word: Dictionary in words:
			if expected_words.has(str(word.id)):
				expected_sources["res://" + str(word.audio)] = true
				if not str(word.image).is_empty():
					expected_sources["res://assets/images/word-library/%s.webp" % word.id] = true
					expected_sources["res://assets/images/word-motion/%s.webp" % word.id] = true
		var actual_sources: Dictionary = {}
		var bundles: Array = supplied.packs[id].get("dependencies", []).duplicate()
		bundles.append(id)
		for bundle: String in bundles:
			if not supplied.packs.has(bundle) or not supplied.packs[bundle].ages.has(id):
				printerr("An age references an unrelated vocabulary bundle: %s / %s" % [id, bundle])
				return 1
			for source: String in supplied.packs[bundle].sources:
				actual_sources[source] = true
		var expected_paths: Array = expected_sources.keys()
		var actual_paths: Array = actual_sources.keys()
		expected_paths.sort()
		actual_paths.sort()
		if expected_paths != actual_paths:
			printerr("An age must load precisely its cohort and phrase media: " + id)
			failures += 1
	for bundle: String in supplied.packs:
		for source: String in supplied.packs[bundle].sources:
			if deferred.has(source):
				printerr("Vocabulary media must be packaged only once: " + source)
				failures += 1
			deferred[source] = true
		for entry: Dictionary in supplied.packs[bundle].entries:
			if deferred.has(str(entry.path)):
				printerr("Vocabulary import must be packaged only once: " + str(entry.path))
				failures += 1
			deferred[str(entry.path)] = true
	for source: String in deferred:
		if FileAccess.file_exists(source) or ResourceLoader.exists(source):
			printerr("Deferred vocabulary unexpectedly remains in the startup pack: " + source)
			failures += 1
	if failures:
		return failures
	for bundle: String in supplied.packs:
		var pack: Dictionary = supplied.packs[bundle]
		if not ProjectSettings.load_resource_pack(str(pack.file), false):
			printerr("Could not mount the deferred vocabulary pack " + bundle)
			failures += 1
			continue
		for source: String in pack.sources:
			if not ResourceLoader.exists(source):
				printerr("A vocabulary pack is missing its imported resource: " + source)
				failures += 1
	print("Deferred vocabulary: %d unique bundles for ten ages mounted after confirming %d paths are absent from startup." % [supplied.packs.size(), deferred.size()])
	return failures


func _verify_word_motion(words: Array) -> int:
	var failures := 0
	var art = load("res://scripts/word_art.gd")
	var motions: Dictionary = art.motion_catalog()
	var supplied: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/word-motion.json"))
	if not supplied is Dictionary or supplied.get("schema") != 1 or not supplied.get("files") is Array \
		or supplied.files.size() != 1285 or motions.size() != 1285:
		printerr("The startup pack needs the complete runtime vocabulary motion manifest.")
		return 1
	var authored := 0
	var total_frames := 0
	var pictured := 0
	for word: Dictionary in words:
		var id: String = str(word.id)
		if str(word.image).is_empty():
			if motions.has(id):
				printerr("A context-only word unexpectedly has an animation: " + id)
				failures += 1
			continue
		pictured += 1
		if not motions.has(id):
			printerr("A pictured word is missing its runtime animation: " + id)
			failures += 1
			continue
		var motion: Dictionary = motions[id]
		var expected_path: String = "assets/images/word-motion/%s.webp" % id
		if str(motion.path) != expected_path or int(motion.frameSide) != 128 or int(motion.columns) != 8:
			printerr("A word animation has invalid layout metadata: " + id)
			failures += 1
			continue
		var frames: int = int(motion.frames)
		var expected_size := Vector2(1024, ceili(float(frames) / 8.0) * 128)
		# Do not populate WordArt's shared texture cache while inspecting the full
		# catalogue. Release each sheet before loading the next one.
		var sheet: Texture2D = ResourceLoader.load("res://" + expected_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if sheet == null or sheet.get_size() != expected_size:
			printerr("A word animation atlas is missing or incomplete: " + id)
			failures += 1
		sheet = null
		total_frames += frames
		if art.CLIPS.has(id):
			authored += 1
			if frames != int(art.CLIPS[id][0]) or int(motion.posterFrame) != int(art.CLIPS[id][1]) or float(motion.fps) != 24.0:
				printerr("An authored teaching animation lost its reviewed timing: " + id)
				failures += 1
		elif frames != 32 or float(motion.fps) != 12.0:
			printerr("A library illustration animation has unexpected timing: " + id)
			failures += 1
	if pictured != 1285 or authored != 8 or total_frames != 41380:
		printerr("The startup pack must preserve every reviewed word motion and all eight authored teaching actions.")
		failures += 1
	print("Vocabulary motion: %d animated words, %d authored actions and %d frames checked in the startup pack." % [pictured, authored, total_frames])
	return failures


func _verify_word_library(words: Array) -> int:
	var failures := 0
	var pictured := 0
	var contextual := 0
	var paths: Dictionary = {}
	for word: Dictionary in words:
		var expected: String = "assets/images/word-library/%s.webp" % word.id
		if str(word.image).is_empty():
			contextual += 1
			if ResourceLoader.exists("res://" + expected):
				printerr("A context-only word unexpectedly has an arbitrary picture in the startup pack: " + str(word.id))
				failures += 1
			continue
		pictured += 1
		paths[str(word.image)] = true
		if str(word.image) != expected or str(word.art_key) != "library/" + str(word.id):
			printerr("The startup pack does not select the reviewed library picture: " + str(word.id))
			failures += 1
		var picture: Texture2D = load("res://" + expected) if ResourceLoader.exists("res://" + expected) else null
		if picture == null or picture.get_size() != Vector2(256, 256):
			printerr("A complete reviewed picture is missing from the startup pack: " + expected)
			failures += 1
	if pictured != 1285 or contextual != 265 or paths.size() != 1285:
		printerr("The startup pack must preserve 1285 distinct pictured words and 265 contextual words.")
		failures += 1
	if ResourceLoader.exists("res://assets/images/words/cat.svg") or FileAccess.file_exists("res://assets/images/words/cat.svg"):
		printerr("A historical vocabulary picture is still bundled instead of remaining an authoring source.")
		failures += 1
	print("Vocabulary library: %d reviewed pictures and %d contextual words checked in the startup pack." % [pictured, contextual])
	return failures


func _verify_phrases(words: Array) -> int:
	var failures := 0
	var phrase_data = load("res://scripts/phrase_data.gd")
	var game_data = load("res://scripts/game_data.gd")
	if phrase_data == null or not FileAccess.file_exists("res://phrases.json"):
		printerr("The startup pack must contain the Phrase Builder catalog and loader.")
		return 1
	var phrases: Array[Dictionary] = phrase_data.entries()
	for age in range(3, 13):
		var age_band: String = str(age)
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
			if game_data.word_age(word) > game_data.word_age(phrase):
				printerr("A phrase exceeds its vocabulary age level: " + phrase.id + " / " + word_id)
				failures += 1
		if " ".join(phrase_words) != phrase.text or (not phrase.picture_id.is_empty() and not vocabulary.has(phrase.picture_id)):
			printerr("A phrase has inconsistent text or a missing picture reference: " + phrase.id)
			failures += 1
		var audio_path: String = "res://" + str(phrase.audio)
		var stream: AudioStream = load(audio_path) if ResourceLoader.exists(audio_path) else null
		if stream == null or stream.get_length() <= 0.0:
			printerr("A whole-phrase recording is missing or invalid in the startup pack: " + audio_path)
			failures += 1
	print("Phrase Builder: %d phrases, vocabulary references, age levels, and whole-phrase recordings checked in the startup pack." % phrases.size())
	return failures


func _verify_excluded_content_absent() -> int:
	var failures := 0
	var build_only_sources := ["res://assets/fonts/Nunito-600.ttf", "res://assets/fonts/Nunito-800.ttf",
		"res://assets/images/mascots/outfits/wardrobe.svg", "res://assets/coins/prepare.py",
		"res://assets/coins/manifest.json", "res://assets/coins/review-contact.png"]
	var build_only_imports := ["Nunito-600.ttf-", "Nunito-800.ttf-", "wardrobe.svg-", "review-contact.png-"]
	var archived_chest_imports: Dictionary = {}
	var chest_bank = load("res://scripts/chest_sound_bank.gd")
	for theme: String in ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]:
		for cue: String in chest_bank.CUES:
			var source_path: String = "res://assets/audio/chests/%s-%s.wav" % [theme, cue]
			archived_chest_imports["res://.godot/imported/%s-%s.sample" % [source_path.get_file(), source_path.md5_text()]] = true
	for name: String in ["star", "ball", "rocket", "kite", "robot", "doll"]:
		var source_path: String = "res://assets/chests/surprises/%s.svg" % name
		archived_chest_imports["res://.godot/imported/%s-%s.ctex" % [source_path.get_file(), source_path.md5_text()]] = true
	var historical_word_imports: Dictionary = {}
	var original_words: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	if original_words is Array:
		for word: Dictionary in original_words:
			if str(word.get("image", "")).is_empty():
				continue
			var historical_sources: PackedStringArray = ["res://" + str(word.image)]
			if int(word.get("min_age", 0)) == 3:
				historical_sources.append("res://assets/images/words/lv3-%s.png" % word.id)
			for source_path: String in historical_sources:
				# Godot keys imports by the complete res:// source path. Theme and
				# interface assets may legitimately share a vocabulary basename.
				var imported_path: String = "res://.godot/imported/%s-%s.ctex" % [source_path.get_file(), source_path.md5_text()]
				historical_word_imports[imported_path] = true
	var retired_phrase_audio := ["phrase-intro.wav", "phrase-try-again.wav", "phrase-complete.wav"]
	# A curriculum phrase can reuse a former prompt filename (for example "try again").
	# Its new recording is checked against the active phrase catalog, not used as guidance.
	var active_phrases: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://phrases.json"))
	if active_phrases is Array:
		for phrase: Dictionary in active_phrases:
			retired_phrase_audio.erase(str(phrase.get("audio", "")).get_file())
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
			if path.begins_with("res://web/preview/") or path.begins_with("res://build/word-art-review/") \
				or path.begins_with("res://tools/vocabulary-art/") or path.begins_with("res://docs/assets/") \
				or path.get_extension() in ["blend", "blend1", "fbx"]:
				printerr("Local preview or authoring source is unexpectedly bundled: " + path)
				failures += 1
			if path.contains("talk_quest") or path.contains("assets/audio/quest/"):
				printerr("Retired Talk Quest content is still bundled: " + path)
				failures += 1
			if path.begins_with("res://assets/audio/chests/") or path.begins_with("res://assets/chests/surprises/") \
				or archived_chest_imports.has(path):
				printerr("Archived chest audio or surprise artwork is still bundled: " + path)
				failures += 1
			var build_only: bool = build_only_sources.has(path.trim_suffix(".import")) or path.begins_with("res://assets/images/words/")
			if directory == "res://.godot/imported":
				for prefix: String in build_only_imports:
					build_only = build_only or file.begins_with(prefix)
				build_only = build_only or historical_word_imports.has(path)
			if build_only:
				printerr("A build-only source or imported copy is still bundled: " + path)
				failures += 1
			for filename: String in retired_phrase_audio:
				var retired: bool = path.trim_suffix(".import") == "res://assets/audio/voice/" + filename
				if directory == "res://.godot/imported":
					retired = retired or file.begins_with(filename + "-")
				if retired:
					printerr("Retired Phrase Builder guide narration is still bundled: " + path)
					failures += 1
		for child: String in access.get_directories():
			pending.append(directory.path_join(child))
	print("Excluded content: complete startup pack inventory checked, %d remaining resources." % failures)
	return failures


func _verify_growth() -> int:
	var failures: int = 0
	var motions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/pip-age-motions.json"))
	if not motions is Dictionary or motions.get("clips", {}).size() != 22 or motions.get("stages", {}).size() != 11:
		printerr("All 22 age-specific Pip performances must ship in the startup pack.")
		return 1
	var stages: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/pip-growth-stages.json"))
	if not stages is Dictionary or not stages.get("stages") is Array or stages.stages.size() != 11:
		printerr("Baby Pip and all ten age appearances must ship in the game pack.")
		return 1
	var ages: Array = []
	for stage: Dictionary in stages.stages:
		var stage_age: Variant = stage.get("age", -1)
		if not (stage_age is int or stage_age is float) or float(stage_age) != floorf(float(stage_age)):
			printerr("Pip age must be a whole number.")
			failures += 1
		ages.append(int(stage_age))
		for source in stage.art.values():
			if not ResourceLoader.exists("res://" + str(source)):
				printerr("Missing Pip growth art: " + str(source))
				failures += 1
		if not ResourceLoader.exists("res://" + str(stage.newVoice.path)):
			printerr("Missing Pip growth voice: " + str(stage.newVoice.path))
			failures += 1
	if ages != [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]:
		printerr("Pip artwork must follow the complete independent age sequence.")
		failures += 1
	return failures


func _verify_growth_morphology(words: Array) -> int:
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/vocabulary/morphology/index.json"))
	if not metadata is Dictionary or not metadata.get("ages") is Dictionary or metadata.get("total") != words.size():
		printerr("The startup pack needs the complete Growth morphology index.")
		return 1
	var overlay: Script = load("res://scripts/growth_morphology.gd")
	var counts: Dictionary = {}
	var failures := 0
	var reviewed := 0
	for word: Dictionary in words:
		var age: String = str(int(word.min_age))
		if not counts.has(age):
			counts[age] = {"total": 0, "reviewed": 0, "pending": 0}
		counts[age].total += 1
		var decorated: Dictionary = overlay.decorate(word)
		var status: String = str(decorated.get("morphology_status", "invalid"))
		if status not in ["reviewed", "pending"]:
			printerr("Invalid or missing Growth word analysis in the startup pack: " + str(word.id))
			failures += 1
			continue
		counts[age][status] += 1
		if status == "reviewed":
			reviewed += 1
	for age: String in counts:
		var expected: Variant = metadata.ages.get(age, {})
		var matches: bool = expected is Dictionary and expected.size() == 3
		for field: String in ["total", "reviewed", "pending"]:
			var value: Variant = expected.get(field) if expected is Dictionary else null
			# JSON numbers are floats. Compare numeric values explicitly rather
			# than using type-sensitive Dictionary equality with native counts.
			matches = matches and (value is int or value is float) and value == counts[age][field]
		if not matches:
			printerr("Packed Growth review totals disagree for age %s: %s vs %s" % [age, counts[age], expected])
			failures += 1
	print("Growth morphology: %d reviewed and %d pending identities checked in startup metadata." % [reviewed, words.size() - reviewed])
	return failures

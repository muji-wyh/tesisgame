extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var path := "res://scripts/game_model.gd"
	check(FileAccess.file_exists(path), "The Godot game model exists")
	if not FileAccess.file_exists(path):
		quit(1)
		return
	var model_script: GDScript = load(path)
	check(model_script != null and model_script.can_instantiate(), "The model compiles")
	if model_script == null or not model_script.can_instantiate():
		quit(1)
		return
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	_test_rounds(model_script, words)
	_test_matching(model_script, words)
	_test_results(model_script, words)
	_test_data(words)
	_test_controls()
	_test_effects()
	await _test_audio()
	await _test_scene()
	print("Godot: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func pairs_for(model) -> Array:
	var pairs: Array = []
	for card in model.cards:
		if card.kind != "word":
			continue
		for other in model.cards:
			if other.kind == "image" and card.word.id == other.word.id:
				pairs.append([card.id, other.id])
	return pairs


func wrong_pair_for(model) -> Array:
	for card in model.cards:
		for other in model.cards:
			if card.kind != other.kind and card.word.id != other.word.id:
				return [card.id, other.id]
	return []


func _test_rounds(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	var seen_themes: Dictionary = {}
	for seed_value in range(80):
		check(model.reset(words, seed_value), "A valid vocabulary starts a round")
		check(model.cards.size() == 8, "There are eight cards")
		check(pairs_for(model).size() == 3, "There are exactly three complete pairs")
		var ids: Dictionary = {}
		var counts: Dictionary = {}
		var kinds: Dictionary = {"word": 0, "image": 0}
		for card in model.cards:
			ids[card.id] = true
			counts[card.word.id] = counts.get(card.word.id, 0) + 1
			kinds[card.kind] += 1
		check(ids.size() == 8, "Card IDs are unique")
		check(counts.size() == 5, "Pairs and distractors use five distinct words")
		check(counts.values().count(1) == 2, "Two cards have no matching partner")
		check(kinds.word == 4 and kinds.image == 4, "Distractors are one of each kind")
		check(model.phase == "waiting", "Rounds start waiting")
		check(model.successes == 0 and model.mistakes == 0, "Counters reset")
		seen_themes[model.theme_id] = true
	check(seen_themes.size() == 4, "New rounds can choose each season")
	model.reset(words, 17)
	var deck: Array = model.cards.duplicate(true)
	var season: String = model.theme_id
	model.reset(words, 17)
	check(model.cards == deck and model.theme_id == season, "Seeded rounds are reproducible")
	check(not model.reset(words.slice(0, 4), 1), "Fewer than five words cannot start a round")


func _test_matching(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	model.reset(words, 6)
	var first: Dictionary = model.cards[0]
	check(model.select(first.id) == "selected", "A first click selects a card")
	check(model.phase == "matching" and model.selected_id == first.id, "Selection enters matching")
	check(model.select(first.id) == "cancelled", "A second click on the selection cancels")
	check(model.phase == "waiting", "Cancellation returns to waiting")
	model.select(first.id)
	for card in model.cards:
		if card.kind == first.kind and card.id != first.id:
			check(model.select(card.id) == "reselected", "Same-kind selection is replaced")
			check(model.mistakes == 0, "Reselection does not count as a mistake")
			break
	var before: Array = model.cards.duplicate(true)
	var selected: String = model.selected_id
	check(model.set_theme("winter"), "Theme can change during selection")
	check(model.cards == before and model.selected_id == selected, "Theme change preserves selection/deck")
	check(not model.set_theme("unknown"), "Unknown themes are rejected")
	model.reset(words, 6)
	var wrong: Array = wrong_pair_for(model)
	model.select(wrong[0])
	check(model.select(wrong[1]) == "wrong", "Unrelated opposite kinds are incorrect")
	check(model.mistakes == 1 and model.successes == 0, "Wrong pair increments only mistakes")
	check(model.phase == "feedback", "Wrong feedback locks the round")
	check(model.select(wrong[0]) == "ignored", "Cards cannot be selected during feedback")
	model.resolve_feedback()
	check(model.phase == "waiting" and model.selected_id == "", "Feedback clears selection")
	var pair: Array = pairs_for(model)[0]
	model.select(pair[0])
	check(model.select(pair[1]) == "correct", "Matching opposite kinds are correct")
	check(model.successes == 1 and model.mistakes == 1, "Both counters accumulate independently")
	model.resolve_feedback()
	check(model.matched_ids.size() == 2, "Both matched cards are retained as matched")
	check(model.select(pair[0]) == "ignored", "Matched cards cannot score twice")


func _test_results(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	model.reset(words, 27)
	for pair in pairs_for(model):
		model.select(pair[0])
		model.select(pair[1])
		model.resolve_feedback()
	check(model.phase == "won" and model.successes == 3, "Three successes win")
	check(model.select(model.cards[0].id) == "ignored", "Winning locks the board")
	check(model.set_theme("spring"), "A closed chest follows theme selection")
	check(model.begin_open(), "The winning chest can open")
	check(model.chest_state == "opening" and model.reward_theme == "spring", "Opening captures its theme")
	check(not model.begin_open(), "Repeated opening is rejected")
	check(not model.set_theme("summer"), "Theme changes are locked during opening")
	check(model.finish_open(), "Opening completes once")
	check(not model.finish_open(), "Opening completion is one-shot")
	check(model.set_theme("winter"), "Theme can change after opening")
	check(model.reward_theme == "spring" and model.chest_state == "opened", "Earned reward is immutable")
	model.reset(words, 27)
	check(model.reward_theme == "" and model.chest_state == "closed", "Replay clears earned reward")
	check(not model.finish_open(), "A stale opening cannot reward the new round")
	var wrong: Array = wrong_pair_for(model)
	for count in range(3):
		model.select(wrong[0])
		model.select(wrong[1])
		model.resolve_feedback()
	check(model.phase == "lost" and model.mistakes == 3, "Three mistakes lose")
	check(not model.begin_open(), "Losing cannot grant a chest")
	model.reset(words, 12)
	var pair: Array = pairs_for(model)[0]
	model.select(pair[0])
	model.select(pair[1])
	model.resolve_feedback()
	wrong = wrong_pair_for(model)
	# Use unmatched cards so the independent loss threshold is exercised.
	for card in model.cards:
		for other in model.cards:
			if not card.id in model.matched_ids and not other.id in model.matched_ids:
				if card.kind != other.kind and card.word.id != other.word.id:
					wrong = [card.id, other.id]
	for count in range(3):
		model.select(wrong[0])
		model.select(wrong[1])
		model.resolve_feedback()
	check(model.phase == "lost" and model.successes == 1, "Success does not erase earlier/later mistakes")


func _test_data(words: Array) -> void:
	var path := "res://scripts/game_data.gd"
	check(FileAccess.file_exists(path), "The native data loader exists")
	if not FileAccess.file_exists(path):
		return
	var data_script: GDScript = load(path)
	check(data_script != null and data_script.can_instantiate(), "The data loader compiles")
	if data_script == null or not data_script.can_instantiate():
		return
	check(data_script.validate_words(words) == "", "The shared words.json is accepted")
	check(data_script.validate_words({}) != "", "Non-array vocabularies are rejected")
	check(data_script.validate_words(words.slice(0, 4)) != "", "Small vocabularies are rejected")
	var duplicate: Array = words.duplicate(true)
	duplicate[1].id = duplicate[0].id
	check(data_script.validate_words(duplicate) != "", "Duplicate word IDs are rejected")
	duplicate = words.duplicate(true)
	duplicate[1].text = duplicate[0].text
	check(data_script.validate_words(duplicate) != "", "Duplicate text is rejected")
	duplicate = words.duplicate(true)
	duplicate[1].image = duplicate[0].image
	check(data_script.validate_words(duplicate) != "", "Duplicate images are rejected")
	for bad_text in ["CAT", "a", "toolongword", "two words", "123"]:
		duplicate = words.duplicate(true)
		duplicate[0].text = bad_text
		check(data_script.validate_words(duplicate) != "", "Only short lowercase English words are accepted")
	for bad_path in ["https://example.invalid/cat.svg", "assets/images/words/../cat.svg", "C:\\cat.svg"]:
		duplicate = words.duplicate(true)
		duplicate[0].image = bad_path
		check(data_script.validate_words(duplicate) != "", "External/traversal image paths are rejected")
	for season in ["spring", "summer", "autumn", "winter"]:
		var theme: Dictionary = data_script.theme(season)
		check(theme.id == season and theme.prize != "", "Each season has a named reward")
	var expected_themes := {
		"spring": {
			"name": "Spring",
			"background": Color("#edf8ec"),
			"accent": Color("#438363"),
			"light": Color("#d7efc7"),
			"spark": Color("#75c66f"),
			"tint": Color("#dff6de")
		},
		"summer": {
			"name": "Summer",
			"background": Color("#ffe6e6"),
			"accent": Color("#b53640"),
			"light": Color("#ffc6cb"),
			"spark": Color("#ff8f9d"),
			"tint": Color("#ffe3e8")
		},
		"autumn": {
			"name": "Autumn",
			"background": Color("#fff8cf"),
			"accent": Color("#8f7400"),
			"light": Color("#ffe07a"),
			"spark": Color("#ffd24d"),
			"tint": Color("#fff0ad")
		},
		"winter": {
			"name": "Winter",
			"background": Color.WHITE,
			"accent": Color("#606a73"),
			"light": Color("#eef2f4"),
			"spark": Color("#d8dee3"),
			"tint": Color("#f5f7f8")
		}
	}
	for season in expected_themes.keys():
		var theme: Dictionary = data_script.theme(season)
		var expected: Dictionary = expected_themes[season]
		for key in expected.keys():
			check(theme.get(key) == expected[key], "%s %s matches the seasonal palette" % [season, key])
	var data = data_script.new()
	check(data.load_all(), "Runtime JSON and imported chest manifest load: " + data.error)
	check(data.words == words, "Godot uses the unchanged shared vocabulary")
	if not data.chests.is_empty():
		check(data.chests.styles.crystal.parts.size() == 9, "Crystal has all nine assembled pieces")


func _test_controls() -> void:
	var styles: GDScript = load("res://scripts/ui_style.gd")
	var menu := MenuButton.new()
	styles.button(menu, Color("#438363"), 120)
	check(menu.focus_mode == Control.FOCUS_ALL, "The season menu is keyboard reachable")
	check(menu.get_theme_color("font_disabled_color") == styles.INK, "Disabled theme text remains readable")
	menu.free()


func _test_effects() -> void:
	var effect_script: GDScript = load("res://scripts/celebration.gd")
	var data_script: GDScript = load("res://scripts/game_data.gd")
	var effect_view = effect_script.new()
	root.add_child(effect_view)
	var data = data_script.new()
	check(data.load_all(), "Celebration assets are valid")
	effect_view.configure(data.chests)
	check(effect_view._textures.is_empty(), "Celebration textures do not delay startup")
	effect_view.start(data_script.theme("spring"), true)
	check(effect_view._textures.is_empty(), "Reduced motion does not load unused particle textures")
	effect_view.start(data_script.theme("spring"), false)
	check(effect_view._textures.size() == data.chests.particles.size(), "The first celebration loads its textures")
	check(effect_view.particle_count() == 72, "Native celebration has 72 particles")
	for category in range(3):
		var quadrants: Dictionary = {}
		for particle in effect_view._particles:
			if particle.kind == category:
				quadrants[int(fposmod(particle.angle, TAU) / (PI * 0.5))] = true
		check(quadrants.size() == 4, "Every particle category spans the whole circle")
	effect_view._process(4.9)
	check(effect_view.particle_count() == 0, "Celebration clears itself after its lifetime")
	effect_view.start(data_script.theme("winter"), true)
	check(effect_view.particle_count() == 0, "Reduced motion creates no particles")
	check(effect_view.has_method("_particle_position"), "Seasons have distinct motion profiles")
	if effect_view.has_method("_particle_position"):
		var positions: Array[Vector2] = []
		var sample := {"kind": 0, "angle": 0.6, "distance": 0.8}
		for season in ["spring", "summer", "autumn", "winter"]:
			effect_view.start(data_script.theme(season), false)
			var position: Vector2 = effect_view._particle_position(sample, 1.0, Vector2.ZERO, 200.0)
			check(not positions.has(position), "Each season has a different particle trajectory")
			positions.append(position)
	effect_view.free()


func _test_audio() -> void:
	var audio_script: GDScript = load("res://scripts/game_audio.gd")
	check(audio_script != null and audio_script.can_instantiate(), "The native audio controller compiles")
	if audio_script == null or not audio_script.can_instantiate():
		return
	var controller = audio_script.new()
	root.add_child(controller)
	await process_frame
	var notices: Array[String] = []
	controller.status_changed.connect(func(message: String) -> void: notices.append(message))
	check(not controller.active and not controller.music.playing, "Audio waits for interaction")
	for season in ["spring", "summer", "autumn", "winter"]:
		var track: AudioStreamWAV = load("res://assets/audio/bgm/" + season + ".wav")
		check(track.mix_rate == 22050, "Mobile background music uses 22.05 kHz: " + season)
		check(not track.stereo, "Mobile background music uses mono: " + season)
	var original: AudioStreamWAV = load("res://assets/audio/bgm/spring.wav")
	var original_loop: int = original.loop_mode
	controller.interact("spring")
	check(controller.music.playing, "A gesture starts native background music")
	check(controller.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Background music loops")
	check(controller.music.stream != original and original.loop_mode == original_loop, "Loop setup does not mutate the shared WAV")
	controller.cue("select", "welcome")
	check(controller.effect.playing and controller.voice.playing, "Effects and voice use independent native channels")
	check(is_equal_approx(db_to_linear(controller.music.volume_db), 0.04), "Speech ducks background music")
	check(is_equal_approx(db_to_linear(controller.effect.volume_db), 0.24), "Effects have a bounded gain")
	check(is_equal_approx(db_to_linear(controller.voice.volume_db), 0.64), "Speech has a bounded gain")
	controller.say("res://assets/audio/voice/missing-test.wav")
	check(not controller.voice.playing, "An unavailable new voice does not leave the old word speaking")
	check(not notices[-1].is_empty(), "Unavailable speech has an explicit notice")
	controller.interact("missing-test")
	check(not controller.music.playing, "An unavailable new theme does not leave the old music playing")
	controller.interact("summer")
	check(controller.music.playing, "Audio can retry after a missing resource")
	controller.set_muted(true)
	check(not controller.active and not controller.music.playing and not controller.effect.playing and not controller.voice.playing,
		"Muting stops all channels")
	controller.interact("winter")
	check(not controller.active, "Interaction does not bypass mute")
	controller.set_muted(false)
	controller.interact("winter")
	check(controller.music.playing and controller.current_theme == "winter", "Unmuted audio can resume after a gesture")
	controller.halt()
	check(not controller.active and not controller.music.playing, "Hiding/resetting suspends audio")
	controller.queue_free()
	await process_frame


func _test_scene() -> void:
	var path := "res://scenes/main.tscn"
	check(FileAccess.file_exists(path), "The native main scene exists")
	if not FileAccess.file_exists(path):
		return
	var packed: PackedScene = load(path)
	check(packed != null, "The main scene loads")
	if packed == null:
		return
	var app = packed.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	check(app.data.error == "", "The scene loads its data: " + app.data.error)
	if app.data.error != "":
		app.queue_free()
		await process_frame
		return
	app.audio.set_muted(true)
	check(app.cards.size() == 8, "The scene creates eight native card buttons")
	check(app._stage.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW, "Chest effects respect the rounded panel mask")
	check(is_equal_approx(app.feedback_timer.wait_time, 0.7), "Feedback lasts 700ms")
	var dimensions: Array[Vector2i] = [
		Vector2i(320, 320), Vector2i(375, 667), Vector2i(390, 844),
		Vector2i(430, 932), Vector2i(844, 390), Vector2i(768, 1024),
		Vector2i(834, 1194), Vector2i(1194, 834), Vector2i(1024, 1366),
		Vector2i(507, 1024)
	]
	app.new_round(71)
	var round_cards: Array = app.model.cards.duplicate(true)
	for dimensions_value in dimensions:
		root.size = dimensions_value
		await process_frame
		await process_frame
		var viewport: Rect2 = root.get_visible_rect()
		var pixels_per_unit: Vector2 = Vector2(dimensions_value) / viewport.size
		check(app.model.cards == round_cards, "Resizing does not create a new round")
		check(app.grid.columns == (4 if dimensions_value.x >= dimensions_value.y else 2),
			"Grid chooses orientation: " + str(dimensions_value))
		var controls: Array = app.cards.values()
		controls.append_array([app.theme_menu, app.mute_button, app.listen_button])
		for control in controls:
			var bounds: Rect2 = control.get_global_rect()
			check(viewport.grow(0.5).encloses(bounds), "Control fits " + str(dimensions_value) + ": " + control.name)
			var pixel_size: Vector2 = bounds.size * pixels_per_unit
			check(pixel_size.x >= 47.9 and pixel_size.y >= 47.9,
				"Touch target is at least 48px: " + control.name + " " + str(pixel_size))
	for pair in pairs_for(app.model):
		app.cards[pair[0]].pressed.emit()
		app.cards[pair[1]].pressed.emit()
		check(app.feedback_timer.time_left > 0.0, "Button interaction starts feedback")
		app.feedback_timer.timeout.emit()
	check(app.model.phase == "won", "The native button/timer wiring can win a round")
	for season in ["spring", "summer", "autumn", "winter"]:
		app.choose_theme(season)
		await process_frame
		check(app.chest.theme_id == season, "Closed chest follows selected season")
		check(app.chest.piece_count() == (9 if season == "winter" else 2), "Chest uses real imported artwork")
	app.choose_theme("spring")
	app.set_reduced_motion(true)
	app.chest_button.pressed.emit()
	await process_frame
	check(app.model.chest_state == "opened", "Reduced motion reveals the reward immediately")
	check(app.effects.particle_count() == 0, "Reduced motion has no moving particles")
	app.choose_theme("winter")
	check(app.model.reward_theme == "spring" and app.chest.theme_id == "spring", "Earned chest remains spring")
	check(app.reward_image.visible, "Opening displays the reward medallion")
	app.new_round(81)
	check(app.audio.muted, "Replay preserves mute")
	check(app.model.chest_state == "closed" and app.effects.particle_count() == 0, "Replay clears reward/effects")
	check(app.feedback_timer.is_stopped(), "Replay cancels feedback timer")
	app.set_reduced_motion(false)
	for pair in pairs_for(app.model):
		app.cards[pair[0]].pressed.emit()
		app.cards[pair[1]].pressed.emit()
		app.feedback_timer.timeout.emit()
	app.chest_button.pressed.emit()
	check(app.model.chest_state == "opening", "Normal opening is staged, not immediate")
	check(app.theme_menu.disabled, "Opening disables theme selection")
	check(app.effects.particle_count() == 72, "Opening emits exactly 72 seasonal particles")
	await create_timer(1.95).timeout
	check(app.model.chest_state == "opened", "The native animation completes the reward")
	app.new_round(90)
	for pair in pairs_for(app.model):
		app.cards[pair[0]].pressed.emit()
		app.cards[pair[1]].pressed.emit()
		app.feedback_timer.timeout.emit()
	app.chest_button.pressed.emit()
	app.on_page_hidden()
	check(app.model.chest_state == "opened", "Hiding finalizes an already-earned opening once")
	check(app.effects.particle_count() == 0, "Hiding during opening clears particles")
	check(app._medallion.scale == Vector2.ONE, "Hiding does not leave a queued reward-pop animation")
	check(app._reward_tween == null or not app._reward_tween.is_running(), "Hiding cancels the reveal tween too")
	app.new_round(91)
	var wrong: Array = wrong_pair_for(app.model)
	for count in range(3):
		app.cards[wrong[0]].pressed.emit()
		app.cards[wrong[1]].pressed.emit()
		app.feedback_timer.timeout.emit()
	check(app.model.phase == "lost" and app.failure_image.visible, "Failure displays the encouraging picture")
	check(not app.audio.music.playing, "Loss stops background music")
	app.new_round(92)
	var first: String = app.model.cards[0].id
	app.cards[first].pressed.emit()
	var second: String = wrong_pair_for(app.model)[0]
	app.on_page_hidden()
	check(not app.audio.active, "Hiding pauses audio until another gesture")
	check(app.effects.particle_count() == 0, "Hiding clears transient effects")
	check(app.model.selected_id == first, "Hiding does not reset a selection")
	app.cards[second].pressed.emit()
	app.queue_free()
	await process_frame

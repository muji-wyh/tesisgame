extends SceneTree

const WordArt = preload("res://scripts/word_art.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	if not app.get("_mode_id") == "match":
		check(false, "New scene instances initialize in Match")
		app.free()
		quit(1)
		return
	var directory := "user://lesson-scene-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.choose_mode("match")
	app.choose_theme("spring")
	check(app.grid.is_visible_in_tree() and app.model.lesson_words.size() == 5, "Match starts with five vocabulary associations")
	var lesson: Array = app.model.lesson_words.duplicate(true)
	var world: String = app.model.theme_id
	for mode in ["memory", "pop", "match"]:
		app.choose_mode(mode)
		if mode == "pop":
			preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
		check(app.model.lesson_words == lesson and app.model.theme_id == world, "Mode " + mode + " retains the exact lesson and world")
		check((app.model.matched_ids.size() / 2) == 0 and app.model.mistakes == 0, "Mode change resets only the attempt")
		if mode == "memory":
			check(app._memory.memory.cards.all(func(card: Dictionary) -> bool: return lesson.has(card.word)),
				"Memory questions use exactly the learned words")
	check(not app._message.is_visible_in_tree() and app._status_announcement.contains("Find 5 word"),
		"The five-pair objective is announced accessibly without a visible footer")
	var wrong: Array = []
	for card in app.model.cards:
		if wrong.is_empty() or (card.kind != wrong[0].kind and card.word.id != wrong[0].word.id):
			wrong.append(card)
		if wrong.size() == 2:
			break
	app.cards[wrong[0].id].pressed.emit()
	app.cards[wrong[1].id].pressed.emit()
	check(app.model.phase == "feedback" and app.model.feedback_ids == [wrong[0].id, wrong[1].id]
		and not app._message.is_visible_in_tree(), "Wrong Match marks the chosen cards without adding another association panel")
	check(not app.feedback_timer.is_stopped(), "Manual Match feedback starts its automatic transition")
	app._show_collection()
	app.cards[wrong[0].id].pressed.emit()
	check(app.model.phase == "feedback", "A covered card cannot advance the challenge")
	app._hide_collection()
	app.cards[wrong[0].id].pressed.emit()
	check(app.model.phase == "matching" and app.model.selected_id == wrong[0].id,
		"The next card resumes the same challenge without a separate Continue")
	# This fixture exercises an earned chest; chance outcomes have separate coverage.
	app.model.chest_earned = true
	app.model.phase = "won"
	app.model.chest_state = "opened"
	app._refresh()
	check(app.model.lesson_words == lesson, "The opened chest retains the current lesson until New adventure")
	app._new_adventure_button.pressed.emit()
	check(app._mode_id == "match" and app.grid.is_visible_in_tree() and app.model.lesson_words != lesson,
		"New adventure leaves the opened chest for a fresh Match board")
	check(app.model.lesson_words.size() == 5 and app.model.theme_id == world and app.model.hints_remaining == 3,
		"The fresh lesson preserves the world and renews the normal hint allowance")
	var current: Dictionary = app.model.cards.filter(func(card: Dictionary) -> bool:
		return card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty())[0].word.duplicate()
	var current_card: Button = app.cards[current.id + ":word"]
	var picture_card: Button = app.cards[current.id + ":image"]
	current_card.pressed.emit()
	check((app.model.matched_ids.size() / 2) == 0 and app.medal_progress.counts.is_empty(), "Selecting one Match word never scores or awards pieces")
	check(not app.audio.voice.playing and current_card.word_label.visible and picture_card.picture.visible,
		"Muted Match keeps the written word and matching picture readable")
	app.audio.available = false
	app._audio_status("Sound is not available in this browser.")
	check(not current_card.disabled and not picture_card.disabled and current_card.word_label.visible
		and picture_card.picture.visible, "Unavailable audio keeps the matching association readable and playable")
	check(app._valid_focus(app._default_focus()), "Silent Match keeps an enabled keyboard/controller target")
	app.audio.available = true
	app.audio.set_muted(false)
	app._audio_status("")
	app._hear_word(current)
	check(app.audio.voice.playing, "Audio recovery restores word pronunciation")
	app.audio.status_changed.emit("Sound could not load. You can keep playing. Tap a card to try again.")
	check(app.audio.voice.playing, "Optional music failure does not disable bundled word pronunciation")
	var audio_statuses: Array[String] = []
	app.audio.status_changed.connect(func(message: String) -> void: audio_statuses.append(message))
	var missing_word: Dictionary = current.duplicate()
	missing_word.audio = "assets/audio/voice/word-missing-test.wav"
	app._hear_word(missing_word)
	check(not app.audio.voice.playing
		and audio_statuses.any(func(message: String) -> bool: return message.contains("could not load")),
		"Actual pronunciation failure stops playback and reports the missing audio")
	check(app.model.selected_id == current.id + ":word" and current_card.word_label.text == current.text
		and WordArt.source_path(picture_card.picture.texture) == "res://" + current.image,
		"Failed playback preserves the same readable picture-word association")
	app.audio.status_changed.emit("")
	check(not app.audio.voice.playing, "A later optional music success cannot restart a failed word")
	app._controller_back()
	current_card.pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + current.audio),
		"Retrying the visible bundled word restores its actual pronunciation")
	check((app.model.matched_ids.size() / 2) == 0 and app.model.mistakes == 0 and app.model.hints_remaining == 3
		and app.medal_progress.counts.is_empty(), "Audio recovery neither scores nor spends or awards progress")
	var stopped_playbacks: Array[WeakRef] = []
	for player in [app.audio.music, app.audio.voice]:
		if player.has_stream_playback():
			stopped_playbacks.append(weakref(player.get_stream_playback()))
	app.audio.set_muted(true)
	app._audio_status("")
	check(not app.audio.voice.playing and not current_card.disabled and not picture_card.disabled,
		"Muting stops pronunciation while preserving playable cards")
	var before_reset: Array = app.model.lesson_words.duplicate(true)
	app.new_round()
	check(app.model.lesson_words != before_reset, "An unseeded internal fixture reset selects fresh words")
	app.queue_free()
	await process_frame
	# The Dummy mixer reclaims stopped playback asynchronously; wait for actual release.
	var deadline: int = Time.get_ticks_msec() + 2000
	while stopped_playbacks.any(func(playback: WeakRef) -> bool: return playback.get_ref() != null) and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(stopped_playbacks.all(func(playback: WeakRef) -> bool: return playback.get_ref() == null), "Stopped lesson audio releases its playback resources before process teardown")
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Lesson scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

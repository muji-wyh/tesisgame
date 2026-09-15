extends SceneTree

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
		check(false, "New scene instances initialize in Match before Learn is explicitly chosen")
		app.free()
		quit(1)
		return
	var directory := "user://lesson-scene-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.choose_mode("learn")
	app.choose_theme("spring")
	check(app._lesson.is_visible_in_tree() and app.model.lesson_words.size() == 5, "Learn exposes exactly five concrete associations")
	var lesson: Array = app.model.lesson_words.duplicate(true)
	var world: String = app.model.theme_id
	for mode in ["match", "memory", "learn", "match"]:
		app.choose_mode(mode)
		check(app.model.lesson_words == lesson and app.model.theme_id == world, "Mode " + mode + " retains the exact lesson and world")
		check(app.model.successes == 0 and app.model.mistakes == 0, "Mode change resets only the attempt")
		if mode == "memory":
			check(app._memory.memory.cards.all(func(card: Dictionary) -> bool: return lesson.has(card.word)),
				"Memory questions use exactly the learned words")
	check(not app._message.is_visible_in_tree() and app._status_announcement.contains("no match"),
		"The two unmatched cards are explained accessibly without a visible footer")
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
	check(app.model.missed_word_ids.has(wrong[0].word.id) and app.model.missed_word_ids.has(wrong[1].word.id), "Both mixed-up words enter review")
	app._show_collection()
	app.cards[wrong[0].id].pressed.emit()
	check(app.model.phase == "feedback", "A covered card cannot advance the challenge")
	app._hide_collection()
	app.cards[wrong[0].id].pressed.emit()
	check(app.model.phase == "matching" and app.model.selected_id == wrong[0].id,
		"The next card resumes the same challenge without a separate Continue")
	app.model.phase = "lost"
	app._refresh()
	check(app._found_words.get_child_count() == 5, "Review includes all five lesson words")
	check(app._found_words.get_child(0).get_meta("word_id") == wrong[0].word.id, "Review presents missed words first")
	app._new_adventure_button.pressed.emit()
	check(app._mode_id == "learn" and app._lesson.is_visible_in_tree() and app.model.lesson_words != lesson,
		"New adventure leaves result review for a fresh five-word Learn lesson")
	check(app.model.lesson_words.size() == 5 and app.model.theme_id == world and app.model.hints_remaining == 3,
		"The fresh lesson preserves the world and renews the normal hint allowance")
	app._lesson._move(1)
	check(app.model.successes == 0 and app.medal_progress.counts.is_empty(), "Browsing Learn never scores or awards pieces")
	check(not app._lesson.audio_available and app._lesson.hear_hint_label.text.contains("No sound"),
		"Muted Learn keeps a written word and an honest no-sound cue")
	app.audio.available = false
	app._audio_status("Sound is not available in this browser.")
	check(app._lesson.controls() == [app._lesson.picture_button] and app._lesson.word_label.visible
		and app._lesson.picture.visible, "Unavailable audio never removes the lesson's readable, navigable association")
	for index in range(4):
		app._lesson._move(1)
	check(app._valid_focus(app._default_focus()), "The last silent lesson word keeps an enabled keyboard/controller target")
	app.audio.available = true
	app.audio.set_muted(false)
	app._audio_status("")
	check(app._lesson.audio_available, "Audio recovery restores Learn pronunciation")
	app.audio.status_changed.emit("Sound could not load. You can keep playing. Tap a card to try again.")
	check(app._lesson.audio_available, "Optional music failure does not disable bundled word pronunciation")
	var word_failures: Array[bool] = []
	var audio_statuses: Array[String] = []
	app.audio.word_failed.connect(func() -> void: word_failures.append(true))
	app.audio.status_changed.connect(func(message: String) -> void: audio_statuses.append(message))
	var current: Dictionary = app._lesson.current_word.duplicate()
	var missing_word: Dictionary = current.duplicate()
	missing_word.audio = "assets/audio/voice/word-missing-test.wav"
	app._lesson_hear(missing_word)
	check(word_failures.size() == 1 and not app.audio.voice.playing
		and audio_statuses.any(func(message: String) -> bool: return message.contains("could not load")),
		"Actual pronunciation failure stops playback and reports the missing audio")
	check(app._lesson.current_word == current and app._lesson.word_label.text == current.text
		and app._lesson.picture.texture.resource_path == "res://" + current.image,
		"Failed playback preserves the same readable picture-word association")
	app.audio.status_changed.emit("")
	check(not app.audio.voice.playing, "A later optional music success cannot restart a failed word")
	app._lesson.picture_button.pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + current.audio),
		"Retrying the visible bundled word restores its actual pronunciation")
	check(app.model.successes == 0 and app.model.mistakes == 0 and app.model.hints_remaining == 3
		and app.medal_progress.counts.is_empty(), "Audio recovery neither scores nor spends or awards progress")
	var stopped_playbacks: Array[WeakRef] = []
	for player in [app.audio.music, app.audio.voice]:
		if player.has_stream_playback():
			stopped_playbacks.append(weakref(player.get_stream_playback()))
	app.audio.set_muted(true)
	app._audio_status("")
	check(not app._lesson.audio_available and app._lesson.hear_hint_label.text.contains("No sound"),
		"Muted audio consistently restores the silent learning fallback")
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

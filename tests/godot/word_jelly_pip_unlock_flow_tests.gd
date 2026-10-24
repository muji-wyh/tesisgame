extends "res://tests/godot/professional_application_flow_tests.gd"
## Auto Collect follows the same saved everyday or career Pip as the header.

const Growth = preload("res://scripts/growth_state.gd")


func _make_app() -> void:
	directory = "user://word-jelly-pip-unlock-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Pip unlock integration uses isolated progress")
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var mastered: Array[String] = []
	var streaks: Dictionary = {}
	for index in range(Growth.level_threshold(2)):
		mastered.append(str(words[index].id))
		streaks[str(words[index].id)] = Growth.MASTERY_STREAK
	var saved := ConfigFile.new()
	for key in ["version", "level", "age", "streaks", "mastered_words", "receipts"]:
		saved.set_value("growth", key, {"version": Growth.VERSION, "level": 2, "age": 0,
			"streaks": streaks, "mastered_words": mastered, "receipts": []}[key])
	check(saved.save(directory + "/growth.cfg") == OK, "Startup loads a real three-word Lv2 mastery history")
	app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = Medal.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.save_preferences()
	app.professional.loader.media.free()
	app.professional.loader.media = MediaFixture.FixtureMedia.new()
	app.professional.loader.catalog = Catalog.new()
	app.professional.loader._owner.free()
	app.professional.loader._owner = MediaFixture.FixtureOwner.new(app.professional.loader.catalog)
	app.professional.loader.media.cache.values["sha256:" + IMAGE_HASH] = load("res://assets/images/words/absent.png")
	app.professional.loader.media.cache.values["sha256:" + AUDIO_HASH] = load("res://assets/audio/jelly-match/collect-do.wav")
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_process(false)
	app._word_jelly.set_process(false)


func _assert_level(expected: int, context: String) -> void:
	var state: Dictionary = app._word_jelly.game.snapshot()
	var button: Dictionary = app._word_jelly.collect_button.snapshot()
	check(state.pip_level == expected and state.auto_collect_unlocked == (expected >= 3)
		and state.auto_collect_unlock_level == 3 and button.pip_level == expected and button.locked == (expected < 3),
		context + ": model and button receive the active ready Pip level")


func _everyday_unlock() -> void:
	check(app.growth.ready and app.growth.level == 2 and app.growth.snapshot().lifetime_mastered == 3,
		"The startup Pip level comes from durable mastery")
	_assert_level(2, "Startup before entering Jelly Words")
	Fixture.enter_mode(app, "word_jelly")
	await settle()
	var round_id: String = app._round_id
	_assert_level(2, "A new everyday Jelly Words round")
	app._show_collection()
	app._choose_age_band("12")
	check(app._catalog_age == 12 and app.growth.level == 2, "Browsing an older vocabulary does not change earned Pip level")
	_assert_level(2, "Older-age vocabulary preview")
	app._hide_collection()
	var next_words: Array[String] = []
	for word: Dictionary in app.data.words:
		if not app.growth.is_mastered(str(word.id)):
			next_words.append(str(word.id))
		if next_words.size() == Growth.level_threshold(3) - Growth.level_threshold(2):
			break
	for attempt in range(2):
		app._record_growth("unlock-practice-%d" % attempt, next_words, true)
	_assert_level(2, "Practice without earned mastery")
	app._show_mode_menu()
	app._record_growth("unlock-earned", next_words, true)
	check(app.growth.snapshot().lifetime_mastered == 5 and app.growth.level == 3 and app.growth.age == 0,
		"Five durably mastered words earn Lv3 independently of Pip's age")
	_assert_level(3, "A mastery update while the round is paused")
	check(app._word_jelly.game.paused and app._word_jelly.collect_button.disabled,
		"Unlocking while Home is open does not resume the paused game")
	Fixture.enter_mode(app, "word_jelly")
	await settle()
	check(app._round_id == round_id and not app._word_jelly.game.paused, "Continue resumes the same unlocked round")
	_assert_level(3, "Resuming the unlocked round")
	check(app.new_round(1234, false, "", "word_jelly"), "An unlocked player can start a fresh Jelly Words round")
	_assert_level(3, "Fresh-round configuration")
	app.growth.ready = false
	app._refresh_growth()
	_assert_level(0, "Unavailable everyday progress")
	app._retry_storage()
	await settle()
	check(app.growth.ready and app.growth.level == 3, "Retry reloads the earned level from its saved mastery")
	_assert_level(3, "Everyday progress recovery")


func _career_unlock() -> void:
	await start_course("retail", "match")
	check(app._professional_profile_for(app._round_context).level == 0 and app.growth.level == 3,
		"A new active career has its own Lv0 Pip while everyday Pip remains Lv3")
	_assert_level(0, "New career selection")
	var ids: Array[String] = []
	for index in range(Growth.level_threshold(3)):
		ids.append("fixture.sense.%d" % index)
	for attempt in range(2):
		app._record_growth("career-unlock-practice-%d" % attempt, ids, true)
		await settle()
	_assert_level(0, "Career practice before durable mastery")
	app.professional.store.before_commit = func(operation: String) -> bool: return operation != "record"
	app._record_growth("career-unlock-pending", ids, true)
	await settle()
	check(app.professional.session.snapshot().blocked and not app._professional_profile_for(app._round_context).ready,
		"An unsaved career mastery event leaves the authoritative profile unavailable")
	_assert_level(0, "Pending career mastery cannot borrow everyday Lv3")
	app.professional.store.before_commit = Callable()
	app._retry_storage()
	await settle()
	check(app._professional_profile_for(app._round_context).level == 3
		and app._professional_profile_for(app._round_context).mastered == 5,
		"Retry commits five career words and derives the same Lv3 threshold")
	_assert_level(3, "Recovered career mastery")
	await start_course("retail", "word_jelly")
	_assert_level(3, "Starting Jelly Words with the earned career profile")
	app._show_mode_menu()
	app._select_learning_context(Context.growth(3, "word_jelly"))
	app.choose_mode("word_jelly")
	await settle()
	check(app._round_context.track == "growth" and app.growth.level == 3,
		"Returning to everyday words restores its independent saved Pip")
	_assert_level(3, "Returning from a career to everyday Jelly Words")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 800)
	await _make_app()
	await _everyday_unlock()
	await _career_unlock()
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Word Jelly Pip unlock flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

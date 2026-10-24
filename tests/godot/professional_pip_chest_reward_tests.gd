extends "res://tests/godot/professional_application_flow_tests.gd"
## Career rewards follow the saved career profile and the real async answer gates.

const Growth = preload("res://scripts/growth_state.gd")
const Feel = preload("res://scripts/chest_feel.gd")


func _make_app() -> void:
	directory = "user://professional-pip-chest-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Career chest tests use isolated storage")
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var mastered: Array = words.map(func(word: Dictionary) -> String: return str(word.id))
	var growth := ConfigFile.new()
	for key in ["version", "level", "age", "streaks", "mastered_words", "receipts"]:
		growth.set_value("growth", key, {"version": Growth.VERSION, "level": 99, "age": 0,
			"streaks": {}, "mastered_words": mastered, "receipts": []}[key])
	check(growth.save(directory + "/growth.cfg") == OK, "A valid everyday Lv99 history contrasts with the new career")
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
	app.set_reduced_motion(false)
	for node in [app, app._round_celebration, app.chest]:
		node.set_process(false)
	check(app.growth.level == 99, "The everyday Pip level is loaded from real saved mastery")


func _career_quote_and_track_change() -> void:
	await start_course("retail", "match")
	var profile: Dictionary = app._professional_profile_for(app._round_context)
	check(profile.ready and profile.level == 0 and app.growth.level == 99,
		"The active retail profile is independently Lv0 while everyday Pip is Lv99")
	var fresh: Dictionary = app._reserve_chest_reward("career-new-profile", 1)
	check(fresh.ok and fresh.reward.pip_level == 0 and fresh.reward.total == 50,
		"A new career quote uses the active Lv0 profile rather than everyday Lv99")
	var ids: Array[String] = []
	for index in range(Growth.level_threshold(5)):
		ids.append("fixture.sense.%d" % index)
	for attempt in range(3):
		app._record_growth("career-quote-mastery-%d" % attempt, ids, true)
		await settle()
	profile = app._professional_profile_for(app._round_context)
	check(profile.ready and profile.save_ok and profile.level == 5 and app.growth.level == 99,
		"Real saved career recognition events earn Lv5 without changing everyday learning")
	var reserved: Dictionary = app._reserve_chest_reward("career-lv5-track-change", 1)
	check(reserved.ok and reserved.reward.pip_level == 5 and reserved.reward.base == 50
		and reserved.reward.bonus == 2 and reserved.reward.total == 52,
		"The Lv5 career quote freezes its 50 base coins plus 2 Pip bonus coins")
	app._show_mode_menu()
	app._select_learning_context(Context.growth(3, "match"))
	app.choose_mode("match")
	await settle()
	check(app._round_context.track == "growth", "The player changes from the career to everyday learning")
	var before: int = app.coin_wallet.balance
	var paid: Dictionary = app._credit_chest_coins("career-lv5-track-change", 1)
	check(paid.ok and paid.amount == 52 and paid.chest_reward == reserved.reward
		and app.coin_wallet.balance == before + 52,
		"A saved career quote keeps Lv5 after switching to an everyday Lv99 track")
	var everyday: Dictionary = app._reserve_chest_reward("everyday-after-career", 1)
	check(everyday.ok and everyday.reward.pip_level == 99 and everyday.reward.total == 75,
		"A newly quoted everyday chest follows its own active Lv99 profile")


func _professional_phrase_retry() -> void:
	await start_course("retail", "phrase")
	var view = app._phrase
	for question in range(3):
		check(not app._professional_input_blocked(), "Saved professional practice accepts the next real phrase")
		for id in view.game.current_question().words:
			for index in range(view.game.options.size()):
				if view.game.options[index].id == id:
					view.option_buttons[index].pressed.emit()
		if question == 2:
			app.professional.store.before_commit = func(operation: String) -> bool: return operation != "record"
		view.action_button.pressed.emit()
		view.pip.set_process(false)
		await settle()
		if question < 2:
			view.pip._process(view.pip.GAMEPLAY_HAPPY_SECONDS + 0.01)
			view.action_button.pressed.emit()
	var before: int = app.coin_wallet.balance
	check(view.completion_pending and view.game.phase == "correct" and app._professional_input_blocked()
		and not app._round_celebration_active() and app.model.phase != "won",
		"A failed final professional answer keeps Phrase completion pending and pauses its celebration")
	app._accept_round_chest(app._round_id)
	check(not app._settle_completed_round_rewards() and view.completion_pending and app.model.phase != "won"
		and app.coin_wallet.balance == before,
		"Blocked completion cannot consume its final signal or claim coins through a stale accept/Home route")
	check(app._storage_retry_button.is_visible_in_tree() and not app._storage_retry_button.disabled,
		"The professional persistence failure exposes the existing Retry saving control")
	app.professional.store.before_commit = Callable()
	app._storage_retry_button.pressed.emit()
	await settle()
	check(not app._professional_input_blocked() and view.completion_pending and app._round_celebration_active(),
		"Retry saves the original professional answer and resumes its still-pending celebration")
	Fixture.finish_celebration(app)
	check(not view.completion_pending and view.game.phase == "finished" and app.model.phase == "won"
		and app.model.chest_state == "closed" and app.chest_button.is_visible_in_tree(),
		"The recovered professional celebration reaches its real closed chest exactly once")
	var id: String = app._single_chest_receipt()
	var quote: Dictionary = app.coin_wallet.chest_reward(id)
	check(quote.get("pip_level", -1) == 5 and quote.get("base", -1) == 50
		and quote.get("bonus", -1) == 2 and quote.get("total", -1) == 52,
		"The recovered professional Phrase chest uses the active career Lv5 reward")
	before = app.coin_wallet.balance
	app.chest_button.button_down.emit()
	app._advance_ui(Feel.HOLD_SECONDS)
	app.chest.set_process(false)
	if app.model.chest_state == "opening":
		app.chest._advance_animation(Feel.OPEN_SECONDS + 0.01)
	check(app.model.chest_state == "opened" and app.coin_wallet.balance == before + 52
		and app._single_result.snapshot().coin_breakdown.reward == quote,
		"A deliberate hold pays and displays the original recovered career quote")
	app._on_chest_opened()
	check(app.coin_wallet.balance == before + 52, "A repeated professional completion callback cannot pay twice")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 800)
	await _make_app()
	await _career_quote_and_track_change()
	await _professional_phrase_retry()
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Professional Pip chest rewards: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var app = load("res://scenes/main.tscn").instantiate()
	var properties: Array = app.get_property_list().map(
		func(property: Dictionary) -> String: return property.name)
	for property in ["_found_words", "_found_words_scroll", "_result_footer", "_result_actions", "_try_gift_button",
		"_outcome", "_stage", "_result_text", "_new_adventure_button", "_result_retry_button", "_treasure_backdrop"]:
		check(not properties.has(property), "The chest result removes the obsolete " + property + " control")
	check(not app.has_method("_replay_found_word"), "The removed result word strip has no replay handler")
	var directory := "user://adventure-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The adventure fixture has isolated storage")
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	Fixture.install(app, directory)
	app._mode_id = "match"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	app.new_round(17)
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	preload("res://tests/godot/player_flow_fixture.gd").reserve_pair_chest(app)
	app.choose_theme("spring")
	var adventure: Variant = app.model.get("adventure_name")
	check(adventure is String and not str(adventure).is_empty()
		and app.grid.is_visible_in_tree(),
		"The board retains its adventure without adding a redundant instruction")
	check(not properties.has("_adventure_label"),
		"The redundant adventure topic label is removed rather than hidden")
	check(not properties.has("_match_caption"), "Match has no separate Find 3 pairs caption")
	check(not app._single_result.replay_button.is_visible_in_tree(), "The active board has no result action")
	app._show_collection()
	check(app._age_catalog.is_visible_in_tree() and app.theme_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()),
		"The collection shows vocabulary while theme choices stay on Home")
	app._hide_collection()
	var words: Array[Dictionary] = _pairs(app)
	check(words.size() == 5, "The scene starts with five matchable words")
	check(app.coin_wallet.credit("fixture:adventure-hint", 4).ok, "Fund the adventure's paid hint")
	app._request_hint()
	check(app.model.hints_used == 1 and app.model.hint_ids.size() == 2,
		"The adventure records its first paid hint")
	app._controller_mode = true
	for word in words:
		_match(app, word)
	check(app.model.phase == "won" and app._single_result.is_visible_in_tree()
		and app._settlement_dialog.is_visible_in_tree() and app.grid.is_visible_in_tree(),
		"Winning presents a settlement dialog over the completed board")
	check(app._default_focus() == app.chest_button and app.chest_button.has_focus(),
		"The chest remains the primary controller action after winning")
	check(not app._single_result.replay_button.disabled, "A closed chest offers Play again with automatic settlement")
	var earned_lesson: Array = app.model.lesson_words.duplicate(true)
	check(app.model.chest_state == "closed" and app.model.lesson_words == earned_lesson
		and app.medal_progress.counts.is_empty(), "Showing the result does not claim the chest before an accepted action")
	app._show_collection()
	app._single_result.replay_button.pressed.emit()
	check(app.model.chest_state == "closed" and app.model.lesson_words == earned_lesson and app.medal_progress.counts.is_empty(),
		"The covered Play again action cannot leave the result or claim its reward")
	check(not app._focus_candidates().has(app.chest_button)
		and not app._focus_candidates().has(app._single_result.replay_button),
		"The collection modal excludes covered chest actions from controller focus")
	app._refresh()
	app._hide_collection()
	check(app._default_focus() == app.chest_button, "Closing the collection restores the unopened chest action")
	app._open_chest()
	check(app.model.chest_state == "opening" and not app._pending_fragment.is_empty()
		and not app._single_result.replay_button.disabled, "Opening captures one reward and retains automatic settlement actions")
	check(app._valid_focus(app._default_focus()), "Opening retains a valid controller destination")
	var captured: Dictionary = app._pending_fragment.duplicate(true)
	app._open_chest()
	check(app.model.chest_state == "opening" and app.model.lesson_words == earned_lesson,
		"A duplicate chest action cannot replace the opening or its lesson")
	check(app._pending_fragment == captured, "A duplicate opening preserves exactly the captured reward")
	app.chest.finish_immediately()
	check(app.medal_progress.count_for("spring-1") == 1 and app._single_result.heading.text == "Round complete"
		and app._single_result.replay_button.is_visible_in_tree(), "A saved opening exposes the next adventure")
	check(app._default_focus() == app._single_result.replay_button and app._single_result.replay_button.has_focus(),
		"The next adventure becomes the completed chest's controller action")
	for dimensions in [Vector2i(320, 320), Vector2i(320, 321), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		await process_frame
		await process_frame
		_check_result_bounds(app)
	app.new_round(17)
	check(app.model.adventure_name == adventure and app.grid.is_visible_in_tree(),
		"The same seed restores the same adventure and playable board")
	check(not app._single_result.replay_button.is_visible_in_tree() and app.model.hints_used == 0,
		"Reset hides the result action and clears hint purchase history")
	app.medal_progress.counts["spring-1"] = 3
	app.choose_theme("spring")
	check(app.medal_progress.next_fragment("spring").medal_id == "spring-2",
		"Completing Blossom moves the next chest reward to Ladybug")
	app.choose_theme("winter")
	check(app.medal_progress.next_fragment("winter").medal_id == "winter-1",
		"Changing season selects that season's next chest reward")
	check(app.model.adventure_name == adventure, "Season selection preserves the current adventure topic")
	for index in range(1, 7):
		app.medal_progress.counts["winter-%d" % index] = 3
	app._refresh()
	check(app.medal_progress.completed_count("winter") == 6, "A completed season retains six earned medals")
	app.new_round(19)
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	preload("res://tests/godot/player_flow_fixture.gd").reserve_pair_chest(app)
	words = _pairs(app)
	_match(app, words[0])
	_retry_mismatches(app)
	check(app.model.phase == "waiting" and app.model.matched_ids.size() == 2
		and not app._single_result.is_visible_in_tree(),
		"Repeated mismatches preserve the learned pair and active board")
	for word in words.slice(1):
		_match(app, word)
	check(app.model.phase == "won" and app.model.chest_earned and app.model.chest_state == "closed",
		"Finishing after repeated mistakes still earns an unopened chest")
	root.size = Vector2i(320, 320)
	await process_frame
	await process_frame
	_check_result_bounds(app)
	var completed_id: String = app._round_id
	var coins_before_replay: int = app.coin_wallet.balance
	app._single_result.replay_button.pressed.emit()
	check(app._round_id != completed_id and app.model.phase == "waiting"
		and app.coin_wallet.balance == coins_before_replay + 50,
		"Play again preserves the unopened Match reward once before starting a fresh board")
	app.audio.set_muted(true)
	app.new_round(20)
	_retry_mismatches(app)
	check(app.model.phase == "waiting" and app.model.matched_ids.is_empty()
		and not app._single_result.is_visible_in_tree(),
		"Repeated mistakes without matches never replace the board with results")
	app.new_round(21)
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	preload("res://tests/godot/player_flow_fixture.gd").reserve_pair_chest(app)
	words = _pairs(app)
	app._on_voice_state([true, true, "Listening"])
	for word in words:
		app._on_voice_result([word.text, true])
		app.feedback_timer.timeout.emit()
	Fixture.finish_celebration(app)
	check(app.model.phase == "won" and app.chest_button.is_visible_in_tree() and not app._voice_mode,
		"Voice-earned matches use the same chest result and exit listening")
	app.new_round(22)
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	preload("res://tests/godot/player_flow_fixture.gd").reserve_pair_chest(app)
	words = _pairs(app)
	for word in words.slice(0, 4):
		_match(app, word)
	app.cards[words[4].id + ":word"].pressed.emit()
	app.cards[words[4].id + ":image"].pressed.emit()
	app._show_collection()
	app._continue_match()
	await create_timer(0.8).timeout
	check(app.model.phase == "feedback" and app.collection_page.visible and app.feedback_timer.paused,
		"Opening the collection pauses the final answer's automatic transition")
	check(not app._focus_candidates().has(app.chest_button), "The chest cannot escape the active modal")
	app._hide_collection()
	await create_timer(0.8).timeout
	check(app.model.phase == "won", "The final answer automatically completes after closing the collection")
	Fixture.finish_celebration(app)
	check(app._focus_candidates().has(app.chest_button), "The earned chest becomes reachable after closing the collection")
	await _check_result_lifecycle_layout(app)
	app.on_page_hidden()
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	var files := DirAccess.open(directory)
	for filename in files.get_files():
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Adventure scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _pairs(app) -> Array[Dictionary]:
	var words: Array[Dictionary] = []
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			words.append(card.word)
	return words


func _match(app, word: Dictionary) -> void:
	app.cards[word.id + ":word"].pressed.emit()
	app.cards[word.id + ":image"].pressed.emit()
	app._continue_match()
	Fixture.finish_celebration(app)


func _retry_mismatches(app) -> void:
	var wrong: Array[String] = []
	for card in app.model.cards:
		if app.model.matched_ids.has(card.id):
			continue
		if wrong.is_empty() or (card.kind != app.model.card_by_id(wrong[0]).kind and card.word.id != app.model.card_by_id(wrong[0]).word.id):
			wrong.append(card.id)
		if wrong.size() == 2:
			break
	check(wrong.size() == 2, "The retry fixture uses a real unmatched word and a different picture")
	if wrong.size() != 2:
		return
	for attempt in range(5):
		app.cards[wrong[0]].pressed.emit()
		app.cards[wrong[1]].pressed.emit()
		app._continue_match()


func _check_result_bounds(app) -> void:
	var viewport: Rect2 = root.get_visible_rect().grow(0.5)
	var panel: Rect2 = app._settlement_dialog.panel.get_global_rect()
	var content: Rect2 = app._single_result.get_global_rect()
	check(app._settlement_dialog.is_ancestor_of(app._single_result)
		and panel.encloses(content), "Settlement content lives inside its bounded dialog at %s" % root.size)
	check(viewport.encloses(panel) and panel.size.x < viewport.size.x and panel.size.y < viewport.size.y,
		"The settlement leaves the completed game visible around its edges at %s" % root.size)
	for button in [app._single_result.replay_button, app._single_result.retry_button, app._single_result.home_button]:
		if not button.is_visible_in_tree():
			continue
		var bounds: Rect2 = button.get_global_rect()
		var scale: float = app.Style.ui_scale(app)
		check(app._single_result.is_ancestor_of(button) and viewport.encloses(bounds)
			and content.encloses(bounds), "Settlement actions stay inside their dialog at %s" % root.size)
		check(button.size.x * scale >= 44.0 and button.size.y * scale >= 44.0,
			"Settlement actions retain a 44px touch target at %s" % root.size)
		check(bounds.get_center().y > content.get_center().y,
			"Settlement actions occupy a stable footer below the chest at %s" % root.size)


func _check_result_lifecycle_layout(app) -> void:
	var seed_value: int = 100
	for mode in ["match", "memory"]:
		for dimensions in [Vector2i(320, 320), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 768)]:
			seed_value += 1
			root.size = dimensions
			app.new_round(seed_value, false, "", mode)
			# Match chance is fixed; Memory earns its tier through real completion.
			preload("res://tests/godot/player_flow_fixture.gd").reserve_pair_chest(app)
			app.set_reduced_motion(false)
			if mode == "memory":
				Fixture.start_memory(app)
				for word in app.model.lesson_words:
					for index in range(app._memory.memory.cards.size()):
						if app._memory.memory.cards[index].word.id == word.id:
							app._memory.card_buttons[index].pressed.emit()
					app._memory.continue_feedback()
			else:
				for word in _pairs(app):
					_match(app, word)
			Fixture.finish_celebration(app)
			await process_frame
			await process_frame
			if app._settlement_dialog._entrance != null and app._settlement_dialog._entrance.is_valid():
				app._settlement_dialog._entrance.custom_step(1.0)
			check(app.model.phase == "won" and app.model.chest_state == "closed"
				and not app._single_result.replay_button.disabled, "%s offers replay with automatic settlement of its closed chest" % mode)
			_check_result_bounds(app)
			var stage: Rect2 = app._single_result.get_global_rect()
			app._open_chest()
			await process_frame
			check(not app._single_result.replay_button.disabled and app._single_result.get_global_rect().is_equal_approx(stage),
				"Opening %s keeps the full chest composition and its settlement actions at %s" % [mode, dimensions])
			app.chest.finish_immediately()
			await process_frame
			await process_frame
			check(app._single_result.replay_button.is_visible_in_tree() and not app._single_result.retry_button.visible
				and app._single_result.get_global_rect().is_equal_approx(stage),
				"The saved %s opening preserves its footer action without moving the chest at %s" % [mode, dimensions])
			check(app._single_result.heading.is_visible_in_tree() and app._single_result.caption.is_visible_in_tree(),
				"A completed chest retains the dialog heading and collection acknowledgement")
			_check_result_bounds(app)
			app._single_result.replay_button.grab_focus()
			check(app._default_focus() == app._single_result.replay_button
				and app._focus_candidates().has(app._single_result.replay_button), "The footer action remains reachable by controller")
			app._show_collection()
			check(not app._focus_candidates().has(app._single_result.replay_button), "The room excludes the covered footer action")
			app._hide_collection()
			check(root.gui_get_focus_owner() == app._single_result.replay_button, "Closing the room restores the floating action's focus")

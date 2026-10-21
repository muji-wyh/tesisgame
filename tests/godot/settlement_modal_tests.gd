extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Progress = preload("res://scripts/medal_progress.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const SIZES: Array[Vector2i] = [Vector2i(393, 852), Vector2i(844, 390), Vector2i(1366, 768)]
const CASES: Array[Dictionary] = [
	{"mode": "match", "earned": true}, {"mode": "memory", "earned": true},
	{"mode": "phrase", "earned": true}, {"mode": "pop", "earned": false},
	{"mode": "pop", "earned": true}, {"mode": "jelly", "earned": false},
	{"mode": "word_jelly", "earned": false}
]

var checks: int = 0
var failures: int = 0
var _serial: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(5):
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for item: Dictionary in CASES:
		root.size = SIZES[0]
		var app = await _make_app(str(item.mode))
		await _complete_mode(app, str(item.mode), bool(item.earned))
		_check_removed_pages(app)
		_check_result_owner(app, str(item.mode))
		await _check_layout(app, str(item.mode))
		await _check_input_isolation(app, str(item.mode))
		if item.mode == "match":
			await _check_save_retry(app)
		elif item.mode in ["memory", "phrase"]:
			app._open_chest()
			await _settle()
			check(app.model.chest_state == "opened" and not app._save_error,
				str(item.mode) + ": the modal uses the real chest opening and save lifecycle")
		await _check_navigation(app, str(item.mode))
		await _dispose(app)
	print("Settlement modal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _make_app(mode: String):
	_serial += 1
	var directory := "user://settlement-modal-%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), _serial]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, mode + ": isolated settlement storage is available")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.save_preferences()
	app.set_meta("settlement_fixture_directory", directory)
	root.add_child(app)
	await _settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.new_round(716, false, "", mode, "", false), mode + ": the real application starts its seeded board")
	for node: Node in [app, app._jelly, app._word_jelly, app._pop, app._round_celebration, app._pair_reward]:
		node.set_process(false)
	await _settle()
	return app


func _complete_mode(app, mode: String, earned: bool) -> void:
	if mode in ["match", "memory"]:
		Fixture.reserve_pair_chest(app)
	if mode == "match":
		for word: Dictionary in app.model.lesson_words:
			app.cards[str(word.id) + ":word"].pressed.emit()
			app.cards[str(word.id) + ":image"].pressed.emit()
			app._continue_match()
	elif mode == "memory":
		Fixture.start_memory(app)
		for word: Dictionary in app.model.lesson_words:
			for index in range(app._memory.memory.cards.size()):
				if str(app._memory.memory.cards[index].word.id) == str(word.id):
					app._memory.card_buttons[index].pressed.emit()
			app._memory.continue_feedback()
	elif mode == "phrase":
		var view = app._phrase
		for question in range(3):
			for id in view.game.current_question().words:
				for index in range(view.game.options.size()):
					if view.game.options[index].id == id:
						view.option_buttons[index].pressed.emit()
			view.action_button.pressed.emit()
			view.pip.set_process(false)
			if question < 2:
				view.pip._process(view.pip.GAMEPLAY_HAPPY_SECONDS + 0.01)
				view.action_button.pressed.emit()
	elif mode == "pop":
		app._start_pop_listening()
		app._pop.set_listening(true, true, "Listening.")
		app._pop.set_process(false)
		if earned:
			# Fix only the marker; real transcript acceptance earns every fragment.
			for fragment in range(4):
				for step in range(100):
					if not app._pop.game.targets.is_empty():
						break
					app._pop._advance_game(0.1)
				check(not app._pop.game.targets.is_empty(), "Pop: the earning fixture reaches a live target")
				if app._pop.game.targets.is_empty():
					break
				app._pop.game.targets[0].chest = true
				app._pop._refresh_targets()
				app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
				app._pop.advance_reward_presentation(8.0)
				app._pop._listening_tick_usec = -1
			check(app._pop.game.fragment_count == 4 and app._pop.game.chest_count == 1,
				"Pop: four recognized marked targets earn exactly one chest")
		app._pop._advance_game(0.66)
		app._pop.finish_round()
		check(app._round_result.get("chest_count", -1) == (1 if earned else 0),
			"Pop: settlement preserves the actual zero or earned chest outcome")
		check(not app._pop_speech_active and not app._pop._listening,
			"Pop: the microphone is stopped before the result dialog becomes interactive")
	else:
		var view = app._active_jelly()
		view.game.spawn_interval = 10000.0
		view.game.step(2.0)
		view.finish_button.accessibility_requested.emit()
		check(app._finish_confirmation_open(), mode + ": accessible Finish reaches its confirmation")
		app._finish_confirmation.finish_button.pressed.emit()
	Fixture.finish_celebration(app)
	if mode in ["match", "memory", "phrase"]:
		check(app.model.phase == "won" and app.model.chest_earned,
			mode + ": completing the real lesson reaches its earned-chest result")
	app._refresh()
	await _settle()


func _check_removed_pages(app) -> void:
	var properties: Array = app.get_property_list().map(func(value: Dictionary) -> String: return str(value.name))
	for name in ["_outcome", "_stage", "_result_text", "_title", "_caption", "_new_adventure_button", "_result_retry_button", "_treasure_backdrop"]:
		check(not properties.has(name), "The retired shared result page property is removed: " + name)
	for method in ["_layout_result", "_style_result_actions"]:
		check(not app.has_method(method), "The retired shared result page method is removed: " + method)
	var pop_properties: Array = app._pop.get_property_list().map(func(value: Dictionary) -> String: return str(value.name))
	for name in ["_results", "_result_body", "_result_hero", "_result_actions", "_result_rewards"]:
		check(not pop_properties.has(name), "The retired Pop result page property is removed: " + name)
	check(app._pop.find_child("PopResults", true, false) == null and not app._pop.has_method("_build_results"),
		"Pop creates neither a standalone result page nor its old builder")


func _board(app, mode: String) -> Control:
	match mode:
		"match": return app._match_playfield
		"memory": return app._memory
		"phrase": return app._phrase
		"pop": return app._pop
		"jelly": return app._jelly
		_: return app._word_jelly


func _result_content(app, mode: String) -> Control:
	return app._pop_rewards if mode == "pop" else app._jelly_rewards if mode in ["jelly", "word_jelly"] else app._single_result


func _check_result_owner(app, mode: String) -> void:
	var modal = app._settlement_dialog
	var content: Control = _result_content(app, mode)
	check(modal.is_visible_in_tree() and modal._room == content and content.get_parent() == modal.panel,
		mode + ": the shared settlement dialog owns the completed round content")
	check(_board(app, mode).is_visible_in_tree() and not modal.is_ancestor_of(_board(app, mode)),
		mode + ": the actual completed board remains visible behind the modal")
	check(modal.mouse_filter == Control.MOUSE_FILTER_STOP and modal.panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		mode + ": both shade and panel contain pointer input")
	check(modal.snapshot().title == "Round complete", mode + ": the shared host announces the completed round")
	check(not app._round_celebration_active(), mode + ": no intermission replaces the final settlement content")
	var target: Control = app._default_focus()
	check(app._valid_focus(target) and modal.is_ancestor_of(target), mode + ": the default focus belongs to the modal")
	for control: Control in app._focus_candidates():
		check(modal.is_ancestor_of(control), mode + ": covered controls are excluded from keyboard focus")
	check(not app._focus_candidates().has(modal.panel),
		mode + ": the fallback panel does not interrupt navigation between available actions")
	if mode == "pop":
		check(app._pop.snapshot().board_frozen and app._pop.controls().is_empty(), "Pop: finished targets remain frozen without a result page")
	elif mode in ["jelly", "word_jelly"]:
		check(app._active_jelly().game.phase == "finished" and not app._jelly_interaction_allowed(), mode + ": the settled board no longer accepts play")
	elif mode == "memory":
		check(app._memory.memory.phase == "won" and not app._memory._can_play(), "Memory: completion preserves its frozen cards")
	elif mode == "phrase":
		check(app._phrase.game.phase == "finished" and not app._phrase_interaction_allowed(), "Phrase: completion preserves its frozen phrase")
	else:
		check(app.model.phase == "won", "Match: completion preserves its frozen cards")


func _check_layout(app, mode: String) -> void:
	for dimensions: Vector2i in SIZES:
		root.size = dimensions
		await _settle()
		var modal = app._settlement_dialog
		var viewport: Rect2 = root.get_visible_rect().grow(0.5)
		var panel: Rect2 = modal.panel.get_global_rect()
		check(viewport.encloses(panel), mode + ": the complete modal fits at " + str(dimensions))
		check(modal.panel.size.x <= (560.1 if dimensions.y < 480 else 480.1) / app.Style.ui_scale(app),
			mode + ": the dialog stays bounded instead of stretching into a full page")
		var content: Control = _result_content(app, mode)
		check(panel.encloses(content.get_global_rect()), mode + ": settlement content fits inside its panel")
		for button: Button in content.find_children("*", "Button", true, false):
			if not button.is_visible_in_tree():
				continue
			check(panel.grow(0.5).encloses(button.get_global_rect()), mode + ": the entire " + str(button.name) + " action fits at " + str(dimensions))
			check(button.size.y * app.Style.ui_scale(app) >= 43.75,
				mode + ": " + str(button.name) + " preserves its 44px touch target")
		if mode in ["match", "memory", "phrase"]:
			var state: Dictionary = app._single_result.snapshot()
			check(panel.encloses(app.chest.get_global_rect()) and app.chest.get_global_rect() == app.chest_button.get_global_rect(),
				mode + ": the chest and its direct hold target stay contained and aligned")
			check(_rect(state.chest_button.rect).is_equal_approx(app.chest_button.get_global_rect()),
				mode + ": the published chest target matches its exact real rectangle")
			check(content.find_children("*", "ScrollContainer", true, false).is_empty(), mode + ": compact settlement needs no scrolling")
		else:
			check(is_zero_approx(float(content.snapshot().scroll_max)), mode + ": settlement needs no scrolling at " + str(dimensions))


func _state(app, mode: String) -> Dictionary:
	var state: Dictionary = {"round": app._round_id, "mode": app._mode_id, "phase": app.model.phase,
		"result": app._round_result.duplicate(true), "matched": app.model.matched_ids.duplicate(),
		"selected": app.model.selected_id, "coins": app.coin_wallet.balance}
	if mode == "pop":
		state.game = app._pop.game.summary().duplicate(true)
	elif mode in ["jelly", "word_jelly"]:
		state.game = app._active_jelly().game.snapshot().duplicate(true)
	elif mode == "phrase":
		state.game = app._phrase.game.snapshot().duplicate(true)
	elif mode == "memory":
		state.game = {"phase": app._memory.memory.phase, "matched": app._memory.memory.matched_word_ids.duplicate(),
			"selected": app._memory.memory.selected_indices.duplicate(), "attempts": app._memory.memory.attempts}
	return state


func _key(code: Key, pressed: bool, shifted: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.shift_pressed = shifted
	root.push_input(event, true)


func _tap(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = point
		event.pressed = down
		root.push_input(event, true)


func _check_input_isolation(app, mode: String) -> void:
	var before: Dictionary = _state(app, mode)
	_tap(Vector2(2.0, 2.0))
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _settle()
	check(app._settlement_dialog_open() and _state(app, mode) == before,
		mode + ": shade taps and Escape neither dismiss settlement nor change the frozen round")
	app._default_focus().grab_focus()
	for code: Key in [KEY_TAB, KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP]:
		_key(code, true)
		_key(code, false)
		await process_frame
		var focused: Control = root.gui_get_focus_owner()
		check(focused != null and app._settlement_dialog.is_ancestor_of(focused),
			mode + ": native keyboard navigation stays within the modal")
	_key(KEY_TAB, true, true)
	_key(KEY_TAB, false, true)
	await process_frame
	check(app._settlement_dialog.is_ancestor_of(root.gui_get_focus_owner()), mode + ": reverse Tab stays within the modal")
	check(_state(app, mode) == before, mode + ": navigating the dialog cannot mutate gameplay")


func _check_save_retry(app) -> void:
	var directory: String = str(app.get_meta("settlement_fixture_directory"))
	var path: String = directory + "/blocked.cfg"
	var failing = Progress.new(path, directory + "/unused.cfg")
	check(failing.load_progress(), "Match: the failure fixture loads through the normal storage adapter")
	failing.counts = app.medal_progress.counts.duplicate(true)
	failing._pair_state = app.medal_progress._pair_state.duplicate(true)
	check(failing._persist(failing.counts), "Match: the captured pair reward is durable before blocking its final save")
	DirAccess.remove_absolute(path)
	check(DirAccess.make_dir_absolute(path) == OK, "Match: only the isolated reward save destination is blocked")
	app.medal_progress = failing
	app._open_chest()
	await _settle()
	check(app._save_error and app._single_result.retry_button.is_visible_in_tree()
		and not app._single_result.retry_button.disabled
		and app._single_result.home_button.disabled and app._single_result.replay_button.disabled,
		"Match: persistence failure keeps recovery inside the same modal and prevents departure")
	var pending: Dictionary = app._pending_fragment.duplicate(true)
	check(not pending.is_empty(), "Match: failed persistence retains the exact earned reward")
	check(DirAccess.remove_absolute(path) == OK, "Match: repairing the isolated save leaves the receipt intact")
	app._single_result.retry_button.pressed.emit()
	await _settle()
	check(not app._save_error and app.model.chest_state == "opened" and not app._single_result.replay_button.disabled,
		"Match: a successful retry enables the modal's next-round action")
	if not pending.is_empty():
		check(app.medal_progress.count_for(str(pending.medal_id)) == int(pending.after),
			"Match: the retry persists precisely the originally earned reward")
	var coins: int = app.coin_wallet.balance
	var saved: Dictionary = app.medal_progress.counts.duplicate(true)
	app._single_result.retry_button.pressed.emit()
	app._retry_reward_save()
	app._on_chest_opened()
	check(app.coin_wallet.balance == coins and app.medal_progress.counts == saved,
		"Match: stale retry and chest completion callbacks cannot award duplicate coins or progress")


func _check_navigation(app, mode: String) -> void:
	var identity: String = app._round_id
	var content = _result_content(app, mode)
	var home: Button = content.home_button if mode in ["match", "memory", "phrase"] else content._home
	var replay: Button = content.replay_button if mode in ["match", "memory", "phrase"] else content._back
	check(home.is_visible_in_tree() and replay.is_visible_in_tree(), mode + ": Home and Play again stay in the modal footer")
	home.pressed.emit()
	await _settle()
	check(app._mode_menu_open() and not app._settlement_dialog_open(), mode + ": Home closes the modal into the mode library")
	app.choose_mode(mode)
	await _settle()
	check(not app._settlement_dialog_open() and app._round_id != identity and not app._current_round_ended(),
		mode + ": returning from Home starts a fresh playable round")
	var coins: int = app.coin_wallet.balance
	# Complete a second round to exercise replay directly, with its chest still closed.
	await _complete_mode(app, mode, mode in ["match", "memory", "phrase", "pop"])
	identity = app._round_id
	var expected_coins: int = coins + (Economy.chest_coins(RewardProgress.THEMES.size()) if mode == "memory" else 50 if mode in ["match", "phrase", "pop"] else 0)
	replay.pressed.emit()
	await _settle()
	check(not app._settlement_dialog_open() and app._round_id != identity and _board(app, mode).is_visible_in_tree(),
		mode + ": Play again starts a fresh playable board directly from the modal")
	check(app.coin_wallet.balance == expected_coins, mode + ": replay automatically claims its unopened chest once")
	var fresh_id: String = app._round_id
	replay.pressed.emit()
	check(app._round_id == fresh_id and app.coin_wallet.balance == expected_coins,
		mode + ": repeated replay cannot restart the new round or duplicate its reward")


func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _dispose(app) -> void:
	var directory: String = str(app.get_meta("settlement_fixture_directory"))
	app.audio.halt()
	app.queue_free()
	await _settle()
	for filename: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)

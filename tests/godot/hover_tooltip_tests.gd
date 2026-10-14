extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Feel = preload("res://scripts/chest_feel.gd")
var checks := 0
var failures := 0
var scanned_states := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func scan(app: Node, context: String) -> void:
	# Include hidden controls: changing modes or refreshing state can reveal them.
	var pending: Array[Node] = [app]
	var controls := 0
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is Control:
			controls += 1
			check(node.tooltip_text.is_empty() and node.get_tooltip(Vector2.ZERO).is_empty(),
				context + " has no hover popup on " + str(node.get_path()))
	check(controls > 100, context + " checks the real populated application tree")
	scanned_states += 1


func named(controls: Array, context: String) -> void:
	for control: Control in controls:
		var has_name: bool = not str(control.get("accessibility_name")).strip_edges().is_empty()
		var has_button_text: bool = control is Button and not control.text.strip_edges().is_empty()
		check(has_name or has_button_text,
			context + " keeps an accessible label for " + str(control.name))


func _catalog(app) -> void:
	app._mode_panel.collection_button.pressed.emit()
	await settle()
	check(app.collection_page.is_visible_in_tree(), "Home opens the real vocabulary catalog")
	for age in range(3, 13):
		app._age_buttons[str(age)].pressed.emit()
		await settle()
		scan(app, "Age %d catalog" % age)
		named([app._collection_back, app._age_buttons[str(age)]], "Catalog navigation")
		named(app._age_catalog.word_buttons, "Catalog pronunciation cards")
	app._back_from_collection()


func _match(app) -> void:
	Fixture.enter_mode(app, "match")
	await settle()
	named([app._mode_heading_button, app._growth_button, app.hint_button, app._voice_button, app.duck], "Game header")
	scan(app, "Match board")
	Fixture.reserve_pair_chest(app)
	check(app.coin_wallet.credit("fixture:hover-match-hints", 17).ok, "Fund a paid hint for each of the five Match pairs")
	var purchased_hints := 0
	for word: Dictionary in app.model.lesson_words.duplicate(true):
		check(not app.hint_button.disabled and app.hint_button.count == -1,
			"Every remaining pair supports a paid Hint with no use limit badge")
		app.hint_button.pressed.emit()
		purchased_hints += 1
		check(app.model.hints_used == purchased_hints and app.model.hint_ids.size() == 2,
			"Each accepted purchase highlights a pair, including after the former three-hint limit")
		scan(app, "Active Match hint %d" % purchased_hints)
		app.cards[str(word.id) + ":word"].pressed.emit()
		app.cards[str(word.id) + ":image"].pressed.emit()
		app._continue_match()
	check(app.model.phase == "won" and app.model.hints_used == 5 and app.coin_wallet.balance == 0,
		"Five paid hints finish Match and debit their prices without a round use limit")
	scan(app, "Completed Match after five paid hints")
	Fixture.finish_celebration(app)
	await settle()
	check(app.chest_button.is_visible_in_tree(), "The earned chest invitation reaches the chest page")
	named([app.chest_button], "Chest invitation")
	scan(app, "Closed chest")
	app.chest_button.button_down.emit()
	app._advance_ui(Feel.HOLD_SECONDS)
	app.chest.set_process(false)
	app.chest._advance_animation(Feel.RELEASE_TIME + 0.01)
	app._refresh()
	scan(app, "Committed chest opening")
	app.on_page_hidden()
	app.on_page_visible()
	await settle()
	check(app.model.chest_state == "opened", "Settling an earned chest reaches its result page")
	scan(app, "Opened chest result")


func _memory_and_phrase(app) -> void:
	Fixture.enter_mode(app, "memory")
	await settle()
	named([app._memory.study_button], "Memory hold-to-peek")
	scan(app, "Face-down Memory board")
	app._memory.begin_peek()
	scan(app, "Revealed Memory board")
	app._memory.end_peek()
	app._memory.card_buttons[0].pressed.emit()
	scan(app, "Selected Memory card")
	Fixture.enter_mode(app, "phrase")
	await settle()
	named([app._phrase.listen_button, app._phrase.pip], "Phrase listening controls")
	scan(app, "Phrase word bank")
	app._phrase.option_buttons[0].pressed.emit()
	scan(app, "Phrase answer tile")
	app._phrase.answer_buttons[0].pressed.emit()
	scan(app, "Returned Phrase word")


func _pop(app) -> void:
	Fixture.enter_mode(app, "pop")
	await settle()
	scan(app, "Voice Pop start page")
	Fixture.choose_pop_player(app)
	app._pop.set_listening(true, true, "Listening.")
	app._pop_speech_active = true
	app._pop.set_process(false)
	for fragment in range(4):
		if app._pop.game.targets.is_empty():
			app._pop._advance_game(0.66)
		check(not app._pop.game.targets.is_empty(), "A live Voice Pop target is available")
		if app._pop.game.targets.is_empty():
			return
		app._pop.game.targets[0].chest = true
		app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
		app._pop.advance_reward_presentation(5.0)
		scan(app, "Voice Pop scoring and chest refresh")
	app._pop.finish_round()
	Fixture.finish_celebration(app)
	await settle()
	check(app._pop_rewards_shown and app._settlement_dialog.is_visible_in_tree()
		and not app._pop_rewards._cards.is_empty(), "Earned Voice Pop treasure opens directly in the settlement dialog")
	named(app._pop_rewards.navigation_controls(), "Voice Pop settlement actions")
	scan(app, "Voice Pop settlement dialog")
	for card: Dictionary in app._pop_rewards._cards:
		named([card.button], "Saved chest card")
	scan(app, "Voice Pop treasure room")


func _jellies(app) -> void:
	for mode in ["jelly", "word_jelly"]:
		Fixture.enter_mode(app, mode)
		await settle()
		var view = app._active_jelly()
		view.set_process(false)
		named([view.drop_button, view.finish_button], mode + " controls")
		scan(app, mode + " board and upcoming tiles")
		view.drop_button.pressed.emit()
		view.game.step(0.5)
		view._sync_tiles()
		scan(app, mode + " newly dropped tiles")
		if mode == "word_jelly":
			# The same public update is used when the board starts, gains words,
			# and counts down its collection batch.
			for state: Array in [[0, false, 0, 0], [7, false, 0, 0], [4, true, 4, 7]]:
				view.collect_button.set_state(state[0], state[1], state[2], state[3])
				named([view.collect_button], "Jelly Words collection state")
				scan(app, "Jelly Words collection update")
		view.finish_button.accessibility_requested.emit()
		check(app._finish_confirmation_open(), mode + " finish action asks for confirmation")
		named([app._finish_confirmation.keep_playing_button, app._finish_confirmation.finish_button], mode + " finish confirmation")
		scan(app, mode + " finish confirmation")
		app._finish_confirmation.finish_button.pressed.emit()
		Fixture.finish_celebration(app)
		await settle()
		check(view.game.phase == "finished", mode + " finish action reaches its result")
		scan(app, mode + " result")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://hover-tooltips-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Tooltip checks use isolated saves")
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	Fixture.install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app._mode_menu_open(), "The real application starts at Home")
	named([app._mode_panel.sound_button, app._mode_panel.collection_button, app._mode_panel.pip], "Home settings")
	for button: Button in app._mode_panel.theme_buttons:
		button.pressed.emit()
		named([button], "Home theme")
		scan(app, "Home theme refresh")
	await _catalog(app)
	await _match(app)
	await _memory_and_phrase(app)
	await _pop(app)
	await _jellies(app)
	Fixture.enter_mode(app, "match")
	app._on_voice_state([true, true, "Listening."])
	app._refresh()
	scan(app, "Match voice enabled")
	app._on_voice_state([false, false, "Voice off."])
	app._refresh()
	scan(app, "Match voice disabled")
	app.coin_wallet.error = "The saved balance could not be read."
	app._refresh()
	check(app._storage_retry_button.visible, "Storage failure exposes its recovery action")
	named([app._storage_retry_button], "Save recovery")
	check(str(app._storage_retry_button.get("accessibility_description")) == app.coin_wallet.error,
		"Balance recovery retains the storage explanation for assistive technology")
	scan(app, "Storage recovery")
	app.coin_wallet.error = ""
	app.medal_progress.error = "The reward could not be saved."
	app._save_error = true
	app._refresh()
	check(app._single_result.retry_button.visible
		and str(app._single_result.retry_button.get("accessibility_description")) == app.medal_progress.error
		and str(app._storage_retry_button.get("accessibility_description")) == app.medal_progress.error,
		"Reward retry controls retain the storage error as an accessible description")
	check(not app._single_result.retry_button.text.is_empty(), "Reward recovery keeps its visible action label")
	named([app._storage_retry_button], "Reward recovery")
	scan(app, "Reward save recovery")
	app.audio.halt()
	app.queue_free()
	await settle()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Hover tooltips: %d checks across %d states, %d failures" % [checks, scanned_states, failures])
	quit(1 if failures else 0)

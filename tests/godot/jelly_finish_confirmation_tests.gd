extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func action(app, name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	app._input(event)


func joy(app, button: int, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	app._input(event)


func pointer_button(button: Button, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)


func fresh_round(app, mode: String) -> void:
	check(app.new_round(731, false, "", mode, "", false), mode + ": a fresh round starts")
	app._active_jelly().set_process(false)
	app._active_jelly().game.spawn_interval = 10000.0
	app._active_jelly().game.step(2.0)


func open_dialog(app, context: String) -> void:
	var view = app._active_jelly()
	view.finish_button.accessibility_requested.emit()
	check(app._finish_confirmation_open() and view.game.phase == "playing" and view.game.paused
		and app._round_result.is_empty() and not app._jelly_interaction_allowed(),
		context + ": Finish pauses for a choice without committing a result")
	check(root.gui_get_focus_owner() == app._finish_confirmation.keep_playing_button,
		context + ": Keep playing owns the default focus")


func check_navigation(app, mode: String) -> void:
	var view = app._active_jelly()
	var round_id: String = app._round_id
	open_dialog(app, mode)
	var dialog = app._finish_confirmation
	check(dialog.keep_playing_button.text == "Keep playing" and dialog.finish_button.text == "Finish",
		mode + ": the choice has distinct continuation and finish actions")
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(320, 480), Vector2i(568, 320), Vector2i(1473, 1175)]:
		root.size = dimensions
		await settle()
		var bounds := Rect2(Vector2.ZERO, app.size)
		var scale: float = app.Style.ui_scale(app)
		for button: Button in [dialog.keep_playing_button, dialog.finish_button]:
			check(bounds.grow(0.1).encloses(button.get_global_rect()) and button.size.y * scale >= 43.75,
				mode + ": the action fits with a full touch target at " + str(dimensions))
		check(not dialog.keep_playing_button.get_global_rect().intersects(dialog.finish_button.get_global_rect()),
			mode + ": confirmation targets remain separate at " + str(dimensions))
	root.size = Vector2i(393, 852)
	await settle()
	app._controller_mode = true
	app._refresh()
	check(root.gui_get_focus_owner() == dialog.keep_playing_button and app._focus_candidates().size() == 2,
		mode + ": refresh cannot restore background focus or steal the default")
	action(app, "ui_focus_next")
	check(root.gui_get_focus_owner() == dialog.finish_button, mode + ": Tab reaches the explicit finish action")
	action(app, "ui_focus_next")
	check(root.gui_get_focus_owner() == dialog.keep_playing_button, mode + ": Tab wraps inside the dialog")
	action(app, "ui_focus_prev")
	check(root.gui_get_focus_owner() == dialog.finish_button, mode + ": Shift-Tab stays inside the dialog")
	dialog.keep_playing_button.grab_focus()
	var saved: Dictionary = view.game.snapshot()
	view.game.step(30.0)
	view.drop_button.pressed.emit()
	view.finish_button.accessibility_requested.emit()
	app._request_jelly_finish(mode)
	app._show_mode_menu()
	app._show_collection()
	for button in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		joy(app, button)
	check(view.game.snapshot() == saved and not app._mode_menu_open() and not app.collection_page.visible
		and app._round_id == round_id and app._finish_confirmation_focus_modes.size() > 0,
		mode + ": repeat requests, board input and navigation cannot escape or advance the paused round")
	joy(app, JOY_BUTTON_A)
	check(app._finish_confirmation_open(), mode + ": held controller accept cannot cross into the choice")
	joy(app, JOY_BUTTON_A, false)
	joy(app, JOY_BUTTON_A)
	check(not app._finish_confirmation_open() and not view.game.paused and app._round_id == round_id,
		mode + ": a fresh controller accept keeps playing the same round")
	view.game.step(0.2)
	check(view.game.spawn_elapsed > float(saved.spawn_elapsed), mode + ": continuing resumes the supply clock")
	open_dialog(app, mode + " Escape")
	action(app, "ui_cancel")
	check(not app._finish_confirmation_open() and not view.game.paused and not app._mode_menu_open(),
		mode + ": Escape returns directly to play")
	open_dialog(app, mode + " Back")
	joy(app, JOY_BUTTON_B)
	check(not app._finish_confirmation_open() and not view.game.paused and not app._mode_menu_open(),
		mode + ": controller Back returns directly to play")
	app._controller_mode = false


func check_lifecycle(app, mode: String) -> void:
	var view = app._active_jelly()
	app.set_reduced_motion(false)
	app._reward_confetti.burst("confirmation:" + app._round_id)
	app._sync_reward_confetti()
	open_dialog(app, mode + " interruption")
	var saved: Dictionary = view.game.snapshot()
	var confetti: Dictionary = app._reward_confetti.snapshot()
	var cloud_time: float = app._jelly_backdrop._elapsed
	app._advance_ui(2.0)
	await settle()
	check(confetti.paused and not confetti.visible and app._reward_confetti.snapshot().ages == confetti.ages,
		mode + ": paper freezes and stays below the choice")
	check(not app._jelly_backdrop.is_processing() and is_equal_approx(cloud_time, app._jelly_backdrop._elapsed),
		mode + ": scenery pauses with the game")
	app.on_page_hidden()
	app._finish_confirmation.finish_button.pressed.emit()
	app._finish_confirmation.keep_playing_button.pressed.emit()
	check(app._finish_confirmation_open() and view.game.snapshot() == saved,
		mode + ": hidden-page callbacks cannot finish or resume the game")
	app.on_page_visible()
	check(app._finish_confirmation_open() and view.game.paused,
		mode + ": foregrounding retains the pending choice and paused game")
	app._finish_confirmation.keep_playing_button.pressed.emit()
	check(not view.game.paused and app._reward_confetti.snapshot().visible,
		mode + ": Keep playing restores the earned paper tail and board")
	app.set_reduced_motion(true)
	open_dialog(app, mode + " stale generation")
	view._generation += 1
	app._finish_confirmation.finish_button.pressed.emit()
	check(not app._finish_confirmation_open() and view.game.phase == "playing" and not view.game.paused,
		mode + ": an obsolete view confirmation cannot finish its replacement")
	open_dialog(app, mode + " new round")
	var old_round: String = app._round_id
	fresh_round(app, mode)
	app._confirm_jelly_finish()
	check(not app._finish_confirmation_open() and app._round_id != old_round and view.game.phase == "playing" and not view.game.paused,
		mode + ": a new round dismisses the old choice and rejects its late confirm")
	app._request_jelly_finish("word_jelly" if mode == "jelly" else "jelly")
	check(not app._finish_confirmation_open(), mode + ": the hidden mode cannot request a confirmation")


func check_interrupted_confirmation_taps(app, mode: String) -> void:
	for interruption: String in ["component cancellation", "host input cancellation", "page hiding"]:
		fresh_round(app, mode)
		var view = app._active_jelly()
		open_dialog(app, mode + " " + interruption)
		await settle()
		var button: Button = app._finish_confirmation.finish_button
		var saved: Dictionary = view.game.snapshot()
		pointer_button(button, true)
		check(button.is_pressed() and view.game.snapshot() == saved and app._round_result.is_empty(),
			mode + ": " + interruption + " begins with an armed, uncommitted Finish press")
		match interruption:
			"component cancellation":
				app._finish_confirmation.cancel_input()
			"host input cancellation":
				app._on_input_canceled()
			"page hiding":
				app.on_page_hidden()
		check(not button.is_pressed() and not button.disabled,
			mode + ": " + interruption + " disarms Finish and preserves its enabled state")
		if interruption == "page hiding":
			app.on_page_visible()
		# Godot Web translates touchcancel into an ordinary release after the host callback.
		pointer_button(button, false)
		check(app._finish_confirmation_open() and view.game.snapshot() == saved and app._round_result.is_empty(),
			mode + ": " + interruption + " cannot turn a translated release into confirmation")
		pointer_button(button, true)
		check(view.game.snapshot() == saved and app._finish_confirmation_open(),
			mode + ": a fresh Finish tap after " + interruption + " still waits for release")
		pointer_button(button, false)
		check(view.game.phase == "finished" and not app._finish_confirmation_open() and not app._round_result.is_empty()
			and app._settlement_dialog.is_visible_in_tree() and not app._active_jelly().snapshot().result.visible,
			mode + ": a fresh ordinary tap after " + interruption + " confirms normally")


func start_merge(view) -> bool:
	for first: Dictionary in view.game.cells:
		for second: Dictionary in view.game.cells:
			if first.id == second.id or not view.game.is_settled(first) or not view.game.is_settled(second):
				continue
			var compatible: bool = false
			if view.game is WordJellyModel:
				compatible = not view.game.is_valid_word(first) and not view.game.is_valid_word(second) \
					and view.game.can_merge(first, second)
			else:
				compatible = first.word.id == second.word.id and first.kind != second.kind
			if compatible:
				first.chest = false
				second.chest = false
				if view.game is WordJellyModel:
					first.fragments = 0
					second.fragments = 0
				return view.game.try_merge(first.id, second.id) in ["correct", "merged"]
	return false


func check_fusion(app, mode: String) -> void:
	fresh_round(app, mode)
	var view = app._active_jelly()
	check(start_merge(view), mode + ": a real pair starts its merge")
	view.game.step(0.1)
	open_dialog(app, mode + " fusion")
	var pending: Array = view.game.fusions.duplicate(true)
	view.game.step(4.0)
	check(not pending.is_empty() and view.game.fusions == pending, mode + ": the pending fusion keeps its exact progress")
	app._finish_confirmation.keep_playing_button.pressed.emit()
	view.game.step(view.game.FUSION_SECONDS + 2.0)
	check(view.game.fusions.is_empty() and view.game.phase == "playing", mode + ": continuing completes the same merge")
	fresh_round(app, mode)
	check(start_merge(view), mode + ": another real pair starts before confirmation")
	view.game.step(0.1)
	var completions: Array = []
	var observe: Callable = func(result: Dictionary) -> void: completions.append(result)
	view.round_finished.connect(observe)
	open_dialog(app, mode + " confirmed fusion")
	app._finish_confirmation.finish_button.pressed.emit()
	app._finish_confirmation.finish_button.pressed.emit()
	view.finish_button.accessibility_requested.emit()
	check(view.game.phase == "finished" and not app._finish_confirmation_open() and completions.size() == 1,
		mode + ": an explicit confirmation commits exactly one result")
	check(int(app._round_result.cleared_pairs) == 0 and int(app._round_result.fragment_count) == 0,
		mode + ": confirming an unfinished merge cannot credit an unearned clear or fragment")
	view.round_finished.disconnect(observe)


func check_danger(app, mode: String) -> void:
	fresh_round(app, mode)
	var game = app._active_jelly().game
	game.spawn_interval = 3.0
	for beat in range(game.CAPACITY):
		if game.cells.size() == game.CAPACITY:
			break
		game.step(game.spawn_interval)
	game.step(2.0)
	check(game.phase == "playing" and game.full_elapsed >= 0.0, mode + ": real supply fills the board and starts danger")
	open_dialog(app, mode + " danger")
	var danger_time: float = game.full_elapsed
	game.step(game.FULL_SECONDS * 2.0)
	check(game.phase == "playing" and is_equal_approx(game.full_elapsed, danger_time),
		mode + ": the full-board deadline freezes while choosing")
	app._finish_confirmation.keep_playing_button.pressed.emit()
	game.step(game.FULL_SECONDS)
	check(game.phase == "finished" and not app._finish_confirmation_open() and not app._round_result.is_empty()
		and app._settlement_dialog.is_visible_in_tree() and not app._active_jelly().snapshot().result.visible,
		mode + ": automatic expiry still finishes directly after continuation")


func check_collection_batch(app) -> void:
	fresh_round(app, "word_jelly")
	Fixture.unlock_auto_collect(app)
	var view = app._word_jelly
	var word: Dictionary = app._learning_words().filter(func(candidate: Dictionary) -> bool:
		return str(candidate.text).length() >= 2 and str(candidate.text).length() <= 6 \
			and not str(candidate.get("image", "")).is_empty() and not view.game._reviewed_morphology(candidate))[0]
	check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, true, 731),
		"The batch fixture uses one real current-age word")
	app._sync_jelly()
	view.game.spawn_interval = 10000.0
	for tile: Dictionary in view.game.cells:
		tile.fragments = 0
		tile.chest = false
	for index in range(4):
		view.game.step(2.0)
		check(start_merge(view), "A real word merges for batch collection")
		view.game.step(view.game.FUSION_SECONDS + 2.0)
	var merged_ids: Array[int] = view.game.collectable_ids()
	check(merged_ids.size() == 4 and view.game.try_merge(merged_ids[0], merged_ids[1]) == "merged",
		"Two genuine Lv1 words upgrade to an eligible Lv2 collection")
	view.game.step(view.game.FUSION_SECONDS + 2.0)
	var ready: int = view.game.collectable_ids().size()
	# The batch contains one eligible Lv2 bonus and two Lv1 pickups that never roll.
	view.game._coin_rng.seed = 208
	check(ready == 3 and view.game.start_collection_batch(), "Collect begins the real three-word sequence")
	view.game.step(0.04)
	open_dialog(app, "word_jelly collection")
	var batch: Dictionary = view.game.collection_batch_snapshot()
	var fusions: Array = view.game.fusions.duplicate(true)
	var coins: int = app.coin_wallet.balance
	view.game.step(5.0)
	check(view.game.collection_batch_snapshot() == batch and view.game.fusions == fusions and app.coin_wallet.balance == coins,
		"The choice freezes the batch beat, in-flight word and wallet transaction")
	app._finish_confirmation.keep_playing_button.pressed.emit()
	view.game.step(2.0)
	check(not view.game.collection_batch_active() and int(view.game.collection_batch_snapshot().completed) == ready,
		"Keep playing completes the original reserved sequence")
	check(app.coin_wallet.balance == coins + 50 and view.game.collected_coins == 50,
		"Resuming preserves the rare bonus roll and collects ordinary words without extra coins")


func check_mode(mode: String) -> void:
	var directory := "user://jelly-finish-%s-%d-%d" % [mode, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_process(false)
	app._jelly.set_process(false)
	app._word_jelly.set_process(false)
	app.set_reduced_motion(true)
	Fixture.enter_mode(app, mode)
	fresh_round(app, mode)
	await check_navigation(app, mode)
	await check_lifecycle(app, mode)
	await check_interrupted_confirmation_taps(app, mode)
	check_fusion(app, mode)
	check_danger(app, mode)
	if mode == "word_jelly":
		check_collection_batch(app)
	app.audio.halt()
	app.free()
	await process_frame
	for filename: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	for mode: String in ["jelly", "word_jelly"]:
		await check_mode(mode)
	print("Jelly Finish confirmation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

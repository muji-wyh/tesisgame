extends SceneTree

class BrowserStorage:
	extends RefCounted
	var fail_read: bool = false
	var fail_write: bool = false
	var reads: int = 0
	var saved: String = "[medals]\nversion=1\ncounts={}\n"

	func medalProgress() -> Variant:
		reads += 1
		return false if fail_read else saved

	func saveMedalProgress(value: String) -> bool:
		if fail_write:
			return false
		saved = value
		return true

var checks: int = 0
var failures: int = 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _app(storage: BrowserStorage):
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg", storage)
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	return app

func _visible_retry(app) -> Button:
	for control in app.find_children("*", "Button", true, false):
		if control.is_visible_in_tree() and not control.disabled and control.text.begins_with("Retry"):
			return control
	return null

func _tap_control(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _win(app) -> void:
	if app._mode_id in ["sky", "listen"]:
		for answer in range(5):
			var index: int = 0 if app._choice.choices[0].id == app._choice.current_target.id else 1
			app._choice.answer_buttons[index].pressed.emit()
			app._choice.feedback_view.action_button.pressed.emit()
	elif app._mode_id == "memory":
		for word in app.model.lesson_words:
			for index in range(app._memory.memory.cards.size()):
				if app._memory.memory.cards[index].word.id == word.id:
					app._memory.card_buttons[index].pressed.emit()
			app._memory.feedback_view.action_button.pressed.emit()
	else:
		for card in app.model.cards:
			if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
				app.cards[card.id].pressed.emit()
				app.cards[card.word.id + ":image"].pressed.emit()
				app._match_feedback.action_button.pressed.emit()
	check(app.model.phase == "won" and app.model.chest_state == "closed", "A completed %s round has an unopened reward" % app._mode_id)

func _total(app) -> int:
	var count: int = 0
	for value in app.medal_progress.counts.values():
		count += value
	return count

func _run() -> void:
	directory = "user://ui-recovery-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var storage := BrowserStorage.new()
	storage.fail_read = true
	var app = await _app(storage)
	check(app._save_error and _visible_retry(app) != null, "Initial progress failure exposes a visible retry while Learn is open")
	for bounds in [Vector2i(480, 480), Vector2i(480, 960), Vector2i(960, 480)]:
		root.size = bounds
		await process_frame
		await process_frame
		var visible_retry := _visible_retry(app)
		check(visible_retry != null and Rect2(Vector2.ZERO, app.size).encloses(visible_retry.get_global_rect()), "Retry stays fully on screen at %s" % bounds)
		var reads: int = storage.reads
		if visible_retry != null:
			await _tap_control(visible_retry)
		check(storage.reads == reads + 1, "A real pointer click reaches Retry at %s" % bounds)
	check(not app._mode_buttons[1].disabled and not app._explore_button.disabled, "Unavailable progress does not disable practice or exploration")
	app._lesson.action_button.pressed.emit()
	check(app._mode_id == "match" and not app.cards.is_empty(), "Play Match remains usable after initial storage failure")
	app.choose_theme("ocean")
	check(app.model.theme_id == "ocean", "A progress read failure does not block choosing a practice theme")
	app.choose_mode("memory")
	check(app._mode_id == "memory", "Other practice modes remain available before progress recovers")
	if app._mode_id == "memory":
		app._memory.card_buttons[0].pressed.emit()
	var selection: Array = app._memory.memory.selected_indices.duplicate()
	storage.fail_read = false
	var retry := _visible_retry(app)
	if retry != null:
		await _tap_control(retry)
	check(app._progress_ready and not app._save_error, "The visible retry reloads reward progress after storage recovers")
	check(app._mode_id == "memory" and app._memory.memory.selected_indices == selection, "Retry preserves the active Memory attempt")
	app.queue_free()
	await process_frame

	storage = BrowserStorage.new()
	app = await _app(storage)
	for mode in ["match", "sky", "listen", "memory"]:
		for leave in ["repeat", "adventure"]:
			app.choose_mode(mode)
			_win(app)
			var before := _total(app)
			if leave == "repeat":
				app.replay_button.pressed.emit()
			else:
				app._new_adventure_button.pressed.emit()
				app._choose_adventure("animal-friends")
			check(_total(app) == before + 1, "%s after %s saves the unopened victory's piece" % [leave, mode])
			check(app.model.phase == "waiting", "Successful reward preservation allows %s" % leave)
			var persisted = load("res://scripts/medal_progress.gd").new(directory + "/reload.cfg", directory + "/legacy.cfg", storage)
			check(persisted.load_progress() and persisted.counts == app.medal_progress.counts, "The preserved victory survives reloading progress")
	app.choose_mode("memory")
	_win(app)
	var before := _total(app)
	var lesson: Array = app.model.lesson_words.duplicate(true)
	storage.fail_write = true
	app.choose_mode("learn")
	check(app._mode_id == "memory" and app.model.phase == "won", "A failed reward save keeps the winning mode instead of switching to Learn")
	check(app._save_error and not app._pending_fragment.is_empty() and _total(app) == before, "Failed departure retains one pending piece without inflating progress")
	check(not app._message.is_visible_in_tree(), "A saving error does not add duplicate text below the result actions")
	check(app.replay_button.tooltip_text == app.medal_progress.error, "Retry saving keeps the storage error available in its tooltip")
	app.replay_button.pressed.emit()
	app.new_round()
	check(app.model.phase == "won" and app.model.lesson_words == lesson and _total(app) == before, "Repeated failed retry and reset cannot discard the victory")
	storage.fail_write = false
	app.replay_button.pressed.emit()
	check(not app._save_error and _total(app) == before + 1, "Retry saves the captured piece exactly once")
	app.replay_button.pressed.emit()
	check(app.model.phase == "waiting" and app._mode_id == "memory" and _total(app) == before + 1, "Repeat starts only after saving and does not award another piece")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("UI recovery: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

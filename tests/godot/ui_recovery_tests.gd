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
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await process_frame
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
	if app._mode_id == "memory":
		for word in app.model.lesson_words:
			for index in range(app._memory.memory.cards.size()):
				if app._memory.memory.cards[index].word.id == word.id:
					app._memory.card_buttons[index].pressed.emit()
			app._memory.continue_feedback()
	else:
		for card in app.model.cards:
			if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
				app.cards[card.id].pressed.emit()
				app.cards[card.word.id + ":image"].pressed.emit()
				app._continue_match()
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
	check(app._mode_id == "match" and app._save_error and _visible_retry(app) != null,
		"Initial progress failure exposes a visible retry on the default Match board")
	for bounds in [Vector2i(480, 480), Vector2i(480, 960), Vector2i(960, 480)]:
		root.size = bounds
		await process_frame
		await process_frame
		var visible_retry := _visible_retry(app)
		check(visible_retry != null and Rect2(Vector2.ZERO, app.size).encloses(visible_retry.get_global_rect()), "Retry stays fully on screen at %s" % bounds)
		var reads: int = storage.reads
		var retry_rect: Rect2 = visible_retry.get_global_rect() if visible_retry != null else Rect2()
		var viewport_before: Rect2 = root.get_visible_rect()
		if visible_retry != null:
			await _tap_control(visible_retry)
		var overlapping: Array[String] = []
		if storage.reads != reads + 1:
			for control in app.find_children("*", "Control", true, false):
				if control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(retry_rect.get_center()):
					overlapping.append("%s %s z=%d focus=%d" % [control.name, control.get_global_rect(), control.z_index, control.focus_mode])
		check(storage.reads == reads + 1,
			"A real pointer click reaches Retry at %s: reads=%d -> %d rect=%s -> %s focus=%s viewport=%s -> %s hits=%s" % [
				bounds, reads, storage.reads, retry_rect,
				visible_retry.get_global_rect() if visible_retry != null else Rect2(), root.gui_get_focus_owner(),
				viewport_before, root.get_visible_rect(), overlapping])
	var learn_mode: Button = app.find_child("Mode_learn", true, false)
	var match_mode: Button = app.find_child("Mode_match", true, false)
	check(not learn_mode.disabled and not match_mode.disabled, "Unavailable progress does not disable practice or learning")
	learn_mode.pressed.emit()
	check(app._mode_id == "learn" and app._lesson.is_visible_in_tree(), "Learn remains explicitly available during a storage failure")
	match_mode.pressed.emit()
	check(app._mode_id == "match" and not app.cards.is_empty(), "The Match tab remains usable after initial storage failure")
	app.choose_theme("ocean")
	check(app.model.theme_id == "ocean", "A progress read failure does not block choosing a practice theme")
	app.choose_mode("memory")
	await process_frame
	await process_frame
	check(app._mode_id == "memory", "Other practice modes remain available before progress recovers")
	if app._mode_id == "memory":
		app._memory.card_buttons[0].pressed.emit()
	var selection: Array = app._memory.memory.selected_indices.duplicate()
	storage.fail_read = false
	var retry := _visible_retry(app)
	if retry != null:
		await _tap_control(retry)
	check(app._progress_ready and not app._save_error, "The visible retry reloads reward progress after storage recovers")
	check(app.theme_buttons.size() == 6 and app.theme_buttons.all(func(button: Button) -> bool: return is_instance_valid(button)),
		"Rebuilding recovered rewards replaces rather than duplicates the six world choices")
	check(app._mode_id == "memory" and app._memory.memory.selected_indices == selection, "Retry preserves the active Memory attempt")
	app.queue_free()
	await process_frame

	storage = BrowserStorage.new()
	app = await _app(storage)
	for mode in ["match", "memory"]:
		app.choose_mode(mode)
		_win(app)
		var before := _total(app)
		var completed_lesson: Array = app.model.lesson_words.duplicate(true)
		app._new_adventure_button.pressed.emit()
		check(_total(app) == before + 1, "New adventure after %s saves the unopened victory's piece" % mode)
		check(app.model.phase == "waiting" and app._mode_id == "learn" and app.model.lesson_words.size() == 5
			and app.model.lesson_words != completed_lesson and app.model.hints_remaining == 3,
			"Successful reward preservation starts a fresh five-word Learn lesson with three hints")
		var fresh_lesson: Array = app.model.lesson_words.duplicate(true)
		app._new_adventure_button.pressed.emit()
		check(app.model.lesson_words == fresh_lesson and _total(app) == before + 1,
			"A repeated hidden result click neither replaces the fresh lesson nor duplicates its saved piece")
		var persisted = load("res://scripts/medal_progress.gd").new(directory + "/reload.cfg", directory + "/legacy.cfg", storage)
		check(persisted.load_progress() and persisted.counts == app.medal_progress.counts, "The preserved victory survives reloading progress")
	app.choose_mode("memory")
	_win(app)
	var before := _total(app)
	var lesson: Array = app.model.lesson_words.duplicate(true)
	storage.fail_write = true
	app._new_adventure_button.pressed.emit()
	check(app._mode_id == "memory" and app.model.phase == "won", "A failed New adventure save keeps the winning mode instead of switching to Learn")
	check(app._save_error and not app._pending_fragment.is_empty() and _total(app) == before, "Failed departure retains one pending piece without inflating progress")
	check(not app._message.is_visible_in_tree(), "A saving error does not add duplicate text below the result actions")
	check(app._result_retry_button.is_visible_in_tree() and app._result_retry_button.text == "Retry saving"
		and not app._new_adventure_button.is_visible_in_tree() and app._default_focus() == app._result_retry_button,
		"A failed result exposes only the focused save-retry action")
	check(app._result_retry_button.tooltip_text == app.medal_progress.error, "Retry saving keeps the storage error available in its tooltip")
	app._result_retry_button.pressed.emit()
	app.choose_mode("learn")
	app.new_round()
	check(app.model.phase == "won" and app._mode_id == "memory" and app.model.lesson_words == lesson and _total(app) == before,
		"Repeated failed retry, mode changes, and direct resets cannot discard the victory")
	storage.fail_write = false
	app._result_retry_button.pressed.emit()
	check(not app._save_error and _total(app) == before + 1 and app.model.phase == "won"
		and app._mode_id == "memory" and app.model.lesson_words == lesson,
		"Retry saves the captured piece exactly once without restarting the completed lesson")
	app._result_retry_button.pressed.emit()
	app._retry_reward_save()
	check(app.model.phase == "won" and app.model.lesson_words == lesson and _total(app) == before + 1,
		"Stale save retries cannot behave like the removed Repeat lesson feature")
	check(app._new_adventure_button.is_visible_in_tree() and not app._result_retry_button.is_visible_in_tree()
		and app._default_focus() == app._new_adventure_button,
		"Successful saving restores New adventure as the normal result action")
	app._new_adventure_button.pressed.emit()
	check(app.model.phase == "waiting" and app._mode_id == "learn" and app.model.lesson_words != lesson
		and _total(app) == before + 1, "Only New adventure starts fresh learning after saving, without another piece")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("UI recovery: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

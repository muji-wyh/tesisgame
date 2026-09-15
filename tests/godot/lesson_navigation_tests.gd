extends SceneTree

var checks := 0
var failures := 0

class BrowserStorage extends RefCounted:
	var text: Variant = null
	var writable := true
	var readable := true
	func playroomState() -> Variant:
		return text if readable else false
	func savePlayroomState(value: String) -> bool:
		if not writable:
			return false
		text = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var directory := "user://lesson-navigation-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.choose_mode("learn")
	check(app.find_child("Explore", true, false) == null and app.find_child("AdventureBook", true, false) == null,
		"Explore and its hidden picker are removed")
	app._lesson._move(1)
	var lesson: Array = app.model.lesson_words.duplicate(true)
	var current_word: String = app._lesson.current_word.id
	app.collection_button.grab_focus()
	app._show_collection()
	app._lesson._move(1)
	app.choose_mode("match")
	check(app._mode_id == "learn" and app._lesson.current_word.id == current_word, "More pauses the current lesson")
	app._controller_back()
	check(app.model.lesson_words == lesson and app._lesson.current_word.id == current_word, "Back preserves the lesson and current card")
	check(root.gui_get_focus_owner() == app.collection_button, "Back restores More focus")
	app._new_adventure_button.pressed.emit()
	check(app.model.lesson_words == lesson, "An invisible result action cannot replace the current lesson")
	app.choose_theme("space")
	app.model.phase = "lost"
	app._refresh()
	app._new_adventure_button.pressed.emit()
	check(app._mode_id == "learn" and app._lesson.is_visible_in_tree() and not app.collection_page.visible,
		"New adventure starts Learn directly")
	check(app.model.lesson_words != lesson and app.model.theme_id == "space", "A new lesson changes the words but preserves the world")
	lesson = app.model.lesson_words.duplicate(true)
	app._new_adventure_button.pressed.emit()
	check(app.model.lesson_words == lesson, "A repeated result click cannot start another lesson")
	check(app.model.successes == 0 and app.model.hints_remaining == 3 and app.medal_progress.counts.is_empty(),
		"Starting a lesson grants no rewards and initializes a normal attempt")
	var storage := BrowserStorage.new()
	var state = load("res://scripts/playroom_state.gd").new(directory + "/mock.cfg", storage)
	check(state.load_state(), "The isolated saved-choice fixture loads")
	app.playroom_state = state
	app._playroom_ready = true
	storage.writable = false
	app.new_round(-1, false, "space-trip", "learn")
	check(app._journey_save_failed and state.recent_topic_ids.is_empty(), "Failed writes do not fabricate remembered visits")
	check(app._storage_retry_button.visible and app._status_announcement.contains("Retry saving"),
		"Removing Explore leaves a visible retry for saved-choice failures")
	app._lesson._move(1)
	current_word = app._lesson.current_word.id
	lesson = app.model.lesson_words.duplicate(true)
	storage.writable = true
	app._storage_retry_button.pressed.emit()
	check(not app._journey_save_failed and state.recent_topic_ids == ["space-trip"], "Retry saves the pending visit")
	check(app.model.lesson_words == lesson and app._lesson.current_word.id == current_word, "Retry never restarts learning")
	check(not app._storage_retry_button.visible and state.preferred_theme_id == "space", "Recovery keeps the selected world and clears the retry")
	storage.readable = false
	app.playroom_state = load("res://scripts/playroom_state.gd").new(directory + "/retry.cfg", storage)
	app._playroom_ready = false
	app._preferred_theme = ""
	app._pending_visit_id = "music-makers"
	app._save_journey()
	check(app._journey_save_failed, "Unavailable saved choices stay explicit")
	storage.readable = true
	app._storage_retry_button.pressed.emit()
	check(not app._journey_save_failed and app._preferred_theme == "space"
		and app.playroom_state.recent_topic_ids[0] == "music-makers", "Retry recovers prior choices and the pending visit")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Lesson navigation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

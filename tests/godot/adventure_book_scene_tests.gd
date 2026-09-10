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
	var app = load("res://scenes/main.tscn").instantiate()
	var directory := "user://adventure-book-scene-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app._explore_button.is_visible_in_tree(), "Learn exposes adventure choice without shifting the playfield")
	check(app.playroom_state.recent_topic_ids.has(app.model.adventure_id), "Starting Learn records an honest visit")
	app._lesson.next_button.pressed.emit()
	var lesson: Array = app.model.lesson_words.duplicate(true)
	var current_word: String = app._lesson.word_label.text
	app._explore_button.grab_focus()
	app._explore_button.pressed.emit()
	await process_frame
	check(app.collection_page.visible and app._adventure_book.is_visible_in_tree(), "Explore opens the book inside the collection modal")
	check(not app._room.is_visible_in_tree() and not app.duck.visible, "The book keeps room content and its mascot out of the way")
	app._lesson.next_button.pressed.emit()
	app.choose_mode("sky")
	var world: String = app.model.theme_id
	app.choose_theme("space" if world != "space" else "spring")
	check(app._mode_id == "learn" and app.model.theme_id == world, "Covered mode and world controls cannot change the attempt")
	check(app._lesson.word_label.text == current_word, "Covered lesson controls are paused")
	for control in app._focus_candidates():
		check(app.collection_page.is_ancestor_of(control), "Focus remains inside the book")
	app._controller_back()
	check(app.model.lesson_words == lesson and app._lesson.word_label.text == current_word, "Back preserves the lesson and current card")
	check(root.gui_get_focus_owner() == app._explore_button, "Back restores the opener focus")
	app.choose_theme("space")
	app._show_adventures()
	app._collection_dragged = true
	app._adventure_book.buttons["animal-friends"].pressed.emit()
	check(app.collection_page.visible and app.model.lesson_words == lesson, "A swipe ending on a card never selects it")
	app._collection_dragged = false
	app._adventure_book.buttons["animal-friends"].pressed.emit()
	check(not app.collection_page.visible and app._mode_id == "learn", "A destination starts Learn")
	check(app.model.adventure_id == "animal-friends" and app.model.theme_id == "space", "The chosen topic preserves the preferred reward world")
	check(app.playroom_state.recent_topic_ids[0] == "animal-friends", "A selected destination becomes the latest confirmed visit")
	lesson = app.model.lesson_words.duplicate(true)
	app.choose_mode("sky")
	check(app.model.lesson_words == lesson and app.model.adventure_id == "animal-friends", "Practice modes preserve the destination lesson")
	app._choice._choose(0)
	var answer_phase: String = app._choice.status
	app._show_adventures()
	app._choice.continue_feedback()
	check(app._choice.status == answer_phase, "Opening the book pauses choice feedback")
	app._hide_collection()
	app._choice.continue_feedback()
	check(app._choice.status != answer_phase, "Closing the book resumes choice feedback")
	app._save_error = true
	app._pending_fragment = {"medal_id": "space-1"}
	app._show_adventures()
	check(not app.collection_page.visible and app.model.lesson_words == lesson, "An unsaved earned fragment blocks destination changes")
	app._save_error = false
	app._pending_fragment.clear()
	app._show_collection()
	check(app._room.is_visible_in_tree() and not app._adventure_book.is_visible_in_tree(), "Rewards still opens the playable room")
	app._hide_collection()
	var storage := BrowserStorage.new()
	var state = load("res://scripts/playroom_state.gd").new(directory + "/mock.cfg", storage)
	check(state.load_state(), "The journey storage fixture loads")
	app.playroom_state = state
	app._playroom_ready = true
	storage.writable = false
	app._show_adventures()
	app._choose_adventure("space-trip")
	check(app.model.adventure_id == "space-trip" and app._lesson.is_visible_in_tree(), "A failed visit save still starts the chosen lesson")
	check(app._journey_save_failed and state.recent_topic_ids.is_empty(), "Failed visits never fabricate remembered history")
	app._show_adventures()
	check(app._adventure_book.retry_button.is_visible_in_tree(), "The book exposes a save retry")
	storage.writable = true
	app._adventure_book.retry_button.pressed.emit()
	check(not app._journey_save_failed and state.recent_topic_ids == ["space-trip"], "Retry remembers the pending visit")
	check(state.preferred_theme_id == "space", "Retry also preserves the chosen reward world")
	app._hide_collection()
	storage.readable = false
	app.playroom_state = load("res://scripts/playroom_state.gd").new(directory + "/retry.cfg", storage)
	app._playroom_ready = false
	app._preferred_theme = ""
	app._pending_visit_id = "space-trip"
	app._save_journey()
	check(app._journey_save_failed, "Unavailable saved choices expose retry without overwriting them")
	storage.readable = true
	app._show_adventures()
	app._retry_journey()
	check(app._preferred_theme == "space", "Retry deterministically recovers the saved preference")
	app._choose_adventure("music-makers")
	check(app.model.theme_id == "space", "Recovered world preference survives the next destination after a failed initial read")
	app.model.phase = "lost"
	app._refresh()
	app._new_adventure_button.pressed.emit()
	check(app._adventures_open, "New adventure on results opens the book")
	app._adventure_book.surprise_button.pressed.emit()
	check(app._mode_id == "learn" and not app.collection_page.visible, "Surprise me begins a new Learn adventure")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Adventure book scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

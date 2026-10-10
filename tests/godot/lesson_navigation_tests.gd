extends SceneTree

var checks := 0
var failures := 0

class BrowserStorage extends RefCounted:
	var text: Variant = null
	var writable := true
	var readable := true
	func growthState() -> Variant:
		return text if readable else false
	func saveGrowthState(value: String, expected_text: Variant) -> bool:
		if not writable or text != expected_text:
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
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.choose_mode("match")
	check(app.find_child("Explore", true, false) == null and app.find_child("AdventureBook", true, false) == null,
		"Explore and its hidden picker are removed")
	app.cards[app.model.cards[0].id].pressed.emit()
	var lesson: Array = app.model.lesson_words.duplicate(true)
	var selected_id: String = app.model.selected_id
	app.collection_button.grab_focus()
	app._show_collection()
	app.cards[app.model.cards[1].id].pressed.emit()
	app.choose_mode("memory")
	check(app._mode_id == "match" and app.model.selected_id == selected_id, "More pauses the current Match attempt")
	app._controller_back()
	check(app.model.lesson_words == lesson and app.model.selected_id == selected_id, "Back preserves the vocabulary and selected card")
	check(root.gui_get_focus_owner() == app.collection_button, "Back restores More focus")
	app._new_adventure_button.pressed.emit()
	check(app.model.lesson_words == lesson, "An invisible result action cannot replace the current lesson")
	app.choose_theme("space")
	# This fixture exercises an earned chest; chance outcomes have separate coverage.
	app.model.chest_earned = true
	app.model.phase = "won"
	app.model.chest_state = "opened"
	app._refresh()
	app._new_adventure_button.pressed.emit()
	check(app._mode_id == "match" and app.grid.is_visible_in_tree() and not app.collection_page.visible,
		"New adventure starts Match directly")
	check(app.model.lesson_words != lesson and app.model.theme_id == "space", "A new lesson changes the words but preserves the world")
	lesson = app.model.lesson_words.duplicate(true)
	app._new_adventure_button.pressed.emit()
	check(app.model.lesson_words == lesson, "A repeated result click cannot start another lesson")
	check((app.model.matched_ids.size() / 2) == 0 and app.model.hints_remaining == 3 and app.medal_progress.counts.is_empty(),
		"Starting a lesson grants no rewards and initializes a normal attempt")
	var storage := BrowserStorage.new()
	var state = load("res://scripts/growth_state.gd").new(directory + "/mock.cfg", storage)
	check(state.configure(app.data.words) and state.load_state(), "The isolated growth fixture loads")
	app.growth = state
	storage.writable = false
	app._record_growth("pending-navigation", ["cat"], true)
	app._refresh()
	check(app._growth_save_failed and state.streak("cat") == 0 and state.snapshot().pending_count == 1,
		"Failed writes retain one pending attempt without presenting it as durable mastery")
	check(app._storage_retry_button.visible, "A failed growth write leaves a visible retry action")
	app.cards[app.model.cards[0].id].pressed.emit()
	selected_id = app.model.selected_id
	lesson = app.model.lesson_words.duplicate(true)
	storage.writable = true
	app._storage_retry_button.pressed.emit()
	check(not app._growth_save_failed and state.streak("cat") == 1,
		"Retry saves the pending learning attempt once")
	check(app.model.lesson_words == lesson and app.model.selected_id == selected_id,
		"Retry never restarts the active Match attempt")
	check(not app._storage_retry_button.visible, "Successful recovery clears the retry action")
	storage.readable = false
	app.growth = load("res://scripts/growth_state.gd").new(directory + "/retry.cfg", storage)
	app.growth.configure(app.data.words)
	app._growth_save_failed = not app.growth.load_state()
	app._refresh()
	check(app._growth_save_failed, "Unavailable learning progress stays explicit")
	storage.readable = true
	app._storage_retry_button.pressed.emit()
	check(not app._growth_save_failed and app.growth.streak("cat") == 1,
		"Retry recovers earlier learning progress without losing a saved attempt")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Lesson navigation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

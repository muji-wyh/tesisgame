extends SceneTree

var checks := 0
var failures := 0

class BrowserStorage extends RefCounted:
	var text: Variant = null
	var writable := true
	func playroomState() -> Variant:
		return text
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
	var directory := "user://gift-adventure-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.has_method("_start_gift_adventure"), "A chosen gift connects to an actual learning adventure")
	if app.has_method("_start_gift_adventure"):
		await _exercise(app, directory)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Gift adventure: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _exercise(app, directory: String) -> void:
	var entries := [
		["spring", "great-outdoors", "flower"], ["summer", "play-time", "ball"],
		["autumn", "picnic-time", "apple"], ["winter", "music-makers", "bell"],
		["ocean", "ocean-discovery", "shell"], ["space", "space-trip", "rocket"],
		["jungle", "animal-friends", "monkey"], ["candy", "picnic-time", "cake"]]
	var original_counts: Dictionary = app.medal_progress.counts.duplicate(true)
	var before_words: Array = app.model.lesson_words.duplicate(true)
	app._start_gift_adventure("toy-space")
	check(app.model.lesson_words == before_words and app.playroom_state.goal_item_id.is_empty(), "Hidden room requests cannot start or save a goal")
	for entry in entries:
		app._show_collection()
		app._room.item_buttons["toy-" + entry[0]].pressed.emit()
		check(app._room.goal_button.is_visible_in_tree(), "Locked " + entry[0] + " has an actionable goal")
		app._room.goal_button.pressed.emit()
		check(not app.collection_page.visible and app._mode_id == "match" and app.grid.is_visible_in_tree(), "Choosing a gift starts its Match board")
		check(app.model.theme_id == entry[0] and app.model.adventure_id == entry[1], "Gift selects its reward world and related topic")
		check(app.model.lesson_words.size() == 5 and app.model.lesson_words.any(func(word: Dictionary) -> bool: return word.id == entry[2]), "The lesson contains the desired toy's noun")
		check(app.playroom_state.goal_item_id == "toy-" + entry[0], "The chosen gift persists")
		check(app._gift_label.text.contains(app.playroom_state.selected_goal(app.medal_progress.counts).name), "The medal goal names the player's chosen gift")
		var lesson: Array = app.model.lesson_words.duplicate(true)
		for mode in ["memory", "pop", "match"]:
			app.choose_mode(mode)
			check(app.model.lesson_words == lesson, "Gift words remain identical in " + mode)
	check(app.medal_progress.counts == original_counts and app.playroom_state.toy_id == "toy-ball", "Selecting goals and learning never grant or equip locked gifts")
	app.choose_theme("spring")
	check(app._gift_label.text.contains("Candy"), "Playing another world still identifies where the goal is earned")
	app._show_collection()
	app._collection_dragged = true
	var original_goal: String = app.playroom_state.goal_item_id
	app._start_gift_adventure("toy-autumn")
	check(app.collection_page.visible and app.playroom_state.goal_item_id == original_goal, "Swipe releases cannot start a gift adventure")
	app._collection_dragged = false
	app._show_reward_section("medals")
	app._start_gift_adventure("toy-autumn")
	check(app.playroom_state.goal_item_id == original_goal, "Covered room controls cannot start a goal")
	app._show_reward_section("room")
	app.model.phase = "won"
	app.model.chest_state = "closed"
	app._start_gift_adventure("toy-autumn")
	check(app.collection_page.visible and app.model.chest_state == "closed" and app.playroom_state.goal_item_id == original_goal, "An unopened earned chest is preserved")
	check(app._status_announcement.to_lower().contains("chest"), "The player is told how to collect the waiting reward")
	check(_card_message(app, "toy-autumn").contains("Open your chest first"), "The waiting chest guidance appears on the toy card")
	app.model.phase = "waiting"
	app._save_error = true
	app._pending_fragment = {"medal_id": "space-1"}
	app._start_gift_adventure("toy-autumn")
	check(app.collection_page.visible and app.playroom_state.goal_item_id == original_goal, "An unsaved reward cannot be discarded by a goal")
	check(_card_message(app, "toy-autumn").contains("Save your reward first"), "Pending-save guidance appears on the toy card")
	app._save_error = false
	app._pending_fragment.clear()
	var storage := BrowserStorage.new()
	storage.text = FileAccess.get_file_as_string(directory + "/room-v2.cfg")
	var state = load("res://scripts/playroom_state.gd").new(directory + "/mock.cfg", storage)
	check(state.load_state(), "Load isolated goal-save failure fixture")
	app.playroom_state = state
	app._playroom_ready = true
	app._refresh_collection()
	storage.writable = false
	before_words = app.model.lesson_words.duplicate(true)
	app._start_gift_adventure("toy-autumn")
	check(app.collection_page.visible and app.model.lesson_words == before_words and state.goal_item_id == original_goal, "Failed goal saves retain the lesson and previous choice")
	check(app._status_announcement.to_lower().contains("save"), "Failed goal save has accessible retry guidance")
	check(_card_message(app, "toy-autumn").contains("Not saved"), "Goal-save failure appears on its card")
	storage.writable = true
	app._start_gift_adventure("toy-autumn")
	check(not app.collection_page.visible and state.goal_item_id == "toy-autumn", "Retry starts and saves the same selected gift")
	app.medal_progress.counts["autumn-1"] = 2
	app._refresh()
	check(state.selected_goal(app.medal_progress.counts).remaining_pieces == 1, "Only one ordinary piece remains before the toy unlock")
	_win_match_and_open(app)
	check(app.medal_progress.count_for("autumn-1") == 3, "The normal chest grants exactly the final piece")
	check(state.selected_goal(app.medal_progress.counts).remaining_pieces == 0 and app._try_gift_button.visible, "The completed goal exposes the existing Try gift action")
	app._try_gift_button.pressed.emit()
	check(app._room.is_visible_in_tree() and state.toy_id == "toy-autumn", "Try gift saves and equips the earned toy in Pip's room")
	var earned: Dictionary = app.medal_progress.counts.duplicate(true)
	var stickers: Array = state.collected_word_ids.duplicate()
	for step in range(4):
		app._room.toy_button.pressed.emit()
	check(app.medal_progress.counts == earned and state.collected_word_ids == stickers, "Playing and replaying a toy does not duplicate rewards or stickers")
	var reloaded = load("res://scripts/playroom_state.gd").new(directory + "/reload.cfg", storage)
	check(reloaded.load_state() and reloaded.goal_item_id == "toy-autumn" and reloaded.toy_id == "toy-autumn", "Immediate reload keeps the completed goal and toy")
	app._room.configure(reloaded, earned, load("res://scripts/game_data.gd").theme("autumn"), true)
	check(app._room.goal_button.is_visible_in_tree(), "A completed saved goal remains playable after reload")
	app._room.configure(reloaded, earned, load("res://scripts/game_data.gd").theme("autumn"), false)
	app._room.toy_button.pressed.emit()
	check(app._room.is_processing(), "Animated toy action starts during visible play")
	app.on_page_hidden()
	check(not app._room.is_processing(), "Browser lifecycle settles a running toy action")
	_test_completed_goal_use(app, directory, storage, "toy-autumn", "toy-ball")
	app._hide_collection()
	app.medal_progress.counts["autumn-3"] = 3
	check(app.playroom_state.select_item("backdrop-autumn", app.medal_progress.counts),
		"Seed an earned backdrop through the retained compatibility state API")
	check(app.playroom_state.set_goal("backdrop-space", app.medal_progress.counts),
		"Seed a previously saved backdrop goal without exposing a new UI route")
	app._show_collection()
	app._show_reward_section("room")
	app._refresh()
	check(app._room._room.theme_id == "autumn" and app.playroom_state.backdrop_id == "backdrop-autumn",
		"The existing saved backdrop still renders after removing Rooms")
	check(not app._room.goal_button.is_visible_in_tree()
		and not app._room.goal_label.text.contains(app.playroom_state.item("backdrop-space").name)
		and not app._gift_label.text.contains(app.playroom_state.item("backdrop-space").name),
		"Pip and the reward guide do not market or resume an old backdrop goal")
	check(app.playroom_state.selected_goal(app.medal_progress.counts).id == "backdrop-space",
		"Ignoring a legacy goal in the UI never erases its saved value")
	var before_backdrops: Dictionary = app.medal_progress.counts.duplicate(true)
	var before_stickers: Array = app.playroom_state.collected_word_ids.duplicate()
	var before_lesson: Array = app.model.lesson_words.duplicate(true)
	var before_mode: String = app._mode_id
	var before_room_bytes: String = storage.text
	for entry in entries:
		var id: String = "backdrop-" + entry[0]
		check(not app._room.item_buttons.has(id), "The toy-only view creates no hidden " + entry[0] + " backdrop button")
		app._start_gift_adventure(id)
		check(app.collection_page.visible and app._mode_id == before_mode and app.model.lesson_words == before_lesson
			and app.playroom_state.goal_item_id == "backdrop-space" and storage.text == before_room_bytes,
			"Rejecting a " + entry[0] + " backdrop request performs no write, mode change, or lesson reset")
	check(app.medal_progress.counts == before_backdrops and app.playroom_state.collected_word_ids == before_stickers
		and app.playroom_state.backdrop_id == "backdrop-autumn",
		"Removed backdrop requests cannot award progress, mutate legacy words, or replace the saved room")
	app._hide_collection()
	app.medal_progress.counts["space-1"] = 3
	app.medal_progress.counts["space-2"] = 3
	app.medal_progress.counts["space-3"] = 2
	app.choose_theme("space")
	check(app.playroom_state.selected_goal(app.medal_progress.counts).remaining_pieces == 1,
		"The compatibility reader still understands an old backdrop goal's remaining piece")
	var expected_counts: Dictionary = app.medal_progress.counts.duplicate(true)
	expected_counts["space-3"] = 3
	_win_match_and_open(app)
	check(app.medal_progress.counts == expected_counts and app.playroom_state.selected_goal(app.medal_progress.counts).remaining_pieces == 0,
		"A real Match still grants exactly one ordinary third-medal piece")
	check(not app._try_gift_button.visible and app._unlocked_gift.is_empty(),
		"Finishing a legacy backdrop requirement creates no new room-gift CTA")
	check(app.playroom_state.backdrop_id == "backdrop-autumn", "An earned third medal never auto-equips a new backdrop")
	app._show_collection()
	app._room.item_buttons["toy-winter"].pressed.emit()
	app._room.goal_button.pressed.emit()
	check(app._mode_id == "match" and app.playroom_state.goal_item_id == "toy-winter"
		and app.playroom_state.backdrop_id == "backdrop-autumn",
		"A real toy goal can replace the ignored legacy goal while preserving the chosen backdrop")
	var confirmed = load("res://scripts/playroom_state.gd").new(directory + "/legacy-backdrop-confirmed.cfg", storage)
	check(confirmed.load_state() and confirmed.backdrop_id == "backdrop-autumn" and confirmed.goal_item_id == "toy-winter"
		and confirmed.collected_word_ids == before_stickers,
		"Toy-goal, world, history and reward operations preserve the saved backdrop and words through reload")


func _win_match_and_open(app) -> void:
	app.choose_mode("match")
	for word in app.model.lesson_words:
		if app.model.card_by_id(word.id + ":word").is_empty() or app.model.card_by_id(word.id + ":image").is_empty():
			continue
		app._select_card(word.id + ":word")
		app._select_card(word.id + ":image")
		app._continue_match()
	check(app.model.phase == "won", "The goal is earned through the real Match input flow")
	app._open_chest()
	app.chest.finish_immediately()


func _test_completed_goal_use(app, directory: String, storage: BrowserStorage, goal_id: String, starter_id: String) -> void:
	var gift: Dictionary = app.playroom_state.item(goal_id)
	check(gift.slot == "toy", "Completed gift actions are scoped to toys")
	app._room.item_buttons[starter_id].pressed.emit()
	var previous_toy: String = app.playroom_state.toy_id
	var previous_backdrop: String = app.playroom_state.backdrop_id
	check(previous_toy == starter_id and app.playroom_state.goal_item_id == goal_id, "Equip another toy while retaining the completed goal")
	var reloaded = load("res://scripts/playroom_state.gd").new(directory + "/reload-" + goal_id + ".cfg", storage)
	check(reloaded.load_state() and reloaded.goal_item_id == goal_id, "Reload the completed goal with different equipment")
	app.playroom_state = reloaded
	app._playroom_ready = true
	app._refresh_collection()
	check(app._room.goal_button.is_visible_in_tree() and app._room.goal_button.tooltip_text.begins_with("Use toy"), "The reloaded completed goal has a real use button")
	var saved_bytes: String = storage.text
	var counts: Dictionary = app.medal_progress.counts.duplicate(true)
	var stickers: Array = reloaded.collected_word_ids.duplicate()
	var lesson: Array = app.model.lesson_words.duplicate(true)
	var room_theme: String = app._room._room.theme_id
	storage.writable = false
	app._room.goal_button.pressed.emit()
	check(reloaded.toy_id == previous_toy and reloaded.backdrop_id == previous_backdrop and storage.text == saved_bytes, "Failed completed-goal equipment saves preserve both room choices and committed bytes")
	check(app.collection_page.visible and app._room._toy.id == previous_toy and app._room._room.theme_id == room_theme
		and _card_message(app, goal_id).contains("Not saved"), "Failed completed-goal use keeps the prior visible room and explains the save failure on its card")
	check(app._room.goal_button.is_visible_in_tree() and not app._room.goal_button.disabled, "The failed completed-goal use can retry through the same button")
	storage.writable = true
	app._room.goal_button.pressed.emit()
	check(reloaded.toy_id == goal_id and reloaded.backdrop_id == previous_backdrop,
		"Retrying the completed toy-goal button preserves the existing backdrop")
	check(app._room._toy.id == reloaded.toy_id and app._room._room.theme_id == ("home" if reloaded.backdrop_id == "backdrop-home" else reloaded.item(reloaded.backdrop_id).theme), "Successful retry updates the actual room to the equipped gift")
	app._room.goal_button.pressed.emit()
	check(app.medal_progress.counts == counts and reloaded.collected_word_ids == stickers and app.model.lesson_words == lesson and reloaded.goal_item_id == goal_id, "Repeated completed-goal use preserves the lesson and cannot duplicate rewards or stickers")
	var confirmed = load("res://scripts/playroom_state.gd").new(directory + "/confirmed-" + goal_id + ".cfg", storage)
	check(confirmed.load_state() and confirmed.toy_id == reloaded.toy_id and confirmed.backdrop_id == reloaded.backdrop_id and confirmed.goal_item_id == goal_id, "The equipment chosen through the completed-goal button survives another reload")


func _card_message(app, id: String) -> String:
	var text := ""
	for label in app._room.item_buttons[id].find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			text += label.text + "\n"
	return text

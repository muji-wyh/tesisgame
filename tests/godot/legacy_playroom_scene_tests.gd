extends SceneTree

const State = preload("res://scripts/playroom_state.gd")
const LEGACY_IDS := ["cat", "bell"]

var checks := 0
var failures := 0
var state_path: String

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
	var directory := "user://legacy-playroom-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	state_path = directory + "/room-v2.cfg"
	var legacy = State.new(state_path)
	var ids: Array[String] = ["cat", "bell"]
	check(legacy.load_state() and legacy.collect_words(ids) and legacy.display_word("bell"),
		"The fixture starts with a previously saved collection and displayed word")
	check(legacy.select_item("backdrop-spring", {"spring-3": 3}),
		"The compatibility state API seeds a previously saved backdrop without a Rooms chooser")
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.medal_progress.counts["spring-3"] = 3
	app._refresh_collection()
	var initial_medals: Dictionary = app.medal_progress.counts.duplicate()
	check(app._room._room.theme_id == "spring", "A saved and earned backdrop still renders in Pip's room")
	app.choose_mode("learn")
	check(not app.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "_word_book")
		and not app.has_method("_collect_word_stickers") and not app._room.has_method("set_word_sticker"),
		"The removed Words UI and runtime collection/display handlers are not retained invisibly")
	_check_legacy(app, "Loading the old room and starting Learn")
	app._lesson._move(1)
	app._lesson._move(-1)
	_check_legacy(app, "Browsing Learn")

	app.choose_mode("match")
	var pairs: Array = _pairs(app)
	app.cards[pairs[0].id + ":word"].pressed.emit()
	app.cards[pairs[1].id + ":image"].pressed.emit()
	check(app.model.mistakes == 1, "The legacy fixture still grades an ordinary wrong Match")
	app._continue_match()
	for word in pairs:
		app.cards[word.id + ":word"].pressed.emit()
		app.cards[word.id + ":image"].pressed.emit()
		app.cards[word.id + ":image"].pressed.emit()
		_check_legacy(app, "Correct Match and matched-card replay for " + word.id)
		app._continue_match()
	check(app.model.phase == "won" and app.model.successes == 3 and app.medal_progress.counts == initial_medals,
		"Matching still wins normally without collecting words or claiming unopened medals")
	app._open_chest()
	app.chest.finish_immediately()
	check(app.medal_progress.count_for(app.model.theme_id + "-1") == 1,
		"The normal chest still awards exactly one medal piece")
	_check_legacy(app, "Collecting a medal piece")
	check(app.new_round(-1, true), "A same-lesson internal reset prepares the Memory fixture")
	app.choose_mode("memory")
	var memory = app._memory
	memory.study_button.button_down.emit()
	check(memory.memory.studying, "The remaining Memory eye still starts a held peek")
	memory.study_button.button_up.emit()
	check(not memory.memory.studying, "Releasing the eye ends the peek")
	_check_legacy(app, "Holding and releasing Memory's eye")
	for word in app.model.lesson_words:
		for index in range(memory.memory.cards.size()):
			if memory.memory.cards[index].word.id == word.id:
				memory.card_buttons[index].pressed.emit()
		memory.continue_feedback()
	check(app.model.phase == "won" and app.model.successes == 5, "All five Memory pairs still complete the game")
	_check_legacy(app, "Completing every Memory pair")
	app.new_round(333, false, "music-makers", "match")
	var spoken_words: Array = _pairs(app).filter(func(word: Dictionary) -> bool: return not LEGACY_IDS.has(word.id))
	check(not spoken_words.is_empty(), "The speech fixture uses a word absent from the legacy collection")
	app._on_voice_state([true, true, "Listening"])
	app._on_voice_result([spoken_words[0].text, true])
	check(app.model.successes == 1 and app.model.phase == "feedback", "Spoken Match still grades its real target")
	app._stop_voice()
	app._continue_match()
	_check_legacy(app, "Spoken Match")

	app.medal_progress.counts["spring-1"] = 3
	app.medal_progress.counts["spring-3"] = 3
	app._show_collection()
	check(app._collection_tabs.keys() == ["room", "medals"] and app.theme_buttons.size() == 8
		and app.theme_buttons.all(func(button: Button) -> bool: return button.is_visible_in_tree()),
		"Removing Words and Rooms preserves Pip, Medals, and every World choice")
	app._show_reward_section("room")
	app._room.item_buttons["toy-spring"].pressed.emit()
	check(app.playroom_state.toy_id == "toy-spring" and app.playroom_state.backdrop_id == "backdrop-spring",
		"Saving an owned toy preserves the existing backdrop without a hidden backdrop control")
	check(not app._room.item_buttons.has("backdrop-spring") and app._room._room.theme_id == "spring",
		"The saved backdrop remains visible as artwork, not an available chooser")
	_check_legacy(app, "Saving a toy choice")
	app._show_reward_section("medals")
	app._open_reward_preview("spring-1")
	app._wear_preview_reward()
	check(app.playroom_state.favorite_id == "spring-1", "The earned medal still saves as Pip's favorite")
	_check_legacy(app, "Saving a favorite medal")
	app._hide_reward_preview()
	app._show_reward_section("room")
	app._room.item_buttons["toy-space"].pressed.emit()
	app._room.goal_button.pressed.emit()
	check(app.playroom_state.goal_item_id == "toy-space" and app._mode_id == "learn" and not app.collection_page.visible,
		"A locked gift still saves a goal and starts its related lesson")
	_check_legacy(app, "Saving a gift goal, preferred world, and lesson visit")

	var native_bytes := FileAccess.get_file_as_string(state_path)
	var storage := BrowserStorage.new()
	storage.text = native_bytes
	app.playroom_state = State.new(state_path, storage)
	app._playroom_ready = app.playroom_state.load_state()
	check(app._playroom_ready, "The same legacy record can be loaded through browser storage")
	app._show_collection()
	app._show_reward_section("room")
	var previous_toy: String = app.playroom_state.toy_id
	storage.writable = false
	app._room.item_buttons["toy-ball"].pressed.emit()
	check(app.playroom_state.toy_id == previous_toy and storage.text == native_bytes,
		"A failed room write preserves the prior choice and every committed byte")
	check(app._room.item_buttons["toy-ball"].tooltip_text.to_lower().contains("save")
		and app._room._item_labels["toy-ball"].text.contains("Not saved"),
		"Failed room saves retain retry guidance on the selected card")
	_check_legacy(app, "A failed browser room save", storage)
	storage.writable = true
	app._room.item_buttons["toy-ball"].pressed.emit()
	check(app.playroom_state.toy_id == "toy-ball", "The same room control retries successfully")
	_check_legacy(app, "Retrying the browser room save", storage)
	app._show_reward_section("medals")
	app.theme_buttons[app.model.THEMES.find("ocean")].pressed.emit()
	check(app.playroom_state.preferred_theme_id == "ocean" and app.collection_page.visible
		and app._collection_section == "medals",
		"A world card saves the preference without leaving Medals")
	_check_legacy(app, "Saving a world through the redesigned menu", storage)
	app._hide_collection()
	check(FileAccess.get_file_as_string(state_path) == native_bytes,
		"Browser writes leave the original native legacy record untouched")

	var saved_bytes: String = storage.text
	storage.readable = false
	app._playroom_ready = false
	app._pending_visit_id = "music-makers"
	app._save_journey()
	check(app._journey_save_failed and storage.text == saved_bytes,
		"A failed read cannot overwrite saved choices or legacy fields")
	check(app.playroom_state.collected_word_ids == LEGACY_IDS and app.playroom_state.displayed_word_id == "bell"
		and app.playroom_state.backdrop_id == "backdrop-spring",
		"A failed read retains the last confirmed word and backdrop fields in memory")
	app._lesson._move(1)
	var word_before: String = app._lesson.current_word.id
	var lesson_before: Array = app.model.lesson_words.duplicate(true)
	storage.readable = true
	app._storage_retry_button.pressed.emit()
	check(not app._journey_save_failed and app.playroom_state.recent_topic_ids[0] == "music-makers",
		"The ordinary storage retry recovers the pending visit")
	check(app._lesson.current_word.id == word_before and app.model.lesson_words == lesson_before,
		"Recovering the legacy record never restarts the current lesson")
	_check_legacy(app, "Recovering a read and saving the pending visit", storage)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Legacy playroom scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _pairs(app) -> Array:
	return app.model.lesson_words.filter(func(word: Dictionary) -> bool:
		return not app.model.card_by_id(word.id + ":word").is_empty() and not app.model.card_by_id(word.id + ":image").is_empty())


func _check_legacy(app, context: String, storage: BrowserStorage = null) -> void:
	check(app.playroom_state.collected_word_ids == LEGACY_IDS and app.playroom_state.displayed_word_id == "bell"
		and app.playroom_state.backdrop_id == "backdrop-spring",
		context + " preserves saved word data and the existing backdrop")
	var restored = State.new(state_path, storage)
	check(restored.load_state() and restored.collected_word_ids == LEGACY_IDS and restored.displayed_word_id == "bell"
		and restored.backdrop_id == "backdrop-spring",
		context + " preserves legacy word and backdrop fields through a fresh storage reload")

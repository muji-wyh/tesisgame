extends SceneTree

const Progress = preload("res://scripts/medal_progress.gd")
const State = preload("res://scripts/playroom_state.gd")

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
	for frame in range(8):
		await process_frame


func check_no_medals_ui(app) -> void:
	check(app.find_child("Rewards_medals", true, false) == null
		and app.find_child("RewardPreview", true, false) == null,
		"Medals navigation and its preview page are absent from the scene")
	for route in ["_show_reward_section", "_open_reward_preview", "_wear_preview_reward", "_build_reward_preview_shell"]:
		check(not app.has_method(route), "A retired route cannot reopen Medals: " + route)
	check(not app.get_property_list().any(func(property: Dictionary) -> bool:
		return property.name in ["_reward_slots", "_collection_shelves", "_next_goal", "_collection_tabs"]),
		"Retired medal shelves and the next-medal goal are not retained invisibly")
	check(app.find_child("PipsRoomTitle", true, false) is Label
		and app._collection_title.text == "Pip" and app._collection_title.focus_mode == Control.FOCUS_NONE,
		"More has one clear room title without a redundant navigation tab")
	check(not app.collection_button.tooltip_text.to_lower().contains("medal"),
		"More's accessible entry no longer advertises Medals")


func win(app) -> void:
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app.cards[card.id].pressed.emit()
			app.cards[card.word.id + ":image"].pressed.emit()
			app.feedback_timer.timeout.emit()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	var directory := "user://medals-removal-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create an isolated saved-player fixture")
	var progress = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	check(progress.load_progress(), "Existing fragment progress can load")
	for piece in range(2):
		check(progress.claim(progress.next_fragment("spring")), "Seed an existing partial reward")
	var legacy := ConfigFile.new()
	legacy.set_value("playroom", "favorite", "spring-1")
	check(legacy.save(directory + "/room.cfg") == OK, "Seed an existing favorite display")
	var legacy_bytes := FileAccess.get_file_as_string(directory + "/room.cfg")
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = progress
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check_no_medals_ui(app)
	var initial_counts: Dictionary = app.medal_progress.counts.duplicate()
	var cards: Array = app.model.cards.duplicate(true)
	var focus: Control = app._default_focus()
	focus.grab_focus()
	app.collection_button.pressed.emit()
	await settle()
	check(app.collection_page.visible and app._room.is_visible_in_tree(), "More opens Pip's room directly")
	check(app._status_announcement.begins_with("Pip's room opened.")
		and not app._status_announcement.to_lower().contains("medal"),
		"Room guidance describes toys and settings without a retired Medals destination")
	check(app._playroom_medal.is_visible_in_tree() and app._favorite_reward_id == "spring-1"
		and app._playroom_medal.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"An existing favorite remains a static display without opening a medal browser")
	for dimensions in [Vector2i(320, 568), Vector2i(768, 1024), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		check(app._collection_title.is_visible_in_tree() and app._collection_back.is_visible_in_tree(),
			"The room title and Back remain available at " + str(dimensions))
		for button in app.theme_buttons:
			check(button.is_visible_in_tree() and app.get_global_rect().grow(0.5).encloses(button.get_global_rect()),
				"World choices remain visible inside the viewport at " + str(dimensions))
	root.size = Vector2i(480, 480)
	await settle()
	app._collection_scroll.scroll_vertical = app._collection_max_scroll().y
	await settle()
	var scroll_before: int = app._collection_scroll.scroll_vertical
	check(not app._collection_scroll.get_global_rect().intersects(app.duck.get_global_rect()),
		"The focus regression starts with Pip fully scrolled out of view")
	app.duck.grab_focus()
	await settle()
	check(app.duck.has_focus() and app._collection_scroll.scroll_vertical < scroll_before
		and app._collection_scroll.get_global_rect().encloses(app.duck.get_global_rect()),
		"Keyboard focus reveals Pip after deferred layout and keeps focus on the duck")
	check(app._collection_duck_slot.global_position.y - 16 >= app._collection_scroll.global_position.y,
		"The focused duck also retains room for its jumping head")
	app._choose_world("ocean")
	app._choose_age_band("4-6")
	check(app.collection_page.visible and app.model.theme_id == "ocean"
		and app.playroom_state.age_band_id == "4-6" and app.model.cards == cards,
		"World and age selection preserve the active round and keep the room open")
	app._play_duck()
	check(app.duck.home_playground, "Pip retains room interaction after Medals is removed")
	check(app.medal_progress.counts == initial_counts, "Room visits do not reset existing fragment progress")
	app._collection_back.grab_focus()
	app._controller_accept()
	check(not app.collection_page.visible and focus.has_focus(), "Controller Back returns to the previous game control")
	check(FileAccess.get_file_as_string(directory + "/room.cfg") == legacy_bytes,
		"Viewing and changing room settings preserves the original favorite save")
	app._show_collection()
	app._controller_back()
	check(not app.collection_page.visible and focus.has_focus(), "Controller cancel closes More without a hidden intermediate page")
	app.new_round(24)
	app.choose_theme("spring")
	win(app)
	check(app.model.phase == "won" and app.model.chest_state == "closed", "Winning still offers the reward chest")
	app._open_chest()
	app.chest.finish_immediately()
	check(app.medal_progress.count_for("spring-1") == 3 and app.reward_image.pieces == 3,
		"The chest still saves and displays the next earned fragment")
	check(app._unlocked_gift.get("id", "") == "toy-spring" and app._try_gift_button.visible,
		"Completing the existing reward unlocks its toy and offers Try it with Pip")
	app._try_gift_button.pressed.emit()
	await settle()
	check(app.collection_page.visible and app.playroom_state.toy_id == "toy-spring"
		and app._room.playground != null, "The newly unlocked toy opens and plays in Pip's room")
	check_no_medals_ui(app)
	app._build_collection()
	await settle()
	check_no_medals_ui(app)
	var restored = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	check(restored.load_progress() and restored.count_for("spring-1") == 3,
		"Earned fragments survive a normal persisted reload")
	var room = State.new(directory + "/room-v2.cfg")
	check(room.load_state() and room.toy_id == "toy-spring" and room.favorite_id == "spring-1",
		"Toy selection and the old favorite both survive a saved-room reload")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Medals removal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

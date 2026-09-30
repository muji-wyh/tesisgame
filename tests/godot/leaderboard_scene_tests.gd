extends SceneTree

const State = preload("res://scripts/leaderboard_state.gd")

var checks: int = 0
var failures: int = 0


class BrowserStorage extends RefCounted:

	var text: Variant = null
	var writable: bool = true
	var writes: int = 0

	func leaderboardState() -> Variant:
		return text

	func saveLeaderboardState(value: String) -> bool:
		if not writable:
			return false
		writes += 1
		text = value
		return true


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


func action(panel: Node, control_name: String) -> Button:
	return panel.find_child(control_name, true, false) as Button


func check_review_modal_touch(app, mode: String) -> void:
	var rail = app._found_words_scroll
	check(not rail.interaction_allowed.call(),
		"The covered %s review rail cannot consume leaderboard form touches" % mode)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = rail.get_global_rect().get_center()
	rail._input(touch)
	check(rail._pointer == -1 and rail._touches.is_empty(),
		"A touch over the covered %s review rail does not begin an underlying drag" % mode)


func _run() -> void:
	var directory := "user://leaderboard-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated integration save directory")
	var storage := BrowserStorage.new()
	var state := State.new(directory + "/leaderboards.cfg", storage)
	check(state.load_state(), "Load isolated local player state")
	var created: Dictionary = state.create_profile("Avery", "fox")
	check(created.ok, "Create the first local player")
	var avery: String = str(created.profile.id)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	app.leaderboard_state = state
	root.size = Vector2i(960, 720)
	root.add_child(app)
	await settle()
	app.set_reduced_motion(true)
	await _check_menu(app, state)
	await _check_pop(app, state, storage, avery)
	await _check_match(app, state, avery)
	await _check_memory(app, state, avery)
	await _check_long_rise(app)
	app.audio.halt()
	app.queue_free()
	await settle()
	for filename in DirAccess.get_files_at(directory):
		check(DirAccess.remove_absolute(directory + "/" + filename) == OK, "Remove isolated integration save file")
	check(DirAccess.remove_absolute(directory) == OK, "Remove isolated integration save directory")
	print("Leaderboard scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_menu(app, state) -> void:
	app._show_collection()
	app._players_button.grab_focus()
	app._players_button.pressed.emit()
	await settle()
	check(app._leaderboard_overlay.visible and app.collection_page.visible, "Players opens above the existing menu")
	check(not app.duck.is_visible_in_tree(), "Pip cannot cover or intercept the modal's player form")
	check(not app._room.interaction_allowed.call(), "The hidden playground cannot intercept player form input")
	for rail in app._collection_rails():
		check(not rail.interaction_allowed.call(), "Every covered menu rail ignores modal gestures: " + str(rail.name))
	check(root.gui_get_focus_owner() == app._leaderboard_close and app._leaderboard_close.focus_mode != Control.FOCUS_NONE,
		"The nested modal has a keyboard-accessible Back action")
	for candidate in app._focus_candidates():
		check(app._leaderboard_overlay.is_ancestor_of(candidate), "Player modal fences keyboard and controller focus")
	var panel = app._leaderboard_panel
	var create_button: Button = action(panel, "LeaderboardCreatePlayer")
	check(create_button.disabled, "A blank name cannot create a profile")
	action(panel, "LeaderboardAvatar_cat").pressed.emit()
	var name_field := panel.find_child("LeaderboardName", true, false) as LineEdit
	name_field.text = "Blake"
	name_field.text_changed.emit(name_field.text)
	create_button.pressed.emit()
	await settle()
	check(state.profiles.size() == 2 and state.profiles[1].name == "Blake" and state.profiles[1].avatar == "cat",
		"The menu saves the chosen name and emoji through its real controls")
	for dimensions in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(960, 720)]:
		root.size = dimensions
		await settle()
		var current: Dictionary = app.leaderboard_snapshot()
		for control in current.controls:
			var rect: Array = control.rect
			check(float(rect[0]) >= -1 and float(rect[0]) + float(rect[2]) <= app.size.x + 1,
				"Player controls fit horizontally at %s: %s" % [dimensions, control.name])
	app._controller_back()
	check(not app._leaderboard_overlay.visible and app.collection_page.visible,
		"Back closes only the player modal")
	check(root.gui_get_focus_owner() == app._players_button, "Closing the modal restores its menu action focus")
	app._leaderboards_button.pressed.emit()
	await settle()
	for mode in ["pop", "match", "memory"]:
		action(app._leaderboard_panel, "LeaderboardMode_" + mode).pressed.emit()
		await settle()
		check(app.leaderboard_snapshot().mode == mode and app.leaderboard_snapshot().rows.is_empty(),
			"The menu shows a separate empty %s board without inventing a score" % mode)
	app._controller_back()
	app._hide_collection()
	await settle()


func _check_pop(app, state, storage, player_id: String) -> void:
	app.choose_mode("pop")
	await settle()
	app._pop.set_listening(true, true, "Listening")
	check(app._pop.game.phase == "running", "Voice Pop begins before result attribution exists")
	var round_id: String = app._leaderboard_round_id
	app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
	check(app._pop.game.hits == 1, "The fixture earns a real spoken hit")
	app._pop._advance_game(60.0)
	await settle()
	var panel = app._pop_leaderboard
	check(is_instance_valid(panel) and panel.is_visible_in_tree(), "Voice Pop attaches player choice to completed results")
	check(panel.get_index() == 2 and app._pop.replay_button.is_visible_in_tree(),
		"Attribution sits after the hit total and Play again, before the word lists")
	check(state.board("pop").is_empty() and state.round_submission(round_id).is_empty(),
		"Finishing alone does not assign a score")
	app._pop_finished(app._pop.game.summary())
	check(app._pop_leaderboard == panel, "Duplicate finish callbacks cannot build another chooser")
	check(action(panel, "LeaderboardSaveScore").disabled, "A player must explicitly be selected")
	action(panel, "LeaderboardPlayer_" + player_id).pressed.emit()
	action(panel, "LeaderboardAddPlayer").pressed.emit()
	var draft := panel.find_child("LeaderboardName", true, false) as LineEdit
	draft.text = "Unfinished draft"
	draft.text_changed.emit(draft.text)
	app._show_collection()
	await settle()
	check(not app._pop.is_visible_in_tree() and not app._valid_focus(draft)
		and draft.focus_mode == Control.FOCUS_NONE,
		"Opening the menu hides the result form and fences its unfinished text input")
	app._players_button.pressed.emit()
	await settle()
	var menu_name := app._leaderboard_panel.find_child("LeaderboardName", true, false) as LineEdit
	menu_name.text = "Casey"
	menu_name.text_changed.emit(menu_name.text)
	action(app._leaderboard_panel, "LeaderboardAvatar_bear").pressed.emit()
	action(app._leaderboard_panel, "LeaderboardCreatePlayer").pressed.emit()
	await settle()
	var casey: String = str(state.profiles.back().id)
	check(state.profiles.size() == 3 and state.profiles.back().name == "Casey", "Players adds a new identity while a Pop result is pending")
	app._controller_back()
	app._hide_collection()
	await settle()
	var returned: Dictionary = panel.snapshot()
	var returned_draft := panel.find_child("LeaderboardName", true, false) as LineEdit
	check(app._pop_leaderboard == panel and action(panel, "LeaderboardPlayer_" + casey) != null,
		"Returning from the menu refreshes the existing Pop chooser with the new player")
	check(returned.round_id == round_id and returned.selected_player == player_id and not returned.submitted
		and returned_draft != null and returned_draft.text == "Unfinished draft",
		"Refreshing players preserves pending round identity, chosen player and unfinished draft")
	check(state.board("pop").is_empty() and state.profiles.all(func(profile: Dictionary) -> bool: return profile.name != "Unfinished draft"),
		"Returning to the round does not save its score or an unfinished profile")
	storage.writable = false
	var bytes_before: String = str(storage.text)
	action(panel, "LeaderboardSaveScore").pressed.emit()
	check(not panel.snapshot().submitted and not panel.snapshot().error.is_empty()
		and storage.text == bytes_before and not panel.snapshot().animation.active,
		"Failed persistence keeps the round available without celebrating or modifying storage")
	storage.writable = true
	var writes_before: int = storage.writes
	action(panel, "LeaderboardSaveScore").pressed.emit()
	await settle()
	check(panel.snapshot().submitted and state.board("pop")[0].metric == 1 and state.round_submission(round_id).player_id == player_id,
		"Retry saves the actual hit total for the selected player")
	check(not panel.snapshot().animation.active, "Reduced motion shows the saved rank without a moving celebration")
	panel._save_score()
	check(storage.writes == writes_before + 1, "Repeated submission cannot write or reward the same round twice")
	check(action(panel, "LeaderboardSaveScore") == null, "Saved results no longer offer score reassignment")
	app._show_collection()
	app._leaderboards_button.pressed.emit()
	await settle()
	check(app.leaderboard_snapshot().rows.size() == 1 and not app.leaderboard_snapshot().animation.active,
		"Reopening the saved board does not replay the celebration")
	app._controller_back()
	app._hide_collection()
	app._configure_pop(32)
	await settle()
	check(app._leaderboard_round_id != round_id and app._leaderboard_result.is_empty(),
		"A new Voice Pop round gets a new identity and clears pending attribution")
	check(not app.leaderboard_snapshot().visible and state.board("pop")[0].metric == 1,
		"Replaying hides previous round attribution while retaining the personal best")
	app.choose_mode("match")
	await settle()


func _check_match(app, state, player_id: String) -> void:
	app.new_round(42, true)
	await settle()
	app._request_hint()
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app._select_card(card.id)
			app._select_card(card.word.id + ":image")
			app._continue_match()
	await settle()
	check(app.model.phase == "won" and app._result_board_button.is_visible_in_tree(), "A completed Match round offers leaderboard attribution")
	var round_id: String = app._leaderboard_round_id
	var reward_before: Dictionary = app.medal_progress.counts.duplicate(true)
	app._result_board_button.pressed.emit()
	await settle()
	check(app.leaderboard_snapshot().mode == "match" and app.leaderboard_snapshot().round_id == round_id,
		"Match opens the current completed result")
	check_review_modal_touch(app, "Match")
	action(app._leaderboard_panel, "LeaderboardPlayer_" + player_id).pressed.emit()
	action(app._leaderboard_panel, "LeaderboardSaveScore").pressed.emit()
	await settle()
	check(state.board("match").size() == 1 and state.board("match")[0].result == {"won": true, "mistakes": 0, "hints_used": 1},
		"Match ranks the completed round's misses and consumed hints")
	check(app.model.chest_state == "closed" and app.medal_progress.counts == reward_before,
		"Leaderboard submission does not open a chest or duplicate its reward")
	app._controller_back()
	app.choose_mode("memory")
	await settle()


func _check_memory(app, state, player_id: String) -> void:
	check(app._mode_id == "memory", "The next mode starts after the existing chest completion flow")
	var memory = app._memory
	memory.begin_peek()
	memory.end_peek()
	for index in range(memory.memory.cards.size()):
		var card: Dictionary = memory.memory.cards[index]
		if card.kind != "word":
			continue
		var picture: int = -1
		for other in range(memory.memory.cards.size()):
			if memory.memory.cards[other].word.id == card.word.id and memory.memory.cards[other].kind == "image":
				picture = other
		memory.card_buttons[index].pressed.emit()
		memory.card_buttons[picture].pressed.emit()
		memory.continue_feedback()
	await settle()
	check(app.model.phase == "won" and memory.memory.attempts == 5 and memory.memory.peeks == 1,
		"Memory completes five actual pairs and counts the earlier peek")
	app._result_board_button.pressed.emit()
	await settle()
	check_review_modal_touch(app, "Memory")
	action(app._leaderboard_panel, "LeaderboardPlayer_" + player_id).pressed.emit()
	action(app._leaderboard_panel, "LeaderboardSaveScore").pressed.emit()
	await settle()
	check(state.board("memory").size() == 1 and state.board("memory")[0].result == {"won": true, "attempts": 5, "peeks": 1},
		"Memory submits completed turns and peeks into its own board")
	for mode in ["pop", "match", "memory"]:
		action(app._leaderboard_panel, "LeaderboardMode_" + mode).pressed.emit()
		await settle()
		check(app.leaderboard_snapshot().mode == mode and app.leaderboard_snapshot().rows.size() == 1,
			"Saved results can browse the independent %s board" % mode)
	app._controller_back()


func _check_long_rise(app) -> void:
	var storage := BrowserStorage.new()
	var state := State.new("user://unused-long-rank-rise.cfg", storage)
	check(state.load_state(), "Load an isolated ten-player rise fixture")
	var rising_id: String = ""
	for index in range(10):
		var created: Dictionary = state.create_profile("Player %d" % (index + 1), State.AVATARS[index])
		var id: String = created.get("profile", {}).get("id", "")
		check(created.ok and state.submit_round("round-seed-%d" % index, "pop", id, {"hits": 10 - index}).ok,
			"Seed player %d with a distinct personal best" % (index + 1))
		rising_id = id
	root.size = Vector2i(844, 390)
	# Isolate the board animation from the previous Memory victory's mascot pose.
	app.duck.settle()
	app.set_reduced_motion(false)
	app._show_leaderboard("boards", false)
	app._leaderboard_panel.configure(state, "boards", "pop", "round-long-rise", {"hits": 20}, false)
	await settle()
	var panel = app._leaderboard_panel
	check(state.board("pop")[9].player_id == rising_id and state.board("pop")[9].rank == 10,
		"The promoted player begins in tenth place")
	action(panel, "LeaderboardPlayer_" + rising_id).pressed.emit()
	action(panel, "LeaderboardSaveScore").pressed.emit()
	await settle()
	var writes_after_save: int = storage.writes
	var samples: int = 0
	var first_local_y: float = -1.0
	var last_local_y: float = -1.0
	var clip: ScrollContainer = panel.get_parent()
	for frame in range(90):
		var current: Dictionary = panel.snapshot()
		if not current.animation.active:
			break
		var row: Control = panel._row_nodes[rising_id]
		if first_local_y < 0:
			first_local_y = row.position.y
		last_local_y = row.position.y
		samples += 1
		check(clip.get_global_rect().grow(1).encloses(row.get_global_rect()),
			"A ten-to-first rise keeps the complete avatar/name row visible in short landscape: %s inside %s" % [row.get_global_rect(), clip.get_global_rect()])
		await create_timer(0.03).timeout
	check(samples >= 4 and first_local_y > last_local_y,
		"The tenth player's real row travels upward through multiple visible frames")
	check(not panel.snapshot().animation.active and is_zero_approx(panel._row_nodes[rising_id].position.y),
		"The promoted row settles in the first display position")
	check(state.board("pop")[0].player_id == rising_id and state.board("pop")[1].rank == 2,
		"The improved personal best displaces the previous leader")
	app.on_page_hidden()
	app.on_page_visible()
	await settle()
	check(not panel.snapshot().animation.active and storage.writes == writes_after_save,
		"Returning from the background does not replay promotion or save the round again")
	app._controller_back()

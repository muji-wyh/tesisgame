extends SceneTree

const State = preload("res://scripts/leaderboard_state.gd")

var checks: int = 0
var failures: int = 0


class BrowserStorage extends RefCounted:

	var text: Variant = null
	var writable: bool = true
	var readable: bool = true
	var writes: int = 0

	func leaderboardState() -> Variant:
		return text if readable else false

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
	await _check_onboarding(directory)
	await _check_onboarding_recovery(directory)
	await _check_picker_actions(directory)
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


func _check_onboarding(directory: String) -> void:
	var storage := BrowserStorage.new()
	var state := State.new(directory + "/onboarding.cfg", storage)
	check(state.load_state(), "Load an empty first-visit player store")
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/onboarding-medals.cfg", directory + "/onboarding-legacy.cfg")
	app.playroom_save_path = directory + "/onboarding-room.cfg"
	app.leaderboard_state = state
	root.add_child(app)
	await settle()
	var lesson: Array = app.model.cards.duplicate(true)
	paused = true
	app._on_loading_finished(["summer"])
	await settle()
	check(not paused and app._leaderboard_overlay.visible and app._leaderboard_gate == "onboarding",
		"Leaving loading requires a first player before exposing gameplay")
	check(app.leaderboard_snapshot().view == "onboarding" and not app._leaderboard_close.is_visible_in_tree(),
		"First-visit creation has no skip or Back action")
	check(app.model.theme_id == "summer" and app.model.cards == lesson,
		"Onboarding retains the loading theme and the prepared adventure")
	app._controller_back()
	app.choose_mode("pop")
	check(app._leaderboard_overlay.visible and app._leaderboard_gate == "onboarding" and app._mode_id == "match",
		"Back and a covered mode action cannot bypass mandatory creation")
	var panel = app._leaderboard_panel
	var name_field := panel.find_child("LeaderboardName", true, false) as LineEdit
	check(action(panel, "LeaderboardCreatePlayer").disabled, "The first player still requires a valid name")
	action(panel, "LeaderboardAvatar_panda").pressed.emit()
	name_field.text = "River"
	name_field.text_changed.emit(name_field.text)
	storage.writable = false
	action(panel, "LeaderboardCreatePlayer").pressed.emit()
	await settle()
	check(state.profiles.is_empty() and app._leaderboard_gate == "onboarding" and app._leaderboard_overlay.visible,
		"A failed profile save keeps the first-visit gate open")
	check(not panel.snapshot().error.is_empty(), "First-visit persistence failure gives a retryable error")
	storage.writable = true
	action(panel, "LeaderboardCreatePlayer").pressed.emit()
	await settle()
	check(state.profiles.size() == 1 and state.profiles[0].name == "River" and state.profiles[0].avatar == "panda",
		"The first profile durably stores the selected emoji and name")
	check(not app._leaderboard_overlay.visible and app._leaderboard_gate.is_empty() and app._mode_id == "match",
		"Successful first-player creation continues directly into the prepared game")
	app._on_loading_finished(["winter"])
	check(not app._leaderboard_overlay.visible and state.profiles.size() == 1 and app.model.theme_id == "summer",
		"A repeated loading callback cannot reopen creation or add another player")
	app.audio.halt()
	app.queue_free()
	await settle()
	var returning = load("res://scenes/main.tscn").instantiate()
	returning.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/returning-medals.cfg", directory + "/returning-legacy.cfg")
	returning.playroom_save_path = directory + "/returning-room.cfg"
	returning.leaderboard_state = State.new(directory + "/onboarding.cfg", storage)
	root.add_child(returning)
	await settle()
	returning._on_loading_finished([])
	check(not returning._leaderboard_overlay.visible and returning.leaderboard_state.profiles.size() == 1,
		"A later visit with a stored player goes straight from loading into the game")
	returning.audio.halt()
	returning.queue_free()
	await settle()


func _check_onboarding_recovery(directory: String) -> void:
	for count in [1, 10]:
		var storage := BrowserStorage.new()
		var seed := State.new(directory + "/recovery-seed.cfg", storage)
		check(seed.load_state(), "Create a recoverable browser player store")
		for index in range(count):
			check(seed.create_profile("Player %d" % (index + 1), State.AVATARS[index]).ok,
				"Seed recovered player %d of %d" % [index + 1, count])
		var writes_before: int = storage.writes
		var bytes_before: String = str(storage.text)
		storage.readable = false
		var app = load("res://scenes/main.tscn").instantiate()
		app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/recovery-medals-%d.cfg" % count, directory + "/recovery-legacy-%d.cfg" % count)
		app.playroom_save_path = directory + "/recovery-room-%d.cfg" % count
		app.leaderboard_state = State.new(directory + "/recovery.cfg", storage)
		root.add_child(app)
		await settle()
		app._on_loading_finished([])
		await settle()
		check(app._leaderboard_gate == "onboarding" and app._leaderboard_overlay.visible
			and action(app._leaderboard_panel, "LeaderboardRetryLoad") != null,
			"An unreadable player store gates loading with a visible retry")
		check(action(app._leaderboard_panel, "LeaderboardCreatePlayer") == null,
			"Storage errors cannot masquerade as an empty store and create duplicate players")
		action(app._leaderboard_panel, "LeaderboardRetryLoad").pressed.emit()
		await settle()
		check(app._leaderboard_gate == "onboarding" and not app.leaderboard_state.ready,
			"An unsuccessful read retry keeps mandatory onboarding open")
		storage.readable = true
		action(app._leaderboard_panel, "LeaderboardRetryLoad").pressed.emit()
		await settle()
		check(not app._leaderboard_overlay.visible and app._leaderboard_gate.is_empty()
			and app.leaderboard_state.ready and app.leaderboard_state.profiles.size() == count,
			"Recovering %d saved players continues directly without asking for another profile" % count)
		check(storage.writes == writes_before and storage.text == bytes_before,
			"Onboarding recovery preserves every stored player without rewriting the record")
		app.audio.halt()
		app.queue_free()
		await settle()
	var storage := BrowserStorage.new()
	var state := State.new(directory + "/stale-onboarding.cfg", storage)
	check(state.load_state() and state.create_profile("Existing player", "fox").ok,
		"Seed a returning player for deferred-confirmation coverage")
	var panel = load("res://scripts/leaderboard_panel.gd").new()
	var confirmations: Array[String] = []
	root.add_child(panel)
	panel.player_confirmed.connect(func(id: String) -> void: confirmations.append(id))
	panel.configure(state, "onboarding")
	panel.configure(state, "picker")
	await settle()
	check(confirmations.is_empty() and panel.snapshot().view == "picker" and not panel.snapshot().confirmed,
		"A deferred onboarding recovery cannot confirm a reconfigured player picker")
	panel.configure(state, "onboarding")
	await settle()
	check(confirmations.size() == 1 and confirmations[0] == str(state.profiles[0].id),
		"The current onboarding recovery confirms an existing durable profile exactly once")
	panel.queue_free()
	await settle()


func _check_picker_actions(directory: String) -> void:
	var storage := BrowserStorage.new()
	var state := State.new(directory + "/picker-actions.cfg", storage)
	check(state.load_state() and state.create_profile("First player", "fox").ok,
		"Seed a saved player for direct picker actions")
	var first_id: String = str(state.profiles[0].id)
	var panel = load("res://scripts/leaderboard_panel.gd").new()
	var confirmations: Array[String] = []
	root.add_child(panel)
	panel.player_confirmed.connect(func(id: String) -> void: confirmations.append(id))
	panel.configure(state, "picker")
	await settle()
	var stale_choice := action(panel, "LeaderboardPlayer_" + first_id)
	action(panel, "LeaderboardAddPlayer").pressed.emit()
	stale_choice.pressed.emit()
	check(confirmations.is_empty() and not panel.snapshot().confirmed,
		"An avatar from the previous picker build cannot start while the editor opens")
	await settle()
	var name_field := panel.find_child("LeaderboardName", true, false) as LineEdit
	check(is_instance_valid(name_field) and name_field.has_focus(),
		"The external Add player action opens and focuses the name editor")
	name_field.text = "New player"
	name_field.text_changed.emit(name_field.text)
	var stale_create := action(panel, "LeaderboardCreatePlayer")
	stale_create.pressed.emit()
	stale_create.pressed.emit()
	await settle()
	var new_id: String = str(state.profiles.back().id)
	check(state.profiles.size() == 2 and state.profiles.back().name == "New player" and confirmations.is_empty(),
		"Saving a new player once returns to the chooser without starting a round")
	check(action(panel, "LeaderboardStartGame") == null and panel.find_child("LeaderboardName", true, false) == null,
		"After saving, the editor closes and no extra Start action appears")
	var new_choice := action(panel, "LeaderboardPlayer_" + new_id)
	check(is_instance_valid(new_choice) and new_choice.has_focus(),
		"The new player's avatar receives focus for deliberate activation")
	new_choice.pressed.emit()
	new_choice.pressed.emit()
	action(panel, "LeaderboardPlayer_" + first_id).pressed.emit()
	check(confirmations.size() == 1 and confirmations[0] == new_id and panel.snapshot().confirmed,
		"Repeated or alternate avatar activation confirms the newly created player exactly once")
	panel.configure(state, "picker")
	var old_generation_choice := action(panel, "LeaderboardPlayer_" + first_id)
	panel.configure(state, "picker")
	old_generation_choice.pressed.emit()
	check(confirmations.size() == 1 and panel.snapshot().selected_player.is_empty() and not panel.snapshot().confirmed,
		"An avatar callback from a previous round cannot choose the next round's player")
	storage.readable = false
	action(panel, "LeaderboardPlayer_" + first_id).pressed.emit()
	check(confirmations.size() == 1 and not panel.snapshot().confirmed and not panel.snapshot().error.is_empty(),
		"Direct avatar activation still requires a readable durable player record")
	storage.readable = true
	action(panel, "LeaderboardPlayer_" + first_id).pressed.emit()
	check(confirmations.size() == 2 and confirmations[1] == first_id and panel.snapshot().confirmed,
		"Tapping the avatar again can start once player storage recovers")
	panel.queue_free()
	await settle()


func _check_pop(app, state, storage, player_id: String) -> void:
	app.choose_mode("pop")
	await settle()
	check(app._leaderboard_overlay.visible and app._leaderboard_gate == "pop" and app._pop_player_id.is_empty(),
		"Entering Voice Pop opens a player picker before microphone startup")
	check(app._pop.game.phase == "ready" and not app._pop_speech_active,
		"Player selection has no microphone request, targets or running countdown")
	var panel = app._leaderboard_panel
	check(action(panel, "LeaderboardStartGame") == null and panel.snapshot().selected_player.is_empty(),
		"Each round offers player avatars directly without a separate Start action")
	for dimensions in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(960, 720)]:
		root.size = dimensions
		await settle()
		var surface := panel.find_child("LeaderboardSurface", true, false) as Control
		var add := action(panel, "LeaderboardAddPlayer")
		check(is_instance_valid(surface) and is_instance_valid(add) and not surface.is_ancestor_of(add),
			"Add player sits outside the bordered chooser at %s" % dimensions)
		check(add.get_global_rect().position.y > surface.get_global_rect().end.y,
			"Add player appears below the bordered chooser at %s" % dimensions)
		check(add.get_global_rect().position.x >= -1 and add.get_global_rect().end.x <= app.size.x + 1,
			"The external Add player action fits horizontally at %s" % dimensions)
	var remaining: float = app._pop.game.remaining
	app._on_voice_state([true, true, "Listening"])
	app._on_voice_result(["apple", true])
	app._pop._advance_game(3.0)
	check(app._pop.game.phase == "ready" and app._pop.game.remaining == remaining and app._pop.game.targets.is_empty(),
		"Late recognition callbacks cannot start or score a round before selecting its player")
	app._leaderboard_player_confirmed("missing-player")
	check(app._leaderboard_gate == "pop" and app._pop_player_id.is_empty(),
		"An invalid player confirmation cannot bypass the picker")
	app._controller_back()
	check(not app._leaderboard_overlay.visible and app._leaderboard_gate.is_empty() and app._pop_player_id.is_empty(),
		"Back cancels the picker without assigning a player or starting speech")
	app._on_voice_state([true, true, "Listening"])
	check(app._pop.game.phase == "ready" and not app._pop_speech_active,
		"A late microphone callback after cancellation leaves the round ready")
	app._request_pop_player()
	await settle()
	panel = app._leaderboard_panel
	action(panel, "LeaderboardPlayer_" + player_id).pressed.emit()
	check(app._pop_player_id == player_id and not app._leaderboard_overlay.visible,
		"Choosing an avatar immediately assigns the player and enters the round")
	await settle()
	check(not app._leaderboard_overlay.visible and app._pop_player_id == player_id and app._pop.game.phase == "ready",
		"The selected player's round waits for real listening readiness")
	var round_id: String = app._leaderboard_round_id
	app._leaderboard_player_confirmed(str(state.profiles[1].id))
	check(app._pop_player_id == player_id and app._leaderboard_round_id == round_id,
		"Repeated or stale confirmation cannot reassign or restart the active round")
	app._on_voice_state([true, true, "Listening"])
	check(app._pop.game.phase == "running", "The selected player's round starts only when the microphone is listening")
	app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
	check(app._pop.game.hits == 1, "The fixture earns a real spoken hit")
	storage.writable = false
	var bytes_before: String = str(storage.text)
	app._pop._advance_game(60.0)
	await settle()
	panel = app._pop_leaderboard
	check(is_instance_valid(panel) and panel.is_visible_in_tree(), "Voice Pop automatically shows the completed round's leaderboard")
	check(panel.get_index() == 2 and app._pop.replay_button.is_visible_in_tree(),
		"The board sits after the hit total and Play again, before the word lists")
	check(action(panel, "LeaderboardPlayer_" + player_id) == null and action(panel, "LeaderboardAddPlayer") == null,
		"A completed Voice Pop round has no player chooser or profile editor")
	panel._select_player(str(state.profiles[1].id))
	check(panel.snapshot().assigned_player == player_id and panel.snapshot().selected_player == player_id,
		"The result remains bound to the player selected before play")
	check(not panel.snapshot().submitted and not panel.snapshot().error.is_empty()
		and storage.text == bytes_before and not panel.snapshot().animation.active,
		"Failed automatic persistence leaves the fixed player's result retryable without celebrating")
	check(action(panel, "LeaderboardSaveScore") != null and action(panel, "LeaderboardSaveScore").text == "Retry saving",
		"Persistence failure offers Retry saving instead of a new attribution choice")
	app._pop_finished(app._pop.game.summary())
	check(app._pop_leaderboard == panel and state.round_submission(round_id).is_empty(),
		"Duplicate finish callbacks cannot attach a second result or retry a failed write implicitly")
	app._show_collection()
	app._players_button.pressed.emit()
	await settle()
	var menu_name := app._leaderboard_panel.find_child("LeaderboardName", true, false) as LineEdit
	menu_name.text = "Casey"
	menu_name.text_changed.emit(menu_name.text)
	storage.writable = true
	action(app._leaderboard_panel, "LeaderboardAvatar_bear").pressed.emit()
	action(app._leaderboard_panel, "LeaderboardCreatePlayer").pressed.emit()
	await settle()
	var casey: String = str(state.profiles.back().id)
	check(state.profiles.size() == 3 and state.profiles.back().name == "Casey", "The menu can add a future player while a result awaits retry")
	app._controller_back()
	app._hide_collection()
	await settle()
	check(app._pop_leaderboard == panel and panel.snapshot().assigned_player == player_id
		and action(panel, "LeaderboardPlayer_" + casey) == null and not panel.snapshot().submitted,
		"Returning from profile management preserves the failed round's locked player")
	var writes_before: int = storage.writes
	action(panel, "LeaderboardSaveScore").pressed.emit()
	await settle()
	check(panel.snapshot().submitted and state.board("pop")[0].metric == 1 and state.round_submission(round_id).player_id == player_id,
		"Retry saves the actual hit total for the player selected before play")
	check(not panel.snapshot().animation.active, "Reduced motion shows the saved rank without a moving celebration")
	panel.save_assigned_score()
	panel._save_score()
	check(storage.writes == writes_before + 1, "Repeated automatic or manual submission cannot save the same round twice")
	check(action(panel, "LeaderboardSaveScore") == null, "Saved results need no further attribution or save action")
	app._show_collection()
	app._leaderboards_button.pressed.emit()
	await settle()
	check(app.leaderboard_snapshot().rows.size() == 1 and not app.leaderboard_snapshot().animation.active,
		"Reopening the saved board does not replay the celebration")
	app._controller_back()
	app._hide_collection()
	app._pop.replay_button.pressed.emit()
	await settle()
	check(app._leaderboard_gate == "pop" and action(app._leaderboard_panel, "LeaderboardStartGame") == null
		and app._leaderboard_panel.snapshot().selected_player.is_empty(),
		"Play again asks who will play next instead of silently reusing the last player")
	app._controller_back()
	check(app._pop.game.phase == "finished" and app._leaderboard_round_id == round_id and state.board("pop")[0].metric == 1,
		"Cancelling replay preserves the completed result and saved personal best")
	app._pop.replay_button.pressed.emit()
	await settle()
	action(app._leaderboard_panel, "LeaderboardPlayer_" + casey).pressed.emit()
	await settle()
	check(app._leaderboard_round_id != round_id and app._leaderboard_result.is_empty()
		and app._pop_player_id == casey and app._pop.game.phase == "ready",
		"Tapping a replay avatar creates a fresh round for the newly selected player")
	check(not app.leaderboard_snapshot().visible and state.board("pop")[0].metric == 1,
		"Replaying hides the previous board while retaining its personal best")
	app._on_voice_state([true, true, "Listening"])
	app._pop._advance_game(60.0)
	await settle()
	var next_round: String = app._leaderboard_round_id
	check(state.round_submission(next_round).player_id == casey and app._pop_leaderboard.snapshot().submitted,
		"The next result automatically saves under its newly selected player without another question")
	check(action(app._pop_leaderboard, "LeaderboardPlayer_" + casey) == null,
		"Successful automatic saving also omits the old results attribution controls")
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
		check(app.leaderboard_snapshot().mode == mode and app.leaderboard_snapshot().rows.size() == (2 if mode == "pop" else 1),
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

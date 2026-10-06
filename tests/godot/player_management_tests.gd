extends SceneTree

const State = preload("res://scripts/leaderboard_state.gd")
const PlayerPanel = preload("res://scripts/leaderboard_panel.gd")
const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")

var checks: int = 0
var failures: int = 0
var _directory: String


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
	for frame in range(6):
		await process_frame


func action(panel: Node, control_name: String) -> Button:
	return panel.find_child(control_name, true, false) as Button


func press(panel: Node, control_name: String) -> bool:
	var button := action(panel, control_name)
	check(is_instance_valid(button), "The requested player action exists: " + control_name)
	if not is_instance_valid(button):
		return false
	button.pressed.emit()
	return true


func enter_name(panel: Node, value: String) -> void:
	var field := panel.find_child("LeaderboardName", true, false) as LineEdit
	check(is_instance_valid(field), "The player editor has a name field")
	if is_instance_valid(field):
		field.text = value
		field.text_changed.emit(value)


func profile(state, id: String) -> Dictionary:
	for entry in state.profiles:
		if str(entry.id) == id:
			return entry
	return {}


func _run() -> void:
	_directory = "user://player-management-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(_directory) == OK, "Create isolated player-management storage")
	root.size = Vector2i(960, 720)
	await _check_panel_management()
	await _check_keyboard_viewport_resize()
	await _check_keyboard_submit_gesture()
	await _check_full_capacity()
	await _check_stale_result_refresh()
	await _check_app_management()
	for filename in DirAccess.get_files_at(_directory):
		check(DirAccess.remove_absolute(_directory + "/" + filename) == OK, "Remove isolated player-management file")
	check(DirAccess.remove_absolute(_directory) == OK, "Remove isolated player-management directory")
	print("Player management: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_panel_management() -> void:
	var storage := BrowserStorage.new()
	var state := State.new(_directory + "/panel.cfg", storage)
	check(state.load_state(), "Load an empty player-management store")
	check(state.create_profile("Avery", "fox").ok and state.create_profile("Blake", "cat").ok,
		"Seed two independently editable players")
	var first_id: String = str(state.profiles[0].id)
	var other_id: String = str(state.profiles[1].id)
	check(state.submit_round("management-original-score", "pop", first_id, {"hits": 7}).ok,
		"Seed the first player's personal best")
	var panel := PlayerPanel.new()
	root.add_child(panel)
	panel.size = Vector2(700, 700)
	var updated: Array[Dictionary] = []
	var removed: Array[String] = []
	panel.profile_updated.connect(func(value: Dictionary) -> void: updated.append(value.duplicate(true)))
	panel.profile_removed.connect(func(id: String) -> void: removed.append(id))
	panel.configure(state, "players")
	await settle()
	var original_bytes: String = str(storage.text)
	press(panel, "LeaderboardEdit_" + first_id)
	await settle()
	check(panel.snapshot().editing_player == first_id and panel.snapshot().removing_player.is_empty(),
		"Editing targets one stored player and is visible in the browser snapshot")
	var field := panel.find_child("LeaderboardName", true, false) as LineEdit
	check(is_instance_valid(field) and field.text == "Avery", "Editing prefills the existing player name")
	check(action(panel, "LeaderboardAvatar_fox").button_pressed, "Editing prefills the existing avatar")
	enter_name(panel, "Unsaved change")
	press(panel, "LeaderboardAvatar_panda")
	var stale_save := action(panel, "LeaderboardSavePlayer")
	press(panel, "LeaderboardCancelEdit")
	if is_instance_valid(stale_save):
		stale_save.pressed.emit()
	await settle()
	check(storage.text == original_bytes and updated.is_empty() and panel.snapshot().editing_player.is_empty(),
		"Cancel discards both drafts and rejects an obsolete Save callback")
	check(action(panel, "LeaderboardEdit_" + first_id).has_focus(),
		"Cancelling edits restores focus to the original player's Edit action")
	press(panel, "LeaderboardEdit_" + first_id)
	enter_name(panel, "Avery Nova")
	press(panel, "LeaderboardAvatar_rocket")
	storage.writable = false
	press(panel, "LeaderboardSavePlayer")
	await settle()
	check(storage.text == original_bytes and profile(state, first_id).name == "Avery" and updated.is_empty(),
		"A failed update does not change the durable profile or emit a successful update")
	check(panel.snapshot().editing_player == first_id and not panel.snapshot().error.is_empty()
		and panel.find_child("LeaderboardName", true, false).text == "Avery Nova",
		"A failed update retains a retryable editor and the user's name draft")
	storage.writable = true
	storage.readable = false
	press(panel, "LeaderboardSavePlayer")
	check(not state.ready and storage.text == original_bytes and updated.is_empty(),
		"A stale-store read failure cannot replace another tab's latest player record")
	storage.readable = true
	var writes_before: int = storage.writes
	var save := action(panel, "LeaderboardSavePlayer")
	save.pressed.emit()
	save.pressed.emit()
	await settle()
	check(storage.writes == writes_before + 1 and updated.size() == 1,
		"A double Save persists and announces the edit once")
	check(profile(state, first_id) == {"id": first_id, "name": "Avery Nova", "avatar": "rocket"}
		and profile(state, other_id).name == "Blake", "Saving edits changes only the selected player's identity fields")
	check(state.board("pop")[0].name == "Avery Nova" and state.board("pop")[0].avatar == "rocket"
		and state.board("pop")[0].metric == 7 and state.round_submission("management-original-score").player_id == first_id,
		"An edited identity updates its board without losing its score or round ownership")
	check(panel.snapshot().editing_player.is_empty(), "Successful saving exits the editor")
	original_bytes = str(storage.text)
	press(panel, "LeaderboardRemove_" + first_id)
	await settle()
	check(panel.snapshot().removing_player == first_id and storage.text == original_bytes,
		"Remove opens confirmation before changing stored data")
	var stale_remove := action(panel, "LeaderboardConfirmRemove")
	press(panel, "LeaderboardCancelRemove")
	if is_instance_valid(stale_remove):
		stale_remove.pressed.emit()
	await settle()
	check(storage.text == original_bytes and removed.is_empty() and panel.snapshot().removing_player.is_empty(),
		"Cancelling removal preserves scores and rejects an obsolete confirmation callback")
	press(panel, "LeaderboardRemove_" + first_id)
	storage.writable = false
	press(panel, "LeaderboardConfirmRemove")
	await settle()
	check(storage.text == original_bytes and not profile(state, first_id).is_empty() and removed.is_empty(),
		"A failed removal keeps the player and does not notify the main scene")
	check(panel.snapshot().removing_player == first_id and not panel.snapshot().error.is_empty(),
		"A failed removal retains a retryable confirmation")
	storage.writable = true
	storage.readable = false
	press(panel, "LeaderboardConfirmRemove")
	check(not state.ready and storage.text == original_bytes and removed.is_empty(),
		"A stale-store read failure leaves removal pending without modifying data")
	storage.readable = true
	writes_before = storage.writes
	var confirm := action(panel, "LeaderboardConfirmRemove")
	confirm.pressed.emit()
	confirm.pressed.emit()
	await settle()
	check(storage.writes == writes_before + 1 and removed == [first_id],
		"A double confirmation removes and announces the player once")
	check(profile(state, first_id).is_empty() and not profile(state, other_id).is_empty()
		and state.board("pop").is_empty() and state.round_submission("management-original-score").is_empty(),
		"Removal deletes that player's scores and receipts while retaining the other player")
	var edit := action(panel, "LeaderboardEdit_" + other_id)
	panel.configure(state, "boards")
	edit.pressed.emit()
	check(panel.snapshot().view == "boards" and panel.snapshot().editing_player.is_empty(),
		"A player action from a prior panel generation cannot reopen management")
	panel.queue_free()
	await settle()


func _check_keyboard_viewport_resize() -> void:
	var previous_size: Vector2i = root.size
	var previous_mode: int = root.content_scale_mode
	var previous_aspect: int = root.content_scale_aspect
	var previous_scale_size: Vector2i = root.content_scale_size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	root.size = Vector2i(390, 844)
	await settle()
	var state := State.new(_directory + "/keyboard-resize.cfg", BrowserStorage.new())
	check(state.load_state(), "Load isolated keyboard-resize player storage")
	var panel := PlayerPanel.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.configure(state, "onboarding")
	await settle()
	var field := panel.find_child("LeaderboardName", true, false) as LineEdit
	field.grab_focus()
	enter_name(panel, "Avery Nova")
	field.caret_column = 7
	field.select(2, 7)
	var original_id: int = field.get_instance_id()
	var initial_scale: float = panel._last_scale
	check(field.has_focus() and field.is_editing(), "The resize fixture starts with a live name editor")
	for height in [350, 844, 350]:
		root.size = Vector2i(390, height)
		await settle()
		var current := panel.find_child("LeaderboardName", true, false) as LineEdit
		check(current.get_instance_id() == original_id and current.has_focus() and current.is_editing(),
			"Opening or closing the keyboard keeps the live name editor at height %d" % height)
		check(current.text == "Avery Nova" and panel._draft_name == "Avery Nova"
			and current.caret_column == 7 and current.get_selection_from_column() == 2
			and current.get_selection_to_column() == 7,
			"Keyboard viewport changes preserve the draft, caret and selection at height %d" % height)
	check(not is_equal_approx(initial_scale, panel._scale()) and is_equal_approx(panel._last_scale, initial_scale),
		"The shortened viewport defers a real scale change until editing ends")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = false
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	await settle()
	var settled := panel.find_child("LeaderboardName", true, false) as LineEdit
	check(settled.get_instance_id() != original_id and is_equal_approx(panel._last_scale, panel._scale()),
		"Ending name editing applies the deferred scale without another viewport event")
	check(settled.text == "Avery Nova" and panel._draft_name == "Avery Nova",
		"Applying the deferred scale keeps the unfinished player name")
	action(panel, "LeaderboardCreatePlayer").grab_focus()
	var settled_id: int = settled.get_instance_id()
	root.size = Vector2i(390, 844)
	await settle()
	var resized := panel.find_child("LeaderboardName", true, false) as LineEdit
	check(resized.get_instance_id() != settled_id and is_equal_approx(panel._last_scale, panel._scale()),
		"A viewport resize still updates the form immediately outside name editing")
	check(action(panel, "LeaderboardCreatePlayer").has_focus() and resized.text == "Avery Nova",
		"Ordinary form rescaling retains navigation focus and the name draft")
	panel.queue_free()
	await settle()
	root.content_scale_mode = previous_mode
	root.content_scale_aspect = previous_aspect
	root.content_scale_size = previous_scale_size
	root.size = previous_size
	await settle()


func _player_pointer(position: Vector2, down: bool, touch: bool) -> void:
	var point: Vector2 = root.get_final_transform() * position
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 21
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check_keyboard_submit_gesture() -> void:
	var previous_size: Vector2i = root.size
	var previous_mode: int = root.content_scale_mode
	var previous_aspect: int = root.content_scale_aspect
	var previous_scale_size: Vector2i = root.content_scale_size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	for touch in [false, true]:
		for editing in [false, true]:
			root.size = Vector2i(390, 844)
			await settle()
			var storage := BrowserStorage.new()
			var state := State.new(_directory + "/keyboard-submit.cfg", storage)
			check(state.load_state(), "Load isolated pointer-submit player storage")
			if editing:
				check(state.create_profile("Existing player", "fox").ok, "Seed the player edited by pointer submission")
			var scroll := ScrollContainer.new()
			root.add_child(scroll)
			scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			var panel := PlayerPanel.new()
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(panel)
			panel.configure(state, "players" if editing else "onboarding")
			if editing:
				press(panel, "LeaderboardEdit_" + str(state.profiles[0].id))
			await settle()
			var gestures: Array = [true, false] if not touch and not editing else [false]
			for cancel_gesture in gestures:
				root.size = Vector2i(390, 844)
				await settle()
				var field := panel.find_child("LeaderboardName", true, false) as LineEdit
				field.grab_focus()
				enter_name(panel, "Pointer saved name")
				root.size = Vector2i(390, 350)
				await settle()
				check(field.has_focus() and field.is_editing() and not is_equal_approx(panel._last_scale, panel._scale()),
					"Pointer submission starts with a live editor and a pending keyboard scale")
				var button_name: String = "LeaderboardSavePlayer" if editing else "LeaderboardCreatePlayer"
				var submit := action(panel, button_name)
				scroll.ensure_control_visible(submit)
				await settle()
				var point: Vector2 = submit.get_global_rect().get_center()
				check(root.get_visible_rect().has_point(point), "The pending-scale submit target is inside the short viewport")
				var submit_id: int = submit.get_instance_id()
				var writes_before: int = storage.writes
				_player_pointer(point, true, touch)
				check(submit.has_focus() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
					"A dispatched pointer press transfers editing focus to the submit action")
				await settle()
				check(is_instance_valid(submit) and action(panel, button_name).get_instance_id() == submit_id,
					"A pending scale preserves the pressed submit button until pointer release")
				check(storage.writes == writes_before, "Pressing a submit action does not save before release")
				if cancel_gesture:
					var motion := InputEventMouseMotion.new()
					motion.position = root.get_final_transform() * Vector2(-5, -5)
					motion.global_position = motion.position
					motion.relative = root.get_final_transform().basis_xform(Vector2(-5, -5) - point)
					motion.button_mask = MOUSE_BUTTON_MASK_LEFT
					Input.parse_input_event(motion)
					Input.flush_buffered_events()
				_player_pointer(Vector2(-5, -5) if cancel_gesture else point, false, touch)
				await settle()
				if cancel_gesture:
					check(storage.writes == writes_before and state.profiles.is_empty(),
						"Releasing outside the pending-scale submit target cancels the save")
					check(is_equal_approx(panel._last_scale, panel._scale()) and not panel.is_processing_input(),
						"A canceled gesture applies the deferred scale and releases its input listener")
				else:
					check(storage.writes == writes_before + 1 and state.profiles.size() == 1
						and state.profiles[0].name == "Pointer saved name",
						"The first %s release %s the player despite a pending keyboard scale" % ["touch" if touch else "mouse", "updates" if editing else "creates"])
			scroll.queue_free()
			await settle()
	root.content_scale_mode = previous_mode
	root.content_scale_aspect = previous_aspect
	root.content_scale_size = previous_scale_size
	root.size = previous_size
	await settle()


func _check_full_capacity() -> void:
	var state := State.new(_directory + "/capacity.cfg", BrowserStorage.new())
	check(state.load_state(), "Load an isolated full-capacity store")
	for index in range(10):
		check(state.create_profile("Player %d" % index, State.AVATARS[index]).ok, "Seed player spot %d" % index)
	var ids: Array = state.profiles.map(func(entry: Dictionary) -> String: return str(entry.id))
	var panel := PlayerPanel.new()
	root.add_child(panel)
	panel.size = Vector2(700, 700)
	panel.configure(state, "players")
	for index in range(10):
		press(panel, "LeaderboardEdit_" + str(ids[index]))
		check(panel.snapshot().editing_player == ids[index] and action(panel, "LeaderboardSavePlayer") != null,
			"The editor remains available at ten-player capacity for player %d" % index)
		enter_name(panel, "Updated %d" % index)
		press(panel, "LeaderboardAvatar_" + State.AVATARS[(index + 1) % State.AVATARS.size()])
		press(panel, "LeaderboardSavePlayer")
		check(state.profiles.size() == 10 and str(state.profiles[index].id) == ids[index]
			and state.profiles[index].name == "Updated %d" % index,
			"Editing a full store preserves the capacity and ID of player %d" % index)
	check(action(panel, "LeaderboardCreatePlayer") == null, "Full capacity prevents creating an eleventh profile")
	panel.queue_free()
	await settle()


func _check_stale_result_refresh() -> void:
	var storage := BrowserStorage.new()
	var state := State.new(_directory + "/stale-result.cfg", storage)
	check(state.load_state() and state.create_profile("Covered player", "fox").ok
		and state.create_profile("Survivor", "bear").ok, "Seed a covered result and another surviving player")
	var id: String = str(state.profiles[0].id)
	var other_id: String = str(state.profiles[1].id)
	var panel := PlayerPanel.new()
	root.add_child(panel)
	panel.size = Vector2(700, 700)
	panel.configure(state, "result", "pop", "covered-pop-round", {"hits": 5}, true, id)
	storage.writable = false
	panel.save_assigned_score()
	check(not panel.snapshot().submitted and not panel.snapshot().error.is_empty(),
		"The covered fixture retains a fixed player's pending result after a failed save")
	storage.writable = true
	var external := State.new(_directory + "/stale-result.cfg", storage)
	check(external.load_state() and external.update_profile(id, "Changed elsewhere", "rainbow").ok,
		"Another local view can edit the covered result's player")
	panel.refresh_profiles()
	check(panel.snapshot().profiles[0].name == "Changed elsewhere" and panel.snapshot().assigned_player == id,
		"Refreshing a covered result loads its changed profile without reassigning the score")
	var old_retry := action(panel, "LeaderboardSaveScore")
	check(external.remove_profile(id).ok, "Another local view can remove the pending result's player")
	var writes_before: int = storage.writes
	panel.refresh_profiles()
	if is_instance_valid(old_retry):
		old_retry.pressed.emit()
	panel.save_assigned_score()
	panel._select_player(other_id)
	check(panel.snapshot().retired_result and panel.snapshot().selected_player.is_empty()
		and action(panel, "LeaderboardSaveScore") == null and storage.writes == writes_before,
		"Refreshing a deleted assigned player retires retries and prevents score reassignment")
	check(state.board("pop").is_empty() and state.round_submission("covered-pop-round").is_empty(),
		"A removed player's pending score never becomes another player's personal best")
	check(state.submit_round("covered-match-round", "match", other_id,
		{"won": true, "mistakes": 1, "hints_used": 0}).ok, "Seed a previously saved Match result")
	panel.configure(state, "boards", "match", "covered-match-round", {"won": true, "mistakes": 1, "hints_used": 0}, true)
	check(panel.snapshot().submitted and external.remove_profile(other_id).ok,
		"A saved result's owner can disappear while its board is covered")
	writes_before = storage.writes
	panel.refresh_profiles()
	panel._save_score()
	check(panel.snapshot().retired_result and panel.snapshot().rows.is_empty()
		and action(panel, "LeaderboardSaveScore") == null and storage.writes == writes_before,
		"A refreshed saved result remains retired after its receipt and profile were removed")
	panel.queue_free()
	await settle()


func _open_players(app) -> void:
	if not app.collection_page.visible:
		app._show_collection()
	press(app, "MenuPlayers")
	await settle()


func _leave_players(app) -> void:
	app._controller_back()
	if app.collection_page.visible:
		app._hide_collection()
	await settle()


func _edit_player(app, id: String, new_name: String, avatar: String) -> void:
	press(app._leaderboard_panel, "LeaderboardEdit_" + id)
	enter_name(app._leaderboard_panel, new_name)
	press(app._leaderboard_panel, "LeaderboardAvatar_" + avatar)
	press(app._leaderboard_panel, "LeaderboardSavePlayer")
	await settle()


func _remove_player(app, id: String) -> void:
	var shared_paths: Array[String] = [app.medal_progress._save_path, app.playroom_state._save_path]
	var shared_bytes: Array[String] = []
	for path in shared_paths:
		shared_bytes.append(FileAccess.get_file_as_string(path))
	press(app._leaderboard_panel, "LeaderboardRemove_" + id)
	press(app._leaderboard_panel, "LeaderboardConfirmRemove")
	await settle()
	for index in range(shared_paths.size()):
		check(FileAccess.get_file_as_string(shared_paths[index]) == shared_bytes[index],
			"Removing a player preserves the shared save: " + shared_paths[index].get_file())


func _check_app_management() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(_directory + "/medals.cfg", _directory + "/legacy.cfg")
	app.playroom_save_path = _directory + "/room.cfg"
	PlayerFixture.install(app, _directory)
	var state = app.leaderboard_state
	check(state.create_profile("Second player", "cat").ok and state.create_profile("Third player", "panda").ok
		and state.create_profile("Memory player", "rabbit").ok,
		"Seed players for active, completed and final-profile lifecycle checks")
	var first_id: String = str(state.profiles[0].id)
	var second_id: String = str(state.profiles[1].id)
	var third_id: String = str(state.profiles[2].id)
	var memory_id: String = str(state.profiles[3].id)
	root.add_child(app)
	# Profile checks do not need the host's audio device or playback resources.
	app.audio.muted = true
	await settle()
	app.set_reduced_motion(true)
	app._on_loading_finished([])
	await _open_players(app)
	press(app._leaderboard_panel, "LeaderboardEdit_" + first_id)
	enter_name(app._leaderboard_panel, "Canceled edit")
	app._controller_back()
	check(app._leaderboard_overlay.visible and app._leaderboard_panel.snapshot().editing_player.is_empty()
		and profile(state, first_id).name == "Test player", "Controller Back cancels edits before leaving Players")
	press(app._leaderboard_panel, "LeaderboardRemove_" + first_id)
	app._controller_back()
	check(app._leaderboard_overlay.visible and app._leaderboard_panel.snapshot().removing_player.is_empty()
		and state.profiles.size() == 4, "Controller Back cancels removal before leaving Players")
	for dimensions in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(960, 720)]:
		root.size = dimensions
		await settle()
		for control in app.leaderboard_snapshot().controls:
			var bounds: Array = control.rect
			check(float(bounds[0]) >= -1 and float(bounds[0]) + float(bounds[2]) <= app.size.x + 1,
				"Player-management controls fit horizontally at %s: %s" % [dimensions, control.name])
		for candidate in app._focus_candidates():
			check(app._leaderboard_overlay.is_ancestor_of(candidate), "Controller navigation stays inside player management")
	await _leave_players(app)
	app.choose_mode("pop")
	await settle()
	press(app._leaderboard_panel, "LeaderboardPlayer_" + first_id)
	app._on_voice_state([true, true, "Listening"])
	app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
	check(app._pop.game.hits == 1 and app._pop_player_id == first_id, "The assigned player earns a real Voice Pop hit")
	var live_round: String = app._leaderboard_round_id
	await _open_players(app)
	await _edit_player(app, first_id, "Renamed live player", "rocket")
	check(app._pop._round_player.name == "Renamed live player" and app._pop._round_player.avatar == "rocket"
		and app._pop.game.hits == 1 and app._leaderboard_round_id == live_round,
		"Renaming the current Pop player updates its cached identity without restarting its round")
	await _remove_player(app, first_id)
	check(app._pop_player_id.is_empty() and app._pop._round_player.is_empty() and app._pop.game.phase == "ready"
		and app._pop.game.hits == 0 and app._leaderboard_round_id != live_round,
		"Removing the active Pop player discards that player's unfinished round")
	await _leave_players(app)
	app._on_voice_state([true, true, "Listening"])
	check(app._pop.game.phase == "ready" and app._pop.game.hits == 0,
		"A stale microphone callback cannot restart the removed player's round")
	app._request_pop_player()
	await settle()
	press(app._leaderboard_panel, "LeaderboardPlayer_" + second_id)
	app._on_voice_state([true, true, "Listening"])
	app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
	app._pop._advance_game(60.0)
	await settle()
	check(app._pop.game.phase == "finished" and app._pop_leaderboard.snapshot().submitted,
		"A surviving player can complete and save a fresh Pop round")
	app._show_collection()
	var external := State.new(state._save_path)
	check(external.load_state() and external.update_profile(second_id, "External winner", "rainbow").ok,
		"Another local view can update the finished player's identity")
	app._hide_collection()
	await settle()
	check(app._pop._round_player.name == "External winner" and app._pop._round_player.avatar == "rainbow"
		and app._pop_leaderboard.snapshot().rows[0].name == "External winner",
		"Returning to a covered Pop result refreshes the hero and board from the latest saved profile")
	await _open_players(app)
	await _edit_player(app, second_id, "Renamed winner", "unicorn")
	check(app._pop._round_player.name == "Renamed winner" and app._pop._round_player.avatar == "unicorn",
		"Editing the completed Pop player refreshes the result hero identity")
	check(app._pop_leaderboard.snapshot().rows[0].name == "Renamed winner"
		and app._pop_leaderboard.snapshot().rows[0].avatar == "unicorn",
		"The covered result board refreshes its name and avatar after editing")
	await _remove_player(app, second_id)
	check(app._pop_player_id.is_empty() and app._pop._round_player.is_empty() and app._leaderboard_result.is_empty()
		and app._pop.game.phase == "ready" and state.board("pop").is_empty(),
		"Removing the completed Pop player retires its result and deleted personal best")
	await _leave_players(app)
	await _check_memory_owner_removal(app, state, memory_id)
	app.choose_mode("match")
	await settle()
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app._select_card(card.id)
			app._select_card(card.word.id + ":image")
			app._continue_match()
	await settle()
	check(app.model.phase == "won" and app.model.chest_state == "closed", "A real Match victory earns a shared unopened chest")
	check(app._result_board_button.is_visible_in_tree(), "A new Match victory offers its result leaderboard")
	press(app, "ResultLeaderboard")
	if not app._leaderboard_overlay.visible:
		app._show_result_leaderboard()
	await settle()
	press(app._leaderboard_panel, "LeaderboardPlayer_" + third_id)
	press(app._leaderboard_panel, "LeaderboardSaveScore")
	await settle()
	check(app._leaderboard_saved_player_id == third_id and not state.board("match").is_empty(),
		"Saving the completed Match result records its player ownership")
	app._controller_back()
	await _open_players(app)
	var lesson: Array = app.model.cards.duplicate(true)
	var room_bytes: String = FileAccess.get_file_as_string(app.playroom_state._save_path)
	var medal_bytes: String = FileAccess.get_file_as_string(app.medal_progress._save_path)
	await _remove_player(app, third_id)
	check(state.profiles.is_empty() and app._leaderboard_result.is_empty() and app._leaderboard_saved_player_id.is_empty()
		and state.board("match").is_empty(), "Removing a saved Match owner retires that result instead of allowing reassignment")
	check(not app._result_board_button.visible, "Removing a saved Match owner hides the retired result action immediately")
	app._refresh()
	check(not app._result_board_button.visible, "Refreshing the completed Match game keeps the retired result action hidden")
	check(app._leaderboard_gate == "onboarding" and app._leaderboard_overlay.visible
		and not app._leaderboard_close.is_visible_in_tree(), "Removing the last player restores mandatory player creation")
	app._controller_back()
	check(app._leaderboard_overlay.visible and app._leaderboard_gate == "onboarding",
		"Controller Back cannot bypass the empty-profile onboarding gate")
	check(app.model.phase == "won" and app.model.chest_state == "closed" and app.model.cards == lesson,
		"Removing all profiles preserves the earned Match chest and prepared lesson")
	check(FileAccess.get_file_as_string(app.medal_progress._save_path) == medal_bytes
		and FileAccess.get_file_as_string(app.playroom_state._save_path) == room_bytes,
		"Player deletion leaves shared collectibles and room saves unchanged")
	enter_name(app._leaderboard_panel, "New beginning")
	press(app._leaderboard_panel, "LeaderboardCreatePlayer")
	await settle()
	check(state.profiles.size() == 1 and state.profiles[0].name == "New beginning"
		and app._leaderboard_gate.is_empty() and not app._leaderboard_overlay.visible,
		"Creating a replacement player exits last-profile onboarding")
	app._show_result_leaderboard()
	check(not app._leaderboard_overlay.visible and state.board("match").is_empty(),
		"A replacement player cannot claim the deleted player's old Match result")
	app.audio.halt()
	app.queue_free()
	await settle()


func _check_memory_owner_removal(app, state, player_id: String) -> void:
	app.choose_mode("memory")
	await settle()
	var memory = app._memory
	for index in range(memory.memory.cards.size()):
		var card: Dictionary = memory.memory.cards[index]
		if card.kind != "word":
			continue
		for other in range(memory.memory.cards.size()):
			if memory.memory.cards[other].word.id == card.word.id and memory.memory.cards[other].kind == "image":
				memory.card_buttons[index].pressed.emit()
				memory.card_buttons[other].pressed.emit()
				memory.continue_feedback()
				break
	await settle()
	check(app.model.phase == "won" and app.model.chest_state == "closed", "A real Memory victory earns an unopened chest")
	check(app._result_board_button.is_visible_in_tree(), "A new Memory victory offers its result leaderboard")
	press(app, "ResultLeaderboard")
	await settle()
	press(app._leaderboard_panel, "LeaderboardPlayer_" + player_id)
	press(app._leaderboard_panel, "LeaderboardSaveScore")
	await settle()
	check(app._leaderboard_saved_player_id == player_id and state.board("memory").size() == 1,
		"The completed Memory result records its saved owner")
	app._controller_back()
	await _open_players(app)
	var lesson: Array = app.model.cards.duplicate(true)
	var memory_cards: Array = memory.memory.cards.duplicate(true)
	await _remove_player(app, player_id)
	check(app._leaderboard_result.is_empty() and app._leaderboard_saved_player_id.is_empty()
		and state.board("memory").is_empty(), "Removing a saved Memory owner retires the old result and personal best")
	check(not app._result_board_button.visible, "Removing a saved Memory owner hides the retired result action immediately")
	app._refresh()
	check(not app._result_board_button.visible, "Refreshing the completed Memory game keeps the retired result action hidden")
	check(app.model.phase == "won" and app.model.chest_state == "closed"
		and app.model.cards == lesson and memory.memory.cards == memory_cards,
		"Removing the Memory owner leaves the completed game and earned chest intact")
	await _leave_players(app)
	app._show_result_leaderboard()
	check(not app._leaderboard_overlay.visible, "Another player cannot claim the deleted player's completed Memory result")

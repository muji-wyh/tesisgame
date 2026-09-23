extends SceneTree

var checks: int = 0
var failures: int = 0


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


func voice(index: int) -> Array:
	var embedding: Array = []
	embedding.resize(256)
	embedding.fill(0.0)
	embedding[index] = 1.0
	return embedding


func profiles() -> Array:
	var avatar := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	avatar.fill(Color("#57edff"))
	var png: String = Marshalls.raw_to_base64(avatar.save_png_to_buffer())
	return [
		{"id": "saved-ada", "name": "Ada", "emoji": "🐱", "embedding": voice(0), "avatar_png": png},
		{"id": "saved-ben", "name": "Ben", "emoji": "🐶", "embedding": voice(1), "avatar_png": "data:image/png;base64," + png},
		{"id": "saved-cleo", "name": "Cleo", "emoji": "🦊", "embedding": voice(2)}
	]


func event_for(view, session: String, id: String, embedding: Array) -> Dictionary:
	return {"type": "utterance", "sessionId": session, "eventId": id,
		"text": str(view.game.targets[0].word.text), "startMs": view.game.elapsed * 1000.0,
		"endMs": view.game.elapsed * 1000.0 + 10.0, "embedding": embedding}


func _run() -> void:
	var directory: String = "user://voice-pop-multiplayer-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.size = Vector2i(390, 844)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.choose_mode("pop")
	await settle()
	var view = app._pop
	var drains: Array[String] = []
	app._on_voice_profiles([JSON.stringify({"profiles": profiles(), "open": false})])
	check(view.voice_profile_count() == 3, "The host profile callback supplies the native saved-voice library")
	view.settling_requested.connect(func() -> void: drains.append(view.game.round_id))
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		view.stop()
		view.set_play_mode("single")
		view.remember_previous_round({})
		view._ready_prompt_seen = false
		app._configure_pop(71)
		view.set_process(false)
		view.set_reduced_motion(true)
		view.set_multiplayer_state({"status": "downloading", "loaded": 420, "total": 1000})
		check(view.multiplayer_label.text.contains("42%") and view.play_mode == "single", "Cold download reports real byte progress and leaves solo selected")
		check(view.game.phase == "ready" and view.game.remaining == 30.0, "Model preparation does not start the game timer")
		app._on_voice_state([true, true, "Listening."])
		view._advance_game(0.4)
		var remaining: float = view.game.remaining
		var target_ids: Array = view.game.targets.map(func(target: Dictionary): return target.uid)
		view.set_multiplayer_state({"status": "initializing", "loaded": 1000, "total": 1000})
		check(not view._mode_choices.visible and view.multiplayer_label.text.contains("Starting"), "A full download is still initializing, not ready")
		view.set_multiplayer_state({"status": "error", "message": "Warmup failed"})
		check(view.game.phase == "running" and view.game.remaining == remaining and view.mode_button.text == "Retry", "Preparation failure leaves the running solo round and timer intact")
		view.set_multiplayer_state({"status": "ready"})
		await settle()
		check(view._mode_choices.visible and view._mode_choices.modulate.a == 1.0, "Ready opens the reduced-motion choice bar immediately")
		check(view.game.phase == "running" and view.game.remaining == remaining
			and view.game.targets.map(func(target: Dictionary): return target.uid) == target_ids, "Ready never resets, pauses, or changes a solo round")
		check(view._arena.position.y >= view._mode_bar.position.y + view._mode_bar.size.y,
			"The choice bar has its own space above targets at %s" % dimensions)
		for button in [view.mode_button, view.solo_button, view.multiplayer_button]:
			check(button.is_visible_in_tree() and view.get_global_rect().grow(1).encloses(button.get_global_rect()),
				"Mode control %s fits at %s" % [button.name, dimensions])
		check(view.snapshot().controls.any(func(control: Dictionary) -> bool: return control.name == "StartMultiplayer"), "Accessible controls include the ready multiplayer action")
		view.solo_button.pressed.emit()
		check(not view._mode_choices.visible and view.game.remaining == remaining and view.play_mode == "single", "Continue solo dismisses the choices without changing play")
		check(view.snapshot().controls.any(func(control: Dictionary) -> bool: return control.name == "ChoosePopMode"),
			"The Mode entry retains accessible bounds at %s: bar=%s button=%s" % [dimensions, view._mode_bar.get_global_rect(), view.mode_button.get_global_rect()])
		view.set_multiplayer_state({"status": "ready"})
		check(not view._mode_choices.visible, "Repeated ready notifications do not reopen dismissed choices")
		view.mode_button.pressed.emit()
		check(view._mode_choices.visible, "The ready entry can reopen the mode choices")
		view.receive_transcript(str(view.game.targets[0].word.text))
		var solo_hits: int = view.game.hits
		var solo_score: int = view.game.score
		view.multiplayer_button.pressed.emit()
		view.set_process(false)
		check(view.play_mode == "multi" and view.game.play_mode == "multi" and view.game.phase == "ready"
			and view.game.remaining == 30.0 and view.game.hits == 0, "Start multiplayer creates a fresh round that waits for microphone startup")
		check(view.previous_round_summary.hits == solo_hits and view.previous_round_summary.score == solo_score
			and view._previous_summary_label.text.contains("Previous solo"), "Switching preserves and displays the solo score summary")
		view._process(2.0)
		check(view.game.remaining == 30.0 and view.game.targets.is_empty(), "Starting the multiplayer backend cannot consume round time")
		# Native headless tests have no microphone. Simulate the host's successful
		# model warmup and onStarted callback, then exercise the real JSON bridge.
		view.set_multiplayer_state({"status": "ready"})
		app._on_voice_state([true, true, "Listening on this device."])
		view._advance_game(0.25)
		app._pop_speech_active = true
		app._pop_bridge_session = "current-session"
		var first: Dictionary = event_for(view, "current-session", "p1-first", voice(0))
		var stale: Dictionary = first.duplicate(true)
		stale.sessionId = "previous-session"
		app._on_multiplayer_event([JSON.stringify(stale)])
		check(view.game.hits == 0, "A delayed previous-session event cannot score in the new round")
		var unknown: Dictionary = first.duplicate(true)
		unknown.eventId = "unknown-correct"
		unknown.embedding = voice(10)
		app._on_multiplayer_event([JSON.stringify(unknown)])
		var ambiguous: Dictionary = first.duplicate(true)
		ambiguous.eventId = "ambiguous-correct"
		ambiguous.embedding = voice(0)
		ambiguous.embedding[0] = sqrt(0.5)
		ambiguous.embedding[1] = sqrt(0.5)
		app._on_multiplayer_event([JSON.stringify(ambiguous)])
		check(view.game.hits == 0 and view.snapshot().players.is_empty(),
			"Unknown and ambiguous correct voices cannot join or consume a target")
		app._on_multiplayer_event([JSON.stringify(first)])
		app._on_multiplayer_event([JSON.stringify(first)])
		check(view.game.hits == 1 and view.snapshot().players.size() == 1 and view._player_labels[0].text == "1"
			and view.snapshot().players[0].id == "saved-ada" and view.snapshot().players[0].name == "Ada",
			"A deduplicated first hit joins the saved player and updates the HUD")
		check(view._player_avatars[0].texture != null and view._player_avatars[0].is_visible_in_tree()
			and view._last_hit_avatar.texture != null and view._last_hit.contains("Ada"),
			"Browser PNG avatars render in the HUD and hit feedback without relying on emoji fonts")
		check(not view.snapshot().players[0].has("embedding"), "The published HUD never exposes saved voice vectors")
		view.receive_transcript(first.text)
		check(view.game.hits == 1, "The legacy solo callback cannot score in multiplayer")
		view._advance_game(1.0)
		var second: Dictionary = event_for(view, "current-session", "p2-first", voice(1))
		app._on_multiplayer_event([JSON.stringify(second)])
		check(view.snapshot().players.size() == 2 and view._player_labels[1].text == "1"
			and view._player_labels[0].get_theme_color("font_color") != view._player_labels[1].get_theme_color("font_color"), "A second saved player receives a distinct stable color and hit count")
		view.pause()
		remaining = view.game.remaining
		view._advance_game(3.0)
		check(view.game.phase == "paused" and view.game.remaining == remaining and view.game.players_snapshot().size() == 2, "Runtime pause preserves players, scores, and remaining time")
		view.set_listening(true, true, "Listening on this device.")
		view._advance_game(1.0)
		var delayed: Dictionary = event_for(view, "current-session", "p3-delayed", voice(2))
		var drains_before: int = drains.size()
		view._advance_game(31.0)
		check(view.game.phase == "settling" and not view._results.visible and drains.size() == drains_before + 1, "The deadline flushes once and holds results while captured speech drains")
		app._on_multiplayer_event([JSON.stringify(delayed)])
		check(view.game.hits == 3 and view.game.players_snapshot().size() == 3, "A pre-deadline utterance can finish scoring during the drain")
		app._on_multiplayer_event([JSON.stringify({"type": "flushed", "sessionId": "old-session"})])
		check(view.game.phase == "settling", "An old flush callback cannot freeze the current round")
		app._on_multiplayer_event([JSON.stringify({"type": "flushed", "sessionId": "current-session"})])
		await settle()
		check(view.game.phase == "finished" and view._results.visible and not app._pop_speech_active, "A matching flush freezes results and releases speech")
		check(view.snapshot().ranking.size() == 3 and view.snapshot().ranking.all(func(player: Dictionary) -> bool: return player.rank == 1), "Equal hit counts share first place")
		check(view._result_body.find_child("Ranking1", true, false).tooltip_text.contains("tied"), "Results display tied ranks by player")
		for player in view.snapshot().ranking:
			var ranking_label: Control = view._result_body.find_child("Ranking%d" % int(player.index), true, false)
			check(view._results.get_global_rect().grow(1).encloses(ranking_label.get_global_rect()), "Every player's ranking is visible before scrolling at %s" % dimensions)
		check(view._result_body.find_child("RankingAvatar0", true, false).texture != null
			and view._result_body.find_child("Ranking0", true, false).text.contains("Ada"),
			"The leaderboard pairs the saved avatar with the player's name")
		check(view._results.get_global_rect().grow(1).encloses(view.replay_button.get_global_rect()), "Replay remains visible below the leaderboard at %s" % dimensions)
		var frozen_hits: int = view.game.hits
		app._on_multiplayer_event([JSON.stringify(delayed)])
		check(view.game.hits == frozen_hits, "Events after the result freeze cannot change the leaderboard")
		view.replay_button.pressed.emit()
		view.set_process(false)
		check(view.play_mode == "multi" and view.game.phase == "ready" and view.game.players_snapshot().is_empty(), "Replay remembers multiplayer while clearing per-round identities")
		view.set_multiplayer_state({"status": "ready"})
		view.set_listening(true, true, "Listening.")
		view._advance_game(30.0)
		view._advance_game(2.99)
		check(view.game.phase == "settling", "The fallback drain does not finish before three seconds")
		view._advance_game(0.01)
		check(view.game.phase == "finished", "The fallback drain always freezes after three seconds")
		view.mode_button.pressed.emit()
		view.solo_button.pressed.emit()
		view.set_process(false)
		check(view.play_mode == "single" and view.game.phase == "ready", "The mode entry can start a new solo round after multiplayer")
	await _test_profile_menu(app)
	await _test_profile_gate()
	app.queue_free()
	await settle()
	print("Voice Pop multiplayer scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_profile_menu(app) -> void:
	var original_size: Vector2i = root.size
	app._show_collection()
	await settle()
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		var users: Button = app._voice_profiles_button
		var scale: float = app.Style.ui_scale(app)
		check(users.is_visible_in_tree() and users.text == "Users" and app._focus_candidates().has(users),
			"The Users entry is visible and reachable from the More menu at %s" % dimensions)
		check(app.get_global_rect().grow(1).encloses(users.get_global_rect())
			and users.size.x * scale >= 44 and users.size.y * scale >= 44,
			"The Users entry fits the viewport with a 44 CSS-pixel touch target at %s" % dimensions)
		var neighbors: Array = [app._collection_title, app._collection_back]
		neighbors.append_array(app.theme_buttons)
		for neighbor in neighbors:
			if neighbor.is_visible_in_tree():
				check(not users.get_global_rect().intersects(neighbor.get_global_rect()),
					"The Users entry does not overlap %s at %s" % [neighbor.name, dimensions])
	var saved_profiles: Array = profiles()
	var original: Array = [app.model.cards.duplicate(true), app.model.theme_id, app.model.selected_id,
		app.model.hints_remaining, app.model.phase, app.playroom_state.preferred_theme_id]
	app._collection_back.grab_focus()
	app._on_voice_profiles([JSON.stringify({"open": true, "profiles": saved_profiles})])
	check(app._voice_profiles_open and app.collection_page.visible, "The profile overlay opens above the existing More menu")
	for button in [JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y, JOY_BUTTON_A]:
		for pressed in [true, false]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			event.pressed = pressed
			root.push_input(event, true)
		await process_frame
		check(app.collection_page.visible and app._voice_profiles_open
			and [app.model.cards, app.model.theme_id, app.model.selected_id, app.model.hints_remaining,
				app.model.phase, app.playroom_state.preferred_theme_id] == original,
			"Controller button %s cannot close More, switch worlds or change play behind the profile overlay" % button)
	for pressed in [true, false]:
		var cancel := InputEventKey.new()
		cancel.keycode = KEY_ESCAPE
		cancel.pressed = pressed
		root.push_input(cancel, true)
	await settle()
	check(app.collection_page.visible and app._voice_profiles_open,
		"Keyboard cancel cannot close the underlying More menu while voice users are open")
	app._on_voice_profiles([JSON.stringify({"open": false, "profiles": saved_profiles})])
	await settle()
	check(not app._voice_profiles_open and app.collection_page.visible and app._voice_profiles_button.has_focus(),
		"Closing voice users restores focus to Users and keeps More open")
	check(app._voice_profiles_button.tooltip_text.contains("3 of 10")
		and app._status_announcement.begins_with("Pip's room opened."),
		"A successful close reports the saved-user count and restores the More announcement")
	var error: String = "Could not save voice users. Try again."
	app._on_voice_profiles([JSON.stringify({"open": true, "profiles": saved_profiles, "error": error})])
	await settle()
	check(app.collection_page.visible and app._voice_profiles_open and app._status_announcement == error
		and app._voice_profiles_button.tooltip_text == error,
		"A profile error keeps More open and provides a persistent announcement and Users tooltip")
	app._on_voice_profiles([JSON.stringify({"open": false, "profiles": saved_profiles, "error": error})])
	await settle()
	check(not app._voice_profiles_open and app.collection_page.visible and app._voice_profiles_button.has_focus()
		and app._status_announcement == error and app._voice_profiles_button.tooltip_text == error,
		"An error close restores Users focus without replacing the error with the usual More announcement")
	check([app.model.cards, app.model.theme_id, app.model.selected_id, app.model.hints_remaining,
		app.model.phase, app.playroom_state.preferred_theme_id] == original,
		"Profile open, close and error callbacks preserve the active lesson and saved world")
	app._hide_collection()
	root.size = original_size
	await settle()


func _test_profile_gate() -> void:
	var view = load("res://scripts/voice_pop.gd").new()
	view.size = Vector2(390, 700)
	root.add_child(view)
	await settle()
	view.configure([{"id": "cat", "text": "cat", "image": "assets/images/words/cat.svg", "audio": "assets/audio/voice/word-cat.wav"}], {})
	view.set_multiplayer_state({"status": "ready"})
	var requests: Array[String] = []
	view.voice_profiles_requested.connect(func() -> void: requests.append("profiles"))
	view.request_listening.connect(func() -> void: requests.append("listen"))
	view.multiplayer_button.pressed.emit()
	check(requests == ["profiles"] and view.play_mode == "single" and view.game.remaining == 30.0,
		"An empty library offers enrollment without switching out of solo or starting audio")
	view.set_play_mode("multi")
	check(view.retry_button.text == "Add voice player" and not view.retry_button.disabled,
		"A remembered multiplayer mode with no profiles has an actionable enrollment gate")
	view.retry_button.pressed.emit()
	check(requests == ["profiles", "profiles"], "The empty-library gate requests enrollment instead of microphone listening")
	view.set_listening(true, true, "Listening")
	view._advance_game(2.0)
	check(view.game.phase == "ready" and view.game.remaining == 30.0 and not view.snapshot().listening,
		"Even a late microphone-start callback cannot start multiplayer with an empty library")
	check(view.set_voice_profiles(profiles()) and view.retry_button.text == "Start listening",
		"Supplying saved voices turns the enrollment gate into the normal listening action")
	view.retry_button.pressed.emit()
	check(requests.back() == "listen", "A populated library can request the local microphone")
	view.set_listening(true, true, "Listening")
	view.set_process(false)
	view._advance_game(0.1)
	var first: Dictionary = event_for(view, "local", "first", voice(0))
	first.round_id = view.game.round_id
	first.event_id = first.eventId
	first.start_ms = first.startMs
	first.end_ms = first.endMs
	view.receive_speech_event(first)
	var avatar: Texture2D = view._player_avatars[0].texture
	var updated: Array = profiles()
	updated[0].name = "Renamed Ada"
	updated[0].emoji = "🦁"
	updated[0].avatar_png = ""
	view.set_voice_profiles(updated)
	view.pause()
	view.set_listening(true, true, "Listening")
	view._update_hud()
	check(view.game.players_snapshot()[0].name == "Ada" and view._player_avatars[0].texture == avatar,
		"Editing profiles and pausing retain the current round's saved name and avatar")
	view.stop()
	view.configure([{"id": "cat", "text": "cat", "image": "assets/images/words/cat.svg", "audio": "assets/audio/voice/word-cat.wav"}], {})
	view.set_listening(true, true, "Listening")
	check(view.game._round_profiles[0].name == "Renamed Ada" and view.game._round_profiles[0].emoji == "🦁",
		"The new round picks up changed saved names and avatars")
	view.queue_free()
	await settle()

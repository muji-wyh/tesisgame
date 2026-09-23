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
		var first: Dictionary = event_for(view, "current-session", "p1-first", [1.0, 0.0, 0.0])
		var stale: Dictionary = first.duplicate(true)
		stale.sessionId = "previous-session"
		app._on_multiplayer_event([JSON.stringify(stale)])
		check(view.game.hits == 0, "A delayed previous-session event cannot score in the new round")
		app._on_multiplayer_event([JSON.stringify(first)])
		app._on_multiplayer_event([JSON.stringify(first)])
		check(view.game.hits == 1 and view.snapshot().players.size() == 1 and view._player_labels[0].text == "P1 · 1", "A deduplicated first hit creates P1 and updates the HUD")
		view.receive_transcript(first.text)
		check(view.game.hits == 1, "The legacy solo callback cannot score in multiplayer")
		view._advance_game(1.0)
		var second: Dictionary = event_for(view, "current-session", "p2-first", [0.0, 1.0, 0.0])
		app._on_multiplayer_event([JSON.stringify(second)])
		check(view.snapshot().players.size() == 2 and view._player_labels[1].text == "P2 · 1"
			and view._player_labels[0].get_theme_color("font_color") != view._player_labels[1].get_theme_color("font_color"), "P2 receives a distinct stable color and hit count")
		view.pause()
		remaining = view.game.remaining
		view._advance_game(3.0)
		check(view.game.phase == "paused" and view.game.remaining == remaining and view.game.players_snapshot().size() == 2, "Runtime pause preserves players, scores, and remaining time")
		view.set_listening(true, true, "Listening on this device.")
		view._advance_game(1.0)
		var delayed: Dictionary = event_for(view, "current-session", "p3-delayed", [0.0, 0.0, 1.0])
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
		check(view._result_body.find_child("RankingP2", true, false).text.contains("tied"), "Results display tied ranks by player")
		for player in view.snapshot().ranking:
			var ranking_label: Control = view._result_body.find_child("Ranking" + str(player.id), true, false)
			check(view._results.get_global_rect().grow(1).encloses(ranking_label.get_global_rect()), "Every player's ranking is visible before scrolling at %s" % dimensions)
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
	app.queue_free()
	await settle()
	print("Voice Pop multiplayer scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

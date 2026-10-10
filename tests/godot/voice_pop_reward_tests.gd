extends SceneTree

const PopView = preload("res://scripts/voice_pop.gd")
const Progress = preload("res://scripts/jelly_reward_progress.gd")
const WORDS := [{"id": "cat", "text": "cat", "image": "missing-cat.svg", "audio": "missing-cat.wav"}]

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
	for frame in range(5):
		await process_frame


func event_for(view, target: Dictionary, id: String) -> Dictionary:
	return {"event_id": id, "round_id": view.game.round_id, "target_uid": target.uid,
		"text": target.word.text, "stage": "final", "received_at_ms": 120.0}


func strike(view, marked: bool, id: String) -> Dictionary:
	for step in range(100):
		if not view.game.targets.is_empty():
			break
		view._advance_game(0.1)
	check(not view.game.targets.is_empty(), "The fixture reaches a live target")
	if view.game.targets.is_empty():
		return {}
	view.game.targets[0].chest = marked
	view._refresh_targets()
	var target: Dictionary = view.game.targets[0].duplicate(true)
	check(bool(view.snapshot().targets[0].chest) == marked, "The visible marker follows the accepted target identity")
	var event: Dictionary = event_for(view, target, id)
	check(view.receive_speech_event(JSON.stringify(event)), "A real recognized target is accepted")
	return event


func finish_reward(view) -> void:
	view.advance_reward_presentation(3.0)
	view._listening_tick_usec = -1


func _test_scene(dimensions: Vector2i) -> void:
	root.size = dimensions
	var view := PopView.new()
	root.add_child(view)
	view.size = Vector2(dimensions.x - 24, dimensions.y - 140) / PopView.Style.ui_scale(view)
	view.configure(WORDS, false, 5)
	view.set_process(false)
	view.set_listening(true, true, "Listening.")
	await settle()
	var awards: Array[int] = []
	var cues: Array[String] = []
	view.chest_earned.connect(func(count: int) -> void: awards.append(count))
	view.reward_cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	check(view.snapshot().fragment_count == 0 and view.snapshot().hud.chests.text == "0 / 4",
		"A new round shows the four-fragment goal")
	check(view.snapshot().hud.next_chest.text == "CHEST FRAGMENTS" and view.snapshot().hud.score.text == "0 POINTS",
		"Reward progress is independent of points")
	strike(view, false, "ordinary")
	check(view.game.score > 0 and view.game.fragment_count == 0 and cues.is_empty(), "Unmarked words score without awarding fragments")
	for index in range(14):
		var event: Dictionary = strike(view, true, "fragment-%d" % index)
		var state: Dictionary = view.snapshot()
		check(state.fragment_count == index + 1 and state.chest_fx.text == "+1 FRAGMENT", "Each marked card earns exactly one fragment")
		var serial: int = int(state.chest_fx.serial)
		check(not view.receive_speech_event(JSON.stringify(event)) and int(view.snapshot().chest_fx.serial) == serial,
			"Duplicate speech cannot repeat the fragment flight")
		if index + 1 in [4, 9, 14]:
			var tier: int = int(Progress.reward_progress(index + 1).chest_tier)
			check(view.reward_presentation_active() and view.game.phase == "running" and view.snapshot().listening,
				"A chest milestone keeps recognition and the round running")
			var remaining: float = view.game.remaining
			view._advance_game(0.1)
			check(is_equal_approx(view.game.remaining, remaining - 0.1), "The round clock continues during the milestone")
			view.advance_reward_presentation(1.4)
			check(view.snapshot().reward_presentation.revealed and view._displayed_chest_tier == tier,
				"The synchronized reveal updates the displayed chest tier")
			check(bool(view.snapshot().reward_presentation.confetti), "Unlocks and upgrades both play the shared full-screen confetti")
			check(view.clip_contents and view._reward_presentation._confetti.top_level,
				"Only confetti escapes arena clipping while live target and fragment effects stay bounded")
			check(not view._reward_icon.visible and view._hud.visible and not view._gate.visible,
				"The animated HUD chest replaces only its static icon while gameplay remains visible")
			var hits: int = view.game.hits
			strike(view, false, "during-confetti-%d" % tier)
			check(view.game.hits == hits + 1 and view.reward_presentation_active(), "A recognized word still scores while confetti is visible")
			finish_reward(view)
			check(not view.reward_presentation_active() and view.game.phase == "running" and view._listening,
				"Completion leaves the same microphone session and round running")
			check(view._reward_icon.visible, "The static HUD chest returns after its inline animation")
		else:
			check(not view.reward_presentation_active() and view.game.phase == "running", "Ordinary fragments leave play running")
	check(awards == [1, 1, 1], "Unlock and upgrades present once while keeping a single chest")
	check(cues.count("loot") == 14 and cues.count("assemble") == 3 and cues.count("reward") == 3,
		"Every earned fragment and every milestone has its own sound cue")
	view._advance_game(view.game.remaining + 1.0)
	await settle()
	var result: Dictionary = view.snapshot().results_rewards
	check(result.earned == 1 and result.chest_tier == 3 and result.fragment_count == 14,
		"Results show the final upgraded chest and exact fragments")
	check(view.chests_button.text == "Open chest" and not view.chests_button.disabled, "Only one earned chest is offered")
	var viewport: Rect2 = view._results.get_global_rect()
	for button in [view.chests_button, view.replay_button]:
		check(viewport.grow(1.0).encloses(button.get_global_rect()), "Both actions fit without scrolling at " + str(dimensions))
	view.configure(WORDS, true, 5)
	view.set_process(false)
	view.set_listening(true, true, "Listening.")
	view._advance_game(view.game.remaining + 1.0)
	await settle()
	check(view.chests_button.disabled and view.snapshot().results_rewards.earned == 0, "A zero-fragment round cannot open a new chest")
	view.set_pending_chests(2)
	check(not view.chests_button.disabled and view.chests_button.text == "Open chests"
		and view.snapshot().results_rewards.earned == 0, "Older unopened chests remain accessible without inflating this round's result")
	view.queue_free()
	await settle()


func _test_interruption() -> void:
	var view := PopView.new()
	root.add_child(view)
	view.size = Vector2(640, 480)
	view.configure(WORDS, false, 7)
	view.set_process(false)
	view.set_listening(true, true, "Listening.")
	for index in range(4):
		strike(view, true, "pause-%d" % index)
	view.advance_reward_presentation(1.5)
	check(view.snapshot().reward_presentation.confetti, "The interruption fixture reaches visible confetti")
	var elapsed: float = float(view.snapshot().reward_presentation.elapsed)
	view.pause()
	view.advance_reward_presentation(5.0)
	check(view.snapshot().reward_presentation.elapsed == elapsed and not view.snapshot().reward_presentation.visible,
		"A menu pause freezes the timeline and reveals the listening recovery gate")
	for reduce: bool in [true, false]:
		view.set_reduced_motion(reduce)
		check(not view.snapshot().reward_presentation.visible and not view.snapshot().reward_presentation.confetti
			and view.snapshot().reward_presentation.elapsed == elapsed,
			"Motion preferences cannot reveal a paused chest over the listening recovery gate")
	view.set_listening(true, true, "Listening.")
	check(not view.snapshot().reward_paused and view.game.phase == "running" and view.snapshot().listening
		and view.snapshot().reward_presentation.visible, "Resume continues gameplay and the presentation together")
	view.hide()
	view.advance_reward_presentation(4.0)
	check(view.snapshot().reward_paused and view.snapshot().reward_presentation.elapsed == elapsed
		and not view._reward_presentation._confetti.is_visible_in_tree(),
		"Hiding behind a page or collection removes top-level confetti and pauses the active milestone")
	view.show()
	view.set_process(false)
	view.set_listening(true, true, "Listening.")
	view.set_reduced_motion(true)
	view.advance_reward_presentation(0.5)
	check(view.snapshot().reward_presentation.reduced_motion and not view.snapshot().reward_presentation.confetti,
		"Reduced motion preserves the milestone without motion or confetti")
	view.stop()
	view.advance_reward_presentation(4.0)
	check(not view._listening and not view.reward_presentation_active() and view._loot_flights.is_empty(),
		"Leaving cancels presentation and flights without restarting the microphone")
	view.configure(WORDS, false, 9)
	view.advance_reward_presentation(4.0)
	check(not view._listening and view.game.fragment_count == 0 and view.game.phase == "ready", "Old presentation callbacks cannot affect a new round")
	view.queue_free()
	await settle()


func _test_callback_reentry() -> void:
	var view := PopView.new()
	root.add_child(view)
	view.size = Vector2(640, 480)
	view.configure(WORDS, false, 7)
	view.set_process(false)
	view.set_listening(true, true, "Listening.")
	for index in range(4):
		strike(view, true, "settle-%d" % index)
	var finished: Array[Dictionary] = []
	view.round_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	var finish_on_cue: Callable = func(_cue: String) -> void: view.finish_round()
	view.reward_cue_requested.connect(finish_on_cue)
	view.advance_reward_presentation(3.0)
	view.finish_round()
	check(finished.size() == 1 and finished[0].chest_tier == 1 and finished[0].chest_count == 1,
		"Settlement inside a cue saves the accepted final tier exactly once")
	check(not view._listening and not view.reward_presentation_active(), "Settlement inside a cue never restarts recognition")
	view.reward_cue_requested.disconnect(finish_on_cue)
	view.configure(WORDS, false, 8)
	view.set_process(false)
	view.set_listening(true, true, "Listening.")
	var configure_on_hit: Callable = func(_word: Dictionary) -> void: view.configure(WORDS, false, 9)
	view.hit.connect(configure_on_hit)
	strike(view, true, "replace-on-hit")
	check(view.game.phase == "ready" and view.game.fragment_count == 0 and not view.reward_presentation_active()
		and view._loot_flights.is_empty(), "A hit callback replacing the round leaves no old fragment visuals or milestone")
	view.hit.disconnect(configure_on_hit)
	view.queue_free()
	await settle()


func _test_live_queue_and_expiry() -> void:
	var view := PopView.new()
	root.add_child(view)
	view.size = Vector2(640, 480)
	view.configure(WORDS, false, 15)
	view.set_process(false)
	view.set_listening(true, true, "Listening.")
	for index in range(9):
		strike(view, true, "queue-%d" % index)
	check(view.game.fragment_count == 9 and view.game.chest_tier == 2
		and int(view.snapshot().reward_presentation.queued) == 2 and view._listening,
		"Continuous recognized words can queue the next chest upgrade during its unlock animation")
	view.advance_reward_presentation(1.5)
	view._advance_game(0.1)
	check(view.game.phase == "running" and view.snapshot().reward_presentation.confetti,
		"Targets and the live clock continue under the queued milestone confetti")
	var finished: Array[Dictionary] = []
	view.round_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	view._advance_game(view.game.remaining + 1.0)
	view.advance_reward_presentation(10.0)
	check(finished.size() == 1 and finished[0].chest_tier == 2 and finished[0].chest_count == 1,
		"Natural expiry during confetti settles the final accepted chest exactly once")
	check(not view.reward_presentation_active() and not view.snapshot().reward_presentation.confetti
		and view._loot_flights.is_empty() and not view._listening and view._results.visible,
		"Natural expiry clears old milestone visuals before presenting the full results")
	check(view.controls().has(view.chests_button) and view.default_focus() == view.chests_button,
		"Cancelled milestone animations cannot block results controls")
	view.queue_free()
	await settle()


func _test_listening_recovery() -> void:
	var view := PopView.new()
	root.add_child(view)
	view.size = Vector2(640, 480)
	view.configure(WORDS, false, 17)
	view.set_process(false)
	view.set_listening(true, true, "Listening.")
	for index in range(4):
		strike(view, true, "listen-%d" % index)
	view.advance_reward_presentation(1.5)
	var elapsed: float = float(view.snapshot().reward_presentation.elapsed)
	var round_id: String = view.game.round_id
	view.set_listening(true, false, "Listening paused. Continuing…")
	view.advance_reward_presentation(5.0)
	check(view._reconnecting and view.game.phase == "paused" and not view._gate.visible
		and view._reward_icon.visible
		and not view.snapshot().reward_presentation.visible
		and float(view.snapshot().reward_presentation.elapsed) == elapsed,
		"Recognizer rollover freezes the milestone without covering the retained playfield")
	view.set_listening(true, true, "Listening.")
	check(view._listening and view.game.phase == "running" and view.snapshot().reward_presentation.confetti
		and not view._reward_icon.visible
		and view.game.round_id == round_id, "Recognizer rollover resumes the same game and milestone together")
	view.set_listening(false, false, "Microphone unavailable.")
	view.advance_reward_presentation(5.0)
	check(view._gate.visible and view.controls().has(view.retry_button)
		and view.default_focus() == view.retry_button and not view._listening
		and float(view.snapshot().reward_presentation.elapsed) == elapsed,
		"A real microphone error exposes recovery controls and cannot be resumed by a reward callback")
	view.set_listening(true, true, "Listening.")
	var hits: int = view.game.hits
	strike(view, false, "listen-recovered")
	check(view.game.hits == hits + 1 and view.reward_presentation_active(),
		"Successful microphone recovery accepts answers while the restored confetti finishes")
	view.stop()
	view.queue_free()
	await settle()


func _run() -> void:
	for dimensions in [Vector2i(320, 568), Vector2i(844, 390), Vector2i(1366, 768)]:
		await _test_scene(dimensions)
	await _test_interruption()
	await _test_callback_reentry()
	await _test_live_queue_and_expiry()
	await _test_listening_recovery()
	print("Voice Pop fragment presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

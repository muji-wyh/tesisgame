extends SceneTree

const Model = preload("res://scripts/voice_pop_model.gd")
const PopView = preload("res://scripts/voice_pop.gd")
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


func event_for(game, target: Dictionary, id: String) -> Dictionary:
	return {"event_id": id, "round_id": game.round_id, "target_uid": target.uid,
		"text": target.word.text, "stage": "final", "received_at_ms": 120.0}


func next_target(game) -> Dictionary:
	for step in range(100):
		if not game.targets.is_empty():
			return game.targets[0].duplicate(true)
		game.advance(0.1)
	return {}


func _test_model() -> void:
	var game := Model.new()
	game.configure(WORDS, 5)
	check(game.chest_count == 0 and game.summary().chest_count == 0 and game.next_chest_score() == 100,
		"Every prepared round begins with zero chests and a visible first goal")
	check(game.chest_progress() == 0.0 and game.summary().chest_thresholds == [100, 200, 300],
		"The reward ladder exposes its three score milestones")
	game.start()
	for index in range(6):
		var target: Dictionary = next_target(game)
		var struck: Array = game.hit_speech_event(event_for(game, target, "below-%d" % index))
		check(struck.size() == 1 and not struck[0].chest_awarded and struck[0].chest_awards == 0,
			"A valid hit below the threshold does not invent a chest")
	check(game.score == 90 and game.chest_count == 0 and is_equal_approx(game.chest_progress(), 0.9),
		"Points below 100 provide progress without a premature chest")
	check(game.hit_transcript("dog").is_empty() and game.chest_count == 0,
		"Unmatched speech cannot award a chest")
	var expired: Dictionary = next_target(game)
	game.advance(float(expired.lifetime))
	check(game.misses > 0 and game.combo == 0 and game.chest_count == 0,
		"A miss resets the combo without earning or removing chests")
	var first: Dictionary = next_target(game)
	var first_event: Dictionary = event_for(game, first, "first-chest")
	var earned: Array = game.hit_speech_event(first_event)
	check(game.score == 100 and game.chest_count == 1 and earned.size() == 1
		and earned[0].chest_awarded and earned[0].chest_awards == 1 and earned[0].chest_count == 1,
		"A valid hit at exactly 100 points earns the first chest once")
	check(game.next_chest_score() == 200 and game.chest_progress() == 0.0,
		"The next progress interval begins after an earned chest")
	check(game.hit_speech_event(first_event).is_empty() and game.chest_count == 1,
		"A repeated accepted speech event never duplicates a chest")
	var paused: Dictionary = next_target(game)
	var paused_event: Dictionary = event_for(game, paused, "paused-chest")
	var previous_score: int = game.score
	game.pause()
	game.advance(10.0)
	check(game.hit_speech_event(paused_event).is_empty() and game.score == previous_score and game.chest_count == 1,
		"Pausing retains earned chests and rejects speech without consuming it")
	game.resume()
	check(game.hit_speech_event(paused_event).size() == 1 and game.chest_count == 1,
		"Resuming keeps the earned chest and accepts a fresh valid hit")
	var award_totals: Array[int] = [1]
	for index in range(25):
		var target: Dictionary = next_target(game)
		var before: int = game.chest_count
		var struck: Array = game.hit_speech_event(event_for(game, target, "more-%d" % index))
		check(struck.size() == 1, "Additional reward points come from real accepted targets")
		if struck.is_empty():
			continue
		if bool(struck[0].chest_awarded):
			award_totals.append(int(struck[0].chest_count))
		check(int(struck[0].chest_awards) == game.chest_count - before and game.chest_count <= Model.MAX_CHESTS,
			"Each hit reports only newly earned chests within the cap")
	check(award_totals == [1, 2, 3] and game.score > 400 and game.chest_count == 3,
		"The 200 and 300 point milestones award once and higher scores stay capped at three")
	check(game.next_chest_score() == 0 and game.chest_progress() == 1.0,
		"The completed ladder has no fourth score goal")
	game.advance(game.remaining + 1.0)
	var completed: Dictionary = game.summary()
	check(game.phase == "finished" and completed.chest_count == 3,
		"Natural round completion carries every earned chest into results")
	check(game.hit_speech_event(first_event).is_empty() and game.summary() == completed,
		"Late speech cannot change a completed reward outcome")
	game.start()
	check(game.chest_count == 0 and game.score == 0 and game.next_chest_score() == 100,
		"Replaying resets reward chances to zero")
	game.configure(WORDS, 8)
	check(game.chest_count == 0 and game.chest_progress() == 0.0,
		"Reconfiguration cannot carry chests into another round")


func _test_scene(dimensions: Vector2i) -> void:
	root.size = dimensions
	var view := PopView.new()
	root.add_child(view)
	view.size = Vector2(dimensions)
	view.configure(WORDS, false, 5)
	view.set_process(false)
	var awards: Array[int] = []
	var requests: Array[bool] = []
	view.chest_earned.connect(func(count: int) -> void: awards.append(count))
	view.chests_requested.connect(func() -> void: requests.append(true))
	view.set_listening(true, true, "Listening.")
	view.set_process(false)
	await settle()
	check(view.snapshot().chest_count == 0 and view.snapshot().hud.chests.text == "CHESTS 0 / 3",
		"The visible round starts with zero chest chances at " + str(dimensions))
	check(view.snapshot().hud.score.text == "0 POINTS" and view.snapshot().hud.next_chest.text == "NEXT CHEST AT 100",
		"The HUD explains score and the next chest milestone")
	check(view.get_global_rect().grow(1.0).encloses(view._reward_hud.get_global_rect()),
		"The score and chest panel fits the playfield at " + str(dimensions))
	check(view._score_label.get_global_rect().end.x <= view._chest_count_label.get_global_rect().position.x + 1.0,
		"Points and chest totals have separate readable bounds")
	for index in range(22):
		if view.game.targets.is_empty():
			view._advance_game(0.66)
		if view.game.targets.is_empty():
			continue
		var target: Dictionary = view.game.targets[0].duplicate(true)
		var before: int = view.game.chest_count
		var event: Dictionary = event_for(view.game, target, "scene-%d" % index)
		check(view.receive_speech_event(JSON.stringify(event)), "A real speech hit scores through the visible view")
		if view.game.chest_count > before:
			var snapshot: Dictionary = view.snapshot()
			check(snapshot.chest_fx.active and snapshot.chest_fx.text == "+1 CHEST"
				and snapshot.chest_fx.count == view.game.chest_count and snapshot.chest_fx.above_targets,
				"Each earned chest gets a visible foreground reward badge")
			var serial: int = snapshot.chest_fx.serial
			check(not view.receive_speech_event(JSON.stringify(event)) and view.snapshot().chest_fx.serial == serial,
				"Repeated speech cannot replay the chest effect")
			view._advance_hud_feedback(0.2)
			check(not view._chest_badge.scale.is_equal_approx(Vector2.ONE),
				"Normal motion visibly animates the earned chest badge")
			view.set_reduced_motion(true)
			check(view.snapshot().chest_fx.active and view.snapshot().chest_fx.reduced_motion
				and view._chest_badge.scale.is_equal_approx(Vector2.ONE)
				and view._chest_badge.position.is_equal_approx(view._chest_badge_anchor),
				"Reduced motion keeps the clear earned message without travel or scaling")
			view.set_reduced_motion(false)
			if view.game.chest_count == 1:
				view.pause()
				check(view.game.chest_count == 1 and not view.snapshot().chest_fx.active,
					"Pausing keeps the reward and clears the transient badge")
				view.set_listening(true, true, "Listening.")
	check(awards == [1, 2, 3] and view.game.chest_count == 3 and view.snapshot().chest_fx.serial == 3,
		"The scene announces exactly the three earned opportunities")
	check(view.snapshot().hud.next_chest.text == "ALL 3 CHESTS EARNED",
		"The completed ladder clearly communicates the maximum")
	view._advance_hud_feedback(PopView.CHEST_FX_DURATION + 0.1)
	check(not view.snapshot().chest_fx.active and view.game.chest_count == 3,
		"Finishing chest feedback does not consume the chest")
	view._advance_game(view.game.remaining + 1.0)
	await settle()
	check(view.game.phase == "finished" and not view.chests_button.disabled and view.chests_button.text == "Open chests (3)",
		"The final result exposes every earned chest")
	check(view.controls().has(view.chests_button) and view.default_focus() == view.chests_button,
		"The earned reward action participates in keyboard navigation")
	for button in [view.chests_button, view.replay_button]:
		check(view._results.get_global_rect().grow(1.0).encloses(button.get_global_rect()),
			"Both result actions fit without initial scrolling at " + str(dimensions))
	var completed: Dictionary = view.game.summary()
	view.interaction_allowed = func() -> bool: return false
	view.chests_button.pressed.emit()
	check(requests.is_empty(), "A covering modal blocks chest navigation")
	view.interaction_allowed = Callable()
	view.chests_button.pressed.emit()
	check(requests.size() == 1 and view.game.summary() == completed,
		"Opening the chest room emits navigation without consuming or changing earned results")
	view.hide()
	view.chests_button.pressed.emit()
	check(requests.size() == 1, "A hidden result cannot request a second chest room")
	view.show()
	view.set_process(false)
	await settle()
	check(view.game.summary() == completed and view.chests_button.is_visible_in_tree(),
		"Returning from an external chest panel retains the finished result")
	view.configure(WORDS, true, 5)
	view.set_process(false)
	view.set_listening(true, true, "Listening.")
	view._advance_game(view.game.remaining + 1.0)
	await settle()
	check(view.chests_button.disabled and view.chests_button.text == "Open chests (0)"
		and not view.controls().has(view.chests_button) and view.default_focus() == view.replay_button,
		"A zero-point result disables chest entry while preserving Play again")
	view.chests_button.pressed.emit()
	check(requests.size() == 1 and not view.snapshot().chest_fx.active,
		"A zero-chest replay cannot navigate or reuse an old celebration")
	view.queue_free()
	await settle()


func _test_bonus_layout(dimensions: Vector2i, field: Vector2) -> void:
	root.size = dimensions
	var view := PopView.new()
	root.add_child(view)
	# The captured playfields are CSS pixels; this native fixture keeps project scaling.
	var scale: float = PopView.Style.ui_scale(view)
	view.size = field / scale
	view.configure(WORDS, false, 5)
	view.set_listening(true, true, "Listening.")
	view.set_process(false)
	await settle()
	for index in range(7):
		if view.game.targets.is_empty():
			view._advance_game(0.66)
		if not view.game.targets.is_empty():
			var target: Dictionary = view.game.targets[0].duplicate(true)
			view.receive_speech_event(JSON.stringify(event_for(view.game, target, "layout-%d" % index)))
	check(view.game.chest_count == 1 and view._hud_bonus_amount > 0,
		"Layout feedback comes from real time and chest awards at " + str(dimensions))
	var field_bounds := Rect2(Vector2.ZERO, view.size).grow(1.0 / scale)
	for reduced in [false, true]:
		view.set_reduced_motion(reduced)
		# Awards can start on different hits, so test their independent animation ages.
		for bonus_age in [0.0, 0.16, 0.38, 1.3, 1.55, 1.75]:
			for chest_age in [0.0, 0.2, 0.38, 1.5, 1.85, 2.15]:
				view._hud_bonus_age = bonus_age
				view._chest_fx_age = chest_age
				view._apply_hud_feedback()
				var time_bounds: Rect2 = view._time_bonus_badge.get_transform() * Rect2(Vector2.ZERO, view._time_bonus_badge.size)
				var chest_bounds: Rect2 = view._chest_badge.get_transform() * Rect2(Vector2.ZERO, view._chest_badge.size)
				var context: String = "%s, reduced=%s, time=%.2f, chest=%.2f" % [dimensions, reduced, bonus_age, chest_age]
				check(view._time_bonus_badge.visible and view._chest_badge.visible,
					"Both earned messages remain visible: " + context)
				check(not time_bounds.grow(3.0 / scale).intersects(chest_bounds.grow(3.0 / scale)),
					"Time and chest messages stay separate throughout their animations: " + context)
				check(field_bounds.encloses(time_bounds) and field_bounds.encloses(chest_bounds),
					"Both animated messages fit the actual playfield: " + context)
				if chest_age < 1.55:
					check(not chest_bounds.intersects(view._reward_hud.get_rect()),
						"The readable chest celebration leaves the score panel clear: " + context)
	view.queue_free()
	await settle()


func _run() -> void:
	_test_model()
	for dimensions in [Vector2i(320, 568), Vector2i(844, 390), Vector2i(1366, 768)]:
		await _test_scene(dimensions)
	for layout in [
		[Vector2i(320, 568), Vector2(296, 428)],
		[Vector2i(390, 844), Vector2(366, 704)],
		[Vector2i(460, 568), Vector2(436, 428)],
		[Vector2i(468, 568), Vector2(444, 428)],
		[Vector2i(667, 375), Vector2(643, 287)],
		[Vector2i(844, 390), Vector2(820, 302)],
		[Vector2i(1366, 768), Vector2(1342, 680)],
	]:
		await _test_bonus_layout(layout[0], layout[1])
	print("Voice Pop rewards: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

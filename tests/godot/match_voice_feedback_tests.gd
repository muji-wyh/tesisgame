extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(5):
		await process_frame


func _until(predicate: Callable, seconds: float = 2.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(predicate.call())


func _words(app) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(str(card.word.id) + ":image").is_empty():
			result.append(card.word)
	return result


func _new_round(app, reduce: bool = false) -> void:
	check(app.new_round(21, true, "", "match"), "The fixture starts a fresh Match round")
	app.set_reduced_motion(reduce)
	# Advance the effect explicitly; its real feedback Timer is paused separately.
	app.set_process(false)
	await _settle()
	check(_words(app).size() == 5, "The fixture contains five complete, real word-picture pairs")


func _listen(app) -> void:
	app._on_voice_state([true, true, "Listening"])
	check(app._voice_mode and app._voice_listening, "The real speech-state callback enables Match listening")


func _sound_playing(app) -> bool:
	return app.audio.match_voice_hit != null and app.audio.match_voice_hit.playing


func _sound_request(app) -> int:
	return int(app.audio._playback_requests.get(app.audio.match_voice_hit, -1))


func _path_global(link) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in link.path:
		points.append(link.get_global_transform() * point)
	return points


func _check_contacts(app, word: Dictionary, context: String) -> void:
	var link = app._voice_match_link
	var picture: Control = app.cards[str(word.id) + ":image"]
	var text_card: Control = app.cards[str(word.id) + ":word"]
	check(link != app._hint_link and link.get_parent() == app._match_playfield,
		context + ": spoken feedback uses its own link in the actual Match playfield")
	check(link.active and link.is_visible_in_tree() and link.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		context + ": the feedback arc is visible without intercepting card input")
	check(link.source == picture and link.target == text_card,
		context + ": electricity joins the recognized picture to its matching word")
	var points: PackedVector2Array = _path_global(link)
	check(points.size() == 2, context + ": both real card contacts exist")
	if points.size() != 2:
		return
	var picture_bounds: Rect2 = picture.get_global_rect()
	var word_bounds: Rect2 = text_card.get_global_rect()
	var direction: Vector2 = (word_bounds.get_center() - picture_bounds.get_center()).normalized()
	check(picture_bounds.has_point(points[0]) and word_bounds.has_point(points[1]),
		context + ": the arc reaches inside both matching cards")
	check(absf((points[0] - picture_bounds.get_center()).cross(direction)) < 0.5
		and absf((points[1] - word_bounds.get_center()).cross(direction)) < 0.5
		and (points[1] - points[0]).dot(direction) > 0.0,
		context + ": resized contacts stay on the real picture-to-word center line")
	check(link.colors == app.Style.hint_palette(app.Data.theme(app.model.theme_id)),
		context + ": spoken feedback shares the current world's electric palette")


func _check_cleared(app, context: String) -> void:
	check(not app._voice_match_link.active and not app._voice_match_link.visible
		and is_zero_approx(app._voice_match_left), context + ": the timed arc is fully cleared")
	check(not _sound_playing(app), context + ": the dedicated electrical cue has stopped")


func _test_callback_and_ignored_results(app) -> void:
	await _new_round(app)
	var word: Dictionary = _words(app)[0]
	app._on_voice_result([word.text, true])
	check(app.model.successes == 0 and not app._voice_match_link.active,
		"A final result before listening cannot score or start an arc")
	app._on_voice_state([true, false, "Starting"])
	app._on_voice_result([word.text, true])
	check(app.model.successes == 0 and not _sound_playing(app),
		"A final result while the microphone is not listening stays silent")
	_listen(app)
	for result in [[word.text, false], ["unrecognizedword", true], ["", true]]:
		app._on_voice_result(result)
		check(app.model.successes == 0 and app.model.phase == "waiting"
			and app._speech_queue.is_empty() and not app._voice_match_link.active and not _sound_playing(app),
			"Interim, unknown and empty results cannot create scoring or feedback")
	app._request_hint()
	var hints_left: int = app.model.hints_remaining
	check(hints_left == 2 and app._hint_link.active, "A real paid hint is active before the spoken success")
	app._on_voice_result(["I see a " + str(word.text), true])
	app.feedback_timer.paused = true
	check(app.model.successes == 1 and app.model.mistakes == 0 and app.model.phase == "feedback"
		and app.model.feedback_ids == [str(word.id) + ":word", str(word.id) + ":image"],
		"The browser's final callback scores exactly its real word-picture pair")
	check(is_equal_approx(app._voice_match_left, 1.0) and is_equal_approx(app.feedback_timer.wait_time, 1.0)
		and not app.feedback_timer.is_stopped(), "Spoken success starts a full one-second effect and feedback Timer")
	check(app.model.hints_remaining == hints_left and app.model.hint_ids.is_empty() and not app._hint_link.active,
		"A success clears the old hint without spending or refunding another hint")
	check(_sound_playing(app) and app.audio.match_voice_hit.stream == load(Audio.MATCH_VOICE_HIT_PATH),
		"The electrical cue starts with the actual successful final callback")
	check(not app.audio.music.playing and not app.audio.voice.playing,
		"Electrical feedback keeps music and spoken playback quiet while the microphone is active")
	await _settle()
	_check_contacts(app, word, "Final callback")
	var request: int = _sound_request(app)
	app._advance_voice_match_feedback(0.4)
	for listening in [false, true]:
		app._on_voice_state([true, listening, "Listening" if listening else "Reconnecting"])
		check(app._voice_match_link.active and _sound_request(app) == request
			and is_equal_approx(app._voice_match_left, 0.6),
			"Recognizer rollover preserves the already accepted match's arc and cue")
	for result in [[word.text, true], [str(word.text) + " " + str(word.text), true], [word.text, false], ["unrecognizedword", true]]:
		app._on_voice_result(result)
		check(app.model.successes == 1 and app._speech_queue.is_empty() and _sound_request(app) == request
			and is_equal_approx(app._voice_match_left, 0.6),
			"Duplicate or irrelevant recognition cannot replay the cue, extend the arc or score again")
	app._advance_voice_match_feedback(0.59)
	check(app._voice_match_link.active and app.model.phase == "feedback", "The success arc remains present at 990 milliseconds")
	app._advance_voice_match_feedback(0.02)
	_check_cleared(app, "One-second expiry")
	app._resolve_feedback()
	check(app.model.phase == "waiting" and app.model.successes == 1, "The completed feedback resolves its single match normally")


func _test_resize_and_reduced_motion(app) -> void:
	root.size = Vector2i(480, 900)
	await _new_round(app, true)
	_listen(app)
	var word: Dictionary = _words(app)[0]
	app._on_voice_result([word.text, true])
	app.feedback_timer.paused = true
	await _settle()
	_check_contacts(app, word, "Portrait reduced motion")
	var link = app._voice_match_link
	var phase: float = link.phase
	var portrait_path: PackedVector2Array = _path_global(link)
	var picture_instance: int = link.source.get_instance_id()
	var word_instance: int = link.target.get_instance_id()
	check(link.reduced_motion and not link.is_processing(), "Reduced motion shows a static electric connection")
	app._advance_voice_match_feedback(0.5)
	root.size = Vector2i(900, 480)
	await _settle()
	_check_contacts(app, word, "Landscape reduced motion")
	check(_path_global(link) != portrait_path and link.source.get_instance_id() == picture_instance
		and link.target.get_instance_id() == word_instance,
		"Resize moves both contacts without replacing the matched cards")
	check(is_equal_approx(link.phase, phase) and is_equal_approx(app._voice_match_left, 0.5),
		"Resize keeps the reduced-motion arc static and preserves its remaining lifetime")
	app.choose_theme("space")
	_check_contacts(app, word, "Theme changed during success")
	check(is_equal_approx(app._voice_match_left, 0.5), "A theme change cannot restart the one-second feedback")
	app._advance_voice_match_feedback(0.51)
	_check_cleared(app, "Reduced-motion expiry")
	app._resolve_feedback()
	check(app.model.phase == "waiting" and app.model.successes == 1,
		"Reduced motion still completes the successful pair after its full display interval")
	root.size = Vector2i(480, 900)


func _test_lifecycle_cancellation(app) -> void:
	for action in ["voice_off", "speech_disabled", "new_round", "memory", "background", "menu"]:
		await _new_round(app)
		_listen(app)
		var words: Array[Dictionary] = _words(app)
		app._on_voice_result([str(words[0].text) + " " + str(words[1].text), true])
		app.feedback_timer.paused = true
		check(app._voice_match_link.active and _sound_playing(app) and app._speech_queue.size() == 1,
			action + ": a real success has an active cue and another queued pair before leaving")
		match action:
			"voice_off": app._stop_voice()
			"speech_disabled": app._on_voice_state([false, false, "Stopped"])
			"new_round": app.new_round(37, true, "", "match")
			"memory": app.choose_mode("memory")
			"background": app.on_page_hidden()
			"menu": app._show_collection()
		_check_cleared(app, action)
		check(app._speech_queue.is_empty(), action + ": leaving recognition discards queued pairs")
		var successes: int = app.model.successes
		app._on_voice_result([words[1].text, true])
		app._advance_voice_match_feedback(2.0)
		check(app.model.successes == successes and not app._voice_match_link.active and not _sound_playing(app),
			action + ": a late callback or animation tick cannot revive the effect or consume stale speech")
		if action == "background":
			app.on_page_visible()
		elif action == "menu":
			app._hide_collection()
		_check_cleared(app, action + " after return")


func _test_manual_timing(app) -> void:
	await _new_round(app, true)
	var word: Dictionary = _words(app)[0]
	app._select_card(str(word.id) + ":word")
	app._select_card(str(word.id) + ":image")
	app.feedback_timer.paused = true
	check(app.model.phase == "feedback" and app.model.successes == 1
		and is_equal_approx(app.feedback_timer.wait_time, 0.7), "Manual matching retains its existing 0.7-second feedback interval")
	_check_cleared(app, "Manual success")
	app._resolve_feedback()
	check(app.model.phase == "waiting" and app.model.successes == 1, "Manual success still resolves through the existing path")


func _test_queued_pairs_and_final_timer(app) -> void:
	await _new_round(app)
	_listen(app)
	var words: Array[Dictionary] = _words(app)
	var transcript := PackedStringArray()
	for word in words:
		transcript.append(word.text)
	app._on_voice_result([" ".join(transcript), true])
	app.feedback_timer.paused = true
	for index in range(words.size()):
		var word: Dictionary = words[index]
		check(app.model.phase == "feedback" and app.model.successes == index + 1
			and app.model.feedback_ids == [str(word.id) + ":word", str(word.id) + ":image"]
			and app._speech_queue.size() == words.size() - index - 1,
			"Queued pair %d scores once and preserves transcript order" % (index + 1))
		check(is_equal_approx(app._voice_match_left, 1.0) and is_equal_approx(app.feedback_timer.wait_time, 1.0),
			"Queued pair %d receives a fresh full second" % (index + 1))
		_check_contacts(app, word, "Queued pair %d" % (index + 1))
		check(_sound_playing(app), "Queued pair %d begins its own electrical cue" % (index + 1))
		var request: int = _sound_request(app)
		var pending: Array = app._speech_queue.duplicate()
		app._on_voice_result([" ".join(transcript), true])
		check(app._speech_queue == pending and _sound_request(app) == request,
			"A repeated transcript neither duplicates queued pairs nor restarts their sound")
		if index == words.size() - 1:
			break
		app._advance_voice_match_feedback(0.99)
		check(app._voice_match_link.active and app.model.successes == index + 1,
			"The next queued pair waits while the current arc completes its second")
		app._advance_voice_match_feedback(0.02)
		_check_cleared(app, "Queued pair %d expiry" % (index + 1))
		app._resolve_feedback()
	# Exercise the real Timer and _process path on the fifth pair: the final
	# result must not hide the cards after the former 0.7-second interval.
	var started: int = Time.get_ticks_msec()
	app.set_process(true)
	app.feedback_timer.paused = false
	await create_timer(0.82).timeout
	check(app.model.phase == "feedback" and app._voice_match_link.is_visible_in_tree()
		and app.grid.is_visible_in_tree() and not app._outcome.visible,
		"The last recognized pair stays visible beyond the old 0.7-second feedback interval")
	check(await _until(func() -> bool: return app.model.phase == "won"), "The last pair's real Timer eventually presents the win")
	check(Time.get_ticks_msec() - started >= 940 and app.model.successes == 5 and app.model.mistakes == 0,
		"The final pair receives its full second before exactly five successes win the round")
	_check_cleared(app, "Final win")
	check(not app._voice_mode and app._speech_queue.is_empty() and app.feedback_timer.is_stopped(),
		"Winning retires listening, pending feedback and the speech queue")
	app._on_voice_result([" ".join(transcript), true])
	app._resolve_feedback()
	check(app.model.phase == "won" and app.model.successes == 5 and not app._voice_match_link.active,
		"Late final callbacks and duplicate completion cannot replay feedback or change the finished score")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 900)
	var directory: String = "user://match-voice-feedback-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await _settle()
	await _test_callback_and_ignored_results(app)
	await _test_resize_and_reduced_motion(app)
	await _test_lifecycle_cancellation(app)
	await _test_manual_timing(app)
	await _test_queued_pairs_and_final_timer(app)
	app.audio.halt()
	app.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Match voice feedback: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

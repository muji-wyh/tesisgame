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


func result_pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func check_result_touch_scroll(view) -> void:
	# ScrollContainer consumes the mouse events emulated from touch. Enable the
	# touchscreen hint for the headless display, then send real viewport input.
	var original_touch_hint: bool = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	check(DisplayServer.is_touchscreen_available(), "The headless drag fixture exposes the touchscreen hint")
	var buttons: Array = [view.pip, view.report_button, view.next_report_button,
		view.replay_button, view.back_button, view._review_buttons[0]]
	for button in buttons:
		view._results.scroll_vertical = 0
		await settle()
		button.grab_focus()
		view._ensure_result_control(button)
		await settle()
		var pressed: Array[bool] = []
		var record: Callable = func() -> void: pressed.append(true)
		button.pressed.connect(record)
		var point: Vector2 = button.get_global_rect().intersection(view._results.get_global_rect()).get_center()
		var before: int = view._results.scroll_vertical
		await result_pointer(point, true)
		for step in range(1, 7):
			var motion := InputEventMouseMotion.new()
			motion.device = InputEvent.DEVICE_ID_EMULATION
			motion.position = point + Vector2(0, -20 * step)
			motion.global_position = motion.position
			motion.relative = Vector2(0, -20)
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			root.push_input(motion, true)
			await process_frame
		check(view._results.scroll_vertical > before + 40,
			"Dragging from %s continuously scrolls beyond any focus reveal (before=%d after=%d max=%.1f point=%s button=%s viewport=%s filter=%d parent_filter=%d)" % [
				button.name, before, view._results.scroll_vertical, float(view.snapshot().results_scroll_max), point,
				button.get_global_rect(), view._results.get_global_rect(), button.mouse_filter, button.get_parent().mouse_filter])
		await result_pointer(point + Vector2(0, -120), false)
		check(pressed.is_empty() and view.game.phase == "finished",
			"Dragging from %s cancels its click without leaving the results" % button.name)
		button.pressed.disconnect(record)
		view._results.set_process_internal(false)
	var heard: Array[Dictionary] = []
	var on_hear: Callable = func(word: Dictionary) -> void: heard.append(word)
	view.hear_requested.connect(on_hear)
	var review: Button = view._review_buttons[0]
	view._ensure_result_control(review)
	await settle()
	var tap: Vector2 = review.get_global_rect().get_center()
	await result_pointer(tap, true)
	await result_pointer(tap, false)
	check(heard.size() == 1, "A stationary result word tap still plays exactly once after dragging")
	view.hear_requested.disconnect(on_hear)
	Input.emulate_touch_from_mouse = original_touch_hint
	view._results.scroll_vertical = 0
	await settle()


func check_result_actions(view, dimensions: Vector2i, context: String) -> void:
	check(view._results.scroll_vertical == 0, "%s stays at scroll zero at %s" % [context, dimensions])
	var viewport_rect: Rect2 = view._results.get_global_rect()
	for button in [view.replay_button, view.back_button]:
		check(button.is_visible_in_tree() and viewport_rect.encloses(button.get_global_rect()),
			"%s keeps %s fully visible at %s: viewport=%s button=%s" % [
				context, button.name, dimensions, viewport_rect, button.get_global_rect()])

func check_compact_reports(view, dimensions: Vector2i, fixture: String) -> void:
	view._show_report(0)
	for report_step in range(3):
		await settle()
		var context: String = "%s report page %d" % [fixture, report_step + 1]
		check(int(view.snapshot().report_step) == report_step, context + " is the requested page")
		check_result_actions(view, dimensions, context)
		view.pip.pressed.emit()
		await settle()
		check_result_actions(view, dimensions, context + " after high five")
		if report_step < 2:
			view.next_report_button.pressed.emit()
	view._show_report(0)
	await settle()

func _run() -> void:
	var directory: String = "user://voice-pop-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.size = Vector2i(390, 844)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	check(app._mode_id == "match" and not app._pop.is_visible_in_tree(), "Startup preserves Match without activating speech")
	var modes: Array[String] = ["match", "memory", "pop"]
	var saw_scrollable_results: bool = false
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(679, 900), Vector2i(680, 900), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		var original_positions: Array[Vector2] = []
		for mode in modes:
			app.choose_mode(mode)
			await settle()
			var current_positions: Array[Vector2] = []
			for button in app._mode_buttons:
				current_positions.append(button.global_position)
				check(Rect2(Vector2.ZERO, app.size).grow(1).encloses(button.get_global_rect()), "Every mode tab fits at %s in %s" % [dimensions, mode])
				var label_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
				check(label_width <= button.size.x - 8.0, "Mode label is fully readable at %s: %s" % [dimensions, button.text])
			if original_positions.is_empty():
				original_positions = current_positions
			else:
				check(current_positions == original_positions, "Mode tabs stay in the same positions at %s in %s" % [dimensions, mode])
		var view = app._pop
		view.set_process(false)
		check(view.is_visible_in_tree() and not app.grid.is_visible_in_tree() and not app._memory.visible,
			"Voice Pop owns the visible playfield at " + str(dimensions))
		check(not app.hint_button.visible and not app._voice_button.visible and not app._memory.study_button.visible,
			"Other modes' actions do not intrude into Voice Pop")
		check(view.game.phase == "ready" and view.game.remaining == 30.0, "Waiting for microphone does not consume time")
		view.show_transcript("This arrived before listening", false)
		check(not view.transcript_label.is_visible_in_tree() and str(view.snapshot().transcript).is_empty(),
			"Permission waiting cannot display a transcript from an inactive recognizer")
		view._process(2.0)
		check(view.game.remaining == 30.0 and view.game.targets.is_empty(), "Permission waiting never starts target motion")
		app._on_voice_state([true, true, "Listening. Say an English word."])
		check(view.game.phase == "running" and view.game.targets.size() == 1, "A live microphone starts the actual arcade round")
		view.show_transcript("I am still thinking", false)
		check(view.transcript_label.is_visible_in_tree() and view.transcript_label.text.contains("I am still thinking"),
			"The HUD displays a whole unmatched interim sentence at " + str(dimensions))
		check(view.game.hits == 0 and not bool(view.snapshot().transcript_final), "Displaying an interim sentence does not award a hit")
		check(view.get_global_rect().grow(1).encloses(view.transcript_label.get_global_rect()),
			"The live transcript fits inside the playfield at " + str(dimensions))
		view._advance_game(1.5)
		var before_catchup: float = view.game.remaining
		var catchup_started: int = Time.get_ticks_usec()
		var missed_frame_usec: int = mini(250000, catchup_started / 2)
		view._listening_tick_usec = catchup_started - missed_frame_usec
		view._process(0.000001)
		var caught_up: float = before_catchup - view.game.remaining
		var catchup_limit: float = float(Time.get_ticks_usec() - catchup_started + missed_frame_usec) / 1000000.0
		check(caught_up >= float(missed_frame_usec) / 1000000.0 - 0.00001 and caught_up <= catchup_limit + 0.00001,
			"A tiny engine delta still consumes the full monotonic interval after a missed frame")
		check(caught_up > 0.000001 and view._listening_tick_usec >= catchup_started,
			"Low frame rates cannot stretch the round by repeatedly consuming clamped engine deltas")
		var before: int = view.game.hits
		var word: Dictionary = view.game.targets[0].word.duplicate(true)
		var sentence: String = "I think it is a " + str(word.text)
		view.show_transcript(sentence, false)
		check(view.transcript_label.text.contains(sentence) and str(view.snapshot().transcript) == sentence and view.game.hits == before,
			"A complete hypothesis remains visible independently of target scoring")
		view.receive_transcript(word.text)
		check(view.game.hits == before + 1 and view.game.hit_words[0].id == word.id, "A spoken visible word produces an exact hit")
		check(view.game.targets.all(func(target: Dictionary) -> bool: return target.word.id != word.id), "A popped target is removed immediately")
		check(view.transcript_label.text.contains(sentence), "Hit feedback does not replace the full sentence with the popped noun")
		var revised: String = "I think it is the " + str(word.text) + ", please"
		view.show_transcript(revised, false)
		check(view.transcript_label.text.contains(revised) and not bool(view.snapshot().transcript_final), "Interim revisions replace the displayed hypothesis immediately")
		view.show_transcript(revised, true)
		check(view.transcript_label.text.contains(revised) and bool(view.snapshot().transcript_final) and view.game.hits == before + 1,
			"A final hypothesis updates the HUD state without scoring the noun a second time")
		var long_sentence: String = "I am trying to speak clearly and I would like you to hear the whole sentence before I finish"
		view.show_transcript(long_sentence, false)
		check(view.transcript_label.text.contains(long_sentence) and str(view.snapshot().transcript) == long_sentence,
			"Long hypotheses retain every recognized word instead of keeping only a matched noun")
		var transcript_lines: int = view.transcript_label.get_line_count()
		check(view.transcript_label.get_visible_line_count() == mini(2, transcript_lines)
			and view.transcript_label.lines_skipped == maxi(0, transcript_lines - 2),
			"The live HUD shows the latest two full lines, or the whole shorter sentence: viewport=%s total=%d visible=%d skipped=%d" % [
				dimensions, transcript_lines, view.transcript_label.get_visible_line_count(), view.transcript_label.lines_skipped])
		check(view.get_global_rect().grow(1).encloses(view.transcript_label.get_global_rect()),
			"A long live sentence stays inside the HUD at " + str(dimensions))
		view.show_transcript("earlier words ".repeat(170) + "newest cat", false)
		check(view.transcript_label.text.length() <= 2000 and view.transcript_label.text.ends_with("newest cat")
			and str(view.snapshot().transcript).ends_with("newest cat"),
			"The bounded speech buffer retains new words after a very long hypothesis")
		app._on_voice_state([true, false, "Speech network error. Tap Retry."])
		check(not view.transcript_label.is_visible_in_tree() and str(view.snapshot().transcript).is_empty(), "Pausing clears the live transcript")
		view.show_transcript("This is a stale paused hypothesis", false)
		check(str(view.snapshot().transcript).is_empty(), "A late hypothesis cannot repopulate the paused HUD")
		var remaining: float = view.game.remaining
		check(view._listening_tick_usec == -1, "Speech failure clears the active listening clock baseline")
		view._listening_tick_usec = 0
		view._process(3.0)
		check(view.game.phase == "paused" and view.game.remaining == remaining, "Speech failure pauses both targets and the clock")
		view._listening_tick_usec = 0
		var resumed_at: int = Time.get_ticks_usec()
		app._on_voice_state([true, true, "Listening."])
		check(view.game.phase == "running" and view.game.remaining == remaining and view.game.hits == before + 1,
			"Speech recovery resumes the same round")
		check(view._listening_tick_usec >= resumed_at, "Resuming replaces the stale baseline from before the pause")
		view._process(0.000001)
		var resume_limit: float = float(Time.get_ticks_usec() - resumed_at) / 1000000.0
		check(remaining - view.game.remaining >= 0.0 and remaining - view.game.remaining <= resume_limit + 0.00001,
			"The first resumed frame excludes all time spent paused")
		app._show_collection()
		check(view.game.phase == "paused", "More pauses Voice Pop")
		remaining = view.game.remaining
		app._hide_collection()
		check(view.game.phase == "paused" and view.game.remaining == remaining, "Returning from More waits for an explicit Resume without consuming time")
		app._on_voice_state([true, true, "Listening."])
		app.on_page_hidden()
		remaining = view.game.remaining
		check(view._listening_tick_usec == -1, "Hiding the page clears the active listening clock baseline")
		view._listening_tick_usec = 0
		view._process(3.0)
		check(view.game.phase == "paused" and view.game.remaining == remaining, "Hidden pages preserve the remaining round")
		app.on_page_visible()
		app._on_voice_state([true, true, "Listening."])
		view._advance_game(31.0)
		await settle()
		check(view.game.phase == "finished" and view.game.remaining == 0.0, "The view reaches results at the 30-second deadline")
		var result: Dictionary = view.game.summary()
		check(result.hits == before + 1 and result.unique_words == 1 and result.best_combo >= 1,
			"The result report reflects the real spoken hits")
		check(Rect2(Vector2.ZERO, app.size).grow(1).encloses(view.get_global_rect()), "The result view fits at " + str(dimensions))
		var snapshot: Dictionary = view.snapshot()
		check(snapshot.phase == "finished", "Accessible state reflects the visible results")
		check(str(snapshot.transcript).is_empty() and not view.transcript_label.is_visible_in_tree(), "Results clear the completed round's transcript")
		view.show_transcript("This is a stale finished hypothesis", true)
		check(str(view.snapshot().transcript).is_empty(), "Late hypotheses cannot revive a completed round's transcript")
		var initial_report: String = str(snapshot.report)
		check(int(snapshot.report_step) == 0 and initial_report == view._pip_caption.text and initial_report.contains("30"),
			"Pip starts with a visible report of the actual 30-second round")
		check(initial_report.contains(str(result.hits)) and not initial_report.contains("points")
			and view.report_audio() == ["res://assets/audio/pop/round-%d.wav" % int(result.hits)],
			"Pip uses the complete recorded hit-count sentence without assembling score fragments")
		check(view._stats.get_child(3).get_child(0).get_child(0).text == str(result.score)
			and view._stats.get_child(1).get_child(0).get_child(0).text == str(result.unique_words),
			"Exact score and distinct words remain visible in their result tiles")
		var report_requests: Array[String] = []
		var pip_requests: Array[String] = []
		var on_report: Callable = func(text: String) -> void: report_requests.append(text)
		var on_pip: Callable = func(text: String) -> void: pip_requests.append(text)
		view.report_requested.connect(on_report)
		view.pip_report_requested.connect(on_pip)
		view.report_button.pressed.emit()
		check(report_requests.size() == 1 and report_requests.back() == initial_report, "Hear Pip replays the current report")
		view.next_report_button.pressed.emit()
		var highlights: String = str(view.snapshot().report)
		check(int(view.snapshot().report_step) == 1 and highlights.to_lower().contains(str(word.text).to_lower()),
			"My highlights names a word the player actually popped")
		check(highlights.contains("Your best combo was %d" % int(result.best_combo))
			and view.report_audio().has("res://" + str(word.audio))
			and view.report_audio().back() == "res://assets/audio/pop/combo-%d.wav" % int(result.best_combo),
			"Highlights play the actual word and the complete recorded combo sentence")
		check(report_requests.size() == 2 and report_requests.back() == highlights, "Changing report page also speaks that page")
		view.next_report_button.pressed.emit()
		var coaching: String = str(view.snapshot().report)
		var practice_words: Array = result.missed_words if not result.missed_words.is_empty() else result.hit_words
		check(int(view.snapshot().report_step) == 2 and practice_words.any(func(item: Dictionary) -> bool:
			return coaching.to_lower().contains(str(item.text).to_lower())), "Coach me suggests an actual word from this round")
		check(coaching != initial_report and coaching != highlights and report_requests.back() == coaching,
			"Coaching provides and speaks a distinct, concrete next step")
		view.next_report_button.pressed.emit()
		check(int(view.snapshot().report_step) == 0 and str(view.snapshot().report) == initial_report,
			"The three report pages cycle back to the original round summary")
		var ordinary_requests: int = report_requests.size()
		view.pip.pressed.emit()
		check(str(view.snapshot().report).contains("High five") and str(view.snapshot().report).contains(initial_report),
			"Pip's high five adds a reaction while keeping the actual report")
		check(pip_requests == [str(view.snapshot().report)] and report_requests.size() == ordinary_requests,
			"A Pip tap requests its greeting and visible report once through a separate audio route")
		check(view.report_audio().front() == "res://assets/audio/pop/high-five.wav",
			"A high five prepends its matching recorded clip")
		check(view.game.summary() == result, "Report browsing and Pip interaction leave the round result unchanged")
		view.set_report_speaking(true)
		check(view.pip.speaking and bool(view.snapshot().report_speaking), "Pip's mouth starts only when report speech starts")
		view.set_report_speaking(false)
		check(not view.pip.speaking and not bool(view.snapshot().report_speaking), "Pip's mouth stops when report speech ends or is cancelled")
		view.set_report_audio_state("loading")
		check(bool(view.snapshot().report_loading) and not view.pip.speaking,
			"Loading never pretends that Pip has started speaking")
		view.set_report_audio_state("idle")
		view.report_requested.disconnect(on_report)
		view.pip_report_requested.disconnect(on_pip)
		if dimensions in [Vector2i(320, 568), Vector2i(844, 390)]:
			await check_compact_reports(view, dimensions, "One-hit round")
		await settle()
		check(not bool(view.snapshot().results_scrollbar_visible) and not view._results.get_v_scroll_bar().is_visible_in_tree(),
			"Results never paint a scrollbar at " + str(dimensions))
		if float(view.snapshot().results_scroll_max) > 1.0:
			saw_scrollable_results = true
			if dimensions == Vector2i(320, 568):
				await check_result_touch_scroll(view)
			view._results.scroll_vertical = mini(100, int(view.snapshot().results_scroll_max))
			await settle()
			check(view._results.scroll_vertical > 0 and float(view.snapshot().results_scroll) > 0,
				"Hiding the result scrollbar preserves actual scrolling")
			var last_review: Control = view._review_buttons.back()
			last_review.grab_focus()
			await settle()
			check(view._results.get_global_rect().grow(1).encloses(last_review.get_global_rect()),
				"Keyboard focus reveals the final review word without a visible scrollbar: viewport=%s scroll_rect=%s button=%s button_rect=%s scroll=%s scroll_max=%s scroll_page=%s focus=%s" % [
					dimensions, view._results.get_global_rect(), last_review.name, last_review.get_global_rect(),
					view._results.scroll_vertical, view._results.get_v_scroll_bar().max_value,
					view._results.get_v_scroll_bar().page, root.gui_get_focus_owner()])
			view._results.scroll_vertical = 0
			await settle()
		var interactive_pip: bool = false
		for control in view.controls():
			if control.is_visible_in_tree() and control.name.to_lower().contains("pip"):
				interactive_pip = true
		check(interactive_pip, "Pip is an actual interactive result control")
		check(not view.default_focus() is Label, "Results provide a usable action for keyboard focus")
		app.choose_mode("match")
		check(not view.is_visible_in_tree() and not bool(view.snapshot().report_speaking)
			and not bool(view.snapshot().report_loading) and view.report_audio().is_empty(),
			"Leaving results clears report playback state and the exposed audio list")
		view.set_report_speaking(true)
		check(not view.pip.speaking, "A late report speech callback cannot animate Pip after leaving results")
		view.set_process(true)
	check(saw_scrollable_results, "Compact result layouts exercise scrolling with the scrollbar hidden")
	app.playroom_state.age_band_id = "4-6"
	app.choose_mode("pop")
	check(app._pop.game._words.all(func(word: Dictionary) -> bool: return app.Data.word_level(word) == 1),
		"Voice Pop uses only the selected age group's vocabulary")
	app._pop.set_process(false)
	app._on_voice_state([true, true, "Listening."])
	app._pop._advance_game(31.0)
	await settle()
	var empty_round: Dictionary = app._pop.game.summary()
	var empty_report: String = str(app._pop.snapshot().report)
	check(empty_round.hits == 0 and empty_round.score == 0 and empty_round.hit_words.is_empty(),
		"The no-hit report fixture completes an actual round without invented results")
	check(empty_report.contains("0 words") and empty_report.contains("30") and not empty_report.contains("points")
		and app._pop.report_audio() == ["res://assets/audio/pop/round-0.wav"],
		"Pip accurately reports a zero-hit round using its complete encouraging recording")
	check(empty_report.to_lower().contains("practise"), "A no-hit round gives encouraging help")
	app._pop.next_report_button.pressed.emit()
	check(str(app._pop.snapshot().report).contains("No words popped"), "Empty highlights do not invent a successful word")
	app._pop.next_report_button.pressed.emit()
	check(not empty_round.missed_words.is_empty() and str(app._pop.snapshot().report).contains(str(empty_round.missed_words[0].text)),
		"A no-hit round still offers a specific missed word to practise")
	check(app._pop.game.summary() == empty_round, "Pip's no-hit coaching leaves the recorded result unchanged")
	for dimensions in [Vector2i(320, 568), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		await check_compact_reports(app._pop, dimensions, "Zero-hit round")
	check(app._pop.game.summary() == empty_round, "Compact report pages and every-page high fives preserve the zero-hit result")
	var long_words: Array = app.data.words.duplicate()
	long_words.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.text).length() > str(b.text).length())
	for count in [20, 21]:
		var long_report: Dictionary = empty_round.duplicate(true)
		long_report.hits = count
		long_report.best_combo = count
		long_report.unique_words = 2
		long_report.score = 200
		long_report.hit_words = long_words.slice(0, 2)
		long_report.missed_words = long_words.slice(2, 3)
		app._pop._build_results(long_report)
		for dimensions in [Vector2i(320, 568), Vector2i(844, 390)]:
			root.size = dimensions
			await settle()
			await check_compact_reports(app._pop, dimensions, "Two long words, %d hits" % count)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Voice Pop scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

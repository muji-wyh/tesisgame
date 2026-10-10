extends SceneTree

const Jelly = preload("res://scripts/jelly_match.gd")
const Meter = preload("res://scripts/jelly_loot_meter.gd")
const Data = preload("res://scripts/game_data.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")

var checks: int = 0
var failures: int = 0
var data = Data.new()
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 720)
	_check_meter_motion()
	check(data.load_all(), "The treasure meter uses the production curriculum and chest artwork")
	words = data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) <= 3 and not str(word.get("image", "")).is_empty()).slice(0, 12)
	var view = Jelly.new()
	root.add_child(view)
	view.size = Vector2(1000, 720)
	view.set_process(false)
	_check_fragment_arrival(view)
	_check_owner_frame_timing(view)
	_check_staggered_arrivals(view)
	_check_double_fragment_arrival(view)
	_check_threshold(view, 3, 4)
	_check_threshold(view, 8, 5)
	_check_flight_pause(view)
	_check_owner_lifecycle(view)
	_check_reduced_motion(view)
	_check_layout(view)
	_check_results_and_restart(view)
	view.free()
	await process_frame
	print("Jelly loot meter: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_meter_motion() -> void:
	var meter = Meter.new()
	root.add_child(meter)
	meter.size = Vector2(72, 72)
	meter.reset()
	meter.set_progress(0, 4, false)
	var state: Dictionary = meter.snapshot()
	check(state.filled == 0 and state.required == 4 and is_zero_approx(float(state.displayed)),
		"An empty treasure starts with four unfilled segments")
	meter.set_progress(1, 4, false)
	check(meter.snapshot().filled == 1 and float(meter.snapshot().displayed) < 1.0,
		"A new fragment has a target without snapping its visual fill")
	meter.advance(0.16)
	state = meter.snapshot()
	check(float(state.displayed) > 0.0 and float(state.displayed) < 1.0 and float(state.pulse) > 0.0,
		"Fragment arrival animates a partial fill and a local pickup pulse")
	meter.set_progress(1, 4, false)
	meter.advance(0.17)
	check(is_equal_approx(float(meter.snapshot().displayed), 1.0),
		"Repeated HUD refreshes do not restart the segment animation")
	meter.advance(0.3)
	check(is_zero_approx(float(meter.snapshot().pulse)), "The pickup accent ends instead of looping")
	meter.set_progress(4, 4, false)
	meter.advance(0.4)
	check(is_equal_approx(float(meter.snapshot().displayed), 4.0), "A complete unlock fills all four segments")
	meter.set_progress(0, 5, false)
	state = meter.snapshot()
	check(state.filled == 0 and state.required == 5 and is_zero_approx(float(state.displayed)),
		"Revealing a chest starts a fresh five-segment upgrade ring")
	meter.set_progress(2, 5, true)
	state = meter.snapshot()
	check(state.filled == 2 and is_equal_approx(float(state.displayed), 2.0) and is_zero_approx(float(state.pulse)),
		"Reduced motion preserves progress without interpolating or pulsing")
	meter.advance(0.2)
	check(is_equal_approx(float(meter.snapshot().displayed), 2.0) and is_zero_approx(float(meter.snapshot().pulse)),
		"Reduced motion remains still as the owner clock advances")
	meter.set_progress(3, 5, false)
	meter.advance(0.08)
	meter.settle()
	check(is_equal_approx(float(meter.snapshot().displayed), 3.0) and is_zero_approx(float(meter.snapshot().pulse)),
		"Settling completes the current fill and removes transient effects")
	meter.reset()
	check(meter.snapshot().filled == 0 and is_zero_approx(float(meter.snapshot().displayed))
		and is_zero_approx(float(meter.snapshot().pulse)), "Reset removes all previous-round progress and motion")
	meter.free()


func _reset(view, fragments: int = 0, reduced: bool = false) -> void:
	view.show()
	view.interaction_allowed = Callable()
	check(view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42),
		"The meter fixture configures a real Jelly Match round")
	view.set_process(false)
	# Seed only previously earned progress; the tested fragment always comes from
	# a production marked pair completing its normal fusion.
	var progress: Dictionary = RewardProgress.reward_progress(fragments)
	view.game.fragment_count = fragments
	view.game.chest_tier = int(progress.chest_tier)
	view.game.chest_count = int(progress.chest_count)
	view._displayed_chest_tier = int(progress.chest_tier)
	view._refresh_hud()
	view._loot_meter.settle()
	view._layout()


func _merge_marked(view) -> bool:
	for a: Dictionary in view.game.cells:
		for b: Dictionary in view.game.cells:
			if a.id == b.id or a.word.id != b.word.id or a.kind == b.kind:
				continue
			if int(bool(a.chest)) + int(bool(b.chest)) != 1:
				continue
			check(view.game.try_merge(int(a.id), int(b.id)) == "correct",
				"A real marked picture-word pair starts the fragment fixture")
			view.game.step(view.game.FUSION_SECONDS)
			view._sync_tiles()
			view._refresh_hud()
			return true
	check(false, "The seeded production board contains a pair with exactly one fragment")
	return false


func _advance(view, duration: float) -> void:
	var remaining: float = duration
	while remaining > 0.000001:
		var delta: float = minf(0.1, remaining)
		view._process(delta)
		remaining -= delta


func _start_marked_pair(view, amount: int = 1) -> bool:
	for a: Dictionary in view.game.cells:
		if view.game.is_fusing(int(a.id)) or not view.game.is_settled(a):
			continue
		for b: Dictionary in view.game.cells:
			if a.id == b.id or a.word.id != b.word.id or a.kind == b.kind \
				or view.game.is_fusing(int(b.id)) or not view.game.is_settled(b):
				continue
			# Change only the reward markers; matching, fusion completion, and
			# fragment credit still pass through the production model.
			a.chest = true
			b.chest = amount == 2
			var accepted: bool = view.game.try_merge(int(a.id), int(b.id)) == "correct"
			check(accepted, "A production pair accepts the controlled fragment markers")
			return accepted
	check(false, "The production board contains an available matching pair")
	return false


func _progress(view) -> Dictionary:
	return view.snapshot().loot.progress


func _check_fragment_arrival(view) -> void:
	_reset(view)
	check(view.get_node_or_null("JellyLootCount") == null and view._loot_detail.text == "Unlock chest",
		"The gameplay HUD explains the goal without displaying a numeric fragment counter")
	if not _merge_marked(view):
		return
	check(view.game.fragment_count == 1 and view._loot_flights.size() == 1 and _progress(view).filled == 0,
		"A committed fragment keeps flying without filling its destination early")
	_advance(view, 0.64)
	check(_progress(view).filled == 0 and is_zero_approx(float(_progress(view).displayed))
		and is_zero_approx(float(_progress(view).pulse)) and view._loot_flights.size() == 1,
		"The treasure ring keeps its fill and pickup pulse still throughout the flight")
	_advance(view, 0.02)
	check(_progress(view).filled == 1 and view._loot_flights.is_empty(),
		"Reaching the chest advances exactly one segment")
	_advance(view, 0.4)
	check(is_equal_approx(float(_progress(view).displayed), 1.0),
		"The arrived fragment settles into one complete segment")
	_advance(view, 0.3)
	check(is_zero_approx(float(_progress(view).pulse)) and view.game.fragment_count == 1,
		"The pickup accent ends without changing the earned fragment")


func _check_owner_frame_timing(view) -> void:
	_reset(view)
	if not _start_marked_pair(view):
		return
	view.game.step(view.game.FUSION_SECONDS - 0.04)
	check(view.game.fragment_count == 0 and view._loot_flights.is_empty(),
		"A nearly complete fusion has no fragment flight or reward yet")
	view._process(0.2)
	check(view.game.fragment_count == 1 and view._loot_flights.size() == 1,
		"The owner frame completes the fusion and launches its earned fragment")
	if view._loot_flights.size() != 1:
		return
	check(is_zero_approx(float(view._loot_flights[0].elapsed))
		and _progress(view).filled == 0 and is_zero_approx(float(_progress(view).displayed))
		and is_zero_approx(float(_progress(view).pulse)),
		"A newly launched fragment cannot inherit time from its creation frame")
	view._process(0.5)
	view._process(0.1)
	check(view._loot_flights.size() == 1 and _progress(view).filled == 0
		and is_zero_approx(float(_progress(view).displayed)) and is_zero_approx(float(_progress(view).pulse)),
		"Even large owner frames cannot begin progress before the fragment arrives")
	view._process(0.2)
	var residual: float = 0.15
	check(view._loot_flights.is_empty() and _progress(view).filled == 1,
		"Crossing the arrival boundary credits the fragment once")
	check(is_equal_approx(float(_progress(view).displayed), smoothstep(0.0, Meter.FILL_SECONDS, residual))
		and is_equal_approx(float(_progress(view).pulse), sin(residual / Meter.PULSE_SECONDS * PI)),
		"Progress fill and pulse receive only the frame time after arrival")
	_advance(view, 0.5)
	check(is_equal_approx(float(_progress(view).displayed), 1.0) and is_zero_approx(float(_progress(view).pulse)),
		"The corrected owner timeline still finishes one complete pickup animation")


func _check_staggered_arrivals(view) -> void:
	_reset(view)
	if not _start_marked_pair(view):
		return
	_advance(view, 0.2)
	if not _start_marked_pair(view):
		return
	_advance(view, 0.85)
	check(view.game.fragment_count == 1 and view._loot_flights.size() == 1,
		"The first concurrent fusion creates its own flight")
	view._process(0.2)
	check(view.game.fragment_count == 2 and view._loot_flights.size() == 2,
		"A later concurrent fusion creates an independently timed flight")
	if view._loot_flights.size() != 2:
		return
	check(is_equal_approx(float(view._loot_flights[0].elapsed), 0.2)
		and is_zero_approx(float(view._loot_flights[1].elapsed)),
		"Sibling fragments keep their staggered launch times")
	view._process(0.44)
	check(_progress(view).filled == 0 and is_zero_approx(float(_progress(view).displayed))
		and is_zero_approx(float(_progress(view).pulse)),
		"Two airborne rewards still leave the destination unchanged")
	view._process(0.02)
	check(view._loot_flights.size() == 1 and _progress(view).filled == 1,
		"The first arrival credits only its own fragment")
	view._process(0.18)
	check(view._loot_flights.size() == 1 and _progress(view).filled == 1,
		"A pending sibling cannot borrow the first fragment's arrival")
	view._process(0.02)
	check(view._loot_flights.is_empty() and _progress(view).filled == 2
		and float(_progress(view).displayed) < 2.0,
		"The second arrival starts its own addition without snapping the meter full")
	_advance(view, 0.6)
	check(is_equal_approx(float(_progress(view).displayed), 2.0) and is_zero_approx(float(_progress(view).pulse))
		and view.game.fragment_count == 2,
		"Overlapping pickup effects settle with no missing or duplicate fragments")


func _check_double_fragment_arrival(view) -> void:
	_reset(view)
	if not _start_marked_pair(view, 2):
		return
	_advance(view, view.game.FUSION_SECONDS)
	check(view.game.fragment_count == 2 and view._loot_flights.size() == 1,
		"A pair with two chest markers launches one flight carrying both fragments")
	if view._loot_flights.size() != 1:
		return
	check(int(view._loot_flights[0].amount) == 2 and _progress(view).filled == 0,
		"The complete double reward remains pending during its flight")
	_advance(view, 0.64)
	check(_progress(view).filled == 0 and is_zero_approx(float(_progress(view).displayed))
		and is_zero_approx(float(_progress(view).pulse)),
		"Neither half of a double reward appears in the meter before arrival")
	_advance(view, 0.02)
	check(view._loot_flights.is_empty() and _progress(view).filled == 2
		and float(_progress(view).displayed) > 0.0 and float(_progress(view).displayed) < 2.0,
		"Both earned fragments begin filling only after their shared flight arrives")
	_advance(view, 0.6)
	check(is_equal_approx(float(_progress(view).displayed), 2.0) and is_zero_approx(float(_progress(view).pulse))
		and view.game.fragment_count == 2,
		"A double pickup finishes once while preserving the exact earned amount")


func _check_threshold(view, previous_fragments: int, required: int) -> void:
	_reset(view, previous_fragments)
	check(_progress(view).filled == required - 1 and _progress(view).required == required,
		"A threshold fixture begins exactly one piece short of its current reward")
	if not _merge_marked(view):
		return
	check(_progress(view).filled == required - 1 and view._reward_presentation.is_active(),
		"A milestone queues its celebration while the final fragment is still flying")
	_advance(view, 0.66)
	check(_progress(view).filled == required and _progress(view).required == required
		and not view._reward_presentation.visible,
		"The last arriving fragment starts filling its ring before the reward overlay")
	_advance(view, 0.2)
	check(float(_progress(view).displayed) > float(required - 1)
		and float(_progress(view).displayed) < float(required) and not view._reward_presentation.visible,
		"Unlocks and upgrades leave the meter visible while its final segment fills")
	_advance(view, 0.3)
	check(is_equal_approx(float(_progress(view).displayed), float(required))
		and view._reward_presentation.visible and not view._reward_presentation.snapshot().revealed,
		"Chest assembly begins only after the completed ring has been shown")
	_advance(view, 0.8)
	check(view._reward_presentation.snapshot().revealed and _progress(view).filled == 0
		and _progress(view).required == 5 and is_zero_approx(float(_progress(view).displayed)),
		"Only the actual reward reveal resets the ring for the next upgrade")
	check(view._loot_detail.text == "Upgrade chest", "An unlocked treasure explains its next upgrade without numbers")
	_advance(view, 1.5)
	check(not view._reward_presentation.is_active() and _progress(view).filled == 0
		and view.game.fragment_count == previous_fragments + 1 and view.game.chest_count == 1,
		"Finishing the performance neither replays progress nor creates another chest")


func _check_flight_pause(view) -> void:
	for action: String in ["pause", "hidden", "host_gate"]:
		_reset(view)
		if not _merge_marked(view):
			continue
		_advance(view, 0.3)
		var before: Array = view._loot_flights.duplicate(true)
		if action == "pause":
			view.pause(true)
		elif action == "hidden":
			view.hide()
		else:
			view.interaction_allowed = func() -> bool: return false
		_advance(view, 1.0)
		check(view._loot_flights == before and _progress(view).filled == 0
			and is_zero_approx(float(_progress(view).displayed)) and is_zero_approx(float(_progress(view).pulse)),
			"The %s gate freezes the flight without leaking progress or pickup effects" % action)
		if action == "pause":
			view.pause(false)
		elif action == "hidden":
			view.show()
		else:
			view.interaction_allowed = Callable()
		_advance(view, 0.34)
		check(view._loot_flights.size() == 1 and _progress(view).filled == 0,
			"Resuming from %s preserves the fragment's remaining journey" % action)
		_advance(view, 0.02)
		check(view._loot_flights.is_empty() and _progress(view).filled == 1,
			"The resumed %s flight credits its fragment only when it reaches the chest" % action)


func _check_owner_lifecycle(view) -> void:
	for action: String in ["pause", "hidden", "host_gate"]:
		_reset(view)
		if not _merge_marked(view):
			continue
		_advance(view, 0.75)
		var before: Dictionary = _progress(view).duplicate(true)
		if action == "pause":
			view.pause(true)
		elif action == "hidden":
			view.hide()
		else:
			view.interaction_allowed = func() -> bool: return false
		_advance(view, 1.0)
		check(is_equal_approx(float(_progress(view).displayed), float(before.displayed))
			and is_equal_approx(float(_progress(view).pulse), float(before.pulse)),
			"The %s gate freezes the fragment fill and pickup effect" % action)
		if action == "pause":
			view.pause(false)
		elif action == "hidden":
			view.show()
		else:
			view.interaction_allowed = Callable()
		_advance(view, 0.65)
		check(is_equal_approx(float(_progress(view).displayed), 1.0) and is_zero_approx(float(_progress(view).pulse)),
			"Returning from %s finishes the same visual progress once" % action)
	_reset(view)
	if not _merge_marked(view):
		return
	_advance(view, 0.3)
	view.settle()
	check(view._loot_flights.is_empty() and _progress(view).filled == 1
		and is_equal_approx(float(_progress(view).displayed), 1.0) and is_zero_approx(float(_progress(view).pulse)),
		"Settling a flight preserves its committed fragment without retaining motion")


func _check_reduced_motion(view) -> void:
	_reset(view, 0, true)
	if not _merge_marked(view):
		return
	check(view._loot_flights.is_empty() and _progress(view).filled == 1
		and is_equal_approx(float(_progress(view).displayed), 1.0) and is_zero_approx(float(_progress(view).pulse)),
		"Reduced motion presents an earned fragment immediately without flight or pulse")
	_reset(view)
	if not _merge_marked(view):
		return
	_advance(view, 0.3)
	view.set_reduced_motion(true)
	check(view._loot_flights.is_empty() and _progress(view).filled == 1
		and is_equal_approx(float(_progress(view).displayed), 1.0) and is_zero_approx(float(_progress(view).pulse)),
		"Enabling reduced motion during flight settles the already earned progress")


func _rect(value: Array) -> Rect2:
	return Rect2(Vector2(float(value[0]), float(value[1])), Vector2(float(value[2]), float(value[3])))


func _check_layout(view) -> void:
	_reset(view, 2)
	for dimensions: Vector2 in [Vector2(1366, 600), Vector2(390, 640), Vector2(340, 460), Vector2(320, 260), Vector2(844, 235), Vector2(1024, 370)]:
		view.size = dimensions
		view._layout()
		var bounds: Rect2 = _rect(_progress(view).rect)
		check(bool(_progress(view).visible) and bounds.has_area() and view.get_global_rect().encloses(bounds),
			"%s contains the complete treasure progress graphic" % dimensions)
		check(not bounds.intersects(_rect(view.snapshot().board_rect))
			and not bounds.intersects(_rect(view.snapshot().preview.rect))
			and not bounds.intersects(view.finish_button.get_global_rect()),
			"%s separates treasure progress from the board, supply, and finish control" % dimensions)
		check(view._loot_meter.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"The decorative treasure meter does not intercept gameplay input")
	view.size = Vector2(1000, 720)
	view._layout()


func _check_results_and_restart(view) -> void:
	_reset(view, 2)
	view.game.finish_round()
	view.result_reveal()
	check(not bool(_progress(view).visible) and not view._loot_icon.visible and not view._loot_detail.visible,
		"The gameplay treasure meter leaves the screen when the result page appears")
	_reset(view)
	if not _merge_marked(view):
		return
	_advance(view, 0.75)
	view.stop()
	check(not bool(_progress(view).visible) and view._loot_flights.is_empty()
		and is_zero_approx(float(_progress(view).pulse)), "Leaving the mode removes the ring and all pickup effects")
	_reset(view)
	check(_progress(view).filled == 0 and _progress(view).required == 4
		and is_zero_approx(float(_progress(view).displayed)) and is_zero_approx(float(_progress(view).pulse)),
		"A new round restores an empty unlock ring without replaying the previous reward")

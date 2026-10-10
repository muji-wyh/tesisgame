extends SceneTree

const Celebration = preload("res://scripts/jelly_chest_celebration.gd")
const Jelly = preload("res://scripts/jelly_match.gd")
const Data = preload("res://scripts/game_data.gd")
const BEFORE = preload("res://assets/chests/energy/closed.png")
const AFTER = preload("res://assets/chests/royal/closed.png")

var checks: int = 0
var failures: int = 0
var heard: Array[Dictionary] = []


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
	var view := Celebration.new()
	root.add_child(view)
	view.position = Vector2(24, 60)
	view.size = Vector2(952, 636)
	view.set_chest_anchor(Rect2(20, 16, 72, 72))
	view.cue_requested.connect(func(cue: String) -> void:
		heard.append({"cue": cue, "state": view.snapshot()}))
	_check_timeline(view)
	_check_queue(view)
	_check_reentry(view)
	_check_reduced_motion(view)
	_check_layouts(view)
	view.clear()
	view.free()
	_check_owner_lifecycle()
	print("Jelly chest celebration: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _begin(view, previous: int = 0, tier: int = 1, reduced: bool = false) -> void:
	view.clear()
	heard.clear()
	view.reduced_motion = reduced
	view.enqueue(previous, tier, BEFORE, AFTER)


func _check_timeline(view) -> void:
	_begin(view)
	check(view.is_active() and not view.visible and view.snapshot().kind == "synthesis",
		"Synthesis reserves its timeline without obscuring the fragment flight")
	view.advance(0.64)
	check(not view.visible and heard.is_empty(), "A fragment gets its entire flight before assembly begins")
	view.advance(0.02)
	check(view.visible and heard.size() == 1 and heard[0].cue == "assemble"
		and is_equal_approx(float(heard[0].state.elapsed), Celebration.ARRIVAL_SECONDS),
		"Assembly sound is published at the precise flight-arrival boundary")
	view.advance(0.70)
	check(not view.snapshot().revealed and heard.size() == 1,
		"The new chest and reward sound wait until the assembly finishes")
	view.advance(0.02)
	check(view.snapshot().revealed and heard.size() == 2 and heard[1].cue == "reward"
		and is_equal_approx(float(heard[1].state.elapsed), Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS),
		"The finished chest reveal and reward sound share one exact boundary")
	check(view.snapshot().confetti and view.snapshot().kind == "synthesis",
		"The first unlocked chest receives the same full-screen paper celebration as upgrades")
	view.advance(1.43)
	check(not view.is_active() and not view.visible and heard.size() == 2,
		"A completed synthesis releases the scene without looping its animation")
	view.advance(30.0)
	check(heard.size() == 2, "An idle timeline cannot replay either reward cue")
	_begin(view, 1, 2)
	var before: Dictionary = view.snapshot()
	for delta: float in [-1.0, 0.0, INF, NAN]:
		view.advance(delta)
	check(view.snapshot() == before and heard.is_empty(), "Invalid clock samples leave queued rewards untouched")
	view.advance(2.0)
	check(heard.size() == 2
		and is_equal_approx(float(heard[0].state.elapsed), Celebration.ARRIVAL_SECONDS)
		and is_equal_approx(float(heard[1].state.elapsed), Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS),
		"A stalled frame still publishes assembly and reveal at their separate authored boundaries")
	check(view.snapshot().confetti and view.snapshot().kind == "upgrade" and view.snapshot().tier == 2,
		"Upgrade reveals its precise level together with full-screen confetti")
	view.reduced_motion = true
	check(not view.snapshot().confetti, "Changing motion preferences removes the burst immediately")
	view.reduced_motion = false
	check(view.snapshot().confetti, "Restoring motion samples the existing milestone instead of restarting it")


func _check_queue(view) -> void:
	_begin(view)
	view.enqueue(1, 2, BEFORE, AFTER)
	check(view.snapshot().queued == 2 and view.snapshot().tier == 1,
		"A later upgrade queues behind synthesis without replacing the earned first chest")
	var total: float = Celebration.ARRIVAL_SECONDS + Celebration.PERFORMANCE_SECONDS
	view.advance(total + Celebration.ARRIVAL_SECONDS + 0.05)
	check(view.snapshot().queued == 1 and view.snapshot().tier == 2 and view.snapshot().kind == "upgrade"
		and is_equal_approx(float(view.snapshot().elapsed), Celebration.ARRIVAL_SECONDS + 0.05),
		"Queued upgrades consume only time remaining after the previous presentation")
	check(heard.size() == 3 and heard[0].cue == "assemble" and heard[1].cue == "reward"
		and heard[2].cue == "assemble", "Queue order preserves each chest's own sound sequence")
	view.advance(total)
	check(not view.is_active() and heard.size() == 4 and heard[3].cue == "reward",
		"Each queued milestone completes exactly once")
	view.enqueue(3, 3, BEFORE, AFTER)
	view.enqueue(3, 2, BEFORE, AFTER)
	check(not view.is_active(), "Repeated or regressive tier transitions cannot start a presentation")


func _check_reentry(view) -> void:
	for at: String in ["assemble", "reward"]:
		for replace: bool in [false, true]:
			_begin(view)
			view.enqueue(1, 2, BEFORE, AFTER)
			var interrupt: Callable = func(cue: String) -> void:
				if cue != at:
					return
				view.clear()
				if replace:
					view.enqueue(2, 3, BEFORE, AFTER)
			view.cue_requested.connect(interrupt)
			view.advance(20.0)
			view.cue_requested.disconnect(interrupt)
			check(heard.size() == (1 if at == "assemble" else 2),
				"Clearing during %s prevents every remaining stale cue" % at)
			if replace:
				check(view.snapshot().tier == 3 and view.snapshot().queued == 1
					and is_zero_approx(float(view.snapshot().elapsed)) and not view.visible,
					"A replacement reward starts from its own flight clock after synchronous reentry")
			else:
				check(not view.is_active() and not view.visible,
					"A cleared timeline cannot reactivate a queued old reward")


func _check_reduced_motion(view) -> void:
	_begin(view, 2, 3, true)
	view.advance(0.64)
	check(not view.visible, "Reduced motion preserves the fragment arrival gate")
	view.advance(0.02)
	check(view.visible and not view.snapshot().confetti,
		"Reduced motion shows the static HUD chest without flying paper")
	view.advance(0.72)
	check(view.snapshot().revealed and not view.snapshot().confetti and heard.size() == 2,
		"Reduced motion preserves the same reward gate and one sound per milestone")
	view.advance(2.0)
	check(not view.is_active(), "Static presentation finishes after the same duration")


func _check_layouts(view) -> void:
	_begin(view, 1, 2)
	view.advance(1.5)
	for dimensions: Vector2 in [Vector2(1366, 600), Vector2(390, 640), Vector2(320, 220), Vector2(844, 235)]:
		view.size = dimensions
		var anchor := Rect2(Vector2(16, 12), Vector2.ONE * minf(72.0, dimensions.y * 0.25))
		view.set_chest_anchor(anchor)
		check(_rect(view.snapshot().anchor).is_equal_approx(anchor),
			"%s keeps the chest effect at its supplied HUD location" % dimensions)
		check(_rect(view.snapshot().confetti_rect).is_equal_approx(root.get_visible_rect()),
			"%s celebrates across the current viewport instead of a replacement page" % dimensions)
	check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and view._confetti.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and view.find_children("*", "BaseButton", true, false).is_empty(),
		"The HUD celebration and full-screen paper cannot capture a game gesture")
	check(view.find_children("*", "Label", true, false).is_empty(),
		"An in-game chest milestone does not add a modal title over the board")


func _rect(values: Array) -> Rect2:
	return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))


func _advance_owner(view, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var delta: float = minf(0.05, remaining)
		view._process(delta)
		remaining -= delta


func _check_owner_lifecycle() -> void:
	var data := Data.new()
	check(data.load_all(), "Presentation ownership uses the production chest manifest")
	var words: Array = data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) <= 3 and not str(word.get("image", "")).is_empty()).slice(0, 12)
	var view := Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(1000, 720)
	check(view.configure(words, 3, Data.theme("spring"), data.chests, false, 42),
		"A real Jelly view owns the reward timeline")
	view._chest_milestone(0, 1)
	_advance_owner(view, 0.3)
	view.pause(true)
	var paused: Dictionary = view._reward_presentation.snapshot()
	var board: Dictionary = view.game.snapshot()
	_advance_owner(view, 8.0)
	check(view._reward_presentation.snapshot() == paused and view.game.snapshot() == board,
		"Opening the menu freezes reward timing and gameplay together")
	view.pause(false)
	view.hide()
	_advance_owner(view, 8.0)
	check(view._reward_presentation.snapshot() == paused,
		"A hidden game cannot advance reward visuals or play late reward sounds")
	view.show()
	_advance_owner(view, 0.4)
	check(view._reward_presentation.visible and view._can_play() and not view.drop_button.disabled
		and not view.game.paused and is_equal_approx(view.game.spawn_elapsed, 0.7),
		"Returning resumes the same reward and the playable board together")
	view.stop()
	check(not view._reward_presentation.is_active() and not view._reward_presentation.visible,
		"Leaving Jelly immediately removes the old reward and its queue")
	_check_pending_fusions(view, words, data.chests)
	_check_active_gameplay(view, words, data.chests)
	_check_later_pickup(view, words, data.chests)
	_check_finish_during_reward(view, words, data.chests)
	view.configure(words, 3, Data.theme("spring"), data.chests, false, 42)
	view._chest_milestone(0, 1)
	view.advance_reward_presentation(2.77)
	view._process(0.1)
	check(not view._reward_presentation.is_active() and is_equal_approx(view.game.spawn_elapsed, 0.1),
		"The frame advances gameplay in full even when the chest effect ends partway through it")
	for at: String in ["assemble", "reward"]:
		for action: String in ["stop", "reconfigure"]:
			view.configure(words, 3, Data.theme("spring"), data.chests, false, 42)
			view._chest_milestone(0, 1)
			view.advance_reward_presentation(0.6 if at == "assemble" else 1.32)
			var interrupt: Callable = func(cue: String) -> void:
				if cue != at:
					return
				if action == "stop":
					view.stop()
				else:
					view.configure(words, 3, Data.theme("spring"), data.chests, false, 72)
			view.audio_requested.connect(interrupt)
			view._process(0.2)
			view.audio_requested.disconnect(interrupt)
			check(not view._reward_presentation.is_active(),
				"Synchronous %s during %s cannot retain an old presentation" % [action, at])
			if action == "stop":
				check(not view._configured and view.game.paused,
					"The old frame cannot unpause a game stopped from its sound callback")
			else:
				check(view._configured and is_zero_approx(view.game.spawn_elapsed)
					and view.game.fragment_count == 0,
					"The old frame cannot advance or reward a replacement round")
	view.stop()
	view.free()


func _matching_pair(view, marked: bool = false) -> Array[int]:
	for a: Dictionary in view.game.cells:
		if view.game.is_fusing(int(a.id)) or not view._settled(a) or (marked and not bool(a.chest)):
			continue
		for b: Dictionary in view.game.cells:
			if not view.game.is_fusing(int(b.id)) and view._settled(b) and a.word.id == b.word.id and a.kind != b.kind:
				return [int(a.id), int(b.id)]
	return []


func _check_pending_fusions(view, words: Array, manifest: Dictionary) -> void:
	view.configure(words, 3, Data.theme("spring"), manifest, false, 42)
	# The model threshold is tested separately; seed its already earned three
	# fragments so this fixture isolates a menu opened between sibling clears.
	view.game.fragment_count = 3
	var first: Array[int] = _matching_pair(view, true)
	check(first.size() == 2 and view.game.try_merge(first[0], first[1]) == "correct",
		"The unlock fixture begins with a real marked fusion")
	_advance_owner(view, 0.2)
	var second: Array[int] = _matching_pair(view)
	check(second.size() == 2 and view.game.try_merge(second[0], second[1]) == "correct",
		"Another accepted fusion retains its independent completion deadline")
	var other: Array[int] = _matching_pair(view)
	check(other.size() == 2, "An unrelated pair remains available before the fragment threshold")
	var point: Vector2 = view._tiles[other[0]].get_global_rect().get_center()
	check(view._press(4, point), "An unrelated jelly can be held before synthesis queues")
	view._move(point + Vector2(24.0, 0.0))
	_advance_owner(view, 0.85)
	check(view.game.fusions.size() == 1 and view._reward_presentation.is_active()
		and not view._reward_presentation.visible and view.game.fragment_count == 4,
		"The fourth fragment queues synthesis while the later accepted jelly finishes")
	check(view._can_play() and view.snapshot().drag.active and int(view.snapshot().drag.source) == other[0],
		"A queued chest presentation cannot interrupt a drag while a sibling is still disappearing")
	_advance_owner(view, 0.21)
	check(view.game.fusions.is_empty() and view.game.cleared_pairs == 2
		and view._reward_presentation.is_active() and view._can_play() and not view.game.paused
		and view.snapshot().drag.active and int(view.snapshot().drag.source) == other[0],
		"The last sibling clear leaves both gameplay and the held drag running during synthesis")
	_advance_owner(view, 0.65)
	check(not view._reward_presentation.visible,
		"Synthesis waits for the arriving fragment's visible progress fill")
	_advance_owner(view, 0.3)
	check(view._reward_presentation.visible and view.game.fragment_count == 4 and view.game.chest_count == 1,
		"Synthesis then starts once with the previously committed single chest")
	_advance_owner(view, 0.7)
	check(view._reward_presentation.snapshot().confetti and view.snapshot().drag.active
		and int(view.snapshot().drag.source) == other[0],
		"Full-screen confetti starts over the current board without dropping the held jelly")
	var destination: Vector2 = view._tiles[other[1]].get_global_rect().get_center()
	view._move(destination)
	view._release(destination)
	check(view.game.fusions.size() == 1 and not view.snapshot().drag.active
		and view._reward_presentation.snapshot().confetti,
		"Releasing the preserved drag onto its partner accepts a new fusion while paper is falling")
	check(not view.finish_button.disabled and view.navigation_controls().has(view.finish_button),
		"Finish remains available during an in-game chest celebration")
	view.stop()


func _check_active_gameplay(view, words: Array, manifest: Dictionary) -> void:
	for reduced: bool in [false, true]:
		view.configure(words, 3, Data.theme("spring"), manifest, reduced, 42)
		view._chest_milestone(0, 1)
		_advance_owner(view, 1.4)
		check(view._reward_presentation.visible and view._reward_presentation.snapshot().confetti == (not reduced),
			"The input fixture reaches a live chest reveal with the selected motion preference")
		var pair: Array[int] = _matching_pair(view)
		check(pair.size() == 2, "The live reward screen retains an available pair")
		var point: Vector2 = view._tiles[pair[0]].get_global_rect().get_center()
		var destination: Vector2 = view._tiles[pair[1]].get_global_rect().get_center()
		check(view._press(4, point), "A fresh touch can pick up a jelly during the reward effect")
		view._move(destination)
		view._release(destination)
		check(view.game.fusions.size() == 1 and view._reward_presentation.visible and not view.game.paused,
			"A fresh drag can start a fusion while the HUD chest celebrates")
		var count: int = view.game.generated_tiles
		view.drop_button.pressed.emit()
		check(view.game.generated_tiles == count + 4 and view._reward_presentation.visible,
			"The next-wave control dispatches all four jellies during the chest effect")
		_advance_owner(view, 0.1)
		check(is_equal_approx(float(view.game.fusions[0].elapsed), 0.1)
			and is_equal_approx(float(view.game.spawn_elapsed), 0.1),
			"Fusion, falling supply and the next spawn clock continue alongside the reward effect")
		var snapshot: Dictionary = view.game.snapshot()
		view.pause(true)
		var reward: Dictionary = view._reward_presentation.snapshot()
		_advance_owner(view, 1.0)
		check(view.game.cells == snapshot.cells and view.game.fusions == snapshot.fusions
			and view._reward_presentation.snapshot() == reward,
			"An explicit menu pause still freezes an active fusion and chest effect together")
		view.pause(false)
		view.configure(words, 3, Data.theme("spring"), manifest, reduced, 42)
		view._chest_milestone(0, 1)
		view.advance_reward_presentation(1.4)
		view.game.spawn_elapsed = view.game.spawn_interval - 0.05
		count = view.game.generated_tiles
		view._process(0.1)
		check(view.game.generated_tiles == count + 4 and view._reward_presentation.visible
			and is_equal_approx(view.game.spawn_elapsed, 0.05),
			"A natural spawn deadline releases supply without waiting for confetti to finish")
		view.configure(words, 3, Data.theme("spring"), manifest, reduced, 42)
		while view.game.cells.size() < view.game.CAPACITY:
			view.game.drop_now()
			view.game.step(view.game.SETTLE_SECONDS)
		view._sync_tiles()
		view._refresh_hud()
		view._chest_milestone(0, 1)
		view.advance_reward_presentation(1.4)
		var danger: float = view.game.full_elapsed
		view._process(0.2)
		check(danger >= 0.0 and is_equal_approx(view.game.full_elapsed, danger + 0.2)
			and view._reward_presentation.visible and view.game.phase == "playing",
			"A full board continues its danger countdown during the same HUD reward effect")
	view.stop()


func _check_later_pickup(view, words: Array, manifest: Dictionary) -> void:
	view.configure(words, 3, Data.theme("spring"), manifest, false, 42)
	# The fifth pickup is still flying after the first four filled the unlock ring.
	view.game.fragment_count = 5
	view.game.chest_tier = 1
	view.game.chest_count = 1
	view._loot_flights.append({"from": view._board.get_center(), "elapsed": 0.0, "amount": 1})
	view._refresh_hud()
	view._loot_meter.settle()
	view._chest_milestone(0, 1)
	view.advance_reward_presentation(0.64)
	view._process(0.02)
	check(view._reward_presentation.visible and view._loot_flights.size() == 1
		and is_equal_approx(float(view._loot_flights[0].elapsed), 0.02)
		and is_equal_approx(float(view._loot_meter.snapshot().displayed), 4.0),
		"A later in-flight pickup cannot postpone celebration for the already filled unlock ring")
	view.stop()


func _check_finish_during_reward(view, words: Array, manifest: Dictionary) -> void:
	view.configure(words, 3, Data.theme("spring"), manifest, false, 42)
	view.game.fragment_count = 3
	var pair: Array[int] = _matching_pair(view, true)
	check(pair.size() == 2 and view.game.try_merge(pair[0], pair[1]) == "correct",
		"The finish fixture unlocks a real chest through a marked match")
	_advance_owner(view, 2.9)
	check(view.game.fragment_count == 4 and view.game.chest_count == 1
		and view._reward_presentation.snapshot().confetti,
		"A committed chest is already earned while its confetti is active")
	view._chest_milestone(1, 2)
	check(view._reward_presentation.snapshot().queued == 2,
		"Finishing is exercised with both active and queued visual milestones")
	var results: Array[Dictionary] = []
	var record: Callable = func(result: Dictionary) -> void: results.append(result)
	view.round_finished.connect(record)
	view.finish_button.pressed.emit()
	view.finish_button.pressed.emit()
	_advance_owner(view, 4.0)
	view.round_finished.disconnect(record)
	check(view.game.phase == "finished" and results.size() == 1
		and int(results[0].chest_count) == 1 and int(results[0].chest_tier) == 1
		and int(results[0].fragment_count) == 4 and int(results[0].score) == 1,
		"Finish during confetti settles the exact earned chest once despite repeated clicks")
	check(not view._reward_presentation.is_active() and not view._reward_presentation.visible
		and not view._reward_presentation.snapshot().confetti,
		"Finishing clears the active paper and every queued visual upgrade immediately")
	view.stop()

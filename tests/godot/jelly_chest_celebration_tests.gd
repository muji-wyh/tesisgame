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
	check(view.snapshot().confetti and view._heading.text == "Chest upgraded!"
		and view._caption.text == "Chest Lv. 2", "Upgrade reveals its precise level together with full-screen confetti")
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
	check(view.visible and not view.snapshot().confetti and is_equal_approx(view._heading.modulate.a, 1.0),
		"Reduced motion shows a static chest and readable labels without flying paper")
	view.advance(0.72)
	check(view.snapshot().revealed and not view.snapshot().confetti and heard.size() == 2,
		"Reduced motion preserves the same reward gate and one sound per milestone")
	view.advance(2.0)
	check(not view.is_active(), "Static presentation returns control after the same duration")


func _check_layouts(view) -> void:
	_begin(view, 1, 2)
	view.advance(1.5)
	for dimensions: Vector2 in [Vector2(1366, 600), Vector2(390, 640), Vector2(320, 220), Vector2(844, 235)]:
		view.size = dimensions
		view._layout()
		for label: Label in [view._heading, view._caption]:
			check(Rect2(Vector2.ZERO, dimensions).encloses(label.get_rect()),
				"%s keeps the reward title and level within the available screen" % dimensions)
		check(not view._heading.get_rect().intersects(view._caption.get_rect()),
			"%s separates the unlock title from the level label" % dimensions)


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
	check(view._reward_presentation.visible and not view._can_play() and view.drop_button.disabled,
		"Returning resumes the same reward while board and fast-drop controls stay gated")
	view.stop()
	check(not view._reward_presentation.is_active() and not view._reward_presentation.visible,
		"Leaving Jelly immediately removes the old reward and its queue")
	_check_pending_fusion_pause(view, words, data.chests)
	view.configure(words, 3, Data.theme("spring"), data.chests, false, 42)
	view._chest_milestone(0, 1)
	view.advance_reward_presentation(2.77)
	view._process(0.1)
	check(not view._reward_presentation.is_active() and is_equal_approx(view.game.spawn_elapsed, 0.07),
		"Gameplay receives only the frame's unused time after the reward performance ends")
	for action: String in ["stop", "reconfigure"]:
		view.configure(words, 3, Data.theme("spring"), data.chests, false, 42)
		view._chest_milestone(0, 1)
		view.advance_reward_presentation(0.6)
		var interrupt: Callable = func(cue: String) -> void:
			if cue != "assemble":
				return
			if action == "stop":
				view.stop()
			else:
				view.configure(words, 3, Data.theme("spring"), data.chests, false, 72)
		view.audio_requested.connect(interrupt)
		view._process(0.2)
		view.audio_requested.disconnect(interrupt)
		check(not view._reward_presentation.is_active(),
			"Synchronous %s during a reward cue cannot retain an old presentation" % action)
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
		if view.game.is_fusing(int(a.id)) or (marked and not bool(a.chest)):
			continue
		for b: Dictionary in view.game.cells:
			if not view.game.is_fusing(int(b.id)) and a.word.id == b.word.id and a.kind != b.kind:
				return [int(a.id), int(b.id)]
	return []


func _check_pending_fusion_pause(view, words: Array, manifest: Dictionary) -> void:
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
	view.cancel_input()
	view._refresh_controls()
	check(not view.finish_button.disabled and view.navigation_controls().has(view.finish_button),
		"A pending synthesis keeps Finish available until the reward presentation actually begins")
	view.pause(true)
	var state: Dictionary = view.game.snapshot()
	_advance_owner(view, 1.0)
	check(view.game.snapshot() == state, "Menu pause freezes the sibling fusion and queued synthesis")
	view.pause(false)
	_advance_owner(view, 0.21)
	check(view.game.fusions.is_empty() and view.game.cleared_pairs == 2
		and view._reward_presentation.is_active() and not view._can_play() and view.finish_button.disabled,
		"Only the actual chest presentation gates gameplay after the final sibling finishes")
	_advance_owner(view, 0.7)
	check(not view._reward_presentation.visible,
		"Synthesis waits for the arriving fragment's visible progress fill")
	_advance_owner(view, 0.4)
	check(view._reward_presentation.visible and view.game.fragment_count == 4 and view.game.chest_count == 1,
		"Synthesis then starts once with the previously committed single chest")
	view.stop()

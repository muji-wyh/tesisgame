extends SceneTree

const Confetti = preload("res://scripts/reward_confetti.gd")
const RoundCelebration = preload("res://scripts/round_celebration.gd")
const ChestCelebration = preload("res://scripts/jelly_chest_celebration.gd")
const Data = preload("res://scripts/game_data.gd")
const BEFORE = preload("res://assets/chests/energy/closed.png")
const AFTER = preload("res://assets/chests/royal/closed.png")
const FRAMES: int = 180

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 620)
	var paper := Confetti.new()
	root.add_child(paper)
	check(paper.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Falling paper cannot capture gameplay input")
	_check_samples(paper)
	_check_viewport_transform(paper)
	var layouts: Array = [
		{"screen": Rect2(0, 0, 1366, 768), "unit": 1.0},
		{"screen": Rect2(-24, -60, 390, 844), "unit": 1.0},
		{"screen": Rect2(30, 18, 844, 235), "unit": 1.25},
		{"screen": Rect2(-80, 12, 320, 220), "unit": 0.75},
		{"screen": Rect2(-48, -120, 1920, 1240), "unit": 2.0},
	]
	for duration: float in [RoundCelebration.DURATION - 1.8, Confetti.DURATION]:
		for layout: Dictionary in layouts:
			_check_paths(paper, layout.screen, float(layout.unit), duration)
	_check_owner_windows()
	paper.free()
	print("Reward confetti: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_samples(paper) -> void:
	for values: Array in [[-0.1, 1.2, 1.0], [INF, 1.2, 1.0], [NAN, 1.2, 1.0],
		[0.2, 0.0, 1.0], [0.2, -1.0, 1.0], [0.2, INF, 1.0], [0.2, NAN, 1.0],
		[0.2, 1.2, 0.0], [0.2, 1.2, -0.1], [0.2, 1.2, NAN]]:
		paper.sample(float(values[0]), float(values[1]), float(values[2]))
		check(not paper.visible, "Invalid, pre-reveal or transparent clock samples hide paper")
	var screen := Rect2(12, 40, 960, 620)
	paper.sample(0.45 * 1.2, 1.2)
	var short: Dictionary = paper._paper_state(0, screen, 1.0)
	paper.sample(0.45 * Confetti.DURATION, Confetti.DURATION)
	var ordinary: Dictionary = paper._paper_state(0, screen, 1.0)
	check(not short.is_empty() and not ordinary.is_empty()
		and short.position.is_equal_approx(ordinary.position)
		and short.size.is_equal_approx(ordinary.size)
		and is_equal_approx(float(short.rotation), float(ordinary.rotation)),
		"The shorter finale samples the same complete path as the ordinary reward window")
	paper.sample(0.45 * 1.2, 1.2, 0.4)
	check(is_equal_approx(float(paper._paper_state(0, screen, 1.0).color.a), 0.4),
		"Explicit caller opacity is preserved without an additional renderer fade")
	paper.sample(1.2, 1.2)
	check(not paper.visible, "The owner deadline hides the completed burst")
	paper.sample(3.0, 1.2)
	check(not paper.visible, "Later clock samples cannot restart a completed burst")


func _check_viewport_transform(paper) -> void:
	paper.position = Vector2(47, 91)
	paper.scale = Vector2(1.5, 1.5)
	var bounds: Rect2 = paper.get_global_transform_with_canvas() * paper.screen_rect()
	check(bounds.is_equal_approx(root.get_visible_rect()),
		"An offset scaled owner still samples the entire visible viewport")
	paper.position = Vector2.ZERO
	paper.scale = Vector2.ONE


func _half_extent(state: Dictionary) -> Vector2:
	# Measure the actual rotated textured rectangle, not just its center.
	var half: Vector2 = state.size * 0.5
	var angle: float = float(state.rotation)
	return Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y,
		absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)


func _check_paths(paper, screen: Rect2, unit: float, duration: float) -> void:
	var exit_bands: Dictionary = {}
	var first_exit: float = 1.0
	var last_exit: float = 0.0
	for index in range(Confetti.PAPER_COUNT):
		var previous: Dictionary = {}
		var last: Dictionary = {}
		var launch_y: float = 0.0
		var apex_y: float = INF
		var last_progress: float = 0.0
		var first_empty: float = 1.0
		var observed: bool = false
		var ended: bool = false
		var repeated: bool = false
		var finite: bool = true
		var bounded: bool = true
		var continuous: bool = true
		var opaque: bool = true
		var bottom_visited: bool = false
		var rises: bool = false
		var descends: bool = false
		for frame in range(FRAMES + 1):
			var progress: float = float(frame) / float(FRAMES)
			paper.sample(progress * duration, duration)
			var state: Dictionary = paper._paper_state(index, screen, unit)
			if state.is_empty():
				if observed and not ended:
					ended = true
					first_empty = progress
				continue
			if ended:
				repeated = true
			var point: Vector2 = state.position
			var half: Vector2 = _half_extent(state)
			if not observed:
				launch_y = point.y
				observed = true
			finite = finite and point.is_finite() and state.size.is_finite() and is_finite(float(state.rotation))
			bounded = bounded and point.x - half.x >= screen.position.x - 0.01 and point.x + half.x <= screen.end.x + 0.01
			opaque = opaque and is_equal_approx(float(state.color.a), 1.0)
			apex_y = minf(apex_y, point.y)
			if point.y >= screen.end.y - screen.size.y * 0.1 and point.y <= screen.end.y:
				bottom_visited = true
			if not previous.is_empty():
				var delta: Vector2 = point - Vector2(previous.position)
				rises = rises or delta.y < -0.01
				descends = descends or delta.y > 0.01
				continuous = continuous and delta.length() < screen.size.length() * 0.12
			previous = state
			last = state
			last_progress = progress
		var context: String = "Paper %d at %s, unit %.2f, %.2fs" % [index, screen.size, unit, duration]
		check(observed and ended and not repeated, context + " has exactly one bounded lifetime")
		check(finite and continuous, context + " moves continuously with finite transforms")
		check(bounded, context + " keeps its rotated footprint inside the screen sides")
		check(rises and descends and apex_y < launch_y - screen.size.y * 0.20,
			context + " rises to an apex and then falls")
		check(bottom_visited and opaque, context + " reaches the bottom tenth while fully opaque")
		if last.is_empty():
			continue
		# Refine the last visible instant; coarse frame samples can miss the few
		# pixels between the complete bottom exit and an individual piece's end.
		var lower: float = last_progress
		var upper: float = first_empty
		for iteration in range(18):
			var middle: float = (lower + upper) * 0.5
			paper.sample(middle * duration, duration)
			var state: Dictionary = paper._paper_state(index, screen, unit)
			if state.is_empty():
				upper = middle
			else:
				lower = middle
				last = state
		var last_half: Vector2 = _half_extent(last)
		check(float(last.position.y) - last_half.y > screen.end.y,
			context + " disappears only after its entire rotated footprint exits the bottom")
		check(is_equal_approx(float(last.color.a), 1.0), context + " never fades while exiting")
		check(upper < 1.0, context + " completes before the owner hides the burst")
		exit_bands[roundi(upper * 100.0)] = true
		first_exit = minf(first_exit, upper)
		last_exit = maxf(last_exit, upper)
	check(exit_bands.size() >= 8 and last_exit - first_exit > 0.12,
		"Paper exits are staggered instead of disappearing together at %s / %.2fs" % [screen.size, duration])
	paper.sample(duration, duration)
	check(not paper.visible, "The completed %s / %.2fs burst is hidden" % [screen.size, duration])


func _bottom_paper_count(paper) -> int:
	var screen: Rect2 = paper.screen_rect()
	var count: int = 0
	for index in range(Confetti.PAPER_COUNT):
		var state: Dictionary = paper._paper_state(index, screen, 1.0)
		if not state.is_empty() and float(state.position.y) >= screen.end.y - screen.size.y * 0.1 \
			and float(state.position.y) - _half_extent(state).y <= screen.end.y:
			check(is_equal_approx(float(state.color.a), 1.0), "An owner keeps descending paper opaque near its deadline")
			count += 1
	return count


func _check_owner_windows() -> void:
	var data := Data.new()
	check(data.load_all(), "Reward owner fixtures load the production chest manifest")
	if not data.error.is_empty():
		return
	var round := RoundCelebration.new()
	root.add_child(round)
	round.size = Vector2(960, 620)
	round.begin("falling-paper", "spring", data.chests, 1, false)
	round.set_process(false)
	var finale_window: float = RoundCelebration.DURATION - 1.8
	round.advance(1.8 + finale_window * 0.92)
	check(round.snapshot().confetti and _bottom_paper_count(round._confetti) > 0,
		"The short round finale shows opaque paper reaching the bottom before Open chest")
	check(not round.is_ready(), "Falling paper preserves the existing three-second performance gate")
	round.advance(RoundCelebration.DURATION)
	check(round.is_ready() and not round.snapshot().confetti,
		"The original finale deadline still clears paper and enables the invitation")
	round.stop()
	round.free()
	var chest := ChestCelebration.new()
	root.add_child(chest)
	chest.size = Vector2(960, 620)
	chest.set_chest_anchor(Rect2(16, 12, 72, 72))
	chest.enqueue(0, 1, BEFORE, AFTER)
	var chest_window: float = ChestCelebration.PERFORMANCE_SECONDS - ChestCelebration.REVEAL_SECONDS
	chest.advance(ChestCelebration.ARRIVAL_SECONDS + ChestCelebration.REVEAL_SECONDS + chest_window * 0.92)
	check(chest.snapshot().confetti and _bottom_paper_count(chest._confetti) > 0,
		"Jelly and Voice Pop retain opaque bottom-reaching paper during the chest's closing fade")
	chest.advance(ChestCelebration.ARRIVAL_SECONDS + ChestCelebration.PERFORMANCE_SECONDS)
	check(not chest.is_active() and not chest.snapshot().confetti,
		"Falling paper leaves the original milestone queue deadline unchanged")
	chest.clear()
	chest.free()

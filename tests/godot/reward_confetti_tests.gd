extends SceneTree

const Confetti = preload("res://scripts/reward_confetti.gd")
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
	var clip := Control.new()
	clip.position = Vector2(47, 91)
	clip.scale = Vector2(1.5, 1.5)
	clip.size = Vector2(120, 100)
	clip.clip_contents = true
	root.add_child(clip)
	var paper := Confetti.new()
	clip.add_child(paper)
	check(paper._surface.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and paper._surface.focus_mode == Control.FOCUS_NONE,
		"The viewport overlay cannot capture pointer, keyboard or gamepad input")
	check(paper is CanvasLayer and paper.layer > 0
		and (paper._surface.get_global_transform_with_canvas() * paper.screen_rect()).is_equal_approx(root.get_visible_rect()),
		"Paper has its own full-viewport canvas despite an offset, scaled and clipped ancestor")
	_check_lifecycle(paper)
	for layout: Dictionary in [
		{"screen": Rect2(0, 0, 1366, 768), "unit": 1.0},
		{"screen": Rect2(0, 0, 390, 844), "unit": 1.0},
		{"screen": Rect2(0, 0, 568, 320), "unit": 1.0},
		{"screen": Rect2(0, 0, 320, 220), "unit": 0.75},
		{"screen": Rect2(0, 0, 1920, 1240), "unit": 2.0}]:
		_check_paths(paper, layout.screen, float(layout.unit))
	clip.free()
	print("Reward confetti: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_lifecycle(paper) -> void:
	check(not paper.burst("") and not paper.is_active(), "An empty reward identity cannot launch paper")
	check(paper.burst("round-1:jelly:2") and not paper.burst("round-1:jelly:2"),
		"Each chest reveal starts only one burst")
	paper.advance(1.4)
	var before: Dictionary = paper.snapshot()
	for delta: float in [-1.0, 0.0, INF, NAN]:
		paper.advance(delta)
	check(paper.snapshot() == before, "Invalid timing samples cannot corrupt a burst")
	paper.set_paused(true)
	paper.advance(12.0)
	check(not paper.visible and paper.is_active() and paper.snapshot().ages == before.ages,
		"Menu and background pauses hide and freeze the independent tail")
	paper.set_paused(false)
	check(paper.visible and paper.snapshot().ages == before.ages, "Resume continues the same paper without a second burst")
	paper.advance(1.6)
	check(paper.is_active() and paper.visible, "Paper remains alive after the three-second Pip performance")
	check(paper.burst("round-1:jelly:3"), "A later tier can celebrate while an earlier tail is falling")
	paper.advance(3.5)
	check(paper.snapshot().ages.size() == 1 and is_equal_approx(float(paper.snapshot().ages[0]), 3.5),
		"Overlapping rewards retain independent ages without resetting the older tail")
	paper.advance(3.0)
	check(not paper.is_active() and not paper.visible and not paper.burst("round-1:jelly:2"),
		"Expired rewards stay deduplicated for the round")
	paper.burst("round-1:jelly:4")
	paper.clear()
	check(not paper.is_active() and not paper.visible and paper.snapshot().keys.is_empty(),
		"Navigation and a new round clear all paper and reward identities immediately")

func _half_extent(state: Dictionary) -> Vector2:
	var half: Vector2 = state.size * 0.5
	var angle: float = float(state.rotation)
	return Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y,
		absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)

func _check_paths(paper, screen: Rect2, unit: float) -> void:
	var columns: Dictionary = {}
	var canopy_top: float = INF
	var canopy_bottom: float = -INF
	var first_exit: float = INF
	var last_exit: float = 0.0
	for index in range(Confetti.PAPER_COUNT):
		var canopy: Dictionary = paper._paper_state(index, screen, unit, 2.8)
		canopy_top = minf(canopy_top, float(canopy.position.y))
		canopy_bottom = maxf(canopy_bottom, float(canopy.position.y))
		var previous: Dictionary = {}
		var last: Dictionary = {}
		var last_time: float = 0.0
		var first_empty: float = Confetti.DURATION
		var apex_time: float = 0.0
		var apex_y: float = INF
		var ended: bool = false
		var repeated: bool = false
		var bounded: bool = true
		var continuous: bool = true
		var opaque: bool = true
		var bottom_visited: bool = false
		var descent_speed: float = 0.0
		for frame in range(385):
			var seconds: float = float(frame) / 60.0
			var state: Dictionary = paper._paper_state(index, screen, unit, seconds)
			if state.is_empty():
				if not last.is_empty() and not ended:
					ended = true
					first_empty = seconds
				continue
			repeated = repeated or ended
			var point: Vector2 = state.position
			var half: Vector2 = _half_extent(state)
			bounded = bounded and point.is_finite() and state.size.is_finite() \
				and point.x - half.x >= screen.position.x - 0.01 and point.x + half.x <= screen.end.x + 0.01
			opaque = opaque and is_equal_approx(float(state.color.a), 1.0)
			if point.y < apex_y:
				apex_y = point.y
				apex_time = seconds
			if point.y >= screen.end.y - screen.size.y * 0.1 and point.y <= screen.end.y:
				bottom_visited = true
			if not previous.is_empty():
				var delta: Vector2 = point - Vector2(previous.position)
				continuous = continuous and delta.length() < screen.size.length() * 0.12
				descent_speed = maxf(descent_speed, delta.y * 60.0)
			if frame == 90:
				columns[clampi(int((point.x - screen.position.x) / screen.size.x * 8.0), 0, 7)] = true
			previous = state
			last = state
			last_time = seconds
		var context: String = "Paper %d at %s" % [index, screen.size]
		check(not last.is_empty() and ended and not repeated and bounded and continuous,
			context + " has one finite, continuous path inside the screen sides")
		check(apex_time < 1.1 and first_empty - apex_time > 4.0,
			context + " keeps a brisk launch followed by more than four seconds of drifting")
		check(descent_speed < screen.size.y * 0.4, context + " falls at a gentle terminal speed")
		check(bottom_visited and opaque, context + " reaches the bottom while fully opaque")
		var lower: float = last_time
		var upper: float = first_empty
		for iteration in range(18):
			var middle: float = (lower + upper) * 0.5
			var state: Dictionary = paper._paper_state(index, screen, unit, middle)
			if state.is_empty():
				upper = middle
			else:
				lower = middle
				last = state
		check(float(last.position.y) - _half_extent(last).y > screen.end.y,
			context + " disappears only after its whole footprint exits the bottom")
		first_exit = minf(first_exit, upper)
		last_exit = maxf(last_exit, upper)
	check(columns.size() == 8, "Paper spans all eight viewport columns at %s" % screen.size)
	check(canopy_bottom - canopy_top > screen.size.y * 0.20,
		"Paper drifts at varied heights instead of one horizontal strip at %s" % screen.size)
	check(last_exit - first_exit > 0.9, "Paper finishes gradually instead of disappearing all at once at %s" % screen.size)

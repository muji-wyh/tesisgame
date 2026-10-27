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
	_check_density_reduction(paper)
	_check_lifecycle(paper)
	_check_viewport_coverage(paper)
	_check_burst_sampling()
	_check_motion_variety(paper)
	_check_small_stage_celebration(paper)
	paper.burst("paths:earned-tier-three")
	var variations: Array[float] = [0.0, float(paper._bursts[0].variation), 0.999999]
	paper.clear()
	for layout: Dictionary in [
		{"screen": Rect2(0, 0, 1366, 768), "unit": 1.0},
		{"screen": Rect2(0, 0, 390, 844), "unit": 1.0},
		{"screen": Rect2(0, 0, 568, 320), "unit": 1.0},
		{"screen": Rect2(0, 0, 320, 220), "unit": 0.75},
		{"screen": Rect2(0, 0, 1920, 1240), "unit": 2.0}]:
		for variation: float in variations:
			_check_paths(paper, layout.screen, float(layout.unit), variation)
	clip.free()
	print("Reward confetti: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_density_reduction(paper) -> void:
	for dimensions: Vector2 in [Vector2(320, 220), Vector2(390, 844), Vector2(960, 620),
		Vector2(1366, 768), Vector2(1920, 1240), Vector2(3440, 1440)]:
		var screen := Rect2(Vector2.ZERO, dimensions)
		for unit: float in [0.25, 0.75, 1.0, 1.5, 2.0]:
			var full_spacing: float = 42.0 * maxf(0.25, unit)
			var previous_full: int = clampi(ceili(screen.get_area() / pow(full_spacing, 2)), 384, 1200)
			check(paper._paper_count(screen, unit) == roundi(previous_full / 3.0),
				"Full-screen paper is exactly the nearest whole one-third of its previous population at %s, scale %s" % [dimensions, unit])
			var small_spacing: float = 80.0 * maxf(0.25, unit)
			var previous_small: int = clampi(ceili(screen.get_area() / 3.0 / pow(small_spacing, 2)), 24, 72)
			check(paper._burst_count({"small": true}, screen, unit) == roundi(previous_small / 3.0),
				"Small bursts also use one-third of their previous population instead of retaining the old minimum")


func _check_small_stage_celebration(paper) -> void:
	paper.clear()
	check(paper.has_method("burst_small"), "A stage has a dedicated restrained one-third-screen paper preset")
	if not paper.has_method("burst_small"):
		return
	check(bool(paper.call("burst_small", "stage:small")) and not bool(paper.call("burst_small", "stage:small")),
		"The smaller stage celebration retains reward-key deduplication")
	var snapshot: Dictionary = paper.snapshot()
	check(int(snapshot.paper_count) >= 8 and int(snapshot.paper_count) <= 24,
		"A small stage burst uses eight to twenty-four papers after the one-third reduction")
	var region_values: Array = snapshot.get("regions", [])[0]
	var region := Rect2(region_values[0], region_values[1], region_values[2], region_values[3])
	check(region.size.y <= paper.screen_rect().size.y / 3.0 + 0.01
		and paper.screen_rect().encloses(region),
		"The whole celebration is confined to the upper third of the viewport")
	paper.advance(2.5)
	check(not paper.is_active(), "A restrained stage celebration finishes promptly without a long full-screen tail")
	paper.clear()

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

func _check_burst_sampling() -> void:
	var coarse := Confetti.new()
	var fine := Confetti.new()
	root.add_child(coarse)
	root.add_child(fine)
	for effect in [coarse, fine]:
		check(effect.burst("sampling:first-chest"), "A deterministic motion fixture accepts its first reward")
	coarse.advance(2.4)
	for frame in range(120):
		fine.advance(0.02)
	var first_variation: float = float(coarse._bursts[0].variation)
	var before_retry: Array[Dictionary] = coarse._bursts.duplicate(true)
	check(not coarse.burst("sampling:first-chest") and coarse._bursts == before_retry,
		"Retrying an active reward preserves its existing age and motion variation")
	for effect in [coarse, fine]:
		check(effect.burst("sampling:upgraded-chest"), "A different earned chest can overlap the older paper")
	check(float(coarse._bursts[0].variation) == first_variation
		and float(coarse._bursts[1].variation) != first_variation,
		"A new reward receives independent variation without reshuffling the active tail")
	coarse.advance(0.8)
	for frame in range(80):
		fine.advance(0.01)
	var screen := Rect2(0, 0, 960, 620)
	var changed_paths: int = 0
	for burst_index in range(2):
		var a: Dictionary = coarse._bursts[burst_index]
		var b: Dictionary = fine._bursts[burst_index]
		check(is_equal_approx(float(a.age), float(b.age)) and a.variation == b.variation,
			"Coarse and fine frames retain the same independent burst age and deterministic variation")
		for index in range(Confetti.PAPER_COUNT):
			var first: Dictionary = coarse._paper_state(index, screen, 1.0, float(a.age), float(a.variation))
			var second: Dictionary = fine._paper_state(index, screen, 1.0, float(b.age), float(b.variation))
			check(first.is_empty() == second.is_empty(), "Frame subdivision cannot create or delete a paper at a different age")
			if first.is_empty() or second.is_empty():
				continue
			check(Vector2(first.position).is_equal_approx(second.position) and Vector2(first.size).is_equal_approx(second.size)
				and is_equal_approx(float(first.rotation), float(second.rotation))
				and is_equal_approx(float(first.bend), float(second.bend)) and Color(first.color).is_equal_approx(second.color),
				"A slow frame samples the same wind, tumble, fold, and lighting as many small frames")
			check(first == coarse._paper_state(index, screen, 1.0, float(a.age), float(a.variation)),
				"Repeated drawing of one paper never consumes randomness or advances its pose")
	for index in range(Confetti.PAPER_COUNT):
		var first: Dictionary = coarse._paper_state(index, screen, 1.0, 2.4, float(coarse._bursts[0].variation))
		var second: Dictionary = coarse._paper_state(index, screen, 1.0, 2.4, float(coarse._bursts[1].variation))
		if Vector2(first.position).distance_to(second.position) > 0.01 \
			or absf(float(first.rotation) - float(second.rotation)) > 0.001 \
			or Vector2(first.size).distance_to(second.size) > 0.01:
			changed_paths += 1
	check(changed_paths > Confetti.PAPER_COUNT / 2,
		"Overlapping rewards do not replay the same synchronized paper poses at the same elapsed time")
	var paused: Array[Dictionary] = coarse._bursts.duplicate(true)
	coarse.set_paused(true)
	coarse.advance(10.0)
	check(coarse._bursts == paused, "Pausing freezes every burst's motion seed together with its timeline")
	coarse.set_paused(false)
	coarse.clear()
	check(coarse.burst("sampling:first-chest") and float(coarse._bursts[0].variation) == first_variation,
		"Recreating the same reward identity reproduces its paper variation without dependence on earlier bursts")
	coarse.free()
	fine.free()


func _check_viewport_coverage(paper) -> void:
	var previous_count: int = 0
	for dimensions: Vector2 in [Vector2(390, 844), Vector2(1366, 768), Vector2(2560, 1440), Vector2(3440, 1440)]:
		var screen := Rect2(Vector2.ZERO, dimensions)
		var count: int = Confetti.PAPER_COUNT
		check(paper.has_method("_paper_count"), "Confetti density adapts to the actual viewport instead of a fixed particle count")
		if paper.has_method("_paper_count"):
			count = int(paper.call("_paper_count", screen, 1.0))
		check(count >= 128 and count <= 400 and count >= previous_count,
			"Larger screens retain adaptive coverage with a lighter, bounded paper population")
		previous_count = count
		for variation: float in [0.0, 0.43, 0.999999]:
			var cells: Dictionary = {}
			for index in range(count):
				var state: Dictionary = paper._paper_state(index, screen, 1.0, 1.25, variation)
				if state.is_empty() or not screen.has_point(state.position):
					continue
				var column: int = clampi(int(state.position.x / dimensions.x * 6.0), 0, 5)
				var row: int = clampi(int(state.position.y / dimensions.y * 5.0), 0, 4)
				var key := Vector2i(column, row)
				cells[key] = int(cells.get(key, 0)) + 1
			var occupied_columns: Dictionary = {}
			var occupied_rows: Dictionary = {}
			for cell: Vector2i in cells:
				occupied_columns[cell.x] = true
				occupied_rows[cell.y] = true
			check(occupied_columns.size() == 6,
				"The lighter canopy still reaches all six full-screen columns instead of becoming a local patch")
			check(occupied_rows.size() == 5,
				"The lighter canopy still spans all five vertical regions at %s, variation %.3f: %s" %
					[dimensions, variation, cells])


func _check_motion_variety(paper) -> void:
	var screen := Rect2(0, 0, 960, 620)
	var clockwise: int = 0
	var counterclockwise: int = 0
	var changing_spin: int = 0
	var changing_thickness: int = 0
	var bow_positive: bool = false
	var bow_negative: bool = false
	for index in range(Confetti.PAPER_COUNT):
		var early: Dictionary = paper._paper_state(index, screen, 1.0, 1.2)
		var middle: Dictionary = paper._paper_state(index, screen, 1.0, 2.4)
		var late: Dictionary = paper._paper_state(index, screen, 1.0, 3.6)
		var first_turn: float = float(middle.rotation) - float(early.rotation)
		var second_turn: float = float(late.rotation) - float(middle.rotation)
		if first_turn + second_turn > 0.0:
			clockwise += 1
		elif first_turn + second_turn < 0.0:
			counterclockwise += 1
		if absf(first_turn - second_turn) > 0.001:
			changing_spin += 1
		var narrowest: float = INF
		var widest: float = 0.0
		var thinnest: float = INF
		var thickest: float = 0.0
		for sample in range(31):
			var state: Dictionary = paper._paper_state(index, screen, 1.0, 1.2 + float(sample) * 0.1)
			var dimensions: Vector2 = state.size
			var bow: float = float(state.bend)
			check(dimensions.x > 0.0 and dimensions.y > 0.0 and is_finite(bow)
				and absf(bow) < dimensions.y * 0.5,
				"Paper folds remain finite and inside the reported body dimensions")
			narrowest = minf(narrowest, dimensions.x)
			widest = maxf(widest, dimensions.x)
			thinnest = minf(thinnest, dimensions.y)
			thickest = maxf(thickest, dimensions.y)
			bow_positive = bow_positive or bow > 0.001
			bow_negative = bow_negative or bow < -0.001
		check(widest - narrowest > 0.01, "A drifting paper visibly changes projected width as its face turns")
		if thickest - thinnest > 0.01:
			changing_thickness += 1
	check(clockwise > 0 and counterclockwise > 0, "The canopy contains papers tumbling in both directions")
	check(changing_spin > Confetti.PAPER_COUNT / 2,
		"Most papers vary their tumble speed instead of rotating as a rigid synchronized layer")
	check(changing_thickness > Confetti.PAPER_COUNT / 2 and bow_positive and bow_negative,
		"Independent pitch and signed bow give the falling paper more than a flat width flip")
	for index in range(0, Confetti.PAPER_COUNT, 13):
		var previous: Dictionary = {}
		var darkest: float = INF
		var brightest: float = -INF
		var continuous: bool = true
		for sample in range(721):
			var state: Dictionary = paper._paper_state(index, screen, 1.0, 1.0 + float(sample) / 240.0)
			var color: Color = state.color
			var light: float = color.get_luminance()
			darkest = minf(darkest, light)
			brightest = maxf(brightest, light)
			if not previous.is_empty():
				var before: Color = previous.color
				continuous = continuous and maxf(absf(color.r - before.r),
					maxf(absf(color.g - before.g), absf(color.b - before.b))) < 0.03
			previous = state
		check(continuous and brightest - darkest > 0.01,
			"Front-to-back lighting changes smoothly through the fold instead of switching color abruptly")


func _half_extent(state: Dictionary) -> Vector2:
	var half: Vector2 = state.size * 0.5
	var angle: float = float(state.rotation)
	return Vector2(absf(cos(angle)) * half.x + absf(sin(angle)) * half.y,
		absf(sin(angle)) * half.x + absf(cos(angle)) * half.y)

func _check_paths(paper, screen: Rect2, unit: float, variation: float = 0.0) -> void:
	var columns: Dictionary = {}
	var canopy_top: float = INF
	var canopy_bottom: float = -INF
	var first_exit: float = INF
	var last_exit: float = 0.0
	for index in range(Confetti.PAPER_COUNT):
		var canopy: Dictionary = paper._paper_state(index, screen, unit, 2.8, variation)
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
			var state: Dictionary = paper._paper_state(index, screen, unit, seconds, variation)
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
		var context: String = "Paper %d at %s with variation %.6f" % [index, screen.size, variation]
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
			var state: Dictionary = paper._paper_state(index, screen, unit, middle, variation)
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

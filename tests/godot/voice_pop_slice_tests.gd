extends SceneTree

const Slice = preload("res://scripts/voice_pop_slice.gd")
const PopView = preload("res://scripts/voice_pop.gd")

var checks: int = 0
var failures: int = 0
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func area(polygon: PackedVector2Array) -> float:
	var result: float = 0.0
	for index in range(polygon.size()):
		result += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(result) * 0.5


func fixture(uid: int = 1) -> Dictionary:
	return Slice.create({"uid": uid, "word": {"id": "apple", "text": "apple"},
		"center": Vector2(200, 260), "size": Vector2(180, 149), "rotation": 0.12}, 10, Color.CORAL)


func check_geometry() -> void:
	for uid in range(1, 9):
		var effect: Dictionary = fixture(uid)
		var normal: Vector2 = Slice.normal(uid)
		var origin: Vector2 = Slice.cut_origin(effect.size)
		var whole: PackedVector2Array = Slice.rounded_rect(effect.size, 19.0)
		var upper: PackedVector2Array = Slice.clip_half(whole, origin, normal, -1.0)
		var lower: PackedVector2Array = Slice.clip_half(whole, origin, normal, 1.0)
		check(upper.size() >= 3 and lower.size() >= 3, "Every blade angle creates two drawable fragments")
		check(absf(area(upper) + area(lower) - area(whole)) < 0.05,
			"The cut preserves the whole card without duplicated or missing surface")
		var word_band := Rect2(-74, float(effect.size.y) * 0.5 - 38.0, 148, 27)
		for corner in [word_band.position, Vector2(word_band.end.x, word_band.position.y),
			word_band.end, Vector2(word_band.position.x, word_band.end.y)]:
			check((corner - origin).dot(normal) > 0.0, "The complete readable word belongs to the actual lower fragment")
		for point in upper:
			check((point - origin).dot(normal) <= 0.001, "The upper fragment stays on its own side of the seam")
		for point in lower:
			check((point - origin).dot(normal) >= -0.001, "The lower fragment stays on its own side of the seam")
		var art := Rect2(-50, -62, 100, 100)
		var quad := PackedVector2Array([art.position, Vector2(art.end.x, art.position.y), art.end, Vector2(art.position.x, art.end.y)])
		for side in [-1.0, 1.0]:
			var cut: PackedVector2Array = Slice.clip_half(quad, origin, normal, side)
			var uv: PackedVector2Array = Slice.texture_uv(cut, art)
			check(cut.size() >= 3 and uv.size() == cut.size(), "Both halves retain their source illustration coordinates")
			for index in range(uv.size()):
				check(Rect2(Vector2.ZERO, Vector2.ONE).grow(0.0001).has_point(uv[index]), "Clipped illustration UVs never sample outside the picture")
				check((art.position + uv[index] * art.size).is_equal_approx(cut[index]), "Clipping does not stretch or mirror the retained picture")
		var initial: Dictionary = Slice.pose(effect, -1.0)
		effect.age = 0.035
		check(Slice.pose(effect, -1.0) == initial, "The actual hit pose is held through the short blade lead-in")
		effect.age = 0.12
		var first: Dictionary = Slice.pose(effect, -1.0)
		var second: Dictionary = Slice.pose(effect, 1.0)
		check(first.offset.distance_to(second.offset) > 8.0 and first.rotation * second.rotation < 0.0,
			"Rupture separates two recognizable pieces with opposing rotation")
		effect.age = 0.50
		var falling: Dictionary = Slice.pose(effect, 1.0)
		check(falling.offset.y > second.offset.y and falling.alpha > 0.0, "Fragments gain downward weight before fading")
		effect.age = 0.80
		check(is_zero_approx(float(Slice.pose(effect, 1.0).alpha)), "Fragments fully fade out without permanent debris")
		effect.age = 0.05
		var ribbon: PackedVector2Array = Slice.blade_ribbon(effect, 6.0, 1.0)
		check(ribbon.size() >= 20 and area(ribbon) > 50.0, "A hit produces a visible tapered blade surface")
		check(ribbon == Slice.blade_ribbon(fixture_with_age(uid, 0.05), 6.0, 1.0),
			"Blade variation is reproducible without consuming gameplay randomness")
		effect.age = 0.20
		check(Slice.blade_ribbon(effect, 6.0, 1.0).is_empty(), "The blade disappears quickly while fragments continue")
		var still: Dictionary = Slice.pose(effect, -1.0, true)
		check(still.offset == Vector2.ZERO and is_zero_approx(still.rotation), "Reduced motion never moves a fragment")


func fixture_with_age(uid: int, age: float) -> Dictionary:
	var effect: Dictionary = fixture(uid)
	effect.age = age
	return effect


func check_compact_seams() -> void:
	for dimensions in [Vector2(112, 60), Vector2(112, 96), Vector2(202, 162)]:
		for scale in [0.8125, 1.0, 1.5]:
			var polygon: PackedVector2Array = Slice.rounded_rect(dimensions, 19.0 / scale)
			for uid in range(1, 5):
				var seam: PackedVector2Array = Slice.seam(dimensions, 19.0 / scale, uid)
				check(seam.size() == 2 and seam[0].distance_to(seam[1]) > 50.0,
					"Compact cards retain one complete cut edge")
				for endpoint in seam:
					var distance: float = INF
					for index in range(polygon.size()):
						distance = minf(distance, endpoint.distance_to(Geometry2D.get_closest_point_to_segment(
							endpoint, polygon[index], polygon[(index + 1) % polygon.size()])))
					check(distance < 0.001, "Bright cut edges end at the actual rounded silhouette, including compact landscape corners")
					check(absf((endpoint - Slice.cut_origin(dimensions)).dot(Slice.normal(uid))) < 0.001,
						"The visible cut edge and clipped illustration share the same plane")


func check_combo_strength() -> void:
	var baseline: Dictionary = fixture()
	var stronger: Dictionary = Slice.create(baseline, 10, Color.CORAL, 6)
	var capped: Dictionary = Slice.create(baseline, 10, Color.CORAL, 100)
	check(float(stronger.strength) > float(baseline.strength) and float(stronger.strength) <= 1.25,
		"A six-word combo modestly strengthens the cut without overwhelming nearby words")
	check(is_equal_approx(float(capped.strength), float(stronger.strength)), "Long combos cannot grow unbounded visual feedback")
	check(is_equal_approx(float(Slice.create(baseline, 999, Color.CORAL, 1).strength), float(baseline.strength)),
		"Visual strength follows actual combo metadata rather than inferring it from awarded points")
	for age in [0.0, 0.12, 0.40, 0.78]:
		baseline.age = age
		stronger.age = age
		check(Slice.pose(baseline, -1.0) == Slice.pose(stronger, -1.0)
			and Slice.pose(baseline, 1.0) == Slice.pose(stronger, 1.0),
			"Combo strength keeps the same captured card geometry, timing and fade")


func begin(view, reduced: bool = false) -> void:
	view.configure(words, reduced, 71)
	view.set_listening(true, true, "Listening.")
	view.set_process(false)
	view._listening_tick_usec = -1


func strike(view) -> void:
	view._listening_tick_usec = -1
	view.receive_transcript(str(view.game.targets[0].word.text))


func check_lifecycle(view) -> void:
	begin(view)
	view.game.advance(1.5)
	view._refresh_targets()
	var before: Dictionary = view._draw_targets[0].duplicate(true)
	var emitted: Array[Dictionary] = []
	view.hit.connect(func(word: Dictionary) -> void: emitted.append(word))
	strike(view)
	var effects: Array = view.slice_snapshot()
	check(view.game.hits == 1 and emitted.size() == 1 and effects.size() == 1,
		"A recognized word awards and emits immediately with one visual effect")
	check(effects[0].center == before.center and effects[0].size == before.size and effects[0].rotation == before.rotation,
		"A cut starts from the actual rendered throw rather than a newly computed position")
	check(str(view._bursts[0].word.image) == str(before.word.image), "The removed target retains its own illustration")
	view.receive_transcript(str(before.word.text))
	check(view.game.hits == 1 and emitted.size() == 1 and view.slice_snapshot().size() == 1,
		"A repeated recognition cannot replay or award a removed target")
	var remaining: float = view.game.remaining
	view._advance_slices(0.20)
	check(view.game.remaining == remaining and view.game.hits == 1 and emitted.size() == 1,
		"The visual timeline cannot advance gameplay, award points or emit another sound")
	check(view.slice_snapshot()[0].first_offset != Vector2.ZERO, "Fragments visibly separate after impact")
	view._advance_slices(1.0)
	check(view.slice_snapshot().is_empty(), "Expired effects release retained target snapshots")
	begin(view)
	view.game.advance(3.0)
	var sentence: PackedStringArray = []
	for target in view.game.targets:
		sentence.append(str(target.word.text))
	view.receive_transcript(" ".join(sentence))
	check(sentence.size() >= 2 and view.slice_snapshot().size() == sentence.size() and view.game.hits == sentence.size(),
		"One recognition can show independent cuts for multiple real targets")
	check(float(view.slice_snapshot().back().strength) > float(view.slice_snapshot().front().strength),
		"Each cut receives its own combo count from the scored hit metadata")
	view.pause()
	check(view.slice_snapshot().is_empty() and view.game.phase == "paused", "Pausing removes cut debris before the microphone gate appears")
	begin(view)
	strike(view)
	view.set_listening(true, false, "Listening paused. Continuing...")
	check(view.slice_snapshot().size() == 1 and view.game.phase == "paused" and view._reconnecting,
		"Normal utterance rollover preserves the just-earned cut while pausing recognition")
	var rollover_remaining: float = view.game.remaining
	view._advance_slices(0.20)
	check(view.slice_snapshot()[0].first_offset != Vector2.ZERO and view.game.remaining == rollover_remaining,
		"An earned slice finishes during rollover without consuming paused round time")
	view.set_listening(true, true, "Listening.")
	check(view.slice_snapshot().size() == 1 and is_equal_approx(float(view.slice_snapshot()[0].age), 0.20),
		"Recognition recovery retains the same cut without restarting the animation")
	view.set_listening(true, false, "Speech network error. Tap Retry.")
	check(view.slice_snapshot().is_empty() and view.game.phase == "paused" and not view._reconnecting,
		"A real speech error clears recent fragments before the retry gate appears")
	begin(view)
	strike(view)
	view.set_listening(false, false, "Microphone permission denied.")
	check(view.slice_snapshot().is_empty(), "Permission failure cannot leave stale cut effects behind")
	begin(view)
	for index in range(10):
		if view.game.targets.is_empty():
			view.game.advance(0.66)
		strike(view)
	check(view.game.hits == 10 and view.slice_snapshot().size() <= 6, "Rapid hits keep every score while bounding live cut geometry")
	check(view.slice_snapshot().back().uid == view._bursts.back().uid, "The concurrency limit preserves the newest feedback")
	view.set_reduced_motion(true)
	check(view.slice_snapshot().is_empty(), "Changing motion preferences removes in-flight fragments immediately")
	begin(view, true)
	strike(view)
	view._advance_slices(0.15)
	var still: Dictionary = view.slice_snapshot()[0]
	check(still.first_offset == Vector2.ZERO and still.second_offset == Vector2.ZERO and still.reduced_motion,
		"Reduced-motion hits retain feedback without moving or rotating pieces")
	view._advance_slices(0.3)
	check(view.slice_snapshot().is_empty(), "Reduced-motion feedback clears promptly")
	begin(view)
	strike(view)
	view.hide()
	check(view.slice_snapshot().is_empty() and view.game.phase == "paused", "Hiding the mode clears slices and preserves the paused round")
	view.show()
	begin(view)
	strike(view)
	view.stop()
	check(view.slice_snapshot().is_empty(), "Leaving the round releases all cut geometry")
	begin(view)
	strike(view)
	view.configure(words)
	check(view.slice_snapshot().is_empty(), "A new round never inherits a previous target's fragments")


func _run() -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	words = catalog.filter(func(word: Dictionary) -> bool: return str(word.id) in ["apple", "cat", "dog", "sun", "horn"])
	check_geometry()
	check_compact_seams()
	check_combo_strength()
	var view = PopView.new()
	root.size = Vector2i(390, 844)
	view.size = Vector2(358, 540)
	root.add_child(view)
	await process_frame
	check_lifecycle(view)
	for dimensions in [Vector2(288, 350), Vector2(812, 180), Vector2(740, 530)]:
		view.size = dimensions
		view._layout()
		check(view._slice_clip.clip_contents and view._slice_clip.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Slice clipping never blocks mouse, touch or keyboard controls")
		# Control derives single-precision offsets from position and size, which
		# can differ by a few hundred-thousandths of a layout unit on assignment.
		check(view._slice_clip.position.distance_to(view._arena.position) < 0.001
			and view._slice_clip.size.distance_to(view._arena.size) < 0.001,
			"All cut geometry shares the actual arena clip at %s: clip=%s arena=%s position_error=%.9f size_error=%.9f" % [
				dimensions, view._slice_clip.get_rect(), view._arena,
				view._slice_clip.position.distance_to(view._arena.position), view._slice_clip.size.distance_to(view._arena.size)])
		check(view._slice_clip.position.y >= view._live_caption.get_rect().end.y,
			"Blade trails and droplets cannot paint over the transcript or HUD at " + str(dimensions))
	view.queue_free()
	await process_frame
	print("Voice Pop slices: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

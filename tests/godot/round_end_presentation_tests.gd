extends SceneTree

const End = preload("res://scripts/round_end_presentation.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var ending := End.new()
	root.add_child(ending)
	var completions: Array[String] = []
	var cues: Array[Dictionary] = []
	ending.completed.connect(func(id: String) -> void: completions.append(id))
	ending.cue_requested.connect(func(id: String, failed: bool) -> void:
		cues.append({"id": id, "failed": failed}))
	check(not ending.begin("", true, false) and not ending.is_active(),
		"An end presentation requires an actual round identity")
	for steady: bool in [false, true]:
		ending.stop()
		ending.size = Vector2(390, 844)
		var id: String = "round-%s" % steady
		check(ending.begin(id, true, steady) and ending.is_active()
			and ending.snapshot().title == "Game over", "A timeout opens a clear end message over the finished board")
		check(not ending.begin(id, true, steady), "Duplicate completion cannot restart the visual or audio")
		var original: Dictionary = ending.snapshot()
		for invalid: float in [0.0, -1.0, INF, NAN]:
			ending.advance(invalid)
		check(ending.snapshot() == original, "Invalid clock updates cannot consume end presentation time")
		ending.advance(0.30)
		check(ending.is_active() and ending._visual.modulate.a > 0.9, "The end message becomes fully readable")
		var elapsed: float = float(ending.snapshot().elapsed)
		ending.set_paused(true)
		ending.advance(20.0)
		check(ending.is_active() and not ending.visible and ending.snapshot().elapsed == elapsed,
			"Hidden pages and menus freeze the effect instead of skipping to settlement")
		ending.set_paused(false)
		for dimensions: Vector2 in [Vector2(320, 220), Vector2(390, 844), Vector2(1366, 768), Vector2(2560, 1440)]:
			ending.size = dimensions
			ending._layout()
			var bounds := Rect2(Vector2.ZERO, dimensions)
			check(bounds.encloses(ending._heading.get_rect()) and bounds.encloses(ending._caption.get_rect()),
				"Both the end heading and next-step caption fit short, phone and large desktop viewports")
			check(ending.snapshot().elapsed == elapsed, "Responsive layout does not reset or accelerate the handoff clock")
			if steady:
				check(ending._visual.scale == Vector2.ONE and ending._rays.rotation == 0.0,
					"Reduced motion retains the same readable time without zooming or rotation")
		ending.advance(End.DURATION - elapsed - 0.01)
		check(ending.is_active() and not completions.has(id), "Settlement remains unavailable before the actual deadline")
		ending.advance(0.02)
		ending.advance(10.0)
		check(not ending.is_active() and not ending.visible and completions.count(id) == 1
			and not ending.begin(id, true, steady), "The end cue hands off once and cannot be replayed by duplicate completion")
	check(cues.size() == 2, "Every distinct ending requests its audio exactly once")
	ending.begin("canceled-round", false, false)
	check(ending.snapshot().title == "Round complete", "Voluntary completion uses a positive, distinct headline")
	ending.stop()
	ending.advance(20.0)
	check(not completions.has("canceled-round") and not ending.is_active(),
		"Leaving the round cancels its pending settlement callback")
	ending.free()
	print("Round end presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

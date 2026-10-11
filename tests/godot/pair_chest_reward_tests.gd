extends SceneTree

const PairReward = preload("res://scripts/pair_chest_reward.gd")
const Data = preload("res://scripts/game_data.gd")
const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]

var checks: int = 0
var failures: int = 0
var cues: Array[String] = []
var reveals: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 640)
	var data := Data.new()
	if not data.load_all():
		check(false, "Pair rewards use the acquired game chest manifests")
		quit(1)
		return
	var view := PairReward.new()
	root.add_child(view)
	view.size = Vector2(960, 640)
	view.set_toast_bounds(Rect2(100, 72, 760, 46))
	view.cue_requested.connect(func(id: String, cue: String) -> void: cues.append(id + ":" + cue))
	view.confetti_requested.connect(func(id: String) -> void: reveals.append(id))
	check(view.configure("round-a", "spring", data.chests, false), "A valid round configures its existing theme chest")
	check(not view.snapshot().active and not view.visible and view.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The empty reward row adds no visible content or input target")
	check(not view.show_pair_result("old-round", true), "A stale pair callback cannot show treasure in the current round")
	check(not view.show_pair_result("round-a", false, false), "The owner can omit routine no-chest messages")
	check(view.show_pair_result("round-a", false), "A requested no-chest result appears")
	check(view.snapshot().message == "No chest this pair" and not view.snapshot().earned and not view.chest.visible,
		"A failed drop is a small text acknowledgement without fake treasure")
	view.advance(PairReward.MISS_SECONDS + 0.01)
	check(not view.snapshot().active and not view.visible and cues.is_empty(), "No-chest feedback quietly clears without sound or paper")
	check(view.show_pair_result("round-a", true), "A committed successful pair starts the chest result")
	view.advance(PairReward.REVEAL_SECONDS - 0.01)
	check(cues.is_empty() and reveals.is_empty(), "Paper and sound wait for the actual reveal beat")
	view.advance(0.02)
	check(cues == ["round-a:reward"] and reveals == ["round-a"] and view.snapshot().performance_active,
		"The reveal emits one round-bound sound and one request for the shared screen overlay")
	check(not view.show_pair_result("round-a", true) and not view.show_pair_result("round-a", false),
		"Duplicate or later pairs cannot restart the earned chest or replace its status")
	var before_pause: float = view.snapshot().elapsed
	view.set_paused(true)
	view.advance(5.0)
	check(view.snapshot().elapsed == before_pause and reveals == ["round-a"],
		"Menu or background pause preserves the current timeline without another reveal")
	view.set_paused(false)
	view.advance(0.1)
	check(view.snapshot().elapsed > before_pause and cues.size() == 1 and reveals.size() == 1,
		"Resume continues without replaying the reward cue or screen overlay request")
	view.advance(1.0)
	check(view.snapshot().performance_active and reveals.size() == 1,
		"The compact chest performance continues independently after its single reveal request")
	view.advance(2.0)
	check(not view.snapshot().performance_active and view.snapshot().active and view.snapshot().earned,
		"The performance ends while its earned chest remains visible")
	check(view.snapshot().message == "Chest ready" and view.snapshot().chest_mode == "closed" and reveals.size() == 1,
		"The compact settled status retains a closed chest without opening or repeated paper")
	check(view.chest.scale == Vector2.ONE and is_zero_approx(view.chest.rotation), "The closed chest settles exactly to its authored dimensions")
	for theme_id: String in THEMES:
		check(view.configure("theme-" + theme_id, theme_id, data.chests, true)
			and view.show_pair_result("theme-" + theme_id, true), "The earned preview supports source chest theme " + theme_id)
		view.advance(0.5)
		check(view.chest.theme_id == theme_id and view.chest.mode == "closed" and view.chest.piece_count() > 0,
			"Theme " + theme_id + " reuses real closed chest artwork")
		check(view.chest.scale == Vector2.ONE and is_zero_approx(view.chest.rotation) and reveals == ["round-a"],
			"Reduced motion preserves a static earned status in " + theme_id)
		view.advance(2.0)
		check(not view.snapshot().performance_active and view.snapshot().earned,
			"Reduced motion completes the same presentation deadline for " + theme_id)
	for area: Rect2 in [Rect2(12, 64, 336, 46), Rect2(12, 40, 780, 46), Rect2(12, 64, 184, 42)]:
		view.set_toast_bounds(area)
		check(area.encloses(view.snapshot().toast_rect), "The status remains inside the host's reserved toolbar row")
		check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view._title.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and view.chest.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"All pair reward visuals leave gameplay input with the live board")
	view.clear()
	view.advance(10.0)
	check(not view.snapshot().active and view.snapshot().round_id.is_empty() and not view.visible,
		"Leaving a round removes every transient and persistent reward visual")
	view.configure("reentrant", "spring", data.chests, false)
	view.cue_requested.connect(func(id: String, _cue: String) -> void:
		if id == "reentrant":
			view.clear())
	view.show_pair_result("reentrant", true)
	view.advance(0.3)
	check(not view.snapshot().active and view.snapshot().round_id.is_empty() and not view.visible
		and reveals.count("reentrant") <= 1,
		"A host navigation during the sound cue cannot revive an obsolete reward")
	await check_turn(view, data)
	view.free()
	print("Pair chest reward: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_turn(view, data) -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(568, 320)]:
		root.size = dimensions
		view.position = Vector2(8, 64)
		view.size = Vector2(dimensions.x - 16, 34)
		view.set_toast_bounds(Rect2(Vector2.ZERO, view.size))
		view.configure("turn-%s" % dimensions, "jungle", data.chests, false)
		view.show_pair_result("turn-%s" % dimensions, true)
		await process_frame
		var before: float = maxf(view.chest.closed_art_rect().size.x, view.chest.closed_art_rect().size.y)
		view.advance(0.28)
		var pose: Dictionary = view.snapshot().motion
		check(view.snapshot().live_turn and float(pose.edge) * float(pose.scale) >= before * 3.0,
			"%s enlarges the actual acquired chest silhouette, rather than only its empty layout box" % dimensions)
		check(view._title.modulate.a < 0.01 and view._surface_layer.modulate.a < 0.01,
			"The enlarged chest takes visual priority over the compact status pill")
		var model = view._models._pool[1]
		var safe := Rect2(Vector2.ZERO, Vector2(dimensions))
		var contained: bool = true
		for age: float in [0.28, 0.55, 0.95, 1.20, 1.45, 1.72]:
			view.advance(age - float(view.snapshot().elapsed))
			pose = view.snapshot().motion
			var bounds: Rect2 = model.closed_bounds()
			var unit: float = float(pose.edge) / maxf(bounds.size.x, bounds.size.y)
			var transform: Transform2D = view.get_global_transform_with_canvas() * Transform2D(
				float(pose.roll), Vector2.ONE * float(pose.scale), 0.0, pose.center)
			for corner in range(8):
				var projected: Vector2 = model._project_point(model._rig.transform * model._closed_box.get_endpoint(corner))
				contained = contained and safe.has_point(transform * ((projected - bounds.get_center()) * unit))
		check(contained and is_equal_approx(float(pose.yaw), TAU),
			"%s keeps the real model inside the viewport throughout a complete closed-chest turn" % dimensions)
		view.set_paused(true)
		var paused: Dictionary = view.snapshot().motion
		view.advance(0.2)
		check(view.snapshot().motion == paused and not view._models._active,
			"Pausing freezes the pose and disables the extra 3D render surface")
		view.set_paused(false)
		view.set_reduced_motion(true)
		check(not view.snapshot().live_turn and not view._models._active
			and view.chest.modulate.a == 1.0 and view.chest.scale == Vector2.ONE,
			"Reduced motion immediately restores the original still chest without a turn or flash")
		view.set_reduced_motion(false)
		view.advance(1.0)
		check(not view._models._active and view.chest.modulate.a == 1.0 and view.chest.scale == Vector2.ONE
			and view._title.modulate.a == 1.0 and view._surface_layer.modulate.a == 1.0,
			"Completion returns to the original chest and status without keeping an animated viewport alive")
	view.clear()
	check(view._models._pool.is_empty() and not view.snapshot().active,
		"Clearing the round releases the reusable turned model")

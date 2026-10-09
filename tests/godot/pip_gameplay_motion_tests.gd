extends SceneTree

const Mascot = preload("res://scripts/duck_mascot.gd")
const LEVELS := [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _same_pose(first: Array, second: Array) -> bool:
	for index in range(6):
		if not first[index].is_equal_approx(second[index]):
			return false
	return true


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(360, 300)
	var duck = Mascot.new()
	root.add_child(duck)
	duck.custom_minimum_size = Vector2(52, 52)
	duck.size = Vector2(52, 52)
	duck.position = Vector2(100, 100)
	_check_motion()
	_check_priority_and_lifecycle(duck)
	_check_extended_reaction(duck)
	if DisplayServer.get_name() != "headless":
		await _check_rendered_faces(duck)
	duck.free()
	print("Pip gameplay motion: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_motion() -> void:
	var neutral: Array[Transform2D] = []
	for index in range(6):
		neutral.append(Transform2D.IDENTITY)
	for correct in [true, false]:
		var name: String = "Happy" if correct else "Sad"
		check(_same_pose(Mascot._gameplay_transforms(correct, 0.0), neutral)
			and _same_pose(Mascot._gameplay_transforms(correct, 1.0), neutral),
			name + " reaction starts and finishes with the original articulated silhouette")
		var still: Array[Transform2D] = Mascot._gameplay_transforms(correct, 0.0, true)
		check(not _same_pose(still, neutral) and _same_pose(still, Mascot._gameplay_transforms(correct, 0.5, true))
			and _same_pose(still, Mascot._gameplay_transforms(correct, 1.0, true)),
			name + " reduced-motion feedback has a distinct, time-independent emotional pose")
		var finite := true
		for frame in range(101):
			for part in Mascot._gameplay_transforms(correct, frame / 100.0):
				finite = finite and part.x.is_finite() and part.y.is_finite() and part.origin.is_finite() and part.determinant() > 0.65
		check(finite, name + " pose keeps all six body parts finite and never collapses a layer")
	var happy: Array[Transform2D] = Mascot._gameplay_transforms(true, 0.31)
	check((happy[0] * Vector2(61, 98)).y < 76 and (happy[4] * Vector2(24, 110)).y < 93
		and (happy[5] * Vector2(99, 111)).y < 95 and happy[2].get_rotation() > 1.3 and happy[3].get_rotation() < -1.3,
		"A successful result visibly lifts the body and both feet while spreading both wings")
	var landing: Array[Transform2D] = Mascot._gameplay_transforms(true, 0.525)
	var encore: Array[Transform2D] = Mascot._gameplay_transforms(true, 0.695)
	check(landing[0].y.length() < 0.89 and (encore[0] * Vector2(61, 98)).y < 85,
		"The first leap lands with squash before a smaller joyful rebound")
	var sad: Array[Transform2D] = Mascot._gameplay_transforms(false, 0.4)
	check((sad[1] * Vector2(61, 72)).y > 82 and sad[1].get_rotation() < -0.16
		and sad[2].get_rotation() < -0.4 and sad[3].get_rotation() > 0.35,
		"A missed result droops the head and both wings instead of reusing a happy bounce")


func _check_priority_and_lifecycle(duck) -> void:
	var rect: Rect2 = duck.get_rect()
	var children: int = duck.get_child_count()
	duck.set_proactive_allowed(true)
	duck.perform_trick("wave")
	duck.set_speaking(true)
	duck.react_gameplay(true)
	check(duck._gameplay_reaction == "happy" and duck.pose == 3 and duck._idle_action.is_empty(),
		"A game result immediately overrides the speaking pose and an existing greeting")
	duck.react("curious")
	duck.set_speaking(false)
	duck.set_speaking(true)
	duck.note_activity()
	check(duck._gameplay_reaction == "happy" and duck.pose == 3 and duck.perform_trick("wave").is_empty(),
		"Hover, speech changes, activity and greeting attempts cannot replace an active result")
	duck._process(0.45)
	duck.react_gameplay(false)
	check(duck._gameplay_reaction == "sad" and duck.pose == 2 and is_equal_approx(duck._gameplay_left, Mascot.GAMEPLAY_SAD_SECONDS),
		"A newer miss replaces an unfinished celebration with one fresh sad response")
	for index in range(30):
		duck.react_gameplay(true)
	check(is_equal_approx(duck._gameplay_left, Mascot.GAMEPLAY_HAPPY_SECONDS),
		"Rapid hits restart one response without building a reaction queue")
	duck._process(1.26)
	check(duck._gameplay_reaction.is_empty() and duck.speaking and duck._idle_action.is_empty(),
		"A completed reaction returns to real pronunciation with no deferred gesture backlog")
	for reason in ["settle", "hide", "pause"]:
		duck.react_gameplay(false)
		match reason:
			"settle": duck.settle()
			"hide": duck.hide()
			"pause": duck.set_idle_paused(true)
		check(duck._gameplay_reaction.is_empty() and is_zero_approx(duck._gameplay_left),
			reason + " cancels the result immediately")
		if reason == "hide":
			duck.react_gameplay(true)
			check(duck._gameplay_reaction.is_empty(), "Hidden Pip ignores late results")
			duck.show()
		elif reason == "pause":
			duck.react_gameplay(true)
			check(duck._gameplay_reaction.is_empty(), "Paused Pip ignores late results")
			duck.set_idle_paused(false)
	duck.set_reduced_motion(true)
	for correct in [true, false]:
		duck.react_gameplay(correct)
		var pose: int = duck.pose
		duck._process(0.75)
		check(duck.pose == pose and not duck._gameplay_reaction.is_empty()
			and duck._gameplay_left > 0.0, "Reduced-motion results remain visible and completely still during their feedback interval")
		duck._process(1.0)
		check(duck._gameplay_reaction.is_empty() and not duck.is_processing(),
			"Static result feedback expires and releases normal mascot interactions")
	duck.react_gameplay(true)
	duck.set_reduced_motion(false)
	check(is_equal_approx(duck._gameplay_left, Mascot.GAMEPLAY_HAPPY_SECONDS), "Changing motion settings preserves the current result deadline")
	check(duck.get_rect() == rect and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation)
		and duck.get_child_count() == children, "Results preserve the input target and create no per-hit nodes")
	duck.settle()


func _check_extended_reaction(duck) -> void:
	duck.react_gameplay(false, 2.4)
	duck._process(1.2)
	check(duck._gameplay_reaction == "sad" and is_equal_approx(duck._gameplay_duration(), 2.4)
		and is_equal_approx(1.0 - duck._gameplay_left / duck._gameplay_duration(), 0.5),
		"A longer loss reaction stays sad and reaches its midpoint after half its requested duration")
	duck._process(1.21)
	check(duck._gameplay_reaction.is_empty(), "An extended reaction finishes at its own deadline")
	duck.react_gameplay(false, 0.1)
	check(is_equal_approx(duck._gameplay_duration(), 0.5), "A short override preserves a visible minimum reaction")
	duck.react_gameplay(false, 10.0)
	check(is_equal_approx(duck._gameplay_duration(), 4.0), "An excessive override cannot hold a reaction indefinitely")
	for correct in [true, false]:
		duck.react_gameplay(correct)
		check(is_equal_approx(duck._gameplay_duration(), Mascot.GAMEPLAY_HAPPY_SECONDS if correct else Mascot.GAMEPLAY_SAD_SECONDS),
			"An ordinary reaction resets an earlier duration override")
	for duration in [-1.0, INF, NAN]:
		duck.react_gameplay(false, duration)
		check(is_equal_approx(duck._gameplay_duration(), Mascot.GAMEPLAY_SAD_SECONDS),
			"An invalid duration retains the standard reaction deadline")
	duck.set_reduced_motion(true)
	duck.react_gameplay(false, 2.4)
	duck._process(1.6)
	check(duck.pose == 2 and duck._gameplay_reaction == "sad" and duck._gameplay_left > 0.0,
		"Reduced motion keeps the static sad expression beyond the ordinary short reaction")
	duck._process(0.81)
	check(duck._gameplay_reaction.is_empty() and not duck.is_processing(),
		"The extended reduced-motion expression expires without leaving a processing loop")
	duck.set_reduced_motion(false)
	duck.settle()


func _capture(viewport: SubViewport, duck) -> Image:
	duck.set_process(false)
	duck.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _check_rendered_faces(duck) -> void:
	var directory := ProjectSettings.globalize_path("res://build/pip-gameplay-motion")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The motion preview directory is available")
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	duck.reparent(viewport)
	duck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in [52, 156]:
		viewport.size = Vector2i(edge + 24, edge + 24)
		duck.size = Vector2(edge, edge)
		duck.position = Vector2(12, 12)
		var cell: int = edge + 24
		var montage := Image.create(cell * 6, cell * LEVELS.size(), false, Image.FORMAT_RGBA8)
		montage.fill(Color("#fff7df"))
		for theme_index in range(LEVELS.size()):
			duck.set_growth_level(LEVELS[theme_index])
			var frames: Array[PackedByteArray] = []
			for column in range(6):
				var correct: bool = column < 3
				var time: float = [0.05, 0.31, 0.695, 0.15, 0.4, 0.7][column]
				duck.react_gameplay(correct)
				duck._gameplay_left = duck._gameplay_duration() * (1.0 - time)
				duck._update_pose()
				var frame: Image = await _capture(viewport, duck)
				frame.convert(Image.FORMAT_RGBA8)
				montage.blend_rect(frame, Rect2i(Vector2i.ZERO, viewport.size), Vector2i(column * cell, theme_index * cell))
				frames.append(frame.get_data())
			check(frames[0] != frames[1] and frames[1] != frames[2] and frames[3] != frames[4] and frames[4] != frames[5],
				"Lv%d" % LEVELS[theme_index] + " renders distinct happy and sad phases at %d pixels" % edge)
		check(montage.save_png(directory + "/reactions-%d.png" % edge) == OK, "Actual %d-pixel gameplay poses are saved for visual review" % edge)
		duck.set_reduced_motion(true)
		duck.react_gameplay(false)
		var before: PackedByteArray = (await _capture(viewport, duck)).get_data()
		duck._process(0.6)
		check((await _capture(viewport, duck)).get_data() == before, "Reduced motion preserves identical rendered pixels at %d pixels" % edge)
		duck.set_reduced_motion(false)
	duck.settle()
	duck.reparent(root)
	viewport.queue_free()

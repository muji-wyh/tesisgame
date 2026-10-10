extends SceneTree

const Celebration = preload("res://scripts/round_celebration.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const Data = preload("res://scripts/game_data.gd")
const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]

var checks: int = 0
var failures: int = 0
var _finished: Array[String] = []
var _opened: Array[String] = []
var _cues: Array[String] = []


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
	var data := Data.new()
	if not data.load_all():
		check(false, "The complete game data and chest manifests load")
		quit(1)
		return
	var view := Celebration.new()
	root.add_child(view)
	view.position = Vector2(24, 24)
	view.size = Vector2(912, 572)
	view.performance_finished.connect(func(id: String) -> void: _finished.append(id))
	view.open_requested.connect(func(id: String) -> void: _opened.append(id))
	view.cue_requested.connect(func(id: String, cue: String) -> void: _cues.append(id + ":" + cue))
	_check_motion(view)
	_check_deadline_and_actions(view, data.chests)
	_check_reward_counts(view, data.chests)
	_check_no_chest(view, data.chests)
	_check_score_summary(view, data.chests)
	_check_lifecycle(view, data.chests)
	_check_theme_updates(view, data.chests)
	_check_reduced_and_stalls(view, data.chests)
	_check_layouts(view, data.chests)
	if DisplayServer.get_name() != "headless":
		await _render_review(view, data.chests)
	view.stop()
	view.free()
	print("Round celebration: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _begin(view, manifest: Dictionary, id: String, reduced: bool = false, automatic: bool = false, count: int = 1, theme_id: String = "spring") -> void:
	view.show()
	view.begin(id, theme_id, manifest, count, reduced, automatic)
	view.set_process(false)


func _step(view, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.00001:
		var delta: float = minf(0.05, remaining)
		view.advance(delta)
		remaining -= delta


func _same_pose(first: Array, last: Array) -> bool:
	for index in range(first.size()):
		if not first[index].is_equal_approx(last[index]):
			return false
	return true


func _part_anchor(parts: Array[Transform2D], index: int) -> Vector2:
	return parts[index] * Mascot.GAMEPLAY_PIVOTS[index]


func _check_motion(view) -> void:
	var ordinary: Array[Transform2D] = Mascot._gameplay_transforms(true, 0.5)
	var still: Array[Transform2D] = Mascot._celebration_transforms(0.0, true)
	check(_same_pose(still, Mascot._celebration_transforms(0.5, true))
		and _same_pose(still, Mascot._celebration_transforms(1.0, true)),
		"Reduced motion presents one time-independent proud pose")
	check(not _same_pose(Mascot._celebration_transforms(0.3), Mascot._gameplay_transforms(true, 0.3)),
		"The complete-round performance is distinct from a slowed ordinary correct answer")
	var finite: bool = true
	for frame in range(181):
		for part: Transform2D in Mascot._celebration_transforms(float(frame) / 180.0):
			finite = finite and part.x.is_finite() and part.y.is_finite() and part.origin.is_finite() and part.determinant() > 0.85
	check(finite, "All six authored body parts remain finite and intact through the choreography")
	var crouch: Array[Transform2D] = Mascot._celebration_transforms(0.18 / 3.0)
	check(_part_anchor(crouch, 4).is_equal_approx(Vector2(40, 103))
		and _part_anchor(crouch, 5).is_equal_approx(Vector2(80, 103))
		and _part_anchor(crouch, 0).y > 102 and crouch[0].get_scale().y < 0.95,
		"Preparation compresses the body over two planted feet before push-off")
	var push_off: Array[Transform2D] = Mascot._celebration_transforms(0.25 / 3.0)
	check(_part_anchor(push_off, 0).y < 98 and is_equal_approx(_part_anchor(push_off, 4).y, 103)
		and is_equal_approx(_part_anchor(push_off, 5).y, 103),
		"The 0.25-second cue meets an upward push from the floor")
	var leap: Array[Transform2D] = Mascot._celebration_transforms(0.52 / 3.0)
	check((leap[0] * Vector2(61, 98)).y < 77 and (leap[4] * Vector2(40, 103)).y < 83,
		"The leap peaks at 0.52 seconds between push-off and landing")
	var touchdown: Array[Transform2D] = Mascot._celebration_transforms(0.82 / 3.0)
	var landing: Array[Transform2D] = Mascot._celebration_transforms(0.9 / 3.0)
	var recovery: Array[Transform2D] = Mascot._celebration_transforms(0.99 / 3.0)
	check(is_equal_approx(_part_anchor(touchdown, 4).y, 103)
		and is_equal_approx(_part_anchor(touchdown, 5).y, 103)
		and _part_anchor(touchdown, 0).y < 98 and _part_anchor(touchdown, 1).y < 72,
		"Feet touch down while the body and head are still descending")
	check(_part_anchor(landing, 0).y > 101 and _part_anchor(landing, 1).y > 76
		and landing[0].get_scale().y < 0.95 and recovery[0].get_scale().is_equal_approx(Vector2.ONE)
		and _part_anchor(recovery, 0).y < _part_anchor(landing, 0).y
		and _part_anchor(recovery, 1).y < _part_anchor(landing, 1).y,
		"The 0.9-second impact compresses before the body and head recover")
	var left_step: Array[Transform2D] = Mascot._celebration_transforms(1.15 / 3.0)
	var right_step: Array[Transform2D] = Mascot._celebration_transforms(1.5 / 3.0)
	check(is_equal_approx(_part_anchor(left_step, 4).y, 103) and _part_anchor(left_step, 5).y < 100
		and _part_anchor(right_step, 4).y < 100 and is_equal_approx(_part_anchor(right_step, 5).y, 103)
		and _part_anchor(left_step, 0).x < 61 and _part_anchor(right_step, 0).x > 61,
		"Two alternating steps shift weight onto the planted foot before 1.65 seconds")
	var presentation: Array[Transform2D] = Mascot._celebration_transforms(1.8 / 3.0)
	check(is_equal_approx(_part_anchor(presentation, 4).y, 103)
		and is_equal_approx(_part_anchor(presentation, 5).y, 103)
		and _part_anchor(presentation, 0).y > 96 and rad_to_deg(presentation[3].get_rotation()) < -75,
		"The 1.8-second reward reveal meets a grounded presenting gesture, not a late leap")
	check(_same_pose(Mascot._celebration_transforms(2.4 / 3.0), Mascot._celebration_transforms(1.0)),
		"The presenting gesture settles by 2.4 seconds and holds through the invitation")
	var faces: Array[String] = []
	for seconds: float in [0.18, 0.52, 0.9, 1.3, 1.5, 1.8, 2.4]:
		view.pip.set_celebration_progress(seconds / 3.0)
		faces.append(view.pip.expression_name())
	check(faces == ["surprised", "delighted", "delighted", "wink", "delighted", "proud", "proud"],
		"Expressions follow preparation, leap and steps, reward presentation, then pride")
	view.pip.set_celebration_progress(0.4)
	view.pip._process(10.0)
	view.pip.react_gameplay(false)
	check(is_equal_approx(view.pip._celebration_progress, 0.4) and not view.pip.is_processing()
		and view.pip._gameplay_reaction.is_empty(), "Only the owner's clock advances a finale")
	view.pip.settle()
	check(view.pip._celebration_progress < 0.0 and _same_pose(ordinary, Mascot._gameplay_transforms(true, 0.5)),
		"Settling clears the finale and preserves ordinary answer choreography")


func _check_deadline_and_actions(view, manifest: Dictionary) -> void:
	_begin(view, manifest, "manual")
	view.set_narration_playing(true)
	check(view.is_active() and not view.is_ready() and view.controls().is_empty()
		and not view.action_button.visible and view.chest.mode == "closed",
		"A new finale hides actions and keeps its preview closed")
	view.action_button.pressed.emit()
	_step(view, 0.3)
	var before: Dictionary = view.snapshot()
	view.begin("manual", "winter", manifest, 3, true, true)
	check(view.snapshot() == before, "A duplicate round notification does not restart or restyle the active performance")
	_step(view, 2.69)
	check(not view.is_ready() and _finished.is_empty() and _opened.is_empty(),
		"Early actions and the instant before three seconds cannot bypass the finale")
	_step(view, 0.03)
	check(not view.is_ready() and _finished.is_empty(), "Long final pronunciation still owns its completion gate")
	check(_cues == ["manual:step", "manual:step-detail", "manual:reward"],
		"The owner's clock emits each synchronized sound once")
	view.set_narration_playing(false)
	check(view.is_ready() and view.controls() == [view.action_button] and view.default_focus() == view.action_button
		and _finished == ["manual"], "Finishing both gates exposes one focused invitation")
	_step(view, 10.0)
	check(_opened.is_empty(), "A ready manual invitation never opens itself")
	view.action_button.pressed.emit()
	view.action_button.pressed.emit()
	check(_opened == ["manual"] and view.controls().is_empty(), "The explicit invitation can be accepted only once")
	check(view.chest.mode == "closed" and not view.chest.opening_committed()
		and not view.chest.hold_effect_snapshot().surprise.active,
		"Celebration and acceptance never open the preview or manufacture a gift")
	view.stop()


func _check_reward_counts(view, manifest: Dictionary) -> void:
	for count: int in [1, 2, 3, 4, 12]:
		var identity: String = "reward-count-%d" % count
		_begin(view, manifest, identity, false, true, count)
		var caption: String = "You earned a treasure chest!" if count == 1 else "You earned %d treasure chests!" % count
		var badge: String = "" if count == 1 else "x%d" % count
		check(view.snapshot().chest_count == count and view._caption.text == caption and view._count.text == badge,
			"The shared performance preserves all %d earned chests in its snapshot, caption, and badge" % count)
		_step(view, 3.01)
		check(view.is_ready() and _finished.back() == identity and view.snapshot().chest_count == count
			and view._caption.text == caption and view._count.text == badge and not view.action_button.visible,
			"Automatic completion retains the exact %d-chest reward without an extra action" % count)
		view.stop()


func _check_score_summary(view, manifest: Dictionary) -> void:
	view.show()
	view.begin("scored", "spring", manifest, 4, false, true, 27)
	view.set_process(false)
	var summary: Dictionary = view.snapshot()
	check(summary.title == "Round results" and summary.caption == "Score: 27 · Chests: 4" and summary.score == 27
		and is_zero_approx(summary.elapsed) and is_equal_approx(view._heading.modulate.a, 1.0)
		and is_equal_approx(view._caption.modulate.a, 1.0),
		"A scored result shows its title and exact totals from the first animation frame")
	var finished_before: int = _finished.size()
	view.set_narration_playing(true)
	_step(view, 3.01)
	check(not view.is_ready() and _finished.size() == finished_before and view.controls().is_empty(),
		"Immediate result copy does not bypass the performance or narration gates")
	view.set_narration_playing(false)
	check(view.is_ready() and _finished.size() == finished_before + 1 and _finished.back() == "scored"
		and view.snapshot().caption == summary.caption and not view.action_button.visible,
		"A scored automatic finale completes once while preserving its result summary")
	_begin(view, manifest, "after-scored")
	check(view.snapshot().score == -1 and view.snapshot().title == "You did it!"
		and view.snapshot().caption == "You earned a treasure chest!"
		and is_zero_approx(view._heading.modulate.a) and is_zero_approx(view._caption.modulate.a),
		"The next ordinary celebration restores its default copy and reveal timing")
	view.stop()


func _check_no_chest(view, manifest: Dictionary) -> void:
	var opened_before: int = _opened.size()
	var finished_before: int = _finished.size()
	_begin(view, manifest, "no-chest", false, false, 0)
	view.set_narration_playing(true)
	var initial: Dictionary = view.snapshot()
	check(initial.chest_count == 0 and not initial.chest_visible and not view._glow.visible
		and initial.title == "You did it!" and initial.caption == "Every word matched!"
		and view._count.text.is_empty() and view.action_button.text == "Play again",
		"A completed round without a chest celebrates learning without inventing a treasure")
	check(is_equal_approx(view.pip.get_rect().get_center().x, view.size.x * 0.5),
		"Pip is centered when no chest accompanies the celebration")
	view.action_button.pressed.emit()
	_step(view, 3.01)
	check(not view.is_ready() and _opened.size() == opened_before and _finished.size() == finished_before
		and view.snapshot().cue_log == ["step", "step-detail"],
		"No-chest completion still waits for narration and omits the treasure reveal sound")
	view.set_narration_playing(false)
	check(view.is_ready() and view.controls() == [view.action_button] and view.action_button.visible
		and _finished.size() == finished_before + 1,
		"A play-again action appears after the same three-second and narration gates")
	view.action_button.pressed.emit()
	view.action_button.pressed.emit()
	check(_opened.size() == opened_before + 1 and _opened.back() == "no-chest" and view.controls().is_empty(),
		"The host receives one round-bound play-again request, even after repeated clicks")
	view.retry_open("old-round")
	check(view.controls().is_empty(), "A stale retry cannot re-enable a different round's action")
	var completed: Dictionary = view.snapshot()
	view.retry_open("no-chest")
	check(view.controls() == [view.action_button] and not view.action_button.disabled
		and view.snapshot().elapsed == completed.elapsed and view.snapshot().cue_log == completed.cue_log
		and _finished.size() == finished_before + 1,
		"A rejected replay can be retried without repeating the completed performance")
	view.action_button.pressed.emit()
	view.action_button.pressed.emit()
	check(_opened.size() == opened_before + 2 and view.controls().is_empty(),
		"A retried replay remains protected against duplicate clicks")
	_begin(view, manifest, "no-chest-reduced", true, false, 0)
	_step(view, 3.01)
	check(view.is_ready() and not view.snapshot().chest_visible and not view._glow.visible,
		"Reduced motion preserves zero-chest ownership and the completion action")
	_begin(view, manifest, "after-no-chest")
	check(view.chest.visible and view._glow.visible and view.action_button.text == "Open chest"
		and view.snapshot().caption == "You earned a treasure chest!",
		"A later earned chest restores its authored preview, glow, and invitation")
	view.stop()


func _check_lifecycle(view, manifest: Dictionary) -> void:
	_begin(view, manifest, "interrupted")
	_step(view, 1.0)
	view.pause()
	var paused_time: float = view.snapshot().elapsed
	_step(view, 8.0)
	check(view.snapshot().paused and is_equal_approx(view.snapshot().elapsed, paused_time),
		"Paused performance cannot finish offscreen")
	view.resume()
	view.set_process(false)
	check(is_zero_approx(view.snapshot().elapsed) and not view.snapshot().paused,
		"Returning to an unfinished performance restarts one complete sequence")
	_step(view, 0.2)
	view.resume()
	check(is_equal_approx(view.snapshot().elapsed, 0.2), "Repeated active resume calls do not restart the clock")
	view.hide()
	check(view.snapshot().paused and not view.is_processing(), "Hiding automatically suspends the performance")
	view.show()
	view.resume()
	view.set_process(false)
	_step(view, 3.01)
	var ready: Dictionary = view.snapshot()
	view.pause()
	view.resume()
	check(view.is_ready() and view.snapshot().elapsed == ready.elapsed
		and view.snapshot().cue_log == ready.cue_log, "A ready invitation survives overlays without replaying sounds or motion")
	view.stop()
	view.advance(10.0)
	view.action_button.pressed.emit()
	check(not view.is_active() and view.current_round_id().is_empty() and view.controls().is_empty(),
		"Stopping clears the session and rejects late callbacks")
	_begin(view, manifest, "replace-old")
	_step(view, 1.0)
	_begin(view, manifest, "replace-new")
	check(view.current_round_id() == "replace-new" and is_zero_approx(view.snapshot().elapsed)
		and view.snapshot().cue_log.is_empty(), "A new round replaces every old timing and cue record")
	view.stop()


func _check_reduced_and_stalls(view, manifest: Dictionary) -> void:
	_begin(view, manifest, "reduced", true)
	var first_face: String = view.pip.expression_name()
	var first_scale: Vector2 = view.chest.scale
	_step(view, 1.5)
	check(view.pip.expression_name() == first_face and view.chest.scale == first_scale and not view.is_ready(),
		"Reduced motion is visually still without skipping the deadline")
	view.set_reduced_motion(false)
	check(is_equal_approx(view.snapshot().elapsed, 1.5), "Changing motion preferences preserves the completion clock")
	view.set_reduced_motion(true)
	_step(view, 1.51)
	check(view.is_ready() and not view.is_processing() and is_zero_approx(view._glow.modulate.a),
		"Reduced motion reaches the same deadline with no halo or idle processing")
	_begin(view, manifest, "stall")
	var prior_cues: int = _cues.size()
	view.advance(2.7)
	check(_cues.size() == prior_cues and view.snapshot().cue_log.is_empty() and not view.is_ready(),
		"A stalled frame consumes missed sound beats without a catch-up burst")
	view.advance(0.31)
	check(view.is_ready() and _cues.size() == prior_cues, "After a stall the final deadline still resolves once")
	var prior_finished: int = _finished.size()
	_begin(view, manifest, "automatic", false, true, 3)
	_step(view, 3.01)
	check(view.is_ready() and _finished.size() == prior_finished + 1 and _finished.back() == "automatic"
		and not view.action_button.visible and view.controls().is_empty(),
		"Automatic completion signals its host without inserting another chest action")
	view.stop()


func _check_theme_updates(view, manifest: Dictionary) -> void:
	_begin(view, manifest, "changing-world")
	view.set_narration_playing(true)
	_step(view, 0.4)
	var pending: Dictionary = view.snapshot()
	view.apply_theme("space", manifest)
	check(view.pip.theme_id == "space" and view.chest.theme_id == "space"
		and view.snapshot().elapsed == pending.elapsed and view.snapshot().cue_log == pending.cue_log
		and view.snapshot().narration_playing and not view.is_ready(),
		"Changing a world updates both authored artworks without changing a pending gate or replaying cues")
	view.set_narration_playing(false)
	_step(view, 2.61)
	var ready: Dictionary = view.snapshot()
	var finished_count: int = _finished.size()
	view.apply_theme("ocean", manifest)
	check(view.pip.theme_id == "ocean" and view.chest.theme_id == "ocean"
		and view.is_ready() and view.snapshot().elapsed == ready.elapsed
		and view.snapshot().cue_log == ready.cue_log and _finished.size() == finished_count,
		"A ready invitation adopts the chosen world without another performance or completion")
	view.stop()


func _check_layouts(view, manifest: Dictionary) -> void:
	for dimensions: Vector2 in [Vector2(912, 572), Vector2(358, 640), Vector2(780, 220), Vector2(300, 200)]:
		view.size = dimensions
		_begin(view, manifest, "layout-%s" % str(dimensions), true)
		_step(view, 3.01)
		var frame := Rect2(Vector2.ZERO, dimensions)
		check(frame.encloses(view.pip.get_rect()) and frame.encloses(view.action_button.get_rect())
			and frame.encloses(view._heading.get_rect()) and frame.encloses(view._caption.get_rect()),
			"Pip, copy and the complete touch action fit " + str(dimensions))
		check(view.action_button.size.y >= 44.0 and not view.pip.get_rect().intersects(view.action_button.get_rect()),
			"Compact layouts preserve the touch target and separate it from the performance")
		view.stop()
	view.size = Vector2(912, 572)


func _capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK, "Rendered review saved: " + path.get_file())


func _render_review(view, manifest: Dictionary) -> void:
	var output: String = ProjectSettings.globalize_path("res://build/round-celebration")
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "The rendered review directory is available")
	RenderingServer.set_default_clear_color(Color("#fbf8f0"))
	for theme_id: String in THEMES:
		root.size = Vector2i(960, 620)
		view.position = Vector2(24, 24)
		view.size = Vector2(912, 572)
		_begin(view, manifest, "render-" + theme_id, false, false, 1, theme_id)
		_step(view, 0.52)
		await _capture(output + "/" + theme_id + "-leap.png")
		_step(view, 2.49)
		await _capture(output + "/" + theme_id + "-ready.png")
		view.stop()
	for dimensions: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		view.position = Vector2(16, 50)
		view.size = Vector2(dimensions) - Vector2(32, 74)
		_begin(view, manifest, "render-" + str(dimensions), false)
		_step(view, 3.01)
		await _capture(output + "/" + str(dimensions.x) + "x" + str(dimensions.y) + ".png")
		view.stop()

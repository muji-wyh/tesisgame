extends SceneTree

const Celebration = preload("res://scripts/round_celebration.gd")
const Settlement = preload("res://scripts/round_settlement.gd")
const SettlementDialog = preload("res://scripts/settlement_dialog.gd")
const CoinBreakdown = preload("res://scripts/chest_coin_breakdown.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const Data = preload("res://scripts/game_data.gd")
const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]

var checks: int = 0
var failures: int = 0
var _finished: Array[String] = []
var _opened: Array[String] = []
var _cues: Array[String] = []
var _reveals: Array[String] = []
var _home_requests: int = 0


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
	view.confetti_requested.connect(func(id: String) -> void: _reveals.append(id))
	view.home_requested.connect(func() -> void: _home_requests += 1)
	_check_motion(view)
	_check_deadline_and_actions(view, data.chests)
	_check_exit_during_performance(view, data.chests)
	await _check_early_replay_pointer(view, data.chests)
	_check_reward_counts(view, data.chests)
	_check_staged_arrival(view, data.chests)
	_check_confetti(view, data.chests)
	_check_no_chest(view, data.chests)
	_check_score_summary(view, data.chests)
	_check_lifecycle(view, data.chests)
	_check_theme_updates(view, data.chests)
	_check_reduced_and_stalls(view, data.chests)
	_check_layouts(view, data.chests)
	await _check_chest_reward_layout(view, data.chests)
	if DisplayServer.get_name() != "headless":
		await _render_review(view, data.chests)
		view.hide()
		await _render_chest_reward_review(data.chests)
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
	check(view.is_active() and not view.is_ready() and view.controls() == [view.home_button]
		and not view.action_button.visible and view.chest.mode == "closed",
		"A new finale keeps Home available while its preview and replay stay gated")
	view.action_button.pressed.emit()
	_step(view, 0.3)
	var before: Dictionary = view.snapshot()
	view.begin("manual", "winter", manifest, 3, true, true)
	check(view.snapshot() == before, "A duplicate round notification does not restart or restyle the active performance")
	_step(view, 2.69)
	check(not view.is_ready() and _finished.is_empty() and _opened.is_empty(),
		"Early actions and the instant before three seconds cannot bypass the finale")
	_step(view, 0.03)
	check(not view.is_ready() and _finished.is_empty() and is_zero_approx(view._caption.modulate.a),
		"Long final pronunciation still owns its completion gate and withholds the opening instruction")
	check(_cues == ["manual:step", "manual:step-detail", "manual:reward"],
		"The owner's clock emits each synchronized sound once")
	view.set_narration_playing(false)
	check(view.is_ready() and not view.action_button.visible and view.action_button.disabled
		and not view.controls().has(view.action_button) and _finished == ["manual"],
		"Finishing both gates signals the host without an earned-chest action")
	_step(view, 10.0)
	check(_opened.is_empty(), "Presentation readiness never opens or awards a chest by itself")
	view.action_button.pressed.emit()
	view.action_button.pressed.emit()
	check(_opened.is_empty() and not view.controls().has(view.action_button),
		"Stale hidden action callbacks cannot insert an earned-chest invitation")
	check(view.chest.mode == "closed" and not view.chest.opening_committed()
		and not view.chest.hold_effect_snapshot().opened_effect.active,
		"The celebration preview stays closed without triggering opening effects")
	view.stop()


func _check_exit_during_performance(view, manifest: Dictionary) -> void:
	_begin(view, manifest, "early-home")
	_step(view, 0.7)
	var requests_before: int = _home_requests
	check(view.home_button.is_visible_in_tree() and not view.home_button.disabled
		and view.controls() == [view.home_button] and view.default_focus() == null,
		"Home stays reachable during the performance without turning held Accept into an exit")
	view.home_button.pressed.emit()
	check(_home_requests == requests_before + 1, "Home can request exit before the chest arrives")
	view.pause()
	view.home_button.pressed.emit()
	view.stop()
	view.home_button.pressed.emit()
	check(_home_requests == requests_before + 1, "Paused and stopped presentations reject stale Home callbacks")


func _check_early_replay_pointer(view, manifest: Dictionary) -> void:
	var replays: Array[String] = []
	var handoffs: Array[String] = []
	# Model the host's real ownership change: either accepted action removes
	# the celebration and its button immediately, so a lost release is visible.
	var replay_owner := func(id: String) -> void:
		replays.append(id)
		view.stop()
	var handoff_owner := func(id: String) -> void:
		handoffs.append(id)
		view.stop()
	view.replay_requested.connect(replay_owner)
	view.performance_finished.connect(handoff_owner)
	for cancelled: bool in [false, true]:
		var id: String = "early-pointer-cancel" if cancelled else "early-pointer-replay"
		view.show()
		view.begin(id, "spring", manifest, 1, false, false, -1, 0, false, "", true)
		view.set_process(false)
		_step(view, Celebration.DURATION - 0.05)
		var replay_center: Vector2 = view.replay_button.get_global_rect().get_center()
		var finished_before: int = _finished.size()
		var replays_before: int = replays.size()
		await _pointer_button(replay_center, true)
		check(view.replay_button.is_pressed(), "A real pointer-down captures the early replay button before the deadline")
		_step(view, 0.2)
		check(view.is_active() and not view.is_ready() and is_equal_approx(view.snapshot().elapsed, Celebration.DURATION)
			and view.replay_button.is_visible_in_tree() and not view.replay_button.disabled
			and view.controls().has(view.replay_button) and _finished.size() == finished_before and handoffs.is_empty(),
			"Crossing the finale deadline preserves the pressed replay target until its pointer gesture resolves")
		await _pointer_button(replay_center, false, cancelled)
		if cancelled:
			check(not view.replay_button.is_pressed() and replays.size() == replays_before,
				"A cancelled pointer release clears the pressed state without requesting replay")
			_step(view, 0.01)
			check(not view.is_active() and handoffs == [id] and _finished.size() == finished_before + 1
				and _finished.back() == id and replays.size() == replays_before,
				"A cancelled replay gesture allows the completed finale to hand off exactly once")
		else:
			check(replays == [id] and not view.is_active() and _finished.size() == finished_before and handoffs.is_empty(),
				"A valid release after the deadline requests replay once instead of disappearing during handoff")
			await _pointer_button(replay_center, false)
			_step(view, 1.0)
			check(replays == [id] and handoffs.is_empty() and _finished.size() == finished_before,
				"A duplicate release and the retired clock cannot replay or hand off the abandoned celebration")
	view.replay_requested.disconnect(replay_owner)
	view.performance_finished.disconnect(handoff_owner)
	view.stop()


func _pointer_button(point: Vector2, pressed: bool, cancelled: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.canceled = cancelled
	root.push_input(event, true)
	await process_frame


func _check_reward_counts(view, manifest: Dictionary) -> void:
	for count: int in [1, 2, 3, 4, 12]:
		var identity: String = "reward-count-%d" % count
		_begin(view, manifest, identity, false, true, count)
		var title: String = "You earned a chest!" if count == 1 else "You earned %d chests!" % count
		var badge: String = "" if count == 1 else "x%d" % count
		check(view.snapshot().chest_count == count and view._count.text == badge and is_zero_approx(view._caption.modulate.a),
			"The shared performance preserves all %d earned chests while withholding the opening prompt" % count)
		_step(view, 3.01)
		check(view.is_ready() and _finished.back() == identity and view.snapshot().chest_count == count
			and view._heading.text == title and view._caption.text == "Hold the chest to open" and view._count.text == badge and not view.action_button.visible,
			"Automatic completion retains the exact %d-chest reward without an extra action" % count)
		view.stop()


func _check_staged_arrival(view, manifest: Dictionary) -> void:
	for dimensions: Vector2 in [Vector2(456, 436), Vector2(334, 436), Vector2(788, 196)]:
		view.size = dimensions
		_begin(view, manifest, "stages-" + str(dimensions))
		_step(view, 0.52)
		check(is_equal_approx(view.pip.get_rect().get_center().x, dimensions.x * 0.5)
			and is_zero_approx(view.chest.modulate.a) and is_zero_approx(view._caption.modulate.a),
			"Pip owns the center during the celebration, before chest or invitation: " + str(dimensions))
		_step(view, 1.08)
		check(view.snapshot().stage == "move_aside" and view.pip.position.x > view._pip_rect.position.x
			and view.pip.position.x < view._pip_center_rect.position.x and is_zero_approx(view.chest.modulate.a),
			"Pip moves aside before any chest is visible")
		_step(view, 0.19)
		check(view.pip.position.is_equal_approx(view._pip_rect.position) and is_zero_approx(view.chest.modulate.a),
			"Pip reaches its final side position before the chest enters")
		_step(view, 0.20)
		check(view.snapshot().stage == "chest_arrival" and view.chest.modulate.a > 0.99
			and view.chest.position.y < view._chest_rect.position.y and view.chest.scale == Vector2.ONE
			and is_zero_approx(view._caption.modulate.a),
			"The intact chest descends into place without scaling or an early opening prompt")
		_step(view, 0.46)
		check(view.chest.position.is_equal_approx(view._chest_rect.position)
			and view._heading.text == "You earned a chest!" and is_zero_approx(view._caption.modulate.a),
			"The chest settles before its earned message and opening invitation")
		_step(view, 0.30)
		check(is_equal_approx(view._caption.modulate.a, 1.0) and view._caption.text == "Hold the chest to open"
			and not view.is_ready() and view.controls() == [view.home_button],
			"The invitation is legible before the existing handoff deadline")
		var elapsed: float = view.snapshot().elapsed
		view.size = dimensions + Vector2(20, 20)
		check(view.snapshot().elapsed == elapsed and view.pip.position.is_equal_approx(view._pip_rect.position)
			and view.chest.position.is_equal_approx(view._chest_rect.position),
			"Resizing preserves the timeline and recomputes both settled subjects")
		view.stop()
	view.size = Vector2(912, 572)
	_begin(view, manifest, "stages-reduced", true)
	var resting_pip: Vector2 = view.pip.position
	var resting_chest: Vector2 = view.chest.position
	_step(view, 1.79)
	check(view.pip.position == resting_pip and view.chest.position == resting_chest and is_zero_approx(view.chest.modulate.a),
		"Reduced motion preserves the order with still artwork")
	_step(view, 1.22)
	check(view.pip.position == resting_pip and view.chest.position == resting_chest and view.is_ready()
		and view.chest.modulate.a == 1.0 and view._caption.modulate.a == 1.0,
		"Reduced motion reveals the same reward and invitation without spatial animation")
	view.stop()


func _check_score_summary(view, manifest: Dictionary) -> void:
	view.show()
	view.begin("scored", "spring", manifest, 4, false, true, 27)
	view.set_process(false)
	var summary: Dictionary = view.snapshot()
	check(summary.title == "Round complete" and summary.summary == "Score: 27 · Chests: 4" and summary.score == 27
		and is_zero_approx(summary.elapsed) and view._summary.visible and is_zero_approx(view._caption.modulate.a),
		"A scored result keeps its exact totals visible while the reward invitation waits")
	var finished_before: int = _finished.size()
	view.set_narration_playing(true)
	_step(view, 3.01)
	check(not view.is_ready() and _finished.size() == finished_before and view.controls() == [view.home_button],
		"Immediate result copy does not bypass the performance or narration gates")
	view.set_narration_playing(false)
	check(view.is_ready() and _finished.size() == finished_before + 1 and _finished.back() == "scored"
		and view.snapshot().caption == summary.caption and not view.action_button.visible,
		"A scored automatic finale completes once while preserving its result summary")
	_begin(view, manifest, "after-scored")
	check(view.snapshot().score == -1 and view.snapshot().title == "You did it!"
		and view.snapshot().caption == "Hold the chest to open" and not view._summary.visible
		and is_zero_approx(view._heading.modulate.a) and is_zero_approx(view._caption.modulate.a),
		"The next ordinary celebration restores its default copy and reveal timing")
	view.stop()


func _check_confetti(view, manifest: Dictionary) -> void:
	_begin(view, manifest, "paper")
	_step(view, 1.79)
	check(not _reveals.has("paper"), "The screen-overlay request waits for the chest reveal")
	_step(view, 0.02)
	check(_reveals.count("paper") == 1 and view.snapshot().reward_revealed,
		"The earned chest publishes exactly one round-bound screen-overlay request")
	view.set_reduced_motion(true)
	view.set_reduced_motion(false)
	check(_reveals.count("paper") == 1, "Changing motion preferences does not replay the already published reveal")
	view.pause()
	view.resume()
	view.set_process(false)
	_step(view, 1.81)
	check(_reveals.count("paper") == 1, "Restarting an interrupted performance cannot request another burst for the same chest")
	_step(view, 1.2)
	check(view.is_ready() and _reveals.count("paper") == 1,
		"The invitation gate completes independently of the shared paper tail")
	view.stop()
	check(not view.snapshot().reward_revealed, "Stopping clears the local reveal identity")


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
		and view.snapshot().cue_log == ["step", "step-detail"] and not _reveals.has("no-chest"),
		"No-chest completion still waits for narration and omits the treasure reveal sound")
	view.set_narration_playing(false)
	check(view.is_ready() and view.controls() == [view.home_button, view.action_button] and view.action_button.visible
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
	check(view.controls() == [view.home_button, view.action_button] and not view.action_button.disabled
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
	check(view.chest.visible and view._glow.visible and view.action_button.text == "Play again"
		and not view.action_button.visible and view.action_button.disabled
		and view.snapshot().caption == "Hold the chest to open",
		"A later earned chest restores its authored preview without an Open chest action")
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
	check(not _reveals.has("reduced"), "Reduced motion never requests a moving paper overlay")
	_begin(view, manifest, "stall")
	var prior_cues: int = _cues.size()
	view.advance(2.7)
	check(_cues.size() == prior_cues and view.snapshot().cue_log.is_empty() and not view.is_ready(),
		"A stalled frame consumes missed sound beats without a catch-up burst")
	check(_reveals.count("stall") == 1, "A stalled frame still publishes the earned visual reveal exactly once")
	view.advance(0.31)
	check(view.is_ready() and _cues.size() == prior_cues, "After a stall the final deadline still resolves once")
	var prior_finished: int = _finished.size()
	_begin(view, manifest, "automatic", false, true, 3)
	_step(view, 3.01)
	check(view.is_ready() and _finished.size() == prior_finished + 1 and _finished.back() == "automatic"
		and not view.action_button.visible and view.controls() == [view.home_button],
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
		check(frame.encloses(view.pip.get_rect()) and frame.encloses(view.chest.get_rect())
			and frame.encloses(view._heading.get_rect()) and frame.encloses(view._caption.get_rect()),
			"The Pip/chest composition and complete copy fit " + str(dimensions))
		check(not view.action_button.visible and view.action_button.disabled,
			"Earned-chest layouts never expose an extra action at " + str(dimensions))
		view.stop()
		_begin(view, manifest, "no-chest-layout-%s" % str(dimensions), true, false, 0)
		_step(view, 3.01)
		check(frame.encloses(view.action_button.get_rect()) and view.action_button.size.y >= 44.0
			and not view.pip.get_rect().intersects(view.action_button.get_rect()),
			"Zero-chest layouts retain an unobstructed replay touch target at " + str(dimensions))
		view.stop()
	view.size = Vector2(912, 572)


func _capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK, "Rendered review saved: " + path.get_file())


func _check_chest_reward_layout(view, manifest: Dictionary) -> void:
	var quote := {"policy": CoinBreakdown.Economy.CHEST_REWARD_POLICY, "tier": 14, "pip_level": 99, "base": 700, "bonus": 350, "total": 1050}
	var result := Settlement.new()
	root.add_child(result)
	result.position = view.position
	result.set_chest_reward(quote)
	for dimensions: Vector2 in [Vector2(448, 436), Vector2(337, 436), Vector2(536, 314), Vector2(264, 200)]:
		view.size = dimensions
		result.size = dimensions
		_begin(view, manifest, "reward-layout-%s" % str(dimensions), true)
		view.set_chest_reward(quote)
		_step(view, 3.01)
		result.configure(Data.theme("spring"), true, false, false, false)
		await process_frame
		check(result.caption.visible and result.caption.text == "Hold the chest to open" and not result.coin_breakdown.visible,
			"The locked coin quote preserves the opening instruction at " + str(dimensions))
		check(result.chest.get_rect().is_equal_approx(view.chest.get_rect())
			and result.pip.get_rect().is_equal_approx(view.pip.get_rect())
			and result.caption.get_rect().is_equal_approx(view._caption.get_rect()),
			"Reward space stays identical across the Pip handoff at " + str(dimensions))
		var closed_chest: Rect2 = result.chest.get_rect()
		result.configure(Data.theme("spring"), true, false, false, true)
		await process_frame
		var receipt: Dictionary = result.snapshot().coin_breakdown
		check(receipt.visible and receipt.reward == quote
			and receipt.detail_text == "Chest 700 + Pip Lv99 bonus 350" and receipt.total_text == "Total 1050 coins",
			"Opened settlement shows the saved base, Pip level bonus, and exact total")
		check(not result.caption.visible and result.chest.get_rect().is_equal_approx(closed_chest),
			"Revealing the coin receipt never moves the opened chest")
		var frame := Rect2(Vector2.ZERO, dimensions)
		check(frame.encloses(result.heading.get_rect()) and not result.heading.get_rect().intersects(result.chest.get_rect()),
			"The heading reflows above the artwork after the first phone layout at " + str(dimensions))
		check(frame.encloses(result.coin_breakdown.get_rect())
			and not result.coin_breakdown.get_rect().intersects(result.replay_button.get_rect())
			and not result.coin_breakdown.get_rect().intersects(result.chest.get_rect()),
			"The complete coin receipt stays clear of the chest and actions at " + str(dimensions))
		for label: Label in [result.coin_breakdown.detail, result.coin_breakdown.total]:
			check(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				label.get_theme_font_size("font_size")).x <= label.size.x + 0.5
				and label.get_line_height() <= label.size.y + 0.5,
				"Every receipt line fits without clipping at " + str(dimensions))
		view.stop()
	result.configure({}, true, true, false, true)
	check(result.caption.visible and not result.coin_breakdown.visible and result.caption.text == "Saving your treasure...",
		"An unconfirmed save keeps its saving status in place of a collected receipt")
	result.configure({}, true, false, true, true)
	check(result.caption.visible and not result.coin_breakdown.visible and result.retry_button.visible,
		"Failed reward saves keep their retry instruction visible")
	result.set_chest_reward({})
	result.configure({}, false, false, false, false)
	check(not result.coin_breakdown.visible and result.coin_breakdown.total.text.is_empty()
		and view.snapshot().chest_reward.is_empty(), "New rounds clear prior reward details from both settlement surfaces")
	check(CoinBreakdown.description(quote) == "Chest: 700 coins. Pip level 99 bonus: 350 coins. Total: 1050 coins.",
		"Accessible reward copy contains every part of the saved reward")
	var legacy := {"policy": CoinBreakdown.Economy.LEGACY_CHEST_REWARD_POLICY, "tier": 1, "pip_level": 0, "base": 50, "bonus": 0, "total": 50}
	result.set_chest_reward(legacy)
	check(result.coin_breakdown.detail.text == "Previously saved chest reward"
		and CoinBreakdown.description(legacy) == "Previously saved chest reward. Total: 50 coins.",
		"Previously paid rewards never invent a historical Pip level")
	result.free()
	view.size = Vector2(912, 572)


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
		_step(view, 1.56)
		await _capture(output + "/" + theme_id + "-reveal.png")
		_step(view, 0.93)
		await _capture(output + "/" + theme_id + "-ready.png")
		view.stop()
	for dimensions: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		view.position = Vector2(16, 50)
		view.size = Vector2(dimensions) - Vector2(32, 74)
		_begin(view, manifest, "render-" + str(dimensions), false)
		_step(view, 2.08)
		await _capture(output + "/" + str(dimensions.x) + "x" + str(dimensions.y) + "-reveal.png")
		_step(view, 0.93)
		await _capture(output + "/" + str(dimensions.x) + "x" + str(dimensions.y) + ".png")
		view.stop()


func _render_chest_reward_review(manifest: Dictionary) -> void:
	var output: String = ProjectSettings.globalize_path("res://build/pip-chest-reward")
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "The Pip coin receipt review directory is available")
	var dialog := SettlementDialog.new()
	root.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var result := Settlement.new()
	dialog.panel.add_child(result)
	result.chest.configure_skin(Data.theme("spring"), manifest)
	result.chest.reduced_motion = true
	result.chest.mode = "opening"
	result.chest.finish_immediately()
	result.pip.set_growth_age(99)
	result.set_chest_reward({"policy": CoinBreakdown.Economy.CHEST_REWARD_POLICY, "tier": 14, "pip_level": 99, "base": 700, "bonus": 350, "total": 1050})
	result.configure(Data.theme("spring"), true, false, false, true)
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(844, 390)]:
		root.size = dimensions
		dialog.configure(result, Data.theme("spring"), true, true, "Round complete")
		dialog.open(false)
		await process_frame
		await _capture(output + "/receipt-%dx%d.png" % [dimensions.x, dimensions.y])
	dialog.free()

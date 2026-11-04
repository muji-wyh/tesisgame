extends "res://scripts/duck_mascot.gd"
## A sleepy perch performance reuses Pip's existing articulated artwork.

const SLEEP_AFTER_SECONDS: float = 3.0
const WAKE_SECONDS: float = 1.6
const SNORE_SECONDS: float = 2.8
const SLEEP_CYCLE_SECONDS: float = 21.0
const WAKE_HANDOVER_SECONDS: float = 0.18
const JOURNEY_STRIDE_SECONDS: float = 0.38
const JOURNEY_GROUND_Y: float = -14.0
const SleepAudio = preload("res://scripts/word_jelly_map_pip_audio.gd")
const ScrollInertia = preload("res://scripts/word_jelly_map_pip_inertia.gd")
# Seconds, head tuck, lateral slip, drop, body turn, wing catch, head turn.
# Long still passages separate the small sleepy mishaps.
const SLEEP_BEATS := [
	[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	[5.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	[7.0, 1.0, -3.0, 0.0, -3.0, 0.0, -5.0],
	[12.6, 1.0, -3.0, 0.0, -3.0, 0.0, -5.0],
	[13.6, 1.0, 6.0, 4.0, 5.0, 8.0, -10.0],
	[14.2, 0.65, 20.0, 14.0, 24.0, 56.0, -19.0],
	[14.8, 0.45, 17.0, 10.0, 18.0, 66.0, -15.0],
	[15.5, 0.65, 6.0, 1.0, 3.0, 33.0, -8.0],
	[16.2, 1.0, -3.0, 0.0, -3.0, 6.0, -5.0],
	[17.4, 1.0, -3.0, 0.0, -3.0, 0.0, -5.0],
	[19.6, 1.0, -3.0, 0.0, -3.0, 0.0, -5.0],
	[SLEEP_CYCLE_SECONDS, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]]
# Seconds, lateral slip, drop, body turn, wing spread, head counter-turn.
const WAKE_BEATS := [
	[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	[0.10, -2.0, -5.0, -8.0, 35.0, 10.0],
	[0.30, 18.0, 12.0, 28.0, 65.0, -16.0],
	[0.48, 28.0, 24.0, 38.0, 76.0, -22.0],
	[0.66, 23.0, 19.0, 30.0, 57.0, -14.0],
	[0.88, 13.0, 8.0, 18.0, 67.0, -14.0],
	[1.10, 4.0, -3.0, -8.0, 24.0, 5.0],
	[1.30, -1.5, 1.0, 4.0, 8.0, -3.0],
	[WAKE_SECONDS, 0.0, 0.0, 0.0, 0.0, 0.0]]

var _awake: bool = true
var _wake_blend: float = 1.0
var _quiet_seconds: float = 0.0
var _sleep_seconds: float = 0.0
var _wake_elapsed: float = WAKE_SECONDS
var _wake_count: int = 0
var perch_direction: float = 1.0
var _wake_direction: float = 1.0
var _sleep_direction: float = 1.0
var _wake_from: Array[Transform2D] = []
var _wake_source := "pointer"
var _scroll_wake_count := 0
var _scroll_hold_left := 0.0
var _scroll_reaction_left := 0.0
var _grip_blend := 0.0
var _inertia := ScrollInertia.new()
var _scroll_reaction_timer := Timer.new()
var _grip_release_timer := Timer.new()
var _interaction_active: bool = false
var _foreground := Control.new()
var _sleep_timer := Timer.new()
var _snore_timer := Timer.new()
var _audio := SleepAudio.new()
var _snores: Array[Label] = []
var _journey_phase := ""
var _journey_elapsed := 0.0
var _journey_progress := 0.0
var _journey_direction := 1.0
var _journey_from: Array[Transform2D] = []
var _journey_phase_from: Array[Transform2D] = []
var _journey_transforms: Array[Transform2D] = []


func _init() -> void:
	_foreground.name = "RestingPipHeadAndWings"
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground.focus_mode = Control.FOCUS_NONE
	_foreground.z_index = 2
	add_child(_foreground)
	_foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_foreground.draw.connect(_draw_foreground)
	_sleep_timer.one_shot = true
	_sleep_timer.timeout.connect(_fall_asleep)
	add_child(_sleep_timer)
	add_child(_audio)
	_snore_timer.wait_time = SNORE_SECONDS
	_snore_timer.timeout.connect(func() -> void:
		if _is_snoring():
			_audio.pulse_snore())
	add_child(_snore_timer)
	_scroll_reaction_timer.one_shot = true
	_scroll_reaction_timer.timeout.connect(func() -> void:
		_scroll_reaction_left = 0.0
		_update_pose())
	add_child(_scroll_reaction_timer)
	_grip_release_timer.one_shot = true
	_grip_release_timer.timeout.connect(func() -> void:
		if reduced_motion:
			_scroll_hold_left = 0.0
			_grip_blend = 0.0
			_update_pose())
	add_child(_grip_release_timer)
	for index in range(3):
		var snore: Label = Style.label("z" if index < 2 else "Z", 13)
		snore.mouse_filter = Control.MOUSE_FILTER_IGNORE
		snore.add_theme_color_override("font_color", Color("#fff9de"))
		snore.add_theme_color_override("font_shadow_color", Color(0.35, 0.38, 0.49, 0.28))
		snore.add_theme_constant_override("shadow_offset_y", 1)
		_foreground.add_child(snore)
		_snores.append(snore)
		snore.hide()
	resized.connect(func() -> void:
		cancel_scroll_motion()
		queue_redraw()
		_foreground.queue_redraw())


func _ready() -> void:
	super._ready()
	name = "MapPip"
	custom_minimum_size = Vector2.ZERO
	set_proactive_allowed(false)
	_sync_sleep_timer()


func support_point() -> Vector2:
	return Vector2(size.x * 0.5, size.y - size.x * 18.0 / 120.0)


func set_awake(value: bool) -> void:
	if value:
		pointer_activity()
	else:
		_fall_asleep()


func reset_rest() -> void:
	_journey_phase = ""
	_journey_elapsed = 0.0
	_journey_progress = 0.0
	_journey_from.clear()
	_journey_phase_from.clear()
	_journey_transforms.clear()
	cancel_scroll_motion()
	_wake_source = "pointer"
	_audio.stop()
	_snore_timer.stop()
	_awake = true
	_quiet_seconds = 0.0
	_sleep_seconds = 0.0
	_wake_elapsed = WAKE_SECONDS
	_wake_blend = 1.0
	_wake_from.clear()
	_interaction_active = false
	_sync_sleep_timer()
	_update_pose()


func journey_active() -> bool:
	return not _journey_phase.is_empty()


func set_journey_pose(phase: String, elapsed: float, progress: float, direction: float) -> void:
	if phase.is_empty():
		if journey_active():
			reset_rest()
		return
	if phase not in ["depart", "run", "jump", "land"] or reduced_motion \
		or not is_finite(elapsed) or not is_finite(progress) or not is_finite(direction):
		return
	if not journey_active():
		_journey_from = rest_transforms().duplicate()
		cancel_scroll_motion()
		_audio.stop()
		_snore_timer.stop()
		_sleep_timer.stop()
		_awake = true
		_quiet_seconds = 0.0
		_sleep_seconds = 0.0
		_wake_elapsed = WAKE_SECONDS
		_wake_blend = 1.0
		_wake_from.clear()
		_wake_source = "journey"
		_reset_idle()
		reaction_left = 0.0
		_reaction = ""
		_reaction_face = ""
	if phase != _journey_phase:
		_journey_phase_from = _journey_transforms.duplicate()
	_journey_phase = phase
	_journey_elapsed = maxf(0.0, elapsed)
	_journey_progress = clampf(progress, 0.0, 1.0)
	_journey_direction = -1.0 if direction < 0.0 else 1.0
	# The route owns one clock. Draw callbacks reuse the same articulated sample.
	_journey_transforms = _sample_journey_transforms()
	_update_pose()


func set_interaction_active(value: bool) -> void:
	if _interaction_active == value:
		return
	_interaction_active = value
	if value:
		pointer_activity()


func pointer_activity() -> void:
	if journey_active() or _idle_paused or not is_visible_in_tree():
		return
	_quiet_seconds = 0.0
	if not _awake:
		_wake_source = "pointer"
		_wake_from = rest_transforms()
		_audio.wake()
		_snore_timer.stop()
		_awake = true
		_wake_count += 1
		_wake_direction = perch_direction
		_wake_elapsed = WAKE_SECONDS if reduced_motion else 0.0
		_sleep_seconds = 0.0
	if reduced_motion:
		_wake_blend = 1.0
	_sync_sleep_timer()
	_update_pose()


func scroll_motion(distance: float) -> void:
	if journey_active() or _idle_paused or not is_visible_in_tree() or not is_finite(distance) \
		or absf(distance) < 0.001 or size.x <= 0.0:
		return
	var was_sleeping: bool = not _awake
	if was_sleeping or not _scroll_engaged():
		_wake_from = rest_transforms()
		_wake_source = "scroll"
		_wake_direction = perch_direction
		_wake_elapsed = WAKE_SECONDS if reduced_motion else 0.0
	if was_sleeping:
		_audio.wake()
		_snore_timer.stop()
		_awake = true
		_wake_count += 1
		_scroll_wake_count += 1
		_sleep_seconds = 0.0
		_scroll_reaction_left = 0.55
		if reduced_motion:
			_scroll_reaction_timer.start(_scroll_reaction_left)
	_quiet_seconds = 0.0
	_scroll_hold_left = 0.18
	if reduced_motion:
		_wake_blend = 1.0
		_grip_blend = 1.0
		_grip_release_timer.start(0.22)
	else:
		# Positive scroll offset moves the supporting stage upward.
		_inertia.push(-distance * 120.0 / size.x, perch_direction)
	_sync_sleep_timer()
	_update_pose()


func cancel_scroll_motion() -> void:
	_inertia.reset()
	_scroll_hold_left = 0.0
	_scroll_reaction_left = 0.0
	_grip_blend = 0.0
	_scroll_reaction_timer.stop()
	_grip_release_timer.stop()


func _scroll_engaged() -> bool:
	return _scroll_hold_left > 0.0 or _inertia.is_active() or _grip_blend > 0.0


func _fall_asleep() -> void:
	if journey_active() or _idle_paused or not is_visible_in_tree() or not _awake:
		return
	cancel_scroll_motion()
	_awake = false
	_quiet_seconds = SLEEP_AFTER_SECONDS
	_sleep_seconds = 0.0
	_sleep_direction = perch_direction
	_wake_from.clear()
	_wake_elapsed = WAKE_SECONDS
	if reduced_motion:
		_wake_blend = 0.0
	_sleep_timer.stop()
	_audio.set_sleeping(true)
	_audio.pulse_snore()
	if reduced_motion:
		_snore_timer.start()
	_update_pose()


func set_audio_enabled(value: bool) -> void:
	_audio.set_enabled(value)


func _sync_sleep_timer() -> void:
	_sleep_timer.stop()
	if not journey_active() and reduced_motion and _awake and not _idle_paused and is_visible_in_tree():
		_sleep_timer.start(maxf(0.01, SLEEP_AFTER_SECONDS - _quiet_seconds))


func set_idle_paused(value: bool) -> void:
	if _idle_paused == value:
		return
	super.set_idle_paused(value)
	if value:
		if journey_active():
			_sleep_timer.stop()
			_snore_timer.stop()
			_audio.stop()
		else:
			reset_rest()
	else:
		_sync_sleep_timer()


func set_reduced_motion(value: bool) -> void:
	if value == reduced_motion:
		return
	if value and journey_active():
		reset_rest()
	if reduced_motion and _awake and not _sleep_timer.is_stopped():
		_quiet_seconds = SLEEP_AFTER_SECONDS - _sleep_timer.time_left
	var was_gripping: bool = _scroll_engaged()
	_inertia.reset()
	_scroll_hold_left = 0.18 if value and was_gripping else 0.0
	_grip_blend = 1.0 if value and was_gripping else 0.0
	_scroll_reaction_timer.stop()
	_grip_release_timer.stop()
	_scroll_reaction_left = 0.0
	if value and was_gripping:
		_grip_release_timer.start(0.22)
	if value:
		reaction_left = 0.0
		_reaction_face = ""
		_reaction = ""
	super.set_reduced_motion(value)
	_snore_timer.stop()
	if value and not _awake and not _idle_paused and is_visible_in_tree():
		_snore_timer.start()
	_wake_elapsed = WAKE_SECONDS
	_wake_from.clear()
	_wake_blend = 1.0 if _awake else 0.0
	_sync_sleep_timer()
	_update_pose()


func _process(delta: float) -> void:
	if journey_active() or _idle_paused or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	var step: float = minf(delta, 0.1)
	if not reduced_motion:
		_inertia.advance(step)
		_scroll_hold_left = maxf(0.0, _scroll_hold_left - step)
		_scroll_reaction_left = maxf(0.0, _scroll_reaction_left - step)
		var holding: bool = _scroll_hold_left > 0.0 or _inertia.is_active()
		_grip_blend = move_toward(_grip_blend, 1.0 if holding else 0.0, step / (0.12 if holding else 0.25))
		if _wake_elapsed < WAKE_SECONDS:
			_wake_elapsed = minf(WAKE_SECONDS, _wake_elapsed + step)
		elif _awake and not _scroll_engaged():
			_quiet_seconds = minf(SLEEP_AFTER_SECONDS, _quiet_seconds + step)
			if _quiet_seconds >= SLEEP_AFTER_SECONDS - 0.00001:
				_fall_asleep()
		elif not _awake:
			var previous_beat: int = floori(_sleep_seconds / SNORE_SECONDS)
			var was_snoring: bool = _is_snoring()
			_sleep_seconds += step
			if not _is_snoring():
				_audio.pause_snore()
			elif not was_snoring or floori(_sleep_seconds / SNORE_SECONDS) != previous_beat:
				_audio.pulse_snore()
	var target: float = 1.0 if _awake else 0.0
	_wake_blend = target if reduced_motion else move_toward(_wake_blend, target, step / 0.18)
	super._process(step)


func _has_continuous_pose() -> bool:
	return not reduced_motion or super._has_continuous_pose()


func _select_expression() -> String:
	if journey_active():
		if _journey_phase == "depart":
			return "encourage"
		if _journey_phase == "land":
			return "proud" if _journey_progress < 0.72 else "neutral"
		return "delighted" if _journey_phase == "jump" else "encourage"
	if not _awake:
		return "sleepy"
	if _wake_source == "scroll":
		if _scroll_reaction_left > 0.35:
			return "surprised"
		if _scroll_engaged():
			return "listening"
		if _wake_elapsed < WAKE_SECONDS:
			return "thinking"
	if _wake_elapsed < 0.72:
		return "surprised"
	if _wake_elapsed < 1.14:
		return "encourage"
	if _wake_elapsed < WAKE_SECONDS:
		return "proud"
	var blink: bool = not reduced_motion and fmod(_idle_time, 4.6) > 4.42
	return "blink" if blink else "neutral"


func _update_pose(force_redraw: bool = true) -> void:
	super._update_pose(force_redraw)
	if is_instance_valid(_foreground):
		_foreground.queue_redraw()
	_update_snores()


func _update_snores() -> void:
	if not _is_snoring():
		for snore: Label in _snores:
			snore.hide()
		return
	var emission: Vector2 = Vector2(size.x * 0.76, size.y * 0.24)
	if not _growth_stage.is_empty():
		var neck_y: float = GAMEPLAY_PIVOTS[1].y
		var joints: Array = _growth_stage.get("motionPivots", [])
		if joints.size() == GAMEPLAY_PIVOTS.size():
			neck_y = float(joints[1][1])
		emission = support_point() + (rest_transforms()[1] * Vector2(87.0, neck_y - 14.0) - Vector2(60, 100)) * size.x / 120.0
	for index in range(_snores.size()):
		var snore: Label = _snores[index]
		snore.show()
		var phase: float = 0.30 + index * 0.20 if reduced_motion else fposmod(_sleep_seconds / SNORE_SECONDS - index * 0.17, 1.0)
		var opacity: float = smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.62, 1.0, phase))
		snore.modulate.a = opacity * 0.85
		snore.position = emission + Vector2(size.x * phase * 0.20, -size.y * phase * 0.32)
		var pixels: int = maxi(10, roundi(size.x * (0.10 + index * 0.015)))
		if snore.get_theme_font_size("font_size") != pixels:
			snore.add_theme_font_size_override("font_size", pixels)
		snore.rotation = deg_to_rad(-8.0 + phase * 12.0)


func _sleep_stage() -> String:
	if _awake:
		return ""
	if reduced_motion:
		return "upright-snoring"
	var elapsed: float = fposmod(_sleep_seconds, SLEEP_CYCLE_SECONDS)
	if elapsed < 5.6:
		return "upright-snoring"
	if elapsed < 7.0:
		return "nestling"
	if elapsed < 12.6:
		return "prone-snoring"
	if elapsed < 13.6:
		return "sleep-drifting"
	if elapsed < 14.2:
		return "sleep-slipping"
	if elapsed < 14.8:
		return "sleep-catching"
	if elapsed < 17.4:
		return "sleep-resettling"
	if elapsed < 19.6:
		return "tucked-snoring"
	return "untucking"


func _is_snoring() -> bool:
	if journey_active() or _awake or _idle_paused or not is_visible_in_tree():
		return false
	return _sleep_stage() not in ["sleep-drifting", "sleep-slipping", "sleep-catching", "sleep-resettling"]


func _sleep_motion() -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	if _awake or reduced_motion:
		return result
	var elapsed: float = fposmod(_sleep_seconds, SLEEP_CYCLE_SECONDS)
	for index in range(1, SLEEP_BEATS.size()):
		var right: Array = SLEEP_BEATS[index]
		if elapsed <= float(right[0]):
			var left: Array = SLEEP_BEATS[index - 1]
			var weight: float = smoothstep(float(left[0]), float(right[0]), elapsed)
			for channel in range(result.size()):
				result[channel] = lerpf(float(left[channel + 1]), float(right[channel + 1]), weight)
			break
	return result


func _wake_motion() -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
	if reduced_motion or _wake_elapsed >= WAKE_SECONDS or _wake_source == "scroll":
		return result
	for index in range(1, WAKE_BEATS.size()):
		var right: Array = WAKE_BEATS[index]
		if _wake_elapsed <= float(right[0]):
			var left: Array = WAKE_BEATS[index - 1]
			var weight: float = smoothstep(float(left[0]), float(right[0]), _wake_elapsed)
			for channel in range(result.size()):
				result[channel] = lerpf(float(left[channel + 1]), float(right[channel + 1]), weight)
			break
	return result


func rest_transforms() -> Array[Transform2D]:
	if journey_active() and not _journey_transforms.is_empty():
		return _journey_transforms
	return _perch_transforms()


func _perch_transforms() -> Array[Transform2D]:
	var neck_y: float = GAMEPLAY_PIVOTS[1].y
	var shoulder_y: float = (GAMEPLAY_PIVOTS[2].y + GAMEPLAY_PIVOTS[3].y) * 0.5
	var joints: Array = _growth_stage.get("motionPivots", [])
	if joints.size() == GAMEPLAY_PIVOTS.size():
		neck_y = float(joints[1][1])
		shoulder_y = (float(joints[2][1]) + float(joints[3][1])) * 0.5
	var gripping: bool = _awake and _scroll_engaged()
	var breath: float = 0.0 if reduced_motion or gripping else sin((_idle_time if _awake else _sleep_seconds) * TAU / (4.2 if _awake else SNORE_SECONDS)) * (0.55 if _awake else 1.25)
	var wake: float = smoothstep(0.0, 1.0, _wake_blend)
	var motion: PackedFloat32Array = _wake_motion()
	var sleep_motion: PackedFloat32Array = _sleep_motion()
	var tuck: float = sleep_motion[0]
	if not _awake:
		motion = PackedFloat32Array([sleep_motion[1], sleep_motion[2], sleep_motion[3], sleep_motion[4], sleep_motion[5]])
	var direction: float = _wake_direction if _awake else _sleep_direction
	var grip_fold: float = 0.0 if reduced_motion else _grip_blend
	motion[0] *= direction
	motion[2] *= direction
	motion[4] *= direction
	var torso: Vector2 = Vector2(0.0, 96.0 - shoulder_y + breath)
	var head: Vector2 = Vector2(-1.5 * (1.0 - wake) - tuck * 8.0 * direction, 90.0 - neck_y - 4.0 * wake + breath * 0.35 + tuck * 5.0)
	var authored: Array[Transform2D] = [
		_gameplay_part_transform(0, torso, deg_to_rad(-4.0)),
		_gameplay_part_transform(1, head, deg_to_rad(lerpf(-10.0, -1.0, wake) + motion[4])),
		_gameplay_part_transform(2, Vector2.ZERO, deg_to_rad(-78.0 - grip_fold * 4.0 + motion[3] * (1.0 if direction > 0 else 0.65))),
		_gameplay_part_transform(3, Vector2.ZERO, deg_to_rad(80.0 + grip_fold * 4.0 - motion[3] * (0.65 if direction > 0 else 1.0))),
		Transform2D.IDENTITY,
		Transform2D.IDENTITY,
	]
	var transforms: Array[Transform2D] = _growth_transforms(authored)
	var pivot := Vector2(60.0, 96.0)
	var slip := Transform2D(deg_to_rad(motion[2]), Vector2.ZERO)
	slip.origin = pivot + Vector2(motion[0], motion[1]) - slip * pivot
	for index in range(transforms.size()):
		transforms[index] = slip * transforms[index]
	if gripping and not reduced_motion:
		var supported: Array[Transform2D] = transforms.duplicate()
		var sway := Transform2D(_inertia.angle, Vector2.ZERO)
		sway.origin = pivot + _inertia.offset - sway * pivot
		for index in range(transforms.size()):
			transforms[index] = sway * transforms[index]
		# A little neck follow-through makes the head heavier than the torso.
		var neck := Vector2(60.0, neck_y)
		var head_pivot: Vector2 = transforms[1] * neck
		var head_follow := Transform2D(-_inertia.angle * 0.35, Vector2.ZERO)
		head_follow.origin = head_pivot - head_follow * head_pivot
		transforms[1] = head_follow * transforms[1]
		for index: int in [2, 3]:
			var tip: Vector2 = grip_tip(index)
			var shoulder: Vector2 = _part_joint(index)
			var anchor: Vector2 = supported[index] * tip
			var root: Vector2 = transforms[0] * shoulder
			var turn: float = (anchor - root).angle() - (tip - shoulder).angle()
			var wing := Transform2D(turn, Vector2.ZERO)
			wing.origin = anchor - wing * tip
			transforms[index] = wing
	if _awake and not _wake_from.is_empty() and not reduced_motion and _wake_elapsed < WAKE_HANDOVER_SECONDS:
		var handover: float = smoothstep(0.0, WAKE_HANDOVER_SECONDS, _wake_elapsed)
		for index in range(transforms.size()):
			transforms[index] = _wake_from[index].interpolate_with(transforms[index], handover)
	return transforms


func _sample_journey_transforms() -> Array[Transform2D]:
	var result: Array[Transform2D] = _journey_run_transforms()
	var progress: float = _journey_progress
	if _journey_phase == "depart":
		var stand: float = smoothstep(0.0, 1.0, progress)
		for index in range(result.size()):
			result[index] = _journey_from[index].interpolate_with(result[index], stand)
	elif _journey_phase == "jump":
		var airborne: float = sin(progress * PI)
		var crouch: float = sin(clampf(progress / 0.22, 0.0, 1.0) * PI)
		var tilt: float = deg_to_rad(_journey_direction * lerpf(6.0, -2.0, progress))
		var hips := Vector2(0.0, JOURNEY_GROUND_Y + crouch * 2.5 - airborne * 1.2)
		var wing_open: float = smoothstep(0.06, 0.44, progress) * (1.0 - smoothstep(0.72, 1.0, progress) * 0.58)
		var flutter: float = sin(progress * TAU * 2.0) * airborne * 5.0
		var authored: Array[Transform2D] = [
			_gameplay_part_transform(0, hips, tilt),
			_gameplay_part_transform(1, hips + Vector2(0.0, -airborne), -tilt * 0.45),
			_gameplay_part_transform(2, hips, deg_to_rad(lerpf(-14.0, 72.0, wing_open) + flutter)),
			_gameplay_part_transform(3, hips, deg_to_rad(lerpf(14.0, -72.0, wing_open) - flutter)),
			_gameplay_part_transform(4, Vector2(-airborne * 2.0, JOURNEY_GROUND_Y - airborne * 6.0), deg_to_rad(-airborne * 18.0)),
			_gameplay_part_transform(5, Vector2(airborne * 2.0, JOURNEY_GROUND_Y - airborne * 6.0), deg_to_rad(airborne * 18.0)),
		]
		result = _growth_transforms(authored)
		_attach_journey_head(result)
		if not _journey_phase_from.is_empty():
			var push_off: float = smoothstep(0.0, 0.24, progress)
			for index in range(result.size()):
				result[index] = _journey_phase_from[index].interpolate_with(result[index], push_off)
	elif _journey_phase == "land":
		result = _perch_transforms()
		var settle: float = smoothstep(0.0, 1.0, progress)
		if not _journey_phase_from.is_empty():
			for index in range(result.size()):
				result[index] = _journey_phase_from[index].interpolate_with(result[index], settle)
		# Contact bends at the hips and neck; the painted layers retain their volume.
		var absorption: float = sin(progress * PI) * (1.0 - progress) * 2.8
		result[0].origin.y += absorption
		result[1].origin.y += absorption * 1.35
	_attach_journey_wings(result)
	return result


func _journey_run_transforms() -> Array[Transform2D]:
	var stride: float = sin(_journey_elapsed * TAU / JOURNEY_STRIDE_SECONDS)
	# The last strides plant both feet and bend the hips before the route's leap.
	var ready: float = smoothstep(0.86, 1.0, _journey_progress) if _journey_phase == "run" else 0.0
	stride *= 1.0 - ready
	var hips := Vector2(stride * 0.7, JOURNEY_GROUND_Y - absf(stride) * 1.8 + ready * 2.1)
	var tilt: float = deg_to_rad(_journey_direction * (5.0 - ready * 2.0) + stride * 2.0)
	var authored: Array[Transform2D] = [
		_gameplay_part_transform(0, hips, tilt),
		_gameplay_part_transform(1, hips + Vector2(0.0, -absf(stride) * 0.5), -tilt * 0.45),
		_gameplay_part_transform(2, hips, deg_to_rad(-14.0 - stride * 20.0 + ready * 12.0)),
		_gameplay_part_transform(3, hips, deg_to_rad(14.0 - stride * 20.0 - ready * 12.0)),
		_gameplay_part_transform(4, Vector2(stride * _journey_direction * 2.0, JOURNEY_GROUND_Y - maxf(0.0, stride) * 4.5), deg_to_rad(-_journey_direction * 4.0 - stride * 10.0)),
		_gameplay_part_transform(5, Vector2(-stride * _journey_direction * 2.0, JOURNEY_GROUND_Y - maxf(0.0, -stride) * 4.5), deg_to_rad(-_journey_direction * 4.0 + stride * 10.0)),
	]
	var result: Array[Transform2D] = _growth_transforms(authored)
	_attach_journey_head(result)
	return result


func _attach_journey_head(transforms: Array[Transform2D]) -> void:
	var neck: Vector2 = _part_joint(1)
	# A counter-turned head keeps its neck planted in the independently leaning body.
	transforms[1].origin = transforms[0] * neck - transforms[1].basis_xform(neck)


func _attach_journey_wings(transforms: Array[Transform2D]) -> void:
	for index: int in [2, 3]:
		var shoulder: Vector2 = _part_joint(index)
		transforms[index].origin = transforms[0] * shoulder - transforms[index].basis_xform(shoulder)


func _journey_feet_alpha() -> float:
	if _journey_phase == "depart":
		return smoothstep(0.04, 0.48, _journey_progress)
	if _journey_phase == "land":
		return 1.0 - smoothstep(0.24, 0.78, _journey_progress)
	return 1.0


func _journey_front_alpha() -> float:
	if _journey_phase == "depart":
		return smoothstep(0.12, 0.55, _journey_progress)
	if _journey_phase == "land":
		return 1.0 - smoothstep(0.05, 0.65, _journey_progress)
	return 1.0


func _part_joint(index: int) -> Vector2:
	var joints: Array = _growth_stage.get("motionPivots", [])
	if joints.size() == GAMEPLAY_PIVOTS.size():
		return Vector2(float(joints[index][0]), float(joints[index][1]))
	return GAMEPLAY_PIVOTS[index]


func grip_tip(index: int) -> Vector2:
	# The held feather follows the acquired storybook wing's authored contour.
	var age: int = 12 if not professional_profile.is_empty() else growth_age
	var length: float = 16.0 if age <= 3 else 19.0 if age <= 6 else 23.0
	return _part_joint(index) + Vector2(-3.0 if index == 2 else 3.0, length - 3.0)


func _paint_part(canvas: CanvasItem, index: int, transform: Transform2D, alpha: float = 1.0) -> void:
	var unit: float = size.x / 120.0
	var support: Vector2 = support_point()
	var base := Transform2D(Vector2(unit, 0), Vector2(0, unit), support - Vector2(60, 100) * unit)
	var texture: Texture2D = _outfit_dance_sheet if _outfit_dance_sheet != null else DANCE_SHEET
	var cell: int = index
	if index == 1 and _expression_heads != null:
		texture = _expression_heads
		cell = EXPRESSION_NAMES.find(_face_name)
	var edge: float = texture.get_height()
	canvas.draw_set_transform_matrix(base * transform)
	canvas.draw_texture_rect_region(texture, Rect2(0, 0, 120, 120),
		Rect2(Vector2(cell * edge, 0), Vector2.ONE * edge), Color(1.0, 1.0, 1.0, alpha))
	canvas.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	if size.x > 0.0 and not _growth_stage.is_empty():
		var transforms: Array[Transform2D] = rest_transforms()
		if journey_active():
			for index: int in [4, 5]:
				_paint_part(self, index, transforms[index], _journey_feet_alpha())
		_paint_part(self, 0, transforms[0])


func _draw_foreground() -> void:
	if size.x <= 0.0 or _growth_stage.is_empty():
		return
	var transforms: Array[Transform2D] = rest_transforms()
	if journey_active():
		# Travel clears the stage face; landing returns the body behind its rim.
		var front: float = _journey_front_alpha()
		for index: int in [4, 5]:
			_paint_part(_foreground, index, transforms[index], front * _journey_feet_alpha())
		_paint_part(_foreground, 0, transforms[0], front)
	for index: int in [2, 3, 1]:
		_paint_part(_foreground, index, transforms[index])


func rest_snapshot() -> Dictionary:
	var support: Vector2 = get_global_transform() * support_point()
	var state: String = "sleeping" if not _awake else "awake"
	if _awake and _wake_elapsed < WAKE_SECONDS:
		state = "startled" if _wake_elapsed < 0.16 else "slipping" if _wake_elapsed < 0.66 \
			else "climbing" if _wake_elapsed < 1.14 else "settling"
	if _awake and _wake_source == "scroll":
		if _scroll_reaction_left > 0.35:
			state = "scroll-startled"
		elif _scroll_engaged():
			state = "scroll-gripping" if _scroll_hold_left > 0.0 else "scroll-settling"
		elif _wake_elapsed < WAKE_SECONDS:
			state = "scroll-settling"
		else:
			state = "awake"
	if journey_active():
		state = "journey-" + _journey_phase
	return {"pose": "traveling-between-stages" if journey_active() else "resting-on-stage", "awake": _awake, "state": state,
		"journey_active": journey_active(), "journey_phase": _journey_phase,
		"journey_elapsed": _journey_elapsed, "journey_progress": _journey_progress,
		"journey_direction": _journey_direction,
		"quiet_seconds": _quiet_seconds, "wake_elapsed": _wake_elapsed, "wake_count": _wake_count,
		"wake_direction": _wake_direction,
		"wake_source": _wake_source, "scroll_wake_count": _scroll_wake_count,
		"gripping": _awake and _scroll_engaged(), "grip_blend": _grip_blend,
		"inertia": _inertia.snapshot(),
		"snoring": _is_snoring(), "sleep_stage": _sleep_stage(),
		"sleep_elapsed": _sleep_seconds, "sleep_cycle_elapsed": fposmod(_sleep_seconds, SLEEP_CYCLE_SECONDS),
		"sleep_direction": _sleep_direction,
		"audio": _audio.snapshot(),
		"wake_blend": _wake_blend, "elapsed": _idle_time, "expression": expression_name(),
		"support": [support.x, support.y], "breathing": not journey_active() and not reduced_motion and not _idle_paused}

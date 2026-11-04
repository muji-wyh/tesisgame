extends "res://scripts/duck_mascot.gd"
## Sleep and a small near-fall reuse Pip's existing articulated artwork.

const SLEEP_AFTER_SECONDS: float = 3.0
const WAKE_SECONDS: float = 1.6
const SNORE_SECONDS: float = 2.8
const SleepAudio = preload("res://scripts/word_jelly_map_pip_audio.gd")
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
var _interaction_active: bool = false
var _foreground := Control.new()
var _sleep_timer := Timer.new()
var _snore_timer := Timer.new()
var _audio := SleepAudio.new()
var _snores: Array[Label] = []


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
		if not _awake and not _idle_paused and is_visible_in_tree():
			_audio.pulse_snore())
	add_child(_snore_timer)
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
	_audio.stop()
	_snore_timer.stop()
	_awake = true
	_quiet_seconds = 0.0
	_sleep_seconds = 0.0
	_wake_elapsed = WAKE_SECONDS
	_wake_blend = 1.0
	_interaction_active = false
	_sync_sleep_timer()
	_update_pose()


func set_interaction_active(value: bool) -> void:
	if _interaction_active == value:
		return
	_interaction_active = value
	if value:
		pointer_activity()


func pointer_activity() -> void:
	if _idle_paused or not is_visible_in_tree():
		return
	_quiet_seconds = 0.0
	if not _awake:
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


func _fall_asleep() -> void:
	if _idle_paused or not is_visible_in_tree() or not _awake:
		return
	_awake = false
	_quiet_seconds = SLEEP_AFTER_SECONDS
	_sleep_seconds = 0.0
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
	if reduced_motion and _awake and not _idle_paused and is_visible_in_tree():
		_sleep_timer.start(maxf(0.01, SLEEP_AFTER_SECONDS - _quiet_seconds))


func set_idle_paused(value: bool) -> void:
	if _idle_paused == value:
		return
	super.set_idle_paused(value)
	if value:
		reset_rest()
	else:
		_sync_sleep_timer()


func set_reduced_motion(value: bool) -> void:
	if value == reduced_motion:
		return
	if reduced_motion and _awake and not _sleep_timer.is_stopped():
		_quiet_seconds = SLEEP_AFTER_SECONDS - _sleep_timer.time_left
	if value:
		reaction_left = 0.0
		_reaction_face = ""
		_reaction = ""
	super.set_reduced_motion(value)
	_snore_timer.stop()
	if value and not _awake and not _idle_paused and is_visible_in_tree():
		_snore_timer.start()
	_wake_elapsed = WAKE_SECONDS
	_wake_blend = 1.0 if _awake else 0.0
	_sync_sleep_timer()
	_update_pose()


func _process(delta: float) -> void:
	if _idle_paused or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	var step: float = minf(delta, 0.1)
	if not reduced_motion:
		if _wake_elapsed < WAKE_SECONDS:
			_wake_elapsed = minf(WAKE_SECONDS, _wake_elapsed + step)
		elif _awake:
			_quiet_seconds = minf(SLEEP_AFTER_SECONDS, _quiet_seconds + step)
			if _quiet_seconds >= SLEEP_AFTER_SECONDS - 0.00001:
				_fall_asleep()
		else:
			var previous_beat: int = floori(_sleep_seconds / SNORE_SECONDS)
			_sleep_seconds += step
			if floori(_sleep_seconds / SNORE_SECONDS) != previous_beat:
				_audio.pulse_snore()
	var target: float = 1.0 if _awake else 0.0
	_wake_blend = target if reduced_motion else move_toward(_wake_blend, target, step / 0.18)
	super._process(step)


func _has_continuous_pose() -> bool:
	return not reduced_motion or super._has_continuous_pose()


func _select_expression() -> String:
	if not _awake:
		return "sleepy"
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
	for index in range(_snores.size()):
		var snore: Label = _snores[index]
		snore.visible = not _awake and not _idle_paused and is_visible_in_tree()
		if not snore.visible:
			continue
		var phase: float = 0.30 + index * 0.20 if reduced_motion else fposmod(_sleep_seconds / SNORE_SECONDS - index * 0.17, 1.0)
		var opacity: float = smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.62, 1.0, phase))
		snore.modulate.a = opacity * 0.85
		snore.position = Vector2(size.x * (0.76 + phase * 0.20), size.y * (0.24 - phase * 0.32))
		var pixels: int = maxi(10, roundi(size.x * (0.10 + index * 0.015)))
		if snore.get_theme_font_size("font_size") != pixels:
			snore.add_theme_font_size_override("font_size", pixels)
		snore.rotation = deg_to_rad(-8.0 + phase * 12.0)


func _wake_motion() -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
	if reduced_motion or _wake_elapsed >= WAKE_SECONDS:
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
	var neck_y: float = GAMEPLAY_PIVOTS[1].y
	var shoulder_y: float = (GAMEPLAY_PIVOTS[2].y + GAMEPLAY_PIVOTS[3].y) * 0.5
	var joints: Array = _growth_stage.get("motionPivots", [])
	if joints.size() == GAMEPLAY_PIVOTS.size():
		neck_y = float(joints[1][1])
		shoulder_y = (float(joints[2][1]) + float(joints[3][1])) * 0.5
	var breath: float = 0.0 if reduced_motion else sin((_idle_time if _awake else _sleep_seconds) * TAU / (4.2 if _awake else SNORE_SECONDS)) * (0.55 if _awake else 1.25)
	var wake: float = smoothstep(0.0, 1.0, _wake_blend)
	var motion: PackedFloat32Array = _wake_motion()
	motion[0] *= _wake_direction
	motion[2] *= _wake_direction
	motion[4] *= _wake_direction
	var torso: Vector2 = Vector2(0.0, 96.0 - shoulder_y + breath)
	var head: Vector2 = Vector2(-1.5 * (1.0 - wake), 90.0 - neck_y - 4.0 * wake + breath * 0.35)
	var authored: Array[Transform2D] = [
		_gameplay_part_transform(0, torso, deg_to_rad(-4.0)),
		_gameplay_part_transform(1, head, deg_to_rad(lerpf(-10.0, -1.0, wake) + motion[4])),
		_gameplay_part_transform(2, Vector2.ZERO, deg_to_rad(-78.0 + motion[3] * (1.0 if _wake_direction > 0 else 0.65))),
		_gameplay_part_transform(3, Vector2.ZERO, deg_to_rad(80.0 - motion[3] * (0.65 if _wake_direction > 0 else 1.0))),
		Transform2D.IDENTITY,
		Transform2D.IDENTITY,
	]
	var transforms: Array[Transform2D] = _growth_transforms(authored)
	var pivot := Vector2(60.0, 96.0)
	var slip := Transform2D(deg_to_rad(motion[2]), Vector2.ZERO)
	slip.origin = pivot + Vector2(motion[0], motion[1]) - slip * pivot
	for index in range(transforms.size()):
		transforms[index] = slip * transforms[index]
	return transforms


func _paint_part(canvas: CanvasItem, index: int, transform: Transform2D) -> void:
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
		Rect2(Vector2(cell * edge, 0), Vector2.ONE * edge))
	canvas.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	if size.x > 0.0 and not _growth_stage.is_empty():
		_paint_part(self, 0, rest_transforms()[0])


func _draw_foreground() -> void:
	if size.x <= 0.0 or _growth_stage.is_empty():
		return
	var transforms: Array[Transform2D] = rest_transforms()
	for index: int in [2, 3, 1]:
		_paint_part(_foreground, index, transforms[index])


func rest_snapshot() -> Dictionary:
	var support: Vector2 = get_global_transform() * support_point()
	var state: String = "sleeping" if not _awake else "awake"
	if _awake and _wake_elapsed < WAKE_SECONDS:
		state = "startled" if _wake_elapsed < 0.16 else "slipping" if _wake_elapsed < 0.66 \
			else "climbing" if _wake_elapsed < 1.14 else "settling"
	return {"pose": "resting-on-stage", "awake": _awake, "state": state,
		"quiet_seconds": _quiet_seconds, "wake_elapsed": _wake_elapsed, "wake_count": _wake_count,
		"wake_direction": _wake_direction,
		"snoring": not _awake and not _idle_paused and is_visible_in_tree(),
		"audio": _audio.snapshot(),
		"wake_blend": _wake_blend, "elapsed": _idle_time, "expression": expression_name(),
		"support": [support.x, support.y], "breathing": not reduced_motion and not _idle_paused}

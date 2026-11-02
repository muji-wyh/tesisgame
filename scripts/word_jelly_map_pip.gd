extends "res://scripts/duck_mascot.gd"
## The map's quiet, supported pose reuses Pip's existing articulated artwork.

var _awake: bool = false
var _wake_blend: float = 0.0
var _foreground := Control.new()


func _init() -> void:
	_foreground.name = "RestingPipHeadAndWings"
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground.focus_mode = Control.FOCUS_NONE
	_foreground.z_index = 2
	add_child(_foreground)
	_foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_foreground.draw.connect(_draw_foreground)
	resized.connect(func() -> void:
		queue_redraw()
		_foreground.queue_redraw())


func _ready() -> void:
	super._ready()
	name = "MapPip"
	custom_minimum_size = Vector2.ZERO
	set_proactive_allowed(false)


func support_point() -> Vector2:
	return Vector2(size.x * 0.5, size.y - size.x * 18.0 / 120.0)


func set_awake(value: bool) -> void:
	if _awake == value:
		return
	_awake = value
	if reduced_motion or _idle_paused:
		_wake_blend = 1.0 if value else 0.0
	_update_pose()


func set_reduced_motion(value: bool) -> void:
	if value == reduced_motion:
		return
	super.set_reduced_motion(value)
	_wake_blend = 1.0 if _awake else 0.0
	_update_pose()


func _process(delta: float) -> void:
	if _idle_paused or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	var step: float = minf(delta, 0.1)
	var target: float = 1.0 if _awake or reaction_left > 0.0 else 0.0
	_wake_blend = target if reduced_motion else move_toward(_wake_blend, target, step / 0.18)
	super._process(step)


func _has_continuous_pose() -> bool:
	return not reduced_motion or super._has_continuous_pose()


func _select_expression() -> String:
	var blink: bool = not reduced_motion and fmod(_idle_time, 4.6) > 4.42
	return "blink" if blink else "neutral" if _wake_blend > 0.15 else "sleepy"


func _update_pose(force_redraw: bool = true) -> void:
	super._update_pose(force_redraw)
	if is_instance_valid(_foreground):
		_foreground.queue_redraw()


func rest_transforms() -> Array[Transform2D]:
	var neck_y: float = GAMEPLAY_PIVOTS[1].y
	var shoulder_y: float = (GAMEPLAY_PIVOTS[2].y + GAMEPLAY_PIVOTS[3].y) * 0.5
	var joints: Array = _growth_stage.get("motionPivots", [])
	if joints.size() == GAMEPLAY_PIVOTS.size():
		neck_y = float(joints[1][1])
		shoulder_y = (float(joints[2][1]) + float(joints[3][1])) * 0.5
	var breath: float = 0.0 if reduced_motion else sin(_idle_time * TAU / 4.2) * 0.55
	var wake: float = smoothstep(0.0, 1.0, _wake_blend)
	var torso: Vector2 = Vector2(0.0, 96.0 - shoulder_y + breath)
	var head: Vector2 = Vector2(-1.5 * (1.0 - wake), 90.0 - neck_y - 4.0 * wake + breath * 0.35)
	var authored: Array[Transform2D] = [
		_gameplay_part_transform(0, torso, deg_to_rad(-4.0)),
		_gameplay_part_transform(1, head, deg_to_rad(lerpf(-10.0, -1.0, wake))),
		_gameplay_part_transform(2, Vector2.ZERO, deg_to_rad(-78.0)),
		_gameplay_part_transform(3, Vector2.ZERO, deg_to_rad(80.0)),
		Transform2D.IDENTITY,
		Transform2D.IDENTITY,
	]
	return _growth_transforms(authored)


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
	return {"pose": "resting-on-stage", "awake": _awake or reaction_left > 0.0,
		"wake_blend": _wake_blend, "elapsed": _idle_time, "expression": expression_name(),
		"support": [support.x, support.y], "breathing": not reduced_motion and not _idle_paused}

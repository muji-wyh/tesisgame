extends SubViewport
## The optimized Pirate uses its authored object pivots; the view owns every pose clock.

const Pirate = preload("res://scripts/pirate_asset_actor.gd")
const MODEL: String = Pirate.MODEL_PATH
const CAMERA_HEIGHT: float = 4.4
const CAMERA_CENTER_Y: float = 1.55
const FOOT_Y: float = (CAMERA_CENTER_Y + CAMERA_HEIGHT * 0.5) / CAMERA_HEIGHT
const GAMEPLAY_CLIPS: Dictionary = {
	"Idle": "Idle", "Throw": "Attack_M", "Kick": "Special_GiantRam",
	"Snatch": "Special_BigBite", "Hit": "Hit_M", "Taunt": "Taunt_BellyLaugh",
	"Celebrate": "Taunt_VictoryLap", "Escape": "Taunt_Swagger"}
const GAMEPLAY_SPANS: Dictionary = {
	"Throw": 1.1, "Kick": 1.4, "Snatch": 2.2, "Hit": 0.45,
	"Taunt": 2.0, "Celebrate": 2.5, "Escape": 2.0}

var last_error: String = ""
var _world := Node3D.new()
var _rig := Node3D.new()
var _camera := Camera3D.new()
var _pirate := Pirate.new()
# These aliases retain the viewport's inspection API without inventing a skeleton.
var _model: Node3D
var _player: AnimationPlayer
var _body: MeshInstance3D
var _hat: MeshInstance3D
var _animated_root: Node3D
var _anchor_nodes: Dictionary = {}
var _anchor_offsets: Dictionary = {}
var _clip: String = "Idle"
var _gesture: String = "Idle"
var _native_time: float = 0.0
var _action_span: float = 0.0
var _loaded: bool = false
var _frame_height: float = CAMERA_HEIGHT
var _frame_center_y: float = CAMERA_CENTER_Y


func _init() -> void:
	name = "PirateBossViewport"
	size = Vector2i(384, 576)
	transparent_bg = true
	own_world_3d = true
	gui_disable_input = true
	handle_input_locally = false
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_world)
	_world.add_child(_rig)
	_world.add_child(_camera)
	_pirate.auto_advance = false
	_rig.add_child(_pirate)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.01
	_camera.far = 100.0
	_camera.current = true
	var studio := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e0edff")
	environment.ambient_light_energy = 0.65
	studio.environment = environment
	_world.add_child(studio)
	for spec: Array in [[Vector3(-35, -30, 0), Color("#fff0d1"), 1.0],
		[Vector3(-15, 125, 0), Color("#d9e8ff"), 0.6]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		_world.add_child(light)
	set_process(false)


func load_character() -> bool:
	if _loaded:
		return true
	if not _pirate.load_character():
		return _fail(_pirate.last_error)
	_model = _pirate._model
	_player = _pirate._player
	_body = _model.find_child("Pirate_Body", true, false) as MeshInstance3D
	_hat = _model.find_child("Pirate_Hat", true, false) as MeshInstance3D
	if _body == null or _hat == null or not _body.get_parent() is Node3D \
		or not _body.get_parent().get_parent() is Node3D:
		return _fail("The Pirate Boss needs its authored elastic body and rigid hat mesh nodes.")
	_animated_root = _body.get_parent().get_parent() as Node3D
	_build_anchors()
	_rig.rotation.y = -0.15
	set_framing(CAMERA_HEIGHT, CAMERA_CENTER_Y)
	_loaded = true
	last_error = ""
	pose("Idle", 0.0)
	return true


func _build_anchors() -> void:
	# Landmarks are measured in the real mesh's local coordinates. Applying its
	# authored parent transforms keeps effects attached through growth and jumps.
	var body_bounds: AABB = _body.get_aabb()
	var hat_bounds: AABB = _hat.get_aabb()
	var center: Vector3 = body_bounds.get_center()
	_anchor_nodes = {"root": _animated_root, "body": _body, "hat": _hat,
		"face": _body, "compass": _body, "foot": _body,
		"body_left": _body, "body_right": _body}
	_anchor_offsets = {"root": Vector3.ZERO, "body": center,
		"hat": hat_bounds.get_center(),
		"face": Vector3(center.x, center.y, body_bounds.end.z),
		"compass": Vector3(center.x, body_bounds.position.y + body_bounds.size.y * 0.35, body_bounds.end.z),
		"foot": Vector3(center.x, body_bounds.position.y, center.z),
		"body_left": Vector3(body_bounds.position.x, center.y, center.z),
		"body_right": Vector3(body_bounds.end.x, center.y, center.z)}


func set_framing(height: float, center_y: float) -> void:
	if not is_finite(height) or not is_finite(center_y) or height <= 0.0:
		_fail("The Pirate Boss camera needs a positive height and finite center.")
		return
	_frame_height = height
	_frame_center_y = center_y
	_camera.size = height
	_camera.position = Vector3(0.0, center_y, 8.0)
	_camera.look_at(Vector3(0.0, center_y, 0.0))
	if _loaded:
		render_target_update_mode = SubViewport.UPDATE_ONCE


func pose(clip: String, elapsed: float, reduced_motion: bool = false, action_duration: float = 0.0) -> void:
	if not _loaded:
		return
	if not is_finite(elapsed) or not is_finite(action_duration) or action_duration < 0.0:
		_fail("The Pirate Boss pose needs finite elapsed time and a nonnegative action duration.")
		return
	var selected: String = str(GAMEPLAY_CLIPS.get(clip, clip))
	if selected not in _pirate.animation_names():
		_fail("The Pirate Boss is missing its required %s animation." % selected)
		return
	var duration: float = _pirate.clip_duration(selected)
	var span: float = action_duration if action_duration > 0.0 else float(GAMEPLAY_SPANS.get(clip, duration))
	var at: float = maxf(0.0, elapsed)
	if selected == "Idle":
		at = fposmod(at, maxf(0.001, duration))
	else:
		# A longer gameplay beat plays the whole authored action once. Clamping
		# prevents a hit, bite or taunt from restarting at its final frame.
		at = clampf(at / maxf(0.001, span), 0.0, 1.0) * duration
	if reduced_motion:
		at = 0.0
	if not _pirate.pose(selected, at):
		_fail(_pirate.last_error)
		return
	_fit_motion_camera()
	_clip = selected
	_gesture = clip
	_native_time = at
	_action_span = span
	last_error = ""
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _fit_motion_camera() -> void:
	# Authored Giant Ram grows only the elastic body. Widen its camera smoothly
	# with the real motion bounds while keeping the projected ground fixed.
	var bounds: AABB = _body.global_transform * _body.get_aabb()
	bounds = bounds.merge(_hat.global_transform * _hat.get_aabb())
	var aspect: float = float(size.x) / maxf(1.0, float(size.y))
	var half_width: float = maxf(absf(bounds.position.x), absf(bounds.end.x))
	var height: float = maxf(_frame_height, half_width * 2.0 * 1.08 / aspect)
	var center_ratio: float = _frame_center_y / _frame_height
	height = maxf(height, bounds.end.y * 1.04 / maxf(0.01, 0.5 + center_ratio))
	_camera.size = height
	var center_y: float = center_ratio * height
	_camera.position = Vector3(0.0, center_y, 8.0)
	_camera.look_at(Vector3(0.0, center_y, 0.0))


func animation_names() -> PackedStringArray:
	return _pirate.animation_names()


func clip_duration(clip: String) -> float:
	return _pirate.clip_duration(str(GAMEPLAY_CLIPS.get(clip, clip)))


func project_anchor(anchor_name: String) -> Vector2:
	if not _loaded or not _anchor_nodes.has(anchor_name):
		_fail("Load the Pirate Boss and choose an authored root, body, hat or face effect anchor.")
		return Vector2.ZERO
	var node: Node3D = _anchor_nodes[anchor_name]
	var local: Vector3 = _anchor_offsets[anchor_name]
	var point: Vector3 = node.global_transform * local
	return _camera.unproject_position(point)


func project_bone(anchor_name: String) -> Vector2:
	# Compatibility facade for callers that adopted semantic anchors. Pirate
	# has object animation, so former skeletal bone names are deliberately invalid.
	return project_anchor(anchor_name)


func snapshot() -> Dictionary:
	var sources: Dictionary = {}
	var points: Dictionary = {}
	if _loaded:
		for anchor: String in _anchor_nodes:
			var node: Node3D = _anchor_nodes[anchor]
			sources[anchor] = str(_model.get_path_to(node))
			var point: Vector2 = project_anchor(anchor)
			points[anchor] = [point.x, point.y]
	return {"loaded": _loaded, "model": MODEL, "clip": _clip, "gesture": _gesture,
		"time": _native_time, "duration": clip_duration(_clip), "action_duration": _action_span,
		"animations": animation_names(), "anchor_sources": sources, "anchors": points,
		"camera_height": _camera.size, "camera_center_y": _camera.position.y,
		"auto_advance": _pirate.auto_advance, "last_error": last_error}


func _fail(message: String) -> bool:
	last_error = message
	push_error(message)
	return false

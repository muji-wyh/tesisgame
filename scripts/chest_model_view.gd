extends SubViewport
## A transparent, continuously posed model surface for the shared chest view.
## The caller owns the clock, input, effects, sound, and reward state.

signal resolution_changed

const DESIGN_SIZE: float = 1024.0
const MIN_RESOLUTION: int = 512
const MAX_RESOLUTION: int = 1536
const IDLE_POSE_FPS: float = 15.0

static var _studio_sky: Sky

var _world := Node3D.new()
var _rig := Node3D.new()
var _camera := Camera3D.new()
var _interior_light := OmniLight3D.new()
var _model: Node3D
var _player: AnimationPlayer
var _clip: StringName = &""
var _clip_start: float = 0.0
var _clip_end: float = 0.0
var _parts: Array[Dictionary] = []
var _meshes: Array[MeshInstance3D] = []
var _closed_box := AABB()
var _motion_box := AABB()
var _design_closed := Rect2()
var _design_motion := Rect2()
var _cavity := Vector3.ZERO
var _seam: Array[Vector3] = []
var _active: bool = false
var _dirty: bool = true
var _pose_key: Array = []
var _idle_sample_key: Array = []
var _idle_light_strength: float = 0.0
var _open_amount: float = 0.0
var _pressure: float = 0.0
var _idle_time: float = 0.0
var _light_strength: float = 0.0
var _reduced_motion: bool = false
var _source_path: String = ""
var _max_resolution: int = 1024


func _init() -> void:
	name = "ChestModelViewport"
	size = Vector2i(MIN_RESOLUTION, MIN_RESOLUTION)
	transparent_bg = true
	own_world_3d = true
	gui_disable_input = true
	handle_input_locally = false
	physics_object_picking = false
	msaa_3d = Viewport.MSAA_2X
	positional_shadow_atlas_size = 512
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_world)
	_world.name = "Studio"
	_world.add_child(_rig)
	_rig.name = "ChestMotion"
	_world.add_child(_camera)
	_camera.name = "ChestCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.01
	_camera.far = 40.0
	_camera.current = true
	var studio := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#dce5f0")
	environment.ambient_light_energy = 0.62
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.sky = _get_studio_sky()
	studio.environment = environment
	_world.add_child(studio)
	_add_light("Key", Vector3(-42.0, -36.0, 0.0), Color("#fff3db"), 1.9, true)
	_add_light("Fill", Vector3(-20.0, 138.0, 0.0), Color("#bfd6ff"), 0.65, false)
	_add_light("Rim", Vector3(-32.0, 208.0, 0.0), Color("#fff2dd"), 1.0, false)
	_world.add_child(_interior_light)
	_interior_light.name = "TreasureLight"
	_interior_light.light_energy = 0.0
	_interior_light.omni_attenuation = 1.3
	_interior_light.shadow_enabled = false
	set_process(false)


static func _get_studio_sky() -> Sky:
	if _studio_sky == null:
		_studio_sky = Sky.new()
		_studio_sky.radiance_size = Sky.RADIANCE_SIZE_128
		_studio_sky.process_mode = Sky.PROCESS_MODE_QUALITY
		var material := ProceduralSkyMaterial.new()
		material.sky_top_color = Color("#899caf")
		material.sky_horizon_color = Color("#e8edf4")
		material.ground_bottom_color = Color("#555361")
		material.ground_horizon_color = Color("#d5cbbd")
		_studio_sky.sky_material = material
	return _studio_sky


func _add_light(label: String, angles: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var light := DirectionalLight3D.new()
	light.name = label
	light.rotation_degrees = angles
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadows
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 12.0
	# The shared reflection environment is static, independent of each studio.
	light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_world.add_child(light)


func configure(style: Dictionary) -> bool:
	var path: String = str(style.get("model", ""))
	if not path.begins_with("res://"):
		path = "res://" + path
	if not path.begins_with("res://assets/chests/") or path.contains("..") or path.contains("\\"):
		return false
	var resource := load(path) as PackedScene
	if resource == null:
		return false
	var candidate := resource.instantiate() as Node3D
	if candidate == null:
		return false
	if is_instance_valid(_model):
		_rig.remove_child(_model)
		_model.queue_free()
	_model = candidate
	_rig.add_child(_model)
	_source_path = path
	_max_resolution = clampi(int(style.get("max_resolution", 1024)), MIN_RESOLUTION, MAX_RESOLUTION)
	_rig.transform = Transform3D.IDENTITY
	_parts.clear()
	_meshes.clear()
	_player = null
	_clip = &""
	_pose_key.clear()
	_idle_sample_key.clear()
	_scan(_model)
	if _meshes.is_empty():
		return false
	_find_clip(str(style.get("open_animation", "Open")))
	if _player != null and not _clip.is_empty():
		var animation: Animation = _player.get_animation(_clip)
		_clip_start = clampf(float(style.get("open_start", 0.0)), 0.0, animation.length)
		_clip_end = clampf(float(style.get("open_end", animation.length)), _clip_start, animation.length)
		_sample_clip(0.0)
	for entry: Variant in style.get("model_parts", style.get("parts", [])):
		if entry is Dictionary:
			_add_part(entry)
	var has_mechanism: bool = not _clip.is_empty()
	for part in _parts:
		has_mechanism = has_mechanism or absf(float(part.angle)) > 0.01 or part.lift.length() > 0.01
	if not has_mechanism:
		return false
	_closed_box = _read_box(style.get("closed_bounds_3d", {}))
	if not _box_valid(_closed_box):
		_closed_box = _measure_model()
	_motion_box = _read_box(style.get("motion_bounds_3d", {}))
	if not _box_valid(_motion_box):
		_motion_box = _closed_box
		for index in range(13):
			_pose_mechanism(float(index) / 12.0, 0.0, 0.0, 0.0, false)
			_motion_box = _motion_box.merge(_measure_model())
	_pose_mechanism(0.0, 0.0, 0.0, 0.0, false)
	if not _box_valid(_motion_box):
		return false
	# This one envelope stays fixed through tension, release, and the open pose.
	# Source exporters supply skinned bounds; rigid fallback geometry is sampled.
	_frame_camera(_vector(style.get("camera_direction", []), Vector3(3.8, 2.7, 6.0)),
		maxf(1.04, float(style.get("camera_margin", 1.12))))
	_design_closed = _project_box(_closed_box)
	_design_motion = _project_box(_motion_box).grow(12.0)
	_cavity = _vector(style.get("cavity_3d", []),
		_closed_box.position + _closed_box.size * Vector3(0.5, 0.68, 0.53))
	_seam.clear()
	for point: Variant in style.get("seam_3d", []):
		_seam.append(_vector(point, _cavity))
	if _seam.is_empty():
		var half_width: float = _closed_box.size.x * 0.40
		_seam.assign([_cavity + Vector3(-half_width, 0, 0), _cavity,
			_cavity + Vector3(half_width, 0, 0)])
	_interior_light.position = _cavity
	_interior_light.omni_range = maxf(0.5, _closed_box.get_longest_axis_size() * 0.85)
	set_pose(0.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE, false)
	_dirty = true
	_request_render()
	return true


func _scan(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		_meshes.append(node)
		# Keep every authored albedo, normal, metallic, roughness, and UV map.
		# The studio changes illumination, never replaces source texture detail.
		for index in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(index)
			if material != null:
				node.set_surface_override_material(index, material.duplicate() as Material)
	if node is AnimationPlayer:
		node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		node.stop()
		if _player == null:
			_player = node
	for child in node.get_children():
		_scan(child)


func _find_clip(wanted: String) -> void:
	if _player == null:
		return
	for clip_name: StringName in _player.get_animation_list():
		var label: String = str(clip_name)
		var leaf: String = label.get_slice("/", label.get_slice_count("/") - 1)
		if label == wanted or leaf.to_lower() == wanted.to_lower():
			_clip = clip_name
			return


func _sample_clip(amount: float) -> void:
	if _player == null or _clip.is_empty():
		return
	# Manual seeking keeps all motion on ChestView's clock, including pause and
	# frame stalls. Imported animation completion cannot award treasure.
	if _player.current_animation != _clip:
		_player.play(_clip)
	_player.seek(lerpf(_clip_start, _clip_end, amount), true)
	_player.advance(0.0)


func _add_part(entry: Dictionary) -> void:
	var path: String = str(entry.get("node", ""))
	var node: Node = _model.get_node_or_null(NodePath(path)) if not path.is_empty() else null
	if node == null and not path.is_empty():
		node = _model.find_child(path, true, false)
	if not node is Node3D:
		return
	var part: Dictionary = {"node": node, "rest": node.transform,
		"role": str(entry.get("role", "lid")),
		"axis": _vector(entry.get("axis", []), Vector3.RIGHT).normalized(),
		"angle": float(entry.get("angle", 0.0)),
		"press_direction": float(entry.get("press_direction", -signf(float(entry.get("angle", 1.0))))),
		"lift": _vector(entry.get("lift", []), Vector3.ZERO),
		"bone": -1}
	if node is Skeleton3D and entry.has("bone"):
		var bone: int = node.find_bone(str(entry.bone))
		if bone < 0:
			return
		part.bone = bone
		part["bone_rotation"] = node.get_bone_pose_rotation(bone)
		part["bone_position"] = node.get_bone_pose_position(bone)
		part["bone_scale"] = node.get_bone_pose_scale(bone)
	_parts.append(part)


func set_pose(open_amount: float, pressure: float, pulse: float, idle_time: float,
		light_strength: float, light_color: Color, reduce: bool, performing: bool = true) -> void:
	if not is_instance_valid(_model):
		return
	_open_amount = clampf(open_amount, 0.0, 1.0) if is_finite(open_amount) else 0.0
	_pressure = 0.0 if reduce or not is_finite(pressure) else clampf(pressure, 0.0, 1.0)
	_idle_time = 0.0 if reduce or not is_finite(idle_time) else maxf(0.0, idle_time)
	_light_strength = clampf(light_strength, 0.0, 3.0) if is_finite(light_strength) else 0.0
	_reduced_motion = reduce
	var beat: float = 0.0 if reduce or not is_finite(pulse) else clampf(pulse, -1.0, 1.0)
	if performing:
		_idle_sample_key.clear()
	else:
		# Only the gentle model idle is sampled. Hold, release, cancellation,
		# input and the shared reward/effect timeline keep their full precision.
		var bucket: int = floori(_idle_time * IDLE_POSE_FPS)
		var sample_key: Array = [bucket, _open_amount, _pressure, beat, light_color,
			reduce, _light_strength > 0.0]
		if sample_key != _idle_sample_key:
			_idle_sample_key = sample_key
			_idle_light_strength = _light_strength
		_idle_time = float(bucket) / IDLE_POSE_FPS
		# Freeze the idle cavity glow within the same bucket as the geometry;
		# otherwise a tiny light change would request another full 3D render.
		_light_strength = _idle_light_strength
	var key: Array = [_open_amount, _pressure, beat, _idle_time, _light_strength, light_color, reduce]
	if key == _pose_key:
		return
	_pose_key = key
	_pose_mechanism(_open_amount, _pressure, beat, _idle_time, reduce)
	# Real three-dimensional yaw changes perspective and specular reflections.
	# The outer 2D view retains the shared planted body impulses and dragging.
	_rig.rotation = Vector3.ZERO if reduce else Vector3(
		sin(_idle_time * 0.67) * 0.006, sin(_idle_time * 0.48) * 0.026, 0.0)
	_interior_light.position = _rig.transform * _cavity
	set_interior_light(_light_strength, light_color)
	_dirty = true
	_request_render()


func _pose_mechanism(amount: float, pressure: float, pulse: float, clock: float, reduce: bool) -> void:
	# Restore all authored layers first. A source clip may omit a lock or
	# handle track; its additive tension must never accumulate across frames.
	for part in _parts:
		var target: Node3D = part.node
		if int(part.bone) >= 0:
			var skeleton: Skeleton3D = target
			skeleton.set_bone_pose_rotation(part.bone, part.bone_rotation)
			skeleton.set_bone_pose_position(part.bone, part.bone_position)
			skeleton.set_bone_pose_scale(part.bone, part.bone_scale)
		else:
			target.transform = part.rest
	_sample_clip(amount)
	for part in _parts:
		var role: String = part.role
		var angle: float = 0.0 if not _clip.is_empty() else float(part.angle) * amount
		var lift: Vector3 = Vector3.ZERO if not _clip.is_empty() else part.lift * amount
		if not reduce:
			if role == "lid":
				# Tension pushes into the closed stop. It must not reveal a cavity
				# or expose the reward before the shared mechanical release.
				angle += float(part.press_direction) * (pressure * 0.006 + absf(pulse) * 0.004) * (1.0 - amount)
				angle += sin(clock * 1.2) * 0.003 * amount
			elif role == "lock":
				angle += pulse * 0.14 + sin(clock * 1.8) * 0.012 * (1.0 - pressure)
			elif role == "handle":
				angle += pulse * 0.12 + sin(clock * 1.4) * 0.015
		var target: Node3D = part.node
		var rotation := Quaternion(part.axis, angle)
		if int(part.bone) >= 0:
			var skeleton: Skeleton3D = target
			var bone: int = part.bone
			var base_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone) if not _clip.is_empty() else part.bone_rotation
			var base_position: Vector3 = skeleton.get_bone_pose_position(bone) if not _clip.is_empty() else part.bone_position
			skeleton.set_bone_pose_rotation(bone, base_rotation * rotation)
			skeleton.set_bone_pose_position(bone, base_position + lift)
			if _clip.is_empty():
				skeleton.set_bone_pose_scale(bone, part.bone_scale)
		else:
			var base: Transform3D = target.transform if not _clip.is_empty() else part.rest
			target.transform = Transform3D(base.basis * Basis(rotation), base.origin + lift)


func set_interior_light(strength: float, color: Color) -> void:
	var energy: float = clampf(strength, 0.0, 3.0) if is_finite(strength) else 0.0
	if is_equal_approx(_interior_light.light_energy, energy * 1.5) and _interior_light.light_color == color:
		return
	_interior_light.light_energy = energy * 1.5
	_interior_light.light_color = color
	_dirty = true
	_request_render()


func set_display_size(physical_size: Vector2) -> void:
	# Input is the final device-pixel size, including canvas and device scale.
	# Quantization avoids reallocating the render target during a drag or kick.
	if not physical_size.is_finite():
		return
	var pixels: float = maxf(physical_size.x, physical_size.y)
	var resolution: int = clampi(ceili(pixels / 64.0) * 64, MIN_RESOLUTION, _max_resolution)
	if size == Vector2i(resolution, resolution):
		return
	size = Vector2i(resolution, resolution)
	_dirty = true
	resolution_changed.emit()
	_request_render()


func set_render_active(enabled: bool) -> void:
	if _active == enabled:
		return
	_active = enabled
	if not enabled:
		render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_dirty = true
		_request_render()


func _request_render() -> void:
	if _active and _dirty and is_instance_valid(_model):
		render_target_update_mode = SubViewport.UPDATE_ONCE
		_dirty = false


func design_bounds() -> Rect2:
	return _design_motion


func closed_bounds() -> Rect2:
	return _design_closed


func cavity_point() -> Vector2:
	# The 2D release effects and actual cavity light follow the same spatial
	# anchor while the model turns inside its fixed framing envelope.
	return _project_point(_rig.transform * _cavity)


func seam_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in _seam:
		result.append(_project_point(_rig.transform * point))
	return result


func snapshot() -> Dictionary:
	var mechanism: Array[Dictionary] = []
	for part in _parts:
		var node: Node3D = part.node
		var rotation: Quaternion = node.quaternion
		var position: Vector3 = node.position
		if int(part.bone) >= 0:
			var skeleton: Skeleton3D = node
			rotation = skeleton.get_bone_pose_rotation(part.bone)
			position = skeleton.get_bone_pose_position(part.bone)
		mechanism.append({"role": part.role, "rotation": rotation, "position": position})
	return {"source": _source_path, "resolution": size.x, "virtual_size": DESIGN_SIZE,
		"active": _active, "open_amount": _open_amount, "pressure": _pressure,
		"idle_time": _idle_time, "reduced_motion": _reduced_motion,
		"source_animation": str(_clip), "parts": mechanism, "mesh_count": _meshes.size(),
		"light_strength": _light_strength, "model_rotation": _rig.rotation}


func _frame_camera(direction: Vector3, margin: float) -> void:
	if direction.length_squared() < 0.1:
		direction = Vector3(3.8, 2.7, 6.0)
	var center: Vector3 = _motion_box.get_center()
	var extent: float = _motion_box.get_longest_axis_size()
	_camera.position = center + direction.normalized() * maxf(6.0, extent * 4.0)
	_camera.look_at(center, Vector3.UP)
	var camera_box := Rect2()
	for index in range(8):
		var point: Vector3 = _camera.transform.affine_inverse() * _motion_box.get_endpoint(index)
		var plane := Vector2(point.x, point.y)
		camera_box = Rect2(plane, Vector2.ZERO) if index == 0 else camera_box.expand(plane)
	_camera.size = maxf(camera_box.size.x, camera_box.size.y) * margin
	_camera.far = maxf(40.0, extent * 10.0)


func _project_point(point: Vector3) -> Vector2:
	# Use the stable virtual square, independent of current render resolution.
	var local: Vector3 = _camera.transform.affine_inverse() * point
	return Vector2(0.5 + local.x / _camera.size, 0.5 - local.y / _camera.size) * DESIGN_SIZE


func _project_box(box: AABB) -> Rect2:
	var result := Rect2()
	for index in range(8):
		var point: Vector2 = _project_point(box.get_endpoint(index))
		result = Rect2(point, Vector2.ZERO) if index == 0 else result.expand(point)
	return result


func _measure_model() -> AABB:
	var result := AABB()
	var first: bool = true
	for mesh in _meshes:
		var transform: Transform3D = _relative_transform(mesh)
		var box: AABB = mesh.get_aabb()
		for index in range(8):
			var point: Vector3 = transform * box.get_endpoint(index)
			result = AABB(point, Vector3.ZERO) if first else result.expand(point)
			first = false
	return result


func _relative_transform(node: Node3D) -> Transform3D:
	var transform: Transform3D = node.transform
	var ancestor: Node = node.get_parent()
	while ancestor != null and ancestor != _rig:
		if ancestor is Node3D:
			transform = ancestor.transform * transform
		ancestor = ancestor.get_parent()
	return transform


func _box_valid(box: AABB) -> bool:
	return box.position.is_finite() and box.size.is_finite() and box.size.x > 0.0 and box.size.y > 0.0 and box.size.z > 0.0


func _read_box(value: Variant) -> AABB:
	if not value is Dictionary:
		return AABB()
	var minimum: Vector3 = _vector(value.get("min", []), Vector3.ZERO)
	var maximum: Vector3 = _vector(value.get("max", []), Vector3.ZERO)
	return AABB(minimum, maximum - minimum)


func _vector(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value if value.is_finite() else fallback
	if not value is Array or value.size() != 3:
		return fallback
	for component: Variant in value:
		if not (component is float or component is int) or not is_finite(float(component)):
			return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

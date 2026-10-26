extends SubViewport
## A transparent, continuously posed model surface for the shared chest view.
## The caller owns the clock, input, effects, sound, and reward state.

signal resolution_changed

const DESIGN_SIZE: float = 1024.0
const MIN_RESOLUTION: int = 512
const MAX_RESOLUTION: int = 1536
const IDLE_POSE_FPS: float = 15.0
const Catalog = preload("res://scripts/chest_tier_catalog.gd")

static var _studio_sky: Sky
static var _atlas_shader: Shader
static var _atlas_double_sided_shader: Shader

var _world := Node3D.new()
var _rig := Node3D.new()
var _camera := Camera3D.new()
var _interior_light := OmniLight3D.new()
var _model: Node3D
var _base_frame: Node3D
var _fittings: Node3D
var _player: AnimationPlayer
var _clip: StringName = &""
var _clip_start: float = 0.0
var _clip_end: float = 0.0
var _parts: Array[Dictionary] = []
var _meshes: Array[MeshInstance3D] = []
var _base_meshes: Array[MeshInstance3D] = []
var _body_meshes: Array[MeshInstance3D] = []
var _body_triangles := PackedVector3Array()
var _body_box := AABB()
var _lid_motion_box := AABB()
var _decorations: Array[Dictionary] = []
var _tier: int = 0
var _preset_id: String = ""
var _available: bool = false
var _camera_direction := Vector3(3.8, 2.7, 6.0)
var _camera_margin: float = 1.12
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
var last_error: String = ""


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
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.sky = _get_studio_sky()
	studio.environment = environment
	_world.add_child(studio)
	_add_light("Key", Vector3(-42.0, -36.0, 0.0), Color("#fff3db"), 0.85, true)
	_add_light("Fill", Vector3(-20.0, 138.0, 0.0), Color("#bfd6ff"), 0.28, false)
	_add_light("Rim", Vector3(-32.0, 208.0, 0.0), Color("#fff2dd"), 0.40, false)
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
	_clear_model()
	var path: String = str(style.get("model", ""))
	if not path.begins_with("res://"):
		path = "res://" + path
	if not path.begins_with("res://assets/chests/") or path.contains("..") or path.contains("\\"):
		return _unavailable("Invalid acquired chest model path: " + path)
	if not ResourceLoader.exists(path, "PackedScene"):
		return _unavailable("Chest model is missing or has not been imported: " + path)
	var entries: Array = style.get("decorations", [])
	for entry: Variant in entries:
		if not entry is Dictionary:
			return _unavailable("Chest recipe contains an invalid source ornament")
		var ornament_path: String = str(entry.get("model", ""))
		if not ornament_path.begins_with("res://"):
			ornament_path = "res://" + ornament_path
		if not ornament_path.begins_with("res://assets/chests/catalog-cc0/") \
			or ornament_path.contains("..") or ornament_path.contains("\\") \
			or not ResourceLoader.exists(ornament_path, "PackedScene"):
			return _unavailable("Required source ornament is missing or unimported: " + ornament_path)
	var resource := load(path) as PackedScene
	if resource == null:
		return _unavailable("Unable to load acquired chest scene: " + path)
	var candidate := resource.instantiate() as Node3D
	if candidate == null:
		return _unavailable("Acquired chest scene has no 3D root: " + path)
	_base_frame = Node3D.new()
	_base_frame.name = "SourceFrame"
	_rig.add_child(_base_frame)
	_model = candidate
	_base_frame.add_child(_model)
	_source_path = path
	_tier = int(style.get("tier", 0))
	_preset_id = str(style.get("preset_id", ""))
	_max_resolution = clampi(int(style.get("max_resolution", 1024)), MIN_RESOLUTION, MAX_RESOLUTION)
	_rig.transform = Transform3D.IDENTITY
	var profile: Dictionary = style.get("material_profile", {})
	_scan(_model, profile, style.get("atlas_trim", {}))
	if _meshes.is_empty():
		return _unavailable("Acquired chest has no renderable meshes: " + path)
	_base_meshes.assign(_meshes)
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
		return _unavailable("Acquired chest has no real lid clip or hinge: " + path)
	if bool(style.get("normalize_model", false)):
		if not _normalize_base(style):
			return _unavailable("Acquired chest has no finite volumetric base: " + path)
	for mesh in _base_meshes:
		if not _is_lid_mesh(mesh):
			_body_meshes.append(mesh)
	_body_box = _measure_meshes(_body_meshes)
	if not _box_valid(_body_box):
		return _unavailable("Acquired chest has no separate body panel geometry: " + path)
	var source_frame: Transform3D = _base_frame.transform
	_cavity = source_frame * _vector(style.get("cavity_3d", []), _source_cavity())
	_seam.clear()
	for point: Variant in style.get("seam_3d", []):
		_seam.append(source_frame * _vector(point, source_frame.affine_inverse() * _cavity))
	if _seam.is_empty():
		var half_width: float = _body_box.size.x * 0.40
		_seam.assign([_cavity + Vector3(-half_width, 0, _body_box.size.z * 0.42),
			_cavity + Vector3(half_width, 0, _body_box.size.z * 0.42)])
	_fittings = Node3D.new()
	_fittings.name = "BodyFittings"
	_rig.add_child(_fittings)
	if not entries.is_empty():
		_measure_lid_motion()
		_build_body_triangles()
		for entry: Variant in entries:
			if not entry is Dictionary or not _add_decoration(entry, profile, entries):
				return _unavailable("Unable to attach required source ornament for " + _preset_id)
		_body_triangles.clear()
	_closed_box = _read_box(style.get("closed_bounds_3d", {}))
	if _tier > 0 or not _box_valid(_closed_box):
		_closed_box = _measure_model()
	_motion_box = _read_box(style.get("motion_bounds_3d", {}))
	if _box_valid(_motion_box) and bool(style.get("normalize_model", false)):
		_motion_box = source_frame * _motion_box
	_motion_box = _motion_box.merge(_closed_box) if _box_valid(_motion_box) else _closed_box
	for index in range(13):
		_pose_mechanism(float(index) / 12.0, 0.0, 0.0, 0.0, false)
		_motion_box = _motion_box.merge(_measure_model())
	_pose_mechanism(0.0, 0.0, 0.0, 0.0, false)
	if _tier > 0:
		_motion_box = _motion_box.merge(_turn_envelope(_closed_box, 0.24))
	if not _box_valid(_motion_box):
		return _unavailable("Acquired chest has invalid measured motion bounds: " + path)
	# This one envelope stays fixed through tension, release, and the open pose.
	# Source exporters supply skinned bounds; rigid fallback geometry is sampled.
	_camera_direction = _vector(style.get("camera_direction", []), Vector3(3.8, 2.7, 6.0))
	_camera_margin = maxf(1.04, float(style.get("camera_margin", 1.12)))
	_frame_camera(_camera_direction, _camera_margin)
	_design_closed = _project_box(_closed_box)
	_design_motion = _project_box(_motion_box).grow(12.0)
	_interior_light.position = _cavity
	_interior_light.omni_range = maxf(0.5, _closed_box.get_longest_axis_size() * 0.85)
	_available = true
	set_pose(0.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE, false)
	_dirty = true
	_request_render()
	return true


func _scan(node: Node, profile: Dictionary = {}, atlas: Dictionary = {}, role: String = "") -> void:
	if node is MeshInstance3D and node.mesh != null:
		_meshes.append(node)
		# Every instance owns its finish. Atlas adaptations mask verified metal
		# regions and keep the original source texture, wood shading and UVs.
		for index in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(index)
			if material != null:
				node.set_surface_override_material(index, _styled_material(material, profile, atlas, role))
	if node is AnimationPlayer:
		node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		node.stop()
		if _player == null:
			_player = node
	for child in node.get_children():
		_scan(child, profile, atlas, role)


func _clear_model() -> void:
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(_base_frame):
		_base_frame.free()
	if is_instance_valid(_fittings):
		_fittings.free()
	_base_frame = null
	_fittings = null
	_model = null
	_player = null
	_parts.clear()
	_meshes.clear()
	_base_meshes.clear()
	_body_meshes.clear()
	_body_triangles.clear()
	_decorations.clear()
	_clip = &""
	_clip_start = 0.0
	_clip_end = 0.0
	_source_path = ""
	_tier = 0
	_preset_id = ""
	_available = false
	_closed_box = AABB()
	_motion_box = AABB()
	_body_box = AABB()
	_lid_motion_box = AABB()
	_design_closed = Rect2()
	_design_motion = Rect2()
	_cavity = Vector3.ZERO
	_seam.clear()
	_pose_key.clear()
	_idle_sample_key.clear()
	_rig.transform = Transform3D.IDENTITY
	_interior_light.light_energy = 0.0
	_open_amount = 0.0
	_pressure = 0.0
	_idle_time = 0.0
	_light_strength = 0.0
	_dirty = true
	last_error = ""


func _unavailable(message: String) -> bool:
	_clear_model()
	last_error = message
	return false


func _normalize_base(style: Dictionary) -> bool:
	_base_frame.rotation_degrees = _vector(style.get("source_rotation_degrees", []), Vector3.ZERO)
	var box: AABB = _measure_meshes(_base_meshes)
	if not _box_valid(box):
		return false
	_base_frame.scale = Vector3.ONE * (2.0 / box.size.x)
	box = _measure_meshes(_base_meshes)
	_base_frame.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return true


func _is_lid_mesh(mesh: MeshInstance3D) -> bool:
	for part in _parts:
		var node: Node = part.node
		if part.role == "lid" and int(part.bone) < 0 and (node == mesh or node.is_ancestor_of(mesh)):
			return true
	return false


func _source_cavity() -> Vector3:
	var cavity: Vector3 = _body_box.position + _body_box.size * Vector3(0.5, 0.72, 0.5)
	for part in _parts:
		if part.role == "lid" and int(part.bone) < 0:
			cavity.y = _relative_transform(part.node).origin.y
			break
	return _base_frame.transform.affine_inverse() * cavity


func _build_body_triangles() -> void:
	for mesh in _body_meshes:
		var transform: Transform3D = _relative_transform(mesh)
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for vertex in vertices:
					_body_triangles.append(transform * vertex)
			else:
				for index in indices:
					_body_triangles.append(transform * vertices[index])


func _measure_lid_motion() -> void:
	var meshes: Array[MeshInstance3D] = []
	for mesh in _base_meshes:
		if _is_lid_mesh(mesh):
			meshes.append(mesh)
	for index in range(33):
		_pose_mechanism(float(index) / 32.0, 0.0, 0.0, 0.0, true)
		var box: AABB = _measure_meshes(meshes)
		_lid_motion_box = box if index == 0 else _lid_motion_box.merge(box)
	_pose_mechanism(0.0, 0.0, 0.0, 0.0, true)


func _body_surface(center: Vector3, normal: Vector3) -> Variant:
	var ray: Vector3 = center + normal * 8.0
	var nearest: Variant = null
	var distance: float = INF
	for index in range(0, _body_triangles.size() - 2, 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(ray, -normal,
			_body_triangles[index], _body_triangles[index + 1], _body_triangles[index + 2])
		if hit is Vector3:
			var squared: float = ray.distance_squared_to(hit)
			if squared < distance:
				distance = squared
				nearest = hit
	return nearest


func _add_decoration(entry: Dictionary, profile: Dictionary, entries: Array) -> bool:
	var path: String = str(entry.get("model", ""))
	if not path.begins_with("res://"):
		path = "res://" + path
	if not path.begins_with("res://assets/chests/catalog-cc0/") or path.contains("..") \
		or path.contains("\\") or not ResourceLoader.exists(path, "PackedScene"):
		last_error = "Required source ornament is missing or unimported: " + path
		return false
	var resource := load(path) as PackedScene
	if resource == null:
		return false
	var ornament := resource.instantiate() as Node3D
	if ornament == null:
		return false
	var slot: String = str(entry.get("slot", ""))
	var mount := Node3D.new()
	mount.name = "BodyFitting_" + slot
	_fittings.add_child(mount)
	mount.add_child(ornament)
	var first_mesh: int = _meshes.size()
	var gem: bool = path.ends_with("/jewel.glb") or path.ends_with("/detail-crystal.glb")
	var atlas: Dictionary = Catalog.atlas_regions(path)
	if gem:
		atlas = {"regions": [[0.0, 0.0, 1.0, 1.0]],
			"reference": "#5f74ca" if path.ends_with("/jewel.glb") else "#cc77ec"}
	_scan(ornament, profile, atlas, "gemstone" if gem else "ornament_metal")
	var meshes: Array[MeshInstance3D] = []
	for index in range(first_mesh, _meshes.size()):
		meshes.append(_meshes[index])
	var raw_box: AABB = _measure_meshes(meshes)
	if not _box_valid(raw_box):
		return false
	ornament.position -= raw_box.get_center()
	mount.rotation_degrees = _vector(entry.get("rotation_degrees", []), Vector3.ZERO)
	mount.scale = Vector3.ONE * (2.0 * float(entry.get("scale", 0.0)) / raw_box.get_longest_axis_size())
	var box: AABB = _measure_meshes(meshes)
	# The rear lip can dip below its closed floor during a hinge rotation.
	# Fit below the complete swept source lid, not just its initial pose.
	var ceiling: float = minf(_cavity.y - 0.025, _lid_motion_box.position.y - 0.015)
	var floor_y: float = _body_box.position.y + 0.015
	var panel_height: float = ceiling - floor_y
	if panel_height <= 0.02:
		return false
	var front: bool = slot not in ["left", "right"]
	var has_flanks: bool = false
	for other: Dictionary in entries:
		has_flanks = has_flanks or str(other.get("slot", "")) in ["front-left", "front-right"]
	var panel_width: float = _body_box.size.x * (0.28 if has_flanks else 0.76)
	if not front:
		panel_width = _body_box.size.z * 0.65
	var fit: float = minf(1.0, panel_height * 0.84 / box.size.y)
	fit = minf(fit, panel_width / (box.size.x if front else box.size.z))
	mount.scale *= fit
	box = _measure_meshes(meshes)
	var center: Vector3 = _body_box.get_center()
	center.y = (floor_y + ceiling) * 0.5
	var normal := Vector3.BACK
	match slot:
		"front-left":
			center.x -= _body_box.size.x * 0.32
		"front-right":
			center.x += _body_box.size.x * 0.32
		"left":
			normal = Vector3.LEFT
		"right":
			normal = Vector3.RIGHT
		"front":
			pass
		_:
			return false
	var surface: Variant = _body_surface(center, normal)
	if not surface is Vector3:
		return false
	var support: float = 0.0
	for corner in range(8):
		support = maxf(support, -normal.dot(box.get_endpoint(corner)))
	mount.position = surface + normal * (support + 0.012)
	box = _measure_meshes(meshes)
	_decorations.append({"source": path, "slot": slot, "attachment_target": "body",
		"mesh_count": meshes.size(), "bounds_3d": box, "panel_point": surface,
		"source_scale": float(entry.get("scale", 0.0)), "clearance_scale": fit})
	return true


func _styled_material(source: Material, profile: Dictionary, atlas: Dictionary, role: String) -> Material:
	var result: Material = source.duplicate() as Material
	var base: BaseMaterial3D = source as BaseMaterial3D
	if profile.is_empty() or base == null:
		return result
	var roles: Dictionary = profile.get("roles", {})
	var selected: String = role if not role.is_empty() else _private_material_role(source.resource_name)
	if not atlas.is_empty() and base.albedo_texture != null:
		if selected.is_empty():
			selected = "trim"
		var atlas_finish: Dictionary = roles.get(selected, {})
		if not atlas_finish.is_empty():
			return _atlas_material(base, atlas, atlas_finish)
	if selected.is_empty() or not roles.get(selected) is Dictionary:
		return result
	var finish: Dictionary = roles[selected]
	var material: BaseMaterial3D = result as BaseMaterial3D
	material.albedo_color = Color(str(finish.get("base_color", "#ffffff")))
	material.metallic = clampf(float(finish.get("metallic", material.metallic)), 0.0, 1.0)
	material.roughness = clampf(float(finish.get("roughness", material.roughness)), 0.0, 1.0)
	return material


func _private_material_role(label: String) -> String:
	if label == "Moonstone_Gem":
		return "gemstone"
	if label.begins_with("meadow-explorer_"):
		if label.ends_with("_M_Yellow"):
			return "trim"
		if label.ends_with("_M_Gray"):
			return "shell"
	if label.begins_with("harvest-keepsake_") \
		and (label.ends_with("_Chest_4_3") or label.ends_with("_Chest_4_1")):
		return "trim"
	if label.begins_with("lagoon-pearl_") and label.ends_with("_Chest_1_1"):
		return "trim"
	if label.begins_with("strawberry-bonbon_"):
		if label.ends_with("_Chest_2_1"):
			return "trim"
		if label.ends_with("_Chest_2_3"):
			return "shell"
	return ""


func _atlas_material(source: BaseMaterial3D, atlas: Dictionary, finish: Dictionary) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.resource_name = source.resource_name + "_TierRegionAdaptation"
	result.shader = _get_atlas_shader(source.cull_mode == BaseMaterial3D.CULL_DISABLED)
	result.set_shader_parameter("source_texture", source.albedo_texture)
	result.set_shader_parameter("source_tint", source.albedo_color)
	result.set_shader_parameter("source_metallic", source.metallic)
	result.set_shader_parameter("source_roughness", source.roughness)
	result.set_shader_parameter("reference_color", Color(str(atlas.get("reference", "#ffffff"))))
	result.set_shader_parameter("finish_color", Color(str(finish.get("base_color", "#ffffff"))))
	result.set_shader_parameter("finish_metallic", clampf(float(finish.get("metallic", 0.0)), 0.0, 1.0))
	result.set_shader_parameter("finish_roughness", clampf(float(finish.get("roughness", 0.5)), 0.0, 1.0))
	var regions: Array = atlas.get("regions", [])
	for index in range(4):
		var region := Vector4(-2, -2, -1, -1)
		if index < regions.size() and regions[index] is Array and regions[index].size() == 4:
			region = Vector4(float(regions[index][0]), float(regions[index][1]),
				float(regions[index][2]), float(regions[index][3]))
		result.set_shader_parameter("region_%d" % index, region)
	return result


static func _get_atlas_shader(double_sided: bool) -> Shader:
	var cached: Shader = _atlas_double_sided_shader if double_sided else _atlas_shader
	if cached != null:
		return cached
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode %s;
uniform sampler2D source_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform vec4 reference_color : source_color = vec4(1.0);
uniform vec4 finish_color : source_color = vec4(1.0);
uniform float source_metallic = 0.0;
uniform float source_roughness = 0.8;
uniform float finish_metallic = 0.0;
uniform float finish_roughness = 0.5;
uniform vec4 region_0;
uniform vec4 region_1;
uniform vec4 region_2;
uniform vec4 region_3;
float region_mask(vec2 uv, vec4 rect) {
	return step(rect.x, uv.x) * step(rect.y, uv.y) * step(uv.x, rect.z) * step(uv.y, rect.w);
}
void fragment() {
	vec3 original = texture(source_texture, UV).rgb * source_tint.rgb;
	float mask = clamp(region_mask(UV, region_0) + region_mask(UV, region_1)
		+ region_mask(UV, region_2) + region_mask(UV, region_3), 0.0, 1.0);
	vec3 luma = vec3(0.2126, 0.7152, 0.0722);
	float shading = dot(original, luma) / max(0.025, dot(reference_color.rgb, luma));
	ALBEDO = mix(original, finish_color.rgb * clamp(shading, 0.12, 1.55), mask);
	METALLIC = mix(source_metallic, finish_metallic, mask);
	ROUGHNESS = mix(source_roughness, finish_roughness, mask);
}
""" % ("cull_disabled" if double_sided else "cull_back")
	if double_sided:
		_atlas_double_sided_shader = shader
	else:
		_atlas_shader = shader
	return shader


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


func set_closed_turn(yaw: float, pitch: float = 0.0) -> void:
	if not is_instance_valid(_model) or not is_finite(yaw) or not is_finite(pitch):
		return
	# Reward turns use the acquired closed geometry, independently of the
	# opening mechanism. The caller supplies the entire deterministic clock.
	var key: Array = ["closed-turn", yaw, pitch]
	if key == _pose_key:
		return
	_pose_key = key
	_idle_sample_key.clear()
	_open_amount = 0.0
	_pressure = 0.0
	_idle_time = 0.0
	_light_strength = 0.0
	_reduced_motion = false
	_pose_mechanism(0.0, 0.0, 0.0, 0.0, true)
	_rig.rotation = Vector3(pitch, yaw, 0.0)
	_interior_light.position = _rig.transform * _cavity
	set_interior_light(0.0, Color.WHITE)
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
				var compression: float = (pressure * 0.006 + absf(pulse) * 0.004) * (1.0 - amount)
				if is_zero_approx(float(part.angle)) and part.lift.length() > 0.01:
					lift -= part.lift.normalized() * compression
				else:
					angle += float(part.press_direction) * compression
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
	if _active and _dirty and _available and is_instance_valid(_model):
		render_target_update_mode = SubViewport.UPDATE_ONCE
		_dirty = false


func design_bounds() -> Rect2:
	return _design_motion


func closed_bounds() -> Rect2:
	return _design_closed


func closed_box() -> AABB:
	return _closed_box


func frame_closed_turn(pitch_limit: float = 0.24) -> bool:
	if not _available or not _box_valid(_closed_box):
		return false
	if not is_finite(pitch_limit) or pitch_limit < 0.0 or pitch_limit > PI * 0.25:
		last_error = "Invalid closed chest pitch envelope"
		return false
	_motion_box = _turn_envelope(_closed_box, pitch_limit)
	_frame_camera(_camera_direction, _camera_margin)
	_design_closed = _project_box(_closed_box)
	_design_motion = _project_box(_motion_box).grow(12.0)
	_dirty = true
	_request_render()
	return true


func _turn_envelope(box: AABB, pitch_limit: float) -> AABB:
	var half_x: float = maxf(absf(box.position.x), absf(box.end.x))
	var half_z: float = maxf(absf(box.position.z), absf(box.end.z))
	var half_y: float = maxf(absf(box.position.y), absf(box.end.y))
	var pitch_z: float = half_y * sin(pitch_limit)
	var pitch_y: float = half_z * sin(pitch_limit)
	var radius: float = Vector2(half_x, half_z + pitch_z).length()
	return AABB(Vector3(-radius, box.position.y - pitch_y, -radius),
		Vector3(radius * 2.0, box.size.y + pitch_y * 2.0, radius * 2.0))


func closed_turn_bounds() -> Rect2:
	var result := Rect2()
	for index in range(8):
		var point: Vector2 = _project_point(_rig.transform * _closed_box.get_endpoint(index))
		result = Rect2(point, Vector2.ZERO) if index == 0 else result.expand(point)
	return result


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
		"available": _available, "chest_tier": _tier, "preset_id": _preset_id,
		"closed_box": _closed_box, "motion_box": _motion_box, "body_box": _body_box,
		"lid_motion_box": _lid_motion_box, "last_error": last_error,
		"decorations": _decorations.duplicate(true),
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
	return _measure_meshes(_meshes)


func _measure_meshes(meshes: Array[MeshInstance3D]) -> AABB:
	var result := AABB()
	var first: bool = true
	for mesh in meshes:
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

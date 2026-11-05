extends SceneTree

const Model = preload("res://scripts/chest_model_view.gd")
const Chest = preload("res://scripts/chest_view.gd")
const RewardModel = preload("res://scripts/chest_reward_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const CATALOG_PATH: String = "res://scripts/chest_tier_catalog.gd"
const PRESETS_PATH: String = "res://assets/chests/catalog/gameplay-chests.json"
const SOURCES_PATH: String = "res://assets/chests/catalog/atelier.json"
const MANIFEST_PATH: String = "res://assets/chests/catalog/gameplay-chests.json"
const CAPTURE_PATH: String = "res://build/qa/chest-ninety-nine-tiers"
const THEMES: Array[String] = [
	"spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"
]

var checks: int = 0
var failures: int = 0
var _catalog: Script
var _manifest: Dictionary = {}
var _recipes: Array = []
var _source_catalog: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	_manifest = _read_json(MANIFEST_PATH)
	var presets: Dictionary = _read_json(PRESETS_PATH)
	_source_catalog = _read_json(SOURCES_PATH)
	_recipes = presets.get("tiers", [])
	check(_recipes.size() == 99, "Acquired Atelier materials define exactly ninety-nine gameplay tiers")
	_check_entry_points()
	if _load_catalog():
		_check_catalog(presets)
		for tier in range(1, int(_manifest.get("material_count", 0)) + 1):
			_check_tier_model(tier)
		_check_tier_model(99)
		_check_legacy_themes()
		_check_exact_tier_reconfiguration()
		_check_missing_geometry()
	await _check_reward_pool()
	if OS.get_cmdline_user_args().has("--capture") and _catalog != null and failures == 0:
		await _capture_contact_sheets()
	print("Ninety-nine-tier Atelier chest models: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		check(false, "Required catalog exists: " + path)
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(value is Dictionary, "Required catalog parses as an object: " + path)
	return value if value is Dictionary else {}


func _check_entry_points() -> void:
	var chest := Chest.new()
	root.add_child(chest)
	check(chest.has_method("configure_tier"),
		"ChestView exposes configure_tier without requiring an existing legacy theme")
	chest.free()


func _load_catalog() -> bool:
	check(FileAccess.file_exists(CATALOG_PATH),
		"ChestTierCatalog exists before any tier model is requested")
	if not FileAccess.file_exists(CATALOG_PATH):
		return false
	_catalog = load(CATALOG_PATH) as Script
	check(_catalog != null and _catalog.can_instantiate(), "ChestTierCatalog is a loadable script")
	if _catalog == null or not _catalog.can_instantiate():
		_catalog = null
		return false
	for method: String in ["preset", "style", "theme_tier", "error"]:
		check(_catalog.has_method(method), "ChestTierCatalog exposes " + method)
		if not _catalog.has_method(method):
			_catalog = null
			return false
	return true


func _preset(tier: int) -> Dictionary:
	var value: Variant = _catalog.call("preset", tier)
	check(value is Dictionary, "Tier %d preset returns a dictionary" % tier)
	return value if value is Dictionary else {}


func _style(tier: int) -> Dictionary:
	var value: Variant = _catalog.call("style", tier, _manifest)
	check(value is Dictionary, "Tier %d style returns a dictionary" % tier)
	return value if value is Dictionary else {}


func _check_catalog(presets: Dictionary) -> void:
	var constants: Dictionary = _catalog.get_script_constant_map()
	check(int(constants.get("MAX_TIER", 0)) == 99, "The rendering catalog caps gameplay tiers at ninety-nine")
	var ranking: Dictionary = _read_json("res://assets/chests/catalog/chest-levels.json")
	var ranked_models: Array[Dictionary] = []
	var ranked_ids: Dictionary = {}
	for row: Dictionary in ranking.get("levels", []):
		if str(row.get("asset_type", "")) == "model" and not ranked_ids.has(str(row.asset_id)):
			ranked_ids[str(row.asset_id)] = true
			ranked_models.append(row)
	check(ranked_models.size() == 28 and int(presets.get("material_count", 0)) == ranked_models.size(),
		"The replacement uses all twenty-eight retained ranked Atelier models")
	var ids: Dictionary = {}
	var models: Dictionary = {}
	for tier in range(1, 100):
		var preset: Dictionary = _preset(tier)
		var style: Dictionary = _style(tier)
		if preset.is_empty() or style.is_empty() or ranked_models.is_empty():
			check(false, "Tier %d has an explicit preset and renderable style" % tier)
			continue
		var selected: Dictionary = ranked_models[mini(tier - 1, ranked_models.size() - 1)]
		check(int(preset.get("level", 0)) == tier and int(style.get("tier", 0)) == tier,
			"Tier %d keeps its exact contiguous gameplay level" % tier)
		check(str(preset.get("id", "")).begins_with("tier-%02d-" % tier)
			and style.get("preset_id", "") == preset.get("id"),
			"Tier %d keeps its independent tier identity through rendering" % tier)
		ids[preset.get("id", "")] = true
		var source: String = str(preset.get("base_model", ""))
		check(source == str(selected.model) and _resource_path(str(style.get("model", ""))) == _resource_path(source)
			and preset.get("base_source_id", "") == selected.asset_id,
			"Tier %d selects its ordered Atelier material and repeats only the final source after material twenty-eight" % tier)
		check(source.begins_with("assets/chests/models/atelier/") and _known_model(source)
			and FileAccess.file_exists(_resource_path(source)),
			"Tier %d uses an acquired Atelier model without selecting an old CC0, licensed base or sprite family" % tier)
		models[source] = true
		check(style.get("decorations", []).is_empty() and preset.get("decorations", []).is_empty(),
			"Tier %d preserves its already fitted source artwork without adding old modular ornaments" % tier)
		var acquired: Dictionary = _acquired_model(source)
		check(not acquired.is_empty() and style.get("model_parts", []) == acquired.get("style", {}).get("model_parts", [])
			and style.get("open_animation", "") == "Open" and acquired.get("animations", []).any(
				func(clip: Dictionary) -> bool: return str(clip.name) == "Open"),
			"Tier %d preserves its actual authored Atelier opening and model parts" % tier)
		check(style.get("state_asset_id", "") == selected.asset_id and not str(style.get("state_scene", "")).is_empty(),
			"Tier %d binds the reusable source state scene to its actual Atelier identity" % tier)
	check(ids.size() == 99 and models.size() == ranked_models.size(),
		"Ninety-nine independent tiers use every retained Atelier model, with the final material continuing through Lv99")
	check(_preset(0).is_empty() and not str(_catalog.call("error")).is_empty(),
		"Tier zero returns an explicit catalog validation error without engine noise")
	check(_preset(100).is_empty() and not str(_catalog.call("error")).is_empty()
		and _style(100).is_empty() and not str(_catalog.call("error")).is_empty(),
		"Out-of-range tiers fail explicitly instead of wrapping or silently clamping")
	var first: Dictionary = _preset(2)
	check(str(_catalog.call("error")).is_empty(),
		"A valid catalog lookup clears its preceding input validation error")
	var original: Dictionary = first.duplicate(true)
	first["id"] = "mutated"
	check(_preset(2) == original, "Callers cannot mutate the cached source recipe")
	var styled: Dictionary = _style(99)
	var original_style: Dictionary = styled.duplicate(true)
	var parts: Array = styled.get("model_parts", [])
	if not parts.is_empty():
		parts[0]["node"] = "mutated"
	check(_style(99) == original_style, "Callers cannot mutate the cached nested model-part recipe")


func _acquired_model(path: String) -> Dictionary:
	for entry: Dictionary in _source_catalog.get("models", []):
		if entry.get("model", "") == path:
			return entry
	return {}


func _known_model(path: String) -> bool:
	return not _acquired_model(path).is_empty()


func _resource_path(path: String) -> String:
	return path if path.begins_with("res://") else "res://" + path


func _check_tier_model(tier: int) -> void:
	var style: Dictionary = _style(tier)
	if style.is_empty():
		return
	var model := Model.new()
	root.add_child(model)
	model.set_render_active(false)
	if not model.configure(style):
		check(false, "Tier %d configures actual imported geometry and a continuous opening mechanism" % tier)
		model.free()
		return
	var rig: Node3D = model.get("_rig") as Node3D
	var meshes: Array[MeshInstance3D] = []
	meshes.assign(model.get("_meshes"))
	var state: Dictionary = model.snapshot()
	check(not meshes.is_empty() and int(state.get("mesh_count", 0)) == meshes.size(),
		"Tier %d measures its actual shell surfaces independently from hidden treasure and magic" % tier)
	var genuine: bool = true
	for mesh in meshes:
		genuine = genuine and mesh.mesh is ArrayMesh and _has_spatial_volume(mesh.mesh)
	check(genuine, "Tier %d has genuine volumetric source meshes, never a quad or primitive substitute" % tier)
	var source: Node3D = model.get("_model") as Node3D
	check(source != null and source.find_children("*", "Sprite3D", true, false).is_empty()
		and source.find_children("*", "SpriteBase3D", true, false).is_empty(),
		"Tier %d does not hide a camera-facing card among its source geometry" % tier)
	check(int(state.get("composer_source_instances", 0)) == 1
		and str(state.get("content_source", "")) == str(style.state_asset_id)
		and str(state.get("content_state", "")) == "closed",
		"Tier %d owns one exact source state composition and begins with its contents hidden" % tier)
	var closed_box: AABB = model.get("_closed_box")
	var motion_box: AABB = model.get("_motion_box")
	check(_volume_valid(closed_box) and _volume_valid(motion_box)
		and motion_box.grow(0.001).encloses(closed_box),
		"Tier %d measures finite closed and complete-motion volumes" % tier)
	var base_roots: Array[Node3D] = []
	_find_source_roots(rig, _resource_path(str(style.model)), base_roots)
	check(base_roots.size() == 1, "Tier %d retains one identifiable acquired base instance" % tier)
	if base_roots.size() == 1:
		var base_meshes: Array[MeshInstance3D] = []
		_collect_meshes(base_roots[0], base_meshes)
		var base_box: AABB = _bounds(base_meshes, rig)
		check(_volume_valid(base_box) and base_box.size.x >= 1.5 and base_box.size.x <= 3.0
			and absf(base_box.position.y) < 0.005,
			"Tier %d keeps its grounded +Y-up acquired body and fitted dimensional artwork without flattening its silhouette" % tier)
		_check_source_materials(tier, base_roots[0], style)
	_check_opening_and_camera(tier, model, style)
	_check_runtime_contents(tier, model, style)
	model.free()


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)


func _find_source_roots(node: Node, path: String, result: Array[Node3D]) -> void:
	if node is Node3D and node.scene_file_path == path:
		result.append(node)
	for child in node.get_children():
		_find_source_roots(child, path, result)


func _has_spatial_volume(mesh: Mesh) -> bool:
	var box: AABB = mesh.get_aabb()
	if not _volume_valid(box):
		return false
	var vertices := PackedVector3Array()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
	if vertices.size() < 4:
		return false
	var origin: Vector3 = vertices[0]
	var axis := Vector3.ZERO
	for vertex in vertices:
		var offset: Vector3 = vertex - origin
		if offset.length_squared() > axis.length_squared():
			axis = offset
	if axis.length_squared() < 0.000000001:
		return false
	var normal := Vector3.ZERO
	for vertex in vertices:
		var cross: Vector3 = axis.cross(vertex - origin)
		if cross.length_squared() > normal.length_squared():
			normal = cross
	if normal.length_squared() < 0.000000000001:
		return false
	normal = normal.normalized()
	for vertex in vertices:
		if absf(normal.dot(vertex - origin)) > box.get_longest_axis_size() * 0.00001:
			return true
	return false


func _volume_valid(box: AABB) -> bool:
	return box.position.is_finite() and box.size.is_finite() \
		and box.size.x > 0.000001 and box.size.y > 0.000001 and box.size.z > 0.000001


func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != ancestor:
		if parent is Node3D:
			result = parent.transform * result
		parent = parent.get_parent()
	return result


func _bounds(meshes: Array[MeshInstance3D], ancestor: Node3D) -> AABB:
	var result := AABB()
	var first: bool = true
	for mesh in meshes:
		var transform: Transform3D = _relative_transform(mesh, ancestor)
		for index in range(8):
			var point: Vector3 = transform * mesh.get_aabb().get_endpoint(index)
			result = AABB(point, Vector3.ZERO) if first else result.expand(point)
			first = false
	return result


func _project_geometry_bounds(model: SubViewport) -> Rect2:
	var camera: Camera3D = model.get("_camera") as Camera3D
	var rig: Node3D = model.get("_rig") as Node3D
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(rig, meshes)
	var view: Transform3D = camera.transform.affine_inverse() * rig.transform
	var result := Rect2()
	var first: bool = true
	for mesh in meshes:
		if not mesh.is_visible_in_tree():
			continue
		var transform: Transform3D = view * _relative_transform(mesh, rig)
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point: Vector3 = transform * vertex
				var screen := Vector2(0.5 + point.x / camera.size, 0.5 - point.y / camera.size) * Model.DESIGN_SIZE
				result = Rect2(screen, Vector2.ZERO) if first else result.expand(screen)
				first = false
	return result


func _check_runtime_contents(tier: int, model: SubViewport, style: Dictionary) -> void:
	model.call("set_pose", 0.45, 0.0, 0.0, 0.0, 0.0, Color.WHITE, false)
	var source: Node3D = model.get("_model") as Node3D
	var pose: Array = model.call("snapshot").get("parts", []).duplicate(true)
	for content_state: String in ["closed", "open", "treasure", "magic"]:
		check(model.call("set_contents", content_state, 0.25, 0.8, false),
			"Tier %d samples actual sourced %s contents through the runtime viewer" % [tier, content_state])
		var state: Dictionary = model.call("snapshot")
		var content: Dictionary = state.get("content", {})
		check(model.get("_model") == source and state.get("parts", []) == pose
			and is_equal_approx(float(state.get("open_amount", 0.0)), 0.45)
			and int(state.get("composer_source_instances", 0)) == 1,
			"Tier %d changes %s contents without duplicating the source or seeking its fractional lid pose" % [tier, content_state])
		check(bool(content.get("caller_owned", false)) and not bool(content.get("auto_processing", true))
			and str(content.get("state_scene", "")) == str(style.state_scene),
			"Tier %d samples %s from its actual scene using only the owner clock" % [tier, content_state])
		check(bool(content.get("loot_visible", false)) == (content_state == "treasure")
			and bool(content.get("magic_visible", false)) == (content_state == "magic"),
			"Tier %d keeps empty, treasure and magic presentations distinct" % tier)
		if content_state == "magic":
			check(is_equal_approx(float(content.get("content_time", -1.0)), 0.25)
				and is_equal_approx(float(content.get("magic_strength", -1.0)), 0.8)
				and not bool(content.get("magic_clipped", true)),
				"Tier %d samples continuous sourced magic within its authored envelope" % tier)
	check(model.call("set_contents", "magic", 4.0, 0.8, true)
		and is_zero_approx(float(model.call("snapshot").get("content", {}).get("content_time", -1.0))),
		"Tier %d retains sourced magic in a static reduced-motion state" % tier)
	var before: Dictionary = model.call("snapshot").duplicate(true)
	check(not model.call("set_contents", "unknown", 0.0)
		and model.call("snapshot") == before,
		"Tier %d rejects unknown contents without mutating its real source composition" % tier)
	model.call("set_closed_turn", 0.0)


func _check_source_materials(tier: int, base: Node3D, style: Dictionary) -> void:
	var path: String = _resource_path(str(style.model))
	if not path.begins_with("res://assets/chests/models/atelier/"):
		return
	var resource := load(path) as PackedScene
	if resource == null:
		check(false, "Tier %d source scene remains loadable for atlas comparison" % tier)
		return
	var original := resource.instantiate() as Node3D
	var source_meshes: Array[MeshInstance3D] = []
	var instance_meshes: Array[MeshInstance3D] = []
	_collect_meshes(original, source_meshes)
	_collect_meshes(base, instance_meshes)
	check(source_meshes.size() == instance_meshes.size(),
		"Tier %d preserves the acquired Atelier model's geometry structure" % tier)
	var preserved: bool = source_meshes.size() == instance_meshes.size()
	var source_surfaces: int = 0
	for index in range(mini(source_meshes.size(), instance_meshes.size())):
		var source_mesh: MeshInstance3D = source_meshes[index]
		var instance: MeshInstance3D = instance_meshes[index]
		preserved = preserved and source_mesh.mesh.get_surface_count() == instance.mesh.get_surface_count()
		for surface in range(mini(source_mesh.mesh.get_surface_count(), instance.mesh.get_surface_count())):
			var source_arrays: Array = source_mesh.mesh.surface_get_arrays(surface)
			var instance_arrays: Array = instance.mesh.surface_get_arrays(surface)
			preserved = preserved and source_arrays[Mesh.ARRAY_TEX_UV] == instance_arrays[Mesh.ARRAY_TEX_UV]
			var source_material: BaseMaterial3D = source_mesh.get_active_material(surface) as BaseMaterial3D
			var material: Material = instance.get_active_material(surface)
			if source_material == null:
				continue
			source_surfaces += 1
			if source_material.albedo_texture != null:
				preserved = preserved and _retains_source_texture(material, source_material.albedo_texture)
			if material is BaseMaterial3D:
				preserved = preserved and material.albedo_color == source_material.albedo_color \
					and (is_equal_approx(material.metallic, source_material.metallic)
						or material.metallic_texture != null) \
					and material.vertex_color_use_as_albedo == source_material.vertex_color_use_as_albedo
			elif source_material.albedo_texture == null:
				preserved = false
	check(source_surfaces > 0 and preserved,
		"Tier %d preserves authored UVs, source textures or vertex palette and differentiated material surfaces" % tier)
	original.free()


func _retains_source_texture(material: Material, texture: Texture2D) -> bool:
	if material is BaseMaterial3D:
		return material.albedo_texture == texture
	if material is ShaderMaterial and material.shader != null:
		if material.get_shader_parameter("source_texture") == texture:
			return true
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			if material.get_shader_parameter(str(uniform.name)) == texture:
				return true
	return false


func _check_opening_and_camera(tier: int, model: SubViewport, style: Dictionary) -> void:
	var camera: Camera3D = model.get("_camera") as Camera3D
	var rig: Node3D = model.get("_rig") as Node3D
	var camera_transform: Transform3D = camera.transform
	var camera_size: float = camera.size
	var envelope: Rect2 = model.call("design_bounds")
	var rest: Dictionary = model.call("snapshot")
	var rest_parts: Array = rest.get("parts", []).duplicate(true)
	check(not rest_parts.is_empty(), "Tier %d exposes its actual lid mechanism for absolute pose sampling" % tier)
	if style.get("open_animation", "") != "":
		var clip: String = str(rest.get("source_animation", ""))
		check(clip.get_slice("/", clip.get_slice_count("/") - 1) == style.open_animation,
			"Tier %d uses the acquired source opening clip" % tier)
		check(absf(float(model.get("_clip_end")) - 1.0) < 0.0001,
			"Tier %d plays the complete authored one-second Atelier opening" % tier)
	else:
		check(false, "Tier %d must retain its actual Atelier Open clip" % tier)
	model.call("set_pose", 0.25, 0.0, 0.0, 0.0, 0.0, Color.WHITE, true)
	var quarter: Array = model.call("snapshot").get("parts", []).duplicate(true)
	model.call("set_pose", 0.26, 0.0, 0.0, 0.0, 0.0, Color.WHITE, true)
	var adjacent: Array = model.call("snapshot").get("parts", []).duplicate(true)
	check(quarter != adjacent and _mechanism_difference(quarter, adjacent) < 0.20,
		"Tier %d opens continuously between adjacent fractional poses" % tier)
	model.call("set_pose", 1.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE, true)
	check(_mechanism_difference(rest_parts, model.call("snapshot").get("parts", [])) > 0.25,
		"Tier %d substantially opens real lid geometry rather than swapping flat art" % tier)
	var contained: bool = Rect2(0, 0, 1024, 1024).encloses(envelope)
	var geometry_contained: bool = true
	var fixed_camera: bool = true
	var genuine_turn: bool = true
	var closed_box: AABB = model.get("_closed_box")
	var silhouettes: Array[Rect2] = []
	for pitch: float in [-0.22, 0.0, 0.22]:
		for index in range(17):
			var yaw: float = float(index) * TAU / 16.0
			model.call("set_closed_turn", yaw, pitch)
			var state: Dictionary = model.call("snapshot")
			genuine_turn = genuine_turn and rig.basis.is_equal_approx(Basis.from_euler(Vector3(pitch, yaw, 0.0))) \
				and rig.scale.is_equal_approx(Vector3.ONE) and state.get("parts", []) == rest_parts \
				and is_zero_approx(float(state.get("open_amount", -1.0)))
			fixed_camera = fixed_camera and camera.transform == camera_transform \
				and is_equal_approx(camera.size, camera_size) and model.call("design_bounds") == envelope
			var silhouette: Rect2 = model.call("closed_turn_bounds")
			for corner in range(8):
				var point: Vector2 = model.call("_project_point", rig.transform * closed_box.get_endpoint(corner))
				contained = contained and envelope.grow(0.01).has_point(point) \
					and Rect2(0, 0, 1024, 1024).has_point(point) \
					and silhouette.grow(0.01).has_point(point)
			if is_zero_approx(pitch) and index in [0, 4, 8]:
				# A square X/Z AABB is invariant under 90-degree yaw even when
				# the actual rounded lid's projected height visibly changes.
				var actual: Rect2 = _project_geometry_bounds(model)
				geometry_contained = geometry_contained and silhouette.grow(0.01).encloses(actual)
				silhouettes.append(actual)
	check(genuine_turn, "Tier %d performs real front, side and back yaw with an exactly closed mechanism" % tier)
	check(fixed_camera and contained and geometry_contained,
		"Tier %d keeps its ornaments, open motion and full pitched turn inside one fixed camera envelope" % tier)
	check(silhouettes.size() == 3 and silhouettes[0].size.distance_to(silhouettes[1].size) > 1.0,
		"Tier %d changes its projected dimensional silhouette at a quarter turn" % tier)
	model.call("set_pose", 0.25, 0.0, 0.0, 0.0, 0.0, Color.WHITE, true)
	check(model.call("snapshot").get("parts", []) == quarter,
		"Tier %d can resume the exact source opening after reward rotation" % tier)


func _mechanism_difference(first: Array, second: Array) -> float:
	var maximum: float = 0.0
	for index in range(mini(first.size(), second.size())):
		var a: Dictionary = first[index]
		var b: Dictionary = second[index]
		if a.get("role", "") != "lid" or b.get("role", "") != "lid":
			continue
		var first_rotation: Quaternion = a.get("rotation", Quaternion.IDENTITY)
		var second_rotation: Quaternion = b.get("rotation", Quaternion.IDENTITY)
		var first_position: Vector3 = a.get("position", Vector3.ZERO)
		var second_position: Vector3 = b.get("position", Vector3.ZERO)
		maximum = maxf(maximum, first_rotation.angle_to(second_rotation))
		maximum = maxf(maximum, first_position.distance_to(second_position))
	return maximum


func _check_legacy_themes() -> void:
	var chest := Chest.new()
	root.add_child(chest)
	chest.size = Vector2(320, 280)
	for theme in THEMES:
		var tier: int = int(_catalog.call("theme_tier", theme))
		check(tier >= 1 and tier <= 99, theme + " maps to an actual catalog tier")
		chest.configure_skin(Data.theme(theme), _manifest)
		chest.set_process(false)
		var state: Dictionary = chest.hold_effect_snapshot()
		var live: Dictionary = state.get("live_model", {})
		check(chest.theme_id == theme and not live.is_empty() and int(live.get("mesh_count", 0)) > 0,
			theme + " renders a live volumetric chest while preserving audio/reward identity")
		check(int(state.get("chest_tier", 0)) == tier
			and state.get("preset_id", "") == _preset(tier).get("id", ""),
			theme + " exposes its representative tier and recipe identity")
		var style_alias: String = str(Data.theme(theme).chest)
		check(int(_catalog.call("theme_tier", style_alias)) == tier,
			theme + " and its legacy chest-style alias share one genuine 3D recipe")
	chest.free()


func _check_exact_tier_reconfiguration() -> void:
	var chest := Chest.new()
	root.add_child(chest)
	chest.size = Vector2(320, 280)
	if not chest.has_method("configure_tier"):
		chest.free()
		return
	var palette: Dictionary = Data.theme("autumn")
	for tier in range(1, 100):
		chest.call("configure_tier", tier, palette, _manifest)
		chest.set_process(false)
		var state: Dictionary = chest.hold_effect_snapshot()
		check(chest.theme_id == "autumn" and int(state.get("chest_tier", 0)) == tier
			and state.get("preset_id", "") == _preset(tier).get("id", "")
			and not state.get("live_model", {}).is_empty(),
			"Exact tier %d replaces same-theme art without recursive legacy reconfiguration" % tier)
	var model: Object = chest.get("_model_view")
	chest.start_open(false)
	chest._advance_animation(Feel.RELEASE_TIME + 0.1)
	var before: Dictionary = chest.hold_effect_snapshot().duplicate(true)
	chest.call("configure_tier", 99, palette, _manifest)
	check(chest.get("_model_view") == model and chest.hold_effect_snapshot() == before,
		"Reconfiguring the same actual tier preserves its ongoing model, opening and sound clock")
	check(chest.get_child_count() < 20,
		"Changing ninety-nine exact tiers does not retain old model viewports")
	chest.free()


func _check_missing_geometry() -> void:
	var model := Model.new()
	root.add_child(model)
	check(model.configure(_style(2)), "Missing-resource validation first owns a real styled source model")
	var style: Dictionary = _style(2)
	style["model"] = "assets/chests/models/atelier/missing-chest.glb"
	check(not model.configure(style) and not model.last_error.is_empty()
		and not bool(model.snapshot().get("available", true)) and int(model.snapshot().get("mesh_count", -1)) == 0,
		"A missing acquired base reports unavailable instead of substituting a card")
	check(model.configure(_style(2)), "A valid recipe can recover from a rejected base")
	style = _style(2)
	style["open_animation"] = "MissingAuthoredOpening"
	check(not model.configure(style) and not model.last_error.is_empty()
		and not bool(model.snapshot().get("available", true)),
		"A missing authored opening rejects the source recipe rather than presenting an inert chest")
	model.free()


func _check_reward_pool() -> void:
	var models := RewardModel.new()
	root.add_child(models)
	models.set_active(false)
	var retired: Array[WeakRef] = []
	for tier in range(1, 100):
		var sample: Dictionary = models.sample(tier, 0.0)
		var pool: Dictionary = models.get("_pool")
		check(pool.has(tier) and not sample.is_empty(),
			"Reward tier %d is available as actual closed 3D geometry" % tier)
		check(pool.size() <= 2 and models.get_child_count() <= 2,
			"Reward tier %d respects the two-surface pool limit" % tier)
		if not pool.has(tier):
			await process_frame
			continue
		var model: SubViewport = pool[tier]
		var state: Dictionary = model.call("snapshot")
		check(sample.get("texture") is ViewportTexture
			and sample.get("bounds", Rect2()).has_area()
			and sample.get("turn_bounds", Rect2()).has_area(),
			"Reward tier %d supplies a real render target and measured bounds" % tier)
		check(not bool(state.get("active", true))
			and model.render_target_update_mode == SubViewport.UPDATE_DISABLED,
			"Reward tier %d remains idle while its owner is paused" % tier)
		if _catalog != null:
			check(state.get("source", "") == _resource_path(str(_style(tier).get("model", ""))),
				"Reward tier %d uses its exact recipe rather than a repeating legacy theme" % tier)
		var camera: Camera3D = model.get("_camera") as Camera3D
		var camera_transform: Transform3D = camera.transform
		var camera_size: float = camera.size
		var closed: AABB = model.get("_closed_box")
		var envelope: Rect2 = model.call("design_bounds")
		var contained: bool = _volume_valid(closed)
		var real_turn: bool = true
		for pitch: float in [-0.22, 0.0, 0.22]:
			for yaw: float in [0.0, PI * 0.5, PI, PI * 1.5, TAU]:
				var turned: Dictionary = models.sample(tier, yaw, pitch)
				var rig: Node3D = model.get("_rig") as Node3D
				real_turn = real_turn and rig.basis.is_equal_approx(Basis.from_euler(Vector3(pitch, yaw, 0.0))) \
					and is_zero_approx(float(model.call("snapshot").get("open_amount", -1.0))) \
					and camera.transform == camera_transform and is_equal_approx(camera.size, camera_size)
				for corner in range(8):
					var point: Vector2 = model.call("_project_point", rig.transform * closed.get_endpoint(corner))
					contained = contained and envelope.grow(0.01).has_point(point) \
						and Rect2(0, 0, 1024, 1024).has_point(point) \
						and turned.get("turn_bounds", Rect2()).grow(0.01).has_point(point)
		check(real_turn and contained,
			"Reward tier %d uses measured full-turn framing, including sources without exported bounds" % tier)
		retired.append(weakref(model))
		await process_frame
	var before_invalid: Array = models.get("_order").duplicate()
	check(models.sample(0, 0.0).is_empty() and models.sample(100, 0.0).is_empty()
		and models.sample(99, NAN).is_empty() and models.sample(99, 0.0, INF).is_empty()
		and models.get("_order") == before_invalid and not models.last_error.is_empty(),
		"Invalid tier/angle samples are explicitly unavailable and cannot mutate the bounded pool")
	if models.get("_pool").has(99):
		models.set_active(true)
		models.sample(99, 0.37)
		check(models.last_error.is_empty(), "A valid real-model sample clears its prior input validation error")
		var active: SubViewport = models.get("_pool")[99]
		check(active.render_target_update_mode == SubViewport.UPDATE_ONCE,
			"A changed ninety-ninth-tier turn requests exactly one render")
		active.render_target_update_mode = SubViewport.UPDATE_DISABLED
		models.sample(99, 0.37)
		check(active.render_target_update_mode == SubViewport.UPDATE_DISABLED,
			"An unchanged ninety-ninth-tier turn does not repeatedly render")
		models.set_active(false)
	models.clear()
	check(models.get("_pool").is_empty() and models.get("_order").is_empty()
		and models.get_child_count() == 0,
		"Clearing the reward renderer immediately disables and detaches both pooled surfaces")
	await process_frame
	await process_frame
	var disposed: bool = true
	for reference in retired:
		disposed = disposed and reference.get_ref() == null
	check(disposed, "Retired tier surfaces and their world/camera/model children are actually disposed")
	models.free()


func _capture_contact_sheets() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "Actual tier captures require a rendering display, not a headless blank surface")
		return
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_PATH))
	check(error == OK, "Actual tier contact-sheet output directory can be created")
	if error != OK:
		return
	var index: Array[Dictionary] = []
	var sheet: Image
	var labels: Array[String] = ["front", "side", "back", "opened"]
	for tier in range(1, 100):
		if (tier - 1) % 5 == 0:
			sheet = Image.create(1024, 1280, false, Image.FORMAT_RGBA8)
			sheet.fill(Color("#edf1f2"))
		var model := Model.new()
		root.add_child(model)
		if not model.configure(_style(tier)):
			check(false, "Capture tier %d configures real artwork" % tier)
			model.free()
			continue
		model.set_display_size(Vector2(512, 512))
		model.set_render_active(true)
		for column in range(4):
			if column == 3:
				model.set_pose(1.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE, true)
			else:
				model.set_closed_turn([0.0, PI * 0.5, PI][column])
			for frame in range(2):
				await process_frame
				await RenderingServer.frame_post_draw
			var picture: Image = model.get_texture().get_image()
			check(picture != null and not picture.is_empty() and _has_visible_pixels(picture),
				"Tier %d %s capture contains a rendered surface" % [tier, labels[column]])
			if picture == null or picture.is_empty() or not _has_visible_pixels(picture):
				continue
			var filename: String = "tier-%02d-%s.png" % [tier, labels[column]]
			check(picture.save_png(CAPTURE_PATH + "/" + filename) == OK,
				"Tier %d %s capture is persisted" % [tier, labels[column]])
			picture.convert(Image.FORMAT_RGBA8)
			picture.resize(256, 256, Image.INTERPOLATE_LANCZOS)
			sheet.blend_rect(picture, Rect2i(0, 0, 256, 256),
				Vector2i(column * 256, ((tier - 1) % 5) * 256))
			index.append({"tier": tier, "preset_id": _preset(tier).get("id", ""),
				"view": labels[column], "file": filename})
		model.free()
		if tier % 5 == 0 or tier == 99:
			var first_tier: int = tier - ((tier - 1) % 5)
			check(sheet.save_png(CAPTURE_PATH + "/tiers-%02d-%02d.png" % [first_tier, tier]) == OK,
				"Tier %d-%d four-view contact sheet is persisted" % [first_tier, tier])
	var file := FileAccess.open(CAPTURE_PATH + "/capture-index.json", FileAccess.WRITE)
	check(file != null, "Actual capture index can be persisted")
	if file != null:
		file.store_string(JSON.stringify({"columns": labels, "rows": "ascending tiers", "captures": index}, "\t"))


func _has_visible_pixels(image: Image) -> bool:
	var samples: int = 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			if image.get_pixel(x, y).a > 0.1:
				samples += 1
	return samples > 20

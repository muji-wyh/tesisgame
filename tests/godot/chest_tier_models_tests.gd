extends SceneTree

const Model = preload("res://scripts/chest_model_view.gd")
const Chest = preload("res://scripts/chest_view.gd")
const RewardModel = preload("res://scripts/chest_reward_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const CATALOG_PATH: String = "res://scripts/chest_tier_catalog.gd"
const PRESETS_PATH: String = "res://assets/chests/tier-presets.json"
const SOURCES_PATH: String = "res://assets/chests/catalog-cc0/sources.json"
const MANIFEST_PATH: String = "res://assets/chests/downloaded/manifest.json"
const CAPTURE_PATH: String = "res://build/qa/chest-thirty-tiers"
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
	check(_recipes.size() == 30, "Acquired recipes define exactly thirty modular tiers")
	_check_entry_points()
	if _load_catalog():
		_check_catalog(presets)
		for tier in range(1, 31):
			_check_tier_model(tier)
		_check_legacy_themes()
		_check_exact_tier_reconfiguration()
		_check_missing_geometry()
	await _check_reward_pool()
	if OS.get_cmdline_user_args().has("--capture") and _catalog != null and failures == 0:
		await _capture_contact_sheets()
	print("Thirty-tier chest models: %d checks, %d failures" % [checks, failures])
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
	check(int(constants.get("MAX_TIER", 0)) == 30, "The rendering catalog caps tiers at thirty")
	var ids: Dictionary = {}
	var structures: Dictionary = {}
	var families: Dictionary = {}
	var previous_rank: int = 0
	var profiles: Dictionary = presets.get("source_notes", {}).get("material_styles", {})
	for tier in range(1, 31):
		var preset: Dictionary = _preset(tier)
		var style: Dictionary = _style(tier)
		if preset.is_empty() or style.is_empty():
			check(false, "Tier %d has an explicit preset and renderable style" % tier)
			continue
		check(int(preset.get("level", 0)) == tier and int(style.get("tier", 0)) == tier,
			"Tier %d keeps its exact contiguous level" % tier)
		check(str(preset.get("id", "")).begins_with("tier-%02d-" % tier)
			and style.get("preset_id", "") == preset.get("id"),
			"Tier %d keeps the acquired recipe identity through rendering" % tier)
		ids[preset.get("id", "")] = true
		var source: String = str(preset.get("base_model", ""))
		check(_resource_path(str(style.get("model", ""))) == _resource_path(source),
			"Tier %d uses its declared acquired base rather than another tier or flat art" % tier)
		check(_known_model(source), "Tier %d base resolves to a documented source artifact" % tier)
		check(FileAccess.file_exists(_resource_path(source)),
			"Tier %d acquired base file is present" % tier)
		families[source] = true
		var geometry: Array = []
		var slots: Dictionary = {}
		var decorations: Array = preset.get("decorations", [])
		check(style.get("decorations", []) == decorations,
			"Tier %d preserves its structurally distinct source ornament recipe" % tier)
		for entry: Dictionary in decorations:
			var ornament: String = str(entry.get("model", ""))
			var slot: String = str(entry.get("slot", ""))
			check(_known_model(ornament) and FileAccess.file_exists(_resource_path(ornament)),
				"Tier %d %s ornament is a real acquired model" % [tier, slot])
			check(not slots.has(slot) and slot in ["front", "left", "right", "front-left", "front-right"],
				"Tier %d has one model per semantic body anchor" % tier)
			slots[slot] = true
			geometry.append([ornament, slot])
		var signature: String = source + JSON.stringify(geometry)
		check(not structures.has(signature),
			"Tier %d differs by geometry or composition, not just tint or overall size" % tier)
		structures[signature] = true
		var profile_id: String = str(preset.get("material_style", ""))
		var profile: Dictionary = profiles.get(profile_id, {})
		var rank: int = int(profile.get("preciousness_rank", 0))
		check(not profile.is_empty() and rank >= previous_rank,
			"Tier %d advances through the declared preciousness direction" % tier)
		check(style.get("material_style", "") == profile_id
			and style.get("material_profile", {}) == profile,
			"Tier %d exposes role-specific, explicitly game-authored material styling" % tier)
		previous_rank = rank
		if source.begins_with("assets/chests/models/"):
			var legacy: Dictionary = _legacy_style_for_model(source)
			check(not legacy.is_empty() and style.get("model_parts", []) == legacy.get("model_parts", [])
				and style.get("open_animation", "") == legacy.get("open_animation", "")
				and is_equal_approx(float(style.get("open_start", -1.0)), float(legacy.get("open_start", 0.0)))
				and is_equal_approx(float(style.get("open_end", -1.0)), float(legacy.get("open_end", 1.0))),
				"Tier %d preserves the existing private model's bones and opening curve range" % tier)
	check(ids.size() == 30 and structures.size() == 30 and families.size() == 9,
		"Thirty unique modular recipes use nine honest native base families")
	check(_preset(0).is_empty() and not str(_catalog.call("error")).is_empty(),
		"Tier zero returns an explicit catalog validation error without engine noise")
	check(_preset(31).is_empty() and not str(_catalog.call("error")).is_empty()
		and _style(31).is_empty() and not str(_catalog.call("error")).is_empty(),
		"Out-of-range tiers fail explicitly instead of wrapping or silently clamping")
	var first: Dictionary = _preset(2)
	check(str(_catalog.call("error")).is_empty(),
		"A valid catalog lookup clears its preceding input validation error")
	var original: Dictionary = first.duplicate(true)
	first["id"] = "mutated"
	var nested: Array = first.get("decorations", [])
	if not nested.is_empty():
		nested[0]["model"] = "mutated"
	check(_preset(2) == original, "Callers cannot mutate the cached source recipe or nested decorations")
	var styled: Dictionary = _style(30)
	var original_style: Dictionary = styled.duplicate(true)
	styled.get("decorations", []).clear()
	styled.get("material_profile", {}).clear()
	check(_style(30) == original_style, "Callers cannot mutate the cached material profile or render recipe")


func _known_model(path: String) -> bool:
	for entry: Dictionary in _source_catalog.get("files", []):
		if entry.get("path", "") == path and entry.get("kind", "") == "model":
			return true
	for entry: Dictionary in _source_catalog.get("referenced_private_models", []):
		if entry.get("path", "") == path:
			return true
	return false


func _legacy_style_for_model(path: String) -> Dictionary:
	for style: Dictionary in _manifest.get("styles", {}).values():
		if style.get("model", "") == path:
			return style
	return {}


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
	_collect_meshes(rig, meshes)
	var state: Dictionary = model.snapshot()
	check(not meshes.is_empty() and int(state.get("mesh_count", 0)) == meshes.size(),
		"Tier %d includes every base and ornament mesh in its renderer statistics" % tier)
	var genuine: bool = true
	for mesh in meshes:
		genuine = genuine and mesh.mesh is ArrayMesh and _has_spatial_volume(mesh.mesh)
	check(genuine, "Tier %d has genuine volumetric source meshes, never a quad or primitive substitute" % tier)
	check(rig.find_children("*", "Sprite3D", true, false).is_empty()
		and rig.find_children("*", "SpriteBase3D", true, false).is_empty(),
		"Tier %d does not hide a camera-facing card among its source geometry" % tier)
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
		check(is_equal_approx(base_box.size.x, 2.0)
			and absf(base_box.position.y) < 0.005
			and absf(base_box.get_center().x) < 0.005 and absf(base_box.get_center().z) < 0.005,
			"Tier %d normalizes its real base to +Y up, centered X/Z and two units wide" % tier)
		_check_attachments(tier, model, base_roots[0], base_box, style)
		_check_source_materials(tier, base_roots[0], style)
	_check_opening_and_camera(tier, model, style)
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


func _check_attachments(tier: int, model: SubViewport, base: Node3D,
		base_box: AABB, style: Dictionary) -> void:
	var rig: Node3D = model.get("_rig") as Node3D
	var cavity: Vector3 = model.get("_cavity")
	var closed_box: AABB = model.get("_closed_box")
	var decorations: Array = style.get("decorations", [])
	var sources: Dictionary = {}
	var assigned: Array[Node3D] = []
	for entry: Dictionary in decorations:
		var path: String = _resource_path(str(entry.model))
		if not sources.has(path):
			var roots: Array[Node3D] = []
			_find_source_roots(rig, path, roots)
			sources[path] = roots
		var candidates: Array = sources[path]
		var ornament: Node3D
		for candidate: Node3D in candidates:
			if not assigned.has(candidate):
				ornament = candidate
				break
		check(ornament != null, "Tier %d instantiates its real %s source ornament" % [tier, entry.slot])
		if ornament == null:
			continue
		assigned.append(ornament)
		check(not base.is_ancestor_of(ornament),
			"Tier %d %s fitting attaches to the body frame, outside the animated source hierarchy" % [tier, entry.slot])
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(ornament, meshes)
		var box: AABB = _bounds(meshes, rig)
		check(not meshes.is_empty() and _volume_valid(box) and closed_box.grow(0.001).encloses(box),
			"Tier %d %s ornament remains volumetric and participates in closed framing" % [tier, entry.slot])
		check(box.position.y >= base_box.position.y - 0.002
			and box.end.y <= cavity.y - base_box.size.x * 0.002,
			"Tier %d %s fitting stays entirely below the measured lid seam" % [tier, entry.slot])
		var normal: Vector3 = _slot_normal(str(entry.slot))
		var center: Vector3 = box.get_center()
		var surface: Variant = _body_surface(base, model, center, normal, base_box.size.x)
		check(surface is Vector3, "Tier %d %s anchor lands on actual body triangles" % [tier, entry.slot])
		if surface is Vector3:
			var nearest: float = INF
			for corner in range(8):
				nearest = minf(nearest, normal.dot(box.get_endpoint(corner) - surface))
			check(nearest >= -base_box.size.x * 0.008 and nearest <= base_box.size.x * 0.055,
				"Tier %d %s fitting sits just outside its body panel, not inside it or floating away" % [tier, entry.slot])
		var rest: Transform3D = _relative_transform(ornament, rig)
		var stationary: bool = true
		var lid_clear: bool = true
		for amount: float in [0.0, 0.15, 0.5, 1.0]:
			model.call("set_pose", amount, 0.0, 0.0, 0.0, 0.0, Color.WHITE, true)
			stationary = stationary and _relative_transform(ornament, rig).is_equal_approx(rest)
			var parts: Array = model.get("_parts")
			for part: Dictionary in parts:
				if part.get("role", "") != "lid" or int(part.get("bone", -1)) >= 0:
					continue
				var lid_meshes: Array[MeshInstance3D] = []
				_collect_meshes(part.node, lid_meshes)
				lid_clear = lid_clear and not box.intersects(_bounds(lid_meshes, rig))
		check(stationary, "Tier %d %s fitting follows the body rather than the opening lid" % [tier, entry.slot])
		check(lid_clear, "Tier %d %s fitting clears the actual moving lid volume" % [tier, entry.slot])
		model.call("set_pose", 0.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE, true)
	var ornament_count: int = 0
	for roots: Array in sources.values():
		ornament_count += roots.size()
	check(ornament_count == decorations.size(),
		"Tier %d creates exactly its declared ornaments without duplicate attachment leaks" % tier)


func _slot_normal(slot: String) -> Vector3:
	match slot:
		"left":
			return Vector3.LEFT
		"right":
			return Vector3.RIGHT
	return Vector3.BACK


func _body_surface(base: Node3D, model: SubViewport, center: Vector3,
		normal: Vector3, width: float) -> Variant:
	var rig: Node3D = model.get("_rig") as Node3D
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(base, meshes)
	var ray: Vector3 = center + normal * width * 3.0
	var nearest_distance: float = INF
	var nearest: Variant = null
	var parts: Array = model.get("_parts")
	for mesh in meshes:
		var moving: bool = false
		for part: Dictionary in parts:
			var node: Node = part.get("node")
			if part.get("role", "") == "lid" and int(part.get("bone", -1)) < 0 \
				and (node == mesh or node.is_ancestor_of(mesh)):
				moving = true
		if moving:
			continue
		var transform: Transform3D = _relative_transform(mesh, rig)
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for offset in range(0, count - 2, 3):
				var a: int = indices[offset] if not indices.is_empty() else offset
				var b: int = indices[offset + 1] if not indices.is_empty() else offset + 1
				var c: int = indices[offset + 2] if not indices.is_empty() else offset + 2
				var hit: Variant = Geometry3D.ray_intersects_triangle(ray, -normal,
					transform * vertices[a], transform * vertices[b], transform * vertices[c])
				if hit is Vector3:
					var distance: float = ray.distance_squared_to(hit)
					if distance < nearest_distance:
						nearest_distance = distance
						nearest = hit
	return nearest


func _check_source_materials(tier: int, base: Node3D, style: Dictionary) -> void:
	var path: String = _resource_path(str(style.model))
	if not path.contains("/catalog-cc0/"):
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
		"Tier %d preserves the source atlas base's geometry structure" % tier)
	var preserved: bool = source_meshes.size() == instance_meshes.size()
	var textured: bool = false
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
			if source_material == null or source_material.albedo_texture == null:
				continue
			textured = true
			preserved = preserved and material != source_material \
				and _retains_source_texture(material, source_material.albedo_texture)
			if material is BaseMaterial3D:
				preserved = preserved and material.albedo_color == source_material.albedo_color \
					and (is_equal_approx(material.metallic, source_material.metallic)
						or material.metallic_texture != null)
	check(textured and preserved,
		"Tier %d keeps source UV/atlas detail and never blanket-tints or metallizes wood with trim" % tier)
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
		if str(style.model).contains("/kenney-"):
			check(absf(float(model.get("_clip_end")) - 0.3) < 0.0001,
				"Tier %d plays the complete original 0.3-second Kenney opening" % tier)
	else:
		check(str(style.model).contains("/kaykit-") and not style.get("model_parts", []).is_empty(),
			"Tier %d gives the static KayKit lid a real game-authored hinge" % tier)
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
		check(tier >= 1 and tier <= 30, theme + " maps to an actual catalog tier")
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
	for tier in range(1, 31):
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
	chest.call("configure_tier", 30, palette, _manifest)
	check(chest.get("_model_view") == model and chest.hold_effect_snapshot() == before,
		"Reconfiguring the same actual tier preserves its ongoing model, opening and sound clock")
	check(chest.get_child_count() < 20,
		"Changing thirty exact tiers does not retain old model viewports")
	chest.free()


func _check_missing_geometry() -> void:
	var model := Model.new()
	root.add_child(model)
	check(model.configure(_style(2)), "Missing-resource validation first owns a real styled source model")
	var style: Dictionary = _style(2)
	style["model"] = "assets/chests/catalog-cc0/missing-chest.glb"
	check(not model.configure(style) and not model.last_error.is_empty()
		and not bool(model.snapshot().get("available", true)) and int(model.snapshot().get("mesh_count", -1)) == 0,
		"A missing acquired base reports unavailable instead of substituting a card")
	check(model.configure(_style(2)), "A valid recipe can recover from a rejected base")
	style = _style(2)
	var decorations: Array = style.get("decorations", [])
	if not decorations.is_empty():
		decorations[0]["model"] = "assets/chests/catalog-cc0/missing-ornament.glb"
	check(not model.configure(style) and not model.last_error.is_empty()
		and not bool(model.snapshot().get("available", true)) and int(model.snapshot().get("mesh_count", -1)) == 0,
		"A missing required real ornament rejects the recipe instead of claiming a complete tier")
	model.free()


func _check_reward_pool() -> void:
	var models := RewardModel.new()
	root.add_child(models)
	models.set_active(false)
	var retired: Array[WeakRef] = []
	for tier in range(1, 31):
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
			check(state.get("source", "") == _resource_path(str(_preset(tier).get("base_model", ""))),
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
	check(models.sample(0, 0.0).is_empty() and models.sample(31, 0.0).is_empty()
		and models.sample(30, NAN).is_empty() and models.sample(30, 0.0, INF).is_empty()
		and models.get("_order") == before_invalid and not models.last_error.is_empty(),
		"Invalid tier/angle samples are explicitly unavailable and cannot mutate the bounded pool")
	if models.get("_pool").has(30):
		models.set_active(true)
		models.sample(30, 0.37)
		check(models.last_error.is_empty(), "A valid real-model sample clears its prior input validation error")
		var active: SubViewport = models.get("_pool")[30]
		check(active.render_target_update_mode == SubViewport.UPDATE_ONCE,
			"A changed thirtieth-tier turn requests exactly one render")
		active.render_target_update_mode = SubViewport.UPDATE_DISABLED
		models.sample(30, 0.37)
		check(active.render_target_update_mode == SubViewport.UPDATE_DISABLED,
			"An unchanged thirtieth-tier turn does not repeatedly render")
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
	for tier in range(1, 31):
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
		if tier % 5 == 0:
			check(sheet.save_png(CAPTURE_PATH + "/tiers-%02d-%02d.png" % [tier - 4, tier]) == OK,
				"Tier %d-%d four-view contact sheet is persisted" % [tier - 4, tier])
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

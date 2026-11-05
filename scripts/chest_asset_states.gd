extends Node3D
## Reusable, source-preserving chest presentation. Rewards remain caller-owned.

const CATALOG_PATH: String = "res://assets/chests/catalog/chest-states.json"
const STATES: Array[String] = ["closed", "open", "treasure", "magic"]

static var _cached_catalog_text: String = ""
static var _cached_catalog: Dictionary = {}
static var _has_cached_catalog: bool = false

@export var asset_id: String = ""
@export_enum("closed", "open", "treasure", "magic") var initial_state: String = "closed"
@export var reduced_motion: bool = false

var last_error: String = ""
var _entry: Dictionary = {}
var _source: Node3D
var _loot: Node3D
var _magic: Node3D
var _embedded_loot: Array[Node3D] = []
var _players: Array[AnimationPlayer] = []
var _player: AnimationPlayer
var _clip: StringName = &""
var _hinge: Node3D
var _hinge_rest: Transform3D
var _state: String = "closed"
var _age: float = 0.0
var _sprites: Array[Dictionary] = []
var _magic_envelope := AABB()
var _opening_amount: float = 0.0
var _magic_strength: float = 1.0
var _caller_owned: bool = false


func _ready() -> void:
	if not asset_id.is_empty() and _source == null:
		if configure(asset_id):
			set_state(initial_state)


func configure(id: String) -> bool:
	_clear()
	asset_id = id
	if not FileAccess.file_exists(CATALOG_PATH):
		return _fail("Chest state catalog is missing")
	# Read every time so edited, unreadable, or removed catalogs cannot reuse
	# stale recipes. Only parsing is shared, for one exact current source text.
	var selected: Variant = _entry_for_catalog_text(FileAccess.get_file_as_string(CATALOG_PATH), id)
	if not selected is Dictionary:
		return _fail("Chest state catalog is invalid")
	_entry = selected
	if _entry.is_empty() or str(_entry.get("asset_type", "")) != "model":
		return _fail("Unknown 3D chest asset: " + id)
	_source = _instantiate_model(str(_entry.get("model", "")))
	if _source == null:
		return _fail("Chest source model is missing: " + id)
	_source.name = "ChestSource"
	add_child(_source)
	_scan_players(_source)
	var opening: Dictionary = _entry.get("opening", {})
	if str(opening.get("kind", "")) == "animation":
		var wanted: String = str(opening.get("clip", ""))
		for player: AnimationPlayer in _players:
			for clip: StringName in player.get_animation_list():
				if str(clip) == wanted or str(clip).ends_with("/" + wanted):
					_player = player
					_clip = clip
					break
			if _player != null:
				break
		if _player == null:
			return _fail("Declared chest opening clip is missing: " + wanted)
	elif str(opening.get("kind", "")) == "hinge":
		_hinge = _find_named(_source, str(opening.get("node", "")))
		if _hinge == null:
			return _fail("Declared source lid is missing: " + id)
		_hinge_rest = _hinge.transform
	else:
		return _fail("Chest opening mechanism is missing: " + id)
	var treasure: Dictionary = _entry.get("treasure", {})
	if str(treasure.get("mode", "")) == "embedded":
		for node_name: Variant in treasure.get("nodes", []):
			var node: Node3D = _find_named(_source, str(node_name))
			if node == null:
				return _fail("Declared embedded treasure is missing: " + str(node_name))
			_embedded_loot.append(node)
		if _embedded_loot.is_empty():
			return _fail("Chest has no declared embedded treasure: " + id)
	elif str(treasure.get("mode", "")) == "model":
		_loot = _instantiate_model(str(treasure.get("model", "")))
		if _loot == null:
			return _fail("Sourced chest treasure is missing: " + id)
		_loot.name = "SourcedTreasure"
		add_child(_loot)
		_loot.position = _vector(treasure.get("position", []))
		_loot.rotation_degrees = _vector(treasure.get("rotation_degrees", []))
		_loot.scale = _vector(treasure.get("scale", []), Vector3.ONE)
	else:
		return _fail("Chest treasure composition is missing: " + id)
	if not _build_magic(_entry.get("magic", {})):
		return false
	last_error = ""
	return set_state("closed")


static func _entry_for_catalog_text(source_text: String, id: String) -> Variant:
	if not _has_cached_catalog or source_text != _cached_catalog_text:
		_cached_catalog_text = source_text
		_cached_catalog = {}
		_has_cached_catalog = true
		var parser := JSON.new()
		if parser.parse(source_text) == OK:
			var parsed: Variant = parser.data
			if parsed is Dictionary and parsed.get("variants") is Array:
				_cached_catalog = parsed
	if _cached_catalog.is_empty():
		return null
	for candidate: Variant in _cached_catalog.variants:
		if candidate is Dictionary and str(candidate.get("id", "")) == id:
			# Every instance owns all mutable recipe data, including nested arrays.
			return candidate.duplicate(true)
	return {}


func set_state(value: String) -> bool:
	if not value in STATES or _source == null or _entry.is_empty():
		return false
	var amount: float = 0.0 if value == "closed" else 1.0
	_pose_opening(amount)
	if not sample_contents(value, 0.0, amount, reduced_motion):
		return false
	_caller_owned = false
	set_process(value == "magic" and not reduced_motion)
	return true


func sample_contents(value: String, time: float, openness: float,
		reduce: bool = false, strength: float = 1.0) -> bool:
	if not value in STATES or _source == null or _entry.is_empty():
		return false
	# Runtime callers own both clocks. Sampling contents never seeks the lid,
	# restarts its source animation, or creates an independent animation loop.
	set_process(false)
	_caller_owned = true
	_state = value
	_age = maxf(0.0, time) if is_finite(time) and not reduce else 0.0
	_opening_amount = clampf(openness, 0.0, 1.0) if is_finite(openness) else 0.0
	_magic_strength = clampf(strength, 0.0, 1.0) if is_finite(strength) else 0.0
	reduced_motion = reduce
	for node: Node3D in _embedded_loot:
		node.visible = value == "treasure"
	if _loot != null:
		_loot.visible = value == "treasure"
	if _magic != null:
		_magic.visible = value == "magic" and _magic_strength > 0.0
	_sample_magic(_age)
	return true


func source_model() -> Node3D:
	return _source


func source_model_path() -> String:
	return str(_entry.get("model", ""))


func is_embedded_content(node: Node) -> bool:
	for content: Node3D in _embedded_loot:
		if node == content or content.is_ancestor_of(node):
			return true
	return false


func _process(delta: float) -> void:
	_age += maxf(0.0, delta)
	_sample_magic(_age)


func _pose_opening(amount: float) -> void:
	var opening: Dictionary = _entry.get("opening", {})
	if _player != null and not _clip.is_empty():
		var animation: Animation = _player.get_animation(_clip)
		var start: float = clampf(float(opening.get("start", 0.0)), 0.0, animation.length)
		var end: float = clampf(float(opening.get("end", animation.length)), start, animation.length)
		_player.play(_clip)
		_player.seek(lerpf(start, end, amount), true)
		_player.advance(0.0)
	elif _hinge != null:
		var axis: Vector3 = _vector(opening.get("axis", []), Vector3.RIGHT).normalized()
		var turn := Basis(Quaternion(axis, float(opening.get("angle", 0.0)) * amount))
		_hinge.transform = Transform3D(_hinge_rest.basis * turn, _hinge_rest.origin)


func _instantiate_model(filename: String) -> Node3D:
	var resource_path: String = _resource_path(filename)
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path, "PackedScene"):
		return null
	var scene := load(resource_path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _scan_players(node: Node) -> void:
	if node is AnimationPlayer:
		node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		node.stop()
		_players.append(node)
	for child: Node in node.get_children():
		_scan_players(child)


func _find_named(node: Node, wanted: String) -> Node3D:
	if str(node.name) == wanted:
		return node as Node3D
	return node.find_child(wanted, true, false) as Node3D


func _build_magic(composition: Dictionary) -> bool:
	var textures: Dictionary = composition.get("textures", {})
	var dimensions: Vector3 = _vector(composition.get("size", []))
	if dimensions.x <= 0.0 or dimensions.y <= 0.0 or dimensions.z <= 0.0:
		return _fail("Chest magic envelope is invalid: " + asset_id)
	_magic = Node3D.new()
	_magic.name = "SourcedMagic"
	add_child(_magic)
	_magic.position = _vector(composition.get("position", []))
	_magic_envelope = AABB(_magic.position - Vector3(dimensions.x * 0.5, 0.0,
		dimensions.z * 0.5), dimensions)
	var color := Color(str(composition.get("color", "#90dcff")))
	var width: float = minf(dimensions.x, dimensions.z)
	var seed_value: int = int(composition.get("seed", 1))
	for role: String in ["glow", "ray", "spark"]:
		var texture_path: String = _resource_path(str(textures.get(role, "")))
		if texture_path.is_empty() or not ResourceLoader.exists(texture_path, "Texture2D"):
			return _fail("Sourced magic texture is missing: " + role + " for " + asset_id)
		var texture := load(texture_path) as Texture2D
		if texture == null:
			return _fail("Sourced magic texture is invalid: " + texture_path)
		var count: int = 7 if role == "spark" else 1
		for index in range(count):
			var sprite := Sprite3D.new()
			sprite.name = "Magic%s%d" % [role.capitalize(), index + 1]
			sprite.texture = texture
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.shaded = false
			sprite.double_sided = true
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			sprite.modulate = Color(color, 0.88 if role == "glow" else 0.65 if role == "ray" else 1.0)
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.albedo_texture = texture
			material.vertex_color_use_as_albedo = true
			material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			sprite.material_override = material
			var extent: float = width * (0.68 if role == "glow" else 0.76 if role == "ray" else 0.13)
			extent = minf(extent, dimensions.y * 0.75)
			var phase: float = float((seed_value * 37 + index * 71) % 997) / 997.0 * TAU
			var rest := Vector3(0, dimensions.y * (0.33 if role == "glow" else 0.5), 0)
			if role == "spark":
				rest = Vector3(sin(phase) * dimensions.x * 0.29,
					dimensions.y * (0.18 + float(index) / 7.0 * 0.64),
					cos(phase) * dimensions.z * 0.22)
			# Reserve half the diagonal for arbitrary billboard orientation, plus
			# the full vertical drift, before choosing a texture's pixel scale.
			var radius: float = minf(dimensions.x * 0.5 - absf(rest.x),
				dimensions.z * 0.5 - absf(rest.z))
			radius = minf(radius, minf(rest.y, dimensions.y - rest.y)
				- (dimensions.y * 0.025 if role == "spark" else 0.0))
			var diagonal: float = Vector2(texture.get_width(), texture.get_height()).length()
			sprite.pixel_size = minf(extent / float(maxi(texture.get_width(), texture.get_height())),
				maxf(0.001, radius) * 1.8 / diagonal)
			sprite.position = rest
			_magic.add_child(sprite)
			_sprites.append({"node": sprite, "role": role, "rest": rest,
				"phase": phase, "alpha": sprite.modulate.a, "height": dimensions.y})
	return true


func _sample_magic(time: float) -> void:
	for piece: Dictionary in _sprites:
		var sprite: Sprite3D = piece.node
		var clock: float = 0.0 if reduced_motion else time
		var phase: float = float(piece.phase)
		sprite.position = piece.rest
		if piece.role == "spark":
			sprite.position.y += sin(clock * 0.8 + phase) * float(piece.height) * 0.025
			sprite.modulate.a = float(piece.alpha) * _magic_strength * (0.76 + 0.24 * sin(clock * 1.2 + phase))
		else:
			sprite.modulate.a = float(piece.alpha) * _magic_strength * (0.90 + 0.10 * sin(clock * 0.7 + phase))


func state_bounds() -> AABB:
	var boxes: Array[AABB] = []
	_collect_bounds(self, true, boxes)
	return _merge_bounds(boxes)


func content_bounds(include_magic_envelope: bool = false) -> AABB:
	var boxes: Array[AABB] = []
	for content: Node3D in _embedded_loot:
		_collect_bounds(content, true, boxes)
	if _loot != null:
		_collect_bounds(_loot, true, boxes)
	if _magic != null:
		_collect_bounds(_magic, true, boxes)
	if include_magic_envelope and _magic_envelope.size.length_squared() > 0.0:
		boxes.append(_magic_envelope)
	return _merge_bounds(boxes)


func _merge_bounds(boxes: Array[AABB]) -> AABB:
	if boxes.is_empty():
		return AABB()
	var result: AABB = boxes[0]
	for index in range(1, boxes.size()):
		result = result.merge(boxes[index])
	return result


func _collect_bounds(node: Node, active: bool, boxes: Array[AABB]) -> void:
	if node is Node3D:
		active = active and node.visible
	if not active:
		return
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(global_transform.affine_inverse() * node.global_transform * node.get_aabb())
	elif node is Sprite3D and node.texture != null:
		# Billboard orientation is camera-dependent; its spherical bound is safe
		# for all viewing directions, including drag rotation in a review scene.
		var radius: float = Vector2(node.texture.get_width(), node.texture.get_height()).length() \
			* node.pixel_size * 0.5
		var center: Vector3 = global_transform.affine_inverse() * node.global_position
		boxes.append(AABB(center - Vector3.ONE * radius, Vector3.ONE * radius * 2.0))
	for child: Node in node.get_children():
		_collect_bounds(child, active, boxes)


func debug_state() -> Dictionary:
	var textures: Dictionary = _entry.get("magic", {}).get("textures", {})
	var loot_meshes: int = _visible_mesh_count(_loot) if _loot != null else 0
	for node: Node3D in _embedded_loot:
		loot_meshes += _visible_mesh_count(node)
	var magic_boxes: Array[AABB] = []
	if _magic != null:
		_collect_bounds(_magic, true, magic_boxes)
	var clipped: bool = false
	for box: AABB in magic_boxes:
		clipped = clipped or not _magic_envelope.grow(0.0001).encloses(box)
	return {"id": asset_id, "state": _state, "configured": _source != null and last_error.is_empty(),
		"model": _entry.get("model", ""), "openness": _opening_amount,
		"state_scene": _entry.get("scene", ""), "state_catalog": CATALOG_PATH,
		"caller_owned": _caller_owned, "auto_processing": is_processing(),
		"content_time": _age, "magic_strength": _magic_strength,
		"source_instances": 1 if _source != null else 0,
		"loot_visible": loot_meshes > 0, "visible_loot_meshes": loot_meshes,
		"loot_mode": _entry.get("treasure", {}).get("mode", ""),
		"loot_resource": _entry.get("treasure", {}).get("model", "embedded"),
		"magic_visible": _magic != null and _magic.visible,
		"magic_textures": textures.duplicate(true), "magic_sprites": _sprites.size(),
		"magic_clipped": clipped, "bounds": state_bounds(), "magic_envelope": _magic_envelope,
		"opening_clip": str(_clip), "error": last_error}


func _visible_mesh_count(node: Node) -> int:
	if node is Node3D and not node.is_visible_in_tree():
		return 0
	var count: int = 1 if node is MeshInstance3D and node.mesh != null else 0
	for child: Node in node.get_children():
		count += _visible_mesh_count(child)
	return count


func _clear() -> void:
	set_process(false)
	for child: Node in get_children():
		child.free()
	_entry.clear()
	_embedded_loot.clear()
	_players.clear()
	_sprites.clear()
	_magic_envelope = AABB()
	_source = null
	_loot = null
	_magic = null
	_player = null
	_hinge = null
	_clip = &""
	_state = "closed"
	_opening_amount = 0.0
	_age = 0.0
	_magic_strength = 1.0
	_caller_owned = false
	last_error = ""


func _fail(message: String) -> bool:
	_clear()
	last_error = message
	return false


func _resource_path(filename: String) -> String:
	var result: String = filename if filename.begins_with("res://") else "res://" + filename
	if not result.begins_with("res://assets/chests/") or result.contains("..") or result.contains("\\"):
		return ""
	return result


func _vector(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if not value is Array or value.size() != 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

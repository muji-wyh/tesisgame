extends Node
## A bounded GPU atlas of the original settled gel shader, shared by one viewport.
## Only new cells render; completed paint stays in the target without CPU readback.

const DISPLAY_SHADER = preload("res://scripts/jelly_idle_body.gdshader")
const CLEAR_SHADER = preload("res://scripts/jelly_idle_clear.gdshader")
const ATLAS_EDGE: int = 2048
const CELL_EDGE: int = 256
const PADDING: int = 2
const CELL_COUNT: int = 64
const WARM_PER_FRAME: int = 2
const UNUSED_SECONDS: float = 2.0
const POOL_NAME := "JellyIdleBodyAtlas"
const PARAMETERS: Array[StringName] = [&"shape_sdf", &"surface_size", &"bend", &"beat",
	&"preview_pressure", &"preview_sway", &"preview_pull", &"rim_color", &"rim_strength",
	&"rim_width", &"rim_uv", &"contact_direction", &"contact_strength", &"contact_match",
	&"palette_hue", &"completion_strength", &"completion_glint"]
const DEFAULT_PARAMETERS: Dictionary = {&"surface_size": Vector2(100.0, 100.0),
	&"bend": 0.0, &"beat": 0.0, &"preview_pressure": 0.0, &"preview_sway": 0.0,
	&"preview_pull": 0.0, &"rim_color": Color(0.21, 0.49, 0.44, 1.0),
	&"rim_strength": 0.0, &"rim_width": 1.0, &"rim_uv": 0.025,
	&"contact_direction": Vector2.ZERO, &"contact_strength": 0.0, &"contact_match": false,
	&"palette_hue": -1.0, &"completion_strength": 0.0, &"completion_glint": -2.0}

static var _display_material: ShaderMaterial
static var _clear_material: ShaderMaterial
var _atlas: SubViewport
var _entries: Dictionary = {}
var _owners: Dictionary = {}
var _pending: Array[String] = []
var _rendering: Array[String] = []
var _bake_nodes: Array[Control] = []
var _clock: int = 0
var _unused_age: float = 0.0
var _hits: int = 0
var _misses: int = 0
var _fallbacks: int = 0
var _bakes: int = 0

static func display_material() -> ShaderMaterial:
	if _display_material == null:
		_display_material = ShaderMaterial.new()
		_display_material.shader = DISPLAY_SHADER
	return _display_material

static func obtain(viewport: Viewport):
	if DisplayServer.get_name() == "headless":
		return null
	var pool: Node = viewport.get_node_or_null(NodePath(POOL_NAME))
	if pool == null:
		pool = load("res://scripts/jelly_idle_body_cache.gd").new()
		pool.name = POOL_NAME
		viewport.add_child(pool)
	return pool

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func _ready() -> void:
	_atlas = SubViewport.new()
	_atlas.name = "Paint"
	_atlas.size = Vector2i.ONE * ATLAS_EDGE
	_atlas.transparent_bg = true
	_atlas.disable_3d = true
	_atlas.gui_disable_input = true
	_atlas.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_atlas.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_atlas.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_atlas)
	get_parent().size_changed.connect(_viewport_changed)

func request(owner: Node, source: Texture2D, material: ShaderMaterial, extent: Vector2i,
		stretch_mode: int) -> Dictionary:
	if extent.x <= 0 or extent.y <= 0 or extent.x > CELL_EDGE - PADDING * 2 or extent.y > CELL_EDGE - PADDING * 2:
		_fallbacks += 1
		return {}
	var signature: Array = [source.get_rid().get_id(), material.shader.get_rid().get_id(), extent, stretch_mode]
	var uniforms: Dictionary = {}
	for parameter: StringName in PARAMETERS:
		var value: Variant = material.get_shader_parameter(parameter)
		uniforms[parameter] = DEFAULT_PARAMETERS.get(parameter) if value == null else value
	# Zero-strength clocks and hidden rims cannot change acquired body pixels.
	# Canonicalize them so contact release and ordinary poses reuse the same cell.
	if is_zero_approx(float(uniforms[&"bend"])):
		uniforms[&"beat"] = 0.0
	if is_zero_approx(float(uniforms[&"contact_strength"])):
		uniforms[&"contact_direction"] = Vector2.ZERO
		uniforms[&"contact_match"] = false
	if is_zero_approx(float(uniforms[&"rim_strength"])):
		for parameter: StringName in [&"rim_color", &"rim_width", &"rim_uv"]:
			uniforms[parameter] = DEFAULT_PARAMETERS[parameter]
	if is_zero_approx(float(uniforms[&"completion_strength"])):
		uniforms[&"completion_glint"] = -2.0
	var mesh_scale: float = 1.0 + smoothstep(0.35, 0.7, float(uniforms[&"completion_strength"])) * 0.32
	var capture_extent := Vector2(extent) * mesh_scale
	if ceili(capture_extent.x) > CELL_EDGE - PADDING * 2 or ceili(capture_extent.y) > CELL_EDGE - PADDING * 2:
		_fallbacks += 1
		return {}
	for parameter: StringName in PARAMETERS:
		var value: Variant = uniforms[parameter]
		signature.append(value.get_rid().get_id() if value is Texture2D else value)
	var key: String = var_to_bytes(signature).hex_encode()
	_clock += 1
	if _entries.has(key):
		_hits += 1
		if not bool(_entries[key].ready) and not _pending.has(key) and not _rendering.has(key):
			_pending.append(key)
	else:
		var slot: int = _available_slot()
		if slot < 0:
			_fallbacks += 1
			return {}
		_misses += 1
		_entries[key] = {"slot": slot, "source": source, "shader": material.shader,
			"uniforms": uniforms, "extent": extent, "stretch_mode": stretch_mode,
			"mesh_scale": mesh_scale, "capture_extent": capture_extent,
			"owners": {}, "ready": false, "texture": null, "display_material": null, "used": _clock}
		_pending.append(key)
	var id: int = owner.get_instance_id()
	if _owners.has(id) and _owners[id] != key:
		release(owner)
	_owners[id] = key
	_entries[key].owners[id] = weakref(owner)
	_entries[key].used = _clock
	_unused_age = 0.0
	set_process(not _pending.is_empty() or not _rendering.is_empty())
	return {"key": key, "texture": _entries[key].texture if bool(_entries[key].ready) else null,
		"material": _entries[key].display_material if bool(_entries[key].ready) else null}

func release(owner: Node) -> void:
	var id: int = owner.get_instance_id()
	if not _owners.has(id):
		return
	var key: String = _owners[id]
	_owners.erase(id)
	if _entries.has(key):
		_entries[key].owners.erase(id)
	if _owners.is_empty():
		_unused_age = 0.0
		set_process(true)

func _available_slot() -> int:
	if _entries.size() < CELL_COUNT:
		var used: Dictionary = {}
		for entry: Dictionary in _entries.values():
			used[int(entry.slot)] = true
		for slot in range(CELL_COUNT):
			if not used.has(slot):
				return slot
	var oldest: String = ""
	var oldest_clock: int = _clock + 1
	for key: String in _entries:
		var entry: Dictionary = _entries[key]
		for id: int in entry.owners.keys():
			if entry.owners[id].get_ref() == null:
				entry.owners.erase(id)
				_owners.erase(id)
		if entry.owners.is_empty() and not _rendering.has(key) and int(entry.used) < oldest_clock:
			oldest = key
			oldest_clock = int(entry.used)
	if oldest.is_empty():
		return -1
	var slot: int = int(_entries[oldest].slot)
	_entries.erase(oldest)
	_pending.erase(oldest)
	return slot

func _process(delta: float) -> void:
	if _owners.is_empty():
		_unused_age += delta
		if _unused_age >= UNUSED_SECONDS and _rendering.is_empty():
			queue_free()
			return
	if not _rendering.is_empty():
		return
	while not _pending.is_empty() and _rendering.size() < WARM_PER_FRAME:
		var key: String = _pending.pop_front()
		if not _entries.has(key):
			continue
		var entry: Dictionary = _entries[key]
		if entry.owners.is_empty():
			continue
		_prepare_cell(key, entry)
	if _rendering.is_empty():
		set_process(_owners.is_empty())
		return
	_atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_finish_bake, CONNECT_ONE_SHOT)

func _prepare_cell(key: String, entry: Dictionary) -> void:
	var origin := Vector2i(int(entry.slot) % 8, floori(float(entry.slot) / 8.0)) * CELL_EDGE
	var clear := ColorRect.new()
	clear.position = Vector2(origin)
	clear.size = Vector2.ONE * CELL_EDGE
	clear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _clear_material == null:
		_clear_material = ShaderMaterial.new()
		_clear_material.shader = CLEAR_SHADER
	clear.material = _clear_material
	_atlas.add_child(clear)
	_bake_nodes.append(clear)
	var paint := TextureRect.new()
	paint.texture = entry.source
	paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paint.stretch_mode = int(entry.stretch_mode)
	paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logical_size: Vector2 = entry.uniforms[&"surface_size"]
	var capture_origin := Vector2(origin + Vector2i.ONE * PADDING)
	# The authored shader expands around its logical surface center. Rasterize
	# in that coordinate system, then scale once into backing pixels so every
	# directional light and the entire padded glow fit inside the atlas cell.
	paint.size = logical_size
	paint.scale = Vector2(entry.extent) / logical_size
	paint.position = capture_origin + (Vector2(entry.capture_extent) - Vector2(entry.extent)) * 0.5
	var material := ShaderMaterial.new()
	material.shader = entry.shader
	for parameter: StringName in entry.uniforms:
		if entry.uniforms[parameter] != null:
			material.set_shader_parameter(parameter, entry.uniforms[parameter])
	paint.material = material
	_atlas.add_child(paint)
	_bake_nodes.append(paint)
	var texture := AtlasTexture.new()
	texture.atlas = _atlas.get_texture()
	texture.region = Rect2(capture_origin, Vector2(entry.capture_extent))
	texture.filter_clip = true
	entry.texture = texture
	if is_equal_approx(float(entry.mesh_scale), 1.0):
		entry.display_material = display_material()
	else:
		# Entry-owned variants are bounded by the atlas capacity and reused by
		# identical targets. Ordinary bodies keep the shared display material.
		var display := ShaderMaterial.new()
		display.shader = DISPLAY_SHADER
		display.set_shader_parameter("surface_size", logical_size)
		display.set_shader_parameter("mesh_scale", float(entry.mesh_scale))
		entry.display_material = display
	_rendering.append(key)

func _finish_bake() -> void:
	for node: Control in _bake_nodes:
		node.queue_free()
	_bake_nodes.clear()
	for key: String in _rendering:
		if not _entries.has(key):
			continue
		var entry: Dictionary = _entries[key]
		entry.ready = true
		_bakes += 1
		for id: int in entry.owners.keys():
			var owner: Node = entry.owners[id].get_ref()
			if is_instance_valid(owner) and not owner.is_queued_for_deletion():
				owner.call("_idle_cache_ready", key, entry.texture, entry.display_material)
			else:
				entry.owners.erase(id)
				_owners.erase(id)
	_rendering.clear()
	set_process(not _pending.is_empty() or _owners.is_empty())

func _viewport_changed() -> void:
	# Pixel resolution and rims depend on the canvas size and display scale.
	var clients: Array[WeakRef] = []
	for key: String in _entries:
		for client: WeakRef in _entries[key].owners.values():
			clients.append(client)
	for client: WeakRef in clients:
		var owner: Node = client.get_ref()
		if is_instance_valid(owner):
			owner.call("_invalidate_idle_cache")

func snapshot() -> Dictionary:
	var ready: int = 0
	for entry: Dictionary in _entries.values():
		ready += int(entry.ready)
	return {"entries": _entries.size(), "ready": ready, "pending": _pending.size(),
		"warming": _rendering.size(), "owners": _owners.size(), "hits": _hits,
		"misses": _misses, "fallbacks": _fallbacks, "bakes": _bakes,
		"capacity": CELL_COUNT, "warm_per_frame": WARM_PER_FRAME,
		"bytes": ATLAS_EDGE * ATLAS_EDGE * 4 if _atlas != null else 0}

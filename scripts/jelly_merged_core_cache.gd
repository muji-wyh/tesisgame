extends Node
## Bounded GPU captures of frozen merged artwork, retaining original source nodes.

const DISPLAY = preload("res://scripts/jelly_merged_core.gdshader")
const CLEAR = preload("res://scripts/jelly_idle_clear.gdshader")
const ATLAS_EDGE: int = 2048
const CELL_EDGE: int = 256
const PADDING: int = 2
const CAPACITY: int = 64
const WARM_PER_FRAME: int = 2
const UNUSED_SECONDS: float = 2.0
const POOL_NAME := "JellyMergedCoreAtlas"

static var _display_material: ShaderMaterial
static var _clear_material: ShaderMaterial
var _atlas: SubViewport
var _entries: Dictionary = {}
var _owners: Dictionary = {}
var _pending: Array[String] = []
var _rendering: Array[String] = []
var _bake_nodes: Array[Node] = []
var _tint_watch: Dictionary = {}
var _clock: int = 0
var _unused_age: float = 0.0
var _bakes: int = 0
var _fallbacks: int = 0
var _tint_checks: int = 0
var _diagnostic_enabled: bool = false
var _diagnostic_capture: Dictionary = {}


static func display_material() -> ShaderMaterial:
	if _display_material == null:
		_display_material = ShaderMaterial.new()
		_display_material.shader = DISPLAY
	return _display_material


static func obtain(viewport: Viewport):
	if DisplayServer.get_name() == "headless":
		return null
	var pool: Node = viewport.get_node_or_null(NodePath(POOL_NAME))
	if pool == null:
		pool = load("res://scripts/jelly_merged_core_cache.gd").new()
		pool.name = POOL_NAME
		viewport.add_child(pool)
	return pool


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 999000
	set_process(false)


func _ready() -> void:
	_atlas = SubViewport.new()
	_atlas.name = "Paint"
	_atlas.size = Vector2i.ONE * ATLAS_EDGE
	_atlas.transparent_bg = true
	_atlas.disable_3d = true
	_atlas.gui_disable_input = true
	_atlas.oversampling_override = get_parent().get_oversampling()
	_atlas.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_atlas.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_atlas.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_atlas)
	get_parent().size_changed.connect(_viewport_changed)


func request(owner: Node, revision: int) -> Dictionary:
	var id: int = owner.get_instance_id()
	var key: String = "%d:%d" % [id, revision]
	if _owners.has(id) and _owners[id] != key:
		release(owner)
	_clock += 1
	if not _entries.has(key):
		var slot: int = _available_slot()
		if slot < 0:
			_fallbacks += 1
			return {}
		_entries[key] = {"slot": slot, "owner": weakref(owner), "ready": false,
			"texture": null, "bounds": Rect2(), "used": _clock}
		_pending.append(key)
	_owners[id] = key
	_entries[key].used = _clock
	_watch_tints(owner)
	_unused_age = 0.0
	set_process(true)
	return {"key": key, "texture": _entries[key].texture if bool(_entries[key].ready) else null,
		"bounds": _entries[key].bounds}


func release(owner: Node) -> void:
	var id: int = owner.get_instance_id()
	_owners.erase(id)
	for watched: Dictionary in _tint_watch.values():
		watched.owners.erase(id)
	set_process(true)


func _available_slot() -> int:
	if _entries.size() < CAPACITY:
		var used: Dictionary = {}
		for entry: Dictionary in _entries.values():
			used[int(entry.slot)] = true
		for slot in range(CAPACITY):
			if not used.has(slot):
				return slot
	var oldest: String = ""
	var oldest_clock: int = _clock + 1
	for key: String in _entries:
		var entry: Dictionary = _entries[key]
		var owner: Node = entry.owner.get_ref()
		var active: bool = is_instance_valid(owner) and _owners.get(owner.get_instance_id(), "") == key
		if not active and not _rendering.has(key) and int(entry.used) < oldest_clock:
			oldest = key
			oldest_clock = int(entry.used)
	if oldest.is_empty():
		return -1
	var slot: int = int(_entries[oldest].slot)
	_entries.erase(oldest)
	_pending.erase(oldest)
	return slot


func _watch_tints(owner: Node) -> void:
	var id: int = owner.get_instance_id()
	var subject: Node = owner
	while subject is CanvasItem:
		var canvas: CanvasItem = subject
		var subject_id: int = canvas.get_instance_id()
		if not _tint_watch.has(subject_id):
			_tint_watch[subject_id] = {"node": weakref(canvas), "color": canvas.modulate, "owners": {}}
		_tint_watch[subject_id].owners[id] = weakref(owner)
		subject = subject.get_parent()
	var visual: CanvasItem = owner.get("_visual")
	if visual != null:
		var visual_id: int = visual.get_instance_id()
		if not _tint_watch.has(visual_id):
			_tint_watch[visual_id] = {"node": weakref(visual), "color": visual.modulate, "owners": {}}
		_tint_watch[visual_id].owners[id] = weakref(owner)


func _check_tints() -> void:
	var changed: Dictionary = {}
	for id: int in _tint_watch.keys():
		var watched: Dictionary = _tint_watch[id]
		var subject: CanvasItem = watched.node.get_ref()
		if not is_instance_valid(subject) or watched.owners.is_empty():
			_tint_watch.erase(id)
			continue
		_tint_checks += 1
		if subject.modulate != watched.color:
			watched.color = subject.modulate
			changed.merge(watched.owners, true)
	for reference: WeakRef in changed.values():
		var owner: Node = reference.get_ref()
		if is_instance_valid(owner):
			owner.call("_invalidate_merged_core")
			owner.call("_request_merged_core")


func _process(delta: float) -> void:
	_check_tints()
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
		var owner: Node = _entries[key].owner.get_ref()
		if not is_instance_valid(owner) or _owners.get(owner.get_instance_id(), "") != key \
			or not bool(owner.call("_merged_core_eligible")):
			continue
		_prepare_cell(key, owner)
	if _rendering.is_empty():
		return
	_atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_finish_bake, CONNECT_ONE_SHOT)


func _prepare_cell(key: String, owner: Node) -> void:
	var capture: Dictionary = owner.call("_capture_merged_core")
	var bounds: Rect2 = capture.get("bounds", Rect2())
	if not bounds.has_area() or bounds.size.x > CELL_EDGE - PADDING * 2 \
		or bounds.size.y > CELL_EDGE - PADDING * 2:
		_fallbacks += 1
		owner.call("_reject_merged_core")
		return
	var entry: Dictionary = _entries[key]
	var origin := Vector2i(int(entry.slot) % 8, floori(float(entry.slot) / 8.0)) * CELL_EDGE
	var clear := ColorRect.new()
	clear.position = Vector2(origin)
	clear.size = Vector2.ONE * CELL_EDGE
	clear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear.z_index = -1
	if _clear_material == null:
		_clear_material = ShaderMaterial.new()
		_clear_material.shader = CLEAR
	clear.material = _clear_material
	_atlas.add_child(clear)
	RenderingServer.canvas_item_set_draw_index(clear.get_canvas_item(), clear.get_index())
	_bake_nodes.append(clear)
	var paint_origin := Vector2(origin + Vector2i.ONE * PADDING)
	var diagnose: bool = _diagnostic_enabled and _diagnostic_capture.is_empty()
	if diagnose:
		_diagnostic_capture = {"bounds": bounds, "paint_origin": paint_origin,
			"atlas_size": _atlas.size, "sources": []}
	for source: Dictionary in capture.sources:
		var wrapper := Node2D.new()
		var transform: Transform2D = source.transform
		transform.origin += paint_origin - bounds.position
		wrapper.transform = transform
		_atlas.add_child(wrapper)
		# New viewport roots receive their scene order on a later deferred pass.
		# Establish it before the one-shot capture so every source composites in order.
		RenderingServer.canvas_item_set_draw_index(wrapper.get_canvas_item(), wrapper.get_index())
		_bake_nodes.append(wrapper)
		var original: Control = source.node
		var copy: Control = original.duplicate(0)
		for child: Node in copy.get_children():
			copy.remove_child(child)
			child.free()
		copy.set_anchors_preset(Control.PRESET_TOP_LEFT)
		copy.position = Vector2.ZERO
		copy.rotation = 0.0
		copy.scale = Vector2.ONE
		copy.pivot_offset = Vector2.ZERO
		copy.size = original.size
		copy.z_index = 0
		copy.modulate = source.color
		copy.self_modulate = Color.WHITE
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if original.material is ShaderMaterial:
			copy.material = original.material.duplicate()
		var texture_original: TextureRect = original as TextureRect
		var texture_copy: TextureRect = copy as TextureRect
		if texture_original != null and texture_original.texture is AtlasTexture:
			texture_copy.texture = texture_original.texture.duplicate()
		wrapper.add_child(copy)
		if diagnose:
			var diagnostic: Dictionary = {"name": original.name, "class": copy.get_class(),
				"source_transform": source.transform, "wrapper_transform": wrapper.transform,
				"copy_global": copy.get_global_transform(), "copy_visible": copy.is_visible_in_tree(),
				"copy_size": copy.size, "copy_position": copy.position, "copy_top_level": copy.top_level,
				"copy_layout_mode": copy.get("layout_mode"), "copy_visibility_layer": copy.visibility_layer,
				"copy_modulate": copy.modulate, "copy_self_modulate": copy.self_modulate, "draws": 0}
			_diagnostic_capture.sources.append(diagnostic)
			copy.draw.connect(func() -> void: diagnostic.draws += 1)
	var texture := AtlasTexture.new()
	texture.atlas = _atlas.get_texture()
	texture.region = Rect2(paint_origin, bounds.size)
	texture.filter_clip = true
	entry.texture = texture
	entry.bounds = bounds
	_rendering.append(key)


func _finish_bake() -> void:
	for node: Node in _bake_nodes:
		node.queue_free()
	_bake_nodes.clear()
	for key: String in _rendering:
		if not _entries.has(key):
			continue
		var entry: Dictionary = _entries[key]
		var owner: Node = entry.owner.get_ref()
		entry.ready = true
		_bakes += 1
		if is_instance_valid(owner) and _owners.get(owner.get_instance_id(), "") == key:
			owner.call("_merged_core_ready", key, entry.texture, entry.bounds)
	_rendering.clear()


func _viewport_changed() -> void:
	_atlas.oversampling_override = get_parent().get_oversampling()
	for id: int in _owners.keys():
		var owner: Node = _entries[_owners[id]].owner.get_ref()
		if is_instance_valid(owner):
			owner.call("_invalidate_merged_core")


func snapshot() -> Dictionary:
	return {"entries": _entries.size(), "owners": _owners.size(), "pending": _pending.size(),
		"warming": _rendering.size(), "bakes": _bakes, "fallbacks": _fallbacks,
		"capacity": CAPACITY, "warm_per_frame": WARM_PER_FRAME, "tint_checks": _tint_checks,
		"bytes": ATLAS_EDGE * ATLAS_EDGE * 4 if _atlas != null else 0}

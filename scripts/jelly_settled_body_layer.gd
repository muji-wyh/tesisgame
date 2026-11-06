extends Node2D
## Shared cached skins for ordinary settled Word Jelly bodies.
## Learning faces and shadows retain their original nodes and ordering.

const Cache = preload("res://scripts/jelly_idle_body_cache.gd")
const Tile = preload("res://scripts/word_jelly_tile.gd")

var _tracked: Dictionary = {}
var _dirty: Dictionary = {}
var _paint: Dictionary = {}
var _order: Array[int] = []
var _blockers: Dictionary = {}
var _occluded: Dictionary = {}
var _blockers_dirty: bool = true
var _visibility_depth: int = 0
var _drawing: bool = false
var _draws: int = 0


func _init() -> void:
	name = "WordJellySettledBodies"
	z_index = 1
	material = Cache.display_material()


func watch(tile: Tile) -> void:
	var id: int = tile.get_instance_id()
	if _tracked.has(id):
		return
	var callbacks: Array[Dictionary] = []
	for subject: CanvasItem in [tile, tile._visual, tile._surface]:
		for event: StringName in [&"visibility_changed", &"item_rect_changed"]:
			var callback: Callable = _changed.bind(id)
			subject.connect(event, callback)
			callbacks.append({"subject": weakref(subject), "event": event, "callback": callback})
	var paint_callback: Callable = _paint_changed.bind(id)
	tile.idle_paint_changed.connect(paint_callback)
	callbacks.append({"subject": weakref(tile), "event": &"idle_paint_changed", "callback": paint_callback})
	var pose_callback: Callable = _paint_changed.bind(id)
	tile.idle_pose_changed.connect(pose_callback)
	callbacks.append({"subject": weakref(tile), "event": &"idle_pose_changed", "callback": pose_callback})
	var exit_callback: Callable = forget.bind(tile)
	tile.tree_exiting.connect(exit_callback)
	callbacks.append({"subject": weakref(tile), "event": &"tree_exiting", "callback": exit_callback})
	_tracked[id] = {"tile": weakref(tile), "allowed": true, "callbacks": callbacks}
	_order.append(id)
	_changed(id)


func refresh(tile: Tile, allowed: bool = true) -> void:
	watch(tile)
	var id: int = tile.get_instance_id()
	if bool(_tracked[id].allowed) == allowed:
		if not allowed or tile.valid_word or not _paint.has(id):
			return
		# CanvasItem tint properties have no change signal. Preserve direct tint
		# updates while rectangle, visibility and cache changes use their watchers.
		var tint: Array = _paint[id].tint_inputs
		if tint[0] == tile._surface.self_modulate and tint[1] == tile._surface.modulate \
			and tint[2] == tile._visual.modulate and tint[3] == tile.modulate:
			return
	else:
		_tracked[id].allowed = allowed
	if not allowed:
		_remove_paint(id)
	_changed(id)


func forget(tile: Tile) -> void:
	var id: int = tile.get_instance_id()
	if not _tracked.has(id):
		return
	_remove_paint(id)
	for connection: Dictionary in _tracked[id].callbacks:
		var subject: Object = connection.subject.get_ref()
		if is_instance_valid(subject) and subject.is_connected(connection.event, connection.callback):
			subject.disconnect(connection.event, connection.callback)
	_tracked.erase(id)
	_dirty.erase(id)
	_order.erase(id)
	_occluded.erase(id)
	if _blockers.has(id):
		_blockers_dirty = true
		if not _drawing and (not _paint.is_empty() or not _occluded.is_empty()):
			queue_redraw()


func _changed(id: int) -> void:
	if _visibility_depth > 0 or not _tracked.has(id):
		return
	var tile: Tile = _tracked[id].tile.get_ref()
	if is_instance_valid(tile) and (tile.valid_word or _blockers.has(id)):
		_blockers_dirty = true
		if not tile.valid_word:
			_dirty[id] = true
		# Moving merged effects can change occlusion without owning a batch stamp.
		# Empty and merged-only boards need no retained body redraws.
		if not _drawing and (not _paint.is_empty() or not _occluded.is_empty()):
			queue_redraw()
		return
	if not _paint.has(id) and (not bool(_tracked[id].allowed) or not is_instance_valid(tile) \
		or not tile._idle_cache_requested or tile._surface.material != material):
		return
	_dirty[id] = true
	if not _drawing:
		queue_redraw()


func _paint_changed(id: int) -> void:
	if not _tracked.has(id):
		return
	var tile: Tile = _tracked[id].tile.get_ref()
	# Feedback restores its original live surface in the same call stack.
	if not is_instance_valid(tile) or not tile._idle_cache_requested:
		_remove_paint(id)
	_changed(id)


func _eligible(tile: Tile, allowed: bool) -> bool:
	return allowed and is_instance_valid(tile) and tile.get_parent() == get_parent() \
		and tile.is_visible_in_tree() and tile._visual.is_visible_in_tree() \
		and not tile.valid_word and tile.z_index == 1 and tile.z_as_relative \
		and tile._visual.z_index == 0 and tile._surface.z_index == 0 \
		and not tile.clip_contents and not tile._visual.clip_contents \
		and not tile.highlighted and not tile.selected and not tile.has_focus() \
		and not tile.is_hovered() and tile._idle_cache_requested \
		and tile._surface.material == material and tile._surface.texture is AtlasTexture \
		and tile._surface.stretch_mode == TextureRect.STRETCH_SCALE \
		and tile._idle_cache_eligible()


func _remove_paint(id: int) -> void:
	if not _paint.has(id):
		return
	_paint.erase(id)
	if _tracked.has(id):
		var tile: Tile = _tracked[id].tile.get_ref()
		if is_instance_valid(tile):
			_visibility_depth += 1
			tile._surface.show()
			_visibility_depth -= 1
	if not _drawing:
		queue_redraw()


func _sync_dirty() -> void:
	_sync_blockers()
	var changed: Array = _dirty.keys()
	_dirty.clear()
	for id: int in changed:
		if not _tracked.has(id):
			continue
		var tile: Tile = _tracked[id].tile.get_ref()
		# A released ordinary tile can have moved while merged bounds stayed fixed.
		if is_instance_valid(tile) and not tile.valid_word:
			if _is_occluded(tile):
				_occluded[id] = true
			else:
				_occluded.erase(id)
		if not _eligible(tile, bool(_tracked[id].allowed)) or _occluded.has(id) \
			or (not tile._surface.visible and not _paint.has(id)):
			_remove_paint(id)
			continue
		var surface: TextureRect = tile._surface
		var transform: Transform2D = _render_transform(surface)
		var tint: Color = surface.self_modulate
		var ancestor: CanvasItem = surface
		while ancestor != get_parent():
			tint *= ancestor.modulate
			ancestor = ancestor.get_parent() as CanvasItem
		_paint[id] = {"transform": transform,
			"texture": surface.texture, "size": surface.size, "color": tint,
			"tint_inputs": [surface.self_modulate, surface.modulate, tile._visual.modulate, tile.modulate]}
		_visibility_depth += 1
		surface.hide()
		_visibility_depth -= 1


func _render_transform(control: Control) -> Transform2D:
	var transform := Transform2D.IDENTITY
	var ancestor: CanvasItem = control
	var snap: bool = get_viewport().is_snap_controls_to_pixels_enabled()
	while ancestor != get_parent():
		var local: Transform2D = ancestor.get_transform()
		# Control rounds its render origin separately from get_transform().
		# Match each local node before composing the retained drawing transform.
		var gui: Control = ancestor as Control
		if snap and gui != null and absf(sin(gui.rotation * 4.0)) < 0.00001:
			local.origin = (local.origin + Vector2(0.5, 0.5)).floor()
		transform = local * transform
		ancestor = ancestor.get_parent() as CanvasItem
	return get_transform().affine_inverse() * transform


func _canvas_rect(control: Control, expansion: float = 1.0) -> Rect2:
	var extent: Vector2 = control.size * expansion
	var transform: Transform2D = _render_transform(control)
	return transform * Rect2((control.size - extent) * 0.5, extent)


func _is_occluded(tile: Tile) -> bool:
	var bounds: Rect2 = _canvas_rect(tile._surface)
	for blocker: Rect2 in _blockers.values():
		if bounds.intersects(blocker, true):
			return true
	return false


func _sync_blockers() -> void:
	if not _blockers_dirty:
		return
	_blockers_dirty = false
	var blockers: Dictionary = {}
	for id: int in _order:
		var tile: Tile = _tracked[id].tile.get_ref()
		if not is_instance_valid(tile) or not tile.valid_word or not tile.is_visible_in_tree():
			continue
		# Include the expanded acquired skin and every fixed readiness effect.
		# Keep neighboring ordinary skins in their original sibling order when
		# any of this paint could overlap them, regardless of the current frame.
		var bounds: Rect2 = _canvas_rect(tile._surface, 1.32)
		if tile._merged_glow != null and tile._merged_glow.visible:
			bounds = bounds.merge(_canvas_rect(tile._merged_glow))
		if tile._merged_effect != null and tile._merged_effect.visible:
			bounds = bounds.merge(_canvas_rect(tile._merged_effect))
		blockers[id] = bounds
	if blockers == _blockers:
		return
	_blockers = blockers
	var occluded: Dictionary = {}
	for id: int in _order:
		var tile: Tile = _tracked[id].tile.get_ref()
		if not is_instance_valid(tile) or tile.valid_word:
			continue
		if _is_occluded(tile):
			occluded[id] = true
		if occluded.has(id) != _occluded.has(id):
			_dirty[id] = true
	_occluded = occluded


func _draw() -> void:
	_draws += 1
	_drawing = true
	_sync_dirty()
	for id: int in _order:
		if not _paint.has(id):
			continue
		var paint: Dictionary = _paint[id]
		draw_set_transform_matrix(paint.transform)
		draw_texture_rect(paint.texture, Rect2(Vector2.ZERO, paint.size), false, paint.color)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_drawing = false


func snapshot() -> Dictionary:
	return {"tracked": _tracked.size(), "bodies": _paint.size(), "dirty": _dirty.size(),
		"occluded": _occluded.size(), "draws": _draws}


func _exit_tree() -> void:
	for id: int in _order.duplicate():
		var tile: Tile = _tracked[id].tile.get_ref()
		if is_instance_valid(tile):
			forget(tile)

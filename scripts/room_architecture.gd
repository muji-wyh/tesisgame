extends Control
## Rasterize only the unchanged room architecture, at the current device resolution.
## Toys, ground shadows, Pip, and interaction effects remain live sibling nodes.

const Interior = preload("res://scripts/room_interior.gd")
const MAX_RASTER_SIDE := 4096
const RASTER_PADDING := 2.0
const UV_BIAS := Vector2(0.00001, 0.00001)

class RoomCanvas extends Control:
	var palette: Dictionary = {}
	var theme_id: String = "home"

	func _draw() -> void:
		Interior.draw_room(self, palette, theme_id)

var _palette: Dictionary = {}
var _theme_id: String = "home"
var _viewport: SubViewport
var _source: RoomCanvas
var _premultiplied: CanvasItemMaterial
var _signature: Dictionary = {}
var _candidate_signature: Dictionary = {}
var _stable_frames := 0
var _texture_rect := Rect2()
var _dirty := true
var _pending := false
var _using_cache := false
var _render_revision := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(invalidate)
	visibility_changed.connect(_visibility_changed)


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_viewport = SubViewport.new()
		_viewport.name = "StaticRoomRaster"
		_viewport.disable_3d = true
		_viewport.transparent_bg = true
		_viewport.gui_disable_input = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		add_child(_viewport)
		_source = RoomCanvas.new()
		_source.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_viewport.add_child(_source)
		_premultiplied = CanvasItemMaterial.new()
		_premultiplied.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		RenderingServer.frame_post_draw.connect(_frame_rendered)
	_visibility_changed()


func configure(palette: Dictionary, theme_id: String) -> void:
	if _palette == palette and _theme_id == theme_id:
		return
	_palette = palette.duplicate(true)
	_theme_id = theme_id
	invalidate()


func invalidate() -> void:
	_dirty = true
	_set_cached(false)
	queue_redraw()


func _process(_delta: float) -> void:
	_sync_cache()


func _visibility_changed() -> void:
	set_process(_viewport != null and is_visible_in_tree())
	if _viewport == null:
		return
	if is_visible_in_tree():
		_sync_cache(false)
	elif _pending:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_pending = false
		_dirty = true


func _raster_geometry(screen: Transform2D) -> Dictionary:
	# Rotated, mirrored, or skewed controls retain their original drawing path.
	if not is_zero_approx(screen.x.y) or not is_zero_approx(screen.y.x):
		return {}
	var pixel_scale := Vector2(screen.x.x, screen.y.y)
	if pixel_scale.x <= 0.0 or pixel_scale.y <= 0.0 or size.x < 4.0 or size.y < 4.0:
		return {}
	var offset := screen.origin - screen.origin.floor() + Vector2.ONE * RASTER_PADDING
	var pixels := Vector2i((offset + size * pixel_scale + Vector2.ONE * RASTER_PADDING).ceil())
	if pixels.x > MAX_RASTER_SIDE or pixels.y > MAX_RASTER_SIDE:
		return {}
	return {"size": size, "scale": pixel_scale, "offset": offset, "pixels": pixels}


func _opaque_modulation() -> bool:
	# Fading individual overlapping primitives differs from fading a finished image.
	# Keep the live path during ancestor fades to preserve its exact compositing.
	if not is_equal_approx(self_modulate.a, 1.0):
		return false
	var ancestor: Node = self
	while ancestor != null:
		if ancestor is CanvasLayer or ancestor is Viewport:
			break
		var item := ancestor as CanvasItem
		if item != null:
			if not is_equal_approx(item.modulate.a, 1.0):
				return false
			if item.is_set_as_top_level():
				break
		ancestor = ancestor.get_parent()
	return true


func _sync_cache(count_stability: bool = true) -> void:
	if _viewport == null or not is_visible_in_tree():
		return
	var next := _raster_geometry(get_screen_transform()) if _opaque_modulation() else {}
	if next.is_empty():
		_set_cached(false)
		_dirty = true
		_pending = false
		_candidate_signature.clear()
		_stable_frames = 0
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	next["msaa"] = get_viewport().msaa_2d
	if not _dirty and next == _signature:
		return
	if next != _candidate_signature:
		# Continuous scrolling/resizing draws only the live art. Capture once after
		# the device geometry settles, rather than rendering both paths every tick.
		_candidate_signature = next
		_stable_frames = 0
		_dirty = true
		_pending = false
		_set_cached(false)
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if count_stability:
		_stable_frames += 1
	if _stable_frames < 2:
		return
	_signature = next
	_dirty = false
	_pending = true
	_set_cached(false)
	_source.size = size
	_source.palette = _palette
	_source.theme_id = _theme_id
	_viewport.size = next.pixels
	_viewport.msaa_2d = next.msaa
	_source.scale = next.scale
	_source.position = next.offset
	_texture_rect = Rect2(-next.offset / next.scale, Vector2(next.pixels) / next.scale)
	_source.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_render_revision += 1


func _frame_rendered() -> void:
	if not _pending or _dirty or not is_visible_in_tree():
		return
	_pending = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_set_cached(true)


func _set_cached(enabled: bool) -> void:
	if _using_cache == enabled:
		return
	_using_cache = enabled
	material = _premultiplied if enabled else null
	queue_redraw()


func _draw() -> void:
	if _using_cache:
		# Explicit vertices avoid scaled texture-rect sampling errors in Compatibility.
		# The tiny UV bias stays inside each texel and prevents boundary rounding from
		# selecting an adjacent row (also used by Godot's pixel-snap shader path).
		var start := _texture_rect.position
		var end := _texture_rect.end
		draw_polygon(PackedVector2Array([start, Vector2(end.x, start.y), end, Vector2(start.x, end.y)]),
			PackedColorArray([Color.WHITE]), PackedVector2Array([UV_BIAS, Vector2.RIGHT + UV_BIAS, Vector2.ONE + UV_BIAS, Vector2.DOWN + UV_BIAS]), _viewport.get_texture())
	else:
		# A pending resize/theme change draws live until the new raster has rendered.
		Interior.draw_room(self, _palette, _theme_id)

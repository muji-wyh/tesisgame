extends Control
## Present only reviewed artwork, retaining at most two compositions in a fade.

const Media = preload("res://scripts/professional_media_access.gd")
const Resolver = preload("res://scripts/learning_content_resolver.gd")
const Motion = preload("res://scripts/learning_theme_motion.gd")
const PREVIEW_ROOT: String = "res://assets/images/professional-previews/"
const PREVIEW_MAX_SIDE: int = 512
const TRANSITION_SECONDS: float = 0.2

var _current: Control
var _previous: Control
var _transition: Tween
var _generation := 0
var _key := ""
var _theme_id := ""
var _ready_art := false
var _reduced := false
var _elapsed := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_current = _layer()
	_previous = _layer()
	set_process(false)
	hide()


func _layer() -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for role in ["environment", "props"]:
		var texture := TextureRect.new()
		texture.name = role
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(texture)
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ambient := Control.new()
	ambient.name = "ambient"
	ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ambient)
	ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.set_meta("clips", [])
	return layer


func show_profile(profile: Dictionary, role: String, reduced: bool = false) -> bool:
	var descriptor: Dictionary = profile.get("preview", {}) if role == "preview" else profile.get("art", {}).get(role, {})
	var props: Dictionary = profile.get("art", {}).get("props", {}) if role == "environment" else {}
	# Review and immutable-resource identity changes invalidate a cached view,
	# even when a profile retains the same display identity and path.
	var key: String = "%s:%s:%s:%s:%s" % [profile.get("id", ""), role, JSON.stringify(descriptor), JSON.stringify(props), JSON.stringify(profile.get("ambient_motion", {}))]
	_reduced = reduced
	if key == _key and _ready_art:
		if reduced:
			_finish_transition(_generation)
		_sync_motion()
		return _ready_art
	_key = key
	_theme_id = str(profile.get("id", ""))
	_generation += 1
	_stop_transition()
	var texture: Texture2D = _texture(descriptor, role == "preview")
	var motion: Dictionary = Motion.compile(profile) if role == "environment" else {"ok": true, "clips": []}
	var prepared: Array = []
	if motion.ok:
		for clip in motion.clips:
			var sheet: Texture2D = _texture(clip.image, false)
			if sheet == null or sheet.get_width() % int(clip.columns) != 0 or sheet.get_height() % int(clip.rows) != 0:
				motion.ok = false
				break
			prepared.append({"clip": clip, "sheet": sheet})
	if texture == null or not motion.ok:
		_clear_layer(_current)
		_clear_layer(_previous)
		_ready_art = false
		set_process(false)
		hide()
		return false
	_clear_layer(_previous)
	var spare: Control = _previous
	_previous = _current
	_current = spare
	move_child(_current, get_child_count() - 1)
	_current.get_node("environment").texture = texture
	_current.get_node("environment").stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if role == "preview" else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_current.get_node("props").texture = _texture(props, false)
	_elapsed = 0.0
	for item in prepared:
		var atlas := AtlasTexture.new()
		atlas.atlas = item.sheet
		atlas.filter_clip = true
		# Ambient patches share the source image's fractional cover transform.
		# Control pixel snapping would shift or stretch them against that image.
		var sprite := Sprite2D.new()
		sprite.name = str(item.clip.id)
		sprite.centered = false
		sprite.texture = atlas
		_current.get_node("ambient").add_child(sprite)
		_current.get_meta("clips").append({"spec": item.clip, "node": sprite, "frame": -1})
	_ready_art = true
	show()
	_layout_motion()
	_sync_motion()
	if reduced or not is_inside_tree():
		_finish_transition(_generation)
		return true
	_current.modulate.a = 0.0
	_previous.modulate.a = 1.0
	_transition = create_tween().set_parallel(true)
	_transition.tween_property(_current, "modulate:a", 1.0, TRANSITION_SECONDS)
	_transition.tween_property(_previous, "modulate:a", 0.0, TRANSITION_SECONDS)
	_transition.chain().tween_callback(_finish_transition.bind(_generation))
	return true


func _texture(descriptor: Dictionary, preview: bool) -> Texture2D:
	if not Resolver._media_ready(descriptor):
		return null
	var source: String = str(descriptor.get("path", ""))
	if Media.is_professional(source):
		return Media.resource(source) as Texture2D
	# Preview bytes and source hashes are checked during packaging. Loaded
	# textures remain local to the current/previous view rather than a global cache.
	if not preview or not source.begins_with(PREVIEW_ROOT) or source.contains("..") or source.contains("\\") \
		or not ResourceLoader.exists(source):
		return null
	var texture: Texture2D = ResourceLoader.load(source, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if texture == null or maxi(texture.get_width(), texture.get_height()) > PREVIEW_MAX_SIDE:
		return null
	return texture


func clear() -> void:
	_generation += 1
	_stop_transition()
	_clear_layer(_current)
	_clear_layer(_previous)
	_key = ""
	_theme_id = ""
	_ready_art = false
	_elapsed = 0.0
	set_process(false)
	hide()


func has_art() -> bool:
	return _ready_art


func snapshot() -> Dictionary:
	return {"theme_id": _theme_id, "ready": _ready_art, "transitioning": is_instance_valid(_transition) and _transition.is_running(),
		"current_images": _image_count(_current), "previous_images": _image_count(_previous),
		"motion_frames": _current.get_meta("clips").map(func(clip: Dictionary) -> int: return clip.frame),
		"motion_processing": is_processing()}


func _image_count(layer: Control) -> int:
	return int(layer.get_node("environment").texture != null) + int(layer.get_node("props").texture != null) + layer.get_meta("clips").size()


func _finish_transition(generation: int) -> void:
	if generation != _generation:
		return
	_stop_transition()
	_current.modulate.a = 1.0
	_clear_layer(_previous)


func _stop_transition() -> void:
	if is_instance_valid(_transition):
		_transition.kill()
	_transition = null


func _clear_layer(layer: Control) -> void:
	for role in ["environment", "props"]:
		layer.get_node(role).texture = null
	for sprite in layer.get_node("ambient").get_children():
		sprite.texture = null
		layer.get_node("ambient").remove_child(sprite)
		sprite.queue_free()
	layer.set_meta("clips", [])
	layer.modulate.a = 0.0


func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	_apply_frames()


func _sync_motion() -> void:
	if _current == null:
		return
	_apply_frames()
	set_process(_ready_art and not _reduced and is_visible_in_tree() and not _current.get_meta("clips").is_empty())


func _apply_frames() -> void:
	for clip in _current.get_meta("clips"):
		var spec: Dictionary = clip.spec
		var frame: int = int(spec.rest_frame) if _reduced else (int(floor(_elapsed * float(spec.frames_per_second))) + int(spec.rest_frame)) % int(spec.frame_count)
		if frame == clip.frame:
			continue
		var atlas: AtlasTexture = clip.node.texture
		var cell := Vector2(atlas.atlas.get_width() / float(spec.columns), atlas.atlas.get_height() / float(spec.rows))
		atlas.region = Rect2(Vector2(frame % int(spec.columns), frame / int(spec.columns)) * cell, cell)
		clip.frame = frame


func _layout_motion() -> void:
	for layer in [_current, _previous]:
		if layer == null or layer.get_node("environment").texture == null:
			continue
		var original: Vector2 = layer.get_node("environment").texture.get_size()
		var scale_factor: float = maxf(size.x / original.x, size.y / original.y)
		var covered: Vector2 = original * scale_factor
		var origin: Vector2 = (size - covered) * 0.5
		for clip in layer.get_meta("clips"):
			var rect: Array = clip.spec.rect
			clip.node.position = origin + Vector2(rect[0], rect[1]) * covered
			var atlas: AtlasTexture = clip.node.texture
			var cell := Vector2(atlas.atlas.get_width() / float(clip.spec.columns), atlas.atlas.get_height() / float(clip.spec.rows))
			clip.node.scale = Vector2(rect[2], rect[3]) * covered / cell


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_motion()
	elif what == NOTIFICATION_RESIZED:
		_layout_motion()


func _exit_tree() -> void:
	clear()

extends RefCounted
## Shared vocabulary atlas playback; every copy of a word uses one texture.

const FRAME_SIDE := 128
const COLUMNS := 8
const FPS := 24.0
const CLIPS := {
	"walk": [40, 19], "run": [20, 9], "jump": [64, 30],
	"open": [80, 62], "close": [80, 62], "drink": [80, 38],
	"eat": [80, 38], "hello": [72, 34]
}

static var _clips: Dictionary = {}
static var _reduced := false


static func texture(source: String, owner: CanvasItem = null) -> Texture2D:
	if source.is_empty():
		return null
	var path: String = source if source.begins_with("res://") else "res://" + source
	if not ResourceLoader.exists(path):
		return null
	var id: String = path.get_file().get_basename().trim_prefix("lv3-")
	if path != "res://assets/images/words/lv3-%s.png" % id or not CLIPS.has(id):
		return load(path) as Texture2D
	if not _clips.has(id):
		var sheet := load("res://assets/images/word-motion/%s.webp" % id) as Texture2D
		if sheet == null:
			return load(path) as Texture2D
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.filter_clip = true
		atlas.set_meta("word_art_source", path)
		atlas.set_meta("word_art_id", id)
		_clips[id] = {"texture": atlas, "frame": -1, "elapsed": 0.0, "owners": {}}
		_set_frame(_clips[id], int(CLIPS[id][1]) if _reduced else 0)
	var result: Texture2D = _clips[id].texture
	bind(result, owner)
	return result


static func bind(value: Texture2D, owner: CanvasItem) -> void:
	if value == null or owner == null or not value.has_meta("word_art_id"):
		return
	var id: String = value.get_meta("word_art_id")
	_clips[id].owners[owner.get_instance_id()] = weakref(owner)


static func source_path(value: Texture2D) -> String:
	return "" if value == null else str(value.get_meta("word_art_source", value.resource_path))


static func set_reduced_motion(value: bool) -> void:
	if _reduced == value:
		return
	_reduced = value
	for id: String in _clips:
		_clips[id].elapsed = 0.0
		_set_frame(_clips[id], int(CLIPS[id][1]) if value else 0)


static func advance(delta: float, playing: bool = true) -> void:
	if _reduced or not playing or not is_finite(delta) or delta <= 0.0:
		return
	for id: String in _clips:
		var clip: Dictionary = _clips[id]
		if not _has_visible_owner(clip):
			continue
		# Do not fast-forward a teaching action after a stalled browser frame.
		clip.elapsed = fmod(float(clip.elapsed) + minf(delta, 0.1), float(CLIPS[id][0]) / FPS)
		_set_frame(clip, int(float(clip.elapsed) * FPS) % int(CLIPS[id][0]))


static func _has_visible_owner(clip: Dictionary) -> bool:
	var visible := false
	for key: int in clip.owners.keys():
		var owner: CanvasItem = clip.owners[key].get_ref()
		if not is_instance_valid(owner):
			clip.owners.erase(key)
			continue
		# Answer slots and supply previews reuse controls for different words.
		if owner is TextureRect and owner.texture != clip.texture:
			continue
		if owner is Button and owner.icon != clip.texture:
			continue
		if not owner.is_visible_in_tree():
			continue
		if owner is Control:
			var rect: Rect2 = owner.get_global_rect()
			if not rect.intersects(owner.get_viewport_rect()):
				continue
			var parent: Node = owner.get_parent()
			var clipped := false
			while parent is CanvasItem:
				if parent is Control and parent.clip_contents and not rect.intersects(parent.get_global_rect()):
					clipped = true
					break
				parent = parent.get_parent()
			if clipped:
				continue
		visible = true
	return visible


static func _set_frame(clip: Dictionary, frame: int) -> void:
	if int(clip.frame) == frame:
		return
	clip.frame = frame
	clip.texture.region = Rect2((frame % COLUMNS) * FRAME_SIDE, (frame / COLUMNS) * FRAME_SIDE, FRAME_SIDE, FRAME_SIDE)

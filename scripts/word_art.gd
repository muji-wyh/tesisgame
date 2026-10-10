extends RefCounted
## Shared, visibility-driven vocabulary motion with bounded sheet residency.

const FRAME_SIDE := 128
const COLUMNS := 8
const FPS := 24.0
const CLIPS := {
	"walk": [40, 19], "run": [20, 9], "jump": [64, 30],
	"open": [80, 62], "close": [80, 62], "drink": [80, 38],
	"eat": [80, 38], "hello": [72, 34]
}
const MANIFEST := "res://data/word-motion.json"
const IDLE_SECONDS := 2.0
const MAX_RESIDENT_SHEETS := 64
const MAX_LOADS_PER_TICK := 4

static var _profiles: Dictionary = {}
static var _manifest_read := false
static var _clips: Dictionary = {}
static var _reduced := false


static func motion_catalog() -> Dictionary:
	_read_manifest()
	return _profiles.duplicate(true)


static func _read_manifest() -> void:
	if _manifest_read:
		return
	_manifest_read = true
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not manifest is Dictionary or not manifest.get("files") is Array:
		push_error("The vocabulary motion manifest is missing or invalid.")
		return
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9-]*$")
	for row: Variant in manifest.files:
		if not row is Dictionary or not row.get("id") is String or pattern.search(row.id) == null:
			_profiles.clear()
			push_error("Vocabulary motion needs a valid word identity.")
			return
		var numeric := true
		for field in ["frames", "fps", "frameSide", "columns", "posterFrame"]:
			var value: Variant = row.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)):
				numeric = false
		if not numeric or row.get("path") != "assets/images/word-motion/%s.webp" % row.id \
			or _profiles.has(row.id) or int(row.frames) < 2 or int(row.frames) > 512 \
			or int(row.fps) < 1 or int(row.fps) > 60 or int(row.frameSide) != FRAME_SIDE \
			or int(row.columns) != COLUMNS or int(row.posterFrame) < 0 or int(row.posterFrame) >= int(row.frames):
			_profiles.clear()
			push_error("Vocabulary motion contains an invalid or duplicate clip: " + str(row.id))
			return
		_profiles[row.id] = row.duplicate(true)


static func texture(source: String, owner: CanvasItem = null) -> Texture2D:
	if source.is_empty():
		return null
	var path: String = source if source.begins_with("res://") else "res://" + source
	if not ResourceLoader.exists(path):
		return null
	var id: String = path.get_file().get_basename()
	_read_manifest()
	if path != "res://assets/images/word-library/%s.webp" % id or not _profiles.has(id):
		return load(path) as Texture2D
	var result: AtlasTexture = _clips[id].texture.get_ref() if _clips.has(id) else null
	if result == null:
		result = AtlasTexture.new()
		result.filter_clip = true
		result.set_meta("word_art_source", path)
		result.set_meta("word_art_id", id)
		_clips[id] = {"texture": weakref(result), "source": path, "id": id,
			"frame": -1, "elapsed": 0.0, "idle": 0.0, "owners": {}, "loaded": false,
			"visible": false, "failed": false}
		_set_poster(_clips[id], result)
	bind(result, owner)
	return result


static func bind(value: Texture2D, owner: CanvasItem) -> void:
	if value == null or owner == null or not value.has_meta("word_art_id"):
		return
	var id: String = str(value.get_meta("word_art_id"))
	# A frozen Voice Pop slice duplicates the wrapper and must remain frozen.
	if not _clips.has(id) or _clips[id].texture.get_ref() != value:
		return
	_clips[id].owners[owner.get_instance_id()] = weakref(owner)


static func source_path(value: Texture2D) -> String:
	return "" if value == null else str(value.get_meta("word_art_source", value.resource_path))


static func set_reduced_motion(value: bool) -> void:
	if _reduced == value:
		return
	_reduced = value
	for id: String in _clips.keys():
		var clip: Dictionary = _clips[id]
		var atlas: AtlasTexture = clip.texture.get_ref()
		if atlas == null:
			_clips.erase(id)
			continue
		clip.elapsed = 0.0
		if bool(clip.loaded):
			_set_poster(clip, atlas)


static func advance(delta: float, playing: bool = true) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var active: Array[Dictionary] = []
	var residents := 0
	for id: String in _clips.keys():
		var clip: Dictionary = _clips[id]
		var atlas: AtlasTexture = clip.texture.get_ref()
		if atlas == null:
			_clips.erase(id)
			continue
		clip.visible = playing and not _reduced and _has_visible_owner(clip, atlas)
		clip.idle = 0.0 if bool(clip.visible) else float(clip.idle) + delta
		if bool(clip.loaded) and float(clip.idle) >= IDLE_SECONDS:
			_set_poster(clip, atlas)
		if bool(clip.loaded):
			residents += 1
		if bool(clip.visible):
			active.append(clip)
	var loaded_this_tick := 0
	for clip: Dictionary in active:
		var atlas: AtlasTexture = clip.texture.get_ref()
		if not bool(clip.loaded):
			if bool(clip.failed) or loaded_this_tick >= MAX_LOADS_PER_TICK:
				continue
			if residents >= MAX_RESIDENT_SHEETS:
				if not _evict_hidden_sheet():
					continue
				residents -= 1
			loaded_this_tick += 1
			if not _load_sheet(clip, atlas):
				continue
			residents += 1
		var profile: Dictionary = _profiles[clip.id]
		# Do not fast-forward a teaching action after a stalled browser frame.
		clip.elapsed = fmod(float(clip.elapsed) + minf(delta, 0.1), float(profile.frames) / float(profile.fps))
		_set_frame(clip, atlas, int(float(clip.elapsed) * float(profile.fps)) % int(profile.frames))


static func _poster_texture(path: String) -> Texture2D:
	var source := load(path) as Texture2D
	if source == null:
		return null
	var image: Image = source.get_image()
	if image == null or image.is_empty():
		return source
	if image.is_compressed():
		image.decompress()
	image.resize(FRAME_SIDE, FRAME_SIDE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


static func _set_poster(clip: Dictionary, atlas: AtlasTexture) -> void:
	# Replacing the only sheet reference releases it; frozen slices retain their
	# shallow copy only until their own short effect lifetime ends.
	atlas.atlas = _poster_texture(str(clip.source))
	atlas.region = Rect2(0, 0, FRAME_SIDE, FRAME_SIDE)
	clip.loaded = false
	clip.frame = -1


static func _load_sheet(clip: Dictionary, atlas: AtlasTexture) -> bool:
	var profile: Dictionary = _profiles[clip.id]
	var path := "res://" + str(profile.path)
	# Avoid an engine-cache owner keeping a retired multi-megabyte sheet alive.
	var sheet := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	var expected := Vector2(COLUMNS * FRAME_SIDE, ceili(float(profile.frames) / COLUMNS) * FRAME_SIDE)
	if sheet == null or sheet.get_size() != expected:
		clip.failed = true
		push_error("Missing or incomplete vocabulary motion sheet: " + str(clip.id))
		return false
	atlas.atlas = sheet
	clip.loaded = true
	clip.frame = -1
	return true


static func _evict_hidden_sheet() -> bool:
	var candidate: Dictionary = {}
	for clip: Dictionary in _clips.values():
		if bool(clip.loaded) and not bool(clip.visible) and (candidate.is_empty() or float(clip.idle) > float(candidate.idle)):
			candidate = clip
	if candidate.is_empty():
		return false
	var atlas: AtlasTexture = candidate.texture.get_ref()
	if atlas != null:
		_set_poster(candidate, atlas)
	return true


static func _has_visible_owner(clip: Dictionary, atlas: AtlasTexture) -> bool:
	var visible := false
	for key: int in clip.owners.keys():
		var owner: CanvasItem = clip.owners[key].get_ref()
		if not is_instance_valid(owner):
			clip.owners.erase(key)
			continue
		# Answer slots and supply previews reuse controls for different words.
		if (owner is TextureRect and owner.texture != atlas) or (owner is Button and owner.icon != atlas):
			clip.owners.erase(key)
			continue
		if not owner.is_visible_in_tree():
			continue
		if owner.has_method("is_word_art_visible") and not owner.call("is_word_art_visible", str(clip.id)):
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


static func _set_frame(clip: Dictionary, atlas: AtlasTexture, frame: int) -> void:
	if int(clip.frame) == frame:
		return
	clip.frame = frame
	atlas.region = Rect2((frame % COLUMNS) * FRAME_SIDE, (frame / COLUMNS) * FRAME_SIDE, FRAME_SIDE, FRAME_SIDE)


static func cache_snapshot() -> Dictionary:
	var ids: Array[String] = []
	var live := 0
	var owners := 0
	var bytes := 0
	for clip: Dictionary in _clips.values():
		var atlas: AtlasTexture = clip.texture.get_ref()
		if atlas == null:
			continue
		live += 1
		owners += clip.owners.size()
		if bool(clip.loaded):
			ids.append(str(clip.id))
			bytes += int(atlas.atlas.get_width()) * int(atlas.atlas.get_height()) * 4
	ids.sort()
	return {"entries": _clips.size(), "live": live, "owners": owners, "resident_sheets": ids.size(),
		"resident_ids": ids, "decoded_sheet_bytes": bytes, "reduced_motion": _reduced}

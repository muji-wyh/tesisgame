extends RefCounted
## Scoped URLs keep a frozen round bound to its own releasable cache lease.

const ThemeMotion = preload("res://scripts/learning_theme_motion.gd")

static var _scopes: Dictionary = {}
static var _next_scope: int = 0


static func acquire(cache: RefCounted, resource_ids: Array) -> Dictionary:
	var pinned: Dictionary = cache.pin_round(resource_ids)
	if not pinned.ok:
		return pinned
	_next_scope += 1
	var scope: String = "round%d" % _next_scope
	_scopes[scope] = {"cache": weakref(cache), "lease": pinned.lease, "ids": resource_ids.duplicate()}
	return {"ok": true, "scope": scope}


static func path(scope: String, sha256: String) -> String:
	return "professional://%s/%s" % [scope, sha256]


static func is_professional(source: String) -> bool:
	return source.trim_prefix("res://").begins_with("professional://")


static func resource(source: String) -> Resource:
	var value: String = source.trim_prefix("res://")
	if not value.begins_with("professional://"):
		return null
	var parts: PackedStringArray = value.trim_prefix("professional://").split("/", false)
	if parts.size() != 2 or not _scopes.has(parts[0]):
		return null
	var scoped: Dictionary = _scopes[parts[0]]
	var id: String = "sha256:" + parts[1]
	if not scoped.ids.has(id):
		return null
	var cache: RefCounted = scoped.cache.get_ref()
	if cache == null:
		return null
	var result: Resource = cache.get_resource(id, scoped.lease)
	if result != null:
		result.set_meta("professional_media", true)
	return result


static func bind_content(content: Dictionary, scope: String) -> Dictionary:
	if not _scopes.has(scope):
		return {"ok": false, "error": "This module's media is no longer available."}
	var result: Dictionary = content.duplicate(true)
	var words: Array = result.get("words", []).duplicate()
	words.append_array(result.get("module_words", []))
	for word in words:
		word.image = path(scope, word.media.image.sha256)
		word.audio = path(scope, word.media.audio.sha256)
		if not resource(word.image) is Texture2D or not resource(word.audio) is AudioStream:
			return {"ok": false, "error": "A required word picture or recording is unavailable."}
	for expression in result.get("expressions", []):
		expression.audio = path(scope, expression.media.audio.sha256)
		if not resource(expression.audio) is AudioStream:
			return {"ok": false, "error": "A required expression recording is unavailable."}
	for artwork in result.get("theme_profile", {}).get("art", {}).values():
		artwork.path = path(scope, str(artwork.get("sha256", "")))
		if not resource(artwork.path) is Texture2D:
			return {"ok": false, "error": "A required workplace illustration is unavailable."}
	var profile: Dictionary = result.get("theme_profile", {})
	if profile.has("ambient_motion"):
		var motion: Dictionary = ThemeMotion.compile(profile, true)
		if not motion.ok:
			return motion
	for clip in profile.get("ambient_motion", {}).get("clips", []):
		clip.image.path = path(scope, str(clip.image.get("sha256", "")))
		var sheet: Texture2D = resource(clip.image.path) as Texture2D
		if sheet == null or int(clip.get("columns", 0)) < 1 or int(clip.get("rows", 0)) < 1 \
			or sheet.get_width() % int(clip.columns) != 0 or sheet.get_height() % int(clip.rows) != 0:
			return {"ok": false, "error": "A required workplace animation sheet is unavailable or has invalid dimensions."}
	result["media_scope"] = scope
	return result


static func release(scope: String) -> void:
	if not _scopes.has(scope):
		return
	var scoped: Dictionary = _scopes[scope]
	_scopes.erase(scope)
	var cache: RefCounted = scoped.cache.get_ref()
	if cache != null:
		cache.release_round(scoped.lease)

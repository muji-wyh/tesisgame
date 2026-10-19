extends RefCounted
## Load small catalog metadata first, then only a selected module's records.

const Context = preload("res://scripts/learning_context.gd")
const Resolver = preload("res://scripts/learning_content_resolver.gd")
const MediaManifest = preload("res://scripts/professional_media_manifest.gd")
const ThemeMotion = preload("res://scripts/learning_theme_motion.gd")
const ROOT: String = "res://data/professional/"
const MAX_METADATA_BYTES: int = 8 * 1024 * 1024

var error: String = ""
var _catalog: Dictionary = {}
var _themes: Dictionary = {}


func load_index() -> bool:
	error = ""
	var catalog: Dictionary = _read(ROOT + "catalog.json")
	if catalog.get("schema_version") != 1 or not catalog.get("courses") is Array:
		return _fail("The professional course catalog could not be loaded. Please retry.")
	var seen: Dictionary = {}
	for course in catalog.courses:
		if not course is Dictionary or not course.get("id") is String or seen.has(course.id) \
			or not course.get("title") is String or not _safe_path(course.get("manifest", "")):
			return _fail("The professional course catalog contains an invalid course.")
		seen[course.id] = true
	var themes: Dictionary = _read(str(catalog.get("themes", "")))
	if themes.get("schema_version") != 1 or not themes.get("profiles") is Array:
		return _fail("The workplace theme catalog could not be loaded. Please retry.")
	var profiles: Dictionary = {}
	for profile in themes.profiles:
		if not profile is Dictionary or not profile.get("id") is String or profiles.has(profile.id):
			return _fail("The workplace theme catalog contains an invalid profile.")
		profiles[profile.id] = profile.duplicate(true)
	_catalog = catalog.duplicate(true)
	_themes = profiles
	return true


func courses() -> Array:
	return _catalog.get("courses", []).duplicate(true)


func theme_profile(id: String) -> Dictionary:
	return _themes.get(id, {}).duplicate(true)


func course(id: String) -> Dictionary:
	error = ""
	for entry in _catalog.get("courses", []):
		if entry.id == id:
			var value: Dictionary = _read(entry.manifest)
			if value.get("id") == id and value.get("modules") is Array:
				return value
			_fail("This course could not be loaded. Please retry.")
			return {}
	_fail("Choose an available professional course.")
	return {}


func resolve(context: Dictionary, seed_value: int = -1) -> Dictionary:
	error = Context.validate(context)
	if not error.is_empty() or context.get("track") != "professional":
		return _rejected(error if not error.is_empty() else "Choose a professional course.")
	var manifest: Dictionary = course(context.course_id)
	if manifest.is_empty():
		return _rejected(error)
	var selected: Dictionary = {}
	for module in manifest.modules:
		if module is Dictionary and module.get("id") == context.module_id:
			selected = module
			break
	if selected.get("status") != "ready":
		return _rejected("This module is still being prepared.", "content_pending")
	var lexemes: Dictionary = _records(selected.get("lexeme_files", []), "lexemes")
	if not error.is_empty():
		return _rejected(error)
	var expressions: Dictionary = _records(selected.get("expression_files", []), "expressions")
	if not error.is_empty():
		return _rejected(error)
	var result: Dictionary = Resolver.resolve_professional(context, manifest, lexemes, expressions, seed_value)
	if not result.ok:
		return result
	var profile: Dictionary = theme_profile(result.theme_id)
	if profile.get("status") != "ready" or profile.get("course_id") != context.course_id:
		return _rejected("This workplace theme is still being prepared.", "theme_pending")
	var descriptor: Variant = selected.get("media_manifest")
	if not descriptor is Dictionary or not _safe_path(descriptor.get("path")):
		return _rejected("This module is missing its media manifest.")
	var file := FileAccess.open(descriptor.path, FileAccess.READ)
	if file == null or file.get_length() > MediaManifest.MAX_MANIFEST:
		return _rejected("The module media manifest is unavailable. Please retry.")
	var media: Dictionary = MediaManifest.parse_manifest(file.get_buffer(file.get_length()), str(descriptor.get("sha256", "")), context)
	if not media.ok:
		return media
	var dependencies: Array = []
	for id in selected.lexeme_ids:
		dependencies.append(lexemes[id].media.image)
		dependencies.append(lexemes[id].media.audio)
	for id in selected.expression_ids:
		dependencies.append(expressions[id].media.audio)
	for role in ["environment", "home", "props"]:
		var artwork: Variant = profile.get("art", {}).get(role)
		if not artwork is Dictionary or not Resolver._media_ready(artwork):
			return _rejected("The workplace artwork is waiting for review.", "theme_pending")
		dependencies.append(artwork)
	var motion: Dictionary = ThemeMotion.compile(profile, true)
	if not motion.ok:
		return _rejected(motion.error, "theme_pending")
	for clip in motion.clips:
		dependencies.append(clip.image)
	var required_ids: Array[String] = []
	var resources: Dictionary = {}
	for resource in media.manifest.resources:
		resources[resource.id] = resource
	for dependency in dependencies:
		var id: String = "sha256:" + str(dependency.sha256)
		if not resources.has(id) or str(dependency.path).trim_prefix("res://") != resources[id].path:
			return _rejected("A required picture or recording is absent from the media manifest.", "missing_dependency")
		if not required_ids.has(id):
			required_ids.append(id)
	result["media_manifest"] = media.manifest
	result["required_resource_ids"] = required_ids
	result["theme_profile"] = profile
	return result


func _records(files: Variant, key: String) -> Dictionary:
	var result: Dictionary = {}
	if not files is Array or files.is_empty():
		_fail("This module is missing its content files.")
		return result
	for path in files:
		var value: Dictionary = _read(path)
		if value.get("schema_version") != 1 or not value.get(key) is Array:
			_fail("A required content file could not be loaded. Please retry.")
			return {}
		for entry in value[key]:
			if not entry is Dictionary or not entry.get("id") is String or result.has(entry.id):
				_fail("A required content file contains an invalid or duplicate sense.")
				return {}
			result[entry.id] = entry.duplicate(true)
	return result


func _read(path: Variant) -> Dictionary:
	if not _safe_path(path):
		_fail("The course requested an invalid content path.")
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_METADATA_BYTES:
		_fail("A course content file is unavailable. Please retry.")
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		_fail("A course content file could not be understood. Please retry.")
		return {}
	return value


func _safe_path(path: Variant) -> bool:
	return path is String and path.begins_with(ROOT) and path.ends_with(".json") \
		and not path.contains("..") and not path.contains("\\") and not path.substr(6).contains(":")


func _fail(message: String) -> bool:
	error = message
	return false


func _rejected(message: String, code: String = "content_unavailable") -> Dictionary:
	return {"ok": false, "code": code, "error": message, "words": [], "expressions": []}

extends "res://scripts/professional_catalog.gd"
## Owner-private snapshot adapter. It is never a policy authorization service.
## Only the owner's registered, current request token can authorize a round.

var _snapshot: Dictionary = {}
var _profile: Dictionary = {}
var _selected: Dictionary = {}
var _media: Dictionary = {}
var _generated_manifest: Dictionary = {}
var _context: Dictionary = {}


func _init(source_owner: Node, capability: RefCounted) -> void:
	# A capability is issued and consumed only inside the owner's resolve phase.
	# The constructor has no caller-supplied payload, manifest or accepted-ID API.
	if source_owner == null or capability == null or not source_owner.has_method("_take_catalog_snapshot"):
		return
	var source: Variant = source_owner.call("_take_catalog_snapshot", capability)
	if not source is Dictionary or source.is_empty():
		return
	_snapshot = source.snapshot.duplicate(true)
	_profile = source.profile.duplicate(true)
	_media = source.media.duplicate(true)
	_generated_manifest = source.generated_manifest.duplicate(true)
	_context = Context.freeze(source.context)
	for item: Dictionary in _snapshot.course.modules:
		if item.id == _snapshot.module_id:
			_selected = item
			break


func load_index() -> bool:
	return not _snapshot.is_empty()


func courses() -> Array:
	# Home browsing belongs to the ordinary catalog, not this private adapter.
	return []


func course(id: String) -> Dictionary:
	if _snapshot.is_empty() or id != _snapshot.course_id:
		_fail("The verified course snapshot is unavailable.")
		return {}
	return _snapshot.course.duplicate(true)


func theme_profile(id: String) -> Dictionary:
	return _profile.duplicate(true) if id == _profile.get("id") else {}


func _records(files: Variant, key: String) -> Dictionary:
	var source_key: String = "lexeme_files" if key == "lexemes" else "expression_files"
	if key not in ["lexemes", "expressions"] or files != _selected.get(source_key):
		_fail("The verified module rejected a substituted content list.")
		return {}
	var result: Dictionary = {}
	for entry: Dictionary in _snapshot[key]:
		result[entry.id] = entry.duplicate(true)
	return result


func _load_module_media(descriptor: Variant, context: Dictionary) -> Dictionary:
	if not descriptor is Dictionary or descriptor != _selected.get("media_manifest") \
		or not _safe_path(descriptor.get("path")) or descriptor.get("path") != _generated_manifest.get("source_path") \
		or descriptor.get("sha256") != _generated_manifest.get("sha256") \
		or not Context.same_round(context, _context):
		return _rejected("The cached media manifest belongs to another verified selection.")
	if not _media.get("ok", false) or not _media.get("manifest") is Dictionary:
		return _rejected("The verified media manifest is unavailable.")
	# Recheck course/module/revision and all media rules on every cache reuse.
	# This retains the original validation semantics without opening a file.
	return MediaManifest.validate_manifest(_media.manifest, context)


func _read(_path: Variant) -> Dictionary:
	_fail("Verified Professional content cannot fall back to loose source files.")
	return {}

extends RefCounted
## The owner must release round leases and references before an asset can be freed.

const Manifest = preload("res://scripts/professional_media_manifest.gd")

var _limit := Manifest.MAX_RESIDENT
var _entries: Dictionary = {}
var _identities: Dictionary = {}
var _bundle_identities: Dictionary = {}
var _revisions: Dictionary = {}
var _leases: Dictionary = {}
var _active: Dictionary = {}
var _staging: Dictionary = {}
var _generation := 0
var _clock := 0
var _resident := 0
var _reserved := 0
var _next_lease := 0


func configure(resident_limit: int = Manifest.MAX_RESIDENT) -> bool:
	if not _entries.is_empty() or not _staging.is_empty() or resident_limit <= 0 or resident_limit > Manifest.MAX_RESIDENT:
		return false
	_limit = resident_limit
	return true


func begin(manifest: Dictionary, generation: int, expected: Dictionary = {}) -> Dictionary:
	var validated: Dictionary = Manifest.validate_manifest(manifest, expected)
	if not validated.ok:
		return validated
	manifest = validated.manifest
	if generation <= _generation:
		return Manifest.failure("This media selection has been replaced.", "cancelled")
	abort()
	_generation = generation
	var revision: String = JSON.stringify([manifest.course_id, manifest.module_id, manifest.curriculum_revision])
	var fingerprint: String = JSON.stringify(manifest, "", true)
	if _revisions.has(revision) and _revisions[revision] != fingerprint:
		return Manifest.failure("A module media manifest changed without a new curriculum revision.", "revision_mismatch")
	var bundles: Dictionary = Manifest.bundle_inventory(manifest).bundles
	for key in bundles:
		if _bundle_identities.has(key) and _bundle_identities[key] != bundles[key]:
			return Manifest.failure("Shared bundle membership changed without a new bundle revision.", "revision_mismatch")
	var required: Dictionary = {}
	var needed := 0
	for metadata: Dictionary in manifest.resources:
		var identity: String = JSON.stringify(metadata, "", true)
		if _identities.has(metadata.id) and _identities[metadata.id] != identity:
			return Manifest.failure("Shared media metadata changed for an existing hash.", "identity_mismatch")
		required[metadata.id] = metadata.duplicate(true)
		if not _entries.has(metadata.id):
			needed += int(metadata.decoded_bytes)
	# Protect all existing dependencies before choosing any eviction candidate.
	_staging = required
	var reclaimable := 0
	for id in _entries:
		if not _protected(id):
			reclaimable += int(_entries[id].cost)
	if _resident + needed - reclaimable > _limit:
		_staging.clear()
		return Manifest.failure("Active rounds are using the media budget. Finish or close a round, then retry.", "budget_pressure")
	_evict_until(_limit - needed)
	_reserved = needed
	_revisions[revision] = fingerprint
	for key in bundles:
		_bundle_identities[key] = bundles[key].duplicate()
	for id in required:
		_identities[id] = JSON.stringify(required[id], "", true)
	return {"ok": true, "generation": generation, "resource_ids": required.keys(), "manifest": manifest}


func contains(id: String) -> bool:
	return _entries.has(id)


func insert(generation: int, metadata: Dictionary, decoded: Dictionary) -> Dictionary:
	if generation != _generation or not _staging.has(metadata.id):
		return Manifest.failure("This media selection has been replaced.", "cancelled")
	if JSON.stringify(metadata, "", true) != _identities[metadata.id]:
		return Manifest.failure("The media metadata changed while loading.", "identity_mismatch")
	if _entries.has(metadata.id):
		return {"ok": true}
	if not decoded.get("ok", false):
		return decoded
	if not decoded.get("resource") is Resource or decoded.get("decoded_bytes") != int(metadata.decoded_bytes):
		return Manifest.failure("The decoder did not return the declared resource budget.", "decoded_size_mismatch")
	if (metadata.kind == "image" and not decoded.resource is Texture2D) \
		or (metadata.kind == "audio" and not decoded.resource is AudioStreamWAV):
		return Manifest.failure("The decoded resource has the wrong media type.", "decode_failed")
	var cost: int = decoded.decoded_bytes
	if _resident + cost > _limit or cost > _reserved:
		return Manifest.failure("The media cache is full. Please retry after closing a round.", "budget_pressure")
	_clock += 1
	_entries[metadata.id] = {"resource": decoded.resource, "cost": cost, "used": _clock}
	_resident += cost
	_reserved -= cost
	return {"ok": true}


func activate(generation: int) -> Dictionary:
	if generation != _generation or _staging.is_empty():
		return Manifest.failure("This media selection has been replaced.", "cancelled")
	for id in _staging:
		if not _entries.has(id):
			return Manifest.failure("Required module media is still missing.", "missing_asset")
	_active = {}
	for id in _staging:
		_active[id] = true
		_touch(id)
	_staging.clear()
	_reserved = 0
	return {"ok": true, "generation": generation, "resource_ids": _active.keys()}


func abort() -> void:
	_staging.clear()
	_reserved = 0


func deactivate() -> void:
	_active.clear()


func pin_round(ids: Array) -> Dictionary:
	if ids.is_empty():
		return Manifest.failure("A round must pin its required media.", "missing_asset")
	var pinned: Dictionary = {}
	for id in ids:
		if not id is String or not _active.has(id) or not _entries.has(id):
			return Manifest.failure("Round media must belong to the active module.", "missing_asset")
		pinned[id] = true
	_next_lease += 1
	_leases[_next_lease] = pinned
	return {"ok": true, "lease": _next_lease}


func release_round(lease: int) -> void:
	_leases.erase(lease)


func get_resource(id: String, lease: int = 0) -> Resource:
	if not _entries.has(id):
		return null
	if lease != 0:
		if not _leases.has(lease) or not _leases[lease].has(id):
			return null
	elif not _active.has(id):
		return null
	_touch(id)
	return _entries[id].resource


func trim_inactive() -> void:
	_evict_until(0)


func stats() -> Dictionary:
	var pinned := 0
	for id in _entries:
		if _protected(id):
			pinned += int(_entries[id].cost)
	return {"resident_bytes": _resident, "reserved_bytes": _reserved, "limit_bytes": _limit,
		"pinned_bytes": pinned, "resources": _entries.size(), "leases": _leases.size(), "active_ids": _active.keys()}


func _touch(id: String) -> void:
	_clock += 1
	_entries[id].used = _clock


func _protected(id: String) -> bool:
	if _active.has(id) or _staging.has(id):
		return true
	for pinned: Dictionary in _leases.values():
		if pinned.has(id):
			return true
	return false


func _evict_until(target: int) -> void:
	while _resident > target:
		var oldest := ""
		var used := 9223372036854775807
		for id in _entries:
			if not _protected(id) and int(_entries[id].used) < used:
				oldest = id
				used = int(_entries[id].used)
		if oldest.is_empty():
			return
		_resident -= int(_entries[oldest].cost)
		_entries.erase(oldest)

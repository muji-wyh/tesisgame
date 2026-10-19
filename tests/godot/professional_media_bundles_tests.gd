extends SceneTree
## Real decoding and lifecycle checks; generated/expanded images are test fixtures only.

const Manifest = preload("res://scripts/professional_media_manifest.gd")
const Cache = preload("res://scripts/professional_media_cache.gd")
const Loader = preload("res://scripts/professional_media_loader.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const Play = preload("res://scripts/professional_play.gd")

var checks := 0
var failures := 0
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _image(image: Image) -> Dictionary:
	var bytes: PackedByteArray = image.save_png_to_buffer()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var sha: String = hashing.finish().hex_encode()
	var metadata: Dictionary = {"id": "sha256:" + sha, "sha256": sha,
		"path": "professional-media/%s.png" % sha, "kind": "image", "format": "png",
		"compressed_bytes": bytes.size(), "decoded_bytes": image.get_width() * image.get_height() * 8,
		"width": image.get_width(), "height": image.get_height()}
	return {"metadata": metadata, "bytes": bytes}


func _tiny(color: Color) -> Dictionary:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return _image(image)


func _manifest(resources: Array, revision: String = "1") -> Dictionary:
	var bundles: Array = []
	for resource in resources:
		bundles.append({"id": "shared-" + resource.sha256, "revision": "1", "resource_ids": [resource.id]})
	return {"schema_version": 2, "course_id": "retail", "module_id": "module03",
		"curriculum_revision": revision, "resources": resources.duplicate(true), "bundles": bundles}


func _run() -> void:
	directory = "user://professional-bundles-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory.path_join("professional-media")) == OK, "Use isolated raw media storage")
	_test_bundle_contract()
	_test_shared_identity()
	await _test_actual_delivery()
	await _test_leave_pending()
	for name in DirAccess.get_files_at(directory.path_join("professional-media")):
		check(DirAccess.remove_absolute(directory.path_join("professional-media").path_join(name)) == OK, "Remove raw fixture")
	check(DirAccess.remove_absolute(directory.path_join("professional-media")) == OK, "Remove raw fixture directory")
	for name in DirAccess.get_files_at(directory):
		check(DirAccess.remove_absolute(directory.path_join(name)) == OK, "Remove isolated progress fixture")
	check(DirAccess.remove_absolute(directory) == OK, "Remove isolated root")
	print("Professional media bundles: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_bundle_contract() -> void:
	var resources: Array = []
	for index in range(9):
		var sha: String = str(index).repeat(64)
		resources.append({"id": "sha256:" + sha, "sha256": sha, "path": "professional-media/%s.png" % sha,
			"kind": "image", "format": "png", "compressed_bytes": 1000,
			"width": 1024, "height": 2048, "decoded_bytes": 16 * 1024 * 1024})
	check(Manifest.validate_manifest(_manifest(resources.slice(0, 3))).ok, "Three bounded groups may exceed 32 MiB in total")
	check(Manifest.validate_manifest(_manifest(resources.slice(0, 8))).ok, "128 MiB unique inventory is inclusive")
	check(Manifest.validate_manifest(_manifest(resources)).code == "budget_pressure", "Unique residency cannot exceed 128 MiB")
	var value: Dictionary = _manifest(resources.slice(0, 3))
	value.bundles = [{"id": "too-large", "revision": "1", "resource_ids": [resources[0].id, resources[1].id, resources[2].id]}]
	check(Manifest.validate_manifest(value).code == "budget_pressure", "Each bundle retains the 32 MiB decoded cap")
	value = _manifest(resources.slice(0, 2))
	value.bundles.pop_back()
	check(Manifest.validate_manifest(value).code == "missing_dependency", "Unbundled resources reject activation")
	value = _manifest(resources.slice(0, 2))
	value.bundles[0].resource_ids.append(resources[0].id)
	check(not Manifest.validate_manifest(value).ok, "Duplicate members cannot hide a bundle overage")
	value = _manifest(resources.slice(0, 2))
	value.bundles[0].resource_ids = [resources[8].id]
	check(Manifest.validate_manifest(value).code == "missing_dependency", "Unknown group members reject activation")
	value = _manifest(resources.slice(0, 2))
	value.bundles.append(value.bundles[0])
	check(not Manifest.validate_manifest(value).ok, "Duplicate bundle revisions reject activation")
	value = _manifest(resources.slice(0, 2))
	value.bundles.append({"id": "shared-pair", "revision": "1", "resource_ids": [resources[1].id, resources[0].id]})
	check(Manifest.validate_manifest(value).decoded_bytes == 32 * 1024 * 1024, "Overlapping groups count flat shared resources once")
	check(Manifest.bundle_inventory(value).bundles[JSON.stringify(["shared-pair", "1"])] == [resources[0].id, resources[1].id], "Bundle signatures use sorted members")
	value.schema_version = 1
	check(not Manifest.validate_manifest(value).ok, "Version 1 cannot silently accept version 2 fields")
	value.erase("bundles")
	check(Manifest.validate_manifest(value).ok, "Legacy ungrouped 32 MiB remains valid")
	value.resources.append(resources[2])
	check(Manifest.validate_manifest(value).code == "budget_pressure", "Legacy ungrouped overage remains invalid")
	value = _manifest(resources.slice(0, 3))
	for item in value.resources:
		item.compressed_bytes = 4 * 1024 * 1024
	check(Manifest.validate_manifest(value).code == "budget_pressure", "Grouped transfer budget stays 10 MiB")


func _test_shared_identity() -> void:
	var cache := Cache.new()
	check(cache.configure(16), "Use a deliberately constrained cache without raising production limits")
	var a: Dictionary = _tiny(Color.RED)
	var b: Dictionary = _tiny(Color.GREEN)
	var original: Dictionary = _manifest([a.metadata, b.metadata])
	original.bundles = [{"id": "shared-pair", "revision": "1", "resource_ids": [a.metadata.id, b.metadata.id]}]
	check(cache.begin(original, 1).ok, "Begin a shared group")
	for item in [a, b]:
		check(cache.insert(1, item.metadata, Manifest.decode(item.bytes, item.metadata)).ok, "Insert shared group fixture")
	check(cache.activate(1).ok, "Activate only the complete shared inventory")
	var lease: Dictionary = cache.pin_round([a.metadata.id, b.metadata.id])
	var reordered: Dictionary = original.duplicate(true)
	reordered.course_id = "nursing"
	reordered.bundles[0].resource_ids.reverse()
	check(cache.begin(reordered, 2).ok and cache.stats().reserved_bytes == 0, "Another course reuses the identical stable group regardless of member order")
	check(cache.activate(2).ok, "Reused group activates without duplicate allocation")
	var conflict: Dictionary = _manifest([a.metadata], "2")
	conflict.bundles = [{"id": "shared-pair", "revision": "1", "resource_ids": [a.metadata.id]}]
	check(cache.begin(conflict, 3).code == "revision_mismatch", "Cross-module group drift requires a new bundle revision")
	check(cache.get_resource(b.metadata.id, lease.lease) != null and cache.stats().resident_bytes == 16, "Rejected group preserves the old round and bytes")
	var drift: Dictionary = original.duplicate(true)
	drift.curriculum_revision = "new-module"
	drift.resources[0].width = 2
	drift.resources[0].decoded_bytes = 16
	check(cache.begin(drift, 4).code == "identity_mismatch", "Group support does not bypass existing resource identity protection")
	conflict.bundles[0].revision = "2"
	check(cache.begin(conflict, 5).ok, "New membership uses an explicit new bundle revision")
	cache.abort()
	var c: Dictionary = _tiny(Color.BLUE)
	var blocked: Dictionary = _manifest([c.metadata], "pressure")
	blocked.bundles[0].id = "not-yet-registered"
	check(cache.begin(blocked, 6).code == "budget_pressure", "Pinned complete round cannot be evicted for a replacement bundle")
	check(cache.stats().resident_bytes == 16 and cache.stats().reserved_bytes == 0, "Pressure leaves prior bytes and no staged reservation")
	blocked.resources = [a.metadata]
	blocked.bundles[0].resource_ids = [a.metadata.id]
	check(cache.begin(blocked, 7).ok, "Failed budget preflight does not register a new bundle identity")
	cache.abort()
	cache.release_round(lease.lease)
	cache.deactivate()
	cache.trim_inactive()
	check(cache.stats().resident_bytes == 0, "All released grouped resources remain evictable")


func _test_actual_delivery() -> void:
	var source := Image.new()
	source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/images/words/absent.png"))
	# Expanded existing artwork exercises actual decoding at the exact bundle cap.
	source.resize(2048, 2048)
	var large: Dictionary = _image(source)
	var small: Dictionary = _tiny(Color.BLUE)
	for item in [large, small]:
		var file := FileAccess.open(directory.path_join(item.metadata.path), FileAccess.WRITE)
		file.store_buffer(item.bytes)
		file.close()
	var manifest: Dictionary = _manifest([large.metadata, small.metadata], "real-delivery")
	var serialized: PackedByteArray = JSON.stringify(manifest).to_utf8_buffer()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(serialized)
	var parsed: Dictionary = Manifest.parse_manifest(serialized, hashing.finish().hex_encode())
	check(parsed.ok, "Version 2 also accepts the JSON parser's numeric version representation")
	manifest = parsed.manifest
	var loader := Loader.new()
	root.add_child(loader)
	loader.configure(directory)
	var generation: int = loader.request_module(manifest, {}, [large.metadata.id, small.metadata.id])
	var result: Array = await loader.completed
	check(result[0] == generation and result[1].ok, "Native loader decodes an actual inventory above 32 MiB with bounded groups")
	check(loader.cache.stats().resident_bytes == Manifest.MAX_DECODED + 8, "Actual decoded costs agree with grouped metadata")
	var pinned: Dictionary = loader.cache.pin_round(result[1].resource_ids)
	check(pinned.ok and (loader.cache.get_resource(large.metadata.id, pinned.lease) as Texture2D).get_width() == 2048, "Round accesses the fully decoded large source fixture")
	# A failed replacement must keep the previous complete grouped round intact.
	var missing: Dictionary = _tiny(Color.YELLOW)
	generation = loader.request_module(_manifest([missing.metadata], "missing-delivery"))
	result = await loader.completed
	check(result[0] == generation and not result[1].ok and result[1].code == "missing_asset", "Missing replacement returns a recoverable failure")
	check(loader.cache.get_resource(large.metadata.id, pinned.lease) != null, "Failed grouped replacement preserves the old round lease")
	var callbacks: Array = []
	loader.fetch_override = func(_metadata: Dictionary, _generation: int, complete: Callable) -> void:
		callbacks.append(complete)
	loader.request_module(_manifest([missing.metadata], "late-delivery"))
	for frame in range(3):
		await process_frame
	check(callbacks.size() == 1, "Hold an actual grouped transport callback in flight")
	generation = loader.request_module(manifest)
	result = await loader.completed
	while result[0] != generation:
		result = await loader.completed
	check(result[1].ok, "Latest cached grouped inventory activates after cancellation")
	callbacks[0].call({"ok": true, "bytes": missing.bytes})
	await process_frame
	check(not loader.cache.contains(missing.metadata.id) and loader.cache.get_resource(large.metadata.id, pinned.lease) != null, "Late grouped callback cannot insert stale media or replace the held round")
	loader.cache.release_round(pinned.lease)
	loader.cache.deactivate()
	loader.cache.trim_inactive()
	check(loader.cache.stats().resident_bytes == 0 and loader.cache.stats().reserved_bytes == 0, "Grouped teardown releases all decoded payload and reservations")
	loader.queue_free()
	await process_frame


func _test_leave_pending() -> void:
	var play := Play.new()
	root.add_child(play)
	check(play.configure(null, func(_id: String, _tier: int) -> Dictionary: return {"ok": true}, directory.path_join("progress.json")), "Configure a real play owner with isolated progress")
	for frame in range(10):
		await process_frame
	var a: Dictionary = _tiny(Color.RED)
	var b: Dictionary = _tiny(Color.GREEN)
	var cache: RefCounted = play.loader.media.cache
	check(cache.begin(_manifest([a.metadata], "old"), 100).ok and cache.insert(100, a.metadata, Manifest.decode(a.bytes, a.metadata)).ok and cache.activate(100).ok, "Prepare old active module")
	var active: Dictionary = Access.acquire(cache, [a.metadata.id])
	play.active = {"media_scope": active.scope}
	check(cache.begin(_manifest([b.metadata], "pending"), 101).ok and cache.insert(101, b.metadata, Manifest.decode(b.bytes, b.metadata)).ok and cache.activate(101).ok, "Prepare replacement before its round is claimed")
	var pending: Dictionary = Access.acquire(cache, [b.metadata.id])
	# This cleanup fixture installs only an unclaimed scope; it grants no
	# policy token or ready-content authority.
	play.loader._preparation = {"pending_scope": pending.scope}
	check(cache.stats().leases == 2, "Both old and unclaimed replacement scopes are retained")
	# No views or audio own these test textures. Real callers clear them first.
	play.leave()
	check(cache.stats().leases == 0 and cache.stats().resident_bytes == 0 and cache.stats().active_ids.is_empty(), "Leaving cancels pending scope, releases active scope, deactivates and trims")
	check(Access.resource(Access.path(active.scope, a.metadata.sha256)) == null and Access.resource(Access.path(pending.scope, b.metadata.sha256)) == null, "Neither released scope can access old resources")
	play.leave()
	check(cache.stats().resident_bytes == 0, "Repeated leave remains harmless")
	play.queue_free()
	await process_frame

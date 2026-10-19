extends SceneTree

const Manifest = preload("res://scripts/professional_media_manifest.gd")
const Cache = preload("res://scripts/professional_media_cache.gd")
const Loader = preload("res://scripts/professional_media_loader.gd")

var checks := 0
var failures := 0
var directory: String
var image_bytes: PackedByteArray
var image_metadata: Dictionary
var audio_bytes: PackedByteArray
var audio_metadata: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _metadata(bytes: PackedByteArray, kind: String, format: String) -> Dictionary:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var hash_value: String = hashing.finish().hex_encode()
	var result: Dictionary = {"id": "sha256:" + hash_value, "sha256": hash_value, "path": "professional-media/%s.%s" % [hash_value, format],
		"kind": kind, "format": format, "compressed_bytes": bytes.size()}
	if kind == "image":
		var image := Image.new()
		match format:
			"png": image.load_png_from_buffer(bytes)
			"webp": image.load_webp_from_buffer(bytes)
			"jpg": image.load_jpg_from_buffer(bytes)
		result.merge({"width": image.get_width(), "height": image.get_height(), "decoded_bytes": image.get_width() * image.get_height() * 8})
	else:
		var index := 12
		var count := 0
		while index + 8 <= bytes.size():
			var chunk: String = bytes.slice(index, index + 4).get_string_from_ascii()
			var size: int = bytes.decode_u32(index + 4)
			index += 8
			if chunk == "fmt ":
				result.channels = bytes.decode_u16(index + 2)
				result.sample_rate = bytes.decode_u32(index + 4)
			elif chunk == "data":
				count = size
			index += size + size % 2
		result.frames = count / (int(result.channels) * 2)
		result.decoded_bytes = count
	return result


func _manifest(resources: Array, revision: String = "test-1") -> Dictionary:
	return {"schema_version": 1, "course_id": "retail", "module_id": "module01", "curriculum_revision": revision, "resources": resources.duplicate(true)}


func _run() -> void:
	directory = "user://professional-media-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory.path_join("professional-media")) == OK, "Create isolated raw delivery directory")
	image_bytes = FileAccess.get_file_as_bytes("res://assets/images/words/absent.png")
	image_metadata = _metadata(image_bytes, "image", "png")
	audio_bytes = FileAccess.get_file_as_bytes("res://assets/audio/jelly-match/collect-do.wav")
	audio_metadata = _metadata(audio_bytes, "audio", "wav")
	for pair in [[image_metadata, image_bytes], [audio_metadata, audio_bytes]]:
		var file := FileAccess.open(directory.path_join(pair[0].path), FileAccess.WRITE)
		file.store_buffer(pair[1])
		file.close()
	_test_real_decode()
	_test_cache()
	await _test_loader()
	for name in DirAccess.get_files_at(directory.path_join("professional-media")):
		check(DirAccess.remove_absolute(directory.path_join("professional-media").path_join(name)) == OK, "Remove raw delivery fixture")
	check(DirAccess.remove_absolute(directory.path_join("professional-media")) == OK, "Remove raw media fixture directory")
	check(DirAccess.remove_absolute(directory) == OK, "Remove isolated fixture root")
	print("Professional media: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_real_decode() -> void:
	check(Manifest.validate_manifest(_manifest([image_metadata, audio_metadata])).ok, "Representative module is inside both delivery budgets")
	check(Manifest.validate_dependencies(_manifest([image_metadata]), [image_metadata.id]).ok, "Known content dependency resolves to canonical media")
	check(Manifest.validate_dependencies(_manifest([image_metadata]), [audio_metadata.id]).code == "missing_dependency", "Missing required content dependency prevents activation")
	var serialized: PackedByteArray = JSON.stringify(_manifest([image_metadata, audio_metadata])).to_utf8_buffer()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(serialized)
	var parsed: Dictionary = Manifest.parse_manifest(serialized, hashing.finish().hex_encode())
	check(parsed.ok, "Manifest file is hash-verified before parsing: " + str(parsed.get("error", "")))
	check(Manifest.parse_manifest(serialized, "0".repeat(64)).code == "hash_mismatch", "Wrong manifest hash rejects the entire delivery")
	var decoded: Dictionary = Manifest.decode(image_bytes, image_metadata)
	check(decoded.ok and decoded.resource is ImageTexture, "Decode existing real artwork into a releasable image texture")
	check(decoded.get("decoded_bytes") == int(image_metadata.width) * int(image_metadata.height) * 8, "Image cost includes RGBA CPU and GPU payload")
	decoded = Manifest.decode(audio_bytes, audio_metadata)
	check(decoded.ok and decoded.resource is AudioStreamWAV, "Decode real production WAV without ResourceLoader")
	check(decoded.get("decoded_bytes") == audio_metadata.decoded_bytes, "PCM cost equals actual sample data")
	var webp: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/images/word-library/almond.webp")
	check(Manifest.decode(webp, _metadata(webp, "image", "webp")).ok, "Decode real WebP artwork with header preflight")
	var image := Image.new()
	image.load_png_from_buffer(image_bytes)
	var jpeg: PackedByteArray = image.save_jpg_to_buffer()
	check(Manifest.decode(jpeg, _metadata(jpeg, "image", "jpg")).ok, "JPEG decoder preserves source image dimensions")
	var wrong: PackedByteArray = image_bytes.duplicate()
	wrong[wrong.size() - 1] ^= 1
	check(Manifest.decode(wrong, image_metadata).code == "hash_mismatch", "Corrupt media never enters the cache")
	var dimensions: Dictionary = image_metadata.duplicate(true)
	dimensions.width += 1
	dimensions.decoded_bytes = dimensions.width * dimensions.height * 8
	check(Manifest.decode(image_bytes, dimensions).code == "decoded_size_mismatch", "Underdeclared or changed dimensions rejected before image decode")
	var frames: Dictionary = audio_metadata.duplicate(true)
	frames.frames += 1
	frames.decoded_bytes += frames.channels * 2
	check(Manifest.decode(audio_bytes, frames).code == "decoded_size_mismatch", "WAV actual frames must match delivery budget")
	var oversized: Dictionary = image_metadata.duplicate(true)
	oversized.compressed_bytes = Manifest.MAX_COMPRESSED + 1
	check(Manifest.validate_manifest(_manifest([oversized])).code == "budget_pressure", "Compressed budget cannot be exceeded")
	var large: Dictionary = image_metadata.duplicate(true)
	large.width = 2048
	large.height = 2048
	large.decoded_bytes = Manifest.MAX_DECODED
	check(Manifest.validate_manifest(_manifest([large, audio_metadata])).code == "budget_pressure", "Decoded module budget cannot be exceeded")
	check(not Manifest.validate_manifest(_manifest([image_metadata, image_metadata])).ok, "Shared resources are listed only once")
	check(not Manifest.validate_manifest(_manifest([image_metadata]), {"course_id": "nursing"}).ok, "Manifest cannot activate another course")


func _tiny(color: Color) -> Dictionary:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var bytes: PackedByteArray = image.save_png_to_buffer()
	var metadata: Dictionary = _metadata(bytes, "image", "png")
	return {"metadata": metadata, "decoded": Manifest.decode(bytes, metadata)}


func _test_cache() -> void:
	var cache = Cache.new()
	check(cache.configure(16), "Tests can lower but cannot raise the resident budget")
	var a: Dictionary = _tiny(Color.RED)
	var b: Dictionary = _tiny(Color.GREEN)
	var c: Dictionary = _tiny(Color.BLUE)
	check(cache.begin(_manifest([a.metadata], "a"), 1).ok and cache.insert(1, a.metadata, a.decoded).ok and cache.activate(1).ok, "Activate first immutable module")
	var lease: Dictionary = cache.pin_round([a.metadata.id])
	check(lease.ok and cache.get_resource(a.metadata.id, lease.lease) != null, "Active round retains explicit resource lease")
	check(cache.begin(_manifest([b.metadata], "b"), 2).ok and cache.insert(2, b.metadata, b.decoded).ok and cache.activate(2).ok, "Activate another module while old round is pinned")
	check(cache.begin(_manifest([c.metadata], "c"), 3).code == "budget_pressure", "Pinned old round and active module cannot be evicted")
	check(cache.stats().resident_bytes == 16 and cache.get_resource(a.metadata.id, lease.lease) != null, "Budget pressure preserves active assets")
	cache.release_round(lease.lease)
	check(cache.begin(_manifest([c.metadata], "c"), 4).ok and not cache.contains(a.metadata.id), "Released inactive least-recently-used resource is evicted")
	check(cache.insert(4, c.metadata, c.decoded).ok and cache.activate(4).ok, "Retry after releasing round succeeds")
	check(cache.get_resource(a.metadata.id, lease.lease) == null, "Released lease cannot access evicted data")
	check(cache.begin(_manifest([c.metadata], "shared"), 5).ok and cache.stats().reserved_bytes == 0, "Shared canonical hash needs no duplicate allocation")
	check(cache.activate(5).ok and cache.stats().resident_bytes == 16, "Shared modules reuse decoded resource")
	var changed: Dictionary = c.metadata.duplicate(true)
	changed.width = 2
	changed.decoded_bytes = 16
	check(cache.begin(_manifest([changed], "changed"), 6).code == "identity_mismatch", "Existing resource hash cannot change metadata")
	check(cache.begin(_manifest([b.metadata], "shared"), 7).code == "revision_mismatch", "Pinned module revision cannot silently change dependencies")
	cache.deactivate()
	cache.trim_inactive()
	check(cache.stats().resident_bytes == 0 and cache.stats().resources == 0, "Inactive unpinned resources can be released completely")
	check(not Cache.new().configure(Manifest.MAX_RESIDENT + 1), "Production cache cap cannot be raised")
	var lru = Cache.new()
	check(lru.configure(24), "Configure three-resource LRU fixture")
	for pair in [[a, "a"], [b, "b"], [c, "c"]]:
		var next: int = int(lru.stats().resources) + 1
		check(lru.begin(_manifest([pair[0].metadata], pair[1]), next).ok \
			and lru.insert(next, pair[0].metadata, pair[0].decoded).ok and lru.activate(next).ok, "Populate LRU fixture")
	check(lru.begin(_manifest([a.metadata], "a"), 4).ok and lru.activate(4).ok, "Reuse touches older shared resource")
	var d: Dictionary = _tiny(Color.PURPLE)
	check(lru.begin(_manifest([d.metadata], "d"), 5).ok and not lru.contains(b.metadata.id) and lru.contains(c.metadata.id), "LRU evicts oldest inactive resource before a more recently used one")
	lru.abort()
	check(lru.stats().reserved_bytes == 0, "Cancellation releases an unused reservation")


func _test_loader() -> void:
	var loader = Loader.new()
	root.add_child(loader)
	loader.configure(directory)
	var generation: int = loader.request_module(_manifest([image_metadata, audio_metadata]))
	var response: Array = await loader.completed
	check(response[0] == generation and response[1].ok, "Native raw sidecar image and audio activate together")
	var ids: Array = response[1].resource_ids
	var lease: Dictionary = loader.cache.pin_round(ids)
	check(lease.ok and loader.cache.get_resource(audio_metadata.id, lease.lease) is AudioStreamWAV, "Round can play its pinned raw audio")
	var delayed: Array = []
	loader.fetch_override = func(metadata: Dictionary, _generation: int, complete: Callable) -> void:
		delayed.append({"metadata": metadata, "complete": complete})
	var other: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/images/words/after.png")
	var other_metadata: Dictionary = _metadata(other, "image", "png")
	var old: int = loader.request_module(_manifest([other_metadata], "old"))
	await process_frame
	await process_frame
	check(delayed.size() == 1, "Inject an in-flight raw download")
	generation = loader.request_module(_manifest([image_metadata], "latest"))
	response = await loader.completed
	while response[0] != generation:
		response = await loader.completed
	check(response[1].ok and response[1].generation == generation and old != generation, "Latest selection activates while earlier request is cancelled")
	delayed[0].complete.call({"ok": true, "bytes": other})
	await process_frame
	check(not loader.cache.contains(other_metadata.id) and loader.cache.stats().active_ids == [image_metadata.id], "Stale callback cannot insert or activate another module")
	loader.timeout_seconds = 0.02
	loader.request_module(_manifest([other_metadata], "timeout"))
	response = await loader.completed
	check(response[1].code == "timeout" and loader.cache.stats().reserved_bytes == 0, "Timeout releases staging reservation and remains retryable")
	loader.fetch_override = func(_metadata: Dictionary, _generation: int, complete: Callable) -> void:
		complete.call_deferred({"ok": true, "bytes": image_bytes})
	loader.request_module(_manifest([other_metadata], "retry"))
	response = await loader.completed
	check(not response[1].ok and response[1].code in ["size_mismatch", "hash_mismatch"], "Wrong media never activates")
	loader.fetch_override = func(_metadata: Dictionary, _generation: int, complete: Callable) -> void:
		complete.call_deferred({"ok": true, "bytes": other})
	loader.request_module(_manifest([other_metadata], "retry"))
	response = await loader.completed
	check(response[1].ok and loader.cache.get_resource(other_metadata.id) != null, "Correct retry activates immutable revision")
	loader.fetch_override = Callable()
	var absent: Dictionary = _tiny(Color.YELLOW).metadata
	loader.request_module(_manifest([absent], "missing"))
	response = await loader.completed
	check(response[1].code == "missing_asset" and loader.cache.get_resource(other_metadata.id) != null, "Missing asset preserves previous active module")
	loader.cache.release_round(lease.lease)
	loader.queue_free()
	await process_frame

extends SceneTree

const Manifest = preload("res://scripts/professional_media_manifest.gd")
const Loader = preload("res://scripts/professional_media_loader.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _read(filename: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(filename))


func _run() -> void:
	var receipts: Array[Dictionary] = [
		_read("res://data/professional/provenance/retail-approved-audio-2026-10-16.json"),
		_read("res://data/professional/provenance/retail-cart-basket-approved-audio-2026-10-16.json"),
		_read("res://data/professional/provenance/retail-pallet-shelf-approved-audio-2026-10-16.json"),
		_read("res://data/professional/provenance/retail-bag-wrap-approved-audio-2026-10-16.json"),
		_read("res://data/professional/provenance/retail-counter-checkout-approved-audio-2026-10-16.json"),
		_read("res://data/professional/provenance/retail-card-reader-barcode-approved-audio-2026-10-16.json"),
	]
	var patches: Array = []
	for receipt: Dictionary in receipts:
		patches.append_array(receipt.patches)
	var lexemes := _read("res://data/professional/lexemes/retail-pilot.json")
	var resources: Array = []
	var required: Array = []
	var decoded_total := 0
	check(patches.size() == 12, "All twelve exact user-approved recordings are covered")
	for patch: Dictionary in patches:
		var metadata: Dictionary = patch.resource
		decoded_total += int(metadata.decoded_bytes)
		var entries: Array = lexemes.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == patch.sense_id)
		check(entries.size() == 1, "Each approved recording belongs to one canonical sense")
		var audio: Dictionary = entries[0].media.audio
		check(audio.status == "integrated" and audio.review.status == "reviewed", "Persisted audio descriptor records exact user approval")
		check(audio.path == "res://" + metadata.path and audio.sha256 == metadata.sha256, "Descriptor resolves to the approved immutable resource")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(audio.path)
		check(Manifest.verify_bytes(bytes, metadata).ok, "Approved production bytes satisfy the delivery hash and size")
		var decoded: Dictionary = Manifest.decode(bytes, metadata)
		check(decoded.ok and decoded.resource is AudioStreamWAV, "Actual approved WAV decodes through the production raw loader")
		if decoded.ok:
			var stream: AudioStreamWAV = decoded.resource
			check(stream.mix_rate == 22050 and not stream.stereo and stream.format == AudioStreamWAV.FORMAT_16_BITS, "Ava delivery preserves PCM16 mono 22050 Hz")
			check(stream.data.size() == int(metadata.decoded_bytes), "Account for exact decoded PCM residency")
			check(absf(stream.get_length() - float(metadata.frames) / 22050.0) < 0.0001, "Complete approved duration survives raw decode")
		var altered: PackedByteArray = bytes.duplicate()
		altered[altered.size() - 1] ^= 1
		check(Manifest.decode(altered, metadata).code == "hash_mismatch", "Changed sample bytes cannot use human approval")
		resources.append(metadata)
		required.append(metadata.id)
	# This is an audio-only delivery review, not a curriculum module manifest.
	# No draft course status or required image/content/morphology gate is altered.
	var context := {"track": "professional", "course_id": "retail", "module_id": "module03", "curriculum_revision": "audio-delivery-review-6"}
	var manifest := {"schema_version": 1, "course_id": "retail", "module_id": "module03", "curriculum_revision": "audio-delivery-review-6", "resources": resources}
	check(decoded_total == 990648, "Twelve immutable recording receipts declare the exact PCM total")
	check(Manifest.validate_dependencies(manifest, required, context).ok, "All twelve exact sense dependencies fit the real bounded delivery contract")
	var loader = Loader.new()
	root.add_child(loader)
	loader.configure(ProjectSettings.globalize_path("res://"))
	loader.request_module(manifest, context, required)
	var completed: Array = await loader.completed
	check(completed[1].ok, "Native loader reads all twelve immutable production WAV files")
	var lease: Dictionary = loader.cache.pin_round(required)
	check(lease.ok, "A round can pin all twelve approved audio resources")
	for metadata: Dictionary in resources:
		var resource: Resource = loader.cache.get_resource(metadata.id, lease.get("lease", 0))
		check(resource is AudioStreamWAV, "A leased audio resource reaches the playback contract")
		if resource is AudioStreamWAV:
			check(resource.data.size() == int(metadata.decoded_bytes), "Cached stream retains complete approved samples")
	var active: Dictionary = loader.cache.stats()
	check(active.resident_bytes == decoded_total and active.resources == 12 and active.leases == 1, "Twelve complete clips consume their exact shared cache budget")
	loader.request_module(manifest, context, required)
	completed = await loader.completed
	check(completed[1].ok and loader.cache.stats().resident_bytes == active.resident_bytes, "Repeated selection reuses canonical audio without duplicate allocation")
	loader.cache.deactivate()
	loader.cache.trim_inactive()
	check(loader.cache.stats().resident_bytes == active.resident_bytes, "Pinned round audio survives inactive-resource trimming")
	loader.cache.release_round(lease.get("lease", 0))
	loader.cache.trim_inactive()
	check(loader.cache.stats().resident_bytes == 0 and loader.cache.stats().resources == 0 and loader.cache.stats().leases == 0, "Exit releases all decoded audio and leases")
	loader.queue_free()
	await process_frame
	print("Professional approved audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

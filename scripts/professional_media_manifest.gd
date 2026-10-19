extends RefCounted
## Raw delivery metadata and bounded decoding, independent of imported PCK assets.

const MAX_MANIFEST := 256 * 1024
const MAX_COMPRESSED := 10 * 1024 * 1024
const MAX_DECODED := 32 * 1024 * 1024
const MAX_RESIDENT := 128 * 1024 * 1024
const MAX_RESOURCES := 256


static func failure(message: String, code: String = "invalid_manifest") -> Dictionary:
	return {"ok": false, "retryable": true, "code": code, "error": message}


static func _whole(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value > 0 and value <= maximum


static func _matches(value: Variant, pattern: String) -> bool:
	if not value is String:
		return false
	var expression := RegEx.new()
	expression.compile(pattern)
	return expression.search(value) != null


static func validate_resource(value: Variant) -> Dictionary:
	if not value is Dictionary or not _matches(value.get("sha256"), "^[a-f0-9]{64}$") \
		or value.get("id") != "sha256:" + str(value.get("sha256")):
		return failure("Media requires its canonical SHA-256 resource identity.")
	if not value.get("format") in ["png", "webp", "jpg", "wav"] \
		or value.get("path") != "professional-media/%s.%s" % [value.sha256, value.get("format")]:
		return failure("Media needs an immutable content-addressed path.")
	if not _whole(value.get("compressed_bytes"), MAX_COMPRESSED) or not _whole(value.get("decoded_bytes"), MAX_DECODED):
		return failure("Media exceeds its delivery budget.", "budget_pressure")
	if value.get("kind") == "image":
		if not value.format in ["png", "webp", "jpg"] or not _whole(value.get("width"), 8192) \
			or not _whole(value.get("height"), 8192) or value.decoded_bytes != value.width * value.height * 8:
			return failure("Images require a conservative RGBA8 CPU and GPU budget.")
	elif value.get("kind") != "audio" or value.format != "wav" or not _whole(value.get("channels"), 2) \
		or not _whole(value.get("sample_rate"), 96000) or value.sample_rate < 8000 \
		or not _whole(value.get("frames"), MAX_DECODED / 2) or value.decoded_bytes != value.frames * value.channels * 2:
		return failure("Audio requires exact PCM16 frame, channel, and sample-rate metadata.")
	var normalized: Dictionary = value.duplicate(true)
	for key in ["compressed_bytes", "decoded_bytes", "width", "height", "frames", "channels", "sample_rate"]:
		if normalized.has(key):
			normalized[key] = int(normalized[key])
	return {"ok": true, "resource": normalized}


static func validate_manifest(source: Variant, expected: Dictionary = {}) -> Dictionary:
	if not source is Dictionary or JSON.stringify(source).to_utf8_buffer().size() > MAX_MANIFEST or not _whole(source.get("schema_version"), 2):
		return failure("The module media manifest is invalid or too large.")
	for key in ["course_id", "module_id", "curriculum_revision"]:
		if not _matches(source.get(key), "^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,255}$"):
			return failure("The module media manifest needs stable identities.")
		if expected.has(key) and expected[key] != source[key]:
			return failure("The media manifest belongs to another module revision.")
	if expected.has("track") and expected.track != "professional":
		return failure("Professional media needs a professional context.")
	if not source.get("resources") is Array or source.resources.is_empty() or source.resources.size() > MAX_RESOURCES:
		return failure("The module needs a small, nonempty resource inventory.")
	var ids: Dictionary = {}
	var normalized: Dictionary = source.duplicate(true)
	normalized.resources = []
	var compressed := 0
	var decoded := 0
	for value in source.resources:
		var checked: Dictionary = validate_resource(value)
		if not checked.ok:
			return checked
		if ids.has(value.id):
			return failure("A module must list each shared resource only once.")
		ids[value.id] = true
		normalized.resources.append(checked.resource)
		compressed += int(value.compressed_bytes)
		decoded += int(value.decoded_bytes)
	if source.schema_version == 1:
		if source.has("bundles"):
			return failure("Version 1 media cannot declare version 2 bundles.")
		if compressed > MAX_COMPRESSED or decoded > MAX_DECODED:
			return failure("The module exceeds the 10 MiB transfer or 32 MiB decoded delivery budget.", "budget_pressure")
	else:
		if compressed > MAX_COMPRESSED or decoded > MAX_RESIDENT:
			return failure("The module exceeds the 10 MiB transfer or 128 MiB residency budget.", "budget_pressure")
		var bundles: Dictionary = _validate_bundles(normalized)
		if not bundles.ok:
			return bundles
	return {"ok": true, "manifest": normalized, "compressed_bytes": compressed, "decoded_bytes": decoded}


static func _validate_bundles(source: Dictionary) -> Dictionary:
	if not source.get("bundles") is Array or source.bundles.is_empty() or source.bundles.size() > MAX_RESOURCES:
		return failure("Version 2 media requires a bounded, nonempty bundle inventory.")
	var resources: Dictionary = {}
	for value: Dictionary in source.resources:
		resources[value.id] = value
	var covered: Dictionary = {}
	var inventory: Dictionary = {}
	for bundle in source.bundles:
		if not bundle is Dictionary or not _matches(bundle.get("id"), "^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,255}$") \
			or not _matches(bundle.get("revision"), "^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,255}$"):
			return failure("A bundle needs a stable identity and revision.")
		var key: String = JSON.stringify([bundle.id, bundle.revision])
		if inventory.has(key):
			return failure("A module must list each bundle revision only once.")
		if not bundle.get("resource_ids") is Array or bundle.resource_ids.is_empty() or bundle.resource_ids.size() > MAX_RESOURCES:
			return failure("A bundle needs a bounded, nonempty resource inventory.")
		var members: Array = []
		var decoded := 0
		for id in bundle.resource_ids:
			if not id is String or not resources.has(id):
				return failure("A bundle refers to absent media.", "missing_dependency")
			if members.has(id):
				return failure("A bundle must list each shared resource only once.")
			members.append(id)
			covered[id] = true
			decoded += int(resources[id].decoded_bytes)
		if decoded > MAX_DECODED:
			return failure("A bundle exceeds the 32 MiB decoded delivery budget.", "budget_pressure")
		members.sort()
		inventory[key] = members
	if covered.size() != resources.size():
		return failure("Every module resource must belong to a delivery bundle.", "missing_dependency")
	return {"ok": true, "bundles": inventory}


static func bundle_inventory(source: Dictionary) -> Dictionary:
	var validated: Dictionary = validate_manifest(source)
	if not validated.ok:
		return validated
	return _validate_bundles(validated.manifest) if source.schema_version == 2 else {"ok": true, "bundles": {}}


static func parse_manifest(bytes: PackedByteArray, expected_sha256: String, expected: Dictionary = {}) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_MANIFEST or not _matches(expected_sha256, "^[a-f0-9]{64}$"):
		return failure("The media manifest is missing, too large, or has no immutable hash.")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	if hashing.finish().hex_encode() != expected_sha256:
		return failure("The media manifest failed its SHA-256 integrity check.", "hash_mismatch")
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return failure("The media manifest could not be understood.")
	return validate_manifest(parser.data, expected)


static func validate_dependencies(source: Dictionary, required_ids: Array, expected: Dictionary = {}) -> Dictionary:
	var validated: Dictionary = validate_manifest(source, expected)
	if not validated.ok:
		return validated
	var available: Dictionary = {}
	for metadata: Dictionary in validated.manifest.resources:
		available[metadata.id] = true
	for id in required_ids:
		if not id is String or not available.has(id):
			return failure("A required content or theme resource is absent from the module manifest.", "missing_dependency")
	return validated


static func verify_bytes(data: PackedByteArray, metadata: Dictionary) -> Dictionary:
	var checked: Dictionary = validate_resource(metadata)
	if not checked.ok:
		return checked
	if data.size() != int(metadata.compressed_bytes):
		return failure("The media transfer is incomplete or has changed size. Please retry.", "size_mismatch")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(data)
	if hashing.finish().hex_encode() != metadata.sha256:
		return failure("Media failed its SHA-256 integrity check. Please retry.", "hash_mismatch")
	return {"ok": true}


static func decode(data: PackedByteArray, metadata: Dictionary) -> Dictionary:
	var verified: Dictionary = verify_bytes(data, metadata)
	if not verified.ok:
		return verified
	if metadata.kind == "audio":
		return _decode_wav(data, metadata)
	var dimensions: Vector2i = image_dimensions(data, metadata.format)
	if dimensions != Vector2i(int(metadata.width), int(metadata.height)):
		return failure("The image header does not match its declared dimensions.", "decoded_size_mismatch")
	var image := Image.new()
	var loaded := ERR_FILE_UNRECOGNIZED
	match metadata.format:
		"png": loaded = image.load_png_from_buffer(data)
		"webp": loaded = image.load_webp_from_buffer(data)
		"jpg": loaded = image.load_jpg_from_buffer(data)
	if loaded != OK or image.is_empty() or image.get_size() != dimensions:
		return failure("The image could not be decoded. Please retry.", "decode_failed")
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	if image.get_data_size() * 2 != int(metadata.decoded_bytes):
		return failure("The decoded image exceeds its declared budget.", "decoded_size_mismatch")
	return {"ok": true, "resource": ImageTexture.create_from_image(image), "decoded_bytes": int(metadata.decoded_bytes)}


static func _be32(data: PackedByteArray, index: int) -> int:
	return (int(data[index]) << 24) | (int(data[index + 1]) << 16) | (int(data[index + 2]) << 8) | int(data[index + 3])


static func image_dimensions(data: PackedByteArray, format: String) -> Vector2i:
	if format == "png" and data.size() >= 33 and data.slice(0, 8).hex_encode() == "89504e470d0a1a0a" \
		and _be32(data, 8) == 13 and data.slice(12, 16).get_string_from_ascii() == "IHDR":
		return Vector2i(_be32(data, 16), _be32(data, 20))
	if format == "webp" and data.size() >= 30 and data.slice(0, 4).get_string_from_ascii() == "RIFF" \
		and data.slice(8, 12).get_string_from_ascii() == "WEBP" and data.decode_u32(4) + 8 == data.size():
		var index := 12
		var canvas := Vector2i.ZERO
		var pixels := Vector2i.ZERO
		while index + 8 <= data.size():
			var chunk: String = data.slice(index, index + 4).get_string_from_ascii()
			var count: int = data.decode_u32(index + 4)
			index += 8
			if index + count > data.size():
				return Vector2i.ZERO
			if chunk in ["ANIM", "ANMF"]:
				return Vector2i.ZERO
			if chunk == "VP8X":
				# Extended canvas and actual image payload must agree before decoding.
				if count != 10 or canvas != Vector2i.ZERO or data[index] & 2:
					return Vector2i.ZERO
				canvas = Vector2i(1 + int(data[index + 4]) + (int(data[index + 5]) << 8) + (int(data[index + 6]) << 16),
					1 + int(data[index + 7]) + (int(data[index + 8]) << 8) + (int(data[index + 9]) << 16))
			elif chunk in ["VP8L", "VP8 "]:
				if pixels != Vector2i.ZERO:
					return Vector2i.ZERO
				if chunk == "VP8L" and count >= 5 and data[index] == 0x2f:
					pixels = Vector2i(1 + (data.decode_u32(index + 1) & 0x3fff), 1 + ((data.decode_u32(index + 1) >> 14) & 0x3fff))
				elif chunk == "VP8 " and count >= 10 and data.slice(index + 3, index + 6).hex_encode() == "9d012a":
					pixels = Vector2i(data.decode_u16(index + 6) & 0x3fff, data.decode_u16(index + 8) & 0x3fff)
				else:
					return Vector2i.ZERO
			index += count + count % 2
		if index == data.size() and (canvas == Vector2i.ZERO or canvas == pixels):
			return pixels
	if format == "jpg" and data.size() >= 4 and data[0] == 0xff and data[1] == 0xd8:
		var index := 2
		while index + 3 < data.size():
			if data[index] != 0xff:
				return Vector2i.ZERO
			while index < data.size() and data[index] == 0xff:
				index += 1
			if index + 2 >= data.size():
				break
			var marker: int = data[index]
			index += 1
			if marker in [0xd9, 0xda]:
				break
			var size: int = (int(data[index]) << 8) | int(data[index + 1])
			if size < 2 or index + size > data.size():
				break
			if marker in [0xc0, 0xc1, 0xc2] and size >= 8:
				return Vector2i((int(data[index + 5]) << 8) | int(data[index + 6]), (int(data[index + 3]) << 8) | int(data[index + 4]))
			index += size
	return Vector2i.ZERO


static func _decode_wav(data: PackedByteArray, metadata: Dictionary) -> Dictionary:
	if data.size() < 44 or data.slice(0, 4).get_string_from_ascii() != "RIFF" \
		or data.slice(8, 12).get_string_from_ascii() != "WAVE" or data.decode_u32(4) + 8 != data.size():
		return failure("Audio must be a complete PCM16 WAV file.", "decode_failed")
	var index := 12
	var format_seen := false
	var start := -1
	var count := 0
	while index + 8 <= data.size():
		var kind: String = data.slice(index, index + 4).get_string_from_ascii()
		var size: int = data.decode_u32(index + 4)
		index += 8
		if index + size > data.size():
			return failure("The audio contains an incomplete chunk.", "decode_failed")
		if kind == "fmt ":
			if format_seen or size < 16 or data.decode_u16(index) != 1 or data.decode_u16(index + 14) != 16 \
				or data.decode_u16(index + 2) != int(metadata.channels) or data.decode_u32(index + 4) != int(metadata.sample_rate) \
				or data.decode_u16(index + 12) != int(metadata.channels) * 2 \
				or data.decode_u32(index + 8) != int(metadata.sample_rate) * int(metadata.channels) * 2:
				return failure("The audio format does not match its PCM16 delivery metadata.", "decoded_size_mismatch")
			format_seen = true
		elif kind == "data":
			if start >= 0:
				return failure("The audio has multiple sample payloads.", "decode_failed")
			start = index
			count = size
		index += size + (size % 2)
	if index != data.size() or not format_seen or start < 0 or count != int(metadata.decoded_bytes):
		return failure("The decoded audio does not match its declared frame budget.", "decoded_size_mismatch")
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = int(metadata.channels) == 2
	stream.mix_rate = int(metadata.sample_rate)
	stream.data = data.slice(start, start + count)
	return {"ok": true, "resource": stream, "decoded_bytes": stream.data.size()}

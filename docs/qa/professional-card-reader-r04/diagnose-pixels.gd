extends SceneTree

const Manifest = preload("res://scripts/professional_media_manifest.gd")
const OUTPUT := "res://build/professional-english/card-reader-review-20261020/pixel-diagnostic-r01"

func _initialize() -> void:
	_run.call_deferred()

func _hash(bytes: PackedByteArray) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(bytes)
	return hasher.finish().hex_encode()

func _run() -> void:
	if DirAccess.dir_exists_absolute(OUTPUT):
		printerr("Existing pixel diagnostic preserved")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/professional-card-reader.json"))
	var rows: Array = []
	for item: Dictionary in fixture.resources:
		if item.metadata.kind != "image": continue
		var source := Image.load_from_file(item.source)
		var loaded: Dictionary = Manifest.decode(FileAccess.get_file_as_bytes(item.source), item.metadata)
		if not loaded.get("ok", false):
			rows.append({"id": item.lexeme_id, "failure": loaded})
			continue
		var decoded: Image = loaded.resource.get_image()
		var source_format: int = source.get_format()
		var decoded_format: int = decoded.get_format()
		var source_mipmaps: bool = source.has_mipmaps()
		var decoded_mipmaps: bool = decoded.has_mipmaps()
		source.convert(Image.FORMAT_RGBA8)
		decoded.convert(Image.FORMAT_RGBA8)
		var expected: PackedByteArray = source.get_data()
		var actual: PackedByteArray = decoded.get_data()
		var name: String = item.lexeme_id.replace(".", "-")
		source.save_png(OUTPUT.path_join(name + "-source.png"))
		decoded.save_png(OUTPUT.path_join(name + "-decoded.png"))
		var different_bytes := 0
		var different_pixels := 0
		var different_visible_pixels := 0
		var max_delta := 0
		var first_differences: Array = []
		if expected.size() == actual.size():
			for index in range(0, expected.size(), 4):
				var changed := false
				for channel in range(4):
					var delta: int = absi(int(expected[index + channel]) - int(actual[index + channel]))
					if delta > 0:
						different_bytes += 1
						changed = true
					max_delta = maxi(max_delta, delta)
				if changed:
					different_pixels += 1
					if expected[index + 3] != 0 or actual[index + 3] != 0: different_visible_pixels += 1
					if first_differences.size() < 20:
						first_differences.append({"pixel": index / 4, "source": Array(expected.slice(index, index + 4)), "decoded": Array(actual.slice(index, index + 4))})
		rows.append({"id": item.lexeme_id, "source": item.source, "source_sha256": FileAccess.get_sha256(item.source),
			"source_format": source_format, "decoded_format": decoded_format, "source_mipmaps": source_mipmaps, "decoded_mipmaps": decoded_mipmaps,
			"source_size": [source.get_width(), source.get_height()], "decoded_size": [decoded.get_width(), decoded.get_height()],
			"source_rgba_bytes": expected.size(), "decoded_rgba_bytes": actual.size(),
			"source_rgba_sha256": _hash(expected), "decoded_rgba_sha256": _hash(actual),
			"different_bytes": different_bytes, "different_pixels": different_pixels, "different_visible_pixels": different_visible_pixels,
			"max_channel_delta": max_delta, "first_differences": first_differences})
	var report := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "rows": rows}, "  ") + "\n")
	report.close()
	print(JSON.stringify(rows, "  "))
	quit()

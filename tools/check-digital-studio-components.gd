extends SceneTree
## Internal static-component evidence only. Never edits production readiness.
## Run with a fresh --results-dir=res://build/professional-english/... and
## --private-user-root=res://build/... matching this process's private APPDATA.

const Loader = preload("res://scripts/professional_media_loader.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const Manifest = preload("res://scripts/professional_media_manifest.gd")
const ThemeArt = preload("res://scripts/learning_theme_art.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const Context = preload("res://scripts/learning_context.gd")
const LAYERS := "res://build/professional-english/software-data-theme-render-r04/layers-r01"
const SOURCE_REST := "res://build/professional-english/software-data-theme-render-r04/motion-r01/composition-rest.png"
const THEMES := "res://data/professional/themes.json"
const PREVIEW := "res://assets/images/professional-previews/software-data.png"
const THEME_ID := "professional_software_data"
const REVISION := "digital-studio-static-components-internal-r01"
const PREVIEW_HASH := "5c87d4a3045d91aa60a5fb4be951baa43834fb39fbf684a5ee7aa132daece5b2"
const EXPECTED := {
	"environment.png": "6a3e2fab06a3fb72c78a1414eb8919d7ba7e038fcc0abf73e16fd37203d45062",
	"props.png": "9bf8c55a9a4690f2c90f11ee62741ba49db0f271caa86ffb64195b28717f5b05",
	"motion-sheet.png": "90938fc426893b9944501192fa5fb9feae0cc93a0806080aee83898d36bdfb03"
}
const SIZES: Array[Vector2i] = [Vector2i(768, 768), Vector2i(320, 568),
	Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]

var output := ""
var private_user_root := ""
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var pins: Array[Dictionary] = []
var resources: Array[Dictionary] = []
var decoded: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var weak_resources: Array = []
var urls: Array[String] = []
var lifecycle: Dictionary = {}
var production: Dictionary = {}
var profile: Dictionary = {}
var manifest: Dictionary = {}
var scope := ""
var total_bytes := 0
var media
var layer
var viewport: SubViewport
var started := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "check": label})
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)
	return ok


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _rgba(image: Image) -> String:
	var copy: Image = image.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	return _hash(copy.get_data())


func _normalized(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").to_lower()


func _open_run() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--results-dir="):
			output = argument.trim_prefix("--results-dir=").trim_suffix("/")
		elif argument.begins_with("--private-user-root="):
			private_user_root = argument.trim_prefix("--private-user-root=")
		else:
			return _check(false, "Unknown argument: " + argument)
	if not _check(output.begins_with("res://build/professional-english/")
		and not output.contains("..") and not output.contains("\\"), "Explicit local results directory is bounded"):
		return false
	var project: String = _normalized(ProjectSettings.globalize_path("res://"))
	var private_root: String = _normalized(ProjectSettings.globalize_path(private_user_root))
	if not _check(not private_user_root.is_empty() and private_root.begins_with(project + "/build/")
		and _normalized(OS.get_user_data_dir()).begins_with(private_root + "/"), "Process uses the explicitly isolated user directory"):
		return false
	if not _check(not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output), "Previous attempts are preserved; results directory is new"):
		return false
	return _check(DirAccess.make_dir_recursive_absolute(output.path_join("delivery/professional-media")) == OK, "Fresh private delivery directory created")


func _pin(path: String) -> bool:
	if not _check(FileAccess.file_exists(path), "Input exists: " + path):
		return false
	pins.append({"path": path, "bytes": FileAccess.get_file_as_bytes(path).size(), "sha256": FileAccess.get_sha256(path)})
	return true


func _inputs() -> bool:
	var before: int = failures.size()
	for path: String in [THEMES, PREVIEW, LAYERS.path_join("layer-report.json"),
		LAYERS.path_join("composition-rest.png"), SOURCE_REST, "res://data/professional/courses/software_data.json",
		"res://data/professional/catalog.json", "res://project.godot",
		"res://scripts/professional_media_loader.gd", "res://scripts/professional_media_cache.gd",
		"res://scripts/professional_media_access.gd", "res://scripts/professional_media_manifest.gd",
		"res://scripts/learning_theme_art.gd", "res://scripts/learning_theme_motion.gd",
		"res://tools/check-digital-studio-components.gd"]:
		_pin(path)
	var report: Dictionary = _json(LAYERS.path_join("layer-report.json"))
	_check(report.get("static_reconstruction_exact", false) and report.get("all_motion_reconstructions_exact", false)
		and report.get("loop_endpoint_exact", false), "Retained layer derivation reports exact source reconstruction")
	var matches: Array = _json(THEMES).get("profiles", []).filter(func(row: Dictionary) -> bool: return row.get("id") == THEME_ID)
	if not _check(matches.size() == 1, "Exactly one production Digital Studio profile exists"):
		return false
	production = matches[0].duplicate(true)
	_check(production.get("status") == "pending" and production.art.home.status == "pending"
		and production.ambient_motion.status == "pending", "Full theme, home and motion remain pending")
	_check(production.preview.sha256 == PREVIEW_HASH and FileAccess.get_sha256(PREVIEW) == PREVIEW_HASH,
		"Existing accepted preview is byte-identical and is not newly approved")
	for filename: String in EXPECTED:
		var asset_matches: Array = report.get("assets", []).filter(func(row: Dictionary) -> bool: return row.get("file") == filename)
		if not _check(asset_matches.size() == 1, "Exact layer report entry: " + filename):
			continue
		var source: String = LAYERS.path_join(filename)
		_pin(source)
		var row: Dictionary = asset_matches[0]
		_check(row.sha256 == EXPECTED[filename] and FileAccess.get_sha256(source) == EXPECTED[filename], "Exact candidate SHA-256: " + filename)
		_add_resource(source, row.sha256, int(row.width), int(row.height), int(row.compressed_bytes), int(row.decoded_bytes))
	_add_resource(PREVIEW, PREVIEW_HASH, 512, 320, 46113, 1310720)
	_check(resources.size() == 4 and total_bytes == 11879936, "Exactly four resources and 11,879,936 decoded CPU-plus-GPU bytes")
	var environment: Image = Image.load_from_file(LAYERS.path_join("environment.png"))
	var props: Image = Image.load_from_file(LAYERS.path_join("props.png"))
	var rest: Image = Image.load_from_file(LAYERS.path_join("composition-rest.png"))
	if _check(environment != null and props != null and rest != null, "Static source components decode independently"):
		environment.convert(Image.FORMAT_RGBA8)
		props.convert(Image.FORMAT_RGBA8)
		environment.blend_rect(props, Rect2i(Vector2i.ZERO, props.get_size()), Vector2i.ZERO)
		_check(_rgba(environment) == _rgba(rest), "Native unscaled environment plus props reconstruct every rest-source pixel exactly")
	var rest_records: Array = report.get("sources", []).filter(func(row: Dictionary) -> bool: return row.get("file") == "composition-rest.png")
	_check(rest_records.size() == 1 and FileAccess.get_sha256(SOURCE_REST) == str(rest_records[0].sha256), "Original rest PNG matches the retained source render identity")
	_check(_rgba(rest) == _rgba(Image.load_from_file(SOURCE_REST)), "Derived rest preserves original source pixels despite PNG re-encoding")
	var real := Catalog.new()
	if _check(real.load_index(), "Actual production catalog loads"):
		var course: Dictionary = real.course("software_data")
		for mode: String in ["match", "memory", "pop", "jelly", "word_jelly", "phrase"]:
			var resolved: Dictionary = real.resolve(Context.professional("software_data", "module03", str(course.get("curriculum_revision", "")), mode), 42)
			_check(not resolved.get("ok", false) and resolved.get("code") == "content_pending", "Production Software03 still fails closed: " + mode)
	manifest = {"schema_version": 1, "course_id": "software_data", "module_id": "component_fixture",
		"curriculum_revision": REVISION, "resources": resources.duplicate(true)}
	_check(Manifest.validate_manifest(manifest).get("ok", false), "Internal manifest uses actual schema and budget checks")
	return failures.size() == before


func _add_resource(source: String, digest: String, width: int, height: int, compressed: int, resident: int) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source)
	var metadata: Dictionary = {"id": "sha256:" + digest, "sha256": digest,
		"path": "professional-media/" + digest + ".png", "kind": "image", "format": "png",
		"width": width, "height": height, "compressed_bytes": compressed, "decoded_bytes": resident}
	if not _check(Manifest.verify_bytes(bytes, metadata).get("ok", false), "Raw source matches its immutable delivery metadata: " + source):
		return
	var file := FileAccess.open(output.path_join("delivery").path_join(metadata.path), FileAccess.WRITE)
	if not _check(file != null, "Private raw sidecar is writable: " + source):
		return
	file.store_buffer(bytes)
	file.close()
	resources.append(metadata)
	total_bytes += resident


func _descriptor(metadata: Dictionary) -> Dictionary:
	return {"status": "integrated", "path": "res://" + str(metadata.path), "sha256": metadata.sha256,
		"source": "Pinned local candidate derivative; see retained Digital Studio source records",
		"creator": "Kenney; Innerscene; recorded scene adaptation", "license": "CC0 1.0",
		"review": {"status": "reviewed", "reviewer": "Internal technical fixture only; no production approval"}}


func _load() -> bool:
	media = Loader.new()
	root.add_child(media)
	media.configure(ProjectSettings.globalize_path(output.path_join("delivery")), null)
	_check(not media.fetch_override.is_valid(), "Real native raw loader has no fetch override")
	var ids: Array = resources.map(func(row: Dictionary) -> String: return row.id)
	var generation: int = media.request_module(manifest, {}, ids)
	var completion: Array = await media.completed
	if not _check(completion[0] == generation and completion[1].get("ok", false), "Real loader decodes and activates the four-image manifest"):
		return false
	var acquired: Dictionary = Access.acquire(media.cache, ids)
	if not _check(acquired.get("ok", false), "Actual Access acquires one scoped cache lease"):
		return false
	scope = acquired.scope
	_inspect_resources()
	lifecycle["loaded"] = media.cache.stats()
	var stats: Dictionary = lifecycle.loaded
	var active: Array = stats.active_ids.duplicate()
	active.sort()
	ids.sort()
	_check(active == ids and stats.resources == 4 and stats.leases == 1 and stats.resident_bytes == total_bytes
		and stats.pinned_bytes == total_bytes and stats.reserved_bytes == 0, "Loaded cache owns only four exact resources, exact bytes and one lease")
	media.cache.deactivate()
	media.cache.trim_inactive()
	lifecycle["lease_only"] = media.cache.stats()
	stats = lifecycle.lease_only
	_check(stats.active_ids.is_empty() and stats.resources == 4 and stats.leases == 1
		and stats.resident_bytes == total_bytes and stats.pinned_bytes == total_bytes,
		"One lease retains exact resources after deactivate and trim")
	for url: String in urls:
		_check(Access.resource(url) != null, "Lease-only scope still resolves: " + url)
	profile = production.duplicate(true)
	profile["id"] = "digital_studio_internal_static_fixture"
	profile["art"] = {"environment": _descriptor(resources[0]), "props": _descriptor(resources[1])}
	profile.erase("ambient_motion")
	var bound: Dictionary = Access.bind_content({"theme_profile": profile}, scope)
	if not _check(bound.get("media_scope") == scope, "Actual Access binds only the two internal static art descriptors"):
		return false
	profile = bound.theme_profile
	return failures.is_empty()


func _inspect_resources() -> void:
	for metadata: Dictionary in resources:
		var url: String = Access.path(scope, metadata.sha256)
		urls.append(url)
		var texture: Texture2D = Access.resource(url) as Texture2D
		if not _check(texture != null, "Exact scoped texture resolves: " + metadata.id):
			continue
		weak_resources.append(weakref(texture))
		_check(texture == media.cache.get_resource(metadata.id), "Scope returns the actual active cache resource: " + metadata.id)
		_check(texture.get_size() == Vector2(metadata.width, metadata.height), "Exact decoded dimensions: " + metadata.id)
		var source: Image = Image.load_from_file(output.path_join("delivery").path_join(metadata.path))
		var digest: String = _rgba(texture.get_image())
		_check(digest == _rgba(source), "Exact decoded source pixels before rendering: " + metadata.id)
		decoded.append({"id": metadata.id, "rgba_sha256_before_render": digest, "width": metadata.width,
			"height": metadata.height, "decoded_bytes": metadata.decoded_bytes})
	_check(Access.resource(Access.path(scope, "0".repeat(64))) == null, "Scope denies an unleased hash")
	_check(Access.resource(Access.path("absent_scope", resources[0].sha256)) == null, "Unknown scope cannot resolve a known hash")


func _settle() -> void:
	for unused in range(4):
		await process_frame
	await RenderingServer.frame_post_draw


func _render() -> void:
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	layer = ThemeArt.new()
	viewport.add_child(layer)
	for dimensions: Vector2i in SIZES:
		viewport.size = dimensions
		layer.size = Vector2(dimensions)
		_check(layer.show_profile(profile, "environment", true), "Real theme layer presents the internal static profile")
		await _settle()
		var snapshot: Dictionary = layer.snapshot()
		_check(snapshot.ready and snapshot.current_images == 2 and snapshot.previous_images == 0
			and snapshot.motion_frames.is_empty() and not snapshot.motion_processing, "Exactly environment and props render without animation")
		for role: String in ["environment", "props"]:
			_check(layer._current.get_node(role).texture == Access.resource(profile.art[role].path), "Theme layer uses the exact leased " + role + " texture")
		var screen: Image = viewport.get_texture().get_image()
		var name: String = "static-%dx%d.png" % [dimensions.x, dimensions.y]
		_check(screen.get_size() == dimensions and screen.save_png(output.path_join(name)) == OK, "Actual static component screenshot saved: " + name)
		captures.append({"file": name, "width": dimensions.x, "height": dimensions.y,
			"sha256": FileAccess.get_sha256(output.path_join(name)), "bytes": FileAccess.get_file_as_bytes(output.path_join(name)).size(),
			"layer_snapshot": snapshot, "visual_review": "pending_independent_inspection",
			"comparison": "No scaled pixel-equality claim; source reconstruction alone is exact."})


func _dispose() -> void:
	if is_instance_valid(layer):
		layer.clear()
	if is_instance_valid(viewport):
		viewport.free()
	layer = null
	viewport = null
	if not scope.is_empty():
		Access.release(scope)
	for url: String in urls:
		_check(Access.resource(url) == null, "Released scope no longer resolves: " + url)
	if is_instance_valid(media):
		media.cache.deactivate()
		media.cache.trim_inactive()
		lifecycle["disposed"] = media.cache.stats()
		var stats: Dictionary = lifecycle.disposed
		_check(stats.resources == 0 and stats.leases == 0 and stats.resident_bytes == 0
			and stats.pinned_bytes == 0 and stats.reserved_bytes == 0 and stats.active_ids.is_empty(), "Disposal clears all cache ownership and budgets")
		media.free()
	media = null
	await _settle()
	for reference: WeakRef in weak_resources:
		_check(reference.get_ref() == null, "No decoded texture survives the layer and cache disposal")


func _finish() -> void:
	for pin: Dictionary in pins:
		_check(FileAccess.file_exists(pin.path) and FileAccess.get_sha256(pin.path) == pin.sha256
			and FileAccess.get_file_as_bytes(pin.path).size() == pin.bytes, "Input remains byte-identical after run: " + str(pin.path))
	var report: Dictionary = {"schema": 1, "status": "technical_pass_pending_independent_static_visual_review" if failures.is_empty() else "failed_attempt_preserved",
		"started_utc": started, "finished_utc": Time.get_datetime_string_from_system(true),
		"fixture_revision": REVISION, "production_theme_status": production.get("status", "unknown"),
		"scope": "Standalone actual static theme layer; no Main, full-game, animation, human or device acceptance.",
		"motion_candidate": "Motion sheet bytes are decoded and leased only; no playback or visual motion acceptance.",
		"input_pins": pins, "manifest": manifest, "decoded_images": decoded, "cache_lifecycle": lifecycle,
		"captures": captures, "checks": checks, "failures": failures,
		"limitations": "No production descriptors are edited. Existing accepted preview is unchanged. Fractionally scaled layers require visual inspection; no rendered-pixel tolerance or normalization is used."}
	if not output.is_empty() and DirAccess.dir_exists_absolute(output):
		var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t") + "\n")
			file.close()
	print("Digital Studio static components: %d checks, %d failures" % [checks.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	started = Time.get_datetime_string_from_system(true)
	if not _open_run():
		quit(1)
		return
	if _inputs():
		if await _load():
			await _render()
	await _dispose()
	_finish()

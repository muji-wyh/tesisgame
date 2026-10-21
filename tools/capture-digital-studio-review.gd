extends SceneTree
## Candidate scene inspection in actual Main. No production readiness is changed.

const Flow = preload("res://tests/godot/professional_application_flow_tests.gd")
const MediaFixture = preload("res://tests/godot/professional_round_loader_tests.gd")
const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
const Context = preload("res://scripts/learning_context.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const THEME_FILE := "res://data/professional/themes.json"
const THEME_ID := "professional_software_data"
const SIZES: Array[Vector2i] = [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]
const POSES := ["rest", "negative", "positive"]
const SOURCE_FILES := ["composition-rest.png", "extreme-00.png", "extreme-01.png"]


class CandidateCatalog extends Flow.Catalog:

	var candidate: Dictionary = {}
	var image_ids: Array = []

	func courses() -> Array:
		return [{"id": "software_data", "title": "Digital Studio layout fixture",
			"description": "Synthetic lesson content for candidate scene inspection.", "theme_id": THEME_ID}]

	func theme_profile(id: String) -> Dictionary:
		return candidate.duplicate(true) if id == THEME_ID else super.theme_profile(id)

	func resolve(context: Dictionary, seed_value: int = -1) -> Dictionary:
		var result: Dictionary = super.resolve(context, seed_value)
		result.course_title = "Digital Studio layout fixture"
		result.module_title = "Synthetic lesson; artwork pending review"
		result.required_resource_ids.append_array(image_ids)
		return result


var source_directory: String = ""
var output: String = ""
var production_hash: String = ""
var checks: int = 0
var failures: Array[String] = []
var captures: Array = []
var source_records: Array = []
var texture_hashes: Array[String] = []
var textures: Array[Texture2D] = []
var routing: Array = []
var visibility_resumes: int = 0
var app


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)
	return condition


func _settle(frames: int = 8) -> void:
	for unused in range(frames):
		await process_frame
		_resume_capture_visibility()


func _resume_capture_visibility() -> void:
	# Desktop focus can leave this inspection process while the terminal polls.
	# Exercise Main's real foreground lifecycle; never bypass it with a flag edit.
	if is_instance_valid(app) and app.is_node_ready() and app._page_hidden:
		app.on_page_visible()
		visibility_resumes += 1


func _arguments() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-dir="):
			source_directory = argument.trim_prefix("--source-dir=").trim_suffix("/")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=").trim_suffix("/")
		else:
			return _check(false, "Unknown review argument: " + argument)
	if not _check(source_directory.begins_with("res://build/professional-english/software-data-theme-render-")
		and not ".." in source_directory and not "\\" in source_directory, "Select an existing Digital Studio source render"):
		return false
	if not _check(output.begins_with("res://build/professional-english/software-data-theme-review-")
		and not ".." in output and not "\\" in output, "Use a fresh Digital Studio review output directory"):
		return false
	return _check(not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output),
		"Existing review evidence must not be overwritten")


func _source_images() -> bool:
	var report_path: String = source_directory.path_join("render-report.json")
	if not _check(FileAccess.file_exists(report_path), "The source renderer report exists"):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if not _check(parsed is Dictionary, "The source renderer report is an object"):
		return false
	var report: Dictionary = parsed
	if not _check(report.get("stage") == "rest" and report.get("failures", ["missing"]).is_empty()
		and report.get("repeated_rest_pixels_equal", false), "The source rest render has no script failures and repeats exactly"):
		return false
	for index in range(SOURCE_FILES.size()):
		var name: String = SOURCE_FILES[index]
		var records: Array = report.get("captures", []).filter(func(row: Dictionary) -> bool: return row.get("path") == name)
		if not _check(records.size() == 1, "Source report identifies " + name):
			return false
		var record: Dictionary = records[0]
		var path: String = source_directory.path_join(name)
		if not _check(FileAccess.file_exists(path), "Source image exists: " + name):
			return false
		var digest: String = FileAccess.get_sha256(path)
		if not _check(digest == record.get("sha256") and FileAccess.get_file_as_bytes(path).size() == int(record.get("bytes", -1)),
			"Source image matches its native render report: " + name):
			return false
		var picture: Image = Image.load_from_file(path)
		if not _check(picture != null and picture.get_size() == Vector2i(768, 768), "Source image is a complete 768-square scene: " + name):
			return false
		textures.append(ImageTexture.create_from_image(picture))
		texture_hashes.append(digest)
		source_records.append({"pose": POSES[index], "path": path, "sha256": digest,
			"angle_degrees": record.get("angle_degrees", 0), "render_report_sha256": FileAccess.get_sha256(report_path)})
	return true


func _candidate_profile() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(THEME_FILE))
	if not _check(parsed is Dictionary, "Current theme catalog is readable"):
		return {}
	var matches: Array = parsed.get("profiles", []).filter(func(profile: Dictionary) -> bool: return profile.get("id") == THEME_ID)
	if not _check(matches.size() == 1 and matches[0].get("status") == "pending", "Digital Studio remains pending in the production catalog"):
		return {}
	var profile: Dictionary = matches[0].duplicate(true)
	# This in-memory image descriptor exercises presentation only. The source
	# composition has not earned art, animation, curriculum or theme acceptance.
	profile.art = {"environment": {"status": "integrated", "path": source_directory.path_join(SOURCE_FILES[0]),
		"sha256": texture_hashes[0], "source": "Acquired Kenney Furniture Kit and Innerscene whiteboard scene",
		"creator": "Kenney; Innerscene", "license": "CC0 1.0",
		"review": {"status": "reviewed", "reviewer": "Process-only candidate layout fixture; no production acceptance"}}}
	# The three complete static poses precede atlas derivation. No motion clip
	# or source animation is invented for this layout inspection.
	profile.erase("ambient_motion")
	return profile


func _create_main(profile: Dictionary) -> bool:
	var directory: String = ProjectSettings.globalize_path(output.path_join("private-state"))
	if not _check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Review saves use a private directory"):
		return false
	app = load("res://scenes/main.tscn").instantiate()
	PlayerFixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.reduced_motion = true
	if not _check(app._presentation.save_preferences(), "Review presentation preferences are isolated"):
		app.free()
		app = null
		return false
	var catalog := CandidateCatalog.new()
	catalog.candidate = profile
	for digest: String in texture_hashes:
		catalog.image_ids.append("sha256:" + digest)
	app.professional.loader.media.free()
	app.professional.loader.media = MediaFixture.FixtureMedia.new()
	app.professional.loader.catalog = catalog
	app.professional.loader._owner.free()
	app.professional.loader._owner = MediaFixture.FixtureOwner.new(catalog)
	app.professional.loader.media.cache.values["sha256:" + MediaFixture.IMAGE_HASH] = load("res://assets/images/words/absent.png")
	app.professional.loader.media.cache.values["sha256:" + MediaFixture.AUDIO_HASH] = load("res://assets/audio/jelly-match/collect-do.wav")
	for index in range(textures.size()):
		app.professional.loader.media.cache.values[catalog.image_ids[index]] = textures[index]
	root.add_child(app)
	# Native Main first loads Growth's local assets asynchronously. Starting a
	# candidate request before that handoff finishes lets the pending startup
	# round replace the fixture selection. Wait for the real boot condition.
	for unused in range(360):
		await process_frame
		_resume_capture_visibility()
		if not app._vocabulary_booting and not paused and app.professional.session.snapshot().pending_count == 0:
			break
		if app.professional.phase == "failed":
			break
	_record_routing("initial-boot")
	return _check(not app._vocabulary_booting and not paused, "Current Main completes its native vocabulary startup before candidate selection")


func _record_routing(stage: String) -> void:
	var loader = app.professional.loader
	var preparation: Dictionary = loader._preparation
	var session: Dictionary = app.professional.session.snapshot()
	var entry: Dictionary = {"stage": stage, "tree_paused": paused, "vocabulary_booting": app._vocabulary_booting,
		"page_hidden": app._page_hidden, "backdrop_visible": app._learning_backdrop.is_visible_in_tree(),
		"finish_confirmation_open": app._finish_confirmation_open(), "collection_visible": app.collection_page.visible,
		"vocabulary": app._vocabulary_snapshot(), "home_open": app._mode_menu_open(),
		"home_context": app._home_context.duplicate(true), "round_context": app._round_context.duplicate(true),
		"professional_phase": app.professional.phase, "professional_error": app.professional.error,
		"pending_selection": app.professional.pending.get("selection", -1),
		"preparation_selection": preparation.get("selection", -1), "preparation_phase": preparation.get("phase", ""),
		"preparation_media_generation": preparation.get("media_generation", -1),
		"media_generation": loader.media.generation, "media_requests": loader.media.request_count,
		"owner_configured": loader._owner.configured, "owner_requests": loader._owner.request_count,
		"session": {"ready": session.ready, "blocked": session.blocked, "pending_count": session.pending_count,
			"source_id": session.source_id, "error": session.error}, "store_error": app.professional.store.error}
	routing.append(entry)
	print("Digital Studio routing: " + JSON.stringify(entry))


func _start(mode: String) -> bool:
	_resume_capture_visibility()
	app._show_mode_menu()
	if not _check(app._mode_menu_open(), "Actual Main opens Home before selecting " + mode):
		_record_routing(mode + "-home-rejected")
		return false
	app._select_learning_context(Context.professional("software_data", "module03", "v1", mode))
	app.choose_mode(mode)
	var selection: int = app.professional.pending.get("selection", -1)
	_record_routing(mode + "-selected")
	var media_started: bool = false
	for unused in range(180):
		await process_frame
		_resume_capture_visibility()
		var preparation: Dictionary = app.professional.loader._preparation
		if preparation.get("selection") == selection and preparation.get("phase") == "media" \
			and preparation.get("media_generation", -1) == app.professional.loader.media.generation:
			media_started = true
			break
		if app.professional.phase == "failed":
			break
	_record_routing(mode + "-media")
	if not _check(media_started, "Current Main reaches the selected fixture media request for " + mode):
		return false
	app.professional.loader.media.finish(app.professional.loader.media.generation)
	for unused in range(180):
		await process_frame
		_resume_capture_visibility()
		if app._round_context.get("course_id") == "software_data" and app._mode_id == mode \
			and not app._mode_menu_open() and app.professional.can_play(app._round_id):
			break
		if app.professional.phase == "failed":
			break
	_record_routing(mode + "-entered")
	if not _check(app._round_context.get("course_id") == "software_data" and app._mode_id == mode
		and not app._mode_menu_open() and app.professional.can_play(app._round_id), "Actual Main enters the private " + mode + " fixture"):
		return false
	app.audio.halt()
	app.set_reduced_motion(true)
	if mode == "word_jelly":
		app._word_jelly.set_process(false)
		app._word_jelly.game.spawn_interval = 10000.0
	app._refresh()
	await _settle()
	return _check(app._learning_backdrop.has_art(), "Actual Main presents the candidate Digital Studio scene for " + mode)


func _rect(control: Control) -> Array:
	var value: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _geometry(mode: String) -> Dictionary:
	var result: Dictionary = {"backdrop_rect_pixels": _rect(app._learning_backdrop), "controls": []}
	if mode == "word_jelly":
		var board: Control = app._word_jelly
		result.board = board.snapshot()
		var controls: Array[Control] = [board.collect_button, board.finish_button, board.drop_button]
		for button: Control in board.powerup_buttons.values():
			controls.append(button)
		for control: Control in controls:
			result.controls.append({"name": str(control.name), "rect_pixels": _rect(control), "visible": control.is_visible_in_tree()})
	else:
		for card: Control in app.cards.values():
			result.controls.append({"name": str(card.name), "rect_pixels": _rect(card), "visible": card.is_visible_in_tree()})
	return result


func _capture_pose(mode: String, dimensions: Vector2i, pose: int) -> bool:
	var descriptor: Dictionary = app._round_content.theme_profile.art.environment
	descriptor.sha256 = texture_hashes[pose]
	descriptor.path = Access.path(str(app._round_content.media_scope), texture_hashes[pose])
	app._refresh()
	await _settle()
	await RenderingServer.frame_post_draw
	var backdrop: Control = app._learning_backdrop
	var environment: TextureRect = backdrop._current.get_node("environment")
	if not _check(not app._page_hidden and not app._mode_menu_open() and backdrop.is_visible_in_tree()
		and environment.is_visible_in_tree() and is_equal_approx(backdrop._current.modulate.a, 1.0),
		"Actual Main visibly presents the candidate layer: %s %s %s" % [mode, dimensions, POSES[pose]]):
		_record_routing(mode + "-capture-hidden")
		return false
	if not _check(environment.texture == textures[pose]
		and Access.resource(descriptor.path) == textures[pose]
		and environment.texture.get_image().get_data() == textures[pose].get_image().get_data(),
		"Visible layer uses the exact scoped source pixels: %s %s %s" % [mode, dimensions, POSES[pose]]):
		return false
	var picture: Image = root.get_texture().get_image()
	var name: String = "%s-%dx%d-%s.png" % [mode, dimensions.x, dimensions.y, POSES[pose]]
	var path: String = output.path_join(name)
	_check(picture.get_size() == dimensions, "Main capture matches the requested viewport: " + name)
	_check(picture.save_png(path) == OK, "Saved actual Main candidate view: " + name)
	captures.append({"path": name, "mode": mode, "pose": POSES[pose], "viewport": [dimensions.x, dimensions.y],
		"sha256": FileAccess.get_sha256(path), "source_sha256": texture_hashes[pose],
		"art": backdrop.snapshot(), "geometry": _geometry(mode), "page_hidden": app._page_hidden,
		"backdrop_visible": backdrop.is_visible_in_tree(), "environment_visible": environment.is_visible_in_tree(),
		"environment_source": descriptor.path, "environment_pixels_match_source": true,
		"current_layer_alpha": backdrop._current.modulate.a, "visibility_resumes": visibility_resumes})
	return true


func _finish() -> void:
	var scope: String = ""
	if is_instance_valid(app):
		scope = str(app._round_content.get("media_scope", ""))
		app.audio.halt()
		app.queue_free()
		await _settle()
		app = null
	if not scope.is_empty():
		_check(Access.resource(Access.path(scope, texture_hashes[0])) == null, "Closing Main releases the candidate texture scope")
	textures.clear()
	_check(FileAccess.get_sha256(THEME_FILE) == production_hash, "The production theme catalog remains byte-identical")
	var report: Dictionary = {"schema": 1, "theme_id": THEME_ID, "checks": checks, "failures": failures,
		"source_directory": source_directory, "source_images": source_records, "captures": captures,
		"routing": routing,
		"foreground_lifecycle_restores": visibility_resumes,
		"production_catalog_sha256": production_hash, "renderer": RenderingServer.get_video_adapter_name(),
		"theme_ready": false, "production_modified": false, "normal_speed_motion_reviewed": false,
		"notice": "Actual current Main layout using process-only candidate scene descriptors and existing synthetic lesson/media fixtures. PNG source hashes match the native render report. Complete static poses assess crop and UI occlusion before atlas integration. The internal fixture owner/cache do not establish production media-budget, curriculum, audio, motion-playback or physical-device acceptance. All saves remain in the private review directory."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	else:
		_check(false, "Could not write the review report")
	print("Digital Studio Main review: %d checks, %d failures, %d captures" % [checks, failures.size(), captures.size()])
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	if not _arguments() or not _check(DisplayServer.get_name() != "headless", "Actual Main capture requires a rendering backend"):
		quit(1)
		return
	if not _check(DirAccess.make_dir_recursive_absolute(output) == OK, "Created a fresh review directory"):
		quit(1)
		return
	production_hash = FileAccess.get_sha256(THEME_FILE)
	if not _source_images():
		await _finish()
		return
	var profile: Dictionary = _candidate_profile()
	if profile.is_empty():
		await _finish()
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = SIZES[0]
	if not await _create_main(profile):
		await _finish()
		return
	for mode: String in ["match", "word_jelly"]:
		if not await _start(mode):
			break
		for dimensions: Vector2i in SIZES:
			root.size = dimensions
			await _settle()
			app._layout()
			app._refresh()
			await _settle()
			for pose in range(POSES.size()):
				if not await _capture_pose(mode, dimensions, pose):
					await _finish()
					return
	await _finish()

extends "res://tests/godot/professional_scene_disposal_tests.gd"
## Other Professional views must drop resources before their scene lease ends.

var fixture_mode := "memory"

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	directory = "user://professional-scene-modes-disposal-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated mode-disposal storage")
	for mode in ["memory", "phrase", "pop", "jelly", "word_jelly"]:
		fixture_mode = mode
		await _test_mode_exit(mode)
	for child in DirAccess.get_directories_at(directory):
		var path: String = directory.path_join(child)
		for file in DirAccess.get_files_at(path):
			check(DirAccess.remove_absolute(path.path_join(file)) == OK, "Remove isolated mode fixture file")
		check(DirAccess.remove_absolute(path) == OK, "Remove isolated mode fixture directory")
	check(DirAccess.remove_absolute(directory) == OK, "Remove mode-disposal storage")
	print("Professional scene modes disposal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _select(app, course: String) -> void:
	app._show_mode_menu()
	app._select_learning_context(Context.professional(course, "module03", "v1", fixture_mode))
	app.choose_mode(fixture_mode)


func _test_mode_exit(mode: String) -> void:
	var path: String = directory.path_join(mode)
	check(DirAccess.make_dir_absolute(path) == OK, mode + ": create independent fixture")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, path)
	app.medal_progress = Medal.new(path + "/medals.cfg", path + "/legacy.cfg")
	app._presentation.path = path + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.reduced_motion = false
	app._presentation.save_preferences()
	app.professional.loader.media.free()
	app.professional.loader.media = MediaFixture.FixtureMedia.new()
	app.professional.loader.media.cache = ObservedCache.new()
	app.professional.loader.catalog = ApplicationFixture.Catalog.new()
	app.professional.loader._owner.free()
	app.professional.loader._owner = HeldOwner.new(app.professional.loader.catalog)
	app.professional.loader.media.cache.values["sha256:" + MediaFixture.IMAGE_HASH] = ImageTexture.create_from_image(
		(load("res://assets/images/words/absent.png") as Texture2D).get_image())
	app.professional.loader.media.cache.values["sha256:" + MediaFixture.AUDIO_HASH] = load(
		"res://assets/audio/jelly-match/collect-do.wav").duplicate(true)
	var audit: Dictionary = {"mode": mode, "app": weakref(app), "play": weakref(app.professional),
		"store": weakref(app.professional.store), "cache": weakref(app.professional.loader.media.cache),
		"image": weakref(app.professional.loader.media.cache.values["sha256:" + MediaFixture.IMAGE_HASH]),
		"audio": weakref(app.professional.loader.media.cache.values["sha256:" + MediaFixture.AUDIO_HASH]),
		"trace": [], "publications": [], "releases": [], "teardown": false, "closed": false,
		"store_closed": false, "store_publications_after_close": 0, "late_host_reply": false,
		"host": null, "timer": null, "timer_callback": Callable(), "save_path": path + "/professional.json",
		"consumers": [], "ghosts": []}
	root.add_child(app)
	check(await _settle(app), mode + ": real scene settles")
	_select(app, "retail")
	var prepared: bool = await _wait_media(app)
	check(prepared, mode + ": initial policy reaches media")
	if not prepared:
		app.queue_free()
		await process_frame
		return
	app.professional.loader.media.finish(app.professional.loader.media.generation)
	check(await _settle(app), mode + ": initial round settles through real persistence")
	check(app.professional.can_play(app._round_id) and app._round_context.mode == mode,
		mode + ": actual view owns the frozen Professional round")
	if app.professional.active.is_empty():
		app.queue_free()
		await process_frame
		return
	audit.active_scope = app.professional.active.media_scope
	audit.active_path = app._round_content.words[0].image
	audit.active_lease = Access._scopes[audit.active_scope].lease
	app.professional.loader.media.cache.on_release = _observe_mode_release.bind(audit)
	if mode == "pop":
		# Warm the actual canvas cache while speech remains silent in this fixture.
		app._pop._cache_texture(app._round_content.words[0])
	if mode == "jelly":
		# A real drop creates landing projections that stop() frees deferred.
		check(app._jelly.game.drop_now(), "jelly: create an actual arriving batch")
		app._jelly._sync_tiles()
		check(not app._jelly._ghosts.is_empty(), "jelly: arriving batch owns landing projections")
		for ghost in app._jelly._ghosts.values():
			audit.ghosts.append(weakref(ghost))
	_select(app, "nursing")
	check(await _wait_media(app), mode + ": replacement media is held pending")
	check(app._round_context.course_id == "retail" and Access.resource(audit.active_path) != null,
		mode + ": pending replacement preserves its active resource")
	app.audio.voice.stream = Access.resource(app._round_content.words[0].audio)
	_capture_consumers(app, audit.consumers)
	var initial_refs: Array = _consumer_references(audit)
	check(mode == "phrase" or initial_refs.any(func(value: Dictionary) -> bool: return value.kind == "image"),
		mode + ": image-based views retain the unique professional picture; expression-only Phrase uses text")
	check(initial_refs.any(func(value: Dictionary) -> bool: return value.kind == "audio"),
		mode + ": actual audio player retains the unique professional stream")
	audit.before_files = _snapshot_files(audit.save_path)
	_connect_observers(app, audit)
	app.queue_free()
	for unused in range(6):
		await process_frame
	check(audit.app.get_ref() == null and audit.play.get_ref() == null and audit.store.get_ref() == null,
		mode + ": queue_free destroys the real scene and terminal owners")
	check(audit.closed and audit.store_closed, mode + ": terminal guards execute")
	check(audit.publications.is_empty(), mode + ": no Play publication escapes during scene teardown")
	check(audit.releases.size() == 1, mode + ": active lease is released exactly once")
	if audit.releases.size() == 1:
		check(audit.releases[0].play_closed, mode + ": terminal close owns the release")
		check(audit.releases[0].references.is_empty(),
			mode + ": every captured view, deferred child and audio consumer drops resources before lease release")
	check(Access.resource(audit.active_path) == null and not Access._scopes.has(audit.active_scope),
		mode + ": active scoped resource cannot resolve after disposal")
	check(audit.cache.get_ref() == null and audit.image.get_ref() == null and audit.audio.get_ref() == null,
		mode + ": cache and unique media resources have no surviving owners")
	check(audit.before_files == _snapshot_files(audit.save_path)
		and audit.get("closed_files", {}) == audit.before_files,
		mode + ": terminal disposal preserves committed progress bytes")
	print("Scene mode disposal observation: " + JSON.stringify({"mode": mode, "trace": audit.trace,
		"publications": audit.publications, "active_releases": audit.releases}))


func _capture_consumers(node: Node, consumers: Array) -> void:
	consumers.append({"node": weakref(node), "path": str(node.get_path())})
	for child in node.get_children():
		_capture_consumers(child, consumers)


func _consumer_references(audit: Dictionary) -> Array:
	var found: Array = []
	var picture: Resource = audit.image.get_ref()
	var sound: Resource = audit.audio.get_ref()
	for consumer in audit.consumers:
		var node: Node = consumer.node.get_ref()
		if node == null:
			continue
		for property in node.get_property_list():
			if int(property.type) not in [TYPE_OBJECT, TYPE_ARRAY, TYPE_DICTIONARY]:
				continue
			_find_media(node.get(property.name), str(consumer.path) + ":" + str(property.name),
				picture, sound, found, 0)
	return found


func _find_media(value: Variant, location: String, picture: Resource, sound: Resource, found: Array, depth: int) -> void:
	if depth > 6:
		return
	if value is Resource:
		if value == picture:
			found.append({"path": location, "kind": "image"})
		elif value == sound:
			found.append({"path": location, "kind": "audio"})
		elif value is AtlasTexture:
			_find_media(value.atlas, location + ".atlas", picture, sound, found, depth + 1)
	elif value is Array:
		for index in range(value.size()):
			_find_media(value[index], location + "[%d]" % index, picture, sound, found, depth + 1)
	elif value is Dictionary:
		for key in value:
			_find_media(value[key], location + "." + str(key), picture, sound, found, depth + 1)


func _observe_mode_release(lease: int, audit: Dictionary) -> void:
	if lease != audit.active_lease:
		return
	var play = audit.play.get_ref()
	var retained_ghosts := 0
	for reference in audit.ghosts:
		if reference.get_ref() != null:
			retained_ghosts += 1
	audit.releases.append({"play_closed": play != null and play._closed,
		"references": _consumer_references(audit), "live_captured_ghosts": retained_ghosts})
	audit.trace.append("active_lease_release")

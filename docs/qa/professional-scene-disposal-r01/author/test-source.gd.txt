extends SceneTree
## Synthetic curriculum exercises the real scene's terminal resource handoff.

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const ApplicationFixture = preload("res://tests/godot/professional_application_flow_tests.gd")
const MediaFixture = preload("res://tests/godot/professional_round_loader_tests.gd")
const Context = preload("res://scripts/learning_context.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const Medal = preload("res://scripts/medal_progress.gd")

class HeldOwner extends MediaFixture.FixtureOwner:
	var hold_completions := false
	func _init(catalog_source: RefCounted) -> void:
		super(catalog_source)
	func _finish_catalog(request_id: int) -> void:
		if not hold_completions:
			super._finish_catalog(request_id)
	func _exit_tree() -> void:
		# Match the production owner's terminal exit callback.
		retire()

class ObservedCache extends MediaFixture.FixtureCache:
	var on_release: Callable
	func release_round(lease: int) -> void:
		if on_release.is_valid():
			on_release.call(lease)
		super.release_round(lease)

class HeldHost extends RefCounted:
	var requests: Array = []
	func professionalProgressRequest(text: String, callback: Callable) -> void:
		requests.append({"request": JSON.parse_string(text), "callback": callback})
	func reply() -> bool:
		if requests.is_empty() or not requests[0].callback.is_valid():
			return false
		var request: Dictionary = requests[0].request
		requests[0].callback.call([JSON.stringify({"request_id": request.request_id,
			"ok": true, "registered": 1, "error": ""})])
		return true

var checks := 0
var failures := 0
var directory := ""


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	directory = "user://professional-scene-disposal-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated scene-disposal storage")
	for stage in ["owner", "media", "storage"]:
		await _test_pending_exit(stage)
	for child in DirAccess.get_directories_at(directory):
		var path: String = directory.path_join(child)
		for file in DirAccess.get_files_at(path):
			check(DirAccess.remove_absolute(path.path_join(file)) == OK, "Remove isolated scene fixture file")
		check(DirAccess.remove_absolute(path) == OK, "Remove isolated scene fixture directory")
	check(DirAccess.remove_absolute(directory) == OK, "Remove scene-disposal storage")
	print("Professional scene disposal: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _settle(app) -> bool:
	for frame in range(120):
		await process_frame
		if not is_instance_valid(app):
			return false
		if frame >= 3 and app.professional.session.snapshot().blocked:
			return false
		if frame >= 3 and not app._vocabulary_booting and app.professional.session.snapshot().pending_count == 0 \
			and app.professional.phase not in ["media", "storage", "restoring", "ready"]:
			return true
	return false


func _wait_media(app) -> bool:
	for unused in range(120):
		await process_frame
		var preparation: Dictionary = app.professional.loader._preparation
		if preparation.get("phase") == "media" \
			and preparation.get("media_generation", -1) == app.professional.loader.media.generation:
			return true
		if app.professional.phase == "failed":
			return false
	return false


func _select(app, course: String) -> void:
	app._show_mode_menu()
	app._select_learning_context(Context.professional(course, "module03", "v1", "match"))
	app.choose_mode("match")


func _snapshot_files(path: String) -> Dictionary:
	var snapshot: Dictionary = {}
	for suffix in ["", ".previous", ".pending"]:
		var name: String = path + suffix
		snapshot[suffix] = FileAccess.get_file_as_bytes(name) if FileAccess.file_exists(name) else null
	return snapshot


func _test_pending_exit(stage: String) -> void:
	var path: String = directory.path_join(stage)
	check(DirAccess.make_dir_absolute(path) == OK, stage + ": create independent fixture")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, path)
	app.medal_progress = Medal.new(path + "/medals.cfg", path + "/legacy.cfg")
	app._presentation.path = path + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.save_preferences()
	app.professional.loader.media.free()
	app.professional.loader.media = MediaFixture.FixtureMedia.new()
	app.professional.loader.media.cache = ObservedCache.new()
	app.professional.loader.catalog = ApplicationFixture.Catalog.new()
	app.professional.loader._owner.free()
	app.professional.loader._owner = HeldOwner.new(app.professional.loader.catalog)
	# Unique copies of existing sourced assets make weak references meaningful.
	# The fixture does not add replacement production artwork or curriculum.
	app.professional.loader.media.cache.values["sha256:" + MediaFixture.IMAGE_HASH] = ImageTexture.create_from_image(
		(load("res://assets/images/words/absent.png") as Texture2D).get_image())
	app.professional.loader.media.cache.values["sha256:" + MediaFixture.AUDIO_HASH] = load(
		"res://assets/audio/jelly-match/collect-do.wav").duplicate(true)
	var audit: Dictionary = {"stage": stage, "app": weakref(app), "play": weakref(app.professional),
		"store": weakref(app.professional.store), "cache": weakref(app.professional.loader.media.cache),
		"image": weakref(app.professional.loader.media.cache.values["sha256:" + MediaFixture.IMAGE_HASH]),
		"audio": weakref(app.professional.loader.media.cache.values["sha256:" + MediaFixture.AUDIO_HASH]),
		"trace": [], "publications": [], "releases": [], "teardown": false, "closed": false,
		"store_closed": false, "store_publications_after_close": 0, "late_host_reply": false,
		"host": null, "timer": null, "timer_callback": Callable(), "save_path": path + "/professional.json"}
	root.add_child(app)
	check(await _settle(app), stage + ": initial real scene settles")
	_select(app, "retail")
	var prepared: bool = await _wait_media(app)
	check(prepared, stage + ": initial synthetic policy reaches media")
	if not prepared:
		app.queue_free()
		await process_frame
		return
	app.professional.loader.media.finish(app.professional.loader.media.generation)
	check(await _settle(app), stage + ": initial round opens through real persistence")
	check(app.professional.can_play(app._round_id) and app.cards.size() == 10,
		stage + ": active professional Match owns real controls")
	if app.professional.active.is_empty():
		app.queue_free()
		await process_frame
		return
	audit.active_scope = app.professional.active.media_scope
	audit.active_path = app._round_content.words[0].image
	audit.active_lease = Access._scopes[audit.active_scope].lease
	app.professional.loader.media.cache.on_release = _observe_release.bind(audit)
	if stage == "owner":
		app.professional.loader._owner.hold_completions = true
	if stage == "storage":
		audit.host = HeldHost.new()
		check(app.professional.store.configure([app._round_content.requirements], audit.save_path, audit.host),
			"storage: real store accepts the held host transport before replacement")
	_select(app, "nursing")
	if stage == "owner":
		check(app.professional.loader._preparation.get("phase") == "policy", "owner: policy completion remains held")
	else:
		check(await _wait_media(app), stage + ": replacement media remains pending")
		if stage == "storage":
			app.professional.loader.media.finish(app.professional.loader.media.generation)
			for unused in range(120):
				await process_frame
				if not audit.host.requests.is_empty():
					break
			check(audit.host.requests.size() == 1 and app.professional.phase == "storage",
				"storage: a real replacement registration is dispatched and held")
			if not audit.host.requests.is_empty():
				var id: int = audit.host.requests[0].request.request_id
				var tracked: Dictionary = app.professional.store._timers.get(id, {})
				if not tracked.is_empty():
					audit.timer = tracked.timer
					audit.timer_callback = tracked.callback
	check(app._round_context.course_id == "retail" and Access.resource(audit.active_path) != null,
		stage + ": pending replacement preserves the claimed active resource")
	# Retain a professional stream without playback. The scene must drop this
	# AudioStreamPlayer reference along with its visible card textures on disposal.
	app.audio.voice.stream = Access.resource(app._round_content.words[0].audio)
	check(app.audio.voice.stream != null, stage + ": real audio player holds the scoped stream")
	audit.before_files = _snapshot_files(audit.save_path)
	_connect_observers(app, audit)
	app.queue_free()
	for unused in range(6):
		await process_frame
	check(audit.app.get_ref() == null and audit.play.get_ref() == null and audit.store.get_ref() == null,
		stage + ": queue_free destroys the real scene and persistence owner")
	check(audit.closed and audit.store_closed, stage + ": both terminal exit guards execute")
	check(audit.publications.is_empty(), stage + ": no UI publication occurs once scene teardown starts")
	check(audit.store_publications_after_close == 0, stage + ": closed storage emits no late result")
	check(audit.releases.size() == 1, stage + ": the claimed active lease is released exactly once")
	if audit.releases.size() == 1:
		var released: Dictionary = audit.releases[0]
		check(released.play_closed, stage + ": active lease release belongs to terminal Play close")
		check(released.card_images == 0 and released.library_images == 0 and released.audio_streams == 0,
			stage + ": views and audio drop professional resources before the active lease is released")
	check(Access.resource(audit.active_path) == null and not Access._scopes.has(audit.active_scope),
		stage + ": no scoped URL or active scope survives disposal")
	check(audit.cache.get_ref() == null and audit.image.get_ref() == null and audit.audio.get_ref() == null,
		stage + ": unique cache, picture and audio resources have no surviving owners")
	check(audit.before_files == _snapshot_files(audit.save_path)
		and audit.get("closed_files", {}) == audit.before_files,
		stage + ": terminal close and later callbacks leave committed snapshot bytes unchanged")
	if stage == "storage":
		check(audit.late_host_reply, "storage: held response is delivered after terminal close while its node still exists")
		check(audit.timer != null and not audit.timer.timeout.is_connected(audit.timer_callback),
			"storage: terminal exit disconnects the actual dispatched request timeout")
		check(not audit.host.requests.is_empty() and not audit.host.requests[0].callback.is_valid(),
			"storage: host callback cannot retain or revive the freed store")
	print("Scene disposal observation: " + JSON.stringify({"stage": stage, "trace": audit.trace,
		"publications": audit.publications, "active_releases": audit.releases}))


func _connect_observers(app, audit: Dictionary) -> void:
	app.child_exiting_tree.connect(func(child: Node) -> void:
		audit.teardown = true
		audit.trace.append("child:" + str(child.name)))
	app.professional.changed.connect(func(state: Dictionary) -> void: _publication("changed", state, audit))
	app.professional.round_prepared.connect(func(_selection: int, _content: Dictionary, _source: String) -> void:
		_publication("round_prepared", {}, audit))
	app.professional.event_completed.connect(func(_id: String, _source: String, _result: Dictionary) -> void:
		_publication("event_completed", {}, audit))
	app.professional.store.completed.connect(func(_id: int, _result: Dictionary) -> void:
		if audit.store_closed:
			audit.store_publications_after_close += 1)
	app.professional.store.tree_exiting.connect(_store_exiting.bind(audit))
	app.professional.tree_exiting.connect(_play_exiting.bind(audit))
	app.audio.tree_exiting.connect(func() -> void: audit.trace.append("audio"))
	app._professional_library.tree_exiting.connect(func() -> void: audit.trace.append("library"))
	app.tree_exiting.connect(_app_exiting.bind(audit))


func _publication(kind: String, state: Dictionary, audit: Dictionary) -> void:
	if audit.teardown:
		audit.publications.append({"kind": kind, "phase": state.get("phase", ""), "play_closed": audit.closed})


func _store_exiting(audit: Dictionary) -> void:
	var store = audit.store.get_ref()
	audit.store_closed = store != null and store.is_closed()
	audit.closed_files = _snapshot_files(audit.save_path)
	audit.trace.append("store")


func _play_exiting(audit: Dictionary) -> void:
	var play = audit.play.get_ref()
	audit.closed = play != null and play._closed
	audit.trace.append("play")


func _app_exiting(audit: Dictionary) -> void:
	audit.trace.append("app")
	if audit.host != null:
		audit.late_host_reply = audit.host.reply()
		if audit.timer != null:
			audit.timer.timeout.emit()


func _observe_release(lease: int, audit: Dictionary) -> void:
	if lease != audit.active_lease:
		return
	var app = audit.app.get_ref()
	var card_images := 0
	for card in app.cards.values():
		if is_instance_valid(card) and card.picture.texture != null \
			and card.picture.texture.has_meta("professional_media"):
			card_images += 1
	var audio_streams: int = int(app.audio.voice.stream != null and app.audio.voice.stream.has_meta("professional_media"))
	var library_images: int = int(app._professional_library.snapshot().image_count)
	audit.releases.append({"play_closed": app.professional._closed, "card_images": card_images,
		"library_images": library_images, "audio_streams": audio_streams,
		"audio_inside_tree": app.audio.is_inside_tree(), "view_inside_tree": app.grid.is_inside_tree()})
	audit.trace.append("active_lease_release")

extends SceneTree

const RoundLoader = preload("res://scripts/professional_round_loader.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const Context = preload("res://scripts/learning_context.gd")
const WordArt = preload("res://scripts/word_art.gd")
const Audio = preload("res://scripts/game_audio.gd")
const IMAGE_HASH = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const AUDIO_HASH = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

class FixtureCache extends RefCounted:
	var leases: Dictionary = {}
	var sequence: int = 0
	var values: Dictionary = {}
	func pin_round(ids: Array) -> Dictionary:
		sequence += 1
		leases[sequence] = ids.duplicate()
		return {"ok": true, "lease": sequence}
	func get_resource(id: String, lease: int = 0) -> Resource:
		return values.get(id) if leases.get(lease, []).has(id) else null
	func release_round(lease: int) -> void:
		leases.erase(lease)
	func deactivate() -> void:
		pass
	func trim_inactive() -> void:
		# FixtureMedia retains source resources to simulate subsequent downloads.
		pass

class FixtureMedia extends Node:
	signal completed(generation: int, result: Dictionary)
	var cache = FixtureCache.new()
	var generation: int = 0
	func configure(_root: String = "", _host: Object = null) -> void:
		pass
	func cancel() -> void:
		generation += 1
	func request_module(_manifest: Dictionary, _expected: Dictionary, _required: Array) -> int:
		generation += 1
		return generation
	func finish(id: int) -> void:
		completed.emit(id, {"ok": true, "resource_ids": cache.values.keys()})

class FixtureCatalog extends RefCounted:
	func load_index() -> bool:
		return true
	func resolve(context: Dictionary, _seed: int = -1) -> Dictionary:
		return {"ok": true, "context": context.duplicate(), "theme_profile": {"id": context.course_id,
			"preview": {"path": "res://assets/images/professional-previews/retail.png"},
			"art": {"environment": {"sha256": IMAGE_HASH}}},
			"media_manifest": {}, "required_resource_ids": ["sha256:" + IMAGE_HASH, "sha256:" + AUDIO_HASH],
			"words": [{"id": "fixture", "image": "", "audio": "", "media": {
				"image": {"sha256": IMAGE_HASH}, "audio": {"sha256": AUDIO_HASH}}}],
			"module_words": [{"id": "library-only", "image": "", "audio": "", "media": {
				"image": {"sha256": IMAGE_HASH}, "audio": {"sha256": AUDIO_HASH}}}],
			"expressions": [{"id": "fixture.expression", "media": {"audio": {"sha256": AUDIO_HASH}}}]}

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var loader := RoundLoader.new()
	loader.media.free()
	loader.catalog = FixtureCatalog.new()
	loader.media = FixtureMedia.new()
	loader.media.cache.values["sha256:" + IMAGE_HASH] = load("res://assets/images/words/absent.png")
	loader.media.cache.values["sha256:" + AUDIO_HASH] = load("res://assets/audio/jelly-match/collect-do.wav")
	root.add_child(loader)
	check(loader.configure(), "Round loader configures its selected catalog and media source")
	var prepared: Array = []
	loader.prepared.connect(func(selection: int, content: Dictionary) -> void: prepared.append([selection, content]))
	var first: int = loader.request(Context.professional("nursing", "module03", "v1", "match"))
	var first_generation: int = loader.media.generation
	var second: int = loader.request(Context.professional("retail", "module03", "v1", "match"))
	loader.media.finish(first_generation)
	check(prepared.is_empty() and loader.media.cache.leases.is_empty(), "Late media from an old selection cannot apply assets or retain a lease")
	loader.media.finish(loader.media.generation)
	check(prepared.size() == 1 and prepared[0][0] == second, "Only the most recent course prepares a round")
	check(not loader.claim(first).ok, "Stale selection cannot claim the latest media")
	var content: Dictionary = loader.claim(second)
	check(content.ok and content.context.course_id == "retail", "Claim freezes content and transfers media ownership to the round")
	check(not loader.claim(second).ok, "One selection transfers its lease exactly once")
	var texture: Texture2D = WordArt.texture(content.words[0].image)
	check(texture != null and WordArt.texture("res://" + content.words[0].image) == texture, "WordArt supports scoped URLs through existing res-prefixed callers")
	check(WordArt.texture(content.module_words[0].image) == texture and Access.is_professional(content.module_words[0].audio),
		"Library-only terms use the frozen round's scoped media")
	check(WordArt.texture(content.theme_profile.art.environment.path) == texture \
		and content.theme_profile.preview.path == "res://assets/images/professional-previews/retail.png",
		"Workplace environments use the active scope while Home previews remain lightweight local resources")
	var audio := Audio.new()
	var stream: AudioStream = await audio._stream("res://" + content.words[0].audio)
	check(stream != null and audio.cache.is_empty(), "Professional audio bypasses the permanent Growth cache")
	check(Access.resource("professional://unknown/" + IMAGE_HASH) == null, "An unknown scope cannot access another round's media")
	var motion_content: Dictionary = content.duplicate(true)
	motion_content.theme_profile.ambient_motion = {"status": "ready", "review": {"status": "reviewed"}, "clips": [{
		"id": "fixture", "image": {"path": "res://fixture.png", "sha256": IMAGE_HASH, "status": "integrated",
			"review": {"status": "reviewed"}, "source": "fixture", "creator": "fixture", "license": "fixture"},
		"columns": 2, "rows": 1, "frame_count": 2, "rest_frame": 0, "frames_per_second": 2, "rect": [0, 0, 1, 1]}]}
	var bound: Dictionary = Access.bind_content(motion_content, content.media_scope)
	check(bound.ok and Access.is_professional(bound.theme_profile.ambient_motion.clips[0].image.path),
		"Ambient sheets use the same bounded round lease as the environment")
	motion_content.theme_profile.ambient_motion.clips[0].image.sha256 = "c".repeat(64)
	check(not Access.bind_content(motion_content, content.media_scope).ok, "A missing animation dependency rejects activation")
	check(Access.resource(Access.path(content.media_scope, "c".repeat(64))) == null, "A round cannot read media outside its pinned dependency inventory")
	loader.request(Context.professional("software_data", "module03", "v1", "pop"))
	loader.media.finish(loader.media.generation)
	check(loader.media.cache.leases.size() == 2, "The old round remains protected while a replacement loads")
	loader.cancel()
	check(loader.media.cache.leases.size() == 1 and Access.resource(content.words[0].image) == texture, "Cancelling an unclaimed replacement cannot release the active round")
	texture = null
	stream = null
	Access.release(content.media_scope)
	check(loader.media.cache.leases.is_empty() and Access.resource(content.words[0].audio) == null, "Closing a round invalidates its scope and releases the lease")
	check(Access.resource(content.module_words[0].image) == null and Access.resource(content.theme_profile.art.environment.path) == null,
		"Closing a round invalidates library and workplace references together")
	audio.free()
	loader.free()
	await process_frame
	print("Professional round loading: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

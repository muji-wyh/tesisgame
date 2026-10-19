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
	var released: Array = []
	var after_pin: Callable
	var before_resource: Callable
	func pin_round(ids: Array) -> Dictionary:
		sequence += 1
		var lease: int = sequence
		leases[lease] = ids.duplicate()
		if after_pin.is_valid():
			var callback: Callable = after_pin
			after_pin = Callable()
			callback.call()
		return {"ok": true, "lease": lease}
	func get_resource(id: String, lease: int = 0) -> Resource:
		if before_resource.is_valid():
			var callback: Callable = before_resource
			before_resource = Callable()
			callback.call()
		return values.get(id) if leases.get(lease, []).has(id) else null
	func release_round(lease: int) -> void:
		released.append(lease)
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
	var configure_count: int = 0
	var request_count: int = 0
	var contexts: Array = []
	var complete_inline: bool = false
	func configure(_root: String = "", _host: Object = null) -> void:
		configure_count += 1
	func cancel() -> void:
		generation += 1
	func request_module(_manifest: Dictionary, expected: Dictionary, _required: Array) -> int:
		generation += 1
		var requested: int = generation
		request_count += 1
		contexts.append(expected.duplicate(true))
		if complete_inline:
			finish(requested)
		return requested
	func finish(id: int, result: Dictionary = {}) -> void:
		completed.emit(id, {"ok": true, "resource_ids": cache.values.keys()} if result.is_empty() else result)

class FixtureCatalog extends RefCounted:
	var loads: int = 0
	var resolves: int = 0
	var load_ok: bool = true
	func load_index() -> bool:
		loads += 1
		return load_ok
	func resolve(_context: Dictionary, _seed: int = -1) -> Dictionary:
		resolves += 1
		return {"ok": false, "error": "The ordinary catalog cannot authorize a fixture round."}

# An internal replacement exercises the owner protocol only. No production
# configure/request parameter accepts a test pin, policy, content or owner.
class FixtureOwner extends Node:
	signal completed(request_id: int, result: Dictionary)
	signal retired
	var configured: bool = false
	var closed: bool = false
	var configure_ok: bool = true
	var configure_count: int = 0
	var request_count: int = 0
	var resolve_count: int = 0
	var current: int = 0
	var requests: Dictionary = {}
	var tokens: Dictionary = {}
	var complete_inline: bool = false
	var inline_error: String = ""
	var wrong_context: bool = false
	var _catalog: RefCounted
	func _init(catalog_source: RefCounted = null) -> void:
		# Application-flow fixtures may supply their existing synthetic catalog.
		# This constructor belongs to the test double, never the production owner.
		_catalog = catalog_source
	func configure() -> Dictionary:
		configure_count += 1
		configured = configure_ok and not closed
		return {"ok": configured}
	func request(context: Dictionary, seed_value: int = -1) -> int:
		cancel()
		var request_id: int = current
		request_count += 1
		requests[request_id] = {"context": context.duplicate(true), "seed": seed_value}
		if _catalog != null:
			_finish_catalog.call_deferred(request_id)
		elif complete_inline:
			if inline_error.is_empty():
				finish(request_id)
			else:
				fail(request_id, inline_error)
		return request_id
	func _finish_catalog(request_id: int) -> void:
		if not configured or closed or request_id != current:
			return
		var content: Dictionary = _catalog.resolve(requests[request_id].context, requests[request_id].seed)
		if not configured or closed or request_id != current:
			return
		if not content.get("ok", false):
			completed.emit(request_id, content)
			return
		var token := RefCounted.new()
		tokens[token] = {"request": request_id, "content": content.duplicate(true)}
		completed.emit(request_id, {"ok": true, "token": token})
	func finish(request_id: int) -> RefCounted:
		var token := RefCounted.new()
		var content: Dictionary = _content(requests[request_id].context)
		if wrong_context:
			content.context = Context.professional("nursing", "module03", "v1", "match")
		tokens[token] = {"request": request_id, "content": content}
		completed.emit(request_id, {"ok": true, "token": token})
		return token
	func fail(request_id: int, code: String = "content_pending") -> void:
		completed.emit(request_id, {"ok": false, "error": "This fixture lesson is unavailable.", "code": code})
	func is_current(token: Variant) -> bool:
		return configured and not closed and tokens.has(token) and tokens[token].request == current
	func resolve(token: Variant) -> Dictionary:
		resolve_count += 1
		return tokens[token].content.duplicate(true) if is_current(token) else {"ok": false, "code": "stale_policy"}
	func cancel() -> void:
		current += 1
		tokens.clear()
	func retire() -> void:
		if closed:
			return
		cancel()
		closed = true
		configured = false
		retired.emit()
	func _content(context: Dictionary) -> Dictionary:
		return {"ok": true, "context": context.duplicate(true), "theme_profile": {"id": context.course_id,
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


func _new_loader(configure_now: bool = true):
	var loader := RoundLoader.new()
	loader.media.free()
	loader._owner.free()
	loader.catalog = FixtureCatalog.new()
	loader.media = FixtureMedia.new()
	loader._owner = FixtureOwner.new()
	loader.media.cache.values["sha256:" + IMAGE_HASH] = load("res://assets/images/words/absent.png")
	loader.media.cache.values["sha256:" + AUDIO_HASH] = load("res://assets/audio/jelly-match/collect-do.wav")
	root.add_child(loader)
	if configure_now:
		check(loader.configure(), "Round loader configures its internal owner and media source")
	return loader


func _drain() -> void:
	await process_frame
	await process_frame


func _ready_selection(loader, course: String = "retail") -> int:
	var selection: int = loader.request(Context.professional(course, "module03", "v1", "match"))
	loader._owner.finish(loader._owner.current)
	await _drain()
	loader.media.finish(loader.media.generation)
	await _drain()
	return selection


func _test_configuration_and_deferral() -> void:
	var loader = _new_loader(false)
	var errors: Array = []
	var prepared: Array = []
	loader.failed.connect(func(selection: int, result: Dictionary) -> void: errors.append([selection, result]))
	loader.prepared.connect(func(selection: int, content: Dictionary) -> void: prepared.append([selection, content]))
	var unavailable: int = loader.request(Context.professional("retail", "module03", "v1", "match"))
	check(errors.is_empty() and loader._owner.request_count == 0, "An unconfigured request cannot dispatch policy or fail inline")
	await _drain()
	check(errors.size() == 1 and errors[0][0] == unavailable and errors[0][1].code == "policy_unavailable",
		"An unconfigured request fails asynchronously")
	check(loader.configure() and loader.configure(), "Repeated successful configure is idempotent")
	check(loader._owner.configure_count == 1 and loader.media.configure_count == 1 and loader.catalog.loads == 1,
		"Repeated configure neither reconnects children nor resets transport or catalog")
	errors.clear()
	loader._owner.complete_inline = true
	loader.media.complete_inline = true
	loader.theme_selected.connect(func(_selection: int, profile: Dictionary) -> void:
		profile.id = "changed_by_listener"
		profile.art.environment.sha256 = "c".repeat(64))
	var caller_context: Dictionary = Context.professional("retail", "module03", "v1", "match")
	var selected: int = loader.request(caller_context)
	caller_context.course_id = "nursing"
	check(prepared.is_empty() and loader.media.request_count == 0, "Even an inline owner cannot start media before request returns")
	await _drain()
	check(prepared.size() == 1 and prepared[0][0] == selected and loader.can_claim(selected),
		"Inline owner and media doubles still publish one deferred preparation")
	check(prepared[0][1].context.course_id == "retail" and loader.media.contexts[0].course_id == "retail",
		"Caller context mutation cannot change the frozen owner/media selection")
	check(prepared[0][1].theme_profile.id == "retail" and prepared[0][1].theme_profile.art.environment.sha256 == IMAGE_HASH,
		"Theme listeners receive a defensive copy without changing private preparation content")
	check(loader.catalog.resolves == 0 and loader._owner.resolve_count == 1, "Round authorization never falls back to the ordinary catalog")
	loader.cancel()
	loader._owner.inline_error = "content_pending"
	var pending: int = loader.request(Context.professional("retail", "module03", "v1", "match"))
	check(errors.is_empty(), "Inline owner failure cannot publish before request returns")
	await _drain()
	check(errors.size() == 1 and errors[0][0] == pending and errors[0][1].code == "content_pending",
		"Unavailable policy forwards its asynchronous result without media")
	check(loader.media.request_count == 1 and loader.media.cache.leases.is_empty(), "Policy failure creates no media request or pending lease")
	loader.free()

	var failed_loader = _new_loader(false)
	failed_loader._owner.configure_ok = false
	check(not failed_loader.configure() and not failed_loader.configure(), "An initialization failure remains safely failed on repeated configure")
	check(failed_loader._owner.configure_count == 1 and failed_loader.media.configure_count == 0,
		"Partial initialization does not reconnect or configure media on retry")
	failed_loader.free()
	await _drain()


func _test_selection_and_token_guards() -> void:
	var loader = _new_loader()
	var prepared: Array = []
	var errors: Array = []
	loader.prepared.connect(func(selection: int, content: Dictionary) -> void: prepared.append([selection, content]))
	loader.failed.connect(func(selection: int, result: Dictionary) -> void: errors.append([selection, result]))
	var first: int = loader.request(Context.professional("nursing", "module03", "v1", "match"))
	var first_policy: int = loader._owner.current
	loader.request(Context.professional("retail", "module03", "v1", "match"))
	var second_policy: int = loader._owner.current
	var third: int = loader.request(Context.professional("nursing", "module03", "v1", "match"))
	var third_policy: int = loader._owner.current
	loader._owner.finish(first_policy)
	loader._owner.fail(second_policy)
	loader._owner.finish(third_policy)
	check(loader.media.request_count == 0, "A/B/A policy completions remain deferred")
	await _drain()
	check(loader.media.request_count == 1 and loader.media.contexts[0].course_id == "nursing" and errors.is_empty(),
		"A/B/A starts media only for the latest request, even when the course repeats")
	loader._owner.finish(third_policy)
	await _drain()
	check(loader.media.request_count == 1 and loader._owner.resolve_count == 1, "Duplicate owner completion does not resolve or start media twice")
	loader.media.finish(loader.media.generation - 1)
	loader.media.finish(loader.media.generation - 1, {"ok": false, "code": "stale_media"})
	loader.media.finish(loader.media.generation)
	check(prepared.is_empty(), "Media success cannot publish synchronously")
	await _drain()
	check(prepared.size() == 1 and prepared[0][0] == third and errors.is_empty(), "Stale media success and failure cannot publish")
	loader.media.finish(loader.media.generation)
	await _drain()
	check(loader.media.cache.leases.size() == 1 and prepared.size() == 1, "Duplicate media completion cannot acquire another lease")
	check(not loader.can_claim(first) and not loader.claim(first).ok, "An earlier repeated-course selection cannot claim the current scope")
	check(loader.can_claim(third), "Claim preflight accepts the current prepared token")
	var content: Dictionary = loader.claim(third)
	check(content.ok and loader._preparation.is_empty() and not loader.can_claim(third) and not loader.claim(third).ok,
		"Claim clears private pending content/token and transfers its lease exactly once")
	loader.cancel()
	check(loader.media.cache.leases.size() == 1, "Policy cancellation cannot release a claimed scope")
	Access.release(content.media_scope)
	loader.free()

	var cancelled = _new_loader()
	var cancelled_prepared: Array = []
	cancelled.prepared.connect(func(selection: int, _content: Dictionary) -> void: cancelled_prepared.append(selection))
	cancelled.request(Context.professional("retail", "module03", "v1", "match"))
	var cancelled_policy: int = cancelled._owner.current
	cancelled.cancel()
	cancelled._owner.finish(cancelled_policy)
	await _drain()
	check(cancelled.media.request_count == 0 and cancelled_prepared.is_empty(), "Cancellation during owner work suppresses a late policy completion")
	cancelled.request(Context.professional("retail", "module03", "v1", "match"))
	cancelled._owner.finish(cancelled._owner.current)
	cancelled._owner.cancel()
	await _drain()
	check(cancelled.media.request_count == 0 and cancelled.media.cache.leases.is_empty(),
		"A completed but unobserved revoked token cannot start media")
	cancelled.free()

	var forged = _new_loader()
	var forged_errors: Array = []
	forged.failed.connect(func(_selection: int, result: Dictionary) -> void: forged_errors.append(result))
	forged.request(Context.professional("retail", "module03", "v1", "match"))
	forged._owner.completed.emit(forged._owner.current, {"ok": true, "token": RefCounted.new()})
	await _drain()
	check(forged.media.request_count == 0 and forged_errors.size() == 1 and forged_errors[0].code == "stale_policy",
		"An unregistered owner token cannot authorize media")
	forged._owner.wrong_context = true
	forged.request(Context.professional("retail", "module03", "v1", "match"))
	forged._owner.finish(forged._owner.current)
	await _drain()
	check(forged.media.request_count == 0 and forged_errors.size() == 2 and forged_errors[1].code == "invalid_policy",
		"A resolved context mismatch cannot cross the media boundary")
	forged.free()
	await _drain()


func _test_reentrancy_and_retirement() -> void:
	var loader = _new_loader()
	var replacement: Array = []
	loader.theme_selected.connect(func(_selection: int, profile: Dictionary) -> void:
		if profile.id == "nursing":
			replacement.append(loader.request(Context.professional("retail", "module03", "v1", "match"))))
	loader.request(Context.professional("nursing", "module03", "v1", "match"))
	loader._owner.finish(loader._owner.current)
	await _drain()
	check(replacement.size() == 1 and loader.media.request_count == 0, "Reentrant theme selection prevents the replaced request from starting media")
	loader._owner.finish(loader._owner.current)
	await _drain()
	check(loader.media.request_count == 1 and loader.media.contexts[0].course_id == "retail", "The replacement theme request can continue normally")
	var prepared: Array = []
	loader.prepared.connect(func(selection: int, _content: Dictionary) -> void: prepared.append(selection))
	loader.media.cache.after_pin = func() -> void: loader.cancel()
	loader.media.finish(loader.media.generation)
	await _drain()
	check(prepared.is_empty() and loader.media.cache.leases.is_empty() and loader.media.cache.released.size() == 1,
		"Reentrant cancellation inside acquisition releases its new lease exactly once and cannot prepare")
	var selected: int = await _ready_selection(loader)
	check(loader.can_claim(selected), "A later valid request succeeds after acquire-time cancellation")
	loader.media.cache.before_resource = func() -> void: loader.cancel()
	var rejected: Dictionary = loader.claim(selected)
	check(not rejected.ok and loader.media.cache.leases.is_empty() and not loader.can_claim(selected),
		"Claim rechecks authority after binding and rejects reentrant cancellation without leaking its scope")
	loader.free()

	var retired_loader = _new_loader()
	var invalidations: Array = []
	var retired_prepared: Array = []
	var retired_errors: Array = []
	retired_loader.invalidated.connect(func(selection: int, result: Dictionary) -> void: invalidations.append([selection, result]))
	retired_loader.prepared.connect(func(selection: int, _content: Dictionary) -> void: retired_prepared.append(selection))
	retired_loader.failed.connect(func(selection: int, result: Dictionary) -> void: retired_errors.append([selection, result]))
	var retired_selection: int = retired_loader.request(Context.professional("retail", "module03", "v1", "match"))
	retired_loader._owner.finish(retired_loader._owner.current)
	await _drain()
	var retired_generation: int = retired_loader.media.generation
	retired_loader._owner.retire()
	check(invalidations.size() == 1 and invalidations[0][0] == retired_selection
		and invalidations[0][1].code == "policy_unavailable" and not retired_loader.can_claim(retired_selection),
		"Terminal owner retirement synchronously invalidates the exact selection before storage can continue")
	retired_loader.media.finish(retired_generation)
	await _drain()
	check(retired_prepared.is_empty() and retired_loader.media.cache.leases.is_empty(), "Media completion after retirement cannot acquire or prepare")
	retired_loader.close()
	retired_loader._owner.retire()
	check(invalidations.size() == 1 and not retired_loader.configure(), "Retirement is terminal and emits exactly one invalidation")
	var closed_selection: int = retired_loader.request(Context.professional("retail", "module03", "v1", "match"))
	check(retired_errors.is_empty(), "A request on a closed loader still fails asynchronously")
	await _drain()
	check(retired_errors.size() == 1 and retired_errors[0][0] == closed_selection and retired_errors[0][1].code == "policy_unavailable",
		"A closed loader cannot restart its owner")
	retired_loader.free()

	var claimed_loader = _new_loader()
	var claimed_selection: int = await _ready_selection(claimed_loader)
	var claimed: Dictionary = claimed_loader.claim(claimed_selection)
	claimed_loader._owner.retire()
	check(claimed.ok and claimed_loader.media.cache.leases.size() == 1 and Access.resource(claimed.words[0].image) != null,
		"Terminal retirement preserves an already claimed round's lease")
	Access.release(claimed.media_scope)
	claimed_loader.free()
	await _drain()


func _test_scoped_media() -> void:
	var loader = _new_loader()
	var prepared: Array = []
	loader.prepared.connect(func(selection: int, content: Dictionary) -> void: prepared.append([selection, content]))
	var first: int = loader.request(Context.professional("nursing", "module03", "v1", "match"))
	loader._owner.finish(loader._owner.current)
	await _drain()
	var first_generation: int = loader.media.generation
	var second: int = loader.request(Context.professional("retail", "module03", "v1", "match"))
	loader._owner.finish(loader._owner.current)
	await _drain()
	loader.media.finish(first_generation)
	await _drain()
	check(prepared.is_empty() and loader.media.cache.leases.is_empty(), "Late media from an old selection cannot apply assets or retain a lease")
	loader.media.finish(loader.media.generation)
	await _drain()
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
	loader._owner.finish(loader._owner.current)
	await _drain()
	loader.media.finish(loader.media.generation)
	await _drain()
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
	await _drain()


func _run() -> void:
	await _test_configuration_and_deferral()
	await _test_selection_and_token_guards()
	await _test_reentrancy_and_retirement()
	await _test_scoped_media()
	print("Professional round loading: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

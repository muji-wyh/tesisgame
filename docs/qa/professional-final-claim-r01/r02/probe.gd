extends SceneTree
## Native-only witness: real UI, Play, loader, session, and durable store.
## Curriculum authorization and media transport are the established doubles.

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const ApplicationFixture = preload("res://tests/godot/professional_application_flow_tests.gd")
const MediaFixture = preload("res://tests/godot/professional_round_loader_tests.gd")
const Context = preload("res://scripts/learning_context.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const Medal = preload("res://scripts/medal_progress.gd")
const Progress = preload("res://scripts/professional_progress.gd")
const PROBE_ROOT := "res://build/professional-english/final-claim-after-preflight-r02"
const EXPECTED_ERROR := "This course selection has changed."
const WALLET_RECEIPT := "final-claim-existing-wallet"

class RetiringOwner extends MediaFixture.FixtureOwner:
	var ui_ref: WeakRef
	var armed := false
	var injection_count := 0
	var on_final_gate: Callable
	func _init(catalog_source: RefCounted) -> void:
		super(catalog_source)
	func is_current(token: Variant) -> bool:
		var valid: bool = super.is_current(token)
		var view = ui_ref.get_ref() if ui_ref != null else null
		if armed and valid and view != null and view._rebuilding:
			armed = false
			injection_count += 1
			if on_final_gate.is_valid():
				on_final_gate.call(valid)
			# Use the real retirement signal and loader cancellation protocol.
			retire()
			return false
		return valid

class ObservedCache extends MediaFixture.FixtureCache:
	var on_release: Callable
	func release_round(lease: int) -> void:
		if on_release.is_valid():
			on_release.call(lease)
		super.release_round(lease)

var checks := 0
var failures := 0
var assertions: Array = []
var observations: Dictionary = {"preflights": [], "round_returns": [], "releases": [], "store_commits": []}
var app
var cache: ObservedCache
var owner: RetiringOwner
var attempt_directory := ""
var directory := ""
var baseline: Dictionary = {}
var preflight_files: Dictionary = {}
var replacement_preflight: Dictionary = {}
var final_gate: Dictionary = {}
var rejected_return: Dictionary = {}
var accepted_event := ""
var active_lease := 0
var pending_lease := 0
var pending_scope := ""
var cleanup_started := false


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	assertions.append({"ok": value, "message": message})
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var expected: String = ProjectSettings.globalize_path(PROBE_ROOT + "/attempt-001").simplify_path()
	if arguments.size() != 1 or arguments[0].replace("\\", "/").simplify_path().to_lower() != expected.to_lower():
		printerr("Supply the runner-created attempt-001 absolute directory as the only user argument.")
		quit(2)
		return
	attempt_directory = expected
	directory = attempt_directory.path_join("progress")
	if not DirAccess.dir_exists_absolute(attempt_directory) or DirAccess.dir_exists_absolute(directory) \
		or FileAccess.file_exists(attempt_directory.path_join("result.json")):
		printerr("A fresh runner-created attempt-001 is required; existing evidence is never reused.")
		quit(2)
		return
	check(not OS.has_feature("web"), "The proposal executes only the native persistence path")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated retained progress directory")
	if failures:
		_finish()
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	app = load(PROBE_ROOT + "/probe_ui.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = Medal.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.save_preferences()
	app.professional.loader.media.free()
	app.professional.loader.media = MediaFixture.FixtureMedia.new()
	cache = ObservedCache.new()
	app.professional.loader.media.cache = cache
	app.professional.loader.catalog = ApplicationFixture.Catalog.new()
	app.professional.loader._owner.free()
	owner = RetiringOwner.new(app.professional.loader.catalog)
	owner.ui_ref = weakref(app)
	owner.on_final_gate = _observe_final_gate
	app.professional.loader._owner = owner
	cache.values["sha256:" + MediaFixture.IMAGE_HASH] = load("res://assets/images/words/absent.png")
	cache.values["sha256:" + MediaFixture.AUDIO_HASH] = load("res://assets/audio/jelly-match/collect-do.wav")
	check(cache.values["sha256:" + MediaFixture.IMAGE_HASH] is Texture2D, "Existing sourced fixture picture loads")
	check(cache.values["sha256:" + MediaFixture.AUDIO_HASH] is AudioStream, "Existing sourced fixture audio loads")
	cache.on_release = _observe_release
	app.preflight_observer = _observe_preflight
	app.round_return_observer = _observe_round_return
	root.add_child(app)
	await _settle("initial real application startup")
	if failures:
		await _dispose()
		_finish()
		return
	await _start_course("retail")
	check(app._round_context == Context.professional("retail", "module03", "v1", "match"), "Home establishes the Retail Match round")
	check(app.professional.can_play(app._round_id), "The original round is genuinely playable")
	check(app.cards.size() == 10 and app.model.cards.size() == 10, "The original real Match board owns ten card controls")
	check(observations.preflights.size() == 1 and observations.preflights[0].problem.is_empty(), "The first real model preflight succeeded")
	check(observations.round_returns.size() == 1 and observations.round_returns[0].result, "The first real claim installed the original round")
	check(not app.model.chest_earned and app.model.phase != "won" and app._pair_words.is_empty(), "The unfinished board has no pending pair reward settlement")
	if failures:
		await _dispose()
		_finish()
		return
	var sense: String = app.model.lesson_words[0].id
	accepted_event = app._round_id + ":retained-before-claim:" + sense
	app._record_growth("retained-before-claim", [sense], true)
	await _settle("accepted original-round evidence")
	var saved: Dictionary = _saved_state()
	var progress: Dictionary = app.professional.session.snapshot().progress
	check(int(progress.get("sequence", 0)) == 1 and progress.get("skills", {}).get(sense, {}).get("recognition", {}).get("streak", -1) == 1,
		"A real accepted recognition event creates nonempty prior progress")
	check(saved.get("events", {}).has(accepted_event), "The accepted event is durable before replacement")
	check(saved.get("outbox", {}).is_empty(), "The baseline has no unresolved wallet outbox")
	var credited: Dictionary = app.coin_wallet.credit(WALLET_RECEIPT, 1)
	check(credited.get("ok", false) and app.coin_wallet.balance == 50 and app.coin_wallet._receipts.has(WALLET_RECEIPT),
		"The real wallet has a durable nonempty balance and receipt before replacement")
	baseline = _capture_round()
	baseline["session_progress"] = progress.duplicate(true)
	baseline["session_progress_types"] = _progress_type_profile(progress)
	baseline["saved_state"] = _saved_state()
	baseline["files"] = _file_bytes()
	active_lease = _lease_for_scope(str(baseline.scope))
	check(active_lease > 0 and cache.leases.size() == 1, "The original round owns exactly one claimed media lease")
	check(_all_cards_have_textures(baseline.controls), "All ten existing Match controls hold live textures")
	observations["baseline"] = baseline.duplicate(true)
	app.professional.store.before_commit = _observe_commit
	if failures:
		await _dispose()
		_finish()
		return
	owner.armed = true
	await _start_course("nursing")
	check(not replacement_preflight.is_empty(), "The replacement reached and passed actual preflight before injection")
	check(owner.injection_count == 1 and not final_gate.is_empty(), "Exactly one injected retirement occurred at the real final claim gate")
	check(not rejected_return.is_empty() and not rejected_return.get("result", true), "The real prepared new_round synchronously rejected the final claim")
	check(app.professional.can_play(str(baseline.source)), "Real restoration makes the original source playable again")
	check(app.professional.pending.is_empty() and app.professional.session.snapshot().pending_count == 0,
		"Restoration leaves no pending replacement or storage work")
	check(app.professional.session.snapshot().saved_context == baseline.context,
		"Restoration durably returns the saved context to Retail")
	var restored_progress: Dictionary = app.professional.session.snapshot().progress
	var baseline_canonical: String = Progress.canonical(baseline.session_progress)
	var restored_canonical: String = Progress.canonical(restored_progress)
	observations["progress_comparison"] = {
		"raw_dictionary_equal": restored_progress == baseline.session_progress,
		"canonical_equal": restored_canonical == baseline_canonical,
		"baseline_canonical": baseline_canonical, "restored_canonical": restored_canonical,
		"baseline_canonical_sha256": baseline_canonical.sha256_text(),
		"restored_canonical_sha256": restored_canonical.sha256_text(),
		"baseline_types": baseline.session_progress_types.duplicate(true),
		"restored_types": _progress_type_profile(restored_progress)}
	check(restored_canonical == baseline_canonical, "Restoration retains the exact accepted progress under persistence canonicalization")
	_assert_old_round("after real restoration")
	var restored: Dictionary = _saved_state()
	for key in ["progress", "events", "outbox"]:
		check(restored.get(key) == baseline.saved_state.get(key), "Restoration preserves native " + key)
	check(restored.get("context") == baseline.context, "Native storage restores only the old learning context")
	check(_non_professional_files(_file_bytes()) == _non_professional_files(baseline.files),
		"Replacement and restoration leave Growth, wallet, medal, reward, and presentation bytes unchanged")
	check(observations.store_commits.size() >= 2, "Observe both replacement and restoration context writes")
	for operation in observations.store_commits:
		check(operation == "context", "No answer record, reward acknowledgement, or settlement commit occurs during replacement")
	check(cache.released.count(active_lease) == 0 and cache.released.count(pending_lease) == 1,
		"Only the rejected pending lease is released before final cleanup")
	observations["restored"] = {"round": _capture_round(), "session": app.professional.session.snapshot(),
		"saved_state": restored, "files": _file_bytes(), "leases": cache.leases.duplicate(true)}
	await _dispose()
	check(cache.released.count(active_lease) == 1, "The active lease is released exactly once during final scene cleanup")
	check(cache.leases.is_empty(), "Final scene cleanup leaves no fixture media leases")
	_finish()


func _start_course(course: String) -> void:
	app._show_mode_menu()
	app._select_learning_context(Context.professional(course, "module03", "v1", "match"))
	app.choose_mode("match")
	var selection: int = app.professional.pending.get("selection", -1)
	var media_started := false
	for unused in range(180):
		await process_frame
		var preparation: Dictionary = app.professional.loader._preparation
		if preparation.get("selection") == selection and preparation.get("phase") == "media" \
			and preparation.get("media_generation", -1) == app.professional.loader.media.generation:
			media_started = true
			break
		if app.professional.phase == "failed":
			break
	check(media_started, "Reach the exact asynchronous media generation for " + course)
	if media_started:
		app.professional.loader.media.finish(app.professional.loader.media.generation)
	await _settle(course + " preparation or restoration")


func _settle(label: String) -> void:
	for frame in range(180):
		await process_frame
		if not is_instance_valid(app):
			return
		var state: Dictionary = app.professional.session.snapshot()
		if frame >= 3 and state.blocked:
			check(false, "Storage remains unblocked during " + label)
			return
		if frame >= 3 and not app._vocabulary_booting and state.pending_count == 0 \
			and app.professional.phase not in ["media", "storage", "restoring", "ready"]:
			return
	check(false, "Bounded completion for " + label)


func _observe_preflight(record: Dictionary) -> void:
	observations.preflights.append(record.duplicate(true))
	if record.context.get("course_id") != "nursing":
		return
	replacement_preflight = record.duplicate(true)
	check(record.problem.is_empty(), "The unchanged production model preflight returns success")
	check(record.phase == "ready" and not record.rebuilding, "Successful preflight occurs before the final rebuilding gate")
	check(record.session.ready and not record.session.blocked and record.session.source_id == record.source,
		"Real replacement storage is ready for the exact preflight source")
	check(owner.injection_count == 0 and owner.armed, "No owner failure has occurred during earlier claim or model preflight checks")
	pending_scope = str(app.professional.loader._preparation.get("pending_scope", ""))
	pending_lease = _lease_for_scope(pending_scope)
	check(pending_lease > 0 and pending_lease != active_lease and pending_scope != baseline.scope and cache.leases.size() == 2,
		"Successful preflight retains separate active and pending scopes and leases")
	_assert_old_round("at successful preflight")
	preflight_files = _file_bytes()
	observations["preflight_files"] = preflight_files.duplicate(true)


func _observe_final_gate(owner_was_current: bool) -> void:
	final_gate = {"owner_was_current": owner_was_current, "rebuilding": app._rebuilding,
		"selection": app.professional.pending.get("selection", -1),
		"source": app.professional.pending.get("source", ""), "phase": app.professional.phase,
		"pending_scope": app.professional.loader._preparation.get("pending_scope", ""),
		"active_scope": app.professional.active.get("media_scope", ""), "leases": cache.leases.duplicate(true)}
	observations["final_gate"] = final_gate.duplicate(true)
	check(owner_was_current and final_gate.rebuilding and final_gate.phase == "ready", "Retirement is injected only at the genuine final claim gate")
	check(not replacement_preflight.is_empty() and replacement_preflight.problem.is_empty()
		and replacement_preflight.source == final_gate.source and replacement_preflight.selection == final_gate.selection,
		"The final gate belongs to the exact source and selection whose actual preflight succeeded")
	check(final_gate.active_scope == baseline.scope and final_gate.pending_scope == pending_scope,
		"Both exact media scopes still exist immediately before injected retirement")
	check(_file_bytes() == preflight_files, "Settlement guards perform no writes between successful preflight and final claim")
	_assert_old_round("immediately before final claim failure")


func _observe_round_return(record: Dictionary) -> void:
	observations.round_returns.append(record.duplicate(true))
	if record.context.get("course_id") != "nursing":
		return
	rejected_return = record.duplicate(true)
	check(not record.result and not record.rebuilding and owner.injection_count == 1,
		"The production final claim returns false and clears rebuilding after the injected retirement")
	check(record.source == replacement_preflight.get("source", ""), "The rejected return is the successfully preflighted source")
	check(record.message == EXPECTED_ERROR and record.message_visible and not record.grid_visible,
		"The production error overlay may hide the retained board after final claim failure")
	_assert_old_round("at synchronous rejection")
	check(_file_bytes() == preflight_files, "All progress-directory bytes remain identical during synchronous final claim failure")
	check(cache.released.count(active_lease) == 0 and cache.released.count(pending_lease) == 1,
		"Failure releases the pending lease once without prematurely releasing the active lease")
	check(not Access._scopes.has(pending_scope) and Access._scopes.has(str(baseline.scope)),
		"Only the rejected pending media scope is revoked")
	observations["synchronous_rejection"] = {"return": record.duplicate(true), "round": _capture_round(),
		"files": _file_bytes(), "leases": cache.leases.duplicate(true)}


func _observe_release(lease: int) -> void:
	observations.releases.append({"lease": lease, "cleanup_started": cleanup_started,
		"source": app._round_id if is_instance_valid(app) else "",
		"controls": _controls() if is_instance_valid(app) else {}})
	if lease == active_lease and active_lease != 0:
		check(cleanup_started, "The active scope cannot release before explicitly marked final cleanup")


func _observe_commit(operation: String) -> bool:
	observations.store_commits.append(operation)
	return true


func _assert_old_round(stage: String) -> void:
	var current: Dictionary = _capture_round()
	for key in ["source", "context", "content", "active", "scope", "image_instance", "audio_instance", "controls", "model", "growth", "wallet"]:
		check(current.get(key) == baseline.get(key), "Preserve original " + key + " " + stage)
	check(Access.resource(str(baseline.image)) is Texture2D and Access.resource(str(baseline.audio)) is AudioStream,
		"The old scoped image and audio still resolve " + stage)
	check(cache.leases.has(active_lease) and cache.released.count(active_lease) == 0,
		"The original claimed lease remains pinned " + stage)


func _capture_round() -> Dictionary:
	var model_state: Dictionary = {}
	for key in ["cards", "lesson_words", "matched_ids", "feedback_ids", "hint_ids", "hints_used", "selected_id",
		"mistakes", "phase", "theme_id", "adventure_id", "adventure_name", "age_band_id", "chest_state",
		"chest_earned", "chest_reward_pair", "reward_theme", "reward_id", "error", "last_correct", "_attempt_sequence", "learning_context"]:
		var value: Variant = app.model.get(key)
		model_state[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	var image_resource: Resource = Access.resource(str(app._round_content.words[0].image))
	var audio_resource: Resource = Access.resource(str(app._round_content.words[0].audio))
	return {"source": app._round_id, "context": app._round_context.duplicate(true), "content": app._round_content.duplicate(true),
		"active": app.professional.active.duplicate(true), "scope": app._round_content.get("media_scope", ""),
		"image": app._round_content.words[0].image, "audio": app._round_content.words[0].audio,
		"image_instance": image_resource.get_instance_id() if image_resource != null else 0,
		"audio_instance": audio_resource.get_instance_id() if audio_resource != null else 0,
		"controls": _controls(), "model": model_state, "growth": app.growth.snapshot(),
		"wallet": {"balance": app.coin_wallet.balance, "receipts": app.coin_wallet._receipts.duplicate(true)}}


func _controls() -> Dictionary:
	var result: Dictionary = {}
	for id in app.cards:
		var card = app.cards[id]
		if not is_instance_valid(card):
			result[id] = {"valid": false}
			continue
		result[id] = {"valid": true, "instance": card.get_instance_id(), "data": card.card_data.duplicate(true),
			"parent": card.get_parent().get_instance_id() if card.get_parent() != null else 0,
			"in_grid": card.get_parent() == app.grid,
			"texture": card.picture.texture.get_instance_id() if card.picture.texture != null else 0}
	return result


func _all_cards_have_textures(controls: Dictionary) -> bool:
	if controls.size() != 10:
		return false
	for control in controls.values():
		if not control.get("valid", false) or not control.get("in_grid", false) or int(control.get("texture", 0)) == 0:
			return false
	return true


func _lease_for_scope(scope: String) -> int:
	return int(Access._scopes.get(scope, {}).get("lease", 0))


func _progress_type_profile(value: Variant, value_path: String = "$") -> Array:
	# Capture types before JSON output erases StringName/String and int/float distinctions.
	var rows: Array = []
	var type_id: int = typeof(value)
	if value is Dictionary:
		rows.append({"path": value_path, "role": "container", "type_id": type_id,
			"type_name": type_string(type_id), "size": value.size()})
		for key in value:
			var child_path: String = value_path + "[" + JSON.stringify(str(key)) + "]"
			rows.append({"path": child_path, "role": "dictionary_key", "key": str(key),
				"type_id": typeof(key), "type_name": type_string(typeof(key))})
			rows.append_array(_progress_type_profile(value[key], child_path))
	elif value is Array:
		rows.append({"path": value_path, "role": "container", "type_id": type_id,
			"type_name": type_string(type_id), "size": value.size()})
		for index in range(value.size()):
			rows.append_array(_progress_type_profile(value[index], value_path + "[" + str(index) + "]"))
	else:
		rows.append({"path": value_path, "role": "value", "type_id": type_id,
			"type_name": type_string(type_id), "value": value})
	return rows


func _saved_state() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory + "/professional.json"))
	return value if value is Dictionary else {}


func _file_bytes() -> Dictionary:
	var result: Dictionary = {}
	for filename in DirAccess.get_files_at(directory):
		# Hex preserves exact bytes including recovery files without text normalization.
		result[filename] = FileAccess.get_file_as_bytes(directory.path_join(filename)).hex_encode()
	return result


func _non_professional_files(files: Dictionary) -> Dictionary:
	var result: Dictionary = files.duplicate(true)
	for filename in files:
		if str(filename).begins_with("professional.json"):
			result.erase(filename)
	return result


func _dispose() -> void:
	cleanup_started = true
	if is_instance_valid(app):
		app.queue_free()
	for unused in range(4):
		await process_frame


func _finish() -> void:
	var result: Dictionary = {"schema": 1, "probe": "final-claim-after-preflight-r02",
		"status": "passed" if failures == 0 else "failed", "checks": checks, "failures": failures,
		"scope": "Native real UI/Play/loader/session/store with synthetic owner/catalog/media boundary",
		"limitations": ["No production owner or native engine-boundary authorization claim", "No Web, export, or curriculum-art approval", "No requirement that error UI keeps controls visible or enabled"],
		"assertions": assertions, "observations": observations}
	var output := FileAccess.open(attempt_directory.path_join("result.json"), FileAccess.WRITE)
	if output == null:
		printerr("Could not retain the structured probe result.")
		quit(2)
		return
	output.store_string(JSON.stringify(result, "\t") + "\n")
	output.close()
	print("Final claim after successful preflight: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

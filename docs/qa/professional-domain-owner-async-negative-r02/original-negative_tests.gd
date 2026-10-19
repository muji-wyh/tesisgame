extends SceneTree
## Immutable synthetic package rejection and owner-replacement supplement.

const Context = preload("res://scripts/learning_context.gd")
var _checks: Array[Dictionary] = []
var _failures: int = 0
var _results: Dictionary = {}
var _phases: Dictionary = {}
var _manifest: Dictionary = {}
var _context: Dictionary = {}
var _observations: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	_checks.append({"check": label, "passed": value})
	if not value:
		_failures += 1
		printerr("FAIL: " + label)


func _new_owner(id: String) -> Node:
	var source: Script = load("res://cases/" + id + "/owner.gd")
	var owner: Node = source.new()
	root.add_child(owner)
	owner.configure()
	var identity: String = str(owner.get_instance_id())
	_phases[identity] = []
	owner.phase_entered.connect(func(selection: int, phase: String) -> void:
		_phases[identity].append({"selection": selection, "phase": phase}))
	owner.completed.connect(func(selection: int, result: Dictionary) -> void:
		_results[identity + ":" + str(selection)] = result)
	return owner


func _result(owner: Node, selection: int) -> Dictionary:
	var key: String = str(owner.get_instance_id()) + ":" + str(selection)
	for frame: int in range(250):
		if _results.has(key):
			return _results[key]
		await process_frame
	_check(false, "Request completes within 250 process frames")
	return {"ok": false, "error": "Test timeout", "code": "timeout"}


func _discard(owner: Node) -> void:
	owner.retire()
	owner.queue_free()
	await process_frame


func _run() -> void:
	_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://case-manifest.json"))
	_context = Context.professional("retail", "module03", _manifest.curriculum_revision, "phrase")
	await _package_rejections()
	await _owner_replacement()
	await _invalid_replacement_requests()
	var report: Dictionary = {"schema": 1, "authority": "none", "count": _checks.size(), "failures": _failures,
		"checks": _checks, "cases": _observations,
		"scope": "Fixed synthetic package rejection and replacement only. Exact previous owner logic and current production catalog/resolver. No PCK/app trust, media fetch, browser, memory or latency acceptance."}
	var file: FileAccess = FileAccess.open("res://native-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("NEGATIVE OWNER CHECKS ", _checks.size(), " FAILURES ", _failures)
	quit(0 if _failures == 0 else 1)


func _package_rejections() -> void:
	for spec: Dictionary in _manifest.cases:
		if spec.expected_ok:
			continue
		var owner: Node = _new_owner(spec.id)
		var selection: int = owner.request(_context)
		var result: Dictionary = await _result(owner, selection)
		var state: Dictionary = owner.diagnostics()
		var phases: Array = _phases[str(owner.get_instance_id())]
		var forbidden: bool = false
		var errors: int = 0
		for row: Dictionary in phases:
			forbidden = forbidden or row.phase == spec.forbidden_phase
			if row.phase == "error":
				errors += 1
		_check(not result.get("ok", false), spec.id + ": corrupted/missing package is rejected")
		_check(str(result.get("error", "")).contains(spec.expected_error), spec.id + ": exact expected rejection family")
		_check(not result.has("token") and state.active_tokens == 0, spec.id + ": failure exposes no request token")
		_check(state.cached_modules == 0 and state.cache_insertions == 0 and state.publications == 0,
			spec.id + ": failed package cannot seed module cache or publish")
		_check(state.active_jobs == 0 and state.open_files == 0, spec.id + ": failure releases active job and file")
		_check(not forbidden, spec.id + ": rejected before forbidden phase " + spec.forbidden_phase)
		_check(errors == 1, spec.id + ": one terminal error transition")
		_check(not owner.resolve(RefCounted.new()).ok, spec.id + ": no token can be forged after failure")
		_observations.append({"id": spec.id, "selection": selection, "result": result, "state": state,
			"phases": phases.duplicate(true), "forbidden_phase": spec.forbidden_phase})
		await _discard(owner)


func _owner_replacement() -> void:
	var old: Node = _new_owner("valid")
	var issued: Dictionary = await _result(old, old.request(_context))
	_check(issued.get("ok", false), "Valid owner A starts from the unchanged audited synthetic module")
	if not issued.get("ok", false):
		await _discard(old)
		return
	var token: RefCounted = issued.token
	var content: Dictionary = old.resolve(token)
	_check(content.ok and content.module_words.size() == 50 and content.expressions.size() == 10,
		"Valid A content traverses exact current production catalog/resolver")
	old.retire()
	_check(not old.resolve(token).ok and old.diagnostics().cached_modules == 0 and not old.diagnostics().installed,
		"A loses token/cache/installed metadata before constructing B")
	var replacement: Node = _new_owner("index-hash")
	_check(not replacement.resolve(token).ok, "Invalid replacement B refuses A's old token before I/O")
	var injected: Dictionary = _context.duplicate(true)
	injected.token = token
	injected.records = content
	injected.accepted_ids = ["all"]
	injected.descriptor = {"sha256": "f".repeat(64), "path": "res://cases/valid/fixture/release.json"}
	var rejected: Dictionary = await _result(replacement, replacement.request(injected))
	_check(not rejected.ok and str(rejected.error).contains("digest differs"),
		"B's fixed bad pin cannot be replaced with caller token/content/descriptor")
	var before: Dictionary = replacement.diagnostics()
	_check(before.cached_modules == 0 and before.active_tokens == 0 and before.publications == 0,
		"Failed B cannot inherit retired A's cache or publication authority")
	var retried: Dictionary = await _result(replacement, replacement.request(_context))
	_check(not retried.ok and str(retried.error).contains("digest differs"), "Retrying B fails on the same immutable bad package")
	_check(replacement.diagnostics().policy_file_reads > before.policy_file_reads and replacement.diagnostics().cached_modules == 0,
		"Retry performs fresh B verification without warm fallback to A")
	replacement.configure()
	var configured: Dictionary = await _result(replacement, replacement.request(_context))
	_check(not configured.ok and replacement.diagnostics().active_tokens == 0, "Reconfiguring invalid B cannot revive A or bypass its pin")
	_check(content.ok and content.module_words.size() == 50, "Previously returned content remains independent copied data")
	var fresh: Node = _new_owner("valid")
	var fresh_result: Dictionary = await _result(fresh, fresh.request(_context))
	_check(fresh_result.ok and fresh.resolve(fresh_result.token).ok and not fresh.resolve(token).ok,
		"A separate valid C can recover without reviving the retired A token")
	await _discard(fresh)
	await _discard(replacement)
	await _discard(old)


func _invalid_replacement_requests() -> void:
	var owner: Node = _new_owner("valid")
	var replacements: Array = [
		{"id": "malformed", "context": {"accepted_ids": ["all"]}, "error": "Invalid professional fixture context"},
		{"id": "draft", "context": Context.professional("retail", "module04", _manifest.curriculum_revision, "phrase"), "error": "unavailable"},
		{"id": "foreign-course", "context": Context.professional("missing", "module03", _manifest.curriculum_revision, "phrase"), "error": "unavailable"},
		{"id": "wrong-revision", "context": Context.professional("retail", "module03", "wrong-revision", "phrase"), "error": "revision mismatch"},
		{"id": "unavailable-mode", "context": Context.professional("retail", "module03", _manifest.curriculum_revision, "match"), "error": ""}
	]
	for spec: Dictionary in replacements:
		var issued: Dictionary = await _result(owner, owner.request(_context))
		_check(issued.get("ok", false), spec.id + ": valid predecessor is prepared")
		if not issued.get("ok", false):
			continue
		var before: Dictionary = owner.diagnostics()
		var selection: int = owner.request(spec.context)
		_check(not owner.resolve(issued.token).ok and owner.diagnostics().active_tokens == 0,
			spec.id + ": invalid replacement revokes predecessor token immediately")
		var rejected: Dictionary = await _result(owner, selection)
		_check(not rejected.get("ok", false) and str(rejected.get("error", "")).contains(spec.error),
			spec.id + ": failed replacement cannot return predecessor success")
		if spec.id == "unavailable-mode":
			_check(rejected.get("code") == "mode_unavailable", "Mode replacement keeps actual production mode gate")
		var state: Dictionary = owner.diagnostics()
		_check(state.cached_modules == 1 and state.active_tokens == 0 and state.publications == before.publications,
			spec.id + ": previously verified cache remains data without replacement authority")
		_check(state.policy_file_reads == before.policy_file_reads and state.encoded_bytes_read == before.encoded_bytes_read,
			spec.id + ": immutable installed data handles rejection without extra owner I/O")
	var recovered: Dictionary = await _result(owner, owner.request(_context))
	_check(recovered.ok and owner.resolve(recovered.token).ok, "A subsequent valid request recovers after all rejected replacements")
	await _discard(owner)

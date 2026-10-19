extends SceneTree
## Production native/editor rejection only; no host override or trusted fixture.

const Owner = preload("res://scripts/professional_domain_owner.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const DomainCatalog = preload("res://scripts/professional_domain_catalog.gd")
const Context = preload("res://scripts/learning_context.gd")
const WAIT_FRAMES: int = 24

var checks: Array[Dictionary] = []
var failures: int = 0
var observations: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks.append({"check": message, "passed": condition})
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _context(course: String = "caregiving") -> Dictionary:
	return Context.professional(course, "module01", "professional-v1", "match")


func _fixture() -> Dictionary:
	var owner := Owner.new()
	root.add_child(owner)
	var fixture: Dictionary = {"owner": owner, "completed": [], "phases": [], "retirements": []}
	owner.completed.connect(func(selection: int, result: Dictionary) -> void:
		fixture.completed.append({"selection": selection, "result": result.duplicate(true)}))
	owner.phase_entered.connect(func(selection: int, phase: String) -> void:
		fixture.phases.append({"selection": selection, "phase": phase}))
	owner.retired.connect(func() -> void: fixture.retirements.append(true))
	return fixture


func _wait_for_completion(fixture: Dictionary, count: int = 1) -> void:
	for _frame: int in range(WAIT_FRAMES):
		if fixture.completed.size() >= count:
			return
		await process_frame
	check(false, "Production owner completes within the bounded native test frames")


func _settle_frames() -> void:
	for _frame: int in range(3):
		await process_frame


func _phases_for(fixture: Dictionary, selection: int) -> Array:
	var result: Array = []
	for entry: Dictionary in fixture.phases:
		if entry.selection == selection:
			result.append(entry.phase)
	return result


func _expect_failure(fixture: Dictionary, selection: int, code: String, label: String) -> void:
	check(fixture.completed.size() == 1, label + ": exactly one deferred completion")
	if fixture.completed.size() != 1:
		return
	var completion: Dictionary = fixture.completed[0]
	var result: Dictionary = completion.result
	check(completion.selection == selection and not result.get("ok", true) and result.get("code") == code,
		label + ": failure belongs to the current request and has the expected code")
	check(not str(result.get("error", "")).is_empty() and result.get("words") == []
		and result.get("expressions") == [] and not result.has("token"),
		label + ": failure has a message and exposes no content or authority")


func _expect_no_policy_work(fixture: Dictionary, label: String) -> void:
	var owner = fixture.owner
	var state: Dictionary = owner.diagnostics()
	check(state.policy_file_reads == 0 and state.encoded_bytes_read == 0 and state.manifest_file_reads == 0,
		label + ": no descriptor, index, themes, payload or manifest file is read")
	check(state.decode_calls == 0 and state.resolve_calls == 0,
		label + ": no policy decode or content resolution runs")
	check(not state.installed and state.cached_modules == 0 and state.cache_insertions == 0 and state.cache_hits == 0,
		label + ": no policy installation or module cache is created")
	check(state.active_tokens == 0 and state.active_catalog_capabilities == 0 and state.publications == 0,
		label + ": no token, catalog capability or successful publication is created")
	check(state.active_jobs == 0 and state.open_files == 0 and state.phase == "idle" and not owner.is_processing(),
		label + ": terminal work releases the job and leaves processing idle")
	var last: Dictionary = state.last_request
	if not last.is_empty():
		check(last.policy_file_reads == 0 and last.encoded_bytes_read == 0 and last.manifest_file_reads == 0
			and not last.warm_cache_hit and not last.ok, label + ": request diagnostics retain zero reads and no acceptance")
	observations.append({"case": label, "diagnostics": state, "completed": fixture.completed.duplicate(true),
		"phases": fixture.phases.duplicate(true), "retirement_count": fixture.retirements.size()})


func _discard(fixture: Dictionary) -> void:
	fixture.owner.free()
	await process_frame


func _test_unconfigured_and_invalid_requests() -> void:
	var fixture: Dictionary = _fixture()
	var selection: int = fixture.owner.request(_context())
	check(fixture.completed.is_empty() and fixture.phases.is_empty(), "Unconfigured failure is never synchronous")
	await _wait_for_completion(fixture)
	_expect_failure(fixture, selection, "policy_unavailable", "Unconfigured owner")
	check(_phases_for(fixture, selection) == ["error"], "Unconfigured request never reaches pin loading")
	_expect_no_policy_work(fixture, "Unconfigured owner")
	await _discard(fixture)
	var invalid_values: Array = [null, {}, Context.growth(7, "match"), _context()]
	invalid_values[3]["mode"] = "unknown"
	for index: int in range(invalid_values.size()):
		fixture = _fixture()
		check(fixture.owner.configure().get("ok", false), "Invalid request case configures the production owner")
		selection = fixture.owner.request(invalid_values[index])
		check(fixture.completed.is_empty(), "Invalid context rejection is deferred")
		await _wait_for_completion(fixture)
		var label: String = "Invalid context %d" % index
		_expect_failure(fixture, selection, "invalid_policy", label)
		check(_phases_for(fixture, selection) == ["error"], label + ": rejects before pin loading")
		_expect_no_policy_work(fixture, label)
		await _discard(fixture)


func _test_configuration_and_native_rejection() -> void:
	var fixture: Dictionary = _fixture()
	var owner = fixture.owner
	check(owner.configure().get("ok", false), "Production owner configures without granting policy authority")
	var initial: Dictionary = owner.diagnostics()
	check(owner.configure().get("ok", false) and owner.diagnostics() == initial,
		"Repeated idle configure is idempotent")
	_expect_no_policy_work(fixture, "Configured idle owner")
	var selection: int = owner.request(_context())
	var pending: Dictionary = owner.diagnostics()
	check(fixture.completed.is_empty() and fixture.phases.is_empty() and pending.phase == "pin"
		and pending.active_jobs == 1, "Valid native request queues pin work without synchronous processing")
	check(owner.configure().get("ok", false) and owner.diagnostics() == pending and owner.is_processing(),
		"Repeated configure preserves an in-flight request and its processing")
	await _wait_for_completion(fixture)
	_expect_failure(fixture, selection, "policy_unavailable", "Native host rejection")
	check(_phases_for(fixture, selection) == ["pin", "error"],
		"Native/editor host rejects at the pin before descriptor open or decode")
	check(owner.diagnostics().last_request.request_id == selection
		and owner.diagnostics().last_request.code == "policy_unavailable", "Native failure diagnostics identify the rejected request")
	await _settle_frames()
	check(fixture.completed.size() == 1, "Native rejection is not emitted again on later process frames")
	_expect_no_policy_work(fixture, "Native host rejection")
	await _discard(fixture)


func _test_cancellation() -> void:
	for checkpoint: String in ["before_process", "pin", "error"]:
		var fixture: Dictionary = _fixture()
		var owner = fixture.owner
		owner.configure()
		var state: Dictionary = {"triggered": false}
		if checkpoint != "before_process":
			owner.phase_entered.connect(func(_selection: int, phase: String) -> void:
				if phase == checkpoint and not state.triggered:
					state.triggered = true
					owner.cancel())
		var selection: int = owner.request(_context())
		if checkpoint == "before_process":
			state.triggered = true
			owner.cancel()
		await _settle_frames()
		var label: String = "Cancel at " + checkpoint
		check(state.triggered and fixture.completed.is_empty(), label + ": suppresses deferred completion")
		check(owner.diagnostics().selection > selection and owner.diagnostics().configured
			and not owner.diagnostics().closed, label + ": invalidates selection without retiring the owner")
		var expected: Array = [] if checkpoint == "before_process" else (["pin"] if checkpoint == "pin" else ["pin", "error"])
		check(_phases_for(fixture, selection) == expected, label + ": performs no later phase")
		_expect_no_policy_work(fixture, label)
		var replacement: int = owner.request(_context("retail"))
		check(fixture.completed.is_empty(), label + ": replacement remains deferred")
		await _wait_for_completion(fixture)
		_expect_failure(fixture, replacement, "policy_unavailable", label + " replacement")
		_expect_no_policy_work(fixture, label + " replacement")
		await _discard(fixture)


func _test_supersession() -> void:
	for checkpoint: String in ["before_process", "pin", "error"]:
		var fixture: Dictionary = _fixture()
		var owner = fixture.owner
		owner.configure()
		var state: Dictionary = {"first": 0, "replacement": 0, "triggered": false}
		if checkpoint != "before_process":
			owner.phase_entered.connect(func(selection: int, phase: String) -> void:
				if selection == state.first and phase == checkpoint and not state.triggered:
					state.triggered = true
					state.replacement = owner.request(_context("retail"), 29))
		state.first = owner.request(_context(), 17)
		if checkpoint == "before_process":
			state.triggered = true
			state.replacement = owner.request(_context("retail"), 29)
		check(fixture.completed.is_empty(), "Supersession never emits a synchronous rejection")
		await _wait_for_completion(fixture)
		await _settle_frames()
		var label: String = "Supersede at " + checkpoint
		check(state.triggered and state.replacement > state.first, label + ": replacement receives a new identity")
		_expect_failure(fixture, state.replacement, "policy_unavailable", label)
		var expected: Array = [] if checkpoint == "before_process" else (["pin"] if checkpoint == "pin" else ["pin", "error"])
		check(_phases_for(fixture, state.first) == expected, label + ": stale request stops at the replacement boundary")
		check(_phases_for(fixture, state.replacement) == ["pin", "error"], label + ": current request follows the native guard")
		check(owner.diagnostics().last_request.request_id == state.replacement, label + ": diagnostics belong to the replacement")
		_expect_no_policy_work(fixture, label)
		await _discard(fixture)


func _test_retirement() -> void:
	for checkpoint: String in ["before_process", "pin", "error"]:
		var fixture: Dictionary = _fixture()
		var owner = fixture.owner
		owner.configure()
		var state: Dictionary = {"triggered": false}
		var epoch: int = owner.diagnostics().epoch
		if checkpoint != "before_process":
			owner.phase_entered.connect(func(_selection: int, phase: String) -> void:
				if phase == checkpoint and not state.triggered:
					state.triggered = true
					owner.retire())
		var selection: int = owner.request(_context())
		if checkpoint == "before_process":
			state.triggered = true
			owner.retire()
		await _settle_frames()
		var label: String = "Retire at " + checkpoint
		check(state.triggered and fixture.completed.is_empty() and fixture.retirements.size() == 1,
			label + ": notifies once and cancels pending completion")
		check(owner.diagnostics().closed and not owner.diagnostics().configured
			and owner.diagnostics().epoch > epoch and owner.diagnostics().selection > selection,
			label + ": invalidates the request and permanently closes the owner")
		_expect_no_policy_work(fixture, label)
		owner.retire()
		var configured: Dictionary = owner.configure()
		check(fixture.retirements.size() == 1 and not configured.get("ok", true)
			and configured.get("code") == "policy_unavailable" and owner.diagnostics().closed,
			label + ": repeated retirement cannot re-notify or reopen through configure")
		var terminal: int = owner.request(_context("retail"))
		check(fixture.completed.is_empty(), label + ": request after close also fails asynchronously")
		await _wait_for_completion(fixture)
		_expect_failure(fixture, terminal, "policy_unavailable", label + " terminal request")
		check(_phases_for(fixture, terminal) == ["error"], label + ": terminal request cannot revisit the pin")
		_expect_no_policy_work(fixture, label + " terminal request")
		await _discard(fixture)
		check(fixture.retirements.size() == 1, label + ": tree exit does not duplicate retirement")


func _test_catalog_separation() -> void:
	var fixture: Dictionary = _fixture()
	var owner = fixture.owner
	owner.configure()
	var selection: int = owner.request(_context())
	await _wait_for_completion(fixture)
	_expect_failure(fixture, selection, "policy_unavailable", "Catalog separation owner")
	var impostor := RefCounted.new()
	for candidate: Variant in [null, {}, impostor]:
		var rejected_token: Dictionary = owner.resolve(candidate)
		check(not owner.is_current(candidate) and not rejected_token.get("ok", true)
			and rejected_token.get("code") == "stale_policy" and not rejected_token.has("token"),
			"Caller-created values cannot impersonate a current owner token")
	var adapter := DomainCatalog.new(owner, impostor)
	check(not adapter.load_index() and adapter.courses().is_empty() and adapter.course("caregiving").is_empty(),
		"Unregistered catalog capability exposes no verified course snapshot")
	var resolved: Dictionary = adapter.resolve(_context())
	check(not resolved.get("ok", true) and resolved.get("words") == [] and resolved.get("expressions") == [],
		"Private adapter cannot resolve through ordinary loose source fallback")
	owner.retire()
	var catalog := Catalog.new()
	check(catalog.load_index(), "Ordinary Home catalog still loads after production owner rejection and retirement")
	var courses: Array = catalog.courses()
	check(courses.size() == 20, "Home retains all twenty ordinary course metadata entries")
	for id: String in ["caregiving", "retail"]:
		var course: Dictionary = catalog.course(id)
		check(course.get("id") == id and course.get("modules", []).size() == 10,
			"Home can browse the ordinary " + id + " module metadata")
		check(not catalog.theme_profile(str(course.get("theme_id", ""))).is_empty(),
			"Home can load the ordinary " + id + " theme profile")
	_expect_no_policy_work(fixture, "Home catalog separation")
	await _discard(fixture)


func _write_optional_report() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--report="):
			continue
		var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
		check(file != null, "Optional native test report can be opened")
		if file == null:
			return
		var report: Dictionary = {"schema_version": 1, "kind": "professional_domain_owner_native_tests_v1",
			"host_features": {"web": OS.has_feature("web"), "editor": OS.has_feature("editor")},
			"checks": checks, "failures": failures, "observations": observations,
			"scope": "Unmodified production native/editor unavailable path and ordinary Home catalog only. No Web success, accepted authority, gameplay, media, human review, performance or memory acceptance."}
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
		return


func _run() -> void:
	check(not OS.has_feature("web") or OS.has_feature("editor"), "This suite requires the production native/editor unavailable host")
	if failures == 0:
		await _test_unconfigured_and_invalid_requests()
		await _test_configuration_and_native_rejection()
		await _test_cancellation()
		await _test_supersession()
		await _test_retirement()
		await _test_catalog_separation()
	_write_optional_report()
	print("Professional domain owner native: %d checks, %d failures" % [checks.size(), failures])
	quit(1 if failures else 0)

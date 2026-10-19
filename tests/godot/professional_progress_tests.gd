extends SceneTree

const Progress = preload("res://scripts/professional_progress.gd")
const Store = preload("res://scripts/professional_store.gd")
const HeldSixWallet = preload("res://scripts/coin_wallet.gd")

var checks := 0
var failures := 0
var _directory: String


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _module(course: String = "retail", content_revision: String = "content-1", requirements_revision: String = "objectives-1") -> Dictionary:
	var terms: Array = []
	var expressions: Array = []
	for index in range(50):
		terms.append({"sense_id": "sense-%d" % index, "skills": ["recognition", "context", "spelling"]})
	for index in range(10):
		expressions.append("expression-%d" % index)
	return {"course_id": course, "module_id": "workplace", "curriculum_revision": content_revision,
		"requirements_revision": requirements_revision, "terms": terms, "expressions": expressions}


func _event(id: String, changes: Dictionary = {}) -> Dictionary:
	var event: Dictionary = {"id": id, "sense_id": "sense-0", "skill": "recognition", "correct": true, "assisted": false, "atomic": false,
		"context": {"track": "professional", "course_id": "retail", "module_id": "workplace", "curriculum_revision": "content-1", "mode": "match"}}
	event.merge(changes, true)
	if not changes.has("context"):
		event.context.mode = {"context": "phrase", "spelling": "word_jelly", "speaking": "pop"}.get(event.skill, "match")
	return event


func _run() -> void:
	_directory = "user://professional-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_absolute(_directory) == OK, "Create isolated professional storage")
	_test_evidence()
	_test_atomic_and_mode_eligibility()
	_test_completion()
	_test_held_six_history()
	await _test_storage()
	for file in DirAccess.get_files_at(_directory):
		check(DirAccess.remove_absolute(_directory.path_join(file)) == OK, "Remove isolated fixture")
	check(DirAccess.remove_absolute(_directory) == OK, "Remove isolated fixture directory")
	print("Professional progress: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_evidence() -> void:
	var model = Progress.new()
	var named_keys: Dictionary = {&"z": 1, "a": {&"n": 2}}
	check(Progress.canonical(named_keys) == Progress.canonical({"z": 1.0, "a": {"n": 2.0}}), "StringName property keys and parsed JSON keys have identical event fingerprints")
	check(model.configure([_module(), _module("nursing")]), "Configure reviewed module fixtures")
	var state: Dictionary = Progress.empty_progress()
	for index in range(2):
		state = model.apply_event(state, _event("answer-%d" % index)).progress
	state = model.apply_event(state, _event("assisted", {"assisted": true})).progress
	check(state.skills["sense-0"].recognition.streak == 2 and not state.skills["sense-0"].recognition.earned, "Assisted exposure cannot master a skill")
	var other: Dictionary = _event("other-course")
	other.context.course_id = "nursing"
	state = model.apply_event(state, other).progress
	check(state.skills["sense-0"].recognition.earned, "Same sense shares evidence across courses")
	check(not state.skills["sense-0"].has("spelling"), "Unassessed skills remain absent")
	state = model.apply_event(state, _event("mistake", {"correct": false, "assisted": true})).progress
	check(state.skills["sense-0"].recognition.streak == 0 and state.skills["sense-0"].recognition.earned, "Mistake resets streak while lifetime mastery remains")
	check(not model.apply_event(state, _event("missing", {"sense_id": "missing"})).ok, "Unknown sense rejected")
	var changed: Dictionary = _module()
	changed.terms[0].skills = ["spelling"]
	check(model.configure([changed]), "Load changed requirements for rejection check")
	check(not model.apply_event(state, _event("changed", {"skill": "spelling"})).ok, "Changed objectives require a new revision")
	changed.terms.pop_back()
	check(not model.configure([changed]), "Incomplete production modules are not accepted")


func _test_atomic_and_mode_eligibility() -> void:
	var model = Progress.new()
	var row: Dictionary = _module()
	row.terms[0].skills = ["recognition", "context"]
	check(model.configure([row]), "Configure atomic term without spelling mastery")
	var state: Dictionary = Progress.empty_progress()
	for index in range(4):
		var result: Dictionary = model.apply_event(state, _event("atomic-%d" % index, {"atomic": true, "skill": "spelling"}))
		check(result.ok, "Atomic Word Jelly exposure accepts module sense without eligible spelling mastery")
		if result.ok:
			state = result.progress
	check(state.skills.get("sense-0", {}).get("spelling", {}) == {"streak": 0, "earned": false, "exposures": 4}, "Repeated atomic exposure never grants spelling mastery")
	check(not state.skills.get("sense-0", {}).has("recognition") and state.completions.is_empty(), "Atomic collection cannot assess another skill or complete a module")
	check(not model.validate_event(_event("assessed", {"skill": "spelling"})).is_empty(), "Ineligible assessed spelling remains rejected")
	check(not model.validate_event(_event("unknown", {"skill": "spelling", "atomic": true, "sense_id": "missing"})).is_empty(), "Atomic collection still requires module membership")
	check(not model.validate_event(_event("incorrect", {"skill": "spelling", "atomic": true, "correct": false})).is_empty(), "Atomic collection must be correct")
	check(not model.validate_event(_event("expression", {"skill": "spelling", "atomic": true, "expression_id": "expression-0"})).is_empty(), "Atomic collection cannot complete expressions")
	check(not model.validate_event(_event("wrong-atomic", {"atomic": true})).is_empty(), "Recognition cannot masquerade as atomic spelling exposure")
	var wrong_mode: Dictionary = _event("wrong-mode", {"skill": "spelling", "atomic": true})
	wrong_mode.context.mode = "match"
	check(not model.validate_event(wrong_mode).is_empty(), "Atomic spelling requires Word Jelly mode")
	var skills: Array = ["recognition", "listening", "spelling", "speaking", "context"]
	row.terms[0].skills = skills
	check(model.configure([row]), "Configure complete skill eligibility for mode validation")
	var modes: Dictionary = {"match": ["recognition", "listening"], "memory": ["recognition", "listening"],
		"pop": ["speaking"], "phrase": ["context", "listening"], "jelly": ["recognition", "listening"], "word_jelly": ["spelling"]}
	for mode in modes:
		for skill in skills:
			var answer: Dictionary = _event("mode-%s-%s" % [mode, skill], {"skill": skill})
			answer.context.mode = mode
			check(model.validate_event(answer).is_empty() == (skill in modes[mode]), "Only the actual exercise skill is accepted: %s / %s" % [mode, skill])


func _test_completion() -> void:
	var model = Progress.new()
	check(model.configure([_module()]), "Configure completion requirements")
	var state: Dictionary = Progress.empty_progress()
	for index in range(50):
		for answer in range(3):
			var result: Dictionary = model.apply_event(state, _event("term-%d-%d" % [index, answer], {"sense_id": "sense-%d" % index}))
			check(result.ok, "Accept assessed module answer")
			state = result.progress
	for index in range(10):
		state = model.apply_event(state, _event("assisted-%d" % index, {"skill": "context", "expression_id": "expression-%d" % index, "assisted": true})).progress
	check(state.completions.is_empty(), "Assisted expression answers do not complete a module")
	for index in range(9):
		state = model.apply_event(state, _event("expression-%d" % index, {"skill": "context", "expression_id": "expression-%d" % index})).progress
	check(state.completions.is_empty(), "All ten expressions required")
	state = model.apply_event(state, _event("last-expression", {"skill": "context", "expression_id": "expression-9"})).progress
	var key: String = Progress.requirement_key(_module())
	check(state.completions.has(key), "Fifty terms and ten expressions earn completion")
	var receipt: Dictionary = state.completions[key].duplicate(true)
	check(model.configure([_module("retail", "content-2")]), "Content revision can retain unchanged requirements")
	var next: Dictionary = _event("revised", {"correct": false})
	next.context.curriculum_revision = "content-2"
	state = model.apply_event(state, next).progress
	check(state.completions[key] == receipt, "Content changes and mistakes retain completion")


func _test_storage() -> void:
	var path: String = _directory.path_join("progress.json")
	var store = Store.new()
	root.add_child(store)
	check(store.configure([], path), "Configure native save without preloading content")
	check(store.transact_native("load").progress.sequence == 0, "Fresh native profile")
	check(store.transact_native("register", {"requirements": [_module()]}).registered == 1, "Register module requirements on demand")
	check(store.transact_native("register", {"requirements": [_module()]}).ok, "Identical registration is idempotent")
	var event: Dictionary = _event("wallet-event", {"reward": {"operation": "credit", "payload": {"tier": 1}}})
	store.before_commit = func(_operation: String) -> bool: return false
	check(not store.transact_native("record", event).ok, "Failed native write is retryable")
	check(store.transact_native("load").progress.sequence == 0, "Failed write grants no progress")
	store.before_commit = Callable()
	check(store.transact_native("record", event).ok, "Retry records once")
	check(store.transact_native("record", event).duplicate, "Repeated answer ID is idempotent")
	var conflict: Dictionary = event.duplicate(true)
	conflict.assisted = true
	check(not store.transact_native("record", conflict).ok, "Conflicting event payload rejected")
	var loaded: Dictionary = store.transact_native("load")
	check(loaded.outbox.size() == 1 and loaded.outbox[0].receipt_id == "professional:wallet-event", "Progress and wallet outbox commit together")
	var second = Store.new()
	root.add_child(second)
	check(second.configure([_module()], path), "Configure second native session")
	check(second.transact_native("record", _event("second-session")).ok, "Second session rebases on latest file")
	check(store.transact_native("load").progress.sequence == 2, "Original session reads committed evidence")
	var busy: Dictionary = {}
	store.before_commit = func(_operation: String) -> bool:
		busy.merge(second.transact_native("record", _event("competing")), true)
		return true
	check(store.transact_native("record", _event("locking")).ok, "Native transaction commits while holding lock")
	check(busy.get("reason") == "busy", "Overlapping native writer cannot overwrite transaction")
	store.before_commit = Callable()
	check(second.transact_native("record", _event("competing")).ok, "Contending writer can retry after release")
	check(second.transact_native("ack", {"id": "wallet-event"}).ok, "Wallet acknowledgment clears outbox")
	check(store.transact_native("ack", {"id": "wallet-event"}).duplicate, "Acknowledgment is idempotent")
	check(store.transact_native("record", event).duplicate and store.transact_native("load").outbox.is_empty(), "Replayed event never recreates acknowledged reward")
	check(not store.transact_native("ack", {"id": "second-session"}).ok, "Cannot acknowledge an unrewarded answer")
	check(DirAccess.rename_absolute(path, path + ".previous") == OK, "Simulate interrupted native replacement")
	check(store.transact_native("load").progress.sequence == 4, "Interrupted replacement restores committed snapshot")
	var context: Dictionary = _event("context").context
	var request_id: int = store.request("context", context)
	var response: Array = await store.completed
	check(response[0] == request_id and response[1].ok, "Native adapter uses asynchronous request contract")
	check(store.transact_native("load").context == context, "Context persists alongside progress")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	var damaged: Dictionary = store.transact_native("load")
	check(not damaged.ok and not damaged.has("progress"), "Damaged saves never become a fresh profile")
	check(second.configure([], _directory.path_join("missing-directory/progress.json")), "Configure unavailable location fixture")
	check(not second.transact_native("load").ok, "Unavailable native directory never becomes a fresh profile")
	store.queue_free()
	second.queue_free()


func _held_six_snapshot(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(value is Dictionary, "Held-six isolated save remains readable")
	return value if value is Dictionary else {}


func _test_held_six_history() -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/professional-held-six-progress.json"))
	check(value is Dictionary, "Read shared populated held-six history fixture")
	if not value is Dictionary:
		return
	var fixture: Dictionary = value
	var path: String = _directory.path_join("held-six-progress.json")
	var wallet_path: String = _directory.path_join("held-six-wallet.cfg")
	var seed := FileAccess.open(path, FileAccess.WRITE)
	check(seed != null, "Create only an isolated populated native test profile")
	if seed == null:
		return
	seed.store_string(JSON.stringify(fixture.legacy_state))
	seed.close()
	var wallet_seed := FileAccess.open(wallet_path, FileAccess.WRITE)
	check(wallet_seed != null, "Create isolated historical wallet fixture")
	if wallet_seed == null:
		return
	wallet_seed.store_string(fixture.wallet.initial.text)
	wallet_seed.close()
	var store = Store.new()
	var legacy = Store.new()
	root.add_child(store)
	root.add_child(legacy)
	check(store.configure(fixture.current_rows, path) and legacy.configure(fixture.old_rows, path), "Old and current native clients keep their exact registered contexts")
	check(store.transact_native("load").ok, "Current client opens populated schema-one history")
	check(_held_six_snapshot(path) == fixture.legacy_state, "Opening current content changes no historical saved field")
	check(store.transact_native("register", {"requirements": fixture.current_rows}).ok, "Register current requirements without migration")
	check(_held_six_snapshot(path) == fixture.legacy_state, "Registration preserves skills, events, expressions, requirements, completion and outbox")
	for id in fixture.current_ids:
		check(not fixture.legacy_state.progress.skills.has(id), "Controlled fixture contains no new-ID evidence: " + id)
	var stale: Dictionary = store.transact_native("record", fixture.legacy_events[0])
	check(not stale.ok and "professional module revision" in stale.error, "Current client rejects stale context before historical duplicate lookup")
	check(legacy.transact_native("record", fixture.legacy_events[0]).duplicate, "Original context recognizes an exact historical retry")
	check(_held_six_snapshot(path) == fixture.legacy_state, "No old event or context is translated to a new identity")
	var changed: Dictionary = fixture.old_rows[0].duplicate(true)
	changed.terms[0].skills = ["spelling"]
	var rejected: Dictionary = store.transact_native("register", {"requirements": [changed]})
	check(not rejected.ok and "without a new revision" in rejected.error, "Current registration cannot replace an old immutable requirements fingerprint")
	check(legacy.transact_native("record", fixture.old_later_event).ok, "Old content can append old-ID evidence without converting it")
	var after_old: Dictionary = _held_six_snapshot(path)
	check(after_old.progress.sequence == fixture.expected_sequence.after_old_writer and after_old.progress.completions == fixture.legacy_state.progress.completions, "Old writer preserves the existing completion receipt")
	check(store.transact_native("context", fixture.current_events[0].context).ok, "Selecting current content persists an explicit new context")
	var before_failure: Dictionary = _held_six_snapshot(path)
	store.before_commit = func(_operation: String) -> bool: return false
	check(not store.transact_native("record", fixture.current_events[0]).ok, "Current native write can fail before persistence")
	store.before_commit = Callable()
	check(_held_six_snapshot(path) == before_failure, "Failed current write leaves all old history and pending rewards unchanged")
	for index in range(fixture.current_events.size()):
		var event: Dictionary = fixture.current_events[index]
		var result: Dictionary = store.transact_native("record", event)
		check(result.ok and not result.duplicate, "Accept one new event in deterministic shared order: " + event.id)
		if not result.ok:
			continue
		var evidence: Dictionary = result.progress.skills[event.sense_id]
		match index % 8:
			0:
				check(evidence.recognition == {"streak": 0, "earned": false, "exposures": 1}, "Assisted success cannot inherit old mastery")
			1:
				check(evidence.spelling == {"streak": 0, "earned": false, "exposures": 1}, "Atomic spelling is only a new-ID exposure")
			3:
				check(evidence.recognition == {"streak": 0, "earned": false, "exposures": 3}, "A real mistake resets a new-ID streak")
			6:
				check(evidence.recognition == {"streak": 3, "earned": true, "exposures": 6}, "Three fresh consecutive successes earn only the new sense")
			7:
				check(evidence.recognition == {"streak": 0, "earned": true, "exposures": 7}, "Later mistakes preserve earned new-ID mastery")
	var before_retry: Dictionary = _held_six_snapshot(path)
	check(store.transact_native("record", fixture.current_events[0]).duplicate, "Identical new event retry cannot add progress or another grant")
	var conflict: Dictionary = fixture.current_events[0].duplicate(true)
	conflict.assisted = false
	var conflict_result: Dictionary = store.transact_native("record", conflict)
	check(not conflict_result.ok and "different event" in conflict_result.error, "Conflicting same-ID retry fails against its original fingerprint")
	check(_held_six_snapshot(path) == before_retry, "Both retry paths preserve every stored field")
	check(store.transact_native("record", fixture.shared_career_event).ok, "Unchanged canonical sense continues sharing across careers")
	var current_key: String = Progress.requirement_key(fixture.current_rows[0])
	var before_expressions: Dictionary = _held_six_snapshot(path)
	check(before_expressions.progress.sequence == fixture.expected_sequence.before_new_expressions, "Both backends consume the same pre-expression event count")
	check(not before_expressions.progress.expressions.has(current_key) and not before_expressions.progress.completions.has(current_key), "Old expression map and old completion never satisfy the revised requirement key")
	check(before_expressions.progress.skills[fixture.unchanged_sense_id].recognition.earned, "Unchanged earned skill remains shared")
	for index in range(fixture.expression_events.size()):
		var result: Dictionary = store.transact_native("record", fixture.expression_events[index])
		check(result.ok, "New revision records an explicit fresh contextual answer")
		if result.ok:
			check(result.progress.completions.has(current_key) == (index == 9), "All ten expressions must be answered under the current revision")
	var wallet = HeldSixWallet.new(wallet_path)
	check(wallet.load_state() and wallet.balance == fixture.wallet.initial.balance, "Real native wallet opens its unchanged permanent historical receipt")
	var unready_wallet = HeldSixWallet.new(_directory.path_join("unready-wallet.cfg"))
	var before_wallet_failure: Dictionary = _held_six_snapshot(path)
	check(not unready_wallet.credit("professional:held-six.old.pending", 2).ok, "An unavailable wallet delivery does not succeed")
	check(_held_six_snapshot(path) == before_wallet_failure, "Failed wallet delivery leaves old and current pending grants intact")
	var delivered: Dictionary = wallet.credit("professional:held-six.old.pending", 2)
	check(delivered.ok and not delivered.duplicate and wallet.balance == fixture.wallet.after_legacy_delivery.balance, "Old pending grant reaches the real wallet under its original permanent receipt")
	store.before_commit = func(_operation: String) -> bool: return false
	check(not store.transact_native("ack", {"id": "held-six.old.pending"}).ok, "Wallet success can precede failed acknowledgment")
	store.before_commit = Callable()
	var before_restart: Dictionary = _held_six_snapshot(path)
	store.close()
	legacy.close()
	store.free()
	legacy.free()
	store = Store.new()
	legacy = Store.new()
	root.add_child(store)
	root.add_child(legacy)
	check(store.configure(fixture.current_rows, path) and legacy.configure(fixture.old_rows, path), "Restart both exact revision clients without resetting the save")
	check(store.transact_native("load").ok and _held_six_snapshot(path) == before_restart, "Native restart preserves complete populated progress, events and both pending grants")
	wallet = HeldSixWallet.new(wallet_path)
	check(wallet.load_state(), "Reopen the real durable wallet after crash-before-ack")
	check(wallet.credit("professional:held-six.old.pending", 2).duplicate and wallet.balance == fixture.wallet.after_legacy_delivery.balance, "Permanent old wallet receipt prevents duplicate coins on recovery")
	check(store.transact_native("ack", {"id": "held-six.old.pending"}).ok and store.transact_native("ack", {"id": "held-six.old.pending"}).duplicate, "Old acknowledgment settles once without rewriting event identity")
	var current_reward: Dictionary = fixture.current_events[0]
	check(wallet.credit("professional:" + current_reward.id, 1).ok and wallet.balance == fixture.wallet.final.balance, "Current event earns only its separately saved wallet grant")
	check(store.transact_native("ack", {"id": current_reward.id}).ok, "Acknowledge current reward only after real wallet success")
	check(store.transact_native("record", current_reward).duplicate, "Acknowledged current retry never recreates an outbox entry")
	check(legacy.transact_native("record", fixture.legacy_events[1]).duplicate and not store.transact_native("record", fixture.legacy_events[1]).ok, "Acknowledged old retry still requires its original context")
	check(_held_six_snapshot(path) == fixture.expected_final_state, "Complete normalized native state matches the shared browser expectation")
	var expected_receipts: Dictionary = fixture.wallet.final.receipts
	check(wallet.balance == fixture.wallet.final.balance and wallet._receipts.size() == expected_receipts.size(), "Native wallet retains the exact final balance and receipt count")
	# JSON fixture numbers are floats; native ConfigFile receipt amounts stay ints.
	for id in expected_receipts:
		check(wallet._receipts.has(id) and wallet._receipts[id] is int and wallet._receipts[id] == expected_receipts[id], "Native wallet preserves the exact integer receipt: " + str(id))
	var final_wallet := HeldSixWallet.new(wallet_path)
	check(final_wallet.load_state() and final_wallet.balance == fixture.wallet.final.balance
		and Progress.canonical(final_wallet._receipts) == Progress.canonical(expected_receipts), "Reopened native wallet retains every exact final receipt")
	store.close()
	legacy.close()
	store.free()
	legacy.free()

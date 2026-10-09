extends SceneTree

const State = preload("res://scripts/growth_state.gd")
const MatchModel = preload("res://scripts/game_model.gd")
const PopModel = preload("res://scripts/voice_pop_model.gd")
const PhraseGame = preload("res://scripts/phrase_game.gd")

var checks: int = 0
var failures: int = 0
var _root: String


class Storage extends RefCounted:
	var backing: Dictionary
	var text: Variant:
		get:
			return backing.text
		set(value):
			backing.text = value
	var readable: bool = true
	var writable: bool = true
	var writes: int = 0
	var before_write: Callable

	func _init(shared: Dictionary = {}) -> void:
		backing = shared if not shared.is_empty() else {"text": null}

	func growthState() -> Variant:
		return text if readable else false

	func saveGrowthState(value: String, expected_text: Variant) -> bool:
		writes += 1
		if before_write.is_valid():
			var callback: Callable = before_write
			before_write = Callable()
			callback.call()
		if not writable or text != expected_text:
			return false
		text = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	_root = "user://growth_state_tests_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_absolute(_root) == OK, "Create isolated learning fixtures")
	_test_streaks_and_receipts()
	_test_levels()
	_test_pending_order()
	_test_concurrent_hosts()
	_test_concurrent_pending()
	_test_save_conflict()
	_test_invalid_input()
	_test_invalid_saves()
	_test_native_recovery()
	_test_receipt_bound()
	_test_match_events()
	_test_pop_events()
	await _test_phrase_events()
	for name in DirAccess.get_files_at(_root):
		check(DirAccess.remove_absolute(_root.path_join(name)) == OK, "Remove isolated learning fixture")
	check(DirAccess.remove_absolute(_root) == OK, "Remove isolated learning fixture directory")
	print("Growth state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _words() -> Array:
	var result: Array = [{"id": "apple", "min_age": 3}, {"id": "ball", "min_age": 3}]
	for age in range(4, 13):
		result.append({"id": "age-%d" % age, "min_age": age})
	return result


func _fixture(words: Array = []) -> Dictionary:
	var storage := Storage.new()
	var state := State.new("user://unused-growth-test.cfg", storage)
	check(state.configure(_words() if words.is_empty() else words), "Configure a distinct curriculum")
	check(state.load_state(), "Load a fresh single-player learner")
	return {"state": state, "storage": storage}


func _practice(state, id: String, prefix: String = "learn") -> void:
	for index in range(State.MASTERY_STREAK):
		var result: Dictionary = state.record_attempt("%s-%s-%d" % [prefix, id, index], [id], true)
		check(result.accepted and result.save_ok, "Save accepted practice for " + id)


func _saved(saved_level: Variant = 3, values: Variant = {}, receipts: Variant = [], version: Variant = 1) -> String:
	var config := ConfigFile.new()
	config.set_value("growth", "version", version)
	config.set_value("growth", "level", saved_level)
	config.set_value("growth", "streaks", values)
	config.set_value("growth", "receipts", receipts)
	return config.encode_to_text()


func _test_streaks_and_receipts() -> void:
	var fixture: Dictionary = _fixture()
	var state = fixture.state
	check(state.level == 3 and state.streak("apple") == 0 and not state.completed, "Every fresh learner starts at Lv3")
	check(fixture.storage.writes == 0, "Reading default progress does not write an empty save")
	for index in range(5):
		state.record_attempt("correct-%d" % index, ["apple", "apple"], true)
	check(state.streak("apple") == 5 and not state.is_mastered("apple"), "Five answers are practice; repeated tokens count once")
	var duplicate: Dictionary = state.record_attempt("correct-4", ["apple"], false)
	check(duplicate.duplicate and state.streak("apple") == 5, "A receipt cannot replay with a changed outcome")
	state.record_attempt("wrong", ["apple", "ball"], false)
	check(state.streak("apple") == 0, "A wrong answer resets a five-answer streak")
	_practice(state, "apple")
	check(state.is_mastered("apple") and state.level == 3, "Six consecutive answers master a word, not the whole tier")
	state.record_attempt("extra", ["apple"], true)
	check(state.streak("apple") == 6, "Mastery saturates at six")
	state.record_attempt("mastered-wrong", ["apple"], false)
	check(not state.is_mastered("apple") and state.streak("apple") == 0, "A later wrong answer removes word mastery")
	var reloaded := State.new("user://unused-growth-test.cfg", fixture.storage)
	reloaded.configure(_words())
	check(reloaded.load_state(), "Reload accepted learning progress")
	check(reloaded.record_attempt("extra", ["apple"], true).duplicate and reloaded.streak("apple") == 0,
		"Durable receipts prevent an old correct event from undoing a later mistake")
	check(state.snapshot().total == 2 and state.snapshot().total_words == 11, "Snapshot separates current cohort and total curriculum")
	var snapshot: Dictionary = state.snapshot()
	snapshot.streaks["ball"] = 6
	check(state.streak("ball") == 0, "Snapshots cannot mutate saved progress")


func _test_levels() -> void:
	var fixture: Dictionary = _fixture()
	var state = fixture.state
	var future: Dictionary = state.record_attempt("future-before-unlock", ["age-4"], true)
	check(future.save_ok and future.ignored and state.streak("age-4") == 0, "Future vocabulary cannot be ground before unlock")
	_practice(state, "apple")
	for index in range(5):
		state.record_attempt("ball-%d" % index, ["ball"], true)
	var upgrade: Dictionary = state.record_attempt("ball-final", ["ball"], true)
	check(upgrade.leveled_up and upgrade.previous_level == 3 and upgrade.level == 4, "The last required mastered word unlocks Lv4")
	check(state.record_attempt("future-before-unlock", ["age-4"], true).duplicate and state.streak("age-4") == 0,
		"A previously ineligible event cannot be replayed after unlock")
	state.record_attempt("past-wrong", ["apple"], false)
	check(state.level == 4 and state.streak("apple") == 0, "Lost earlier mastery never takes away an earned level")
	state.record_attempt("past-correct", ["apple"], true)
	check(state.streak("apple") == 1, "Earlier vocabulary remains eligible for practice")
	for age in range(4, 12):
		_practice(state, "age-%d" % age)
		check(state.level == age + 1, "Unlock exactly the next age after its cohort is mastered")
	check(state.level == 12 and not state.completed, "Lv12+ still has its own vocabulary to master")
	_practice(state, "age-12")
	check(state.level == 12 and state.completed and state.snapshot().progress == 1.0, "Complete Lv12+ without inventing Lv13")
	state.record_attempt("final-wrong", ["age-12"], false)
	check(state.level == 12 and not state.completed, "Final mastery can need review without demotion")
	var restored := State.new("user://unused-growth-test.cfg", fixture.storage)
	restored.configure(_words())
	check(restored.load_state() and restored.level == 12, "Permanently earned level survives reload after earlier resets")
	var sparse: Dictionary = _fixture([{"id": "only", "min_age": 3}, {"id": "later", "min_age": 5}])
	_practice(sparse.state, "only")
	check(sparse.state.level == 4 and sparse.state.snapshot().total == 0, "An empty tier cannot auto-unlock")
	sparse.state.record_attempt("empty-no-skip", ["only"], true)
	check(sparse.state.level == 4, "Reviewing past words cannot skip an empty tier")


func _test_pending_order() -> void:
	var fixture: Dictionary = _fixture()
	var state = fixture.state
	state.record_attempt("saved-first", ["apple"], true)
	var saved: String = fixture.storage.text
	fixture.storage.writable = false
	var failed: Dictionary = state.record_attempt("pending-correct", ["apple"], true)
	check(failed.accepted and not failed.save_ok and failed.pending_count == 1, "A failed accepted answer remains queued")
	check(state.streak("apple") == 1 and fixture.storage.text == saved, "Failed writes preserve durable counts and storage")
	check(state.record_attempt("pending-correct", ["apple"], true).duplicate and state.snapshot().pending_count == 1,
		"An unsaved receipt cannot be enqueued twice")
	state.record_attempt("pending-wrong", ["apple"], false)
	state.record_attempt("pending-after-wrong", ["apple"], true)
	check(state.snapshot().pending_count == 3 and state.streak("apple") == 1, "Several failed answers stay ordered and visibly pending")
	check(not state.load_state() and state.snapshot().pending_count == 3, "Reload cannot silently discard pending answers")
	fixture.storage.writable = true
	var recovered: Dictionary = state.retry_pending()
	check(recovered.save_ok and recovered.pending_count == 0 and state.streak("apple") == 1,
		"Retry replays correct, wrong, correct in their original order")
	check(state.record_attempt("pending-wrong", ["apple"], false).duplicate and state.streak("apple") == 1,
		"Retry saves the outcome and all receipts together")
	_practice(state, "apple", "finish-apple")
	for index in range(5):
		state.record_attempt("pending-upgrade-%d" % index, ["ball"], true)
	fixture.storage.writable = false
	state.record_attempt("upgrade-final", ["ball"], true)
	state.record_attempt("queued-future", ["age-4"], true)
	check(state.level == 3, "A failed promotion is not shown as already saved")
	fixture.storage.writable = true
	var promoted: Dictionary = state.retry_pending()
	check(promoted.leveled_up and state.level == 4 and state.streak("age-4") == 0,
		"Retry promotes once but cannot retroactively credit future words")
	check(not state.retry_pending().leveled_up, "Empty retries never repeat promotion")
	fixture.storage.writable = false
	state.record_attempt("later-failure", ["age-4"], true)
	fixture.storage.writable = true
	state.record_attempt("later-success", ["age-4"], true)
	check(state.streak("age-4") == 2 and state.snapshot().pending_count == 0, "A successful later attempt also saves earlier pending answers")


func _two_tabs(saved: Variant = null) -> Dictionary:
	var shared: Dictionary = {"text": saved}
	var first_host := Storage.new(shared)
	var second_host := Storage.new(shared)
	var first := State.new("user://unused-growth-test.cfg", first_host)
	var second := State.new("user://unused-growth-test.cfg", second_host)
	check(first.configure(_words()) and first.load_state(), "The first tab loads the shared durable learner")
	check(second.configure(_words()) and second.load_state(), "The second host instance loads the same initial learner")
	return {"first": first, "second": second, "first_host": first_host, "second_host": second_host, "shared": shared}


func _test_concurrent_hosts() -> void:
	var tabs: Dictionary = _two_tabs()
	check(tabs.first.record_attempt("tab-a-apple", ["apple"], true).save_ok,
		"The first tab saves its accepted word")
	check(tabs.second.record_attempt("tab-b-ball", ["ball"], true).save_ok
		and tabs.second.streak("apple") == 1 and tabs.second.streak("ball") == 1,
		"A stale tab rebases a disjoint word instead of replacing another tab's credit")
	check(tabs.first.record_attempt("tab-a-next", ["apple"], true).save_ok
		and tabs.first.streak("apple") == 2 and tabs.first.streak("ball") == 1,
		"The first tab also rebases when the other tab has written since its last answer")
	var writes_before: int = tabs.second_host.writes
	var duplicate: Dictionary = tabs.second.record_attempt("tab-a-next", ["apple"], false)
	check(duplicate.duplicate and duplicate.save_ok and tabs.second.streak("apple") == 2
		and tabs.second_host.writes == writes_before,
		"A receipt learned from another tab rejects a changed duplicate without writing")
	tabs.first.record_attempt("tab-a-wrong", ["apple"], false)
	duplicate = tabs.second.record_attempt("tab-a-next", ["apple"], true)
	check(duplicate.duplicate and tabs.second.streak("apple") == 0,
		"A cached duplicate refreshes the newer durable reset without reviving its old credit")

	tabs = _two_tabs(_saved(3, {"apple": 6, "ball": 1}))
	tabs.first.record_attempt("mastery-reset", ["apple"], false)
	check(tabs.second.record_attempt("other-word", ["ball"], true).save_ok
		and tabs.second.streak("apple") == 0 and tabs.second.streak("ball") == 2,
		"Rebasing uses the newer wrong reset instead of maximum stale mastery")
	tabs.first.record_attempt("apple-relearn", ["apple"], true)
	check(tabs.second.record_attempt("stale-wrong", ["apple"], false).save_ok
		and tabs.second.streak("apple") == 0,
		"A newly accepted wrong answer resets the current shared streak")

	tabs = _two_tabs(_saved(3, {"apple": 6, "ball": 5}))
	check(tabs.first.record_attempt("promote", ["ball"], true).leveled_up and tabs.first.level == 4,
		"One tab durably earns the next level")
	var premature: Dictionary = tabs.second.record_attempt("old-tab-future", ["age-4"], true)
	check(premature.save_ok and premature.ignored and tabs.second.level == 4 and tabs.second.streak("age-4") == 0,
		"An event captured before this tab learned of promotion remains ineligible after rebase")
	check(tabs.second.record_attempt("post-promotion-wrong", ["apple"], false).save_ok
		and tabs.second.level == 4 and tabs.second.streak("apple") == 0,
		"A stale lower-level tab cannot roll back another tab's earned promotion")
	tabs.first.record_attempt("after-promotion-review", ["ball"], true)
	var restored := State.new("user://unused-growth-test.cfg", Storage.new(tabs.shared))
	check(restored.configure(_words()) and restored.load_state() and restored.level == 4
		and restored.streak("apple") == 0 and restored.streak("age-4") == 0,
		"Promotion, wrong resets and original event eligibility survive a separate reload")
	check(restored.record_attempt("old-tab-future", ["age-4"], true).duplicate
		and restored.streak("age-4") == 0,
		"Replaying the earlier future event after unlock still cannot grant credit")


func _test_concurrent_pending() -> void:
	var tabs: Dictionary = _two_tabs(_saved(3, {"apple": 2, "ball": 1}))
	tabs.second_host.writable = false
	tabs.second.record_attempt("queued-correct", ["apple"], true)
	tabs.second.record_attempt("queued-wrong", ["apple"], false)
	tabs.second.record_attempt("queued-retry", ["apple"], true)
	check(tabs.second.streak("apple") == 2 and tabs.second.snapshot().pending_count == 3,
		"A blocked tab keeps FIFO answers pending without publishing unsaved progress")
	tabs.first.record_attempt("other-ball", ["ball"], true)
	tabs.first.record_attempt("other-apple", ["apple"], true)
	var latest: String = tabs.shared.text
	check(not tabs.second.retry_pending().save_ok and tabs.shared.text == latest
		and tabs.second.snapshot().pending_count == 3,
		"Blocked retries preserve the other tab's newer save and every pending answer")
	tabs.second_host.writable = true
	check(tabs.second.retry_pending().save_ok and tabs.second.streak("apple") == 1
		and tabs.second.streak("ball") == 2 and tabs.second.snapshot().pending_count == 0,
		"A recovered tab rebases its correct-wrong-correct queue in order over newer saved words")
	check(tabs.second.record_attempt("queued-wrong", ["apple"], false).duplicate
		and tabs.second.streak("apple") == 1,
		"All queued receipts persist together and cannot replay the middle reset")
	check(tabs.first.retry_pending().save_ok and tabs.first.streak("apple") == 1
		and tabs.first.streak("ball") == 2,
		"An explicit retry with no local queue refreshes another tab's durable progress")

	tabs.second_host.writable = false
	tabs.second.record_attempt("after-corruption", ["apple"], true)
	latest = tabs.shared.text
	tabs.shared.text = "unreadable external save"
	tabs.second_host.writable = true
	check(not tabs.second.retry_pending().save_ok and tabs.shared.text == "unreadable external save"
		and tabs.second.snapshot().pending_count == 1 and tabs.second.streak("apple") == 1,
		"A newly invalid shared save is not overwritten and cannot discard a queued event")
	tabs.shared.text = latest
	check(tabs.second.retry_pending().save_ok and tabs.second.streak("apple") == 2,
		"Retry succeeds once the latest shared save can be validated again")


func _test_save_conflict() -> void:
	var tabs: Dictionary = _two_tabs()
	tabs.first_host.before_write = func() -> void:
		tabs.second.record_attempt("intervening-ball", ["ball"], true)
	check(tabs.first.record_attempt("conflicting-apple", ["apple"], true).save_ok
		and tabs.first.streak("apple") == 1 and tabs.first.streak("ball") == 1,
		"A save changed between read and comparison is reloaded and rebased synchronously")
	check(tabs.first_host.writes == 2 and tabs.second_host.writes == 1,
		"An intervening writer causes one bounded comparison retry without duplicate credit")
	check(tabs.second.retry_pending().save_ok and tabs.second.streak("apple") == 1,
		"Both host instances converge to the same saved answers after the conflict")


func _test_invalid_input() -> void:
	var fixture: Dictionary = _fixture()
	var state = fixture.state
	for arguments in [["", ["apple"]], ["x".repeat(257), ["apple"]], ["empty", []], ["unknown", ["ghost"]], ["mixed", ["apple", "ghost"]]]:
		check(not state.record_attempt(arguments[0], arguments[1], true).accepted, "Reject malformed answer atomically")
	check(state.streak("apple") == 0 and fixture.storage.writes == 0, "Invalid input never partially credits a known word")
	for vocabulary in [[], [{"id": "bad", "min_age": 2}], [{"id": "bad", "min_age": 13}], [{"id": "bad", "min_age": 3.5}],
		[{"id": "", "min_age": 3}], [{"id": "same", "min_age": 3}, {"id": "same", "min_age": 4}]]:
		check(not State.new().configure(vocabulary), "Reject an invalid curriculum")
	check(State.new().configure([{"id": "parsed-number", "min_age": 3.0}]), "Whole JSON numbers are accepted as ages")


func _test_invalid_saves() -> void:
	for invalid in [false, "not a config", _saved(2), _saved(13), _saved(3.5), _saved(3, {"ghost": 2}),
		_saved(3, {"apple": -1}), _saved(3, {"apple": 7}), _saved(3, {"apple": 2.5}), _saved(3, {"age-4": 1}),
		_saved(3, []), _saved(3, {}, ["same", "same"]), _saved(3, {}, [""]), _saved(3, {}, [8]), _saved(3, {}, [], 999)]:
		var storage := Storage.new()
		storage.text = invalid
		var state := State.new("user://unused-growth-test.cfg", storage)
		state.configure(_words())
		check(not state.load_state() and not state.ready, "Reject malformed saved learning progress")
		check(storage.text == invalid and storage.writes == 0, "Invalid saves are never replaced by an empty learner")
	var unreadable := Storage.new()
	unreadable.readable = false
	var blocked := State.new("user://unused-growth-test.cfg", unreadable)
	blocked.configure(_words())
	check(not blocked.load_state() and not blocked.record_attempt("blocked", ["apple"], true).accepted,
		"Unreadable storage cannot accept untracked practice")


func _test_native_recovery() -> void:
	var path: String = _root.path_join("native.cfg")
	var state := State.new(path)
	state.configure(_words())
	check(state.load_state(), "Missing native save loads the Lv3 default")
	check(state.record_attempt("native-first", ["apple"], true).save_ok, "Save an answer through atomic native storage")
	check(FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".pending"), "Atomic save promotes its staged file")
	check(DirAccess.rename_absolute(path, path + ".previous") == OK, "Simulate an interrupted file replacement")
	var restored := State.new(path)
	restored.configure(_words())
	check(restored.load_state() and restored.streak("apple") == 1, "Recover the previous complete native transaction")
	check(restored.record_attempt("native-first", ["apple"], true).duplicate, "Native receipt survives transaction recovery")
	var unavailable := State.new(_root.path_join("missing-folder").path_join("save.cfg"))
	unavailable.configure(_words())
	check(unavailable.load_state(), "A fresh learner may have a currently unavailable write location")
	check(not unavailable.record_attempt("native-failure", ["apple"], true).save_ok \
		and unavailable.streak("apple") == 0 and unavailable.snapshot().pending_count == 1,
		"A native save failure retains the accepted event without granting unsaved mastery")


func _test_receipt_bound() -> void:
	var fixture: Dictionary = _fixture()
	var receipts: Array = []
	for index in range(State.MAX_RECEIPTS):
		receipts.append("receipt-%d" % index)
	fixture.storage.text = _saved(3, {}, receipts)
	check(fixture.state.load_state(), "Load a bounded full receipt history")
	check(fixture.state.record_attempt("latest", ["apple"], true).save_ok, "New progress rotates the bounded receipt history")
	var config := ConfigFile.new()
	config.parse(fixture.storage.text)
	var saved: Array = config.get_value("growth", "receipts")
	check(saved.size() == State.MAX_RECEIPTS and saved[0] == "receipt-1" and saved.back() == "latest",
		"Only the oldest receipt is evicted when history is full")


func _test_match_events() -> void:
	var model := MatchModel.new()
	var events: Array = []
	model.word_attempted.connect(func(id: String, words: Array[String], correct: bool) -> void:
		events.append({"id": id, "words": words, "correct": correct}))
	model.cards.assign([
		{"id": "apple:word", "kind": "word", "word": {"id": "apple"}},
		{"id": "apple:image", "kind": "image", "word": {"id": "apple"}},
		{"id": "ball:word", "kind": "word", "word": {"id": "ball"}},
		{"id": "ball:image", "kind": "image", "word": {"id": "ball"}}
	])
	model.select("apple:word")
	model.select("ball:word")
	model.select("ball:word")
	check(events.is_empty(), "First selection, same-kind reselection and cancellation are not attempts")
	model.select("apple:word")
	model.select("ball:image")
	check(events.size() == 1 and not events[0].correct and events[0].words == ["apple", "ball"], "A wrong Match pair reports both involved words once")
	model.resolve_feedback()
	model.match_spoken_word("apple")
	check(events.size() == 2 and events[1].correct and events[1].words == ["apple"], "Speech matching uses the same authoritative attempt hook")
	model.select("apple:image")
	check(events.size() == 2 and events[0].id != events[1].id, "Repeated or feedback-locked selections cannot duplicate a Match event")


func _speech_event(game, target: Dictionary, id: String, text: String, stage: String = "final") -> Dictionary:
	return {"event_id": id, "round_id": game.round_id, "target_uid": target.uid,
		"text": text, "stage": stage, "received_at_ms": 120.0}


func _test_pop_events() -> void:
	var game := PopModel.new()
	var events: Array = []
	game.word_attempted.connect(func(id: String, words: Array[String], correct: bool) -> void:
		events.append({"id": id, "words": words, "correct": correct}))
	game.configure([{"id": "apple", "text": "apple", "image": "apple.svg", "audio": "apple.wav"}], 1)
	game.start()
	var target: Dictionary = game.targets[0].duplicate(true)
	game.hit_speech_event(_speech_event(game, target, "interim-wrong", "ball", "interim"))
	game.hit_speech_event(_speech_event(game, target, "empty", ""))
	var unbound: Dictionary = _speech_event(game, target, "unbound", "ball")
	unbound.target_uid = 0
	game.hit_speech_event(unbound)
	check(events.is_empty(), "Unclear, unbound and interim speech do not reset mastery")
	var wrong: Dictionary = _speech_event(game, target, "wrong", "ball")
	game.hit_speech_event(wrong)
	game.hit_speech_event(wrong)
	check(events.size() == 1 and not events[0].correct and events[0].words == ["apple"], "An explicit final target-bound wrong answer is emitted once")
	var hit: Dictionary = _speech_event(game, target, "hit", "apple", "interim")
	game.hit_speech_event(hit)
	hit.stage = "final"
	game.hit_speech_event(hit)
	check(events.size() == 2 and events[1].correct and events[0].id != events[1].id, "Interim and final recognition cannot double-credit a pop")
	game.advance(7.0)
	game.pause()
	game.advance(20.0)
	game.stop()
	check(events.size() == 2, "Unattended expiry, pauses and exiting are not wrong answers")
	game.start()
	game.hit_speech_event(hit)
	check(events.size() == 2, "An old speech round cannot credit a new target")
	game.hit_transcript("apple")
	check(events.size() == 3 and events[2].correct, "The legacy native transcript path also records accepted hits")


func _test_phrase_events() -> void:
	var phrase := PhraseGame.new()
	root.add_child(phrase)
	phrase.size = Vector2(800, 500)
	phrase.set_reduced_motion(true)
	phrase._configured = true
	phrase.game.questions.assign([{"id": "red-apple", "words": ["red", "apple"], "text": "red apple", "audio": "unused.wav"}])
	phrase.game.options.assign([
		{"id": "red", "text": "red", "image": "assets/images/words/apple.svg"},
		{"id": "apple", "text": "apple", "image": "assets/images/words/apple.svg"},
		{"id": "ball", "text": "ball", "image": "assets/images/words/ball.svg"}
	])
	phrase.game.phase = "building"
	var events: Array = []
	phrase.word_attempted.connect(func(id: String, words: Array[String], correct: bool) -> void:
		events.append({"id": id, "words": words, "correct": correct}))
	phrase._activate()
	check(events.is_empty(), "An incomplete phrase cannot reset a word")
	phrase.game.answer.assign([0, 2])
	phrase._activate()
	check(events.size() == 1 and not events[0].correct and events[0].words == ["red", "apple", "ball"],
		"A wrong phrase reports the target and deliberately submitted distractor")
	phrase.game.answer.assign([0, 1])
	phrase._activate()
	check(events.size() == 2 and events[1].correct and events[1].words == ["red", "apple"],
		"A correct phrase credits its target words once")
	phrase._activate()
	check(events.size() == 2, "Repeated confirmation during phrase celebration cannot credit the same answer")
	phrase.queue_free()
	await process_frame

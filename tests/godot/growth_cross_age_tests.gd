extends SceneTree
## Cross-age Jelly practice persists without weakening other games' age gates.

const State = preload("res://scripts/growth_state.gd")

var checks: int = 0
var failures: int = 0


class Storage extends RefCounted:
	var backing: Dictionary
	var writable: bool = true
	var writes: int = 0
	var before_write: Callable
	var text: Variant:
		get:
			return backing.text
		set(value):
			backing.text = value

	func _init(shared: Dictionary = {}) -> void:
		backing = shared if not shared.is_empty() else {"text": null}

	func growthState() -> Variant:
		return text

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


func _words() -> Array:
	return [{"id": "apple", "min_age": 3}, {"id": "ball", "min_age": 3},
		{"id": "age-4", "min_age": 4}, {"id": "age-5", "min_age": 5},
		{"id": "age-12", "min_age": 12}]


func _state(storage: Storage):
	var state := State.new("user://unused-growth-cross-age.cfg", storage)
	check(state.configure(_words()), "Configure a curriculum spanning ages")
	check(state.load_state(), "Load a learner without changing its vocabulary")
	return state


func _practice(state, word: String, prefix: String, cross_age: bool = true) -> void:
	for index in range(State.MASTERY_STREAK):
		var result: Dictionary = state.record_attempt("%s-%d" % [prefix, index], [word], true, cross_age)
		check(result.accepted and result.save_ok and not result.get("ignored", false),
			"Persist each eligible answer exactly once")


func _saved(version: int, values: Dictionary = {}, mastered: Array = [], receipts: Array = []) -> String:
	var config := ConfigFile.new()
	config.set_value("growth", "version", version)
	config.set_value("growth", "level", State.level_for_mastered(mastered.size()))
	config.set_value("growth", "age", 0)
	config.set_value("growth", "streaks", values)
	config.set_value("growth", "mastered_words", mastered)
	config.set_value("growth", "receipts", receipts)
	return config.encode_to_text()


func _run() -> void:
	_test_opt_in_and_reload()
	_test_age_progression()
	_test_schema_upgrade()
	_test_saved_validation()
	_test_pending_answers()
	_test_concurrent_writers()
	_test_native_reload()
	print("Cross-age growth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_opt_in_and_reload() -> void:
	var storage := Storage.new()
	var state = _state(storage)
	var ignored: Dictionary = state.record_attempt("ordinary-future", ["age-12"], true)
	check(ignored.save_ok and ignored.ignored and state.streak("age-12") == 0,
		"Existing games cannot practice future words without explicit opt-in")
	check(state.record_attempt("ordinary-future", ["age-12"], true, true).duplicate
		and state.streak("age-12") == 0, "Replaying an ignored receipt with opt-in cannot grant credit")
	state.record_attempt("jelly-mixed", ["apple", "age-12", "age-12"], true, true)
	check(state.streak("apple") == 1 and state.streak("age-12") == 1,
		"A cross-age answer credits known words across cohorts and deduplicates IDs")
	state.record_attempt("jelly-second", ["age-12"], true, true)
	state.record_attempt("jelly-third", ["age-12"], true, true)
	check(state.is_mastered("age-12") and state.level == 1 and state.age == 0,
		"Future mastery grants earned experience without skipping unfinished ages")
	var saved := ConfigFile.new()
	check(saved.parse(storage.text) == OK and saved.get_value("growth", "version") == 4,
		"Cross-age evidence is written in the supported durable schema")
	var reloaded = _state(storage)
	check(reloaded.is_mastered("age-12") and reloaded.streak("apple") == 1 and reloaded.age == 0,
		"Future mastery and earlier partial practice survive reload")
	check(reloaded.record_attempt("jelly-third", ["age-12"], false, true).duplicate
		and reloaded.is_mastered("age-12"), "Reload preserves cross-age receipt protection")
	ignored = reloaded.record_attempt("ordinary-future-wrong", ["age-12"], false)
	check(ignored.ignored and reloaded.is_mastered("age-12"),
		"Loading future evidence does not enable other games to assess future words")
	reloaded.record_attempt("jelly-future-wrong", ["age-12"], false, true)
	check(not reloaded.is_mastered("age-12") and reloaded.level == 1,
		"An explicit cross-age mistake resets current mastery and preserves earned level")
	var after_reset = _state(storage)
	check(not after_reset.is_mastered("age-12") and after_reset.snapshot().lifetime_mastered == 1,
		"A future word's earned history survives reload after its streak resets")
	var before: String = storage.text
	check(not after_reset.record_attempt("unknown", ["apple", "ghost"], true, true).accepted
		and storage.text == before, "Cross-age opt-in still rejects unknown words atomically")


func _test_age_progression() -> void:
	var state = _state(Storage.new())
	_practice(state, "age-4", "early-four")
	_practice(state, "age-5", "early-five")
	check(state.age == 0 and state.snapshot().lifetime_mastered == 2,
		"Mastering later cohorts leaves the unfinished first cohort in place")
	_practice(state, "apple", "ordinary-apple", false)
	_practice(state, "ball", "ordinary-ball", false)
	check(state.age == 5 and state.learning_age() == 6 and not state.completed,
		"Finishing earlier words recognizes already-mastered contiguous cohorts")
	check(state.snapshot().lifetime_mastered == 4,
		"Cross-age mastery contributes once to the same Pip experience history")


func _test_schema_upgrade() -> void:
	var storage := Storage.new()
	storage.text = _saved(3, {"apple": 3, "ball": 2}, ["apple"], ["existing-answer"])
	var before: String = storage.text
	storage.writable = false
	var state := State.new("user://unused-growth-cross-age.cfg", storage)
	state.configure(_words())
	check(not state.load_state() and not state.ready and storage.text == before,
		"A blocked schema upgrade preserves the original save and publishes no state")
	storage.writable = true
	check(state.load_state() and state.level == 1 and state.age == 0
		and state.streak("apple") == 3 and state.streak("ball") == 2,
		"Schema three migrates without treating its three-answer mastery as legacy six")
	var saved := ConfigFile.new()
	saved.parse(storage.text)
	check(saved.get_value("growth", "version") == State.VERSION,
		"Existing learners are migrated durably before they may practice")
	var writes: int = storage.writes
	check(state.load_state() and storage.writes == writes,
		"Reloading the upgraded schema does not rewrite it")
	check(state.record_attempt("existing-answer", ["ball"], true, true).duplicate
		and state.streak("ball") == 2, "Schema migration retains existing answer receipts")


func _test_saved_validation() -> void:
	for text in [_saved(3, {"age-12": 1}), _saved(3, {}, ["age-12"]),
		_saved(3, {"apple": 6}, ["apple"]), _saved(4, {"age-12": 4}, ["age-12"]),
		_saved(4, {"age-12": 3}), _saved(4, {}, ["ghost"]), _saved(4, {"ghost": 1}),
		_saved(4, {}, ["age-12", "age-12"]), _saved(4, {"age-12": 1}, [], ["same", "same"])]:
		var storage := Storage.new()
		storage.text = text
		var state := State.new("user://unused-growth-cross-age.cfg", storage)
		state.configure(_words())
		check(not state.load_state() and not state.ready and storage.text == text and storage.writes == 0,
			"Reject corrupt historical or current saves without replacing evidence")
	var storage := Storage.new()
	storage.text = _saved(4, {"age-12": 2})
	var state = _state(storage)
	check(state.streak("age-12") == 2 and not state.is_mastered("age-12"),
		"A current save can retain an unfinished cross-age streak")
	state.record_attempt("finish-reloaded", ["age-12"], true, true)
	check(state.is_mastered("age-12") and state.level == 1,
		"Reloaded cross-age practice completes at the normal mastery threshold")


func _test_pending_answers() -> void:
	var storage := Storage.new()
	var state = _state(storage)
	storage.writable = false
	state.record_attempt("pending-first", ["age-12"], true, true)
	state.record_attempt("pending-second", ["age-12"], true, true)
	state.record_attempt("pending-default", ["age-12"], true)
	state.record_attempt("pending-reset", ["age-12"], false, true)
	state.record_attempt("pending-final", ["age-12"], true, true)
	check(state.streak("age-12") == 0 and state.snapshot().pending_count == 5 and storage.text == null,
		"Failed storage retains every ordered event without publishing mastery")
	storage.writable = true
	check(state.retry_pending().save_ok and state.streak("age-12") == 1
		and state.snapshot().pending_count == 0,
		"Retry preserves cross-age eligibility and correct-reset-correct ordering")
	check(state.record_attempt("pending-default", ["age-12"], true, true).duplicate
		and state.streak("age-12") == 1, "An ignored pending event stays ineligible after retry")
	var reloaded = _state(storage)
	check(reloaded.streak("age-12") == 1
		and reloaded.record_attempt("pending-reset", ["age-12"], false, true).duplicate,
		"Queued cross-age receipts and their final streak survive reload")


func _test_concurrent_writers() -> void:
	var shared := {"text": null}
	var first_storage := Storage.new(shared)
	var second_storage := Storage.new(shared)
	var first = _state(first_storage)
	var second = _state(second_storage)
	_practice(first, "age-12", "first-tab")
	check(second.record_attempt("second-tab-apple", ["apple"], true).save_ok
		and second.is_mastered("age-12") and second.streak("apple") == 1,
		"Ordinary age-scoped writers rebase over another tab's future mastery")
	first_storage.before_write = func() -> void:
		second.record_attempt("concurrent-ball", ["ball"], true)
	check(first.record_attempt("concurrent-four", ["age-4"], true, true).save_ok
		and first.streak("age-4") == 1 and first.streak("ball") == 1 and first.is_mastered("age-12"),
		"A comparison-write conflict retains both age-scoped and cross-age answers")
	check(second.retry_pending().save_ok and second.streak("age-4") == 1,
		"An inactive tab can refresh cross-age evidence without submitting an answer")
	second_storage.writable = false
	second.record_attempt("blocked-future-reset", ["age-12"], false, true)
	first.record_attempt("intervening-future", ["age-12"], true, true)
	second_storage.writable = true
	check(second.retry_pending().save_ok and second.streak("age-12") == 0
		and second.snapshot().lifetime_mastered == 1,
		"A queued future-word mistake rebases in order without losing earned experience")


func _test_native_reload() -> void:
	var path: String = "user://growth_cross_age_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var state := State.new(path)
	check(state.configure(_words()) and state.load_state(), "Load a distinct native learning fixture")
	_practice(state, "age-12", "native-future")
	var restored := State.new(path)
	check(restored.configure(_words()) and restored.load_state() and restored.is_mastered("age-12")
		and restored.age == 0, "Native atomic storage reloads future mastery without advancing Pip's age")
	check(DirAccess.remove_absolute(path) == OK, "Remove the native cross-age fixture")

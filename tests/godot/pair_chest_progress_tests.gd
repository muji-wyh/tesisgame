extends SceneTree

const Progress = preload("res://scripts/medal_progress.gd")

var checks: int = 0
var failures: int = 0
var _fixture_count: int = 0


class BrowserStorage extends RefCounted:
	var text: Variant = "[medals]\nversion=1\ncounts={}\n"
	var writable: bool = true
	var save_calls: int = 0
	var read_calls: int = 0
	var replace_on_read: int = -1
	var replacement: Variant = null

	func medalProgress() -> Variant:
		read_calls += 1
		if read_calls == replace_on_read:
			text = replacement
		return text

	func saveMedalProgress(value: String) -> bool:
		save_calls += 1
		if not writable:
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


func _fixture() -> Dictionary:
	_fixture_count += 1
	var path: String = "user://pair-chest-progress-%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), _fixture_count]
	var storage := BrowserStorage.new()
	var progress := Progress.new(path + ".cfg", path + "-legacy.cfg", storage)
	check(progress.load_progress(), "Load isolated pair chest fixture")
	return {"storage": storage, "progress": progress, "path": path}


func _reload(fixture: Dictionary):
	var progress := Progress.new(fixture.path + ".cfg", fixture.path + "-legacy.cfg", fixture.storage)
	check(progress.load_progress(), "Reload pair chest progress from the same atomic record")
	return progress


func _run() -> void:
	_test_old_save_and_validation()
	_test_reservation_and_guarantee()
	_test_earned_reward_recovery()
	_test_write_failures()
	_test_stale_browser_tabs()
	_test_empty_browser_migration()
	_test_completed_season_and_claims()
	_test_invalid_saved_state()
	print("Pair chest progress: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_old_save_and_validation() -> void:
	var fixture: Dictionary = _fixture()
	var progress = fixture.progress
	check(fixture.storage.save_calls == 0, "Reading a legacy medal save does not rewrite it")
	check(progress.pair_round("match").is_empty() and progress.pair_round("memory").is_empty(),
		"Old medal saves start with no chest reservations")
	check(progress.pair_dry_rounds("match") == 0 and progress.pair_dry_rounds("memory") == 0,
		"Both modes start with independent empty dry streaks")
	check(progress.begin_pair_round("phrase", "x", 1).is_empty(), "Other modes cannot create pair reservations")
	check(progress.begin_pair_round("match", "", 1).is_empty(), "A reservation needs a stable round ID")
	check(progress.begin_pair_round("match", "x", -1).is_empty(), "Negative reveal pairs are invalid")
	check(progress.begin_pair_round("match", "x", 6).is_empty(), "Reveal pairs cannot exceed the board")
	check(not progress.record_pair_reward("match", "missing", "spring"), "A missing round cannot award a chest")
	check(not progress.finish_pair_round("match", "missing"), "A missing round cannot increase pity")
	check(not progress.settle_pair_reward("match", "missing"), "A missing round cannot award medal contents")
	check(fixture.storage.save_calls == 0, "Rejected operations leave the durable save untouched")
	var started: Dictionary = progress.begin_pair_round("match", "copy", 2)
	started.pair = 5
	check(progress.pair_round("match").pair == 2, "Returned reservation dictionaries are defensive copies")
	var copy: Dictionary = progress.pair_round("match")
	copy.fragment["medal_id"] = "summer-1"
	check(progress.pair_round("match").fragment.is_empty(), "Nested returned state cannot mutate a reservation")
	check(not progress.record_pair_reward("match", "copy", "unknown"), "An invalid chest theme is rejected")


func _test_reservation_and_guarantee() -> void:
	var fixture: Dictionary = _fixture()
	var progress = fixture.progress
	check(progress.begin_pair_round("match", "m1", 0).pair == 0, "A proposed dry round is reserved")
	var writes: int = fixture.storage.save_calls
	check(progress.begin_pair_round("match", "m1", 5).pair == 0 and fixture.storage.save_calls == writes,
		"Repeated setup neither rerolls nor writes the same round")
	check(progress.begin_pair_round("match", "m1-restarted", 4).pair == 0,
		"Restarting an unfinished round preserves its dry outcome")
	check(progress.pair_dry_rounds("match") == 0, "Abandoning a dry round does not increase pity")
	check(not progress.finish_pair_round("match", "m1"), "A callback from the replaced round is rejected")
	check(progress.finish_pair_round("match", "m1-restarted"), "A completed dry round is saved")
	check(progress.pair_dry_rounds("match") == 1, "The first dry completion increases its mode's streak once")
	writes = fixture.storage.save_calls
	check(progress.finish_pair_round("match", "m1-restarted") and fixture.storage.save_calls == writes,
		"Repeated completion is idempotent")
	check(progress.pair_dry_rounds("memory") == 0, "Match does not change Memory's streak")
	check(progress.begin_pair_round("memory", "v1", 4).pair == 4,
		"Memory retains an independently proposed successful pair")
	check(progress.begin_pair_round("match", "m2", 0).pair == 0, "A second dry round is allowed")
	check(progress.finish_pair_round("match", "m2") and progress.pair_dry_rounds("match") == 2,
		"Two completed dry rounds establish the guarantee")
	progress = _reload(fixture)
	check(progress.begin_pair_round("match", "m3", 0).pair == 1,
		"The third round must drop a chest even when the proposal is dry")
	check(progress.begin_pair_round("memory", "v1-restarted", 0).pair == 4,
		"A reload preserves a positive reservation and its reveal pair")
	check(not progress.finish_pair_round("match", "m3") and progress.pair_dry_rounds("match") == 2,
		"A failed or missing chest grant cannot turn a guaranteed round into a dry completion")
	check(progress.record_pair_reward("match", "m3", "spring"), "The successful pair durably earns its chest")
	check(progress.pair_dry_rounds("match") == 0 and progress.count_for("spring-1") == 0,
		"Reveal resets pity but keeps the medal contents unopened")
	check(progress.finish_pair_round("match", "m3"), "An awarded round completes normally")
	check(progress.pair_dry_rounds("match") == 0, "An awarded completion never raises the dry streak")
	check(progress.begin_pair_round("match", "m4", 1).is_empty(),
		"An unsettled chest cannot be overwritten by a new round")
	check(progress.settle_pair_reward("match", "m3"), "Chest settlement is durable")
	check(progress.begin_pair_round("match", "m4", 0).pair == 0,
		"After settlement a fresh round uses its newly proposed chance")
	check(not progress.record_pair_reward("match", "m3", "spring"),
		"A late award callback cannot grant a chest to a newer round")
	check(not progress.record_pair_reward("match", "m4", "spring"), "A dry reservation cannot award a chest")


func _test_earned_reward_recovery() -> void:
	var fixture: Dictionary = _fixture()
	var progress = fixture.progress
	progress.begin_pair_round("memory", "memory-earned", 3)
	check(progress.record_pair_reward("memory", "memory-earned", "ocean"), "A midround Memory reward is saved")
	var frozen: Dictionary = progress.pair_round("memory")
	check(frozen.awarded and not frozen.settled and not frozen.completed and frozen.theme == "ocean",
		"A pending chest records ownership independently of round completion")
	check(frozen.fragment == {"medal_id": "ocean-1", "before": 0, "after": 1, "completed": false},
		"Reward capture freezes exactly one medal fragment")
	var writes: int = fixture.storage.save_calls
	check(progress.record_pair_reward("memory", "memory-earned", "space") and fixture.storage.save_calls == writes,
		"Duplicate reveals are idempotent even after the selected theme changes")
	check(progress.pair_round("memory").theme == "ocean", "The chest retains its original theme")
	progress = _reload(fixture)
	check(progress.pair_round("memory") == frozen, "Reload restores the full pending chest")
	check(progress.settle_pair_reward("memory", "memory-earned"), "Startup can settle an earned unfinished round")
	check(progress.count_for("ocean-1") == 1 and progress.pair_round("memory").settled,
		"Medal contents and chest consumption are committed together")
	progress = _reload(fixture)
	writes = fixture.storage.save_calls
	check(progress.settle_pair_reward("memory", "memory-earned") and fixture.storage.save_calls == writes,
		"Settlement remains idempotent after a reload")
	check(progress.count_for("ocean-1") == 1, "Recovery never duplicates a medal fragment")
	check(progress.begin_pair_round("memory", "after-exit", 5).pair == 5,
		"An earned and settled interrupted round permits a fresh reservation")


func _test_write_failures() -> void:
	var fixture: Dictionary = _fixture()
	var progress = fixture.progress
	fixture.storage.writable = false
	var saved: String = fixture.storage.text
	check(progress.begin_pair_round("match", "first", 0).is_empty(), "Failed initial reservation is reported")
	check(progress.pair_round("match").is_empty() and fixture.storage.text == saved,
		"Failed initial reservation publishes no state")
	fixture.storage.writable = true
	progress.begin_pair_round("match", "first", 0)
	fixture.storage.writable = false
	check(progress.begin_pair_round("match", "rebind", 4).is_empty(), "Failed rebind is reported")
	check(progress.pair_round("match").id == "first", "Failed rebind leaves the previous callback identity intact")
	check(not progress.finish_pair_round("match", "first") and progress.pair_dry_rounds("match") == 0,
		"Failed dry completion cannot publish or count pity")
	check(not progress.pair_round("match").completed, "Failed dry completion remains retryable")
	fixture.storage.writable = true
	check(progress.finish_pair_round("match", "first"), "A dry completion retries successfully")
	progress.begin_pair_round("match", "reward", 2)
	fixture.storage.writable = false
	saved = fixture.storage.text
	check(not progress.record_pair_reward("match", "reward", "spring"), "Failed reward grant is reported")
	check(not progress.pair_round("match").awarded and progress.pair_dry_rounds("match") == 1
		and fixture.storage.text == saved, "Failed reward grant preserves the reservation, pity and save")
	fixture.storage.writable = true
	check(progress.record_pair_reward("match", "reward", "spring"), "Reward grant can retry the same reservation")
	fixture.storage.writable = false
	saved = fixture.storage.text
	check(not progress.settle_pair_reward("match", "reward"), "Failed settlement is reported")
	check(progress.count_for("spring-1") == 0 and not progress.pair_round("match").settled
		and fixture.storage.text == saved, "Failed settlement grants nothing and preserves the pending reward")
	fixture.storage.writable = true
	progress = _reload(fixture)
	check(progress.settle_pair_reward("match", "reward") and progress.count_for("spring-1") == 1,
		"A failed settlement remains recoverable after reload")


func _test_stale_browser_tabs() -> void:
	var fixture: Dictionary = _fixture()
	var progress = fixture.progress
	progress.begin_pair_round("match", "shared-round", 2)
	var stale = _reload(fixture)
	check(progress.record_pair_reward("match", "shared-round", "spring"), "The first tab saves its earned chest")
	var saved: String = fixture.storage.text
	var writes: int = fixture.storage.save_calls
	var stale_round: Dictionary = stale.pair_round("match")
	check(stale.begin_pair_round("memory", "other-tab", 0).is_empty()
		and stale.error.begins_with("Progress changed in another tab. Reload"),
		"A stale tab cannot replace an earned chest with a new reservation")
	check(not stale.record_pair_reward("match", "shared-round", "summer")
		and stale.error.begins_with("Progress changed in another tab. Reload"),
		"A stale tab cannot replace the saved chest's theme or contents")
	check(not stale.claim(stale.next_fragment("ocean")), "Ordinary medal claims also reject a stale browser snapshot")
	check(stale.pair_round("match") == stale_round and stale.pair_round("memory").is_empty()
		and stale.counts.is_empty() and fixture.storage.text == saved and fixture.storage.save_calls == writes,
		"Rejected stale writes change neither local rewards nor another tab's durable save")
	var stale_earned = _reload(fixture)
	check(progress.settle_pair_reward("match", "shared-round") and progress.count_for("spring-1") == 1,
		"Successful writes advance the first tab's comparison baseline")
	saved = fixture.storage.text
	writes = fixture.storage.save_calls
	check(not stale_earned.settle_pair_reward("match", "shared-round")
		and stale_earned.error.begins_with("Progress changed in another tab. Reload"),
		"An older earned-chest snapshot cannot overwrite its newer settlement")
	check(not stale_earned.pair_round("match").settled and stale_earned.count_for("spring-1") == 0
		and fixture.storage.text == saved and fixture.storage.save_calls == writes,
		"A rejected settlement retains its local pending chest and preserves the saved contents")
	check(stale_earned.load_progress() and stale_earned.settle_pair_reward("match", "shared-round")
		and stale_earned.count_for("spring-1") == 1 and fixture.storage.save_calls == writes,
		"Reload observes the existing settlement without duplicating the reward")
	check(not stale_earned.begin_pair_round("memory", "after-reload", 1).is_empty(),
		"Reload refreshes the baseline so new play can save again")


func _test_empty_browser_migration() -> void:
	var fixture: Dictionary = _fixture()
	fixture.storage.text = null
	var progress := Progress.new(fixture.path + ".cfg", fixture.path + "-legacy.cfg", fixture.storage)
	check(progress.load_progress() and fixture.storage.text is String and fixture.storage.save_calls == 1,
		"A missing browser record migrates from a null baseline")
	check(not progress.begin_pair_round("match", "new-browser", 1).is_empty(),
		"The first reservation compares against the newly migrated record")
	var frozen: Dictionary = progress.pair_round("match")
	var writes: int = fixture.storage.save_calls
	fixture.storage.text = null
	check(not progress.record_pair_reward("match", "new-browser", "spring")
		and progress.error.begins_with("Progress changed in another tab. Reload"),
		"Removal of an existing browser record is a conflict rather than permission to recreate it")
	check(progress.pair_round("match") == frozen and fixture.storage.text == null
		and fixture.storage.save_calls == writes, "A deleted save is not overwritten from stale memory")
	fixture.storage.text = false
	check(not progress.record_pair_reward("match", "new-browser", "spring")
		and progress.error.begins_with("Could not read browser medal progress"),
		"Unavailable browser storage fails before any write")
	check(progress.pair_round("match") == frozen and fixture.storage.save_calls == writes,
		"An unavailable read keeps the pending reservation intact")
	var racing_fixture: Dictionary = _fixture()
	var other_tab_save: String = racing_fixture.storage.text
	racing_fixture.storage.text = null
	racing_fixture.storage.replacement = other_tab_save
	racing_fixture.storage.replace_on_read = racing_fixture.storage.read_calls + 2
	var racing := Progress.new(racing_fixture.path + ".cfg", racing_fixture.path + "-legacy.cfg", racing_fixture.storage)
	check(not racing.load_progress() and racing.error.begins_with("Progress changed in another tab. Reload"),
		"Migration rejects a browser record created after its initial empty read")
	check(racing_fixture.storage.text == other_tab_save and racing_fixture.storage.save_calls == 0
		and racing.counts.is_empty() and racing.pair_round("match").is_empty(),
		"A migration conflict preserves the other tab's save without publishing partial state")


func _test_completed_season_and_claims() -> void:
	var fixture: Dictionary = _fixture()
	var progress = fixture.progress
	for index in range(18):
		check(progress.claim(progress.next_fragment("winter")), "Prepare a completed medal season")
	progress.begin_pair_round("match", "full-season", 1)
	check(progress.record_pair_reward("match", "full-season", "winter"), "Completed seasons can still earn a chest")
	check(progress.pair_round("match").fragment.is_empty(), "A completed season does not invent extra medal contents")
	check(progress.settle_pair_reward("match", "full-season") and progress.completed_count("winter") == 6,
		"A chest with no remaining medal fragment settles normally")
	progress.begin_pair_round("memory", "other-claim", 2)
	progress.record_pair_reward("memory", "other-claim", "spring")
	var reserved: Dictionary = progress.pair_round("memory")
	check(progress.claim(progress.next_fragment("summer")), "Other theme claims remain available")
	progress = _reload(fixture)
	check(progress.pair_round("memory") == reserved and progress.count_for("summer-1") == 1,
		"Ordinary medal writes preserve reserved chest state")
	check(progress.claim(progress.next_fragment("spring")), "Prepare an out-of-order external fragment claim")
	check(not progress.settle_pair_reward("memory", "other-claim") and not progress.pair_round("memory").settled,
		"An out-of-order fragment cannot silently consume a different pending chest")


func _test_invalid_saved_state() -> void:
	var fixture: Dictionary = _fixture()
	fixture.progress.begin_pair_round("match", "valid", 2)
	fixture.progress.record_pair_reward("match", "valid", "spring")
	var config := ConfigFile.new()
	check(config.parse(fixture.storage.text) == OK, "Read a valid pair chest fixture")
	var valid: Dictionary = config.get_value("pair_chests", "state")
	var scenarios: Array[Dictionary] = []
	var invalid: Dictionary = valid.duplicate(true)
	invalid.erase("memory")
	scenarios.append(invalid)
	invalid = valid.duplicate(true)
	invalid.memory.dry_rounds = 3
	scenarios.append(invalid)
	invalid = valid.duplicate(true)
	invalid.match.round.pair = 0
	scenarios.append(invalid)
	invalid = valid.duplicate(true)
	invalid.match.round.fragment.after = 2
	scenarios.append(invalid)
	invalid = valid.duplicate(true)
	invalid.match.round.theme = "summer"
	scenarios.append(invalid)
	invalid = valid.duplicate(true)
	invalid.match.round.awarded = "true"
	scenarios.append(invalid)
	for state in scenarios:
		config.set_value("pair_chests", "state", state)
		fixture.storage.text = config.encode_to_text()
		var saved: String = fixture.storage.text
		var progress := Progress.new(fixture.path + ".cfg", fixture.path + "-legacy.cfg", fixture.storage)
		check(not progress.load_progress() and not progress.error.is_empty(), "Invalid pair chest state is rejected")
		check(fixture.storage.text == saved, "Invalid saves are preserved for recovery")
		check(progress.begin_pair_round("match", "overwrite", 1).is_empty(), "Failed loads cannot overwrite saved rewards")

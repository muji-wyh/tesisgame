extends SceneTree

const Progress = preload("res://scripts/medal_progress.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")

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
	_test_memory_performance_tiers()
	_test_memory_no_guarantee()
	_test_memory_legacy_migration()
	_test_memory_write_failures()
	_test_memory_stale_tabs()
	_test_memory_completed_season()
	_test_memory_invalid_saved_state()
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


func _test_memory_performance_tiers() -> void:
	for tier: int in range(RewardProgress.THEMES.size() + 1):
		var fixture: Dictionary = _fixture()
		var progress = fixture.progress
		var id: String = "performance-%d" % tier
		var initial: Dictionary = progress.begin_memory_round(id)
		check(initial.get("policy") == Progress.MEMORY_REWARD_POLICY and initial.tier == 0
			and initial.pair == 0 and not initial.awarded and not initial.completed and not initial.settled,
			"A Memory preview does not reserve or award a chest: tier %d" % tier)
		var writes: int = fixture.storage.save_calls
		check(progress.begin_memory_round(id) == initial and fixture.storage.save_calls == writes,
			"Beginning the same Memory round is idempotent")
		initial.fragment["medal_id"] = "spring-1"
		check(progress.pair_round("memory").fragment.is_empty(), "Memory snapshots cannot mutate saved contents")
		progress = _reload(fixture)
		check(not progress.pair_round("memory").completed and not progress.pair_round("memory").awarded
			and progress.counts.is_empty(), "Reloading an unfinished preview cannot turn it into a reward")
		check(not progress.record_pair_reward("memory", id, "summer")
			and not progress.finish_pair_round("memory", id) and not progress.settle_pair_reward("memory", id)
			and fixture.storage.save_calls == writes,
			"Legacy reveal, generic completion, and exit settlement cannot earn a preview")
		check(progress.finish_memory_round(id, tier, "summer"), "Save final Memory tier %d" % tier)
		var earned: Dictionary = progress.pair_round("memory")
		check(earned.completed and earned.tier == tier and earned.awarded == (tier > 0)
			and not earned.settled and earned.pair == (5 if tier > 0 else 0),
			"Completion stores the final tier and ownership together")
		check(earned.theme == ("summer" if tier > 0 else "")
			and earned.fragment == ({"medal_id": "summer-1", "before": 0, "after": 1, "completed": false} if tier > 0 else {}),
			"The learning world owns medal contents independently of chest tier")
		check(progress.count_for("summer-1") == 0 and fixture.storage.save_calls == writes + 1,
			"Completion is one save and leaves medal contents unopened")
		writes = fixture.storage.save_calls
		check(progress.finish_memory_round(id, RewardProgress.THEMES.size() - tier, "winter") and progress.pair_round("memory") == earned
			and fixture.storage.save_calls == writes,
			"A duplicate completion cannot reroll the saved tier or medal world")
		progress = _reload(fixture)
		check(progress.pair_round("memory") == earned and progress.pair_dry_rounds("memory") == 0,
			"Reload preserves the exact Memory result without a dry streak")
		if tier > 0:
			check(progress.begin_memory_round("replacement").is_empty(), "A new round cannot discard an earned Memory chest")
			check(progress.settle_pair_reward("memory", id) and progress.count_for("summer-1") == 1,
				"Memory settlement grants one fragment regardless of coin tier")
			progress = _reload(fixture)
			writes = fixture.storage.save_calls
			check(progress.settle_pair_reward("memory", id) and progress.count_for("summer-1") == 1
				and fixture.storage.save_calls == writes, "Memory settlement remains exactly once after reload")
		else:
			check(not progress.settle_pair_reward("memory", id) and progress.counts.is_empty(),
				"Tier zero has no chest or fragment to settle")
		check(not progress.begin_memory_round("next-round").is_empty(), "A consumed or tier-zero Memory result permits a new round")
		check(not progress.finish_memory_round(id, RewardProgress.THEMES.size(), "spring"), "Late completion cannot affect a newer Memory round")


func _test_memory_no_guarantee() -> void:
	var fixture: Dictionary = _fixture()
	var progress = fixture.progress
	for index in range(2):
		var id: String = "match-dry-%d" % index
		progress.begin_pair_round("match", id, 0)
		progress.finish_pair_round("match", id)
	var match_state: Dictionary = progress.pair_round("match")
	for index in range(5):
		var id: String = "memory-dry-%d" % index
		check(not progress.begin_memory_round(id).is_empty() and progress.finish_memory_round(id, 0, "spring"),
			"Repeated unsuccessful Memory rounds can finish without a chest")
		check(progress.pair_dry_rounds("memory") == 0 and not progress.pair_round("memory").awarded,
			"Memory never accumulates or invokes the random-chest guarantee")
	check(progress.pair_dry_rounds("match") == 2 and progress.pair_round("match") == match_state,
		"Memory performance does not change Match's saved guarantee")
	check(progress.begin_pair_round("match", "match-guaranteed", 0).pair == 1,
		"Match still guarantees a chest after its two completed dry rounds")
	progress.begin_memory_round("abandoned")
	check(not progress.begin_memory_round("restarted").is_empty() and not progress.finish_memory_round("abandoned", RewardProgress.THEMES.size(), "spring"),
		"Restarting an unfinished Memory board replaces only its callback identity")
	check(not progress.pair_round("memory").awarded and progress.counts.is_empty(),
		"Abandoning a top-tier preview gives no reward")


func _test_memory_legacy_migration() -> void:
	var fixture: Dictionary = _fixture()
	var legacy = fixture.progress
	legacy.begin_pair_round("memory", "legacy-earned", 2)
	legacy.record_pair_reward("memory", "legacy-earned", "ocean")
	var pending: Dictionary = legacy.pair_round("memory")
	var config := ConfigFile.new()
	check(config.parse(fixture.storage.text) == OK, "Read legacy Memory migration fixture")
	config.set_value("pair_chests", "version", 1)
	fixture.storage.text = config.encode_to_text()
	var saved: String = fixture.storage.text
	var writes: int = fixture.storage.save_calls
	var progress = _reload(fixture)
	check(progress.pair_round("memory") == pending and fixture.storage.text == saved and fixture.storage.save_calls == writes,
		"Version-one pending Memory chests load unchanged without a migration write")
	check(progress.begin_memory_round("new-policy").is_empty() and progress.begin_memory_round("legacy-earned") == pending,
		"Legacy pending ownership survives both new and repeated begin calls")
	check(not progress.finish_memory_round("legacy-earned", RewardProgress.THEMES.size(), "spring") and progress.pair_round("memory") == pending,
		"Legacy chest contents cannot be converted by a new completion callback")
	check(progress.settle_pair_reward("memory", "legacy-earned") and progress.count_for("ocean-1") == 1,
		"A legacy midround chest remains recoverable before any new Memory round")
	check(config.parse(fixture.storage.text) == OK and config.get_value("pair_chests", "version") == 2,
		"The first successful mutation upgrades the container version atomically")
	progress = _reload(fixture)
	check(progress.settle_pair_reward("memory", "legacy-earned") and progress.count_for("ocean-1") == 1,
		"Migrated legacy settlement cannot duplicate its fragment")
	check(progress.begin_memory_round("new-policy").get("policy") == Progress.MEMORY_REWARD_POLICY,
		"Settling a legacy chest allows the next round to adopt the performance policy")
	var dry_fixture: Dictionary = _fixture()
	var old = dry_fixture.progress
	for index in range(2):
		var id: String = "legacy-dry-%d" % index
		old.begin_pair_round("memory", id, 0)
		old.finish_pair_round("memory", id)
	check(old.pair_dry_rounds("memory") == 2, "Prepare an old Memory guarantee")
	check(not old.begin_memory_round("new-zero").is_empty() and old.finish_memory_round("new-zero", 0, "spring")
		and old.pair_dry_rounds("memory") == 0 and not old.pair_round("memory").awarded,
		"The new Memory policy discards legacy pity without inventing a chest")


func _test_memory_write_failures() -> void:
	var fixture: Dictionary = _fixture()
	var progress = fixture.progress
	fixture.storage.writable = false
	var saved: String = fixture.storage.text
	check(progress.begin_memory_round("retry").is_empty() and progress.pair_round("memory").is_empty()
		and fixture.storage.text == saved, "A failed Memory begin publishes no preview ownership")
	fixture.storage.writable = true
	progress.begin_memory_round("retry")
	var initial: Dictionary = progress.pair_round("memory")
	saved = fixture.storage.text
	var writes: int = fixture.storage.save_calls
	check(not progress.finish_memory_round("retry", -1, "spring") and not progress.finish_memory_round("retry", RewardProgress.THEMES.size() + 1, "spring")
		and not progress.finish_memory_round("retry", RewardProgress.THEMES.size(), "unknown") and not progress.finish_memory_round("missing", 2, "spring")
		and fixture.storage.save_calls == writes, "Invalid final tiers, medal worlds, and identities never write")
	fixture.storage.writable = false
	check(not progress.finish_memory_round("retry", RewardProgress.THEMES.size(), "spring") and progress.pair_round("memory") == initial
		and fixture.storage.text == saved, "A failed completion changes neither final tier nor ownership")
	fixture.storage.writable = true
	check(progress.finish_memory_round("retry", 2, "spring"), "A failed completion can retry the actual final tier")
	var earned: Dictionary = progress.pair_round("memory")
	saved = fixture.storage.text
	fixture.storage.writable = false
	check(not progress.settle_pair_reward("memory", "retry") and progress.pair_round("memory") == earned
		and progress.counts.is_empty() and fixture.storage.text == saved,
		"A failed Memory settlement preserves its exact pending fragment and tier")
	fixture.storage.writable = true
	check(progress.settle_pair_reward("memory", "retry") and progress.count_for("spring-1") == 1,
		"Retry consumes the preserved Memory reward exactly once")
	var settled: Dictionary = progress.pair_round("memory")
	saved = fixture.storage.text
	fixture.storage.writable = false
	check(progress.begin_memory_round("next").is_empty() and progress.pair_round("memory") == settled
		and fixture.storage.text == saved, "A failed next-round write cannot erase the previous receipt")


func _test_memory_stale_tabs() -> void:
	var fixture: Dictionary = _fixture()
	var first = fixture.progress
	first.begin_memory_round("shared-performance")
	var stale = _reload(fixture)
	check(first.finish_memory_round("shared-performance", 2, "summer"), "One browser tab completes Memory")
	var saved: String = fixture.storage.text
	check(not stale.finish_memory_round("shared-performance", RewardProgress.THEMES.size(), "spring")
		and not stale.pair_round("memory").completed and fixture.storage.text == saved,
		"A stale tab cannot replace a saved Memory tier or learning world")
	check(stale.load_progress() and stale.pair_round("memory").tier == 2, "Reload exposes the authoritative final tier")
	check(first.settle_pair_reward("memory", "shared-performance"), "The first tab settles its Memory fragment")
	saved = fixture.storage.text
	check(not stale.settle_pair_reward("memory", "shared-performance") and stale.count_for("summer-1") == 0
		and fixture.storage.text == saved, "A stale settlement cannot duplicate Memory contents")
	check(stale.load_progress() and stale.settle_pair_reward("memory", "shared-performance")
		and stale.count_for("summer-1") == 1, "Reloaded recovery confirms the existing receipt without a second grant")


func _test_memory_completed_season() -> void:
	var fixture: Dictionary = _fixture()
	var progress = fixture.progress
	for index in range(18):
		check(progress.claim(progress.next_fragment("winter")), "Fill the Memory fixture's medal world")
	progress.begin_memory_round("complete-world")
	check(progress.finish_memory_round("complete-world", RewardProgress.THEMES.size(), "winter") and progress.pair_round("memory").fragment.is_empty(),
		"A fully collected learning world still earns its performance chest without extra medal contents")
	check(progress.settle_pair_reward("memory", "complete-world") and progress.completed_count("winter") == 6,
		"An empty-fragment performance chest still has a durable settlement")


func _test_memory_invalid_saved_state() -> void:
	var fixture: Dictionary = _fixture()
	fixture.progress.begin_memory_round("valid-performance")
	fixture.progress.finish_memory_round("valid-performance", 2, "summer")
	var config := ConfigFile.new()
	check(config.parse(fixture.storage.text) == OK, "Read a valid Memory performance fixture")
	var valid: Dictionary = config.get_value("pair_chests", "state")
	var scenarios: Array[Dictionary] = []
	for field: String in ["tier", "policy"]:
		var missing: Dictionary = valid.duplicate(true)
		missing.memory.round.erase(field)
		scenarios.append(missing)
	for bad_tier: Variant in [-1, RewardProgress.THEMES.size() + 1, 2.0, "2", true]:
		var wrong_tier: Dictionary = valid.duplicate(true)
		wrong_tier.memory.round.tier = bad_tier
		scenarios.append(wrong_tier)
	for change: Array in [["policy", "unknown"], ["completed", false], ["awarded", false], ["pair", 3],
		["tier", 0], ["theme", "winter"], ["extra", true], ["settled", "true"]]:
		var changed: Dictionary = valid.duplicate(true)
		changed.memory.round[change[0]] = change[1]
		scenarios.append(changed)
	var wrong_streak: Dictionary = valid.duplicate(true)
	wrong_streak.memory.dry_rounds = 1
	scenarios.append(wrong_streak)
	var wrong_mode: Dictionary = valid.duplicate(true)
	wrong_mode.match = wrong_mode.memory.duplicate(true)
	scenarios.append(wrong_mode)
	var wrong_fragment: Dictionary = valid.duplicate(true)
	wrong_fragment.memory.round.fragment.after = 2
	scenarios.append(wrong_fragment)
	for state: Dictionary in scenarios:
		config.set_value("pair_chests", "version", 2)
		config.set_value("pair_chests", "state", state)
		fixture.storage.text = config.encode_to_text()
		var saved: String = fixture.storage.text
		var progress := Progress.new(fixture.path + ".cfg", fixture.path + "-legacy.cfg", fixture.storage)
		check(not progress.load_progress() and not progress.error.is_empty(), "Malformed Memory performance state is rejected")
		check(progress.begin_memory_round("overwrite").is_empty() and fixture.storage.text == saved,
			"Malformed performance saves remain untouched for recovery")
	for version: Variant in [1, 0, 3, "2", 2.0]:
		config.set_value("pair_chests", "version", version)
		config.set_value("pair_chests", "state", valid)
		fixture.storage.text = config.encode_to_text()
		var progress := Progress.new(fixture.path + ".cfg", fixture.path + "-legacy.cfg", fixture.storage)
		check(not progress.load_progress(), "Performance records require the exact supported version-two container")

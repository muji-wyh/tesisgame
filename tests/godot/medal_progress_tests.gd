extends SceneTree

var checks: int = 0
var failures: int = 0
var _data: GDScript
var _progress_script: GDScript
var _root: String = ""
var _files: Array[String] = []
var _directories: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	_data = load("res://scripts/game_data.gd")
	var has_medals: bool = _data.has_method("medals")
	var has_medal: bool = _data.has_method("medal")
	check(has_medals, "Data exposes the six active medals per season")
	check(has_medal, "Data distinguishes active medals from archived rewards")
	var pieces: Variant = _data.get_script_constant_map().get("PIECES_PER_MEDAL")
	check(typeof(pieces) == TYPE_INT and pieces == 3, "Data defines three integer pieces per medal")
	if has_medals and has_medal:
		_test_data()
	var path := "res://scripts/medal_progress.gd"
	check(FileAccess.file_exists(path), "The independent medal progression module exists")
	if FileAccess.file_exists(path):
		_progress_script = load(path)
		check(_progress_script != null and _progress_script.can_instantiate(), "MedalProgress compiles")
		if _progress_script != null and _progress_script.can_instantiate() and has_medals and has_medal:
			_root = "user://medal_progress_tests_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
			if _make_directory(_root):
				_test_fresh()
				_test_exact_progression()
				_test_seasons()
				_test_migration()
				_test_sparse_migration_and_reloads()
				_test_invalid_saves()
				_test_invalid_legacy()
				_test_failed_load_keeps_data()
				_test_claim_validation()
				_test_write_retries()
				_test_locked_replacement()
				_test_interrupted_replacement()
				_test_migration_write_retries()
				_cleanup()
	print("Medal progress: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _make_directory(path: String) -> bool:
	var result := DirAccess.make_dir_absolute(path)
	check(result == OK, "Create isolated test directory: " + path.get_file())
	if result == OK:
		_directories.append(path)
	return result == OK


func _fixture(name: String) -> Dictionary:
	var directory := _root.path_join(name)
	_make_directory(directory)
	var save := directory.path_join("medals.cfg")
	var legacy := directory.path_join("rewards.cfg")
	_files.append_array([save, legacy, save + ".pending", save + ".previous", save + ".held"])
	return {
		"save": save,
		"legacy": legacy,
		"progress": _progress_script.new(save, legacy)
	}


func _write_save(path: String, version: Variant, counts: Variant) -> void:
	var config := ConfigFile.new()
	config.set_value("medals", "version", version)
	config.set_value("medals", "counts", counts)
	check(config.save(path) == OK, "Write isolated medal fixture")


func _write_legacy(path: String, ids: Variant) -> void:
	var config := ConfigFile.new()
	config.set_value("rewards", "ids", ids)
	check(config.save(path) == OK, "Write isolated legacy fixture")


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Open isolated text fixture")
	if file != null:
		file.store_string(text)
		file.close()


func _load_ok(progress, message: String) -> bool:
	var loaded: bool = progress.load_progress()
	check(loaded, message)
	check(progress.error.is_empty(), message + " has no error: " + progress.error)
	return loaded


func _load_corrupt(progress) -> bool:
	# Expected ConfigFile syntax errors still reach the module's public error.
	var was_printing := Engine.print_error_messages
	Engine.print_error_messages = false
	var loaded: bool = progress.load_progress()
	Engine.print_error_messages = was_printing
	return loaded


func _fragment(id: String, before: int) -> Dictionary:
	return {"medal_id": id, "before": before, "after": before + 1, "completed": before == 2}


func _reject_claim(fixture: Dictionary, fragment: Dictionary, message: String) -> void:
	var progress = fixture.progress
	var before: Dictionary = progress.counts.duplicate()
	var saved := FileAccess.get_file_as_string(fixture.save) if FileAccess.file_exists(fixture.save) else ""
	var captured := fragment.duplicate(true)
	check(not progress.claim(fragment), message)
	check(not progress.error.is_empty(), message + " explains the failure")
	check(progress.counts == before, message + " preserves counts")
	check(fragment == captured, message + " preserves the captured award")
	if FileAccess.file_exists(fixture.save):
		check(FileAccess.get_file_as_string(fixture.save) == saved, message + " preserves the save")


func _test_data() -> void:
	var total: int = 0
	for theme_id in ["spring", "summer", "autumn", "winter"]:
		var rewards: Array = _data.rewards(theme_id)
		var medals: Array = _data.medals(theme_id)
		check(rewards.size() == 10, theme_id + " keeps all ten old reward definitions")
		check(medals.size() == 6, theme_id + " has exactly six active medals")
		total += medals.size()
		for index in range(10):
			var id := "%s-%d" % [theme_id, index + 1]
			var reward: Dictionary = _data.reward(id)
			check(not reward.is_empty(), "Old artwork and metadata remain available for " + id)
			if index < 6:
				check(_data.medal(id) == reward, "Active metadata reuses the old reward: " + id)
				if index < medals.size():
					check(medals[index] == reward, "Medal order uses stable reward IDs: " + id)
			else:
				check(_data.medal(id).is_empty(), "Archived reward is not active: " + id)
	check(total == 24, "There are exactly 24 active medals")
	check(_data.medals("invalid").is_empty(), "An unknown season has no active medals")
	for id in ["", "spring-0", "spring-11", "invalid-1"]:
		check(_data.medal(id).is_empty(), "Invalid medal metadata is empty: " + id)


func _test_fresh() -> void:
	var fixture := _fixture("fresh")
	var progress = fixture.progress
	check(progress is RefCounted, "MedalProgress is a small RefCounted module")
	check(progress.count_for("spring-1") == 0, "Missing active counts are zero")
	check(progress.count_for("unknown") == 0, "Unknown counts are zero")
	_reject_claim(fixture, _fragment("spring-1", 0), "Claiming before loading is rejected")
	if not _load_ok(progress, "A fresh player loads without a legacy file"):
		return
	check(progress.completed_count() == 0, "A fresh player has no completed medals")
	check(progress.legacy_rewards.is_empty(), "A fresh player has no archived rewards")
	check(FileAccess.file_exists(fixture.save), "Fresh progress is persisted")
	check(not FileAccess.file_exists(fixture.legacy), "Fresh loading never creates an old save")
	var config := ConfigFile.new()
	check(config.load(fixture.save) == OK, "The new save is a readable ConfigFile")
	check(config.get_value("medals", "version", null) == 1, "The new ConfigFile is versioned")
	check(config.get_value("medals", "counts", null) is Dictionary, "The save contains counts by ID")
	var reloaded = _progress_script.new(fixture.save, fixture.legacy)
	check(_load_ok(reloaded, "Fresh progress reloads"), "Reload succeeds")
	check(reloaded.counts == progress.counts, "Fresh reload preserves the same progress")
	check(progress.next_fragment("invalid").is_empty(), "Invalid themes do not select a fragment")
	check(not progress.error.is_empty(), "Invalid themes have an explicit English error")
	check(progress.next_fragment("").is_empty(), "The next fragment requires a specific season")
	check(not progress.error.is_empty(), "An empty season is not silently accepted")
	check(progress.next_fragment("spring") == _fragment("spring-1", 0), "Valid selection recovers after invalid input")
	check(progress.error.is_empty(), "Successful selection clears the previous selection error")


func _test_exact_progression() -> void:
	var fixture := _fixture("exact")
	var progress = fixture.progress
	if not _load_ok(progress, "Exact-progression fixture loads"):
		return
	for before in range(3):
		var saved := FileAccess.get_file_as_string(fixture.save)
		var fragment: Dictionary = progress.next_fragment("spring")
		check(fragment == _fragment("spring-1", before), "Select the exact spring fragment %d" % (before + 1))
		check(progress.count_for("spring-1") == before, "Selection does not change counts")
		check(FileAccess.get_file_as_string(fixture.save) == saved, "Selection does not write a save")
		var captured := fragment.duplicate(true)
		check(progress.claim(fragment), "Claim spring piece %d" % (before + 1))
		check(progress.error.is_empty(), "A committed fragment has no error")
		check(fragment == captured, "Claim does not modify its captured fragment")
		check(progress.count_for("spring-1") == before + 1, "Each claim advances by exactly one")
		check(progress.completed_count("spring") == (1 if before == 2 else 0), "Only the third piece completes a medal")
		var reloaded = _progress_script.new(fixture.save, fixture.legacy)
		if _load_ok(reloaded, "Each committed piece survives reload"):
			check(reloaded.count_for("spring-1") == before + 1, "Reload reads the committed count")
			_make_directory(fixture.save + ".pending")
			check(progress.claim(fragment), "An immediate duplicate succeeds without needing a write")
			check(reloaded.claim(fragment), "The same committed award is idempotent after reload")
			check(reloaded.count_for("spring-1") == before + 1, "Reloaded duplicate does not increment")
			check(DirAccess.remove_absolute(fixture.save + ".pending") == OK, "Remove the known duplicate-write blocker")
	check(progress.next_fragment("spring") == _fragment("spring-2", 0), "A completed medal advances to the next medal")
	check(progress.completed_count() == 1, "Total completion counts complete medals, not pieces")


func _test_seasons() -> void:
	var fixture := _fixture("seasons")
	var progress = fixture.progress
	if not _load_ok(progress, "Season fixture loads"):
		return
	for win in range(18):
		var expected := _fragment("spring-%d" % (1 + win / 3), win % 3)
		var fragment: Dictionary = progress.next_fragment("spring")
		check(fragment == expected, "Spring win %d fills the first incomplete medal" % (win + 1))
		check(progress.claim(fragment), "Spring win %d is saved" % (win + 1))
	check(progress.completed_count("spring") == 6, "Eighteen wins complete all six spring medals")
	check(progress.completed_count() == 6, "Other seasons are not completed by spring wins")
	check(progress.next_fragment("invalid").is_empty(), "Set a prior selection error")
	check(progress.next_fragment("spring").is_empty(), "A full season has no seventh award")
	check(progress.error.is_empty(), "A full season is normal, not an error")
	check(progress.count_for("spring-7") == 0 and not progress.counts.has("spring-7"), "No active seventh medal is created")
	for theme_id in ["summer", "autumn", "winter"]:
		var fragment: Dictionary = progress.next_fragment(theme_id)
		check(fragment == _fragment(theme_id + "-1", 0), theme_id + " starts independently")
		check(progress.claim(fragment), theme_id + " receives its own fragment")
		check(progress.completed_count(theme_id) == 0, theme_id + " still needs three pieces")
		check(progress.completed_count("spring") == 6, "Changing seasons preserves completed spring medals")
	check(progress.claim(progress.next_fragment("summer")), "The second summer fragment saves")
	check(progress.claim(progress.next_fragment("summer")), "The third summer fragment saves")
	check(progress.completed_count() == 7, "Completed counts span all four active seasons")
	check(progress.count_for("autumn-1") == 1 and progress.count_for("winter-1") == 1, "Partial seasons remain independent")
	check(progress.completed_count("unknown") == 0, "An unknown completion filter has no medals")


func _test_migration() -> void:
	var fixture := _fixture("migration")
	var ids := PackedStringArray()
	for theme_id in ["spring", "summer", "autumn", "winter"]:
		for number in range(1, 11):
			ids.append("%s-%d" % [theme_id, number])
	_write_legacy(fixture.legacy, ids)
	var original := FileAccess.get_file_as_string(fixture.legacy)
	var progress = fixture.progress
	if not _load_ok(progress, "All forty old rewards migrate safely"):
		return
	check(progress.completed_count() == 24, "Old first-six rewards become fully completed medals")
	check(progress.legacy_rewards.size() == 16, "All sixteen earned seventh-to-tenth rewards are archived")
	for id in ids:
		var active: bool = not _data.medal(id).is_empty()
		check(progress.count_for(id) == (3 if active else 0), "Migration count is correct for " + id)
		check(progress.legacy_rewards.has(id) == not active, "Only old seventh-to-tenth IDs are archived: " + id)
		if not active:
			check(progress.legacy_rewards[id] == true, "Archived IDs are marked earned: " + id)
	check(FileAccess.get_file_as_string(fixture.legacy) == original, "Migration leaves the old file byte-for-byte unchanged")
	check(_load_ok(progress, "Migration reloads without repeating"), "Repeated load succeeds")
	check(progress.completed_count() == 24, "Repeated migration does not reset medals")
	check(FileAccess.get_file_as_string(fixture.legacy) == original, "Reload also leaves the old save unchanged")


func _test_sparse_migration_and_reloads() -> void:
	var fixture := _fixture("sparse_migration")
	var ids: Array = ["spring-2", "spring-7", "summer-6", "winter-10", "spring-2"]
	_write_legacy(fixture.legacy, ids)
	var progress = fixture.progress
	if not _load_ok(progress, "Sparse old rewards and duplicate IDs migrate"):
		return
	check(progress.count_for("spring-2") == 3 and progress.count_for("summer-6") == 3, "Sparse earned medals remain complete")
	check(progress.next_fragment("spring") == _fragment("spring-1", 0), "Migration fills the first unearned medal, not a later gap")
	check(progress.legacy_rewards.size() == 2, "Duplicate old IDs do not create archive duplicates")
	check(progress.claim(progress.next_fragment("spring")), "New partial progress saves after migration")
	ids.append_array(["spring-1", "autumn-8"])
	_write_legacy(fixture.legacy, ids)
	var saved := FileAccess.get_file_as_string(fixture.save)
	var reloaded = _progress_script.new(fixture.save, fixture.legacy)
	if not _load_ok(reloaded, "New progress reloads while reading the legacy archive"):
		return
	check(reloaded.count_for("spring-1") == 1, "Existing new saves do not reapply old active rewards")
	check(reloaded.count_for("spring-2") == 3, "Existing migrated completions remain intact")
	check(reloaded.legacy_rewards.has("autumn-8"), "Subsequent loads refresh old archive previews")
	check(not reloaded.legacy_rewards.has("spring-1"), "Active rewards do not leak into the archive")
	check(FileAccess.get_file_as_string(fixture.save) == saved, "Reloading does not rewrite the new save")
	check(DirAccess.remove_absolute(fixture.legacy) == OK, "Remove only this test's legacy fixture")
	check(_load_ok(reloaded, "An absent old save is normal after migration"), "New progress survives without the old file")
	check(reloaded.count_for("spring-1") == 1, "An absent legacy file never resets partial progress")
	check(reloaded.legacy_rewards.is_empty(), "An absent old archive has no earned previews")


func _test_invalid_saves() -> void:
	var scenarios: Array = [
		["missing_version", null, {}], ["unsupported_version", 2, {}],
		["zero_version", 0, {}], ["float_version", 1.0, {}],
		["string_version", "1", {}], ["bool_version", true, {}],
		["missing_counts", 1, null], ["array_counts", 1, []],
		["string_counts", 1, "spring-1"], ["unknown_id", 1, {"unknown": 1}],
		["archived_id", 1, {"spring-7": 1}], ["non_string_id", 1, {1: 1}],
		["negative_count", 1, {"spring-1": -1}], ["oversized_count", 1, {"spring-1": 4}],
		["float_count", 1, {"spring-1": 1.0}], ["string_count", 1, {"spring-1": "1"}],
		["bool_count", 1, {"spring-1": true}], ["null_count", 1, {"spring-1": null}],
		["partly_invalid", 1, {"spring-1": 2, "winter-8": 1}]
	]
	for scenario in scenarios:
		var fixture := _fixture(scenario[0])
		_write_legacy(fixture.legacy, PackedStringArray(["summer-1", "summer-7"]))
		_write_save(fixture.save, scenario[1], scenario[2])
		var original := FileAccess.get_file_as_string(fixture.save)
		var progress = fixture.progress
		check(not progress.load_progress(), "Invalid new save fails: " + scenario[0])
		check(not progress.error.is_empty(), "Invalid new save gives a useful error: " + scenario[0])
		check(progress.counts.is_empty() and progress.legacy_rewards.is_empty(), "Invalid new saves never migrate over an error")
		check(FileAccess.get_file_as_string(fixture.save) == original, "Invalid new saves are preserved: " + scenario[0])
		_reject_claim(fixture, _fragment("spring-1", 0), "Claims cannot overwrite a failed load")
	var corrupt := _fixture("corrupt_new")
	_write_legacy(corrupt.legacy, PackedStringArray(["spring-1"]))
	_write_text(corrupt.save, "[medals\nversion=1\n")
	var original := FileAccess.get_file_as_string(corrupt.save)
	check(not _load_corrupt(corrupt.progress), "Syntactically corrupt new saves fail")
	check(not corrupt.progress.error.is_empty(), "Corrupt new saves explain the read failure")
	check(corrupt.progress.counts.is_empty(), "Corrupt new saves do not reapply migration")
	check(FileAccess.get_file_as_string(corrupt.save) == original, "Corrupt new saves are never overwritten")
	var empty := _fixture("empty_new")
	_write_text(empty.save, "")
	check(not empty.progress.load_progress(), "An existing empty new file is malformed, not absent")
	check(not empty.progress.error.is_empty(), "An empty new file reports an error")
	var directory := _fixture("directory_new")
	_write_legacy(directory.legacy, PackedStringArray(["spring-1"]))
	_make_directory(directory.save)
	check(not _load_corrupt(directory.progress), "A directory at the new save path is not a missing file")
	check(not directory.progress.error.is_empty(), "An unreadable save path has an explicit error")
	check(directory.progress.counts.is_empty(), "An unreadable path does not expose migrated progress")
	var valid := _fixture("valid_bounds")
	_write_save(valid.save, 1, {"spring-1": 0, "summer-1": 1, "autumn-1": 2, "winter-1": 3})
	check(_load_ok(valid.progress, "All integer count bounds load"), "Sparse validated integer counts are accepted")
	check(valid.progress.completed_count() == 1, "Only the upper integer bound means completed")


func _test_invalid_legacy() -> void:
	var values: Array = [null, 1, "spring-1", {}, [1], [true], [null], ["unknown"], ["spring-1", "spring-11"]]
	for index in range(values.size()):
		var fixture := _fixture("invalid_legacy_%d" % index)
		_write_legacy(fixture.legacy, values[index])
		var original := FileAccess.get_file_as_string(fixture.legacy)
		check(not fixture.progress.load_progress(), "Invalid legacy fields fail before migration: %d" % index)
		check(not fixture.progress.error.is_empty(), "Invalid legacy fields report an error")
		check(fixture.progress.counts.is_empty() and fixture.progress.legacy_rewards.is_empty(), "Invalid legacy data is not partially applied")
		check(not FileAccess.file_exists(fixture.save), "Bad legacy input never creates a new save")
		check(FileAccess.get_file_as_string(fixture.legacy) == original, "Bad legacy input is preserved")
	var corrupt := _fixture("corrupt_legacy")
	_write_text(corrupt.legacy, "[rewards\nids=???\n")
	check(not _load_corrupt(corrupt.progress), "Syntactically corrupt old saves fail")
	check(not corrupt.progress.error.is_empty(), "Corrupt old saves have a useful error")
	check(not FileAccess.file_exists(corrupt.save), "Corrupt old saves never become empty migrated saves")
	var directory := _fixture("directory_legacy")
	_make_directory(directory.legacy)
	check(not _load_corrupt(directory.progress), "An old save directory is an error, not absent")
	check(not directory.progress.error.is_empty(), "An unreadable old path reports an error")
	check(not FileAccess.file_exists(directory.save), "An unreadable old path is not migrated")


func _test_failed_load_keeps_data() -> void:
	var fixture := _fixture("failed_reload")
	_write_legacy(fixture.legacy, PackedStringArray(["spring-7"]))
	_write_save(fixture.save, 1, {"winter-1": 2})
	var progress = fixture.progress
	if not _load_ok(progress, "Failed-reload fixture starts with safe data"):
		return
	var previous_counts: Dictionary = progress.counts.duplicate()
	var previous_archive: Dictionary = progress.legacy_rewards.duplicate()
	_write_save(fixture.save, 100, {"winter-1": 3})
	check(not progress.load_progress(), "Unsupported versions also fail on an already loaded object")
	check(progress.counts == previous_counts and progress.legacy_rewards == previous_archive, "Failed loading preserves previous in-memory data")
	_reject_claim(fixture, _fragment("winter-1", 2), "A failed reload blocks overwriting the unsupported save")
	_write_save(fixture.save, 1, previous_counts)
	_write_legacy(fixture.legacy, ["spring-7", "unknown"])
	check(not progress.load_progress(), "A valid new save does not hide corrupt legacy archives")
	check(progress.counts == previous_counts and progress.legacy_rewards == previous_archive, "A bad archive does not reset loaded progress or previews")
	_reject_claim(fixture, _fragment("winter-1", 2), "A failed archive load is not silent success")
	_write_legacy(fixture.legacy, PackedStringArray(["spring-7"]))
	check(_load_ok(progress, "A repaired input can be retried"), "Loading recovers without a reset")
	check(progress.claim(_fragment("winter-1", 2)), "Claims resume after successful reload")


func _test_claim_validation() -> void:
	var fixture := _fixture("claims")
	var progress = fixture.progress
	if not _load_ok(progress, "Claim-validation fixture loads"):
		return
	var invalid: Array = [
		{}, {"medal_id": "spring-1", "after": 1, "completed": false},
		{"medal_id": "spring-1", "before": 0, "completed": false},
		{"medal_id": "spring-1", "before": 0, "after": 1},
		{"medal_id": "spring-1", "before": 0, "after": 1, "completed": true},
		{"medal_id": "spring-1", "before": 0, "after": 1, "completed": 0}
	]
	for key in ["medal_id", "before", "after"]:
		var values: Array = [1, true, null] if key == "medal_id" else [0.0 if key == "before" else 1.0, "0" if key == "before" else "1", false, null]
		for value in values:
			var fragment := _fragment("spring-1", 0)
			fragment[key] = value
			invalid.append(fragment)
	for id in ["unknown", "", "spring-7", "spring-11"]:
		invalid.append(_fragment(id, 0))
	for bounds in [[-1, 0], [3, 4], [0, 2], [0, 0], [1, 0]]:
		invalid.append({"medal_id": "spring-1", "before": bounds[0], "after": bounds[1], "completed": false})
	for index in range(invalid.size()):
		_reject_claim(fixture, invalid[index], "Invalid captured fragment %d is rejected" % index)
	_reject_claim(fixture, _fragment("spring-1", 1), "A future fragment cannot skip the current count")
	_reject_claim(fixture, _fragment("spring-2", 0), "A later medal cannot start before the first incomplete one")
	var first := _fragment("spring-1", 0)
	check(progress.claim(first), "The first valid claim succeeds after validation errors")
	check(progress.error.is_empty(), "A successful retry clears the prior error")
	check(progress.claim(_fragment("spring-1", 1)), "The next exact claim succeeds")
	_reject_claim(fixture, first, "An older captured step is stale after later progress")
	var last := _fragment("spring-1", 2)
	check(progress.claim(last), "The final fragment completes the first medal")
	check(progress.claim(last), "Repeating completion is idempotent after the goal advances")
	check(progress.count_for("spring-2") == 0, "Repeating completion never selects a new award")


func _test_write_retries() -> void:
	var fixture := _fixture("write_retries")
	var progress = fixture.progress
	if not _load_ok(progress, "Write-retry fixture loads"):
		return
	check(progress.claim(progress.next_fragment("spring")), "Establish a previous durable count")
	var fragment: Dictionary = progress.next_fragment("spring")
	var saved := FileAccess.get_file_as_string(fixture.save)
	_make_directory(fixture.save + ".pending")
	for attempt in range(3):
		_reject_claim(fixture, fragment, "Staging write failure %d is retryable" % (attempt + 1))
		check(progress.next_fragment("spring") == fragment, "Failed writes do not choose another award")
	check(DirAccess.remove_absolute(fixture.save + ".pending") == OK, "Remove the known staging blocker")
	check(progress.claim(fragment), "The same captured award saves after the path recovers")
	check(progress.count_for("spring-1") == 2, "Repeated failed retries earn exactly one piece after recovery")
	check(FileAccess.get_file_as_string(fixture.save) != saved, "The recovered save contains the new count")
	_make_directory(fixture.save + ".pending")
	for attempt in range(3):
		check(progress.claim(fragment), "Already committed retries do not need any further writes")
		check(progress.count_for("spring-1") == 2, "Already committed retries do not increment")
	check(DirAccess.remove_absolute(fixture.save + ".pending") == OK, "Remove the known idempotence blocker")
	fragment = progress.next_fragment("spring")
	saved = FileAccess.get_file_as_string(fixture.save)
	check(DirAccess.rename_absolute(fixture.save, fixture.save + ".held") == OK, "Temporarily hold only this fixture's previous save")
	_make_directory(fixture.save)
	for attempt in range(2):
		check(not progress.claim(fragment), "A replacement failure does not commit an award")
		check(not progress.error.is_empty(), "A replacement failure reports its cause")
		check(progress.count_for("spring-1") == 2, "Failed replacement preserves the in-memory count")
		check(FileAccess.get_file_as_string(fixture.save + ".held") == saved, "Failed replacement leaves the prior file unchanged")
		check(not FileAccess.file_exists(fixture.save + ".pending"), "A failed replacement cleans up only its staged file")
	check(DirAccess.remove_absolute(fixture.save) == OK, "Remove the known replacement blocker")
	check(DirAccess.rename_absolute(fixture.save + ".held", fixture.save) == OK, "Restore only this fixture's previous save")
	check(progress.claim(fragment), "Retry the exact captured completion after replacement recovers")
	check(progress.count_for("spring-1") == 3 and progress.count_for("spring-2") == 0, "Replacement retries never duplicate or switch medals")
	var reloaded = _progress_script.new(fixture.save, fixture.legacy)
	check(_load_ok(reloaded, "Recovered progress reloads"), "Recovered progress is durable")
	check(reloaded.claim(fragment) and reloaded.count_for("spring-1") == 3, "Recovered claims remain idempotent after reload")


func _test_migration_write_retries() -> void:
	var fixture := _fixture("migration_write_retries")
	_write_legacy(fixture.legacy, PackedStringArray(["spring-1", "spring-7"]))
	var original := FileAccess.get_file_as_string(fixture.legacy)
	_make_directory(fixture.save + ".pending")
	for attempt in range(3):
		check(not fixture.progress.load_progress(), "A failed migration save is retryable")
		check(not fixture.progress.error.is_empty(), "A failed migration save reports the write error")
		check(fixture.progress.counts.is_empty() and fixture.progress.legacy_rewards.is_empty(), "Migration data is not applied before it is saved")
		check(not FileAccess.file_exists(fixture.save), "A failed migration does not leave a partial primary save")
		check(FileAccess.get_file_as_string(fixture.legacy) == original, "Failed migration retries preserve the old save")
	check(DirAccess.remove_absolute(fixture.save + ".pending") == OK, "Remove the known migration blocker")
	check(_load_ok(fixture.progress, "The same migration can be retried safely"), "Migration recovers")
	check(fixture.progress.count_for("spring-1") == 3, "Recovered migration restores a whole medal")
	check(fixture.progress.legacy_rewards == {"spring-7": true}, "Recovered migration restores the earned archive")
	check(FileAccess.get_file_as_string(fixture.legacy) == original, "Successful retry also leaves the old save untouched")


func _test_locked_replacement() -> void:
	if OS.get_name() != "Windows":
		return
	var fixture := _fixture("locked_replacement")
	var progress = fixture.progress
	if not _load_ok(progress, "Locked-replacement fixture loads"):
		return
	check(progress.claim(progress.next_fragment("spring")), "Establish progress before a Windows sharing violation")
	var fragment: Dictionary = progress.next_fragment("spring")
	var original := FileAccess.get_file_as_string(fixture.save)
	_write_text(fixture.save + ".pending", "A known test file held open during replacement.")
	var locked := FileAccess.open(fixture.save + ".pending", FileAccess.READ)
	check(locked != null, "Hold only the isolated staged file open")
	if locked == null:
		return
	check(not progress.claim(fragment), "A Windows-locked staged file prevents replacement")
	check(not progress.error.is_empty(), "The sharing violation is reported")
	check(progress.count_for("spring-1") == 1, "The locked move does not mutate counts")
	check(FileAccess.file_exists(fixture.save), "A failed Windows move must not delete the previous save")
	if FileAccess.file_exists(fixture.save):
		check(FileAccess.get_file_as_string(fixture.save) == original, "A failed Windows move restores the previous bytes")
	locked.close()
	check(progress.claim(fragment), "The same captured fragment saves after the Windows lock is released")
	check(progress.count_for("spring-1") == 2, "A failed Windows move and retry earn one piece total")
	var reloaded = _progress_script.new(fixture.save, fixture.legacy)
	check(_load_ok(reloaded, "Windows replacement recovery reloads"), "Recovered Windows progress is durable")
	check(reloaded.count_for("spring-1") == 2, "Reload preserves the recovered Windows count")
	locked = FileAccess.open(fixture.save, FileAccess.READ)
	check(locked != null, "Hold only the isolated primary save open")
	if locked != null:
		_reject_claim(fixture, _fragment("spring-1", 2), "A locked previous save cannot be destructively replaced")
		locked.close()
		check(progress.claim(_fragment("spring-1", 2)), "Retrying after the primary lock is released completes the same medal")


func _test_interrupted_replacement() -> void:
	var fixture := _fixture("interrupted_replacement")
	_write_legacy(fixture.legacy, PackedStringArray(["spring-1", "spring-7"]))
	_write_save(fixture.save + ".previous", 1, {"spring-1": 1})
	_write_save(fixture.save + ".pending", 1, {"spring-1": 2})
	var original := FileAccess.get_file_as_string(fixture.legacy)
	var progress = fixture.progress
	if _load_ok(progress, "An interrupted replacement restores the previous complete save"):
		check(progress.count_for("spring-1") == 1, "Recovery does not commit staged progress or reapply migration")
		check(progress.legacy_rewards == {"spring-7": true}, "Recovery still loads earned legacy previews")
		check(FileAccess.get_file_as_string(fixture.legacy) == original, "Recovery leaves legacy data unchanged")
		check(progress.claim(_fragment("spring-1", 1)), "A recovered player can claim the next exact piece")
	var corrupt := _fixture("corrupt_with_backup")
	_write_save(corrupt.save + ".previous", 1, {"spring-1": 1})
	_write_text(corrupt.save, "[medals\n")
	var invalid_bytes := FileAccess.get_file_as_string(corrupt.save)
	var backup_bytes := FileAccess.get_file_as_string(corrupt.save + ".previous")
	check(not _load_corrupt(corrupt.progress), "A backup never hides an existing corrupt primary")
	check(not corrupt.progress.error.is_empty(), "Corrupt primary files still report an error with a backup present")
	check(FileAccess.get_file_as_string(corrupt.save) == invalid_bytes, "Backup recovery never replaces corrupt primary data")
	check(FileAccess.get_file_as_string(corrupt.save + ".previous") == backup_bytes, "A corrupt primary also preserves its backup")
	var blocked := _fixture("blocked_recovery")
	_write_legacy(blocked.legacy, PackedStringArray(["spring-1"]))
	_make_directory(blocked.save + ".previous")
	check(not blocked.progress.load_progress(), "An unreadable previous-save path is not a fresh player")
	check(not blocked.progress.error.is_empty(), "An unreadable recovery path has a useful error")
	check(not FileAccess.file_exists(blocked.save), "A failed recovery never migrates over the interrupted save")


func _cleanup() -> void:
	for path in _files:
		if FileAccess.file_exists(path):
			check(DirAccess.remove_absolute(path) == OK, "Remove only known fixture file: " + path.get_file())
	_directories.reverse()
	for path in _directories:
		if DirAccess.dir_exists_absolute(path):
			check(DirAccess.remove_absolute(path) == OK, "Remove only empty known fixture directory: " + path.get_file())

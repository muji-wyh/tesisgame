extends SceneTree

var checks: int = 0
var failures: int = 0
var _script: GDScript
var _root: String
var _files: Array[String] = []
var _directories: Array[String] = []


class BrowserStorage extends RefCounted:
	var text: Variant = null
	var readable: bool = true
	var writable: bool = true
	var writes: int = 0

	func playroomState() -> Variant:
		return text if readable else false

	func savePlayroomState(value: String) -> bool:
		writes += 1
		if not writable:
			return false
		text = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var path := "res://scripts/playroom_state.gd"
	check(FileAccess.file_exists(path), "The playroom state module exists")
	if FileAccess.file_exists(path):
		_script = load(path)
		check(_script != null and _script.can_instantiate(), "PlayroomState compiles")
		if _script != null and _script.can_instantiate():
			_root = "user://playroom_state_tests_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
			if _directory(_root):
				_test_catalog()
				_test_selection_and_reload()
				_test_goals()
				_test_invalid_records()
				_test_native_failures()
				_test_browser_storage()
				_cleanup()
	print("Playroom state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _directory(path: String) -> bool:
	var status := DirAccess.make_dir_absolute(path)
	check(status == OK, "Create isolated fixture directory")
	if status == OK:
		_directories.append(path)
	return status == OK


func _fixture(name: String, storage: Object = null) -> Dictionary:
	var directory := _root.path_join(name)
	_directory(directory)
	var path := directory.path_join("playroom-v2.cfg")
	_files.append_array([path, path + ".pending", path + ".previous"])
	return {"path": path, "state": _script.new(path, storage)}


func _text(version: Variant = 1, toy: Variant = "toy-ball", backdrop: Variant = "backdrop-home", favorite: Variant = "") -> String:
	var config := ConfigFile.new()
	config.set_value("playroom", "version", version)
	config.set_value("playroom", "toy", toy)
	config.set_value("playroom", "backdrop", backdrop)
	config.set_value("playroom", "favorite", favorite)
	return config.encode_to_text()


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Open isolated fixture file")
	if file != null:
		check(file.store_string(value), "Write isolated fixture file")
		file.close()


func _load(state, legacy_favorite: String = "") -> bool:
	var loaded: bool = state.load_state(legacy_favorite)
	check(loaded and state.error.is_empty(), "Playroom state loads: " + state.error)
	return loaded


func _corrupt_load(state) -> bool:
	var was_printing := Engine.print_error_messages
	Engine.print_error_messages = false
	var loaded: bool = state.load_state()
	Engine.print_error_messages = was_printing
	return loaded


func _test_catalog() -> void:
	var state = _script.new()
	var entries: Array = state.catalog()
	check(entries.size() == 14, "The catalog contains two starters and twelve world gifts")
	var ids: Dictionary = {}
	for entry in entries:
		check(entry.has_all(["id", "slot", "theme", "name", "word_id", "action", "art", "medal_id", "required_pieces"]), "Catalog entries provide room and goal metadata")
		check(not ids.has(entry.id), "Catalog IDs are unique")
		ids[entry.id] = true
		check(FileAccess.file_exists(entry.art), "Catalog artwork exists: " + entry.id)
	check(state.owned(state.item("toy-ball"), {}), "Starter ball needs no progress")
	check(state.owned(state.item("backdrop-home"), {}), "Starter room needs no progress")
	check(state.item("unknown").is_empty() and not state.owned({}, {}), "Unknown catalog items never unlock")
	check(state.item("toy-ball").word_id == "ball" and state.item("toy-ball").action == "roll", "The starter ball teaches its matching noun and action")
	for row in [["spring", "flower", "water"], ["summer", "ball", "roll"], ["autumn", "apple", "offer"], ["winter", "bell", "ring"], ["ocean", "shell", "open"], ["space", "rocket", "launch"]]:
		var toy: Dictionary = state.item("toy-" + row[0])
		var backdrop: Dictionary = state.item("backdrop-" + row[0])
		check(toy.slot == "toy" and toy.word_id == row[1] and toy.action == row[2], "Each world toy has the matching teaching interaction: " + row[0])
		check(toy.art == "res://assets/images/words/%s.svg" % row[1], "Toy artwork matches its spoken word")
		check(backdrop.slot == "backdrop" and backdrop.art == "res://assets/images/rewards/%s.svg" % row[0], "Each backdrop uses its world symbol")
		for pieces in range(4):
			check(state.owned(toy, {row[0] + "-1": pieces}) == (pieces == 3), "The toy unlocks at exactly the first complete medal")
			check(state.owned(backdrop, {row[0] + "-3": pieces}) == (pieces == 3), "Sparse legacy third-medal completion unlocks its backdrop")
	for invalid in [-1, 4, 3.0, "3", true]:
		check(not state.owned(state.item("toy-spring"), {"spring-1": invalid}), "Invalid count values cannot grant ownership")
	check(not state.owned({"id": "toy-spring", "required_pieces": 0, "medal_id": ""}, {}), "Ownership uses canonical catalog requirements")
	entries[0].name = "Changed by a caller"
	check(state.item("toy-ball").name != "Changed by a caller", "Returned catalog entries do not mutate future catalog lookups")


func _test_selection_and_reload() -> void:
	var fixture := _fixture("selection")
	var state = fixture.state
	check(not state.select_item("toy-ball", {}) and not state.set_favorite("spring-1"), "Loading must succeed before any selection can write")
	if not _load(state, "spring-1"):
		return
	check(state.toy_id == "toy-ball" and state.backdrop_id == "backdrop-home", "A fresh playroom starts with playable default selections")
	check(state.favorite_id == "spring-1", "Migration preserves a supplied partially earned favorite")
	var counts := {"spring-1": 3, "spring-3": 3, "ocean-1": 2}
	var before := counts.duplicate(true)
	var saved := FileAccess.get_file_as_string(fixture.path)
	for id in ["unknown", "toy-ocean", "backdrop-space"]:
		check(not state.select_item(id, counts) and not state.error.is_empty(), "Unknown or locked items cannot be equipped: " + id)
		check(FileAccess.get_file_as_string(fixture.path) == saved, "Rejected selections preserve saved preferences")
	check(state.select_item("toy-spring", counts) and state.toy_id == "toy-spring", "An earned toy can be equipped")
	check(state.backdrop_id == "backdrop-home", "Equipping a toy preserves the backdrop")
	check(state.select_item("backdrop-spring", counts) and state.backdrop_id == "backdrop-spring", "An earned backdrop can be equipped")
	check(state.toy_id == "toy-spring" and counts == before, "Customization does not spend or change medal pieces")
	check(state.set_favorite("winter-10"), "A known archived favorite remains supported")
	var reloaded = _script.new(fixture.path)
	if _load(reloaded, "invalid-old-favorite"):
		check(reloaded.toy_id == "toy-spring" and reloaded.backdrop_id == "backdrop-spring" and reloaded.favorite_id == "winter-10", "All three preferences survive native reload; new state takes precedence over legacy")
	check(not state.set_favorite("unknown") and state.favorite_id == "winter-10", "Unknown favorites are rejected without losing the prior display")
	check(state.set_favorite("") and state.favorite_id.is_empty(), "The favorite display can be cleared")
	_directory(fixture.path + ".pending")
	check(state.select_item("toy-spring", counts) and state.set_favorite(""), "Repeated selections are idempotent without another write")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the known write blocker")


func _test_goals() -> void:
	var state = _script.new()
	var gift: Dictionary = state.next_gift({})
	check(gift.id == "toy-spring" and gift.remaining_pieces == 3, "Nearest gifts break ties in catalog order")
	gift = state.next_gift({"spring-1": 2}, "spring")
	check(gift.id == "toy-spring" and gift.remaining_pieces == 1, "A partial first medal has one piece left for its toy")
	gift = state.next_gift({"spring-1": 3, "spring-2": 1, "spring-3": 1}, "spring")
	check(gift.id == "backdrop-spring" and gift.remaining_pieces == 4, "Backdrop goals include deficits in preceding medals")
	gift = state.next_gift({"spring-1": 1, "spring-3": 3}, "spring")
	check(gift.id == "toy-spring" and gift.remaining_pieces == 2, "An already earned sparse backdrop is skipped")
	gift = state.next_gift({"spring-1": 3, "ocean-1": 2})
	check(gift.id == "toy-ocean" and gift.remaining_pieces == 1, "The nearest unfinished gift can belong to another world")
	check(state.next_gift({"spring-1": 3, "spring-3": 3}, "spring").is_empty(), "A world with all catalog gifts has no further gift")
	check(state.next_gift({}, "unknown").is_empty(), "Unknown world filters produce no gift")
	var complete: Dictionary = {}
	for theme_id in ["spring", "summer", "autumn", "winter", "ocean", "space"]:
		complete[theme_id + "-1"] = 3
		complete[theme_id + "-3"] = 3
	var before := complete.duplicate(true)
	check(state.next_gift(complete).is_empty() and complete == before, "Fully earned catalog goals never mutate progress or invent another reward")


func _test_invalid_records() -> void:
	var invalid: Array = ["", "[playroom\n", _text(null), _text(2), _text(1.0), _text(true), _text(1, null), _text(1, 5), _text(1, "unknown"), _text(1, "backdrop-home"), _text(1, "toy-ball", null), _text(1, "toy-ball", "toy-ball"), _text(1, "toy-ball", "backdrop-home", null), _text(1, "toy-ball", "backdrop-home", 1), _text(1, "toy-ball", "backdrop-home", "unknown")]
	for index in range(invalid.size()):
		var fixture := _fixture("invalid_%d" % index)
		_write(fixture.path, invalid[index])
		var state = fixture.state
		check(not _corrupt_load(state) and not state.error.is_empty(), "Invalid or unsupported playroom records fail explicitly")
		check(not state.select_item("toy-ball", {}) and not state.set_favorite("spring-1"), "A failed load blocks later overwrites")
		check(FileAccess.get_file_as_string(fixture.path) == invalid[index], "Invalid source bytes are preserved")
	var directory := _fixture("directory_record")
	_directory(directory.path)
	check(not _corrupt_load(directory.state), "A directory at the save path is not a missing record")
	var legacy := _fixture("invalid_legacy")
	check(not legacy.state.load_state("unknown") and not FileAccess.file_exists(legacy.path), "An invalid supplied favorite cannot be migrated into a fresh save")
	var empty = _script.new("")
	check(not empty.load_state() and not empty.error.is_empty(), "An empty save path fails explicitly")


func _test_native_failures() -> void:
	var fixture := _fixture("native_failure")
	var state = fixture.state
	if not _load(state, "spring-7"):
		return
	var original := FileAccess.get_file_as_string(fixture.path)
	_directory(fixture.path + ".pending")
	check(not state.select_item("toy-spring", {"spring-1": 3}), "A staging failure rejects the new selection")
	check(state.toy_id == "toy-ball" and FileAccess.get_file_as_string(fixture.path) == original, "A failed save preserves visible selection and prior bytes")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the known staging blocker")
	check(state.select_item("toy-spring", {"spring-1": 3}) and state.toy_id == "toy-spring", "The same selection retries after native storage recovers")
	original = FileAccess.get_file_as_string(fixture.path)
	if OS.get_name() == "Windows":
		var locked := FileAccess.open(fixture.path, FileAccess.READ)
		check(locked != null, "Hold only this fixture's native save open")
		if locked != null:
			check(not state.set_favorite("winter-10"), "A locked previous save blocks replacement")
			check(state.favorite_id == "spring-7" and FileAccess.get_file_as_string(fixture.path) == original, "Failed replacement cannot delete the old file or expose new state")
			locked.close()
			check(state.set_favorite("winter-10"), "The favorite retries after the native lock is released")
	_write(fixture.path, _text(2))
	check(not state.load_state() and state.toy_id == "toy-spring", "A failed reload preserves the previous in-memory room")
	check(not state.select_item("toy-ball", {}) and FileAccess.get_file_as_string(fixture.path) == _text(2), "A failed reload disables writes to unsupported data")
	_write(fixture.path, original)
	check(_load(state) and state.select_item("toy-ball", {}), "A repaired record can be loaded and edited again")
	var interrupted := _fixture("interrupted")
	_write(interrupted.path + ".previous", _text(1, "toy-space", "backdrop-space", "space-1"))
	_write(interrupted.path + ".pending", _text())
	if _load(interrupted.state):
		check(interrupted.state.toy_id == "toy-space", "Interrupted replacement restores the committed previous record, not the unfinished staging file")
	var blocked := _fixture("failed_migration")
	_directory(blocked.path + ".pending")
	check(not blocked.state.load_state("spring-7") and blocked.state.favorite_id.is_empty(), "Migration does not expose a favorite before its new record is saved")
	check(not FileAccess.file_exists(blocked.path), "Failed migration leaves no incomplete primary record")
	check(DirAccess.remove_absolute(blocked.path + ".pending") == OK, "Remove the migration write blocker")
	check(_load(blocked.state, "spring-7") and blocked.state.favorite_id == "spring-7", "Migration can retry without losing the old favorite")


func _test_browser_storage() -> void:
	var storage := BrowserStorage.new()
	var fixture := _fixture("browser", storage)
	var state = fixture.state
	if not _load(state, "spring-7"):
		return
	check(storage.text is String and not FileAccess.file_exists(fixture.path), "Fresh browser state persists without waiting for filesystem sync")
	check(state.select_item("toy-space", {"space-1": 3}), "Browser selections persist through the host")
	var writes := storage.writes
	_write(fixture.path, "Broken old filesystem record")
	var reloaded = _script.new(fixture.path, storage)
	if _load(reloaded):
		check(reloaded.toy_id == "toy-space" and reloaded.favorite_id == "spring-7", "Immediate browser reload reads authoritative host selections")
		check(storage.writes == writes, "Loading an existing browser record never rewrites it")
	storage.writable = false
	var original: String = storage.text
	check(not reloaded.set_favorite("winter-10") and reloaded.favorite_id == "spring-7", "A browser write failure preserves the old visible favorite")
	check(storage.text == original, "A blocked write preserves durable browser bytes")
	storage.writable = true
	check(reloaded.set_favorite("winter-10"), "Browser preference writes recover on retry")
	storage.readable = false
	original = storage.text
	check(not reloaded.load_state() and reloaded.favorite_id == "winter-10", "Blocked browser reload preserves the previous in-memory room")
	check(not reloaded.select_item("toy-ball", {}) and storage.text == original, "A blocked browser reload disables writes")
	storage.readable = true
	check(_load(reloaded) and reloaded.select_item("toy-ball", {}), "A repaired browser read permits editing again")
	for value in [false, 1, "", "[playroom\n", _text(2), _text(1, "backdrop-home")]:
		storage.text = value
		writes = storage.writes
		check(not _corrupt_load(reloaded), "Invalid browser storage never falls back to filesystem state")
		check(not reloaded.set_favorite("spring-1") and storage.text == value and storage.writes == writes, "Invalid browser data is preserved without a write")
	var migrating_storage := BrowserStorage.new()
	var migration := _fixture("browser_migration", migrating_storage)
	_write(migration.path, _text(1, "toy-winter", "backdrop-home", "winter-10"))
	original = FileAccess.get_file_as_string(migration.path)
	if _load(migration.state, "spring-1"):
		check(migration.state.toy_id == "toy-winter" and migration.state.favorite_id == "winter-10", "An absent browser key imports the current native-format record before legacy favorite")
		check(migrating_storage.text is String and FileAccess.get_file_as_string(migration.path) == original, "Browser migration commits synchronously while retaining source bytes")
	var failed_storage := BrowserStorage.new()
	failed_storage.writable = false
	var failed := _fixture("browser_failed_migration", failed_storage)
	check(not failed.state.load_state("spring-7") and failed.state.favorite_id.is_empty(), "Failed browser migration cannot expose unsaved preferences")
	check(failed_storage.text == null and not FileAccess.file_exists(failed.path), "Failed browser migration leaves both stores unmodified")
	failed_storage.writable = true
	check(_load(failed.state, "spring-7") and failed.state.favorite_id == "spring-7", "The same browser migration succeeds after storage recovers")


func _cleanup() -> void:
	for path in _files:
		if FileAccess.file_exists(path):
			check(DirAccess.remove_absolute(path) == OK, "Remove only a known fixture file")
	_directories.reverse()
	for path in _directories:
		if DirAccess.dir_exists_absolute(path):
			check(DirAccess.remove_absolute(path) == OK, "Remove only an empty known fixture directory")

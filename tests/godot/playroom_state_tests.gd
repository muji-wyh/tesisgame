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
				var journey_ready: bool = _script.new().has_method("remember_visit") and _script.new().has_method("prefer_theme") and _script.new().has_method("suggested_adventure")
				check(journey_ready, "PlayroomState exposes journey memory and suggestions")
				if journey_ready:
					_test_journey_memory()
					_test_invalid_journey()
					_test_journey_failures()
				var stickers_ready: bool = _script.new().has_method("collect_words") and _script.new().has_method("display_word")
				check(stickers_ready, "PlayroomState exposes sticker collection and display")
				if stickers_ready:
					_test_sticker_memory()
					_test_invalid_stickers()
					_test_sticker_failures()
				var goals_ready: bool = _script.new().has_method("set_goal") and _script.new().has_method("selected_goal")
				check(goals_ready, "PlayroomState exposes saved gift selection and derived goal progress")
				if goals_ready:
					_test_selected_goal()
					_test_invalid_goal()
					_test_goal_failures()
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


func _topic_ids() -> Array[String]:
	var result: Array[String] = []
	for topic in load("res://scripts/game_data.gd").ADVENTURES:
		result.append(topic.id)
	return result


func _journey_text(recent: Variant, preferred: Variant) -> String:
	var config := ConfigFile.new()
	config.parse(_text(1, "toy-spring", "backdrop-home", "spring-7"))
	config.set_value("journey", "recent_topic_ids", recent)
	config.set_value("journey", "preferred_theme_id", preferred)
	return config.encode_to_text()


func _test_journey_memory() -> void:
	var topics := _topic_ids()
	var fixture := _fixture("journey_memory")
	var state = fixture.state
	check(not state.remember_visit(topics[0]) and not state.prefer_theme("spring"), "Journey writes require a successful load")
	var original := _text(1, "toy-spring", "backdrop-home", "spring-7")
	_write(fixture.path, original)
	if not _load(state):
		return
	check(state.recent_topic_ids.is_empty() and state.preferred_theme_id.is_empty(), "An old record without journey fields migrates to empty history and no preferred theme")
	check(FileAccess.get_file_as_string(fixture.path) == original, "Reading an old record does not rewrite its bytes")
	check(state.suggested_adventure() == topics[0], "A new journey suggests the first catalog topic")
	check(not state.remember_visit("unknown") and not state.prefer_theme("unknown"), "Unknown topics and themes are rejected")
	check(FileAccess.get_file_as_string(fixture.path) == original and state.recent_topic_ids.is_empty(), "Rejected journey changes preserve the old record and memory")
	check(state.remember_visit(topics[0]) and state.remember_visit(topics[2]), "Known topics are remembered")
	check(state.recent_topic_ids == [topics[2], topics[0]], "History is most recent first")
	check(state.suggested_adventure() == topics[1], "Suggestions use the first unvisited topic in catalog order")
	check(state.remember_visit(topics[0]) and state.recent_topic_ids == [topics[0], topics[2]], "Revisiting moves a topic to the front without duplicates")
	check(state.prefer_theme("ocean"), "A known preferred theme can be stored")
	var counts := {"spring-1": 3, "winter-3": 3}
	var before := counts.duplicate(true)
	check(state.select_item("backdrop-winter", counts) and state.set_favorite("winter-10"), "Room changes can be interleaved with journey memory")
	check(state.remember_visit(topics[1]) and state.select_item("toy-ball", counts), "Later journey and room changes both save")
	var reloaded = _script.new(fixture.path)
	if _load(reloaded):
		check(reloaded.recent_topic_ids == [topics[1], topics[0], topics[2]] and reloaded.preferred_theme_id == "ocean", "Room and favorite writes preserve every journey field")
		check(reloaded.toy_id == "toy-ball" and reloaded.backdrop_id == "backdrop-winter" and reloaded.favorite_id == "winter-10", "Journey writes preserve every room field")
	check(counts == before, "Journey and customization never mutate medal counts")
	for id in topics:
		check(state.remember_visit(id), "Every known topic can be visited")
	check(state.recent_topic_ids.size() == mini(12, topics.size()) and state.suggested_adventure() == topics[0], "A complete journey suggests its least recently visited topic and stays within twelve entries")
	check(state.remember_visit(topics[0]) and state.suggested_adventure() == topics[1], "Revisiting updates the least-recent suggestion")
	check(state.prefer_theme("") and state.preferred_theme_id.is_empty(), "The preferred theme can be cleared")
	_directory(fixture.path + ".pending")
	check(state.remember_visit(topics[0]) and state.prefer_theme(""), "Remembering the latest topic or same preference is idempotent without a write")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the known journey write blocker")
	var persisted := ConfigFile.new()
	check(persisted.load(fixture.path) == OK and persisted.get_value("playroom", "version") == 1, "Journey fields keep the existing playroom save version")


func _test_invalid_journey() -> void:
	var topics := _topic_ids()
	var oversized: Array = topics.duplicate()
	while oversized.size() <= 12:
		oversized.append(topics[0])
	var invalid: Array[String] = []
	for recent in [null, false, topics[0], {}, [topics[0], topics[0]], ["unknown"], [1], [topics[0], null], oversized]:
		invalid.append(_journey_text(recent, "spring"))
	for preferred in [null, false, 1, [], "unknown"]:
		invalid.append(_journey_text([topics[0]], preferred))
	for missing in ["recent_topic_ids", "preferred_theme_id"]:
		var config := ConfigFile.new()
		config.parse(_journey_text([], ""))
		config.erase_section_key("journey", missing)
		invalid.append(config.encode_to_text())
	for index in range(invalid.size()):
		var fixture := _fixture("journey_invalid_%d" % index)
		var state = fixture.state
		_write(fixture.path, _journey_text([topics[0]], "ocean"))
		if not _load(state):
			continue
		_write(fixture.path, invalid[index])
		check(not _corrupt_load(state), "Invalid present journey fields fail closed")
		check(state.recent_topic_ids == [topics[0]] and state.preferred_theme_id == "ocean" and state.toy_id == "toy-spring", "A failed journey reload preserves the last confirmed memory and room")
		check(not state.remember_visit(topics[1]) and not state.prefer_theme("winter") and not state.select_item("toy-ball", {}) and not state.set_favorite(""), "Invalid journey data blocks all record writes")
		check(FileAccess.get_file_as_string(fixture.path) == invalid[index], "Invalid journey bytes remain unchanged")


func _test_journey_failures() -> void:
	var topics := _topic_ids()
	var fixture := _fixture("journey_native_failure")
	var state = fixture.state
	if not _load(state, "spring-7"):
		return
	check(state.remember_visit(topics[0]) and state.prefer_theme("ocean"), "Prepare confirmed native journey state")
	var original := FileAccess.get_file_as_string(fixture.path)
	_directory(fixture.path + ".pending")
	check(not state.remember_visit(topics[1]) and not state.prefer_theme("winter"), "Native staging failures reject journey changes")
	check(state.recent_topic_ids == [topics[0]] and state.preferred_theme_id == "ocean" and state.toy_id == "toy-ball" and state.favorite_id == "spring-7", "Failed native journey writes preserve confirmed journey and room memory")
	check(FileAccess.get_file_as_string(fixture.path) == original, "Failed native journey writes preserve durable bytes")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove native journey blocker")
	check(_load(state) and state.remember_visit(topics[1]) and state.prefer_theme("winter"), "Journey writes retry after a successful reload")
	var storage := BrowserStorage.new()
	storage.text = _text(1, "toy-spring", "backdrop-home", "spring-7")
	var browser := _fixture("journey_browser", storage)
	state = browser.state
	if not _load(state):
		return
	check(state.recent_topic_ids.is_empty() and state.preferred_theme_id.is_empty() and storage.writes == 0, "Old browser records migrate optional journey fields without a write")
	check(state.remember_visit(topics[2]) and state.prefer_theme("space"), "Journey changes use the existing synchronous browser record")
	original = storage.text
	storage.writable = false
	check(not state.remember_visit(topics[3]) and not state.prefer_theme("autumn"), "Browser write failures reject journey changes")
	check(state.recent_topic_ids == [topics[2]] and state.preferred_theme_id == "space" and state.toy_id == "toy-spring" and state.favorite_id == "spring-7" and storage.text == original, "Browser write failure preserves journey, room, favorite, and saved bytes")
	storage.readable = false
	check(not state.load_state() and state.recent_topic_ids == [topics[2]], "Browser read failure preserves confirmed journey memory")
	storage.writable = true
	check(not state.remember_visit(topics[3]) and not state.prefer_theme("autumn") and storage.text == original, "An unsuccessful read blocks journey writes even after writes become available")
	storage.readable = true
	check(_load(state) and state.remember_visit(topics[3]) and state.set_favorite("winter-10"), "Browser journey and favorite writes recover through reload")
	var reloaded = _script.new(browser.path, storage)
	if _load(reloaded):
		check(reloaded.recent_topic_ids == [topics[3], topics[2]] and reloaded.preferred_theme_id == "space" and reloaded.favorite_id == "winter-10", "Browser reload retains interleaved history and favorite changes")
	storage.text = _journey_text(["unknown"], "space")
	var writes := storage.writes
	check(not _corrupt_load(reloaded) and not reloaded.remember_visit(topics[0]) and storage.writes == writes, "Invalid browser journey data fails closed without falling back or writing")
	check(storage.text == _journey_text(["unknown"], "space"), "Invalid browser journey bytes are preserved")


func _collect(state, ids: Array) -> bool:
	var words: Array[String] = []
	words.assign(ids)
	return state.collect_words(words)


func _sticker_text(words: Variant, displayed: Variant) -> String:
	var config := ConfigFile.new()
	config.parse(_journey_text(["animal-friends"], "ocean"))
	config.set_value("stickers", "word_ids", words)
	config.set_value("stickers", "display_word_id", displayed)
	return config.encode_to_text()


func _test_sticker_memory() -> void:
	var fixture := _fixture("sticker_memory")
	var state = fixture.state
	check(not _collect(state, ["cat"]) and not state.display_word(""), "Sticker writes require a successful load")
	var original := _journey_text(["animal-friends"], "ocean")
	_write(fixture.path, original)
	if not _load(state):
		return
	check(state.collected_word_ids.is_empty() and state.displayed_word_id.is_empty(), "An old room and journey record starts with no collected or displayed stickers")
	check(FileAccess.get_file_as_string(fixture.path) == original, "Reading a pre-sticker save preserves its original bytes")
	check(not state.display_word("cat") and not _collect(state, ["dog", "unknown"]), "Uncollected displays and partly invalid collection batches are rejected")
	check(state.collected_word_ids.is_empty() and FileAccess.get_file_as_string(fixture.path) == original, "Rejected sticker changes do not partially collect a batch")
	check(_collect(state, ["cat", "dog", "cat"]) and state.collected_word_ids == ["cat", "dog"], "A collection batch appends each valid discovery once in discovery order")
	check(state.display_word("cat") and state.displayed_word_id == "cat", "A collected word can be displayed")
	var counts := {"winter-1": 3, "winter-3": 3}
	var before := counts.duplicate(true)
	check(state.select_item("toy-winter", counts) and state.select_item("backdrop-winter", counts), "Toy and room changes coexist with stickers")
	check(state.set_favorite("winter-10") and state.remember_visit("music-makers") and state.prefer_theme("space"), "Favorite and journey changes coexist with stickers")
	check(_collect(state, ["bell", "cat"]) and state.collected_word_ids == ["cat", "dog", "bell"], "Later discoveries preserve prior sticker order and display")
	var reloaded = _script.new(fixture.path)
	if _load(reloaded):
		check(reloaded.collected_word_ids == ["cat", "dog", "bell"] and reloaded.displayed_word_id == "cat", "All existing room and journey operations preserve sticker collection and display through reload")
		check(reloaded.toy_id == "toy-winter" and reloaded.backdrop_id == "backdrop-winter" and reloaded.favorite_id == "winter-10", "Sticker writes preserve toy, backdrop and favorite")
		check(reloaded.recent_topic_ids == ["music-makers", "animal-friends"] and reloaded.preferred_theme_id == "space", "Sticker writes preserve journey history and preferred world")
	check(counts == before, "Collecting and displaying words never changes medal counts")
	_directory(fixture.path + ".pending")
	check(_collect(state, []) and _collect(state, ["bell", "cat", "bell"]) and state.display_word("cat"), "Empty and repeated sticker operations succeed without a storage write")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the known sticker write blocker")
	check(state.display_word("") and state.displayed_word_id.is_empty() and state.collected_word_ids == ["cat", "dog", "bell"], "Clearing the displayed word retains the collection")
	var ids: Array[String] = []
	for topic in load("res://scripts/game_data.gd").ADVENTURES:
		for id in topic.words:
			check(not ids.has(id), "Adventure vocabulary gives each sticker one canonical ID")
			ids.append(id)
	check(ids.size() == 140 and state.collect_words(ids), "All 140 vocabulary words can be collected")
	ids.clear()
	check(state.collected_word_ids.size() == 140, "Collection storage does not retain the caller's mutable input array")
	reloaded = _script.new(fixture.path)
	if _load(reloaded):
		check(reloaded.collected_word_ids.size() == 140 and reloaded.displayed_word_id.is_empty(), "The complete collection and cleared display survive native reload")
	var persisted := ConfigFile.new()
	check(persisted.load(fixture.path) == OK and persisted.get_value("playroom", "version") == 1, "Sticker persistence retains playroom save version one")


func _test_invalid_stickers() -> void:
	var oversized: Array = []
	oversized.resize(141)
	oversized.fill("cat")
	var invalid: Array[String] = []
	for words in [null, false, "cat", {}, ["cat", "cat"], ["unknown"], ["Cat"], [1], ["cat", null], oversized]:
		invalid.append(_sticker_text(words, ""))
	for displayed in [null, false, 1, [], "unknown", "dog"]:
		invalid.append(_sticker_text(["cat"], displayed))
	for missing in ["word_ids", "display_word_id"]:
		var config := ConfigFile.new()
		config.parse(_sticker_text([], ""))
		config.erase_section_key("stickers", missing)
		invalid.append(config.encode_to_text())
	for index in range(invalid.size()):
		var fixture := _fixture("sticker_invalid_%d" % index)
		var state = fixture.state
		_write(fixture.path, _sticker_text(["cat"], "cat"))
		if not _load(state):
			continue
		_write(fixture.path, invalid[index])
		check(not _corrupt_load(state) and not state.error.is_empty(), "Malformed present sticker sections fail explicitly")
		check(state.collected_word_ids == ["cat"] and state.displayed_word_id == "cat" and state.recent_topic_ids == ["animal-friends"] and state.toy_id == "toy-spring", "A failed sticker reload preserves the last confirmed collection and room")
		check(not _collect(state, ["dog"]) and not state.display_word("") and not state.select_item("toy-ball", {}) and not state.set_favorite("") and not state.remember_visit("music-makers") and not state.prefer_theme("winter"), "Invalid sticker data prevents every API from overwriting the record")
		check(FileAccess.get_file_as_string(fixture.path) == invalid[index], "Malformed sticker bytes remain unchanged")


func _test_sticker_failures() -> void:
	var fixture := _fixture("sticker_native_failure")
	var state = fixture.state
	_write(fixture.path, _sticker_text(["cat", "dog"], "cat"))
	if not _load(state):
		return
	var original := FileAccess.get_file_as_string(fixture.path)
	_directory(fixture.path + ".pending")
	check(not _collect(state, ["bell"]) and not state.display_word("dog"), "Failed native staging rejects collection and display changes")
	check(state.collected_word_ids == ["cat", "dog"] and state.displayed_word_id == "cat" and FileAccess.get_file_as_string(fixture.path) == original, "Failed native sticker writes preserve confirmed memory and durable bytes")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove native sticker staging blocker")
	check(_collect(state, ["bell"]) and state.display_word("dog"), "The same sticker changes can retry without reloading after storage recovers")
	original = FileAccess.get_file_as_string(fixture.path)
	if OS.get_name() == "Windows":
		var locked := FileAccess.open(fixture.path, FileAccess.READ)
		check(locked != null, "Hold only this fixture's sticker record open")
		if locked != null:
			check(not _collect(state, ["apple"]) and not state.display_word("bell"), "A native replacement lock rejects both sticker operations")
			check(state.collected_word_ids == ["cat", "dog", "bell"] and state.displayed_word_id == "dog" and FileAccess.get_file_as_string(fixture.path) == original, "Failed replacement cannot remove stickers or expose unsaved display changes")
			locked.close()
	var interrupted := _fixture("sticker_interrupted")
	_write(interrupted.path + ".previous", original)
	_write(interrupted.path + ".pending", _sticker_text(["apple"], "apple"))
	if _load(interrupted.state):
		check(interrupted.state.collected_word_ids == ["cat", "dog", "bell"] and interrupted.state.displayed_word_id == "dog", "Interrupted replacement restores the committed stickers rather than the staged collection")
	var storage := BrowserStorage.new()
	storage.text = _journey_text(["animal-friends"], "ocean")
	var browser := _fixture("sticker_browser", storage)
	state = browser.state
	if not _load(state):
		return
	check(state.collected_word_ids.is_empty() and state.displayed_word_id.is_empty() and storage.writes == 0, "Old browser records acquire empty sticker defaults without a migration write")
	check(_collect(state, ["cat", "dog"]) and state.display_word("cat"), "Browser sticker changes save synchronously through the existing host")
	var writes := storage.writes
	check(_collect(state, ["dog", "cat"]) and state.display_word("cat") and storage.writes == writes, "Repeated browser stickers do not write or reorder the saved collection")
	original = storage.text
	storage.writable = false
	check(not _collect(state, ["bell", "cat"]) and not state.display_word("dog"), "Browser write failures reject sticker changes")
	check(state.collected_word_ids == ["cat", "dog"] and state.displayed_word_id == "cat" and storage.text == original, "Failed browser saves retain confirmed sticker IDs, display and bytes")
	storage.writable = true
	check(_collect(state, ["bell", "cat"]) and state.display_word("dog"), "A pending browser batch retries once without duplicating its existing word")
	var reloaded = _script.new(browser.path, storage)
	if _load(reloaded):
		check(reloaded.collected_word_ids == ["cat", "dog", "bell"] and reloaded.displayed_word_id == "dog", "Immediate browser reload retains saved stickers")
	original = storage.text
	storage.readable = false
	check(not reloaded.load_state() and reloaded.collected_word_ids == ["cat", "dog", "bell"], "Failed browser reads retain confirmed sticker memory")
	check(not _collect(reloaded, ["apple"]) and not reloaded.display_word("") and storage.text == original, "A failed read blocks sticker writes until a successful reload")
	storage.readable = true
	check(_load(reloaded) and _collect(reloaded, ["apple"]), "Sticker writes recover after a readable record is loaded")
	storage.text = _sticker_text(["cat"], "dog")
	writes = storage.writes
	check(not _corrupt_load(reloaded) and not _collect(reloaded, ["bell"]) and storage.writes == writes and storage.text == _sticker_text(["cat"], "dog"), "Malformed browser stickers cannot fall back to or overwrite another store")
	var migration_storage := BrowserStorage.new()
	var migration := _fixture("sticker_browser_migration", migration_storage)
	_write(migration.path, _sticker_text(["cat"], "cat"))
	original = FileAccess.get_file_as_string(migration.path)
	migration_storage.writable = false
	check(not migration.state.load_state() and migration.state.collected_word_ids.is_empty() and migration_storage.text == null, "A failed browser migration does not expose unsaved source stickers")
	migration_storage.writable = true
	if _load(migration.state):
		check(migration.state.collected_word_ids == ["cat"] and migration.state.displayed_word_id == "cat" and FileAccess.get_file_as_string(migration.path) == original, "Browser migration preserves the native sticker section and original file")


func _goal_text(id: Variant) -> String:
	var config := ConfigFile.new()
	config.parse(_sticker_text(["cat"], "cat"))
	config.set_value("journey", "goal_item_id", id)
	return config.encode_to_text()


func _test_selected_goal() -> void:
	var fixture := _fixture("selected_goal")
	var state = fixture.state
	check(not state.set_goal("toy-ocean", {}), "Goal selection requires a successful load")
	var original := _sticker_text(["cat"], "cat")
	_write(fixture.path, original)
	if not _load(state):
		return
	check(state.goal_item_id.is_empty() and state.selected_goal({}).is_empty(), "Existing room, journey and sticker saves default to no selected goal")
	check(FileAccess.get_file_as_string(fixture.path) == original, "Reading an old goal-free record preserves its bytes")
	for id in ["", "unknown", "toy-ball", "backdrop-home", "toy-spring"]:
		check(not state.set_goal(id, {"spring-1": 3}), "Only known locked gifts can be selected as a goal: " + id)
	check(state.goal_item_id.is_empty() and FileAccess.get_file_as_string(fixture.path) == original, "Rejected goals do not change confirmed preferences or saved bytes")
	var counts := {"ocean-1": 3, "ocean-2": 1, "ocean-3": 1}
	var before := counts.duplicate(true)
	check(state.set_goal("backdrop-ocean", counts), "An unowned backdrop can be selected as the gift goal")
	check(state.goal_item_id == "backdrop-ocean" and state.preferred_theme_id == "ocean", "Selecting a goal also saves its world")
	var goal: Dictionary = state.selected_goal(counts)
	check(goal.id == "backdrop-ocean" and goal.remaining_pieces == 4, "A selected backdrop counts exactly the missing pieces of its first three medals")
	check(state.selected_goal({}).remaining_pieces == 9 and state.selected_goal({"ocean-1": 3, "ocean-2": 3, "ocean-3": 2}).remaining_pieces == 1, "Selected goals derive empty and last-piece progress directly from medal counts")
	check(state.selected_goal({"ocean-3": 3}).remaining_pieces == 0, "An owned sparse legacy backdrop is complete even when earlier medals are absent")
	check(not state.set_goal("backdrop-ocean", {"ocean-3": 3}) and state.goal_item_id == "backdrop-ocean", "An earned goal cannot be selected again but remains available for playing")
	check(counts == before, "Goal selection and progress reads never change medal counts")
	goal.name = "Changed by caller"
	check(state.selected_goal(counts).name != goal.name, "Goal metadata cannot mutate the catalog")
	check(state.select_item("toy-winter", {"winter-1": 3}) and state.select_item("backdrop-winter", {"winter-3": 3}) and state.set_favorite("winter-10"), "Room writes coexist with a selected goal")
	check(state.remember_visit("music-makers") and state.prefer_theme("space") and _collect(state, ["bell"]) and state.display_word("bell"), "Journey and sticker writes coexist with a selected goal")
	var reloaded = _script.new(fixture.path)
	if _load(reloaded):
		check(reloaded.goal_item_id == "backdrop-ocean" and reloaded.selected_goal(counts).remaining_pieces == 4, "Every room, journey and sticker write preserves the selected goal across reload")
		check(reloaded.toy_id == "toy-winter" and reloaded.backdrop_id == "backdrop-winter" and reloaded.favorite_id == "winter-10" and reloaded.preferred_theme_id == "space", "The saved goal preserves independent room and world choices")
		check(reloaded.collected_word_ids == ["cat", "bell"] and reloaded.displayed_word_id == "bell" and reloaded.recent_topic_ids == ["music-makers", "animal-friends"], "The saved goal preserves stickers and adventure history")
	check(state.set_goal("backdrop-ocean", counts) and state.preferred_theme_id == "ocean", "Resuming the same locked goal restores its world after another preference")
	_directory(fixture.path + ".pending")
	check(state.set_goal("backdrop-ocean", counts), "Repeating a goal with the same world is idempotent without a storage write")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the known goal write blocker")
	check(state.set_goal("toy-space", {}) and state.selected_goal({"space-1": 2}).remaining_pieces == 1, "A new toy goal replaces the old goal and reports its remaining piece")
	check(state.selected_goal({"space-1": 3}).remaining_pieces == 0, "A completed toy remains the selected goal with zero pieces remaining")


func _test_invalid_goal() -> void:
	for invalid in [false, 1, [], {}, "unknown", "space-1", "toy-ball", "backdrop-home"]:
		var storage := BrowserStorage.new()
		storage.text = _goal_text("toy-ocean")
		var fixture := _fixture("invalid_goal_%d" % _files.size(), storage)
		var state = fixture.state
		if not _load(state):
			continue
		storage.text = _goal_text(invalid)
		var original: String = storage.text
		check(not _corrupt_load(state) and not state.error.is_empty(), "Present invalid goal values are rejected")
		check(state.goal_item_id == "toy-ocean" and state.preferred_theme_id == "ocean" and state.toy_id == "toy-spring" and state.collected_word_ids == ["cat"], "A failed goal reload preserves the last confirmed goal, room, world and stickers")
		check(not state.set_goal("toy-space", {}) and not state.select_item("toy-ball", {}) and not state.set_favorite("") and not state.prefer_theme("winter") and not state.remember_visit("music-makers") and not _collect(state, ["bell"]) and not state.display_word(""), "An invalid goal blocks all record writes")
		check(storage.text == original and storage.writes == 0, "Invalid goal bytes remain untouched")
	var empty := _fixture("empty_goal")
	_write(empty.path, _goal_text(""))
	if _load(empty.state):
		check(empty.state.goal_item_id.is_empty() and empty.state.selected_goal({}).is_empty(), "An explicitly empty saved goal is valid")


func _test_goal_failures() -> void:
	var fixture := _fixture("goal_native_failure")
	var state = fixture.state
	_write(fixture.path, _goal_text("toy-ocean"))
	if not _load(state):
		return
	var original := FileAccess.get_file_as_string(fixture.path)
	_directory(fixture.path + ".pending")
	check(not state.set_goal("toy-space", {}), "A native staging failure rejects a goal and its world together")
	check(state.goal_item_id == "toy-ocean" and state.preferred_theme_id == "ocean" and state.toy_id == "toy-spring" and state.recent_topic_ids == ["animal-friends"] and state.displayed_word_id == "cat", "Failed native goal saves preserve all confirmed memory")
	check(FileAccess.get_file_as_string(fixture.path) == original, "Failed native goal saves preserve committed bytes")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the native goal staging blocker")
	check(state.set_goal("toy-space", {}), "A failed goal retries after native storage recovers")
	var storage := BrowserStorage.new()
	storage.text = _sticker_text(["cat"], "cat")
	var browser := _fixture("goal_browser", storage)
	state = browser.state
	if not _load(state):
		return
	check(state.goal_item_id.is_empty() and storage.writes == 0, "An old browser save gets the empty goal default without a migration write")
	check(state.set_goal("toy-space", {}) and storage.writes == 1, "The browser saves the selected goal and preferred world in one write")
	check(state.set_goal("toy-space", {}) and storage.writes == 1, "An unchanged browser goal does not write again")
	original = storage.text
	storage.writable = false
	check(not state.set_goal("toy-winter", {}) and state.goal_item_id == "toy-space" and state.preferred_theme_id == "space" and storage.text == original, "A failed browser save cannot expose either half of a new goal and world")
	storage.writable = true
	check(state.set_goal("toy-winter", {}), "A failed browser goal can retry")
	var reloaded = _script.new(browser.path, storage)
	if _load(reloaded):
		check(reloaded.goal_item_id == "toy-winter" and reloaded.preferred_theme_id == "winter" and reloaded.displayed_word_id == "cat", "Browser reload restores the goal and preserves its stickers")
	var migration_storage := BrowserStorage.new()
	var migration := _fixture("goal_browser_migration", migration_storage)
	_write(migration.path, _goal_text("toy-ocean"))
	original = FileAccess.get_file_as_string(migration.path)
	migration_storage.writable = false
	check(not migration.state.load_state() and migration.state.goal_item_id.is_empty() and migration.state.preferred_theme_id.is_empty(), "Failed browser migration exposes neither the native goal nor its preferred world")
	migration_storage.writable = true
	if _load(migration.state):
		check(migration.state.goal_item_id == "toy-ocean" and migration.state.preferred_theme_id == "ocean" and FileAccess.get_file_as_string(migration.path) == original, "Native-to-browser migration preserves the saved goal and original file")


func _cleanup() -> void:
	for path in _files:
		if FileAccess.file_exists(path):
			check(DirAccess.remove_absolute(path) == OK, "Remove only a known fixture file")
	_directories.reverse()
	for path in _directories:
		if DirAccess.dir_exists_absolute(path):
			check(DirAccess.remove_absolute(path) == OK, "Remove only an empty known fixture directory")

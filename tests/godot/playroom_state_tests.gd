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
				_test_invalid_records()
				_test_native_failures()
				_test_browser_storage()
				var ages_ready: bool = _script.new().has_method("set_age_band")
				check(ages_ready, "PlayroomState exposes a saved age preference")
				if ages_ready:
					_test_age_memory()
					_test_invalid_age()
					_test_age_failures()
				var journey_ready: bool = _script.new().has_method("remember_visit") and _script.new().has_method("prefer_theme")
				check(journey_ready, "PlayroomState exposes journey memory")
				if journey_ready:
					_test_journey_memory()
					_test_invalid_journey()
					_test_journey_failures()
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
	check(entries.size() == 18, "The catalog contains two starters and sixteen world gifts")
	var toys: Array = state.toys()
	check(toys.size() == 9 and toys.all(func(entry: Dictionary) -> bool: return entry.slot == "toy")
		and toys.any(func(entry: Dictionary) -> bool: return entry.id == "toy-ball"),
		"The active toy catalog contains only the starter ball and eight world toys")
	check(toys == entries.filter(func(entry: Dictionary) -> bool: return entry.slot == "toy"),
		"Filtering active toys preserves canonical metadata while retaining legacy backdrops in the compatibility catalog")
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
	for row in [["spring", "flower", "water"], ["summer", "ball", "roll"], ["autumn", "apple", "offer"], ["winter", "bell", "ring"], ["ocean", "shell", "open"], ["space", "rocket", "launch"], ["jungle", "monkey", "swing"], ["candy", "cake", "decorate"]]:
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
	toys[0].name = "Changed toy"
	check(state.toys()[0].name == "Ball", "Returned toy entries cannot mutate later active catalog lookups")


func _test_selection_and_reload() -> void:
	var fixture := _fixture("selection")
	var state = fixture.state
	check(not state.select_item("toy-ball", {}) and not state.prefer_theme("spring"), "Loading must succeed before any selection can write")
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
	var reloaded = _script.new(fixture.path)
	if _load(reloaded, "invalid-old-favorite"):
		check(reloaded.toy_id == "toy-spring" and reloaded.backdrop_id == "backdrop-spring" and reloaded.favorite_id == "spring-1", "Toy, backdrop, and archived favorite survive native reload; saved state takes precedence over legacy")
	_directory(fixture.path + ".pending")
	check(state.select_item("toy-spring", counts) and state.select_item("backdrop-spring", counts), "Repeated selections are idempotent without another write")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the known write blocker")


func _test_invalid_records() -> void:
	var invalid: Array = ["", "[playroom\n", _text(null), _text(2), _text(1.0), _text(true), _text(1, null), _text(1, 5), _text(1, "unknown"), _text(1, "backdrop-home"), _text(1, "toy-ball", null), _text(1, "toy-ball", "toy-ball"), _text(1, "toy-ball", "backdrop-home", null), _text(1, "toy-ball", "backdrop-home", 1), _text(1, "toy-ball", "backdrop-home", "unknown")]
	for index in range(invalid.size()):
		var fixture := _fixture("invalid_%d" % index)
		_write(fixture.path, invalid[index])
		var state = fixture.state
		check(not _corrupt_load(state) and not state.error.is_empty(), "Invalid or unsupported playroom records fail explicitly")
		check(not state.select_item("toy-ball", {}) and not state.prefer_theme("spring"), "A failed load blocks later overwrites")
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
			check(not state.prefer_theme("winter"), "A locked previous save blocks replacement")
			check(state.preferred_theme_id.is_empty() and state.favorite_id == "spring-7" and FileAccess.get_file_as_string(fixture.path) == original, "Failed replacement cannot delete the old file or expose new state")
			locked.close()
			check(state.prefer_theme("winter"), "The world preference retries after the native lock is released")
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
	check(not reloaded.prefer_theme("winter") and reloaded.preferred_theme_id.is_empty() and reloaded.favorite_id == "spring-7", "A browser write failure preserves the confirmed world and archived favorite")
	check(storage.text == original, "A blocked write preserves durable browser bytes")
	storage.writable = true
	check(reloaded.prefer_theme("winter"), "Browser preference writes recover on retry")
	storage.readable = false
	original = storage.text
	check(not reloaded.load_state() and reloaded.preferred_theme_id == "winter" and reloaded.favorite_id == "spring-7", "Blocked browser reload preserves the previous in-memory room")
	check(not reloaded.select_item("toy-ball", {}) and storage.text == original, "A blocked browser reload disables writes")
	storage.readable = true
	check(_load(reloaded) and reloaded.select_item("toy-ball", {}), "A repaired browser read permits editing again")
	for value in [false, 1, "", "[playroom\n", _text(2), _text(1, "backdrop-home")]:
		storage.text = value
		writes = storage.writes
		check(not _corrupt_load(reloaded), "Invalid browser storage never falls back to filesystem state")
		check(not reloaded.prefer_theme("spring") and storage.text == value and storage.writes == writes, "Invalid browser data is preserved without a write")
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
	for topic in load("res://scripts/game_data.gd").adventures():
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
	check(not state.remember_visit("unknown") and not state.prefer_theme("unknown"), "Unknown topics and themes are rejected")
	check(FileAccess.get_file_as_string(fixture.path) == original and state.recent_topic_ids.is_empty(), "Rejected journey changes preserve the old record and memory")
	check(state.remember_visit(topics[0]) and state.remember_visit(topics[2]), "Known topics are remembered")
	check(state.recent_topic_ids == [topics[2], topics[0]], "History is most recent first")
	check(state.remember_visit(topics[0]) and state.recent_topic_ids == [topics[0], topics[2]], "Revisiting moves a topic to the front without duplicates")
	check(state.prefer_theme("ocean"), "A known preferred theme can be stored")
	var counts := {"spring-1": 3, "winter-3": 3}
	var before := counts.duplicate(true)
	check(state.select_item("backdrop-winter", counts) and state.set_age_band("7-9"), "Room and age changes can be interleaved with journey memory")
	check(state.remember_visit(topics[1]) and state.select_item("toy-ball", counts), "Later journey and room changes both save")
	var reloaded = _script.new(fixture.path)
	if _load(reloaded):
		check(reloaded.recent_topic_ids == [topics[1], topics[0], topics[2]] and reloaded.preferred_theme_id == "ocean", "Room and age writes preserve every journey field")
		check(reloaded.toy_id == "toy-ball" and reloaded.backdrop_id == "backdrop-winter" and reloaded.favorite_id == "spring-7" and reloaded.age_band_id == "7-9", "Journey writes preserve room, age, and archived favorite fields")
	check(counts == before, "Journey and customization never mutate medal counts")
	for id in topics:
		check(state.remember_visit(id), "Every known topic can be visited")
	check(state.recent_topic_ids.size() == mini(12, topics.size()) and state.recent_topic_ids.front() == topics.back(), "Journey history stays within twelve entries with the latest visit first")
	check(state.remember_visit(topics[0]) and state.recent_topic_ids.front() == topics[0], "Revisiting updates the latest topic")
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
		check(not state.remember_visit(topics[1]) and not state.prefer_theme("winter") and not state.select_item("toy-ball", {}) and not state.set_age_band("7-9"), "Invalid journey data blocks active preference writes")
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
	check(_load(state) and state.remember_visit(topics[3]) and state.set_age_band("7-9"), "Browser journey and age writes recover through reload")
	var reloaded = _script.new(browser.path, storage)
	if _load(reloaded):
		check(reloaded.recent_topic_ids == [topics[3], topics[2]] and reloaded.preferred_theme_id == "space" and reloaded.favorite_id == "spring-7" and reloaded.age_band_id == "7-9", "Browser reload retains interleaved history and age changes without losing the archived favorite")
	storage.text = _journey_text(["unknown"], "space")
	var writes := storage.writes
	check(not _corrupt_load(reloaded) and not reloaded.remember_visit(topics[0]) and storage.writes == writes, "Invalid browser journey data fails closed without falling back or writing")
	check(storage.text == _journey_text(["unknown"], "space"), "Invalid browser journey bytes are preserved")


func _sticker_text(words: Variant, displayed: Variant) -> String:
	var config := ConfigFile.new()
	config.parse(_journey_text(["animal-friends"], "ocean"))
	config.set_value("stickers", "word_ids", words)
	config.set_value("stickers", "display_word_id", displayed)
	return config.encode_to_text()


func _test_sticker_memory() -> void:
	var fixture := _fixture("sticker_memory")
	var state = fixture.state
	var original := _journey_text(["animal-friends"], "ocean")
	_write(fixture.path, original)
	if not _load(state):
		return
	check(state.collected_word_ids.is_empty() and state.displayed_word_id.is_empty(), "A pre-sticker save defaults to no collected or displayed words")
	check(FileAccess.get_file_as_string(fixture.path) == original, "Reading a pre-sticker save preserves its original bytes")
	original = _sticker_text(["cat", "dog", "bell"], "cat")
	_write(fixture.path, original)
	if not _load(state):
		return
	check(state.collected_word_ids == ["cat", "dog", "bell"] and state.displayed_word_id == "cat", "Archived stickers retain their discovery order and displayed word")
	check(FileAccess.get_file_as_string(fixture.path) == original, "Reading archived stickers never rewrites them")
	var counts := {"winter-1": 3, "winter-3": 3}
	var before := counts.duplicate(true)
	check(state.select_item("toy-winter", counts) and state.select_item("backdrop-winter", counts), "Toy and room changes preserve archived stickers")
	check(state.remember_visit("music-makers") and state.prefer_theme("space") and state.set_age_band("7-9"), "Journey and age changes preserve archived stickers")
	var reloaded = _script.new(fixture.path)
	if _load(reloaded):
		check(reloaded.collected_word_ids == ["cat", "dog", "bell"] and reloaded.displayed_word_id == "cat", "Active preference writes preserve the exact legacy collection and display through reload")
		check(reloaded.toy_id == "toy-winter" and reloaded.backdrop_id == "backdrop-winter" and reloaded.favorite_id == "spring-7", "Active writes retain the archived favorite alongside room choices")
		check(reloaded.recent_topic_ids == ["music-makers", "animal-friends"] and reloaded.preferred_theme_id == "space" and reloaded.age_band_id == "7-9", "Journey and age choices survive interleaved saves")
	check(counts == before, "Preference writes never change medal counts")
	_directory(fixture.path + ".pending")
	check(state.select_item("toy-winter", counts) and state.remember_visit("music-makers") and state.prefer_theme("space") and state.set_age_band("7-9"), "Repeated active preferences succeed without a storage write")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the known legacy-preservation write blocker")
	var ids: Array[String] = []
	for topic in load("res://scripts/game_data.gd").adventures():
		for id in topic.words:
			check(not ids.has(id), "Adventure vocabulary gives each archived sticker one canonical ID")
			ids.append(id)
	check(ids.size() == 1250, "The archive validator recognizes all 1,250 vocabulary IDs")
	_write(fixture.path, _sticker_text(ids, ""))
	if not _load(state):
		return
	check(state.collected_word_ids == ids and state.displayed_word_id.is_empty(), "A complete archived collection with an empty display remains readable")
	check(state.set_age_band("10-plus"), "An active preference can be saved beside a complete archive")
	reloaded = _script.new(fixture.path)
	if _load(reloaded):
		check(reloaded.collected_word_ids == ids and reloaded.displayed_word_id.is_empty(), "The complete archived collection and empty display survive an active write and reload")
	var persisted := ConfigFile.new()
	check(persisted.load(fixture.path) == OK and persisted.get_value("playroom", "version") == 1, "Preserving archived stickers retains save version one")


func _test_invalid_stickers() -> void:
	var oversized: Array = []
	oversized.resize(201)
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
		check(not state.select_item("toy-ball", {}) and not state.remember_visit("music-makers") and not state.prefer_theme("winter") and not state.set_age_band("7-9") and not state.set_goal("toy-space", {}), "Invalid sticker data prevents every API from overwriting the record")
		check(FileAccess.get_file_as_string(fixture.path) == invalid[index], "Malformed sticker bytes remain unchanged")


func _test_sticker_failures() -> void:
	var fixture := _fixture("sticker_native_failure")
	var state = fixture.state
	_write(fixture.path, _sticker_text(["cat", "dog"], "cat"))
	if not _load(state):
		return
	var original := FileAccess.get_file_as_string(fixture.path)
	_directory(fixture.path + ".pending")
	check(not state.prefer_theme("winter") and not state.set_age_band("7-9"), "Failed native staging rejects active preference changes beside archived stickers")
	check(state.collected_word_ids == ["cat", "dog"] and state.displayed_word_id == "cat" and FileAccess.get_file_as_string(fixture.path) == original, "Failed native saves preserve archived stickers and durable bytes")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove native staging blocker")
	check(state.prefer_theme("winter") and state.set_age_band("7-9"), "The same preferences retry without reloading after storage recovers")
	original = FileAccess.get_file_as_string(fixture.path)
	if OS.get_name() == "Windows":
		var locked := FileAccess.open(fixture.path, FileAccess.READ)
		check(locked != null, "Hold only this fixture's archived record open")
		if locked != null:
			check(not state.prefer_theme("space") and not state.set_age_band("10-plus"), "A native replacement lock rejects active preference writes")
			check(state.collected_word_ids == ["cat", "dog"] and state.displayed_word_id == "cat" and state.preferred_theme_id == "winter" and state.age_band_id == "7-9" and FileAccess.get_file_as_string(fixture.path) == original, "Failed replacement preserves archived fields and confirmed preferences")
			locked.close()
	var interrupted := _fixture("sticker_interrupted")
	_write(interrupted.path + ".previous", original)
	_write(interrupted.path + ".pending", _sticker_text(["apple"], "apple"))
	if _load(interrupted.state):
		check(interrupted.state.collected_word_ids == ["cat", "dog"] and interrupted.state.displayed_word_id == "cat", "Interrupted replacement restores committed archived stickers rather than the staged collection")
	var storage := BrowserStorage.new()
	storage.text = _sticker_text(["cat", "dog"], "cat")
	var browser := _fixture("sticker_browser", storage)
	state = browser.state
	if not _load(state):
		return
	check(state.collected_word_ids == ["cat", "dog"] and state.displayed_word_id == "cat" and storage.writes == 0, "Browser loading preserves archived stickers without a migration write")
	check(state.prefer_theme("winter") and state.set_age_band("7-9"), "Active browser preferences save synchronously beside archived stickers")
	var writes := storage.writes
	check(state.prefer_theme("winter") and state.set_age_band("7-9") and storage.writes == writes, "Repeated browser preferences do not rewrite the archived collection")
	original = storage.text
	storage.writable = false
	check(not state.prefer_theme("space") and not state.set_age_band("10-plus"), "Browser write failures reject preference changes")
	check(state.collected_word_ids == ["cat", "dog"] and state.displayed_word_id == "cat" and storage.text == original, "Failed browser saves retain exact archived sticker IDs, display and bytes")
	storage.writable = true
	check(state.prefer_theme("space") and state.set_age_band("10-plus"), "Browser preferences retry after storage recovers")
	var reloaded = _script.new(browser.path, storage)
	if _load(reloaded):
		check(reloaded.collected_word_ids == ["cat", "dog"] and reloaded.displayed_word_id == "cat" and reloaded.preferred_theme_id == "space" and reloaded.age_band_id == "10-plus", "Immediate browser reload retains archived stickers and retried preferences")
	original = storage.text
	storage.readable = false
	check(not reloaded.load_state() and reloaded.collected_word_ids == ["cat", "dog"], "Failed browser reads retain confirmed sticker memory")
	check(not reloaded.prefer_theme("spring") and not reloaded.set_age_band("all") and storage.text == original, "A failed read blocks preference writes until a successful reload")
	storage.readable = true
	check(_load(reloaded) and reloaded.prefer_theme("spring"), "Preference writes recover after a readable record is loaded")
	storage.text = _sticker_text(["cat"], "dog")
	writes = storage.writes
	check(not _corrupt_load(reloaded) and not reloaded.set_age_band("all") and storage.writes == writes and storage.text == _sticker_text(["cat"], "dog"), "Malformed browser stickers cannot fall back to or overwrite another store")
	var migration_storage := BrowserStorage.new()
	var migration := _fixture("sticker_browser_migration", migration_storage)
	_write(migration.path, _sticker_text(["cat"], "cat"))
	original = FileAccess.get_file_as_string(migration.path)
	migration_storage.writable = false
	check(not migration.state.load_state() and migration.state.collected_word_ids.is_empty() and migration_storage.text == null, "A failed browser migration does not expose unsaved source stickers")
	migration_storage.writable = true
	if _load(migration.state):
		check(migration.state.collected_word_ids == ["cat"] and migration.state.displayed_word_id == "cat" and FileAccess.get_file_as_string(migration.path) == original, "Browser migration preserves the native sticker section and original file")


func _age_text(id: Variant) -> String:
	var config := ConfigFile.new()
	config.parse(_text())
	config.set_value("learning", "age_band", id)
	return config.encode_to_text()


func _test_age_memory() -> void:
	var fixture := _fixture("age_memory")
	var state = fixture.state
	check(not state.set_age_band("4-6"), "Age selection requires a successful load")
	var original := _sticker_text(["sunflower"], "sunflower")
	_write(fixture.path, original)
	if not _load(state):
		return
	check(state.age_band_id == "all" and FileAccess.get_file_as_string(fixture.path) == original,
		"An older save defaults to all words without rewriting the record")
	for id in ["", "unknown", "7-10"]:
		check(not state.set_age_band(id) and not state.error.is_empty() and state.age_band_id == "all",
			"Unknown age choices fail explicitly without changing the preference")
	for id in ["4-6", "7-9", "10-plus", "all"]:
		check(state.set_age_band(id), "Every offered age level can be saved")
		var reloaded = _script.new(fixture.path)
		check(_load(reloaded) and reloaded.age_band_id == id, "The chosen age survives immediate native reload")
	check(state.set_age_band("7-9"), "Set the age before interleaved preference writes")
	var counts := {"winter-1": 3, "winter-3": 3}
	var before := counts.duplicate(true)
	check(state.select_item("toy-winter", counts) and state.select_item("backdrop-winter", counts)
		and state.remember_visit("music-makers") and state.prefer_theme("space")
		and state.set_goal("toy-ocean", counts),
		"Active preference setters remain available with an age level and archived stickers")
	var reloaded = _script.new(fixture.path)
	if _load(reloaded):
		check(reloaded.age_band_id == "7-9" and reloaded.toy_id == "toy-winter"
			and reloaded.favorite_id == "spring-7" and reloaded.displayed_word_id == "sunflower"
			and reloaded.goal_item_id == "toy-ocean" and counts == before,
			"Interleaved saves preserve age, earned items, stickers and medal counts")
	_directory(fixture.path + ".pending")
	check(state.set_age_band("7-9"), "Repeating a confirmed age needs no write")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the age idempotency blocker")
	var fresh := _fixture("age_fresh")
	check(_load(fresh.state) and fresh.state.age_band_id == "all", "New players retain the all-words default")
	var config := ConfigFile.new()
	config.parse(_text())
	config.set_value("learning", "future_option", true)
	var missing := _fixture("age_missing_key")
	_write(missing.path, config.encode_to_text())
	check(_load(missing.state) and missing.state.age_band_id == "all", "A missing optional age key defaults to all words")
	_write(missing.path, _age_text(null))
	check(_load(missing.state) and missing.state.age_band_id == "all", "ConfigFile's null-key deletion retains the missing-age default")


func _test_invalid_age() -> void:
	var invalid: Array = [false, 7, 7.0, [], {}, "", "unknown", "4"]
	for index in range(invalid.size()):
		var fixture := _fixture("age_invalid_%d" % index)
		var state = fixture.state
		_write(fixture.path, _age_text("7-9"))
		if not _load(state):
			continue
		var original := _age_text(invalid[index])
		_write(fixture.path, original)
		check(not _corrupt_load(state) and not state.error.is_empty() and state.age_band_id == "7-9",
			"Malformed supplied age values fail while preserving the confirmed preference")
		check(not state.set_age_band("all") and not state.select_item("toy-ball", {})
			and FileAccess.get_file_as_string(fixture.path) == original,
			"An invalid age record cannot be overwritten through later setters")
	var storage := BrowserStorage.new()
	storage.text = _age_text("10-plus")
	var browser := _fixture("age_invalid_browser", storage)
	if not _load(browser.state):
		return
	storage.text = _age_text("unknown")
	var writes := storage.writes
	check(not browser.state.load_state() and not browser.state.set_age_band("all")
		and storage.writes == writes and browser.state.age_band_id == "10-plus",
		"Malformed browser age data fails closed without overwriting saved choices")


func _test_age_failures() -> void:
	var fixture := _fixture("age_native_failure")
	var state = fixture.state
	if not _load(state):
		return
	var original := FileAccess.get_file_as_string(fixture.path)
	_directory(fixture.path + ".pending")
	check(not state.set_age_band("4-6") and not state.error.is_empty() and state.age_band_id == "all"
		and FileAccess.get_file_as_string(fixture.path) == original,
		"A failed native age write preserves the visible choice and original bytes")
	check(DirAccess.remove_absolute(fixture.path + ".pending") == OK, "Remove the native age write blocker")
	check(state.set_age_band("4-6") and state.age_band_id == "4-6", "Age selection retries after native storage recovers")
	var storage := BrowserStorage.new()
	storage.text = _text()
	var browser := _fixture("age_browser_failure", storage)
	state = browser.state
	if not _load(state):
		return
	check(state.age_band_id == "all" and storage.writes == 0, "Legacy browser age defaults require no write")
	check(state.set_age_band("7-9"), "An age selection saves synchronously to browser storage")
	var writes := storage.writes
	check(state.set_age_band("7-9") and storage.writes == writes, "Repeated browser age choices are idempotent")
	original = storage.text
	storage.writable = false
	check(not state.set_age_band("10-plus") and not state.error.is_empty() and state.age_band_id == "7-9"
		and storage.text == original, "A failed browser write never exposes an unsaved age")
	storage.writable = true
	check(state.set_age_band("10-plus"), "The same browser age selection can retry")
	var reloaded = _script.new(browser.path, storage)
	check(_load(reloaded) and reloaded.age_band_id == "10-plus", "Browser reload retains the retried age")
	storage.readable = false
	check(not reloaded.load_state() and not reloaded.set_age_band("all") and reloaded.age_band_id == "10-plus",
		"A failed read preserves age but blocks writes until a successful reload")
	storage.readable = true
	check(_load(reloaded) and reloaded.set_age_band("all"), "Age choices recover after storage can be read again")
	var migration_storage := BrowserStorage.new()
	var migration := _fixture("age_browser_migration", migration_storage)
	original = _age_text("10-plus")
	_write(migration.path, original)
	migration_storage.writable = false
	check(not migration.state.load_state() and migration.state.age_band_id == "all"
		and migration_storage.text == null, "Failed migration cannot expose an unpersisted age")
	migration_storage.writable = true
	check(_load(migration.state) and migration.state.age_band_id == "10-plus"
		and FileAccess.get_file_as_string(migration.path) == original,
		"Migration preserves the parsed native age and original native bytes")
	var migrated = _script.new(migration.path, migration_storage)
	check(_load(migrated) and migrated.age_band_id == "10-plus", "The migrated browser record contains the parsed age, not the default")


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
	check(state.set_goal("backdrop-ocean", counts), "The compatibility API can seed a previously selected backdrop goal")
	check(state.goal_item_id == "backdrop-ocean" and state.preferred_theme_id == "ocean", "A legacy goal record retains its associated world")
	var goal: Dictionary = state.selected_goal(counts)
	check(goal.id == "backdrop-ocean" and goal.remaining_pieces == 4, "Reading legacy selected-goal data preserves its original three-medal progress")
	check(state.selected_goal({}).remaining_pieces == 9 and state.selected_goal({"ocean-1": 3, "ocean-2": 3, "ocean-3": 2}).remaining_pieces == 1, "Selected goals derive empty and last-piece progress directly from medal counts")
	check(state.selected_goal({"ocean-3": 3}).remaining_pieces == 0, "An owned sparse legacy backdrop is complete even when earlier medals are absent")
	check(not state.set_goal("backdrop-ocean", {"ocean-3": 3}) and state.goal_item_id == "backdrop-ocean", "An earned legacy goal cannot be selected again but remains preserved as saved data")
	check(counts == before, "Goal selection and progress reads never change medal counts")
	goal.name = "Changed by caller"
	check(state.selected_goal(counts).name != goal.name, "Goal metadata cannot mutate the catalog")
	check(state.select_item("toy-winter", {"winter-1": 3}) and state.select_item("backdrop-winter", {"winter-3": 3}), "Room writes coexist with a selected goal")
	check(state.remember_visit("music-makers") and state.prefer_theme("space") and state.set_age_band("7-9"), "Journey and age writes coexist with a selected goal")
	var reloaded = _script.new(fixture.path)
	if _load(reloaded):
		check(reloaded.goal_item_id == "backdrop-ocean" and reloaded.selected_goal(counts).remaining_pieces == 4, "Every room, journey and age write preserves the selected goal across reload")
		check(reloaded.toy_id == "toy-winter" and reloaded.backdrop_id == "backdrop-winter" and reloaded.favorite_id == "spring-7" and reloaded.preferred_theme_id == "space", "The saved goal preserves independent room, world, and archived favorite choices")
		check(reloaded.collected_word_ids == ["cat"] and reloaded.displayed_word_id == "cat" and reloaded.recent_topic_ids == ["music-makers", "animal-friends"] and reloaded.age_band_id == "7-9", "The saved goal preserves archived stickers, adventure history, and age")
	check(state.set_goal("backdrop-ocean", counts) and state.preferred_theme_id == "ocean", "The compatibility API preserves a legacy goal's world without requiring a visible Rooms route")
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
		check(not state.set_goal("toy-space", {}) and not state.select_item("toy-ball", {}) and not state.prefer_theme("winter") and not state.remember_visit("music-makers") and not state.set_age_band("7-9"), "An invalid goal blocks all record writes")
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

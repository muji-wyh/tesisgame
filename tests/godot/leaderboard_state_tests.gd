extends SceneTree

const State = preload("res://scripts/leaderboard_state.gd")

var checks: int = 0
var failures: int = 0
var _root: String
var _files: Array[String] = []


class BrowserStorage extends RefCounted:
	var text: Variant = null
	var readable: bool = true
	var writable: bool = true
	var writes: int = 0

	func leaderboardState() -> Variant:
		return text if readable else false

	func saveLeaderboardState(value: String) -> bool:
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
	_root = "user://leaderboard_state_tests_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_absolute(_root) == OK, "Create isolated state fixture directory")
	_test_profiles()
	_test_browser_fixture()
	_test_pop_ranking()
	_test_other_modes()
	_test_invalid_results()
	_test_browser_failures()
	_test_invalid_saves()
	_test_native_persistence()
	_test_receipt_limit()
	for path in _files:
		if FileAccess.file_exists(path):
			check(DirAccess.remove_absolute(path) == OK, "Remove isolated fixture file")
	check(DirAccess.remove_absolute(_root) == OK, "Remove isolated fixture directory")
	print("Leaderboard state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _browser() -> Dictionary:
	var storage := BrowserStorage.new()
	var state := State.new("user://unused-leaderboard-test.cfg", storage)
	check(state.load_state() and state.ready and state.error.is_empty(), "A fresh browser state is ready")
	return {"state": state, "storage": storage}


func _profile(state, player_name: String = "Avery", avatar: String = "duck") -> String:
	var outcome: Dictionary = state.create_profile(player_name, avatar)
	check(outcome.ok, "Create player: " + outcome.get("error", ""))
	return outcome.get("profile", {}).get("id", "")


func _submit(state, player_id: String, mode: String, result: Dictionary, round_id: String = "") -> Dictionary:
	var outcome: Dictionary = state.submit_round(State.make_round_id() if round_id.is_empty() else round_id, mode, player_id, result)
	check(outcome.ok, "Save %s result: %s" % [mode, outcome.get("error", "")])
	return outcome


func _text(saved_profiles: Variant = [], bests: Variant = {"pop": {}, "match": {}, "memory": {}}, receipts: Variant = [], version: Variant = 1) -> String:
	var config := ConfigFile.new()
	config.set_value("leaderboard", "version", version)
	config.set_value("leaderboard", "profiles", saved_profiles)
	config.set_value("leaderboard", "bests", bests)
	config.set_value("leaderboard", "receipts", receipts)
	return config.encode_to_text()


func _test_profiles() -> void:
	var fixture := _browser()
	var state = fixture.state
	check(state.profiles.is_empty() and state.board("pop").is_empty(), "A new device has no players or scores")
	check(fixture.storage.writes == 0 and fixture.storage.text == null, "Opening a new leaderboard does not write an empty save")
	check(state.board("unknown").is_empty(), "Unknown modes produce an empty read-only board")
	var first := _profile(state, "  Avery  ", "fox")
	check(state.profiles[0].name == "Avery" and state.profiles[0].avatar == "fox", "Names are trimmed and avatars are retained")
	var second := _profile(state, "Zoë", "panda")
	check(first != second and state.profiles[1].name == "Zoë", "Unicode names get unique stable player IDs")
	var saved: String = fixture.storage.text
	for invalid in ["", "   ", "A".repeat(21), "New\nName", "New\tName", "New" + String.chr(127) + "Name", "New" + String.chr(0x202e) + "Name"]:
		check(not state.create_profile(invalid, "duck").ok, "Empty, long, or control-character names are rejected")
		check(fixture.storage.text == saved and state.profiles.size() == 2, "Invalid names do not modify storage or players")
	check(not state.create_profile("Blake", "unknown").ok, "Unknown avatar IDs are rejected")
	for index in range(8):
		_profile(state, "Player %d" % index, State.AVATARS[index])
	check(state.profiles.size() == State.MAX_PROFILES, "Ten players fit on a device")
	check(not state.create_profile("Eleven", "duck").ok, "An eleventh player cannot be added")
	var reloaded := State.new("user://unused-leaderboard-test.cfg", fixture.storage)
	check(reloaded.load_state() and reloaded.profiles == state.profiles, "All profile data survives reload")
	var ids: Dictionary = {}
	for index in range(100):
		var id := State.make_round_id()
		check(not ids.has(id), "Rapid round IDs stay unique")
		ids[id] = true


func _test_browser_fixture() -> void:
	var storage := BrowserStorage.new()
	storage.text = "[leaderboard]\nversion=1\nprofiles=[{\"id\":\"player-a\",\"name\":\"Avery\",\"avatar\":\"fox\"},{\"id\":\"player-b\",\"name\":\"Blake\",\"avatar\":\"duck\"}]\nbests={\"pop\":{\"player-a\":{\"hits\":1},\"player-b\":{\"hits\":0}},\"match\":{},\"memory\":{}}\nreceipts=[]\n"
	var state := State.new("user://unused-leaderboard-test.cfg", storage)
	check(state.load_state(), "The compact browser automation seed is a valid ConfigFile save")
	var climbed := _submit(state, "player-b", "pop", {"hits": 1})
	check(climbed.improved and climbed.old_rank == 2 and climbed.new_rank == 1, "One natural hit in the browser fixture earns a tie at first place")


func _test_pop_ranking() -> void:
	var fixture := _browser()
	var state = fixture.state
	var a := _profile(state, "Avery", "fox")
	var b := _profile(state, "Blake", "cat")
	var c := _profile(state, "Casey", "frog")
	var entered := _submit(state, a, "pop", {"hits": 10, "score": 999, "misses": 5})
	check(entered.first_entry and entered.personal_best and not entered.improved and entered.old_rank == 0 and entered.new_rank == 1, "First entries are distinct from rank improvements")
	_submit(state, b, "pop", {"hits": 10})
	_submit(state, c, "pop", {"hits": 2})
	var board: Array = state.board("pop")
	check(board.map(func(row: Dictionary) -> int: return row.rank) == [1, 1, 3], "Equal hits share competition ranks")
	check(board[0].player_id == a and board[1].player_id == b, "Tied display order follows player creation")
	check(board[0].metric == 10 and board[0].label == "10 hits" and board[0].avatar == "fox", "Rows carry complete presentation metadata")
	board[0].result.hits = 1000
	board[0].name = "Changed externally"
	check(state.board("pop")[0].metric == 10 and state.board("pop")[0].name == "Avery", "Returned rows cannot mutate saved results or names")
	var round_id := State.make_round_id()
	var climbed := _submit(state, c, "pop", {"hits": 11}, round_id)
	check(climbed.improved and climbed.personal_best and climbed.old_rank == 3 and climbed.new_rank == 1, "A personal best moves the player above previous leaders")
	check(climbed.before[2].player_id == c and climbed.after[0].player_id == c, "Rank transitions include independent before and after boards")
	var saved: String = fixture.storage.text
	var writes: int = fixture.storage.writes
	var duplicate := _submit(state, c, "pop", {"hits": 50}, round_id)
	check(duplicate.duplicate and not duplicate.improved and fixture.storage.writes == writes and fixture.storage.text == saved, "A repeated round cannot change a result or replay improvement")
	check(state.round_submission(round_id).player_id == c and state.round_submission("missing").is_empty(), "Round identity remains readable after attribution")
	var receipt: Dictionary = state.round_submission(round_id)
	receipt.player_id = a
	check(state.round_submission(round_id).player_id == c, "Receipt lookups return copies")
	check(not state.submit_round(round_id, "pop", a, {"hits": 11}).ok, "A completed round cannot move to another player")
	check(not state.submit_round(round_id, "match", c, {"won": true, "mistakes": 0, "hints_used": 0}).ok, "A completed round cannot move to another mode")
	var lower := _submit(state, c, "pop", {"hits": 1})
	check(not lower.personal_best and not lower.improved and state.board("pop")[0].metric == 11, "Lower rounds retain the personal best")
	var same_rank := _submit(state, c, "pop", {"hits": 12})
	check(same_rank.personal_best and not same_rank.improved and same_rank.old_rank == 1 and same_rank.new_rank == 1, "A better score at first place does not claim a rank climb")
	var reloaded := State.new("user://unused-leaderboard-test.cfg", fixture.storage)
	check(reloaded.load_state() and reloaded.board("pop") == state.board("pop"), "Boards survive browser reload")
	check(reloaded.submit_round(round_id, "pop", c, {"hits": 11}).duplicate, "Round idempotency survives reload")


func _test_other_modes() -> void:
	var fixture := _browser()
	var state = fixture.state
	var a := _profile(state, "Avery")
	var b := _profile(state, "Blake")
	var c := _profile(state, "Casey")
	_submit(state, a, "match", {"won": true, "mistakes": 1, "hints_used": 0})
	_submit(state, b, "match", {"won": true, "mistakes": 0, "hints_used": 2})
	_submit(state, c, "match", {"won": true, "mistakes": 0, "hints_used": 1})
	check(state.board("match").map(func(row: Dictionary) -> String: return row.player_id) == [c, b, a], "Match ranks fewer misses before fewer hints")
	check(state.board("match")[0].label == "0 misses · 1 hint", "Match labels describe both ranking values")
	var climbed := _submit(state, a, "match", {"won": true, "mistakes": 0, "hints_used": 0})
	check(climbed.improved and climbed.old_rank == 3 and climbed.new_rank == 1, "A cleaner Match win improves rank")
	_submit(state, a, "match", {"won": true, "mistakes": 1, "hints_used": 0})
	check(state.board("match")[0].result.mistakes == 0, "Worse Match wins retain the best result")
	_submit(state, a, "memory", {"won": true, "attempts": 7, "peeks": 0})
	_submit(state, b, "memory", {"won": true, "attempts": 6, "peeks": 2})
	_submit(state, c, "memory", {"won": true, "attempts": 6, "peeks": 2})
	var board: Array = state.board("memory")
	check(board[0].player_id == b and board[1].player_id == c and board[2].player_id == a, "Memory ranks fewer turns before fewer peeks")
	check(board.map(func(row: Dictionary) -> int: return row.rank) == [1, 1, 3], "Memory ties require both turns and peeks to match")
	_submit(state, c, "memory", {"won": true, "attempts": 6, "peeks": 1})
	check(state.board("memory")[0].player_id == c and state.board("memory")[0].label == "6 turns · 1 peek", "Fewer peeks break a Memory tie")
	check(state.board("pop").is_empty(), "Mode leaderboards never mix scores")


func _test_invalid_results() -> void:
	var fixture := _browser()
	var state = fixture.state
	var id := _profile(state)
	var saved: String = fixture.storage.text
	for invalid in [null, true, "3", 3.0, NAN, INF, -1, State.MAX_VALUE + 1]:
		check(not state.submit_round(State.make_round_id(), "pop", id, {"hits": invalid}).ok, "Hits must be finite nonnegative bounded integers")
		check(not state.submit_round(State.make_round_id(), "match", id, {"won": true, "mistakes": invalid, "hints_used": 0}).ok, "Match rejects invalid misses")
		check(not state.submit_round(State.make_round_id(), "memory", id, {"won": true, "attempts": 5, "peeks": invalid}).ok, "Memory rejects invalid peeks")
	check(not state.submit_round("", "pop", id, {"hits": 1}).ok, "Empty round IDs are rejected")
	check(not state.submit_round("bad\nround", "pop", id, {"hits": 1}).ok, "Control characters in round IDs are rejected")
	check(not state.submit_round(State.make_round_id(), "unknown", id, {"hits": 1}).ok, "Unknown modes are rejected")
	check(not state.submit_round(State.make_round_id(), "pop", "unknown", {"hits": 1}).ok, "Unknown players cannot gain scores")
	for won in [false, 1, "true", null]:
		check(not state.submit_round(State.make_round_id(), "match", id, {"won": won, "mistakes": 0, "hints_used": 0}).ok, "Match needs a completed win")
		check(not state.submit_round(State.make_round_id(), "memory", id, {"won": won, "attempts": 5, "peeks": 0}).ok, "Memory needs a completed win")
	check(not state.submit_round(State.make_round_id(), "pop", id, {}).ok, "Missing scores are rejected")
	check(fixture.storage.text == saved, "Invalid submissions never overwrite saved state")


func _test_browser_failures() -> void:
	var fixture := _browser()
	var state = fixture.state
	var storage: BrowserStorage = fixture.storage
	var id := _profile(state)
	var saved: String = storage.text
	storage.writable = false
	check(not state.create_profile("Blake", "cat").ok and state.profiles.size() == 1, "Profile save failures leave memory unchanged")
	var round_id := State.make_round_id()
	check(not state.submit_round(round_id, "pop", id, {"hits": 7}).ok, "A failed result save is visible")
	check(state.ready and state.board("pop").is_empty() and state.round_submission(round_id).is_empty() and storage.text == saved, "A failed save leaves the board and receipt retryable")
	storage.writable = true
	var retried := _submit(state, id, "pop", {"hits": 7}, round_id)
	check(not retried.duplicate and state.board("pop")[0].metric == 7, "A failed result can retry with the same round ID")
	var second := State.new("user://unused-leaderboard-test.cfg", storage)
	check(second.load_state(), "A second local view loads shared state")
	_profile(state, "Blake", "cat")
	_profile(second, "Casey", "frog")
	check(second.profiles.size() == 3 and second.board("pop")[0].metric == 7, "Writes merge the latest shared storage before applying changes")
	check(state.load_state() and state.profiles.size() == 3, "Original view can refresh changes from another view")
	saved = storage.text
	storage.readable = false
	check(not state.create_profile("Drew", "dog").ok and not state.ready and storage.text == saved, "Read failures block overwrite of shared storage")
	storage.readable = true
	check(state.load_state() and state.ready, "A temporary read failure recovers explicitly")
	var locked := BrowserStorage.new()
	locked.writable = false
	var initial := State.new("user://unused-leaderboard-test.cfg", locked)
	check(initial.load_state() and initial.ready and locked.writes == 0, "An empty leaderboard remains readable when writes are unavailable")
	check(not initial.create_profile("Avery", "duck").ok and not initial.error.is_empty() and initial.profiles.is_empty(), "An unavailable first write has an explicit error without a phantom player")


func _test_invalid_saves() -> void:
	var profile := {"id": "player-a", "name": "Avery", "avatar": "duck"}
	var bests := {"pop": {"player-a": {"hits": 1}}, "match": {}, "memory": {}}
	var receipt := {"id": "round-a", "mode": "pop", "player_id": "player-a"}
	var invalid: Array[String] = ["", "[leaderboard", _text([], {}, [], 1), _text([], {}, [], 2), _text([], {}, [], 1.0),
		_text("players"), _text([profile, profile]), _text([{"id": "player-a", "name": " ", "avatar": "duck"}]),
		_text([{"id": "player-a", "name": "Avery", "avatar": "unknown"}]),
		_text([profile], {"pop": {"unknown": {"hits": 1}}, "match": {}, "memory": {}}),
		_text([profile], {"pop": {"player-a": {"hits": 1.0}}, "match": {}, "memory": {}}),
		_text([profile], {"pop": {}, "match": {}, "memory": {"player-a": {"won": false, "attempts": 5, "peeks": 0}}}),
		_text([profile], bests, [receipt, receipt]), _text([profile], bests, [{"id": "round-a", "mode": "pop", "player_id": "unknown"}]),
		_text([profile], {"pop": {}, "match": {}, "memory": {}}, [receipt])]
	for value in invalid:
		var storage := BrowserStorage.new()
		storage.text = value
		var state := State.new("user://unused-leaderboard-test.cfg", storage)
		var printing := Engine.print_error_messages
		Engine.print_error_messages = false
		var loaded := state.load_state()
		Engine.print_error_messages = printing
		check(not loaded and not state.ready and not state.error.is_empty(), "Invalid or unsupported saves report an error")
		check(not state.create_profile("Replacement", "duck").ok and storage.text == value and storage.writes == 0, "Invalid saves are preserved for recovery")
	var empty_path := State.new("")
	check(not empty_path.load_state() and not empty_path.error.is_empty(), "An empty native path is rejected")


func _test_native_persistence() -> void:
	var path := _root.path_join("leaderboards.cfg")
	_files.append_array([path, path + ".pending", path + ".previous"])
	var state := State.new(path)
	check(state.load_state() and not FileAccess.file_exists(path), "Reading a fresh native leaderboard does not write an empty save")
	var id := _profile(state, "Avery", "fox")
	check(FileAccess.file_exists(path), "The first player creates the native save atomically")
	var round_id := State.make_round_id()
	_submit(state, id, "pop", {"hits": 17}, round_id)
	var reloaded := State.new(path)
	check(reloaded.load_state() and reloaded.profiles == state.profiles and reloaded.board("pop") == state.board("pop"), "Native players and results survive reload")
	check(reloaded.submit_round(round_id, "pop", id, {"hits": 17}).duplicate, "Native round receipts survive reload")
	var saved := FileAccess.get_file_as_string(path)
	check(DirAccess.make_dir_absolute(path + ".pending") == OK, "Block only the isolated staged save path")
	var failed_id := State.make_round_id()
	check(not state.submit_round(failed_id, "pop", id, {"hits": 18}).ok, "A staging failure rejects the native result")
	check(FileAccess.get_file_as_string(path) == saved and state.board("pop")[0].metric == 17 and state.round_submission(failed_id).is_empty(), "A native staging failure preserves old bytes and board")
	check(DirAccess.remove_absolute(path + ".pending") == OK, "Remove known isolated staging blocker")
	check(state.submit_round(failed_id, "pop", id, {"hits": 18}).ok, "A native failure retries with the same round")
	check(DirAccess.rename_absolute(path, path + ".previous") == OK, "Simulate an interrupted native replacement")
	var recovered := State.new(path)
	check(recovered.load_state() and recovered.board("pop")[0].metric == 18, "An interrupted save recovers its preserved complete record")
	var invalid_path := _root.path_join("invalid.cfg")
	_files.append(invalid_path)
	var file := FileAccess.open(invalid_path, FileAccess.WRITE)
	check(file != null, "Open isolated unsupported save")
	if file != null:
		file.store_string(_text([], {}, [], 99))
		file.close()
	var invalid := State.new(invalid_path)
	check(not invalid.load_state() and not invalid.create_profile("Replacement", "duck").ok, "Unsupported native saves cannot be overwritten")
	check(FileAccess.get_file_as_string(invalid_path) == _text([], {}, [], 99), "Unsupported native bytes remain intact")


func _test_receipt_limit() -> void:
	var storage := BrowserStorage.new()
	var receipts: Array[Dictionary] = []
	for index in range(State.MAX_RECEIPTS):
		receipts.append({"id": "round-%d" % index, "mode": "pop", "player_id": "player-a"})
	storage.text = _text([{"id": "player-a", "name": "Avery", "avatar": "duck"}], {"pop": {"player-a": {"hits": 2}}, "match": {}, "memory": {}}, receipts)
	var state := State.new("user://unused-leaderboard-test.cfg", storage)
	check(state.load_state(), "Bounded receipt history loads")
	_submit(state, "player-a", "pop", {"hits": 3}, "round-latest")
	var config := ConfigFile.new()
	check(config.parse(storage.text) == OK and config.get_value("leaderboard", "receipts").size() == State.MAX_RECEIPTS, "Long play history stays within its storage bound")
	check(state.round_submission("round-0").is_empty() and state.round_submission("round-latest").player_id == "player-a", "Only the oldest receipt is retired")
	check(state.load_state() and state.submit_round("round-latest", "pop", "player-a", {"hits": 3}).duplicate, "Newest receipts remain idempotent after pruning and reload")

extends SceneTree

const State = preload("res://scripts/pop_reward_state.gd")

var checks: int = 0
var failures: int = 0


class BrowserStorage extends RefCounted:
	var text: Variant = null
	var writable: bool = true
	var writes: int = 0

	func popRewardState() -> Variant:
		return text

	func jellyRewardState() -> Variant:
		return text

	func savePopRewardState(value: String) -> bool:
		if not writable:
			return false
		text = value
		writes += 1
		return true

	func saveJellyRewardState(value: String) -> bool:
		return savePopRewardState(value)


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _state(kind: String, storage: BrowserStorage):
	var state := State.new("user://unused-reward-identity.cfg", storage)
	state.storage_kind = kind
	state.max_chests = 0
	state.allow_repeated_themes = true
	return state


func _run() -> void:
	for kind in ["pop", "jelly"]:
		_test_retained_identity(kind)
		_test_legacy_identity(kind)
		_test_invalid_identity(kind)
	print("Chest reward identities: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_retained_identity(kind: String) -> void:
	var storage := BrowserStorage.new()
	var state = _state(kind, storage)
	check(state.create_batch("batch-a", ["spring", "summer"], [1, 3]), "Create two independently earned chests")
	check(state.entries[0].reward_id == kind + ":batch-a:0" and state.entries[1].reward_id == kind + ":batch-a:1",
		"Each chest gets a stable mode, batch and original-index identity")
	check(state.mark_opened("batch-a", 0), "Opening the first chest permits later inventory pruning")
	var retained_id: String = state.entries[1].reward_id
	check(state.create_batch("batch-b", ["autumn"], [2]) and state.entries.size() == 2,
		"Appending a later batch retains only unopened earlier chests")
	check(state.entries[0].reward_id == retained_id and state.entries[0].tier == 3
		and state.entries[1].reward_id == kind + ":batch-b:0",
		"Pruning and a changed active round never change the retained chest's identity or tier")
	var reloaded = _state(kind, storage)
	check(reloaded.load_state() and reloaded.entries == state.entries, "Per-chest identities survive durable reload")
	var before: String = storage.text
	storage.writable = false
	check(not reloaded.mark_opened("batch-b", 0) and not reloaded.entries[0].opened
		and reloaded.entries[0].reward_id == retained_id and storage.text == before,
		"Failed opening keeps the same retryable reward ID and unopened chest")
	storage.writable = true
	check(reloaded.mark_opened("batch-b", 0) and reloaded.entries[0].reward_id == retained_id,
		"Retry consumes the originally retained reward, even though its index and active batch changed")
	var writes: int = storage.writes
	check(reloaded.create_batch("batch-a", ["space"], [50]) and storage.writes == writes,
		"A retired batch callback cannot recreate old reward identities")
	check(reloaded.create_batch("batch-c", ["winter"], [1]) and reloaded.entries[0].reward_id == kind + ":batch-b:0",
		"Repeated pruning preserves the next retained reward's original identity")


func _test_legacy_identity(kind: String) -> void:
	var storage := BrowserStorage.new()
	storage.text = "[treasure]\nversion=1\nround_id=\"legacy\"\nentries=[{\"theme\":\"spring\",\"opened\":true},{\"theme\":\"summer\",\"opened\":false},{\"theme\":\"space\",\"opened\":false,\"tier\":4}]\nreceipts=[]\n"
	var legacy: String = storage.text
	var state = _state(kind, storage)
	check(state.load_state() and storage.writes == 0 and storage.text == legacy,
		"Reading a legacy inventory derives identities without rewriting earned treasure")
	check(state.entries[0].reward_id == kind + ":legacy:0" and state.entries[0].opened
		and state.entries[1].reward_id == kind + ":legacy:1" and state.entries[2].reward_id == kind + ":legacy:2",
		"Both opened and unopened legacy chests receive deterministic original-index IDs")
	var reloaded = _state(kind, storage)
	check(reloaded.load_state() and reloaded.entries == state.entries,
		"Repeated loading before migration persistence produces identical receipt IDs")
	check(reloaded.create_batch("new", ["ocean"], [2]) and reloaded.entries.size() == 3,
		"The next normal append persists legacy identities while removing previously opened chests")
	check(reloaded.entries[0].reward_id == kind + ":legacy:1" and reloaded.entries[1].reward_id == kind + ":legacy:2"
		and reloaded.entries[2].reward_id == kind + ":new:0" and storage.text.contains("reward_id"),
		"Legacy identities remain tied to their old positions after an append moves them")
	check(state.load_state() and state.entries == reloaded.entries, "Migration survives reload from the actual saved inventory")


func _test_invalid_identity(kind: String) -> void:
	for invalid in ["", 12, "match:foreign:0", kind + ":bad\nreceipt", kind + ":" + "x".repeat(513)]:
		var storage := BrowserStorage.new()
		var config := ConfigFile.new()
		config.set_value("treasure", "version", 1)
		config.set_value("treasure", "round_id", "invalid")
		config.set_value("treasure", "entries", [{"theme": "spring", "opened": false, "reward_id": invalid}])
		config.set_value("treasure", "receipts", [])
		storage.text = config.encode_to_text()
		check(not _state(kind, storage).load_state() and storage.writes == 0,
			"An invalid or foreign-mode reward ID fails closed")
	var storage := BrowserStorage.new()
	var state = _state(kind, storage)
	check(state.create_batch("duplicated", ["spring", "spring"]), "Prepare distinct chests with the same theme")
	var config := ConfigFile.new()
	config.parse(storage.text)
	var entries: Array = config.get_value("treasure", "entries")
	entries[1].reward_id = entries[0].reward_id
	config.set_value("treasure", "entries", entries)
	storage.text = config.encode_to_text()
	var writes: int = storage.writes
	check(not state.load_state() and not state.ready and storage.writes == writes,
		"Two pending chests cannot share one coin receipt identity")

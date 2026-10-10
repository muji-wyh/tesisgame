extends SceneTree

const Wallet = preload("res://scripts/coin_wallet.gd")

var checks: int = 0
var failures: int = 0


class BrowserStorage extends RefCounted:
	var text: Variant = null
	var fail_write: bool = false
	var fail_read: bool = false
	var conflict_text: Variant = null
	var writes: int = 0
	var calls: int = 0

	func coinWalletState() -> Variant:
		return false if fail_read else text

	func saveCoinWalletState(value: String, expected: Variant) -> bool:
		calls += 1
		if conflict_text != null:
			text = conflict_text
			conflict_text = null
		if fail_write or text != expected:
			return false
		text = value
		writes += 1
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _save(balance_value: Variant, receipts: Variant, version: Variant = 1) -> String:
	var config := ConfigFile.new()
	config.set_value("wallet", "version", version)
	config.set_value("wallet", "balance", balance_value)
	config.set_value("wallet", "receipts", receipts)
	return config.encode_to_text()


func _load_corrupt(wallet) -> bool:
	# Expected ConfigFile syntax errors remain visible through wallet.error.
	var was_printing: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var loaded: bool = wallet.load_state()
	Engine.print_error_messages = was_printing
	return loaded


func _run() -> void:
	_test_rewards_and_receipts()
	_test_retry_and_conflicts()
	_test_validation_and_overflow()
	_test_native_durability()
	print("Coin wallet: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_rewards_and_receipts() -> void:
	var storage := BrowserStorage.new()
	var wallet := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(not wallet.credit("match:round-a", 0).ok and storage.calls == 0,
		"Unloaded coin storage cannot grant rewards")
	check(wallet.load_state() and wallet.ready and wallet.balance == 0 and storage.writes == 0,
		"Missing storage starts at zero without inventing receipts or rewriting other saves")
	var earned: Dictionary = wallet.credit("match:round-a", 0)
	check(earned.ok and not earned.duplicate and earned.amount == 50 and earned.before == 0 and earned.after == 50,
		"An ordinary chest durably earns its first 50 coins")
	check(wallet.balance == 50 and storage.writes == 1, "The displayed balance updates after its receipt is saved")
	var duplicate: Dictionary = wallet.credit("match:round-a", 1)
	check(duplicate.ok and duplicate.duplicate and duplicate.amount == 0 and duplicate.before == 50 and duplicate.after == 50,
		"Ordinary and tier-one retries acknowledge the same receipt without another payout")
	check(storage.writes == 1, "Duplicate callbacks do not write again")
	check(not wallet.credit("match:round-a", 2).ok and wallet.balance == 50 and storage.writes == 1,
		"One receipt cannot be reinterpreted as a higher-level chest")
	check(wallet.credit("memory:round-a", 1).amount == 50, "Mode prefixes distinguish otherwise identical round IDs")
	check(wallet.credit("pop:batch-a:0", 3).amount == 150, "Tier three pays 150 coins")
	check(wallet.credit("jelly:batch-a:0", 300).amount == 15000, "High numeric tiers retain their exact coin reward")
	var expected_balance: int = wallet.balance
	var writes: int = storage.writes
	var reloaded := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == expected_balance, "The balance and receipt history survive reload")
	for id in ["match:round-a", "memory:round-a", "pop:batch-a:0", "jelly:batch-a:0"]:
		var tier: int = 300 if id.begins_with("jelly:") else 3 if id.begins_with("pop:") else 1
		check(reloaded.credit(id, tier).duplicate, "Reload preserves the permanent receipt for " + id)
	check(reloaded.balance == expected_balance and storage.writes == writes,
		"Replaying all persisted receipts cannot increase the balance or rewrite history")
	var old_receipts: Dictionary = {}
	for index in range(4100):
		old_receipts["jelly:older-%d:0" % index] = 50
	storage.text = _save(4100 * 50, old_receipts)
	check(reloaded.load_state() and reloaded.credit("jelly:next:0", 1).ok,
		"The wallet can extend receipt history beyond the transient game-event limit")
	writes = storage.writes
	check(reloaded.credit("jelly:older-0:0", 1).duplicate and reloaded.balance == 4101 * 50 and storage.writes == writes,
		"A very old chest receipt is never evicted or eligible for another coin payout")


func _test_retry_and_conflicts() -> void:
	var storage := BrowserStorage.new()
	var first := Wallet.new("user://unused-coin-wallet.cfg", storage)
	var second := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(first.load_state() and second.load_state(), "Two tabs can observe the same missing wallet")
	storage.fail_write = true
	check(not first.credit("phrase:failed", 1).ok and first.balance == 0 and storage.text == null,
		"Failed writes leave both balance and receipt uncommitted")
	check(not first.credit("phrase:failed", 1).ok and storage.writes == 0,
		"Repeated failed requests cannot announce saved coins")
	storage.fail_write = false
	check(first.credit("phrase:failed", 1).amount == 50 and first.balance == 50,
		"Retry credits the original chest exactly once after storage recovers")
	var calls: int = storage.calls
	var before_text: String = storage.text
	check(not second.credit("memory:stale", 1).ok and second.error.contains("Reload")
		and second.balance == 0 and storage.calls == calls and storage.text == before_text,
		"A stale tab fails before its old balance can replace a newer wallet")
	check(second.load_state() and second.credit("memory:stale", 1).amount == 50 and second.balance == 100,
		"Explicit reload allows the stale tab to add its independent reward")
	check(not first.credit("phrase:failed", 1).ok and storage.calls == calls + 1,
		"Even a duplicate request cannot silently confirm a stale wallet snapshot")
	check(first.load_state() and first.credit("phrase:failed", 1).duplicate,
		"Reload recovers duplicate acknowledgement without another payout")
	storage.conflict_text = _save(150, {"phrase:failed": 50, "memory:stale": 50, "pop:other:0": 50})
	check(not first.credit("jelly:pending:0", 2).ok and first.balance == 100,
		"A change between read and write fails the browser's expected-snapshot comparison")
	check(first.load_state() and first.balance == 150 and first.credit("jelly:pending:0", 2).amount == 100,
		"The same pending chest can be retried after loading a concurrent reward")
	before_text = storage.text
	storage.fail_read = true
	calls = storage.calls
	check(not first.credit("match:unreadable", 1).ok and storage.calls == calls and first.balance == 250,
		"Unavailable reads never look like a fresh empty wallet")
	check(not first.load_state() and not first.ready and storage.text == before_text,
		"A failed reload preserves the durable save and disables new credit")
	storage.fail_read = false
	check(first.load_state() and first.balance == 250, "Readable storage restores the verified balance")
	storage.text = null
	check(not first.credit("jelly:pending:0", 2).ok and first.balance == 250 and storage.text == null,
		"Deleted shared storage cannot be silently reconstructed from a stale tab")


func _test_validation_and_overflow() -> void:
	var invalid: Array = [
		false, 42, "", "[wallet", "[wallet]\nversion=1\nbalance=0\n",
		_save(0, {}, 2), _save(0, {}, 1.0), _save(0.0, {}), _save(-1, {}),
		_save(50, {}), _save(0, []), _save(50, {"": 50}),
		_save(50, {"match:x": 50.0}), _save(25, {"match:x": 25}),
		_save(50, {"match:x\n": 50}), _save(50, {" match:x": 50}),
		_save(50, {"match:x": -50}), _save(0, {"match:x": 0}),
		_save(Wallet.MAX_BALANCE, {"jelly:huge:0": Wallet.MAX_BALANCE}),
		_save(Wallet.MAX_BALANCE, {"jelly:a:0": Wallet.MAX_TIER * 50, "jelly:b:0": 50}),
		_save(0, {}) + "\n[foreign]\nvalue=1\n",
	]
	for text in invalid:
		var storage := BrowserStorage.new()
		storage.text = text
		var wallet := Wallet.new("user://unused-coin-wallet.cfg", storage)
		check(not _load_corrupt(wallet) and not wallet.ready and not wallet.error.is_empty(),
			"Malformed or unsupported wallet data fails closed")
		check(not wallet.credit("match:invalid", 1).ok and storage.text == text and storage.calls == 0,
			"Invalid saves remain unchanged until explicit recovery")
	var storage := BrowserStorage.new()
	var wallet := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(wallet.load_state(), "Load an empty overflow fixture")
	for id in ["", " ", "bad\nreceipt", "bad\treceipt", "x".repeat(513)]:
		check(not wallet.credit(id, 1).ok and storage.calls == 0, "Invalid reward IDs cannot create receipts")
	for tier in [-1, Wallet.MAX_TIER + 1]:
		check(not wallet.credit("jelly:bad-tier:0", tier).ok and storage.calls == 0,
			"Out-of-range tiers fail before integer multiplication")
	var largest: int = Wallet.MAX_TIER * 50
	check(wallet.credit("jelly:largest:0", Wallet.MAX_TIER).amount == largest and wallet.balance == largest,
		"The largest supported tier remains an exact integer")
	var text: String = storage.text
	check(not wallet.credit("match:overflow", 1).ok and wallet.balance == largest and storage.text == text,
		"Adding a reward beyond the safe balance is rejected without overflow or receipt loss")
	var reloaded := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == largest and reloaded.credit("jelly:largest:0", Wallet.MAX_TIER).duplicate,
		"Large balances remain exact and idempotent after reload")


func _test_native_durability() -> void:
	var directory: String = "user://coin-wallet-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated native wallet storage")
	var path: String = directory + "/wallet.cfg"
	var wallet := Wallet.new(path)
	check(wallet.load_state() and wallet.balance == 0 and not FileAccess.file_exists(path),
		"An absent native save is a clean zero balance")
	check(wallet.credit("match:native", 1).ok and FileAccess.file_exists(path),
		"Native credit atomically writes the receipt and coins")
	var saved: String = FileAccess.get_file_as_string(path)
	check(DirAccess.make_dir_absolute(path + ".pending") == OK, "Block the staging destination for a failed-write fixture")
	check(not wallet.credit("memory:native-retry", 2).ok and wallet.balance == 50
		and FileAccess.get_file_as_string(path) == saved,
		"A failed native staging write leaves the previous durable balance intact")
	check(DirAccess.remove_absolute(path + ".pending") == OK, "Restore the staging destination")
	check(wallet.credit("memory:native-retry", 2).amount == 100 and wallet.balance == 150,
		"Retry after a native filesystem failure commits the missing receipt once")
	check(not FileAccess.file_exists(path + ".previous") and not FileAccess.file_exists(path + ".pending"),
		"A successful atomic commit leaves no transient journal files")
	var reloaded := Wallet.new(path)
	check(reloaded.load_state() and reloaded.balance == 150 and reloaded.credit("match:native", 1).duplicate,
		"A native reload preserves all earned coins and earlier receipts")
	check(DirAccess.rename_absolute(path, path + ".previous") == OK, "Simulate interruption between atomic file renames")
	var recovered := Wallet.new(path)
	check(recovered.load_state() and recovered.balance == 150 and FileAccess.file_exists(path),
		"Loading restores the previous committed file after an interrupted rename")
	check(recovered.credit("memory:native-retry", 2).duplicate, "Journal recovery cannot replay an already saved reward")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("corrupted wallet")
	broken.close()
	check(not recovered.credit("phrase:after-corruption", 1).ok and recovered.balance == 150,
		"A changed native save is not overwritten by an older in-memory snapshot")
	check(not _load_corrupt(recovered) and not recovered.ready and FileAccess.get_file_as_string(path) == "corrupted wallet",
		"Corrupt native data remains recoverable instead of being reset to zero")
	check(DirAccess.remove_absolute(path) == OK, "Remove the isolated corrupted fixture")
	check(DirAccess.make_dir_absolute(path) == OK, "Use a directory to test an unreadable native save path")
	check(not Wallet.new(path).load_state(), "A directory at the wallet path is unavailable storage, not a missing save")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(directory)

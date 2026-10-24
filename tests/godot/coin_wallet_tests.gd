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
	_test_spending_and_migration()
	_test_spending_retry_and_conflicts()
	_test_signed_receipt_validation()
	_test_exact_credit_migration()
	_test_exact_credit_retry_and_conflicts()
	_test_exact_credit_validation()
	_test_native_durability()
	_test_native_spending()
	_test_native_exact_credit()
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
		_save(0, {}, 4), _save(0, {}, 1.0), _save(0.0, {}), _save(-1, {}),
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


func _test_spending_and_migration() -> void:
	var storage := BrowserStorage.new()
	var original: String = _save(3000, {"chest:one": 2000, "chest:two": 1000})
	storage.text = original
	var wallet := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(not wallet.spend("power:unloaded", 500).ok and storage.calls == 0,
		"An unloaded wallet cannot charge a purchase")
	check(wallet.load_state() and wallet.balance == 3000 and storage.text == original and storage.writes == 0,
		"Version-one wallets load without rewriting their original balance or receipt history")
	check(wallet.credit("chest:one", 40).duplicate and storage.text == original,
		"An old credit remains idempotent before migration without an unnecessary save")
	var spent: Dictionary = wallet.spend("power:auto-merge:one", 1500)
	check(spent == {"ok": true, "duplicate": false, "amount": -1500, "before": 3000, "after": 1500, "error": ""},
		"Auto merge charges its exact cost and returns a signed balance delta after saving")
	var config := ConfigFile.new()
	check(config.parse(storage.text) == OK and config.get_value("wallet", "version") == Wallet.VERSION
		and config.get_value("wallet", "balance") == 1500
		and config.get_value("wallet", "receipts") == {"chest:one": 2000, "chest:two": 1000, "power:auto-merge:one": -1500},
		"The first successful purchase atomically migrates v1 credits and adds one signed debit")
	var writes: int = storage.writes
	check(wallet.spend("power:auto-merge:one", 1500) == {"ok": true, "duplicate": true, "amount": 0, "before": 1500, "after": 1500, "error": ""}
		and storage.writes == writes, "Repeated purchase callbacks acknowledge the receipt without another charge or write")
	check(wallet.spend("power:fragments:one", 500).amount == -500 and wallet.balance == 1000,
		"Fragment purchases charge the lower price through the same durable API")
	var saved: String = storage.text
	var receipts: Dictionary = wallet._receipts.duplicate()
	writes = storage.writes
	for purchase in [{"id": "chest:one", "amount": 2000}, {"id": "power:auto-merge:one", "amount": 500}]:
		check(not wallet.spend(str(purchase.id), int(purchase.amount)).ok and wallet.balance == 1000
			and wallet._receipts == receipts and storage.text == saved and storage.writes == writes,
			"A credit identity or different purchase price cannot be reused as a debit")
	check(not wallet.credit("power:fragments:one", 10).ok and wallet.balance == 1000 and storage.text == saved,
		"A negative purchase receipt cannot be replayed as a positive credit")
	var reloaded := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == 1000 and reloaded._receipts == receipts,
		"Migrated credit and debit receipts survive reloading with the exact balance")
	check(reloaded.credit("chest:one", 40).duplicate and reloaded.credit("chest:two", 20).duplicate
		and reloaded.spend("power:fragments:one", 500).duplicate and storage.writes == writes,
		"Every old credit and saved purchase remains idempotent after migration")
	check(reloaded.spend("power:empty-wallet", 1000).after == 0, "A purchase may consume the exact remaining balance")
	writes = storage.writes
	saved = storage.text
	check(reloaded.spend("power:auto-merge:one", 1500).duplicate and storage.writes == writes,
		"A paid purchase is acknowledged even when the current balance cannot pay its price again")
	var insufficient: Dictionary = reloaded.spend("power:no-funds", 500)
	check(not insufficient.ok and not insufficient.duplicate and insufficient.amount == 0
		and insufficient.before == 0 and insufficient.after == 0 and not insufficient.error.is_empty()
		and insufficient.reason == "insufficient" and reloaded.ready and reloaded.error.is_empty()
		and not reloaded._receipts.has("power:no-funds") and storage.text == saved and storage.writes == writes,
		"Insufficient funds reserve no receipt, change no coins, perform no write, and leave coin storage available")
	check(reloaded.credit("chest:after-spending", 10).amount == 500
		and reloaded.spend("power:no-funds", 500).amount == -500,
		"An unfunded purchase can retry after new coins arrive without losing its identity")
	var final_wallet := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(final_wallet.load_state() and final_wallet.balance == 0 and final_wallet.spend("power:no-funds", 500).duplicate,
		"A spent-down wallet reloads at zero without restoring any consumed coins")


func _test_spending_retry_and_conflicts() -> void:
	var storage := BrowserStorage.new()
	storage.text = _save(2000, {"chest:funding": 2000})
	var wallet := Wallet.new("user://unused-coin-wallet.cfg", storage)
	var other := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(wallet.load_state() and other.load_state(), "Two tabs observe the same funded v1 wallet")
	var original: String = storage.text
	var receipts: Dictionary = wallet._receipts.duplicate()
	storage.fail_write = true
	for attempt in range(2):
		var result: Dictionary = wallet.spend("power:retry", 1500)
		check(not result.ok and result.amount == 0 and result.before == 2000 and result.after == 2000
			and wallet.balance == 2000 and wallet._receipts == receipts and storage.text == original and storage.writes == 0,
			"A failed purchase write preserves its v1 snapshot, balance, and permanent receipts")
	storage.fail_write = false
	check(wallet.spend("power:retry", 1500).amount == -1500 and wallet.balance == 500,
		"Storage recovery retries the same purchase once and commits migration with its debit")
	var calls: int = storage.calls
	var saved: String = storage.text
	check(not other.spend("power:stale", 500).ok and other.balance == 2000 and other.error.contains("Reload")
		and storage.text == saved and storage.calls == calls,
		"A stale tab cannot overwrite a newer purchase with its older funded balance")
	check(other.load_state() and other.spend("power:retry", 1500).duplicate and storage.calls == calls,
		"Reloading a stale tab recovers a paid purchase without paying it twice")
	storage.conflict_text = _save(1000, {"chest:funding": 2000, "power:retry": -1500, "chest:concurrent": 500}, 2)
	receipts = wallet._receipts.duplicate()
	check(not wallet.spend("power:between-read-write", 500).ok and wallet.balance == 500
		and wallet._receipts == receipts and not wallet._receipts.has("power:between-read-write"),
		"A concurrent storage change at commit cannot debit the in-memory wallet or consume a purchase ID")
	check(wallet.load_state() and wallet.balance == 1000
		and wallet.spend("power:between-read-write", 500).amount == -500,
		"A conflicted purchase retries after reload against the latest durable balance")
	calls = storage.calls
	receipts = wallet._receipts.duplicate()
	storage.fail_read = true
	check(not wallet.spend("power:unreadable", 500).ok and wallet.balance == 500
		and wallet._receipts == receipts and storage.calls == calls,
		"Unavailable reads cannot start a debit or reinterpret storage as a new wallet")
	storage.fail_read = false
	storage.text = null
	check(not wallet.spend("power:deleted", 500).ok and wallet.balance == 500
		and wallet._receipts == receipts and storage.calls == calls,
		"Deleted shared storage is not reconstructed with a stale purchase")


func _test_signed_receipt_validation() -> void:
	var invalid: Array = [
		_save(0, {"credit": 50, "debit": -50}),
		_save(0, {"credit": 50, "debit": -100}, 2),
		_save(50, {"credit": 50, "debit": -50}, 2),
		_save(0, {"zero": 0}, 2), _save(0, {"credit": 50, "debit": -50.0}, 2),
		_save(25, {"credit": 50, "debit": -25}, 2),
		_save(0, {"credit": 50, "debit\n": -50}, 2),
		_save(0, {"credit": 50, "debit": -Wallet.MAX_BALANCE - 1}, 2),
		_save(0, {"credit": 50, "debit": -9223372036854775807}, 2),
		_save(Wallet.MAX_BALANCE, {"one": Wallet.MAX_TIER * 50, "two": 50}, 2),
		_save(0, {}, 2) + "unknown=1\n"
	]
	for text in invalid:
		var storage := BrowserStorage.new()
		storage.text = text
		var wallet := Wallet.new("user://unused-coin-wallet.cfg", storage)
		check(not _load_corrupt(wallet) and not wallet.ready and not wallet.error.is_empty(),
			"Malformed signed histories, v1 negative receipts, and mismatched totals fail closed")
		check(not wallet.spend("power:invalid-save", 500).ok and not wallet.credit("chest:invalid-save", 1).ok
			and storage.text == text and storage.calls == 0, "Invalid signed saves cannot be rewritten by either coin operation")
	var storage := BrowserStorage.new()
	storage.text = _save(2000, {"credit": 2000}, 2)
	var wallet := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(wallet.load_state(), "A credit-only version-two wallet is supported")
	var saved: String = storage.text
	for amount: int in [-500, 0, 1, 49, 51, Wallet.MAX_BALANCE, Wallet.MAX_BALANCE + 1]:
		check(not wallet.spend("power:bad-price", amount).ok and wallet.balance == 2000
			and storage.text == saved and storage.calls == 0, "A price must be a positive, safely represented multiple of 50")
	for id: String in ["", " ", "bad\nreceipt", "bad\treceipt", " leading", "trailing ", "x".repeat(513)]:
		check(not wallet.spend(id, 500).ok and storage.text == saved and storage.calls == 0,
			"Purchase IDs follow the same strict receipt rules as earned rewards")
	var largest: int = Wallet.MAX_TIER * 50
	var history: Dictionary = {"final-credit": 50}
	for index in range(1200):
		history["debit:%d" % index] = -largest
		history["credit:%d" % index] = largest
	storage.text = _save(50, history, 2)
	check(wallet.load_state() and wallet.balance == 50 and wallet._receipts == history,
		"Signed receipt reconstruction is exact when reordered lifetime earnings exceed even the native integer range")
	check(wallet.spend("debit:0", largest).duplicate and wallet.credit("credit:0", Wallet.MAX_TIER).duplicate,
		"Very large prior credits and debits retain exact amounts and permanent idempotence")
	check(wallet.spend("power:last-fifty", 50).amount == -50, "A large lifetime history still supports an ordinary small purchase")
	var reloaded := Wallet.new("user://unused-coin-wallet.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == 0 and reloaded.spend("power:last-fifty", 50).duplicate,
		"Serialized mixed-sign history survives another save and reload without overflow or precision loss")


func _test_exact_credit_migration() -> void:
	for version: int in [1, 2]:
		var storage := BrowserStorage.new()
		var legacy: Dictionary = {"chest:legacy": 100}
		if version == 2:
			legacy["power:legacy"] = -50
		var original_balance: int = 100 if version == 1 else 50
		storage.text = _save(original_balance, legacy, version)
		var original: String = storage.text
		var wallet := Wallet.new("user://unused-exact-coins.cfg", storage)
		check(wallet.load_state() and wallet.balance == original_balance and storage.text == original and storage.writes == 0,
			"Legacy wallets load without rewriting or reinterpreting their saved receipts")
		check(wallet.credit_amount("chest:legacy", 100).duplicate and storage.text == original and storage.writes == 0,
			"An exact-amount acknowledgement preserves an old chest's immutable amount without migrating")
		var earned: Dictionary = wallet.credit_amount("combo:first", 3)
		check(earned == {"ok": true, "duplicate": false, "amount": 3, "before": original_balance,
			"after": original_balance + 3, "error": ""}, "A small reward saves its exact integer amount and balance delta")
		var config := ConfigFile.new()
		legacy["combo:first"] = 3
		check(config.parse(storage.text) == OK and config.get_value("wallet", "version") == 3
			and config.get_value("wallet", "receipts") == legacy,
			"The first exact credit migrates v1 or v2 to v3 while preserving every old signed receipt")
		var saved: String = storage.text
		var writes: int = storage.writes
		check(wallet.credit_amount("combo:first", 3).duplicate and storage.writes == writes and storage.text == saved,
			"Repeated combo acknowledgement cannot pay twice or rewrite history")
		check(not wallet.credit_amount("combo:first", 4).ok and not wallet.credit("combo:first", 1).ok
			and not wallet.spend("combo:first", 50).ok and storage.text == saved and storage.writes == writes,
			"A small reward receipt cannot be repriced, promoted to a chest, or reused as a purchase")
		check(wallet.credit("chest:new", 1).amount == 50 and wallet.credit_amount("chest:new", 50).duplicate,
			"The chest API keeps its 50-coin multiplier and shares exact receipt identity")
		check(wallet.spend("power:new", 50).amount == -50,
			"A v3 wallet can spend the usual price while retaining a non-multiple-of-50 remainder")
		var reloaded := Wallet.new("user://unused-exact-coins.cfg", storage)
		check(reloaded.load_state() and reloaded.balance == original_balance + 3
			and reloaded.credit_amount("combo:first", 3).duplicate and reloaded.credit("chest:legacy", 2).duplicate
			and reloaded.spend("power:new", 50).duplicate,
			"Mixed old chests, exact rewards, and purchases reload with their precise balance and idempotence")


func _test_exact_credit_retry_and_conflicts() -> void:
	var storage := BrowserStorage.new()
	storage.text = _save(100, {"chest:funding": 100}, 2)
	var wallet := Wallet.new("user://unused-exact-coins.cfg", storage)
	var stale := Wallet.new("user://unused-exact-coins.cfg", storage)
	check(wallet.load_state() and stale.load_state(), "Two exact-credit clients load the same legacy snapshot")
	var original: String = storage.text
	storage.fail_write = true
	for attempt in range(2):
		check(not wallet.credit_amount("combo:retry", 1).ok and wallet.balance == 100
			and not wallet._receipts.has("combo:retry") and storage.text == original and storage.writes == 0,
			"A failed small-credit save changes neither the legacy file, balance, nor receipt")
	storage.fail_write = false
	check(wallet.credit_amount("combo:retry", 1).amount == 1 and wallet.balance == 101,
		"Recovery pays the same small reward once and migrates in the same write")
	var saved: String = storage.text
	var calls: int = storage.calls
	check(not stale.credit_amount("combo:stale", 2).ok and stale.balance == 100
		and storage.text == saved and storage.calls == calls,
		"A stale client cannot replace a small credited balance with its old snapshot")
	check(stale.load_state() and stale.credit_amount("combo:retry", 1).duplicate and storage.calls == calls,
		"Reload acknowledges a committed exact reward without another write")
	storage.conflict_text = _save(104, {"chest:funding": 100, "combo:retry": 1, "combo:other": 3}, 3)
	check(not wallet.credit_amount("combo:race", 2).ok and wallet.balance == 101
		and not wallet._receipts.has("combo:race"), "A write-time conflict cannot consume an exact reward receipt")
	check(wallet.load_state() and wallet.credit_amount("combo:race", 2).amount == 2 and wallet.balance == 106,
		"Reload and retry preserve both concurrent small rewards without duplication")
	saved = storage.text
	calls = storage.calls
	storage.fail_read = true
	check(not wallet.credit_amount("combo:unreadable", 1).ok and wallet.balance == 106
		and storage.text == saved and storage.calls == calls, "Read failure cannot invent or overwrite a small-credit save")
	storage.fail_read = false
	storage.text = null
	check(not wallet.credit_amount("combo:deleted", 1).ok and wallet.balance == 106 and storage.calls == calls,
		"Deleted shared storage cannot be rebuilt from an old exact-credit client")


func _test_exact_credit_validation() -> void:
	var storage := BrowserStorage.new()
	var wallet := Wallet.new("user://unused-exact-coins.cfg", storage)
	check(not wallet.credit_amount("combo:unloaded", 1).ok and storage.calls == 0,
		"Exact rewards require a successfully loaded wallet")
	check(wallet.load_state(), "Load an empty exact-credit validation fixture")
	for amount: Variant in [null, false, true, 1.0, 1.5, NAN, INF, "3", {}, [], 0, -1, Wallet.MAX_BALANCE + 1]:
		check(not wallet.credit_amount("combo:invalid", amount).ok and wallet.balance == 0
			and wallet._receipts.is_empty() and storage.calls == 0,
			"Exact credit accepts positive whole integer coins without coercion or overflow")
	for id: String in ["", " ", "bad\nreceipt", " leading", "trailing ", "x".repeat(513)]:
		check(not wallet.credit_amount(id, 1).ok and storage.calls == 0,
			"Exact rewards use the same strict permanent receipt identity rules")
	for version: int in [1, 2]:
		storage.text = _save(1, {"combo:legacy": 1}, version)
		check(not _load_corrupt(wallet) and storage.calls == 0,
			"Legacy versions keep their original 50-coin receipt validation")
	for invalid: String in [_save(1, {"combo:float": 1.0}, 3), _save(1, {"combo:zero": 0, "combo:one": 1}, 3),
		_save(1, {"combo:credit": 2, "power:fraction": -1}, 3), _save(2, {"combo:one": 1}, 3)]:
		storage.text = invalid
		check(not _load_corrupt(wallet) and not wallet.ready and storage.text == invalid,
			"V3 rejects non-integer credits, zero receipts, nonstandard debits, and inconsistent totals")
	storage.text = null
	check(wallet.load_state() and wallet.credit_amount("combo:maximum", Wallet.MAX_BALANCE).amount == Wallet.MAX_BALANCE,
		"An exact credit may reach the largest safely represented whole balance")
	var saved: String = storage.text
	check(not wallet.credit_amount("combo:overflow", 1).ok and wallet.balance == Wallet.MAX_BALANCE
		and storage.text == saved and not wallet._receipts.has("combo:overflow"),
		"An extra coin beyond the supported balance cannot overflow or consume its receipt")
	var reloaded := Wallet.new("user://unused-exact-coins.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == Wallet.MAX_BALANCE
		and reloaded.credit_amount("combo:maximum", Wallet.MAX_BALANCE).duplicate,
		"The exact maximum and its permanent reward identity survive serialization")
	check(reloaded.spend("power:maximum", Wallet.MAX_TIER * 50).ok and reloaded.balance == Wallet.MAX_BALANCE % 50,
		"A maximum exact balance still spends only a supported 50-coin price")
	check(wallet.load_state() and wallet.balance == Wallet.MAX_BALANCE % 50,
		"The maximum signed history reconstructs its small remainder without precision loss")


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


func _test_native_spending() -> void:
	var directory: String = "user://coin-spending-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated native spending storage")
	var path: String = directory + "/wallet.cfg"
	var original: String = _save(3000, {"chest:native-funding": 3000})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var wallet := Wallet.new(path)
	var stale := Wallet.new(path)
	check(wallet.load_state() and stale.load_state() and wallet.balance == 3000,
		"Native purchase fixtures load a preexisting version-one wallet")
	check(DirAccess.make_dir_absolute(path + ".pending") == OK, "Block native purchase staging")
	check(not wallet.spend("power:native-fragments", 500).ok and wallet.balance == 3000
		and not wallet._receipts.has("power:native-fragments") and FileAccess.get_file_as_string(path) == original,
		"Native save failure leaves the old wallet and purchase identity intact without migrating")
	check(DirAccess.remove_absolute(path + ".pending") == OK, "Restore native purchase staging")
	check(wallet.spend("power:native-fragments", 500).amount == -500 and wallet.balance == 2500,
		"Retry persists a native debit together with v1 migration")
	var saved: String = FileAccess.get_file_as_string(path)
	check(not stale.spend("power:native-stale", 1500).ok and stale.balance == 3000
		and FileAccess.get_file_as_string(path) == saved, "A stale native wallet cannot overwrite a committed debit")
	check(DirAccess.rename_absolute(path, path + ".previous") == OK, "Simulate an interrupted native signed-save rename")
	var recovered := Wallet.new(path)
	check(recovered.load_state() and recovered.balance == 2500
		and recovered.spend("power:native-fragments", 500).duplicate
		and recovered.credit("chest:native-funding", 60).duplicate,
		"Native journal recovery preserves signed purchase and credit idempotence")
	check(recovered.spend("power:native-remainder", 2500).after == 0, "Native spending can safely consume the remaining balance")
	var reloaded := Wallet.new(path)
	check(reloaded.load_state() and reloaded.balance == 0 and reloaded.spend("power:native-remainder", 2500).duplicate,
		"A native zero balance retains the last purchase receipt after reload")
	check(not FileAccess.file_exists(path + ".pending") and not FileAccess.file_exists(path + ".previous"),
		"Successful native spending clears staging and backup files")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(directory)


func _test_native_exact_credit() -> void:
	var directory: String = "user://coin-exact-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated native exact-credit storage")
	var path: String = directory + "/wallet.cfg"
	var wallet := Wallet.new(path)
	check(wallet.load_state() and wallet.credit_amount("combo:native-one", 1).amount == 1,
		"Native exact credit saves its first single coin")
	var saved: String = FileAccess.get_file_as_string(path)
	check(DirAccess.make_dir_absolute(path + ".pending") == OK, "Block native exact-credit staging")
	check(not wallet.credit_amount("combo:native-retry", 3).ok and wallet.balance == 1
		and not wallet._receipts.has("combo:native-retry") and FileAccess.get_file_as_string(path) == saved,
		"A failed native write preserves the earlier single coin and leaves the new receipt retryable")
	check(DirAccess.remove_absolute(path + ".pending") == OK, "Restore native exact-credit staging")
	check(wallet.credit_amount("combo:native-retry", 3).amount == 3 and wallet.balance == 4,
		"Native retry saves the exact unpaid reward once")
	check(DirAccess.rename_absolute(path, path + ".previous") == OK, "Interrupt a native v3 save between renames")
	var recovered := Wallet.new(path)
	check(recovered.load_state() and recovered.balance == 4
		and recovered.credit_amount("combo:native-one", 1).duplicate
		and recovered.credit_amount("combo:native-retry", 3).duplicate,
		"Native recovery restores exact coins and permanently acknowledges both receipts")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(directory)

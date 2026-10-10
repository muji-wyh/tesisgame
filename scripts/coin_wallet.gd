extends RefCounted
## A chest receipt and its coins are committed together and never expire.

const VERSION: int = 1
const COINS_PER_TIER: int = 50
const MAX_BALANCE: int = 9007199254740991
const MAX_TIER: int = 180143985094819
const MAX_RECEIPTS: int = 100000
const MAX_ID_LENGTH: int = 512
const MAX_SAVE_BYTES: int = 4 * 1024 * 1024

var ready: bool = false
var balance: int = 0
var error: String = ""
var _receipts: Dictionary = {}
var _path: String
var _host: Object
var _saved_text: Variant = null


func _init(path: String = "user://coin-wallet-v1.cfg", host: Object = null) -> void:
	_path = path
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")


func load_state() -> bool:
	ready = false
	error = ""
	if _path.is_empty():
		return _fail("Choose a save path before loading your coins.")
	if _host == null and not OS.has_feature("web"):
		if not FileAccess.file_exists(_path) and FileAccess.file_exists(_path + ".previous"):
			if DirAccess.rename_absolute(_path + ".previous", _path) != OK:
				return _fail("Could not restore your coins. Please retry.")
	var stored: Dictionary = _read_snapshot()
	if not stored.ok:
		return false
	var next_balance: int = 0
	var next_receipts: Dictionary = {}
	if stored.text != null:
		var config := ConfigFile.new()
		if config.parse(stored.text) != OK or config.get_sections().size() != 1 \
			or not config.has_section("wallet") or config.get_section_keys("wallet").size() != 3:
			return _fail("Your coin save could not be understood. Please retry.")
		var version: Variant = config.get_value("wallet", "version", null)
		var saved_balance: Variant = config.get_value("wallet", "balance", null)
		var receipts: Variant = config.get_value("wallet", "receipts", null)
		if not version is int or version != VERSION:
			return _fail("This coin save needs a supported version.")
		if not saved_balance is int or saved_balance < 0 or saved_balance > MAX_BALANCE \
			or not receipts is Dictionary or receipts.size() > MAX_RECEIPTS:
			return _fail("Your coin save contains an invalid balance or receipt history.")
		for id in receipts:
			var amount: Variant = receipts[id]
			if not _valid_id(id) or not amount is int or amount < COINS_PER_TIER \
				or amount > MAX_BALANCE or amount % COINS_PER_TIER != 0 \
				or next_balance > MAX_BALANCE - amount:
				return _fail("Your coin save contains an invalid chest receipt.")
			next_receipts[id] = amount
			next_balance += amount
		if saved_balance != next_balance:
			return _fail("Your coin balance does not match its saved chest receipts.")
	balance = next_balance
	_receipts = next_receipts
	_saved_text = stored.text
	ready = true
	return true


func credit(chest_id: String, tier: int) -> Dictionary:
	error = ""
	if not ready:
		return _rejected("Load your coins successfully before opening this chest.")
	if not _valid_id(chest_id) or tier < 0 or tier > MAX_TIER:
		return _rejected("This chest needs a valid reward ID and level.")
	# Ordinary chests have no tier; both ordinary and tier-one chests pay 50.
	var amount: int = maxi(1, tier) * COINS_PER_TIER
	if not _current_snapshot_matches():
		return _outcome(false, false, 0, balance)
	if _receipts.has(chest_id):
		if int(_receipts[chest_id]) != amount:
			return _rejected("This chest's saved coin reward has a different level.")
		return _outcome(true, true, 0, balance)
	if _receipts.size() >= MAX_RECEIPTS:
		return _rejected("Your coin receipt storage is full. Your chest remains unopened.")
	if balance > MAX_BALANCE - amount:
		return _rejected("This reward exceeds the supported coin balance. Your chest remains unopened.")
	var before: int = balance
	var next_receipts: Dictionary = _receipts.duplicate()
	next_receipts[chest_id] = amount
	if not _persist(balance + amount, next_receipts):
		return _outcome(false, false, 0, before)
	balance += amount
	_receipts = next_receipts
	return _outcome(true, false, amount, before)


func _persist(next_balance: int, next_receipts: Dictionary) -> bool:
	var config := ConfigFile.new()
	config.set_value("wallet", "version", VERSION)
	config.set_value("wallet", "balance", next_balance)
	config.set_value("wallet", "receipts", next_receipts)
	var text: String = config.encode_to_text()
	if text.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return _fail("Your coin receipt storage is full. Your chest remains unopened.")
	if _host != null:
		var result: Variant = _host.saveCoinWalletState(text, _saved_text)
		if not result is bool or not result:
			return _fail("Your coins have not saved yet. Please retry; reload if another tab changed your coins.")
	elif OS.has_feature("web"):
		return _fail("Coin storage is unavailable. Please retry.")
	else:
		if not _current_snapshot_matches():
			return false
		if config.save(_path + ".pending") != OK:
			return _fail("Your coins have not saved yet. Please retry.")
		if FileAccess.file_exists(_path + ".previous") and DirAccess.remove_absolute(_path + ".previous") != OK:
			return _fail("Could not preserve your coins. Please retry.")
		var had_previous: bool = FileAccess.file_exists(_path)
		if had_previous and DirAccess.rename_absolute(_path, _path + ".previous") != OK:
			return _fail("Could not preserve your coins. Please retry.")
		if DirAccess.rename_absolute(_path + ".pending", _path) != OK:
			if had_previous:
				DirAccess.rename_absolute(_path + ".previous", _path)
			return _fail("Your coins have not saved yet. Please retry.")
		if had_previous:
			DirAccess.remove_absolute(_path + ".previous")
	_saved_text = text
	return true


func _read_snapshot() -> Dictionary:
	var text: Variant = null
	if _host != null:
		text = _host.coinWalletState()
	elif OS.has_feature("web"):
		_fail("Coin storage is unavailable. Please retry.")
		return {"ok": false}
	elif DirAccess.dir_exists_absolute(_path):
		_fail("Could not read your coins. Please retry.")
		return {"ok": false}
	elif FileAccess.file_exists(_path):
		var file := FileAccess.open(_path, FileAccess.READ)
		if file == null or file.get_length() > MAX_SAVE_BYTES:
			_fail("Could not read your coins. Please retry.")
			return {"ok": false}
		text = file.get_as_text()
		file.close()
	if text != null and (not text is String or text.is_empty() or text.to_utf8_buffer().size() > MAX_SAVE_BYTES):
		_fail("Could not read your coins. Please retry.")
		return {"ok": false}
	return {"ok": true, "text": text}


func _current_snapshot_matches() -> bool:
	var stored: Dictionary = _read_snapshot()
	if not stored.ok:
		return false
	if stored.text != _saved_text:
		return _fail("Your coins changed in another session. Reload before opening this chest.")
	return true


func _valid_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > MAX_ID_LENGTH or value.strip_edges() != value:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return false
	return true


func _outcome(ok: bool, duplicate: bool, amount: int, before: int) -> Dictionary:
	return {"ok": ok, "duplicate": duplicate, "amount": amount, "before": before, "after": balance, "error": error}


func _rejected(message: String) -> Dictionary:
	_fail(message)
	return _outcome(false, false, 0, balance)


func _fail(message: String) -> bool:
	error = message
	return false

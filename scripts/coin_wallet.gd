extends RefCounted
## Coin changes and their permanent receipts commit together.

const VERSION: int = 4
const Economy = preload("res://scripts/coin_economy.gd")
const COINS_PER_TIER: int = Economy.COINS_PER_TIER
const MAX_BALANCE: int = 9007199254740991
const MAX_TIER: int = 180143985094819
const MAX_RECEIPTS: int = 100000
const MAX_ID_LENGTH: int = 512
const MAX_SAVE_BYTES: int = 4 * 1024 * 1024

var ready: bool = false
var balance: int = 0
var error: String = ""
var _receipts: Dictionary = {}
var _chest_rewards: Dictionary = {}
# A failed reservation retains its first quote across explicit storage reloads.
var _chest_drafts: Dictionary = {}
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
	var next_rewards: Dictionary = {}
	if stored.text != null:
		var config := ConfigFile.new()
		if config.parse(stored.text) != OK or config.get_sections().size() != 1 \
			or not config.has_section("wallet"):
			return _fail("Your coin save could not be understood. Please retry.")
		var version: Variant = config.get_value("wallet", "version", null)
		var saved_balance: Variant = config.get_value("wallet", "balance", null)
		var receipts: Variant = config.get_value("wallet", "receipts", null)
		if not version is int or version not in [1, 2, 3, VERSION]:
			return _fail("This coin save needs a supported version.")
		if config.get_section_keys("wallet").size() != (4 if version == VERSION else 3):
			return _fail("Your coin save could not be understood. Please retry.")
		if not saved_balance is int or saved_balance < 0 or saved_balance > MAX_BALANCE \
			or not receipts is Dictionary or receipts.size() > MAX_RECEIPTS:
			return _fail("Your coin save contains an invalid balance or receipt history.")
		var credits: Array[int] = []
		var debits: Array[int] = []
		for id in receipts:
			var amount: Variant = receipts[id]
			if not _valid_id(id) or not amount is int or amount == 0 \
				or amount < -MAX_BALANCE or amount > MAX_BALANCE \
				or ((version < 3 or amount < 0) and amount % COINS_PER_TIER != 0) \
				or (version == 1 and amount < 0):
				return _fail("Your coin save contains an invalid receipt.")
			next_receipts[id] = amount
			if amount > 0:
				credits.append(amount)
			else:
				debits.append(amount)
		# ConfigFile may reorder dictionary entries. Cancel opposite signs first:
		# lifetime earnings can exceed MAX_BALANCE while the actual wallet cannot.
		while not credits.is_empty() or not debits.is_empty():
			var amount: int
			if not credits.is_empty() and (next_balance <= 0 or debits.is_empty()):
				amount = credits.pop_back()
			else:
				amount = debits.pop_back()
			if (amount > 0 and next_balance > MAX_BALANCE - amount) \
				or (amount < 0 and next_balance < -MAX_BALANCE - amount):
				return _fail("Your coin save contains an invalid receipt total.")
			next_balance += amount
		if saved_balance != next_balance:
			return _fail("Your coin balance does not match its saved receipts.")
		if version == VERSION:
			var rewards: Variant = config.get_value("wallet", "chest_rewards", null)
			if not rewards is Dictionary or rewards.size() > MAX_RECEIPTS:
				return _fail("Your saved chest rewards could not be understood.")
			for id in rewards:
				if not _valid_id(id) or not _valid_chest_reward(rewards[id], next_receipts.get(id, 0)):
					return _fail("Your coin save contains an invalid chest reward.")
				next_rewards[id] = rewards[id].duplicate(true)
	balance = next_balance
	_receipts = next_receipts
	_chest_rewards = next_rewards
	for id in _chest_rewards:
		_chest_drafts.erase(id)
	_saved_text = stored.text
	ready = true
	return true


func chest_reward(id: String) -> Dictionary:
	return _chest_rewards.get(id, {}).duplicate(true) if ready else {}


func has_chest_reward_context(id: String) -> bool:
	return ready and (_chest_rewards.has(id) or _chest_drafts.has(id) or int(_receipts.get(id, 0)) > 0)


func reserve_chest(id: String, tier: int, pip_level: int) -> Dictionary:
	error = ""
	if not ready:
		return _reservation_rejected("Load your coins successfully before preparing this chest.")
	if not _valid_id(id) or tier < 0 or tier > MAX_TIER:
		return _reservation_rejected("This chest needs a valid reward ID and level.")
	var reward_tier: int = maxi(1, tier)
	var reward: Dictionary = _chest_rewards.get(id, {}).duplicate(true)
	if not reward.is_empty():
		if int(reward.tier) != reward_tier:
			return _reservation_rejected("This chest's saved level is different.", reward)
		if not _current_snapshot_matches():
			return {"ok": false, "reward": reward, "error": error}
		return {"ok": true, "reward": reward, "error": ""}
	if _chest_drafts.has(id) and int(_chest_drafts[id].tier) != reward_tier:
		return _reservation_rejected("This chest's reserved level is different.", _chest_drafts[id])
	if _receipts.has(id):
		var original: int = int(_receipts[id])
		if original <= 0:
			return _reservation_rejected("This chest ID already belongs to a purchase.")
		# Paid pre-quote rewards keep their original receipt, including exact v3
		# amounts. Their historical Pip level is unknown and gains no new bonus.
		reward = {"policy": Economy.LEGACY_CHEST_REWARD_POLICY, "pip_level": 0,
			"tier": reward_tier, "base": original, "bonus": 0, "total": original}
	elif _chest_drafts.has(id):
		reward = _chest_drafts[id].duplicate(true)
	else:
		var level: int = clampi(pip_level, 0, 99)
		var per_tier: int = COINS_PER_TIER + ceili(level / 4.0)
		@warning_ignore("integer_division")
		var supported_tier: int = MAX_BALANCE / per_tier
		if reward_tier > supported_tier:
			return _reservation_rejected("This chest exceeds the supported coin reward.")
		reward = Economy.chest_reward(reward_tier, level)
	if not _chest_drafts.has(id) and _chest_drafts.size() >= MAX_RECEIPTS:
		return _reservation_rejected("Your pending chest reward storage is full.", reward)
	_chest_drafts[id] = reward.duplicate(true)
	if not _current_snapshot_matches():
		return {"ok": false, "reward": reward, "error": error}
	if _chest_rewards.size() >= MAX_RECEIPTS:
		return _reservation_rejected("Your chest reward storage is full. This reward has not been saved.", reward)
	var next_rewards: Dictionary = _chest_rewards.duplicate(true)
	next_rewards[id] = reward.duplicate(true)
	if not _persist(balance, _receipts, next_rewards):
		return {"ok": false, "reward": reward, "error": error}
	_chest_rewards = next_rewards
	_chest_drafts.erase(id)
	return {"ok": true, "reward": reward, "error": ""}


func credit_chest(id: String, tier: int, pip_level: int) -> Dictionary:
	var reservation: Dictionary = reserve_chest(id, tier, pip_level)
	var result: Dictionary = _credit_amount(id, int(reservation.reward.total)) if reservation.ok \
		else _outcome(false, false, 0, balance)
	result["chest_reward"] = reservation.reward.duplicate(true)
	return result


func _reservation_rejected(message: String, reward: Dictionary = {}) -> Dictionary:
	_fail(message)
	return {"ok": false, "reward": reward.duplicate(true), "error": error}


func _valid_chest_reward(value: Variant, receipt: int) -> bool:
	if not value is Dictionary or value.size() != 6 or not value.get("policy") is String:
		return false
	for field in ["pip_level", "tier", "base", "bonus", "total"]:
		if not value.get(field) is int:
			return false
	if value.pip_level < 0 or value.pip_level > 99 or value.tier < 1 or value.tier > MAX_TIER \
		or value.base < 1 or value.base > MAX_BALANCE or value.bonus < 0 \
		or value.bonus > MAX_BALANCE - value.base or value.total != value.base + value.bonus \
		or receipt < 0 or (receipt > 0 and receipt != value.total):
		return false
	if value.policy == Economy.LEGACY_CHEST_REWARD_POLICY:
		return receipt == value.total and value.pip_level == 0 and value.bonus == 0
	if value.policy != Economy.CHEST_REWARD_POLICY:
		return false
	var per_tier: int = COINS_PER_TIER + ceili(value.pip_level / 4.0)
	@warning_ignore("integer_division")
	var supported_tier: int = MAX_BALANCE / per_tier
	return value.tier <= supported_tier and value == Economy.chest_reward(value.tier, value.pip_level)


func credit(chest_id: String, tier: int) -> Dictionary:
	error = ""
	if not ready:
		return _rejected("Load your coins successfully before opening this chest.")
	if not _valid_id(chest_id) or tier < 0 or tier > MAX_TIER:
		return _rejected("This chest needs a valid reward ID and level.")
	# Ordinary chests have no tier; both ordinary and tier-one chests pay 50.
	var amount: int = Economy.chest_coins(tier)
	return _credit_amount(chest_id, amount)


func credit_amount(receipt_id: String, amount: Variant) -> Dictionary:
	error = ""
	if not ready:
		return _rejected("Load your coins successfully before collecting this reward.")
	# Validate before conversion so fractional, string, and boolean inputs cannot
	# silently change the immutable amount attached to this receipt.
	if not _valid_id(receipt_id) or not amount is int or amount <= 0 or amount > MAX_BALANCE:
		return _rejected("This reward needs a valid ID and a positive whole coin amount.")
	return _credit_amount(receipt_id, int(amount))


func _credit_amount(receipt_id: String, amount: int) -> Dictionary:
	if not _current_snapshot_matches():
		return _outcome(false, false, 0, balance)
	if _chest_rewards.has(receipt_id) and int(_chest_rewards[receipt_id].total) != amount:
		return _rejected("This reward's reserved coin amount is different.")
	if _receipts.has(receipt_id):
		if int(_receipts[receipt_id]) != amount:
			return _rejected("This reward's saved coin amount is different.")
		return _outcome(true, true, 0, balance)
	if _receipts.size() >= MAX_RECEIPTS:
		return _rejected("Your coin receipt storage is full. This reward has not been saved.")
	if balance > MAX_BALANCE - amount:
		return _rejected("This reward exceeds the supported coin balance and has not been saved.")
	var before: int = balance
	var next_receipts: Dictionary = _receipts.duplicate()
	next_receipts[receipt_id] = amount
	if not _persist(balance + amount, next_receipts):
		return _outcome(false, false, 0, before)
	balance += amount
	_receipts = next_receipts
	return _outcome(true, false, amount, before)


func has_purchase(purchase_id: String, amount: int) -> bool:
	return ready and amount > 0 and int(_receipts.get(purchase_id, 0)) == -amount


func spend(purchase_id: String, amount: int) -> Dictionary:
	error = ""
	if not ready:
		return _rejected("Load your coins successfully before making this purchase.")
	if not _valid_id(purchase_id) or amount < COINS_PER_TIER or amount > MAX_BALANCE or amount % COINS_PER_TIER != 0:
		return _rejected("This purchase needs a valid ID and a positive cost in multiples of 50 coins.")
	if not _current_snapshot_matches():
		return _outcome(false, false, 0, balance)
	if _chest_rewards.has(purchase_id):
		return _rejected("This purchase ID already belongs to a chest reward.")
	if _receipts.has(purchase_id):
		if int(_receipts[purchase_id]) != -amount:
			return _rejected("This purchase's saved coin cost is different.")
		return _outcome(true, true, 0, balance)
	if _receipts.size() >= MAX_RECEIPTS:
		return _rejected("Your coin receipt storage is full. This purchase has not been charged.")
	if balance < amount:
		# Affordability is an ordinary game state, not a storage failure.
		var insufficient: Dictionary = _outcome(false, false, 0, balance)
		insufficient.reason = "insufficient"
		insufficient.error = "You need more coins for this purchase."
		return insufficient
	var before: int = balance
	var next_receipts: Dictionary = _receipts.duplicate()
	next_receipts[purchase_id] = -amount
	if not _persist(balance - amount, next_receipts):
		return _outcome(false, false, 0, before)
	balance -= amount
	_receipts = next_receipts
	return _outcome(true, false, -amount, before)


func _persist(next_balance: int, next_receipts: Dictionary, next_rewards: Variant = null) -> bool:
	var config := ConfigFile.new()
	config.set_value("wallet", "version", VERSION)
	config.set_value("wallet", "balance", next_balance)
	config.set_value("wallet", "receipts", next_receipts)
	config.set_value("wallet", "chest_rewards", _chest_rewards if next_rewards == null else next_rewards)
	var text: String = config.encode_to_text()
	if text.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return _fail("Your coin receipt storage is full. This transaction has not been saved.")
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
		return _fail("Your coins changed in another session. Reload before changing your coins.")
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

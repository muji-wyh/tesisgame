extends RefCounted
## Receipt-backed local persistence for Jelly World RPG progression:
## Pip stance, 8 Boss relics + levels, Boss tokens, Boss ascension clears,
## Jelly World active bounties (3 slots), permanent deeds, and gentle active-day milestones.

const Catalog = preload("res://scripts/word_jelly_rpg_catalog.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")

const VERSION: int = 1
const MAX_SAVE_BYTES: int = 512 * 1024
const MAX_RECEIPTS: int = 2048
const BOUNTY_SLOT_COUNT: int = 3

const BOUNTY_TEMPLATES: Array[Dictionary] = [
	{"id": "collect_words", "title": "Word Harvester", "desc": "Collect %d merged words in Jelly World", "metric": "collections", "targets": [6, 12, 20], "coins": [50, 90, 150], "tokens": [0, 0, 1]},
	{"id": "high_merge", "title": "Jelly Alchemist", "desc": "Collect %d Lv2+ merged Jellies", "metric": "high_collects", "targets": [2, 5, 9], "coins": [60, 110, 175], "tokens": [0, 1, 1]},
	{"id": "combo_rank", "title": "Rhythm Master", "desc": "Reach Combo Rank %s in Jelly World", "metric": "best_combo", "targets": [3, 4, 5], "rank_labels": ["B", "A", "S"], "coins": [60, 100, 160], "tokens": [0, 0, 1]},
	{"id": "companion_skill", "title": "Pip's Power", "desc": "Trigger Pip's Companion Skill %d times", "metric": "skills_used", "targets": [1, 2, 4], "coins": [55, 95, 150], "tokens": [0, 0, 1]},
	{"id": "clear_stage", "title": "Trail Blazer", "desc": "Clear %d Jelly World stage(s)", "metric": "stages_cleared", "targets": [1, 2, 3], "coins": [65, 120, 185], "tokens": [0, 1, 1]},
	{"id": "three_star", "title": "Golden Precision", "desc": "Earn %d three-star clear(s) in Jelly World", "metric": "three_star_clears", "targets": [1, 2, 3], "coins": [80, 140, 210], "tokens": [0, 1, 1]},
	{"id": "boss_dodge", "title": "Nimble Explorer", "desc": "Dodge %d Pirate attack(s) or clear a Boss", "metric": "boss_actions", "targets": [1, 3, 5], "coins": [75, 130, 200], "tokens": [1, 1, 2]},
	{"id": "challenge_wave", "title": "Endless Runner", "desc": "Clear %d Survival Challenge wave(s)", "metric": "challenge_waves", "targets": [2, 4, 7], "coins": [70, 125, 200], "tokens": [0, 1, 1]}
]

const DEEDS: Array[Dictionary] = [
	{"id": "first_skill", "title": "First Spark", "desc": "Trigger Pip's Companion Skill", "metric": "skills_used", "target": 1, "coins": 75, "tokens": 0},
	{"id": "skill_veteran", "title": "Tactical Partner", "desc": "Trigger Pip's Companion Skill 15 times", "metric": "skills_used", "target": 15, "coins": 200, "tokens": 2},
	{"id": "collector_50", "title": "Word Gatherer", "desc": "Collect 50 merged words in Jelly World", "metric": "collections", "target": 50, "coins": 150, "tokens": 1},
	{"id": "collector_250", "title": "Grand Lexicographer", "desc": "Collect 250 merged words in Jelly World", "metric": "collections", "target": 250, "coins": 350, "tokens": 3},
	{"id": "combo_s", "title": "Unstoppable Flow", "desc": "Reach Combo Rank S in Jelly World", "metric": "max_combo", "target": 5, "coins": 175, "tokens": 1},
	{"id": "pure_5", "title": "Pure Explorer", "desc": "Finish 5 Pure Clears (no paid powerups)", "metric": "pure_clears", "target": 5, "coins": 225, "tokens": 2},
	{"id": "relic_3", "title": "Relic Hunter", "desc": "Unlock 3 Pirate Compass Relics", "metric": "relics_unlocked", "target": 3, "coins": 200, "tokens": 2},
	{"id": "relic_max", "title": "Master Artificer", "desc": "Upgrade any Relic to Lv3", "metric": "max_relic_level", "target": 3, "coins": 300, "tokens": 2},
	{"id": "challenge_10", "title": "Boon Weaver", "desc": "Reach Stage 10 in Survival Challenge", "metric": "max_challenge", "target": 10, "coins": 300, "tokens": 2},
	{"id": "ascension_1", "title": "Pirate Nemesis", "desc": "Defeat any Elite or Legend Boss", "metric": "ascension_clears", "target": 1, "coins": 250, "tokens": 2},
	{"id": "active_3_days", "title": "3-Day Adventurer", "desc": "Play Jelly World on 3 different days", "metric": "active_days", "target": 3, "coins": 150, "tokens": 1},
	{"id": "active_7_days", "title": "Weekly Voyager", "desc": "Play Jelly World on 7 different days", "metric": "active_days", "target": 7, "coins": 350, "tokens": 2}
]

var ready: bool = false
var error: String = ""
var _path: String
var _host: Object
var _saved_text: Variant = null
var _state: Dictionary = {}


func _init(path: String = "user://jelly-rpg-v1.cfg", host: Object = null) -> void:
	_path = path
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")
	_state = _default_state()


static func _default_state() -> Dictionary:
	return {
		"stance": "scholar",
		"equipped_relics": [],
		"relic_levels": {},
		"boss_tokens": 0,
		"boss_ascensions": {},
		"bounty_serial": 0,
		"bounties": [],
		"claimed_deeds": [],
		"totals": {
			"collections": 0,
			"high_collects": 0,
			"skills_used": 0,
			"stages_cleared": 0,
			"three_star_clears": 0,
			"pure_clears": 0,
			"boss_actions": 0,
			"challenge_waves": 0,
			"max_combo": 0,
			"max_challenge": 0,
			"ascension_clears": 0
		},
		"active_days": [],
		"receipts": []
	}


func load_state() -> bool:
	ready = false
	error = ""
	if _path.is_empty():
		return _fail("Choose an RPG save path before loading.")
	var stored: Dictionary = _read_snapshot()
	if not stored.ok:
		return false
	var next: Dictionary = _default_state()
	if stored.text != null:
		var config := ConfigFile.new()
		if config.parse(stored.text) != OK or not config.has_section("rpg"):
			return _fail("Your Jelly RPG save could not be understood.")
		var version: Variant = config.get_value("rpg", "version", null)
		if not version is int or int(version) != VERSION:
			return _fail("This Jelly RPG save needs a supported version.")
		var loaded: Variant = config.get_value("rpg", "state", null)
		if not loaded is Dictionary:
			return _fail("Your Jelly RPG state is incomplete.")
		next = _normalize_state(loaded)
	_ensure_bounties(next)
	_state = next
	_saved_text = stored.text
	ready = true
	return true


func _normalize_state(loaded: Dictionary) -> Dictionary:
	var result: Dictionary = _default_state()
	var stance: String = str(loaded.get("stance", "scholar"))
	result.stance = stance if stance in Catalog.STANCE_IDS else "scholar"
	var levels: Variant = loaded.get("relic_levels", {})
	if levels is Dictionary:
		for key: Variant in levels:
			var id: String = str(key)
			if not Catalog.relic_by_id(id).is_empty():
				var lv: int = clampi(int(levels[key]), 0, Catalog.MAX_RELIC_LEVEL)
				if lv > 0:
					result.relic_levels[id] = lv
	var equipped: Variant = loaded.get("equipped_relics", [])
	if equipped is Array:
		for item: Variant in equipped:
			var id: String = str(item)
			if result.relic_levels.has(id) and not result.equipped_relics.has(id) and result.equipped_relics.size() < 3:
				result.equipped_relics.append(id)
	result.boss_tokens = maxi(0, int(loaded.get("boss_tokens", 0)))
	var asc: Variant = loaded.get("boss_ascensions", {})
	if asc is Dictionary:
		for key: Variant in asc:
			var id: int = int(str(key))
			if id >= 1 and id <= 8:
				result.boss_ascensions[str(id)] = clampi(int(asc[key]), 0, 2)
	result.bounty_serial = maxi(0, int(loaded.get("bounty_serial", 0)))
	var bounties: Variant = loaded.get("bounties", [])
	if bounties is Array:
		for item: Variant in bounties:
			if item is Dictionary and item.has_all(["uid", "template_id", "tier", "progress", "target", "coins", "tokens", "claimed"]):
				result.bounties.append(item.duplicate(true))
	var claimed_deeds: Variant = loaded.get("claimed_deeds", [])
	if claimed_deeds is Array:
		for item: Variant in claimed_deeds:
			var id: String = str(item)
			if not id.is_empty() and not result.claimed_deeds.has(id):
				result.claimed_deeds.append(id)
	var totals: Variant = loaded.get("totals", {})
	if totals is Dictionary:
		for key: String in result.totals:
			result.totals[key] = maxi(0, int(totals.get(key, 0)))
	var days: Variant = loaded.get("active_days", [])
	if days is Array:
		for item: Variant in days:
			var day: String = str(item)
			if not day.is_empty() and not result.active_days.has(day) and result.active_days.size() < 400:
				result.active_days.append(day)
	var receipts: Variant = loaded.get("receipts", [])
	if receipts is Array:
		for item: Variant in receipts:
			var id: String = str(item)
			if not id.is_empty() and not result.receipts.has(id):
				result.receipts.append(id)
		while result.receipts.size() > MAX_RECEIPTS:
			result.receipts.pop_front()
	return result


func state() -> Dictionary:
	return _state.duplicate(true)


func stance() -> String:
	return str(_state.get("stance", "scholar"))


func boss_tokens() -> int:
	return int(_state.get("boss_tokens", 0))


func relic_level(relic_id: String) -> int:
	return int(_state.relic_levels.get(relic_id, 0))


func equipped_relics() -> Array:
	return _state.equipped_relics.duplicate()


func highest_boss_ascension(boss_id: int) -> int:
	return int(_state.boss_ascensions.get(str(boss_id), 0))


func sync_boss_victories(boss_victories: Array, slot_capacity: int = 1) -> Array[String]:
	if not ready:
		return []
	var newly_unlocked: Array[String] = []
	var next: Dictionary = _state.duplicate(true)
	for raw_id: Variant in boss_victories:
		var boss_id: int = int(raw_id)
		var relic: Dictionary = Catalog.relic_for_boss(boss_id)
		if relic.is_empty():
			continue
		var rid: String = str(relic.id)
		if not next.relic_levels.has(rid):
			next.relic_levels[rid] = 1
			newly_unlocked.append(rid)
			if next.equipped_relics.size() < clampi(slot_capacity, 1, 3):
				next.equipped_relics.append(rid)
	if newly_unlocked.is_empty():
		return []
	if _commit(next):
		return newly_unlocked
	return []


func set_stance(next_stance: String) -> bool:
	if not ready:
		return _fail("Load Jelly RPG state before changing stance.")
	if next_stance not in Catalog.STANCE_IDS:
		return _fail("Choose Spark Scholar, Compass Hunter, or Treasure Seeker.")
	if _state.stance == next_stance:
		return true
	var next: Dictionary = _state.duplicate(true)
	next.stance = next_stance
	return _commit(next)


func toggle_equip_relic(relic_id: String, slot_capacity: int) -> bool:
	if not ready:
		return _fail("Load Jelly RPG state before equipping relics.")
	if not _state.relic_levels.has(relic_id):
		return _fail("Unlock this Boss relic before equipping it.")
	var next: Dictionary = _state.duplicate(true)
	var limit: int = clampi(slot_capacity, 1, 3)
	if next.equipped_relics.has(relic_id):
		next.equipped_relics.erase(relic_id)
	else:
		if next.equipped_relics.size() >= limit:
			next.equipped_relics.pop_front()
		next.equipped_relics.append(relic_id)
	return _commit(next)


func upgrade_relic(relic_id: String, wallet: Wallet) -> Dictionary:
	if not ready:
		return {"ok": false, "error": "Load Jelly RPG state before upgrading relics."}
	var current_lv: int = relic_level(relic_id)
	if current_lv <= 0:
		return {"ok": false, "error": "Defeat the Pirate Boss first to unlock this relic."}
	if current_lv >= Catalog.MAX_RELIC_LEVEL:
		return {"ok": false, "error": "This relic is already at maximum Lv3."}
	var cost: Dictionary = Catalog.relic_upgrade_cost(current_lv)
	var coin_cost: int = int(cost.coins)
	var token_cost: int = int(cost.tokens)
	if boss_tokens() < token_cost:
		return {"ok": false, "error": "Need %d Boss token(s). Replay any Boss or Pirate Raid." % token_cost}
	var next_lv: int = current_lv + 1
	var receipt: String = "jelly-relic-upgrade-v1:%s:%d" % [relic_id, next_lv]
	if wallet == null or not wallet.ready:
		return {"ok": false, "error": "Wallet is unavailable. Please retry."}
	var paid: bool = wallet.has_purchase(receipt, coin_cost)
	if not paid:
		if wallet.balance < coin_cost:
			return {"ok": false, "error": "Need %d more coins to upgrade this relic." % (coin_cost - wallet.balance)}
		var spent: Dictionary = wallet.spend(receipt, coin_cost)
		if not bool(spent.get("ok", false)):
			return {"ok": false, "error": str(wallet.error if not wallet.error.is_empty() else "Could not spend coins.")}
	var next: Dictionary = _state.duplicate(true)
	next.boss_tokens = maxi(0, int(next.boss_tokens) - token_cost)
	next.relic_levels[relic_id] = next_lv
	if not _commit(next):
		return {"ok": false, "error": error}
	return {"ok": true, "level": next_lv, "coins": coin_cost, "tokens": token_cost}


func record_round_progress(receipt_id: String, summary: Dictionary, slot_capacity: int = 1,
		day_stamp: String = "") -> Dictionary:
	if not ready or receipt_id.is_empty():
		return {"ok": false, "new_relics": [], "tokens_earned": 0, "ascension_bounty": 0}
	if _state.receipts.has(receipt_id):
		return {"ok": true, "duplicate": true, "new_relics": [], "tokens_earned": 0, "ascension_bounty": 0}
	var next: Dictionary = _state.duplicate(true)
	next.receipts.append(receipt_id)
	while next.receipts.size() > MAX_RECEIPTS:
		next.receipts.pop_front()

	var stamp: String = day_stamp if not day_stamp.is_empty() else Time.get_date_string_from_system()
	if not stamp.is_empty() and not next.active_days.has(stamp):
		next.active_days.append(stamp)

	var collections: int = maxi(0, int(summary.get("collections", 0)))
	var high_collects: int = maxi(0, int(summary.get("high_collects", 0)))
	var best_combo: int = maxi(0, int(summary.get("best_combo", 0)))
	var skills_used: int = maxi(0, int(summary.get("skills_used", 0)))
	var cleared: bool = bool(summary.get("cleared", false))
	var stars: int = clampi(int(summary.get("stars", 0)), 0, 3)
	var pure_clear: bool = bool(summary.get("pure_clear", false))
	var boss_dodges: int = maxi(0, int(summary.get("boss_dodges", 0)))
	var boss_victory: bool = bool(summary.get("boss_victory", false))
	var boss_id: int = clampi(int(summary.get("boss_id", 0)), 0, 8)
	var mini_raid_victory: bool = bool(summary.get("mini_raid_victory", false))
	var boss_ascension: int = clampi(int(summary.get("boss_ascension", 0)), 0, 2)
	var challenge_stage: int = maxi(0, int(summary.get("challenge_stage", 0)))
	var challenge_waves: int = maxi(0, challenge_stage - 1) if challenge_stage > 0 else 0

	next.totals.collections = int(next.totals.collections) + collections
	next.totals.high_collects = int(next.totals.high_collects) + high_collects
	next.totals.skills_used = int(next.totals.skills_used) + skills_used
	if cleared:
		next.totals.stages_cleared = int(next.totals.stages_cleared) + 1
		if stars >= 3:
			next.totals.three_star_clears = int(next.totals.three_star_clears) + 1
		if pure_clear:
			next.totals.pure_clears = int(next.totals.pure_clears) + 1
	var boss_actions: int = boss_dodges + (1 if boss_victory or mini_raid_victory else 0)
	next.totals.boss_actions = int(next.totals.boss_actions) + boss_actions
	next.totals.challenge_waves = int(next.totals.challenge_waves) + challenge_waves
	next.totals.max_combo = maxi(int(next.totals.max_combo), best_combo)
	next.totals.max_challenge = maxi(int(next.totals.max_challenge), challenge_stage)

	var new_relics: Array[String] = []
	var tokens_earned: int = 0
	var ascension_bounty: int = 0
	if boss_victory and boss_id >= 1:
		var relic: Dictionary = Catalog.relic_for_boss(boss_id)
		if not relic.is_empty():
			var rid: String = str(relic.id)
			if not next.relic_levels.has(rid):
				next.relic_levels[rid] = 1
				new_relics.append(rid)
				if next.equipped_relics.size() < clampi(slot_capacity, 1, 3):
					next.equipped_relics.append(rid)
		var asc_spec: Dictionary = Catalog.ascension_by_tier(boss_ascension)
		tokens_earned += int(asc_spec.token_reward)
		var prev_asc: int = int(next.boss_ascensions.get(str(boss_id), 0))
		if boss_ascension > prev_asc:
			next.boss_ascensions[str(boss_id)] = boss_ascension
			ascension_bounty = int(asc_spec.coin_bounty)
			next.totals.ascension_clears = int(next.totals.ascension_clears) + 1
	elif mini_raid_victory:
		tokens_earned += 1
	next.boss_tokens = int(next.boss_tokens) + tokens_earned

	var increments: Dictionary = {
		"collections": collections,
		"high_collects": high_collects,
		"skills_used": skills_used,
		"stages_cleared": 1 if cleared else 0,
		"three_star_clears": 1 if cleared and stars >= 3 else 0,
		"boss_actions": boss_actions,
		"challenge_waves": challenge_waves
	}
	for bounty: Dictionary in next.bounties:
		if bool(bounty.claimed):
			continue
		var metric: String = str(bounty.get("metric", ""))
		if metric == "best_combo":
			bounty.progress = mini(int(bounty.target), maxi(int(bounty.progress), best_combo))
		elif increments.has(metric):
			bounty.progress = mini(int(bounty.target), int(bounty.progress) + int(increments[metric]))

	_ensure_bounties(next)
	if not _commit(next):
		return {"ok": false, "error": error, "new_relics": [], "tokens_earned": 0, "ascension_bounty": 0}
	return {"ok": true, "new_relics": new_relics, "tokens_earned": tokens_earned, "ascension_bounty": ascension_bounty}


func claim_bounty(uid: String, wallet: Wallet) -> Dictionary:
	if not ready:
		return {"ok": false, "error": "Load Jelly RPG state before claiming bounties."}
	var index: int = -1
	for i in range(_state.bounties.size()):
		if str(_state.bounties[i].uid) == uid:
			index = i
			break
	if index < 0:
		return {"ok": false, "error": "This bounty is no longer active."}
	var bounty: Dictionary = _state.bounties[index]
	if bool(bounty.claimed):
		return {"ok": true, "duplicate": true, "coins": 0, "tokens": 0}
	if int(bounty.progress) < int(bounty.target):
		return {"ok": false, "error": "Complete this bounty before claiming its reward."}
	var coins: int = int(bounty.coins)
	var tokens: int = int(bounty.tokens)
	var receipt: String = "jelly-bounty-v1:" + uid
	if coins > 0 and wallet != null:
		var credited: Dictionary = wallet.credit_amount(receipt, coins)
		if not bool(credited.get("ok", false)):
			return {"ok": false, "error": str(wallet.error)}
	var next: Dictionary = _state.duplicate(true)
	next.boss_tokens = int(next.boss_tokens) + tokens
	next.bounties.remove_at(index)
	_ensure_bounties(next)
	if not _commit(next):
		return {"ok": false, "error": error}
	return {"ok": true, "coins": coins, "tokens": tokens}


func claim_deed(deed_id: String, wallet: Wallet) -> Dictionary:
	if not ready:
		return {"ok": false, "error": "Load Jelly RPG state before claiming deeds."}
	if _state.claimed_deeds.has(deed_id):
		return {"ok": true, "duplicate": true, "coins": 0, "tokens": 0}
	var found: Dictionary = {}
	for entry: Dictionary in DEEDS:
		if str(entry.id) == deed_id:
			found = entry
			break
	if found.is_empty():
		return {"ok": false, "error": "Unknown adventure deed."}
	if deed_progress(found) < int(found.target):
		return {"ok": false, "error": "Complete this deed before claiming its reward."}
	var coins: int = int(found.coins)
	var tokens: int = int(found.tokens)
	var receipt: String = "jelly-deed-v1:" + deed_id
	if coins > 0 and wallet != null:
		var credited: Dictionary = wallet.credit_amount(receipt, coins)
		if not bool(credited.get("ok", false)):
			return {"ok": false, "error": str(wallet.error)}
	var next: Dictionary = _state.duplicate(true)
	next.boss_tokens = int(next.boss_tokens) + tokens
	next.claimed_deeds.append(deed_id)
	if not _commit(next):
		return {"ok": false, "error": error}
	return {"ok": true, "coins": coins, "tokens": tokens}


func deed_progress(deed: Dictionary) -> int:
	var metric: String = str(deed.get("metric", ""))
	if metric == "relics_unlocked":
		return _state.relic_levels.size()
	if metric == "max_relic_level":
		var best: int = 0
		for lv: Variant in _state.relic_levels.values():
			best = maxi(best, int(lv))
		return best
	if metric == "active_days":
		return _state.active_days.size()
	return int(_state.totals.get(metric, 0))


func claimable_count() -> int:
	if not ready:
		return 0
	var count: int = 0
	for bounty: Dictionary in _state.bounties:
		if not bool(bounty.claimed) and int(bounty.progress) >= int(bounty.target):
			count += 1
	for deed: Dictionary in DEEDS:
		if not _state.claimed_deeds.has(str(deed.id)) and deed_progress(deed) >= int(deed.target):
			count += 1
	return count


func _ensure_bounties(target_state: Dictionary) -> void:
	while target_state.bounties.size() < BOUNTY_SLOT_COUNT:
		var serial: int = int(target_state.bounty_serial) + 1
		target_state.bounty_serial = serial
		var active_templates: Array[String] = []
		for existing: Dictionary in target_state.bounties:
			active_templates.append(str(existing.template_id))
		var pick_index: int = (serial * 3 + 1) % BOUNTY_TEMPLATES.size()
		for offset in range(BOUNTY_TEMPLATES.size()):
			var candidate: Dictionary = BOUNTY_TEMPLATES[(pick_index + offset) % BOUNTY_TEMPLATES.size()]
			if str(candidate.id) not in active_templates:
				pick_index = (pick_index + offset) % BOUNTY_TEMPLATES.size()
				break
		var tpl: Dictionary = BOUNTY_TEMPLATES[pick_index]
		var tier: int = clampi((serial - 1) / 4, 0, 2)
		var goal_value: int = int(tpl.targets[tier])
		var desc_text: String = str(tpl.desc) % str(tpl.rank_labels[tier]) if tpl.has("rank_labels") else str(tpl.desc) % goal_value
		target_state.bounties.append({
			"uid": "b%d" % serial,
			"template_id": str(tpl.id),
			"metric": str(tpl.metric),
			"title": str(tpl.title),
			"desc": desc_text,
			"tier": tier,
			"progress": 0,
			"target": goal_value,
			"coins": int(tpl.coins[tier]),
			"tokens": int(tpl.tokens[tier]),
			"claimed": false
		})


func _commit(next_state: Dictionary) -> bool:
	var config := ConfigFile.new()
	config.set_value("rpg", "version", VERSION)
	config.set_value("rpg", "state", next_state)
	var text: String = config.encode_to_text()
	if text.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return _fail("Jelly RPG storage is full.")
	if _host != null:
		if _host_method("saveJellyRpgState"):
			var ack: Variant = _host.saveJellyRpgState(text, _saved_text)
			if not ack is bool or not ack:
				return _fail("Your Jelly RPG progress could not save. Please retry.")
		else:
			# Test fixtures without web RPG host keep in-memory state cleanly.
			_state = next_state.duplicate(true)
			_saved_text = text
			return true
	elif OS.has_feature("web"):
		return _fail("Jelly RPG storage is unavailable.")
	else:
		var file := FileAccess.open(_path, FileAccess.WRITE)
		if file == null:
			return _fail("Could not write Jelly RPG save file.")
		file.store_string(text)
		file.flush()
		file.close()
	_state = next_state.duplicate(true)
	_saved_text = text
	return true


func _read_snapshot() -> Dictionary:
	var text: Variant = null
	if _host != null:
		if _host_method("jellyRpgState"):
			text = _host.jellyRpgState()
		else:
			return {"ok": true, "text": null}
	elif OS.has_feature("web"):
		_fail("Jelly RPG storage is unavailable.")
		return {"ok": false}
	elif FileAccess.file_exists(_path):
		var file := FileAccess.open(_path, FileAccess.READ)
		if file == null or file.get_length() > MAX_SAVE_BYTES:
			_fail("Could not read Jelly RPG save.")
			return {"ok": false}
		text = file.get_as_text()
		file.close()
	if text != null and (not text is String or text.is_empty() or text.to_utf8_buffer().size() > MAX_SAVE_BYTES):
		_fail("Jelly RPG save is unreadable.")
		return {"ok": false}
	return {"ok": true, "text": text}


func _host_method(method: String) -> bool:
	return _host.has_method(method) or _host.get_class() == "JavaScriptObject"


func _fail(message: String) -> bool:
	error = message
	return false

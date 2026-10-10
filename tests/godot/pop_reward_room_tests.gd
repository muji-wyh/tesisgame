extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const State = preload("res://scripts/pop_reward_state.gd")
const Room = preload("res://scripts/pop_reward_room.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const Style = preload("res://scripts/ui_style.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const PIXEL_TOLERANCE: float = 0.1

class Storage extends RefCounted:
	var text: Variant = null
	var jelly_text: Variant = null
	var readable: bool = true
	var writable: bool = true
	var writes: int = 0
	var jelly_writes: int = 0
	var coin_text: Variant = null
	var coin_writes: int = 0
	var coin_writable: bool = true
	var coin_write_limit: int = -1

	func popRewardState() -> Variant:
		return text if readable else false

	func savePopRewardState(value: String) -> bool:
		if not writable:
			return false
		text = value
		writes += 1
		return true

	func jellyRewardState() -> Variant:
		return jelly_text if readable else false

	func saveJellyRewardState(value: String) -> bool:
		if not writable:
			return false
		jelly_text = value
		jelly_writes += 1
		return true

	func coinWalletState() -> Variant:
		return coin_text

	func saveCoinWalletState(value: String, expected: Variant) -> bool:
		if not coin_writable or (coin_write_limit >= 0 and coin_writes >= coin_write_limit) or coin_text != expected:
			return false
		coin_text = value
		coin_writes += 1
		return true

var checks: int = 0
var failures: int = 0
var _manifest: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.size = Vector2i(960, 720)
	var data := Data.new()
	check(data.load_all(), "Load the shared chest artwork for the reward room")
	_manifest = data.chests
	_state_checks()
	_jelly_state_checks()
	_jelly_tier_checks()
	_pop_fragment_state_checks()
	await _room_checks()
	await _single_chest_layout_checks()
	await _retained_rewards_checks()
	await _failure_checks()
	await _responsive_resize_checks()
	await _deferred_layout_checks()
	await _jelly_pagination_checks()
	await _jelly_save_retry_checks()
	await _jelly_accumulation_checks()
	await _jelly_tier_room_checks()
	await _result_context_checks()
	await _collect_all_checks()
	await _collect_failure_checks()
	print("Pop treasure room: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _jelly_state(storage: Storage):
	var state := State.new("user://unused-jelly-test.cfg", storage)
	state.storage_kind = "jelly"
	state.max_chests = 0
	state.allow_repeated_themes = true
	return state


func _jelly_state_checks() -> void:
	var storage := Storage.new()
	var pop := State.new("user://unused-pop-test.cfg", storage)
	check(not pop.create_batch("over-pop-cap", ["spring", "summer", "autumn", "winter"]),
		"Voice Pop still rejects rewards above its default three-chest cap")
	check(pop.create_batch("pop-isolated", ["summer"]), "Prepare independent Pop treasure")
	var pop_text: String = storage.text
	var jelly = _jelly_state(storage)
	var themes: Array[String] = Room._choose_themes("long-jelly", 257, "ocean", true)
	check(themes.size() == 257 and themes.all(func(theme: String) -> bool: return theme == "ocean"),
		"Every Jelly chest uses the preferred theme without limiting the earned count")
	check(jelly.create_batch("long-jelly", themes) and jelly.entries.size() == 257,
		"An uncapped Jelly batch durably preserves more than three and more than 255 chests")
	check(storage.writes == 1 and storage.jelly_writes == 1 and storage.text == pop_text,
		"Jelly reads and writes use a separate host storage namespace")
	var reloaded = _jelly_state(storage)
	check(reloaded.load_state() and reloaded.entries.size() == 257
		and reloaded.entries.all(func(entry: Dictionary) -> bool: return entry.theme == "ocean"),
		"Reload preserves every repeated-theme chest without truncation")
	check(reloaded.mark_opened("long-jelly", 256) and reloaded.entries[256].opened
		and not reloaded.entries[0].opened, "High reward indexes consume their exact saved chest")
	var writes: int = storage.jelly_writes
	check(reloaded.mark_opened("long-jelly", 256) and reloaded.last_open_was_duplicate
		and storage.jelly_writes == writes, "Repeated callbacks on a high index cannot duplicate its reward")
	storage.writable = false
	check(not reloaded.mark_opened("long-jelly", 255) and not reloaded.entries[255].opened,
		"An uncapped reward's failed save remains unopened and retryable")
	storage.writable = true
	check(reloaded.mark_opened("long-jelly", 255) and reloaded.entries[255].opened,
		"Retry saves the exact previously failed Jelly chest")
	var pending_save: String = storage.jelly_text
	var pending_entries: Array[Dictionary] = reloaded.entries.duplicate(true)
	var pending_receipts: Array[String] = reloaded._receipts.duplicate()
	storage.writable = false
	check(not reloaded.create_batch("replace-pending", ["spring"])
		and storage.jelly_text == pending_save and reloaded.round_id == "long-jelly"
		and reloaded.entries == pending_entries and reloaded._receipts == pending_receipts,
		"A failed Jelly append preserves the durable batch, opened flags and receipts atomically")
	storage.writable = true
	check(reloaded.create_batch("replace-pending", ["spring"]) and reloaded.entries.size() == 256
		and reloaded.entries[0].theme == "ocean" and reloaded.entries[254].theme == "ocean"
		and reloaded.entries[255].theme == "spring"
		and reloaded.entries.all(func(entry: Dictionary) -> bool: return not entry.opened),
		"A new Jelly round carries all unopened treasure forward and omits already opened chests")
	writes = storage.jelly_writes
	check(reloaded.create_batch("long-jelly", ["space"])
		and reloaded.create_batch("replace-pending", ["winter"])
		and reloaded.round_id == "replace-pending" and reloaded.entries.size() == 256
		and reloaded.entries[255].theme == "spring" and storage.jelly_writes == writes,
		"Old and current Jelly batch callbacks are idempotent without adding or rerolling treasure")
	check(not reloaded.mark_opened("long-jelly", 0) and storage.jelly_writes == writes
		and not reloaded.entries[0].opened,
		"A stale pre-append chest callback cannot consume the current batch's remapped index")
	check(storage.text == pop_text and pop.load_state() and pop.entries.size() == 1
		and pop.entries[0].theme == "summer", "Jelly operations do not disturb an unopened Pop reward")
	var defaults := State.new()
	check(defaults._storage_path() == "user://pop-rewards-v1.cfg", "Default native treasure keeps its existing Pop path")
	defaults.storage_kind = "jelly"
	check(defaults._storage_path() == "user://jelly-rewards-v1.cfg", "Jelly automatically selects a separate native save path")
	var custom := State.new("user://custom-jelly.cfg")
	custom.storage_kind = "jelly"
	check(custom._storage_path() == "user://custom-jelly.cfg", "Explicit native test or user save paths are preserved")
	var small_storage := Storage.new()
	var complete = _jelly_state(small_storage)
	check(complete.create_batch("complete-jelly", Room._choose_themes("complete-jelly", 8, "space", true)),
		"Create an eight-chest receipt fixture")
	for index in range(8):
		check(complete.mark_opened("complete-jelly", index), "Every uncapped reward can complete independently")
	check(not complete.has_pending() and small_storage.jelly_writes == 9,
		"A completed uncapped batch writes once per chest and has no pending remainder")
	check(complete.create_batch("next-jelly", ["spring"]) and complete.mark_opened("next-jelly", 0),
		"Completed Jelly treasure permits a subsequent earned batch")
	var completed_writes: int = small_storage.jelly_writes
	check(complete.create_batch("complete-jelly", ["space"]) and complete.round_id == "next-jelly"
		and complete.entries.size() == 1 and complete.entries[0].theme == "spring"
		and complete.entries[0].opened and small_storage.jelly_writes == completed_writes,
		"Completed Jelly receipts acknowledge an old round without recreating its opened treasure")


func _make_jelly_room(storage: Storage):
	var room := Room.new()
	_attach_wallet(room, storage)
	room.storage_kind = "jelly"
	room.max_chests = 0
	room.allow_repeated_themes = true
	room.page_size = 3
	root.add_child(room)
	room.size = Vector2(880, 640)
	room.connect_storage(storage)
	room.set_process(false)
	return room


func _result_context_checks() -> void:
	var room = _make_jelly_room(Storage.new())
	check(room.configure("result-room", 1, "ocean", _manifest, false, 3), "Prepare a live tier-three result chest")
	room.set_result_context({"score": 420, "chest_tier": 3, "chest_count": 1})
	check(room._heading.text == "Round results" and room._result_score.text == "420"
		and room._progress.text == "Chest Lv. 3" and room._back.text == "Play again",
		"Result context presents the score, earned tier and replay action")
	var actions: Array[String] = []
	room.replay_requested.connect(func() -> void: actions.append("replay"))
	room.exit_requested.connect(func() -> void: actions.append("exit"))
	room._back.pressed.emit()
	check(actions == ["replay"] and not room._paused and room.has_pending(),
		"The result action requests replay without hiding, consuming or exiting the room itself")
	for dimensions in [Vector2i(320, 496), Vector2i(390, 772), Vector2i(568, 248), Vector2i(667, 248), Vector2i(1000, 700)]:
		root.size = dimensions
		room.size = Vector2(dimensions) / Style.ui_scale(room)
		room._layout()
		for frame in range(4):
			await process_frame
		var card: Dictionary = room._cards[0]
		check(room.get_global_rect().grow(1.0).encloses(room._back.get_global_rect())
			and not room._scroll.get_global_rect().intersects(room._back.get_global_rect()),
			"Result Play again remains reachable below the chest stage at %s" % dimensions)
		check(card.panel.get_global_rect().grow(1.0).encloses(card.art.get_global_rect())
			and card.panel.get_global_rect().grow(1.0).encloses(card.hint.get_global_rect()),
			"Result chest artwork and hold instruction remain inside their stage at %s" % dimensions)
		check(not room._heading.get_global_rect().intersects(room._result_score.get_global_rect())
			and not room._result_score.get_global_rect().intersects(room._progress.get_global_rect()),
			"Result score and explanatory labels remain separate at %s" % dimensions)
	_hold(room, 0, Feel.HOLD_SECONDS)
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	check(room.get_meta("coin_wallet").balance == 150 and room._cards[0].opened
		and room.get_meta("coin_releases")[0].animate,
		"The result chest retains the real hold-to-open performance and animated coin release")
	room.set_result_context({})
	check(room._heading.text == "Chest Lv. 3" and room._back.text == "Back" and not room._result_score.visible,
		"Clearing result context restores the existing treasure-room presentation")
	room._back.pressed.emit()
	check(actions == ["replay", "exit"] and room._paused, "Legacy Back still pauses and exits")
	room.queue_free()
	await process_frame


func _collect_all_checks() -> void:
	var storage := Storage.new()
	var room = _make_jelly_room(storage)
	check(room.configure("bulk-legacy", 5, "jungle", _manifest, false), "Prepare legacy treasure beyond the visible page")
	check(room.rewards.mark_opened("bulk-legacy", 1), "A previously consumed legacy chest needs no retroactive payout")
	check(room.configure("bulk-current", 1, "ocean", _manifest, false, 3)
		and room.rewards.entries.size() == 5 and room._cards.size() == 3,
		"Current results retain all unopened off-page legacy chests and the final upgraded chest")
	room.set_result_context({"score": 80, "chest_tier": 3, "chest_count": 1})
	var cues: Array[String] = []
	room.chest_audio_requested.connect(func(action: String, _theme: String, _amount: float) -> void: cues.append(action))
	_hold(room, 0, Feel.HOLD_SECONDS * 0.3)
	cues.clear()
	check(room.collect_all_coins() and not room.has_pending() and room.get_meta("coin_wallet").balance == 350,
		"Replay collects four retained ordinary chests plus the tier-three chest, including off-page entries")
	check(room.rewards.entries.all(func(entry: Dictionary) -> bool: return entry.opened)
		and storage.coin_writes == 5 and room.get_meta("coin_releases").all(func(event: Dictionary) -> bool: return not event.animate),
		"Bulk collection consumes each saved receipt once and reconciles without coin flights")
	check(cues.all(func(action: String) -> bool: return action == "stop")
		and room._active == -1 and not room._opening and not room._holding,
		"Replay cancels the partial hold without positive chest cues or late opening callbacks")
	var writes: int = storage.jelly_writes
	check(room.collect_all_coins() and storage.coin_writes == 5 and storage.jelly_writes == writes,
		"Repeated replay collection cannot add payouts or consumption writes")
	room.queue_free()
	await process_frame
	for committed in [false, true]:
		storage = Storage.new()
		room = _make_jelly_room(storage)
		check(room.configure("partial-%s" % committed, 1, "jungle", _manifest, false, 1), "Prepare a partially opening result chest")
		_hold(room, 0, Feel.HOLD_SECONDS)
		if committed:
			room._cards[0].art._advance_animation(Feel.UNLOCK_TIME + 0.01)
		check(room.collect_all_coins() and room.get_meta("coin_wallet").balance == 50
			and storage.coin_writes == 1 and room.rewards.entries[0].opened,
			"Replay collects exactly once before or after a chest's physical release")
		check(room.get_meta("coin_releases").all(func(event: Dictionary) -> bool: return not event.animate),
			"A partially opening chest finishes without a delayed animated deposit")
		room.queue_free()
		await process_frame


func _collect_failure_checks() -> void:
	for fail_consumption in [false, true]:
		var storage := Storage.new()
		var room = _make_jelly_room(storage)
		check(room.configure("bulk-retry-%s" % fail_consumption, 1, "autumn", _manifest, false, 2),
			"Prepare a replay collection retry fixture")
		room.set_result_context({"score": 60, "chest_tier": 2, "chest_count": 1})
		storage.coin_writable = fail_consumption
		storage.writable = not fail_consumption
		check(not room.collect_all_coins() and room._save_failed and room._collect_pending
			and room._retry.visible and not room.rewards.entries[0].opened,
			"A failed wallet or consumption write leaves replay collection visible and retryable")
		check(room.get_meta("coin_wallet").balance == (100 if fail_consumption else 0),
			"A partial replay save preserves exactly the durable side of the transaction")
		storage.coin_writable = true
		storage.writable = true
		room.retry_save()
		check(not room._save_failed and not room._collect_pending and not room.has_pending()
			and room.get_meta("coin_wallet").balance == 100 and storage.coin_writes == 1,
			"Retry save finishes the original bulk collection without duplicate coins")
		check(room.get_meta("coin_releases").all(func(event: Dictionary) -> bool: return not event.animate),
			"Successful bulk retry reconciles silently instead of opening a chest animation")
		room.queue_free()
		await process_frame
	var storage := Storage.new()
	var room = _make_jelly_room(storage)
	check(room.configure("bulk-partial", 5, "jungle", _manifest, false), "Prepare failure after some off-page rewards can be collected")
	storage.coin_write_limit = 2
	check(not room.collect_all_coins() and room.get_meta("coin_wallet").balance == 100
		and room.rewards.entries.filter(func(entry: Dictionary) -> bool: return entry.opened).size() == 2,
		"A later failed payout retains earlier durable collections and the unopened remainder")
	storage.coin_write_limit = -1
	room.retry_save()
	check(not room.has_pending() and room.get_meta("coin_wallet").balance == 250 and storage.coin_writes == 5,
		"Retry continues from saved entry identities across pages without paying earlier entries again")
	room.queue_free()
	await process_frame
	storage = Storage.new()
	room = _make_jelly_room(storage)
	storage.writable = false
	check(not room.configure("bulk-unsaved-batch", 1, "ocean", _manifest, false, 3), "An unsaved result batch remains a draft")
	check(not room.collect_all_coins() and room.get_meta("coin_wallet").balance == 0,
		"Replay cannot discard a result whose original treasure batch is still unsaved")
	storage.writable = true
	room.retry_save()
	check(not room.has_pending() and room.get_meta("coin_wallet").balance == 150 and storage.coin_writes == 1,
		"Retry persists the draft batch before silently crediting and consuming its final chest")
	room.queue_free()
	await process_frame


func _jelly_tier_checks() -> void:
	var storage := Storage.new()
	var state = _jelly_state(storage)
	check(state.create_batch("legacy-jelly", ["ocean", "space"]), "An existing Jelly save can contain several unopened chests")
	var legacy_text: String = storage.jelly_text
	check(state.load_state() and storage.jelly_text == legacy_text and not state.entries[0].has("tier"),
		"Loading a legacy chest does not relabel, upgrade or rewrite it")
	check(state.create_batch("final-tier", ["autumn"], [2]) and state.entries.size() == 3
		and state.entries[0].theme == "ocean" and state.entries[1].theme == "space"
		and not state.entries[0].has("tier") and state.entries[2].tier == 2,
		"A round appends only its final upgraded chest while keeping all legacy loot intact")
	var restored = _jelly_state(storage)
	check(restored.load_state() and restored.entries[2].tier == 2 and restored.entries[2].theme == "autumn",
		"Reload preserves both the final tier and its corresponding chest artwork")
	var writes: int = storage.jelly_writes
	check(restored.create_batch("final-tier", ["winter"], [99]) and storage.jelly_writes == writes
		and restored.entries[2].tier == 2 and restored.entries[2].theme == "autumn",
		"Repeated completion cannot add an intermediate chest or alter the saved final tier")
	check(restored.mark_opened("final-tier", 2) and restored.entries[2].tier == 2,
		"Opening the final chest retains its tier alongside its durable receipt")
	check(restored.create_batch("later-tier", ["winter"], [300]) and restored.entries.size() == 3
		and restored.entries[2].tier == 300 and not restored.entries[2].opened,
		"Higher numeric tiers are preserved without capping them to the available art variants")
	writes = storage.jelly_writes
	check(restored.create_batch("final-tier", ["spring"], [1]) and restored.entries[2].tier == 300
		and storage.jelly_writes == writes, "An older round callback cannot recreate an opened upgraded chest")
	check(not restored.create_batch("bad-count", ["spring"], [1, 2])
		and not restored.create_batch("bad-tier", ["spring"], [-1]) and storage.jelly_writes == writes,
		"Invalid tier metadata cannot replace valid saved treasure")
	var pop := State.new("user://unused-pop-tier.cfg", storage)
	check(pop.create_batch("pop-tier", ["spring"], [1]) and pop.entries[0].tier == 1,
		"Voice Pop supports the same final chest tier metadata as Jelly")
	var malformed := ConfigFile.new()
	malformed.parse(storage.jelly_text)
	malformed.set_value("treasure", "entries", [{"theme": "spring", "opened": false, "tier": -1}])
	storage.jelly_text = malformed.encode_to_text()
	check(not restored.load_state(), "Corrupt persisted tiers fail safely instead of silently losing a chest")


func _pop_fragment_state_checks() -> void:
	var storage := Storage.new()
	var legacy := State.new("user://unused-pop-fragments.cfg", storage)
	check(legacy.create_batch("legacy-pop", ["spring", "summer", "autumn"]),
		"Prepare an existing three-chest Voice Pop save without upgrade metadata")
	check(legacy.mark_opened("legacy-pop", 1), "An old Voice Pop chest may already be opened")
	var state := State.new("user://unused-pop-fragments.cfg", storage)
	state.max_chests = 0
	state.allow_repeated_themes = true
	var legacy_text: String = storage.text
	check(state.load_state() and state.entries.size() == 3 and storage.text == legacy_text
		and not state.entries[0].has("tier") and state.entries[1].opened,
		"The fragment inventory restores legacy chest styles and opened flags without rewriting them")
	check(state.create_batch("fragment-round", ["autumn"], [2]) and state.entries.size() == 3
		and state.entries[0].theme == "spring" and state.entries[1].theme == "autumn"
		and not state.entries[0].has("tier") and not state.entries[1].has("tier")
		and state.entries[2].theme == "autumn" and state.entries[2].tier == 2
		and state.entries.all(func(entry: Dictionary) -> bool: return not entry.opened),
		"A completed fragment round appends only its final chest while preserving all old unopened rewards")
	var writes: int = storage.writes
	check(state.create_batch("fragment-round", ["winter"], [90]) and state.entries.size() == 3
		and state.entries[2].tier == 2 and storage.writes == writes,
		"Repeated round completion cannot append or reroll the final chest")
	check(state.create_batch("legacy-pop", ["space"], [3]) and storage.writes == writes
		and state.round_id == "fragment-round", "A retired legacy round receipt cannot restore consumed or carried treasure twice")
	check(not state.mark_opened("legacy-pop", 0) and storage.writes == writes,
		"An old chest callback cannot consume an index after pending treasure is carried forward")
	var before: String = storage.text
	storage.writable = false
	check(not state.create_batch("failed-round", ["jungle"], [1]) and storage.text == before
		and state.round_id == "fragment-round" and state.entries.size() == 3,
		"A failed Voice Pop append preserves all previous treasure and its current batch identity")
	storage.writable = true
	check(state.create_batch("failed-round", ["jungle"], [1]) and state.entries.size() == 4
		and state.entries[3].tier == 1,
		"A retried new round safely exceeds the old three-chest inventory limit")
	var reloaded := State.new("user://unused-pop-fragments.cfg", storage)
	reloaded.max_chests = 0
	reloaded.allow_repeated_themes = true
	check(reloaded.load_state() and reloaded.entries == state.entries,
		"Reload preserves pending legacy and upgraded Voice Pop treasure together")
	for index in range(reloaded.entries.size()):
		check(reloaded.mark_opened("failed-round", index), "Every carried Voice Pop chest opens at its actual saved index")
	writes = storage.writes
	check(reloaded.mark_opened("failed-round", 3) and reloaded.last_open_was_duplicate
		and storage.writes == writes, "Repeated opening cannot save or award the final chest twice")
	check(reloaded.create_batch("later-round", ["winter"], [300]) and reloaded.entries.size() == 1
		and reloaded.entries[0].tier == 300, "Uncapped numeric tiers persist after previous treasure is fully opened")
	writes = storage.writes
	check(reloaded.create_batch("fragment-round", ["autumn"], [2]) and storage.writes == writes
		and reloaded.entries.size() == 1 and reloaded.entries[0].tier == 300,
		"An old completion callback acknowledges its receipt without recreating an intermediate reward")
	check(not reloaded.create_batch("bad-tiers", ["jungle"], [1, 2])
		and not reloaded.create_batch("negative-tier", ["jungle"], [-1]) and storage.writes == writes,
		"Invalid Voice Pop tier metadata cannot overwrite saved treasure")
	var malformed := ConfigFile.new()
	malformed.parse(storage.text)
	malformed.set_value("treasure", "entries", [{"theme": "jungle", "opened": false, "tier": 0}])
	storage.text = malformed.encode_to_text()
	check(not reloaded.load_state(), "An invalid persisted Voice Pop tier is rejected without silently replacing rewards")
	check(storage.jelly_text == null and storage.jelly_writes == 0,
		"Voice Pop fragment inventory never reads or overwrites Jelly treasure storage")
	var strict_storage := Storage.new()
	var strict := State.new("user://unused-pop-strict.cfg", strict_storage)
	strict.max_chests = 0
	check(strict.create_batch("strict-first", ["spring"], [1]), "Prepare an uncapped inventory with distinct style validation")
	var strict_before: String = strict_storage.text
	check(not strict.create_batch("strict-duplicate", ["spring"], [2]) and strict_storage.text == strict_before
		and strict.load_state(), "An unsupported repeated style cannot create a save that fails its own validation")
	var capped = _jelly_state(Storage.new())
	capped.max_chests = 1
	check(capped.create_batch("capped-first", ["spring"], [1])
		and not capped.create_batch("capped-second", ["autumn"], [2]) and capped.load_state(),
		"Accumulating inventories validate the combined total before writing a capped save")


func _jelly_tier_room_checks() -> void:
	var storage := Storage.new()
	var room = _make_jelly_room(storage)
	check(room.configure("single-upgraded", 1, "ocean", _manifest, true, 3),
		"A final upgraded Jelly chest configures through the real reward room")
	check(room.snapshot().chest_count == 1 and room.snapshot().chests[0].tier == 3
		and room.snapshot().chests[0].theme == "ocean" and room.snapshot().heading == "Chest Lv. 3"
		and room._cards[0].button.accessibility_name.begins_with("Tier 3."),
		"The reward room displays and announces one final chest at its earned level")
	var writes: int = storage.jelly_writes
	check(room.configure("single-upgraded", 1, "winter", _manifest, true, 6)
		and room.snapshot().chests[0].tier == 3 and room.snapshot().chests[0].theme == "ocean"
		and storage.jelly_writes == writes, "Repeated room configuration preserves the original final reward")
	room.queue_free()
	await process_frame
	room = _make_jelly_room(storage)
	check(room.configure_saved(_manifest, true) and room.snapshot().chest_count == 1
		and room.snapshot().chests[0].tier == 3 and room.snapshot().heading == "Chest Lv. 3",
		"Restoring the opening page shows the same upgraded chest after reload")
	_hold(room, 0, Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 1 and not room.has_pending() and room.rewards.entries[0].tier == 3,
		"Holding opens precisely that saved final chest once")
	room.queue_free()
	await process_frame
	storage = Storage.new()
	room = _make_jelly_room(storage)
	storage.writable = false
	check(not room.configure("retry-upgraded", 1, "autumn", _manifest, true, 2)
		and room.snapshot().chests[0].tier == 2, "A failed write keeps the final tier visible and retryable")
	storage.writable = true
	room.retry_save()
	check(not room.snapshot().save_failed and room.rewards.entries.size() == 1
		and room.rewards.entries[0].tier == 2 and room.rewards.entries[0].theme == "autumn",
		"Retry durably writes the final tier without generating intermediate rewards")
	room.queue_free()
	await process_frame


func _jelly_pagination_checks() -> void:
	var storage := Storage.new()
	var room = _make_jelly_room(storage)
	check(room.configure("jelly-pages", 8, "ocean", _manifest, true), "Configure all eight earned Jelly chests")
	var state: Dictionary = room.snapshot()
	check(state.chest_count == 8 and state.opened_count == 0 and state.visible_chest_count == 3
		and state.page == 0 and state.page_count == 3, "Pagination retains complete reward totals while constructing only three live chests")
	check(state.heading == "Your treasure" and state.progress_text == "0 / 8 opened",
		"Treasure progress describes the whole reward batch instead of the current page")
	check(room._cards.all(func(card: Dictionary) -> bool: return card.theme == "ocean")
		and room._cards[0].entry_index == 0 and room._cards[2].entry_index == 2,
		"The first Jelly page has consistent theme and stable global reward indexes")
	check(room.navigation_controls().has(room._next_page) and not room.navigation_controls().has(room._previous_page),
		"Available reward pages participate in controller and keyboard navigation")
	room.begin_hold(room._cards[0].button)
	check(not room.set_page(1) and room.snapshot().page == 0, "Paging cannot interrupt a held chest")
	room.end_hold()
	check(room.set_page(2) and room._cards.size() == 2 and room._cards[0].entry_index == 6,
		"The final page constructs only the two remaining chests")
	_hold(room, 0, Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 1 and room.rewards.entries[6].opened
		and not room.rewards.entries[0].opened, "A paged chest writes its global index rather than its local card index")
	check(room.snapshot().progress_text == "1 / 8 opened",
		"Opening a later-page chest updates the shared progress label")
	check(room.set_page(0) and room.snapshot().opened_count == 1 and room._cards.size() == 3,
		"Returning to an earlier page keeps whole-batch opened totals")
	for index in range(3):
		_hold(room, index, Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 4 and room.snapshot().pending,
		"Finishing one page leaves all other earned rewards pending")
	check(room.set_page(1), "The next unopened page remains reachable")
	for width in [320, 390, 880]:
		room.size = Vector2(width, 640)
		room._layout()
		for frame in range(4):
			await process_frame
		for control in [room._previous_page, room._next_page, room._page_label, room._back]:
			check(room.get_global_rect().grow(1.0).encloses(control.get_global_rect()),
				"Reward page controls fit the room at width %d" % width)
		check(not room._previous_page.get_global_rect().intersects(room._page_label.get_global_rect())
			and not room._next_page.get_global_rect().intersects(room._page_label.get_global_rect()),
			"Reward page controls do not overlap at width %d: previous=%s, label=%s, next=%s" % [
				width, room._previous_page.get_global_rect(), room._page_label.get_global_rect(), room._next_page.get_global_rect()])
	room.pause()
	check(not room.set_page(2), "A paused or covered treasure room cannot change pages")
	room.resume()
	room.queue_free()
	await process_frame
	var restored = _make_jelly_room(storage)
	check(restored.configure_saved(_manifest, true) and restored.snapshot().chest_count == 8
		and restored.snapshot().opened_count == 4 and restored.snapshot().page == 1,
		"Reload returns directly to the first page with unopened treasure")
	for index in range(3):
		_hold(restored, index, Feel.HOLD_SECONDS)
	check(restored.set_page(2) and restored._cards[0].opened, "The last page retains an earlier opened chest")
	_hold(restored, 1, Feel.HOLD_SECONDS)
	check(restored.snapshot().opened_count == 8 and not restored.has_pending()
		and storage.jelly_writes == 9 and storage.writes == 0,
		"All eight paged rewards open once without touching Pop storage")
	restored.queue_free()
	await process_frame


func _jelly_save_retry_checks() -> void:
	var storage := Storage.new()
	var room = _make_jelly_room(storage)
	storage.writable = false
	check(not room.configure("jelly-retry", 11, "space", _manifest, true)
		and room.snapshot().chest_count == 11 and room.snapshot().save_failed,
		"A failed batch save retains every earned Jelly chest in its retry draft")
	check(not room.set_page(1), "Unsaved treasure cannot page into an unavailable reward")
	storage.writable = true
	room.retry_save()
	check(not room.snapshot().save_failed and room.snapshot().chest_count == 11
		and room.rewards.entries.size() == 11, "Retry durably writes the complete uncapped reward draft")
	check(room.set_page(3) and room._cards.size() == 2, "A retried long batch retains its last page")
	storage.writable = false
	_hold(room, 1, Feel.HOLD_SECONDS)
	check(room.snapshot().save_failed and not room.rewards.entries[10].opened,
		"An opened final-page chest keeps its failed receipt pending")
	check(not room.set_page(0), "A failed chest receipt keeps its exact card available for retry")
	storage.writable = true
	room.retry_save()
	check(not room.snapshot().save_failed and room.rewards.entries[10].opened
		and room.snapshot().opened_count == 1 and storage.jelly_writes == 2,
		"Retry writes the final-page receipt once at its global index")
	room.retry_save()
	check(storage.jelly_writes == 2 and room.snapshot().opened_count == 1,
		"Repeated save retry cannot duplicate a Jelly chest")
	room.queue_free()
	await process_frame


func _jelly_accumulation_checks() -> void:
	var storage := Storage.new()
	var room = _make_jelly_room(storage)
	check(room.configure("kept-round", 3, "ocean", _manifest, true),
		"Prepare pending treasure before a direct replay earns another round")
	_hold(room, 0, Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 1, "One earlier chest is already opened before replay")
	var durable_before: String = storage.jelly_text
	storage.writable = false
	check(not room.configure("new-round", 2, "space", _manifest, true)
		and room.snapshot().save_failed and room.snapshot().chest_count == 2
		and room._draft_themes == ["space", "space"] and storage.jelly_text == durable_before,
		"A failed replay reward append retains its exact new draft without disturbing older treasure")
	storage.writable = true
	var external = _jelly_state(storage)
	check(external.create_batch("foreign-round", ["spring"]) and external.entries.size() == 3,
		"Another room can append treasure while the local reward draft waits for a retry")
	room.retry_save()
	check(not room.snapshot().save_failed and room._configured_id == "new-round"
		and room.snapshot().chest_count == 5 and room.snapshot().opened_count == 0
		and room._draft_themes == ["ocean", "ocean", "spring", "space", "space"],
		"Retry combines foreign and local rewards with each remaining chest's original theme")
	check(external.load_state() and external.round_id == "new-round" and external.entries.size() == 5
		and external._receipts.has("kept-round") and external._receipts.has("foreign-round"),
		"The combined reward and both earlier awarded round identities are durable")
	var writes: int = storage.jelly_writes
	room.retry_save()
	check(room.configure("kept-round", 3, "winter", _manifest, true)
		and room._configured_id == "new-round" and room.snapshot().chest_count == 5
		and room._draft_themes == ["ocean", "ocean", "spring", "space", "space"]
		and storage.jelly_writes == writes,
		"Repeated retry and a superseded round callback adopt the saved batch without duplicate rewards")
	var other_room = _make_jelly_room(storage)
	check(other_room.configure_saved(_manifest, true), "A second room restores the same pending treasure")
	_hold(other_room, 0, Feel.HOLD_SECONDS)
	check(other_room.configure("later-round", 1, "candy", _manifest, true)
		and other_room.snapshot().chest_count == 5,
		"A second room opens one chest and appends a reward, changing the saved index mapping")
	writes = storage.jelly_writes
	room.set_reduced_motion(false)
	_hold(room, 0, Feel.HOLD_SECONDS)
	room._cards[0].art._advance_animation(Feel.RELEASE_TIME + 0.01)
	check(room.snapshot().save_failed and room._unsaved_index == 0
		and storage.jelly_writes == writes and external.load_state()
		and external.entries.all(func(entry: Dictionary) -> bool: return not entry.opened),
		"A stale room cannot mark a remapped chest opened when another round has been appended")
	check(room._opening and room._cards[0].art.opening_committed()
		and room._cards[0].art.mode != "opened",
		"Stale-room recovery is exercised after release while the normal opening animation is still active")
	room.retry_save()
	check(not room.snapshot().save_failed and room._unsaved_index == -1
		and room._configured_id == "later-round" and room.snapshot().chest_count == 5
		and room.snapshot().opened_count == 0 and room._cards[0].art.mode == "closed"
		and not room._opening and room._active == -1
		and room._draft_themes == ["ocean", "spring", "space", "space", "candy"]
		and storage.jelly_writes == writes,
		"Retry refreshes a stale room without consuming a new chest or reusing the old index")
	_hold(room, 0, Feel.HOLD_SECONDS)
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	check(room.snapshot().opened_count == 1 and storage.jelly_writes == writes + 1
		and external.load_state() and external.entries[0].opened and not external.entries[1].opened,
		"A fresh hold after stale-room recovery opens exactly the newly displayed chest")
	room.queue_free()
	other_room.queue_free()
	await process_frame


func _state_checks() -> void:
	var storage := Storage.new()
	var state := State.new("user://unused-pop-test.cfg", storage)
	check(state.load_state() and not state.has_pending(), "Missing storage begins without invented treasure")
	check(not state.create_batch("zero", []), "Zero chances cannot create a chest")
	check(not state.create_batch("duplicate", ["spring", "spring"]), "Duplicate styles cannot form a batch")
	check(state.create_batch("one", ["spring", "summer", "winter"]), "Create a durable three-chest batch")
	check(state.entries.size() == 3 and state.has_pending(), "All three earned chances begin unopened")
	var initial_writes: int = storage.writes
	check(state.create_batch("one", ["autumn"]) and state.entries.size() == 3 and storage.writes == initial_writes,
		"Reconfiguring the same round cannot reroll or resize its chest set")
	check(not state.create_batch("two", ["space"]), "An unfinished batch cannot be overwritten")
	check(state.mark_opened("one", 1), "Opening writes the selected chest")
	check(state.mark_opened("one", 1) and storage.writes == initial_writes + 1,
		"Duplicate completion callbacks never write or award twice")
	check(state.last_open_was_duplicate, "A duplicate durable receipt is reported to suppress repeated reward presentations")
	check(not state.mark_opened("other", 0), "A stale round cannot consume the current reward")
	storage.writable = false
	check(not state.mark_opened("one", 0) and not state.entries[0].opened,
		"A failed save leaves durable reward state retryable")
	storage.writable = true
	check(state.mark_opened("one", 0) and state.mark_opened("one", 2) and not state.has_pending(),
		"Opening every chest records the completed batch")
	check(state.create_batch("two", ["space"]), "A completed batch permits another played round")
	check(state.mark_opened("two", 0), "Finish the subsequent batch")
	check(not state.create_batch("one", ["spring"]), "A completed old round receipt prevents replay")
	var reloaded := State.new("user://unused-pop-test.cfg", storage)
	check(reloaded.load_state() and reloaded.round_id == "two" and reloaded.entries[0].opened,
		"Reload preserves both chest selection and opened state")
	storage.readable = false
	check(not reloaded.load_state() and not reloaded.ready, "Unavailable reads do not fabricate a fresh save")
	storage.readable = true
	storage.text = "[treasure]\nversion=1\nround_id=\"bad\"\nentries=[{\"theme\":\"spring\",\"opened\":\"yes\"}]\nreceipts=[]\n"
	check(not reloaded.load_state(), "Malformed opened flags cannot overwrite durable state")
	for theme_id in Data.THEMES:
		var selected: Array[String] = Room._choose_themes("style-check", 3, str(theme_id))
		check(selected.size() == 3 and selected[0] == theme_id, "The active theme receives the first earned chest")
		var styles: Array[String] = []
		for selected_id in selected:
			styles.append(str(Data.THEMES[selected_id].chest))
		check(styles[0] != styles[1] and styles[0] != styles[2] and styles[1] != styles[2],
			"Each simultaneous chest has different physical artwork")
		check(selected == Room._choose_themes("style-check", 3, str(theme_id)),
			"A saved round always selects the same chest styles")


func _make_room(storage: Storage):
	var room := Room.new()
	_attach_wallet(room, storage)
	root.add_child(room)
	room.size = Vector2(880, 640)
	room.connect_storage(storage)
	room.set_process(false)
	return room


func _attach_wallet(room, storage: Storage) -> void:
	var wallet := Wallet.new("user://unused-room-wallet.cfg", storage)
	check(wallet.load_state(), "Room fixtures load an isolated durable coin wallet")
	# Match GameUI's retry boundary while keeping this room fixture isolated.
	room.credit_coins = func(id: String, tier: int) -> Dictionary:
		if not wallet.ready or not wallet.error.is_empty():
			wallet.load_state()
		return wallet.credit(id, tier)
	room.set_meta("coin_wallet", wallet)
	var releases: Array[Dictionary] = []
	room.set_meta("coin_releases", releases)
	room.coins_released.connect(func(id: String, reward: Dictionary, origin: Vector2, animate: bool) -> void:
		releases.append({"id": id, "reward": reward.duplicate(true), "origin": origin, "animate": animate}))


func _hold(room, index: int, seconds: float) -> void:
	room.begin_hold(room._cards[index].button)
	room.advance_hold(seconds)


func _card_geometry(room, card: Dictionary) -> String:
	var scale: float = Style.ui_scale(room)
	return " (room_px=%s, art_px=%s, card=%s, hint=%s, caption=%s, content=%s, viewport=%s, scale=%s)" % [
		room.size * scale, card.art.size * scale, card.panel.get_rect(), card.hint.get_global_rect(),
		card.caption.get_global_rect(), room._content.size, room._scroll.get_global_rect(), scale]


func _check_treasure_labels(room, context: String) -> void:
	var scale: float = Style.ui_scale(room)
	for label in [room._heading, room._progress]:
		var line_height: float = label.get_line_height()
		var detail: String = " (text='%s', size=%s, line_height=%s, visible_lines=%s, scale=%s)" % [
			label.text, label.size, line_height, label.get_visible_line_count(), scale]
		check(label.is_visible_in_tree() and not label.text.is_empty() and not label.clip_text,
			"Treasure heading and progress remain visible without text clipping after " + context + detail)
		check(label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.get_line_count() == 1
			and label.get_visible_line_count() == 1
			and label.size.y * scale + PIXEL_TOLERANCE >= line_height * scale,
			"Treasure label boxes fit their actual scaled font line after " + context + detail)
		if room._scroll.scroll_vertical == 0:
			check(room._scroll.get_global_rect().grow(PIXEL_TOLERANCE / scale).encloses(label.get_global_rect()),
				"Treasure labels begin inside the visible scroll area after " + context + detail)


func _room_checks() -> void:
	var storage := Storage.new()
	var room = _make_room(storage)
	check(room.configure("room-one", 3, "spring", _manifest, false), "Configure the reusable three-chest room")
	var reward_audio: Array[String] = []
	room.chest_audio_requested.connect(func(action: String, theme_id: String, _progress: float) -> void:
		if action == "reward":
			reward_audio.append(theme_id))
	check(room.snapshot().chest_count == 3 and room.navigation_controls().size() == 4,
		"All three chests and the exit action appear simultaneously")
	for width in [880, 480, 390]:
		room.size = Vector2(width, 640)
		room._layout()
		for frame in range(4):
			await process_frame
		for index in range(3):
			var card: Dictionary = room._cards[index]
			var button: Control = room._cards[index].button
			check(button.size.x * Style.ui_scale(room) >= 44 - PIXEL_TOLERANCE
				and button.size.y * Style.ui_scale(room) >= 44 - PIXEL_TOLERANCE,
				"Every desktop and portrait chest has a full touch target")
			check(Rect2(Vector2.ZERO, room._content.size).grow(PIXEL_TOLERANCE / Style.ui_scale(room)).encloses(card.panel.get_rect()),
				"All earned chests belong to the same scrollable treasure stage: room=%s, viewport=%s, content=%s, card=%s, scale=%s" % [
					room.size, room._scroll.size, room._content.size, card.panel.get_rect(), Style.ui_scale(room)])
			check(card.art.size.x * Style.ui_scale(room) >= 180 - PIXEL_TOLERANCE
				and card.art.size.x * Style.ui_scale(room) <= 361
				and card.art.size.y * Style.ui_scale(room) >= 220 - PIXEL_TOLERANCE
				and card.art.size.y * Style.ui_scale(room) <= 301,
				"A reward batch keeps each chest readable without turning it into a full-page card" + _card_geometry(room, card))
			check(button.tooltip_text.is_empty() and not button.accessibility_name.is_empty(),
				"Chest instructions remain accessible without requiring a hover tooltip")
			check(card.has("caption") and card.has("hint") and card.caption.text == "Hold to open"
				and card.caption.is_visible_in_tree() and card.hint.is_visible_in_tree(),
				"Every unopened chest visibly explains the hold interaction")
			check(card.hint.get_global_rect().grow(1.0).encloses(card.caption.get_global_rect())
				and not card.art.get_global_rect().intersects(card.hint.get_global_rect()),
				"The hold instruction fits its compact badge below the chest artwork" + _card_geometry(room, card))
		if width * Style.ui_scale(room) < 620.0:
			check(room.snapshot().scroll_max > 0,
				"A phone can scroll the reward batch without compressing its chest artwork")
		check(room._back.size.x * Style.ui_scale(room) <= 113
			and room._back.size.y * Style.ui_scale(room) >= 44 - PIXEL_TOLERANCE,
			"Back remains a compact, touch-sized secondary action (size_px=%s)" % [room._back.size * Style.ui_scale(room)])
	room.size = Vector2(820, 250)
	room._layout()
	for frame in range(4):
		await process_frame
	for card in room._cards:
		check(card.art.size.x * Style.ui_scale(room) >= 180 - PIXEL_TOLERANCE
			and card.art.size.y * Style.ui_scale(room) >= 128 - PIXEL_TOLERANCE,
			"A short landscape room keeps recognisable chest artwork with room for its action" + _card_geometry(room, card))
		check(card.button.size.y * Style.ui_scale(room) >= 44 - PIXEL_TOLERANCE,
			"Landscape rewards preserve the minimum touch target")
	room.size = Vector2(640, 230) / Style.ui_scale(room)
	room._layout()
	for frame in range(4):
		await process_frame
	for index in range(room._cards.size()):
		var card: Dictionary = room._cards[index]
		check(card.button.size.y * Style.ui_scale(room) >= 44 - PIXEL_TOLERANCE,
			"Narrow landscape rewards preserve the minimum touch target")
		for other_index in range(index + 1, room._cards.size()):
			check(not card.button.get_global_rect().intersects(room._cards[other_index].button.get_global_rect()),
				"Scrollable landscape chest touch targets remain separate")
	room.size = Vector2(390, 640)
	room._layout()
	_hold(room, 0, 0.4)
	check(room._cards[0].caption.text != "Hold to open"
		and room._cards[0].button.accessibility_name.contains("Keep holding"),
		"A held chest updates its visible hint and accessible instructions together")
	room.begin_hold(room._cards[1].button)
	check(room.snapshot().active == 0 and room._cards[1].art.hold_progress == 0.0,
		"A second finger cannot begin another chest while one is held")
	room.end_hold()
	check(room.snapshot().active == -1 and room._cards[0].art.mode == "closed" and storage.writes == 1,
		"Releasing a short hold leaves its chance unspent")
	check(room._cards[0].caption.text == "Hold to open",
		"Canceling a short hold restores the visible instruction")
	_hold(room, 0, Feel.HOLD_SECONDS)
	room._cards[0].art._advance_animation(Feel.ANTICIPATION_TIME)
	room.end_hold()
	check(not room.snapshot().opening and not room._cards[0].opened and room._cards[0].art.mode == "closed",
		"Releasing during buildup cancels before mechanical release")
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	room._finished(0)
	check(reward_audio.is_empty() and storage.writes == 1, "Cancelled and stale callbacks cannot reveal a reward")
	_hold(room, 0, Feel.HOLD_SECONDS)
	room._cards[0].art._advance_animation(Feel.RELEASE_TIME + 0.01)
	check(room.snapshot().opened_count == 1 and storage.writes == 2,
		"Mechanical release persists exactly one opened chest immediately")
	room.end_hold()
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	room._finished(0)
	check(reward_audio.size() == 1 and storage.writes == 2,
		"Letting go after release completes one coin reward without duplicating the save")
	check(room._cards[0].caption.text.to_lower().contains("opened")
		and room._cards[0].button.accessibility_name.contains("Opened"),
		"A completed chest visibly reports its opened state without inviting another hold")
	check(room.get_meta("coin_wallet").balance == 50 and room.get_meta("coin_releases").size() == 1
		and room.get_meta("coin_releases")[0].reward.amount == 50 and room.get_meta("coin_releases")[0].animate
		and not room._cards[0].art.hold_effect_snapshot().surprise.active,
		"The room emits one 50-coin flight from its completed chest after durable credit")
	check(room.configure("room-one", 3, "space", _manifest, false) and room.snapshot().opened_count == 1,
		"Reentering the same round preserves opened chests")
	_hold(room, 1, Feel.HOLD_SECONDS)
	room.pause()
	check(room._cards[1].art.mode == "closed" and not room._cards[1].opened,
		"Backgrounding an uncommitted opening returns the unspent chest")
	room.resume()
	_hold(room, 1, Feel.HOLD_SECONDS)
	room._cards[1].art._advance_animation(Feel.RELEASE_TIME + 0.01)
	room.pause()
	check(room._cards[1].art.mode == "opened" and room.snapshot().opened_count == 2 and reward_audio.size() == 1,
		"Backgrounding after release settles the saved chest silently")
	room.resume()
	check(reward_audio.size() == 1 and room.get_meta("coin_wallet").balance == 100
		and room.get_meta("coin_releases").size() == 2 and not room.get_meta("coin_releases")[1].animate,
		"Resuming does not replay the coins that were settled silently during backgrounding")
	room.set_reduced_motion(true)
	_hold(room, 2, Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 3 and not room.has_pending() and reward_audio.size() == 2,
		"Reduced motion keeps the hold confirmation and opens the final chest once")
	check(storage.writes == 4, "Three rewards require one batch write and one durable write per chest")
	check(storage.coin_writes == 3 and room.get_meta("coin_wallet").balance == 150
		and room.get_meta("coin_releases").size() == 3,
		"All three chests credit exactly one 50-coin receipt and one presentation event each")
	room.queue_free()
	await process_frame
	var restored = _make_room(storage)
	check(restored.configure_saved(_manifest, false) and restored.snapshot().opened_count == 3,
		"A fresh room restores every opened chest after a reload")
	check(not restored.has_pending() and restored.navigation_controls().size() == 1,
		"Restored opened chests cannot be activated again")
	check(restored.get_meta("coin_wallet").balance == 150 and restored.get_meta("coin_releases").is_empty()
		and storage.coin_writes == 3, "Restoring an opened room preserves coins without crediting or presenting them again")
	for card in restored._cards:
		check(card.art.mode == "opened" and card.art.hold_effect_snapshot().surprise.play_count == 0,
			"Restoring durable state never replays the chest animation or surprise")
	restored.queue_free()
	await process_frame


func _single_chest_layout_checks() -> void:
	var previous_size: Vector2i = root.size
	var room = _make_room(Storage.new())
	check(room.configure("single-chest-layout", 1, "spring", _manifest, false),
		"Prepare one chest for the compact treasure presentation")
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(320, 568), Vector2i(844, 390)]:
		root.size = dimensions
		await process_frame
		var scale: float = Style.ui_scale(room)
		room.size = Vector2(dimensions.x, dimensions.y - 92) / scale
		room._layout()
		for frame in range(5):
			await process_frame
		_check_treasure_labels(room, "single chest at %s" % dimensions)
		var card: Dictionary = room._cards[0]
		var viewport: Rect2 = room._scroll.get_global_rect()
		var maximum_width: float = 600 if dimensions.y < 430 and dimensions.x >= 620 else 480
		check(card.panel.size.x * scale <= maximum_width + PIXEL_TOLERANCE and card.art.size.y * scale <= 361,
			"One chest has a bounded display size at %s" % dimensions + _card_geometry(room, card))
		check(absf(card.panel.get_global_rect().get_center().x - viewport.get_center().x) <= 1.0,
			"One chest stays horizontally centered at %s" % dimensions)
		check(room.get_global_rect().grow(1.0).encloses(room._back.get_global_rect())
			and room._back.size.x * scale <= 113,
			"The compact Back action remains in reach at %s" % dimensions)
		check(card.hint.size.y * scale >= 44 - PIXEL_TOLERANCE
			and card.hint.get_global_rect().grow(1.0).encloses(card.caption.get_global_rect()),
			"The hold badge remains legible and touch-sized at %s" % dimensions + _card_geometry(room, card))
		card.button.grab_focus()
		await process_frame
		check(card.button.has_focus() and card.button.get_theme_stylebox("focus") is StyleBoxEmpty,
			"A focused chest keeps keyboard access without outlining its whole stage at %s" % dimensions)
		var focus_surface: StyleBoxFlat = card.hint.get_theme_stylebox("panel")
		check(focus_surface.border_color.a > 0.0 and focus_surface.border_width_top > 0,
			"Keyboard focus remains visibly indicated on the compact hold badge at %s (focused=%s, disabled=%s, border=%s, color=%s)" % [
				dimensions, card.button.has_focus(), card.button.disabled, focus_surface.border_width_top, focus_surface.border_color])
		if dimensions.y >= 568:
			check(viewport.grow(1.0).encloses(card.button.get_global_rect())
				and room.snapshot().scroll_max == 0,
				"A single chest and its instruction are immediately visible without scrolling at %s" % dimensions + _card_geometry(room, card))
	room.queue_free()
	await process_frame
	root.size = previous_size
	await process_frame


func _retained_rewards_checks() -> void:
	var storage := Storage.new()
	var room = _make_room(storage)
	check(room.configure("retained-rewards", 3, "ocean", _manifest, false),
		"Prepare three earned chests for independently saved coin rewards")
	var reward_audio: Array[String] = []
	room.chest_audio_requested.connect(func(action: String, theme_id: String, _progress: float) -> void:
		if action == "reward":
			reward_audio.append(theme_id))
	for index in range(3):
		if index == 2:
			room.set_reduced_motion(true)
		_hold(room, index, Feel.HOLD_SECONDS)
		room._cards[index].art._advance_animation(Feel.OPEN_SECONDS)
		room._cards[index].art._advance_animation(0.2)
		var releases: Array = room.get_meta("coin_releases")
		check(releases.size() == index + 1 and releases[index].reward.amount == 50
			and releases[index].id == room.rewards.entries[index].reward_id
			and room.get_meta("coin_wallet").balance == (index + 1) * 50,
			"Each completed chest emits its own durable 50-coin receipt once")
		var saved_events: Array = releases.duplicate(true)
		room.pause()
		room._cards[index].art._advance_animation(60.0)
		check(room.get_meta("coin_releases") == saved_events and room.get_meta("coin_wallet").balance == (index + 1) * 50,
			"Pausing retains saved coins without emitting another presentation event")
		room.resume()
		room._cards[index].art.set_process(false)
		room._cards[index].art._advance_animation(60.0)
	check(room.snapshot().opened_count == 3 and storage.writes == 4 and reward_audio.size() == 3,
		"Opening all three chests keeps one durable opening receipt and one success sound per chest")
	for index in range(3):
		var art = room._cards[index].art
		art._advance_animation(600.0)
		room._announce(index)
		room._finished(index)
		check(not art.hold_effect_snapshot().surprise.active and room.get_meta("coin_releases").size() == 3
			and room.get_meta("coin_wallet").balance == 150,
			"Later openings, long idle time and stale completion callbacks cannot replay earlier coin rewards")
	check(storage.writes == 4 and storage.coin_writes == 3 and reward_audio.size() == 3,
		"Repeated presentation cannot replay reward audio or save extra opening or coin receipts")
	room.hide()
	for card in room._cards:
		check(not card.art.hold_effect_snapshot().surprise.active,
			"Coin-only rewards leave no decorative gift on a hidden chest stage")
	room.show()
	room.resume()
	for index in range(3):
		room._announce(index)
		check(room.get_meta("coin_releases").size() == 3 and room.get_meta("coin_wallet").balance == 150
			and storage.coin_writes == 3,
			"Reentering an opened batch cannot replay or repay coins from earlier chest receipts")
	room.queue_free()
	await process_frame


func _failure_checks() -> void:
	var unreadable := Storage.new()
	unreadable.readable = false
	var unavailable = _make_room(unreadable)
	check(unavailable.has_pending() and not unavailable.configure_saved(_manifest, false),
		"Unavailable storage keeps the resume path visible instead of starting another round")
	unreadable.readable = true
	unavailable.retry_save()
	check(not unavailable.has_pending() and not unavailable.snapshot().save_failed,
		"Retrying an initially unavailable empty store allows gameplay again")
	unavailable.queue_free()
	await process_frame
	var storage := Storage.new()
	storage.writable = false
	var room = _make_room(storage)
	check(not room.configure("retry-round", 2, "summer", _manifest, false),
		"Initial storage failure remains visible to the integrating screen")
	check(room.snapshot().save_failed and room.snapshot().chest_count == 2 and room._retry.visible,
		"The initial failed save preserves its selected chest draft and offers retry")
	await _check_save_error_layout(room)
	room.begin_hold(room._cards[0].button)
	check(not room.snapshot().holding, "An unpersisted batch cannot consume a chance")
	storage.writable = true
	room.retry_save()
	check(not room.snapshot().save_failed and room.has_pending() and storage.writes == 1,
		"Retry saves the same earned batch without requiring another game")
	var rewards: Array[String] = []
	room.chest_audio_requested.connect(func(action: String, theme_id: String, _progress: float) -> void:
		if action == "reward":
			rewards.append(theme_id))
	storage.writable = false
	_hold(room, 0, Feel.HOLD_SECONDS)
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	check(room.snapshot().save_failed and room._cards[0].art.mode == "opened" and rewards.is_empty(),
		"Failed release persistence keeps the visible opening but withholds duplicate-prone reward feedback")
	storage.writable = true
	room.retry_save()
	room.retry_save()
	check(not room.snapshot().save_failed and room.snapshot().opened_count == 1 and rewards.size() == 1,
		"Retrying a released chest saves and celebrates exactly once")
	check(storage.writes == 2, "Repeated retry cannot write a second receipt for one opening")
	room.queue_free()
	await process_frame
	var conflict = _make_room(Storage.new())
	check(conflict.configure("waiting-treasure", 1, "spring", _manifest, false)
		and not conflict.configure("new-treasure", 1, "summer", _manifest, false)
		and conflict._retry.text == "Resume saved treasure",
		"A conflicting saved batch exposes the longer recovery action")
	await _check_save_error_layout(conflict)
	conflict.queue_free()
	await process_frame


func _check_save_error_layout(room) -> void:
	for width in [320, 390]:
		room.size = Vector2(width, 568) / Style.ui_scale(room)
		room._layout()
		for frame in range(4):
			await process_frame
		for control in [room._back, room._retry, room._notice]:
			check(room.get_global_rect().grow(1.0).encloses(control.get_global_rect()),
				"Save recovery controls fit a %dpx room with action '%s'" % [width, room._retry.text])
		check(not room._back.get_global_rect().intersects(room._retry.get_global_rect())
			and not room._notice.get_global_rect().intersects(room._back.get_global_rect())
			and not room._notice.get_global_rect().intersects(room._retry.get_global_rect()),
			"The save error and recovery actions remain separate at %dpx" % width)
		check(room._retry.size.x >= room._retry.get_combined_minimum_size().x,
			"The full recovery action label remains readable at %dpx" % width)


func _responsive_resize_checks() -> void:
	# Reuse the same stage across orientations so a previous desktop minimum
	# cannot force an oversized scroll viewport on the next phone layout.
	root.size = Vector2i(1366, 768)
	await process_frame
	var column := VBoxContainer.new()
	root.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := Control.new()
	column.add_child(header)
	var room := Room.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(room)
	var storage := Storage.new()
	_attach_wallet(room, storage)
	room.connect_storage(storage)
	check(room.configure("responsive-treasure", 3, "spring", _manifest, false),
		"Prepare one treasure stage for repeated desktop and phone resizing")
	room.set_process(false)
	var published: Array[Dictionary] = []
	room.changed.connect(func(value: Dictionary) -> void: published.append(value.duplicate(true)))
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(320, 568),
		Vector2i(667, 375), Vector2i(375, 667), Vector2i(1366, 768)]:
		published.clear()
		root.size = dimensions
		for frame in range(2):
			await process_frame
		header.custom_minimum_size.y = 72.0 / Style.ui_scale(room)
		for frame in range(6):
			await process_frame
		var context := "resizing the same stage to %s" % dimensions
		var room_global: Rect2 = room.get_global_rect()
		var window_rect: Rect2 = root.get_visible_rect()
		check(room_global.position.x >= window_rect.position.x - 1.0
			and room_global.end.x <= window_rect.end.x + 1.0,
			"The room itself follows the resized window width after " + context)
		var viewport: Rect2 = room._scroll.get_rect()
		check(viewport.position.x >= -1.0 and viewport.end.x <= room.size.x + 1.0,
			"The scroll viewport stays within the room after " + context)
		var viewport_global: Rect2 = room._scroll.get_global_rect()
		var content_global: Rect2 = room._content.get_global_rect()
		check(content_global.position.x >= viewport_global.position.x - 1.0
			and content_global.end.x <= viewport_global.end.x + 1.0
			and absf(content_global.size.x - viewport_global.size.x) <= 1.0,
			"Treasure content fills the current viewport without retaining a previous wide minimum after " + context)
		for card in room._cards:
			var card_global: Rect2 = card.panel.get_global_rect()
			check(card_global.position.x >= viewport_global.position.x - 1.0
				and card_global.end.x <= viewport_global.end.x + 1.0,
				"Every chest keeps its full width within the viewport after " + context)
			check(card.art.size.x * Style.ui_scale(room) <= 361,
				"Reward artwork stays at a considered size after " + context)
		_check_settled_layout(room, published, context)
	column.queue_free()
	await process_frame


func _deferred_layout_checks() -> void:
	# Keep the project's normal content scaling and reproduce the real VBox
	# lifecycle: configure while hidden at zero size, then show and settle.
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(667, 375)]:
		root.size = dimensions
		await process_frame
		var column := VBoxContainer.new()
		root.add_child(column)
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var header := Control.new()
		column.add_child(header)
		var room := Room.new()
		room.hide()
		room.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(room)
		header.custom_minimum_size.y = 72.0 / Style.ui_scale(room)
		var storage := Storage.new()
		_attach_wallet(room, storage)
		room.connect_storage(storage)
		room.size = Vector2.ZERO
		var published: Array[Dictionary] = []
		room.changed.connect(func(value: Dictionary) -> void: published.append(value.duplicate(true)))
		check(room.configure("hidden-layout-%d" % dimensions.x, 3, "spring", _manifest, false),
			"A hidden zero-sized reward room can prepare a durable batch")
		room.set_process(false)
		room.show()
		for frame in range(5):
			await process_frame
		_check_settled_layout(room, published, "show at %s" % dimensions)
		room.hide()
		header.custom_minimum_size.y += 12.0 / Style.ui_scale(room)
		await process_frame
		room.show()
		room.resume()
		for frame in range(5):
			await process_frame
		_check_settled_layout(room, published, "reentry at %s" % dimensions)
		column.queue_free()
		await process_frame


func _check_settled_layout(room, published: Array[Dictionary], context: String) -> void:
	check(not published.is_empty(), "The room publishes its final layout after " + context)
	if published.is_empty():
		return
	_check_treasure_labels(room, context)
	var current: Dictionary = published.back()
	check(Rect2(Vector2.ZERO, room.size).encloses(room._scroll.get_rect())
		and not room._scroll.get_rect().intersects(room._back.get_rect()),
		"The scrollable treasure stage fits above the fixed exit action after " + context)
	check(room._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
		and room._scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"Treasure scrolling keeps both scrollbars hidden after " + context)
	for index in range(room._cards.size()):
		var card: Dictionary = room._cards[index]
		var actual: Rect2 = card.button.get_global_rect()
		var recorded: Dictionary = current.chests[index].rect
		check(actual.is_equal_approx(Rect2(recorded.x, recorded.y, recorded.width, recorded.height)),
			"Published chest geometry matches its final container position after " + context)
		check(Rect2(Vector2.ZERO, card.panel.size).grow(PIXEL_TOLERANCE / Style.ui_scale(room)).encloses(card.art.get_rect())
			and card.panel.get_global_rect().grow(1.0).encloses(card.hint.get_global_rect()),
			"Chest artwork and its instruction remain inside their own card after " + context + _card_geometry(room, card))
		var minimum_art_height: float = 128 if room.size.y * Style.ui_scale(room) < 430 else 220
		check(card.art.size.x * Style.ui_scale(room) >= 180 - PIXEL_TOLERANCE
			and card.art.size.y * Style.ui_scale(room) >= minimum_art_height - PIXEL_TOLERANCE,
			"Settled treasure art keeps its readable physical size after " + context + _card_geometry(room, card))
		for other_index in range(index + 1, room._cards.size()):
			check(not actual.intersects(room._cards[other_index].button.get_global_rect()),
				"Settled chest controls never overlap after " + context)

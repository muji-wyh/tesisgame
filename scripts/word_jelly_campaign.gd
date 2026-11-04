extends RefCounted
## Scene transitions and saved settlement ownership, separate from board physics.

const Map = preload("res://scripts/word_jelly_map.gd")
const Store = preload("res://scripts/word_jelly_campaign_store.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Context = preload("res://scripts/learning_context.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const Upgrades = preload("res://scripts/word_jelly_upgrades.gd")
const Economy = preload("res://scripts/coin_economy.gd")
var map: Map
var upgrades: Upgrades
var store: Store
var starting: bool = false
var settling: bool = false
var return_home_after_settlement: bool = false
var error: String = ""
var pending_plan: Dictionary = {}
var request_context: Dictionary = {}
var context_key: String = ""
var active_context_key: String = ""
var selected_stage: int = 0
var challenge: bool = false
var _app
var _result_draft: Dictionary = {}
var _result_round: String = ""
var _settlement_elapsed: float = 0.0
var _bonus_presented: bool = false
var _buying_upgrade: bool = false
var _upgrade_error: String = ""
var _last_unlocked: int = 0
var _last_unlocked_kind: String = "jelly"
var _pending_challenge_record: int = 0
var _challenge_previous_best: int = 0
var _result_committed: bool = false
var _result_summary_presented: bool = false
var _result_returned: bool = false
var _result_retry: bool = false
var _result_upgrades: bool = false
var _result_context_key: String = ""
# Leaving the old session can synchronously publish its failure before the new request exists.
var requesting_preparation: bool = false


func configure(app, path: String, host: Object = null) -> void:
	_app = app
	store = Store.new(path, host)
	if not store.load_state():
		error = store.error
	map = Map.new()
	app.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.stage_selected.connect(request_stage)
	map.challenge_selected.connect(request_challenge)
	map.home_requested.connect(_home)
	map.retry_requested.connect(retry)
	map.upgrades_requested.connect(open_upgrades)
	map.changed.connect(_publish)
	if app.audio.has_signal("status_changed"):
		app.audio.connect("status_changed", func(_message: String) -> void: _sync_map_audio())
	upgrades = Upgrades.new()
	app.add_child(upgrades)
	upgrades.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrades.back_requested.connect(close_upgrades)
	upgrades.purchase_requested.connect(purchase_upgrade)
	upgrades.contribution_requested.connect(contribute_upgrade)
	upgrades.audio_requested.connect(_upgrade_audio)
	upgrades.charging_changed.connect(_upgrade_charging_changed)
	upgrades.retry_requested.connect(retry)
	upgrades.intro_accepted.connect(_accept_upgrade_intro)
	upgrades.intro_dismissed.connect(_dismiss_upgrade_intro)
	upgrades.changed.connect(_publish)


func is_open() -> bool:
	return is_instance_valid(map) and map.visible or is_instance_valid(upgrades) and upgrades.visible


func _publish() -> void:
	if _app._host != null and not _app._releasing_professional_views and is_instance_valid(_app._active_jelly()):
		_app._publish_jelly(_app._active_jelly().snapshot())


func set_active(active: bool) -> void:
	map.set_active(active and not upgrades.visible)
	_sync_map_audio()
	upgrades.set_active(active)


func _sync_map_audio() -> void:
	if is_instance_valid(map):
		map.set_audio_enabled(_app.audio.get("available") == true \
			and _app.audio.get("muted") != true and not _app._page_hidden)


func set_reduced_motion(value: bool) -> void:
	map.set_reduced_motion(value)
	upgrades.set_reduced_motion(value)


func allows_focus(control: Control) -> bool:
	return upgrades.is_ancestor_of(control) if upgrades.visible else map.is_ancestor_of(control)


func default_focus() -> Control:
	if upgrades.visible:
		return upgrades.default_focus()
	var controls: Array[Control] = map.navigation_controls()
	return controls.back() if not controls.is_empty() else map


func _preview_word() -> Dictionary:
	return {"id": "cat", "text": "cat", "image": "res://assets/images/ui/modes/cat.webp"}


func _upgrade_state() -> Dictionary:
	var state: Dictionary = store.upgrade_state() if store.ready else \
		upgrades._state.duplicate(true) if not upgrades._state.is_empty() else \
			{"level": 1, "auto_merge_level": 1, "funded": {"jelly": 0, "auto_merge": 0},
				"pending": {}, "intro": "unseen"}
	var pending: Dictionary = state.pending
	var storage_error: String = error
	if not _app.coin_wallet.ready or not _app.coin_wallet.error.is_empty():
		storage_error = _app.coin_wallet.error if not _app.coin_wallet.error.is_empty() \
			else "Load your saved coins before buying a Jelly upgrade."
	state["balance"] = _app.coin_wallet.balance
	state["paid"] = not pending.is_empty() and _app.coin_wallet.has_purchase(str(pending.id), _pending_upgrade_amount(pending))
	state["busy"] = _buying_upgrade
	state["error"] = _upgrade_error if not _upgrade_error.is_empty() else storage_error
	state["retry"] = not storage_error.is_empty() or not pending.is_empty()
	state["just_unlocked"] = _last_unlocked
	state["just_unlocked_kind"] = _last_unlocked_kind
	return state


func open_upgrades() -> void:
	if _app._page_hidden or starting or settling or _buying_upgrade or not map.visible \
		or upgrades.visible or not store.ready or not error.is_empty():
		return
	_upgrade_error = ""
	_last_unlocked = 0
	_show_upgrades()


func _show_upgrades() -> void:
	map.close()
	_app._on_input_canceled()
	_app.audio.stop_jelly_sounds()
	if not upgrades.present(_upgrade_state(), _preview_word(), _app.reduced_motion):
		_upgrade_failed("The Jelly ability preview could not load its existing artwork.")
		return
	_app._sync_jelly()
	_app._refresh()
	_publish()


func close_upgrades() -> void:
	if _buying_upgrade or _app._page_hidden or not upgrades.visible:
		return
	if upgrades.is_offer():
		_dismiss_upgrade_intro()
		return
	upgrades.close()
	map.configure(_map_state(), _app.reduced_motion)
	map.show()
	_app._sync_jelly()
	_app._refresh()
	map._upgrades.grab_focus.call_deferred()
	_publish()


func _maybe_offer_upgrade() -> void:
	if not store.ready or not error.is_empty() or not map.visible \
		or store.upgrade_state().intro != "offer" or store.merged_level() != 1:
		return
	if not upgrades.present(_upgrade_state(), _preview_word(), _app.reduced_motion, 2, true):
		_upgrade_failed("The first Jelly upgrade introduction could not load.")
		return
	_app._sync_jelly()


func _accept_upgrade_intro() -> void:
	if _buying_upgrade or _app._page_hidden or not upgrades.visible or not upgrades.is_offer():
		return
	if not error.is_empty():
		if not store.load_state() or not _app.coin_wallet.load_state():
			_upgrade_failed(store.error if not store.ready else _app.coin_wallet.error)
			return
		error = ""
	if not store.begin_upgrade_guide():
		_upgrade_failed(store.error)
		return
	_show_upgrades()


func _dismiss_upgrade_intro() -> void:
	if _buying_upgrade or _app._page_hidden or not upgrades.visible or not upgrades.is_offer():
		return
	if not store.begin_upgrade_guide():
		_upgrade_failed(store.error)
		return
	error = ""
	_upgrade_error = ""
	upgrades.close()
	_app._sync_jelly()
	_app._refresh()
	map._upgrades.grab_focus.call_deferred()
	_publish()


func _upgrade_failed(message: String) -> void:
	_buying_upgrade = false
	error = message if not message.is_empty() else "The Jelly upgrade could not be saved. Please retry."
	upgrades.configure(_upgrade_state())
	_app._announce_status(error)
	_app._refresh()
	_publish()


func _recover_upgrade() -> bool:
	var pending: Dictionary = store.upgrade_state().pending
	if pending.is_empty() or not _app.coin_wallet.has_purchase(str(pending.id), _pending_upgrade_amount(pending)):
		return true
	var completed: bool = store.complete_upgrade_contribution(_app.coin_wallet) \
		if pending.get("mode", "") == "contribution" \
		else store.complete_upgrade(int(pending.level), _app.coin_wallet, str(pending.kind))
	if not completed:
		error = store.error
		return false
	return true


func _pending_upgrade_amount(pending: Dictionary) -> int:
	return int(pending.get("amount", pending.get("price", 0)))


func _upgrade_charging_changed(charging: bool) -> void:
	if charging:
		_app.audio.interact(_app.model.theme_id, true)
	_app.audio.set_upgrade_charging(charging)


func _upgrade_audio(cue: String) -> void:
	if cue == "upgrade_coin":
		_app.audio.play_upgrade_coin_spend()
	elif cue == "goal_complete":
		_app.audio.play_upgrade_milestone()
	else:
		_app.audio.play_jelly_cue(cue)


func contribute_upgrade(kind: String, amount: int = 25, resume_pending: bool = false) -> void:
	if _buying_upgrade or _app._page_hidden or starting or settling or not upgrades.visible \
		or not upgrades._active or upgrades.is_offer() or not store.ready or not error.is_empty() \
		or kind not in Store.UPGRADE_LEVEL_KEYS or amount != 25 \
		or store.upgrade_level(kind) >= Economy.MAX_UPGRADE_LEVEL:
		return
	var current: Dictionary = store.upgrade_state()
	if not resume_pending and (str(upgrades.snapshot().get("kind", "")) != kind \
		or int(upgrades._state.get("level", 0)) != int(current.level) \
		or int(upgrades._state.get("auto_merge_level", 0)) != int(current.auto_merge_level) \
		or upgrades._state.get("funded", {}) != current.funded):
		return
	var pending: Dictionary = current.pending
	if not pending.is_empty() and (pending.get("mode", "") != "contribution" \
		or str(pending.kind) != kind or int(pending.amount) != amount):
		return
	if not _app.coin_wallet.ready or not _app.coin_wallet.error.is_empty():
		_upgrade_failed(_app.coin_wallet.error)
		return
	var paid: bool = not pending.is_empty() \
		and _app.coin_wallet.has_purchase(str(pending.id), _pending_upgrade_amount(pending))
	if _app.coin_wallet.balance < amount and not paid:
		upgrades.configure(_upgrade_state())
		_publish()
		return
	_buying_upgrade = true
	_upgrade_error = ""
	var previous_level: int = store.upgrade_level(kind)
	# Keep the held control enabled while this synchronous journal commits.
	if not store.begin_upgrade_contribution(kind, amount):
		_upgrade_failed(store.error)
		return
	pending = store.upgrade_state().pending
	var spent: Dictionary = _app.coin_wallet.spend(str(pending.id), int(pending.amount))
	if not spent.ok:
		if spent.get("reason") == "insufficient":
			_buying_upgrade = false
			upgrades.configure(_upgrade_state())
			_publish()
		else:
			_upgrade_failed(_app.coin_wallet.error)
		return
	if not store.complete_upgrade_contribution(_app.coin_wallet):
		_upgrade_failed(store.error)
		return
	_buying_upgrade = false
	error = ""
	_upgrade_error = ""
	_last_unlocked = store.upgrade_level(kind) if store.upgrade_level(kind) > previous_level else 0
	_last_unlocked_kind = kind
	_app._coin_flight.sync(_app.coin_wallet.balance, false)
	upgrades.configure(_upgrade_state())
	# The upgrade page owns this receipt; hidden game controls refresh on exit.
	_publish()


func purchase_upgrade(level: int, kind: String = "jelly") -> void:
	if _buying_upgrade or _app._page_hidden or starting or settling or not upgrades.visible \
		or not upgrades._active or upgrades.is_offer() or not store.ready \
		or kind not in Store.UPGRADE_LEVEL_KEYS or level != store.upgrade_level(kind) + 1 \
		or level > Economy.MAX_UPGRADE_LEVEL:
		return
	var pending: Dictionary = store.upgrade_state().pending
	if pending.get("mode", "") == "contribution":
		return
	if not pending.is_empty() and pending.kind != kind:
		_upgrade_failed("Finish the saved upgrade before buying another.")
		return
	var price: int = int(pending.price) if not pending.is_empty() else Economy.permanent_upgrade_price(kind, level)
	var paid: bool = not pending.is_empty() and _app.coin_wallet.has_purchase(str(pending.id), price)
	if not _app.coin_wallet.ready:
		_upgrade_failed(_app.coin_wallet.error)
		return
	if _app.coin_wallet.balance < price and not paid:
		_upgrade_error = "Need %d more coins. Earn them by playing stages." % (price - _app.coin_wallet.balance)
		upgrades.configure(_upgrade_state())
		_publish()
		return
	_buying_upgrade = true
	_upgrade_error = ""
	upgrades.configure(_upgrade_state())
	if not store.begin_upgrade(level, kind):
		_upgrade_failed(store.error)
		return
	pending = store.upgrade_state().pending
	var spent: Dictionary = _app.coin_wallet.spend(str(pending.id), int(pending.price))
	if not spent.ok:
		if spent.get("reason") == "insufficient":
			_buying_upgrade = false
			_upgrade_error = "Need %d more coins." % (int(pending.price) - _app.coin_wallet.balance)
			upgrades.configure(_upgrade_state())
			_publish()
		else:
			_upgrade_failed(_app.coin_wallet.error)
		return
	_app._coin_flight.sync(_app.coin_wallet.balance)
	if not store.complete_upgrade(level, _app.coin_wallet, kind):
		_upgrade_failed(store.error)
		return
	_buying_upgrade = false
	error = ""
	_upgrade_error = ""
	_last_unlocked = level
	_last_unlocked_kind = kind
	upgrades.configure(_upgrade_state())
	_app._sync_jelly()
	_app._refresh()
	_publish()


func _key(context: Dictionary) -> String:
	return "professional:%s:%s" % [context.get("course_id", ""), context.get("module_id", "")] \
		if context.get("track") == "professional" else "growth"


func open_map() -> void:
	if _app._page_hidden or settling or _app._jelly_pause_open():
		return
	request_context = Context.freeze(_app._desired_learning_context("word_jelly"))
	context_key = _key(request_context)
	if not store.ready and not store.load_state():
		error = store.error
	if store.ready and not store.pending(context_key).is_empty():
		if not _recover_result():
			_show_map()
			return
	if store.ready and not _recover_upgrade():
		_show_map()
		return
	_app._hide_mode_menu(false, false)
	_app._on_input_canceled()
	_app.audio.stop_jelly_sounds()
	_show_map()


func _show_map() -> void:
	upgrades.close()
	_sync_map_audio()
	map.open(_map_state(), _app.reduced_motion)
	_app._sync_jelly()
	_app._refresh()
	_maybe_offer_upgrade()


func _map_state() -> Dictionary:
	var highest: int = store.highest_cleared(context_key) if store.ready else 0
	var ratings: Dictionary = {}
	for number in range(1, highest + 1):
		ratings[str(number)] = store.best_stars(context_key, number)
	return {"highest_cleared": highest, "best_stars": ratings, "frontier": mini(highest + 1, 99),
		"context_key": context_key,
		"pip_age": _app.growth.age, "pip_profile": _app._professional_profile_for(request_context),
		"coins": _app.coin_wallet.balance, "error": error,
		"loading": starting, "pending_stage": selected_stage,
		"boss_markers": BossCatalog.map_markers(mini(highest + 1, 99)),
		"boss_victories": store.boss_victories(context_key) if store.ready else [],
		"merged_level": store.merged_level() if store.ready else 1,
		"auto_merge_level": store.auto_merge_level() if store.ready else 1}


func request_stage(number: int) -> void:
	if starting or settling or not map.visible or upgrades.visible or not store.ready or not error.is_empty() \
		or not store.available(context_key, number):
		return
	selected_stage = number
	challenge = false
	_start_request()


func request_challenge() -> void:
	if starting or settling or not map.visible or upgrades.visible or not store.ready or not error.is_empty():
		return
	selected_stage = 0
	challenge = true
	_start_request()


func _start_request() -> void:
	starting = true
	pending_plan.clear()
	error = ""
	map.configure(_map_state(), _app.reduced_motion)
	requesting_preparation = true
	var started: bool = _app.new_round(-1, false, "", "word_jelly", "", false)
	requesting_preparation = false
	if started:
		_app._default_focus().grab_focus()
		_app._restore_mode_music()
	elif not _app._pending_professional_round.is_empty() and _app.professional.phase == "failed":
		start_failed(_app.professional.error)
	else:
		if _app._pending_vocabulary_round.is_empty() and _app._pending_professional_round.is_empty():
			starting = false
			if error.is_empty():
				error = "This stage could not start. Please retry."
			map.configure(_map_state(), _app.reduced_motion)


func prepare_plan(words: Array, seed: int) -> Dictionary:
	if not starting:
		return {"ok": false, "error": "Choose a stage before preparing its words."}
	var recipe: Dictionary = store.recipe(context_key, selected_stage) if not challenge else {}
	var result: Dictionary
	if not pending_plan.is_empty():
		result = Catalog.rebuild_plan(Catalog.to_recipe(pending_plan), words)
	elif not recipe.is_empty():
		result = Catalog.rebuild_plan(recipe, words)
	else:
		var eligible: Array = words.filter(func(word: Dictionary) -> bool:
			return word.get("track") == "professional" or int(word.get("min_age", 3)) == _app.growth.learning_age())
		var weak: Array = eligible.filter(func(word: Dictionary) -> bool: return not _app._jelly_word_mastered(word))
		var limit: int = 16 if challenge else mini(3 + selected_stage - 1, 8)
		if weak.size() < limit:
			for word: Dictionary in eligible:
				if weak.size() >= limit:
					break
				if not weak.any(func(item: Dictionary) -> bool: return item.id == word.id):
					weak.append(word)
		result = Catalog.make_plan(selected_stage, weak, _app.growth.learning_age(), seed, challenge)
	if not result.get("ok", false):
		error = str(result.get("error", "This stage vocabulary is unavailable."))
		return result
	var refresh_pressure: bool = not challenge and selected_stage > store.highest_cleared(context_key) \
		and store.pending(context_key).is_empty()
	if refresh_pressure:
		result = Catalog.tighten_plan_pressure(result)
		if not result.get("ok", false):
			error = str(result.error)
			return result
	if challenge:
		var current: Array = result.words.filter(func(word: Dictionary) -> bool: return not _app._jelly_word_mastered(word))
		var review: Array = result.words.filter(func(word: Dictionary) -> bool: return _app._jelly_word_mastered(word))
		result.words = current + review
		result.word_ids = result.words.map(func(word: Dictionary) -> String: return str(word.id))
	if not challenge and not store.reserve_plan(context_key, result, refresh_pressure):
		error = store.error
		return {"ok": false, "error": error}
	result["merged_level_limit"] = store.merged_level()
	result["auto_merge_level"] = store.auto_merge_level()
	result["boss"] = BossCatalog.encounter(selected_stage, not challenge and selected_stage == 1 \
		and store.highest_cleared(context_key) == 0)
	pending_plan = result.duplicate(true)
	return result


func round_started() -> void:
	starting = false
	active_context_key = context_key
	_result_draft.clear()
	_result_round = ""
	_bonus_presented = false
	_result_committed = false
	_result_summary_presented = false
	_result_returned = false
	_result_retry = false
	_result_upgrades = false
	return_home_after_settlement = false
	error = ""
	map.close()
	upgrades.close()
	pending_plan.clear()
	_challenge_previous_best = store.challenge_best_stage(active_context_key)
	if _app._word_jelly.game.stage_run.kind == "challenge":
		record_challenge_stage(_app._word_jelly.game.stage_run.challenge_stage)


func record_challenge_stage(stage: int) -> void:
	if store.record_challenge_stage(active_context_key, stage):
		_pending_challenge_record = 0
		return
	_pending_challenge_record = stage
	error = store.error
	_app._word_jelly.game.error = error
	_app._announce_status(error)


func is_bound_round() -> bool:
	return _app._mode_id == "word_jelly" and _app._word_jelly.game.stage_run != null


func capture_result(result: Dictionary) -> bool:
	if not result.has("campaign"):
		return true
	var stage: Dictionary = result.campaign
	var chest_coins: int = 0
	var reward_id: String = "jelly:" + _app._round_id + ":0"
	if int(result.get("chest_count", 0)) > 0:
		if not _app._save_jelly_round_reward():
			error = _app._jelly_rewards.rewards.error
			return false
		chest_coins = int(_app.coin_wallet.chest_reward(reward_id).get("total", 0))
	var quote: Dictionary = Catalog.clear_reward(int(stage.number), int(stage.stars), chest_coins)
	if not quote.ok:
		error = str(quote.error)
		return false
	_result_round = _app._round_id
	_result_context_key = active_context_key
	_result_draft = {"kind": stage.kind, "number": stage.number, "outcome": stage.outcome,
		"stars": stage.stars, "time_elapsed": stage.time_elapsed,
		"seconds_remaining": stage.seconds_remaining, "seconds_total": stage.seconds_total,
		"seconds_added": stage.seconds_added, "score": result.score,
		"collection_count": stage.collection_count, "chest_count": result.chest_count,
		"chest_tier": result.chest_tier, "chest_coins": chest_coins,
		"bonus": quote.bonus, "completed_word_ids": []}
	if stage.kind == "challenge":
		_result_draft["challenge_stage"] = int(stage.get("challenge_stage", 1))
		_result_draft["challenge_previous_best"] = _challenge_previous_best
		_app._round_result["challenge_result"] = {
			"stage": int(stage.get("challenge_stage", 1)),
			"previous_best": _challenge_previous_best,
			"best": maxi(int(stage.get("challenge_stage", 1)), store.challenge_best_stage(active_context_key)),
			"collection_count": int(stage.collection_count), "new_best": false, "confirmed": false}
	var boss: Dictionary = result.get("boss", {})
	if bool(boss.get("active", false)):
		_result_draft["boss_roster_version"] = 2
		_result_draft["boss_id"] = int(boss.definition.get("id", 0))
		_result_draft["boss_victory"] = boss.get("outcome") == "defeated" and stage.outcome == "cleared"
		_result_draft["boss_outcome"] = str(boss.get("outcome", ""))
	for word: Dictionary in result.get("words", []):
		_result_draft.completed_word_ids.append(str(word.id))
	_app._round_result["stage_bonus"] = quote.duplicate(true)
	if not store.queue_result(_result_context_key, _result_round, _result_draft):
		error = store.error
		return false
	return true


func begin_settlement() -> void:
	settling = true
	_settlement_elapsed = 0.0
	_bonus_presented = false
	_app._show_jelly_rewards()
	_app._jelly_rewards.set_settlement_error(error)


func advance(delta: float) -> void:
	if upgrades.visible and not _app._page_hidden:
		upgrades.advance(delta)
	if not settling or _app._page_hidden or _app.collection_page.visible or _app._mode_menu_open() \
		or _app._round_end_active() or _app._round_celebration_active() or not is_finite(delta) or delta <= 0.0:
		return
	var room = _app._jelly_rewards
	room.advance_stage_feedback(delta)
	if not error.is_empty():
		room.set_settlement_error(error)
		return
	if _app._growth_save_failed:
		room.set_settlement_error(_app.growth.error)
		return
	_settlement_elapsed += delta
	if room._save_failed:
		error = room.rewards.error
		room.set_settlement_error(error)
		return
	if _result_draft.is_empty():
		if not capture_result(_app._round_result):
			room.set_settlement_error(error)
			return
		room.set_result_context(_app._round_result, _result_round)
	if room.has_pending():
		if _settlement_elapsed < 0.35 or room._holding or room._opening or room._paused:
			return
		var next: Button = null
		for card: Dictionary in room._cards:
			if not card.opened and not card.button.disabled:
				next = card.button
				break
		if next != null:
			room.begin_hold(next)
			room.advance_hold(Feel.HOLD_SECONDS)
		elif not _app._coin_flight.snapshot().active \
			and absf(_app._coin_counter.displayed - float(_app._coin_counter.target)) <= 0.001:
			if not room.collect_all_coins():
				error = room.rewards.error
				room.set_settlement_error(error)
		return
	if room._opening or room._holding or (room.stage_feedback_active() and not _result_returned) or _app._coin_flight.snapshot().active \
		or absf(_app._coin_counter.displayed - float(_app._coin_counter.target)) > 0.001:
		return
	if not _bonus_presented:
		if not _credit_bonus(_result_draft, _result_round, true):
			room.set_settlement_error(error)
			return
		_bonus_presented = true
		return
	if _settlement_elapsed < 2.2:
		return
	if not _result_committed:
		if not store.complete_result(_result_context_key, _result_round):
			error = store.error
			room.set_settlement_error(error)
			return
		_result_committed = true
	if _needs_result_choice() and not _result_returned:
		if not _result_summary_presented:
			_result_summary_presented = true
			if _result_draft.kind == "challenge":
				var best: int = store.challenge_best_stage(_result_context_key)
				var reached: int = int(_result_draft.challenge_stage)
				var summary := {"stage": reached, "previous_best": _challenge_previous_best, "best": best,
					"collection_count": int(_result_draft.collection_count), "confirmed": true,
					"new_best": reached > _challenge_previous_best and reached >= best}
				_app._round_result["challenge_result"] = summary.duplicate(true)
				room.present_challenge_result(summary)
			else:
				room.present_stage_failure()
		return
	settling = false
	_app._jelly_rewards_shown = false
	room.pause()
	_app._settlement_dialog.close()
	_app._coin_flight.sync(_app.coin_wallet.balance)
	_app.audio.stop_coin_sounds()
	if return_home_after_settlement:
		return_home_after_settlement = false
		_app._show_mode_menu()
	elif _result_upgrades:
		_result_upgrades = false
		open_map()
		open_upgrades()
	elif _result_retry:
		_result_retry = false
		var kind: String = str(_result_draft.kind)
		var number: int = int(_result_draft.number)
		open_map()
		if kind == "challenge":
			request_challenge()
		else:
			request_stage(number)
	else:
		_show_map()


func _needs_result_choice() -> bool:
	return _result_draft.get("kind") == "challenge" or _result_draft.get("kind") == "main" \
		and _result_draft.get("outcome") in ["timeout", "blocked"]


func accept_result(action: String = "map") -> void:
	if action not in ["map", "retry", "upgrades"] or not settling or not _result_committed \
		or not _result_summary_presented or not error.is_empty() or _result_returned \
		or _app._page_hidden or not _needs_result_choice():
		return
	_result_returned = true
	_result_retry = action == "retry"
	_result_upgrades = action == "upgrades"
	return_home_after_settlement = false


func _credit_bonus(result: Dictionary, round_id: String, animate: bool) -> bool:
	if int(result.bonus) <= 0:
		return true
	var receipt: String = round_id + ":stage-clear"
	var credited: Dictionary = _app.coin_wallet.credit_amount(receipt, int(result.bonus))
	if not credited.ok:
		error = _app.coin_wallet.error
		return false
	if animate and not credited.duplicate:
		_app._jelly_rewards.present_stage_bonus(receipt, credited)
	else:
		_app._coin_flight.sync(_app.coin_wallet.balance)
	return true


func _recover_result() -> bool:
	var pending: Dictionary = store.pending(context_key)
	if pending.is_empty():
		return true
	var room = _app._jelly_rewards
	if not room.configure_saved(_app.data.chests, _app.reduced_motion) and room.has_pending():
		error = room.rewards.error
		return false
	if not room.collect_all_coins():
		error = room.rewards.error
		return false
	if not _credit_bonus(pending.result, str(pending.round_id), false) \
		or not store.complete_result(context_key, str(pending.round_id)):
		if error.is_empty():
			error = store.error
		return false
	return true


func retry() -> void:
	if _app._page_hidden:
		return
	if not _app.coin_wallet.ready or not _app.coin_wallet.error.is_empty():
		_app.coin_wallet.load_state()
	if not store.load_state():
		error = store.error
		if upgrades.visible:
			upgrades.configure(_upgrade_state())
			_app._refresh()
			_publish()
			return
		if settling:
			_app._jelly_rewards.set_settlement_error(error)
		map.configure(_map_state(), _app.reduced_motion)
		return
	error = ""
	if upgrades.visible:
		_upgrade_error = ""
		if upgrades.is_offer():
			upgrades.configure(_upgrade_state())
		else:
			var pending_upgrade: Dictionary = store.upgrade_state().pending
			if not pending_upgrade.is_empty():
				if pending_upgrade.get("mode", "") == "contribution":
					contribute_upgrade(str(pending_upgrade.kind), int(pending_upgrade.amount), true)
				else:
					purchase_upgrade(int(pending_upgrade.level), str(pending_upgrade.kind))
			else:
				upgrades.configure(_upgrade_state())
		_app._refresh()
		return
	if _pending_challenge_record > 0:
		record_challenge_stage(_pending_challenge_record)
		if _pending_challenge_record > 0:
			return
		_app._word_jelly.game.error = ""
	var room = _app._jelly_rewards
	room.set_settlement_error("")
	if room._save_failed or room._collect_pending or room._unsaved_index >= 0:
		room.retry_save()
		if room._save_failed:
			error = room.rewards.error
			if settling:
				room.set_settlement_error(error)
			else:
				map.configure(_map_state(), _app.reduced_motion)
			return
	if settling:
		if not _result_committed and not _result_draft.is_empty() \
			and not store.queue_result(_result_context_key, _result_round, _result_draft):
			error = store.error
			room.set_settlement_error(error)
		return
	if is_open():
		if not _app._pending_professional_round.is_empty():
			starting = true
			map.configure(_map_state(), _app.reduced_motion)
			requesting_preparation = true
			_app.professional.retry()
			requesting_preparation = false
			if _app.professional.phase == "failed":
				start_failed(_app.professional.error)
			return
		if _recover_result() and _recover_upgrade():
			map.configure(_map_state(), _app.reduced_motion)
	else:
		_app._word_jelly.game.retry_stage_finish()


func cancel_start() -> void:
	starting = false
	pending_plan.clear()
	error = ""
	if is_open():
		map.configure(_map_state(), _app.reduced_motion)


func start_failed(message: String) -> void:
	starting = false
	error = message
	if is_open():
		map.configure(_map_state(), _app.reduced_motion)


func _home() -> void:
	if _buying_upgrade:
		return
	if upgrades.visible:
		close_upgrades()
		return
	if starting:
		_app._cancel_vocabulary_round()
		_app.professional.cancel()
		_app._pending_professional_round.clear()
	cancel_start()
	map.close()
	_app._show_mode_menu()


func snapshot() -> Dictionary:
	var state: Dictionary = map.snapshot() if map.visible else {"visible": false}
	state["upgrades"] = upgrades.snapshot()
	state["settling"] = settling
	state["context"] = context_key
	state["error"] = error
	return state

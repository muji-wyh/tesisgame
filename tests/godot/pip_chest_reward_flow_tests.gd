extends "res://tests/godot/coin_reward_flow_tests.gd"
## Exercise the new chest quote through the existing isolated real GameUI fixture.

const Growth = preload("res://scripts/growth_state.gd")


func _set_level(app, level: int) -> void:
	var mastered: Array[String] = []
	for index in range(Growth.level_threshold(level)):
		mastered.append(str(app.data.words[index].id))
	var config := ConfigFile.new()
	for key in ["version", "level", "age", "streaks", "mastered_words", "receipts"]:
		config.set_value("growth", key, {"version": Growth.VERSION, "level": level, "age": 0,
			"streaks": {}, "mastered_words": mastered, "receipts": []}[key])
	check(config.save(app.growth._path) == OK and app.growth.load_state() and app.growth.level == level,
		"A valid saved mastery history sets Pip Lv%d independently of age" % level)


func _quote(app, id: String, tier: int, level: int) -> Dictionary:
	var value: Dictionary = app.coin_wallet.chest_reward(id)
	var bonus: int = tier * ceili(level * 24.0 / 99.0)
	check(not value.is_empty() and value.get("pip_level", -1) == level and value.get("tier", -1) == tier
		and value.get("base", -1) == tier * 75 and value.get("bonus", -1) == bonus
		and value.get("total", -1) == tier * 75 + bonus,
		"The durable quote retains its earned tier, Pip level, base, bonus and total")
	return value


func _breakdown(value: Dictionary, quote: Dictionary, label: String) -> void:
	check(value.get("visible", false) and value.get("reward", {}) == quote,
		label + ": the displayed breakdown uses the exact durable quote")
	check(value.get("detail_text", "") == "Chest %d + Pip Lv%d bonus %d" % [quote.get("base", -1),
		quote.get("pip_level", -1), quote.get("bonus", -1)]
		and value.get("total_text", "") == "Total %d coins" % quote.get("total", -1),
		label + ": the player can read the base, Pip bonus and complete reward")


func _room_result(app, tier: int):
	var room = app._pop_rewards if app._mode_id == "pop" else app._jelly_rewards
	check(room.connect_storage(app.get_meta("coin_test_storage")), "The completed room shares isolated durable storage")
	var view = app._pop if app._mode_id == "pop" else app._active_jelly()
	view.game.phase = "finished"
	app._round_result = {"mode": app._mode_id, "score": 24, "chest_count": 1, "chest_tier": tier}
	check(app._save_pop_round_reward() if app._mode_id == "pop" else app._save_jelly_round_reward(),
		"GameUI saves the final chest under its actual completed round identity")
	if app._mode_id == "pop":
		app._pop_rewards_shown = true
	else:
		app._jelly_rewards_shown = true
	room.set_result_context(app._round_result, room._configured_id)
	app._refresh()
	room.resume()
	await settle()
	return room


func _single_quote(mode: String, action: String = "open") -> void:
	var app = await make_app(mode)
	_set_level(app, 99)
	finish_single(app)
	var tier: int = 6 if mode == "memory" else 1
	var id: String = app._single_chest_receipt()
	var quote: Dictionary = _quote(app, id, tier, 99)
	check(app.coin_wallet.balance == 0 and not app._single_result.snapshot().coin_breakdown.visible,
		mode + ": presentation reserves the quote without payment or replacing the hold instruction")
	_set_level(app, 0)
	app._refresh()
	if action == "open":
		open_single(app)
		check_arrival(app, tier * 99)
		_breakdown(app._single_result.snapshot().coin_breakdown, quote, mode)
		app._on_chest_opened()
	else:
		var button = app._single_result.home_button if action == "home" else app._single_result.replay_button
		button.pressed.emit()
		check(not app._settlement_dialog_open() and app.coin_wallet.balance == tier * 99,
			mode + ": " + action + " claims the unopened chest using its frozen quote")
	check(app.coin_wallet.balance == tier * 99 and app.coin_wallet.chest_reward(id) == quote,
		mode + ": stale opening callbacks neither reprice nor repeat the reward")
	await dispose(app)


func _room_quote(mode: String, action: String) -> void:
	var storage := Storage.new()
	var app = await make_app(mode, storage)
	_set_level(app, 20)
	var room = await _room_result(app, 3)
	var id: String = room._cards[0].reward_id
	var quote: Dictionary = _quote(app, id, 3, 20)
	check(app.coin_wallet.balance == 0, mode + ": the pending chest quote is not spendable money")
	_set_level(app, 99)
	check(app.coin_wallet.load_state() and app.coin_wallet.chest_reward(id) == quote,
		mode + ": wallet reload preserves the quote after Pip levels up")
	if action == "open":
		open_room(room)
		check_arrival(app, 240)
		_breakdown(room.snapshot().chests[0].get("coin_breakdown", {}), quote, mode)
		room._build_cards()
		_breakdown(room.snapshot().chests[0].get("coin_breakdown", {}), quote, mode + " rebuilt")
	elif action == "home":
		room._home.pressed.emit()
		check(app._mode_menu_open() and app.coin_wallet.balance == 240 and not app._coin_flight.snapshot().active,
			mode + ": Home settles the frozen total before leaving")
	else:
		var old_round: String = app._round_id
		room._back.pressed.emit()
		check(app._round_id != old_round and app.coin_wallet.balance == 240 and not app._coin_flight.snapshot().active,
			mode + ": Play again settles the frozen total before the fresh board")
	check(app.coin_wallet._receipts.get(id, 0) == 240 and app.coin_wallet.chest_reward(id) == quote,
		mode + ": manual and automatic routes save the same quoted receipt")
	await dispose(app)
	app = await make_app(mode, storage)
	check(app.coin_wallet.balance == 240 and app.coin_wallet.chest_reward(id) == quote,
		mode + ": app reload restores the paid quote and complete balance without another payout")
	await dispose(app)


func _pending_room_reload(mode: String) -> void:
	var storage := Storage.new()
	var app = await make_app(mode, storage)
	_set_level(app, 20)
	var room = await make_room(app, 3)
	var id: String = room._cards[0].reward_id
	var quote: Dictionary = _quote(app, id, 3, 20)
	await dispose(app)
	app = await make_app(mode, storage)
	_set_level(app, 99)
	room = app._pop_rewards if mode == "pop" else app._jelly_rewards
	check(room.connect_storage(storage) and room.configure_saved(app.data.chests, false),
		mode + ": a new app restores the saved unopened reward room")
	if mode == "pop":
		app._pop_rewards_shown = true
	else:
		app._jelly_rewards_shown = true
	app._refresh()
	room.resume()
	check(room._cards[0].reward_id == id and app.coin_wallet.balance == 0
		and app.coin_wallet.chest_reward(id) == quote,
		mode + ": the pending receipt keeps its original Lv20 quote in the Lv99 app")
	open_room(room)
	check(app.coin_wallet.balance == 240 and app.coin_wallet._receipts.get(id, 0) == 240,
		mode + ": opening after app reload pays the original quote exactly once")
	_breakdown(room.snapshot().chests[0].get("coin_breakdown", {}), quote, mode + " reloaded")
	await dispose(app)


func _single_retry(mode: String, fail_coins: bool) -> void:
	var app = await make_app(mode)
	_set_level(app, 20)
	finish_single(app)
	var tier: int = 6 if mode == "memory" else 1
	var id: String = app._single_chest_receipt()
	var quote: Dictionary = _quote(app, id, tier, 20)
	var storage = app.get_meta("coin_test_storage")
	storage.coin_writable = not fail_coins
	storage.medal_writable = fail_coins
	open_single(app)
	check(app._save_error and app.coin_wallet.balance == (0 if fail_coins else tier * 80),
		mode + ": a failed single-chest save retains the exact committed portion")
	_set_level(app, 99)
	storage.coin_writable = true
	storage.medal_writable = true
	app._single_result.retry_button.pressed.emit()
	check(not app._save_error and app.coin_wallet.balance == tier * 80
		and app.coin_wallet.chest_reward(id) == quote,
		mode + ": the real Retry button completes its original quote after a level change")
	_breakdown(app._single_result.snapshot().coin_breakdown, quote, mode + " retry")
	await dispose(app)


func _room_retry(fail_coins: bool) -> void:
	var app = await make_app("jelly")
	_set_level(app, 20)
	var room = await _room_result(app, 3)
	var storage = app.get_meta("coin_test_storage")
	var id: String = room._cards[0].reward_id
	var quote: Dictionary = _quote(app, id, 3, 20)
	storage.coin_writable = not fail_coins
	storage.reward_writable = fail_coins
	open_room(room)
	check(room._save_failed and not room.rewards.entries[0].opened
		and app.coin_wallet.balance == (0 if fail_coins else 240),
		"A failed credit or reward acknowledgement retains the exact unpaid/paid portion")
	_set_level(app, 99)
	storage.coin_writable = true
	storage.reward_writable = true
	room._retry.pressed.emit()
	check(not room._save_failed and room.rewards.entries[0].opened and app.coin_wallet.balance == 240,
		"Retry claims the original amount even after Pip level changes")
	_breakdown(room.snapshot().chests[0].get("coin_breakdown", {}), quote, "Retry")
	var saved: Variant = storage.coins
	room._retry.pressed.emit()
	check(storage.coins == saved and app.coin_wallet.balance == 240,
		"A stale Retry click does not duplicate the quote or payout")
	await dispose(app)


func _reservation_retry() -> void:
	var app = await make_app("pop")
	_set_level(app, 20)
	var storage = app.get_meta("coin_test_storage")
	var room = app._pop_rewards
	check(room.connect_storage(storage), "The pending Pop chest uses isolated reward storage")
	storage.coin_writable = false
	room.configure("pip-quote-save-failure", 1, "spring", app.data.chests, false, 1)
	app._pop_rewards_shown = true
	app._refresh()
	room.resume()
	var id: String = room._cards[0].reward_id
	check(room._save_failed and app.coin_wallet.balance == 0 and app.coin_wallet.chest_reward(id).is_empty(),
		"A quote save failure blocks opening without pretending its quote is durable")
	_set_level(app, 99)
	storage.coin_writable = true
	room._retry.pressed.emit()
	_quote(app, id, 1, 20)
	check(not room._save_failed, "Retry saves the first displayed level rather than repricing the failed quote")
	open_room(room)
	check(app.coin_wallet.balance == 80, "Opening after quote retry pays the preserved draft amount")
	await dispose(app)


func _pair_startup_retry() -> void:
	var storage := Storage.new()
	var app = await make_app("memory", storage)
	_set_level(app, 99)
	finish_single(app)
	var id: String = app._single_chest_receipt()
	var quote: Dictionary = _quote(app, id, 6, 99)
	await dispose(app)
	storage.coin_writable = false
	app = await make_app("phrase", storage)
	check(app._save_error and not app._progress_ready and app.coin_wallet.balance == 0,
		"Startup retains the quoted Memory chest when its coin credit cannot save")
	storage.coin_writable = true
	app._storage_retry_button.pressed.emit()
	check(app._progress_ready and not app._save_error and app.coin_wallet.balance == 594
		and app.medal_progress.pair_round("memory").settled and app.coin_wallet.chest_reward(id) == quote,
		"Startup Retry pays the saved Lv99 quote even with the new app's Lv0 growth")
	await dispose(app)
	app = await make_app("phrase", storage)
	check(app.coin_wallet.balance == 594 and app.coin_wallet.chest_reward(id) == quote,
		"A second startup cannot pay the recovered pair chest twice")
	await dispose(app)


func _fixed_payouts() -> void:
	var app = await make_app("phrase")
	_set_level(app, 99)
	var fixed: Dictionary = app._credit_coins("professional-or-collection", 2)
	check(fixed.ok and fixed.amount == 100 and app.coin_wallet.chest_reward("professional-or-collection").is_empty(),
		"The shared non-chest callback keeps its original tier payout at Lv99")
	check(app.coin_wallet.credit_amount("combo", 12).ok and app.coin_wallet.balance == 112,
		"Arbitrary combo coin receipts do not receive a chest bonus")
	check(app.coin_wallet.credit("paid-before-quotes", 1).ok, "The legacy fixture contains a previously paid base chest")
	var paid: Dictionary = app._credit_chest_coins("paid-before-quotes", 1)
	check(paid.ok and paid.duplicate and paid.amount == 0 and app.coin_wallet.balance == 162
		and paid.chest_reward.base == 50 and paid.chest_reward.bonus == 0 and paid.chest_reward.total == 50,
		"A paid legacy chest keeps its original amount without a retroactive Pip top-up")
	await dispose(app)


func _unready_growth_retry() -> void:
	var app = await make_app("pop")
	_set_level(app, 20)
	var saved_growth: String = FileAccess.get_file_as_string(app.growth._path)
	var broken := FileAccess.open(app.growth._path, FileAccess.WRITE)
	broken.store_string("unreadable growth fixture")
	broken.close()
	app.growth.ready = false
	var id: String = "professional:pending-chest-with-unready-growth"
	var first: Dictionary = app._reserve_chest_reward(id, 1)
	check(not first.ok and not app.growth.ready and app.coin_wallet.chest_reward(id).is_empty(),
		"A chest with no known quote waits for unavailable growth instead of silently using Lv0")
	var repaired := FileAccess.open(app.growth._path, FileAccess.WRITE)
	repaired.store_string(saved_growth)
	repaired.close()
	var retry: Dictionary = app._reserve_chest_reward(id, 1)
	check(retry.ok and app.growth.ready and not app._growth_save_failed,
		"The chest retry reloads repaired learning storage without an app restart")
	_quote(app, id, 1, 20)
	var storage = app.get_meta("coin_test_storage")
	storage.coin_writable = false
	var draft_id: String = "professional:known-chest-draft"
	var draft: Dictionary = app._reserve_chest_reward(draft_id, 1)
	check(not draft.ok and draft.reward.get("total", 0) == 80,
		"A failed quote write retains the known Lv20 draft")
	_set_level(app, 99)
	app.growth.ready = false
	broken = FileAccess.open(app.growth._path, FileAccess.WRITE)
	broken.store_string("growth temporarily unavailable after quote")
	broken.close()
	storage.coin_writable = true
	var known: Dictionary = app._reserve_chest_reward(draft_id, 1)
	check(known.ok and known.reward == draft.reward and not app.growth.ready,
		"A known draft can finish saving while growth is unavailable, without repricing at the later level")
	check(app.coin_wallet.balance == 0, "Growth recovery only reserves quotes; it never pays them")
	await dispose(app)


func _mixed_quote_and_medal_retry() -> void:
	var app = await make_app("match")
	_set_level(app, 20)
	var storage = app.get_meta("coin_test_storage")
	for index in range(app.model.lesson_words.size()):
		if index == app.model.lesson_words.size() - 1:
			check(app.model.chest_earned, "Match earned its chest before the final pair's storage interruption")
			storage.medal_writable = false
			storage.coin_writable = false
		var word: Dictionary = app.model.lesson_words[index]
		app.cards[str(word.id) + ":word"].pressed.emit()
		app.cards[str(word.id) + ":image"].pressed.emit()
		app.feedback_timer.stop()
		app._continue_match()
	check(app.model.phase == "won" and app._pair_save_failed and app._chest_quote_failed and app._save_error,
		"A final Match pair can leave both its medal completion and chest quote waiting to save")
	Fixture.finish_celebration(app)
	check(app._single_result.retry_button.is_visible_in_tree(),
		"The midround chest reveal finishes before the real modal Retry control is used")
	storage.coin_writable = true
	app._single_result.retry_button.pressed.emit()
	check(not app._chest_quote_failed and app._pair_save_failed and app._save_error
		and app._single_result.retry_button.is_visible_in_tree() and not app._single_result.retry_button.disabled
		and app._single_result.home_button.disabled and app._single_result.replay_button.disabled,
		"Recovering only the quote keeps the medal error and Retry action, with departure still blocked")
	check(app.coin_wallet.balance == 0 and not app.medal_progress.pair_round("match").completed,
		"Quote-only recovery cannot pay or acknowledge the blocked completed round")
	_quote(app, app._single_chest_receipt(), 1, 20)
	storage.medal_writable = true
	app._single_result.retry_button.pressed.emit()
	Fixture.finish_celebration(app)
	check(not app._save_error and not app._pair_save_failed and app.model.chest_state == "closed",
		"The later medal retry finishes recovery without automatically opening the chest")
	open_single(app)
	check(app.coin_wallet.balance == 80, "Opening after both stores recover pays the single original quote")
	await dispose(app)


func _phrase_quote_completion_retry(leave_pending: bool = false) -> void:
	var app = await make_app("phrase")
	_set_level(app, 20)
	var storage = app.get_meta("coin_test_storage")
	storage.coin_writable = false
	var view = app._phrase
	for question in range(3):
		for id in view.game.current_question().words:
			for index in range(view.game.options.size()):
				if view.game.options[index].id == id:
					view.option_buttons[index].pressed.emit()
		view.action_button.pressed.emit()
		view.pip.set_process(false)
		if question < 2:
			view.pip._process(view.pip.GAMEPLAY_HAPPY_SECONDS + 0.01)
			view.action_button.pressed.emit()
	check(view.completion_pending and app._chest_quote_failed and app._save_error
		and not app._round_celebration_active() and app.coin_wallet.balance == 0,
		"Phrase completion waits at its failed quote before the celebration or any payment")
	storage.coin_writable = true
	if leave_pending:
		app._show_mode_menu()
		check(app._mode_menu_open() and not view.completion_pending and app.coin_wallet.balance == 80,
			"Home accepts a pending Phrase completion and claims its recovered quote exactly once")
		_quote(app, app._single_chest_receipt(), 1, 20)
		await dispose(app)
		return
	app._retry_reward_save()
	check(not app._chest_quote_failed and not app._save_error and view.completion_pending
		and app._round_celebration_active() and app.coin_wallet.balance == 0,
		"Quote Retry resumes the pending Phrase celebration without opening or crediting its chest")
	Fixture.finish_celebration(app)
	check(not view.completion_pending and app.model.phase == "won" and app.model.chest_state == "closed"
		and app.coin_wallet.balance == 0 and app.chest_button.is_visible_in_tree(),
		"The resumed celebration hands off to the real closed chest with no automatic claim")
	_quote(app, app._single_chest_receipt(), 1, 20)
	open_single(app)
	check(app.coin_wallet.balance == 80, "A later deliberate Phrase chest hold pays the recovered quote once")
	await dispose(app)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 800)
	for mode in ["match", "memory", "phrase"]:
		await _single_quote(mode)
	await _single_quote("memory", "replay")
	await _single_quote("phrase", "home")
	for mode in ["pop", "jelly", "word_jelly"]:
		await _room_quote(mode, "open")
		await _room_quote(mode, "replay" if mode != "pop" else "home")
	for fail_coins in [true, false]:
		await _room_retry(fail_coins)
	for mode in ["pop", "jelly"]:
		await _pending_room_reload(mode)
	await _single_retry("memory", true)
	await _single_retry("phrase", false)
	await _reservation_retry()
	await _pair_startup_retry()
	await _fixed_payouts()
	await _unready_growth_retry()
	await _mixed_quote_and_medal_retry()
	await _phrase_quote_completion_retry()
	await _phrase_quote_completion_retry(true)
	print("Pip chest reward flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

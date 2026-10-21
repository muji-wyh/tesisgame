extends RefCounted

const State = preload("res://scripts/growth_state.gd")


static func install(app, directory: String, filename: String = "growth.cfg") -> void:
	app.coin_wallet = preload("res://scripts/coin_wallet.gd").new(directory + "/coins.cfg")
	app.pop_reward_save_path = directory + "/pop-rewards.cfg"
	app.jelly_reward_save_path = directory + "/jelly-rewards.cfg"
	app.professional_save_path = directory + "/professional.json"
	app.growth = State.new(directory + "/" + filename)


static func choose_pop_player(app) -> void:
	app._start_pop_listening()


static func enter_mode(app, id: String) -> void:
	# Gameplay fixtures use the same guarded Home route as a player.
	app._show_mode_menu()
	app.choose_mode(id)


static func reserve_pair_chest(app) -> void:
	if app._mode_id == "memory":
		# Memory earns the remaining tier on completion, with no lottery reservation.
		assert(app._sync_pair_reward(), app.medal_progress.error)
		return
	if app._mode_id not in ["match", "memory"]:
		app.model.chest_earned = true
		return
	var pair: Dictionary = app.medal_progress.pair_round(app._mode_id)
	if pair.get("id", "") != app._round_id:
		pair = app.medal_progress.begin_pair_round(app._mode_id, app._round_id, 1)
	assert(pair.get("id", "") == app._round_id, "The fixture needs a loaded round reservation.")
	if pair.awarded:
		return
	# Override chance only in the fixture; the real answer path still earns it.
	var next_state: Dictionary = app.medal_progress._pair_state.duplicate(true)
	next_state[app._mode_id].round.pair = 1
	assert(app.medal_progress._commit_pair_state(next_state), app.medal_progress.error)
	app._pair_proposed_pair = 1
	app.model.chest_reward_pair = 1


static func earn_pair_chest(app) -> void:
	reserve_pair_chest(app)
	if app._mode_id not in ["match", "memory"]:
		return
	if app._mode_id == "memory":
		assert(app.medal_progress.finish_memory_round(app._round_id, app._memory.memory.reward_tier(), app.model.theme_id),
			app.medal_progress.error)
		assert(app._sync_pair_reward(), app.medal_progress.error)
		return
	assert(app.medal_progress.record_pair_reward(app._mode_id, app._round_id, app.model.theme_id),
		app.medal_progress.error)
	var pair: Dictionary = app.medal_progress.pair_round(app._mode_id)
	app.model.chest_earned = true
	app.model.reward_theme = str(pair.theme)
	assert(app._sync_pair_reward(), app.medal_progress.error)


static func start_memory(app) -> void:
	# Cross both real player gates when a fixture needs an active Memory board.
	if not app._memory.memory.started:
		app._memory.start_button.pressed.emit()
	if app._memory.memory.studying:
		app._memory_peek_countdown.action_button.pressed.emit()


static func finish_celebration(app) -> void:
	# Chest/result-focused suites explicitly cross the shared presentation gate.
	# Dedicated celebration suites exercise real timing, narration and cancellation.
	app._pair_reward.advance(app._pair_reward.REWARD_SECONDS + 0.01)
	app.audio.stop_pair_chest_discovery()
	app._refresh()
	if not app._round_celebration.is_active():
		return
	app.audio.stop_voice()
	app._round_celebration.set_narration_playing(false)
	app._round_celebration.advance(3.01)
	if app._round_celebration.is_active():
		assert(app._mode_id in ["match", "memory"] and app._round_celebration.is_ready() and not app.model.chest_earned)
		app._round_celebration.action_button.pressed.emit()

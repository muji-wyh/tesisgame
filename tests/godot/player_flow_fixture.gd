extends RefCounted

const State = preload("res://scripts/growth_state.gd")


static func install(app, directory: String, filename: String = "growth.cfg") -> void:
	app.coin_wallet = preload("res://scripts/coin_wallet.gd").new(directory + "/coins.cfg")
	app.pop_reward_save_path = directory + "/pop-rewards.cfg"
	app.jelly_reward_save_path = directory + "/jelly-rewards.cfg"
	app.growth = State.new(directory + "/" + filename)


static func choose_pop_player(app) -> void:
	app._start_pop_listening()


static func reserve_pair_chest(app) -> void:
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
	assert(app.medal_progress.record_pair_reward(app._mode_id, app._round_id, app.model.theme_id),
		app.medal_progress.error)
	var pair: Dictionary = app.medal_progress.pair_round(app._mode_id)
	app.model.chest_earned = true
	app.model.reward_theme = str(pair.theme)
	assert(app._sync_pair_reward(), app.medal_progress.error)


static func finish_celebration(app) -> void:
	# Chest/result-focused suites explicitly cross the shared presentation gate.
	# Dedicated celebration suites exercise real timing, narration and cancellation.
	app._pair_reward.advance(3.0)
	app._refresh()
	if not app._round_celebration.is_active():
		return
	app.audio.stop_voice()
	app._round_celebration.set_narration_playing(false)
	app._round_celebration.advance(3.01)
	if app._round_celebration.is_active():
		assert(app._round_celebration.is_ready())
		app._round_celebration.action_button.pressed.emit()

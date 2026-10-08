extends RefCounted

const State = preload("res://scripts/leaderboard_state.gd")


static func install(app, directory: String, filename: String = "leaderboards.cfg") -> void:
	app.pop_reward_save_path = directory + "/pop-rewards.cfg"
	app.leaderboard_state = State.new(directory + "/" + filename)
	assert(app.leaderboard_state.load_state())
	assert(app.leaderboard_state.create_profile("Test player", "duck").ok)


static func choose_pop_player(app) -> void:
	if app._leaderboard_gate != "pop":
		app._request_pop_player()
	var panel = app._leaderboard_panel
	var id: String = str(app.leaderboard_state.profiles[0].id)
	var choice := panel.find_child("LeaderboardPlayer_" + id, true, false) as Button
	assert(choice != null)
	assert(panel.find_child("LeaderboardStartGame", true, false) == null)
	choice.pressed.emit()
	assert(app._pop_player_id == id and not app._leaderboard_overlay.visible)


static func finish_celebration(app) -> void:
	# Chest/result-focused suites explicitly cross the shared presentation gate.
	# Dedicated celebration suites exercise real timing, narration and cancellation.
	if not app._round_celebration.is_active():
		return
	app.audio.stop_voice()
	app._round_celebration.set_narration_playing(false)
	app._round_celebration.advance(3.01)
	if app._round_celebration.is_active():
		assert(app._round_celebration.is_ready())
		app._round_celebration.action_button.pressed.emit()

extends RefCounted

const State = preload("res://scripts/growth_state.gd")


static func install(app, directory: String, filename: String = "growth.cfg") -> void:
	app.pop_reward_save_path = directory + "/pop-rewards.cfg"
	app.jelly_reward_save_path = directory + "/jelly-rewards.cfg"
	app.growth = State.new(directory + "/" + filename)


static func choose_pop_player(app) -> void:
	app._start_pop_listening()


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

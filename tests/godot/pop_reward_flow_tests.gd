extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Feel = preload("res://scripts/chest_feel.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _controller(app, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	app._input(event)


func _run() -> void:
	var directory: String = "user://pop-reward-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(390, 844)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	Fixture.install(app, directory)
	root.add_child(app)
	app.audio.muted = true
	await process_frame
	await process_frame
	app.choose_mode("pop")
	Fixture.choose_pop_player(app)
	app._pop.set_listening(true, true, "Listening.")
	app._pop.set_process(false)
	check(app._pop.game.chest_count == 0, "An actual new Pop round starts without chests")
	for hit_index in range(24):
		if app._pop.game.targets.is_empty():
			app._pop._advance_game(0.66)
		if not app._pop.game.targets.is_empty():
			app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
	app._pop._advance_game(app._pop.game.remaining + 1.0)
	await process_frame
	check(app._pop.game.chest_count == 3 and app._leaderboard_result.chest_count == 3,
		"The finished score publishes all three earned opportunities")
	check(app._pop_rewards.has_pending() and FileAccess.file_exists(app.pop_reward_save_path),
		"Finished-round treasure is saved before the result action")
	check(app._round_celebration.is_active() and not app._pop.visible,
		"The shared celebration covers the saved Pop result until its performance ends")
	Fixture.finish_celebration(app)
	check(not app._pop_rewards_shown and app._pop.visible, "Statistics remain visible before choosing treasure")
	app._pop.chests_button.pressed.emit()
	await process_frame
	await process_frame
	var room = app._pop_rewards
	room.set_process(false)
	check(app._pop_rewards_shown and room.visible and not app._pop.visible, "The result opens the dedicated treasure page")
	check(room.snapshot().chest_count == 3, "All three earned chests appear together")
	var types: Array[String] = []
	for entry in room.snapshot().chests:
		types.append(str(entry.type))
	check(types.size() == 3 and types[0] != types[1] and types[1] != types[2] and types[0] != types[2],
		"A reward batch has three different chest types")
	var first: Button = room._cards[0].button
	first.grab_focus()
	_controller(app, true)
	room.advance_hold(0.5)
	check(room.snapshot().holding, "Controller acceptance begins the selected chest hold")
	app._on_input_canceled()
	check(not room.snapshot().holding and room.snapshot().opened_count == 0,
		"Global input cancellation cannot consume an unopened chest")
	_controller(app, false)
	_controller(app, true)
	room.advance_hold(Feel.HOLD_SECONDS)
	room._cards[0].art.set_process(false)
	room._cards[0].art._advance_animation(Feel.RELEASE_TIME + 0.01)
	check(room._cards[0].art.opening_committed(), "The selected chest reaches its mechanical release")
	app.on_page_hidden()
	check(room.snapshot().opened_count == 1 and not room.snapshot().opening,
		"Backgrounding settles a committed opening and saves exactly one chest")
	app.on_page_visible()
	_controller(app, false)
	check(not room.snapshot().paused, "Returning resumes the reward room without a new microphone session")
	app._hide_pop_rewards()
	check(app._pop.visible and app._pop.game.chest_count == 3, "Back retains the scored result")
	app._start_pop_listening()
	check(app._pop_rewards_shown and not app._leaderboard_overlay.visible,
		"Replay returns to unopened earned treasure before selecting another player")
	room.begin_hold(room._cards[1].button)
	room.advance_hold(0.4)
	app._show_leaderboard("boards", false)
	check(room.snapshot().paused and not room.snapshot().holding and room.snapshot().opened_count == 1,
		"A covering leaderboard cancels an unfinished chest gesture")
	app._hide_leaderboard()
	check(not room.snapshot().paused, "Closing the leaderboard restores unopened reward controls")
	app.set_reduced_motion(true)
	for index in [1, 2]:
		room.begin_hold(room._cards[index].button)
		room.advance_hold(Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 3 and not room.has_pending(), "All chests can be opened independently")
	app._hide_pop_rewards()
	app._start_pop_listening()
	check(app._leaderboard_gate == "pop" and app._leaderboard_overlay.visible,
		"After opening every chest the next player can start a fresh round")
	Fixture.choose_pop_player(app)
	check(app._pop.game.chest_count == 0, "The next round does not inherit the previous reward count")
	app.audio.halt()
	app.queue_free()
	await process_frame
	await process_frame
	print("Pop reward flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

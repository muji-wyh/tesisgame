extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Feel = preload("res://scripts/chest_feel.gd")

class Storage extends RefCounted:
	var text: Variant = null
	var writable: bool = false
	var writes: int = 0

	func popRewardState() -> Variant:
		return text

	func savePopRewardState(value: String) -> bool:
		if not writable:
			return false
		text = value
		writes += 1
		return true

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
	root.size = Vector2i(390, 844)
	for fragments in [0, 3, 4, 9]:
		await _fragment_flow_checks(fragments)
	await _early_exit_checks()
	await _save_failure_checks()
	await _pending_treasure_reload_checks()
	print("Pop reward flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _create_app():
	var directory: String = "user://pop-reward-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	Fixture.install(app, directory)
	root.add_child(app)
	app.audio.muted = true
	await process_frame
	await process_frame
	app.choose_mode("pop")
	Fixture.choose_pop_player(app)
	app._pop.set_listening(true, true, "Listening.")
	app._pop.set_process(false)
	return app


func _earn_fragments(app, count: int, finish_presentation: bool = true) -> void:
	for hit_index in range(count):
		if app._pop.game.targets.is_empty():
			app._pop._advance_game(0.66)
		check(not app._pop.game.targets.is_empty(), "A marked fragment fixture has a real live target")
		if app._pop.game.targets.is_empty():
			return
		app._pop.game.targets[0].chest = true
		var before: int = app._pop.game.fragment_count
		app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
		check(app._pop.game.fragment_count == before + 1,
			"A successful transcript slices its visible chest-marked word and earns one fragment")
		if app._pop.reward_presentation_active():
			check(app._pop.game.phase == "paused" and not app._pop._listening,
				"Chest assembly and upgrade wait with voice recognition and round time paused")
			var remaining: float = app._pop.game.remaining
			app._pop._advance_game(3.0)
			check(app._pop.game.remaining == remaining, "The chest presentation cannot consume answer time")
			if not finish_presentation:
				return
			app._pop.advance_reward_presentation(3.0)
			check(not app._pop.reward_presentation_active(), "The chest milestone completes before live speech resumes")
			app._pop.set_listening(true, true, "Listening.")
			app._pop.set_process(false)


func _finish_pop(app) -> void:
	app._pop._advance_game(app._pop.game.remaining + 1.0)
	await process_frame


func _dispose(app) -> void:
	app.audio.halt()
	app.queue_free()
	await process_frame
	await process_frame


func _fragment_flow_checks(fragments: int) -> void:
	var app = await _create_app()
	var tier: int = 0 if fragments < 4 else 1 + floori((fragments - 4) / 5.0)
	check(app._pop.game.chest_count == 0 and app._pop.game.fragment_count == 0,
		"An actual new Pop round starts without fragments or chests")
	await _earn_fragments(app, fragments)
	await _finish_pop(app)
	check(app._round_result.fragment_count == fragments and app._round_result.chest_tier == tier
		and app._round_result.chest_count == (1 if tier > 0 else 0),
		"Round results derive exactly one final chest from %d fragments" % fragments)
	if tier == 0:
		check(not app._pop_rewards.has_pending() and not FileAccess.file_exists(app.pop_reward_save_path)
			and not app._round_celebration.is_active() and app._pop.visible,
			"A partial fragment recipe reaches results without fabricating a chest or celebration")
		check(app._pop.chests_button.disabled, "Zero-chest results cannot navigate to an empty reward room")
		app._pop.replay_button.pressed.emit()
		check(app._pop.game.phase == "ready" and app._pop.game.fragment_count == 0,
			"Replay resets a partial recipe and waits for live microphone permission")
		await _dispose(app)
		return
	check(app._pop_rewards.has_pending() and FileAccess.file_exists(app.pop_reward_save_path),
		"Finished-round treasure is saved before the result action")
	var saved_entries: Array = app._pop_rewards.rewards.entries.duplicate(true)
	check(saved_entries.size() == 1 and saved_entries[0].tier == tier,
		"The durable round batch contains its final tier and no intermediate chest")
	check(app._round_celebration.is_active() and not app._pop.visible,
		"The shared celebration covers the saved Pop result until its performance ends")
	Fixture.finish_celebration(app)
	check(not app._pop_rewards_shown and app._pop.visible, "Statistics remain visible before choosing treasure")
	if fragments == 9:
		var first_id: String = app._pop.game.round_id
		app._pop.replay_button.pressed.emit()
		check(app._pop.game.phase == "ready" and app._pop.game.round_id != first_id
			and not app._pop_rewards_shown and app._pop_rewards.rewards.entries == saved_entries,
			"Play again starts a fresh round while preserving the previous unopened final chest")
		app._pop.set_listening(true, true, "Listening.")
		app._pop.set_process(false)
		await _earn_fragments(app, 4)
		await _finish_pop(app)
		check(app._round_result.chest_count == 1 and app._round_result.chest_tier == 1
			and app._pop_rewards.rewards.entries.size() == 2
			and app._pop_rewards.rewards.entries[0].tier == 2
			and app._pop_rewards.rewards.entries[1].tier == 1,
			"A second completed round adds one final chest without replacing the prior upgraded treasure")
		Fixture.finish_celebration(app)
		var durable: String = FileAccess.get_file_as_string(app.pop_reward_save_path)
		app._pop_finished(app._round_result.duplicate(true))
		check(FileAccess.get_file_as_string(app.pop_reward_save_path) == durable,
			"Repeated completion cannot duplicate the newly saved chest")
	app._pop.chests_button.pressed.emit()
	await process_frame
	await process_frame
	var room = app._pop_rewards
	room.set_process(false)
	check(app._pop_rewards_shown and room.visible and not app._pop.visible, "The result opens the dedicated treasure page")
	check(room.snapshot().chest_count == (2 if fragments == 9 else 1),
		"The opening page includes only final round rewards and any previously saved treasure")
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
	if fragments == 9:
		room.begin_hold(room._cards[1].button)
		room.advance_hold(0.4)
		app._show_collection()
		check(room.snapshot().paused and not room.snapshot().holding and room.snapshot().opened_count == 1,
			"The growth catalog cancels an unfinished chest gesture")
		app._hide_collection()
		check(not room.snapshot().paused, "Closing the growth catalog restores unopened reward controls")
		app.set_reduced_motion(true)
		room.begin_hold(room._cards[1].button)
		room.advance_hold(Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == room.snapshot().chest_count and not room.has_pending(),
		"Each final chest opens once without generating its earlier upgrade tiers")
	app._hide_pop_rewards()
	app._start_pop_listening()
	check(app._pop.game.phase == "ready" and not app._pop_rewards_shown,
		"After opening every chest a fresh round waits for microphone permission")
	check(app._pop.game.chest_count == 0, "The next round does not inherit the previous reward count")
	await _dispose(app)


func _early_exit_checks() -> void:
	for fragments in [3, 4]:
		var app = await _create_app()
		await _earn_fragments(app, fragments, false)
		check(app._pop.game.phase == ("paused" if fragments == 4 else "running"),
			"Prepare a live round exit during a partial recipe or active chest assembly")
		app.choose_mode("match")
		check(app._mode_id == "match" and not app._pop.reward_presentation_active()
			and not app._round_celebration.is_active(),
			"Switching mode stops the accepted round and its reward animation without replaying celebration")
		check(app._pop_rewards.rewards.entries.size() == (1 if fragments == 4 else 0),
			"Leaving a partial recipe earns nothing while an unlocked chest is durably retained")
		if fragments == 4:
			check(app._pop_rewards.rewards.entries[0].tier == 1,
				"Exiting during assembly preserves the already accepted chest at its actual tier")
			var saved: String = FileAccess.get_file_as_string(app.pop_reward_save_path)
			app.choose_mode("pop")
			check(app._pop_rewards_shown and app._pop.game.phase == "ready"
				and FileAccess.get_file_as_string(app.pop_reward_save_path) == saved,
				"Returning restores the saved final chest without replaying assembly or appending another reward")
		await _dispose(app)


func _save_failure_checks() -> void:
	var app = await _create_app()
	var storage := Storage.new()
	check(app._pop_rewards.connect_storage(storage), "Prepare readable storage that rejects writes")
	await _earn_fragments(app, 4)
	await _finish_pop(app)
	check(not app._pop_reward_saved and app._pop_rewards.snapshot().save_failed
		and storage.text == null, "A failed finish save retains a retryable draft of the earned final chest")
	Fixture.finish_celebration(app)
	var round_id: String = app._pop.game.round_id
	app._pop.replay_button.pressed.emit()
	check(app._pop_rewards_shown and app._pop.game.phase == "finished" and app._pop.game.round_id == round_id,
		"Play again cannot discard a final chest that still needs to be saved")
	app.choose_mode("match")
	check(app._mode_id == "pop" and app._pop_rewards_shown,
		"Switching modes preserves the same unsaved chest and recovery action")
	storage.writable = true
	app._pop_rewards.retry_save()
	check(not app._pop_rewards.snapshot().save_failed and storage.writes == 1
		and app._pop_rewards.rewards.entries.size() == 1 and app._pop_rewards.rewards.entries[0].tier == 1,
		"Retry saves exactly the draft's final tier once")
	app._hide_pop_rewards()
	app._pop.replay_button.pressed.emit()
	check(app._pop.game.phase == "ready" and not app._pop_rewards_shown and storage.writes == 1,
		"After durable recovery replay proceeds without duplicating or losing the unopened chest")
	await _dispose(app)


func _pending_treasure_reload_checks() -> void:
	var directory: String = "user://pop-pending-reload-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var saved_entries: Array = []
	var saved_text: String = ""
	for reload_index in range(2):
		var app = load("res://scenes/main.tscn").instantiate()
		app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
		Fixture.install(app, directory)
		root.add_child(app)
		app.audio.muted = true
		await process_frame
		await process_frame
		app.choose_mode("pop")
		await process_frame
		await process_frame
		if reload_index == 0:
			var room = app._pop_rewards
			check(room.configure("pending-reload-batch", 3, "spring", app.data.chests, true),
				"Create an isolated saved three-chest batch for restoration")
			app._show_pop_rewards()
			room.set_reduced_motion(true)
			room.set_process(false)
			room.begin_hold(room._cards[0].button)
			room.advance_hold(Feel.HOLD_SECONDS)
			check(room.snapshot().opened_count == 1 and room.snapshot().pending,
				"A real hold saves one opened chest and leaves two pending before navigation")
			saved_entries = room.rewards.entries.duplicate(true)
			saved_text = FileAccess.get_file_as_string(app.pop_reward_save_path)
			app.choose_mode("match")
			check(app._mode_id == "match" and not app._pop_rewards.visible,
				"Switching to Match leaves the partial Pop reward batch available")
			app.choose_mode("pop")
			await process_frame
			await process_frame
		_check_restored_pending_room(app, saved_entries, saved_text,
			"switching back to Pop" if reload_index == 0 else "recreating GameUI from the same saved files")
		app.audio.halt()
		app.queue_free()
		await process_frame
		await process_frame


func _check_restored_pending_room(app, saved_entries: Array, saved_text: String, context: String) -> void:
	var room = app._pop_rewards
	var state: Dictionary = room.snapshot()
	check(app._pop_rewards_shown and room.is_visible_in_tree() and not app._pop.visible and not state.paused,
		"Pending treasure appears before a new Pop round after " + context)
	check(state.round_id == "pending-reload-batch" and state.chest_count == 3 and state.opened_count == 1
		and state.pending and room.rewards.entries == saved_entries,
		"The exact chest styles and one-opened/two-pending state survive " + context)
	check(app._pop.game.phase == "ready" and not app._pop_speech_active
		and not app._pop._listening and not app._pop._enabled,
		"Restoring pending treasure does not enter the microphone flow after " + context)
	check(FileAccess.get_file_as_string(app.pop_reward_save_path) == saved_text,
		"Restoring pending treasure neither rerolls nor rewrites its durable batch after " + context)

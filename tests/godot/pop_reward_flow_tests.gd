extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const ChestCelebration = preload("res://scripts/jelly_chest_celebration.gd")

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

class VocabularyDownload extends RefCounted:
	var requests: Array[int] = []
	var callbacks: Dictionary = {}

	func requestVocabulary(age: int, callback: Callable) -> void:
		requests.append(age)
		callbacks[age] = callback

	func reply(age: int, state: String) -> void:
		callbacks[age].call([JSON.stringify({"age": age, "state": state,
			"progress": 1.0 if state == "ready" else 0.0,
			"path": "/vocabulary-%d-0123456789abcdef.pck" % age,
			"error": "The connection was interrupted." if state == "failed" else ""})])

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
	await _delayed_replay_checks()
	await _pending_treasure_reload_checks()
	print("Pop reward flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _create_app():
	var directory: String = "user://pop-reward-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	Fixture.install(app, directory)
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	app.audio.muted = true
	await process_frame
	await process_frame
	Fixture.enter_mode(app, "pop")
	Fixture.choose_pop_player(app)
	app._pop.set_listening(true, true, "Listening.")
	app._pop_speech_active = true
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
			check(app._pop.game.phase == "running" and app._pop._listening and app._pop_speech_active,
				"Chest assembly and upgrade keep the microphone session and round running")
			var remaining: float = app._pop.game.remaining
			app._pop._advance_game(0.1)
			check(is_equal_approx(app._pop.game.remaining, remaining - 0.1), "The round clock advances during the chest presentation")
			if not finish_presentation:
				return
			app._pop.advance_reward_presentation(ChestCelebration.ARRIVAL_SECONDS + ChestCelebration.PERFORMANCE_SECONDS + 0.01)
			check(not app._pop.reward_presentation_active() and app._pop._listening and app._pop_speech_active,
				"The chest milestone completes without restarting live speech")
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
		check(app._settlement_dialog.is_visible_in_tree() and app._pop_rewards._cards.is_empty(),
			"Zero-chest rounds settle in a compact dialog without an invented chest")
		app._pop_rewards._back.pressed.emit()
		check(app._pop.game.phase == "ready" and app._pop.game.fragment_count == 0,
			"Replay resets a partial recipe and waits for live microphone permission")
		await _dispose(app)
		return
	check(app._pop_rewards.has_pending() and FileAccess.file_exists(app.pop_reward_save_path),
		"Finished-round treasure is saved before the result action")
	var saved_entries: Array = app._pop_rewards.rewards.entries.duplicate(true)
	check(saved_entries.size() == 1 and saved_entries[0].tier == tier,
		"The durable round batch contains its final tier and no intermediate chest")
	check(app._round_celebration.is_active() and app._pop.visible
		and app._settlement_dialog.is_visible_in_tree() and not app._pop_rewards_shown
		and app._pop_rewards.snapshot().paused,
		"The saved reward begins Pip's shared entrance over the frozen Pop board")
	Fixture.finish_celebration(app)
	check(not app._round_celebration.is_active() and app._pop_rewards_shown,
		"The finished entrance hands the same saved reward to the interactive room")
	if fragments == 9:
		var first_id: String = app._pop.game.round_id
		app._pop_rewards._back.pressed.emit()
		saved_entries[0].opened = true
		var replayed: bool = app._pop.game.phase == "ready" and app._pop.game.round_id != first_id \
			and not app._pop_rewards_shown and app._pop_rewards.rewards.entries == saved_entries \
			and app.coin_wallet.balance == 100
		check(replayed,
			"Play again starts a fresh round after saving the previous final chest's coins")
		if not replayed:
			await _dispose(app)
			return
		app._pop.set_listening(true, true, "Listening.")
		app._pop_speech_active = true
		app._pop.set_process(false)
		await _earn_fragments(app, 4)
		await _finish_pop(app)
		check(app._round_result.chest_count == 1 and app._round_result.chest_tier == 1
			and app._pop_rewards.rewards.entries.size() == 1
			and app._pop_rewards.rewards.entries[0].tier == 1 and app.coin_wallet.balance == 100,
			"A second completed round adds its final chest while retaining the prior chest's saved coins")
		Fixture.finish_celebration(app)
		var durable: String = FileAccess.get_file_as_string(app.pop_reward_save_path)
		app._pop_finished(app._round_result.duplicate(true))
		check(FileAccess.get_file_as_string(app.pop_reward_save_path) == durable,
			"Repeated completion cannot duplicate the newly saved chest")
	await process_frame
	await process_frame
	var room = app._pop_rewards
	room.set_process(false)
	check(app._pop_rewards_shown and room.visible and app._pop.visible
		and app._settlement_dialog.is_visible_in_tree(), "The result opens treasure inside the shared settlement dialog")
	check(room.snapshot().chest_count == 1,
		"The opening page includes the current final chest without resurrecting a claimed prior reward")
	if room._cards.size() != 1:
		check(false, "The reward dialog presents one earned chest at a time")
		await _dispose(app)
		return
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
		room.set_page(0)
		room.begin_hold(room._cards[0].button)
		room.advance_hold(0.4)
		app._show_collection()
		check(room.snapshot().paused and not room.snapshot().holding and room.snapshot().opened_count == 1,
			"The growth catalog cancels an unfinished chest gesture")
		app._hide_collection()
		check(not room.snapshot().paused, "Closing the growth catalog restores unopened reward controls")
		app.set_reduced_motion(true)
		room.set_page(0)
		room.begin_hold(room._cards[0].button)
		room.advance_hold(Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == room.snapshot().chest_count and not room.has_pending(),
		"Each final chest opens once without generating its earlier upgrade tiers")
	app._pop_rewards._back.pressed.emit()
	app._start_pop_listening()
	check(app._pop.game.phase == "ready" and not app._pop_rewards_shown,
		"After opening every chest a fresh round waits for microphone permission")
	check(app._pop.game.chest_count == 0, "The next round does not inherit the previous reward count")
	await _dispose(app)


func _early_exit_checks() -> void:
	for fragments in [3, 4]:
		var app = await _create_app()
		await _earn_fragments(app, fragments, false)
		check(app._pop.game.phase == "running",
			"Prepare a live round exit during a partial recipe or active chest assembly")
		Fixture.enter_mode(app, "match")
		check(app._mode_id == "match" and not app._pop.reward_presentation_active()
			and not app._round_celebration.is_active(),
			"Switching mode stops the accepted round and its reward animation without replaying celebration")
		check(app._pop_rewards.rewards.entries.size() == (1 if fragments == 4 else 0),
			"Leaving a partial recipe earns nothing while an unlocked chest is durably retained")
		if fragments == 4:
			check(app._pop_rewards.rewards.entries[0].tier == 1,
				"Exiting during assembly preserves the already accepted chest at its actual tier")
			var saved: String = FileAccess.get_file_as_string(app.pop_reward_save_path)
			Fixture.enter_mode(app, "pop")
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
		and storage.text == null and not app._round_celebration.is_active() and app._pop_rewards_shown,
		"A failed finish save immediately exposes recovery for the earned final chest")
	Fixture.finish_celebration(app)
	var round_id: String = app._pop.game.round_id
	app._pop_rewards._back.pressed.emit()
	check(app._pop_rewards_shown and app._pop.game.phase == "finished" and app._pop.game.round_id == round_id,
		"Play again cannot discard a final chest that still needs to be saved")
	Fixture.enter_mode(app, "match")
	check(app._mode_id == "pop" and app._pop_rewards_shown,
		"Switching modes preserves the same unsaved chest and recovery action")
	storage.writable = true
	app._pop_rewards.retry_save()
	check(not app._pop_rewards.snapshot().save_failed and storage.writes == 1 and not app._round_celebration.is_active()
		and app._pop_rewards.rewards.entries.size() == 1 and app._pop_rewards.rewards.entries[0].tier == 1,
		"Retry saves exactly the draft's final tier once")
	app._pop_rewards._back.pressed.emit()
	check(app._pop.game.phase == "ready" and not app._pop_rewards_shown and storage.writes == 2
		and not app._pop_rewards.has_pending() and app.coin_wallet.balance == 50,
		"After durable recovery replay saves its chest consumption and credits exactly one reward")
	await _dispose(app)


func _delayed_replay_checks() -> void:
	var app = await _create_app()
	await _earn_fragments(app, 4)
	await _finish_pop(app)
	Fixture.finish_celebration(app)
	var saved_entries: Array = app._pop_rewards.rewards.entries.duplicate(true)
	var previous_round: String = app._pop.game.round_id
	var age: int = app.growth.learning_age()
	var download := VocabularyDownload.new()
	app.vocabulary_loader.configure(download, func(_path: String, replace: bool) -> bool: return not replace)
	app._pop_rewards._back.pressed.emit()
	saved_entries[0].opened = true
	var saved_text: String = FileAccess.get_file_as_string(app.pop_reward_save_path)
	var waiting: bool = download.requests == [age] and app._vocabulary_prompt.visible \
		and app._pop.game.round_id == previous_round and app._pop_rewards.rewards.entries == saved_entries \
		and app.coin_wallet.balance == 50
	check(waiting, "Replay settles earned treasure before waiting for required vocabulary")
	if not waiting:
		app._cancel_vocabulary_round()
		await _dispose(app)
		return
	download.reply(age, "failed")
	check(app._vocabulary_retry.visible and app._pop.game.round_id == previous_round,
		"A failed replay download retains the finished round and exposes Retry")
	app._vocabulary_retry.pressed.emit()
	check(download.requests == [age, age], "Replay retries only its required vocabulary age")
	download.reply(age, "ready")
	for frame in range(6):
		await process_frame
	check(app._pop.game.phase == "ready" and app._pop.game.round_id != previous_round
		and app._pop.is_visible_in_tree() and not app._pop_rewards_shown and not app._vocabulary_prompt.visible
		and app._pending_vocabulary_round.is_empty(),
		"A retried download resumes the requested fresh Pop replay without opening the treasure room")
	check(not app._pop_speech_active and not app._pop._listening,
		"Completing a replay download does not start a microphone session without a new gesture")
	check(app._pop_rewards.rewards.entries == saved_entries
		and FileAccess.get_file_as_string(app.pop_reward_save_path) == saved_text,
		"Delayed replay preserves the exact opened reward receipt and durable save")
	Fixture.enter_mode(app, "match")
	Fixture.enter_mode(app, "pop")
	check(not app._pop_rewards_shown and app._pop.is_visible_in_tree()
		and app._pop_rewards.rewards.entries == saved_entries and app.coin_wallet.balance == 50
		and FileAccess.get_file_as_string(app.pop_reward_save_path) == saved_text,
		"Returning through Home keeps settled treasure claimed after a delayed replay")
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
		app._presentation.path = directory + "/presentation.cfg"
		root.add_child(app)
		app.audio.muted = true
		await process_frame
		await process_frame
		Fixture.enter_mode(app, "pop")
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
			Fixture.enter_mode(app, "match")
			check(app._mode_id == "match" and not app._pop_rewards.visible,
				"Switching to Match leaves the partial Pop reward batch available")
			Fixture.enter_mode(app, "pop")
			await process_frame
			await process_frame
		_check_restored_pending_room(app, saved_entries, saved_text,
			"switching back to Pop" if reload_index == 0 else "recreating GameUI from the same saved files")
		if reload_index == 1:
			_check_claimed_restored_room_exit(app)
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


func _check_claimed_restored_room_exit(app) -> void:
	var room = app._pop_rewards
	room.set_reduced_motion(true)
	room.set_process(false)
	for card in room._cards:
		if card.opened:
			continue
		room.begin_hold(card.button)
		room.advance_hold(Feel.HOLD_SECONDS)
	check(not room.has_pending() and room.snapshot().opened_count == 3,
		"The restored batch can be fully claimed before starting the next microphone session")
	var ready_round: String = app._pop.game.round_id
	var wallet: int = app.coin_wallet.balance
	var saved: String = FileAccess.get_file_as_string(app.pop_reward_save_path)
	room._back.pressed.emit()
	check(not app._pop_rewards_shown and not app._settlement_dialog_open() and not app._mode_menu_open()
		and app._pop.is_visible_in_tree() and app._pop.game.phase == "ready"
		and app._pop.game.round_id == ready_round and app._pop.retry_button.is_visible_in_tree()
		and not app._pop.retry_button.disabled,
		"Back from fully claimed restored treasure exposes the existing ready microphone gate")
	check(not app._pop_speech_active and not app._pop._listening and not app._pop._enabled,
		"Leaving restored treasure waits for an explicit microphone gesture")
	check(app.coin_wallet.balance == wallet and FileAccess.get_file_as_string(app.pop_reward_save_path) == saved,
		"Returning to the gate cannot credit or rewrite an already opened chest")
	app._show_mode_menu()
	app.choose_mode("pop")
	check(not app._pop_rewards_shown and app._pop.retry_button.is_visible_in_tree()
		and app._pop.game.round_id == ready_round,
		"Re-entering the same Pop mode cannot reopen the consumed treasure batch")

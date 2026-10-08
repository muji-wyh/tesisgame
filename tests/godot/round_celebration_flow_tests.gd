extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Feel = preload("res://scripts/chest_feel.gd")

class StopFailureApp:
	extends "res://scripts/game_ui.gd"
	var refuse_microphone_stop: bool = false

	func _stop_pop_listening() -> bool:
		if refuse_microphone_stop:
			return false
		return super._stop_pop_listening()

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func pieces(app) -> int:
	var total: int = 0
	for count in app.medal_progress.counts.values():
		total += int(count)
	return total


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var directory := "user://round-celebration-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Celebration flow uses isolated durable state")
	var app = load("res://scenes/main.tscn").instantiate()
	# Keep the real main scene and superclass behavior; only the unavailable
	# native microphone failure is injected at its existing boundary.
	app.set_script(StopFailureApp)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	app._presentation.path = directory + "/presentation.cfg"
	Fixture.install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	for mode in ["match", "memory", "phrase"]:
		await check_manual_mode(app, mode)
	await check_voice_gate(app)
	await check_interruption_and_replacement(app)
	await check_exit_settlement(app)
	for chest_count in range(4):
		await check_pop_result(app, chest_count)
	await check_removed_pop_player(app)
	app.audio.halt()
	app.queue_free()
	await settle()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Round celebration flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func start_manual(app, mode: String) -> void:
	check(app.new_round(713, false, "", mode), "A fresh " + mode + " round starts")
	await settle()
	if mode == "match":
		var words: Array = app.model.lesson_words.duplicate(true)
		for word in words:
			app.cards[str(word.id) + ":word"].pressed.emit()
			app.cards[str(word.id) + ":image"].pressed.emit()
			app._continue_match()
	elif mode == "memory":
		var view = app._memory
		var completed: Dictionary = {}
		for card in view.memory.cards:
			if completed.has(card.word.id):
				continue
			completed[card.word.id] = true
			for index in range(view.memory.cards.size()):
				if view.memory.cards[index].word.id == card.word.id:
					view.card_buttons[index].pressed.emit()
			view.continue_feedback()
	else:
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
	app._round_celebration.set_process(false)
	check(app._round_celebration.snapshot().active, mode + " reaches the shared performance through real game controls")


func check_manual_mode(app, mode: String) -> void:
	var before: int = pieces(app)
	await start_manual(app, mode)
	var view = app._round_celebration
	var identity: String = view.snapshot().round_id
	var prior_controller_mode: bool = app._controller_mode
	app._controller_mode = true
	root.gui_release_focus()
	app._refresh_controller_focus()
	check(app._valid_focus(root.gui_get_focus_owner()) and root.gui_get_focus_owner() != app.chest_button,
		mode + " controller refresh chooses a visible allowed control during the performance")
	check(view.is_visible_in_tree() and view.snapshot().chest_count == 1 and not view.snapshot().automatic,
		mode + " presents one earned chest through the shared manual invitation")
	check(not app.chest_button.is_visible_in_tree() and not view.snapshot().ready,
		mode + " keeps the unopened-chest page and invitation action unavailable during performance")
	for attempt in range(3):
		view.action_button.pressed.emit()
		app.chest_button.button_down.emit()
		app._accept_round_chest(identity)
		root.gui_release_focus()
		app._controller_accept()
		app._phrase.finished.emit()
	check(pieces(app) == before and not app._holding_chest and app.model.chest_state == "closed",
		mode + " rejects repeated early actions without starting or awarding the chest")
	view.advance(2.99)
	check(not view.snapshot().ready and view.snapshot().active and pieces(app) == before,
		mode + " preserves the full three-second performance gate")
	view.advance(0.02)
	check(view.snapshot().ready and not view.action_button.disabled and view.action_button.is_visible_in_tree(),
		mode + " exposes Open chest after the performance")
	root.gui_release_focus()
	app._refresh_controller_focus()
	check(root.gui_get_focus_owner() == view.action_button and app._valid_focus(view.action_button),
		mode + " controller refresh targets the ready invitation instead of the hidden chest")
	check(view.snapshot().round_id == identity and pieces(app) == before,
		mode + " finishing the performance retains the same unclaimed round")
	view.advance(5.0)
	check(view.snapshot().ready and not app.chest_button.is_visible_in_tree(),
		mode + " waits indefinitely for the learner's explicit invitation click")
	view.action_button.pressed.emit()
	check(not view.snapshot().active and app.model.phase == "won" and app.chest_button.is_visible_in_tree()
		and app.model.chest_state == "closed" and pieces(app) == before,
		mode + " accepts the invitation into the unopened chest without awarding it")
	if mode == "phrase":
		check(app._phrase.game.phase == "finished" and not app._phrase.completion_pending,
			"Phrase becomes finished only after the accepted shared invitation")
	app.set_reduced_motion(true)
	app.chest_button.button_down.emit()
	app._advance_ui(Feel.HOLD_SECONDS)
	check(app.model.chest_state == "opened" and pieces(app) == before + 1,
		mode + " preserves the existing hold-to-open reward commitment")
	view.open_requested.emit(identity)
	view.performance_finished.emit(identity)
	app.chest.opened.emit()
	check(pieces(app) == before + 1 and app.model.chest_state == "opened",
		mode + " ignores duplicate performance, invitation, and chest completion callbacks")
	app.set_reduced_motion(false)
	app._controller_mode = prior_controller_mode


func check_voice_gate(app) -> void:
	await start_manual(app, "phrase")
	var view = app._round_celebration
	app.set_process(false)
	view.set_narration_playing(true)
	view.advance(3.1)
	check(view.snapshot().active and not view.snapshot().ready and app._phrase.completion_pending
		and app._phrase.game.phase == "correct" and app.model.phase != "won",
		"A long final phrase remains pending after the animation deadline")
	view.action_button.pressed.emit()
	check(app._phrase.game.phase == "correct", "A long final phrase cannot be skipped by an early invitation callback")
	view.set_narration_playing(false)
	check(view.snapshot().ready, "The final phrase ending releases the completed performance gate")
	app.set_process(true)


func cover(app, kind: String, enabled: bool) -> void:
	if kind == "menu":
		if enabled:
			app._mode_heading_button.pressed.emit()
		else:
			app._mode_panel.close_button.pressed.emit()
	elif kind == "room":
		if enabled:
			app.collection_button.pressed.emit()
		else:
			app._collection_back.pressed.emit()
	elif enabled:
		app.on_page_hidden()
	else:
		app.on_page_visible()
	await settle()


func check_interruption_and_replacement(app) -> void:
	for kind in ["menu", "room", "background"]:
		await start_manual(app, "phrase")
		var view = app._round_celebration
		var identity: String = view.snapshot().round_id
		view.advance(1.0)
		await cover(app, kind, true)
		view.advance(4.0)
		view.action_button.pressed.emit()
		check(view.snapshot().paused and not view.snapshot().ready and app._phrase.completion_pending,
			kind + " suspends a pending performance and rejects stale input")
		await cover(app, kind, false)
		view.set_process(false)
		check(not view.snapshot().paused and view.snapshot().elapsed < 0.3 and view.snapshot().round_id == identity,
			kind + " resumes the same earned round with a fresh complete performance")
		view.advance(3.1)
		check(view.snapshot().ready, kind + " eventually returns to the explicit invitation")
		await cover(app, kind, true)
		view.action_button.pressed.emit()
		await cover(app, kind, false)
		view.set_process(false)
		check(view.snapshot().ready and view.snapshot().round_id == identity and app._phrase.game.phase == "correct",
			kind + " restores a ready invitation without replaying or entering the chest")
	var old_id: String = app._round_celebration.snapshot().round_id
	var before: int = pieces(app)
	check(app.new_round(991, false, "", "phrase"), "A replacement game can leave an unaccepted Phrase invitation")
	app._round_celebration.open_requested.emit(old_id)
	app._round_celebration.performance_finished.emit(old_id)
	app._round_celebration.cue_requested.emit(old_id, "reward")
	check(not app._round_celebration.snapshot().active and app._phrase.game.completed == 0
		and app.model.phase != "won" and pieces(app) == before,
		"Late callbacks for the previous ID cannot alter, reward, or restart the new round")


func check_exit_settlement(app) -> void:
	for mode in ["match", "memory"]:
		var before: int = pieces(app)
		await start_manual(app, mode)
		check(app.new_round(412, false, "", "phrase"), "Leaving an already won " + mode + " round starts the requested game")
		check(pieces(app) == before + 1 and not app._round_celebration.snapshot().active,
			"Leaving " + mode + " preserves existing win settlement exactly once")


func check_pop_result(app, chest_count: int) -> void:
	check(app.new_round(820 + chest_count, false, "", "pop"), "A Pop score fixture starts cleanly")
	Fixture.choose_pop_player(app)
	app._pop.set_listening(true, true, "Listening.")
	app._pop.set_process(false)
	var iterations: int = 0
	while app._pop.game.chest_count < chest_count and iterations < 60:
		iterations += 1
		if app._pop.game.targets.is_empty():
			app._pop._advance_game(0.66)
		if not app._pop.game.targets.is_empty():
			app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
	check(app._pop.game.chest_count == chest_count, "Real recognized targets produce exactly %d Pop chests" % chest_count)
	app._pop._advance_game(app._pop.game.remaining + 1.0)
	app._round_celebration.set_process(false)
	var summary: Dictionary = app._pop.game.summary().duplicate(true)
	var saved_result: Dictionary = app._leaderboard_result.duplicate(true)
	check(app._pop.game.phase == "finished" and int(saved_result.chest_count) == chest_count,
		"Pop finishes and persists its actual %d-chest score before celebration" % chest_count)
	if chest_count == 0:
		check(not app._round_celebration.snapshot().active and app._pop.is_visible_in_tree(),
			"A zero-chest Pop result skips celebration and immediately presents the complete result")
		return
	var view = app._round_celebration
	check(view.snapshot().active and view.snapshot().automatic and view.snapshot().chest_count == chest_count
		and not app._pop.is_visible_in_tree() and app._pop_rewards.has_pending(),
		"A %d-chest Pop performance covers the saved result and accurately identifies the reward" % chest_count)
	var identity: String = view.snapshot().round_id
	if chest_count == 1:
		app.refuse_microphone_stop = true
		check(not app.new_round(995, false, "", "match") and view.is_active() and view.is_visible_in_tree()
			and view.current_round_id() == identity and app._mode_id == "pop" and app._pop.game.summary() == summary,
			"A refused microphone shutdown cancels the mode change without discarding its existing celebration")
		app.refuse_microphone_stop = false
		var earned_theme: String = app._pop_rewards._draft_themes[0]
		var saved_batch: String = FileAccess.get_file_as_string(app.pop_reward_save_path)
		view.advance(0.7)
		await cover(app, "room", true)
		app.choose_theme("ocean" if earned_theme != "ocean" else "spring")
		await cover(app, "room", false)
		view.set_process(false)
		check(app.model.theme_id != earned_theme and view.chest.theme_id == earned_theme
			and app._pop_rewards._draft_themes[0] == earned_theme,
			"Changing the room world keeps Pop's preview aligned with its already earned first chest")
		check(FileAccess.get_file_as_string(app.pop_reward_save_path) == saved_batch,
			"Changing the presentation world never rewrites the fixed Pop reward batch")
	app._pop.chests_button.pressed.emit()
	app._pop.replay_button.pressed.emit()
	app._pop_finished(summary)
	check(not app._pop_rewards_shown and view.snapshot().round_id == identity and view.snapshot().elapsed < 0.3,
		"Covered Pop actions and duplicate completion cannot open rewards or replace the performance")
	view.advance(3.1)
	check(not view.snapshot().active and app._pop.is_visible_in_tree() and not app._pop_rewards_shown,
		"Pop automatically returns to its full result after the shared performance")
	check(app._pop.game.summary() == summary and app._leaderboard_result == saved_result
		and app._pop._review_buttons.size() == summary.hit_words.size() + summary.missed_words.size(),
		"Pop preserves score, word review, and its saved leaderboard result across the performance")
	view.performance_finished.emit(identity)
	view.open_requested.emit(identity)
	check(app._pop.is_visible_in_tree() and not app._pop_rewards_shown and app._leaderboard_result == saved_result,
		"Late automatic-performance events cannot bypass the original Pop result action")
	app._pop.chests_button.pressed.emit()
	check(app._pop_rewards_shown and app._pop_rewards.snapshot().chest_count == chest_count,
		"The original Pop result action still opens exactly %d saved chests" % chest_count)
	app.set_reduced_motion(true)
	for entry in app._pop_rewards._cards:
		app._pop_rewards.begin_hold(entry.button)
		app._pop_rewards.advance_hold(Feel.HOLD_SECONDS)
	check(app._pop_rewards.snapshot().opened_count == chest_count and not app._pop_rewards.has_pending(),
		"The saved Pop batch is opened once before starting the next score fixture")
	app._hide_pop_rewards()
	app.set_reduced_motion(false)


func check_removed_pop_player(app) -> void:
	check(app.leaderboard_state.create_profile("Remaining player", "cat").ok,
		"Player-removal coverage keeps a surviving profile")
	check(app.new_round(907, false, "", "pop"), "A removable player's earned Pop round starts")
	Fixture.choose_pop_player(app)
	app._pop.set_listening(true, true, "Listening.")
	app._pop.set_process(false)
	for attempt in range(8):
		if app._pop.game.chest_count > 0:
			break
		if app._pop.game.targets.is_empty():
			app._pop._advance_game(0.66)
		if not app._pop.game.targets.is_empty():
			app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
	app._pop._advance_game(app._pop.game.remaining + 1.0)
	var view = app._round_celebration
	view.set_process(false)
	check(view.is_active() and app._pop.game.chest_count == 1,
		"The removable player reaches an actual earned-chest performance")
	var old_id: String = view.current_round_id()
	var player_id: String = app._pop_player_id
	var saved_batch: String = FileAccess.get_file_as_string(app.pop_reward_save_path)
	view.advance(0.6)
	app._show_collection()
	var players := app.find_child("MenuPlayers", true, false) as Button
	check(players != null, "Pip's room exposes player management during a performance")
	if players == null:
		return
	players.pressed.emit()
	await settle()
	var remove := app._leaderboard_panel.find_child("LeaderboardRemove_" + player_id, true, false) as Button
	check(remove != null, "The active Pop player has an explicit removal action")
	if remove == null:
		return
	remove.pressed.emit()
	var confirm := app._leaderboard_panel.find_child("LeaderboardConfirmRemove", true, false) as Button
	check(confirm != null, "Player removal requires its existing confirmation")
	if confirm == null:
		return
	confirm.pressed.emit()
	await settle()
	check(not view.is_active() and app._leaderboard_round_id != old_id and app._pop_player_id.is_empty()
		and app._pop.game.phase == "ready",
		"Deleting the celebrating player cancels the old presenter and resets the Pop round identity")
	app._controller_back()
	if app.collection_page.visible:
		app._hide_collection()
	await settle()
	var replacement_id: String = app._leaderboard_round_id
	view.open_requested.emit(old_id)
	view.performance_finished.emit(old_id)
	view.cue_requested.emit(old_id, "reward")
	check(app._pop.is_visible_in_tree() and not view.is_active() and app._pop.game.phase == "ready"
		and app._leaderboard_round_id == replacement_id,
		"Returning from player management reveals the new Pop view and ignores the old finale callbacks")
	check(FileAccess.get_file_as_string(app.pop_reward_save_path) == saved_batch,
		"Removing a player preserves the shared treasure that was saved before celebration")

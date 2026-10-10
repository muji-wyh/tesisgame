extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const MatchModel = preload("res://scripts/game_model.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")

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


func check_fullscreen_confetti(view, context: String) -> void:
	var state: Dictionary = view.snapshot()
	check(bool(state.get("confetti", false)), context + " shows confetti at the earned chest reveal")
	var bounds: Array = state.get("confetti_rect", [])
	var screen: Rect2 = root.get_visible_rect()
	check(bounds.size() == 4 and Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3])).is_equal_approx(screen),
		context + " spreads confetti across the entire viewport, including the header")


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
	app._presentation.path = directory + "/presentation.cfg"
	Fixture.install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	for mode in ["match", "memory", "phrase"]:
		await check_manual_mode(app, mode)
	for mode in ["match", "memory"]:
		await check_no_chest_mode(app, mode)
	await check_voice_gate(app)
	await check_interruption_and_replacement(app)
	await check_exit_settlement(app)
	for fragments in [0, 3, 4, 9, 14]:
		await check_pop_result(app, fragments)
	app.audio.halt()
	app.queue_free()
	await settle()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Round celebration flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func reward_seed(app, earned: bool) -> int:
	var probe := MatchModel.new()
	for seed_value in range(128):
		if probe.reset(app._learning_words(), seed_value, false, "", "", str(app.growth.learning_age()), true) \
			and (probe.chest_reward_pair > 0) == earned:
			return seed_value
	check(false, "The deterministic reward fixtures include both chance outcomes")
	return 0


func reset_pair_fixture(app) -> void:
	# Complete the ordinary mode exit before isolating the next seeded policy.
	# Otherwise an unfinished reservation intentionally survives the new seed.
	check(app.new_round(713, false, "", "phrase"), "A pair fixture leaves its prior round through the normal mode route")
	var before: Dictionary = app.medal_progress.counts.duplicate(true)
	var config := ConfigFile.new()
	check(config.load(app.medal_progress._save_path) == OK, "The isolated pair fixture reads its current medal save")
	if config.has_section("pair_chests"):
		config.erase_section("pair_chests")
	check(config.save(app.medal_progress._save_path) == OK and app.medal_progress.load_progress(),
		"The seeded fixture clears only pair reservations and pity history")
	check(app.medal_progress.counts == before, "Isolating a pair fixture preserves every previously earned medal piece")


func check_pair_reveal(app, mode: String, already_checked: bool) -> bool:
	if already_checked or not app.model.chest_earned:
		return already_checked
	var view = app._pair_reward
	view.advance(view.REVEAL_SECONDS + 0.01)
	var state: Dictionary = view.snapshot()
	check(state.earned and state.performance_active and state.confetti_visible,
		mode + " reveals its earned chest and confetti on the actual successful pair")
	var screen: Rect2 = view._confetti.get_global_transform_with_canvas() * view._confetti.screen_rect()
	check(screen.is_equal_approx(root.get_visible_rect()),
		mode + " pair reward confetti reaches the entire viewport")
	check(not app._round_celebration_active() and not app.chest_button.is_visible_in_tree()
		and (app._match_playfield.is_visible_in_tree() if mode == "match" else app._memory.is_visible_in_tree()),
		mode + " keeps the live board visible while its nonmodal chest reveal plays")
	check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.focus_mode == Control.FOCUS_NONE,
		mode + " chest feedback cannot capture a card press or controller focus")
	return true


func start_manual(app, mode: String, earned: bool = true) -> void:
	if mode in ["match", "memory"]:
		reset_pair_fixture(app)
	var seed_value: int = reward_seed(app, earned) if mode in ["match", "memory"] else 713
	check(app.new_round(seed_value, false, "", mode), "A fresh " + mode + " round starts")
	if mode in ["match", "memory"]:
		check(not app.model.chest_earned and (app.model.chest_reward_pair > 0) == earned,
			mode + " reserves its seeded chance without awarding a chest at round creation")
	else:
		check(app.model.chest_earned == earned, mode + " retains its guaranteed completion reward")
	await settle()
	var pair_reveal_checked: bool = false
	if mode == "match":
		var words: Array = app.model.lesson_words.duplicate(true)
		for word in words:
			app.cards[str(word.id) + ":word"].pressed.emit()
			app.cards[str(word.id) + ":image"].pressed.emit()
			pair_reveal_checked = check_pair_reveal(app, mode, pair_reveal_checked)
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
			pair_reveal_checked = check_pair_reveal(app, mode, pair_reveal_checked)
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
	if mode in ["match", "memory"]:
		check(app.model.chest_earned == earned and pair_reveal_checked == earned,
			mode + " completes all five real pairs with exactly its planned reward outcome")
		# The final pair's inline effect completes before the separate round finale.
		app._pair_reward.advance(3.0)
		app._refresh()
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
	check(not view.snapshot().confetti, mode + " begins its round finale without an early confetti burst")
	for attempt in range(3):
		view.action_button.pressed.emit()
		app.chest_button.button_down.emit()
		app._accept_round_chest(identity)
		root.gui_release_focus()
		app._controller_accept()
		app._phrase.finished.emit()
	check(pieces(app) == before and not app._holding_chest and app.model.chest_state == "closed",
		mode + " rejects repeated early actions without starting or awarding the chest")
	view.advance(1.9)
	if mode in ["match", "memory"]:
		check(view.snapshot().get("chest_announced", false) and not view.snapshot().confetti
			and not view.snapshot().cue_log.has("reward"),
			mode + " keeps the earned chest invitation without replaying its already seen reward burst or cue")
	else:
		check_fullscreen_confetti(view, mode)
	check(pieces(app) == before and not view.snapshot().ready,
		mode + " keeps the reward and invitation gates unchanged during the finale")
	view.advance(maxf(0.0, 2.99 - float(view.snapshot().elapsed)))
	check(not view.snapshot().ready and view.snapshot().active and pieces(app) == before,
		mode + " preserves the full three-second performance gate")
	view.advance(0.02)
	check(view.snapshot().ready and not view.action_button.disabled and view.action_button.is_visible_in_tree()
		and not view.snapshot().confetti,
		mode + " exposes Open chest after the performance")
	root.gui_release_focus()
	app._refresh_controller_focus()
	check(root.gui_get_focus_owner() == view.action_button and app._valid_focus(view.action_button),
		mode + " controller refresh targets the ready invitation instead of the hidden chest")
	check(view.snapshot().round_id == identity and pieces(app) == before,
		mode + " finishing the performance retains the same unclaimed round")
	await cover(app, "menu", true)
	await cover(app, "menu", false)
	view.set_process(false)
	check(view.snapshot().ready and view.snapshot().round_id == identity and app.model.chest_earned
		and pieces(app) == before, mode + " keeps its earned reward through a menu visit without rerolling")
	view.advance(5.0)
	check(view.snapshot().ready and not app.chest_button.is_visible_in_tree() and not view.snapshot().confetti,
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


func check_no_chest_mode(app, mode: String) -> void:
	var before: int = pieces(app)
	await start_manual(app, mode, false)
	var view = app._round_celebration
	var identity: String = view.snapshot().round_id
	check(app.model.phase == "won" and not app.model.chest_earned and view.snapshot().chest_count == 0
		and not view.snapshot().chest_visible and view.snapshot().caption == "Every word matched!",
		mode + " celebrates its real completed round without claiming an unearned chest")
	check(not app.chest_button.is_visible_in_tree() and not view.action_button.visible,
		mode + " shows neither an unearned chest nor an early replay action")
	app._open_chest()
	app.chest_button.button_down.emit()
	app._accept_round_chest(identity)
	check(pieces(app) == before and not app._holding_chest and app.model.chest_state == "closed",
		mode + " rejects direct and hidden chest actions when no reward was earned")
	for kind in ["menu", "background"]:
		await cover(app, kind, true)
		await cover(app, kind, false)
		view.set_process(false)
		check(not app.model.chest_earned and view.snapshot().round_id == identity and pieces(app) == before,
			mode + " preserves its no-chest result through " + kind)
	view.set_narration_playing(true)
	view.advance(1.9)
	check(not view.snapshot().confetti, mode + " never throws chest confetti for a zero-chest round")
	view.advance(1.2)
	view.action_button.pressed.emit()
	check(not view.is_ready() and app._round_id == identity and pieces(app) == before,
		mode + " waits for final pronunciation before offering another round")
	view.set_narration_playing(false)
	check(view.is_ready() and view.action_button.text == "Play again" and view.controls() == [view.action_button],
		mode + " offers Play again once the celebration and final word both finish")
	app.growth.ready = false
	view.action_button.pressed.emit()
	check(app._round_id == identity and view.is_ready() and not view.action_button.disabled
		and view.controls() == [view.action_button] and not view.snapshot().open_emitted and pieces(app) == before,
		mode + " keeps Play again usable when unavailable growth storage rejects the new round")
	app.growth.ready = true
	app._growth_save_failed = false
	view.action_button.pressed.emit()
	await settle()
	var next_identity: String = app._round_id
	view.open_requested.emit(identity)
	view.performance_finished.emit(identity)
	app.chest.opened.emit()
	check(next_identity != identity and app._round_id == next_identity and app._mode_id == mode
		and app.model.phase == "waiting" and not view.is_active() and pieces(app) == before,
		mode + " starts a fresh game directly and rejects old actions without manufacturing a reward")


func check_voice_gate(app) -> void:
	await start_manual(app, "phrase")
	var view = app._round_celebration
	app.set_process(false)
	view.set_narration_playing(true)
	view.advance(1.9)
	check_fullscreen_confetti(view, "Long final pronunciation")
	view.advance(1.2)
	check(view.snapshot().active and not view.snapshot().ready and app._phrase.completion_pending
		and app._phrase.game.phase == "correct" and app.model.phase != "won",
		"A long final phrase remains pending after the animation deadline")
	check(not view.snapshot().confetti, "A long final pronunciation does not freeze or loop the confetti")
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
	elif kind == "growth":
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
	for kind in ["menu", "growth", "background"]:
		await start_manual(app, "phrase")
		var view = app._round_celebration
		var identity: String = view.snapshot().round_id
		view.advance(1.9)
		check_fullscreen_confetti(view, kind + " interruption")
		await cover(app, kind, true)
		view.advance(4.0)
		view.action_button.pressed.emit()
		check(view.snapshot().paused and not view.snapshot().ready and app._phrase.completion_pending
			and not view.snapshot().confetti,
			kind + " suspends a pending performance and rejects stale input")
		await cover(app, kind, false)
		view.set_process(false)
		check(not view.snapshot().paused and view.snapshot().elapsed < 0.3 and view.snapshot().round_id == identity
			and not view.snapshot().confetti,
			kind + " resumes the same earned round with a fresh complete performance")
		view.advance(1.9)
		check_fullscreen_confetti(view, kind + " resume")
		view.advance(1.2)
		check(view.snapshot().ready, kind + " eventually returns to the explicit invitation")
		await cover(app, kind, true)
		view.action_button.pressed.emit()
		await cover(app, kind, false)
		view.set_process(false)
		check(view.snapshot().ready and view.snapshot().round_id == identity and app._phrase.game.phase == "correct"
			and not view.snapshot().confetti,
			kind + " restores a ready invitation without replaying or entering the chest")
	var old_id: String = app._round_celebration.snapshot().round_id
	var before: int = pieces(app)
	check(app.new_round(991, false, "", "phrase"), "A replacement game can leave an unaccepted Phrase invitation")
	app._round_celebration.open_requested.emit(old_id)
	app._round_celebration.performance_finished.emit(old_id)
	app._round_celebration.cue_requested.emit(old_id, "reward")
	check(not app._round_celebration.snapshot().active and not app._round_celebration.snapshot().confetti and app._phrase.game.completed == 0
		and app.model.phase != "won" and pieces(app) == before,
		"Late callbacks for the previous ID cannot alter, reward, or restart the new round")


func check_exit_settlement(app) -> void:
	for mode in ["match", "memory"]:
		for earned in [false, true]:
			var before: int = pieces(app)
			await start_manual(app, mode, earned)
			check(app.new_round(412, false, "", "phrase"), "Leaving an already won " + mode + " round starts the requested game")
			check(pieces(app) == before + (1 if earned else 0) and not app._round_celebration.snapshot().active,
				"Leaving " + mode + " settles only the chest that round actually earned")


func check_pop_result(app, fragments: int) -> void:
	var expected: Dictionary = RewardProgress.reward_progress(fragments)
	var chest_count: int = int(expected.chest_count)
	var chest_tier: int = int(expected.chest_tier)
	check(app.new_round(820 + fragments, false, "", "pop"), "A Pop fragment fixture starts cleanly")
	app._start_pop_listening()
	app._pop.set_listening(true, true, "Listening.")
	app._pop_speech_active = true
	app._pop.set_process(false)
	var iterations: int = 0
	while app._pop.game.fragment_count < fragments and iterations < 180 and app._pop.game.phase != "finished":
		iterations += 1
		if app._pop.game.targets.is_empty():
			app._pop._advance_game(0.66)
		if not app._pop.game.targets.is_empty():
			app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
		if app._pop.reward_presentation_active():
			app._pop.advance_reward_presentation(1.5)
			check_fullscreen_confetti(app._pop._reward_presentation, "Pop chest milestone")
			check(app._pop.clip_contents and app._pop_speech_active and app._pop._listening
				and app._pop.game.phase == "running",
				"Pop milestone confetti spans the viewport while gameplay stays clipped and its microphone remains active")
			app._pop.advance_reward_presentation(1.5)
	check(app._pop.game.fragment_count == fragments and app._pop.game.chest_count == chest_count
		and app._pop.game.chest_tier == chest_tier,
		"Real recognized marked targets produce exactly %d fragments and final chest tier %d" % [fragments, chest_tier])
	app._pop._advance_game(app._pop.game.remaining + 1.0)
	app._round_celebration.set_process(false)
	var summary: Dictionary = app._pop.game.summary().duplicate(true)
	check(app.find_child("PlayerAvatar", true, false) == null and app.find_child("PlayerName", true, false) == null,
		"Voice Pop results are available without identity or profile controls")
	var saved_result: Dictionary = app._round_result.duplicate(true)
	check(app._pop.game.phase == "finished" and int(saved_result.chest_count) == chest_count
		and int(saved_result.chest_tier) == chest_tier and int(saved_result.fragment_count) == fragments,
		"Pop retains its actual fragments and one final chest tier before celebration")
	if chest_count == 0:
		check(not app._round_celebration.snapshot().active and not app._round_celebration.snapshot().confetti
			and app._pop.is_visible_in_tree(),
			"A zero-chest Pop result skips celebration and immediately presents the complete result")
		return
	var view = app._round_celebration
	check(view.snapshot().active and view.snapshot().automatic and view.snapshot().chest_count == 1
		and view.snapshot().chest_tier == chest_tier
		and not app._pop.is_visible_in_tree() and app._pop_rewards.has_pending(),
		"The Pop performance presents one final tier-%d chest over the saved result" % chest_tier)
	var identity: String = view.snapshot().round_id
	if chest_tier == 1:
		app.refuse_microphone_stop = true
		check(not app.new_round(995, false, "", "match") and view.is_active() and view.is_visible_in_tree()
			and view.current_round_id() == identity and app._mode_id == "pop" and app._pop.game.summary() == summary,
			"A refused microphone shutdown cancels the mode change without discarding its existing celebration")
		app.refuse_microphone_stop = false
		var earned_theme: String = app._pop_rewards._draft_themes[0]
		var saved_batch: String = FileAccess.get_file_as_string(app.pop_reward_save_path)
		view.advance(0.7)
		await cover(app, "growth", true)
		app.choose_theme("ocean" if earned_theme != "ocean" else "spring")
		await cover(app, "growth", false)
		view.set_process(false)
		check(app.model.theme_id != earned_theme and view.chest.theme_id == earned_theme
			and app._pop_rewards._draft_themes[0] == earned_theme,
			"Changing the selected world keeps Pop's preview aligned with its already earned first chest")
		check(FileAccess.get_file_as_string(app.pop_reward_save_path) == saved_batch,
			"Changing the presentation world never rewrites the fixed Pop reward batch")
	app._pop.chests_button.pressed.emit()
	app._pop.replay_button.pressed.emit()
	app._pop_finished(summary)
	check(not app._pop_rewards_shown and view.snapshot().round_id == identity and view.snapshot().elapsed < 0.3,
		"Covered Pop actions and duplicate completion cannot open rewards or replace the performance")
	view.advance(1.9)
	check_fullscreen_confetti(view, "Pop final tier-%d chest" % chest_tier)
	view.advance(1.2)
	check(not view.snapshot().active and not view.snapshot().confetti and app._pop.is_visible_in_tree() and not app._pop_rewards_shown,
		"Pop automatically returns to its full result after the shared performance")
	check(app._pop.game.summary() == summary and app._round_result == saved_result
		and app._pop._review_buttons.size() == summary.hit_words.size() + summary.missed_words.size(),
		"Pop preserves score, word review, and its saved round result across the performance")
	view.performance_finished.emit(identity)
	view.open_requested.emit(identity)
	check(app._pop.is_visible_in_tree() and not app._pop_rewards_shown and app._round_result == saved_result,
		"Late automatic-performance events cannot bypass the original Pop result action")
	app._pop.chests_button.pressed.emit()
	check(app._pop_rewards_shown and app._pop_rewards.snapshot().chest_count == 1
		and app._pop_rewards._cards.size() == 1 and int(app._pop_rewards._cards[0].tier) == chest_tier,
		"The original Pop result action opens only the saved final-tier chest")
	app.set_reduced_motion(true)
	for entry in app._pop_rewards._cards:
		app._pop_rewards.begin_hold(entry.button)
		app._pop_rewards.advance_hold(Feel.HOLD_SECONDS)
	check(app._pop_rewards.snapshot().opened_count == chest_count and not app._pop_rewards.has_pending(),
		"The saved Pop batch is opened once before starting the next score fixture")
	app._hide_pop_rewards()
	app.set_reduced_motion(false)

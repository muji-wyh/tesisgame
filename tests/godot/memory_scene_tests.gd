extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const Style = preload("res://scripts/ui_style.gd")
var checks := 0
var failures := 0


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


func _run() -> void:
	var directory := "res://build/memory-scene-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	var progress_script = app.medal_progress.get_script()
	app.medal_progress = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	Fixture.install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.coin_wallet.credit("fixture:memory-funding", 5000).ok, "Fund paid observations using the real isolated wallet")
	app._coin_flight.sync(app.coin_wallet.balance)
	Fixture.enter_mode(app, "memory")
	await settle()
	await _check_player_flow(app)
	await _check_refresh(app)
	await _check_reward_tiers(app)
	await _check_early_replay(app)
	await _check_responsive_header(app)
	Fixture.enter_mode(app, "match")
	app._memory.round_finished.emit(true, app.model.lesson_words)
	check(app.model.phase != "won" and app._memory.memory.phase == "stopped", "A departed Memory view cannot complete the Match round")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Memory scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_player_flow(app) -> void:
	var view = app._memory
	var board: Array = view.memory.cards.duplicate(true)
	var targets: Array = _targets(view)
	var field: Rect2 = view.get_global_rect()
	check(board.size() == 10 and view.is_visible_in_tree() and not app.grid.visible, "Memory opens its own complete ten-card board")
	check(view.start_button.is_visible_in_tree() and app._default_focus() == view.start_button
		and not view.memory.started and not view.memory.studying, "Start game is the initial player action")
	check(not view.study_button.visible and view.controls() == [view.start_button]
		and not app._memory_peek_countdown.visible, "Cards and the paid eye cannot bypass the initial start gate")
	check(app._memory_reward.snapshot().tier == RewardProgress.THEMES.size() and not app.model.chest_earned
		and app.model.chest_reward_pair == 0 and not app._pair_reward.visible, "Memory previews the top tier without reserving a random chest")
	view.card_buttons[0].pressed.emit()
	view.begin_peek()
	check(view.memory.selected_indices.is_empty() and not view.memory.started, "Card and eye input are ignored before Start")
	view.start_button.grab_focus()
	app._controller_accept()
	check(view.memory.started and view.memory.studying and view.memory.peeks == 1
		and view.memory.peek_duration == 10.0, "Controller Start begins the free ten-second observation exactly once")
	check(app._memory_peek_countdown.visible and app._memory_peek_countdown.seconds == 10
		and app._default_focus() == app._memory_peek_countdown.action_button, "Observation exposes Start matching as its keyboard action")
	view.start_button.pressed.emit()
	view.card_buttons[0].pressed.emit()
	view.card_buttons[1].pressed.emit()
	check(view.memory.peeks == 1 and view.memory.attempts == 0 and view.memory.selected_indices.is_empty(), "Observation ignores cards and repeat Start signals")
	app._memory_peek_countdown.action_button.pressed.emit()
	check(not view.memory.studying and view.card_buttons.all(func(card: Button) -> bool: return not card.face_up), "Start matching immediately conceals all unmatched cards")
	check(view.get_global_rect() == field and _targets(view) == targets, "Start and observation preserve every card target")
	view.card_buttons[0].pressed.emit()
	check(view.memory.selected_indices == [0] and not view.card_buttons[0].face_up
		and not app.audio.voice.playing and app._memory_stage_label.text == "Choose one more card", "The first selection is concealed, silent and visibly acknowledged")
	check(not str(view.card_buttons[0].get("accessibility_name")).contains(str(board[0].word.text)), "Concealed selection accessibility does not reveal its answer")
	app._controller_back()
	check(view.memory.selected_indices.is_empty(), "Back cancels a concealed selection without costing a mistake")
	view.card_buttons[0].grab_focus()
	app._controller_accept()
	Fixture.enter_mode(app, "memory")
	check(view.memory.selected_indices == [0] and view.memory.cards == board, "Home and reentry preserve the concealed selection")
	app.on_page_hidden()
	view.card_buttons[1].pressed.emit()
	check(view.controls().is_empty() and view.memory.selected_indices == [0], "A hidden page cannot change the attempt")
	app.on_page_visible()
	app._show_collection()
	view.card_buttons[1].pressed.emit()
	view.study_button.pressed.emit()
	check(view.memory.selected_indices == [0] and not view.memory.studying, "Covered controls cannot select or buy an observation")
	app._hide_collection()
	var coins: int = app.coin_wallet.balance
	view.study_button.pressed.emit()
	check(view.memory.studying and view.memory.peek_duration == 5.0 and view.memory.selected_indices.is_empty()
		and app.coin_wallet.balance == coins - 100, "The paid eye clears selection and buys a five-second observation")
	app._memory_peek_countdown.action_button.pressed.emit()
	app._memory_peek_countdown.action_button.pressed.emit()
	check(not view.memory.studying and app.coin_wallet.balance == coins - 100, "Skipping twice cannot charge another observation")
	var wrong := _wrong_pair(view)
	view.card_buttons[wrong[0]].pressed.emit()
	view.card_buttons[wrong[1]].pressed.emit()
	check(view.memory.phase == "feedback" and view.card_buttons[wrong[0]].face_up and view.card_buttons[wrong[1]].face_up
		and view.memory.mistakes == 1 and app._memory_stage_label.text == "Not a pair.", "A wrong attempt reveals both cards together with gentle negative feedback")
	check(app._memory_reward.snapshot().tier == RewardProgress.THEMES.size() - 1 and not app.model.chest_earned, "One mismatch lowers the potential reward by one level")
	var attempts: int = view.memory.attempts
	view.study_button.pressed.emit()
	check(view.memory.phase == "feedback" and view.memory.attempts == attempts and not view.memory.studying,
		"The eye cannot dismiss a mismatch or buy an observation during judgment")
	app._show_collection()
	view.card_buttons[wrong[0]].pressed.emit()
	view.continue_feedback()
	check(view.memory.phase == "feedback", "Collection blocks card dismissal of a waiting mismatch")
	app._hide_collection()
	await create_timer(0.85).timeout
	check(view.memory.phase == "feedback" and view.card_buttons[wrong[0]].face_up and view.card_buttons[wrong[1]].face_up,
		"Returning from Collection keeps the wrong pair visible until another card click")
	view.card_buttons[wrong[0]].pressed.emit()
	check(view.memory.phase == "waiting" and view.memory.attempts == attempts and view.memory.selected_indices.is_empty()
		and view.card_buttons.all(func(card: Button) -> bool: return not card.face_up),
		"Clicking an exposed wrong card hides the pair without selecting it or changing the score")
	_match(view, str(board[0].word.id))
	var pair: Array = view.card_buttons.filter(func(card: Button) -> bool: return card.card_data.word.id == board[0].word.id)
	check(pair.all(func(card: Button) -> bool: return card.face_up and card.match_mark.pair_number == 1)
		and pair[0].match_mark.tint == pair[1].match_mark.tint and app._memory_stage_label.text == "Great match!",
		"Correct cards share a numbered and colored pair badge")
	view.continue_feedback()
	check(pair.all(func(card: Button) -> bool: return card.face_up and card.disabled) and not app.model.chest_earned,
		"A successful pair stays visible and cannot award an early chest")
	check(view.get_global_rect() == field and _targets(view) == targets, "Outcomes never resize or move the remembered board")
	var before_exit: int = app.coin_wallet.balance
	Fixture.enter_mode(app, "match")
	check(app.coin_wallet.balance == before_exit and app.medal_progress.counts.is_empty(), "Leaving unfinished Memory grants neither preview coins nor medal pieces")


func _check_refresh(app) -> void:
	for stage: String in ["ready", "observation", "selection", "feedback"]:
		check(app.new_round(520, false, "", "memory"), "Prepare refresh during " + stage)
		var view = app._memory
		if stage == "observation":
			view.start_button.pressed.emit()
		elif stage in ["selection", "feedback"]:
			Fixture.start_memory(app)
			var wrong := _wrong_pair(view)
			view.card_buttons[wrong[0]].pressed.emit()
			if stage == "feedback":
				view.card_buttons[wrong[1]].pressed.emit()
		var previous_round: String = app._round_id
		var previous_model = view.memory
		var previous_card: Button = view.card_buttons[0]
		var before: int = app.coin_wallet.balance
		var counts: Dictionary = app.medal_progress.counts.duplicate(true)
		check(app._memory_refresh.is_visible_in_tree() and not app._memory_refresh.disabled
			and app._focus_candidates().has(app._memory_refresh), "Refresh is an available header action during " + stage)
		app._memory_refresh.pressed.emit()
		check(app._round_id != previous_round and view.memory != previous_model and previous_model.phase == "stopped",
			"Refresh replaces and stops the previous Memory round during " + stage)
		check(view.start_button.is_visible_in_tree() and not view.memory.started and not view.memory.studying
			and view.memory.selected_indices.is_empty() and view.memory.attempts == 0 and view.memory.mistakes == 0
			and view.memory.matched_word_ids.is_empty() and app._memory_reward.snapshot().tier == RewardProgress.THEMES.size(),
			"Refresh restores the Start gate, empty attempt and top chest during " + stage)
		check(view._feedback_timer.is_stopped() and not app._memory_peek_countdown.visible
			and not app._memory_reward.snapshot().animating, "Refresh cancels observation, feedback and chest motion during " + stage)
		var next_round: String = app._round_id
		previous_card.pressed.emit()
		view._feedback_timer.timeout.emit()
		view._advance_peek(20.0)
		view.round_finished.emit(true, [])
		check(app._round_id == next_round and not view.memory.started and view.memory.attempts == 0
			and app.model.phase != "won" and app.coin_wallet.balance == before and app.medal_progress.counts == counts,
			"Late controls and timers cannot mutate or reward the refreshed round during " + stage)
		await settle()
	var current_round: String = app._round_id
	app.on_page_hidden()
	app._memory_refresh.pressed.emit()
	check(app._round_id == current_round, "A hidden page ignores a stale refresh signal")
	app.on_page_visible()
	app._show_collection()
	app._memory_refresh.pressed.emit()
	check(app._round_id == current_round and not app._focus_candidates().has(app._memory_refresh),
		"The collection covers and disables access to Memory refresh")
	app._hide_collection()
	app._show_mode_menu()
	app._memory_refresh.pressed.emit()
	check(app._round_id == current_round, "Home ignores refresh from the covered board")
	app._hide_mode_menu()
	Fixture.enter_mode(app, "match")
	current_round = app._round_id
	app._memory_refresh.pressed.emit()
	check(app._round_id == current_round and not app._memory_refresh.visible, "A departed Memory refresh cannot restart Match")


func _check_reward_tiers(app) -> void:
	for mistakes in range(RewardProgress.THEMES.size() + 1):
		check(app.new_round(800 + mistakes, false, "", "memory"), "Prepare a fresh Memory reward outcome")
		app.choose_theme("ocean")
		Fixture.start_memory(app)
		var view = app._memory
		var wrong := _wrong_pair(view)
		for attempt in range(mistakes):
			view.card_buttons[wrong[0]].pressed.emit()
			view.card_buttons[wrong[1]].pressed.emit()
			view.continue_feedback()
		var tier: int = RewardProgress.THEMES.size() - mistakes
		var marker: Dictionary = app._memory_reward.snapshot()
		check(marker.tier == tier and marker.grey == (tier == 0), "The fixed chest reflects %d mistakes" % mistakes)
		var lesson: Array = app.model.lesson_words.duplicate(true)
		for word in lesson:
			_match(view, str(word.id))
			if view.memory.matched_word_ids.size() == 5:
				check(app.model.phase != "won" and not app.model.chest_earned, "Final feedback finishes before committing its reward")
			view.continue_feedback()
		check(app.model.phase == "won" and view.memory.phase == "won", "All five pairs complete the real round")
		var saved: Dictionary = app.medal_progress.pair_round("memory")
		check(saved.completed and saved.tier == tier and saved.awarded == (tier > 0)
			and app.model.chest_earned == (tier > 0), "Completion saves the remaining tier, including no chest")
		check(app._round_celebration.is_active() and not app.chest_button.is_visible_in_tree()
			and app._round_celebration.replay_button.is_visible_in_tree() and not app._round_celebration.replay_button.disabled,
			"Pip's entrance keeps Play again immediately available while the chest arrives")
		if tier > 0:
			Fixture.finish_celebration(app)
		else:
			app.audio.stop_voice()
			app._round_celebration.set_narration_playing(false)
			app._round_celebration.advance(3.01)
			check(app._round_celebration.is_ready() and app._round_celebration.replay_button.is_visible_in_tree()
				and not app._round_celebration.action_button.visible, "No-chest completion retains the same replay action after Pip finishes")
		var before: int = app.coin_wallet.balance
		var medal_id: String = str(saved.fragment.get("medal_id", ""))
		var previous_pieces: int = app.medal_progress.count_for(medal_id)
		var receipt: String = "pair:memory:" + app._round_id
		if tier > 0:
			check(app.chest_button.is_visible_in_tree() and app.model.reward_theme == RewardProgress.theme_for_tier(tier), "Earned chests use the surviving tier artwork")
			app._open_chest()
			app.chest._advance_animation(60.0)
			check(app.model.chest_state == "opened" and app.coin_wallet.balance == before + tier * 50
				and app.coin_wallet._receipts.get(receipt, 0) == tier * 50, "Opening credits exactly the tier's coins once")
			check(medal_id.begins_with("ocean-") and app.medal_progress.count_for(medal_id) == previous_pieces + 1, "Tier appearance preserves the selected world's medal reward")
		else:
			check(not app.chest_button.is_visible_in_tree(), "The grey chest never becomes an openable reward")
			app._open_chest()
			app._commit_fragment()
			check(app.coin_wallet.balance == before and not app.coin_wallet._receipts.has(receipt), "No-chest completion cannot award default tier-one coins")
		var after: int = app.coin_wallet.balance
		var counts: Dictionary = app.medal_progress.counts.duplicate(true)
		view.round_finished.emit(true, lesson)
		app._on_chest_opened()
		app._open_chest()
		app.on_page_hidden()
		app.on_page_visible()
		check(app.coin_wallet.balance == after and app.medal_progress.counts == counts, "Duplicate callbacks preserve the exact saved reward")
		await settle()


func _check_early_replay(app) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for mistakes: int in [0, 2, RewardProgress.THEMES.size()]:
		root.size = Vector2i(320, 568) if mistakes == 0 else Vector2i(844, 390) if mistakes == 2 else Vector2i(390, 844)
		check(app.new_round(950 + mistakes, false, "", "memory"), "Prepare early replay with %d mistakes" % mistakes)
		await settle()
		Fixture.start_memory(app)
		var view = app._memory
		var wrong := _wrong_pair(view)
		for attempt in range(mistakes):
			view.card_buttons[wrong[0]].pressed.emit()
			view.card_buttons[wrong[1]].pressed.emit()
			view.continue_feedback()
		for word in app.model.lesson_words.duplicate(true):
			_match(view, str(word.id))
			view.continue_feedback()
		await settle()
		var completed_round: String = app._round_id
		var saved: Dictionary = app.medal_progress.pair_round("memory")
		var tier: int = RewardProgress.THEMES.size() - mistakes
		var receipt: String = "pair:memory:" + completed_round
		var before: int = app.coin_wallet.balance
		var medal_id: String = str(saved.fragment.get("medal_id", ""))
		var before_count: int = app.medal_progress.count_for(medal_id)
		var before_counts: Dictionary = app.medal_progress.counts.duplicate(true)
		check(saved.completed and saved.tier == tier and app._round_celebration.is_active()
			and not app._round_celebration.is_ready(), "The replay test starts before the celebration entrance finishes")
		check(app._round_celebration.replay_button.is_visible_in_tree() and not app._round_celebration.replay_button.disabled
			and app._default_focus() == app._round_celebration.replay_button,
			"Play again is immediately visible and keyboard reachable for every reward outcome")
		var replay_bounds: Rect2 = app._round_celebration.replay_button.get_global_rect()
		var replay_scale: float = Style.ui_scale(app._round_celebration.replay_button)
		check(root.get_visible_rect().grow(1).encloses(replay_bounds) and replay_bounds.size.y * replay_scale >= 43.5
			and not replay_bounds.intersects(app._round_celebration.home_button.get_global_rect()),
			"The immediate replay target fits beside Home at " + str(root.size))
		app._memory_refresh.pressed.emit()
		check(app._round_id == completed_round, "The settlement modal rejects a stale refresh signal")
		app._round_celebration.replay_button.pressed.emit()
		check(app._round_id != completed_round and not app._round_celebration.is_active()
			and not app._settlement_dialog_open() and view.start_button.is_visible_in_tree() and not view.memory.started,
			"Early Play again immediately returns to the new Memory Start gate")
		if tier > 0:
			check(app.coin_wallet.balance == before + tier * 50 and app.coin_wallet._receipts.get(receipt, 0) == tier * 50
				and app.medal_progress.count_for(medal_id) == before_count + 1,
				"Early replay saves the surviving tier's coins and medal fragment exactly once")
		else:
			check(app.coin_wallet.balance == before and not app.coin_wallet._receipts.has(receipt)
				and app.medal_progress.counts == before_counts, "Early replay with no chest grants no coins or fragments")
		var replayed_round: String = app._round_id
		var after: int = app.coin_wallet.balance
		var after_counts: Dictionary = app.medal_progress.counts.duplicate(true)
		app._round_celebration.replay_button.pressed.emit()
		app._round_celebration.replay_requested.emit(completed_round)
		app._round_celebration.performance_finished.emit(completed_round)
		app._on_chest_opened()
		check(app._round_id == replayed_round and app.coin_wallet.balance == after and app.medal_progress.counts == after_counts
			and not view.memory.started, "Duplicate replay and old celebration callbacks cannot repeat settlement or skip Start")
		await settle()
	check(app.new_round(990, false, "", "memory"), "Prepare refresh during the final successful pair")
	Fixture.start_memory(app)
	var final_view = app._memory
	var completed_words: Array = app.model.lesson_words.duplicate(true)
	for word in completed_words:
		_match(final_view, str(word.id))
		if final_view.memory.matched_word_ids.size() < 5:
			final_view.continue_feedback()
	var final_round: String = app._round_id
	var final_before: int = app.coin_wallet.balance
	var fragments_before: int = _total_fragments(app)
	check(final_view.memory.phase == "feedback" and final_view.memory.matched_word_ids.size() == 5
		and app.model.phase != "won", "The fifth pair still has its final feedback before reward settlement")
	app._memory_refresh.pressed.emit()
	check(app._round_id != final_round and final_view.start_button.is_visible_in_tree() and not final_view.memory.started
		and app.coin_wallet.balance == final_before + 300 and app.coin_wallet._receipts.get("pair:memory:" + final_round, 0) == 300
		and _total_fragments(app) == fragments_before + 1,
		"Refresh during the fifth successful pair settles the completed chest before starting again")
	final_view.round_finished.emit(true, completed_words)
	app._round_celebration.replay_requested.emit(final_round)
	app._on_chest_opened()
	check(app.coin_wallet.balance == final_before + 300 and _total_fragments(app) == fragments_before + 1,
		"Late final-pair callbacks cannot duplicate the reward settled by refresh")
	await settle()


func _check_responsive_header(app) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = dimensions
		check(app.new_round(409, false, "", "memory"), "Prepare responsive Memory at " + str(dimensions))
		await settle()
		var view = app._memory
		var board_bounds: Rect2 = view.get_global_rect()
		var card_bounds: Array = _targets(view)
		var badge_bounds: Rect2 = app._memory_reward.get_global_rect()
		var refresh_bounds: Rect2 = app._memory_refresh.get_global_rect()
		var scale_factor: float = Style.ui_scale(app._memory_refresh)
		check(app._memory_refresh.is_visible_in_tree() and root.get_visible_rect().grow(1).encloses(refresh_bounds)
			and refresh_bounds.size.x * scale_factor >= 43.5 and refresh_bounds.size.y * scale_factor >= 43.5
			and not refresh_bounds.intersects(board_bounds) and not refresh_bounds.intersects(badge_bounds),
			"Refresh retains an unobstructed touch target at " + str(dimensions))
		check(root.get_visible_rect().grow(1).encloses(board_bounds)
			and board_bounds.encloses(view.start_button.get_global_rect()), "Board and Start fit the viewport")
		view.start_button.pressed.emit()
		await settle()
		check(not app._memory_refresh.get_global_rect().intersects(view.study_button.get_global_rect())
			and not app._memory_refresh.get_global_rect().intersects(app._mode_heading_button.get_global_rect()),
			"Refresh stays separate from the eye and Home during observation")
		var clock = app._memory_peek_countdown
		var area: Rect2 = clock.get_global_rect()
		check(clock.is_visible_in_tree() and clock.seconds == 10 and clock.action_button.is_visible_in_tree(), "Observation shows the clock and skip action")
		check(root.get_visible_rect().grow(1).encloses(area) and area.grow(0.5).encloses(clock.action_button.get_global_rect())
			and not area.intersects(board_bounds) and not area.intersects(badge_bounds)
			and not area.intersects(app._memory_refresh.get_global_rect()), "Countdown, skip, refresh and chest fit without covering cards")
		view._advance_peek(view.memory.peek_remaining - 3.75)
		check(clock.seconds == 4 and is_equal_approx(clock.progress(), 0.375), "The clock follows the real remaining time")
		view._advance_peek(view.memory.peek_remaining)
		check(not clock.visible and not view.memory.studying and app._memory_stage_label.visible, "Expiry restores matching instructions")
		check(_targets(view) == card_bounds and view.get_global_rect() == board_bounds
			and app._memory_reward.get_global_rect() == badge_bounds, "Observation preserves board and chest positions")
		for card in view.card_buttons:
			check(board_bounds.grow(1).encloses(card.get_global_rect()), "Every card remains in its board")


func _targets(view) -> Array:
	return view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect())


func _total_fragments(app) -> int:
	var total: int = 0
	for count in app.medal_progress.counts.values():
		total += int(count)
	return total


func _wrong_pair(view) -> Array[int]:
	for index in range(1, view.memory.cards.size()):
		if view.memory.cards[index].word.id != view.memory.cards[0].word.id \
			and view.memory.cards[index].kind != view.memory.cards[0].kind:
			return [0, index]
	return []


func _match(view, word_id: String) -> void:
	for index in range(view.memory.cards.size()):
		if view.memory.cards[index].word.id == word_id:
			view.card_buttons[index].pressed.emit()

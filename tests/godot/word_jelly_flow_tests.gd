extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const ChestCelebration = preload("res://scripts/jelly_chest_celebration.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func merged_word(view, word: Dictionary, fragments: int = 0) -> Dictionary:
	var game = view.game
	game.step(0.4)
	var pair: Array[int] = []
	for first: Dictionary in game.cells:
		if int(first.mass) != 1:
			continue
		for second: Dictionary in game.cells:
			if first.id != second.id and int(second.mass) == 1 and str(first.text) + str(second.text) == str(word.text):
				pair.assign([int(first.id), int(second.id)])
				break
		if not pair.is_empty():
			break
	if pair.is_empty():
		game.drop_now()
		game.step(0.4)
		return merged_word(view, word, fragments)
	for tile: Dictionary in game.cells:
		if int(tile.id) in pair:
			tile.fragments = fragments if int(tile.id) == pair[0] else 0
			tile.chest = int(tile.fragments) > 0
	check(game.try_merge(pair[0], pair[1]) == "merged", "The gameplay model accepts a word-building merge")
	var result_id: int = int(game.fusions.back().result.id)
	game.step(game.FUSION_SECONDS + game.SETTLE_SECONDS * 2.0)
	var result: Dictionary = game.cell(result_id)
	check(not result.is_empty() and result.word.id == word.id, "The resulting word persists on the board")
	return result


func check_finish_header(app, view) -> void:
	var original_size: Vector2i = root.size
	var reveal_word: Dictionary = app._learning_words()[0]
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(320, 480), Vector2i(568, 320), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		var s: float = app.Style.ui_scale(app)
		var finish: Rect2 = view.finish_button.get_global_rect()
		var playfield: Rect2 = view.get_global_rect()
		var collect: Rect2 = view.collect_button.get_global_rect()
		var context: String = " at %s" % dimensions
		check(view.finish_button.is_visible_in_tree() and not view.finish_button.disabled
			and app._header.get_global_rect().grow(0.1).encloses(finish),
			"The active round places Finish inside the game header" + context)
		check(finish.end.y + 4.0 / s <= playfield.position.y + 0.1
			and collect.position.y - finish.end.y >= 16.0 / s - 0.1,
			"Finish is separated from the playfield and Collect words" + context)
		check(finish.size.x * s >= 44.0 - 0.1 and finish.size.y * s >= 44.0 - 0.1
			and not finish.intersects(app._mode_heading.get_global_rect()),
			"The header keeps a full touch target and an unobstructed mode title" + context)
		var bottom: float = maxf(view._global_rect(view._board).end.y, maxf(collect.end.y, view._loot_meter.get_global_rect().end.y))
		check(absf(bottom - (playfield.end.y - 12.0 / s)) < 0.1,
			"The board and collection controls retain twelve-pixel bottom padding" + context)
		var chest: Rect2 = view._loot_meter.get_global_rect()
		var icon: Rect2 = view._loot_icon.get_global_rect()
		check(chest.is_equal_approx(view._chest_tap.get_global_rect()) and chest.encloses(icon)
			and chest.get_center().distance_to(icon.get_center()) < 0.1
			and chest.size.x * s >= 44.0 - 0.1 and chest.size.y * s >= 44.0 - 0.1,
			"The chest artwork remains centered inside its full-size meter and tap target" + context)
		check(view._reward_presentation._anchor.is_equal_approx(view._loot_icon.get_rect()),
			"The milestone flight returns to the current local chest artwork anchor" + context)
		if not view._compact_hud:
			check(chest.position.y <= playfield.position.y + 24.0 / s
				and chest.end.y + 12.0 / s <= view.drop_button.global_position.y + 0.1,
				"Phone treasure sits near the top with room above the supply tray" + context)
			check(absf(collect.get_center().x - view._global_rect(view._board).get_center().x) < 0.1,
				"Hosted Collect remains centered beneath the phone board" + context)
			view._word_reveal.set_reduced_motion(false)
			view._word_reveal._rng.seed = 4821
			for index in range(3):
				view._word_reveal.present(reveal_word, view._picture(reveal_word), app.Style.GOOD)
				view._word_reveal.advance(0.10)
			check(view._word_reveal.is_visible_in_tree() and view._word_reveal.snapshot().entries.size() == 3,
				"Rapid collected words coexist beside the hosted chest" + context)
			for tick in range(16):
				for entry: Dictionary in view._word_reveal.snapshot().entries:
					var rect: Array = entry.rect
					var card := Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
					check(not card.intersects(chest) and playfield.grow(0.1).encloses(card),
						"Every collected-word card stays clear of the chest throughout its elastic motion" + context)
				view._word_reveal.advance(0.025)
			view._word_reveal.reset()
			view._word_reveal.set_reduced_motion(view.reduced_motion)
		if dimensions == Vector2i(393, 852):
			check(absf(view._board.size.x - (view.size.x - 16.0 / s)) < 0.1
				and is_equal_approx(view._board.size.x / view._pitch, 6.0),
				"The taller phone retains all six columns at their full available width")
	root.size = original_size
	await settle()
	var source: Vector2 = view._tiles[int(view.game.cells[0].id)].get_global_rect().get_center()
	check(view._press(-1, source), "A settled root can begin the header Finish drag guard check")
	view._move(source + Vector2(24.0 / app.Style.ui_scale(app), 0))
	view._process(0.0)
	check(view._dragging and view.finish_button.disabled, "Dragging a root disables the header Finish target")
	view.finish_button.pressed.emit()
	check(view.game.phase == "playing" and app._round_result.is_empty(), "A Finish signal cannot end an owned board drag")
	view.cancel_input()
	view._refresh_controls()
	view.finish_button.pressed.emit()
	await settle()
	check(app._finish_confirmation_open() and view.game.phase == "playing" and view.game.paused,
		"A deliberate header Finish pauses the round for confirmation")
	app._finish_confirmation.finish_button.pressed.emit()
	await settle()
	check(view.game.phase == "finished" and view._result_visible and not view.finish_button.is_visible_in_tree(),
		"Confirming Finish opens results and removes the round action")
	view.replay_button.pressed.emit()
	await settle()
	view._process(0.0)
	check(view.game.phase == "playing" and view.finish_button.is_visible_in_tree(), "Replay restores Finish to the active header")
	Fixture.enter_mode(app, "match")
	await settle()
	check(not view.finish_button.is_visible_in_tree(), "Switching to Match leaves no Jelly Words Finish in its header")
	Fixture.enter_mode(app, "word_jelly")
	await settle()
	check(view.finish_button.is_visible_in_tree(), "Returning to Jelly Words restores its own Finish control")


func check_finish_visibility_stable(view, expected_visible: bool, context: String) -> void:
	var changes: Array[bool] = []
	var observe: Callable = func() -> void: changes.append(view.finish_button.visible)
	view.finish_button.visibility_changed.connect(observe)
	for index in range(6):
		view._refresh_controls()
	view.finish_button.visibility_changed.disconnect(observe)
	check(changes.is_empty() and view.finish_button.is_visible_in_tree() == expected_visible,
		"Repeated refreshes preserve Finish visibility without triggering header reflow " + context)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 800)
	var directory := "user://word-jelly-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	Fixture.enter_mode(app, "match")
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.new_round(405, false, "", "word_jelly"), "The new mode starts through the application route")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	check(app._active_jelly() == view and view.is_visible_in_tree() and not app._jelly.is_visible_in_tree(), "Only the selected Jelly board is visible")
	check(app._jelly_backdrop.visible and app._mode_heading.text.begins_with("Jelly Words"), "The new game has its heading and shared woodland")
	check(app._round_id.begins_with("word_jelly:"), "Word treasure and coin receipts use a distinct round namespace")
	await check_finish_header(app, view)
	var vocabulary: Array = app._learning_words()
	var word: Dictionary = vocabulary.filter(func(item: Dictionary) -> bool: return str(item.text).length() >= 2 and str(item.text).length() <= 6)[0]
	check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, true, 405), "The integration fixture uses a real current-age word")
	app._sync_jelly()
	app.audio.set_muted(false)
	view.word_requested.emit(word)
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + str(word.audio)), "The new mode routes a complete word to its exact pronunciation")
	app.audio.halt()
	app.audio.set_muted(true)
	var game = view.game
	game.spawn_interval = 10000.0
	var merged: Dictionary = merged_word(view, word, 2)
	check(game.fragment_count == 0 and app.coin_wallet.balance == 0, "Merging keeps carried fragments and coins uncollected")
	check(game.collect(merged.id), "A valid word can be collected through the shared view model")
	var receipt_event: String = str(game.fusions.back().attempt_id)
	game.step(game.COLLECT_SECONDS)
	check(game.cell(merged.id).is_empty() and app.coin_wallet.balance == 100, "Removing a two-piece word saves its hundred coins immediately")
	check(game.fragment_count == 2 and int(app.growth.snapshot().streaks.get(word.id, 0)) == 1, "The collection credits every carried fragment and one learning answer")
	check(app._coin_flight.snapshot().active, "The collected word launches the shared coin flight")
	var duplicate: Dictionary = app._credit_word_jelly(receipt_event, 100)
	app._word_jelly_collected(receipt_event, word, 100, 2, Vector2.ZERO)
	check(duplicate.ok and duplicate.duplicate and app.coin_wallet.balance == 100, "A retried collection receipt cannot pay twice")
	var growth_before: Dictionary = app.growth.snapshot().streaks.duplicate()
	app._jelly.word_attempted.emit("hidden-match", [str(word.id)] as Array[String], true)
	app._jelly.round_finished.emit({"score": 900, "chest_count": 1, "chest_tier": 6})
	check(app.growth.snapshot().streaks == growth_before and app._round_result.is_empty(), "Hidden Jelly Match callbacks cannot change this mode's progress or result")
	merged = merged_word(view, word, 2)
	check(game.collect(merged.id), "The next complete word accepts collection")
	game.step(0.1)
	var paused_time: float = float(game.fusions.back().elapsed)
	app._show_mode_menu()
	game.step(2.0)
	check(game.paused and app.coin_wallet.balance == 100 and is_equal_approx(float(game.fusions.back().elapsed), paused_time), "The library freezes a pending collection before its wallet commit")
	check(not view.finish_button.is_visible_in_tree(), "Home hides the hosted Finish action while the round is paused")
	check_finish_visibility_stable(view, false, "on Home")
	app._hide_mode_menu()
	check(view.finish_button.is_visible_in_tree(), "Returning from Home restores the active Finish action")
	check_finish_visibility_stable(view, true, "during play")
	app.set_reduced_motion(false)
	game.step(game.COLLECT_SECONDS)
	check(not game.paused and game.fragment_count == 4 and game.chest_tier == 1 and app.coin_wallet.balance == 200, "Returning to play completes collection and unlocks the first chest")
	check(view._reward_presentation.snapshot().kind == "synthesis", "The first chest uses the shared fragment-synthesis presentation")
	view.advance_reward_presentation(ChestCelebration.ARRIVAL_SECONDS + ChestCelebration.REVEAL_SECONDS + 0.03)
	check(app._reward_confetti.is_active() and app._reward_confetti.snapshot().keys.has(app._round_id + ":word_jelly:1"), "The new mode's chest acquisition launches screen confetti")
	var reward_elapsed: float = float(view._reward_presentation.snapshot().elapsed)
	app._show_mode_menu()
	check(game.paused and not view._reward_presentation._flight_surface.is_visible_in_tree(),
		"Home hides the independent chest flight layer while retaining its earned reward")
	app._hide_mode_menu()
	check(not game.paused and view._reward_presentation._flight_surface.is_visible_in_tree()
		and is_equal_approx(float(view._reward_presentation.snapshot().elapsed), reward_elapsed),
		"Returning from Home restores the same in-progress chest flight")
	app._show_collection()
	check(game.paused and not view._reward_presentation._flight_surface.is_visible_in_tree(),
		"The vocabulary page is never covered by a paused chest flight")
	check(not view.finish_button.is_visible_in_tree(), "Vocabulary hides the hosted Finish action")
	app._hide_collection()
	check(not game.paused and view._reward_presentation._flight_surface.is_visible_in_tree()
		and is_equal_approx(float(view._reward_presentation.snapshot().elapsed), reward_elapsed),
		"Closing vocabulary resumes the original flight without replaying its reveal")
	view.advance_reward_presentation(ChestCelebration.PERFORMANCE_SECONDS - ChestCelebration.REVEAL_SECONDS)
	merged = merged_word(view, word, 1)
	var wallet_path: String = app.coin_wallet._path
	app.coin_wallet._path = directory + "/missing/coins.cfg"
	check(game.collect(merged.id), "A word reserves its collection before storage is attempted")
	var retry_event: String = str(game.fusions.back().attempt_id)
	game.step(game.COLLECT_SECONDS)
	check(not game.cell(merged.id).is_empty() and app.coin_wallet.balance == 200 and game.fragment_count == 4, "A failed wallet write keeps the word and its fragments recoverable")
	app.coin_wallet._path = wallet_path
	check(app.coin_wallet.load_state(), "The wallet reloads after storage recovers")
	app._refresh()
	check(game.collect(merged.id) and str(game.fusions.back().attempt_id) == retry_event, "Retrying the same word keeps its original receipt identity")
	game.step(game.COLLECT_SECONDS)
	check(game.cell(merged.id).is_empty() and app.coin_wallet.balance == 300 and game.fragment_count == 5, "The successful retry credits coins and fragments once")
	app.on_page_hidden()
	var spawn_before: float = game.spawn_elapsed
	game.step(2.0)
	check(game.paused and game.spawn_elapsed == spawn_before and not app._jelly_backdrop.visible, "Backgrounding freezes the word board and its scenery")
	app.on_page_visible()
	check(not game.paused, "The word board resumes when its page returns")
	app._show_collection()
	check(game.paused and app.collection_page.visible and not app._jelly_interaction_allowed(), "The vocabulary page pauses and blocks the new board")
	app._hide_collection()
	check(not game.paused and view.is_visible_in_tree(), "Closing vocabulary restores the current word board")
	app.set_reduced_motion(false)
	check(not view.reduced_motion, "Motion preferences reach the new mode")
	for index in range(2):
		merged = merged_word(view, word, 2)
		check(game.collect(merged.id), "Another word can contribute to the same chest")
		game.step(game.COLLECT_SECONDS)
	check(game.fragment_count == 9 and game.chest_tier == 2, "Additional collections upgrade the earned chest")
	check(view._reward_presentation.snapshot().kind == "upgrade", "The next chest tier uses the enlarged spinning upgrade presentation")
	view.advance_reward_presentation(ChestCelebration.ARRIVAL_SECONDS + ChestCelebration.REVEAL_SECONDS + 0.03)
	check(app._reward_confetti.snapshot().keys.has(app._round_id + ":word_jelly:2"), "The new chest tier launches its own single confetti burst")
	var earned_round: String = app._round_id
	Fixture.enter_mode(app, "jelly")
	await settle()
	check(app._mode_id == "jelly" and app._jelly_rewards_shown and app._jelly_rewards.has_pending(), "Switching Jelly games preserves and opens the saved treasure room")
	check(not view.finish_button.is_visible_in_tree(), "The treasure room and the other Jelly mode cannot expose Jelly Words Finish")
	check(app._jelly_rewards.rewards.entries[0].tier == 2 and app._jelly_rewards.rewards.round_id == earned_round
		and app._jelly_rewards.rewards.entries[0].reward_id == "jelly:" + earned_round + ":0", "The saved reward retains the exact upgraded tier and mode namespace")
	growth_before = app.growth.snapshot().streaks.duplicate()
	view.word_attempted.emit("hidden-words", [str(word.id)] as Array[String], true)
	check(app.growth.snapshot().streaks == growth_before, "A stopped Jelly Words callback cannot credit Jelly Match")
	check(app.coin_wallet.balance == 500, "Switching modes preserves every immediate word reward")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly Words application flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

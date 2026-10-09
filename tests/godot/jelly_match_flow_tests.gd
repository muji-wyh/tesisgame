extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const RewardState = preload("res://scripts/pop_reward_state.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
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


func pair(game, marked: bool = false) -> Array:
	for a in game.cells:
		if marked and not a.chest:
			continue
		for b in game.cells:
			if a.word.id == b.word.id and a.kind != b.kind:
				return [a, b]
	return []


func unmarked_pair(game) -> Array:
	for a: Dictionary in game.cells:
		if bool(a.chest):
			continue
		for b: Dictionary in game.cells:
			if not bool(b.chest) and a.word.id == b.word.id and a.kind != b.kind:
				return [a, b]
	return []


func fill_board(game) -> void:
	for beat in range(game.CAPACITY + 2):
		if game.phase != "playing" or game.full_elapsed >= 0.0:
			break
		var remaining: float = float(game.spawn_interval) - float(game.spawn_elapsed)
		if game.cells.size() == game.CAPACITY:
			remaining = 0.0
			for cell: Dictionary in game.cells:
				remaining = maxf(remaining, Motion.ready_at(cell) - float(cell.age))
		game.step(maxf(0.000001, remaining))
	check(game.cells.size() == game.CAPACITY and is_zero_approx(float(game.full_elapsed)),
		"A full board waits for its final single tile to settle before warning")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var directory := "user://jelly-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	check(app.new_round(51, false, "", "jelly"), "A real Jelly round starts through GameUI")
	app._jelly.set_process(false)
	await settle()
	check(app._jelly.visible and not app._phrase.visible and not app._pop.visible, "Jelly owns the play surface")
	check(app._jelly_backdrop.is_visible_in_tree() and app._jelly_backdrop.size == app.size
		and app._jelly_backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The woodland covers the Jelly screen behind controls without capturing touch input")
	var game = app._jelly.game
	game.step(game.SETTLE_SECONDS)
	var chosen := pair(game, true)
	check(chosen.size() == 2, "The initial board contains a reachable marked pair")
	if chosen.size() != 2:
		app.queue_free()
		await settle()
		quit(1)
		return
	var word_id: String = str(chosen[0].word.id)
	check(game.try_merge(chosen[0].id, chosen[1].id) == "correct", "Matching picture and word commits fusion")
	var spawn_before: float = game.spawn_elapsed
	var supply_before: Array = game.snapshot().upcoming.duplicate(true)
	var cells_before: Array = game.cells.duplicate(true)
	game.step(0.4)
	check(game.cleared_pairs == 0 and game.spawn_elapsed == spawn_before and game.cells == cells_before
		and game.snapshot().upcoming == supply_before,
		"Fusion neither credits early nor advances the drop, active fall or advertised supply")
	app._show_mode_menu()
	var fusion_before: float = game.fusion.elapsed
	game.step(20)
	check(game.paused and game.fusion.elapsed == fusion_before and game.cells == cells_before
		and game.snapshot().upcoming == supply_before, "The game menu freezes fusion, falling tiles and supply together")
	app._hide_mode_menu()
	game.step(0.66)
	check(game.cleared_pairs == 1 and game.chest_count == 1, "Resuming completes one pair and one chest")
	check(int(app.growth.snapshot().streaks.get(word_id, 0)) == 1, "One eliminated pair credits its word exactly once")
	app._jelly.word_attempted.emit("jelly-1", [word_id] as Array[String], true)
	check(int(app.growth.snapshot().streaks.get(word_id, 0)) == 1, "A repeated event receipt cannot double credit growth")
	app._show_collection()
	check(not app._jelly_backdrop.visible, "The woodland does not leak behind the word notebook")
	var before: Dictionary = game.snapshot()
	game.step(50)
	check(game.snapshot().spawn_elapsed == before.spawn_elapsed and game.paused and game.snapshot().cells == before.cells
		and game.snapshot().upcoming == before.upcoming, "The notebook freezes falling, queued supply and danger clocks")
	app._hide_collection()
	app.on_page_hidden()
	check(not app._jelly_backdrop.visible, "Backgrounding removes the gameplay scenery")
	game.step(50)
	check(game.paused and game.snapshot().spawn_elapsed == before.spawn_elapsed and game.snapshot().cells == before.cells
		and game.snapshot().upcoming == before.upcoming, "Backgrounding cannot consume preview tiles or catch up a falling body")
	app.on_page_visible()
	check(not game.paused, "Returning restores the same board")
	check(app._jelly_backdrop.visible, "Returning restores the same woodland without replaying scenery")
	game.finish_round()
	check(app._round_celebration.is_active() and not app._jelly.visible, "A positive result enters the shared Pip celebration")
	check(not app._jelly_backdrop.visible, "The shared reward presentation owns its own background")
	var summary: Dictionary = app._round_celebration.snapshot()
	check(app._round_result.score == 1 and summary.score == 1 and summary.title == "Round results"
		and summary.caption == "Score: 1 · Chests: 1" and is_equal_approx(app._round_celebration._heading.modulate.a, 1.0)
		and is_equal_approx(app._round_celebration._caption.modulate.a, 1.0),
		"The real result immediately reports the completed pair's score and earned chest")
	check(app._jelly_rewards.has_pending() and FileAccess.file_exists(app.jelly_reward_save_path), "Earned treasure is durable before its result action")
	app._show_jelly_rewards()
	check(not app._jelly_rewards_shown, "Treasure cannot open through the celebration gate")
	var receipt: String = app._round_id
	game.finish_round()
	check(app._round_id == receipt and app._jelly_rewards.snapshot().chest_count == 1, "Finishing twice preserves one reward batch")
	Fixture.finish_celebration(app)
	check(app._jelly.visible and not app._round_celebration.is_active(), "The full result appears after celebration")
	check(app._jelly_backdrop.visible, "Jelly's settlement returns to its woodland setting")
	check(app._jelly.snapshot().score == 1 and app._jelly.snapshot().result.title == "Round results"
		and app._jelly.snapshot().result.caption == summary.caption,
		"The persistent result retains the same score and chest summary after the animation")
	check(not app.new_round(52, false, "", "jelly") and app._jelly_rewards_shown, "Replay resumes pending treasure before starting a new board")
	check(not app._jelly_backdrop.visible, "The chest room does not inherit gameplay scenery")
	await settle()
	var room = app._jelly_rewards
	room.set_process(false)
	room.begin_hold(room._cards[0].button)
	room.advance_hold(0.2)
	app._show_mode_menu()
	check(room.snapshot().paused and not room.snapshot().holding, "Menu cancels an uncommitted treasure hold")
	app._hide_mode_menu()
	app.set_reduced_motion(true)
	room.begin_hold(room._cards[0].button)
	room.advance_hold(Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 1 and not room.has_pending(), "The earned chest uses the real opening flow")
	app._hide_jelly_rewards()
	check(app.new_round(53, false, "", "jelly"), "A new board is available after rewards are opened")
	app._jelly.set_process(false)
	game = app._jelly.game
	game.finish_round()
	check(not app._round_celebration.is_active() and app._jelly.visible, "Zero loot shows a result without a false reward celebration")
	check(app._round_result.score == 0 and app._jelly.snapshot().result.title == "Round results"
		and app._jelly.snapshot().result.caption == "Score: 0 · Chests: 0",
		"A new zero-loot round reports its own zero totals without stale score or victory copy")
	check(app.new_round(54, false, "", "jelly"), "A zero-loot result can replay")
	app._jelly.set_process(false)
	game = app._jelly.game
	game.step(game.SETTLE_SECONDS)
	chosen = pair(game, true)
	game.try_merge(chosen[0].id, chosen[1].id)
	game.step(1.05)
	app.choose_mode("memory")
	check(not app._jelly_backdrop.visible, "Switching games removes the Jelly-only scenery")
	check(app._mode_id == "memory" and app._jelly_rewards.has_pending(), "Switching modes settles earned Jelly loot without replaying celebration")
	var saved_growth: Dictionary = app.growth.snapshot().streaks.duplicate()
	app._jelly.word_attempted.emit("stale", [word_id] as Array[String], true)
	check(app.growth.snapshot().streaks == saved_growth, "A hidden Jelly callback cannot affect the new round")
	app.choose_mode("jelly")
	check(app._jelly_rewards_shown and app._jelly.game.paused, "Returning to Jelly resumes its saved chest before gameplay")
	for viewport_size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 320), Vector2i(1366, 768)]:
		root.size = viewport_size
		await settle()
		app._show_mode_menu()
		await settle()
		check(app._mode_panel.buttons.size() == 5, "All five modes remain available")
		check(app._mode_panel.get_global_rect().end.y <= root.size.y + 1, "Mode cards fit at %s" % viewport_size)
		for tile in app._mode_panel._tiles:
			check(tile.picture.is_visible_in_tree() and tile.picture.size.x > 0 and tile.picture.size.y > 0, "Every mode retains its picture")
		app._hide_mode_menu()
	app.audio.halt()
	app.queue_free()
	await settle()
	await _warning_audio_flow(directory)
	await _uncapped_reward_checks(directory)
	await _reward_conflict_checks(directory)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly Match flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _jelly_cue_playing(audio, cue: String = "") -> bool:
	for player: AudioStreamPlayer in audio._jelly_players:
		if player.playing and player.stream != null and (cue.is_empty() or player.stream.resource_path == audio.JELLY_PATHS[cue]):
			return true
	return false


func _warning_audio_flow(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory, "warning-growth.cfg")
	app.jelly_reward_save_path = directory + "/warning-jelly-rewards.cfg"
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/warning-medals.cfg", directory + "/warning-legacy.cfg")
	app._presentation.path = directory + "/warning-presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(false)
	app.choose_mode("jelly")
	app._jelly.set_process(false)
	var game = app._jelly.game
	var cues: Array[String] = []
	app._jelly.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	fill_board(game)
	check(app._mode_id == "jelly" and _jelly_cue_playing(app.audio, "danger") and cues.count("danger") == 1
		and not app.audio.voice.playing, "Choosing Jelly enables its first warning without a word tap")
	game.step(1.0)
	check(_jelly_cue_playing(app.audio, "danger") and cues.count("danger") == 2,
		"The next model beat reaches GameUI's warning audio without additional input")
	for interruption: String in ["menu", "background"]:
		var elapsed: float = game.full_elapsed
		var warning_count: int = cues.count("danger")
		if interruption == "menu":
			app._show_mode_menu()
		else:
			app.on_page_hidden()
		game.step(5.0)
		check(game.paused and game.full_elapsed == elapsed and not _jelly_cue_playing(app.audio)
			and cues.count("danger") == warning_count, "%s stops warning audio and freezes its timeline" % interruption)
		if interruption == "menu":
			app._hide_mode_menu()
		else:
			app.on_page_visible()
		check(not _jelly_cue_playing(app.audio, "danger"), "%s return does not replay the interrupted warning" % interruption)
		game.step(1.0)
		check(not game.paused and _jelly_cue_playing(app.audio, "danger") and cues.count("danger") == warning_count + 1,
			"The next live beat restores warning audio after %s" % interruption)
	# This fixture exercises warning restart, not the separate pending-reward gate.
	# Supply is shuffled, so the first match can legitimately contain a chest.
	var chosen := unmarked_pair(game)
	check(chosen.size() == 2, "The warning fixture has a real pair without a treasure marker")
	if chosen.size() != 2:
		app.audio.halt()
		app.queue_free()
		await settle()
		return
	app._jelly._activate(chosen[0].id)
	app._jelly._activate(chosen[1].id)
	check(not game.fusion.is_empty() and not _jelly_cue_playing(app.audio, "danger") and _jelly_cue_playing(app.audio, "merge"),
		"A real selected pair silences the warning while preserving its rescue merge sound")
	game.step(game.FUSION_SECONDS)
	check(game.chest_count == 0 and not app._jelly_rewards.has_pending(),
		"The warning-only rescue leaves no pending treasure that would correctly gate a new board")
	fill_board(game)
	check(_jelly_cue_playing(app.audio, "danger"), "Refilling the rescued board starts a fresh audible warning")
	game.finish_round()
	check(game.phase == "finished" and not _jelly_cue_playing(app.audio), "Finishing stops the active warning through GameUI")
	app.choose_mode("memory")
	app.choose_mode("jelly")
	app._jelly.set_process(false)
	fill_board(app._jelly.game)
	check(_jelly_cue_playing(app.audio, "danger"), "A replacement Jelly round owns a new warning")
	app.choose_mode("memory")
	check(app._mode_id == "memory" and not _jelly_cue_playing(app.audio), "Switching modes stops the previous Jelly warning")
	app.audio.halt()
	app.queue_free()
	await settle()


func _uncapped_reward_checks(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory, "uncapped-growth.cfg")
	app.jelly_reward_save_path = directory + "/uncapped-jelly-rewards.cfg"
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/uncapped-medals.cfg", directory + "/uncapped-legacy.cfg")
	app._presentation.path = directory + "/uncapped-presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.new_round(104, false, "", "jelly"), "An uncapped reward round starts through GameUI")
	app._jelly.set_process(false)
	var game = app._jelly.game
	var attempts: int = 0
	while game.chest_count < 4 and game.phase == "playing" and attempts < 40:
		attempts += 1
		var chosen := pair(game, true)
		if chosen.is_empty():
			chosen = pair(game)
		if chosen.is_empty():
			game.step(game.spawn_interval + game.SETTLE_SECONDS)
			continue
		game.step(game.SETTLE_SECONDS)
		var merged: String = game.try_merge(chosen[0].id, chosen[1].id)
		check(merged == "correct", "Real word-picture merges earn the uncapped reward")
		if merged != "correct":
			break
		game.step(game.FUSION_SECONDS)
	check(game.chest_count == 4 and game.cleared_pairs >= 4,
		"Normal spawning and completed merges earn four chests without changing score or reward state")
	if game.chest_count != 4:
		app.audio.halt()
		app.queue_free()
		await settle()
		return
	var cleared: int = game.cleared_pairs
	game.step(game.CAPACITY * game.spawn_interval + game.FULL_SECONDS + 1.0)
	app._round_celebration.set_process(false)
	var celebration: Dictionary = app._round_celebration.snapshot()
	check(game.phase == "finished" and game.cleared_pairs == cleared and app._round_result.score == cleared
		and app._round_result.chest_count == 4,
		"A natural full-board timeout finishes with all four previously earned chests")
	check(celebration.active and celebration.automatic and celebration.chest_count == 4
		and celebration.score == cleared and celebration.title == "Round results"
		and celebration.caption == "Score: %d · Chests: 4" % cleared
		and app._round_celebration._count.text == "x4",
		"The real Jelly finale reports the earned score and full reward instead of truncating it to three")
	var saved := RewardState.new(app.jelly_reward_save_path)
	saved.storage_kind = "jelly"
	saved.max_chests = 0
	saved.allow_repeated_themes = true
	check(saved.load_state() and saved.round_id == app._round_id and saved.entries.size() == 4,
		"All four earned chests are durable before the celebration completes")
	Fixture.finish_celebration(app)
	check(not app._round_celebration.is_active() and app._jelly.snapshot().result.visible
		and app._round_result.chest_count == 4 and app._jelly.snapshot().score == cleared
		and app._jelly.snapshot().result.title == "Round results"
		and app._jelly.snapshot().result.caption == celebration.caption,
		"The completed celebration restores the same score and exact four-chest result")
	app._jelly.chests_button.pressed.emit()
	var room = app._jelly_rewards
	room.set_process(false)
	var first_page: Dictionary = room.snapshot()
	check(app._jelly_rewards_shown and first_page.chest_count == 4 and first_page.page_count == 2
		and first_page.page == 0 and first_page.visible_chest_count == 3,
		"The result action opens a four-chest batch paged into three visible chests")
	check(room.set_page(1) and room.snapshot().chest_count == 4 and room.snapshot().visible_chest_count == 1
		and room.snapshot().chests[0].index == 3,
		"The second page exposes the fourth durable chest at its global index")
	room.begin_hold(room._cards[0].button)
	room.advance_hold(Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 1 and saved.load_state() and saved.entries[3].opened
		and not saved.entries[0].opened and not saved.entries[1].opened and not saved.entries[2].opened,
		"Opening the second page commits only the fourth chest")
	check(room.set_page(0), "The first page remains reachable after the fourth chest opens")
	for card in room._cards:
		room.begin_hold(card.button)
		room.advance_hold(Feel.HOLD_SECONDS)
	check(room.snapshot().chest_count == 4 and room.snapshot().opened_count == 4 and not room.has_pending()
		and saved.load_state() and saved._receipts.has(app._round_id),
		"Opening both pages completes the full four-chest batch with one durable round receipt")
	app.audio.halt()
	app.queue_free()
	await settle()


func _reward_conflict_checks(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory, "conflict-growth.cfg")
	app.jelly_reward_save_path = directory + "/conflict-jelly-rewards.cfg"
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/conflict-medals.cfg", directory + "/conflict-legacy.cfg")
	app._presentation.path = directory + "/conflict-presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	var external := RewardState.new(app.jelly_reward_save_path)
	external.storage_kind = "jelly"
	external.max_chests = 0
	external.allow_repeated_themes = true
	for next_mode in ["jelly", "memory"]:
		check(app.new_round(91, false, "", "jelly"), "A conflict fixture starts without pending local treasure")
		app._jelly.set_process(false)
		app.choose_theme("ocean")
		var game = app._jelly.game
		game.step(game.SETTLE_SECONDS)
		var chosen := pair(game, true)
		check(chosen.size() == 2, "The conflict fixture has an earned chest pair")
		if chosen.size() != 2:
			break
		game.try_merge(chosen[0].id, chosen[1].id)
		game.step(1.05)
		var local_id: String = app._round_id
		var foreign_id: String = "foreign-" + next_mode
		check(external.create_batch(foreign_id, ["spring"]), "Another tab can save treasure while this round is in progress")
		game.finish_round()
		check(not app._jelly_reward_saved and app._jelly_rewards._save_failed,
			"A conflicting saved batch does not mark this round's earned treasure as durable")
		Fixture.finish_celebration(app)
		app._show_jelly_rewards()
		var room = app._jelly_rewards
		room.set_process(false)
		room.retry_save()
		check(room.rewards.round_id == foreign_id and room._configured_id == foreign_id,
			"Conflict recovery first resumes the other tab's saved treasure")
		app.choose_theme("candy")
		check(app._jelly._theme.id == "ocean", "The result preview preserves this round's chest through a foreign save conflict")
		check(not app.new_round(92, false, "", "memory") and app._round_id == local_id,
			"Leaving cannot discard a finished round while its chest is still unsaved")
		check(room._draft_themes.size() == 1 and room._draft_themes[0] == "ocean",
			"The deferred reward retains its original theme after a world change")
		room.retry_save()
		room.begin_hold(room._cards[0].button)
		room.advance_hold(Feel.HOLD_SECONDS)
		check(not room.has_pending() and room.rewards.round_id == foreign_id,
			"The foreign batch can finish without falsely completing this round's reward")
		app._hide_jelly_rewards()
		var advanced: bool = app.new_round(93, false, "", next_mode)
		check(external.load_state() and external.round_id == local_id and external.entries.size() == 1
			and external.entries[0].theme == "ocean" and not external.entries[0].opened,
			"The deferred local chest is saved before %s can discard its result" % next_mode)
		if next_mode == "jelly":
			check(not advanced and app._jelly_rewards_shown and app._jelly_reward_saved,
				"Replay reveals the newly persisted local chest before a fresh board")
		else:
			check(advanced and app._mode_id == "memory", "Mode exit is safe once the local reward is durable")
			app.choose_mode("jelly")
			check(app._jelly_rewards_shown, "Returning restores the deferred local chest")
			app._jelly.set_process(false)
		room.begin_hold(room._cards[0].button)
		room.advance_hold(Feel.HOLD_SECONDS)
		check(external.load_state() and external.round_id == local_id and external.entries[0].opened
			and external._receipts.has(local_id) and external._receipts.has(foreign_id),
			"Both conflict batches complete once and retain their separate durable receipts")
		app._hide_jelly_rewards()
		check(app.new_round(94, false, "", "memory"), "A completed local reward permits the next game")
		check(external.load_state() and external.entries[0].opened and external.round_id == local_id,
			"Leaving an already saved round never recreates its reward batch")
	app.audio.halt()
	app.queue_free()
	await settle()

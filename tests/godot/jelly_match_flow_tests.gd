extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const RewardState = preload("res://scripts/pop_reward_state.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
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
		"A full board waits for every arrival in its final batch to settle before warning")


func earn_fragments(view, total: int) -> void:
	var game = view.game
	for attempt in range(400):
		view.advance_reward_presentation(8.0)
		if game.fragment_count >= total or game.phase != "playing":
			break
		game.step(game.SETTLE_SECONDS)
		var chosen: Array = []
		var unmarked: Array = []
		var budget: int = total - int(game.fragment_count)
		for a: Dictionary in game.cells:
			if not game.is_settled(a) or game.is_fusing(int(a.id)):
				continue
			for b: Dictionary in game.cells:
				if not game.is_settled(b) or game.is_fusing(int(b.id)):
					continue
				var reward: int = int(bool(a.chest)) + int(bool(b.chest))
				if a.word.id == b.word.id and a.kind != b.kind and reward > 0 and reward <= budget:
					chosen = [a, b]
					break
				elif a.word.id == b.word.id and a.kind != b.kind and reward == 0:
					unmarked = [a, b]
			if not chosen.is_empty():
				break
		if chosen.is_empty():
			chosen = unmarked
		if chosen.is_empty():
			var falling: bool = game.cells.any(func(cell: Dictionary) -> bool: return not game.is_settled(cell))
			game.step(game.SETTLE_SECONDS if falling else game.spawn_interval + game.SETTLE_SECONDS)
			continue
		check(game.try_merge(chosen[0].id, chosen[1].id) == "correct", "A real dragged pair contributes to the fragment reward fixture")
		game.step(game.FUSION_SECONDS)
	view.advance_reward_presentation(8.0)
	check(game.fragment_count == total, "Completed marked merges reach exactly %d chest fragments" % total)


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
	check(game.cells.size() == game.INITIAL_SETTLED_TILES and game.upcoming.size() == 4
		and game.cells.all(func(cell: Dictionary) -> bool: return game.is_settled(cell) and not cell.arrival)
		and app._jelly.snapshot().preview.slots.size() == 4,
		"The real game starts with settled tiles and a complete preview without dropping a batch")
	var chosen := pair(game, true)
	check(chosen.size() == 2, "The initial board contains a reachable marked pair")
	if chosen.size() != 2:
		app.queue_free()
		await settle()
		quit(1)
		return
	var word_id: String = str(chosen[0].word.id)
	var advertised: Array = game.snapshot().upcoming.duplicate(true)
	var tile_count: int = game.cells.size()
	app._jelly._sync_tiles()
	app._jelly.drop_button.grab_focus()
	app._controller_accept()
	check(game.cells.size() == tile_count + 4
		and game.cells.filter(func(cell: Dictionary) -> bool: return bool(cell.arrival) and is_zero_approx(float(cell.age))).size() == 4,
		"GameUI controller activation immediately drops the four advertised jellies")
	check(is_zero_approx(float(game.spawn_elapsed)) and app._jelly.drop_button.disabled,
		"Manual supply resets the full interval and blocks another activation while falling")
	app._controller_accept()
	check(game.cells.size() == tile_count + 4,
		"A repeated controller activation cannot dispatch another airborne batch")
	for tile: Dictionary in advertised:
		check(game.cells.any(func(cell: Dictionary) -> bool: return (int(cell.id) == int(tile.id)
			and cell.word == tile.word and cell.kind == tile.kind and cell.chest == tile.chest)),
			"Every advertised identity enters the real game unchanged")
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
	check(game.cleared_pairs == 1 and game.fragment_count == 1 and game.chest_count == 0,
		"Resuming completes one pair and one fragment without prematurely granting a chest")
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
	earn_fragments(app._jelly, 4)
	var earned_score: int = game.cleared_pairs
	game.finish_round()
	check(app._round_celebration.is_active() and not app._jelly.visible, "A positive result enters the shared Pip celebration")
	check(not app._jelly_backdrop.visible, "The shared reward presentation owns its own background")
	var summary: Dictionary = app._round_celebration.snapshot()
	check(app._round_result.score == earned_score and summary.score == earned_score and summary.title == "Round results"
		and summary.chest_tier == 1 and summary.caption == "Score: %d · Chest Lv. 1" % earned_score
		and is_equal_approx(app._round_celebration._heading.modulate.a, 1.0)
		and is_equal_approx(app._round_celebration._caption.modulate.a, 1.0),
		"The real result reports its actual score and single synthesized chest tier")
	check(app._jelly_rewards.has_pending() and FileAccess.file_exists(app.jelly_reward_save_path), "Earned treasure is durable before its result action")
	app._show_jelly_rewards()
	check(not app._jelly_rewards_shown, "Treasure cannot open through the celebration gate")
	var receipt: String = app._round_id
	game.finish_round()
	check(app._round_id == receipt and app._jelly_rewards.snapshot().chest_count == 1, "Finishing twice preserves one reward batch")
	Fixture.finish_celebration(app)
	check(app._jelly.visible and not app._round_celebration.is_active(), "The full result appears after celebration")
	check(app._jelly_backdrop.visible, "Jelly's settlement returns to its woodland setting")
	check(app._jelly.snapshot().score == earned_score and app._jelly.snapshot().result.title == "Round results"
		and app._jelly.snapshot().result.caption == summary.caption,
		"The persistent result retains the same score and chest summary after the animation")
	check(not app.new_round(52, false, "", "jelly") and app._jelly_rewards_shown, "Mode navigation resumes pending treasure before starting a new board")
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
		and app._jelly.snapshot().result.caption == "Score: 0 · Fragments: 0 / 4",
		"A new zero-loot round reports its own zero totals without stale score or victory copy")
	var zero_round_id: String = app._round_id
	app._jelly.replay_button.pressed.emit()
	check(app._round_id != zero_round_id and app._jelly.game.phase == "playing", "The zero-loot Play again button immediately starts another board")
	app._jelly.set_process(false)
	game = app._jelly.game
	earn_fragments(app._jelly, 3)
	game.finish_round()
	check(app._round_result.fragment_count == 3 and app._round_result.chest_count == 0
		and app._round_result.chest_tier == 0 and not app._round_celebration.is_active()
		and not app._jelly_rewards.has_pending(),
		"Ending below four fragments shows an honest result without saving or celebrating a chest")
	app._jelly.replay_button.pressed.emit()
	app._jelly.set_process(false)
	game = app._jelly.game
	earn_fragments(app._jelly, 4)
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
	await _tap_growth_checks(directory)
	await _warning_audio_flow(directory)
	await _upgraded_reward_checks(directory)
	await _reward_conflict_checks(directory)
	await _replay_reward_checks(directory)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly Match flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _tap_growth_checks(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory, "tap-growth.cfg")
	app.jelly_reward_save_path = directory + "/tap-jelly-rewards.cfg"
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/tap-medals.cfg", directory + "/tap-legacy.cfg")
	app._presentation.path = directory + "/tap-presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	check(app.new_round(51, false, "", "jelly"), "Tap regression starts a real Jelly round")
	var view = app._jelly
	view.set_process(false)
	await settle()
	view.game.step(view.game.SETTLE_SECONDS)
	view._sync_tiles()
	var chosen := pair(view.game)
	var other: Dictionary = {}
	for cell: Dictionary in view.game.cells:
		if cell.word.id != chosen[0].word.id:
			other = cell
			break
	var practiced: Array = [chosen[0].word.id, other.word.id]
	app.growth.record_attempt("tap-fixture-prior-learning", practiced, true)
	check(app.growth.streak(str(practiced[0])) == 1 and app.growth.streak(str(practiced[1])) == 1,
		"Both tapped words have saved progress that an incorrect judgment would erase")
	var saved: String = FileAccess.get_file_as_string(directory + "/tap-growth.cfg")
	var learned: Dictionary = app.growth.snapshot().streaks.duplicate()
	for pointer: int in [-1, 3]:
		for cell: Dictionary in [chosen[0], chosen[1], chosen[0], other, chosen[1]]:
			var point: Vector2 = view._tiles[int(cell.id)].get_global_rect().get_center()
			check(view._press(pointer, point), "A settled jelly accepts a pronunciation tap")
			view._release(point)
			check(view.game.fusion.is_empty() and view.game.cleared_pairs == 0 and view.game.chest_count == 0,
				"Matching and mismatching taps cannot start fusion or earn a reward")
	for cell: Dictionary in [chosen[0], chosen[1], other]:
		view._tiles[int(cell.id)].pressed.emit()
	check(app.growth.snapshot().streaks == learned
		and FileAccess.get_file_as_string(directory + "/tap-growth.cfg") == saved,
		"Mouse, touch and keyboard activation neither increment nor reset saved learning or attempt receipts")
	check(not app._jelly_rewards.has_pending(), "Pronunciation taps never create pending treasure")
	var target: Vector2 = view._tiles[int(chosen[1].id)].get_global_rect().get_center()
	view._press(-1, view._tiles[int(chosen[0].id)].get_global_rect().get_center())
	view._move(target)
	view._release(target)
	check(not view.game.fusion.is_empty(), "Dragging the same tapped pair still starts its normal fusion")
	for step: float in [0.4, 0.4, 0.25]:
		view._process(step)
	check(view.game.cleared_pairs == 1 and app.growth.streak(str(practiced[0])) == 2
		and app.growth.streak(str(practiced[1])) == 1,
		"Only the completed drag adds one learning success while leaving the other word intact")
	app.audio.halt()
	app.queue_free()
	await settle()


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
	await settle()
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
	app._jelly._sync_tiles()
	var target: Vector2 = app._jelly._tiles[int(chosen[1].id)].get_global_rect().get_center()
	app._jelly._press(-1, app._jelly._tiles[int(chosen[0].id)].get_global_rect().get_center())
	app._jelly._move(target)
	app._jelly._release(target)
	check(not game.fusion.is_empty() and not _jelly_cue_playing(app.audio, "danger") and _jelly_cue_playing(app.audio, "merge"),
		"A real dragged pair silences the warning while preserving its rescue merge sound")
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


func _upgraded_reward_checks(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory, "upgraded-growth.cfg")
	app.jelly_reward_save_path = directory + "/upgraded-jelly-rewards.cfg"
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/upgraded-medals.cfg", directory + "/upgraded-legacy.cfg")
	app._presentation.path = directory + "/upgraded-presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.new_round(104, false, "", "jelly"), "An upgraded reward round starts through GameUI")
	app._jelly.set_process(false)
	var game = app._jelly.game
	earn_fragments(app._jelly, 19)
	check(game.chest_count == 1 and game.chest_tier == 4 and game.fragment_count == 19,
		"Nineteen real fragments synthesize one chest and upgrade it three times")
	if game.chest_tier != 4:
		app.audio.halt()
		app.queue_free()
		await settle()
		return
	var cleared: int = game.cleared_pairs
	game.step(game.CAPACITY * game.spawn_interval + game.FULL_SECONDS + 1.0)
	app._round_celebration.set_process(false)
	var celebration: Dictionary = app._round_celebration.snapshot()
	check(game.phase == "finished" and game.cleared_pairs == cleared and app._round_result.score == cleared
		and app._round_result.chest_count == 1 and app._round_result.chest_tier == 4,
		"A natural full-board timeout preserves the single final upgraded chest")
	check(celebration.active and celebration.automatic and celebration.chest_count == 1 and celebration.chest_tier == 4
		and celebration.score == cleared and celebration.title == "Round results"
		and celebration.caption == "Score: %d · Chest Lv. 4" % cleared
		and app._round_celebration._count.text == "" and celebration.theme == RewardProgress.theme_for_tier(4),
		"The finale reports one Tier 4 chest with its final artwork rather than four separate rewards")
	var saved := RewardState.new(app.jelly_reward_save_path)
	saved.storage_kind = "jelly"
	saved.max_chests = 0
	saved.allow_repeated_themes = true
	check(saved.load_state() and saved.round_id == app._round_id and saved.entries.size() == 1
		and saved.entries[0].tier == 4 and saved.entries[0].theme == RewardProgress.theme_for_tier(4),
		"Only the final upgraded chest is durable before the celebration completes")
	Fixture.finish_celebration(app)
	check(not app._round_celebration.is_active() and app._jelly.snapshot().result.visible
		and app._round_result.chest_count == 1 and app._jelly.snapshot().score == cleared
		and app._jelly.snapshot().result.title == "Round results"
		and app._jelly.snapshot().result.caption == celebration.caption,
		"The completed celebration restores the same score and single upgraded reward")
	app._jelly.chests_button.pressed.emit()
	var room = app._jelly_rewards
	room.set_process(false)
	var first_page: Dictionary = room.snapshot()
	check(app._jelly_rewards_shown and first_page.chest_count == 1 and first_page.page_count == 1
		and first_page.page == 0 and first_page.visible_chest_count == 1 and first_page.chests[0].tier == 4
		and first_page.heading == "Chest Lv. 4",
		"The result action presents only the final upgraded chest to open")
	room.begin_hold(room._cards[0].button)
	room.advance_hold(Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 1 and saved.load_state() and saved.entries[0].opened
		and saved.entries[0].tier == 4 and not room.has_pending() and saved._receipts.has(app._round_id),
		"Opening the final chest completes the round with one durable receipt and no intermediate chests")
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
		earn_fragments(app._jelly, 9)
		var local_id: String = app._round_id
		var foreign_id: String = "foreign-" + next_mode
		check(external.create_batch(foreign_id, ["spring"]), "Another tab can save treasure while this round is in progress")
		game.finish_round()
		check(app._jelly_reward_saved and not app._jelly_rewards._save_failed,
			"Another tab's saved treasure is safely combined with this round's earned chest")
		Fixture.finish_celebration(app)
		var room = app._jelly_rewards
		room.set_process(false)
		check(external.load_state() and external.round_id == local_id and external.entries.size() == 2
			and external.entries[0].theme == "spring" and not external.entries[0].has("tier")
			and external.entries[1].theme == RewardProgress.theme_for_tier(2) and external.entries[1].tier == 2,
			"Another tab's old chest and this round's final upgraded chest retain their earned state")
		app.choose_theme("candy")
		check(app._jelly._theme.id == RewardProgress.theme_for_tier(2), "Changing the world cannot reroll this round's upgraded chest artwork")
		if next_mode == "jelly":
			app._jelly.replay_button.pressed.emit()
			check(app._round_id != local_id and app._jelly.game.phase == "playing"
				and app._jelly.visible and not app._jelly_rewards_shown and not app._jelly.game.paused,
				"Play again immediately starts a playable board with unopened treasure retained")
			var replay_id: String = app._round_id
			app._jelly.replay_button.pressed.emit()
			app._replay_jelly()
			check(app._round_id == replay_id, "Repeated replay activation cannot reset the new board")
			app._jelly.set_process(false)
			app._jelly.game.finish_round()
			await settle()
			check(not app._round_celebration.is_active() and app._round_result.chest_count == 0
				and app._jelly.chests_button.visible and app._jelly.chests_button.text == "Open chests",
				"A zero-loot follow-up reports its own totals and still offers saved treasure")
			check(not app._jelly.chests_button.get_global_rect().intersects(app._jelly.replay_button.get_global_rect()),
				"Retained treasure has a separate clickable action even when this round earns no chests: %s / %s" % [
					app._jelly.chests_button.get_global_rect(), app._jelly.replay_button.get_global_rect()])
			app._jelly.chests_button.pressed.emit()
		else:
			check(app.new_round(93, false, "", next_mode) and app._mode_id == "memory", "Mode exit is safe once the combined reward is durable")
			app.choose_mode("jelly")
			check(app._jelly_rewards_shown, "Returning restores all retained treasure")
			app._jelly.set_process(false)
		check(app._jelly_rewards_shown and room.snapshot().chest_count == 2, "Both saved chests remain reachable")
		for index in range(2):
			room.begin_hold(room._cards[index].button)
			room.advance_hold(Feel.HOLD_SECONDS)
		check(external.load_state() and external.round_id == local_id
			and external.entries.all(func(entry: Dictionary) -> bool: return entry.opened)
			and external._receipts.has(local_id) and external._receipts.has(foreign_id),
			"Both saved rounds open once and retain their durable receipts")
		app._hide_jelly_rewards()
		check(app.new_round(94, false, "", "memory"), "A completed local reward permits the next game")
		check(external.load_state() and external.entries[0].opened and external.round_id == local_id,
			"Leaving an already saved round never recreates its reward batch")
	app.audio.halt()
	app.queue_free()
	await settle()


func _replay_reward_checks(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory, "replay-growth.cfg")
	app.jelly_reward_save_path = directory + "/replay-jelly-rewards.cfg"
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/replay-medals.cfg", directory + "/replay-legacy.cfg")
	app._presentation.path = directory + "/replay-presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.new_round(91, false, "", "jelly"), "Consecutive reward rounds start")
	var ids: Array[String] = []
	for index in range(3):
		app._jelly.set_process(false)
		var game = app._jelly.game
		earn_fragments(app._jelly, 4 + index * 5)
		ids.append(app._round_id)
		var saved_text: String = FileAccess.get_file_as_string(app.jelly_reward_save_path) if index > 0 else ""
		if index == 2:
			app._jelly_rewards.rewards._path = directory + "/unavailable/rewards.cfg"
		game.finish_round()
		Fixture.finish_celebration(app)
		if index == 2:
			app._jelly.replay_button.pressed.emit()
			check(app._round_id == ids[index] and app._jelly_rewards_shown and app._jelly_rewards._save_failed,
				"A failed treasure save retains its finished round and exposes retry before replay")
			check(FileAccess.get_file_as_string(app.jelly_reward_save_path) == saved_text,
				"Failed saving leaves earlier rounds' unopened treasure intact")
			app._jelly_rewards.rewards._path = app.jelly_reward_save_path
			app._jelly_rewards.retry_save()
			check(not app._jelly_rewards._save_failed, "Retry saves this round together with earlier treasure")
			app._hide_jelly_rewards()
		check(app._jelly_rewards.snapshot().chest_count == index + 1 and app._round_result.chest_count == 1
			and app._round_result.chest_tier == index + 1
			and app._jelly_rewards.rewards.entries[index].tier == index + 1,
			"Consecutive rounds retain one final chest per round at its separately earned tier")
		app._jelly.replay_button.pressed.emit()
		check(app._round_id != ids[index] and app._jelly.game.phase == "playing" and not app._jelly_rewards_shown,
			"Each saved result can replay immediately without opening any treasure")
	var saved := RewardState.new(app.jelly_reward_save_path)
	saved.storage_kind = "jelly"
	saved.max_chests = 0
	saved.allow_repeated_themes = true
	check(saved.load_state() and saved.entries.size() == 3 and saved.has_pending(), "Reload restores the accumulated treasure")
	for index in range(ids.size()):
		check(saved.entries[index].tier == index + 1 and saved.entries[index].theme == RewardProgress.theme_for_tier(index + 1),
			"Reload preserves each replay's final tier and corresponding chest artwork")
		check(saved.create_batch(ids[index], ["spring"], [99]) and saved.entries.size() == 3
			and saved.entries[index].tier == index + 1,
			"A delayed finished-round callback cannot duplicate or overwrite upgraded treasure")
	app.audio.halt()
	app.queue_free()
	await settle()

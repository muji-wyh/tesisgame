extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Store = preload("res://scripts/word_jelly_campaign_store.gd")
const Banner = preload("res://scripts/word_jelly_stage_banner.gd")
var checks: int = 0
var failures: int = 0
var stage_presentations: Array[Dictionary] = []


class TreasureHost extends RefCounted:
	var text: String
	var writable: bool = true

	func jellyRewardState() -> String:
		return text

	func saveJellyRewardState(value: String) -> bool:
		if not writable:
			return false
		text = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func advance_app(app, delta: float) -> void:
	app._word_jelly._process(delta)
	app._advance_ui(delta)
	if app._round_celebration_active():
		Fixture.finish_celebration(app)
	var room = app._jelly_rewards
	room.advance_hold(delta)
	for card: Dictionary in room._cards:
		if card.art.mode == "opening":
			card.art._advance_animation(delta)


func finish_entry(app) -> void:
	for frame in range(40):
		advance_app(app, 0.05)


func finish_live_stage(app) -> void:
	finish_entry(app)
	var game = app._word_jelly.game
	game.cells.clear()
	game.upcoming.clear()
	game._supply.clear()
	game._supply_pending.clear()
	for index in range(game.stage_run.words.size()):
		var word: Dictionary = game.stage_run.words[index]
		var tile: Dictionary = game._new_word_root(word)
		game._set_merged_word(tile, word, 1, true)
		tile.column = index
		tile.row = 7
		tile.age = 100.0
		tile.settling = false
		game.cells.append(tile)
	for tile: Dictionary in game.cells.duplicate(true):
		check(game.collect(int(tile.id)), "The real campaign collects each live stage goal")
		game.step(game.COLLECT_SECONDS)
	for frame in range(400):
		advance_app(app, 0.05)
		var room = app._jelly_rewards
		var feedback: Dictionary = room.snapshot().get("stage_feedback", {})
		if not feedback.is_empty():
			feedback["formula_readable"] = room._result_score.is_visible_in_tree() \
				and room._result_score.text.contains("×") and room._result_score.get_line_count() == 1 \
				and room._result_score.get_visible_line_count() == 1
			feedback["bonus_readable"] = room._stage_bonus_label.is_visible_in_tree() \
				and room._stage_bonus_label.get_line_count() == 2 \
				and room._stage_bonus_label.get_visible_line_count() == 2
			if room.is_visible_in_tree() and feedback.get("phase") == "bonus":
				check(feedback.formula_readable and feedback.bonus_readable,
					"Every clear keeps its multiplier and both coin-caption lines readable, including real chest results")
			stage_presentations.append(feedback)
		if app._campaign.map.visible:
			break


func test_map_chest_retry(app) -> void:
	var room = app._jelly_rewards
	room.set_result_context({})
	var id: String = app._round_id + ":map-recovery"
	var themes: Array[String] = ["spring"]
	var tiers: Array[int] = [1]
	check(room.rewards.create_batch(id, themes, tiers) and room.configure_saved(app.data.chests, true),
		"Map recovery starts with a genuinely saved unopened chest and reserved wallet quote")
	var reward_id: String = room.rewards._reward_id(id, 0)
	var amount: int = int(app.coin_wallet.chest_reward(reward_id).total)
	var result: Dictionary = app._campaign._result_draft.duplicate(true)
	result.chest_count = 1
	result.chest_tier = 1
	result.chest_coins = amount
	result.bonus = 0
	check(app._campaign.store.queue_result("growth", id, result), "Journal the exact unpaid map-recovery result")
	var before: int = app.coin_wallet.balance
	var host := TreasureHost.new()
	host.text = FileAccess.get_file_as_string(room.rewards._path)
	host.writable = false
	room.rewards._host = host
	app._campaign.open_map()
	check(not app._campaign.error.is_empty() and room._save_failed
		and not app._campaign.store.pending("growth").is_empty(),
		"A failed mark-opened write retains both the chest operation and campaign journal on the map")
	host.writable = true
	app._campaign.retry()
	check(app._campaign.error.is_empty() and not room._save_failed and not room.has_pending()
		and app._campaign.store.pending("growth").is_empty() and app.coin_wallet.balance == before + amount,
		"Map Retry repairs the retained chest operation and completes its journal without crediting twice")


func test_retained_treasure_does_not_block_empty_clear(app) -> void:
	app._campaign.request_stage(1)
	await settle()
	app._word_jelly.set_process(false)
	var room = app._jelly_rewards
	var id: String = app._round_id + ":older-treasure"
	var themes: Array[String] = ["spring"]
	var tiers: Array[int] = [1]
	check(room.rewards.create_batch(id, themes, tiers), "Retain a real earlier treasure batch alongside the live attempt")
	var reward_id: String = room.rewards._reward_id(id, 0)
	check(app._reserve_chest_reward(reward_id, 1).ok, "The retained chest keeps its own immutable wallet quote")
	var amount: int = int(app.coin_wallet.chest_reward(reward_id).total)
	var before: int = app.coin_wallet.balance
	finish_live_stage(app)
	check(app._campaign.map.visible and not room.has_pending()
		and app.coin_wallet.balance == before + amount + 150,
		"A no-new-chest clear settles retained treasure separately and returns to its map without weighting it again")


func test_home_confirmation_and_feedback(app) -> void:
	app._campaign.request_stage(1)
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	finish_entry(app)
	var game = view.game
	game.cells.clear()
	game.upcoming.clear()
	game._supply.clear()
	game._supply_pending.clear()
	for index in range(4):
		var word: Dictionary = game.stage_run.words[index % game.stage_run.words.size()]
		var tile: Dictionary = game._new_word_root(word)
		game._set_merged_word(tile, word, 4 if index == 0 else 1, true)
		tile.fragments = 1
		tile.column = index
		tile.row = 7
		tile.age = 100.0
		tile.settling = false
		game.cells.append(tile)
	view._sync_tiles()
	var round_id: String = app._round_id
	var before: Dictionary = game.snapshot()
	app._mode_heading_button.pressed.emit()
	check(app._finish_confirmation_open() and not app._mode_menu_open() and game.paused,
		"The actual Home action asks for confirmation before abandoning the live stage")
	if not app._finish_confirmation_open():
		app._hide_mode_menu()
		game.finish_round()
		for frame in range(240):
			advance_app(app, 0.05)
			if app._campaign.map.visible:
				return
		return
	var dialog = app._finish_confirmation
	var original_size: Vector2 = dialog.size
	for dimensions in [Vector2(393, 852), Vector2(320, 480)]:
		dialog.size = dimensions
		await settle()
		check(dialog._caption.get_global_rect().end.y + 4.0 <= dialog.keep_playing_button.get_global_rect().position.y,
			"The complete Home-exit explanation fits above the phone's confirmation buttons at %s" % dimensions)
	dialog.size = original_size
	await settle()
	view._process(2.0)
	check(game.stage_run.remaining == before.campaign.seconds_remaining and game.cleared_pairs == 0,
		"Waiting for the exit decision neither consumes stage time nor collects rewards")
	app._finish_confirmation.keep_playing_button.pressed.emit()
	check(not app._finish_confirmation_open() and not game.paused and app._round_id == round_id,
		"Canceling Home exit resumes the exact same attempt")
	app._mode_heading_button.pressed.emit()
	app._finish_confirmation.finish_button.pressed.emit()
	check(game.stage_ending() and not game.paused and not app._mode_menu_open(),
		"Confirming Home starts the normal forced collection sweep rather than opening the library early")
	var saw_feedback: bool = false
	var unearned_confetti: bool = false
	for frame in range(400):
		advance_app(app, 0.05)
		unearned_confetti = unearned_confetti or app._reward_confetti.snapshot().keys.has(round_id + ":round-clear")
		var effects: Dictionary = view.snapshot().collection_effects
		var reveal: Dictionary = view.snapshot().word_reveal
		if effects.active_count > 0 or reveal.active_count > 0:
			saw_feedback = true
			check(not app._round_end_active() and not app._settlement_dialog_open(),
				"Round complete and settlement wait while any last pickup effect is still running")
		if app._mode_menu_open():
			break
	check(saw_feedback and game.cleared_pairs == 4 and game.phase == "finished"
		and game.stage_run.outcome == "exit" and app._mode_menu_open()
		and not app._campaign.map.visible and app._campaign.store.pending("growth").is_empty(),
		"A confirmed Home exit drains all four merged words and their effects, settles and only then opens Home: %s"
		% JSON.stringify({"phase": game.phase, "ending": game.stage_ending(), "home": app._mode_menu_open(),
			"cleared": game.cleared_pairs, "settling": app._campaign.settling,
			"room_opening": app._jelly_rewards._opening, "error": app._campaign.error}))
	check(not unearned_confetti, "A voluntary stage exit cannot launch an unearned clear celebration")
	app.choose_mode("word_jelly")
	await settle()
	check(app._campaign.map.visible and not app._mode_menu_open() and game.phase == "finished",
		"Entering Jelly World again opens the stage map instead of resuming the abandoned board")


func test_rating_segments() -> void:
	var banner := Banner.new()
	root.add_child(banner)
	banner.configure_layout(Rect2(0, 0, 360, 44), Rect2(0, 60, 360, 500), 1.0)
	var state: Dictionary = {"kind": "main", "number": 1, "total": 3, "mastered": 0,
		"seconds_total": 90.0, "seconds_remaining": 90.0, "time_elapsed": 0.0, "stars_now": 3}
	banner.set_stage(state, true)
	var slots: Array = banner.snapshot().get("rating_segments", [])
	check(slots.size() == 3, "The timer exposes one separate star for each of its three progress segments")
	check(banner._label.get_line_count() == 1,
		"The timed-stage caption stays on one row above the rating stars")
	for slot: Dictionary in slots:
		var star: Rect2 = Rect2(slot.star[0], slot.star[1], slot.star[2], slot.star[3])
		var bar: Rect2 = Rect2(slot.bar[0], slot.bar[1], slot.bar[2], slot.bar[3])
		check(star.get_center().x >= bar.position.x and star.get_center().x <= bar.end.x,
			"Each rating star is horizontally centered over its own progress segment")
		check(not banner._label.get_rect().intersects(star),
			"Clock text cannot wrap down into the star row after a taller timer layout")
	state.time_elapsed = 31.0
	state.seconds_remaining = 59.0
	state.stars_now = 2
	banner.set_stage(state)
	check(banner.snapshot().get("star_loss_active", false),
		"Crossing an original-budget rating boundary starts a bounded star-loss effect")
	banner.advance(0.2)
	var elapsed: Variant = banner.snapshot().get("star_loss_elapsed", [])
	banner.set_stage(state)
	check(banner.snapshot().get("star_loss_elapsed", []) == elapsed,
		"Refreshing the same timer state cannot replay its star-loss animation")
	banner.advance(0.6)
	check(not banner.snapshot().get("star_loss_active", false),
		"The lost star settles to its muted state after the short animation")
	banner.reduced_motion = true
	state.time_elapsed = 61.0
	state.seconds_remaining = 29.0
	state.stars_now = 1
	banner.set_stage(state)
	check(not banner.snapshot().get("star_loss_active", false),
		"Reduced motion updates the earned star slots without flying or flashing")
	banner.free()


func test_settlement_caption_scaling(room) -> void:
	for ui_scale in [0.8125, 1.0, 1.6, 2.0]:
		room._layout_result_dialog(ui_scale, 448.0 / ui_scale, 268.0 / ui_scale)
		check(room._result_score.get_line_count() == 1 and room._result_score.get_visible_line_count() == 1
			and room._stage_bonus_label.get_line_count() == 2 and room._stage_bonus_label.get_visible_line_count() == 2,
			"The real multiplier and clear-coins text remain unclipped at UI scale %s" % ui_scale)
		check(Rect2(Vector2.ZERO, room._stage_rating.size).grow(0.1).encloses(room._stage_bonus_label.get_rect()),
			"The complete two-line coin count fits its star presentation at UI scale %s: %s" % [
				ui_scale, JSON.stringify({"group": room._stage_rating.size,
					"caption": room._stage_bonus_label.get_rect(), "font": room._stage_bonus_label.get_theme_font_size("font_size"),
					"minimum": room._stage_bonus_label.get_minimum_size()})])
	room._layout()


func test_stage_deadline_border(app) -> void:
	app._campaign.request_stage(1)
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	finish_entry(app)
	var game = view.game
	var attempt = game.stage_run
	attempt.advance(attempt.remaining - 10.001)
	view._refresh_danger()
	check(not view._danger_frame.is_visible_in_tree() and not view.snapshot().danger.active,
		"The stage deadline does not flash the border before its final ten seconds")
	attempt.advance(0.002)
	view._refresh_danger()
	check(view._danger_frame.is_visible_in_tree() and view.snapshot().danger.active
		and view.snapshot().danger.get("source") == "stage" and game.full_elapsed < 0.0,
		"The real frame starts its final-ten-second warning even on a non-full board")
	var early: float = float(view._danger_frame.state.get("urgency", 0.0))
	attempt.advance(5.0)
	view._refresh_danger()
	check(float(view._danger_frame.state.get("urgency", 0.0)) > early,
		"The existing sourced rim light grows more urgent as the stage deadline approaches")
	var reduced: bool = view.reduced_motion
	view.reduced_motion = true
	view._refresh_danger()
	check(not view._danger_frame.state.get("moving", true)
		and is_equal_approx(float(view._danger_frame.state.get("pulse", 0.0)), 0.65),
		"Reduced motion keeps a still deadline rim instead of flashing or orbiting glints")
	view.reduced_motion = reduced
	game.full_elapsed = 8.0
	view._refresh_danger()
	check(view.snapshot().danger.get("source") == "full" and view.snapshot().danger.get("elapsed") == 8.0,
		"A more urgent full-board clock owns the single border instead of stacking another flash")
	game.full_elapsed = -1.0
	view.pause(true)
	var before: float = attempt.remaining
	game.step(8.0)
	view._refresh_danger()
	check(attempt.remaining == before and not view._danger_frame.is_visible_in_tree(),
		"Pausing freezes the stage deadline and suppresses its flashing frame")
	view.pause(false)
	check(game.activate_powerup("extra_time"), "A real saved extra-time purchase can rescue the deadline")
	view._refresh_danger()
	check(attempt.remaining > 10.0 and not view._danger_frame.is_visible_in_tree()
		and not view.snapshot().danger.active and attempt.stars_now() == 1,
		"Bought time cancels the deadline border without restoring an expired star tier")


func _run() -> void:
	test_rating_segments()
	var intro := Banner.new()
	root.add_child(intro)
	intro.set_stage({"kind": "main", "number": 1, "total": 3, "mastered": 0,
		"seconds_total": 180.0, "seconds_remaining": 180.0, "time_elapsed": 0.0, "stars_now": 3}, true)
	intro.configure_layout(Rect2(0, 0, 264, 24), Rect2(0, 35, 264, 422), 0.8125)
	await settle()
	check(Rect2(Vector2.ZERO, intro._card.size).grow(0.1).encloses(intro._title.get_rect())
		and not intro._title.get_rect().intersects(intro._detail.get_rect()),
		"An initially zero-width phone intro reflows its title inside its card, above the goal caption")
	intro.free()
	check(ResourceLoader.exists("res://scripts/word_jelly_campaign.gd"),
		"The application has an independently testable campaign coordinator")
	if failures:
		print("Jelly campaign flow: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	AudioServer.set_bus_mute(0, true)
	var directory: String = "user://campaign-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Campaign flow uses isolated saves")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	if app.get("jelly_campaign_save_path") != null:
		app.jelly_campaign_save_path = directory + "/campaign.cfg"
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_process(false)
	check(app.get("_campaign") != null, "The real application owns the campaign map and settlement coordinator")
	if app.get("_campaign") == null:
		app.free()
		print("Jelly campaign flow: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	app._show_mode_menu()
	app.choose_mode("word_jelly")
	await settle()
	check(app._campaign.map.is_visible_in_tree() and not app._mode_menu_open()
		and app._campaign.map.snapshot().stage_nodes.size() == 99,
		"Choosing Jelly Words enters its real 99-stage map, not an unbound endless board")
	var first_state: Dictionary = app._campaign.map.snapshot()
	check(first_state.stage_nodes[0].unlocked and not first_state.stage_nodes[1].unlocked,
		"A new campaign exposes only its first frontier")
	app._campaign.request_stage(2)
	check(app._campaign.map.visible and not app._campaign.starting,
		"A stale locked-stage callback cannot skip the persistent frontier")
	app.audio.set_muted(false)
	app._campaign.request_stage(1)
	await settle()
	check(app.audio.active and app.audio.music.playing,
		"A synchronous map start restores gameplay audio after the old round's halt")
	app.audio.set_muted(true)
	var view = app._word_jelly
	view.set_process(false)
	check(not app._campaign.map.visible and view.game.stage_run != null
		and view.game.stage_run.number == 1 and view.game.stage_run.goals.size() == 3,
		"Starting the first unlocked stage binds its three fixed per-attempt word goals")
	finish_live_stage(app)
	await settle()
	check(app._campaign.map.visible and app._campaign.store.highest_cleared("growth") == 1
		and app._campaign.store.best_stars("growth", 1) == 3,
		"An automatic completed settlement returns to the map and persists the best three-star clear")
	check(app.coin_wallet.balance == 150 and app._coin_counter.target == 150
		and app._campaign.store.pending("growth").is_empty(),
		"Three-star weighting pays one exact 150-coin first-stage bonus before unlocking")
	check(stage_presentations.any(func(state: Dictionary) -> bool: return state.get("phase") == "stars")
		and stage_presentations.any(func(state: Dictionary) -> bool: return state.get("phase") == "bonus"),
		"Settlement presents the earned stars sequentially and then animates their coin multiplier before wallet arrival")
	check(stage_presentations.any(func(state: Dictionary) -> bool:
		return state.get("phase") == "bonus" and state.get("formula_readable", false) \
			and state.get("bonus_readable", false)),
		"The real settlement displays its full star-multiplier formula and unclipped clear-coin caption")
	test_settlement_caption_scaling(app._jelly_rewards)
	var restored := Store.new(directory + "/campaign.cfg")
	check(restored.load_state() and restored.best_stars("growth", 1) == 3 and restored.available("growth", 2),
		"Reloading actual campaign storage preserves stars and the next unlocked stage")
	app._campaign.request_stage(1)
	await settle()
	view.set_process(false)
	view.game.stage_run.advance(view.game.stage_run.initial_seconds * 0.70)
	finish_live_stage(app)
	check(app._campaign.store.best_stars("growth", 1) == 3 and app.coin_wallet.balance == 225,
		"A one-star replay pays its own exact reward without downgrading the saved three stars")
	app._campaign.request_stage(1)
	await settle()
	view.set_process(false)
	var wallet_path: String = app.coin_wallet._path
	app.coin_wallet._path = directory + "/missing/coins.cfg"
	finish_live_stage(app)
	check(app._campaign.settling and not app._campaign.error.is_empty()
		and not app._campaign.store.pending("growth").is_empty() and app.coin_wallet.balance == 225,
		"A failed star-bonus save retains the immutable settlement journal without claiming payment")
	check(app._jelly_rewards._retry.is_visible_in_tree() and not app._jelly_rewards._retry.disabled
		and app._valid_focus(app._jelly_rewards._retry)
		and app._jelly_rewards.snapshot().error == app._campaign.error,
		"Campaign payment failure exposes its actual error and an actionable retry inside the blocking result dialog")
	var recovered := Store.new(directory + "/campaign.cfg")
	check(recovered.load_state() and not recovered.pending("growth").is_empty(),
		"The unpaid settlement is genuinely present on disk before recovery")
	app.coin_wallet._path = wallet_path
	check(app.coin_wallet.load_state(), "Recovery reloads the authoritative wallet without a partial bonus")
	app._jelly_rewards._retry.pressed.emit()
	check(app._campaign.error.is_empty(),
		"The visible result-dialog retry clears and retries coordinator storage, not only chest storage")
	app._campaign.store = recovered
	app._campaign.settling = false
	app._campaign.error = ""
	app._campaign._result_draft.clear()
	app._campaign.open_map()
	check(app._campaign.map.visible and app.coin_wallet.balance == 375
		and app._campaign.store.pending("growth").is_empty(),
		"Opening the map after a lost coordinator recovers and pays the original pending result once")
	app._campaign.open_map()
	check(app.coin_wallet.balance == 375,
		"Opening a recovered map again cannot repeat its star bonus")
	check(app.growth.record_attempt("challenge-current-targets", ["cat", "dog", "duck"], false).save_ok,
		"Leave the three visible learning targets outstanding independently of earlier clears")
	var review_ids: Array = app.data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) == 3 and str(word.id) not in ["cat", "dog", "duck"]).map(
		func(word: Dictionary) -> String: return str(word.id))
	for attempt in range(3):
		check(app.growth.record_attempt("challenge-review-%d" % attempt, review_ids, true).save_ok,
			"Seed real saved review words while leaving three current learning targets")
	app._campaign.request_challenge()
	await settle()
	view.set_process(false)
	check(view.game.stage_run.kind == "challenge" and view.game.stage_run.initial_seconds == 90.0
		and view._stage_banner.snapshot().label.contains("1:30"),
		"The Challenge entrance starts its real ninety-second Stage 1 rather than a numbered campaign stage")
	check(view._stage_banner._title.text == "Ready?" and view._stage_banner._detail.text.contains("90s"),
		"The challenge introduction never presents a fictitious stage zero or mastery quota")
	check(view.snapshot().practice.words.size() == 3,
		"Challenge shows its first batch of three explicit timed collection goals")
	var active_ids: Array = view.game._words.map(func(word: Dictionary) -> String: return str(word.id))
	active_ids.sort()
	check(active_ids == ["cat", "dog", "duck"],
		"A challenge starts with outstanding learning targets before adding mastered review words")
	view.game.finish_round()
	for frame in range(180):
		view._process(0.05)
		app._advance_ui(0.05)
		if app._campaign.map.visible:
			break
	check(app._campaign.map.visible and app._campaign.store.highest_cleared("growth") == 1,
		"An untimed challenge settles and returns to its map without unlocking a numbered stage")
	app._campaign.request_stage(1)
	await settle()
	view.set_process(false)
	for attempt in range(3):
		app._record_growth("campaign-grow-%d" % attempt, ["cat", "dog", "duck"], true)
	check(app.growth.learning_age() == 4 and app._matches_current_learning_context("word_jelly"),
		"A live bound campaign keeps its frozen round when Pip advances to the next learning age")
	view.game.stage_run.advance(view.game.stage_run.initial_seconds * 0.4)
	app._refresh_jelly_stage_targets()
	var before_extension: float = float(view._stage_banner.snapshot().get("timer_ratio", -1.0))
	view.game.stage_run.add_time("rating-view-extension")
	app._refresh_jelly_stage_targets()
	check(is_equal_approx(float(view._stage_banner.snapshot().get("timer_ratio", -1.0)),
		minf(1.0, view.game.stage_run.remaining / view.game.stage_run.initial_seconds))
		and float(view._stage_banner.snapshot().get("timer_ratio", -1.0)) > before_extension
		and view._stage_banner.snapshot().stars_now == 2,
		"Extra time refills the remaining-time bar without restoring an expired original-budget star")
	app._pause_jelly()
	check(app._jelly_pause_open() and view.game.paused, "A bound campaign stage supports inline pause")
	app._campaign.context_key = "professional:retail:module03"
	view.finish_button.finish_committed.emit()
	check(not app._jelly_pause_open() and not view.game.paused and view.game.stage_ending(),
		"A deliberate paused pull resumes the forced end sweep instead of deadlocking it behind pause")
	for frame in range(200):
		view._process(0.05)
		if view.game.phase == "finished":
			break
	check(not app._campaign.store.pending("growth").is_empty()
		and app._campaign.store.pending("professional:retail:module03").is_empty(),
		"A departing round journals against its bound context, not a newly browsed campaign")
	app._campaign.context_key = "growth"
	for frame in range(180):
		view._process(0.05)
		app._advance_ui(0.05)
		if app._campaign.map.visible:
			break
	check(app._campaign.map.visible and app._campaign.store.best_stars("growth", 1) == 3
		and app.coin_wallet.balance == 375,
		"A paused pull settles the abandoned stage once without a clear bonus or lost best rating")
	test_map_chest_retry(app)
	await test_retained_treasure_does_not_block_empty_clear(app)
	await test_home_confirmation_and_feedback(app)
	await test_stage_deadline_border(app)
	app.audio.halt()
	app.free()
	await settle()
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly campaign flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

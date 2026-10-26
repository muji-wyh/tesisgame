extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Store = preload("res://scripts/word_jelly_campaign_store.gd")
const Banner = preload("res://scripts/word_jelly_stage_banner.gd")
var checks: int = 0
var failures: int = 0


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


func finish_live_stage(app) -> void:
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
	for frame in range(180):
		game.step(0.05)
		app._advance_ui(0.05)
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


func _run() -> void:
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
	check(view.game.stage_run.kind == "challenge" and view.game.stage_run.initial_seconds == 0.0
		and view._stage_banner.snapshot().label.to_lower().contains("challenge"),
		"The separate challenge entrance starts a real untimed board rather than a fake numbered stage")
	check(view._stage_banner._title.text == "Challenge" and view._stage_banner._detail.text.contains("No timer"),
		"The challenge introduction never presents a fictitious stage zero or mastery quota")
	check(view.snapshot().practice.words.size() == 3,
		"Challenge keeps the three active words' real saved learning progress visible")
	var active_ids: Array = view.game._words.map(func(word: Dictionary) -> String: return str(word.id))
	active_ids.sort()
	check(active_ids == ["cat", "dog", "duck"],
		"A challenge starts with outstanding learning targets before adding mastered review words")
	view.game.finish_round()
	for frame in range(180):
		view.game.step(0.05)
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
	view.game.stage_run.add_time("rating-view-extension")
	app._refresh_jelly_stage_targets()
	check(is_equal_approx(float(view._stage_banner.snapshot().get("timer_ratio", -1.0)), 0.6)
		and view._stage_banner.snapshot().stars_now == 2,
		"Extra time extends the deadline without visually refilling the original three-phase star bar")
	app._pause_jelly()
	check(app._jelly_pause_open() and view.game.paused, "A bound campaign stage supports inline pause")
	app._campaign.context_key = "professional:retail:module03"
	view.finish_button.finish_committed.emit()
	check(not app._jelly_pause_open() and not view.game.paused and view.game.stage_ending(),
		"A deliberate paused pull resumes the forced end sweep instead of deadlocking it behind pause")
	view.game.step(0.05)
	check(not app._campaign.store.pending("growth").is_empty()
		and app._campaign.store.pending("professional:retail:module03").is_empty(),
		"A departing round journals against its bound context, not a newly browsed campaign")
	app._campaign.context_key = "growth"
	for frame in range(180):
		view.game.step(0.05)
		app._advance_ui(0.05)
		if app._campaign.map.visible:
			break
	check(app._campaign.map.visible and app._campaign.store.best_stars("growth", 1) == 3
		and app.coin_wallet.balance == 375,
		"A paused pull settles the abandoned stage once without a clear bonus or lost best rating")
	test_map_chest_retry(app)
	await test_retained_treasure_does_not_block_empty_clear(app)
	app.audio.halt()
	app.free()
	await settle()
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly campaign flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

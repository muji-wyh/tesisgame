extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Progress = preload("res://scripts/medal_progress.gd")
const RewardState = preload("res://scripts/pop_reward_state.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const Flight = preload("res://scripts/coin_reward_flight.gd")

var checks: int = 0
var failures: int = 0
var serial: int = 0


class Storage extends RefCounted:
	var coins: Variant = null
	var jelly: Variant = null
	var coin_writable: bool = true
	var reward_writable: bool = true
	var coin_writes: int = 0

	func coinWalletState() -> Variant:
		return coins

	func saveCoinWalletState(value: String, expected: Variant) -> bool:
		if not coin_writable or expected != coins:
			return false
		coins = value
		coin_writes += 1
		return true

	func jellyRewardState() -> Variant:
		return jelly

	func saveJellyRewardState(value: String) -> bool:
		if not reward_writable:
			return false
		jelly = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func make_app(storage = null):
	serial += 1
	var directory := "user://jelly-result-coins-%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), serial]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Jelly results use isolated save files")
	var host = Storage.new() if storage == null else storage
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.coin_wallet = Wallet.new(directory + "/coins.cfg", host)
	app.medal_progress = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.reduced_motion = false
	app._presentation.has_motion_override = true
	check(app._presentation.save_preferences(), "The result fixture saves muted normal-motion preferences")
	app._mode_id = "jelly"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	for node in [app, app._memory, app._phrase, app._pop, app._jelly, app._round_celebration, app.chest, app._jelly_rewards]:
		node.set_process(false)
	check(app._jelly_rewards.connect_storage(host), "The Jelly room shares isolated durable storage with the wallet")
	check(app.new_round(51, false, "", "jelly", "", false), "GameUI starts a seeded fresh Jelly board")
	app.set_meta("result_test_storage", host)
	await settle()
	return app


func dispose(app) -> void:
	app.audio.halt()
	app.queue_free()
	await settle()


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
		if game.try_merge(chosen[0].id, chosen[1].id) != "correct":
			check(false, "A real complementary pair starts the reward fixture's fusion")
			break
		game.step(game.FUSION_SECONDS)
	view.advance_reward_presentation(8.0)
	check(game.phase == "playing" and game.fragment_count == total,
		"Real completed Jelly fusions earn exactly %d fragments" % total)


func finish_result(app, tier: int) -> void:
	var fragments: int = 0 if tier == 0 else 4 + (tier - 1) * 5
	earn_fragments(app._jelly, fragments)
	var score: int = app._jelly.game.score()
	app._jelly.finish_button.pressed.emit()
	check(app._jelly.game.phase == "finished" and int(app._round_result.score) == score,
		"The real Finish control records the completed Jelly score")
	check(int(app._round_result.chest_tier) == tier and int(app._round_result.chest_count) == (0 if tier == 0 else 1),
		"Finishing keeps only the final synthesized chest tier")
	check(app.coin_wallet.balance == 0 and not app._coin_flight.snapshot().active,
		"Earning a result chest alone does not credit or animate coins")
	if tier > 0:
		check(app._round_celebration.is_active() and not app._jelly_rewards_shown,
			"The reward celebration gates the interactive result chest")
		Fixture.finish_celebration(app)
		check(app._jelly_rewards_shown and app._jelly_rewards.is_visible_in_tree()
			and not app._round_celebration.is_active(),
			"Celebration leads directly to an interactive result chest without an Open chest navigation step")
		check(app._jelly_backdrop.is_visible_in_tree(), "Interactive Jelly results retain the woodland background")
		check_result_context(app, score, tier)
		check(app._jelly_rewards._cards.size() > 0 and not app._jelly_rewards._cards[0].button.disabled,
			"The earned chest can be held directly on the result screen")
	else:
		check(not app._round_celebration.is_active() and app._jelly.is_visible_in_tree()
			and app._jelly.replay_button.is_visible_in_tree(),
			"A zero-chest finish exposes its ordinary result and immediate replay without a false reward")


func check_result_context(app, score: int, tier: int) -> void:
	var room = app._jelly_rewards
	check(int(room.snapshot().result_context.get("score", -1)) == score and int(room.snapshot().result_context.get("chest_tier", -1)) == tier,
		"The result room retains the actual round score and earned tier")
	check(room._heading.text == "Round results" and room._heading.is_visible_in_tree()
		and room._result_score.text == str(score) and room._result_score.is_visible_in_tree(),
		"Score and result heading remain visible alongside the interactive chest")
	check(room._back.text == "Play again" and room._back.is_visible_in_tree(),
		"The interactive result offers a direct Play again action")


func start_open(room) -> void:
	room._cards[0].art.set_process(false)
	room._cards[0].button.button_down.emit()
	room.advance_hold(Feel.HOLD_SECONDS)
	check(room._opening, "The result chest starts opening through its real hold control")


func check_new_board(app, old_round: String, amount: int) -> void:
	check(app._round_id != old_round and app._mode_id == "jelly" and app._jelly.game.phase == "playing"
		and app._jelly.is_visible_in_tree() and not app._jelly.game.paused and not app._jelly_rewards_shown,
		"Play again immediately replaces the result with a fresh playable Jelly board")
	check(app._round_result.is_empty() and not app._jelly_rewards.has_pending(),
		"Replay clears the old result only after all remaining treasure is consumed")
	check(app.coin_wallet.balance == amount and not app._coin_flight.snapshot().active
		and app._coin_flight.snapshot().target == amount and app._coin_flight.snapshot().displayed == float(amount),
		"Replay silently settles all earned coins into the visible wallet before gameplay resumes")
	var fresh_id: String = app._round_id
	var writes: int = app.get_meta("result_test_storage").coin_writes
	app._jelly_rewards.replay_requested.emit()
	app._jelly.replay_button.pressed.emit()
	app._coin_flight.advance(10.0)
	check(app._round_id == fresh_id and app.coin_wallet.balance == amount
		and app.get_meta("result_test_storage").coin_writes == writes and not app._coin_flight.snapshot().active,
		"Queued or repeated replay clicks cannot restart the new board or pay an old chest twice")


func check_interactive_result(tier: int) -> void:
	var app = await make_app()
	finish_result(app, tier)
	var room = app._jelly_rewards
	var score: int = app._round_result.score
	var receipt: String = room._cards[0].reward_id
	start_open(room)
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS + 0.01)
	check(room.rewards.entries[0].opened and app.coin_wallet.balance == tier * 50
		and app.coin_wallet._receipts.has(receipt), "Opening the result chest saves its final-tier coin receipt")
	check_result_context(app, score, tier)
	check(app._coin_flight.snapshot().active and app._coin_flight.snapshot().target == 0
		and app._coin_flight.snapshot().displayed == 0.0,
		"The result counter waits for flying coins instead of immediately revealing the saved total")
	app._refresh()
	app._coin_flight.advance(Flight.BURST_SECONDS + Flight.TRAVEL_SECONDS - 0.001)
	check(app._coin_flight.snapshot().target == 0, "A result refresh and pre-arrival animation cannot increment the coin counter")
	app._coin_flight.advance(0.002)
	check(app._coin_flight.snapshot().target > 0 and app._coin_flight.snapshot().target < tier * 50,
		"The first arriving result coin releases only its share of the payout")
	app._coin_flight.advance(2.0)
	check(app._coin_flight.snapshot().displayed == float(tier * 50) and not app._coin_flight.snapshot().active,
		"The complete result flight finishes at the durable coin balance")
	room._finished(0)
	room._announce(0)
	check(app.get_meta("result_test_storage").coin_writes == 1 and not app._coin_flight.snapshot().active,
		"Repeated result opening callbacks cannot pay or animate an already opened chest again")
	var old_round: String = app._round_id
	room._back.pressed.emit()
	check_new_board(app, old_round, tier * 50)
	await dispose(app)


func check_replay_during_opening(stage: String) -> void:
	var app = await make_app()
	finish_result(app, 1)
	var room = app._jelly_rewards
	var old_round: String = app._round_id
	if stage == "holding":
		room._cards[0].button.button_down.emit()
		room.advance_hold(0.3)
		check(room._holding and not room._opening and app.coin_wallet.balance == 0,
			"Replay can interrupt an unfinished result chest hold")
	elif stage in ["opening", "released", "flying"]:
		start_open(room)
		var elapsed: float = 0.25 if stage == "opening" else Feel.RELEASE_TIME + 0.01
		if stage == "flying":
			elapsed = Feel.OPEN_SECONDS + 0.01
		room._cards[0].art._advance_animation(elapsed)
		check(app.coin_wallet.balance == (0 if stage == "opening" else 50),
			"The replay fixture distinguishes uncommitted tension from already saved opening coins")
		if stage == "flying":
			check(app._coin_flight.snapshot().active and app._coin_flight.snapshot().target == 0,
				"Replay starts while saved result coins are still flying toward the HUD")
	check(not room._back.disabled, "Play again remains available during chest interaction")
	room._back.pressed.emit()
	check_new_board(app, old_round, 50)
	check(app.get_meta("result_test_storage").coin_writes == 1, "Every replay opening stage yields exactly one durable payout")
	await dispose(app)


func check_zero_replay() -> void:
	var app = await make_app()
	finish_result(app, 0)
	var old_round: String = app._round_id
	app._jelly.replay_button.pressed.emit()
	check_new_board(app, old_round, 0)
	check(app.get_meta("result_test_storage").coin_writes == 0, "A zero-chest replay never writes a phantom coin receipt")
	await dispose(app)


func check_reduced_result() -> void:
	var app = await make_app()
	app.set_reduced_motion(true)
	finish_result(app, 1)
	var room = app._jelly_rewards
	var old_round: String = app._round_id
	room._cards[0].button.button_down.emit()
	room.advance_hold(Feel.HOLD_SECONDS)
	check(room.rewards.entries[0].opened and not room._opening and app.coin_wallet.balance == 50,
		"Reduced motion opens the held result chest directly into its saved resting pose")
	check(app._coin_flight.snapshot().target == 0 and app._coin_flight.snapshot().displayed == 0.0,
		"Reduced motion preserves the short acknowledgement before updating the coin total")
	app._coin_flight.advance(0.25)
	check(not app._coin_flight.snapshot().active and app._coin_flight.snapshot().displayed == 50.0,
		"Reduced motion settles the complete result payout in one update without a rolling counter")
	check_result_context(app, int(app._round_result.score), 1)
	room._back.pressed.emit()
	check_new_board(app, old_round, 50)
	check(app.reduced_motion and app.get_meta("result_test_storage").coin_writes == 1,
		"Reduced-motion replay preserves the preference and the single saved chest receipt")
	await dispose(app)


func check_replay_save_retry(fail_coins: bool) -> void:
	var app = await make_app()
	finish_result(app, 1)
	var room = app._jelly_rewards
	var storage = app.get_meta("result_test_storage")
	var old_round: String = app._round_id
	storage.coin_writable = not fail_coins
	storage.reward_writable = fail_coins
	room._back.pressed.emit()
	check(app._round_id == old_round and app._jelly.game.phase == "finished" and app._jelly_rewards_shown
		and room._save_failed and room.has_pending(),
		"Replay stays on the result when wallet or chest consumption cannot be saved")
	check(app.coin_wallet.balance == (0 if fail_coins else 50) and not room.rewards.entries[0].opened,
		"Failed replay preserves the pending chest and only the durable portion of its payout")
	check(room._retry.is_visible_in_tree() and not room._retry.disabled,
		"The failed replay exposes an in-session retry action")
	storage.coin_writable = true
	storage.reward_writable = true
	room._retry.pressed.emit()
	if app._round_id == old_round:
		room._back.pressed.emit()
	check_new_board(app, old_round, 50)
	check(storage.coin_writes == 1, "Retry after either store failure settles one receipt without a reload or duplicate payout")
	await dispose(app)


func check_retained_inventory() -> void:
	var storage := Storage.new()
	var rewards := RewardState.new("user://unused-jelly-result-fixture.cfg", storage)
	rewards.storage_kind = "jelly"
	rewards.max_chests = 0
	rewards.allow_repeated_themes = true
	var themes: Array[String] = []
	for tier in range(1, 5):
		themes.append(RewardProgress.theme_for_tier(tier))
	check(rewards.create_batch("older-jelly-result", themes, [1, 2, 3, 4] as Array[int]),
		"Retained inventory has four durable unopened rewards across multiple pages")
	var old_receipts: Array[String] = []
	for entry in rewards.entries:
		old_receipts.append(str(entry.reward_id))
	var app = await make_app(storage)
	finish_result(app, 1)
	var room = app._jelly_rewards
	check(room.rewards.entries.size() == 5 and room._cards.size() < room.rewards.entries.size(),
		"The current result retains older treasure beyond the currently displayed chest page")
	var old_round: String = app._round_id
	room._back.pressed.emit()
	check_new_board(app, old_round, 550)
	check(storage.coin_writes == 5 and app.coin_wallet._receipts.size() == 5,
		"Replay settles every retained and current chest exactly once, including off-page inventory")
	for receipt in old_receipts:
		check(app.coin_wallet._receipts.has(receipt), "Retained treasure keeps its original wallet receipt identity")
	check(not rewards.has_pending() if rewards.load_state() else false,
		"A fresh inventory load confirms every retained chest was durably consumed")
	await dispose(app)


func check_menu_and_background() -> void:
	var app = await make_app()
	finish_result(app, 1)
	var room = app._jelly_rewards
	var old_round: String = app._round_id
	var score: int = app._round_result.score
	room._cards[0].button.button_down.emit()
	room.advance_hold(0.3)
	app._show_mode_menu()
	check(room._paused and not room._holding and app.coin_wallet.balance == 0,
		"Opening the menu cancels an uncommitted result hold without paying coins")
	room.replay_requested.emit()
	check(app._round_id == old_round, "A replay callback cannot replace the result while the menu owns input")
	app._hide_mode_menu()
	app._controller_back()
	check(app._mode_menu_open() and app._round_id == old_round and app._jelly.game.phase == "finished"
		and app.coin_wallet.balance == 0 and app.get_meta("result_test_storage").coin_writes == 0,
		"Controller Back opens the menu from the result without triggering Play again or collecting coins")
	app._hide_mode_menu()
	check_result_context(app, score, 1)
	start_open(room)
	room._cards[0].art._advance_animation(Feel.RELEASE_TIME + 0.01)
	check(app.coin_wallet.balance == 50 and room._opening,
		"The background fixture starts after the result opening has durably released its coins")
	app.on_page_hidden()
	room.replay_requested.emit()
	check(app._round_id == old_round and not app._coin_flight.snapshot().active,
		"Backgrounding settles the committed opening and blocks hidden replay input")
	app.on_page_visible()
	check_result_context(app, score, 1)
	check(room.rewards.entries[0].opened and app.coin_wallet.balance == 50
		and app._coin_flight.snapshot().displayed == 50.0 and not app._coin_flight.snapshot().active,
		"Returning shows the same result and reconciled saved coins without replaying the opening")
	app._show_mode_menu()
	app._hide_mode_menu()
	app.on_page_hidden()
	app.on_page_visible()
	check(app.get_meta("result_test_storage").coin_writes == 1 and not app._round_celebration.is_active()
		and not app._coin_flight.snapshot().active,
		"Repeated menu and background resumes duplicate neither rewards nor result celebrations")
	room._back.pressed.emit()
	check_new_board(app, old_round, 50)
	await dispose(app)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 800)
	for tier in [1, 3]:
		await check_interactive_result(tier)
	for stage in ["unopened", "holding", "opening", "released", "flying"]:
		await check_replay_during_opening(stage)
	await check_zero_replay()
	await check_reduced_result()
	for fail_coins in [true, false]:
		await check_replay_save_retry(fail_coins)
	await check_retained_inventory()
	await check_menu_and_background()
	print("Jelly result coins: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

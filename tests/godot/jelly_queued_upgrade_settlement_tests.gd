extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Progress = preload("res://scripts/medal_progress.gd")
const RewardState = preload("res://scripts/pop_reward_state.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const Celebration = preload("res://scripts/jelly_chest_celebration.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const FINAL_FRAGMENTS: int = 19
const FINAL_TIER: int = 4

var checks: int = 0
var failures: int = 0
var serial: int = 0


class Storage extends RefCounted:
	var coins: Variant = null
	var jelly: Variant = null
	var reward_writable: bool = true
	var coin_writes: int = 0
	var reward_writes: int = 0

	func coinWalletState() -> Variant:
		return coins

	func saveCoinWalletState(value: String, expected: Variant) -> bool:
		if expected != coins:
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
		reward_writes += 1
		return true


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


func make_app(mode: String):
	serial += 1
	var directory := "user://queued-upgrade-settlement-%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), serial]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Queued upgrades use isolated player storage")
	var storage := Storage.new()
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.coin_wallet = Wallet.new(directory + "/coins.cfg", storage)
	app.medal_progress = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.save_preferences()
	app._mode_id = mode
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	freeze_clocks(app)
	check(app._jelly_rewards.connect_storage(storage), mode + ": rewards use the persistent storage adapter")
	check(app.new_round(51, false, "", mode, "", false), mode + ": a round starts through the actual player flow")
	await settle()
	freeze_clocks(app)
	var words: Array = app._learning_words().filter(func(item: Dictionary) -> bool: return str(item.text).length() == 3)
	check(not words.is_empty(), mode + ": the current age contains a pictured three-letter word")
	if not words.is_empty():
		check(app._active_jelly().configure([words[0]], app.growth.learning_age(),
			Data.theme(app.model.theme_id), app.data.chests, false, 51),
			mode + ": real current-age supply makes the reward sequence reproducible")
		app._sync_jelly()
		app.set_meta("queued_upgrade_word", words[0])
	app.set_meta("queued_upgrade_storage", storage)
	return app


func freeze_clocks(app) -> void:
	# Gameplay and chest presentation advance independently below, reproducing
	# completed rewards that run ahead of the still-playing upgrade animation.
	for node in [app, app._jelly, app._word_jelly, app._round_celebration, app._jelly_rewards]:
		node.set_process(false)


func dispose(app) -> void:
	app.audio.halt()
	app.queue_free()
	await settle()


func advance_game(game, seconds: float) -> void:
	# Explicit Next drops supply real marked tiles without racing the clock.
	game.spawn_interval = 10000.0
	game.step(seconds)


func earn_fragments(app, mode: String, target: int) -> bool:
	var game = app._active_jelly().game
	var word: Dictionary = app.get_meta("queued_upgrade_word", {})
	for attempt in range(800):
		if game.fragment_count >= target or game.phase != "playing":
			break
		advance_game(game, 2.0)
		var chosen: Array = []
		var unmarked: Array = []
		var budget: int = target - int(game.fragment_count)
		for first: Dictionary in game.cells:
			if not game.is_settled(first) or game.is_fusing(int(first.id)):
				continue
			for second: Dictionary in game.cells:
				if first.id == second.id or not game.is_settled(second) or game.is_fusing(int(second.id)):
					continue
				var compatible: bool = first.word.id == second.word.id and first.kind != second.kind if mode == "jelly" \
					else not game.is_valid_word(first) and not game.is_valid_word(second) and game.can_merge(first, second)
				if not compatible:
					continue
				var fragments: int = int(bool(first.chest)) + int(bool(second.chest)) if mode == "jelly" \
					else int(first.fragments) + int(second.fragments)
				if fragments > 0 and fragments <= budget:
					chosen = [first, second]
					break
				if fragments == 0:
					unmarked = [first, second]
			if not chosen.is_empty():
				break
		if chosen.is_empty():
			chosen = unmarked
		if chosen.is_empty():
			if game.can_drop_now():
				game.drop_now()
			continue
		var accepted: bool = game.try_merge(chosen[0].id, chosen[1].id) == ("correct" if mode == "jelly" else "merged")
		check(accepted, mode + ": an actual compatible pair merges to earn fragments")
		if not accepted:
			return false
		var merged_id: int = int(game.fusions.back().result.id) if mode == "word_jelly" else -1
		advance_game(game, game.FUSION_SECONDS + 2.0)
		if mode == "word_jelly" and game.is_valid_word(game.cell(merged_id)):
			# Select the normal no-bonus branch, leaving chest payout measurable.
			game._coin_rng.seed = 0
			var collected: bool = game.collect(merged_id)
			check(collected, mode + ": collection commits the merged word's naturally carried fragments")
			if not collected:
				return false
			advance_game(game, game.COLLECT_SECONDS + 2.0)
	var reached: bool = game.phase == "playing" and game.fragment_count == target
	check(reached, "%s: completed gameplay earns exactly %d fragments (actual %d, phase %s)" %
		[mode, target, game.fragment_count, game.phase])
	return reached


func load_saved(app, storage):
	var saved := RewardState.new(app.jelly_reward_save_path, storage)
	saved.storage_kind = "jelly"
	saved.max_chests = 0
	saved.allow_repeated_themes = true
	check(saved.load_state(), "The independent reward reader reloads the durable batch")
	return saved


func entry_for(saved, reward_id: String) -> Dictionary:
	for entry: Dictionary in saved.entries:
		if str(entry.get("reward_id", "")) == reward_id:
			return entry
	return {}


func check_current_card(app, reward_id: String, label: String) -> bool:
	var room = app._jelly_rewards
	var expected_theme: String = RewardProgress.theme_for_tier(FINAL_TIER)
	check(app._settlement_dialog.is_visible_in_tree() and room.is_visible_in_tree(),
		label + ": Finish presents the result inside its settlement modal")
	check(room._cards.size() == 1, label + ": the final result displays one earned chest")
	if room._cards.size() != 1:
		return false
	var card: Dictionary = room._cards[0]
	var matches: bool = card.reward_id == reward_id and card.tier == FINAL_TIER and card.theme == expected_theme
	check(matches, label + ": the visible chest is this round's tier 4 reward, not an earlier animation or retained reward")
	return matches


func check_level_badge(view, tier: int, visible: bool, label: String) -> void:
	var loot: Dictionary = view.snapshot().loot
	var badge: Dictionary = loot.get("level_label", {})
	var text: String = "Lv%d" % tier
	check(loot.get("displayed_tier", -1) == tier and loot.tier == view.game.chest_tier,
		label + ": the published displayed level stays distinct from the earned model tier")
	check(is_instance_valid(view._header_chest_level) and view._header_chest_level.text == text
		and badge.get("text", "") == text,
		label + ": the actual header badge and its snapshot both show " + text)
	check(is_instance_valid(view._header_chest_level) and view._header_chest_level.is_visible_in_tree() == visible
		and badge.get("visible", not visible) == visible,
		label + ": the badge follows gameplay header visibility")


func check_queued_finish(mode: String, retained: bool, fail_first_save: bool) -> void:
	var label: String = mode + (" retained" if retained else " fresh") + (" retry" if fail_first_save else "")
	var app = await make_app(mode)
	var storage = app.get_meta("queued_upgrade_storage")
	var view = app._active_jelly()
	var game = view.game
	var room = app._jelly_rewards
	var old_entry: Dictionary = {}
	check_level_badge(view, 0, true, label + " initial")
	if retained:
		# Another pending reward can coexist with this in-progress round. Use the
		# real inventory API so its identity and earlier index are both preserved.
		var themes: Array[String] = ["jungle"]
		var tiers: Array[int] = [1]
		check(room.rewards.create_batch("older-round-" + str(serial), themes, tiers),
			label + ": an older unopened chest is already durable")
		old_entry = room.rewards.entries[0].duplicate(true)
	if not earn_fragments(app, mode, 4):
		await dispose(app)
		return
	check_level_badge(view, 0, true, label + " pending synthesis")
	if retained:
		view.advance_reward_presentation(Celebration.ARRIVAL_SECONDS + Celebration.PERFORMANCE_SECONDS + 0.01)
		check(not view._reward_presentation.is_active() and view._displayed_chest_tier == 1,
			label + ": synthesis completes before the first upgrade begins")
		check_level_badge(view, 1, true, label + " completed synthesis")
		if not earn_fragments(app, mode, 9):
			await dispose(app)
			return
	view.advance_reward_presentation(Celebration.ARRIVAL_SECONDS + 0.15)
	if not earn_fragments(app, mode, 14) or not earn_fragments(app, mode, FINAL_FRAGMENTS):
		await dispose(app)
		return
	var presentation: Dictionary = view._reward_presentation.snapshot()
	check(presentation.active and presentation.visible and not presentation.reduced_motion
		and presentation.tier == (2 if retained else 1) and presentation.queued == (3 if retained else 4),
		label + ": later earned upgrades remain queued behind the visibly active earlier chest")
	check(game.chest_tier == FINAL_TIER and game.chest_count == 1 and view._displayed_chest_tier < FINAL_TIER,
		label + ": the completed model reward has reached tier 4 ahead of presentation")
	var previous_tier: int = 1 if retained else 0
	check_level_badge(view, previous_tier, true, label + " queued upgrades")
	view.advance_reward_presentation(Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS
		- float(presentation.elapsed) - 0.001)
	check(not view._reward_presentation.snapshot().revealed,
		label + ": the earlier chest has not revealed just before its reward cue")
	check_level_badge(view, previous_tier, true, label + " before reveal")
	view.advance_reward_presentation(0.002)
	check(view._reward_presentation.snapshot().revealed and game.chest_tier == FINAL_TIER,
		label + ": one reveal leaves the later earned upgrades queued")
	check_level_badge(view, previous_tier + 1, true, label + " after reveal")
	var round_id: String = app._round_id
	var reward_id: String = "jelly:" + round_id + ":0"
	var coins_before: int = app.coin_wallet.balance
	var chest_payout: int = int(Economy.chest_reward(FINAL_TIER, app.growth.level).total)
	var saves_before: int = storage.reward_writes
	storage.reward_writable = not fail_first_save
	view.finish_button.accessibility_requested.emit()
	check(app._finish_confirmation_open() and game.paused, label + ": Finish pauses before confirmation")
	app._finish_confirmation.finish_button.pressed.emit()
	await settle()
	check(game.phase == "finished" and app._round_result.fragment_count == FINAL_FRAGMENTS
		and app._round_result.chest_tier == FINAL_TIER and app._round_result.chest_count == 1,
		label + ": confirmed Finish settles every earned fragment despite the unfinished animation")
	check(not view._reward_presentation.is_active() and view._displayed_chest_tier == FINAL_TIER,
		label + ": finishing clears obsolete animation events and reconciles the displayed tier")
	check_level_badge(view, FINAL_TIER, false, label + " finished")
	check(app._round_end.is_active() and not app._settlement_dialog.is_visible_in_tree()
		and not app._round_celebration.is_active(),
		label + ": both saved rewards and failed saves first show the same end sequence without a chest dance")
	Fixture.finish_celebration(app)
	if fail_first_save:
		check(room._save_failed and room._retry.is_visible_in_tree() and storage.reward_writes == saves_before,
			label + ": a failed batch write remains retryable without replacing old treasure")
		var failed_save = load_saved(app, storage)
		check(failed_save.entries.size() == 1 and failed_save.entries[0] == old_entry
			and app.coin_wallet.balance == coins_before,
			label + ": failed persistence neither consumes the retained chest nor pays coins")
		room._back.pressed.emit()
		check(app._round_id == round_id and app._settlement_dialog.is_visible_in_tree(),
			label + ": Play again cannot discard an unsaved final reward")
		storage.reward_writable = true
		room.retry_save()
		await settle()
		check(not room._save_failed, label + ": retry durably saves the same final tier")
	var saved = load_saved(app, storage)
	var current: Dictionary = entry_for(saved, reward_id)
	check(saved.round_id == round_id and saved.entries.size() == (2 if retained else 1)
		and current.get("tier", 0) == FINAL_TIER and current.get("theme", "") == RewardProgress.theme_for_tier(FINAL_TIER)
		and not bool(current.get("opened", true)) and storage.reward_writes == saves_before + 1,
		label + ": persistence contains exactly one new unopened chest with the final tier and theme")
	if retained:
		check(saved.entries[0] == old_entry, label + ": appending the final reward preserves the older entry and its index")
	check(not app._round_end.is_active() and not app._round_celebration.is_active(),
		label + ": settlement and save recovery remain actionable without a second entrance")
	var card_matches: bool = check_current_card(app, reward_id, label)
	check(room.snapshot().result_context == app._round_result and app.coin_wallet.balance == coins_before,
		label + ": showing settlement keeps the final result and does not pay before opening")
	var writes: int = storage.reward_writes
	view.advance_reward_presentation(100.0)
	game.finish_round()
	check(not view._reward_presentation.is_active() and storage.reward_writes == writes
		and app._round_result.chest_tier == FINAL_TIER,
		label + ": late presentation time and repeated Finish cannot downgrade or duplicate the reward")
	app._show_collection()
	await settle()
	check(app.collection_page.visible, label + ": the word library temporarily covers the settlement")
	app._hide_collection()
	await settle()
	check(app._round_id == round_id, label + ": closing the word library restores the same finished round")
	card_matches = check_current_card(app, reward_id, label + " reopened") and card_matches
	if not card_matches:
		await dispose(app)
		return
	var releases: Array[String] = []
	room.coins_released.connect(func(id: String, _credit: Dictionary, _origin: Vector2, _animate: bool) -> void:
		if not id.is_empty():
			releases.append(id))
	var card: Dictionary = room._cards[0]
	card.art.set_process(false)
	room.begin_hold(card.button)
	room.advance_hold(Feel.HOLD_SECONDS)
	card.art._advance_animation(Feel.OPEN_SECONDS + 0.01)
	check(app.coin_wallet.balance == coins_before + chest_payout
		and releases == [reward_id], label + ": opening releases the final tier's coins under its own identity exactly once")
	saved = load_saved(app, storage)
	current = entry_for(saved, reward_id)
	check(bool(current.get("opened", false)) and current.get("tier", 0) == FINAL_TIER,
		label + ": the current reward is durably opened")
	if retained:
		check(saved.entries[0] == old_entry and not saved.entries[0].opened,
			label + ": opening the current reward leaves the older unopened chest untouched")
	var coin_writes: int = storage.coin_writes
	writes = storage.reward_writes
	room.begin_hold(card.button)
	room.advance_hold(Feel.HOLD_SECONDS)
	card.art._advance_animation(Feel.OPEN_SECONDS + 1.0)
	game.finish_round()
	check(storage.coin_writes == coin_writes and storage.reward_writes == writes and releases == [reward_id],
		label + ": repeated chest input and finish callbacks cannot save or pay the reward twice")
	app.on_page_hidden()
	app.on_page_visible()
	await settle()
	check_current_card(app, reward_id, label + " opened restoration")
	check(room._cards[0].opened and app.coin_wallet.balance == coins_before + chest_payout
		and storage.coin_writes == coin_writes and releases == [reward_id],
		label + ": restoring the opened result does not replay the payout or substitute the older chest")
	room._back.pressed.emit()
	await settle()
	freeze_clocks(app)
	# The fixture freezes presentation clocks, so supply the normal first HUD frame.
	view._process(0.0)
	check(app._round_id != round_id and view.game.phase == "playing" and view.game.fragment_count == 0
		and not view._reward_presentation.is_active(),
		label + ": Play again starts a fresh round without the finished upgrade queue")
	check_level_badge(view, 0, true, label + " restarted")
	await dispose(app)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	for mode: String in ["jelly", "word_jelly"]:
		await check_queued_finish(mode, false, false)
		await check_queued_finish(mode, true, false)
		await check_queued_finish(mode, true, true)
	print("Jelly queued-upgrade settlement: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

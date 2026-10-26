extends SceneTree
const BASE_COINS: int = preload("res://scripts/coin_economy.gd").CHEST_BASE_COINS

const Progress = preload("res://scripts/medal_progress.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const PairReward = preload("res://scripts/pair_chest_reward.gd")
const Audio = preload("res://scripts/game_audio.gd")
var checks: int = 0
var failures: int = 0
var serial: int = 0

class Storage extends RefCounted:
	var text: Variant = null
	var writable: bool = true
	func medalProgress() -> Variant:
		return text
	func saveMedalProgress(value: String) -> bool:
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
	for frame in range(4):
		await process_frame

func make_app(mode: String, slot: int, storage = null):
	serial += 1
	var directory := "user://pair-flow-%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), serial]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app._presentation.path = directory + "/presentation.cfg"
	app._mode_id = mode
	app.medal_progress = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg", Storage.new() if storage == null else storage)
	check(app.medal_progress.load_progress(), "Load isolated pair flow save")
	if storage == null:
		check(not app.medal_progress.begin_pair_round(mode, "reserved", slot).is_empty(), "Reserve deterministic pair result")
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_process(false)
	app._memory.set_process(false)
	app._round_celebration.set_process(false)
	app.set_reduced_motion(false)
	Fixture.enter_mode(app, mode)
	return app

func match_pair(app, index: int) -> void:
	var word: Dictionary = app.model.lesson_words[index]
	if app._mode_id == "match":
		app.cards[str(word.id) + ":word"].pressed.emit()
		app.cards[str(word.id) + ":image"].pressed.emit()
		app.feedback_timer.stop()
	else:
		for n in range(app._memory.memory.cards.size()):
			if app._memory.memory.cards[n].word.id == word.id:
				app._memory.card_buttons[n].pressed.emit()
		app._memory._feedback_timer.stop()

func continue_pair(app) -> void:
	if app._mode_id == "match":
		app._continue_match()
	else:
		app._memory.continue_feedback()

func pieces(app) -> int:
	var total: int = 0
	for value in app.medal_progress.counts.values():
		total += int(value)
	return total

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 800)
	# Memory performance tiers are covered through real rounds in memory_scene_tests.
	for mode in ["match"]:
		for slot in [1, 5]:
			await check_reward(mode, slot)
		await check_failure(mode)
		await check_dry(mode)
		await check_reload(mode)
		await check_discovery_preferences(mode)
	print("Pair chest flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func discovery_playing(app) -> bool:
	return is_instance_valid(app.audio.pair_chest_discovery) and app.audio.pair_chest_discovery.playing


func discovery_cues(app) -> Array[String]:
	var received: Array[String] = []
	app._pair_reward.cue_requested.connect(func(id: String, cue: String) -> void:
		if cue == "reward":
			received.append(id))
	return received


func check_reward(mode: String, slot: int) -> void:
	var app = await make_app(mode, slot)
	var cues: Array[String] = discovery_cues(app)
	var cheer_seconds: float = 0.0
	app.audio.set_muted(false)
	app.audio.interact(app.model.theme_id, false)
	check(not app.model.chest_earned, mode + " does not own a chest at creation")
	check(app.coin_wallet.ready and app.coin_wallet.balance == 0, mode + " begins with its isolated empty wallet")
	for index in range(5):
		match_pair(app, index)
		check(app.model.chest_earned == (index + 1 >= slot), mode + " reveals at its reserved successful pair")
		check(pieces(app) == 0, mode + " saves ownership without prematurely opening the chest")
		check(app.coin_wallet.balance == 0 and not app._coin_flight.snapshot().active,
			mode + " saves chest ownership without prematurely awarding its coins")
		if index + 1 == slot:
			check(not discovery_playing(app) and cues.is_empty()
				and not app._pair_reward.snapshot().discovery_visible,
				mode + " waits for the chest reveal beat before cheering or showing its discovery caption")
			var voice_request: int = app.audio._playback_requests.get(app.audio.voice, 0)
			app._advance_ui(PairReward.REVEAL_SECONDS + 0.01)
			check(discovery_playing(app) and cues == [app._round_id]
				and app.audio.pair_chest_discovery.stream.resource_path == Audio.PAIR_CHEST_DISCOVERY_PATH,
				mode + " plays its dedicated cheer exactly when the saved chest is revealed")
			cheer_seconds = app.audio.pair_chest_discovery.stream.get_length()
			check(app.audio._playback_requests.get(app.audio.voice, 0) == voice_request,
				mode + " chest discovery adds no Pip voice or spoken narration")
			check(app._pair_reward.snapshot().discovery_visible
				and app._pair_reward.snapshot().message == PairReward.DISCOVERY_MESSAGE
				and app._status_announcement.begins_with(PairReward.DISCOVERY_MESSAGE),
				mode + " shows and announces the complete hidden treasure chest message")
			check(app._reward_confetti.snapshot().visible and app._pair_reward.chest.is_visible_in_tree(), mode + " plays chest and full-screen paper on the live board")
			check(app._pair_reward.chest.theme_id == RewardProgress.theme_for_tier(1),
				mode + " reveals an ordinary tier-one chest independently of the selected world")
			check(not app._round_celebration.is_active(), mode + " keeps completion controls out of the pair reward")
			if slot == 1:
				var cheer_request: int = app.audio._playback_requests[app.audio.pair_chest_discovery]
				app._refresh()
				continue_pair(app)
				var next_card: Button
				var next_word: Dictionary = app.model.lesson_words[index + 1]
				if mode == "match":
					next_card = app.cards[str(next_word.id) + ":word"]
				else:
					for card_index in range(app._memory.memory.cards.size()):
						if app._memory.memory.cards[card_index].word.id == next_word.id:
							next_card = app._memory.card_buttons[card_index]
							break
				next_card.pressed.emit()
				check(discovery_playing(app)
					and app.audio._playback_requests[app.audio.pair_chest_discovery] == cheer_request,
					mode + " board refresh, continuing feedback and selecting the next card preserve the same cheer")
				next_card.pressed.emit()
				var elapsed: float = app._pair_reward.snapshot().elapsed
				var paper_ages: Array = app._reward_confetti.snapshot().ages.duplicate()
				app._show_mode_menu()
				app._advance_ui(0.5)
				check(not discovery_playing(app) and not app._pair_reward.snapshot().discovery_visible,
					mode + " returning Home stops the cheer and hides the discovery caption")
				check(not app._reward_confetti.snapshot().visible and app._reward_confetti.snapshot().ages == paper_ages
					and is_equal_approx(app._pair_reward.snapshot().elapsed, elapsed), mode + " menu hides and pauses pair effects")
				app._hide_mode_menu()
				app._refresh()
				app.on_page_hidden()
				app._advance_ui(0.5)
				check(not app._reward_confetti.snapshot().visible and app._reward_confetti.snapshot().ages == paper_ages
					and is_equal_approx(app._pair_reward.snapshot().elapsed, elapsed), mode + " background pauses without repeating the drop")
				app.on_page_visible()
				app._pair_matched(str(app.model.lesson_words[index].id))
				check(not discovery_playing(app) and cues == [app._round_id],
					mode + " refresh, navigation, background resume and duplicate callbacks cannot replay the discovery cheer")
				check(app._pair_words.size() == index + 1, mode + " duplicate callbacks cannot count twice")
		continue_pair(app)
		if index == 1 and slot == 1:
			check(app._pair_words.size() == 2 and app._pair_reward_revealing(), mode + " accepts another pair during chest animation")
	check(app.model.phase == "won" and not app._round_celebration.is_active(), mode + " lets the compact chest reveal finish before the finale")
	app._open_chest()
	app._start_chest_hold()
	check(not app._holding_chest and app.model.chest_state == "closed" and pieces(app) == 0, mode + " rejects hidden chest actions during the final pair effect")
	if slot == 5:
		check(cheer_seconds > 0.0 and PairReward.REVEAL_SECONDS + cheer_seconds <= PairReward.REWARD_SECONDS,
			mode + " reserves enough final-pair presentation time for the complete discovery recording")
		app._advance_ui(PairReward.REVEAL_SECONDS + cheer_seconds - 0.01 - float(app._pair_reward.snapshot().elapsed))
		check(app._pair_reward_revealing() and not app._round_celebration.is_active()
			and not app._settlement_dialog_open(),
			mode + " keeps final settlement closed until the discovery cheer has had time to finish")
	app._advance_ui(PairReward.REWARD_SECONDS + 0.01 - float(app._pair_reward.snapshot().elapsed))
	if slot == 5:
		check(discovery_playing(app) and not app._pair_reward.snapshot().performance_active
			and app._pair_reward_revealing() and not app._round_celebration.is_active()
			and not app._settlement_dialog_open(),
			mode + " a slow visual frame cannot cut off the still-playing final discovery cheer")
		# Deliver the player's real completion signal without making the test sleep
		# for the recording's wall-clock duration under the headless audio driver.
		app.audio.pair_chest_discovery.stop()
		app.audio.pair_chest_discovery.finished.emit()
		await process_frame
		app._advance_ui(0.01)
	check(app._round_celebration.is_active() and app._round_celebration.snapshot().chest_announced, mode + " retains the normal finale without a second reward burst")
	Fixture.finish_celebration(app)
	check(cues == [app._round_id] and not discovery_playing(app)
		and not app._pair_reward.snapshot().discovery_visible,
		mode + " final settlement cannot replay the chest discovery or retain its overlay caption")
	check(app._reward_confetti.is_active() and app._reward_confetti.snapshot().keys.size() == 1,
		mode + " retains one shared paper tail beyond the compact chest and Pip performances")
	app.set_reduced_motion(true)
	app._open_chest()
	check(app.model.chest_state == "opened" and pieces(app) == 1, mode + " opens the one saved chest")
	check(app.chest.theme_id == RewardProgress.theme_for_tier(1) and app.coin_wallet.balance == BASE_COINS
		and app._coin_flight.snapshot().active, mode + " opening saves the base chest coins and starts their flight")
	app._on_chest_opened()
	check(pieces(app) == 1 and app.coin_wallet.balance == BASE_COINS and app._coin_flight.snapshot().flights == 1,
		mode + " duplicate opening cannot duplicate contents or the coin flight")
	app.queue_free()
	await settle()

func check_failure(mode: String) -> void:
	var app = await make_app(mode, 1)
	var cues: Array[String] = discovery_cues(app)
	app.audio.set_muted(false)
	app.audio.interact(app.model.theme_id, false)
	var storage = app.medal_progress._browser_storage
	storage.writable = false
	match_pair(app, 0)
	check(app._pair_save_failed and not app.model.chest_earned and not app._pair_reward.snapshot().earned, mode + " failed save cannot announce an unsaved chest")
	app._advance_ui(PairReward.REVEAL_SECONDS + 0.01)
	check(cues.is_empty() and not discovery_playing(app), mode + " a failed reward save cannot cheer for an uncommitted chest")
	continue_pair(app)
	match_pair(app, 1)
	check(app._pair_words.size() == 2, mode + " remains playable while reward storage is unavailable")
	check(not app.new_round(), mode + " preserves the pending drop on a rejected restart")
	storage.writable = true
	app._retry_storage()
	check(app.model.chest_earned and not app._pair_save_failed and app._pair_reward.snapshot().earned, mode + " retry saves and reveals the same chest")
	app._advance_ui(PairReward.REVEAL_SECONDS + 0.01)
	check(cues == [app._round_id] and discovery_playing(app), mode + " successful storage recovery cheers for its newly committed chest once")
	app._retry_storage()
	app._refresh()
	app._advance_ui(0.05)
	check(cues == [app._round_id], mode + " repeated storage retry and refresh cannot announce the saved chest again")
	storage.writable = false
	check(not app.new_round(2, false, "", "phrase") and app._pair_settlement_pending, mode + " preserves failed exit settlement")
	storage.writable = true
	app._retry_storage()
	check(not app._pair_save_failed and not app._pair_settlement_pending and pieces(app) == 1, mode + " retry actually commits pending exit settlement")
	check(app.coin_wallet.balance == BASE_COINS and not app._coin_flight.snapshot().active,
		mode + " exit retry settles the same coin receipt without a hidden flight")
	check(app.new_round(2, false, "", "phrase") and pieces(app) == 1, mode + " leaving midround settles its earned chest once")
	app.queue_free()
	await settle()

func check_dry(mode: String) -> void:
	var app = await make_app(mode, 0)
	var seed_value: int = 0
	var probe = app.Model.new()
	for candidate in range(128):
		probe.reset(app._learning_words(), candidate, false, "", "", str(app.growth.learning_age()), true)
		if probe.chest_reward_pair == 0:
			seed_value = candidate
			break
	for round_index in range(3):
		if round_index > 0:
			check(app.new_round(seed_value, false, "", mode), mode + " starts next completed round")
		for index in range(5):
			match_pair(app, index)
			if round_index < 2:
				check(app._status_announcement.begins_with("No chest this pair."), mode + " includes the dry pair acknowledgement in the accessible board status")
				check(not discovery_playing(app) and not app._pair_reward.snapshot().discovery_visible,
					mode + " ordinary matching feedback has no chest discovery cheer or caption")
			continue_pair(app)
		app._advance_ui(3.0)
		check(app.model.chest_earned == (round_index == 2), mode + " guarantees a chest after two completed dry rounds")
		check(app.medal_progress.pair_dry_rounds(mode) == (round_index + 1 if round_index < 2 else 0), mode + " updates durable pity once")
		app._refresh()
		app._refresh()
		check(app.medal_progress.pair_dry_rounds(mode) == (round_index + 1 if round_index < 2 else 0), mode + " repeated refresh does not count another round")
	check(app.medal_progress.pair_dry_rounds("memory" if mode == "match" else "match") == 0, mode + " keeps the other mode's pity independent")
	app.queue_free()
	await settle()

func check_reload(mode: String) -> void:
	var app = await make_app(mode, 1)
	match_pair(app, 0)
	var storage = app.medal_progress._browser_storage
	check(app.model.chest_earned and pieces(app) == 0, mode + " has durable unopened midround treasure")
	app.queue_free()
	await settle()
	storage.writable = false
	app = await make_app(mode, 0, storage)
	check(app._pair_save_failed and not app._progress_ready, mode + " startup preserves a chest when recovery cannot write")
	storage.writable = true
	app._retry_storage()
	check(not app._pair_save_failed and app._progress_ready, mode + " startup recovery can retry without another reload")
	check(pieces(app) == 1 and not app.model.chest_earned, mode + " reload settles prior treasure before a fresh round")
	check(not discovery_playing(app) and not app._pair_reward.snapshot().discovery_visible,
		mode + " recovering a saved reward never replays its discovery sound or caption")
	check(app.coin_wallet.balance == BASE_COINS and not app._coin_flight.snapshot().active,
		mode + " reload recovery credits one saved chest without replaying its coin animation")
	app.queue_free()
	await settle()


func check_discovery_preferences(mode: String) -> void:
	for muted: bool in [true, false]:
		var app = await make_app(mode, 1)
		var cues: Array[String] = discovery_cues(app)
		app.set_reduced_motion(not muted)
		app.audio.set_muted(muted)
		app.audio.interact(app.model.theme_id, false)
		match_pair(app, 0)
		app._advance_ui(PairReward.REVEAL_SECONDS + 0.01)
		check(cues == [app._round_id] and app._pair_reward.snapshot().discovery_visible
			and app._pair_reward.snapshot().message == PairReward.DISCOVERY_MESSAGE,
			mode + " keeps its complete visible discovery message with mute or reduced motion enabled")
		check(discovery_playing(app) == (not muted),
			mode + " mute suppresses the cheer while reduced motion retains its audio acknowledgement")
		if muted:
			app.audio.set_muted(false)
			app.audio.interact(app.model.theme_id, false)
			app._refresh()
			app._advance_ui(0.10)
			check(not discovery_playing(app) and cues == [app._round_id],
				mode + " unmuting after discovery does not replay a suppressed cheer")
		else:
			check(not app._reward_confetti.is_active(), mode + " reduced motion announces the find without animated paper")
			app.on_page_hidden()
			check(not discovery_playing(app) and not app._pair_reward.snapshot().discovery_visible,
				mode + " backgrounding immediately stops an audible discovery cheer")
			app.on_page_visible()
			app._advance_ui(0.10)
			check(not discovery_playing(app) and cues == [app._round_id],
				mode + " returning to the page keeps the interrupted cheer silent")
		app.queue_free()
		await settle()

extends SceneTree

const Progress = preload("res://scripts/medal_progress.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
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
	for mode in ["match", "memory"]:
		for slot in [1, 5]:
			await check_reward(mode, slot)
		await check_failure(mode)
		await check_dry(mode)
		await check_reload(mode)
	print("Pair chest flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_reward(mode: String, slot: int) -> void:
	var app = await make_app(mode, slot)
	check(not app.model.chest_earned, mode + " does not own a chest at creation")
	for index in range(5):
		match_pair(app, index)
		check(app.model.chest_earned == (index + 1 >= slot), mode + " reveals at its reserved successful pair")
		check(pieces(app) == 0, mode + " saves ownership without prematurely opening the chest")
		if index + 1 == slot:
			app._advance_ui(0.22)
			check(app._status_announcement.begins_with("Chest found!"), mode + " preserves the earned chest announcement after board refresh")
			check(app._pair_reward.snapshot().confetti_visible and app._pair_reward.chest.is_visible_in_tree(), mode + " plays chest and full-screen paper on the live board")
			check(not app._round_celebration.is_active(), mode + " keeps completion controls out of the pair reward")
			var elapsed: float = app._pair_reward.snapshot().elapsed
			app._show_mode_menu()
			app._advance_ui(0.5)
			check(not app._pair_reward.snapshot().confetti_visible and is_equal_approx(app._pair_reward.snapshot().elapsed, elapsed), mode + " menu hides and pauses pair effects")
			app._hide_mode_menu()
			app._refresh()
			app.on_page_hidden()
			app._advance_ui(0.5)
			check(not app._pair_reward.snapshot().confetti_visible and is_equal_approx(app._pair_reward.snapshot().elapsed, elapsed), mode + " background pauses without repeating the drop")
			app.on_page_visible()
			app._pair_matched(str(app.model.lesson_words[index].id))
			check(app._pair_words.size() == index + 1, mode + " duplicate callbacks cannot count twice")
		continue_pair(app)
		if index == 1 and slot == 1:
			check(app._pair_words.size() == 2 and app._pair_reward_revealing(), mode + " accepts another pair during chest animation")
	check(app.model.phase == "won" and not app._round_celebration.is_active(), mode + " lets final paper finish before the finale")
	app._open_chest()
	app._start_chest_hold()
	check(not app._holding_chest and app.model.chest_state == "closed" and pieces(app) == 0, mode + " rejects hidden chest actions during the final pair effect")
	app._advance_ui(2.5)
	check(app._round_celebration.is_active() and app._round_celebration.snapshot().chest_announced, mode + " retains the normal finale without a second reward burst")
	Fixture.finish_celebration(app)
	app.set_reduced_motion(true)
	app._open_chest()
	check(app.model.chest_state == "opened" and pieces(app) == 1, mode + " opens the one saved chest")
	app._on_chest_opened()
	check(pieces(app) == 1, mode + " duplicate opening cannot duplicate contents")
	app.queue_free()
	await settle()

func check_failure(mode: String) -> void:
	var app = await make_app(mode, 1)
	var storage = app.medal_progress._browser_storage
	storage.writable = false
	match_pair(app, 0)
	check(app._pair_save_failed and not app.model.chest_earned and not app._pair_reward.snapshot().earned, mode + " failed save cannot announce an unsaved chest")
	continue_pair(app)
	match_pair(app, 1)
	check(app._pair_words.size() == 2, mode + " remains playable while reward storage is unavailable")
	check(not app.new_round(), mode + " preserves the pending drop on a rejected restart")
	storage.writable = true
	app._retry_storage()
	check(app.model.chest_earned and not app._pair_save_failed and app._pair_reward.snapshot().earned, mode + " retry saves and reveals the same chest")
	storage.writable = false
	check(not app.new_round(2, false, "", "phrase") and app._pair_settlement_pending, mode + " preserves failed exit settlement")
	storage.writable = true
	app._retry_storage()
	check(not app._pair_save_failed and not app._pair_settlement_pending and pieces(app) == 1, mode + " retry actually commits pending exit settlement")
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
	app.queue_free()
	await settle()

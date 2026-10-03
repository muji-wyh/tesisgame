extends SceneTree

const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
const Quest = preload("res://scripts/talk_quest.gd")
const QuestModel = preload("res://scripts/talk_quest_model.gd")
const Feel = preload("res://scripts/chest_feel.gd")

var checks: int = 0
var failures: int = 0
var _directory: String
var _audio_events: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _isolate_quest(node: Node) -> void:
	# The main scene creates TalkQuest during _ready. Inject its path at tree
	# entry, before the child's _ready can read or write the user's checkpoint.
	if node.get_script() == Quest:
		node.save_path = _directory + "/quest.cfg"


func _controller(app, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	app._input(event)


func _earn_chest(app) -> bool:
	var quest = app._quest
	quest.start_level(1)
	for turn in range(180):
		if quest.game.phase != "playing":
			break
		var prompt: Dictionary = quest.game.current_prompt()
		if prompt.is_empty():
			quest._process(0.5)
			continue
		quest._submit_text(str(prompt.text))
		quest._process(0.65)
	quest._process(3.2)
	quest.set_process(false)
	quest._chest.set_process(false)
	var ready: bool = quest.game.phase == "chest" and quest._chest_button.is_visible_in_tree()
	check(ready, "The real quest word battle earns a closed, interactive treasure")
	if ready:
		quest._chest_button.grab_focus()
	return ready


func _begin(app) -> void:
	app._quest._chest_button.button_down.emit()
	app._quest.set_process(false)
	app._quest._chest.set_process(false)


func _confirm(app) -> void:
	_begin(app)
	app._quest._advance_chest_hold(Feel.HOLD_SECONDS)


func _cancelled(app, clears: int, reason: String) -> void:
	var quest = app._quest
	check(not quest._holding_chest and not quest._opening and quest.game.phase == "chest"
		and quest._chest.mode == "closed" and quest.game.total_clears == clears,
		reason + " retains the same uncollected chest")
	check(not quest._chest.hold_effect_snapshot().active and not app.audio._chest_charge_active
		and app.audio.chest_charge != null and not app.audio.chest_charge.playing,
		reason + " clears visual progress and the shared pressure loop")
	quest._chest._advance_animation(Feel.OPEN_SECONDS + 1.0)
	quest._chest.finish_immediately()
	quest._reward_finished()
	check(quest.game.total_clears == clears and not quest._chest.hold_effect_snapshot().surprise.active,
		reason + " rejects stale completion and surprise callbacks")


func _saved_progress(path: String) -> Dictionary:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return {}
	var value: Variant = JSON.parse_string(str(file.get_value("quest", "progress", "")))
	return value if value is Dictionary else {}


func _run() -> void:
	_directory = "user://quest-reward-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(_directory) == OK, "The reward flow uses isolated player storage")
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(_directory + "/medals.cfg", _directory + "/legacy.cfg")
	app.playroom_save_path = _directory + "/room.cfg"
	app._mode_id = "quest"
	PlayerFixture.install(app, _directory)
	node_added.connect(_isolate_quest)
	root.add_child(app)
	await process_frame
	await process_frame
	node_added.disconnect(_isolate_quest)
	app.set_process(false)
	app.set_reduced_motion(false)
	app.audio.set_muted(false)
	var quest = app._quest
	quest.set_process(false)
	quest.chest_audio_requested.connect(func(action: String, _theme: String, _progress: float) -> void:
		_audio_events.append(action))
	check(quest.save_path == _directory + "/quest.cfg" and quest._loaded,
		"The embedded quest loaded only its isolated checkpoint")
	check(app._mode_id == "quest" and quest.is_visible_in_tree() and not app._leaderboard_overlay.visible,
		"The main scene enters Talk Quest with the isolated player selected")
	if not _earn_chest(app):
		app.queue_free()
		await process_frame
		quit(1)
		return
	_check_controller_and_cancel(app)
	_check_completion_and_audio(app)
	_check_save_retry(app)
	_check_reduced_motion(app)
	app.audio.halt()
	app.queue_free()
	await process_frame
	# The fixture only creates flat files in its unique directory.
	for filename: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(filename))
	DirAccess.remove_absolute(_directory)
	print("Talk Quest reward flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_controller_and_cancel(app) -> void:
	var quest = app._quest
	_controller(app, true)
	check(app._controller_holding_quest_chest and quest._holding_chest,
		"Controller A down starts the quest confirmation through the focused real control")
	check(app.audio._chest_charge_active and app.audio.chest_charge.playing
		and app.audio._chest_theme == quest._chest.theme_id,
		"Quest confirmation arms the same material audio loop as Match")
	quest._advance_chest_hold(0.4)
	var earned: float = quest._chest_hold_elapsed
	_controller(app, true)
	check(is_equal_approx(quest._chest_hold_elapsed, earned), "Repeated controller down cannot restart earned hold progress")
	_controller(app, false)
	check(not app._controller_holding_quest_chest, "Controller A up clears its dedicated quest gesture")
	_cancelled(app, 0, "Controller release before confirmation")
	_confirm(app)
	quest._chest._advance_animation(0.4)
	quest._advance_chest_hold(0.0)
	check(app.audio._chest_phase == "opening" and app.audio.chest_charge.playing,
		"Confirmation hands the same audio loop into the shared tension timeline")
	app._on_input_canceled()
	_cancelled(app, 0, "Global input cancellation during buildup")
	_begin(app)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(40, 20)
	drag.relative = Vector2(18, 0)
	quest._chest_input(drag)
	_cancelled(app, 0, "Dragging farther than the confirmation threshold")
	quest.end_chest_hold()
	_confirm(app)
	app.on_page_hidden()
	check(quest.game.phase == "paused" and not quest._opening and not app.audio.chest_charge.playing,
		"Backgrounding cancels an unreleased quest chest and silences shared audio")
	app.on_page_visible()
	quest._continue_run()
	quest.set_process(false)
	quest._chest.set_process(false)
	check(quest.game.phase == "chest" and quest._chest.mode == "closed" and not quest._holding_chest,
		"Returning to the saved chest requires a fresh explicit hold")


func _check_completion_and_audio(app) -> void:
	var quest = app._quest
	var reward_count: int = _audio_events.count("reward")
	quest._chest_button.grab_focus()
	_controller(app, true)
	quest._advance_chest_hold(Feel.HOLD_SECONDS)
	quest._chest._advance_animation(Feel.RELEASE_TIME + 0.01)
	check(quest._chest.opening_committed() and not quest._holding_chest
		and quest.game.total_clears == 0 and not app.audio._chest_rewarded,
		"Visible release completes input while the reward still waits for settling")
	_controller(app, false)
	check(quest._opening and quest._chest.mode == "opening", "Controller release after the visible opening preserves its tail")
	app._on_input_canceled()
	check(quest._opening and app.audio._chest_phase == "opening",
		"Global cancellation after release preserves the quest's committed shared audio performance")
	quest._chest._advance_animation(Feel.OPEN_SECONDS)
	check(quest.game.phase == "complete" and quest.game.total_clears == 1
		and not quest._next.disabled and app.audio._chest_rewarded,
		"Settling saves one reward, enables Next, and plays its shared success accent")
	check(_audio_events.count("reward") == reward_count + 1,
		"The main scene receives one reward sound request for the completed chest")
	var surprise_count: int = quest._chest.hold_effect_snapshot().surprise.play_count
	quest._reward_finished()
	quest._chest.finish_immediately()
	check(quest.game.total_clears == 1 and _audio_events.count("reward") == reward_count + 1
		and quest._chest.hold_effect_snapshot().surprise.play_count == surprise_count,
		"Duplicate completion cannot repeat collection, sound, or the decorative surprise")
	quest._chest._advance_animation(60.0)
	var retained: Dictionary = quest._chest.hold_effect_snapshot().surprise
	check(retained.active and retained.play_count == surprise_count,
		"The completed quest keeps its flying gift visible after the opening effects finish")
	quest.pause()
	check(quest._chest.hold_effect_snapshot().surprise.active
		and quest._chest.hold_effect_snapshot().surprise.kind == retained.kind,
		"The quest pause view preserves its already revealed gift")
	quest._continue_run()
	quest.set_process(false)
	quest._chest.set_process(false)
	quest._chest._advance_animation(60.0)
	check(quest.game.phase == "complete" and quest._chest.hold_effect_snapshot().surprise.active
		and quest._chest.hold_effect_snapshot().surprise.kind == retained.kind
		and quest._chest.hold_effect_snapshot().surprise.play_count == surprise_count
		and quest.game.total_clears == 1 and _audio_events.count("reward") == reward_count + 1,
		"Resuming the completed quest preserves the same gift without replaying rewards or sounds")


func _check_save_retry(app) -> void:
	var quest = app._quest
	if not _earn_chest(app):
		return
	var before: int = quest.game.total_clears
	var reward_count: int = _audio_events.count("reward")
	var path: String = quest.save_path
	var durable_before: Dictionary = _saved_progress(path)
	_confirm(app)
	# Saving a ConfigFile to an existing directory fails without touching any
	# user file. Restore the exact normal path before exercising Retry saving.
	quest.save_path = _directory
	quest._chest._advance_animation(Feel.OPEN_SECONDS + 0.1)
	check(quest.save_failed and quest.game.total_clears == before + 1 and quest._next.disabled,
		"A failed reward write retains one in-memory clear and blocks Next")
	check(_saved_progress(path) == durable_before and _audio_events.count("reward") == reward_count
		and not app.audio._chest_rewarded and not app.audio.chest_charge.playing,
		"Save failure leaves durable progress unchanged and stops motion without a success accent")
	var surprise_count: int = quest._chest.hold_effect_snapshot().surprise.play_count
	quest.save_path = path
	quest._save_retry.pressed.emit()
	var restored = QuestModel.new()
	check(restored.import_progress(_saved_progress(path)) and restored.total_clears == before + 1,
		"Retry writes the same earned reward to an importable durable checkpoint")
	check(not quest.save_failed and not quest._next.disabled and app.audio._chest_rewarded
		and _audio_events.count("reward") == reward_count + 1,
		"Only the successful explicit retry releases Next and acknowledges the saved reward")
	quest._save_retry.pressed.emit()
	quest._reward_finished()
	check(quest.game.total_clears == before + 1 and _audio_events.count("reward") == reward_count + 1
		and quest._chest.hold_effect_snapshot().surprise.play_count == surprise_count,
		"Repeated retry cannot award another clear or replay the reward surprise or accent")


func _check_reduced_motion(app) -> void:
	var quest = app._quest
	if not _earn_chest(app):
		return
	var before: int = quest.game.total_clears
	app.set_reduced_motion(true)
	_begin(app)
	quest._advance_chest_hold(Feel.HOLD_SECONDS - 0.01)
	check(quest.game.total_clears == before and quest._holding_chest,
		"Reduced motion still requires the same explicit confirmation hold")
	var state: Dictionary = quest._chest.hold_effect_snapshot()
	check(not state.animated and state.spark_count == 0 and state.physical_pose.rotation == 0.0,
		"Reduced confirmation keeps progress readable without chest motion or particles")
	quest._advance_chest_hold(0.02)
	check(quest.game.total_clears == before + 1 and quest._chest.mode == "opened"
		and app.audio._chest_rewarded and not app.audio.chest_charge.playing,
		"Reduced confirmation settles once with a saved success accent and no lingering tension bed")
	var reduced_gift: Dictionary = quest._chest.hold_effect_snapshot().surprise
	quest._chest._advance_animation(60.0)
	check(reduced_gift.active and quest._chest.hold_effect_snapshot().surprise.active
		and quest._chest.hold_effect_snapshot().surprise.kind == reduced_gift.kind
		and quest._chest.hold_effect_snapshot().surprise.bounds == reduced_gift.bounds,
		"Reduced-motion quest rewards retain the same static gift for the complete result view")
	app.set_reduced_motion(false)
	if not _earn_chest(app):
		return
	before = quest.game.total_clears
	_confirm(app)
	quest._chest._advance_animation(0.5)
	app.set_reduced_motion(true)
	app.set_reduced_motion(true)
	check(quest.game.total_clears == before + 1 and not quest._opening and app.audio._chest_rewarded,
		"Enabling reduced motion during a confirmed buildup completes the quest reward once")

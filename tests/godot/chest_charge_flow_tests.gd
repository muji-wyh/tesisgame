extends SceneTree

const Feel = preload("res://scripts/chest_feel.gd")

class BrowserStorage:
	extends RefCounted
	var fail_write: bool = false
	var writes: int = 0
	var saved: String = "[medals]\nversion=1\ncounts={}\n"

	func medalProgress() -> String:
		return saved

	func saveMedalProgress(value: String) -> bool:
		if fail_write:
			return false
		writes += 1
		saved = value
		return true

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _pieces(app) -> int:
	var total: int = 0
	for count in app.medal_progress.counts.values():
		total += int(count)
	return total


func _win(app, seed_value: int) -> void:
	var surprise_count: int = app.chest.hold_effect_snapshot().surprise.play_count
	check(app.new_round(seed_value), "The next real Match round starts")
	var surprise: Dictionary = app.chest.hold_effect_snapshot().surprise
	check(not surprise.active and str(surprise.kind).is_empty() and surprise.play_count == surprise_count,
		"A new round clears the decorative gift without replaying an automatically settled opening")
	app.choose_theme("spring")
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app.cards[card.id].pressed.emit()
			app.cards[card.word.id + ":image"].pressed.emit()
			app._continue_match()
	check(app.model.phase == "won" and app.model.chest_state == "closed",
		"Five real word-picture matches earn a closed chest")
	preload("res://tests/godot/player_flow_fixture.gd").finish_celebration(app)


func _begin(app) -> void:
	app.chest_button.button_down.emit()
	# Advance the actual hold controller deterministically, without adding live
	# frame time to simulated input while these scene assertions are running.
	app.set_process(false)


func _check_cancelled(app, pieces: int, reason: String) -> void:
	var surprise: Dictionary = app.chest.hold_effect_snapshot().surprise
	check(not surprise.active and str(surprise.kind).is_empty(),
		reason + " leaves no decorative gift from the cancelled opening")
	check(not app._holding_chest and is_zero_approx(app._hold_elapsed)
		and not app.chest.hold_effect_snapshot().active and is_zero_approx(app.chest.hold_effect_snapshot().release_flash),
		reason + " clears the hold and visible progress immediately")
	check(not app.audio._chest_charge_active and not app.audio.chest_charge.playing
		and app.audio.chest_charge.stream == null
		and app.audio._chest_players.all(func(player): return not player.playing or player.stream == app.audio._chest_stream(app.chest.theme_id, "cancel")),
		reason + " stops the pressure bed and old accents, allowing only the brief release feedback")
	check(app.model.chest_state == "closed" and app.chest.mode == "closed" and _pieces(app) == pieces
		and app._pending_fragment.is_empty() and app.model.reward_id.is_empty() and app.model.reward_theme.is_empty(),
		reason + " leaves the earned chest closed without awarding a piece")
	app._advance_ui(2.0)
	app.chest._advance_animation(Feel.OPEN_SECONDS + 1.0)
	app.chest.finish_immediately()
	app._on_chest_opened()
	check(app.model.chest_state == "closed" and _pieces(app) == pieces,
		reason + " cannot complete later from an old frame or finish callback")
	check(not app.chest.hold_effect_snapshot().surprise.active
		and app.chest.hold_effect_snapshot().surprise.play_count == surprise.play_count,
		reason + " cannot launch a decorative gift from stale completion callbacks")
	var next_player: int = app.audio._chest_next_player
	app._on_chest_cue(app.chest.theme_id, "hold_pulse", 1)
	app._on_chest_cue(app.chest.theme_id, "tension_pulse", 1)
	app.audio.set_chest_tension(1.0)
	check(app.audio._chest_next_player == next_player and not app.audio.chest_charge.playing,
		reason + " rejects a late rhythm pulse and progress update from the cancelled performance")


func _run() -> void:
	var directory := "user://chest-charge-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The scene uses isolated reward storage")
	var progress_script = load("res://scripts/medal_progress.gd")
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._mode_id = "match"
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_reduced_motion(false)
	app.audio.set_muted(false)
	var cues: Array = []
	app.chest.cue_requested.connect(func(theme_id: String, cue: String, step: int) -> void:
		cues.append([theme_id, cue, step]))
	_begin(app)
	check(not app._holding_chest and not app.chest.hold_effect_snapshot().active,
		"A hold before winning cannot charge a chest")
	_win(app, 81)
	check(_pieces(app) == 0, "Winning alone does not claim a piece")
	_begin(app)
	var state: Dictionary = app.chest.hold_effect_snapshot()
	check(app._holding_chest and state.active and state.phase == "holding" and state.percent == 0,
		"The real button-down signal immediately displays zero-percent charging")
	check(app.audio._chest_charge_active and app.audio.chest_charge.playing
		and app.audio.chest_charge.stream == app.audio._chest_charge_loop,
		"The same button-down arms the audible charge loop")
	app._process(0.25)
	check(is_zero_approx(app._hold_elapsed) and app.chest.hold_effect_snapshot().percent == 0,
		"A fresh press never consumes the preceding slow frame's 250 milliseconds")
	app._advance_ui(0.36)
	var elapsed: float = app._hold_elapsed
	var percent: int = app.chest.hold_effect_snapshot().percent
	var pitch: float = app.audio.chest_charge.pitch_scale
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	app._chest_input(touch)
	app.chest_button.button_down.emit()
	check(is_equal_approx(app._hold_elapsed, elapsed) and app.chest.hold_effect_snapshot().percent == percent
		and is_equal_approx(app.audio.chest_charge.pitch_scale, pitch),
		"Duplicate GUI and touch start notifications do not reset hold progress or pitch")
	app.chest_button.button_up.emit()
	_check_cancelled(app, 0, "Releasing an incomplete hold")
	_begin(app)
	check(app.chest.hold_effect_snapshot().percent == 0, "Reholding starts a fresh charge at zero")
	app._advance_ui(0.6)
	check(app.chest.hold_effect_snapshot().percent == 17 and app.audio.chest_charge.pitch_scale > pitch,
		"Confirmation advances its real share of the complete progress and rising audio pitch")
	app._advance_ui(0.51)
	check(not cues.any(func(item): return item[1] == "charge_step"),
		"The hold keeps its first progress star silent until one third of the complete buildup")
	app._advance_ui(0.02)
	check(app.model.chest_state == "closed" and cues.back() == ["spring", "charge_step", 1],
		"The first progress star lights during the hold immediately before confirmation")
	app._advance_ui(0.08)
	state = app.chest.hold_effect_snapshot()
	check(app.model.chest_state == "opening" and state.phase == "gathering" and state.percent == 35,
		"Completing confirmation keeps the gesture held while gathering advances")
	check(app._holding_chest and not app.chest_button.disabled,
		"The opening keeps both its held gesture and button release path active")
	check(cues.filter(func(item): return item[1] == "charge_step") == [["spring", "charge_step", 1]],
		"The automatic handoff does not replay the first progress star")
	check(not app.audio._chest_charge_active and app.audio.chest_charge.playing
		and app.audio._chest_phase == "opening",
		"Confirmation hands its audio loop to the automatic tension timeline")
	check(not app.audio._chest_rewarded and not cues.any(func(item): return item[1] == "release"),
		"Full charge neither announces the reward nor plays the later lid release")
	app.chest._process(0.25)
	check(is_zero_approx(app.chest.hold_effect_snapshot().opening_time)
		and not cues.any(func(item): return item[1] in ["unlock", "release", "settle"]),
		"Opening keeps its full initial tension instead of consuming the hold frame's 250 milliseconds")
	check(_pieces(app) == 0, "The piece still waits for the actual chest-opened callback")
	app.chest_button.button_up.emit()
	_check_cancelled(app, 0, "Releasing just after confirmation")
	for release_at in [2.0, Feel.HOLD_SECONDS + (Feel.PAUSE_START_TIME + Feel.RELEASE_TIME) * 0.5,
		Feel.HOLD_SECONDS + Feel.RELEASE_TIME - 0.01]:
		_begin(app)
		app._advance_ui(Feel.HOLD_SECONDS)
		app.chest.set_process(false)
		app.chest._advance_animation(release_at - Feel.HOLD_SECONDS)
		app._advance_ui(0.0)
		check(app.model.chest_state == "opening" and app._holding_chest and _pieces(app) == 0,
			"Holding for %.2f seconds still allows cancellation before the lid releases" % release_at)
		if release_at >= Feel.HOLD_SECONDS + Feel.PAUSE_START_TIME:
			check(app.chest.hold_effect_snapshot().anticipation_held and not app.chest.opening_committed(),
				"The real input controller still accepts cancellation during the held breath at %.2f seconds" % release_at)
		app.chest_button.button_up.emit()
		_check_cancelled(app, 0, "Releasing after %.2f seconds" % release_at)
	# A second press during the visual return must not be blocked or inherit
	# any of the abandoned opening's elapsed time, flash or reward selection.
	_begin(app)
	app._advance_ui(Feel.HOLD_SECONDS)
	app.chest._advance_animation(0.8)
	app.chest_button.button_up.emit()
	_begin(app)
	check(app._holding_chest and app.chest.hold_effect_snapshot().percent == 0
		and is_zero_approx(app.chest.hold_effect_snapshot().opening_time)
		and app._pending_fragment.is_empty(), "Repressing during rollback immediately starts from zero")
	app._on_chest_opened()
	app._advance_ui(0.2)
	check(app.model.chest_state == "closed" and _pieces(app) == 0 and app._holding_chest,
		"A stale completion after repressing cannot save or skip the new hold")
	app._advance_ui(1.0)
	cues.clear()
	var surprise_count: int = app.chest.hold_effect_snapshot().surprise.play_count
	app.chest.finish_immediately()
	app.chest_button.button_up.emit()
	var first_surprise: Dictionary = app.chest.hold_effect_snapshot().surprise
	check(first_surprise.active and not str(first_surprise.kind).is_empty()
		and first_surprise.play_count == surprise_count + 1,
		"The visible completed opening launches exactly one decorative gift")
	check(app.model.chest_state == "opened" and _pieces(app) == 1 and is_zero_approx(app.chest.hold_effect_snapshot().release_flash),
		"Finishing the actual opening claims exactly one piece")
	check(app.audio._chest_rewarded and app._chest_reward_announced,
		"The saved reward is announced after the piece was persisted")
	check(not cues.any(func(item): return item[1] in ["unlock", "release", "settle"]),
		"Skipping the opening never replays missed physical cues")
	app._on_chest_opened()
	app.chest.finish_immediately()
	_begin(app)
	app._advance_ui(2.0)
	check(_pieces(app) == 1 and not app.chest.hold_effect_snapshot().active,
		"Repeated opening callbacks and a hold on the opened chest cannot duplicate the reward")
	check(app.chest.hold_effect_snapshot().surprise.play_count == first_surprise.play_count
		and app.chest.hold_effect_snapshot().surprise.kind == first_surprise.kind,
		"Repeated completion and button signals do not reroll or replay the decorative gift")
	var saved = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	check(saved.load_progress() and saved.count_for("spring-1") == 1,
		"The single earned piece survives reloading the real save")

	_win(app, 82)
	_begin(app)
	app._advance_ui(0.4)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = Vector2(24, 0)
	motion.position = Vector2(74, 50)
	app._chest_input(motion)
	_check_cancelled(app, 1, "Dragging the chest beyond the movement threshold")
	app.chest_button.button_up.emit()
	_begin(app)
	app._advance_ui(0.4)
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(0, 24)
	drag.position = Vector2(50, 74)
	app._chest_input(drag)
	_check_cancelled(app, 1, "Dragging the chest with a touch")
	app.chest_button.button_up.emit()
	_begin(app)
	app._advance_ui(0.4)
	app._toggle_collection()
	_check_cancelled(app, 1, "Opening More during a hold")
	_begin(app)
	check(app.collection_page.visible and not app._holding_chest and not app.audio._chest_charge_active,
		"A late start while More is open cannot restart charge feedback")
	app._hide_collection()
	_begin(app)
	app._advance_ui(0.4)
	app.on_page_hidden()
	_check_cancelled(app, 1, "Backgrounding the game during a hold")
	_begin(app)
	check(not app._holding_chest and not app.audio._chest_charge_active,
		"A late start while the page is hidden cannot restart charging")
	app.on_page_visible()
	_begin(app)
	check(app._holding_chest, "Returning to the foreground permits a fresh hold")
	app._advance_ui(0.4)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check_cancelled(app, 1, "Losing native application focus during a hold")
	_begin(app)
	check(not app._holding_chest and not app.audio._chest_charge_active,
		"A stale press cannot restart a native hold until application focus returns")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_begin(app)
	check(app._holding_chest, "Regaining native application focus permits a fresh press")
	app._advance_ui(0.4)
	check(app.new_round(83), "A new round can leave an earned chest during a hold")
	check(_pieces(app) == 2 and app.model.chest_state == "closed" and app.model.phase == "waiting"
		and not app._holding_chest and not app.chest.hold_effect_snapshot().active
		and not app.audio._chest_charge_active and not app.audio.chest_charge.playing,
		"A new round preserves the existing one-piece auto-claim and clears all old charge feedback")
	app._advance_ui(2.0)
	app._on_chest_opened()
	check(_pieces(app) == 2, "Late hold frames and open callbacks cannot award the new round a piece")

	_win(app, 84)
	_begin(app)
	app._advance_ui(0.4)
	app.choose_theme("winter")
	_check_cancelled(app, 2, "Changing worlds during an unfinished hold")
	check(app.chest.theme_id == "winter", "A new world cannot inherit the previous world's hold or sound")
	app.choose_theme("spring")
	app.chest_button.grab_focus()
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	app._input(accept)
	app.set_process(false)
	app._advance_ui(0.4)
	check(app._controller_holding_chest and app.chest.hold_effect_snapshot().active,
		"Controller A drives the same real chest charge")
	accept.pressed = false
	app._input(accept)
	_check_cancelled(app, 2, "Releasing controller A")
	accept.pressed = true
	app._input(accept)
	app.set_process(false)
	app._advance_ui(0.4)
	app._on_joy_connection_changed(0, false)
	_check_cancelled(app, 2, "Disconnecting the controller")
	check(not app._controller_holding_chest, "A controller disconnect clears its held-action latch")
	_begin(app)
	app._advance_ui(0.4)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_input(escape)
	_check_cancelled(app, 2, "Pressing Escape during a hold")
	app.chest_button.grab_focus()
	accept.pressed = true
	app._input(accept)
	app.set_process(false)
	app._advance_ui(0.4)
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	app._input(back)
	_check_cancelled(app, 2, "Pressing controller B during a hold")
	check(not app._controller_holding_chest, "Controller Back also clears the held-action latch")
	for input_kind in ["mouse release", "touch release", "touch cancellation", "mouse drag", "touch drag", "controller release", "controller disconnect", "controller back", "Escape", "More"]:
		app.chest_button.grab_focus()
		if input_kind.begins_with("controller"):
			accept.pressed = true
			app._input(accept)
			app.set_process(false)
		else:
			_begin(app)
		app._advance_ui(Feel.HOLD_SECONDS)
		app.chest.set_process(false)
		app.chest._advance_animation(0.8)
		check(app.model.chest_state == "opening" and app._holding_chest,
			input_kind + " reaches the same two-second active opening")
		match input_kind:
			"mouse release":
				var release := InputEventMouseButton.new()
				release.button_index = MOUSE_BUTTON_LEFT
				release.pressed = false
				app._chest_input(release)
			"touch release", "touch cancellation":
				var release := InputEventScreenTouch.new()
				release.pressed = false
				release.canceled = input_kind == "touch cancellation"
				app._chest_input(release)
			"mouse drag":
				app._chest_input(motion)
			"touch drag":
				app._chest_input(drag)
			"controller release":
				accept.pressed = false
				app._input(accept)
			"controller disconnect":
				app._on_joy_connection_changed(0, false)
			"controller back":
				app._input(back)
			"Escape":
				app._unhandled_input(escape)
			"More":
				app._toggle_collection()
		_check_cancelled(app, 2, input_kind + " during the opening")
		app._end_chest_hold()
		if input_kind == "More":
			app._hide_collection()
		accept.pressed = false
		app._input(accept)

	app.set_reduced_motion(true)
	_begin(app)
	app._advance_ui(0.6)
	state = app.chest.hold_effect_snapshot()
	check(state.active and state.percent == 50 and state.text.contains("50%")
		and not state.animated and state.spark_count == 0 and _pieces(app) == 2,
		"Reduced motion keeps real readable hold progress without particles or an early reward")
	app.chest_button.button_up.emit()
	_check_cancelled(app, 2, "Releasing a reduced-motion hold")
	_begin(app)
	app._advance_ui(1.21)
	check(app.model.chest_state == "opened" and _pieces(app) == 3
		and not app.chest.hold_effect_snapshot().active
		and is_zero_approx(app.chest.hold_effect_snapshot().release_flash),
		"A full reduced-motion hold completes once without the opening motion")
	app._on_chest_opened()
	check(_pieces(app) == 3, "Reduced-motion completion also ignores duplicate callbacks")

	# Exercise persistence with audible feedback enabled. A failed save must not
	# announce success, and a visible retry must announce one saved piece only.
	var storage := BrowserStorage.new()
	app.medal_progress = progress_script.new(directory + "/retry.cfg", directory + "/retry-legacy.cfg", storage)
	check(app.medal_progress.load_progress(), "The retry scenario starts with isolated browser storage")
	app.set_reduced_motion(false)
	_win(app, 85)
	storage.fail_write = true
	_begin(app)
	app._advance_ui(1.21)
	app.chest.set_process(false)
	app.chest._advance_animation(Feel.ANTICIPATION_TIME + 0.01)
	app.chest._advance_animation(Feel.UNLOCK_TIME - 0.02 - app.chest.hold_effect_snapshot().opening_time)
	state = app.chest.hold_effect_snapshot()
	check(state.percent > 90 and state.percent < 100 and _pieces(app) == 0
		and not app.audio._chest_rewarded and not app.audio._chest_seen.has("release0"),
		"Late in the buildup, anticipation has not saved or announced a reward")
	check(app.audio.chest_charge.playing and app.audio._chest_seen.has("anticipation0"),
		"The final transition keeps the continuous pressure bed audible before unlocking")
	app.chest._advance_animation(0.03)
	check(app.audio.chest_charge.playing and app.audio._chest_seen.has("unlock0")
		and not app.audio._chest_seen.has("release0"),
		"Unlocking adds its material accent without cutting the pressure bed")
	app.chest._advance_animation(Feel.RELEASE_TIME - Feel.UNLOCK_TIME)
	check(app.chest.hold_effect_snapshot().release_flash > 0.0
		and _pieces(app) == 0 and not app.audio._chest_rewarded and not app.audio.chest_charge.playing,
		"Physical release lights the chest cavity immediately without a separate delayed global burst or early reward")
	app.chest._advance_animation(Feel.SETTLE_TIME - Feel.RELEASE_TIME)
	check(app.audio._chest_seen.has("unlock0") and app.audio._chest_seen.has("release0")
		and app.audio._chest_seen.has("settle0"), "Real opening motion drives the three physical sound beats")
	app.chest.finish_immediately()
	check(app._save_error and _pieces(app) == 0 and not app._chest_reward_announced
		and not app.audio._chest_rewarded, "A failed reward save never announces a saved reward")
	var failed_save_surprise: Dictionary = app.chest.hold_effect_snapshot().surprise
	check(failed_save_surprise.active and not str(failed_save_surprise.kind).is_empty() and storage.writes == 0,
		"The opening's decorative gift does not depend on or create a successful save")
	app._retry_reward_save()
	check(storage.writes == 0 and not app.audio._chest_rewarded,
		"Repeated failed retries do not play a success sound")
	check(app.chest.hold_effect_snapshot().surprise.play_count == failed_save_surprise.play_count
		and app.chest.hold_effect_snapshot().surprise.kind == failed_save_surprise.kind,
		"A failed save retry does not reroll the visible decorative gift")
	app.on_page_hidden()
	app.chest._advance_animation(60.0)
	check(app.chest.hold_effect_snapshot().surprise.active
		and app.chest.hold_effect_snapshot().surprise.kind == failed_save_surprise.kind
		and app.chest.hold_effect_snapshot().surprise.play_count == failed_save_surprise.play_count
		and app.chest.hold_effect_snapshot().surprise.age == failed_save_surprise.age
		and storage.writes == 0,
		"Backgrounding freezes the revealed gift while the failed reward save remains pending")
	app.on_page_visible()
	app.audio.set_muted(true)
	app.audio.set_muted(false)
	storage.fail_write = false
	app._retry_reward_save()
	check(storage.writes == 1 and _pieces(app) == 1 and app.audio._chest_rewarded,
		"An explicit successful retry after background/mute saves and announces the waiting reward once")
	app.chest._advance_animation(60.0)
	check(app.chest.hold_effect_snapshot().surprise.active
		and app.chest.hold_effect_snapshot().surprise.kind == failed_save_surprise.kind
		and app.chest.hold_effect_snapshot().surprise.play_count == failed_save_surprise.play_count,
		"A successful save retry retains the same gift without replaying its flight")
	check(not app.audio._chest_seen.has("release0") and not app.audio._chest_seen.has("unlock0"),
		"A successful retry after interruption never replays missed physical sounds")
	app._retry_reward_save()
	app._on_chest_opened()
	check(storage.writes == 1 and _pieces(app) == 1, "Stale retries and callbacks cannot write a second reward")
	_win(app, 86)
	_begin(app)
	app._advance_ui(1.21)
	app.chest._advance_animation(float(Feel.PULSE_TIMES[0]) + 0.001)
	check(app.audio._chest_last_tension_pulse == 1 and app.audio.chest_charge.playing,
		"Background interruption exercises an actual audible rhythm after its first synchronized kick")
	cues.clear()
	app.on_page_hidden()
	check(_pieces(app) == 1 and app.model.chest_state == "closed" and cues.all(func(item): return item[1] == "cancel")
		and app.audio._chest_phase == "idle" and is_zero_approx(app.chest.hold_effect_snapshot().release_flash),
		"Backgrounding an incomplete opening cancels it without saving or replaying a sound")
	app.on_page_visible()
	cues.clear()
	app.chest._advance_animation(Feel.OPEN_SECONDS + 1.0)
	app._on_chest_cue("spring", "tension_pulse", 2)
	app.audio.set_chest_tension(1.0)
	app._on_chest_opened()
	check(_pieces(app) == 1 and app.model.chest_state == "closed" and app.audio._chest_phase == "idle" and cues.is_empty()
		and not app.audio.chest_charge.playing and is_zero_approx(app.chest.hold_effect_snapshot().release_flash),
		"Foregrounding and stale callbacks cannot resume or reward the interrupted opening")
	_begin(app)
	app._advance_ui(Feel.HOLD_SECONDS)
	app.chest.finish_immediately()
	check(_pieces(app) == 2, "The earned chest remains available to reopen after background cancellation")
	_win(app, 87)
	_begin(app)
	app._advance_ui(1.21)
	cues.clear()
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(_pieces(app) == 2 and app.model.chest_state == "closed" and cues.all(func(item): return item[1] == "cancel")
		and app.audio._chest_phase == "idle",
		"Native focus loss during opening cancels the gesture without saving a reward")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	cues.clear()
	app.chest._advance_animation(2.0)
	app._on_chest_opened()
	check(_pieces(app) == 2 and app.model.chest_state == "closed" and cues.is_empty() and app.audio._chest_phase == "idle",
		"Duplicate native focus events and stale frames cannot complete the cancelled gesture")
	_begin(app)
	app._advance_ui(Feel.HOLD_SECONDS)
	app.chest.finish_immediately()
	check(_pieces(app) == 3, "Regaining focus permits a fresh opening of the unclaimed chest")
	_win(app, 88)
	app.set_reduced_motion(true)
	storage.fail_write = true
	_begin(app)
	app._advance_ui(1.21)
	check(app._save_error and _pieces(app) == 3 and not app.audio._chest_rewarded
		and not app.audio.chest_charge.playing and is_equal_approx(app.audio._chest_music_duck, 1.0),
		"A reduced-motion save failure leaves no tension loop or music duck and does not announce success")
	storage.fail_write = false
	app._retry_reward_save()
	check(_pieces(app) == 4, "The reduced-motion failure remains safely retryable")
	_win(app, 89)
	app.set_reduced_motion(false)
	storage.fail_write = true
	_begin(app)
	app._advance_ui(1.21)
	app.chest._advance_animation(1.0)
	check(app.audio.chest_charge.playing, "The interrupted scenario starts with an active automatic tension loop")
	cues.clear()
	app.set_reduced_motion(true)
	check(app._save_error and _pieces(app) == 4 and not app.audio._chest_rewarded
		and not app.audio.chest_charge.playing and is_equal_approx(app.audio._chest_music_duck, 1.0)
		and not cues.any(func(item): return item[1] in ["unlock", "release", "settle"]),
		"Reducing motion during buildup stops tension without missed accents even when saving fails")
	storage.fail_write = false
	app._retry_reward_save()
	check(_pieces(app) == 5, "The interrupted reduced-motion failure saves one piece on explicit retry")
	_win(app, 91)
	app.set_reduced_motion(false)
	_begin(app)
	app._advance_ui(1.21)
	app.chest._advance_animation(Feel.ANTICIPATION_TIME + 0.001)
	check(app.audio.chest_charge.playing and app.audio._chest_seen.has("anticipation0"),
		"The stalled-release scenario reaches the audible final pressure rise")
	var stalled_pieces: int = _pieces(app)
	var stalled_writes: int = storage.writes
	var stalled_player: int = app.audio._chest_next_player
	cues.clear()
	app.chest._advance_animation(Feel.RELEASE_TIME + 0.24 - app.chest.hold_effect_snapshot().opening_time)
	check(app.chest.performance_phase() == "release" and cues.is_empty()
		and not app.audio._chest_seen.has("release0"),
		"A frame beyond the release freshness window consumes missed accents without replaying them")
	app._advance_ui(0.0)
	check(not app.audio.chest_charge.playing and app.audio.chest_charge.stream == null,
		"Physical release stops the pressure bed even when its one-shot cue was suppressed")
	check(app.model.chest_state == "opening" and _pieces(app) == stalled_pieces
		and storage.writes == stalled_writes and not app.audio._chest_rewarded
		and cues.is_empty() and app.audio._chest_next_player == stalled_player,
		"Stopping stale pressure adds no late cue, saved piece or early reward")
	for frame in range(3):
		app.chest._advance_animation(0.05)
		app._advance_ui(0.0)
		app.audio.set_chest_tension(1.0)
	check(not app.audio.chest_charge.playing and app.audio.chest_charge.stream == null
		and cues.is_empty() and app.audio._chest_next_player == stalled_player
		and _pieces(app) == stalled_pieces and storage.writes == stalled_writes,
		"Later release frames and stale tension updates cannot restart the bed or replay missed accents")
	app.chest.finish_immediately()
	check(_pieces(app) == stalled_pieces + 1 and storage.writes == stalled_writes + 1,
		"The stalled opening still saves exactly one reward at actual completion")
	_win(app, 90)
	app.set_reduced_motion(false)
	_begin(app)
	app._advance_ui(1.21)
	app._show_collection()
	app._advance_ui(0.25)
	check(app.collection_page.visible and app._chest_announced_percent == -1,
		"The room keeps hidden chest progress hidden on later automatic-opening frames")
	app.on_page_hidden()
	app.audio.halt()
	app.set_process(false)
	await process_frame
	app.free()
	await process_frame
	await _check_release_commitment(directory)
	await _check_gameplay_pixels(directory)
	print("Chest charge flow: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_release_commitment(directory: String) -> void:
	var storage := BrowserStorage.new()
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(
		directory + "/committed.cfg", directory + "/committed-legacy.cfg", storage)
	app._mode_id = "match"
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_reduced_motion(false)
	app.audio.set_muted(false)
	var cues: Array = []
	app.chest.cue_requested.connect(func(theme_id: String, cue: String, step: int) -> void:
		cues.append([theme_id, cue, step]))
	var seed_value: int = 700
	for release_time in [Feel.RELEASE_TIME, Feel.RELEASE_TIME + 0.24, Feel.OPEN_SECONDS - 0.01]:
		seed_value += 1
		_win(app, seed_value)
		var pieces: int = _pieces(app)
		var writes: int = storage.writes
		_begin(app)
		app._advance_ui(Feel.HOLD_SECONDS)
		app.chest.set_process(false)
		app.chest._advance_animation(Feel.RELEASE_TIME - 0.001)
		check(app._holding_chest and not app.chest.opening_committed() and _pieces(app) == pieces,
			"The gesture remains cancellable one millisecond before its physical release")
		cues.clear()
		app.chest._advance_animation(release_time - app.chest.hold_effect_snapshot().opening_time)
		var committed: Dictionary = app.chest.hold_effect_snapshot()
		var pending: Dictionary = app._pending_fragment.duplicate(true)
		check(not app._holding_chest and app.chest.opening_committed() and app.model.chest_state == "opening"
			and not pending.is_empty() and _pieces(app) == pieces and storage.writes == writes,
			"The physical lid release frees the held gesture while retaining its unclaimed reward")
		if release_time > Feel.RELEASE_TIME + 0.20:
			check(not cues.any(func(item): return item[1] == "release"),
				"A stale release accent is suppressed without suppressing the irreversible state transition")
		app.chest_button.button_up.emit()
		var touch_release := InputEventScreenTouch.new()
		touch_release.pressed = false
		app._chest_input(touch_release)
		app._end_chest_hold()
		var released: Dictionary = app.chest.hold_effect_snapshot()
		check(app.model.chest_state == "opening" and app.chest.opening_committed()
			and released.opening_time == committed.opening_time and released.pose_signature == committed.pose_signature
			and released.release_flash == committed.release_flash and app._pending_fragment == pending
			and not cues.any(func(item): return item[1] == "cancel"),
			"Mouse and touch release after %.2f seconds preserve the full opening tail and light" % (Feel.HOLD_SECONDS + release_time))
		app._on_chest_opened()
		app._advance_ui(0.0)
		check(_pieces(app) == pieces and storage.writes == writes and app.model.chest_state == "opening",
			"A completion callback before the physical tail finishes cannot claim the committed reward early")
		app.chest._advance_animation(Feel.OPEN_SECONDS - released.opening_time - 0.001)
		check(app.model.chest_state == "opening" and _pieces(app) == pieces and storage.writes == writes,
			"Letting go does not shorten the five-second opening performance")
		var before_surprise: Dictionary = app.chest.hold_effect_snapshot().surprise
		check(not before_surprise.active, "The decorative gift waits until the entire opening is complete")
		var growth_before: Dictionary = app.growth.snapshot().streaks.duplicate()
		app.chest._advance_animation(0.002)
		var completed_surprise: Dictionary = app.chest.hold_effect_snapshot().surprise
		check(app.model.chest_state == "opened" and _pieces(app) == pieces + 1 and storage.writes == writes + 1
			and app.chest.hold_effect_snapshot().opened_glow > 0.0,
			"The released opening saves once at its original deadline and keeps its themed glow")
		check(completed_surprise.active and not str(completed_surprise.kind).is_empty()
			and completed_surprise.play_count == before_surprise.play_count + 1
			and app.growth.snapshot().streaks == growth_before,
			"Completion adds one displayed gift without collecting a sticker or another saved reward")
		app.chest_button.button_up.emit()
		app.chest.cancel_open(true)
		app._on_chest_opened()
		app.chest.finish_immediately()
		app.chest._advance_animation(0.5)
		check(_pieces(app) == pieces + 1 and storage.writes == writes + 1
			and app.chest.hold_effect_snapshot().opened_glow > 0.0,
			"Repeated releases and old callbacks cannot retract or duplicate the opened reward")
		check(app.chest.hold_effect_snapshot().surprise.play_count == completed_surprise.play_count
			and app.chest.hold_effect_snapshot().surprise.kind == completed_surprise.kind,
			"Old release and completion callbacks preserve the same decorative gift")
		app.chest._advance_animation(60.0)
		var retained_surprise: Dictionary = app.chest.hold_effect_snapshot().surprise
		check(retained_surprise.active and retained_surprise.kind == completed_surprise.kind
			and retained_surprise.play_count == completed_surprise.play_count
			and _pieces(app) == pieces + 1 and storage.writes == writes + 1
			and app.growth.snapshot().streaks == growth_before,
			"The settled gift stays visible without adding save writes, pieces or collected words")
		var cue_count: int = cues.size()
		app.on_page_hidden()
		app.chest._advance_animation(60.0)
		check(app.chest.hold_effect_snapshot().surprise == retained_surprise,
			"Backgrounding freezes the earned gift instead of discarding it")
		app.on_page_visible()
		app.chest.set_process(false)
		app.chest._advance_animation(60.0)
		check(app.chest.hold_effect_snapshot().surprise.active
			and app.chest.hold_effect_snapshot().surprise.kind == completed_surprise.kind
			and app.chest.hold_effect_snapshot().surprise.play_count == completed_surprise.play_count
			and cues.size() == cue_count and _pieces(app) == pieces + 1 and storage.writes == writes + 1,
			"Returning to the result preserves its gift without replaying chest cues or saving again")
		app.set_reduced_motion(true)
		app.chest._advance_animation(60.0)
		check(app.chest.hold_effect_snapshot().surprise.active
			and app.chest.hold_effect_snapshot().surprise.kind == completed_surprise.kind
			and app.chest.hold_effect_snapshot().surprise.play_count == completed_surprise.play_count,
			"Changing motion preference preserves the earned gift on the result")
		app.set_reduced_motion(false)

	for interruption in ["background", "More", "native focus"]:
		seed_value += 1
		_win(app, seed_value)
		var pieces: int = _pieces(app)
		var writes: int = storage.writes
		var surprise_count: int = app.chest.hold_effect_snapshot().surprise.play_count
		_begin(app)
		app._advance_ui(Feel.HOLD_SECONDS)
		app.chest.set_process(false)
		app.chest._advance_animation(Feel.RELEASE_TIME + 0.01)
		check(app.chest.opening_committed() and not app._holding_chest,
			interruption + " exercises an already released lid before the save deadline")
		cues.clear()
		match interruption:
			"background": app.on_page_hidden()
			"More": app._show_collection()
			"native focus": app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(app.model.chest_state == "opened" and _pieces(app) == pieces + 1 and storage.writes == writes + 1
			and cues.is_empty() and not app.audio._chest_rewarded and not app.audio.chest_charge.playing
			and app.audio._chest_players.all(func(player): return not player.playing),
			interruption + " silently saves the committed opening without replaying its remaining sounds")
		check(not app.chest.hold_effect_snapshot().surprise.active
			and app.chest.hold_effect_snapshot().surprise.play_count == surprise_count,
			interruption + " settles the opening without launching a hidden decorative gift")
		match interruption:
			"background": app.on_page_visible()
			"More": app._hide_collection()
			"native focus": app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		app.chest_button.button_up.emit()
		app._on_chest_opened()
		app.chest._advance_animation(Feel.OPEN_SECONDS + 1.0)
		check(_pieces(app) == pieces + 1 and storage.writes == writes + 1 and cues.is_empty()
			and app.chest.hold_effect_snapshot().opened_glow > 0.0,
			"Returning from " + interruption + " retains the saved light without a late sound or duplicate reward")
		check(not app.chest.hold_effect_snapshot().surprise.active
			and app.chest.hold_effect_snapshot().surprise.play_count == surprise_count,
			"Returning from " + interruption + " cannot replay a decorative gift that was skipped")

	for interruption in ["background", "More"]:
		seed_value += 1
		_win(app, seed_value)
		var pieces: int = _pieces(app)
		var writes: int = storage.writes
		storage.fail_write = true
		_begin(app)
		app._advance_ui(Feel.HOLD_SECONDS)
		app.chest.set_process(false)
		app.chest._advance_animation(Feel.RELEASE_TIME + 0.01)
		var pending: Dictionary = app._pending_fragment.duplicate(true)
		if interruption == "background":
			app.on_page_hidden()
		else:
			app._show_collection()
		check(app._save_error and app.model.chest_state == "opened" and app._pending_fragment == pending
			and _pieces(app) == pieces and storage.writes == writes and not app.audio._chest_rewarded,
			interruption + " preserves the exact committed reward when persistence fails")
		if interruption == "background":
			app.on_page_visible()
		else:
			app._hide_collection()
		app._retry_reward_save()
		check(app._save_error and _pieces(app) == pieces and storage.writes == writes,
			"An unsuccessful retry cannot discard or duplicate the committed reward")
		storage.fail_write = false
		app._retry_reward_save()
		app._retry_reward_save()
		app._on_chest_opened()
		check(not app._save_error and _pieces(app) == pieces + 1 and storage.writes == writes + 1
			and app.audio._chest_rewarded, "An explicit successful retry saves the same committed reward once")

	seed_value += 1
	_win(app, seed_value)
	var pieces: int = _pieces(app)
	var writes: int = storage.writes
	var before_skip_surprise: int = app.chest.hold_effect_snapshot().surprise.play_count
	_begin(app)
	app._advance_ui(Feel.HOLD_SECONDS)
	app.chest.set_process(false)
	app.chest._advance_animation(Feel.RELEASE_TIME)
	check(app.new_round(seed_value + 1) and app.model.phase == "waiting"
		and _pieces(app) == pieces + 1 and storage.writes == writes + 1,
		"Explicitly skipping the committed tail still saves its single earned reward before the next round")
	app._on_chest_opened()
	app.chest._advance_animation(Feel.OPEN_SECONDS + 1.0)
	check(_pieces(app) == pieces + 1 and storage.writes == writes + 1,
		"Late callbacks from the skipped opening cannot award the next round")
	check(not app.chest.hold_effect_snapshot().surprise.active
		and app.chest.hold_effect_snapshot().surprise.play_count == before_skip_surprise,
		"Skipping to another round clears decorative state without a late gift flight")
	app.audio.halt()
	app.free()
	await process_frame


func _body_center(chest) -> Vector2:
	for piece in chest._pieces:
		if piece.role in ["body", "chest"]:
			var sprite: Sprite2D = piece.node
			# Headless screen transforms omit the window's canvas stretch. These
			# EXPAND layouts fill the window, so map actual sprite canvas geometry
			# through the requested viewport dimensions explicitly.
			var point: Vector2 = sprite.get_global_transform_with_canvas() * sprite.get_rect().get_center()
			return point * Vector2(root.size) / root.get_visible_rect().size
	return Vector2.ZERO


func _buildup_trace(app) -> Array:
	var trace: Array = []
	_begin(app)
	for frame in range(1, 73):
		var target: float = Feel.HOLD_SECONDS * float(frame) / 72.0
		var delta: float = target - app._hold_elapsed
		app._advance_ui(delta)
		if app.model.chest_state == "closed":
			app.chest._advance_animation(delta)
		trace.append({"time": target, "point": _body_center(app.chest),
			"glow": app.chest.hold_effect_snapshot().buildup_glow})
	for frame in range(1, ceili(Feel.RELEASE_TIME * 60.0) + 1):
		var target: float = minf(float(frame) / 60.0, Feel.RELEASE_TIME - 0.001)
		app.chest._advance_animation(target - app.chest.hold_effect_snapshot().opening_time)
		app._advance_ui(0.0)
		trace.append({"time": Feel.HOLD_SECONDS + target, "point": _body_center(app.chest),
			"glow": app.chest.hold_effect_snapshot().buildup_glow})
	return trace


func _motion_window(trace: Array, start: float, end: float) -> Dictionary:
	var points: Array = trace.filter(func(sample): return sample.time >= start and sample.time <= end)
	var minimum: float = INF
	var maximum: float = -INF
	var minimum_y: float = INF
	var maximum_y: float = -INF
	var minimum_glow: float = INF
	var maximum_glow: float = -INF
	var glow: float = 0.0
	var quiet: float = 0.0
	var longest_quiet: float = 0.0
	for index in range(points.size()):
		minimum = minf(minimum, points[index].point.x)
		maximum = maxf(maximum, points[index].point.x)
		minimum_y = minf(minimum_y, points[index].point.y)
		maximum_y = maxf(maximum_y, points[index].point.y)
		minimum_glow = minf(minimum_glow, points[index].glow)
		maximum_glow = maxf(maximum_glow, points[index].glow)
		glow += points[index].glow
		if index > 0:
			if absf(points[index].point.x - points[index - 1].point.x) < 0.20:
				quiet += points[index].time - points[index - 1].time
			else:
				quiet = 0.0
			longest_quiet = maxf(longest_quiet, quiet)
	return {"span": maximum - minimum, "vertical_span": maximum_y - minimum_y,
		"glow": glow / maxf(1.0, points.size()), "glow_span": maximum_glow - minimum_glow,
		"duration": points.back().time - points.front().time if points.size() > 1 else 0.0,
		"quiet": longest_quiet}


func _check_gameplay_pixels(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/visible.cfg", directory + "/visible-legacy.cfg")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	root.add_child(app)
	for frame in range(4):
		await process_frame
	app.set_reduced_motion(false)
	app.audio.set_muted(true)
	var seed_value: int = 300
	var first_range := Vector2(INF, -INF)
	var late_range := Vector2(INF, -INF)
	var first_min_case: String = ""
	var late_min_case: String = ""
	var envelope_min := Vector3(INF, INF, INF)
	var envelope_max := Vector3.ZERO
	var longest_quiet: float = 0.0
	for dimensions in [Vector2i(390, 664), Vector2i(844, 390), Vector2i(1024, 768), Vector2i(1366, 768)]:
		root.size = dimensions
		for theme_id in app.data.THEMES:
			seed_value += 1
			_win(app, seed_value)
			app.choose_theme(theme_id)
			app.set_process(false)
			app.chest.set_process(false)
			for frame in range(4):
				await process_frame
			check(app.chest.is_visible_in_tree() and app._stage.size.y > 0,
				"The %s chest uses the real visible result stage at %s" % [theme_id, dimensions])
			_begin(app)
			var first_time: float = float(Feel.HOLD_PULSE_TIMES[0])
			app._advance_ui(first_time - 0.001)
			app.chest._advance_animation(first_time - 0.001)
			var before: Vector2 = _body_center(app.chest)
			app._advance_ui(0.00101)
			app.chest._advance_animation(0.00101)
			app._advance_ui(0.025)
			app.chest._advance_animation(0.025)
			var first: float = _body_center(app.chest).distance_to(before)
			if first < first_range.x:
				first_min_case = "%s at %s" % [theme_id, dimensions]
			first_range = Vector2(minf(first_range.x, first), maxf(first_range.y, first))
			check(first >= 0.5, "%s at viewport %s/stage %s: first accelerating body beat is visible at %.2f screen pixels" %
				[theme_id, dimensions, app._stage.size, first])
			for beat in Feel.HOLD_PULSE_TIMES.slice(1):
				var delta: float = float(beat) + 0.00001 - app._hold_elapsed
				app._advance_ui(delta)
				app.chest._advance_animation(delta)
			app._advance_ui(Feel.HOLD_SECONDS + 0.00001 - app._hold_elapsed)
			check(app.model.chest_state == "opening" and app.chest.mode == "opening",
				"The real %s hold controller starts the automatic sequence at %s" % [theme_id, dimensions])
			var late: float = 0.0
			for beat in Feel.PULSE_TIMES:
				app.chest._advance_animation(float(beat) - 0.001 - app.chest.hold_effect_snapshot().opening_time)
				before = _body_center(app.chest)
				app.chest._advance_animation(0.00101)
				app.chest._advance_animation(0.025)
				if is_equal_approx(float(beat), float(Feel.PULSE_TIMES.back())):
					late = _body_center(app.chest).distance_to(before)
			if late < late_range.x:
				late_min_case = "%s at %s" % [theme_id, dimensions]
			late_range = Vector2(minf(late_range.x, late), maxf(late_range.y, late))
			check(late >= 2.0 and late > first, "%s at viewport %s/stage %s: final body rocking grows to %.2f screen pixels" %
				[theme_id, dimensions, app._stage.size, late])
			var cues: Array = app.chest.hold_effect_snapshot().cues
			check(cues.filter(func(cue): return cue.cue == "hold_pulse").size() == 5
				and cues.filter(func(cue): return cue.cue == "tension_pulse").size() == 15,
				"The real %s result emits all twenty body beats at %s" % [theme_id, dimensions])
			app._end_chest_hold()
			var trace: Array = _buildup_trace(app)
			var early: Dictionary = _motion_window(trace, 0.08, 0.55)
			var middle: Dictionary = _motion_window(trace, 1.35, 1.85)
			var final: Dictionary = _motion_window(trace, 2.80, Feel.HOLD_SECONDS + Feel.ANTICIPATION_TIME)
			var held: Dictionary = _motion_window(trace, Feel.HOLD_SECONDS + Feel.PAUSE_START_TIME,
				Feel.HOLD_SECONDS + Feel.RELEASE_TIME)
			var envelope := Vector3(early.span, middle.span, final.span)
			envelope_min = envelope_min.min(envelope)
			envelope_max = envelope_max.max(envelope)
			longest_quiet = maxf(longest_quiet, final.quiet)
			check(middle.span > early.span * 1.20 and final.span > middle.span * 1.35 and final.span >= 8.0,
				"The actual %s body at %s grows from %.2f to %.2f to %.2f screen-pixel shake spans" %
				[theme_id, dimensions, early.span, middle.span, final.span])
			check(final.quiet <= 0.075,
				"The actual %s final roll at %s stays active before its deliberate brake (longest quiet interval %.0f milliseconds)" %
				[theme_id, dimensions, final.quiet * 1000.0])
			check(held.duration >= 0.14 and held.span < 0.01 and held.vertical_span < 0.01 and held.glow_span < 0.000001,
				"The actual %s body and buildup glow at %s hold for %.0f milliseconds before the release (%.4f by %.4f screen pixels)" %
				[theme_id, dimensions, held.duration * 1000.0, held.span, held.vertical_span])
			check(middle.glow > early.glow + 0.10 and final.glow > middle.glow + 0.15,
				"The actual %s buildup light at %s strengthens across the same motion windows (%.2f, %.2f, %.2f)" %
				[theme_id, dimensions, early.glow, middle.glow, final.glow])
			app.chest.finish_immediately()
	print("Real gameplay body motion across 32 theme/viewport cases: first %.2f-%.2f screen px (minimum: %s); late %.2f-%.2f screen px (minimum: %s)" %
		[first_range.x, first_range.y, first_min_case, late_range.x, late_range.y, late_min_case])
	print("Gameplay shake before the held breath: early %.2f-%.2f, middle %.2f-%.2f, late %.2f-%.2f screen px; longest final-roll quiet interval %.0f ms" %
		[envelope_min.x, envelope_max.x, envelope_min.y, envelope_max.y, envelope_min.z, envelope_max.z, longest_quiet * 1000.0])
	app.audio.halt()
	app.free()
	await process_frame

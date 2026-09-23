extends SceneTree

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
	check(app.new_round(seed_value), "The next real Match round starts")
	app.choose_theme("spring")
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app.cards[card.id].pressed.emit()
			app.cards[card.word.id + ":image"].pressed.emit()
			app._continue_match()
	check(app.model.phase == "won" and app.model.chest_state == "closed",
		"Three real word-picture matches earn a closed chest")


func _begin(app) -> void:
	app.chest_button.button_down.emit()
	# Advance the actual hold controller deterministically, without adding live
	# frame time to simulated input while these scene assertions are running.
	app.set_process(false)


func _check_cancelled(app, pieces: int, reason: String) -> void:
	check(not app._holding_chest and is_zero_approx(app._hold_elapsed)
		and not app.chest.hold_effect_snapshot().active,
		reason + " clears the hold and visible progress immediately")
	check(not app.audio._chest_charge_active and not app.audio.chest_charge.playing
		and app.audio.chest_charge.stream == null,
		reason + " stops and releases the charge sound")
	check(app.model.chest_state == "closed" and _pieces(app) == pieces,
		reason + " leaves the earned chest closed without awarding a piece")
	app._process(2.0)
	check(app.model.chest_state == "closed" and _pieces(app) == pieces,
		reason + " cannot complete later from an old frame")


func _run() -> void:
	var directory := "user://chest-charge-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The scene uses isolated reward storage")
	var progress_script = load("res://scripts/medal_progress.gd")
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	app._mode_id = "match"
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_reduced_motion(false)
	app.audio.set_muted(false)
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
	app._process(0.36)
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
	app._process(0.6)
	check(app.chest.hold_effect_snapshot().percent == 50 and app.audio.chest_charge.pitch_scale > pitch,
		"The same elapsed time advances the visible percentage and rising audio pitch")
	app._process(0.61)
	state = app.chest.hold_effect_snapshot()
	check(app.model.chest_state == "opening" and state.phase == "opening" and state.percent == 100,
		"Completing the real hold starts the existing opening at full charge")
	check(not app.audio._chest_charge_active and app.audio.chest_charge.playing
		and app.audio.chest_charge.stream == app.audio._chest_charge_accent,
		"Full charge replaces the loop with one finite release accent")
	check(_pieces(app) == 0, "The piece still waits for the actual chest-opened callback")
	app.chest_button.button_up.emit()
	app.chest.finish_immediately()
	check(app.model.chest_state == "opened" and _pieces(app) == 1,
		"Finishing the actual opening claims exactly one piece")
	app._on_chest_opened()
	app.chest.finish_immediately()
	_begin(app)
	app._process(2.0)
	check(_pieces(app) == 1 and not app.chest.hold_effect_snapshot().active,
		"Repeated opening callbacks and a hold on the opened chest cannot duplicate the reward")
	var saved = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	check(saved.load_progress() and saved.count_for("spring-1") == 1,
		"The single earned piece survives reloading the real save")

	_win(app, 82)
	_begin(app)
	app._process(0.4)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = Vector2(24, 0)
	motion.position = Vector2(74, 50)
	app._chest_input(motion)
	_check_cancelled(app, 1, "Dragging the chest beyond the movement threshold")
	app.chest_button.button_up.emit()
	_begin(app)
	app._process(0.4)
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(0, 24)
	drag.position = Vector2(50, 74)
	app._chest_input(drag)
	_check_cancelled(app, 1, "Dragging the chest with a touch")
	app.chest_button.button_up.emit()
	_begin(app)
	app._process(0.4)
	app._toggle_collection()
	_check_cancelled(app, 1, "Opening More during a hold")
	_begin(app)
	check(app.collection_page.visible and not app._holding_chest and not app.audio._chest_charge_active,
		"A late start while More is open cannot restart charge feedback")
	app._hide_collection()
	_begin(app)
	app._process(0.4)
	app.on_page_hidden()
	_check_cancelled(app, 1, "Backgrounding the game during a hold")
	_begin(app)
	check(not app._holding_chest and not app.audio._chest_charge_active,
		"A late start while the page is hidden cannot restart charging")
	app.on_page_visible()
	_begin(app)
	check(app._holding_chest, "Returning to the foreground permits a fresh hold")
	app._process(0.4)
	check(app.new_round(83), "A new round can leave an earned chest during a hold")
	check(_pieces(app) == 2 and app.model.chest_state == "closed" and app.model.phase == "waiting"
		and not app._holding_chest and not app.chest.hold_effect_snapshot().active
		and not app.audio._chest_charge_active and not app.audio.chest_charge.playing,
		"A new round preserves the existing one-piece auto-claim and clears all old charge feedback")
	app._process(2.0)
	app._on_chest_opened()
	check(_pieces(app) == 2, "Late hold frames and open callbacks cannot award the new round a piece")

	_win(app, 84)
	app.chest_button.grab_focus()
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	app._input(accept)
	app.set_process(false)
	app._process(0.4)
	check(app._controller_holding_chest and app.chest.hold_effect_snapshot().active,
		"Controller A drives the same real chest charge")
	accept.pressed = false
	app._input(accept)
	_check_cancelled(app, 2, "Releasing controller A")
	accept.pressed = true
	app._input(accept)
	app.set_process(false)
	app._process(0.4)
	app._on_joy_connection_changed(0, false)
	_check_cancelled(app, 2, "Disconnecting the controller")
	check(not app._controller_holding_chest, "A controller disconnect clears its held-action latch")
	_begin(app)
	app._process(0.4)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_input(escape)
	_check_cancelled(app, 2, "Pressing Escape during a hold")
	app.chest_button.grab_focus()
	accept.pressed = true
	app._input(accept)
	app.set_process(false)
	app._process(0.4)
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	app._input(back)
	_check_cancelled(app, 2, "Pressing controller B during a hold")
	check(not app._controller_holding_chest, "Controller Back also clears the held-action latch")

	app.set_reduced_motion(true)
	_begin(app)
	app._process(0.6)
	state = app.chest.hold_effect_snapshot()
	check(state.active and state.percent == 50 and state.text.contains("50%")
		and not state.animated and state.spark_count == 0 and _pieces(app) == 2,
		"Reduced motion keeps real readable hold progress without particles or an early reward")
	app.chest_button.button_up.emit()
	_check_cancelled(app, 2, "Releasing a reduced-motion hold")
	_begin(app)
	app._process(1.21)
	check(app.model.chest_state == "opened" and _pieces(app) == 3
		and not app.chest.hold_effect_snapshot().active and app.effects.particle_count() == 0,
		"A full reduced-motion hold completes once without the opening motion")
	app._on_chest_opened()
	check(_pieces(app) == 3, "Reduced-motion completion also ignores duplicate callbacks")
	app.audio.halt()
	app.set_process(false)
	await process_frame
	app.free()
	await process_frame
	print("Chest charge flow: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

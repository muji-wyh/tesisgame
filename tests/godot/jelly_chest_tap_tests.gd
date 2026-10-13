extends SceneTree

const Tap = preload("res://scripts/jelly_chest_tap.gd")
const Jelly = preload("res://scripts/jelly_match.gd")
const WordJellyView = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
const CHEST = preload("res://assets/chests/energy/closed.png")

var checks: int = 0
var failures: int = 0
var data = Data.new()
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 720)
	_check_component()
	check(data.load_all(), "Chest taps use the production vocabulary and acquired chest artwork")
	words = data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) <= 3 and not str(word.get("image", "")).is_empty()).slice(0, 12)
	for scene in [Jelly, WordJellyView]:
		var view = scene.new()
		root.add_child(view)
		view.set_process(false)
		view.size = Vector2(1000, 720)
		_check_owner_presentation(view)
		_check_input_gates(view)
		_check_lifecycle(view)
		_check_layout_and_navigation(view)
		if view is WordJellyView:
			_check_collection_gate(view)
		view.free()
	await process_frame
	print("Jelly chest tap: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_component() -> void:
	var tap = Tap.new()
	root.add_child(tap)
	tap.position = Vector2(48, 80)
	tap.size = Vector2(64, 64)
	var resting: Rect2 = tap.get_rect()
	check(not tap.is_active(), "The decorative chest response begins idle")
	tap.play(CHEST, 1.0, false)
	var peak_scale: float = 1.0
	var peak_rotation: float = 0.0
	var peak_light: float = 0.0
	for index in range(24):
		tap.advance(0.05)
		var state: Dictionary = tap.snapshot()
		peak_scale = maxf(peak_scale, float(state.scale))
		peak_rotation = maxf(peak_rotation, absf(float(state.rotation)))
		peak_light = maxf(peak_light, float(state.light))
		check(tap.get_rect().is_equal_approx(resting),
			"Chest artwork motion retains its original center and hit target")
	check(peak_scale > 1.15 and peak_rotation > 0.05 and peak_light > 0.1,
		"An ordinary tap visibly enlarges, turns and illuminates the sourced chest")
	check(not tap.is_active(), "The chest response finishes within a short finite timeline")
	var idle: Dictionary = tap.snapshot()
	check(is_equal_approx(float(idle.scale), 1.0) and is_zero_approx(float(idle.rotation))
		and is_zero_approx(float(idle.light)), "Completion restores the idle pose without residual light")
	tap.play(CHEST, 0.72, true)
	peak_light = 0.0
	for index in range(12):
		tap.advance(0.05)
		var state: Dictionary = tap.snapshot()
		peak_light = maxf(peak_light, float(state.light))
		check(is_equal_approx(float(state.scale), 1.0) and is_zero_approx(float(state.rotation))
			and tap.get_rect().is_equal_approx(resting),
			"Reduced motion acknowledges a tap without scaling, spinning or moving")
	check(peak_light > 0.1 and not tap.is_active(), "Reduced motion retains a brief local light acknowledgment")
	tap.play(CHEST, 1.0, false)
	tap.advance(0.2)
	tap.clear()
	tap.advance(0.2)
	check(not tap.is_active() and is_zero_approx(float(tap.snapshot().light)),
		"Clearing a response removes it immediately and cannot replay it on the next frame")
	tap.free()


func _reset(view, reduced: bool = false) -> void:
	view.show()
	view.interaction_allowed = Callable()
	check(view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42),
		"%s configures a production round for chest feedback" % view.name)
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view._layout()


func _check_owner_presentation(view) -> void:
	_reset(view)
	var events: Array[String] = []
	var on_cue: Callable = func(cue: String) -> void: events.append(cue)
	view.audio_requested.connect(on_cue)
	var model: Dictionary = view.game.snapshot().duplicate(true)
	var anchor: Rect2 = view._loot_icon.get_rect()
	view._chest_tap.pressed.emit()
	check(view._chest_tap.is_active() and bool(view.snapshot().loot.tap.active),
		"%s routes the chest button to its published local response" % view.name)
	check(view.game.snapshot() == model and events.is_empty() and not view._reward_presentation.is_active(),
		"Tapping a chest cannot grant fragments, coins, progress, words, or a reward celebration")
	view._chest_tap.advance(0.2)
	var before_repeat: Dictionary = view._chest_tap.snapshot().duplicate(true)
	view._chest_tap.pressed.emit()
	check(view._chest_tap.snapshot() == before_repeat,
		"Repeated taps cannot restart the response or accumulate overlapping effects")
	view._refresh_hud()
	check(not view._loot_icon.visible and view._loot_icon.get_rect().is_equal_approx(anchor),
		"HUD refresh keeps only one animated chest while preserving the reward flight anchor")
	view._process(0.1)
	check(float(view._chest_tap.snapshot().elapsed) > float(before_repeat.elapsed),
		"The owner advances the response alongside normal gameplay")
	for index in range(12):
		view._process(0.1)
	check(not view._chest_tap.is_active() and view._loot_icon.visible
		and view._loot_icon.get_rect().is_equal_approx(anchor),
		"The ordinary chest returns to the same position after feedback finishes")
	check(view.game.fragment_count == int(model.fragment_count) and view.game.chest_tier == int(model.chest_tier),
		"Completing decorative feedback preserves all earned chest ownership")
	view.audio_requested.disconnect(on_cue)


func _check_input_gates(view) -> void:
	for gate: String in ["pointer", "pause", "hidden", "host", "result", "reward"]:
		_reset(view)
		match gate:
			"pointer":
				view._pointer = view.MOUSE_POINTER
			"pause":
				view.pause(true)
			"hidden":
				view.hide()
			"host":
				view.interaction_allowed = func() -> bool: return false
			"result":
				view.game.finish_round()
				view.result_reveal()
			"reward":
				view._chest_milestone(0, 1)
		var model: Dictionary = view.game.snapshot().duplicate(true)
		check(not view._can_tap_chest(), "%s blocks chest taps behind the %s gate" % [view.name, gate])
		view._chest_tap.pressed.emit()
		check(not view._chest_tap.is_active() and view.game.snapshot() == model,
			"A stale pressed signal behind %s cannot bypass the owner's input or reward guards" % gate)
	_reset(view)
	view.stop()
	view._chest_tap.pressed.emit()
	check(not view._chest_tap.is_active(), "Stopped games cannot respond to a delayed chest press")


func _check_lifecycle(view) -> void:
	for action: String in ["cancel", "pause", "hidden", "focus", "settle", "stop", "finish", "milestone", "reduced"]:
		_reset(view)
		view._tap_chest()
		view._chest_tap.advance(0.2)
		check(view._chest_tap.is_active(), "The %s interruption starts with active feedback" % action)
		match action:
			"cancel":
				view.cancel_input()
			"pause":
				view.pause(true)
			"hidden":
				view.hide()
			"focus":
				view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"settle":
				view.settle()
			"stop":
				view.stop()
			"finish":
				view.game.finish_round()
			"milestone":
				view._chest_milestone(0, 1)
			"reduced":
				view.set_reduced_motion(true)
		check(not view._chest_tap.is_active(), "%s immediately clears feedback on %s" % [view.name, action])
		if action == "pause":
			view.pause(false)
		elif action == "hidden":
			view.show()
		view._process(0.1)
		check(not view._chest_tap.is_active(), "Returning after %s cannot replay an old tap" % action)
	_reset(view, true)
	view._tap_chest()
	view._process(0.15)
	var reduced: Dictionary = view.snapshot().loot.tap
	check(bool(reduced.active) and is_equal_approx(float(reduced.scale), 1.0)
		and is_zero_approx(float(reduced.rotation)) and float(reduced.light) > 0.0,
		"The owner passes reduced motion through to its light-only chest response")


func _check_layout_and_navigation(view) -> void:
	for dimensions: Vector2 in [Vector2(1000, 720), Vector2(390, 700)]:
		view.size = dimensions
		_reset(view)
		var hit_rect: Rect2 = view._chest_tap.get_rect()
		check(hit_rect.is_equal_approx(view._loot_meter.get_rect()) and hit_rect.has_area()
			and Rect2(Vector2.ZERO, view.size).encloses(hit_rect),
			"%s keeps the whole meter as a usable chest target at %s" % [view.name, dimensions])
		check(not hit_rect.intersects(view._board) and not hit_rect.intersects(view._preview_rect)
			and not hit_rect.intersects(view.finish_button.get_rect()),
			"The chest target stays separate from jellies, upcoming supply and Finish")
		check(view.navigation_controls().has(view._chest_tap)
			and view._chest_tap.focus_mode == Control.FOCUS_ALL and view._chest_tap.tooltip_text.is_empty(),
			"The chest responds to keyboard navigation without adding a tooltip")
		view.pause(true)
		check(not view.navigation_controls().has(view._chest_tap),
			"Paused keyboard navigation cannot activate the gameplay chest")
	view.size = Vector2(1000, 720)


func _check_collection_gate(view) -> void:
	_reset(view)
	view.game.cells.clear()
	var tile: Dictionary = view.game._new_tile(str(words[0].text), 2, 0)
	tile.column = 0
	tile.row = view.game.ROWS - int(tile.height)
	view.game.cells.append(tile)
	view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": true}
	view._sync_tiles()
	view._layout()
	check(view.game.start_collection_batch(), "A real valid merged word starts the collection input guard")
	check(view.game.collection_batch_active() and not view._can_tap_chest(),
		"Word Jelly gives the collection rhythm priority over decorative chest taps")
	var batch: Dictionary = view.game.collection_batch_snapshot().duplicate(true)
	view._chest_tap.pressed.emit()
	check(not view._chest_tap.is_active() and view.game.collection_batch_snapshot() == batch,
		"A chest tap during Collect cannot interrupt or advance the pending word payout")

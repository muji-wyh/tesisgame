extends SceneTree

const Tap = preload("res://scripts/jelly_chest_tap.gd")
const Jelly = preload("res://scripts/jelly_match.gd")
const WordJellyView = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
const CHEST = preload("res://assets/chests/shared/ui/chest.png")

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
		await _check_hosted_header(scene)
	await process_frame
	print("Jelly chest tap: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_component() -> void:
	var tap = Tap.new()
	root.add_child(tap)
	tap.position = Vector2(48, 80)
	tap.size = Vector2(64, 64)
	var resting: Rect2 = tap.get_rect()
	var resting_layer: int = tap.z_index
	check(not tap.is_active(), "The decorative chest response begins idle")
	tap.play(CHEST, 1.0, false)
	check(tap.z_index > resting_layer, "An active chest and its attached label rise above the static HUD")
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
	check(peak_scale > 3.10 and peak_rotation > 0.05 and peak_light > 0.1,
		"An ordinary tap triples the former scale amplitude while retaining its turn and light")
	check(not tap.is_active(), "The chest response finishes within a short finite timeline")
	check(tap.z_index == resting_layer, "Completion restores the ordinary chest drawing layer")
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
	check(tap.z_index == resting_layer, "Canceling chest feedback also restores its drawing layer")
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
		"%s returns the ordinary chest after feedback: active=%s visible=%s rect=%s anchor=%s" % [
			view.name, view._chest_tap.is_active(), view._loot_icon.visible, view._loot_icon.get_rect(), anchor])
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
	view.set_pip_level(3)
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


func _header_anchors(view) -> Dictionary:
	return {"hit": view._chest_tap.get_global_rect(), "icon": view._loot_icon.get_global_rect(),
		"flight": view.chest_anchor_rect(), "meter": view.chest_meter_rect(),
		"reward": view._reward_presentation._anchor}


func _header_artwork_points(view) -> Array[Vector2]:
	var tap: Tap = view._chest_tap
	var label: Label = view._header_chest_level
	var artwork: Vector2 = view._loot_icon.texture.get_size()
	artwork *= minf(tap.size.x, tap.size.y) * 0.67 / maxf(artwork.x, artwork.y)
	var offset: Vector2 = view._header_chest_host.size - label.size - tap.position - tap.size * 0.5
	return [-artwork * 0.5, Vector2(artwork.x, -artwork.y) * 0.5, artwork * 0.5,
		Vector2(-artwork.x, artwork.y) * 0.5, offset, offset + Vector2(label.size.x, 0.0),
		offset + label.size, offset + Vector2(0.0, label.size.y)]


func _expected_artwork_pose(view) -> Transform2D:
	var tap: Tap = view._chest_tap
	var state: Dictionary = tap.snapshot()
	var center: Vector2 = tap.size * 0.5
	var turn: float = float(state.rotation)
	var zoom: float = float(state.scale)
	if bool(state.active) and not view.reduced_motion:
		# Fit the independent transformed corners of both acquired artwork and badge.
		# The shared translation must keep the whole visible pair within the viewport.
		var canvas: Transform2D = tap.get_global_transform_with_canvas()
		var pose := Transform2D(turn, Vector2.ONE * zoom, 0.0, center)
		var points: Array[Vector2] = _header_artwork_points(view)
		var bounds := Rect2(canvas * pose * points[0], Vector2.ZERO)
		for point: Vector2 in points:
			bounds = bounds.expand(canvas * pose * point)
		var viewport: Vector2 = tap.get_viewport_rect().size
		var shift := Vector2.ZERO
		if bounds.position.x < 4.0:
			shift.x = 4.0 - bounds.position.x
		elif bounds.end.x > viewport.x - 4.0:
			shift.x = viewport.x - 4.0 - bounds.end.x
		if bounds.position.y < 4.0:
			shift.y = 4.0 - bounds.position.y
		elif bounds.end.y > viewport.y - 4.0:
			shift.y = viewport.y - 4.0 - bounds.end.y
		center = canvas.affine_inverse() * (canvas * center + shift)
	return Transform2D(turn, Vector2.ONE * zoom, 0.0, center)


func _check_header_pose(view, anchors: Dictionary, context: String) -> void:
	var tap: Tap = view._chest_tap
	var host: Node2D = tap.artwork_host()
	var label: Label = view._header_chest_level
	var expected: Transform2D = _expected_artwork_pose(view)
	var offset: Vector2 = view._header_chest_host.size - label.size - tap.position - tap.size * 0.5
	check(host.get_parent() == tap and label.get_parent() == host,
		context + " keeps the level attached to the chest artwork anchor")
	check(host.transform.is_equal_approx(expected),
		context + " retains the chest's fitted center, turn and amplified scale")
	check(label.position.is_equal_approx(offset),
		context + " preserves the badge's resting bottom-right offset within the shared pose")
	var canvas: Transform2D = tap.get_global_transform_with_canvas() * expected
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(label.size.x, 0.0), label.size,
		Vector2(0.0, label.size.y)]
	for corner: Vector2 in corners:
		check((label.get_global_transform_with_canvas() * corner).is_equal_approx(canvas * (offset + corner)),
			context + " moves every badge corner with the chest's complete affine transform")
	var current: Dictionary = _header_anchors(view)
	for key: String in anchors:
		var rectangle: Rect2 = current[key]
		check(rectangle.is_equal_approx(anchors[key]),
			context + " preserves the independent " + key + " target")
	if tap.is_active() and not view.reduced_motion:
		var viewport: Vector2 = tap.get_viewport_rect().size
		for point: Vector2 in _header_artwork_points(view):
			var fitted: Vector2 = host.get_global_transform_with_canvas() * point
			check(fitted.x >= 3.99 and fitted.y >= 3.99
				and fitted.x <= viewport.x - 3.99 and fitted.y <= viewport.y - 3.99,
				context + " keeps the complete chest and level inside the viewport")


func _check_hosted_header(scene) -> void:
	var frame := Control.new()
	root.add_child(frame)
	frame.position = Vector2(12, 6)
	frame.size = Vector2(root.size)
	var header := Control.new()
	frame.add_child(header)
	header.size = Vector2(80, 64)
	header.position = Vector2(908, 2)
	var view = scene.new()
	frame.add_child(view)
	view.set_process(false)
	view.size = Vector2(1000, 720)
	view.host_header_chest(header)
	view._header_chest_host.size = header.size
	_reset(view)
	var tap: Tap = view._chest_tap
	var label: Label = view._header_chest_level
	check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.focus_mode == Control.FOCUS_NONE,
		"The hosted level leaves pointer and keyboard ownership on the chest button")
	check(not tap.is_processing() and tap.artwork_host().is_visible_in_tree() and label.is_visible_in_tree(),
		"The hosted level remains visible at rest without an idle polling process")
	for tier: int in [0, 99]:
		view._displayed_chest_tier = tier
		view._refresh_hud()
		var anchors: Dictionary = _header_anchors(view)
		var resting: Transform2D = label.get_global_transform_with_canvas()
		var context: String = "%s hosted Lv%d" % [view.name, tier]
		_check_header_pose(view, anchors, context + " at rest")
		view._tap_chest()
		var elapsed: float = 0.0
		for sample: float in [0.0, 0.14, 0.34, 0.50, 0.66, 0.92]:
			tap.advance(sample - elapsed)
			elapsed = sample
			_check_header_pose(view, anchors, context + " at %.2f seconds" % sample)
			if is_equal_approx(sample, 0.34):
				check(not tap.artwork_host().position.is_equal_approx(tap.size * 0.5)
					and not label.get_global_transform_with_canvas().is_equal_approx(resting),
					context + " shares the nonzero edge-fit translation and peak motion")
		tap.advance(Tap.DURATION)
		view._sync_chest_tap()
		check(not tap.is_active() and view._loot_icon.visible and label.is_visible_in_tree()
			and label.get_global_transform_with_canvas().is_equal_approx(resting) and label.text == "Lv%d" % tier,
			context + " restores the original visible badge after the animation endpoint")

	view._tap_chest()
	tap.advance(0.34)
	header.size = Vector2(96, 72)
	view._header_chest_host.size = header.size
	view.layout_header_chest()
	var elapsed_before_resize: float = float(tap.snapshot().elapsed)
	_check_header_pose(view, _header_anchors(view), "An in-flight header resize")
	frame.scale = Vector2.ONE * 1.35
	header.position = Vector2((float(root.size.x) - frame.position.x - 8.0) / frame.scale.x - header.size.x,
		(8.0 - frame.position.y) / frame.scale.y)
	await process_frame
	_check_header_pose(view, _header_anchors(view), "A uniformly scaled and moved header ancestor")
	check(is_equal_approx(float(tap.snapshot().elapsed), elapsed_before_resize),
		"Header geometry changes update the badge pose without advancing its animation clock")
	for action: String in ["clear", "pause", "reduced"]:
		tap.clear()
		view._sync_chest_tap()
		view._tap_chest()
		tap.advance(0.34)
		var anchors: Dictionary = _header_anchors(view)
		match action:
			"clear":
				tap.clear()
				view._sync_chest_tap()
			"pause":
				view.pause(true)
				view.pause(false)
			"reduced":
				view.set_reduced_motion(true)
		check(not tap.is_active() and label.is_visible_in_tree(),
			"The hosted badge immediately returns after " + action)
		_check_header_pose(view, anchors, "Hosted restoration after " + action)
	view._tap_chest()
	tap.advance(0.15)
	var reduced: Dictionary = tap.snapshot()
	check(bool(reduced.active) and is_equal_approx(float(reduced.scale), 1.0)
		and is_zero_approx(float(reduced.rotation)) and float(reduced.light) > 0.0,
		"The hosted badge retains reduced-motion light feedback without scale or rotation")
	_check_header_pose(view, _header_anchors(view), "Hosted reduced-motion acknowledgment")
	tap.advance(Tap.REDUCED_DURATION)
	view._sync_chest_tap()
	_check_header_pose(view, _header_anchors(view), "The reduced-motion endpoint")
	view.free()
	frame.free()

extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Room = preload("res://scripts/pop_reward_room.gd")
const Feel = preload("res://scripts/chest_feel.gd")

class Storage extends RefCounted:
	var text: Variant = null
	var writes := 0

	func popRewardState() -> Variant:
		return text

	func savePopRewardState(value: String) -> bool:
		text = value
		writes += 1
		return true


var checks := 0
var failures := 0


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


func pointer(point: Vector2, down: bool, kind: String, canceled: bool = false, index: int = 0) -> void:
	var event: InputEvent
	if kind == "touch":
		event = InputEventScreenTouch.new()
		event.index = index
	else:
		event = InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION if kind == "emulated" else 0
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = point
	event.pressed = down
	event.canceled = canceled
	root.push_input(event, true)
	await process_frame


func motion(point: Vector2, kind: String, index: int = 0) -> void:
	var event: InputEvent
	if kind == "touch":
		event = InputEventScreenDrag.new()
		event.index = index
	else:
		event = InputEventMouseMotion.new()
		event.device = InputEvent.DEVICE_ID_EMULATION if kind == "emulated" else 0
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	# Absolute positions own the gesture even when an emulated relative delta differs.
	event.relative = Vector2(0, -300)
	root.push_input(event, true)
	await process_frame


func _reset(room) -> void:
	room.cancel_input()
	room._scroll.cancel_drag()
	room._scroll.scroll_vertical = 0
	await settle()


func _visible_point(room, index: int) -> Vector2:
	return room._cards[index].button.get_global_rect().intersection(room._scroll.get_global_rect()).get_center()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	var data := Data.new()
	check(data.load_all(), "Load sourced reward artwork for pointer interaction checks")
	var storage := Storage.new()
	var room := Room.new()
	root.add_child(room)
	room.size = Vector2(390, 780)
	room.connect_storage(storage)
	check(room.configure("large-scrollable-chests", 3, "ocean", data.chests, false),
		"Prepare three real chests in the large scrollable reward room")
	room.set_process(false)
	await settle()
	check(room.snapshot().scroll_max > 0 and not room._scroll.get_v_scroll_bar().visible,
		"The phone reward stage scrolls while its scrollbar stays hidden")
	await _check_stationary_contacts(room, storage)
	await _check_drag_and_momentum(room, storage)
	await _check_cancellations(room, storage)
	await _check_focus_and_snapshot(room)
	await _check_retained_reward(room, storage)
	room.queue_free()
	await process_frame
	print("Pop treasure scrolling: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_stationary_contacts(room, storage: Storage) -> void:
	for kind in ["mouse", "touch", "emulated"]:
		await _reset(room)
		var point := _visible_point(room, 0)
		await motion(point, kind)
		await pointer(point, true, kind)
		room.advance_hold(0.35)
		check(room.snapshot().active == 0 and room.snapshot().holding
			and room._cards[0].art.hold_progress > 0,
			"A stationary %s contact charges the chest immediately" % kind)
		await pointer(point, false, kind)
		check(not room.snapshot().holding and room.snapshot().active == -1
			and not room._cards[0].opened and storage.writes == 1,
			"A short %s contact cancels without spending its reward" % kind)
	for first in ["touch", "emulated"]:
		await _reset(room)
		var second: String = "emulated" if first == "touch" else "touch"
		var point := _visible_point(room, 0)
		await pointer(point, true, first)
		room.advance_hold(0.35)
		var progress: float = room._cards[0].art.hold_progress
		await pointer(point, true, second)
		check(room.snapshot().holding and is_equal_approx(room._cards[0].art.hold_progress, progress),
			"Duplicate native and emulated presses do not restart the hold, first=%s" % first)
		await pointer(point, false, first)
		await pointer(point, false, second)
		check(not room.snapshot().holding and not room._scroll.is_pointer_active() and storage.writes == 1,
			"Paired native and emulated releases finish one unspent contact, first=%s" % first)


func _check_drag_and_momentum(room, storage: Storage) -> void:
	for kind in ["mouse", "touch", "emulated"]:
		await _reset(room)
		var point := _visible_point(room, 0)
		await pointer(point, true, kind)
		room.advance_hold(0.35)
		for distance in [20.0, 40.0, 60.0]:
			await motion(point - Vector2(0, distance), kind)
		check(not room.snapshot().holding and room.snapshot().active == -1
			and room._scroll.scroll_vertical >= 55,
			"Dragging with %s scrolls the large stage and cancels chest charging" % kind)
		await pointer(point - Vector2(0, 60), false, kind)
		room._scroll.set_process(false)
		var released: int = room._scroll.scroll_vertical
		check(room._scroll.is_coasting(), "A %s swipe releases with inertia" % kind)
		room._scroll._process(0.04)
		room._scroll.set_process(false)
		check(room._scroll.scroll_vertical > released and storage.writes == 1,
			"The reward stage continues moving after %s release without awarding a chest" % kind)
		var braking_point := _visible_point(room, 0)
		await pointer(braking_point, true, kind)
		room.advance_hold(Feel.HOLD_SECONDS + 1.0)
		check(not room.snapshot().holding and not room._scroll.is_coasting()
			and room.snapshot().opened_count == 0,
			"Touching a coasting stage brakes it without beginning a %s chest hold" % kind)
		await pointer(braking_point, false, kind)
	await _reset(room)
	var point := _visible_point(room, 0)
	await pointer(point, true, "touch")
	room.advance_hold(0.35)
	await motion(point + Vector2(30, 2), "touch")
	room.advance_hold(Feel.HOLD_SECONDS + 1.0)
	check(not room.snapshot().holding and room.snapshot().opened_count == 0 and storage.writes == 1,
		"A horizontal swipe cancels charging even when it does not begin vertical scrolling")
	await pointer(point + Vector2(30, 2), false, "touch")


func _check_cancellations(room, storage: Storage) -> void:
	for cause in ["cancel", "second-finger", "wheel", "pause", "hide", "resize", "background", "blocked"]:
		await _reset(room)
		var point := _visible_point(room, 0)
		await pointer(point, true, "touch")
		room.advance_hold(0.35)
		match cause:
			"cancel":
				await pointer(point, false, "touch", true)
			"second-finger":
				await pointer(point + Vector2(30, 0), true, "touch", false, 1)
				await pointer(point + Vector2(30, 0), false, "touch", false, 1)
			"wheel":
				var wheel := InputEventMouseButton.new()
				wheel.position = point
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				root.push_input(wheel, true)
			"pause":
				room.pause()
				room.resume()
			"hide":
				room.hide()
				room.show()
				room.resume()
			"resize":
				room._scroll.resized.emit()
			"background":
				room._scroll.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"blocked":
				room.interaction_allowed = func() -> bool: return false
				await motion(point, "touch")
				room.interaction_allowed = Callable()
		room.advance_hold(Feel.HOLD_SECONDS + 1.0)
		await pointer(point, false, "touch")
		check(not room.snapshot().holding and room.snapshot().active == -1
			and room.snapshot().opened_count == 0 and storage.writes == 1,
			"Canceling by %s leaves the held chest available without awarding it" % cause)
	await _reset(room)
	var wheel := InputEventMouseButton.new()
	wheel.position = _visible_point(room, 0)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	check(room._scroll.is_coasting(), "A wheel notch starts eased scrolling")
	room.pause()
	var paused_offset: int = room._scroll.scroll_vertical
	room._scroll._process(0.2)
	check(not room._scroll.is_scrolling() and room._scroll.scroll_vertical == paused_offset,
		"Pausing the reward room stops its inertial motion")
	room.resume()
	await _reset(room)
	wheel.position = _visible_point(room, 0)
	root.push_input(wheel, true)
	check(room._scroll.is_coasting(), "Input cancellation fixture begins with wheel momentum")
	room.cancel_input()
	var canceled_offset: int = room._scroll.scroll_vertical
	room._scroll._process(0.2)
	check(not room._scroll.is_scrolling() and room._scroll.scroll_vertical == canceled_offset,
		"Global reward input cancellation stops inertia as well as an active chest hold")


func _check_focus_and_snapshot(room) -> void:
	await _reset(room)
	var last: Button = room._cards[2].button
	last.grab_focus()
	room._ensure_chest_visible(last)
	await settle()
	var viewport: Rect2 = room._scroll.get_global_rect()
	check(room._scroll.scroll_vertical > 0 and viewport.grow(1.0).encloses(last.get_global_rect()),
		"Keyboard and controller focus can reveal the last large chest on a phone: viewport %s, chest %s, offset %s" %
		[viewport, last.get_global_rect(), room._scroll.scroll_vertical])
	var published: Array[Dictionary] = []
	room.changed.connect(func(value: Dictionary) -> void: published.append(value.duplicate(true)))
	room._scroll.scroll_vertical = 0
	await settle()
	check(not published.is_empty(), "Scrolling publishes fresh reward geometry to the browser host")
	if not published.is_empty():
		var value: Dictionary = published.back()
		var recorded: Dictionary = value.chests[2].rect
		check(value.scroll_offset == room._scroll.scroll_vertical
			and last.get_global_rect().is_equal_approx(Rect2(recorded.x, recorded.y, recorded.width, recorded.height)),
			"Published chest bounds track scroll movement instead of keeping stale hit targets")
	await _reset(room)
	var point := _visible_point(room, 0)
	await pointer(point, true, "touch")
	room._ensure_chest_visible(last)
	check(room._scroll.scroll_vertical == 0 and room.snapshot().holding,
		"Focus reveal cannot move the stage underneath an active chest contact")
	await pointer(point, false, "touch")


func _check_retained_reward(room, storage: Storage) -> void:
	await _reset(room)
	var point := _visible_point(room, 0)
	await pointer(point, true, "mouse")
	room.advance_hold(Feel.HOLD_SECONDS)
	room._cards[0].art.set_process(false)
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	await pointer(point, false, "mouse")
	room._cards[0].art._advance_animation(60.0)
	var gift: Dictionary = room._cards[0].art.hold_effect_snapshot().surprise
	check(room.snapshot().opened_count == 1 and storage.writes == 2 and gift.active,
		"A stationary full hold still opens and saves one chest with its persistent gift")
	room._scroll.scroll_vertical = roundi(room.snapshot().scroll_max)
	await settle()
	room._scroll.scroll_vertical = 0
	await settle()
	var retained: Dictionary = room._cards[0].art.hold_effect_snapshot().surprise
	check(retained.active and retained.kind == gift.kind and retained.play_count == gift.play_count
		and storage.writes == 2,
		"Scrolling an opened chest out of view and back preserves its gift without replay or duplicate save")

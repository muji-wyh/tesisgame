extends SceneTree

const ResultScroll = preload("res://scripts/result_scroll.gd")

class InputProbe extends Node:
	var outside_press_seen := false

	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed and event.position == Vector2(600, 760):
			outside_press_seen = true


var checks := 0
var failures := 0
var _activations := 0
var _focus_events := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func pointer(point: Vector2, down: bool, touch: bool, canceled: bool = false, index: int = 0) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = index
	else:
		event = InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = point
	event.pressed = down
	event.canceled = canceled
	root.push_input(event, true)
	await process_frame


func motion(point: Vector2, touch: bool) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenDrag.new()
		event.index = 0
	else:
		event = InputEventMouseMotion.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	# Deliberately different from the pointer displacement, as can happen when
	# physical-screen deltas and stretched canvas coordinates are mixed.
	event.relative = Vector2(0, -300)
	root.push_input(event, true)
	await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640, 800)
	# Input visits nodes in reverse tree order. This observer is reached only
	# if ResultScroll leaves the outside press available to the rest of the UI.
	var probe := InputProbe.new()
	root.add_child(probe)
	var scroll := ResultScroll.new()
	scroll.position = Vector2(20, 20)
	scroll.size = Vector2(350, 350)
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	for index in range(18):
		var button := Button.new()
		button.text = "Word %d" % index
		button.custom_minimum_size = Vector2(0, 70)
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(func() -> void: _activations += 1)
		button.focus_entered.connect(func() -> void: _focus_events += 1)
		body.add_child(button)
	await settle()
	for factor in [0.75, 1.0, 1.5]:
		scroll.scale = Vector2.ONE * factor
		await settle()
		for touch_first in [false, true]:
			scroll.scroll_vertical = 120
			await settle()
			var point: Vector2 = scroll.get_global_transform_with_canvas() * Vector2(160, 240)
			var before := scroll.scroll_vertical
			var activation_before := _activations
			var focus_before := _focus_events
			await pointer(point, true, touch_first)
			await pointer(point, true, not touch_first)
			check(_focus_events == focus_before and scroll.scroll_vertical == before,
				"A touch press does not focus-reveal a card before its gesture is known")
			for distance in [20.0, 40.0, 60.0, 50.0]:
				var moved := point - Vector2(0, distance * factor)
				await motion(moved, touch_first)
				await motion(moved, not touch_first)
				check(absi(scroll.scroll_vertical - before - roundi(distance)) <= 1,
					"Drag follows absolute finger movement once at scale %.2f, touch first=%s, distance=%.0f, scroll=%d" % [
						factor, touch_first, distance, scroll.scroll_vertical - before])
			var end := point - Vector2(0, 50 * factor)
			await pointer(end, false, touch_first)
			await pointer(end, false, not touch_first)
			await settle()
			check(not scroll.is_pointer_active(), "Touch release ends contact while momentum may continue")
			check(_activations == activation_before, "A drag across a word card never activates it")
			await _check_tap(scroll, body.get_child(0), touch_first)
	scroll.scale = Vector2.ONE
	await settle()
	await _check_cancellations(scroll, body.get_child(0))
	await _check_touch_only_exit(scroll, probe)
	await _check_native_controls(scroll, body.get_child(0))
	scroll.queue_free()
	probe.queue_free()
	await process_frame
	print("Result scrolling: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_tap(scroll: ResultScroll, button: Button, touch_first: bool) -> void:
	scroll.cancel_drag()
	scroll.scroll_vertical = 0
	await settle()
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var before := _activations
	await pointer(point, true, touch_first)
	await pointer(point, true, not touch_first)
	check(not button.self_modulate.is_equal_approx(Color.WHITE),
		"A stationary contact gives the word card immediate visual feedback")
	await pointer(point, false, touch_first)
	await pointer(point, false, not touch_first)
	check(_activations == before + 1 and button.has_focus() and button.self_modulate.is_equal_approx(Color.WHITE),
		"Paired touch and emulated mouse events activate a word once and leave keyboard focus")


func _check_cancellations(scroll: ResultScroll, button: Button) -> void:
	scroll.cancel_drag()
	scroll.scroll_vertical = 0
	await settle()
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	for cause in ["cancel", "hidden", "resize", "background", "blocked", "second-finger"]:
		var before := _activations
		await pointer(point, true, false)
		await pointer(point, true, true)
		match cause:
			"cancel":
				await pointer(point, false, true, true)
			"hidden":
				scroll.hide()
				scroll.show()
			"resize":
				scroll.resized.emit()
			"background":
				scroll.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"blocked":
				scroll.interaction_allowed = func() -> bool: return false
				await motion(point, false)
				scroll.interaction_allowed = Callable()
			"second-finger":
				await pointer(point + Vector2(30, 0), true, true, false, 1)
				await pointer(point + Vector2(30, 0), false, true, false, 1)
		await pointer(point, false, false)
		await pointer(point, false, true)
		check(_activations == before and not scroll.is_pointer_active() and button.self_modulate.is_equal_approx(Color.WHITE),
			"Canceled gesture cannot activate a word after " + cause)
	await _check_tap(scroll, button, false)


func _check_native_controls(scroll: ResultScroll, button: Button) -> void:
	scroll.cancel_drag()
	scroll.scroll_vertical = 0
	await settle()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = scroll.get_global_transform_with_canvas() * Vector2(160, 240)
	await pointer(wheel.position, true, true)
	root.push_input(wheel, true)
	await settle()
	check(scroll.scroll_vertical > 0 and not scroll.is_pointer_active(),
		"Desktop wheel input cancels an unfinished contact and continues scrolling")
	await pointer(wheel.position, false, true)
	scroll.cancel_drag()
	scroll.scroll_vertical = 0
	await settle()
	button.grab_focus()
	var before := _activations
	for down in [true, false]:
		var key := InputEventAction.new()
		key.action = "ui_accept"
		key.pressed = down
		root.push_input(key, true)
		await process_frame
	check(_activations == before + 1, "Keyboard activation remains native and fires once")


func _check_touch_only_exit(scroll: ResultScroll, probe: InputProbe) -> void:
	for canceled in [false, true]:
		scroll.cancel_drag()
		scroll.scroll_vertical = 120
		await settle()
		var point: Vector2 = scroll.get_global_transform_with_canvas() * Vector2(160, 240)
		await pointer(point, true, true)
		await motion(point - Vector2(0, 40), true)
		await pointer(point - Vector2(0, 40), false, true, canceled)
		var outside := InputEventScreenTouch.new()
		outside.position = Vector2(600, 760)
		outside.pressed = true
		probe.outside_press_seen = false
		root.push_input(outside, true)
		check(probe.outside_press_seen,
			"A new touch outside results remains available after a raw-touch-only gesture: canceled=%s" % canceled)
		await pointer(outside.position, false, true)

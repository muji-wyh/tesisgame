extends "res://tests/godot/word_jelly_map_tests.gd"

const RestPip = preload("res://scripts/word_jelly_map_pip.gd")
var _alpha_bounds: Dictionary = {}


func _number_bounds(label: Label) -> Rect2:
	var ink := Rect2()
	for index in range(label.text.length()):
		var glyph: Rect2 = label.get_character_bounds(index)
		if glyph.has_area():
			ink = ink.merge(glyph) if ink.has_area() else glyph
	return label.get_global_transform() * ink


func _part_bounds(pip, index: int) -> Rect2:
	var texture: Texture2D = pip._expression_heads if index == 1 else pip._outfit_dance_sheet
	var cell: int = pip.EXPRESSION_NAMES.find(pip.expression_name()) if index == 1 else index
	var key: String = texture.resource_path + ":" + str(cell)
	if not _alpha_bounds.has(key):
		var edge: int = texture.get_height()
		var image: Image = texture.get_image().get_region(Rect2i(cell * edge, 0, edge, edge))
		image.convert(Image.FORMAT_RGBA8)
		var bounds: Rect2i = image.get_used_rect()
		var unit: float = 120.0 / edge
		_alpha_bounds[key] = Rect2(Vector2(bounds.position) * unit, Vector2(bounds.size) * unit)
	var unit: float = pip.size.x / 120.0
	var base := Transform2D(Vector2(unit, 0), Vector2(0, unit), pip.support_point() - Vector2(60, 100) * unit)
	return pip.get_global_transform() * base * pip.rest_transforms()[index] * Rect2(_alpha_bounds[key])


func _check_perch(view, number: int) -> void:
	var pip = view._pip
	var item: Dictionary = view._nodes[number - 1]
	var support: Vector2 = pip.get_global_transform() * pip.support_point()
	var expected: Vector2 = item.button.get_global_transform() * item.face.get_transform() * Vector2(item.face.size.x * 0.5, 0)
	check(support.distance_to(expected) < 0.01, "The real painted rim, not the button's empty rectangle, supports Pip")
	check(view._scroll.get_global_rect().grow(0.5).encloses(pip.get_global_rect()),
		"The entire resting guide is framed at stage %d and viewport %s" % [number, root.size])
	check(pip.disabled and pip.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and pip._foreground.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and not view.navigation_controls().has(pip), "Neither layer of the resting companion intercepts stage input")
	check(pip.z_index < item.button.z_index and pip._foreground.z_index > item.button.z_index,
		"The sourced torso sits behind the medallion and the supported wings and head sit in front")
	for index: int in [1, 2, 3]:
		var bounds: Rect2 = _part_bounds(pip, index)
		check(not bounds.grow(-0.15).intersects(_number_bounds(item.label))
			and not bounds.intersects(item.rating.get_global_rect()),
			"Actual opaque Pip part %d leaves the stage %d number and Play clear: %s" % [index, number, bounds])
		if item.boss.visible:
			check(not bounds.intersects(item.boss.get_global_rect()),
				"The resting Pip and the original Boss portrait remain distinct")
	for transform: Transform2D in pip.rest_transforms():
		check(is_equal_approx(transform.determinant(), 1.0), "Perching articulates rigid sourced parts without flattening Pip")


func _check_supported_sleep_poses(view, wardrobe: String) -> void:
	var pip = view._pip
	var item: Dictionary = view._nodes[51]
	var support: Array = pip.rest_snapshot().support
	var geometry: Array = _geometry(view)
	pip.set_reduced_motion(false)
	pip.set_process(false)
	pip.set_awake(false)
	pip.set_process(false)
	pip._wake_blend = 0.0
	for sample: Dictionary in [
		{"elapsed": 0.5, "stage": "upright-snoring"},
		{"elapsed": 9.0, "stage": "prone-snoring"},
		{"elapsed": 18.5, "stage": "tucked-snoring"}]:
		pip._sleep_seconds = float(sample.elapsed)
		pip._update_pose()
		var context: String = "%s %s at %s" % [wardrobe, str(sample.stage), root.size]
		check(pip.rest_snapshot().state == "sleeping"
			and pip.rest_snapshot().sleep_stage == str(sample.stage)
			and pip.expression_name() == "sleepy", "The supported sleep fixture keeps its actual phase and closed eyes: " + context)
		check(pip.rest_snapshot().support == support and _geometry(view) == geometry,
			"Long supported sleep postures leave the rim and stage input targets fixed: " + context)
		for index: int in [1, 2, 3]:
			var bounds: Rect2 = _part_bounds(pip, index)
			check(not bounds.grow(-0.15).intersects(_number_bounds(item.label))
				and not bounds.intersects(item.rating.get_global_rect()),
				"Opaque supported sleep part %d keeps the stage number and Play clear: %s %s" % [index, context, bounds])
		for transform: Transform2D in pip.rest_transforms():
			check(is_equal_approx(transform.determinant(), 1.0),
				"Supported sleep retains rigid sourced artwork: " + context)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	_holder = Control.new()
	root.add_child(_holder)
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view = load(MAP_PATH).new()
	_holder.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stage_selected.connect(func(number: int) -> void: _stage_events.append(number))
	await _settle()
	for dimensions: Vector2i in SIZES:
		await _resize(dimensions)
		for number in range(1, 100):
			view.open(_state(number - 1), true)
			await _settle(2)
			_check_perch(view, number)
	for age: int in [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]:
		var state: Dictionary = _state(51)
		state.pip_age = age
		view.open(state, true)
		await _settle(2)
		_check_perch(view, 52)
	var profiles: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/pip-professional.json")).profiles
	for profile: Dictionary in profiles:
		var state: Dictionary = _state(51)
		state.pip_profile = {"course_id": str(profile.course_id), "level": 4}
		view.open(state, true)
		await _settle(2)
		_check_perch(view, 52)
		check(view.snapshot().guide.course_id == str(profile.course_id), "Resting retains the actual requested career wardrobe")
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(393, 852)]:
		await _resize(dimensions)
		for age: int in [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]:
			var state: Dictionary = _state(51)
			state.pip_age = age
			view.open(state, true)
			await _settle(2)
			_check_supported_sleep_poses(view, "Age %d" % age)
		for profile: Dictionary in profiles:
			var state: Dictionary = _state(51)
			state.pip_profile = {"course_id": str(profile.course_id), "level": 4}
			view.open(state, true)
			await _settle(2)
			_check_supported_sleep_poses(view, str(profile.course_id))
	await _resize(Vector2i(1366, 768))
	view.open(_state(51), false)
	await _settle()
	view.set_process(false)
	view._pip.set_process(false)
	view._nodes[51].button.release_focus()
	view._pip.reaction_left = 0.0
	view._pip.set_awake(false)
	for step in range(3):
		view._pip._process(0.1)
	var rest: Array[Transform2D] = view._pip.rest_transforms()
	var clock: float = view._pip._idle_time
	view._pip._process(0.1)
	check(view._pip._idle_time > clock and view._pip.rest_transforms() != rest,
		"The quiet map pose has its own restrained breathing rather than a standing-age trick")
	view._pip.set_awake(true)
	view._pip._process(0.05)
	var wake_blend: float = view._pip._wake_blend
	clock = view._pip._idle_time
	view._pip.set_reduced_motion(false)
	check(view._pip._wake_blend == wake_blend and view._pip._idle_time == clock,
		"Refreshing an unchanged motion preference cannot snap or restart a head lift")
	view._pip.set_awake(false)
	view._pip._process(0.1)
	var geometry: Array = _geometry(view)
	var point: Vector2 = view._nodes[51].button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion)
	await process_frame
	for step in range(3):
		view._pip._process(0.1)
	check(view._pip.rest_snapshot().awake and view._pip._wake_blend > 0.99
		and view._pip.expression_name() == "surprised" and _geometry(view) == geometry,
		"Actual hover immediately startles Pip without moving stage targets or starting a purchase")
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event)
		await process_frame
	check(_stage_events == [52], "A real stage click emits immediately without waiting for Pip to wake")
	for step in range(14):
		view._pip._process(0.1)
	check(view._pip.rest_snapshot().state == "awake" and view._pip.expression_name() == "neutral"
		and _geometry(view) == geometry,
		"The complete slip-and-climb settles back to an awake face while stage targets remain fixed")
	view.set_reduced_motion(true)
	var still: Array[Transform2D] = view._pip.rest_transforms()
	clock = view._pip._idle_time
	view._pip._process(5.0)
	check(view._pip.rest_transforms() == still and view._pip._idle_time == clock
		and not view._pip.is_processing(), "Reduced motion retains the selected resting pose without breathing or catch-up")
	view.set_active(false)
	view._pip._process(5.0)
	check(view._pip._idle_time == clock, "An inactive map cannot advance its resting companion")
	view.close()
	check(not view.snapshot().guide.visible and _processing(view).is_empty(), "Closing releases every resting-map frame owner")
	_holder.free()
	_finish()

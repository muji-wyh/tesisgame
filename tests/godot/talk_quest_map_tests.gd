extends SceneTree

const Atlas = preload("res://scripts/talk_quest_map.gd")
const Data = preload("res://scripts/talk_quest_data.gd")
var checks: int = 0
var failures: int = 0
var _selected: int = 0
var _selections: int = 0
var _geometry_changes: int = 0


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


func contains_monster_resource(value: Variant) -> bool:
	if value is Resource:
		var path: String = value.resource_path.to_lower()
		return path.contains("/monsters/") or path.ends_with("/talk_quest_monster.gd")
	if value is Array:
		for item in value:
			if contains_monster_resource(item):
				return true
	if value is Dictionary:
		for item in value.values():
			if contains_monster_resource(item):
				return true
	return false


func contains_monster(node: Node) -> bool:
	# Landscape textures and scrolling containers are valid map content.
	for property: Dictionary in node.get_property_list():
		if int(property.type) in [TYPE_OBJECT, TYPE_ARRAY, TYPE_DICTIONARY] and contains_monster_resource(node.get(str(property.name))):
			return true
	for child in node.get_children():
		if contains_monster(child):
			return true
	return false


func check_source_texture(path: String, label: String) -> void:
	check(not path.is_empty() and ResourceLoader.exists(path, "Texture2D"), label + " has an imported source texture")
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return
	var texture: Texture2D = load(path)
	check(texture != null and texture.get_width() > 0 and texture.get_height() > 0,
		label + " resolves to usable artwork instead of an empty image")
	check(not contains_monster_resource(texture), label + " depicts a place instead of a monster portrait")


func check_sourced_art(atlas) -> void:
	for button in atlas.level_buttons:
		check_source_texture(button.art_path, "Adventure %d landmark" % button.number)
	var art: Dictionary = atlas.art_snapshot()
	var manifest_path: String = str(art.get("source_manifest", ""))
	check(not manifest_path.is_empty() and FileAccess.file_exists(manifest_path),
		"All fourteen destinations retain a source and license manifest")
	if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	check(manifest is Dictionary, "The source and license manifest is readable structured data")
	if not manifest is Dictionary:
		return
	var landmark_paths: Array = manifest.get("landmarks", [])
	check(landmark_paths.size() == 14, "The manifest assigns sourced artwork to all fourteen adventures")
	for index in range(mini(landmark_paths.size(), atlas.level_buttons.size())):
		check(str(landmark_paths[index]) == atlas.level_buttons[index].art_path,
			"Adventure %d uses its recorded sourced landmark" % (index + 1))
	var backgrounds: Array = manifest.get("backgrounds", [])
	check(not backgrounds.is_empty(), "The continuous map retains sourced environment artwork")
	for index in range(backgrounds.size()):
		check_source_texture(str(backgrounds[index]), "Map environment %d" % (index + 1))
	var interface_art: Dictionary = manifest.get("ui", {})
	check(not interface_art.is_empty(), "The map retains sourced interface artwork")
	for role in interface_art:
		check_source_texture(str(interface_art[role]), "Map interface " + str(role))
	var sources: Array = manifest.get("sources", [])
	check(not sources.is_empty(), "The map identifies the original asset sources")
	for source: Dictionary in sources:
		for field in ["title", "creator", "url", "license", "licenseUrl", "acquisitionStatus", "animations"]:
			check(not str(source.get(field, "")).is_empty(),
				"Source %s records %s" % [str(source.get("id", "unknown")), field])


func _maximum(atlas) -> float:
	var bar: ScrollBar = atlas._scroll.get_h_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 760)
	var atlas = Atlas.new()
	root.add_child(atlas)
	atlas.size = Vector2(390, 540)
	atlas.configure(Data.levels())
	atlas.set_reduced_motion(true)
	atlas.level_selected.connect(func(number: int) -> void:
		_selected = number
		_selections += 1)
	atlas.changed.connect(func() -> void: _geometry_changes += 1)
	await settle()
	check(atlas.level_buttons.size() == 14, "All fourteen adventures retain accessible Button controls")
	check(not contains_monster(atlas), "The atlas uses place landmarks without creature portraits")
	check_sourced_art(atlas)
	for index in range(14):
		atlas.set_level_state(index + 1, index < 3, index == 0)
		var button: Button = atlas.level_buttons[index]
		check(button.disabled == (index >= 3), "Only unlocked stops accept input")
		check(button.accessibility_name.contains(Data.level(index + 1).title), "Every stop announces its full scene title")
		check(button.focus_mode == (Control.FOCUS_ALL if index < 3 else Control.FOCUS_NONE),
			"Unlocked offscreen adventures remain reachable by keyboard while locked ones do not")
	check(atlas.level_buttons[1].current_stop and not atlas.level_buttons[2].current_stop,
		"The beacon chooses the first unfinished unlocked adventure")
	check(atlas.level_buttons[0].accessibility_name.contains("Cleared"), "Completed state is announced independently of its color")
	await _check_locked_input(atlas)
	await _check_layouts(atlas)
	await _check_progress_and_focus(atlas)
	await _check_pointer_navigation(atlas)
	await _check_cancellations(atlas)
	var next_stop = atlas.level_buttons[10]
	var previous_time: float = next_stop._time
	next_stop._process(1.0)
	check(next_stop.reduced_motion and is_equal_approx(next_stop._time, previous_time),
		"Reduced motion freezes the next-stop beacon clock")
	atlas.configure([])
	await settle()
	check(atlas.level_buttons.is_empty() and not atlas._next.visible,
		"Reconfiguration removes old destinations and region controls")
	check(not atlas._scroll.is_scrolling(), "Reconfiguration cannot retain a stale map gesture")
	atlas.queue_free()
	await process_frame
	print("Talk Quest atlas: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_layouts(atlas) -> void:
	# Reuse the same instance to catch minimum-size locks after desktop-to-phone resizing.
	for layout: Dictionary in [
		{"size": Vector2(960, 480), "scale": 1.0},
		{"size": Vector2(390, 540), "scale": 1.0},
		{"size": Vector2(296, 308), "scale": 1.0},
		{"size": Vector2(320, 420), "scale": 1.0},
		{"size": Vector2(844, 225), "scale": 1.0},
		{"size": Vector2(544, 136), "scale": 1.0},
		{"size": Vector2(544, 140) / 0.75, "scale": 0.75},
		{"size": Vector2(320, 420) / 0.75, "scale": 0.75}
	]:
		atlas.set_ui_scale(float(layout.scale))
		atlas.size = layout.size
		await settle()
		var label: String = "at %s, scale %.2f" % [str(layout.size), float(layout.scale)]
		check(atlas.custom_minimum_size == Vector2.ZERO and atlas.get_combined_minimum_size() == Vector2.ZERO,
			"The world never expands the map viewport " + label)
		check(Rect2(Vector2.ZERO, atlas.size).grow(1.0).encloses(atlas._scroll.get_rect()),
			"The horizontal viewport stays inside the resized atlas " + label)
		check(atlas._scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
			and atlas._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			and not atlas._scroll.get_h_scroll_bar().visible and not atlas._scroll.get_v_scroll_bar().visible,
			"Map movement is horizontal and both scrollbars stay hidden " + label)
		check(_maximum(atlas) > atlas._scroll.size.x and atlas._scroll.scroll_vertical == 0,
			"Fourteen large destinations form a scrollable horizontal world " + label)
		var previous_x: float = -INF
		var target_rects: Array[Rect2] = []
		for button in atlas.level_buttons:
			check(button.visible and button.get_rect().get_center().x > previous_x,
				"All destinations remain ordered, distinct targets in the continuous world " + label)
			previous_x = button.get_rect().get_center().x
			var overlaps: bool = false
			for previous: Rect2 in target_rects:
				overlaps = overlaps or previous.intersects(button.get_rect())
			check(not overlaps, "Adventure targets remain separate along the route " + label)
			target_rects.append(button.get_rect())
			check(button.size.x * float(layout.scale) >= 44 and button.size.y * float(layout.scale) >= 44,
				"Every destination keeps a usable physical touch target " + label)
			var caption: Label = button._caption
			check(Rect2(Vector2.ZERO, button.size).grow(1.0).encloses(caption.get_rect()),
				"Scene captions fit inside their responsive landmarks " + label)
			check(caption.get_theme_font_size("font_size") * float(layout.scale) >= 12,
				"Scene captions retain readable type " + label)
			check(caption.get_visible_line_count() >= caption.get_line_count(),
				"The complete scene title remains readable " + label + ", level %d" % button.number)
			atlas.show_level(button.number)
			await settle()
			check(atlas.level_in_view(button) and atlas._scroll.get_global_rect().grow(1.0).encloses(button.get_global_rect()),
				"Every destination can be revealed completely " + label + ", level %d" % button.number)
			check(atlas.visible_level_buttons().has(button), "Visible destination reporting follows horizontal scrolling")
		for button: Button in atlas.navigation_buttons():
			check(button.size.x * float(layout.scale) >= 44 and button.size.y * float(layout.scale) >= 44,
				"Region arrows retain usable touch targets " + label)
			check(Rect2(Vector2.ZERO, atlas.size).grow(1.0).encloses(button.get_rect()),
				"Region arrows remain fixed within the atlas " + label)


func _check_progress_and_focus(atlas) -> void:
	atlas.set_ui_scale(1.0)
	atlas.size = Vector2(390, 540)
	for number in range(1, 15):
		atlas.set_level_state(number, true, number < 11)
	await settle()
	check(atlas.current_chapter == 2 and atlas.level_in_view(atlas.level_buttons[10]),
		"Newly reached progress reveals the next unfinished adventure")
	atlas.show_level(2)
	await settle()
	var offset: int = atlas._scroll.scroll_horizontal
	for number in range(1, 15):
		atlas.set_level_state(number, true, number < 11)
	await settle()
	check(atlas._scroll.scroll_horizontal == offset,
		"Refreshing unchanged progress preserves a manually explored part of the map")
	atlas.show_level(7)
	await settle()
	check(atlas.current_chapter == 1 and atlas.level_in_view(atlas.level_buttons[6]),
		"Continuing a saved adventure reveals its exact destination")
	atlas.show_level(1)
	await settle()
	check(not atlas.level_in_view(atlas.level_buttons[13]), "The last adventure starts outside the phone viewport")
	atlas.level_buttons[13].grab_focus()
	await settle()
	check(atlas.level_in_view(atlas.level_buttons[13]) and not atlas._scroll.is_scrolling(),
		"Offscreen keyboard focus reveals the full last adventure and takes ownership from inertia")
	for index in range(13):
		var button: Button = atlas.level_buttons[index]
		var neighbor: NodePath = button.get_focus_neighbor(SIDE_RIGHT)
		check(not neighbor.is_empty() and button.get_node_or_null(neighbor) == atlas.level_buttons[index + 1],
			"Right controller navigation follows adventure order")
	atlas.set_chapter(0)
	await settle()
	check(atlas.current_chapter == 0 and atlas.level_in_view(atlas.level_buttons[0]) and atlas._previous.disabled,
		"The first region arrow destination reveals the beginning of the world")
	atlas._next.pressed.emit()
	await settle()
	check(atlas.current_chapter == 1 and atlas.level_in_view(atlas.level_buttons[4]),
		"Next region reveals the first adventure around town")
	atlas._next.grab_focus()
	atlas._next.pressed.emit()
	await settle()
	check(atlas.current_chapter == 2 and atlas.level_in_view(atlas.level_buttons[10]) and atlas._next.disabled,
		"Next region stops at the final region")
	check(not atlas._next.has_focus(), "A disabled region arrow does not retain keyboard focus")


func _send(atlas, event: InputEvent) -> void:
	root.push_input(event, true)
	# Pointer timestamps use wall time; deterministic steps below own inertia.
	atlas._scroll.set_process(false)


func _pointer(atlas, point: Vector2, down: bool, kind: String) -> void:
	var event: InputEvent
	if kind == "touch":
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION if kind == "emulated" else 0
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = point
	event.pressed = down
	_send(atlas, event)


func _motion(atlas, point: Vector2, kind: String) -> void:
	var event: InputEvent
	if kind == "touch":
		event = InputEventScreenDrag.new()
		event.index = 0
	else:
		event = InputEventMouseMotion.new()
		event.device = InputEvent.DEVICE_ID_EMULATION if kind == "emulated" else 0
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	event.relative = Vector2(-300, -300)
	_send(atlas, event)


func _advance(atlas, frames: int) -> void:
	for frame in range(frames):
		atlas._scroll._process(1.0 / 60.0)
		atlas._scroll.set_process(false)


func _reset(atlas, number: int = 7) -> void:
	atlas.cancel_input()
	root.gui_release_focus()
	atlas.show_level(number)
	await settle()


func _visible_button(atlas) -> Button:
	for button: Button in atlas.level_buttons:
		var shown: Rect2 = button.get_global_rect().intersection(atlas._scroll.get_global_rect())
		if not button.disabled and shown.size.x >= 44 and shown.size.y >= 44:
			return button
	return null


func _check_locked_input(atlas) -> void:
	await _reset(atlas, 14)
	var before: int = _selections
	var point: Vector2 = atlas.level_buttons[13].get_global_rect().get_center()
	_pointer(atlas, point, true, "mouse")
	_pointer(atlas, point, false, "mouse")
	check(_selections == before, "Tapping a visible locked landmark never starts its adventure")


func _check_pointer_navigation(atlas) -> void:
	for kind in ["mouse", "touch", "emulated"]:
		await _reset(atlas)
		var button: Button = atlas.level_buttons[6]
		var point: Vector2 = button.get_global_rect().get_center()
		var before: int = _selections
		var offset: int = atlas._scroll.scroll_horizontal
		_pointer(atlas, point, true, kind)
		check(_selections == before and atlas._scroll.scroll_horizontal == offset,
			"A %s press waits for a known tap instead of starting an adventure or moving focus" % kind)
		_pointer(atlas, point, false, kind)
		check(_selections == before + 1 and _selected == 7,
			"A stationary %s tap starts the actual visible adventure exactly once" % kind)
	for first in ["touch", "emulated"]:
		await _reset(atlas)
		var second: String = "emulated" if first == "touch" else "touch"
		var start: Vector2 = atlas.level_buttons[6].get_global_rect().get_center()
		var before: int = _selections
		var offset: int = atlas._scroll.scroll_horizontal
		var changes: int = _geometry_changes
		_pointer(atlas, start, true, first)
		_pointer(atlas, start, true, second)
		var finish := start
		for step in range(1, 5):
			await create_timer(0.020).timeout
			finish = start - Vector2(step * 20, 0)
			_motion(atlas, finish, first)
			_motion(atlas, finish, second)
		check(absi(atlas._scroll.scroll_horizontal - offset - 80) <= 1,
			"Paired %s-first events move the horizontal world once using absolute pointer positions" % first)
		_pointer(atlas, finish, false, first)
		_pointer(atlas, finish, false, second)
		var released: int = atlas._scroll.scroll_horizontal
		_advance(atlas, 12)
		check(atlas._scroll.scroll_horizontal > released and atlas._scroll.is_coasting() and _selections == before,
			"A map swipe continues with inertia without selecting the crossed adventure")
		await settle()
		check(_geometry_changes > changes, "Scrolled map geometry is republished for accessible and browser navigation")
		var visible: Button = _visible_button(atlas)
		check(visible != null, "A coasting map retains a visible destination for a braking contact")
		if visible == null:
			continue
		var point: Vector2 = visible.get_global_rect().intersection(atlas._scroll.get_global_rect()).get_center()
		_pointer(atlas, point, true, "touch")
		_pointer(atlas, point, false, "touch")
		check(not atlas._scroll.is_scrolling() and _selections == before,
			"The first contact brakes a moving map without starting a level")
		_pointer(atlas, point, true, "touch")
		_pointer(atlas, point, false, "touch")
		check(_selections == before + 1 and _selected == visible.number,
			"A fresh tap after braking can select the same destination")


func _check_cancellations(atlas) -> void:
	var permission := {"allowed": true}
	atlas.interaction_allowed = func() -> bool: return permission.allowed
	for cause in ["host", "hidden", "resize", "focus", "blocked"]:
		permission.allowed = true
		atlas.show()
		await _reset(atlas)
		var wheel := InputEventMouseButton.new()
		wheel.position = atlas._scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.factor = 1.0
		wheel.pressed = true
		_send(atlas, wheel)
		_advance(atlas, 3)
		check(atlas._scroll.is_coasting(), "A wheel gesture starts horizontal momentum before " + cause)
		match cause:
			"host": atlas.cancel_input()
			"hidden": atlas.hide()
			"resize": atlas.size.x += 1
			"focus": atlas._scroll.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"blocked": permission.allowed = false
		_advance(atlas, 1)
		await settle()
		var offset: int = atlas._scroll.scroll_horizontal
		_advance(atlas, 20)
		check(not atlas._scroll.is_scrolling() and atlas._scroll.scroll_horizontal == offset,
			"Map interaction cancellation stops pointer ownership and momentum: " + cause)
	permission.allowed = true
	atlas.show()
	atlas.interaction_allowed = Callable()
	atlas.cancel_input()

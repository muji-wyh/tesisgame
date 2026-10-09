class_name JellyMatch
extends Control
## A fixed portrait jelly well. The model alone owns answers, time and loot.

signal word_requested(word: Dictionary)
signal audio_requested(cue: String)
signal word_attempted(event_id: String, word_ids: Array[String], correct: bool)
signal round_finished(result: Dictionary)
signal chests_requested
signal replay_requested
signal changed(state: Dictionary)

const JellyMatchModel = preload("res://scripts/jelly_match_model.gd")
const Tile = preload("res://scripts/jelly_tile.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
const Style = preload("res://scripts/ui_style.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const Chest = preload("res://scripts/chest_view.gd")
const SURFACES := ["coral", "mint", "sky", "lilac"]
const NO_POINTER: int = -2147483648
const MOUSE_POINTER: int = -1

var game = JellyMatchModel.new()
var interaction_allowed: Callable
var reduced_motion: bool = false
var replay_button: Button
var chests_button: Button
var finish_button: Button

var _configured: bool = false
var _generation: int = 0
var _paused: bool = false
var _theme: Dictionary = {}
var _manifest: Dictionary = {}
var _surfaces: Array[Texture2D] = []
var _pictures: Dictionary = {}
var _tiles: Dictionary = {}
var _falling_layer: Control
var _ghost: Tile
var _preview_tiles: Array[Tile] = []
var _preview_rect := Rect2()
var _board := Rect2()
var _pitch: float = 0.0
var _gap: float = 0.0
var _compact_hud: bool = false
var _pointer: int = NO_POINTER
var _gesture_serial: int = 0
var _source: int = -1
var _target: int = -1
var _selected: int = -1
var _press_point := Vector2.ZERO
var _drag_point := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _dragging: bool = false
var _snapbacks: Dictionary = {}
var _merged: Tile
var _fusion_origin := Vector2.ZERO
var _fusion_start := Vector2.ZERO
var _fusion_direction := Vector2.RIGHT
var _focus_after_fusion: bool = false
var _loot_flights: Array[Dictionary] = []
var _loot_icon: TextureRect
var _loot_count: Label
var _pace: Label
var _next_tile: ProgressBar
var _notice: Label
var _result: Control
var _result_title: Label
var _result_caption: Label
var _result_chests: Array[TextureRect] = []
var _result_visible: bool = false
var _result_transition: bool = false
var _result_elapsed: float = 0.0
var _last_published: String = ""
var _publish_elapsed: float = 0.0
var _chest_cache: Dictionary = {}
var _chest_texture: Texture2D
var _landing_cooldown: float = 0.0

func _init() -> void:
	name = "JellyMatch"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	_falling_layer = Control.new()
	_falling_layer.name = "FallingJellyClip"
	_falling_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_falling_layer.clip_contents = true
	_falling_layer.z_index = 2
	add_child(_falling_layer)
	_ghost = Tile.new()
	_ghost.name = "LandingProjection"
	_ghost.disabled = true
	_ghost.focus_mode = Control.FOCUS_NONE
	_ghost.modulate = Color(0.65, 0.82, 0.75, 0.28)
	add_child(_ghost)
	_ghost.hide()
	_merged = Tile.new()
	_merged.name = "FusedJelly"
	_merged.focus_mode = Control.FOCUS_NONE
	_merged.z_index = 30
	add_child(_merged)
	_merged.hide()
	_loot_icon = _image(self)
	_loot_count = _label(self, "0", 24)
	_loot_count.name = "JellyLootCount"
	_pace = _label(self, "Next", 12)
	_pace.add_theme_color_override("font_color", Color("#315142"))
	_next_tile = ProgressBar.new()
	_next_tile.show_percentage = false
	_next_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_next_tile)
	for index in range(3):
		var preview := Tile.new()
		preview.name = "UpcomingJelly%d" % (index + 1)
		preview.disabled = true
		preview.focus_mode = Control.FOCUS_NONE
		add_child(preview)
		_preview_tiles.append(preview)
	_notice = _label(self, "Match a picture to its word.", 14)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result = Control.new()
	_result.name = "JellyResults"
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_result)
	_result.hide()
	_result_title = _label(_result, "Round results", 30)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_caption = _label(_result, "", 17)
	_result_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(3):
		_result_chests.append(_image(_result))
	chests_button = _button("Open chests", "JellyOpenChests", _open_chests)
	replay_button = _button("Play again", "JellyReplay", _replay)
	finish_button = Button.new()
	finish_button.name = "JellyFinish"
	finish_button.text = "Finish"
	UiClick.bind_button(finish_button)
	finish_button.pressed.connect(_finish_round)
	add_child(finish_button)
	game.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		word_attempted.emit(id, ids, correct))
	game.cue_requested.connect(_cue)
	game.chest_awarded.connect(_chest_awarded)
	game.finished.connect(_finished)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)

func _image(parent: Node) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _label(parent: Node, value: String, pixels: int) -> Label:
	var label := Style.label(value, pixels)
	label.clip_text = true
	parent.add_child(label)
	return label

func _button(value: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.name = node_name
	UiClick.bind_button(button)
	button.pressed.connect(callback)
	_result.add_child(button)
	return button

func configure(words: Array, level: int, theme: Dictionary, chests: Dictionary, reduced: bool, seed_value: int = -1) -> bool:
	stop()
	if _surfaces.is_empty():
		var loaded: Array[Texture2D] = []
		for color: String in SURFACES:
			var texture := load("res://assets/images/jelly-match/gel-%s.png" % color) as Texture2D
			if texture == null:
				return false
			loaded.append(texture)
		_surfaces = loaded
	reduced_motion = reduced
	_result_visible = false
	_result_transition = false
	_result_elapsed = 0.0
	_publish_elapsed = 0.0
	_landing_cooldown = 0.0
	_focus_after_fusion = false
	_paused = false
	apply_theme(theme, chests)
	_configured = game.configure(words, level, seed_value)
	game.paused = false
	_sync_tiles()
	_layout()
	_refresh_hud()
	_publish()
	return _configured

func apply_theme(theme: Dictionary, chests: Dictionary) -> void:
	_theme = theme.duplicate(true)
	_manifest = chests
	_prepare_chest()
	var accent: Color = _theme.get("accent", Style.GOOD)
	_next_tile.add_theme_stylebox_override("background", Style.box(Color(accent, 0.13), Color.TRANSPARENT, 4, 0))
	_next_tile.add_theme_stylebox_override("fill", Style.box(accent, Color.TRANSPARENT, 4, 0))
	for state: String in ["background", "fill"]:
		_next_tile.get_theme_stylebox(state).set_content_margin_all(0)
	Style.action_button(chests_button, accent, true)
	Style.action_button(replay_button, accent)
	Style.action_button(finish_button, accent)
	for id in _tiles:
		_configure_tile(_tiles[id], _cell(int(id)))
	_merged.tile_id = -1
	_ghost.tile_id = -1
	for preview: Tile in _preview_tiles:
		preview.tile_id = -1
	queue_redraw()

func _prepare_chest() -> void:
	if _theme.is_empty() or _manifest.is_empty() or not is_inside_tree():
		return
	var id: String = str(_theme.get("id", "spring"))
	if not _chest_cache.has(id):
		var viewport := SubViewport.new()
		viewport.name = "JellyChest_" + id
		viewport.size = Vector2i(256, 256)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var art := Chest.new()
		viewport.add_child(art)
		art.size = Vector2(256, 256)
		art.reduced_motion = true
		art.configure_skin(_theme, _manifest)
		_chest_cache[id] = {"viewport": viewport, "art": art, "frames": 0, "texture": viewport.get_texture(), "cropped": false}
	_apply_chest_texture(_chest_cache[id].texture)

func _apply_chest_texture(texture: Texture2D) -> void:
	_chest_texture = texture
	_loot_icon.texture = _chest_texture
	for chest: TextureRect in _result_chests:
		chest.texture = _chest_texture
	for tile in _tiles.values():
		tile.set_chest_texture(texture)
	for preview: Tile in _preview_tiles:
		preview.set_chest_texture(texture)

func _cache_chest_image(id: String, cache: Dictionary) -> void:
	# Source chests reserve an opening envelope. Trim the rendered closed pose once
	# so a tiny treasure marker and a result hero use actual artwork dimensions.
	if DisplayServer.get_name() == "headless":
		return
	var picture: Image = cache.viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		return
	var bounds: Rect2i = picture.get_used_rect()
	if not bounds.has_area():
		return
	bounds = bounds.grow(2).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	cache.texture = ImageTexture.create_from_image(picture.get_region(bounds))
	cache.cropped = true
	if str(_theme.get("id", "")) == id:
		_apply_chest_texture(cache.texture)

func _ready() -> void:
	_prepare_chest()
	_layout()

func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	_snapbacks.clear()
	_loot_flights.clear()
	_sync_tiles()
	_refresh_fusion()
	_animate_result()
	queue_redraw()
	_publish()

func pause(value: bool = true) -> void:
	if _paused == value:
		return
	_paused = value
	game.set_paused(value)
	cancel_input()
	if not value:
		_result_transition = false
	_refresh_controls()
	_publish()

func settle() -> void:
	cancel_input()
	_snapbacks.clear()
	_loot_flights.clear()
	_sync_tiles()
	_refresh_fusion()
	queue_redraw()
	_publish()

func stop() -> void:
	_generation += 1
	_configured = false
	game.paused = true
	settle()
	_result_visible = false
	_result.hide()
	_merged.hide()
	_ghost.hide()
	for preview: Tile in _preview_tiles:
		preview.hide()
	for tile in _tiles.values():
		tile.hide()
		tile.queue_free()
	_tiles.clear()
	_focus_after_fusion = false
	_refresh_controls()
	_refresh_hud()
	_publish()

func cancel_input() -> void:
	_pointer = NO_POINTER
	_source = -1
	_target = -1
	_selected = -1
	_dragging = false
	_gesture_serial += 1
	_refresh_marks()
	_sync_positions()
	_refresh_fusion()
	queue_redraw()
	_publish()

func release_pointer(pointer: int) -> void:
	# The host may report pointer-up before Godot receives its normal drop event.
	# Only cancel a gesture still owned by the same contact after that event runs.
	_cancel_missing_release.call_deferred(pointer, _gesture_serial)

func _cancel_missing_release(pointer: int, serial: int) -> void:
	if serial == _gesture_serial and pointer == _pointer:
		cancel_input()

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_input()
	else:
		_result_transition = false
	_refresh_controls()
	_publish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _merged != null:
		cancel_input()

func _allowed() -> bool:
	return _configured and not _paused and is_visible_in_tree() and (not interaction_allowed.is_valid() or bool(interaction_allowed.call()))

func _can_play() -> bool:
	return _allowed() and game.phase == "playing" and game.fusion.is_empty() and not _result_visible

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (_pointer != NO_POINTER or _selected >= 0):
		cancel_input()
		get_viewport().set_input_as_handled()
		return
	if not _can_play():
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var handled: bool = false
	if event is InputEventScreenTouch:
		if event.canceled and event.index == _pointer:
			cancel_input()
			handled = true
		elif event.pressed:
			handled = _press(event.index, event.position)
		elif event.index == _pointer:
			_release(event.position)
			handled = true
	elif event is InputEventScreenDrag and event.index == _pointer:
		_move(event.position)
		handled = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.canceled and _pointer == MOUSE_POINTER:
			cancel_input()
			handled = true
		elif event.pressed:
			handled = _press(MOUSE_POINTER, event.position)
		elif _pointer == MOUSE_POINTER:
			_release(event.position)
			handled = true
	elif event is InputEventMouseMotion and _pointer == MOUSE_POINTER:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_move(event.position)
		else:
			cancel_input()
		handled = true
	if handled:
		get_viewport().set_input_as_handled()

func _press(pointer: int, global_point: Vector2) -> bool:
	if _pointer != NO_POINTER or not _can_play():
		return false
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	var id: int = _tile_at(point)
	if id < 0:
		return false
	_pointer = pointer
	_gesture_serial += 1
	_source = id
	_target = -1
	_press_point = point
	_drag_point = point
	_drag_offset = point - _tiles[id].position
	_dragging = false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if _tiles.values().has(focused):
		focused.release_focus()
	var generation: int = _generation
	word_requested.emit(_cell(id).word.duplicate(true))
	if generation != _generation or not _can_play():
		return false
	audio_requested.emit("pick")
	if generation != _generation or not _can_play():
		return false
	_refresh_marks()
	_publish()
	return true

func _move(global_point: Vector2) -> void:
	if _source < 0 or not _tiles.has(_source):
		cancel_input()
		return
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	_drag_point = point
	if point.distance_to(_press_point) * Style.ui_scale(self) > 7.0:
		_dragging = true
	if not _dragging:
		return
	_selected = -1
	_tiles[_source].position = point - _drag_offset
	_tiles[_source].z_index = 40
	_target = _tile_at(point, _source)
	_refresh_marks()
	_publish()

func _release(global_point: Vector2) -> void:
	if not _can_play() or _source < 0:
		cancel_input()
		return
	var generation: int = _generation
	var source: int = _source
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	var target: int = _tile_at(point, source) if _dragging else -1
	var from: Vector2 = _tiles[source].position if _tiles.has(source) else Vector2.ZERO
	var dragged: bool = _dragging
	_pointer = NO_POINTER
	_source = -1
	_target = -1
	_dragging = false
	_gesture_serial += 1
	if dragged:
		_selected = -1
		if target >= 0:
			_merge(source, target, from)
		else:
			_snap_back(source, from)
			audio_requested.emit("release")
	else:
		_activate(source, false)
	if generation != _generation or not _allowed():
		return
	_refresh_marks()
	_publish()

func _activate(id: int, speak: bool = true) -> void:
	if not _can_play() or not _settled(_cell(id)):
		return
	if speak:
		var generation: int = _generation
		word_requested.emit(_cell(id).word.duplicate(true))
		if generation != _generation or not _can_play():
			return
		audio_requested.emit("pick")
		if generation != _generation or not _can_play():
			return
	if _selected == id:
		_selected = -1
	elif _selected >= 0:
		var previous: int = _selected
		_selected = -1
		_merge(previous, id, _tiles[previous].position)
	else:
		_selected = id
	_refresh_marks()
	_publish()

func _merge(first: int, second: int, from: Vector2) -> void:
	var generation: int = _generation
	var result: String = game.try_merge(first, second)
	if generation != _generation or not _configured or game.phase != "playing":
		return
	if result == "correct":
		if game.fusion.is_empty():
			return
		_fusion_start = from + _tile_rect(game.fusion.a).size * 0.5
		_fusion_direction = (_tile_rect(game.fusion.b).get_center() - _tile_rect(game.fusion.a).get_center()).normalized()
		_focus_after_fusion = _tiles.values().has(get_viewport().gui_get_focus_owner())
		_snapbacks.clear()
	else:
		_snap_back(first, from)
	_sync_tiles()
	_refresh_fusion()
	_refresh_hud()
	queue_redraw()

func _snap_back(id: int, from: Vector2) -> void:
	if not _tiles.has(id):
		return
	if not reduced_motion:
		_snapbacks[id] = {"from": from, "elapsed": 0.0}
	_sync_positions()

func _cell(id: int) -> Dictionary:
	for cell: Dictionary in game.cells:
		if int(cell.id) == id:
			return cell
	return {}

func _settled(cell: Dictionary) -> bool:
	return game.is_settled(cell)

func _tile_at(point: Vector2, except_id: int = -1) -> int:
	if not _board.has_point(point):
		return -1
	for cell: Dictionary in game.cells:
		if int(cell.id) != except_id and _settled(cell) and _tile_rect(cell).has_point(point):
			return int(cell.id)
	return -1

func _picture(word: Dictionary) -> Texture2D:
	var path: String = str(word.get("image", ""))
	if path.is_empty():
		return null
	if not _pictures.has(path):
		_pictures[path] = load("res://" + path) as Texture2D
	return _pictures[path]

func _configure_tile(tile: Tile, cell: Dictionary, combined: bool = false) -> void:
	if cell.is_empty() or _surfaces.is_empty():
		return
	tile.configure(cell, _surfaces[posmod(int(cell.id), _surfaces.size())], _picture(cell.word), _chest_texture, _theme.get("accent", Style.GOOD), combined)

func _sync_tiles() -> void:
	if not _configured:
		return
	var live: Dictionary = {}
	for cell: Dictionary in game.cells:
		var id: int = int(cell.id)
		live[id] = true
		if not _tiles.has(id):
			var tile := Tile.new()
			tile.name = "Jelly_%d" % id
			tile.pressed.connect(_activate.bind(id))
			add_child(tile)
			_tiles[id] = tile
			_configure_tile(tile, cell)
	for id in _tiles.keys():
		if not live.has(id):
			_tiles[id].hide()
			_tiles[id].queue_free()
			_tiles.erase(id)
			_snapbacks.erase(id)
	_refresh_marks()
	_sync_positions()
	_refresh_controls()
	if _focus_after_fusion and game.fusion.is_empty() and _can_play():
		_focus_after_fusion = false
		default_focus().grab_focus()

func _tile_rect(cell: Dictionary) -> Rect2:
	return Rect2(_board.position + Vector2(int(cell.column), int(cell.row)) * _pitch + Vector2.ONE * _gap * 0.5,
		Vector2.ONE * (_pitch - _gap))

func _sync_positions() -> void:
	_ghost.hide()
	for cell: Dictionary in game.cells:
		var id: int = int(cell.id)
		if not _tiles.has(id):
			continue
		var tile: Tile = _tiles[id]
		var rect: Rect2 = _tile_rect(cell)
		tile.size = rect.size
		tile.z_index = 40 if id == _source and _dragging else 1
		var pose: Dictionary = Motion.sample(cell)
		var dragging: bool = id == _source and _dragging
		var airborne: bool = bool(cell.get("arrival", false)) and float(cell.age) < Motion.contact_at(cell) and not reduced_motion
		var parent: Control = _falling_layer if airborne else self
		if tile.get_parent() != parent:
			tile.reparent(parent, false)
		var position_in_view: Vector2 = tile.position if dragging else rect.position
		if not dragging:
			if _snapbacks.has(id):
				var p: float = clampf(float(_snapbacks[id].elapsed) / 0.24, 0.0, 1.0)
				position_in_view = Vector2(_snapbacks[id].from).lerp(rect.position, 1.0 - pow(1.0 - p, 3.0))
			elif not reduced_motion:
				position_in_view.y -= float(pose.lift_rows) * _pitch
			tile.position = position_in_view - (_falling_layer.position if airborne else Vector2.ZERO)
		var stretch: Vector2 = Vector2.ONE if reduced_motion else Vector2(0.985, 1.06) if dragging else Vector2(pose.stretch)
		tile.deform(0.0 if reduced_motion or dragging else float(pose.bend), float(pose.beat), stretch)
		var lift: float = 6.0 / Style.ui_scale(self) if dragging else maxf(0.0, rect.position.y - position_in_view.y)
		tile.set_support(lift, 0.0 if reduced_motion or dragging else float(pose.compression))
		tile.modulate.a = 1.0 if reduced_motion else float(pose.opacity)
		tile.visible = not _result_visible
		if airborne and not _result_visible:
			if _ghost.tile_id != id:
				_configure_tile(_ghost, cell)
				_ghost.set_projection(true)
			_ghost.position = rect.position
			_ghost.size = rect.size
			_ghost.set_projection(true)
			_ghost.show()

func _sync_preview() -> void:
	for index in range(_preview_tiles.size()):
		var preview: Tile = _preview_tiles[index]
		preview.visible = _configured and not _result_visible and index < game.upcoming.size()
		if not preview.visible:
			continue
		var item: Dictionary = game.upcoming[index]
		if preview.tile_id != int(item.id):
			_configure_tile(preview, item)
			preview.set("accessibility_name", "Next %d: %s %s" % [index + 1, str(item.kind), str(item.word.text)])
		preview.set_support(0.0, 0.0, false)

func _refresh_marks() -> void:
	var feedback_enabled: bool = _can_play()
	for id in _tiles:
		_tiles[id].set_marked(int(id) == _target, int(id) == _selected or int(id) == _source, feedback_enabled, reduced_motion)

func _process(delta: float) -> void:
	for id in _chest_cache:
		var cache: Dictionary = _chest_cache[id]
		if int(cache.frames) < 6:
			cache.frames += 1
			if int(cache.frames) == 6:
				_cache_chest_image(str(id), cache)
				cache.art.set_idle_paused(true)
				cache.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not _allowed() or delta > 0.5:
		if _pointer != NO_POINTER:
			cancel_input()
		return
	var generation: int = _generation
	var previous_ages: Dictionary = {}
	for cell: Dictionary in game.cells:
		previous_ages[int(cell.id)] = float(cell.age)
	_landing_cooldown = maxf(0.0, _landing_cooldown - delta)
	if game.phase == "playing":
		game.step(delta)
	if generation != _generation or not _allowed():
		return
	for id in _snapbacks.keys():
		_snapbacks[id].elapsed += delta
		if float(_snapbacks[id].elapsed) >= 0.24:
			_snapbacks.erase(id)
	for flight: Dictionary in _loot_flights:
		flight.elapsed += delta
	_loot_flights = _loot_flights.filter(func(item: Dictionary) -> bool: return float(item.elapsed) < 0.65)
	if _result_visible:
		_result_elapsed += delta
	_sync_tiles()
	_refresh_fusion()
	_refresh_hud()
	_animate_result()
	queue_redraw()
	_publish_elapsed += delta
	if _publish_elapsed >= 0.1:
		_publish()
	if generation == _generation and _can_play() and game.full_elapsed < 0.0 and _landing_cooldown <= 0.0:
		for cell: Dictionary in game.cells:
			var contact: float = Motion.contact_at(cell)
			if float(previous_ages.get(int(cell.id), 0.0)) < contact and float(cell.age) >= contact:
				# Adjacent bodies land as one quiet group, never a stack of impacts.
				_landing_cooldown = 0.12
				audio_requested.emit("land")
				break

func _refresh_fusion() -> void:
	if game.fusion.is_empty() or _result_visible:
		_merged.hide()
		return
	var fusion: Dictionary = game.fusion
	var p: float = clampf(float(fusion.elapsed) / float(fusion.duration), 0.0, 1.0)
	var a: Dictionary = fusion.a
	var b: Dictionary = fusion.b
	var destination: Vector2 = _tile_rect(b).get_center()
	_fusion_origin = destination
	if _merged.tile_id != int(b.id):
		_configure_tile(_merged, b, true)
	var size_factor: float = 1.28
	var opacity: float = 1.0
	var stretch := Vector2.ONE
	var contact: float = smoothstep(0.0, 0.30, p)
	var union: float = smoothstep(0.24, 0.38, p)
	var close_drop: bool = _fusion_start.distance_to(destination) < _pitch * 0.4
	var contact_lobe: float = sin(clampf(p / 0.27, 0.0, 1.0) * PI) if close_drop else 0.0
	for cell: Dictionary in [a, b]:
		if not _tiles.has(int(cell.id)):
			continue
		var droplet: Tile = _tiles[int(cell.id)]
		droplet.set_support(0.0, 0.0, false)
		droplet.visible = not reduced_motion and p < 0.38
		droplet.modulate.a = 1.0 - union
		droplet.z_index = 22 if int(cell.id) == int(a.id) else 21
		var center: Vector2 = _fusion_start.lerp(destination, contact) if int(cell.id) == int(a.id) else destination
		if close_drop:
			center += _fusion_direction * contact_lobe * _pitch * (-0.26 if int(cell.id) == int(a.id) else 0.14)
		droplet.position = center - droplet.size * 0.5
		var pull: float = sin(contact * PI) * 0.17
		droplet.deform(0.012 * sin(contact * PI), p * TAU, Vector2(1.0 + pull, 1.0 - pull * 0.7))
	if not reduced_motion:
		size_factor = lerpf(1.12, 1.28, union)
		opacity = union
		if p > 0.67:
			var vanish: float = smoothstep(0.67, 1.0, p)
			size_factor *= 1.0 - vanish * 0.8
			opacity = 1.0 - vanish
		var jelly: float = sin(p * PI * 6.0) * (1.0 - p) * 0.13
		stretch = Vector2(1.0 + jelly, 1.0 - jelly)
	_merged.size = Vector2.ONE * (_pitch - _gap) * size_factor
	_merged.position = destination - _merged.size * 0.5
	_merged.modulate.a = opacity
	_merged.deform(0.0 if reduced_motion else 0.018 * sin(p * PI), p * TAU * 2.0, stretch)
	_merged.set_support(0.0, maxf(0.0, 1.0 - stretch.y))
	_merged.show()
	_merged.visible = reduced_motion or union > 0.0

func _cue(cue: String) -> void:
	if _allowed():
		audio_requested.emit(cue)

func _chest_awarded(_count: int) -> void:
	if not reduced_motion:
		_loot_flights.append({"from": _fusion_origin, "elapsed": 0.0})
	_refresh_hud()

func _finished(result: Dictionary) -> void:
	cancel_input()
	_merged.hide()
	_refresh_controls()
	round_finished.emit(result.duplicate(true))
	_publish()

func _finish_round() -> void:
	if not _can_play() or _pointer != NO_POINTER:
		return
	cancel_input()
	game.finish_round()

func result_reveal() -> void:
	if not _configured or game.phase != "finished":
		return
	cancel_input()
	_result_visible = true
	_result_transition = false
	_result_elapsed = 0.0
	_result.show()
	_result_title.text = "Round results"
	_result_caption.text = "Score: %d · Chests: %d" % [game.score(), game.chest_count]
	chests_button.text = "Open chest" if int(game.chest_count) == 1 else "Open chests"
	_layout()
	_sync_tiles()
	_refresh_controls()
	_focus_result.call_deferred()
	_publish()

func _focus_result() -> void:
	if _result_visible and _allowed():
		default_focus().grab_focus()

func _open_chests() -> void:
	if not _allowed() or not _result_visible or _result_transition or int(game.chest_count) <= 0:
		return
	_result_transition = true
	_refresh_controls()
	chests_requested.emit()
	_publish()

func _replay() -> void:
	if not _allowed() or not _result_visible or _result_transition:
		return
	_result_transition = true
	_refresh_controls()
	replay_requested.emit()
	_publish()

func _refresh_hud() -> void:
	_loot_count.text = str(game.chest_count)
	_loot_count.set("accessibility_name", "%d chests collected" % game.chest_count)
	var state: Dictionary = game.snapshot()
	_next_tile.value = float(state.get("spawn_elapsed", 0.0)) / maxf(0.1, float(game.spawn_interval)) * 100.0
	_pace.text = "Next"
	var full: bool = float(game.full_elapsed) >= 0.0
	_notice.text = "Board full · %ds to make space" % maxi(1, ceili(float(state.get("full_remaining", 8.0)))) if full else "Match a picture to its word."
	if _compact_hud and full:
		_notice.text = "Make space\n%ds" % maxi(1, ceili(float(state.get("full_remaining", 8.0))))
	_notice.add_theme_color_override("font_color", Color("#733713") if full else Color("#315142"))
	_notice.visible = _configured and not _result_visible and (not _compact_hud or full)
	_pace.visible = _configured and not _result_visible
	_next_tile.visible = _configured and not _result_visible
	_loot_icon.visible = _configured
	_loot_count.visible = _configured
	_sync_preview()

func _refresh_controls() -> void:
	for cell: Dictionary in game.cells:
		if _tiles.has(int(cell.id)):
			_tiles[int(cell.id)].disabled = not _can_play() or not _settled(cell)
	chests_button.visible = _result_visible and int(game.chest_count) > 0
	replay_button.visible = _result_visible
	chests_button.disabled = not _allowed() or _result_transition
	replay_button.disabled = not _allowed() or _result_transition
	finish_button.visible = _configured and game.phase == "playing" and not _result_visible
	finish_button.disabled = not _can_play() or _pointer != NO_POINTER

func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if not _allowed():
		return controls
	if _result_visible:
		if int(game.chest_count) > 0:
			controls.append(chests_button)
		controls.append(replay_button)
	elif _can_play():
		var ordered: Array = game.cells.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.row) * 4 + int(a.column) < int(b.row) * 4 + int(b.column))
		for cell: Dictionary in ordered:
			if _settled(cell) and _tiles.has(int(cell.id)):
				controls.append(_tiles[int(cell.id)])
		if not finish_button.disabled:
			controls.append(finish_button)
	return controls

func default_focus() -> Control:
	var controls: Array[Control] = navigation_controls()
	return controls[0] if not controls.is_empty() else self

func _layout() -> void:
	if _loot_icon == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor: float = Style.ui_scale(self)
	var accent: Color = _theme.get("accent", Style.GOOD)
	Style.action_button(chests_button, accent, true)
	Style.action_button(replay_button, accent)
	var short_board: bool = size.y * scale_factor < 320.0
	var edge: float = (4.0 if short_board else 8.0) / scale_factor
	var wide: bool = short_board or size.x > size.y * 1.18
	_compact_hud = wide and size.x * scale_factor <= 400.0
	var side_space: float = minf(164.0 / scale_factor, size.x * 0.20) if wide else 0.0
	var available_height: float = size.y - edge * 2.0 if wide else size.y - 150.0 / scale_factor
	var available_width: float = size.x - edge * 2.0 - side_space * 2.0
	var board_height: float = maxf(60.0, minf(minf(available_height, available_width * 1.5), 684.0 / scale_factor))
	_board = Rect2(Vector2((size.x - board_height * 2.0 / 3.0) * 0.5, edge if wide else 88.0 / scale_factor), Vector2(board_height * 2.0 / 3.0, board_height))
	_falling_layer.position = _board.position
	_falling_layer.size = _board.size
	_pitch = board_height / 6.0
	_gap = maxf(2.0 / scale_factor, _pitch * 0.035)
	var hud_width: float = minf(160.0 / scale_factor, maxf(0.0, _board.position.x - edge * 2.0)) if wide else minf(110.0 / scale_factor, _board.size.x * 0.40)
	var hud_x: float = maxf(edge, _board.position.x - hud_width - edge) if wide else edge
	var hud_y: float = _board.position.y + 14.0 / scale_factor if wide else 20.0 / scale_factor
	_loot_icon.position = Vector2(hud_x, hud_y)
	_loot_icon.size = Vector2(44, 44) / scale_factor
	_loot_count.position = Vector2(hud_x + 46.0 / scale_factor, hud_y)
	_loot_count.size = Vector2(hud_width - 46.0 / scale_factor, 44.0 / scale_factor)
	_loot_count.add_theme_font_size_override("font_size", ceili(24 / scale_factor))
	_loot_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _compact_hud:
		_loot_icon.size = Vector2(40, 40) / scale_factor
		_loot_icon.position.x = hud_x + (hud_width - _loot_icon.size.x) * 0.5
		_loot_count.position = Vector2(hud_x, hud_y + 38.0 / scale_factor)
		_loot_count.size = Vector2(hud_width, 26.0 / scale_factor)
		_loot_count.add_theme_font_size_override("font_size", ceili(20 / scale_factor))
		_loot_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var preview_width: float = minf(112.0 / scale_factor, size.x - _board.end.x - edge * 2.0) if wide else minf(208.0 / scale_factor, size.x - 92.0 / scale_factor - edge * 2.0)
	var preview_x: float = _board.end.x + edge if wide else size.x - edge - preview_width
	var preview_y: float = _board.position.y if wide else 0.0
	var padding: float = 8.0 / scale_factor
	var preview_size: float = minf(minf(72.0 / scale_factor, preview_width - padding * 2.0), maxf(20.0 / scale_factor, (board_height - 94.0 / scale_factor) / 3.0)) if wide else minf(56.0 / scale_factor, (preview_width - padding * 2.0) / 3.0)
	if wide:
		preview_size = minf(preview_size, _pitch * 0.88)
	var preview_height: float = preview_size * 3.0 + 44.0 / scale_factor if wide else 78.0 / scale_factor
	_preview_rect = Rect2(Vector2(preview_x, preview_y), Vector2(preview_width, preview_height))
	_pace.position = _preview_rect.position + Vector2(padding, 2.0 / scale_factor)
	_pace.size = Vector2(preview_width - padding * 2.0, 20.0 / scale_factor)
	_pace.add_theme_font_size_override("font_size", ceili(12 / scale_factor))
	for index in range(_preview_tiles.size()):
		var preview: Tile = _preview_tiles[index]
		preview.size = Vector2.ONE * preview_size
		preview.position = _preview_rect.position + (Vector2((preview_width - preview_size) * 0.5, 22.0 / scale_factor + index * (preview_size + 4.0 / scale_factor)) if wide else Vector2(padding + index * preview_size, 17.0 / scale_factor))
	_next_tile.position = Vector2(preview_x + padding, _preview_rect.end.y - 8.0 / scale_factor)
	_next_tile.size = Vector2(preview_width - padding * 2.0, 4.0 / scale_factor)
	_notice.position = Vector2(_board.end.x + edge * 2.0, _preview_rect.end.y + 10.0 / scale_factor) if wide else Vector2(_board.position.x, _board.end.y + 7.0 / scale_factor)
	_notice.size = Vector2(maxf(0.0, size.x - _notice.position.x - edge), minf(size.y - _notice.position.y, 96.0 / scale_factor)) if wide else Vector2(maxf(0.0, _board.size.x - 92.0 / scale_factor), 44.0 / scale_factor)
	_notice.add_theme_font_size_override("font_size", ceili(14 / scale_factor))
	Style.action_button(finish_button, _theme.get("accent", Style.GOOD))
	finish_button.custom_minimum_size = Vector2(0, 44.0 / scale_factor)
	if _compact_hud:
		finish_button.add_theme_font_size_override("font_size", ceili(12 / scale_factor))
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			finish_button.get_theme_stylebox(state).content_margin_left = 6.0 / scale_factor
			finish_button.get_theme_stylebox(state).content_margin_right = 6.0 / scale_factor
	finish_button.position = Vector2(hud_x, _board.end.y - 48.0 / scale_factor) if wide else Vector2(_board.end.x - 84.0 / scale_factor, _board.end.y + 7.0 / scale_factor)
	finish_button.size = Vector2(hud_width if wide else 84.0 / scale_factor, 44.0 / scale_factor)
	_result.position = Vector2.ZERO
	_result.size = size
	_layout_result(scale_factor, edge)
	if _result_visible:
		_loot_icon.position = Vector2(edge, edge)
		_loot_count.position = Vector2(edge + 46.0 / scale_factor, edge)
	_sync_positions()
	_refresh_fusion()
	_refresh_hud()
	queue_redraw()
	_publish()

func _layout_result(s: float, edge: float) -> void:
	var w: float = size.x * s
	var h: float = size.y * s
	var count: int = mini(3, int(game.chest_count))
	var landscape: bool = w >= 600.0 and h < 300.0
	var compact: bool = h < 320.0
	var margin: float = edge * s
	var result_w: float = minf(w - margin * 2.0, 460.0)
	var result_x: float = (w - result_w) * 0.5
	var title_h: float = 32.0 if compact else 40.0
	var caption_h: float = 28.0 if compact else 36.0
	var gap: float = 4.0 if compact else 8.0
	var hero: float = minf(180.0 if w >= 600.0 else 140.0, result_w / maxf(1.0, float(count)))
	hero = minf(hero, maxf(0.0, h - 52.0 - title_h - caption_h - 48.0 - gap * 2.0 - 8.0)) if count > 0 else 0.0
	var total_h: float = title_h + caption_h + hero + gap * 2.0 + 48.0
	var top: float = maxf(52.0, (h - total_h) * 0.5)
	var hero_x: float = (w - hero * count) * 0.5
	var hero_y: float = top + title_h + caption_h + gap
	var action_y: float = hero_y + hero + gap
	if landscape:
		result_w = minf(w * 0.54 - margin, 440.0)
		result_x = w * 0.46
		top = maxf(margin, (h - title_h - caption_h - 48.0 - 12.0) * 0.5)
		hero = minf(180.0, minf(h - 60.0, (w * 0.44 - margin * 2.0) / maxf(1.0, float(count))))
		hero_x = (w * 0.44 - hero * count) * 0.5
		hero_y = 48.0 + (h - 48.0 - hero) * 0.5
		action_y = top + title_h + caption_h + 12.0
	_result_title.position = Vector2(result_x, top) / s
	_result_title.size = Vector2(result_w, title_h) / s
	_result_title.add_theme_font_size_override("font_size", ceili((24.0 if w < 350.0 else 28.0) / s))
	_result_caption.position = Vector2(result_x, top + title_h) / s
	_result_caption.size = Vector2(result_w, caption_h) / s
	_result_caption.add_theme_font_size_override("font_size", ceili((14.0 if compact else 16.0) / s))
	for index in range(_result_chests.size()):
		var image: TextureRect = _result_chests[index]
		image.visible = _result_visible and index < count
		image.size = Vector2.ONE * hero / s
		image.position = Vector2(hero_x + hero * index, hero_y) / s
	var action_w: float = (result_w - 10.0) * 0.5 if count > 0 else result_w
	chests_button.position = Vector2(result_x, action_y) / s
	chests_button.size = Vector2(action_w, 48.0) / s
	replay_button.position = Vector2(result_x + action_w + 10.0 if count > 0 else result_x, action_y) / s
	replay_button.size = Vector2(action_w, 48.0) / s

func _animate_result() -> void:
	for index in range(_result_chests.size()):
		var image: TextureRect = _result_chests[index]
		var p: float = clampf((_result_elapsed - index * 0.1) / 0.55, 0.0, 1.0)
		image.pivot_offset = image.size * Vector2(0.5, 0.85)
		image.scale = Vector2.ONE if reduced_motion else Vector2.ONE * (1.0 + sin(p * PI * 2.0) * (1.0 - p) * 0.14)
		image.modulate.a = 1.0 if reduced_motion else smoothstep(0.0, 0.2, p)

func danger_feedback() -> Dictionary:
	var active: bool = _can_play() and float(game.full_elapsed) >= 0.0
	var strength: float = 0.0
	if active:
		# The model emits a warning at this same second boundary. Keep a quiet
		# interval between bright frames, without flashing the learning content.
		var beat: float = fposmod(float(game.full_elapsed), 1.0)
		strength = 1.0 if reduced_motion else 1.0 - smoothstep(0.18, 0.55, beat)
	return {"active": active, "strength": strength}

func _draw() -> void:
	if not _configured or _result_visible:
		return
	var accent: Color = _theme.get("accent", Style.GOOD)
	var well := Style.box(Color("#fbfff9", 0.90), Color("#78a995", 0.64), 18, 2)
	well.shadow_color = Color("#2a6954", 0.13)
	well.shadow_size = ceili(10.0 / Style.ui_scale(self))
	well.shadow_offset = Vector2(0, 5.0 / Style.ui_scale(self))
	draw_style_box(well, _board.grow(2.0))
	draw_style_box(Style.box(Color("#fffdf5", 0.78), Color("#78a995", 0.30), 12, 1), _preview_rect)
	for column in range(1, JellyMatchModel.COLUMNS):
		var x: float = _board.position.x + float(column) * _pitch
		draw_line(Vector2(x, _board.position.y + 8.0), Vector2(x, _board.end.y - 8.0), Color(accent, 0.07), 1.0 / Style.ui_scale(self))
	var warning: Dictionary = danger_feedback()
	if float(warning.strength) > 0.0:
		var edge := Color(Color("#c65c35"), float(warning.strength))
		var width: int = maxi(2, ceili(4.0 / Style.ui_scale(self)))
		draw_style_box(Style.box(Color.TRANSPARENT, edge, 18, width), _board.grow(2.0))
	if _chest_texture != null:
		for flight: Dictionary in _loot_flights:
			var p: float = clampf(float(flight.elapsed) / 0.65, 0.0, 1.0)
			var destination: Vector2 = _loot_icon.position + _loot_icon.size * 0.5
			var center: Vector2 = Vector2(flight.from).lerp(destination, smoothstep(0.0, 1.0, p))
			center.y -= sin(p * PI) * 44.0 / Style.ui_scale(self)
			var edge_size: float = lerpf(_pitch * 0.60, _loot_icon.size.x, p)
			draw_texture_rect(_chest_texture, Rect2(center - Vector2.ONE * edge_size * 0.5, Vector2.ONE * edge_size), false)

func snapshot() -> Dictionary:
	var result: Dictionary = game.snapshot()
	result["visible"] = is_visible_in_tree() and _configured
	result["paused"] = _paused
	result["board_rect"] = _rect(_global_rect(_board))
	result["board_ratio"] = 2.0 / 3.0
	result["tiles"] = []
	for cell: Dictionary in game.cells:
		if not _tiles.has(int(cell.id)):
			continue
		var item: Dictionary = cell.duplicate(true)
		item["rect"] = _rect(_tiles[int(cell.id)].get_global_rect())
		item["settled"] = _settled(cell)
		item["visible"] = _tiles[int(cell.id)].is_visible_in_tree()
		item["focused"] = _tiles[int(cell.id)].has_focus()
		result.tiles.append(item)
	result["drag"] = {"active": _dragging, "pointer": _pointer, "source": _source, "target": _target, "selected": _selected}
	result["preview"] = {"visible": _pace.is_visible_in_tree(), "rect": _rect(_global_rect(_preview_rect)), "slots": []}
	for preview: Tile in _preview_tiles:
		result.preview.slots.append({"id": preview.tile_id, "rect": _rect(preview.get_global_rect()), "visible": preview.is_visible_in_tree()})
	result["landing_ghost"] = {"visible": _ghost.is_visible_in_tree(), "id": _ghost.tile_id, "rect": _rect(_ghost.get_global_rect())}
	result["fusion_rect"] = _rect(_merged.get_global_rect()) if _merged.visible else []
	result["loot"] = {"count": game.chest_count, "rect": _rect(_loot_icon.get_global_rect()), "flights": _loot_flights.size()}
	result["result"] = {"visible": _result_visible, "title": _result_title.text, "caption": _result_caption.text,
		"open": _control(chests_button), "replay": _control(replay_button)}
	result["finish"] = _control(finish_button)
	result["notice"] = _notice.text
	result["danger"] = danger_feedback()
	return result

func _global_rect(rect: Rect2) -> Rect2:
	return get_global_transform() * rect

func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _control(button: Button) -> Dictionary:
	return {"visible": button.is_visible_in_tree(), "disabled": button.disabled, "text": button.text, "rect": _rect(button.get_global_rect())}

func _publish() -> void:
	_publish_elapsed = 0.0
	var state: Dictionary = snapshot()
	var serialized: String = JSON.stringify(state)
	if serialized != _last_published:
		_last_published = serialized
		changed.emit(state)

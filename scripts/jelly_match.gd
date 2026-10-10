class_name JellyMatch
extends Control
const WordArt = preload("res://scripts/word_art.gd")
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
const FusionArt = preload("res://scripts/jelly_fusion.gd")
const Style = preload("res://scripts/ui_style.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Data = preload("res://scripts/game_data.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const LootMeter = preload("res://scripts/jelly_loot_meter.gd")
const ChestCelebration = preload("res://scripts/jelly_chest_celebration.gd")
const SURFACES := ["coral", "mint", "sky", "lilac"]
const NO_POINTER: int = -2147483648
const MOUSE_POINTER: int = -1

var game = JellyMatchModel.new()
var interaction_allowed: Callable
var reduced_motion: bool = false
var replay_button: Button
var chests_button: Button
var finish_button: Button
var drop_button: Button

var _configured: bool = false
var _generation: int = 0
var _paused: bool = false
var _theme: Dictionary = {}
var _manifest: Dictionary = {}
var _surfaces: Array[Texture2D] = []
var _pictures: Dictionary = {}
var _tiles: Dictionary = {}
var _falling_layer: Control
var _ghosts: Dictionary = {}
var _preview_tiles: Array[Tile] = []
var _preview_origins: Array[Vector2] = []
var _preview_rect := Rect2()
var _preview_first_id: int = -1
var _preview_canceled: bool = false
var _preview_pressed: bool = false
var _board := Rect2()
var _pitch: float = 0.0
var _gap: float = 0.0
var _compact_hud: bool = false
var _pointer: int = NO_POINTER
var _gesture_serial: int = 0
var _source: int = -1
var _target: int = -1
var _press_point := Vector2.ZERO
var _drag_point := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _dragging: bool = false
var _snapbacks: Dictionary = {}
var _fusion_visuals: Dictionary = {}
var _contact_elapsed: float = 0.0
var _rejection: Dictionary = {}
var _contact_label: Label
var _contact_label_kind: String = ""
var _loot_flights: Array[Dictionary] = []
var _loot_icon: TextureRect
var _loot_meter: LootMeter
var _loot_detail: Label
var _reward_presentation: ChestCelebration
var _displayed_chest_tier: int = 0
var _notice: Label
var _result: Control
var _result_title: Label
var _result_caption: Label
var _result_chests: Array[TextureRect] = []
var _result_visible: bool = false
var _result_transition: bool = false
var _pending_chests: int = 0
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
	_contact_label = _label(self, "", 14)
	_contact_label.name = "JellyContactFeedback"
	_contact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contact_label.z_index = 50
	_contact_label.hide()
	_loot_meter = LootMeter.new()
	add_child(_loot_meter)
	_loot_icon = _image(self)
	_loot_detail = _label(self, "Fragments", 11)
	_loot_detail.name = "JellyFragmentProgress"
	drop_button = Button.new()
	drop_button.name = "JellyDropNow"
	drop_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_button.focus_mode = Control.FOCUS_ALL
	drop_button.set("accessibility_name", "Drop the next jellies")
	drop_button.tooltip_text = "Drop the next jellies"
	drop_button.pressed.connect(_drop_next)
	add_child(drop_button)
	for index in range(JellyMatchModel.UPCOMING_COUNT):
		var preview := Tile.new()
		preview.name = "UpcomingJelly%d" % (index + 1)
		preview.z_index = 1
		preview.disabled = true
		preview.focus_mode = Control.FOCUS_NONE
		add_child(preview)
		_preview_tiles.append(preview)
		_preview_origins.append(Vector2.ZERO)
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
	for index in range(1):
		_result_chests.append(_image(_result))
	_reward_presentation = ChestCelebration.new()
	add_child(_reward_presentation)
	_reward_presentation.cue_requested.connect(_reward_cue)
	chests_button = _button("Open chests", "JellyOpenChests", _open_chests)
	replay_button = _button("Play again", "JellyReplay", _replay)
	finish_button = Button.new()
	finish_button.name = "JellyFinish"
	finish_button.text = "Finish"
	finish_button.expand_icon = true
	finish_button.tooltip_text = "Finish this round and see your score"
	UiClick.bind_button(finish_button)
	finish_button.pressed.connect(_finish_round)
	add_child(finish_button)
	game.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		word_attempted.emit(id, ids, correct))
	game.cue_requested.connect(_cue)
	game.fusion_completed.connect(_fusion_completed)
	game.chest_milestone.connect(_chest_milestone)
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
	_displayed_chest_tier = 0
	_loot_meter.reset()
	_result_visible = false
	_result_transition = false
	_result_elapsed = 0.0
	_publish_elapsed = 0.0
	_landing_cooldown = 0.0
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
	Style.action_button(chests_button, accent, true)
	Style.action_button(replay_button, accent)
	_style_finish_button()
	for id in _tiles:
		_configure_tile(_tiles[id], _cell(int(id)))
	for visual: Dictionary in _fusion_visuals.values():
		visual.merged.tile_id = -1
	for ghost: Tile in _ghosts.values():
		ghost.tile_id = -1
	for preview: Tile in _preview_tiles:
		preview.tile_id = -1
	queue_redraw()

func _prepare_chest() -> void:
	if _theme.is_empty() or _manifest.is_empty() or not is_inside_tree():
		return
	var id: String = str(_theme.get("id", "spring"))
	_apply_chest_texture(_chest_for_theme(id))
	# Warm the first reward before its four pieces come together.
	_chest_for_theme(RewardProgress.theme_for_tier(maxi(1, game.chest_tier)))
	_chest_for_theme(RewardProgress.theme_for_tier(maxi(2, game.chest_tier + 1)))

func _chest_for_theme(id: String) -> Texture2D:
	if _manifest.is_empty() or not is_inside_tree():
		return null
	if not _chest_cache.has(id):
		var viewport := SubViewport.new()
		viewport.name = "JellyChest_" + id
		viewport.size = Vector2i(768, 768)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var art := Chest.new()
		viewport.add_child(art)
		art.size = Vector2(768, 768)
		art.reduced_motion = true
		art.configure_skin(Data.theme(id), _manifest)
		_chest_cache[id] = {"viewport": viewport, "art": art, "frames": 0, "texture": viewport.get_texture(), "cropped": false}
	return _chest_cache[id].texture

func _reward_texture(tier: int = -1) -> Texture2D:
	return _chest_for_theme(RewardProgress.theme_for_tier(game.chest_tier if tier < 0 else tier))

func _apply_chest_texture(texture: Texture2D) -> void:
	_chest_texture = texture
	_loot_icon.texture = _reward_texture()
	for chest: TextureRect in _result_chests:
		chest.texture = _reward_texture()
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
	_reward_presentation.reduced_motion = value
	_reward_presentation._sync()
	_snapbacks.clear()
	_loot_flights.clear()
	_refresh_hud()
	_loot_meter.settle()
	_sync_tiles()
	_sync_preview()
	_refresh_fusion()
	_refresh_contact()
	_animate_result()
	queue_redraw()
	_publish()

func pause(value: bool = true) -> void:
	if _paused == value:
		return
	_paused = value
	game.set_paused(value or (_reward_presentation.is_active() and game.fusions.is_empty()))
	cancel_input()
	if not value:
		_result_transition = false
	_refresh_controls()
	_publish()

func settle() -> void:
	cancel_input()
	_snapbacks.clear()
	_loot_flights.clear()
	_refresh_hud()
	_loot_meter.settle()
	_sync_tiles()
	_refresh_fusion()
	queue_redraw()
	_publish()

func stop() -> void:
	_generation += 1
	_reward_presentation.clear()
	_configured = false
	game.paused = true
	settle()
	_result_visible = false
	_result.hide()
	_clear_fusion_visuals()
	for ghost: Tile in _ghosts.values():
		ghost.hide()
		ghost.queue_free()
	_ghosts.clear()
	for preview: Tile in _preview_tiles:
		preview.hide()
		preview._picture.texture = null
		preview.tile_id = -1
	for tile in _tiles.values():
		tile.hide()
		tile.queue_free()
	_tiles.clear()
	# WordArt keeps weak references; this round cache must not retain every
	# previously encountered word's poster after leaving or restarting.
	_pictures.clear()
	_refresh_controls()
	_refresh_hud()
	_publish()

func cancel_input() -> void:
	_pointer = NO_POINTER
	_preview_first_id = -1
	_preview_canceled = false
	_set_preview_pressed(false)
	_source = -1
	_target = -1
	_dragging = false
	_contact_elapsed = 0.0
	_rejection.clear()
	_gesture_serial += 1
	_refresh_marks()
	_sync_positions()
	_refresh_fusion()
	_refresh_contact()
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _contact_label != null:
		cancel_input()

func _allowed() -> bool:
	return _configured and not _paused and is_visible_in_tree() and (not interaction_allowed.is_valid() or bool(interaction_allowed.call()))

func _can_play() -> bool:
	return _allowed() and game.phase == "playing" and not _result_visible \
		and not (_reward_presentation.is_active() and game.fusions.is_empty())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _pointer != NO_POINTER:
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
	if _preview_rect.has_point(point):
		if not game.can_drop_now():
			return false
		_pointer = pointer
		_gesture_serial += 1
		_preview_first_id = int(game.upcoming[0].id)
		_preview_canceled = false
		_press_point = point
		_set_preview_pressed(true)
		_publish()
		return true
	var id: int = _tile_at(point)
	if id < 0:
		return false
	_pointer = pointer
	_gesture_serial += 1
	_source = id
	_target = -1
	_contact_elapsed = 0.0
	_rejection.clear()
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
	if _preview_first_id >= 0:
		var point: Vector2 = get_global_transform().affine_inverse() * global_point
		_preview_canceled = _preview_canceled or not _preview_rect.has_point(point) \
			or point.distance_to(_press_point) * Style.ui_scale(self) > 12.0
		_set_preview_pressed(not _preview_canceled and game.can_drop_now() and int(game.upcoming[0].id) == _preview_first_id)
		return
	if _source < 0 or not _tiles.has(_source):
		cancel_input()
		return
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	_drag_point = point
	if point.distance_to(_press_point) * Style.ui_scale(self) > 7.0:
		_dragging = true
	if not _dragging:
		return
	_tiles[_source].position = point - _drag_offset
	_tiles[_source].z_index = 40
	var target: int = _tile_at(point, _source)
	if target != _target:
		_contact_elapsed = 0.0
	_target = target
	_refresh_marks()
	_sync_positions()
	_refresh_fusion()
	_publish()

func _release(global_point: Vector2) -> void:
	if _preview_first_id >= 0:
		var expected_id: int = _preview_first_id
		var generation: int = _generation
		var point: Vector2 = get_global_transform().affine_inverse() * global_point
		var accepted: bool = not _preview_canceled and _preview_rect.has_point(point) \
			and point.distance_to(_press_point) * Style.ui_scale(self) <= 12.0
		cancel_input()
		if accepted and generation == _generation:
			_drop_next(expected_id)
		return
	if not _can_play() or _source < 0:
		cancel_input()
		return
	var generation: int = _generation
	var source: int = _source
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	var target: int = _tile_at(point, source) if _dragging else -1
	var from: Vector2 = _tiles[source].position if _tiles.has(source) else Vector2.ZERO
	var dragged: bool = _dragging
	var held: Dictionary = _contact_state()
	_pointer = NO_POINTER
	_source = -1
	_target = -1
	_dragging = false
	_gesture_serial += 1
	if dragged:
		if target >= 0:
			_merge(source, target, from, held, true)
		else:
			_snap_back(source, from)
			audio_requested.emit("release")
	if generation != _generation or not _allowed():
		return
	_refresh_marks()
	_publish()

func _drop_next(expected_first_id: int = -1) -> void:
	if not _can_play() or _pointer != NO_POINTER:
		return
	var generation: int = _generation
	if not game.drop_now(expected_first_id):
		return
	if generation != _generation or not _can_play():
		return
	_sync_tiles()
	_refresh_hud()
	queue_redraw()
	_publish()
	if generation == _generation and _can_play():
		audio_requested.emit("pick")

func _activate(id: int) -> void:
	# Keyboard/controller activation is pronunciation only. Pointer presses
	# already read the word; only a completed drag can submit a pair.
	if not _can_play() or _pointer != NO_POINTER or not _settled(_cell(id)):
		return
	var generation: int = _generation
	word_requested.emit(_cell(id).word.duplicate(true))
	if generation != _generation or not _can_play():
		return
	audio_requested.emit("pick")

func _merge(first: int, second: int, from: Vector2, held: Dictionary = {}, held_source: bool = false) -> void:
	var generation: int = _generation
	# A source grabbed while settled stays in the hand if an earlier clear moves
	# its resting row. The destination must still be an available, settled tile.
	var result: String = game.try_merge(first, second, held_source)
	if generation != _generation or not _configured or game.phase != "playing":
		return
	if result == "correct":
		for fusion: Dictionary in game.fusions:
			if int(fusion.a_id) == first and int(fusion.b_id) == second:
				var visual: Dictionary = _ensure_fusion_visual(fusion)
				visual.start = from + _tile_rect(fusion.a).size * 0.5
				if held.get("kind", "none") == "match" and not Vector2(held.direction).is_zero_approx():
					visual.direction = Vector2(held.direction)
				visual.contact_strength = lerpf(0.35, 1.0, smoothstep(0.0, 0.14, _contact_elapsed))
				break
		_snapbacks.erase(first)
		_snapbacks.erase(second)
		_rejection.clear()
	else:
		if result == "wrong":
			var direction: Vector2 = (_tile_rect(_cell(second)).get_center() - _tile_rect(_cell(first)).get_center()).normalized()
			_rejection = {"a": first, "b": second, "elapsed": 0.0, "direction": direction}
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
	return game.is_settled(cell) and not game.is_fusing(int(cell.id))

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
		_pictures[path] = WordArt.texture(path)
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

func _tile_rect(cell: Dictionary) -> Rect2:
	return Rect2(_board.position + Vector2(int(cell.column), int(cell.row)) * _pitch + Vector2.ONE * _gap * 0.5,
		Vector2.ONE * (_pitch - _gap))

func _sync_positions() -> void:
	var airborne_ids: Dictionary = {}
	for cell: Dictionary in game.cells:
		var id: int = int(cell.id)
		if not _tiles.has(id):
			continue
		var tile: Tile = _tiles[id]
		tile._surface.visible = true
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
			airborne_ids[id] = true
			if not _ghosts.has(id):
				var projection := Tile.new()
				projection.name = "LandingProjection_%d" % id
				projection.disabled = true
				projection.focus_mode = Control.FOCUS_NONE
				projection.modulate = Color(0.65, 0.82, 0.75, 0.28)
				add_child(projection)
				_ghosts[id] = projection
			var ghost: Tile = _ghosts[id]
			if ghost.tile_id != id:
				_configure_tile(ghost, cell)
				ghost.set_projection(true)
			ghost.position = rect.position
			ghost.size = rect.size
			ghost.show()
	for id in _ghosts.keys():
		if not airborne_ids.has(id):
			_ghosts[id].hide()
			_ghosts[id].queue_free()
			_ghosts.erase(id)
	if _dragging:
		# A completed pair can move a destination without another pointer event.
		var target: int = _tile_at(_drag_point, _source)
		if target != _target:
			_target = target
			_contact_elapsed = 0.0
			_refresh_marks()
	_refresh_contact()

func _sync_preview() -> void:
	for index in range(_preview_tiles.size()):
		var preview: Tile = _preview_tiles[index]
		preview.visible = _configured and not _result_visible and index < game.upcoming.size()
		if not preview.visible:
			continue
		var item: Dictionary = game.upcoming[index]
		if preview.tile_id != int(item.id):
			_configure_tile(preview, item)
			preview.set("accessibility_name", "Upcoming %d: %s %s" % [index + 1, str(item.kind), str(item.word.text)])
		var pose: Dictionary = _preview_pose(index)
		preview.position = _preview_origins[index]
		preview.deform(0.0, 0.0)
		preview.set_preview_pressure(float(pose.pressure), float(pose.sway))

func _preview_pose(index: int) -> Dictionary:
	return Motion.preview(game.spawn_elapsed, game.spawn_interval, index,
		reduced_motion or game.phase != "playing" or game.cells.size() >= JellyMatchModel.CAPACITY)

func _refresh_marks() -> void:
	var feedback_enabled: bool = _can_play()
	for id in _tiles:
		_tiles[id].set_marked(int(id) == _target, int(id) == _source, feedback_enabled and not game.is_fusing(int(id)), reduced_motion)
	_refresh_contact()

func _contact_state() -> Dictionary:
	var state := {"kind": "none", "source": -1, "target": -1, "strength": 0.0, "direction": Vector2.ZERO}
	if not _can_play():
		return state
	if not _rejection.is_empty():
		state.merge({"kind": "mismatch", "source": int(_rejection.a), "target": int(_rejection.b),
			"strength": sin(clampf(float(_rejection.elapsed) / 0.34, 0.0, 1.0) * PI), "direction": _rejection.direction}, true)
		return state
	if not _dragging or _source < 0 or _target < 0:
		return state
	var a: Dictionary = _cell(_source)
	var b: Dictionary = _cell(_target)
	if a.is_empty() or b.is_empty() or game.is_fusing(_source) or not _settled(b):
		return state
	var matching: bool = a.word.id == b.word.id and a.kind != b.kind
	var direction: Vector2 = (_tile_rect(b).get_center() - (_tiles[_source].position + _tiles[_source].size * 0.5)).normalized()
	if direction.length_squared() < 0.1:
		direction = (_tile_rect(b).get_center() - _tile_rect(a).get_center()).normalized()
	state.merge({"kind": "match" if matching else "mismatch", "source": _source, "target": _target,
		"strength": lerpf(0.35, 1.0, smoothstep(0.0, 0.14, _contact_elapsed)), "direction": direction}, true)
	return state

func _refresh_contact() -> void:
	var state: Dictionary = _contact_state()
	for id in _tiles:
		var involved: bool = int(id) == int(state.source) or int(id) == int(state.target)
		var direction: Vector2 = Vector2(state.direction) * (1.0 if int(id) == int(state.source) else -1.0)
		_tiles[id].set_contact(str(state.kind) if involved else "none", direction, float(state.strength) if involved else 0.0, reduced_motion)
	_contact_label.visible = state.kind != "none"
	if not _contact_label.visible:
		return
	var good: bool = state.kind == "match"
	var s: float = Style.ui_scale(self)
	_contact_label.add_theme_font_size_override("font_size", ceili(13.0 / s))
	if _contact_label_kind != str(state.kind):
		_contact_label_kind = str(state.kind)
		_contact_label.text = "Match!" if good else "Try another"
		_contact_label.add_theme_color_override("font_color", Color("#17604a") if good else Color("#923e43"))
		_contact_label.add_theme_stylebox_override("normal", Style.box(Color("#edfff3") if good else Color("#fff0ea"), Color("#76bb97") if good else Color("#d99288"), 9, 1))
	_contact_label.size = Vector2(72.0 if good else 104.0, 25.0) / s
	var destination: Vector2 = _tile_rect(_cell(int(state.target))).get_center()
	_contact_label.position = destination - Vector2(_contact_label.size.x * 0.5, _pitch * 0.57 + _contact_label.size.y)
	_contact_label.position.x = clampf(_contact_label.position.x, _board.position.x, _board.end.x - _contact_label.size.x)
	_contact_label.position.y = maxf(_board.position.y, _contact_label.position.y)

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
	if _dragging and _target >= 0:
		_contact_elapsed += delta
	if not _rejection.is_empty():
		_rejection.elapsed += delta
		if float(_rejection.elapsed) >= 0.34:
			_rejection.clear()
	var remaining: float = delta
	if _reward_presentation.is_active() and game.fusions.is_empty():
		remaining = advance_reward_presentation(delta)
	if generation != _generation or not _allowed():
		return
	if game.phase == "playing" and (not _reward_presentation.is_active() or not game.fusions.is_empty()):
		game.step(remaining)
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
	_loot_meter.advance(delta)
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

func _ensure_fusion_visual(fusion: Dictionary) -> Dictionary:
	var id: String = str(fusion.attempt_id)
	if not _fusion_visuals.has(id):
		var art := FusionArt.new()
		art.name = "GelUnion_" + id
		art.z_index = 25
		add_child(art)
		art.configure(SURFACES, int(fusion.a_id), int(fusion.b_id), _surfaces[posmod(int(fusion.b_id), _surfaces.size())])
		var merged := Tile.new()
		merged.name = "FusedJelly_" + id
		merged.focus_mode = Control.FOCUS_NONE
		merged.disabled = true
		merged.z_index = 30
		merged._shadow.z_index = -10
		add_child(merged)
		merged.hide()
		_fusion_visuals[id] = {"art": art, "merged": merged,
			"start": _tile_rect(fusion.a).get_center(),
			"direction": (_tile_rect(fusion.b).get_center() - _tile_rect(fusion.a).get_center()).normalized(),
			"contact_strength": 0.0}
	return _fusion_visuals[id]

func _remove_fusion_visual(id: String) -> void:
	var visual: Dictionary = _fusion_visuals[id]
	for node: Control in [visual.art, visual.merged]:
		node.hide()
		node.queue_free()
	_fusion_visuals.erase(id)

func _clear_fusion_visuals() -> void:
	for id: String in _fusion_visuals.keys():
		_remove_fusion_visual(id)

func _refresh_fusion() -> void:
	if not _configured or _result_visible or game.phase != "playing":
		_clear_fusion_visuals()
		return
	var live: Dictionary = {}
	for fusion: Dictionary in game.fusions:
		live[str(fusion.attempt_id)] = true
		_pose_fusion(fusion, _ensure_fusion_visual(fusion))
	for id: String in _fusion_visuals.keys():
		if not live.has(id):
			_remove_fusion_visual(id)

func _pose_fusion(fusion: Dictionary, visual: Dictionary) -> void:
	var merged: Tile = visual.merged
	var art: Control = visual.art
	var p: float = clampf(float(fusion.elapsed) / float(fusion.duration), 0.0, 1.0)
	var a: Dictionary = fusion.a
	var b: Dictionary = fusion.b
	var destination: Vector2 = _tile_rect(b).get_center()
	if merged.tile_id != int(b.id):
		_configure_tile(merged, b, true)
	var unit: float = _pitch - _gap
	var size_factor: float = 1.28
	var stretch := Vector2.ONE
	var contact: float = smoothstep(0.0, 0.30, p)
	var union: float = smoothstep(0.24, 0.38, p)
	var close_drop: bool = Vector2(visual.start).distance_to(destination) < _pitch * 0.4
	var contact_lobe: float = sin(clampf(p / 0.27, 0.0, 1.0) * PI) if close_drop else 0.0
	var held_separation: float = float(visual.contact_strength) * unit * 0.25 * (1.0 - smoothstep(0.0, 0.27, p)) if close_drop else 0.0
	var first_center: Vector2 = Vector2(visual.start).lerp(destination, contact)
	var second_center: Vector2 = destination
	if close_drop:
		first_center -= Vector2(visual.direction) * (contact_lobe * _pitch * 0.17 + held_separation)
		second_center += Vector2(visual.direction) * (contact_lobe * _pitch * 0.12 + held_separation)
	for cell: Dictionary in [a, b]:
		if not _tiles.has(int(cell.id)):
			continue
		var droplet: Tile = _tiles[int(cell.id)]
		droplet.set_support(0.0, 0.0, false)
		droplet.visible = not reduced_motion and p < 0.38
		droplet._surface.hide()
		droplet.modulate.a = 1.0 - union
		droplet.z_index = 28 if int(cell.id) == int(a.id) else 27
		var center: Vector2 = first_center if int(cell.id) == int(a.id) else second_center
		droplet.position = center - droplet.size * 0.5
		droplet.deform(0.0, 0.0)
	var compression: float = smoothstep(0.54, 2.0 / 3.0, p)
	var release: float = clampf((p - 2.0 / 3.0) * 3.0, 0.0, 1.0)
	var body_opacity: float = 1.0
	var content_opacity: float = 1.0
	var rise: float = 0.0
	if not reduced_motion:
		size_factor = lerpf(1.0, 1.28, union)
		content_opacity = union
		var settle: float = sin(clampf((p - 0.30) / 0.24, 0.0, 1.0) * TAU) * (1.0 - smoothstep(0.30, 0.54, p)) * 0.10
		stretch = Vector2(1.0 + settle + compression * 0.20, 1.0 - settle - compression * 0.22)
		if release > 0.0:
			var snap: float = smoothstep(0.0, 0.24, release)
			var retract: float = smoothstep(0.20, 0.88, release)
			stretch = Vector2(lerpf(1.20, 0.74, snap), lerpf(0.78, 1.42, snap)) * lerpf(1.0, 0.05, retract)
			rise = unit * (0.18 * snap + 0.15 * retract)
			body_opacity = 1.0 - smoothstep(0.66, 0.92, release)
			content_opacity *= 1.0 - smoothstep(0.04, 0.44, release)
		var extent: Vector2 = Vector2.ONE * unit * size_factor * stretch
		# The same two painted lobes become one surface; no sprite crossfade at the seam.
		art.pose(first_center - Vector2(0, rise), second_center - Vector2(0, rise), destination,
			extent, unit, p, union, compression * (1.0 - release), release, body_opacity)
	else:
		art.hide()
	merged._surface.visible = reduced_motion
	merged.size = Vector2.ONE * unit * size_factor
	merged.position = destination - merged.size * 0.5 - Vector2(0, rise * 0.65)
	merged.modulate.a = content_opacity
	merged.deform(0.0, 0.0, Vector2.ONE if reduced_motion else stretch)
	merged.set_support(0.0, maxf(0.0, 1.0 - stretch.y))
	merged._shadow.modulate.a *= body_opacity
	merged.visible = reduced_motion or union > 0.0

func _cue(cue: String) -> void:
	if _allowed():
		audio_requested.emit(cue)

func _reward_cue(cue: String) -> void:
	if cue == "reward":
		_displayed_chest_tier = int(_reward_presentation.snapshot().tier)
		_refresh_hud()
	_cue(cue)

func _fusion_completed(fusion: Dictionary, awarded: int) -> void:
	if not _configured:
		return
	var generation: int = _generation
	_cue("danger_end")
	if generation != _generation or not _configured or game.phase != "playing":
		return
	if awarded > 0 and not reduced_motion:
		_loot_flights.append({"from": _tile_rect(fusion.b).get_center(), "elapsed": 0.0, "amount": awarded})
	if _reward_presentation.is_active() and game.fusions.is_empty():
		cancel_input()
		if generation != _generation or not _configured or game.phase != "playing":
			return
		game.set_paused(true)
	_refresh_hud()

func _chest_milestone(previous_tier: int, tier: int) -> void:
	if not _configured or game.phase != "playing":
		return
	var generation: int = _generation
	if game.fusions.is_empty():
		cancel_input()
		if generation != _generation or not _configured or game.phase != "playing":
			return
	_reward_presentation.reduced_motion = reduced_motion
	_reward_presentation.enqueue(previous_tier, tier, _reward_texture(previous_tier), _reward_texture(tier))
	game.set_paused(game.fusions.is_empty())
	_chest_for_theme(RewardProgress.theme_for_tier(tier + 1))
	_refresh_hud()
	_refresh_controls()
	_publish()

func advance_reward_presentation(delta: float) -> float:
	if not _allowed() or not game.fusions.is_empty():
		return 0.0
	var generation: int = _generation
	var remaining: float = _reward_presentation.advance(delta)
	if generation != _generation or not _allowed():
		return 0.0
	game.set_paused(_paused or _reward_presentation.is_active())
	_refresh_controls()
	return remaining

func _finished(result: Dictionary) -> void:
	cancel_input()
	_reward_presentation.clear()
	_displayed_chest_tier = game.chest_tier
	_clear_fusion_visuals()
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
	_result_caption.text = "Score: %d · Chest Lv. %d" % [game.score(), game.chest_tier] if game.chest_count > 0 else \
		"Score: %d · Fragments: %d / 4" % [game.score(), game.fragment_count]
	for chest: TextureRect in _result_chests:
		chest.texture = _reward_texture()
	chests_button.text = "Open chest" if maxi(game.chest_count, _pending_chests) == 1 else "Open chests"
	_layout()
	_sync_tiles()
	_refresh_controls()
	_focus_result.call_deferred()
	_publish()

func _focus_result() -> void:
	if _result_visible and _allowed():
		default_focus().grab_focus()

func _open_chests() -> void:
	if not _allowed() or not _result_visible or _result_transition or maxi(game.chest_count, _pending_chests) <= 0:
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
	var progress: Dictionary = game.reward_progress(game.fragment_count)
	var displayed_tier: int = _displayed_chest_tier
	var arrived: int = game.fragment_count
	for flight: Dictionary in _loot_flights:
		arrived -= int(flight.get("amount", 1))
	var base: int = 4 + (displayed_tier - 1) * 5 if displayed_tier > 0 else 0
	_loot_meter.set_progress(maxi(0, arrived - base), 5 if displayed_tier > 0 else 4, reduced_motion)
	_loot_detail.text = "Upgrade chest" if displayed_tier > 0 else "Unlock chest"
	_loot_meter.set("accessibility_name", "%d fragments. Chest level %d. %d of %d toward the next reward." % [game.fragment_count, game.chest_tier, progress.fragments_toward_next, progress.fragments_required])
	_loot_icon.texture = _reward_texture(displayed_tier)
	_loot_icon.modulate.a = 1.0 if displayed_tier > 0 else 0.72
	var state: Dictionary = game.snapshot()
	var full: bool = float(game.full_elapsed) >= 0.0
	_notice.text = "Board full · %ds to make space" % maxi(1, ceili(float(state.get("full_remaining", 8.0)))) if full else "Match a picture to its word."
	if _compact_hud and full:
		_notice.text = "Make space\n%ds" % maxi(1, ceili(float(state.get("full_remaining", 8.0))))
	_notice.add_theme_color_override("font_color", Color("#733713") if full else Color("#315142"))
	_notice.visible = _configured and not _result_visible and (not _compact_hud or full)
	_loot_icon.visible = _configured and not _result_visible
	_loot_meter.visible = _configured and not _result_visible
	_loot_detail.visible = _configured and not _result_visible
	_sync_preview()

func set_pending_chests(count: int) -> void:
	if _pending_chests == count:
		return
	_pending_chests = count
	chests_button.text = "Open chest" if maxi(game.chest_count, _pending_chests) == 1 else "Open chests"
	_refresh_controls()
	_layout()
	_publish()

func _refresh_controls() -> void:
	for cell: Dictionary in game.cells:
		if _tiles.has(int(cell.id)):
			_tiles[int(cell.id)].disabled = not _can_play() or not _settled(cell)
	chests_button.visible = _result_visible and maxi(game.chest_count, _pending_chests) > 0
	replay_button.visible = _result_visible
	chests_button.disabled = not _allowed() or _result_transition
	replay_button.disabled = not _allowed() or _result_transition
	finish_button.visible = _configured and game.phase == "playing" and not _result_visible
	finish_button.disabled = not _can_play() or _pointer != NO_POINTER
	drop_button.visible = _configured and game.phase == "playing" and not _result_visible
	drop_button.disabled = not _can_play() or not game.can_drop_now() or (_pointer != NO_POINTER and _preview_first_id < 0)
	if drop_button.disabled:
		_set_preview_pressed(false)

func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if not _allowed():
		return controls
	if _result_visible:
		if maxi(game.chest_count, _pending_chests) > 0:
			controls.append(chests_button)
		controls.append(replay_button)
	elif _can_play():
		var ordered: Array = game.cells.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.row) * 4 + int(a.column) < int(b.row) * 4 + int(b.column))
		for cell: Dictionary in ordered:
			if _settled(cell) and _tiles.has(int(cell.id)):
				controls.append(_tiles[int(cell.id)])
		if not drop_button.disabled:
			controls.append(drop_button)
		if not finish_button.disabled:
			controls.append(finish_button)
	return controls

func default_focus() -> Control:
	var controls: Array[Control] = navigation_controls()
	return controls[0] if not controls.is_empty() else self

func _style_drop_button() -> void:
	var s: float = Style.ui_scale(self)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var pressed: bool = state == "pressed"
		var surface := Style.box(Color("#e7f4df", 0.94) if pressed else Color("#fffdf5", 0.78),
			Color("#578f69", 0.72) if pressed else Color("#78a995", 0.30), ceili(12.0 / s), maxi(1, roundi(1.0 / s)))
		drop_button.add_theme_stylebox_override(state, surface)
	var focus := Style.box(Color.TRANSPARENT, Style.GOOD, ceili(12.0 / s), maxi(2, roundi(2.0 / s)))
	focus.set_expand_margin_all(2.0 / s)
	drop_button.add_theme_stylebox_override("focus", focus)
	drop_button.add_theme_stylebox_override("hover_pressed", drop_button.get_theme_stylebox("pressed"))
	_set_preview_pressed(_preview_pressed, true)

func _set_preview_pressed(value: bool, force: bool = false) -> void:
	if value == _preview_pressed and not force:
		return
	_preview_pressed = value
	# Pointer ownership lives in _input, so paint momentary feedback explicitly.
	# BaseButton.set_pressed_no_signal only applies to toggle buttons.
	drop_button.add_theme_stylebox_override("normal", drop_button.get_theme_stylebox("pressed" if value else "disabled"))

func _style_finish_button() -> void:
	var s: float = Style.ui_scale(self)
	var ink := Color("#514731")
	Style.action_button(finish_button, ink)
	finish_button.icon = null if _compact_hud else preload("res://assets/images/ui/finish-flag.svg")
	finish_button.custom_minimum_size = Vector2(0, 44.0 / s)
	finish_button.add_theme_font_size_override("font_size", ceili((12.0 if _compact_hud else 14.0) / s))
	finish_button.add_theme_constant_override("icon_max_width", ceili((16.0 if _compact_hud else 20.0) / s))
	finish_button.add_theme_constant_override("h_separation", ceili((4.0 if _compact_hud else 6.0) / s))
	var fills := {"normal": Color("#fff5dc"), "hover": Color("#fff9e9"),
		"pressed": Color("#efdfbb"), "disabled": Color("#e7e9dc")}
	for state: String in fills:
		var pressed: bool = state == "pressed"
		var inactive: bool = state == "disabled"
		var surface := Style.box(fills[state], Color("#c5b489") if not inactive else Color("#ced4c7"), ceili(22.0 / s), maxi(1, roundi(1.0 / s)))
		surface.border_width_bottom = maxi(1, roundi((1.0 if pressed or inactive else 3.0) / s))
		surface.shadow_color = Color("#294834", 0.0 if pressed or inactive else 0.12)
		surface.shadow_size = ceili(3.0 / s)
		surface.shadow_offset = Vector2(0, 2.0 / s)
		surface.content_margin_left = (6.0 if _compact_hud else 12.0) / s
		surface.content_margin_right = surface.content_margin_left
		surface.content_margin_top = (10.0 if pressed else 7.0) / s
		surface.content_margin_bottom = (4.0 if pressed else 7.0) / s
		finish_button.add_theme_stylebox_override(state, surface)
	var focus := Style.box(Color.TRANSPARENT, Style.GOOD, ceili(25.0 / s), maxi(2, roundi(2.0 / s)))
	focus.set_expand_margin_all(3.0 / s)
	finish_button.add_theme_stylebox_override("focus", focus)
	for state: String in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		var color: Color = Color("#8a927e") if state == "disabled" else ink
		finish_button.add_theme_color_override("font_color" if state == "normal" else "font_%s_color" % state, color)
		finish_button.add_theme_color_override("icon_%s_color" % state, color)

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
	var hud_y: float = _board.position.y + 14.0 / scale_factor if wide else 0.0
	var meter_edge: float = minf(64.0 / scale_factor, hud_width)
	_loot_meter.position = Vector2(hud_x + (hud_width - meter_edge) * 0.5, hud_y)
	_loot_meter.size = Vector2.ONE * meter_edge
	_loot_icon.size = Vector2.ONE * meter_edge * 0.67
	_loot_icon.position = _loot_meter.position + (_loot_meter.size - _loot_icon.size) * 0.5
	_loot_detail.position = Vector2(hud_x, hud_y + meter_edge + 2.0 / scale_factor)
	_loot_detail.size = Vector2(hud_width, 17.0 / scale_factor)
	_loot_detail.add_theme_font_size_override("font_size", ceili(11.0 / scale_factor))
	_loot_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _compact_hud:
		_loot_detail.add_theme_font_size_override("font_size", ceili(9.0 / scale_factor))
	var preview_width: float = minf(144.0 / scale_factor, size.x - _board.end.x - edge * 2.0) if wide else minf(248.0 / scale_factor, size.x - 92.0 / scale_factor - edge * 2.0)
	var preview_x: float = _board.end.x + edge if wide else size.x - edge - preview_width
	var preview_y: float = _board.position.y if wide else 0.0
	var padding: float = 8.0 / scale_factor
	var preview_columns: int = 2 if wide else JellyMatchModel.UPCOMING_COUNT
	var preview_gap: float = 4.0 / scale_factor
	var preview_size: float = minf(60.0 / scale_factor, (preview_width - padding * 2.0 - preview_gap * (preview_columns - 1)) / preview_columns)
	if wide:
		preview_size = minf(preview_size, _pitch * 0.88)
	var preview_height: float = preview_size * 2.0 + preview_gap + padding * 2.0 if wide else preview_size + padding * 2.0
	_preview_rect = Rect2(Vector2(preview_x, preview_y), Vector2(preview_width, preview_height))
	drop_button.position = _preview_rect.position
	drop_button.size = _preview_rect.size
	_style_drop_button()
	var inset: float = (preview_width - preview_columns * preview_size - (preview_columns - 1) * preview_gap) * 0.5
	for index in range(_preview_tiles.size()):
		var preview: Tile = _preview_tiles[index]
		preview.size = Vector2.ONE * preview_size
		_preview_origins[index] = _preview_rect.position + Vector2(inset + (index % preview_columns) * (preview_size + preview_gap), padding + floorf(float(index) / preview_columns) * (preview_size + preview_gap))
	_notice.position = Vector2(_board.end.x + edge * 2.0, _preview_rect.end.y + 10.0 / scale_factor) if wide else Vector2(_board.position.x, _board.end.y + 7.0 / scale_factor)
	_notice.size = Vector2(maxf(0.0, size.x - _notice.position.x - edge), minf(size.y - _notice.position.y, 96.0 / scale_factor)) if wide else Vector2(maxf(0.0, _board.size.x - 120.0 / scale_factor), 44.0 / scale_factor)
	_notice.add_theme_font_size_override("font_size", ceili(14 / scale_factor))
	_style_finish_button()
	var finish_width: float = minf(hud_width, 112.0 / scale_factor) if wide else 112.0 / scale_factor
	finish_button.position = Vector2(hud_x + hud_width - finish_width, _board.end.y - 48.0 / scale_factor) if wide else Vector2(_board.end.x - finish_width, _board.end.y + 7.0 / scale_factor)
	finish_button.size = Vector2(finish_width, 44.0 / scale_factor)
	_result.position = Vector2.ZERO
	_result.size = size
	_reward_presentation.size = size
	_layout_result(scale_factor, edge)
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
	var has_treasure: bool = maxi(game.chest_count, _pending_chests) > 0
	var action_w: float = (result_w - 10.0) * 0.5 if has_treasure else result_w
	chests_button.position = Vector2(result_x, action_y) / s
	chests_button.size = Vector2(action_w, 48.0) / s
	replay_button.position = Vector2(result_x + action_w + 10.0 if has_treasure else result_x, action_y) / s
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
	var well := Style.box(Color("#fbfff9", 0.90), Color("#78a995", 0.64), 18, 2)
	well.shadow_color = Color("#2a6954", 0.13)
	well.shadow_size = ceili(10.0 / Style.ui_scale(self))
	well.shadow_offset = Vector2(0, 5.0 / Style.ui_scale(self))
	draw_style_box(well, _board.grow(2.0))
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
	result["drag"] = {"active": _dragging, "pointer": _pointer, "source": _source, "target": _target, "selected": -1}
	var contact: Dictionary = _contact_state()
	result["contact"] = {"kind": contact.kind, "source": contact.source, "target": contact.target, "strength": contact.strength}
	result["fusion_effects"] = []
	for id: String in _fusion_visuals:
		var visual: Dictionary = _fusion_visuals[id]
		var visible_art: bool = visual.art.is_visible_in_tree()
		result.fusion_effects.append({"attempt_id": id, "visible": visible_art,
			"stage": visual.art.stage if visible_art else "none",
			"rect": _rect(visual.merged.get_global_rect()) if visual.merged.visible else []})
	var first_effect: Dictionary = result.fusion_effects[0] if not result.fusion_effects.is_empty() else {}
	result["fusion_effect"] = {"visible": first_effect.get("visible", false), "stage": first_effect.get("stage", "none")}
	result["preview"] = {"visible": is_visible_in_tree() and _configured and not _result_visible,
		"enabled": _can_play() and game.can_drop_now() and _pointer == NO_POINTER,
		"control": _control(drop_button), "rect": _rect(_global_rect(_preview_rect)), "slots": []}
	for index in range(_preview_tiles.size()):
		var preview: Tile = _preview_tiles[index]
		var pose: Dictionary = _preview_pose(index)
		result.preview.slots.append({"id": preview.tile_id, "rect": _rect(preview.get_global_rect()), "visible": preview.is_visible_in_tree(),
			"motion": {"pressure": pose.pressure, "sway": pose.sway, "beat": pose.beat, "intensity": pose.intensity}})
	result["landing_ghosts"] = []
	for ghost: Tile in _ghosts.values():
		result.landing_ghosts.append({"visible": ghost.is_visible_in_tree(), "id": ghost.tile_id, "rect": _rect(ghost.get_global_rect())})
	result["fusion_rect"] = first_effect.get("rect", [])
	result["loot"] = {"count": game.chest_count, "rect": _rect(_loot_icon.get_global_rect()), "flights": _loot_flights.size()}
	result["loot"]["fragments"] = game.fragment_count
	result["loot"]["tier"] = game.chest_tier
	result["loot"]["progress_text"] = _loot_detail.text
	result["loot"]["progress"] = _loot_meter.snapshot()
	result["loot"]["progress"]["rect"] = _rect(_loot_meter.get_global_rect())
	result["reward_presentation"] = _reward_presentation.snapshot()
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

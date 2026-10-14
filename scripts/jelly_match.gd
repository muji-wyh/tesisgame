class_name JellyMatch
extends Control
const WordArt = preload("res://scripts/word_art.gd")
## A fixed portrait jelly well. The model alone owns answers, time and loot.

signal word_requested(word: Dictionary)
signal audio_requested(cue: String)
signal word_attempted(event_id: String, word_ids: Array[String], correct: bool)
signal round_finished(result: Dictionary)
signal finish_requested
signal changed(state: Dictionary)

const JellyMatchModel = preload("res://scripts/jelly_match_model.gd")
const Tile = preload("res://scripts/jelly_tile.gd")
const FinishButton = preload("res://scripts/jelly_finish_button.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
const FusionArt = preload("res://scripts/jelly_fusion.gd")
const Style = preload("res://scripts/ui_style.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Data = preload("res://scripts/game_data.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const LootMeter = preload("res://scripts/jelly_loot_meter.gd")
const ChestCelebration = preload("res://scripts/jelly_chest_celebration.gd")
const ChestTap = preload("res://scripts/jelly_chest_tap.gd")
const DangerFrame = preload("res://scripts/jelly_danger_frame.gd")
const LOOT_FLIGHT_SECONDS: float = ChestCelebration.ARRIVAL_SECONDS
const SURFACES := ["coral", "mint", "sky", "lilac"]
const NO_POINTER: int = -2147483648
const MOUSE_POINTER: int = -1
const DRAG_STRETCH := Vector2(0.985, 1.06)

var game = JellyMatchModel.new()
var interaction_allowed: Callable
var reduced_motion: bool = false
var finish_button: FinishButton
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
var _danger_frame: DangerFrame
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
var _contact_cue_target: int = -1
var _rejection: Dictionary = {}
var _loot_flights: Array[Dictionary] = []
var _loot_icon: TextureRect
var _loot_meter: LootMeter
var _chest_tap: ChestTap
var _header_chest_host: Control
var _loot_detail: Label
var _reward_presentation: ChestCelebration
var _displayed_chest_tier: int = 0
var _notice: Label
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
	_danger_frame = DangerFrame.new()
	add_child(_danger_frame)
	_loot_meter = LootMeter.new()
	add_child(_loot_meter)
	_loot_icon = _image(self)
	_chest_tap = ChestTap.new()
	_chest_tap.pressed.connect(_tap_chest)
	add_child(_chest_tap)
	_loot_detail = _label(self, "Fragments", 11)
	_loot_detail.name = "JellyFragmentProgress"
	drop_button = Button.new()
	drop_button.name = "JellyDropNow"
	drop_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_button.focus_mode = Control.FOCUS_ALL
	drop_button.set("accessibility_name", "Drop the next jellies")
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
	_reward_presentation = ChestCelebration.new()
	add_child(_reward_presentation)
	_reward_presentation.cue_requested.connect(_reward_cue)
	finish_button = FinishButton.new()
	finish_button.name = "JellyFinish"
	finish_button.accessibility_requested.connect(_request_finish)
	finish_button.finish_committed.connect(_finish_round)
	finish_button.threshold_reached.connect(_finish_pull_ready)
	finish_button.pull_started.connect(_finish_pull_changed)
	finish_button.pull_canceled.connect(_finish_pull_changed)
	add_child(finish_button)
	game.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		word_attempted.emit(id, ids, correct))
	game.cue_requested.connect(_cue)
	game.fusion_completed.connect(_fusion_completed)
	game.chest_milestone.connect(_chest_milestone)
	game.finished.connect(_finished)
	resized.connect(func() -> void: finish_button.cancel_pull(true))
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
	for tile in _tiles.values():
		tile.set_chest_texture(texture)
	for preview: Tile in _preview_tiles:
		preview.set_chest_texture(texture)

func _cache_chest_image(id: String, cache: Dictionary) -> void:
	# Source chests reserve an opening envelope. Trim the rendered closed pose once
	# so treasure markers and chest celebrations use actual artwork dimensions.
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

func _exit_tree() -> void:
	if has_header_chest() and not _header_chest_host.is_queued_for_deletion():
		_header_chest_host.hide()
		_header_chest_host.queue_free()

func host_header_chest(header: Control) -> void:
	if has_header_chest():
		return
	_header_chest_host = Control.new()
	_header_chest_host.name = name + "ChestDock"
	_header_chest_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_chest_host.hide()
	header.add_child(_header_chest_host)
	for control: Control in [_loot_meter, _loot_icon, _chest_tap]:
		control.reparent(_header_chest_host, false)
	_header_chest_host.resized.connect(layout_header_chest)
	_header_chest_host.item_rect_changed.connect(_sync_header_chest_anchor)
	item_rect_changed.connect(_sync_header_chest_anchor)
	layout_header_chest()
	_sync_chest_tap()

func has_header_chest() -> bool:
	return is_instance_valid(_header_chest_host)

func layout_header_chest() -> bool:
	if not has_header_chest():
		return false
	var edge: float = minf(_header_chest_host.size.x, _header_chest_host.size.y)
	_loot_meter.position = (_header_chest_host.size - Vector2.ONE * edge) * 0.5
	_loot_meter.size = Vector2.ONE * edge
	_loot_icon.size = Vector2.ONE * edge * 0.67
	_loot_icon.position = (_header_chest_host.size - _loot_icon.size) * 0.5
	_chest_tap.position = _loot_meter.position
	_chest_tap.size = _loot_meter.size
	_loot_detail.hide()
	_sync_header_chest_anchor()
	return true

func chest_anchor_rect() -> Rect2:
	return get_global_transform().affine_inverse() * _loot_icon.get_global_rect()

func chest_meter_rect() -> Rect2:
	return get_global_transform().affine_inverse() * _loot_meter.get_global_rect()

func _sync_header_chest_anchor() -> void:
	if is_inside_tree() and is_instance_valid(_reward_presentation):
		_reward_presentation.set_chest_anchor(chest_anchor_rect())
		queue_redraw()

func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	_style_finish_button()
	_chest_tap.clear()
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
	queue_redraw()
	_publish()

func pause(value: bool = true) -> void:
	if _paused == value:
		return
	_paused = value
	game.set_paused(value)
	_reward_presentation.set_paused(value)
	cancel_input()
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
	if is_instance_valid(finish_button):
		finish_button.cancel_pull(true)
	_chest_tap.clear()
	_contact_cue_target = -1
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
	_sync_chest_tap()
	_refresh_marks()
	_sync_positions()
	_refresh_fusion()
	_refresh_contact()
	queue_redraw()
	_publish()

func release_pointer(pointer: int) -> void:
	finish_button.release_pointer(pointer)
	# The host may report pointer-up before Godot receives its normal drop event.
	# Only cancel a gesture still owned by the same contact after that event runs.
	_cancel_missing_release.call_deferred(pointer, _gesture_serial)

func _cancel_missing_release(pointer: int, serial: int) -> void:
	if serial == _gesture_serial and pointer == _pointer:
		cancel_input()

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_input()
	_refresh_controls()
	_publish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _configured:
		cancel_input()

func _allowed() -> bool:
	return _configured and not _paused and is_visible_in_tree() and (not interaction_allowed.is_valid() or bool(interaction_allowed.call()))

func _can_play() -> bool:
	return _allowed() and game.phase == "playing"

func _can_tap_chest() -> bool:
	return _can_play() and not _finish_is_pulling() and _pointer == NO_POINTER and not _reward_presentation.is_active()

func _tap_chest() -> void:
	if not _can_tap_chest() or _chest_tap.is_active():
		return
	_chest_tap.play(_loot_icon.texture, _loot_icon.modulate.a, reduced_motion)
	_sync_chest_tap()
	_publish()

func _sync_chest_tap() -> void:
	var shown: bool = _configured and not _reward_presentation.visible
	if has_header_chest():
		_header_chest_host.visible = _can_play()
	_chest_tap.visible = shown
	_chest_tap.disabled = not _can_tap_chest()
	_loot_icon.visible = shown and not _chest_tap.is_active()

func _input(event: InputEvent) -> void:
	if _finish_is_pulling():
		return
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
	if _pointer != NO_POINTER or not _can_play() or _finish_is_pulling():
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
	_contact_cue_target = -1
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
	_sync_positions()
	_refresh_fusion()
	_publish()
	_sound_contact()

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
	var serial: int = _gesture_serial
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	if _dragging and _tiles.has(source):
		# Pointer-up may carry a newer position than the last motion event.
		_drag_point = point
		_tiles[source].position = point - _drag_offset
		_sync_positions()
		_sound_contact()
		if generation != _generation or serial != _gesture_serial or not _can_play():
			return
	var target: int = _target if _dragging else -1
	var from: Vector2 = _tiles[source].position if _tiles.has(source) else Vector2.ZERO
	var dragged: bool = _dragging
	var held: Dictionary = _contact_state()
	if dragged and target >= 0:
		# Continue from the painted skins, including the held lift and pressure.
		var inverse: Transform2D = get_global_transform().affine_inverse()
		held["origin_a"] = inverse * _tiles[source]._surface.get_global_rect().get_center()
		held["origin_b"] = inverse * _tiles[target]._surface.get_global_rect().get_center()
		held["stretch_a"] = _tiles[source]._surface.scale
		held["stretch_b"] = _tiles[target]._surface.scale
	_pointer = NO_POINTER
	_source = -1
	_target = -1
	_contact_cue_target = -1
	_dragging = false
	_gesture_serial += 1
	if dragged:
		if target >= 0:
			_merge(source, target, from, held, true)
		else:
			_release_empty_space(source, from)
	if generation != _generation or not _allowed():
		return
	_refresh_marks()
	_publish()

func _release_empty_space(source: int, from: Vector2) -> void:
	_snap_back(source, from)
	audio_requested.emit("release")

func _drop_next(expected_first_id: int = -1) -> void:
	if not _can_play() or _pointer != NO_POINTER or _finish_is_pulling():
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
	if not _can_play() or _pointer != NO_POINTER or _finish_is_pulling() or not _settled(_cell(id)):
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
				for key: String in ["origin_a", "origin_b", "stretch_a", "stretch_b"]:
					if held.has(key):
						visual[key] = held[key]
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

func _drag_target() -> int:
	if not _tiles.has(_source):
		return -1
	var source: Tile = _tiles[_source]
	var outline: PackedVector2Array = source.contact_outline(Vector2.ONE if reduced_motion else DRAG_STRETCH)
	var nearest: int = -1
	var nearest_distance: float = INF
	for cell: Dictionary in game.cells:
		var id: int = int(cell.id)
		if id == _source or not _settled(cell) or not _tiles.has(id):
			continue
		var target: Tile = _tiles[id]
		# Several neighbors can touch at once. Choose the closest physical body,
		# regardless of the answer, while preserving the current target on a tie.
		var distance: float = source.get_rect().get_center().distance_squared_to(target.get_rect().get_center())
		if distance > nearest_distance or (is_equal_approx(distance, nearest_distance) and id != _target):
			continue
		if Geometry2D.intersect_polygons(outline, target.contact_outline()).is_empty():
			continue
		nearest = id
		nearest_distance = distance
	return nearest

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
		var stretch: Vector2 = Vector2.ONE if reduced_motion else DRAG_STRETCH if dragging else Vector2(pose.stretch)
		tile.deform(0.0 if reduced_motion or dragging else float(pose.bend), float(pose.beat), stretch)
		var lift: float = 6.0 / Style.ui_scale(self) if dragging else maxf(0.0, rect.position.y - position_in_view.y)
		tile.set_support(lift, 0.0 if reduced_motion or dragging else float(pose.compression))
		tile.modulate.a = 1.0 if reduced_motion else float(pose.opacity)
		tile.visible = true
		if airborne:
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
		var target: int = _drag_target()
		if target != _target:
			_target = target
			_contact_elapsed = 0.0
			_refresh_marks()
	_refresh_contact()

func _sync_preview() -> void:
	for index in range(_preview_tiles.size()):
		var preview: Tile = _preview_tiles[index]
		preview.visible = _configured and index < game.upcoming.size()
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
	# The old deep-overlap response separates the reading faces. Fade it out at
	# edge contact so a newly touching pair does not visibly jump apart.
	var separation: float = _tiles[_source].get_rect().get_center().distance_to(_tiles[_target].get_rect().get_center()) / (_pitch - _gap)
	var pressure: float = 1.0 - smoothstep(0.4, 0.7, separation)
	state.merge({"kind": "match" if matching else "mismatch", "source": _source, "target": _target,
		"strength": pressure * lerpf(0.35, 1.0, smoothstep(0.0, 0.14, _contact_elapsed)), "direction": direction}, true)
	return state

func _sound_contact() -> void:
	# A held contact is one event, including when the final pointer-up position
	# is the first touching frame. Separating and touching again starts a new one.
	var target: int = _target if _dragging and _can_play() else -1
	if target == _contact_cue_target:
		return
	_contact_cue_target = target
	if target >= 0:
		audio_requested.emit("contact")

func _refresh_contact() -> void:
	var state: Dictionary = _contact_state()
	for id in _tiles:
		var involved: bool = int(id) == int(state.source) or int(id) == int(state.target)
		var direction: Vector2 = Vector2(state.direction) * (1.0 if int(id) == int(state.source) else -1.0)
		_tiles[id].set_contact(str(state.kind) if involved else "none", direction, float(state.strength) if involved else 0.0, reduced_motion)

func _process(delta: float) -> void:
	for id in _chest_cache:
		var cache: Dictionary = _chest_cache[id]
		if int(cache.frames) < 6:
			cache.frames += 1
			if int(cache.frames) == 6:
				_cache_chest_image(str(id), cache)
				cache.art.set_idle_paused(true)
				cache.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	finish_button.set_hint_allowed(_finish_hint_allowed())
	if not _allowed() or delta > 0.5:
		_chest_tap.clear()
		_sync_chest_tap()
		_refresh_danger()
		if _pointer != NO_POINTER or _finish_is_pulling():
			cancel_input()
		return
	# Pulling Finish owns this interaction, including the falling-board clock.
	# Its elastic return advances independently so an early release resumes play.
	if _finish_is_pulling():
		_publish()
		return
	var generation: int = _generation
	var previous_ages: Dictionary = {}
	_chest_tap.advance(delta)
	for cell: Dictionary in game.cells:
		previous_ages[int(cell.id)] = float(cell.age)
	_landing_cooldown = maxf(0.0, _landing_cooldown - delta)
	if _dragging and _target >= 0:
		_contact_elapsed += delta
	if not _rejection.is_empty():
		_rejection.elapsed += delta
		if float(_rejection.elapsed) >= 0.34:
			_rejection.clear()
	# Advance only flights that existed before this frame's simulation. A clear
	# inside game.step() starts a new flight, not one already aged by the frame.
	var loot_ready: bool = _reward_pickup_ready()
	_advance_loot_feedback(delta)
	if _reward_presentation.is_active():
		advance_reward_presentation(delta, loot_ready)
	if generation != _generation or not _allowed():
		return
	if game.phase == "playing":
		game.step(delta)
	if generation != _generation or not _allowed():
		return
	for id in _snapbacks.keys():
		_snapbacks[id].elapsed += delta
		if float(_snapbacks[id].elapsed) >= 0.24:
			_snapbacks.erase(id)
	_sync_tiles()
	_refresh_fusion()
	_refresh_hud()
	queue_redraw()
	_publish_elapsed += delta
	if _publish_elapsed >= 0.1:
		_publish()
	if generation == _generation and _can_play() and game.full_elapsed < 0.0 and _landing_cooldown <= 0.0:
		for cell: Dictionary in game.cells:
			var contact: float = _landing_contact_at(cell)
			if float(previous_ages.get(int(cell.id), 0.0)) < contact and float(cell.age) >= contact:
				# Adjacent bodies land as one quiet group, never a stack of impacts.
				_landing_cooldown = 0.12
				audio_requested.emit("land")
				break
	if generation == _generation:
		_sound_contact()

func _landing_contact_at(cell: Dictionary) -> float:
	return Motion.contact_at(cell)

func _reward_pickup_ready() -> bool:
	if _loot_meter.is_filling():
		return false
	if _loot_flights.is_empty():
		return true
	# Later pickups can fly while an earlier, fully arrived milestone celebrates.
	var arrived: int = game.fragment_count
	for flight: Dictionary in _loot_flights:
		arrived -= int(flight.get("amount", 1))
	var tier: int = int(_reward_presentation.snapshot().tier)
	return tier > 0 and arrived >= 4 + (tier - 1) * 5

func _advance_loot_feedback(delta: float) -> void:
	var remaining: float = delta
	while remaining > 0.0:
		var consumed: float = remaining
		for flight: Dictionary in _loot_flights:
			consumed = minf(consumed, maxf(0.0, LOOT_FLIGHT_SECONDS - float(flight.elapsed)))
		# Split at each arrival: a new segment receives only time after its pickup
		# reaches the chest, including when several flights finish in one frame.
		_loot_meter.advance(consumed)
		for flight: Dictionary in _loot_flights:
			flight.elapsed += consumed
		var before: int = _loot_flights.size()
		_loot_flights = _loot_flights.filter(func(item: Dictionary) -> bool:
			return float(item.elapsed) < LOOT_FLIGHT_SECONDS)
		if _loot_flights.size() != before:
			_refresh_hud()
		remaining -= consumed
		if consumed <= 0.0 and _loot_flights.size() == before:
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
			"origin_a": _tile_rect(fusion.a).get_center(), "origin_b": _tile_rect(fusion.b).get_center(),
			"stretch_a": Vector2.ONE, "stretch_b": Vector2.ONE}
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
	if not _configured or game.phase != "playing":
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
	# Give the neck time to form before the two lobes flow into their common
	# center. Both bodies contribute; one does not slide underneath the other.
	var gather: float = smoothstep(0.16, 0.52, p)
	var union: float = smoothstep(0.32, 0.40, p)
	var separate_faces: float = 1.0 - smoothstep(0.24, 0.32, p)
	var origin_a: Vector2 = visual.origin_a
	var origin_b: Vector2 = visual.origin_b
	var center: Vector2 = ((origin_a + origin_b) * 0.5).lerp(destination, smoothstep(0.14, 0.52, p))
	var half_separation: Vector2 = (origin_b - origin_a) * 0.5
	# Deep drops start in their actual held pose, then express the two soft
	# lobes briefly before joining. Edge drops already have that separation.
	var opening: float = maxf(0.0, unit * 0.72 - half_separation.length() * 2.0) * smoothstep(0.0, 0.10, p)
	half_separation = (half_separation + Vector2(visual.direction) * opening * 0.5) * (1.0 - gather)
	var first_center: Vector2 = center - half_separation
	var second_center: Vector2 = center + half_separation
	for cell: Dictionary in [a, b]:
		if not _tiles.has(int(cell.id)):
			continue
		var droplet: Tile = _tiles[int(cell.id)]
		droplet.set_support(0.0, 0.0, false)
		droplet.visible = not reduced_motion and separate_faces > 0.0
		droplet._surface.hide()
		droplet.modulate.a = separate_faces
		droplet.z_index = 28 if int(cell.id) == int(a.id) else 27
		var face_center: Vector2 = first_center if int(cell.id) == int(a.id) else second_center
		droplet.position = face_center - droplet.size * 0.5
		droplet.deform(0.0, 0.0)
	var compression: float = smoothstep(0.57, 2.0 / 3.0, p)
	var release: float = clampf((p - 2.0 / 3.0) * 3.0, 0.0, 1.0)
	var body_opacity: float = 1.0
	var content_opacity: float = 1.0
	var rise: float = 0.0
	if not reduced_motion:
		size_factor = lerpf(1.0, 1.28, smoothstep(0.16, 0.50, p))
		content_opacity = union
		var settle: float = sin(clampf((p - 0.48) / 0.15, 0.0, 1.0) * TAU) * (1.0 - smoothstep(0.48, 0.63, p)) * 0.06
		stretch = Vector2(1.0 + settle + compression * 0.20, 1.0 - settle - compression * 0.22)
		if release > 0.0:
			var snap: float = smoothstep(0.0, 0.24, release)
			var retract: float = smoothstep(0.20, 0.88, release)
			stretch = Vector2(lerpf(1.20, 0.74, snap), lerpf(0.78, 1.42, snap)) * lerpf(1.0, 0.05, retract)
			rise = unit * (0.18 * snap + 0.15 * retract)
			body_opacity = 1.0 - smoothstep(0.66, 0.92, release)
			content_opacity *= 1.0 - smoothstep(0.04, 0.44, release)
		var extent: Vector2 = Vector2.ONE * unit * size_factor * stretch
		var recovery: float = smoothstep(0.0, 0.24, p)
		var extent_a: Vector2 = extent * Vector2(visual.stretch_a).lerp(Vector2.ONE, recovery)
		var extent_b: Vector2 = extent * Vector2(visual.stretch_b).lerp(Vector2.ONE, recovery)
		# The same two painted lobes become one surface; no sprite crossfade at the seam.
		art.pose(first_center - Vector2(0, rise), second_center - Vector2(0, rise), destination,
			extent_a, extent_b, unit, p, compression * (1.0 - release), release, body_opacity)
	else:
		art.hide()
	merged._surface.visible = reduced_motion
	merged.size = Vector2.ONE * unit * size_factor
	merged.position = (destination if reduced_motion else center) - merged.size * 0.5 - Vector2(0, rise * 0.65)
	merged.modulate.a = content_opacity
	merged.deform(0.0, 0.0, Vector2.ONE if reduced_motion else stretch)
	merged.set_support(0.0, maxf(0.0, 1.0 - stretch.y))
	merged._shadow.modulate.a *= body_opacity
	merged.visible = reduced_motion or union > 0.0

func _cue(cue: String) -> void:
	if cue in ["danger", "danger_end"]:
		_refresh_danger()
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
	_refresh_hud()

func _chest_milestone(previous_tier: int, tier: int) -> void:
	if not _configured or game.phase != "playing":
		return
	_chest_tap.clear()
	_reward_presentation.reduced_motion = reduced_motion
	_reward_presentation.enqueue(previous_tier, tier, _reward_texture(previous_tier), _reward_texture(tier))
	_chest_for_theme(RewardProgress.theme_for_tier(tier + 1))
	_refresh_hud()
	_refresh_controls()
	_publish()

func advance_reward_presentation(delta: float, pickup_ready: bool = true) -> float:
	if not _allowed():
		return 0.0
	var generation: int = _generation
	var remaining: float = _reward_presentation.advance(delta, pickup_ready)
	if generation != _generation or not _allowed():
		return 0.0
	_refresh_hud()
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

func _finish_is_pulling() -> bool:
	return is_instance_valid(finish_button) and finish_button.is_pulling()

func _finish_hint_allowed() -> bool:
	return _can_play() and _pointer == NO_POINTER and not _reward_presentation.is_active() and not _chest_tap.is_active()

func _finish_pull_changed() -> void:
	_refresh_controls()
	_publish()

func _finish_pull_ready() -> void:
	if _can_play() and _finish_is_pulling():
		audio_requested.emit("finish_ready")
		_publish()

func _request_finish() -> void:
	if _can_play() and _pointer == NO_POINTER and not _finish_is_pulling():
		finish_requested.emit()

func _finish_round() -> void:
	if not _can_play() or _pointer != NO_POINTER or _finish_is_pulling():
		return
	cancel_input()
	game.finish_round()

func _refresh_hud() -> void:
	_refresh_danger()
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
	_notice.visible = _configured and not has_header_chest() and (not _compact_hud or full)
	_sync_chest_tap()
	_loot_meter.visible = _configured
	_loot_detail.visible = _configured and not has_header_chest()
	_sync_preview()

func _refresh_controls() -> void:
	_sync_chest_tap()
	_refresh_danger()
	for cell: Dictionary in game.cells:
		if _tiles.has(int(cell.id)):
			_tiles[int(cell.id)].disabled = not _can_play() or _finish_is_pulling() or not _settled(cell)
	finish_button.visible = _can_play() if finish_button.get_parent() != self else \
		_configured and game.phase == "playing"
	finish_button.disabled = not _can_play() or _pointer != NO_POINTER
	drop_button.visible = _configured and game.phase == "playing"
	drop_button.disabled = not _can_play() or _finish_is_pulling() or not game.can_drop_now() or (_pointer != NO_POINTER and _preview_first_id < 0)
	if drop_button.disabled:
		_set_preview_pressed(false)

func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if not _allowed():
		return controls
	if _can_play():
		var ordered: Array = game.cells.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.row) * 4 + int(a.column) < int(b.row) * 4 + int(b.column))
		for cell: Dictionary in ordered:
			if _settled(cell) and _tiles.has(int(cell.id)):
				controls.append(_tiles[int(cell.id)])
		if not drop_button.disabled:
			controls.append(drop_button)
		if not _chest_tap.disabled:
			controls.append(_chest_tap)
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
	finish_button.configure(_theme.get("accent", Style.GOOD), Style.ui_scale(self), reduced_motion)

func _layout() -> void:
	if _loot_icon == null or size.x <= 0.0 or size.y <= 0.0:
		return
	if has_header_chest():
		_layout_hosted()
		return
	var scale_factor: float = Style.ui_scale(self)
	var short_board: bool = size.y * scale_factor < 320.0
	var edge: float = (4.0 if short_board else 8.0) / scale_factor
	var wide: bool = short_board or size.x > size.y * 1.18
	_compact_hud = wide and size.x * scale_factor <= 400.0
	var side_space: float = maxf(84.0 / scale_factor + edge, minf(164.0 / scale_factor, size.x * 0.20)) if wide else 0.0
	var available_height: float = size.y - edge * 2.0 if wide else size.y - 150.0 / scale_factor
	var available_width: float = size.x - edge * 2.0 - side_space * 2.0
	var board_height: float = maxf(60.0, minf(minf(available_height, available_width * 1.5), 684.0 / scale_factor))
	_board = Rect2(Vector2((size.x - board_height * 2.0 / 3.0) * 0.5, edge if wide else 88.0 / scale_factor), Vector2(board_height * 2.0 / 3.0, board_height))
	_danger_frame.layout_frame(_board.grow(2.0), scale_factor, 18.0)
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
	_chest_tap.position = _loot_meter.position
	_chest_tap.size = _loot_meter.size
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
	_reward_presentation.size = size
	_reward_presentation.set_chest_anchor(chest_anchor_rect())
	_sync_positions()
	_refresh_fusion()
	_refresh_hud()
	queue_redraw()
	_publish()

func _layout_hosted() -> void:
	var s: float = Style.ui_scale(self)
	var edge: float = (4.0 if size.y * s < 320.0 else 6.0) / s
	var bottom: float = 8.0 / s
	var feed_gap: float = 6.0 / s
	var padding: float = 6.0 / s
	var available: Vector2 = size - Vector2(edge * 2.0, edge + bottom)
	var supply_side: float = minf(132.0 / s, maxf(88.0 / s, available.x * 0.18))
	var top_feed: float = minf(72.0 / s, maxf(44.0 / s, available.x / 4.0))
	var top_height: float = minf(available.y - top_feed - feed_gap, available.x * 1.5)
	var side_height: float = minf(available.y, (available.x - supply_side - feed_gap) * 1.5)
	var side_supply: bool = side_height > top_height + 1.0 / s
	_compact_hud = true
	var board_height: float = maxf(48.0 / s, side_height if side_supply else top_height)
	var board_width: float = board_height * 2.0 / 3.0
	var group_width: float = board_width + supply_side + feed_gap if side_supply else board_width
	var group_x: float = (size.x - group_width) * 0.5
	var board_y: float = size.y - bottom - board_height
	var next_board := Rect2(Vector2(group_x, board_y), Vector2(board_width, board_height))
	if next_board != _board:
		if _dragging:
			cancel_input()
		_snapbacks.clear()
	_board = next_board
	_pitch = board_height / 6.0
	_gap = maxf(2.0 / s, _pitch * 0.035)
	_danger_frame.layout_frame(_board.grow(2.0), s, 18.0)
	_falling_layer.position = _board.position
	_falling_layer.size = _board.size
	layout_header_chest()
	var preview_columns: int = 2 if side_supply else JellyMatchModel.UPCOMING_COUNT
	var preview_gap: float = 4.0 / s
	var preview_width: float = supply_side if side_supply else board_width
	var preview_size: float = minf(60.0 / s, (preview_width - padding * 2.0 - preview_gap * (preview_columns - 1)) / preview_columns)
	if side_supply:
		preview_size = minf(preview_size, (available.y - padding * 2.0 - preview_gap) * 0.5)
	else:
		preview_size = minf(preview_size, top_feed - padding * 2.0)
	var preview_height: float = maxf(44.0 / s, preview_size * (2.0 if side_supply else 1.0) + padding * 2.0 + (preview_gap if side_supply else 0.0))
	_preview_rect = Rect2(Vector2(_board.end.x + feed_gap, board_y) if side_supply else Vector2(group_x, board_y - feed_gap - preview_height), Vector2(preview_width, preview_height))
	drop_button.position = _preview_rect.position
	drop_button.size = _preview_rect.size
	_style_drop_button()
	var inset: float = (preview_width - preview_columns * preview_size - (preview_columns - 1) * preview_gap) * 0.5
	for index in range(_preview_tiles.size()):
		_preview_tiles[index].size = Vector2.ONE * preview_size
		_preview_origins[index] = _preview_rect.position + Vector2(inset + (index % preview_columns) * (preview_size + preview_gap), padding + floorf(float(index) / preview_columns) * (preview_size + preview_gap))
	_style_finish_button()
	_reward_presentation.size = size
	_reward_presentation.set_chest_anchor(chest_anchor_rect())
	_sync_positions()
	_refresh_fusion()
	_refresh_hud()
	queue_redraw()
	_publish()

func danger_feedback() -> Dictionary:
	var active: bool = _can_play() and float(game.full_elapsed) >= 0.0
	var strength: float = 0.0
	if active:
		strength = DangerFrame.primary_pulse(float(game.full_elapsed), reduced_motion)
	return {"active": active, "strength": strength}

func _refresh_danger() -> void:
	_danger_frame.set_warning(_can_play() and float(game.full_elapsed) >= 0.0,
		float(game.full_elapsed), JellyMatchModel.FULL_SECONDS, reduced_motion)

func _draw() -> void:
	if not _configured:
		return
	var well := Style.box(Color("#fbfff9", 0.90), Color("#78a995", 0.64), 18, 2)
	well.shadow_color = Color("#2a6954", 0.13)
	well.shadow_size = ceili(10.0 / Style.ui_scale(self))
	well.shadow_offset = Vector2(0, 5.0 / Style.ui_scale(self))
	draw_style_box(well, _board.grow(2.0))
	if _chest_texture != null:
		for flight: Dictionary in _loot_flights:
			var p: float = clampf(float(flight.elapsed) / LOOT_FLIGHT_SECONDS, 0.0, 1.0)
			var destination: Vector2 = chest_anchor_rect().get_center()
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
	result["preview"] = {"visible": is_visible_in_tree() and _configured,
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
	result["loot"]["tap"] = _chest_tap.snapshot()
	result["loot"]["tap"].merge(_control(_chest_tap))
	result["reward_presentation"] = _reward_presentation.snapshot()
	# Preserve the published key while settlement belongs to the host modal.
	result["result"] = {"visible": false, "retired": true}
	result["finish"] = _control(finish_button)
	result["finish"]["pull"] = finish_button.snapshot()
	result["finish"]["focused"] = finish_button.has_focus()
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

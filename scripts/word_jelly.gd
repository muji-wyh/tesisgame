class_name WordJelly
extends "res://scripts/jelly_match.gd"
## Five-column word construction, with the established jelly input and rewards.

signal collected(event_id: String, word: Dictionary, amount: int, fragments: int, origin: Vector2)
signal word_merged(word: Dictionary)
signal batch_collection_started
signal combo_coins_earned(event_id: String, origin: Vector2)

const WordModel = preload("res://scripts/word_jelly_model.gd")
const WordTile = preload("res://scripts/word_jelly_tile.gd")
const Palette = preload("res://scripts/word_jelly_palette.gd")
const WordReveal = preload("res://scripts/word_jelly_word_reveal.gd")
const CollectionEffects = preload("res://scripts/word_jelly_collection_fx.gd")
const StageBanner = preload("res://scripts/word_jelly_stage_banner.gd")
const PracticePanel = preload("res://scripts/word_jelly_practice.gd")
const CollectButton = preload("res://scripts/word_jelly_collect_button.gd")
const PowerupButton = preload("res://scripts/word_jelly_powerup_button.gd")
const PowerupEffects = preload("res://scripts/word_jelly_powerup_effects.gd")
const ReadPanel = preload("res://scripts/jelly_read_panel.gd")
const ComboHUD = preload("res://scripts/word_jelly_combo.gd")
const BossView = preload("res://scripts/word_jelly_boss_view.gd")
const COLLECTION_GLOW = preload("res://assets/chests/particles/portal_glow.png")
const POWERUP_SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const POWERUP_RAYS = preload("res://assets/chests/milestone/rays.png")
const WELL_CLOUDS = preload("res://assets/images/jelly-match/well/clouds.png")
const WELL_SURFACE = preload("res://scripts/word_jelly_well.gdshader")

var credit_collection: Callable:
	set(value):
		credit_collection = value
		game.credit_collection = value
var purchase_powerup: Callable:
	set(value):
		purchase_powerup = value
		game.purchase_powerup = value
var coin_balance: Callable
var powerup_buttons: Dictionary = {}
var _powerup_effects: PowerupEffects
var _powerup_arrivals: Array[Dictionary] = []
var _powerup_frame_end: float = -1.0
var _powerup_frame_receipt: String = ""
var _powerup_frame_generation: int = -1
var _collection_origins: Dictionary = {}
var _rest_rects: Dictionary = {}
var _reflow: Dictionary = {}
var _keyboard_source: int = -1
var _palette := Palette.new()
var _palette_indices: Dictionary = {}
var _palette_cache: Dictionary = {}
var _arrival_origins: Dictionary = {}
var _preview_generated: int = -1
var _word_reveal: WordReveal
var _combo_hud: ComboHUD
var _collection_effects: CollectionEffects
var _stage_banner: StageBanner
var _practice_panel: PracticePanel
var _presentation_elapsed: float = 0.0
var collect_button: CollectButton
var _action_divider := ColorRect.new()
var _placement_tile: WordTile
var _placement: Dictionary = {}
var _completion_source: int = -1
var _completion_elapsed: float = 0.0
var _fusion_drag: Dictionary = {}
var _fusion_tap: Dictionary = {}
var _queued_collections: Dictionary = {}
var _reveal_frame_end: float = -1.0
var _reveal_frame_batch: int = -1
var _reveal_frame_generation: int = -1
var _error_notice_reserved: bool = false
var _well_art := TextureRect.new()
var _read_panel: ReadPanel
var _read_cell: Dictionary = {}
var _requested_pause: bool = false
var _layout_too_small: bool = false
var _preview_layout_generation: int = -1
var _preview_layout_rows: int = 1
var _size_cover: ColorRect
var _size_message: Label
var _room_notice: Label
var _room_notice_remaining: float = 0.0
var _read_hold_id: int = -1
var _read_hold_elapsed: float = 0.0
var _tile_press_started_ms: int = -1
var _view_update_active: bool = false
var _view_cells: Dictionary = {}
var _view_mergeable: Dictionary = {}
var _view_drop_known: bool = false
var _view_drop_available: bool = false
var _view_palette_ready: bool = false
var _view_hints_ready: bool = false
var _view_hint_source: int = -1
var _boss_view: BossView
var _preview_drop_available: bool = false
const READ_HOLD_SECONDS: float = 0.45
const COLLECTION_CLICK_MAX_MS: int = 500
const STAGE_WARNING_SECONDS: float = 10.0

func _init() -> void:
	super()
	name = "WordJelly"
	_well_art.name = "CloudPatternWell"
	_well_art.texture = WELL_CLOUDS
	_well_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_well_art.stretch_mode = TextureRect.STRETCH_SCALE
	_well_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_well_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var well_material := ShaderMaterial.new()
	well_material.shader = WELL_SURFACE
	_well_art.material = well_material
	add_child(_well_art)
	move_child(_well_art, 0)
	game = WordModel.new()
	game.finish_feedback_ready = _finish_feedback_ready
	_palette.compatibility = game.parts_compatible
	game.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		word_attempted.emit(id, ids, correct))
	game.cue_requested.connect(_cue)
	game.fusion_started.connect(_merge_started)
	game.fusion_completed.connect(_fusion_completed)
	game.collected.connect(_collected)
	game.collection_started.connect(_collection_started)
	game.chest_milestone.connect(_chest_milestone)
	game.finished.connect(_finished)
	game.powerup_feedback.connect(_powerup_feedback)
	game.powerup_fragment_arrived.connect(_powerup_fragment_arrived)
	game.drag_blocked.connect(_drag_blocked)
	game.combo_changed.connect(_combo_changed)
	game.boss_changed.connect(_sync_boss)
	game.fusion_started.connect(_powerup_fusion_started)
	for tile: Tile in _preview_tiles:
		remove_child(tile)
		tile.free()
	_preview_tiles.clear()
	_preview_origins.clear()
	for index in range(WordModel.UPCOMING_COUNT):
		var tile := WordTile.new()
		tile.name = "UpcomingWordPart%d" % (index + 1)
		tile.disabled = true
		tile.focus_mode = Control.FOCUS_NONE
		add_child(tile)
		_preview_tiles.append(tile)
		_preview_origins.append(Vector2.ZERO)
		tile.read_requested.connect(_show_read)
	drop_button.set("accessibility_name", "Drop the next roots and pictures")
	_word_reveal = WordReveal.new()
	add_child(_word_reveal)
	_combo_hud = ComboHUD.new()
	_combo_hud.z_index = 60
	add_child(_combo_hud)
	# Large blooms remain behind the compact chest prompt as well as word cards.
	_loot_detail.z_index = _word_reveal.z_index + 1
	_collection_effects = CollectionEffects.new()
	add_child(_collection_effects)
	_stage_banner = StageBanner.new()
	add_child(_stage_banner)
	_practice_panel = PracticePanel.new()
	_practice_panel.stage_timer = _stage_banner
	_practice_panel.word_progressed.connect(func(_id: String, complete: bool) -> void:
		if complete and _can_play():
			audio_requested.emit("goal_complete"))
	add_child(_practice_panel)
	_boss_view = BossView.new()
	_boss_view.audio_requested.connect(func(cue: String) -> void: audio_requested.emit(cue))
	add_child(_boss_view)
	collect_button = CollectButton.new()
	collect_button.name = "WordJellyCollectAll"
	collect_button.pressed.connect(_collect_all)
	collect_button.z_index = 5
	add_child(collect_button)
	for kind: String in WordModel.POWERUP_PRICES:
		var button := PowerupButton.new()
		button.configure(kind, game.powerup_price(kind), reduced_motion)
		button.pressed.connect(_activate_powerup.bind(kind))
		button.z_index = 5
		add_child(button)
		powerup_buttons[kind] = button
	_action_divider.name = "PaidToolsDivider"
	_action_divider.color = Color(0.27, 0.43, 0.42, 0.52)
	_action_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_divider.z_index = 5
	_action_divider.hide()
	add_child(_action_divider)
	_powerup_effects = PowerupEffects.new()
	add_child(_powerup_effects)
	_placement_tile = WordTile.new()
	_placement_tile.name = "WordJellyPlacement"
	_placement_tile.disabled = true
	_placement_tile.focus_mode = Control.FOCUS_NONE
	_placement_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_tile.hide()
	add_child(_placement_tile)
	_size_cover = ColorRect.new()
	_size_cover.name = "JellyLayoutPause"
	_size_cover.color = Color(Style.PAPER, 0.97)
	_size_cover.z_index = 90
	_size_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_size_cover)
	_size_message = Style.label("Make the window larger or rotate your device.\nYour game is paused.", 18)
	_size_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_size_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_size_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_size_cover.add_child(_size_message)
	_size_cover.hide()
	_read_panel = ReadPanel.new()
	_read_panel.dismissed.connect(_close_read)
	_read_panel.pronunciation_requested.connect(func() -> void:
		var word: Dictionary = _pronunciation_word(_read_cell)
		if not word.is_empty():
			word_requested.emit(word.duplicate(true)))
	add_child(_read_panel)
	_room_notice = Style.label("Make room before moving this jelly.", 16)
	_room_notice.name = "JellyRoomNotice"
	_room_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_room_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_notice.z_index = 50
	_room_notice.add_theme_stylebox_override("normal", Style.box(Style.PAPER, Style.EDGE, 12, 1))
	_room_notice.hide()
	add_child(_room_notice)

func set_pip_level(level: int) -> void:
	if game.pip_level == maxi(0, level):
		return
	game.set_pip_level(level)
	_refresh_controls()
	_publish()

func stop() -> void:
	_queued_collections.clear()
	if _stage_banner != null:
		_stage_banner.reset()
	if _practice_panel != null:
		_practice_panel.set_stage({})
	_presentation_elapsed = 0.0
	if _collection_effects != null:
		_collection_effects.reset()
	_room_notice_remaining = 0.0
	if _room_notice != null:
		_room_notice.hide()
	_read_cell.clear()
	_requested_pause = false
	_layout_too_small = false
	if _read_panel != null:
		_read_panel.hide()
	if _size_cover != null:
		_size_cover.hide()
	game.finish_powerup()
	_powerup_arrivals.clear()
	if _powerup_effects != null:
		_powerup_effects.reset()
		_powerup_effects.hide()
	for button: PowerupButton in powerup_buttons.values():
		button.reset()
	game.cancel_collection_batch()
	if collect_button != null:
		collect_button.reset()
	if _word_reveal != null:
		_word_reveal.reset()
	super.stop()
	_collection_origins.clear()
	_rest_rects.clear()
	_reflow.clear()
	_keyboard_source = -1
	_palette.clear()
	_palette_indices.clear()
	_palette_cache.clear()
	_arrival_origins.clear()
	_placement.clear()
	_placement_tile.tile_id = -1
	_placement_tile._picture.texture = null
	_placement_tile.hide()

func pause(value: bool = true, preserve_effects: bool = false) -> void:
	if value and _stage_banner != null:
		_stage_banner.dismiss()
	_requested_pause = value
	if value and not preserve_effects and _collection_effects != null:
		_collection_effects.reset()
	if value and not preserve_effects and _word_reveal != null:
		_word_reveal.reset()
	_apply_pause_reasons()
	if _powerup_effects != null:
		_powerup_effects.visible = not _paused and _can_play()
	for button: PowerupButton in powerup_buttons.values():
		button.pause_feedback(_paused)

func _apply_pause_reasons() -> void:
	super.pause(_requested_pause or _layout_too_small or not _read_cell.is_empty())
	# The reason can change while the combined pause remains true.
	_refresh_controls()

func _show_read(id: int) -> void:
	if not _can_play() or game.powerup_active() or game.collection_batch_active():
		return
	var target: Dictionary = _cell(id)
	if target.is_empty():
		for item: Dictionary in game.upcoming:
			if int(item.get("id", -1)) == id:
				target = item
				break
	if target.is_empty() or str(target.get("jelly_kind", "")) == "picture":
		return
	_read_cell = target.duplicate(true)
	_apply_pause_reasons()
	_read_panel.present(str(target.get("display_text", target.text)), not str(_pronunciation_word(target).get("audio", "")).is_empty())
	_publish()

func _close_read() -> void:
	var id: int = int(_read_cell.get("id", -1))
	_read_cell.clear()
	_read_panel.hide()
	_apply_pause_reasons()
	if _can_play() and _tiles.has(id):
		_tiles[id].grab_focus()
	elif _can_play():
		for preview: WordTile in _preview_tiles:
			if preview.tile_id == id and preview.visible and not preview.disabled:
				preview.grab_focus()
				break
	_publish()

func _read_action_at(point: Vector2) -> bool:
	for tile: WordTile in _tiles.values() + _preview_tiles:
		if tile._read_button.is_visible_in_tree() and tile._read_button.get_global_rect().has_point(point):
			return true
	return false

func set_reduced_motion(value: bool) -> void:
	_practice_panel.reduced_motion = value
	_combo_hud.reduced_motion = value
	_stage_banner.reduced_motion = value
	_word_reveal.set_reduced_motion(value)
	_collection_effects.set_reduced_motion(value)
	collect_button.set_reduced_motion(value)
	for kind: String in powerup_buttons:
		powerup_buttons[kind].configure(kind, game.powerup_price(kind), value)
	super.set_reduced_motion(value)

func _visibility_changed() -> void:
	if not is_visible_in_tree() and _collection_effects != null:
		_collection_effects.reset()
	if not is_visible_in_tree() and _word_reveal != null:
		_word_reveal.reset()
	super._visibility_changed()

func _finished(result: Dictionary) -> void:
	_queued_collections.clear()
	_combo_hud.reset()
	_word_reveal.reset()
	_collection_effects.reset()
	_powerup_effects.hide()
	super._finished(result)


func _finish_feedback_ready() -> bool:
	return _collection_effects._entries.is_empty() and _word_reveal._entries.is_empty() \
		and _loot_flights.is_empty() and not _loot_meter.is_filling() \
		and not _reward_presentation.is_active() and not _practice_panel.feedback_active() \
		and not _stage_banner.rating_feedback_active()

func cancel_input() -> void:
	_end_view_update()
	_fusion_tap.clear()
	if not _fusion_drag.is_empty():
		game.hold_merge_for_drag(str(_fusion_drag.event_id), false)
		_fusion_drag.clear()
	_read_hold_id = -1
	_read_hold_elapsed = 0.0
	_tile_press_started_ms = -1
	_keyboard_source = -1
	# Resolve the lifted body before the base view paints its resting position.
	game.set_held_tile()
	super.cancel_input()

func _drag_blocked(_reason: String) -> void:
	_room_notice_remaining = 2.5
	_room_notice.show()
	_publish()

func set_learning_backdrop(active: bool) -> void:
	super.set_learning_backdrop(active)
	_well_art.visible = not active

func apply_theme(theme: Dictionary, chests: Dictionary) -> void:
	if _placement_tile != null:
		_placement_tile.tile_id = -1
	super.apply_theme(theme, chests)
	for fusion: Dictionary in game.fusions:
		var visual: Dictionary = _fusion_visuals.get(str(fusion.attempt_id), {})
		if visual.is_empty():
			continue
		_configure_tile(visual.merged, fusion.result if str(fusion.operation) == "merge" else fusion.a)
		for index in range(visual.get("parts", []).size()):
			_configure_tile(visual.parts[index], fusion.results[index])
	_refresh_fusion()

func _apply_chest_texture(texture: Texture2D) -> void:
	super._apply_chest_texture(texture)
	if powerup_buttons.has("fragments"):
		powerup_buttons.fragments.set_chest_texture(texture)
	if _placement_tile != null:
		_placement_tile.set_chest_texture(texture)
	for visual: Dictionary in _fusion_visuals.values():
		visual.merged.set_chest_texture(texture)

func _input(event: InputEvent) -> void:
	if _read_panel != null and _read_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_read()
			get_viewport().set_input_as_handled()
		return
	if _finish_is_pulling():
		return
	if game.collection_batch_active() or game.powerup_active() or game.stage_ending():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R \
		and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and _can_play():
		var focused: Control = get_viewport().gui_get_focus_owner()
		for tile: WordTile in _tiles.values() + _preview_tiles:
			if tile == focused and tile.is_visible_in_tree():
				_show_read(tile.tile_id)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("ui_cancel") and _keyboard_source >= 0:
		cancel_input()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.shift_pressed and event.is_action_pressed("ui_accept") and not event.echo:
		if _can_play() and _pointer == NO_POINTER:
			var focused: Control = get_viewport().gui_get_focus_owner()
			for id in _tiles:
				if _tiles[id] == focused and _settled(_cell(int(id))):
					_keyboard_source = -1 if _keyboard_source == int(id) else int(id)
					game.set_held_tile(_keyboard_source)
					_refresh_marks()
					_publish()
					get_viewport().set_input_as_handled()
					return
	super._input(event)

func _press(pointer: int, global_point: Vector2) -> bool:
	# A completed tap speaks; pressing before a drag never reveals a partial root.
	if _pointer != NO_POINTER or not _can_play() or _finish_is_pulling() or game.collection_batch_active() or game.powerup_active():
		return false
	if _read_action_at(global_point):
		return false
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	var merging: String = _fusion_at(point)
	if not merging.is_empty() and game.hold_merge_for_drag(merging, true):
		_keyboard_source = -1
		_pointer = pointer
		_gesture_serial += 1
		_press_point = point
		_drag_point = point
		_tile_press_started_ms = Time.get_ticks_msec()
		for fusion: Dictionary in game.fusions:
			if str(fusion.attempt_id) == merging:
				_fusion_drag = {"event_id": merging, "offset": Vector2.ZERO, "moved": false, "result": fusion.result}
		_source = int(_fusion_drag.result.id)
		if game.is_valid_word(_fusion_drag.result):
			# Keep the captured lobe's identity if it moves away during the union.
			_fusion_tap = {"event_id": merging, "result_id": _source,
				"generation": _generation, "model_generation": game._generation}
		_dragging = false
		_target = -1
		_contact_cue_target = -1
		_contact_elapsed = 0.0
		_rejection.clear()
		audio_requested.emit("pick")
		_refresh_marks()
		_publish()
		return true
	if _preview_rect.has_point(point):
		_preview_generated = game.generated_tiles
		var accepted: bool = super._press(pointer, global_point)
		if not accepted:
			# A blocked supply row can still be read without dispatching it.
			_pointer = pointer
			_preview_first_id = _preview_identity()
			_preview_canceled = true
			_press_point = point
			accepted = true
		if accepted:
			for tile: WordTile in _preview_tiles:
				if tile.visible and tile.requires_read and tile.get_rect().has_point(point):
					_read_hold_id = tile.tile_id
					_read_hold_elapsed = 0.0
					break
		return accepted
	var id: int = _tile_at(point)
	if id < 0:
		return false
	_rejection.clear()
	_keyboard_source = -1
	_pointer = pointer
	_tile_press_started_ms = Time.get_ticks_msec()
	_gesture_serial += 1
	_source = id
	game.set_held_tile(id)
	_target = -1
	_contact_cue_target = -1
	_contact_elapsed = 0.0
	_press_point = point
	_drag_point = point
	_drag_offset = point - _tiles[id].position
	_dragging = false
	_read_hold_id = id if _tiles[id].requires_read else -1
	_read_hold_elapsed = 0.0
	audio_requested.emit("pick")
	_refresh_marks()
	_publish()
	return true

func _move(global_point: Vector2) -> void:
	if (get_global_transform().affine_inverse() * global_point).distance_to(_press_point) * Style.ui_scale(self) > 7.0:
		_fusion_tap.clear()
		# A deliberate drag supersedes a previously queued tap on this body.
		_queued_collections.erase(_source)
	if not _fusion_drag.is_empty():
		_drag_point = get_global_transform().affine_inverse() * global_point
		if _drag_point.distance_to(_press_point) * Style.ui_scale(self) > 7.0:
			_fusion_drag.moved = true
		if bool(_fusion_drag.moved):
			_fusion_drag.offset = _drag_point - _press_point
			_dragging = true
		if _defer_motion_visuals:
			return
		_sync_positions()
		_sound_contact()
		_publish()
		return
	if (get_global_transform().affine_inverse() * global_point).distance_to(_press_point) * Style.ui_scale(self) > 7.0:
		_read_hold_id = -1
	if _preview_first_id < 0 and not _dragging and _source >= 0:
		var point: Vector2 = get_global_transform().affine_inverse() * global_point
		if point.distance_to(_press_point) * Style.ui_scale(self) > 7.0:
			var source: int = _source
			var generation: int = _generation
			var serial: int = _gesture_serial
			# A press still supports its stack; an actual drag lifts that support.
			if not game.begin_drag(source):
				cancel_input()
				return
			if generation != _generation or serial != _gesture_serial or source != _source or not _can_play():
				return
	super._move(global_point)

func _release(global_point: Vector2) -> void:
	# Measure on release arrival, before motion rendering can turn a tap into a hold.
	var collection_click: bool = _tile_press_started_ms >= 0 \
		and Time.get_ticks_msec() - _tile_press_started_ms < COLLECTION_CLICK_MAX_MS
	_consume_drag_motion()
	if not _fusion_drag.is_empty() or not _fusion_tap.is_empty():
		_move(global_point)
	if not _fusion_tap.is_empty() and not _dragging and _pointer != NO_POINTER \
		and collection_click \
		and _can_play() and not _finish_is_pulling() and not game.collection_batch_active() and not game.powerup_active():
		# Finish the original animation, then collect its exact result once.
		_queued_collections[int(_fusion_tap.result_id)] = _fusion_tap.duplicate()
		cancel_input()
		_drain_queued_collections()
		return
	if not _fusion_drag.is_empty():
		if not bool(_fusion_drag.moved):
			cancel_input()
			return
		# A release commits the already accepted pair before the ordinary drop
		# resolves its new position or partner. Natural completion uses the same handoff.
		game.complete_merge_drag(str(_fusion_drag.event_id))
		if not _fusion_drag.is_empty() or _source < 0:
			cancel_input()
			return
	_read_hold_id = -1
	_read_hold_elapsed = 0.0
	_tile_press_started_ms = -1
	_fusion_tap.clear()
	if _preview_first_id >= 0:
		# A partial timed dispatch can leave the first slot unchanged while the
		# pressed packet has already departed through its other open columns.
		_preview_canceled = _preview_canceled or _preview_generated != game.generated_tiles
		super._release(global_point)
		return
	var source: int = _source
	var was_dragging: bool = _dragging
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	var valid_tap: bool = _can_play() and source >= 0 and not was_dragging \
		and point.distance_to(_press_point) * Style.ui_scale(self) <= 7.0 and _tile_at(point) == source \
		and (not game.is_valid_word(_cell(source)) or collection_click)
	super._release(global_point)
	if valid_tap:
		_tap_tile(source)
	game.set_held_tile(_keyboard_source)
	_sync_positions()

func _release_empty_space(source: int, from: Vector2) -> void:
	var destination: Dictionary = _placement_at(source, from, _drag_point)
	var generation: int = _generation
	if bool(destination.get("valid", false)) and game.reposition(source, int(destination.column), int(destination.row)):
		if generation != _generation or not _can_play():
			return
		_snapbacks.erase(source)
		var placed: Dictionary = game.cell(source)
		# Gravity reserves the supported destination immediately. Start its visual
		# fall at pointer-up, even when it lands back in the original board slot.
		_rest_rects[source] = _tile_rect(placed)
		if reduced_motion:
			_reflow.erase(source)
		else:
			_reflow[source] = {"from": from, "started": float(placed.age), "falling": bool(placed.get("falling", false))}
		_sync_positions()
		_refresh_hud()
		queue_redraw()
		audio_requested.emit("release")
	else:
		super._release_empty_space(source, from)

func _placement_at(id: int, from: Vector2, pointer: Vector2) -> Dictionary:
	if _pitch <= 0.0 or not _board.has_point(pointer) or not _tiles.has(id):
		return {}
	# Snap the held body's origin, preserving where the finger grabbed it.
	var grid: Vector2 = (from - _board.position - Vector2.ONE * _gap * 0.5) / _pitch
	var column: int = roundi(grid.x)
	var row: int = roundi(grid.y)
	var cell: Dictionary = game.cell(id)
	if cell.is_empty():
		return {}
	cell.column = column
	cell.row = row
	return {"tile_id": id, "column": column, "row": row, "valid": game.can_reposition(id, column, row),
		"rect": _tile_rect(cell)}

func _refresh_placement() -> void:
	_placement.clear()
	if _placement_tile == null:
		return
	_placement_tile.hide()
	if not _can_play() or not _dragging or _source < 0 or _target >= 0 or not _tiles.has(_source):
		return
	_placement = _placement_at(_source, _tiles[_source].position, _drag_point)
	if _placement.is_empty():
		return
	if _placement_tile.tile_id != _source:
		_configure_tile(_placement_tile, _cell(_source))
	_apply_palette(_placement_tile, _source)
	_placement_tile.position = _placement.rect.position
	_placement_tile.size = _placement.rect.size
	_placement_tile.set_projection(true)
	_placement_tile.set_support(0.0, 0.0, false)
	_placement_tile.modulate = Color(1.0, 1.0, 1.0, 0.42 if _placement.valid else 0.24)
	_placement_tile._gel.set_shader_parameter("rim_color", Color("#398b72") if _placement.valid else Color("#ce655b"))
	_placement_tile._gel.set_shader_parameter("rim_strength", 1.0)
	_placement_tile._gel.set_shader_parameter("rim_width", 1.5)
	_placement_tile.show()

func _activate(id: int) -> void:
	if not game.boss_interactable(id):
		return
	if not _can_play() or _pointer != NO_POINTER or _finish_is_pulling() or not _settled(_cell(id)) or game.collection_batch_active() or game.powerup_active():
		return
	_rejection.clear()
	if _keyboard_source >= 0 and _keyboard_source != id and _tiles.has(_keyboard_source):
		var source: int = _keyboard_source
		_keyboard_source = -1
		_merge(source, id, _tiles[source].position)
		game.set_held_tile()
	elif game.is_valid_word(_cell(id)):
		_collect(id)
	else:
		_keyboard_source = -1 if _keyboard_source == id else id
		game.set_held_tile(_keyboard_source)
		_refresh_marks()
		_publish()
		_speak_tile(id)

func _tap_tile(id: int) -> void:
	if game.is_valid_word(_cell(id)):
		_collect(id)
	else:
		_speak_tile(id)

func _pronunciation_word(tile: Dictionary) -> Dictionary:
	if str(tile.get("jelly_kind", "")) == "picture":
		return tile.get("image_word", {})
	if game.is_valid_word(tile):
		return tile.get("word", {})
	# Only a complete spelling has a candidate; a bound root stays silent.
	return tile.get("word_candidate", {})

func _speak_tile(id: int) -> void:
	if not _can_play() or _finish_is_pulling() or game.collection_batch_active() or game.powerup_active():
		return
	var tile: Dictionary = _cell(id)
	if tile.is_empty() or not _settled(tile):
		return
	var word: Dictionary = _pronunciation_word(tile)
	if not str(word.get("audio", "")).is_empty():
		word_requested.emit(word.duplicate(true))

func _collect(id: int) -> void:
	if not _can_play() or _finish_is_pulling() or game.collection_batch_active() or not game.is_valid_word(_cell(id)):
		return
	var generation: int = _generation
	if not game.collect(id) or generation != _generation or not _can_play():
		return
	if _keyboard_source == id:
		_keyboard_source = -1
		game.set_held_tile(_source)
	_refresh_controls()
	_refresh_fusion()
	_publish()

func _drain_queued_collections() -> void:
	for id: int in _queued_collections.keys():
		if not _can_play() or _finish_is_pulling() or game.collection_batch_active() or game.powerup_active():
			return
		var request: Dictionary = _queued_collections[id]
		if int(request.generation) != _generation or int(request.model_generation) != game._generation:
			_queued_collections.erase(id)
			continue
		var tile: Dictionary = game.cell(id)
		if tile.is_empty():
			if game._fusion_index(str(request.event_id)) < 0:
				_queued_collections.erase(id)
			continue
		if game.is_fusing(id) or not game.is_valid_word(tile):
			# Another collection or merge already owns this exact body.
			_queued_collections.erase(id)
			continue
		if not game.is_settled(tile) or game.is_lifted(id) or _pointer != NO_POINTER or _keyboard_source >= 0:
			continue
		# Consume before callbacks; a failed save keeps the ordinary explicit retry.
		_queued_collections.erase(id)
		_collect(id)
		if int(request.generation) != _generation or int(request.model_generation) != game._generation:
			return

func _collect_all() -> void:
	if not game.auto_collect_unlocked() or not _can_play() or _pointer != NO_POINTER or _finish_is_pulling() or game.collection_batch_active():
		return
	cancel_input()
	if game.start_collection_batch():
		batch_collection_started.emit()
	_refresh_controls()
	_refresh_fusion()
	_publish()

func _collection_started(fusion: Dictionary) -> void:
	if not _can_play():
		return
	var id: int = int(fusion.a_id)
	var origin: Vector2 = _tiles[id].get_global_rect().get_center() if _tiles.has(id) else get_global_transform() * _tile_rect(fusion.a).get_center()
	_collection_origins[str(fusion.attempt_id)] = origin
	var word: Dictionary = fusion.word
	var merge_level: int = clampi(int(fusion.get("merge_level", fusion.a.get("merge_level", 1))), 1, WordModel.MAX_MERGE_LEVEL)
	_word_reveal.set_reduced_motion(reduced_motion)
	var batch: bool = bool(fusion.get("batch", false))
	var initial_age: float = 0.0
	if batch and _reveal_frame_end >= 0.0 and _reveal_frame_generation == _generation \
		and int(fusion.get("batch_id", -1)) == _reveal_frame_batch:
		initial_age = maxf(0.0, _reveal_frame_end - float(game.collection_batch_snapshot().elapsed))
	var reveal_delay: float = float(fusion.pop_at)
	_word_reveal.present(word, _picture(word), _theme.get("accent", Style.GOOD), batch, initial_age, merge_level, reveal_delay)
	_collection_effects.set_reduced_motion(reduced_motion)
	_collection_effects.present(get_global_transform().affine_inverse() * origin,
		merge_level,
		_theme.get("accent", Style.GOOD), batch, initial_age, float(fusion.pop_at), str(fusion.attempt_id))
	# Batch pickups keep their pop rhythm without additional pronunciation.
	if not bool(fusion.get("batch", false)):
		word_requested.emit(word)
	_refresh_controls()
	_refresh_fusion()
	_publish()

func _collected(event_id: String, word: Dictionary, coins: int, fragments: int) -> void:
	_cue("danger_end")
	collect_button.beat()
	var origin: Vector2 = _collection_origins.get(event_id, get_global_rect().get_center())
	_collection_origins.erase(event_id)
	if fragments > 0 and not reduced_motion:
		_loot_flights.append({"from": get_global_transform().affine_inverse() * origin, "elapsed": 0.0, "amount": fragments})
	collected.emit(event_id, word, coins, fragments, origin)
	_refresh_hud()

func _merge(first: int, second: int, from: Vector2, held: Dictionary = {}, held_source: bool = false) -> void:
	var generation: int = _generation
	var result: String = game.try_merge(first, second, held_source)
	if generation != _generation or not _can_play():
		return
	if result == "merged":
		for fusion: Dictionary in game.fusions:
			if int(fusion.a_id) == first and int(fusion.b_id) == second:
				var visual: Dictionary = _ensure_fusion_visual(fusion)
				visual.start = from + _tile_rect(fusion.a).size * 0.5
				visual.origin_a = visual.start
				for key: String in ["origin_a", "origin_b", "stretch_a", "stretch_b"]:
					if held.has(key):
						visual[key] = held[key]
				break
		_snapbacks.erase(first)
		_snapbacks.erase(second)
		for id: int in [first, second]:
			_reflow.erase(id)
			_arrival_origins.erase(id)
		_rejection.clear()
	else:
		if result == "wrong":
			var direction: Vector2 = held.get("direction", Vector2.ZERO)
			if direction.length_squared() < 0.1:
				direction = (_tile_rect(_cell(second)).get_center() - _tile_rect(_cell(first)).get_center()).normalized()
			_rejection = {"a": first, "b": second, "elapsed": 0.0, "direction": direction}
		_snap_back(first, from)
	_sync_tiles()
	_refresh_fusion()
	_refresh_hud()
	_publish()

func _configure_tile(tile: Tile, cell: Dictionary, combined: bool = false) -> void:
	if cell.is_empty() or _surfaces.is_empty():
		return
	# Recolor one acquired painted skin, so matching hues also share shading.
	var presented: Dictionary = cell.duplicate()
	presented["merged_level_limit"] = game.merged_level_limit
	tile.configure(presented, _surfaces[0], _picture(cell.get("image_word", cell.get("word", {}))), _chest_texture, _theme.get("accent", Style.GOOD), combined)
	tile.set_merged_presentation(_presentation_elapsed, reduced_motion)
	_apply_palette(tile, int(cell.id))

func _apply_palette(tile: WordTile, id: int) -> void:
	var index: int = int(_palette_indices.get(id, _palette_cache.get(id, 0)))
	if tile.palette_index != index:
		tile.set_palette(index, Palette.hue(index))

func _begin_view_update() -> void:
	# These caches live only across a presentation pass, after model.step().
	# No time-, occupancy-, or return-space decision survives a simulation step.
	_view_update_active = true
	_view_cells.clear()
	for cell: Dictionary in game.cells:
		_view_cells[int(cell.id)] = cell
	_view_mergeable.clear()
	_view_drop_known = false
	_view_palette_ready = false
	_view_hints_ready = false

func _end_view_update() -> void:
	_view_update_active = false
	_view_cells.clear()
	_view_mergeable.clear()

func _cell(id: int) -> Dictionary:
	return _view_cells.get(id, {}) if _view_update_active else super._cell(id)

func _can_drop_preview() -> bool:
	if not _view_update_active:
		return game.can_drop_now()
	if not _view_drop_known:
		_view_drop_available = game.can_drop_now()
		_view_drop_known = true
	return _view_drop_available

func _can_merge_for_feedback(source: Dictionary, target: Dictionary) -> bool:
	if not _view_update_active:
		return game.can_merge(source, target)
	var pair := Vector2i(int(source.get("id", -1)), int(target.get("id", -1)))
	if not _view_mergeable.has(pair):
		_view_mergeable[pair] = game.can_merge(source, target)
	return bool(_view_mergeable[pair])

func _refresh_palette() -> void:
	if not _configured:
		return
	if _view_update_active and _view_palette_ready:
		return
	_view_palette_ready = true
	var items: Array[Dictionary] = []
	var reserved: Array[int] = []
	for cell: Dictionary in game.cells:
		if not game.is_fusing(int(cell.id)):
			items.append(cell)
	for active: Dictionary in game.fusions:
		for id: int in [int(active.a_id), int(active.b_id)]:
			var color: int = int(_palette_cache.get(id, -1))
			if color >= 0 and not color in reserved:
				reserved.append(color)
		if str(active.operation) == "merge":
			items.append(active.result)
	for item: Dictionary in game.upcoming:
		if item.has("id"):
			items.append(item)
	_palette.update(items, game._word_lookup, reserved)
	var selected: int = _source if _source >= 0 else _keyboard_source
	_palette_indices = _palette.selected(items, game._word_lookup, selected)
	for id: int in _palette_indices:
		_palette_cache[id] = _palette_indices[id]
	for id: int in _tiles:
		_apply_palette(_tiles[id], id)
	for preview: WordTile in _preview_tiles:
		if preview.tile_id >= 0:
			_apply_palette(preview, preview.tile_id)

func _sync_tiles() -> void:
	if not _configured:
		return
	var owns_update: bool = not _view_update_active
	if owns_update:
		_begin_view_update()
	if _preview_first_id >= 0 and _preview_generated != game.generated_tiles:
		_preview_canceled = true
		_set_preview_pressed(false)
	# The old preview still owns the departing IDs until this sync completes.
	# Keep the slot rather than screen pixels so a paused resize stays coherent.
	for cell: Dictionary in game.cells:
		if bool(cell.get("arrival", false)) and not _tiles.has(int(cell.id)):
			for index in range(_preview_tiles.size()):
				var preview: WordTile = _preview_tiles[index]
				if preview.tile_id == int(cell.id):
					_arrival_origins[int(cell.id)] = {"slot": index,
						"width": int(cell.get("width", 1)), "height": int(cell.get("height", 1)),
						"pressure": float(preview._gel.get_shader_parameter("preview_pressure")),
						"sway": float(preview._gel.get_shader_parameter("preview_sway")),
						"pull": float(preview._gel.get_shader_parameter("preview_pull"))}
					break
	_refresh_palette()
	var live: Dictionary = {}
	for cell: Dictionary in game.cells:
		var id: int = int(cell.id)
		live[id] = true
		if not _tiles.has(id):
			var tile := WordTile.new()
			tile.name = "WordJelly_%d" % id
			tile.pressed.connect(_activate.bind(id))
			tile.read_requested.connect(_show_read)
			add_child(tile)
			_tiles[id] = tile
			_configure_tile(tile, cell)
	for id in _tiles.keys():
		if not live.has(id):
			_tiles[id].hide()
			_tiles[id].queue_free()
			_tiles.erase(id)
			_snapbacks.erase(id)
			_rest_rects.erase(id)
			_reflow.erase(id)
			_arrival_origins.erase(id)
	_refresh_marks()
	_sync_positions()
	_refresh_controls()
	_sync_boss()
	if owns_update:
		_end_view_update()

func _sync_boss() -> void:
	if not _configured:
		return
	if _boss_view == null:
		if game.boss.active():
			game.error = "Boss presentation could not load. Restore the approved artwork and retry this stage."
			_requested_pause = true
			_apply_pause_reasons()
			push_error(game.error)
		return
	var rects: Dictionary = {}
	for tile: Dictionary in game.cells:
		rects[int(tile.id)] = _tile_rect(tile)
	for id: int in _tiles:
		_tiles[id].set_boss_status(game.boss.status(id), reduced_motion)
	_boss_view.reduced_motion = reduced_motion
	if not _boss_view.sync(game.boss.snapshot(), rects, _generation, _can_play(), _tiles):
		game.error = _boss_view._actor.last_error
		_requested_pause = true
		_apply_pause_reasons()

func _tile_rect(cell: Dictionary) -> Rect2:
	return Rect2(_board.position + Vector2(int(cell.get("column", 0)), int(cell.get("row", 0))) * _pitch + Vector2.ONE * _gap * 0.5,
		Vector2(int(cell.get("width", 1)), int(cell.get("height", 1))) * _pitch - Vector2.ONE * _gap)

func _arrival_rect(cell: Dictionary) -> Rect2:
	var origin: Dictionary = _arrival_origins.get(int(cell.id), {})
	if not origin.is_empty():
		var slot: int = int(origin.slot)
		var extent := Vector2(int(origin.get("width", 1)), int(origin.get("height", 1))) * _pitch - Vector2.ONE * _gap
		return Rect2(Vector2(_preview_rect.position.x + slot * _pitch + _gap * 0.5,
			_preview_rect.get_center().y - extent.y * 0.5), extent)
	var rect: Rect2 = _tile_rect(cell)
	rect.position.y = _board.position.y - _pitch + _gap * 0.5
	return rect

func _arrival_delay(cell: Dictionary) -> float:
	return WordModel.arrival_delay(cell)

func _sync_positions() -> void:
	var owns_update: bool = not _view_update_active
	if owns_update:
		_begin_view_update()
	_refresh_completion_hints()
	var preview_owners: Dictionary = {}
	if not reduced_motion:
		for cell: Dictionary in game.cells:
			var id: int = int(cell.id)
			if not bool(cell.get("arrival", false)) or not _arrival_origins.has(id):
				continue
			var departure: float = _arrival_delay(cell) - float(cell.age)
			if departure + WordModel.ARRIVAL_SLOT_CLEARANCE <= 0.0:
				continue
			var slot: int = int(_arrival_origins[id].slot)
			if not preview_owners.has(slot) or departure < float(preview_owners[slot].departure):
				preview_owners[slot] = {"id": id, "departure": departure}
	for cell: Dictionary in game.cells:
		var id: int = int(cell.id)
		if not _tiles.has(id):
			continue
		var tile: WordTile = _tiles[id]
		if game.is_fusing(id):
			# The union owns both captured bodies, including an interrupted fall.
			tile.hide()
			continue
		tile.set_merged_presentation(_presentation_elapsed, reduced_motion)
		var rect: Rect2 = _tile_rect(cell)
		if _rest_rects.has(id) and _rest_rects[id] != rect and not reduced_motion:
			_reflow[id] = {"from": tile.position, "started": 0.0 if bool(cell.get("falling", false)) else float(cell.age), "falling": bool(cell.get("falling", false))}
			if bool(cell.get("falling", false)):
				# One motion owns the new destination. Continuing a snapback first
				# would rewind the body when the slower fall takes over afterward.
				_snapbacks.erase(id)
		_rest_rects[id] = rect
		tile.size = rect.size
		tile._surface.show()
		tile.modulate.a = 1.0
		tile.visible = true
		var dragging: bool = id == _source and _dragging
		tile.z_index = 40 if dragging else 4 if tile.completion_hint else 1
		var stretch: Vector2 = Vector2.ONE
		var compression: float = 0.0
		var arrival: bool = bool(cell.get("arrival", false)) and not game.is_settled(cell)
		var shadow_visible: bool = true
		tile.set_preview_pressure(0.0, 0.0)
		if dragging:
			tile.position = _drag_point - _drag_offset
		else:
			tile.position = rect.position
			if arrival and not reduced_motion:
				# A rapid release may reserve another body in the same tray slot.
				# Let its predecessor leave before showing the waiting replacement.
				var slot: int = int(_arrival_origins.get(id, {}).get("slot", -1))
				if float(cell.age) < _arrival_delay(cell) and preview_owners.has(slot):
					tile.visible = tile.visible and int(preview_owners[slot].id) == id
				var source: Rect2 = _arrival_rect(cell)
				var age: float = maxf(0.0, float(cell.age) - _arrival_delay(cell))
				var contact: float = WordModel.arrival_contact_at(cell) - _arrival_delay(cell)
				var fall: float = clampf(age / contact, 0.0, 1.0)
				# Establish the lane near the rim; the body then accelerates vertically.
				var align: float = smoothstep(0.0, minf(0.28, contact * 0.45), age)
				tile.size = source.size.lerp(rect.size, align)
				tile.position = Vector2(lerpf(source.get_center().x, rect.get_center().x, align) - tile.size.x * 0.5,
					lerpf(source.position.y, rect.position.y, fall * fall))
				var moving: Dictionary = cell.duplicate()
				moving.age = age
				var pose: Dictionary = Motion.sample(moving)
				stretch = pose.stretch
				compression = float(pose.compression)
				var source_pose: Dictionary = _arrival_origins.get(id, {})
				var release: float = 1.0 - smoothstep(0.0, 0.12, age)
				var source_pull: float = float(source_pose.get("pull", 0.0))
				tile.set_preview_pressure(float(source_pose.get("pressure", 0.0)) * release, float(source_pose.get("sway", 0.0)) * release,
					source_pull * release)
				# Start the fall at the loaded belly, not the undeformed rectangle.
				# Releasing tension must never pull the visible foot back uphill.
				var loaded_foot: float = source.size.y * Motion.FOOT_Y * source_pull
				var remaining_pull: float = tile.size.y * Motion.FOOT_Y * source_pull * release * stretch.y
				tile.position.y += loaded_foot * (1.0 - fall * fall) - remaining_pull
				shadow_visible = align >= 1.0
				tile.z_index = 3
			elif _snapbacks.has(id) and not reduced_motion:
				var p: float = clampf(float(_snapbacks[id].elapsed) / 0.24, 0.0, 1.0)
				tile.position = Vector2(_snapbacks[id].from).lerp(rect.position, 1.0 - pow(1.0 - p, 3.0))
			elif _reflow.has(id) and not reduced_motion:
				var p: float = clampf((float(cell.age) - float(_reflow[id].started)) / WordModel.SETTLE_SECONDS, 0.0, 1.0)
				var falling: bool = bool(_reflow[id].falling)
				var travel: float = pow(minf(1.0, p / 0.70), 2.0) if falling else smoothstep(0.0, 1.0, p)
				tile.position = Vector2(_reflow[id].from).lerp(rect.position, travel)
				if falling and p >= 0.70:
					var landing: float = (p - 0.70) / 0.30
					var squash: float = sin(landing * TAU) * (1.0 - landing) * 0.12
					stretch = Vector2(1.0 + squash, 1.0 - squash)
				if p >= 1.0:
					_reflow.erase(id)
			elif bool(cell.get("settling", false)) and not reduced_motion:
				var p: float = clampf(float(cell.age) / WordModel.SETTLE_SECONDS, 0.0, 1.0)
				var bounce: float = sin(p * PI) * (1.0 - p) * 0.14
				stretch = Vector2(1.0 + bounce, 1.0 - bounce)
		tile.deform(0.0, 0.0, DRAG_STRETCH if dragging and not reduced_motion else stretch)
		var support_lift: float = maxf(0.0, rect.position.y - tile.position.y) if arrival or bool(cell.get("falling", false)) else 0.0
		tile.set_support(6.0 / Style.ui_scale(self) if dragging else support_lift, compression, shadow_visible)
	# Pose the pending body before testing contact, including on frames without
	# pointer motion while its two lobes continue to join.
	if not _fusion_drag.is_empty():
		_refresh_fusion()
	if _dragging:
		var target: int = _drag_target()
		if target != _target:
			_target = target
			_contact_elapsed = 0.0
			_refresh_marks()
	_refresh_contact()
	_refresh_placement()
	_pose_powerup()
	if owns_update:
		_end_view_update()

func _activate_powerup(kind: String) -> void:
	if not _can_play() or _pointer != NO_POINTER or _finish_is_pulling() or _keyboard_source >= 0:
		return
	game.activate_powerup(kind)
	_refresh_controls()
	_publish()

func _powerup_feedback(kind: String, success: bool) -> void:
	if powerup_buttons.has(kind):
		powerup_buttons[kind].feedback(success)
	_rejection.clear()
	_refresh_controls()
	_publish()

func _powerup_fragment_arrived(event: Dictionary) -> void:
	var id: int = int(event.tile_id)
	if _tiles.has(id):
		_configure_tile(_tiles[id], _cell(id))
	var age: float = 0.0
	if _powerup_frame_end >= 0.0 and _powerup_frame_generation == _generation and str(event.timeline_id) == _powerup_frame_receipt:
		age = maxf(0.0, _powerup_frame_end - float(event.at))
	if age < 0.48:
		_powerup_arrivals.append({"tile_id": id, "elapsed": age, "index": int(event.index)})

func _powerup_fusion_started(fusion: Dictionary) -> void:
	if not game.powerup_active() or str(fusion.operation) != "merge":
		return
	# The ordinary liquid union starts where the automatic drag has arrived.
	var visual: Dictionary = _ensure_fusion_visual(fusion)
	var destination: Vector2 = _tile_rect(fusion.b).get_center()
	visual["powerup_anchor"] = true
	visual.origin_a = destination
	visual.origin_b = destination
	visual.start = destination

func _powerup_stamp(stamps: Array[Dictionary], texture: Texture2D, center: Vector2, extent: Vector2, color: Color = Color.WHITE, angle: float = 0.0) -> void:
	stamps.append({"texture": texture, "center": center, "size": extent, "color": color, "rotation": angle})

func _pose_powerup() -> void:
	if _powerup_effects == null:
		return
	for tile: WordTile in _tiles.values():
		tile.set_fragment_arrival(-1.0, reduced_motion)
	_powerup_effects.visible = _can_play()
	var state: Dictionary = game.powerup_snapshot()
	var stamps: Array[Dictionary] = []
	var unit: float = maxf(8.0, _pitch)
	if bool(state.get("active", false)) and str(state.get("kind", "")) == "blast":
		_pose_blast_marks(state, stamps, unit)
	if bool(state.get("active", false)) and str(state.get("kind", "")) in ["auto_merge", "blast"]:
		for drag: Dictionary in state.get("drags", []):
			var source: Dictionary = drag.get("source", {})
			var target: Dictionary = drag.get("target", {})
			var id: int = int(drag.get("source_id", -1))
			if source.is_empty() or target.is_empty() or not _tiles.has(id):
				continue
			var from: Rect2 = _tile_rect(source)
			var to: Vector2 = _tile_rect(target).get_center()
			var t: float = clampf(float(drag.elapsed) / maxf(0.01, float(drag.duration)), 0.0, 1.0)
			var p: float = t if reduced_motion else smoothstep(0.0, 1.0, t)
			var lift: float = 0.0 if reduced_motion else sin(p * PI) * minf(unit * 0.65, from.get_center().distance_to(to) * 0.18)
			var tile: WordTile = _tiles[id]
			tile.position = from.get_center().lerp(to, p) - from.size * 0.5 - Vector2(0.0, lift)
			tile.z_index = 42
			tile.deform(0.0, 0.0, Vector2.ONE if reduced_motion else Vector2(1.0 + sin(p * PI) * 0.09, 1.0 - sin(p * PI) * 0.05))
			tile.set_support(lift, 0.0)
			_powerup_stamp(stamps, COLLECTION_GLOW, to, Vector2.ONE * unit * 1.65, Color(1.0, 0.91, 0.6, 0.30))
			if not reduced_motion:
				for index in range(4):
					var trail: float = maxf(0.0, p - 0.055 * float(index + 1))
					var point: Vector2 = from.get_center().lerp(to, trail) - Vector2(0.0, sin(trail * PI) * minf(unit * 0.65, from.get_center().distance_to(to) * 0.18))
					_powerup_stamp(stamps, POWERUP_SPARKLE, point, Vector2.ONE * unit * (0.20 - index * 0.03), Color(1.0, 0.92, 0.63, 0.7 - index * 0.14), trail * TAU)
	elif bool(state.get("active", false)) and str(state.get("kind", "")) == "fragments" and powerup_buttons.has("fragments"):
		var start: Vector2 = powerup_buttons.fragments.get_rect().get_center()
		for arrival: Dictionary in state.get("arrivals", []):
			var id: int = int(arrival.tile_id)
			var remaining: float = float(arrival.at) - float(state.elapsed)
			if bool(arrival.get("arrived", false)) or remaining < 0.0 or remaining > WordModel.POWERUP_FRAGMENT_FLIGHT or not _tiles.has(id):
				continue
			var t: float = clampf(1.0 - remaining / WordModel.POWERUP_FRAGMENT_FLIGHT, 0.0, 1.0)
			var target: Vector2 = _tiles[id].get_rect().get_center()
			var point: Vector2 = start.lerp(target, smoothstep(0.0, 1.0, t))
			if not reduced_motion:
				point += Vector2(sin(t * PI) * unit * 0.4 * (-1.0 if int(arrival.index) % 2 == 0 else 1.0), -sin(t * PI) * unit * 0.55)
			_powerup_stamp(stamps, COLLECTION_GLOW, point, Vector2.ONE * unit, Color(1.0, 0.85, 0.4, 0.48))
			_powerup_stamp(stamps, _chest_texture, point, Vector2.ONE * unit * 0.5, Color.WHITE, 0.0 if reduced_motion else sin(t * PI) * 0.25)
	for arrival: Dictionary in _powerup_arrivals:
		var id: int = int(arrival.tile_id)
		if not _tiles.has(id):
			continue
		_tiles[id].set_fragment_arrival(float(arrival.elapsed), reduced_motion)
		var t: float = clampf(float(arrival.elapsed) / 0.48, 0.0, 1.0)
		var center: Vector2 = _tiles[id].get_rect().get_center()
		var envelope: float = 1.0 - t
		_powerup_stamp(stamps, COLLECTION_GLOW, center, Vector2.ONE * unit * (1.7 if reduced_motion else 1.2 + t), Color(1.0, 0.88, 0.45, envelope * 0.6))
		for index in range(4):
			var angle: float = float(index) * TAU / 4.0 + 0.35
			var radius: float = unit * (0.48 if reduced_motion else 0.30 + t * 0.4)
			_powerup_stamp(stamps, POWERUP_SPARKLE, center + Vector2.from_angle(angle) * radius,
				Vector2.ONE * unit * (0.18 if reduced_motion else 0.28 * envelope), Color(1.0, 0.94, 0.65, envelope), angle)
	_powerup_effects.present(stamps)


func _pose_blast_marks(state: Dictionary, stamps: Array[Dictionary], unit: float) -> void:
	var blast: Dictionary = state.get("blast", {})
	var ids: Array = blast.get("target_ids", [])
	var group_size: int = maxi(1, int(blast.get("group_size", 1)))
	var clock: float = float(state.clock)
	var last_launch: float = WordModel.BLAST_MARK_WINDUP_SECONDS \
		+ floorf(float(maxi(0, ids.size() - 1)) / group_size) * WordModel.BLAST_MARK_BEAT_SECONDS
	var sources: Dictionary = {}
	for index in range(ids.size()):
		var id: int = int(ids[index])
		if not _tiles.has(id) or not blast.origins.has(id):
			continue
		var origin: Dictionary = blast.origins[id]
		var level: int = int(origin.level)
		var tint := Color.from_hsv(float(CollectionEffects.profile(level).hue), 0.62, 1.0)
		var center: Vector2 = _tiles[id].get_rect().get_center()
		var start: Vector2 = _tile_rect(origin).get_center()
		var source_key := Vector2i(int(origin.column), int(origin.row))
		if not sources.has(source_key) and clock < last_launch + 0.20:
			sources[source_key] = true
			var charge: float = 1.0 if reduced_motion else smoothstep(0.0, WordModel.BLAST_MARK_WINDUP_SECONDS, clock)
			var source_fade: float = 1.0 - smoothstep(last_launch, last_launch + 0.20, clock)
			_powerup_stamp(stamps, COLLECTION_GLOW, start, Vector2.ONE * unit * (1.0 + charge * 1.10),
				Color(tint, source_fade * 0.82))
			_powerup_stamp(stamps, POWERUP_RAYS, start, Vector2.ONE * unit * (0.48 + charge * 0.72),
				Color(tint.lightened(0.35), source_fade * 0.72))
		var launch_at: float = WordModel.BLAST_MARK_WINDUP_SECONDS \
			+ floorf(float(index) / group_size) * WordModel.BLAST_MARK_BEAT_SECONDS
		var age: float = clock - launch_at
		if age < 0.0:
			continue
		var impact_age: float = age - WordModel.BLAST_MARK_FLIGHT_SECONDS
		if impact_age < 0.0:
			if not reduced_motion:
				var direction: Vector2 = center - start
				var travel: float = pow(clampf(age / WordModel.BLAST_MARK_FLIGHT_SECONDS, 0.0, 1.0), 2.2)
				var point: Vector2 = start.lerp(center, travel)
				for tail in range(5, 0, -1):
					var prior: float = maxf(0.0, age - tail * 0.018)
					var behind: Vector2 = start.lerp(center, pow(prior / WordModel.BLAST_MARK_FLIGHT_SECONDS, 2.2))
					var strength: float = 1.0 - tail / 6.0
					_powerup_stamp(stamps, POWERUP_SPARKLE, behind,
						Vector2(unit * (0.22 + strength * 0.22), unit * 0.12),
						Color(tint, strength * 0.78), direction.angle())
				_powerup_stamp(stamps, COLLECTION_GLOW, point, Vector2.ONE * unit * 0.72, Color(tint, 0.86))
				_powerup_stamp(stamps, POWERUP_SPARKLE, point, Vector2(unit * 0.42, unit * 0.30),
					Color(tint.lightened(0.50), 1.0), direction.angle())
			continue
		if index >= int(blast.marked):
			continue
		var pulse: float = 0.50 if reduced_motion else 1.0 - smoothstep(0.04, 0.26, impact_age)
		_powerup_stamp(stamps, COLLECTION_GLOW, center, Vector2.ONE * unit * 1.55, Color(tint, 0.18 + pulse * 0.56))
		if not reduced_motion and impact_age < 0.22:
			_powerup_stamp(stamps, POWERUP_RAYS, center, Vector2.ONE * unit * (0.78 + impact_age * 2.2),
				Color(tint.lightened(0.35), pulse * 0.78))
		for spark in range(4):
			var angle: float = spark * TAU / 4.0
			var point: Vector2 = center + Vector2.from_angle(angle) * unit * (0.43 + pulse * 0.08)
			_powerup_stamp(stamps, POWERUP_SPARKLE, point, Vector2.ONE * unit * (0.14 + pulse * 0.14),
				Color(tint.lightened(0.45), 0.48 + pulse * 0.48), angle)
		if not reduced_motion and impact_age < 0.30:
			var load: float = smoothstep(0.0, 0.035, impact_age) * (1.0 - smoothstep(0.055, 0.13, impact_age)) * 0.22
			var rebound: float = sin(clampf((impact_age - 0.10) / 0.18, 0.0, 1.0) * PI) * 0.06
			var squeeze: float = load - rebound
			# The foot and shadow stay planted; only the acquired gel skin takes the load.
			_tiles[id].deform(squeeze * 0.12, impact_age * 20.0, Vector2(1.0 + squeeze * 0.68, 1.0 - squeeze))
			_tiles[id].set_support(0.0, maxf(0.0, squeeze) / 0.22)


func _sync_preview() -> void:
	drop_button.queue_redraw()
	_preview_drop_available = _can_drop_preview()
	var refills: Array[float] = []
	refills.resize(_preview_tiles.size())
	refills.fill(1.0)
	if not reduced_motion:
		for cell: Dictionary in game.cells:
			if bool(cell.get("arrival", false)) and _arrival_origins.has(int(cell.id)):
				var slot: int = int(_arrival_origins[int(cell.id)].slot)
				# Each departing body frees its own preview slot. Later roots can
				# keep waiting while the cleared slots quietly refill behind them.
				for lane in range(slot, mini(WordModel.COLUMNS, slot + int(cell.get("width", 1)))):
					refills[lane] = minf(refills[lane], (float(cell.age) - _arrival_delay(cell) - 0.18) / 0.18)
	for index in range(_preview_tiles.size()):
		var preview: Tile = _preview_tiles[index]
		var refill: float = refills[index]
		var available: bool = _configured and index < game.upcoming.size() and game.upcoming[index].has("id")
		preview.visible = available and refill > 0.0
		if not available:
			preview.tile_id = -1
			continue
		var item: Dictionary = game.upcoming[index]
		for lane in range(index, mini(WordModel.COLUMNS, index + int(item.get("width", 1)))):
			refill = minf(refill, refills[lane])
		preview.visible = refill > 0.0
		# A rapid tap can release a refilling slot before it becomes visible.
		# Keep its identity current so that departure still owns the right origin.
		if preview.tile_id != int(item.id):
			_configure_tile(preview, item)
		_apply_palette(preview, int(item.id))
		preview.set_merged_presentation(_presentation_elapsed, reduced_motion)
		var pose: Dictionary = _preview_pose(index)
		preview.size = Vector2(int(item.get("width", 1)), int(item.get("height", 1))) * _pitch - Vector2.ONE * _gap
		_preview_origins[index] = Vector2(_preview_rect.position.x + index * _pitch + _gap * 0.5,
			_preview_rect.get_center().y - preview.size.y * 0.5)
		preview.position = _preview_origins[index]
		preview.modulate.a = clampf(refill, 0.0, 1.0)
		preview.deform(0.0, 0.0)
		preview.set_preview_pressure(float(pose.pressure), float(pose.sway), float(pose.pull))
	_refresh_preview_read_controls()

func _refresh_preview_read_controls() -> void:
	for preview: WordTile in _preview_tiles:
		var available: bool = preview.visible and preview.requires_read and _can_play() and not _finish_is_pulling() \
			and not game.collection_batch_active() and not game.powerup_active()
		preview.disabled = not available
		preview.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE

func _preview_pose(index: int) -> Dictionary:
	return Motion.preview(game.spawn_elapsed, game.spawn_interval, index, reduced_motion or game.phase != "playing" or not _preview_drop_available)

func _process(delta: float) -> void:
	_consume_drag_motion()
	if _read_hold_id >= 0 and _pointer != NO_POINTER and not _dragging and _can_play() and delta <= 0.5:
		_read_hold_elapsed += delta
		if _read_hold_elapsed >= READ_HOLD_SECONDS:
			var id: int = _read_hold_id
			_read_hold_id = -1
			_show_read(id)
	if _room_notice_remaining > 0.0:
		_room_notice_remaining = maxf(0.0, _room_notice_remaining - delta)
		_room_notice.visible = _room_notice_remaining > 0.0
	if _finish_is_pulling():
		if _layout_too_small and can_finish_round() and delta <= 0.5:
			# The header owns this pull; the board remains paused underneath it.
			_publish()
		else:
			super._process(delta)
		return
	_reveal_frame_end = -1.0
	_powerup_frame_end = -1.0
	if _can_play() and delta <= 0.5:
		var board_delta: float = game.presentation_delta(delta)
		_combo_hud.advance(delta)
		_practice_panel.advance(delta)
		_stage_banner.advance(delta)
		_practice_panel.queue_redraw()
		_presentation_elapsed += board_delta
		_collection_effects.advance(board_delta)
		var powerup: Dictionary = game.powerup_snapshot()
		if bool(powerup.active) and str(powerup.kind) == "fragments":
			_powerup_frame_end = float(powerup.elapsed) + delta
			_powerup_frame_receipt = str(powerup.receipt_id)
			_powerup_frame_generation = _generation
		_word_reveal.advance(board_delta)
		if game.collection_batch_active():
			# New cards keep their collection offsets even when a frame spans several beats.
			_reveal_frame_end = float(game.collection_batch_snapshot().elapsed) + delta
			_reveal_frame_batch = game._collection_batch_serial
			_reveal_frame_generation = _generation
		collect_button.advance(delta)
		for button: PowerupButton in powerup_buttons.values():
			button.advance(delta)
		for arrival: Dictionary in _powerup_arrivals:
			arrival.elapsed += delta
		_powerup_arrivals = _powerup_arrivals.filter(func(item: Dictionary) -> bool: return float(item.elapsed) < 0.48)
		if _completion_source >= 0:
			_completion_elapsed += board_delta
	var generation: int = _generation
	var previous_rows: Dictionary = {}
	for cell: Dictionary in game.cells:
		previous_rows[int(cell.id)] = int(cell.row)
	super._process(delta)
	_reveal_frame_end = -1.0
	_powerup_frame_end = -1.0
	# Dispatch outside the model step, including on a full board or landing frame.
	if generation == _generation and delta <= 0.5:
		_drain_queued_collections()
	if generation != _generation or not _can_play() or game.full_elapsed >= 0.0 or _landing_cooldown > 0.0:
		return
	# A long frame can finish collection and pass the new fall's contact time.
	# The inherited age-crossing check still sees the previous settled age.
	for cell: Dictionary in game.cells:
		if bool(cell.get("falling", false)) and int(cell.row) > int(previous_rows.get(int(cell.id), cell.row)) \
			and float(cell.age) >= _landing_contact_at(cell):
			_landing_cooldown = 0.12
			audio_requested.emit("land")
			break

func _refresh_marks() -> void:
	var feedback_enabled: bool = _can_play()
	var completing: bool = _contact_state().kind == "match"
	for id: int in _tiles:
		_tiles[id].set_marked(id == _target and completing, id == _source or _queued_collections.has(id),
			feedback_enabled and not game.is_fusing(id), reduced_motion)
	_refresh_contact()
	_refresh_palette()
	if _keyboard_source >= 0 and _tiles.has(_keyboard_source):
		_tiles[_keyboard_source].set_marked(false, true, _can_play(), reduced_motion)
	_refresh_completion_hints()

func _refresh_completion_hints() -> void:
	var source: int = (_source if _source >= 0 else _keyboard_source) if _can_play() and not game.collection_batch_active() else -1
	if _view_update_active and _view_hints_ready and _view_hint_source == source:
		return
	_view_hints_ready = true
	_view_hint_source = source
	if source != _completion_source:
		_completion_source = source
		_completion_elapsed = 0.0
	var prefix: Dictionary = _feedback_source() if source == _source else _cell(source)
	var has_matches: bool = false
	for id: int in _tiles:
		var target: Dictionary = _cell(id)
		var same_word: bool = str(prefix.get("jelly_kind", "")) == "merged" \
			and str(target.get("jelly_kind", "")) == "merged" and id != source \
			and not prefix.get("word", {}).is_empty() \
			and str(prefix.word.id) == str(target.get("word", {}).get("id", ""))
		var eligible: bool = not prefix.is_empty() and (not _fusion_drag.is_empty() or _settled(prefix)) and game.is_contactable(target) \
			and (same_word or _can_merge_for_feedback(prefix, target))
		_tiles[id].set_completion_hint(eligible, _completion_elapsed, reduced_motion)
		has_matches = has_matches or eligible
	for id: int in _tiles:
		_tiles[id].set_match_dimmed(has_matches and id != source and not _tiles[id].completion_hint)

func _drag_target() -> int:
	# A nearby valid match must remain reachable through crowded neighbors.
	var source: WordTile = _feedback_body()
	if source == null:
		return -1
	var outlines: Array[PackedVector2Array] = _feedback_outlines(source)
	# Forgive a slight painted-edge gap without advertising a remote merge.
	var reach: float = minf(minf(source.size.x, source.size.y) * 0.06, 4.0 / Style.ui_scale(self))
	var pending: Dictionary = _feedback_source()
	var bounds: Rect2 = _outline_bounds(outlines[0])
	for outline: PackedVector2Array in outlines:
		bounds = bounds.merge(_outline_bounds(outline))
	bounds = bounds.grow(reach)
	var expanded: Array[PackedVector2Array] = []
	var nearest: int = -1
	var nearest_distance: float = INF
	for cell: Dictionary in game.cells:
		var id: int = int(cell.id)
		if id == _source or not game.is_contactable(cell) or not _tiles.has(id) or not _tiles[id].visible:
			continue
		var target: WordTile = _tiles[id]
		if not bounds.intersects(target.get_rect()) or not _can_merge_for_feedback(pending, cell):
			continue
		var distance: float = source.get_rect().get_center().distance_squared_to(target.get_rect().get_center())
		if distance > nearest_distance or (is_equal_approx(distance, nearest_distance) and id != _target):
			continue
		if expanded.is_empty():
			for outline: PackedVector2Array in outlines:
				expanded.append_array(Geometry2D.offset_polygon(outline, reach, Geometry2D.JOIN_ROUND))
		for area: PackedVector2Array in expanded:
			if not Geometry2D.intersect_polygons(area, target.contact_outline()).is_empty():
				nearest = id
				nearest_distance = distance
				break
	if nearest >= 0:
		return nearest
	return _touching_target(outlines, source)

func _feedback_source() -> Dictionary:
	# A reserved result can preview its next interaction without entering the
	# model's cell list or completing the accepted merge ahead of its clock.
	return _fusion_drag.result if not _fusion_drag.is_empty() else _cell(_source)

func _feedback_body() -> WordTile:
	if not _fusion_drag.is_empty():
		return _fusion_visuals.get(str(_fusion_drag.event_id), {}).get("merged")
	return _tiles.get(_source)

func _feedback_outlines(source: WordTile) -> Array[PackedVector2Array]:
	var outlines: Array[PackedVector2Array] = []
	if not _fusion_drag.is_empty() and not reduced_motion:
		var visual: Dictionary = _fusion_visuals.get(str(_fusion_drag.event_id), {})
		if not visual.is_empty() and visual.art.visible and float(visual.merged._surface.modulate.a) < 0.5:
			# Sample both painted lobes, excluding pressure deformation so contact
			# cannot move its own hit threshold and flicker on and off.
			for key: String in ["body_a", "body_b"]:
				var body: Vector4 = visual.art._gel.get_shader_parameter(key)
				var outline := PackedVector2Array()
				for point: Vector2 in source._contact_outline:
					outline.append(visual.art.position + Vector2(body.x, body.y) + (point - Vector2.ONE * 0.5) * Vector2(body.z, body.w))
				outlines.append(outline)
	if outlines.is_empty():
		outlines.append(source.contact_outline(Vector2.ONE if reduced_motion else DRAG_STRETCH))
	return outlines

func _touching_target(outlines: Array[PackedVector2Array], source: WordTile) -> int:
	var nearest: int = -1
	var nearest_distance: float = INF
	for cell: Dictionary in game.cells:
		var id: int = int(cell.id)
		if id == _source or not game.is_contactable(cell) or not _tiles.has(id) or not _tiles[id].visible:
			continue
		var target: WordTile = _tiles[id]
		var distance: float = source.get_rect().get_center().distance_squared_to(target.get_rect().get_center())
		if distance > nearest_distance or (is_equal_approx(distance, nearest_distance) and id != _target):
			continue
		var target_outline: PackedVector2Array = target.contact_outline()
		for outline: PackedVector2Array in outlines:
			if _outline_bounds(outline).intersects(_outline_bounds(target_outline), true) \
				and not Geometry2D.intersect_polygons(outline, target_outline).is_empty():
				nearest = id
				nearest_distance = distance
				break
	return nearest

func _fusion_at(point: Vector2) -> String:
	for fusion: Dictionary in game.fusions:
		if str(fusion.operation) != "merge" or bool(fusion.get("automatic", false)):
			continue
		var visual: Dictionary = _fusion_visuals.get(str(fusion.attempt_id), {})
		if visual.is_empty():
			continue
		if reduced_motion or float(visual.merged.modulate.a) > 0.2:
			if visual.merged.get_rect().has_point(point):
				return str(fusion.attempt_id)
		if not visual.art.visible:
			continue
		for key: String in ["body_a", "body_b"]:
			var body: Vector4 = visual.art._gel.get_shader_parameter(key)
			var extent := Vector2(body.z, body.w) * 0.86
			var center: Vector2 = visual.art.position + Vector2(body.x, body.y)
			if Rect2(center - extent * 0.5, extent).has_point(point):
				return str(fusion.attempt_id)
	return ""

func navigation_controls() -> Array[Control]:
	if _read_panel != null and _read_panel.visible:
		return _read_panel.navigation_controls()
	if not _can_play():
		return super.navigation_controls()
	var controls: Array[Control] = []
	var ordered: Array = game.cells.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.row) * WordModel.COLUMNS + int(a.column) < int(b.row) * WordModel.COLUMNS + int(b.column))
	for cell: Dictionary in ordered:
		if _settled(cell) and _tiles.has(int(cell.id)) and not game.collection_batch_active() and not game.powerup_active():
			controls.append(_tiles[int(cell.id)])
	for preview: WordTile in _preview_tiles:
		if preview.is_visible_in_tree() and not preview.disabled:
			controls.append(preview)
	if not collect_button.disabled:
		controls.append(collect_button)
	for button: PowerupButton in powerup_buttons.values():
		if button.visible and not button.disabled:
			controls.append(button)
	if not drop_button.disabled:
		controls.append(drop_button)
	if not _chest_tap.disabled:
		controls.append(_chest_tap)
	if not finish_button.disabled:
		controls.append(finish_button)
	return controls

func _contact_state() -> Dictionary:
	var state := {"kind": "none", "source": -1, "target": -1, "strength": 0.0, "direction": Vector2.ZERO}
	if not _can_play():
		return state
	if not _rejection.is_empty():
		state.merge({"kind": "mismatch", "source": int(_rejection.a), "target": int(_rejection.b),
			"strength": sin(clampf(float(_rejection.elapsed) / 0.34, 0.0, 1.0) * PI), "direction": _rejection.direction}, true)
		return state
	if not _dragging or _source < 0 or _target < 0 or not _tiles.has(_target):
		return state
	var source: Dictionary = _feedback_source()
	var target: Dictionary = _cell(_target)
	var body: WordTile = _feedback_body()
	if body == null or source.is_empty() or (_fusion_drag.is_empty() and not _settled(source)) or not game.is_contactable(target):
		return state
	# All painted bodies respond to pressure. Only a forward word earns the
	# separate completion highlight. A failed drop is rejected only on release.
	var completing: bool = _can_merge_for_feedback(source, target)
	var direction: Vector2 = (_tiles[_target].get_rect().get_center() - body.get_rect().get_center()).normalized()
	if direction.length_squared() < 0.1:
		direction = (_tile_rect(target).get_center() - _tile_rect(source).get_center()).normalized()
	state.merge({"kind": "match" if completing else "touch", "source": _source, "target": _target,
		"strength": lerpf(0.2, 0.65, smoothstep(0.0, 0.14, _contact_elapsed)), "direction": direction}, true)
	return state

func _refresh_contact() -> void:
	super._refresh_contact()
	var state: Dictionary = _contact_state()
	for event_id: String in _fusion_visuals:
		var visual: Dictionary = _fusion_visuals[event_id]
		var held: bool = event_id == str(_fusion_drag.get("event_id", ""))
		var kind: String = str(state.kind) if held else "none"
		var acknowledged: bool = _can_play() and (event_id == str(_fusion_tap.get("event_id", "")) \
			or _queued_collections.has(int(visual.merged.tile_id)))
		if kind == "none" and acknowledged:
			# Reuse the neutral contact rim without deforming the ongoing union.
			visual.merged.set_contact("touch", Vector2.ZERO, 0.0, reduced_motion)
			visual.art.set_contact("touch", Vector2.ZERO, 0.0, reduced_motion)
		else:
			visual.merged.set_contact(kind, state.direction, float(state.strength), reduced_motion)
			visual.art.set_contact(kind, state.direction, float(state.strength), reduced_motion)

func _ensure_fusion_visual(fusion: Dictionary) -> Dictionary:
	var id: String = str(fusion.attempt_id)
	if not _fusion_visuals.has(id):
		_refresh_palette()
		var art := FusionArt.new()
		art.z_index = 25
		add_child(art)
		art.configure(SURFACES, 0, 0, _surfaces[0])
		var color_a: int = int(_palette_cache.get(int(fusion.a_id), 0))
		var color_b: int = int(_palette_cache.get(int(fusion.b_id), 0))
		art._gel.set_shader_parameter("palette_hue_a", Palette.hue(color_a))
		art._gel.set_shader_parameter("palette_hue_b", Palette.hue(color_b))
		var merged := WordTile.new()
		merged.focus_mode = Control.FOCUS_NONE
		merged.disabled = true
		merged.z_index = 30
		add_child(merged)
		_configure_tile(merged, fusion.result if str(fusion.operation) == "merge" else fusion.a)
		_fusion_visuals[id] = {"art": art, "merged": merged,
			"start": _tile_rect(fusion.a).get_center(), "direction": Vector2.RIGHT,
			"origin_a": _tile_rect(fusion.a).get_center(), "origin_b": _tile_rect(fusion.b).get_center(),
			"stretch_a": Vector2.ONE, "stretch_b": Vector2.ONE,
			"palette_a": color_a, "palette_b": color_b}
	return _fusion_visuals[id]

func _remove_fusion_visual(id: String) -> void:
	var glow: TextureRect = _fusion_visuals[id].get("collect_glow")
	if glow != null:
		glow.hide()
		glow.queue_free()
	for spark: TextureRect in _fusion_visuals[id].get("charge_sparks", []):
		spark.hide()
		spark.queue_free()
	super._remove_fusion_visual(id)

func _collection_glow(visual: Dictionary) -> TextureRect:
	if not visual.has("collect_glow"):
		var glow: TextureRect = _image(self)
		glow.texture = COLLECTION_GLOW
		glow.z_index = 29
		visual["collect_glow"] = glow
	return visual.collect_glow

func _pose_collection_charge(fusion: Dictionary, visual: Dictionary, rect: Rect2) -> void:
	var elapsed: float = float(fusion.elapsed)
	var pop_at: float = float(fusion.pop_at)
	var contraction: float = smoothstep(0.0, 0.22, elapsed)
	var charge: float = smoothstep(0.18, pop_at, elapsed)
	var release: float = smoothstep(pop_at, pop_at + 0.14, elapsed)
	var compressed: float = lerpf(1.0, 0.58, contraction)
	compressed += sin(charge * PI * 3.0) * 0.025 * contraction * (1.0 - release)
	var merged: WordTile = visual.merged
	merged.scale = Vector2.ONE if reduced_motion else Vector2.ONE * lerpf(compressed, 1.28, release)
	merged.modulate.a = 1.0 - release
	var edge: float = maxf(rect.size.y, _pitch)
	var center: Vector2 = rect.get_center()
	var glow: TextureRect = _collection_glow(visual)
	glow.size = Vector2.ONE * edge * (0.88 if reduced_motion else lerpf(1.55, 0.82, charge))
	glow.position = center - glow.size * 0.5
	glow.modulate = Color("#ffe3a1", (0.22 + charge * 0.53) * (1.0 - release))
	glow.show()
	if not reduced_motion and not visual.has("charge_sparks"):
		var sparks: Array[TextureRect] = []
		for index in range(8):
			var spark: TextureRect = _image(self)
			spark.texture = POWERUP_SPARKLE
			spark.z_index = 31
			sparks.append(spark)
		visual["charge_sparks"] = sparks
	for index in range(visual.get("charge_sparks", []).size()):
		var spark: TextureRect = visual.charge_sparks[index]
		var angle: float = TAU * float(index) / 8.0 + charge * 0.24
		var inward: float = smoothstep(0.08 + float(index % 3) * 0.04, 0.96, charge)
		var point: Vector2 = center + Vector2.from_angle(angle) * edge * lerpf(0.86, 0.12, inward)
		spark.size = Vector2.ONE * edge * lerpf(0.20, 0.09, inward)
		spark.position = point - spark.size * 0.5
		spark.modulate = Color("#ffc957", smoothstep(0.0, 0.16, charge) * (1.0 - release))
		spark.visible = not reduced_motion and elapsed < pop_at + 0.14

func _pose_fusion(fusion: Dictionary, visual: Dictionary) -> void:
	var merged: WordTile = visual.merged
	merged.set_merged_presentation(_presentation_elapsed, reduced_motion)
	_apply_palette(merged, int(fusion.result.id) if str(fusion.operation) == "merge" else int(fusion.a_id))
	var art: Control = visual.art
	var p: float = clampf(float(fusion.elapsed) / float(fusion.duration), 0.0, 1.0)
	var collecting: bool = str(fusion.operation) == "collect"
	for id in [int(fusion.a_id), int(fusion.b_id)]:
		if _tiles.has(id):
			_tiles[id].hide()
	if collecting:
		art.hide()
		var rect: Rect2 = _tile_rect(fusion.a)
		merged.size = rect.size
		merged.position = rect.position
		merged.pivot_offset = rect.size * 0.5
		merged.rotation = 0.0
		merged._surface.show()
		var pop_progress: float = float(fusion.pop_at) / float(fusion.duration)
		var charge: float = smoothstep(0.0, pop_progress, p)
		var release: float = smoothstep(pop_progress, 1.0, p)
		merged.scale = Vector2.ONE if reduced_motion else Vector2(1.0 + charge * 0.12, 1.0 - charge * 0.12).lerp(Vector2.ONE * 0.18, release)
		merged.modulate.a = 1.0 - release
		if not bool(fusion.get("batch", false)) and int(fusion.get("merge_level", 1)) >= 4:
			_pose_collection_charge(fusion, visual, rect)
		elif bool(fusion.get("batch", false)) and not reduced_motion:
			var direction: float = -1.0 if int(fusion.batch_index) % 2 == 0 else 1.0
			var lift: float = sin(release * PI * 0.5)
			merged.position += Vector2(direction * _pitch * 0.28 * release, -_pitch * 0.72 * lift)
			merged.rotation = direction * 0.12 * release
			var glow: TextureRect = _collection_glow(visual)
			glow.size = Vector2.ONE * maxf(rect.size.y, _pitch) * (1.2 + release * 0.5)
			glow.position = merged.position + rect.size * 0.5 - glow.size * 0.5
			glow.modulate = Color("#fff0b0", sin(p * PI) * 0.6)
			glow.show()
		elif visual.has("collect_glow"):
			visual.collect_glow.hide()
		merged.show()
		return
	var target_size: Vector2 = _tile_rect(fusion.result).size
	var destination: Vector2 = _tile_rect(fusion.result).get_center()
	if bool(visual.get("powerup_anchor", false)):
		# Resolve the automatic contact point against the current responsive board.
		var contact: Vector2 = _tile_rect(fusion.b).get_center()
		visual.origin_a = contact
		visual.origin_b = contact
		visual.start = contact
	var joining: float = smoothstep(0.0, 0.68, p)
	# Let the flowing paint reach the new pair's hue before the skin handover.
	var from_hue: float = Palette.hue(int(visual.palette_b))
	var to_hue: float = Palette.hue(merged.palette_index)
	art._gel.set_shader_parameter("palette_hue_b", fposmod(from_hue + (fposmod(to_hue - from_hue + 0.5, 1.0) - 0.5) * joining, 1.0))
	var a: Vector2 = Vector2(visual.origin_a).lerp(destination, joining)
	var b: Vector2 = Vector2(visual.origin_b).lerp(destination, joining)
	var extent_a: Vector2 = _tile_rect(fusion.a).size.lerp(target_size, joining)
	var extent_b: Vector2 = _tile_rect(fusion.b).size.lerp(target_size, joining)
	var wobble: float = sin((p - 0.64) * TAU * 2.0) * (1.0 - smoothstep(0.64, 1.0, p)) * 0.045 if p > 0.64 else 0.0
	var stretch := Vector2(1.0 + wobble, 1.0 - wobble)
	var handover: float = smoothstep(0.78, 0.96, p)
	if reduced_motion:
		art.hide()
	else:
		art.pose(a, b, destination, extent_a * stretch, extent_b * stretch, _pitch, minf(0.55, p * 0.8), 0.0, 0.0, 1.0 - handover)
	merged.size = target_size
	merged.position = destination - target_size * 0.5
	merged._surface.visible = reduced_motion or handover > 0.0
	merged._surface.modulate.a = 1.0 if reduced_motion else handover
	merged.modulate.a = 1.0 if reduced_motion else smoothstep(0.34, 0.65, p)
	merged.deform(0.0, 0.0, Vector2.ONE if reduced_motion else stretch)
	if str(_fusion_drag.get("event_id", "")) == str(fusion.attempt_id):
		art.position += Vector2(_fusion_drag.offset)
		merged.position += Vector2(_fusion_drag.offset)
		var state: Dictionary = _contact_state()
		merged.set_contact(str(state.kind), state.direction, float(state.strength), reduced_motion)
	merged.show()

func _merge_started(fusion: Dictionary) -> void:
	if str(fusion.get("operation", "")) == "merge" and _can_play() \
		and not bool(fusion.get("automatic", false)) and not game.collection_batch_active() \
		and game.is_valid_word(fusion.get("result", {})):
		# The accepted drop already reserves a valid word. Speak with the union
		# instead of adding the full animation to the pronunciation response time.
		word_merged.emit(fusion.word)

func _fusion_completed(fusion: Dictionary, _awarded: int) -> void:
	if str(_fusion_drag.get("event_id", "")) == str(fusion.attempt_id):
		var moved: bool = bool(_fusion_drag.moved)
		var from: Vector2 = _tile_rect(fusion.result).position + Vector2(_fusion_drag.offset)
		_fusion_drag.clear()
		if _can_play() and _pointer != NO_POINTER:
			_end_view_update()
			_source = int(fusion.result.id)
			_dragging = moved
			_drag_offset = _drag_point - from
			if moved:
				game.begin_drag(_source)
			_sync_tiles()
			if _tiles.has(_source):
				_tiles[_source].position = from
			_snapbacks.erase(_source)
			_reflow.erase(_source)
			_refresh_marks()
			return
	if game._has_free_cell():
		_cue("danger_end")
	if str(fusion.get("operation", "")) == "merge" and not reduced_motion:
		var visual: Dictionary = _fusion_visuals.get(str(fusion.attempt_id), {})
		if not visual.is_empty():
			_snapbacks[int(fusion.result.id)] = {"from": visual.merged.position, "elapsed": 0.0}
	_refresh_hud()

func _landing_contact_at(cell: Dictionary) -> float:
	if game.is_fusing(int(cell.id)):
		return INF
	if bool(cell.get("arrival", false)):
		return WordModel.arrival_contact_at(cell)
	return WordModel.SETTLE_SECONDS * (0.70 if bool(cell.get("falling", false)) else 1.0)

func _refresh_hud() -> void:
	super._refresh_hud()
	if _combo_hud != null:
		# Learning callbacks can refresh the HUD before combo_changed. Consume
		# increments only through that ordered signal so each keeps its flourish.
		if game.phase != "playing" or game.combo_count == 0:
			_combo_hud.set_state({})
		else:
			var combo: Dictionary = game.combo_snapshot()
			_combo_hud.set_timer(float(combo.remaining), float(combo.seconds))
	_loot_detail.visible = _loot_detail.visible and _compact_hud and not has_header_chest()
	var has_error: bool = not game.error.is_empty()
	_notice.hide()
	if has_error:
		_notice.text = game.error
		_notice.show()
	if _error_notice_reserved != has_error:
		_error_notice_reserved = has_error
		_layout.call_deferred()
	_refresh_collect_button()

func _can_play() -> bool:
	return super._can_play() and not bool(game.combo_snapshot().pending)

func _combo_changed(state: Dictionary) -> void:
	if _combo_hud == null:
		return
	var increased: bool = int(state.count) > int(_combo_hud.snapshot().count)
	_combo_hud.set_state(state, _can_play())
	if increased and _can_play():
		audio_requested.emit("jelly-combo-%d" % int(state.count))
	if increased and int(state.get("bonus", 0)) > 0:
		combo_coins_earned.emit(str(state.event_id), _combo_hud.coin_origin())
	_publish()

func set_stage_progress(state: Dictionary, celebrate: bool = false) -> void:
	if _stage_banner._state == state and not celebrate:
		return
	var was_visible: bool = _stage_banner.visible
	var previous_rows: int = _practice_panel._rows.size()
	_stage_banner.reduced_motion = reduced_motion
	_stage_banner.set_stage(state, celebrate)
	_practice_panel.set_stage(state)
	if was_visible != _stage_banner.visible or previous_rows != _practice_panel._rows.size():
		_layout()
	_publish()

func _finish_hint_allowed() -> bool:
	return super._finish_hint_allowed() and not game.collection_batch_active() and not game.powerup_active() and _keyboard_source < 0

func _finish_pull_changed() -> void:
	if _finish_is_pulling():
		_keyboard_source = -1
		game.set_held_tile()
		_refresh_marks()
	super._finish_pull_changed()

func _can_tap_chest() -> bool:
	return not game.collection_batch_active() and not game.powerup_active() and super._can_tap_chest()

func can_finish_round() -> bool:
	# A size-only pause stops the board while retaining the header's exit action.
	return _can_play() or _paused_finish_allowed() or (_layout_too_small and not _requested_pause and _read_cell.is_empty()
		and _configured and game.phase == "playing" and is_visible_in_tree()
		and (not interaction_allowed.is_valid() or bool(interaction_allowed.call())))

func _request_finish() -> void:
	if can_finish_round() and _pointer == NO_POINTER and not _finish_is_pulling():
		finish_requested.emit()

func _finish_round() -> void:
	if not can_finish_round() or _pointer != NO_POINTER or _finish_is_pulling():
		return
	cancel_input()
	game.finish_round()

func _sync_chest_tap() -> void:
	super._sync_chest_tap()
	if has_header_chest() and can_finish_round():
		_header_chest_host.show()

func _refresh_controls() -> void:
	if _layout_too_small and can_finish_round():
		# Do not briefly hide hosted Finish through the base gameplay guard:
		# hiding it cancels the very header pull that remains available here.
		_sync_chest_tap()
		_refresh_danger()
		for tile: Tile in _tiles.values():
			tile.disabled = true
		drop_button.visible = true
		drop_button.disabled = true
		_set_preview_pressed(false)
	else:
		super._refresh_controls()
	if can_finish_round():
		finish_button.show()
		finish_button.disabled = _pointer != NO_POINTER
	_refresh_preview_read_controls()
	if collect_button == null:
		return
	if game.collection_batch_active() or game.powerup_active() or game.stage_ending():
		for tile: Tile in _tiles.values():
			tile.disabled = true
		drop_button.disabled = true
	_refresh_collect_button()
	_refresh_powerup_buttons()

func _refresh_powerup_buttons() -> void:
	var balance: int = int(coin_balance.call()) if coin_balance.is_valid() else 0
	for kind: String in powerup_buttons:
		var button: PowerupButton = powerup_buttons[kind]
		var price: int = game.powerup_price(kind)
		button.set_price(price)
		button.visible = _configured and game.phase == "playing" and (kind != "extra_time" \
			or game.stage_run != null and game.stage_run.kind == "main")
		var available: bool = game.can_activate_powerup(kind)
		button.set_availability(_can_play() and not _finish_is_pulling() and _pointer == NO_POINTER and _keyboard_source < 0 and available,
			balance >= price, game.powerup_active() and not available)

func _refresh_collect_button() -> void:
	if collect_button == null:
		return
	var batch: Dictionary = game.collection_batch_snapshot()
	var count: int = game.collectable_ids().size() if _configured else 0
	collect_button.visible = _configured and game.phase == "playing"
	_action_divider.visible = collect_button.visible
	collect_button.disabled = not game.auto_collect_unlocked() or not _can_play() or _finish_is_pulling() or _pointer != NO_POINTER or bool(batch.active) or game.powerup_active() or count == 0
	collect_button.set_pip_level(game.pip_level)
	collect_button.set_reduced_motion(reduced_motion)
	collect_button.set_state(count, _configured and bool(batch.active), int(batch.remaining) if _configured else 0, int(batch.total) if _configured else 0)

func _reward_pickup_ready() -> bool:
	# Let the collection rhythm reach its final word before a queued chest
	# takes the screen's focal position. Fragment credit remains immediate.
	return not game.collection_batch_active() and super._reward_pickup_ready()

func danger_feedback() -> Dictionary:
	var elapsed: float = float(game.full_elapsed)
	var source: String = "full" if elapsed >= 0.0 else ""
	if _configured and game.stage_run != null and game.stage_run.kind == "main" \
		and game.stage_run.outcome.is_empty() and game.stage_run.remaining <= STAGE_WARNING_SECONDS:
		var deadline_elapsed: float = STAGE_WARNING_SECONDS - game.stage_run.remaining
		if deadline_elapsed > elapsed:
			elapsed = deadline_elapsed
			source = "stage"
	var active: bool = _can_play() and not game.powerup_active() and not game.stage_ending() and elapsed >= 0.0
	return {"active": active, "source": source, "elapsed": elapsed,
		"strength": DangerFrame.primary_pulse(elapsed, reduced_motion) if active else 0.0}


func _refresh_danger() -> void:
	if _danger_frame != null:
		var warning: Dictionary = danger_feedback()
		_danger_frame.set_warning(bool(warning.active), float(warning.elapsed), WordModel.FULL_SECONDS, reduced_motion)

func _layout() -> void:
	if _loot_icon == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var s: float = Style.ui_scale(self)
	var authored: bool = game.uses_authored_morphology()
	var edge: float = (4.0 if authored else 6.0) / s
	var bottom_padding: float = 12.0 / s
	var padding: float = 4.0 / s
	var feed_gap: float = 4.0 / s
	var hud_width: float = clampf((size.x - edge * 2.0) * 0.25, 88.0 / s, 144.0 / s)
	var hud_gap: float = (8.0 if authored else 12.0) / s
	var local_finish: bool = finish_button.get_parent() == self
	var local_chest: bool = not has_header_chest()
	var top_hud_height: float = (44.0 if authored else 52.0) / s if local_finish or local_chest else 0.0
	var boss_y: float = top_hud_height
	var boss_height: float = 84.0 / s if game.boss.active() else 0.0
	top_hud_height += boss_height
	var notice_y: float = top_hud_height
	var stage_y: float = top_hud_height
	var stage_in_rail: bool = size.x > size.y * 1.4 and size.y * s <= 400.0
	var timed_stage: bool = _stage_banner != null and _stage_banner._state.get("kind") == "main"
	if _stage_banner != null and _stage_banner.visible and not stage_in_rail:
		top_hud_height += (50.0 if timed_stage else 34.0) / s
		notice_y = top_hud_height
	if not game.error.is_empty():
		top_hud_height += 42.0 / s
	var content_top: float = top_hud_height + (2.0 if authored else 12.0) / s
	var available := Vector2(size.x - edge * 2.0, size.y - bottom_padding - content_top)
	var action_height: float = 56.0 / s
	var tool_count: int = 3 if game.stage_run != null and game.stage_run.kind == "main" else 2
	var collect_height: float = action_height
	var divider_gap: float = 20.0 / s
	var footer_height: float = action_height * 2.0 + divider_gap + edge
	var bottom_pitch: float = _fit_layout_pitch(available - Vector2(0.0, footer_height), s)
	var side_pitch: float = _fit_layout_pitch(available - Vector2(hud_width + hud_gap, 0.0), s)
	# Center the well and its single action rail as one group. On short screens
	# the rail may extend beside the supply row, but never into the header.
	var side_hud: bool = side_pitch > bottom_pitch + 0.5 / s and available.y >= 184.0 / s
	_compact_hud = side_hud
	footer_height = 0.0 if side_hud else footer_height
	if side_hud:
		collect_height = clampf(available.y - action_height * tool_count - divider_gap - 8.0 / s, 44.0 / s, action_height)
	_pitch = side_pitch if side_hud else bottom_pitch
	var too_small: bool = authored and _pitch * s < 32.0
	if too_small != _layout_too_small:
		_layout_too_small = too_small
		_apply_pause_reasons()
	_gap = maxf(3.0 / s, _pitch * 0.09)
	var preview_size: float = _pitch - _gap
	var preview_height: float = maxf(44.0 / s, _pitch * _preview_row_count() - _gap + padding * 2.0)
	var feed_height: float = preview_height + feed_gap
	var group_top: float = maxf(content_top, size.y - bottom_padding - footer_height - _pitch * WordModel.ROWS - feed_height)
	var rail_extent: float = hud_width + hud_gap if side_hud else 0.0
	var next_board := Rect2(Vector2((size.x - _pitch * WordModel.COLUMNS - rail_extent) * 0.5, group_top + feed_height), Vector2(WordModel.COLUMNS, WordModel.ROWS) * _pitch)
	if next_board != _board:
		# Reflow belongs to gameplay. A resize must place every hit target inside
		# the new well immediately, even while the game clock is paused.
		if _dragging:
			cancel_input()
		_rest_rects.clear()
		_reflow.clear()
		_snapbacks.clear()
	_board = next_board
	_boss_view.size = size
	_boss_view.layout_battle(Rect2(Vector2(_board.position.x, boss_y),
		Vector2(_board.size.x, maxf(0.0, boss_height - 6.0 / s))), _board, s,
		Rect2(Vector2(_board.position.x, group_top), Vector2(_board.size.x, preview_height)))
	var well_bounds: Rect2 = _board.grow(-2.0 / s)
	_well_art.position = well_bounds.position
	_well_art.size = well_bounds.size
	_well_art.material.set_shader_parameter("region_size", well_bounds.size * s)
	_well_art.material.set_shader_parameter("corner_radius", ceilf(16.0 / s) * s)
	_danger_frame.layout_frame(_board.grow(2.0), s, 18.0)
	_falling_layer.position = _board.position
	_falling_layer.size = _board.size
	var footer_width: float = minf(size.x - edge * 2.0, 388.0 / s)
	var item_width: float = clampf((footer_width - (12.0 if tool_count == 3 else 132.0) / s) / tool_count, 88.0 / s, 112.0 / s)
	var hud_x: float = _board.end.x + hud_gap if side_hud else (size.x - footer_width) * 0.5
	if _stage_banner != null:
		_stage_banner.size = size
		var badge := Rect2(Vector2(_board.position.x, stage_y), Vector2(_board.size.x, (44.0 if timed_stage else 28.0) / s))
		if stage_in_rail and side_hud:
			badge = Rect2(Vector2(hud_x, content_top), Vector2(hud_width, 46.0 / s))
		_stage_banner.configure_layout(badge, _board, s)
		var sidebar_width: float = _board.position.x - edge * 2.0 - 12.0 / s
		var sidebar: bool = sidebar_width * s >= 152.0 and _board.size.y * s >= 200.0
		_stage_banner._label.visible = not _practice_panel.visible or sidebar
		var practice_width: float = minf(232.0 / s, sidebar_width)
		var practice_area: Rect2 = Rect2(Vector2(_board.position.x - practice_width - 18.0 / s, group_top),
			Vector2(practice_width, minf(_board.size.y, (66.0 + _practice_panel._rows.size() * 60.0) / s))) \
			if sidebar else badge
		_practice_panel.configure_layout(practice_area, s, not sidebar)
	if not layout_header_chest():
		_loot_meter.position = Vector2(edge, 4.0 / s)
		_loot_meter.size = Vector2.ONE * 44.0 / s
		_loot_icon.size = _loot_meter.size * 0.67
		_loot_icon.position = _loot_meter.position + (_loot_meter.size - _loot_icon.size) * 0.5
		_chest_tap.position = _loot_meter.position
		_chest_tap.size = _loot_meter.size
	_loot_detail.position = chest_meter_rect().position + Vector2(50.0, 14.0) / s
	_loot_detail.size = Vector2(maxf(0.0, size.x - 152.0 / s), 16.0 / s)
	_loot_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_loot_detail.add_theme_font_size_override("font_size", ceili(10.0 / s))
	_preview_rect = Rect2(Vector2(_board.position.x, group_top), Vector2(_board.size.x, preview_height))
	drop_button.position = _preview_rect.position
	drop_button.size = _preview_rect.size
	_style_drop_button()
	for index in range(_preview_tiles.size()):
		_preview_tiles[index].size = Vector2.ONE * preview_size
		_preview_origins[index] = _preview_rect.position + Vector2((float(index) + 0.5) * _pitch - preview_size * 0.5, (preview_height - preview_size) * 0.5)
	_sync_preview()
	_style_finish_button()
	# The app hosts Finish in its header, away from dragging and collection.
	if local_finish:
		finish_button.size = Vector2(84.0, 44.0) / s
		finish_button.position = Vector2(size.x - edge - finish_button.size.x, 4.0 / s)
	for index in range(tool_count):
		var button: PowerupButton = powerup_buttons[["auto_merge", "fragments", "extra_time"][index]]
		button.set_ui_scale(s)
		button.size = Vector2(hud_width if side_hud else item_width, action_height)
		button.position = Vector2(hud_x, _board.end.y - (tool_count - index) * (button.size.y + 8.0 / s) + 8.0 / s) if side_hud else \
			Vector2(hud_x + index * (footer_width - button.size.x) / float(tool_count - 1), _board.end.y + edge + action_height + divider_gap)
	var auto_merge: Rect2 = powerup_buttons.auto_merge.get_rect()
	collect_button.set_ui_scale(s)
	collect_button.size = Vector2(auto_merge.size.x, collect_height)
	collect_button.position = Vector2(auto_merge.position.x, auto_merge.position.y - divider_gap - collect_button.size.y)
	# Use existing header/footer/rail space, preserving the board's cell size.
	var combo_bounds := Rect2(Vector2.ZERO, Vector2(196.0, 72.0) / s)
	if local_finish or local_chest:
		combo_bounds.size.y = 44.0 / s
		var left: float = chest_meter_rect().end.x + 8.0 / s if local_chest else edge
		var right: float = finish_button.position.x - 8.0 / s if local_finish else size.x - edge
		combo_bounds.size.x = minf(combo_bounds.size.x, maxf(0.0, right - left))
		combo_bounds.position = Vector2((left + right - combo_bounds.size.x) * 0.5, 2.0 / s)
	elif not side_hud:
		combo_bounds.size.y = minf(combo_bounds.size.y, collect_height)
		var left: float = collect_button.get_rect().end.x + 12.0 / s
		var right: float = hud_x + footer_width
		combo_bounds.size.x = minf(combo_bounds.size.x, maxf(0.0, right - left))
		combo_bounds.position = Vector2(right - combo_bounds.size.x,
			collect_button.position.y + (collect_height - combo_bounds.size.y) * 0.5)
	else:
		var rail_top: float = content_top + (54.0 / s if stage_in_rail and _stage_banner.visible else 0.0)
		var rail_space: float = collect_button.position.y - rail_top - 8.0 / s
		combo_bounds.size.y = minf(combo_bounds.size.y, maxf(44.0 / s, rail_space))
		if rail_space >= combo_bounds.size.y:
			combo_bounds.size.x = minf(combo_bounds.size.x, hud_width)
			combo_bounds.position = Vector2(hud_x, rail_top)
		else:
			combo_bounds.size.x = minf(combo_bounds.size.x, maxf(0.0, _board.position.x - edge * 2.0))
			# Short landscape leaves its upper gutter to collected-word cards.
			combo_bounds.position = Vector2(edge, maxf(content_top, _board.end.y - combo_bounds.size.y))
	_combo_hud.configure(combo_bounds, s, reduced_motion)
	_action_divider.size = Vector2(hud_width if side_hud else footer_width, 2.0 / s)
	_action_divider.position = Vector2(hud_x, collect_button.get_rect().end.y + (divider_gap - _action_divider.size.y) * 0.5)
	if _powerup_effects != null:
		_powerup_effects.size = size
	if _read_panel != null:
		_read_panel.size = size
	if _size_cover != null:
		_size_cover.size = size
		_size_cover.visible = _configured and _layout_too_small
		_size_message.position = Vector2.ONE * 16.0 / s
		_size_message.size = size - Vector2.ONE * 32.0 / s
		_size_message.add_theme_font_size_override("font_size", ceili(18.0 / s))
	_notice.position = Vector2(edge, notice_y)
	_notice.size = Vector2(size.x - edge * 2.0, 42.0 / s)
	_notice.add_theme_font_size_override("font_size", ceili(12.0 / s))
	if _room_notice != null:
		_room_notice.position = _board.position + Vector2(8.0, 8.0) / s
		_room_notice.size = Vector2(_board.size.x - 16.0 / s, 56.0 / s)
		_room_notice.add_theme_font_size_override("font_size", ceili(16.0 / s))
	_reward_presentation.size = size
	_reward_presentation.set_chest_anchor(chest_anchor_rect())
	if _collection_effects != null:
		_collection_effects.configure_layout(Rect2(Vector2.ZERO, size), s)
		_collection_effects.set_board_burst(_pitch)
		# A charging Jelly follows responsive board layout until its burst begins.
		# Once released, the particle tail retains its own position and clock.
		for fusion: Dictionary in game.fusions:
			if str(fusion.operation) == "collect":
				_collection_effects.reanchor_pending(str(fusion.attempt_id), _tile_rect(fusion.a).get_center())
	if _word_reveal != null:
		# Short landscape screens need two compact rows for distinct collection beats.
		var reveal_fraction: float = 0.60 if size.x > size.y * 1.4 and size.y * s < 350.0 else 0.40
		var finish_rect: Rect2 = get_global_transform().affine_inverse() * finish_button.get_global_rect()
		# Falling embers get room below the reading cards without moving or resizing them.
		var firework_area := Rect2(Vector2.ONE * edge,
			Vector2(size.x - edge * 2.0, minf(680.0 / s, size.y * maxf(0.86, reveal_fraction)) - edge))
		var effect_exclusions: Array[Rect2] = [chest_meter_rect().grow(10.0 / s), collect_button.get_rect().grow(8.0 / s), finish_rect.grow(8.0 / s),
			_combo_hud.get_rect().grow(3.0 / s), powerup_buttons.auto_merge.get_rect().grow(5.0 / s),
			powerup_buttons.fragments.get_rect().grow(5.0 / s)]
		if _practice_panel.visible:
			effect_exclusions.append(_practice_panel.get_rect().grow(6.0 / s))
		_word_reveal.configure_layout(Rect2(Vector2.ONE * edge,
			Vector2(size.x - edge * 2.0, minf(280.0 / s, size.y * reveal_fraction) - edge)), s,
			effect_exclusions, firework_area)
	_sync_positions()
	_refresh_fusion()
	_refresh_hud()
	queue_redraw()
	_publish()

func _preview_row_count() -> int:
	if _preview_layout_generation != game._generation:
		_preview_layout_generation = game._generation
		_preview_layout_rows = 1
		# Reserve the tallest source part the round can supply, without shrinking
		# single-row vocabularies or changing the board when the preview refills.
		for analysis_id: String in game._authored_words.values():
			for state: Dictionary in game._morphology.source_tiles(analysis_id):
				_preview_layout_rows = maxi(_preview_layout_rows, int(game._composition_footprint(state).height))
	return _preview_layout_rows

func _fit_layout_pitch(available: Vector2, s: float) -> float:
	# Fit the well together with a full-sized supply row, its 44px hit area,
	# and the gap below it. Cell size follows the space available on screen.
	var height_pitch: float = maxf((available.y - 12.0 / s) / (WordModel.ROWS + 0.91), (available.y - 9.0 / s) / (WordModel.ROWS + 1.0))
	if game.uses_authored_morphology():
		height_pitch = (available.y - 9.0 / s) / (WordModel.ROWS + _preview_row_count())
	height_pitch = minf(height_pitch, (available.y - 48.0 / s) / WordModel.ROWS)
	return maxf(8.0 / s, minf(available.x / WordModel.COLUMNS, height_pitch))

func snapshot() -> Dictionary:
	# A pause or collection may publish before the next presentation pass.
	# Refresh once so all preview slots describe the current model state.
	_preview_drop_available = _can_drop_preview()
	var state: Dictionary = super.snapshot()
	state["stage"] = _stage_banner.snapshot() if _stage_banner != null else {}
	state["boss_view"] = _boss_view.snapshot() if _boss_view != null else {}
	state["practice"] = _practice_panel.snapshot() if _practice_panel != null else {"visible": false, "words": []}
	state["combo_hud"] = _combo_hud.snapshot() if _combo_hud != null else {"visible": false}
	state["mode"] = "word_jelly"
	state["columns"] = WordModel.COLUMNS
	state["rows"] = WordModel.ROWS
	state["board_ratio"] = float(WordModel.COLUMNS) / WordModel.ROWS
	state["playfield_rect"] = _rect(get_global_rect())
	state["word_reveal"] = _word_reveal.snapshot() if _word_reveal != null else {"visible": false}
	state["collection_effects"] = _collection_effects.snapshot() if _collection_effects != null else {"visible": false}
	state["read_detail"] = _read_panel.snapshot() if _read_panel != null else {"visible": false}
	state["layout_paused"] = _layout_too_small
	state["cell_pitch_pixels"] = _pitch * Style.ui_scale(self)
	state["collect_button"] = collect_button.snapshot() if collect_button != null else {}
	state["action_divider"] = {"rect": _rect(_action_divider.get_global_rect()), "visible": _action_divider.is_visible_in_tree()}
	state["powerup"] = game.powerup_snapshot()
	state["hit_stop"]["visible"] = is_visible_in_tree() and _can_play() and not reduced_motion \
		and bool(state.hit_stop.active) and _powerup_effects.is_visible_in_tree()
	state["powerup_buttons"] = {}
	for kind: String in powerup_buttons:
		var button: PowerupButton = powerup_buttons[kind]
		state.powerup_buttons[kind] = button.snapshot()
		state.powerup_buttons[kind].merge({"rect": _rect(button.get_global_rect()), "enabled": not button.disabled,
			"visible": button.is_visible_in_tree()}, true)
	state["powerup_effect_count"] = _powerup_effects.stamps.size() if _powerup_effects != null else 0
	state["placement"] = {"visible": _placement_tile != null and _placement_tile.is_visible_in_tree(), "valid": false}
	if not _placement.is_empty():
		state.placement.merge(_placement, true)
		state.placement.rect = _rect(_global_rect(_placement.rect))
	if collect_button != null:
		state.collect_button.merge({"rect": _rect(collect_button.get_global_rect()), "enabled": not collect_button.disabled, "visible": collect_button.is_visible_in_tree()}, true)
	state.preview.enabled = state.preview.enabled and not game.collection_batch_active() and not game.powerup_active()
	state.drag.selected = _keyboard_source
	state.drag["needs_room"] = _room_notice != null and _room_notice.visible
	for item: Dictionary in state.tiles:
		var tile: WordTile = _tiles[int(item.id)]
		item["presentation"] = tile.presentation_snapshot()
		item["completion_hint"] = tile.completion_hint
		item["match_dimmed"] = tile.match_dimmed
		item["completion_scale"] = tile.completion_scale
		item["picture_visible"] = tile._picture.is_visible_in_tree()
		item["label_text"] = tile._label.text
		item["label_visible"] = tile._label.is_visible_in_tree()
		item["accessibility_name"] = tile.get("accessibility_name")
		item["tooltip_text"] = tile.tooltip_text
		item["label_font_pixels"] = tile._label.get_theme_font_size("font_size") * Style.ui_scale(self)
		item["requires_read"] = tile.requires_read
		item["read_available"] = tile.requires_read
		item["read_button_visible"] = tile._read_button.is_visible_in_tree()
		item["label_line_count"] = tile._label.get_line_count()
		item["label_visible_line_count"] = tile._label.get_visible_line_count()
		item["label_line_height"] = tile._label.get_line_height()
		item["label_height"] = tile._label.size.y
		item["fragment_badges"] = tile.visible_fragment_badges()
		item["fragment_badge"] = tile.fragment_badge_snapshot()
		item["coins"] = WordModel.coins_for_tile(item)
		item["coin_drop_chance"] = WordModel.coin_drop_chance_for_tile(item)
		item["palette_index"] = tile.palette_index
		item["palette_hue"] = tile._gel.get_shader_parameter("palette_hue")
	for index in range(state.preview.slots.size()):
		state.preview.slots[index]["palette_index"] = _preview_tiles[index].palette_index
		state.preview.slots[index]["palette_hue"] = _preview_tiles[index]._gel.get_shader_parameter("palette_hue")
	return state

class_name WordJelly
extends "res://scripts/jelly_match.gd"
## Six-column word construction, with the established jelly input and rewards.

signal collected(event_id: String, word: Dictionary, amount: int, fragments: int, origin: Vector2)
signal word_merged(word: Dictionary)
signal batch_collection_started

const WordModel = preload("res://scripts/word_jelly_model.gd")
const WordTile = preload("res://scripts/word_jelly_tile.gd")
const Palette = preload("res://scripts/word_jelly_palette.gd")
const WordReveal = preload("res://scripts/word_jelly_word_reveal.gd")
const CollectButton = preload("res://scripts/word_jelly_collect_button.gd")
const PowerupButton = preload("res://scripts/word_jelly_powerup_button.gd")
const PowerupEffects = preload("res://scripts/word_jelly_powerup_effects.gd")
const COLLECTION_GLOW = preload("res://assets/chests/particles/portal_glow.png")
const POWERUP_SPARKLE = preload("res://assets/chests/milestone/sparkle.png")

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
var _word_reveal: WordReveal
var collect_button: CollectButton
var _placement_tile: WordTile
var _placement: Dictionary = {}
var _completion_source: int = -1
var _completion_elapsed: float = 0.0
var _reveal_frame_end: float = -1.0
var _reveal_frame_batch: int = -1
var _reveal_frame_generation: int = -1
var _error_notice_reserved: bool = false

func _init() -> void:
	super()
	name = "WordJelly"
	game = WordModel.new()
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
	drop_button.set("accessibility_name", "Drop the next word parts")
	_word_reveal = WordReveal.new()
	add_child(_word_reveal)
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
	_powerup_effects = PowerupEffects.new()
	add_child(_powerup_effects)
	_placement_tile = WordTile.new()
	_placement_tile.name = "WordJellyPlacement"
	_placement_tile.disabled = true
	_placement_tile.focus_mode = Control.FOCUS_NONE
	_placement_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_tile.hide()
	add_child(_placement_tile)

func stop() -> void:
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

func pause(value: bool = true) -> void:
	if value and _word_reveal != null:
		_word_reveal.reset()
	super.pause(value)
	if _powerup_effects != null:
		_powerup_effects.visible = not value and _can_play()
	for button: PowerupButton in powerup_buttons.values():
		button.pause_feedback(value)

func set_reduced_motion(value: bool) -> void:
	_word_reveal.set_reduced_motion(value)
	collect_button.set_reduced_motion(value)
	for kind: String in powerup_buttons:
		powerup_buttons[kind].configure(kind, game.powerup_price(kind), value)
	super.set_reduced_motion(value)

func _visibility_changed() -> void:
	if not is_visible_in_tree() and _word_reveal != null:
		_word_reveal.reset()
	super._visibility_changed()

func _finished(result: Dictionary) -> void:
	_word_reveal.reset()
	_powerup_effects.hide()
	super._finished(result)

func cancel_input() -> void:
	_keyboard_source = -1
	# Resolve the lifted body before the base view paints its resting position.
	game.set_held_tile()
	super.cancel_input()

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
	if _finish_is_pulling():
		return
	if game.collection_batch_active() or game.powerup_active():
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
	# Roots have no pronunciation recording; a completed word keeps its audio.
	if _pointer != NO_POINTER or not _can_play() or _finish_is_pulling() or game.collection_batch_active() or game.powerup_active():
		return false
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	if _preview_rect.has_point(point):
		return super._press(pointer, global_point)
	var id: int = _tile_at(point)
	if id < 0:
		return false
	_rejection.clear()
	_keyboard_source = -1
	_pointer = pointer
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
	audio_requested.emit("pick")
	_refresh_marks()
	_publish()
	return true

func _move(global_point: Vector2) -> void:
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
	if _preview_first_id >= 0:
		super._release(global_point)
		return
	var source: int = _source
	var was_dragging: bool = _dragging
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	var valid_tap: bool = _can_play() and source >= 0 and not was_dragging \
		and point.distance_to(_press_point) * Style.ui_scale(self) <= 7.0 and _tile_at(point) == source
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

func _tap_tile(id: int) -> void:
	if game.is_valid_word(_cell(id)):
		_collect(id)

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

func _collect_all() -> void:
	if not _can_play() or _pointer != NO_POINTER or _finish_is_pulling() or game.collection_batch_active():
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
	_word_reveal.set_reduced_motion(reduced_motion)
	var batch: bool = bool(fusion.get("batch", false))
	var initial_age: float = 0.0
	if batch and _reveal_frame_end >= 0.0 and _reveal_frame_generation == _generation \
		and int(fusion.get("batch_id", -1)) == _reveal_frame_batch:
		initial_age = maxf(0.0, _reveal_frame_end - float(game.collection_batch_snapshot().elapsed))
	_word_reveal.present(word, _picture(word), _theme.get("accent", Style.GOOD), batch, initial_age)
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
	tile.configure(cell, _surfaces[0], _picture(cell.word), _chest_texture, _theme.get("accent", Style.GOOD), combined)
	_apply_palette(tile, int(cell.id))

func _apply_palette(tile: WordTile, id: int) -> void:
	var index: int = int(_palette_indices.get(id, _palette_cache.get(id, 0)))
	if tile.palette_index != index:
		tile.set_palette(index, Palette.hue(index))

func _refresh_palette() -> void:
	if not _configured:
		return
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
	items.append_array(game.upcoming)
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
	# The old preview still owns the departing IDs until this sync completes.
	# Keep the slot rather than screen pixels so a paused resize stays coherent.
	for cell: Dictionary in game.cells:
		if bool(cell.get("arrival", false)) and not _tiles.has(int(cell.id)):
			for index in range(_preview_tiles.size()):
				var preview: WordTile = _preview_tiles[index]
				if preview.tile_id == int(cell.id):
					_arrival_origins[int(cell.id)] = {"slot": index,
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

func _tile_rect(cell: Dictionary) -> Rect2:
	return Rect2(_board.position + Vector2(int(cell.get("column", 0)), int(cell.get("row", 0))) * _pitch + Vector2.ONE * _gap * 0.5,
		Vector2(int(cell.get("width", 1)), int(cell.get("height", 1))) * _pitch - Vector2.ONE * _gap)

func _arrival_rect(cell: Dictionary) -> Rect2:
	var origin: Dictionary = _arrival_origins.get(int(cell.id), {})
	if not origin.is_empty():
		var slot: int = int(origin.slot)
		return Rect2(_preview_origins[slot], _preview_tiles[slot].size)
	var rect: Rect2 = _tile_rect(cell)
	rect.position.y = _board.position.y - _pitch + _gap * 0.5
	return rect

func _arrival_delay(cell: Dictionary) -> float:
	return WordModel.arrival_delay(cell)

func _sync_positions() -> void:
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
		tile.z_index = 40 if dragging else 1
		var stretch: Vector2 = Vector2.ONE
		var compression: float = 0.0
		var arrival: bool = bool(cell.get("arrival", false)) and not game.is_settled(cell)
		var shadow_visible: bool = true
		tile.set_preview_pressure(0.0, 0.0)
		if not dragging:
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
	if _dragging:
		var target: int = _drag_target()
		if target != _target:
			_target = target
			_contact_elapsed = 0.0
			_refresh_marks()
	_refresh_contact()
	_refresh_placement()
	_pose_powerup()

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
	if bool(state.get("active", false)) and str(state.get("kind", "")) == "auto_merge":
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

func _sync_preview() -> void:
	drop_button.queue_redraw()
	var refills: Array[float] = []
	refills.resize(_preview_tiles.size())
	refills.fill(1.0)
	if not reduced_motion:
		for cell: Dictionary in game.cells:
			if bool(cell.get("arrival", false)) and _arrival_origins.has(int(cell.id)):
				var slot: int = int(_arrival_origins[int(cell.id)].slot)
				# Each departing body frees its own preview slot. Later roots can
				# keep waiting while the cleared slots quietly refill behind them.
				refills[slot] = minf(refills[slot], (float(cell.age) - _arrival_delay(cell) - 0.18) / 0.18)
	for index in range(_preview_tiles.size()):
		var preview: Tile = _preview_tiles[index]
		var refill: float = refills[index]
		var available: bool = _configured and index < game.upcoming.size()
		preview.visible = available and refill > 0.0
		if not available:
			continue
		var item: Dictionary = game.upcoming[index]
		# A rapid tap can release a refilling slot before it becomes visible.
		# Keep its identity current so that departure still owns the right origin.
		if preview.tile_id != int(item.id):
			_configure_tile(preview, item)
		_apply_palette(preview, int(item.id))
		var pose: Dictionary = _preview_pose(index)
		preview.position = _preview_origins[index]
		preview.modulate.a = clampf(refill, 0.0, 1.0)
		preview.deform(0.0, 0.0)
		preview.set_preview_pressure(float(pose.pressure), float(pose.sway), float(pose.pull))

func _preview_pose(index: int) -> Dictionary:
	return Motion.preview(game.spawn_elapsed, game.spawn_interval, index, reduced_motion or game.phase != "playing" or not game.can_drop_now())

func _process(delta: float) -> void:
	if _finish_is_pulling():
		super._process(delta)
		return
	_reveal_frame_end = -1.0
	_powerup_frame_end = -1.0
	if _can_play() and delta <= 0.5:
		var powerup: Dictionary = game.powerup_snapshot()
		if bool(powerup.active) and str(powerup.kind) == "fragments":
			_powerup_frame_end = float(powerup.elapsed) + delta
			_powerup_frame_receipt = str(powerup.receipt_id)
			_powerup_frame_generation = _generation
		_word_reveal.advance(delta)
		if game.collection_batch_active():
			# New cards keep their actual 120 ms offsets even when a frame spans several beats.
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
			_completion_elapsed += delta
	var generation: int = _generation
	var previous_rows: Dictionary = {}
	for cell: Dictionary in game.cells:
		previous_rows[int(cell.id)] = int(cell.row)
	super._process(delta)
	_reveal_frame_end = -1.0
	_powerup_frame_end = -1.0
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
		_tiles[id].set_marked(id == _target and completing, id == _source,
			feedback_enabled and not game.is_fusing(id), reduced_motion)
	_refresh_contact()
	_refresh_palette()
	if _keyboard_source >= 0 and _tiles.has(_keyboard_source):
		_tiles[_keyboard_source].set_marked(false, true, _can_play(), reduced_motion)
	_refresh_completion_hints()

func _refresh_completion_hints() -> void:
	var source: int = (_source if _source >= 0 else _keyboard_source) if _can_play() and not game.collection_batch_active() else -1
	if source != _completion_source:
		_completion_source = source
		_completion_elapsed = 0.0
	var prefix: Dictionary = _cell(source)
	for id: int in _tiles:
		var target: Dictionary = _cell(id)
		var eligible: bool = not prefix.is_empty() and _settled(prefix) and _settled(target) \
			and Palette.completes(prefix, target, game._word_lookup)
		_tiles[id].set_completion_hint(eligible, _completion_elapsed, reduced_motion)

func navigation_controls() -> Array[Control]:
	if not _can_play():
		return super.navigation_controls()
	var controls: Array[Control] = []
	var ordered: Array = game.cells.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.row) * WordModel.COLUMNS + int(a.column) < int(b.row) * WordModel.COLUMNS + int(b.column))
	for cell: Dictionary in ordered:
		if _settled(cell) and _tiles.has(int(cell.id)) and not game.collection_batch_active() and not game.powerup_active():
			controls.append(_tiles[int(cell.id)])
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
	var source: Dictionary = _cell(_source)
	var target: Dictionary = _cell(_target)
	if not _settled(source) or not _settled(target):
		return state
	# All painted bodies respond to pressure. Only a forward word earns the
	# separate completion highlight. A failed drop is rejected only on release.
	var completing: bool = Palette.completes(source, target, game._word_lookup)
	var direction: Vector2 = (_tiles[_target].get_rect().get_center() - _tiles[_source].get_rect().get_center()).normalized()
	if direction.length_squared() < 0.1:
		direction = (_tile_rect(target).get_center() - _tile_rect(source).get_center()).normalized()
	state.merge({"kind": "match" if completing else "touch", "source": _source, "target": _target,
		"strength": lerpf(0.2, 0.65, smoothstep(0.0, 0.14, _contact_elapsed)), "direction": direction}, true)
	return state

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
	super._remove_fusion_visual(id)

func _pose_fusion(fusion: Dictionary, visual: Dictionary) -> void:
	var merged: WordTile = visual.merged
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
		if bool(fusion.get("batch", false)) and not reduced_motion:
			var direction: float = -1.0 if int(fusion.batch_index) % 2 == 0 else 1.0
			var lift: float = sin(release * PI * 0.5)
			merged.position += Vector2(direction * _pitch * 0.28 * release, -_pitch * 0.72 * lift)
			merged.rotation = direction * 0.12 * release
			if not visual.has("collect_glow"):
				var glow: TextureRect = _image(self)
				glow.texture = COLLECTION_GLOW
				glow.z_index = 29
				visual["collect_glow"] = glow
			var glow: TextureRect = visual.collect_glow
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
	merged.show()

func _merge_started(fusion: Dictionary) -> void:
	if str(fusion.get("operation", "")) == "merge" and _can_play() \
		and not bool(fusion.get("automatic", false)) and not game.collection_batch_active() \
		and game.is_valid_word(fusion.get("result", {})):
		# The accepted drop already reserves a valid word. Speak with the union
		# instead of adding the full animation to the pronunciation response time.
		word_merged.emit(fusion.word)

func _fusion_completed(fusion: Dictionary, _awarded: int) -> void:
	if game._has_free_cell():
		_cue("danger_end")
	if str(fusion.get("operation", "")) == "merge" and not reduced_motion:
		var visual: Dictionary = _fusion_visuals.get(str(fusion.attempt_id), {})
		if not visual.is_empty():
			_snapbacks[int(fusion.result.id)] = {"from": visual.merged.position, "elapsed": 0.0}
	_refresh_hud()

func _landing_contact_at(cell: Dictionary) -> float:
	if bool(cell.get("arrival", false)):
		return WordModel.arrival_contact_at(cell)
	return WordModel.SETTLE_SECONDS * (0.70 if bool(cell.get("falling", false)) else 1.0)

func _refresh_hud() -> void:
	super._refresh_hud()
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

func _refresh_controls() -> void:
	super._refresh_controls()
	if collect_button == null:
		return
	if game.collection_batch_active() or game.powerup_active():
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
		button.visible = _configured and game.phase == "playing"
		var available: bool = game.can_activate_powerup(kind)
		button.set_availability(_can_play() and not _finish_is_pulling() and _pointer == NO_POINTER and _keyboard_source < 0 and available,
			balance >= price, game.powerup_active() and not available)

func _refresh_collect_button() -> void:
	if collect_button == null:
		return
	var batch: Dictionary = game.collection_batch_snapshot()
	var count: int = game.collectable_ids().size() if _configured else 0
	collect_button.visible = _configured and game.phase == "playing"
	collect_button.disabled = not _can_play() or _finish_is_pulling() or _pointer != NO_POINTER or bool(batch.active) or game.powerup_active() or count == 0
	collect_button.set_reduced_motion(reduced_motion)
	collect_button.set_state(count, _configured and bool(batch.active), int(batch.remaining) if _configured else 0, int(batch.total) if _configured else 0)

func _reward_pickup_ready() -> bool:
	# Let the collection rhythm reach its final word before a queued chest
	# takes the screen's focal position. Fragment credit remains immediate.
	return not game.collection_batch_active() and super._reward_pickup_ready()

func _refresh_danger() -> void:
	if _danger_frame != null:
		_danger_frame.set_warning(_can_play() and not game.powerup_active() and float(game.full_elapsed) >= 0.0, float(game.full_elapsed), WordModel.FULL_SECONDS, reduced_motion)

func _layout() -> void:
	if _loot_icon == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var s: float = Style.ui_scale(self)
	var edge: float = 6.0 / s
	var bottom_padding: float = 12.0 / s
	var padding: float = 4.0 / s
	var feed_gap: float = 4.0 / s
	var hud_width: float = 144.0 / s
	var hud_gap: float = 12.0 / s
	var local_finish: bool = finish_button.get_parent() == self
	var local_chest: bool = not has_header_chest()
	var top_hud_height: float = 52.0 / s if local_finish or local_chest else 0.0
	var notice_y: float = top_hud_height
	if not game.error.is_empty():
		top_hud_height += 42.0 / s
	var available := Vector2(size.x - edge * 2.0, size.y - bottom_padding - top_hud_height)
	var footer_height: float = 56.0 / s + edge
	var bottom_pitch: float = _fit_layout_pitch(available - Vector2(0.0, footer_height), s)
	var side_pitch: float = _fit_layout_pitch(available - Vector2(hud_width + hud_gap, 0.0), s)
	# Center the well and its single action rail as one group. On short screens
	# the rail may extend beside the supply row, but never into the header.
	var side_hud: bool = side_pitch > bottom_pitch + 0.5 / s and available.y >= 184.0 / s
	_compact_hud = side_hud
	footer_height = 0.0 if side_hud else footer_height
	_pitch = side_pitch if side_hud else bottom_pitch
	_gap = maxf(3.0 / s, _pitch * 0.09)
	var preview_size: float = _pitch - _gap
	var preview_height: float = maxf(44.0 / s, preview_size + padding * 2.0)
	var feed_height: float = preview_height + feed_gap
	var group_top: float = maxf(top_hud_height, size.y - bottom_padding - footer_height - _pitch * WordModel.ROWS - feed_height)
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
	_danger_frame.layout_frame(_board.grow(2.0), s, 18.0)
	_falling_layer.position = _board.position
	_falling_layer.size = _board.size
	var footer_width: float = minf(size.x - edge * 2.0, 388.0 / s)
	var item_width: float = clampf((footer_width - 132.0 / s) * 0.5, 88.0 / s, 112.0 / s)
	var collect_width: float = footer_width - item_width * 2.0 - 16.0 / s
	var hud_x: float = _board.end.x + hud_gap if side_hud else (size.x - footer_width) * 0.5
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
	_style_finish_button()
	# The app hosts Finish in its header, away from dragging and collection.
	if local_finish:
		finish_button.size = Vector2(84.0, 44.0) / s
		finish_button.position = Vector2(size.x - edge - finish_button.size.x, 4.0 / s)
	if collect_button != null:
		collect_button.set_ui_scale(s)
		collect_button.size = Vector2(hud_width if side_hud else collect_width, 56.0 / s)
		collect_button.position = Vector2(hud_x, _board.end.y - collect_button.size.y) if side_hud else Vector2(hud_x + (footer_width - collect_button.size.x) * 0.5, _board.end.y + edge)
	for index in range(powerup_buttons.size()):
		var button: PowerupButton = powerup_buttons["auto_merge" if index == 0 else "fragments"]
		button.set_ui_scale(s)
		button.size = Vector2(hud_width if side_hud else item_width, 56.0 / s)
		button.position = Vector2(hud_x, _board.end.y - (3 - index) * (button.size.y + 8.0 / s) + 8.0 / s) if side_hud else \
			Vector2(hud_x + (0.0 if index == 0 else footer_width - button.size.x), _board.end.y + edge)
	if _powerup_effects != null:
		_powerup_effects.size = size
	_notice.position = Vector2(edge, notice_y)
	_notice.size = Vector2(size.x - edge * 2.0, 42.0 / s)
	_notice.add_theme_font_size_override("font_size", ceili(12.0 / s))
	_reward_presentation.size = size
	_reward_presentation.set_chest_anchor(chest_anchor_rect())
	if _word_reveal != null:
		# Short landscape screens need two compact rows for distinct collection beats.
		var reveal_fraction: float = 0.60 if size.x > size.y * 1.4 and size.y * s < 350.0 else 0.40
		_word_reveal.configure_layout(Rect2(Vector2.ONE * edge,
			Vector2(size.x - edge * 2.0, minf(280.0 / s, size.y * reveal_fraction) - edge)), s,
			[chest_meter_rect().grow(10.0 / s)])
	_sync_positions()
	_refresh_fusion()
	_refresh_hud()
	queue_redraw()
	_publish()

func _fit_layout_pitch(available: Vector2, s: float) -> float:
	# Fit the well together with a full-sized supply row, its 44px hit area,
	# and the gap below it. Cell size follows the space available on screen.
	var height_pitch: float = maxf((available.y - 12.0 / s) / (WordModel.ROWS + 0.91), (available.y - 9.0 / s) / (WordModel.ROWS + 1.0))
	height_pitch = minf(height_pitch, (available.y - 48.0 / s) / WordModel.ROWS)
	return maxf(8.0 / s, minf(available.x / WordModel.COLUMNS, height_pitch))

func snapshot() -> Dictionary:
	var state: Dictionary = super.snapshot()
	state["mode"] = "word_jelly"
	state["columns"] = WordModel.COLUMNS
	state["rows"] = WordModel.ROWS
	state["board_ratio"] = float(WordModel.COLUMNS) / WordModel.ROWS
	state["playfield_rect"] = _rect(get_global_rect())
	state["word_reveal"] = _word_reveal.snapshot() if _word_reveal != null else {"visible": false}
	state["collect_button"] = collect_button.snapshot() if collect_button != null else {}
	state["powerup"] = game.powerup_snapshot()
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
	for item: Dictionary in state.tiles:
		var tile: WordTile = _tiles[int(item.id)]
		item["completion_hint"] = tile.completion_hint
		item["completion_scale"] = tile.completion_scale
		item["picture_visible"] = tile._picture.is_visible_in_tree()
		item["label_text"] = tile._label.text
		item["label_line_count"] = tile._label.get_line_count()
		item["label_visible_line_count"] = tile._label.get_visible_line_count()
		item["label_line_height"] = tile._label.get_line_height()
		item["label_height"] = tile._label.size.y
		item["fragment_badges"] = tile.visible_fragment_badges()
		item["fragment_badge"] = tile.fragment_badge_snapshot()
		item["coins"] = WordModel.coins_for_tile(item)
		item["coin_drop_chance"] = WordModel.COIN_DROP_CHANCE
		item["palette_index"] = tile.palette_index
		item["palette_hue"] = tile._gel.get_shader_parameter("palette_hue")
	for index in range(state.preview.slots.size()):
		state.preview.slots[index]["palette_index"] = _preview_tiles[index].palette_index
		state.preview.slots[index]["palette_hue"] = _preview_tiles[index]._gel.get_shader_parameter("palette_hue")
	return state

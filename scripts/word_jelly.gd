class_name WordJelly
extends "res://scripts/jelly_match.gd"
## Six-column word construction, with the established jelly input and rewards.

signal collected(event_id: String, word: Dictionary, amount: int, fragments: int, origin: Vector2)

const WordModel = preload("res://scripts/word_jelly_model.gd")
const WordTile = preload("res://scripts/word_jelly_tile.gd")
const Palette = preload("res://scripts/word_jelly_palette.gd")
const WordReveal = preload("res://scripts/word_jelly_word_reveal.gd")
const CollectButton = preload("res://scripts/word_jelly_collect_button.gd")
const COLLECTION_GLOW = preload("res://assets/chests/particles/portal_glow.png")

var credit_collection: Callable:
	set(value):
		credit_collection = value
		game.credit_collection = value
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

func _init() -> void:
	super()
	name = "WordJelly"
	game = WordModel.new()
	game.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		word_attempted.emit(id, ids, correct))
	game.cue_requested.connect(_cue)
	game.fusion_completed.connect(_fusion_completed)
	game.collected.connect(_collected)
	game.collection_started.connect(_collection_started)
	game.chest_milestone.connect(_chest_milestone)
	game.finished.connect(_finished)
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
	_placement_tile = WordTile.new()
	_placement_tile.name = "WordJellyPlacement"
	_placement_tile.disabled = true
	_placement_tile.focus_mode = Control.FOCUS_NONE
	_placement_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_tile.hide()
	add_child(_placement_tile)

func stop() -> void:
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

func set_reduced_motion(value: bool) -> void:
	_word_reveal.set_reduced_motion(value)
	collect_button.set_reduced_motion(value)
	super.set_reduced_motion(value)

func _visibility_changed() -> void:
	if not is_visible_in_tree() and _word_reveal != null:
		_word_reveal.reset()
	super._visibility_changed()

func _finished(result: Dictionary) -> void:
	_word_reveal.reset()
	super._finished(result)

func cancel_input() -> void:
	_keyboard_source = -1
	super.cancel_input()
	game.set_held_tile()
	_sync_positions()

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
	if _placement_tile != null:
		_placement_tile.set_chest_texture(texture)
	for visual: Dictionary in _fusion_visuals.values():
		visual.merged.set_chest_texture(texture)
		for part: WordTile in visual.get("parts", []):
			part.set_chest_texture(texture)

func _input(event: InputEvent) -> void:
	if game.collection_batch_active():
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
	if _pointer != NO_POINTER or not _can_play() or game.collection_batch_active():
		return false
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	if _preview_rect.has_point(point):
		return super._press(pointer, global_point)
	var id: int = _tile_at(point)
	if id < 0:
		return false
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
		_reflow.erase(source)
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
	if not _can_play() or _pointer != NO_POINTER or not _settled(_cell(id)) or game.collection_batch_active():
		return
	if _keyboard_source >= 0 and _keyboard_source != id and _tiles.has(_keyboard_source):
		var source: int = _keyboard_source
		_keyboard_source = -1
		_merge(source, id, _tiles[source].position)
		game.set_held_tile()
	elif game.is_valid_word(_cell(id)):
		_collect(id)
	elif game.can_split(_cell(id)):
		_split(id)
	else:
		_keyboard_source = -1 if _keyboard_source == id else id
		game.set_held_tile(_keyboard_source)
		_refresh_marks()
		_publish()

func _tap_tile(id: int) -> void:
	if game.is_valid_word(_cell(id)):
		_collect(id)
	elif game.can_split(_cell(id)):
		_split(id)

func _split(id: int) -> void:
	if not _can_play() or not _settled(_cell(id)) or not game.can_split(_cell(id)):
		return
	var generation: int = _generation
	var accepted: bool = game.split(id)
	if generation != _generation or not _can_play():
		return
	_keyboard_source = -1
	game.set_held_tile(_source)
	if accepted:
		_snapbacks.erase(id)
		_rejection.clear()
	else:
		# A full well cannot hold two separate bodies. Keep the word intact and
		# answer the tap with the established elastic feedback, without a label.
		_rejection = {"a": id, "b": -1, "elapsed": 0.0, "direction": Vector2.RIGHT, "split": true}
	_sync_tiles()
	_refresh_fusion()
	_refresh_hud()
	_publish()

func _collect(id: int) -> void:
	if not _can_play() or game.collection_batch_active() or not game.is_valid_word(_cell(id)):
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
	if not _can_play() or _pointer != NO_POINTER or game.collection_batch_active():
		return
	cancel_input()
	game.start_collection_batch()
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
	_word_reveal.present(word, _picture(word), _theme.get("accent", Style.GOOD))
	# Batch pickups keep their pop rhythm; pronunciation belongs to direct taps.
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
	if game.try_merge(first, second, held_source) == "merged":
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
	else:
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
		elif str(active.operation) == "split":
			items.append_array(active.results)
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
						"sway": float(preview._gel.get_shader_parameter("preview_sway"))}
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
		tile.visible = not _result_visible
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
				tile.set_preview_pressure(float(source_pose.get("pressure", 0.0)) * release, float(source_pose.get("sway", 0.0)) * release)
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

func _sync_preview() -> void:
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
		preview.visible = _configured and not _result_visible and index < game.upcoming.size() and refill > 0.0
		if not preview.visible:
			continue
		var item: Dictionary = game.upcoming[index]
		if preview.tile_id != int(item.id):
			_configure_tile(preview, item)
		_apply_palette(preview, int(item.id))
		var pose: Dictionary = _preview_pose(index)
		preview.position = _preview_origins[index]
		preview.modulate.a = clampf(refill, 0.0, 1.0)
		preview.deform(0.0, 0.0)
		preview.set_preview_pressure(float(pose.pressure), float(pose.sway))

func _preview_pose(index: int) -> Dictionary:
	return Motion.preview(game.spawn_elapsed, game.spawn_interval, index, reduced_motion or game.phase != "playing" or not game.can_drop_now())

func _process(delta: float) -> void:
	if _can_play() and delta <= 0.5:
		_word_reveal.advance(delta)
		collect_button.advance(delta)
	var generation: int = _generation
	var previous_rows: Dictionary = {}
	for cell: Dictionary in game.cells:
		previous_rows[int(cell.id)] = int(cell.row)
	super._process(delta)
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
	super._refresh_marks()
	_refresh_palette()
	if _keyboard_source >= 0 and _tiles.has(_keyboard_source):
		_tiles[_keyboard_source].set_marked(false, true, _can_play(), reduced_motion)

func navigation_controls() -> Array[Control]:
	if not _can_play():
		return super.navigation_controls()
	var controls: Array[Control] = []
	var ordered: Array = game.cells.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.row) * WordModel.COLUMNS + int(a.column) < int(b.row) * WordModel.COLUMNS + int(b.column))
	for cell: Dictionary in ordered:
		if _settled(cell) and _tiles.has(int(cell.id)) and not game.collection_batch_active():
			controls.append(_tiles[int(cell.id)])
	if not collect_button.disabled:
		controls.append(collect_button)
	if not drop_button.disabled:
		controls.append(drop_button)
	if not finish_button.disabled:
		controls.append(finish_button)
	return controls

func _contact_state() -> Dictionary:
	var state := {"kind": "none", "source": -1, "target": -1, "strength": 0.0, "direction": Vector2.ZERO}
	if bool(_rejection.get("split", false)):
		state.merge({"kind": "mismatch", "source": int(_rejection.a),
			"strength": sin(clampf(float(_rejection.elapsed) / 0.34, 0.0, 1.0) * PI), "direction": Vector2.RIGHT}, true)
		return state
	if not _can_play() or not _dragging or _source < 0 or _target < 0 or not _tiles.has(_target):
		return state
	var direction: Vector2 = (_tiles[_target].get_rect().get_center() - _tiles[_source].get_rect().get_center()).normalized()
	state.merge({"kind": "match", "source": _source, "target": _target,
		"strength": lerpf(0.2, 0.65, smoothstep(0.0, 0.14, _contact_elapsed)), "direction": direction}, true)
	return state

func _ensure_fusion_visual(fusion: Dictionary) -> Dictionary:
	var id: String = str(fusion.attempt_id)
	if not _fusion_visuals.has(id):
		_refresh_palette()
		var splitting: bool = str(fusion.operation) == "split"
		var art := FusionArt.new()
		art.z_index = 25
		add_child(art)
		art.configure(SURFACES, 0, 0, _surfaces[0])
		var color_a: int = int(_palette_cache.get(int(fusion.a_id), 0))
		var color_b: int = int(_palette_cache.get(int(fusion.b_id), 0))
		var parts: Array[WordTile] = []
		if splitting:
			for child: Dictionary in fusion.results:
				var part := WordTile.new()
				part.focus_mode = Control.FOCUS_NONE
				part.disabled = true
				part.z_index = 30
				add_child(part)
				_configure_tile(part, child)
				parts.append(part)
			color_a = parts[0].palette_index
			color_b = parts[1].palette_index
		art._gel.set_shader_parameter("palette_hue_a", Palette.hue(color_a))
		art._gel.set_shader_parameter("palette_hue_b", Palette.hue(color_b))
		var merged := WordTile.new()
		merged.focus_mode = Control.FOCUS_NONE
		merged.disabled = true
		merged.z_index = 30
		add_child(merged)
		_configure_tile(merged, fusion.result if str(fusion.operation) == "merge" else fusion.a)
		_fusion_visuals[id] = {"art": art, "merged": merged, "parts": parts,
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
	for part: WordTile in _fusion_visuals[id].get("parts", []):
		part.hide()
		part.queue_free()
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
	if str(fusion.operation) == "split":
		_pose_split(fusion, visual, p)
		return
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

func _pose_split(fusion: Dictionary, visual: Dictionary, p: float) -> void:
	var parent_rect: Rect2 = _tile_rect(fusion.a)
	var merged: WordTile = visual.merged
	var separation: float = smoothstep(0.12, 0.86, p)
	var handover: float = smoothstep(0.68, 0.95, p)
	var parent_opacity: float = 1.0 - smoothstep(0.08, 0.38, p)
	merged.size = parent_rect.size
	merged.position = parent_rect.position
	merged.modulate.a = parent_opacity
	merged._surface.visible = reduced_motion
	merged.deform(0.0, 0.0, Vector2.ONE)
	merged.show()
	var centers: Array[Vector2] = []
	var extents: Array[Vector2] = []
	for index in range(visual.parts.size()):
		var part: WordTile = visual.parts[index]
		_apply_palette(part, int(fusion.results[index].id))
		var parent_hue: float = Palette.hue(merged.palette_index)
		var part_hue: float = Palette.hue(part.palette_index)
		visual.art._gel.set_shader_parameter("palette_hue_a" if index == 0 else "palette_hue_b",
			fposmod(parent_hue + (fposmod(part_hue - parent_hue + 0.5, 1.0) - 0.5) * separation, 1.0))
		var rect: Rect2 = _tile_rect(fusion.results[index])
		var center: Vector2 = rect.get_center() if reduced_motion else parent_rect.get_center().lerp(rect.get_center(), separation)
		var extent: Vector2 = rect.size if reduced_motion else parent_rect.size.lerp(rect.size, separation)
		var recoil: float = sin(clampf((p - 0.65) / 0.35, 0.0, 1.0) * TAU) * (1.0 - p) * 0.12
		var stretch := Vector2.ONE if reduced_motion else Vector2(1.0 + recoil, 1.0 - recoil)
		part.size = extent
		part.position = center - extent * 0.5
		part.modulate.a = smoothstep(0.25, 0.62, p)
		part._surface.visible = reduced_motion or handover > 0.0
		part._surface.modulate.a = 1.0 if reduced_motion else handover
		part.deform(0.0, 0.0, stretch)
		part.show()
		centers.append(center)
		extents.append(extent * stretch)
	if reduced_motion:
		visual.art.hide()
	else:
		# Reverse the existing painted liquid union: a waist forms, then the two
		# original skins pull apart and hand over at their reserved destinations.
		visual.art.pose(centers[0], centers[1], parent_rect.get_center(), extents[0], extents[1],
			_pitch, (1.0 - separation) * 0.54, 0.0, 0.0, 1.0 - handover)
		visual.art.stage = "split"

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
	_loot_detail.visible = _loot_detail.visible and _compact_hud
	_notice.hide()
	if not game.error.is_empty():
		_notice.text = game.error
		_notice.show()
	_refresh_collect_button()

func _refresh_controls() -> void:
	super._refresh_controls()
	if collect_button == null:
		return
	if game.collection_batch_active():
		for tile: Tile in _tiles.values():
			tile.disabled = true
		drop_button.disabled = true
	_refresh_collect_button()

func _refresh_collect_button() -> void:
	if collect_button == null:
		return
	var batch: Dictionary = game.collection_batch_snapshot()
	var count: int = game.collectable_ids().size() if _configured else 0
	collect_button.visible = _configured and game.phase == "playing" and not _result_visible
	collect_button.disabled = not _can_play() or _pointer != NO_POINTER or bool(batch.active) or count == 0
	collect_button.set_reduced_motion(reduced_motion)
	collect_button.set_state(count, _configured and bool(batch.active), int(batch.remaining) if _configured else 0, int(batch.total) if _configured else 0)

func _reward_pickup_ready() -> bool:
	# Let the collection rhythm reach its final word before a queued chest
	# takes the screen's focal position. Fragment credit remains immediate.
	return not game.collection_batch_active() and super._reward_pickup_ready()

func result_reveal() -> void:
	_word_reveal.reset()
	super.result_reveal()
	_result_caption.text = "%d words · %d coins" % [game.cleared_pairs, game.collected_coins]
	_publish()

func _refresh_danger() -> void:
	if _danger_frame != null:
		_danger_frame.set_warning(_can_play() and float(game.full_elapsed) >= 0.0, float(game.full_elapsed), WordModel.FULL_SECONDS, reduced_motion)

func _layout() -> void:
	if _loot_icon == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var s: float = Style.ui_scale(self)
	var accent: Color = _theme.get("accent", Style.GOOD)
	Style.action_button(chests_button, accent, true)
	Style.action_button(replay_button, accent)
	var edge: float = 8.0 / s
	var bottom_padding: float = 12.0 / s
	var padding: float = 5.0 / s
	var feed_gap: float = 10.0 / s
	var hud_width: float = 108.0 / s
	var hud_gap: float = 12.0 / s
	var available := Vector2(size.x - edge * 2.0, size.y - bottom_padding - padding * 2.0 - feed_gap)
	_pitch = _fit_layout_pitch(available, s)
	# The well determines the supply columns and the available HUD gutter.
	# Portrait tablets can have a side rail; narrow phones use a shared footer.
	var side_hud: bool = (size.x - _pitch * WordModel.COLUMNS) * 0.5 >= edge + hud_gap + hud_width
	_compact_hud = side_hud
	var footer_height: float = 0.0 if side_hud else 52.0 / s + edge
	available.y -= footer_height
	_pitch = _fit_layout_pitch(available, s)
	var preview_size: float = minf(48.0 / s, _pitch * 0.84)
	var preview_height: float = maxf(44.0 / s, preview_size + padding * 2.0)
	var feed_height: float = preview_height + feed_gap
	var group_top: float = maxf(0.0, size.y - bottom_padding - footer_height - _pitch * WordModel.ROWS - feed_height)
	var next_board := Rect2(Vector2((size.x - _pitch * WordModel.COLUMNS) * 0.5, group_top + feed_height), Vector2(WordModel.COLUMNS, WordModel.ROWS) * _pitch)
	if next_board != _board:
		# Reflow belongs to gameplay. A resize must place every hit target inside
		# the new well immediately, even while the game clock is paused.
		if _dragging:
			cancel_input()
		_rest_rects.clear()
		_reflow.clear()
		_snapbacks.clear()
	_board = next_board
	_gap = maxf(3.0 / s, _pitch * 0.09)
	_danger_frame.layout_frame(_board.grow(2.0), s, 18.0)
	_falling_layer.position = _board.position
	_falling_layer.size = _board.size
	var footer_width: float = maxf(_board.size.x, minf(size.x - edge * 2.0, 308.0 / s))
	var hud_x: float = _board.position.x - hud_width - hud_gap if side_hud else (size.x - footer_width) * 0.5
	var meter_edge: float = (60.0 if side_hud else 44.0) / s
	_loot_meter.position = Vector2(hud_x + (hud_width - meter_edge) * 0.5, group_top) if side_hud else Vector2(hud_x, _board.end.y + edge + 8.0 / s)
	_loot_meter.size = Vector2.ONE * meter_edge
	_loot_icon.size = Vector2.ONE * meter_edge * 0.67
	_loot_icon.position = _loot_meter.position + (_loot_meter.size - _loot_icon.size) * 0.5
	_loot_detail.position = Vector2(hud_x, _loot_meter.position.y + meter_edge + 2.0 / s) if side_hud else _loot_meter.position + Vector2(meter_edge + 6.0 / s, 14.0 / s)
	_loot_detail.size = Vector2(hud_width if side_hud else maxf(0.0, footer_width - meter_edge - hud_width - 14.0 / s), 16.0 / s)
	_loot_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if side_hud else HORIZONTAL_ALIGNMENT_LEFT
	_loot_detail.add_theme_font_size_override("font_size", ceili(10.0 / s))
	_preview_rect = Rect2(Vector2(_board.position.x, group_top), Vector2(_board.size.x, preview_height))
	drop_button.position = _preview_rect.position
	drop_button.size = _preview_rect.size
	_style_drop_button()
	for index in range(_preview_tiles.size()):
		_preview_tiles[index].size = Vector2.ONE * preview_size
		_preview_origins[index] = _preview_rect.position + Vector2((float(index) + 0.5) * _pitch - preview_size * 0.5, (preview_height - preview_size) * 0.5)
	_style_finish_button()
	finish_button.size = Vector2(hud_width if side_hud else 84.0 / s, 44.0 / s)
	finish_button.position = Vector2(hud_x, _board.end.y - finish_button.size.y) if side_hud else Vector2(hud_x + footer_width - finish_button.size.x, _board.end.y + edge + 8.0 / s)
	if collect_button != null:
		collect_button.set_ui_scale(s)
		collect_button.size = Vector2(hud_width, minf(96.0 / s, _board.size.y * 0.44)) if side_hud else Vector2(minf(136.0 / s, footer_width - meter_edge - finish_button.size.x - 20.0 / s), 52.0 / s)
		collect_button.position = Vector2(hud_x, finish_button.position.y - collect_button.size.y - 16.0 / s) if side_hud else Vector2(hud_x + meter_edge + (footer_width - meter_edge - finish_button.size.x - collect_button.size.x) * 0.5, _board.end.y + edge)
	_notice.position = Vector2(hud_x, _loot_detail.position.y + _loot_detail.size.y + edge) if side_hud else Vector2(_board.position.x, maxf(0.0, group_top - 42.0 / s - edge))
	_notice.size = Vector2(hud_width if side_hud else _board.size.x, 42.0 / s)
	_notice.add_theme_font_size_override("font_size", ceili(12.0 / s))
	_result.position = Vector2.ZERO
	_result.size = size
	_reward_presentation.size = size
	_reward_presentation.set_chest_anchor(_loot_icon.get_rect())
	if _word_reveal != null:
		_word_reveal.configure_layout(Rect2(Vector2(edge, edge), Vector2(size.x - edge * 2.0, minf(180.0 / s, size.y * 0.36))), s)
	_layout_result(s, edge)
	_sync_positions()
	_refresh_fusion()
	_refresh_hud()
	queue_redraw()
	_publish()

func _fit_layout_pitch(available: Vector2, s: float) -> float:
	# A small well also has a smaller supply row, leaving room for the game.
	var height_pitch: float = maxf(available.y / (WordModel.ROWS + 0.84), (available.y - 48.0 / s) / WordModel.ROWS)
	height_pitch = minf(height_pitch, (available.y - 34.0 / s) / WordModel.ROWS)
	return maxf(8.0, minf(minf(available.x / WordModel.COLUMNS, height_pitch), 78.0 / s))

func snapshot() -> Dictionary:
	var state: Dictionary = super.snapshot()
	state["mode"] = "word_jelly"
	state["columns"] = WordModel.COLUMNS
	state["rows"] = WordModel.ROWS
	state["board_ratio"] = float(WordModel.COLUMNS) / WordModel.ROWS
	state["playfield_rect"] = _rect(get_global_rect())
	state["word_reveal"] = _word_reveal.snapshot() if _word_reveal != null else {"visible": false}
	state["collect_button"] = collect_button.snapshot() if collect_button != null else {}
	state["placement"] = {"visible": _placement_tile != null and _placement_tile.is_visible_in_tree(), "valid": false}
	if not _placement.is_empty():
		state.placement.merge(_placement, true)
		state.placement.rect = _rect(_global_rect(_placement.rect))
	if collect_button != null:
		state.collect_button.merge({"rect": _rect(collect_button.get_global_rect()), "enabled": not collect_button.disabled, "visible": collect_button.is_visible_in_tree()}, true)
	state.preview.enabled = state.preview.enabled and not game.collection_batch_active()
	state.drag.selected = _keyboard_source
	for item: Dictionary in state.tiles:
		var tile: WordTile = _tiles[int(item.id)]
		item["picture_visible"] = tile._picture.is_visible_in_tree()
		item["fragment_badges"] = tile.visible_fragment_badges()
		item["coins"] = WordModel.coins_for_tile(item)
		item["splittable"] = game.can_split(item)
		item["palette_index"] = tile.palette_index
		item["palette_hue"] = tile._gel.get_shader_parameter("palette_hue")
	for index in range(state.preview.slots.size()):
		state.preview.slots[index]["palette_index"] = _preview_tiles[index].palette_index
		state.preview.slots[index]["palette_hue"] = _preview_tiles[index]._gel.get_shader_parameter("palette_hue")
	for effect: Dictionary in state.fusion_effects:
		var visual: Dictionary = _fusion_visuals[str(effect.attempt_id)]
		effect["parts"] = []
		for part: WordTile in visual.get("parts", []):
			effect.parts.append({"id": part.tile_id, "rect": _rect(part.get_global_rect()), "visible": part.is_visible_in_tree()})
	return state

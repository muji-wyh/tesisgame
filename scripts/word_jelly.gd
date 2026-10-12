class_name WordJelly
extends "res://scripts/jelly_match.gd"
## Six-column word construction, with the established jelly input and rewards.

signal collected(event_id: String, word: Dictionary, amount: int, fragments: int, origin: Vector2)

const WordModel = preload("res://scripts/word_jelly_model.gd")
const WordTile = preload("res://scripts/word_jelly_tile.gd")

var credit_collection: Callable:
	set(value):
		credit_collection = value
		game.credit_collection = value
var _collection_origins: Dictionary = {}
var _rest_rects: Dictionary = {}
var _reflow: Dictionary = {}
var _keyboard_source: int = -1

func _init() -> void:
	super()
	name = "WordJelly"
	game = WordModel.new()
	game.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		word_attempted.emit(id, ids, correct))
	game.cue_requested.connect(_cue)
	game.fusion_completed.connect(_fusion_completed)
	game.collected.connect(_collected)
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
	drop_button.tooltip_text = "Drop the next word parts"

func stop() -> void:
	super.stop()
	_collection_origins.clear()
	_rest_rects.clear()
	_reflow.clear()
	_keyboard_source = -1

func cancel_input() -> void:
	_keyboard_source = -1
	super.cancel_input()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _keyboard_source >= 0:
		cancel_input()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _press(pointer: int, global_point: Vector2) -> bool:
	# Roots have no pronunciation recording; a completed word keeps its audio.
	if _pointer != NO_POINTER or not _can_play():
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
		_collect(source)

func _activate(id: int) -> void:
	if not _can_play() or _pointer != NO_POINTER or not _settled(_cell(id)):
		return
	if _keyboard_source >= 0 and _keyboard_source != id and _tiles.has(_keyboard_source):
		var source: int = _keyboard_source
		_keyboard_source = -1
		_merge(source, id, _tiles[source].position)
	elif game.is_valid_word(_cell(id)):
		_collect(id)
	else:
		_keyboard_source = -1 if _keyboard_source == id else id
		_refresh_marks()
		_publish()

func _collect(id: int) -> void:
	if not _can_play() or not game.is_valid_word(_cell(id)):
		return
	var word: Dictionary = _cell(id).word.duplicate(true)
	var origin: Vector2 = _tiles[id].get_global_rect().get_center()
	if not game.collect(id):
		return
	for fusion: Dictionary in game.fusions:
		if str(fusion.operation) == "collect" and int(fusion.a_id) == id:
			_collection_origins[str(fusion.attempt_id)] = origin
	word_requested.emit(word)
	_refresh_controls()
	_refresh_fusion()
	_publish()

func _collected(event_id: String, word: Dictionary, coins: int, fragments: int) -> void:
	_cue("danger_end")
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
	tile.configure(cell, _surfaces[posmod(int(cell.get("skin", cell.id)), _surfaces.size())], _picture(cell.word), _chest_texture, _theme.get("accent", Style.GOOD), combined)

func _sync_tiles() -> void:
	if not _configured:
		return
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
	_refresh_marks()
	_sync_positions()
	_refresh_controls()

func _tile_rect(cell: Dictionary) -> Rect2:
	return Rect2(_board.position + Vector2(int(cell.get("column", 0)), int(cell.get("row", 0))) * _pitch + Vector2.ONE * _gap * 0.5,
		Vector2(int(cell.get("width", 1)), int(cell.get("height", 1))) * _pitch - Vector2.ONE * _gap)

func _sync_positions() -> void:
	for cell: Dictionary in game.cells:
		var id: int = int(cell.id)
		if not _tiles.has(id):
			continue
		var tile: WordTile = _tiles[id]
		var rect: Rect2 = _tile_rect(cell)
		if _rest_rects.has(id) and _rest_rects[id] != rect and not reduced_motion:
			_reflow[id] = {"from": tile.position, "started": float(cell.age)}
		_rest_rects[id] = rect
		tile.size = rect.size
		tile._surface.show()
		tile.modulate.a = 1.0
		tile.visible = not _result_visible
		var dragging: bool = id == _source and _dragging
		tile.z_index = 40 if dragging else 1
		var stretch: Vector2 = Vector2.ONE
		if not dragging:
			tile.position = rect.position
			if _snapbacks.has(id) and not reduced_motion:
				var p: float = clampf(float(_snapbacks[id].elapsed) / 0.24, 0.0, 1.0)
				tile.position = Vector2(_snapbacks[id].from).lerp(rect.position, 1.0 - pow(1.0 - p, 3.0))
			elif _reflow.has(id) and not reduced_motion:
				var p: float = clampf((float(cell.age) - float(_reflow[id].started)) / WordModel.SETTLE_SECONDS, 0.0, 1.0)
				tile.position = Vector2(_reflow[id].from).lerp(rect.position, smoothstep(0.0, 1.0, p))
				if p >= 1.0:
					_reflow.erase(id)
			elif bool(cell.get("settling", false)) and not reduced_motion:
				var p: float = clampf(float(cell.age) / WordModel.SETTLE_SECONDS, 0.0, 1.0)
				var lift: float = (1.0 - p) * (1.0 - p) * _pitch * 0.8 if bool(cell.get("arrival", false)) else 0.0
				tile.position.y -= lift
				var bounce: float = sin(p * PI) * (1.0 - p) * 0.14
				stretch = Vector2(1.0 + bounce, 1.0 - bounce)
		tile.deform(0.0, 0.0, DRAG_STRETCH if dragging and not reduced_motion else stretch)
		tile.set_support(6.0 / Style.ui_scale(self) if dragging else 0.0)
	if _dragging:
		var target: int = _drag_target()
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
		var pose: Dictionary = _preview_pose(index)
		preview.position = _preview_origins[index]
		preview.deform(0.0, 0.0)
		preview.set_preview_pressure(float(pose.pressure), float(pose.sway))

func _preview_pose(index: int) -> Dictionary:
	return Motion.preview(game.spawn_elapsed, game.spawn_interval, index, reduced_motion or game.phase != "playing" or not game.can_drop_now())

func _refresh_marks() -> void:
	super._refresh_marks()
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
		if _settled(cell) and _tiles.has(int(cell.id)):
			controls.append(_tiles[int(cell.id)])
	if not drop_button.disabled:
		controls.append(drop_button)
	if not finish_button.disabled:
		controls.append(finish_button)
	return controls

func _contact_state() -> Dictionary:
	var state := {"kind": "none", "source": -1, "target": -1, "strength": 0.0, "direction": Vector2.ZERO}
	if not _can_play() or not _dragging or _source < 0 or _target < 0 or not _tiles.has(_target):
		return state
	var direction: Vector2 = (_tiles[_target].get_rect().get_center() - _tiles[_source].get_rect().get_center()).normalized()
	state.merge({"kind": "match", "source": _source, "target": _target,
		"strength": lerpf(0.2, 0.65, smoothstep(0.0, 0.14, _contact_elapsed)), "direction": direction}, true)
	return state

func _ensure_fusion_visual(fusion: Dictionary) -> Dictionary:
	var id: String = str(fusion.attempt_id)
	if not _fusion_visuals.has(id):
		var art := FusionArt.new()
		art.z_index = 25
		add_child(art)
		art.configure(SURFACES, int(fusion.a.get("skin", fusion.a_id)), int(fusion.b.get("skin", fusion.b_id)), _surfaces[posmod(int(fusion.b_id), _surfaces.size())])
		var merged := WordTile.new()
		merged.focus_mode = Control.FOCUS_NONE
		merged.disabled = true
		merged.z_index = 30
		add_child(merged)
		_configure_tile(merged, fusion.a if str(fusion.operation) == "collect" else fusion.result)
		_fusion_visuals[id] = {"art": art, "merged": merged,
			"start": _tile_rect(fusion.a).get_center(), "direction": Vector2.RIGHT,
			"origin_a": _tile_rect(fusion.a).get_center(), "origin_b": _tile_rect(fusion.b).get_center(),
			"stretch_a": Vector2.ONE, "stretch_b": Vector2.ONE}
	return _fusion_visuals[id]

func _pose_fusion(fusion: Dictionary, visual: Dictionary) -> void:
	var merged: WordTile = visual.merged
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
		merged._surface.show()
		var charge: float = smoothstep(0.0, 0.42, p)
		var release: float = smoothstep(0.42, 1.0, p)
		merged.scale = Vector2.ONE if reduced_motion else Vector2(1.0 + charge * 0.12, 1.0 - charge * 0.12).lerp(Vector2.ONE * 0.18, release)
		merged.modulate.a = 1.0 - release
		merged.show()
		return
	var target_size: Vector2 = _tile_rect(fusion.result).size
	var destination: Vector2 = _tile_rect(fusion.result).get_center()
	var joining: float = smoothstep(0.0, 0.68, p)
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

func _fusion_completed(fusion: Dictionary, _awarded: int) -> void:
	_cue("danger_end")
	if str(fusion.get("operation", "")) == "merge" and not reduced_motion:
		var visual: Dictionary = _fusion_visuals.get(str(fusion.attempt_id), {})
		if not visual.is_empty():
			_snapbacks[int(fusion.result.id)] = {"from": visual.merged.position, "elapsed": 0.0}
	_refresh_hud()

func _landing_contact_at(_cell_value: Dictionary) -> float:
	return WordModel.SETTLE_SECONDS

func _refresh_hud() -> void:
	super._refresh_hud()
	_notice.hide()
	if not game.error.is_empty():
		_notice.text = game.error
		_notice.show()

func result_reveal() -> void:
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
	var wide: bool = size.x > size.y * 1.18 or size.y * s < 340.0
	_compact_hud = wide
	var edge: float = 8.0 / s
	var side: float = minf(144.0 / s, size.x * 0.18) if wide else 0.0
	var available: Vector2 = Vector2(size.x - 2.0 * (edge + side), size.y - (edge * 2.0 if wide else 136.0 / s))
	_pitch = maxf(8.0, minf(minf(available.x / WordModel.COLUMNS, available.y / WordModel.ROWS), 78.0 / s))
	var next_board := Rect2(Vector2((size.x - _pitch * WordModel.COLUMNS) * 0.5, edge if wide else 78.0 / s), Vector2(WordModel.COLUMNS, WordModel.ROWS) * _pitch)
	if next_board != _board:
		# Reflow belongs to gameplay. A resize must place every hit target inside
		# the new well immediately, even while the game clock is paused.
		_rest_rects.clear()
		_reflow.clear()
		_snapbacks.clear()
	_board = next_board
	_gap = maxf(1.5 / s, _pitch * 0.025)
	_danger_frame.layout_frame(_board.grow(2.0), s, 18.0)
	_falling_layer.position = _board.position
	_falling_layer.size = _board.size
	var hud_width: float = minf(128.0 / s, maxf(32.0 / s, _board.position.x - edge * 2.0)) if wide else 64.0 / s
	var meter_edge: float = minf(60.0 / s, hud_width)
	_loot_meter.position = Vector2(maxf(edge, _board.position.x - hud_width - edge), _board.position.y + edge) if wide else Vector2(edge, 0)
	_loot_meter.size = Vector2.ONE * meter_edge
	_loot_icon.size = Vector2.ONE * meter_edge * 0.67
	_loot_icon.position = _loot_meter.position + (_loot_meter.size - _loot_icon.size) * 0.5
	_loot_detail.position = _loot_meter.position + Vector2(-8.0 / s, meter_edge)
	_loot_detail.size = Vector2(meter_edge + 16.0 / s, 16.0 / s)
	_loot_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loot_detail.add_theme_font_size_override("font_size", ceili(10.0 / s))
	var preview_width: float = minf(144.0 / s, maxf(30.0 / s, size.x - _board.end.x - edge * 2.0)) if wide else size.x - 88.0 / s - edge
	var columns: int = 2 if wide else WordModel.UPCOMING_COUNT
	var padding: float = 5.0 / s
	var preview_size: float = minf(48.0 / s, (preview_width - padding * 2.0) / columns)
	var rows: int = ceili(float(WordModel.UPCOMING_COUNT) / columns)
	_preview_rect = Rect2(Vector2(_board.end.x + edge, _board.position.y) if wide else Vector2(80.0 / s, 0), Vector2(preview_width, preview_size * rows + padding * 2.0))
	drop_button.position = _preview_rect.position
	drop_button.size = _preview_rect.size
	_style_drop_button()
	for index in range(_preview_tiles.size()):
		_preview_tiles[index].size = Vector2.ONE * preview_size
		_preview_origins[index] = _preview_rect.position + Vector2((preview_width - preview_size * columns) * 0.5 + (index % columns) * preview_size, padding + floorf(float(index) / columns) * preview_size)
	_style_finish_button()
	finish_button.size = Vector2(minf(108.0 / s, hud_width) if wide else 108.0 / s, 42.0 / s)
	finish_button.position = Vector2(_loot_meter.position.x, _board.end.y - finish_button.size.y) if wide else Vector2(_board.end.x - finish_button.size.x, _board.end.y + edge)
	_notice.position = Vector2(_board.position.x, _board.end.y + edge)
	_notice.size = Vector2(maxf(0, _board.size.x - finish_button.size.x - edge), 42.0 / s)
	_notice.add_theme_font_size_override("font_size", ceili(12.0 / s))
	_result.position = Vector2.ZERO
	_result.size = size
	_reward_presentation.size = size
	_reward_presentation.set_chest_anchor(_loot_icon.get_rect())
	_layout_result(s, edge)
	_sync_positions()
	_refresh_fusion()
	_refresh_hud()
	queue_redraw()
	_publish()

func snapshot() -> Dictionary:
	var state: Dictionary = super.snapshot()
	state["mode"] = "word_jelly"
	state["columns"] = WordModel.COLUMNS
	state["rows"] = WordModel.ROWS
	state["board_ratio"] = float(WordModel.COLUMNS) / WordModel.ROWS
	state.drag.selected = _keyboard_source
	for item: Dictionary in state.tiles:
		var tile: WordTile = _tiles[int(item.id)]
		item["picture_visible"] = tile._picture.is_visible_in_tree()
		item["fragment_badges"] = tile.visible_fragment_badges()
		item["coins"] = WordModel.coins_for_tile(item)
	return state

extends SceneTree

const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
const Quest = preload("res://scripts/talk_quest.gd")

var checks: int = 0
var failures: int = 0
var directory: String = ""


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func _isolate_quest(node: Node) -> void:
	if node.get_script() == Quest:
		node.save_path = directory + "/quest.cfg"


func _tap(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()


func _start(app, seed_value: int = 21) -> void:
	check(app.new_round(seed_value, false, "music-makers", "match", "microphone"),
		"The isolated fixture starts a real five-pair Match round")
	app.feedback_timer.paused = true
	await settle()
	check(app._match_connections.connections.is_empty(), "A new round has no completed connections")
	check(app._match_connections.focused_id.is_empty() and app._match_connections.visible_connections().is_empty(),
		"A new round has neither a focused pair nor a visible connector")


func _words(app) -> Array[String]:
	var words: Array[String] = []
	for card in app.model.cards:
		if card.kind == "image":
			words.append(str(card.word.id))
	return words


func _connection_snapshot(app) -> Dictionary:
	var result: Dictionary = {}
	for connection in app._match_connections.connections:
		result[connection.id] = {
			"lane": connection.lane, "color": connection.color,
			"path": connection.path.duplicate(),
			"source": connection.source.get_instance_id(),
			"target": connection.target.get_instance_id(),
		}
	return result


func _global_path(layer: Control, path: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in path:
		points.append(layer.get_global_transform() * point)
	return points


func _segment_enters(a: Vector2, b: Vector2, bounds: Rect2) -> bool:
	if bounds.has_point(a) or bounds.has_point(b):
		return true
	var corners := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	for edge in range(4):
		if Geometry2D.segment_intersects_segment(a, b, corners[edge], corners[(edge + 1) % 4]) != null:
			return true
	return false


func _check_visible_connections(app, expected_count: int, stage: String) -> void:
	var layer = app._match_connections
	var visible: Array = layer.visible_connections()
	check(visible.size() == expected_count, stage + ": every completed pair retains its visible connection")
	var visible_ids: Array[String] = []
	for connection in visible:
		check(layer.connections.has(connection) and not visible_ids.has(str(connection.id)),
			stage + ": every painted connection is a unique completed pair")
		visible_ids.append(str(connection.id))
	for connection in layer.connections:
		check(visible_ids.has(str(connection.id)), stage + ": an earlier completed connection is never filtered out")
	if not visible.is_empty():
		check(visible.back().id == layer.focused_id,
			stage + ": the focused connection paints last while all earlier connections remain visible")


func _check_geometry(app, expected_count: int, stage: String) -> void:
	var layer = app._match_connections
	check(layer.connections.size() == expected_count, stage + ": each completed pair owns exactly one connection")
	check(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE and not layer.is_processing(),
		stage + ": persistent connectors neither intercept input nor keep an idle animation loop running")
	_check_visible_connections(app, expected_count, stage)
	check(layer.vertical_pairs == (app.grid.columns == 5), stage + ": routing follows the actual grouped board orientation")
	var board: Rect2 = app._match_playfield.get_global_rect()
	var scale: float = app.Style.ui_scale(layer)
	var lanes: Array[int] = []
	var ids: Array[String] = []
	for connection in layer.connections:
		var word_id: String = str(connection.id)
		var valid_pair: bool = app.cards.has(word_id + ":image") and app.cards.has(word_id + ":word")
		check(valid_pair and not ids.has(word_id), stage + ": the connection identifies one unique real lesson word")
		ids.append(word_id)
		if not valid_pair:
			continue
		check(connection.source == app.cards[word_id + ":image"] and connection.target == app.cards[word_id + ":word"]
			and app.model.matched_ids.has(word_id + ":image") and app.model.matched_ids.has(word_id + ":word"),
			stage + ": the line joins the completed picture to its own word")
		var lane: int = int(connection.lane)
		check(lane >= 0 and lane < 5 and not lanes.has(lane), stage + ": completed pairs keep distinct stable identities")
		lanes.append(lane)
		check(connection.color is Color and connection.color.a > 0.0, stage + ": the completed connection is visibly colored")
		for card in [connection.source, connection.target]:
			check(card.match_mark.visible and card.match_mark.pair_number == lane + 1
				and card.match_mark.tint == connection.color,
				stage + ": both cards retain the same numbered, colored pair badge")
			check(card.match_mark.active == (word_id == layer.focused_id),
				stage + ": only the focused pair's badges are emphasized")
			check(card.get_theme_stylebox("normal").border_color == connection.color,
				stage + ": each completed card's border identifies the same pair as its badge")
			for interaction in ["hover", "pressed", "focus"]:
				check(card.get_theme_stylebox(interaction).border_color == connection.color,
					stage + ": " + interaction + " keeps the completed card's pair color")
		var points: PackedVector2Array = _global_path(layer, connection.path)
		check(points.size() >= 2, stage + ": the connection has both card contacts")
		if points.size() < 2:
			continue
		var picture: Rect2 = connection.source.get_global_rect()
		var word: Rect2 = connection.target.get_global_rect()
		var from_edge := Vector2(picture.get_center().x, picture.end.y) if layer.vertical_pairs \
			else Vector2(picture.end.x, picture.get_center().y)
		var to_edge := Vector2(word.get_center().x, word.position.y) if layer.vertical_pairs \
			else Vector2(word.position.x, word.get_center().y)
		check(points[0].distance_to(from_edge) * scale <= 3.5
			and points[-1].distance_to(to_edge) * scale <= 3.5,
			stage + ": both contacts stay at the facing edge midpoints without crossing the artwork")
		var inside_board: bool = true
		var clear_of_cards: bool = true
		for point in points:
			inside_board = inside_board and point.is_finite() and board.grow(1.0 / scale).has_point(point)
		for card in app.cards.values():
			var own_endpoint: bool = card == connection.source or card == connection.target
			var interior: Rect2 = card.get_global_rect().grow(-(4.0 if own_endpoint else 0.5) / scale)
			for index in range(points.size() - 1):
				clear_of_cards = clear_of_cards and not _segment_enters(points[index], points[index + 1], interior)
		check(inside_board, stage + ": the entire route remains inside the playfield")
		check(clear_of_cards, stage + ": the route avoids every card's text and artwork, including unrelated pairs")
	for card in app.cards.values():
		check(board.grow(1.0 / scale).encloses(card.get_global_rect())
			and minf(card.size.x, card.size.y) * scale >= 44.0,
			stage + ": the reserved gutter keeps each card fully visible and tappable")


func _test_pointer_matches(app) -> void:
	await _start(app)
	var words: Array[String] = _words(app)
	await _tap(app.cards[words[0] + ":image"])
	check(app.model.selected_id == words[0] + ":image" and app._match_connections.connections.is_empty(),
		"A real first pointer selection does not draw a completed connection")
	await _tap(app.cards[words[1] + ":word"])
	check(app.model.mistakes == 1 and app._match_connections.connections.is_empty(),
		"A real incorrect pointer pair cannot create a connection")
	app._resolve_feedback()
	await _tap(app.cards[words[0] + ":word"])
	await _tap(app.cards[words[0] + ":image"])
	check(app.model.phase == "feedback" and app.model.successes == 1
		and app._match_connections.connections.size() == 1 and app._match_connections.focused_id == words[0],
		"A successful real pointer pair is connected during its immediate feedback")
	_check_geometry(app, 1, "First success")
	var first: Dictionary = _connection_snapshot(app)
	app._resolve_feedback()
	await settle()
	check(_connection_snapshot(app) == first and app.model.feedback_ids.is_empty()
		and app._match_connections.focused_id == words[0],
		"The completed connection survives feedback resolution after temporary feedback IDs are cleared")
	_check_visible_connections(app, 1, "First feedback resolved")
	await _tap(app.cards[words[0] + ":image"])
	check(app.model.successes == 1 and app.model.selected_id.is_empty() and _connection_snapshot(app) == first,
		"A pointer tap on a connected card still replays its word without adding a duplicate or scoring")
	for index in range(1, 4):
		app._select_card(words[index] + ":image")
		app._select_card(words[index] + ":word")
		check(app._match_connections.connections.size() == index + 1
			and app._match_connections.focused_id == words[index]
			and app._match_connections.visible_connections().size() == index + 1,
			"Each later success emphasizes its own line without hiding any earlier matched line")
		_check_visible_connections(app, index + 1, "Later success feedback")
		app._resolve_feedback()
		await settle()
		_check_visible_connections(app, index + 1, "Later feedback resolved")
		var current: Dictionary = _connection_snapshot(app)
		check(current.get(words[0], {}) == first[words[0]],
			"Adding another pair preserves the first pair's identity, appearance and exact route")
	_check_geometry(app, 4, "Four accumulated successes")
	var accumulated: Dictionary = _connection_snapshot(app)
	var successes: int = app.model.successes
	var mistakes: int = app.model.mistakes
	var matched: Array = app.model.matched_ids.duplicate()
	for card_id in [words[0] + ":image", words[2] + ":word", words[0] + ":word", words[1] + ":image"]:
		await _tap(app.cards[card_id])
		var expected_id: String = str(app.model.card_by_id(card_id).word.id)
		check(app._match_connections.focused_id == expected_id
			and app._match_connections.visible_connections().size() == 4
			and app._match_connections.visible_connections().back().id == expected_id,
			"Tapping either completed card emphasizes its own connection without hiding the other three")
		check(app.model.successes == successes and app.model.mistakes == mistakes
			and app.model.matched_ids == matched and app.model.selected_id.is_empty()
			and _connection_snapshot(app) == accumulated,
			"Changing completed-pair focus neither scores, selects a card nor changes any saved pairing")
		_check_geometry(app, 4, "Completed-card pointer replay")
	await _tap(app.cards[words[4] + ":image"])
	await _tap(app.cards[words[2] + ":word"])
	check(app.model.selected_id == words[4] + ":image" and app.model.successes == successes
		and app.model.mistakes == mistakes and app._match_connections.focused_id == words[2],
		"Replaying a completed pair preserves an in-progress unmatched selection")
	_check_visible_connections(app, 4, "Completed replay during an unmatched selection")
	await _tap(app.cards[words[4] + ":image"])
	var focus_before: String = app._match_connections.focused_id
	check(not app._match_connections.focus_pair("missing-word")
		and app._match_connections.focused_id == focus_before and _connection_snapshot(app) == accumulated,
		"An unknown pair cannot replace the current focus or damage completed connections")


func _test_responsive_and_lifecycle(app) -> void:
	var before: Dictionary = _connection_snapshot(app)
	var matched: Array = app.model.matched_ids.duplicate()
	var focused: String = app._match_connections.focused_id
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 768), Vector2i(320, 320)]:
		root.size = dimensions
		await settle()
		_check_geometry(app, 4, str(dimensions))
		var current: Dictionary = _connection_snapshot(app)
		var preserved: bool = true
		for id in before:
			preserved = preserved and current.has(id) and current[id].lane == before[id].lane \
				and current[id].source == before[id].source and current[id].target == before[id].target
		check(preserved and app.model.matched_ids == matched and app.model.successes == 4
			and app._match_connections.focused_id == focused,
			"Resize reroutes the same four pairs without rebuilding cards, changing focus or altering progress")
	root.size = Vector2i(390, 844)
	await settle()
	before = _connection_snapshot(app)
	var original_theme: String = app.model.theme_id
	var other_theme: String = app.Model.THEMES.filter(func(id: String) -> bool: return id != original_theme)[0]
	app.choose_theme(other_theme)
	await settle()
	check(app._match_connections.focused_id == focused and _connection_snapshot(app) == before,
		"Changing the theme preserves the chosen pair, its badge colors and completed routes")
	_check_geometry(app, 4, "Theme refresh")
	app.choose_theme(original_theme)
	await settle()
	app._show_mode_menu()
	check(app._mode_menu_open(), "The completed board can still open Pip's mode menu")
	app._hide_mode_menu()
	app.feedback_timer.paused = true
	await settle()
	check(_connection_snapshot(app) == before and app._match_connections.focused_id == focused,
		"Closing the mode menu restores the same completed connections and focused pair")
	_check_visible_connections(app, 4, "Pip menu closed")
	app._show_collection()
	app._hide_collection()
	app.feedback_timer.paused = true
	await settle()
	check(_connection_snapshot(app) == before and app._match_connections.focused_id == focused,
		"Returning from More preserves all completed connections and focused pair")
	_check_visible_connections(app, 4, "More closed")
	app.on_page_hidden()
	app.on_page_visible()
	app.feedback_timer.paused = true
	await settle()
	check(_connection_snapshot(app) == before and app._match_connections.focused_id == focused,
		"A background and foreground cycle preserves the completed routes and focused pair")
	_check_visible_connections(app, 4, "Page restored")
	app.set_reduced_motion(false)
	await settle()
	check(not app._match_connections.is_processing() and _connection_snapshot(app) == before
		and app._match_connections.focused_id == focused,
		"Normal motion does not start a permanent animation loop or change the connection geometry")
	_check_visible_connections(app, 4, "Normal motion restored")
	app.set_reduced_motion(true)
	var remaining: String = ""
	for word_id in _words(app):
		if not app.model.matched_ids.has(word_id + ":word"):
			remaining = word_id
	check(not remaining.is_empty(), "The accumulated board still has one unfinished pair")
	if not remaining.is_empty():
		app._select_card(remaining + ":word")
		app._select_card(remaining + ":image")
		check(app._match_connections.focused_id == remaining, "The final success becomes the focused pair")
		_check_geometry(app, 5, "Final pair feedback")
		app._resolve_feedback()
		await settle()
		check(app.model.phase == "won" and not app._match_connections.is_visible_in_tree(),
			"Completed lines and pair badges leave with the board when the chest result takes over")
	var old_cards: Array[WeakRef] = []
	for card in app.cards.values():
		old_cards.append(weakref(card))
	await _start(app, 37)
	check(old_cards.all(func(reference: WeakRef) -> bool: return reference.get_ref() == null),
		"Restart releases all old card instances instead of retaining connector references")
	var word: String = _words(app)[0]
	app._select_card(word + ":word")
	app._select_card(word + ":image")
	app._resolve_feedback()
	await settle()
	_check_geometry(app, 1, "Fresh round after reset")
	app.choose_mode("memory")
	await settle()
	check(not app._match_connections.is_visible_in_tree(), "Match connections cannot leak into another game mode")
	app.choose_mode("match")
	app.feedback_timer.paused = true
	await settle()
	check(app._match_connections.connections.is_empty() and app._match_connections.focused_id.is_empty()
		and app._match_connections.visible_connections().is_empty(),
		"Returning to Match starts with a clean connection layer and no stale focus")


func _test_voice_retention(app) -> void:
	await _start(app)
	var words: Array[String] = _words(app)
	var prior_id: String = words[0]
	app._select_card(prior_id + ":image")
	app._select_card(prior_id + ":word")
	app._resolve_feedback()
	await settle()
	var word_id: String = words[1]
	var word: Dictionary = app.model.card_by_id(word_id + ":word").word
	app._on_voice_state([true, true, "Listening"])
	await settle()
	var prior_connection: Dictionary = _connection_snapshot(app)[prior_id]
	app._on_voice_result([word.text, true])
	app.feedback_timer.paused = true
	await settle()
	check(app.model.successes == 2 and app._voice_match_link.active
		and app._match_connections.connections.size() == 2 and app._match_connections.focused_id == word_id,
		"A spoken success adds its connection and temporary electric effect beside the earlier completed line")
	_check_visible_connections(app, 2, "Spoken success feedback")
	app._advance_voice_match_feedback(1.01)
	app._resolve_feedback()
	await settle()
	check(not app._voice_match_link.active and app._match_connections.connections.size() == 2
		and app._match_connections.focused_id == word_id
		and _connection_snapshot(app)[prior_id] == prior_connection,
		"Both completed connections survive after the spoken match's temporary electric effect expires")
	_check_visible_connections(app, 2, "Voice effect expired")
	app._stop_voice()
	await settle()
	_check_geometry(app, 2, "Voice stopped after success")


func _test_default_card_badge(app) -> void:
	var card = preload("res://scripts/word_card.gd").new()
	card.setup(app.model.cards[0])
	root.add_child(card)
	card.set_reduced_motion(true)
	var palette: Dictionary = app.Data.theme(app.model.theme_id)
	card.refresh(palette, false, true, false, false)
	check(card.match_mark.visible and card.match_mark.pair_number <= 0
		and card.match_mark.tint == app.Style.GOOD and not card.match_mark.active,
		"A card refreshed without Match pair metadata keeps its ordinary success checkmark")
	check(card.get_theme_stylebox("normal").border_color == app.Style.GOOD,
		"Default completed cards keep the existing green success border used outside Match")
	for interaction in ["hover", "pressed", "focus"]:
		check(card.get_theme_stylebox(interaction).border_color == palette.accent,
			"Default completed cards retain the theme accent for " + interaction + " without Match metadata")
	card.queue_free()
	await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	directory = "user://match-connections-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	node_added.connect(_isolate_quest)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	PlayerFixture.install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.set_process(false)
	await _test_pointer_matches(app)
	await _test_responsive_and_lifecycle(app)
	await _test_voice_retention(app)
	await _test_default_card_badge(app)
	app.queue_free()
	await process_frame
	node_added.disconnect(_isolate_quest)
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Match connections: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

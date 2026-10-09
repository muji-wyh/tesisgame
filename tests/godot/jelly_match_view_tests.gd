extends SceneTree

const Jelly = preload("res://scripts/jelly_match.gd")
const Data = preload("res://scripts/game_data.gd")

var checks: int = 0
var failures: int = 0
var data = Data.new()
var words: Array = []
var heard: Array[Dictionary] = []
var attempts: Array[Dictionary] = []
var cues: Array[String] = []
var finishes: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 720)
	check(data.load_all(), "The view tests use real vocabulary and production chest skins")
	words = data.words.filter(func(word: Dictionary) -> bool: return int(word.min_age) <= 3 and not str(word.get("image", "")).is_empty()).slice(0, 12)
	var view = Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(1000, 720)
	view.word_requested.connect(func(word: Dictionary) -> void: heard.append(word))
	view.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		attempts.append({"id": id, "words": ids, "correct": correct}))
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	view.round_finished.connect(func(result: Dictionary) -> void: finishes.append(result))
	_reset(view)
	_check_layout(view)
	_check_pictures(view)
	await _check_pointer_ownership(view)
	_check_wrong_drop(view)
	_check_fusion(view)
	_check_close_drop_contact(view)
	_check_pauses_and_new_round(view)
	await _check_deferred_release(view)
	_check_result_gate(view)
	_check_reduced_motion_and_cache(view)
	_check_publication_budget(view)
	_check_signal_reentry(view)
	view.free()
	await process_frame
	print("Jelly Match view: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _reset(view, reduced: bool = false) -> void:
	check(view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42), "Jelly Match configures with the current curriculum")
	view.set_process(false)
	view.game.step(0.45)
	view._sync_tiles()
	view._refresh_hud()
	view._layout()
	heard.clear()
	attempts.clear()
	cues.clear()
	finishes.clear()


func _pair(view, chest_only: bool = false) -> Array[int]:
	for a: Dictionary in view.game.cells:
		for b: Dictionary in view.game.cells:
			if a.id != b.id and a.word.id == b.word.id and a.kind != b.kind:
				if not chest_only or bool(a.chest) or bool(b.chest):
					return [int(a.id), int(b.id)]
	return []


func _center(view, id: int) -> Vector2:
	return view._tiles[id].get_global_rect().get_center()


func _check_layout(view) -> void:
	for dimensions: Vector2 in [Vector2(1366, 600), Vector2(390, 640), Vector2(340, 460), Vector2(844, 235), Vector2(1024, 370)]:
		view.size = dimensions
		view._layout()
		var board: Rect2 = view._board
		check(is_equal_approx(board.size.x / board.size.y, 2.0 / 3.0), "%s keeps a fixed four-column, six-row portrait board" % dimensions)
		check(Rect2(Vector2.ZERO, dimensions).encloses(board), "%s contains the board" % dimensions)
		check(not board.intersects(view.finish_button.get_rect()), "%s keeps Finish outside the board" % dimensions)
		check(not board.intersects(view._loot_icon.get_rect()), "%s keeps chest totals outside the board" % dimensions)
		for cell: Dictionary in view.game.cells:
			check(board.encloses(view._tiles[int(cell.id)].get_rect()), "%s keeps settled jelly %s inside its well" % [dimensions, cell.id])
	view.size = Vector2(1000, 720)
	view._layout()


func _check_pictures(view) -> void:
	for cell: Dictionary in view.game.cells:
		var tile = view._tiles[int(cell.id)]
		check(tile._surface.texture != null, "Every tile uses acquired gel artwork")
		check(tile._picture.visible == (str(cell.kind) == "picture"), "Picture tiles show the actual word image")
		check(tile._label.visible == (str(cell.kind) == "word"), "Word tiles show only the word")
		check(tile._picture.texture != null, "The pictured vocabulary asset loads")
		check(tile._badge.visible == bool(cell.chest), "Exactly the marked tile carries its chest")
		tile.deform(0.02, 0.5, Vector2(1.1, 0.9))
		check(tile._visual.scale == Vector2.ONE and tile._surface.scale != Vector2.ONE,
			"Soft gel deforms independently of the readable learning content")


func _check_pointer_ownership(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	check(view._press(4, _center(view, pair[0])), "The first finger owns a settled tile")
	check(heard.size() == 1 and heard[0].id == view._cell(pair[0]).word.id, "Touch-down immediately reads the selected vocabulary")
	check(not view._press(9, _center(view, pair[1])), "A second finger cannot steal the jelly")
	view.pause(false)
	check(int(view.snapshot().drag.pointer) == 4, "Repeated unpause refreshes leave the active drag untouched")
	view.release_pointer(9)
	await process_frame
	check(int(view.snapshot().drag.pointer) == 4, "An unrelated browser contact release is ignored")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.position = _center(view, pair[1])
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	view._input(emulated)
	check(int(view.snapshot().drag.pointer) == 4 and heard.size() == 1, "Touch-emulated mouse events cannot duplicate pronunciation or contact")
	view._release(_center(view, pair[0]))
	check(int(view.snapshot().drag.selected) == pair[0] and attempts.is_empty(), "A tap selects without inventing an attempt")
	view.cancel_input()


func _check_wrong_drop(view) -> void:
	_reset(view)
	var first: int = int(view.game.cells[0].id)
	var other: int = -1
	for cell: Dictionary in view.game.cells:
		if cell.word.id != view._cell(first).word.id:
			other = int(cell.id)
			break
	var before: Array = view.game.cells.duplicate(true)
	view._press(-1, _center(view, first))
	view._move(_center(view, other))
	view._release(_center(view, other))
	check(attempts.size() == 1 and not bool(attempts[0].correct), "A wrong drop emits one incorrect learning attempt")
	check(view.game.cells == before and view.game.fusion.is_empty(), "Wrong drops preserve board positions and tiles")
	check(view._snapbacks.has(first), "Wrong drops visibly return the held jelly to its slot")
	view._process(0.25)
	check(view._snapbacks.is_empty() and view._tiles[first].position == view._tile_rect(view._cell(first)).position,
		"Snapback settles into the original slot")


func _check_fusion(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view, true)
	var source_center: Vector2 = _center(view, pair[0])
	view._activate(pair[0])
	view._activate(pair[1])
	check(heard.size() == 2 and not view.game.fusion.is_empty(), "Tap or controller selection reads both tiles and starts the same fusion")
	check(attempts.is_empty() and view.game.chest_count == 0, "A matching contact does not credit a clear or treasure before fusion completes")
	check(view.finish_button.disabled and not view._can_play(), "Fusion blocks repeated contacts and early finish")
	view._process(0.10)
	check(view._tiles[pair[0]].visible and view._tiles[pair[1]].visible and not view._merged.visible,
		"Fusion begins with two separate droplets moving into contact")
	check(_center(view, pair[0]) != source_center, "The held droplet moves toward its matching partner")
	view._process(0.32)
	check(view._merged.visible and view._merged._picture.visible and view._merged._label.visible,
		"The merged jelly holds its picture and word together before popping")
	check(not view._tiles[pair[0]].visible and not view._tiles[pair[1]].visible,
		"The merged jelly replaces both source droplets once they unite")
	view._process(0.29)
	check(cues.count("pop") == 1 and attempts.is_empty(), "The visual pop shares the model's timed sound event before credit")
	view._process(0.34)
	check(attempts.size() == 1 and bool(attempts[0].correct) and view.game.chest_count == 1,
		"One completed fusion grants exactly one word credit and its marked chest")
	check(not view._tiles.has(pair[0]) and not view._tiles.has(pair[1]) and not view._merged.visible,
		"Cleared droplets disappear and the model supplies gravity")
	check(view._loot_flights.size() == 1, "A completed treasure fusion flies toward the visible chest total")
	view._release(source_center)
	check(attempts.size() == 1, "A stale release cannot repeat a completed merge")


func _check_pauses_and_new_round(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	view._press(2, _center(view, pair[0]))
	view._move(_center(view, pair[1]))
	view.pause(true)
	var elapsed: float = float(view.game.spawn_elapsed)
	view._process(0.3)
	view._release(_center(view, pair[1]))
	check(view.game.spawn_elapsed == elapsed and attempts.is_empty() and not view.snapshot().drag.active,
		"A menu pause cancels the drag and freezes time without answering")
	view.pause(false)
	view._press(2, _center(view, pair[0]))
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(int(view.snapshot().drag.pointer) == Jelly.NO_POINTER, "Window blur immediately gives up pointer ownership")
	view._press(2, _center(view, pair[0]))
	view.hide()
	view.show()
	check(int(view.snapshot().drag.pointer) == Jelly.NO_POINTER, "Leaving and restoring the mode cannot restore an old drag")
	view._press(2, _center(view, pair[0]))
	_reset(view)
	view._release(_center(view, _pair(view)[1]))
	check(attempts.is_empty(), "Reused tile IDs in a new round cannot inherit a held gesture")


func _check_deferred_release(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	view._press(-1, _center(view, pair[0]))
	view._move(_center(view, pair[1]))
	view.release_pointer(-1)
	view._release(_center(view, pair[1]))
	await process_frame
	check(not view.game.fusion.is_empty(), "Browser pointer-up defers to a valid native drop in the same frame")
	_reset(view)
	pair = _pair(view)
	view._press(3, _center(view, pair[0]))
	view._move(_center(view, pair[1]))
	view.release_pointer(3)
	await process_frame
	check(view.game.fusion.is_empty() and int(view.snapshot().drag.pointer) == Jelly.NO_POINTER,
		"A genuinely missing native release cancels instead of guessing a drop")


func _check_result_gate(view) -> void:
	_reset(view)
	var opened: Array[int] = []
	var replayed: Array[int] = []
	view.chests_requested.connect(func() -> void: opened.append(1))
	view.replay_requested.connect(func() -> void: replayed.append(1))
	var pair: Array[int] = _pair(view, true)
	view._activate(pair[0])
	view._activate(pair[1])
	for delta: float in [0.4, 0.4, 0.25]:
		view._process(delta)
	view.finish_button.pressed.emit()
	check(finishes.size() == 1 and view.game.phase == "finished", "Finish emits a settled result once")
	view._open_chests()
	view._replay()
	check(opened.is_empty() and replayed.is_empty() and not view._result.visible,
		"Result actions stay hidden and inert while the shared celebration runs")
	view.result_reveal()
	check(view._result.visible and view.chests_button.visible and view.replay_button.visible,
		"The root explicitly reveals the complete result after celebration")
	for dimensions: Vector2 in [Vector2(390, 640), Vector2(844, 235), Vector2(320, 260)]:
		view.size = dimensions
		view._layout()
		check(Rect2(Vector2.ZERO, dimensions).encloses(view.chests_button.get_rect()), "Result actions fit %s" % dimensions)
		check(not view.chests_button.get_rect().intersects(view.replay_button.get_rect()), "Result actions never overlap at %s" % dimensions)
		for image: TextureRect in view._result_chests:
			if image.visible:
				check(not image.get_rect().intersects(view.chests_button.get_rect()), "Result treasure and actions stay separate at %s" % dimensions)
	view._open_chests()
	view._open_chests()
	view._replay()
	check(opened.size() == 1 and replayed.is_empty(), "Repeated result activation produces a single transition")
	_reset(view)
	view.finish_button.pressed.emit()
	view.result_reveal()
	check(not view.chests_button.visible and view.replay_button.visible, "A zero-chest round offers replay without a false opening action")
	view.size = Vector2(1000, 720)


func _check_reduced_motion_and_cache(view) -> void:
	_reset(view, true)
	var pair: Array[int] = _pair(view, true)
	view._activate(pair[0])
	view._activate(pair[1])
	view._process(0.2)
	var static_rect: Rect2 = view._merged.get_rect()
	view._process(0.3)
	check(view._merged.get_rect().is_equal_approx(static_rect) and view._merged._surface.scale == Vector2.ONE,
		"Reduced motion shows a stationary combined picture and word: %s -> %s, scale %s" % [static_rect, view._merged.get_rect(), view._merged._surface.scale])
	for delta: float in [0.3, 0.25]:
		view._process(delta)
	check(view._loot_flights.is_empty() and view.game.chest_count == 1,
		"Reduced motion removes flight while preserving the actual reward")
	var texture: Texture2D = view._chest_texture
	view.apply_theme(Data.theme("spring"), data.chests)
	check(view._chest_texture == texture, "Repeated theme refreshes share one live-rendered chest texture")
	for index in range(7):
		view._process(0.01)
	var cache: Dictionary = view._chest_cache["spring"]
	check(cache.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not cache.art.is_processing(),
		"Static theme chest previews stop rendering once their source pose is cached")
	view.stop()
	check(view._tiles.is_empty() and not view._merged.visible and not view.finish_button.visible
		and not view._loot_icon.visible and not view._pace.visible,
		"Stopping a view releases all gameplay presentation without finishing a round")


func _check_publication_budget(view) -> void:
	_reset(view)
	var publications: Array[int] = []
	view.changed.connect(func(_state: Dictionary) -> void: publications.append(1))
	for index in range(60):
		view._process(1.0 / 60.0)
	check(publications.size() >= 8 and publications.size() <= 11,
		"Animated snapshots are published around ten times a second, not every render frame")


func _check_close_drop_contact(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	var target: Vector2 = _center(view, pair[1])
	view._press(-1, _center(view, pair[0]))
	view._move(target)
	view._release(target)
	view._process(0.01)
	check(not view.game.fusion.is_empty() and _center(view, pair[0]).distance_to(target) < view._pitch * 0.05,
		"A center-to-center drop begins at its actual dropped position")
	view._process(0.10)
	check(_center(view, pair[0]).distance_to(_center(view, pair[1])) > view._pitch * 0.25,
		"Close drops express two elastic contact lobes before uniting")
	check(attempts.is_empty() and view._tiles[pair[0]].visible and view._tiles[pair[1]].visible,
		"The close-drop contact is presentation only and earns nothing early")


func _check_signal_reentry(view) -> void:
	_reset(view)
	var interrupt: Callable = func(cue: String) -> void:
		if cue == "merge":
			view.game.finish_round()
	view.audio_requested.connect(interrupt)
	var pair: Array[int] = _pair(view)
	view._activate(pair[0])
	view._activate(pair[1])
	check(view.game.phase == "finished" and view.game.fusion.is_empty() and attempts.is_empty(),
		"A synchronous finish callback may cancel a just-started fusion without stale payload access or credit")
	view.audio_requested.disconnect(interrupt)
	_reset(view)
	var leave_on_word: Callable = func(_word: Dictionary) -> void: view.stop()
	view.word_requested.connect(leave_on_word)
	view._activate(_pair(view)[0])
	check(not view._configured and int(view.snapshot().drag.selected) == -1,
		"Leaving from a synchronous pronunciation callback cannot restore a stale selection")
	view.word_requested.disconnect(leave_on_word)

extends SceneTree

const Jelly = preload("res://scripts/jelly_match.gd")
const Data = preload("res://scripts/game_data.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
const Style = preload("res://scripts/ui_style.gd")

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
	_check_opening(view)
	_reset(view)
	_check_layout(view)
	_check_pictures(view)
	_check_supply_preview(view)
	_check_manual_preview_drop(view)
	_check_preview_cancel_and_rollover(view)
	_check_preview_lifecycle_gates(view)
	_check_preview_controller(view)
	_check_preview_motion(view)
	_check_drop_projection(view)
	_check_landing_presentation(view)
	_check_landing_audio_groups(view)
	_check_landing_lifecycle(view)
	_check_gesture_audio(view)
	_check_consecutive_taps(view)
	_check_drag_threshold(view)
	await _check_pointer_ownership(view)
	_check_pointer_feedback(view)
	_check_drag_after_tap(view)
	_check_contact_validity(view)
	_check_same_kind_contact(view)
	_check_contact_lifecycle(view)
	_check_rejection_lifecycle(view)
	_check_keyboard_feedback(view)
	_check_feedback_lifecycle(view)
	_check_danger_clock(view)
	_check_danger_lifecycle(view)
	_check_danger_reduced_motion_and_end(view)
	_check_wrong_drop(view)
	_check_fusion(view)
	_check_concurrent_fusions(view)
	_check_drag_across_fusion_completion(view)
	_check_concurrent_fusion_lifecycle(view)
	_check_fusion_interruption(view)
	_check_close_drop_contact(view)
	_check_off_center_drop_continuity(view)
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


func _reset(view, reduced: bool = false, settled: bool = true) -> void:
	check(view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42), "Jelly Match configures with the current curriculum")
	view.set_process(false)
	# These presentation fixtures observe a batch released by the player.
	view.game.drop_now()
	if settled:
		view.game.step(view.game.SETTLE_SECONDS)
	view._sync_tiles()
	view._refresh_hud()
	view._layout()
	heard.clear()
	attempts.clear()
	cues.clear()
	finishes.clear()


func _check_opening(view) -> void:
	for reduced in [false, true]:
		check(view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42), "A new round configures without a forced opening drop")
		view.set_process(false)
		check(view.game.cells.size() == 6 and _arrivals(view).is_empty() and view._ghosts.is_empty(),
			"The opening shows only settled starters without falling bodies or landing projections")
		check(view.snapshot().preview.slots.size() == 4 and not view.drop_button.disabled,
			"All four upcoming tiles remain available for an optional immediate release")
		_advance(view, 2.0)
		view.pause(true)
		_advance(view, 10.0)
		check(view.game.cells.size() == 6 and is_equal_approx(view.game.spawn_elapsed, 2.0),
			"Pausing the opening preserves the remaining reading time")
		view.pause(false)
		_advance(view, 7.99)
		check(view.game.cells.size() == 6 and _arrivals(view).is_empty(),
			"The opening has no automatic arrivals before the complete ten seconds")
		_advance(view, 0.02)
		check(_arrivals(view).size() == 4 and view.game.cells.size() == 10,
			"The first automatic batch uses the normal visible four-tile descent")


func _pair(view, chest_only: bool = false) -> Array[int]:
	for a: Dictionary in view.game.cells:
		for b: Dictionary in view.game.cells:
			if a.id != b.id and a.word.id == b.word.id and a.kind != b.kind:
				if not chest_only or bool(a.chest) or bool(b.chest):
					return [int(a.id), int(b.id)]
	return []


func _center(view, id: int) -> Vector2:
	return view._tiles[id].get_global_rect().get_center()


func _effect(view) -> Dictionary:
	return view._fusion_visuals.values()[0] if not view._fusion_visuals.is_empty() else {}


func _available_pairs(view) -> Array[Array]:
	var pairs: Array[Array] = []
	var used: Array[int] = []
	for a: Dictionary in view.game.cells:
		if int(a.id) in used or not view._settled(a):
			continue
		for b: Dictionary in view.game.cells:
			if a.id != b.id and int(b.id) not in used and view._settled(b) and a.word.id == b.word.id and a.kind != b.kind:
				pairs.append([int(a.id), int(b.id)])
				used.append(int(a.id))
				used.append(int(b.id))
				break
	return pairs


func _drag_pair(view, source: int, target: int) -> void:
	var destination: Vector2 = _center(view, target)
	view._press(-1, _center(view, source))
	view._move(destination)
	view._release(destination)


func _advance(view, seconds: float, frame_step: float = 0.1) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var delta: float = minf(frame_step, remaining)
		view._process(delta)
		remaining -= delta


func _arrival(view) -> Dictionary:
	var incoming: Array[Dictionary] = _arrivals(view)
	return incoming[0] if not incoming.is_empty() else {}


func _arrivals(view) -> Array[Dictionary]:
	var incoming: Array[Dictionary] = []
	for cell: Dictionary in view.game.cells:
		if bool(cell.get("arrival", false)) and not view._settled(cell):
			incoming.append(cell)
	incoming.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Motion.contact_at(a) < Motion.contact_at(b))
	return incoming


func _ghost(view, id: int) -> Dictionary:
	for projection: Dictionary in view.snapshot().landing_ghosts:
		if int(projection.id) == id:
			return projection
	return {}


func _landing_groups(incoming: Array[Dictionary]) -> int:
	var count: int = 0
	var previous: float = -1.0
	for cell: Dictionary in incoming:
		var contact: float = Motion.contact_at(cell)
		if previous < 0.0 or contact - previous > 0.12:
			count += 1
			previous = contact
	return count


func _rect(values: Array) -> Rect2:
	return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))


func _check_layout(view) -> void:
	for dimensions: Vector2 in [Vector2(1366, 600), Vector2(390, 640), Vector2(340, 460), Vector2(320, 260), Vector2(844, 235), Vector2(1024, 370)]:
		view.size = dimensions
		view._layout()
		var board: Rect2 = view._board
		check(is_equal_approx(board.size.x / board.size.y, 2.0 / 3.0), "%s keeps a fixed four-column, six-row portrait board" % dimensions)
		check(Rect2(Vector2.ZERO, dimensions).encloses(board), "%s contains the board" % dimensions)
		check(not board.intersects(view.finish_button.get_rect()), "%s keeps Finish outside the board" % dimensions)
		check(not board.intersects(view._loot_icon.get_rect()), "%s keeps chest totals outside the board" % dimensions)
		var preview: Dictionary = view.snapshot().preview
		var preview_rect: Rect2 = _rect(preview.rect)
		check(bool(preview.visible) and preview.slots.size() == 4
			and view.get_global_rect().encloses(preview_rect) and not view._global_rect(board).intersects(preview_rect),
			"%s contains all four upcoming tiles in a separate area outside the fixed board" % dimensions)
		check(not preview_rect.intersects(view.finish_button.get_global_rect())
			and not preview_rect.intersects(view._loot_icon.get_global_rect()),
			"%s keeps the supply preview separate from finish and treasure controls" % dimensions)
		for slot: Dictionary in preview.slots:
			check(bool(slot.visible) and preview_rect.encloses(_rect(slot.rect)),
				"%s keeps preview tile %s fully inside its supply area" % [dimensions, slot.id])
		for index in range(view._preview_tiles.size()):
			var tile = view._preview_tiles[index]
			var anchored_rect := Rect2(view._preview_origins[index], tile.size)
			check(tile.position.is_equal_approx(view._preview_origins[index])
				and preview_rect.encloses(view._global_rect(anchored_rect)),
				"%s keeps preview %d planted inside its supply region" % [dimensions, index + 1])
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


func _check_supply_preview(view) -> void:
	_reset(view, false, false)
	var before: Dictionary = view.snapshot()
	var supply: Array = before.upcoming.duplicate(true)
	check(supply.size() == 4 and before.preview.slots.size() == 4,
		"The view reveals all four committed tiles in the next batch")
	check(view.find_children("*", "ProgressBar", true, false).is_empty(),
		"The supply area has no competing progress bar")
	for label: Label in view.find_children("*", "Label", true, false):
		check(str(label.text) != "Next", "The four preview tiles communicate supply without a Next label")
	for index in range(supply.size()):
		var slot: Dictionary = before.preview.slots[index]
		var preview = view._preview_tiles[index]
		check(int(slot.id) == int(supply[index].id) and bool(slot.visible),
			"Preview slot %d shows the corresponding model supply identity" % (index + 1))
		check(preview.word == supply[index].word and preview.kind == supply[index].kind
			and preview._surface.texture != null and preview._picture.texture != null
			and preview._picture.visible == (str(supply[index].kind) == "picture")
			and preview._label.visible == (str(supply[index].kind) == "word")
			and preview._badge.visible == bool(supply[index].chest),
			"Preview slot %d retains the queued learning artwork, word kind and treasure marker" % (index + 1))
		check(preview.disabled and preview.focus_mode == Control.FOCUS_NONE and preview.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Upcoming artwork %d stays decorative inside its shared release control" % (index + 1))
		check(not view._press(4, _rect(slot.rect).get_center()), "An airborne wave keeps preview presses disabled")
		view._activate(int(slot.id))
	check(heard.is_empty() and cues.is_empty() and attempts.is_empty() and int(view.snapshot().drag.selected) == -1,
		"Disabled preview interaction cannot pronounce, select, answer, or release another wave")
	for control: Control in view.navigation_controls():
		check(not control.get_global_rect().intersects(_rect(before.preview.rect)),
			"Keyboard navigation excludes the preview while an existing wave is airborne")
	view._layout()
	view.apply_theme(Data.theme("spring"), data.chests)
	view._refresh_hud()
	check(view.snapshot().upcoming == supply, "Theme, HUD and layout refreshes cannot reroll the advertised supply")
	var count: int = view.game.cells.size()
	_advance(view, view.game.spawn_interval - view.game.spawn_elapsed + 0.00001)
	var next: Dictionary = view.snapshot()
	check(view.game.cells.size() == count + 4 and int(next.generated_tiles) == int(before.generated_tiles) + 4,
		"One supply beat dispatches the complete advertised batch of four")
	var columns: Array[int] = []
	for index in range(supply.size()):
		var arrived: Dictionary = view._cell(int(supply[index].id))
		check(not arrived.is_empty() and arrived.word == supply[index].word and arrived.kind == supply[index].kind
			and arrived.chest == supply[index].chest and not view._settled(arrived),
			"Advertised tile %d arrives with its exact identity, learning content and chest marker" % (index + 1))
		if not arrived.is_empty():
			columns.append(int(arrived.column))
		check(int(next.preview.slots[index].id) == int(next.upcoming[index].id)
			and not supply.any(func(item: Dictionary) -> bool: return int(item.id) == int(next.preview.slots[index].id)),
			"Preview slot %d advances to a newly committed tile after its batch leaves" % (index + 1))
	check(columns.size() == 4 and columns.has(0) and columns.has(1) and columns.has(2) and columns.has(3),
		"A batch uses all four available columns instead of stacking its arrivals")
	var queued: Array = next.upcoming.duplicate(true)
	var cells: Array = next.cells.duplicate(true)
	view.pause(true)
	_advance(view, view.game.spawn_interval + Motion.MAX_SETTLE_SECONDS)
	check(view.snapshot().upcoming == queued and view.snapshot().cells == cells,
		"Pausing freezes all airborne tiles and the next-four supply")
	view.pause(false)
	view.hide()
	_advance(view, view.game.spawn_interval + Motion.MAX_SETTLE_SECONDS)
	view.show()
	check(view.snapshot().upcoming == queued and view.snapshot().cells == cells,
		"Hiding and returning cannot consume supply or complete an unseen fall")
	_reset(view)
	check(view.snapshot().upcoming == supply and view.game.cells.size() == count,
		"A seeded replacement round restores its own committed supply without the old arrival")
	view.game.finish_round()
	view.result_reveal()
	check(not bool(view.snapshot().preview.visible) and view.snapshot().landing_ghosts.is_empty(),
		"Results hide the supply preview and all landing guidance")
	view.stop()
	check(not bool(view.snapshot().preview.visible) and view.snapshot().landing_ghosts.is_empty(),
		"Stopping the mode leaves no visible supply or ghost")
	_reset(view)


func _check_manual_preview_drop(view) -> void:
	for pointer: int in [-1, 4]:
		_reset(view)
		var state: Dictionary = view.snapshot()
		var preview_rect: Rect2 = _rect(state.preview.rect)
		var point: Vector2 = preview_rect.get_center() if pointer == -1 else preview_rect.position + Vector2(4.0, 4.0)
		var advertised: Array = state.upcoming.duplicate(true)
		var count: int = view.game.cells.size()
		check(bool(state.preview.enabled) and not view.drop_button.disabled
			and view.drop_button.focus_mode == Control.FOCUS_ALL and view.navigation_controls().has(view.drop_button)
			and _rect(state.preview.control.rect).is_equal_approx(preview_rect),
			"A settled board exposes the whole supply area as one accessible release control")
		check(view._press(pointer, point) and view.game.cells.size() == count
			and view.game.upcoming == advertised and heard.is_empty() and cues.is_empty()
			and not view.snapshot().drag.active,
			"Pressing a preview tile or its surrounding padding waits for release without starting a board drag")
		_advance(view, 0.5)
		check(view.game.cells.size() == count and view.game.upcoming == advertised and cues.is_empty(),
			"Holding the preview does not repeatedly dispatch supply or play feedback")
		view.drop_button.pressed.emit()
		check(view.game.cells.size() == count and cues.is_empty(),
			"Controller activation cannot steal a held preview gesture")
		var before_release: Array = view.game.cells.duplicate(true)
		var release: Vector2 = point + Vector2(5.0, 0.0)
		view._move(release)
		view._release(release)
		check(view.game.cells.size() == count + 4 and view.game.cells.slice(0, count) == before_release
			and view.game.spawn_elapsed == 0.0 and cues == ["pick"]
			and heard.is_empty() and attempts.is_empty() and view.game.chest_count == 0,
			"A valid preview release dispatches one exact batch with one tactile cue and no learning or time skip")
		for index in range(advertised.size()):
			var arrival: Dictionary = view._cell(int(advertised[index].id))
			check(not arrival.is_empty() and arrival.word == advertised[index].word
				and arrival.kind == advertised[index].kind and arrival.chest == advertised[index].chest
				and arrival.age == 0.0 and not view._settled(arrival)
				and view._tiles.has(int(arrival.id)) and not _ghost(view, int(arrival.id)).is_empty(),
				"A manually released jelly immediately renders its advertised content, normal descent, and landing shadow")
		check(not bool(view.snapshot().preview.enabled) and view.drop_button.disabled
			and not view.navigation_controls().has(view.drop_button)
			and int(view.snapshot().drag.pointer) == Jelly.NO_POINTER,
			"The released wave returns pointer ownership and temporarily disables another release")
		var dispatched: Dictionary = view.game.snapshot()
		view._release(release)
		view.drop_button.pressed.emit()
		check(view.game.snapshot() == dispatched and cues == ["pick"],
			"Repeated release or controller events cannot stack another falling wave")
	_reset(view)


func _check_preview_cancel_and_rollover(view) -> void:
	for action: String in ["outside", "motion", "cancel", "pause", "hide", "blur", "new-round", "stop"]:
		_reset(view)
		var preview_rect: Rect2 = _rect(view.snapshot().preview.rect)
		var point: Vector2 = preview_rect.get_center()
		check(view._press(4, point), "The preview accepts a fresh gesture before %s" % action)
		match action:
			"outside":
				view._move(preview_rect.end + Vector2(10.0, 10.0))
				view._move(point)
			"motion":
				view._move(point + Vector2(20.0 / Style.ui_scale(view), 0.0))
				view._move(point)
			"cancel":
				view.cancel_input()
			"pause":
				view.pause(true)
				view.pause(false)
			"hide":
				view.hide()
				view.show()
			"blur":
				view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"new-round":
				_reset(view)
			"stop":
				view.stop()
		var stopped: Dictionary = view.game.snapshot()
		var before_cues: Array[String] = cues.duplicate()
		view._release(point)
		check(view.game.snapshot() == stopped and cues == before_cues
			and int(view.snapshot().drag.pointer) == Jelly.NO_POINTER,
			"%s prevents the old preview release from consuming a batch or playing feedback" % action)
	_reset(view)
	_advance(view, view.game.spawn_interval - view.game.spawn_elapsed - 0.02)
	var point: Vector2 = _rect(view.snapshot().preview.rect).get_center()
	var old_preview: Array = view.game.upcoming.duplicate(true)
	var count: int = view.game.generated_tiles
	check(view._press(-1, point), "A preview press just before the natural beat retains its current batch identity")
	_advance(view, 0.03 + view.game.SETTLE_SECONDS)
	check(view.game.generated_tiles == count + 4 and view.game.upcoming != old_preview,
		"The normal supply beat can pass while the preview pointer remains held")
	var after_beat: Dictionary = view.game.snapshot()
	view._release(point)
	check(view.game.snapshot() == after_beat and cues.count("pick") == 0,
		"Releasing a stale preview press never dispatches the replacement batch after its predecessor lands")
	_reset(view)


func _check_preview_lifecycle_gates(view) -> void:
	for state: String in ["airborne", "paused", "hidden", "fusion", "disappearance", "full", "results", "stopped", "drag"]:
		_reset(view, false, state != "airborne")
		var point: Vector2 = _rect(view.snapshot().preview.rect).get_center()
		match state:
			"paused":
				view.pause(true)
			"hidden":
				view.hide()
			"fusion", "disappearance":
				var pair: Array[int] = _pair(view)
				_drag_pair(view, pair[0], pair[1])
				if state == "disappearance":
					_advance(view, 0.8)
			"full":
				view.game.step(4.0 * view.game.spawn_interval)
				view._sync_tiles()
				view._refresh_hud()
				check(view.game.cells.size() == view.game.CAPACITY and view.game.phase == "playing",
					"The manual-release guard is exercised on a live full board")
			"results":
				view.game.finish_round()
				view.result_reveal()
			"stopped":
				view.stop()
			"drag":
				var source: Vector2 = _center(view, int(view.game.cells[0].id))
				view._press(4, source)
				view._move(source + Vector2(20.0, 0.0))
		var before: Dictionary = view.game.snapshot()
		var before_cues: Array[String] = cues.duplicate()
		check(not view._press(8, point), "%s blocks a new preview gesture" % state)
		view.drop_button.pressed.emit()
		check(view.game.snapshot() == before and cues == before_cues,
			"%s cannot bypass release eligibility by directly emitting the controller action" % state)
		view.cancel_input()
		view.show()
	_reset(view)


func _check_preview_controller(view) -> void:
	_reset(view)
	var advertised: Array = view.game.upcoming.duplicate(true)
	var count: int = view.game.generated_tiles
	check(view.navigation_controls().has(view.drop_button), "A ready supply area is reachable by keyboard and controller")
	view.drop_button.grab_focus()
	view.drop_button.pressed.emit()
	check(view.game.generated_tiles == count + 4 and cues == ["pick"] and heard.is_empty() and attempts.is_empty(),
		"Controller activation releases one complete batch without pronouncing preview content")
	for tile: Dictionary in advertised:
		check(not view._cell(int(tile.id)).is_empty(), "Controller release uses the same committed preview as pointer release")
	for index in range(8):
		view.drop_button.pressed.emit()
	check(view.game.generated_tiles == count + 4 and cues == ["pick"],
		"Repeated controller signals cannot bypass the airborne-wave gate or duplicate its cue")
	_reset(view)


func _preview_window(interval: float, start: float, finish: float) -> Dictionary:
	var energy: float = 0.0
	var samples: int = 0
	for index in range(4):
		for sample_index in range(81):
			var progress: float = lerpf(start, finish, float(sample_index) / 80.0)
			var pose: Dictionary = Motion.preview(progress * interval, interval, index)
			energy += float(pose.pressure) * float(pose.pressure) + float(pose.sway) * float(pose.sway)
			samples += 1
	var first: Dictionary = Motion.preview(start * interval, interval, 0)
	var last: Dictionary = Motion.preview(finish * interval, interval, 0)
	return {"amplitude": sqrt(energy / samples), "speed": (float(last.beat) - float(first.beat)) / ((finish - start) * interval)}


func _check_preview_pose(view, reason: String) -> void:
	var slots: Array = view.snapshot().preview.slots
	var still: bool = view.reduced_motion or view.game.phase != "playing" or view.game.cells.size() >= view.game.CAPACITY
	for index in range(view._preview_tiles.size()):
		var tile = view._preview_tiles[index]
		var pose: Dictionary = Motion.preview(view.game.spawn_elapsed, view.game.spawn_interval, index, still)
		check(tile.position.is_equal_approx(view._preview_origins[index]) and tile._surface.scale == Vector2.ONE
			and is_zero_approx(float(tile._gel.get_shader_parameter("bend")))
			and is_equal_approx(float(tile._gel.get_shader_parameter("preview_pressure")), float(pose.pressure))
			and is_equal_approx(float(tile._gel.get_shader_parameter("preview_sway")), float(pose.sway)),
			"%s applies preview %d's model-clock strain to its skin without moving or scaling its root" % [reason, index + 1])
		check(tile._visual.scale == Vector2.ONE and tile._picture.scale == Vector2.ONE and tile._label.scale == Vector2.ONE
			and is_zero_approx(tile._visual.rotation) and is_zero_approx(tile._picture.rotation) and is_zero_approx(tile._label.rotation),
			"%s keeps preview %d learning content free of pressure deformation" % [reason, index + 1])
		check(tile._shadow.visible and tile._shadow.modulate.a > 0.0
			and is_equal_approx(tile._shadow.position.x + tile._shadow.size.x * 0.5, tile.size.x * 0.5)
			and is_equal_approx(tile._shadow.position.y + tile._shadow.size.y * 0.6, tile.size.y * Motion.FOOT_Y),
			"%s keeps preview %d's contact shadow anchored to its painted foot" % [reason, index + 1])
		var shadow_layer: int = tile.z_index + tile._shadow.z_index
		check(tile.z_as_relative and tile._shadow.z_as_relative and tile._visual.z_as_relative
			and tile.get_parent() == view.drop_button.get_parent()
			and (shadow_layer > view.drop_button.z_index
				or (shadow_layer == view.drop_button.z_index and tile.get_index() > view.drop_button.get_index()))
			and tile._shadow.z_index < tile._visual.z_index,
			"%s paints preview %d's support shadow above the supply panel and below its gel skin" % [reason, index + 1])
		check(slots[index].has("motion") and slots[index].motion == pose
			and _rect(slots[index].rect).is_equal_approx(tile.get_global_rect()),
			"%s publishes preview %d's actual pressure and fixed hit rectangle" % [reason, index + 1])


func _preview_content_transforms(view) -> Array:
	var transforms: Array = []
	for tile in view._preview_tiles:
		transforms.append([tile.get_transform(), tile._surface.get_transform(), tile._visual.get_transform(),
			tile._picture.get_transform(), tile._label.get_transform(), tile._badge.get_transform()])
	return transforms


func _check_preview_motion(view) -> void:
	for interval: float in [view.game.INITIAL_SPAWN_INTERVAL, view.game.MIN_SPAWN_INTERVAL]:
		var early: Dictionary = _preview_window(interval, 0.05, 0.20)
		var middle: Dictionary = _preview_window(interval, 0.40, 0.55)
		var late: Dictionary = _preview_window(interval, 0.84, 0.99)
		check(float(early.amplitude) > 0.0 and float(middle.amplitude) > float(early.amplitude)
			and float(late.amplitude) > float(middle.amplitude),
			"The %.2f-second supply cycle builds material pressure from early through middle to late release" % interval)
		check(float(middle.speed) > float(early.speed) and float(late.speed) > float(middle.speed),
			"The %.2f-second supply cycle brings pressure pulses closer together as dispatch approaches" % interval)
		var previous_intensity: float = 0.0
		var different_slots: bool = false
		for step in range(101):
			var elapsed: float = interval * float(step) / 100.0
			var pose: Dictionary = Motion.preview(elapsed, interval, 0)
			check(float(pose.intensity) >= previous_intensity and float(pose.intensity) <= 1.0
				and float(pose.pressure) >= -0.021 and float(pose.pressure) <= 0.066 and absf(float(pose.sway)) <= 0.0121
				and not pose.has("offset") and not pose.has("stretch") and not pose.has("bend"),
				"Preview urgency grows inside a small strain envelope without affine motion at %d percent" % step)
			previous_intensity = float(pose.intensity)
			var still: Dictionary = Motion.preview(elapsed, interval, step % 4, true)
			check(is_zero_approx(float(still.pressure)) and is_zero_approx(float(still.sway))
				and is_zero_approx(float(still.beat)) and is_zero_approx(float(still.intensity)),
				"Reduced motion has a neutral preview pose throughout the supply beat")
			for index in range(1, 4):
				var other: Dictionary = Motion.preview(elapsed, interval, index)
				different_slots = different_slots or not is_equal_approx(float(other.pressure), float(pose.pressure))
		check(different_slots, "The four queued skins have staggered pressure impulses instead of moving as a rigid group")
		for index in range(4):
			var reset: Dictionary = Motion.preview(0.0, interval, index)
			check(is_zero_approx(float(reset.pressure)) and is_zero_approx(float(reset.sway)),
				"A newly queued skin starts exactly at rest rather than inheriting the previous beat")
			var previous: Dictionary = reset
			var maximum_rate: Vector2 = Vector2.ZERO
			var minimum_pressure: float = 0.0
			var maximum_pressure: float = 0.0
			for sample_index in range(1, 2001):
				var current: Dictionary = Motion.preview(interval * float(sample_index) / 2000.0, interval, index)
				var rate := Vector2(absf(float(current.pressure) - float(previous.pressure)), absf(float(current.sway) - float(previous.sway))) / (interval / 2000.0)
				maximum_rate = maximum_rate.max(rate)
				minimum_pressure = minf(minimum_pressure, float(current.pressure))
				maximum_pressure = maxf(maximum_pressure, float(current.pressure))
				previous = current
			check(minimum_pressure < 0.0 and maximum_pressure > 0.0 and maximum_rate.x < 5.0 and maximum_rate.y < 1.0,
				"Preview %d compresses and elastically recovers through continuous bounded pressure without a phase-boundary snap" % (index + 1))
	_reset(view, false, false)
	var first: Array = view.snapshot().preview.slots.duplicate(true)
	var content: Array = _preview_content_transforms(view)
	_check_preview_pose(view, "A fresh batch")
	for progress: float in [0.25, 0.5, 0.75, 0.9]:
		_advance(view, view.game.spawn_interval * progress - view.game.spawn_elapsed)
		_check_preview_pose(view, "The %.0f percent supply beat" % (progress * 100))
		check(_preview_content_transforms(view) == content,
			"Pressure changes the gel material while every queued root, word, picture, and chest marker stays anchored")
	var late_slots: Array = view.snapshot().preview.slots.duplicate(true)
	check(late_slots != first and int(late_slots[0].id) == int(first[0].id),
		"Approaching release animates the existing queued tiles without replacing them")
	view.pause(true)
	_advance(view, 0.5)
	check(view.snapshot().preview.slots == late_slots, "Menu pause freezes all four preview poses and identities")
	view.pause(false)
	view.hide()
	_advance(view, 0.5)
	view.show()
	check(view.snapshot().preview.slots == late_slots, "A hidden board cannot continue pressure pulses or advance its preview clock")
	var pair: Array[int] = _pair(view)
	_drag_pair(view, pair[0], pair[1])
	_advance(view, 0.4)
	check(not view.game.fusion.is_empty() and view.snapshot().preview.slots == late_slots,
		"Fusion freezes the pending batch's pressure strain with its supply clock")
	_advance(view, view.game.FUSION_SECONDS - 0.4 + 0.00001)
	_advance(view, view.game.spawn_interval - view.game.spawn_elapsed + 0.00001)
	_check_preview_pose(view, "The following dispatched batch")
	var dispatched: Array = view.snapshot().preview.slots
	check(int(dispatched[0].id) != int(first[0].id) and float(dispatched[0].motion.intensity) < 0.121,
		"Dispatch resets the replacement preview to gentle motion instead of inheriting urgency")
	_reset(view, false, false)
	var reset_slots: Array = view.snapshot().preview.slots
	check(reset_slots.size() == first.size(), "A replacement round restores the complete preview batch")
	for index in range(mini(reset_slots.size(), first.size())):
		var reset_rect: Rect2 = _rect(reset_slots[index].rect)
		var first_rect: Rect2 = _rect(first[index].rect)
		check(reset_slots[index].id == first[index].id and reset_slots[index].visible == first[index].visible
			and reset_slots[index].motion == first[index].motion
			and reset_rect.position.distance_to(first_rect.position) < 0.001 and reset_rect.size.is_equal_approx(first_rect.size),
			"A replacement round resets preview %d position, deformation and supply identity" % (index + 1))
	_advance(view, view.game.spawn_interval * 0.9)
	view.set_reduced_motion(true)
	_check_preview_pose(view, "Enabling reduced motion")
	var static_slots: Array = view.snapshot().preview.slots.duplicate(true)
	_advance(view, 0.2)
	check(view.snapshot().preview.slots == static_slots, "Reduced motion advances supply time without moving its preview")
	view.set_reduced_motion(false)
	_check_preview_pose(view, "Restoring motion")
	_fill_board(view)
	_check_preview_pose(view, "A full board")
	var full_slots: Array = view.snapshot().preview.slots.duplicate(true)
	_advance(view, 0.2)
	check(view.snapshot().preview.slots == full_slots, "Full-board danger cannot keep pulsing a batch that cannot fall")
	view.stop()
	check(not bool(view.snapshot().preview.visible), "Stopping removes the pressure-pulse supply presentation")
	for tile in view._preview_tiles:
		check(not tile.visible, "No preview tile continues rendering after stop")
	_reset(view)


func _check_drop_projection(view) -> void:
	_reset(view, false, false)
	var incoming: Array[Dictionary] = _arrivals(view)
	check(incoming.size() == 4 and view.snapshot().landing_ghosts.size() == 4 and view._ghosts.size() == 4,
		"Four simultaneous arrivals each receive their own destination projection")
	if incoming.size() != 4:
		return
	var previous: Dictionary = {}
	for cell: Dictionary in incoming:
		var tile = view._tiles[int(cell.id)]
		var target: Rect2 = view._global_rect(view._tile_rect(cell))
		var ghost: Dictionary = _ghost(view, int(cell.id))
		check(not ghost.is_empty() and bool(ghost.visible) and _rect(ghost.rect).is_equal_approx(target),
			"Arrival %s has a fixed projection in its exact destination cell" % cell.id)
		var projection = view._ghosts[int(cell.id)]
		check(projection.disabled and projection.focus_mode == Control.FOCUS_NONE
			and projection.mouse_filter == Control.MOUSE_FILTER_IGNORE and projection._surface.texture == tile._surface.texture
			and not projection._picture.visible and not projection._label.visible and not projection._badge.visible,
			"Each landing silhouette reuses its gel contour without duplicating content or accepting input")
		check(tile.get_parent() != view and tile.get_parent().clip_contents,
			"Every airborne tile is clipped by the well instead of crossing its supply preview")
		check(not view._press(4, target.get_center()), "A projected destination is not a second playable tile")
		previous[int(cell.id)] = tile.get_global_rect()
	for fraction: float in [0.25, 0.50, 0.75]:
		_advance(view, Motion.contact_at(incoming[0]) * fraction - float(incoming[0].age))
		for cell: Dictionary in incoming:
			var tile = view._tiles[int(cell.id)]
			var target: Rect2 = view._global_rect(view._tile_rect(cell))
			var current: Rect2 = tile.get_global_rect()
			var ghost: Dictionary = _ghost(view, int(cell.id))
			check(current.position.y > Rect2(previous[int(cell.id)]).position.y and current.position.y < target.position.y
				and is_equal_approx(current.position.x, target.position.x),
				"Arrival %s visibly descends in its own column at %d percent of first contact" % [cell.id, roundi(fraction * 100)])
			check(not ghost.is_empty() and bool(ghost.visible) and _rect(ghost.rect).is_equal_approx(target),
				"Every destination remains fixed while its own body descends")
			check(tile.disabled and not view.navigation_controls().has(tile), "An airborne tile cannot be selected by touch or keyboard")
			previous[int(cell.id)] = current
	_advance(view, Motion.contact_at(incoming[0]) - float(incoming[0].age) + 0.001)
	var expected_ghosts: int = 0
	for cell: Dictionary in incoming:
		var contacted: bool = float(cell.age) >= Motion.contact_at(cell)
		check(_ghost(view, int(cell.id)).is_empty() == contacted,
			"Only the arriving body's own contact retires its projection")
		if contacted:
			check(view._tiles[int(cell.id)].get_global_rect().is_equal_approx(view._global_rect(view._tile_rect(cell))),
				"Contact replaces its silhouette with the real body at the same destination")
		else:
			expected_ghosts += 1
	check(expected_ghosts > 0 and expected_ghosts < 4 and view.snapshot().landing_ghosts.size() == expected_ghosts,
		"Columns with different stack heights retire their landing ghosts independently")
	var last: Dictionary = incoming[-1]
	_advance(view, Motion.ready_at(last) - float(last.age) + 0.001)
	check(view.snapshot().landing_ghosts.is_empty() and view._ghosts.is_empty(), "The complete batch leaves no landing projections behind")
	for cell: Dictionary in incoming:
		var tile = view._tiles[int(cell.id)]
		check(tile.get_parent() == view and not tile.disabled and view.navigation_controls().has(tile),
			"Every settled arrival rejoins the normal drag and navigation surface")
	_reset(view, true, false)
	incoming = _arrivals(view)
	check(view.snapshot().landing_ghosts.is_empty() and view._ghosts.is_empty(), "Reduced motion creates no duplicate landing silhouettes")
	for cell: Dictionary in incoming:
		var tile = view._tiles[int(cell.id)]
		check(tile.get_global_rect().is_equal_approx(view._global_rect(view._tile_rect(cell))) and tile.disabled,
			"Reduced motion keeps every arrival stationary at its destination behind the input gate")
	_advance(view, Motion.ready_at(incoming[0]) * 0.5)
	for cell: Dictionary in incoming:
		var tile = view._tiles[int(cell.id)]
		check(tile.get_global_rect().is_equal_approx(view._global_rect(view._tile_rect(cell))) and tile._surface.scale == Vector2.ONE and tile.disabled,
			"Reduced motion introduces neither a ghost nor a hidden moving body during the batch's fall time")
	_reset(view)


func _check_landing_presentation(view) -> void:
	_reset(view, false, false)
	var cell: Dictionary = _arrival(view)
	check(not cell.is_empty(), "A new round has a visible batch above its prepared starting board")
	if cell.is_empty():
		return
	var tile = view._tiles[int(cell.id)]
	var target: Rect2 = view._tile_rect(cell)
	var support: Vector2 = view.get_global_transform() * (target.position + tile.size * Vector2(0.5, Motion.FOOT_Y))
	view._process(0.2)
	var shadow_before: float = tile._shadow.modulate.a
	check(tile.get_global_rect().position.y < view._global_rect(target).position.y and tile.disabled and not view._settled(cell),
		"A descending jelly remains above its support and cannot be selected")
	check((tile._shadow.get_global_transform() * (tile._shadow.size * 0.5)).distance_to(support) < tile.size.y * 0.025,
		"The contact shadow stays grounded while its body descends")
	_advance(view, Motion.contact_at(cell) - float(cell.age) + 0.001)
	check(cues.count("land") == 1 and tile.get_global_rect().position.is_equal_approx(view._global_rect(target).position),
		"The arriving tile emits one impact as its visible body reaches its support")
	view._process(Motion.COMPRESSION_SECONDS - 0.001)
	check(tile._surface.scale.y < 0.9 and tile._surface.scale.x > 1.0
		and (tile._surface.get_global_transform() * (tile.size * Vector2(0.5, Motion.FOOT_Y))).is_equal_approx(support),
		"Compression widens the acquired body around a planted foot")
	check(tile._shadow.modulate.a > shadow_before and tile._label.scale == Vector2.ONE
		and tile._picture.scale == Vector2.ONE and tile._visual.scale == Vector2.ONE,
		"Contact strengthens the separate shadow while word and picture stay undistorted")
	var remaining: float = Motion.ready_at(cell) - float(cell.age)
	for index in range(12):
		_advance(view, remaining / 12.0, 1.0 / 240.0)
		check((tile._surface.get_global_transform() * (tile.size * Vector2(0.5, Motion.FOOT_Y))).is_equal_approx(support)
			and tile.get_global_rect().position.is_equal_approx(view._global_rect(target).position),
			"The visible foot and tile destination remain planted across rebound and recovery")
		check(tile._surface.scale.y <= 1.04 and tile._label.scale == Vector2.ONE and tile._picture.scale == Vector2.ONE,
			"A firm impact recovers without a large bounce or deforming its learning content")
	view._process(0.001)
	check(view._settled(cell) and not tile.disabled and tile._surface.scale.is_equal_approx(Vector2.ONE),
		"The visual body settles at the same boundary that enables input")
	var landed_before: int = cues.count("land")
	view._layout()
	view._sync_positions()
	view.apply_theme(Data.theme("spring"), data.chests)
	check(cues.count("land") == landed_before, "Layout, position and theme refreshes never replay an impact")


func _check_landing_audio_groups(view) -> void:
	for skipped_drops in [0, 2]:
		_reset(view, false, false)
		if skipped_drops > 0:
			view.game.step(float(skipped_drops) * view.game.spawn_interval)
			view._sync_tiles()
		var incoming: Array[Dictionary] = _arrivals(view)
		check(incoming.size() == 4, "The landing-audio fixture observes one complete airborne batch")
		if incoming.is_empty():
			continue
		var first_contact: float = Motion.contact_at(incoming[0])
		var last_contact: float = Motion.contact_at(incoming[-1])
		check(last_contact > first_contact,
			"Uneven columns produce distinct contact times within the same dispatched batch")
		# Sample more finely than the 120 ms grouping window. The faster descent
		# can put separate contacts only a few milliseconds beyond that threshold.
		_advance(view, Motion.ready_at(incoming[-1]) + 0.001, 1.0 / 240.0)
		check(cues.count("land") == _landing_groups(incoming),
			"Faster contacts emit one cue for each natural impact group without one cue per tile")
		if skipped_drops == 0:
			check(cues.count("land") == 1 and last_contact - first_contact < 0.12,
				"The first batch's closely spaced impacts combine into one grounded landing cue")
		else:
			check(cues.count("land") == 2 and last_contact - first_contact > 0.12,
				"Contacts beyond the grouping window retain both distinct landing cues")
		var landed: int = cues.count("land")
		_advance(view, 0.3, 1.0 / 240.0)
		check(cues.count("land") == landed, "Recovery never replays a contact cue")
	_reset(view)


func _check_landing_lifecycle(view) -> void:
	_reset(view, false, false)
	var incoming: Array[Dictionary] = _arrivals(view)
	var cell: Dictionary = incoming[0]
	var before_contact: float = Motion.contact_at(cell) * 0.45
	_advance(view, before_contact)
	var paused_cells: Array = view.game.cells.duplicate(true)
	view.pause(true)
	view._process(0.4)
	check(cues.is_empty() and view.game.cells == paused_cells,
		"Pausing before contact freezes the whole batch and does not emit a landing")
	view.pause(false)
	_advance(view, Motion.ready_at(incoming[-1]) - float(incoming[-1].age) + 0.001, 1.0 / 240.0)
	check(cues.count("land") == _landing_groups(incoming),
		"Resume completes the batch with one impact per simultaneous contact group")
	var landed_before: int = cues.count("land")
	_advance(view, 0.2)
	check(cues.count("land") == landed_before, "Recovered batch contacts do not repeat after settling")
	_reset(view, false, false)
	incoming = _arrivals(view)
	paused_cells = view.game.cells.duplicate(true)
	view.hide()
	_advance(view, Motion.ready_at(incoming[-1]) + 0.001, 1.0 / 240.0)
	view.show()
	check(cues.is_empty() and view.game.cells == paused_cells, "A hidden board cannot advance any fall or emit landing feedback")
	_advance(view, Motion.ready_at(incoming[-1]) + 0.001, 1.0 / 240.0)
	check(cues.count("land") == _landing_groups(incoming), "A replacement round owns fresh grouped contacts without the old cooldown")
	_reset(view, true, false)
	incoming = _arrivals(view)
	cell = incoming[0]
	var tile = view._tiles[int(cell.id)]
	check(tile.position == view._tile_rect(cell).position and tile._surface.scale == Vector2.ONE and not view._settled(cell),
		"Reduced motion presents a static body without skipping the input gate")
	_advance(view, Motion.ready_at(incoming[-1]) + 0.001, 1.0 / 240.0)
	check(view._settled(cell) and tile._surface.scale == Vector2.ONE and cues.count("land") == _landing_groups(incoming),
		"Reduced motion retains each ready boundary and quiet grouped contact cues")
	_reset(view)
	view.game.step(view.game.spawn_interval - view.game.spawn_elapsed)
	view._sync_tiles()
	incoming = _arrivals(view)
	var falling: Dictionary = {}
	for arrival: Dictionary in incoming:
		falling[int(arrival.id)] = {"age": float(arrival.age), "position": view._tiles[int(arrival.id)].get_global_rect().position}
	var pair: Array[int] = _pair(view)
	_drag_pair(view, pair[0], pair[1])
	view._process(0.4)
	check(incoming.size() == 4 and not view.game.fusion.is_empty() and not cues.has("land"),
		"Fusion suspends all four arrivals without adding a landing sound")
	for arrival: Dictionary in incoming:
		var held: Dictionary = falling[int(arrival.id)]
		check(is_equal_approx(float(arrival.age), float(held.age))
			and view._tiles[int(arrival.id)].get_global_rect().position.is_equal_approx(Vector2(held.position)),
			"Fusion freezes arrival %s at its current height" % arrival.id)
	view.stop()
	view._process(0.4)
	check(not cues.has("land"), "Stopping the mode cannot revive a pending landing")


func _check_gesture_audio(view) -> void:
	_reset(view)
	var id: int = int(view.game.cells[0].id)
	var start: Vector2 = _center(view, id)
	view._press(4, start)
	view._release(start)
	check(cues == ["pick"] and heard.size() == 1, "A tap reads its word and acknowledges the touch exactly once")
	view.cancel_input()
	view._activate(id)
	check(cues.count("pick") == 2 and heard.size() == 2, "Keyboard pronunciation shares the pointer's tactile feedback")
	view.cancel_input()
	var empty: Vector2 = view.get_global_transform() * (view._board.position + Vector2(view._pitch * 0.5, view._pitch * 0.5))
	view._press(4, start)
	for index in range(10):
		view._move(start.lerp(empty, float(index + 1) / 10.0))
	check(cues.count("pick") == 3 and not cues.has("release"), "Dragging cannot stack sounds for each motion event")
	view._release(empty)
	check(cues.count("release") == 1 and attempts.is_empty(), "An empty drop has a short return cue without counting as an answer")
	view._process(0.3)
	view._layout()
	check(cues.count("release") == 1, "Snapback and layout cannot replay the drop sound")
	view._press(4, _center(view, id))
	view._move(empty)
	view.pause(true)
	check(cues.count("release") == 1, "Menu interruption cancels a drag silently instead of pretending the player dropped it")
	_reset(view)


func _check_consecutive_taps(view) -> void:
	for pointer: int in [-1, 4]:
		_reset(view)
		var pair: Array[int] = _pair(view, true)
		var wrong: int = -1
		for cell: Dictionary in view.game.cells:
			if cell.word.id != view._cell(pair[0]).word.id:
				wrong = int(cell.id)
				break
		check(wrong >= 0, "The tap regression has both a chest-bearing match and a genuine distractor")
		if wrong < 0:
			continue
		var before: Dictionary = view.game.snapshot()
		var ids: Array[int] = [pair[0], pair[1], pair[0], wrong, wrong, pair[1], pair[0], pair[0]]
		for id: int in ids:
			var point: Vector2 = _center(view, id)
			check(view._press(pointer, point), "Each separate mouse or touch tap owns its word until release")
			view._release(point)
			check(int(view.snapshot().drag.selected) == -1 and int(view.snapshot().drag.pointer) == Jelly.NO_POINTER
				and view._contact_state().kind == "none" and view.game.fusion.is_empty(),
				"Each completed tap releases its word without carrying a matching target into the next tap")
		check(heard.size() == ids.size() and cues.count("pick") == ids.size(),
			"Consecutive matching, mismatching and repeated taps pronounce exactly their own words")
		check(view.game.snapshot() == before and attempts.is_empty() and view._rejection.is_empty()
			and view._loot_flights.is_empty() and view._fusion_visuals.is_empty(),
			"Tap sequences cannot judge answers, reset learning streaks, fuse tiles, change score or earn chests")
		check(not cues.has("merge") and not cues.has("wrong") and not cues.has("pop"),
			"Tapping two words never emits answer or fusion feedback")
	_reset(view)


func _check_drag_threshold(view) -> void:
	for pointer: int in [-1, 4]:
		for travel: float in [0.0, 6.0]:
			_reset(view)
			var pair: Array[int] = _pair(view, true)
			var start: Vector2 = _center(view, pair[0])
			var destination: Vector2 = _center(view, pair[1])
			var before: Dictionary = view.game.snapshot()
			view._press(pointer, start)
			view._move(start + Vector2(travel / Style.ui_scale(view), 0.0))
			check(not bool(view.snapshot().drag.active), "Sub-threshold pointer movement remains a pronunciation gesture")
			view._release(destination)
			check(view.game.snapshot() == before and attempts.is_empty() and cues == ["pick"]
				and int(view.snapshot().drag.pointer) == Jelly.NO_POINTER and int(view.snapshot().drag.selected) == -1,
				"Even a release over another tile cannot match without crossing the drag threshold")
	_reset(view)


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
	check(int(view.snapshot().drag.selected) == -1 and int(view.snapshot().drag.pointer) == Jelly.NO_POINTER
		and attempts.is_empty(), "A tap releases ownership without leaving a match selection or learning attempt")
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
	check(not view._rejection.is_empty() and int(view._rejection.a) == first and int(view._rejection.b) == other,
		"An incorrect commit records both participants for one reciprocal rejection")
	check(cues.count("wrong") == 1 and not cues.has("merge") and not cues.has("pop"),
		"An incorrect commit uses one rejection sound without successful fusion feedback")
	view._process(0.08)
	var source_offset: Vector2 = view._tiles[first]._surface.position
	var target_offset: Vector2 = view._tiles[other]._surface.position
	check(view._tiles[first]._contact_kind == "mismatch" and view._tiles[other]._contact_kind == "mismatch"
		and not source_offset.is_zero_approx() and not target_offset.is_zero_approx()
		and source_offset.dot(target_offset) < 0.0, "Both incorrect partners recoil away from their shared contact")
	view._process(0.17)
	check(view._snapbacks.is_empty() and view._tiles[first].position == view._tile_rect(view._cell(first)).position,
		"Snapback settles into the original slot")
	view._process(0.10)
	check(view._rejection.is_empty() and view._tiles[first]._contact_kind == "none" and view._tiles[other]._contact_kind == "none",
		"The complete rejection releases both participants without leaving a false match cue")
	check(view._tiles[first]._surface.position.is_zero_approx() and view._tiles[other]._surface.position.is_zero_approx(),
		"Both surfaces return to their authored positions when rejection ends")
	check(attempts.size() == 1 and cues.count("wrong") == 1 and view.game.score() == 0 and view.game.chest_count == 0,
		"Rejection playback cannot repeat the learning reset or earn a reward")


func _lift_stopped(tile) -> bool:
	return tile._lift == null or not tile._lift.is_valid() or not tile._lift.is_running()


func _check_feedback_cleared(tile, reason: String) -> void:
	check(not tile.selected and not tile.highlighted and is_zero_approx(float(tile._gel.get_shader_parameter("rim_strength"))),
		"%s clears selection and contact contours" % reason)
	check(tile._visual.position.is_zero_approx() and _lift_stopped(tile),
		"%s immediately resets and stops the selection lift" % reason)


func _check_pointer_feedback(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	var tile = view._tiles[pair[0]]
	view._tiles[pair[1]].grab_focus()
	view._press(2, _center(view, pair[0]))
	check(tile.selected and not view._tiles.values().has(root.gui_get_focus_owner()),
		"Holding a jelly clears an earlier tile focus and presents one active touch cue")
	check(float(tile._gel.get_shader_parameter("rim_strength")) > 0.0 and tile._lift != null,
		"A held pointer uses the gel contour and starts the tactile lift")
	if tile._lift != null and tile._lift.is_valid():
		tile._lift.custom_step(0.12)
	check(tile._visual.position.y < 0.0, "The held jelly visibly rises before pointer release")
	view._release(_center(view, pair[0]))
	_check_feedback_cleared(tile, "Releasing a pronunciation tap")
	check(int(view.snapshot().drag.selected) == -1 and not tile.has_focus(),
		"A completed tap leaves neither a pending match selection nor pointer-created keyboard focus")
	view._press(2, _center(view, pair[0]))
	view._release(_center(view, pair[0]))
	_check_feedback_cleared(tile, "Tapping the same jelly again")
	check(heard.size() == 2 and attempts.is_empty(), "Repeated taps replay pronunciation without selecting or answering")
	view.finish_button.grab_focus()
	view._press(2, _center(view, pair[0]))
	check(view.finish_button.has_focus(), "Tile pointer input leaves the separately focused Finish control alone")
	view.cancel_input()
	view.finish_button.release_focus()


func _check_drag_after_tap(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	var previous: int = -1
	for cell: Dictionary in view.game.cells:
		if not pair.has(int(cell.id)):
			previous = int(cell.id)
			break
	view._press(2, _center(view, previous))
	view._release(_center(view, previous))
	view._press(2, _center(view, pair[0]))
	view._move(_center(view, pair[1]))
	view._sync_positions()
	_check_feedback_cleared(view._tiles[previous], "Dragging a different jelly")
	var source = view._tiles[pair[0]]
	var target = view._tiles[pair[1]]
	check(source.selected and target.highlighted and not target.selected,
		"The held jelly and prospective partner have distinct selection and contact states")
	check(source._contact_kind == "match" and target._contact_kind == "match"
		and target._surface.scale != Vector2.ONE,
		"Both valid partners share matching feedback while the target responds to contact")
	view.cancel_input()
	_check_feedback_cleared(source, "Cancelling the dragged source")
	_check_feedback_cleared(target, "Cancelling the prospective partner")
	check(source._surface.scale == Vector2.ONE and target._surface.scale == Vector2.ONE,
		"Cancellation clears contact squash without waiting for the next frame")


func _check_contact_validity(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	var wrong: int = -1
	for cell: Dictionary in view.game.cells:
		if cell.word.id != view._cell(pair[0]).word.id and cell.kind != view._cell(pair[0]).kind:
			wrong = int(cell.id)
			break
	check(wrong >= 0, "The contact test has a real opposite-kind distractor")
	if wrong < 0:
		return
	view._press(2, _center(view, pair[0]))
	view._move(_center(view, pair[1]))
	view._process(0.08)
	var contact: Dictionary = view._contact_state()
	check(contact.kind == "match" and int(contact.source) == pair[0] and int(contact.target) == pair[1],
		"Dragging a picture onto its word identifies the actual two matching participants")
	check(view._tiles[pair[0]]._contact_kind == "match" and view._tiles[pair[1]]._contact_kind == "match",
		"Matching contact reaches both gel surfaces instead of decorating only the target")
	var source_offset: Vector2 = view._tiles[pair[0]]._surface.position
	var target_offset: Vector2 = view._tiles[pair[1]]._surface.position
	check(not source_offset.is_zero_approx() and not target_offset.is_zero_approx()
		and source_offset.dot(target_offset) < 0.0, "Correct contact visibly pulls the two gel surfaces toward each other")
	check(str(view.snapshot().contact.kind) == "match", "The published contact state agrees with the rendered match feedback")
	var settled_clock: float = view._contact_elapsed
	for index in range(8):
		view._move(_center(view, pair[1]))
	check(is_equal_approx(view._contact_elapsed, settled_clock), "Repeated motion events do not restart or advance contact animation")
	check(attempts.is_empty() and view.game.fusion.is_empty() and view.game.score() == 0 and view.game.chest_count == 0
		and cues == ["pick"], "Matching hover neither submits an answer nor stacks sounds or rewards")
	view._move(_center(view, wrong))
	check(is_zero_approx(view._contact_elapsed), "Changing partners starts a fresh contact response")
	view._process(0.08)
	contact = view._contact_state()
	check(contact.kind == "mismatch" and int(contact.target) == wrong,
		"A different word is rejected visually even when the two tile kinds are complementary")
	check(view._tiles[pair[0]]._contact_kind == "mismatch" and view._tiles[wrong]._contact_kind == "mismatch"
		and view._tiles[pair[1]]._contact_kind == "none", "Retargeting updates both new participants and releases the previous partner")
	check(attempts.is_empty() and view.game.fusion.is_empty() and cues == ["pick"],
		"An incorrect preview does not reset learning or play the committed rejection sound")
	var empty: Vector2 = view.get_global_transform() * (view._board.position + Vector2(view._pitch * 0.5, view._pitch * 0.5))
	view._move(empty)
	check(view._contact_state().kind == "none" and view._tiles[pair[0]]._contact_kind == "none"
		and view._tiles[wrong]._contact_kind == "none", "Leaving all partners immediately removes reciprocal contact feedback")
	view.cancel_input()


func _check_same_kind_contact(view) -> void:
	check(view.configure(words.slice(0, 1), 3, Data.theme("spring"), data.chests, false, 42),
		"A real single-word supply can exercise repeated copies without mutating board state")
	view.set_process(false)
	view.game.step(view.game.SETTLE_SECONDS)
	view._sync_tiles()
	view._layout()
	heard.clear()
	attempts.clear()
	cues.clear()
	var pair: Array[int] = []
	for first: Dictionary in view.game.cells:
		for second: Dictionary in view.game.cells:
			if first.id != second.id and first.word.id == second.word.id and first.kind == second.kind:
				pair = [int(first.id), int(second.id)]
				break
		if not pair.is_empty():
			break
	check(pair.size() == 2, "The ordinary supply contains repeated copies of the same tile kind")
	if pair.size() != 2:
		_reset(view)
		return
	view._press(2, _center(view, pair[0]))
	view._move(_center(view, pair[1]))
	view._process(0.08)
	check(view._contact_state().kind == "mismatch" and view._tiles[pair[0]]._contact_kind == "mismatch"
		and view._tiles[pair[1]]._contact_kind == "mismatch", "Same-word copies still need opposite kinds to receive matching feedback")
	check(attempts.is_empty() and view.game.fusion.is_empty(), "A same-kind hover remains presentation only")
	view._release(_center(view, pair[1]))
	check(attempts.size() == 1 and not attempts[0].correct and view.game.fusion.is_empty(),
		"Committing same-kind copies agrees with the preview and resets the word only once")
	_reset(view)


func _check_contact_lifecycle(view) -> void:
	for interruption: String in ["cancel", "pause", "hide", "stop", "new_round"]:
		_reset(view)
		var pair: Array[int] = _pair(view)
		view._press(2, _center(view, pair[0]))
		view._move(_center(view, pair[1]))
		view._process(0.08)
		match interruption:
			"cancel":
				view.cancel_input()
			"pause":
				view.pause(true)
			"hide":
				view.hide()
			"stop":
				view.stop()
			"new_round":
				_reset(view)
		check(view._contact_state().kind == "none" and is_zero_approx(view._contact_elapsed) and view._rejection.is_empty(),
			"%s clears contact and rejection ownership immediately" % interruption)
		for tile in view._tiles.values():
			check(tile._contact_kind == "none" and tile._surface.position.is_zero_approx(),
				"%s leaves no stale matching material or contact offset on a surviving tile" % interruption)
		check(attempts.is_empty() and view._fusion_visuals.is_empty(), "%s cannot convert cancelled contact into a fusion or attempt" % interruption)
		view.show()
		view.pause(false)
	_reset(view)
	var pair: Array[int] = _pair(view)
	view._press(2, _center(view, pair[0]))
	view._move(_center(view, pair[1]))
	view._process(0.08)
	view.set_reduced_motion(true)
	check(view._contact_state().kind == "match" and view._tiles[pair[0]]._contact_kind == "match"
		and view._tiles[pair[1]]._contact_kind == "match", "Reduced motion retains understandable static match feedback")
	for id: int in pair:
		check(view._tiles[id]._surface.scale == Vector2.ONE and view._tiles[id]._visual.position.is_zero_approx()
			and view._tiles[id]._surface.position.is_zero_approx(),
			"Enabling reduced motion removes active contact movement on both partners")
	view.cancel_input()
	check(view._contact_state().kind == "none" and view._tiles[pair[0]]._contact_kind == "none"
		and view._tiles[pair[1]]._contact_kind == "none", "Cancelling reduced-motion contact removes both static markers")
	_reset(view)


func _check_rejection_lifecycle(view) -> void:
	for interruption: String in ["cancel", "pause", "hide", "stop", "new_round"]:
		_reset(view)
		var first: int = int(view.game.cells[0].id)
		var other: int = -1
		for cell: Dictionary in view.game.cells:
			if cell.word.id != view._cell(first).word.id:
				other = int(cell.id)
				break
		view._press(2, _center(view, first))
		view._move(_center(view, other))
		view._release(_center(view, other))
		view._process(0.08)
		check(not view._rejection.is_empty(), "%s begins with an active committed rejection" % interruption)
		match interruption:
			"cancel":
				view.cancel_input()
			"pause":
				view.pause(true)
			"hide":
				view.hide()
			"stop":
				view.stop()
			"new_round":
				_reset(view)
		check(view._rejection.is_empty() and view._fusion_visuals.is_empty(),
			"%s immediately removes the interrupted rejection effect" % interruption)
		for tile in view._tiles.values():
			check(tile._contact_kind == "none" and tile._surface.position.is_zero_approx(),
				"%s releases both rejection participants without a stale offset" % interruption)
		view.show()
		view.pause(false)
		view._process(0.4)
		check(view._rejection.is_empty() and cues.count("wrong") <= 1 and not cues.has("merge") and not cues.has("pop"),
			"%s cannot revive a cancelled rejection or emit a stale success cue" % interruption)
	_reset(view)


func _check_keyboard_feedback(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view, true)
	var first = view._tiles[pair[0]]
	var second = view._tiles[pair[1]]
	var before: Dictionary = view.game.snapshot()
	first.grab_focus()
	var focus_strength: float = float(first._gel.get_shader_parameter("rim_strength"))
	var focus_width: float = float(first._gel.get_shader_parameter("rim_width"))
	check(first.has_focus() and not first.selected and focus_strength > 0.0
		and first._visual.position.is_zero_approx() and _lift_stopped(first),
		"Keyboard focus is visible without selecting or lifting a jelly")
	first.pressed.emit()
	check(not first.selected and is_equal_approx(float(first._gel.get_shader_parameter("rim_strength")), focus_strength)
		and is_equal_approx(float(first._gel.get_shader_parameter("rim_width")), focus_width)
		and first._visual.position.is_zero_approx() and _lift_stopped(first),
		"Keyboard or controller confirmation reads the focused word without creating a match selection")
	second.grab_focus()
	_check_feedback_cleared(first, "Navigating away from a pronounced word")
	check(second.has_focus() and not second.selected
		and is_equal_approx(float(second._gel.get_shader_parameter("rim_strength")), focus_strength),
		"Moving keyboard focus gives the next word only a navigation cue")
	second.pressed.emit()
	check(heard.size() == 2 and cues == ["pick", "pick"] and attempts.is_empty()
		and view.game.snapshot() == before and view._rejection.is_empty() and view._fusion_visuals.is_empty(),
		"Confirming matching partners only pronounces both words and cannot change learning, score or treasure")
	for index in range(4):
		second.pressed.emit()
	check(heard.size() == 6 and cues.count("pick") == 6 and attempts.is_empty()
		and view.game.snapshot() == before and int(view.snapshot().drag.selected) == -1,
		"Repeated keyboard or controller confirmation never builds a pending pair or learning streak")
	check(second.has_focus() and not second.selected and second._visual.position.is_zero_approx() and _lift_stopped(second),
		"Pronunciation retains ordinary keyboard focus without a sticky lift or selection")


func _check_feedback_lifecycle(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	var tile = view._tiles[pair[0]]
	view._press(2, _center(view, pair[0]))
	if tile._lift != null and tile._lift.is_valid():
		tile._lift.custom_step(0.12)
	view.set_reduced_motion(true)
	check(tile.selected and int(view.snapshot().drag.selected) == -1
		and int(view.snapshot().drag.source) == pair[0] and float(tile._gel.get_shader_parameter("rim_strength")) > 0.0,
		"Enabling reduced motion retains only the currently held jelly and its static contour")
	check(tile._visual.position.is_zero_approx() and _lift_stopped(tile),
		"Enabling reduced motion immediately ends an in-flight lift")
	view.cancel_input()
	_check_feedback_cleared(tile, "Cancelling a held jelly under reduced motion")
	tile.grab_focus()
	tile.pressed.emit()
	check(not tile.selected and tile.has_focus() and float(tile._gel.get_shader_parameter("rim_strength")) > 0.0
		and tile._visual.position.is_zero_approx() and attempts.is_empty(),
		"Reduced-motion keyboard pronunciation retains only its independent focus cue")
	view.pause(true)
	_check_feedback_cleared(tile, "Pausing keyboard navigation")
	view.pause(false)
	view.set_reduced_motion(false)
	view._press(2, _center(view, pair[0]))
	view._move(_center(view, pair[1]))
	view._sync_positions()
	if tile._lift != null and tile._lift.is_valid():
		tile._lift.custom_step(0.12)
	view.pause(true)
	_check_feedback_cleared(tile, "Pausing an active drag")
	_check_feedback_cleared(view._tiles[pair[1]], "Pausing a highlighted partner")
	check(tile._surface.scale == Vector2.ONE and view._tiles[pair[1]]._surface.scale == Vector2.ONE,
		"Pause removes drag stretch and contact squash immediately")
	view.pause(false)
	view._press(2, _center(view, pair[0]))
	view._release(_center(view, pair[0]))
	view.hide()
	_check_feedback_cleared(tile, "Hiding the mode")
	view.show()


func _fill_board(view) -> void:
	for index in range(view.game.CAPACITY * 100):
		if view.game.full_elapsed >= 0.0 or view.game.phase != "playing":
			break
		var remaining: float = float(view.game.spawn_interval) - float(view.game.spawn_elapsed)
		if view.game.cells.size() == view.game.CAPACITY:
			remaining = 0.0
			for cell: Dictionary in view.game.cells:
				remaining = maxf(remaining, Motion.ready_at(cell) - float(cell.age))
		view._process(minf(0.25, maxf(0.000001, remaining)))
	check(view.game.cells.size() == view.game.CAPACITY and is_zero_approx(float(view.game.full_elapsed)),
		"Batch supply fills the board and starts its warning only when every final arrival is ready")


func _check_danger_hidden(view, reason: String) -> void:
	var danger: Dictionary = view.danger_feedback()
	check(not bool(danger.active) and is_zero_approx(float(danger.strength)),
		"%s immediately suppresses the countdown warning" % reason)
	check(view.snapshot().danger == danger, "%s publishes the same warning state" % reason)


func _check_danger_clock(view) -> void:
	_reset(view)
	_check_danger_hidden(view, "A board with available space")
	var warning_frames: Array[Dictionary] = []
	var capture_warning: Callable = func(cue: String) -> void:
		if cue == "danger":
			warning_frames.append(view.danger_feedback().duplicate(true))
	view.audio_requested.connect(capture_warning)
	_fill_board(view)
	check(cues.count("danger") == 1 and not cues.has("tick"),
		"Filling the board starts one warning sound without a second overlapping cue")
	var start: Dictionary = view.danger_feedback()
	var landed_before: int = cues.count("land")
	check(bool(start.active) and is_equal_approx(float(start.strength), 1.0),
		"The warning starts at full brightness with its first sound")
	view._refresh_hud()
	view._layout()
	check(view.danger_feedback() == start, "Refreshing layout and HUD cannot restart the model-clock warning phase")
	view._process(0.125)
	check(is_equal_approx(float(view.danger_feedback().strength), 1.0),
		"The warning remains bright long enough to read each pulse")
	view._process(0.125)
	var early_fade: float = float(view.danger_feedback().strength)
	view._process(0.125)
	var late_fade: float = float(view.danger_feedback().strength)
	check(cues.count("land") == landed_before, "Fresh top-row contacts cannot cover the full-board warning")
	check(early_fade > late_fade and late_fade > 0.0 and early_fade < 1.0,
		"The warning fades smoothly after its bright interval")
	view._process(0.25)
	var dim: Dictionary = view.danger_feedback()
	check(bool(dim.active) and is_zero_approx(float(dim.strength)) and view.snapshot().danger == dim,
		"The dim interval stays logically active while its visible strength reaches zero")
	view._process(0.25)
	check(is_zero_approx(float(view.danger_feedback().strength)), "The warning stays dim until the next clock boundary")
	for delta: float in [0.125, 0.5, 0.5]:
		view._process(delta)
	check(warning_frames.size() == 3 and cues.count("danger") == 3 and not cues.has("tick"),
		"The zero-, one-, and two-second boundaries each produce one warning sound")
	for frame: Dictionary in warning_frames:
		check(bool(frame.active) and is_equal_approx(float(frame.strength), 1.0),
			"The visual warning is already bright inside the corresponding audio callback")
	view._process(0.25)
	var before: Dictionary = view.danger_feedback()
	var elapsed: float = float(view.game.full_elapsed)
	var first: int = int(view.game.cells[0].id)
	var other: int = -1
	for cell: Dictionary in view.game.cells:
		if cell.word.id != view._cell(first).word.id:
			other = int(cell.id)
			break
	_drag_pair(view, first, other)
	check(attempts.size() == 1 and not bool(attempts[0].correct), "The warning test makes a real incorrect match")
	check(is_equal_approx(float(view.game.full_elapsed), elapsed) and view.danger_feedback() == before
		and cues.count("danger") == 3,
		"An incorrect match does not restart, brighten, or repeat the countdown warning")
	view.audio_requested.disconnect(capture_warning)


func _check_danger_lifecycle(view) -> void:
	_reset(view)
	_fill_board(view)
	view._process(0.25)
	var elapsed: float = float(view.game.full_elapsed)
	var before: Dictionary = view.danger_feedback()
	var warnings: int = cues.count("danger")
	view.pause(true)
	_check_danger_hidden(view, "Pausing a full board")
	view._process(0.4)
	check(is_equal_approx(float(view.game.full_elapsed), elapsed) and cues.count("danger") == warnings,
		"A paused warning advances neither the countdown nor its sound")
	view.pause(false)
	check(view.danger_feedback() == before, "Resuming restores the saved warning phase without starting a new pulse")
	view.hide()
	_check_danger_hidden(view, "Hiding a full board")
	view._process(0.4)
	view.show()
	check(view.danger_feedback() == before and is_equal_approx(float(view.game.full_elapsed), elapsed),
		"Returning to the mode preserves the countdown phase that was hidden")
	var pair: Array[int] = _pair(view)
	_drag_pair(view, pair[0], pair[1])
	check(not view.game.fusion.is_empty(), "A correct match starts a real rescue fusion on the full board")
	_check_danger_hidden(view, "Starting a rescue fusion")
	view._process(0.4)
	check(is_equal_approx(float(view.game.full_elapsed), elapsed) and cues.count("danger") == warnings,
		"Rescue fusion suspends the old countdown without continuing its warning sounds")
	for delta: float in [0.4, 0.25]:
		view._process(delta)
	check(view.game.cells.size() == view.game.CAPACITY - 2 and view.game.full_elapsed < 0.0,
		"Completing the rescue makes space and clears the model's danger clock")
	_check_danger_hidden(view, "Completing a rescue fusion")
	_fill_board(view)
	check(cues.count("danger") == warnings + 1 and not cues.has("tick")
		and is_equal_approx(float(view.danger_feedback().strength), 1.0),
		"Filling the rescued space begins a fresh warning and one new first sound")


func _check_danger_reduced_motion_and_end(view) -> void:
	_reset(view, true)
	_check_danger_hidden(view, "Reduced motion before the board fills")
	_fill_board(view)
	for delta: float in [0.125, 0.25, 0.25]:
		view._process(delta)
		check(bool(view.danger_feedback().active) and is_equal_approx(float(view.danger_feedback().strength), 1.0),
			"Reduced motion keeps the countdown warning steadily visible")
	var elapsed: float = float(view.game.full_elapsed)
	view.set_reduced_motion(false)
	check(is_zero_approx(float(view.danger_feedback().strength)) and is_equal_approx(float(view.game.full_elapsed), elapsed),
		"Disabling reduced motion resumes the existing dim phase without resetting time")
	view.set_reduced_motion(true)
	check(is_equal_approx(float(view.danger_feedback().strength), 1.0) and cues.count("danger") == 1,
		"Enabling reduced motion immediately restores a steady warning without replaying its sound")
	for index in range(20):
		if view.game.phase == "finished":
			break
		view._process(0.5)
	check(view.game.phase == "finished" and finishes.size() == 1 and cues.count("danger") == 8 and not cues.has("tick"),
		"The eight-second deadline finishes once after exactly eight warning sounds")
	_check_danger_hidden(view, "Reaching the deadline")
	view.result_reveal()
	_check_danger_hidden(view, "Revealing the completed result")
	view.stop()
	_check_danger_hidden(view, "Stopping the mode")
	_reset(view)
	_check_danger_hidden(view, "Starting a fresh round")


func _check_fusion(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view, true)
	var source_center: Vector2 = _center(view, pair[0])
	_drag_pair(view, pair[0], pair[1])
	check(heard.size() == 1 and not view.game.fusion.is_empty(), "Dragging reads the held word and starts fusion only when released on its matching partner")
	check(attempts.is_empty() and view.game.chest_count == 0, "A matching contact does not credit a clear or treasure before fusion completes")
	check(view.finish_button.disabled and view._can_play(), "Fusion keeps other jellies interactive while preventing early finish")
	view._process(0.10)
	check(view._tiles[pair[0]].visible and view._tiles[pair[1]].visible and not _effect(view).merged.visible,
		"Fusion begins with two separate droplets moving into contact")
	check(_effect(view).art.visible and not view._tiles[pair[0]]._surface.visible and not view._tiles[pair[1]]._surface.visible,
		"The shared gel material draws contact continuously without layering two opaque tile bodies")
	check(_center(view, pair[0]) != source_center, "The held droplet moves toward its matching partner")
	view._process(0.32)
	check(_effect(view).merged.visible and _effect(view).merged._picture.visible and _effect(view).merged._label.visible,
		"The merged jelly holds its picture and word together before popping")
	check(_effect(view).art.visible and not _effect(view).merged._surface.visible,
		"The combined word and picture remain separate from the continuous deforming gel material")
	check(not view._tiles[pair[0]].visible and not view._tiles[pair[1]].visible,
		"The merged jelly replaces both source droplets once they unite")
	view._process(0.29)
	check(cues.count("pop") == 1 and attempts.is_empty(), "The visual pop shares the model's timed sound event before credit")
	view._process(0.34)
	check(attempts.size() == 1 and bool(attempts[0].correct) and view.game.chest_count == 1,
		"One completed fusion grants exactly one word credit and its marked chest")
	check(not view._tiles.has(pair[0]) and not view._tiles.has(pair[1]) and view._fusion_visuals.is_empty(),
		"Cleared droplets disappear and the model supplies gravity")
	check(view._fusion_visuals.is_empty(), "The completed clear also releases the shared material effect")
	check(view._loot_flights.size() == 1, "A completed treasure fusion flies toward the visible chest total")
	view._release(source_center)
	check(attempts.size() == 1, "A stale release cannot repeat a completed merge")


func _check_concurrent_fusions(view) -> void:
	for delay: float in [0.18, 0.76]:
		_reset(view)
		var pairs: Array[Array] = _available_pairs(view)
		check(pairs.size() >= 2, "The production board supplies two independent settled pairs")
		if pairs.size() < 2:
			continue
		var first: Array = pairs[0]
		var second: Array = pairs[1]
		var chests: int = 0
		for id: int in first + second:
			chests += 1 if bool(view._cell(id).chest) else 0
		var first_home: Vector2 = view._global_rect(view._tile_rect(view._cell(first[0]))).get_center()
		var second_target_home: Vector2 = _center(view, second[1])
		_drag_pair(view, first[0], first[1])
		var elapsed: float = view.game.spawn_elapsed
		var generated: int = view.game.generated_tiles
		_advance(view, delay)
		check(view._can_play() and view.finish_button.disabled, "Other jellies remain playable during merge and elastic release")
		check(not view._press(-1, first_home), "A participating jelly cannot begin a second gesture")
		view._activate(first[0])
		check(heard.size() == 1 and view.game.fusions.size() == 1, "Reserved jellies cannot replay pronunciation or create a duplicate fusion")
		for id: int in second:
			view._press(-1, _center(view, id))
			view._release(_center(view, id))
		check(heard.size() == 3 and attempts.is_empty() and view.game.fusions.size() == 1,
			"Consecutive taps on other matching jellies remain pronunciation only during an active fusion")
		view.finish_button.pressed.emit()
		check(view.game.phase == "playing" and finishes.is_empty(), "A synthetic Finish press cannot interrupt an unearned clear")
		check(view._press(4, _center(view, second[0])), "Touch can pick up an unrelated jelly while another pair animates")
		view._move(second_target_home)
		check(view.snapshot().drag.active and view.snapshot().drag.target == second[1]
			and view.snapshot().contact.kind == "match", "The second drag gets ordinary matching contact feedback")
		check(view._fusion_visuals.size() == 1 and _effect(view).art.visible,
			"Moving a new jelly preserves the first pair's continuous material effect")
		view._release(second_target_home)
		check(view.game.fusions.size() == 2 and view._fusion_visuals.size() == 2,
			"A second valid drop starts its own fusion immediately instead of being ignored or queued")
		check(view.snapshot().fusion_effects.size() == 2 and attempts.is_empty(),
			"Both accepted effects are observable before either receives learning credit")
		check(cues.count("merge") == 2 and is_equal_approx(view.game.spawn_elapsed, elapsed)
			and view.game.generated_tiles == generated, "Two independent merge sounds do not restart the paused supply")
		var first_id: String = str(view.game.fusions[0].attempt_id)
		var second_id: String = str(view.game.fusions[1].attempt_id)
		_advance(view, view.game.FUSION_SECONDS - delay)
		check(view.game.cleared_pairs == 1 and attempts.size() == 1 and attempts[0].id == first_id,
			"The older fusion earns its word exactly at its own completion boundary")
		check(view.game.fusions.size() == 1 and str(view.game.fusions[0].attempt_id) == second_id
			and view._fusion_visuals.size() == 1 and view._fusion_visuals.has(second_id),
			"Completing the older pair removes only its own material and face")
		check(view.finish_button.disabled and view._can_play()
			and is_equal_approx(view.game.spawn_elapsed, elapsed) and view.game.generated_tiles == generated,
			"Supply and Finish remain paused until the final independent fusion completes")
		check(view._global_rect(view._tile_rect(view._cell(second[1]))).get_center().is_equal_approx(second_target_home),
			"Earlier removal cannot shift the still-animating pair's destination")
		_advance(view, delay)
		check(view.game.fusions.is_empty() and view._fusion_visuals.is_empty() and not view.finish_button.disabled,
			"The final disappearance releases all effects and enables Finish")
		check(attempts.size() == 2 and attempts[1].id == second_id and first_id != second_id
			and bool(attempts[0].correct) and bool(attempts[1].correct) and view.game.chest_count == chests,
			"Independent pairs receive distinct, exactly-once word and marked-chest credits")
		check(cues.count("pop") == 2 and view.game.cleared_pairs == 2, "Both timelines pop once and score once")
		view._release(second_target_home)
		_advance(view, 0.2)
		check(attempts.size() == 2 and view.game.chest_count == chests and view.game.spawn_elapsed > elapsed,
			"A repeated release cannot duplicate awards and ordinary supply resumes after all fusions")


func _check_drag_across_fusion_completion(view) -> void:
	_reset(view)
	var pairs: Array[Array] = _available_pairs(view)
	var first: Array = pairs[0]
	var second: Array = pairs[1]
	var arranged: Array[Dictionary] = []
	var positions: Array[Vector2i] = [Vector2i(0, 5), Vector2i(1, 5), Vector2i(0, 4), Vector2i(2, 5)]
	var ids: Array = first + second
	for index in range(ids.size()):
		var cell: Dictionary = view._cell(ids[index]).duplicate(true)
		cell.column = positions[index].x
		cell.row = positions[index].y
		arranged.append(cell)
	view.game.cells.assign(arranged)
	view._sync_tiles()
	_drag_pair(view, first[0], first[1])
	_advance(view, 0.77)
	var source_home: Vector2 = _center(view, second[0])
	var held: Vector2 = source_home + Vector2(view._pitch * 0.32, -view._pitch * 0.27)
	check(view._press(-1, source_home), "Mouse can begin another drag during elastic disappearance")
	view._move(held)
	var position: Vector2 = view._tiles[second[0]].position
	_advance(view, 0.28)
	check(view.game.cleared_pairs == 1 and view.game.fusions.is_empty() and view.snapshot().drag.active
		and view.snapshot().drag.source == second[0] and view.snapshot().drag.pointer == -1,
		"Completing the last animated pair preserves an unrelated held pointer and source")
	check(view._tiles[second[0]].position.is_equal_approx(position),
		"Applying gravity below a held jelly cannot snap it away from the pointer")
	check(int(view._cell(second[0]).row) == 5 and not view.game.is_settled(view._cell(second[0]))
		and view.game.is_settled(view._cell(second[1])),
		"The first clear moves the held jelly's logical home while its partner remains a settled target")
	view._move(_center(view, second[1]))
	view._release(_center(view, second[1]))
	check(view.game.fusions.size() == 1 and attempts.size() == 1,
		"An uninterrupted drag can commit immediately despite gravity moving its logical home")
	_advance(view, view.game.FUSION_SECONDS)
	check(attempts.size() == 2 and view.game.cleared_pairs == 2, "Continuing the held drag awards the second word once")


func _check_concurrent_fusion_lifecycle(view) -> void:
	_reset(view)
	var pairs: Array[Array] = _available_pairs(view)
	check(pairs.size() >= 3, "The lifecycle scenario has a third free pair to hold")
	if pairs.size() < 3:
		return
	_drag_pair(view, pairs[0][0], pairs[0][1])
	_advance(view, 0.12)
	_drag_pair(view, pairs[1][0], pairs[1][1])
	view._press(7, _center(view, pairs[2][0]))
	view._move(_center(view, pairs[2][1]))
	var saved: Array = view.game.fusions.duplicate(true)
	view.pause(true)
	_advance(view, 0.4)
	check(view.game.fusions == saved and view._fusion_visuals.size() == 2 and attempts.is_empty(),
		"A menu freezes every active fusion without discarding or prematurely crediting it")
	check(not view.snapshot().drag.active and view.snapshot().drag.pointer == Jelly.NO_POINTER
		and view.snapshot().contact.kind == "none", "Pausing cancels only the uncommitted third gesture")
	view.pause(false)
	view._release(_center(view, pairs[2][1]))
	check(view.game.fusions.size() == 2, "A stale touch release after resume cannot commit the canceled drag")
	view.set_reduced_motion(true)
	for effect: Dictionary in view._fusion_visuals.values():
		check(not effect.art.visible and effect.merged.visible and effect.merged._surface.visible,
			"Reduced motion switches every simultaneous fusion to its static authored combined jelly")
	view.stop()
	check(view._fusion_visuals.is_empty() and not view.snapshot().drag.active and attempts.is_empty(),
		"Leaving the mode immediately removes all simultaneous effects and unearned interaction")
	_reset(view)
	_advance(view, view.game.FUSION_SECONDS)
	check(view.game.fusions.is_empty() and view._fusion_visuals.is_empty() and attempts.is_empty()
		and view.game.chest_count == 0, "New rounds cannot inherit prior concurrent effects, callbacks, or rewards")


func _check_fusion_interruption(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view, true)
	_drag_pair(view, pair[0], pair[1])
	view._process(0.42)
	var elapsed: float = view.game.fusion.elapsed
	var pose: Rect2 = _effect(view).merged.get_rect()
	view.pause(true)
	view._process(0.3)
	check(is_equal_approx(view.game.fusion.elapsed, elapsed) and _effect(view).merged.get_rect().is_equal_approx(pose)
		and attempts.is_empty(), "A menu freezes the in-progress gel union and its unearned reward")
	view.set_reduced_motion(true)
	check(not _effect(view).art.visible and _effect(view).merged.visible and _effect(view).merged._surface.visible,
		"Enabling reduced motion during fusion switches to the static authored combined jelly")
	view.pause(false)
	var static_pose: Rect2 = _effect(view).merged.get_rect()
	view._process(0.3)
	check(_effect(view).merged.get_rect().is_equal_approx(static_pose) and _effect(view).merged._surface.scale == Vector2.ONE
		and not _effect(view).art.visible and attempts.is_empty(), "Reduced motion keeps the combined tile still while honoring the original completion boundary")
	view._process(0.33)
	check(attempts.size() == 1 and attempts[0].correct and view.game.chest_count == 1
		and view._fusion_visuals.is_empty(), "Resuming a reduced-motion fusion awards its word and chest once at the original end")
	_reset(view)
	pair = _pair(view)
	_drag_pair(view, pair[0], pair[1])
	view._process(0.2)
	view.stop()
	view._process(0.4)
	check(view._fusion_visuals.is_empty() and attempts.is_empty(),
		"Stopping during contact removes the unified material without completing a stale answer")
	_reset(view)
	check(view._fusion_visuals.is_empty() and view.game.fusion.is_empty() and attempts.is_empty(),
		"A new round cannot inherit an interrupted fusion effect or success credit")


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
	_drag_pair(view, pair[0], pair[1])
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
	check(view.snapshot().score == 1 and view.snapshot().result.title == "Round results"
		and view.snapshot().result.caption == "Score: 1 · Chests: 1", "The settled result reports completed pairs and exact loot")
	for dimensions: Vector2 in [Vector2(390, 640), Vector2(844, 235), Vector2(320, 260)]:
		view.size = dimensions
		view._layout()
		check(Rect2(Vector2.ZERO, dimensions).encloses(view.chests_button.get_rect()), "Result actions fit %s" % dimensions)
		check(not view.chests_button.get_rect().intersects(view.replay_button.get_rect()), "Result actions never overlap at %s" % dimensions)
		for label: Label in [view._result_title, view._result_caption]:
			check(Rect2(Vector2.ZERO, dimensions).encloses(label.get_rect()), "Result facts fit %s" % dimensions)
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
	check(view.snapshot().score == 0 and view.snapshot().result.caption == "Score: 0 · Chests: 0",
		"An empty round explicitly reports zero score and zero loot")
	view.size = Vector2(1000, 720)


func _check_reduced_motion_and_cache(view) -> void:
	_reset(view, true)
	var pair: Array[int] = _pair(view, true)
	_drag_pair(view, pair[0], pair[1])
	view._process(0.2)
	var static_rect: Rect2 = _effect(view).merged.get_rect()
	view._process(0.3)
	check(_effect(view).merged.get_rect().is_equal_approx(static_rect) and _effect(view).merged._surface.scale == Vector2.ONE,
		"Reduced motion shows a stationary combined picture and word: %s -> %s, scale %s" % [static_rect, _effect(view).merged.get_rect(), _effect(view).merged._surface.scale])
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
	check(view._tiles.is_empty() and view._fusion_visuals.is_empty() and not view.finish_button.visible
		and not view._loot_icon.visible and not bool(view.snapshot().preview.visible) and view._ghosts.is_empty(),
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
	var source_tile = view._tiles[pair[0]]
	var target_tile = view._tiles[pair[1]]
	view._press(-1, _center(view, pair[0]))
	if source_tile._lift != null and source_tile._lift.is_valid():
		source_tile._lift.custom_step(0.12)
	view._move(target)
	view._sync_positions()
	var held_center: Vector2 = source_tile.get_rect().get_center() + source_tile._surface.position
	view._release(target)
	_check_feedback_cleared(source_tile, "Starting pointer fusion on its first frame")
	_check_feedback_cleared(target_tile, "Starting pointer fusion on its contact partner")
	check(source_tile._surface.scale == Vector2.ONE and target_tile._surface.scale == Vector2.ONE,
		"Pointer fusion starts without stale held stretch or target squash")
	check(not view._tiles.values().has(root.gui_get_focus_owner()),
		"Pointer fusion does not request keyboard focus restoration")
	view._process(0.01)
	check(not view.game.fusion.is_empty() and _effect(view).start.is_equal_approx(target)
		and _center(view, pair[0]).distance_to(held_center) < view._pitch * 0.05,
		"A close drop retains its pointer anchor and continues the visible held lobe without snapping")
	view._process(0.10)
	check(_center(view, pair[0]).distance_to(_center(view, pair[1])) > view._pitch * 0.25,
		"Close drops express two elastic contact lobes before uniting")
	check(attempts.is_empty() and view._tiles[pair[0]].visible and view._tiles[pair[1]].visible,
		"The close-drop contact is presentation only and earns nothing early")
	for delta: float in [0.4, 0.4, 0.14]:
		view._process(delta)
	check(view.game.fusion.is_empty() and not view._tiles.values().has(root.gui_get_focus_owner()),
		"Completing a pointer fusion leaves the remaining board without a phantom focus contour")


func _check_off_center_drop_continuity(view) -> void:
	for turn: float in [0.0, 0.60, -0.60]:
		_reset(view)
		var pair: Array[int] = _pair(view)
		var source = view._tiles[pair[0]]
		var target = view._tiles[pair[1]]
		var source_home: Vector2 = _center(view, pair[0])
		var target_home: Vector2 = _center(view, pair[1])
		var grid_direction: Vector2 = (target_home - source_home).normalized()
		var drop: Vector2 = target_home + grid_direction.rotated(turn) * view._pitch * 0.18
		var cells: Array = view.game.cells.duplicate(true)
		view._press(2, source_home)
		view._move(drop)
		view._process(0.12)
		var contact: Dictionary = view._contact_state()
		var held_direction: Vector2 = contact.direction
		check(contact.kind == "match" and held_direction.dot(grid_direction) < -0.7,
			"An off-center drop approaches from the opposite side of the original grid direction")
		var source_surface: Vector2 = source._surface.get_global_rect().get_center()
		var target_surface: Vector2 = target._surface.get_global_rect().get_center()
		var source_control: Vector2 = source.get_global_rect().get_center()
		var target_control: Vector2 = target.get_global_rect().get_center()
		check(source_control.is_equal_approx(drop) and target_control.is_equal_approx(target_home),
			"Contact deformation preserves the pointer anchor and target hit rectangle before release")
		view._release(drop)
		check(not view.game.fusion.is_empty() and _effect(view).direction.is_equal_approx(held_direction),
			"Fusion inherits the actual approach direction rather than the source's former grid direction")
		check(source.get_global_rect().get_center().distance_to(source_surface) < view._pitch * 0.05
			and target.get_global_rect().get_center().distance_to(target_surface) < view._pitch * 0.05,
			"Both visible gel lobes continue across pointer release without switching sides or snapping")
		check(_effect(view).start.is_equal_approx(drop) and attempts.is_empty() and view.game.score() == 0,
			"Off-center continuity retains the real pointer origin and does not credit the answer early")
		for index in range(cells.size()):
			check(view.game.cells[index].column == cells[index].column and view.game.cells[index].row == cells[index].row,
				"Fusion contact offsets leave every board cell's logical position unchanged")
	_reset(view)


func _check_signal_reentry(view) -> void:
	_reset(view)
	var interrupt: Callable = func(cue: String) -> void:
		if cue == "merge":
			view.game.finish_round()
	view.audio_requested.connect(interrupt)
	var pair: Array[int] = _pair(view)
	_drag_pair(view, pair[0], pair[1])
	check(view.game.phase == "finished" and view.game.fusion.is_empty() and attempts.is_empty(),
		"A synchronous finish callback may cancel a just-started fusion without stale payload access or credit")
	view.audio_requested.disconnect(interrupt)
	_reset(view)
	var leave_on_word: Callable = func(_word: Dictionary) -> void: view.stop()
	view.word_requested.connect(leave_on_word)
	view._activate(_pair(view)[0])
	check(not view._configured and int(view.snapshot().drag.selected) == -1,
		"Leaving from a synchronous pronunciation callback cannot restore stale input ownership")
	view.word_requested.disconnect(leave_on_word)

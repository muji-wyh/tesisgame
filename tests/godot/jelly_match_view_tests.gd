extends SceneTree

const Jelly = preload("res://scripts/jelly_match.gd")
const Data = preload("res://scripts/game_data.gd")
const Motion = preload("res://scripts/jelly_motion.gd")

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
	_check_supply_preview(view)
	_check_preview_motion(view)
	_check_drop_projection(view)
	_check_landing_presentation(view)
	_check_landing_lifecycle(view)
	_check_gesture_audio(view)
	await _check_pointer_ownership(view)
	_check_pointer_feedback(view)
	_check_drag_replaces_selection(view)
	_check_keyboard_feedback(view)
	_check_feedback_lifecycle(view)
	_check_danger_clock(view)
	_check_danger_lifecycle(view)
	_check_danger_reduced_motion_and_end(view)
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


func _reset(view, reduced: bool = false, settled: bool = true) -> void:
	check(view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42), "Jelly Match configures with the current curriculum")
	view.set_process(false)
	if settled:
		view.game.step(view.game.SETTLE_SECONDS)
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


func _advance(view, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var delta: float = minf(0.1, remaining)
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
		for progress: float in [0.8, 0.9, 0.99]:
			for index in range(view._preview_tiles.size()):
				var tile = view._preview_tiles[index]
				var pose: Dictionary = Motion.preview(progress * view.game.spawn_interval, view.game.spawn_interval, index)
				var moving_rect := Rect2(view._preview_origins[index] + Vector2(pose.offset) * tile.size, tile.size)
				check(preview_rect.encloses(view._global_rect(moving_rect)),
					"%s contains preview %d at %d percent of its urgent wobble" % [dimensions, index + 1, roundi(progress * 100)])
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
			"Upcoming tile %d remains display-only for every input route" % (index + 1))
		check(not view._press(4, _rect(slot.rect).get_center()), "An upcoming tile cannot start a board drag")
		view._activate(int(slot.id))
	check(heard.is_empty() and cues.is_empty() and attempts.is_empty() and int(view.snapshot().drag.selected) == -1,
		"Preview interaction cannot pronounce, select, answer or consume a queued tile")
	for control: Control in view.navigation_controls():
		check(not control.get_global_rect().intersects(_rect(before.preview.rect)),
			"Keyboard navigation excludes the read-only supply preview")
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


func _preview_window(interval: float, start: float, finish: float) -> Dictionary:
	var energy: float = 0.0
	var samples: int = 0
	for index in range(4):
		for sample_index in range(41):
			var progress: float = lerpf(start, finish, float(sample_index) / 40.0)
			var pose: Dictionary = Motion.preview(progress * interval, interval, index)
			energy += Vector2(pose.offset).length_squared()
			samples += 1
	var first: Dictionary = Motion.preview(start * interval, interval, 0)
	var last: Dictionary = Motion.preview(finish * interval, interval, 0)
	return {"amplitude": sqrt(energy / samples), "speed": (float(last.beat) - float(first.beat)) / ((finish - start) * interval)}


func _check_preview_pose(view, reason: String) -> void:
	var slots: Array = view.snapshot().preview.slots
	for index in range(view._preview_tiles.size()):
		var tile = view._preview_tiles[index]
		var pose: Dictionary = Motion.preview(view.game.spawn_elapsed, view.game.spawn_interval, index, view.reduced_motion)
		check(tile.position.is_equal_approx(view._preview_origins[index] + Vector2(pose.offset) * tile.size)
			and tile._surface.scale.is_equal_approx(Vector2(pose.stretch))
			and is_equal_approx(float(tile._gel.get_shader_parameter("bend")), float(pose.bend)),
			"%s derives preview %d from the live model clock" % [reason, index + 1])
		check(tile._visual.scale == Vector2.ONE and tile._picture.scale == Vector2.ONE and tile._label.scale == Vector2.ONE,
			"%s keeps preview %d learning content readable while its gel wobbles" % [reason, index + 1])
		check(slots[index].has("motion") and is_equal_approx(float(slots[index].motion.intensity), float(pose.intensity))
			and _rect(slots[index].rect).is_equal_approx(tile.get_global_rect()),
			"%s publishes preview %d's real motion intensity and moving rectangle" % [reason, index + 1])


func _check_preview_motion(view) -> void:
	for interval: float in [view.game.INITIAL_SPAWN_INTERVAL, view.game.MIN_SPAWN_INTERVAL]:
		var early: Dictionary = _preview_window(interval, 0.05, 0.20)
		var middle: Dictionary = _preview_window(interval, 0.40, 0.55)
		var late: Dictionary = _preview_window(interval, 0.84, 0.99)
		check(float(middle.amplitude) > float(early.amplitude) * 1.5
			and float(late.amplitude) > float(middle.amplitude) * 1.5,
			"The %.2f-second supply beat grows from gentle motion to a stronger pre-drop wobble" % interval)
		check(float(middle.speed) > float(early.speed) * 1.2 and float(late.speed) > float(middle.speed) * 1.8,
			"The %.2f-second supply beat accelerates wobble frequency as dispatch approaches" % interval)
		var previous_intensity: float = 0.0
		for step in range(101):
			var elapsed: float = interval * float(step) / 100.0
			var pose: Dictionary = Motion.preview(elapsed, interval, 0)
			check(float(pose.intensity) >= previous_intensity and float(pose.intensity) <= 1.0
				and absf(Vector2(pose.offset).x) <= 0.0521 and absf(Vector2(pose.offset).y) <= 0.0209
				and Vector2(pose.stretch).y >= 0.9219 and Vector2(pose.stretch).y <= 1.0781,
				"Preview urgency grows inside a small readable motion envelope at %d percent" % step)
			previous_intensity = float(pose.intensity)
			var still: Dictionary = Motion.preview(elapsed, interval, step % 4, true)
			check(still.offset == Vector2.ZERO and still.stretch == Vector2.ONE
				and is_zero_approx(float(still.bend)) and is_zero_approx(float(still.intensity)),
				"Reduced motion has a neutral preview pose throughout the supply beat")
	_reset(view, false, false)
	var first: Array = view.snapshot().preview.slots.duplicate(true)
	_check_preview_pose(view, "A fresh batch")
	_advance(view, view.game.spawn_interval * 0.9)
	_check_preview_pose(view, "The late supply beat")
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
	check(view.snapshot().preview.slots == late_slots, "A hidden board cannot keep wobbling or advance its preview clock")
	var pair: Array[int] = _pair(view)
	view._activate(pair[0])
	view._activate(pair[1])
	_advance(view, 0.4)
	check(not view.game.fusion.is_empty() and view.snapshot().preview.slots == late_slots,
		"Fusion freezes the pending batch's urgent wobble with its supply clock")
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
	view.stop()
	check(not bool(view.snapshot().preview.visible), "Stopping removes the wobbling supply presentation")
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
	_advance(view, Motion.ready_at(cell) - float(cell.age) + 0.001)
	check(view._settled(cell) and not tile.disabled and tile._surface.scale.is_equal_approx(Vector2.ONE),
		"The visual body settles at the same boundary that enables input")
	var landed_before: int = cues.count("land")
	view._layout()
	view._sync_positions()
	view.apply_theme(Data.theme("spring"), data.chests)
	check(cues.count("land") == landed_before, "Layout, position and theme refreshes never replay an impact")


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
	_advance(view, Motion.ready_at(incoming[-1]) - float(incoming[-1].age) + 0.001)
	check(cues.count("land") == _landing_groups(incoming),
		"Resume completes the batch with one impact per simultaneous contact group")
	var landed_before: int = cues.count("land")
	_advance(view, 0.2)
	check(cues.count("land") == landed_before, "Recovered batch contacts do not repeat after settling")
	_reset(view, false, false)
	incoming = _arrivals(view)
	paused_cells = view.game.cells.duplicate(true)
	view.hide()
	_advance(view, Motion.ready_at(incoming[-1]) + 0.001)
	view.show()
	check(cues.is_empty() and view.game.cells == paused_cells, "A hidden board cannot advance any fall or emit landing feedback")
	_advance(view, Motion.ready_at(incoming[-1]) + 0.001)
	check(cues.count("land") == _landing_groups(incoming), "A replacement round owns fresh grouped contacts without the old cooldown")
	_reset(view, true, false)
	incoming = _arrivals(view)
	cell = incoming[0]
	var tile = view._tiles[int(cell.id)]
	check(tile.position == view._tile_rect(cell).position and tile._surface.scale == Vector2.ONE and not view._settled(cell),
		"Reduced motion presents a static body without skipping the input gate")
	_advance(view, Motion.ready_at(incoming[-1]) + 0.001)
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
	view._activate(pair[0])
	view._activate(pair[1])
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
	check(cues == ["pick"] and heard.size() == 1, "A tap reads its word and acknowledges selection exactly once")
	view.cancel_input()
	view._activate(id)
	check(cues.count("pick") == 2 and heard.size() == 2, "Keyboard selection shares the pointer's tactile feedback")
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
	view._release(_center(view, pair[0]))
	check(tile.selected and not view._tiles.values().has(root.gui_get_focus_owner()),
		"Pointer selection clears an earlier tile focus instead of creating a second selection cue")
	check(float(tile._gel.get_shader_parameter("rim_strength")) > 0.0 and tile._lift != null,
		"A pointer tap uses the gel contour and starts the selection lift")
	if tile._lift != null and tile._lift.is_valid():
		tile._lift.custom_step(0.12)
	check(tile._visual.position.y < 0.0, "A selected jelly visibly rises before a retap")
	view._press(2, _center(view, pair[0]))
	view._release(_center(view, pair[0]))
	_check_feedback_cleared(tile, "Retapping the selected jelly")
	check(int(view.snapshot().drag.selected) == -1 and not tile.has_focus(),
		"Retapping leaves neither logical selection nor pointer-created keyboard focus")
	view.finish_button.grab_focus()
	view._press(2, _center(view, pair[0]))
	check(view.finish_button.has_focus(), "Tile pointer input leaves the separately focused Finish control alone")
	view.cancel_input()
	view.finish_button.release_focus()


func _check_drag_replaces_selection(view) -> void:
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
	check(source._gel.get_shader_parameter("rim_color") != target._gel.get_shader_parameter("rim_color")
		and target._surface.scale != Vector2.ONE,
		"The contact partner uses its own warm contour and soft surface response")
	view.cancel_input()
	_check_feedback_cleared(source, "Cancelling the dragged source")
	_check_feedback_cleared(target, "Cancelling the prospective partner")
	check(source._surface.scale == Vector2.ONE and target._surface.scale == Vector2.ONE,
		"Cancellation clears contact squash without waiting for the next frame")


func _check_keyboard_feedback(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	var first = view._tiles[pair[0]]
	var second = view._tiles[pair[1]]
	first.grab_focus()
	var focus_strength: float = float(first._gel.get_shader_parameter("rim_strength"))
	var focus_width: float = float(first._gel.get_shader_parameter("rim_width"))
	check(first.has_focus() and not first.selected and focus_strength > 0.0
		and first._visual.position.is_zero_approx() and _lift_stopped(first),
		"Keyboard focus is visible without selecting or lifting a jelly")
	first.pressed.emit()
	check(first.selected and float(first._gel.get_shader_parameter("rim_strength")) > focus_strength
		and float(first._gel.get_shader_parameter("rim_width")) > focus_width,
		"Keyboard confirmation strengthens the contour separately from focus")
	if first._lift != null and first._lift.is_valid():
		first._lift.custom_step(0.12)
	second.grab_focus()
	check(first.selected and not first.has_focus() and second.has_focus() and not second.selected
		and is_equal_approx(float(second._gel.get_shader_parameter("rim_strength")), focus_strength),
		"Moving keyboard focus preserves the chosen jelly and gives its partner only a focus cue")
	second.pressed.emit()
	check(not view.game.fusion.is_empty() and view._focus_after_fusion,
		"Keyboard matching remembers to restore navigation after fusion")
	_check_feedback_cleared(first, "Starting keyboard fusion on its first frame")
	_check_feedback_cleared(second, "Starting keyboard fusion on its focused partner")
	for delta: float in [0.4, 0.4, 0.25]:
		view._process(delta)
	var focused = root.gui_get_focus_owner()
	check(view._tiles.values().has(focused) and not view._focus_after_fusion,
		"Completed keyboard fusion restores focus to a remaining playable jelly")
	if view._tiles.values().has(focused):
		check(not focused.selected and float(focused._gel.get_shader_parameter("rim_strength")) > 0.0
			and focused._visual.position.is_zero_approx() and _lift_stopped(focused),
			"Restored navigation has a focus contour without a stale selection or lift")


func _check_feedback_lifecycle(view) -> void:
	_reset(view)
	var pair: Array[int] = _pair(view)
	var tile = view._tiles[pair[0]]
	tile.grab_focus()
	tile.pressed.emit()
	if tile._lift != null and tile._lift.is_valid():
		tile._lift.custom_step(0.12)
	view.set_reduced_motion(true)
	check(tile.selected and int(view.snapshot().drag.selected) == pair[0]
		and float(tile._gel.get_shader_parameter("rim_strength")) > 0.0,
		"Enabling reduced motion preserves the player's chosen jelly and static contour")
	check(tile._visual.position.is_zero_approx() and _lift_stopped(tile),
		"Enabling reduced motion immediately ends an in-flight lift")
	view.cancel_input()
	check(not tile.selected and tile.has_focus() and float(tile._gel.get_shader_parameter("rim_strength")) > 0.0
		and tile._visual.position.is_zero_approx(),
		"Cancelling keyboard selection preserves only its independent focus cue")
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
	view._activate(first)
	view._activate(other)
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
	view._activate(pair[0])
	view._activate(pair[1])
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
	view._release(target)
	_check_feedback_cleared(source_tile, "Starting pointer fusion on its first frame")
	_check_feedback_cleared(target_tile, "Starting pointer fusion on its contact partner")
	check(source_tile._surface.scale == Vector2.ONE and target_tile._surface.scale == Vector2.ONE,
		"Pointer fusion starts without stale held stretch or target squash")
	check(not view._focus_after_fusion and not view._tiles.values().has(root.gui_get_focus_owner()),
		"Pointer fusion does not request keyboard focus restoration")
	view._process(0.01)
	check(not view.game.fusion.is_empty() and _center(view, pair[0]).distance_to(target) < view._pitch * 0.05,
		"A center-to-center drop begins at its actual dropped position")
	view._process(0.10)
	check(_center(view, pair[0]).distance_to(_center(view, pair[1])) > view._pitch * 0.25,
		"Close drops express two elastic contact lobes before uniting")
	check(attempts.is_empty() and view._tiles[pair[0]].visible and view._tiles[pair[1]].visible,
		"The close-drop contact is presentation only and earns nothing early")
	for delta: float in [0.4, 0.4, 0.14]:
		view._process(delta)
	check(view.game.fusion.is_empty() and not view._tiles.values().has(root.gui_get_focus_owner()),
		"Completing a pointer fusion leaves the remaining board without a phantom focus contour")


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

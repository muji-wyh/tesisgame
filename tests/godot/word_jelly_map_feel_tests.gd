extends "res://tests/godot/word_jelly_map_tests.gd"

const OUTPUT: String = "res://build/qa/jelly-map-feel"


func _motion(point: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = mask
	root.push_input(event)
	await process_frame


func _save(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK,
		"Retain the actual map presentation: " + name)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	_holder = Control.new()
	root.add_child(_holder)
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view = load(MAP_PATH).new()
	_holder.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stage_selected.connect(func(number: int) -> void: _stage_events.append(number))
	await _settle()
	var state: Dictionary = _state(24)
	state["pip_age"] = 3
	view.open(state, false)
	await _settle()
	var opening: Dictionary = view.snapshot()
	check(opening.has_all(["guide", "presentation"]),
		"The live map exposes a real Pip guide and owned presentation state")
	if not opening.has_all(["guide", "presentation"]):
		_holder.free()
		_finish()
		return
	view.set_process(false)
	view._process(0.65)
	var item: Dictionary = view._nodes[24]
	var controls: Array = _geometry(view)
	check(view._pip.mouse_filter == Control.MOUSE_FILTER_IGNORE and view._pip.focus_mode == Control.FOCUS_NONE
		and view._pip.disabled and not view.navigation_controls().has(view._pip),
		"Pip is sourced, input-transparent presentation rather than another stage or focus target")
	check(view.snapshot().guide.visible and view.snapshot().guide.stage == 25 and view._pip.growth_age == 3,
		"The acquired guide marks the actual frontier and follows the supplied earned age")
	check(view._scroll.get_global_rect().encloses(view._pip.get_global_rect())
		and view._pip.rest_snapshot().pose == "resting-on-stage"
		and view._pip.rest_snapshot().support[1] < item.label.get_global_rect().position.y,
		"Pip rests on the medallion rim while the number, stars and original native target stay clear")
	check(view.snapshot().presentation.completed_edges == 5 and item.halo.visible,
		"Earned route color and the current node's local light have real progress ownership")
	var saved: Dictionary = state.duplicate(true)
	var replay: Dictionary = view._nodes[23]
	item.button.release_focus()
	await _motion(replay.button.get_global_rect().get_center())
	view._process(0.18)
	check(replay.face.scale.x > 1.02 and replay.face.position.y < replay.face_rest.y
		and replay.halo.visible and view.snapshot().presentation.hovered_stage == 24,
		"A genuine replay-node hover lifts its acquired medallion and adds one local acknowledgement")
	check(_geometry(view) == controls and state == saved and _stage_events.is_empty(),
		"Hover changes only painted material, not any hit rectangle, saved value or stage selection")
	await _save("hover-1366x768")
	var point: Vector2 = replay.button.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = point
	press.global_position = point
	root.push_input(press)
	await process_frame
	view._process(0.04)
	check(view.snapshot().presentation.pressed_stage == 24 and replay.face.scale.x < 1.0,
		"The actual scroll-owned press seats the medallion instead of waiting for a later click")
	await _save("press-1366x768")
	press.pressed = false
	press.button_mask = 0
	root.push_input(press)
	await process_frame
	view._process(0.20)
	check(_stage_events == [24] and view.snapshot().presentation.pressed_stage == 0,
		"Release enters exactly the real selected stage and leaves no stuck press")
	view.focus_frontier()
	view._process(0.2)
	var section: Dictionary = view._chapters[view._chapter_index]
	var tree_rotation: float = section.grove.rotation
	var effect_age: float = view.snapshot().presentation.elapsed
	controls = _geometry(view)
	view._process(0.2)
	check(not is_equal_approx(section.grove.rotation, tree_rotation)
		and view.snapshot().presentation.elapsed > effect_age and _geometry(view) == controls,
		"Grounded scenery has gentle owned motion while stage inputs stay planted: %s" %
			str([tree_rotation, section.grove.rotation, effect_age, view.snapshot().presentation.elapsed]))
	var pip_clock: float = view._pip._idle_time
	effect_age = view.snapshot().presentation.elapsed
	view.configure(state, false)
	check(view._pip._idle_time == pip_clock and view.snapshot().presentation.elapsed == effect_age,
		"An ordinary wallet/status configure does not restart Pip or the map's quiet atmosphere")
	view.set_active(false)
	var frozen: Dictionary = view.snapshot().presentation
	view._process(10.0)
	check(view.snapshot().presentation == frozen and not view._pip.is_processing(),
		"Backgrounding freezes the complete map and its guide without catch-up motion")
	view.set_active(true)
	view._scroll.scroll_vertical = roundi(view._scroll.get_v_scroll_bar().max_value)
	await _settle()
	check(not view.snapshot().guide.visible and not view._pip.is_processing(),
		"A clipped-offscreen guide stops its existing idle rather than animating below the map viewport")
	view.focus_frontier()
	await _settle()
	view._pip.react("happy")
	check(view._pip.reaction_left > 0.0, "Switch reduced motion during a real, still-live guide reaction")
	view.set_reduced_motion(true)
	view.set_process(false)
	var geometry: Array = _geometry(view)
	var steady: Array = _poses(view)
	frozen = view.snapshot().presentation
	view._process(5.0)
	check(view.snapshot().presentation == frozen and _poses(view) == steady
		and _geometry(view) == geometry and not view._pip.is_processing(),
		"Reduced motion retains the guide and current-stage meaning with no animated scenery or effects")
	check(view.show_chapter(4), "Browse the next real chapter")
	await _settle()
	check(not view.snapshot().guide.visible and view.snapshot().presentation.completed_edges == 0,
		"A future chapter cannot display a false current Pip, earned road or success light")
	check(view.show_chapter(3), "Return to the earned frontier chapter")
	await _settle()
	check(view.snapshot().guide.visible, "Returning restores the resting guide only on the true frontier")
	var alternate: Dictionary = state.duplicate(true)
	alternate.pip_age = 8
	view.configure(alternate, true)
	check(view._pip.growth_age == 8 and view.snapshot().guide.age == 8,
		"Refreshing appearance uses the real earned age, not a hard-coded Baby Pip")
	alternate.pip_profile = {"course_id": "retail", "level": 4}
	view.configure(alternate, true)
	check(view.snapshot().guide.course_id == "retail" and view._pip.professional_profile.level == 4,
		"A supplied professional appearance uses the existing real career wardrobe")
	view.configure(state, true)
	check(view.snapshot().guide.course_id.is_empty() and view._pip.growth_age == 3,
		"Returning to the growth scope removes the former professional wardrobe")
	for dimensions: Vector2i in SIZES:
		await _resize(dimensions)
		view.open(state, true)
		await _settle()
		check(view._scroll.get_global_rect().grow(0.5).encloses(view._pip.get_global_rect())
			and view._pip.rest_snapshot().support[1] < item.label.get_global_rect().position.y,
			"Resting guide, stage and input remain legible on " + str(dimensions))
		await _save("frontier-%dx%d" % [dimensions.x, dimensions.y])
	for dimensions: Vector2i in [SIZES[1], SIZES[3]]:
		await _resize(dimensions)
		for number in range(1, 100):
			view.open(_state(number - 1), true)
			await _settle(2)
			check(view.snapshot().guide.visible and view.snapshot().guide.stage == number
				and view._scroll.get_global_rect().grow(0.5).encloses(view._pip.get_global_rect())
				and view._pip.rest_snapshot().support[1] < view._nodes[number - 1].label.get_global_rect().position.y,
				"Every real frontier keeps its guide legible and input-transparent: stage %d at %s; %s" %
					[number, str(dimensions), str([view._scroll.get_global_rect(),
						view._pip.get_global_rect(), view._nodes[number - 1].button.get_global_rect()])])
	view.close()
	check(not view.snapshot().guide.visible and _processing(view).is_empty(),
		"Closing removes the companion and every decorative frame owner")
	_holder.free()
	_finish()

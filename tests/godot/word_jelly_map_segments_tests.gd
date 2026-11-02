extends "res://tests/godot/word_jelly_map_tests.gd"


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = SIZES[0]
	_holder = Control.new()
	root.add_child(_holder)
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view = load(MAP_PATH).new()
	_holder.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stage_selected.connect(func(number: int) -> void: _stage_events.append(number))
	await _settle()
	var source: Dictionary = _state(12)
	source["boss_markers"] = view.BossCatalog.map_markers(13)
	var original: Dictionary = source.duplicate(true)
	view.open(source, true)
	await _settle()
	var state: Dictionary = view.snapshot()
	check(state.get("layout") == "continuous" and state.has("chapters"),
		"Chapters are scenic sections on one real route, not pages of nine stages")
	if state.get("layout") != "continuous" or not state.has("chapters"):
		_holder.free()
		_finish()
		return
	check(not state.has("chapter_previous") and not state.has("chapter_next") and not state.has("segment"),
		"The live map exposes no page buttons or selected-page contract")
	check(state.stage_nodes.size() == 99 and state.chapters.size() == 11
		and view._content.custom_minimum_size.y * _pixel_scale() > 12000.0,
		"All 99 stages and eleven authored chapter landmarks share one continuous content surface")
	check(root.gui_get_focus_owner() == _stage_button(view, 13) and _stage(state, 13).visible,
		"Opening still brings the real earned frontier into view")
	view._nodes[0].button.pressed.emit()
	check(_stage_events.is_empty(), "An offscreen cleared-stage signal cannot enter an unseen stage")
	var scroll: ScrollContainer = view._scroll
	for boundary in range(9, 99, 9):
		var before: Vector2 = view._nodes[boundary - 1].button.position
		var after: Vector2 = view._nodes[boundary].button.position
		scroll.scroll_vertical = roundi((before.y + after.y + view._nodes[boundary].button.size.y) * 0.5
			- scroll.size.y * 0.5)
		await _settle()
		state = view.snapshot()
		check(_stage(state, boundary).visible and _stage(state, boundary + 1).visible,
			"Stages %d and %d coexist across their chapter boundary without a page transition" %
				[boundary, boundary + 1])
		check(view._nodes[boundary - 1].button.position == before
			and view._nodes[boundary].button.position == after,
			"Crossing a chapter changes only the scroll offset, never the world positions")
		check(state.chapters[boundary / 9].visible,
			"The next chapter's real title landmark is visible between its neighboring stages")
		for section: Dictionary in view._chapters:
			for item: Dictionary in view._nodes:
				if item.boss.visible:
					check(not section.banner.get_rect().intersects(item.boss.get_rect()),
						"A chapter title never sits behind a real Bramble portrait")
		if boundary == 9:
			await _capture("continuous-boundary-9-10-%dx%d" % [root.size.x, root.size.y])
	var point: Vector2 = scroll.get_global_rect().get_center()
	var offset: int = scroll.scroll_vertical
	await _touch(point, true)
	await _touch_move(point + Vector2(0, 100))
	await _touch(point + Vector2(0, 100), false)
	scroll.cancel_drag()
	check(scroll.scroll_vertical != offset and _stage_events.is_empty(),
		"A real swipe travels through the same map without selecting a stage")
	check(source == original, "Continuous travel does not change supplied coins, ratings or progress")
	check(view.show_chapter(11), "The existing chapter helper scrolls to the summit section")
	await _settle()
	check(view.snapshot().chapter.index == 11 and not view.snapshot().guide.visible,
		"Inspecting a future section cannot move Pip away from the actual frontier")
	var position: int = scroll.scroll_vertical
	var refreshed: Dictionary = original.duplicate(true)
	refreshed.coins = 3280
	view.configure(refreshed, true)
	await _settle()
	check(scroll.scroll_vertical == position,
		"A wallet/status refresh preserves the actual browsed offset instead of selecting a page")
	view.focus_frontier()
	await _settle()
	check(view.snapshot().chapter.index == 2 and _stage(view.snapshot(), 13).visible,
		"Frontier navigation returns through the continuous map to the real next stage")
	view.open(_state(8), false)
	await _settle()
	view.configure(_state(9), false)
	await _settle()
	check(view.snapshot().unlock.from == 9 and view.snapshot().unlock.to == 10
		and view._nodes[9].button.position.y < view._nodes[8].button.position.y,
		"A genuine chapter clear keeps the real adjacent-world unlock event")
	check(view.show_chapter(3), "The player can scroll elsewhere during decorative unlock motion")
	view._process(view.ROUTE_SECONDS + view.UNLOCK_SECONDS + 0.1)
	check(view.show_chapter(2) and not _stage(view.snapshot(), 10).lock_visible,
		"Returning after an offscreen unlock shows the real earned padlock state")
	var context: Dictionary = _state(9)
	context.context_key = "professional:another:module"
	view.configure(context, false)
	check(view.snapshot().unlock.phase == "done",
		"Changing learning scope cannot inherit another context's unlock performance")
	var blocked: Dictionary = _state(9)
	blocked.loading = true
	blocked.pending_stage = 10
	view.configure(blocked, true)
	check(not view.show_chapter(3), "An actual pending load retains navigation ownership")
	blocked.loading = false
	blocked.error = "Stage progress could not be loaded."
	view.configure(blocked, true)
	check(not view.show_chapter(3) and view.snapshot().retry.enabled,
		"A real loading error retains its retry rather than reporting a successful new section")
	view.open(original, true)
	await _settle()
	for dimensions: Vector2i in SIZES:
		await _resize(dimensions)
		scroll.scroll_vertical = roundi((view._nodes[8].button.position.y + view._nodes[9].button.position.y
			+ view._nodes[9].button.size.y) * 0.5 - scroll.size.y * 0.5)
		await _settle()
		await _capture("continuous-boundary-9-10-%dx%d" % [dimensions.x, dimensions.y])
		for chapter in [1, 2, 11]:
			check(view.show_chapter(chapter), "Responsive chapter inspection remains a scroll operation")
			await _settle()
			check(view._nodes.all(func(item: Dictionary) -> bool: return item.button.is_visible_in_tree()),
				"Every stage remains part of the continuous native scene at every viewport size")
			_check_layout(view, "Continuous chapter %d at %s" % [chapter, dimensions])
	view.close()
	check(not view.show_chapter(1) and view.navigation_controls().is_empty(),
		"A closed map cannot react to an abandoned navigation request")
	_holder.free()
	_finish()

extends "res://tests/godot/word_jelly_map_tests.gd"


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
	var source: Dictionary = _state(12)
	var original: Dictionary = source.duplicate(true)
	view.open(source, true)
	await _settle()
	check(view.has_method("show_chapter") and view.snapshot().has("segment"),
		"The journey has an explicit chapter segment instead of one 99-stage scroll")
	if not view.has_method("show_chapter") or not view.snapshot().has("segment"):
		_holder.free()
		_finish()
		return
	var state: Dictionary = view.snapshot()
	check(state.segment.index == 2 and state.segment.count == 11
		and state.segment.first_stage == 10 and state.segment.last_stage == 18,
		"Opening follows the earned frontier to its real nine-stage chapter")
	check(state.stage_nodes.size() == 99 and state.stage_nodes.filter(func(item: Dictionary) -> bool:
		return item.in_segment).size() == 9,
		"All original stage identities remain readable but only one segment is presented")
	check(view.get("_content").custom_minimum_size.y * _pixel_scale() < 1500.0,
		"The real content contains one chapter, not the original thirteen-thousand-pixel route")
	check(root.gui_get_focus_owner() == _stage_button(view, 13),
		"The next unlocked stage is focused inside the selected segment")
	view.get("_nodes")[0].button.pressed.emit()
	check(_stage_events.is_empty(), "A hidden cleared-stage signal cannot activate another chapter")
	await _click(_action_button(view, "chapter_previous"))
	state = view.snapshot()
	check(state.segment.index == 1 and not state.chapter_previous.enabled
		and state.chapter_next.enabled,
		"A real previous-chapter press exposes the first segment and its boundary")
	check(source == original and view.get("_state").best_stars == original.best_stars,
		"Browsing a chapter never changes supplied progress, stars or coins")
	await _click(_action_button(view, "chapter_next"))
	check(view.snapshot().segment.index == 2, "A real next-chapter press returns to the second segment")
	check(view.show_chapter(11), "Future chapters can be inspected without unlocking their stages")
	await _settle()
	state = view.snapshot()
	check(state.segment.first_stage == 91 and state.segment.last_stage == 99
		and not state.chapter_next.enabled and state.chapter_previous.enabled,
		"The last segment ends at the actual ninety-ninth stage, without a phantom next chapter")
	check(not _stage(state, 99).unlocked and _stage(state, 99).boss
		and view.get("_nodes")[98].boss.is_visible_in_tree(),
		"The final medallion remains a real visible locked Boss in its own segment")
	view.get("_nodes")[98].boss.pressed.emit()
	check(_stage_events.is_empty(), "Browsing the summit cannot bypass its saved Boss-stage lock")
	var refreshed: Dictionary = original.duplicate(true)
	refreshed.coins = 3280
	view.configure(refreshed, true)
	check(view.snapshot().segment.index == 11, "A wallet/status refresh cannot reset the chosen chapter")
	view.focus_frontier()
	await _settle()
	check(view.snapshot().segment.index == 2 and root.gui_get_focus_owner() == _stage_button(view, 13),
		"The current-progress helper returns from any chapter to the real frontier")
	view.open(_state(8), false)
	await _settle()
	view.configure(_state(9), false)
	await _settle()
	check(view.snapshot().segment.index == 2 and view.snapshot().unlock.from == 9
		and view.snapshot().unlock.to == 10,
		"Clearing a chapter finale opens the next segment with the same genuine unlock event")
	check(view.show_chapter(3), "The player may browse during a decorative unlock, not a pending purchase")
	view._process(view.ROUTE_SECONDS + view.UNLOCK_SECONDS + 0.1)
	check(view.show_chapter(2) and not _stage(view.snapshot(), 10).lock_visible,
		"Returning after an off-segment unlock cannot show a stale padlock on an earned stage")
	var new_context: Dictionary = _state(9)
	new_context.context_key = "professional:another:module"
	view.configure(new_context, false)
	check(view.snapshot().unlock.phase == "done" and view.snapshot().segment.index == 2,
		"Changing learning context cannot carry over another scope's unlock performance")
	var blocked: Dictionary = _state(9)
	blocked.loading = true
	blocked.pending_stage = 10
	view.configure(blocked, true)
	check(not view.show_chapter(3) and not view.snapshot().chapter_previous.enabled
		and not view.snapshot().chapter_next.enabled,
		"A pending stage owns navigation until its actual load finishes")
	blocked.loading = false
	blocked.error = "Stage progress could not be loaded."
	view.configure(blocked, true)
	check(not view.show_chapter(3) and view.snapshot().retry.enabled,
		"A genuine load error retains its retry instead of navigating into a success-shaped page")
	view.open(original, true)
	await _settle()
	for dimensions: Vector2i in SIZES:
		await _resize(dimensions)
		for chapter in [1, 2, 11]:
			check(view.show_chapter(chapter), "Responsive chapter selection remains available")
			await _settle()
			state = view.snapshot()
			var bounds: Rect2 = view.get_global_rect()
			for key: String in ["chapter_previous", "chapter_next"]:
				var button: BaseButton = _action_button(view, key)
				check(button != null and bounds.grow(0.2).encloses(button.get_global_rect())
					and button.size.x * _pixel_scale() >= 44.0 and button.size.y * _pixel_scale() >= 44.0,
					"Each chapter control stays onscreen with a real forty-four-pixel target")
			check(state.stage_nodes.filter(func(item: Dictionary) -> bool: return item.in_segment).size() == 9,
				"Resize never reintroduces another chapter's stage bodies")
			for item: Dictionary in state.stage_nodes:
				if not item.in_segment:
					check(not item.visible and not view.get("_nodes")[int(item.number) - 1].button.is_visible_in_tree(),
						"Every off-segment stage remains inert, not just visually scrolled away")
			_check_layout(view, "Segment %d at %s" % [chapter, dimensions])
	view.close()
	check(not view.show_chapter(1) and view.navigation_controls().is_empty(),
		"A closed map cannot retain chapter navigation or react to an abandoned press")
	_holder.free()
	_finish()

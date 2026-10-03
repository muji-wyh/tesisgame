extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const State = preload("res://scripts/pop_reward_state.gd")
const Room = preload("res://scripts/pop_reward_room.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const Style = preload("res://scripts/ui_style.gd")

class Storage extends RefCounted:
	var text: Variant = null
	var readable: bool = true
	var writable: bool = true
	var writes: int = 0

	func popRewardState() -> Variant:
		return text if readable else false

	func savePopRewardState(value: String) -> bool:
		if not writable:
			return false
		text = value
		writes += 1
		return true

var checks: int = 0
var failures: int = 0
var _manifest: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.size = Vector2i(960, 720)
	var data := Data.new()
	check(data.load_all(), "Load the shared chest artwork for the reward room")
	_manifest = data.chests
	_state_checks()
	await _room_checks()
	await _retained_rewards_checks()
	await _failure_checks()
	await _responsive_resize_checks()
	await _deferred_layout_checks()
	print("Pop treasure room: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _state_checks() -> void:
	var storage := Storage.new()
	var state := State.new("user://unused-pop-test.cfg", storage)
	check(state.load_state() and not state.has_pending(), "Missing storage begins without invented treasure")
	check(not state.create_batch("zero", []), "Zero chances cannot create a chest")
	check(not state.create_batch("duplicate", ["spring", "spring"]), "Duplicate styles cannot form a batch")
	check(state.create_batch("one", ["spring", "summer", "winter"]), "Create a durable three-chest batch")
	check(state.entries.size() == 3 and state.has_pending(), "All three earned chances begin unopened")
	var initial_writes: int = storage.writes
	check(state.create_batch("one", ["autumn"]) and state.entries.size() == 3 and storage.writes == initial_writes,
		"Reconfiguring the same round cannot reroll or resize its chest set")
	check(not state.create_batch("two", ["space"]), "An unfinished batch cannot be overwritten")
	check(state.mark_opened("one", 1), "Opening writes the selected chest")
	check(state.mark_opened("one", 1) and storage.writes == initial_writes + 1,
		"Duplicate completion callbacks never write or award twice")
	check(state.last_open_was_duplicate, "A duplicate durable receipt is reported to suppress repeat surprises")
	check(not state.mark_opened("other", 0), "A stale round cannot consume the current reward")
	storage.writable = false
	check(not state.mark_opened("one", 0) and not state.entries[0].opened,
		"A failed save leaves durable reward state retryable")
	storage.writable = true
	check(state.mark_opened("one", 0) and state.mark_opened("one", 2) and not state.has_pending(),
		"Opening every chest records the completed batch")
	check(state.create_batch("two", ["space"]), "A completed batch permits another played round")
	check(state.mark_opened("two", 0), "Finish the subsequent batch")
	check(not state.create_batch("one", ["spring"]), "A completed old round receipt prevents replay")
	var reloaded := State.new("user://unused-pop-test.cfg", storage)
	check(reloaded.load_state() and reloaded.round_id == "two" and reloaded.entries[0].opened,
		"Reload preserves both chest selection and opened state")
	storage.readable = false
	check(not reloaded.load_state() and not reloaded.ready, "Unavailable reads do not fabricate a fresh save")
	storage.readable = true
	storage.text = "[treasure]\nversion=1\nround_id=\"bad\"\nentries=[{\"theme\":\"spring\",\"opened\":\"yes\"}]\nreceipts=[]\n"
	check(not reloaded.load_state(), "Malformed opened flags cannot overwrite durable state")
	for theme_id in Data.THEMES:
		var selected: Array[String] = Room._choose_themes("style-check", 3, str(theme_id))
		check(selected.size() == 3 and selected[0] == theme_id, "The active theme receives the first earned chest")
		var styles: Array[String] = []
		for selected_id in selected:
			styles.append(str(Data.THEMES[selected_id].chest))
		check(styles[0] != styles[1] and styles[0] != styles[2] and styles[1] != styles[2],
			"Each simultaneous chest has different physical artwork")
		check(selected == Room._choose_themes("style-check", 3, str(theme_id)),
			"A saved round always selects the same chest styles")


func _make_room(storage: Storage):
	var room := Room.new()
	root.add_child(room)
	room.size = Vector2(880, 640)
	room.connect_storage(storage)
	room.set_process(false)
	return room


func _hold(room, index: int, seconds: float) -> void:
	room.begin_hold(room._cards[index].button)
	room.advance_hold(seconds)


func _room_checks() -> void:
	var storage := Storage.new()
	var room = _make_room(storage)
	check(room.configure("room-one", 3, "spring", _manifest, false), "Configure the reusable three-chest room")
	var reward_audio: Array[String] = []
	room.chest_audio_requested.connect(func(action: String, theme_id: String, _progress: float) -> void:
		if action == "reward":
			reward_audio.append(theme_id))
	check(room.snapshot().chest_count == 3 and room.navigation_controls().size() == 4,
		"All three chests and the exit action appear simultaneously")
	for width in [880, 480, 390]:
		room.size = Vector2(width, 640)
		room._layout()
		for frame in range(4):
			await process_frame
		for index in range(3):
			var card: Dictionary = room._cards[index]
			var button: Control = room._cards[index].button
			check(button.size.x * Style.ui_scale(room) >= 44 and button.size.y * Style.ui_scale(room) >= 44,
				"Every desktop and portrait chest has a full touch target")
			check(Rect2(Vector2.ZERO, room._content.size).encloses(card.panel.get_rect()),
				"All earned chests belong to the same scrollable treasure stage: room=%s, viewport=%s, content=%s, card=%s, scale=%s" % [
					room.size, room._scroll.size, room._content.size, card.panel.get_rect(), Style.ui_scale(room)])
			check(card.art.size.x * Style.ui_scale(room) >= 220
				and card.art.size.y * Style.ui_scale(room) >= 260,
				"Desktop and portrait rewards keep the chest artwork large instead of shrinking the full batch")
			check(button.tooltip_text.is_empty() and not button.accessibility_name.is_empty(),
				"Artwork-only chests retain accessible instructions without visual tooltips")
			check(not card.has("heading") and not card.has("caption"),
				"Treasure cards reserve their space for artwork without title or hold labels")
		check(room.snapshot().scroll_max > 0,
			"A large three-chest batch can scroll instead of compressing every reward into the viewport")
	room.size = Vector2(820, 250)
	room._layout()
	for frame in range(4):
		await process_frame
	for card in room._cards:
		check(card.art.size.x * Style.ui_scale(room) >= 220
			and card.art.size.y * Style.ui_scale(room) >= 190,
			"A short landscape room preserves large chest art and allows vertical scrolling")
		check(card.button.size.y * Style.ui_scale(room) >= 44,
			"Landscape rewards preserve the minimum touch target")
	room.size = Vector2(640, 230) / Style.ui_scale(room)
	room._layout()
	for frame in range(4):
		await process_frame
	for index in range(room._cards.size()):
		var card: Dictionary = room._cards[index]
		check(card.button.size.y * Style.ui_scale(room) >= 44,
			"Narrow landscape rewards preserve the minimum touch target")
		for other_index in range(index + 1, room._cards.size()):
			check(not card.button.get_global_rect().intersects(room._cards[other_index].button.get_global_rect()),
				"Scrollable landscape chest touch targets remain separate")
	room.size = Vector2(390, 640)
	room._layout()
	_hold(room, 0, 0.4)
	room.begin_hold(room._cards[1].button)
	check(room.snapshot().active == 0 and room._cards[1].art.hold_progress == 0.0,
		"A second finger cannot begin another chest while one is held")
	room.end_hold()
	check(room.snapshot().active == -1 and room._cards[0].art.mode == "closed" and storage.writes == 1,
		"Releasing a short hold leaves its chance unspent")
	_hold(room, 0, Feel.HOLD_SECONDS)
	room._cards[0].art._advance_animation(Feel.ANTICIPATION_TIME)
	room.end_hold()
	check(not room.snapshot().opening and not room._cards[0].opened and room._cards[0].art.mode == "closed",
		"Releasing during buildup cancels before mechanical release")
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	room._finished(0)
	check(reward_audio.is_empty() and storage.writes == 1, "Cancelled and stale callbacks cannot reveal a reward")
	_hold(room, 0, Feel.HOLD_SECONDS)
	room._cards[0].art._advance_animation(Feel.RELEASE_TIME + 0.01)
	check(room.snapshot().opened_count == 1 and storage.writes == 2,
		"Mechanical release persists exactly one opened chest immediately")
	room.end_hold()
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	room._finished(0)
	check(reward_audio.size() == 1 and storage.writes == 2,
		"Letting go after release completes one surprise without duplicating the save")
	check(room._cards[0].art.hold_effect_snapshot().surprise.play_count == 1,
		"The room uses the shared chest surprise effect")
	check(room.configure("room-one", 3, "space", _manifest, false) and room.snapshot().opened_count == 1,
		"Reentering the same round preserves opened chests")
	_hold(room, 1, Feel.HOLD_SECONDS)
	room.pause()
	check(room._cards[1].art.mode == "closed" and not room._cards[1].opened,
		"Backgrounding an uncommitted opening returns the unspent chest")
	room.resume()
	_hold(room, 1, Feel.HOLD_SECONDS)
	room._cards[1].art._advance_animation(Feel.RELEASE_TIME + 0.01)
	room.pause()
	check(room._cards[1].art.mode == "opened" and room.snapshot().opened_count == 2 and reward_audio.size() == 1,
		"Backgrounding after release settles the saved chest silently")
	room.resume()
	check(reward_audio.size() == 1 and room._cards[1].art.hold_effect_snapshot().surprise.play_count == 0,
		"Resuming does not replay a silently settled surprise")
	room.set_reduced_motion(true)
	_hold(room, 2, Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 3 and not room.has_pending() and reward_audio.size() == 2,
		"Reduced motion keeps the hold confirmation and opens the final chest once")
	check(storage.writes == 4, "Three rewards require one batch write and one durable write per chest")
	room.queue_free()
	await process_frame
	var restored = _make_room(storage)
	check(restored.configure_saved(_manifest, false) and restored.snapshot().opened_count == 3,
		"A fresh room restores every opened chest after a reload")
	check(not restored.has_pending() and restored.navigation_controls().size() == 1,
		"Restored opened chests cannot be activated again")
	for card in restored._cards:
		check(card.art.mode == "opened" and card.art.hold_effect_snapshot().surprise.play_count == 0,
			"Restoring durable state never replays the chest animation or surprise")
	restored.queue_free()
	await process_frame


func _retained_rewards_checks() -> void:
	var storage := Storage.new()
	var room = _make_room(storage)
	check(room.configure("retained-rewards", 3, "ocean", _manifest, false),
		"Prepare three earned chances for simultaneous persistent gifts")
	var reward_audio: Array[String] = []
	room.chest_audio_requested.connect(func(action: String, theme_id: String, _progress: float) -> void:
		if action == "reward":
			reward_audio.append(theme_id))
	var gifts: Array[Dictionary] = []
	for index in range(3):
		if index == 2:
			room.set_reduced_motion(true)
		_hold(room, index, Feel.HOLD_SECONDS)
		room._cards[index].art._advance_animation(Feel.OPEN_SECONDS)
		room._cards[index].art._advance_animation(0.2)
		var flying: Dictionary = room._cards[index].art.hold_effect_snapshot().surprise
		room.pause()
		room._cards[index].art._advance_animation(60.0)
		check(flying.active and room._cards[index].art.hold_effect_snapshot().surprise == flying,
			"Pausing preserves the current gift and freezes its flight")
		room.resume()
		room._cards[index].art.set_process(false)
		room._cards[index].art._advance_animation(60.0)
		gifts.append(room._cards[index].art.hold_effect_snapshot().surprise)
	check(room.snapshot().opened_count == 3 and storage.writes == 4 and reward_audio.size() == 3,
		"Opening all three persistent gifts keeps one saved receipt and one success sound per chest")
	for index in range(3):
		var art = room._cards[index].art
		art._advance_animation(600.0)
		art.show_surprise()
		var retained: Dictionary = art.hold_effect_snapshot().surprise
		check(retained.active and retained.kind == gifts[index].kind
			and retained.play_count == gifts[index].play_count,
			"All three opened chests retain their own gifts together after later openings and long idle time")
	check(storage.writes == 4 and reward_audio.size() == 3,
		"Persistent gift display cannot replay reward audio or save additional receipts")
	room.hide()
	for card in room._cards:
		check(not card.art.hold_effect_snapshot().surprise.active,
			"Leaving the reward room removes each gift from its stage")
	room.show()
	room.resume()
	for index in range(3):
		room._cards[index].art.show_surprise()
		check(not room._cards[index].art.hold_effect_snapshot().surprise.active
			and room._cards[index].art.hold_effect_snapshot().surprise.play_count == gifts[index].play_count,
			"Reentering an opened batch cannot reroll or replay gifts that were left behind")
	room.queue_free()
	await process_frame


func _failure_checks() -> void:
	var unreadable := Storage.new()
	unreadable.readable = false
	var unavailable = _make_room(unreadable)
	check(unavailable.has_pending() and not unavailable.configure_saved(_manifest, false),
		"Unavailable storage keeps the resume path visible instead of starting another round")
	unreadable.readable = true
	unavailable.retry_save()
	check(not unavailable.has_pending() and not unavailable.snapshot().save_failed,
		"Retrying an initially unavailable empty store allows gameplay again")
	unavailable.queue_free()
	await process_frame
	var storage := Storage.new()
	storage.writable = false
	var room = _make_room(storage)
	check(not room.configure("retry-round", 2, "summer", _manifest, false),
		"Initial storage failure remains visible to the integrating screen")
	check(room.snapshot().save_failed and room.snapshot().chest_count == 2 and room._retry.visible,
		"The initial failed save preserves its selected chest draft and offers retry")
	room.begin_hold(room._cards[0].button)
	check(not room.snapshot().holding, "An unpersisted batch cannot consume a chance")
	storage.writable = true
	room.retry_save()
	check(not room.snapshot().save_failed and room.has_pending() and storage.writes == 1,
		"Retry saves the same earned batch without requiring another game")
	var rewards: Array[String] = []
	room.chest_audio_requested.connect(func(action: String, theme_id: String, _progress: float) -> void:
		if action == "reward":
			rewards.append(theme_id))
	storage.writable = false
	_hold(room, 0, Feel.HOLD_SECONDS)
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS)
	check(room.snapshot().save_failed and room._cards[0].art.mode == "opened" and rewards.is_empty(),
		"Failed release persistence keeps the visible opening but withholds duplicate-prone reward feedback")
	storage.writable = true
	room.retry_save()
	room.retry_save()
	check(not room.snapshot().save_failed and room.snapshot().opened_count == 1 and rewards.size() == 1,
		"Retrying a released chest saves and celebrates exactly once")
	check(storage.writes == 2, "Repeated retry cannot write a second receipt for one opening")
	room.queue_free()
	await process_frame


func _responsive_resize_checks() -> void:
	# Reuse the same stage across orientations so a previous desktop minimum
	# cannot force an oversized scroll viewport on the next phone layout.
	root.size = Vector2i(1366, 768)
	await process_frame
	var column := VBoxContainer.new()
	root.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := Control.new()
	column.add_child(header)
	var room := Room.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(room)
	room.connect_storage(Storage.new())
	check(room.configure("responsive-treasure", 3, "spring", _manifest, false),
		"Prepare one treasure stage for repeated desktop and phone resizing")
	room.set_process(false)
	var published: Array[Dictionary] = []
	room.changed.connect(func(value: Dictionary) -> void: published.append(value.duplicate(true)))
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(320, 568),
		Vector2i(667, 375), Vector2i(375, 667), Vector2i(1366, 768)]:
		published.clear()
		root.size = dimensions
		for frame in range(2):
			await process_frame
		header.custom_minimum_size.y = 72.0 / Style.ui_scale(room)
		for frame in range(6):
			await process_frame
		var context := "resizing the same stage to %s" % dimensions
		var room_global: Rect2 = room.get_global_rect()
		var window_rect: Rect2 = root.get_visible_rect()
		check(room_global.position.x >= window_rect.position.x - 1.0
			and room_global.end.x <= window_rect.end.x + 1.0,
			"The room itself follows the resized window width after " + context)
		var viewport: Rect2 = room._scroll.get_rect()
		check(viewport.position.x >= -1.0 and viewport.end.x <= room.size.x + 1.0,
			"The scroll viewport stays within the room after " + context)
		var viewport_global: Rect2 = room._scroll.get_global_rect()
		var content_global: Rect2 = room._content.get_global_rect()
		check(content_global.position.x >= viewport_global.position.x - 1.0
			and content_global.end.x <= viewport_global.end.x + 1.0
			and absf(content_global.size.x - viewport_global.size.x) <= 1.0,
			"Treasure content fills the current viewport without retaining a previous wide minimum after " + context)
		for card in room._cards:
			var card_global: Rect2 = card.panel.get_global_rect()
			check(card_global.position.x >= viewport_global.position.x - 1.0
				and card_global.end.x <= viewport_global.end.x + 1.0,
				"Every chest keeps its full width within the viewport after " + context)
			if dimensions.x <= 390:
				check(card.art.size.x >= room._scroll.size.x - 10.0 / Style.ui_scale(room),
					"Phone treasure artwork uses the available stage width after " + context)
		_check_settled_layout(room, published, context)
	column.queue_free()
	await process_frame


func _deferred_layout_checks() -> void:
	# Keep the project's normal content scaling and reproduce the real VBox
	# lifecycle: configure while hidden at zero size, then show and settle.
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(667, 375)]:
		root.size = dimensions
		await process_frame
		var column := VBoxContainer.new()
		root.add_child(column)
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var header := Control.new()
		column.add_child(header)
		var room := Room.new()
		room.hide()
		room.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(room)
		header.custom_minimum_size.y = 72.0 / Style.ui_scale(room)
		room.connect_storage(Storage.new())
		room.size = Vector2.ZERO
		var published: Array[Dictionary] = []
		room.changed.connect(func(value: Dictionary) -> void: published.append(value.duplicate(true)))
		check(room.configure("hidden-layout-%d" % dimensions.x, 3, "spring", _manifest, false),
			"A hidden zero-sized reward room can prepare a durable batch")
		room.set_process(false)
		room.show()
		for frame in range(5):
			await process_frame
		_check_settled_layout(room, published, "show at %s" % dimensions)
		room.hide()
		header.custom_minimum_size.y += 12.0 / Style.ui_scale(room)
		await process_frame
		room.show()
		room.resume()
		for frame in range(5):
			await process_frame
		_check_settled_layout(room, published, "reentry at %s" % dimensions)
		column.queue_free()
		await process_frame


func _check_settled_layout(room, published: Array[Dictionary], context: String) -> void:
	check(not published.is_empty(), "The room publishes its final layout after " + context)
	if published.is_empty():
		return
	var current: Dictionary = published.back()
	check(Rect2(Vector2.ZERO, room.size).encloses(room._scroll.get_rect())
		and not room._scroll.get_rect().intersects(room._back.get_rect()),
		"The scrollable treasure stage fits above the fixed exit action after " + context)
	check(room._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
		and room._scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"Treasure scrolling keeps both scrollbars hidden after " + context)
	for index in range(room._cards.size()):
		var card: Dictionary = room._cards[index]
		var actual: Rect2 = card.button.get_global_rect()
		var recorded: Dictionary = current.chests[index].rect
		check(actual.is_equal_approx(Rect2(recorded.x, recorded.y, recorded.width, recorded.height)),
			"Published chest geometry matches its final container position after " + context)
		check(Rect2(Vector2.ZERO, card.panel.size).encloses(card.art.get_rect()),
			"Large chest artwork remains inside its own card after " + context)
		var minimum_art_height: float = 190 if room.size.y * Style.ui_scale(room) < 430 else 260
		check(card.art.size.x * Style.ui_scale(room) >= 220
			and card.art.size.y * Style.ui_scale(room) >= minimum_art_height,
			"Settled treasure art keeps its readable physical size after " + context)
		for other_index in range(index + 1, room._cards.size()):
			check(not actual.intersects(room._cards[other_index].button.get_global_rect()),
				"Settled chest controls never overlap after " + context)

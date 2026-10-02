extends Control

signal exit_requested
signal changed(state: Dictionary)
signal chest_audio_requested(action: String, theme_id: String, progress: float)
signal chest_cue_requested(theme_id: String, cue: String, step: int)

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const State = preload("res://scripts/pop_reward_state.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const Backdrop = preload("res://scripts/treasure_backdrop.gd")

var rewards := State.new()
var save_path: String = "user://pop-rewards-v1.cfg"
var reduced_motion: bool = false
var interaction_allowed: Callable
var _cards: Array[Dictionary] = []
var _manifest: Dictionary = {}
var _configured_id: String = ""
var _draft_themes: Array[String] = []
var _active: int = -1
var _holding: bool = false
var _opening: bool = false
var _elapsed: float = 0.0
var _hold_frame: int = -1
var _paused: bool = false
var _settling: bool = false
var _save_failed: bool = false
var _unsaved_index: int = -1
var _pointer_origin: Vector2
var _pointer_set: bool = false
var _layout_pending: bool = false
var _backdrop: Backdrop
var _title: Label
var _subtitle: Label
var _notice: Label
var _back: Button
var _retry: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_backdrop = Backdrop.new()
	_backdrop.show_theme_name = false
	add_child(_backdrop)
	_title = _label("Your treasure", 30)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.minimum_size_changed.connect(_queue_layout)
	_subtitle = _label("Hold a chest to discover its surprise.", 16)
	_notice = _label("", 14)
	_notice.add_theme_color_override("font_color", Style.WRONG)
	_back = Button.new()
	_back.name = "PopTreasureBack"
	_back.text = "Back"
	add_child(_back)
	Style.action_button(_back, Color("#694a99"))
	_back.pressed.connect(func() -> void:
		pause()
		exit_requested.emit())
	_retry = Button.new()
	_retry.name = "PopTreasureRetry"
	_retry.text = "Retry save"
	add_child(_retry)
	Style.action_button(_retry, Color("#694a99"), true)
	_retry.pressed.connect(retry_save)
	item_rect_changed.connect(_queue_layout)
	get_viewport().size_changed.connect(_queue_layout)
	visibility_changed.connect(_visibility_changed)
	_refresh()


func _label(text: String, pixels: int) -> Label:
	var label := Style.label(text, pixels)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	add_child(label)
	return label


func connect_storage(host: Object) -> bool:
	if not _configured_id.is_empty():
		return rewards.ready
	rewards = State.new(save_path, host)
	_save_failed = not rewards.load_state()
	_refresh()
	return not _save_failed


func has_pending() -> bool:
	if not rewards.ready and not rewards.load_state():
		_save_failed = true
	return _save_failed or _unsaved_index >= 0 or rewards.has_pending()


func has_batch() -> bool:
	if not rewards.ready:
		rewards.load_state()
	return not rewards.entries.is_empty()


func configure(id: String, chest_count: int, preferred_theme: String, manifest: Dictionary, reduce: bool) -> bool:
	_manifest = manifest
	reduced_motion = reduce
	if not _configured_id.is_empty() and _configured_id != id and (_unsaved_index >= 0 or _save_failed):
		_refresh()
		return false
	if _configured_id == id and not _cards.is_empty():
		set_reduced_motion(reduce)
		_refresh()
		return not _save_failed
	pause()
	_configured_id = id
	_draft_themes = _choose_themes(id, clampi(chest_count, 0, 3), preferred_theme)
	_save_failed = not rewards.create_batch(id, _draft_themes)
	_unsaved_index = -1
	_build_cards()
	resume()
	return not _save_failed


func configure_saved(manifest: Dictionary, reduce: bool) -> bool:
	_manifest = manifest
	reduced_motion = reduce
	if _unsaved_index >= 0 or (_save_failed and not _configured_id.is_empty()):
		resume()
		return false
	pause()
	_save_failed = not rewards.load_state()
	if not _save_failed and rewards.entries.is_empty():
		return false
	_configured_id = rewards.round_id
	_draft_themes.clear()
	for entry in rewards.entries:
		_draft_themes.append(str(entry.theme))
	_build_cards()
	resume()
	return not _save_failed


static func _choose_themes(id: String, count: int, preferred: String) -> Array[String]:
	var available: Array[String] = []
	for key in Data.THEMES:
		available.append(str(key))
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	for index in range(available.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var value: String = available[index]
		available[index] = available[other]
		available[other] = value
	if available.has(preferred):
		available.erase(preferred)
		available.push_front(preferred)
	var result: Array[String] = []
	var types: Array[String] = []
	for theme_id in available:
		var chest_type: String = str(Data.THEMES[theme_id].chest)
		if types.has(chest_type):
			continue
		if result.size() >= count:
			break
		result.append(theme_id)
		types.append(chest_type)
	return result


func _build_cards() -> void:
	for card in _cards:
		card.panel.free()
	_cards.clear()
	var entries: Array[Dictionary] = []
	if rewards.round_id == _configured_id:
		entries.assign(rewards.entries)
	if entries.is_empty():
		for theme_id in _draft_themes:
			entries.append({"theme": theme_id, "opened": false})
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var palette: Dictionary = Data.theme(str(entry.theme))
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", Style.box(Color(1, 1, 1, 0.86), palette.light, 24, 2))
		add_child(panel)
		var art := Chest.new()
		panel.add_child(art)
		art.configure_skin(palette, _manifest)
		art.reduced_motion = reduced_motion
		var heading := Style.label(str(palette.name) + " chest", 19)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.clip_text = true
		panel.add_child(heading)
		var caption := Style.label("Hold to open", 14)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.clip_text = true
		panel.add_child(caption)
		var button := Button.new()
		button.name = "PopTreasureChest%d" % index
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style_name in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, palette.accent, 24, 3))
		panel.add_child(button)
		_cards.append({"panel": panel, "art": art, "heading": heading, "caption": caption,
			"button": button, "theme": str(entry.theme), "opened": bool(entry.opened), "announced": bool(entry.opened)})
		button.button_down.connect(begin_hold.bind(button))
		button.button_up.connect(func() -> void:
			if _active == index:
				end_hold())
		button.gui_input.connect(_card_input.bind(index))
		button.focus_exited.connect(func() -> void:
			if _active == index:
				cancel_input())
		art.release_reached.connect(_released.bind(index))
		art.opened.connect(_finished.bind(index))
		art.cue_requested.connect(_cue.bind(index))
		if bool(entry.opened):
			# Restoring a completed chest must not replay its release or surprise.
			art.mode = "opening"
			art.finish_immediately()
	if not _cards.is_empty():
		_backdrop.configure(Data.theme(str(_cards[0].theme)))
	_refresh()


func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for card in _cards:
		if not card.button.disabled:
			controls.append(card.button)
	if _retry.visible:
		controls.append(_retry)
	controls.append(_back)
	return controls


func is_chest_control(control: Control) -> bool:
	for card in _cards:
		if card.button == control:
			return not card.button.disabled and is_visible_in_tree() and not _paused
	return false


func begin_hold(control: Control) -> void:
	if _active >= 0 or _paused or _save_failed or not is_chest_control(control):
		return
	if interaction_allowed.is_valid() and not interaction_allowed.call():
		return
	for index in range(_cards.size()):
		if _cards[index].button == control:
			_active = index
			break
	if _active < 0:
		return
	_holding = true
	_elapsed = 0.0
	_hold_frame = Engine.get_process_frames()
	_pointer_set = false
	var card: Dictionary = _cards[_active]
	chest_audio_requested.emit("prepare", card.theme, 0.0)
	card.art.begin_hold()
	chest_audio_requested.emit("charge", card.theme, 0.0)
	_refresh()


func end_hold() -> void:
	_cancel(true)


func cancel_input() -> void:
	_cancel(false)


func _cancel(animate: bool) -> void:
	_holding = false
	_elapsed = 0.0
	_hold_frame = -1
	_pointer_set = false
	if _active < 0:
		return
	var card: Dictionary = _cards[_active]
	if _opening and card.art.opening_committed():
		return
	if _opening:
		card.art.cancel_open(animate)
	elif animate:
		card.art.cancel_hold()
	else:
		card.art.set_hold_progress(0.0)
	chest_audio_requested.emit("cancel" if animate else "stop", card.theme, 0.0)
	_active = -1
	_opening = false
	_refresh()


func _process(delta: float) -> void:
	if Engine.get_process_frames() != _hold_frame:
		advance_hold(delta)


func advance_hold(delta: float) -> void:
	if _paused or _active < 0 or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	var card: Dictionary = _cards[_active]
	if _holding and not _opening:
		_elapsed += delta
		var progress: float = minf(1.0, _elapsed / Feel.HOLD_SECONDS)
		card.art.set_hold_progress(progress)
		chest_audio_requested.emit("charge", card.theme, progress)
		if progress >= 1.0:
			_opening = true
			card.art.start_open(reduced_motion)
	if _opening:
		chest_audio_requested.emit("release" if card.art.opening_committed() else "tension", card.theme, card.art.tension_progress())
	_refresh_captions()


func _released(index: int) -> void:
	if index != _active or not _opening or not _cards[index].art.opening_committed():
		return
	_holding = false
	_hold_frame = -1
	_pointer_set = false
	_commit(index)
	if not _settling:
		chest_audio_requested.emit("release", _cards[index].theme, 1.0)
	_refresh()


func _commit(index: int) -> bool:
	if _cards[index].opened:
		return true
	if rewards.mark_opened(_configured_id, index):
		_cards[index].opened = true
		if rewards.last_open_was_duplicate:
			_cards[index].announced = true
		_unsaved_index = -1
		_save_failed = false
		return true
	_save_failed = true
	_unsaved_index = index
	return false


func _finished(index: int) -> void:
	if index != _active or not _opening or _cards[index].art.mode != "opened":
		return
	_commit(index)
	_holding = false
	_opening = false
	_active = -1
	_elapsed = 0.0
	_hold_frame = -1
	if not _settling:
		chest_audio_requested.emit("finish", _cards[index].theme, 1.0)
	_announce(index)
	_refresh()


func _announce(index: int) -> void:
	if _cards[index].announced or not _cards[index].opened:
		return
	_cards[index].announced = true
	if _settling or _paused or not is_visible_in_tree():
		return
	_cards[index].art.show_surprise()
	chest_audio_requested.emit("reward", _cards[index].theme, 0.0)


func _cue(theme_id: String, cue: String, step: int, index: int) -> void:
	if index != _active or _settling or _paused or not is_visible_in_tree():
		return
	if cue in ["press", "hold_pulse"] and (not _holding or _opening):
		return
	if cue in ["opening", "tension_pulse", "anticipation", "unlock", "release", "settle"] and not _opening:
		return
	chest_cue_requested.emit(theme_id, cue, step)


func retry_save() -> void:
	if _unsaved_index >= 0:
		var index: int = _unsaved_index
		if _commit(index) and _cards[index].art.mode == "opened":
			_announce(index)
	elif _configured_id.is_empty():
		_save_failed = not rewards.load_state()
		if not _save_failed and not rewards.entries.is_empty():
			configure_saved(_manifest, reduced_motion)
	elif rewards.has_pending() and rewards.round_id != _configured_id:
		# Another tab may have earned a batch while this round was in play.
		# Keep that durable batch intact and let the player resume it.
		_save_failed = false
		configure_saved(_manifest, reduced_motion)
	else:
		_save_failed = not rewards.create_batch(_configured_id, _draft_themes)
		if not _save_failed:
			_build_cards()
	_refresh()


func pause() -> void:
	_settling = true
	cancel_input()
	if _active >= 0 and _opening and _cards[_active].art.opening_committed():
		chest_audio_requested.emit("stop", _cards[_active].theme, 0.0)
		_cards[_active].art.finish_immediately()
	_settling = false
	_paused = true
	for card in _cards:
		card.art.set_idle_paused(true)
	_refresh()


func resume() -> void:
	_paused = false
	for card in _cards:
		card.art.set_idle_paused(false)
	_refresh()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	for card in _cards:
		card.art.reduced_motion = enabled
	if enabled and _active >= 0 and _opening:
		# A settings change never completes a cancellable hold on the player's behalf.
		if _cards[_active].art.opening_committed():
			_cards[_active].art.finish_immediately()
		else:
			cancel_input()
	_refresh()


func _card_input(event: InputEvent, index: int) -> void:
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and not event.echo:
		if event.pressed:
			begin_hold(_cards[index].button)
		else:
			end_hold()
		accept_event()
	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			begin_hold(_cards[index].button)
			_pointer_origin = event.position
			_pointer_set = true
		elif _active == index:
			end_hold()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _active == index and _pointer_set:
		if event.position.distance_to(_pointer_origin) * Style.ui_scale(self) > 10.0:
			end_hold()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		pause()
	else:
		_queue_layout()


func _refresh_captions() -> void:
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		var message: String = "Opened!" if card.opened else "Hold to open"
		if _unsaved_index == index:
			message = "Opened - retry save"
		elif index == _active:
			message = "You can let go!" if card.art.opening_committed() else "Keep holding. Release to cancel."
		card.caption.text = message
		card.button.tooltip_text = str(card.heading.text) + ". " + message
		card.button.accessibility_name = card.button.tooltip_text


func _refresh() -> void:
	if not is_instance_valid(_back):
		return
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		card.button.disabled = _paused or _save_failed or card.opened or (_active >= 0 and _active != index)
	_retry.visible = _save_failed
	_retry.text = "Resume saved treasure" if rewards.has_pending() and rewards.round_id != _configured_id else "Retry save"
	_retry.disabled = _opening
	_notice.text = rewards.error if _save_failed else ""
	_notice.visible = _save_failed
	var opened: int = 0
	for card in _cards:
		opened += int(card.opened)
	_subtitle.text = "%d of %d opened. Hold a chest to discover its surprise." % [opened, _cards.size()]
	if opened == _cards.size() and opened > 0:
		_subtitle.text = "Every surprise is yours. Great speaking!"
	_refresh_captions()
	_layout()
	changed.emit(snapshot())
	_queue_layout()


func _queue_layout() -> void:
	if _layout_pending or not is_inside_tree():
		return
	_layout_pending = true
	_settle_layout.call_deferred()


func _settle_layout() -> void:
	_layout_pending = false
	if not is_inside_tree():
		return
	_layout()
	# Containers can assign the room's final position after configure/resume.
	# Publish those settled rectangles for input and accessibility consumers.
	changed.emit(snapshot())


func _layout() -> void:
	if not is_instance_valid(_back):
		return
	var s: float = Style.ui_scale(self)
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var compact: bool = h * s < 430.0
	var gap: float = 12 / s
	var margin: float = 18 / s
	_backdrop.size = size
	var title_height: float = (34 if compact else 40) / s
	var title_font_size: int = ceili((24 if compact else 28) / s)
	var title_font: Font = _title.get_theme_font("font")
	while title_font_size > 1 and title_font.get_height(title_font_size) > title_height:
		title_font_size -= 1
	_title.add_theme_font_size_override("font_size", title_font_size)
	_title.position = Vector2(margin, (6 if compact else 12) / s)
	_title.size = Vector2(w - margin * 2, title_height)
	_subtitle.add_theme_font_size_override("font_size", ceili((14 if compact else 15) / s))
	_subtitle.position = Vector2(margin, (40 if compact else 54) / s)
	_subtitle.size = Vector2(w - margin * 2, (36 if compact else 48) / s)
	var footer: float = (106 if _save_failed else 58 if compact else 62) / s
	var top: float = (82 if compact else 112) / s
	var area_h: float = maxf(64 / s, h - top - footer)
	var count: int = maxi(1, _cards.size())
	var row_space: float = 60 * count / s + gap * (count - 1)
	var stacked: bool = w * s < 680 and count > 1 and area_h >= row_space
	var card_w: float = w - margin * 2 if stacked else (w - margin * 2 - gap * (count - 1)) / count
	var card_h: float = (area_h - gap * (count - 1)) / count if stacked else area_h
	var horizontal_art: bool = stacked or card_h * s < 185.0
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		var heading_pixels: int = 15 if compact and not stacked and card_w * s < 220 else 16 if compact else 18
		card.heading.add_theme_font_size_override("font_size", ceili(heading_pixels / s))
		card.caption.add_theme_font_size_override("font_size", ceili((13 if compact else 14) / s))
		card.panel.position = Vector2(margin + (0 if stacked else (card_w + gap) * index), top + ((card_h + gap) * index if stacked else 0))
		card.panel.size = Vector2(card_w, card_h)
		card.button.custom_minimum_size = Vector2(44 / s, 44 / s)
		card.button.position = Vector2.ZERO
		card.button.size = card.panel.size
		if horizontal_art:
			var art_share: float = 0.49 if stacked else 0.34 if card_w * s < 220 else 0.44
			var art_w: float = minf(card_w * art_share, card_h * (1.32 if stacked else 1.05))
			card.art.position = Vector2(6 / s, 4 / s)
			card.art.size = Vector2(art_w, card_h - 8 / s)
			card.heading.position = Vector2(art_w + 10 / s, card_h * 0.12)
			card.heading.size = Vector2(card_w - art_w - 22 / s, card_h * 0.32)
			card.caption.position = Vector2(art_w + 10 / s, card_h * 0.50)
			card.caption.size = Vector2(card_w - art_w - 20 / s, card_h * 0.42)
		else:
			card.heading.position = Vector2(8 / s, 10 / s)
			card.heading.size = Vector2(card_w - 16 / s, 42 / s)
			card.art.position = Vector2(8 / s, 58 / s)
			card.art.size = Vector2(card_w - 16 / s, maxf(32 / s, card_h - 122 / s))
			card.caption.position = Vector2(8 / s, card_h - 60 / s)
			card.caption.size = Vector2(card_w - 16 / s, 50 / s)
	var button_y: float = h - 54 / s
	_back.position = Vector2(margin, button_y)
	_back.size = Vector2((w - margin * 2 - gap) / 2 if _save_failed else w - margin * 2, 46 / s)
	_retry.position = Vector2(w * 0.5 + gap * 0.5, button_y)
	_retry.size = Vector2((w - margin * 2 - gap) / 2, 46 / s)
	_notice.add_theme_font_size_override("font_size", ceili(14 / s))
	_notice.position = Vector2(margin, button_y - 48 / s)
	_notice.size = Vector2(w - margin * 2, 44 / s)


func snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []
	var opened: int = 0
	for card in _cards:
		opened += int(card.opened)
		var rect: Rect2 = card.button.get_global_rect()
		var art_rect: Rect2 = card.art.get_global_rect()
		entries.append({"theme": card.theme, "type": str(Data.THEMES[card.theme].chest), "opened": card.opened,
			"mode": card.art.mode, "progress": card.art.performance_progress(),
			"phase": card.art.performance_phase(), "committed": card.art.opening_committed(),
			"disabled": card.button.disabled, "control": str(card.button.name),
			"art_rect": {"x": art_rect.position.x, "y": art_rect.position.y,
				"width": art_rect.size.x, "height": art_rect.size.y},
			"rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}})
	return {"round_id": _configured_id, "chest_count": _cards.size(), "opened_count": opened,
		"chests": entries, "active": _active, "holding": _holding, "opening": _opening,
		"pending": _unsaved_index >= 0 or rewards.has_pending(), "save_failed": _save_failed,
		"error": rewards.error if _save_failed else "", "paused": _paused}


func _exit_tree() -> void:
	pause()

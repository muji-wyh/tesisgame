extends Control

signal exit_requested
signal replay_requested
signal home_requested
signal changed(state: Dictionary)
signal chest_audio_requested(action: String, theme_id: String, progress: float)
signal chest_cue_requested(theme_id: String, cue: String, step: int)
signal coins_released(id: String, reward: Dictionary, origin: Vector2, animate: bool)

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const State = preload("res://scripts/pop_reward_state.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const JellyRewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const TreasureScroll = preload("res://scripts/treasure_scroll.gd")
const TREASURE_LIGHT = preload("res://assets/chests/particles/portal_glow.png")

var rewards := State.new()
var save_path: String = "user://pop-rewards-v1.cfg"
var storage_kind: String = "pop"
var max_chests: int = 3
var allow_repeated_themes: bool = false
var page_size: int = 3
var reduced_motion: bool = false
var interaction_allowed: Callable
var credit_coins: Callable
var _cards: Array[Dictionary] = []
var _manifest: Dictionary = {}
var _configured_id: String = ""
var _draft_themes: Array[String] = []
var _draft_tiers: Array[int] = []
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
var _heading: Label
var _progress: Label
var _scroll: TreasureScroll
var _content: Control
var _notice: Label
var _back: Button
var _home: Button
var _retry: Button
var _previous_page: Button
var _next_page: Button
var _page_label: Label
var _page_index: int = 0
var _result_context: Dictionary = {}
var _empty_result_id: String = ""
var _result_score: Label
var _collecting: bool = false
var _collect_pending: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_heading = _label("Your treasure", 28)
	_progress = _label("", 14)
	_result_score = _label("", 48)
	_result_score.add_theme_font_override("font", Style.HEADING_FONT)
	_result_score.hide()
	for label in [_heading, _progress, _result_score]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
		# Font shaping settles after a viewport-scale change. Reflow once its
		# actual metrics arrive so old text heights cannot squeeze the chest.
		label.minimum_size_changed.connect(_queue_layout)
	_progress.add_theme_color_override("font_color", Style.MUTED)
	_scroll = TreasureScroll.new()
	_scroll.name = "TreasureScroll"
	_scroll.interaction_allowed = func() -> bool:
		return not _paused and (not interaction_allowed.is_valid() or interaction_allowed.call())
	add_child(_scroll)
	_scroll.hold_started.connect(begin_hold)
	_scroll.hold_finished.connect(end_hold)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:
		changed.emit(snapshot())
		_queue_layout())
	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)
	_heading.reparent(_content)
	_progress.reparent(_content)
	_result_score.reparent(_content)
	_notice = _label("", 14)
	_notice.add_theme_color_override("font_color", Style.WRONG)
	_back = Button.new()
	UiClick.bind_button(_back)
	_back.name = "PopTreasureBack"
	_back.text = "Back"
	add_child(_back)
	Style.action_button(_back, Style.GOOD)
	_back.pressed.connect(func() -> void:
		if not _result_context.is_empty():
			if not _paused and (not interaction_allowed.is_valid() or interaction_allowed.call()):
				replay_requested.emit()
			return
		pause()
		exit_requested.emit())
	_home = Button.new()
	UiClick.bind_button(_home)
	_home.name = "JellyGameOverHome"
	_home.text = "Home"
	add_child(_home)
	Style.action_button(_home, Style.GOOD)
	_home.hide()
	_home.pressed.connect(func() -> void:
		if _is_jelly_result() and not _paused and (not interaction_allowed.is_valid() or interaction_allowed.call()):
			home_requested.emit())
	_retry = Button.new()
	UiClick.bind_button(_retry)
	_retry.name = "PopTreasureRetry"
	_retry.text = "Retry save"
	add_child(_retry)
	Style.action_button(_retry, Style.GOOD, true)
	_retry.pressed.connect(retry_save)
	_previous_page = Button.new()
	_previous_page.name = "TreasurePreviousPage"
	_previous_page.text = "Previous"
	UiClick.bind_button(_previous_page)
	Style.action_button(_previous_page, Style.GOOD, true)
	add_child(_previous_page)
	_previous_page.pressed.connect(func() -> void: set_page(_page_index - 1))
	_next_page = Button.new()
	_next_page.name = "TreasureNextPage"
	_next_page.text = "Next"
	UiClick.bind_button(_next_page)
	Style.action_button(_next_page, Style.GOOD, true)
	add_child(_next_page)
	_next_page.pressed.connect(func() -> void: set_page(_page_index + 1))
	_page_label = _label("", 16)
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
	rewards.storage_kind = storage_kind
	rewards.max_chests = max_chests
	rewards.allow_repeated_themes = allow_repeated_themes
	_save_failed = not rewards.load_state()
	_refresh()
	return not _save_failed


func has_pending() -> bool:
	if not rewards.ready and not rewards.load_state():
		_save_failed = true
	return _save_failed or _unsaved_index >= 0 or rewards.has_pending()


func set_result_context(result: Dictionary) -> void:
	var previous_page_size: int = _effective_page_size()
	var had_empty_result: bool = not _empty_result_id.is_empty()
	_result_context = result.duplicate(true)
	if result.is_empty():
		_empty_result_id = ""
	if is_instance_valid(_scroll) and (previous_page_size != _effective_page_size() or (had_empty_result and _empty_result_id.is_empty())):
		_page_index = 0
		_build_cards()
		return
	_refresh()


func configure_empty_result(id: String, manifest: Dictionary, reduce: bool) -> bool:
	# An empty round is presentation only. It must neither display an earlier
	# opened batch as a new reward nor replace any durable unopened treasure.
	if _unsaved_index >= 0:
		_refresh()
		return false
	pause()
	_manifest = manifest
	reduced_motion = reduce
	_empty_result_id = id
	_page_index = 0
	if not rewards.ready and not rewards.load_state():
		_save_failed = true
	_build_cards()
	resume()
	return not _save_failed


func _is_danger_result() -> bool:
	return str(_result_context.get("reason", "")) == "danger"


func _is_jelly_result() -> bool:
	return storage_kind == "jelly" and not _result_context.is_empty()


func _effective_page_size() -> int:
	return 1 if _is_jelly_result() else maxi(1, page_size)


func collect_all_coins() -> bool:
	if _collecting:
		return false
	_collecting = true
	_collect_pending = true
	var was_paused: bool = _paused
	# Pause resolves a released lid silently and cancels any incomplete hold.
	# Unopened chests below are consumed directly, without playing their opening.
	pause()
	if not rewards.load_state():
		return _finish_collection(false, was_paused)
	if not _configured_id.is_empty() and rewards.round_id != _configured_id and not _draft_themes.is_empty():
		# A failed initial batch write must be recovered before Play again can
		# retire this round. Existing batch receipts make this idempotent.
		if not rewards.create_batch(_configured_id, _draft_themes, _draft_tiers):
			return _finish_collection(false, was_paused)
	_sync_saved_batch()
	var batch_id: String = rewards.round_id
	var entries: Array[Dictionary] = rewards.entries.duplicate(true)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if bool(entry.opened):
			continue
		if not credit_coins.is_valid():
			rewards.error = "Coin storage is unavailable. Please retry."
			return _finish_collection(false, was_paused)
		var reward_id: String = str(entry.get("reward_id", ""))
		var credit: Dictionary = credit_coins.call(reward_id, maxi(1, int(entry.get("tier", 0))))
		if not bool(credit.get("ok", false)):
			rewards.error = "Could not save your coins. Please retry."
			return _finish_collection(false, was_paused)
		if not rewards.mark_opened(batch_id, index):
			return _finish_collection(false, was_paused)
		coins_released.emit(reward_id, credit, global_position + size * 0.5, false)
	return _finish_collection(true, was_paused)


func _finish_collection(success: bool, was_paused: bool) -> bool:
	_collecting = false
	_collect_pending = not success
	_save_failed = not success
	_unsaved_index = -1
	# Rebuild only from this configured batch. Failed draft writes keep their
	# original identity and recovery arguments until the next retry succeeds.
	_build_cards()
	if not was_paused:
		resume()
	else:
		_refresh()
	if success:
		# Also reconcile a flight from a chest opened just before Play again.
		coins_released.emit("", {}, global_position + size * 0.5, false)
	return success


func configure(id: String, chest_count: int, preferred_theme: String, manifest: Dictionary, reduce: bool, final_chest_tier: int = 0) -> bool:
	_manifest = manifest
	reduced_motion = reduce
	if not _configured_id.is_empty() and _configured_id != id and (_unsaved_index >= 0 or _save_failed):
		_refresh()
		return false
	_empty_result_id = ""
	if _configured_id == id and not _cards.is_empty():
		set_reduced_motion(reduce)
		_refresh()
		return not _save_failed
	pause()
	_configured_id = id
	_page_index = 0
	var count: int = maxi(0, chest_count) if max_chests == 0 else clampi(chest_count, 0, max_chests)
	_draft_themes = _choose_themes(id, count, preferred_theme, allow_repeated_themes)
	_draft_tiers.clear()
	if final_chest_tier > 0 and count == 1:
		_draft_tiers.append(final_chest_tier)
	_save_failed = not rewards.create_batch(id, _draft_themes, _draft_tiers)
	if not _save_failed:
		_sync_saved_batch()
	_unsaved_index = -1
	_build_cards()
	resume()
	return not _save_failed


func _sync_saved_batch() -> void:
	_configured_id = rewards.round_id
	_draft_themes.clear()
	_draft_tiers.clear()
	for entry in rewards.entries:
		_draft_themes.append(str(entry.theme))
		_draft_tiers.append(int(entry.get("tier", 0)))


func configure_saved(manifest: Dictionary, reduce: bool) -> bool:
	_manifest = manifest
	reduced_motion = reduce
	if _unsaved_index >= 0 or (_save_failed and not _configured_id.is_empty()):
		resume()
		return false
	_empty_result_id = ""
	pause()
	_save_failed = not rewards.load_state()
	if not _save_failed and rewards.entries.is_empty():
		return false
	_sync_saved_batch()
	_page_index = 0
	for index in range(rewards.entries.size()):
		if not bool(rewards.entries[index].opened):
			_page_index = floori(float(index) / _effective_page_size())
			break
	_build_cards()
	resume()
	return not _save_failed


static func _choose_themes(id: String, count: int, preferred: String, repeat_preferred: bool = false) -> Array[String]:
	var available: Array[String] = []
	for key in Data.THEMES:
		available.append(str(key))
	if repeat_preferred:
		var repeated: Array[String] = []
		var selected: String = preferred if available.has(preferred) else available[0]
		for index in range(maxi(0, count)):
			repeated.append(selected)
		return repeated
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
	_scroll.cancel_drag()
	_scroll.scroll_vertical = 0
	for card in _cards:
		card.panel.free()
	_cards.clear()
	var entries: Array[Dictionary] = _batch_entries()
	_page_index = clampi(_page_index, 0, _page_count() - 1)
	var start: int = _page_index * _effective_page_size()
	for entry_index in range(start, mini(entries.size(), start + _effective_page_size())):
		var index: int = _cards.size()
		var entry: Dictionary = entries[entry_index]
		var palette: Dictionary = Data.theme(str(entry.theme))
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_content.add_child(panel)
		var light := TextureRect.new()
		light.texture = TREASURE_LIGHT
		light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		light.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		light.modulate = Color("#e8d19c", 0.36)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(light)
		var art := Chest.new()
		panel.add_child(art)
		art.configure_skin(palette, _manifest)
		art.reduced_motion = reduced_motion
		var tier: int = int(entry.get("tier", 0))
		var tier_label := Style.label(JellyRewardProgress.title_for_tier(tier) if tier > 0 else "", 14)
		tier_label.name = "ChestTier"
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.add_theme_color_override("font_color", Style.GOOD)
		tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tier_label)
		var button := Button.new()
		button.name = "%sTreasureChest%d" % ["Jelly" if storage_kind == "jelly" else "Pop", entry_index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style_name in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		panel.add_child(button)
		# The chest owns input. Its instruction is plain, non-interactive text.
		var hint := Panel.new()
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		panel.add_child(hint)
		var caption := Style.label("Hold to open", 16)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_child(caption)
		_cards.append({"panel": panel, "light": light, "art": art, "entry_index": entry_index,
			"button": button, "hint": hint, "caption": caption,
			"theme": str(entry.theme), "tier": tier, "tier_label": tier_label,
			"opened": bool(entry.opened), "announced": bool(entry.opened),
			"reward_id": str(entry.get("reward_id", "")), "coin_reward": {}})
		button.focus_entered.connect(_ensure_chest_visible.bind(button))
		button.focus_entered.connect(_refresh_captions)
		button.mouse_entered.connect(_refresh_captions)
		button.mouse_exited.connect(_refresh_captions)
		button.button_down.connect(begin_hold.bind(button))
		button.button_up.connect(func() -> void:
			if _active == index:
				end_hold())
		button.gui_input.connect(_card_input.bind(index))
		button.focus_exited.connect(func() -> void:
			if _active == index:
				cancel_input()
			_refresh_captions())
		art.release_reached.connect(_released.bind(index))
		art.opened.connect(_finished.bind(index))
		art.cue_requested.connect(_cue.bind(index))
		if bool(entry.opened):
			# Restoring a completed chest must not replay its release or opening flourish.
			art.mode = "opening"
			art.finish_immediately()
	_refresh()


func _batch_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not _empty_result_id.is_empty():
		return entries
	if rewards.round_id == _configured_id:
		entries.assign(rewards.entries)
	if entries.is_empty():
		for index in range(_draft_themes.size()):
			var entry: Dictionary = {"theme": _draft_themes[index], "opened": false}
			if index < _draft_tiers.size() and _draft_tiers[index] > 0:
				entry["tier"] = _draft_tiers[index]
			entries.append(entry)
	return entries


func _page_count() -> int:
	return maxi(1, ceili(float(_batch_entries().size()) / _effective_page_size()))


func set_page(index: int) -> bool:
	if not is_visible_in_tree() or _paused or _holding or _opening or _save_failed or _unsaved_index >= 0:
		return false
	if interaction_allowed.is_valid() and not interaction_allowed.call():
		return false
	var target: int = clampi(index, 0, _page_count() - 1)
	if target == _page_index:
		return false
	var move_focus: bool = _previous_page.has_focus() or _next_page.has_focus()
	cancel_input()
	_page_index = target
	_build_cards()
	if move_focus:
		var controls: Array[Control] = navigation_controls()
		if not controls.is_empty():
			controls[0].grab_focus()
	return true


func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for card in _cards:
		if not card.button.disabled:
			controls.append(card.button)
	if _retry.visible:
		controls.append(_retry)
	for button in [_previous_page, _next_page]:
		if is_instance_valid(button) and button.visible and not button.disabled:
			controls.append(button)
	if is_instance_valid(_home) and _home.visible:
		controls.append(_home)
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
	_ensure_chest_visible(control)
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
	if is_instance_valid(_scroll):
		_scroll.cancel_drag()


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
	# Validate ownership against the current durable batch before a coin receipt
	# can be issued. A different tab may have appended and moved these entries.
	if not rewards.load_state() or rewards.round_id != _configured_id:
		_save_failed = true
		_unsaved_index = index
		return false
	var entry_index: int = _cards[index].entry_index
	if entry_index >= rewards.entries.size() or str(rewards.entries[entry_index].get("reward_id", "")) != _cards[index].reward_id:
		_save_failed = true
		_unsaved_index = index
		return false
	if not rewards.entries[entry_index].opened and credit_coins.is_valid():
		var credit: Dictionary = credit_coins.call(_cards[index].reward_id, maxi(1, int(_cards[index].tier)))
		if not bool(credit.get("ok", false)):
			rewards.error = "Could not save your coins. Please retry."
			_save_failed = true
			_unsaved_index = index
			return false
		if int(credit.get("amount", 0)) > 0:
			_cards[index].coin_reward = credit
	if rewards.mark_opened(_configured_id, int(_cards[index].entry_index)):
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
	coins_released.emit(_cards[index].reward_id, _cards[index].coin_reward,
		_cards[index].art.get_global_transform() * _cards[index].art._cavity_origin(),
		not _settling and not _paused and is_visible_in_tree())
	if _settling or _paused or not is_visible_in_tree():
		return
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
	if _collect_pending:
		collect_all_coins()
		return
	if not _empty_result_id.is_empty():
		_save_failed = not rewards.load_state()
		if not _save_failed and not _configured_id.is_empty() and rewards.round_id != _configured_id and not _draft_themes.is_empty():
			_save_failed = not rewards.create_batch(_configured_id, _draft_themes, _draft_tiers)
		if not _save_failed:
			_sync_saved_batch()
		_build_cards()
		return
	if _unsaved_index >= 0:
		if (storage_kind == "jelly" or max_chests == 0) and rewards.load_state() and rewards.round_id != _configured_id:
			# Another tab appended loot and changed indexes. Reload rather than
			# applying this old chest's callback to a different saved chest.
			pause()
			_unsaved_index = -1
			_save_failed = false
			configure_saved(_manifest, reduced_motion)
			return
		var index: int = _unsaved_index
		if _commit(index) and _cards[index].art.mode == "opened":
			_announce(index)
	elif _configured_id.is_empty():
		_save_failed = not rewards.load_state()
		if not _save_failed and not rewards.entries.is_empty():
			configure_saved(_manifest, reduced_motion)
	elif storage_kind != "jelly" and max_chests > 0 and rewards.has_pending() and rewards.round_id != _configured_id:
		# Another tab may have earned a batch while this round was in play.
		# Keep that durable batch intact and let the player resume it.
		_save_failed = false
		configure_saved(_manifest, reduced_motion)
	else:
		_save_failed = not rewards.create_batch(_configured_id, _draft_themes, _draft_tiers)
		if not _save_failed:
			_sync_saved_batch()
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
	var s: float = Style.ui_scale(self)
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		var message: String = "Opened!" if card.opened else "Hold to open"
		if _unsaved_index == index:
			message = "Opened - retry save"
		elif index == _active:
			message = "You can let go!" if card.art.opening_committed() else "Keep holding..."
		card.button.accessibility_name = str(Data.theme(card.theme).name) + " chest. " + message
		if int(card.tier) > 0:
			card.button.accessibility_name = "Tier %d. " % int(card.tier) + card.button.accessibility_name
		if index == _active and not card.art.opening_committed():
			card.button.accessibility_name += " Release to cancel."
		card.caption.text = message
		var active: bool = index == _active
		var focused: bool = card.button.has_focus() and not card.button.disabled
		var hovered: bool = card.button.is_hovered() and not card.button.disabled
		var appearance: Array = [active, focused, hovered, card.opened, s]
		if card.hint.get_meta("appearance", []) == appearance:
			continue
		card.hint.set_meta("appearance", appearance)
		# Focus belongs to the reward itself, never a button-shaped instruction.
		card.light.modulate = Color("#ebcd85", 0.64 if active else 0.52 if focused else 0.38 if hovered else 0.22)
		card.caption.add_theme_color_override("font_color", Style.GOOD if active or focused or card.opened else Style.MUTED)


func _refresh() -> void:
	if not is_instance_valid(_back):
		return
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		card.button.disabled = _paused or _save_failed or card.opened or (_active >= 0 and _active != index)
	_retry.visible = _save_failed
	_retry.text = "Resume saved treasure" if storage_kind != "jelly" and max_chests > 0 and rewards.has_pending() and rewards.round_id != _configured_id else "Retry save"
	_retry.disabled = _opening
	_notice.text = rewards.error if _save_failed else ""
	_notice.visible = _save_failed
	var state: Dictionary = snapshot()
	var result_mode: bool = not _result_context.is_empty()
	var danger_result: bool = _is_danger_result()
	_home.visible = _is_jelly_result()
	_home.disabled = _paused
	_back.text = "Play again" if result_mode else "Back"
	_result_score.visible = result_mode
	if result_mode:
		_heading.text = "Game over" if danger_result else "Round complete" if _is_jelly_result() else "Round results"
		_result_score.text = str(maxi(0, int(_result_context.get("score", 0))))
		_result_score.accessibility_name = "Score: " + _result_score.text
		var tier: int = maxi(0, int(_result_context.get("chest_tier", 0)))
		_progress.text = JellyRewardProgress.title_for_tier(tier) if tier > 0 else "No chest this round"
		if _is_jelly_result():
			var completed: int = maxi(0, int(_result_context.get("cleared_pairs", 0)))
			var words: String = "word completed" if completed == 1 else "words completed"
			_progress.text = words if completed == int(_result_context.get("score", 0)) else "%d %s" % [completed, words]
			if tier <= 0:
				_progress.text += "\nNo chest this round"
	else:
		_heading.text = JellyRewardProgress.title_for_tier(int(_cards[0].tier)) if state.chest_count == 1 and not _cards.is_empty() and int(_cards[0].tier) > 0 else "Your treasure"
		_progress.text = "%d / %d opened" % [state.opened_count, state.chest_count]
	var pages: int = _page_count()
	_previous_page.visible = pages > 1
	_next_page.visible = pages > 1
	_page_label.visible = pages > 1
	_previous_page.disabled = _paused or _holding or _opening or _save_failed or _page_index == 0
	_next_page.disabled = _paused or _holding or _opening or _save_failed or _page_index + 1 >= pages
	_page_label.text = "%d / %d" % [_page_index + 1, pages]
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
	# Layout queues a ScrollContainer sort. Publish after it has assigned child
	# positions and scroll limits, including when a restored room first appears.
	_publish_layout.call_deferred()


func _publish_layout() -> void:
	if is_inside_tree():
		changed.emit(snapshot())


func _layout() -> void:
	if not is_instance_valid(_back):
		return
	var s: float = Style.ui_scale(self)
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	if _is_jelly_result():
		_layout_jelly_result(s, w, h)
		return
	if _back.get_meta("result_appearance", []) != [s, false]:
		# Restore ordinary result actions after leaving a Jelly modal, including
		# physical font and button minimums when the viewport scale changes.
		Style.action_button(_back, Style.GOOD)
		Style.action_button(_retry, Style.GOOD, true)
		_back.set_meta("result_appearance", [s, false])
	if not _result_context.is_empty() and _batch_entries().size() <= 1:
		_layout_single_result(s, w, h)
		return
	var compact: bool = h * s < 430.0
	var gap: float = 24 / s
	var margin: float = 12 / s
	var heading_height: float = (72 if compact else 80) / s
	var result_height: float = 60 / s if not _result_context.is_empty() else 0.0
	heading_height += result_height
	_heading.add_theme_font_size_override("font_size", ceili((22 if compact else 28) / s))
	_progress.add_theme_font_size_override("font_size", ceili(14 / s))
	var pager_height: float = 52 / s if _page_count() > 1 else 0.0
	var footer: float = (110 if _save_failed else 62) / s + pager_height
	_scroll.position = Vector2(margin, 8 / s)
	_scroll.size = Vector2(maxf(1, w - margin * 2), maxf(64 / s, h - footer - 8 / s))
	var count: int = maxi(1, _cards.size())
	var wide_single: bool = compact and count == 1 and w * s >= 620
	var columns: int = mini(count, 3 if w * s >= 960 else 2 if w * s >= 620 else 1)
	var card_w: float = minf((600 if wide_single else 480 if count == 1 else 360) / s, (_scroll.size.x - gap * (columns - 1)) / columns)
	var art_h: float = clampf(card_w * 0.82, 240 / s if count == 1 else 220 / s, (360 if count == 1 else 300) / s)
	if compact:
		art_h = maxf(128 / s, minf(art_h, _scroll.size.y - heading_height - (0 if wide_single else 56 / s)))
	var card_h: float = art_h + (0 if wide_single else 56 / s)
	var rows: int = ceili(float(count) / columns)
	var content_height: float = heading_height + card_h * rows + gap * (rows - 1)
	# Let the viewport own width so a desktop layout can shrink to a phone.
	_content.custom_minimum_size = Vector2(0, content_height)
	_content.size = Vector2(_scroll.size.x, maxf(content_height, _scroll.size.y))
	var left: float = (_scroll.size.x - card_w * columns - gap * (columns - 1)) * 0.5
	var top: float = maxf(0.0, (_scroll.size.y - content_height) * 0.42)
	_heading.position = Vector2(0, top)
	_heading.size = Vector2(_scroll.size.x, (40 if compact else 48) / s)
	_result_score.position = Vector2(0, top + (40 if compact else 48) / s)
	_result_score.size = Vector2(_scroll.size.x, result_height)
	_result_score.add_theme_font_size_override("font_size", ceili(44 / s))
	_progress.position = Vector2(0, top + (40 if compact else 48) / s + result_height)
	_progress.size = Vector2(_scroll.size.x, 24 / s)
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		card.panel.position = Vector2(left + (index % columns) * (card_w + gap), top + heading_height + floori(float(index) / columns) * (card_h + gap))
		card.panel.size = Vector2(card_w, card_h)
		card.button.custom_minimum_size = Vector2(44 / s, 44 / s)
		card.art.position = Vector2.ZERO
		card.art.size = Vector2(card_w, art_h)
		card.tier_label.visible = int(card.tier) > 0 and _batch_entries().size() > 1
		card.tier_label.position = Vector2.ZERO
		card.tier_label.size = Vector2(card_w, 24 / s)
		card.tier_label.add_theme_font_size_override("font_size", ceili(14 / s))
		if card.tier_label.visible:
			card.art.position.y = 24 / s
			card.art.size.y -= 24 / s
		card.light.size = Vector2.ONE * minf(card_w, art_h * 1.15)
		card.light.position = Vector2((card_w - card.light.size.x) * 0.5, art_h * 0.55 - card.light.size.y * 0.5)
		var hint_width: float = minf(card_w, 184 / s)
		card.hint.position = Vector2((card_w - hint_width) * 0.5, art_h + 8 / s)
		card.hint.size = Vector2(hint_width, 28 / s)
		card.caption.position = Vector2.ZERO
		card.caption.add_theme_font_size_override("font_size", ceili(14 / s))
		card.caption.size = card.hint.size
		if wide_single:
			# A short landscape screen places the instruction beside the chest.
			card.art.size.x = card_w - 204 / s
			card.hint.position = Vector2(card_w - hint_width, (card_h - card.hint.size.y) * 0.5)
			card.light.size = Vector2.ONE * art_h
			card.light.position = Vector2((card.art.size.x - art_h) * 0.5, art_h * 0.05)
		card.button.position = card.art.position
		card.button.size = card.art.size
	var button_y: float = h - 54 / s
	_back.size = Vector2((132 if not _result_context.is_empty() else 104) / s, 46 / s)
	_back.position = Vector2(margin if _save_failed else w - margin - _back.size.x, button_y)
	_retry.size = Vector2(minf(208 / s, w - margin * 2 - _back.size.x - 8 / s), 46 / s)
	_retry.position = Vector2(w - margin - _retry.size.x, button_y)
	_notice.add_theme_font_size_override("font_size", ceili(14 / s))
	_notice.position = Vector2(margin, button_y - pager_height - 48 / s)
	_notice.size = Vector2(w - margin * 2, 44 / s)
	var page_gap: float = 8 / s
	var page_button_width: float = minf(130 / s, maxf(44 / s, (w - margin * 2 - 80 / s - page_gap * 2) * 0.5))
	page_button_width = maxf(page_button_width, maxf(_previous_page.get_combined_minimum_size().x,
		_next_page.get_combined_minimum_size().x))
	_previous_page.position = Vector2(margin, button_y - pager_height)
	_previous_page.size = Vector2(page_button_width, 44 / s)
	_next_page.position = Vector2(w - margin - page_button_width, button_y - pager_height)
	_next_page.size = Vector2(page_button_width, 44 / s)
	_page_label.position = Vector2(margin + page_button_width + page_gap, button_y - pager_height)
	_page_label.size = Vector2(maxf(1.0, w - margin * 2 - page_button_width * 2 - page_gap * 2), 44 / s)
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", ceili(16 / s))
	_refresh_captions()
	_update_navigation(columns)


func _layout_jelly_result(s: float, w: float, h: float) -> void:
	var appearance: Array = [s, true]
	if _back.get_meta("result_appearance", []) != appearance:
		Style.action_button(_back, Style.GOOD, true)
		Style.action_button(_home, Style.GOOD)
		Style.action_button(_retry, Style.GOOD)
		Style.action_button(_previous_page, Style.GOOD)
		Style.action_button(_next_page, Style.GOOD)
		_back.set_meta("result_appearance", appearance)
	var margin: float = 4 / s
	var gap: float = 8 / s
	var action_h: float = 48 / s
	var inner_w: float = maxf(1.0, w - margin * 2)
	var action_y: float = h - action_h - margin
	var wide_actions: bool = w * s >= 420.0
	var action_count: int = 3 if _save_failed and wide_actions else 2
	var action_w: float = (inner_w - gap * (action_count - 1)) / action_count
	_home.position = Vector2(margin, action_y)
	_home.size = Vector2(action_w, action_h)
	_back.position = Vector2(w - margin - action_w, action_y)
	_back.size = Vector2(action_w, action_h)
	var footer_top: float = action_y
	if _save_failed:
		if wide_actions:
			_retry.position = Vector2(margin + action_w + gap, action_y)
			_retry.size = Vector2(action_w, action_h)
		else:
			footer_top -= action_h + gap
			_retry.position = Vector2(margin, footer_top)
			_retry.size = Vector2(inner_w, action_h)
		footer_top -= 40 / s
		_notice.position = Vector2(margin, footer_top)
		_notice.size = Vector2(inner_w, 36 / s)
		_notice.add_theme_font_size_override("font_size", ceili(12 / s))
	if _page_count() > 1:
		footer_top -= 54 / s
		var page_w: float = (inner_w - 56 / s - gap * 2) * 0.5
		_previous_page.position = Vector2(margin, footer_top)
		_previous_page.size = Vector2(page_w, action_h)
		_next_page.position = Vector2(w - margin - page_w, footer_top)
		_next_page.size = Vector2(page_w, action_h)
		_page_label.position = Vector2(margin + page_w + gap, footer_top)
		_page_label.size = Vector2(56 / s, action_h)
		_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_page_label.add_theme_font_size_override("font_size", ceili(13 / s))
	_scroll.position = Vector2(margin, margin)
	_scroll.size = Vector2(inner_w, maxf(1.0, footer_top - gap - margin))
	_scroll.scroll_vertical = 0
	# Fit the reward stage to the modal. A short screen puts the score beside
	# the chest; a phone uses a single column with a flexible artwork height.
	var stage_h: float = _scroll.size.y
	var compact: bool = w * s >= 420.0 and stage_h * s < 340.0 and not _cards.is_empty()
	var tight: bool = stage_h * s < 170.0
	var heading_h: float = (24 if tight else 32) / s
	var score_h: float = (36 if tight else 62) / s
	var summary_h: float = (20 if tight else 24) / s
	var label_gap: float = (2 if tight else 4) / s
	_heading.add_theme_font_size_override("font_size", ceili((18 if tight else 24) / s))
	_result_score.add_theme_font_size_override("font_size", ceili((30 if tight else 52) / s))
	_progress.add_theme_font_size_override("font_size", ceili((11 if tight else 13) / s))
	heading_h = maxf(heading_h, _heading.get_combined_minimum_size().y)
	score_h = maxf(score_h, _result_score.get_combined_minimum_size().y)
	summary_h = maxf(summary_h, _progress.get_combined_minimum_size().y)
	var header_h: float = heading_h + score_h + summary_h + label_gap * 2
	var info_w: float = inner_w * 0.42 if compact else inner_w
	var chest_w: float = inner_w - info_w - gap if compact else minf(410 / s, inner_w)
	var chest_h: float = minf(stage_h, 370 / s) if compact else maxf(0.0, minf(stage_h - header_h - gap, 370 / s))
	if _cards.is_empty():
		chest_h = 0.0
	var content_h: float = maxf(header_h, chest_h) if compact else header_h + (gap + chest_h if chest_h > 0 else 0.0)
	var top: float = maxf(0.0, (stage_h - content_h) * 0.5)
	var info_top: float = top + maxf(0.0, (content_h - header_h) * 0.5) if compact else top
	_content.custom_minimum_size = Vector2.ZERO
	_content.size = _scroll.size
	_heading.position = Vector2(0, info_top)
	_heading.size = Vector2(info_w, heading_h)
	_result_score.position = Vector2(0, info_top + heading_h + label_gap)
	_result_score.size = Vector2(info_w, score_h)
	_progress.position = Vector2(0, info_top + heading_h + score_h + label_gap * 2)
	_progress.size = Vector2(info_w, summary_h)
	if not _cards.is_empty():
		var card: Dictionary = _cards[0]
		var hint_h: float = 28 / s
		var tier_h: float = (20 if tight else 24) / s if int(card.tier) > 0 else 0.0
		var art_h: float = maxf(1.0, chest_h - tier_h - hint_h - 4 / s)
		card.panel.position = Vector2(info_w + gap if compact else (inner_w - chest_w) * 0.5,
			top if compact else top + header_h + gap)
		card.panel.size = Vector2(chest_w, chest_h)
		card.art.position = Vector2(0, tier_h)
		card.art.size = Vector2(chest_w, art_h)
		card.tier_label.visible = tier_h > 0
		card.tier_label.position = Vector2.ZERO
		card.tier_label.size = Vector2(chest_w, tier_h)
		card.tier_label.add_theme_font_size_override("font_size", ceili(12 / s))
		card.light.size = Vector2.ONE * minf(chest_w, art_h * 1.12)
		card.light.position = Vector2((chest_w - card.light.size.x) * 0.5, tier_h + art_h * 0.55 - card.light.size.y * 0.5)
		card.button.custom_minimum_size = Vector2(44 / s, 44 / s)
		card.button.position = card.art.position
		card.button.size = card.art.size
		var hint_w: float = minf(184 / s, chest_w)
		card.hint.position = Vector2((chest_w - hint_w) * 0.5, tier_h + art_h + 4 / s)
		card.hint.size = Vector2(hint_w, hint_h)
		card.caption.position = Vector2.ZERO
		card.caption.add_theme_font_size_override("font_size", ceili(13 / s))
		card.caption.size = card.hint.size
	_refresh_captions()
	_update_navigation(1)


func _layout_single_result(s: float, w: float, h: float) -> void:
	var margin: float = 16 / s
	var compact: bool = h * s < 360.0 and w * s >= 480.0
	var footer: float = (116 if _save_failed else 62) / s
	_scroll.position = Vector2(margin, 4 / s)
	_scroll.size = Vector2(maxf(1.0, w - margin * 2), maxf(64 / s, h - footer - 4 / s))
	var stage_w: float = _scroll.size.x
	_heading.add_theme_font_size_override("font_size", ceili(20 / s))
	_result_score.add_theme_font_size_override("font_size", ceili((44 if compact else 52) / s))
	_progress.add_theme_font_size_override("font_size", ceili(15 / s))
	var heading_h: float = maxf(30 / s, _heading.get_combined_minimum_size().y)
	var score_h: float = maxf((58 if compact else 68) / s, _result_score.get_combined_minimum_size().y)
	var summary_h: float = maxf(26 / s, _progress.get_combined_minimum_size().y)
	var label_gap: float = 4 / s
	var header_h: float = heading_h + score_h + summary_h + label_gap * 2
	var art_w: float = minf(410 / s, stage_w)
	var art_h: float = clampf(_scroll.size.y - header_h - 60 / s, 180 / s, 328 / s)
	var info_w: float = stage_w
	if compact:
		info_w = minf(210 / s, stage_w * 0.36)
		art_w = minf(350 / s, stage_w - info_w - 20 / s)
		art_h = clampf(_scroll.size.y - 54 / s, 128 / s, 230 / s)
	var chest_h: float = art_h + 54 / s if not _cards.is_empty() else 0.0
	var content_h: float = maxf(header_h, chest_h) if compact else header_h + chest_h
	_content.custom_minimum_size = Vector2(0, content_h)
	_content.size = Vector2(stage_w, maxf(content_h, _scroll.size.y))
	var top: float = maxf(0.0, (_scroll.size.y - content_h) * 0.5)
	var info_left: float = (stage_w - info_w - art_w - 20 / s) * 0.5 if compact else 0.0
	var info_top: float = top + (content_h - header_h) * 0.5 if compact else top
	_heading.position = Vector2(info_left, info_top)
	_heading.size = Vector2(info_w, heading_h)
	_result_score.position = Vector2(info_left, info_top + heading_h + label_gap)
	_result_score.size = Vector2(info_w, score_h)
	_progress.position = Vector2(info_left, info_top + heading_h + score_h + label_gap * 2)
	_progress.size = Vector2(info_w, summary_h)
	if not _cards.is_empty():
		var card: Dictionary = _cards[0]
		card.panel.position = Vector2(info_left + info_w + 20 / s if compact else (stage_w - art_w) * 0.5,
			top if compact else top + header_h)
		card.panel.size = Vector2(art_w, chest_h)
		card.art.position = Vector2.ZERO
		card.art.size = Vector2(art_w, art_h)
		card.tier_label.hide()
		card.light.size = Vector2.ONE * minf(art_w, art_h * 1.12)
		card.light.position = Vector2((art_w - card.light.size.x) * 0.5, art_h * 0.55 - card.light.size.y * 0.5)
		card.button.custom_minimum_size = Vector2(44 / s, 44 / s)
		card.button.position = card.art.position
		card.button.size = card.art.size
		var hint_w: float = minf(184 / s, card.button.size.x)
		card.hint.position = Vector2((art_w - hint_w) * 0.5, art_h + 6 / s)
		card.hint.size = Vector2(hint_w, 28 / s)
		card.caption.position = Vector2.ZERO
		card.caption.add_theme_font_size_override("font_size", ceili(14 / s))
		card.caption.size = card.hint.size
	var button_y: float = h - 54 / s
	_back.size = Vector2(144 / s, 46 / s)
	_back.position = Vector2(margin if _save_failed else (w - _back.size.x) * 0.5, button_y)
	_retry.size = Vector2(minf(180 / s, w - margin * 2 - _back.size.x - 8 / s), 46 / s)
	_retry.position = Vector2(w - margin - _retry.size.x, button_y)
	_notice.add_theme_font_size_override("font_size", ceili(13 / s))
	_notice.position = Vector2(margin, button_y - 52 / s)
	_notice.size = Vector2(w - margin * 2, 48 / s)
	_refresh_captions()
	_update_navigation(1)


func _ensure_chest_visible(control: Control) -> void:
	if _scroll.is_pointer_active():
		return
	_scroll.cancel_drag()
	_scroll.ensure_control_visible(control)


func _update_navigation(columns: int) -> void:
	var controls: Array[Control] = navigation_controls()
	for index in range(controls.size()):
		var control: Control = controls[index]
		var previous: Control = controls[posmod(index - 1, controls.size())]
		var next: Control = controls[(index + 1) % controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
	for index in range(_cards.size()):
		var button: Button = _cards[index].button
		for direction in [Vector2i(-1, SIDE_LEFT), Vector2i(1, SIDE_RIGHT),
			Vector2i(-columns, SIDE_TOP), Vector2i(columns, SIDE_BOTTOM)]:
			var candidate: int = index + direction.x
			var horizontal: bool = direction.y in [SIDE_LEFT, SIDE_RIGHT]
			if candidate >= 0 and candidate < _cards.size() and not _cards[candidate].button.disabled \
				and (not horizontal or floori(float(index) / columns) == floori(float(candidate) / columns)):
				button.set_focus_neighbor(direction.y, button.get_path_to(_cards[candidate].button))
			elif horizontal:
				button.set_focus_neighbor(direction.y, button.get_path_to(button))


func snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []
	var actions: Array[Dictionary] = []
	for button: Button in [_home, _retry, _back]:
		if not is_instance_valid(button):
			continue
		var action_rect: Rect2 = button.get_global_rect()
		actions.append({"name": str(button.name), "text": button.text,
			"rect": [action_rect.position.x, action_rect.position.y, action_rect.size.x, action_rect.size.y],
			"visible": button.visible, "disabled": button.disabled})
	var opened: int = 0
	var batch: Array[Dictionary] = _batch_entries()
	for entry in batch:
		opened += int(entry.opened)
	for card in _cards:
		var rect: Rect2 = card.button.get_global_rect()
		var art_rect: Rect2 = card.art.get_global_rect()
		var hint_rect: Rect2 = card.hint.get_global_rect()
		entries.append({"index": card.entry_index, "theme": card.theme, "type": str(Data.THEMES[card.theme].chest), "opened": card.opened,
			"tier": int(card.tier),
			"mode": card.art.mode, "progress": card.art.performance_progress(),
			"phase": card.art.performance_phase(), "committed": card.art.opening_committed(),
			"disabled": card.button.disabled, "control": str(card.button.name),
			"caption": card.caption.text,
			"hint_rect": {"x": hint_rect.position.x, "y": hint_rect.position.y,
				"width": hint_rect.size.x, "height": hint_rect.size.y},
			"art_rect": {"x": art_rect.position.x, "y": art_rect.position.y,
				"width": art_rect.size.x, "height": art_rect.size.y},
			"rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}})
	var viewport_rect: Rect2 = _scroll.get_global_rect() if is_instance_valid(_scroll) else Rect2()
	return {"round_id": _empty_result_id if not _empty_result_id.is_empty() else _configured_id, "chest_count": batch.size(), "opened_count": opened,
		"result_context": _result_context.duplicate(true), "collect_pending": _collect_pending,
		"empty_result": not _empty_result_id.is_empty(), "actions": actions,
		"score_text": _result_score.text if is_instance_valid(_result_score) and not _result_context.is_empty() else "",
		"replay_action": not _result_context.is_empty(),
		"heading": _heading.text if is_instance_valid(_heading) else "",
		"progress_text": _progress.text if is_instance_valid(_progress) else "",
		"page": _page_index, "page_count": _page_count(), "page_size": _effective_page_size(), "visible_chest_count": _cards.size(),
		"scroll_rect": {"x": viewport_rect.position.x, "y": viewport_rect.position.y,
			"width": viewport_rect.size.x, "height": viewport_rect.size.y},
		"scroll_offset": _scroll.scroll_vertical if is_instance_valid(_scroll) else 0,
		"scroll_max": _scroll._maximum() if is_instance_valid(_scroll) else 0.0,
		"chests": entries, "active": _active, "holding": _holding, "opening": _opening,
		"pending": _unsaved_index >= 0 or rewards.has_pending(), "save_failed": _save_failed,
		"error": rewards.error if _save_failed else "", "paused": _paused}


func _exit_tree() -> void:
	pause()

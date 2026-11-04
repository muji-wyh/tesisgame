extends Control
## Hold-to-charge presentation. Only committed store state moves the gold rail.

signal back_requested
signal purchase_requested(level: int, kind: String)
signal contribution_requested(kind: String, amount: int)
signal audio_requested(cue: String)
signal charging_changed(active: bool)
signal intro_accepted
signal intro_dismissed
signal retry_requested
signal changed

const Style = preload("res://scripts/ui_style.gd")
const Preview = preload("res://scripts/word_jelly_ability_preview.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const Tile = preload("res://scripts/word_jelly_tile.gd")
const WordArt = preload("res://scripts/word_art.gd")
const SKY = preload("res://assets/images/jelly-match/sky/day.png")
const COIN = preload("res://assets/coins/gold-coin.png")
const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")
const WAND = preload("res://assets/images/ui/jelly-powerups/auto-merge-wand.svg")
const GLOW = preload("res://assets/chests/shared/effects/portal_glow.png")
const RAYS = preload("res://assets/chests/shared/effects/rays.png")
const SPARKLE = preload("res://assets/chests/shared/effects/sparkle.png")
const GOLD := Color("#ffdb6f")
const GOLD_DARK := Color("#a36927")
const PULSE_AMOUNT := 25
const HOLD_LEAD := 0.18

var _state: Dictionary = {}
var _word: Dictionary = {}
var _picture: Texture2D
var _selected := 2
var _displayed_level := 2
var _level_reveal_pending := false
var _reveal_level := 2
var _kind := "jelly"
var _offering := false
var _active := true
var _reduced := false
var _charging := false
var _retry_press_armed := false
var _charge_wait := 0.0
var _elapsed := 0.0
var _pulse := 0.0
var _payoff := 0.0
var _preview_wait := 0.0
var _visual_progress := 0.0
var _rail_from := 0.0
var _rail_to := 0.0
var _rail_velocity := 0.0
var _rail_start_velocity := 0.0
var _rail_time := 0.0
var _rail_duration := 0.18
var _pending_milestone := false
var _milestone_progress := 0.0
var _level_up_count := 0
var _deposit_count := 0
var _charge_energy := 0.0
var _wallet_energy := 0.0
var _visual_balance := 0.0
var _layout_state: Array = []
var _layout_count := 0
var _rail_base_style: StyleBoxFlat
var _rail_fill_style: StyleBoxFlat
var _hero_base := Vector2.ZERO
var _hero_edge := 1.0
var _hero_lift_room := 0.0
var _rail_pitch := 76.0
var _rail_origin := Vector2.ZERO
var _rail_unit := 1.0
var _rail_scroll_offset := 0.0
var _sky := TextureRect.new()
var _back := Button.new()
var _heading: Label
var _wallet: Label
var _wallet_icon := TextureRect.new()
var _wallet_roll := Control.new()
var _wallet_right := 0.0
var _categories := Control.new()
var _category_buttons: Dictionary = {}
var _stage := Control.new()
var _hero := Tile.new()
var _wand := TextureRect.new()
var _name: Label
var _tier: Label
var _description: Label
var _benefits: Label
var _preview := Preview.new()
var _preview_label: Label
var _footer := Control.new()
var _scroll := ScrollContainer.new()
var _levels := Control.new()
var _tabs: Array[Dictionary] = []
var _progress: Label
var _progress_coin := TextureRect.new()
var _notice: Label
var _buy := Button.new()
var _buy_coin := TextureRect.new()
var _effects := Control.new()
var _shade := ColorRect.new()
var _offer := Panel.new()
var _offer_title: Label
var _offer_caption: Label
var _offer_jelly := Tile.new()
var _offer_accept := Button.new()
var _offer_later := Button.new()

func _init() -> void:
	name = "JellyUpgrades"
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	_texture(_sky, SKY, self)
	_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_back.text = "Back"
	_back.accessibility_name = "Back to the Jelly World map"
	add_child(_back)
	_back.pressed.connect(func() -> void:
		if _active and not _back.disabled:
			stop_charging()
			back_requested.emit())
	_heading = _label(self, "Jelly Upgrades", 26)
	_heading.clip_text = true
	_wallet = _label(self, "", 20)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_texture(_wallet_icon, COIN, self)
	_wallet_roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet_roll.clip_contents = true
	_wallet_roll.hide()
	add_child(_wallet_roll)
	_wallet_roll.draw.connect(_draw_wallet_digits)
	add_child(_categories)
	for kind: String in ["jelly", "auto_merge"]:
		var category := Button.new()
		category.text = "Merged Jelly" if kind == "jelly" else "Auto merge"
		category.pressed.connect(select_upgrade.bind(kind))
		_categories.add_child(category)
		_category_buttons[kind] = category
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.draw.connect(_draw_stage)
	_hero.disabled = true
	_hero.focus_mode = Control.FOCUS_NONE
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_hero)
	_texture(_wand, WAND, _stage)
	_wand.modulate = Color("#7950a6")
	_tier = _label(_stage, "", 42)
	_name = _label(_stage, "", 22)
	_description = _label(_stage, "", 16)
	_benefits = _label(_stage, "", 13)
	for label: Label in [_tier, _name, _description, _benefits]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_preview)
	_preview_label = _label(_stage, "POWER PREVIEW", 11)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_footer)
	_footer.add_child(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void:
		changed.emit.call_deferred())
	_scroll.add_child(_levels)
	_levels.draw.connect(_draw_rail)
	for level in range(1, 10):
		var button := Button.new()
		button.name = "JellyLv%d" % level
		button.text = "Lv%d" % level
		button.pressed.connect(select_level.bind(level))
		_levels.add_child(button)
		_tabs.append({"button": button, "level": level})
	_progress = _label(_footer, "", 19)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texture(_progress_coin, COIN, _footer)
	_notice = _label(_footer, "", 13)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_child(_buy)
	_buy.button_down.connect(func() -> void:
		_retry_press_armed = bool(_state.get("retry", false)) and not _buy.disabled
		start_charging())
	_buy.button_up.connect(stop_charging)
	_buy.mouse_exited.connect(stop_charging)
	_buy.pressed.connect(func() -> void:
		var armed: bool = _retry_press_armed
		_retry_press_armed = false
		if armed:
			retry_saving())
	_texture(_buy_coin, COIN, _buy)
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effects)
	_effects.draw.connect(_draw_effects)
	_shade.color = Color(Style.INK, 0.48)
	add_child(_shade)
	add_child(_offer)
	_offer_title = _label(_offer, "New Jelly powers!", 25)
	_offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_jelly.disabled = true
	_offer_jelly.focus_mode = Control.FOCUS_NONE
	_offer_jelly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer.add_child(_offer_jelly)
	_offer_caption = _label(_offer, "", 16)
	_offer_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offer_accept.text = "Upgrade Jellies"
	_offer.add_child(_offer_accept)
	_offer_accept.pressed.connect(func() -> void:
		if _active and not _offer_accept.disabled:
			intro_accepted.emit())
	_offer_later.text = "Not now"
	_offer.add_child(_offer_later)
	_offer_later.pressed.connect(func() -> void:
		if _active and not _offer_later.disabled:
			intro_dismissed.emit())
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			stop_charging()
			_settle_showcase()
		_animate_wallet())
	hide()

func _texture(control: TextureRect, texture: Texture2D, parent: Node) -> void:
	control.texture = texture
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)

func _label(parent: Node, text: String, pixels: int) -> Label:
	var label: Label = Style.label(text, pixels)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func present(state: Dictionary, word: Dictionary, steady: bool, selected: int = 0, offer: bool = false) -> bool:
	stop_charging()
	_state = state.duplicate(true)
	_word = word.duplicate(true)
	_reduced = steady
	_offering = offer
	_kind = "jelly"
	_selected = clampi(selected if selected > 0 else mini(9, _owned_level() + 1), 1, 9)
	_displayed_level = _selected
	_level_reveal_pending = false
	_visual_progress = _target_progress()
	_reset_rail()
	_pending_milestone = false
	_payoff = 0.0
	_pulse = 0.0
	_preview_wait = 0.0
	_charge_energy = 0.0
	_wallet_energy = 0.0
	_visual_balance = float(_state.get("balance", 0))
	_update_wallet_text()
	if not _present_preview():
		return false
	if offer:
		_offer_jelly.configure(_tile_data(2), SKIN, WordArt.texture(str(word.get("image", "")), self), null, Style.GOOD, true)
		_offer_jelly.set_merged_presentation(0.0, steady)
	show()
	_refresh()
	_follow_rail.call_deferred()
	default_focus().grab_focus.call_deferred()
	return true

func configure(state: Dictionary) -> void:
	var previous_balance: int = int(_state.get("balance", 0))
	var committed_kind := ""
	var level_changed := false
	for kind: String in ["jelly", "auto_merge"]:
		var key: String = "level" if kind == "jelly" else "auto_merge_level"
		var advanced: bool = int(state.get(key, 1)) > int(_state.get(key, 1))
		if advanced or int(state.get("funded", {}).get(kind, 0)) > int(_state.get("funded", {}).get(kind, 0)):
			committed_kind = kind
			level_changed = advanced
	_state = state.duplicate(true)
	var balance: int = int(_state.get("balance", 0))
	if balance > previous_balance or not is_visible_in_tree() or not _active or _offering:
		_visual_balance = float(balance)
	elif balance < previous_balance:
		# A saved wallet debit is real even when its funding journal needs recovery.
		_wallet_energy = maxf(_wallet_energy, 0.28)
		audio_requested.emit("upgrade_coin")
	var deposited: bool = not committed_kind.is_empty()
	if deposited and is_visible_in_tree() and _active and not _offering:
		# Recovery follows the paid receipt even if another power was inspected.
		if committed_kind != _kind:
			stop_charging()
			_kind = committed_kind
			_selected = mini(9, _owned_level() + 1)
			_visual_progress = _target_progress()
			_reset_rail()
			_present_preview()
			_follow_rail.call_deferred()
		_deposit_count += 1
		_pulse = 1.0
		if level_changed:
			_level_up_count += 1
			_preview_wait = 0.9
			_set_displayed_level(mini(_displayed_level, _owned_level() - 1))
			_reveal_level = _owned_level()
			_level_reveal_pending = true
			if _selected != _owned_level():
				_selected = _owned_level()
				_present_preview()
			_pending_milestone = true
			_milestone_progress = float(_owned_level() - 1)
			_follow_rail.call_deferred()
	# Receipts overlap their approaches, retaining motion between saved debits.
	_set_rail_target(_target_progress(), 0.30)
	if _pending_milestone and _reduced:
		_begin_milestone()
	if not _can_charge():
		stop_charging()
	_refresh()

func close() -> void:
	stop_charging()
	hide()

func is_offer() -> bool:
	return _offering

func select_level(level: int) -> void:
	if not _active or _offering or not is_visible_in_tree() or bool(_state.get("busy", false)) or level < 1 or level > 9:
		return
	stop_charging()
	_pending_milestone = false
	_payoff = 0.0
	_pulse = 0.0
	_preview_wait = 0.0
	_selected = level
	_displayed_level = level
	_level_reveal_pending = false
	_present_preview()
	_refresh()
	changed.emit()

func select_upgrade(kind: String) -> void:
	if not _active or _offering or not is_visible_in_tree() or bool(_state.get("busy", false)) or not _category_buttons.has(kind) or kind == _kind:
		return
	stop_charging()
	_pending_milestone = false
	_kind = kind
	_payoff = 0.0
	_pulse = 0.0
	_preview_wait = 0.0
	_selected = mini(9, _owned_level() + 1)
	_displayed_level = _selected
	_level_reveal_pending = false
	_visual_progress = _target_progress()
	_reset_rail()
	_present_preview()
	_refresh()
	_follow_rail.call_deferred()
	changed.emit()

func _tile_data(level: int) -> Dictionary:
	return {"id": 1001, "word": _word, "text": _word.get("text", ""), "jelly_kind": "merged", "merge_level": level, "fragments": 0, "merged_level_limit": 9}

func _present_preview() -> bool:
	if _word.is_empty():
		return false
	var valid: bool = _preview.present_auto_merge(_selected, _word, _reduced) if _kind == "auto_merge" else _preview.present(_selected, _word, _reduced)
	_picture = WordArt.texture(str(_word.get("image", "")), self)
	_hero.configure(_tile_data(_displayed_level), SKIN, _picture, null, Style.GOOD, true)
	_hero._level_badge.hide()
	_hero.set_merged_presentation(0.0, _reduced)
	_hero.visible = _kind == "jelly"
	_wand.visible = _kind == "auto_merge"
	_preview.set_charge_feedback(_charge_energy, _pulse)
	_preview.set_upgrade_feedback(_payoff)
	return valid

func _set_displayed_level(level: int) -> void:
	var next: int = clampi(level, 1, 9)
	if next != _displayed_level:
		_displayed_level = next
		_hero.configure(_tile_data(next), SKIN, _picture, null, Style.GOOD, true)
		_hero._level_badge.hide()
	_tier.text = "Lv %d" % _displayed_level
	_name.text = "Auto merge" if _kind == "auto_merge" else Preview.NAMES[_displayed_level]

func _reveal_earned_level() -> void:
	_level_reveal_pending = false
	_set_displayed_level(_reveal_level)

func _settle_showcase() -> void:
	_pending_milestone = false
	_level_reveal_pending = false
	_payoff = 0.0
	_pulse = 0.0
	_preview_wait = 0.0
	_charge_energy = 0.0
	_set_displayed_level(_selected)
	_preview.set_charge_feedback(0.0, 0.0)
	_preview.set_upgrade_feedback(0.0)
	_animate_subject()

func _owned_level() -> int:
	return int(_state.get("auto_merge_level" if _kind == "auto_merge" else "level", 1))

func _funded() -> int:
	return int(_state.get("funded", {}).get(_kind, 0))

func _price() -> int:
	return Economy.permanent_upgrade_price(_kind, _owned_level() + 1) if _owned_level() < 9 else 0

func _target_progress() -> float:
	return float(_owned_level() - 1) + (float(_funded()) / _price() if _price() > 0 else 0.0)

func _can_charge() -> bool:
	return _active and is_visible_in_tree() and not _offering and _owned_level() < 9 \
		and int(_state.get("balance", 0)) >= PULSE_AMOUNT and not bool(_state.get("busy", false)) \
		and str(_state.get("error", "")).is_empty() and not bool(_state.get("retry", false)) \
		and _state.get("pending", {}).is_empty()

func start_charging() -> void:
	if _charging or not _can_charge():
		return
	# A quick release and repress preserves the earned level through its payoff.
	var celebrating: bool = _pending_milestone or _payoff > 0.0
	var selected: int = _owned_level() if celebrating else mini(9, _owned_level() + 1)
	if not celebrating:
		_preview_wait = 0.0
	if _selected != selected:
		_selected = selected
		_present_preview()
	if not celebrating:
		_set_displayed_level(_owned_level())
	_charging = true
	_rail_scroll_offset = float(_scroll.scroll_horizontal)
	_charge_energy = maxf(_charge_energy, 0.28)
	_charge_wait = HOLD_LEAD
	charging_changed.emit(true)
	_refresh()
	_effects.queue_redraw()
	_follow_rail()
	changed.emit()

func stop_charging() -> void:
	var was_charging: bool = _charging
	_charging = false
	_charge_wait = 0.0
	if was_charging:
		charging_changed.emit(false)
		changed.emit()


func retry_saving() -> void:
	if _active and is_visible_in_tree() and not _offering and not _buy.disabled and bool(_state.get("retry", false)):
		retry_requested.emit()

func _input(event: InputEvent) -> void:
	if not _charging:
		return
	if event is InputEventMouseButton and not event.pressed:
		stop_charging()
	elif event is InputEventScreenTouch and not event.pressed:
		stop_charging()
	elif event is InputEventScreenDrag and not _buy.get_global_rect().has_point(event.position):
		stop_charging()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		stop_charging()

func _refresh() -> void:
	var owned: int = _owned_level()
	var busy: bool = bool(_state.get("busy", false)) or not _active
	var error: String = str(_state.get("error", ""))
	_update_wallet_text()
	_wallet.accessibility_name = "%d saved coins" % int(_state.get("balance", 0))
	_tier.text = "Lv %d" % _displayed_level
	_name.text = "Auto merge" if _kind == "auto_merge" else Preview.NAMES[_displayed_level]
	_description.text = "%d ready Jellies" % Economy.auto_merge_capacity(_selected) if _kind == "auto_merge" \
		else "%d nearby Jellies" % _preview.snapshot().target_count
	_benefits.text = "Lv %d  >  Lv %d" % [owned, mini(9, owned + 1)] if owned < 9 else "Lv 9"
	_benefits.accessibility_name = _preview.coin_description()
	for kind: String in _category_buttons:
		var category: Button = _category_buttons[kind]
		category.disabled = busy
		category.accessibility_name = "%s upgrades. Current Lv%d" % [category.text, int(_state.get("auto_merge_level" if kind == "auto_merge" else "level", 1))]
	for tab: Dictionary in _tabs:
		tab.button.disabled = busy
		tab.button.accessibility_name = "Preview Lv%d. %s" % [tab.level, "Owned" if int(tab.level) <= owned else "Locked"]
	_update_funding_text()
	_progress.accessibility_name = "%d of %d coins saved toward Lv%d. %d coins remaining." % [_funded(), _price(), mini(9, owned + 1), maxi(0, _price() - _funded())]
	if owned == 9:
		_progress.accessibility_name = "Lv9. All milestones complete."
	_buy.disabled = not _can_charge()
	_buy.text = "    Hold to charge" if owned < 9 else "Lv 9"
	if bool(_state.get("retry", false)) and not busy:
		_buy.disabled = false
		_buy.text = "Retry saving"
	_buy.accessibility_name = "Hold to invest coins toward Lv%d. Release to stop. %s" % [mini(9, owned + 1), _progress.accessibility_name] if not bool(_state.get("retry", false)) else "Retry saving. Your paid coins will not be charged again."
	_notice.text = error
	_notice.add_theme_color_override("font_color", Style.WRONG)
	_offer_caption.text = error if not error.is_empty() else "%d coins saved.\nHold to charge your first Jelly power." % int(_state.get("balance", 0))
	_offer_accept.disabled = busy
	_offer_later.disabled = busy
	_back.disabled = busy
	for control: Control in [_sky, _back, _heading, _wallet, _wallet_icon, _categories, _stage, _footer, _effects]:
		control.visible = not _offering
	_shade.visible = _offering
	_offer.visible = _offering
	if _layout_state != _presentation_layout_state():
		_layout()
	_layout_funding()
	_levels.queue_redraw()
	_effects.queue_redraw()
	_animate_wallet()

func set_active(value: bool) -> void:
	_active = value
	if not value:
		stop_charging()
		_settle_showcase()
	_refresh()

func set_reduced_motion(value: bool) -> void:
	_reduced = value
	_preview.set_reduced_motion(value)
	_hero.set_merged_presentation(0.0, value)
	_offer_jelly.set_merged_presentation(0.0, value)
	if value:
		_visual_progress = _target_progress()
		_reset_rail()
		if _pending_milestone:
			_begin_milestone()
		elif _level_reveal_pending:
			_reveal_earned_level()
	_update_funding_text()
	_animate_subject()
	_animate_wallet()
	_effects.queue_redraw()

func _update_wallet_text() -> void:
	var text: String = str(roundi(_visual_balance))
	if _wallet.text != text:
		_wallet.text = text
		_layout_wallet()

func _layout_wallet() -> void:
	if _wallet_right <= 0.0:
		return
	var u: float = 1.0 / Style.ui_scale(self)
	var font: Font = _wallet.get_theme_font("font")
	var pixels: int = _wallet.get_theme_font_size("font_size")
	var width: float = font.get_string_size(_wallet.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	_wallet.position = Vector2(_wallet_right - width, 12 * u)
	_wallet.size = Vector2(width, 44 * u)
	_wallet.pivot_offset = Vector2(width, _wallet.size.y * 0.5)
	_wallet_icon.position = Vector2(_wallet.position.x - 6 * u - _wallet_icon.size.x, 22 * u)
	var row: float = font.get_height(pixels)
	_wallet_roll.position = _wallet.position + Vector2(0, (_wallet.size.y - row) * 0.5)
	_wallet_roll.size = Vector2(width, row)

func _reset_rail() -> void:
	_rail_from = _visual_progress
	_rail_to = _visual_progress
	_rail_velocity = 0.0
	_rail_start_velocity = 0.0
	_rail_time = _rail_duration

func _set_rail_target(target: float, duration: float) -> void:
	if _reduced:
		_visual_progress = target
		_reset_rail()
		return
	if is_equal_approx(target, _rail_to):
		return
	_rail_from = _visual_progress
	_rail_to = target
	_rail_duration = duration
	_rail_time = 0.0
	var distance: float = _rail_to - _rail_from
	_rail_start_velocity = clampf(_rail_velocity, 0.0, maxf(0.0, 3.0 * distance / duration))

func _advance_rail(step: float) -> void:
	if _rail_time < _rail_duration:
		_rail_time = minf(_rail_duration, _rail_time + step)
		var t: float = _rail_time / _rail_duration
		var t2: float = t * t
		var t3: float = t2 * t
		var tangent: float = _rail_start_velocity * _rail_duration
		_visual_progress = (2 * t3 - 3 * t2 + 1) * _rail_from + (t3 - 2 * t2 + t) * tangent + (-2 * t3 + 3 * t2) * _rail_to
		_rail_velocity = ((6 * t2 - 6 * t) * _rail_from + (3 * t2 - 4 * t + 1) * tangent + (-6 * t2 + 6 * t) * _rail_to) / _rail_duration
		if _rail_time >= _rail_duration:
			_visual_progress = _rail_to
			_rail_velocity = 0.0
	if _pending_milestone and _visual_progress >= _milestone_progress - 0.000001:
		_begin_milestone()

func _begin_milestone() -> void:
	_pending_milestone = false
	_payoff = 1.0
	if _reduced and _level_reveal_pending:
		_reveal_earned_level()
	audio_requested.emit("goal_complete")

func _advance_charge_feedback(step: float) -> void:
	# Retarget the continuous envelopes instead of restarting a tween per debit.
	var blend: float = 1.0 - exp(-step * 14.0)
	_charge_energy = lerpf(_charge_energy, 1.0 if _charging else 0.0, blend)
	var balance: float = float(_state.get("balance", 0))
	var decreasing: bool = _visual_balance > balance + 0.15
	_wallet_energy = lerpf(_wallet_energy, 1.0 if decreasing else 0.0, blend)
	if decreasing:
		_visual_balance = maxf(balance, lerpf(_visual_balance, balance, 1.0 - exp(-step * 12.0)))
	else:
		_visual_balance = balance
	_update_wallet_text()
	_animate_wallet()

func _animate_wallet() -> void:
	_wallet.modulate = Color.WHITE.lerp(Color("#b47722"), _wallet_energy * 0.68)
	_wallet_roll.visible = _active and is_visible_in_tree() and not _offering and not _reduced \
		and _visual_balance > float(_state.get("balance", 0)) + 0.001
	_wallet.self_modulate.a = 0.0 if _wallet_roll.visible else 1.0
	_wallet_roll.queue_redraw()
	var scale_amount: float = 1.0 if _reduced else 1.0 + _wallet_energy * (0.045 + sin(_elapsed * 10.0) * 0.018)
	_wallet_icon.scale = Vector2.ONE * scale_amount

func _draw_wallet_digits() -> void:
	if not _wallet_roll.visible:
		return
	var font: Font = _wallet.get_theme_font("font")
	var pixels: int = _wallet.get_theme_font_size("font_size")
	var digits: int = str(ceili(_visual_balance)).length()
	var cell: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var row: float = font.get_height(pixels)
	var baseline: float = (_wallet_roll.size.y - row) * 0.5 + font.get_ascent(pixels)
	var color: Color = Style.INK.lerp(GOLD_DARK, _wallet_energy * 0.9)
	# Retain a single clipped number strip; no nodes or tweens are created per tick.
	for index in range(digits):
		var place: float = pow(10.0, digits - index - 1)
		var value: float = _visual_balance / place
		var digit: int = floori(value) % 10
		var offset: float = clampf((fmod(value, 1.0) - (1.0 - 1.0 / place)) * place, 0.0, 1.0)
		var at := Vector2(_wallet_roll.size.x - (digits - index) * cell, baseline - offset * row)
		if index > 0 or digit > 0 or digits == 1:
			_wallet_roll.draw_string(font, at, str(digit), HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)
		if offset > 0.0:
			_wallet_roll.draw_string(font, at + Vector2(0, row), str((digit + 1) % 10),
				HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Color(color, offset))

func advance(delta: float) -> void:
	if not _active or not is_visible_in_tree() or _offering or not is_finite(delta) or delta <= 0.0:
		return
	# Resuming a suspended page must never replay missed spending pulses.
	if delta > 0.25:
		stop_charging()
	var step: float = minf(delta, 0.05)
	_elapsed += step
	_pulse = maxf(0.0, _pulse - step * 4.5)
	_payoff = maxf(0.0, _payoff - step / 0.9)
	if _level_reveal_pending and not _pending_milestone and _payoff <= 1.0 - 0.10 / 0.9:
		_reveal_earned_level()
	_preview.advance(step)
	if _preview_wait > 0.0:
		_preview_wait = maxf(0.0, _preview_wait - step)
	if _preview_wait <= 0.0 and _charging and not _pending_milestone and _payoff <= 0.0:
		var next_level: int = mini(9, _owned_level() + 1)
		if _selected != next_level:
			_selected = next_level
			_present_preview()
			_refresh()
	_advance_rail(step)
	_update_funding_text()
	_advance_rail_scroll(step)
	if _charging:
		if not _can_charge():
			stop_charging()
		else:
			_charge_wait -= step
			if _charge_wait <= 0.0:
				_charge_wait = lerpf(0.23, 0.14, float(_funded()) / maxf(1.0, _price()))
				var before: float = _target_progress()
				contribution_requested.emit(_kind, PULSE_AMOUNT)
				if is_equal_approx(before, _target_progress()):
					stop_charging()
	_advance_charge_feedback(step)
	_preview.set_charge_feedback(_charge_energy, _pulse)
	_preview.set_upgrade_feedback(_payoff)
	_animate_subject()
	_stage.queue_redraw()
	_levels.queue_redraw()
	_effects.queue_redraw()

func _animate_subject() -> void:
	var squash: float = _pulse * 0.012 + _charge_energy * (0.012 + sin(_elapsed * 7.0) * 0.012)
	var lift: float = _hero_edge * _charge_energy * (0.020 + sin(_elapsed * 7.0) * 0.008)
	var tier_scale := Vector2.ONE
	if _payoff > 0.0 and not _reduced:
		var t: float = 1.0 - _payoff
		squash += 0.16 * exp(-t * 18.0) - sin(t * TAU * 1.4) * exp(-t * 5.0) * 0.23
		lift += sin(minf(1.0, t * 1.5) * PI) * _hero_edge * 0.14
		var seconds: float = t * 0.9
		if seconds < 0.1:
			tier_scale = Vector2(1.0 + seconds * 1.5, 1.0 - seconds * 7.0)
		else:
			var reveal: float = seconds - 0.1
			tier_scale = Vector2.ONE * (1.0 + sin(reveal * 14.0) * exp(-reveal * 7.0) * 0.32)
			tier_scale.y *= minf(1.0, 0.30 + reveal * 13.0)
	if _reduced:
		squash = 0.0
		lift = 0.0
	lift = minf(lift, _hero_lift_room)
	_hero.scale = Vector2(1.0 + squash, 1.0 - squash)
	_hero.position = _hero_base - Vector2(0, lift)
	_wand.position = _hero_base + Vector2(_hero_edge * 0.48, -_hero_edge * 0.04) - Vector2(0, lift)
	_wand.rotation = 0.0 if _reduced else sin(_elapsed * 2.0) * 0.05 + _pulse * 0.09
	_tier.scale = tier_scale
	_tier.modulate = Color.WHITE.lerp(Color("#b9771b"), minf(1.0, _payoff * 1.5))
	_hero.set_merged_presentation(0.0 if _reduced else _elapsed, _reduced)

func _follow_rail() -> void:
	if _rail_pitch > 0.0 and not _charging:
		_scroll.scroll_horizontal = roundi(maxf(0.0, (_owned_level() - 1.6) * _rail_pitch - _scroll.size.x * 0.23))
		_rail_scroll_offset = float(_scroll.scroll_horizontal)

func _advance_rail_scroll(step: float) -> void:
	if not _charging:
		return
	var maximum: float = maxf(0.0, _levels.size.x - _scroll.size.x)
	var target: float = clampf(_rail_origin.x + _visual_progress * _rail_pitch - _scroll.size.x * 0.62, 0.0, maximum)
	_rail_scroll_offset = lerpf(_rail_scroll_offset, target, 1.0 - exp(-step * 10.0))
	_scroll.scroll_horizontal = roundi(_rail_scroll_offset)

func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if not is_visible_in_tree() or not _active:
		return controls
	if _offering:
		return [_offer_accept, _offer_later]
	controls.append(_back)
	for category: Button in _category_buttons.values():
		if not category.disabled:
			controls.append(category)
	for tab: Dictionary in _tabs:
		if not tab.button.disabled:
			controls.append(tab.button)
	if not _buy.disabled:
		controls.append(_buy)
	return controls

func default_focus() -> Control:
	if _offering:
		return _offer_accept
	return _buy if not _buy.disabled else _back

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _notice == null:
		return
	var u: float = 1.0 / Style.ui_scale(self)
	_rail_unit = u
	_layout_state = _presentation_layout_state()
	_layout_count += 1
	_rail_base_style = Style.box(Color("#6987ab"), Color("#c7dbed"), ceili(7 * u), ceili(u))
	_rail_base_style.shadow_color = Color("#476480", 0.22)
	_rail_base_style.shadow_size = ceili(u)
	_rail_base_style.shadow_offset = Vector2(0, 2 * u)
	_rail_fill_style = Style.box(GOLD, Color("#fff4c2"), ceili(7 * u), ceili(u))
	var width: float = minf(size.x - 32.0 * u, 940.0 * u)
	var left: float = (size.x - width) * 0.5
	var short: bool = size.y < 620.0 * u
	var landscape: bool = short and size.x > size.y
	_sky.size = size
	_back.position = Vector2(left, 12 * u)
	Style.action_button(_back, Style.GOOD)
	_back.custom_minimum_size = Vector2.ZERO
	_back.size = Vector2(64, 44) * u
	_wallet_icon.size = Vector2.ONE * 25 * u
	_wallet_icon.pivot_offset = _wallet_icon.size * 0.5
	_wallet.add_theme_font_size_override("font_size", ceili(20 * u))
	_wallet_right = left + width
	_layout_wallet()
	_heading.position = Vector2(left + 76 * u, 12 * u)
	_heading.text = "Upgrades" if width < 340 * u else "Jelly Upgrades"
	_heading.size = Vector2(maxf(1.0, width - 184 * u), 44 * u)
	_heading.add_theme_font_size_override("font_size", ceili((18 if width < 500 * u else 26) * u))
	_categories.size = Vector2(minf(width, 420 * u), 44 * u)
	_categories.position = Vector2((size.x - _categories.size.x) * 0.5, 68 * u)
	var category_index := 0
	for kind: String in _category_buttons:
		var category: Button = _category_buttons[kind]
		Style.action_button(category, Style.GOOD)
		var fill: Color = Color("#fff9e6") if kind == _kind else Color(Style.PAPER, 0.45)
		category.add_theme_stylebox_override("normal", Style.box(fill, Color.TRANSPARENT, ceili(22 * u), 0))
		category.custom_minimum_size = Vector2.ZERO
		category.position = Vector2(category_index * (_categories.size.x + 8 * u) * 0.5, 0)
		category.size = Vector2((_categories.size.x - 8 * u) * 0.5, 44 * u)
		category.add_theme_font_size_override("font_size", ceili(15 * u))
		category_index += 1
	var error_height: float = 44 * u if not _notice.text.is_empty() else 0.0
	_footer.size = Vector2(width * 0.48 if landscape else width, (184 if short else 214) * u + error_height)
	_footer.position = Vector2(left, size.y - _footer.size.y - 12 * u)
	if landscape:
		_footer.position.x = left + width - _footer.size.x
	_stage.position = Vector2(left, (112 if short else 126) * u)
	_stage.size = Vector2(width * 0.48 if landscape else width,
		maxf(90 * u, (size.y - 12 * u if landscape else _footer.position.y - 8 * u) - _stage.position.y))
	var body_width: float = _stage.size.x
	var footer_width: float = _footer.size.x
	_tier.add_theme_font_size_override("font_size", ceili((24 if short else 36) * u))
	_name.add_theme_font_size_override("font_size", ceili((15 if short else 20) * u))
	var tier_height: float = maxf((28 if short else 42) * u, _tier.get_minimum_size().y)
	var name_height: float = maxf((22 if short else 28) * u, _name.get_minimum_size().y)
	var title_height: float = tier_height + name_height + (4 if short else 8) * u
	var caption_height: float = 0.0 if short else 38 * u
	var art_height: float = minf(282 * u, maxf(42 * u, _stage.size.y - title_height - caption_height))
	var top: float = maxf(0.0, (_stage.size.y - title_height - art_height - caption_height) * 0.5)
	var gap: float = clampf(body_width * 0.045, 12 * u, 32 * u)
	var group_width: float = minf(body_width, 540 * u)
	_hero_edge = minf(256 * u, minf((group_width - gap) * 0.51, art_height * 0.86))
	var preview_width: float = minf(240 * u, minf(group_width - gap - _hero_edge, art_height / 1.10))
	group_width = _hero_edge + gap + preview_width
	art_height = maxf(_hero_edge, preview_width * 1.10)
	top = maxf(0.0, (_stage.size.y - title_height - art_height - caption_height) * 0.5)
	var group_left: float = (body_width - group_width) * 0.5
	_tier.position = Vector2(group_left, top)
	_tier.size = Vector2(_hero_edge, tier_height)
	_tier.pivot_offset = _tier.size * 0.5
	_name.position = Vector2(maxf(0.0, group_left - 8 * u), top + tier_height + 2 * u)
	_name.size = Vector2(_hero_edge + 16 * u, name_height)
	_hero_base = Vector2(group_left, top + title_height + (art_height - _hero_edge) * 0.5)
	_hero_lift_room = maxf(0.0, _hero_base.y - (_name.position.y + _name.size.y) - 3 * u)
	_hero.size = Vector2.ONE * _hero_edge
	_hero._level_badge.hide()
	_hero.pivot_offset = _hero.size * 0.5
	_wand.size = _hero.size * 0.36
	_wand.pivot_offset = _wand.size * 0.5
	_preview.size = Vector2(preview_width, preview_width * 1.10)
	_preview.position = Vector2(group_left + _hero_edge + gap, top + title_height + (art_height - _preview.size.y) * 0.5)
	_preview_label.hide()
	_description.position = Vector2(_preview.position.x - 8 * u, top + title_height + art_height + 6 * u)
	_description.size = Vector2(_preview.size.x + 16 * u, 28 * u)
	_description.add_theme_font_size_override("font_size", ceili(17 * u))
	_benefits.position = Vector2(0, _stage.size.y - 32 * u)
	_benefits.size = Vector2(body_width, 24 * u)
	_benefits.add_theme_font_size_override("font_size", ceili(13 * u))
	_description.visible = not short
	_benefits.hide()
	_scroll.position = Vector2.ZERO
	_scroll.size = Vector2(footer_width, (80 if short else 88) * u)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_rail_pitch = maxf(58 * u, (footer_width - 56 * u) / 8.0)
	_levels.custom_minimum_size = Vector2(_rail_pitch * 8 + 56 * u, 76 * u)
	_levels.size = _levels.custom_minimum_size
	_rail_origin = Vector2(28 * u, 56 * u)
	for tab: Dictionary in _tabs:
		var button: Button = tab.button
		_style_level_button(button, int(tab.level), u)
		button.position = Vector2(6 * u + (int(tab.level) - 1) * _rail_pitch, 0)
		button.size = Vector2.ONE * 44 * u
	_progress.position = Vector2((footer_width - 156 * u) * 0.5, (80 if short else 88) * u)
	_progress.size = Vector2(180, 32) * u
	_progress.add_theme_font_size_override("font_size", ceili(19 * u))
	_progress_coin.position = Vector2(_progress.position.x - 4 * u, _progress.position.y + 5 * u)
	_progress_coin.size = Vector2.ONE * 22 * u
	_layout_funding()
	_buy.size = Vector2(minf(308 * u, footer_width), (60 if short else 70) * u)
	_buy.position = Vector2((footer_width - _buy.size.x) * 0.5, (120 if short else 130) * u)
	_style_charge_button(u)
	_buy_coin.position = Vector2(_buy.size.x * 0.5 - 104 * u, (_buy.size.y - 32 * u) * 0.5 - 2 * u)
	_buy_coin.size = Vector2.ONE * 32 * u
	_buy_coin.visible = _owned_level() < 9 and not bool(_state.get("retry", false))
	_notice.position = Vector2(0, _buy.position.y + _buy.size.y + 4 * u)
	_notice.size = Vector2(footer_width, 42 * u)
	_notice.visible = not _notice.text.is_empty()
	_notice.add_theme_font_size_override("font_size", ceili(12 * u))
	_effects.size = size
	_shade.size = size
	_layout_offer(u)
	_animate_subject()
	_stage.queue_redraw()
	_levels.queue_redraw()
	_effects.queue_redraw()

func _presentation_layout_state() -> Array:
	return [_kind, _selected, _owned_level(), _offering, not _notice.text.is_empty(),
		bool(_state.get("retry", false)), Style.ui_scale(self)]

func _layout_funding() -> void:
	if _footer.size.x <= 0.0:
		return
	var u: float = _rail_unit
	var font: Font = _progress.get_theme_font("font")
	var pixels: int = _progress.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(_progress.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var icon_width: float = 28 * u if _progress_coin.visible else 0.0
	var left: float = (_footer.size.x - text_width - icon_width) * 0.5
	_progress.size.x = text_width
	_progress.position.x = left + icon_width
	_progress_coin.position = Vector2(left, _progress.position.y + 5 * u)

func _update_funding_text() -> void:
	# The numeral and fill describe the same acknowledged segment during its glide.
	var level: int = clampi(floori(_visual_progress + 0.0000001) + 1, 1, _owned_level())
	var price: int = Economy.permanent_upgrade_price(_kind, level + 1) if level < 9 else 0
	var amount: int = clampi(roundi((_visual_progress - float(level - 1)) * price), 0, price)
	var text: String = "%d / %d" % [amount, price] if level < 9 else "Lv 9"
	if _progress.text != text or _progress_coin.visible != (level < 9):
		_progress.text = text
		_progress_coin.visible = level < 9
		_layout_funding()

func _style_level_button(button: Button, level: int, u: float) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2.ZERO
	button.add_theme_font_override("font", Style.HEADING_FONT)
	button.add_theme_font_size_override("font_size", ceili(16 * u))
	for mode: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
	var focus: StyleBoxFlat = Style.box(Color.TRANSPARENT, Color(GOLD_DARK, 0.65), ceili(10 * u), ceili(u))
	focus.set_content_margin_all(0.0)
	button.add_theme_stylebox_override("focus", focus)
	var ink: Color = GOLD_DARK if level == _selected else Style.INK if level <= _owned_level() else Color("#536e8f")
	button.add_theme_color_override("font_color", ink)
	for mode: String in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(mode, GOLD_DARK)
	button.add_theme_color_override("font_disabled_color", Style.MUTED)

func _style_charge_button(u: float) -> void:
	Style.action_button(_buy, GOLD_DARK)
	_buy.custom_minimum_size = Vector2.ZERO
	_buy.add_theme_font_size_override("font_size", ceili(19 * u))
	_buy.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Color("#fff1bd"), ceili(25 * u), ceili(3 * u)))
	for mode: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = Color("#ffdc72") if mode == "normal" else Color("#ffe79d") if mode == "hover" else Color("#f5c24d") if mode == "pressed" else Color("#cfceba")
		var skin: StyleBoxFlat = Style.box(fill, Color("#aa752c") if mode != "disabled" else Color("#a7ac9a"), ceili(25 * u), ceili(2 * u))
		skin.shadow_color = Color("#805932")
		skin.shadow_size = ceili(u)
		skin.shadow_offset = Vector2(0, 3 if mode == "pressed" else 7) * u
		_buy.add_theme_stylebox_override(mode, skin)
		_buy.add_theme_color_override("font_" + ("color" if mode == "normal" else mode + "_color"), Color("#61451e"))

func _layout_offer(u: float) -> void:
	_offer.size = Vector2(minf(440 * u, size.x - 28 * u), minf(398 * u, size.y - 24 * u))
	_offer.position = (size - _offer.size) * 0.5
	_offer.add_theme_stylebox_override("panel", Style.box(Style.PAPER, Style.GOOD.lightened(0.65), ceili(22 * u), 1))
	var inner: float = _offer.size.x - 32 * u
	_offer_title.position = Vector2(16, 14) * u
	_offer_title.size = Vector2(inner, 36 * u)
	_offer_title.add_theme_font_size_override("font_size", ceili(24 * u))
	var edge: float = minf(104 * u, maxf(44 * u, _offer.size.y - 252 * u))
	_offer_jelly.position = Vector2((_offer.size.x - edge) * 0.5, 58 * u)
	_offer_jelly.size = Vector2.ONE * edge
	_offer_caption.position = Vector2(16 * u, 64 * u + edge)
	_offer_caption.size = Vector2(inner, maxf(44 * u, _offer.size.y - edge - 190 * u))
	_offer_caption.add_theme_font_size_override("font_size", ceili(15 * u))
	_offer_accept.position = Vector2(16 * u, _offer.size.y - 112 * u)
	_offer_accept.size = Vector2(inner, 44 * u)
	_offer_later.position = Vector2(16 * u, _offer.size.y - 58 * u)
	_offer_later.size = Vector2(inner, 44 * u)
	Style.action_button(_offer_accept, Style.GOOD, true)
	Style.action_button(_offer_later, Style.GOOD)

func _draw_stage() -> void:
	var center: Vector2 = _hero_base + Vector2.ONE * _hero_edge * 0.5
	var charge: float = float(_funded()) / maxf(1.0, _price())
	var breath: float = 1.0 if _reduced else 0.92 + sin(_elapsed * 7.0) * 0.08
	var energy: float = _charge_energy * breath
	var edge: float = _hero_edge * (1.40 + energy * 0.40 + _payoff * 0.25)
	_stage.draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false,
		Color(1.0, 0.86 + charge * 0.08, 0.44, 0.24 + energy * 0.60 + _payoff * 0.36))
	var footing: Vector2 = _hero_base + Vector2(_hero_edge * 0.5, _hero_edge * 0.94)
	var ground := Vector2(_hero_edge * (1.35 + energy * 0.15), _hero_edge * 0.24)
	_stage.draw_texture_rect(GLOW, Rect2(footing - ground * 0.5, ground), false,
		Color(1.0, 0.91, 0.52, 0.38 + energy * 0.35))
	if energy > 0.01:
		var charge_edge: float = _hero_edge * 1.62
		_stage.draw_set_transform(center, 0.0 if _reduced else _elapsed * 0.16)
		_stage.draw_texture_rect(RAYS, Rect2(-Vector2.ONE * charge_edge * 0.5, Vector2.ONE * charge_edge), false,
			Color(1.0, 0.90, 0.51, energy * (0.16 + charge * 0.12)))
		_stage.draw_set_transform(Vector2.ZERO)
	if _payoff > 0.0:
		var ray_edge: float = _hero_edge * (1.8 if _reduced else 1.65 + (1.0 - _payoff) * 1.25)
		_stage.draw_set_transform(center, 0.0 if _reduced else (1.0 - _payoff) * 0.4)
		_stage.draw_texture_rect(RAYS, Rect2(-Vector2.ONE * ray_edge * 0.5, Vector2.ONE * ray_edge), false, Color(1.0, 0.96, 0.72, minf(1.0, _payoff * 1.5)))
		_stage.draw_set_transform(Vector2.ZERO)
	if _kind == "auto_merge":
		_stage.draw_set_transform(_hero.position + Vector2.ONE * _hero_edge * 0.5, 0.0, _hero.scale)
		var jelly_edge: float = _hero_edge * 0.60
		for offset: Vector2 in [Vector2(-0.25, -0.15), Vector2(0.25, -0.15), Vector2(0, 0.22)]:
			var at: Vector2 = offset * _hero_edge
			_stage.draw_texture_rect(SKIN, Rect2(at - Vector2.ONE * jelly_edge * 0.5, Vector2.ONE * jelly_edge), false)
			if _picture != null:
				_stage.draw_texture_rect(_picture, Rect2(at - Vector2.ONE * jelly_edge * 0.30, Vector2.ONE * jelly_edge * 0.60), false)
		_stage.draw_set_transform(Vector2.ZERO)

func _draw_rail() -> void:
	var u: float = _rail_unit
	var rail := Rect2(_rail_origin - Vector2(0, 7 * u), Vector2(_rail_pitch * 8, 14 * u))
	if _rail_base_style == null or _rail_fill_style == null:
		return
	_levels.draw_style_box(_rail_base_style, rail)
	if _visual_progress > 0.0:
		_levels.draw_style_box(_rail_fill_style, Rect2(rail.position, Vector2(maxf(2 * u, _visual_progress * _rail_pitch), rail.size.y)))
		if _charge_energy > 0.01 and not _reduced:
			# Sourced light moves inside the paid segment while the hold remains active.
			var start: float = maxf(0.0, _visual_progress - 1.0) * _rail_pitch
			var span: float = _visual_progress * _rail_pitch - start
			for index in range(3):
				var phase: float = fposmod(_elapsed * 0.72 + float(index) / 3.0, 1.0)
				var point: Vector2 = _rail_origin + Vector2(start + span * phase, 0)
				var extent := Vector2(minf(30 * u, span), 12 * u)
				_levels.draw_texture_rect(GLOW, Rect2(point - extent * 0.5, extent), false,
					Color(1.0, 0.99, 0.81, _charge_energy * sin(phase * PI) * 0.85))
	for level in range(1, 10):
		var at: Vector2 = _rail_origin + Vector2((level - 1) * _rail_pitch, 0)
		var reached: bool = level <= _owned_level()
		_levels.draw_circle(at, 8 * u, GOLD_DARK if reached else Color("#638bb2"))
		_levels.draw_circle(at, 5 * u, Color("#fff4c4") if reached else Color("#c8dcec"))
		if level == _selected:
			_levels.draw_arc(at, 11 * u, 0, TAU, 24, Color("#fff0b4"), 2 * u, true)
		if level == _owned_level() + 1:
			_levels.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * 9 * u, Vector2.ONE * 18 * u), false,
				Color(1, 0.95, 0.64, 0.35 + _charge_energy * 0.35))
	var tip: Vector2 = _rail_origin + Vector2(_visual_progress * _rail_pitch, 0)
	_levels.draw_texture_rect(GLOW, Rect2(tip - Vector2.ONE * 18 * u, Vector2.ONE * 36 * u), false,
		Color(1, 0.87, 0.45, 0.45 + _charge_energy * 0.35))
	if _payoff > 0.0:
		var marker: Vector2 = _rail_origin + Vector2(_milestone_progress * _rail_pitch, 0)
		var edge: float = (20.0 if _reduced else 20.0 + (1.0 - _payoff) * 18.0) * u
		_levels.draw_texture_rect(SPARKLE, Rect2(marker - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false,
			Color(1.0, 0.98, 0.76, _payoff))

func _draw_effects() -> void:
	var u: float = 1.0 / Style.ui_scale(self)
	var center: Vector2 = _stage.position + _hero_base + Vector2.ONE * _hero_edge * 0.5
	_draw_charge_feedback(u)
	if _charge_energy > 0.01:
		for index in range(3 if _reduced else 6):
			var phase: float = 0.45 if _reduced else fposmod(_elapsed * 0.75 + index / 6.0, 1.0)
			var angle: float = index * TAU / (3 if _reduced else 6) + (0.0 if _reduced else phase * 0.28)
			var radius: float = _hero_edge * (0.88 - phase * 0.49)
			var at: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.44) * radius
			var edge: float = (12 + sin(phase * PI) * 12) * u
			_effects.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false,
				Color(1.0, 0.96, 0.64, _charge_energy * (0.45 if _reduced else sin(phase * PI)) * 0.92))
	if _payoff > 0.0:
		var t: float = 1.0 - _payoff
		var flash: float = _payoff * 0.28 if _reduced else exp(-t * 13.0) * 0.70
		var flash_edge: float = _hero_edge * (1.05 if _reduced else 0.8 + t * 1.8)
		_effects.draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * flash_edge * 0.5, Vector2.ONE * flash_edge), false,
			Color(1.0, 0.99, 0.82, flash))
		for index in range(4 if _reduced else 12):
			var angle: float = index * TAU / (4 if _reduced else 12) - PI * 0.5
			var radius: float = _hero_edge * (0.61 if _reduced else 0.40 + (1.0 - pow(1.0 - t, 3.0)) * 0.50)
			var at: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.44) * radius
			var edge: float = (22 if _reduced else 12 + 28 * _payoff) * u
			_effects.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color(1, 0.97, 0.75, _payoff))
		var tier_center: Vector2 = _stage.position + _tier.position + _tier.size * 0.5
		var wipe: float = 0.5 if _reduced else clampf(t * 0.9 / 0.25, 0.0, 1.0)
		var at: Vector2 = tier_center + Vector2(minf(50 * u, _tier.size.x * 0.43) + (wipe - 0.5) * 8 * u, 0)
		var glint_edge: float = (16 if _reduced else 16 + 8 * sin(wipe * PI)) * u
		_effects.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * glint_edge * 0.5, Vector2.ONE * glint_edge), false,
			Color(1.0, 0.97, 0.72, _payoff * (0.5 if _reduced else 1.0 - smoothstep(0.20, 0.40, t))))

func _draw_charge_feedback(u: float) -> void:
	if _charge_energy > 0.01:
		var button_center: Vector2 = _footer.position + _buy.position + _buy.size * 0.5
		var breath: float = 0.82 if _reduced else 0.82 + sin(_elapsed * 7.0) * 0.12
		var glow_size := Vector2(_buy.size.x + 34 * u, _buy.size.y * 1.28)
		_effects.draw_texture_rect(GLOW, Rect2(button_center - glow_size * 0.5, glow_size), false,
			Color(1.0, 0.89, 0.36, _charge_energy * breath * 0.3))
		for index in range(2 if _reduced else 4):
			var phase: float = float(index) / (2 if _reduced else 4)
			if not _reduced:
				phase = fposmod(phase + _elapsed * 0.42, 1.0)
			var at: Vector2 = button_center + Vector2(cos(phase * TAU) * (_buy.size.x * 0.49), sin(phase * TAU) * (_buy.size.y * 0.47))
			var edge: float = (16.0 if _reduced else 13.0 + sin(phase * TAU + _elapsed * 5.0) * 3.0) * u
			_effects.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false,
				Color(1.0, 0.98, 0.72, _charge_energy * 0.95))
	if _wallet_energy > 0.01:
		var at: Vector2 = _wallet_icon.position + _wallet_icon.size * 0.5
		var edge: float = 54 * u
		_effects.draw_texture_rect(GLOW, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false,
			Color(1.0, 0.79, 0.25, _wallet_energy * 0.45))
		var phase: float = 0.0 if _reduced else _elapsed * 3.0
		var glint: Vector2 = at + Vector2(cos(phase) * 13, sin(phase) * 10) * u
		var glint_edge: float = 13 * u
		_effects.draw_texture_rect(SPARKLE, Rect2(glint - Vector2.ONE * glint_edge * 0.5, Vector2.ONE * glint_edge), false,
			Color(1.0, 0.94, 0.56, _wallet_energy))
		var number: Rect2 = _wallet.get_rect()
		var light := Vector2(number.size.x + 14 * u, 30 * u)
		_effects.draw_texture_rect(GLOW, Rect2(number.get_center() - light * 0.5, light), false,
			Color(1.0, 0.84, 0.39, _wallet_energy * 0.22))
		for index in range(2):
			var fall: float = 0.35 if _reduced else fposmod(_elapsed * 1.8 + index * 0.5, 1.0)
			var spark := Vector2(number.position.x + number.size.x * (0.3 + index * 0.45),
				number.get_center().y + (7 + fall * 12) * u)
			var spark_edge: float = (7 - fall * 3) * u
			_effects.draw_texture_rect(SPARKLE, Rect2(spark - Vector2.ONE * spark_edge * 0.5, Vector2.ONE * spark_edge), false,
				Color(1.0, 0.93, 0.57, _wallet_energy * (1.0 - fall)))

func _rect(control: Control) -> Array:
	var rect: Rect2 = control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "mode": "offer" if _offering else "page", "kind": _kind,
		"owned_level": _owned_level(), "auto_merge_level": int(_state.get("auto_merge_level", 1)),
		"selected_level": _selected, "level": int(_state.get("level", 1)), "funded": _funded(),
		"displayed_level": _displayed_level, "level_reveal_pending": _level_reveal_pending,
		"stage": _rect(_stage), "hero": _rect(_hero),
		"funding": _state.get("funded", {}).duplicate(true), "price": _price(),
		"remaining": maxi(0, _price() - _funded()), "charging": _charging,
		"progress": _target_progress(), "visual_progress": _visual_progress,
		"rail": {"origin": [_rail_origin.x, _rail_origin.y], "pitch": _rail_pitch,
			"velocity": _rail_velocity, "marker_progress": _milestone_progress,
			"viewport_rect": _rect(_scroll), "charge_interval": lerpf(0.23, 0.14, float(_funded()) / maxf(1.0, _price()))},
		"level_up_count": _level_up_count, "deposit_count": _deposit_count, "payoff": _payoff,
		"milestone_pending": _pending_milestone,
		"coin_flights": 0, "balance": int(_state.get("balance", 0)), "visual_balance": _visual_balance,
		"charge_energy": _charge_energy, "wallet_energy": _wallet_energy, "layout_count": _layout_count,
		"subject_charge_energy": _charge_energy,
		"wallet_digits_rolling": _wallet_roll.visible,
		"intro": str(_state.get("intro", "unseen")), "error": str(_state.get("error", "")), "notice": _notice.text,
		"preview": _preview.snapshot(), "pending": _state.get("pending", {}).duplicate(true),
		"buy": {"rect": _rect(_buy), "enabled": not _buy.disabled, "text": _buy.text,
			"guided": _kind == "jelly" and _state.get("intro") == "guide" and int(_state.get("level", 1)) == 1},
		"categories": _category_buttons.keys().map(func(kind: String) -> Dictionary:
			return {"kind": kind, "rect": _rect(_category_buttons[kind]), "selected": kind == _kind, "enabled": not _category_buttons[kind].disabled}),
		"back": {"rect": _rect(_back), "enabled": not _back.disabled},
		"offer": {"primary": _rect(_offer_accept), "later": _rect(_offer_later), "caption": _offer_caption.text},
		"levels": _tabs.map(func(tab: Dictionary) -> Dictionary:
			return {"level": tab.level, "rect": _rect(tab.button), "selected": int(tab.level) == _selected, "enabled": not tab.button.disabled})}

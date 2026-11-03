extends Control
## Hold-to-charge presentation. Only committed store state moves the gold rail.

signal back_requested
signal purchase_requested(level: int, kind: String)
signal contribution_requested(kind: String, amount: int)
signal audio_requested(cue: String)
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
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const GOLD := Color("#ffdb6f")
const GOLD_DARK := Color("#a36927")
const PULSE_AMOUNT := 25
const HOLD_LEAD := 0.18

var _state: Dictionary = {}
var _word: Dictionary = {}
var _picture: Texture2D
var _selected := 2
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
var _level_up_count := 0
var _deposit_count := 0
var _coins: Array[Dictionary] = []
var _hero_base := Vector2.ZERO
var _hero_edge := 1.0
var _rail_pitch := 76.0
var _rail_origin := Vector2.ZERO
var _sky := TextureRect.new()
var _back := Button.new()
var _heading: Label
var _wallet: Label
var _wallet_icon := TextureRect.new()
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
			stop_charging())
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
	_visual_progress = _target_progress()
	_payoff = 0.0
	_pulse = 0.0
	_preview_wait = 0.0
	_coins.clear()
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
	var committed_kind := ""
	var level_changed := false
	for kind: String in ["jelly", "auto_merge"]:
		var key: String = "level" if kind == "jelly" else "auto_merge_level"
		var advanced: bool = int(state.get(key, 1)) > int(_state.get(key, 1))
		if advanced or int(state.get("funded", {}).get(kind, 0)) > int(_state.get("funded", {}).get(kind, 0)):
			committed_kind = kind
			level_changed = advanced
	_state = state.duplicate(true)
	var deposited: bool = not committed_kind.is_empty()
	if deposited and is_visible_in_tree() and _active and not _offering:
		# Recovery follows the paid receipt even if another power was inspected.
		if committed_kind != _kind:
			stop_charging()
			_kind = committed_kind
			_selected = mini(9, _owned_level() + 1)
			_visual_progress = _target_progress()
			_present_preview()
			_follow_rail.call_deferred()
		_deposit_count += 1
		_pulse = 1.0
		if not _reduced:
			_coins.append({"age": 0.0, "side": -1.0 if _deposit_count % 2 == 0 else 1.0})
		audio_requested.emit("upgrade_coin")
		if level_changed:
			_visual_progress = _target_progress()
			_level_up_count += 1
			_payoff = 1.0
			_charge_wait = 0.64
			_preview_wait = 0.9
			_selected = _owned_level()
			_present_preview()
			audio_requested.emit("goal_complete")
			_follow_rail.call_deferred()
	if not _can_charge():
		stop_charging()
	_refresh()

func close() -> void:
	stop_charging()
	_coins.clear()
	hide()

func is_offer() -> bool:
	return _offering

func select_level(level: int) -> void:
	if not _active or _offering or not is_visible_in_tree() or bool(_state.get("busy", false)) or level < 1 or level > 9:
		return
	stop_charging()
	_preview_wait = 0.0
	_selected = level
	_present_preview()
	_refresh()
	changed.emit()

func select_upgrade(kind: String) -> void:
	if not _active or _offering or not is_visible_in_tree() or bool(_state.get("busy", false)) or not _category_buttons.has(kind) or kind == _kind:
		return
	stop_charging()
	_kind = kind
	_coins.clear()
	_payoff = 0.0
	_pulse = 0.0
	_preview_wait = 0.0
	_selected = mini(9, _owned_level() + 1)
	_visual_progress = _target_progress()
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
	_hero.configure(_tile_data(_selected), SKIN, _picture, null, Style.GOOD, true)
	_hero.set_merged_presentation(0.0, _reduced)
	_hero.visible = _kind == "jelly"
	_wand.visible = _kind == "auto_merge"
	return valid

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
	_selected = mini(9, _owned_level() + 1)
	_preview_wait = 0.0
	_present_preview()
	_charging = true
	_charge_wait = HOLD_LEAD
	_refresh()
	_follow_rail()
	changed.emit()

func stop_charging() -> void:
	var was_charging: bool = _charging
	_charging = false
	_charge_wait = 0.0
	if was_charging:
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
	_wallet.text = str(int(_state.get("balance", 0)))
	_wallet.accessibility_name = "%s saved coins" % _wallet.text
	_tier.text = "Lv %d" % _selected
	_name.text = "Auto merge" if _kind == "auto_merge" else Preview.NAMES[_selected]
	_description.text = "%d ready Jellies" % Economy.auto_merge_capacity(_selected) if _kind == "auto_merge" \
		else "%d nearby Jellies" % _preview.snapshot().target_count if _selected <= 4 else "Full column" if _selected == 5 \
		else "Row + column" if _selected == 6 else "Extended ring" if _selected == 7 else "Double ring" if _selected == 8 else "Whole board"
	_benefits.text = "Lv %d  →  Lv %d" % [owned, mini(9, owned + 1)] if owned < 9 else "Lv 9"
	_benefits.accessibility_name = _preview.coin_description()
	for kind: String in _category_buttons:
		var category: Button = _category_buttons[kind]
		category.disabled = busy
		category.accessibility_name = "%s upgrades. Current Lv%d" % [category.text, int(_state.get("auto_merge_level" if kind == "auto_merge" else "level", 1))]
	for tab: Dictionary in _tabs:
		tab.button.disabled = busy
		tab.button.accessibility_name = "Preview Lv%d. %s" % [tab.level, "Owned" if int(tab.level) <= owned else "Locked"]
	_progress.text = "%d / %d" % [_funded(), _price()] if owned < 9 else "Lv 9"
	_progress_coin.visible = owned < 9
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
	_layout()

func set_active(value: bool) -> void:
	_active = value
	if not value:
		stop_charging()
	_refresh()

func set_reduced_motion(value: bool) -> void:
	_reduced = value
	_preview.set_reduced_motion(value)
	_hero.set_merged_presentation(0.0, value)
	_offer_jelly.set_merged_presentation(0.0, value)
	if value:
		_coins.clear()
		_visual_progress = _target_progress()

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
	_preview.advance(step)
	if _preview_wait > 0.0:
		_preview_wait -= step
		if _preview_wait <= 0.0 and _charging:
			_selected = mini(9, _owned_level() + 1)
			_present_preview()
			_refresh()
	_visual_progress = _target_progress() if _reduced else move_toward(_visual_progress, _target_progress(), step * 4.0)
	for coin: Dictionary in _coins:
		coin.age = float(coin.age) + step
	_coins = _coins.filter(func(coin: Dictionary) -> bool: return float(coin.age) < 0.46)
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
	_animate_subject()
	_stage.queue_redraw()
	_levels.queue_redraw()
	_effects.queue_redraw()

func _animate_subject() -> void:
	var squash: float = _pulse * 0.055
	var lift: float = 0.0
	if _payoff > 0.0 and not _reduced:
		var t: float = 1.0 - _payoff
		squash += sin(t * TAU * 1.5) * exp(-t * 5.0) * 0.23
		lift = sin(minf(1.0, t * 1.6) * PI) * _hero_edge * 0.13
	if _reduced:
		squash = 0.0
	_hero.scale = Vector2(1.0 + squash, 1.0 - squash)
	_hero.position = _hero_base - Vector2(0, lift)
	_wand.position = _hero_base + Vector2(_hero_edge * 0.48, -_hero_edge * 0.04) - Vector2(0, lift)
	_wand.rotation = 0.0 if _reduced else sin(_elapsed * 2.0) * 0.05 + _pulse * 0.09
	_hero.set_merged_presentation(0.0 if _reduced else _elapsed, _reduced)

func _follow_rail() -> void:
	if _rail_pitch > 0.0:
		_scroll.scroll_horizontal = roundi(maxf(0.0, (_owned_level() - 1.6) * _rail_pitch - _scroll.size.x * 0.23))

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
	var width: float = minf(size.x - 32.0 * u, 940.0 * u)
	var left: float = (size.x - width) * 0.5
	var short: bool = size.y < 620.0 * u
	var landscape: bool = short and size.x > size.y
	_sky.size = size
	_back.position = Vector2(left, 12 * u)
	Style.action_button(_back, Style.GOOD)
	_back.custom_minimum_size = Vector2.ZERO
	_back.size = Vector2(64, 44) * u
	_wallet_icon.position = Vector2(left + width - 100 * u, 22 * u)
	_wallet_icon.size = Vector2.ONE * 25 * u
	_wallet.position = Vector2(left + width - 72 * u, 12 * u)
	_wallet.size = Vector2(72, 44) * u
	_wallet.add_theme_font_size_override("font_size", ceili(20 * u))
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
	_footer.size = Vector2(width * 0.48 if landscape else width, (164 if short else 214) * u + error_height)
	_footer.position = Vector2(left, size.y - _footer.size.y - 12 * u)
	if landscape:
		_footer.position.x = left + width - _footer.size.x
	_stage.position = Vector2(left, (112 if short else 126) * u)
	_stage.size = Vector2(width * 0.48 if landscape else width,
		maxf(90 * u, (size.y - 12 * u if landscape else _footer.position.y - 8 * u) - _stage.position.y))
	var body_width: float = _stage.size.x
	var footer_width: float = _footer.size.x
	var wide: bool = body_width > 620 * u
	var title_height: float = (48 if short else 74) * u
	_tier.position = Vector2.ZERO
	_tier.size = Vector2(body_width * (0.6 if wide else 1.0), (28 if short else 46) * u)
	_tier.add_theme_font_size_override("font_size", ceili((24 if short else 38) * u))
	_name.position = Vector2(0, (26 if short else 44) * u)
	_name.size = Vector2(_tier.size.x, (22 if short else 30) * u)
	_name.add_theme_font_size_override("font_size", ceili((16 if short else 21) * u))
	var art_height: float = maxf(42 * u, _stage.size.y - title_height - (0 if short else 68) * u)
	_hero_edge = minf((216 if wide else 198) * u, art_height * 0.88)
	var hero_x: float = body_width * (0.30 if wide else 0.34)
	_hero_base = Vector2(hero_x - _hero_edge * 0.5, title_height + (art_height - _hero_edge) * 0.44)
	_hero.size = Vector2.ONE * _hero_edge
	_hero.pivot_offset = _hero.size * 0.5
	_wand.size = _hero.size * 0.36
	_wand.pivot_offset = _wand.size * 0.5
	_preview.size = Vector2(minf(body_width * 0.30, 222 * u), minf(art_height, 240 * u))
	_preview.position = Vector2(body_width * (0.69 if wide else 0.82) - _preview.size.x * 0.5, title_height + (art_height - _preview.size.y) * 0.5)
	_preview_label.position = Vector2(_preview.position.x - 12 * u, _preview.position.y - 20 * u)
	_preview_label.size = Vector2(_preview.size.x + 24 * u, 20 * u)
	_preview_label.add_theme_font_size_override("font_size", ceili(10 * u))
	_preview_label.visible = not short and _preview.size.y > 105 * u
	_description.position = Vector2(0, _stage.size.y - 62 * u)
	_description.size = Vector2(body_width, 28 * u)
	_description.add_theme_font_size_override("font_size", ceili(17 * u))
	_benefits.position = Vector2(0, _stage.size.y - 32 * u)
	_benefits.size = Vector2(body_width, 24 * u)
	_benefits.add_theme_font_size_override("font_size", ceili(13 * u))
	_description.visible = not short
	_benefits.visible = not short
	_scroll.position = Vector2.ZERO
	_scroll.size = Vector2(footer_width, (72 if short else 88) * u)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_rail_pitch = maxf(70 * u, (footer_width - 56 * u) / 8.0)
	_levels.custom_minimum_size = Vector2(_rail_pitch * 8 + 56 * u, (64 if short else 76) * u)
	_levels.size = _levels.custom_minimum_size
	_rail_origin = Vector2(28 * u, (53 if short else 61) * u)
	for tab: Dictionary in _tabs:
		var button: Button = tab.button
		Style.quiet_button(button, Style.GOOD, 0)
		button.custom_minimum_size = Vector2.ZERO
		button.position = Vector2((int(tab.level) - 1) * _rail_pitch, 0)
		button.size = Vector2(56, 48) * u
		button.add_theme_font_size_override("font_size", ceili(16 * u))
		button.add_theme_color_override("font_color", Style.INK if int(tab.level) <= _owned_level() else Color("#42657f"))
		if int(tab.level) == _selected:
			button.add_theme_stylebox_override("normal", Style.box(Color("#fff5ce"), Color.TRANSPARENT, ceili(22 * u), 0))
	_progress.position = Vector2((footer_width - 156 * u) * 0.5, (65 if short else 88) * u)
	_progress.size = Vector2(180, 32) * u
	_progress.add_theme_font_size_override("font_size", ceili(19 * u))
	_progress_coin.position = Vector2(_progress.position.x - 4 * u, _progress.position.y + 5 * u)
	_progress_coin.size = Vector2.ONE * 22 * u
	_buy.size = Vector2(minf(308 * u, footer_width), (60 if short else 70) * u)
	_buy.position = Vector2((footer_width - _buy.size.x) * 0.5, (102 if short else 130) * u)
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
	var edge: float = _hero_edge * (1.7 + charge * 0.3 + (0.0 if _reduced else _pulse * 0.15))
	_stage.draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color(1.0, 0.91, 0.57, 0.5 + charge * 0.2))
	if _payoff > 0.0:
		var ray_edge: float = _hero_edge * (2.5 if _reduced else 2.6 + (1.0 - _payoff) * 0.8)
		_stage.draw_set_transform(center, 0.0 if _reduced else (1.0 - _payoff) * 0.4)
		_stage.draw_texture_rect(RAYS, Rect2(-Vector2.ONE * ray_edge * 0.5, Vector2.ONE * ray_edge), false, Color(1.0, 0.94, 0.64, _payoff * 0.86))
		_stage.draw_set_transform(Vector2.ZERO)
	if _kind == "auto_merge":
		var lift := 0.0
		if not _reduced and _payoff > 0.0:
			lift = sin(minf(1.0, (1.0 - _payoff) * 1.6) * PI) * _hero_edge * 0.13
		var squash: float = 0.0 if _reduced else _pulse * 0.07
		_stage.draw_set_transform(center - Vector2(0, lift), 0.0, Vector2(1 + squash, 1 - squash))
		var jelly_edge: float = _hero_edge * 0.60
		for offset: Vector2 in [Vector2(-0.25, -0.15), Vector2(0.25, -0.15), Vector2(0, 0.22)]:
			var at: Vector2 = offset * _hero_edge
			_stage.draw_texture_rect(SKIN, Rect2(at - Vector2.ONE * jelly_edge * 0.5, Vector2.ONE * jelly_edge), false)
			if _picture != null:
				_stage.draw_texture_rect(_picture, Rect2(at - Vector2.ONE * jelly_edge * 0.30, Vector2.ONE * jelly_edge * 0.60), false)
		_stage.draw_set_transform(Vector2.ZERO)

func _draw_rail() -> void:
	var u: float = 1.0 / Style.ui_scale(self)
	var rail := Rect2(_rail_origin - Vector2(0, 7 * u), Vector2(_rail_pitch * 8, 14 * u))
	_levels.draw_style_box(Style.box(Color("#739ab9"), Color("#d6e5f1"), ceili(7 * u), ceili(u)), rail)
	if _visual_progress > 0.0:
		_levels.draw_style_box(Style.box(GOLD, Color("#fff2bb"), ceili(7 * u), ceili(u)), Rect2(rail.position, Vector2(maxf(2 * u, _visual_progress * _rail_pitch), rail.size.y)))
	for level in range(1, 10):
		var at: Vector2 = _rail_origin + Vector2((level - 1) * _rail_pitch, 0)
		var reached: bool = level <= _owned_level()
		_levels.draw_circle(at, 8 * u, GOLD_DARK if reached else Color("#638bb2"))
		_levels.draw_circle(at, 5 * u, Color("#fff4c4") if reached else Color("#c8dcec"))
		if level == _owned_level() + 1:
			_levels.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * 12 * u, Vector2.ONE * 24 * u), false, Color(1, 0.95, 0.64, 0.6 + _pulse * 0.4))
	var tip: Vector2 = _rail_origin + Vector2(_visual_progress * _rail_pitch, 0)
	_levels.draw_texture_rect(GLOW, Rect2(tip - Vector2.ONE * 26 * u, Vector2.ONE * 52 * u), false, Color(1, 0.87, 0.45, 0.55 + _pulse * 0.3))

func _draw_effects() -> void:
	var u: float = 1.0 / Style.ui_scale(self)
	var center: Vector2 = _stage.position + _hero_base + Vector2.ONE * _hero_edge * 0.5
	if not _reduced:
		var start: Vector2 = _footer.position + _buy.position + _buy.size * 0.5
		for coin: Dictionary in _coins:
			var t: float = clampf(float(coin.age) / 0.46, 0.0, 1.0)
			var at: Vector2 = start.lerp(center, t * t * (3.0 - 2.0 * t)) + Vector2(sin(t * PI) * 48 * u * float(coin.side), 0)
			var edge: float = lerpf(25 * u, 17 * u, t)
			_effects.draw_texture_rect(GLOW, Rect2(at - Vector2.ONE * edge, Vector2.ONE * edge * 2), false, Color(1, 0.89, 0.5, 0.5))
			_effects.draw_texture_rect(COIN, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color(1, 1, 1, 1.0 - smoothstep(0.83, 1.0, t)))
	if _payoff > 0.0:
		var t: float = 1.0 - _payoff
		for index in range(4 if _reduced else 10):
			var angle: float = index * TAU / (4 if _reduced else 10) - PI * 0.5
			var radius: float = _hero_edge * (0.67 if _reduced else 0.48 + t * 0.65)
			var at: Vector2 = center + Vector2.from_angle(angle) * radius
			var edge: float = (26 if _reduced else 16 + 17 * _payoff) * u
			_effects.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color(1, 0.97, 0.75, _payoff))

func _rect(control: Control) -> Array:
	var rect: Rect2 = control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "mode": "offer" if _offering else "page", "kind": _kind,
		"owned_level": _owned_level(), "auto_merge_level": int(_state.get("auto_merge_level", 1)),
		"selected_level": _selected, "level": int(_state.get("level", 1)), "funded": _funded(),
		"funding": _state.get("funded", {}).duplicate(true), "price": _price(),
		"remaining": maxi(0, _price() - _funded()), "charging": _charging,
		"progress": _target_progress(), "visual_progress": _visual_progress,
		"level_up_count": _level_up_count, "deposit_count": _deposit_count, "payoff": _payoff,
		"coin_flights": _coins.size(), "balance": int(_state.get("balance", 0)),
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

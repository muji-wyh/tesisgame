extends Control
## An inspectable permanent-upgrade page; the coordinator owns every purchase.

signal back_requested
signal purchase_requested(level: int, kind: String)
signal intro_accepted
signal intro_dismissed
signal retry_requested
signal changed

const Style = preload("res://scripts/ui_style.gd")
const Scroll = preload("res://scripts/result_scroll.gd")
const Preview = preload("res://scripts/word_jelly_ability_preview.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const Tile = preload("res://scripts/word_jelly_tile.gd")
const WordArt = preload("res://scripts/word_art.gd")
const SKY = preload("res://assets/images/jelly-match/sky/day.png")
const COIN = preload("res://assets/coins/gold-coin.png")
const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")
const WAND = preload("res://assets/images/ui/jelly-powerups/auto-merge-wand.svg")

var _state: Dictionary = {}
var _word: Dictionary = {}
var _selected := 2
var _kind := "jelly"
var _offering := false
var _active := true
var _reduced := false
var _sky := TextureRect.new()
var _back := Button.new()
var _heading: Label
var _wallet: Label
var _wallet_icon := TextureRect.new()
var _categories := Control.new()
var _category_buttons: Dictionary = {}
var _scroll := Scroll.new()
var _content := Control.new()
var _levels := Panel.new()
var _tabs: Array[Dictionary] = []
var _detail := Panel.new()
var _name: Label
var _description: Label
var _benefits: Label
var _preview := Preview.new()
var _footer := Panel.new()
var _notice: Label
var _buy := Button.new()
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
	_sky.texture = SKY
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	_back.text = "Back"
	_back.accessibility_name = "Back to the Jelly World map"
	add_child(_back)
	_back.pressed.connect(func() -> void:
		if _active and not _back.disabled:
			back_requested.emit())
	_heading = _label(self, "Jelly Upgrades", 28)
	_heading.clip_text = true
	_wallet = _label(self, "", 18)
	_wallet.clip_text = true
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_icon.texture = COIN
	_wallet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wallet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wallet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wallet_icon)
	add_child(_categories)
	for kind: String in ["jelly", "auto_merge"]:
		var category := Button.new()
		category.text = "Merged Jelly" if kind == "jelly" else "Auto merge"
		category.pressed.connect(select_upgrade.bind(kind))
		_categories.add_child(category)
		_category_buttons[kind] = category
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.interaction_allowed = func() -> bool:
		return _active and is_visible_in_tree() and not _offering and not bool(_state.get("busy", false))
	add_child(_scroll)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_content.add_child(_levels)
	_content.add_child(_detail)
	for level in range(1, 10):
		var button := Button.new()
		button.name = "JellyLv%d" % level
		button.set_meta("jelly_level", level)
		_levels.add_child(button)
		button.pressed.connect(select_level.bind(level))
		var art := TextureRect.new()
		art.texture = SKIN
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(art)
		var title: Label = _label(button, "Lv%d" % level, 16)
		var price: Label = _label(button, "", 12)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tabs.append({"button": button, "art": art, "title": title, "price": price, "level": level})
	_name = _label(_detail, "", 21)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(_preview)
	_description = _label(_detail, "", 15)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_benefits = _label(_detail, "", 13)
	_benefits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_benefits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_benefits.add_theme_color_override("font_color", Style.MUTED)
	add_child(_footer)
	_notice = _label(_footer, "", 14)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_child(_buy)
	_buy.pressed.connect(func() -> void:
		if not _buy.disabled and _active and not _offering:
			if bool(_state.get("retry", false)):
				retry_requested.emit()
			else:
				purchase_requested.emit(_selected, _kind))
	_shade.color = Color(Style.INK, 0.48)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
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
	hide()


func _label(parent: Node, text: String, pixels: int) -> Label:
	var label: Label = Style.label(text, pixels)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func present(state: Dictionary, word: Dictionary, steady: bool, selected: int = 0, offer: bool = false) -> bool:
	_state = state.duplicate(true)
	_word = word.duplicate(true)
	_reduced = steady
	_offering = offer
	_kind = "jelly"
	_selected = clampi(selected if selected > 0 else mini(9, int(state.get("level", 1)) + 1), 1, 9)
	if not _preview.present(_selected, _word, steady):
		return false
	if offer:
		_offer_jelly.configure({"id": 1001, "word": word, "text": word.text,
			"jelly_kind": "merged", "merge_level": 2, "fragments": 0, "merged_level_limit": 9},
			SKIN, WordArt.texture(str(word.get("image", "")), self), null, Style.GOOD, true)
		_offer_jelly.set_merged_presentation(0.0, steady)
	show()
	_refresh()
	default_focus().grab_focus.call_deferred()
	return true


func configure(state: Dictionary) -> void:
	_state = state.duplicate(true)
	_refresh()


func close() -> void:
	_scroll.cancel_drag()
	hide()


func is_offer() -> bool:
	return _offering


func select_level(level: int) -> void:
	if not _active or _offering or not is_visible_in_tree() or bool(_state.get("busy", false)):
		return
	if level < 1 or level > 9:
		push_error("Choose a Jelly preview from level 1 to 9.")
		return
	_selected = level
	if not _present_preview():
		return
	_refresh()
	changed.emit()


func select_upgrade(kind: String) -> void:
	if not _active or _offering or not is_visible_in_tree() or bool(_state.get("busy", false)):
		return
	if not _category_buttons.has(kind):
		push_error("Choose Merged Jelly or Auto merge.")
		return
	if kind == _kind:
		return
	_kind = kind
	_selected = mini(Economy.MAX_UPGRADE_LEVEL, _owned_level() + 1)
	if not _present_preview():
		return
	_refresh()
	_scroll.scroll_vertical = 0
	changed.emit()


func _present_preview() -> bool:
	return _preview.present_auto_merge(_selected, _word, _reduced) if _kind == "auto_merge" \
		else _preview.present(_selected, _word, _reduced)


func _owned_level() -> int:
	return int(_state.get("auto_merge_level" if _kind == "auto_merge" else "level", 1))


func _refresh() -> void:
	var owned: int = _owned_level()
	var busy: bool = bool(_state.get("busy", false)) or not _active
	var pending: Dictionary = _state.get("pending", {})
	var matching: bool = not pending.is_empty() and pending.get("kind", "jelly") == _kind
	var blocked: bool = not pending.is_empty() and not matching
	var price: int = int(pending.price) if matching and int(pending.level) == _selected \
		else Economy.permanent_upgrade_price(_kind, _selected) if _selected > 1 else 0
	var balance: int = int(_state.get("balance", 0))
	var paid: bool = bool(_state.get("paid", false)) and matching and int(pending.level) == _selected
	var error: String = str(_state.get("error", ""))
	var guided: bool = _kind == "jelly" and _state.get("intro") == "guide" and owned == 1
	_wallet.text = str(balance)
	_wallet.accessibility_name = "%d saved coins" % balance
	_wallet.tooltip_text = _wallet.accessibility_name
	var ability_name: String = "Up to %d Jellies" % Economy.auto_merge_capacity(_selected) \
		if _kind == "auto_merge" else Preview.NAMES[_selected]
	_name.text = "Lv%d · %s" % [_selected, ability_name]
	if int(_state.get("just_unlocked", 0)) == _selected and _state.get("just_unlocked_kind", "jelly") == _kind:
		_name.text = "Lv%d unlocked! · %s" % [_selected, ability_name]
	_description.text = _preview.description()
	_benefits.text = _preview.coin_description()
	for kind: String in _category_buttons:
		var category: Button = _category_buttons[kind]
		category.disabled = busy
		category.accessibility_name = "%s upgrades. Current Lv%d" % [
			category.text, int(_state.get("auto_merge_level" if kind == "auto_merge" else "level", 1))]
		Style.action_button(category, Style.GOOD, kind == _kind)
	for tab: Dictionary in _tabs:
		tab.button.disabled = busy
		var quoted: int = int(pending.price) if matching and int(pending.level) == int(tab.level) \
			else Economy.permanent_upgrade_price(_kind, int(tab.level)) if int(tab.level) > 1 else 0
		tab.art.texture = WAND if _kind == "auto_merge" else SKIN
		tab.art.modulate = Color("#d7c5ff") if _kind == "auto_merge" and int(tab.level) == _selected \
			else Color("#8e68b5") if _kind == "auto_merge" else Color.WHITE
		tab.price.text = "Unlocked" if int(tab.level) <= owned else "%d coins" % quoted
		tab.button.accessibility_name = "Preview Lv%d. %s. %s" % [
			tab.level, "Auto merge up to %d Jellies" % Economy.auto_merge_capacity(int(tab.level)) \
				if _kind == "auto_merge" else Preview.NAMES[int(tab.level)], tab.price.text]
		Style.action_button(tab.button, Style.GOOD if int(tab.level) == _selected else Style.MUTED,
			int(tab.level) == _selected)
		tab.title.add_theme_color_override("font_color", Style.PAPER if int(tab.level) == _selected else Style.INK)
		tab.price.add_theme_color_override("font_color", Style.PAPER if int(tab.level) == _selected else Style.INK)
	_buy.disabled = busy or blocked or _selected <= owned or _selected != owned + 1 or (balance < price and not paid)
	if _selected <= owned:
		_buy.text = "Unlocked"
	elif _selected != owned + 1:
		_buy.text = "Unlock Lv%d first" % (_selected - 1)
	elif paid:
		_buy.text = "Finish unlocking Lv%d" % _selected
	else:
		_buy.text = ("%s Lv%d · %d coins" % ["Upgrade to" if _kind == "auto_merge" else "Unlock", _selected, price])
	if blocked:
		_buy.text = "Finish the saved upgrade first"
	if bool(_state.get("retry", false)) and not busy:
		_buy.disabled = false
		_buy.text = "Retry saving"
	_buy.accessibility_name = _buy.text
	_notice.text = error if not error.is_empty() else "Payment saved. Finish the unlock; you will not be charged again." if paid \
		else "Finish the saved %s Lv%d upgrade first." % [
			"Auto merge" if pending.get("kind", "jelly") == "auto_merge" else "Jelly", int(pending.level)] if blocked \
		else "Need %d more coins. Earn them by playing stages." % (price - balance) if _selected == owned + 1 and balance < price \
		else "Your first upgrade: unlock Lv2 with 50 coins." if guided and _selected == 2 \
		else "Bought levels stay unlocked in every Jelly World journey."
	_notice.add_theme_color_override("font_color", Style.WRONG if not error.is_empty() else Style.GOOD if guided else Style.MUTED)
	_offer_caption.text = error if not error.is_empty() else \
		"%d coins saved.\nUnlock Lv2 for 50 coins: mark 4 nearby Jellies and auto-match their partners." % balance
	_offer_accept.disabled = busy
	_offer_later.disabled = busy
	_back.disabled = busy
	for control: Control in [_sky, _back, _heading, _wallet, _wallet_icon, _categories, _scroll, _footer]:
		control.visible = not _offering
	_shade.visible = _offering
	_offer.visible = _offering
	_layout()


func set_active(value: bool) -> void:
	if value == _active:
		return
	_active = value
	if not value:
		_scroll.cancel_drag()
	_refresh()


func set_reduced_motion(value: bool) -> void:
	_reduced = value
	_preview.set_reduced_motion(value)
	_offer_jelly.set_merged_presentation(0.0, value)


func advance(delta: float) -> void:
	if not _active or not is_visible_in_tree() or _offering:
		return
	if _scroll.get_global_rect().intersects(_preview.get_global_rect()):
		_preview.advance(delta)


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
	return _buy if not _buy.disabled else _tabs[_selected - 1].button


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _notice == null:
		return
	var s: float = Style.ui_scale(self)
	var unit := 1.0 / s
	var width: float = minf(size.x - 24.0 * unit, 1000.0 * unit)
	var left: float = (size.x - width) * 0.5
	_sky.size = size
	_back.position = Vector2(left, 12.0 * unit)
	Style.action_button(_back, Style.GOOD)
	_back.custom_minimum_size = Vector2.ZERO
	_back.size = Vector2(68, 44) * unit
	_wallet_icon.position = Vector2(left + width - 104.0 * unit, 22.0 * unit)
	_wallet_icon.size = Vector2.ONE * 24.0 * unit
	_wallet.position = Vector2(left + width - 76.0 * unit, 12.0 * unit)
	_wallet.size = Vector2(76, 44) * unit
	_wallet.add_theme_font_size_override("font_size", ceili(18.0 * unit))
	_heading.position = Vector2(left + 80.0 * unit, 12.0 * unit)
	var heading_width: float = maxf(1.0, width - 192.0 * unit)
	_heading.size = Vector2(heading_width, 44.0 * unit)
	var heading_pixels: int = ceili(26.0 * unit)
	while heading_pixels > ceili(14.0 * unit) and Style.HEADING_FONT.get_string_size(
		_heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_pixels).x > heading_width:
		heading_pixels -= 1
	_heading.add_theme_font_size_override("font_size", heading_pixels)
	var footer_height: float = 102.0 * unit
	_footer.position = Vector2(left, size.y - footer_height - 12.0 * unit)
	_footer.size = Vector2(width, footer_height)
	_footer.add_theme_stylebox_override("panel", Style.box(Style.PAPER, Style.EDGE, ceili(16 * unit), 1))
	_notice.position = Vector2(10, 4) * unit
	_notice.size = Vector2(width - 20.0 * unit, 40.0 * unit)
	_notice.add_theme_font_size_override("font_size", ceili(13.0 * unit))
	_buy.position = Vector2(10, 48) * unit
	_buy.size = Vector2(width - 20.0 * unit, 44.0 * unit)
	Style.action_button(_buy, Style.GOOD, true)
	_buy.add_theme_font_size_override("font_size", ceili(16.0 * unit))
	_categories.position = Vector2(left, 66.0 * unit)
	_categories.size = Vector2(width, 44.0 * unit)
	var category_width: float = (width - 8.0 * unit) * 0.5
	var category_index := 0
	for category: Button in _category_buttons.values():
		category.custom_minimum_size = Vector2.ZERO
		category.position = Vector2(category_index * (category_width + 8.0 * unit), 0)
		category.size = Vector2(category_width, 44.0 * unit)
		category.add_theme_font_size_override("font_size", ceili(15.0 * unit))
		category_index += 1
	_scroll.position = Vector2(left, 122.0 * unit)
	_scroll.size = Vector2(width, maxf(1.0, _footer.position.y - _scroll.position.y - 10.0 * unit))
	var wide: bool = size.x * s >= 720.0 and size.x > size.y
	var level_width: float = 276.0 * unit if wide else width
	var tab_height: float = 64.0 * unit if wide else 52.0 * unit
	var gap: float = 8.0 * unit
	var level_height: float = tab_height * 3.0 + gap * 2.0
	var detail_top: float = 0.0 if wide else level_height + 12.0 * unit
	var detail_height: float = maxf(360.0 * unit, _scroll.size.y - detail_top)
	var body_height: float = maxf(level_height, detail_height) if wide else detail_top + detail_height
	_content.custom_minimum_size = Vector2(0, body_height)
	_content.size = Vector2(width, body_height)
	_levels.position = Vector2.ZERO
	_levels.size = Vector2(level_width, level_height)
	_levels.add_theme_stylebox_override("panel", Style.box(Color(Style.PAPER, 0.88), Style.EDGE, ceili(16 * unit), 1))
	var tab_width: float = (level_width - gap * 2.0) / 3.0
	for index in range(_tabs.size()):
		var tab: Dictionary = _tabs[index]
		tab.button.position = Vector2((index % 3) * (tab_width + gap), (index / 3) * (tab_height + gap))
		tab.button.size = Vector2(tab_width, tab_height)
		tab.button.custom_minimum_size = Vector2.ZERO
		tab.art.position = Vector2(8, 6) * unit
		tab.art.size = Vector2.ONE * 24.0 * unit
		tab.title.position = Vector2(36, 2) * unit
		tab.title.size = Vector2(maxf(1.0, tab_width - 40 * unit), 30 * unit)
		tab.title.add_theme_font_size_override("font_size", ceili(16 * unit))
		tab.price.position = Vector2(4, 30) * unit
		tab.price.size = Vector2(tab_width - 8 * unit, maxf(18 * unit, tab_height - 32 * unit))
		tab.price.add_theme_font_size_override("font_size", ceili(12 * unit))
	_detail.position = Vector2(level_width + 16 * unit, 0) if wide else Vector2(0, detail_top)
	_detail.size = Vector2(width - _detail.position.x, detail_height)
	_detail.add_theme_stylebox_override("panel", Style.box(Style.PAPER, Style.EDGE, ceili(18 * unit), 1))
	_name.position = Vector2(8, 6) * unit
	_name.size = Vector2(_detail.size.x - 16 * unit, 32 * unit)
	_name.add_theme_font_size_override("font_size", ceili(19 * unit))
	_preview.position = Vector2(12, 42) * unit
	_preview.size = Vector2(_detail.size.x - 24 * unit, detail_height - 146 * unit)
	_description.position = Vector2(12 * unit, detail_height - 98 * unit)
	_description.size = Vector2(_detail.size.x - 24 * unit, 54 * unit)
	_description.add_theme_font_size_override("font_size", ceili(14 * unit))
	_benefits.position = Vector2(12 * unit, detail_height - 42 * unit)
	_benefits.size = Vector2(_detail.size.x - 24 * unit, 36 * unit)
	_benefits.add_theme_font_size_override("font_size", ceili(12 * unit))
	_shade.size = size
	_offer.size = Vector2(minf(440 * unit, size.x - 28 * unit), minf(398 * unit, size.y - 24 * unit))
	_offer.position = (size - _offer.size) * 0.5
	_offer.add_theme_stylebox_override("panel", Style.box(Style.PAPER, Style.GOOD.lightened(0.65), ceili(22 * unit), 1))
	var inner_width: float = _offer.size.x - 32 * unit
	_offer_title.position = Vector2(16, 14) * unit
	_offer_title.size = Vector2(inner_width, 36 * unit)
	_offer_title.add_theme_font_size_override("font_size", ceili(24 * unit))
	var hero_edge: float = minf(104 * unit, maxf(44 * unit, _offer.size.y - 252 * unit))
	_offer_jelly.position = Vector2((_offer.size.x - hero_edge) * 0.5, 58 * unit)
	_offer_jelly.size = Vector2.ONE * hero_edge
	_offer_caption.position = Vector2(16 * unit, 64 * unit + hero_edge)
	_offer_caption.size = Vector2(inner_width, maxf(44 * unit, _offer.size.y - hero_edge - 190 * unit))
	_offer_caption.add_theme_font_size_override("font_size", ceili(15 * unit))
	_offer_accept.position = Vector2(16 * unit, _offer.size.y - 112 * unit)
	_offer_accept.size = Vector2(inner_width, 44 * unit)
	_offer_later.position = Vector2(16 * unit, _offer.size.y - 58 * unit)
	_offer_later.size = Vector2(inner_width, 44 * unit)
	Style.action_button(_offer_accept, Style.GOOD, true)
	Style.action_button(_offer_later, Style.GOOD)


func _rect(control: Control) -> Array:
	var rect: Rect2 = control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "mode": "offer" if _offering else "page",
		"kind": _kind, "owned_level": _owned_level(), "auto_merge_level": int(_state.get("auto_merge_level", 1)),
		"selected_level": _selected, "level": int(_state.get("level", 1)),
		"balance": int(_state.get("balance", 0)), "intro": str(_state.get("intro", "unseen")),
		"error": str(_state.get("error", "")), "notice": _notice.text,
		"preview": _preview.snapshot(), "pending": _state.get("pending", {}).duplicate(true),
		"buy": {"rect": _rect(_buy), "enabled": not _buy.disabled, "text": _buy.text,
			"guided": _kind == "jelly" and _selected == 2 and _state.get("intro") == "guide" and int(_state.get("level", 1)) == 1},
		"categories": _category_buttons.keys().map(func(kind: String) -> Dictionary:
			return {"kind": kind, "rect": _rect(_category_buttons[kind]),
				"selected": kind == _kind, "enabled": not _category_buttons[kind].disabled}),
		"back": {"rect": _rect(_back), "enabled": not _back.disabled},
		"offer": {"primary": _rect(_offer_accept), "later": _rect(_offer_later), "caption": _offer_caption.text},
		"levels": _tabs.map(func(tab: Dictionary) -> Dictionary:
			return {"level": tab.level, "rect": _rect(tab.button), "price": tab.price.text,
				"selected": int(tab.level) == _selected, "enabled": not tab.button.disabled})}

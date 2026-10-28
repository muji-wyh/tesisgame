extends Button
## A stable purchase target. The owner advances and pauses its feedback clock.

const Style = preload("res://scripts/ui_style.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const WAND = preload("res://assets/images/ui/jelly-powerups/auto-merge-wand.svg")
const MAGNET = preload("res://assets/images/ui/jelly-powerups/family-magnet.webp")
const CHEST = preload("res://assets/chests/royal/closed.png")
const COIN = preload("res://assets/coins/gold-coin.png")
const CLOCK = preload("res://assets/images/ui/jelly-goals/clock.webp")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const SUCCESS_SECONDS: float = 0.62
const FAILURE_SECONDS: float = 0.42
const REDUCED_SECONDS: float = 0.32
const FUNDS_SECONDS: float = 1.15

var _kind: String = "auto_merge"
var _price: int = Model.POWERUP_PRICES.auto_merge
var _available: bool = true
var _affordable: bool = false
var _balance_known: bool = true
var _busy: bool = false
var _reduced_motion: bool = false
var _paused: bool = false
var _ui_scale: float = 1.0
var _compact: bool = false
var _targeting: bool = false
var _feedback_active: bool = false
var _feedback_success: bool = true
var _feedback_elapsed: float = 0.0
var _feedback_serial: int = 0
var _missing_coins: int = 0
var _price_position := Vector2.ZERO
var _chest: Texture2D = CHEST
var _chest_region := Rect2(39, 309, 798, 595)
var _icon_rect := Rect2()
var _coin_rect := Rect2()
var _price_pill := Rect2()
var _title := Label.new()
var _price_label := Label.new()
var _panel := StyleBoxFlat.new()


func _init() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for label: Label in [_title, _price_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", Style.HEADING_FONT)
		label.add_theme_constant_override("line_spacing", 0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		add_child(label)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resized.connect(_layout)
	for event: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)
	set_ui_scale(1.0)
	configure("auto_merge", Model.POWERUP_PRICES.auto_merge, false)


func configure(kind: String, price: int, reduced_motion: bool) -> void:
	_kind = kind if kind in ["extra_time", "family_merge"] else "fragments" if kind in ["fragments", "treasure"] else "auto_merge"
	_price = maxi(0, price)
	_reduced_motion = reduced_motion
	name = "PowerupExtraTime" if _kind == "extra_time" else "PowerupMagnet" if _kind == "family_merge" \
		else "PowerupTreasure" if _kind == "fragments" else "PowerupAutoMerge"
	tooltip_text = ""
	reset()
	_layout()
	_update_accessibility()


func set_ui_scale(value: float, compact: bool = false) -> void:
	_ui_scale = maxf(0.1, value)
	_compact = compact
	custom_minimum_size = Vector2(88.0, 44.0 if compact else 56.0) / _ui_scale
	_layout()


func set_price(value: int) -> void:
	var next_price: int = maxi(0, value)
	if next_price == _price:
		return
	_price = next_price
	# Updating the next purchase must not cancel the current success animation.
	_layout()
	_update_accessibility()


func set_targeting(value: bool) -> void:
	if value == _targeting:
		return
	_targeting = value
	_layout()
	_update_accessibility()


func set_chest_texture(texture: Texture2D) -> void:
	if texture == null or texture == _chest:
		return
	_chest = texture
	# The owner supplies its cropped chest renderer. Reading a ViewportTexture
	# back here fails before its first frame and stalls ordinary GPU rendering.
	_chest_region = Rect2(39, 309, 798, 595) if texture == CHEST else Rect2(Vector2.ZERO, texture.get_size())
	queue_redraw()


func set_availability(available: bool, affordable: bool, busy: bool = false, balance_known: bool = true) -> void:
	_available = available
	_affordable = affordable
	_balance_known = balance_known
	_busy = busy
	# A low balance is a feedback opportunity, never a disabled purchase target.
	disabled = not available or busy
	_update_accessibility()
	queue_redraw()


func feedback(success: bool) -> void:
	if _paused:
		return
	_feedback_success = success
	_missing_coins = 0
	_feedback_elapsed = 0.0
	_feedback_active = true
	_feedback_serial += 1
	_layout()
	_update_accessibility()


func insufficient_coins(missing: int) -> void:
	if _paused or not _feedback_active or _feedback_success:
		return
	_missing_coins = maxi(0, missing)
	_layout()
	_update_accessibility()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	_layout()
	_update_accessibility()


func pause_feedback(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	_layout()
	_update_accessibility()


func advance(delta: float) -> void:
	if _paused or not is_visible_in_tree() or not _feedback_active or not is_finite(delta) or delta <= 0.0:
		return
	_feedback_elapsed = minf(_duration(), _feedback_elapsed + delta)
	if _feedback_elapsed >= _duration():
		_feedback_active = false
		_missing_coins = 0
		_layout()
		_update_accessibility()
	queue_redraw()


func reset() -> void:
	_targeting = false
	_feedback_active = false
	_feedback_elapsed = 0.0
	_missing_coins = 0
	_paused = false
	_layout()
	_update_accessibility()


func _duration() -> float:
	if _missing_coins > 0:
		return FUNDS_SECONDS
	return REDUCED_SECONDS if _reduced_motion else SUCCESS_SECONDS if _feedback_success else FAILURE_SECONDS


func _title_text() -> String:
	return "Need coins" if _funds_warning() else _action_title()


func _action_title() -> String:
	return "+30 sec" if _kind == "extra_time" else "Treasure" if _kind == "fragments" \
		else "Pick Jelly" if _targeting else "Magnet" if _kind == "family_merge" else "Auto merge"


func _funds_warning() -> bool:
	return _feedback_active and not _feedback_success and _missing_coins > 0 and not _paused


func _update_accessibility() -> void:
	var title: String = _action_title()
	var status: String = "Working" if _busy else "Unavailable right now" if not _available \
		else "Coin balance unavailable" if not _balance_known else "Not enough coins" if not _affordable else "Ready"
	if _funds_warning():
		status = "Not enough coins. Need %d more coins" % _missing_coins
	set("accessibility_name", "%s. %d coins. %s.%s" % [title, _price, status,
		" Choose a Jelly to merge its word, picture and upgraded family. Press again or Back to cancel." if _kind == "family_merge" else ""])


func _layout() -> void:
	var unit: float = 1.0 / _ui_scale
	var edge: float = minf((18.0 if _compact else 26.0) * unit, minf(size.y * 0.50, size.x * 0.27))
	var lower_center: float = size.y - (12.0 if _compact else 17.0) * unit
	_icon_rect = Rect2(Vector2(7.0 * unit, lower_center - edge * 0.5), Vector2.ONE * edge)
	_title.position = Vector2(6.0 * unit, (1.0 if _compact else 3.0) * unit)
	var title_size := Vector2(maxf(1.0, size.x - 12.0 * unit), maxf(1.0, (18.0 if _compact else 22.0) * unit))
	var title: String = _title_text()
	var font_size: int = maxi(1, roundi((12.0 if _compact else 13.0) * unit))
	while font_size > 1 and (Style.HEADING_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > title_size.x \
		or Style.HEADING_FONT.get_height(font_size) > title_size.y):
		font_size -= 1
	_title.text = title
	_title.add_theme_font_size_override("font_size", font_size)
	_title.size = title_size
	_price_label.text = str(_price)
	var price_font: int = maxi(1, roundi(12.0 * unit))
	var price_width: float = Style.HEADING_FONT.get_string_size(_price_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, price_font).x
	var coin_edge: float = 12.0 * unit
	var available_price: float = maxf(1.0, size.x - _icon_rect.end.x - 10.0 * unit)
	while price_font > 1 and price_width + coin_edge + 12.0 * unit > available_price:
		price_font -= 1
		price_width = Style.HEADING_FONT.get_string_size(_price_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, price_font).x
	_price_label.add_theme_font_size_override("font_size", price_font)
	var group_width: float = coin_edge + 4.0 * unit + price_width
	var pill_width: float = group_width + 8.0 * unit
	_price_pill = Rect2(Vector2(size.x - 6.0 * unit - pill_width, lower_center - 11.0 * unit), Vector2(pill_width, 22.0 * unit))
	_coin_rect = Rect2(Vector2(_price_pill.position.x + 4.0 * unit, lower_center - coin_edge * 0.5), Vector2.ONE * coin_edge)
	_price_label.position = Vector2(_coin_rect.end.x + 4.0 * unit, lower_center - 9.5 * unit)
	_price_position = _price_label.position
	_price_label.size = Vector2(price_width + 1.0, 19.0 * unit)
	queue_redraw()


func _pose() -> Dictionary:
	var pose := {"scale": 1.0, "rotation": 0.0, "offset": Vector2.ZERO, "light": 0.0,
		"price_offset": Vector2.ZERO, "coin_scale": 1.0}
	if not _feedback_active or _paused:
		return pose
	if _funds_warning():
		pose.light = 1.0 - smoothstep(0.78, FUNDS_SECONDS, _feedback_elapsed)
		if not _reduced_motion:
			var recoil: float = clampf(_feedback_elapsed / FAILURE_SECONDS, 0.0, 1.0)
			pose.price_offset = Vector2(sin(recoil * TAU * 3.0) * pow(1.0 - recoil, 2.0) * 4.0 / _ui_scale, 0.0)
			pose.coin_scale = 1.0 + sin(clampf(_feedback_elapsed / 0.28, 0.0, 1.0) * PI) * 0.18
		return pose
	if _reduced_motion:
		pose.light = 0.65
		return pose
	var t: float = clampf(_feedback_elapsed / _duration(), 0.0, 1.0)
	if _feedback_success:
		var rise: float = sin(t * PI) * pow(1.0 - t, 0.42)
		pose.scale = 1.0 + rise * 0.22
		pose.rotation = sin(t * TAU) * (0.20 if _kind == "auto_merge" else 0.10) * (1.0 - t)
		pose.offset = Vector2(0.0, -rise * 3.5 / _ui_scale)
		pose.light = sin(minf(1.0, t * 1.6) * PI) * 0.85
	else:
		pose.rotation = sin(t * TAU * 2.0) * 0.11 * (1.0 - t)
		pose.offset = Vector2(sin(t * TAU * 3.0) * 3.2 * (1.0 - t) / _ui_scale, 0.0)
		pose.scale = 1.0 - sin(t * PI) * 0.08
		pose.light = sin(t * PI) * 0.75
	return pose


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var unit: float = 1.0 / _ui_scale
	var accent: Color = Style.GOOD if _targeting else Style.EDGE
	var fill: Color = Style.SOFT if _targeting else Style.SURFACE
	var pose: Dictionary = _pose()
	var ink: Color = Style.INK
	var celebrating: bool = _feedback_active and _feedback_success and not _paused
	var funds: bool = _funds_warning()
	if funds:
		fill = Style.SURFACE.lerp(Color("#ffedcf"), 0.65 + float(pose.light) * 0.35)
		accent = Color("#d28a43")
		ink = Color("#925026")
	elif disabled and not celebrating:
		fill = Color("#f0f1eb")
		accent = Color("#b5bbb0")
		ink = Color("#64736b")
	elif not _affordable and not celebrating:
		accent = accent.lerp(Color("#b9b7af"), 0.28)
	elif is_hovered():
		fill = fill.lightened(0.28)
	_panel.bg_color = fill
	_panel.border_color = accent
	_panel.set_border_width_all(maxi(1, roundi((2.0 if funds else 1.0) * unit)))
	_panel.set_corner_radius_all(maxi(1, roundi(13.0 * unit)))
	_panel.shadow_color = Color("#577777", 0.14)
	_panel.shadow_size = roundi(3.0 * unit)
	_panel.shadow_offset = Vector2(0.0, (1.0 if is_pressed() else 2.0) * unit)
	if has_focus() and not disabled and not funds:
		_panel.border_color = Style.GOOD
		_panel.set_border_width_all(maxi(1, roundi(2.0 * unit)))
	draw_style_box(_panel, Rect2(Vector2.ONE * unit, size - Vector2.ONE * 2.0 * unit))
	_title.add_theme_color_override("font_color", ink)
	var price_color := Color("#675335") if _affordable else Color("#80644d")
	if _feedback_active and not _feedback_success and not _paused:
		price_color = Color("#a34c24") if funds else Color("#b46640")
	_price_label.add_theme_color_override("font_color", ink if disabled and not celebrating else price_color)
	_price_label.position = _price_position + Vector2(pose.price_offset)
	var center: Vector2 = _icon_rect.get_center() + Vector2(pose.offset)
	var tint := Color("#8e68b5") if _kind == "auto_merge" else Color.WHITE
	if disabled and not celebrating:
		tint.a = 0.70
	elif not _affordable and not celebrating:
		tint.a = 0.90
	var light: float = float(pose.light)
	var light_color := Color("#d7c5ff") if _feedback_success and _kind == "auto_merge" else Color("#ffe49d") if _feedback_success else Color("#ffc49d")
	if light > 0.0:
		var glow_rect: Rect2 = _price_pill.grow(4.0 * unit) if funds else Rect2(center - _icon_rect.size * 0.8, _icon_rect.size * 1.6)
		draw_texture_rect(GLOW, glow_rect, false, Color(light_color, light * (0.65 if funds else 1.0)))
	var press: float = 0.94 if is_pressed() and not disabled else 1.0
	draw_set_transform(center, float(pose.rotation), Vector2.ONE * float(pose.scale) * press)
	if _kind == "auto_merge":
		draw_texture_rect(WAND, Rect2(-_icon_rect.size * 0.5, _icon_rect.size), false, tint)
	elif _kind == "family_merge":
		draw_texture_rect(MAGNET, Rect2(-_icon_rect.size * 0.5, _icon_rect.size), false, tint)
	elif _kind == "extra_time":
		draw_texture_rect(CLOCK, Rect2(-_icon_rect.size * 0.5, _icon_rect.size), false, tint)
	else:
		# A newly allocated viewport can be blank until the owner caches its
		# cropped render. Keep the acquired fallback visible during that warmup.
		var warming: bool = _chest is ViewportTexture or not _chest_region.has_area()
		var texture: Texture2D = CHEST if warming else _chest
		var region := Rect2(39, 309, 798, 595) if warming else _chest_region
		var extent: Vector2 = region.size * (_icon_rect.size.x / maxf(1.0, region.size.x))
		draw_texture_rect_region(texture, Rect2(-extent * 0.5, extent), region, tint)
	draw_set_transform(Vector2.ZERO)
	var coin_size: Vector2 = _coin_rect.size * float(pose.coin_scale)
	var coin_center: Vector2 = _coin_rect.get_center() + Vector2(pose.price_offset)
	draw_texture_rect(COIN, Rect2(coin_center - coin_size * 0.5, coin_size), false,
		Color(1.0, 1.0, 1.0, 0.75 if disabled and not celebrating and not funds else 1.0))
	if light > 0.0 and not funds:
		var offsets: Array[Vector2] = [Vector2(-0.42, -0.42), Vector2(0.48, -0.24), Vector2(0.38, 0.38)]
		for index in range(offsets.size()):
			var edge: float = (8.0 if index == 0 else 6.0) * unit
			var point: Vector2 = center + offsets[index] * _icon_rect.size
			draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color(light_color, light))


func snapshot() -> Dictionary:
	var pose: Dictionary = _pose()
	return {"kind": _kind, "price": _price, "available": _available, "affordable": _affordable, "targeting": _targeting,
		"busy": _busy, "enabled": not disabled, "paused": _paused, "reduced_motion": _reduced_motion,
		"feedback_active": _feedback_active, "feedback_success": _feedback_success,
		"feedback_serial": _feedback_serial, "feedback_elapsed": _feedback_elapsed,
		"funds_warning": _funds_warning(), "missing_coins": _missing_coins, "balance_known": _balance_known,
		"price_offset": [pose.price_offset.x, pose.price_offset.y], "coin_scale": pose.coin_scale,
		"icon_scale": pose.scale, "icon_rotation": pose.rotation, "icon_offset": [pose.offset.x, pose.offset.y],
		"light": pose.light, "title": _title.text, "price_text": _price_label.text,
		"icon_rect": [_icon_rect.position.x, _icon_rect.position.y, _icon_rect.size.x, _icon_rect.size.y],
		"coin_rect": [_coin_rect.position.x, _coin_rect.position.y, _coin_rect.size.x, _coin_rect.size.y],
		"title_rect": [_title.position.x, _title.position.y, _title.size.x, _title.size.y],
		"price_rect": [_price_label.position.x, _price_label.position.y, _price_label.size.x, _price_label.size.y]}

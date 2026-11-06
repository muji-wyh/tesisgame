extends Button
## A stable purchase target. The owner advances and pauses its feedback clock.

signal preview_changed(active: bool)

const Style = preload("res://scripts/ui_style.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const WAND = preload("res://assets/images/ui/jelly-powerups/auto-merge-wand.svg")
const MAGNET = preload("res://assets/images/ui/jelly-powerups/family-magnet.webp")
const CHEST = preload("res://assets/chests/shared/ui/chest.png")
const COIN = preload("res://assets/coins/gold-coin.png")
const CLOCK = preload("res://assets/images/ui/jelly-goals/clock.webp")
const GEL = preload("res://assets/images/jelly-match/gel-mint.png")
const GLOW = preload("res://assets/chests/shared/effects/portal_glow.png")
const SPARKLE = preload("res://assets/chests/shared/effects/sparkle.png")
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
var _preview_active: bool = false
var _preview_consumed: bool = false
var _pointer_input: bool = false
var _feedback_active: bool = false
var _feedback_success: bool = true
var _feedback_elapsed: float = 0.0
var _feedback_serial: int = 0
var _missing_coins: int = 0
var _price_position := Vector2.ZERO
var _chest: Texture2D = CHEST
var _chest_region := Rect2(Vector2.ZERO, CHEST.get_size())
var _icon_rect := Rect2()
var _coin_rect := Rect2()
var _price_pill := Rect2()
var _title := Label.new()
var _price_label := Label.new()
var _capacity_label := Label.new()
var _capacity_badge := StyleBoxFlat.new()
var _capacity_rect := Rect2()
var _auto_merge_capacity: int = Economy.AUTO_MERGE_BASE_CAPACITY
var _auto_merge_level: int = 1
var _panel := StyleBoxFlat.new()
var _goal: Dictionary = {}
var _goal_geometry: Dictionary = {}
var _spent_coins: int = 0
var _goal_complete_progress: float = 1.0
var _progress_surface := StyleBoxFlat.new()


func _init() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for label: Label in [_title, _price_label, _capacity_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", Style.HEADING_FONT)
		label.add_theme_constant_override("line_spacing", 0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		add_child(label)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capacity_label.add_theme_color_override("font_color", Style.PAPER)
	resized.connect(_layout)
	for event: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited, button_down, button_up]:
		event.connect(queue_redraw)
	for event: Signal in [focus_exited, visibility_changed]:
		event.connect(_refresh_preview)
	for event: Signal in [mouse_entered, mouse_exited, focus_entered]:
		event.connect(_restart_preview)
	pressed.connect(_consume_preview)
	set_ui_scale(1.0)
	configure("auto_merge", Model.POWERUP_PRICES.auto_merge, false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _kind != "auto_merge" or not _goal.is_empty():
		return
	var was_pointer: bool = _pointer_input
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenTouch:
		_pointer_input = true
	elif event is InputEventKey or event is InputEventJoypadButton \
		or event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		_pointer_input = false
	if was_pointer != _pointer_input:
		_refresh_preview()


func _refresh_preview() -> void:
	var active: bool = _kind == "auto_merge" and _goal.is_empty() and not _preview_consumed \
		and not disabled and not _paused and is_visible_in_tree() and (is_hovered() or has_focus() and not _pointer_input)
	if active == _preview_active:
		return
	_preview_active = active
	preview_changed.emit(active)


func _restart_preview() -> void:
	_preview_consumed = false
	_refresh_preview()


func clear_preview() -> void:
	if not _preview_active:
		return
	_preview_active = false
	preview_changed.emit(false)


func _consume_preview() -> void:
	if _kind != "auto_merge" or not _goal.is_empty():
		return
	_preview_consumed = true
	_refresh_preview()
	if _pointer_input:
		release_focus()


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

func configure_goal(item: Dictionary, price: int, reduced: bool) -> void:
	_goal = item.duplicate(true)
	configure("family_merge", price, reduced)
	name = "WordGoal_" + str(item.id).replace(":", "_")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_stylebox_override("panel", _panel)
	custom_minimum_size = Vector2.ZERO
	_layout()


func set_goal(item: Dictionary) -> void:
	if _goal == item:
		return
	_goal = item.duplicate(true)
	_layout()
	_update_accessibility()


func layout_goal(icon: Rect2, title: Rect2, price: Rect2, detail: Rect2, scale_value: float, compact: bool) -> void:
	_ui_scale = maxf(0.1, scale_value)
	_compact = compact
	_goal_geometry = {"icon": icon, "title": title, "price": price, "detail": detail}
	_layout()


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


func set_auto_merge_level(level: int) -> void:
	if level < 1 or level > Economy.MAX_UPGRADE_LEVEL:
		push_error("Auto merge needs its real saved level.")
		return
	if level == _auto_merge_level:
		return
	_auto_merge_capacity = Economy.auto_merge_capacity(level)
	_auto_merge_level = level
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
	_chest_region = Rect2(Vector2.ZERO, texture.get_size())
	queue_redraw()


func set_availability(available: bool, affordable: bool, busy: bool = false, balance_known: bool = true) -> void:
	if _available == available and _affordable == affordable and _busy == busy \
		and _balance_known == balance_known and disabled == (not available or busy):
		_refresh_preview()
		return
	_available = available
	_affordable = affordable
	_balance_known = balance_known
	_busy = busy
	# A low balance is a feedback opportunity, never a disabled purchase target.
	disabled = not available or busy
	_update_accessibility()
	_refresh_preview()
	queue_redraw()


func feedback(success: bool, spent_coins: int = 0) -> void:
	if _paused:
		return
	_feedback_success = success
	_missing_coins = 0
	_feedback_elapsed = 0.0
	_feedback_active = true
	_feedback_serial += 1
	_spent_coins = maxi(0, spent_coins) if success else 0
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
	_refresh_preview()


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
	_spent_coins = 0
	_paused = false
	_preview_consumed = false
	_layout()
	_update_accessibility()
	_refresh_preview()


func _duration() -> float:
	if _missing_coins > 0:
		return FUNDS_SECONDS
	return REDUCED_SECONDS if _reduced_motion else SUCCESS_SECONDS if _feedback_success else FAILURE_SECONDS


func _title_text() -> String:
	return "Need coins" if _funds_warning() else str(_goal.text) if not _goal.is_empty() else _action_title()


func _action_title() -> String:
	if not _goal.is_empty():
		return "Auto merge " + str(_goal.text)
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
	if not _goal.is_empty():
		var progress: String = "%d of %d complete" % [int(_goal.current), int(_goal.required)]
		set("accessibility_name", "%s. %s. %d coins. %s. Only this word family is merged; collect it yourself." % [
			title, progress, _price, "Goal complete" if _goal.mastered else status])
		return
	set("accessibility_name", "%s. %d coins. %s.%s" % [title, _price, status,
		" Choose a Jelly to merge its word, picture and upgraded family. Press again or Back to cancel." if _kind == "family_merge" \
			else " Lv%d. Up to %d completed Jellies per use. Hover or focus to preview the exact board inputs." \
				% [_auto_merge_level, _auto_merge_capacity] if _kind == "auto_merge" else ""])


func _layout() -> void:
	var unit: float = 1.0 / _ui_scale
	_capacity_label.visible = _kind == "auto_merge" and _goal.is_empty()
	_capacity_rect = Rect2()
	if not _goal.is_empty():
		_title.scale = Vector2.ONE
		_price_label.scale = Vector2.ONE
		if _goal_geometry.is_empty():
			return
		_icon_rect = _goal_geometry.icon
		var title_area: Rect2 = _goal_geometry.title
		_title.position = title_area.position
		_title.size = title_area.size
		_title.text = _title_text()
		var font_size: int = maxi(1, roundi((13.0 if _compact else 18.0) * unit))
		while font_size > 1 and (Style.HEADING_FONT.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > title_area.size.x \
			or Style.HEADING_FONT.get_height(font_size) > title_area.size.y):
			font_size -= 1
		_title.add_theme_font_size_override("font_size", font_size)
		_price_pill = _goal_geometry.price
		var coin_edge: float = minf(12.0 * unit, _price_pill.size.y)
		_coin_rect = Rect2(Vector2(_price_pill.position.x, _price_pill.get_center().y - coin_edge * 0.5), Vector2.ONE * coin_edge)
		_price_label.text = str(_price)
		_price_label.add_theme_font_size_override("font_size", maxi(1, roundi(12.0 * unit)))
		_price_position = Vector2(_coin_rect.end.x + 3.0 * unit, _price_pill.position.y)
		_price_label.position = _price_position
		_price_label.size = Vector2(maxf(1.0, _price_pill.end.x - _price_position.x), _price_pill.size.y)
		_price_label.visible = not bool(_goal.mastered)
		queue_redraw()
		return
	# Keep tool lettering in display pixels instead of rounding it to tiny
	# local font sizes when the application canvas is highly scaled.
	_title.scale = Vector2.ONE * unit
	_price_label.scale = Vector2.ONE * unit
	var wide_edge: float = 180.0 if _kind == "auto_merge" else 144.0
	var wide: bool = size.x >= wide_edge * unit or is_equal_approx(size.x, wide_edge * unit)
	var edge: float = (24.0 if _compact else 32.0) * unit if wide else \
		minf((18.0 if _compact else 26.0) * unit, minf(size.y * 0.50, size.x * 0.25))
	var lower_center: float = size.y - (12.0 if _compact else 17.0) * unit
	var title_height: float = (18.0 if _compact else 20.0 if wide else 22.0) * unit
	if wide:
		_icon_rect = Rect2(Vector2(10.0 * unit, (size.y - edge) * 0.5), Vector2.ONE * edge)
		_title.position = Vector2(_icon_rect.end.x + 8.0 * unit, (size.y - title_height - 20.0 * unit) * 0.5)
		lower_center = _title.position.y + title_height + 10.5 * unit
	else:
		_icon_rect = Rect2(Vector2(7.0 * unit, lower_center - edge * 0.5), Vector2.ONE * edge)
		_title.position = Vector2(6.0 * unit, (1.0 if _compact else 3.0) * unit)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
	var capacity_space: float = 0.0
	if _capacity_label.visible:
		if wide:
			_capacity_rect = Rect2(Vector2(size.x - 54.0 * unit, (size.y - 26.0 * unit) * 0.5),
				Vector2(46, 26) * unit)
			capacity_space = 52.0 * unit
		else:
			_capacity_rect = Rect2(Vector2(_icon_rect.end.x - 14.0 * unit, _icon_rect.position.y + 3.0 * unit),
				Vector2(20, 18) * unit)
		_capacity_label.scale = Vector2.ONE * unit
		_capacity_label.position = _capacity_rect.position + Vector2(22.0 * unit if wide else 0.0, 0)
		_capacity_label.size = Vector2((_capacity_rect.size.x - (23.0 * unit if wide else 0.0)) / unit,
			_capacity_rect.size.y / unit)
		_capacity_label.text = str(_auto_merge_capacity)
		_capacity_label.add_theme_font_size_override("font_size", 13 if wide else 11)
	var title_size := Vector2(maxf(1.0, size.x - _title.position.x - (8.0 if wide else 6.0) * unit \
		- capacity_space), maxf(1.0, title_height))
	var title: String = _title_text()
	var font_size: int = 12 if _compact else 13
	while font_size > 1 and (Style.HEADING_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * unit > title_size.x \
		or Style.HEADING_FONT.get_height(font_size) * unit > title_size.y):
		font_size -= 1
	_title.text = title
	_title.add_theme_font_size_override("font_size", font_size)
	_title.size = title_size / unit
	_price_label.text = str(_price)
	var price_font: int = 12
	var price_width: float = Style.HEADING_FONT.get_string_size(_price_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, price_font).x * unit
	var coin_edge: float = 12.0 * unit
	var available_price: float = maxf(1.0, size.x - _title.position.x - 8.0 * unit) if wide else \
		maxf(1.0, size.x - _icon_rect.end.x - 12.0 * unit)
	while price_font > 1 and (price_width + coin_edge + 5.0 * unit > available_price \
		or Style.HEADING_FONT.get_height(price_font) * unit > 19.0 * unit):
		price_font -= 1
		price_width = Style.HEADING_FONT.get_string_size(_price_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, price_font).x * unit
	_price_label.add_theme_font_size_override("font_size", price_font)
	var group_width: float = coin_edge + 5.0 * unit + price_width
	var price_x: float = _title.position.x if wide else size.x - 8.0 * unit - group_width
	_price_pill = Rect2(Vector2(price_x, lower_center - 9.5 * unit), Vector2(group_width, 19.0 * unit))
	_coin_rect = Rect2(Vector2(price_x, lower_center - coin_edge * 0.5), Vector2.ONE * coin_edge)
	_price_label.position = Vector2(_coin_rect.end.x + 4.0 * unit, lower_center - 9.5 * unit)
	_price_position = _price_label.position
	_price_label.size = Vector2(price_width + unit, 19.0 * unit) / unit
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
		if not _goal.is_empty():
			pose.scale = 1.0
			pose.rotation = 0.0
			pose.offset = Vector2.ZERO
			pose.price_offset = Vector2(0.0, -rise * 2.5 / _ui_scale)
			pose.coin_scale = 1.0 + rise * 0.18
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
	var mastered: bool = not _goal.is_empty() and bool(_goal.mastered)
	if funds:
		fill = Style.SURFACE.lerp(Color("#ffedcf"), 0.65 + float(pose.light) * 0.35)
		accent = Color("#d28a43")
		ink = Color("#925026")
	elif mastered:
		fill = Color("#f5fbef")
		accent = Color("#edc45f").lerp(Color("#c5d9b0"), _goal_complete_progress)
		ink = Style.GOOD
	elif disabled and not celebrating:
		fill = Color("#f0f1eb")
		accent = Color("#b5bbb0")
		ink = Color("#64736b")
	elif not _affordable and not celebrating:
		accent = accent.lerp(Color("#b9b7af"), 0.28)
	elif is_hovered():
		fill = fill.lightened(0.28)
	if not _goal.is_empty() and _targeting and not disabled and not funds:
		fill = Color("#e6f5e8")
		accent = Style.GOOD
	_panel.bg_color = fill
	_panel.border_color = accent
	_panel.set_border_width_all(maxi(1, roundi((2.0 if funds or _targeting else 1.0) * unit)))
	_panel.set_corner_radius_all(maxi(1, roundi(13.0 * unit)))
	_panel.shadow_color = Color("#577777", 0.14)
	_panel.shadow_size = roundi(3.0 * unit)
	_panel.shadow_offset = Vector2(0.0, (1.0 if is_pressed() else 2.0) * unit)
	if has_focus() and not disabled and not funds:
		_panel.border_color = Style.GOOD
		_panel.set_border_width_all(maxi(1, roundi(2.0 * unit)))
	draw_style_box(_panel, Rect2(Vector2.ONE * unit, size - Vector2.ONE * 2.0 * unit))
	if not _goal.is_empty() and not mastered:
		var ratio: float = clampf(float(_goal.current) / maxf(1.0, float(_goal.required)), 0.0, 1.0)
		_progress_surface.bg_color = Color("#c1e1c5", 0.50)
		_progress_surface.set_corner_radius_all(maxi(1, roundi(12.0 * unit)))
		if ratio > 0.0:
			draw_style_box(_progress_surface, Rect2(Vector2.ONE * 2.0 * unit,
				Vector2(maxf(0.0, size.x - 4.0 * unit) * ratio, maxf(0.0, size.y - 4.0 * unit))))
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
		var glow_rect: Rect2 = _price_pill.grow(4.0 * unit) if funds or not _goal.is_empty() else Rect2(center - _icon_rect.size * 0.8, _icon_rect.size * 1.6)
		draw_texture_rect(GLOW, glow_rect, false, Color(light_color, light * (0.65 if funds else 1.0)))
	var press: float = 0.94 if is_pressed() and not disabled else 1.0
	draw_set_transform(center, float(pose.rotation), Vector2.ONE * float(pose.scale) * press)
	if not _goal.is_empty():
		pass
	elif _kind == "auto_merge":
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
		var region := Rect2(Vector2.ZERO, CHEST.get_size()) if warming else _chest_region
		var extent: Vector2 = region.size * (_icon_rect.size.x / maxf(1.0, region.size.x))
		draw_texture_rect_region(texture, Rect2(-extent * 0.5, extent), region, tint)
	draw_set_transform(Vector2.ZERO)
	if _capacity_label.visible:
		_capacity_badge.bg_color = Color("#706080") if disabled and not celebrating else Color("#745496")
		_capacity_badge.set_corner_radius_all(maxi(1, roundi(8.0 * unit)))
		draw_style_box(_capacity_badge, _capacity_rect)
		if _capacity_rect.size.x > 30.0 * unit:
			draw_texture_rect(GEL, Rect2(_capacity_rect.position + Vector2(4, 5) * unit,
				Vector2.ONE * 16.0 * unit), false)
	var coin_size: Vector2 = _coin_rect.size * float(pose.coin_scale)
	var coin_center: Vector2 = _coin_rect.get_center() + Vector2(pose.price_offset)
	if not mastered:
		draw_texture_rect(COIN, Rect2(coin_center - coin_size * 0.5, coin_size), false,
			Color(1.0, 1.0, 1.0, 0.75 if disabled and not celebrating and not funds else 1.0))
	if not _goal.is_empty() and celebrating and _spent_coins > 0 and not _goal_geometry.is_empty():
		var area: Rect2 = _goal_geometry.detail
		var alpha: float = 1.0 - smoothstep(0.65, 1.0, _feedback_elapsed / _duration())
		var pixels: int = maxi(1, roundi(11.0 * unit))
		var label: String = "-%d" % _spent_coins
		while pixels > 1 and Style.HEADING_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > area.size.x:
			pixels -= 1
		var at := Vector2(area.position.x, area.position.y + (area.size.y - Style.HEADING_FONT.get_height(pixels)) * 0.5 \
			+ Style.HEADING_FONT.get_ascent(pixels))
		draw_string(Style.HEADING_FONT, at, label, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, pixels, Color("#a36628", alpha))
	if light > 0.0 and not funds and _goal.is_empty():
		var offsets: Array[Vector2] = [Vector2(-0.42, -0.42), Vector2(0.48, -0.24), Vector2(0.38, 0.38)]
		for index in range(offsets.size()):
			var edge: float = (8.0 if index == 0 else 6.0) * unit
			var point: Vector2 = center + offsets[index] * _icon_rect.size
			draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color(light_color, light))


func snapshot() -> Dictionary:
	var pose: Dictionary = _pose()
	return {"kind": _kind, "price": _price, "available": _available, "affordable": _affordable, "targeting": _targeting,
		"preview_active": _preview_active,
		"auto_merge_level": _auto_merge_level, "capacity": _auto_merge_capacity,
		"capacity_badge": {"visible": _capacity_label.is_visible_in_tree(), "text": _capacity_label.text,
			"rect": [_capacity_rect.position.x, _capacity_rect.position.y, _capacity_rect.size.x, _capacity_rect.size.y]},
		"goal": not _goal.is_empty(), "spent_coins": _spent_coins if _feedback_active and _feedback_success and not _paused else 0,
		"progress_ratio": clampf(float(_goal.current) / maxf(1.0, float(_goal.required)), 0.0, 1.0) if not _goal.is_empty() else 0.0,
		"price_visible": _price_label.is_visible_in_tree(),
		"accessibility_name": str(get("accessibility_name")),
		"busy": _busy, "enabled": not disabled, "paused": _paused, "reduced_motion": _reduced_motion,
		"feedback_active": _feedback_active, "feedback_success": _feedback_success,
		"feedback_serial": _feedback_serial, "feedback_elapsed": _feedback_elapsed,
		"funds_warning": _funds_warning(), "missing_coins": _missing_coins, "balance_known": _balance_known,
		"price_offset": [pose.price_offset.x, pose.price_offset.y], "coin_scale": pose.coin_scale,
		"icon_scale": pose.scale, "icon_rotation": pose.rotation, "icon_offset": [pose.offset.x, pose.offset.y],
		"light": pose.light, "title": _title.text, "price_text": _price_label.text,
		"icon_rect": [_icon_rect.position.x, _icon_rect.position.y, _icon_rect.size.x, _icon_rect.size.y],
		"coin_rect": [_coin_rect.position.x, _coin_rect.position.y, _coin_rect.size.x, _coin_rect.size.y],
		"title_rect": [_title.position.x, _title.position.y, _title.size.x * _title.scale.x, _title.size.y * _title.scale.y],
		"price_rect": [_price_label.position.x, _price_label.position.y, _price_label.size.x * _price_label.scale.x, _price_label.size.y * _price_label.scale.y]}

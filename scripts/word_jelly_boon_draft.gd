extends Control
## Exaggerated Roguelite 3-pick Boon Draft shown every 5 Challenge waves.
## Pauses stage & combo clocks via model's pending_boon_options until one boon is picked.

signal boon_selected(boon_id: String)

const Style = preload("res://scripts/ui_style.gd")
const UiClick = preload("res://scripts/ui_click.gd")

var _shade := ColorRect.new()
var _panel := Panel.new()
var _heading: Label
var _subtitle: Label
var _cards_box := VBoxContainer.new()
var _options: Array[Dictionary] = []
var _buttons: Array[Button] = []


func _init() -> void:
	name = "ChallengeBoonDraft"
	z_index = 130
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.color = Color(Style.INK, 0.58)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.name = "BoonDraftPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_heading = Style.display_heading("Choose a Power Boon!", 26)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_heading)
	_subtitle = Style.label("Wave milestone reached! Pick 1 exaggerated boost for this Challenge run.", 13)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_color_override("font_color", Style.MUTED)
	_panel.add_child(_subtitle)
	_panel.add_child(_cards_box)
	resized.connect(_layout)
	hide()


func present(options: Array) -> void:
	_options.clear()
	for opt: Variant in options:
		if opt is Dictionary:
			_options.append(opt.duplicate(true))
	_rebuild_cards()
	visible = not _options.is_empty()
	_layout()
	if not _buttons.is_empty():
		_buttons[0].grab_focus.call_deferred()


func dismiss() -> void:
	_options.clear()
	hide()


func _rebuild_cards() -> void:
	for child: Node in _cards_box.get_children():
		child.queue_free()
	_buttons.clear()
	var s: float = Style.ui_scale(self)
	_cards_box.add_theme_constant_override("separation", ceili(10.0 / s))
	for opt: Dictionary in _options:
		var bid: String = str(opt.get("id", ""))
		var accent: Color = opt.get("accent", Style.GOOD)
		var btn := Button.new()
		btn.name = "BoonOption_" + bid
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.accessibility_name = "%s. %s" % [str(opt.get("name", "")), str(opt.get("desc", ""))]
		Style.action_button(btn, accent, false)
		btn.custom_minimum_size = Vector2(0, 74.0 / s)
		UiClick.bind_button(btn)
		btn.pressed.connect(func() -> void: boon_selected.emit(bid))
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side: String in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + side, ceili(14.0 / s))
		for side: String in ["top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, ceili(8.0 / s))
		btn.add_child(margin)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", ceili(10.0 / s))
		margin.add_child(row)
		var icon_path: String = str(opt.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			icon.custom_minimum_size = Vector2.ONE * 44.0 / s
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", ceili(3.0 / s))
		row.add_child(col)
		var title := Style.label("[%s]  %s" % [str(opt.get("tag", "BOON")), str(opt.get("name", ""))], ceili(16.0 / s))
		title.add_theme_font_override("font", Style.HEADING_FONT)
		title.add_theme_color_override("font_color", accent)
		var desc := Style.label(str(opt.get("desc", "")), ceili(12.5 / s))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(title)
		col.add_child(desc)
		_cards_box.add_child(btn)
		_buttons.append(btn)


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s: float = Style.ui_scale(self)
	var pad: float = 16.0 / s
	var w: float = minf(480.0 / s, maxf(240.0 / s, size.x - 28.0 / s))
	var h: float = minf(410.0 / s, maxf(240.0 / s, size.y - 28.0 / s))
	_panel.size = Vector2(w, h)
	_panel.position = (size - _panel.size) * 0.5
	_panel.add_theme_stylebox_override("panel", Style.parchment_panel(s, 14.0, 12.0))
	_heading.position = Vector2(pad, pad)
	_heading.size = Vector2(w - pad * 2.0, 34.0 / s)
	_heading.add_theme_font_size_override("font_size", ceili(24.0 / s))
	_subtitle.position = Vector2(pad, pad + 36.0 / s)
	_subtitle.size = Vector2(w - pad * 2.0, 34.0 / s)
	_subtitle.add_theme_font_size_override("font_size", ceili(12.5 / s))
	var list_top: float = pad + 78.0 / s
	_cards_box.position = Vector2(pad, list_top)
	_cards_box.size = Vector2(w - pad * 2.0, maxf(60.0 / s, h - list_top - pad))


func navigation_controls() -> Array[Control]:
	var result: Array[Control] = []
	for btn: Button in _buttons:
		if is_instance_valid(btn) and btn.visible and not btn.disabled:
			result.append(btn)
	return result


func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "options": _options.duplicate(true)}

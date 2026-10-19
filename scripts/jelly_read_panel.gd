extends Control
## A paused spelling detail. Scrolling reveals the full authored spelling.

signal dismissed
signal pronunciation_requested

const Style = preload("res://scripts/ui_style.gd")
var _shade := ColorRect.new()
var _panel := Panel.new()
var _heading := Style.label("Take a closer look", 20)
var _scroll := ScrollContainer.new()
var _text := Style.label("", 24)
var _help := Style.label("Swipe or scroll sideways to read the whole word.", 14)
var _close := Button.new()
var _listen := Button.new()
var _has_audio: bool = false

func _init() -> void:
	name = "JellyReadDetail"
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.color = Color(0.10, 0.20, 0.20, 0.46)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_panel.add_child(_heading)
	_panel.add_child(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.add_child(_text)
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.clip_text = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_help)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for button: Button in [_close, _listen]:
		_panel.add_child(button)
		Style.button(button, Style.GOOD)
	_close.text = "Keep playing"
	_listen.text = "Listen"
	_close.pressed.connect(func() -> void: dismissed.emit())
	_listen.pressed.connect(func() -> void: pronunciation_requested.emit())
	resized.connect(_layout)
	hide()

func present(spelling: String, has_audio: bool) -> void:
	_text.text = spelling
	_text.set("accessibility_name", spelling)
	_has_audio = has_audio
	_scroll.scroll_horizontal = 0
	show()
	_layout()
	_close.grab_focus()

func navigation_controls() -> Array[Control]:
	var result: Array[Control] = [_scroll]
	if _has_audio:
		result.append(_listen)
	result.append(_close)
	return result

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		dismissed.emit()
		get_viewport().set_input_as_handled()

func _layout() -> void:
	var s: float = Style.ui_scale(self)
	_shade.size = size
	var margin: float = 16.0 / s
	_panel.size = Vector2(minf(560.0 / s, maxf(0, size.x - margin * 2)), minf(230.0 / s, size.y))
	_panel.position = (size - _panel.size) * 0.5
	_panel.add_theme_stylebox_override("panel", Style.box(Style.PAPER, Style.EDGE, ceili(18.0 / s)))
	var inner_width: float = maxf(0.0, _panel.size.x - margin * 2)
	_heading.position = Vector2.ONE * margin
	_heading.size = Vector2(inner_width, 28.0 / s)
	_heading.add_theme_font_size_override("font_size", ceili(20.0 / s))
	_scroll.position = Vector2(margin, 52.0 / s)
	_scroll.size = Vector2(inner_width, 68.0 / s)
	_text.add_theme_font_size_override("font_size", ceili(24.0 / s))
	_text.custom_minimum_size.y = 44.0 / s
	_help.position = Vector2(margin, 126.0 / s)
	_help.size = Vector2(inner_width, 44.0 / s)
	_help.add_theme_font_size_override("font_size", ceili(14.0 / s))
	for button: Button in [_close, _listen]:
		button.custom_minimum_size = Vector2.ZERO
		button.size = Vector2((inner_width - 8.0 / s) * 0.5, 44.0 / s)
		button.add_theme_font_size_override("font_size", ceili(16.0 / s))
	_close.position = Vector2(_panel.size.x - margin - _close.size.x, _panel.size.y - margin - _close.size.y)
	_listen.position = Vector2(margin, _close.position.y)
	_listen.visible = _has_audio

func snapshot() -> Dictionary:
	return {"visible": visible, "text": _text.text, "scroll": _scroll.scroll_horizontal,
		"font_pixels": _text.get_theme_font_size("font_size") * Style.ui_scale(self), "has_audio": _has_audio}

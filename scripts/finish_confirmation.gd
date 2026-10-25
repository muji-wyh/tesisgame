extends Control
class_name FinishConfirmation
## Presents the choice; the host owns pausing, focus, and round completion.

signal canceled
signal confirmed

const Style = preload("res://scripts/ui_style.gd")
const UiClick = preload("res://scripts/ui_click.gd")

var keep_playing_button: Button
var finish_button: Button
var _shade: ColorRect
var _panel: Panel
var _heading: Label
var _caption: Label
var _palette: Dictionary = {}
var _reduced_motion: bool = false


func _init() -> void:
	name = "FinishConfirmation"
	z_index = 110
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade = ColorRect.new()
	_shade.name = "ModalShade"
	_shade.color = Color(Style.INK, 0.52)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = Panel.new()
	_panel.name = "ConfirmationPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_heading = Style.label("Finish this round?", 24)
	_heading.name = "ConfirmationTitle"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_heading)
	_caption = Style.label("Your collected rewards will be kept.", 16)
	_caption.name = "ConfirmationCaption"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_color_override("font_color", Style.MUTED)
	_panel.add_child(_caption)
	keep_playing_button = _make_button("KeepPlaying", "Keep playing")
	keep_playing_button.pressed.connect(func() -> void: canceled.emit())
	finish_button = _make_button("ConfirmFinish", "Finish")
	finish_button.pressed.connect(func() -> void: confirmed.emit())
	_link_focus(keep_playing_button, finish_button)
	_link_focus(finish_button, keep_playing_button)
	resized.connect(_layout)
	set_process(false)
	hide()


func _ready() -> void:
	_layout()


func _make_button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.set("accessibility_name", text)
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_panel.add_child(button)
	UiClick.bind_button(button)
	return button


func _link_focus(button: Button, other: Button) -> void:
	var path: NodePath = button.get_path_to(other)
	button.focus_next = path
	button.focus_previous = path
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		button.set_focus_neighbor(side, path)


func configure(palette: Dictionary, reduced_motion: bool) -> void:
	_palette = palette.duplicate()
	_reduced_motion = reduced_motion
	_layout()


func set_labels(heading: String, caption: String, primary: String, secondary: String) -> void:
	_heading.text = heading
	_caption.text = caption
	keep_playing_button.text = primary
	finish_button.text = secondary
	keep_playing_button.set("accessibility_name", primary)
	finish_button.set("accessibility_name", secondary)


func open() -> void:
	show()
	_layout()


func close() -> void:
	cancel_input()
	hide()


func cancel_input() -> void:
	# Web touch cancellation can be followed by an ordinary release.
	# Reset BaseButton's held state so that release cannot commit a decision.
	for button: Button in [keep_playing_button, finish_button]:
		var was_disabled: bool = button.disabled
		button.disabled = true
		button.disabled = was_disabled


func _layout() -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(finish_button):
		return
	var s: float = Style.ui_scale(self)
	var accent: Color = _palette.get("accent", Style.GOOD)
	var surface := Style.box(Style.PAPER, accent.lightened(0.70), ceili(24 / s), maxi(1, roundi(1 / s)))
	surface.shadow_color = Color(Style.INK, 0.22)
	surface.shadow_size = ceili(18 / s)
	surface.shadow_offset = Vector2(0, 6 / s)
	_panel.add_theme_stylebox_override("panel", surface)
	Style.action_button(keep_playing_button, accent, true)
	Style.action_button(finish_button, accent)
	var panel_width: float = minf(400 / s, maxf(0, size.x - 32 / s))
	var panel_height: float = 196 / s
	_panel.size = Vector2(panel_width, panel_height)
	_panel.position = (size - _panel.size) * 0.5
	var inset: float = (20 if panel_width * s < 340 else 24) / s
	var content_width: float = maxf(0, panel_width - 2 * inset)
	_heading.add_theme_font_size_override("font_size", ceili(24 / s))
	_heading.position = Vector2(inset, 20 / s)
	_heading.size = Vector2(content_width, 34 / s)
	_caption.add_theme_font_size_override("font_size", ceili(16 / s))
	_caption.position = Vector2(inset, 58 / s)
	_caption.size = Vector2(content_width, 44 / s)
	var gap: float = 12 / s
	var primary_width: float = (content_width - gap) * 0.57
	keep_playing_button.position = Vector2(inset, 124 / s)
	keep_playing_button.size = Vector2(primary_width, 48 / s)
	finish_button.position = Vector2(inset + primary_width + gap, 124 / s)
	finish_button.size = Vector2(content_width - primary_width - gap, 48 / s)


func snapshot() -> Dictionary:
	return {
		"visible": is_visible_in_tree(),
		"panel": _rect(_panel.get_global_rect()),
		"keep_playing": _button_snapshot(keep_playing_button),
		"confirm": _button_snapshot(finish_button),
		"reduced_motion": _reduced_motion
	}


func _button_snapshot(button: Button) -> Dictionary:
	return {
		"rect": _rect(button.get_global_rect()),
		"visible": button.is_visible_in_tree(),
		"disabled": button.disabled,
		"focused": button.has_focus()
	}


func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

extends Control
class_name RoundSettlement
## Shared completed-round content. The host owns the modal and reward lifecycle.

signal retry_requested
signal replay_requested
signal home_requested

const ChestView = preload("res://scripts/chest_view.gd")
const Style = preload("res://scripts/ui_style.gd")
const UiClick = preload("res://scripts/ui_click.gd")

var chest: ChestView
var chest_button: Button
var retry_button: Button
var replay_button: Button
var home_button: Button
var heading: Label
var caption: Label

var _palette: Dictionary = {}
var _has_chest: bool = false
var _saving: bool = false
var _save_failed: bool = false
var _opened: bool = false
var _compact: bool = false
var _appearance: Array = []


func _init() -> void:
	name = "RoundSettlement"
	mouse_filter = Control.MOUSE_FILTER_STOP
	heading = Style.label("Round complete", 24)
	heading.name = "SettlementHeading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(heading)
	caption = Style.label("", 14)
	caption.name = "SettlementCaption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.max_lines_visible = 3
	add_child(caption)
	chest = ChestView.new()
	chest.name = "SettlementChest"
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest.clip_contents = true
	add_child(chest)
	chest_button = Button.new()
	chest_button.name = "OpenSettlementChest"
	chest_button.focus_mode = Control.FOCUS_ALL
	chest_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chest_button.set("accessibility_name", "Hold to open the treasure chest")
	for state in ["normal", "hover", "pressed", "disabled"]:
		chest_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(chest_button)
	retry_button = _make_button("RetrySettlementSave", "Retry save")
	retry_button.pressed.connect(func() -> void:
		if _can_activate(retry_button):
			retry_requested.emit())
	home_button = _make_button("SettlementHome", "Home")
	home_button.pressed.connect(func() -> void:
		if _can_activate(home_button):
			home_requested.emit())
	replay_button = _make_button("SettlementReplay", "Play again")
	replay_button.pressed.connect(func() -> void:
		if _can_activate(replay_button):
			replay_requested.emit())
	resized.connect(_layout)
	configure({}, false, false, false, false)


func _ready() -> void:
	_layout()


func _make_button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.set("accessibility_name", text)
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	add_child(button)
	UiClick.bind_button(button)
	return button


func _can_activate(button: Button) -> bool:
	return button.is_visible_in_tree() and not button.disabled and button.can_process()


func configure(palette: Dictionary, has_chest: bool, saving: bool, save_failed: bool,
		opened: bool, message: String = "") -> void:
	_palette = palette.duplicate()
	_has_chest = has_chest
	_saving = saving
	_save_failed = save_failed
	_opened = opened
	heading.text = "Round complete"
	if not message.is_empty():
		caption.text = message
	elif save_failed:
		caption.text = "Could not save your reward. Please try again."
	elif saving:
		caption.text = "Saving your treasure..."
	elif opened:
		caption.text = "Treasure collected!"
	elif has_chest:
		caption.text = "Hold the chest to open"
	else:
		caption.text = "Every word matched!"
	caption.set("accessibility_description", caption.text)
	caption.add_theme_color_override("font_color", Style.WRONG if save_failed else Style.MUTED)
	chest.visible = has_chest
	chest_button.visible = has_chest
	chest_button.disabled = not has_chest or saving or save_failed or opened
	retry_button.visible = save_failed
	retry_button.disabled = saving and not save_failed
	retry_button.set("accessibility_description", message if save_failed else "")
	home_button.disabled = saving or save_failed
	replay_button.disabled = saving or save_failed
	_layout()


func _layout() -> void:
	if not is_instance_valid(replay_button):
		return
	var s: float = Style.ui_scale(self)
	var accent: Color = _palette.get("accent", Style.GOOD)
	if _appearance != [s, accent]:
		Style.action_button(home_button, accent)
		Style.action_button(replay_button, accent, true)
		Style.action_button(retry_button, accent)
		chest_button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT,
			accent, ceili(20 / s), maxi(2, roundi(2 / s))))
		_appearance = [s, accent]
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var margin: float = 4.0 / s
	var gap: float = 8.0 / s
	var action_h: float = 48.0 / s
	var inner_w: float = maxf(1.0, size.x - margin * 2.0)
	var action_y: float = size.y - margin - action_h
	var wide_actions: bool = size.x * s >= 420.0
	var action_count: int = 3 if _save_failed and wide_actions else 2
	var action_w: float = (inner_w - gap * (action_count - 1)) / action_count
	home_button.position = Vector2(margin, action_y)
	home_button.size = Vector2(action_w, action_h)
	replay_button.position = Vector2(size.x - margin - action_w, action_y)
	replay_button.size = Vector2(action_w, action_h)
	var stage_bottom: float = action_y - gap
	if _save_failed:
		if wide_actions:
			retry_button.position = Vector2(margin + action_w + gap, action_y)
			retry_button.size = Vector2(action_w, action_h)
		else:
			stage_bottom -= action_h
			retry_button.position = Vector2(margin, stage_bottom)
			retry_button.size = Vector2(inner_w, action_h)
			stage_bottom -= gap
	var stage_h: float = maxf(0.0, stage_bottom - margin)
	_compact = _has_chest and inner_w * s >= 380.0 and stage_h * s < 320.0
	var tight: bool = stage_h * s < 180.0
	var heading_h: float = (28.0 if tight else 36.0) / s
	var caption_h: float = (50.0 if _save_failed else 38.0) / s
	heading.add_theme_font_size_override("font_size", ceili((20.0 if tight else 24.0) / s))
	caption.add_theme_font_size_override("font_size", ceili((12.0 if tight else 14.0) / s))
	if _compact:
		var info_w: float = inner_w * 0.43
		var info_h: float = heading_h + gap + caption_h
		var info_top: float = margin + maxf(0.0, (stage_h - info_h) * 0.5)
		heading.position = Vector2(margin, info_top)
		heading.size = Vector2(info_w, heading_h)
		caption.position = Vector2(margin, info_top + heading_h + gap)
		caption.size = Vector2(info_w, caption_h)
		chest.position = Vector2(margin + info_w + gap, margin)
		chest.size = Vector2(maxf(0.0, inner_w - info_w - gap), stage_h)
	elif _has_chest:
		heading.position = Vector2(margin, margin)
		heading.size = Vector2(inner_w, heading_h)
		caption.position = Vector2(margin, stage_bottom - caption_h)
		caption.size = Vector2(inner_w, caption_h)
		var chest_top: float = margin + heading_h + gap
		var chest_h: float = maxf(0.0, caption.position.y - gap - chest_top)
		var chest_w: float = minf(inner_w, 410.0 / s)
		chest.position = Vector2((size.x - chest_w) * 0.5, chest_top)
		chest.size = Vector2(chest_w, chest_h)
	else:
		var info_h: float = heading_h + gap + caption_h
		var info_top: float = margin + maxf(0.0, (stage_h - info_h) * 0.5)
		heading.position = Vector2(margin, info_top)
		heading.size = Vector2(inner_w, heading_h)
		caption.position = Vector2(margin, info_top + heading_h + gap)
		caption.size = Vector2(inner_w, caption_h)
		chest.position = Vector2.ZERO
		chest.size = Vector2.ZERO
	chest_button.position = chest.position
	chest_button.size = chest.size
	_update_focus()


func _update_focus() -> void:
	var actions: Array[Button] = []
	for button: Button in [chest_button, retry_button, home_button, replay_button]:
		if button.visible and not button.disabled:
			actions.append(button)
	for index in range(actions.size()):
		var button: Button = actions[index]
		var previous: NodePath = button.get_path_to(actions[posmod(index - 1, actions.size())])
		var next: NodePath = button.get_path_to(actions[(index + 1) % actions.size()])
		button.focus_previous = previous
		button.focus_next = next
		button.set_focus_neighbor(SIDE_LEFT, previous)
		button.set_focus_neighbor(SIDE_TOP, previous)
		button.set_focus_neighbor(SIDE_RIGHT, next)
		button.set_focus_neighbor(SIDE_BOTTOM, next)


func snapshot() -> Dictionary:
	return {
		"visible": is_visible_in_tree(), "rect": _rect(get_global_rect()),
		"heading": heading.text, "caption": caption.text,
		"has_chest": _has_chest, "saving": _saving, "save_failed": _save_failed,
		"opened": _opened, "compact": _compact,
		"chest": {"visible": chest.is_visible_in_tree(), "rect": _rect(chest.get_global_rect())},
		"chest_button": _button_snapshot(chest_button),
		"retry": _button_snapshot(retry_button), "replay": _button_snapshot(replay_button),
		"home": _button_snapshot(home_button),
		"actions": [_button_snapshot(home_button), _button_snapshot(retry_button), _button_snapshot(replay_button)]
	}


func _button_snapshot(button: Button) -> Dictionary:
	return {
		"name": str(button.name), "text": button.text, "rect": _rect(button.get_global_rect()),
		"visible": button.is_visible_in_tree(), "disabled": button.disabled,
		"focused": button.has_focus()
	}


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

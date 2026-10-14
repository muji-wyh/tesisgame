extends Control
class_name RoundSettlement
## Shared completed-round content. The host owns the modal and reward lifecycle.

signal retry_requested
signal replay_requested
signal home_requested

const ChestView = preload("res://scripts/chest_view.gd")
const Style = preload("res://scripts/ui_style.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const RewardLayout = preload("res://scripts/round_reward_layout.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const TREASURE_LIGHT = preload("res://assets/chests/particles/portal_glow.png")

var pip: Mascot
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
var _chest_light := TextureRect.new()


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
	pip = Mascot.new()
	pip.name = "SettlementPip"
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.focus_mode = Control.FOCUS_NONE
	pip.set_proactive_allowed(false)
	add_child(pip)
	_chest_light.texture = TREASURE_LIGHT
	_chest_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chest_light.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chest_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chest_light)
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
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		chest_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(chest_button)
	chest_button.focus_entered.connect(_refresh_chest_focus)
	chest_button.focus_exited.connect(_refresh_chest_focus)
	chest_button.mouse_entered.connect(_refresh_chest_focus)
	chest_button.mouse_exited.connect(_refresh_chest_focus)
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
	visibility_changed.connect(_sync_companion)
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
	_sync_companion()
	_layout()


func _refresh_chest_focus() -> void:
	var focused: bool = chest_button.has_focus() and not chest_button.disabled
	var hovered: bool = chest_button.is_hovered() and not chest_button.disabled
	_chest_light.visible = _has_chest
	_chest_light.modulate = Color("#ebcd85", 0.52 if focused else 0.38 if hovered else 0.22)
	caption.add_theme_color_override("font_color", Style.WRONG if _save_failed else
		Style.GOOD if focused or hovered or _opened else Style.MUTED)


func _sync_companion() -> void:
	if not is_instance_valid(pip):
		return
	pip.set_outfit_theme(chest.theme_id)
	pip.set_reduced_motion(chest.reduced_motion)
	pip.set_celebration_progress(1.0)
	pip.set_idle_paused(not is_visible_in_tree())


func _layout() -> void:
	if not is_instance_valid(replay_button):
		return
	var s: float = Style.ui_scale(self)
	var accent: Color = _palette.get("accent", Style.GOOD)
	if _appearance != [s, accent]:
		Style.action_button(home_button, accent)
		Style.action_button(replay_button, accent, true)
		Style.action_button(retry_button, accent)
		_appearance = [s, accent]
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var layout: Dictionary = RewardLayout.measure(size, s, _has_chest, _save_failed)
	_compact = layout.compact
	for item: Array in [[heading, "heading"], [caption, "caption"], [pip, "pip"], [chest, "chest"],
		[home_button, "home"], [replay_button, "replay"], [retry_button, "retry"]]:
		var control: Control = item[0]
		var rect: Rect2 = layout[item[1]]
		control.custom_minimum_size = Vector2.ZERO
		control.position = rect.position
		control.size = rect.size
	heading.add_theme_font_size_override("font_size", layout.heading_size)
	caption.add_theme_font_size_override("font_size", layout.caption_size)
	chest_button.position = chest.position
	chest_button.size = chest.size
	_chest_light.size = Vector2.ONE * minf(chest.size.x, chest.size.y * 1.15)
	_chest_light.position = chest.position + Vector2(chest.size.x * 0.5, chest.size.y * 0.60) - _chest_light.size * 0.5
	_refresh_chest_focus()
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
		"heading": heading.text, "caption": caption.text, "pip_rect": _rect(pip.get_global_rect()),
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

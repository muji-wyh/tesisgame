extends RefCounted
## Connect menu actions before their handlers so navigation keeps one short cue.


static func bind_button(button: BaseButton) -> void:
	var callback := _on_pressed.bind(button)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


static func _on_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.is_queued_for_deletion() or not button.is_inside_tree() \
		or not button.is_visible_in_tree() or button.disabled or not button.can_process():
		return
	var ancestor: Node = button
	while ancestor != null:
		if ancestor.has_method("_play_ui_click"):
			ancestor.call("_play_ui_click", button)
			if ancestor.has_method("trigger_haptic"):
				ancestor.call("trigger_haptic", "tap")
			return
		ancestor = ancestor.get_parent()

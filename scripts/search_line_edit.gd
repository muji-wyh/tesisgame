extends LineEdit
## Preserve Web search notifications when the last characters are removed.

var _change_revision: int = 0


func _init() -> void:
	text_changed.connect(func(_value: String) -> void: _change_revision += 1)


# Godot 4.7 Viewport::_push_text_input dynamically calls this method. Its native
# LineEdit implementation clears before comparing, so an empty replacement can
# omit text_changed. Keep native editing behavior and supplement only a missing
# notification; a future engine that emits correctly will not be notified twice.
@warning_ignore("native_method_override")
func _set_text(value: String, emit_changed: bool = false) -> void:
	var previous: String = text
	var revision: int = _change_revision
	super._set_text(value, emit_changed)
	if emit_changed and text != previous and _change_revision == revision:
		text_changed.emit(text)

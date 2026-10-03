extends "res://scripts/result_scroll.gd"

signal hold_started(control: Button)
signal hold_finished

var _hold_target: Button


func _begin(point: Vector2, pointer: int, touch_id: int = -1) -> void:
	super._begin(point, pointer, touch_id)
	if is_instance_valid(_target):
		_hold_target = _target
		hold_started.emit(_hold_target)


func _end_pointer_hold() -> void:
	var was_holding: bool = is_instance_valid(_hold_target)
	_hold_target = null
	if was_holding:
		hold_finished.emit()


func _move(point: Vector2) -> void:
	super._move(point)
	# Any deliberate swipe cancels a hold, even across the scrolling axis.
	if _travel >= _threshold():
		_end_pointer_hold()


func _clear_pointer() -> void:
	var was_holding: bool = is_instance_valid(_hold_target)
	_hold_target = null
	super._clear_pointer()
	# Clear ownership first: cancellation can refresh the containing room.
	if was_holding:
		hold_finished.emit()


func _finish(point: Vector2, canceled: bool = false) -> void:
	if not canceled:
		_move(point)
	var target := _target
	var tapped: bool = not canceled and not _braking and _travel < _threshold() and _contains(point)
	if not canceled and _dragging:
		_motion.release(_now())
	else:
		_motion.stop()
	_clear_pointer()
	set_process(_motion.is_active())
	# Chests react to the held press, never to an extra synthetic click.
	if tapped and is_instance_valid(target) and target == _button_at(point):
		target.grab_focus()

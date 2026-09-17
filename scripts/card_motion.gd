extends RefCounted

var _tween: Tween
var _target: Control
var _scale_y: float = 1.0
var _rotation: float = 0.0
var _pivot := Vector2.ZERO


func play(target: Control, reduced_motion: bool) -> void:
	stop()
	if reduced_motion or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	_target = target
	_scale_y = target.scale.y
	_rotation = target.rotation
	_pivot = target.pivot_offset
	target.pivot_offset = target.size * 0.5
	_tween = target.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pose(0.94, -0.018, 0.06)
	_pose(1.025, 0.012, 0.12)
	_pose(1.0, 0.0, 0.12)
	_tween.tween_callback(stop)


func _pose(stretch: float, angle: float, duration: float) -> void:
	_tween.tween_property(_target, "scale:y", _scale_y * stretch, duration)
	_tween.parallel().tween_property(_target, "rotation", _rotation + angle, duration)


func stop() -> void:
	if _tween != null:
		_tween.kill()
	_tween = null
	if is_instance_valid(_target):
		_target.scale.y = _scale_y
		_target.rotation = _rotation
		_target.pivot_offset = _pivot
	_target = null

extends RefCounted

const Style = preload("res://scripts/ui_style.gd")
# ponytail: six reviewed nouns; unlisted pictures stay still instead of guessing their motion.
const WORDS := ["ball", "bell", "rocket", "fish", "boat", "flower"]

var _tween: Tween
var _target: Control
var _position := Vector2.ZERO
var _scale := Vector2.ONE
var _rotation := 0.0
var _pivot := Vector2.ZERO


func play(target: Control, word_id: String, reduced_motion: bool) -> void:
	stop()
	if reduced_motion or not WORDS.has(word_id) or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	_target = target
	_position = target.position
	_scale = target.scale
	_rotation = target.rotation
	_pivot = target.pivot_offset
	target.pivot_offset = target.size * Vector2(0.5, 0.05 if word_id == "bell" else 1.0 if word_id in ["ball", "flower"] else 0.5)
	var distance: float = minf(12 / Style.ui_scale(target), minf(target.size.x, target.size.y) * 0.045)
	_tween = target.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	match word_id:
		"ball":
			_pose(Vector2.ZERO, Vector2(1.04, 0.9), 0, 0.08)
			_pose(Vector2(0, -distance), Vector2(0.98, 1.02), 0, 0.16)
			_pose(Vector2.ZERO, Vector2(1.025, 0.97), 0, 0.16)
			_pose(Vector2.ZERO, Vector2.ONE, 0, 0.12)
		"bell":
			_pose(Vector2.ZERO, Vector2.ONE, -0.16, 0.12)
			_pose(Vector2.ZERO, Vector2.ONE, 0.13, 0.14)
			_pose(Vector2.ZERO, Vector2.ONE, -0.07, 0.1)
			_pose(Vector2.ZERO, Vector2.ONE, 0, 0.12)
		"rocket":
			_pose(Vector2(0, distance * 0.15), Vector2(1.02, 0.97), 0, 0.08)
			_pose(Vector2(0, -distance), Vector2(0.98, 1.02), 0, 0.22)
			_pose(Vector2(0, -distance * 0.4), Vector2.ONE, 0, 0.1)
			_pose(Vector2.ZERO, Vector2.ONE, 0, 0.14)
		"fish":
			_pose(Vector2(-distance, distance * 0.15), Vector2.ONE, -0.05, 0.16)
			_pose(Vector2(distance, -distance * 0.15), Vector2.ONE, 0.05, 0.18)
			_pose(Vector2.ZERO, Vector2.ONE, 0, 0.18)
		"boat":
			_pose(Vector2(distance * 0.3, -distance * 0.3), Vector2.ONE, -0.065, 0.16)
			_pose(Vector2(-distance * 0.3, distance * 0.2), Vector2.ONE, 0.05, 0.18)
			_pose(Vector2.ZERO, Vector2.ONE, 0, 0.18)
		"flower":
			_pose(Vector2.ZERO, Vector2(0.94, 0.86), 0, 0.08)
			_pose(Vector2.ZERO, Vector2(1.015, 1.035), 0, 0.24)
			_pose(Vector2.ZERO, Vector2.ONE, 0, 0.22)
	_tween.tween_callback(stop)


func _pose(offset: Vector2, stretch: Vector2, angle: float, duration: float) -> void:
	_tween.tween_property(_target, "position", _position + offset, duration)
	_tween.parallel().tween_property(_target, "scale", _scale * stretch, duration)
	_tween.parallel().tween_property(_target, "rotation", _rotation + angle, duration)


func stop() -> void:
	if _tween != null:
		_tween.kill()
	_tween = null
	if is_instance_valid(_target):
		_target.position = _position
		_target.scale = _scale
		_target.rotation = _rotation
		_target.pivot_offset = _pivot
	_target = null

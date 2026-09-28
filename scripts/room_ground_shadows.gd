extends Control

var duck_slot: Control
var active_toy: Control
var owned_toys: Control
var playground: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func track(control: Control) -> void:
	if not control.item_rect_changed.is_connected(queue_redraw):
		control.item_rect_changed.connect(queue_redraw)
	if not control.visibility_changed.is_connected(queue_redraw):
		control.visibility_changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(duck_slot) and duck_slot.is_visible_in_tree():
		var edge := minf(duck_slot.size.x, duck_slot.size.y)
		var baseline := (duck_slot.size.y - edge) * 0.5 + edge * (112.0 / 120.0)
		var foot: Vector2 = _local_point(duck_slot, Vector2(0.5, baseline / maxf(1, duck_slot.size.y)))
		_contact(foot, edge * 0.34, edge * 0.042, 0.17)
	if is_instance_valid(active_toy) and active_toy.is_visible_in_tree() and not playground.toy_locked and playground.toy_phase != "flying":
		_toy_contact(active_toy)
	if is_instance_valid(owned_toys):
		for toy: Control in owned_toys.get_children():
			if toy.is_visible_in_tree():
				_toy_contact(toy)


func _local_point(control: Control, proportion: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * control.get_global_transform() * (control.size * proportion)


func _toy_contact(toy: Control) -> void:
	var foot: Vector2 = _local_point(toy, Vector2(0.5, 0.90))
	_contact(foot, toy.size.x * 0.35, toy.size.y * 0.055, 0.12)


func _contact(foot: Vector2, width: float, depth: float, opacity: float) -> void:
	# Separate soft penumbra and contact core ground the sprites without dark outlines.
	var shade := Color("#584835")
	for layer in range(5, 0, -1):
		var spread: float = 1.0 + layer * 0.18
		shade.a = opacity / 5.0
		draw_set_transform(foot + Vector2(layer * 0.65, layer * 0.15), 0, Vector2(width * spread, maxf(1, depth * spread)))
		draw_circle(Vector2.ZERO, 1, shade, true, -1, true)
	draw_set_transform(Vector2.ZERO)

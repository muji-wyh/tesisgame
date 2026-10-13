extends Control
## Acquired treasure and light artwork follows the powerup's gameplay clock.

var stamps: Array[Dictionary] = []

func _init() -> void:
	name = "PowerupEffects"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 41

func present(next: Array[Dictionary]) -> void:
	stamps = next
	queue_redraw()

func reset() -> void:
	stamps.clear()
	queue_redraw()

func _draw() -> void:
	for stamp: Dictionary in stamps:
		var texture: Texture2D = stamp.texture
		if texture == null:
			continue
		var extent: Vector2 = stamp.size
		draw_set_transform(stamp.center, float(stamp.get("rotation", 0.0)))
		draw_texture_rect(texture, Rect2(-extent * 0.5, extent), false, stamp.get("color", Color.WHITE))
	draw_set_transform(Vector2.ZERO)

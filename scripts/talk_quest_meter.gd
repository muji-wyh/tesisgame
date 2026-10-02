extends ProgressBar
## Health has a delayed damage trail; cooperative progress uses a rising mint fill.

var reduced_motion: bool = false
var cooperative: bool = false
var trail_value: float = 0.0
var _target: float = 0.0
var _flash: float = 0.0
var _wait: float = 0.0
var _initialized: bool = false


func _ready() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("background", empty)
	add_theme_stylebox_override("fill", empty)


func reset_value(next_value: float, maximum: float, repair: bool) -> void:
	cooperative = repair
	max_value = maxf(1.0, maximum)
	value = next_value
	_target = next_value
	trail_value = next_value
	_initialized = true
	_flash = 0.0
	queue_redraw()


func present(next_value: float, maximum: float, repair: bool, animate: bool = true) -> void:
	if not _initialized or maximum != max_value or repair != cooperative:
		reset_value(next_value, maximum, repair)
		return
	if not is_equal_approx(_target, next_value):
		_target = next_value
		_flash = 1.0
		_wait = 0.35
	if reduced_motion or not animate:
		value = _target
		trail_value = _target
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if is_equal_approx(value, _target) and is_equal_approx(trail_value, _target) and _flash <= 0.0:
		return
	value = move_toward(value, _target, delta * max_value * 2.8)
	_wait = maxf(0.0, _wait - delta)
	if _wait <= 0.0:
		trail_value = move_toward(trail_value, _target, delta * max_value * 1.1)
	_flash = maxf(0.0, _flash - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var outer := StyleBoxFlat.new()
	outer.bg_color = Color("#26344de8")
	outer.border_color = Color("#fff3d1")
	outer.set_border_width_all(2)
	outer.set_corner_radius_all(12)
	outer.shadow_color = Color("#19233c45")
	outer.shadow_size = 4
	outer.shadow_offset = Vector2(0, 2)
	draw_style_box(outer, Rect2(Vector2.ZERO, size))
	var area := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	if area.size.y <= 0:
		return
	var shade := StyleBoxFlat.new()
	shade.set_corner_radius_all(8)
	shade.bg_color = Color("#ffd07b")
	if not cooperative and trail_value > value:
		draw_style_box(shade, Rect2(area.position, Vector2(area.size.x * trail_value / max_value, area.size.y)))
	var fraction: float = clampf(value / max_value, 0, 1)
	if fraction > 0.001:
		shade.bg_color = Color("#60d2bb") if cooperative else Color("#a699ed") if fraction > 0.33 else Color("#efa285")
		shade.bg_color = shade.bg_color.lerp(Color("#fff3c5"), _flash * 0.30)
		var fill := Rect2(area.position, Vector2(area.size.x * fraction, area.size.y))
		draw_style_box(shade, fill)
		draw_line(fill.position + Vector2(5, 3), Vector2(maxf(fill.position.x + 5, fill.end.x - 5), fill.position.y + 3), Color("#ffffff77"), 2, true)
	var ticks: int = 5 if cooperative else mini(40, int(max_value))
	for index in range(1, ticks):
		var x: float = area.position.x + area.size.x * float(index) / ticks
		draw_line(Vector2(x, area.position.y + 1), Vector2(x, area.end.y - 1), Color("#26344d50"), 1, true)

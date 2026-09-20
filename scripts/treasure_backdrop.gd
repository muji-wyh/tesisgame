extends Control

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const SKY_COLORS: Dictionary = {
	"spring": Color("#d7efda"), "summer": Color("#cfeef2"),
	"autumn": Color("#f7d7ae"), "winter": Color("#c8ddf3"),
	"ocean": Color("#b5e3e9"), "space": Color("#cbb9e8"),
	"jungle": Color("#bfdca7"), "candy": Color("#f6d0e5")
}
const GROUND_COLORS: Dictionary = {
	"spring": Color("#b8dca6"), "summer": Color("#f4d69a"),
	"autumn": Color("#e9bd83"), "winter": Color("#ffffff"),
	"ocean": Color("#9bd2da"), "space": Color("#bcacd7"),
	"jungle": Color("#9fc58c"), "candy": Color("#ecc2dd")
}

var theme_id: String = "spring"
var palette: Dictionary = {}
var _sky := GradientTexture2D.new()
var _theme_icon: Texture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)


func _ready() -> void:
	if palette.is_empty():
		configure(Data.theme("spring"))


func configure(next_palette: Dictionary) -> void:
	if palette == next_palette:
		return
	palette = next_palette.duplicate(true)
	theme_id = str(palette.get("id", "spring"))
	var background: Color = palette.get("background", Color("#effbef"))
	var sky_color: Color = SKY_COLORS.get(theme_id, background)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gradient.colors = PackedColorArray([sky_color, background, background.lightened(0.12)])
	_sky.gradient = gradient
	_sky.width = 4
	_sky.height = 256
	_sky.fill_from = Vector2(0.5, 0)
	_sky.fill_to = Vector2(0.5, 1)
	_theme_icon = load("res://assets/images/rewards/" + theme_id + ".svg") if Data.THEMES.has(theme_id) else null
	queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0 or palette.is_empty():
		return
	var edge: float = minf(size.x, size.y)
	var ground: Color = GROUND_COLORS.get(theme_id, palette.get("light", Color("#bfe9c5")))
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, size), false)
	_ground(0.82, -0.085, ground.lightened(0.17))
	_ground(0.96, -0.035, ground)
	match theme_id:
		"spring": _draw_spring(edge)
		"summer": _draw_summer(edge)
		"autumn": _draw_autumn(edge)
		"winter": _draw_winter(edge)
		"ocean": _draw_ocean(edge)
		"space": _draw_space(edge)
		"jungle": _draw_jungle(edge)
		"candy": _draw_candy(edge)
	# The chest occupies x=19..81%, y=29..89%; the reward sits at bottom right.
	# Keep those areas quiet, with only a soft landing beneath the chest.
	_ellipse(_point(0.5, 0.875), Vector2(size.x * 0.31, size.y * 0.068), Color(ground.darkened(0.18), 0.10))
	_ellipse(_point(0.5, 0.858), Vector2(size.x * 0.29, size.y * 0.052), Color(Color.WHITE, 0.28))
	_draw_theme_name(edge)


func _draw_spring(edge: float) -> void:
	var green := Color("#73a96c")
	for blade in [Vector3(0.035, 0.92, -0.35), Vector3(0.08, 0.94, 0.16), Vector3(0.105, 0.95, 0.44)]:
		_leaf(_point(blade.x, blade.y), edge * 0.19, edge * 0.055, blade.z, green.lightened(blade.x))
	var flower := _point(0.09, 0.64)
	draw_line(flower, _point(0.075, 0.89), green, maxf(1.5, edge * 0.009), true)
	_leaf(_point(0.082, 0.81), edge * 0.10, edge * 0.045, -0.95, green.lightened(0.12))
	_flower(flower, edge * 0.052, Color("#f4b4c3"))
	_flower(_point(0.15, 0.84), edge * 0.034, Color("#fff0b0"))
	var upper_flower := _point(0.89, 0.16)
	draw_line(upper_flower, _point(0.96, 0.34), green.lightened(0.22), maxf(1.5, edge * 0.008), true)
	_leaf(_point(0.95, 0.31), edge * 0.11, edge * 0.05, -0.85, green.lightened(0.22))
	_flower(upper_flower, edge * 0.075, Color("#ffe4a1"))


func _draw_summer(edge: float) -> void:
	var sun := _point(0.86, 0.17)
	var radius: float = edge * 0.092
	for index in range(10):
		var direction := Vector2.from_angle(float(index) * TAU / 10.0)
		draw_line(sun + direction * radius * 1.28, sun + direction * radius * 1.63, Color("#e7b858"), maxf(2, edge * 0.012), true)
	draw_circle(sun, radius, Color("#f8ce76"))
	draw_arc(sun, radius * 0.70, PI * 1.08, PI * 1.61, 16, Color("#fff0b6"), maxf(2, edge * 0.012), true)
	_ground(0.76, -0.035, Color("#b8dde0"), 0.009)
	_ground(0.815, -0.035, Color("#fff0cd"), 0.012)
	_ground(0.875, -0.045, Color("#f4d69a"), 0.008)
	var shell := _point(0.105, 0.79)
	var shell_size: float = edge * 0.073
	var outline := PackedVector2Array([shell + Vector2(0, shell_size * 0.5)])
	for index in range(17):
		var angle: float = PI + float(index) * PI / 16.0
		outline.append(shell + Vector2(cos(angle), sin(angle)) * shell_size)
	draw_colored_polygon(outline, Color("#f9c4ab"))
	for index in range(1, 6):
		var angle: float = PI + float(index) * PI / 6.0
		draw_line(outline[0], shell + Vector2(cos(angle), sin(angle)) * shell_size * 0.83, Color("#d5997b"), maxf(1, edge * 0.004), true)
	for index in range(3):
		var start := _point(0.015 + float(index) * 0.025, 0.91 + float(index) * 0.028)
		draw_line(start, start + Vector2(edge * 0.085, -edge * 0.012), Color("#ddb979"), maxf(1, edge * 0.005), true)


func _draw_autumn(edge: float) -> void:
	var branch := PackedVector2Array([_point(1.015, 0.43), _point(0.95, 0.23), _point(0.87, 0.035)])
	draw_polyline(branch, Color("#bb895d"), maxf(2, edge * 0.018), true)
	_leaf(_point(0.95, 0.235), edge * 0.16, edge * 0.075, -0.68, Color("#d4a15c"))
	_leaf(_point(0.92, 0.16), edge * 0.14, edge * 0.07, 1.02, Color("#d79573"))
	_leaf(_point(0.975, 0.32), edge * 0.15, edge * 0.068, -0.98, Color("#e6b76c"))
	_leaf(_point(0.14, 0.78), edge * 0.13, edge * 0.075, -0.55, Color("#d99263"))
	_leaf(_point(0.105, 0.88), edge * 0.10, edge * 0.058, 0.72, Color("#c6a26b"))
	_leaf(_point(0.16, 0.95), edge * 0.10, edge * 0.058, -1.2, Color("#e2aa69"))
	_leaf(_point(0.07, 0.44), edge * 0.075, edge * 0.043, 0.55, Color("#e1b274"))


func _draw_winter(edge: float) -> void:
	_ground(0.855, -0.075, Color("#edf5fd"), 0.011)
	_ground(0.925, -0.06, Color.WHITE, 0.018)
	_snowflake(_point(0.87, 0.16), edge * 0.086, Color("#7ba2c7"), maxf(1.5, edge * 0.009))
	_snowflake(_point(0.09, 0.45), edge * 0.049, Color("#a1bcd8"), maxf(1, edge * 0.006))
	_snowflake(_point(0.15, 0.74), edge * 0.027, Color("#aac4db"), maxf(1, edge * 0.005))
	_snowflake(_point(0.62, 0.12), edge * 0.023, Color("#f7fbff"), maxf(1, edge * 0.005))
	_ellipse(_point(0.015, 0.88), Vector2(edge * 0.16, edge * 0.06), Color("#dbe8f4"), -0.18)
	_ellipse(_point(0.01, 0.865), Vector2(edge * 0.16, edge * 0.055), Color.WHITE, -0.18)


func _draw_ocean(edge: float) -> void:
	_ground(0.79, -0.025, Color("#b8e2e8"), 0.024)
	_ground(0.86, -0.03, Color("#8ecad5"), 0.022)
	_ground(0.915, -0.02, Color("#bce5e8"), 0.016)
	_wave(0.79, 0.024, Color("#eefafa"), maxf(1.5, edge * 0.009))
	for bubble in [Vector3(0.88, 0.14, 0.050), Vector3(0.96, 0.27, 0.027), Vector3(0.77, 0.08, 0.022), Vector3(0.085, 0.44, 0.029), Vector3(0.145, 0.58, 0.018)]:
		var center := _point(bubble.x, bubble.y)
		var radius: float = edge * bubble.z
		draw_circle(center, radius, Color(1, 1, 1, 0.16))
		draw_arc(center, radius, 0, TAU, 32, Color("#6caebb"), maxf(1, edge * 0.005), true)
		draw_arc(center, radius * 0.71, PI * 1.10, PI * 1.62, 12, Color.WHITE, maxf(1, edge * 0.006), true)
	for index in range(3):
		var root_point := _point(0.045 + float(index) * 0.04, 0.94)
		var stem := PackedVector2Array()
		for step in range(17):
			var t: float = float(step) / 16.0
			stem.append(root_point + Vector2(sin(t * TAU + index) * edge * 0.022, -t * edge * (0.17 + index * 0.022)))
		draw_polyline(stem, Color("#73a99a"), maxf(2, edge * 0.018), true)


func _draw_space(edge: float) -> void:
	var planet := _point(0.86, 0.16)
	var radius: float = edge * 0.079
	_ellipse_arc(planet, Vector2(radius * 1.65, radius * 0.54), -0.32, 0, TAU, Color("#ecd195"), maxf(2, edge * 0.018))
	draw_circle(planet, radius, Color("#a997d4"))
	draw_arc(planet + Vector2(-radius * 0.14, -radius * 0.14), radius * 0.67, PI * 1.06, PI * 1.61, 20, Color("#cfc3ec"), maxf(2, edge * 0.019), true)
	_ellipse_arc(planet, Vector2(radius * 1.65, radius * 0.54), -0.32, 0, PI, Color("#f7dea6"), maxf(2, edge * 0.019))
	for star in [Vector3(0.64, 0.13, 0.021), Vector3(0.95, 0.40, 0.023), Vector3(0.085, 0.44, 0.027), Vector3(0.155, 0.63, 0.016), Vector3(0.055, 0.79, 0.016)]:
		_star(_point(star.x, star.y), edge * star.z, Color("#fff0be"))
	_ellipse(_point(0.075, 0.91), Vector2(edge * 0.065, edge * 0.019), Color("#a998c6"), -0.15)
	_ellipse(_point(0.16, 0.97), Vector2(edge * 0.035, edge * 0.012), Color("#a998c6"), 0.1)


func _draw_jungle(edge: float) -> void:
	for index in range(2):
		var x: float = 0.9 + float(index) * 0.085
		var vine := PackedVector2Array()
		for step in range(25):
			var t: float = float(step) / 24.0
			vine.append(_point(x + sin(t * PI * 1.6) * 0.022, -0.03 + t * (0.57 - index * 0.12)))
		draw_polyline(vine, Color("#679664"), maxf(2, edge * 0.011), true)
		for leaf_index in range(3):
			var point: Vector2 = vine[5 + leaf_index * 6]
			_leaf(point, edge * 0.12, edge * 0.062, -0.75 if leaf_index % 2 == 0 else 1.10, Color("#82b174") if index == 0 else Color("#a2c485"))
	var fern := _point(0.05, 0.97)
	for index in range(5):
		_leaf(fern, edge * (0.19 + sin(index * 0.7) * 0.06), edge * 0.064, -0.55 + index * 0.28, Color("#7eab70").lightened(index * 0.028))
	_leaf(_point(0.025, 0.51), edge * 0.15, edge * 0.065, 0.60, Color("#91b97b"))


func _draw_candy(edge: float) -> void:
	_lollipop(_point(0.9, 0.145), edge * 0.078, -0.20, Color("#d899bb"), edge * 0.14)
	_lollipop(_point(0.095, 0.60), edge * 0.057, 0.10, Color("#9acbbb"), edge * 0.23)
	var candy := _point(0.12, 0.9)
	var radius: float = edge * 0.037
	for side in [-1, 1]:
		draw_colored_polygon(PackedVector2Array([candy + Vector2(side * radius * 0.6, 0), candy + Vector2(side * radius * 1.7, -radius * 0.8), candy + Vector2(side * radius * 1.6, radius * 0.85)]), Color("#e1b970"))
	_ellipse(candy, Vector2(radius, radius * 0.75), Color("#f9dc91"), -0.2)
	draw_line(candy + Vector2(-radius * 0.3, -radius * 0.45), candy + Vector2(radius * 0.28, radius * 0.4), Color("#fff2c8"), maxf(1.5, edge * 0.011), true)
	for sprinkle in [Vector3(0.68, 0.10, 0.5), Vector3(0.98, 0.43, -0.4), Vector3(0.05, 0.41, 0.4)]:
		var start := _point(sprinkle.x, sprinkle.y)
		draw_line(start, start + Vector2.from_angle(sprinkle.z) * edge * 0.025, Color("#c6a271"), maxf(1.5, edge * 0.011), true)


func _draw_theme_name(edge: float) -> void:
	var margin: float = clampf(edge * 0.05, 5, 13)
	var icon_size: float = clampf(edge * 0.11, 18, 28)
	var font_size: int = clampi(roundi(edge * 0.054), 12, 16)
	var font: Font = get_theme_default_font()
	var title: String = str(palette.get("name", theme_id.capitalize()))
	var title_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var show_name: bool = size.x >= 148 and size.y >= 118 and title_width + icon_size + 25 <= size.x * 0.60
	var badge_size := Vector2(icon_size + 12 + (title_width + 9 if show_name else 0.0), icon_size + 10)
	var badge := Rect2(Vector2.ONE * margin, badge_size)
	var accent: Color = palette.get("accent", Style.GOOD)
	draw_style_box(Style.box(Color(1, 1, 1, 0.86), Color(accent, 0.17), roundi(badge_size.y * 0.35), 1), badge)
	if _theme_icon != null:
		draw_texture_rect(_theme_icon, Rect2(badge.position + Vector2(6, 5), Vector2.ONE * icon_size), false)
	if show_name:
		var baseline: float = badge.position.y + (badge.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
		draw_string(font, Vector2(badge.position.x + icon_size + 13, baseline), title, HORIZONTAL_ALIGNMENT_LEFT, title_width + 1, font_size, Style.INK)


func _point(x: float, y: float) -> Vector2:
	return size * Vector2(x, y)


func _ground(level: float, bend: float, color: Color, ripple: float = 0.0) -> void:
	var outline := PackedVector2Array([Vector2(0, size.y)])
	for index in range(49):
		var t: float = float(index) / 48.0
		var y: float = level + bend * pow((t - 0.5) * 2.0, 2) + sin(t * TAU * 2.0) * ripple
		outline.append(_point(t, y))
	outline.append(size)
	draw_colored_polygon(outline, color)


func _wave(level: float, amplitude: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(65):
		var t: float = float(index) / 64.0
		points.append(_point(t, level - 0.025 * pow((t - 0.5) * 2.0, 2) + sin(t * TAU * 2.0) * amplitude))
	draw_polyline(points, color, width, true)


func _ellipse(center: Vector2, radii: Vector2, color: Color, angle: float = 0.0) -> void:
	var points := PackedVector2Array()
	for index in range(40):
		points.append(center + (Vector2.from_angle(float(index) * TAU / 40.0) * radii).rotated(angle))
	draw_colored_polygon(points, color)


func _ellipse_arc(center: Vector2, radii: Vector2, angle: float, start: float, end: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(41):
		points.append(center + (Vector2.from_angle(lerpf(start, end, float(index) / 40.0)) * radii).rotated(angle))
	draw_polyline(points, color, width, true)


func _leaf(base: Vector2, length: float, width: float, angle: float, color: Color) -> void:
	var outline := PackedVector2Array()
	for side in [-1, 1]:
		for index in (range(9) if side == -1 else range(1, 8)):
			var t: float = float(index if side == -1 else 8 - index) / 8.0
			outline.append(base + Vector2(sin(t * PI) * width * 0.5 * side, -t * length).rotated(angle))
	draw_colored_polygon(outline, color)
	draw_line(base, base + Vector2(0, -length * 0.91).rotated(angle), Color(color.darkened(0.23), 0.6), maxf(1, width * 0.065), true)


func _flower(center: Vector2, radius: float, color: Color) -> void:
	for index in range(5):
		var direction := Vector2.from_angle(float(index) * TAU / 5.0 - PI * 0.5)
		_ellipse(center + direction * radius * 0.53, Vector2(radius * 0.50, radius * 0.33), color, direction.angle())
	draw_circle(center, radius * 0.32, Color("#e7b963"))
	draw_circle(center + Vector2(-radius * 0.06, -radius * 0.08), radius * 0.12, Color("#ffedb3"))


func _snowflake(center: Vector2, radius: float, color: Color, width: float) -> void:
	for index in range(6):
		var direction := Vector2.from_angle(float(index) * TAU / 6.0)
		draw_line(center, center + direction * radius, color, width, true)
		for side in [-1, 1]:
			draw_line(center + direction * radius * 0.61, center + direction * radius * 0.61 + direction.rotated(side * 0.8) * radius * 0.29, color, width, true)


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(8):
		points.append(center + Vector2.from_angle(float(index) * TAU / 8.0) * radius * (1.0 if index % 2 == 0 else 0.3))
	draw_colored_polygon(points, color)


func _lollipop(center: Vector2, radius: float, angle: float, color: Color, stick_length: float) -> void:
	var stick_end := center + Vector2(0, radius + stick_length).rotated(angle)
	draw_line(center, stick_end, Color("#c7aba9"), maxf(2, radius * 0.18), true)
	draw_line(center, stick_end, Color("#fff3e8"), maxf(1, radius * 0.09), true)
	draw_circle(center, radius, color)
	draw_arc(center, radius, 0, TAU, 40, color.darkened(0.15), maxf(1, radius * 0.045), true)
	var spiral := PackedVector2Array()
	for index in range(49):
		var t: float = float(index) / 48.0
		spiral.append(center + Vector2.from_angle(t * TAU * 1.65 + angle) * radius * t * 0.83)
	draw_polyline(spiral, Color("#fff2d9"), maxf(1.5, radius * 0.16), true)

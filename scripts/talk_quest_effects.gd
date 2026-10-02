extends Control
## Bounded, lightweight word spells and celebratory particles for the quest stage.

signal attack_landed(cooperative: bool)
signal word_landed(uid: int)

var reduced_motion: bool = false
var _attacks: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []
var _prompt_glow: float = 0.0
var _prompt_rect := Rect2()
var _tint := Color("#a58ce8")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	# Transient paths use viewport pixels; discard them after a resize.
	resized.connect(clear)


func clear() -> void:
	_attacks.clear()
	_bursts.clear()
	_prompt_glow = 0.0
	queue_redraw()


func highlight_prompt(rect: Rect2, color: Color) -> void:
	_prompt_rect = rect
	_prompt_glow = 1.0
	_tint = color
	queue_redraw()


func launch_line(line: String, origin: Vector2, target: Vector2, cooperative: bool, scale_factor: float = 1.0) -> void:
	var words := line.split(" ", false)
	_attacks.append({"time": 0.0, "words": words, "origin": origin, "target": target,
		"cooperative": cooperative, "scale": scale_factor, "landed": false,
		"color": Color("#54c4b1") if cooperative else Color("#ad83ed")})
	queue_redraw()


func launch_word(uid: int, word: String, origin: Vector2, target: Vector2, scale_factor: float = 1.0) -> void:
	_attacks.append({"time": 0.0, "words": PackedStringArray([word]), "origin": origin, "target": target,
		"uid": uid, "cooperative": false, "scale": scale_factor, "landed": false, "bullet": true,
		"color": Color("#ffce78")})
	queue_redraw()


func celebrate(at: Vector2, cooperative: bool = false) -> void:
	_bursts.append({"time": 0.0, "position": at, "color": Color("#70dec2") if cooperative else Color("#ffd275"), "large": true})
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _attacks.is_empty() and _bursts.is_empty() and _prompt_glow <= 0.0:
		return
	_prompt_glow = maxf(0.0, _prompt_glow - delta * 2.0)
	for spell in _attacks:
		spell.time += delta
		var arrival: float = 0.10 if reduced_motion else 0.50
		if spell.time >= arrival and not spell.landed:
			spell.landed = true
			_bursts.append({"time": 0.0, "position": spell.target, "color": spell.color, "large": false})
			if spell.get("bullet", false):
				word_landed.emit(int(spell.uid))
			else:
				attack_landed.emit(bool(spell.cooperative))
	for burst in _bursts:
		burst.time += delta
	_attacks = _attacks.filter(func(spell: Dictionary) -> bool: return spell.time < 0.85)
	_bursts = _bursts.filter(func(burst: Dictionary) -> bool: return burst.time < (1.7 if burst.large else 0.7))
	queue_redraw()


func _star(at: Vector2, radius: float, color: Color, angle: float = 0.0) -> void:
	var points := PackedVector2Array()
	for point in range(8):
		var a: float = angle + PI * 0.25 * point
		points.append(at + Vector2(cos(a), sin(a)) * radius * (1.0 if point % 2 == 0 else 0.28))
	draw_colored_polygon(points, color)


func _draw() -> void:
	if _prompt_glow > 0.0:
		var outline := StyleBoxFlat.new()
		outline.bg_color = Color.TRANSPARENT
		outline.border_color = Color(_tint, _prompt_glow * 0.7)
		outline.set_border_width_all(3)
		outline.set_corner_radius_all(20)
		outline.shadow_color = Color(_tint, _prompt_glow * 0.16)
		outline.shadow_size = 8
		draw_style_box(outline, _prompt_rect.grow(-2))
	for spell in _attacks:
		_draw_spell(spell)
	for burst in _bursts:
		_draw_burst(burst)


func _draw_spell(spell: Dictionary) -> void:
	if reduced_motion:
		return
	if spell.get("bullet", false):
		_draw_word_bullet(spell)
		return
	var words: PackedStringArray = spell.words
	var s: float = spell.scale
	var font := ThemeDB.fallback_font
	var font_size: int = ceili(17.0 / s)
	for index in range(mini(words.size(), 24)):
		var t: float = clampf((float(spell.time) - index * 0.006) / 0.5, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var start: Vector2 = spell.origin + Vector2((index % 5 - 2) * 26, (index / 5) * 16) / s
		var end: Vector2 = spell.target
		var bend := Vector2(sin(float(index) * 2.4) * 72, -86) / s
		var at: Vector2 = start.lerp(end, t * t) + bend * sin(t * PI)
		var color: Color = spell.color
		color.a = (1.0 - smoothstep(0.78, 1.0, t)) * 0.9
		var previous: Vector2 = at.lerp(start, 0.11)
		draw_line(previous, at, Color(color, color.a * 0.25), 8 / s, true)
		draw_line(previous, at, Color("#ffefb6"), 2 / s, true)
		var text_size: Vector2 = font.get_string_size(words[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var chip := Rect2(at - text_size * 0.5 - Vector2(7, 4) / s, text_size + Vector2(14, 8) / s)
		var surface := StyleBoxFlat.new()
		surface.bg_color = Color("#fff9ef").lerp(color, 0.1)
		surface.bg_color.a = color.a
		surface.border_color = color
		surface.set_border_width_all(2)
		surface.set_corner_radius_all(9)
		draw_style_box(surface, chip)
		draw_string(font, Vector2(chip.position.x + 7 / s, chip.position.y + font.get_ascent(font_size) + 4 / s), words[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#67518e", color.a))


func _draw_word_bullet(spell: Dictionary) -> void:
	var t: float = clampf(float(spell.time) / 0.5, 0, 1)
	if t >= 1:
		return
	var s: float = spell.scale
	var travel: float = t * t
	var at: Vector2 = spell.origin.lerp(spell.target, travel)
	var direction: Vector2 = (spell.target - spell.origin).normalized()
	var length: float = (15 + 70 * t) / s
	draw_line(at - direction * length, at, Color("#f1b85733"), 22 / s, true)
	draw_line(at - direction * length * 0.8, at, Color("#ffd58099"), 10 / s, true)
	draw_line(at - direction * length * 0.55, at, Color("#fff9df"), 3 / s, true)
	draw_circle(at, (10 - 4 * t) / s, Color("#ffd379"))
	draw_circle(at, (5 - 2 * t) / s, Color.WHITE)
	var font := ThemeDB.fallback_font
	var font_size: int = ceili((19 - 5 * t) / s)
	var word: String = spell.words[0]
	var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, at + Vector2(-width * 0.5, -16 / s), word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(1, ceili(4 / s)), Color("#fffaf0"))
	draw_string(font, at + Vector2(-width * 0.5, -16 / s), word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#725234"))


func _draw_burst(burst: Dictionary) -> void:
	var duration: float = 1.7 if burst.large else 0.7
	var t: float = clampf(float(burst.time) / duration, 0.0, 1.0)
	var at: Vector2 = burst.position
	var color: Color = burst.color
	var count: int = 30 if burst.large else 16
	if reduced_motion:
		color.a = (1.0 - t) * 0.65
		_star(at, 16, color)
		return
	var radius: float = (150.0 if burst.large else 85.0) * (1.0 - pow(1.0 - t, 3))
	color.a = (1.0 - t) * 0.8
	if not burst.large:
		draw_arc(at, radius * 0.72, 0, TAU, 48, color, maxf(1.0, 5 * (1.0 - t)), true)
		draw_arc(at, radius * 0.45, 0, TAU, 40, Color("#fff2d3", color.a), 2, true)
	for index in range(count):
		var angle: float = index * 2.39996
		var travel: float = radius * (0.5 + float(index % 7) / 12.0)
		var point: Vector2 = at + Vector2(cos(angle), sin(angle)) * travel
		if burst.large:
			point.y += t * t * 95
		var particle: Color = [color, Color("#ffd57e", color.a), Color("#ffffff", color.a), Color("#89d9cf", color.a)][index % 4]
		_star(point, (5 + index % 4) * (1.0 - t * 0.6), particle, angle + t * 2)

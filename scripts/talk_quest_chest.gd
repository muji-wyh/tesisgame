extends Control
## Twenty original reward containers with shape-specific opening mechanisms.
## The reveal cue always occurs at 3.36 seconds; the settled pose occurs at 5.0.

signal hold_reached
signal reward_revealed
signal opening_finished
signal release_reached
signal opened

const OPEN_SECONDS: float = 5.0
const HOLD_SECONDS: float = 1.20
const RELEASE_SECONDS: float = 3.36
const DESIGN_SIZE := Vector2(420, 370)
const INK := Color("#425266")
const GOLD := Color("#e6bd68")
const CREAM := Color("#fff3d1")
const COLORS: Array = [
	["#8cbabc", "#e9b776"], ["#94cecb", "#dbb0cd"],
	["#cb9f6e", "#e6bf82"], ["#b3a1d0", "#eabdb2"],
	["#e3bd7f", "#cf9487"], ["#dfbe8e", "#8fb8ad"],
	["#b4bf8f", "#e1ad7b"], ["#9daacb", "#d8bb82"],
	["#91b898", "#d6bc79"], ["#7faec9", "#e5c67d"],
	["#e9b0b6", "#d3bfd9"], ["#a5b9af", "#dcb87c"],
	["#dda7b6", "#e6c486"], ["#9eb9c4", "#e4b879"],
	["#d99189", "#e6c5a0"], ["#c3cce5", "#edcb91"],
	["#d7be8d", "#9eacbd"], ["#baa2c4", "#ddb77e"],
	["#d8b574", "#b7c999"], ["#b6b5d5", "#e4af9a"]
]

var chest_index: int = 1
var chest_id: String = "chest-01"
var chest_name: String = "Welcome Mailbox"
var mode: String = "closed"
var reduced_motion: bool = false
var _elapsed: float = 0.0
var _idle_time: float = 0.0
var _open_amount: float = 0.0
var _hold_sent: bool = false
var _reveal_sent: bool = false
var _frame_time: float = 0.0
var _accent := Color("#e9b776")
var _body := Color("#8cbabc")
var _styles: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)


func configure(chest_data: Dictionary) -> void:
	var requested_id: String = str(chest_data.get("id", "chest-01"))
	chest_index = clampi(int(chest_data.get("index", requested_id.get_slice("-", 1).to_int())), 1, 20)
	chest_id = "chest-%02d" % chest_index
	chest_name = str(chest_data.get("name", chest_id))
	_body = Color(COLORS[chest_index - 1][0])
	_accent = Color(COLORS[chest_index - 1][1])
	if chest_data.get("accent") is Color:
		_accent = chest_data.accent
	elif chest_data.get("accent") is String and Color.html_is_valid(chest_data.accent):
		_accent = Color(chest_data.accent)
	reset_closed()


func play_open() -> void:
	if mode == "opening":
		return
	mode = "opening"
	_elapsed = 0.0
	_open_amount = 0.0
	_hold_sent = false
	_reveal_sent = false
	queue_redraw()


func reset_closed() -> void:
	mode = "closed"
	_elapsed = 0.0
	_open_amount = 0.0
	_hold_sent = false
	_reveal_sent = false
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_update_pose()
	queue_redraw()


func set_preview_time(seconds: float) -> void:
	# Deterministic art inspection without emitting gameplay events.
	mode = "preview"
	_elapsed = clampf(seconds, 0.0, OPEN_SECONDS)
	_update_pose()
	queue_redraw()


func get_animation_state() -> Dictionary:
	return {"id": chest_id, "index": chest_index, "mode": mode,
		"elapsed": _elapsed, "open_amount": _open_amount,
		"reward_revealed": _reveal_sent, "duration": OPEN_SECONDS}


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not reduced_motion:
		_idle_time += delta
	if mode == "opening":
		_elapsed = minf(OPEN_SECONDS, _elapsed + delta)
		_update_pose()
		queue_redraw()
		if _elapsed >= HOLD_SECONDS and not _hold_sent:
			_hold_sent = true
			hold_reached.emit()
		if _elapsed >= RELEASE_SECONDS and not _reveal_sent:
			_reveal_sent = true
			reward_revealed.emit()
			release_reached.emit()
		if _elapsed >= OPEN_SECONDS:
			mode = "open"
			opening_finished.emit()
			opened.emit()
	_frame_time += delta
	if _frame_time >= 1.0 / 30.0:
		_frame_time = 0.0
		if mode == "opening" or (not reduced_motion and mode != "preview"):
			queue_redraw()


func _update_pose() -> void:
	if reduced_motion:
		_open_amount = 1.0 if _elapsed >= RELEASE_SECONDS else 0.0
	else:
		_open_amount = smoothstep(HOLD_SECONDS + 0.15, RELEASE_SECONDS, _elapsed)


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var origin := (size - DESIGN_SIZE * factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	_ellipse(Vector2(210, 316), Vector2(112, 18), Color(0.20, 0.24, 0.32, 0.10))
	_ellipse(Vector2(210, 312), Vector2(86, 10), Color(0.20, 0.24, 0.32, 0.07))
	_glow()
	var bob: float = sin(_idle_time * 1.2) * 1.8 if not reduced_motion and mode == "closed" else 0.0
	var shake: float = 0.0
	if mode == "opening" and _elapsed < HOLD_SECONDS and not reduced_motion:
		shake = sin(_elapsed * 23.0) * smoothstep(0.0, HOLD_SECONDS, _elapsed) * 1.7
	draw_set_transform(origin + Vector2(shake, bob) * factor, 0.0, Vector2.ONE * factor)
	match chest_index:
		1: _mailbox()
		2: _capsule()
		3: _basket()
		4: _wardrobe()
		5: _sandcastle()
		6: _palette_case()
		7: _orchard_cart()
		8: _storybook()
		9: _turtle()
		10: _bus_trunk()
		11: _pearl_shell()
		12: _tent()
		13: _birthday_cake()
		14: _robot_toolbox()
		15: _mushroom()
		16: _cloud_pillow()
		17: _clockwork_egg()
		18: _concertina()
		19: _honeycomb()
		20: _patchwork()
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	if _elapsed >= RELEASE_SECONDS:
		_reward()
	if mode == "closed":
		_glint(Vector2(279, 150), 7.5, Color(CREAM, 0.6 + sin(_idle_time) * 0.18))
	draw_set_transform(Vector2.ZERO)


func _mailbox() -> void:
	_line(Vector2(174, 260), Vector2(174, 309), _body.darkened(0.2), 17)
	_line(Vector2(259, 260), Vector2(259, 309), _body.darkened(0.2), 17)
	_box(Rect2(106, 154, 198, 120), _body.darkened(0.07), 52)
	_box(Rect2(111, 157, 140, 107), _body, 43)
	_ellipse(Vector2(273, 213), Vector2(43, 58), _body.darkened(0.32))
	_ellipse(Vector2(272, 211), Vector2(33, 47), GOLD.lightened(0.2))
	var door: Array = [Vector2(297, 164), Vector2(247 + _open_amount * 100, 165 + _open_amount * 40), Vector2(247 + _open_amount * 100, 261 + _open_amount * 33), Vector2(297, 261)]
	_poly(door, _body.lightened(0.12))
	_line(Vector2(297, 168), Vector2(297, 260), _body.darkened(0.16), 5)
	_box(Rect2(259 + _open_amount * 58, 206 + _open_amount * 33, 16, 6), GOLD, 3)
	_box(Rect2(132, 181, 82, 7), _body.darkened(0.15), 3)
	_box(Rect2(146, 212, 55, 33), CREAM, 5)
	_poly([Vector2(148, 214), Vector2(173, 229), Vector2(199, 214)], _accent)
	_line(Vector2(118, 185), Vector2(118, 126), _accent.darkened(0.1), 6)
	_box(Rect2(118, 121, 39, 21), _accent, 5)
	if _open_amount > 0.2:
		for index in range(3):
			_star(Vector2(249 + index * 20 + _open_amount * 23, 187 - index * 29 * _open_amount), 8, CREAM, index * 0.3)


func _capsule() -> void:
	_ellipse(Vector2(210, 258), Vector2(94, 35), _accent.darkened(0.06))
	_ellipse(Vector2(210, 208), Vector2(75, 88), _body.darkened(0.16))
	_ellipse(Vector2(210, 205), Vector2(65, 74), Color("#f6e5b1"))
	var separation: float = _open_amount * 65.0
	_capsule_half(Vector2(210 - separation, 203 - separation * 0.35), -1.0, _body)
	_capsule_half(Vector2(210 + separation, 203 - separation * 0.35), 1.0, _body.lightened(0.15))
	_box(Rect2(193 - separation * 0.4, 189, 34, 30), _accent, 12)
	draw_circle(Vector2(210 - separation * 0.4, 204), 7, CREAM)
	for index in range(5):
		var amount: float = maxf(0.0, _open_amount - index * 0.08)
		if amount > 0.01:
			_bubble(Vector2(156 + index * 29 + sin(index * 2.0) * amount * 30, 194 - amount * (71 + index * 13)), 7 + index % 3 * 3, Color(_body.lightened(0.4), 0.8))


func _capsule_half(center: Vector2, side: float, tint: Color) -> void:
	var points: Array = [center + Vector2(0, -87)]
	for index in range(25):
		var angle: float = -PI * 0.5 + index * PI / 24.0
		points.append(center + Vector2(cos(angle) * 85 * side, sin(angle) * 87))
	points.append(center + Vector2(0, 87))
	_poly(points, tint)
	_line(center + Vector2(0, -81), center + Vector2(0, 81), tint.darkened(0.12), 4)
	_ellipse(center + Vector2(side * 39, -39), Vector2(13, 27), tint.lightened(0.15), side * 0.35)


func _basket() -> void:
	_arc(Vector2(210, 179), 68, PI, TAU, _body.darkened(0.12), 12)
	_arc(Vector2(210, 179), 63, PI, TAU, _accent, 6)
	_box(Rect2(106, 203, 208, 91), _body, 28)
	_ellipse(Vector2(210, 202), Vector2(104, 29), _body.darkened(0.27))
	_ellipse(Vector2(210, 201), Vector2(94, 21), GOLD.lightened(0.13))
	for index in range(9):
		var slat_amount: float = smoothstep(float(index) * 0.06, 0.6 + float(index) * 0.045, _open_amount)
		var width: float = 194 * (1.0 - slat_amount * 0.20)
		var y: float = 181 + index * 5 * (1.0 - slat_amount) - slat_amount * 15
		_box(Rect2(210 - width * 0.5, y, width, 6 * (1.0 - slat_amount * 0.90)), _accent.lightened((index % 2) * 0.07), 3)
	_ellipse(Vector2(210, 174 - _open_amount * 5), Vector2(94, 7 + _open_amount * 4), _body)
	for row in range(4):
		_line(Vector2(121, 219 + row * 18), Vector2(301, 219 + row * 18), _body.darkened(0.13), 3)
	for index in range(10):
		_line(Vector2(120 + index * 20, 212), Vector2(127 + index * 18, 283), _accent, 3)
	_box(Rect2(189, 233, 43, 30), CREAM, 9)
	_star(Vector2(211, 248), 9, _body)
	_box(Rect2(104, 204, 212, 12), _accent, 6)


func _wardrobe() -> void:
	_box(Rect2(122, 125, 176, 176), _body.darkened(0.19), 29)
	_box(Rect2(137, 142, 146, 143), CREAM.darkened(0.13), 15)
	_line(Vector2(150, 165), Vector2(272, 165), _accent.darkened(0.2), 5)
	_line(Vector2(171, 167), Vector2(171, 203), _accent, 3)
	_line(Vector2(247, 167), Vector2(247, 203), _accent, 3)
	var width: float = 76 * (1.0 - _open_amount * 0.76)
	_box(Rect2(130 - _open_amount * 12, 134, width, 158), _body.lightened(0.1), 19)
	_box(Rect2(290 + _open_amount * 12 - width, 134, width, 158), _body, 19)
	for side in [-1.0, 1.0]:
		var knob := Vector2(210 + side * (13 + _open_amount * 80), 220)
		draw_circle(knob, 8, _accent)
		for hole in [Vector2(-2, -2), Vector2(2, 2)]:
			draw_circle(knob + hole, 1.4, CREAM)
		_box(Rect2(143 + (side + 1) * 56, 296, 17, 17), _body.darkened(0.2), 5)
	_ribbon(Vector2(211, 136), _accent, 1.0, _open_amount)
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for index in range(12):
			var t: float = float(index) / 11.0
			points.append(Vector2(210 + side * (17 + _open_amount * t * 87), 144 + t * 67 + sin(t * 6.0 + _open_amount * 2.0) * _open_amount * 15))
		draw_polyline(points, _accent, 8, true)


func _sandcastle() -> void:
	_box(Rect2(133, 217, 154, 85), _body.darkened(0.03), 8)
	for side in [-1.0, 1.0]:
		var x: float = 210 + side * 85
		_box(Rect2(x - 30, 169, 60, 132), _body, 12)
		_ellipse(Vector2(x, 170), Vector2(31, 11), _body.lightened(0.08))
		for index in range(3):
			_box(Rect2(x - 32 + index * 23, 145, 19, 35), _body, 4)
		_box(Rect2(x - 9, 194, 18, 28), _body.darkened(0.19), 9)
	for index in range(5):
		_box(Rect2(147 + index * 26, 198, 17, 28), _body.lightened(0.07), 3)
	_box(Rect2(178, 230, 63, 73), _body.darkened(0.27), 29)
	var bridge: Array = [Vector2(181, 301), Vector2(239, 301), Vector2(239 + _open_amount * 23, 233 + _open_amount * 91), Vector2(181 - _open_amount * 23, 233 + _open_amount * 91)]
	_poly(bridge, _accent)
	for side in [-1.0, 1.0]:
		_line(Vector2(210 + side * 31, 245), Vector2(210 + side * (29 + _open_amount * 23), 240 + _open_amount * 79), GOLD.darkened(0.17), 2)
	_line(Vector2(210, 203), Vector2(210, 119 - _open_amount * 23), _body.darkened(0.17), 4)
	_poly([Vector2(213, 121 - _open_amount * 23), Vector2(252, 135 - _open_amount * 23), Vector2(213, 148 - _open_amount * 23)], _accent)
	for index in range(10):
		draw_circle(Vector2(104 + index * 24, 312 + (index % 3) * 4), 1.8, _body.darkened(0.1))


func _palette_case() -> void:
	_ellipse(Vector2(210, 258), Vector2(107, 39), _body.darkened(0.12), -0.12)
	_ellipse(Vector2(209, 229), Vector2(107, 64), _body.darkened(0.25), -0.12)
	_ellipse(Vector2(209, 225), Vector2(96, 53), CREAM, -0.12)
	var pivot := Vector2(120, 248)
	var angle: float = -_open_amount * 1.04
	var center := _rotate(Vector2(207, 213), pivot, angle)
	_ellipse(center, Vector2(107, 66), _body, -0.12 + angle)
	var colors: Array = [Color("#cf8f87"), Color("#e7bc65"), Color("#9eb994"), Color("#8fb2c9"), Color("#b69ac2")]
	for index in range(5):
		var point := Vector2(158 + index * 33, 187 + sin(index * 0.82) * -18)
		draw_circle(_rotate(point, pivot, angle), 12, colors[index])
	_ellipse(_rotate(Vector2(258, 237), pivot, angle), Vector2(18, 13), _body.darkened(0.24), angle)
	var brush_base := _rotate(Vector2(141, 244), pivot, angle)
	var brush_tip := _rotate(Vector2(236, 204), pivot, angle)
	_line(brush_base, brush_tip, _accent, 10)
	_line(brush_tip, _rotate(Vector2(258, 195), pivot, angle), Color("#c3a78c"), 13)
	_ellipse(_rotate(Vector2(268, 191), pivot, angle), Vector2(15, 8), Color("#8e8691"), -0.40 + angle)
	draw_circle(pivot, 8, GOLD)


func _orchard_cart() -> void:
	for x in [140.0, 282.0]:
		draw_circle(Vector2(x, 297), 25, _body.darkened(0.26))
		draw_circle(Vector2(x, 297), 14, CREAM)
		draw_circle(Vector2(x, 297), 5, _accent)
	_box(Rect2(104, 218, 216, 72), _accent.darkened(0.08), 12)
	_box(Rect2(112, 226, 200, 55), GOLD.lightened(0.1), 9)
	for index in range(5):
		var retraction: float = smoothstep(index * 0.10, 0.6 + index * 0.1, _open_amount)
		_box(Rect2(108 + index * 42, 220 + retraction * 55, 37, 65 * (1.0 - retraction * 0.80)), _accent.lightened((index % 2) * 0.05), 5)
		_line(Vector2(113 + index * 42, 235 + retraction * 46), Vector2(139 + index * 42, 235 + retraction * 46), _accent.darkened(0.15), 2)
	for x in [118.0, 304.0]:
		_line(Vector2(x, 225), Vector2(x, 142), _accent.darkened(0.13), 8)
	_box(Rect2(96, 118, 226, 40), _body, 18)
	for index in range(6):
		_box(Rect2(98 + index * 37, 123, 36, 44), CREAM if index % 2 else _body.lightened(0.08), 13)
	for index in range(5):
		var point := Vector2(143 + index * 35, 222 - (index % 2) * 12 - _open_amount * 21)
		draw_circle(point, 16, Color("#d99a79") if index % 2 else Color("#b1c591"))
		_line(point + Vector2(0, -13), point + Vector2(2, -21), _body.darkened(0.2), 3)
	_line(Vector2(319, 239), Vector2(350, 222), _accent.darkened(0.13), 8)


func _storybook() -> void:
	_box(Rect2(104, 222, 220, 73), _body.darkened(0.15), 16)
	_box(Rect2(115, 216, 199, 66), CREAM, 11)
	for index in range(5):
		_line(Vector2(135, 228 + index * 10), Vector2(305, 228 + index * 10), Color("#decda8"), 1.5)
	_box(Rect2(99, 285, 232, 15), _body, 6)
	var angle: float = -_open_amount * 1.17
	var pivot := Vector2(114, 225)
	var points: Array = []
	for point in [Vector2(112, 219), Vector2(306, 185), Vector2(330, 220), Vector2(133, 257)]:
		points.append(_rotate(point, pivot, angle))
	_poly(points, _body)
	_line(_rotate(Vector2(131, 223), pivot, angle), _rotate(Vector2(307, 197), pivot, angle), GOLD, 4)
	_line(_rotate(Vector2(145, 245), pivot, angle), _rotate(Vector2(313, 221), pivot, angle), GOLD, 3)
	_star(_rotate(Vector2(220, 220), pivot, angle), 22, _accent, angle)
	_box(Rect2(100, 226, 29, 63), _body.lightened(0.08), 8)
	for index in range(3):
		_line(Vector2(105, 237 + index * 19), Vector2(125, 237 + index * 19), GOLD, 4)
	if _open_amount > 0.4:
		for index in range(2):
			var point := Vector2(250 + index * 48, 210 - (_open_amount - 0.4) * (145 + index * 35))
			_poly([point + Vector2(-20, -9), point, point + Vector2(-5, 4)], CREAM)
			_poly([point, point + Vector2(17, -14), point + Vector2(9, 6)], CREAM)


func _turtle() -> void:
	for point in [Vector2(140, 276), Vector2(269, 282), Vector2(139, 229), Vector2(264, 229)]:
		_ellipse(point, Vector2(23, 15), _body.lightened(0.08), 0.2)
	_ellipse(Vector2(207, 254), Vector2(97, 49), _body.darkened(0.12))
	_ellipse(Vector2(304, 253), Vector2(33, 26), _body.lightened(0.13))
	draw_circle(Vector2(317, 245), 4, INK)
	draw_circle(Vector2(318, 244), 1.2, CREAM)
	_arc(Vector2(316, 254), 10, 0.3, 1.8, _body.darkened(0.14), 2)
	_ellipse(Vector2(206, 228), Vector2(87, 57), _body.darkened(0.3))
	_ellipse(Vector2(205, 225), Vector2(72, 45), GOLD.lightened(0.1))
	for index in range(5):
		var amount: float = smoothstep(index * 0.08, 0.6 + index * 0.08, _open_amount)
		var point := Vector2(142 + index * 32, 222 - sin(float(index) / 4.0 * PI) * 25 - amount * (50 + index % 2 * 14))
		_hexagon(point, Vector2(28, 36), _body.lightened((index % 2) * 0.06), -0.12 + index * 0.05)
		_hexagon(point, Vector2(19, 24), _accent, -0.12 + index * 0.05)
	_poly([Vector2(115, 251), Vector2(89, 259), Vector2(117, 268)], _body)


func _bus_trunk() -> void:
	_box(Rect2(94, 183, 237, 111), _body.darkened(0.08), 29)
	_box(Rect2(99, 190, 224, 84), _body, 21)
	for index in range(3):
		_box(Rect2(115 + index * 58, 201, 45, 40), Color("#d7edeb"), 10)
		_box(Rect2(120 + index * 58, 205, 14, 30), Color(1, 1, 1, 0.25), 5)
	_box(Rect2(289, 204, 24, 65), _body.darkened(0.18), 9)
	_box(Rect2(103, 249, 221, 14), _accent, 5)
	for x in [149.0, 277.0]:
		draw_circle(Vector2(x, 293), 24, INK)
		draw_circle(Vector2(x, 293), 13, CREAM)
		draw_circle(Vector2(x, 293), 5, _accent)
	_ellipse(Vector2(210, 184), Vector2(99, 21), _body.darkened(0.3))
	_box(Rect2(100 - _open_amount * 39, 163 - _open_amount * 25, 227 - _open_amount * 67, 35), _body.lightened(0.13), 18)
	_box(Rect2(160 - _open_amount * 31, 159 - _open_amount * 25, 104, 9), _accent, 4)
	_box(Rect2(296, 275 + _open_amount * 17, 18 + _open_amount * 31, 11), _accent, 4)
	_box(Rect2(318, 221, 15, 21), CREAM, 6)
	_arc(Vector2(199 - _open_amount * 26, 155 - _open_amount * 25), 25, PI, TAU, _body.darkened(0.12), 8)


func _pearl_shell() -> void:
	var bottom: Array = [Vector2(111, 245)]
	for index in range(25):
		var angle: float = float(index) / 24.0 * PI
		bottom.append(Vector2(210 + cos(angle) * 101, 247 + sin(angle) * 59))
	_poly(bottom, _body.darkened(0.05))
	_ellipse(Vector2(210, 244), Vector2(103, 28), _body.darkened(0.17))
	_ellipse(Vector2(210, 241), Vector2(91, 20), _accent.lightened(0.12))
	var lid: Array = [Vector2(210, 243)]
	var height: float = 66 + _open_amount * 89
	for index in range(29):
		var angle: float = PI + float(index) / 28.0 * PI
		var ridge: float = 1.0 + 0.055 * cos(index * PI)
		lid.append(Vector2(210 + cos(angle) * 102 * ridge, 231 + sin(angle) * height * ridge))
	_poly(lid, _body.lightened(0.15))
	for index in range(1, 7):
		var angle: float = PI + index * PI / 7.0
		_line(Vector2(210, 237), Vector2(210 + cos(angle) * 92, 231 + sin(angle) * height * 0.90), _body.darkened(0.04), 3)
	if _open_amount > 0.02:
		var pearl_y: float = 244 - _open_amount * 31
		draw_circle(Vector2(210, pearl_y), 25 * _open_amount, Color("#fff7e0"))
		draw_circle(Vector2(202, pearl_y - 9), 7 * _open_amount, Color.WHITE)
	for index in range(6):
		_line(Vector2(145 + index * 25, 266), Vector2(160 + index * 20, 290), _body.lightened(0.13), 2)


func _tent() -> void:
	_poly([Vector2(89, 292), Vector2(206, 121), Vector2(316, 292)], _body.darkened(0.13))
	_poly([Vector2(206, 121), Vector2(285, 159), Vector2(341, 287), Vector2(316, 292)], _body.darkened(0.22))
	_poly([Vector2(110, 285), Vector2(207, 148), Vector2(294, 285)], GOLD.lightened(0.2))
	var left: Array = [Vector2(99, 289), Vector2(206, 130), Vector2(207 - _open_amount * 72, 284)]
	var right: Array = [Vector2(206, 130), Vector2(311, 289), Vector2(208 + _open_amount * 72, 284)]
	_poly(left, _body.lightened(0.12))
	_poly(right, _body)
	_line(Vector2(206, 133), Vector2(207 - _open_amount * 72, 284), _accent, 5)
	_line(Vector2(206, 133), Vector2(208 + _open_amount * 72, 284), _accent, 5)
	_star(Vector2(207, 274 - smoothstep(0.0, 0.55, _open_amount) * 112), 13, CREAM)
	for side in [-1.0, 1.0]:
		_line(Vector2(210 + side * 104, 287), Vector2(210 + side * 139, 303), CREAM.darkened(0.12), 3)
		_line(Vector2(210 + side * 139, 298), Vector2(210 + side * 142, 311), _accent.darkened(0.18), 5)
	_box(Rect2(87, 288, 251, 12), _accent, 5)
	_star(Vector2(264, 209), 9, Color(CREAM, 0.7))


func _birthday_cake() -> void:
	_ellipse(Vector2(210, 299), Vector2(116, 17), CREAM)
	for tier in range(3):
		var local_open: float = smoothstep(tier * 0.08, 0.78 + tier * 0.08, _open_amount)
		var width: float = 204 - tier * 49
		var y: float = 293 - tier * 54 - (tier * 24) * local_open
		var shift: float = sin(local_open * PI * 0.72) * tier * 15
		var tint: Color = _body.lightened(tier * 0.12)
		_box(Rect2(210 - width * 0.5 + shift, y - 52, width, 54), tint, 12)
		_ellipse(Vector2(210 + shift, y - 49), Vector2(width * 0.5, 15), CREAM)
		for dot in range(5):
			var x: float = 210 - width * 0.38 + dot * width * 0.19 + shift
			draw_circle(Vector2(x, y - 18), 4, _accent)
		if tier > 0:
			_line(Vector2(210 - width * 0.32 + shift, y - 48), Vector2(210 + width * 0.30 + shift, y - 48), _accent, 3)
	var top := Vector2(210 + sin(_open_amount * PI * 0.72) * 30, 128 - _open_amount * 48)
	for index in range(3):
		_line(top + Vector2(-24 + index * 24, 6), top + Vector2(-24 + index * 24, 27), Color("#9abdaf"), 6)
		_ellipse(top + Vector2(-24 + index * 24, -1), Vector2(4, 7), GOLD)
	_ribbon(Vector2(210, 260), _accent, 0.67, 0.0)


func _robot_toolbox() -> void:
	_box(Rect2(121, 229, 177, 69), _body, 16)
	_box(Rect2(139, 256, 142, 29), _body.darkened(0.09), 8)
	for x in [160.0, 260.0]:
		_box(Rect2(x - 14, 293, 28, 17), _body.darkened(0.21), 5)
	_box(Rect2(128, 213 - _open_amount * 105, 164, 55), _body.lightened(0.14), 18)
	_arc(Vector2(210, 211 - _open_amount * 105), 27, PI, TAU, _accent, 10)
	for x in [179.0, 241.0]:
		draw_circle(Vector2(x, 236 - _open_amount * 105), 10, INK)
		draw_circle(Vector2(x - 3, 233 - _open_amount * 105), 3, CREAM)
	_arc(Vector2(210, 244 - _open_amount * 105), 12, 0.1, PI - 0.1, _body.darkened(0.2), 3)
	for side in [-1.0, 1.0]:
		for tier in range(2):
			var amount: float = smoothstep(tier * 0.16, 0.75 + tier * 0.16, _open_amount)
			var point := Vector2(210 + side * (37 + amount * (63 + tier * 17)), 233 - amount * (23 + tier * 32))
			_line(Vector2(210 + side * 52, 263), point + Vector2(side * 15, 9), _accent.darkened(0.08), 5)
			_box(Rect2(point - Vector2(39, 11), Vector2(78, 27)), _body.lightened(0.08 + tier * 0.07), 7)
			_box(Rect2(point - Vector2(32, 9), Vector2(64, 9)), _body.darkened(0.20), 4)
			if amount > 0.25:
				_gear(point + Vector2(0, -12), 11, _accent, amount * side)
	_star(Vector2(210, 271), 13, _accent)


func _mushroom() -> void:
	_box(Rect2(140, 210, 142, 91), _accent, 29)
	_box(Rect2(184, 240, 48, 62), _accent.darkened(0.24), 23)
	_box(Rect2(190, 246, 36, 56), Color("#c39b83"), 17)
	draw_circle(Vector2(218, 276), 3, GOLD)
	for x in [163.0, 257.0]:
		draw_circle(Vector2(x, 236), 14, CREAM)
		_line(Vector2(x - 11, 236), Vector2(x + 11, 236), _accent.darkened(0.16), 3)
		_line(Vector2(x, 224), Vector2(x, 248), _accent.darkened(0.16), 3)
	var shift: float = sin(_open_amount * PI * 0.65) * 14
	var cap_y: float = 209 - _open_amount * 90
	var cap: Array = [Vector2(93 + shift, cap_y), Vector2(326 + shift, cap_y)]
	for index in range(25):
		var angle: float = float(index) / 24.0 * PI
		cap.append(Vector2(210 + shift + cos(angle) * 116, cap_y - sin(angle) * 81))
	_poly(cap, _body)
	_ellipse(Vector2(210 + shift, cap_y), Vector2(118, 17), _body.darkened(0.09))
	_ellipse(Vector2(210 + shift, cap_y - 5), Vector2(114, 11), _body.lightened(0.1))
	for spot in [Vector3(-55, -38, 15), Vector3(-14, -61, 13), Vector3(39, -47, 19), Vector3(72, -19, 9)]:
		_ellipse(Vector2(210 + shift + spot.x + sin(_open_amount * 2.0) * 8, cap_y + spot.y), Vector2(spot.z, spot.z * 0.68), CREAM, _open_amount * 0.35)
	for x in [127.0, 292.0]:
		_leaf(Vector2(x, 299), 21, Color("#a7bd97"), -0.6 if x < 210 else 0.6)


func _cloud_pillow() -> void:
	_cloud(Vector2(210, 252), 1.16, _body.darkened(0.08))
	_cloud(Vector2(210, 227), 1.13, _body)
	for index in range(10):
		var angle: float = PI * 0.1 + index * PI * 0.8 / 9.0
		var point := Vector2(210 + cos(angle) * 107, 230 + sin(angle) * 32)
		_line(point, point + Vector2(1, 5), _body.darkened(0.15), 2)
	var flap := Vector2(226 - _open_amount * 31, 202 - _open_amount * 72)
	var crescent: Array = []
	for index in range(25):
		var angle: float = index * PI / 24.0
		crescent.append(flap + Vector2(-sin(angle) * 50, -cos(angle) * 50).rotated(0.28 + _open_amount * 0.35))
	for index in range(25):
		var angle: float = index * PI / 24.0
		crescent.append(flap + Vector2(-sin(angle) * 21, cos(angle) * 50).rotated(0.28 + _open_amount * 0.35))
	_poly(crescent, _accent)
	_star(Vector2(277, 215 - _open_amount * 10), 13, CREAM, _open_amount * 0.5)
	if _open_amount > 0.1:
		for index in range(4):
			_arc(Vector2(210, 235), 32 + index * 10, PI, TAU, Color(["#dba8af", "#e9c993", "#b3c99e", "#aabbd7"][index], _open_amount * 0.65), 8)


func _clockwork_egg() -> void:
	_ellipse(Vector2(210, 287), Vector2(66, 21), _accent)
	_box(Rect2(182, 278, 56, 25), _accent.darkened(0.09), 10)
	var separation: float = _open_amount * 56
	for side in [-1.0, 1.0]:
		var points: Array = [Vector2(210 + side * separation, 280)]
		for index in range(25):
			var angle: float = PI * 0.5 + float(index) / 24.0 * PI
			var y: float = sin(angle)
			points.append(Vector2(210 + side * separation - side * cos(angle) * (64 + y * 11), 199 + y * 87 - _open_amount * 13))
		points.append(Vector2(210 + side * separation, 112 - _open_amount * 13))
		_poly(points, _body.lightened(0.07 if side > 0 else 0.0))
		_line(Vector2(210 + side * separation, 122 - _open_amount * 13), Vector2(210 + side * separation, 276 - _open_amount * 13), _accent, 4)
		_gear(Vector2(210 + side * (38 + separation), 213 - _open_amount * 13), 18, _accent, side * _open_amount)
	var key := Vector2(301 + separation * 0.25, 203)
	_line(Vector2(271 + separation * 0.5, 206), key, _accent, 9)
	var angle: float = smoothstep(0.0, 0.5, _open_amount) * TAU
	for side in [-1.0, 1.0]:
		var handle := key + Vector2(0, side * 15).rotated(angle)
		_ellipse(handle, Vector2(12, 14), _accent, angle)
		_ellipse(handle, Vector2(5, 7), CREAM, angle)
	_star(Vector2(210, 159 - _open_amount * 5), 13, CREAM)


func _concertina() -> void:
	var width: float = 91 + _open_amount * 94
	var left: float = 210 - width * 0.5
	_box(Rect2(left - 41, 184, 42, 116), _body, 13)
	_box(Rect2(left + width, 184, 42, 116), _body, 13)
	for index in range(10):
		var x: float = left + index * width / 10.0
		_poly([Vector2(x, 195), Vector2(x + width / 20.0, 185), Vector2(x + width / 10.0, 195), Vector2(x + width / 10.0, 288), Vector2(x + width / 20.0, 299), Vector2(x, 288)], _body.darkened(0.12 if index % 2 else 0.04))
		_line(Vector2(x + width / 20.0, 192), Vector2(x + width / 20.0, 291), _accent, 2)
	for row in range(4):
		for column in range(2):
			draw_circle(Vector2(left - 26 + column * 13, 213 + row * 20), 3.7, CREAM)
	for index in range(7):
		_box(Rect2(left + width + 9, 197 + index * 13, 23, 11), CREAM, 2)
		if index % 3 != 0:
			_box(Rect2(left + width + 8, 204 + index * 13, 12, 5), INK, 1)
	_box(Rect2(176, 183 - _open_amount * 58, 68, 15), _accent, 7)
	_arc(Vector2(210, 180 - _open_amount * 58), 17, PI, TAU, _accent, 6)
	for index in range(3):
		if _open_amount > 0.2 + index * 0.1:
			_note(Vector2(159 + index * 53, 160 - _open_amount * (17 + index * 13)), _accent, 0.8 + index * 0.15)


func _honeycomb() -> void:
	var centers: Array = [Vector2(165, 177), Vector2(245, 177), Vector2(126, 246), Vector2(205, 246), Vector2(284, 246), Vector2(165, 314), Vector2(245, 314)]
	for index in range(centers.size()):
		var point: Vector2 = centers[index] + Vector2(5, -16)
		_hexagon(point, Vector2(46, 45), _body.darkened(0.22))
		_hexagon(point, Vector2(37, 37), _body.darkened(0.1))
	for index in range(centers.size()):
		var point: Vector2 = centers[index] + Vector2(5, -16)
		var amount: float = smoothstep(index * 0.065, 0.59 + index * 0.065, _open_amount)
		var shift := Vector2(-13 if index % 2 == 0 else 13, 15) * amount
		if amount > 0.01:
			_poly([point + Vector2(-38, -18), point + Vector2(-38, 18), point + shift + Vector2(-38, 18), point + shift + Vector2(-38, -18)], _body.darkened(0.15))
			_poly([point + Vector2(38, -18), point + Vector2(38, 18), point + shift + Vector2(38, 18), point + shift + Vector2(38, -18)], _body.darkened(0.12))
		_hexagon(point + shift, Vector2(38, 37), _body.lightened((index % 3) * 0.025))
		_hexagon(point + shift, Vector2(29, 28), _body.lightened(0.12))
		draw_circle(point + shift, 6, _accent.darkened(0.03))
	_ellipse(Vector2(305, 138), Vector2(18, 13), _body, 0.25)
	for x in [299.0, 309.0]:
		_line(Vector2(x, 128), Vector2(x, 147), _body.darkened(0.23), 4)
	_ellipse(Vector2(299, 121), Vector2(10, 7), Color(CREAM, 0.85), -0.4)
	_ellipse(Vector2(315, 121), Vector2(10, 7), Color(CREAM, 0.85), 0.4)


func _patchwork() -> void:
	var p: float = _open_amount
	_box(Rect2(139, 211, 143, 89), _body.darkened(0.20), 12)
	_box(Rect2(151, 219, 120, 63), GOLD.lightened(0.1), 7)
	var panels: Array = [
		[Vector2(139, 214), Vector2(139, 298), Vector2(139 - p * 61, 296 - p * 4), Vector2(139 - p * 61, 214 + p * 78)],
		[Vector2(282, 214), Vector2(282, 298), Vector2(282 + p * 61, 296 - p * 4), Vector2(282 + p * 61, 214 + p * 78)],
		[Vector2(139, 211), Vector2(282, 211), Vector2(282 + p * 21, 211 - p * 74), Vector2(139 - p * 21, 211 - p * 74)],
		[Vector2(139, 298), Vector2(282, 298), Vector2(282 + p * 28, 214 + p * 118), Vector2(139 - p * 28, 214 + p * 118)]
	]
	for index in [2, 0, 1, 3]:
		_poly(panels[index], _body.lightened(index * 0.035))
		var corners: Array = panels[index]
		for edge in range(4):
			var a: Vector2 = corners[edge]
			var b: Vector2 = corners[(edge + 1) % 4]
			for stitch in range(7):
				_line(a.lerp(b, float(stitch) / 7.0 + 0.02), a.lerp(b, float(stitch) / 7.0 + 0.08), CREAM, 1.7)
	if p < 0.9:
		for row in range(2):
			for column in range(3):
				_box(Rect2(151 + column * 42, 223 + row * 33 + p * 99, 34, 25 * (1.0 - p * 0.75)), [_accent, _body.lightened(0.23), Color("#abc0aa")][(row + column) % 3], 5)
	var ribbon_y: float = 206 - p * 56
	_ribbon(Vector2(210, ribbon_y), _accent, 1.15, p)
	for side in [-1.0, 1.0]:
		_line(Vector2(210 + side * 8, ribbon_y), Vector2(210 + side * (12 + p * 106), 287 - p * 7), _accent, 11 * (1.0 - p * 0.4))


func _glow() -> void:
	var charge: float = smoothstep(0.15, RELEASE_SECONDS, _elapsed)
	if charge <= 0.001:
		return
	for ring in range(7):
		var radius: float = 40 + ring * 15
		draw_circle(Vector2(210, 222), radius, Color(CREAM, charge * 0.035))
	if not reduced_motion:
		for index in range(10):
			var angle: float = index * TAU / 10.0 + _elapsed * 0.045
			var direction := Vector2.from_angle(angle)
			var tangent := direction.orthogonal()
			_poly([Vector2(210, 223) + direction * 29, Vector2(210, 223) + direction * 151 + tangent * 9, Vector2(210, 223) + direction * 151 - tangent * 9], Color(GOLD, charge * 0.065))


func _reward() -> void:
	var t: float = clampf((_elapsed - RELEASE_SECONDS) / (OPEN_SECONDS - RELEASE_SECONDS), 0.0, 1.0)
	var rise: float = 1.0 - pow(1.0 - t, 3.0)
	if reduced_motion:
		rise = 1.0
	var center := Vector2(210, 206 - rise * (16.0 if chest_index == 14 else 73.0))
	if chest_index == 14:
		# A friendly companion silhouette foreshadows the collected robot reward.
		_box(Rect2(center + Vector2(-20, -22), Vector2(40, 30)), _body.lightened(0.24), 10)
		_box(Rect2(center + Vector2(-14, 9), Vector2(28, 20)), _accent, 7)
		for side in [-1.0, 1.0]:
			draw_circle(center + Vector2(side * 8, -9), 3, INK)
			_line(center + Vector2(side * 18, 12), center + Vector2(side * 27, 7), _body, 5)
		_line(center + Vector2(0, -24), center + Vector2(0, -32), _body, 3)
		draw_circle(center + Vector2(0, -35), 4, GOLD)
	else:
		draw_circle(center, 28, Color(CREAM, 0.72))
		_star(center, 22, GOLD, 0.05)
		_star(center + Vector2(-2, -3), 14, CREAM, 0.05)
	for index in range(14):
		var angle: float = -PI + float(index) * TAU / 14.0
		var radius: float = (45 + (index % 3) * 22) * rise
		var point := center + Vector2.from_angle(angle) * radius
		if not reduced_motion:
			point.y += t * t * 23
		var tint: Color = [GOLD, _accent, _body.lightened(0.25), CREAM][index % 4]
		if chest_index == 2:
			_bubble(point, 3 + index % 4, Color(tint, 0.70))
		elif chest_index == 18:
			_note(point, tint, 0.45)
		elif chest_index == 14 or chest_index == 17:
			_gear(point, 4 + index % 3, tint, angle)
		elif chest_index == 13 or chest_index == 20:
			_line(point, point + Vector2.from_angle(angle + 0.7) * 8, tint, 3)
		else:
			_star(point, 3 + index % 3, tint, angle)


func _ribbon(center: Vector2, tint: Color, scale_value: float, untie: float) -> void:
	for side in [-1.0, 1.0]:
		var point := center + Vector2(side * (19 + untie * 38), -6 - untie * 6) * scale_value
		_ellipse(point, Vector2(22, 11 * (1.0 - untie * 0.65)) * scale_value, tint, side * (0.35 - untie * 0.6))
		_ellipse(point, Vector2(12, 5 * (1.0 - untie * 0.65)) * scale_value, tint.darkened(0.12), side * (0.35 - untie * 0.6))
	if untie < 0.85:
		draw_circle(center, 9 * scale_value * (1.0 - untie * 0.5), tint.lightened(0.1))


func _cloud(center: Vector2, scale_value: float, tint: Color) -> void:
	for piece in [Vector3(-70, 6, 29), Vector3(-41, -16, 39), Vector3(0, -26, 43), Vector3(41, -14, 37), Vector3(69, 7, 28)]:
		draw_circle(center + Vector2(piece.x, piece.y) * scale_value, piece.z * scale_value, tint)
	_box(Rect2(center + Vector2(-74, 0) * scale_value, Vector2(150, 35) * scale_value), tint, 15)


func _leaf(center: Vector2, radius: float, tint: Color, angle: float) -> void:
	_ellipse(center, Vector2(radius * 0.43, radius), tint, angle)
	_line(center, center + Vector2(0, -radius * 0.7).rotated(angle), tint.darkened(0.15), 2)


func _hexagon(center: Vector2, radii: Vector2, tint: Color, angle: float = 0.0) -> void:
	var points: Array = []
	for index in range(6):
		var a: float = -PI * 0.5 + index * TAU / 6.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(angle))
	_poly(points, tint)


func _gear(center: Vector2, radius: float, tint: Color, angle: float = 0.0) -> void:
	var points: Array = []
	for index in range(32):
		var radius_value: float = radius if index % 4 <= 1 else radius * 0.75
		points.append(center + Vector2.from_angle(angle + index * TAU / 32.0) * radius_value)
	_poly(points, tint)
	draw_circle(center, radius * 0.28, CREAM)


func _note(center: Vector2, tint: Color, scale_value: float = 1.0) -> void:
	_ellipse(center, Vector2(8, 5) * scale_value, tint, -0.3)
	_line(center + Vector2(6, 0) * scale_value, center + Vector2(6, -23) * scale_value, tint, 3 * scale_value)
	_line(center + Vector2(6, -23) * scale_value, center + Vector2(17, -18) * scale_value, tint, 4 * scale_value)


func _bubble(center: Vector2, radius: float, tint: Color) -> void:
	draw_circle(center, radius, Color(tint, tint.a * 0.16))
	_arc(center, radius, 0, TAU, tint, 1.5)
	_arc(center, radius * 0.67, PI, PI * 1.6, CREAM, 1.5)


func _glint(center: Vector2, radius: float, tint: Color) -> void:
	_poly([center + Vector2(0, -radius), center + Vector2(radius * 0.21, -radius * 0.21), center + Vector2(radius, 0), center + Vector2(radius * 0.21, radius * 0.21), center + Vector2(0, radius), center + Vector2(-radius * 0.21, radius * 0.21), center + Vector2(-radius, 0), center + Vector2(-radius * 0.21, -radius * 0.21)], tint)


func _star(center: Vector2, radius: float, tint: Color, angle: float = 0.0) -> void:
	var points: Array = []
	for index in range(10):
		points.append(center + Vector2.from_angle(-PI * 0.5 + angle + index * PI / 5.0) * radius * (1.0 if index % 2 == 0 else 0.44))
	_poly(points, tint)


func _rotate(point: Vector2, pivot: Vector2, angle: float) -> Vector2:
	return pivot + (point - pivot).rotated(angle)


func _box(rect: Rect2, tint: Color, radius: float) -> void:
	if rect.size.x <= 0.01 or rect.size.y <= 0.01:
		return
	var key: String = tint.to_html() + ":" + str(roundi(radius))
	if not _styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = tint
		style.set_corner_radius_all(maxi(0, roundi(radius)))
		style.anti_aliasing = true
		_styles[key] = style
	draw_style_box(_styles[key], rect)


func _ellipse(center: Vector2, radii: Vector2, tint: Color, angle: float = 0.0) -> void:
	var points: Array = []
	for index in range(40):
		points.append(center + Vector2(cos(index * TAU / 40.0) * radii.x, sin(index * TAU / 40.0) * radii.y).rotated(angle))
	_poly(points, tint)


func _poly(points: Array, tint: Color) -> void:
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or clean[-1].distance_squared_to(point) > 0.001:
			clean.append(point)
	if clean.size() > 2 and clean[0].distance_squared_to(clean[-1]) < 0.001:
		clean.remove_at(clean.size() - 1)
	var area: float = 0.0
	for index in range(clean.size()):
		area += clean[index].cross(clean[(index + 1) % clean.size()])
	if clean.size() >= 3 and absf(area) > 0.01:
		draw_colored_polygon(clean, tint)


func _line(start: Vector2, end: Vector2, tint: Color, width: float) -> void:
	if width > 0.01:
		draw_line(start, end, tint, width, true)


func _arc(center: Vector2, radius: float, start: float, end: float, tint: Color, width: float) -> void:
	if radius > 0.01 and width > 0.01:
		draw_arc(center, radius, start, end, 32, tint, width, true)

extends Control
## Original vector environments for the fourteen Talk Quest conversations.
## Art is drawn in a fixed design space and fitted without clipping on small screens.

const DESIGN_SIZE := Vector2(960, 540)
const INK := Color("#384964")
const CREAM := Color("#fff5dc")
const PALETTES: Array = [
	["#ffe4ce", "#eebc98"], ["#d6f3ee", "#9bcfc8"],
	["#fff0d5", "#e7c595"], ["#e8def6", "#c5b4da"],
	["#d9f1ec", "#c5dcae"], ["#ddf3e7", "#b3d5c1"],
	["#ffe8c8", "#d8bd96"], ["#354464", "#806b6c"],
	["#d5f0e9", "#a8c895"], ["#d7edfb", "#adc5d7"],
	["#c9eff7", "#edcd93"], ["#263958", "#52675e"],
	["#ffe4df", "#d4b3c5"], ["#dceef4", "#b2c5cd"]
]

var level: int = 1
var reduced_motion: bool = false
var _time: float = 0.0
var _progress: float = 0.0
var _target_progress: float = 0.0
var _celebration: float = 0.0
var _frame_time: float = 0.0
var _styles: Dictionary = {}
var _data: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	resized.connect(queue_redraw)


func configure(next_level: int, scene_data: Dictionary = {}) -> void:
	level = clampi(next_level, 1, 14)
	_data = scene_data.duplicate(true)
	_progress = 0.0
	_target_progress = 0.0
	_celebration = 0.0
	_time = 0.0
	queue_redraw()


func configure_level(next_level: int, scene_data: Dictionary = {}) -> void:
	configure(next_level, scene_data)


func set_progress(value: float) -> void:
	_target_progress = clampf(value, 0.0, 1.0)
	if reduced_motion:
		_progress = _target_progress
	queue_redraw()


func set_repair_count(value: int) -> void:
	set_progress(float(clampi(value, 0, 5)) / 5.0)


func celebrate() -> void:
	_target_progress = 1.0
	_celebration = 3.2
	if reduced_motion:
		_progress = 1.0
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_progress = _target_progress
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_progress = move_toward(_progress, _target_progress, delta * 1.6)
	var previous_celebration: float = _celebration
	_celebration = maxf(0.0, _celebration - delta)
	if previous_celebration > 0.0 and _celebration == 0.0:
		queue_redraw()
	if not reduced_motion:
		_time += delta
	_frame_time += delta
	if _frame_time >= 1.0 / 30.0:
		_frame_time = 0.0
		if not reduced_motion or not is_equal_approx(_progress, _target_progress):
			queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var wall := Color(PALETTES[level - 1][0])
	draw_rect(Rect2(Vector2.ZERO, size), wall)
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var origin := (size - DESIGN_SIZE * factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	match level:
		1: _porch()
		2: _bathroom()
		3: _kitchen()
		4: _bedroom()
		5: _playground()
		6: _classroom()
		7: _market()
		8: _library()
		9: _zoo()
		10: _bus()
		11: _beach()
		12: _camp()
		13: _birthday()
		14: _workshop()
	# Soft footlights leave room for the character and the conversation panel.
	_ellipse(Vector2(480, 447), Vector2(142, 26), Color(0.2, 0.25, 0.3, 0.08))
	if _celebration > 0.0:
		_celebrate_sparks()
	draw_set_transform(Vector2.ZERO)


func _room(wall: Color, floor_color: Color, horizon: float = 358.0) -> void:
	draw_rect(Rect2(0, 0, 960, 540), wall)
	draw_rect(Rect2(0, horizon, 960, 540 - horizon), floor_color)
	_box(Rect2(-10, horizon - 12, 980, 18), wall.darkened(0.10), 0)
	_line(Vector2(0, horizon + 6), Vector2(960, horizon + 6), Color(1, 1, 1, 0.32), 3)
	for index in range(7):
		var x: float = float(index) * 180.0 - 80.0
		_line(Vector2(480 + (x - 480) * 0.70, horizon + 10), Vector2(x, 540), Color(0.2, 0.25, 0.3, 0.055), 2)


func _window(rect: Rect2, night: bool = false) -> void:
	_box(Rect2(rect.position + Vector2(0, 7), rect.size), Color(0.2, 0.3, 0.4, 0.08), 24)
	_box(rect.grow(8), CREAM, 24)
	_box(rect, Color("#7792be") if night else Color("#bfe7ef"), 19)
	_box(Rect2(rect.position + Vector2(8, 8), rect.size * Vector2(0.38, 0.83)), Color(1, 1, 1, 0.18), 13)
	_line(rect.position + Vector2(rect.size.x * 0.5, 0), rect.position + Vector2(rect.size.x * 0.5, rect.size.y), CREAM, 7)
	_line(rect.position + Vector2(0, rect.size.y * 0.55), rect.position + Vector2(rect.size.x, rect.size.y * 0.55), CREAM, 7)
	_box(Rect2(rect.position + Vector2(-15, rect.size.y - 1), Vector2(rect.size.x + 30, 14)), CREAM, 7)


func _porch() -> void:
	_room(Color("#ffe4ce"), Color("#d1b59f"), 409)
	for index in range(6):
		_line(Vector2(0, 65 + index * 57), Vector2(960, 65 + index * 57), Color("#f2ceb4"), 3)
	_box(Rect2(338, 35, 284, 372), Color("#efc59f"), 110)
	_box(Rect2(353, 47, 254, 354), CREAM, 102)
	_box(Rect2(365, 59, 230, 342), Color("#638f97"), 92)
	var opening: float = smoothstep(0.78, 1.0, _progress)
	_box(Rect2(370, 64, 220 * (1.0 - opening * 0.76), 332), Color("#84b2b4"), 77)
	if opening > 0.05:
		_box(Rect2(541, 130, 39, 202), Color("#d4f1d6"), 12)
	var knob := Vector2(561 - opening * 157, 252)
	draw_circle(knob, 9, Color("#e9c46e"))
	draw_circle(knob + Vector2(-2, -2), 3, CREAM)
	_box(Rect2(325, 395, 310, 24), Color("#f4dfc3"), 8)
	_box(Rect2(309, 419, 342, 19), Color("#bc9b80"), 7)
	_box(Rect2(377, 443, 206, 39), Color("#d39973"), 14)
	for index in range(7):
		_line(Vector2(398 + index * 25, 451), Vector2(398 + index * 25, 474), Color("#e8b793"), 3)
	var bell_shift: float = sin(_time * 1.6) * 2.2
	_box(Rect2(656, 212 + bell_shift, 29, 48), CREAM, 12)
	draw_circle(Vector2(670, 236 + bell_shift), 7, Color("#d9ad5b"))
	_box(Rect2(714, 107, 149, 112), Color("#e7b892"), 15)
	_box(Rect2(723, 116, 131, 93), Color("#fef5de"), 10)
	_sun(Vector2(751, 143), 15, Color("#eec45b"))
	_poly([Vector2(735, 187), Vector2(775, 149), Vector2(804, 180), Vector2(838, 165), Vector2(844, 198), Vector2(735, 198)], Color("#9dc5a0"))
	_plant(Vector2(182, 428), 1.45, 0.0)
	_plant(Vector2(775, 429), 1.12, 1.7)
	_plant(Vector2(858, 448), 0.72, 2.8)
	_ellipse(Vector2(479, 109), Vector2(21, 10), Color(1, 1, 1, 0.27))


func _bathroom() -> void:
	_room(Color("#d6f3ee"), Color("#aad6d0"), 360)
	for row in range(4):
		for col in range(9):
			_box(Rect2(col * 120 + (row % 2) * 60 - 60, 90 + row * 64, 117, 61), Color(1, 1, 1, 0.20), 5)
	_box(Rect2(84, 64, 245, 198), Color("#81b7b8"), 77)
	_box(Rect2(97, 77, 219, 172), Color("#cfedf5"), 67)
	_poly([Vector2(116, 176), Vector2(222, 89), Vector2(262, 89), Vector2(119, 208)], Color(1, 1, 1, 0.34))
	_box(Rect2(135, 327, 144, 126), Color("#f0f7e9"), 23)
	_line(Vector2(207, 344), Vector2(207, 442), Color("#bdd9d3"), 3)
	_box(Rect2(72, 292, 274, 57), Color("#fffdf1"), 25)
	_ellipse(Vector2(210, 296), Vector2(105, 23), Color("#9acccc"))
	_ellipse(Vector2(210, 300), Vector2(84, 14), Color("#b4e5df"))
	_line(Vector2(245, 285), Vector2(245, 253), Color("#81a4b3"), 13)
	_arc(Vector2(226, 253), 20, PI, TAU, Color("#81a4b3"), 12)
	_line(Vector2(206, 252), Vector2(206, 268), Color("#81a4b3"), 10)
	if _progress > 0.12:
		for stream in range(3):
			_line(Vector2(201 + stream * 5, 270), Vector2(201 + stream * 5, 290 + sin(_time * 3.0 + stream) * 2), Color("#77c8dd"), 2)
	var press: float = maxf(0.0, sin(_time * 1.3)) * 4.0 if not reduced_motion else 0.0
	_box(Rect2(102, 249, 35, 48), Color("#e7c278"), 10)
	_box(Rect2(111, 236 + press, 17, 16), Color("#f5daa1"), 4)
	_box(Rect2(109, 230 + press, 38, 8), Color("#fff6d9"), 4)
	_line(Vector2(695, 169), Vector2(858, 169), Color("#78aaa9"), 9)
	_box(Rect2(720, 174, 97, 139), Color("#f2cfb9"), 12)
	_box(Rect2(721, 174, 17, 139), Color("#e6b69e"), 8)
	_line(Vector2(738, 285), Vector2(814, 285), CREAM, 5)
	_box(Rect2(666, 366, 229, 59), Color("#f8edd6"), 27)
	for index in range(7):
		var t: float = fmod(_time * 0.08 + float(index) / 7.0, 1.0)
		var point := Vector2(321 + sin(index * 2.7 + _time * 0.7) * 28, 318 - t * 190)
		_bubble(point, 6 + index % 3 * 4, Color(1, 1, 1, (1.0 - t) * 0.65))
	_plant(Vector2(854, 438), 0.65, 1.2)


func _kitchen() -> void:
	_room(Color("#fff0d5"), Color("#e7c595"), 357)
	_window(Rect2(359, 52, 240, 168))
	for index in range(3):
		var x: float = 42 + index * 92
		_box(Rect2(x, 85, 83, 135), Color("#c6d8b8"), 14)
		_box(Rect2(x + 9, 96, 65, 110), Color("#dae5c8"), 10)
		draw_circle(Vector2(x + 65, 158), 4, Color("#8c9f88"))
	_box(Rect2(688, 192, 220, 176), Color("#a3c2b0"), 18)
	_box(Rect2(680, 185, 236, 23), Color("#fcf1d9"), 9)
	_line(Vector2(799, 216), Vector2(799, 355), Color("#89ac99"), 4)
	for index in range(2):
		_line(Vector2(735 + index * 97, 240), Vector2(760 + index * 97, 240), CREAM, 6)
	_jar(Vector2(727, 178), Color("#edbd82"))
	_jar(Vector2(777, 178), Color("#c8b9d6"))
	_plant(Vector2(856, 188), 0.48, 1.0)
	_table(Vector2(260, 381), 350, 96, Color("#caa782"))
	_ellipse(Vector2(235, 357), Vector2(66, 24), Color("#fcfcf1"))
	var bounce: float = sin(_time * 1.2) * 2.0
	_box(Rect2(197, 319 + bounce, 77, 42), Color("#b98049"), 14)
	_box(Rect2(204, 323 + bounce, 64, 32), Color("#e8be79"), 11)
	_box(Rect2(222, 332 + bounce, 22, 13), Color("#f7dd96"), 5)
	_mug(Vector2(342, 346), Color("#a5cbd5"), 0.95)
	for index in range(3):
		_steam(Vector2(213 + index * 18, 308), float(index), Color(1, 1, 1, 0.62))
	_box(Rect2(130, 422, 74, 32), Color("#d99680"), 13)
	_line(Vector2(145, 449), Vector2(141, 486), Color("#b58264"), 9)
	_line(Vector2(193, 449), Vector2(200, 486), Color("#b58264"), 9)


func _bedroom() -> void:
	_room(Color("#e8def6"), Color("#c5b4da"), 368)
	_window(Rect2(379, 51, 176, 139))
	for index in range(5):
		_star(Vector2(357 + index * 48, 220 + sin(index) * 12), 8, Color("#f7ddb0"))
	_box(Rect2(69, 274, 277, 159), Color("#b29bb6"), 30)
	_box(Rect2(77, 248, 258, 116), Color("#f6e9e1"), 24)
	_box(Rect2(128, 278, 207, 102), Color("#aaa5d6"), 22)
	_box(Rect2(82, 261, 77, 54), Color("#fff5df"), 20)
	for index in range(4):
		_star(Vector2(181 + index * 43, 327), 9, Color("#d9d0ee"))
	_box(Rect2(704, 72, 190, 336), Color("#a99ac0"), 30)
	_box(Rect2(716, 85, 166, 307), Color("#6f6689"), 20)
	var door: float = 1.0 - 0.66 * smoothstep(0.08, 0.7, _progress)
	_box(Rect2(716, 85, 82 * door, 307), Color("#d0bfdf"), 19)
	_box(Rect2(882 - 82 * door, 85, 82 * door, 307), Color("#c5afd6"), 19)
	_line(Vector2(741, 151), Vector2(858, 151), Color("#d9cde6"), 5)
	var lift: float = sin(_time * 1.3) * 3.0
	_shirt(Vector2(800, 221 + lift), 0.8, Color("#83b7db"))
	_box(Rect2(751, 312, 21, 42), CREAM, 7)
	_box(Rect2(751, 340, 37, 15), CREAM, 7)
	_box(Rect2(811, 312, 21, 42), Color("#edcbb8"), 7)
	_box(Rect2(811, 340, 37, 15), Color("#edcbb8"), 7)
	_ellipse(Vector2(667, 445), Vector2(73, 22), Color("#ad99c1"))
	_box(Rect2(609, 412, 57, 26), Color("#cf928a"), 12)
	_box(Rect2(676, 419, 57, 26), Color("#cf928a"), 12)
	for index in range(2):
		_line(Vector2(626 + index * 68, 420 + index * 7), Vector2(644 + index * 68, 420 + index * 7), CREAM, 4)
	_ellipse(Vector2(437, 447), Vector2(135, 39), Color("#ddd0e8"))


func _playground() -> void:
	_outdoors(Color("#d9f1ec"), Color("#bbd5a0"))
	_cloud(Vector2(221, 76), 1.0)
	_cloud(Vector2(728, 108), 0.72)
	_sun(Vector2(834, 69), 30, Color("#f1ce73"))
	for index in range(8):
		_box(Rect2(index * 132 - 8, 301, 26, 70), Color("#f4e5c6"), 10)
	_line(Vector2(0, 321), Vector2(960, 321), Color("#ead8b6"), 12)
	_line(Vector2(0, 348), Vector2(960, 348), Color("#ead8b6"), 12)
	_ellipse(Vector2(246, 442), Vector2(193, 45), Color("#dcba97"))
	_line(Vector2(154, 223), Vector2(147, 419), Color("#d29276"), 17)
	_line(Vector2(245, 225), Vector2(255, 416), Color("#d29276"), 17)
	_box(Rect2(131, 208, 138, 22), Color("#e9bb8e"), 10)
	_poly([Vector2(129, 204), Vector2(198, 157), Vector2(268, 204)], Color("#efaaa1"))
	_poly([Vector2(252, 228), Vector2(282, 228), Vector2(415, 407), Vector2(394, 426), Vector2(359, 416)], Color("#e98f85"))
	_line(Vector2(270, 231), Vector2(397, 409), Color("#ffd0b2"), 16)
	for index in range(4):
		_line(Vector2(156, 276 + index * 33), Vector2(236, 276 + index * 33), Color("#e2ac88"), 11)
	_line(Vector2(194, 163), Vector2(194, 95), Color("#af8266"), 5)
	_poly([Vector2(198, 97), Vector2(256, 107 + sin(_time * 1.3) * 5), Vector2(198, 126)], Color("#eaba66"))
	_line(Vector2(671, 219), Vector2(625, 418), Color("#7eafa6"), 15)
	_line(Vector2(822, 219), Vector2(866, 418), Color("#7eafa6"), 15)
	_line(Vector2(670, 216), Vector2(821, 216), Color("#8dbdb1"), 20)
	var sway: float = sin(_time * 0.8) * 8.0
	_line(Vector2(723, 226), Vector2(723 + sway, 357), CREAM, 4)
	_line(Vector2(775, 226), Vector2(775 + sway, 357), CREAM, 4)
	_box(Rect2(706 + sway, 354, 89, 16), Color("#edbd7c"), 7)
	_flower(Vector2(92, 464), Color("#f1e7bd"), 10)
	_flower(Vector2(902, 447), Color("#e9b4b0"), 11)


func _classroom() -> void:
	_room(Color("#ddf3e7"), Color("#b3d5c1"), 366)
	_box(Rect2(355, 47, 260, 177), Color("#bb987a"), 18)
	_box(Rect2(367, 59, 236, 153), Color("#f4f5db"), 12)
	for index in range(3):
		_box(Rect2(73 + index * 78, 94 + (index % 2) * 13, 61, 73), Color("#fdf8e5"), 7)
		_star(Vector2(105 + index * 78, 127 + (index % 2) * 13), 15, [Color("#e8bd62"), Color("#cf94a2"), Color("#8eb7bd")][index])
	_table(Vector2(260, 391), 348, 87, Color("#d3ae84"))
	_box(Rect2(142, 336, 195, 53), Color("#fffcf0"), 8)
	if _progress > 0.22:
		_sun(Vector2(179, 355), 11 * smoothstep(0.22, 0.38, _progress), Color("#e9bc53"))
	if _progress > 0.56:
		var tree_size: float = smoothstep(0.56, 0.78, _progress)
		_line(Vector2(275, 377), Vector2(275, 346), Color("#b38661"), 7 * tree_size)
		for point in [Vector2(263, 348), Vector2(283, 348), Vector2(274, 340)]:
			draw_circle(point, 13 * tree_size, Color("#8eb891"))
	if _progress > 0.85:
		_sun(Vector2(424, 108), 19, Color("#e9bc53"))
		_tree(Vector2(548, 191), 0.42, Color("#9dc898"))
	_box(Rect2(75, 313, 49, 60), Color("#de9c86"), 10)
	for index in range(4):
		var x: float = 85 + index * 11
		var top: float = 287 - (index % 2) * 14 + sin(_time + index) * 1.4
		_line(Vector2(x, 343), Vector2(x, top), [Color("#8fbaac"), Color("#e5bc59"), Color("#91b3d2"), Color("#c18ba7")][index], 7)
		_poly([Vector2(x - 4, top), Vector2(x, top - 8), Vector2(x + 4, top)], Color("#eed4b0"))
	_box(Rect2(713, 238, 170, 172), Color("#97b9a4"), 19)
	for row in range(2):
		_box(Rect2(726, 250 + row * 79, 144, 63), Color("#d6e6c9"), 12)
		for item in range(3):
			_box(Rect2(738 + item * 43, 264 + row * 79, 33, 35), [Color("#d3b1a1"), Color("#b8c4db"), Color("#eccb83")][item], 9)
	_plant(Vector2(807, 238), 0.64, 1.0)


func _market() -> void:
	_room(Color("#ffe8c8"), Color("#d8bd96"), 381)
	_box(Rect2(79, 99, 802, 54), Color("#a7ba8c"), 17)
	for index in range(10):
		var x: float = 83 + index * 79
		_box(Rect2(x, 104, 77, 88), Color("#f5dba1") if index % 2 == 0 else Color("#a9c095"), 17)
	_box(Rect2(86, 77, 788, 42), Color("#eecb8a"), 15)
	for side in range(2):
		var x: float = 91 + side * 554
		_box(Rect2(x, 317, 223, 117), Color("#bf9470"), 12)
		for row in range(3):
			_line(Vector2(x + 7, 342 + row * 29), Vector2(x + 216, 342 + row * 29), Color("#d7ac7e"), 4)
		_box(Rect2(x - 5, 301, 233, 27), Color("#e6bf91"), 9)
		for index in range(8):
			var point := Vector2(x + 24 + (index % 5) * 43, 293 - floorf(float(index) / 5.0) * 29)
			point.y += sin(_time * 1.1 + index + side) * 1.5
			if side == 0:
				_apple(point, 19, Color("#d99179"))
			else:
				_arc(point + Vector2(0, -12), 20, 0.18, PI - 0.15, Color("#efd26c"), 11)
		_box(Rect2(x + 74, 224, 84, 43), Color("#fff3d6"), 10)
		if side == 0:
			_apple(Vector2(x + 101, 245), 10, Color("#d99179"))
		else:
			_arc(Vector2(x + 101, 238), 11, 0.2, PI - 0.1, Color("#e2bc50"), 6)
		for dot in range(3):
			draw_circle(Vector2(x + 123 + dot * 10, 246), 3, Color("#a98c61"))
	_ellipse(Vector2(512, 424), Vector2(73, 25), Color(0.3, 0.24, 0.2, 0.08))
	_arc(Vector2(497, 373), 38, PI, TAU, Color("#b48760"), 8)
	_box(Rect2(446, 371, 105, 57), Color("#d6aa76"), 18)
	for index in range(5):
		_line(Vector2(458 + index * 18, 378), Vector2(461 + index * 16, 422), Color("#b98f62"), 3)
	_line(Vector2(451, 398), Vector2(546, 398), Color("#edd0a0"), 4)


func _library() -> void:
	_room(Color("#354464"), Color("#806b6c"), 390)
	_window(Rect2(369, 53, 219, 164), true)
	_star(Vector2(418, 102), 6, Color("#f0da9c"))
	_star(Vector2(544, 128), 5, Color("#f0da9c"))
	for side in range(2):
		var x: float = 50 + side * 644
		_box(Rect2(x, 61, 216, 341), Color("#b4936c"), 51)
		_box(Rect2(x + 13, 78, 190, 307), Color("#5a5665"), 42)
		for shelf in range(3):
			for book in range(7):
				var h: float = 43 + (book * 13 + shelf * 19) % 28
				var bx: float = x + 25 + book * 24
				var by: float = 164 + shelf * 93 - h
				_box(Rect2(bx, by, 18, h), [Color("#a3bcae"), Color("#d2a481"), Color("#bd96a3"), Color("#d7bf86")][(book + shelf) % 4], 4)
				_line(Vector2(bx + 4, by + 9), Vector2(bx + 14, by + 9), Color(1, 1, 1, 0.30), 2)
			_box(Rect2(x + 13, 164 + shelf * 93, 190, 11), Color("#c3a378"), 4)
	_ellipse(Vector2(490, 458), Vector2(167, 40), Color("#bc9988"))
	_box(Rect2(281, 345, 95, 89), Color("#c1a0b3"), 31)
	_box(Rect2(289, 326, 78, 69), Color("#d0b2bf"), 27)
	_open_book(Vector2(326, 339), 0.78, sin(_time * 0.6) * 0.15)
	_line(Vector2(654, 423), Vector2(654, 210), Color("#c2ac83"), 7)
	_ellipse(Vector2(654, 427), Vector2(37, 11), Color("#b39877"))
	_ellipse(Vector2(654, 241), Vector2(69, 45), Color(1.0, 0.83, 0.43, 0.045))
	_poly([Vector2(624, 202), Vector2(685, 202), Vector2(698, 249), Vector2(611, 249)], Color("#e8ce95"))
	_ellipse(Vector2(654, 248), Vector2(43, 9), Color("#f6e3b0"))
	_plant(Vector2(891, 447), 0.63, 0.4)


func _zoo() -> void:
	_outdoors(Color("#d5f0e9"), Color("#a8c895"))
	_cloud(Vector2(487, 74), 0.73)
	_poly([Vector2(405, 324), Vector2(531, 324), Vector2(753, 540), Vector2(226, 540)], Color("#e5d6ae"))
	for side in range(2):
		var x: float = 45 + side * 608
		_box(Rect2(x, 127, 263, 233), Color("#8dac83"), 69)
		_box(Rect2(x + 13, 141, 237, 206), Color("#c2dcc0"), 58)
		_ellipse(Vector2(x + 131, 329), Vector2(104, 22), Color("#b1cfb0"))
	_tree(Vector2(785, 316), 0.70, Color("#85b090"))
	# A long neck, patterned body and small head make the giraffe readable at 320 px.
	_box(Rect2(156, 207, 22, 113), Color("#dcbb76"), 10)
	_ellipse(Vector2(192, 302), Vector2(48, 23), Color("#dcbb76"))
	_box(Rect2(145, 188, 47, 30), Color("#e7c781"), 13)
	for leg in range(3):
		_line(Vector2(164 + leg * 28, 310), Vector2(162 + leg * 28, 341), Color("#d5b070"), 8)
	for spot in [Vector2(167, 239), Vector2(166, 276), Vector2(185, 297), Vector2(210, 308)]:
		draw_circle(spot, 6, Color("#b39158"))
	_line(Vector2(154, 189), Vector2(151, 179), Color("#b39158"), 4)
	_line(Vector2(171, 189), Vector2(174, 179), Color("#b39158"), 4)
	draw_circle(Vector2(183, 198), 2.5, INK)
	_monkey(Vector2(766, 296), 0.67, Color("#ad9277"))
	_monkey(Vector2(812, 321), 0.38, Color("#c0a58c"))
	_ellipse(Vector2(887, 384), Vector2(19, 30), Color("#556d7b"))
	_ellipse(Vector2(887, 391), Vector2(13, 19), Color("#f4edcd"))
	_poly([Vector2(885, 371), Vector2(901, 375), Vector2(885, 379)], Color("#deae66"))
	draw_circle(Vector2(893, 367), 2, INK)
	_line(Vector2(585, 304), Vector2(585, 377), Color("#ab9678"), 8)
	_box(Rect2(548, 280, 76, 39), Color("#f3dfae"), 12)
	_poly([Vector2(571, 292), Vector2(591, 292), Vector2(591, 285), Vector2(605, 299), Vector2(591, 312), Vector2(591, 305), Vector2(571, 305)], Color("#8ba48a"))
	_plant(Vector2(65, 435), 0.8, 1.5)


func _bus() -> void:
	_outdoors(Color("#d7edfb"), Color("#bdcfc9"))
	for index in range(6):
		var x: float = float(index) * 190 - fmod(_time * 7.0, 190.0)
		_box(Rect2(x, 163 + (index % 2) * 24, 139, 173), Color("#b3c7d6"), 20)
		for row in range(2):
			_box(Rect2(x + 23, 192 + row * 49 + (index % 2) * 24, 36, 27), Color("#e4edf1"), 7)
	_box(Rect2(-10, 401, 980, 139), Color("#91a5b0"), 0)
	for index in range(7):
		_box(Rect2(index * 157 - fmod(_time * 14.0, 157.0), 478, 82, 7), Color("#e5ddbe"), 3)
	_box(Rect2(91, 154, 652, 263), Color("#638eae"), 62)
	_box(Rect2(101, 167, 632, 221), Color("#81afc8"), 51)
	_box(Rect2(111, 331, 613, 41), Color("#ebd796"), 15)
	for index in range(3):
		var x: float = 122 + index * 137
		_box(Rect2(x, 186, 115, 119), Color("#dcf1ef"), 23)
		_box(Rect2(x + 11, 260, 71, 43), Color("#c4a4a3"), 15)
		_line(Vector2(x + 59, 192), Vector2(x + 59, 254), Color("#badbdc"), 4)
	var door: float = smoothstep(0.15, 0.5, _progress)
	_box(Rect2(557, 189, 136, 212), Color("#496d87"), 20)
	_box(Rect2(562, 194, 60 * (1.0 - door * 0.78), 200), Color("#c4e1e7"), 13)
	_box(Rect2(688 - 60 * (1.0 - door * 0.78), 194, 60 * (1.0 - door * 0.78), 200), Color("#bdd9e2"), 13)
	_box(Rect2(574, 402, 105, 12), Color("#d9cdb1"), 4)
	for x in [228.0, 619.0]:
		draw_circle(Vector2(x, 415), 40, Color("#536371"))
		draw_circle(Vector2(x, 415), 23, Color("#bcc8ca"))
		draw_circle(Vector2(x, 415), 8, Color("#91a3ad"))
	_line(Vector2(835, 259), Vector2(835, 445), Color("#d6b984"), 8)
	_box(Rect2(795, 199, 82, 67), Color("#f2dcac"), 19)
	_box(Rect2(809, 213, 54, 32), Color("#7fabc1"), 9)
	for x in [820.0, 852.0]:
		draw_circle(Vector2(x, 247), 5, INK)
	_box(Rect2(762, 372, 118, 50), Color("#f1dfb7"), 8)
	for index in range(4):
		_line(Vector2(781, 382 + index * 8), Vector2(831, 382 + index * 8), Color("#c3ad85"), 2)
	_star(Vector2(856, 398), 10, Color("#cda969"))


func _beach() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("#c9eff7"))
	_cloud(Vector2(304, 89), 0.77)
	_sun(Vector2(813, 80), 37, Color("#f7d985"))
	draw_rect(Rect2(0, 220, 960, 199), Color("#8bcfd7"))
	for index in range(3):
		_wave(260 + index * 39, 8, Color("#c5ebdf"), 5, float(index))
	_poly([Vector2(0, 340), Vector2(150, 325), Vector2(390, 360), Vector2(620, 337), Vector2(960, 324), Vector2(960, 540), Vector2(0, 540)], Color("#edcd93"))
	_wave(346, 7, Color("#f5e4b7"), 10, 0.8)
	_box(Rect2(59, 411, 206, 65), Color("#dc9c8e"), 10)
	for index in range(5):
		_line(Vector2(80 + index * 39, 416), Vector2(80 + index * 39, 470), Color("#f6d9b4"), 10)
	var tower: float = smoothstep(0.15, 0.8, _progress)
	_castle(Vector2(736, 431), 1.17, tower)
	var tip: float = sin(_time * 0.9) * 3.0
	_poly([Vector2(289 + tip, 361), Vector2(351 + tip, 364), Vector2(342, 423), Vector2(302, 423)], Color("#81b8ba"))
	_arc(Vector2(322 + tip, 365), 24, PI, TAU, Color("#e8c278"), 5)
	_box(Rect2(282 + tip, 357, 76, 11), Color("#a4d1cb"), 5)
	for point in [Vector2(594, 468), Vector2(875, 421), Vector2(354, 486)]:
		_shell(point, 17, Color("#edb29c"))
	for index in range(16):
		draw_circle(Vector2(43 + index * 57, 395 + (index * 31) % 132), 1.7, Color("#ccac77"))


func _camp() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("#263958"))
	for index in range(28):
		var point := Vector2(27 + (index * 139) % 922, 23 + (index * 73) % 237)
		var alpha: float = 0.45 + 0.32 * sin(_time * 0.6 + index * 1.7)
		_star(point, 2.0 + index % 3, Color(1.0, 0.91, 0.69, alpha))
	draw_circle(Vector2(804, 78), 32, Color("#efe1b0"))
	draw_circle(Vector2(817, 69), 29, Color("#263958"))
	_poly([Vector2(0, 278), Vector2(166, 156), Vector2(311, 282), Vector2(449, 193), Vector2(611, 297), Vector2(763, 184), Vector2(960, 292), Vector2(960, 540), Vector2(0, 540)], Color("#3c5560"))
	_ellipse(Vector2(471, 507), Vector2(716, 190), Color("#52675e"))
	for index in range(3):
		_pine(Vector2(807 + index * 57, 371 + index * 25), 0.64 + index * 0.15, Color("#3c5854"))
	_ellipse(Vector2(251, 430), Vector2(182, 33), Color(0.1, 0.16, 0.2, 0.2))
	_poly([Vector2(68, 423), Vector2(227, 191), Vector2(402, 422)], Color("#c29973"))
	_poly([Vector2(227, 191), Vector2(414, 258), Vector2(457, 422), Vector2(402, 422)], Color("#8f8271"))
	_poly([Vector2(124, 421), Vector2(230, 251), Vector2(340, 421)], Color("#3d4d53"))
	_poly([Vector2(124, 421), Vector2(230, 251), Vector2(188, 409)], Color("#e2bd89"))
	_poly([Vector2(230, 251), Vector2(340, 421), Vector2(273, 404)], Color("#d5ad7b"))
	_line(Vector2(74, 426), Vector2(41, 442), Color("#d3c6a4"), 3)
	_line(Vector2(443, 421), Vector2(476, 442), Color("#d3c6a4"), 3)
	_box(Rect2(600, 384, 74, 106), Color("#b2a4b9"), 30)
	_box(Rect2(609, 380, 56, 33), Color("#e0d9cc"), 13)
	_box(Rect2(687, 404, 74, 106), Color("#92b4ab"), 30)
	_box(Rect2(696, 400, 56, 33), Color("#e0d9cc"), 13)
	_bear(Vector2(819, 448), 0.64, Color("#b8a07d"))
	_ellipse(Vector2(529, 408), Vector2(45, 21), Color(1.0, 0.80, 0.44, 0.06))
	_box(Rect2(511, 372, 34, 51), Color("#d8bb7f"), 10)
	_box(Rect2(517, 381, 22, 28), Color("#ffdf91"), 7)
	_arc(Vector2(528, 370), 11, PI, TAU, Color("#c8b492"), 3)


func _birthday() -> void:
	_room(Color("#ffe4df"), Color("#d4b3c5"), 384)
	_box(Rect2(263, 60, 435, 302), Color("#dcb6c6"), 93)
	_box(Rect2(280, 77, 401, 285), Color("#f7d3cc"), 82)
	_box(Rect2(233, 356, 495, 47), Color("#b68eaa"), 17)
	_box(Rect2(252, 352, 457, 23), Color("#eed4cf"), 11)
	for string_index in range(2):
		var rope := PackedVector2Array()
		for index in range(21):
			var x: float = index * 48
			rope.append(Vector2(x, 57 + string_index * 59 + sin(float(index) / 20.0 * PI) * 44))
		draw_polyline(rope, Color("#c1a091"), 2, true)
		for index in range(11):
			var x: float = 35 + index * 89
			var y: float = 57 + string_index * 59 + sin(x / 960.0 * PI) * 44
			_poly([Vector2(x - 15, y), Vector2(x + 15, y), Vector2(x, y + 29)], [Color("#e9b76f"), Color("#a4c4bb"), Color("#c1acd0")][(index + string_index) % 3])
	for index in range(4):
		var bx: float = 70 + (index % 2) * 91 + floori(float(index) / 2.0) * 643
		var by: float = 218 + (index % 2) * 32 + sin(_time * 0.8 + index) * 5
		_line(Vector2(bx, by + 41), Vector2(bx + 8, 397), Color("#bda2a5"), 2)
		_ellipse(Vector2(bx, by), Vector2(28, 36), [Color("#e8b574"), Color("#c3b1d4"), Color("#a2c6bc"), Color("#e7a6a5")][index])
		_ellipse(Vector2(bx - 8, by - 13), Vector2(5, 9), Color(1, 1, 1, 0.25))
	_table(Vector2(786, 404), 250, 65, Color("#c297a4"))
	_cake(Vector2(789, 366), 0.72)
	_mug(Vector2(873, 375), Color("#e5bf7d"), 0.55)
	_present(Vector2(123, 422), Vector2(85, 64), Color("#9dc4b8"), Color("#f5dda4"))
	_present(Vector2(213, 443), Vector2(58, 82), Color("#c0aacd"), Color("#f1cdac"))
	for index in range(3):
		_box(Rect2(341 + index * 56, 463, 48, 30), [Color("#d59995"), Color("#acbe99"), Color("#b1adc9")][index], 7)
		for wheel in range(2):
			draw_circle(Vector2(350 + index * 56 + wheel * 27, 494), 7, Color("#8b8499"))
	_box(Rect2(343, 443, 22, 29), Color("#d59995"), 5)
	_box(Rect2(370, 451, 11, 21), Color("#c5a77a"), 4)


func _workshop() -> void:
	_room(Color("#dceef4"), Color("#b2c5cd"), 365)
	_box(Rect2(330, 48, 305, 192), Color("#9db6bf"), 22)
	_box(Rect2(342, 60, 281, 168), Color("#c2d4d8"), 16)
	for row in range(5):
		for col in range(9):
			draw_circle(Vector2(358 + col * 31, 77 + row * 33), 2, Color("#95b0b9"))
	_line(Vector2(393, 95), Vector2(393, 163), Color("#c69675"), 10)
	_box(Rect2(371, 88, 44, 18), Color("#91a7b4"), 6)
	_line(Vector2(449, 99), Vector2(449, 164), Color("#e0b66d"), 9)
	_box(Rect2(442, 80, 14, 26), Color("#90a8b2"), 5)
	_arc(Vector2(515, 110), 16, 0.5, TAU - 0.5, Color("#91a7b4"), 8)
	_line(Vector2(515, 127), Vector2(515, 164), Color("#91a7b4"), 10)
	_gear(Vector2(579, 112), 23, Color("#e6bd7d"))
	# Three large silhouettes match the triangle, circle and square part choices.
	_poly([Vector2(376, 203), Vector2(392, 176), Vector2(408, 203)], Color("#d9a097"))
	draw_circle(Vector2(479, 191), 15, Color("#a4bc98"))
	_box(Rect2(551, 176, 29, 29), Color("#a79fc9"), 5)
	for index in range(5):
		var x: float = 82 + index * 176
		var repaired: bool = _progress + 0.001 >= float(index + 1) / 5.0
		_box(Rect2(x - 20, 296, 139, 115), Color("#a6bfc1"), 17)
		_box(Rect2(x - 24, 286, 147, 19), Color("#f0d8af"), 8)
		_box(Rect2(x + 6, 323, 89, 66), Color("#c7d8d5"), 12)
		var toy_y: float = 270.0
		if repaired and not reduced_motion:
			toy_y -= maxf(0.0, sin(_time * 1.5 + index)) * 5.0
		_toy(Vector2(x + 49, toy_y), index, repaired)
		if repaired:
			_star(Vector2(x + 49, 351), 11, Color("#e7be64"))
		else:
			draw_circle(Vector2(x + 49, 351), 5, Color("#a1b9b8"))
	_box(Rect2(67, 444, 155, 45), Color("#c0aecb"), 21)
	_box(Rect2(77, 441, 66, 26), Color("#e2d7e5"), 12)
	_star(Vector2(185, 462), 10, Color("#ead5a0"))
	_ellipse(Vector2(812, 474), Vector2(77, 21), Color("#99b4bd"))
	_box(Rect2(774, 433, 77, 35), Color("#d5b388"), 11)
	_gear(Vector2(793, 440), 13, Color("#a8b9c7"))
	_gear(Vector2(827, 438), 11, Color("#dbb4a0"))


func _toy(center: Vector2, type: int, repaired: bool) -> void:
	var c := Color("#b1c4c8") if not repaired else Color("#e3b382")
	match type:
		0:
			_box(Rect2(center + Vector2(-36, -26), Vector2(72, 27)), c, 10)
			_box(Rect2(center + Vector2(-18, -43), Vector2(38, 25)), c.lightened(0.1), 12)
			for x in [-22.0, 23.0]:
				draw_circle(center + Vector2(x, 2), 11, Color("#6c8491"))
				draw_circle(center + Vector2(x, 2), 4, CREAM)
		1:
			_poly([center + Vector2(-51, -18), center + Vector2(-9, -26), center + Vector2(3, -55), center + Vector2(14, -55), center + Vector2(16, -25), center + Vector2(47, -15), center + Vector2(47, -5), center + Vector2(8, -10), center + Vector2(-13, 3), center + Vector2(-21, -1), center + Vector2(-11, -14), center + Vector2(-51, -8)], c)
		2: _bear(center + Vector2(0, -17), 0.60, c)
		3:
			_box(Rect2(center + Vector2(-25, -30), Vector2(50, 33)), c, 9)
			_box(Rect2(center + Vector2(-28, -65), Vector2(56, 35)), c.lightened(0.15), 10)
			for x in [-11.0, 11.0]:
				draw_circle(center + Vector2(x, -49), 5, Color("#637f90"))
			_line(center + Vector2(-36, -24), center + Vector2(-29, -6), c, 9)
			_line(center + Vector2(36, -24), center + Vector2(29, -6), c, 9)
		4:
			_box(Rect2(center + Vector2(-34, -30), Vector2(68, 36)), c, 11)
			_box(Rect2(center + Vector2(-39, -37), Vector2(78, 14)), c.lightened(0.2), 6)
			_star(center + Vector2(0, -13), 10, Color("#fff1c3"))
			if repaired:
				_note(center + Vector2(23, -56), Color("#b794b8"))


func _outdoors(sky: Color, ground_color: Color) -> void:
	draw_rect(Rect2(0, 0, 960, 540), sky)
	_ellipse(Vector2(107, 425), Vector2(520, 189), ground_color.lightened(0.13))
	_ellipse(Vector2(839, 443), Vector2(603, 200), ground_color)
	_tree(Vector2(32, 338), 1.05, ground_color.darkened(0.06))
	_tree(Vector2(933, 316), 0.98, ground_color.darkened(0.02))


func _tree(base: Vector2, scale_value: float, green: Color) -> void:
	_line(base, base + Vector2(0, -116) * scale_value, Color("#b29877"), 16 * scale_value)
	for p in [Vector2(-35, -115), Vector2(32, -119), Vector2(0, -151)]:
		draw_circle(base + p * scale_value, 46 * scale_value, green)
	draw_circle(base + Vector2(-15, -159) * scale_value, 23 * scale_value, green.lightened(0.09))


func _pine(base: Vector2, scale_value: float, green: Color) -> void:
	_line(base, base + Vector2(0, -123) * scale_value, Color("#8d8974"), 12 * scale_value)
	for index in range(3):
		var y: float = -53.0 - index * 40.0
		var w: float = 57.0 - index * 11.0
		_poly([base + Vector2(-w, y) * scale_value, base + Vector2(0, y - 76) * scale_value, base + Vector2(w, y) * scale_value], green.lightened(index * 0.025))


func _plant(base: Vector2, scale_value: float, phase: float) -> void:
	var sway: float = sin(_time * 0.8 + phase) * 4.0
	_ellipse(base + Vector2(0, 4) * scale_value, Vector2(48, 12) * scale_value, Color(0.2, 0.25, 0.25, 0.08))
	for index in range(5):
		var tip := base + Vector2((index - 2) * 24 + sway, -91 - (2 - absi(index - 2)) * 19) * scale_value
		_line(base + Vector2(0, -33) * scale_value, tip, Color("#84a684"), 4 * scale_value)
		_ellipse(tip, Vector2(16, 32) * scale_value, Color("#9bb995").lightened((index % 2) * 0.1), float(index - 2) * 0.39)
	_poly([base + Vector2(-37, -48) * scale_value, base + Vector2(37, -48) * scale_value, base + Vector2(29, 0) * scale_value, base + Vector2(-29, 0) * scale_value], Color("#cfac8b"))
	_box(Rect2(base + Vector2(-41, -53) * scale_value, Vector2(82, 14) * scale_value), Color("#e0bea0"), 7 * scale_value)


func _table(center: Vector2, width: float, depth: float, tint: Color) -> void:
	for side in [-1.0, 1.0]:
		_line(center + Vector2(side * width * 0.35, 11), center + Vector2(side * width * 0.39, 99), tint.darkened(0.08), 16)
	_box(Rect2(center - Vector2(width * 0.5, depth * 0.5), Vector2(width, depth)), tint, 27)
	_box(Rect2(center - Vector2(width * 0.5, depth * 0.5 + 7), Vector2(width, depth - 7)), tint.lightened(0.14), 27)


func _mug(base: Vector2, tint: Color, scale_value: float) -> void:
	_arc(base + Vector2(26, -23) * scale_value, 16 * scale_value, -PI * 0.6, PI * 0.6, tint.darkened(0.06), 8 * scale_value)
	_box(Rect2(base + Vector2(-24, -49) * scale_value, Vector2(49, 52) * scale_value), tint, 10 * scale_value)
	_ellipse(base + Vector2(0, -47) * scale_value, Vector2(24, 9) * scale_value, tint.lightened(0.18))
	_ellipse(base + Vector2(0, -47) * scale_value, Vector2(18, 5) * scale_value, CREAM)


func _jar(base: Vector2, tint: Color) -> void:
	_box(Rect2(base + Vector2(-17, -47), Vector2(34, 47)), tint, 10)
	_box(Rect2(base + Vector2(-19, -51), Vector2(38, 10)), Color("#e7d3ac"), 4)
	_box(Rect2(base + Vector2(-12, -33), Vector2(24, 19)), CREAM, 6)


func _shirt(center: Vector2, scale_value: float, tint: Color) -> void:
	var points: Array = []
	for p in [Vector2(-22, -37), Vector2(-56, -13), Vector2(-39, 7), Vector2(-25, -1), Vector2(-26, 44), Vector2(26, 44), Vector2(25, -1), Vector2(39, 7), Vector2(56, -13), Vector2(22, -37), Vector2(12, -26), Vector2(-12, -26)]:
		points.append(center + p * scale_value)
	_poly(points, tint)
	_line(center + Vector2(-19, 32) * scale_value, center + Vector2(20, 32) * scale_value, tint.lightened(0.16), 4 * scale_value)


func _bear(center: Vector2, scale_value: float, tint: Color) -> void:
	for side in [-1.0, 1.0]:
		draw_circle(center + Vector2(side * 27, -39) * scale_value, 15 * scale_value, tint)
		_ellipse(center + Vector2(side * 27, 30) * scale_value, Vector2(14, 18) * scale_value, tint)
	_ellipse(center + Vector2(0, 20) * scale_value, Vector2(33, 38) * scale_value, tint)
	draw_circle(center + Vector2(0, -21) * scale_value, 33 * scale_value, tint.lightened(0.04))
	_ellipse(center + Vector2(0, -11) * scale_value, Vector2(16, 12) * scale_value, tint.lightened(0.28))
	for side in [-1.0, 1.0]:
		draw_circle(center + Vector2(side * 13, -27) * scale_value, 3 * scale_value, INK)
	draw_circle(center + Vector2(0, -15) * scale_value, 4 * scale_value, INK)


func _monkey(center: Vector2, scale_value: float, tint: Color) -> void:
	var tail := PackedVector2Array()
	for index in range(25):
		var angle: float = -0.5 + index * TAU * 0.87 / 24.0
		var radius: float = 30.0 - index * 0.62
		tail.append(center + (Vector2(-41, 23) + Vector2.from_angle(angle) * radius) * scale_value)
	draw_polyline(tail, tint.darkened(0.03), 9 * scale_value, true)
	_ellipse(center + Vector2(0, 23) * scale_value, Vector2(26, 35) * scale_value, tint)
	for side in [-1.0, 1.0]:
		draw_circle(center + Vector2(side * 31, -22) * scale_value, 14 * scale_value, tint)
		draw_circle(center + Vector2(side * 31, -22) * scale_value, 8 * scale_value, tint.lightened(0.22))
		_ellipse(center + Vector2(side * 22, 47) * scale_value, Vector2(15, 9) * scale_value, tint)
	draw_circle(center + Vector2(0, -20) * scale_value, 32 * scale_value, tint)
	for side in [-1.0, 1.0]:
		_ellipse(center + Vector2(side * 11, -23) * scale_value, Vector2(17, 20) * scale_value, tint.lightened(0.26))
		draw_circle(center + Vector2(side * 11, -28) * scale_value, 3 * scale_value, INK)
	_ellipse(center + Vector2(0, -7) * scale_value, Vector2(19, 12) * scale_value, tint.lightened(0.26))
	_arc(center + Vector2(0, -8) * scale_value, 8 * scale_value, 0.2, PI - 0.2, tint.darkened(0.25), 2 * scale_value)


func _open_book(center: Vector2, scale_value: float, page: float) -> void:
	_poly([center + Vector2(-63, -17) * scale_value, center + Vector2(-14, -24) * scale_value, center + Vector2(0, -15) * scale_value, center + Vector2(17, -25) * scale_value, center + Vector2(64, -19) * scale_value, center + Vector2(60, 14) * scale_value, center + Vector2(0, 23) * scale_value, center + Vector2(-61, 14) * scale_value], CREAM)
	_line(center + Vector2(0, -15) * scale_value, center + Vector2(0, 23) * scale_value, Color("#c3af8d"), 3 * scale_value)
	# The left page carries the bear picture used in the library conversation.
	for point in [Vector2(-43, -4), Vector2(-25, -6)]:
		draw_circle(center + point * scale_value, 6 * scale_value, Color("#c7ad86"))
	_ellipse(center + Vector2(-34, 3) * scale_value, Vector2(13, 11) * scale_value, Color("#c7ad86"))
	for x in [-39.0, -29.0]:
		draw_circle(center + Vector2(x, 1) * scale_value, 1.2 * scale_value, INK)
	for index in range(3):
		_line(center + Vector2(11, -5 + index * 7) * scale_value, center + Vector2(51, -8 + index * 7) * scale_value, Color("#d7c9a8"), 2 * scale_value)
	if page > 0.0:
		_poly([center + Vector2(0, -15) * scale_value, center + Vector2(-44 * page, -35) * scale_value, center + Vector2(-48 * page, 1) * scale_value, center + Vector2(0, 23) * scale_value], Color("#fff8e6"))


func _castle(base: Vector2, scale_value: float, progress_value: float) -> void:
	_box(Rect2(base + Vector2(-85, -67) * scale_value, Vector2(170, 70) * scale_value), Color("#d4af75"), 8)
	for side in [-1.0, 1.0]:
		var height: float = 67 + progress_value * 47
		_box(Rect2(base + Vector2(side * 68 - 27, -height) * scale_value, Vector2(54, height) * scale_value), Color("#e4c18a"), 6)
		for index in range(3):
			_box(Rect2(base + Vector2(side * 68 - 28 + index * 20, -height - 15) * scale_value, Vector2(16, 23) * scale_value), Color("#e4c18a"), 3)
	_box(Rect2(base + Vector2(-22, -42) * scale_value, Vector2(44, 45) * scale_value), Color("#b99362"), 20)
	_line(base + Vector2(0, -67) * scale_value, base + Vector2(0, -143) * scale_value, Color("#b18e63"), 4)
	_poly([base + Vector2(3, -143) * scale_value, base + Vector2(40, -129 + sin(_time) * 2) * scale_value, base + Vector2(3, -119) * scale_value], Color("#d99285"))


func _cake(base: Vector2, scale_value: float) -> void:
	for tier in range(3):
		var width: float = 134 - tier * 31
		var y: float = -tier * 39
		_box(Rect2(base + Vector2(-width * 0.5, y - 40) * scale_value, Vector2(width, 42) * scale_value), [Color("#dfa6aa"), Color("#edc4ac"), Color("#e8afbd")][tier], 9)
		_box(Rect2(base + Vector2(-width * 0.5, y - 43) * scale_value, Vector2(width, 12) * scale_value), CREAM, 5)
	for index in range(3):
		var x: float = -19 + index * 19
		_line(base + Vector2(x, -121) * scale_value, base + Vector2(x, -141) * scale_value, Color("#a6c5bc"), 5 * scale_value)
		_ellipse(base + Vector2(x, -150) * scale_value, Vector2(4, 7) * scale_value, Color("#ecc66b"))


func _present(base: Vector2, dimensions: Vector2, tint: Color, ribbon: Color) -> void:
	_box(Rect2(base - Vector2(dimensions.x * 0.5, dimensions.y), dimensions), tint, 9)
	_box(Rect2(base - Vector2(8, dimensions.y), Vector2(16, dimensions.y)), ribbon, 3)
	_box(Rect2(base - Vector2(dimensions.x * 0.5 + 4, dimensions.y + 3), Vector2(dimensions.x + 8, 14)), tint.lightened(0.12), 5)
	for side in [-1.0, 1.0]:
		_ellipse(base + Vector2(side * 14, -dimensions.y - 9), Vector2(15, 8), ribbon, side * 0.3)


func _apple(center: Vector2, radius: float, tint: Color) -> void:
	draw_circle(center + Vector2(-radius * 0.28, 0), radius * 0.78, tint)
	draw_circle(center + Vector2(radius * 0.29, 0), radius * 0.78, tint)
	_line(center + Vector2(0, -radius * 0.6), center + Vector2(3, -radius * 1.08), Color("#a28560"), 3)
	_ellipse(center + Vector2(8, -radius * 0.88), Vector2(8, 4), Color("#9fb27d"), -0.3)
	draw_circle(center + Vector2(-radius * 0.38, -radius * 0.28), radius * 0.18, Color(1, 1, 1, 0.25))


func _shell(center: Vector2, radius: float, tint: Color) -> void:
	var points: Array = [center + Vector2(0, radius * 0.48)]
	for index in range(13):
		var angle: float = PI + index * PI / 12.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_poly(points, tint)
	for index in range(1, 5):
		_line(center + Vector2(0, radius * 0.35), center + Vector2.from_angle(PI + index * PI / 5.0) * radius * 0.82, tint.darkened(0.12), 1.5)


func _cloud(center: Vector2, scale_value: float) -> void:
	for piece in [Vector3(-45, 4, 27), Vector3(-16, -11, 37), Vector3(21, -4, 29), Vector3(48, 10, 20)]:
		draw_circle(center + Vector2(piece.x, piece.y) * scale_value, piece.z * scale_value, Color(1, 1, 1, 0.65))
	_box(Rect2(center + Vector2(-48, 1) * scale_value, Vector2(100, 28) * scale_value), Color(1, 1, 1, 0.65), 13)


func _sun(center: Vector2, radius: float, tint: Color) -> void:
	if radius < 0.01:
		return
	for index in range(10):
		var direction := Vector2.from_angle(index * TAU / 10.0)
		_line(center + direction * radius * 1.2, center + direction * radius * 1.47, tint, maxf(2, radius * 0.1))
	draw_circle(center, radius, tint)
	draw_circle(center + Vector2(-radius * 0.22, -radius * 0.25), radius * 0.18, tint.lightened(0.18))


func _flower(center: Vector2, tint: Color, radius: float) -> void:
	for index in range(5):
		draw_circle(center + Vector2.from_angle(index * TAU / 5.0) * radius * 0.62, radius * 0.53, tint)
	draw_circle(center, radius * 0.38, Color("#d3b374"))


func _gear(center: Vector2, radius: float, tint: Color) -> void:
	for index in range(8):
		var direction := Vector2.from_angle(index * TAU / 8.0)
		_line(center + direction * radius * 0.63, center + direction * radius, tint, radius * 0.4)
	draw_circle(center, radius * 0.76, tint)
	draw_circle(center, radius * 0.31, Color("#c2d4d8"))


func _note(center: Vector2, tint: Color) -> void:
	_ellipse(center, Vector2(7, 5), tint, -0.3)
	_line(center + Vector2(6, 0), center + Vector2(6, -23), tint, 3)
	_line(center + Vector2(6, -23), center + Vector2(16, -18), tint, 4)


func _wave(y: float, amplitude: float, tint: Color, width: float, phase: float) -> void:
	var points := PackedVector2Array()
	for index in range(49):
		points.append(Vector2(index * 20, y + sin(index * 0.23 + _time * 0.65 + phase) * amplitude))
	draw_polyline(points, tint, width, true)


func _steam(base: Vector2, phase: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in range(12):
		points.append(base + Vector2(sin(index * 0.49 + phase + _time * 0.8) * 4, -index * 3.5))
	draw_polyline(points, tint, 2, true)


func _bubble(center: Vector2, radius: float, tint: Color) -> void:
	draw_circle(center, radius, Color(tint, tint.a * 0.20))
	_arc(center, radius, 0, TAU, tint, 1.8)
	_arc(center, radius * 0.66, PI * 1.05, PI * 1.55, Color(tint, tint.a * 0.9), 2)


func _celebrate_sparks() -> void:
	var alpha: float = minf(1.0, _celebration)
	for index in range(12):
		var point := Vector2(140 + index * 61, 124 + sin(index * 2.1) * 49)
		if not reduced_motion:
			point.y += (3.2 - _celebration) * 31 + sin(_time * 2 + index) * 5
		_star(point, 4 + index % 3 * 2, Color(Color("#f1cf85") if index % 2 else Color("#fff7d4"), alpha))


func _star(center: Vector2, radius: float, tint: Color) -> void:
	var points: Array = []
	for index in range(10):
		points.append(center + Vector2.from_angle(-PI * 0.5 + index * PI / 5.0) * radius * (1.0 if index % 2 == 0 else 0.43))
	_poly(points, tint)


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
		var point := Vector2(cos(index * TAU / 40.0) * radii.x, sin(index * TAU / 40.0) * radii.y)
		points.append(center + point.rotated(angle))
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

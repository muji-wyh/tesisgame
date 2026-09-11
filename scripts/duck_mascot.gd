extends Button

const SHEET = preload("res://assets/images/mascots/pip.svg")
const IDLE_SHEET = preload("res://assets/images/mascots/pip-idle-actions.svg")
const Style = preload("res://scripts/ui_style.gd")
const IDLE_ACTIONS := ["look", "stretch", "wave", "preen", "hop"]
const IDLE_SECONDS: float = 1.8
const TRICK_SECONDS: float = 1.8
const ROOM_REACTION_SECONDS: float = 1.1
const TRICK_CAPTIONS := {
	"dance": "Pip's happy dance!", "snack": "Crunch! A carrot for Pip!", "bubbles": "Pop! Bubble party!"
}

var speaking: bool = false
var reduced_motion: bool = false
var compact: bool = false
var pose: int = 0
var reaction_left: float = 0.0
var accent: Color = Style.GOOD
var _reaction: String = ""
var _idle_time: float = 0.0
var _speech_time: float = 0.0
var _trick: String = ""
var _trick_left: float = 0.0
var _idle_action: String = ""
var _idle_left: float = 0.0
var _idle_wait: float = 3.5
var _idle_index: int = 0
var _idle_paused: bool = false
var _idle_rng := RandomNumberGenerator.new()
var _room_motion: String = ""
var _room_direction: float = 1.0
var _room_step: float = 0.0
var _room_reaction: String = ""
var _room_reaction_left: float = 0.0


func _ready() -> void:
	_idle_rng.randomize()
	name = "Pip"
	custom_minimum_size = Vector2(72, 72)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Pip the duck. Press for a hello!"
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.INK, 18, 2))
	mouse_entered.connect(func() -> void: react("curious"))
	focus_entered.connect(func() -> void: react("curious"))
	visibility_changed.connect(_visibility_changed)
	resized.connect(queue_redraw)
	_visibility_changed()


func set_speaking(value: bool) -> void:
	if speaking == value:
		return
	speaking = value
	_speech_time = 0.0
	_reset_idle()
	_update_pose()


func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	_reset_idle()
	if value:
		reaction_left = 0.0
		_trick_left = 0.0
		_room_reaction_left = 0.0
	elif is_zero_approx(_trick_left):
		_trick = ""
	if not value and is_zero_approx(_room_reaction_left):
		_room_reaction = ""
	_visibility_changed()
	_update_pose()


func react(kind: String = "happy") -> void:
	_reset_idle()
	_reaction = kind
	reaction_left = 0.0 if reduced_motion else 0.65
	if reduced_motion:
		pose = 1 if speaking else 3 if kind == "happy" else 0
		queue_redraw()
		return
	_update_pose()


func settle() -> void:
	clear_room_interaction()
	_reset_idle()
	reaction_left = 0.0
	_reaction = ""
	_idle_time = 0.0
	clear_trick()
	set_speaking(false)
	_update_pose()


func perform_trick(kind: String) -> String:
	if not TRICK_CAPTIONS.has(kind):
		return ""
	_reset_idle()
	_trick = kind
	_trick_left = 0.0 if reduced_motion else TRICK_SECONDS
	reaction_left = 0.0
	_update_pose()
	return TRICK_CAPTIONS[kind]


func clear_trick() -> void:
	_trick = ""
	_trick_left = 0.0
	_update_pose()


func set_room_motion(kind: String, direction: float = 1.0) -> void:
	if not kind in ["", "walk", "run"]:
		return
	if not kind.is_empty() and (_idle_paused or not is_visible_in_tree()):
		return
	_room_direction = -1.0 if direction < 0.0 else 1.0
	if _room_motion == kind:
		queue_redraw()
		return
	_reset_idle()
	_room_motion = kind
	_room_step = 0.0
	if not kind.is_empty():
		_room_reaction = ""
		_room_reaction_left = 0.0
		reaction_left = 0.0
		clear_trick()
	_update_pose()


func react_in_room(kind: String) -> void:
	if not kind in ["pet", "poke", "catch"] or _idle_paused or not is_visible_in_tree():
		return
	_reset_idle()
	_room_motion = ""
	_room_step = 0.0
	_room_reaction = kind
	_room_reaction_left = 0.0 if reduced_motion else ROOM_REACTION_SECONDS
	reaction_left = 0.0
	clear_trick()
	_update_pose()


func clear_room_interaction() -> void:
	if _room_motion.is_empty() and _room_reaction.is_empty():
		return
	_room_motion = ""
	_room_reaction = ""
	_room_reaction_left = 0.0
	_room_step = 0.0
	_room_direction = 1.0
	_idle_time = 0.0
	reaction_left = 0.0
	_reaction = ""
	_reset_idle()
	_update_pose()


func _visibility_changed() -> void:
	set_process(is_visible_in_tree() and not reduced_motion and not _idle_paused)
	if not is_visible_in_tree():
		clear_room_interaction()
		_reset_idle()
		reaction_left = 0.0
		clear_trick()


func set_idle_paused(value: bool) -> void:
	if _idle_paused == value:
		return
	_idle_paused = value
	if value:
		clear_room_interaction()
	_reset_idle()
	_visibility_changed()
	_update_pose()


func _reset_idle() -> void:
	_idle_action = ""
	_idle_left = 0.0
	_idle_wait = _idle_rng.randf_range(6.0, 10.0)


func _advance_idle(delta: float) -> void:
	# A resumed tab or a long engine frame must not catch up missed gestures.
	if delta > 0.5:
		_reset_idle()
		return
	if speaking or reaction_left > 0.0 or not _trick.is_empty() or not _room_motion.is_empty() or not _room_reaction.is_empty():
		return
	if not _idle_action.is_empty():
		_idle_left = maxf(0.0, _idle_left - delta)
		if is_zero_approx(_idle_left):
			_reset_idle()
		return
	_idle_wait -= delta
	if _idle_wait <= 0.0:
		_idle_action = IDLE_ACTIONS[_idle_index % IDLE_ACTIONS.size()]
		_idle_index += 1
		_idle_left = IDLE_SECONDS


func _update_pose() -> void:
	pose = 0
	if speaking:
		pose = 1 if reduced_motion else 1 - int(_speech_time * 8.0) % 2
	elif not _room_reaction.is_empty():
		pose = 2 if _room_reaction == "pet" else 1 if _room_reaction == "poke" else 3
	elif not _room_motion.is_empty():
		pose = 3 if _room_motion == "run" else 0
	elif not _trick.is_empty():
		pose = 3 if _trick == "dance" else 1
	elif reaction_left > 0.0 and _reaction == "happy":
		pose = 3
	elif _idle_action == "wave" or _idle_action == "hop":
		pose = 3 if sin((1.0 - _idle_left / IDLE_SECONDS) * TAU * 2.0) > 0.0 else 0
	elif not reduced_motion and fmod(_idle_time, 4.6) > 4.42:
		pose = 2
	queue_redraw()


func _process(delta: float) -> void:
	if reduced_motion or _idle_paused or not is_visible_in_tree():
		return
	_idle_time += delta
	_speech_time += delta
	reaction_left = maxf(0.0, reaction_left - delta)
	if not _room_motion.is_empty():
		_room_step += minf(delta, 0.1) * (4.2 if _room_motion == "run" else 2.3)
	if _room_reaction_left > 0.0:
		_room_reaction_left = maxf(0.0, _room_reaction_left - delta)
		if is_zero_approx(_room_reaction_left):
			_room_reaction = ""
			_reset_idle()
	if _trick_left > 0.0:
		_trick_left = maxf(0.0, _trick_left - delta)
		if is_zero_approx(_trick_left):
			_trick = ""
	_advance_idle(delta)
	_update_pose()


func _draw() -> void:
	var edge: float = 54.0 if compact else minf(size.x, size.y)
	var origin := Vector2(0, -2) if compact else (size - Vector2.ONE * edge) * 0.5
	var wave: float = sin((1.0 - reaction_left / 0.65) * PI) if reaction_left > 0.0 else 0.0
	var turn: float = (-0.07 if _reaction == "curious" else 0.07) * wave
	var trick_progress: float = 0.45 if reduced_motion else 1.0 - _trick_left / TRICK_SECONDS
	var bounce: float = -wave * edge * 0.07
	var stretch := Vector2(1 + wave * 0.04, 1 - wave * 0.03)
	var sheet: Texture2D = SHEET
	var frame: int = pose
	if not _idle_action.is_empty():
		var progress: float = 1.0 - _idle_left / IDLE_SECONDS
		var envelope: float = sin(progress * PI)
		match _idle_action:
			"look":
				sheet = IDLE_SHEET
				frame = 0 if progress < 0.5 else 1
				turn = sin(progress * TAU) * 0.09
			"stretch":
				sheet = IDLE_SHEET
				frame = 2
				stretch = Vector2(1.0 - envelope * 0.05, 1.0 + envelope * 0.06)
			"preen":
				sheet = IDLE_SHEET
				frame = 3
				turn = envelope * 0.09 + sin(progress * TAU * 2.0) * 0.025
			"wave":
				turn = sin(progress * TAU * 2.0) * 0.08
			"hop":
				var lift: float = absf(sin(progress * TAU))
				bounce = -lift * edge * 0.07
				stretch = Vector2(1.0 - lift * 0.025, 1.0 + lift * 0.035)
	if _trick == "dance" and not reduced_motion:
		turn += sin(trick_progress * TAU * 3.0) * 0.13
		bounce -= absf(sin(trick_progress * TAU * 3.0)) * edge * 0.055
	elif _trick == "snack" and not reduced_motion:
		turn += sin(trick_progress * TAU * 2.0) * 0.045
	if not _room_motion.is_empty():
		var running: bool = _room_motion == "run"
		var stride: float = 0.0 if reduced_motion else sin(_room_step * TAU)
		turn = _room_direction * (0.12 if running else 0.055) + stride * (0.07 if running else 0.04)
		bounce = -absf(stride) * edge * (0.065 if running else 0.025)
		stretch = Vector2(1.0 + absf(stride) * 0.025, 1.0 - absf(stride) * 0.02)
		if not speaking:
			sheet = SHEET if running and stride > 0.0 else IDLE_SHEET
			frame = 3 if sheet == SHEET else 0 if _room_direction < 0.0 else 1
	if not _room_reaction.is_empty():
		var progress: float = 0.4 if reduced_motion else 1.0 - _room_reaction_left / ROOM_REACTION_SECONDS
		var pulse: float = 0.7 if reduced_motion else sin(progress * PI)
		match _room_reaction:
			"pet":
				turn = -0.1 * pulse
				stretch = Vector2.ONE * (1.0 + pulse * 0.035)
				bounce = 0.0
			"poke":
				turn = 0.0
				bounce = 0.0 if reduced_motion else -absf(sin(minf(progress * 2.0, 1.0) * PI)) * edge * 0.1
				stretch = Vector2(0.96, 1.04)
			"catch":
				turn = 0.0 if reduced_motion else sin(progress * TAU * 2.0) * 0.06
				bounce = 0.0 if reduced_motion else -pulse * edge * 0.055
				if not speaking:
					sheet = IDLE_SHEET
					frame = 2
	var center := origin + Vector2(edge * 0.5, edge * 0.75)
	draw_set_transform(center + Vector2(0, bounce), turn, stretch)
	var source_edge: float = sheet.get_height()
	draw_texture_rect_region(sheet, Rect2(origin - center, Vector2.ONE * edge),
		Rect2(Vector2(float(frame) * source_edge, 0), Vector2.ONE * source_edge))
	draw_set_transform(Vector2.ZERO)
	_draw_room_effects(origin, edge)
	if not _trick.is_empty():
		_draw_trick(origin, edge, trick_progress)
	if speaking:
		for index in range(2):
			draw_arc(origin + Vector2(edge * 0.8, edge * 0.55), edge * (0.08 + index * 0.06),
				-0.75, 0.75, 12, accent, 1.6, true)


func _draw_room_effects(origin: Vector2, edge: float) -> void:
	if not _room_motion.is_empty():
		for index in range(3):
			var step: float = float(index) / 3.0 if reduced_motion else fmod(_room_step + float(index) / 3.0, 1.0)
			var point := origin + Vector2(edge * (0.5 - _room_direction * (0.16 + step * 0.3)), edge * (0.9 + float(index % 2) * 0.05))
			var tint := Color(Color("#a4784b"), (1.0 - step) * 0.5)
			for toe in range(3):
				draw_line(point, point + Vector2(_room_direction * edge * 0.025, (toe - 1) * edge * 0.022), tint, maxf(1.5, edge * 0.01), true)
	if _room_reaction.is_empty():
		return
	var progress: float = 0.4 if reduced_motion else 1.0 - _room_reaction_left / ROOM_REACTION_SECONDS
	var fade: float = 1.0 if reduced_motion else minf(1.0, (1.0 - progress) * 4.0)
	if _room_reaction == "pet":
		for index in range(3):
			var point := origin + Vector2(edge * (0.12 + index * 0.37), edge * (0.24 - progress * 0.12 + float(index % 2) * 0.06))
			var radius: float = edge * 0.032
			var tint := Color(Color("#ec7b97"), fade)
			draw_circle(point + Vector2(-radius * 0.6, 0), radius, tint)
			draw_circle(point + Vector2(radius * 0.6, 0), radius, tint)
			draw_colored_polygon(PackedVector2Array([point + Vector2(-radius * 1.5, radius * 0.3), point + Vector2(radius * 1.5, radius * 0.3), point + Vector2(0, radius * 2.0)]), tint)
	elif _room_reaction == "poke":
		var point := origin + Vector2(edge * 0.85, edge * 0.25)
		draw_arc(point, edge * (0.055 + progress * 0.12), 0.0, TAU, 24, Color(accent, fade * 0.7), maxf(1.5, edge * 0.014), true)
		draw_line(point + Vector2(0, -edge * 0.025), point + Vector2(0, edge * 0.025), Color(Style.INK, fade), maxf(2.0, edge * 0.017), true)
		draw_circle(point + Vector2(0, edge * 0.055), edge * 0.012, Color(Style.INK, fade))
	elif _room_reaction == "catch":
		for index in range(5):
			var point := origin + Vector2(edge * (0.1 + index * 0.2), edge * (0.18 + float(index % 2) * 0.13 - progress * 0.08))
			var radius: float = edge * 0.024
			var tint := Color(Color("#e0a52e"), fade)
			draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), tint, maxf(2.0, edge * 0.012), true)
			draw_line(point - Vector2(0, radius), point + Vector2(0, radius), tint, maxf(2.0, edge * 0.012), true)


func _draw_trick(origin: Vector2, edge: float, progress: float) -> void:
	var fade: float = 1.0 if reduced_motion else clampf((1.0 - progress) * 5.0, 0.0, 1.0)
	if _trick == "dance":
		for index in range(3):
			var beat: float = 0.0 if reduced_motion else sin(progress * TAU * 3.0 + index)
			var point := origin + Vector2(edge * (0.16 + index * 0.32), edge * (0.15 - beat * 0.04))
			var tint := Color(accent, fade)
			draw_circle(point, edge * 0.025, tint)
			draw_line(point, point + Vector2(0, -edge * 0.07), tint, 2.0, true)
			draw_line(point + Vector2(0, -edge * 0.07), point + Vector2(edge * 0.035, -edge * 0.05), tint, 2.0, true)
	elif _trick == "snack":
		var bite: float = 1.0 if reduced_motion else 1.0 - floorf(progress * 3.0) * 0.16
		var point := origin + Vector2(edge * 0.79, edge * 0.68)
		var carrot := PackedVector2Array([point + Vector2(-edge * 0.045, -edge * 0.08),
			point + Vector2(edge * 0.07, -edge * 0.04), point + Vector2(-edge * 0.03, edge * 0.12 * bite)])
		draw_colored_polygon(carrot, Color(Color("#f09b42"), fade))
		for index in range(3):
			var top := point + Vector2(edge * 0.01, -edge * 0.065)
			draw_line(top, top + Vector2((index - 1) * edge * 0.045, -edge * 0.08),
				Color(Style.GOOD, fade), maxf(2.0, edge * 0.022), true)
		for index in range(3):
			var fall: float = 0.3 if reduced_motion else fmod(progress * 2.0 + index * 0.3, 1.0)
			var crumb := point + Vector2((index - 1) * edge * 0.055, edge * (0.1 + fall * 0.13))
			draw_circle(crumb, maxf(1.0, edge * 0.012), Color(Color("#f09b42"), fade))
	elif _trick == "bubbles":
		for index in range(6):
			var rise: float = float(index % 3) / 3.0 if reduced_motion else fmod(progress * 1.4 + index * 0.17, 1.0)
			var radius: float = edge * (0.04 + float(index % 3) * 0.012)
			var point := origin + Vector2(edge * (0.11 if index % 2 == 0 else 0.89), edge * (0.83 - rise * 0.65))
			var alpha: float = fade if reduced_motion else fade * sin(rise * PI)
			draw_circle(point, radius, Color(0.65, 0.86, 1.0, alpha * 0.24))
			draw_arc(point, radius, 0.0, TAU, 20, Color(accent.lightened(0.3), alpha), 1.8, true)
			draw_circle(point + Vector2(-radius * 0.3, -radius * 0.3), maxf(1.0, radius * 0.18), Color(1, 1, 1, alpha))

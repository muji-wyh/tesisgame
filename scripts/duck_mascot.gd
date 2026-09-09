extends Button

const SHEET = preload("res://assets/images/mascots/pip.svg")
const Style = preload("res://scripts/ui_style.gd")
const TRICK_SECONDS: float = 1.8
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


func _ready() -> void:
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
	_update_pose()


func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	if value:
		reaction_left = 0.0
		_trick_left = 0.0
	elif is_zero_approx(_trick_left):
		_trick = ""
	_visibility_changed()
	_update_pose()


func react(kind: String = "happy") -> void:
	_reaction = kind
	reaction_left = 0.0 if reduced_motion else 0.65
	if reduced_motion:
		pose = 1 if speaking else 3 if kind == "happy" else 0
		queue_redraw()
		return
	_update_pose()


func settle() -> void:
	reaction_left = 0.0
	_reaction = ""
	_idle_time = 0.0
	clear_trick()
	set_speaking(false)
	_update_pose()


func perform_trick(kind: String) -> String:
	if not TRICK_CAPTIONS.has(kind):
		return ""
	_trick = kind
	_trick_left = 0.0 if reduced_motion else TRICK_SECONDS
	reaction_left = 0.0
	_update_pose()
	return TRICK_CAPTIONS[kind]


func clear_trick() -> void:
	_trick = ""
	_trick_left = 0.0
	_update_pose()


func _visibility_changed() -> void:
	set_process(is_visible_in_tree() and not reduced_motion)
	if not is_visible_in_tree():
		reaction_left = 0.0
		clear_trick()


func _update_pose() -> void:
	pose = 0
	if speaking:
		pose = 1 if reduced_motion else 1 - int(_speech_time * 8.0) % 2
	elif not _trick.is_empty():
		pose = 3 if _trick == "dance" else 1
	elif reaction_left > 0.0 and _reaction == "happy":
		pose = 3
	elif not reduced_motion and fmod(_idle_time, 4.6) > 4.42:
		pose = 2
	queue_redraw()


func _process(delta: float) -> void:
	if reduced_motion:
		return
	_idle_time += delta
	_speech_time += delta
	reaction_left = maxf(0.0, reaction_left - delta)
	if _trick_left > 0.0:
		_trick_left = maxf(0.0, _trick_left - delta)
		if is_zero_approx(_trick_left):
			_trick = ""
	_update_pose()


func _draw() -> void:
	var edge: float = 54.0 if compact else minf(size.x, size.y)
	var origin := Vector2(0, -2) if compact else (size - Vector2.ONE * edge) * 0.5
	var wave: float = sin((1.0 - reaction_left / 0.65) * PI) if reaction_left > 0.0 else 0.0
	var turn: float = (-0.07 if _reaction == "curious" else 0.07) * wave
	var trick_progress: float = 0.45 if reduced_motion else 1.0 - _trick_left / TRICK_SECONDS
	var bounce: float = -wave * edge * 0.07
	if _trick == "dance" and not reduced_motion:
		turn += sin(trick_progress * TAU * 3.0) * 0.13
		bounce -= absf(sin(trick_progress * TAU * 3.0)) * edge * 0.055
	elif _trick == "snack" and not reduced_motion:
		turn += sin(trick_progress * TAU * 2.0) * 0.045
	var center := origin + Vector2(edge * 0.5, edge * 0.75)
	draw_set_transform(center + Vector2(0, bounce), turn, Vector2(1 + wave * 0.04, 1 - wave * 0.03))
	var source_edge: float = SHEET.get_height()
	draw_texture_rect_region(SHEET, Rect2(origin - center, Vector2.ONE * edge),
		Rect2(Vector2(float(pose) * source_edge, 0), Vector2.ONE * source_edge))
	draw_set_transform(Vector2.ZERO)
	if not _trick.is_empty():
		_draw_trick(origin, edge, trick_progress)
	if speaking:
		for index in range(2):
			draw_arc(origin + Vector2(edge * 0.8, edge * 0.55), edge * (0.08 + index * 0.06),
				-0.75, 0.75, 12, accent, 1.6, true)


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

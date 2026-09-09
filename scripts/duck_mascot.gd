extends Button

const SHEET = preload("res://assets/images/mascots/pip.svg")
const Style = preload("res://scripts/ui_style.gd")

var speaking: bool = false
var reduced_motion: bool = false
var compact: bool = false
var pose: int = 0
var reaction_left: float = 0.0
var accent: Color = Style.GOOD
var _reaction: String = ""
var _idle_time: float = 0.0
var _speech_time: float = 0.0


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
	set_speaking(false)
	_update_pose()


func _visibility_changed() -> void:
	set_process(is_visible_in_tree() and not reduced_motion)
	if not is_visible_in_tree():
		reaction_left = 0.0


func _update_pose() -> void:
	pose = 0
	if speaking:
		pose = 1 if reduced_motion else 1 - int(_speech_time * 8.0) % 2
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
	_update_pose()


func _draw() -> void:
	var edge: float = 54.0 if compact else minf(size.x, size.y)
	var origin := Vector2(0, -2) if compact else (size - Vector2.ONE * edge) * 0.5
	var wave: float = sin((1.0 - reaction_left / 0.65) * PI) if reaction_left > 0.0 else 0.0
	var turn: float = (-0.07 if _reaction == "curious" else 0.07) * wave
	var center := origin + Vector2(edge * 0.5, edge * 0.75)
	draw_set_transform(center + Vector2(0, -wave * edge * 0.07), turn, Vector2(1 + wave * 0.04, 1 - wave * 0.03))
	var source_edge: float = SHEET.get_height()
	draw_texture_rect_region(SHEET, Rect2(origin - center, Vector2.ONE * edge),
		Rect2(Vector2(float(pose) * source_edge, 0), Vector2.ONE * source_edge))
	draw_set_transform(Vector2.ZERO)
	if speaking:
		for index in range(2):
			draw_arc(origin + Vector2(edge * 0.8, edge * 0.55), edge * (0.08 + index * 0.06),
				-0.75, 0.75, 12, accent, 1.6, true)

extends Button

signal gameplay_reaction_finished(correct: bool)

const SHEET = preload("res://assets/images/mascots/pip.svg")
const DANCE_SHEET = preload("res://assets/images/mascots/pip-dance-parts.svg")
const Outfits = preload("res://scripts/pip_outfits.gd")
const GROWTH_CATALOG_PATH := "res://data/pip-growth-stages.json"
const Style = preload("res://scripts/ui_style.gd")
const GROWTH_ACTION_SECONDS := {"wave": 1.8, "look": 1.9, "high-five": 1.7,
	"peekaboo": 2.1, "stretch": 2.2, "hop": 1.7, "dance-sway": 2.8,
	"flutter": 1.9, "dance-wave": 2.9, "dance-hop": 3.2}
const GROWTH_ACTION_CAPTIONS := {"wave": "Hello from Pip!", "look": "Pip is curious!",
	"high-five": "High five!", "peekaboo": "Peekaboo!", "stretch": "A little stretch!",
	"hop": "A happy little hop!", "dance-sway": "Sway with Pip!", "flutter": "Flutter, flutter!",
	"dance-wave": "Pip's two-step wave!", "dance-hop": "Pip's celebration dance!"}
const IDLE_SECONDS: float = 1.8
const PROACTIVE_IDLE_SECONDS: float = 6.0
const GAMEPLAY_HAPPY_SECONDS: float = 1.25
const GAMEPLAY_SAD_SECONDS: float = 1.35
const CELEBRATION_SECONDS: float = 3.0
const EXPRESSION_NAMES := ["neutral", "listening", "thinking", "delighted", "proud",
	"encourage", "surprised", "sleepy", "wink", "blink"]
const HAPPY_EXPRESSIONS := ["delighted", "wink", "proud"]
const GAMEPLAY_PIVOTS := [Vector2(61, 98), Vector2(61, 72), Vector2(33, 78),
	Vector2(88, 78), Vector2(40, 103), Vector2(80, 103)]
const CELEBRATION_POSES := {
	"rest": [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO],
	"left": [Vector3(-4, 3, -4), Vector3(-5, 1, 4), Vector3(-4, 2, 78), Vector3(-4, 2, -22), Vector3.ZERO, Vector3(0, -5, 9)],
	"right": [Vector3(4, 3, 4), Vector3(5, 0, -5), Vector3(4, 2, 24), Vector3(4, 2, -88), Vector3(0, -5, -9), Vector3.ZERO],
	"crouch": [Vector3(0, 5, 0), Vector3(0, 7, 0), Vector3(0, 4, -14), Vector3(0, 4, 14), Vector3.ZERO, Vector3.ZERO],
	"push-off": [Vector3(0, -2, 0), Vector3(0, 0, 0), Vector3(0, -1, 40), Vector3(0, -1, -40), Vector3.ZERO, Vector3.ZERO],
	"leap": [Vector3(0, -23, -3), Vector3(0, -25, 3), Vector3(0, -23, 100), Vector3(0, -23, -100), Vector3(-2, -23, -17), Vector3(2, -23, 17)],
	"touchdown": [Vector3(0, -5, -1), Vector3(0, -9, 2), Vector3(0, -5, 72), Vector3(0, -5, -80), Vector3.ZERO, Vector3.ZERO],
	"land": [Vector3(0, 4, 0), Vector3(0, 5, -2), Vector3(0, 2, 52), Vector3(0, 2, -64), Vector3.ZERO, Vector3.ZERO],
	"recover": [Vector3.ZERO, Vector3(0, 1, 0), Vector3(0, 0, 32), Vector3(0, 0, -38), Vector3.ZERO, Vector3.ZERO],
	"present-reach": [Vector3(-3, -1, -3), Vector3(1, -3, 7), Vector3(-3, -1, 34), Vector3(-1, -3, -91), Vector3.ZERO, Vector3.ZERO],
	"present": [Vector3(-2, 0, -2), Vector3(0, -2, 4), Vector3(-2, 0, 27), Vector3(-1, -2, -77), Vector3.ZERO, Vector3.ZERO],
}
# Push-off and compressed landing share the presentation's two contact cues.
# Feet touch first; the body and head absorb the landing before either step.
const CELEBRATION_BEATS := [[0.0, "rest"], [0.18, "crouch"], [0.25, "push-off"],
	[0.52, "leap"], [0.82, "touchdown"], [0.9, "land"], [0.99, "recover"],
	[1.15, "left"], [1.31, "recover"], [1.5, "right"], [1.65, "recover"],
	[1.85, "present-reach"], [2.4, "present"], [3.0, "present"]]

var speaking: bool = false
var reduced_motion: bool = false
var compact: bool = false
var pose: int = 0
var reaction_left: float = 0.0
var accent: Color = Style.GOOD
var theme_id: String = "spring"
var growth_level: int = 3
var _growth_stage: Dictionary = {}
static var _growth_definitions: Array = []
var _outfit_sheet: Texture2D
var _outfit_idle_sheet: Texture2D
var _outfit_dance_sheet: Texture2D
var _expression_sheet: Texture2D
var _expression_heads: Texture2D
var _attention: String = ""
var _face_name: String = ""
var _reaction_face: String = ""
var _greeting_cycle: int = 0
var _success_cycle: int = 0
var _gameplay_variant: int = 0
var _reaction: String = ""
var _idle_time: float = 0.0
var _speech_time: float = 0.0
var _idle_action: String = ""
var _growth_action_manual: bool = false
var _idle_left: float = 0.0
var _idle_wait: float = PROACTIVE_IDLE_SECONDS
var _idle_index: int = 0
var _idle_paused: bool = false
var _proactive_allowed: bool = false
var _idle_rng := RandomNumberGenerator.new()
var _gameplay_reaction: String = ""
var _gameplay_left: float = 0.0
var _gameplay_seconds: float = GAMEPLAY_SAD_SECONDS
var _celebration_progress: float = -1.0
var _celebration_rest: float = 0.0


func _ready() -> void:
	_idle_rng.randomize()
	set_growth_level(growth_level)
	set_outfit_theme(theme_id)
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


func set_outfit_theme(value: String) -> void:
	var chosen := Outfits.normalize_theme(value)
	if not _growth_stage.is_empty():
		# World colors remain independent from Pip's earned growth appearance.
		theme_id = chosen
		queue_redraw()
		return
	if theme_id == chosen and _outfit_sheet != null:
		return
	var sheets: Array[Texture2D] = Outfits.load_sheets(chosen)
	theme_id = chosen
	_outfit_sheet = sheets[0]
	_outfit_idle_sheet = sheets[1]
	_outfit_dance_sheet = sheets[2]
	var expressions: Array[Texture2D] = Outfits.load_expression_sheets(chosen)
	_expression_sheet = expressions[0]
	_expression_heads = expressions[1]
	# A wardrobe change is visual only: preserve speech, gestures and quiet timing.
	queue_redraw()


func set_growth_level(value: int) -> void:
	var chosen: int = clampi(value, 3, 12)
	if growth_level == chosen and not _growth_stage.is_empty():
		return
	if _growth_definitions.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GROWTH_CATALOG_PATH))
		if parsed is Dictionary and parsed.get("stages") is Array:
			_growth_definitions = parsed.stages
	var stage: Dictionary = {}
	for definition in _growth_definitions:
		if definition is Dictionary and int(definition.get("level", 0)) == chosen:
			stage = definition
			break
	if stage.is_empty():
		push_error("Missing Pip growth stage for level %d." % chosen)
		return
	var art: Dictionary = stage.get("art", {})
	var sheets: Array[Texture2D] = []
	for kind in ["regular", "idle", "parts", "expressions", "expressionHeads"]:
		var asset_path: String = "res://" + str(art.get(kind, ""))
		var texture: Texture2D = load(asset_path) as Texture2D
		if texture == null:
			push_error("Missing Pip growth artwork: " + asset_path)
			return
		sheets.append(texture)
	growth_level = chosen
	_growth_stage = stage.duplicate(true)
	_outfit_sheet = sheets[0]
	_outfit_idle_sheet = sheets[1]
	_outfit_dance_sheet = sheets[2]
	_expression_sheet = sheets[3]
	_expression_heads = sheets[4]
	_reset_idle()
	# Keep final-answer reactions and shared celebration on their original clock.
	_update_pose()


func growth_actions() -> Array[String]:
	var result: Array[String] = []
	for action in _growth_stage.get("actions", ["wave"]):
		result.append(str(action))
	return result


func growth_voice_path() -> String:
	var voice: Dictionary = _growth_stage.get("newVoice", {})
	return "res://" + str(voice.get("path", "")) if voice.has("path") else ""


func perform_growth_action(kind: String = "") -> bool:
	if _celebration_progress >= 0.0 or not _gameplay_reaction.is_empty() or _idle_paused or speaking or not is_visible_in_tree() or is_manual_action_busy():
		return false
	var available: Array[String] = growth_actions()
	if available.is_empty():
		return false
	var chosen: String = available[_idle_index % available.size()] if kind.is_empty() else kind
	if not chosen in available:
		return false
	_reset_idle()
	_idle_action = chosen
	_growth_action_manual = true
	_idle_index += 1
	_idle_left = 0.0 if reduced_motion else _idle_duration()
	reaction_left = 0.0
	set_process(not reduced_motion)
	_update_pose()
	return true


func set_speaking(value: bool) -> void:
	if speaking == value:
		return
	speaking = value
	_speech_time = 0.0
	_reset_idle()
	_update_pose()


func set_attention(kind: String) -> void:
	if not kind in ["", "listening", "thinking"] or _attention == kind:
		return
	if not kind.is_empty() and (_idle_paused or not is_visible_in_tree()):
		return
	_attention = kind
	if not _growth_action_manual:
		_reset_idle()
	_update_pose()


func expression_name() -> String:
	if not _face_name.is_empty():
		return _face_name
	return "speaking" if speaking else "blink" if pose == 2 else "neutral"


func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	_reset_idle()
	if not value and is_zero_approx(_gameplay_left):
		_gameplay_reaction = ""
	_visibility_changed()
	_update_pose()

func react(kind: String = "happy") -> void:
	if _celebration_progress >= 0.0 or not _gameplay_reaction.is_empty() or _growth_action_manual or _idle_paused or not is_visible_in_tree():
		return
	if not kind in ["happy", "curious"] and not kind in EXPRESSION_NAMES:
		return
	_reset_idle()
	_reaction = kind
	_reaction_face = "thinking" if kind == "curious" else kind
	if kind == "happy":
		_reaction_face = HAPPY_EXPRESSIONS[_greeting_cycle % HAPPY_EXPRESSIONS.size()]
		_greeting_cycle += 1
	reaction_left = 0.65
	set_process(true)
	_update_pose()


func react_gameplay(correct: bool, duration: float = 0.0) -> void:
	if _celebration_progress >= 0.0 or _idle_paused or not is_visible_in_tree():
		return
	_reset_idle()
	reaction_left = 0.0
	_reaction = ""
	_gameplay_reaction = "happy" if correct else "sad"
	if correct:
		_gameplay_variant = _success_cycle % HAPPY_EXPRESSIONS.size()
		_success_cycle += 1
	_gameplay_seconds = GAMEPLAY_HAPPY_SECONDS if correct else GAMEPLAY_SAD_SECONDS
	if is_finite(duration) and duration > 0.0:
		_gameplay_seconds = clampf(duration, 0.5, 4.0)
	_gameplay_left = _gameplay_duration()
	set_process(true)
	_update_pose()


func clear_gameplay_reaction() -> void:
	_gameplay_reaction = ""
	_gameplay_left = 0.0
	if reduced_motion:
		set_process(reaction_left > 0.0 and not _idle_paused and is_visible_in_tree())
	_update_pose()


func _gameplay_duration() -> float:
	return _gameplay_seconds


func settle() -> void:
	_celebration_progress = -1.0
	_celebration_rest = 0.0
	clear_gameplay_reaction()
	_reset_idle()
	reaction_left = 0.0
	_reaction = ""
	_reaction_face = ""
	_attention = ""
	_idle_time = 0.0
	set_speaking(false)
	_update_pose()


func set_celebration_progress(progress: float, rest_seconds: float = 0.0) -> void:
	if not is_finite(progress) or not is_finite(rest_seconds):
		return
	if _celebration_progress < 0.0:
		settle()
	_celebration_progress = clampf(progress, 0.0, 1.0)
	_celebration_rest = maxf(0.0, rest_seconds)
	# The presentation owns this clock. Idle, speech and reactions cannot advance it.
	set_process(false)
	_update_pose()


func clear_celebration() -> void:
	if _celebration_progress < 0.0:
		return
	_celebration_progress = -1.0
	_visibility_changed()
	_update_pose()


func perform_trick(kind: String) -> String:
	return str(GROWTH_ACTION_CAPTIONS.get(kind, "")) if perform_growth_action(kind) else ""

func is_manual_action_busy() -> bool:
	# Static reduced-motion poses have no remaining animation to wait for.
	return _gameplay_left > 0.0 or (_growth_action_manual and _idle_left > 0.0)

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		clear_gameplay_reaction()
		_reset_idle()
		reaction_left = 0.0
		_reaction_face = ""
		_attention = ""
	set_process(_celebration_progress < 0.0 and is_visible_in_tree() and (not reduced_motion or _gameplay_left > 0.0 or reaction_left > 0.0) and not _idle_paused)
	_update_pose()


func set_idle_paused(value: bool) -> void:
	if _idle_paused == value:
		return
	_idle_paused = value
	if value:
		clear_gameplay_reaction()
		reaction_left = 0.0
		_reaction_face = ""
		_attention = ""
	_reset_idle()
	_visibility_changed()
	_update_pose()


func note_activity() -> void:
	if _growth_action_manual:
		return
	var interrupted: bool = not _idle_action.is_empty()
	_reset_idle()
	if interrupted:
		_idle_time = 0.0
		_update_pose()


func set_proactive_allowed(value: bool) -> void:
	if _proactive_allowed == value:
		return
	_proactive_allowed = value
	note_activity()


func _reset_idle() -> void:
	_idle_action = ""
	_growth_action_manual = false
	_idle_left = 0.0
	_idle_wait = _idle_rng.randf_range(PROACTIVE_IDLE_SECONDS, PROACTIVE_IDLE_SECONDS + 3.0)


func _idle_duration() -> float:
	return float(GROWTH_ACTION_SECONDS.get(_idle_action, IDLE_SECONDS))

func _advance_idle(delta: float) -> void:
	if _growth_action_manual:
		_idle_left = maxf(0.0, _idle_left - delta)
		if is_zero_approx(_idle_left):
			_reset_idle()
		return
	# A resumed tab or a long engine frame must not catch up missed gestures.
	if delta > 0.5:
		_reset_idle()
		return
	if (not _proactive_allowed and _idle_action.is_empty()) or speaking or not _attention.is_empty() or not _gameplay_reaction.is_empty() or reaction_left > 0.0:
		return
	if not _idle_action.is_empty():
		_idle_left = maxf(0.0, _idle_left - delta)
		if is_zero_approx(_idle_left):
			_reset_idle()
		return
	_idle_wait -= delta
	if _idle_wait <= 0.0:
		var available: Array[String] = growth_actions()
		_idle_action = available[_idle_index % available.size()]
		_idle_index += 1
		_idle_left = _idle_duration()


func _update_pose(force_redraw: bool = true) -> void:
	var previous_pose: int = pose
	var previous_face: String = _face_name
	pose = 0
	if _celebration_progress >= 0.0:
		pose = 3
	elif not _gameplay_reaction.is_empty():
		pose = 3 if _gameplay_reaction == "happy" else 2
	elif speaking:
		pose = 1 if reduced_motion else 1 - int(_speech_time * 8.0) % 2
	elif reaction_left > 0.0 and _reaction == "happy":
		pose = 3
	elif not _idle_action.is_empty():
		pose = 3
	elif not reduced_motion and fmod(_idle_time, 4.6) > 4.42:
		pose = 2
	_face_name = _select_expression()
	if force_redraw or pose != previous_pose or _face_name != previous_face:
		queue_redraw()


func _select_expression() -> String:
	if _celebration_progress >= 0.0:
		if reduced_motion:
			return "proud"
		if _celebration_progress >= 1.0 and fmod(_celebration_rest, 4.6) > 4.42:
			return "blink"
		var seconds: float = _celebration_progress * CELEBRATION_SECONDS
		if seconds < 0.25:
			return "surprised"
		if seconds >= 1.23 and seconds < 1.39:
			return "wink"
		if seconds < 1.65:
			return "delighted"
		return "proud"
	if not _gameplay_reaction.is_empty():
		var correct: bool = _gameplay_reaction == "happy"
		if reduced_motion:
			return "delighted" if correct else "encourage"
		var progress: float = 1.0 - _gameplay_left / _gameplay_duration()
		if not correct:
			return "thinking" if progress < 0.42 else "encourage"
		if progress < 0.14:
			return "surprised"
		return HAPPY_EXPRESSIONS[_gameplay_variant] if progress < 0.82 else "proud"
	if speaking:
		return ""
	if reaction_left > 0.0:
		return _reaction_face
	if not _growth_stage.is_empty() and not _idle_action.is_empty():
		var progress: float = 1.0 if reduced_motion else 1.0 - _idle_left / _idle_duration()
		return str(_growth_action_pose(_idle_action, progress, reduced_motion).face)
	if not _attention.is_empty():
		return _attention
	if _proactive_allowed and not reduced_motion and _idle_action.is_empty():
		var quiet_time: float = fmod(_idle_time, 18.0)
		if quiet_time > 13.9 and quiet_time < 14.65:
			return "sleepy"
	return ""


func _process(delta: float) -> void:
	if _celebration_progress >= 0.0 or _idle_paused or not is_visible_in_tree():
		return
	var was_animating: bool = _has_continuous_pose()
	if reaction_left > 0.0:
		reaction_left = maxf(0.0, reaction_left - delta)
		if is_zero_approx(reaction_left):
			_reaction_face = ""
			_reaction = ""
			_update_pose()
	if _gameplay_left > 0.0:
		_gameplay_left = maxf(0.0, _gameplay_left - delta)
		if is_zero_approx(_gameplay_left):
			var correct: bool = _gameplay_reaction == "happy"
			_gameplay_reaction = ""
			_reset_idle()
			if reduced_motion:
				set_process(reaction_left > 0.0)
			_update_pose(true)
			gameplay_reaction_finished.emit(correct)
	if reduced_motion:
		if is_zero_approx(_gameplay_left) and is_zero_approx(reaction_left):
			set_process(false)
		return
	_idle_time += delta
	_speech_time += delta
	_advance_idle(delta)
	# Idle and speech use discrete sheet frames. Keep their draw commands until
	# the pose changes, while every continuous motion and its final frame redraw.
	_update_pose(was_animating or _has_continuous_pose())


func _has_continuous_pose() -> bool:
	return reaction_left > 0.0 or not _gameplay_reaction.is_empty() or not _idle_action.is_empty()

func _draw() -> void:
	var edge: float = 54.0 if compact else minf(size.x, size.y)
	var origin := Vector2(0, -2) if compact else (size - Vector2.ONE * edge) * 0.5
	if _celebration_progress >= 0.0:
		_draw_celebration(origin, edge)
		return
	if not _gameplay_reaction.is_empty():
		_draw_gameplay_reaction(origin, edge)
		return
	if not _growth_stage.is_empty() and not speaking and not _idle_action.is_empty():
		_draw_growth_action(origin, edge)
		return
	var wave: float = sin((1.0 - reaction_left / 0.65) * PI) if reaction_left > 0.0 and not reduced_motion else 0.0
	var turn: float = (-0.07 if _reaction == "curious" else 0.07) * wave
	var bounce: float = -wave * edge * 0.07
	var stretch := Vector2(1 + wave * 0.04, 1 - wave * 0.03)
	var center := origin + Vector2(edge * 0.5, edge * 0.75)
	draw_set_transform(center + Vector2(0, bounce), turn, stretch)
	var outfit: Texture2D = _outfit_sheet if _outfit_sheet != null else SHEET
	var frame: int = pose
	if not _face_name.is_empty() and _expression_sheet != null:
		outfit = _expression_sheet
		frame = EXPRESSION_NAMES.find(_face_name)
	var source_edge: float = outfit.get_height()
	draw_texture_rect_region(outfit, Rect2(origin - center, Vector2.ONE * edge),
		Rect2(Vector2(float(frame) * source_edge, 0), Vector2.ONE * source_edge))
	draw_set_transform(Vector2.ZERO)
	if speaking:
		for index in range(2):
			draw_arc(origin + Vector2(edge * 0.8, edge * 0.55), edge * (0.08 + index * 0.06),
				-0.75, 0.75, 12, accent, 1.6, true)

static func _growth_action_pose(kind: String, progress: float, reduced: bool = false) -> Dictionary:
	var parts: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	if reduced:
		return {"parts": parts, "face": "delighted"}
	var p: float = clampf(progress, 0.0, 1.0)
	var envelope: float = smoothstep(0.0, 0.14, p) * (1.0 - smoothstep(0.82, 1.0, p))
	var beat: float = sin(p * PI * 4.0)
	var face: String = "proud"
	match kind:
		"wave":
			parts[2].z = (79.0 + sin(p * PI * 6.0) * 15.0) * envelope
			parts[1].z = 4.0 * envelope
			face = "wink" if p > 0.45 and p < 0.58 else "encourage"
		"look":
			var direction: float = sin(p * TAU)
			parts[1] = Vector3(direction * 2.8, -0.7, direction * 8.0) * envelope
			parts[0].z = direction * 2.0 * envelope
			face = "thinking"
		"high-five":
			parts[3] = Vector3(0.0, -1.2, -82.0) * envelope
			parts[1] = Vector3(2.0, -1.2, -4.0) * envelope
			parts[0].z = 2.0 * envelope
			face = "delighted"
		"peekaboo":
			var hiding: float = smoothstep(0.0, 0.16, p) * (1.0 - smoothstep(0.43, 0.59, p))
			parts[2].z = 126.0 * hiding + 58.0 * envelope * (1.0 - hiding)
			parts[3].z = -parts[2].z
			parts[1].y = 2.5 * hiding
			face = "blink" if p < 0.48 else "surprised" if p < 0.63 else "delighted"
		"stretch":
			parts[2].z = 66.0 * envelope
			parts[3].z = -66.0 * envelope
			parts[0].y = -2.0 * envelope
			parts[1].y = -3.5 * envelope
			face = "blink" if p < 0.5 else "proud"
		"hop":
			var jump: float = maxf(0.0, sin((p - 0.18) / 0.47 * PI)) if p > 0.18 and p < 0.65 else 0.0
			var crouch: float = sin(p / 0.18 * PI) * 4.0 if p < 0.18 else 0.0
			var settle: float = sin((p - 0.65) / 0.2 * PI) * 3.0 if p > 0.65 and p < 0.85 else 0.0
			for index in range(parts.size()):
				parts[index].y = -17.0 * jump
			parts[0].y += crouch + settle
			parts[1].y += crouch * 1.3 + settle * 1.5
			parts[2].z = 82.0 * envelope
			parts[3].z = -82.0 * envelope
			parts[4].z = -12.0 * jump
			parts[5].z = 12.0 * jump
			face = "surprised" if p < 0.18 else "delighted"
		"flutter":
			parts[2].z = (76.0 + sin(p * PI * 15.0) * 18.0) * envelope
			parts[3].z = -parts[2].z
			parts[1].z = 4.0 * envelope
			face = "delighted"
		"dance-sway", "dance-wave", "dance-hop":
			var left: float = maxf(0.0, beat) * envelope
			var right: float = maxf(0.0, -beat) * envelope
			var sway: bool = kind == "dance-sway"
			var hop: bool = kind == "dance-hop"
			var lift: float = absf(sin(p * PI * 3.0)) * 12.0 * envelope if hop else absf(beat) * 1.6 * envelope
			var hips: float = beat * (6.0 if sway else 3.0) * envelope
			parts[0] = Vector3(hips, -lift, (-5.0 if sway else 3.0) * beat * envelope)
			parts[1] = Vector3(hips * 0.5, -lift, (4.0 if sway else -2.0) * beat * envelope)
			parts[2] = Vector3(hips, -lift, 85.0 * envelope if hop else 35.0 * envelope + 32.0 * left if sway else 96.0 * left)
			parts[3] = Vector3(hips, -lift, -85.0 * envelope if hop else -35.0 * envelope - 32.0 * right if sway else -96.0 * right)
			parts[4] = Vector3(hips * 0.2, -lift if hop else -4.0 * right, -7.0 * left)
			parts[5] = Vector3(hips * 0.2, -lift if hop else -4.0 * left, 7.0 * right)
			face = "blink" if p > 0.45 and p < 0.5 else "proud" if p > 0.83 else "delighted"
	return {"parts": parts, "face": face}


func _draw_growth_action(origin: Vector2, edge: float) -> void:
	var progress: float = 1.0 if reduced_motion else 1.0 - _idle_left / _idle_duration()
	var action: Dictionary = _growth_action_pose(_idle_action, progress, reduced_motion)
	var parts: Array = action.parts
	# Add headroom gradually around the planted baseline; no size jump at rest.
	var envelope: float = 0.0 if reduced_motion else smoothstep(0.0, 0.14, progress) * (1.0 - smoothstep(0.82, 1.0, progress))
	var inset: float = 1.0 - 0.18 * envelope
	var unit: float = edge * inset / 120.0
	var base_origin := origin + Vector2(edge * (1.0 - inset) * 0.5, edge * (1.0 - inset) * 112.0 / 120.0)
	var base := Transform2D(Vector2(unit, 0), Vector2(0, unit), base_origin)
	var lift: float = maxf(0.0, -float(parts[0].y)) / 23.0
	draw_set_transform(base_origin + Vector2(61, 112) * unit, 0.0,
		Vector2(39.0 - lift * 9.0, 5.0) * unit)
	draw_circle(Vector2.ZERO, 1.0, Color(0.396, 0.439, 0.541, 0.14 - lift * 0.05))
	var outfit: Texture2D = _outfit_dance_sheet if _outfit_dance_sheet != null else DANCE_SHEET
	var source_edge: float = outfit.get_height()
	for index in [4, 5, 0, 1, 2, 3]:
		var part: Vector3 = parts[index]
		var transform: Transform2D = _gameplay_part_transform(index, Vector2(part.x, part.y), deg_to_rad(part.z))
		draw_set_transform_matrix(base * transform)
		_draw_articulated_part(outfit, index, Rect2(Vector2.ZERO, Vector2(120, 120)), source_edge)
	draw_set_transform(Vector2.ZERO)


static func _gameplay_arc(progress: float, start: float, finish: float) -> float:
	return sin(PI * clampf((progress - start) / (finish - start), 0.0, 1.0))


static func _gameplay_transforms(correct: bool, progress: float, reduced: bool = false) -> Array[Transform2D]:
	var time: float = clampf(progress, 0.0, 1.0)
	var envelope: float = 1.0 if reduced else smoothstep(0.0, 0.055, time) * (1.0 - smoothstep(0.84, 1.0, time))
	var hips := Vector2.ZERO
	var head := Vector2.ZERO
	var tilt := 0.0
	var head_tilt := 0.0
	var left_wing := 0.0
	var right_wing := 0.0
	var feet_y := 0.0
	var feet_turn := 0.0
	var body_scale := Vector2.ONE
	if correct:
		var first: float = 0.0 if reduced else _gameplay_arc(time, 0.10, 0.52)
		var second: float = 0.0 if reduced else _gameplay_arc(time, 0.55, 0.84)
		var lift: float = first * 24.0 + second * 14.0
		var crouch: float = 0.0 if reduced else _gameplay_arc(time, 0.0, 0.10) + _gameplay_arc(time, 0.48, 0.57) * 0.9 + _gameplay_arc(time, 0.81, 0.94) * 0.6
		var airborne: float = maxf(first, second)
		hips = Vector2(0.0 if reduced else sin(time * TAU * 2.0) * 2.5 * envelope, crouch * 5.0 - lift)
		tilt = 0.0 if reduced else sin(time * TAU * 2.0) * 0.085 * envelope
		head = Vector2(hips.x * 0.65, hips.y - airborne * 2.0)
		head_tilt = -tilt * 0.8
		left_wing = deg_to_rad(78.0) if reduced else deg_to_rad(20.0 + airborne * (78.0 + sin(time * TAU * 4.0) * 15.0)) * envelope
		right_wing = -left_wing
		feet_y = -lift
		feet_turn = (0.1 + airborne * 0.32) * envelope
		body_scale = Vector2(1.0 + crouch * 0.12 - airborne * 0.035, 1.0 - crouch * 0.14 + airborne * 0.055)
	else:
		var slump: float = 1.0 if reduced else smoothstep(0.0, 0.16, time) * (1.0 - smoothstep(0.78, 1.0, time))
		var sigh: float = 0.0 if reduced else _gameplay_arc(time, 0.28, 0.72) * 1.8
		hips = Vector2(-2.0, 6.0) * slump
		tilt = -0.065 * slump
		head = Vector2(-4.0, 10.0 + sigh) * slump
		head_tilt = -0.19 * slump
		left_wing = -0.48 * slump
		right_wing = 0.48 * slump
		feet_turn = -0.065 * slump
		body_scale = Vector2(1.0 + slump * 0.045, 1.0 - slump * 0.08)
	return [
		_gameplay_part_transform(0, hips, tilt, body_scale),
		_gameplay_part_transform(1, head, head_tilt),
		_gameplay_part_transform(2, hips, left_wing + tilt),
		_gameplay_part_transform(3, hips, right_wing + tilt),
		_gameplay_part_transform(4, Vector2(hips.x * 0.3, feet_y), -feet_turn),
		_gameplay_part_transform(5, Vector2(hips.x * 0.3, feet_y), feet_turn),
	]


static func _gameplay_part_transform(index: int, translation: Vector2, angle: float, stretch: Vector2 = Vector2.ONE) -> Transform2D:
	var pivot: Vector2 = GAMEPLAY_PIVOTS[index]
	var transform := Transform2D(angle, stretch, 0.0, Vector2.ZERO)
	transform.origin = pivot + translation - transform * pivot
	return transform


static func _celebration_transforms(progress: float, reduced: bool = false, rest_seconds: float = 0.0) -> Array[Transform2D]:
	var seconds: float = CELEBRATION_SECONDS if reduced else clampf(progress, 0.0, 1.0) * CELEBRATION_SECONDS
	var first: String = "present"
	var last: String = "present"
	var blend: float = 1.0
	for index in range(1, CELEBRATION_BEATS.size()):
		var end: float = float(CELEBRATION_BEATS[index][0])
		if seconds <= end:
			var start: float = float(CELEBRATION_BEATS[index - 1][0])
			first = str(CELEBRATION_BEATS[index - 1][1])
			last = str(CELEBRATION_BEATS[index][1])
			blend = smoothstep(0.0, 1.0, (seconds - start) / (end - start))
			break
	var result: Array[Transform2D] = []
	for index in range(6):
		var source: Vector3 = CELEBRATION_POSES[first][index]
		var target: Vector3 = CELEBRATION_POSES[last][index]
		var part: Vector3 = source.lerp(target, blend)
		if progress >= 1.0 and not reduced and index < 4:
			part.y += sin(rest_seconds * TAU / 3.6) * (0.32 if index == 1 else 0.22)
		var stretch := Vector2.ONE
		if index == 0:
			var start_scale := Vector2(1.08, 0.91) if first in ["crouch", "land"] else Vector2.ONE
			var end_scale := Vector2(1.08, 0.91) if last in ["crouch", "land"] else Vector2.ONE
			stretch = start_scale.lerp(end_scale, blend)
		result.append(_gameplay_part_transform(index, Vector2(part.x, part.y), deg_to_rad(part.z), stretch))
	return result


func _draw_celebration(origin: Vector2, edge: float) -> void:
	var transforms: Array[Transform2D] = _celebration_transforms(_celebration_progress, reduced_motion, _celebration_rest)
	var unit: float = edge * 0.82 / 120.0
	var base_origin := origin + Vector2(edge * 0.09, edge * 0.18 * 112.0 / 120.0)
	var base := Transform2D(Vector2(unit, 0), Vector2(0, unit), base_origin)
	var lift: float = maxf(0.0, 98.0 - (transforms[0] * GAMEPLAY_PIVOTS[0]).y) / 23.0
	draw_set_transform(base_origin + Vector2(61, 112) * unit, 0.0,
		Vector2(37.0 - lift * 10.0, 4.2 - lift) * unit)
	draw_circle(Vector2.ZERO, 1.0, Color(0.396, 0.439, 0.541, 0.15 - lift * 0.06))
	var outfit: Texture2D = _outfit_dance_sheet if _outfit_dance_sheet != null else DANCE_SHEET
	var source_edge: float = outfit.get_height()
	for index in [4, 5, 0, 1, 2, 3]:
		draw_set_transform_matrix(base * transforms[index])
		_draw_articulated_part(outfit, index, Rect2(Vector2.ZERO, Vector2(120, 120)), source_edge)
	draw_set_transform(Vector2.ZERO)


func _draw_gameplay_reaction(origin: Vector2, edge: float) -> void:
	var correct: bool = _gameplay_reaction == "happy"
	var progress: float = 0.45 if reduced_motion else 1.0 - _gameplay_left / _gameplay_duration()
	var envelope: float = 1.0 if reduced_motion else smoothstep(0.0, 0.055, progress) * (1.0 - smoothstep(0.84, 1.0, progress))
	var transforms: Array[Transform2D] = _gameplay_transforms(correct, progress, reduced_motion)
	# Inset around the planted baseline as the wings open. Even the leap apex
	# stays inside a 52-pixel header slot without moving its input rectangle.
	var inset: float = 1.0 - (0.20 if correct else 0.045) * envelope
	var unit: float = edge / 120.0 * inset
	var base_origin := origin + Vector2(edge * (1.0 - inset) * 0.5, edge * (1.0 - inset) * 112.0 / 120.0)
	var base := Transform2D(Vector2(unit, 0), Vector2(0, unit), base_origin)
	var airborne: float = clampf((98.0 - (transforms[0] * GAMEPLAY_PIVOTS[0]).y) / 24.0, 0.0, 1.0)
	draw_set_transform(origin + Vector2(edge * 0.51, edge * 0.94), 0.0,
		Vector2(edge * (0.31 - airborne * 0.095), edge * 0.036))
	draw_circle(Vector2.ZERO, 1.0, Color(0.396, 0.439, 0.541, 0.19 - airborne * 0.09))
	var outfit: Texture2D = _outfit_dance_sheet if _outfit_dance_sheet != null else DANCE_SHEET
	var source_edge: float = outfit.get_height()
	for index in [4, 5, 0, 1, 2, 3]:
		draw_set_transform_matrix(base * transforms[index])
		_draw_articulated_part(outfit, index, Rect2(Vector2.ZERO, Vector2(120, 120)), source_edge)
	draw_set_transform_matrix(base)
	if correct:
		var radius: float = 4.0 * envelope
		if radius > 0.01:
			# Triangulate at unit scale; tiny absolute-coordinate stars lose precision.
			var rays := PackedVector2Array()
			for ray in range(8):
				rays.append(Vector2.from_angle(ray * PI / 4.0) * (1.0 if ray % 2 == 0 else 0.32))
			for index in range(3):
				var point := Vector2(13 + index * 47, 34 - (index % 2) * 21)
				draw_set_transform_matrix(base * Transform2D(Vector2(radius, 0), Vector2(0, radius), point))
				draw_colored_polygon(rays, Color(Color("#f1b638"), envelope))
	draw_set_transform(Vector2.ZERO)


func _draw_articulated_part(outfit: Texture2D, index: int, destination: Rect2, source_edge: float) -> void:
	# Swap the whole authored head, including its wardrobe, under the same joint.
	# Face masks would paint over the transparent space helmet and hat brim.
	if index == 1 and not _face_name.is_empty() and _expression_heads != null:
		var head_edge: float = _expression_heads.get_height()
		draw_texture_rect_region(_expression_heads, destination,
			Rect2(Vector2(EXPRESSION_NAMES.find(_face_name) * head_edge, 0), Vector2.ONE * head_edge))
	else:
		draw_texture_rect_region(outfit, destination,
			Rect2(Vector2(index * source_edge, 0), Vector2.ONE * source_edge))

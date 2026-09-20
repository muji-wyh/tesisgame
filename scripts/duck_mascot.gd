extends Button

const SHEET = preload("res://assets/images/mascots/pip.svg")
const IDLE_SHEET = preload("res://assets/images/mascots/pip-idle-actions.svg")
const DANCE_SHEET = preload("res://assets/images/mascots/pip-dance-parts.svg")
const Outfits = preload("res://scripts/pip_outfits.gd")
const LoadingMoves = preload("res://scripts/pip_loading_moves.gd")
const Style = preload("res://scripts/ui_style.gd")
const IDLE_ACTIONS := ["wave", "high-five", "peekaboo", "look", "stretch", "preen", "hop"]
const IDLE_DANCES := ["dance-wave", "dance-sway", "dance-hop"]
const IDLE_SECONDS: float = 1.8
const DANCE_SECONDS: float = 3.2
const PROACTIVE_IDLE_SECONDS: float = 6.0
const TRICK_SECONDS: float = 1.8
const ROOM_REACTION_SECONDS: float = 1.1
const SOCIAL_TRICKS := ["high-five", "peekaboo", "flutter"]
const TRICK_CAPTIONS := {
	"dance": "Pip's happy dance!", "snack": "Crunch! A carrot for Pip!", "bubbles": "Pop! Bubble party!",
	"high-five": "High five, friend!", "peekaboo": "Peekaboo! Here is Pip!", "flutter": "Flutter, flutter! Hello!"
}

var speaking: bool = false
var reduced_motion: bool = false
var compact: bool = false
var home_playground: bool = false
var pose: int = 0
var reaction_left: float = 0.0
var accent: Color = Style.GOOD
var theme_id: String = "spring"
var _outfit_sheet: Texture2D
var _outfit_idle_sheet: Texture2D
var _outfit_dance_sheet: Texture2D
var _reaction: String = ""
var _idle_time: float = 0.0
var _speech_time: float = 0.0
var _trick: String = ""
var _trick_left: float = 0.0
var _idle_action: String = ""
var _idle_left: float = 0.0
var _idle_wait: float = PROACTIVE_IDLE_SECONDS
var _idle_index: int = 0
var _idle_paused: bool = false
var _proactive_allowed: bool = false
var _idle_rng := RandomNumberGenerator.new()
var _room_motion: String = ""
var _room_direction: float = 1.0
var _room_step: float = 0.0
var _room_reaction: String = ""
var _room_reaction_left: float = 0.0


func _ready() -> void:
	_idle_rng.randomize()
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
	if theme_id == chosen and _outfit_sheet != null:
		return
	var sheets: Array[Texture2D] = Outfits.load_sheets(chosen)
	theme_id = chosen
	_outfit_sheet = sheets[0]
	_outfit_idle_sheet = sheets[1]
	_outfit_dance_sheet = sheets[2]
	# A wardrobe change is visual only: preserve speech, gestures and quiet timing.
	queue_redraw()


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
	if (not kind in ["pet", "poke", "catch"] and not kind in SOCIAL_TRICKS and not kind in LoadingMoves.REACTIONS) or _idle_paused or not is_visible_in_tree():
		return
	_reset_idle()
	_room_motion = ""
	_room_step = 0.0
	_room_reaction = kind
	_room_reaction_left = 0.0 if reduced_motion else _room_reaction_duration()
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


func note_activity() -> void:
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


func set_home_playground(value: bool) -> void:
	if home_playground == value:
		return
	home_playground = value
	_reset_idle()
	queue_redraw()


func _room_reaction_duration() -> float:
	return LoadingMoves.duration(_room_reaction) if _room_reaction in LoadingMoves.REACTIONS else ROOM_REACTION_SECONDS


func _reset_idle() -> void:
	_idle_action = ""
	_idle_left = 0.0
	_idle_wait = 0.35 if home_playground else _idle_rng.randf_range(PROACTIVE_IDLE_SECONDS, PROACTIVE_IDLE_SECONDS + 3.0)


func _idle_duration() -> float:
	if _idle_action == "home-dance": return LoadingMoves.DANCE_SECONDS
	return DANCE_SECONDS if _idle_action in IDLE_DANCES else IDLE_SECONDS


func _advance_idle(delta: float) -> void:
	# A resumed tab or a long engine frame must not catch up missed gestures.
	if delta > 0.5:
		_reset_idle()
		return
	if not _proactive_allowed or speaking or reaction_left > 0.0 or not _trick.is_empty() or not _room_motion.is_empty() or not _room_reaction.is_empty():
		return
	if home_playground:
		if _idle_action == "home-dance":
			_idle_left = fposmod(_idle_left - delta, LoadingMoves.DANCE_SECONDS)
		else:
			_idle_wait -= delta
			if _idle_wait <= 0.0:
				_idle_action = "home-dance"
				_idle_left = LoadingMoves.DANCE_SECONDS
		return
	if not _idle_action.is_empty():
		_idle_left = maxf(0.0, _idle_left - delta)
		if is_zero_approx(_idle_left):
			_reset_idle()
		return
	_idle_wait -= delta
	if _idle_wait <= 0.0:
		# Lead with a dance, then alternate full routines with smaller greetings.
		var cycle: int = int(_idle_index / 2)
		_idle_action = IDLE_DANCES[cycle % IDLE_DANCES.size()] if _idle_index % 2 == 0 else IDLE_ACTIONS[cycle % IDLE_ACTIONS.size()]
		_idle_index += 1
		_idle_left = _idle_duration()


func _update_pose() -> void:
	pose = 0
	if speaking:
		pose = 1 if reduced_motion else 1 - int(_speech_time * 8.0) % 2
	elif not _room_reaction.is_empty():
		if _room_reaction in SOCIAL_TRICKS:
			pose = _trick_pose(_room_reaction, 0.45 if reduced_motion else 1.0 - _room_reaction_left / ROOM_REACTION_SECONDS)
		else:
			pose = 2 if _room_reaction == "pet" else 1 if _room_reaction == "poke" else 3
	elif not _room_motion.is_empty():
		pose = 3 if _room_motion == "run" else 0
	elif not _trick.is_empty():
		pose = _trick_pose(_trick, 0.45 if reduced_motion else 1.0 - _trick_left / TRICK_SECONDS)
	elif reaction_left > 0.0 and _reaction == "happy":
		pose = 3
	elif _idle_action in ["high-five", "peekaboo"]:
		pose = _trick_pose(_idle_action, 1.0 - _idle_left / IDLE_SECONDS)
	elif _idle_action == "wave" or _idle_action == "hop":
		pose = 3 if sin((1.0 - _idle_left / IDLE_SECONDS) * TAU * 2.0) > 0.0 else 0
	elif not reduced_motion and fmod(_idle_time, 4.6) > 4.42:
		pose = 2
	queue_redraw()


func _trick_pose(kind: String, progress: float) -> int:
	if kind == "peekaboo":
		return 2 if progress < 0.55 else 3
	return 3 if kind in ["dance", "high-five", "flutter"] else 1


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
	# Explicit tap feedback wins even while a previous word finishes speaking.
	if _room_reaction in LoadingMoves.REACTIONS or (not speaking and _idle_action == "home-dance"):
		_draw_loading_moves(origin, edge)
		return
	var wave: float = sin((1.0 - reaction_left / 0.65) * PI) if reaction_left > 0.0 else 0.0
	var turn: float = (-0.07 if _reaction == "curious" else 0.07) * wave
	var trick_progress: float = 0.45 if reduced_motion else 1.0 - _trick_left / TRICK_SECONDS
	var bounce: float = -wave * edge * 0.07
	var stretch := Vector2(1 + wave * 0.04, 1 - wave * 0.03)
	var sheet: Texture2D = SHEET
	var frame: int = pose
	var social_action: String = _trick
	var social_progress: float = trick_progress
	if not _idle_action.is_empty():
		var progress: float = 1.0 - _idle_left / _idle_duration()
		var envelope: float = sin(progress * PI)
		if _idle_action in ["high-five", "peekaboo"]:
			social_action = _idle_action
			social_progress = progress
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
	if _room_reaction in SOCIAL_TRICKS:
		social_action = _room_reaction
		social_progress = 0.45 if reduced_motion else 1.0 - _room_reaction_left / ROOM_REACTION_SECONDS
	if _trick == "dance" and not reduced_motion:
		turn += sin(trick_progress * TAU * 3.0) * 0.13
		bounce -= absf(sin(trick_progress * TAU * 3.0)) * edge * 0.055
	elif _trick == "snack" and not reduced_motion:
		turn += sin(trick_progress * TAU * 2.0) * 0.045
	elif social_action == "high-five":
		var reach: float = 0.7 if reduced_motion else sin(social_progress * PI)
		turn = -reach * 0.085
		stretch = Vector2(1.0, 1.0 + reach * 0.035)
	elif social_action == "peekaboo":
		var peek: float = 0.7 if reduced_motion else sin(social_progress * PI)
		turn = (-0.065 if social_progress < 0.55 else 0.045) * peek
		bounce = edge * 0.025 * peek
	elif social_action == "flutter":
		var flap: float = 0.7 if reduced_motion else sin(social_progress * TAU * 4.0)
		turn = 0.0 if reduced_motion else flap * 0.045
		bounce = 0.0 if reduced_motion else -absf(flap) * edge * 0.06
		stretch = Vector2(1.0 + absf(flap) * 0.035, 1.0 - absf(flap) * 0.025)
		if not speaking and flap > 0.0:
			sheet = IDLE_SHEET
			frame = 2
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
	var dancing: bool = not reduced_motion and not speaking and (_idle_action in IDLE_DANCES or _trick == "dance")
	if dancing:
		var routine: String = _idle_action if _idle_action in IDLE_DANCES else "dance-wave"
		var progress: float = 1.0 - _idle_left / DANCE_SECONDS if _idle_action in IDLE_DANCES else trick_progress
		_draw_dance(origin, edge, routine, progress)
	else:
		var center := origin + Vector2(edge * 0.5, edge * 0.75)
		draw_set_transform(center + Vector2(0, bounce), turn, stretch)
		var outfit: Texture2D = _outfit_idle_sheet if sheet == IDLE_SHEET else _outfit_sheet
		if outfit == null:
			outfit = sheet
		var source_edge: float = outfit.get_height()
		draw_texture_rect_region(outfit, Rect2(origin - center, Vector2.ONE * edge),
			Rect2(Vector2(float(frame) * source_edge, 0), Vector2.ONE * source_edge))
		draw_set_transform(Vector2.ZERO)
	_draw_room_effects(origin, edge)
	if not _trick.is_empty():
		_draw_trick(origin, edge, trick_progress)
	elif _idle_action in ["high-five", "peekaboo"]:
		_draw_trick(origin, edge, social_progress, _idle_action)
	if speaking:
		for index in range(2):
			draw_arc(origin + Vector2(edge * 0.8, edge * 0.55), edge * (0.08 + index * 0.06),
				-0.75, 0.75, 12, accent, 1.6, true)


func _draw_loading_moves(origin: Vector2, edge: float) -> void:
	var reacting: bool = _room_reaction in LoadingMoves.REACTIONS
	var progress: float = 0.45 if reduced_motion else 1.0 - _room_reaction_left / _room_reaction_duration()
	var transforms: Array[Transform2D] = LoadingMoves.reaction(_room_reaction, progress, reduced_motion) if reacting else LoadingMoves.dance(LoadingMoves.DANCE_SECONDS - _idle_left)
	# Keep planted toes at the ordinary mascot baseline. The existing room slot
	# has headroom for a jump without resizing or moving its touch target.
	var unit: float = edge / 120.0
	var base := Transform2D(Vector2(unit, 0), Vector2(0, unit), origin)
	var outfit: Texture2D = _outfit_dance_sheet if _outfit_dance_sheet != null else DANCE_SHEET
	var source_edge: float = outfit.get_height()
	draw_set_transform(origin + Vector2(61, 112) * unit, 0.0, Vector2(39, 5) * unit)
	draw_circle(Vector2.ZERO, 1.0, Color(0.396, 0.439, 0.541, 0.14))
	for index in [4, 5, 0, 1, 2, 3]:
		draw_set_transform_matrix(base * transforms[index])
		draw_texture_rect_region(outfit, Rect2(Vector2.ZERO, Vector2(120, 120)),
			Rect2(Vector2(index * source_edge, 0), Vector2.ONE * source_edge))
		if index == 1 and reacting:
			if _room_reaction == "shy":
				for cheek in [Vector2(31, 62), Vector2(91, 59)]:
					draw_set_transform_matrix(base * transforms[1] * Transform2D(Vector2(8, 0), Vector2(0, 5), cheek))
					draw_circle(Vector2.ZERO, 1.0, Color(0.93, 0.55, 0.61, 0.8))
			elif _room_reaction == "bonk":
				# Keep the stars inside the floor even when Pip stands at its edge.
				for center in [Vector2(20, 20), Vector2(94, 12)]:
					var points := PackedVector2Array()
					for ray in range(8):
						points.append(center + Vector2.from_angle(ray * PI / 4.0) * (7.0 if ray % 2 == 0 else 2.5))
					draw_colored_polygon(points, Color("#ffd979"))
	draw_set_transform(Vector2.ZERO)


func _draw_dance(origin: Vector2, edge: float, routine: String, progress: float) -> void:
	# Art moves within the original button; the hit area never follows a limb.
	var envelope: float = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress))
	var beat: float = sin(progress * TAU * 2.0)
	var left: float = maxf(0.0, beat) * envelope
	var right: float = maxf(0.0, -beat) * envelope
	var hips := Vector2(beat * 3.0, -absf(beat) * 2.0) * envelope
	var tilt: float = beat * 0.045 * envelope
	var head_tilt: float = -tilt * 0.7
	var left_wing: float = left * 1.9
	var right_wing: float = -right * 1.9
	var left_step: float = right * 3.0
	var right_step: float = left * 3.0
	if routine == "dance-sway":
		hips = Vector2(beat * 8.0, -absf(beat) * 1.5) * envelope
		tilt = -beat * 0.09 * envelope
		head_tilt = beat * 0.08 * envelope
		left_wing = (0.55 + left * 0.5) * envelope
		right_wing = -(0.55 + right * 0.5) * envelope
		left_step = left * 4.0
		right_step = right * 4.0
	elif routine == "dance-hop":
		var hop: float = absf(sin(progress * PI * 3.0)) * envelope
		hips = Vector2(0, -hop * 6.0)
		tilt = beat * 0.035 * envelope
		head_tilt = -tilt
		left_wing = hop * 1.65
		right_wing = -left_wing
		left_step = hop * 2.0
		right_step = left_step
	# Ease the small inset in and out, leaving breathing room for raised wings.
	var unit: float = edge / 120.0 * (1.0 - 0.035 * envelope)
	var base := origin + Vector2(edge - unit * 120.0, edge - unit * 120.0) * 0.5
	draw_set_transform(base + Vector2(61, 112) * unit, 0.0, Vector2(39, 5) * unit)
	draw_circle(Vector2.ZERO, 1.0, Color(0.396, 0.439, 0.541, 0.14))
	_draw_dance_part(4, base, unit, Vector2(40, 103), Vector2(hips.x * 0.3, hips.y - left_step), left * 0.16)
	_draw_dance_part(5, base, unit, Vector2(80, 103), Vector2(hips.x * 0.3, hips.y - right_step), -right * 0.16)
	_draw_dance_part(0, base, unit, Vector2(61, 98), hips, tilt)
	_draw_dance_part(1, base, unit, Vector2(61, 72), Vector2(hips.x * 0.5, hips.y), head_tilt)
	_draw_dance_part(2, base, unit, Vector2(33, 78), hips, left_wing + tilt)
	_draw_dance_part(3, base, unit, Vector2(88, 78), hips, right_wing + tilt)
	draw_set_transform(Vector2.ZERO)


func _draw_dance_part(index: int, origin: Vector2, unit: float, joint: Vector2, offset: Vector2, angle: float) -> void:
	draw_set_transform(origin + (joint + offset) * unit, angle, Vector2.ONE * unit)
	var outfit: Texture2D = _outfit_dance_sheet if _outfit_dance_sheet != null else DANCE_SHEET
	var source_edge: float = outfit.get_height()
	draw_texture_rect_region(outfit, Rect2(-joint, Vector2(120, 120)),
		Rect2(Vector2(index * source_edge, 0), Vector2.ONE * source_edge))


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
	if _room_reaction in SOCIAL_TRICKS:
		_draw_trick(origin, edge, progress, _room_reaction)
		return
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


func _draw_trick(origin: Vector2, edge: float, progress: float, kind: String = "") -> void:
	if kind.is_empty():
		kind = _trick
	var fade: float = 1.0 if reduced_motion else clampf((1.0 - progress) * 5.0, 0.0, 1.0)
	if kind == "dance":
		for index in range(3):
			var beat: float = 0.0 if reduced_motion else sin(progress * TAU * 3.0 + index)
			var point := origin + Vector2(edge * (0.16 + index * 0.32), edge * (0.15 - beat * 0.04))
			var tint := Color(accent, fade)
			draw_circle(point, edge * 0.025, tint)
			draw_line(point, point + Vector2(0, -edge * 0.07), tint, 2.0, true)
			draw_line(point + Vector2(0, -edge * 0.07), point + Vector2(edge * 0.035, -edge * 0.05), tint, 2.0, true)
	elif kind == "snack":
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
	elif kind == "bubbles":
		for index in range(6):
			var rise: float = float(index % 3) / 3.0 if reduced_motion else fmod(progress * 1.4 + index * 0.17, 1.0)
			var radius: float = edge * (0.04 + float(index % 3) * 0.012)
			var point := origin + Vector2(edge * (0.11 if index % 2 == 0 else 0.89), edge * (0.83 - rise * 0.65))
			var alpha: float = fade if reduced_motion else fade * sin(rise * PI)
			draw_circle(point, radius, Color(0.65, 0.86, 1.0, alpha * 0.24))
			draw_arc(point, radius, 0.0, TAU, 20, Color(accent.lightened(0.3), alpha), 1.8, true)
			draw_circle(point + Vector2(-radius * 0.3, -radius * 0.3), maxf(1.0, radius * 0.18), Color(1, 1, 1, alpha))
	elif kind == "high-five":
		var point := origin + Vector2(edge * 0.84, edge * 0.36)
		var reach: float = 0.7 if reduced_motion else sin(progress * PI)
		var tint := Color(accent, fade)
		draw_arc(point, edge * (0.07 + reach * 0.035), -1.6, 0.7, 16, tint, maxf(1.8, edge * 0.016), true)
		for index in range(3):
			var direction := Vector2.from_angle(-1.45 + index * 0.85)
			draw_line(point + direction * edge * 0.13, point + direction * edge * (0.15 + reach * 0.02),
				tint, maxf(1.8, edge * 0.017), true)
	elif kind == "peekaboo":
		var cover: float = 0.85 if reduced_motion else 1.0 - smoothstep(0.25, 0.6, progress)
		for side in [-1, 1]:
			var point := origin + Vector2(edge * (0.51 + side * (0.15 + (1.0 - cover) * 0.13)),
				edge * (0.41 + (1.0 - cover) * 0.28))
			draw_set_transform(point, side * (0.3 + (1.0 - cover) * 0.45), Vector2(1.0, 0.58))
			draw_circle(Vector2.ZERO, edge * 0.155, Color(Color("#ffde7f"), fade))
			draw_arc(Vector2.ZERO, edge * 0.155, 0.0, TAU, 24,
				Color(Color("#785d3e"), fade), maxf(1.5, edge * 0.018), true)
		draw_set_transform(Vector2.ZERO)
	elif kind == "flutter":
		for side in [-1, 1]:
			for index in range(2):
				var flutter: float = 0.5 if reduced_motion else absf(sin(progress * TAU * 4.0))
				var point := origin + Vector2(edge * (0.5 + side * (0.36 + index * 0.045)),
					edge * (0.73 + flutter * 0.08))
				draw_arc(point, edge * (0.08 + index * 0.035),
					0.3 if side > 0 else PI - 1.2, 1.2 if side > 0 else PI - 0.3, 12,
					Color(accent, fade * 0.75), maxf(1.5, edge * 0.014), true)

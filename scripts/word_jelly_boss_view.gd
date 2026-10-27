extends Control
## A side-standing acquired character and sourced energy effects; BossRun owns combat.

signal audio_requested(cue: String)

const Style = preload("res://scripts/ui_style.gd")
const Actor = preload("res://scripts/word_jelly_boss_actor.gd")
const Run = preload("res://scripts/word_jelly_boss_run.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const LOCK = preload("res://assets/images/ui/controls/lock.svg")
const CLOCK = preload("res://assets/images/ui/jelly-goals/clock.webp")
const INK = preload("res://assets/images/ui/controls/eye-closed.svg")
const COMPASS = preload("res://assets/jelly-boss/compass.webp")
const WOOD = preload("res://assets/images/ui/jelly-map/adventure-panel.png")
const COLORS: Dictionary = {"freeze": Color("#6cdffb"), "ink": Color("#c39afa"),
	"lock": Color("#ffc75d"), "snatch": Color("#a5ed8c")}
var reduced_motion: bool = false
var _actor := Actor.new()
var _character := TextureRect.new()
var _doubles: Array[TextureRect] = []
var _dialogue: Label
var _speaker_text: String = ""
var _state: Dictionary = {}
var _board := Rect2()
var _preview := Rect2()
var _hud := Rect2()
var _character_rect := Rect2()
var _scale: float = 1.0
var _generation: int = -1
var _last_event: int = 0
var _gesture: String = "Idle"
var _gesture_at: float = 0.0
var _dialogue_until: float = 0.0
var _sparks: Array[Dictionary] = []
var _tile_rects: Dictionary = {}
var _last_pose_frame: int = -1
var _last_pose_clip: String = ""
var _snatch: Dictionary = {}
var _thrown: Array[Dictionary] = []
var _health_from: float = 1.0
var _health_to: float = 1.0
var _health_at: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 28
	add_child(_actor)
	_character.texture = _actor.get_texture()
	_character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_character.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_character)
	for index in range(2):
		var clone := TextureRect.new()
		clone.texture = _actor.get_texture()
		clone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clone.modulate = Color(0.64, 0.51, 0.85, 0.55)
		add_child(clone)
		_doubles.append(clone)
	_dialogue = _label(13)
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue.max_lines_visible = 2
	_dialogue.clip_text = true
	_dialogue.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_dialogue.add_theme_color_override("font_outline_color", Color("#fffdf6"))
	hide()


func _label(pixels: int) -> Label:
	var label: Label = Style.label("", pixels)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func layout_battle(hud: Rect2, board: Rect2, scale_factor: float, preview: Rect2 = Rect2()) -> void:
	_hud = hud
	_board = board
	_scale = scale_factor
	_preview = preview if preview.has_area() else Rect2(board.position - Vector2(0, 60) / _scale,
		Vector2(board.size.x, 54 / _scale))
	var height: float = minf(hud.size.y, hud.size.x * 1.5)
	var dimensions := Vector2(height / 1.5, height).max(Vector2.ONE)
	_character_rect = Rect2(Vector2(hud.position.x + (hud.size.x - dimensions.x) * 0.5,
		hud.end.y - dimensions.y), dimensions)
	_character.position = _character_rect.position
	_character.size = _character_rect.size
	_dialogue.position = Vector2(board.position.x + 8 / _scale, board.end.y - 46 / _scale)
	_dialogue.size = Vector2(maxf(1.0, board.size.x - 16 / _scale), 38 / _scale)
	_dialogue.add_theme_font_size_override("font_size", ceili(13 / _scale))
	_dialogue.add_theme_constant_override("outline_size", ceili(3 / _scale))
	_pose()
	queue_redraw()


func sync(state: Dictionary, tiles: Dictionary, generation: int, active_clock: bool, visuals: Dictionary = {}) -> bool:
	var previous_health: float = _energy_ratio()
	var target_health: float = float(state.get("health", 0)) / maxf(1.0, float(state.get("max_health", 1)))
	if generation != _generation:
		_health_from = target_health
		_health_to = target_health
	elif not is_equal_approx(target_health, _health_to):
		_health_from = previous_health
		_health_to = target_health
		_health_at = float(state.elapsed)
	_state = state
	_tile_rects = tiles
	visible = bool(state.get("active", false)) and (not bool(state.get("definition", {}).get("intro", false)) \
		or state.get("phase") in ["ending", "done"])
	if not visible:
		return true
	if not _actor.load_character():
		return false
	if generation != _generation:
		_generation = generation
		_last_event = 0
		_gesture = "Taunt"
		_gesture_at = -100.0
		_last_pose_frame = -1
		_last_pose_clip = ""
		_sparks.clear()
		_snatch.clear()
		_thrown.clear()
	for event: Dictionary in state.get("events", []):
		if int(event.id) <= _last_event:
			continue
		_last_event = int(event.id)
		_handle_event(event, active_clock, visuals)
	set("accessibility_name", "Bramble. %d percent energy remaining." % roundi(target_health * 100.0))
	_pose()
	return true


func _handle_event(event: Dictionary, audible: bool, visuals: Dictionary) -> void:
	var kind: String = str(event.kind)
	var clips: Dictionary = {"throw": "Throw", "kick_windup": "Kick", "snatch": "Snatch",
		"player_hit": "Hit", "victory": "Hit", "taunt": "Taunt", "clones": "Taunt", "ward": "Celebrate"}
	if clips.has(kind):
		_gesture = clips[kind]
		_gesture_at = float(event.at)
	if kind == "throw" and event.get("status") == "snatch":
		_snatch = event.duplicate(true)
		_gesture = "Snatch"
	if kind == "snatch":
		var id: int = int(event.target)
		if visuals.has(id):
			var tile = visuals[id]
			_thrown.append({"at": float(event.at), "rect": _tile_rects.get(id,
				Rect2(_board.position + Vector2(event.tile.column, event.tile.row) * _board.size.x / 5,
					Vector2.ONE * _board.size.x / 5)),
				"surface": tile._surface.texture, "picture": tile._picture.texture,
				"text": tile._label.text})
	if event.has("text"):
		_dialogue.text = str(event.text)
		_dialogue_until = float(event.at) + 3.0
	if kind in ["status_hit", "thaw", "clear_ink", "unlock", "lock_resisted", "kick", "sky_repaired"]:
		_sparks.append({"event": event, "until": float(event.at) + 0.65})
	var cues: Dictionary = {"throw": "boss-throw", "kick": "boss-kick", "snatch": "boss-throw",
		"player_hit": "boss-hit", "unlock": "boss-unlock", "thaw": "boss-thaw",
		"sky_repaired": "boss-thaw", "clones": "boss-trick", "ward": "boss-trick",
		"taunt": "boss-taunt", "victory": "boss-win"}
	if audible and cues.has(kind):
		audio_requested.emit(cues[kind])


func _pose() -> void:
	if _state.is_empty() or not visible:
		return
	var elapsed: float = float(_state.elapsed)
	var ending: bool = _state.phase in ["ending", "done"]
	var ending_time: float = float(_state.ending_elapsed)
	var clip: String = _gesture if elapsed - _gesture_at < 1.1 else "Taunt"
	_character.position = _character_rect.position
	_character.size = _character_rect.size
	_character.modulate = Color.WHITE
	_character.rotation = 0.0
	if ending:
		clip = "Hit" if _state.outcome == "defeated" and ending_time < 1.2 else "Taunt" if ending_time < 5.0 else "Escape"
		var departure: float = clampf((ending_time - 5.0) / 2.0, 0.0, 1.0)
		if not reduced_motion:
			var style: String = str(_state.definition.retreat)
			if bool(_state.definition.get("intro", false)):
				var arrival: float = 1.0 - smoothstep(0.0, 0.7, ending_time)
				_character.position.x += arrival * (size.x + _character.size.x - _character_rect.position.x)
			_character.position.x += departure * departure * (size.x + _character.size.x - _character_rect.position.x)
			_character.position.y -= sin(departure * PI) * (72.0 if style in ["panic", "scramble"] else 30.0) / _scale
			_character.rotation = sin(departure * TAU * 2.0) * 0.12 if style == "panic" else -0.08 * departure if style == "swagger" else 0.0
		_character.modulate.a = 1.0 - departure if reduced_motion or _state.definition.retreat == "trick" else 1.0
		_speaker_text = "Pip" if ending_time >= 3.0 and ending_time < 4.8 else "Bramble"
		var end_event: Dictionary = {}
		for event: Dictionary in _state.events:
			if event.kind in ["victory", "taunt"]:
				end_event = event
		_dialogue.text = str(end_event.get("reply", "")) if ending_time >= 3.0 and ending_time < 4.8 else str(end_event.get("text", ""))
		if _state.outcome == "defeated" and ending_time < 1.7:
			_speaker_text = "Pip"
			_dialogue.text = "We did it!"
	else:
		if not reduced_motion:
			if _gesture == "Kick" and elapsed - _gesture_at < 1.4:
				var kick: float = sin(clampf((elapsed - _gesture_at) / 1.4, 0, 1) * PI)
				_character.size *= 1.0 + kick * 0.65
				var contact: Vector2 = _preview.get_center() - _character.size * Vector2(0.5, Actor.FOOT_Y)
				_character.position = _character_rect.position.lerp(contact, kick)
			if not _snatch.is_empty():
				var age: float = elapsed - float(_snatch.at)
				var destination: Vector2 = _board.position + Vector2(float(_snatch.column) + 0.5,
					float(_snatch.row) + 0.5) * _board.size.x / 5.0
				var target: Vector2 = destination - _character.size * Vector2(0.5, 0.65)
				var jump: float = clampf(age / (Run.WINDUP_SECONDS + Run.FLIGHT_SECONDS), 0.0, 1.0)
				if age <= Run.WINDUP_SECONDS + Run.FLIGHT_SECONDS:
					_character.position = _character_rect.position.lerp(target, jump)
					_character.position.y -= 4.0 * jump * (1 - jump) * 84.0 / _scale
				else:
					var back: float = clampf((age - Run.WINDUP_SECONDS - Run.FLIGHT_SECONDS) / 0.7, 0.0, 1.0)
					_character.position = target.lerp(_character_rect.position, back)
					_character.position.y -= sin(back * PI) * 54.0 / _scale
					if back >= 1.0:
						_snatch.clear()
		_speaker_text = "Bramble"
	_dialogue.visible = ((_state.phase == "ending" and ending_time < 6.4) \
		or not ending and elapsed < _dialogue_until) and not _dialogue.text.is_empty()
	var sample: int = floori(elapsed * 24.0)
	if sample != _last_pose_frame or clip != _last_pose_clip:
		_actor.pose(clip, elapsed - _gesture_at, reduced_motion)
		_last_pose_frame = sample
		_last_pose_clip = clip
	for index in range(2):
		var clone: TextureRect = _doubles[index]
		clone.visible = not ending and int(_state.clones) > index
		clone.size = _character.size * 0.8
		clone.position = _character.position + Vector2((8.0 if index == 0 else _character.size.x * 0.24), 8.0 / _scale)
	_sparks = _sparks.filter(func(item: Dictionary) -> bool: return float(item.until) > elapsed)
	_thrown = _thrown.filter(func(item: Dictionary) -> bool: return elapsed - float(item.at) < 1.2)
	queue_redraw()

func _energy_ratio() -> float:
	var elapsed: float = float(_state.get("elapsed", 0.0))
	var p: float = 1.0 if reduced_motion else smoothstep(0.0, 0.42, elapsed - _health_at)
	return clampf(lerpf(_health_from, _health_to, p), 0.0, 1.0)


func _draw() -> void:
	if not visible or _state.is_empty():
		return
	var center: Vector2 = _character.position + _character.size * Vector2(0.5, 0.53)
	var floor_point: Vector2 = _character.position + _character.size * Vector2(0.5, Actor.FOOT_Y)
	draw_texture_rect(GLOW, Rect2(floor_point - _character.size * Vector2(0.35, 0.035),
		_character.size * Vector2(0.70, 0.07)), false, Color(0.32, 0.22, 0.52, 0.42))
	if _state.phase not in ["ending", "done"]:
		var energy: float = _energy_ratio()
		draw_texture_rect(GLOW, _character.get_rect().grow(-_character.size.x * 0.06),
			false, Color(0.63, 0.41, 1.0, 0.13 + energy * 0.13))
		for index in range(8):
			var angle: float = lerpf(PI * 0.60, PI * 2.40, index / 7.0)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * _character.size * Vector2(0.43, 0.38)
			var filled: float = clampf(energy * 8.0 - index, 0.0, 1.0)
			var pulse: float = 1.0 if reduced_motion else 1.0 + 0.09 * sin(float(_state.elapsed) * 2.0 + index)
			var edge: float = minf(18.0 / _scale, _character.size.x * 0.14) * pulse
			draw_texture_rect(GLOW, Rect2(point - Vector2.ONE * edge, Vector2.ONE * edge * 2.0),
				false, Color(0.72, 0.52, 1.0, 0.45 * filled))
			draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
				false, Color(0.86, 0.72, 1.0, 0.10 + 0.90 * filled))
	if float(_state.broken_remaining) > 0.0:
		var rail_height: float = 7.0 / _scale
		var half: float = _preview.size.x * 0.5 - 10 / _scale
		draw_texture_rect_region(WOOD, Rect2(_preview.position + Vector2(0, _preview.size.y - rail_height),
			Vector2(half, rail_height)), Rect2(0, 0, 64, 14), Color("#e2b58e"))
		draw_texture_rect_region(WOOD, Rect2(_preview.position + Vector2(half + 20 / _scale, _preview.size.y - rail_height + 3 / _scale),
			Vector2(half, rail_height)), Rect2(64, 0, 64, 14), Color("#e2b58e"))
		draw_texture_rect(CLOCK, Rect2(_preview.position + Vector2(4, -20) / _scale,
			Vector2.ONE * 16 / _scale), false)
		draw_string(Style.HEADING_FONT, _preview.position + Vector2(23, -5) / _scale,
			"%ds" % ceili(float(_state.broken_remaining)), HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(11 / _scale), Color("#9c4c35"))
	for thrown: Dictionary in _thrown:
		if reduced_motion:
			continue
		var t: float = clampf((float(_state.elapsed) - float(thrown.at)) / 1.2, 0.0, 1.0)
		var rect: Rect2 = thrown.rect
		var destination := Vector2(size.x + rect.size.x * 2.0, _board.end.y + rect.size.y)
		var at: Vector2 = rect.get_center().lerp(destination, t)
		at.y -= 4.0 * t * (1.0 - t) * 140.0 / _scale
		draw_set_transform(at, t * TAU, Vector2.ONE)
		var box := Rect2(-rect.size * 0.5, rect.size)
		if thrown.surface != null:
			draw_texture_rect(thrown.surface, box, false)
		if thrown.picture != null:
			draw_texture_rect(thrown.picture, box.grow(-rect.size.x * 0.15), false)
		elif not str(thrown.text).is_empty():
			draw_string(Style.HEADING_FONT, Vector2(-rect.size.x * 0.4, 5 / _scale), str(thrown.text),
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x * 0.8, ceili(13 / _scale), Style.INK)
		draw_set_transform(Vector2.ZERO)
	for event: Dictionary in _state.get("events", []):
		if event.kind not in ["player_hit", "clone_hit", "ward_hit"]:
			continue
		var age: float = float(_state.elapsed) - float(event.at)
		if age < 0.0 or age > 0.85:
			continue
		var origin: Dictionary = event.get("origin", {})
		var start: Vector2 = _board.position + Vector2(float(origin.get("column", 2)) + 0.5,
			float(origin.get("row", 4)) + 0.5) * _board.size.x / 5.0
		var target: Vector2 = _character.position + _character.size * Vector2(0.5, 0.42)
		var p: float = clampf(age / 0.55, 0.0, 1.0)
		var at: Vector2 = start.lerp(target, p)
		at.y -= sin(p * PI) * 48.0 / _scale
		var edge: float = (18.0 + int(event.get("level", 1)) * 2.0) / _scale
		if reduced_motion:
			draw_texture_rect(GLOW, Rect2(target - Vector2.ONE * edge, Vector2.ONE * edge * 2),
				false, Color(1, 0.88, 0.55, 0.55))
			continue
		if p < 1.0:
			draw_texture_rect(GLOW, Rect2(at - Vector2.ONE * edge, Vector2.ONE * edge * 2), false, Color("#fff0a6"))
			draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color("#ffe799"))
		else:
			draw_texture_rect(RAYS, Rect2(target - Vector2.ONE * edge * 1.6, Vector2.ONE * edge * 3.2), false, Color(1, 0.85, 0.5, 1 - (age - 0.55) / 0.3))
			draw_string(Style.HEADING_FONT, target - Vector2(10, 12) / _scale,
				"-%d" % int(event.get("damage", 0)), HORIZONTAL_ALIGNMENT_CENTER, -1, ceili(18 / _scale), Color("#75426f"))
	if _state.phase in ["ending", "done"]:
		var compass_edge: float = 42 / _scale
		var compass_target: Vector2 = _character.position + _character.size * Vector2(0.77, 0.62)
		if _state.outcome == "ambushed":
			var steal: float = clampf((float(_state.ending_elapsed) - 0.5) / 1.4, 0, 1)
			var from: Vector2 = _board.position + Vector2(_board.size.x * 0.20, 40 / _scale)
			compass_target = from.lerp(compass_target, steal)
		elif int(_state.definition.get("id", 0)) == 8 and _state.outcome == "defeated":
			var give_back: float = clampf(float(_state.ending_elapsed) / 2.0, 0, 1)
			compass_target = compass_target.lerp(_board.get_center(), give_back)
		draw_texture_rect(GLOW, Rect2(compass_target - Vector2.ONE * compass_edge, Vector2.ONE * compass_edge * 2),
			false, Color(1, 0.86, 0.42, 0.7))
		draw_texture_rect(COMPASS, Rect2(compass_target - Vector2.ONE * compass_edge * 0.5,
			Vector2.ONE * compass_edge), false)
		if not reduced_motion and _state.outcome == "defeated" and float(_state.ending_elapsed) < 2.0:
			var p: float = float(_state.ending_elapsed) / 2.0
			for index in range(12):
				var angle: float = TAU * index / 12.0
				var at: Vector2 = center + Vector2(cos(angle), sin(angle)) * (40.0 + p * 100.0) / _scale
				draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * 8 / _scale, Vector2.ONE * 16 / _scale),
					false, Color(1, 0.86, 0.4, 1 - p))
		return
	for projectile: Dictionary in _state.get("projectiles", []):
		if projectile.status == "snatch":
			continue
		var progress: float = clampf((float(projectile.elapsed) - float(projectile.windup)) / float(projectile.duration), 0.0, 1.0)
		var destination: Vector2 = _board.position + Vector2(float(projectile.column) + 0.5,
			float(projectile.row) + 0.5) * _board.size.x / 5.0
		var start: Vector2 = _character.position + _character.size * Vector2(0.35, 0.5)
		var at: Vector2 = start.lerp(destination, progress)
		at.y -= 4.0 * progress * (1.0 - progress) * maxf(30 / _scale, start.distance_to(destination) * 0.24)
		var tint: Color = COLORS.get(projectile.status, Color.WHITE)
		var edge: float = 30 / _scale
		if progress <= 0.0 or reduced_motion:
			draw_texture_rect(GLOW, Rect2(destination - Vector2.ONE * edge, Vector2.ONE * edge * 2), false, Color(tint, 0.35))
			continue
		for sample in range(5):
			var tail: float = maxf(0.0, progress - sample * 0.025)
			var point: Vector2 = start.lerp(destination, tail)
			point.y -= 4.0 * tail * (1.0 - tail) * maxf(30 / _scale, start.distance_to(destination) * 0.24)
			draw_texture_rect(GLOW, Rect2(point - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color(tint, 0.5 - sample * 0.075))
		draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.35, Vector2.ONE * edge * 0.7), false, tint)
		var icon: Texture2D = LOCK if projectile.status == "lock" else INK if projectile.status == "ink" else CLOCK
		draw_texture_rect(icon, Rect2(at - Vector2.ONE * edge * 0.25, Vector2.ONE * edge * 0.5), false)
	for item: Dictionary in _sparks:
		var event: Dictionary = item.event
		var sky_effect: bool = event.kind in ["kick", "sky_repaired"]
		if not sky_effect and not _tile_rects.has(int(event.target)):
			continue
		var rect: Rect2 = _preview if sky_effect else _tile_rects[int(event.target)]
		var p: float = clampf((float(_state.elapsed) - float(event.at)) / 0.65, 0, 1)
		var tint: Color = Color("#b3f4ff") if event.kind == "thaw" else Color("#ffe1a0")
		if reduced_motion:
			draw_texture_rect(GLOW, rect.grow(4 / _scale), false, Color(tint, 0.6))
			continue
		draw_texture_rect(RAYS, rect.grow(rect.size.x * 0.3 * p), false, Color(tint, 1.0 - p))
		for index in range(5):
			var point: Vector2 = rect.get_center() + Vector2.from_angle(TAU * index / 5.0) * rect.size.x * p * 0.75
			var edge: float = 12 / _scale * (1.0 - p)
			draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color(tint, 1 - p))


func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "rect": [_hud.position.x, _hud.position.y, _hud.size.x, _hud.size.y],
		"base_character_rect": [_character_rect.position.x, _character_rect.position.y, _character_rect.size.x, _character_rect.size.y],
		"character_rect": [_character.position.x, _character.position.y, _character.size.x, _character.size.y],
		"presentation": "side_character", "clip": _last_pose_clip, "heading": "", "health_text": "",
		"health_fraction": float(_state.get("health", 0)) / maxf(1.0, float(_state.get("max_health", 1))),
		"energy_fraction": _energy_ratio(), "energy_segments": 8,
		"dialogue": _dialogue.text if visible and _dialogue.visible else "", "speaker": _speaker_text if visible else "",
		"animations": Array(_actor.animation_names()), "error": _actor.last_error}

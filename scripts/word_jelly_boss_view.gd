extends Control
## The optimized Pirate and sourced energy effects; BossRun owns combat.

signal audio_requested(cue: String)

const Style = preload("res://scripts/ui_style.gd")
const Actor = preload("res://scripts/word_jelly_boss_actor.gd")
const Pirate = preload("res://scripts/pirate_asset_actor.gd")
const Run = preload("res://scripts/word_jelly_boss_run.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const GLOW = preload("res://assets/chests/shared/effects/portal_glow.png")
const SPARKLE = preload("res://assets/chests/shared/effects/sparkle.png")
const RAYS = preload("res://assets/chests/shared/effects/rays.png")
const FROST_FLAKE = preload("res://assets/images/jelly-level-fx/frost-flake.png")
const INK_SPLAT = preload("res://assets/images/jelly-level-fx/ink-splat.png")
const IMPACT_STAR = preload("res://assets/images/jelly-level-fx/impact-star.png")
const SOFT_POOF = preload("res://assets/images/jelly-level-fx/soft-poof.png")
const LOCK = preload("res://assets/images/ui/controls/lock.svg")
const CLOCK = preload("res://assets/images/ui/jelly-goals/clock.webp")
const INK = preload("res://assets/images/ui/controls/eye-closed.svg")
const COMPASS = preload("res://assets/jelly-boss/compass.webp")
const WOOD = preload("res://assets/images/ui/jelly-map/adventure-panel.png")
const COLORS: Dictionary = {"freeze": Color("#6cdffb"), "ink": Color("#c39afa"),
	"lock": Color("#ffc75d"), "snatch": Color("#a5ed8c")}
const HIT_FLIGHT_SECONDS: float = 0.55
const HIT_RECOVERY_SECONDS: float = 0.32
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
var _gesture_clip: String = "Idle"
var _taunt_serial: int = 0
var _gesture_at: float = 0.0
var _dialogue_until: float = 0.0
var _sparks: Array[Dictionary] = []
var _dodges: Array[Dictionary] = []
var _tile_rects: Dictionary = {}
var _last_pose_frame: int = -1
var _last_pose_clip: String = ""
var _last_pose_reduced: bool = false
var _snatch: Dictionary = {}
var _thrown: Array[Dictionary] = []
var _health_from: float = 1.0
var _health_to: float = 1.0
var _health_at: float = 0.0
var _health_ghost_from: float = 1.0
var _last_impact_event: int = 0
var _last_defense_event: int = 0
var _impact_level: int = 1
var _impact_power: bool = false
var _impact_hitstop: float = 0.0
var _hit_flash_at: float = -100.0
var _hit_flash_tint: Color = Color(1.0, 0.96, 0.84)
var _clone_poofs: Array[Dictionary] = []
var _ward_shatters: Array[Dictionary] = []
var _beam_strikes: Array[Dictionary] = []
var _energy_shatters: Array[Dictionary] = []
var _audible_clock: bool = false
var _victory_announced: bool = false
var _dialogue_layout_key: Array = []


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
	_dialogue_layout_key.clear()
	_layout_dialogue(_state.get("phase") in ["ending", "done"])
	_pose()
	queue_redraw()


func sync(state: Dictionary, tiles: Dictionary, generation: int, active_clock: bool, visuals: Dictionary = {}) -> bool:
	var target_health: float = float(state.get("health", 0)) / maxf(1.0, float(state.get("max_health", 1)))
	if generation != _generation:
		_health_from = target_health
		_health_to = target_health
		_health_ghost_from = target_health
	_state = state
	_audible_clock = active_clock
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
		_taunt_serial = int(state.get("definition", {}).get("id", 0))
		_gesture_clip = _next_taunt()
		_gesture_at = -100.0
		_last_pose_frame = -1
		_last_pose_clip = ""
		_last_impact_event = 0
		_last_defense_event = 0
		_impact_power = false
		_impact_hitstop = 0.0
		_hit_flash_at = -100.0
		_victory_announced = false
		_sparks.clear()
		_dodges.clear()
		_snatch.clear()
		_thrown.clear()
		_clone_poofs.clear()
		_ward_shatters.clear()
		_beam_strikes.clear()
		_energy_shatters.clear()
		_actor.set_hit_flash(0.0)
	for event: Dictionary in state.get("events", []):
		if int(event.id) <= _last_event:
			continue
		_last_event = int(event.id)
		_handle_event(event, active_clock, visuals)
	set("accessibility_name", "Pirate. %d percent energy remaining." % roundi(target_health * 100.0))
	_pose()
	return true


func _handle_event(event: Dictionary, audible: bool, visuals: Dictionary) -> void:
	var kind: String = str(event.kind)
	var clips: Dictionary = {"entrance": "Taunt", "throw": "Throw", "kick_windup": "Kick", "snatch": "Snatch",
		"taunt": "Taunt", "clones": "Taunt", "ward": "Celebrate", "storm": "Storm"}
	var storm_active: bool = _gesture == "Storm" and float(event.at) - _gesture_at < 2.5
	var snatch_contact: bool = kind == "snatch" and not _snatch.is_empty()
	if clips.has(kind) and not (kind == "throw" and storm_active) and not snatch_contact:
		_gesture = clips[kind]
		_gesture_at = float(event.at)
		match kind:
			"entrance", "taunt":
				_gesture_clip = _next_taunt()
			"clones":
				_gesture_clip = "Taunt_Peekaboo"
			"ward":
				_gesture_clip = "Taunt_VictoryLap"
			"kick_windup":
				_gesture_clip = "Special_GiantRam"
			"snatch":
				_gesture_clip = "Special_BigBite"
			"storm":
				_gesture_clip = ["Ultimate_TidalRush", "Ultimate_CrescentSpin", "Ultimate_CaptainsDrop"][int(event.id) % 3]
			"throw":
				_gesture_clip = "Attack_L" if event.get("status") == "freeze" else "Attack_M" if event.get("status") == "ink" else "Attack_P"
	if kind == "throw" and event.get("status") == "snatch":
		_snatch = event.duplicate(true)
		_gesture = "Snatch"
		_gesture_clip = "Special_BigBite"
	if kind == "snatch":
		var id: int = int(event.target)
		if visuals.has(id):
			var tile = visuals[id]
			_thrown.append({"at": float(event.at), "rect": _tile_rects.get(id,
				Rect2(_board.position + Vector2(event.tile.column, event.tile.row) * _board.size.x / Model.COLUMNS,
					Vector2.ONE * _board.size.x / Model.COLUMNS)),
				"surface": tile._surface.texture, "picture": tile._picture.texture,
				"text": tile._label.text})
	if event.has("text"):
		_dialogue.text = str(event.text)
		_dialogue_until = float(event.at) + 3.0
	if kind in ["status_hit", "thaw", "clear_ink", "unlock", "lock_resisted", "kick", "sky_repaired"]:
		_sparks.append({"event": event, "until": float(event.at) + 0.65})
	if kind == "miss":
		_dodges.append({"event": event, "until": float(event.at) + 0.95})
		if audible:
			audio_requested.emit("boss-thaw")
	var cues: Dictionary = {"throw": "boss-throw", "kick": "boss-kick", "snatch": "boss-throw",
		"unlock": "boss-unlock", "thaw": "boss-thaw",
		"sky_repaired": "boss-thaw", "clones": "boss-trick", "ward": "boss-trick",
		"taunt": "boss-taunt"}
	if audible and cues.has(kind):
		audio_requested.emit(cues[kind])


func _layout_dialogue(ending: bool) -> void:
	var key: Array = [ending, _board, _scale]
	if key == _dialogue_layout_key:
		return
	_dialogue_layout_key = key
	var pixels: float = (16.0 if _board.size.x * _scale >= 220.0 else 14.0) if ending else 13.0
	var height: float = 52.0 if ending else 44.0
	_dialogue.position = Vector2(_board.position.x + 8.0 / _scale, _board.end.y - (height + 8.0) / _scale)
	_dialogue.size = Vector2(maxf(1.0, _board.size.x - 16.0 / _scale), height / _scale)
	_dialogue.add_theme_font_size_override("font_size", ceili(pixels / _scale))
	_dialogue.add_theme_constant_override("outline_size", ceili(3.0 / _scale))


func _present_impacts(elapsed: float) -> void:
	var delay: float = 0.0 if reduced_motion else HIT_FLIGHT_SECONDS
	for event: Dictionary in _state.get("events", []):
		if event.kind in ["clone_hit", "ward_hit"] and int(event.id) > _last_defense_event:
			var def_age: float = elapsed - float(event.at) - delay
			if def_age >= 0.0:
				_last_defense_event = int(event.id)
				if not reduced_motion:
					if event.kind == "clone_hit":
						_clone_poofs.append({"at": float(event.at) + delay, "remaining": int(event.get("remaining", 0))})
					else:
						_ward_shatters.append({"at": float(event.at) + delay, "remaining": int(event.get("remaining", 0)),
							"shattered": int(event.get("remaining", 0)) == 0})
					if _audible_clock:
						audio_requested.emit("boss-ward-break" if event.kind == "ward_hit" else "boss-clone-pop")
		if event.kind != "player_hit" or int(event.id) <= _last_impact_event:
			continue
		var is_skill: bool = bool(event.get("skill_hit", false))
		var event_delay: float = 0.0 if (reduced_motion or is_skill) else delay
		var age: float = elapsed - float(event.at) - event_delay
		if age < 0.0:
			continue
		_last_impact_event = int(event.id)
		var prev_energy: float = _energy_ratio()
		_health_from = prev_energy
		_health_ghost_from = maxf(_energy_ghost_ratio(), prev_energy)
		_health_to = float(event.health_after) / maxf(1.0, float(_state.max_health))
		_health_at = float(event.at) + event_delay
		if not reduced_motion:
			var lost_start: int = floori(_health_to * 8.0)
			var lost_end: int = ceili(prev_energy * 8.0)
			for seg in range(maxi(0, lost_start), mini(8, lost_end)):
				if prev_energy * 8.0 - float(seg) > 0.15 and _health_to * 8.0 - float(seg) < 0.85:
					_energy_shatters.append({"seg": seg, "at": _health_at})
			if is_skill:
				_beam_strikes.append({"at": _health_at, "origin": event.get("origin", {"column": 3, "row": 3})})
		var power_hit: bool = bool(event.get("power_hit", false))
		var level: int = int(event.get("level", 1))
		_impact_level = level
		_impact_power = power_hit
		_hit_flash_at = _health_at
		_hit_flash_tint = Color(1.0, 0.90, 0.56) if (power_hit or is_skill) else Color(1.0, 0.98, 0.92)
		_impact_hitstop = 0.0 if reduced_motion else (0.085 if (power_hit or is_skill) else 0.065 if level >= 4 else 0.045)
		if age <= HIT_RECOVERY_SECONDS:
			_gesture = "Hit"
			_gesture_at = _health_at
			_gesture_clip = _hit_clip(_impact_level)
			if _audible_clock:
				audio_requested.emit("boss-hit")
				if power_hit or is_skill:
					audio_requested.emit("boss-hit-power")
				elif level >= 4:
					audio_requested.emit("boss-hit-heavy")
	if _state.outcome == "defeated" and float(_state.ending_elapsed) >= _victory_delay() and not _victory_announced:
		_victory_announced = true
		_hit_flash_at = elapsed
		_hit_flash_tint = Color(1.0, 0.93, 0.62)
		_impact_hitstop = 0.0 if reduced_motion else 0.11
		if _audible_clock:
			audio_requested.emit("boss-win")


func _finishing_hit() -> bool:
	var started: float = float(_state.elapsed) - float(_state.ending_elapsed)
	return _state.get("outcome") == "defeated" and _state.get("events", []).any(
		func(event: Dictionary) -> bool:
			return event.kind == "player_hit" and absf(float(event.at) - started) <= Run.EPSILON)


func _victory_delay() -> float:
	return HIT_FLIGHT_SECONDS if not reduced_motion and _finishing_hit() else 0.0


func _next_taunt() -> String:
	var clip: String = Pirate.TAUNTS[_taunt_serial % Pirate.TAUNTS.size()]
	_taunt_serial += 1
	return clip


func _hit_clip(level: int) -> String:
	return "Hit_L" if level <= 3 else "Hit_M" if level <= 6 else "Hit_P"


func _action_clip(gesture: String) -> String:
	if gesture == "Idle":
		return "Idle"
	if gesture == "Hit":
		return _hit_clip(_impact_level)
	if gesture == "Escape":
		return "Taunt_Swagger"
	if gesture == _gesture:
		return _gesture_clip
	return "Taunt_BellyLaugh"


func _action_span(gesture: String, native_clip: String) -> float:
	match gesture:
		"Hit": return HIT_RECOVERY_SECONDS
		"Throw": return Run.WINDUP_SECONDS + Run.FLIGHT_SECONDS
		"Kick": return 1.4
		"Snatch": return Run.WINDUP_SECONDS + Run.FLIGHT_SECONDS + 0.7
		"Storm": return _actor.clip_duration(native_clip)
	return _actor.clip_duration(native_clip)


func _native_action_time(gesture: String, age: float, native_clip: String) -> float:
	var duration: float = _actor.clip_duration(native_clip)
	var span: float = _action_span(gesture, native_clip)
	var contact: float = Run.WINDUP_SECONDS
	var native_contact: float = 0.0
	match gesture:
		"Throw":
			native_contact = {"Attack_L": 0.22, "Attack_M": 0.40, "Attack_P": 0.69}.get(native_clip, 0.40)
		"Kick":
			native_contact = 1.05
		"Snatch":
			contact = Run.WINDUP_SECONDS + Run.FLIGHT_SECONDS
			native_contact = 0.72
		_:
			return clampf(age / maxf(0.001, span), 0.0, 1.0) * duration if gesture != "Idle" else age
	if age <= contact:
		return native_contact * clampf(age / contact, 0.0, 1.0)
	return lerpf(native_contact, duration, clampf((age - contact) / maxf(0.001, span - contact), 0.0, 1.0))


func _anchor_point(anchor: String) -> Vector2:
	var point: Vector2 = _actor.project_anchor(anchor) / Vector2(_actor.size)
	return _character.get_transform() * (point * _character.size)


func _pose() -> void:
	if _state.is_empty() or not visible:
		return
	var elapsed: float = float(_state.elapsed)
	_present_impacts(elapsed)
	var ending: bool = _state.phase in ["ending", "done"]
	_layout_dialogue(ending)
	var ending_time: float = float(_state.ending_elapsed)
	var clip: String = _gesture if elapsed - _gesture_at < _action_span(_gesture, _gesture_clip) else "Idle"
	if _state.phase == "exhausted":
		clip = "Hit"
		_snatch.clear()
	_character.position = _character_rect.position
	_character.size = _character_rect.size
	_character.scale = Vector2.ONE
	_character.modulate = Color.WHITE
	_character.rotation = 0.0
	if ending:
		var impact_at: float = _victory_delay()
		if _state.outcome == "defeated":
			clip = "Idle" if ending_time < impact_at else "Hit" if ending_time < 1.7 \
				else "Idle" if int(_state.definition.id) == 8 else "Escape"
		else:
			clip = "Taunt" if ending_time < 5.0 else "Escape"
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
		_speaker_text = "Pip" if ending_time >= 3.0 and ending_time < 4.8 else "Pirate"
		var end_event: Dictionary = {}
		for event: Dictionary in _state.events:
			if event.kind in ["victory", "taunt"]:
				end_event = event
		_dialogue.text = str(end_event.get("reply", "")) if ending_time >= 3.0 and ending_time < 4.8 else str(end_event.get("text", ""))
		if _state.outcome == "ambushed" and ending_time >= 0.5 and ending_time < 2.0:
			_speaker_text = "Pip"
			_dialogue.text = "Hey! Our Word Compass!"
		elif _state.outcome == "defeated" and ending_time >= impact_at and ending_time < 1.7:
			_speaker_text = "Pip"
			_dialogue.text = "Pirate beaten!"
	else:
		if not reduced_motion:
			if _gesture == "Kick" and elapsed - _gesture_at < 1.4:
				var kick: float = sin(clampf((elapsed - _gesture_at) / 1.4, 0, 1) * PI)
				var contact: Vector2 = _preview.get_center() - _character.size * Vector2(0.5, Actor.FOOT_Y)
				_character.position = _character_rect.position.lerp(contact, kick)
			if not _snatch.is_empty():
				var age: float = elapsed - float(_snatch.at)
				var destination: Vector2 = _board.position + Vector2(float(_snatch.column) + 0.5,
					float(_snatch.row) + 0.5) * _board.size.x / Model.COLUMNS
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
		_speaker_text = "Pirate"
	_character.pivot_offset = _character.size * Vector2(0.5, Actor.FOOT_Y)
	var flash_age: float = elapsed - _hit_flash_at
	var flash_strength: float = 0.0 if (reduced_motion or flash_age < 0.0 or flash_age >= 0.14) else (1.0 - smoothstep(0.02, 0.14, flash_age))
	_actor.set_hit_flash(flash_strength, _hit_flash_tint)
	if not reduced_motion:
		if ending and _finishing_hit():
			var finish_age: float = ending_time - HIT_FLIGHT_SECONDS
			var impact: float = clampf(finish_age / 0.48, 0.0, 1.0)
			if impact > 0.0:
				var snap: float = sin(pow(impact, 0.65) * PI)
				var shake: float = sin(finish_age * 78.0) * (1.0 - impact) * 3.5 if finish_age < 0.22 else 0.0
				_character.position.x += (snap * 22.0 + shake) / _scale
				_character.rotation += snap * 0.17
				var sq: float = sin(minf(1.0, impact / 0.45) * PI) * 0.16
				_character.scale = Vector2(1.0 - sq, 1.0 + sq * 0.78)
		elif not ending and _gesture == "Hit":
			var hit_age: float = elapsed - _gesture_at
			var impact: float = clampf(hit_age / HIT_RECOVERY_SECONDS, 0.0, 1.0)
			var weight: float = (18.0 if _impact_power else minf(14.5, 5.5 + float(_impact_level) * 1.4))
			var recoil: float = sin(pow(impact, 0.55) * PI)
			var jitter: float = sin(hit_age * 88.0) * (1.0 - impact) * (2.6 if _impact_power else 1.4) if hit_age < 0.14 else 0.0
			_character.position.x += (recoil * weight + jitter) / _scale
			_character.rotation = recoil * (0.14 if _impact_power else 0.065 + float(_impact_level) * 0.008)
			var sq_amp: float = 0.14 if _impact_power else 0.075 + float(_impact_level) * 0.008
			var sq: float = exp(-impact * 4.2) * sin(impact * PI * 1.6) * sq_amp
			_character.scale = Vector2(1.0 - sq, 1.0 + sq * 0.85)
		elif not ending and float(_state.get("stun_remaining", 0.0)) > 0.0:
			var wobble: float = sin(elapsed * 12.0) * 0.035
			_character.rotation = wobble
	_dialogue.visible = ((_state.phase == "ending" and ending_time < 6.4) \
		or not ending and elapsed < _dialogue_until) and not _dialogue.text.is_empty()
	var sample: int = floori(elapsed * 24.0)
	var native_clip: String = _action_clip(clip)
	var hitstop_active: bool = not reduced_motion and clip == "Hit" and (elapsed - _gesture_at) < _impact_hitstop and (elapsed - _gesture_at) >= 0.0
	if sample != _last_pose_frame or native_clip != _last_pose_clip or reduced_motion != _last_pose_reduced:
		var raw_pose_time: float = elapsed - _gesture_at
		var pose_time: float = (0.04 if hitstop_active else maxf(0.0, raw_pose_time - _impact_hitstop * 0.6)) if clip == "Hit" else raw_pose_time
		var native_time: float = _native_action_time(clip, pose_time, native_clip)
		if ending and _state.outcome == "defeated":
			pose_time = ending_time - (_victory_delay() if clip == "Hit" else 1.7 if clip == "Escape" else 0.0)
			if clip == "Hit":
				native_time = clampf(pose_time / (1.7 - _victory_delay()), 0.0, 1.0) * _actor.clip_duration(native_clip)
			else:
				native_time = pose_time
		elif ending:
			native_time = ending_time - (5.0 if clip == "Escape" else 0.0)
		_actor.pose(native_clip, native_time, reduced_motion)
		_last_pose_frame = sample
		_last_pose_clip = native_clip
		_last_pose_reduced = reduced_motion
	for index in range(2):
		var clone: TextureRect = _doubles[index]
		var arriving_hits: int = 0
		if not reduced_motion:
			for event: Dictionary in _state.get("events", []):
				if event.kind == "clone_hit" and elapsed - float(event.at) < HIT_FLIGHT_SECONDS:
					arriving_hits += 1
		clone.visible = not ending and int(_state.clones) + arriving_hits > index
		clone.size = _character.size * 0.8
		clone.position = _character.position + Vector2((8.0 if index == 0 else _character.size.x * 0.24), 8.0 / _scale)
	_sparks = _sparks.filter(func(item: Dictionary) -> bool: return float(item.until) > elapsed)
	_dodges = _dodges.filter(func(item: Dictionary) -> bool: return float(item.until) > elapsed)
	_thrown = _thrown.filter(func(item: Dictionary) -> bool: return elapsed - float(item.at) < 1.2)
	_clone_poofs = _clone_poofs.filter(func(item: Dictionary) -> bool: return elapsed - float(item.at) < 0.36)
	_ward_shatters = _ward_shatters.filter(func(item: Dictionary) -> bool: return elapsed - float(item.at) < 0.42)
	_beam_strikes = _beam_strikes.filter(func(item: Dictionary) -> bool: return elapsed - float(item.at) < 0.42)
	_energy_shatters = _energy_shatters.filter(func(item: Dictionary) -> bool: return elapsed - float(item.at) < 0.44)
	queue_redraw()

func _energy_ratio() -> float:
	var elapsed: float = float(_state.get("elapsed", 0.0))
	var p: float = 1.0 if reduced_motion else smoothstep(0.0, 0.24, elapsed - _health_at)
	return clampf(lerpf(_health_from, _health_to, p), 0.0, 1.0)


func _energy_ghost_ratio() -> float:
	var elapsed: float = float(_state.get("elapsed", 0.0))
	var p: float = 1.0 if reduced_motion else smoothstep(0.18, 0.62, elapsed - _health_at)
	return clampf(lerpf(_health_ghost_from, _health_to, p), 0.0, 1.0)


func _draw() -> void:
	if not visible or _state.is_empty():
		return
	var center: Vector2 = _character.position + _character.size * Vector2(0.5, 0.53)
	var floor_point: Vector2 = _character.position + _character.size * Vector2(0.5, Actor.FOOT_Y)
	draw_texture_rect(GLOW, Rect2(floor_point - _character.size * Vector2(0.35, 0.035),
		_character.size * Vector2(0.70, 0.07)), false, Color(0.32, 0.22, 0.52, 0.42))
	if _state.outcome == "defeated" and not reduced_motion:
		var release: float = float(_state.ending_elapsed) - _victory_delay()
		if release >= 0.0 and release < 1.0:
			var glow: float = sin(clampf(release / 0.4, 0.0, 1.0) * PI) * (1.0 - release)
			var edge: float = _character.size.x * (1.1 + 0.45 * smoothstep(0.0, 0.4, release))
			draw_texture_rect(RAYS, Rect2(center - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
				false, Color(1.0, 0.86, 0.36, glow * 0.88))
			if release < 0.36:
				var ring_p: float = release / 0.36
				var ring_ease: float = 1.0 - pow(1.0 - ring_p, 3.0)
				draw_arc(center, _character.size.x * lerpf(0.22, 1.35, ring_ease), 0.0, TAU, 36,
					Color(1.0, 0.95, 0.68, (1.0 - ring_p) * 0.92), maxf(2.0, lerpf(6.0, 1.0, ring_ease) / _scale), true)
				draw_arc(center, _character.size.x * lerpf(0.14, 0.92, ring_ease), 0.0, TAU, 32,
					Color(1.0, 0.82, 0.34, (1.0 - ring_p) * 0.78), maxf(1.5, lerpf(4.0, 0.8, ring_ease) / _scale), true)
			if release < 0.18:
				var veil_a: float = (1.0 - release / 0.18) * 0.24
				draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.96, 0.82, veil_a))
	if _state.phase not in ["ending", "done"]:
		var energy: float = _energy_ratio()
		var energy_ghost: float = _energy_ghost_ratio()
		draw_texture_rect(GLOW, _character.get_rect().grow(-_character.size.x * 0.06),
			false, Color(0.63, 0.41, 1.0, 0.13 + energy * 0.13))
		for index in range(8):
			var angle: float = lerpf(PI * 0.60, PI * 2.40, index / 7.0)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * _character.size * Vector2(0.43, 0.38)
			var filled: float = clampf(energy * 8.0 - index, 0.0, 1.0)
			var ghost_fill: float = clampf(energy_ghost * 8.0 - index, 0.0, 1.0)
			var pulse: float = 1.0 if reduced_motion else 1.0 + 0.09 * sin(float(_state.elapsed) * 2.0 + index)
			var edge: float = minf(18.0 / _scale, _character.size.x * 0.14) * pulse
			if ghost_fill > filled + 0.02 and not reduced_motion:
				var trail_alpha: float = clampf(ghost_fill - filled, 0.0, 1.0)
				draw_texture_rect(GLOW, Rect2(point - Vector2.ONE * edge * 1.1, Vector2.ONE * edge * 2.2),
					false, Color(1.0, 0.46, 0.36, 0.65 * trail_alpha))
			draw_texture_rect(GLOW, Rect2(point - Vector2.ONE * edge, Vector2.ONE * edge * 2.0),
				false, Color(0.72, 0.52, 1.0, 0.45 * filled))
			draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
				false, Color(0.86, 0.72, 1.0, 0.10 + 0.90 * filled))
		for shatter: Dictionary in _energy_shatters:
			var sh_p: float = clampf((float(_state.elapsed) - float(shatter.at)) / 0.44, 0.0, 1.0)
			var seg_i: int = int(shatter.seg)
			var seg_angle: float = lerpf(PI * 0.60, PI * 2.40, float(seg_i) / 7.0)
			var pt0: Vector2 = center + Vector2(cos(seg_angle), sin(seg_angle)) * _character.size * Vector2(0.43, 0.38)
			var burst_r: float = (18.0 + sh_p * 34.0) / _scale
			for k in range(5):
				var ka: float = seg_angle + (float(k) - 2.0) * 0.48
				var kp: Vector2 = pt0 + Vector2.from_angle(ka) * burst_r * (0.7 + 0.3 * float(k % 2))
				var ke: float = (9.0 / _scale) * (1.0 - sh_p)
				draw_texture_rect(SPARKLE, Rect2(kp - Vector2.ONE * ke * 0.5, Vector2.ONE * ke),
					false, Color(1.0, 0.72, 0.96, (1.0 - sh_p) * 0.92))
		# Visible translucent arcane barrier when Pirate has active Ward stacks.
		var ward_stacks: int = int(_state.get("ward", 0))
		if ward_stacks > 0:
			var shield_r: float = _character.size.x * 0.44
			var shield_pulse: float = 0.0 if reduced_motion else sin(float(_state.elapsed) * 4.2) * 0.08
			var barrier_col := Color(0.48, 0.85, 1.0, 0.62 + shield_pulse) if ward_stacks >= 2 else Color(0.76, 0.92, 1.0, 0.48 + shield_pulse)
			draw_arc(center, shield_r, PI * 0.55, PI * 1.45, 24, barrier_col, maxf(2.5, (5.0 if ward_stacks >= 2 else 3.2) / _scale), true)
			draw_arc(center, shield_r * 0.92, PI * 0.62, PI * 1.38, 20, Color(1.0, 0.98, 0.88, 0.40), maxf(1.2, 2.0 / _scale), true)
			for w_idx in range(ward_stacks):
				var wy: float = center.y + (float(w_idx) - float(ward_stacks - 1) * 0.5) * 18.0 / _scale
				var wp := Vector2(center.x - shield_r, wy)
				var we: float = 11.0 / _scale
				draw_texture_rect(IMPACT_STAR, Rect2(wp - Vector2.ONE * we * 0.5, Vector2.ONE * we),
					false, Color(0.75, 0.95, 1.0, 0.92))
		# Dizzy orbiting stars above hat while Pirate is stunned!
		var stun_left: float = float(_state.get("stun_remaining", 0.0))
		if stun_left > 0.0:
			var hat_pt: Vector2 = _anchor_point("hat") - Vector2(0.0, 14.0 / _scale)
			var spin_t: float = 0.0 if reduced_motion else float(_state.elapsed) * 5.2
			for st_i in range(3):
				var sa: float = spin_t + TAU * float(st_i) / 3.0
				var sp := hat_pt + Vector2(cos(sa) * 26.0 / _scale, sin(sa) * 9.0 / _scale)
				var se: float = (13.0 if sin(sa) >= 0.0 else 9.0) / _scale
				draw_texture_rect(IMPACT_STAR, Rect2(sp - Vector2.ONE * se * 0.5, Vector2.ONE * se),
					false, Color(1.0, 0.92, 0.42, 0.94))
		# Transient shield shatter shards & clone dispersion poofs.
		for sh: Dictionary in _ward_shatters:
			var wp: float = clampf((float(_state.elapsed) - float(sh.at)) / 0.42, 0.0, 1.0)
			var ease_w: float = 1.0 - pow(1.0 - wp, 2.6)
			var sh_col := Color(0.70, 0.94, 1.0, 1.0 - wp)
			draw_arc(center, _character.size.x * lerpf(0.38, 0.92, ease_w), 0.0, TAU, 28,
				sh_col, maxf(1.5, lerpf(4.5, 0.8, ease_w) / _scale), true)
			var shard_n: int = 8 if bool(sh.get("shattered", false)) else 5
			for si in range(shard_n):
				var sa: float = PI * 0.45 + TAU * float(si) / float(shard_n)
				var spt: Vector2 = center + Vector2.from_angle(sa) * (_character.size.x * (0.34 + 0.55 * ease_w))
				var r_sz: float = (9.0 / _scale) * (1.0 - wp * 0.65)
				var poly := PackedVector2Array([
					spt + Vector2.from_angle(sa) * r_sz * 1.4,
					spt + Vector2.from_angle(sa + PI * 0.5) * r_sz * 0.55,
					spt - Vector2.from_angle(sa) * r_sz * 1.2,
					spt + Vector2.from_angle(sa - PI * 0.5) * r_sz * 0.55
				])
				draw_colored_polygon(poly, Color(0.84, 0.97, 1.0, (1.0 - wp) * 0.92))
		for cp: Dictionary in _clone_poofs:
			var cp_p: float = clampf((float(_state.elapsed) - float(cp.at)) / 0.36, 0.0, 1.0)
			var ease_c: float = 1.0 - pow(1.0 - cp_p, 2.5)
			var poof_center: Vector2 = _character.position + Vector2(_character.size.x * 0.22, _character.size.y * 0.5)
			var p_edge: float = _character.size.x * lerpf(0.42, 0.96, ease_c)
			draw_texture_rect(SOFT_POOF, Rect2(poof_center - Vector2.ONE * p_edge * 0.5, Vector2.ONE * p_edge),
				false, Color(0.76, 0.60, 0.98, (1.0 - cp_p) * 0.86))
			for k in range(6):
				var ka: float = TAU * float(k) / 6.0 + 0.35
				var kpt: Vector2 = poof_center + Vector2.from_angle(ka) * (_character.size.x * 0.48 * ease_c)
				var ke: float = 11.0 / _scale * (1.0 - cp_p)
				draw_texture_rect(SPARKLE, Rect2(kpt - Vector2.ONE * ke * 0.5, Vector2.ONE * ke),
					false, Color(0.86, 0.72, 1.0, 1.0 - cp_p))
		for beam: Dictionary in _beam_strikes:
			var bp: float = clampf((float(_state.elapsed) - float(beam.at)) / 0.42, 0.0, 1.0)
			var b_alpha: float = 1.0 - smoothstep(0.18, 1.0, bp)
			var b_orig: Dictionary = beam.origin
			var b_start: Vector2 = _board.position + Vector2(float(b_orig.get("column", 3)) + 0.5,
				float(b_orig.get("row", 3)) + 0.5) * _board.size.x / Model.COLUMNS
			var b_end: Vector2 = _anchor_point("face")
			var outer_w: float = maxf(2.0, lerpf(22.0, 4.0, bp) / _scale)
			var core_w: float = maxf(1.2, lerpf(9.0, 1.5, bp) / _scale)
			draw_line(b_start, b_end, Color(0.68, 0.48, 1.0, b_alpha * 0.72), outer_w, true)
			draw_line(b_start, b_end, Color(1.0, 0.96, 0.78, b_alpha * 0.96), core_w, true)
			var b_star: float = (44.0 + bp * 26.0) / _scale
			draw_texture_rect(IMPACT_STAR, Rect2(b_end - Vector2.ONE * b_star * 0.5, Vector2.ONE * b_star),
				false, Color(1.0, 0.94, 0.68, b_alpha))
		var charge: int = int(_state.get("charge", 0))
		if charge > 0:
			var charge_max: float = maxf(1.0, float(_state.get("charge_max", 20)))
			var ratio: float = clampf(float(charge) / charge_max, 0.0, 1.0)
			var power_ready: bool = charge >= Run.POWER_CHARGE_THRESHOLD
			var held_compass: Vector2 = _anchor_point("compass")
			var orbit_count: int = clampi(ceili(ratio * 5.0), 1, 5)
			var halo: float = (34.0 + ratio * 18.0) / _scale
			draw_texture_rect(GLOW, Rect2(held_compass - Vector2.ONE * halo, Vector2.ONE * halo * 2.0),
				false, Color(1.0, 0.84, 0.30, 0.22 + ratio * (0.40 if power_ready else 0.24)))
			if power_ready and not reduced_motion:
				var ray_edge: float = (46.0 + 6.0 * sin(float(_state.elapsed) * 6.0)) / _scale
				draw_texture_rect(RAYS, Rect2(held_compass - Vector2.ONE * ray_edge * 0.5, Vector2.ONE * ray_edge),
					false, Color(1.0, 0.88, 0.42, 0.45))
			for idx in range(orbit_count):
				var spin: float = 0.0 if reduced_motion else float(_state.elapsed) * (2.6 if power_ready else 1.5)
				var angle: float = spin + TAU * float(idx) / float(orbit_count)
				var radius: float = (20.0 + (4.0 if power_ready else 0.0)) / _scale
				var pt: Vector2 = held_compass + Vector2(cos(angle), sin(angle)) * radius
				var sp_edge: float = (11.0 if power_ready else 8.0) / _scale
				draw_texture_rect(SPARKLE, Rect2(pt - Vector2.ONE * sp_edge * 0.5, Vector2.ONE * sp_edge),
					false, Color(1.0, 0.90, 0.45, 0.92 if power_ready else 0.72))
			var bonus_pct: int = roundi(charge * 2.5)
			var charge_text: String = "+%d%%" % bonus_pct
			var ch_pixels: int = ceili((13.0 if power_ready else 11.0) / _scale)
			var ch_width: float = Style.HEADING_FONT.get_string_size(charge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ch_pixels).x
			var ch_color := Color("#a86414") if power_ready else Color("#6e5739")
			draw_string(Style.HEADING_FONT, held_compass + Vector2(-ch_width * 0.5, -24.0 / _scale),
				charge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ch_pixels, ch_color)
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
		var is_skill: bool = bool(event.get("skill_hit", false))
		var flight_time: float = 0.0 if (reduced_motion or is_skill) else HIT_FLIGHT_SECONDS
		var age: float = float(_state.elapsed) - float(event.at)
		if age < 0.0 or age > flight_time + 0.52:
			continue
		var origin: Dictionary = event.get("origin", {})
		var start: Vector2 = _board.position + Vector2(float(origin.get("column", floori(Model.COLUMNS * 0.5))) + 0.5,
			float(origin.get("row", 4)) + 0.5) * _board.size.x / Model.COLUMNS
		var target: Vector2 = _anchor_point("face")
		var p: float = 1.0 if flight_time <= 0.0 else clampf(age / flight_time, 0.0, 1.0)
		var level: int = int(event.get("level", 1))
		var power_hit: bool = event.kind == "player_hit" and bool(event.get("power_hit", false))
		var edge: float = (18.0 + float(level) * 2.2 + (5.0 if power_hit else 0.0)) / _scale
		var attack_dir: Vector2 = (target - start).normalized()
		if attack_dir.length_squared() < 0.01:
			attack_dir = Vector2.RIGHT
		if reduced_motion:
			draw_texture_rect(GLOW, Rect2(target - Vector2.ONE * edge, Vector2.ONE * edge * 2),
				false, Color(1, 0.88, 0.55, 0.55))
			continue
		if p < 1.0:
			var windup_split: float = 0.24
			var bolt_pos: Vector2
			if p < windup_split:
				# Brief anticipation pullback & energy gather before launch!
				var wp: float = p / windup_split
				var pull: float = sin(wp * PI * 0.85) * (16.0 if power_hit else 10.0) / _scale
				bolt_pos = start - attack_dir * pull
				var charge_r: float = edge * lerpf(1.55, 0.55, wp)
				draw_arc(bolt_pos, charge_r, 0.0, TAU, 24,
					Color("#ffcf56" if power_hit else "#fff1ad", 0.35 + 0.55 * wp), maxf(1.5, 2.6 / _scale), true)
				for gi in range(4):
					var ga: float = TAU * float(gi) / 4.0 + wp * 2.2
					var gp: Vector2 = bolt_pos + Vector2.from_angle(ga) * charge_r * 1.15
					var ge: float = 8.0 / _scale * wp
					draw_texture_rect(SPARKLE, Rect2(gp - Vector2.ONE * ge * 0.5, Vector2.ONE * ge),
						false, Color(1.0, 0.94, 0.65, 0.85))
				var core_s: float = edge * lerpf(0.65, 1.15, wp)
				draw_texture_rect(GLOW, Rect2(bolt_pos - Vector2.ONE * core_s, Vector2.ONE * core_s * 2.0), false, Color("#fff0a6"))
			else:
				# High-acceleration launch with elongated comet tail!
				var lp: float = clampf((p - windup_split) / (1.0 - windup_split), 0.0, 1.0)
				var accel: float = pow(lp, 2.3)
				var arc_h: float = (56.0 if power_hit else 44.0) / _scale
				bolt_pos = start.lerp(target, accel)
				bolt_pos.y -= sin(accel * PI) * arc_h
				var tail_steps: int = 8 if (power_hit or level >= 4) else 5
				for ti in range(tail_steps, 0, -1):
					var t_lp: float = maxf(0.0, lp - float(ti) * 0.045)
					var t_acc: float = pow(t_lp, 2.3)
					var t_pos: Vector2 = start.lerp(target, t_acc)
					t_pos.y -= sin(t_acc * PI) * arc_h
					var t_frac: float = 1.0 - float(ti) / float(tail_steps + 1)
					var t_edge: float = edge * (0.45 + t_frac * 0.75)
					var t_col := Color(1.0, 0.82, 0.35, t_frac * 0.72) if power_hit else Color(1.0, 0.92, 0.62, t_frac * 0.58)
					draw_texture_rect(GLOW, Rect2(t_pos - Vector2.ONE * t_edge, Vector2.ONE * t_edge * 2.0), false, t_col)
				draw_set_transform(bolt_pos, attack_dir.angle())
				draw_texture_rect(GLOW, Rect2(Vector2(-edge * 1.4, -edge * 0.85), Vector2(edge * 2.8, edge * 1.7)),
					false, Color("#ffd866" if power_hit else "#fff0a6"))
				draw_texture_rect(IMPACT_STAR if power_hit else SPARKLE,
					Rect2(Vector2(-edge * 0.72, -edge * 0.58), Vector2(edge * 1.44, edge * 1.16)),
					false, Color("#fff7cf"))
				draw_set_transform(Vector2.ZERO)
		else:
			var imp_age: float = age - flight_time
			var imp_p: float = clampf(imp_age / 0.52, 0.0, 1.0)
			var burst_p: float = clampf(imp_age / 0.30, 0.0, 1.0)
			if burst_p < 1.0:
				var ring_ease: float = 1.0 - pow(1.0 - burst_p, 2.8)
				var ring_r: float = edge * lerpf(0.35, 2.5 if power_hit else 1.85, ring_ease)
				draw_arc(target, ring_r, 0.0, TAU, 28,
					Color(1.0, 0.92, 0.55 if power_hit else 0.76, (1.0 - burst_p) * 0.92),
					maxf(1.5, lerpf(5.0 if power_hit else 3.2, 0.8, ring_ease) / _scale), true)
				draw_texture_rect(RAYS, Rect2(target - Vector2.ONE * edge * (2.3 if power_hit else 1.6), Vector2.ONE * edge * (4.6 if power_hit else 3.2)), false,
					Color(1, 0.85, 0.5, 1.0 - burst_p))
				if power_hit or level >= 3 or is_skill:
					var star_e: float = edge * (1.75 if power_hit else 1.25) * lerpf(0.75, 1.25, ring_ease)
					draw_texture_rect(IMPACT_STAR, Rect2(target - Vector2.ONE * star_e, Vector2.ONE * star_e * 2.0), false,
						Color(1.0, 0.94, 0.62, 1.0 - burst_p))
				# Directional hit-spark cone flying behind Pirate along attack vector
				var cone_n: int = 10 if (power_hit or is_skill) else 6
				var base_ang: float = attack_dir.angle()
				for si in range(cone_n):
					var spread_ang: float = base_ang + (float(si) / float(maxi(1, cone_n - 1)) - 0.5) * 1.45
					var s_dist: float = edge * (0.7 + float(si % 3) * 0.35) * (0.4 + 2.2 * ring_ease)
					var s_pos: Vector2 = target + Vector2.from_angle(spread_ang) * s_dist
					var s_len: float = (12.0 if power_hit else 8.5) / _scale * (1.0 - burst_p * 0.6)
					draw_set_transform(s_pos, spread_ang)
					draw_texture_rect(SPARKLE, Rect2(Vector2(-s_len, -s_len * 0.45), Vector2(s_len * 2.0, s_len * 0.9)),
						false, Color(1.0, 0.90, 0.50 if si % 2 == 0 else 0.85, 1.0 - burst_p))
				draw_set_transform(Vector2.ZERO)
			# Juicy physics-bounce damage popup with crisp dark outline!
			var text: String = "Decoy!" if event.kind == "clone_hit" else "Shield!" if event.kind == "ward_hit" \
				else "-%d!" % int(event.damage) if power_hit else "-%d" % int(event.damage)
			var pop_s: float = lerpf(0.55, 1.55 if power_hit else 1.32, clampf(imp_age / 0.085, 0.0, 1.0)) if imp_age < 0.085 \
				else lerpf(1.55 if power_hit else 1.32, 1.0, smoothstep(0.085, 0.22, imp_age))
			var txt_alpha: float = 1.0 - smoothstep(0.62, 1.0, imp_p)
			var side_vx: float = (1.0 if int(event.id) % 2 == 0 else -1.0) * (16.0 / _scale) * imp_p
			var bounce_y: float = (42.0 * imp_p - 26.0 * imp_p * imp_p) / _scale
			var pixels: int = maxi(12, ceili((23.0 if power_hit else 18.0) * pop_s / _scale))
			var width: float = Style.HEADING_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
			var txt_pos: Vector2 = target + Vector2(-width * 0.5 + side_vx, -12.0 / _scale - bounce_y)
			var outline_px: int = maxi(2, ceili((4.0 if power_hit else 3.0) / _scale))
			var fill_col := Color("#ffe066", txt_alpha) if power_hit else Color("#fff2fa", txt_alpha)
			var out_col := Color("#5e2808", txt_alpha * 0.94) if power_hit else Color("#3c1f45", txt_alpha * 0.90)
			draw_string_outline(Style.HEADING_FONT, txt_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, outline_px, out_col)
			draw_string(Style.HEADING_FONT, txt_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, fill_col)
			if power_hit or is_skill:
				var p_text: String = "STRIKE!" if is_skill else "POWER!"
				var p_px: int = maxi(10, ceili(13.0 * minf(1.2, pop_s) / _scale))
				var p_w: float = Style.HEADING_FONT.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, p_px).x
				var p_pos: Vector2 = target + Vector2(-p_w * 0.5 + side_vx, -34.0 / _scale - bounce_y)
				draw_string_outline(Style.HEADING_FONT, p_pos, p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, p_px, maxi(2, ceili(3.0 / _scale)), Color("#4d1d06", txt_alpha * 0.9))
				draw_string(Style.HEADING_FONT, p_pos, p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, p_px, Color("#ffd15c", txt_alpha))
	if _state.phase not in ["ending", "done"]:
		var held_compass: Vector2 = _anchor_point("compass")
		var edge: float = 28.0 / _scale
		draw_texture_rect(GLOW, Rect2(held_compass - Vector2.ONE * edge, Vector2.ONE * edge * 2.0),
			false, Color(1.0, 0.86, 0.42, 0.26))
		draw_texture_rect(COMPASS, Rect2(held_compass - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false)
	if _state.phase in ["ending", "done"]:
		var compass_edge: float = (64.0 if _state.outcome == "ambushed" \
			or int(_state.definition.get("id", 0)) == 8 and _state.outcome == "defeated" else 42.0) / _scale
		var compass_target: Vector2 = _anchor_point("compass")
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
		var impact_at: float = _victory_delay()
		if not reduced_motion and _state.outcome == "defeated" \
			and float(_state.ending_elapsed) >= impact_at and float(_state.ending_elapsed) < impact_at + 1.4:
			var p: float = (float(_state.ending_elapsed) - impact_at) / 1.4
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
			float(projectile.row) + 0.5) * _board.size.x / Model.COLUMNS
		var start: Vector2 = _anchor_point("face")
		var at: Vector2 = start.lerp(destination, progress)
		at.y -= 4.0 * progress * (1.0 - progress) * maxf(30 / _scale, start.distance_to(destination) * 0.24)
		var tint: Color = COLORS.get(projectile.status, Color.WHITE)
		var edge: float = 30 / _scale
		var cell_pitch: float = _board.size.x / Model.COLUMNS
		var icon: Texture2D = LOCK if projectile.status == "lock" else INK_SPLAT if projectile.status == "ink" else FROST_FLAKE if projectile.status == "freeze" else CLOCK
		if progress <= 0.0 or reduced_motion:
			var windup_ratio: float = clampf(float(projectile.elapsed) / maxf(0.01, float(projectile.windup)), 0.0, 1.0)
			var ring_radius: float = cell_pitch * (0.48 if reduced_motion else lerpf(0.66, 0.42, windup_ratio))
			draw_texture_rect(GLOW, Rect2(destination - Vector2.ONE * edge * 1.15, Vector2.ONE * edge * 2.3), false, Color(tint, 0.30 + 0.25 * windup_ratio))
			draw_arc(destination, ring_radius, 0.0, TAU, 24, Color(tint, 0.85), maxf(2.0, 3.0 / _scale), true)
			draw_texture_rect(icon, Rect2(destination - Vector2.ONE * edge * 0.28, Vector2.ONE * edge * 0.56), false, Color(1, 1, 1, 0.88))
			continue
		draw_arc(destination, cell_pitch * 0.44, 0.0, TAU, 24, Color(tint, 0.55), maxf(1.5, 2.0 / _scale), true)
		for sample in range(5):
			var tail: float = maxf(0.0, progress - sample * 0.025)
			var point: Vector2 = start.lerp(destination, tail)
			point.y -= 4.0 * tail * (1.0 - tail) * maxf(30 / _scale, start.distance_to(destination) * 0.24)
			draw_texture_rect(GLOW, Rect2(point - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color(tint, 0.5 - sample * 0.075))
		draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.35, Vector2.ONE * edge * 0.7), false, tint)
		draw_texture_rect(icon, Rect2(at - Vector2.ONE * edge * 0.25, Vector2.ONE * edge * 0.5), false)
	for item: Dictionary in _dodges:
		var event: Dictionary = item.event
		var age: float = clampf(float(_state.elapsed) - float(event.at), 0.0, 0.95)
		var p: float = age / 0.95
		var cell_pitch: float = _board.size.x / Model.COLUMNS
		var origin: Vector2 = _board.position + Vector2(float(event.get("column", 3)) + 0.5,
			float(event.get("row", 4)) + 0.5) * cell_pitch
		var alpha: float = 1.0 - smoothstep(0.55, 1.0, p)
		var rise: float = 0.0 if reduced_motion else (28.0 * p + 8.0 * sin(minf(1.0, p * 2.5) * PI)) / _scale
		var glow_edge: float = cell_pitch * (0.85 if reduced_motion else 0.75 + p * 0.45)
		draw_texture_rect(GLOW, Rect2(origin - Vector2.ONE * glow_edge * 0.5, Vector2.ONE * glow_edge),
			false, Color("#8ee6b2", alpha * 0.58))
		if not reduced_motion:
			var ring_p: float = clampf(p / 0.35, 0.0, 1.0)
			if ring_p < 1.0:
				draw_arc(origin, cell_pitch * lerpf(0.32, 0.95, 1.0 - pow(1.0 - ring_p, 2.5)), 0.0, TAU, 24,
					Color("#6de3aa", (1.0 - ring_p) * 0.85), maxf(1.5, 3.0 / _scale), true)
			# Golden counter-charge stream flying from dodged cell into Pirate's compass!
			var stream_p: float = clampf(p / 0.55, 0.0, 1.0)
			if stream_p < 1.0:
				var compass_pt: Vector2 = _anchor_point("compass")
				var ease_s: float = pow(stream_p, 1.6)
				var sp_pt: Vector2 = origin.lerp(compass_pt, ease_s)
				sp_pt.y -= sin(ease_s * PI) * 32.0 / _scale
				var sp_e: float = 15.0 / _scale * (1.0 - stream_p * 0.35)
				draw_texture_rect(GLOW, Rect2(sp_pt - Vector2.ONE * sp_e, Vector2.ONE * sp_e * 2.0),
					false, Color(1.0, 0.88, 0.42, (1.0 - stream_p) * 0.85))
				draw_texture_rect(SPARKLE, Rect2(sp_pt - Vector2.ONE * sp_e * 0.5, Vector2.ONE * sp_e),
					false, Color(1.0, 0.96, 0.72, 1.0 - stream_p))
			for index in range(4):
				var pt: Vector2 = origin + Vector2.from_angle(TAU * index / 4.0 + 0.4) * cell_pitch * p * 0.58
				var sp: float = 10.0 / _scale * (1.0 - p)
				draw_texture_rect(SPARKLE, Rect2(pt - Vector2.ONE * sp * 0.5, Vector2.ONE * sp), false, Color("#ffe896", alpha))
		var label := "Dodged!"
		var px: int = ceili(15.0 / _scale)
		var lw: float = Style.HEADING_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var dpos := origin + Vector2(-lw * 0.5, -rise)
		draw_string_outline(Style.HEADING_FONT, dpos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, ceili(3.0 / _scale)), Color("#fffef5", alpha * 0.92))
		draw_string(Style.HEADING_FONT, dpos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("#1f7a56", alpha))
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
		"presentation": "side_character", "clip": _last_pose_clip, "gesture": _gesture,
		"model": Actor.MODEL, "actor": _actor.snapshot(), "heading": "", "health_text": "",
		"health_fraction": float(_state.get("health", 0)) / maxf(1.0, float(_state.get("max_health", 1))),
		"charge": int(_state.get("charge", 0)),
		"charge_fraction": float(_state.get("charge", 0)) / maxf(1.0, float(_state.get("charge_max", 20))),
		"dodge_active": not _dodges.is_empty(),
		"energy_fraction": _energy_ratio(), "energy_ghost_fraction": _energy_ghost_ratio(), "energy_segments": 8,
		"hit_flash": _actor._hit_flash_intensity,
		"ward_shatters": _ward_shatters.size(), "clone_poofs": _clone_poofs.size(), "beam_strikes": _beam_strikes.size(),
		"impact_serial": _last_impact_event, "victory_announced": _victory_announced,
		"compass_visible": visible and not _state.is_empty(),
		"dialogue": _dialogue.text if visible and _dialogue.visible else "", "speaker": _speaker_text if visible else "",
		"animations": Array(_actor.animation_names()), "error": _actor.last_error}

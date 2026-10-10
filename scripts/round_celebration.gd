extends Control
## A presentation of a completed round. Reward ownership stays with the host.

signal performance_finished(round_id: String)
signal open_requested(round_id: String)
signal cue_requested(round_id: String, cue: String)
signal confetti_requested(round_id: String)

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const ChestView = preload("res://scripts/chest_view.gd")
const JellyRewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const DURATION: float = Mascot.CELEBRATION_SECONDS
const CUE_TIMES := [0.25, 0.9, 1.8]
const CUE_NAMES := ["step", "step-detail", "reward"]

var pip: Mascot
var chest: ChestView
var action_button: Button
var _heading: Label
var _caption: Label
var _count: Label
var _glow: TextureRect
var _round_id: String = ""
var _active: bool = false
var _ready_to_open: bool = false
var _paused: bool = false
var _automatic: bool = false
var _reduced_motion: bool = false
var _narration_playing: bool = false
var _elapsed: float = 0.0
var _rest_elapsed: float = 0.0
var _origin_frame: int = -1
var _cue_index: int = 0
var _cue_log: Array[String] = []
var _performance_emitted: bool = false
var _reward_revealed: bool = false
var _open_emitted: bool = false
var _chest_count: int = 1
var _chest_announced: bool = false
var _chest_tier: int = 0
var _score: int = -1
var _theme_id: String = "spring"
var _palette: Dictionary = {}
var _pip_rect := Rect2()
var _chest_rect := Rect2()
var _glow_rect := Rect2()


func _init() -> void:
	name = "RoundCelebration"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_glow = TextureRect.new()
	_glow.name = "TreasureGlow"
	_glow.texture = GLOW
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	pip = Mascot.new()
	pip.name = "CelebratingPip"
	pip.focus_mode = Control.FOCUS_NONE
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.set_proactive_allowed(false)
	add_child(pip)
	chest = ChestView.new()
	chest.name = "EarnedChestPreview"
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# This preview never receives hold, open or reward calls.
	chest.reduced_motion = true
	add_child(chest)
	_heading = _label("You did it!", "CelebrationTitle")
	_heading.add_theme_font_override("font", Style.HEADING_FONT)
	_caption = _label("You earned a treasure chest!", "CelebrationCaption")
	_count = _label("", "CelebrationChestCount")
	_count.add_theme_font_override("font", Style.HEADING_FONT)
	action_button = Button.new()
	action_button.name = "OpenEarnedChest"
	action_button.text = "Open chest"
	action_button.pressed.connect(_request_open)
	add_child(action_button)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	set_process(false)


func _label(text: String, node_name: String) -> Label:
	var label := Style.label(text, 18)
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func begin(round_id: String, theme_id: String, chest_manifest: Dictionary,
		chest_count: int, reduce: bool, automatic: bool = false, score: int = -1, chest_tier: int = 0, chest_announced: bool = false) -> void:
	if round_id.is_empty() or (_active and round_id == _round_id):
		return
	stop()
	_round_id = round_id
	_chest_count = maxi(0, chest_count)
	_chest_announced = chest_announced
	_chest_tier = maxi(0, chest_tier) if _chest_count > 0 else 0
	_score = score
	_reduced_motion = reduce
	_automatic = automatic
	_active = true
	_paused = false
	_origin_frame = Engine.get_process_frames()
	_heading.text = "Round results" if _score >= 0 else "You did it!"
	_caption.text = "Score: %d · Chests: %d" % [_score, _chest_count] if _score >= 0 else \
		"Every word matched!" if _chest_count == 0 else \
		"You earned a treasure chest!" if _chest_count == 1 else "You earned %d treasure chests!" % _chest_count
	if _chest_tier > 0:
		_caption.text = "Score: %d · %s" % [_score, JellyRewardProgress.title_for_tier(_chest_tier)]
	_count.text = "" if _chest_count <= 1 else "x%d" % _chest_count
	action_button.text = "Play again" if _chest_count == 0 else "Open chest" if _chest_count == 1 else "Open chests"
	chest.visible = _chest_count > 0
	_glow.visible = _chest_count > 0
	pip.set_reduced_motion(reduce)
	pip.set_idle_paused(false)
	apply_theme(theme_id, chest_manifest)
	chest.set_idle_paused(false)
	chest.set_process(false)
	_layout()
	_sync_processing()


func apply_theme(theme_id: String, chest_manifest: Dictionary) -> void:
	_theme_id = theme_id if Data.THEMES.has(theme_id) else "spring"
	_palette = Data.theme(_theme_id)
	pip.set_outfit_theme(_theme_id)
	chest.configure_skin(_palette, chest_manifest)
	chest.set_process(false)
	_layout()


func set_narration_playing(value: bool) -> void:
	_narration_playing = value
	_try_finish()


func set_reduced_motion(value: bool) -> void:
	if _reduced_motion == value:
		return
	_reduced_motion = value
	pip.set_reduced_motion(value)
	_sample()
	_sync_processing()


func pause() -> void:
	if not _active or _paused:
		return
	_paused = true
	pip.set_idle_paused(true)
	chest.set_idle_paused(true)
	_sync_processing()
	_refresh_action()


func resume() -> void:
	if not _active:
		return
	if _paused and not _ready_to_open:
		_elapsed = 0.0
		_cue_index = 0
		_cue_log.clear()
		_origin_frame = Engine.get_process_frames()
	_paused = false
	pip.set_idle_paused(false)
	chest.set_idle_paused(false)
	chest.set_process(false)
	_sample()
	_sync_processing()
	_try_finish()


func stop() -> void:
	_active = false
	_paused = false
	_ready_to_open = false
	_narration_playing = false
	_elapsed = 0.0
	_rest_elapsed = 0.0
	_cue_index = 0
	_cue_log.clear()
	_performance_emitted = false
	_reward_revealed = false
	_open_emitted = false
	_round_id = ""
	_origin_frame = -1
	pip.settle()
	pip.set_idle_paused(true)
	chest.set_idle_paused(true)
	set_process(false)
	_refresh_action()


func is_active() -> bool:
	return _active


func is_ready() -> bool:
	return _active and _ready_to_open


func current_round_id() -> String:
	return _round_id


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if _active and _ready_to_open and not _paused and not _automatic and not _open_emitted and is_visible_in_tree():
		result.append(action_button)
	return result


func default_focus() -> Control:
	return action_button if not controls().is_empty() else null


func _request_open() -> void:
	if controls().is_empty():
		return
	_open_emitted = true
	_refresh_action()
	open_requested.emit(_round_id)


func retry_open(round_id: String) -> void:
	if not _active or not _ready_to_open or _automatic or round_id != _round_id:
		return
	_open_emitted = false
	_refresh_action()


func _process(delta: float) -> void:
	if Engine.get_process_frames() != _origin_frame:
		advance(delta)


func advance(delta: float) -> void:
	if not _active or _paused or not is_visible_in_tree() or delta <= 0.0 or not is_finite(delta):
		return
	if _ready_to_open:
		if not _reduced_motion:
			_rest_elapsed += minf(delta, 0.1)
			_sample()
		return
	_elapsed = minf(DURATION, _elapsed + delta)
	var advancing_round: String = _round_id
	# Consume missed beats during a stalled frame; do not play an audio burst.
	while _cue_index < CUE_TIMES.size() and _elapsed >= float(CUE_TIMES[_cue_index]):
		var cue: String = CUE_NAMES[_cue_index]
		_cue_index += 1
		if cue == "reward":
			if _chest_count == 0 or _chest_announced:
				continue
			if not _reward_revealed:
				_reward_revealed = true
				if not _reduced_motion:
					confetti_requested.emit(_round_id)
					if not _active or _paused or _round_id != advancing_round:
						return
		if delta <= 0.5:
			_cue_log.append(cue)
			cue_requested.emit(_round_id, cue)
			if not _active or _paused or _round_id != advancing_round:
				return
	_sample()
	_try_finish()


func _try_finish() -> void:
	if not _active or _paused or _ready_to_open or not is_visible_in_tree() or _elapsed < DURATION or _narration_playing:
		return
	_ready_to_open = true
	_sample()
	_sync_processing()
	if not _performance_emitted:
		_performance_emitted = true
		performance_finished.emit(_round_id)


func _sync_processing() -> void:
	set_process(_active and not _paused and (not _ready_to_open or not _reduced_motion) and is_visible_in_tree())


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		pause()
	else:
		# The host decides when an overlay's pause can be released.
		_sample.call_deferred()
	_sync_processing()


func _refresh_action() -> void:
	action_button.visible = _active and _ready_to_open and not _automatic
	action_button.disabled = not _active or not _ready_to_open or _paused or _open_emitted


func _sample() -> void:
	if not _active:
		return
	pip.set_celebration_progress(_elapsed / DURATION, _rest_elapsed)
	pip.set_process(false)
	# ChestView renders its authored closed pose once; its mechanical clock stays off.
	chest.set_process(false)
	var reveal: float = 1.0 if _reduced_motion else smoothstep(1.8, 2.05, _elapsed)
	var settle: float = 1.0 if _reduced_motion else smoothstep(1.8, 2.45, _elapsed)
	var pop: float = 0.0 if _reduced_motion else sin(clampf((_elapsed - 1.8) / 0.58, 0.0, 1.0) * PI)
	chest.modulate = Color(1, 1, 1, reveal)
	chest.pivot_offset = chest.size * Vector2(0.5, 0.75)
	chest.scale = Vector2.ONE * (1.0 if _reduced_motion else lerpf(0.80, 1.0, reveal) + pop * 0.055)
	chest.position = _chest_rect.position + Vector2(0, 14.0 * (1.0 - reveal) / maxf(0.25, Style.ui_scale(self)))
	var glow_amount: float = 0.0 if _reduced_motion else reveal * (0.40 + pop * 0.16) * (1.0 - smoothstep(2.05, 2.5, _elapsed))
	_glow.modulate = Color(_palette.get("spark", Color("#f8d574")), glow_amount)
	_glow.pivot_offset = _glow.size * 0.5
	_glow.scale = Vector2.ONE * (1.0 if _reduced_motion else 0.94 + pop * 0.09)
	_heading.modulate.a = 1.0 if _reduced_motion or _score >= 0 else smoothstep(0.0, 0.25, _elapsed)
	_caption.modulate.a = 1.0 if _reduced_motion or _score >= 0 else smoothstep(1.8, 2.18, _elapsed)
	_count.modulate.a = reveal * settle
	_refresh_action()


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor: float = maxf(0.25, Style.ui_scale(self))
	var w: float = size.x * scale_factor
	var h: float = size.y * scale_factor
	var compact: bool = h < 350.0
	var title_h: float = 40.0 if compact else 54.0
	var caption_h: float = 25.0 if compact else 32.0
	var action_h: float = 44.0 if compact else 50.0
	var gap: float = 5.0 if compact else 12.0
	var available: float = maxf(48.0, h - title_h - caption_h - action_h - gap * 3.0)
	var hero_height: float = minf(280.0, minf(available, w * 0.70))
	var hero_width: float = minf(w - 12.0, hero_height * 1.82)
	var pip_side: float = minf(hero_height, hero_width * 0.59)
	if _chest_count == 0:
		pip_side = hero_height
	var chest_side: float = minf(hero_height * 0.85, hero_width * 0.46)
	var total: float = title_h + hero_height + caption_h + action_h + gap * 3.0
	var top: float = maxf(0.0, (h - total) * 0.42)
	var left: float = (w - hero_width) * 0.5
	var hero_top: float = top + title_h + gap
	_place(_heading, Rect2(4.0, top, w - 8.0, title_h), scale_factor)
	_heading.add_theme_font_size_override("font_size", ceili((28.0 if compact else 38.0) / scale_factor))
	_pip_rect = Rect2(Vector2(left, hero_top + hero_height - pip_side) / scale_factor, Vector2.ONE * pip_side / scale_factor)
	if _chest_count == 0:
		_pip_rect.position.x = (w - pip_side) * 0.5 / scale_factor
	_chest_rect = Rect2(Vector2(left + hero_width - chest_side, hero_top + hero_height - chest_side * 0.91) / scale_factor, Vector2.ONE * chest_side / scale_factor)
	pip.custom_minimum_size = Vector2.ZERO
	pip.position = _pip_rect.position
	pip.size = _pip_rect.size
	chest.position = _chest_rect.position
	chest.size = _chest_rect.size
	_glow_rect = Rect2(_chest_rect.get_center() - _chest_rect.size * 0.60, _chest_rect.size * 1.20)
	_glow.position = _glow_rect.position
	_glow.size = _glow_rect.size
	var caption_y: float = hero_top + hero_height + gap
	_place(_caption, Rect2(4, caption_y, w - 8, caption_h), scale_factor)
	_caption.add_theme_font_size_override("font_size", ceili((14.0 if compact else 17.0) / scale_factor))
	_caption.add_theme_color_override("font_color", _palette.get("accent", Style.GOOD))
	_place(_count, Rect2((left + hero_width - chest_side * 0.40), hero_top + hero_height - 25.0, chest_side * 0.4, 26.0), scale_factor)
	_count.add_theme_font_size_override("font_size", ceili((17.0 if compact else 22.0) / scale_factor))
	_count.add_theme_color_override("font_color", Style.INK)
	Style.action_button(action_button, _palette.get("accent", Style.GOOD), true)
	action_button.custom_minimum_size.y = action_h / scale_factor
	var action_w: float = minf(230.0, w - 16.0)
	_place(action_button, Rect2((w - action_w) * 0.5, caption_y + caption_h + gap, action_w, action_h), scale_factor)
	_sample()


func _place(control: Control, rect: Rect2, scale_factor: float) -> void:
	control.position = rect.position / scale_factor
	control.size = rect.size / scale_factor


func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func snapshot() -> Dictionary:
	return {"round_id": _round_id, "theme": _theme_id, "active": _active, "ready": _ready_to_open,
		"paused": _paused, "automatic": _automatic, "elapsed": _elapsed, "duration": DURATION,
		"narration_playing": _narration_playing, "reduced_motion": _reduced_motion,
		"chest_count": _chest_count, "chest_tier": _chest_tier, "chest_visible": chest.is_visible_in_tree(), "chest_announced": _chest_announced,
		"reward_revealed": _reward_revealed,
		"cue_log": _cue_log.duplicate(),
		"title": _heading.text, "caption": _caption.text, "score": _score,
		"performance_emitted": _performance_emitted, "open_emitted": _open_emitted,
		"action": {"rect": _rect(action_button.get_global_rect()), "visible": action_button.is_visible_in_tree(),
			"disabled": action_button.disabled, "text": action_button.text},
		"pip_rect": _rect(pip.get_global_rect()), "chest_rect": _rect(chest.get_global_rect()),
		"expression": pip.expression_name(), "chest_mode": chest.mode}

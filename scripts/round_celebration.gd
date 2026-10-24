extends Control
## A presentation of a completed round. Reward ownership stays with the host.

signal performance_finished(round_id: String)
signal open_requested(round_id: String)
signal home_requested
signal replay_requested(round_id: String)
signal cue_requested(round_id: String, cue: String)
signal confetti_requested(round_id: String)

const RewardLayout = preload("res://scripts/round_reward_layout.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const ChestView = preload("res://scripts/chest_view.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const DURATION: float = Mascot.CELEBRATION_SECONDS
const MOVE_START: float = 1.46
const MOVE_END: float = 1.78
const CHEST_START: float = 1.8
const CHEST_LAND: float = 2.08
const CHEST_SETTLED: float = 2.42
const INVITATION_END: float = 2.72
const CUE_TIMES := [0.25, 0.9, 1.8]
const CUE_NAMES := ["step", "step-detail", "reward"]

var pip: Mascot
var chest: ChestView
var action_button: Button
var home_button: Button
var replay_button: Button
var _early_replay: bool = false
var _replay_blocked: bool = false
var _heading: Label
var _caption: Label
var _summary: Label
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
var _chest_reward: Dictionary = {}
var _chest_announced: bool = false
var _chest_tier: int = 0
var _score: int = -1
var _theme_id: String = "spring"
var _palette: Dictionary = {}
var _pip_rect := Rect2()
var _pip_center_rect := Rect2()
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
	_summary = _label("", "CelebrationSummary")
	_count = _label("", "CelebrationChestCount")
	_count.add_theme_font_override("font", Style.HEADING_FONT)
	action_button = Button.new()
	action_button.name = "CelebrationReplay"
	action_button.text = "Play again"
	action_button.pressed.connect(_request_open)
	add_child(action_button)
	home_button = Button.new()
	home_button.name = "CelebrationHome"
	home_button.text = "Home"
	home_button.pressed.connect(func() -> void:
		if _active and not _paused and not _open_emitted and home_button.is_visible_in_tree():
			home_requested.emit())
	add_child(home_button)
	replay_button = Button.new()
	replay_button.name = "CelebrationEarlyReplay"
	replay_button.text = "Play again"
	replay_button.set("accessibility_name", "Play again")
	replay_button.pressed.connect(func() -> void:
		if controls().has(replay_button) and not replay_button.disabled:
			replay_requested.emit(_round_id))
	UiClick.bind_button(replay_button)
	add_child(replay_button)
	replay_button.hide()
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
		chest_count: int, reduce: bool, automatic: bool = false, score: int = -1, chest_tier: int = 0, chest_announced: bool = false, summary: String = "", early_replay: bool = false) -> void:
	if round_id.is_empty() or (_active and round_id == _round_id):
		return
	stop()
	_early_replay = early_replay
	_replay_blocked = false
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
	_caption.text = "Hold the chest to open" if _chest_count > 0 else "Every word matched!"
	_summary.text = summary if not summary.is_empty() else "Score: %d · Chests: %d" % [_score, _chest_count] if _score >= 0 else ""
	_summary.visible = _score >= 0
	_count.text = "" if _chest_count <= 1 else "x%d" % _chest_count
	action_button.text = "Play again"
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


func set_chest_reward(quote: Dictionary) -> void:
	_chest_reward = quote.duplicate(true)
	_layout()


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
	_chest_reward.clear()
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
	if not _active or _paused or _open_emitted or not is_visible_in_tree():
		return result
	result.append(home_button)
	if _early_replay and not _replay_blocked:
		result.append(replay_button)
	elif not _early_replay and _ready_to_open and not _automatic and _chest_count == 0:
		result.append(action_button)
	return result


func default_focus() -> Control:
	if controls().has(replay_button):
		return replay_button
	return action_button if _ready_to_open and controls().has(action_button) else null


func _request_open() -> void:
	if not controls().has(action_button):
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
	# Keep the pressed control alive across the automatic settlement handoff.
	# Its release must either activate the action or cancel before we replace it.
	if home_button.is_pressed() or (_early_replay and replay_button.is_pressed()):
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


func set_replay_blocked(value: bool) -> void:
	_replay_blocked = value
	_refresh_action()


func _refresh_action() -> void:
	action_button.visible = _active and _ready_to_open and not _automatic and _chest_count == 0 and not _early_replay
	action_button.disabled = not _active or not _ready_to_open or _paused or _open_emitted or _chest_count > 0
	replay_button.visible = _active and _early_replay
	replay_button.disabled = not _active or _paused or _open_emitted or _replay_blocked
	home_button.visible = _active
	home_button.disabled = not _active or _paused or _open_emitted


func _sample() -> void:
	if not _active:
		return
	pip.set_celebration_progress(_elapsed / DURATION, _rest_elapsed)
	pip.set_process(false)
	# Pip owns the center for the dance, then clears the chest's stage in one step.
	var s: float = maxf(0.25, Style.ui_scale(self))
	var move: float = 1.0 if _reduced_motion or _chest_count == 0 else smoothstep(MOVE_START, MOVE_END, _elapsed)
	pip.size = _pip_center_rect.size.lerp(_pip_rect.size, move)
	pip.position = _pip_center_rect.position.lerp(_pip_rect.position, move)
	if not _reduced_motion and _chest_count > 0:
		pip.position.y -= sin(move * PI) * 8.0 / s
	pip.modulate.a = 1.0 if _reduced_motion else smoothstep(0.0, 0.16, _elapsed)
	# ChestView renders its authored closed pose once; its mechanical clock stays off.
	chest.set_process(false)
	var reveal: float = (1.0 if _elapsed >= CHEST_START else 0.0) if _reduced_motion else smoothstep(CHEST_START, CHEST_START + 0.14, _elapsed)
	var settle: float = smoothstep(CHEST_START, CHEST_SETTLED, _elapsed)
	chest.modulate = Color(1, 1, 1, reveal)
	chest.scale = Vector2.ONE
	var drop: float = 1.0 - pow(1.0 - clampf((_elapsed - CHEST_START) / (CHEST_LAND - CHEST_START), 0.0, 1.0), 3.0)
	var rebound: float = clampf((_elapsed - CHEST_LAND) / (CHEST_SETTLED - CHEST_LAND), 0.0, 1.0)
	var lift: float = 0.0 if _reduced_motion else -32.0 * (1.0 - drop) - sin(rebound * PI) * (1.0 - rebound) * 7.0
	chest.position = _chest_rect.position + Vector2(0, lift / s)
	var glow_amount: float = 0.0 if _reduced_motion else reveal * 0.44 * (1.0 - smoothstep(CHEST_SETTLED, INVITATION_END, _elapsed))
	_glow.modulate = Color(_palette.get("spark", Color("#f8d574")), glow_amount)
	var invitation: bool = _chest_count > 0 and _elapsed >= CHEST_SETTLED
	_heading.text = ("You earned a chest!" if _chest_count == 1 else "You earned %d chests!" % _chest_count) if invitation else "Round complete" if _score >= 0 else "You did it!"
	_heading.modulate.a = 1.0 if _reduced_motion else smoothstep(0.0, 0.20, _elapsed)
	if not _reduced_motion and _chest_count > 0:
		_heading.modulate.a *= smoothstep(CHEST_SETTLED, CHEST_SETTLED + 0.16, _elapsed) if invitation else 1.0 - smoothstep(CHEST_SETTLED - 0.12, CHEST_SETTLED, _elapsed)
	var caption_start: float = CHEST_SETTLED + 0.12 if _chest_count > 0 else CHEST_START
	_caption.modulate.a = (1.0 if _elapsed >= caption_start else 0.0) if _reduced_motion else smoothstep(caption_start, INVITATION_END, _elapsed)
	if _chest_count > 0 and _narration_playing:
		_caption.modulate.a = 0.0
	_count.modulate.a = reveal * settle
	_refresh_action()


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor: float = maxf(0.25, Style.ui_scale(self))
	var layout: Dictionary = RewardLayout.measure(size, scale_factor, _chest_count > 0, false, _score >= 0, not _chest_reward.is_empty())
	for item: Array in [[_heading, "heading"], [_summary, "summary"], [_caption, "caption"], [pip, "pip"], [chest, "chest"],
		[home_button, "home"], [action_button, "replay"], [replay_button, "replay"]]:
		var control: Control = item[0]
		var rect: Rect2 = layout[item[1]]
		control.custom_minimum_size = Vector2.ZERO
		control.position = rect.position
		control.size = rect.size
	_pip_rect = layout.pip
	_pip_center_rect = layout.pip_center
	_chest_rect = layout.chest
	_glow_rect = Rect2(_chest_rect.get_center() - _chest_rect.size * 0.60, _chest_rect.size * 1.20)
	_glow.position = _glow_rect.position
	_glow.size = _glow_rect.size
	_heading.add_theme_font_size_override("font_size", layout.heading_size)
	_caption.add_theme_font_size_override("font_size", layout.caption_size)
	_summary.add_theme_font_size_override("font_size", layout.summary_size)
	_caption.add_theme_color_override("font_color", Style.MUTED)
	_count.position = _chest_rect.end - Vector2(54, 30) / scale_factor
	_count.size = Vector2(50, 26) / scale_factor
	_count.add_theme_font_size_override("font_size", ceili(22.0 / scale_factor))
	Style.action_button(action_button, _palette.get("accent", Style.GOOD), true)
	Style.action_button(replay_button, _palette.get("accent", Style.GOOD), true)
	Style.action_button(home_button, _palette.get("accent", Style.GOOD))
	_sample()


func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func snapshot() -> Dictionary:
	return {"round_id": _round_id, "theme": _theme_id, "active": _active, "ready": _ready_to_open,
		"paused": _paused, "automatic": _automatic, "elapsed": _elapsed, "duration": DURATION,
		"narration_playing": _narration_playing, "reduced_motion": _reduced_motion,
		"chest_count": _chest_count, "chest_tier": _chest_tier, "chest_visible": chest.is_visible_in_tree(), "chest_announced": _chest_announced,
		"chest_reward": _chest_reward.duplicate(true),
		"reward_revealed": _reward_revealed,
		"cue_log": _cue_log.duplicate(),
		"title": _heading.text, "caption": _caption.text, "summary": _summary.text, "score": _score,
		"stage": "ready" if _ready_to_open else "invitation" if _elapsed >= CHEST_SETTLED else "chest_arrival" if _elapsed >= CHEST_START and _chest_count > 0 else "move_aside" if _elapsed >= MOVE_START and _chest_count > 0 else "celebrating",
		"chest_opacity": chest.modulate.a, "caption_opacity": _caption.modulate.a,
		"performance_emitted": _performance_emitted, "open_emitted": _open_emitted,
		"action": {"rect": _rect(action_button.get_global_rect()), "visible": action_button.is_visible_in_tree(),
			"disabled": action_button.disabled, "text": action_button.text},
		"home": {"rect": _rect(home_button.get_global_rect()), "visible": home_button.is_visible_in_tree(), "disabled": home_button.disabled},
		"replay": {"rect": _rect(replay_button.get_global_rect()), "visible": replay_button.is_visible_in_tree(),
			"disabled": replay_button.disabled, "text": replay_button.text},
		"pip_rect": _rect(pip.get_global_rect()), "chest_rect": _rect(chest.get_global_rect()),
		"expression": pip.expression_name(), "chest_mode": chest.mode}

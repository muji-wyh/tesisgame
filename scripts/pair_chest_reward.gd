extends Control
## Nonmodal pair feedback. The caller owns the roll, reward and saved receipt.

signal cue_requested(round_id: String, cue: String)

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const ChestView = preload("res://scripts/chest_view.gd")
const RewardConfetti = preload("res://scripts/reward_confetti.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const REVEAL_SECONDS: float = 0.12
const REWARD_SECONDS: float = 1.95
const MISS_SECONDS: float = 0.80

var chest: ChestView
var _title: Label
var _confetti: RewardConfetti
var _round_id: String = ""
var _theme_id: String = "spring"
var _manifest: Dictionary = {}
var _palette: Dictionary = {}
var _earned: bool = false
var _performance_active: bool = false
var _paused: bool = false
var _reduced_motion: bool = false
var _elapsed: float = 0.0
var _revealed: bool = false
var _serial: int = 0
var _cue_log: Array[String] = []
var _anchor := Rect2()
var _toast_rect := Rect2()
var _chest_rect := Rect2()
var _surface: StyleBoxFlat
var _surface_key: Array = []
var _render_until_frame: int = -1


func _init() -> void:
	name = "PairChestReward"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	z_index = 70
	chest = ChestView.new()
	chest.name = "PairClosedChest"
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest.reduced_motion = true
	add_child(chest)
	_title = Style.label("", 14)
	_title.name = "PairRewardStatus"
	_title.add_theme_font_override("font", Style.HEADING_FONT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_title)
	_confetti = RewardConfetti.new()
	# Only the paper leaves the compact HUD row; it completes its full viewport fall.
	_confetti.top_level = true
	add_child(_confetti)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	hide()
	set_process(false)


func _ready() -> void:
	_prepare_chest()
	_sample()


func configure(round_id: String, theme_id: String, chest_manifest: Dictionary, reduce: bool) -> bool:
	if round_id.is_empty():
		return false
	var chosen: String = theme_id if Data.THEMES.has(theme_id) else "spring"
	var palette: Dictionary = Data.theme(chosen)
	var styles: Variant = chest_manifest.get("styles")
	if not styles is Dictionary or not styles.get(str(palette.get("chest", ""))) is Dictionary:
		return false
	if round_id != _round_id:
		clear()
	_round_id = round_id
	_theme_id = chosen
	_palette = palette
	_manifest = chest_manifest
	_reduced_motion = reduce
	_prepare_chest()
	_sample()
	return true


func show_pair_result(round_id: String, earned: bool, notify_miss: bool = true) -> bool:
	if _round_id.is_empty() or round_id != _round_id or _earned or (not earned and not notify_miss):
		return false
	_serial += 1
	_earned = earned
	_elapsed = 0.0
	_revealed = false
	_cue_log.clear()
	_performance_active = true
	_sample()
	return true


func set_toast_bounds(rect: Rect2) -> void:
	if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x < 0.0 or rect.size.y < 0.0:
		return
	if _anchor.is_equal_approx(rect):
		return
	# The host reserves this compact HUD row above the cards, in local coordinates.
	_anchor = rect
	_layout()
	_warm_chest()


func set_paused(value: bool) -> void:
	if value == _paused:
		return
	var resuming: bool = _paused and not value
	_paused = value
	_sample()
	if resuming:
		_warm_chest()


func set_reduced_motion(value: bool) -> void:
	if value == _reduced_motion:
		return
	_reduced_motion = value
	_sample()


func advance(delta: float) -> void:
	_maintain_chest_render()
	if not _performance_active or _paused or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	var generation: int = _serial
	var duration: float = REWARD_SECONDS if _earned else MISS_SECONDS
	_elapsed = minf(duration, _elapsed + delta)
	if _earned and not _revealed and _elapsed >= REVEAL_SECONDS:
		_revealed = true
		_cue_log.append("reward")
		cue_requested.emit(_round_id, "reward")
		# A host may leave the round, mute or reconfigure while handling the cue.
		if generation != _serial or _round_id.is_empty():
			return
	if _elapsed >= duration:
		_performance_active = false
	_sample()


func clear() -> void:
	_serial += 1
	_round_id = ""
	_earned = false
	_performance_active = false
	_paused = false
	_elapsed = 0.0
	_revealed = false
	_render_until_frame = -1
	_cue_log.clear()
	_confetti.hide()
	chest.hide()
	chest.set_idle_paused(true)
	_title.text = ""
	hide()
	queue_redraw()


func snapshot() -> Dictionary:
	return {"round_id": _round_id, "theme_id": _theme_id,
		"active": _performance_active or _earned, "performance_active": _performance_active,
		"earned": _earned, "paused": _paused, "reduced_motion": _reduced_motion,
		"elapsed": _elapsed, "revealed": _revealed, "message": _title.text,
		"confetti_visible": _confetti.is_visible_in_tree(), "cue_log": _cue_log.duplicate(),
		"anchor": _anchor, "toast_rect": _toast_rect, "chest_rect": _chest_rect,
		"chest_mode": chest.mode, "mouse_filter": mouse_filter}


func _prepare_chest() -> void:
	if not is_inside_tree() or _manifest.is_empty() or _palette.is_empty():
		return
	chest.configure_skin(_palette, _manifest)
	# No opening or mechanical clock belongs to this earned-chest preview.
	chest.reduced_motion = true
	chest.set_idle_paused(true)
	chest.set_process(false)
	_warm_chest()


func _sample() -> void:
	var was_visible: bool = chest.is_visible_in_tree()
	visible = not _round_id.is_empty() and (_performance_active or _earned)
	chest.visible = _earned
	_title.text = "Chest found!" if _earned and _performance_active else "Chest ready" if _earned else "No chest this pair" if _performance_active else ""
	_confetti.sample(_elapsed - REVEAL_SECONDS if _earned and _revealed and _performance_active
		and not _paused and not _reduced_motion and is_visible_in_tree() else -1.0)
	_layout()
	if not was_visible and chest.is_visible_in_tree():
		_warm_chest()
	else:
		_maintain_chest_render()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_confetti.hide()
		_maintain_chest_render()
	else:
		_warm_chest()


func _warm_chest() -> void:
	if _earned and not _paused and chest.is_visible_in_tree():
		_render_until_frame = Engine.get_process_frames() + 3
	_maintain_chest_render()


func _maintain_chest_render() -> void:
	# Render a newly visible closed model, then retain the texture without an idle
	# render loop. Neither its native mechanical clock nor its opening can run here.
	var warm: bool = _earned and not _paused and chest.is_visible_in_tree() and Engine.get_process_frames() < _render_until_frame
	chest.set_idle_paused(not warm)
	chest.set_process(false)


func _layout() -> void:
	var unit: float = 1.0 / Style.ui_scale(self)
	var available: Rect2 = _anchor
	if not available.has_area():
		available = Rect2(Vector2.ZERO, size)
	if not available.has_area():
		return
	var desired_width: float = (210.0 if _earned and _performance_active else 184.0 if _earned else 170.0) * unit
	var width: float = minf(desired_width, available.size.x)
	var height: float = minf(46.0 * unit, available.size.y)
	_toast_rect = Rect2(available.get_center() - Vector2(width, height) * 0.5, Vector2(width, height))
	var accent: Color = _palette.get("accent", Style.GOOD)
	var surface_key: Array = [height, unit, accent, _earned]
	if _surface == null or _surface_key != surface_key:
		_surface_key = surface_key
		_surface = Style.box(Color.WHITE.lerp(accent.lightened(0.82), 0.24), Color(accent, 0.14), ceili(height * 0.5), 1)
		_surface.shadow_color = Color(Style.INK, 0.055 if _earned else 0.0)
		_surface.shadow_size = ceili(3.0 * unit)
		_surface.shadow_offset = Vector2(0, 1.5 * unit)
	var edge: float = minf(height * 1.12, 51.0 * unit)
	_chest_rect = Rect2(Vector2(_toast_rect.position.x + 5.0 * unit,
		_toast_rect.get_center().y - edge * 0.5), Vector2.ONE * edge)
	chest.position = _chest_rect.position
	chest.size = _chest_rect.size
	chest.pivot_offset = Vector2(edge * 0.5, edge * 0.82)
	chest.scale = Vector2.ONE
	chest.rotation = 0.0
	var text_left: float = _chest_rect.end.x + 4.0 * unit if _earned else _toast_rect.position.x + 8.0 * unit
	_title.position = Vector2(text_left, _toast_rect.position.y)
	_title.size = Vector2(maxf(0.0, _toast_rect.end.x - text_left - 12.0 * unit), height)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _earned else HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", maxi(10, roundi((14.0 if _earned else 12.0) * unit)))
	_title.add_theme_color_override("font_color", Style.INK if _earned else Style.MUTED)
	if _earned and _performance_active and not _reduced_motion:
		var pop: float = sin(clampf((_elapsed - REVEAL_SECONDS) / 0.56, 0.0, 1.0) * PI)
		var settle: float = sin(clampf((_elapsed - 0.68) / 0.24, 0.0, 1.0) * PI)
		chest.position.y -= pop * 4.0 * unit
		chest.scale = Vector2.ONE * (1.0 + pop * 0.12 + settle * 0.025)
		chest.rotation = -sin(clampf(_elapsed / 0.68, 0.0, 1.0) * TAU) * 0.045 * pop
	var opacity: float = 1.0
	if not _earned and _performance_active and not _reduced_motion:
		opacity = smoothstep(0.0, 0.08, _elapsed) * (1.0 - smoothstep(0.52, MISS_SECONDS, _elapsed))
	_title.modulate.a = opacity
	queue_redraw()


func _draw() -> void:
	if not visible or not _toast_rect.has_area() or _surface == null:
		return
	if _earned:
		draw_style_box(_surface, _toast_rect)
	if not _earned or not _performance_active or _reduced_motion:
		return
	var t: float = _elapsed - REVEAL_SECONDS
	if t < 0.0:
		return
	var accent: Color = _palette.get("spark", Color("#ffd777"))
	var center: Vector2 = _chest_rect.get_center()
	var edge: float = _chest_rect.size.x
	var glow: float = (1.0 - smoothstep(0.24, 0.86, t)) * 0.42
	draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * edge * 0.64, Vector2.ONE * edge * 1.28), false, Color(accent, glow))
	draw_set_transform(center, t * 0.18)
	draw_texture_rect(RAYS, Rect2(Vector2.ONE * -edge * 0.66, Vector2.ONE * edge * 1.32), false, Color(accent.lightened(0.18), glow * 0.6))
	draw_set_transform(Vector2.ZERO)
	for index in range(3):
		var age: float = t - float(index) * 0.07
		if age < 0.0 or age >= 0.58:
			continue
		var direction: Vector2 = Vector2.from_angle(-2.55 + float(index) * 0.97)
		var point: Vector2 = center + direction * edge * (0.38 + age * 0.15)
		var star_size: float = edge * 0.24 * sin(age / 0.58 * PI)
		draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * star_size * 0.5, Vector2.ONE * star_size), false,
			Color(accent.lightened(0.5), 1.0 - age / 0.58))

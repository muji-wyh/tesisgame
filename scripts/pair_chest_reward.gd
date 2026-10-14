extends Control
## Nonmodal pair feedback. The caller owns the roll, reward and saved receipt.

signal cue_requested(round_id: String, cue: String)
signal confetti_requested(round_id: String)

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const ChestView = preload("res://scripts/chest_view.gd")
const RewardModel = preload("res://scripts/chest_reward_model.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const Flight = preload("res://scripts/chest_reward_flight.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const REVEAL_SECONDS: float = Flight.REVEAL_SECONDS
const REWARD_SECONDS: float = 3.25
const MISS_SECONDS: float = 0.80
const DISCOVERY_MESSAGE: String = "You found a hidden treasure chest!"

var chest: ChestView
var _title: Label
var _discovery: Label
var _discovery_rect := Rect2()
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
var _surface_layer := Node2D.new()
var _surface_key: Array = []
var _render_until_frame: int = -1
var _models: RewardModel
var _model_tier: int = 0
var _model_sample: Dictionary = {}
var _effect := Node2D.new()
var _overlay := CanvasLayer.new()
var _glow := Node2D.new()
var _pose: Dictionary = {}
var _art_rect := Rect2()


func _init() -> void:
	name = "PairChestReward"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	z_index = 70
	add_child(_surface_layer)
	_surface_layer.draw.connect(_draw_status_surface)
	_overlay.layer = 70
	_overlay.visible = false
	add_child(_overlay)
	_overlay.add_child(_glow)
	_glow.draw.connect(_draw_chest_glow)
	chest = ChestView.new()
	chest.name = "PairClosedChest"
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest.reduced_motion = true
	_overlay.add_child(chest)
	_title = Style.label("", 14)
	_title.name = "PairRewardStatus"
	_title.add_theme_font_override("font", Style.HEADING_FONT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_title)
	_models = RewardModel.new()
	add_child(_models)
	_overlay.add_child(_effect)
	_effect.draw.connect(_draw_chest_effect)
	_discovery = Style.label(DISCOVERY_MESSAGE, 22)
	_discovery.name = "ChestDiscoveryMessage"
	_discovery.add_theme_font_override("font", Style.HEADING_FONT)
	_discovery.add_theme_color_override("font_color", Style.INK)
	_discovery.add_theme_color_override("font_outline_color", Color.WHITE)
	_discovery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discovery.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_discovery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_discovery.max_lines_visible = 2
	_discovery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_discovery)
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
		if not _reduced_motion:
			confetti_requested.emit(_round_id)
			if generation != _serial or _round_id.is_empty():
				return
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
	_model_sample.clear()
	_pose.clear()
	_models.clear()
	_overlay.visible = false
	_glow.queue_redraw()
	_effect.queue_redraw()
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
		"discovery_visible": _discovery.is_visible_in_tree(), "discovery_rect": _discovery_rect,
		"cue_log": _cue_log.duplicate(),
		"anchor": _anchor, "toast_rect": _toast_rect, "chest_rect": _chest_rect,
		"motion": _pose.duplicate(), "live_turn": not _model_sample.is_empty(), "overlay_visible": _overlay.visible,
		"chest_mode": chest.mode, "mouse_filter": mouse_filter}


func _prepare_chest() -> void:
	if not is_inside_tree() or _manifest.is_empty() or _palette.is_empty():
		return
	chest.configure_skin(_palette, _manifest)
	# No opening or mechanical clock belongs to this earned-chest preview.
	chest.reduced_motion = true
	chest.set_idle_paused(true)
	chest.set_process(false)
	_model_tier = RewardProgress.THEMES.find(_theme_id) + 1
	if _model_tier > 4:
		_model_tier = 0
	if not _reduced_motion:
		_models.prepare(_model_tier)
	_warm_chest()


func _sample() -> void:
	var was_visible: bool = chest.is_visible_in_tree()
	visible = not _round_id.is_empty() and (_performance_active or _earned)
	chest.visible = _earned
	_title.text = DISCOVERY_MESSAGE if _earned else "No chest this pair" if _performance_active else ""
	_layout()
	if not was_visible and chest.is_visible_in_tree():
		_warm_chest()
	else:
		_maintain_chest_render()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_maintain_chest_render()
	else:
		_warm_chest()


func _warm_chest() -> void:
	if _earned and not _paused and chest.is_visible_in_tree():
		_render_until_frame = Engine.get_process_frames() + 3
	_maintain_chest_render()


func _maintain_chest_render() -> void:
	_sync_overlay()
	# Render a newly visible closed model, then retain the texture without an idle
	# render loop. Neither its native mechanical clock nor its opening can run here.
	var warm: bool = _earned and not _paused and chest.is_visible_in_tree() and Engine.get_process_frames() < _render_until_frame
	chest.set_idle_paused(not warm)
	chest.set_process(false)
	_models.set_active(_earned and _performance_active and _elapsed < Flight.PERFORMANCE_SECONDS and not _paused
		and not _reduced_motion and is_visible_in_tree())


func _sync_overlay() -> void:
	if not is_inside_tree():
		return
	# The flight crosses the bounded board, while its coordinates remain local
	# to the original reward row. CanvasLayer bypasses ancestor clipping only.
	_overlay.transform = get_global_transform_with_canvas()
	_overlay.visible = _earned and not _paused and is_visible_in_tree()


func _layout() -> void:
	var unit: float = 1.0 / Style.ui_scale(self)
	var available: Rect2 = _anchor
	if not available.has_area():
		available = Rect2(Vector2.ZERO, size)
	if not available.has_area():
		return
	# Keep the resting chest in one place before and after the flight.
	var desired_width: float = (324.0 if _earned else 170.0) * unit
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
	chest.modulate.a = 1.0
	_art_rect = chest.closed_art_rect()
	var text_left: float = _chest_rect.end.x + 4.0 * unit if _earned else _toast_rect.position.x + 8.0 * unit
	_title.position = Vector2(text_left, _toast_rect.position.y)
	_title.size = Vector2(maxf(0.0, _toast_rect.end.x - text_left - 12.0 * unit), height)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _earned else HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var title_font_size: int = maxi(10, roundi((13.0 if _earned else 12.0) * unit))
	while title_font_size > maxi(9, roundi(10.0 * unit)) and Style.HEADING_FONT.get_multiline_string_size(
		_title.text, HORIZONTAL_ALIGNMENT_LEFT, _title.size.x, title_font_size).y > height:
		title_font_size -= 1
	_title.add_theme_font_size_override("font_size", title_font_size)
	_title.add_theme_color_override("font_color", Style.INK if _earned else Style.MUTED)
	_sample_chest_motion(unit)
	var opacity: float = 1.0
	if not _earned and _performance_active and not _reduced_motion:
		opacity = smoothstep(0.0, 0.08, _elapsed) * (1.0 - smoothstep(0.52, MISS_SECONDS, _elapsed))
	_title.modulate.a = opacity
	if _earned and not _pose.is_empty():
		_title.modulate.a *= 1.0 - float(_pose.emphasis)
	_surface_layer.modulate.a = _title.modulate.a
	_surface_layer.queue_redraw()
	_sync_overlay()
	_layout_discovery(unit)
	_glow.queue_redraw()
	_effect.queue_redraw()


func _layout_discovery(unit: float) -> void:
	_discovery.visible = _earned and _revealed and _performance_active and _elapsed < Flight.PERFORMANCE_SECONDS
	if not _discovery.visible or not is_inside_tree():
		return
	var safe: Rect2 = (get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()).grow(-12.0 * unit)
	var width: float = minf(260.0 * unit, safe.size.x)
	var font_size: int = maxi(12, roundi((20.0 if safe.size.x < 430.0 * unit else 22.0) * unit))
	_discovery.add_theme_font_size_override("font_size", font_size)
	_discovery.add_theme_constant_override("outline_size", maxi(2, roundi(5.0 * unit)))
	var height: float = Style.HEADING_FONT.get_height(font_size) * 2.0 + float(_discovery.get_theme_constant("line_spacing"))
	# Keep the caption at the showcase while the chest returns to its HUD row.
	# Reduced motion retains this same static, legible acknowledgement.
	var peak: float = minf(176.0 * unit, minf(safe.size.x * 0.46, safe.size.y * 0.40))
	var top: float = safe.position.y + maxf(safe.size.y * 0.22, peak * 0.72) + peak * 0.52 + 8.0 * unit
	_discovery_rect = Rect2(Vector2(safe.get_center().x - width * 0.5,
		minf(top, safe.end.y - height)), Vector2(width, height))
	_discovery.position = _discovery_rect.position
	_discovery.size = _discovery_rect.size
	_discovery.pivot_offset = _discovery.size * 0.5
	var age: float = maxf(0.0, _elapsed - REVEAL_SECONDS)
	_discovery.scale = Vector2.ONE if _reduced_motion else Vector2.ONE * (1.0 - 0.10 * exp(-age * 12.0) * cos(age * 18.0))
	_discovery.modulate.a = 1.0 if _reduced_motion else (1.0 - smoothstep(Flight.RETURN_START, Flight.PERFORMANCE_SECONDS, _elapsed))


func _sample_chest_motion(unit: float) -> void:
	_model_sample.clear()
	var rest: Vector2 = _chest_rect.position + _art_rect.get_center()
	_pose = {"center": rest, "scale": 1.0, "yaw": 0.0, "roll": 0.0,
		"edge": maxf(_art_rect.size.x, _art_rect.size.y), "emphasis": 0.0, "model_weight": 0.0, "phase": "rest"}
	if not _earned or not _performance_active or _elapsed >= Flight.PERFORMANCE_SECONDS or _reduced_motion or not _art_rect.has_area():
		return
	var safe: Rect2 = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	safe = safe.grow(-2.0 * unit)
	_pose.merge(Flight.sample(_elapsed, rest, safe, float(_pose.edge), 176.0 * unit), true)
	if _model_tier > 0 and float(_pose.model_weight) > 0.0:
		_model_sample = _models.sample(_model_tier, float(_pose.yaw))
	var local := Rect2(-_art_rect.size * 0.5, _art_rect.size)
	if not _model_sample.is_empty():
		var framing: Rect2 = _model_sample.bounds
		var turned: Rect2 = _model_sample.turn_bounds
		var model_unit: float = float(_pose.edge) / maxf(framing.size.x, framing.size.y)
		local = local.merge(Rect2((turned.position - framing.get_center()) * model_unit, turned.size * model_unit))
	else:
		# Source sprites turn in their own plane without invented rear geometry.
		_pose.roll = _pose.yaw
		_pose.model_weight = 0.0
	_pose = Flight.fit(_pose, local, safe)
	chest.pivot_offset = _art_rect.get_center()
	chest.position = Vector2(_pose.center) - chest.pivot_offset
	chest.scale = Vector2.ONE * float(_pose.scale)
	chest.rotation = float(_pose.roll)
	chest.modulate.a = 1.0 - float(_pose.model_weight)


func _draw_status_surface() -> void:
	if visible and _earned and _toast_rect.has_area() and _surface != null:
		_surface_layer.draw_style_box(_surface, _toast_rect)


func _draw_chest_glow() -> void:
	if not visible or not _toast_rect.has_area() or _pose.is_empty():
		return
	if not _earned or not _performance_active or _reduced_motion:
		return
	var t: float = _elapsed - REVEAL_SECONDS
	if t < 0.0:
		return
	var accent: Color = _palette.get("spark", Color("#ffd777"))
	var center: Vector2 = _pose.center
	var edge: float = float(_pose.edge) * float(_pose.scale)
	var glow: float = (1.0 - smoothstep(0.40, 1.35, t)) * 0.72
	_glow.draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * edge * 0.94, Vector2.ONE * edge * 1.88), false, Color(accent, glow))
	_glow.draw_set_transform(center, t * 0.62)
	_glow.draw_texture_rect(RAYS, Rect2(Vector2.ONE * -edge, Vector2.ONE * edge * 2.0), false, Color(accent.lightened(0.18), glow * 0.82))
	_glow.draw_set_transform(Vector2.ZERO)


func _draw_chest_effect() -> void:
	if not _earned or not _performance_active or _reduced_motion or _pose.is_empty():
		return
	var center: Vector2 = _pose.center
	var edge: float = float(_pose.edge) * float(_pose.scale)
	var accent: Color = _palette.get("spark", Color("#ffd777"))
	if not _model_sample.is_empty() and float(_pose.model_weight) > 0.0:
		var bounds: Rect2 = _model_sample.bounds
		var unit: float = float(_pose.edge) / maxf(bounds.size.x, bounds.size.y)
		_effect.draw_set_transform(center, float(_pose.roll), Vector2.ONE * float(_pose.scale))
		_effect.draw_texture_rect(_model_sample.texture, Rect2(-bounds.get_center() * unit, Vector2.ONE * 1024.0 * unit), false,
			Color(1, 1, 1, float(_pose.model_weight)))
		_effect.draw_set_transform(Vector2.ZERO)
	var t: float = _elapsed - REVEAL_SECONDS
	if t < 0.0:
		return
	var flash: float = 1.0 - smoothstep(0.0, 0.24, t)
	_effect.draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * edge * 0.80, Vector2.ONE * edge * 1.60), false,
		Color(accent.lightened(0.75), flash * 0.86))
	for index in range(7):
		var age: float = t - float(index) * 0.065
		if age < 0.0 or age >= 0.80:
			continue
		var direction: Vector2 = Vector2.from_angle(-2.55 + float(index) * TAU / 7.0)
		var point: Vector2 = center + direction * edge * (0.50 + age * 0.22)
		var star_size: float = edge * 0.22 * sin(age / 0.80 * PI)
		_effect.draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * star_size * 0.5, Vector2.ONE * star_size), false,
			Color(accent.lightened(0.5), 1.0 - age / 0.80))

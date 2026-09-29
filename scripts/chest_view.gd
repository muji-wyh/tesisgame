extends Control

signal opened
signal release_reached
signal cue_requested(theme_id: String, cue: String, step: int)

const Feel = preload("res://scripts/chest_feel.gd")
const OPEN_SECONDS: float = Feel.OPEN_SECONDS
const OPEN_SWAY_SECONDS: float = 6.0
const RELEASE_SECONDS: float = 0.72
const CHARGE_STEPS: int = 3
const CHARGE_GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SURFACE_LIGHT = preload("res://scripts/chest_surface.gdshader")
const Style = preload("res://scripts/ui_style.gd")

var theme_id: String = ""
var reduced_motion: bool = false
var mode: String = "closed"
var _art := Node2D.new()
var _pieces: Array[Dictionary] = []
var _bounds := Rect2()
var _body_pivot := Vector2.ZERO
var _body_floor := Vector2.ZERO
var _elapsed: float = 0.0
var _idle_time: float = 0.0
var _idle_paused: bool = false
var _tint: Color = Color.WHITE
var _style: String = ""
var drag_offset: Vector2 = Vector2.ZERO
var hold_progress: float = 0.0
var _tap_remaining: float = 0.0
var _glint := Node2D.new()
var _glint_color: Color = Color.WHITE
var _charge := Node2D.new()
var _charge_color := Color("#58d7c5")
var _charge_spark := Color("#fff4be")
var _hold_active: bool = false
var _release_active: bool = false
var _charge_time: float = 0.0
var _charge_center := Vector2.ZERO
var _charge_radius := Vector2.ZERO
var _charge_bounds := Rect2()
var _charge_scale: float = 1.0
var _charge_unit: float = 1.0
var _charge_inset: float = 0.0
var _shadow := Node2D.new()
var _details := Node2D.new()
var _motion_bounds := Rect2()
var _ground_center := Vector2.ZERO
var _fit_scale: float = 1.0
var _physical_pose: Dictionary = {}
var _rigged: bool = false
var _cancel_remaining: float = 0.0
var _cancel_pressure: float = 0.0
var _cancel_progress: float = 0.0
var _charge_step: int = 0
var _opening_cues_enabled: bool = false
var _opening_cues: Dictionary = {}
var _opening_timeline: Array = Feel.timeline()
var _cue_log: Array[Dictionary] = []
var _feel: Dictionary = Feel.profile("spring")
var _crystal_cavity: Node2D
var _animation_origin_frame: int = -1
var _pulse_step: int = 0
var _pulse_started_at: float = 0.0
var _hold_pulse_step: int = 0
var _pulse_holding: bool = false
var _body_shift_x: float = 0.0
var _cancel_shift_x: float = 0.0
var _cancel_body_pose: Dictionary = {}
var _cancel_piece_poses: Array[Dictionary] = []
var _radiance := Node2D.new()
var _cavity_light := Node2D.new()
var _flash := Node2D.new()
var _seam_light := Node2D.new()
var _release_color := Color.WHITE
var _lid_edges: Array[Dictionary] = []
var _surface_light_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)
	_shadow.draw.connect(_draw_shadow)
	add_child(_radiance)
	_radiance.draw.connect(_draw_radiance)
	add_child(_charge)
	# Keep the progress rail readable above the lid, below the release flash.
	_charge.z_index = 9
	_charge.hide()
	_charge.draw.connect(_draw_charge)
	add_child(_art)
	add_child(_cavity_light)
	_cavity_light.draw.connect(_draw_cavity_light)
	add_child(_details)
	_details.draw.connect(_draw_details)
	add_child(_glint)
	_glint.hide()
	_glint.draw.connect(_draw_glint)
	add_child(_flash)
	_flash.z_index = 10
	var light_material := CanvasItemMaterial.new()
	light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = light_material
	_flash.draw.connect(_draw_flash)
	add_child(_seam_light)
	_seam_light.z_index = 3
	_seam_light.draw.connect(_draw_seam)
	resized.connect(_fit)
	visibility_changed.connect(_visibility_changed)
	_visibility_changed()


func configure_skin(palette: Dictionary, manifest: Dictionary) -> void:
	if theme_id == palette.id:
		return
	stop_reaction()
	theme_id = palette.id
	_feel = Feel.profile(theme_id)
	_style = palette.chest
	# Above the inner lid/interior, below the solid front and floating facets.
	_cavity_light.z_index = 0 if _style == "crystal" else 1
	_tint = palette.tint
	_glint_color = palette.light
	_charge_color = palette.get("accent", _glint_color)
	_charge_spark = palette.get("spark", _glint_color).lightened(0.25)
	_release_color = Feel.FLASH_COLORS.get(theme_id, palette.light)
	mode = "closed"
	_elapsed = 0.0
	_idle_time = 0.0
	_crystal_cavity = null
	for child in _art.get_children():
		child.free()
	_pieces.clear()
	_lid_edges.clear()
	_surface_light_active = false
	_rigged = false
	var style: Dictionary = manifest.styles[_style]
	if _style == "crystal":
		for part in style.parts:
			var matrix: Array = part.transform
			var pose := Transform2D(Vector2(matrix[0], matrix[1]), Vector2(matrix[2], matrix[3]), Vector2(matrix[4], matrix[5]))
			_add_piece(part.texture, part.name, pose, Vector2(part.pivot[0], part.pivot[1]), int(part.order), part.flip_h, part.flip_v)
		_crystal_cavity = Node2D.new()
		_pieces[0].node.add_child(_crystal_cavity)
		_crystal_cavity.draw.connect(_draw_crystal_cavity)
	elif not _load_rig():
		_add_piece(style.closed, "closed", Transform2D.IDENTITY, Vector2(0.5, 0.5))
		_add_piece(style.open, "open", Transform2D.IDENTITY, Vector2(0.5, 0.5))
	_measure_bounds()
	_measure_motion_bounds()
	_apply_pose(0.0)
	_fit()


func _load_rig() -> bool:
	const RIG_PATH: String = "res://assets/chests/rigs.json"
	if not FileAccess.file_exists(RIG_PATH):
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(RIG_PATH))
	if not manifest is Dictionary or not manifest.get("styles") is Dictionary:
		return false
	var rig: Variant = manifest.styles.get(_style)
	if not rig is Dictionary or not rig.get("parts") is Array or rig.parts.is_empty():
		return false
	for part in rig.parts:
		if not part is Dictionary or not part.has_all(["texture", "pivot", "position", "role"]):
			return false
		if not ResourceLoader.exists("res://" + str(part.texture)):
			return false
	for part in rig.parts:
		var pivot := Vector2(float(part.pivot[0]), float(part.pivot[1]))
		var position := Vector2(float(part.position[0]), float(part.position[1]))
		# Derived rig pivots use top-left coordinates. Original Crystal geometry
		# retains its imported bottom-left pivot convention in _add_piece.
		_add_piece(str(part.texture), str(part.role), Transform2D(0.0, position),
			Vector2(pivot.x, 1.0 - pivot.y), int(part.get("order", 0)))
	_rigged = true
	return true


func _add_piece(path: String, role: String, pose: Transform2D, pivot: Vector2, order: int = 0, flip_h: bool = false, flip_v: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://" + path)
	sprite.centered = false
	var dimensions: Vector2 = sprite.texture.get_size()
	sprite.offset = Vector2(-dimensions.x * pivot.x, -dimensions.y * (1.0 - pivot.y))
	sprite.transform = pose
	sprite.z_index = order
	sprite.flip_h = flip_h
	sprite.flip_v = flip_v
	var material := ShaderMaterial.new()
	material.shader = SURFACE_LIGHT
	material.set_shader_parameter("light_strength", 0.0)
	sprite.material = material
	_art.add_child(sprite)
	_pieces.append({"node": sprite, "rest": pose, "role": role})
	if role in ["lid_outer", "lid_inner"]:
		# Keep a solid rim through the edge-on hinge pose. Its thickness is
		# projected separately, so the lid never collapses into a paper line.
		var edge := Sprite2D.new()
		edge.texture = sprite.texture
		edge.centered = false
		edge.offset = sprite.offset
		edge.z_index = order
		_art.add_child(edge)
		_art.move_child(edge, sprite.get_index())
		_lid_edges.append({"node": edge, "source": sprite, "role": role})


func _measure_bounds() -> void:
	var first := true
	for piece in _pieces:
		var rect: Rect2 = piece.node.get_rect()
		var pose: Transform2D = piece.rest
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var point: Vector2 = pose * corner
			if first:
				_bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				_bounds = _bounds.expand(point)
	_body_pivot = _bounds.get_center()
	_body_floor = Vector2(_body_pivot.x, _bounds.end.y)
	for piece in _pieces:
		if piece.role in ["body", "chest"]:
			var body_rect: Rect2 = piece.node.get_rect()
			_body_pivot = piece.rest * Vector2(body_rect.get_center().x, body_rect.end.y * 0.98 + body_rect.position.y * 0.02)
			_body_floor = piece.rest * Vector2(body_rect.get_center().x, body_rect.end.y)
			break


func _measure_motion_bounds() -> void:
	_motion_bounds = _bounds
	for frame in range(37):
		var time: float = Feel.BUILDUP_SECONDS + 1.8 * float(frame) / 36.0
		for index in range(_pieces.size()):
			var state: Dictionary = _piece_pose(index, time, true)
			if float(state.alpha) <= 0.001:
				continue
			var rect: Rect2 = _pieces[index].node.get_rect()
			for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				_motion_bounds = _motion_bounds.expand(state.pose * corner)
	# A fixed margin contains the body's small recoil, Candy's elastic motion,
	# and finite taps without asking the parent stage to stop clipping.
	_motion_bounds = _motion_bounds.grow(maxf(_bounds.size.x, _bounds.size.y) * 0.065)


func _fit() -> void:
	if _pieces.is_empty() or _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0:
		return
	_update_charge()
	# Keep the same physical envelope throughout the progress effects and opening.
	var pixel: float = 1.0 / _charge_scale
	var safe_top: float = _charge_inset + 4.0 * pixel
	var bottom: float = maxf(safe_top, size.y - 7.0 * pixel)
	var available_height: float = maxf(0.0, bottom - safe_top)
	_fit_scale = maxf(0.0, minf(size.x * 0.79 / _motion_bounds.size.x, available_height * 0.87 / _motion_bounds.size.y))
	var center := Vector2(size.x * 0.5, safe_top + available_height * 0.54)
	var hold: Vector2 = _hold_pose_state()
	var pose_time: float = _elapsed if mode in ["opening", "opened"] else hold_progress * Feel.HOLD_SECONDS
	_physical_pose = Feel.body_pose(theme_id, hold.x, hold.y, pose_time, mode in ["opening", "opened"], _pulse_clock())
	if mode == "opened" and not reduced_motion:
		var phase: float = _idle_time * TAU / OPEN_SWAY_SECONDS
		var ease_in: float = smoothstep(0.0, 0.65, _idle_time)
		var sway: float = 0.018 if theme_id == "autumn" else 0.024 if theme_id == "candy" else 0.021
		_physical_pose.rotation += sin(phase) * sway * ease_in
	var returning: float = smoothstep(0.0, Feel.CANCEL_SECONDS, _cancel_remaining)
	if returning > 0.0 and not _cancel_body_pose.is_empty():
		_physical_pose = {"offset": _cancel_body_pose.offset * returning,
			"scale": Vector2.ONE.lerp(_cancel_body_pose.scale, returning),
			"rotation": float(_cancel_body_pose.rotation) * returning}
	if reduced_motion:
		_physical_pose = {"offset": Vector2.ZERO, "scale": Vector2.ONE, "rotation": 0.0}
	var offset: Vector2 = _physical_pose.offset * _bounds.size.x * _fit_scale
	if not reduced_motion:
		# Keep kicks readable even when a short phone stage fits a tiny chest.
		# The beat controls the whole body, not just its glow or decoration.
		if returning > 0.0:
			offset.x = _cancel_shift_x * returning
		elif _hold_active or (mode == "opening" and _elapsed < Feel.RELEASE_TIME + 0.075):
			offset.x += Feel.buildup_motion(_buildup_time(), _pulse_clock()) * maxf(0.0,
				6.0 * pixel - Feel.shake_distance(theme_id) * _bounds.size.x * _fit_scale)
		if mode == "opening":
			# A small stage must still show the base taking the release impact.
			offset.y += Feel.release_load(_elapsed) * maxf(0.0,
				4.0 * pixel - 0.050 * _bounds.size.x * _fit_scale)
	_body_shift_x = offset.x
	var pulse: Vector2 = _physical_pose.scale
	var bob: float = center.y - size.y * 0.59
	drag_offset = _clamp_drag_offset(drag_offset, _fit_scale, bob, Vector2.ONE, safe_top)
	_art.scale = Vector2.ONE * _fit_scale * pulse
	_art.rotation = float(_physical_pose.rotation)
	if not reduced_motion:
		_art.rotation += sin(_tap_remaining * 24.0) * 0.025 * (_tap_remaining / 0.35)
	# Rock around the feet: the body has leverage above a planted contact,
	# rather than spinning a flat card around its centre.
	_art.position = center - _motion_bounds.get_center() * _art.scale + drag_offset + offset
	_art.position += _body_pivot * _art.scale - _art.transform.basis_xform(_body_pivot)
	_ground_center = center + (_body_floor - _motion_bounds.get_center()) * _fit_scale + Vector2(offset.x * 0.20, 0.0) + drag_offset
	_shadow.queue_redraw()
	_details.queue_redraw()
	_radiance.queue_redraw()
	_cavity_light.queue_redraw()
	_flash.queue_redraw()
	_seam_light.queue_redraw()
	_glint.visible = not reduced_motion and (hold_progress > 0.0 or _tap_remaining > 0.0
		or (mode == "opening" and _elapsed < Feel.RELEASE_TIME))
	_glint.queue_redraw()


func _update_charge() -> void:
	var active: bool = is_visible_in_tree() and ((_hold_active and mode == "closed")
		or (_release_active and mode == "opening" and _elapsed < Feel.SETTLE_TIME))
	_charge.visible = active
	_charge_scale = maxf(0.25, Style.ui_scale(self))
	var pixel: float = 1.0 / _charge_scale
	var margin: float = minf(10.0 * pixel, minf(size.x, size.y) * 0.08)
	_charge_inset = margin
	var available: float = maxf(0.0, size.x - margin * 2.0)
	var top: float = margin + 5.0 * pixel
	var available_height: float = maxf(0.0, size.y - margin - top)
	_charge_unit = minf(pixel, minf(available, available_height) / 100.0)
	_charge_center = Vector2(size.x * 0.5, top + available_height * 0.52)
	_charge_radius = Vector2(maxf(0, available * 0.37 - 18.0 * _charge_unit), maxf(0, available_height * 0.39 - 18.0 * _charge_unit))
	# Every halo, star and spark stays in this measured rectangle, including
	# the one-shot release. The parent stage can safely keep clipping enabled.
	var extent: Vector2 = _charge_radius * 1.13 + Vector2.ONE * 18.0 * _charge_unit
	if _charge_radius.x <= 0.0 or _charge_radius.y <= 0.0:
		extent = Vector2.ZERO
	_charge_bounds = Rect2(_charge_center - extent, extent * 2.0)
	_charge.queue_redraw()


func _ellipse_points(radius: Vector2, start: float, end: float, steps: int = 72) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var angle: float = lerpf(start, end, float(index) / float(steps))
		points.append(_charge_center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw_charge() -> void:
	if _charge_radius.x <= 0.0 or _charge_radius.y <= 0.0:
		return
	var pixel: float = _charge_unit
	var progress: float = performance_progress()
	var releasing: bool = mode == "opening" and _elapsed >= Feel.RELEASE_TIME
	var alpha: float = 1.0 - smoothstep(0.0, 0.22, _elapsed - Feel.RELEASE_TIME) if releasing else 1.0
	if alpha <= 0.0:
		return
	var pulse: float = _pulse_strength()
	var crest: float = _crown_crest()
	var gold: Color = _release_color.lightened(0.30)
	var energy: Color = _charge_color.lerp(_release_color, smoothstep(0.2, 1.0, progress))
	# A recessed casing gives the rail weight. Its light grows continuously;
	# only the small accent follows the same delivered beats as the body/audio.
	_draw_crown_arc(0.0, 1.0, Color(Color("#152332"), 0.50 * alpha), 14.0 * pixel, Vector2(0, 2.0 * pixel))
	_draw_crown_arc(0.0, 1.0, Color(_charge_color.darkened(0.72), 0.92 * alpha), 12.0 * pixel)
	_draw_crown_arc(0.0, 1.0, Color(_charge_color.lightened(0.30), 0.32 * alpha), 8.0 * pixel)
	_draw_crown_arc(0.0, 1.0, Color(_charge_color.darkened(0.60), 0.90 * alpha), 5.0 * pixel)
	if progress > 0.0:
		_draw_crown_arc(0.0, progress, Color(energy, (0.16 + progress * 0.16 + pulse * 0.05) * alpha), 22.0 * pixel)
		_draw_crown_arc(0.0, progress, Color(energy, 0.38 * alpha), 13.0 * pixel)
		_draw_crown_arc(0.0, progress, Color(energy, alpha), 8.0 * pixel)
		_draw_crown_arc(0.0, progress, Color(gold, 0.88 * alpha), 4.0 * pixel)
		_draw_crown_arc(0.0, progress, Color(Color.WHITE, 0.92 * alpha), 1.5 * pixel)
	for streak in _crown_streaks():
		_draw_crown_arc(streak.x, streak.y, Color(gold, 0.70 * alpha), 9.0 * pixel)
		_draw_crown_arc(lerpf(streak.x, streak.y, 0.45), streak.y, Color(Color.WHITE, alpha), 4.0 * pixel)
	if crest > 0.0:
		# A single completed-rail crest merges into the cavity's release light.
		_draw_crown_arc(0.0, 1.0, Color(gold, crest * 0.32 * alpha), 28.0 * pixel)
		_draw_crown_arc(0.0, 1.0, Color(Color.WHITE, crest * alpha), 7.0 * pixel)
	if not reduced_motion and not releasing and progress > 0.0:
		# This comet is the earned progress frontier, never an independent timer.
		for trail in range(5):
			var end: float = maxf(0.0, progress - float(trail) * 0.009)
			_draw_crown_arc(maxf(0.0, end - 0.009), end,
				Color(gold, (0.8 - float(trail) * 0.13) * alpha), (7.0 - float(trail)) * pixel)
		var tip: Vector2 = _crown_point(progress)
		var halo: float = (12.0 + pulse) * pixel
		_charge.draw_texture_rect(CHARGE_GLOW, Rect2(tip - Vector2.ONE * halo, Vector2.ONE * halo * 2.0), false,
			Color(gold, (0.70 + progress * 0.30) * alpha))
		_charge.draw_circle(tip, 4.0 * pixel, Color(Color.WHITE, alpha))
		_draw_charge_star(tip, (7.0 + pulse) * pixel, Color(Color.WHITE, alpha))
	for index in range(CHARGE_STEPS):
		var threshold: float = float(index + 1) / CHARGE_STEPS
		var lit: bool = progress + 0.000001 >= threshold
		var beat: float = _crown_milestone_strength(index)
		var position: Vector2 = _crown_star_position(index)
		var radius: float = _crown_star_radius()
		_charge.draw_circle(position + Vector2(0, 1.5 * pixel), radius * 1.50, Color(Color("#152332"), 0.55 * alpha))
		_charge.draw_circle(position, radius * 1.40, Color(energy, (0.95 if lit else 0.45) * alpha))
		_charge.draw_circle(position, radius * 1.16, Color(_charge_color.darkened(0.78), 0.98 * alpha))
		if lit:
			var halo: float = radius * 1.80
			_charge.draw_texture_rect(CHARGE_GLOW, Rect2(position - Vector2.ONE * halo, Vector2.ONE * halo * 2.0), false,
				Color(gold, (0.65 + beat * 0.35) * alpha))
		if beat > 0.0:
			var expansion: float = clampf(_crown_milestone_age(index) / 0.32, 0.0, 1.0)
			_charge.draw_arc(position, radius * lerpf(1.20, 1.80, expansion), 0, TAU, 32,
				Color(gold, beat * alpha), 1.5 * pixel, true)
			for spark in range(6):
				var direction := Vector2.from_angle(float(spark) * TAU / 6.0 - PI * 0.5)
				var point: Vector2 = position + direction * radius * lerpf(1.20, 1.72, expansion)
				_charge.draw_line(point - direction * 3.0 * pixel * beat, point,
					Color(_charge_spark, beat * alpha), 1.5 * pixel, true)
		_draw_charge_star(position, radius * (0.87 + beat * 0.20), Color(gold if lit else Color.WHITE, alpha if lit else 0.50 * alpha))


func _crown_clock() -> float:
	# Unlike the old particle clock, this never resets at confirmation.
	return Feel.HOLD_SECONDS + _elapsed if mode in ["opening", "opened"] else hold_progress * Feel.HOLD_SECONDS


func _crown_flow_phase() -> float:
	var time: float = _crown_clock()
	return 0.40 * time + 0.35 * time * time


func _crown_streaks() -> Array[Vector2]:
	var streaks: Array[Vector2] = []
	var progress: float = performance_progress()
	if reduced_motion or not _charge.visible or progress <= 0.0 or progress >= 1.0:
		return streaks
	for index in range(3):
		var head: float = fposmod(_crown_flow_phase() + float(index) / 3.0, 1.0) * progress
		streaks.append(Vector2(maxf(0.0, head - 0.045 - progress * 0.020), head))
	return streaks


func _crown_milestone_age(index: int) -> float:
	return _crown_clock() - float(index + 1) * (Feel.HOLD_SECONDS + Feel.RELEASE_TIME) / CHARGE_STEPS


func _crown_milestone_strength(index: int) -> float:
	var age: float = _crown_milestone_age(index)
	if reduced_motion or not _charge.visible or age < 0.0 or age >= 0.32:
		return 0.0
	return (1.0 - smoothstep(0.04, 0.32, age)) * smoothstep(0.0, 0.025, age)


func _crown_crest() -> float:
	if reduced_motion or not _charge.visible or mode != "opening":
		return 0.0
	var age: float = _elapsed - Feel.RELEASE_TIME
	return smoothstep(0.0, 0.025, age) * (1.0 - smoothstep(0.035, 0.20, age)) if age >= 0.0 else 0.0


func _crown_point(progress: float) -> Vector2:
	var part: float = clampf(progress, 0.0, 1.0) * CHARGE_STEPS
	var segment: int = mini(CHARGE_STEPS - 1, floori(part))
	var start: float = PI + PI * float(segment) / CHARGE_STEPS + 0.06
	var end: float = PI + PI * float(segment + 1) / CHARGE_STEPS - 0.06
	return _charge_center + Vector2.from_angle(lerpf(start, end, part - segment)) * _charge_radius


func _draw_crown_arc(from: float, to: float, color: Color, width: float, offset: Vector2 = Vector2.ZERO) -> void:
	# Every decorative stroke is clipped to its earned interval and the gaps.
	for index in range(CHARGE_STEPS):
		var start: float = maxf(0.0, from * CHARGE_STEPS - index)
		var end: float = minf(1.0, to * CHARGE_STEPS - index)
		if end <= start:
			continue
		var angle_start: float = PI + PI * float(index) / CHARGE_STEPS + 0.06
		var angle_end: float = PI + PI * float(index + 1) / CHARGE_STEPS - 0.06
		var points: PackedVector2Array = _ellipse_points(_charge_radius,
			lerpf(angle_start, angle_end, start), lerpf(angle_start, angle_end, end), maxi(2, ceili((end - start) * 28.0)))
		if offset != Vector2.ZERO:
			for point in range(points.size()):
				points[point] += offset
		_charge.draw_polyline(points, color, width, true)


func _crown_star_position(index: int) -> Vector2:
	return _charge_center + Vector2.from_angle(PI + PI * (float(index) + 0.5) / CHARGE_STEPS) * _charge_radius


func _crown_star_radius() -> float:
	return minf(9.0 * _charge_unit, minf(_charge_radius.x, _charge_radius.y) * 0.24)


func _crown_effect_bounds() -> Rect2:
	# The drawing uses these same rail points and star/head sizes. Include
	# stroke half-widths, the release crest, and milestone spark travel.
	if _charge_radius.x <= 0.0 or _charge_radius.y <= 0.0:
		return Rect2(_charge_center, Vector2.ZERO)
	var result := Rect2(_crown_point(0.0), Vector2.ZERO)
	for index in range(CHARGE_STEPS):
		var start: float = PI + PI * float(index) / CHARGE_STEPS + 0.06
		var end: float = PI + PI * float(index + 1) / CHARGE_STEPS - 0.06
		for point in _ellipse_points(_charge_radius, start, end, 28):
			result = result.expand(point)
	result = result.grow(14.0 * _charge_unit)
	var star_extent: float = _crown_star_radius() * 1.80 + 0.75 * _charge_unit
	for index in range(CHARGE_STEPS):
		var position: Vector2 = _crown_star_position(index)
		result = result.merge(Rect2(position - Vector2.ONE * star_extent, Vector2.ONE * star_extent * 2.0))
	return result


func _draw_charge_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(10):
		points.append(center + Vector2.from_angle(-PI * 0.5 + PI * float(index) / 5.0) * radius * (1.0 if index % 2 == 0 else 0.44))
	_charge.draw_colored_polygon(points, color)


func _hold_status() -> String:
	return "Hold to begin"


func performance_progress() -> float:
	if mode in ["opening", "opened"]:
		return Feel.progress(_elapsed)
	return hold_progress if reduced_motion else hold_progress * Feel.HOLD_SECONDS / (Feel.HOLD_SECONDS + Feel.RELEASE_TIME)


func performance_phase() -> String:
	if mode == "opened":
		return "opened"
	if mode == "opening":
		return Feel.phase(_elapsed)
	return "holding" if _hold_active else "idle"


func tension_progress() -> float:
	if mode == "opening":
		return Feel.tension(_elapsed)
	return Feel.tension((hold_progress - 1.0) * Feel.HOLD_SECONDS) if _hold_active else 0.0


func _pulse_clock() -> float:
	if reduced_motion or _pulse_step <= 0:
		return -1.0
	var clock: float = _elapsed
	var beats: Array = Feel.PULSE_TIMES
	if _pulse_holding:
		if mode != "closed" or not _hold_active:
			return -1.0
		clock = hold_progress * Feel.HOLD_SECONDS
		beats = Feel.HOLD_PULSE_TIMES
	elif mode != "opening" or not _opening_cues_enabled or _elapsed >= Feel.ANTICIPATION_TIME:
		return -1.0
	var age: float = clock - _pulse_started_at
	if age < 0.0 or age >= Feel.pulse_duration(_pulse_step - 1, _pulse_holding):
		return -1.0
	# Begin the kick on the frame that actually sounds the beat. Slow frames
	# must not start an already-decayed kick or invent a skipped later beat.
	return float(beats[_pulse_step - 1]) + age


func _pulse_motion() -> float:
	return Feel.pulse_motion(_pulse_clock(), _pulse_holding)


func _pulse_strength() -> float:
	return Feel.pulse_strength(_pulse_clock(), _pulse_holding)


func _buildup_time() -> float:
	return _elapsed if mode == "opening" else (hold_progress - 1.0) * Feel.HOLD_SECONDS


func _buildup_intensity() -> float:
	if reduced_motion or not is_visible_in_tree():
		return 0.0
	if not _hold_active and not (mode == "opening" and _opening_cues_enabled):
		return 0.0
	var fade: float = 1.0 - smoothstep(Feel.RELEASE_TIME, Feel.RELEASE_TIME + 0.10, _elapsed) if mode == "opening" else 1.0
	return Feel.buildup_intensity(_buildup_time()) * fade


func _buildup_glow() -> float:
	var intensity: float = _buildup_intensity()
	# Pressure stays luminous between impacts. Only a small accent follows
	# the sounded beat, so the increasingly fast roll never becomes a strobe.
	return (intensity * 0.09 + pow(intensity, 1.35) * 0.82) * (0.88 + _pulse_strength() * 0.12)


func _buildup_bounds() -> Rect2:
	var radius: Vector2 = _release_radius() * lerpf(0.40, 0.95, _buildup_intensity())
	return Rect2(_light_origin() - radius, radius * 2.0)


func performance_status() -> String:
	match performance_phase():
		"gathering": return "Gathering"
		"building": return "Building tension"
		"anticipation": return "Get ready!"
		"release", "opened": return "Opening!"
	return _hold_status()


func _charge_particle_count() -> int:
	if reduced_motion or not _charge.visible:
		return 0
	var count: int = 1 if performance_progress() > 0.0 and performance_progress() < 1.0 else 0
	for index in range(CHARGE_STEPS):
		if _crown_milestone_strength(index) > 0.0:
			count += 6
	return count


func _hold_pose_state() -> Vector2:
	if reduced_motion:
		return Vector2.ZERO
	if _cancel_remaining > 0.0:
		var returning: float = smoothstep(0.0, Feel.CANCEL_SECONDS, _cancel_remaining)
		return Vector2(_cancel_pressure, _cancel_progress) * returning
	var energy: float = tension_progress()
	return Vector2(0.30 + energy * 0.70, energy) if _hold_active else Vector2.ZERO


func begin_hold() -> void:
	if mode != "closed" or not is_visible_in_tree() or _hold_active:
		return
	_hold_active = true
	_animation_origin_frame = Engine.get_process_frames()
	_release_active = false
	_cancel_remaining = 0.0
	_cancel_piece_poses.clear()
	_charge_time = 0.0
	_charge_step = 0
	_hold_pulse_step = 0
	_pulse_step = 0
	_pulse_holding = true
	_cue_log.clear()
	hold_progress = 0.0
	_tap_remaining = 0.0
	_apply_pose(0.0)
	_fit()
	_emit_cue("press")


func cancel_hold() -> void:
	if not _hold_active or mode != "closed":
		return
	_cancel_piece_poses.clear()
	_cancel_pressure = _hold_pose_state().x
	_cancel_body_pose = _physical_pose.duplicate(true)
	_cancel_shift_x = _body_shift_x
	_animation_origin_frame = Engine.get_process_frames()
	_cancel_progress = _hold_pose_state().y
	_cancel_remaining = 0.0 if reduced_motion else Feel.CANCEL_SECONDS
	_hold_active = false
	hold_progress = 0.0
	_charge_step = 0
	_hold_pulse_step = 0
	_pulse_step = 0
	_tap_remaining = 0.0
	_emit_cue("cancel")
	_apply_pose(0.0)
	_fit()


func opening_committed() -> bool:
	return mode == "opened" or (mode == "opening" and _elapsed >= Feel.RELEASE_TIME)


func cancel_open(animate_return: bool = true) -> void:
	if mode != "opening" or opening_committed():
		return
	var body_pose: Dictionary = _physical_pose.duplicate(true)
	var shift_x: float = _body_shift_x
	var piece_poses: Array[Dictionary] = []
	for piece in _pieces:
		piece_poses.append({"pose": piece.node.transform, "alpha": piece.node.modulate.a})
	mode = "closed"
	_elapsed = 0.0
	_idle_time = 0.0
	_opening_cues.clear()
	stop_reaction()
	_animation_origin_frame = Engine.get_process_frames()
	if animate_return and not reduced_motion:
		_cancel_remaining = Feel.CANCEL_SECONDS
		_cancel_pressure = 0.0
		_cancel_progress = 0.0
		_cancel_body_pose = body_pose
		_cancel_shift_x = shift_x
		_cancel_piece_poses = piece_poses
	_emit_cue("cancel")
	_apply_pose(0.0)
	_fit()


func _emit_cue(cue: String, step: int = 0, cue_time: float = -1.0) -> void:
	if not is_visible_in_tree() or theme_id.is_empty():
		return
	var time: float = _elapsed if mode in ["opening", "opened"] else hold_progress * Feel.HOLD_SECONDS
	if cue_time >= 0.0:
		time = cue_time
	if cue in ["hold_pulse", "tension_pulse"]:
		_pulse_step = step
		_pulse_holding = cue == "hold_pulse"
		_pulse_started_at = hold_progress * Feel.HOLD_SECONDS if _pulse_holding else _elapsed
	_cue_log.append({"theme": theme_id, "cue": cue, "step": step, "time": time})
	if _cue_log.size() > 64:
		_cue_log.pop_front()
	cue_requested.emit(theme_id, cue, step)


func hold_effect_snapshot() -> Dictionary:
	var active: bool = _charge.visible and is_visible_in_tree()
	var drawing: bool = active and _charge_radius.x > 0.0 and _charge_radius.y > 0.0
	var pieces: Array[Dictionary] = []
	var signature: PackedStringArray = ["body:%.3f:%.3f:%.3f:%.3f:%.3f" % [
		_art.position.x, _art.position.y, _art.rotation, _art.scale.x, _art.scale.y]]
	var rendered_bounds := Rect2()
	var first_visible: bool = true
	for piece in _pieces:
		var transform: Transform2D = piece.node.transform
		var alpha: float = piece.node.modulate.a
		pieces.append({"role": piece.role, "x": transform.origin.x, "y": transform.origin.y,
			"rotation": transform.get_rotation(), "scale_x": transform.get_scale().x,
			"scale_y": transform.get_scale().y, "alpha": alpha})
		signature.append("%s:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f" % [piece.role, transform.origin.x,
			transform.origin.y, transform.get_rotation(), transform.get_scale().x, transform.get_scale().y, alpha])
		if alpha > 0.001:
			var rect: Rect2 = piece.node.get_rect()
			for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				var point: Vector2 = _art.transform * transform * corner
				rendered_bounds = Rect2(point, Vector2.ZERO) if first_visible else rendered_bounds.expand(point)
				first_visible = false
	var body_offset: Vector2 = _physical_pose.get("offset", Vector2.ZERO)
	var body_scale: Vector2 = _physical_pose.get("scale", Vector2.ONE)
	var percent: int = mini(100, floori(performance_progress() * 100.0))
	var status: String = performance_status()
	var beam_bounds: Rect2 = _opened_beam_bounds()
	var cavity_bounds: Rect2 = _cavity_glow_bounds()
	var crown_bounds: Rect2 = _crown_effect_bounds()
	var burst_origin: Vector2 = _release_burst_origin()
	var bloom_bounds: Rect2 = _release_bloom_bounds()
	var core_bounds: Rect2 = _release_core_bounds()
	var wave_bounds: Rect2 = _release_wave_bounds()
	var crown_streaks: Array[Dictionary] = []
	var crown_milestones: Array[float] = []
	for streak in _crown_streaks():
		crown_streaks.append({"start": streak.x, "end": streak.y})
	for index in range(CHARGE_STEPS):
		crown_milestones.append(_crown_milestone_strength(index))
	var surface_light: float = 0.0
	for piece in _pieces:
		if piece.role in ["body", "chest"]:
			surface_light = float(piece.node.material.get_shader_parameter("light_strength"))
			break
	return {"active": active, "phase": performance_phase(),
		"progress": performance_progress(), "performance_progress": performance_progress(), "hold_progress": hold_progress,
		"tension": tension_progress(),
		"pulse_strength": _pulse_strength(),
		"pulse_motion": _pulse_motion(),
		"crown_clock": _crown_clock(), "crown_flow_phase": _crown_flow_phase(),
		"crown_streaks": crown_streaks, "crown_milestones": crown_milestones, "crown_crest": _crown_crest(),
		"crown_effect_bounds": {"x": crown_bounds.position.x, "y": crown_bounds.position.y,
			"width": crown_bounds.size.x, "height": crown_bounds.size.y},
		"buildup_intensity": _buildup_intensity(), "buildup_glow": _buildup_glow(),
		"buildup_color": _release_color.to_html(false),
		"buildup_bounds": {"x": _buildup_bounds().position.x, "y": _buildup_bounds().position.y,
			"width": _buildup_bounds().size.x, "height": _buildup_bounds().size.y},
		"release_flash": _release_power(), "release_color": _release_color.to_html(false),
		"release_impact": _release_impact(),
		"release_load": Feel.release_load(_elapsed) if mode == "opening" and not reduced_motion else 0.0,
		"stop_response": Feel.stop_response(_elapsed) if mode == "opening" and not reduced_motion else 0.0,
		"release_additive": _flash.material is CanvasItemMaterial and _flash.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
		"release_burst_origin": {"x": burst_origin.x, "y": burst_origin.y},
		"release_bloom_bounds": {"x": bloom_bounds.position.x, "y": bloom_bounds.position.y,
			"width": bloom_bounds.size.x, "height": bloom_bounds.size.y},
		"release_core_bounds": {"x": core_bounds.position.x, "y": core_bounds.position.y,
			"width": core_bounds.size.x, "height": core_bounds.size.y},
		"release_wave_bounds": {"x": wave_bounds.position.x, "y": wave_bounds.position.y,
			"width": wave_bounds.size.x, "height": wave_bounds.size.y},
		"opened_glow": _opened_glow(), "opened_idle_time": _idle_time,
		"opened_beam_strength": _beam_strength(), "opened_surface_light": surface_light,
		"opened_light_color": _release_color.to_html(false),
		"cavity_origin": {"x": _cavity_origin().x, "y": _cavity_origin().y},
		"opened_beam_bounds": {"x": beam_bounds.position.x, "y": beam_bounds.position.y,
			"width": beam_bounds.size.x, "height": beam_bounds.size.y},
		"cavity_glow_bounds": {"x": cavity_bounds.position.x, "y": cavity_bounds.position.y,
			"width": cavity_bounds.size.x, "height": cavity_bounds.size.y},
		"opened_animated": mode == "opened" and is_visible_in_tree() and not reduced_motion and not _idle_paused,
		"final_drive": Feel.final_drive(_elapsed) if mode == "opening" and not reduced_motion else 0.0,
		"release_radius": {"x": _release_radius().x, "y": _release_radius().y},
		"release_bounds": {"x": _release_bounds().position.x, "y": _release_bounds().position.y,
			"width": _release_bounds().size.x, "height": _release_bounds().size.y},
		"lid_pressure": _lid_pressure(),
		"light_origin": {"x": _light_origin().x, "y": _light_origin().y},
		"ground_center": {"x": _ground_center.x, "y": _ground_center.y},
		"grounding_pivot": {"x": (_art.transform * _body_pivot).x, "y": (_art.transform * _body_pivot).y},
		"percent": percent,
		"text": "%s · %d%%" % [status, percent] if active else "", "status": status if active else "",
		"animated": active and not reduced_motion,
		"theme": theme_id, "material": _feel.material, "rigged": _rigged,
		"opening_time": _elapsed, "cancel_remaining": _cancel_remaining,
		"animation_origin_frame": _animation_origin_frame,
		"interior_open": _crystal_opening(),
		"fitted_scale": _fit_scale, "pose_signature": "/".join(signature), "pieces": pieces,
		"physical_pose": {"x": body_offset.x, "y": body_offset.y, "scale_x": body_scale.x,
			"scale_y": body_scale.y, "rotation": _physical_pose.get("rotation", 0.0)},
		"physical_bounds": {"x": rendered_bounds.position.x, "y": rendered_bounds.position.y,
			"width": rendered_bounds.size.x, "height": rendered_bounds.size.y},
		"motion_bounds": {"x": _motion_bounds.position.x, "y": _motion_bounds.position.y,
			"width": _motion_bounds.size.x, "height": _motion_bounds.size.y},
		"cues": _cue_log.duplicate(true), "cue_count": _cue_log.size(),
		"spark_count": _charge_particle_count() if drawing else 0,
		"bounds": {"x": _charge_bounds.position.x, "y": _charge_bounds.position.y,
			"width": _charge_bounds.size.x, "height": _charge_bounds.size.y}}


func _draw_glint() -> void:
	var center: Vector2 = _light_origin()
	var power: float = maxf(_buildup_glow(), _tap_remaining / 0.35 * 0.6)
	var radius: float = minf(size.x, size.y) * (0.05 + _buildup_intensity() * 0.04)
	for layer in range(3):
		_glint.draw_circle(center, radius * (1.8 - float(layer) * 0.4), Color(_glint_color, power * 0.1))
	_glint.draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(_glint_color, power), 3.0, true)
	_glint.draw_line(center - Vector2(0, radius * 0.6), center + Vector2(0, radius * 0.6), Color(Color.WHITE, power), 2.0, true)


func _draw_shadow() -> void:
	if _bounds.size.x <= 0.0 or _fit_scale <= 0.0:
		return
	var width: float = _bounds.size.x * _fit_scale * 0.35
	var height: float = maxf(1.0, minf(width * 0.10, size.y * 0.04))
	var lift: float = maxf(0.0, -float(_physical_pose.get("offset", Vector2.ZERO).y))
	var pressure: float = _hold_pose_state().x if mode == "closed" else maxf(0.0, float(_physical_pose.get("offset", Vector2.ZERO).y)) * 15.0
	var impact: float = Feel.release_load(_elapsed) if mode == "opening" and not reduced_motion else 0.0
	var contact: float = impact + absf(Feel.stop_response(_elapsed)) if mode == "opening" and not reduced_motion else 0.0
	for layer in range(5):
		var radius := Vector2(width, height) * (1.0 - float(layer) * 0.14 + lift)
		radius *= Vector2(1.0 - contact * 0.10, 1.0 - contact * 0.28)
		var points := PackedVector2Array()
		for index in range(32):
			points.append(_ground_center + Vector2.from_angle(TAU * float(index) / 32.0) * radius)
		_shadow.draw_colored_polygon(points, Color(0.07, 0.10, 0.16,
			(0.045 + float(layer) * 0.018 + pressure * 0.018 + contact * 0.065) * (1.0 - lift * 3.0)))


func _lid_pressure() -> float:
	if reduced_motion:
		return 0.0
	var hold: Vector2 = _hold_pose_state()
	var energy: float = tension_progress() if mode == "opening" else hold.y
	var fade: float = 1.0 - smoothstep(Feel.RELEASE_TIME, Feel.RELEASE_TIME + 0.10, _elapsed) if mode == "opening" else 1.0
	var drive: float = Feel.final_drive(_elapsed) if mode == "opening" else 0.0
	return (pow(energy, 1.6) + drive * 0.28) * fade


func _release_power() -> float:
	# Background/skip completion has no delayed flash to replay on return.
	return Feel.release_flash(_elapsed) if mode == "opening" and _opening_cues_enabled and not reduced_motion else 0.0


func _opened_glow() -> float:
	if not is_visible_in_tree():
		return 0.0
	if mode == "opened":
		return 0.94 if reduced_motion else 0.94 + sin(_idle_time * TAU / OPEN_SWAY_SECONDS) * 0.04
	if mode == "opening" and _opening_cues_enabled and not reduced_motion:
		# Establish the lasting light before the one-shot burst fades, so the
		# cavity never goes dark between the release and the opened result.
		return smoothstep(0.06, 0.42, _elapsed - Feel.RELEASE_TIME) * 0.94
	return 0.0


func _cavity_origin_in_art() -> Vector2:
	for piece in _pieces:
		if piece.role == "interior":
			var rect: Rect2 = piece.node.get_rect()
			return piece.node.transform * (rect.position + rect.size * Vector2(0.50, 0.58))
		if piece.role == "chest" and _style == "crystal":
			var rect: Rect2 = piece.node.get_rect()
			return piece.node.transform * (rect.position + rect.size * Vector2(0.51, 0.145))
	return _body_pivot - Vector2(0, _bounds.size.y * 0.5)


func _cavity_origin() -> Vector2:
	return _art.transform * _cavity_origin_in_art()


func _beam_strength() -> float:
	return maxf(_release_power() * 0.80, _opened_glow() * 0.96) + _release_impact() * 0.90


func _release_impact() -> float:
	return _release_power() * (1.0 - smoothstep(0.16, 0.60, _elapsed - Feel.RELEASE_TIME))


func _release_burst_origin() -> Vector2:
	var safe: Rect2 = _release_bounds()
	return _cavity_origin().clamp(safe.position, safe.end)


func _release_bloom_bounds() -> Rect2:
	var origin: Vector2 = _release_burst_origin()
	var safe: Rect2 = _release_bounds()
	var age: float = maxf(0.0, _elapsed - Feel.RELEASE_TIME)
	var spread: float = lerpf(0.28, 0.98, smoothstep(0.0, 0.10, age))
	var top_left: Vector2 = origin.lerp(safe.position, spread)
	return Rect2(top_left, origin.lerp(safe.end, spread) - top_left)


func _release_core_bounds() -> Rect2:
	var width: float = _bounds.size.x * _fit_scale
	var extent := Vector2(width * 0.85, width * 0.58)
	return Rect2(_release_burst_origin() - extent * 0.5, extent).intersection(_release_bounds())


func _release_edge_point(angle: float, reach: float) -> Vector2:
	var origin: Vector2 = _release_burst_origin()
	# Leave space for the widest wave stroke as well as the parent's clipping.
	var inset: float = minf(5.0 / _charge_scale, minf(size.x, size.y) * 0.04)
	var safe: Rect2 = _release_bounds().grow(-inset)
	var direction := Vector2.from_angle(angle)
	var extent := Vector2(maxf(0.0, safe.end.x - origin.x if direction.x >= 0.0 else origin.x - safe.position.x),
		maxf(0.0, safe.end.y - origin.y if direction.y >= 0.0 else origin.y - safe.position.y))
	return origin + direction * extent * reach


func _release_wave_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var age: float = maxf(0.0, _elapsed - Feel.RELEASE_TIME)
	var travel: float = 0.16 + (1.0 - exp(-age * 14.0)) * 0.80
	for index in range(65):
		points.append(_release_edge_point(TAU * float(index) / 64.0, travel))
	return points


func _release_wave_bounds() -> Rect2:
	var points: PackedVector2Array = _release_wave_points()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds.grow(_release_wave_width() * 0.5)


func _release_wave_width() -> float:
	return minf(9.0 / _charge_scale, minf(size.x, size.y) * 0.08)


func _draw_release_bloom(bounds: Rect2, color: Color) -> void:
	# Four texture quadrants keep the hot source at the actual cavity while
	# filling the space above it, even in a shallow landscape stage.
	var origin: Vector2 = _release_burst_origin()
	var half_texture: Vector2 = CHARGE_GLOW.get_size() * 0.5
	for row in range(2):
		for column in range(2):
			var top_left := Vector2(bounds.position.x if column == 0 else origin.x,
				bounds.position.y if row == 0 else origin.y)
			var bottom_right := Vector2(origin.x if column == 0 else bounds.end.x,
				origin.y if row == 0 else bounds.end.y)
			var rect := Rect2(top_left, bottom_right - top_left)
			if rect.size.x > 0.01 and rect.size.y > 0.01:
				_flash.draw_texture_rect_region(CHARGE_GLOW, rect,
					Rect2(Vector2(column, row) * half_texture, half_texture), color)


func _opened_beam_bounds() -> Rect2:
	var safe: Rect2 = _release_bounds()
	var origin: Vector2 = _cavity_origin()
	var half_width: float = minf(origin.x - safe.position.x, safe.end.x - origin.x) * 0.94
	return Rect2(Vector2(origin.x - half_width, safe.position.y),
		Vector2(half_width * 2.0, maxf(0.0, origin.y - safe.position.y)))


func _cavity_glow_bounds() -> Rect2:
	var origin: Vector2 = _cavity_origin()
	var width: float = _bounds.size.x * _fit_scale
	return Rect2(origin - Vector2(width * 0.40, width * 0.16), Vector2(width * 0.80, width * 0.32)).intersection(_release_bounds())


func _seam_points() -> PackedVector2Array:
	for piece in _pieces:
		if piece.role in ["body", "chest"]:
			var rect: Rect2 = piece.node.get_rect()
			var ratios: Array = [Vector2(0.03, 0.03), Vector2(0.67, 0.20), Vector2(0.98, 0.025)]
			if _style == "royal":
				ratios = [Vector2(0.08, 0.02), Vector2(0.68, 0.14), Vector2(0.94, 0.01)]
			elif _style == "crystal":
				ratios = [Vector2(0.04, 0.15), Vector2(0.74, 0.23), Vector2(0.97, 0.08)]
			var points := PackedVector2Array()
			for ratio: Vector2 in ratios:
				points.append(_art.transform * piece.node.transform * (rect.position + rect.size * ratio))
			return points
	return PackedVector2Array()


func _light_origin() -> Vector2:
	var seam: PackedVector2Array = _seam_points()
	return (seam[0] + seam[1] * 2.0 + seam[2]) * 0.25 if seam.size() == 3 else size * 0.5


func _release_bounds() -> Rect2:
	var inset: float = minf(8.0 / _charge_scale, minf(size.x, size.y) * 0.06)
	return Rect2(Vector2.ONE * inset, (size - Vector2.ONE * inset * 2.0).max(Vector2.ZERO))


func _release_radius() -> Vector2:
	var origin: Vector2 = _light_origin()
	var safe: Rect2 = _release_bounds()
	return Vector2(maxf(0.0, minf(origin.x - safe.position.x, safe.end.x - origin.x)),
		maxf(0.0, minf(origin.y - safe.position.y, safe.end.y - origin.y))) * 0.94


func _draw_radiance() -> void:
	if _fit_scale <= 0.0:
		return
	var pressure: float = _lid_pressure()
	var buildup: float = _buildup_glow()
	var flash: float = _release_power()
	var ambient: float = _opened_glow()
	var light: float = maxf(flash, ambient)
	if pressure <= 0.001 and buildup <= 0.001 and light <= 0.001:
		return
	var origin: Vector2 = _light_origin()
	var width: float = minf(_bounds.size.x * _fit_scale, size.x * 0.80)
	var radius: Vector2 = _release_radius()
	var spread: float = maxf(flash, smoothstep(0.0, 0.50, ambient) * 0.94)
	var glow: Vector2 = Vector2(width * 0.60, width * 0.35).lerp(radius * 2.0, spread)
	_radiance.draw_texture_rect(CHARGE_GLOW, Rect2(origin - glow * 0.5, glow), false,
		Color(_release_color, pressure * 0.35 + light))
	if buildup > 0.001:
		_radiance.draw_texture_rect(CHARGE_GLOW, _buildup_bounds(), false, Color(_release_color, buildup))
	var safe: Rect2 = _release_bounds()
	var expansion: float = 0.12 + _buildup_intensity() * 0.70
	var height: float = maxf(0.0, origin.y - safe.position.y) * expansion
	# Sealed-lid leakage stays behind the chest. Once open, the cavity's
	# shafts render in front of the inner lid so it cannot swallow the light.
	if buildup <= 0.001:
		return
	for ray in range(7):
		var lean: float = float(ray - 3) / 3.0
		var beam_spread: float = 0.45 + _buildup_intensity() * 0.40
		var half_width: float = safe.size.x * (0.085 if ray % 2 == 0 else 0.045) * beam_spread
		var top: Vector2 = origin + Vector2(lean * radius.x * 0.88 * beam_spread, -height)
		var points := PackedVector2Array([origin - Vector2(width * 0.08, 0),
			origin + Vector2(width * 0.08, 0),
			Vector2(minf(safe.end.x, top.x + half_width), top.y),
			Vector2(maxf(safe.position.x, top.x - half_width), top.y)])
		var ray_alpha: float = buildup * 0.48
		_radiance.draw_polygon(points, PackedColorArray([Color(_release_color, ray_alpha),
			Color(_release_color, ray_alpha), Color(_release_color, 0), Color(_release_color, 0)]))


func _draw_cavity_light() -> void:
	var strength: float = _beam_strength()
	if _fit_scale <= 0.0 or strength <= 0.001:
		return
	var origin: Vector2 = _cavity_origin()
	var bounds: Rect2 = _opened_beam_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var width: float = minf(_bounds.size.x * _fit_scale, bounds.size.x)
	var hot: Color = _release_color.lightened(0.82)
	var impact: float = _release_impact()
	for ray in range(7):
		var lean: float = float(ray - 3) / 3.0
		if mode == "opened" and not reduced_motion:
			lean += sin(_idle_time * TAU / (OPEN_SWAY_SECONDS * 1.8) + float(ray) * 0.7) * 0.045 * smoothstep(0.0, 0.65, _idle_time)
		var top_x: float = origin.x + lean * bounds.size.x * 0.38
		var spread: float = bounds.size.x * (0.11 if ray % 2 == 0 else 0.065) * (1.0 + impact * 0.28)
		var left := Vector2(maxf(bounds.position.x, top_x - spread), bounds.position.y)
		var right := Vector2(minf(bounds.end.x, top_x + spread), bounds.position.y)
		var base_left: Vector2 = origin - Vector2(width * 0.13, 0)
		var base_right: Vector2 = origin + Vector2(width * 0.13, 0)
		var alpha: float = minf(1.0, strength * (1.0 if ray == 3 else 0.76))
		# A white-hot mouth becomes saturated theme light farther from its
		# source. Midpoints preserve a visible shaft instead of a faint triangle.
		_cavity_light.draw_polygon(PackedVector2Array([base_left, base_right,
			base_right.lerp(right, 0.46), right, left, base_left.lerp(left, 0.46)]),
			PackedColorArray([Color(hot, alpha), Color(hot, alpha),
				Color(_release_color.lightened(0.12 + impact * 0.48), alpha * (0.58 + impact * 0.24)), Color(_release_color, 0),
				Color(_release_color, 0), Color(_release_color.lightened(0.12 + impact * 0.48), alpha * (0.58 + impact * 0.24))]))
	var glow: Rect2 = _cavity_glow_bounds()
	_cavity_light.draw_texture_rect(CHARGE_GLOW, glow, false, Color(_release_color, strength))
	var core := Rect2(origin - glow.size * Vector2(0.28, 0.18), glow.size * Vector2(0.56, 0.36))
	_cavity_light.draw_texture_rect(CHARGE_GLOW, core, false, Color(hot, strength))


func _draw_seam() -> void:
	if _fit_scale <= 0.0:
		return
	var seam: PackedVector2Array = _seam_points()
	if seam.is_empty():
		return
	var pressure: float = _lid_pressure()
	var buildup: float = _buildup_glow()
	var pixel: float = 1.0 / _charge_scale
	# The solid lock/core occludes this light; it cannot shine through metal.
	if pressure > 0.001:
		_seam_light.draw_polyline(seam, Color(_release_color, pressure * 0.18), (5.0 + pressure * 8.0) * pixel, true)
		_seam_light.draw_polyline(seam, Color(_release_color, pressure * 0.80), (1.0 + pressure * 2.0) * pixel, true)
		_seam_light.draw_polyline(seam, Color(Color.WHITE, pressure * 0.72), pixel, true)
	if buildup > 0.001:
		var origin: Vector2 = _light_origin()
		var width: float = _bounds.size.x * _fit_scale
		var glow: Vector2 = Vector2(width * (0.60 + buildup * 0.25), width * (0.10 + buildup * 0.22)).min(_release_radius() * 2.0)
		_seam_light.draw_texture_rect(CHARGE_GLOW, Rect2(origin - glow * 0.5, glow), false,
			Color(_release_color.lightened(0.20), buildup * 0.80))
		_seam_light.draw_polyline(seam, Color(_release_color, buildup * 0.30), (8.0 + buildup * 12.0) * pixel, true)
		_seam_light.draw_polyline(seam, Color(_release_color.lightened(0.55), buildup), (1.0 + buildup * 2.0) * pixel, true)
	var ambient: float = _opened_glow()
	if ambient > 0.001:
		var origin: Vector2 = _light_origin()
		var radius: Vector2 = _release_radius()
		var glow: Vector2 = Vector2(_bounds.size.x * _fit_scale * 0.98,
			_bounds.size.x * _fit_scale * 0.44).min(radius * 2.0)
		_seam_light.draw_texture_rect(CHARGE_GLOW, Rect2(origin - glow * 0.5, glow), false,
			Color(_release_color.lightened(0.50), ambient * 0.80))
		_seam_light.draw_polyline(seam, Color(_release_color, ambient * 0.72), 6.0 * pixel, true)
		_seam_light.draw_polyline(seam, Color(_release_color.lightened(0.82), ambient), 2.0 * pixel, true)


func _draw_flash() -> void:
	if reduced_motion or _fit_scale <= 0.0:
		return
	var flash: float = _release_power()
	if flash <= 0.001:
		return
	var seam: PackedVector2Array = _seam_points()
	if seam.is_empty():
		return
	var origin: Vector2 = _release_burst_origin()
	var pixel: float = 1.0 / _charge_scale
	var age: float = maxf(0.0, _elapsed - Feel.RELEASE_TIME)
	var impact: float = _release_impact()
	var expansion: float = lerpf(0.28, 0.98, smoothstep(0.0, 0.10, age))
	var hot: Color = _release_color.lightened(0.88)
	# Additive light has a distinct white-hot attack, then reveals the themed
	# rays and the chest again. The bloom reaches upward independently of the
	# floor clearance, so landscape layouts retain a substantial release.
	_draw_release_bloom(_release_bloom_bounds(), Color(_release_color.lightened(0.18), flash * 0.85))
	_draw_release_bloom(_release_core_bounds(), Color(hot, impact * 0.90))
	_flash.draw_polyline(seam, Color(hot, impact), (5.0 + impact * 9.0) * pixel, true)
	for wedge in range(24):
		var a: float = TAU * float(wedge) / 24.0 - 0.06
		var b: float = a + TAU / 24.0 * 0.42
		var ray_a: Vector2 = _release_edge_point(a, expansion * (0.98 if wedge % 2 == 0 else 0.64))
		var ray_b: Vector2 = _release_edge_point(b, expansion * (0.64 if wedge % 2 == 0 else 0.98))
		if absf((ray_a - origin).cross(ray_b - origin)) > 0.01:
			_flash.draw_polygon(PackedVector2Array([origin, ray_a, ray_b]),
				PackedColorArray([Color(hot, impact * 0.78), Color(_release_color, 0), Color(_release_color, 0)]))
	var travel: float = 1.0 - exp(-age * 14.0)
	var wave: PackedVector2Array = _release_wave_points()
	var wave_alpha: float = flash * (1.0 - smoothstep(0.14, 0.50, age))
	var wave_width: float = _release_wave_width()
	_flash.draw_polyline(wave, Color(_release_color, wave_alpha * 0.55), wave_width, true)
	_flash.draw_polyline(wave, Color(hot, wave_alpha * 0.95), wave_width * 0.30, true)
	for ray in range(12):
		var angle: float = TAU * float(ray) / 12.0 - 0.15
		var head: Vector2 = _release_edge_point(angle, travel * 0.96)
		var tail: Vector2 = _release_edge_point(angle, maxf(0.0, travel - 0.30))
		_flash.draw_line(tail, head, Color(hot, impact * 0.90), (4.0 - travel * 2.0) * pixel, true)


func _crystal_opening() -> float:
	if _style != "crystal" or not mode in ["opening", "opened"]:
		return 0.0
	return smoothstep(Feel.RELEASE_TIME, Feel.RELEASE_TIME + 0.38, _elapsed)


func _crystal_face_points(coordinates: Array, opening: float) -> PackedVector2Array:
	var sprite: Sprite2D = _pieces[0].node
	var texture_size: Vector2 = sprite.texture.get_size()
	var points := PackedVector2Array()
	# Coordinates follow the top face of the original Crystal base. Reveal
	# depth away from its front rim instead of replacing or tinting the box.
	for point in coordinates:
		var coordinate: Vector2 = Vector2(point) / Vector2(805.0, 609.0)
		coordinate.y = lerpf(0.205, coordinate.y, opening)
		points.append(sprite.offset + coordinate * texture_size)
	return points


func _draw_crystal_cavity() -> void:
	var opening: float = _crystal_opening()
	if _crystal_cavity == null or opening <= 0.001:
		return
	var rim: PackedVector2Array = _crystal_face_points([
		Vector2(29, 91), Vector2(222, 12), Vector2(783, 48), Vector2(595, 140)], opening)
	var inside: PackedVector2Array = _crystal_face_points([
		Vector2(49, 86), Vector2(229, 28), Vector2(750, 56), Vector2(587, 121)], opening)
	var floor: PackedVector2Array = _crystal_face_points([
		Vector2(105, 99), Vector2(254, 50), Vector2(694, 74), Vector2(575, 122)], opening)
	var light: float = maxf(_opened_glow(), _release_power())
	_crystal_cavity.draw_colored_polygon(rim, _charge_color.darkened(0.62).lerp(_release_color, light * 0.35))
	_crystal_cavity.draw_colored_polygon(inside, Color("#10252e").lerp(_release_color, light * 0.68))
	_crystal_cavity.draw_colored_polygon(floor, _charge_color.darkened(0.81).lerp(_release_color.lightened(0.86), light))
	var edge := PackedVector2Array([rim[3], rim[0], rim[1], rim[2]])
	_crystal_cavity.draw_polyline(edge, Color(_charge_spark, 0.70), 2.5, true)


func _draw_details() -> void:
	if reduced_motion or _fit_scale <= 0.0 or not (_hold_active or mode == "opening"):
		return
	var opening_now: bool = mode == "opening"
	var time: float = _elapsed if opening_now else _charge_time
	var release: float = maxf(0.0, time - Feel.RELEASE_TIME) if opening_now else 0.0
	var visual_progress: float = performance_progress()
	var fade: float = (0.35 + visual_progress * 0.65) * (1.0 - smoothstep(Feel.BUILDUP_SECONDS + 1.05, Feel.BUILDUP_SECONDS + 1.6, time)) if opening_now else 0.35 + visual_progress * 0.55
	var center: Vector2 = _art.transform * (_bounds.get_center() - Vector2(0, _bounds.size.y * 0.12))
	var extent := Vector2(_bounds.size.x * _fit_scale * 0.48, _bounds.size.y * _fit_scale * 0.40)
	var radius: float = maxf(0.8, minf(extent.x, extent.y) * 0.055)
	var detail_min := Vector2(radius * 3.0, _charge_inset + radius * 3.0)
	var detail_max := Vector2(maxf(detail_min.x, size.x - radius * 3.0), maxf(detail_min.y, size.y - radius * 3.0))
	var color := Color(_charge_spark, fade * 0.75)
	var detail: String = _feel.decoration
	if detail == "orbit":
		for ring in range(2):
			var orbit := PackedVector2Array()
			for index in range(33):
				var angle: float = TAU * float(index) / 32.0
				var position: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.30).rotated(-0.22 + ring * 0.44) * extent.x * (0.65 + ring * 0.18)
				orbit.append(position.clamp(detail_min, detail_max))
			_details.draw_polyline(orbit, Color(_charge_color, fade * 0.55), maxf(1.0, radius * 0.35), true)
	for index in range(8):
		var phase: float = float(index) / 8.0
		var angle: float = TAU * phase + (time * 0.22 if detail == "orbit" else 0.0)
		var distance: float = 0.75 + (minf(release, 0.55) * 0.4 if opening_now else sin(time * 2.0 + index) * 0.04)
		var position: Vector2 = center + Vector2(cos(angle), sin(angle)) * extent * distance
		if detail == "petals":
			var side: float = -1.0 if index < 4 else 1.0
			var anchor := Vector2(_bounds.get_center().x + side * _bounds.size.x * 0.29,
				_bounds.position.y + _bounds.size.y * 0.35)
			var flick: float = sin(clampf(release / 0.52, 0.0, 1.0) * PI)
			position = _art.transform * anchor + Vector2.from_angle(phase * TAU * 2.0) * radius * (1.6 + visual_progress * 0.6)
			position += Vector2(side * release * extent.x * 0.20, -flick * extent.y * 0.18)
		elif detail == "bubbles":
			position.y -= fposmod(time * 9.0 + index * 3.0, maxf(1.0, extent.y * 0.4))
		elif detail == "falling_leaves":
			var side: float = -1.0 if index < 4 else 1.0
			position = center + Vector2(side * extent.x * (0.63 + float(index % 4) * 0.09), -extent.y * 0.46)
			position += Vector2(sin(time * 3.0 + index) * radius * 1.8, release * release * extent.y * 0.65 + float(index % 4) * radius)
		elif detail == "vine_leaves":
			var side: float = -1.0 if index < 4 else 1.0
			var row: float = float(index % 4)
			var anchor := Vector2(_bounds.get_center().x + side * _bounds.size.x * 0.31,
				_bounds.get_center().y + _bounds.size.y * (0.10 + row * 0.045))
			var pull: float = Feel.opening(theme_id, time - 0.14 - row * 0.035) if opening_now else visual_progress * 0.25
			var origin: Vector2 = _art.transform * anchor
			position = origin + Vector2(side * radius * (3.2 + row * 0.6 + pull * 2.0), -radius * (1.5 + row + pull * 4.0))
			position = position.clamp(detail_min, detail_max)
			var bend: Vector2 = origin.lerp(position, 0.50) + Vector2(side * radius * 1.4, radius * (1.0 - pull))
			_details.draw_polyline(PackedVector2Array([origin.clamp(detail_min, detail_max), bend.clamp(detail_min, detail_max), position]),
				Color(_charge_color, fade * 0.6), maxf(1.0, radius * 0.35), true)
		# Decoration is clipped to measured stage space, including short phones.
		position = position.clamp(detail_min, detail_max)
		match detail:
			"sun_rays":
				var direction := Vector2.from_angle(angle)
				_details.draw_line(position - direction * radius, position + direction * radius * (1.8 + visual_progress), color, maxf(1.0, radius * 0.50), true)
			"ice_facets":
				for arm in range(3):
					var direction := Vector2.from_angle(float(arm) * PI / 3.0)
					_details.draw_line(position - direction * radius, position + direction * radius, color, maxf(1.0, radius * 0.27), true)
			"bubbles":
				_details.draw_arc(position, radius * (0.7 + phase), 0.0, TAU, 16, color, maxf(1.0, radius * 0.25), true)
				_details.draw_circle(position + Vector2(-0.25, -0.35) * radius, radius * 0.20, Color(Color.WHITE, fade * 0.6))
			"orbit":
				_details.draw_circle(position, radius * (1.1 if index % 2 == 0 else 0.55), color)
			"sprinkles":
				var direction := Vector2.from_angle(angle + sin(time * 8.0 + index) * 0.35)
				_details.draw_line(position - direction * radius, position + direction * radius, Color(_charge_color if index % 2 else _charge_spark, fade), maxf(1.0, radius * 0.7), true)
			_:
				var direction := Vector2.from_angle(angle + sin(time * 3.0 + index) * 0.2)
				var side := direction.orthogonal()
				var leaf := PackedVector2Array([position - direction * radius * 1.5,
					position + side * radius * 0.7, position + direction * radius * 1.5,
					position - side * radius * 0.7])
				_details.draw_colored_polygon(leaf, color)
				if detail == "vine_leaves":
					_details.draw_line(position - direction * radius * 2.8, position + direction * radius * 1.5, Color(_charge_color, fade * 0.65), maxf(1.0, radius * 0.3), true)


func play_tap() -> void:
	if reduced_motion or mode != "closed":
		return
	_tap_remaining = 0.35
	_animation_origin_frame = Engine.get_process_frames()
	_fit()


func stop_reaction() -> void:
	_tap_remaining = 0.0
	hold_progress = 0.0
	_hold_active = false
	_release_active = false
	_charge_time = 0.0
	_cancel_remaining = 0.0
	_cancel_piece_poses.clear()
	_charge_step = 0
	_opening_cues_enabled = false
	_pulse_step = 0
	_hold_pulse_step = 0
	_pulse_holding = false
	_art.rotation = 0.0
	_glint.hide()
	_charge.hide()
	_apply_pose(0.0)
	_fit()


func _clamp_drag_offset(value: Vector2, fit: float, bob: float, pulse: Vector2, safe_top: float) -> Vector2:
	var dimensions: Vector2 = _motion_bounds.size * fit * pulse
	var center := Vector2(size.x * 0.5, size.y * 0.59 + bob)
	var minimum := dimensions * 0.5 - center
	minimum.y += safe_top
	var maximum := size - dimensions * 0.5 - center
	return Vector2(
		clampf(value.x, minimum.x, maximum.x) if minimum.x <= maximum.x else 0.0,
		clampf(value.y, minimum.y, maximum.y) if minimum.y <= maximum.y else 0.0
	)


func _rotate_piece(pose: Transform2D, angle: float) -> Transform2D:
	var origin: Vector2 = pose.origin
	pose = pose.rotated(angle)
	pose.origin = origin
	return pose


func _charged_piece_pose(index: int, pressure: float, progress: float, time: float) -> Transform2D:
	var piece: Dictionary = _pieces[index]
	var pose: Transform2D = piece.rest
	if pressure <= 0.0:
		return pose
	var tension: float = Feel.pulse_motion(time, _pulse_holding)
	if _style == "crystal" and piece.role != "chest":
		var direction: Vector2 = pose.origin - _bounds.get_center()
		if direction.length_squared() < 1.0:
			direction = Vector2.UP
		var group: int = (index * 3) % 8 % CHARGE_STEPS
		var stage: float = smoothstep(float(group) / CHARGE_STEPS, float(group + 1) / CHARGE_STEPS, progress)
		var turn: float = (0.010 * pressure + 0.025 * stage) * (1.0 if index % 2 == 0 else -1.0)
		if theme_id == "winter":
			turn *= 0.40
		elif theme_id == "ocean":
			turn *= 0.75
		elif theme_id == "candy":
			turn *= 1.65
		pose = _rotate_piece(pose, turn)
		pose.origin -= direction.normalized() * _bounds.size.x * (0.003 * pressure + 0.008 * stage)
		# The plates visibly resist pressure; the body underneath stays solid.
		pose.origin.y -= _bounds.size.y * 0.014 * pow(progress, 1.6)
	elif _rigged and piece.role == "lid_outer":
		var stored: float = pow(progress, 1.6)
		pose.origin.y -= _bounds.size.y * (0.014 * stored + absf(tension) * 0.005)
		pose = pose * Transform2D(tension * 0.006, Vector2.ZERO)
	elif _rigged and piece.role == "latch":
		var stages: float = smoothstep(0.0, 1.0 / 3.0, progress) * 0.25
		stages += smoothstep(1.0 / 3.0, 2.0 / 3.0, progress) * 0.30
		stages += smoothstep(2.0 / 3.0, 1.0, progress) * 0.45
		var turn: float = (0.010 * pressure + stages * 0.060 + tension * 0.016) * (0.65 if theme_id == "autumn" else 1.0)
		pose = pose * Transform2D(turn, Vector2.ZERO)
		pose.origin.y += _bounds.size.y * (0.004 * pressure + stages * 0.003)
	elif _rigged and piece.role == "core":
		var stages: float = smoothstep(0.0, 1.0 / 3.0, progress) * 0.035
		stages += smoothstep(1.0 / 3.0, 2.0 / 3.0, progress) * 0.050
		stages += smoothstep(2.0 / 3.0, 1.0, progress) * 0.070
		var turn: float = (0.020 * pressure + stages + tension * 0.006) * (1.0 if theme_id == "summer" else -1.0)
		pose = pose * Transform2D(turn, Vector2.ZERO)
	return pose


func _piece_pose(index: int, time: float, opening_now: bool) -> Dictionary:
	var piece: Dictionary = _pieces[index]
	var hold: Vector2 = _hold_pose_state()
	var charge_time: float = _pulse_clock()
	if opening_now:
		var anticipation: float = 1.0 - smoothstep(Feel.RELEASE_TIME, Feel.RELEASE_TIME + 0.075, time)
		var energy: float = Feel.tension(time)
		hold = Vector2(0.30 + energy * 0.70, energy) * anticipation if not reduced_motion else Vector2.ZERO
	var pose: Transform2D = _charged_piece_pose(index, hold.x, hold.y, charge_time)
	var alpha: float = 1.0
	var progress: float = Feel.opening(theme_id, time) if opening_now else 0.0
	var stop: float = Feel.stop_response(time) if opening_now and not reduced_motion else 0.0
	if _style == "crystal" and piece.role == "01":
		# The small central crystal is the lock. It releases before the large
		# facets, so their shared source artwork still reads as a mechanism.
		var unlock: float = smoothstep(Feel.UNLOCK_TIME, Feel.RELEASE_TIME, time) if opening_now else 0.0
		var twist: float = 0.14 if theme_id == "winter" else -0.10 if theme_id == "ocean" else 0.20
		pose = _rotate_piece(pose, twist * unlock)
		pose.origin.y -= _bounds.size.y * 0.035 * unlock
	elif _style == "crystal" and piece.role != "chest":
		# Opposing facets move in distinct waves, never as one enlarged sprite.
		if theme_id == "candy":
			progress = Feel.opening(theme_id, time, 0 if index % 2 == 0 else 7) if opening_now else 0.0
		else:
			progress = Feel.opening(theme_id, time, (index * 3) % 8) if opening_now else 0.0
		var direction: Vector2 = pose.origin - _bounds.get_center()
		if direction.length_squared() < 1.0:
			direction = Vector2.UP
		var spread: float = float(_feel.spread)
		var turn: float = (0.11 if index % 2 == 0 else -0.11) * progress
		if theme_id == "winter":
			turn *= 0.45
		elif theme_id == "ocean":
			var side: float = -1.0 if direction.x < 0.0 else 1.0
			direction = Vector2(side, -0.60 - absf(direction.y) / maxf(1.0, _bounds.size.y))
			turn = side * 0.21 * progress
		elif theme_id == "candy":
			turn *= 1.65
		pose = _rotate_piece(pose, turn)
		pose.origin += direction.normalized() * _bounds.size.x * spread * (progress - stop * 0.10)
		pose = _rotate_piece(pose, stop * (0.040 if index % 2 == 0 else -0.040))
	elif _rigged:
		match piece.role:
			"lid_outer":
				if theme_id == "space":
					# A magnetic cover keeps its rigid silhouette while detaching;
					# it does not inherit the solar chest's hinged opening.
					pose = pose * Transform2D(-0.045 * progress + stop * 0.065, Vector2.ZERO)
					pose.origin += Vector2(_bounds.size.x * 0.015 * progress,
						-_bounds.size.y * (0.29 * progress - stop * 0.030))
				else:
					var squash: float = maxf(0.0, cos(clampf(progress, 0.0, 1.0) * PI))
					pose = pose * Transform2D(0.0, Vector2(1.0, maxf(0.001, squash)), 0.0, Vector2.ZERO)
					alpha = 1.0 if progress < 0.5 else 0.0
					if theme_id == "jungle":
						var pull: float = sin(clampf(progress, 0.0, 1.0) * PI)
						pose = pose * Transform2D(-0.055 * pull, Vector2.ZERO)
						pose.origin.x += _bounds.size.x * 0.018 * pull
			"lid_inner":
				var rise: float = maxf(0.0, -cos(clampf(progress, 0.0, 1.0) * PI))
				pose = pose * Transform2D(0.0, Vector2(1.0, maxf(0.001, rise)), 0.0, Vector2.ZERO)
				alpha = 1.0 if progress >= 0.5 and theme_id != "space" else 0.0
				pose = pose * Transform2D(-stop * (0.12 if theme_id == "autumn" else 0.085), Vector2.ZERO)
				pose.origin.y += _bounds.size.y * 0.024 * stop
				if theme_id == "jungle":
					var pull: float = sin(clampf(progress, 0.0, 1.0) * PI)
					pose = pose * Transform2D(-0.055 * pull, Vector2.ZERO)
					pose.origin.x += _bounds.size.x * 0.018 * pull
			"interior":
				alpha = 1.0 if progress > 0.01 or hold.y > 0.30 else 0.0
			"latch":
				var unlock: float = smoothstep(Feel.UNLOCK_TIME, Feel.RELEASE_TIME, time) if opening_now else 0.0
				pose = pose * Transform2D(-0.22 * unlock, Vector2.ZERO)
				pose.origin.y += _bounds.size.y * 0.035 * unlock
			"core":
				var unlock: float = smoothstep(Feel.UNLOCK_TIME, Feel.RELEASE_TIME, time) if opening_now else 0.0
				pose = pose * Transform2D((PI * 0.16 if theme_id == "summer" else -PI * 0.25) * unlock, Vector2.ZERO)
				pose.origin.y -= _bounds.size.y * 0.018 * progress
	elif _style != "crystal":
		# Old manifests still render safely if a derived rig is unavailable.
		# The fallback swaps only at the edge-on opening beat; it never ghosts
		# two complete boxes through an alpha crossfade.
		alpha = 1.0 if (piece.role == "closed") == (progress < 0.5) else 0.0
	return {"pose": pose, "alpha": alpha}


func _apply_pose(_progress: float) -> void:
	var returning: float = smoothstep(0.0, Feel.CANCEL_SECONDS, _cancel_remaining)
	for index in range(_pieces.size()):
		var state: Dictionary = _piece_pose(index, _elapsed, mode in ["opening", "opened"])
		if returning > 0.0 and index < _cancel_piece_poses.size():
			# Return the entire mechanism from the last rendered pose. Rewinding
			# the timeline would replay its pressure kicks and unlock motion.
			var rest_pose: Transform2D = state.pose
			state.pose = rest_pose.interpolate_with(_cancel_piece_poses[index].pose, returning)
			state.alpha = lerpf(float(state.alpha), float(_cancel_piece_poses[index].alpha), returning)
		var sprite: Sprite2D = _pieces[index].node
		sprite.transform = state.pose
		var lighting: Color = _tint
		if not reduced_motion:
			var role: String = _pieces[index].role
			var open: float = Feel.opening(theme_id, _elapsed) if mode in ["opening", "opened"] else 0.0
			if role == "lid_outer":
				lighting = lighting.darkened(open * 0.22)
			elif role == "lid_inner":
				lighting = lighting.darkened((1.0 - open) * 0.20)
			# Reflected light on the body ties the effect to the chest surface.
			lighting = lighting.lerp(_release_color.lightened(0.48), _buildup_glow() * 0.16)
			lighting = lighting.lerp(_release_color.lightened(0.58), _release_power() * 0.23)
		sprite.modulate = Color(lighting, float(state.alpha))
	_update_surface_light()
	for edge in _lid_edges:
		var source: Sprite2D = edge.source
		var rim: Sprite2D = edge.node
		rim.transform = source.transform
		rim.scale.y = maxf(0.060, rim.scale.y)
		rim.position.y += _bounds.size.y * 0.017
		rim.modulate = Color(_tint.darkened(0.42).lerp(_release_color, _release_power() * 0.12), source.modulate.a)
	if is_instance_valid(_crystal_cavity):
		_crystal_cavity.queue_redraw()


func _update_surface_light() -> void:
	var light: float = maxf(_opened_glow(), _release_power()) + _release_impact() * 0.55
	if light <= 0.0:
		if _surface_light_active:
			for piece in _pieces:
				piece.node.material.set_shader_parameter("light_strength", 0.0)
		_surface_light_active = false
		return
	_surface_light_active = true
	var origin: Vector2 = _cavity_origin_in_art()
	for piece in _pieces:
		var sprite: Sprite2D = piece.node
		var material: ShaderMaterial = sprite.material
		var source: Vector2 = sprite.transform.affine_inverse() * origin
		var uv: Vector2 = (source - sprite.offset) / sprite.texture.get_size()
		if sprite.flip_h:
			uv.x = 1.0 - uv.x
		if sprite.flip_v:
			uv.y = 1.0 - uv.y
		var weight: float = 0.90 if piece.role in ["body", "chest", "closed", "open"] else 1.15
		if piece.role in ["interior", "lid_inner", "core"]:
			weight = 1.35
		material.set_shader_parameter("light_color", _release_color.lightened(0.55))
		material.set_shader_parameter("light_strength", light * weight)
		material.set_shader_parameter("light_origin", uv)
		material.set_shader_parameter("light_distance", sprite.texture.get_size() * sprite.scale.abs()
			/ Vector2(maxf(1.0, _bounds.size.x * 0.72), maxf(1.0, _bounds.size.y * 0.65)))


func start_open(reduce: bool) -> void:
	if mode != "closed":
		return
	reduced_motion = reduce
	var confirmed_steps: int = _charge_step
	stop_reaction()
	hold_progress = 0.0
	mode = "opening"
	_elapsed = 0.0
	_animation_origin_frame = Engine.get_process_frames()
	_release_active = not reduced_motion
	_opening_cues.clear()
	# A shorter buildup can light the first star before confirmation completes.
	for step in range(1, confirmed_steps + 1):
		_opening_cues["charge_step:" + str(step)] = true
	_opening_cues_enabled = is_visible_in_tree() and not reduced_motion
	_emit_cue("opening")
	if reduced_motion:
		finish_immediately()
	else:
		_apply_pose(0.0)
		_fit()


func finish_immediately() -> void:
	if mode != "opening":
		return
	mode = "opened"
	_idle_time = 0.0
	_release_active = false
	_opening_cues_enabled = false
	_elapsed = OPEN_SECONDS
	_apply_pose(1.0)
	_fit()
	opened.emit()


func clear() -> void:
	stop_reaction()
	mode = "closed"
	_elapsed = 0.0
	_idle_time = 0.0
	_animation_origin_frame = -1
	theme_id = ""
	hold_progress = 0.0
	drag_offset = Vector2.ZERO
	_cue_log.clear()
	_opening_cues.clear()
	_apply_pose(0.0)
	_fit()


func set_hold_progress(value: float) -> void:
	if mode != "closed":
		return
	if not is_finite(value):
		value = 0.0
	if value > 0.0 and not _hold_active:
		begin_hold()
	if value > 0.0:
		hold_progress = maxf(hold_progress, clampf(value, 0.0, 1.0)) if is_visible_in_tree() else 0.0
	else:
		hold_progress = 0.0
	if hold_progress <= 0.0:
		_hold_active = false
		_charge_time = 0.0
		_tap_remaining = 0.0
		_cancel_remaining = 0.0
		_cancel_piece_poses.clear()
		_charge_step = 0
		_hold_pulse_step = 0
		_pulse_step = 0
	else:
		if not reduced_motion:
			var time: float = hold_progress * Feel.HOLD_SECONDS
			var latest: int = _hold_pulse_step
			while latest < Feel.HOLD_PULSE_TIMES.size() and time >= float(Feel.HOLD_PULSE_TIMES[latest]):
				latest += 1
			if latest > _hold_pulse_step:
				_hold_pulse_step = latest
				var beat: float = float(Feel.HOLD_PULSE_TIMES[latest - 1])
				# A stalled frame consumes missed beats without playing a burst.
				if time - beat <= 0.20:
					_emit_cue("hold_pulse", latest, beat)
		var crossed: int = mini(CHARGE_STEPS, floori(performance_progress() * CHARGE_STEPS + 0.000001))
		var duration: float = Feel.HOLD_SECONDS if reduced_motion else Feel.HOLD_SECONDS + Feel.RELEASE_TIME
		while _charge_step < crossed:
			_charge_step += 1
			_emit_cue("charge_step", _charge_step, float(_charge_step) * duration / CHARGE_STEPS)
	_apply_pose(0.0)
	_fit()


func set_drag_offset(value: Vector2) -> void:
	drag_offset = value
	_fit()


func piece_count() -> int:
	return _pieces.size()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		stop_reaction()
	set_process(is_visible_in_tree() and not _idle_paused)


func set_idle_paused(value: bool) -> void:
	_idle_paused = value
	set_process(is_visible_in_tree() and not _idle_paused)


func _process(delta: float) -> void:
	# A parent or input callback can begin this action earlier in this same
	# frame. Its delta describes time before that transition and is not earned.
	if Engine.get_process_frames() == _animation_origin_frame:
		return
	_advance_animation(delta)


func _advance_animation(delta: float) -> void:
	# The deterministic step is also used by native simulations. Runtime
	# callers go through _process so a new action cannot inherit an old delta.
	if delta <= 0.0 or not is_finite(delta) or not is_visible_in_tree() or _idle_paused:
		return
	if mode == "opened" and not reduced_motion:
		_idle_time += delta
	if _hold_active and not reduced_motion:
		_charge_time += delta
	_tap_remaining = maxf(0.0, _tap_remaining - delta)
	_cancel_remaining = maxf(0.0, _cancel_remaining - delta)
	if mode == "opening":
		var was_committed: bool = opening_committed()
		_elapsed = minf(OPEN_SECONDS, _elapsed + delta)
		if not was_committed and opening_committed():
			# Input completes with the visible release, independently of audio
			# cues that may be skipped after a stalled or interrupted frame.
			release_reached.emit()
		if _opening_cues_enabled:
			for event in _opening_timeline:
				if mode != "opening" or not _opening_cues_enabled:
					break
				var key: String = str(event.cue) + ":" + str(event.step)
				if _elapsed >= float(event.time) and not _opening_cues.has(key):
					_opening_cues[key] = true
					var newer_pulse: bool = event.cue == "tension_pulse" and int(event.step) < Feel.PULSE_TIMES.size() and _elapsed >= float(Feel.PULSE_TIMES[int(event.step)])
					# Coalesce missed beats and latch the newest live kick to its
					# sound. Long stalls never replay a backlog or start a late rise.
					var live_pulse: bool = event.cue != "tension_pulse" or (not newer_pulse and _elapsed < Feel.ANTICIPATION_TIME)
					var live_rise: bool = event.cue != "anticipation" or (_elapsed < Feel.RELEASE_TIME and _elapsed - float(event.time) <= 0.08)
					if live_pulse and live_rise and _elapsed - float(event.time) <= 0.20:
						_emit_cue(str(event.cue), int(event.step), float(event.time))
		if _elapsed >= OPEN_SECONDS:
			finish_immediately()
	_apply_pose(0.0)
	_fit()

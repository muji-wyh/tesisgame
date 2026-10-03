extends "res://scripts/chest_view.gd"
## The twenty quest mechanisms inside the shared Match chest performance.

const Artist = preload("res://scripts/talk_quest_chest.gd")
const PROFILE_IDS: Array[String] = [
	"spring", "ocean", "autumn", "candy", "summer", "spring", "jungle",
	"autumn", "jungle", "space", "ocean", "jungle", "candy", "space",
	"spring", "winter", "space", "autumn", "summer", "candy"
]
# Conservative design-space envelopes include the complete opened mechanism.
# Fitting uses one envelope throughout the action, so the chest never resizes.
const ART_BOUNDS: Array[Rect2] = [
	Rect2(100, 108, 269, 207), Rect2(59, 91, 302, 206),
	Rect2(100, 105, 222, 195), Rect2(91, 89, 238, 228),
	Rect2(87, 90, 257, 240), Rect2(34, 48, 292, 258),
	Rect2(88, 108, 271, 219), Rect2(88, 4, 255, 303),
	Rect2(83, 88, 261, 220), Rect2(54, 96, 299, 228),
	Rect2(98, 61, 225, 252), Rect2(62, 114, 298, 204),
	Rect2(86, 68, 250, 255), Rect2(48, 69, 324, 247),
	Rect2(82, 30, 271, 296), Rect2(72, 70, 277, 230),
	Rect2(72, 91, 267, 223), Rect2(67, 84, 286, 223),
	Rect2(77, 107, 262, 251), Rect2(67, 115, 287, 226)
]
const FLOOR_Y: Array[float] = [
	310, 293, 294, 313, 324, 299, 322, 300, 303, 318,
	307, 311, 316, 310, 321, 293, 308, 303, 352, 333
]
const CAVITIES: Array[Vector2] = [
	Vector2(272, 211), Vector2(210, 205), Vector2(210, 202), Vector2(210, 211),
	Vector2(210, 260), Vector2(210, 225), Vector2(210, 232), Vector2(212, 231),
	Vector2(206, 225), Vector2(210, 184), Vector2(210, 242), Vector2(207, 234),
	Vector2(210, 235), Vector2(210, 231), Vector2(210, 209), Vector2(210, 230),
	Vector2(210, 203), Vector2(210, 238), Vector2(210, 229), Vector2(210, 221)
]
const SEAMS: Array = [
	[Vector2(248, 166), Vector2(272, 161), Vector2(297, 166)],
	[Vector2(157, 205), Vector2(210, 197), Vector2(263, 205)],
	[Vector2(116, 202), Vector2(210, 181), Vector2(304, 202)],
	[Vector2(210, 147), Vector2(210, 211), Vector2(210, 280)],
	[Vector2(181, 263), Vector2(210, 234), Vector2(239, 263)],
	[Vector2(121, 239), Vector2(210, 207), Vector2(299, 219)],
	[Vector2(113, 226), Vector2(211, 222), Vector2(312, 226)],
	[Vector2(115, 223), Vector2(212, 205), Vector2(314, 221)],
	[Vector2(124, 228), Vector2(206, 194), Vector2(287, 228)],
	[Vector2(111, 184), Vector2(210, 163), Vector2(309, 184)],
	[Vector2(111, 243), Vector2(210, 230), Vector2(309, 243)],
	[Vector2(135, 282), Vector2(206, 145), Vector2(279, 282)],
	[Vector2(111, 239), Vector2(210, 225), Vector2(309, 239)],
	[Vector2(130, 230), Vector2(210, 215), Vector2(292, 230)],
	[Vector2(94, 209), Vector2(210, 194), Vector2(326, 209)],
	[Vector2(148, 235), Vector2(210, 209), Vector2(267, 233)],
	[Vector2(210, 123), Vector2(210, 203), Vector2(210, 276)],
	[Vector2(167, 195), Vector2(210, 185), Vector2(253, 195)],
	[Vector2(130, 230), Vector2(210, 204), Vector2(289, 230)],
	[Vector2(139, 213), Vector2(210, 205), Vector2(282, 213)]
]

var chest_index: int = 1
var chest_id: String = "chest-01"
var chest_name: String = "Welcome Mailbox"
var _artist = Artist.new()
var _previewing: bool = false
var _surface_strength: float = 0.0
var _surface_material := ShaderMaterial.new()


func _ready() -> void:
	super._ready()
	_ensure_artist()


func _ensure_artist() -> void:
	if _artist.get_parent() == null:
		_art.add_child(_artist)
		_artist.size = Artist.DESIGN_SIZE
		_artist.set_external_control(true)
		_surface_material.shader = SURFACE_LIGHT
		# Vector primitives have no sprite UV atlas. The shared reflection shader
		# lights their painted colors uniformly; seam light supplies the origin.
		_surface_material.set_shader_parameter("light_distance", Vector2.ZERO)
		_artist.material = _surface_material


func configure(chest_data: Dictionary) -> void:
	_ensure_artist()
	_artist.configure(chest_data)
	chest_index = _artist.chest_index
	chest_id = _artist.chest_id
	chest_name = _artist.chest_name
	theme_id = PROFILE_IDS[chest_index - 1]
	_feel = Feel.profile(theme_id)
	_style = "quest"
	_tint = Color.WHITE
	_glint_color = _artist._accent.lightened(0.28)
	_charge_color = _artist._body
	_charge_spark = _artist._accent.lightened(0.25)
	_release_color = Feel.FLASH_COLORS[theme_id]
	_bounds = ART_BOUNDS[chest_index - 1]
	_motion_bounds = _bounds.grow(maxf(_bounds.size.x, _bounds.size.y) * 0.065)
	_body_pivot = Vector2(210, FLOOR_Y[chest_index - 1])
	_body_floor = _body_pivot
	# Custom art is drawn as a complete mechanism. Keep its cavity light behind
	# the opaque container; the common seam and release layers sit above it.
	_cavity_light.z_index = -1
	reset_closed()


func reset_closed() -> void:
	var selected_theme: String = theme_id
	_previewing = false
	super.clear()
	theme_id = selected_theme
	_artist.reset_closed()
	set_idle_paused(false)
	_apply_pose(0.0)
	_fit()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_artist.set_reduced_motion(enabled)
	if enabled:
		# Preserve a pending confirmation while removing only its motion.
		var was_holding: bool = _hold_active
		var earned_progress: float = hold_progress
		stop_reaction()
		if was_holding and mode == "closed":
			_hold_active = true
			hold_progress = earned_progress
		if mode == "opening" and not _previewing:
			finish_immediately()
	_apply_pose(0.0)
	_fit()


func start_open(reduce: bool) -> void:
	_previewing = false
	super.start_open(reduce)


func set_preview_time(seconds: float) -> void:
	# Preview uses the shared opening clock (after the confirmation hold).
	# It samples the same effects without emitting cues or gameplay events.
	_surprise.clear()
	stop_reaction()
	_previewing = true
	_elapsed = clampf(seconds, 0.0, OPEN_SECONDS) if is_finite(seconds) else 0.0
	mode = "opened" if _elapsed >= OPEN_SECONDS else "opening"
	_opening_cues_enabled = not reduced_motion
	_release_active = not reduced_motion
	_apply_pose(0.0)
	_fit()


func _advance_animation(delta: float) -> void:
	if not _previewing:
		super._advance_animation(delta)


func _has_art() -> bool:
	return is_instance_valid(_artist) and _artist.get_parent() == _art


func _apply_pose(_progress: float) -> void:
	if not _has_art():
		return
	var amount: float = 0.0
	if mode == "opened":
		amount = 1.0
	elif mode == "opening":
		amount = Feel.opening(theme_id, _elapsed)
	_artist.set_external_pose(amount)
	var reflected: float = _buildup_glow() * 0.16 + _release_power() * 0.23
	_surface_strength = maxf(_opened_glow(), _release_power()) + _release_impact() * 0.55
	_surface_material.set_shader_parameter("light_color", _release_color.lightened(0.55))
	_surface_material.set_shader_parameter("light_strength", _surface_strength)
	_artist.modulate = Color.WHITE.lerp(_release_color.lightened(0.58), clampf(reflected, 0, 0.4))


func _cavity_origin_in_art() -> Vector2:
	return CAVITIES[chest_index - 1]


func _seam_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in SEAMS[chest_index - 1]:
		result.append(_art.transform * point)
	return result


func hold_effect_snapshot() -> Dictionary:
	var state: Dictionary = super.hold_effect_snapshot()
	var rect: Rect2 = _bounds
	var physical: Rect2 = Rect2(_art.transform * rect.position, Vector2.ZERO)
	for corner: Vector2 in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		physical = physical.expand(_art.transform * corner)
	state["chest_id"] = chest_id
	state["design_index"] = chest_index
	state["interior_open"] = _artist._open_amount
	state["opened_surface_light"] = _surface_strength
	state["physical_bounds"] = {"x": physical.position.x, "y": physical.position.y,
		"width": physical.size.x, "height": physical.size.y}
	state["pose_signature"] += "/%s:%.3f" % [chest_id, _artist._open_amount]
	return state


func get_animation_state() -> Dictionary:
	return {"id": chest_id, "index": chest_index, "mode": mode,
		"elapsed": _elapsed, "open_amount": _artist._open_amount,
		"reward_revealed": opening_committed(), "duration": OPEN_SECONDS}

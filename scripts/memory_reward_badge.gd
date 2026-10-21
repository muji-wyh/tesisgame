extends Control
## A fixed reward marker. The Memory model owns its tier and settlement.

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const ChestView = preload("res://scripts/chest_view.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const CHANGE_SECONDS: float = 0.78
const SWAP_SECONDS: float = 0.34
const LOSS_HOLD_SECONDS: float = 0.40
const EMPTY_HOLD_SECONDS: float = 0.48

var chest := ChestView.new()
var tier_label := Style.label("", 13)
var _round_id: String = ""
var _tier: int = RewardProgress.THEMES.size()
var _display_tier: int = RewardProgress.THEMES.size()
var _theme_id: String = ""
var _manifest: Dictionary = {}
var _paused: bool = false
var _reduced_motion: bool = false
var _animating: bool = false
var _elapsed: float = 0.0
var _change_count: int = 0
var _origin_frame: int = -1
var _render_until_frame: int = -1
var _render_live: bool = false
var _original_materials: Dictionary = {}
var _empty_material := ShaderMaterial.new()


func _init() -> void:
	name = "MemoryRewardBadge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	chest.name = "MemoryPotentialChest"
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest.reduced_motion = true
	add_child(chest)
	tier_label.name = "MemoryChestTier"
	tier_label.add_theme_font_override("font", Style.HEADING_FONT)
	tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_label.clip_text = true
	add_child(tier_label)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	float grey = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(vec3(grey) * 0.78, pixel.a * 0.88);
}
"""
	_empty_material.shader = shader
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	set_process(false)
	hide()


func _ready() -> void:
	_prepare_chest()
	_layout()


func configure(round_id: String, tier: int, manifest: Dictionary, _palette: Dictionary, reduce: bool) -> bool:
	if round_id.is_empty() or tier < 0 or tier > RewardProgress.THEMES.size():
		return false
	var theme_id: String = RewardProgress.theme_for_tier(maxi(1, tier))
	var palette: Dictionary = Data.theme(theme_id)
	if not manifest.get("styles") is Dictionary or not manifest.styles.get(str(palette.chest)) is Dictionary:
		return false
	var new_round: bool = round_id != _round_id
	var stepped_down: bool = not new_round and tier < _tier
	if stepped_down and not reduce:
		_display_tier = _tier
	if new_round:
		_elapsed = 0.0
		_animating = false
		_change_count = 0
		_paused = false
	_round_id = round_id
	_tier = tier
	_manifest = manifest
	_reduced_motion = reduce
	if stepped_down:
		_change_count += 1
		_elapsed = 0.0
		_origin_frame = Engine.get_process_frames()
		_animating = not reduce
	if reduce:
		_animating = false
	if not _animating:
		_display_tier = tier
	visible = true
	_prepare_chest()
	tier_label.add_theme_color_override("font_color", Style.INK if tier > 0 else Style.MUTED)
	set("accessibility_name", "Potential reward: level %d chest." % tier if tier > 0 else "No chest this round. Keep matching to finish.")
	_layout()
	_sample()
	return true


func set_paused(value: bool) -> void:
	if value == _paused:
		return
	_paused = value
	if not value:
		_warm_chest()
	_sync_processing()


func reset() -> void:
	_round_id = ""
	_tier = RewardProgress.THEMES.size()
	_display_tier = _tier
	_animating = false
	_elapsed = 0.0
	_change_count = 0
	_paused = false
	_render_until_frame = -1
	chest.scale = Vector2.ONE
	chest.rotation = 0.0
	chest.modulate = Color.WHITE
	tier_label.text = ""
	hide()
	_sync_processing()


func advance(delta: float) -> void:
	if _paused or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	if _animating:
		_elapsed = minf(CHANGE_SECONDS, _elapsed + delta)
		_animating = _elapsed < CHANGE_SECONDS
	_sample()


func _process(delta: float) -> void:
	if Engine.get_process_frames() != _origin_frame:
		advance(delta)
	_sync_processing()


func _sample() -> void:
	if _display_tier != _tier and (not _animating or _elapsed >= SWAP_SECONDS):
		_display_tier = _tier
		_prepare_chest()
	# Reverse Jelly's full positive turn around the actual artwork center. Losing
	# a tier compresses and dims the chest; recovery has no celebratory overshoot.
	var art: Rect2 = chest.closed_art_rect()
	if art.has_area():
		chest.pivot_offset = art.get_center()
	var extent: float = 1.0
	var turn: float = 0.0
	var shade: float = 1.0
	if _animating and not _reduced_motion:
		var minimum: float = 0.18 if _tier == 0 else 0.40
		var hold_until: float = EMPTY_HOLD_SECONDS if _tier == 0 else LOSS_HOLD_SECONDS
		var darkest: float = 0.46 if _tier == 0 else 0.68
		if _elapsed < 0.10:
			extent = lerpf(1.0, 0.82, smoothstep(0.0, 0.10, _elapsed))
		elif _elapsed < SWAP_SECONDS:
			extent = lerpf(0.82, minimum, smoothstep(0.10, SWAP_SECONDS, _elapsed))
		else:
			extent = lerpf(minimum, 1.0, smoothstep(hold_until, CHANGE_SECONDS, _elapsed))
		shade = lerpf(1.0, darkest, smoothstep(0.0, 0.16, _elapsed))
		if _elapsed > hold_until:
			shade = lerpf(darkest, 1.0, smoothstep(hold_until, CHANGE_SECONDS, _elapsed))
		turn = -TAU * smoothstep(0.04, 0.68, _elapsed)
	chest.scale = Vector2.ONE * extent
	chest.rotation = turn
	chest.modulate = Color(shade, shade, shade, 1.0)
	_sync_processing()


func _prepare_chest() -> void:
	if not is_inside_tree() or _round_id.is_empty() or _manifest.is_empty():
		return
	var chosen: String = RewardProgress.theme_for_tier(maxi(1, _display_tier))
	if _theme_id != chosen:
		_original_materials.clear()
		_theme_id = chosen
		chest.configure_skin(Data.theme(chosen), _manifest)
		chest.reduced_motion = true
		_warm_chest()
	# The closed production artwork remains recognizable when no chest remains.
	# Replace only this instance's surface material; never mutate shared assets.
	for part: Dictionary in chest._pieces:
		var sprite: Sprite2D = part.node
		if _display_tier == 0:
			if not _original_materials.has(sprite):
				_original_materials[sprite] = sprite.material
			sprite.material = _empty_material
		elif _original_materials.has(sprite):
			sprite.material = _original_materials[sprite]
	if _display_tier > 0:
		_original_materials.clear()
	chest.set_process(false)


func _layout() -> void:
	var unit: float = 1.0 / Style.ui_scale(self)
	var edge: float = minf(56.0 * unit, size.y + 8.0 * unit)
	var target := Rect2(Vector2(-2.0 * unit, (size.y - edge) * 0.5), Vector2.ONE * edge)
	if chest.position != target.position or chest.size != target.size:
		chest.position = target.position
		chest.size = target.size
		_warm_chest()
	var left: float = maxf(44.0 * unit, edge - 4.0 * unit)
	tier_label.position = Vector2(left, 0)
	tier_label.size = Vector2(maxf(0.0, size.x - left), size.y)
	var pixels: int = ceili(13.0 * unit)
	var minimum_pixels: int = ceili(11.0 * unit)
	var text: String = "Chest\nLevel %d" % _tier if _tier > 0 else "No chest"
	if _label_width(text, minimum_pixels) > tier_label.size.x:
		text = "Chest\nLv %d" % _tier if _tier > 0 else "No\nchest"
	while pixels > minimum_pixels and _label_width(text, pixels) > tier_label.size.x:
		pixels -= 1
	tier_label.text = text
	tier_label.add_theme_font_size_override("font_size", pixels)
	_sample()


func _label_width(text: String, pixels: int) -> float:
	var width: float = 0.0
	for line: String in text.split("\n"):
		width = maxf(width, Style.HEADING_FONT.get_string_size(line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x)
	return width


func _visibility_changed() -> void:
	if is_visible_in_tree():
		_warm_chest()
	_sync_processing()


func _warm_chest() -> void:
	if is_inside_tree() and is_visible_in_tree() and not _paused:
		_render_until_frame = Engine.get_process_frames() + 3
	_sync_processing()


func _sync_processing() -> void:
	var active: bool = not _round_id.is_empty() and is_visible_in_tree() and not _paused
	var warm: bool = active and Engine.get_process_frames() < _render_until_frame
	if warm != _render_live:
		_render_live = warm
		chest.set_idle_paused(not warm)
		chest.set_process(false)
	set_process(active and (_animating or warm))


func snapshot() -> Dictionary:
	var area: Rect2 = get_global_rect()
	var art: Rect2 = chest.get_global_transform() * chest.closed_art_rect()
	var anchor: Vector2 = get_global_transform() * (chest.position + chest.size * 0.5)
	return {"visible": is_visible_in_tree(), "round_id": _round_id, "tier": _tier, "display_tier": _display_tier, "theme_id": _theme_id,
		"text": tier_label.text, "grey": _tier == 0, "paused": _paused, "reduced_motion": _reduced_motion,
		"animating": _animating, "elapsed": _elapsed, "change_count": _change_count,
		"scale": chest.scale.x, "rotation": chest.rotation, "shade": chest.modulate.r, "chest_mode": chest.mode,
		"anchor": [anchor.x, anchor.y], "art_center": [art.get_center().x, art.get_center().y],
		"rect": [area.position.x, area.position.y, area.size.x, area.size.y],
		"chest_rect": [art.position.x, art.position.y, art.size.x, art.size.y]}

extends Control
## Keeps the ended board visible while the reward room owns settlement.

signal home_requested

const Style = preload("res://scripts/ui_style.gd")
const CompanionResult = preload("res://scripts/round_settlement.gd")
const CompanionCelebration = preload("res://scripts/round_celebration.gd")
const RewardRoom = preload("res://scripts/pop_reward_room.gd")

var panel: Panel
var _panel_paper: ColorRect
var _panel_paper_material: ShaderMaterial
var _shade: ColorRect
var _room: Control
var _palette: Dictionary = {}
var _reduced_motion: bool = false
var _entrance: Tween
var _has_chest: bool = false
var _title: String = "Game over"


func _init() -> void:
	name = "SettlementDialog"
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade = ColorRect.new()
	_shade.color = Color(Style.INK, 0.52)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = Panel.new()
	panel.name = "SettlementPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(panel)
	_panel_paper = ColorRect.new()
	_panel_paper.name = "SettlementPaperGrain"
	_panel_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_paper.focus_mode = Control.FOCUS_NONE
	_panel_paper_material = Style.paper_material(Style.PAPER, Color("#f2f6ec"), 0.24, 0.015)
	_panel_paper.material = _panel_paper_material
	panel.add_child(_panel_paper)
	_panel_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	hide()


func configure(room: Control, palette: Dictionary, motion_reduced: bool, has_chest: bool, title: String = "Game over") -> void:
	if is_instance_valid(_room) and _room != room:
		_room.hide()
	_room = room
	_palette = palette.duplicate()
	_reduced_motion = motion_reduced
	_has_chest = has_chest
	_title = title
	panel.set("accessibility_name", title)
	if _room.get_parent() != panel:
		_room.reparent(panel, false)
	_room.show()
	_layout()


func open(animate: bool = false) -> void:
	if visible:
		return
	show()
	_layout()
	if _reduced_motion or not animate:
		return
	panel.scale = Vector2.ONE * 0.94
	panel.modulate.a = 0.0
	_shade.modulate.a = 0.0
	_entrance = create_tween().set_parallel(true)
	_entrance.tween_property(panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance.tween_property(panel, "modulate:a", 1.0, 0.16)
	_entrance.tween_property(_shade, "modulate:a", 1.0, 0.18)


func close() -> void:
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	panel.scale = Vector2.ONE
	panel.modulate.a = 1.0
	_shade.modulate.a = 1.0
	hide()


func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var s: float = Style.ui_scale(self)
	var accent: Color = _palette.get("accent", Style.GOOD)
	panel.add_theme_stylebox_override("panel", Style.parchment_panel(s, 12.0, 10.0))
	if _panel_paper_material != null:
		_panel_paper_material.set_shader_parameter("paper_tint", Style.PAPER)
		_panel_paper_material.set_shader_parameter("top_wash", Style.PAPER.lerp(accent.lightened(0.84), 0.55))
	# Keep the reward close to its result and actions, even on a large canvas.
	# A wide, short viewport still needs room for the two-column arrangement.
	var landscape: bool = size.x * s >= 600 and size.y * s < 480
	var companion_result: bool = _room is CompanionResult or _room is CompanionCelebration \
		or (_room is RewardRoom and not _room._result_context.is_empty())
	var chest_height: float = 460.0 if companion_result else 540.0
	var result_boss: bool = _room is RewardRoom and _room.wants_result_boss()
	if result_boss:
		chest_height = maxf(chest_height, 520.0)
	var panel_width: float = minf((560 if landscape else 480) / s, maxf(0, size.x - 32 / s))
	var upgrade_row: bool = _room is RewardRoom and _room.offers_upgrades() and panel_width * s - 24.0 < 420.0
	var empty_height: float = 520.0 if result_boss else 356.0 if upgrade_row else 300.0
	panel.size = Vector2(panel_width,
		minf((chest_height if _has_chest else empty_height) / s, maxf(0, size.y - 32 / s)))
	panel.position = (size - panel.size) * 0.5
	panel.pivot_offset = panel.size * 0.5
	if is_instance_valid(_room):
		_room.position = Vector2.ONE * (12 / s)
		_room.size = panel.size - Vector2.ONE * (24 / s)


func snapshot() -> Dictionary:
	var rect: Rect2 = panel.get_global_rect()
	return {"visible": is_visible_in_tree(), "title": _title,
		"panel_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"reduced_motion": _reduced_motion}

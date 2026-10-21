extends Control
## Persistent stage progress and a brief, input-transparent stage arrival.

const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const DURATION: float = 1.8
var reduced_motion: bool = false
var _state: Dictionary = {}
var _label: Label
var _title: Label
var _detail: Label
var _card := Control.new()
var _badge := Rect2()
var _scale: float = 1.0
var _elapsed: float = DURATION


func _init() -> void:
	name = "JellyStageProgress"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 35
	_label = Style.label("", 15)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	add_child(_card)
	_title = Style.label("", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_title)
	_detail = Style.label("", 14)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_detail)
	hide()


func set_stage(state: Dictionary, celebrate: bool = false) -> void:
	_state = state.duplicate(true)
	visible = int(state.get("number", 0)) > 0
	_update_label()
	set("accessibility_name", _label.text)
	if celebrate:
		_elapsed = 0.0
		_title.text = "All words mastered!" if state.get("complete", false) else "Stage %d" % state.number
		_detail.text = "Beautiful work!" if state.get("complete", false) else "%d new words to master" % state.total
	_refresh_motion()
	queue_redraw()


func reset() -> void:
	_state.clear()
	_elapsed = DURATION
	hide()
	_card.hide()


func dismiss() -> void:
	_elapsed = DURATION
	_refresh_motion()


func advance(delta: float) -> void:
	if _elapsed >= DURATION or delta <= 0.0:
		return
	_elapsed = minf(DURATION, _elapsed + delta)
	_refresh_motion()


func configure_layout(badge: Rect2, board: Rect2, ui_scale: float) -> void:
	_scale = maxf(0.1, ui_scale)
	_badge = badge
	_update_label()
	_label.add_theme_font_size_override("font_size", ceili(14.0 / _scale))
	_label.position = badge.position
	_label.size = badge.size
	_card.size = Vector2(minf(board.size.x - 16.0 / _scale, 320.0 / _scale), 104.0 / _scale)
	_card.position = board.get_center() - _card.size * 0.5
	_card.pivot_offset = _card.size * 0.5
	_title.position = Vector2(8, 14) / _scale
	_title.size = Vector2(_card.size.x - 16.0 / _scale, 42.0 / _scale)
	_title.add_theme_font_size_override("font_size", ceili((minf(24.0, _card.size.x * _scale / 10.0) if _state.get("complete", false) else 30.0) / _scale))
	_detail.position = Vector2(8, 60) / _scale
	_detail.size = Vector2(_card.size.x - 16.0 / _scale, 28.0 / _scale)
	_detail.add_theme_font_size_override("font_size", ceili(14.0 / _scale))
	queue_redraw()
	_card.queue_redraw()


func snapshot() -> Dictionary:
	var state: Dictionary = _state.duplicate(true)
	state["visible"] = is_visible_in_tree()
	state["label"] = _label.text
	state["celebrating"] = visible and _elapsed < DURATION
	state["elapsed"] = _elapsed
	state["rect"] = [_badge.position.x, _badge.position.y, _badge.size.x, _badge.size.y]
	return state


func _update_label() -> void:
	if _state.is_empty():
		return
	var separator: String = "\n" if _badge.size.y * _scale >= 40.0 else "  ·  "
	_label.text = "Stage %d%s%d / %d mastered" % [_state.number, separator, _state.mastered, _state.total]


func _refresh_motion() -> void:
	_card.visible = _elapsed < DURATION and visible
	var enter: float = clampf(_elapsed / 0.25, 0.0, 1.0)
	var leave: float = clampf((DURATION - _elapsed) / 0.32, 0.0, 1.0)
	_card.modulate.a = minf(enter, leave)
	_card.scale = Vector2.ONE if reduced_motion else Vector2.ONE * (1.0 + sin(enter * PI) * 0.08 - (1.0 - enter) * 0.14)
	_card.queue_redraw()


func _draw() -> void:
	if _state.is_empty():
		return
	draw_style_box(Style.box(Color("eef9ed"), Color("b8d6bf"), 12, 1), _badge)
	var progress: float = float(_state.get("mastered", 0)) / maxf(1.0, float(_state.get("total", 10)))
	var track := Rect2(_badge.position + Vector2(12.0 / _scale, _badge.size.y - 3.0 / _scale), Vector2((_badge.size.x - 24.0 / _scale) * progress, 2.0 / _scale))
	if track.size.x > 0.0:
		draw_rect(track, Style.GOOD)


func _draw_card() -> void:
	if not _card.visible:
		return
	var bounds := Rect2(Vector2.ZERO, _card.size)
	draw_card_light(bounds)
	_card.draw_style_box(Style.box(Color("fffdf1"), Color("9bcbad"), 22, 2), bounds)
	for index in range(6):
		var angle: float = TAU * float(index) / 6.0
		var travel: float = 1.0 if reduced_motion else smoothstep(0.0, 0.7, _elapsed)
		var offset := Vector2(cos(angle) * (_card.size.x * 0.48 + 12.0 / _scale * travel), sin(angle) * (52.0 + 22.0 * travel) / _scale)
		var edge: float = (16.0 + 6.0 * sin(float(index))) / _scale
		_card.draw_texture_rect(SPARKLE, Rect2(bounds.get_center() + offset - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color("f4c768"))


func draw_card_light(bounds: Rect2) -> void:
	_card.draw_texture_rect(GLOW, bounds.grow(26.0 / _scale), false, Color(0.9, 0.86, 0.4, 0.45))

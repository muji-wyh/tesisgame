extends Control
## Reuse Pip's shipped costume atlas and dance for one completed adventure.

signal finished

const Mascot = preload("res://scripts/duck_mascot.gd")
const Style = preload("res://scripts/ui_style.gd")
const DURATION: float = 3.2

var pip: CelebrationPip
var headline: Label
var note: Label
var elapsed: float = 0.0
var active: bool = false
var settled: bool = false
var paused: bool = false
var reduced_motion: bool = false
var companion_mode: bool = false
var _started: bool = false
var _finished_emitted: bool = false
var _ui_scale: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	resized.connect(layout)


func _ready() -> void:
	pip = CelebrationPip.new()
	add_child(pip)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.focus_mode = Control.FOCUS_NONE
	pip.tooltip_text = ""
	pip.accessibility_name = "Pip celebrating your adventure"
	headline = _label("You did it!", Color("#fff5db"))
	note = _label("Pip is cheering for you!", Color("#fff5db"))
	visibility_changed.connect(_visibility_changed)
	layout()
	set_process(false)


func _label(text: String, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.clip_text = true
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color("#243345"))
	label.add_theme_color_override("font_shadow_color", Color("#102237b3"))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label


func begin(theme_id: String = "spring") -> bool:
	pip.set_outfit_theme(theme_id)
	show()
	if _started:
		_apply_pose()
		return false
	_started = true
	_finished_emitted = false
	elapsed = 0.0
	active = true
	settled = false
	paused = false
	_apply_pose()
	_update_processing()
	return true


func pause() -> void:
	if not _started or settled:
		return
	paused = true
	_update_processing()


func resume() -> void:
	if not _started or settled:
		return
	paused = false
	_apply_pose()
	_update_processing()


func settle() -> void:
	# A restored chest gets a quiet happy companion, never a replayed dance.
	_started = true
	active = false
	settled = true
	paused = false
	elapsed = DURATION
	show()
	_apply_pose()
	_update_processing()


func reset() -> void:
	_started = false
	_finished_emitted = false
	elapsed = 0.0
	active = false
	settled = false
	paused = false
	if pip != null:
		pip.settle()
		_apply_pose()
	hide()
	_update_processing()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_apply_pose()
	_update_processing()


func set_ui_scale(value: float) -> void:
	if not is_finite(value) or value <= 0.0:
		return
	_ui_scale = value
	layout()


func set_companion_mode(value: bool) -> void:
	companion_mode = value
	layout()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		pause()
	_update_processing()


func _update_processing() -> void:
	set_process(is_visible_in_tree() and active and not paused)
	if pip != null:
		pip.set_process(false)


func _apply_pose() -> void:
	if pip == null:
		return
	pip.present_dance(active and not reduced_motion, elapsed / DURATION)
	pip.accessibility_description = "Pip dances to celebrate. You did it!" if active and not reduced_motion else "Pip smiles and waves. You did it!"


func _process(delta: float) -> void:
	if not active or paused or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	elapsed = minf(DURATION, elapsed + delta)
	if elapsed >= DURATION:
		settle()
		if not _finished_emitted:
			_finished_emitted = true
			finished.emit()
	else:
		_apply_pose()


func layout() -> void:
	if pip == null or headline == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale: float = _ui_scale if _ui_scale > 0.0 else Style.ui_scale(self)
	var area: Vector2 = size * scale
	var padding: float = minf(16.0, minf(area.x, area.y) * 0.07)
	var inside := Rect2(Vector2.ONE * padding, (area - Vector2.ONE * padding * 2.0).max(Vector2.ONE))
	headline.visible = not companion_mode
	note.visible = not companion_mode
	var art: Rect2 = inside
	if not companion_mode:
		var horizontal: bool = area.y < 200.0 or area.x >= area.y * 1.6
		var text: Rect2
		if horizontal:
			var art_width: float = minf(inside.size.x * 0.44, minf(360.0, inside.size.y))
			var text_width: float = minf(390.0, inside.size.x - art_width - padding)
			var left: float = (area.x - art_width - padding - text_width) * 0.5
			art = Rect2(Vector2(left, inside.position.y), Vector2(art_width, inside.size.y))
			text = Rect2(Vector2(art.end.x + padding, area.y * 0.5 - 42.0), Vector2(text_width, 84.0))
		else:
			var text_height: float = minf(84.0, inside.size.y * 0.29)
			text = Rect2(inside.position, Vector2(inside.size.x, text_height))
			art = Rect2(Vector2(inside.position.x, text.end.y + padding),
				Vector2(inside.size.x, maxf(1.0, inside.end.y - text.end.y - padding)))
		var heading_height: float = minf(48.0, text.size.y * 0.58)
		headline.position = text.position / scale
		headline.size = Vector2(text.size.x, heading_height) / scale
		note.position = Vector2(text.position.x, text.position.y + heading_height) / scale
		note.size = Vector2(text.size.x, text.size.y - heading_height) / scale
		headline.add_theme_font_size_override("font_size", maxi(1, roundi((26.0 if text.size.x < 240.0 else 32.0) / scale)))
		note.add_theme_font_size_override("font_size", maxi(1, roundi((13.0 if text.size.x < 240.0 else 16.0) / scale)))
		for label: Label in [headline, note]:
			label.add_theme_constant_override("outline_size", maxi(1, roundi(3.0 / scale)))
	# Leave space around raised wings and hats instead of clipping the dance.
	var edge: float = maxf(1.0, minf(360.0, minf(art.size.x, art.size.y)) * 0.86)
	pip.custom_minimum_size = Vector2.ZERO
	pip.size = Vector2.ONE * edge / scale
	pip.position = (art.get_center() - Vector2.ONE * edge * 0.5) / scale


func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "active": active, "settled": settled,
		"paused": paused, "elapsed": elapsed, "duration": DURATION,
		"reduced_motion": reduced_motion, "companion_mode": companion_mode,
		"pip": {"emotion": "happy", "pose": "dance" if pip != null and pip.dancing else "wave",
			"dancing": pip != null and pip.dancing, "progress": elapsed / DURATION,
			"theme": pip.theme_id if pip != null else "spring"}}


class CelebrationPip extends Mascot:
	var dancing: bool = false
	var dance_progress: float = 0.0

	func present_dance(enabled: bool, progress: float) -> void:
		dancing = enabled
		dance_progress = clampf(progress, 0.0, 1.0)
		set_process(false)
		queue_redraw()

	func _visibility_changed() -> void:
		super._visibility_changed()
		set_process(false)

	func _draw() -> void:
		var edge: float = minf(size.x, size.y)
		var origin: Vector2 = (size - Vector2.ONE * edge) * 0.5
		if dancing:
			_draw_dance(origin, edge, "dance-wave", dance_progress)
			return
		# The happy waving frame is original Pip art, shared with the loader.
		var sheet: Texture2D = _outfit_sheet if _outfit_sheet != null else SHEET
		var source_edge: float = sheet.get_height()
		draw_texture_rect_region(sheet, Rect2(origin, Vector2.ONE * edge),
			Rect2(Vector2(3.0 * source_edge, 0), Vector2.ONE * source_edge))

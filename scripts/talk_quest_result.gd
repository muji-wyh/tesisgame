extends Control
## Shared pause and rematch presentation around the current encounter.

signal loss_reaction_requested

const Style = preload("res://scripts/ui_style.gd")
const QuestButton = preload("res://scripts/talk_quest_button.gd")
const Pip = preload("res://scripts/duck_mascot.gd")
const LOSS_SAD_SECONDS: float = 2.4
const GOLD := Color("#edbd79")
const LIGHT := Color("#fff2dc")
const MUTED := Color("#b7ccc3")

var hits: int = 0
var max_hp: int = 1
var remaining_hp: int = 1
var pause_mode: bool = false
var context_phase: String = "lost"
var reduced_motion: bool = false
var reveal: float = 1.0
var card := Rect2()
var hero_rect := Rect2()
var retry: Button
var map_button: Button
var surface: Panel
var pip: Pip
var loss_emotion: String = ""
var _loss_started: bool = false
var _loss_age: float = 0.0
var _eyebrow: Label
var _title: Label
var _note: Label
var _hits_value: Label
var _hits_label: Label
var _hp_value: Label
var _hp_label: Label
var _hero_name: Label
var _sigil: Sigil
var _track: Control
var _clock: float = 0.0
var _compact: bool = false
var _scale: float = 1.0
var _accent := GOLD


func _init() -> void:
	# Chest glows use layers through 11; intermissions stay above their tails
	# and below the application's collection and leaderboard overlays.
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(layout)


func _ready() -> void:
	surface = Panel.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	_sigil = Sigil.new()
	_sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(_sigil)
	_eyebrow = _label(surface, GOLD)
	_title = _label(surface, LIGHT)
	_note = _label(surface, MUTED)
	_note.text = "Every word makes you stronger."
	_hits_value = _label(surface, LIGHT)
	_hits_label = _label(surface, MUTED)
	_hits_label.text = "WORD HITS"
	_hp_value = _label(surface, GOLD)
	_hp_label = _label(surface, MUTED)
	_hp_label.text = "HP LEFT"
	_track = Control.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)
	surface.add_child(_track)
	retry = QuestButton.new()
	retry.text = "Try again"
	retry.accessibility_name = "Try this adventure again"
	surface.add_child(retry)
	map_button = QuestButton.new()
	map_button.text = "Map"
	map_button.accessibility_name = "Return to the adventure map"
	surface.add_child(map_button)
	_hero_name = _label(self, LIGHT)
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pip = Pip.new()
	add_child(pip)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.focus_mode = Control.FOCUS_NONE
	pip.tooltip_text = ""
	pip.accessibility_name = "Pip, your adventure friend"
	pip.hide()
	visibility_changed.connect(_visibility_changed)
	layout()
	set_process(false)


func _label(parent: Node, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	parent.add_child(label)
	return label


func present(number: int, creature: String, earned: int, health: int, left: int, blocked: bool) -> void:
	pause_mode = false
	context_phase = "lost"
	_set_statistics(number, creature, earned, health, left)
	_title.text = "So close!" if hits > 0 and remaining_hp <= 2 else "One more try?"
	_update_loss_copy()
	pip.show()
	retry.text = "Try again"
	retry.accessibility_name = "Try this adventure again"
	_finish_presentation(blocked)
	if not _loss_started and is_visible_in_tree():
		_loss_started = true
		_loss_age = 0.0
		loss_emotion = "sad"
		pip.react_gameplay(false, LOSS_SAD_SECONDS)
		_update_loss_copy()
		loss_reaction_requested.emit()
	_update_processing()


func reset_loss() -> void:
	hide()
	_loss_started = false
	_loss_age = 0.0
	loss_emotion = ""
	pip.settle()


func _update_loss_copy() -> void:
	var encouraging: bool = loss_emotion == "encouraging"
	_note.text = "Let's try again together!" if encouraging else "Oh no... that was a tough one."
	_hero_name.text = "Let's try again!" if encouraging else "Oh no..."
	pip.accessibility_description = "Pip smiles and offers a high five. Let's try again together!" if encouraging else "Pip lowers his head and wings with a tearful frown."


func _encourage() -> void:
	loss_emotion = "encouraging"
	pip.clear_gameplay_reaction()
	pip.perform_trick("high-five")
	_update_loss_copy()
	_update_processing()


func _visibility_changed() -> void:
	if not is_visible_in_tree() and _loss_started:
		# Returning from a pause must not replay disappointment or old calls.
		loss_emotion = "encouraging"
		_loss_age = LOSS_SAD_SECONDS
		pip.settle()
	elif is_visible_in_tree() and loss_emotion == "encouraging" and not pause_mode:
		_encourage()
	_update_processing()


func _update_processing() -> void:
	set_process(is_visible_in_tree() and (not reduced_motion or loss_emotion == "sad"))


func present_pause(number: int, subject: String, earned: int, health: int, left: int, phase: String, blocked: bool) -> void:
	pause_mode = true
	pip.hide()
	context_phase = phase
	_set_statistics(number, subject, earned, health, left)
	_title.text = "Paused"
	_note.text = "Pick up right where you left off."
	retry.text = "Continue"
	retry.accessibility_name = "Continue the paused adventure"
	if context_phase in ["victory", "chest", "complete"]:
		_hits_value.text = "%02d" % number
		_hits_label.text = "ADVENTURE"
		_hp_value.text = "Collected" if context_phase == "complete" else "Ready"
		_hp_label.text = "TREASURE"
		_note.text = "Your treasure is collected." if context_phase == "complete" else "Your treasure is waiting."
	elif context_phase == "lost":
		_note.text = "Ready for another try?"
	if blocked:
		_note.text = "Save your progress to continue."
	_finish_presentation(blocked)


func _set_statistics(number: int, subject: String, earned: int, health: int, left: int) -> void:
	hits = earned
	max_hp = maxi(1, health)
	remaining_hp = left
	_eyebrow.text = "ADVENTURE %02d" % number
	_hits_value.text = "%d / %d" % [hits, max_hp]
	_hp_value.text = str(remaining_hp)
	_hits_label.text = "WORD HITS"
	_hp_label.text = "HP LEFT"
	_hero_name.text = subject


func _finish_presentation(blocked: bool) -> void:
	_accent = Color("#a7e4cf") if pause_mode else GOLD
	_eyebrow.add_theme_color_override("font_color", _accent)
	_hp_value.add_theme_color_override("font_color", _accent)
	_sigil.pause_mode = pause_mode
	_sigil.queue_redraw()
	retry.disabled = blocked
	map_button.disabled = blocked
	if not visible:
		reveal = 1.0 if reduced_motion else 0.0
		_clock = 0.0
		show()
	_update_processing()
	layout()
	_track.queue_redraw()
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		reveal = 1.0
	if retry != null:
		retry.set_reduced_motion(value)
		map_button.set_reduced_motion(value)
		pip.set_reduced_motion(value)
		_apply_reveal()
	_update_processing()
	queue_redraw()


func _place(label: Label, rect: Rect2, font_size: float) -> void:
	label.add_theme_font_size_override("font_size", roundi(font_size / _scale))
	label.position = rect.position / _scale
	label.size = rect.size / _scale


func layout() -> void:
	if surface == null or size.x <= 0 or size.y <= 0:
		return
	_scale = Style.ui_scale(self)
	var px: Vector2 = size * _scale
	_compact = px.y < 300
	var split: bool = px.x >= 520
	var padding: float = 12 if _compact else 16 if px.x < 360 else 24
	var card_width: float = minf(420, px.x * 0.55) if split else minf(420, px.x - 16)
	var card_height: float = minf(300, px.y - 16) if split else minf(284, px.y - 20)
	if _compact:
		card_height = px.y - 12
	var minimal: bool = _compact and card_height < 200
	var origin := Vector2(px.x - card_width - 8, (px.y - card_height) * 0.5) if split else Vector2((px.x - card_width) * 0.5, px.y - card_height - 8)
	card = Rect2(origin / _scale, Vector2(card_width, card_height) / _scale)
	hero_rect = Rect2(Vector2(4, 4) / _scale, Vector2(origin.x - 8, px.y - 8) / _scale) if split else Rect2(Vector2(4, 0) / _scale, Vector2(px.x - 8, maxf(40, origin.y + 12)) / _scale)
	surface.size = card.size
	var box := Style.box(Color("#15322cf5"), Color(_accent, 0.55), ceili(22 / _scale), maxi(1, roundi(1 / _scale)))
	box.shadow_color = Color("#081b1780")
	box.shadow_size = ceili(16 / _scale)
	box.shadow_offset = Vector2(0, 6 / _scale)
	surface.add_theme_stylebox_override("panel", box)
	var inner: float = card_width - padding * 2
	var header_x: float = padding + (0 if _compact else 56)
	_sigil.visible = not _compact
	_sigil.position = Vector2(padding, padding + 2) / _scale
	_sigil.size = Vector2(44, 50) / _scale
	_sigil.queue_redraw()
	_place(_eyebrow, Rect2(header_x, padding - 2, card_width - header_x - padding, 18), 10)
	_place(_title, Rect2(header_x, padding + 15, card_width - header_x - padding, 36), 25 if card_width < 340 else 30)
	_eyebrow.visible = not _compact or card_height >= 170
	_note.visible = not _compact
	_place(_note, Rect2(padding, padding + 64, inner, 22), 13)
	var button_h: float = 44 if _compact else 48
	var button_y: float = card_height - padding - button_h
	var track_y: float = button_y - (15 if _compact else 24)
	var value_y: float = track_y - (52 if _compact else 65)
	if _compact:
		# Short landscape viewports retain readable stats and full touch targets.
		_place(_title, Rect2(padding, 26 if _eyebrow.visible else 8, inner, 28), 24)
		value_y = button_y - 66
		_place(_hits_value, Rect2(padding, value_y, inner * 0.56, 27), 23)
		_place(_hits_label, Rect2(padding, value_y + 26, inner * 0.56, 14), 9)
		_place(_hp_value, Rect2(padding + inner * 0.54, value_y, inner * 0.46, 27), 16 if pause_mode and context_phase in ["victory", "chest", "complete"] else 23)
		_place(_hp_label, Rect2(padding + inner * 0.54, value_y + 26, inner * 0.46, 14), 9)
	else:
		_place(_hits_value, Rect2(padding, value_y, inner * 0.56, 38), 30)
		_place(_hits_label, Rect2(padding, value_y + 37, inner * 0.56, 18), 10)
		_place(_hp_value, Rect2(padding + inner * 0.56, value_y, inner * 0.44, 38), 21 if pause_mode and context_phase in ["victory", "chest", "complete"] else 30)
		_place(_hp_label, Rect2(padding + inner * 0.56, value_y + 37, inner * 0.44, 18), 10)
	for statistic in [_hits_value, _hits_label, _hp_value, _hp_label, _track]:
		statistic.visible = not minimal
	if minimal:
		_eyebrow.hide()
		_place(_title, Rect2(padding, 8, inner, 28), 24)
		_note.show()
		_place(_note, Rect2(padding, 38, inner, 22), 12)
	_track.position = Vector2(padding, track_y) / _scale
	_track.size = Vector2(inner, 5) / _scale
	_track.queue_redraw()
	retry.configure(_accent if pause_mode else Color("#e6b16c"), true, reduced_motion)
	map_button.configure(Color("#739b89"), false, reduced_motion)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		retry.add_theme_color_override(state, Color("#263e38"))
		map_button.add_theme_color_override(state, LIGHT)
	for key in ["normal", "hover", "pressed"]:
		var quiet: StyleBoxFlat = map_button.get_theme_stylebox(key).duplicate()
		quiet.bg_color = Color("#34574a") if key == "hover" else Color("#203f35")
		quiet.border_color = Color("#527461")
		map_button.add_theme_stylebox_override(key, quiet)
	for button in [retry, map_button]:
		button.custom_minimum_size = Vector2(0, button_h / _scale)
		button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, LIGHT, ceili(12 / _scale), ceili(2 / _scale)))
	retry.position = Vector2(padding, button_y) / _scale
	retry.size = Vector2(inner * 0.64 - 4, button_h) / _scale
	map_button.position = Vector2(padding + inner * 0.64 + 4, button_y) / _scale
	map_button.size = Vector2(inner * 0.36 - 4, button_h) / _scale
	_hero_name.position = Vector2(hero_rect.position.x, hero_rect.end.y - 31 / _scale)
	_hero_name.size = Vector2(hero_rect.size.x, 24 / _scale)
	_hero_name.add_theme_font_size_override("font_size", ceili(12 / _scale))
	_hero_name.visible = hero_rect.size.y * _scale >= 85
	# The high-five's hat and raised wing extend beyond the resting art bounds.
	var pip_space := Vector2(hero_rect.size.x - 20 / _scale, hero_rect.size.y - 66 / _scale)
	var pip_edge: float = maxf(40, minf(360 / _scale, minf(pip_space.x, pip_space.y)))
	pip.custom_minimum_size = Vector2.ZERO
	pip.size = Vector2.ONE * pip_edge
	pip.position = hero_rect.position + Vector2((hero_rect.size.x - pip_edge) * 0.5, 16 / _scale + maxf(0, (pip_space.y - pip_edge) * 0.5))
	_apply_reveal()
	queue_redraw()


func _apply_reveal() -> void:
	surface.position = card.position + Vector2(0, (1.0 - reveal) * 12 / _scale)
	surface.modulate.a = reveal
	_hero_name.modulate.a = reveal
	pip.modulate.a = reveal


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if loss_emotion == "sad":
		_loss_age += delta
		if _loss_age >= LOSS_SAD_SECONDS:
			_encourage()
	if reduced_motion:
		return
	_clock += minf(delta, 0.1)
	if reveal < 1.0:
		reveal = minf(1.0, reveal + delta / 0.42)
		_apply_reveal()
		_track.queue_redraw()
	queue_redraw()


func _draw_track() -> void:
	if pause_mode and context_phase in ["victory", "chest", "complete"]:
		_track.draw_line(Vector2.ZERO, Vector2(_track.size.x, 0), Color(_accent, 0.25), 1 / _scale)
		return
	var gap: float = 3 / _scale
	var width: float = (_track.size.x - (max_hp - 1) * gap) / max_hp
	for index in range(max_hp):
		var rect := Rect2(index * (width + gap), 0, width, _track.size.y)
		var earned: bool = index < hits
		var color := _accent if earned else Color("#395748")
		if earned:
			color.a = 0.4 + 0.6 * reveal
		_track.draw_style_box(Style.box(color, Color.TRANSPARENT, ceili(2 / _scale), 0), rect)


func _draw() -> void:
	if size.x <= 0:
		return
	# The curtain frames Pip on loss and the current encounter while paused.
	draw_style_box(Style.box(Color("#0b241da8"), Color.TRANSPARENT, ceili(20 / _scale), 0), Rect2(Vector2.ZERO, size))
	var center: Vector2 = hero_rect.get_center()
	var radius: float = minf(hero_rect.size.x, hero_rect.size.y) * 0.39
	if radius > 12:
		var glow := Color(_accent, 0.06)
		draw_arc(center, radius, 0.22, 2.85, 48, glow, 1 / _scale, true)
		draw_arc(center, radius + 7 / _scale, 3.30, 5.98, 48, glow, 1 / _scale, true)
	for index in range(12):
		var x: float = fmod(float(index) * 0.618, 1.0) * size.x
		var y: float = fmod(float(index) * 0.313 + (0.0 if reduced_motion else _clock * 0.016), 1.0) * size.y
		if card.grow(12 / _scale).has_point(Vector2(x, y)):
			continue
		var opacity: float = 0.12 + 0.12 * sin(float(index) * 2.4 + (0.0 if reduced_motion else _clock))
		draw_circle(Vector2(x, y), (1.0 + index % 3 * 0.45) / _scale, Color(_accent, opacity))


class Sigil extends Control:
	var pause_mode: bool = false

	func _draw() -> void:
		var s: float = minf(size.x / 44, size.y / 50)
		draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5), 0, Vector2.ONE * s)
		if pause_mode:
			for ring in range(5, 0, -1):
				draw_circle(Vector2.ZERO, 14 + ring * 2, Color("#a7e4cf05"))
			draw_circle(Vector2.ZERO, 20, Color("#a7e4cf14"))
			draw_arc(Vector2.ZERO, 22, -0.95, 0.80, 22, Color("#a7e4cf66"), 1, true)
			draw_arc(Vector2.ZERO, 22, 2.18, 3.9, 22, Color("#a7e4cf66"), 1, true)
			for x in [-8, 3]:
				draw_style_box(Style.box(Color("#e2f6ff"), Color.TRANSPARENT, 2, 0), Rect2(x, -10, 5, 20))
			return
		for ring in range(5, 0, -1):
			draw_circle(Vector2.ZERO, 14 + ring * 2, Color("#edbd7905"))
		draw_arc(Vector2.ZERO, 22, -0.95, 0.80, 22, Color("#edbd794d"), 1, true)
		draw_arc(Vector2.ZERO, 22, 2.18, 3.9, 22, Color("#edbd794d"), 1, true)
		var shield := PackedVector2Array([Vector2(0, -16), Vector2(14, -10), Vector2(12, 7), Vector2(0, 18), Vector2(-12, 7), Vector2(-14, -10)])
		draw_colored_polygon(shield, Color("#edbd791a"))
		shield.append(shield[0])
		draw_polyline(shield, Color("#edbd79"), 1.5, true)
		var spark := PackedVector2Array([Vector2(0, -9), Vector2(2.4, -2.4), Vector2(8, 0), Vector2(2.4, 2.4), Vector2(0, 10), Vector2(-2.4, 2.4), Vector2(-8, 0), Vector2(-2.4, -2.4)])
		draw_colored_polygon(spark, Color("#fff2dc"))

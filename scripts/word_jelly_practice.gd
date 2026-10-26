extends Panel
## The stage's durable learning evidence, outside the playable well.

signal word_progressed(word_id: String, complete: bool)

const Style = preload("res://scripts/ui_style.gd")
const Scroll = preload("res://scripts/review_scroll.gd")
const WordArt = preload("res://scripts/word_art.gd")
const MEDAL = preload("res://assets/images/ui/mastery-medal.webp")
const STAR = preload("res://assets/chests/milestone/sparkle.png")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const CHECK = preload("res://assets/images/ui/jelly-goals/completed.svg")
const RATING_STAR = preload("res://assets/images/ui/jelly-goals/star.webp")
const GAIN_SECONDS: float = 0.55
const COMPLETE_SECONDS: float = 0.60
const MARKER_HOLD: float = 0.7
var reduced_motion: bool = false
var _title: Label
var _subtitle: Label
var _medal := TextureRect.new()
var _scroll := Scroll.new()
var _content := Control.new()
var _rows: Array[Dictionary] = []
var _state: Dictionary = {}
var _compact: bool = false
var _scale: float = 1.0


func _init() -> void:
	name = "StagePracticeWords"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 36
	_title = Style.label("", 16)
	_title.add_theme_font_override("font", Style.HEADING_FONT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Style.label("", 12)
	_subtitle.add_theme_color_override("font_color", Style.MUTED)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)
	_medal.texture = MEDAL
	_medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_medal)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_scroll.add_child(_content)
	hide()


func set_stage(state: Dictionary) -> void:
	if _state == state:
		return
	var previous: Dictionary = {}
	if not _state.is_empty() and int(_state.get("number", 0)) == int(state.get("number", 0)):
		for item: Dictionary in _state.get("practice", []):
			previous[str(item.id)] = item
	_state = state.duplicate(true)
	var words: Array = state.get("practice", [])
	while _rows.size() > words.size():
		_rows.pop_back().surface.free()
	while _rows.size() < words.size():
		var surface := Panel.new()
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.clip_contents = true
		_content.add_child(surface)
		var background := ProgressBar.new()
		background.show_percentage = false
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		background.add_theme_stylebox_override("fill",
			Style.box(Color("#c1e1c5"), Color.TRANSPARENT, 10, 0))
		surface.add_child(background)
		var label: Label = Style.label("", 16)
		label.add_theme_font_override("font", Style.HEADING_FONT)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(label)
		var fraction: Label = Style.label("", 14)
		fraction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fraction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fraction.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(fraction)
		var picture := TextureRect.new()
		picture.name = "PracticeWordPicture"
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(picture)
		var steps: Array[TextureRect] = []
		for index in range(3):
			var star := TextureRect.new()
			star.texture = STAR
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			surface.add_child(star)
			steps.append(star)
		var gain: Label = Style.label("", 13)
		gain.add_theme_font_override("font", Style.HEADING_FONT)
		gain.add_theme_color_override("font_color", Color("#b57f1c"))
		gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(gain)
		var glow := TextureRect.new()
		glow.texture = GLOW
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(glow)
		var sparkles: Array[TextureRect] = []
		for index in range(4):
			var sparkle := TextureRect.new()
			sparkle.texture = STAR
			sparkle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			surface.add_child(sparkle)
			sparkles.append(sparkle)
		var badge := Panel.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(badge)
		var check_icon := TextureRect.new()
		check_icon.texture = CHECK
		check_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		check_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(check_icon)
		var done: Label = Style.label("Done", 10)
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		done.add_theme_color_override("font_color", Color.WHITE)
		badge.add_child(done)
		_rows.append({"surface": surface, "background_progress": background, "label": label,
			"fraction": fraction, "picture": picture, "steps": steps, "gain_label": gain,
			"success_glow": glow, "success_sparkles": sparkles, "complete_badge": badge,
			"complete_icon": check_icon, "done_label": done, "word_id": "",
			"gain_elapsed": GAIN_SECONDS, "complete_elapsed": COMPLETE_SECONDS + MARKER_HOLD,
			"gain_amount": 0, "mastered": false})
	for index in range(words.size()):
		var item: Dictionary = words[index]
		var row: Dictionary = _rows[index]
		var old: Dictionary = previous.get(str(item.id), {})
		if str(row.word_id) != str(item.id) or old.is_empty():
			row.gain_elapsed = GAIN_SECONDS
			row.complete_elapsed = COMPLETE_SECONDS + MARKER_HOLD
		row.word_id = str(item.id)
		row.mastered = bool(item.mastered)
		if not old.is_empty() and int(item.current) > int(old.current) and is_visible_in_tree():
			row.gain_amount = int(item.current) - int(old.current)
			row.gain_elapsed = GAIN_SECONDS if reduced_motion else 0.0
			var completed: bool = bool(item.mastered) and not bool(old.mastered)
			if completed:
				row.complete_elapsed = COMPLETE_SECONDS + MARKER_HOLD if reduced_motion else 0.0
			word_progressed.emit(str(item.id), completed)
		elif not old.is_empty() and int(item.current) < int(old.current):
			row.gain_elapsed = GAIN_SECONDS
			row.complete_elapsed = COMPLETE_SECONDS + MARKER_HOLD
		row.label.text = str(item.text)
		row.fraction.text = "%d/%d" % [int(item.current), int(item.required)]
		row.background_progress.max_value = int(item.required)
		row.background_progress.value = int(item.current)
		row.picture.texture = WordArt.texture(str(item.get("image", "")), row.picture)
		row.picture.visible = row.picture.texture != null
		for index_step in range(3):
			row.steps[index_step].modulate = Color("#e3aa35") if index_step < int(item.current) else Color("#b9c9bf")
		row.label.add_theme_color_override("font_color", Style.GOOD if item.mastered else Style.INK)
		var card: StyleBoxFlat = Style.box(Color("#f5fbef") if item.mastered else Color("#fffdf7"),
			Color("#c5d9b0") if item.mastered else Color("#dce7dd"), ceili(14.0 / _scale), 1)
		card.shadow_color = Color(0.15, 0.28, 0.20, 0.08)
		card.shadow_size = ceili(3.0 / _scale)
		card.shadow_offset = Vector2(0, 2.0 / _scale)
		row.surface.add_theme_stylebox_override("panel", card)
		row.fraction.add_theme_stylebox_override("normal",
			Style.box(Color("#deefd7") if item.mastered else Color("#edf3ee"), Color.TRANSPARENT, ceili(8.0 / _scale), 0))
		row.surface.set("accessibility_name", "%s. %d of %d correct. %s" % [
			item.text, int(item.current), int(item.required), "Mastered." if item.mastered else "Practising."])
	visible = not words.is_empty()
	_layout()


func advance(delta: float) -> void:
	if not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	for row: Dictionary in _rows:
		if float(row.gain_elapsed) >= GAIN_SECONDS and float(row.complete_elapsed) >= COMPLETE_SECONDS + MARKER_HOLD:
			continue
		row.gain_elapsed = minf(GAIN_SECONDS, float(row.gain_elapsed) + delta)
		row.complete_elapsed = minf(COMPLETE_SECONDS + MARKER_HOLD, float(row.complete_elapsed) + delta)
		_pose_feedback(row)


func feedback_active() -> bool:
	return not reduced_motion and _rows.any(func(row: Dictionary) -> bool:
		return float(row.gain_elapsed) < GAIN_SECONDS or float(row.complete_elapsed) < COMPLETE_SECONDS + MARKER_HOLD)


func _pose_feedback(row: Dictionary) -> void:
	var gaining: bool = not reduced_motion and float(row.gain_elapsed) < GAIN_SECONDS
	var completing: bool = not reduced_motion and float(row.complete_elapsed) < COMPLETE_SECONDS
	var p: float = clampf(float(row.gain_elapsed) / GAIN_SECONDS, 0.0, 1.0)
	var complete_p: float = clampf(float(row.complete_elapsed) / COMPLETE_SECONDS, 0.0, 1.0)
	row.fraction.scale = Vector2.ONE * (1.0 + (0.18 * sin(p * PI) if gaining else 0.0))
	row.picture.scale = Vector2.ONE * (1.0 + (0.12 * sin(p * PI) if gaining else 0.0))
	row.gain_label.visible = gaining and not _compact
	row.gain_label.text = "+%d" % int(row.gain_amount)
	row.gain_label.modulate.a = 1.0 - smoothstep(0.45, 1.0, p)
	row.gain_label.position = Vector2(row.surface.size.x - 42.0 / _scale, (8.0 - p * 8.0) / _scale)
	row.label.size.x = maxf(1.0, row.surface.size.x - row.label.position.x
		- (48.0 if gaining and not _compact else 10.0) / _scale)
	row.fraction.visible = not _compact and (not row.mastered or completing)
	row.complete_badge.visible = row.mastered and not completing
	for star: TextureRect in row.steps:
		star.visible = not _compact and not row.mastered and _state.get("kind", "") != "main"
	row.success_glow.visible = completing
	var glow_size := Vector2(52, 44) / _scale
	var center: Vector2 = row.picture.position + row.picture.size * 0.5
	row.success_glow.position = center - glow_size * 0.5
	row.success_glow.size = glow_size
	row.success_glow.modulate = Color(1.0, 0.88, 0.45, (1.0 - complete_p) * 0.54)
	for index in range(row.success_sparkles.size()):
		var sparkle: TextureRect = row.success_sparkles[index]
		sparkle.visible = completing
		sparkle.size = Vector2.ONE * (5.0 + (1.0 - complete_p) * 3.0) / _scale
		var half: Vector2 = sparkle.size * 0.5
		var reach: float = lerpf(5.0, 10.0 if _compact else 23.0, complete_p) / _scale
		var point: Vector2 = center + Vector2.from_angle(float(index) * TAU / 4.0 - PI * 0.5) * reach
		sparkle.position = point.clamp(half, row.surface.size - half) - half
		sparkle.modulate = Color(1.0, 0.77, 0.30, 1.0 - complete_p)
	var card: StyleBoxFlat = row.surface.get_theme_stylebox("panel")
	card.border_color = Color("#edc45f").lerp(Color("#c5d9b0"), complete_p) if completing \
		else Color("#c5d9b0") if row.mastered else Color("#dce7dd")
	row.surface.queue_redraw()


func configure_layout(area: Rect2, ui_scale: float, compact: bool) -> void:
	position = area.position
	size = area.size
	_scale = ui_scale
	_compact = compact
	_layout()


func _layout() -> void:
	if not visible:
		return
	var s: float = _scale
	var padding: float = 6.0 / s
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_title.add_theme_font_size_override("font_size", ceili((12.0 if _compact else 20.0) / s))
	_title.text = "Stage %d" % int(_state.get("number", 1)) if _compact else "Word goals"
	if _state.get("kind") == "challenge":
		_title.text = "Wave %d" % int(_state.get("pressure", {}).get("level", 1)) if _compact else "Word practice"
	var timed: bool = _state.get("kind") == "main"
	if timed and _compact:
		var remaining: int = maxi(0, ceili(float(_state.get("seconds_remaining", 0))))
		_title.text = "%d · %d:%02d" % [int(_state.number), remaining / 60, remaining % 60]
	_subtitle.visible = not _compact
	_subtitle.text = "%d of %d mastered" % [int(_state.get("mastered", 0)), _rows.size()]
	if timed:
		_subtitle.text = "%d of %d goals done" % [int(_state.get("mastered", 0)), _rows.size()]
	_subtitle.add_theme_font_size_override("font_size", ceili(12.0 / s))
	_medal.visible = not _compact
	_medal.position = Vector2(0, 2.0) / s
	_medal.size = Vector2(36, 40) / s
	var stacked: bool = _compact and size.y * s >= 40.0
	var title_height: float = 18.0 / s if stacked else size.y - padding * 2.0
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.position = Vector2(padding if _compact else 46.0 / s, 0.0)
	_title.size = Vector2(size.x - (padding * 2.0 if _compact else 46.0 / s) if stacked or not _compact else 62.0 / s,
		(16.0 / s if timed and _compact else title_height) if _compact else 28.0 / s)
	_subtitle.position = Vector2(46, 28) / s
	_subtitle.size = Vector2(maxf(1.0, size.x - 46.0 / s), 20.0 / s)
	_scroll.position = Vector2(padding if stacked or not _compact else (88.0 if timed else 70.0) / s,
		18.0 / s if stacked else 58.0 / s if not _compact else 0.0)
	_scroll.horizontal = _compact
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if _compact else ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if _compact else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if _compact:
		_content.custom_minimum_size.y = 0.0
	else:
		_content.custom_minimum_size.x = 0.0
	_scroll.size = (size - _scroll.position - Vector2(padding, 0.0 if _compact else padding)).max(Vector2.ONE)
	var cursor: float = 0.0
	for row: Dictionary in _rows:
		var card: StyleBoxFlat = row.surface.get_theme_stylebox("panel")
		card.set_corner_radius_all(ceili((10.0 if _compact else 14.0) / s))
		card.shadow_size = ceili(3.0 / s)
		card.shadow_offset = Vector2(0, 2.0 / s)
		var badge: StyleBoxFlat = row.fraction.get_theme_stylebox("normal")
		badge.set_content_margin_all(1.0 / s)
		badge.content_margin_left = 4.0 / s
		badge.content_margin_right = 4.0 / s
		badge.set_corner_radius_all(ceili(8.0 / s))
		var font_size: int = ceili((13.0 if _compact else 18.0) / s)
		row.label.add_theme_font_size_override("font_size", font_size)
		row.fraction.add_theme_font_size_override("font_size", ceili(12.0 / s))
		var width: float = minf(220.0 / s, maxf(82.0 / s,
			Style.HEADING_FONT.get_string_size(row.label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 44.0 / s)) \
			if _compact else _scroll.size.x
		var height: float = _scroll.size.y if _compact else 52.0 / s
		row.surface.position = Vector2(cursor, 0.0) if _compact else Vector2(0.0, cursor)
		row.surface.size = Vector2(width, height)
		row.background_progress.position = Vector2.ONE / s
		row.background_progress.size = (row.surface.size - Vector2.ONE * 2.0 / s).max(Vector2.ONE)
		row.background_progress.get_theme_stylebox("fill").set_corner_radius_all(
			maxi(0, ceili((10.0 if _compact else 14.0) / s) - 1))
		row.fraction.visible = not _compact
		var picture_edge: float = (20.0 if _compact else 38.0) / s
		row.picture.position = Vector2(6.0 / s, (height - picture_edge) * 0.5)
		row.picture.size = Vector2.ONE * picture_edge
		row.picture.pivot_offset = row.picture.size * 0.5
		var left: float = (32.0 if _compact else 58.0) / s if row.picture.visible else 10.0 / s
		row.label.position = Vector2(left, 0.0 if _compact else 4.0 / s)
		row.label.size = Vector2(maxf(1.0, width - left - 10.0 / s),
			height if _compact else 26.0 / s)
		row.fraction.position = Vector2(width - 37.0 / s, (height - 20.0 / s) * 0.5 if _compact else 28.0 / s)
		row.fraction.size = Vector2(30.0, 20.0) / s
		row.fraction.pivot_offset = row.fraction.size * 0.5
		row.gain_label.size = Vector2(34, 18) / s
		row.gain_label.add_theme_font_size_override("font_size", ceili(13.0 / s))
		row.complete_badge.add_theme_stylebox_override("panel",
			Style.box(Style.GOOD, Color.TRANSPARENT, ceili(7.0 / s), 0))
		row.complete_badge.position = row.picture.position + row.picture.size - Vector2.ONE * 12.0 / s if _compact \
			else Vector2(width - 64.0 / s, 28.0 / s)
		row.complete_badge.size = Vector2.ONE * 12.0 / s if _compact else Vector2(58, 20) / s
		row.complete_icon.position = Vector2.ONE / s if _compact else Vector2(3, 3) / s
		row.complete_icon.size = Vector2.ONE * (10.0 if _compact else 14.0) / s
		row.done_label.visible = not _compact
		row.done_label.position = Vector2(18, 0) / s
		row.done_label.size = Vector2(36, 20) / s
		row.done_label.add_theme_font_size_override("font_size", ceili(10.0 / s))
		for index in range(3):
			var star: TextureRect = row.steps[index]
			star.visible = not _compact
			star.position = Vector2(left + index * 17.0 / s, 32.0 / s)
			star.size = Vector2.ONE * 13.0 / s
		_pose_feedback(row)
		cursor += width + 8.0 / s if _compact else height + 8.0 / s
	_content.custom_minimum_size = Vector2(maxf(1.0, cursor - 8.0 / s), _scroll.size.y) if _compact \
		else Vector2(0.0, maxf(1.0, cursor - 8.0 / s))
	_scroll.focus_mode = Control.FOCUS_ALL if (_content.custom_minimum_size.x > _scroll.size.x + 0.1 \
		or _content.custom_minimum_size.y > _scroll.size.y + 0.1) else Control.FOCUS_NONE
	_scroll.set("accessibility_name", "Current stage practice words and mastery progress")
	queue_redraw()


func _draw() -> void:
	if not _compact or _state.get("kind") != "main":
		return
	var stars: int = int(_state.get("stars_now", 0))
	for index in range(3):
		draw_texture_rect(RATING_STAR, Rect2(Vector2(17 + index * 18, 15) / _scale, Vector2.ONE * 10.0 / _scale),
			false, Color.WHITE if index < stars else Color(0.4, 0.45, 0.42, 0.45))


func snapshot() -> Dictionary:
	var words: Array = _state.get("practice", []).duplicate(true)
	for index in range(words.size()):
		var rect: Rect2 = _rows[index].surface.get_global_rect()
		words[index]["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		words[index]["gain_active"] = not reduced_motion and float(_rows[index].gain_elapsed) < GAIN_SECONDS
		words[index]["complete_active"] = not reduced_motion and float(_rows[index].complete_elapsed) < COMPLETE_SECONDS
		words[index]["completed_marker_visible"] = _rows[index].complete_badge.is_visible_in_tree()
	var bounds: Rect2 = get_global_rect()
	return {"visible": is_visible_in_tree(), "compact": _compact, "words": words,
		"rect": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]}

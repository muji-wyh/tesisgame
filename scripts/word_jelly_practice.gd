extends Panel
## The stage's durable learning evidence, outside the playable well.

signal word_progressed(word_id: String, complete: bool)

const Style = preload("res://scripts/ui_style.gd")
const Scroll = preload("res://scripts/review_scroll.gd")
const StageTimer = preload("res://scripts/word_jelly_stage_banner.gd")
const WordArt = preload("res://scripts/word_art.gd")
const MEDAL = preload("res://assets/images/ui/mastery-medal.webp")
const STAR = preload("res://assets/chests/milestone/sparkle.png")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const CHECK = preload("res://assets/images/ui/jelly-goals/completed.svg")
const CHECK_REVEAL = preload("res://scripts/word_jelly_goal_check.gdshader")
const RecordBadge = preload("res://scripts/word_jelly_record_badge.gd")
const GAIN_SECONDS: float = 0.55
const COMPLETE_SECONDS: float = 0.60
const COMPLETED_HOLD_SECONDS: float = 3.0
const EXIT_SECONDS: float = 0.38
var reduced_motion: bool = false
var stage_timer: StageTimer
var _title: Label
var _subtitle: Label
var _medal := TextureRect.new()
var _record_badge := RecordBadge.new()
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
	add_child(_record_badge)
	_record_badge.hide()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_scroll.add_child(_content)
	hide()


func set_stage(state: Dictionary) -> void:
	if _state == state:
		return
	if _state.get("kind") == state.get("kind") and _state.get("number") == state.get("number") \
		and _state.get("practice") == state.get("practice"):
		_state = state.duplicate(true)
		_update_heading()
		queue_redraw()
		return
	var previous: Dictionary = {}
	if not _state.is_empty() and _state.get("kind") == state.get("kind") \
		and int(_state.get("number", 0)) == int(state.get("number", 0)):
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
		check_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var check_material := ShaderMaterial.new()
		check_material.shader = CHECK_REVEAL
		check_icon.material = check_material
		badge.add_child(check_icon)
		_rows.append({"surface": surface, "background_progress": background, "label": label,
			"fraction": fraction, "picture": picture, "steps": steps, "gain_label": gain,
			"success_glow": glow, "success_sparkles": sparkles, "complete_badge": badge,
			"complete_icon": check_icon, "word_id": "",
			"gain_elapsed": GAIN_SECONDS, "complete_elapsed": COMPLETED_HOLD_SECONDS + EXIT_SECONDS,
			"gain_amount": 0, "mastered": false, "retired": false})
	var ordered: Array[Dictionary] = []
	var ids: Array = words.map(func(item: Dictionary) -> String: return str(item.id))
	for item: Dictionary in words:
		var matching: Array = _rows.filter(func(row: Dictionary) -> bool: return str(row.word_id) == str(item.id))
		if not matching.is_empty():
			ordered.append(matching[0])
		else:
			for row: Dictionary in _rows:
				if not ordered.has(row) and str(row.word_id) not in ids:
					ordered.append(row)
					break
	_rows = ordered
	for index in range(words.size()):
		var item: Dictionary = words[index]
		var row: Dictionary = _rows[index]
		var old: Dictionary = previous.get(str(item.id), {})
		if str(row.word_id) != str(item.id) or old.is_empty():
			row.gain_elapsed = GAIN_SECONDS
			row.complete_elapsed = COMPLETED_HOLD_SECONDS + EXIT_SECONDS
		row.word_id = str(item.id)
		row.mastered = bool(item.mastered)
		row.retired = row.mastered and (bool(row.retired) and not old.is_empty() \
			or float(row.complete_elapsed) >= _retire_time())
		if not old.is_empty() and is_visible_in_tree() and (int(item.current) > int(old.current) \
			or bool(item.mastered) and not bool(old.mastered)):
			row.gain_amount = int(item.current) - int(old.current)
			row.gain_elapsed = GAIN_SECONDS if reduced_motion else 0.0
			var completed: bool = bool(item.mastered) and not bool(old.mastered)
			if completed:
				row.complete_elapsed = 0.0
				row.retired = false
			word_progressed.emit(str(item.id), completed)
		elif not old.is_empty() and int(item.current) < int(old.current):
			row.gain_elapsed = GAIN_SECONDS
			row.complete_elapsed = COMPLETED_HOLD_SECONDS + EXIT_SECONDS
			row.retired = row.mastered
		row.label.text = "%s %d/%d" % [item.text, int(item.current), int(item.required)] \
			if _state.get("kind") == "challenge" and not item.mastered and _compact else str(item.text)
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
	_record_badge.advance(delta)
	_pose_timer_feedback()
	var reflow: bool = false
	for row: Dictionary in _rows:
		if float(row.gain_elapsed) >= GAIN_SECONDS \
			and (not row.mastered or row.retired):
			continue
		var previous_exit: float = _exit_progress(row)
		row.gain_elapsed = minf(GAIN_SECONDS, float(row.gain_elapsed) + delta)
		if row.mastered:
			row.complete_elapsed = minf(_retire_time(), float(row.complete_elapsed) + delta)
			row.retired = float(row.complete_elapsed) >= _retire_time()
		reflow = reflow or not is_equal_approx(previous_exit, _exit_progress(row))
		_pose_feedback(row)
	if reflow:
		_layout()


func feedback_active() -> bool:
	return _rows.any(func(row: Dictionary) -> bool:
		return (not reduced_motion and float(row.gain_elapsed) < GAIN_SECONDS) \
			or (row.mastered and not row.retired))


func _pose_feedback(row: Dictionary) -> void:
	row.surface.visible = not row.retired
	var exit: float = _exit_progress(row)
	row.surface.modulate.a = 1.0 - exit
	if row.has("base_position"):
		row.surface.position = row.base_position + Vector2((0.0 if reduced_motion else 22.0 * exit) / _scale, 0)
	var gaining: bool = not reduced_motion and float(row.gain_elapsed) < GAIN_SECONDS
	var completing: bool = not reduced_motion and float(row.complete_elapsed) < COMPLETE_SECONDS
	var p: float = clampf(float(row.gain_elapsed) / GAIN_SECONDS, 0.0, 1.0)
	var complete_p: float = clampf(float(row.complete_elapsed) / COMPLETE_SECONDS, 0.0, 1.0)
	row.fraction.scale = Vector2.ONE * (1.0 + (0.18 * sin(p * PI) if gaining else 0.0))
	row.picture.scale = Vector2.ONE * (1.0 + (0.12 * sin(p * PI) if gaining else 0.0))
	row.gain_label.visible = gaining and not _compact and not row.mastered
	row.gain_label.text = "+%d" % int(row.gain_amount)
	row.gain_label.modulate.a = 1.0 - smoothstep(0.45, 1.0, p)
	row.gain_label.position = Vector2(row.fraction.position.x, (1.0 - p * 7.0) / _scale)
	var label_end: float = row.surface.size.x - 10.0 / _scale if _compact \
		else row.surface.size.x - 40.0 / _scale if row.mastered else row.fraction.position.x - 6.0 / _scale
	row.label.size.x = maxf(1.0, label_end - row.label.position.x)
	row.fraction.visible = not _compact and not row.mastered
	row.complete_badge.visible = row.mastered and not row.retired
	row.complete_badge.scale = Vector2.ONE * (1.0 + 0.18 * sin(complete_p * PI) if completing else 1.0)
	row.complete_icon.material.set_shader_parameter("check_progress",
		1.0 if reduced_motion else smoothstep(0.04, COMPLETE_SECONDS * 0.75, float(row.complete_elapsed)))
	for star: TextureRect in row.steps:
		star.visible = not _compact and not row.mastered and _state.get("kind", "") not in ["main", "challenge"]
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


func _exit_progress(row: Dictionary) -> float:
	if not row.mastered:
		return 0.0
	if reduced_motion:
		return 1.0 if float(row.complete_elapsed) >= COMPLETED_HOLD_SECONDS else 0.0
	return smoothstep(COMPLETED_HOLD_SECONDS, COMPLETED_HOLD_SECONDS + EXIT_SECONDS, float(row.complete_elapsed))


func _retire_time() -> float:
	return COMPLETED_HOLD_SECONDS + (0.0 if reduced_motion else EXIT_SECONDS)


func timer_width() -> float:
	return 112.0 if _state.get("kind") == "challenge" else 86.0


func configure_layout(area: Rect2, ui_scale: float, compact: bool) -> void:
	position = area.position
	size = area.size
	_scale = ui_scale
	_compact = compact
	_layout()


func _update_heading() -> void:
	var challenge: bool = _state.get("kind") == "challenge"
	_title.visible = not challenge or _compact
	_subtitle.visible = not _compact and not challenge
	_medal.visible = not _compact and not challenge
	_record_badge.visible = challenge
	if not challenge and _record_badge.value >= 0:
		_record_badge.reset()
	if challenge:
		var best: int = int(_state.get("challenge_best_stage", 0))
		_record_badge.reduced_motion = reduced_motion
		_record_badge.set_record(best, _record_badge.value >= 0 and best > _record_badge.value)
		_subtitle.text = ""
	if _compact and _state.get("kind") in ["main", "challenge"]:
		var remaining: int = maxi(0, ceili(float(_state.get("seconds_remaining", 0))))
		_title.text = "%d:%02d" % [remaining / 60, remaining % 60]
	else:
		_title.text = "" if challenge else "Word goals"
		_subtitle.text = "%d of %d goals done" % [int(_state.get("mastered", 0)), _rows.size()] \
			if _state.get("kind") == "main" else "%d of %d mastered" % [int(_state.get("mastered", 0)), _rows.size()]
	_pose_timer_feedback()


func _pose_timer_feedback() -> void:
	var boost: float = stage_timer.time_bonus_scale() \
		if _compact and _state.get("kind") == "challenge" and stage_timer != null else 1.0
	_title.scale = Vector2.ONE * boost
	if is_equal_approx(boost, 1.0):
		return
	var font: Font = _title.get_theme_font("font")
	var width: float = font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_title.get_theme_font_size("font_size")).x
	_title.pivot_offset = Vector2(maxf(0.0, _title.size.x - width), _title.size.y * 0.5)


func _layout() -> void:
	if not visible:
		return
	var s: float = _scale
	var padding: float = 6.0 / s
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_title.add_theme_font_size_override("font_size", ceili((12.0 if _compact else 20.0) / s))
	_update_heading()
	var timed: bool = _state.get("kind") in ["main", "challenge"]
	_subtitle.add_theme_font_size_override("font_size", ceili(12.0 / s))
	_medal.position = Vector2(0, 2.0) / s
	_medal.size = Vector2(36, 40) / s
	var stacked: bool = _compact and not timed and size.y * s >= 40.0
	var title_height: float = 18.0 / s if stacked else size.y - padding * 2.0
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.position = Vector2(padding if _compact else 46.0 / s, 0.0)
	_title.size = Vector2(size.x - (padding * 2.0 if _compact else 46.0 / s) if stacked or not _compact else 62.0 / s,
		(16.0 / s if timed and _compact else title_height) if _compact else 28.0 / s)
	if timed and _compact:
		_title.size.x = (timer_width() - 10.0) / s
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle.position = Vector2(46, 28) / s
	_subtitle.size = Vector2(maxf(1.0, size.x - 46.0 / s), 20.0 / s)
	if _compact and _state.get("kind") == "challenge":
		_record_badge.layout_badge(Rect2(Vector2(6, 20) / s, Vector2(timer_width() - 12.0, 24) / s), s)
	elif _state.get("kind") == "challenge":
		_record_badge.layout_badge(Rect2(Vector2.ZERO, Vector2(size.x, 52.0 / s)), s)
	_scroll.position = Vector2(padding if stacked or not _compact else (timer_width() + 2.0 if timed else 70.0) / s,
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
		if _state.get("kind") == "challenge":
			for item: Dictionary in _state.get("practice", []):
				if str(item.id) == str(row.word_id):
					row.label.text = "%s %d/%d" % [item.text, int(item.current), int(item.required)] \
						if _compact and not item.mastered else str(item.text)
					break
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
		row.fraction.add_theme_font_size_override("font_size", ceili(13.0 / s))
		var width: float = minf(220.0 / s, maxf(82.0 / s,
			Style.HEADING_FONT.get_string_size(row.label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 44.0 / s)) \
			if _compact else _scroll.size.x
		var height: float = _scroll.size.y if _compact else 52.0 / s
		row.base_position = Vector2(cursor, 0.0) if _compact else Vector2(0.0, cursor)
		row.surface.position = row.base_position
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
		row.label.position = Vector2(left, 0.0)
		row.label.size = Vector2(maxf(1.0, width - left - 10.0 / s),
			height)
		var fraction_width: float = minf(width * 0.43, maxf(34.0 / s,
			Style.HEADING_FONT.get_string_size(row.fraction.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				row.fraction.get_theme_font_size("font_size")).x + 8.0 / s))
		var fraction_height: float = maxf(20.0 / s, row.fraction.get_combined_minimum_size().y)
		row.fraction.position = Vector2(width - fraction_width - 8.0 / s, (height - fraction_height) * 0.5)
		row.fraction.size = Vector2(fraction_width, fraction_height)
		row.fraction.pivot_offset = row.fraction.size * 0.5
		row.gain_label.size = Vector2(fraction_width, 14.0 / s)
		row.gain_label.add_theme_font_size_override("font_size", ceili(11.0 / s))
		row.complete_badge.add_theme_stylebox_override("panel",
			Style.box(Style.GOOD, Color.TRANSPARENT, ceili((7.0 if _compact else 14.0) / s), 0))
		row.complete_badge.position = row.picture.position + row.picture.size - Vector2.ONE * 14.0 / s if _compact \
			else Vector2(width - 34.0 / s, (height - 28.0 / s) * 0.5)
		row.complete_badge.size = Vector2.ONE * (14.0 if _compact else 28.0) / s
		row.complete_badge.pivot_offset = row.complete_badge.size * 0.5
		row.complete_icon.position = Vector2.ONE * (1.0 if _compact else 2.0) / s
		row.complete_icon.size = Vector2.ONE * (12.0 if _compact else 24.0) / s
		for index in range(3):
			var star: TextureRect = row.steps[index]
			star.visible = not _compact
			star.position = Vector2(left + index * 17.0 / s, 32.0 / s)
			star.size = Vector2.ONE * 13.0 / s
		_pose_feedback(row)
		if not row.retired:
			cursor += (width + 8.0 / s if _compact else height + 8.0 / s) * (1.0 - _exit_progress(row))
	_content.custom_minimum_size = Vector2(maxf(1.0, cursor - 8.0 / s), _scroll.size.y) if _compact \
		else Vector2(0.0, maxf(1.0, cursor - 8.0 / s))
	_scroll.focus_mode = Control.FOCUS_ALL if (_content.custom_minimum_size.x > _scroll.size.x + 0.1 \
		or _content.custom_minimum_size.y > _scroll.size.y + 0.1) else Control.FOCUS_NONE
	_scroll.set("accessibility_name", "Current stage practice words and mastery progress")
	queue_redraw()


func _draw() -> void:
	if not _compact:
		return
	if _state.get("kind") in ["main", "challenge"]:
		var ratio: float = clampf(float(_state.get("seconds_remaining", 0.0)) \
			/ maxf(0.001, float(_state.get("seconds_total", 90.0))), 0.0, 1.0)
		var clock_bounds := Rect2(Vector2.ZERO, Vector2(timer_width() / _scale, size.y))
		draw_style_box(Style.box(Color("#fbf5e8"), Color("#ddd3bc"), 10, 1), clock_bounds)
		var fill := Rect2(Vector2(6.0 / _scale, size.y - 3.0 / _scale),
			Vector2((timer_width() - 12.0) * ratio / _scale, 2.0 / _scale))
		if fill.has_area():
			draw_style_box(Style.box(Color("#78b9ae"), Color.TRANSPARENT, 1, 0), fill)
		if _state.get("kind") == "main" and stage_timer != null:
			stage_timer.draw_rating(self, Rect2(Vector2(6, 18) / _scale, Vector2(72, 24) / _scale), _scale, true)
		return


func snapshot() -> Dictionary:
	var words: Array = _state.get("practice", []).duplicate(true)
	for index in range(words.size()):
		var rect: Rect2 = _rows[index].surface.get_global_rect()
		words[index]["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		words[index]["gain_active"] = not reduced_motion and float(_rows[index].gain_elapsed) < GAIN_SECONDS
		words[index]["complete_active"] = not reduced_motion and float(_rows[index].complete_elapsed) < COMPLETE_SECONDS
		words[index]["completed_marker_visible"] = _rows[index].complete_badge.is_visible_in_tree()
		words[index]["visible"] = _rows[index].surface.is_visible_in_tree()
		words[index]["retired"] = bool(_rows[index].retired)
		words[index]["dismiss_remaining"] = maxf(0.0, COMPLETED_HOLD_SECONDS - float(_rows[index].complete_elapsed)) \
			if _rows[index].mastered and not _rows[index].retired else 0.0
	var bounds: Rect2 = get_global_rect()
	return {"visible": is_visible_in_tree(), "compact": _compact, "words": words,
		"record": _record_badge.snapshot(),
		"rect": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]}

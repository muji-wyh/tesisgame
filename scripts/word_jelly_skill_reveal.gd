extends Control
## An earned ability explanation and a view-only preview, never a reward source.

signal accepted

const Style = preload("res://scripts/ui_style.gd")
const Tile = preload("res://scripts/word_jelly_tile.gd")
const WordArt = preload("res://scripts/word_art.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const NAMES: Array[String] = ["", "", "Neighbor burst", "Wider burst", "Surrounding burst",
	"Column burst", "Cross burst", "Extended ring", "Double ring", "Board burst"]

var reduced_motion: bool = false
var _level: int = 0
var _elapsed: float = 0.0
var _title: Label
var _level_label: Label
var _description: Label
var _continue := Button.new()
var _demo := Control.new()
var _jelly := Tile.new()
var _targets: Array[Vector2i] = []
var _picture: Texture2D
var _demo_pitch: float = 1.0


func _init() -> void:
	name = "NewJellySkill"
	z_index = 60
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	for key: String in ["New skill unlocked!", "", ""]:
		var label: Label = Style.label(key, 18)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)
		if _title == null:
			_title = label
		elif _level_label == null:
			_level_label = label
		else:
			_description = label
	_title.add_theme_font_override("font", Style.HEADING_FONT)
	_title.add_theme_color_override("font_color", Style.GOOD)
	_demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo.draw.connect(_draw_demo)
	add_child(_demo)
	_jelly.disabled = true
	_jelly.focus_mode = Control.FOCUS_NONE
	_demo.add_child(_jelly)
	_continue.text = "Let's try it"
	_continue.accessibility_name = "Continue to the map with your new Jelly skill"
	Style.action_button(_continue, Style.GOOD)
	add_child(_continue)
	_continue.pressed.connect(func() -> void:
		if is_visible_in_tree() and not _continue.disabled:
			hide()
			accepted.emit())
	resized.connect(_layout)
	hide()


func present(level: int, word: Dictionary, steady: bool) -> bool:
	if level < 2 or level > 9 or word.is_empty():
		push_error("A new Jelly skill needs an earned level and its actual learned word.")
		return false
	_level = level
	_elapsed = 0.0
	reduced_motion = steady
	_continue.disabled = true
	_level_label.text = "Lv%d · %s" % [level, NAMES[level]]
	var reach: String = "up to %d nearby jellies" % [4, 6, 8][level - 2] if level <= 4 \
		else "its whole column" if level == 5 else "its row and column" if level == 6 \
		else "the inner ring and 4 outer jellies" if level == 7 \
		else "two rings, up to 22 jellies" if level == 8 else "the whole board"
	_description.text = "Collect it to reach %s.\nMatching pieces merge automatically." % reach
	_picture = WordArt.texture(str(word.get("image", "")), self)
	_jelly.configure({"id": 1, "word": word, "text": word.text, "jelly_kind": "merged",
		"merge_level": level, "fragments": 0}, SKIN, _picture, null, Style.GOOD, true)
	_targets.clear()
	var inner: Array[Vector2i] = []
	var outer: Array[Vector2i] = []
	for row in range(-2, 3):
		for column in range(-2, 3):
			var point := Vector2i(column, row)
			if point == Vector2i.ZERO:
				continue
			var distance: int = maxi(absi(column), absi(row))
			if level == 9 or level == 5 and column == 0 or level == 6 and (column == 0 or row == 0):
				_targets.append(point)
			elif distance == 1:
				inner.append(point)
			else:
				outer.append(point)
	if level <= 4:
		_targets.assign(inner.slice(0, [4, 6, 8][level - 2]))
	elif level in [7, 8]:
		_targets = inner
		_targets.append_array(outer.slice(0, 4 if level == 7 else 14))
	set("accessibility_name", "New skill unlocked. " + _level_label.text + ". " + _description.text)
	show()
	_layout()
	grab_focus()
	return true


func advance(delta: float) -> void:
	if not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed += delta
	var was_disabled: bool = _continue.disabled
	_continue.disabled = _elapsed < 1.1
	if was_disabled and not _continue.disabled:
		_continue.grab_focus()
	_jelly.set_merged_presentation(_elapsed, reduced_motion)
	var pulse: float = 1.0 if reduced_motion else 1.0 + 0.05 * sin(minf(_elapsed / 0.6, 1.0) * PI)
	_jelly.scale = Vector2.ONE * pulse
	_demo.queue_redraw()
	queue_redraw()


func _layout() -> void:
	if _title == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var s: float = Style.ui_scale(self)
	var short: bool = size.x > size.y * 1.3 and size.y * s < 430.0
	var demo_edge: float = minf(size.x * 0.35, size.y - 16.0 / s) if short \
		else minf(size.x - 32.0 / s, maxf(32.0 / s, size.y - 196.0 / s))
	var left: float = demo_edge + 20.0 / s if short else 12.0 / s
	var width: float = maxf(1.0, size.x - left - 12.0 / s)
	_title.text = "New skill!" if short else "New skill unlocked!"
	_title.position = Vector2(left, 6.0 / s)
	_title.size = Vector2(width, 32.0 / s)
	_title.add_theme_font_size_override("font_size", ceili(minf(24.0, width * s / 10.0) / s))
	_level_label.position = Vector2(left, 38.0 / s)
	_level_label.size = Vector2(width, 26.0 / s)
	_level_label.add_theme_font_size_override("font_size", ceili(15.0 / s))
	_demo.position = Vector2(8.0 / s, (size.y - demo_edge) * 0.5) if short \
		else Vector2((size.x - demo_edge) * 0.5, 70.0 / s)
	_demo.size = Vector2.ONE * demo_edge
	_demo_pitch = demo_edge / 5.0
	_jelly.size = Vector2.ONE * _demo_pitch * 0.88
	_jelly.position = (_demo.size - _jelly.size) * 0.5
	_jelly.pivot_offset = _jelly.size * 0.5
	_description.position = Vector2(left, 70.0 / s) if short \
		else Vector2(left, _demo.get_rect().end.y + 6.0 / s)
	_description.size = Vector2(width, maxf(1.0, size.y - 60.0 / s - _description.position.y))
	_description.add_theme_font_size_override("font_size", ceili(14.0 / s))
	_continue.custom_minimum_size = Vector2.ZERO
	_continue.size = Vector2(minf(width, 184.0 / s), 44.0 / s)
	_continue.position = Vector2(left + (width - _continue.size.x) * 0.5, size.y - 50.0 / s)
	_demo.queue_redraw()
	queue_redraw()


func _draw() -> void:
	draw_style_box(Style.box(Color("#fffcf2"), Color("#c8ddb8"), 16, 1), Rect2(Vector2.ZERO, size))
	draw_texture_rect(GLOW, Rect2(Vector2(size.x * 0.15, 0), Vector2(size.x * 0.7, size.y * 0.5)),
		false, Color(1.0, 0.87, 0.45, 0.22))


func _draw_demo() -> void:
	if not visible or _level == 0:
		return
	var age: float = fposmod(_elapsed, 3.2)
	var travel: float = 1.0 if reduced_motion else smoothstep(0.5, 1.5, age)
	var center: Vector2 = _demo.size * 0.5
	for row in range(-2, 3):
		for column in range(-2, 3):
			var point := Vector2i(column, row)
			if point == Vector2i.ZERO:
				continue
			var at: Vector2 = center + Vector2(point) * _demo_pitch
			var edge: float = _demo_pitch * 0.85
			var targeted: bool = point in _targets
			_demo.draw_texture_rect(SKIN, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
				false, Color(1, 1, 1, 1.0 if targeted else 0.25))
			if _picture != null:
				_demo.draw_texture_rect(_picture, Rect2(at - Vector2.ONE * edge * 0.27, Vector2.ONE * edge * 0.54),
					false, Color(1, 1, 1, 0.85 if targeted else 0.18))
			if not targeted:
				continue
			var light: Vector2 = center.lerp(at, travel)
			_demo.draw_texture_rect(GLOW, Rect2(light - Vector2.ONE * edge * 0.55, Vector2.ONE * edge * 1.1),
				false, Color(0.85, 0.65, 1.0, 0.60))
			if travel >= 1.0:
				_demo.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.22, Vector2.ONE * edge * 0.44),
					false, Color("#fff1b0"))
	_demo.draw_texture_rect(RAYS, Rect2(center - Vector2.ONE * _demo_pitch, Vector2.ONE * _demo_pitch * 2),
		false, Color(1.0, 0.86, 0.45, 0.24))


func snapshot() -> Dictionary:
	var rect: Rect2 = _continue.get_global_rect()
	return {"visible": is_visible_in_tree(), "level": _level, "skill": NAMES[_level] if _level > 0 else "",
		"description": _description.text, "elapsed": _elapsed, "preview_targets": _targets.size(),
		"continue": {"enabled": not _continue.disabled,
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}}

extends Control
## An inert scenic route; the campaign coordinator owns progress and rewards.

signal stage_selected(number: int)
signal challenge_selected
signal home_requested
signal retry_requested

const Style = preload("res://scripts/ui_style.gd")
const Scroll = preload("res://scripts/result_scroll.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const STAR = preload("res://assets/images/ui/jelly-goals/star.webp")
const SKY = preload("res://assets/images/jelly-match/sky/day.png")
const GELS: Array[Texture2D] = [
	preload("res://assets/images/jelly-match/gel-mint.png"),
	preload("res://assets/images/jelly-match/gel-sky.png"),
	preload("res://assets/images/jelly-match/gel-coral.png"),
	preload("res://assets/images/jelly-match/gel-lilac.png")]
const SCENERY: Array[Texture2D] = [
	preload("res://assets/images/jelly-match/garden/hills.png"),
	preload("res://assets/images/jelly-match/garden/tree.png"),
	preload("res://assets/images/jelly-campaign/tree-pine.png"),
	preload("res://assets/images/jelly-campaign/cottage.png"),
	preload("res://assets/images/jelly-campaign/tree-orange.png"),
	preload("res://assets/images/jelly-campaign/tree-snow.png"),
	preload("res://assets/images/jelly-campaign/tree-pine-snow.png"),
	preload("res://assets/images/jelly-campaign/tree-palm.png"),
	preload("res://assets/images/jelly-campaign/cactus.png"),
	preload("res://assets/images/jelly-campaign/mountains.png"),
	preload("res://assets/images/jelly-campaign/castle.png")]
const HILLS = preload("res://assets/images/jelly-match/garden/hills.png")
const FOLIAGE = preload("res://assets/images/jelly-match/garden/foliage.png")
const TREE = preload("res://assets/images/jelly-match/garden/tree-long.png")
const FADE = preload("res://scripts/scenic_art_fade.gdshader")
var _state: Dictionary = {}
var _scroll := Scroll.new()
var _content := Control.new()
var _sky := TextureRect.new()
var _heading: Label
var _subtitle: Label
var _wallet: Label
var _status: Label
var _home: Button
var _challenge: Button
var _retry: Button
var _nodes: Array[Dictionary] = []
var _chapters: Array[Dictionary] = []
var _scale: float = 1.0


func _init() -> void:
	name = "JellyStageMap"
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sky.texture = SKY
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.modulate = Color(0.93, 0.98, 1.0, 1.0)
	add_child(_sky)
	_heading = _label(self, "Jelly Journey", 30)
	_subtitle = _label(self, "99 little adventures. Collect words, earn stars.", 14)
	_wallet = _label(self, "", 16)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_home = _button("Home", "Back to game library")
	_home.pressed.connect(func() -> void: home_requested.emit())
	_challenge = _button("Endless Challenge\nNo timer", "Endless challenge. No timer. Growing variety and speed.")
	_challenge.add_theme_stylebox_override("normal", _gel_style(GELS[3]))
	_challenge.pressed.connect(func() -> void:
		if not _challenge.disabled:
			challenge_selected.emit())
	_status = _label(self, "", 15)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_retry = _button("Retry", "Retry stage loading or saving")
	_retry.pressed.connect(func() -> void: retry_requested.emit())
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.interaction_allowed = func() -> bool: return is_visible_in_tree() and not bool(_state.get("loading", false))
	add_child(_scroll)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.draw.connect(_draw_route)
	for chapter in range(11):
		var title: Label = _label(_content, Catalog.CHAPTERS[chapter], 27)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var number: Label = _label(_content, "CHAPTER %02d" % (chapter + 1), 11)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var left: TextureRect = _image(_content, SCENERY[chapter])
		var right: TextureRect = _image(_content, SCENERY[chapter])
		var hills: TextureRect = _image(_content, HILLS)
		hills.stretch_mode = TextureRect.STRETCH_SCALE
		hills.modulate = Color(0.65, 0.92, 0.84, 0.58)
		var fade := ShaderMaterial.new()
		fade.shader = FADE
		hills.material = fade
		if chapter in [0, 9]:
			left.material = fade
			right.material = fade
		var shrubs: TextureRect = _image(_content, FOLIAGE)
		var grove: TextureRect = _image(_content, TREE)
		_chapters.append({"title": title, "number": number, "left": left, "right": right,
			"hills": hills, "shrubs": shrubs, "grove": grove})
	for number in range(1, 100):
		var button := Button.new()
		button.name = "Stage%d" % number
		button.text = str(number)
		button.add_theme_font_override("font", Style.HEADING_FONT)
		button.add_theme_color_override("font_color", Style.INK)
		button.add_theme_color_override("font_disabled_color", Color("#6d7d7b"))
		button.add_theme_color_override("font_hover_color", Style.INK)
		button.add_theme_color_override("font_pressed_color", Style.GOOD)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_stylebox_override("normal", _gel_style(GELS[(number - 1) / 9 % GELS.size()]))
		button.add_theme_stylebox_override("hover", _gel_style(GELS[(number - 1) / 9 % GELS.size()]))
		button.add_theme_stylebox_override("pressed", _gel_style(GELS[(number - 1) / 9 % GELS.size()]))
		button.add_theme_stylebox_override("disabled", _gel_style(GELS[1], Color(0.67, 0.72, 0.73, 0.65)))
		button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Color("#fff5b9"), 20, 3))
		button.pressed.connect(_select.bind(number))
		_content.add_child(button)
		button.focus_entered.connect(_reveal_stage.bind(number))
		var stars: Array[TextureRect] = []
		for index in range(3):
			stars.append(_image(button, STAR))
		var next: Label = _label(button, "NEXT", 10)
		next.add_theme_color_override("font_color", Color("#a26618"))
		next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_nodes.append({"number": number, "button": button, "stars": stars, "next": next})
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_scroll.cancel_drag())
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: queue_redraw())
	set_process(false)
	hide()


func _ready() -> void:
	get_viewport().size_changed.connect(_layout.call_deferred)
	_layout()


func _label(parent: Node, text: String, pixels: int) -> Label:
	var label: Label = Style.label(text, pixels)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Style.HEADING_FONT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _button(text: String, description: String) -> Button:
	var button := Button.new()
	button.text = text
	button.accessibility_name = description
	Style.action_button(button, Style.GOOD)
	add_child(button)
	return button


func _image(parent: Node, texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image


func _gel_style(texture: Texture2D, color: Color = Color.WHITE) -> StyleBoxTexture:
	var surface := StyleBoxTexture.new()
	surface.texture = texture
	surface.modulate_color = color
	surface.set_content_margin_all(0.0)
	surface.content_margin_bottom = 22.0
	return surface


func configure(state: Dictionary, _reduced_motion: bool = false) -> void:
	_state = state.duplicate(true)
	var highest: int = clampi(int(state.get("highest_cleared", 0)), 0, 99)
	var blocked: bool = bool(state.get("loading", false)) or not str(state.get("error", "")).is_empty()
	for item: Dictionary in _nodes:
		var number: int = int(item.number)
		var stars: int = int(state.get("best_stars", {}).get(str(number), 0))
		item.button.disabled = number > mini(highest + 1, 99) or blocked
		item.button.focus_mode = Control.FOCUS_ALL if not item.button.disabled else Control.FOCUS_NONE
		item.button.accessibility_name = "Stage %d. %d of 3 stars. %s." % [
			number, stars, "Replay" if number <= highest else "Next" if number == highest + 1 else "Locked"]
		for index in range(3):
			item.stars[index].modulate = Color.WHITE if index < stars else Color(0.32, 0.41, 0.43, 0.48)
		item.next.visible = number == highest + 1
	_challenge.disabled = blocked
	_challenge.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	_wallet.text = "%d coins" % int(state.get("coins", 0))
	_status.text = str(state.get("error", "")) if not str(state.get("error", "")).is_empty() \
		else "Loading stage %d..." % int(state.get("pending_stage", 0)) if state.get("loading", false) else ""
	_status.add_theme_color_override("font_color", Style.WRONG if not str(state.get("error", "")).is_empty() else Style.INK)
	_retry.visible = not str(state.get("error", "")).is_empty()
	_status.visible = not _status.text.is_empty()
	_layout()


func open(state: Dictionary, reduced_motion: bool = false) -> void:
	configure(state, reduced_motion)
	show()
	_layout()
	focus_frontier.call_deferred()


func close() -> void:
	_scroll.cancel_drag()
	hide()


func focus_frontier() -> void:
	if not is_visible_in_tree():
		return
	var index: int = mini(clampi(int(_state.get("highest_cleared", 0)), 0, 99), 98)
	var button: Button = _nodes[index].button
	if not button.disabled:
		_reveal_stage(index + 1)
		button.grab_focus()
	else:
		_home.grab_focus()


func _select(number: int) -> void:
	if _nodes[number - 1].button.disabled:
		return
	stage_selected.emit(number)


func _reveal_stage(number: int) -> void:
	var button: Button = _nodes[number - 1].button
	_scroll.ensure_control_visible(button)
	var maximum: float = _scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page
	_scroll.scroll_vertical = roundi(clampf(button.position.y - (_scroll.size.y - button.size.y) * 0.45, 0.0, maximum))


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventJoypadButton or event.button_index != JOY_BUTTON_A:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button and is_ancestor_of(focused):
		if event.pressed and not focused.disabled:
			focused.pressed.emit()
		get_viewport().set_input_as_handled()


func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if not is_visible_in_tree():
		return controls
	controls.append(_home)
	if not _challenge.disabled:
		controls.append(_challenge)
	if _retry.visible:
		controls.append(_retry)
	for item: Dictionary in _nodes:
		if not item.button.disabled:
			controls.append(item.button)
	return controls


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s: float = Style.ui_scale(self)
	_scale = s
	_sky.size = size
	var narrow: bool = size.x * s < 600.0
	var width: float = minf(size.x - 24.0 / s, 1000.0 / s)
	var left: float = (size.x - width) * 0.5
	var top: float = 14.0 / s
	_home.custom_minimum_size = Vector2(0, ceilf(44.0 / s))
	_home.add_theme_font_size_override("font_size", ceili(14.0 / s))
	_home.position = Vector2(left, top)
	_home.size = (Vector2(76, 44) / s).ceil()
	_heading.position = Vector2(left + 88.0 / s, top)
	_heading.size = Vector2(width - 88.0 / s, 38.0 / s)
	_heading.add_theme_font_size_override("font_size", ceili((24.0 if narrow else 32.0) / s))
	_subtitle.position = Vector2(left, top + 48.0 / s)
	_subtitle.size = Vector2(width, 30.0 / s)
	_subtitle.text = "Collect words. Earn stars. Explore." if narrow else "99 little adventures. Collect words, earn stars."
	_subtitle.add_theme_font_size_override("font_size", ceili(14.0 / s))
	_wallet.visible = not narrow
	_wallet.position = Vector2(left + width - 150.0 / s, top)
	_wallet.size = Vector2(150, 38) / s
	_challenge.custom_minimum_size = Vector2.ZERO
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var surface: StyleBox = _challenge.get_theme_stylebox(state)
		surface.set_content_margin_all(0.0)
	_challenge.add_theme_font_size_override("font_size", ceili(15.0 / s))
	_challenge.size = Vector2(minf(width, 232.0 / s), ceilf(62.0 / s))
	_challenge.position = Vector2(left + width - _challenge.size.x, size.y - _challenge.size.y - 14.0 / s)
	var status_height: float = 76.0 / s if _status.visible else 0.0
	_status.position = Vector2(left, 90.0 / s)
	_status.size = Vector2(width - (84.0 / s if _retry.visible else 0.0), status_height)
	_status.add_theme_font_size_override("font_size", ceili(14.0 / s))
	_retry.position = Vector2(left + width - 78.0 / s, 98.0 / s)
	_retry.size = Vector2(78, 44) / s
	_content.custom_minimum_size.x = 0.0
	_scroll.position = Vector2(left, 88.0 / s + status_height)
	_scroll.size = Vector2(width, maxf(1.0, _challenge.position.y - _scroll.position.y - 12.0 / s))
	var chapter_height: float = 1160.0 / s
	var node_size := Vector2(98, 92) / s
	var amplitude: float = minf(width * 0.27, 240.0 / s)
	for index in range(_chapters.size()):
		var section: Dictionary = _chapters[index]
		var y: float = index * chapter_height
		section.number.position = Vector2(0, y + 20.0 / s)
		section.number.size = Vector2(width, 20.0 / s)
		section.number.add_theme_font_size_override("font_size", ceili(11.0 / s))
		section.title.position = Vector2(0, y + 40.0 / s)
		section.title.size = Vector2(width, 42.0 / s)
		section.title.add_theme_font_size_override("font_size", ceili((23.0 if narrow else 30.0) / s))
		var scenery_width: float = minf(width * 0.38, 270.0 / s)
		section.left.position = Vector2(8.0 / s, y + 170.0 / s)
		section.left.size = Vector2(scenery_width, 230.0 / s)
		section.left.modulate.a = 0.72
		section.right.position = Vector2(width - scenery_width - 8.0 / s, y + 660.0 / s)
		section.right.size = Vector2(scenery_width, 250.0 / s)
		section.right.modulate.a = 0.82
		section.hills.position = Vector2(0, y + 830.0 / s)
		section.hills.size = Vector2(width, 260.0 / s)
		section.shrubs.position = Vector2(12.0 / s, y + 1030.0 / s)
		section.shrubs.size = Vector2(width * 0.35, 75.0 / s)
		section.grove.position = Vector2(width * 0.70, y + 440.0 / s)
		section.grove.size = Vector2(minf(width * 0.25, 170.0 / s), 210.0 / s)
		section.grove.modulate = Color(0.9, 1.0, 0.96, 0.50)
	for item: Dictionary in _nodes:
		var number: int = int(item.number)
		var chapter: int = (number - 1) / 9
		var step: int = (number - 1) % 9
		var center := Vector2(width * 0.5 + sin(float(step) * PI * 0.5) * amplitude,
			chapter * chapter_height + (136.0 + step * 116.0) / s)
		var button: Button = item.button
		button.position = center - node_size * 0.5
		button.size = node_size
		button.add_theme_font_size_override("font_size", ceili(28.0 / s))
		item.next.position = Vector2(18, 5) / s
		item.next.size = Vector2(62, 15) / s
		item.next.add_theme_font_size_override("font_size", ceili(10.0 / s))
		for name: String in ["normal", "hover", "pressed", "disabled"]:
			button.get_theme_stylebox(name).content_margin_bottom = 25.0 / s
		for index in range(3):
			var star: TextureRect = item.stars[index]
			star.position = Vector2((14.0 + index * 24.0) / s, 61.0 / s)
			star.size = Vector2.ONE * 22.0 / s
	_content.custom_minimum_size = Vector2(0.0, chapter_height * 11.0)
	_content.size.x = width
	_content.queue_redraw()


func _draw_route() -> void:
	if _nodes.is_empty():
		return
	var curve := Curve2D.new()
	for index in range(_nodes.size()):
		var center: Vector2 = _nodes[index].button.get_rect().get_center()
		curve.add_point(center, Vector2(0, -40.0 / _scale), Vector2(0, 40.0 / _scale))
	var points: PackedVector2Array = curve.get_baked_points()
	if points.size() > 1:
		_content.draw_polyline(points, Color(0.38, 0.55, 0.48, 0.15), 26.0 / _scale, true)
		_content.draw_polyline(points, Color("#fff6df"), 18.0 / _scale, true)
		_content.draw_polyline(points, Color("#dccb99"), 2.0 / _scale, true)


func _rect(bounds: Rect2) -> Dictionary:
	return {"x": bounds.position.x, "y": bounds.position.y, "width": bounds.size.x, "height": bounds.size.y}


func _control(control: Control) -> Dictionary:
	return {"visible": control.is_visible_in_tree(), "enabled": not control.disabled,
		"rect": _rect(control.get_global_rect())}


func snapshot() -> Dictionary:
	var stages: Array[Dictionary] = []
	var highest: int = clampi(int(_state.get("highest_cleared", 0)), 0, 99)
	for item: Dictionary in _nodes:
		var number: int = int(item.number)
		stages.append({"number": number, "chapter": ceili(float(number) / 9.0),
			"unlocked": number <= mini(highest + 1, 99),
			"best_stars": int(_state.get("best_stars", {}).get(str(number), 0)),
			"rect": _rect(item.button.get_global_rect()),
			"visible": is_visible_in_tree() and _scroll.get_global_rect().intersects(item.button.get_global_rect())})
	return {"visible": is_visible_in_tree(), "map_rect": _rect(get_global_rect()),
		"scroll_rect": _rect(_scroll.get_global_rect()), "scroll_offset": _scroll.scroll_vertical,
		"stage_nodes": stages, "challenge": _control(_challenge), "home": _control(_home),
		"retry": _control(_retry), "loading": bool(_state.get("loading", false)),
		"error": str(_state.get("error", ""))}

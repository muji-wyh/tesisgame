extends Control
## An inert scenic route; the campaign coordinator owns progress and rewards.

signal stage_selected(number: int)
signal challenge_selected
signal home_requested
signal retry_requested
signal changed

const Style = preload("res://scripts/ui_style.gd")
const Scroll = preload("res://scripts/result_scroll.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Icons = preload("res://scripts/icon_button.gd")
const STAR = preload("res://assets/images/ui/jelly-goals/star.webp")
const SKY = preload("res://assets/images/jelly-match/sky/day.png")
const STAGE_OPEN = preload("res://assets/images/ui/jelly-map/stage-open.png")
const STAGE_LOCKED = preload("res://assets/images/ui/jelly-map/stage-locked.png")
const PANEL = preload("res://assets/images/ui/jelly-map/adventure-panel.png")
const COIN = preload("res://assets/coins/gold-coin.png")
const PLAY = preload("res://assets/images/ui/controls/player-play.svg")
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
var _challenge_icon: TextureRect
var _challenge_title: Label
var _challenge_caption: Label
var _challenge_frame: Panel
var _nodes: Array[Dictionary] = []
var _chapters: Array[Dictionary] = []
var _scale: float = 1.0
var _publish_pending: bool = false


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
	_home = Icons.new()
	_home.set("symbol", Icons.Symbol.HOME)
	_home.accessibility_name = "Home. Back to game library"
	_home.tooltip_text = "Home"
	add_child(_home)
	_home.pressed.connect(func() -> void: home_requested.emit())
	_challenge = _button("", "Endless challenge. No timer. Earn coins with growing variety and speed.")
	_challenge_frame = Panel.new()
	_challenge_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_challenge_frame.add_theme_stylebox_override("panel", _panel_style())
	_challenge.add_child(_challenge_frame)
	_challenge_icon = _image(_challenge, COIN)
	_challenge_title = _label(_challenge, "Endless Challenge", 18)
	_challenge_caption = _label(_challenge, "No timer · Earn coins", 12)
	_challenge_caption.add_theme_color_override("font_color", Style.MUTED)
	for signal_name: String in ["mouse_entered", "mouse_exited", "button_down", "button_up", "focus_entered", "focus_exited"]:
		_challenge.connect(signal_name, _refresh_challenge_frame)
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
		button.add_theme_font_override("font", Style.HEADING_FONT)
		button.add_theme_color_override("font_color", Style.INK)
		button.add_theme_color_override("font_disabled_color", Color("#6d7d7b"))
		button.add_theme_color_override("font_hover_color", Style.INK)
		button.add_theme_color_override("font_pressed_color", Style.GOOD)
		button.focus_mode = Control.FOCUS_ALL
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Color("#719686"), 18, 2))
		button.pressed.connect(_select.bind(number))
		_content.add_child(button)
		button.focus_entered.connect(_reveal_stage.bind(number))
		var face: TextureRect = _image(button, STAGE_OPEN)
		var label: Label = _label(button, str(number), 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stars: Array[TextureRect] = []
		for index in range(3):
			stars.append(_image(button, STAR))
		var next: TextureRect = _image(button, PLAY)
		next.modulate = Style.GOOD
		var boss_label: Label = _label(button, "BOSS", 11)
		boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_label.add_theme_stylebox_override("normal", Style.box(Color("#f3ddef"), Color("#996b9d"), 8, 1))
		boss_label.hide()
		_nodes.append({"number": number, "button": button, "face": face, "label": label,
			"stars": stars, "next": next, "boss": boss_label})
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_scroll.cancel_drag())
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:
		queue_redraw()
		_queue_changed())
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


func _panel_style(color: Color = Color.WHITE) -> StyleBoxTexture:
	var surface := StyleBoxTexture.new()
	surface.texture = PANEL
	surface.modulate_color = color
	surface.set_content_margin_all(0.0)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		surface.set_texture_margin(side, 16.0)
	return surface


func _queue_changed() -> void:
	if _publish_pending or not is_inside_tree():
		return
	_publish_pending = true
	_publish_changed.call_deferred()


func _publish_changed() -> void:
	_publish_pending = false
	if is_visible_in_tree():
		changed.emit()


func _refresh_challenge_frame() -> void:
	_challenge_frame.self_modulate = Color("#ead5b6") if _challenge.is_pressed() else Color("#fff0d0") \
		if _challenge.is_hovered() or _challenge.has_focus() else Color.WHITE
	_challenge_icon.modulate.a = 0.45 if _challenge.disabled else 1.0
	_challenge_title.add_theme_color_override("font_color", Style.MUTED if _challenge.disabled else Style.INK)


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
		var unlocked: bool = number <= mini(highest + 1, 99)
		item.face.texture = STAGE_OPEN if unlocked else STAGE_LOCKED
		item.label.add_theme_color_override("font_color", Style.INK if unlocked else Color("#cbd7da"))
		for index in range(3):
			item.stars[index].modulate = Color.WHITE if index < stars else Color(0.32, 0.41, 0.43, 0.48)
		item.next.visible = number == highest + 1
		item.boss.visible = number in state.get("boss_markers", [])
		if item.boss.visible:
			item.button.accessibility_name += " Bramble Boss encounter."
	_challenge.disabled = blocked
	_challenge.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	_wallet.text = "%d coins" % int(state.get("coins", 0))
	_status.text = str(state.get("error", "")) if not str(state.get("error", "")).is_empty() \
		else "Loading stage %d..." % int(state.get("pending_stage", 0)) if state.get("loading", false) else ""
	_status.add_theme_color_override("font_color", Style.WRONG if not str(state.get("error", "")).is_empty() else Style.INK)
	_retry.visible = not str(state.get("error", "")).is_empty()
	_status.visible = not _status.text.is_empty()
	if state.has("merged_level"):
		_subtitle.text = "Chase Bramble · Merged Lv%d" % int(state.merged_level)
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
	Style.square_icon_button(_home, Style.GOOD)
	_home.position = Vector2(left, top)
	_home.size = Vector2.ONE * ceilf(44.0 / s)
	_heading.position = Vector2(_home.get_rect().end.x + 14.0 / s, top)
	_heading.size = Vector2(maxf(1.0, left + width - _heading.position.x - (162.0 / s if not narrow else 0.0)), 44.0 / s)
	var heading_pixels: int = ceili((24.0 if narrow else 32.0) / s)
	var heading_ink: float = Style.HEADING_FONT.get_string_size(_heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_pixels).x
	if heading_ink > _heading.size.x:
		heading_pixels = maxi(1, floori(heading_pixels * _heading.size.x / heading_ink))
	_heading.add_theme_font_size_override("font_size", heading_pixels)
	_subtitle.position = Vector2(left, top + 48.0 / s)
	_subtitle.size = Vector2(width, 30.0 / s)
	_subtitle.text = "Chase Bramble · Merged Lv%d" % int(_state.merged_level) if _state.has("merged_level") \
		else "Collect words. Earn stars. Explore." if narrow else "99 little adventures. Collect words, earn stars."
	_subtitle.add_theme_font_size_override("font_size", ceili(14.0 / s))
	_wallet.visible = not narrow
	_wallet.position = Vector2(left + width - 150.0 / s, top)
	_wallet.size = Vector2(150, 38) / s
	_challenge.custom_minimum_size = Vector2.ZERO
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_challenge.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_challenge.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.GOOD, ceili(8.0 / s), ceili(2.0 / s)))
	_challenge.size = Vector2(minf(width, 312.0 / s), ceilf(78.0 / s))
	_challenge.position = Vector2((size.x - _challenge.size.x) * 0.5, size.y - _challenge.size.y - 14.0 / s)
	_challenge_frame.scale = Vector2.ONE / s
	_challenge_frame.size = _challenge.size * s
	_challenge_icon.position = Vector2(18, 17) / s
	_challenge_icon.size = Vector2.ONE * 44.0 / s
	_challenge_title.position = Vector2(76, 16) / s
	_challenge_title.size = Vector2(_challenge.size.x - 92.0 / s, 26.0 / s)
	_challenge_title.add_theme_font_size_override("font_size", ceili(17.0 / s))
	_challenge_caption.position = Vector2(76, 42) / s
	_challenge_caption.size = Vector2(_challenge.size.x - 92.0 / s, 20.0 / s)
	_challenge_caption.add_theme_font_size_override("font_size", ceili(12.0 / s))
	_refresh_challenge_frame()
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
	var node_size := Vector2(98, 104) / s
	var amplitude: float = minf(width * 0.27, 240.0 / s)
	for index in range(_chapters.size()):
		var section: Dictionary = _chapters[index]
		var y: float = (10 - index) * chapter_height
		section.number.position = Vector2(0, y + 1122.0 / s)
		section.number.size = Vector2(width, 20.0 / s)
		section.number.add_theme_font_size_override("font_size", ceili(11.0 / s))
		section.title.position = Vector2(0, y + 1080.0 / s)
		section.title.size = Vector2(width, 42.0 / s)
		section.title.add_theme_font_size_override("font_size", ceili((23.0 if narrow else 30.0) / s))
		var scenery_width: float = minf(width * 0.38, 270.0 / s)
		section.left.position = Vector2(8.0 / s, y + 760.0 / s)
		section.left.size = Vector2(scenery_width, 230.0 / s)
		section.left.modulate.a = 0.72
		section.right.position = Vector2(width - scenery_width - 8.0 / s, y + 250.0 / s)
		section.right.size = Vector2(scenery_width, 250.0 / s)
		section.right.modulate.a = 0.82
		section.hills.position = Vector2(0, y + 70.0 / s)
		section.hills.size = Vector2(width, 260.0 / s)
		section.shrubs.position = Vector2(12.0 / s, y + 55.0 / s)
		section.shrubs.size = Vector2(width * 0.35, 75.0 / s)
		section.grove.position = Vector2(width * 0.70, y + 510.0 / s)
		section.grove.size = Vector2(minf(width * 0.25, 170.0 / s), 210.0 / s)
		section.grove.modulate = Color(0.9, 1.0, 0.96, 0.50)
	for item: Dictionary in _nodes:
		var number: int = int(item.number)
		var chapter: int = (number - 1) / 9
		var step: int = (number - 1) % 9
		var center := Vector2(width * 0.5 + sin(float(step) * PI * 0.5) * amplitude,
			(11 - chapter) * chapter_height - (136.0 + step * 116.0) / s)
		var button: Button = item.button
		button.position = center - node_size * 0.5
		button.size = node_size
		item.face.position = Vector2(11, 0) / s
		item.face.size = Vector2.ONE * 76.0 / s
		item.label.position = item.face.position
		item.label.size = item.face.size
		item.label.add_theme_font_size_override("font_size", ceili(30.0 / s))
		item.next.position = Vector2(79, 31) / s
		item.next.size = Vector2.ONE * 14.0 / s
		item.boss.add_theme_font_size_override("font_size", ceili(11.0 / s))
		item.boss.position = Vector2(15, -22) / s
		item.boss.size = Vector2(68, 20) / s
		for index in range(3):
			var star: TextureRect = item.stars[index]
			star.position = Vector2((14.0 + index * 24.0) / s, 80.0 / s)
			star.size = Vector2.ONE * 22.0 / s
	_content.custom_minimum_size = Vector2(0.0, chapter_height * 11.0)
	_content.size.x = width
	_content.queue_redraw()
	_queue_changed()


func _draw_route() -> void:
	if _nodes.is_empty():
		return
	var curve := Curve2D.new()
	for index in range(_nodes.size()):
		var center: Vector2 = _nodes[index].button.get_rect().get_center()
		curve.add_point(center, Vector2(0, 40.0 / _scale), Vector2(0, -40.0 / _scale))
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
			"boss": item.boss.visible,
			"rect": _rect(item.button.get_global_rect()),
			"visible": is_visible_in_tree() and _scroll.get_global_rect().intersects(item.button.get_global_rect())})
	return {"visible": is_visible_in_tree(), "map_rect": _rect(get_global_rect()),
		"heading_rect": _rect(_heading.get_global_rect()),
		"scroll_rect": _rect(_scroll.get_global_rect()), "scroll_offset": _scroll.scroll_vertical,
		"stage_nodes": stages, "challenge": _control(_challenge), "home": _control(_home),
		"retry": _control(_retry), "loading": bool(_state.get("loading", false)),
		"error": str(_state.get("error", "")),
		"merged_level": int(_state.get("merged_level", 1)),
		"boss_markers": _state.get("boss_markers", []).duplicate(),
		"boss_victories": _state.get("boss_victories", []).duplicate()}

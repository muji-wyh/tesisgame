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
const LevelBadge = preload("res://scripts/word_jelly_level_badge.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const Rating = preload("res://scripts/word_jelly_stage_banner.gd")
const SKY = preload("res://assets/images/jelly-match/sky/day.png")
const STAGE_OPEN = preload("res://assets/images/ui/jelly-map/stage-open.png")
const STAGE_LOCKED = preload("res://assets/images/ui/jelly-map/stage-locked.png")
const MEDAL = preload("res://assets/images/ui/mastery-medal.webp")
const PLAY = preload("res://assets/images/ui/controls/player-play.svg")
const LOCK = preload("res://assets/images/ui/controls/lock.svg")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const ROUTE_SECONDS: float = 0.85
const UNLOCK_SECONDS: float = 0.65
const BOSS_PORTRAIT = preload("res://assets/jelly-boss/private/bramble-portrait.png")
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
var _merged_level_badge := LevelBadge.new()
var _status: Label
var _home: Button
var _challenge: Button
var _retry: Button
var _nodes: Array[Dictionary] = []
var _chapters: Array[Dictionary] = []
var _scale: float = 1.0
var _publish_pending: bool = false
var _reduced_motion: bool = false
var _active: bool = true
var _effect_elapsed: float = 0.0
var _unlock_from: int = 0
var _unlock_elapsed: float = ROUTE_SECONDS + UNLOCK_SECONDS


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
	add_child(_merged_level_badge)
	_home = Icons.new()
	_home.set("symbol", Icons.Symbol.HOME)
	_home.accessibility_name = "Home. Back to game library"
	_home.tooltip_text = "Home"
	add_child(_home)
	_home.pressed.connect(func() -> void: home_requested.emit())
	_challenge = Button.new()
	_challenge.text = "Challenge"
	_challenge.icon = MEDAL
	_challenge.expand_icon = true
	_challenge.accessibility_name = "Survival Challenge. 90 seconds. Collect words for a chance of extra time."
	add_child(_challenge)
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
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_select.bind(number))
		_content.add_child(button)
		button.focus_entered.connect(_reveal_stage.bind(number))
		var face: TextureRect = _image(button, STAGE_OPEN)
		var label: Label = _label(button, str(number), 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rating := Panel.new()
		rating.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(rating)
		var stars: Array[TextureRect] = []
		for index in range(3):
			stars.append(_image(button, Rating.STAR_TEXTURES[index]))
		var next: TextureRect = _image(button, PLAY)
		next.modulate = Style.GOOD
		var next_label: Label = _label(button, "Play", 12)
		var lock_glow: TextureRect = _image(button, GLOW)
		lock_glow.modulate = Color(0.73, 0.86, 1.0, 0.24)
		var padlock: TextureRect = _image(button, LOCK)
		var boss_frame: TextureRect = _image(_content, STAGE_LOCKED)
		boss_frame.modulate = Color("#71508d")
		boss_frame.visible = number == 99
		var boss_aura: TextureRect = _image(_content, RAYS)
		boss_aura.modulate = Color(0.38, 0.16, 0.56, 0.74)
		boss_aura.visible = number == 99
		var boss_picture := TextureButton.new()
		boss_picture.name = "BossPortrait%d" % number
		boss_picture.texture_normal = BOSS_PORTRAIT
		boss_picture.texture_disabled = BOSS_PORTRAIT
		boss_picture.ignore_texture_size = true
		boss_picture.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		boss_picture.focus_mode = Control.FOCUS_NONE
		boss_picture.pressed.connect(_select.bind(number))
		_content.add_child(boss_picture)
		boss_picture.hide()
		_nodes.append({"number": number, "button": button, "face": face, "label": label,
			"stars": stars, "rating": rating, "next": next, "next_label": next_label,
			"boss": boss_picture, "boss_frame": boss_frame, "boss_aura": boss_aura,
			"padlock": padlock, "lock_glow": lock_glow})
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_scroll.cancel_drag()
		set_process(is_visible_in_tree() and _active and not _reduced_motion))
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


func _queue_changed() -> void:
	if _publish_pending or not is_inside_tree():
		return
	_publish_pending = true
	_publish_changed.call_deferred()


func _publish_changed() -> void:
	_publish_pending = false
	if is_visible_in_tree():
		changed.emit()


func configure(state: Dictionary, reduced_motion: bool = false) -> void:
	var previous: int = int(_state.get("highest_cleared", -1))
	var highest: int = clampi(int(state.get("highest_cleared", 0)), 0, 99)
	_reduced_motion = reduced_motion
	if previous >= 0 and highest == previous + 1 and highest < 99 \
		and _state.get("context_key", "") == state.get("context_key", ""):
		_unlock_from = highest
		_unlock_elapsed = ROUTE_SECONDS + UNLOCK_SECONDS if reduced_motion else 0.0
	elif highest != previous:
		_unlock_from = 0
		_unlock_elapsed = ROUTE_SECONDS + UNLOCK_SECONDS
	if reduced_motion:
		_unlock_elapsed = ROUTE_SECONDS + UNLOCK_SECONDS
	_state = state.duplicate(true)
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
			item.stars[index].visible = number <= highest
			item.stars[index].modulate = Color.WHITE if index < stars else Color(0.57, 0.49, 0.36, 0.28)
		item.next.visible = number == highest + 1
		item.next_label.visible = item.next.visible
		item.rating.visible = number <= mini(highest + 1, 99)
		item.boss.visible = number == 99 or number > 1 and number in state.get("boss_markers", [])
		item.boss.disabled = item.button.disabled
		if item.boss.visible:
			item.button.accessibility_name += " Bramble Boss encounter."
			item.boss.accessibility_name = item.button.accessibility_name
			item.boss.tooltip_text = "Bramble. Boss in stage %d" % number
	_challenge.disabled = blocked
	_challenge.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	_wallet.text = "%d coins" % int(state.get("coins", 0))
	_status.text = str(state.get("error", "")) if not str(state.get("error", "")).is_empty() \
		else "Loading stage %d..." % int(state.get("pending_stage", 0)) if state.get("loading", false) else ""
	_status.add_theme_color_override("font_color", Style.WRONG if not str(state.get("error", "")).is_empty() else Style.INK)
	_retry.visible = not str(state.get("error", "")).is_empty()
	_status.visible = not _status.text.is_empty()
	_refresh_locks()
	set_process(is_visible_in_tree() and _active and not _reduced_motion)
	_layout()


func open(state: Dictionary, reduced_motion: bool = false) -> void:
	configure(state, reduced_motion)
	show()
	_layout()
	focus_frontier.call_deferred()


func close() -> void:
	_scroll.cancel_drag()
	_unlock_elapsed = ROUTE_SECONDS + UNLOCK_SECONDS
	_refresh_locks()
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
	if number == 99:
		_scroll.scroll_vertical = mini(_scroll.scroll_vertical,
			maxi(0, floori(_nodes[98].boss_frame.position.y - 8.0 / _scale)))


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
	Style.action_button(_challenge, Style.GOOD)
	_challenge.custom_minimum_size = Vector2.ZERO
	_challenge.add_theme_font_size_override("font_size", ceili(14.0 / s))
	_challenge.add_theme_constant_override("icon_max_width", ceili(24.0 / s))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var surface: StyleBox = _challenge.get_theme_stylebox(state)
		surface.content_margin_left = 8.0 / s
		surface.content_margin_right = 8.0 / s
		surface.content_margin_top = 6.0 / s
		surface.content_margin_bottom = 6.0 / s
	_challenge.position = Vector2(left + width - 132.0 / s, top)
	_challenge.size = Vector2(ceilf(132.0 / s), ceilf(44.0 / s))
	_wallet.visible = not narrow
	_wallet.position = Vector2(_challenge.position.x - 162.0 / s, top)
	_wallet.size = Vector2(150, 38) / s
	_wallet.add_theme_font_size_override("font_size", ceili(16.0 / s))
	_wallet.size = Vector2(150, 38) / s
	_heading.position = Vector2(_home.get_rect().end.x + 14.0 / s, top)
	var title_end: float = (_wallet.position.x if not narrow else _challenge.position.x) - 12.0 / s
	var title_width: float = maxf(1.0, title_end - _heading.position.x)
	_heading.size = Vector2(title_width, 44.0 / s)
	var heading_pixels: int = ceili((24.0 if narrow else 32.0) / s)
	var heading_ink: float = Style.HEADING_FONT.get_string_size(_heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_pixels).x
	if heading_ink > title_width:
		heading_pixels = maxi(1, floori(heading_pixels * title_width / heading_ink))
	_heading.add_theme_font_size_override("font_size", heading_pixels)
	_heading.size = Vector2(title_width, 44.0 / s)
	_subtitle.position = Vector2(left, top + 48.0 / s)
	var level_width: float = minf(width * 0.48, 142.0 / s)
	_subtitle.size = Vector2(width - level_width - 8.0 / s, 30.0 / s)
	_merged_level_badge.set_level(int(_state.get("merged_level", 1)))
	_merged_level_badge.layout_badge(Rect2(Vector2(left + width - level_width, top + 48.0 / s),
		Vector2(level_width, 28.0 / s)), s)
	_subtitle.text = ("Collect words" if int(_state.get("highest_cleared", 0)) == 0 else "Chase Bramble") if _state.has("merged_level") \
		else "Collect words. Earn stars. Explore." if narrow else "99 little adventures. Collect words, earn stars."
	var highest: int = int(_state.get("highest_cleared", 0))
	var target: int = BossCatalog.chase_target(highest)
	if highest > 0 and target > 0:
		var first_win: bool = BossCatalog.STAGES.find(target) + 1 not in _state.get("boss_victories", [])
		_subtitle.text = "Bramble: Stage %d" % target if narrow \
			else "Catch Bramble at Stage %d · Win: Jelly Lv%d" % [
				target, mini(9, int(_state.get("merged_level", 1)) + 1)] if first_win \
			else "Catch Bramble at Stage %d · Follow the compass" % target
	elif highest == 99:
		_subtitle.text = "Compass recovered!" if 8 in _state.get("boss_victories", []) \
			else "99 adventures complete"
	_subtitle.add_theme_font_size_override("font_size", ceili(14.0 / s))
	var status_height: float = 76.0 / s if _status.visible else 0.0
	_status.position = Vector2(left, 90.0 / s)
	_status.size = Vector2(width - (84.0 / s if _retry.visible else 0.0), status_height)
	_status.add_theme_font_size_override("font_size", ceili(14.0 / s))
	_retry.position = Vector2(left + width - 78.0 / s, 98.0 / s)
	_retry.size = Vector2(78, 44) / s
	_content.custom_minimum_size.x = 0.0
	_scroll.position = Vector2(left, 88.0 / s + status_height)
	_scroll.size = Vector2(width, maxf(1.0, size.y - _scroll.position.y - 12.0 / s))
	var chapter_height: float = 1160.0 / s
	var summit_space: float = 132.0 / s
	var node_size := Vector2(98, 104) / s
	var amplitude: float = minf(width * 0.27, 240.0 / s)
	for index in range(_chapters.size()):
		var section: Dictionary = _chapters[index]
		var y: float = summit_space + (10 - index) * chapter_height
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
			summit_space + (11 - chapter) * chapter_height - (136.0 + step * 116.0) / s)
		var button: Button = item.button
		button.position = center - node_size * 0.5
		button.size = node_size
		item.face.position = Vector2(11, 0) / s
		item.face.size = Vector2.ONE * 76.0 / s
		item.face.pivot_offset = item.face.size * 0.5
		var focus := Style.box(Color.TRANSPARENT, Color("#fff0bd"), ceili(39.0 / s), maxi(1, roundi(2.0 / s)))
		focus.expand_margin_left = -10.0 / s
		focus.expand_margin_right = -10.0 / s
		focus.expand_margin_top = 1.0 / s
		focus.expand_margin_bottom = -27.0 / s
		button.add_theme_stylebox_override("focus", focus)
		item.label.position = item.face.position
		item.label.size = item.face.size
		item.label.add_theme_font_size_override("font_size", ceili(30.0 / s))
		item.rating.position = Vector2(8, 78) / s
		item.rating.size = Vector2(82, 24) / s
		item.rating.add_theme_stylebox_override("panel",
			Style.box(Color("#fff8e6"), Color("#dfcba2"), ceili(12.0 / s), maxi(1, roundi(1.0 / s))))
		item.next.position = Vector2(24, 83) / s
		item.next.size = Vector2.ONE * 14.0 / s
		item.next_label.position = Vector2(43, 78) / s
		item.next_label.size = Vector2(37, 24) / s
		item.next_label.add_theme_font_size_override("font_size", ceili(12.0 / s))
		item.next_label.add_theme_color_override("font_color", Style.GOOD)
		item.lock_glow.position = Vector2(56, 43) / s
		item.lock_glow.size = Vector2.ONE * 36.0 / s
		item.padlock.position = Vector2(65, 52) / s
		item.padlock.size = Vector2.ONE * 19.0 / s
		item.padlock.pivot_offset = item.padlock.size * 0.5
		item.boss.position = button.position + (Vector2(-13, -124) if number == 99 else Vector2(15, -68)) / s
		item.boss.size = Vector2.ONE * (124.0 if number == 99 else 68.0) / s
		item.boss_aura.position = item.boss.position - Vector2.ONE * 16.0 / s
		item.boss_aura.size = item.boss.size + Vector2.ONE * 32.0 / s
		item.boss_frame.position = item.boss.position - Vector2.ONE * 18.0 / s
		item.boss_frame.size = item.boss.size + Vector2.ONE * 36.0 / s
		for index in range(3):
			var star: TextureRect = item.stars[index]
			star.position = Vector2((14.0 + index * 24.0) / s, 79.0 / s)
			star.size = Vector2.ONE * 22.0 / s
	_content.custom_minimum_size = Vector2(0.0, summit_space + chapter_height * 11.0)
	_content.size.x = width
	_content.queue_redraw()
	_queue_changed()


func _process(delta: float) -> void:
	if not _active or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	_effect_elapsed += delta
	var unlocking: bool = _unlock_elapsed < ROUTE_SECONDS + UNLOCK_SECONDS
	if unlocking:
		_unlock_elapsed = minf(ROUTE_SECONDS + UNLOCK_SECONDS, _unlock_elapsed + delta)
	_refresh_locks(true)
	if unlocking:
		_content.queue_redraw()
		_queue_changed()


func set_active(active: bool) -> void:
	_active = active
	set_process(is_visible_in_tree() and active and not _reduced_motion)
	if not active:
		_scroll.cancel_drag()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		set_active(false)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		set_active(true)


func _refresh_locks(visible_only: bool = false) -> void:
	var highest: int = clampi(int(_state.get("highest_cleared", 0)), 0, 99)
	for item: Dictionary in _nodes:
		var number: int = int(item.number)
		var arriving: bool = _unlock_from > 0 and number == _unlock_from + 1
		if visible_only and not arriving and not _scroll.get_global_rect().intersects(item.button.get_global_rect()):
			continue
		var p: float = clampf((_unlock_elapsed - ROUTE_SECONDS) / UNLOCK_SECONDS, 0.0, 1.0) if arriving else 1.0
		var locked: bool = number > mini(highest + 1, 99)
		item.face.texture = STAGE_LOCKED if locked or (arriving and p <= 0.0) else STAGE_OPEN
		item.face.scale = Vector2.ONE * (1.0 + 0.12 * sin(p * PI) if arriving and not _reduced_motion else 1.0)
		item.padlock.visible = locked or (arriving and p < 1.0)
		item.lock_glow.visible = item.padlock.visible
		item.padlock.modulate = Color(0.89, 0.95, 1.0, 1.0 if locked else 1.0 - p)
		item.padlock.scale = Vector2.ONE * (1.0 + 0.45 * p if arriving and not locked else 1.0)
		item.padlock.rotation = sin(p * TAU * 2.0) * 0.22 * (1.0 - p) if arriving and not _reduced_motion else 0.0
		item.lock_glow.modulate.a = (0.22 if _reduced_motion else 0.22 + 0.09 * sin(_effect_elapsed * 1.8 + number)) \
			* (1.0 if locked else 1.0 - p)


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
	if _unlock_from <= 0 or _unlock_elapsed >= ROUTE_SECONDS + UNLOCK_SECONDS:
		return
	var journey := Curve2D.new()
	journey.add_point(_nodes[_unlock_from - 1].button.get_rect().get_center(),
		Vector2.ZERO, Vector2(0, -40.0 / _scale))
	journey.add_point(_nodes[_unlock_from].button.get_rect().get_center(),
		Vector2(0, 40.0 / _scale), Vector2.ZERO)
	var travel: float = clampf(_unlock_elapsed / ROUTE_SECONDS, 0.0, 1.0)
	var trail := PackedVector2Array()
	for index in range(33):
		trail.append(journey.sample_baked(journey.get_baked_length() * travel * index / 32.0))
	_content.draw_polyline(trail, Color(1.0, 0.78, 0.25, 0.28), 24.0 / _scale, true)
	_content.draw_polyline(trail, Color("#ffe69b"), 12.0 / _scale, true)
	var head: Vector2 = trail[trail.size() - 1]
	var edge: float = 52.0 / _scale
	_content.draw_texture_rect(GLOW, Rect2(head - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
		false, Color(1.0, 0.85, 0.4, 0.8))
	_content.draw_texture_rect(SPARKLE, Rect2(head - Vector2.ONE * edge * 0.22, Vector2.ONE * edge * 0.44),
		false, Color("#fff4c4"))
	if _unlock_elapsed > ROUTE_SECONDS:
		var p: float = (_unlock_elapsed - ROUTE_SECONDS) / UNLOCK_SECONDS
		_content.draw_texture_rect(RAYS, Rect2(head - Vector2.ONE * edge, Vector2.ONE * edge * 2),
			false, Color(1.0, 0.85, 0.45, 1.0 - p))
		for index in range(8):
			var at: Vector2 = head + Vector2.from_angle(TAU * index / 8.0) * (18.0 + p * 54.0) / _scale
			_content.draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * 6.0 / _scale, Vector2.ONE * 12.0 / _scale),
				false, Color(1.0, 0.87, 0.45, 1.0 - p))


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
			"lock_visible": item.padlock.visible,
			"best_stars": int(_state.get("best_stars", {}).get(str(number), 0)),
			"boss": item.boss.visible,
			"final_boss": number == 99,
			"boss_rect": _rect(item.boss.get_global_rect()) if item.boss.visible else {},
			"boss_portrait": BOSS_PORTRAIT.resource_path if item.boss.visible else "",
			"rect": _rect(item.button.get_global_rect()),
			"visible": is_visible_in_tree() and _scroll.get_global_rect().intersects(item.button.get_global_rect())})
	return {"visible": is_visible_in_tree(), "map_rect": _rect(get_global_rect()),
		"heading_rect": _rect(_heading.get_global_rect()),
		"scroll_rect": _rect(_scroll.get_global_rect()), "scroll_offset": _scroll.scroll_vertical,
		"stage_nodes": stages, "challenge": _control(_challenge), "home": _control(_home),
		"retry": _control(_retry), "loading": bool(_state.get("loading", false)),
		"unlock": {"from": _unlock_from, "to": _unlock_from + 1 if _unlock_from > 0 else 0,
			"elapsed": _unlock_elapsed, "phase": "route" if _unlock_elapsed < ROUTE_SECONDS \
				else "node" if _unlock_elapsed < ROUTE_SECONDS + UNLOCK_SECONDS else "done"},
		"error": str(_state.get("error", "")),
		"merged_level": int(_state.get("merged_level", 1)),
		"final_boss_stage": 99,
		"merged_level_indicator": _merged_level_badge.snapshot(),
		"boss_markers": _state.get("boss_markers", []).filter(func(number: int) -> bool: return number > 1),
		"boss_victories": _state.get("boss_victories", []).duplicate()}

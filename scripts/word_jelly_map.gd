extends Control
## An inert scenic route; the campaign coordinator owns progress and rewards.

signal stage_selected(number: int)
signal challenge_selected
signal home_requested
signal retry_requested
signal upgrades_requested
signal changed

const Style = preload("res://scripts/ui_style.gd")
const Scroll = preload("res://scripts/result_scroll.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Icons = preload("res://scripts/icon_button.gd")
const LevelBadge = preload("res://scripts/word_jelly_level_badge.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const Rating = preload("res://scripts/word_jelly_stage_banner.gd")
const Pip = preload("res://scripts/word_jelly_map_pip.gd")
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
const STAGES_PER_CHAPTER: int = 9
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
var _upgrades := Button.new()
var _upgrade_label: Label
var _status: Label
var _home: Button
var _challenge: Button
var _retry: Button
var _chapter_index: int = 0
var _pip := Pip.new()
var _nodes: Array[Dictionary] = []
var _chapters: Array[Dictionary] = []
var _scale: float = 1.0
var _publish_pending: bool = false
var _reduced_motion: bool = false
var _active: bool = true
var _effect_elapsed: float = 0.0
var _unlock_from: int = 0
var _unlock_elapsed: float = ROUTE_SECONDS + UNLOCK_SECONDS
var _hovered_stage: int = 0
var _pressed_stage: int = 0
var _route_points := PackedVector2Array()
var _earned_points := PackedVector2Array()


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
	_upgrades.name = "JellyUpgrades"
	_upgrades.tooltip_text = "Upgrade Jelly powers and Auto merge capacity with saved coins"
	add_child(_upgrades)
	_upgrades.add_child(_merged_level_badge)
	_upgrade_label = _label(_upgrades, "Upgrade", 13)
	_upgrade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrades.pressed.connect(func() -> void:
		if _active and not _upgrades.disabled:
			upgrades_requested.emit())
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
	_scroll.interaction_allowed = func() -> bool:
		return _active and is_visible_in_tree() and not bool(_state.get("loading", false))
	_scroll.held_button_changed.connect(func(button: Button) -> void:
		_set_pressed(int(button.get_meta("map_stage", 0)) if is_instance_valid(button) else 0))
	add_child(_scroll)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.draw.connect(_draw_route)
	for chapter in range(11):
		var banner := Panel.new()
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(banner)
		var title: Label = _label(banner, Catalog.CHAPTERS[chapter], 27)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var number: Label = _label(banner, "CHAPTER %02d" % (chapter + 1), 11)
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
		_chapters.append({"banner": banner, "title": title, "number": number, "left": left, "right": right,
			"hills": hills, "shrubs": shrubs, "grove": grove})
	for number in range(1, 100):
		var button := Button.new()
		button.name = "Stage%d" % number
		button.z_index = 1
		button.set_meta("map_stage", number)
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
		button.focus_entered.connect(func() -> void:
			if number == int(_state.get("highest_cleared", 0)) + 1 and _active:
				_pip.react("curious"))
		button.focus_entered.connect(_sync_guide)
		button.focus_exited.connect(_sync_guide)
		button.mouse_entered.connect(_hover_stage.bind(number))
		button.mouse_exited.connect(func() -> void:
			if _hovered_stage == number:
				_hover_stage(0))
		button.button_down.connect(_set_pressed.bind(number))
		button.button_up.connect(_set_pressed.bind(0))
		var halo: TextureRect = _image(button, GLOW)
		var face: TextureRect = _image(button, STAGE_OPEN)
		var glint: TextureRect = _image(button, SPARKLE)
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
		boss_picture.z_index = 1
		boss_picture.texture_normal = BOSS_PORTRAIT
		boss_picture.texture_disabled = BOSS_PORTRAIT
		boss_picture.ignore_texture_size = true
		boss_picture.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		boss_picture.focus_mode = Control.FOCUS_NONE
		boss_picture.pressed.connect(_select.bind(number))
		_content.add_child(boss_picture)
		boss_picture.hide()
		_nodes.append({"number": number, "button": button, "face": face, "label": label,
			"halo": halo, "glint": glint, "hover": 0.0, "face_rest": Vector2.ZERO,
			"stars": stars, "rating": rating, "next": next, "next_label": next_label,
			"boss": boss_picture, "boss_frame": boss_frame, "boss_aura": boss_aura,
			"padlock": padlock, "lock_glow": lock_glow})
	_pip.name = "MapPip"
	_pip.accessibility_name = "Pip. Your journey companion."
	_pip.disabled = true
	_pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pip.focus_mode = Control.FOCUS_NONE
	_pip.set_idle_paused(true)
	_content.add_child(_pip)
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_scroll.cancel_drag()
			_clear_response()
		set_process(is_visible_in_tree() and _active and not _reduced_motion))
	visibility_changed.connect(_sync_guide)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:
		queue_redraw()
		_clear_response()
		_refresh_viewport.call_deferred()
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
	var same_context: bool = _state.get("context_key", "") == state.get("context_key", "")
	if previous != highest or not same_context:
		_scroll.cancel_drag()
		_clear_response()
		_chapter_index = mini(highest, 98) / STAGES_PER_CHAPTER
	_reduced_motion = reduced_motion
	if previous >= 0 and highest == previous + 1 and highest < 99 \
		and same_context:
		_unlock_from = highest
		_unlock_elapsed = ROUTE_SECONDS + UNLOCK_SECONDS if reduced_motion else 0.0
	elif highest != previous or not same_context:
		_unlock_from = 0
		_unlock_elapsed = ROUTE_SECONDS + UNLOCK_SECONDS
	if reduced_motion:
		_unlock_elapsed = ROUTE_SECONDS + UNLOCK_SECONDS
	_state = state.duplicate(true)
	_pip.set_growth_age(int(state.get("pip_age", 0)))
	_pip.set_professional_profile(state.get("pip_profile", {}))
	_pip.set_reduced_motion(reduced_motion)
	_pip.set_proactive_allowed(false)
	var blocked: bool = bool(state.get("loading", false)) or not str(state.get("error", "")).is_empty()
	if blocked:
		_scroll.cancel_drag()
		_clear_response()
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
		item["boss_marker"] = number == 99 or number > 1 and number in state.get("boss_markers", [])
		item.boss.visible = bool(item.boss_marker)
		item.boss.disabled = item.button.disabled
		if item.boss.visible:
			item.button.accessibility_name += " Bramble Boss encounter."
			item.boss.accessibility_name = item.button.accessibility_name
			item.boss.tooltip_text = "Bramble. Boss in stage %d" % number
	_challenge.disabled = blocked
	_challenge.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	_upgrades.disabled = blocked
	_upgrades.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	_upgrades.accessibility_name = "Jelly Lv%d. Auto merge Lv%d. Open permanent upgrades. Higher levels cost coins." % [
		int(state.get("merged_level", 1)), int(state.get("auto_merge_level", 1))]
	_wallet.text = "%d coins" % int(state.get("coins", 0))
	_status.text = str(state.get("error", "")) if not str(state.get("error", "")).is_empty() \
		else "Loading stage %d..." % int(state.get("pending_stage", 0)) if state.get("loading", false) else ""
	_status.add_theme_color_override("font_color", Style.WRONG if not str(state.get("error", "")).is_empty() else Style.INK)
	_retry.visible = not str(state.get("error", "")).is_empty()
	_status.visible = not _status.text.is_empty()
	_refresh_locks()
	set_process(is_visible_in_tree() and _active and not _reduced_motion)
	_layout()
	if is_visible_in_tree() and previous >= 0 and (previous != highest or not same_context):
		focus_frontier.call_deferred()


func set_reduced_motion(value: bool) -> void:
	if value != _reduced_motion:
		configure(_state, value)


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


func _hover_stage(number: int) -> void:
	_hovered_stage = number if number > 0 and not _nodes[number - 1].button.disabled \
		and _nodes[number - 1].button.is_visible_in_tree() and _active else 0
	_pose_nodes()
	_sync_guide()
	_queue_changed()


func _set_pressed(number: int) -> void:
	if number == _pressed_stage:
		return
	_pressed_stage = number if number > 0 and _active and is_visible_in_tree() else 0
	_pose_nodes()
	_sync_guide()
	_queue_changed()


func _clear_response() -> void:
	_hovered_stage = 0
	_pressed_stage = 0
	for item: Dictionary in _nodes:
		item.hover = 0.0
	_pose_nodes()
	_sync_guide()


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
	if number < 1 or number > Catalog.MAX_STAGE or not _active or not is_visible_in_tree():
		return
	if _nodes[number - 1].button.disabled or not _nodes[number - 1].button.is_visible_in_tree():
		return
	var item: Dictionary = _nodes[number - 1]
	var viewport: Rect2 = _scroll.get_global_rect()
	if not viewport.intersects(item.button.get_global_rect()) \
		and not (item.boss.is_visible_in_tree() and viewport.intersects(item.boss.get_global_rect())):
		return
	stage_selected.emit(number)


func show_chapter(number: int) -> bool:
	if number < 1 or number > Catalog.CHAPTERS.size() or not _active or not is_visible_in_tree() \
		or _state.get("loading", false) or not str(_state.get("error", "")).is_empty():
		return false
	_scroll.cancel_drag()
	_clear_response()
	var frontier: int = mini(clampi(int(_state.get("highest_cleared", 0)), 0, 99) + 1, 99)
	var first: int = (number - 1) * STAGES_PER_CHAPTER + 1
	var anchor: int = frontier if frontier >= first and frontier < first + STAGES_PER_CHAPTER else first
	_reveal_stage(anchor)
	return true


func _reveal_stage(number: int) -> void:
	if number < 1 or number > Catalog.MAX_STAGE or not is_visible_in_tree():
		return
	_scroll.cancel_drag()
	var button: Button = _nodes[number - 1].button
	_scroll.ensure_control_visible(button)
	var maximum: float = _scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page
	_scroll.scroll_vertical = roundi(clampf(button.position.y - (_scroll.size.y - button.size.y) * 0.45, 0.0, maximum))
	if number == 99 and _nodes[98].boss_frame.get_rect().merge(button.get_rect()).size.y + 8.0 / _scale <= _scroll.size.y:
		var portrait_top: int = maxi(0, floori(_nodes[98].boss_frame.position.y - 8.0 / _scale))
		var button_bottom: int = maxi(0, ceili(button.get_rect().end.y - _scroll.size.y))
		_scroll.scroll_vertical = maxi(button_bottom, mini(_scroll.scroll_vertical, portrait_top))
	var focus_bounds: Rect2 = button.get_rect()
	if number == int(_state.get("highest_cleared", 0)) + 1:
		focus_bounds = focus_bounds.merge(_pip.get_rect())
	if _nodes[number - 1].boss.visible:
		focus_bounds = focus_bounds.merge(_nodes[number - 1].boss.get_rect())
	for section: Dictionary in _chapters:
		var banner: Rect2 = section.banner.get_rect()
		if banner.position.y < _scroll.scroll_vertical and banner.end.y > _scroll.scroll_vertical:
			var aligned: int = ceili(banner.end.y + 4.0 / _scale)
			if aligned <= maximum and focus_bounds.position.y >= aligned \
				and focus_bounds.end.y <= aligned + _scroll.size.y:
				_scroll.scroll_vertical = aligned
	_refresh_viewport()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		if not _state.get("loading", false) and str(_state.get("error", "")).is_empty():
			_scroll.cancel_drag()
			_clear_response()
			_scroll.scroll_vertical += roundi(_scroll.size.y * (0.85 if event.keycode == KEY_PAGEDOWN else -0.85))
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventJoypadButton or event.button_index != JOY_BUTTON_A:
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
	if not _upgrades.disabled:
		controls.append(_upgrades)
	if not _challenge.disabled:
		controls.append(_challenge)
	if _retry.visible:
		controls.append(_retry)
	for item: Dictionary in _nodes:
		if item.button.is_visible_in_tree() and not item.button.disabled:
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
	var level_width: float = minf(width * 0.55, 180.0 / s)
	_subtitle.size = Vector2(width - level_width - 8.0 / s, 44.0 / s)
	_merged_level_badge.set_level(int(_state.get("merged_level", 1)))
	_upgrades.position = Vector2(left + width - level_width, top + 48.0 / s)
	_upgrades.size = Vector2(level_width, 44.0 / s)
	Style.action_button(_upgrades, Style.GOOD)
	_merged_level_badge.layout_badge(Rect2(Vector2(4, 8) / s, Vector2(108, 28) / s), s)
	_upgrade_label.position = Vector2(116.0 / s, 0)
	_upgrade_label.size = Vector2(maxf(1.0, level_width - 120.0 / s), 44.0 / s)
	_upgrade_label.add_theme_font_size_override("font_size", ceili(13.0 / s))
	_subtitle.text = ("Collect words" if int(_state.get("highest_cleared", 0)) == 0 else "Chase Bramble") if _state.has("merged_level") \
		else "Collect words. Earn stars. Explore." if narrow else "99 little adventures. Collect words, earn stars."
	var highest: int = int(_state.get("highest_cleared", 0))
	var target: int = BossCatalog.chase_target(highest)
	if highest > 0 and target > 0:
		_subtitle.text = "Bramble: Stage %d" % target if narrow \
			else "Catch Bramble at Stage %d · Follow the compass" % target
	elif highest == 99:
		_subtitle.text = "Compass recovered!" if 8 in _state.get("boss_victories", []) \
			else "99 adventures complete"
	_subtitle.add_theme_font_size_override("font_size", ceili(14.0 / s))
	var status_height: float = 76.0 / s if _status.visible else 0.0
	_status.position = Vector2(left, 106.0 / s)
	_status.size = Vector2(width - (84.0 / s if _retry.visible else 0.0), status_height)
	_status.add_theme_font_size_override("font_size", ceili(14.0 / s))
	_retry.position = Vector2(left + width - 78.0 / s, 114.0 / s)
	_retry.size = Vector2(78, 44) / s
	_content.custom_minimum_size.x = 0.0
	_scroll.position = Vector2(left, 104.0 / s + status_height)
	_scroll.size = Vector2(width, maxf(1.0, size.y - _scroll.position.y - 12.0 / s))
	var chapter_height: float = 1160.0 / s
	var summit_space: float = 132.0 / s
	var node_size := Vector2(98, 104) / s
	var amplitude: float = minf(width * 0.27, 240.0 / s)
	for index in range(_chapters.size()):
		var section: Dictionary = _chapters[index]
		var y: float = summit_space + (_chapters.size() - 1 - index) * chapter_height
		var banner_width: float = minf(width - 16.0 / s, 340.0 / s)
		section.banner.position = Vector2((width - banner_width) * 0.5,
			y + chapter_height - 74.0 / s)
		section.banner.size = Vector2(banner_width, 44.0 / s)
		section.banner.add_theme_stylebox_override("panel",
			Style.box(Color("#fffaf0"), Color("#d5e4db"), ceili(16.0 / s), maxi(1, roundi(1.0 / s))))
		var chapter_title_width: float = banner_width - 24.0 / s
		section.number.text = "CHAPTER %02d / 11 · %d-%d" % [
			index + 1, index * STAGES_PER_CHAPTER + 1, (index + 1) * STAGES_PER_CHAPTER]
		section.number.position = Vector2(12, 25) / s
		section.number.size = Vector2(chapter_title_width, 18.0 / s)
		section.number.add_theme_font_size_override("font_size", ceili(11.0 / s))
		section.title.position = Vector2(12, 1) / s
		section.title.size = Vector2(chapter_title_width, 24.0 / s)
		var pixels: int = ceili((18.0 if narrow else 20.0) / s)
		while pixels > 1 and Style.HEADING_FONT.get_string_size(section.title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > chapter_title_width:
			pixels -= 1
		section.title.add_theme_font_size_override("font_size", pixels)
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
		for key: String in ["left", "right", "grove", "shrubs"]:
			section[key].pivot_offset = Vector2(section[key].size.x * 0.5, section[key].size.y)
	for item: Dictionary in _nodes:
		var number: int = int(item.number)
		var chapter: int = (number - 1) / STAGES_PER_CHAPTER
		var step: int = (number - 1) % STAGES_PER_CHAPTER
		var center := Vector2(width * 0.5 + sin(float(step) * PI * 0.5) * amplitude,
			summit_space + (_chapters.size() - chapter) * chapter_height - (136.0 + step * 116.0) / s)
		var button: Button = item.button
		button.visible = true
		item.boss.visible = bool(item.get("boss_marker", number == 99))
		item.boss_frame.visible = number == 99
		item.boss_aura.visible = number == 99
		button.position = center - node_size * 0.5
		button.size = node_size
		item.face.position = Vector2(11, 0) / s
		item.face_rest = item.face.position
		item.face.size = Vector2.ONE * 76.0 / s
		item.face.pivot_offset = item.face.size * 0.5
		item.halo.position = Vector2(-11, -22) / s
		item.halo.size = Vector2.ONE * 120.0 / s
		item.glint.position = Vector2(17, 8) / s
		item.glint.size = Vector2.ONE * 15.0 / s
		var focus := Style.box(Color.TRANSPARENT, Color("#fff0bd"), ceili(39.0 / s), maxi(1, roundi(2.0 / s)))
		focus.expand_margin_left = -10.0 / s
		focus.expand_margin_right = -10.0 / s
		focus.expand_margin_top = 1.0 / s
		focus.expand_margin_bottom = -27.0 / s
		button.add_theme_stylebox_override("focus", focus)
		item.label.position = item.face.position + Vector2(0, 8) / s
		item.label.size = Vector2(76, 60) / s
		item.label.add_theme_font_size_override("font_size", ceili((32.0 if number == highest + 1 else 30.0) / s))
		item.rating.position = Vector2(8, 78) / s
		item.rating.size = Vector2(82, 24) / s
		item.rating.add_theme_stylebox_override("panel",
			Style.box(Color("#eaffec") if number == highest + 1 else Color("#fff8e6"),
				Color("#8eb898") if number == highest + 1 else Color("#dfcba2"),
				ceili(12.0 / s), maxi(1, roundi(1.0 / s))))
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
		var boss_size: float = minf(124.0 / s, maxf(68.0 / s, _scroll.size.y - node_size.y - 26.0 / s)) \
			if number == 99 else 68.0 / s
		item.boss.position = button.position + Vector2((node_size.x - boss_size) * 0.5, -boss_size)
		if number == highest + 1 and item.boss.visible:
			var on_right: bool = width - button.get_rect().end.x >= button.position.x
			var frame_margin: float = 18.0 / s if number == 99 else 0.0
			var room: float = maxf(button.position.x, width - button.get_rect().end.x)
			boss_size = minf(boss_size, room - 8.0 / s - frame_margin * 2.0)
			item.boss.position = Vector2(button.get_rect().end.x + 8.0 / s + frame_margin if on_right \
				else button.position.x - 8.0 / s - frame_margin - boss_size,
				button.position.y + 8.0 / s - boss_size * 0.5)
		item.boss.size = Vector2.ONE * boss_size
		item.boss_aura.position = item.boss.position - Vector2.ONE * 16.0 / s
		item.boss_aura.size = item.boss.size + Vector2.ONE * 32.0 / s
		item.boss_frame.position = item.boss.position - Vector2.ONE * 18.0 / s
		item.boss_frame.size = item.boss.size + Vector2.ONE * 36.0 / s
		for index in range(3):
			var star: TextureRect = item.stars[index]
			star.position = Vector2((14.0 + index * 24.0) / s, 79.0 / s)
			star.size = Vector2.ONE * 22.0 / s
	_content.custom_minimum_size = Vector2(0.0, summit_space + chapter_height * _chapters.size())
	_content.size.x = width
	var curve := Curve2D.new()
	var earned := Curve2D.new()
	for item: Dictionary in _nodes:
		var center: Vector2 = item.button.get_rect().get_center()
		curve.add_point(center, Vector2(0, 40.0 / s), Vector2(0, -40.0 / s))
		if int(item.number) <= highest:
			earned.add_point(center, Vector2(0, 40.0 / s), Vector2(0, -40.0 / s))
	_route_points = curve.get_baked_points()
	_earned_points = earned.get_baked_points()
	_pip.custom_minimum_size = Vector2.ZERO
	_pip.size = Vector2(112, 84) / s
	_position_guide()
	_refresh_locks()
	_refresh_viewport()
	_content.queue_redraw()
	_queue_changed()


func _process(delta: float) -> void:
	if not _active or _reduced_motion or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	_effect_elapsed += minf(delta, 0.1)
	var unlocking: bool = _unlock_elapsed < ROUTE_SECONDS + UNLOCK_SECONDS
	if unlocking:
		_unlock_elapsed = minf(ROUTE_SECONDS + UNLOCK_SECONDS, _unlock_elapsed + delta)
	_refresh_locks(true)
	_pose_nodes(delta)
	_pose_scenery()
	if unlocking:
		_content.queue_redraw()
		_queue_changed()


func set_active(active: bool) -> void:
	if active == _active:
		return
	_active = active
	set_process(is_visible_in_tree() and active and not _reduced_motion)
	if not active:
		_scroll.cancel_drag()
		_clear_response()
	_layout()


func _sync_guide() -> void:
	if not is_inside_tree() or _nodes.is_empty():
		return
	var highest: int = clampi(int(_state.get("highest_cleared", 0)), 0, 99)
	var viewport: Rect2 = _scroll.get_global_rect()
	var supported_node: Button = _nodes[mini(highest, 98)].button
	_pip.visible = is_visible_in_tree() and highest < 99 \
		and not bool(_state.get("loading", false)) and str(_state.get("error", "")).is_empty() \
		and viewport.intersects(supported_node.get_global_rect())
	var on_screen: bool = _pip.is_visible_in_tree() \
		and _scroll.get_global_rect().intersects(_pip.get_global_rect())
	_pip.set_idle_paused(not on_screen or not _active or _reduced_motion)
	_pip.set_awake(on_screen and _active and highest < 99 \
		and (_hovered_stage == highest + 1 or _pressed_stage == highest + 1 \
			or _reduced_motion and _nodes[highest].button.has_focus()))


func _position_guide() -> void:
	if _nodes.is_empty() or _pip.size.x <= 0.0:
		return
	var highest: int = clampi(int(_state.get("highest_cleared", 0)), 0, 98)
	var item: Dictionary = _nodes[highest]
	var face: TextureRect = item.face
	var support: Vector2 = item.button.position + face.get_transform() * Vector2(face.size.x * 0.5, 0.0)
	_pip.position = support - _pip.support_point()


func _refresh_viewport() -> void:
	if _nodes.is_empty() or _chapters.is_empty():
		return
	var center: float = _scroll.scroll_vertical + _scroll.size.y * 0.5
	_chapter_index = clampi(_chapters.size() - 1 - floori((center - 132.0 / _scale) / (1160.0 / _scale)),
		0, _chapters.size() - 1)
	_refresh_locks(true)
	_pose_nodes()
	_pose_scenery()
	_sync_guide()


func _pose_nodes(delta: float = 0.0) -> void:
	if _nodes.is_empty():
		return
	var highest: int = clampi(int(_state.get("highest_cleared", 0)), 0, 99)
	var viewport: Rect2 = _scroll.get_global_rect()
	for item: Dictionary in _nodes:
		if not viewport.intersects(item.button.get_global_rect()) and is_zero_approx(float(item.hover)):
			continue
		var available: bool = not item.button.disabled and _active
		var hovering: bool = available and _hovered_stage == int(item.number)
		var holding: bool = available and _pressed_stage == int(item.number)
		var before: float = float(item.hover)
		item.hover = (1.0 if hovering else 0.0) if _reduced_motion else \
			move_toward(float(item.hover), 1.0 if hovering else 0.0, delta / 0.14)
		if before != float(item.hover) and float(item.hover) == (1.0 if hovering else 0.0):
			_queue_changed()
		var current: bool = int(item.number) == highest + 1
		var release: float = float(item.get("unlock_scale", 1.0))
		item.face.scale = Vector2.ONE * release * (1.0 + (0.04 if current else 0.0)
			+ 0.045 * float(item.hover) - (0.10 if holding else 0.0))
		item.face.position = item.face_rest + Vector2(0, -3.0 * float(item.hover) + (3.0 if holding else 0.0)) / _scale
		item.label.position = item.face.position + Vector2(0, 8) / _scale
		item.halo.visible = available and (current or hovering)
		item.halo.modulate = Color(1.0, 0.85, 0.40, 0.50 + (0.08 * sin(_effect_elapsed * 1.9) if not _reduced_motion else 0.0)) \
			if current else Color(0.64, 1.0, 0.82, 0.36 * float(item.hover))
		item.glint.visible = current and available
		item.glint.modulate = Color(1.0, 0.96, 0.73,
			0.80 if _reduced_motion else 0.10 + 0.80 * pow(maxf(0.0, cos(_effect_elapsed * 1.6)), 8.0))
	_position_guide()


func _pose_scenery() -> void:
	if _chapters.is_empty():
		return
	for index in range(_chapters.size()):
		var section: Dictionary = _chapters[index]
		var section_y: float = (132.0 + (_chapters.size() - 1 - index) * 1160.0) / _scale
		if not _reduced_motion and (section_y > _scroll.scroll_vertical + _scroll.size.y
			or section_y + 1160.0 / _scale < _scroll.scroll_vertical):
			continue
		var wind: float = 0.0 if _reduced_motion else sin(_effect_elapsed * 0.95 + index * 0.7)
		for key: String in ["grove", "shrubs", "left", "right"]:
			var flexible: bool = key in ["grove", "shrubs"] or index in [1, 2, 4, 5, 6, 7]
			section[key].rotation = wind * (0.008 if key == "shrubs" else 0.012) if flexible else 0.0


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
		if visible_only and (not item.button.is_visible_in_tree() \
			or not arriving and not _scroll.get_global_rect().intersects(item.button.get_global_rect())):
			continue
		var p: float = clampf((_unlock_elapsed - ROUTE_SECONDS) / UNLOCK_SECONDS, 0.0, 1.0) if arriving else 1.0
		var locked: bool = number > mini(highest + 1, 99)
		item.face.texture = STAGE_LOCKED if locked or (arriving and p <= 0.0) else STAGE_OPEN
		item["unlock_scale"] = 1.0 + 0.12 * sin(p * PI) if arriving and not _reduced_motion else 1.0
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
	var points: PackedVector2Array = _route_points
	if points.size() > 1:
		_content.draw_polyline(points, Color(0.38, 0.55, 0.48, 0.15), 26.0 / _scale, true)
		_content.draw_polyline(points, Color("#fff6df"), 18.0 / _scale, true)
		_content.draw_polyline(points, Color("#dccb99"), 2.0 / _scale, true)
	if _earned_points.size() > 1:
		_content.draw_polyline(_earned_points, Color("#d49c43"), 12.0 / _scale, true)
		_content.draw_polyline(_earned_points, Color("#f9d982"), 8.0 / _scale, true)
		_content.draw_polyline(_earned_points, Color("#fff1bf"), 2.0 / _scale, true)
	if _unlock_from <= 0 or _unlock_elapsed >= ROUTE_SECONDS + UNLOCK_SECONDS:
		return
	var journey := Curve2D.new()
	var start: Vector2 = _nodes[_unlock_from - 1].button.get_rect().get_center()
	journey.add_point(start,
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
	var chapters: Array[Dictionary] = []
	for index in range(_chapters.size()):
		var banner: Panel = _chapters[index].banner
		chapters.append({"index": index + 1, "title": Catalog.CHAPTERS[index],
			"first_stage": index * STAGES_PER_CHAPTER + 1, "last_stage": (index + 1) * STAGES_PER_CHAPTER,
			"rect": _rect(banner.get_global_rect()),
			"visible": banner.is_visible_in_tree() and _scroll.get_global_rect().intersects(banner.get_global_rect())})
	var highest: int = clampi(int(_state.get("highest_cleared", 0)), 0, 99)
	for item: Dictionary in _nodes:
		var number: int = int(item.number)
		stages.append({"number": number, "chapter": ceili(float(number) / 9.0),
			"unlocked": number <= mini(highest + 1, 99),
			"lock_visible": item.padlock.visible,
			"best_stars": int(_state.get("best_stars", {}).get(str(number), 0)),
			"boss": bool(item.get("boss_marker", number == 99)),
			"final_boss": number == 99,
			"boss_rect": _rect(item.boss.get_global_rect()) if item.boss.visible else {},
			"boss_portrait": BOSS_PORTRAIT.resource_path if item.boss.visible else "",
			"rect": _rect(item.button.get_global_rect()),
			"visible": item.button.is_visible_in_tree() and _scroll.get_global_rect().intersects(item.button.get_global_rect())})
	return {"visible": is_visible_in_tree(), "map_rect": _rect(get_global_rect()),
		"heading_rect": _rect(_heading.get_global_rect()),
		"scroll_rect": _rect(_scroll.get_global_rect()), "scroll_offset": _scroll.scroll_vertical,
		"stage_nodes": stages, "challenge": _control(_challenge), "home": _control(_home),
		"layout": "continuous", "chapters": chapters,
		"chapter": {"index": _chapter_index + 1, "count": Catalog.CHAPTERS.size(),
			"title": Catalog.CHAPTERS[_chapter_index], "first_stage": _chapter_index * STAGES_PER_CHAPTER + 1,
			"last_stage": (_chapter_index + 1) * STAGES_PER_CHAPTER},
		"guide": {"visible": _pip.is_visible_in_tree() and _scroll.get_global_rect().intersects(_pip.get_global_rect()),
			"stage": highest + 1 if highest < 99 else 0,
			"age": _pip.growth_age, "course_id": str(_pip.professional_profile.get("course_id", "")),
			"rect": _rect(_pip.get_global_rect()), "presentation": _pip.rest_snapshot()},
		"presentation": {"elapsed": _effect_elapsed, "hovered_stage": _hovered_stage, "pressed_stage": _pressed_stage,
			"reduced_motion": _reduced_motion,
			"hover_scale": _nodes[_hovered_stage - 1].face.scale.x if _hovered_stage > 0 else 1.0,
			"pressed_scale": _nodes[_pressed_stage - 1].face.scale.x if _pressed_stage > 0 else 1.0,
			"completed_edges": clampi(highest - (_chapter_index * STAGES_PER_CHAPTER + 1), 0, STAGES_PER_CHAPTER - 1)},
		"retry": _control(_retry), "loading": bool(_state.get("loading", false)),
		"unlock": {"from": _unlock_from, "to": _unlock_from + 1 if _unlock_from > 0 else 0,
			"elapsed": _unlock_elapsed, "phase": "route" if _unlock_elapsed < ROUTE_SECONDS \
				else "node" if _unlock_elapsed < ROUTE_SECONDS + UNLOCK_SECONDS else "done"},
		"error": str(_state.get("error", "")),
		"merged_level": int(_state.get("merged_level", 1)),
		"auto_merge_level": int(_state.get("auto_merge_level", 1)),
		"final_boss_stage": 99,
		"merged_level_indicator": _merged_level_badge.snapshot(),
		"upgrades_entry": _control(_upgrades),
		"boss_markers": _state.get("boss_markers", []).filter(func(number: int) -> bool: return number > 1),
		"boss_victories": _state.get("boss_victories", []).duplicate()}

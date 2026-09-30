extends VBoxContainer

signal changed
signal score_saved(outcome: Dictionary)

const Style = preload("res://scripts/ui_style.gd")
const NAVY := Color("#10172f")
const SURFACE := Color("#202b4c")
const EDGE := Color("#3c4770")
const WHITE := Color("#f6f7ff")
const SOFT := Color("#b7c4e7")
const GOLD := Color("#ffdc78")
const PURPLE := Color("#b39cff")
const AVATARS := ["duck", "cat", "dog", "fox", "panda", "frog", "unicorn", "rocket", "star", "rainbow", "bear", "rabbit"]
const MODES := {"pop": "Voice Pop", "match": "Match", "memory": "Memory"}
const RISE_DURATION := 1.65

var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		_reduced = value
		if value:
			settle_animation()

var _store
var _view: String = "boards"
var _mode: String = "pop"
var _round_mode: String = "pop"
var _round_id: String = ""
var _result: Dictionary = {}
var _reduced: bool = false
var _submitted: bool = false
var _selected: String = ""
var _selected_avatar: String = "duck"
var _draft_name: String = ""
var _editor_open: bool = false
var _error: String = ""
var _notice: String = ""
var _rows_data: Array = []
var _row_nodes: Dictionary = {}
var _row_starts: Dictionary = {}
var _board: Control
var _glory: Control
var _form: VBoxContainer
var _name_input: LineEdit
var _error_label: Label
var _save_button: Button
var _create_button: Button
var _animation: Dictionary = {}
var _animation_age: float = 0.0
var _generation: int = 0
var _textures: Dictionary = {}
var _last_scale: float = -1.0
var _rescale_pending: bool = false


class RankRow extends PanelContainer:

	var rank_label: Label
	var name_label: Label
	var metric_label: Label
	var avatar: TextureRect
	var player_id: String = ""
	var highlighted: bool = false


	func setup(data: Dictionary, texture: Texture2D, factor: float, highlight: bool) -> void:
		player_id = str(data.get("player_id", ""))
		highlighted = highlight
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var surface := Style.box(Color("#352e4d") if highlight else SURFACE, GOLD if highlight else EDGE, ceili(15 / factor), 1)
		surface.content_margin_left = 12 / factor
		surface.content_margin_right = 12 / factor
		surface.content_margin_top = 8 / factor
		surface.content_margin_bottom = 8 / factor
		add_theme_stylebox_override("panel", surface)
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", ceili(10 / factor))
		add_child(line)
		rank_label = Style.label(str(data.get("rank", 0)), ceili(20 / factor))
		rank_label.add_theme_color_override("font_color", GOLD if int(data.get("rank", 0)) <= 3 else SOFT)
		rank_label.custom_minimum_size.x = 26 / factor
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(rank_label)
		avatar = TextureRect.new()
		avatar.texture = texture
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.custom_minimum_size = Vector2.ONE * 44 / factor
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(avatar)
		name_label = Style.label(str(data.get("name", "Player")), ceili(18 / factor))
		name_label.add_theme_color_override("font_color", WHITE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.custom_minimum_size.x = 12
		line.add_child(name_label)
		var score := VBoxContainer.new()
		score.add_theme_constant_override("separation", 0)
		score.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(score)
		metric_label = Style.label(str(data.get("metric", 0)), ceili(22 / factor))
		metric_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		metric_label.add_theme_color_override("font_color", GOLD if highlight else WHITE)
		score.add_child(metric_label)
		var caption := Style.label(str(data.get("label", "hits")).trim_prefix(str(data.get("metric", 0)) + " "), ceili(10 / factor))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caption.add_theme_color_override("font_color", SOFT)
		score.add_child(caption)


class RiseGlory extends Control:

	var row_rect := Rect2()
	var progress: float = 0.0
	var factor: float = 1.0
	var rising: bool = true


	func _draw() -> void:
		if row_rect.size.x <= 0:
			return
		var energy: float = sin(PI * clampf(progress, 0.0, 1.0))
		var center := row_rect.get_center()
		var radius: float = row_rect.size.y * 0.42
		var avatar_center := Vector2(row_rect.position.x + 70 / factor, center.y)
		for layer in range(4, 0, -1):
			var halo := Style.box(Color(GOLD, energy * 0.012 * (5 - layer)), Color(GOLD, energy * 0.032 * (5 - layer)), ceili((17 + layer * 3) / factor), maxi(1, ceili(layer / factor)))
			draw_style_box(halo, row_rect.grow(layer * 4 / factor))
		if rising:
			for trail in range(7):
				var offset := Vector2((trail - 3) * 8 / factor, row_rect.size.y * 0.45)
				var end := offset + Vector2(sin(trail * 2.1 + progress * 9) * 5, 20 + 60 * energy) / factor
				draw_line(avatar_center + offset, avatar_center + end, Color(GOLD, energy * (0.25 if trail % 2 else 0.52)), (2 if trail % 2 else 3) / factor, true)
		draw_arc(avatar_center, radius + (5 + 8 * energy) / factor, progress * TAU, progress * TAU + PI * 1.55, 44, Color(GOLD, energy * 0.9), 2 / factor, true)
		for spark in range(18):
			var angle: float = spark * 2.39996 + progress * 0.55
			var flight: float = fmod(progress * 1.8 + spark * 0.137, 1.0)
			var origin := Vector2(lerpf(row_rect.position.x + 14 / factor, row_rect.end.x - 14 / factor, float(spark % 6) / 5), center.y)
			var point := origin + Vector2(cos(angle), sin(angle)) * (18 + 58 * flight) / factor
			var sparkle: float = (1.0 - flight) * energy
			var length: float = (2 + 4 * sparkle) / factor
			draw_line(point - Vector2(length, 0), point + Vector2(length, 0), Color(GOLD.lightened(0.4), sparkle), 1.5 / factor, true)
			draw_line(point - Vector2(0, length), point + Vector2(0, length), Color(GOLD, sparkle), 1.5 / factor, true)


func _ready() -> void:
	_last_scale = _scale()
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", _px(14))
	resized.connect(_relayout_board)
	visibility_changed.connect(_visibility_changed)
	set_process(false)


func configure(store: RefCounted, view: String = "boards", mode: String = "pop", round_id: String = "", result: Dictionary = {}, reduced: bool = false) -> void:
	settle_animation()
	_generation += 1
	_store = store
	_view = view if view in ["players", "boards"] else "boards"
	_mode = mode if MODES.has(mode) else "pop"
	_round_mode = _mode
	_round_id = round_id
	_result = result.duplicate(true)
	_reduced = reduced
	reduced_motion = reduced
	_submitted = false
	_selected = ""
	_selected_avatar = "duck"
	_draft_name = ""
	_error = ""
	_notice = ""
	_editor_open = _view == "players" or _profiles().is_empty()
	if not _round_id.is_empty() and _store != null and _store.has_method("round_submission"):
		var previous: Dictionary = _store.round_submission(_round_id)
		if not previous.is_empty():
			_submitted = true
			_selected = str(previous.get("player_id", ""))
			_notice = "Score saved. Your personal best is on the board."
	_build()


func refresh_profiles() -> void:
	# Menu edits may happen while this result is covered. Keep its choice and
	# draft, but rebuild the visible profiles from the latest durable record.
	settle_animation()
	if _store != null:
		_store.load_state()
	_build()


func _build() -> void:
	_generation += 1
	_last_scale = _scale()
	set_process(false)
	_animation = {}
	_row_nodes.clear()
	_row_starts.clear()
	_rows_data.clear()
	_board = null
	_glory = null
	_form = null
	_name_input = null
	_save_button = null
	_create_button = null
	_error_label = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", _px(14))
	var panel := PanelContainer.new()
	panel.name = "LeaderboardSurface"
	var surface := Style.box(NAVY, EDGE, _px(22), 1)
	surface.content_margin_left = 16 / _scale()
	surface.content_margin_right = 16 / _scale()
	surface.content_margin_top = 18 / _scale()
	surface.content_margin_bottom = 18 / _scale()
	panel.add_theme_stylebox_override("panel", surface)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", _px(14))
	panel.add_child(body)
	var eyebrow := _label("YOUR LOCAL PLAYERS" if _view == "players" else "LOCAL LEADERBOARDS", 11, GOLD)
	body.add_child(eyebrow)
	body.add_child(_label("Make it your game" if _view == "players" else "Meet the high scorers", 24, WHITE, true))
	body.add_child(_label("Up to 10 players. Pick an emoji and a name." if _view == "players" else "Personal bests on this device. Equal scores share a rank.", 12, SOFT, true))
	_error_label = _label(_error, 13, Color("#ffb8a9"), true)
	_error_label.name = "LeaderboardError"
	_error_label.visible = not _error.is_empty()
	body.add_child(_error_label)
	if _store == null or not _store.ready:
		_set_error(str(_store.error) if _store != null else "Player data is unavailable.")
		var retry := _button("Retry loading", "LeaderboardRetryLoad", true)
		retry.pressed.connect(_retry_load)
		body.add_child(retry)
		_pass_scroll_inputs(self)
		_publish_later()
		return
	if _view == "players":
		_build_profiles(body, false)
		_build_editor(body)
		body.add_child(_label("Emoji artwork: Twemoji / CC BY 4.0", 10, SOFT))
	else:
		if not _round_id.is_empty():
			_build_attribution(body)
		if _round_id.is_empty() or _submitted:
			_build_mode_tabs(body)
		_build_board(body)
	_pass_scroll_inputs(self)
	_publish_later()


func _build_attribution(body: VBoxContainer) -> void:
	if _submitted:
		var profile: Dictionary = _profile(_selected)
		var saved := HBoxContainer.new()
		saved.add_theme_constant_override("separation", _px(10))
		var icon := _avatar(str(profile.get("avatar", "duck")), 38)
		saved.add_child(icon)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_child(_label("Saved for " + str(profile.get("name", "your player")), 16, GOLD, true))
		copy.add_child(_label(_notice if not _notice.is_empty() else "Your personal best is on the board.", 12, SOFT, true))
		saved.add_child(copy)
		body.add_child(saved)
		return
	body.add_child(_label("Who played this round?", 19, WHITE))
	body.add_child(_label("Choose a player to save this score, or play again without saving.", 12, SOFT, true))
	_build_profiles(body, true)
	if _profiles().size() < 10:
		var add := _button("Add player" if not _editor_open else "Choose an emoji and name", "LeaderboardAddPlayer")
		add.disabled = _editor_open
		add.pressed.connect(_open_editor)
		body.add_child(add)
		if _editor_open:
			_build_editor(body)
	_save_button = _button("Save score", "LeaderboardSaveScore", true)
	_save_button.disabled = _selected.is_empty()
	_save_button.pressed.connect(_save_score)
	body.add_child(_save_button)


func _build_profiles(body: VBoxContainer, selectable: bool) -> void:
	var profiles := _profiles()
	if profiles.is_empty():
		body.add_child(_label("Your first player starts here.", 14, PURPLE, true))
		return
	var grid := HFlowContainer.new()
	grid.name = "LeaderboardPlayerChoices"
	grid.add_theme_constant_override("h_separation", _px(8))
	grid.add_theme_constant_override("v_separation", _px(8))
	for profile in profiles:
		var id: String = str(profile.get("id", ""))
		var choice := _button(str(profile.get("name", "Player")), "LeaderboardPlayer_" + id, id == _selected)
		choice.icon = _texture(str(profile.get("avatar", "duck")))
		choice.expand_icon = true
		choice.add_theme_constant_override("icon_max_width", _px(30))
		choice.custom_minimum_size = Vector2(116, 48) / _scale()
		choice.clip_text = true
		choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		choice.tooltip_text = str(profile.get("name", "Player"))
		choice.toggle_mode = selectable
		choice.button_pressed = id == _selected
		if selectable:
			choice.pressed.connect(_select_player.bind(id))
		else:
			choice.mouse_filter = Control.MOUSE_FILTER_IGNORE
			choice.focus_mode = Control.FOCUS_NONE
		grid.add_child(choice)
	body.add_child(grid)
	if not selectable:
		body.add_child(_label("%d / 10 players" % profiles.size(), 12, SOFT))


func _build_editor(body: VBoxContainer) -> void:
	if _profiles().size() >= 10:
		body.add_child(_label("All 10 player spots are in use.", 13, GOLD, true))
		return
	_form = VBoxContainer.new()
	_form.name = "LeaderboardPlayerEditor"
	_form.add_theme_constant_override("separation", _px(10))
	body.add_child(_form)
	_form.add_child(_label("Choose your avatar", 13, SOFT))
	var avatars := HFlowContainer.new()
	avatars.add_theme_constant_override("h_separation", _px(6))
	avatars.add_theme_constant_override("v_separation", _px(6))
	for id in AVATARS:
		var choice := _button("", "LeaderboardAvatar_" + id, id == _selected_avatar)
		choice.icon = _texture(id)
		choice.expand_icon = true
		choice.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice.add_theme_constant_override("icon_max_width", _px(32))
		choice.custom_minimum_size = Vector2.ONE * 46 / _scale()
		choice.tooltip_text = str(id).capitalize()
		choice.toggle_mode = true
		choice.button_pressed = id == _selected_avatar
		choice.pressed.connect(_select_avatar.bind(id))
		avatars.add_child(choice)
	_form.add_child(avatars)
	_name_input = LineEdit.new()
	_name_input.name = "LeaderboardName"
	_name_input.placeholder_text = "Player name"
	_name_input.max_length = 20
	_name_input.text = _draft_name
	_name_input.custom_minimum_size.y = 48 / _scale()
	_name_input.add_theme_font_size_override("font_size", _px(16))
	_name_input.add_theme_color_override("font_color", WHITE)
	_name_input.add_theme_color_override("font_placeholder_color", SOFT)
	_name_input.add_theme_color_override("caret_color", GOLD)
	_name_input.add_theme_stylebox_override("normal", Style.box(SURFACE, EDGE, _px(12), 1))
	_name_input.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, GOLD, _px(12), 2))
	_name_input.text_changed.connect(_name_changed)
	_name_input.text_submitted.connect(func(_text: String): _create_player())
	_name_input.focus_entered.connect(_ensure_visible.bind(_name_input))
	_form.add_child(_name_input)
	_create_button = _button("Create player", "LeaderboardCreatePlayer", true)
	_create_button.disabled = _draft_name.strip_edges().is_empty()
	_create_button.pressed.connect(_create_player)
	_form.add_child(_create_button)


func _build_mode_tabs(body: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", _px(6))
	for mode in MODES:
		var button := _button(MODES[mode], "LeaderboardMode_" + str(mode), mode == _mode)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", _px(12))
		button.pressed.connect(_choose_mode.bind(mode))
		tabs.add_child(button)
	body.add_child(tabs)


func _build_board(body: VBoxContainer) -> void:
	_rows_data = _store.board(_mode)
	var heading := HBoxContainer.new()
	var title := _label(MODES.get(_mode, "Voice Pop"), 18, WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_label("PERSONAL BEST", 10, PURPLE))
	body.add_child(heading)
	var rule: String = "Most hits wins."
	if _mode == "match":
		rule = "Completed rounds: fewest misses, then hints."
	elif _mode == "memory":
		rule = "Completed rounds: fewest turns, then peeks."
	body.add_child(_label(rule, 12, SOFT, true))
	if _rows_data.is_empty():
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", Style.box(SURFACE, EDGE, _px(16), 1))
		empty.custom_minimum_size.y = 90 / _scale()
		var prompt := _label("The first score is waiting.\nFinish a round and choose its player.", 14, SOFT, true)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(prompt)
		body.add_child(empty)
		return
	_board = Control.new()
	_board.name = "LeaderboardRows"
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.custom_minimum_size.y = _rows_data.size() * _row_step() - 8 / _scale()
	_board.resized.connect(_relayout_board)
	body.add_child(_board)
	for data in _rows_data:
		var row := RankRow.new()
		row.name = "LeaderboardRow_" + str(data.get("player_id", ""))
		row.setup(data, _texture(str(data.get("avatar", "duck"))), _scale(), str(data.get("player_id", "")) == _selected)
		_board.add_child(row)
		_row_nodes[row.player_id] = row
	_glory = RiseGlory.new()
	_glory.name = "LeaderboardRiseEffect"
	_glory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glory.z_index = 4
	_glory.visible = false
	_board.add_child(_glory)
	_relayout_board()


func _select_player(id: String) -> void:
	if _submitted:
		return
	_selected = id
	_error = ""
	for control in controls():
		if control is Button and str(control.name).begins_with("LeaderboardPlayer_"):
			control.button_pressed = str(control.name) == "LeaderboardPlayer_" + id
			_style_button(control, control.button_pressed)
	if is_instance_valid(_save_button):
		_save_button.disabled = false
	_set_error("")
	changed.emit()


func _select_avatar(id: String) -> void:
	_selected_avatar = id
	for control in controls():
		if control is Button and str(control.name).begins_with("LeaderboardAvatar_"):
			control.button_pressed = str(control.name) == "LeaderboardAvatar_" + id
			_style_button(control, control.button_pressed)
	changed.emit()


func _name_changed(value: String) -> void:
	_draft_name = value
	if is_instance_valid(_create_button):
		_create_button.disabled = value.strip_edges().is_empty()
	changed.emit()


func _open_editor() -> void:
	_editor_open = true
	_build()
	if is_instance_valid(_name_input):
		_name_input.grab_focus()


func _create_player() -> void:
	if _store == null or _draft_name.strip_edges().is_empty() or _profiles().size() >= 10:
		return
	if not _store.ready and not _store.load_state():
		_set_error(str(_store.error))
		return
	var outcome: Dictionary = _store.create_profile(_draft_name, _selected_avatar)
	if not bool(outcome.get("ok", false)):
		_set_error(str(outcome.get("error", "Could not save this player. Please try again.")))
		return
	_selected = str(outcome.get("profile", {}).get("id", ""))
	_draft_name = ""
	_editor_open = _view == "players"
	_error = ""
	_notice = "Player created."
	_build()
	if is_instance_valid(_save_button):
		_save_button.grab_focus()
	elif is_instance_valid(_name_input):
		_name_input.grab_focus()


func _save_score() -> void:
	if _submitted or _selected.is_empty() or _round_id.is_empty() or _store == null:
		return
	if not _store.ready and not _store.load_state():
		_set_error(str(_store.error))
		return
	var outcome: Dictionary = _store.submit_round(_round_id, _round_mode, _selected, _result)
	if not bool(outcome.get("ok", false)):
		_set_error(str(outcome.get("error", "Could not save this score. Please try again.")))
		return
	_submitted = true
	_selected = str(outcome.get("player_id", _selected))
	_error = ""
	_mode = _round_mode
	var improving: bool = bool(outcome.get("improved", false))
	var first_entry: bool = int(outcome.get("old_rank", 0)) == 0
	var places: int = int(outcome.get("old_rank", 0)) - int(outcome.get("new_rank", 0))
	_notice = "UP %d %s!" % [places, "PLACE" if places == 1 else "PLACES"] if improving else "Your first score is on the board!" if first_entry else "New personal best!" if bool(outcome.get("personal_best", false)) else "Score saved. Your personal best stays on the board."
	_build()
	var focus := find_child("LeaderboardMode_" + _mode, true, false) as Control
	if is_instance_valid(focus):
		focus.grab_focus()
	if not bool(outcome.get("duplicate", false)):
		if improving or first_entry:
			_begin_animation.call_deferred(outcome.duplicate(true), _generation)
		score_saved.emit(outcome)
	changed.emit()


func _begin_animation(outcome: Dictionary, generation: int) -> void:
	# Let containers settle after the chooser is replaced by the saved identity.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if generation != _generation or _reduced or not is_instance_valid(_board) or not is_visible_in_tree():
		return
	var id: String = str(outcome.get("player_id", ""))
	if not _row_nodes.has(id):
		return
	var is_rise: bool = bool(outcome.get("improved", false))
	var before: Array = outcome.get("before", [])
	_row_starts.clear()
	for index in range(before.size()):
		_row_starts[str(before[index].get("player_id", ""))] = float(index) * _row_step()
	_animation = {"active": false, "type": "rise" if is_rise else "entry", "player_id": id, "old_rank": int(outcome.get("old_rank", 0)), "new_rank": int(outcome.get("new_rank", 0)), "progress": 0.0}
	_animation_age = 0.0
	_glory.rising = is_rise
	_row_nodes[id].z_index = 3
	# Place the player at the source before scrolling. Short climbs keep their
	# entire path in view; long climbs reveal the source and follow the player.
	_apply_animation()
	_reveal_animation_path(id, is_rise)
	await get_tree().process_frame
	if generation != _generation or _reduced or not is_instance_valid(_board) or not is_visible_in_tree() or _animation.is_empty():
		return
	_animation["active"] = true
	_glory.visible = true
	set_process(true)
	changed.emit()


func _reveal_animation_path(id: String, is_rise: bool) -> void:
	var row: Control = _row_nodes[id]
	for index in range(_rows_data.size()):
		if str(_rows_data[index].get("player_id", "")) != id:
			continue
		var destination: float = index * _row_step()
		var start: float = float(_row_starts.get(id, destination)) if is_rise else destination
		var lift: float = (22.0 if is_rise else 12.0) / _scale() if is_equal_approx(start, destination) else 0.0
		var region := Rect2(Vector2(0, minf(start, destination) - lift), Vector2(row.size.x, absf(start - destination) + row.size.y + lift))
		_scroll_rect_into_view(_board.get_global_transform() * region, 26 / _scale(), true)
		return


func _process(delta: float) -> void:
	if _animation.is_empty():
		set_process(false)
		return
	_animation_age = minf(RISE_DURATION, _animation_age + delta)
	_animation["progress"] = _animation_age / RISE_DURATION
	_apply_animation()
	if _animation_age >= RISE_DURATION:
		settle_animation()


func _apply_animation() -> void:
	if _animation.is_empty() or not is_instance_valid(_board):
		return
	var progress: float = float(_animation.get("progress", 0.0))
	var travel: float = clampf((progress - 0.12) / 0.69, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - travel, 3)
	var active_id: String = str(_animation.get("player_id", ""))
	for index in range(_rows_data.size()):
		var id: String = str(_rows_data[index].get("player_id", ""))
		var row: Control = _row_nodes[id]
		var destination: float = index * _row_step()
		var start: float = float(_row_starts.get(id, destination)) if _animation.get("type") == "rise" else destination
		row.position.y = lerpf(start, destination, eased)
		if id == active_id:
			row.pivot_offset = row.size * 0.5
			var lift: float = sin(progress * PI)
			row.position.x = -3 / _scale() * lift
			row.scale = Vector2.ONE * (1.0 + 0.035 * lift)
			if _animation.get("type") == "entry":
				row.position.y -= sin(progress * PI) * 12 / _scale()
			elif is_equal_approx(start, destination):
				# A player can improve to a tied rank without changing stable row order.
				row.position.y -= sin(progress * PI) * 22 / _scale()
			_glory.row_rect = Rect2(row.position, row.size)
			_glory.progress = progress
			_glory.factor = _scale()
			_glory.queue_redraw()
			# Long climbs can span more than one mobile screen. Follow the player
			# as the surrounding rows move, keeping room for the gold glow.
			_ensure_visible_now(row, 22 / _scale())


func settle_animation() -> void:
	_generation += 1
	set_process(false)
	var was_active: bool = not _animation.is_empty()
	_animation = {}
	_row_starts.clear()
	for row in _row_nodes.values():
		if is_instance_valid(row):
			row.scale = Vector2.ONE
			row.position.x = 0
			row.z_index = 0
	if is_instance_valid(_glory):
		_glory.visible = false
	_relayout_board()
	if was_active:
		changed.emit()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		settle_animation()


func _choose_mode(mode: String) -> void:
	settle_animation()
	_mode = mode
	_build()
	var focus := find_child("LeaderboardMode_" + mode, true, false) as Control
	if is_instance_valid(focus):
		focus.grab_focus()


func _retry_load() -> void:
	if _store == null:
		return
	_store.load_state()
	_error = "" if _store.ready else str(_store.error)
	_build()


func _relayout_board() -> void:
	if _last_scale > 0.0 and not is_equal_approx(_last_scale, _scale()) and not _rescale_pending:
		_rescale_pending = true
		_rescale.call_deferred()
	if not is_instance_valid(_board):
		return
	for index in range(_rows_data.size()):
		var id: String = str(_rows_data[index].get("player_id", ""))
		if not _row_nodes.has(id):
			continue
		var row: Control = _row_nodes[id]
		row.size = Vector2(_board.size.x, _row_step() - 8 / _scale())
		if _animation.is_empty():
			row.position = Vector2(0, index * _row_step())
	if is_instance_valid(_glory):
		_glory.size = _board.size
	if not _animation.is_empty():
		_apply_animation()
	_publish_later()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	_collect_controls(self, result)
	return result


func _collect_controls(node: Node, result: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and child.visible and child.focus_mode != Control.FOCUS_NONE and (child is Button or child is LineEdit):
			result.append(child)
		_collect_controls(child, result)


func default_focus() -> Control:
	if is_instance_valid(_save_button) and not _save_button.disabled:
		return _save_button
	if _profiles().is_empty() and is_instance_valid(_name_input):
		return _name_input
	for control in controls():
		if not control is Button or not control.disabled:
			return control
	return null


func snapshot() -> Dictionary:
	var geometry: Array = []
	for control in controls():
		var rect := control.get_global_rect()
		geometry.append({"name": str(control.name), "text": str(control.text), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "focused": control.has_focus(), "disabled": control.disabled if control is Button else false})
	var rows: Array = _rows_data.duplicate(true)
	for row in rows:
		var node: Control = _row_nodes.get(str(row.get("player_id", "")))
		if is_instance_valid(node):
			var rect := node.get_global_rect()
			row["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	var animation: Dictionary = _animation.duplicate(true) if not _animation.is_empty() else {"active": false}
	if bool(animation.get("active", false)):
		var id: String = str(animation.get("player_id", ""))
		var row: Control = _row_nodes.get(id)
		if is_instance_valid(row):
			var row_rect := row.get_global_rect()
			animation["rect"] = [row_rect.position.x, row_rect.position.y, row_rect.size.x, row_rect.size.y]
			animation["origin_y"] = _board.global_position.y + float(_row_starts.get(id, row.position.y))
			for index in range(_rows_data.size()):
				if str(_rows_data[index].get("player_id", "")) == id:
					animation["target_y"] = _board.global_position.y + index * _row_step()
			animation["current_y"] = row_rect.position.y
	var rect := get_global_rect()
	return {"view": _view, "mode": _mode, "round_id": _round_id, "submitted": _submitted, "selected_player": _selected, "error": _error, "profiles": _profiles().duplicate(true), "rows": rows, "animation": animation, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "controls": geometry}


func _set_error(message: String) -> void:
	_error = message
	if is_instance_valid(_error_label):
		_error_label.text = message
		_error_label.visible = not message.is_empty()
	changed.emit()


func _profile(id: String) -> Dictionary:
	for profile in _profiles():
		if str(profile.get("id", "")) == id:
			return profile
	return {}


func _profiles() -> Array:
	return _store.profiles if _store != null else []


func _button(text: String, node_name: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.name = node_name
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 46 / _scale()
	button.add_theme_font_size_override("font_size", _px(14))
	button.focus_entered.connect(_ensure_visible.bind(button))
	_style_button(button, primary)
	return button


func _style_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = GOLD if primary else SURFACE
		if state == "hover":
			fill = fill.lightened(0.12)
		elif state == "pressed":
			fill = fill.darkened(0.10)
		elif state == "disabled":
			fill = Color("#28334f")
		var surface := Style.box(fill, GOLD if primary and state != "disabled" else EDGE, _px(12), 1)
		surface.content_margin_left = 10 / _scale()
		surface.content_margin_right = 10 / _scale()
		surface.content_margin_top = 6 / _scale()
		surface.content_margin_bottom = 6 / _scale()
		button.add_theme_stylebox_override(state, surface)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, NAVY if primary else WHITE)
	button.add_theme_color_override("font_disabled_color", SOFT)
	button.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, PURPLE, _px(12), _px(2)))


func _label(text: String, font_size: int, color: Color, wrap: bool = false) -> Label:
	var label := Style.label(text, _px(font_size))
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _avatar(id: String, width: float) -> TextureRect:
	var avatar := TextureRect.new()
	avatar.texture = _texture(id)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2.ONE * width / _scale()
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return avatar


func _texture(id: String) -> Texture2D:
	var avatar: String = id if id in AVATARS else "duck"
	if not _textures.has(avatar):
		_textures[avatar] = load("res://assets/avatars/" + avatar + ".svg")
	return _textures[avatar]


func _scale() -> float:
	return Style.ui_scale(self)


func _px(value: float) -> int:
	return maxi(1, ceili(value / _scale()))


func _row_step() -> float:
	return 76 / _scale()


func _publish_later() -> void:
	changed.emit.call_deferred()


func _ensure_visible(control: Control) -> void:
	_ensure_visible_now.call_deferred(control)


func _ensure_visible_now(control: Control, padding: float = 0.0) -> void:
	if not is_instance_valid(control) or not is_ancestor_of(control):
		return
	_scroll_rect_into_view(control.get_global_rect(), padding)


func _scroll_rect_into_view(global_rect: Rect2, padding: float = 0.0, require_fit: bool = false) -> void:
	var content: Control = self
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			# Hidden scrollbar rails must still scroll focused controls into view.
			# Absolute content coordinates keep duplicate focus events idempotent.
			var content_rect: Rect2 = content.get_global_transform().affine_inverse() * global_rect
			content_rect = content_rect.grow_individual(0, padding, 0, padding)
			if require_fit and content_rect.size.y > ancestor.size.y:
				return
			if content_rect.position.y < ancestor.scroll_vertical:
				ancestor.scroll_vertical = floori(content_rect.position.y)
			elif content_rect.end.y > ancestor.scroll_vertical + ancestor.size.y:
				ancestor.scroll_vertical = ceili(content_rect.end.y - ancestor.size.y)
			return
		if ancestor is Control:
			content = ancestor
		ancestor = ancestor.get_parent()


func _pass_scroll_inputs(node: Node) -> void:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_pass_scroll_inputs(child)


func _rescale() -> void:
	_rescale_pending = false
	if is_equal_approx(_last_scale, _scale()) or _store == null:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focus_name: String = str(focused.name) if is_instance_valid(focused) and is_ancestor_of(focused) else ""
	settle_animation()
	_build()
	if not focus_name.is_empty():
		var replacement := find_child(focus_name, true, false) as Control
		if is_instance_valid(replacement):
			replacement.grab_focus()

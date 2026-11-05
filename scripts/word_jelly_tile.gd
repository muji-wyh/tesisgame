extends "res://scripts/jelly_tile.gd"
## Roots, pictures and merged words share the ordinary square Jelly body.

signal read_requested(id: int)

var valid_word: bool = false
var requires_read: bool = false
var jelly_kind: String = "root"
var merge_level: int = 0
var _authored: bool = false
var _spelling: String = ""
var _break_offsets: Array = []
const Footprint = preload("res://scripts/jelly_footprint.gd")
const WordModel = preload("res://scripts/word_jelly_model.gd")
var _read_button := Button.new()
var fragments: int = 0
var _fragment_badges: Array[TextureRect] = []
var _fragment_texture: Texture2D
var _fragment_holder: Control
var _fragment_count: Label
var _fragment_arrival_age: float = -1.0
var _unit: float = 60.0
var palette_index: int = -1
const COMPLETION_GLOW = preload("res://assets/chests/shared/effects/portal_glow.png")
const COMPLETION_LIGHT = preload("res://scripts/jelly_completion_glow.gdshader")
const COMPLETION_SPARKLE = preload("res://assets/chests/shared/effects/sparkle.png")
const MERGED_EFFECT_ATLAS = preload("res://assets/images/jelly-level-fx/atlas.png")
const MERGED_EFFECT_SHADER = preload("res://scripts/word_jelly_merged_level_fx.gdshader")
const MergedCoreCache = preload("res://scripts/jelly_merged_core_cache.gd")
const MERGED_EFFECT_IDS: Array[String] = ["pearl", "ripple", "spiral", "firework", "cascade",
	"bouquet", "aurora", "constellation", "grand_bouquet"]
const MERGED_EFFECT_FRAMES: float = 32.0
const MERGED_EFFECT_SECONDS: float = 3.2
const COMPLETION_GROW_SECONDS: float = 0.20
const COMPLETION_HELD_SCALE: float = 1.12
const COMPLETION_BREATH_AMOUNT: float = 0.025
const COMPLETION_BREATH_SECONDS: float = 2.2
var completion_hint: bool = false
var match_dimmed: bool = false
var completion_scale: float = 1.0
var _completion_started_at: float = 0.0
var _completion_last_elapsed: float = 0.0
var _completion_animated: bool = true
var _completion_reduced: bool = false
var _merged_glow: TextureRect
var _merged_glints: Array[TextureRect] = []
var _merged_effect: TextureRect
var _merged_effect_material: ShaderMaterial
var _merged_effect_frame: float = 0.0
var _merged_elapsed: float = 0.0
var _merged_geometry_size := Vector2(-1.0, -1.0)
var _merged_geometry_scale: float = -1.0
var _merged_geometry_level: int = -1
var _merged_geometry_active: bool = false
var _merged_pose_elapsed: float = -1.0
var _merged_pose_reduced: bool = false
var _merged_pose_id: int = -1
var _ambient_animation: bool = true
static var _shared_light_material: ShaderMaterial
var _level_badge: Label
var _picture_shadow: TextureRect
var _boss_status: Dictionary = {}
var _boss_overlay := Control.new()
var _merged_core_proxy := Node2D.new()
var _merged_core_allowed: bool = false
var _merged_core_enabled: bool = true
var _merged_core_requested: bool = false
var _merged_core_revision: int = 0
var _merged_core_rejected_revision: int = -1
var _merged_core_key: String = ""
var _merged_core_pool: WeakRef
var _merged_core_texture: Texture2D
var _merged_core_size := Vector2.ZERO
var _merged_core_hidden: Array[CanvasItem] = []
const MERGED_COLORS: Array[Color] = [Color("#f7c45c"), Color("#f7c45c"), Color("#9ee8f3"),
	Color("#b6c3ff"), Color("#ffd16f"), Color("#ffb4dc"), Color("#f4daff"),
	Color("#b3f1dd"), Color("#cbd9ff"), Color("#ffe397")]

func _init() -> void:
	super()
	_merged_core_proxy.name = "MergedCorePaint"
	_merged_core_proxy.material = MergedCoreCache.display_material()
	_merged_core_proxy.draw.connect(_draw_merged_core)
	add_child(_merged_core_proxy)
	move_child(_merged_core_proxy, _visual.get_index())
	_merged_core_proxy.hide()
	idle_paint_changed.connect(_merged_body_paint_changed)
	visibility_changed.connect(_merged_visibility_changed)
	_picture_shadow = _texture()
	_picture_shadow.name = "WordPictureShadow"
	_picture_shadow.self_modulate = Color(0.12, 0.18, 0.22, 0.56)
	_visual.move_child(_picture_shadow, _picture.get_index())
	visibility_changed.connect(_sync_picture_shadow)
	_read_button.name = "ReadSpelling"
	_read_button.text = "Read"
	_read_button.focus_mode = Control.FOCUS_ALL
	_read_button.mouse_filter = Control.MOUSE_FILTER_STOP
	Style.button(_read_button, Style.GOOD)
	_read_button.custom_minimum_size = Vector2.ZERO
	_read_button.pressed.connect(func() -> void: read_requested.emit(tile_id))
	add_child(_read_button)
	_read_button.hide()
	_level_badge = Style.label("", 12)
	_level_badge.name = "MergeLevel"
	_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_badge.add_theme_font_override("font", Style.HEADING_FONT)
	_level_badge.add_theme_color_override("font_color", Color("#fff8df"))
	_level_badge.add_theme_color_override("font_outline_color", Color("#473e63"))
	_level_badge.add_theme_constant_override("outline_size", 1)
	_level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_badge.z_index = 46
	_visual.add_child(_level_badge)
	_level_badge.hide()
	_boss_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_overlay.z_index = 55
	_boss_overlay.draw.connect(_draw_boss_status)
	add_child(_boss_overlay)


func set_boss_status(state: Dictionary, reduced: bool) -> void:
	# Ordinary stages keep the same empty overlay between layout changes.
	# A nonempty previous state must still run once to restore inked faces.
	if state.is_empty() and _boss_status.is_empty() and _boss_overlay.size == size:
		return
	# Keep the presented state stable if a caller reuses its dictionary.
	if (float(state.get("ink", 0.0)) > 0.0) != (float(_boss_status.get("ink", 0.0)) > 0.0):
		_invalidate_merged_core()
	_boss_status = state.duplicate()
	var obscured: bool = float(state.get("ink", 0.0)) > 0.0
	_label.modulate.a = 0.06 if obscured else 1.0
	_picture.modulate.a = 0.06 if obscured else 1.0
	_picture_shadow.modulate.a = 0.06 if obscured else 1.0
	if float(state.get("freeze", 0.0)) > 0.0:
		disabled = true
		set_completion_hint(false, _merged_elapsed, reduced)
	_boss_overlay.size = size
	_boss_overlay.queue_redraw()


func _draw_boss_status() -> void:
	var s: float = Style.ui_scale(self)
	var frozen: float = float(_boss_status.get("freeze", 0.0))
	var locks: int = int(_boss_status.get("locks", 0))
	var edge: float = minf(size.x * 0.33, 22.0 / s)
	if float(_boss_status.get("ink", 0.0)) > 0.0:
		_boss_overlay.draw_texture_rect(COMPLETION_GLOW, Rect2(Vector2.ZERO, size), false, Color("#794ea0"))
		var mark: Texture2D = preload("res://assets/images/ui/controls/eye-closed.svg")
		_boss_overlay.draw_texture_rect(mark, Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge), false)
	if frozen > 0.0:
		_boss_overlay.draw_texture_rect(COMPLETION_GLOW, Rect2(-size * 0.12, size * 1.24), false, Color("#87dfff"))
		var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.47)
		_boss_overlay.draw_texture_rect(preload("res://assets/images/ui/jelly-goals/clock.webp"),
			Rect2(center - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false)
		_boss_overlay.draw_arc(center, edge * 0.65, -PI * 0.5, -PI * 0.5 + TAU * frozen / 3.0,
			32, Color("#e7fcff"), maxf(1.0, 2.0 / s), true)
		_boss_overlay.draw_string(Style.HEADING_FONT, Vector2(size.x * 0.40, size.y * 0.88),
			"%d" % ceili(frozen), HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(12 / s), Color("#194d67"))
	for index in range(locks):
		var at: Vector2 = Vector2(size.x - edge * (index + 1) - 2 / s, 2 / s)
		var rect := Rect2(at, Vector2.ONE * edge)
		_boss_overlay.draw_style_box(Style.box(Color("#fff0c3"), Color("#b98b38"), 5, 1), rect)
		_boss_overlay.draw_texture_rect(preload("res://assets/images/ui/controls/lock.svg"), rect.grow(-2 / s), false)

static func _completion_light_material() -> ShaderMaterial:
	if _shared_light_material == null:
		_shared_light_material = ShaderMaterial.new()
		_shared_light_material.shader = COMPLETION_LIGHT
	return _shared_light_material


func set_ambient_animation(enabled: bool) -> void:
	if _ambient_animation == enabled:
		return
	_invalidate_merged_core()
	_ambient_animation = enabled
	WordArt.set_owner_animation(_picture, enabled)
	_sync_picture_shadow()
	set_merged_presentation(_merged_elapsed, _reduced_motion)


func has_ambient_animation() -> bool:
	return not _projection and (valid_word or jelly_kind == "picture")


func set_merged_presentation(elapsed: float, reduced: bool = false) -> void:
	_merged_elapsed = elapsed
	var still: bool = reduced or not _ambient_animation
	var active: bool = valid_word and not _projection
	if active and (not still or size != _merged_geometry_size or merge_level != _merged_geometry_level \
		or still != _merged_pose_reduced or reduced and _merged_effect_frame != 0.0):
		_invalidate_merged_core()
	if active and _merged_glow == null:
		_merged_glow = TextureRect.new()
		_merged_glow.name = "MergedLight"
		_merged_glow.texture = COMPLETION_GLOW
		_merged_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_merged_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_merged_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_merged_glow.self_modulate.a = 0.25 if match_dimmed else 1.0
		_merged_glow.material = _completion_light_material()
		add_child(_merged_glow)
		move_child(_merged_glow, _visual.get_index())
		for index in range(2):
			var glint: TextureRect = _texture()
			glint.texture = COMPLETION_SPARKLE
			glint.stretch_mode = TextureRect.STRETCH_SCALE
			glint.name = "MergedGlint%d" % index
			glint.self_modulate.a = 0.25 if match_dimmed else 1.0
			_visual.move_child(glint, _picture.get_index())
			_merged_glints.append(glint)
	if active and _merged_effect == null:
		_merged_effect = _texture()
		_merged_effect.name = "MergedLevelEffect"
		_merged_effect.texture = MERGED_EFFECT_ATLAS
		_merged_effect.stretch_mode = TextureRect.STRETCH_SCALE
		_merged_effect.self_modulate.a = 0.25 if match_dimmed else 1.0
		_merged_effect_material = ShaderMaterial.new()
		_merged_effect_material.shader = MERGED_EFFECT_SHADER
		_merged_effect.material = _merged_effect_material
		_visual.move_child(_merged_effect, _picture.get_index())
	if _merged_glow != null:
		var ui_scale: float = Style.ui_scale(self)
		var geometry_changed: bool = size != _merged_geometry_size or ui_scale != _merged_geometry_scale \
			or merge_level != _merged_geometry_level or active != _merged_geometry_active
		if geometry_changed:
			if merge_level != _merged_geometry_level or active != _merged_geometry_active:
				_merged_effect_frame = 0.0
				_merged_effect_material.set_shader_parameter("frame", 0.0)
			_merged_geometry_size = size
			_merged_geometry_scale = ui_scale
			_merged_geometry_level = merge_level
			_merged_geometry_active = active
			_merged_glow.visible = active
			_merged_effect.visible = active
			_merged_effect.size = size * 1.32
			_merged_effect.position = (size - _merged_effect.size) * 0.5
			_merged_effect_material.set_shader_parameter("tier_row", float(maxi(0, merge_level - 1)))
			# The sourced readiness light has fixed geometry between layout changes.
			_merged_glow.size = size * 1.30
			_merged_glow.position = (size - _merged_glow.size) * 0.5 - Vector2(0.0, size.y * 0.025)
			var tint: Color = MERGED_COLORS[clampi(merge_level, 1, WordModel.MAX_MERGE_LEVEL)]
			tint.a = 0.48 + float(maxi(0, merge_level - 1)) * 0.025
			_merged_glow.modulate = tint
			for index in range(_merged_glints.size()):
				var glint: TextureRect = _merged_glints[index]
				glint.visible = active
				glint.size = Vector2.ONE * minf(_unit * (0.19 if index == 0 else 0.15), 15.0 / ui_scale)
				glint.pivot_offset = glint.size * 0.5
				# Readiness accents stay on the gel rim, behind the learning faces.
				glint.position = size * (Vector2(0.04, 0.47) if index == 0 else Vector2(0.96, 0.47)) - glint.size * 0.5
		if active and (geometry_changed or still != _merged_pose_reduced or reduced and _merged_effect_frame != 0.0 \
			or not still and (elapsed != _merged_pose_elapsed or tile_id != _merged_pose_id)):
			var next_frame: float = _merged_effect_frame
			if reduced:
				next_frame = 0.0
			elif not still and not _merged_pose_reduced and _merged_pose_elapsed >= 0.0 and not geometry_changed:
				# A local phase holds its exact pose outside the shared idle cohort.
				# Capped active time also avoids catching up after a hidden page.
				next_frame = fposmod(next_frame + clampf(elapsed - _merged_pose_elapsed, 0.0, 0.1)
					* MERGED_EFFECT_FRAMES / MERGED_EFFECT_SECONDS, MERGED_EFFECT_FRAMES)
			if next_frame != _merged_effect_frame:
				_merged_effect_frame = next_frame
				_merged_effect_material.set_shader_parameter("frame", next_frame)
			for index in range(_merged_glints.size()):
				var glint: TextureRect = _merged_glints[index]
				var twinkle: float = 0.5 if still else (sin(elapsed * TAU / 2.8 + index * PI + tile_id * 0.41) + 1.0) * 0.5
				glint.scale = Vector2.ONE * (1.0 if still else 0.85 + twinkle * 0.20)
				glint.modulate = Color(1.0, 0.98, 0.86, 0.68 + twinkle * 0.24)
		_merged_pose_elapsed = elapsed
		_merged_pose_reduced = still
		_merged_pose_id = tile_id
	if not completion_hint:
		_set_surface_parameter(&"completion_strength", 0.35 if active else 0.0)
		_set_surface_parameter(&"completion_glint", -2.0 if still or not active else -0.3 + fposmod(elapsed + tile_id * 0.13, 4.2) * 0.40)
	_request_merged_core()

func set_completion_hint(active: bool, elapsed: float, reduced: bool, animated: bool = true) -> void:
	var next_hint: bool = active and not _projection
	if next_hint == completion_hint and animated == _completion_animated and reduced == _completion_reduced \
		and (not next_hint or not animated or elapsed == _completion_last_elapsed):
		return
	var was_active: bool = completion_hint
	var was_animated: bool = _completion_animated
	completion_hint = next_hint
	_completion_animated = animated
	_completion_reduced = reduced
	if not completion_hint and not was_active:
		return
	# A newly available target grows in even when the source has been held awhile.
	if completion_hint and (not was_active or elapsed < _completion_last_elapsed):
		_completion_started_at = elapsed
	if completion_hint and was_active and animated and not was_animated:
		# Waking an already enlarged hint starts its breath at the held posture.
		_completion_started_at = minf(_completion_started_at, elapsed - COMPLETION_GROW_SECONDS)
	_completion_last_elapsed = elapsed
	var age: float = maxf(0.0, elapsed - _completion_started_at)
	var previous_scale: float = completion_scale
	var enter: float = smoothstep(0.0, COMPLETION_GROW_SECONDS, age) if animated else 1.0
	var breath: float = (1.0 - cos(maxf(0.0, age - COMPLETION_GROW_SECONDS) * TAU / COMPLETION_BREATH_SECONDS)) * 0.5 if animated and not reduced else 0.0
	# Keep the enlarged resting size throughout every breath while still eligible.
	completion_scale = lerpf(1.0, COMPLETION_HELD_SCALE + breath * COMPLETION_BREATH_AMOUNT, enter) if completion_hint and not reduced else 1.0
	# Only the painted skin breathes. Letters, badges, layout and contact stay fixed.
	if completion_scale != previous_scale:
		_invalidate_idle_cache()
		_base_stretch *= completion_scale / previous_scale
		_surface.scale *= completion_scale / previous_scale
	_set_surface_parameter(&"completion_strength", (0.82 if reduced else 0.7 + enter * 0.25) if completion_hint else 0.35 if valid_word and not _projection else 0.0)
	_set_surface_parameter(&"completion_glint", -2.0 if reduced or not animated or not completion_hint else -0.25 + fposmod(elapsed, 3.0) * 1.35)
	if completion_hint != was_active:
		_refresh_feedback()

func set_match_dimmed(value: bool) -> void:
	value = value and not _projection
	if match_dimmed == value:
		return
	_invalidate_merged_core()
	match_dimmed = value
	# Lower competing material light, keeping learning faces and badges readable.
	_surface.self_modulate = Color(0.68, 0.72, 0.76) if value else Color.WHITE
	if _merged_glow != null:
		_merged_glow.self_modulate.a = 0.25 if value else 1.0
	if _merged_effect != null:
		_merged_effect.self_modulate.a = 0.25 if value else 1.0
	for glint: TextureRect in _merged_glints:
		glint.self_modulate.a = 0.25 if value else 1.0

func set_projection(value: bool) -> void:
	if _projection == value:
		return
	super.set_projection(value)
	if value:
		set_completion_hint(false, 0.0, _reduced_motion)
		set_match_dimmed(false)

func deform(amount: float, beat: float, stretch: Vector2 = Vector2.ONE) -> void:
	super.deform(amount, beat, stretch * completion_scale)

func set_contact(kind_value: String, direction: Vector2 = Vector2.ZERO, strength: float = 0.0, reduced: bool = false) -> void:
	if kind_value == "none" and _contact_kind == "none":
		return
	super.set_contact(kind_value, direction, strength, reduced)
	_sync_picture_shadow()

func _sync_picture_shadow() -> void:
	if _picture_shadow == null:
		return
	var active: bool = is_visible_in_tree() and _picture.visible and _picture.texture != null
	# Share the exact animated atlas; hiding releases the extra reference too.
	var source: Texture2D = _picture.texture if active else null
	if _picture_shadow.texture != source:
		_picture_shadow.texture = source
	_picture_shadow.visible = active
	if not active:
		return
	var pixel: float = 1.0 / Style.ui_scale(self)
	_picture_shadow.size = _picture.size + Vector2.ONE * pixel * 0.7
	_picture_shadow.position = _picture.position + Vector2(-0.35, 0.30) * pixel
	_picture_shadow.z_index = _picture.z_index

func set_palette(index: int, hue: float) -> void:
	palette_index = index
	_set_surface_parameter(&"palette_hue", hue)

func configure(cell: Dictionary, surface: Texture2D, picture: Texture2D, chest: Texture2D, accent: Color, show_both: bool = false) -> void:
	_invalidate_merged_core()
	_authored = not cell.get("composition", {}).is_empty()
	var legacy_complete: bool = not cell.get("word", {}).is_empty() and (_authored or int(cell.get("mass", 1)) > 1)
	jelly_kind = str(cell.get("jelly_kind", "merged" if legacy_complete else "root"))
	valid_word = jelly_kind == "merged" and not cell.get("word", {}).is_empty()
	merge_level = clampi(int(cell.get("merge_level", 1)), 1, WordModel.MAX_MERGE_LEVEL) if valid_word else 0
	requires_read = jelly_kind != "picture" and _authored and bool(cell.get("requires_read", false))
	_spelling = str(cell.get("display_text", cell.get("text", ""))) if jelly_kind != "picture" else ""
	_break_offsets = cell.get("approved_break_offsets", []).duplicate()
	if _spelling.begins_with("-"):
		for index in range(_break_offsets.size()):
			_break_offsets[index] = int(_break_offsets[index]) + 1
	fragments = int(cell.get("fragments", 0))
	var face: Dictionary = cell.duplicate(true)
	face.word = {"text": _spelling} if not valid_word else cell.word
	face.kind = "picture" if jelly_kind == "picture" else "word"
	super.configure(face, surface, picture, chest, accent, valid_word)
	if not _ambient_animation:
		WordArt.set_owner_animation(_picture, false)
	_fragment_texture = chest
	_surface.stretch_mode = TextureRect.STRETCH_SCALE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _fragment_holder == null:
		_fragment_holder = Control.new()
		_fragment_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual.add_child(_fragment_holder)
		for index in range(2):
			var badge: TextureRect = _texture()
			badge.reparent(_fragment_holder, false)
			_fragment_badges.append(badge)
		_fragment_count = Style.label("", 10)
		_fragment_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fragment_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_fragment_count.add_theme_font_override("font", Style.HEADING_FONT)
		_fragment_count.add_theme_color_override("font_color", Color("#674a27"))
		_fragment_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fragment_holder.add_child(_fragment_count)
	var identity: String = "Picture of %s" % str(cell.get("image_word", {}).get("text", cell.get("text", ""))) if jelly_kind == "picture" else _spelling
	var instruction: String = "Drag this root before another root to build a word."
	if valid_word:
		var chance: float = WordModel.coin_drop_chance_for_tile(cell)
		var reward: String = " No bonus coins at this level." if chance <= 0.0 else " %d%% chance of %d bonus coins." % [roundi(chance * 100.0), WordModel.coins_for_tile(cell)]
		instruction = "Merged word, level %d. Press to collect.%s Drag onto the same word to add their levels, capped at %d." % [
			merge_level, reward, int(cell.get("merged_level_limit", WordModel.MAX_MERGE_LEVEL))]
	elif jelly_kind == "picture":
		instruction = "Drag to its complete matching word to merge."
	elif not cell.get("word_candidate", {}).is_empty():
		instruction = "Word assembled. Drag to its matching picture to merge."
	set("accessibility_name", "%s. %s Drag to a fitting empty space to move it. Shift+Enter selects this jelly to merge with another.%s%s" % [identity, instruction,
		" %d chest fragments." % fragments if fragments > 0 else "",
		" Press R while focused to read the full spelling." if jelly_kind != "picture" else ""])
	_layout()
	_refresh_feedback()

func set_chest_texture(texture: Texture2D) -> void:
	super.set_chest_texture(texture)
	_fragment_texture = texture
	_layout()

func _refresh_feedback(reset_motion: bool = false) -> void:
	super._refresh_feedback(reset_motion)
	if completion_hint and _mark < 2 and _contact_kind == "none":
		# A cream inner edge and dark outer edge follow the acquired silhouette.
		_gel.set_shader_parameter("rim_color", Color("#236451"))
		_gel.set_shader_parameter("rim_strength", 1.0)
		_gel.set_shader_parameter("rim_width", 1.8)
	elif valid_word and not _projection and _mark == 0 and _contact_kind == "none":
		_gel.set_shader_parameter("rim_color", MERGED_COLORS[merge_level].darkened(0.12))
		_gel.set_shader_parameter("rim_strength", 1.0)
		_gel.set_shader_parameter("rim_width", 1.65)

func _layout() -> void:
	if _visual == null:
		return
	_invalidate_merged_core()
	super._layout()
	_badge.hide()
	_surface.stretch_mode = TextureRect.STRETCH_SCALE
	_unit = minf(size.y, size.x)
	_layout_fragment_badge()
	_layout_level_badge()
	_read_button.hide()
	_layout_compact_label()
	set_merged_presentation(_merged_elapsed, _reduced_motion)
	_sync_picture_shadow()

func _layout_compact_label() -> void:
	var s: float = Style.ui_scale(self)
	var font: Font = _label.get_theme_font("font")
	var has_picture: bool = _picture.texture != null and (valid_word or jelly_kind == "picture")
	_picture.visible = has_picture and not _projection
	_label.visible = jelly_kind != "picture" and not _projection
	if jelly_kind == "picture":
		requires_read = false
		_label.text = ""
		tooltip_text = "Match this picture to its word."
		_picture.size = size * 0.84
		_picture.position = (size - _picture.size) * 0.5 - Vector2(0.0, size.y * 0.025)
		if fragments > 0:
			# A compact reward corner leaves most of the clue's body available.
			_picture.size = size * 0.74
			_picture.position = Vector2(size.x * 0.13, size.y * 0.23)
		_layout_corner_fragments()
		return
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var inset: float = size.x * 0.10
	var label_top: float = size.y * (0.54 if has_picture else 0.36 if fragments > 0 or merge_level > 1 else 0.21)
	var label_bottom: float = size.y * (0.85 if has_picture else 0.89 if fragments > 0 or merge_level > 1 else 0.79)
	var label_size := Vector2(size.x - inset * 2.0, label_bottom - label_top)
	var minimum: int = ceili(13.0 / s)
	var pixels: int = maxi(minimum, mini(roundi(_unit * (0.25 if has_picture else 0.34)), ceili((22.0 if has_picture else 28.0) / s)))
	var lines: Array = [_spelling]
	# Fit at authored boundaries only. The body never grows with spelling length.
	while pixels >= minimum:
		var maximum_lines: int = maxi(1, floori(label_size.y / font.get_height(pixels)))
		var fit: Dictionary = Footprint._wrap(_spelling, font, _break_offsets,
			maxf(0.0, label_size.x - 1.0 / s) * float(Footprint.FONT_SIZE) / pixels, maximum_lines)
		if fit.ok:
			lines = fit.lines
			break
		if pixels == minimum:
			break
		pixels -= 1
	requires_read = false
	for line: String in lines:
		requires_read = requires_read or font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > label_size.x + 0.01
	tooltip_text = _spelling + ("\nHold to read. Keyboard: R." if requires_read else "\nKeyboard: R to read.")
	_label.add_theme_font_size_override("font_size", pixels)
	_label.text = "\n".join(lines)
	# Apply font and text first so Label's minimum height reflects this layout.
	_label.position = Vector2(inset, label_top)
	_label.size = Vector2(label_size.x, maxf(label_size.y, font.get_height(pixels) * lines.size()))
	if _label.get_rect().end.y > size.y * 0.89:
		_label.position.y = maxf(size.y * 0.10, size.y * 0.89 - _label.size.y)
	_layout_corner_fragments()
	var picture_top: float = size.y * 0.055
	var picture_left: float = size.x * 0.08
	var picture_right: float = size.x * 0.92
	if fragments > 0 and _fragment_holder != null:
		# Reserve the full receive bounce, not only the currently painted badge.
		var extent: Vector2 = _fragment_holder.size * float(_fragment_holder.get_meta("fit", 1.0))
		picture_left = size.x * 0.02 + extent.x * 1.06 + 1.0 / s
	if merge_level > 1 and _level_badge != null:
		picture_right = _level_badge.position.x - 1.0 / s
	var picture_edge: float = maxf(0.0, minf(picture_right - picture_left, _label.position.y - picture_top - 1.0 / s))
	_picture.size = Vector2.ONE * picture_edge
	_picture.position = Vector2((picture_left + picture_right - picture_edge) * 0.5, picture_top)

func _layout_corner_fragments() -> void:
	if _fragment_holder == null or fragments <= 0:
		return
	# The left corner remains separate from the level numeral on the right.
	# Neither badge borrows the word caption's row or its centered picture.
	var extent: Vector2 = _fragment_holder.size
	var top: float = size.y * (0.02 if jelly_kind == "picture" else 0.08)
	var height: float = size.y * (0.18 if jelly_kind == "picture" else 0.21)
	if jelly_kind != "picture":
		# Short landscape bodies lift the caption to preserve its reading floor.
		# Reserve the same actual caption edge for the badge and its receive pop.
		height = minf(height, maxf(0.0, _label.position.y - top - 1.0 / Style.ui_scale(self)) / 1.06)
	var fit: float = minf(1.0, minf(size.x * 0.25 / maxf(1.0, extent.x), height / maxf(1.0, extent.y)))
	_fragment_holder.set_meta("fit", fit)
	_fragment_holder.position = Vector2(size.x * 0.02, top) - extent * (1.0 - fit) * 0.5
	set_fragment_arrival(_fragment_arrival_age, _reduced_motion)

func _layout_level_badge() -> void:
	if _level_badge == null:
		return
	_level_badge.visible = valid_word and merge_level > 1 and not _projection
	_level_badge.text = str(merge_level) if merge_level > 1 else ""
	var ui_scale: float = Style.ui_scale(self)
	var pixels: int = maxi(ceili(10.0 / ui_scale), roundi(minf(_unit * 0.20, 15.0 / ui_scale)))
	_level_badge.add_theme_font_size_override("font_size", pixels)
	var edge: float = maxf(Style.HEADING_FONT.get_height(pixels), minf(_unit * 0.28, 21.0 / ui_scale))
	# A single numeral needs its glyph width and padding, not a full square.
	var width: float = maxf(Style.HEADING_FONT.get_string_size(_level_badge.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + 4.0 / ui_scale, edge * 0.70)
	_level_badge.size = Vector2(width, edge)
	_level_badge.position = Vector2(size.x * 0.98 - width, size.y * 0.08)
	var badge := Style.box(Color("#4d4565"), MERGED_COLORS[clampi(merge_level, 1, WordModel.MAX_MERGE_LEVEL)], ceili(edge * 0.42), maxi(1, roundi(1.2 / ui_scale)))
	badge.set_content_margin_all(0.0)
	_level_badge.add_theme_stylebox_override("normal", badge)
	_level_badge.set("accessibility_name", "Level %d" % merge_level)

func _layout_fragment_badge() -> void:
	if _fragment_holder == null:
		return
	_fragment_holder.visible = fragments > 0 and not _projection
	var ui_scale: float = Style.ui_scale(self)
	var edge: float = minf(_unit * 0.28, 28.0 / ui_scale)
	var stacked: bool = fragments > 1
	var offset := Vector2(edge * 0.25, edge * 0.10) if stacked else Vector2.ZERO
	var extent := Vector2.ONE * edge + offset
	for index in range(_fragment_badges.size()):
		var badge: TextureRect = _fragment_badges[index]
		badge.texture = _fragment_texture
		badge.visible = not _projection and index < mini(fragments, 2)
		badge.size = Vector2.ONE * edge
		badge.position = offset if index == 1 else Vector2.ZERO
		badge.modulate = Color(0.93, 0.96, 0.95, 0.85) if stacked and index == 0 else Color.WHITE
	_fragment_count.visible = fragments > 2 and not _projection
	_fragment_count.text = str(fragments) if fragments > 2 else ""
	if fragments > 2:
		var pixels: int = maxi(8, roundi(minf(_unit * 0.21, 15.0 / ui_scale)))
		_fragment_count.add_theme_font_size_override("font_size", pixels)
		var height: float = maxf(edge * 0.76, Style.HEADING_FONT.get_height(pixels))
		var width: float = maxf(height, Style.HEADING_FONT.get_string_size(_fragment_count.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + edge * 0.36)
		extent.y = maxf(extent.y, height)
		_fragment_count.position = Vector2(extent.x - edge * 0.13, extent.y - height)
		_fragment_count.size = Vector2(width, height)
		var paper := Style.box(Color("#fff7e4"), Color("#d9bd82"), ceili(height * 0.5), maxi(1, roundi(1.0 / ui_scale)))
		paper.set_content_margin_all(0.0)
		_fragment_count.add_theme_stylebox_override("normal", paper)
		extent.x = _fragment_count.position.x + width
	_fragment_holder.size = extent
	_fragment_holder.pivot_offset = extent * 0.5
	_fragment_holder.position = Vector2(size.x * 0.91 - extent.x, size.y * 0.96 - extent.y)
	# Keep even unusually large totals inside the jelly, including its receive pop.
	var fit: float = minf(1.0, minf(size.x * 0.80 / maxf(1.0, extent.x), size.y * 0.34 / maxf(1.0, extent.y)))
	_fragment_holder.set_meta("fit", fit)
	if fit < 1.0:
		_fragment_holder.position = Vector2(size.x * 0.51, size.y * 0.79) - extent * 0.5
	set_fragment_arrival(_fragment_arrival_age, _reduced_motion)

func set_fragment_arrival(age: float, reduced: bool = false) -> void:
	_fragment_arrival_age = age
	if _fragment_holder == null:
		return
	var pop: float = 0.0
	if age >= 0.0 and age < 0.48 and not reduced:
		pop = sin(minf(age / 0.11, 1.0) * PI * 0.5) * exp(-maxf(0.0, age - 0.11) * 10.0)
	var target_scale := Vector2.ONE * float(_fragment_holder.get_meta("fit", 1.0)) * (1.0 + pop * 0.12)
	if _fragment_holder.scale != target_scale:
		_invalidate_merged_core()
		_fragment_holder.scale = target_scale


func set_idle_cached(enabled: bool) -> void:
	_merged_core_allowed = enabled
	super.set_idle_cached(enabled)
	if enabled:
		_request_merged_core()
	else:
		_invalidate_merged_core()


func _merged_body_paint_changed() -> void:
	_invalidate_merged_core()
	_request_merged_core()


func _merged_visibility_changed() -> void:
	_invalidate_merged_core()
	_request_merged_core()


func _merged_core_eligible() -> bool:
	return _merged_core_enabled and _merged_core_allowed and is_inside_tree() and is_visible_in_tree() \
		and valid_word and not _projection and not _ambient_animation and z_index == 1 \
		and _mark == 0 and _contact_kind == "none" and not has_focus() and not is_hovered() \
		and (not completion_hint or not _completion_animated or _completion_reduced) \
		and (_fragment_arrival_age < 0.0 or _fragment_arrival_age >= 0.48 or _reduced_motion) \
		and _idle_cache_requested and _surface.material != _gel and _idle_cache_eligible()


func set_merged_core_cache_enabled(enabled: bool) -> void:
	_merged_core_enabled = enabled
	if enabled:
		_request_merged_core()
	else:
		_invalidate_merged_core()


func _request_merged_core() -> void:
	if _merged_core_requested or _merged_core_rejected_revision == _merged_core_revision \
		or not _merged_core_eligible():
		return
	var pool = MergedCoreCache.obtain(get_viewport())
	if pool == null:
		return
	var request: Dictionary = pool.request(self, _merged_core_revision)
	if request.is_empty():
		return
	_merged_core_requested = true
	_merged_core_key = request.key
	_merged_core_pool = weakref(pool)
	if request.texture != null:
		_merged_core_ready(request.key, request.texture, request.bounds)


func _invalidate_merged_core() -> void:
	_merged_core_revision += 1
	for subject: CanvasItem in _merged_core_hidden:
		if is_instance_valid(subject):
			RenderingServer.canvas_item_set_visible(subject.get_canvas_item(), subject.is_visible_in_tree())
	_merged_core_hidden.clear()
	if _merged_core_proxy != null:
		_merged_core_proxy.hide()
	_merged_core_texture = null
	_merged_core_requested = false
	_merged_core_key = ""
	if _merged_core_pool != null:
		var pool: Node = _merged_core_pool.get_ref()
		if is_instance_valid(pool) and not pool.is_queued_for_deletion():
			pool.release(self)
	_merged_core_pool = null


func _reject_merged_core() -> void:
	_invalidate_merged_core()
	_merged_core_rejected_revision = _merged_core_revision


func _core_painted_nodes(subject: Node, result: Array[Control]) -> void:
	if subject == _label or subject == _level_badge or subject == _fragment_holder:
		return
	if subject is TextureRect or subject is Label:
		var control: Control = subject
		if control.is_visible_in_tree():
			result.append(control)
	for child: Node in subject.get_children():
		_core_painted_nodes(child, result)


func _render_global_transform(subject: CanvasItem) -> Transform2D:
	var transform := Transform2D.IDENTITY
	var ancestor: Node = subject
	var snap: bool = get_viewport().is_snap_controls_to_pixels_enabled()
	while ancestor is CanvasItem:
		var canvas: CanvasItem = ancestor
		var local: Transform2D = canvas.get_transform()
		var gui: Control = canvas as Control
		if snap and gui != null and absf(sin(gui.rotation * 4.0)) < 0.00001:
			local.origin = (local.origin + Vector2(0.5, 0.5)).floor()
		transform = local * transform
		ancestor = ancestor.get_parent()
	# Embedded windows omit content stretch from their popup/screen transform.
	# The viewport transform includes the actual canvas backing-pixel scale.
	return subject.get_viewport_transform() * transform


func _capture_merged_core() -> Dictionary:
	var painted: Array[Control] = []
	if _merged_glow != null:
		_core_painted_nodes(_merged_glow, painted)
	_core_painted_nodes(_visual, painted)
	var sources: Array[Dictionary] = []
	var bounds := Rect2()
	for source: Control in painted:
		var transform: Transform2D = _render_global_transform(source)
		var extent: Rect2 = Rect2(Vector2.ZERO, source.size)
		if source == _surface:
			var paint_material: ShaderMaterial = source.material as ShaderMaterial
			var mesh: Variant = paint_material.get_shader_parameter("mesh_scale")
			var expansion: float = 1.0 if mesh == null else float(mesh)
			extent = Rect2(source.size * (1.0 - expansion) * 0.5, source.size * expansion)
		if source is Label:
			extent = extent.grow(maxf(2.0, source.get_theme_constant("outline_size")))
		var source_bounds: Rect2 = transform * extent
		bounds = source_bounds if not bounds.has_area() else bounds.merge(source_bounds)
		var tint: Color = source.self_modulate
		var ancestor: Node = source
		while ancestor is CanvasItem:
			var canvas: CanvasItem = ancestor
			tint *= canvas.modulate
			ancestor = ancestor.get_parent()
		sources.append({"node": source, "transform": transform, "color": tint})
	var origin: Vector2 = bounds.position.floor()
	bounds = Rect2(origin, bounds.end.ceil() - origin)
	return {"bounds": bounds, "sources": sources}


func _merged_core_ready(key: String, texture: Texture2D, bounds: Rect2) -> void:
	if not _merged_core_requested or _merged_core_key != key or not _merged_core_eligible():
		return
	_merged_core_texture = texture
	_merged_core_size = bounds.size
	var screen := Transform2D.IDENTITY
	screen.origin = bounds.position
	_merged_core_proxy.transform = _render_global_transform(self).affine_inverse() * screen
	var painted: Array[Control] = []
	if _merged_glow != null:
		_core_painted_nodes(_merged_glow, painted)
	_core_painted_nodes(_visual, painted)
	# Preserve logical visibility, layout, accessibility and source resources.
	# Only the rendering server hides paint replaced by the same tile's proxy.
	for subject: Control in painted:
		RenderingServer.canvas_item_set_visible(subject.get_canvas_item(), false)
		_merged_core_hidden.append(subject)
	_merged_core_proxy.show()
	_merged_core_proxy.queue_redraw()


func _draw_merged_core() -> void:
	if _merged_core_texture != null:
		_merged_core_proxy.draw_texture_rect(_merged_core_texture, Rect2(Vector2.ZERO, _merged_core_size), false)


func merged_core_snapshot() -> Dictionary:
	var pool: Node = _merged_core_pool.get_ref() if _merged_core_pool != null else null
	return {"cached": _merged_core_proxy.is_visible_in_tree(), "requested": _merged_core_requested,
		"revision": _merged_core_revision, "size": [_merged_core_size.x, _merged_core_size.y],
		"atlas": pool.snapshot() if is_instance_valid(pool) else {}}


func _exit_tree() -> void:
	_invalidate_merged_core()
	super._exit_tree()

func fragment_badge_snapshot() -> Dictionary:
	if _fragment_holder == null:
		return {"icons": 0, "count_text": "", "rect": [0.0, 0.0, 0.0, 0.0], "visible": false, "scale": 1.0}
	var extent: Vector2 = _fragment_holder.size * _fragment_holder.scale
	var origin: Vector2 = _fragment_holder.position + _fragment_holder.pivot_offset * (Vector2.ONE - _fragment_holder.scale)
	return {"icons": visible_fragment_badges(), "count_text": _fragment_count.text if _fragment_count.visible else "",
		"rect": [origin.x, origin.y, extent.x, extent.y], "visible": _fragment_holder.visible,
		"scale": _fragment_holder.scale.x}

func visible_fragment_badges() -> int:
	return mini(fragments, 2) if not _projection else 0

func presentation_snapshot() -> Dictionary:
	return {"jelly_kind": jelly_kind, "merge_level": merge_level, "display_text": _spelling,
		"merged_effect": {"visible": _merged_effect != null and _merged_effect.is_visible_in_tree(),
			"id": MERGED_EFFECT_IDS[merge_level - 1] if valid_word else "",
			"level": merge_level, "animated": valid_word and not _projection and is_visible_in_tree() and _ambient_animation and not _merged_pose_reduced,
			"frame": _merged_effect_frame, "atlas": MERGED_EFFECT_ATLAS.resource_path},
		"picture_only": jelly_kind == "picture" and _picture.visible and not _label.visible,
		"merged_light": _merged_glow != null and _merged_glow.visible,
		"merged_glints": _merged_glints.size() if valid_word and not _projection else 0,
		"level_badge": _level_badge.text if _level_badge != null and _level_badge.visible else "",
		"level_badge_rect": [_level_badge.position.x, _level_badge.position.y, _level_badge.size.x, _level_badge.size.y] if _level_badge != null else [],
		"read_available": requires_read and jelly_kind != "picture"}

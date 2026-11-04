extends Control
## View-only target samples use the same selector as real campaign collections.

const Style = preload("res://scripts/ui_style.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Tile = preload("res://scripts/word_jelly_tile.gd")
const WordArt = preload("res://scripts/word_art.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")
const QUIET_SKIN = preload("res://assets/images/jelly-match/gel-sky.png")
const QUIET_ALT = preload("res://assets/images/jelly-match/gel-lilac.png")
const GLOW = preload("res://assets/chests/shared/effects/portal_glow.png")
const SPARKLE = preload("res://assets/chests/shared/effects/sparkle.png")
const WAND = preload("res://assets/images/ui/jelly-powerups/auto-merge-wand.svg")
const NAMES: Array[String] = ["", "Little spark", "Neighbor burst", "Wider burst",
	"Surrounding burst", "Column burst", "Cross burst", "Extended ring", "Double ring", "Board burst"]

var reduced_motion := false
var _kind := "jelly"
var _level := 1
var _elapsed := 0.0
var _model := Model.new()
var _origin := Vector2i(Model.COLUMNS / 2, Model.ROWS / 2)
var _targets: Array[int] = []
var _jelly := Tile.new()
var _picture: Texture2D
var _pitch := 1.0
var _board := Rect2()
var _backplate := StyleBoxFlat.new()
var _source_center := Vector2.ZERO
var _cell_centers := PackedVector2Array()
var _cell_marked := PackedByteArray()
var _cell_distances := PackedFloat32Array()
var _glint_indices := PackedInt32Array()
var _target_lookup: Dictionary = {}
var _auto_centers := PackedVector2Array()
var _auto_pitch := 1.0
var _wand_rect := Rect2()
var _charge_energy := 0.0
var _paid_pulse := 0.0
var _upgrade_payoff := 0.0
var _upgrade_clock := 0.0


func _init() -> void:
	name = "JellyAbilityPreview"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jelly.disabled = true
	_jelly.focus_mode = Control.FOCUS_NONE
	_jelly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_jelly)
	_backplate.bg_color = Color("#25233c", 0.70)
	_backplate.border_color = Color("#9b93c4", 0.24)
	_backplate.set_border_width_all(1)
	resized.connect(_layout)


func present(level: int, word: Dictionary, steady: bool) -> bool:
	if level < 1 or level > 9 or word.is_empty() or str(word.get("text", "")).is_empty():
		push_error("A Jelly ability preview needs a real word and a level from 1 to 9.")
		return false
	_level = level
	_kind = "jelly"
	_elapsed = 0.0
	reduced_motion = steady
	_picture = WordArt.texture(str(word.get("image", "")), self)
	_jelly.configure({"id": 1000, "word": word, "text": word.text, "jelly_kind": "merged",
		"merge_level": level, "fragments": 0, "merged_level_limit": 9}, SKIN, _picture, null, Style.GOOD, true)
	_model.cells.clear()
	for row in range(Model.ROWS):
		for column in range(Model.COLUMNS):
			_model.cells.append({"id": row * Model.COLUMNS + column + 1,
				"column": column, "row": row, "width": 1, "height": 1,
				"age": 100.0, "settling": false, "falling": false, "arrival": false})
	_model._campaign_level_rules = true
	_model._blast_rng.seed = 812
	var source: Dictionary = _model.cells[_origin.y * Model.COLUMNS + _origin.x]
	_targets = _model._blast_target_ids(source, level)
	_target_lookup.clear()
	for target: int in _targets:
		_target_lookup[target] = true
	_jelly.set_merged_presentation(0.0, reduced_motion)
	_jelly.show()
	_layout()
	set("accessibility_name", "Lv%d. %s. %s %s" % [level, NAMES[level], description(), coin_description()])
	queue_redraw()
	return true


func present_auto_merge(level: int, word: Dictionary, steady: bool) -> bool:
	if level < 1 or level > Economy.MAX_UPGRADE_LEVEL or word.is_empty():
		push_error("An Auto merge preview needs real Jelly artwork and a level from 1 to 9.")
		return false
	_kind = "auto_merge"
	_level = level
	_elapsed = 0.0
	reduced_motion = steady
	_picture = WordArt.texture(str(word.get("image", "")), self)
	_jelly.hide()
	_layout()
	set("accessibility_name", "Auto merge Lv%d. %s %s" % [level, description(), coin_description()])
	queue_redraw()
	return true


func description() -> String:
	if _kind == "auto_merge":
		return "Finish up to %d Jellies.\nEach result is ready to collect." \
			% Economy.auto_merge_capacity(_level)
	var reach: String = "up to %d nearby Jellies" % _targets.size() if _level <= 4 \
		else "its entire column" if _level == 5 else "its row and column" if _level == 6 \
		else "the inner ring and 4 outer Jellies" if _level == 7 \
		else "two rings, up to 22 Jellies" if _level == 8 else "the whole board"
	return "Collect it to mark %s.\nMarked pieces find legal partners and merge automatically." % reach


func coin_description() -> String:
	if _kind == "auto_merge":
		return "Saved across rounds. Use costs 600 / 900 / 1200 coins."
	var bonus: String = "No pickup coin bonus" if _level == 1 else "%d%% chance of +%d coins" % [
		roundi(Economy.jelly_bonus_chance(_level) * 100.0), Economy.jelly_bonus(_level)]
	return "%s  ·  Base Boss hit: %d" % [bonus, BossCatalog.DAMAGE[_level]]


func advance(delta: float) -> void:
	if not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	if not reduced_motion:
		_elapsed += minf(delta, 0.1)
		_upgrade_clock += minf(delta, 0.1)
	_jelly.set_merged_presentation(_elapsed, reduced_motion)
	queue_redraw()


func set_charge_feedback(energy: float, paid_pulse: float) -> void:
	_charge_energy = clampf(energy, 0.0, 1.0) if is_finite(energy) else 0.0
	_paid_pulse = clampf(paid_pulse, 0.0, 1.0) if is_finite(paid_pulse) else 0.0
	queue_redraw()


func set_upgrade_feedback(payoff: float) -> void:
	var next: float = clampf(payoff, 0.0, 1.0) if is_finite(payoff) else 0.0
	if next > 0.001 and _upgrade_payoff <= 0.001:
		_upgrade_clock = 0.0
	_upgrade_payoff = next
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	if value == reduced_motion:
		return
	reduced_motion = value
	_jelly.set_merged_presentation(_elapsed, reduced_motion)
	queue_redraw()


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_pitch = minf(size.x / (Model.COLUMNS + 0.7), size.y / (Model.ROWS + 0.7))
	_board = Rect2((size - Vector2(Model.COLUMNS, Model.ROWS) * _pitch) * 0.5,
		Vector2(Model.COLUMNS, Model.ROWS) * _pitch)
	_backplate.set_corner_radius_all(roundi(_pitch * 0.42))
	_source_center = _board.position + (Vector2(_origin) + Vector2.ONE * 0.5) * _pitch
	_jelly.size = Vector2.ONE * _pitch * 1.18
	_jelly.position = _source_center - _jelly.size * 0.5
	# The stage carries the readable word and level; the miniature keeps one clear face.
	_jelly._label.hide()
	_jelly._level_badge.hide()
	_jelly._picture.size = _jelly.size * 0.70
	_jelly._picture.position = (_jelly.size - _jelly._picture.size) * 0.5
	_jelly._sync_picture_shadow()
	_cache_board_geometry()
	_layout_auto_merge()
	queue_redraw()


func _cache_board_geometry() -> void:
	_cell_centers.clear()
	_cell_marked.clear()
	_cell_distances.clear()
	_glint_indices.clear()
	var marked_indices := PackedInt32Array()
	var farthest := 1.0
	for cell: Dictionary in _model.cells:
		if int(cell.column) == _origin.x and int(cell.row) == _origin.y:
			continue
		var at: Vector2 = _board.position + Vector2(float(cell.column) + 0.5, float(cell.row) + 0.5) * _pitch
		var marked: bool = _target_lookup.has(int(cell.id))
		if marked:
			marked_indices.append(_cell_centers.size())
			farthest = maxf(farthest, at.distance_to(_source_center))
		_cell_centers.append(at)
		_cell_marked.append(1 if marked else 0)
		_cell_distances.append(at.distance_to(_source_center))
	for index in range(_cell_distances.size()):
		_cell_distances[index] /= farthest
	# A wide burst changes every target's skin, with only eight traveling accents.
	var accents: int = mini(8, marked_indices.size())
	for index in range(accents):
		_glint_indices.append(marked_indices[floori(float(index) * marked_indices.size() / accents)])


func _layout_auto_merge() -> void:
	_auto_centers.clear()
	var capacity: int = Economy.auto_merge_capacity(_level)
	var columns: int = mini(4, capacity)
	var rows: int = ceili(float(capacity) / columns)
	_auto_pitch = minf(64.0, minf(size.x / (columns + 0.65), size.y / (rows + 1.75)))
	var top: float = (size.y - _auto_pitch * (rows + 1.45)) * 0.5
	var wand_edge: float = _auto_pitch * 0.95
	_wand_rect = Rect2(Vector2((size.x - wand_edge) * 0.5, top), Vector2.ONE * wand_edge)
	for index in range(capacity):
		var row: int = index / columns
		var count: int = mini(columns, capacity - row * columns)
		_auto_centers.append(Vector2((size.x - count * _auto_pitch) * 0.5 + (index % columns + 0.5) * _auto_pitch,
			top + _auto_pitch * (row + 1.8)))


func _draw() -> void:
	if not _board.has_area():
		return
	if _kind == "auto_merge":
		_draw_auto_merge()
		return
	draw_style_box(_backplate, _board.grow(_pitch * 0.25))
	var age: float = fposmod(_elapsed, 3.6)
	var fade: float = 1.0 if reduced_motion else 1.0 - smoothstep(3.0, 3.6, age)
	var edge: float = _pitch * 0.86
	for index in range(_cell_centers.size()):
		var at: Vector2 = _cell_centers[index]
		var marked: bool = _cell_marked[index] == 1
		var reveal: float = 1.0 if reduced_motion else smoothstep(0.28 + _cell_distances[index] * 0.68,
			0.52 + _cell_distances[index] * 0.68, age) * fade
		var lit: float = reveal if marked else 0.0
		var skin: Texture2D = SKIN if marked and lit > 0.08 else QUIET_SKIN if index % 2 == 0 else QUIET_ALT
		var tint := Color(0.88, 0.90, 1.0, 0.42)
		if marked:
			tint = tint.lerp(Color(1.0, 0.98, 0.80, 0.96), lit)
			tint.a += _charge_energy * 0.04
		draw_texture_rect(skin, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, tint)
	var glow_edge: float = _pitch * (1.85 + _charge_energy * 0.35 + _paid_pulse * 0.12)
	draw_texture_rect(GLOW, Rect2(_source_center - Vector2.ONE * glow_edge * 0.5, Vector2.ONE * glow_edge),
		false, Color(0.80, 1.0, 0.86, 0.24 + _charge_energy * 0.28 + _paid_pulse * 0.12))
	for order in range(_glint_indices.size()):
		var index: int = _glint_indices[order]
		var target: Vector2 = _cell_centers[index]
		var flight: float = 1.0 if reduced_motion else smoothstep(0.25, 0.60 + _cell_distances[index] * 0.68, age)
		var at: Vector2 = _source_center.lerp(target, flight)
		var light: float = fade * (0.50 if flight >= 1.0 else sin(flight * PI) * 0.78)
		if light <= 0.01:
			continue
		var glint_edge: float = edge * (0.35 if flight >= 1.0 else 0.56)
		draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * glint_edge * 0.5, Vector2.ONE * glint_edge),
			false, Color(1.0, 0.94, 0.65, light))
	_draw_upgrade_flash(_source_center, _pitch)


func _draw_auto_merge() -> void:
	var age: float = fposmod(_elapsed, 3.6)
	var wand_center: Vector2 = _wand_rect.get_center()
	var light_edge: float = _auto_pitch * (1.5 + _charge_energy * 0.4)
	draw_texture_rect(GLOW, Rect2(wand_center - Vector2.ONE * light_edge * 0.5, Vector2.ONE * light_edge),
		false, Color(0.83, 0.73, 1.0, 0.28 + _charge_energy * 0.28 + _paid_pulse * 0.12))
	draw_texture_rect(WAND, _wand_rect, false, Color("#e8c9ff"))
	for index in range(_auto_centers.size()):
		var arrive: float = 1.0 if reduced_motion else smoothstep(0.22 + index * 0.065, 0.52 + index * 0.065, age)
		var at: Vector2 = _auto_centers[index] - Vector2(0.0, (1.0 - arrive) * _auto_pitch * 0.18)
		var edge: float = _auto_pitch * lerpf(0.72, 0.88, arrive)
		var tint := Color(1.0, 1.0, 1.0, 0.30 + arrive * 0.70)
		draw_texture_rect(SKIN if arrive > 0.2 else QUIET_SKIN,
			Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, tint)
		if _picture != null:
			draw_texture_rect(_picture, Rect2(at - Vector2.ONE * edge * 0.29, Vector2.ONE * edge * 0.58), false, tint)
		if index < 8 and arrive > 0.95:
			var glint_edge: float = edge * 0.30
			var glint_at: Vector2 = at + Vector2(edge * 0.31, -edge * 0.27)
			draw_texture_rect(SPARKLE, Rect2(glint_at - Vector2.ONE * glint_edge * 0.5, Vector2.ONE * glint_edge),
				false, Color(1.0, 0.95, 0.73, 0.55 + _charge_energy * 0.15))
	_draw_upgrade_flash(wand_center, _auto_pitch)


func _draw_upgrade_flash(center: Vector2, pitch: float) -> void:
	if _upgrade_payoff <= 0.001:
		return
	var expand: float = 0.45 if reduced_motion else smoothstep(0.0, 0.65, _upgrade_clock)
	var edge: float = pitch * lerpf(1.5, 4.0, expand)
	draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false,
		Color(1.0, 0.88, 0.50, _upgrade_payoff * 0.52))
	for index in range(6):
		var angle: float = float(index) * TAU / 6.0 - PI * 0.5
		var at: Vector2 = center + Vector2.from_angle(angle) * pitch * lerpf(0.35, 1.65, expand)
		var sparkle_edge: float = pitch * (0.24 + _upgrade_payoff * 0.18)
		draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * sparkle_edge * 0.5, Vector2.ONE * sparkle_edge),
			false, Color(1.0, 0.96, 0.77, _upgrade_payoff * 0.90))


func snapshot() -> Dictionary:
	var targets: Array = []
	for cell: Dictionary in _model.cells:
		if int(cell.id) in _targets:
			targets.append({"column": cell.column, "row": cell.row})
	return {"kind": _kind, "level": _level, "name": "Auto merge" if _kind == "auto_merge" else NAMES[_level],
		"capacity": Economy.auto_merge_capacity(_level) if _kind == "auto_merge" else 0,
		"columns": Model.COLUMNS, "rows": Model.ROWS,
		"origin": [_origin.x, _origin.y], "target_count": _targets.size(), "targets": targets,
		"description": description(), "coins": coin_description(), "reduced_motion": reduced_motion,
		"elapsed": _elapsed}

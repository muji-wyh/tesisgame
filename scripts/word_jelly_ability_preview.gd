extends Control
## View-only target samples use the same selector as real campaign collections.

const Style = preload("res://scripts/ui_style.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Tile = preload("res://scripts/word_jelly_tile.gd")
const WordArt = preload("res://scripts/word_art.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
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


func _init() -> void:
	name = "JellyAbilityPreview"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jelly.disabled = true
	_jelly.focus_mode = Control.FOCUS_NONE
	_jelly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_jelly)
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
	_jelly.set_merged_presentation(_elapsed, reduced_motion)
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
	_pitch = minf(size.x / Model.COLUMNS, size.y / Model.ROWS)
	_board = Rect2((size - Vector2(Model.COLUMNS, Model.ROWS) * _pitch) * 0.5,
		Vector2(Model.COLUMNS, Model.ROWS) * _pitch)
	_jelly.size = Vector2.ONE * _pitch * 0.90
	_jelly.position = _board.position + (Vector2(_origin) + Vector2.ONE * 0.5) * _pitch - _jelly.size * 0.5
	queue_redraw()


func _draw() -> void:
	if not _board.has_area():
		return
	if _kind == "auto_merge":
		_draw_auto_merge()
		return
	var age: float = fposmod(_elapsed, 3.2)
	var progress: float = 1.0 if reduced_motion else smoothstep(0.35, 1.25, age)
	var center: Vector2 = _board.position + (Vector2(_origin) + Vector2.ONE * 0.5) * _pitch
	for cell: Dictionary in _model.cells:
		if int(cell.column) == _origin.x and int(cell.row) == _origin.y:
			continue
		var at: Vector2 = _board.position + Vector2(float(cell.column) + 0.5, float(cell.row) + 0.5) * _pitch
		var edge: float = _pitch * 0.86
		var marked: bool = int(cell.id) in _targets
		draw_texture_rect(SKIN, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
			false, Color(1, 1, 1, 0.86 if marked else 0.18))
		if _picture != null:
			draw_texture_rect(_picture, Rect2(at - Vector2.ONE * edge * 0.27, Vector2.ONE * edge * 0.54),
				false, Color(1, 1, 1, 0.8 if marked else 0.13))
		if not marked:
			continue
		var light: Vector2 = center.lerp(at, progress)
		draw_texture_rect(GLOW, Rect2(light - Vector2.ONE * edge * 0.6, Vector2.ONE * edge * 1.2),
			false, Color(1.0, 0.87, 0.50, 0.65))
		if progress >= 1.0:
			draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.23, Vector2.ONE * edge * 0.46),
				false, Color("#fff1b0"))


func _draw_auto_merge() -> void:
	var capacity: int = Economy.auto_merge_capacity(_level)
	var columns: int = mini(4, capacity)
	var rows: int = ceili(float(capacity) / columns)
	var pitch: float = minf(64.0, minf(size.x / (columns + 0.5), size.y / (rows + 1.4)))
	var wand_edge: float = pitch * 0.85
	var top: float = (size.y - pitch * (rows + 1.2)) * 0.5
	draw_texture_rect(WAND, Rect2(Vector2((size.x - wand_edge) * 0.5, top), Vector2.ONE * wand_edge),
		false, Color("#8e68b5"))
	for index in range(capacity):
		var row: int = index / columns
		var count: int = mini(columns, capacity - row * columns)
		var at := Vector2((size.x - count * pitch) * 0.5 + (index % columns + 0.5) * pitch,
			top + pitch * (row + 1.65))
		var edge: float = pitch * 0.86
		draw_texture_rect(SKIN, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false)
		if _picture != null:
			draw_texture_rect(_picture, Rect2(at - Vector2.ONE * edge * 0.29, Vector2.ONE * edge * 0.58), false)


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

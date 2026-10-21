extends SceneTree
## Hybrid word faces retain one ordinary square and preserve picture-only clues.

const Tile = preload("res://scripts/word_jelly_tile.gd")
const Style = preload("res://scripts/ui_style.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")
const PICTURE = preload("res://assets/images/ui/modes/cat.webp")
const CHEST = preload("res://assets/chests/royal/closed.png")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _cell(face_kind: String, spelling: String, display: String, level: int = 0, fragments: int = 0) -> Dictionary:
	var word := {"id": "fixture:" + spelling, "text": spelling, "image": "res://assets/images/ui/modes/cat.webp"}
	return {"id": 12, "kind": "picture" if face_kind == "picture" else "word", "jelly_kind": face_kind,
		"text": spelling, "display_text": display, "word": word if face_kind == "merged" else {},
		"image_word": word if face_kind != "root" else {}, "merge_level": level, "mass": 1,
		"fragments": fragments, "width": 1, "height": 1, "approved_break_offsets": []}

func _inside(tile: Control, rect: Rect2) -> bool:
	return Rect2(Vector2.ZERO, tile.size).grow(0.1).encloses(rect)

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 800)
	var tile := Tile.new()
	root.add_child(tile)
	for side: float in [36.0, 44.0, 72.0, 100.0]:
		tile.size = Vector2.ONE * side
		for spelling: String in ["un-", "-believe-", "-able"]:
			var cell: Dictionary = _cell("root", spelling.replace("-", ""), spelling)
			tile.configure(cell, SKIN, null, CHEST, Color("#357d70"))
			check(tile._spelling == spelling and tile._label.text == spelling, "Authored positional hyphens remain visible at %s" % side)
			check(tile._label.visible and not tile._picture.visible and not tile.valid_word, "Root faces show only spelling")
			check(not tile.presentation_snapshot().merged_light and tile.presentation_snapshot().level_badge.is_empty(), "Roots carry no merged-only treatment")
			check(tile._label.get_theme_font_size("font_size") * Style.ui_scale(tile) >= 13.0, "Root lettering retains its physical reading floor")
			check(_inside(tile, tile._label.get_rect()), "Root labels remain inside their ordinary square")
		var picture_cell: Dictionary = _cell("picture", "cat", "", 0, 3)
		tile.configure(picture_cell, SKIN, PICTURE, CHEST, Color("#357d70"))
		check(tile.presentation_snapshot().picture_only, "Picture-only clues have a visible picture and no visible lettering")
		check(tile._label.text.is_empty() and tile._spelling.is_empty() and not tile.requires_read, "Picture clues cannot expose a spelling through Read")
		check(not tile.tooltip_text.contains("cat") and not str(tile.get("accessibility_name")).contains("Press R"), "Picture hover and keyboard hints do not reveal Read")
		check(str(tile.get("accessibility_name")).contains("Picture of cat"), "Screen readers can identify the depicted word")
		check(_inside(tile, tile._picture.get_rect()), "Picture art remains within its ordinary square")
		for level in range(1, 10):
			var cell: Dictionary = _cell("merged", "cat", "cat", level, 8)
			tile.configure(cell, SKIN, PICTURE, CHEST, Color("#357d70"))
			tile.set_merged_presentation(1.2, false)
			check(tile.size == Vector2.ONE * side, "Merged level %d keeps the ordinary body size" % level)
			check(tile.valid_word and tile._picture.visible and tile._label.visible, "Merged faces show picture and full word")
			check(tile.presentation_snapshot().merged_light and tile.presentation_snapshot().merged_glints == 2, "Merged levels have a permanent sourced readiness light")
			check(tile.presentation_snapshot().level_badge == (str(level) if level > 1 else ""), "Only upgraded merged words carry the upper-right numeral")
			check(not tile._label.get_rect().intersects(tile._picture.get_rect()), "Merged picture and caption have separate space")
			check(_inside(tile, tile._label.get_rect()) and _inside(tile, tile._picture.get_rect()), "Merged learning content fits the ordinary square")
			if level > 1:
				var fragment_rect: Array = tile.fragment_badge_snapshot().rect
				check(not Rect2(fragment_rect[0], fragment_rect[1], fragment_rect[2], fragment_rect[3]).intersects(tile._level_badge.get_rect()), "Level and fragment badges occupy different corners")
				check(_inside(tile, tile._level_badge.get_rect()) and tile._level_badge.position.x > side * 0.5, "Level numeral stays in the upper-right corner")
			var label_rect: Rect2 = tile._label.get_rect()
			tile.set_merged_presentation(2.4, true)
			var still_glint: Vector2 = tile._merged_glints[0].scale
			var still_alpha: float = tile._merged_glints[0].modulate.a
			tile.set_merged_presentation(9.8, true)
			check(tile._merged_glints[0].scale == still_glint and tile._merged_glints[0].modulate.a == still_alpha, "Reduced motion preserves a steady merged accent")
			check(tile._label.get_rect().is_equal_approx(label_rect) and tile._surface.scale.is_equal_approx(Vector2.ONE), "Idle level accents leave the learning face and body scale fixed")
			tile.set_completion_hint(true, 0.6, false)
			check(tile.completion_hint and tile._completion_glow.visible, "Merged words can still show upgrade target feedback")
			tile.set_completion_hint(false, 0.0, false)
			check(tile.presentation_snapshot().merged_light and is_equal_approx(tile.completion_scale, 1.0), "Clearing target feedback preserves merged readiness without enlarged skin")
			tile.set_projection(true)
			check(not tile._label.visible and not tile._picture.visible and not tile._level_badge.visible and not tile.presentation_snapshot().merged_light,
				"Placement projections hide content and merged decorations")
			tile.set_projection(false)
			check(tile.presentation_snapshot().merged_light and tile._label.visible, "Leaving projection restores the same merged identity")
		var no_picture: Dictionary = _cell("merged", "MRI", "MRI", 1)
		no_picture.image_word = {}
		tile.configure(no_picture, SKIN, null, CHEST, Color("#357d70"))
		check(tile.valid_word and tile._label.visible and not tile._picture.visible, "A pictureless word has a full-sized word face and remains collectable")
		check(tile.presentation_snapshot().merged_light, "Pictureless merged words retain the same readiness light")
	tile.free()
	print("Word Jelly hybrid tile: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

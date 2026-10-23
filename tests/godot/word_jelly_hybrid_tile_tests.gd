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

func _check_completion_enlargement() -> void:
	var tile := Tile.new()
	root.add_child(tile)
	for side: float in [36.0, 100.0]:
		tile.size = Vector2.ONE * side
		for face_kind: String in ["root", "picture", "merged"]:
			tile.configure(_cell(face_kind, "cat", "cat", 3 if face_kind == "merged" else 0, 8),
				SKIN, PICTURE, CHEST, Color("#357d70"))
			tile.deform(0.0, 0.0)
			var rectangle: Rect2 = tile.get_rect()
			var outline: PackedVector2Array = tile.contact_outline()
			var label_rect: Rect2 = tile._label.get_rect()
			var picture_rect: Rect2 = tile._picture.get_rect()
			tile.set_completion_hint(true, 0.0, false)
			check(is_equal_approx(tile.completion_scale, 1.0), "A newly matched target starts its enlargement at the resting size")
			var previous: float = tile.completion_scale
			for elapsed: float in [0.05, 0.10, 0.15, 0.20]:
				tile.set_completion_hint(true, elapsed, false)
				check(tile.completion_scale > previous, "The target grows progressively during entry")
				previous = tile.completion_scale
			check(tile.completion_scale >= 1.12 - 0.0001, "The target reaches a clearly enlarged held size after entry")
			var smallest: float = INF
			var largest: float = 0.0
			for frame in range(49):
				tile.set_completion_hint(true, 0.20 + float(frame) * 0.10, false)
				smallest = minf(smallest, tile.completion_scale)
				largest = maxf(largest, tile.completion_scale)
				check(tile.completion_scale >= 1.12 - 0.0001 and tile.completion_scale <= 1.145 + 0.0001,
					"A held target keeps its enlarged baseline through more than two breathing cycles")
				check(tile._surface.scale.is_equal_approx(Vector2.ONE * tile.completion_scale),
					"The sampled completion scale is applied to the authored skin")
			check(largest - smallest > 0.02, "The enlarged target visibly breathes while it remains highlighted")
			check(tile.get_rect().is_equal_approx(rectangle) and tile.contact_outline() == outline,
				"The stronger enlargement leaves target placement and contact geometry stable")
			check(tile._label.get_rect().is_equal_approx(label_rect) and tile._picture.get_rect().is_equal_approx(picture_rect)
				and tile._visual.scale.is_equal_approx(Vector2.ONE), "Skin breathing preserves readable picture and caption geometry")
			var stretch := Vector2(1.04, 0.96)
			tile.deform(0.02, 0.4, stretch)
			check(tile._base_stretch.is_equal_approx(stretch * tile.completion_scale),
				"Ordinary jelly deformation retains the held target enlargement")
			tile.set_contact("match", Vector2.RIGHT, 0.6)
			check(not tile._surface.scale.is_equal_approx(tile._base_stretch), "Matching contact can deform an already enlarged skin")
			tile.set_contact("none")
			check(tile._surface.scale.is_equal_approx(stretch * tile.completion_scale),
				"Leaving contact restores the enlarged target instead of its resting size")
			tile.set_completion_hint(false, 0.0, false)
			for attempt in range(5):
				tile.set_completion_hint(true, 0.0, false)
				tile.set_completion_hint(true, 0.8, false)
				tile.set_completion_hint(false, 0.0, false)
				check(is_equal_approx(tile.completion_scale, 1.0) and tile._surface.scale.is_equal_approx(stretch)
					and tile._base_stretch.is_equal_approx(stretch), "Repeated selection and cancellation cannot accumulate enlargement")
			tile.deform(0.0, 0.0)
			tile.set_completion_hint(true, 0.0, false)
			tile.set_completion_hint(true, 0.8, false)
			tile.set_completion_hint(true, 0.8, true)
			var still_light: float = tile._gel.get_shader_parameter("completion_strength")
			tile.set_completion_hint(true, 5.2, true)
			check(tile.completion_hint and is_equal_approx(tile.completion_scale, 1.0)
				and tile._surface.scale.is_equal_approx(Vector2.ONE), "Reduced motion immediately clears enlargement and keeps the matching cue still")
			check(is_equal_approx(float(tile._gel.get_shader_parameter("completion_strength")), still_light),
				"Reduced-motion matching brightness stays steady during a long hold")
			tile.set_completion_hint(true, 5.2, false)
			check(tile.completion_scale >= 1.12 - 0.0001, "Reenabling motion restores the still-active target's enlarged state")
			tile.set_projection(true)
			check(not tile.completion_hint and is_equal_approx(tile.completion_scale, 1.0)
				and tile._surface.scale.is_equal_approx(Vector2.ONE), "Placement projection clears the active enlargement immediately")
			tile.set_projection(false)
			check(not tile.completion_hint and is_equal_approx(tile.completion_scale, 1.0),
				"Leaving projection does not revive an old target enlargement")
			tile.set_completion_hint(true, 5.0, false)
			check(is_equal_approx(tile.completion_scale, 1.0), "A target becoming eligible late in a hold starts at its resting size")
			tile.set_completion_hint(true, 5.1, false)
			check(tile.completion_scale > 1.0 and tile.completion_scale < 1.12,
				"Late eligibility animates a fresh entry instead of jumping to the held size")
			tile.set_completion_hint(true, 5.2, false)
			check(tile.completion_scale >= 1.12 - 0.0001, "A late target reaches the same enlarged held size")
			tile.set_completion_hint(true, 0.0, false)
			check(is_equal_approx(tile.completion_scale, 1.0), "A replacement source restarts entry when its shared elapsed time rewinds")
			tile.set_completion_hint(true, 0.2, false)
			check(tile.completion_scale >= 1.12 - 0.0001, "A replacement source keeps the target's normal growth timing")
			tile.set_completion_hint(false, 0.0, false)
		tile.set_completion_hint(false, 0.0, false)
	tile.free()

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
			check(tile.completion_hint and float(tile._gel.get_shader_parameter("completion_strength")) > 0.35, "Merged words can still show upgrade target feedback")
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
	_check_completion_enlargement()
	print("Word Jelly hybrid tile: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

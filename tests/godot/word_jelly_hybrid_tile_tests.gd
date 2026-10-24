extends SceneTree
## Hybrid word faces retain one ordinary square and preserve picture-only clues.

const Tile = preload("res://scripts/word_jelly_tile.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Style = preload("res://scripts/ui_style.gd")
const WordArt = preload("res://scripts/word_art.gd")
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

func _painted_rect(control: Control) -> Rect2:
	return Rect2(control.position + control.pivot_offset * (Vector2.ONE - control.scale),
		control.size * control.scale)

func _check_picture_clarity() -> void:
	var tile := Tile.new()
	root.add_child(tile)
	for side: float in [36.0, 44.0, 72.0, 100.0]:
		tile.size = Vector2.ONE * side
		for face: Dictionary in [{"kind": "picture", "level": 0}, {"kind": "merged", "level": 1},
			{"kind": "merged", "level": Model.MAX_MERGE_LEVEL}]:
			for fragments: int in [0, 1, 2, 8, 20]:
				tile.set_fragment_arrival(-1.0, false)
				tile.configure(_cell(face.kind, "cat", "cat", face.level, fragments), SKIN, PICTURE, CHEST, Color("#357d70"))
				var context: String = "%s, level %d, %d fragments, %s px" % [face.kind, face.level, fragments, side]
				var picture: Rect2 = tile._picture.get_rect()
				var label: Rect2 = tile._label.get_rect()
				var body: Rect2 = tile.get_rect()
				var outline: PackedVector2Array = tile.contact_outline()
				check(tile._picture.texture == PICTURE and tile._picture.scale == Vector2.ONE
					and tile._picture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
					context + ": the learning face keeps the exact source and undistorted aspect fitting")
				check(picture.has_area() and _inside(tile, picture), context + ": the larger picture remains inside its body")
				if face.kind == "picture":
					# Reject the old 68%/58% clue faces without pinning the new layout constants.
					var minimum_edge: float = side * (0.75 if fragments == 0 else 0.65)
					check(picture.size.x >= minimum_edge and picture.size.y >= minimum_edge,
						context + ": the picture gains useful area even when carrying treasure")
				else:
					check(not picture.intersects(label) and _inside(tile, label), context + ": the picture and readable caption keep separate space")
					check(tile._label.get_theme_font_size("font_size") * Style.ui_scale(tile) >= 13.0,
						context + ": larger artwork does not borrow from the caption's physical reading floor")
					if side >= 72.0:
						check(picture.size.x >= side * 0.38, context + ": merged artwork is no longer limited to the old small badge slot")
					if tile._level_badge.visible:
						check(not picture.intersects(tile._level_badge.get_rect()), context + ": the level numeral leaves the picture clear")
					for elapsed: float in [0.0, 0.7, 1.4, 2.1, 2.8]:
						tile.set_merged_presentation(elapsed, false)
						for glint: TextureRect in tile._merged_glints:
							check(not _painted_rect(glint).intersects(picture),
								context + ": twinkling rim accents leave the picture unobstructed; glint %s, picture %s" % [_painted_rect(glint), picture])
							check(glint.get_parent() == tile._picture.get_parent()
								and glint.z_index <= tile._picture.z_index and glint.z_index <= tile._label.z_index
								and glint.get_index() < tile._picture.get_index() and glint.get_index() < tile._label.get_index(),
								context + ": rim accents paint behind both learning faces, including small caption edges")
				if fragments > 0:
					for age: float in [-1.0, 0.11]:
						tile.set_fragment_arrival(age, false)
						var reward: Rect2 = _painted_rect(tile._fragment_holder)
						check(_inside(tile, reward) and not reward.intersects(picture),
							context + ": the full fragment stack stays inside and clear of the picture at rest and peak bounce")
						if tile._label.visible:
							check(not reward.intersects(label), context + ": the fragment bounce leaves the caption clear")
						if tile._level_badge.visible:
							check(not reward.intersects(tile._level_badge.get_rect()), context + ": fragment bounce and level remain separate")
					tile.set_fragment_arrival(-1.0, false)
				for contact: String in ["match", "touch", "reject"]:
					tile.set_contact(contact, Vector2.RIGHT, 0.6)
					check(tile._picture.size.is_equal_approx(picture.size) and tile._label.size.is_equal_approx(label.size)
						and (tile._label.position - tile._picture.position).distance_to(label.position - picture.position) < 0.01,
						context + ": contact moves learning content together without resizing or crowding it")
					check(tile.get_rect().is_equal_approx(body) and tile.contact_outline() == outline,
						context + ": contact keeps the original drag and hit geometry")
					tile.set_contact("none")
					check(tile._picture.get_rect().is_equal_approx(picture) and tile._label.get_rect().is_equal_approx(label),
						context + ": releasing contact restores the exact learning layout")
				tile.set_completion_hint(true, 0.0, false)
				tile.set_completion_hint(true, 1.3, false)
				check(tile._picture.get_rect().is_equal_approx(picture) and tile._label.get_rect().is_equal_approx(label)
					and tile.get_rect().is_equal_approx(body) and tile.contact_outline() == outline,
					context + ": completion breathing preserves the larger learning face and hit geometry")
				tile.set_completion_hint(false, 0.0, false)
	tile.free()

func _check_picture_motion_binding() -> void:
	var source: String = "res://assets/images/word-library/cat.webp"
	WordArt.set_reduced_motion(false)
	var owners_before: int = int(WordArt.cache_snapshot().owners)
	var picture: Texture2D = WordArt.texture(source)
	var host := Control.new()
	root.add_child(host)
	var tile := Tile.new()
	host.add_child(tile)
	tile.size = Vector2.ONE * 72.0
	tile.configure(_cell("picture", "cat", "", 0, 8), SKIN, picture, CHEST, Color("#357d70"))
	check(picture is AtlasTexture and tile._picture.texture == picture and WordArt.source_path(picture) == source,
		"The larger picture clue keeps the shared animation wrapper and its original source")
	var picture_tint: Color = tile._picture.modulate
	var picture_self_tint: Color = tile._picture.self_modulate
	var shadow: TextureRect = tile._picture_shadow
	check(shadow.visible and shadow.texture == picture and int(WordArt.cache_snapshot().owners) == owners_before + 1,
		"The picture shadow shares the exact animation wrapper without registering another playback owner")
	var offset: Vector2 = shadow.position - tile._picture.position
	var extent: Vector2 = shadow.size - tile._picture.size
	check(offset.length() * Style.ui_scale(tile) < 2.0 and extent.length() * Style.ui_scale(tile) < 2.0,
		"The source-shaped shadow stays closely aligned with the picture in physical pixels")
	var shadow_rect: Rect2 = shadow.get_rect()
	tile.set_contact("match", Vector2.RIGHT, 0.6)
	check((shadow.position - tile._picture.position).is_equal_approx(offset)
		and (shadow.size - tile._picture.size).is_equal_approx(extent)
		and shadow.z_index == tile._picture.z_index and shadow.get_index() < tile._picture.get_index(),
		"Contact keeps the same small shadow offset and paints it behind the moving picture")
	tile.set_contact("none")
	check(shadow.get_rect().is_equal_approx(shadow_rect),
		"Releasing contact restores the picture shadow to its exact resting alignment")
	if picture is AtlasTexture:
		var atlas := picture as AtlasTexture
		WordArt.advance(0.1)
		check(atlas.region.position != Vector2.ZERO and shadow.texture == atlas,
			"The larger clue and its shadow advance together through one shared animation")
		var frame: Rect2 = atlas.region
		for hidden: Control in [tile, host]:
			hidden.hide()
			check(not shadow.visible and shadow.texture == null and tile._picture.texture == picture,
				"Hiding the tile or its ancestor releases the shadow reference without changing the learning picture")
			WordArt.advance(0.1)
			check(atlas.region == frame, "Hidden picture shadows cannot keep vocabulary playback active")
			hidden.show()
			check(shadow.is_visible_in_tree() and shadow.texture == picture,
				"Showing the tile or its ancestor restores the same live picture shadow")
		tile.set_projection(true)
		WordArt.advance(0.1)
		check(not tile._picture.visible and atlas.region == frame and not shadow.visible and shadow.texture == null,
			"A landing projection hides and freezes word art while releasing its shadow reference")
		tile.set_projection(false)
		check(shadow.visible and shadow.texture == picture, "Leaving projection restores the exact shared picture shadow")
		tile.configure(_cell("root", "cat", "cat"), SKIN, picture, CHEST, Color("#357d70"))
		check(not shadow.visible and shadow.texture == null and not tile._picture.visible,
			"Reusing a picture tile as a root clears the shadow even when its old texture is supplied")
		tile.hide()
		tile.show()
		check(not shadow.visible and shadow.texture == null, "Showing a root cannot revive an obsolete picture shadow")
		tile.configure(_cell("merged", "cat", "cat", 6, 8), SKIN, picture, CHEST, Color("#357d70"))
		tile.size = Vector2.ONE * 44.0
		tile._layout()
		check(tile._picture.texture == picture and shadow.texture == picture and atlas.region == frame,
			"Reconfiguration and resizing preserve the exact live frame without replacing or cropping its wrapper")
		WordArt.advance(0.1)
		check(tile._picture.visible and tile._label.visible and atlas.region != frame,
			"The merged picture continues the same animation alongside its readable caption")
	check(tile._picture.modulate == picture_tint and tile._picture.self_modulate == picture_self_tint
		and tile._picture.texture == picture and int(WordArt.cache_snapshot().owners) == owners_before + 1,
		"Shadow lifecycle changes preserve the main picture's tint, texture, and sole playback owner")
	host.free()
	WordArt.set_reduced_motion(true)
	WordArt.set_reduced_motion(false)

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

func _check_match_dimming() -> void:
	var tile := Tile.new()
	root.add_child(tile)
	tile.size = Vector2.ONE * 44.0
	for face_kind: String in ["root", "picture", "merged"]:
		tile.configure(_cell(face_kind, "cat", "cat", 3 if face_kind == "merged" else 0, 8),
			SKIN, PICTURE, CHEST, Color("#357d70"))
		tile.set_merged_presentation(0.8, true)
		var rectangle: Rect2 = tile.get_rect()
		var outline: PackedVector2Array = tile.contact_outline()
		var original_skin: Color = tile._surface.self_modulate
		var label_color: Color = tile._label.modulate
		var picture_color: Color = tile._picture.modulate
		var badge_color: Color = tile._fragment_holder.modulate
		tile.modulate.a = 0.42
		for attempt in range(3):
			tile.set_match_dimmed(true)
			check(tile.match_dimmed and tile._surface.self_modulate.r < original_skin.r
				and tile._surface.self_modulate.g < original_skin.g,
				"Unrelated jelly skins visibly recede while a matching choice is held")
			check(is_equal_approx(tile.modulate.a, 0.42)
				and is_equal_approx(tile._surface.self_modulate.a, original_skin.a),
				"Matching contrast preserves independent arrival and collection transparency")
			check(tile._label.modulate == label_color and tile._picture.modulate == picture_color
				and tile._fragment_holder.modulate == badge_color and tile._visual.modulate == Color.WHITE,
				"Dimming the material preserves the word, picture and reward badge readability")
			check(tile.get_rect().is_equal_approx(rectangle) and tile.contact_outline() == outline,
				"A visually muted jelly keeps its original hit ownership and contact geometry")
			if face_kind == "merged":
				check(tile._merged_glow.self_modulate.a < 1.0 and tile._merged_glints[0].self_modulate.a < 1.0,
					"An unrelated merged word's permanent accents recede with its skin")
			tile.set_match_dimmed(false)
			check(not tile.match_dimmed and tile._surface.self_modulate.is_equal_approx(original_skin)
				and is_equal_approx(tile.modulate.a, 0.42),
				"Repeated matching cancellation restores the exact skin without overwriting opacity")
			if face_kind == "merged":
				check(tile._merged_glow.self_modulate == Color.WHITE and tile._merged_glints[0].self_modulate == Color.WHITE,
					"Matching cancellation restores the permanent merged-word accents")
		tile.modulate.a = 1.0
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
		for level in range(1, Model.MAX_MERGE_LEVEL + 1):
			var cell: Dictionary = _cell("merged", "cat", "cat", level, 8)
			tile.configure(cell, SKIN, PICTURE, CHEST, Color("#357d70"))
			tile.set_merged_presentation(1.2, false)
			check(tile.size == Vector2.ONE * side, "Merged level %d keeps the ordinary body size" % level)
			check(tile.valid_word and tile._picture.visible and tile._label.visible, "Merged faces show picture and full word")
			check(tile.presentation_snapshot().merged_light and tile.presentation_snapshot().merged_glints == 2, "Merged levels have a permanent sourced readiness light")
			check(tile.presentation_snapshot().level_badge == (str(level) if level > 1 else ""), "Only upgraded merged words carry the upper-right numeral")
			var guidance: String = str(tile.get("accessibility_name"))
			check(guidance.contains("add their levels") if level < Model.MAX_MERGE_LEVEL else guidance.contains("Maximum level reached"),
				"Merged-word guidance describes additive levels and the final tier")
			check(not guidance.contains("same level"), "Mixed-level word merges are discoverable to screen-reader users")
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
		for requested: int in [0, 7, 9, 20]:
			tile.configure(_cell("merged", "cat", "cat", requested), SKIN, PICTURE, CHEST, Color("#357d70"))
			check(tile.merge_level == clampi(requested, 1, Model.MAX_MERGE_LEVEL),
				"Legacy and invalid level inputs fit the six available tile presentations")
	tile.size = Vector2.ONE * 53.5
	tile.configure(_cell("merged", "cat", "cat", 6, 8), SKIN, PICTURE, CHEST, Color("#357d70"))
	var numeral: Label = tile._level_badge
	var numeral_font: Font = numeral.get_theme_font("font")
	var numeral_pixels: int = numeral.get_theme_font_size("font_size")
	var numeral_width: float = numeral_font.get_string_size(numeral.text, HORIZONTAL_ALIGNMENT_LEFT, -1, numeral_pixels).x
	check((numeral.size.x - numeral_width) * Style.ui_scale(tile) >= 3.9
		and numeral_font.get_height(numeral_pixels) <= numeral.size.y + 0.01
		and numeral_pixels * Style.ui_scale(tile) >= 10.0,
		"The compact level badge keeps its readable digit, full line height, and padded sides at a fractional phone tile size")
	tile.free()
	_check_picture_clarity()
	_check_picture_motion_binding()
	_check_completion_enlargement()
	_check_match_dimming()
	print("Word Jelly hybrid tile: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

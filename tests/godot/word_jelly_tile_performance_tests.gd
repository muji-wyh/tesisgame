extends SceneTree
## Repeated drag presentation updates preserve layout and authored tile feedback.

const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")
const PICTURE = preload("res://assets/images/ui/modes/cat.webp")
const CHEST = preload("res://assets/chests/royal/closed.png")
const BaseTile = preload("res://scripts/jelly_tile.gd")

class ProbeTile:
	extends "res://scripts/word_jelly_tile.gd"
	var layout_count: int = 0

	func _layout() -> void:
		layout_count += 1
		super._layout()

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _cell(level: int = 2) -> Dictionary:
	return {"id": 12, "kind": "word", "jelly_kind": "merged", "text": "cat", "display_text": "cat",
		"word": {"id": "fixture:cat", "text": "cat"}, "merge_level": level, "mass": 1,
		"fragments": 8, "width": 1, "height": 1, "approved_break_offsets": []}

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 800)
	var ghost := BaseTile.new()
	root.add_child(ghost)
	ghost.size = Vector2.ONE * 80.0
	ghost.configure(_cell(), SKIN, PICTURE, CHEST, Color("#357d70"))
	ghost.set_projection(true)
	# Theme changes reconfigure an existing landing ghost before reapplying its
	# already-true projection state. Its outline must survive that refresh.
	ghost.configure(_cell(), SKIN, PICTURE, CHEST, Color("#745a93"))
	ghost.set_projection(true)
	check(ghost._gel.get_shader_parameter("rim_color") == Color("#507968")
		and is_equal_approx(float(ghost._gel.get_shader_parameter("rim_strength")), 0.8),
		"Reconfiguring an existing landing projection preserves its standard outline")
	check(not ghost._label.visible and not ghost._picture.visible and not ghost._shadow.visible,
		"Reconfigured landing projections keep their face and support shadow hidden")
	ghost.set_projection(false)
	check(is_zero_approx(float(ghost._gel.get_shader_parameter("rim_strength"))) and ghost._label.visible,
		"Leaving a landing projection restores ordinary unselected feedback")
	ghost.free()
	var tile := ProbeTile.new()
	root.add_child(tile)
	tile.size = Vector2.ONE * 100.0
	tile.configure(_cell(), SKIN, PICTURE, CHEST, Color("#357d70"))
	tile.set_completion_hint(true, 0.0, false)
	tile.set_completion_hint(true, 0.6, false)
	tile.set_projection(true)
	check(not tile._label.visible and not tile._picture.visible and not tile._level_badge.visible,
		"Projection hides the learning face and level badge")
	check(not tile._merged_glow.visible and is_zero_approx(float(tile._gel.get_shader_parameter("completion_strength"))) and not tile._fragment_holder.visible,
		"Projection hides sourced decorations and matching material light")
	var projected_layouts: int = tile.layout_count
	var placement_rim := Color("#ce655b")
	tile._gel.set_shader_parameter("rim_color", placement_rim)
	for index in range(120):
		tile.position = Vector2(index * 0.5, 20.0)
		tile.set_projection(true)
	check(tile.layout_count == projected_layouts, "Moving an unchanged projection never repeats label or badge layout")
	check(tile._gel.get_shader_parameter("rim_color") == placement_rim, "Repeated projection preserves current placement validity feedback")
	tile.size = Vector2.ONE * 72.0
	await process_frame
	check(tile.layout_count > projected_layouts and tile._surface.size == tile.size,
		"A projected tile still relayouts when its responsive size changes")
	tile.set_projection(false)
	check(tile._label.visible and tile._picture.visible and tile._level_badge.visible,
		"Leaving projection restores the complete learning face")
	check(tile._merged_glow.visible and tile._fragment_holder.visible and is_equal_approx(float(tile._gel.get_shader_parameter("completion_strength")), 0.35),
		"Leaving projection restores readiness and fragments without reviving a stale completion hint")
	var restored_layouts: int = tile.layout_count
	tile.set_projection(false)
	check(tile.layout_count == restored_layouts, "Repeated ordinary presentation is also layout-free")

	tile.set_marked(false, false, true, false)
	var stretch := Vector2(1.04, 0.96)
	tile.deform(0.02, 0.4, stretch)
	tile.set_contact("touch", Vector2.RIGHT, 0.6)
	check(not tile._surface.scale.is_equal_approx(stretch), "Contact still deforms the authored skin")
	tile.deform(0.02, 0.4, stretch)
	check(tile._surface.scale.is_equal_approx(stretch), "An unchanged deformation restores the base transform after contact")
	tile.set_contact("none")
	check(tile._surface.position == Vector2.ZERO and tile._content_offset == Vector2.ZERO,
		"Contact release restores the picture and caption offsets")
	check(is_equal_approx(float(tile._gel.get_shader_parameter("bend")), 0.02)
		and is_equal_approx(float(tile._gel.get_shader_parameter("beat")), 0.4), "Repeated deformation retains its shader values")
	tile.set_preview_pressure(0.06, 0.02, 0.12)
	var preview_shadow: Rect2 = tile._shadow.get_rect()
	for index in range(30):
		tile.set_preview_pressure(0.06, 0.02, 0.12)
	check(tile._shadow.get_rect().is_equal_approx(preview_shadow), "Repeated loaded preview poses do not accumulate shadow displacement")
	tile.set_support(6.0, 0.0, false)
	tile.set_preview_pressure(0.06, 0.02, 0.12)
	check(tile._shadow.visible and tile._shadow.get_rect().is_equal_approx(preview_shadow),
		"An unchanged preview pose restores its shadow after drag support changes")
	tile.size = Vector2.ONE * 88.0
	await process_frame
	tile.deform(0.02, 0.4, stretch)
	tile.set_preview_pressure(0.06, 0.02, 0.12)
	check(tile._surface.pivot_offset.is_equal_approx(tile.size * Vector2(0.5, tile.Motion.FOOT_Y)),
		"Resizing updates the deformation pivot even when shader values are unchanged")
	check(not tile._shadow.get_rect().is_equal_approx(preview_shadow), "Resizing updates an otherwise unchanged preview shadow")
	check(tile._gel.get_shader_parameter("surface_size") == tile.size, "Resizing updates the lighting extent")
	tile.deform(0.0, 0.0)
	tile.set_preview_pressure(0.0, 0.0)
	tile.set_palette(2, 0.25)
	tile.set_palette(2, 0.25)
	tile.set_palette(3, 0.45)
	check(tile.palette_index == 3 and is_equal_approx(float(tile._gel.get_shader_parameter("palette_hue")), 0.45),
		"Palette changes still reach the shared artwork shader")

	tile.set_merged_presentation(1.2, false)
	var light_extent: Vector2 = tile._merged_glow.size
	var glint_extent: Vector2 = tile._merged_glints[0].size
	var light_tint: Color = tile._merged_glow.modulate
	tile.set_merged_presentation(1.2, false)
	check(tile._merged_glow.size == light_extent and tile._merged_glints[0].size == glint_extent,
		"Repeated readiness poses preserve sourced light geometry")
	tile.set_merged_presentation(2.4, true)
	var still_glint: Vector2 = tile._merged_glints[0].scale
	var still_tint: Color = tile._merged_glints[0].modulate
	tile.set_merged_presentation(9.8, true)
	check(tile._merged_glints[0].scale == still_glint and tile._merged_glints[0].modulate == still_tint,
		"Reduced motion keeps readiness glints still as elapsed time advances")
	tile.set_merged_presentation(9.8, false)
	check(not tile._merged_glints[0].scale.is_equal_approx(still_glint), "Leaving reduced motion resumes the existing glint animation")
	tile.set_completion_hint(true, 0.0, false)
	tile.set_completion_hint(true, 0.6, false)
	var completion_strength: float = tile._gel.get_shader_parameter("completion_strength")
	tile.set_merged_presentation(10.0, false)
	check(tile.completion_hint and tile.completion_scale > 1.0
		and is_equal_approx(float(tile._gel.get_shader_parameter("completion_strength")), completion_strength),
		"Readiness updates preserve active completion feedback")
	tile.set_completion_hint(false, 0.0, false)
	check(is_equal_approx(tile.completion_scale, 1.0) and tile._merged_glow.visible,
		"Clearing completion feedback retains ordinary merged readiness")
	tile.configure(_cell(9), SKIN, PICTURE, CHEST, Color("#357d70"))
	tile.set_merged_presentation(10.0, false)
	check(tile._merged_glow.modulate != light_tint and tile._level_badge.text == "9",
		"Reusing the same tile at a new level updates readiness tint and badge")
	var chances: Array[int] = [0, 2, 4, 6, 10, 16, 28, 50, 80]
	var coins: Array[int] = [0, 50, 100, 150, 200, 250, 300, 350, 450]
	for level in range(1, 10):
		tile.configure(_cell(level), SKIN, PICTURE, CHEST, Color("#357d70"))
		var description: String = tile.get("accessibility_name")
		check(description.contains("No bonus coins at this level.") if level == 1
			else description.contains("%d%% chance of %d bonus coins." % [chances[level - 1], coins[level - 1]]),
			"Level %d accessibility describes its own collection reward" % level)
	tile.free()
	print("Word Jelly tile performance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree

const Tile = preload("res://scripts/jelly_tile.gd")
const Style = preload("res://scripts/ui_style.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	var tile := Tile.new()
	root.add_child(tile)
	tile.kind = "word"
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1920, 1080), Vector2i(1280, 800)]:
		root.size = dimensions
		await process_frame
		var scale_factor: float = Style.ui_scale(tile)
		# Desktop browser evidence: 34.8 canvas units at 5/3 scale gives a 58px preview.
		tile.size = Vector2.ONE * 58.0 / scale_factor
		for spelling: String in ["fish", "banana", "yellow", "rabbit", "banana"]:
			tile._label.text = spelling
			tile._layout()
			await process_frame
			var label: Label = tile._label
			var pixels: int = label.get_theme_font_size("font_size")
			var shaped_width: float = label.get_theme_font("font").get_string_size(spelling, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
			check(shaped_width <= label.size.x - 2.0 + 0.01,
				"The complete %s spelling fits a 58px preview at %s (scale %.3f)" % [spelling, dimensions, scale_factor])
			check(pixels * scale_factor >= 9.0,
				"Preview fitting keeps its nine-display-pixel reading floor at %s" % dimensions)
			var last: Rect2 = label.get_character_bounds(spelling.length() - 1)
			check(last.has_area() and last.end.x <= label.size.x + 0.01,
				"The final letter remains inside the rendered label after word changes and resize at %s" % dimensions)
	tile.free()
	print("Jelly tile label: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

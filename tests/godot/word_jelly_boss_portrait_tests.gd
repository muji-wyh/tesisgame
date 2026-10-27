extends SceneTree

const Map = preload("res://scripts/word_jelly_map.gd")
const PORTRAIT: String = "res://assets/jelly-boss/private/bramble-portrait.png"
var checks: int = 0
var failures: int = 0
var selections: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var view := Map.new()
	root.add_child(view)
	view.stage_selected.connect(func(number: int) -> void: selections.append(number))
	var capture: bool = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(393, 852), Vector2i(320, 480)]:
		root.size = dimensions
		view.size = dimensions
		view.open({"highest_cleared": 2, "best_stars": {}, "boss_markers": [3],
			"boss_victories": [], "merged_level": 1, "coins": 0, "loading": false, "error": ""})
		await settle()
		var item: Dictionary = view._nodes[2]
		var picture = item.boss
		check(picture is TextureButton, "The Boss marker is a tappable picture, not a BOSS text capsule")
		if picture is TextureButton:
			check(picture.texture_normal != null and picture.texture_normal.resource_path == PORTRAIT,
				"The Boss marker uses the actual acquired Bramble portrait")
			check(picture.size.x >= 44 and picture.size.y >= 44,
				"The portrait keeps a full touch target at %s" % dimensions)
			check(not picture.get_global_rect().intersects(item.label.get_global_rect()),
				"The Boss face does not cover the stage number at %s" % dimensions)
			for star: TextureRect in item.stars:
				check(not picture.get_global_rect().intersects(star.get_global_rect()),
					"The Boss face leaves earned stars readable")
			check(view._scroll.get_global_rect().grow(0.1).encloses(picture.get_global_rect()),
				"The focused Boss portrait is fully visible in the actual scroll viewport")
			var before: int = selections.size()
			picture.pressed.emit()
			check(selections.size() == before + 1 and selections.back() == 3,
				"Selecting the Boss image starts that same unlocked stage")
		if capture:
			DirAccess.make_dir_recursive_absolute("res://build/qa/boss-map-portrait")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://build/qa/boss-map-portrait/map-%d.png" % dimensions.x) == OK,
				"Capture the actual rendered portrait map")
	view.configure({"highest_cleared": 3, "best_stars": {"3": 3}, "boss_markers": [3, 5],
		"boss_victories": [1], "merged_level": 2, "loading": false, "error": ""})
	check(view._nodes[2].boss.visible and view._nodes[4].boss.visible and not view._nodes[6].boss.visible,
		"Portraits preserve unlocked Bosses plus only the next future Boss")
	check(view._nodes[4].button.disabled, "The upcoming portrait cannot unlock a later stage")
	view.configure({"highest_cleared": 0, "boss_markers": [1, 3], "merged_level": 1})
	check(not view._nodes[0].boss.visible and not view._subtitle.text.contains("Bramble"),
		"Neither a stale opening marker nor the subtitle reveals the first-stage surprise")
	view.free()
	print("Boss map portrait: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

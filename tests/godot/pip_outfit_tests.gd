extends SceneTree

const Pip = preload("res://scripts/duck_mascot.gd")
const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]
const AGES := [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const CELL := Vector2i(168, 168)
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var duck := Pip.new()
	root.add_child(duck)
	_reset_visual(duck)
	_check_contract(duck)
	if DisplayServer.get_name() != "headless":
		await _check_rendered_wardrobes(duck)
	duck.free()
	print("Pip outfits: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _advance(duck: Button, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed + 0.001 < seconds:
		duck._process(0.05)
		elapsed += 0.05


func _activity(duck: Button) -> Array:
	return [duck.pose, duck.speaking, duck.reduced_motion, duck.is_processing(),
		duck._idle_action, duck._idle_left, duck._idle_wait, duck._idle_index,
		duck._reaction, duck.reaction_left, duck._speech_time, duck._idle_time,
		duck._gameplay_reaction, duck._gameplay_left, duck.expression_name()]


func _sheets(duck: Button) -> Array[Texture2D]:
	return [duck._outfit_sheet, duck._outfit_idle_sheet, duck._outfit_dance_sheet, duck._expression_sheet, duck._expression_heads]


func _check_contract(duck: Button) -> void:
	check(duck.growth_age == 0 and duck.growth_actions() == ["wave"], "Pip begins as Baby with the first unlocked gesture")
	var events: Array[String] = []
	duck.pressed.connect(func() -> void: events.append("pressed"))
	var bounds: Rect2 = duck.get_global_rect()
	var nodes := duck.get_child_count()
	for age in AGES:
		duck.set_growth_age(age)
		var sheets: Array[Texture2D] = _sheets(duck)
		check(sheets.all(func(texture: Texture2D): return texture != null and texture.get_height() > 0), "Every growth stage loads all five production atlases")
		for index in range(sheets.size()):
			check(sheets[index].get_width() == sheets[index].get_height() * [4, 4, 6, 10, 10][index], "Every imported pose and limb retains its square atlas cell dimensions")
		check(duck.growth_actions().size() == maxi(1, age - 2), "Each new age adds one action while retaining the earlier repertoire")
		for scenario in ["quiet", "gesture", "speaking", "listening", "result", "reduced"]:
			_reset_visual(duck)
			match scenario:
				"gesture": duck.perform_trick("wave")
				"speaking": duck.set_speaking(true)
				"listening": duck.set_attention("listening")
				"result": duck.react_gameplay(true)
				"reduced":
					duck.set_reduced_motion(true)
					duck.perform_trick("wave")
			_advance(duck, 0.25)
			var before := _activity(duck)
			for theme in THEMES:
				duck.set_outfit_theme(theme)
				check(duck.theme_id == theme and duck.growth_age == age and _sheets(duck) == sheets
					and _activity(duck) == before, "World " + theme + " preserves the earned appearance and active " + scenario)
			duck.set_growth_age(age)
			check(_sheets(duck) == sheets and _activity(duck) == before, "Refreshing an unchanged age retains resources and every animation deadline")
			duck.set_outfit_theme("unknown-world")
			check(duck.theme_id == "spring" and _sheets(duck) == sheets and _activity(duck) == before, "An unknown world falls back safely without replacing growth artwork")
	check(events.is_empty() and duck.get_child_count() == nodes, "Appearance changes create no activation, audio players, timer or effect nodes")
	check(duck.get_global_rect() == bounds and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation), "Every growth appearance retains the exact Button input bounds")
	_reset_visual(duck)


func _reset_visual(duck: Button) -> void:
	duck.set_reduced_motion(false)
	duck.set_idle_paused(false)
	duck.set_proactive_allowed(false)
	duck.settle()
	duck.compact = false
	duck.position = Vector2(28, 24)
	duck.custom_minimum_size = Vector2.ZERO
	duck.size = Vector2(112, 112)
	duck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	duck.set_process(false)


func _capture(viewport: SubViewport, duck: Button) -> Image:
	duck.set_process(false)
	duck.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _visible_bounds(image: Image) -> Rect2i:
	var first := image.get_size()
	var last := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.02:
				first = Vector2i(mini(first.x, x), mini(first.y, y))
				last = Vector2i(maxi(last.x, x), maxi(last.y, y))
	return Rect2i(first, last - first + Vector2i.ONE) if last.x >= 0 else Rect2i()


func _save_cell(frame: Image, sheet: Image, column: int, row: int) -> void:
	var used: Rect2i = _visible_bounds(frame)
	check(used.has_area() and Rect2i(1, 1, CELL.x - 2, CELL.y - 2).encloses(used), "Every actual growth pose retains complete headwear, wings and feet")
	sheet.blend_rect(frame, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))


func _check_rendered_wardrobes(duck: Button) -> void:
	var directory := ProjectSettings.globalize_path("res://build/pip-outfits")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The growth appearance evidence directory is available")
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	duck.reparent(viewport)
	var sheet := Image.create(CELL.x * AGES.size(), CELL.y * 10, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#F1F6F4"))
	var outfits: Array[PackedByteArray] = []
	var smalls: Array[PackedByteArray] = []
	for column in range(AGES.size()):
		_reset_visual(duck)
		duck.set_growth_age(AGES[column])
		var resting: Image = await _capture(viewport, duck)
		_save_cell(resting, sheet, column, 0)
		check(not outfits.has(resting.get_data()), "Every earned stage has a distinct complete rendered silhouette")
		outfits.append(resting.get_data())
		duck.compact = true
		duck.position = Vector2(58, 58)
		duck.size = Vector2(52, 52)
		var small: Image = await _capture(viewport, duck)
		check(not smalls.has(small.get_data()), "Each growth stage remains distinct at the real 52-pixel header size")
		smalls.append(small.get_data())
		_save_cell(small, sheet, column, 1)
		for index in range(5):
			_reset_visual(duck)
			match index:
				0: duck.set_speaking(true)
				1: duck.set_attention("listening")
				2: duck.set_attention("thinking")
				3: duck.react_gameplay(true)
				4: duck.react_gameplay(false)
			_advance(duck, 0.4)
			_save_cell(await _capture(viewport, duck), sheet, column, index + 2)
		_reset_visual(duck)
		var action: String = duck.growth_actions().back()
		check(not duck.perform_trick(action).is_empty(), "Each stage can demonstrate its newly unlocked gesture")
		var duration: float = duck._idle_duration()
		var frames: Array[PackedByteArray] = []
		for index in range(3):
			duck._idle_left = duration * (1.0 - [0.2, 0.5, 0.8][index])
			duck._update_pose()
			var frame: Image = await _capture(viewport, duck)
			frames.append(frame.get_data())
			_save_cell(frame, sheet, column, index + 7)
		check(frames[0] != frames[1] and frames[1] != frames[2], "Each newly unlocked gesture has distinct articulated motion phases")
		duck.settle()
		check((await _capture(viewport, duck)).get_data() == resting.get_data(), "Gesture cleanup restores the entire earned silhouette")
		duck.set_reduced_motion(true)
		duck.perform_trick(action)
		var still: Image = await _capture(viewport, duck)
		_advance(duck, 14.0)
		check((await _capture(viewport, duck)).get_data() == still.get_data(), "Reduced motion keeps each stage's invitation completely static")
	check(sheet.save_png(directory + "/native-contact-sheet.png") == OK, "Baby and all ten age appearances and their live poses are saved together")
	check(sheet.get_region(Rect2i(0, 0, sheet.get_width(), CELL.y * 2)).save_png(directory + "/native-resting-header.png") == OK, "Full-size and header appearances are available for independent review")
	duck.reparent(root)
	viewport.queue_free()
	await process_frame

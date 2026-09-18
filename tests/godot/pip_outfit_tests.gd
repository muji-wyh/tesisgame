extends SceneTree

const Pip = preload("res://scripts/duck_mascot.gd")
const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]
const DANCES := ["dance-wave", "dance-sway", "dance-hop"]
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
	duck.position = Vector2(28, 24)
	duck.size = Vector2(112, 112)
	duck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	duck.set_process(false)
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
		duck._trick, duck._trick_left, duck._room_motion, duck._room_step,
		duck._room_reaction, duck._room_reaction_left, duck._reaction, duck.reaction_left,
		duck._speech_time, duck._idle_time]


func _check_contract(duck: Button) -> void:
	check(duck.theme_id == "spring", "Pip starts in the spring gardener outfit")
	var events: Array[String] = []
	duck.pressed.connect(func() -> void: events.append("pressed"))
	var bounds: Rect2 = duck.get_global_rect()
	var nodes := duck.get_child_count()
	for scenario in ["quiet", "dance", "speaking", "walking", "room reaction", "invitation", "reduced"]:
		_reset_visual(duck)
		match scenario:
			"dance": duck.perform_trick("dance")
			"speaking": duck.set_speaking(true)
			"walking": duck.set_room_motion("walk", -1)
			"room reaction": duck.react_in_room("high-five")
			"invitation": check(_start_idle(duck, "dance-sway"), "The wardrobe fixture reaches a real idle dance")
			"reduced":
				duck.set_reduced_motion(true)
				duck.perform_trick("high-five")
		_advance(duck, 0.25)
		var before := _activity(duck)
		for theme in THEMES:
			duck.set_outfit_theme(theme)
			check(duck.theme_id == theme and _activity(duck) == before,
				"Changing to " + theme + " preserves the active " + scenario + " exactly")
			var sheets: Array[Texture2D] = [duck._outfit_sheet, duck._outfit_idle_sheet, duck._outfit_dance_sheet]
			check(sheets.all(func(texture: Texture2D) -> bool: return texture != null and texture.get_height() > 0),
				"The " + theme + " wardrobe supplies regular, idle and articulated art")
			if sheets.all(func(texture: Texture2D) -> bool: return texture != null):
				check(sheets[0].get_width() == sheets[0].get_height() * 4
					and sheets[1].get_width() == sheets[1].get_height() * 4
					and sheets[2].get_width() == sheets[2].get_height() * 6,
					"Imported wardrobe cells retain square pose and limb dimensions at any SVG import scale")
			duck.set_outfit_theme(theme)
			check([duck._outfit_sheet, duck._outfit_idle_sheet, duck._outfit_dance_sheet] == sheets
				and _activity(duck) == before, "An unchanged outfit neither reloads art nor restarts activity")
		duck.set_outfit_theme("unknown-wardrobe")
		check(duck.theme_id == "spring" and _activity(duck) == before,
			"An unknown wardrobe safely falls back to spring without interrupting " + scenario)
	check(events.is_empty() and duck.get_child_count() == nodes,
		"Wardrobe changes create no activation, audio player, timer or effect nodes")
	check(duck.get_global_rect() == bounds and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation),
		"Every wardrobe retains the exact Button input bounds")
	_reset_visual(duck)


func _reset_visual(duck: Button) -> void:
	duck.set_reduced_motion(false)
	duck.set_idle_paused(false)
	duck.set_proactive_allowed(false)
	duck.settle()
	duck.compact = false
	duck.position = Vector2(28, 24)
	duck.size = Vector2(112, 112)
	duck.set_process(false)


func _start_idle(duck: Button, wanted: String) -> bool:
	duck.settle()
	duck.set_proactive_allowed(true)
	for invitation in range(42):
		duck.note_activity()
		for step in range(200):
			duck._process(0.05)
			if not duck._idle_action.is_empty():
				break
		if duck._idle_action == wanted:
			return true
	return false


func _capture(viewport: SubViewport, duck: Button) -> Image:
	duck.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _part(image: Image, logical: Rect2) -> Image:
	var origin := Vector2(28, 24) + logical.position * (112.0 / 120.0)
	var dimensions := logical.size * (112.0 / 120.0)
	return image.get_region(Rect2i(Vector2i(origin.round()), Vector2i(dimensions.round())))


func _different_pixels(reference: Image, candidate: Image) -> float:
	if reference.is_empty() or candidate.is_empty() or reference.get_size() != candidate.get_size():
		return 1.0
	var a: Image = reference.duplicate()
	var b: Image = candidate.duplicate()
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var left := a.get_data()
	var right := b.get_data()
	var changed := 0
	for offset in range(0, left.size(), 4):
		for channel in range(4):
			if absi(int(left[offset + channel]) - int(right[offset + channel])) > 60:
				changed += 1
				break
	return float(changed) / (left.size() / 4.0)


func _check_rendered_wardrobes(duck: Button) -> void:
	var directory := ProjectSettings.globalize_path("res://build/pip-outfits")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The wardrobe visual evidence directory is available")
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	duck.reparent(viewport)
	var caption := Label.new()
	caption.position = Vector2(2, 146)
	caption.size = Vector2(164, 20)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", Color("#3F5260"))
	viewport.add_child(caption)
	var atlas := AtlasTexture.new()
	atlas.atlas = Pip.SHEET
	atlas.region = Rect2(Vector2.ZERO, Vector2.ONE * Pip.SHEET.get_height())
	var original := TextureRect.new()
	original.texture = atlas
	original.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	original.position = duck.position
	original.size = duck.size
	viewport.add_child(original)
	duck.hide()
	var plain: Image = await _capture(viewport, duck)
	original.free()
	duck.show()
	var plain_hat := _part(plain, Rect2(12, 0, 97, 31))
	var plain_body := _part(plain, Rect2(29, 85, 65, 25))
	var plain_face := _part(plain, Rect2(29, 32, 61, 44))
	var sheet := Image.create(CELL.x * THEMES.size(), CELL.y * 12, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#F1F6F4"))
	var hats: Array[PackedByteArray] = []
	var clothes: Array[PackedByteArray] = []
	var smalls: Array[PackedByteArray] = []
	var dance_frames: Dictionary = {"dance-wave": [], "dance-sway": [], "dance-hop": []}
	for column in range(THEMES.size()):
		var theme: String = THEMES[column]
		_reset_visual(duck)
		duck.set_outfit_theme(theme)
		caption.text = theme + " / resting"
		var resting: Image = await _capture(viewport, duck)
		_save_cell(resting, sheet, directory, theme, "resting", column, 0)
		var hat := _part(resting, Rect2(12, 0, 97, 31))
		var body := _part(resting, Rect2(29, 85, 65, 25))
		check(_different_pixels(plain_hat, hat) > 0.16 and _different_pixels(plain_body, body) > 0.16,
			theme + " adds substantial headwear and clothing, not only a small badge")
		check(not hats.has(hat.get_data()) and not clothes.has(body.get_data()),
			theme + " has its own rendered headwear and body outfit")
		hats.append(hat.get_data())
		clothes.append(body.get_data())
		check(_different_pixels(plain_face, _part(resting, Rect2(29, 32, 61, 44))) < 0.025,
			theme + " keeps Pip's original eyes and beak unobscured")
		duck.compact = true
		duck.position = Vector2(58, 58)
		duck.custom_minimum_size = Vector2.ZERO
		duck.size = Vector2(52, 52)
		caption.text = theme + " / header 52px"
		var small: Image = await _capture(viewport, duck)
		var small_pixels := small.get_region(Rect2i(56, 54, 60, 60)).get_data()
		check(not smalls.has(small_pixels), theme + " remains distinguishable at the actual small header size")
		smalls.append(small_pixels)
		_save_cell(small, sheet, directory, theme, "header", column, 1)
		var poses := ["speaking", "waving", "blinking", "look-left", "look-right", "stretch", "preen"]
		for index in range(poses.size()):
			_reset_visual(duck)
			var kind: String = poses[index]
			match kind:
				"speaking": duck.set_speaking(true)
				"waving":
					duck.react("happy")
					_advance(duck, 0.2)
				"blinking": _advance(duck, 4.5)
				"look-left": duck.set_room_motion("walk", -1)
				"look-right": duck.set_room_motion("walk", 1)
				"stretch": duck.react_in_room("catch")
				"preen":
					check(_start_idle(duck, "preen"), theme + " reaches the actual preening pose")
					_advance(duck, 0.4)
			caption.text = theme + " / " + kind
			var pose_image: Image = await _capture(viewport, duck)
			check(_part(pose_image, Rect2(12, 0, 97, 31)).get_data() != plain_hat.get_data(),
				theme + " retains headwear while " + kind)
			_save_cell(pose_image, sheet, directory, theme, kind, column, index + 2)
		for index in range(DANCES.size()):
			_reset_visual(duck)
			var kind: String = DANCES[index]
			check(_start_idle(duck, kind), theme + " reaches its actual scheduled " + kind)
			caption.text = theme + " / resting"
			var beginning: Image = await _capture(viewport, duck)
			check(_different_pixels(resting, beginning) < 0.08,
				theme + " keeps the same complete dressed silhouette at the start of " + kind)
			caption.text = theme + " / " + kind
			_advance(duck, 0.25)
			var early: Image = await _capture(viewport, duck)
			_advance(duck, 0.55)
			var middle: Image = await _capture(viewport, duck)
			_advance(duck, 1.1)
			var later: Image = await _capture(viewport, duck)
			check(early.get_data() != middle.get_data() and middle.get_data() != later.get_data(),
				theme + " has real multi-frame dressed motion in " + kind)
			var dressed_pixels := middle.get_region(Rect2i(0, 0, CELL.x, 142)).get_data()
			check(not dance_frames[kind].has(dressed_pixels),
				kind + " uses " + theme + " clothing on its articulated body and head")
			dance_frames[kind].append(dressed_pixels)
			_save_cell(middle, sheet, directory, theme, kind, column, index + 9)
			duck.note_activity()
			caption.text = theme + " / resting"
			check(_different_pixels(resting, await _capture(viewport, duck)) == 0.0,
				"Input settles " + theme + " clothing along with every limb")
		_reset_visual(duck)
		duck.set_reduced_motion(true)
		caption.text = theme + " / reduced"
		var still: Image = await _capture(viewport, duck)
		_advance(duck, 14.0)
		check((await _capture(viewport, duck)).get_data() == still.get_data(),
			theme + " stays completely static under reduced motion")
	check(sheet.save_png(directory + "/native-contact-sheet.png") == OK, "The full eight-theme native contact sheet is saved")
	check(sheet.get_region(Rect2i(0, 0, sheet.get_width(), CELL.y * 2)).save_png(directory + "/native-resting-header.png") == OK,
		"The full-size and header wardrobes are saved together for visual review")
	duck.reparent(root)
	viewport.queue_free()
	await process_frame


func _save_cell(frame: Image, sheet: Image, directory: String, theme: String, pose_name: String, column: int, row: int) -> void:
	sheet.blend_rect(frame, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))
	check(frame.save_png(directory + "/" + theme + "-" + pose_name + ".png") == OK,
		"Actual " + theme + " / " + pose_name + " pixels are available for independent review")

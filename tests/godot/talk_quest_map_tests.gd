extends SceneTree

const Atlas = preload("res://scripts/talk_quest_map.gd")
const Data = preload("res://scripts/talk_quest_data.gd")
var checks: int = 0
var failures: int = 0
var _selected: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func contains_monster_resource(value: Variant) -> bool:
	if value is Resource:
		var path: String = value.resource_path.to_lower()
		return path.contains("/monsters/") or path.ends_with("/talk_quest_monster.gd")
	if value is Array:
		for item in value:
			if contains_monster_resource(item):
				return true
	if value is Dictionary:
		for item in value.values():
			if contains_monster_resource(item):
				return true
	return false


func contains_portrait_or_scroll(node: Node) -> bool:
	if node is ScrollContainer or node is ScrollBar:
		return true
	# Sourced landscape and landmark textures are valid map artwork. Inspect
	# actual resources instead of treating every image node as a creature portrait.
	for property: Dictionary in node.get_property_list():
		if int(property.type) in [TYPE_OBJECT, TYPE_ARRAY, TYPE_DICTIONARY] and contains_monster_resource(node.get(str(property.name))):
			return true
	for child in node.get_children():
		if contains_portrait_or_scroll(child):
			return true
	return false


func check_source_texture(path: String, label: String) -> void:
	check(not path.is_empty() and ResourceLoader.exists(path, "Texture2D"), label + " has an imported source texture")
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return
	var texture: Texture2D = load(path)
	check(texture != null and texture.get_width() > 0 and texture.get_height() > 0,
		label + " resolves to usable artwork instead of an empty image")
	check(not contains_monster_resource(texture), label + " depicts a place instead of a monster portrait")


func check_sourced_art(atlas) -> void:
	var seen_landmarks: int = 0
	var manifest_path: String = ""
	for chapter in range(3):
		atlas.set_chapter(chapter)
		var art: Dictionary = atlas.art_snapshot()
		check_source_texture(str(art.get("background", "")), "Chapter %d background" % (chapter + 1))
		var paths: Array = art.get("landmarks", [])
		check(paths.size() == atlas.visible_level_buttons().size(),
			"Each visible destination has its own sourced landmark assignment")
		for index in range(paths.size()):
			check_source_texture(str(paths[index]), "Chapter %d landmark %d" % [chapter + 1, index + 1])
			seen_landmarks += 1
		manifest_path = str(art.get("source_manifest", ""))
	check(seen_landmarks == 14, "All fourteen destinations have sourced artwork")
	check(not manifest_path.is_empty() and FileAccess.file_exists(manifest_path),
		"The integrated map retains a source and license manifest")
	if not manifest_path.is_empty() and FileAccess.file_exists(manifest_path):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		check(manifest is Dictionary,
			"The source and license manifest is readable structured data")
		if manifest is Dictionary:
			var interface_art: Dictionary = manifest.get("ui", {})
			check(not interface_art.is_empty(), "The map retains sourced interface artwork")
			for role in interface_art:
				check_source_texture(str(interface_art[role]), "Map interface " + str(role))
			var sources: Array = manifest.get("sources", [])
			check(not sources.is_empty(), "The map identifies the original asset sources")
			for source: Dictionary in sources:
				for field in ["title", "creator", "url", "license", "licenseUrl", "acquisitionStatus", "animations"]:
					check(not str(source.get(field, "")).is_empty(),
						"Source %s records %s" % [str(source.get("id", "unknown")), field])
	atlas.set_chapter(0)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 760)
	var atlas = Atlas.new()
	root.add_child(atlas)
	atlas.size = Vector2(390, 540)
	atlas.configure(Data.levels())
	atlas.level_selected.connect(func(number: int) -> void: _selected = number)
	check(atlas.level_buttons.size() == 14, "All fourteen adventures retain accessible Button controls")
	check(not contains_portrait_or_scroll(atlas), "The atlas uses place landmarks without creature portraits or scrolling controls")
	check_sourced_art(atlas)
	for index in range(14):
		atlas.set_level_state(index + 1, index < 3, index == 0)
		var button: Button = atlas.level_buttons[index]
		check(button.disabled == (index >= 3), "Only unlocked stops accept input")
		check(button.accessibility_name.contains(Data.level(index + 1).title), "Every stop announces its full scene title")
	check(atlas.level_buttons[1].current_stop and not atlas.level_buttons[2].current_stop, "The beacon chooses the first unfinished unlocked adventure")
	check(atlas.level_buttons[0].accessibility_name.contains("Cleared"), "Completed state is announced independently of its color")
	atlas.level_buttons[1].pressed.emit()
	check(_selected == 2, "Selecting a landmark emits its actual level number")
	for layout: Dictionary in [
		{"size": Vector2(296, 308), "scale": 1.0},
		{"size": Vector2(320, 420), "scale": 1.0},
		{"size": Vector2(390, 340), "scale": 1.0},
		{"size": Vector2(844, 225), "scale": 1.0},
		{"size": Vector2(544, 140), "scale": 1.0},
		{"size": Vector2(544, 136), "scale": 1.0},
		{"size": Vector2(544, 140) / 0.75, "scale": 0.75},
		{"size": Vector2(960, 480), "scale": 1.0},
		{"size": Vector2(320, 420) / 0.75, "scale": 0.75}
	]:
		atlas.set_ui_scale(float(layout.scale))
		atlas.size = layout.size
		for chapter in range(3):
			atlas.set_chapter(chapter)
			await settle()
			check(atlas.custom_minimum_size == Vector2.ZERO and atlas.get_combined_minimum_size() == Vector2.ZERO,
				"Changing chapter or scale never expands the map beyond its available viewport")
			var visible_buttons: Array[Button] = atlas.visible_level_buttons()
			check(visible_buttons.size() == (6 if chapter == 1 else 4), "Only the current chapter's landmarks are visible")
			for index in range(visible_buttons.size()):
				var button: Button = visible_buttons[index]
				var rect: Rect2 = button.get_rect()
				check(rect.position.x >= 0 and rect.end.x <= atlas.size.x + 1, "Every visible landmark fits the map width")
				check(rect.position.y >= atlas._header_height and rect.end.y <= atlas.size.y + 1, "Every visible landmark fits below the chapter controls without scrolling")
				check(rect.size.x * float(layout.scale) >= 44 and rect.size.y * float(layout.scale) >= 44, "Every landmark keeps a generous physical touch target")
				for next_index in range(index + 1, visible_buttons.size()):
					check(not rect.intersects(visible_buttons[next_index].get_rect()), "Visible landmark touch targets never overlap")
				var caption: Label = button._caption
				check(caption.position.x >= 0 and caption.get_rect().end.x <= button.size.x
					and caption.position.y >= 0 and caption.get_rect().end.y <= button.size.y + 1,
					"Scene captions fit fully inside their responsive landmarks")
				check(caption.get_theme_font_size("font_size") * float(layout.scale) >= 12, "Responsive captions retain readable type size")
				check(caption.get_visible_line_count() >= caption.get_line_count(),
					"The complete scene title remains visible at %s (level %d)" % [str(layout.size), button.number])
				if button.compact:
					check(Rect2(Vector2.ZERO, button.size).encloses(button.compact_badge_rect()), "Compact number circles and completion stars paint entirely inside the level target")
					check(not caption.get_rect().intersects(button.compact_badge_rect()), "Compact captions never overlap the level number")
			for button: Button in atlas.level_buttons:
				if not button.visible:
					check(button.focus_mode == Control.FOCUS_NONE, "Hidden chapters cannot receive keyboard or controller focus")
			for button: Button in atlas.navigation_buttons():
				check(button.size.x * float(layout.scale) >= 44 and button.size.y * float(layout.scale) >= 44, "Chapter navigation retains a 44-pixel touch target")
				check(Rect2(Vector2.ZERO, atlas.size).encloses(button.get_rect()), "Chapter navigation stays within the atlas")
	for number in range(1, 15):
		atlas.set_level_state(number, number <= 11, number < 11)
	check(atlas.current_chapter == 2 and atlas.level_buttons[10].visible, "Newly reached destinations automatically reveal their chapter")
	atlas.set_chapter(0)
	atlas.set_level_state(11, true, false)
	check(atlas.current_chapter == 0, "Refreshing unchanged progress preserves a manually selected chapter")
	atlas.show_level(7)
	check(atlas.current_chapter == 1 and atlas.level_buttons[6].visible, "Continuing a saved adventure reveals its exact chapter")
	atlas.level_buttons[6].grab_focus()
	atlas.set_chapter(2)
	await settle()
	check(not atlas.level_buttons[6].has_focus() and atlas._previous.has_focus(), "Page navigation transfers focus away from hidden landmarks")
	atlas._previous.pressed.emit()
	check(atlas.current_chapter == 1, "Previous chapter opens the preceding page")
	atlas._next.grab_focus()
	atlas._next.pressed.emit()
	check(atlas.current_chapter == 2 and atlas._next.disabled, "Next chapter stops at the final page")
	check(atlas._previous.has_focus(), "Reaching the final chapter transfers focus from its disabled Next control")
	atlas.set_chapter(1)
	atlas._previous.grab_focus()
	atlas._previous.pressed.emit()
	check(atlas.current_chapter == 0 and atlas._next.has_focus(), "Returning to the first chapter transfers focus from its disabled Previous control")
	atlas.show_level(11)
	atlas.set_reduced_motion(true)
	var first_stop = atlas.level_buttons[10]
	var previous_time: float = first_stop._time
	first_stop._process(1.0)
	check(first_stop.reduced_motion and is_equal_approx(first_stop._time, previous_time), "Reduced motion freezes the next-stop beacon clock")
	atlas.configure([])
	await settle()
	check(atlas.level_buttons.is_empty() and atlas._route_points.is_empty() and not atlas._next.visible,
		"Reconfiguration removes old destinations, trails, and chapter controls")
	atlas.queue_free()
	await process_frame
	print("Talk Quest atlas: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

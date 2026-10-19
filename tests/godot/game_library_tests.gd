extends SceneTree

const Library = preload("res://scripts/game_library.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
var checks := 0
var failures := 0
var chosen := ""
var mode_requests := 0
var collection_visits := 0
var theme_chosen := ""

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in range(5):
		await process_frame

func move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame

func check_mode_previews(library: Library) -> void:
	root.size = Vector2i(1280, 900)
	library.fit(Vector2(1280, 900), 1.0)
	library.configure("word_jelly", false, false)
	await settle()
	await move_pointer(Vector2(1, 1))
	library.pip.grab_focus()
	await settle()
	var initial_requests: int = mode_requests
	var initial_phases: Array[float] = []
	for entry: Dictionary in library._tiles:
		initial_phases.append(entry.preview._elapsed)
	for tile: Dictionary in library._tiles:
		var preview: Control = tile.preview
		check(preview.mouse_filter == Control.MOUSE_FILTER_IGNORE and preview.focus_mode == Control.FOCUS_NONE,
			"%s: the decorative preview cannot intercept pointer or keyboard focus" % tile.entry.title)
		check(preview.is_processing() and not preview.highlighted,
			"%s: the gameplay demonstration runs without hover or focus" % tile.entry.title)
		var before_loop: float = preview._elapsed
		preview._process(preview.DURATION * 3.0 + 0.125)
		check(preview.is_processing() and preview._elapsed >= 0.0 and preview._elapsed < preview.DURATION
			and not is_equal_approx(preview._elapsed, before_loop),
			"%s: its timeline keeps advancing after several complete demonstrations" % tile.entry.title)
		tile.button.grab_focus()
		await settle()
		check(tile.button.has_focus() and preview.highlighted and preview.is_processing(),
			"%s: the parent game button retains keyboard focus while its scene loops" % tile.entry.title)
		library.pip.grab_focus()
		await settle()
		check(not preview.highlighted and preview.is_processing(),
			"%s: moving focus away clears its highlight without freezing the scene" % tile.entry.title)
	var distinct_phases: Array[float] = []
	for phase: float in initial_phases:
		if not distinct_phases.any(func(other: float) -> bool: return absf(other - phase) < 0.05):
			distinct_phases.append(phase)
	check(distinct_phases.size() >= 4, "The home scenes start at varied phases instead of all striking the same beat")
	check(mode_requests == initial_requests, "Previewing all six games never starts a game")
	var tile: Dictionary = library._tiles[0]
	var point: Vector2 = tile.preview.get_global_rect().get_center()
	await move_pointer(point)
	check(tile.button.is_hovered() and tile.preview.highlighted and tile.preview.is_processing(),
		"Hovering the miniature scene belongs to the parent game card")
	await move_pointer(Vector2(1, 1))
	check(not tile.preview.highlighted and tile.preview.is_processing(),
		"Moving the pointer away keeps the automatic demonstration running")
	library.hide()
	await settle()
	check(not library._tiles.any(func(entry: Dictionary) -> bool: return entry.preview.is_processing()),
		"Leaving Home stops every preview")
	var hidden_phases: Array[float] = []
	for entry: Dictionary in library._tiles:
		hidden_phases.append(entry.preview._elapsed)
	await settle()
	for index in range(library._tiles.size()):
		check(is_equal_approx(library._tiles[index].preview._elapsed, hidden_phases[index]),
			"%s: its timeline stays still while Home is hidden" % library._tiles[index].entry.title)
	library.show()
	await settle()
	check(library._tiles.all(func(entry: Dictionary) -> bool: return entry.preview.is_processing()),
		"Returning Home restarts every scene without another hover or focus gesture")
	library.finish_previews()
	await settle()
	check(not library._tiles.any(func(entry: Dictionary) -> bool: return entry.preview.is_processing()),
		"Backgrounding the page can suspend all demonstrations immediately")
	library.configure("word_jelly", false, false)
	tile.button.grab_focus()
	await move_pointer(point)
	check(not library._tiles.any(func(entry: Dictionary) -> bool: return entry.preview.is_processing()),
		"A settings refresh or focus change cannot restart a suspended page")
	library.hide()
	library.show()
	await settle()
	check(library._tiles.all(func(entry: Dictionary) -> bool: return entry.preview.is_processing()),
		"A visible Home visit resumes demonstrations after suspension")
	library.configure("word_jelly", false, true)
	await settle()
	check(not library._tiles.any(func(entry: Dictionary) -> bool: return entry.preview.is_processing()),
		"Enabling system reduced motion freezes all demonstrations immediately")
	library.pip.grab_focus()
	await move_pointer(point)
	check(not tile.preview.is_processing(), "Reduced motion preserves a static scene even when hovered")
	library.hide()
	library.show()
	await settle()
	check(not library._tiles.any(func(entry: Dictionary) -> bool: return entry.preview.is_processing()),
		"Returning Home honors reduced motion for all six scenes")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	root.push_input(release, true)
	await settle()
	check(chosen == "word_jelly" and mode_requests == initial_requests + 1,
		"Clicking inside a preview selects its game exactly once through the parent button")
	await move_pointer(Vector2(1, 1))
	library.pip.grab_focus()
	library.configure("word_jelly", false, false)
	await settle()
	check(library._tiles.all(func(entry: Dictionary) -> bool: return entry.preview.is_processing()),
		"Turning reduced motion off starts all scenes without interaction")
	library.configure("word_jelly", false, true)

func check_label_fits(label: Label, context: String) -> void:
	check(label.get_minimum_size().y <= label.size.y + 1.0,
		context + ": all text lines fit vertically")
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		for line: String in label.text.split("\n"):
			check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x + 1.0,
				context + ": each text line fits horizontally")

func check_growth_states(library: Library) -> void:
	var baby := {"ready": true, "completed": false, "age": 0, "learning_age": 3,
		"mastered": 0, "total": 60, "progress": 0.0, "lifetime_mastered": 0}
	library.configure_growth(baby)
	check(library.pip.growth_age == 0 and library.snapshot().hero.next_age == 3,
		"A new learner sees Baby Pip and the first earned appearance ahead")
	check(library._next_pip.visible and library._journey_bar.visible
		and is_zero_approx(library._journey_bar.value),
		"A new learner starts with an empty growth track and a visible destination")
	var growing := {"ready": true, "completed": false, "age": 6, "learning_age": 7,
		"mastered": 12, "total": 70, "progress": 12.0 / 70.0,
		"level_progress": 0.95, "lifetime_mastered": 165}
	library.configure_growth(growing)
	check(library.pip.growth_age == 6 and library.snapshot().hero.next_age == 7,
		"The growth journey pairs the earned Pip with the current learning destination")
	check(absf(library._journey_bar.value - 1200.0 / 70.0) <= 0.01,
		"The journey uses age mastery rather than independent experience-level progress")
	check(library._journey_count.text.contains("12") and library._journey_count.text.contains("70"),
		"The visible growth count reflects the current vocabulary cohort")
	var next_texture := library._next_pip.texture as AtlasTexture
	check(next_texture != null and next_texture.atlas.resource_path.ends_with("pip-lv7.png"),
		"The destination preview uses the actual next Pip appearance")
	var near_goal := {"ready": true, "completed": false, "age": 0, "learning_age": 3,
		"mastered": 69, "total": 80, "progress": 69.0 / 80.0, "lifetime_mastered": 69}
	library.configure_growth(near_goal)
	check(library._journey_heading.text == "11 more words to grow"
		and library._journey_count.text.contains("69") and library._journey_count.text.contains("80"),
		"Near the next growth stage, Home explains the remaining goal alongside the mastered count")
	near_goal.mastered = 79
	near_goal.progress = 79.0 / 80.0
	library.configure_growth(near_goal)
	check(library._journey_heading.text == "1 more word to grow"
		and library._journey_count.text.contains("79") and library._journey_count.text.contains("80"),
		"The final word uses a singular growth goal without losing the cohort count")
	var completed := {"ready": true, "completed": true, "age": 12, "learning_age": 12,
		"mastered": 180, "total": 200, "progress": 0.9, "lifetime_mastered": 1550}
	library.configure_growth(completed)
	check(library.pip.growth_age == 12 and library.snapshot().hero.next_age == -1
		and not library._next_pip.visible and not library._next_label.visible,
		"A completed journey never promises an unavailable next age")
	check(is_equal_approx(library._journey_bar.value, 100.0)
		and library._journey_count.text.contains("1550"),
		"Completion celebrates permanent growth and lifetime learning after a later missed word")
	library.configure_growth({"ready": false, "completed": false, "age": 0})
	check(not library._journey_bar.visible and not library._next_pip.visible
		and library.snapshot().hero.next_age == -1,
		"Unavailable saved progress cannot claim an empty or completed growth target")
	check(library._journey_count.text.to_lower().contains("unavailable"),
		"Unavailable saved progress has a readable recovery state")
	library.configure_growth(growing)
	check(library._journey_bar.visible and library._next_pip.visible
		and library._next_label.visible and library.snapshot().hero.ready,
		"Recovered progress restores the real growth journey")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var library := Library.new()
	root.add_child(library)
	library.fit(Vector2(1280, 800), 1.0)
	var catalog := Catalog.new()
	check(catalog.load_index(), "Home uses the real learning catalog")
	library.configure_learning(catalog, {}, {"phase": "idle"})
	await settle()
	check(library.learning.snapshot().screen == "paths" and not library.grid.visible
		and not library._hero.visible, "A fresh Home offers learning paths before games or age progress")
	check(not library._tiles.any(func(entry: Dictionary) -> bool: return entry.preview.is_processing()),
		"Hidden game previews do not animate before a learning path is selected")
	library.learning_context_selected.connect(func(selection: Dictionary) -> void:
		library.configure_learning(catalog, selection, {"phase": "idle"}))
	library.learning._growth_button.pressed.emit()
	await settle()
	check(library.grid.visible and library._hero.visible and library.learning.snapshot().screen == "summary",
		"Selecting Growth reveals the age journey and the six game choices")
	var focused_tile: Button = library.buttons[0]
	focused_tile.grab_focus()
	check(focused_tile.focus_mode == Control.FOCUS_ALL and focused_tile.get_theme_stylebox("focus") is StyleBoxEmpty,
		"Programmatic Home focus preserves navigation without a persistent dark pointer outline")
	var keyboard := InputEventKey.new()
	keyboard.keycode = KEY_TAB
	keyboard.pressed = true
	root.push_input(keyboard, true)
	check(focused_tile.get_theme_stylebox("focus") is StyleBoxFlat
		and focused_tile.get_theme_stylebox("focus").border_width_top >= 3,
		"Keyboard navigation restores the visible high-contrast focus outline")
	var pointer := InputEventScreenTouch.new()
	pointer.position = Vector2(1, 1)
	pointer.pressed = true
	root.push_input(pointer, true)
	check(focused_tile.get_theme_stylebox("focus") is StyleBoxEmpty,
		"Touch navigation hides only the focus decoration without disabling focus")
	pointer.pressed = false
	root.push_input(pointer, true)
	library.mode_requested.connect(func(id: String) -> void:
		chosen = id
		mode_requests += 1)
	library.collection_requested.connect(func() -> void: collection_visits += 1)
	library.theme_requested.connect(func(id: String) -> void: theme_chosen = id)
	library.configure_theme("ocean", false, false)
	check(library.theme_buttons.size() == 8 and library.theme_buttons[4].button_pressed
		and library.snapshot().theme_id == "ocean" and not library._theme_choices.visible,
		"Historical theme configuration is retained without exposing the removed manual picker")
	library.configure("", false, true)
	check(library.buttons.size() == 6, "Home offers all six supported games")
	check(not library.buttons.any(func(button: Button) -> bool: return button.button_pressed),
		"A first visit to Home does not claim a current game")
	check(library.find_child("LibraryClose", true, false) == null, "Home has no menu dismissal button")
	check(library.find_child("LibraryMotion", true, false) == null
		and not library.snapshot().controls.any(func(control: Dictionary) -> bool: return control.name == "LibraryMotion"),
		"Home has no manual motion control in its navigation or snapshot")
	check(library._footer.get_child_count() == 2, "Home keeps only the word library and sound controls in its footer")
	library.configure("word_jelly", false, true)
	check(library.buttons.front().button_pressed, "Home identifies the resumable Jelly Words game")
	library.pip.set_idle_paused(true)
	library.configure("word_jelly", false, true)
	check(library.pip._idle_paused, "Refreshing Home settings cannot resume Pip while the page is in the background")
	library.pip.set_idle_paused(false)
	library.set_growth_age(6)
	library.set_home_coins(123)
	check(library.pip.growth_age == 6, "Home uses the player's current Pip age")
	check_growth_states(library)
	library.collection_button.pressed.emit()
	check(collection_visits == 1, "Home requests the collection once")
	await check_mode_previews(library)
	for dimensions: Vector2 in [Vector2(320, 320), Vector2(390, 420), Vector2(390, 600), Vector2(390, 844), Vector2(768, 1024), Vector2(844, 390), Vector2(1280, 800)]:
		root.size = dimensions
		library.position = Vector2.ZERO
		library.fit(dimensions, 1.0)
		await settle()
		library.fit(dimensions, 1.0)
		await settle()
		var bounds := Rect2(Vector2.ZERO, dimensions)
		check(bounds.grow(1).encloses(library.get_global_rect()) and library.size.is_equal_approx(dimensions),
			"%s: Home fills the viewport without overflowing" % dimensions)
		var hero_bounds: Rect2 = library._hero.get_global_rect()
		var journey_bounds: Rect2 = library._journey.get_global_rect()
		check(hero_bounds.grow(1).encloses(journey_bounds),
			"%s: the unified growth panel stays inside the Home hero" % dimensions)
		var journey_content: Array[Control] = [library.pip, library.heading, library._journey_heading,
			library._journey_count, library._journey_bar, library._next_pip]
		for child: Control in journey_content + [library._pip_caption, library._next_label]:
			check(journey_bounds.grow(1).encloses(child.get_global_rect()),
				"%s: the unified growth panel contains %s" % [dimensions, child.name])
		for first in range(journey_content.size()):
			for second in range(first + 1, journey_content.size()):
				check(not journey_content[first].get_global_rect().intersects(journey_content[second].get_global_rect()),
					"%s: %s and %s have separate readable space" % [dimensions, journey_content[first].name, journey_content[second].name])
		check(not library.heading.text.contains("\n"),
			"%s: the growth headline avoids an unnecessary forced line break" % dimensions)
		for label: Label in [library.heading, library._journey_heading, library._journey_count, library._pip_caption, library._next_label]:
			check_label_fits(label, "%s: %s" % [dimensions, label.name])
		check(not library._theme_choices.visible and library.theme_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()),
			"%s: automatic learning themes leave no hidden manual picker in the focus flow" % dimensions)
		library.learning._change_path.grab_focus()
		await settle()
		check(library.learning._change_path.has_focus() and library.scroll.get_global_rect().grow(1).encloses(library.learning._change_path.get_global_rect()),
			"%s: changing the learning path remains keyboard reachable" % dimensions)
		for tile: Dictionary in library._tiles:
			library.ensure_mode_visible(str(tile.entry.id))
			await settle()
			var button: Button = tile.button
			var scroll_bounds: Rect2 = library.scroll.get_global_rect()
			check(button.size.x >= 43 and button.size.y >= 43,
				"%s: %s keeps a comfortable touch target" % [dimensions, button.name])
			check(scroll_bounds.grow(1).encloses(button.get_global_rect()) and bounds.grow(1).encloses(button.get_global_rect()),
				"%s: scrolling fully reveals %s" % [dimensions, button.name])
			check(button.get_global_rect().grow(1).encloses(tile.title.get_global_rect()),
				"%s: the %s title fits its card" % [dimensions, tile.entry.title])
			var preview_bounds: Rect2 = tile.preview.get_global_rect()
			check(button.get_global_rect().grow(1).encloses(preview_bounds)
				and not preview_bounds.intersects(tile.title.get_global_rect())
				and not preview_bounds.intersects(tile.copy.get_global_rect()),
				"%s: the %s preview fits above its readable title and description" % [dimensions, tile.entry.title])
			button.grab_focus()
			await settle()
			check(button.has_focus() and library.scroll.get_global_rect().has_point(button.get_global_rect().get_center()),
				"%s: keyboard focus reveals %s" % [dimensions, button.name])
			button.pressed.emit()
			check(chosen == tile.entry.id, "Each Home card requests its own game: " + str(tile.entry.id))
		check(absf(library.sound_button.size.x - library.collection_button.size.x) <= 1.0,
			"%s: both Home footer controls share the available width equally" % dimensions)
		for button: Button in [library.collection_button, library.sound_button]:
			button.grab_focus()
			await settle()
			check(bounds.grow(1).encloses(button.get_global_rect()) and button.size.y >= 43,
				"%s: focused %s stays reachable" % [dimensions, button.name])
		if dimensions == Vector2(320, 320):
			check(library.scroll.get_v_scroll_bar().max_value > library.scroll.get_v_scroll_bar().page,
				"A small Home viewport scrolls instead of cramping every game into a tiny row")
	root.size = Vector2i(640, 400)
	library.fit(Vector2(640, 400), 2.0)
	await settle()
	var portrait_css_size := library.pip.size * 2.0
	check(portrait_css_size.x >= 96.0 and portrait_css_size.x <= 208.0
		and portrait_css_size.is_equal_approx(Vector2.ONE * portrait_css_size.x)
		and library._journey.get_global_rect().grow(1).encloses(library.pip.get_global_rect())
		and not library.pip.get_global_rect().intersects(library.heading.get_global_rect()),
		"A scaled Home portrait stays recognizable, enclosed by the growth panel and clear of the welcome text")
	root.size = Vector2i(854, 480)
	library.fit(Vector2(853.75, 480), 1.6)
	library._keyboard_focus_visible = true
	await settle()
	library.collection_button.grab_focus()
	await settle()
	library.sound_button.grab_focus()
	await settle()
	check(library.scroll.get_global_rect().grow(0.01).encloses(library.sound_button.get_global_rect()),
		"Fractional browser scaling fully reveals the focused Sound button without clipping a CSS pixel")
	for dimensions: Vector2i in [Vector2i(320, 320), Vector2i(844, 260)]:
		root.size = dimensions
		library.fit(Vector2(dimensions), 1.0)
		library.learning._show_courses()
		await settle()
		var career: Control = library.learning.find_child("Career_retail", true, false)
		check(career != null, "The actual illustrated Retail card remains available in a short viewport")
		library.learning._search.grab_focus()
		await settle()
		career.grab_focus()
		await settle()
		var viewport: Rect2 = library.scroll.get_global_rect()
		var card: Rect2 = career.get_global_rect()
		check(career.has_focus() and card.size.y > viewport.size.y,
			"%s: the regression exercises an illustrated card taller than the available scroll viewport" % dimensions)
		check(card.position.y >= viewport.position.y and card.position.y <= viewport.position.y + 4.0
			and viewport.intersection(card).size.y >= 44.0,
			"%s: an oversized focused career begins at its illustration/title and retains a visible activation target" % dimensions)
	library.queue_free()
	await process_frame
	print("Game homepage: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

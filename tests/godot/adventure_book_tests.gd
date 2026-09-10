extends SceneTree

const Data = preload("res://scripts/game_data.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture()
		return
	var path := "res://scripts/adventure_book.gd"
	check(FileAccess.file_exists(path), "The adventure book view exists")
	if not FileAccess.file_exists(path):
		_finish()
		return
	var script = load(path)
	check(script != null and script.can_instantiate(), "The adventure book compiles")
	if script == null or not script.can_instantiate():
		_finish()
		return
	var view = script.new()
	root.add_child(view)
	view.size = Vector2(288, 1600)
	var recent: Array = ["animal-friends", "picnic-time", "animal-friends", "not-a-place"]
	view.setup("animal-friends", recent, "space-trip", Color("#438363"))
	await process_frame
	await process_frame
	check(view is VBoxContainer, "The book fits inside the host's existing scrolling column")
	check(view.buttons.size() == 12, "All twelve topics have a card")
	check(view.find_child("Intro", true, false).text == "Pick a place. Learn five words, then play!", "The introduction explains the five-word loop")
	check(view.find_child("VisitCount", true, false).text == "Places visited 2 / 12", "Visits count only unique canonical places")
	check(view.controls().size() == 14, "The host receives all twelve cards, surprise, and retry")
	check(view.controls().has(view.retry_button) and not view.retry_button.visible, "A hidden retry is available for one-time host wiring")
	check(not view.find_child("SaveFailure", true, false).visible, "The save notice starts hidden")
	var original_controls: Array = view.controls()
	var selections: Array[String] = []
	var surprises: Array[bool] = []
	var retries: Array[bool] = []
	view.adventure_selected.connect(func(id: String) -> void: selections.append(id))
	view.surprise_requested.connect(func() -> void: surprises.append(true))
	view.retry_requested.connect(func() -> void: retries.append(true))
	for topic in Data.ADVENTURES:
		check(view.buttons.has(topic.id), topic.name + " has a stable selector")
		if not view.buttons.has(topic.id):
			continue
		var button: Button = view.buttons[topic.id]
		check(button.focus_mode == Control.FOCUS_ALL and not button.disabled, topic.name + " is immediately selectable")
		check(button.find_child("TopicName", true, false).text == topic.name, topic.name + " displays its name")
		var status: String = button.find_child("VisitStatus", true, false).text
		var expected := "Pip is here" if topic.id == "animal-friends" else "Visited" if topic.id == "picnic-time" else "New place"
		check(status == expected, topic.name + " reports its current visit state")
		var suggestion: Label = button.find_child("Suggestion", true, false)
		check(suggestion.visible == (topic.id == "space-trip") and suggestion.text == "Try this next", topic.name + " shows a suggestion only when requested")
		var pictures: Array[TextureRect] = []
		for descendant in button.find_children("*", "TextureRect", true, false):
			pictures.append(descendant)
		check(pictures.size() == 2, topic.name + " uses two familiar pictures")
		for picture in pictures:
			check(picture.texture != null, topic.name + " has loaded artwork")
			if picture.texture != null:
				var art_path: String = picture.texture.resource_path
				check(art_path.begins_with("res://assets/images/words/") and art_path.ends_with(".svg"), topic.name + " uses the original SVG word art")
				check(topic.words.has(art_path.get_file().get_basename()), topic.name + " illustrates words from its own topic")
		for descendant in button.find_children("*", "Control", true, false):
			check(descendant.mouse_filter == Control.MOUSE_FILTER_IGNORE and descendant.focus_mode == Control.FOCUS_NONE, "Card decoration leaves pointer and keyboard input on " + topic.name)
		button.pressed.emit()
		check(selections.back() == topic.id, topic.name + " emits its destination")
	check(selections.size() == 12 and selections[0] == "animal-friends", "Each selection emits once, including a revisit to the current place")
	view.surprise_button.pressed.emit()
	check(surprises.size() == 1, "Surprise me emits one request")
	check(recent == ["animal-friends", "picnic-time", "animal-friends", "not-a-place"], "Choosing a card never edits the host's visit history")
	check(view.find_child("VisitCount", true, false).text == "Places visited 2 / 12", "Selection does not claim an unsaved visit")
	view.setup("space-trip", recent, "garden-trail", Color("#69569b"), true)
	check(view.controls() == original_controls, "Setup preserves every focus and scroll control")
	check(view.retry_button.visible and view.find_child("SaveFailure", true, false).visible, "A failed save reveals its notice and retry")
	check(view.find_child("SaveFailure", true, false).text == "This visit could not be remembered.", "A failed save uses honest recovery copy")
	check(view.buttons["space-trip"].find_child("VisitStatus", true, false).text == "Pip is here", "The current place is shown even when its visit could not be remembered")
	check(view.find_child("VisitCount", true, false).text == "Places visited 2 / 12", "The count never invents a persisted current visit")
	check(view.buttons["animal-friends"].find_child("VisitStatus", true, false).text == "Visited", "Leaving a place restores its remembered status")
	view.retry_button.pressed.emit()
	check(retries.size() == 1, "Retry emits one request")
	check(view.find_child("SaveFailure", true, false).visible, "Only the host clears a save failure after persistence succeeds")
	view.setup("space-trip", [], "", Color("#216d89"))
	check(not view.retry_button.visible and not view.find_child("SaveFailure", true, false).visible, "A later successful setup clears the save notice")
	check(view.find_child("VisitCount", true, false).text == "Places visited 0 / 12", "An empty history reports zero visits")
	for topic in Data.ADVENTURES:
		check(not view.buttons[topic.id].find_child("Suggestion", true, false).visible, "Clearing the suggestion removes stale card cues")
	view.hide()
	check(view.controls() == original_controls, "A hidden book still exposes every control for host wiring")
	view.show()
	view.setup("animal-friends", recent, "space-trip", Color("#438363"), true)
	for dimensions in [[288, 2], [456, 2], [700, 3], [1000, 4], [288, 2]]:
		view.size = Vector2(dimensions[0], 1600)
		await process_frame
		await process_frame
		var grid: GridContainer = view.find_child("Places", true, false)
		check(grid.columns == dimensions[1], "The book chooses readable columns at width " + str(dimensions[0]))
		check(view.get_combined_minimum_size().x <= dimensions[0], "The book can shrink to content width " + str(dimensions[0]))
		for control in view.controls():
			check(control.size.x >= 44 and control.size.y >= 44, "Book controls have generous touch targets")
			check(control.get_global_rect().position.x >= view.global_position.x - 1 and control.get_global_rect().end.x <= view.global_position.x + view.size.x + 1, "Book controls stay within width " + str(dimensions[0]))
		for button in view.buttons.values():
			for decoration in button.find_children("*", "Control", true, false):
				if not decoration.visible:
					continue
				check(button.get_global_rect().grow(1).encloses(decoration.get_global_rect()), "Card artwork and labels fit at width " + str(dimensions[0]))
		var card_list: Array = view.buttons.values()
		for index in range(1, card_list.size()):
			check(not card_list[index - 1].get_global_rect().intersects(card_list[index].get_global_rect()), "Adjacent cards never overlap")
	check(view.find_children("*", "ScrollContainer", true, false).is_empty(), "The book delegates scrolling to its host")
	check(not view.is_processing(), "Static postcards require no motion")
	view.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("Adventure book: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _capture() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var view = load("res://scripts/adventure_book.gd").new()
	var scroll := ScrollContainer.new()
	root.add_child(scroll)
	scroll.position = Vector2(16, 16)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(view)
	view.setup("animal-friends", ["animal-friends", "picnic-time", "on-the-move"], "space-trip", Color("#438363"), true)
	DirAccess.make_dir_recursive_absolute("res://build/visuals")
	for width in [320, 960]:
		root.size = Vector2i(width, 900)
		scroll.size = Vector2(width - 32, 868)
		scroll.scroll_vertical = 0
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/visuals/adventure-book-%d.png" % width)
		if width == 320:
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/visuals/adventure-book-320-bottom.png")
	print("Captured adventure book at phone and desktop widths.")
	quit()

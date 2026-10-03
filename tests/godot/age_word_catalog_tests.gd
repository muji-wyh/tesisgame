extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Catalog = preload("res://scripts/age_word_catalog.gd")

var checks := 0
var failures := 0
var heard: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func pointer(point: Vector2, down: bool, touch: bool) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = point
	event.pressed = down
	root.push_input(event, true)
	await process_frame


func motion(point: Vector2, touch: bool) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenDrag.new()
		event.index = 0
	else:
		event = InputEventMouseMotion.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	event.relative = Vector2(0, -300)
	root.push_input(event, true)
	await process_frame


func _run() -> void:
	# This standalone component fixture never creates or reads a player save.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640, 800)
	var data := Data.new()
	check(data.load_all(), "The catalogue uses successfully loaded production word data: " + data.error)
	if failures:
		quit(1)
		return
	var catalog := Catalog.new()
	catalog.position = Vector2(12, 108)
	catalog.size = Vector2(616, 680)
	catalog.hear_requested.connect(func(word: Dictionary) -> void: heard.append(word))
	root.add_child(catalog)
	await settle()
	await _check_content(catalog, data.words)
	await _check_layout(catalog)
	root.size = Vector2i(640, 800)
	catalog.size = Vector2(616, 680)
	await settle()
	await _check_input(catalog)
	await _check_cancellations(catalog)
	await _check_stretched_resize(catalog)
	catalog.queue_free()
	await process_frame
	print("Age word catalogue: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_content(catalog: Catalog, words: Array) -> void:
	var counts := {"all": 350, "4-6": 148, "7-9": 112, "10-plus": 90}
	var levels := {"4-6": "basic", "7-9": "growing", "10-plus": "advanced"}
	var english := RegEx.new()
	english.compile("^[A-Za-z][A-Za-z '-]*$")
	for band: Dictionary in Data.age_bands():
		# Raw curriculum tiers are independent of the production age-level helper.
		var eligible: Array = words.filter(func(word: Dictionary) -> bool:
			return band.id == "all" or word.level == levels[band.id])
		var expected: Array = eligible.map(func(word: Dictionary) -> String: return word.id)
		eligible.reverse()
		catalog.configure(eligible, band, Data.theme("spring"))
		await settle()
		check(catalog.snapshot().word_count == counts[band.id]
			and catalog.title_label.text == band.name
			and catalog.count_label.text == "%d words" % counts[band.id],
			"Age " + band.id + " shows only its own range's word count with an English heading")
		var seen: Dictionary = {}
		var previous := ""
		for button: Button in catalog.word_buttons:
			var word: Dictionary = button.get_meta("word")
			var picture: TextureRect = button.get_meta("word_art")
			var caption: Label = button.get_meta("word_label")
			check(not seen.has(word.id) and eligible.has(word), "Each eligible word appears exactly once: " + word.id)
			seen[word.id] = true
			check(english.search(caption.text) != null and caption.text == word.text
				and previous.naturalnocasecmp_to(caption.text) <= 0,
				"English word labels are alphabetically ordered: " + word.id)
			previous = caption.text
			check(picture.texture != null and picture.texture.resource_path == "res://" + word.image
				and ResourceLoader.exists("res://" + word.audio),
				"The catalogue retains the loaded illustration and recorded pronunciation: " + word.id)
		check(seen.size() == expected.size() and expected.all(func(id: String) -> bool: return seen.has(id)),
			"Age " + band.id + " contains its exact curriculum tier")
		for topic: Dictionary in Data.ADVENTURES:
			var topic_words: Array = eligible.filter(func(word: Dictionary) -> bool: return topic.words.has(word.id))
			check(topic_words.all(func(word: Dictionary) -> bool: return seen.has(word.id)),
				"Age " + band.id + " includes all eligible vocabulary from " + topic.name)
		var last: Button = catalog.word_buttons.back()
		check(catalog.focus_word(str(last.get_meta("word_id"))), "Words can be located through the public focus API")
		await settle()
		var offset: int = catalog.scroll.scroll_vertical
		catalog.configure(eligible, band, Data.theme("spring"))
		await settle()
		check(catalog.word_buttons.back() == last and last.has_focus() and catalog.scroll.scroll_vertical == offset,
			"Refreshing the selected age preserves focused words and reading position")
	check(not catalog.focus_word("missing-word"), "Unknown word focus requests are rejected")
	catalog.configure(words, Data.age_band("all"), Data.theme("spring"))
	await settle()


func _check_layout(catalog: Catalog) -> void:
	for dimensions in [Vector2i(320, 320), Vector2i(320, 568), Vector2i(390, 844),
		Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		catalog.size = Vector2(dimensions.x - 24, dimensions.y - 120)
		await settle()
		var suffix := " at %dx%d" % [dimensions.x, dimensions.y]
		check(catalog.size.x <= dimensions.x - 24 and catalog.scroll.size.y > 0,
			"The catalogue fits the available page area" + suffix)
		check(not catalog.scroll.get_h_scroll_bar().is_visible_in_tree()
			and not catalog.scroll.get_v_scroll_bar().is_visible_in_tree()
			and catalog.snapshot().scroll_max > 0,
			"A complete vocabulary stays scrollable without visible rails" + suffix)
		var bounds: Rect2 = catalog.scroll.get_global_rect()
		for button: Button in catalog.word_buttons:
			var rect: Rect2 = button.get_global_rect()
			var caption: Label = button.get_meta("word_label")
			check(rect.position.x >= bounds.position.x - 1 and rect.end.x <= bounds.end.x + 1
				and button.size.x >= 48 and button.size.y >= 48,
				"Every word has a reachable touch target within the page width" + suffix)
			check(caption.get_global_rect().end.y <= rect.end.y + 1
				and caption.size.x >= caption.get_minimum_size().x - 1,
				"The full word caption fits its illustrated card" + suffix)
		var last: Button = catalog.word_buttons.back()
		catalog.focus_word(str(last.get_meta("word_id")))
		await settle()
		var last_label: Label = last.get_meta("word_label")
		check(last.has_focus() and catalog.scroll.scroll_vertical > 0
			and bounds.encloses(last_label.get_global_rect()),
			"Keyboard focus reveals the last word with hidden scrollbars" + suffix)
		catalog.focus_word(str(catalog.word_buttons.front().get_meta("word_id")))
		await settle()
		check(catalog.scroll.scroll_vertical <= 4, "Keyboard focus returns to the first word" + suffix)


func _check_input(catalog: Catalog) -> void:
	var first: Button = catalog.word_buttons.front()
	for touch_first in [false, true]:
		catalog.scroll.cancel_drag()
		catalog.scroll.scroll_vertical = 0
		await settle()
		var point: Vector2 = first.get_global_transform_with_canvas() * (first.size * 0.5)
		var before := heard.size()
		await pointer(point, true, touch_first)
		await pointer(point, true, not touch_first)
		check(catalog.scroll.is_pointer_active() and heard.size() == before, "Touch press waits for release before pronunciation")
		await pointer(point, false, touch_first)
		await pointer(point, false, not touch_first)
		check(heard.size() == before + 1 and heard.back() == first.get_meta("word") and first.has_focus(),
			"Paired touch and emulated mouse events request the correct pronunciation exactly once")
		before = heard.size()
		point = catalog.scroll.get_global_transform_with_canvas() * Vector2(80, 280)
		await pointer(point, true, touch_first)
		await pointer(point, true, not touch_first)
		await motion(point - Vector2(0, 100), touch_first)
		await motion(point - Vector2(0, 100), not touch_first)
		check(catalog.scroll.scroll_vertical == 100,
			"The vocabulary follows held input once before its inertial release")
		await pointer(point - Vector2(0, 100), false, touch_first)
		await pointer(point - Vector2(0, 100), false, not touch_first)
		check(heard.size() == before,
			"Dragging the vocabulary never pronounces a crossed word")
	catalog.scroll.cancel_drag()
	catalog.focus_word(str(first.get_meta("word_id")))
	await settle()
	var before := heard.size()
	for down in [true, false]:
		var key := InputEventAction.new()
		key.action = "ui_accept"
		key.pressed = down
		root.push_input(key, true)
		await process_frame
	check(heard.size() == before + 1, "Keyboard activation pronounces a focused word once")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = catalog.scroll.get_global_transform_with_canvas() * Vector2(80, 280)
	root.push_input(wheel, true)
	await settle()
	check(catalog.scroll.scroll_vertical > 0, "Desktop mouse wheel reaches additional vocabulary")


func _check_cancellations(catalog: Catalog) -> void:
	var first: Button = catalog.word_buttons.front()
	for cause in ["cancel", "hide", "resize", "blocked"]:
		catalog.scroll.cancel_drag()
		catalog.scroll.scroll_vertical = 0
		await settle()
		var point: Vector2 = first.get_global_transform_with_canvas() * (first.size * 0.5)
		var before := heard.size()
		await pointer(point, true, true)
		await pointer(point, true, false)
		match cause:
			"cancel": catalog.cancel_input()
			"hide":
				catalog.hide()
				catalog.show()
			"resize":
				catalog.size.x -= 8
				await settle()
			"blocked":
				catalog.interaction_allowed = func() -> bool: return false
		await pointer(point, false, true)
		await pointer(point, false, false)
		check(heard.size() == before and not catalog.scroll.is_pointer_active()
			and first.self_modulate.is_equal_approx(Color.WHITE),
			"An unfinished word tap is disarmed after " + cause)
		catalog.interaction_allowed = Callable()
	catalog.hide()
	var before := heard.size()
	first.pressed.emit()
	check(heard.size() == before and not catalog.focus_word(str(first.get_meta("word_id"))),
		"Hidden catalogue controls cannot pronounce or take focus")


func _check_stretched_resize(catalog: Catalog) -> void:
	catalog.show()
	root.content_scale_size = Vector2i(480, 480)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for dimensions in [Vector2i(960, 720), Vector2i(390, 844), Vector2i(557, 1206),
		Vector2i(844, 390), Vector2i(1206, 557), Vector2i(390, 844)]:
		catalog.focus_word("ant")
		await settle()
		root.size = dimensions
		await process_frame
		var canvas_size: Vector2 = root.get_visible_rect().size
		var scale: float = preload("res://scripts/ui_style.gd").ui_scale(catalog)
		catalog.position = Vector2(12, 108) / scale
		catalog.size = Vector2(minf(960.0 / scale, canvas_size.x - 24.0 / scale), canvas_size.y - 120.0 / scale)
		var largest_offset := 0
		for frame in range(40):
			await process_frame
			largest_offset = maxi(largest_offset, catalog.scroll.scroll_vertical)
		var focused: Control = root.gui_get_focus_owner()
		check(is_instance_valid(focused) and focused.get_meta("word_id", "") == "ant"
			and catalog.scroll.get_global_rect().encloses(focused.get_global_rect()),
			"Canvas-items resize keeps the early focused word visible at %dx%d" % [dimensions.x, dimensions.y])
		check(largest_offset < catalog.scroll.size.y and catalog.scroll.scroll_vertical < catalog.snapshot().scroll_max,
			"Canvas-items resize does not run away to the vocabulary end at %dx%d (largest offset %d)" % [dimensions.x, dimensions.y, largest_offset])
		var offset: int = catalog.scroll.scroll_vertical
		for frame in range(30):
			await process_frame
		check(catalog.scroll.scroll_vertical == offset,
			"Focused-word scrolling settles after the canvas resize at %dx%d" % [dimensions.x, dimensions.y])
	for button: Button in catalog.word_buttons:
		button.focus_mode = Control.FOCUS_NONE
	root.size = Vector2i(960, 720)
	await process_frame
	catalog.size.x -= 8
	await settle()
	check(catalog.word_buttons.all(func(button: Button) -> bool: return button.focus_mode == Control.FOCUS_NONE),
		"Responsive restyling preserves modal-disabled word focus")
	for button: Button in catalog.word_buttons:
		button.focus_mode = Control.FOCUS_ALL

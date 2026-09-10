extends SceneTree

const Data = preload("res://scripts/game_data.gd")
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
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	await _album(words)
	await _room(words[0])
	await _lesson(words)
	print("Word sticker components: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _album(words: Array) -> void:
	var path := "res://scripts/word_sticker_book.gd"
	check(FileAccess.file_exists(path), "The Words album component exists")
	if not FileAccess.file_exists(path):
		return
	var script = load(path)
	check(script != null and script.can_instantiate(), "The Words album compiles")
	if script == null or not script.can_instantiate():
		return
	var book = script.new()
	book.hide()
	root.add_child(book)
	book.size = Vector2(288, 2000)
	var collected: Array[String] = ["cat", "dog", "apple"]
	book.setup(words, collected, "cat", Data.theme("spring"), true)
	check(book.word_buttons.size() == 24 and not book.word_buttons.has("apple"), "Only the selected topic has card nodes")
	for picture in book.find_children("*", "TextureRect", true, false):
		check(picture.texture == null, "A hidden album loads no word art")
	var heard: Array[String] = []
	var selections: Array[String] = []
	var displayed: Array[String] = []
	var retries: Array[bool] = []
	var changed: Array[bool] = []
	book.hear_requested.connect(func(word: Dictionary) -> void: heard.append(word.id))
	book.selection_changed.connect(func(word: Dictionary) -> void:
		selections.append(word.id)
		check(heard.size() < selections.size(), "Selection notification precedes pronunciation for host scrolling"))
	book.display_requested.connect(func(id: String) -> void: displayed.append(id))
	book.retry_requested.connect(func() -> void: retries.append(true))
	book.controls_changed.connect(func() -> void: changed.append(true))
	book.show()
	await process_frame
	await process_frame
	check(book.get_node("TotalCount").text == "Collected 3 / 140", "Album reports collected words without inventing mastery")
	check(book.get_node("TopicCount").text == "Collected 2 / 24", "Topic count belongs to the selected topic")
	check(book.word_buttons.cat.get_node("Picture").texture.resource_path == "res://assets/images/words/cat.svg", "Collected cards use their exact canonical picture")
	check(book.word_buttons.fish.disabled and book.word_buttons.fish.get_node("Picture").texture == null, "Uncollected words cannot pronounce or load reward art")
	book.word_buttons.fish.pressed.emit()
	check(heard.is_empty(), "Programmatic activation cannot bypass the collected guard")
	book.word_buttons.dog.pressed.emit()
	check(heard == ["dog"] and book.selected_word.id == "dog", "A collected picture selects and pronounces the same word")
	check(selections == ["dog"], "A collected picture notifies the host to expose its selected actions")
	book.display_button.pressed.emit()
	check(displayed == ["dog"], "Display requests the selected word without changing persistence")
	book.set_audio_available(false)
	book.word_buttons.cat.pressed.emit()
	book.hear_button.pressed.emit()
	check(heard == ["dog"] and book.selected_word.id == "cat", "Silent cards remain selectable without requesting audio")
	check(selections == ["dog", "cat"], "Silent selection still notifies the host for scrolling and announcement")
	check(book.hear_button.disabled, "Unavailable pronunciation has no active Hear button")
	book.retry_button.pressed.emit()
	check(retries.size() == 1 and book.retry_button.visible, "Retry leaves failure visible until the host confirms success")
	book.interaction_allowed = func() -> bool: return false
	book.word_buttons.dog.pressed.emit()
	book.display_button.pressed.emit()
	book.next_topic_button.pressed.emit()
	check(book.selected_word.id == "cat" and displayed == ["dog"] and book.topic_index == 0, "A modal blocks card, display and topic actions")
	book.interaction_allowed = Callable()
	book.next_topic_button.pressed.emit()
	check(book.topic_index == 1 and book.word_buttons.has("apple") and not book.word_buttons.has("cat"), "Next topic replaces its card controls")
	check(changed.size() == 1, "Topic navigation signals dynamic focus controls")
	check(book.selected_word.id == "apple", "A topic starts with one of its collected words selected")
	book.setup(words, collected, "apple", Data.theme("ocean"))
	check(book.topic_index == 1 and not book.retry_button.visible and book.display_button.disabled, "Refresh preserves topic and indicates the persisted display")
	await process_frame
	await process_frame
	check(book.get_combined_minimum_size().x <= 288, "The album fits a 320px phone with margins")
	for control in book.controls():
		if not control.is_visible_in_tree():
			continue
		check(control.size.x >= 44 and control.size.y >= 44, "Album controls have touch-sized targets")
		check(control.get_global_rect().position.x >= book.global_position.x - 1 and control.get_global_rect().end.x <= book.global_position.x + book.size.x + 1, "Album controls fit the narrow column")
	for index in range(11):
		book.next_topic_button.pressed.emit()
	check(book.topic_index == 0, "Topic navigation reaches all twelve topics and wraps")
	book.hide()
	book.word_buttons.cat.pressed.emit()
	check(heard == ["dog"], "Hidden album cards cannot play audio")
	book.queue_free()
	await process_frame


func _room(word: Dictionary) -> void:
	var room = load("res://scripts/playroom_view.gd").new()
	root.add_child(room)
	check(room.has_method("set_word_sticker"), "Pip's room exposes a displayed word sticker")
	if room.has_method("set_word_sticker"):
		var requests: Array[String] = []
		room.word_requested.connect(func(id: String) -> void: requests.append(id))
		room.set_word_sticker(word)
		check(room.word_sticker_button.visible and room.word_sticker_button.icon.resource_path == "res://" + word.image, "Room sticker shows the chosen exact picture")
		check(room.word_sticker_button.text == word.text and room.controls().has(room.word_sticker_button), "Room sticker exposes its word and focus control")
		check(room.word_sticker_button.get("accessibility_name") == "Hear " + str(word.text), "Room sticker's accessible name explains pronunciation")
		room.word_sticker_button.pressed.emit()
		check(requests == [word.id], "Room sticker requests its own word pronunciation")
		room.set_word_sticker(word, false)
		room.word_sticker_button.pressed.emit()
		check(room.word_sticker_button.disabled and requests.size() == 1, "Silent room stickers keep their picture but block pronunciation")
		check(room.word_sticker_button.get("accessibility_name") == "No sound. " + str(word.text), "Silent room sticker announces unavailable audio")
		room.set_word_sticker({})
		check(not room.word_sticker_button.visible and room.word_sticker_button.icon == null, "Clearing the displayed word removes stale art")
	room.queue_free()
	await process_frame


func _lesson(words: Array) -> void:
	var lesson = load("res://scripts/word_lesson.gd").new()
	root.add_child(lesson)
	lesson.show_words(words.slice(0, 2), "Learn")
	var has_button: bool = lesson.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "picture_button")
	check(has_button, "Learn exposes its exact picture as a real pronunciation button")
	if has_button:
		var heard: Array[String] = []
		lesson.hear_requested.connect(func(word: Dictionary) -> void: heard.append(word.id))
		check(lesson.picture is TextureRect and lesson.controls().has(lesson.picture_button), "Existing picture API stays intact and picture enters focus navigation")
		check(lesson.picture_button.get("accessibility_name") == words[0].text, "Picture's accessible name is exactly the current word")
		lesson.picture_button.pressed.emit()
		check(heard == [words[0].id], "Picture uses the existing Hear request")
		lesson.pause(true)
		lesson.picture_button.pressed.emit()
		check(lesson.picture_button.disabled and heard.size() == 1, "Paused lesson blocks picture pronunciation")
		lesson.pause(false)
		lesson.set_audio_available(false)
		lesson.picture_button.pressed.emit()
		check(lesson.picture_button.disabled and heard.size() == 1, "Unavailable audio disables picture pronunciation")
	lesson.queue_free()
	await process_frame

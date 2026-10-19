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


func _texture() -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))


func _run() -> void:
	var words: Array = []
	for word in JSON.parse_string(FileAccess.get_file_as_string("res://words.json")):
		if word.id in ["cat", "dog", "fish", "duck", "cow"]:
			words.append(word)
	var memory = preload("res://scripts/memory_garden.gd").new()
	root.add_child(memory)
	memory.start_round(words, Data.theme("spring"), 71)
	var picture: ImageTexture = _texture()
	var reference: WeakRef = weakref(picture)
	memory.card_buttons[0].picture.texture = picture
	memory.card_buttons[0].card_data.word["test_resource"] = picture
	picture = null
	memory.pause(true)
	check(reference.get_ref() != null, "Memory pause keeps its resumable media")
	memory.stop()
	check(reference.get_ref() == null, "Memory stop releases media before deferred node disposal")
	check(memory.card_buttons.is_empty() and memory.memory.cards.is_empty(), "Memory clears model and hidden card records")
	memory.start_round(words, Data.theme("spring"), 72)
	check(memory.card_buttons.size() == 10, "Memory can start again after teardown")
	memory.stop()
	memory.queue_free()

	var phrase = preload("res://scripts/phrase_game.gd").new()
	root.add_child(phrase)
	picture = _texture()
	reference = weakref(picture)
	var option := Button.new()
	option.icon = picture
	phrase._bank_content.add_child(option)
	phrase.option_buttons.append(option)
	phrase._preview.icon = picture
	phrase.game.questions.append({"test_resource": picture})
	phrase.game._question_options.append([{"test_resource": picture}])
	phrase._finished_options.append({"test_resource": picture})
	picture = null
	phrase.pause(true)
	check(reference.get_ref() != null, "Phrase pause retains round options")
	phrase.stop()
	check(reference.get_ref() == null, "Phrase stop clears live, preview and completed presentation media immediately")
	check(phrase.game.questions.is_empty() and phrase.game._question_options.is_empty(), "Phrase clears model word and expression banks")
	phrase.queue_free()

	var pop = preload("res://scripts/voice_pop.gd").new()
	root.add_child(pop)
	pop.configure(words, true, 9)
	picture = _texture()
	reference = weakref(picture)
	pop._textures.test = picture
	pop._words[0]["test_resource"] = picture
	pop.game._words[0]["test_resource"] = picture
	pop.game.hit_words.append({"test_resource": picture})
	pop.game.missed_words.append({"test_resource": picture})
	pop._bursts.append({"picture": picture})
	picture = null
	pop.stop()
	check(reference.get_ref() == null, "Voice Pop stop releases cached, sliced, model and result media")
	check(pop._words.is_empty() and pop.game._words.is_empty(), "Voice Pop clears both vocabulary owners")
	pop.configure(words, true, 10)
	check(pop.game.start(), "Voice Pop can start again after teardown")
	pop.stop()
	pop.queue_free()
	await process_frame
	await process_frame
	print("Professional view teardown: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

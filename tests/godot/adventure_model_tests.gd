extends SceneTree

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
	var model_script: GDScript = load("res://scripts/game_model.gd")
	var data_script: GDScript = load("res://scripts/game_data.gd")
	var adventures: Array = data_script.get_script_constant_map().get("ADVENTURES", [])
	var model = model_script.new()
	var properties: Array = model.get_property_list().map(func(value: Dictionary) -> String: return value.name)
	check(not adventures.is_empty(), "The vocabulary offers themed word adventures")
	check(properties.has("adventure_id") and properties.has("adventure_name"), "Rounds expose their word adventure")
	if not adventures.is_empty() and properties.has("adventure_id") and properties.has("adventure_name"):
		var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
		_test_catalog(adventures, words)
		_test_adventures(model, adventures, words)
		_test_replays(model, words)
		_test_small_vocabularies(model, words)
		_test_freshness_before_adventures(model, words)
	print("Word adventures: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_catalog(adventures: Array, words: Array) -> void:
	check(words.size() == 140 and adventures.size() == 12, "The expanded catalog contains 140 words in twelve adventures")
	var all_ids: Array = words.map(func(word: Dictionary) -> String: return word.id)
	var included: Dictionary = {}
	var adventure_ids: Dictionary = {}
	for adventure in adventures:
		check(not adventure.id.is_empty() and not adventure.name.is_empty(), "Every adventure has a stable ID and visible name")
		check(not adventure_ids.has(adventure.id), "Adventure IDs are unique")
		adventure_ids[adventure.id] = true
		check(adventure.words.size() >= 5, "Each adventure can form a complete eight-card board")
		for id in adventure.words:
			check(all_ids.has(id), "Adventure words use existing illustrated vocabulary: " + id)
			check(not included.has(id), "A word belongs to one clear adventure: " + id)
			included[id] = true
	check(included.size() == words.size(), "Every existing word remains available through adventures")


func _test_adventures(model, adventures: Array, words: Array) -> void:
	for adventure in adventures:
		var vocabulary: Array = words.filter(func(word: Dictionary) -> bool: return adventure.words.has(word.id))
		check(model.reset(vocabulary, 17), "An adventure starts with its own vocabulary")
		check(model.adventure_id == adventure.id and model.adventure_name == adventure.name, "The round identifies its available adventure")
		_check_board(model)
		check(model.cards.all(func(card: Dictionary) -> bool: return adventure.words.has(card.word.id)), "All pairs and distractors belong to the named adventure")
	model.reset(words, 23)
	var matching_adventures: Array = adventures.filter(func(adventure: Dictionary) -> bool: return adventure.id == model.adventure_id)
	check(matching_adventures.size() == 1, "A full-vocabulary round names a known adventure")
	if matching_adventures.size() == 1:
		check(model.cards.all(func(card: Dictionary) -> bool: return matching_adventures[0].words.has(card.word.id)), "A randomly chosen adventure uses only its related words")
	var deck: Array = model.cards.duplicate(true)
	var adventure_id: String = model.adventure_id
	var theme_id: String = model.theme_id
	model.reset(words)
	model.reset(words, 23)
	check(model.cards == deck and model.adventure_id == adventure_id and model.theme_id == theme_id, "Seeded adventures ignore prior boards and reproduce the same round")
	model.set_theme("winter")
	check(model.adventure_id == adventure_id and model.cards == deck, "Changing the visual season keeps the word adventure")
	check(model.request_hint(), "An adventure permits its one hint")
	check(not model.reset(words.slice(0, 4)), "Too few words cannot restart an adventure")
	check(model.cards == deck and model.adventure_id == adventure_id and model.hint_used, "A rejected reset preserves the current adventure and spent hint")


func _test_replays(model, words: Array) -> void:
	model.reset(words, 9)
	for round_index in range(24):
		var previous_ids: Array = model.cards.map(func(card: Dictionary) -> String: return card.word.id)
		var previous_adventure: String = model.adventure_id
		check(model.reset(words), "Ordinary replay starts another adventure")
		check(not model.adventure_id.is_empty() and model.adventure_id != previous_adventure, "Full-vocabulary replays visit a different adventure")
		check(model.cards.all(func(card: Dictionary) -> bool: return not previous_ids.has(card.word.id)), "Adventure replay never repeats a previous-board word when five fresh words exist")
		_check_board(model)


func _test_small_vocabularies(model, words: Array) -> void:
	var mixed_ids: Array = ["cat", "apple", "sun", "hat", "car", "ball", "bed", "eye", "dog"]
	var mixed: Array = words.filter(func(word: Dictionary) -> bool: return mixed_ids.has(word.id))
	for count in range(5, 10):
		check(model.reset(mixed.slice(0, count)), "A small mixed vocabulary still starts")
		check(model.adventure_id.is_empty() and model.adventure_name == "Word explorers", "Mixed vocabularies without five related words use a clear fallback")
		_check_board(model)
	var animals: Array = words.filter(func(word: Dictionary) -> bool: return ["cat", "dog", "fish", "duck", "cow"].has(word.id))
	model.reset(animals)
	check(model.reset(animals) and model.adventure_id == "animal-friends", "The only eligible adventure can repeat when no alternative exists")
	_check_board(model)


func _test_freshness_before_adventures(model, words: Array) -> void:
	var animal_ids: Array = ["cat", "dog", "fish", "duck", "cow"]
	var fresh_ids: Array = ["apple", "sun", "hat", "car", "ball"]
	var animals: Array = words.filter(func(word: Dictionary) -> bool: return animal_ids.has(word.id))
	var mixed: Array = words.filter(func(word: Dictionary) -> bool: return animal_ids.has(word.id) or fresh_ids.has(word.id))
	model.reset(animals, 11)
	check(model.reset(mixed), "Fresh mixed words can replace a themed board")
	check(model.adventure_id.is_empty(), "Freshness wins when its remaining words cannot form a themed adventure")
	check(model.cards.all(func(card: Dictionary) -> bool: return fresh_ids.has(card.word.id)), "Themed replay cannot reintroduce excluded previous-board words")
	_check_board(model)


func _check_board(model) -> void:
	var counts: Dictionary = {}
	var kinds: Dictionary = {"word": 0, "image": 0}
	for card in model.cards:
		counts[card.word.id] = counts.get(card.word.id, 0) + 1
		kinds[card.kind] += 1
	check(model.cards.size() == 8 and counts.size() == 5 and counts.values().count(2) == 3 and counts.values().count(1) == 2,
		"Adventure boards retain eight cards, three pairs, and two distractors")
	check(kinds.word == 4 and kinds.image == 4, "Adventure boards balance word and picture cards")

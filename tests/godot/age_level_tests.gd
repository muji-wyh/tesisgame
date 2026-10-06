extends SceneTree

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _initialize() -> void:
	var Data = load("res://scripts/game_data.gd")
	var Model = load("res://scripts/game_model.gd")
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	check(words.size() == 1250, "The expanded catalogue contains 1,250 illustrated words")
	check(Data.has_method("age_bands") and Data.has_method("word_level"), "Age levels expose one shared selection contract")
	if failures:
		quit(1)
		return
	check(Data.validate_words(words).is_empty(), "The complete age-graded catalogue validates")
	var bands: Array = Data.age_bands()
	check(bands.map(func(band: Dictionary): return band.id) == ["all", "4-6", "7-9", "10-plus"],
		"Age choices include a backward-compatible all-words option")
	check(bands.map(func(band: Dictionary): return band.max_level) == [3, 1, 2, 3],
		"Age bands use cumulative, bounded vocabulary levels")
	check(Data.age_band("unknown").is_empty() and Data.word_level({}) == 1,
		"Unknown bands are rejected while older word fixtures retain basic-level compatibility")
	var level_counts := {1: 0, 2: 0, 3: 0}
	for word in words:
		check(word.has("level") and word.level in ["basic", "growing", "advanced"],
			"Every authored word has an explicit reviewed level: " + word.id)
		level_counts[Data.word_level(word)] += 1
	check(level_counts == {1: 448, 2: 412, 3: 390}, "Each level adds 300 words while preserving all previous vocabulary")
	var additions: Array = words.slice(350)
	check(additions.size() == 900, "The new expansion preserves the 350-word prefix")
	for level in ["basic", "growing", "advanced"]:
		var added: Array = additions.filter(func(word: Dictionary) -> bool: return word.level == level)
		check(added.size() == 300 and added.any(func(word: Dictionary) -> bool: return word.part_of_speech != "noun"),
			"Every tier adds exactly 300 words and includes language beyond objects")
	for band in bands:
		var eligible: Array = words.filter(func(word: Dictionary) -> bool: return Data.word_level(word) <= band.max_level)
		var expected_sizes: Dictionary = {"all": 1250, "4-6": 448, "7-9": 860, "10-plus": 1250}
		check(eligible.size() == expected_sizes[band.id], "The " + band.id + " pool retains cumulative review words")
	for pair in [["bird", "parrot"], ["nut", "hazelnut"], ["boat", "sailboat"],
		["beach", "sand"], ["foot", "toe"], ["galaxy", "universe"], ["kettle", "teapot"]]:
		check(Data.confusable_words(pair[0], pair[1]) and Data.confusable_words(pair[1], pair[0]),
			"New overlapping picture meanings stay out of the same lesson: " + str(pair))
	for band in bands:
		for topic in Data.adventures(words):
			var highest_level := 0
			for word in words:
				if topic.words.has(word.id) and Data.word_level(word) <= band.max_level:
					highest_level = maxi(highest_level, Data.word_level(word))
			for seed_value in range(20):
				var model = Model.new()
				check(model.reset(words, seed_value, false, topic.id, "", band.id), "Every topic and age can start a complete lesson")
				if model.lesson_words.size() != 5:
					check(false, "Every age produces five words, not a partial board")
					continue
				check(model.cards.size() == 10 and model.hints_remaining == 3, "Age selection preserves Classic Match rules")
				check(model.lesson_words.all(func(word: Dictionary): return Data.word_level(word) <= band.max_level),
					"The lesson stays within the chosen vocabulary level")
				if band.id != "all":
					var levels: Array = model.lesson_words.map(func(word: Dictionary): return Data.word_level(word))
					var ordered := levels.duplicate()
					ordered.sort()
					ordered.reverse()
					check(levels == ordered and levels.front() == highest_level,
						"Higher available levels lead; earlier vocabulary remains review")
				for first in range(5):
					for second in range(first + 1, 5):
						check(not Data.word_pair_conflicts(model.lesson_words[first], model.lesson_words[second]),
							"Age filtering never introduces ambiguous partners")
	var model = Model.new()
	check(model.reset(words, 17, false, "", "", "4-6"), "A basic lesson starts")
	var original_words: Array = model.lesson_words.duplicate(true)
	var original_cards: Array = model.cards.duplicate(true)
	check(not model.reset(words, 18, false, "", "", "unknown") and model.cards == original_cards,
		"An invalid age choice does not destroy the current round")
	check(model.reset(words, 18, true, "", "", "10-plus") and model.lesson_words == original_words
		and model.age_band_id == "4-6", "Mode switches keep the active lesson and its age until the next lesson")
	for band in bands:
		check(model.reset(words, 17, false, "", "", band.id), "A seeded band can choose its own topic")
		var replay = Model.new()
		check(replay.reset(words, 17, false, "", "", band.id) and replay.cards == model.cards
			and replay.adventure_id == model.adventure_id and replay.age_band_id == band.id,
			"The same seed and age reproduce the same topic and cards")
	var review_words: Array = words.slice(0, 200)
	check(model.reset(review_words, 17, false, "music-makers", "", "10-plus")
		and model.lesson_words.all(func(word: Dictionary) -> bool: return Data.word_level(word) == 3),
		"The first advanced music lesson uses its five advanced nouns")
	var practiced: Array = model.lesson_words.map(func(word: Dictionary) -> String: return word.id)
	check(model.reset(review_words, -1, false, "music-makers", "bell", "10-plus")
		and model.age_band_id == "10-plus" and model.lesson_words[0].id == "bell",
		"A fresh gift lesson retains its age and required noun")
	check(model.lesson_words.all(func(word: Dictionary) -> bool: return not practiced.has(word.id) and Data.word_level(word) < 3),
		"Earlier vocabulary provides fresh review when the advanced nouns were just practiced")
	var gifts := {"great-outdoors": "flower", "play-time": "ball", "picnic-time": "apple",
		"music-makers": "bell", "ocean-discovery": "shell", "space-trip": "rocket"}
	for band in bands:
		for topic in gifts:
			check(model.reset(words, 29, false, topic, gifts[topic], band.id)
				and model.lesson_words[0].id == gifts[topic], "Every age retains the existing gift-word entry points")
	for value in ["secret", "", null, 1, true, [], {}]:
		var invalid: Array = words.duplicate(true)
		invalid[0].level = value
		var previous: Array = model.cards.duplicate(true)
		check(not Data.validate_words(invalid).is_empty() and Data.word_level(invalid[0]) == 0,
			"Invalid supplied level metadata is rejected")
		check(not model.reset(invalid, 1) and not model.error.is_empty() and model.cards == previous,
			"Invalid supplied levels cannot silently filter or replace the active lesson")
	var invalid: Array = words.duplicate(true)
	invalid[0].text = "incomprehensible"
	check(not Data.validate_words(invalid).is_empty(), "The expanded word-length limit stays bounded")
	var bounded: Array = words.slice(0, 5).duplicate(true)
	bounded[0].text = "responsibility"
	check(Data.validate_words(bounded).is_empty(), "Fourteen-letter vocabulary can use the shared catalog")
	for metadata in [{"part_of_speech": "unknown"}, {"topic": "missing-topic"}, {"confusable": "happy"}, {"confusable": [false]}]:
		var malformed: Array = words.slice(0, 5).duplicate(true)
		malformed[0].merge(metadata, true)
		check(not Data.validate_words(malformed).is_empty(), "Invalid learning metadata is rejected")
	var first: Dictionary = {"id": "happy", "text": "happy", "art_key": "mulberry/happy.svg", "confusable": ["glad"]}
	var second: Dictionary = {"id": "glad", "text": "glad", "art_key": "mulberry/glad.svg"}
	check(Data.word_pair_conflicts(first, second) and Data.word_pair_conflicts(second, first),
		"Reviewed similar meanings cannot share a board in either order")
	first.erase("confusable")
	second.art_key = first.art_key
	check(Data.word_pair_conflicts(first, second), "Shared artwork cannot create two correct picture answers")
	second.art_key = "mulberry/glad.svg"
	check(not Data.word_pair_conflicts(first, second), "Distinct artwork remains eligible without an authored conflict")
	check(Model.new()._distinct_words([first, {"id": "blue", "text": "blue"}, second]).size() == 3,
		"Unrelated language categories can share a complete lesson")
	var legacy: Array = words.slice(0, 5).duplicate(true)
	for word in legacy:
		word.erase("level")
	check(Data.validate_words(legacy).is_empty() and model.reset(legacy, 1, false, "", "", "4-6"),
		"Callers with original four-field word records still work")
	print("Age levels: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/game_model.gd")
var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _initialize() -> void:
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var curriculum: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://curriculum.json"))
	check(words.size() == curriculum.total_words and words.size() >= 1550, "The expanded curriculum retains at least 1,550 words")
	check(Data.validate_words(words).is_empty(), "The complete age-graded catalogue validates")
	var bands: Array = Data.age_bands()
	check(bands.map(func(band: Dictionary): return band.id) == ["3", "4", "5", "6", "7", "8", "9", "10", "11", "12"],
		"The ten age choices span 3 through 12+")
	check(bands.map(func(band: Dictionary): return band.max_age) == range(3, 13)
		and bands.back().label == "12+", "Age limits are cumulative and the final stage displays 12+")
	check(Data.age_band("unknown").is_empty() and Data.word_age({}) == 3, "Unknown age IDs are rejected and missing runtime ages have a safe baseline")
	var reviewed_ids: Dictionary = {}
	for tier: Dictionary in curriculum.tiers:
		var cohort: Array = words.filter(func(word: Dictionary) -> bool: return int(word.min_age) == int(tier.age))
		check(cohort.size() == tier.count and cohort.map(func(word: Dictionary): return word.id) == tier.word_ids,
			"Age %s matches its reviewed curriculum cohort" % tier.id)
		check(cohort.any(func(word: Dictionary): return word.part_of_speech != "noun"), "Every cohort includes language beyond objects")
		for word: Dictionary in cohort:
			check(not reviewed_ids.has(word.id) and word.practice_modes.size() > 0, "Each word has one cohort and a practice route: " + word.id)
			reviewed_ids[word.id] = true
			if word.image.is_empty():
				check(word.practice_modes == ["phrase"] and not Data.supports_mode(word, "match")
					and not Data.supports_mode(word, "memory") and not Data.supports_mode(word, "pop"),
					"Contextual language cannot become an ambiguous picture target: " + word.id)
	check(reviewed_ids.size() == words.size(), "Every authored word belongs to exactly one reviewed cohort")
	for pair in [["bird", "parrot"], ["nut", "hazelnut"], ["boat", "sailboat"], ["beach", "sand"], ["foot", "toe"], ["galaxy", "universe"], ["kettle", "teapot"]]:
		check(Data.confusable_words(pair[0], pair[1]) and Data.confusable_words(pair[1], pair[0]),
			"Overlapping picture meanings stay out of the same lesson: " + str(pair))
	for band: Dictionary in bands:
		var eligible: Array = words.filter(func(word: Dictionary) -> bool: return int(word.min_age) <= band.max_age and Data.supports_mode(word, "match"))
		for seed_value in range(20):
			var model := Model.new()
			check(model.reset(words, seed_value, false, "", "", band.id), "Every age can start a complete lesson")
			check(model.lesson_words.size() == 5 and model.cards.size() == 10 and model.hints_remaining == 3, "Age selection preserves five pairs and three hints")
			check(model.lesson_words.all(func(word: Dictionary): return eligible.has(word)), "The entire board stays within its unlocked pictured vocabulary")
			for first in range(model.lesson_words.size()):
				for second in range(first + 1, model.lesson_words.size()):
					check(not Data.word_pair_conflicts(model.lesson_words[first], model.lesson_words[second]), "Age filtering never introduces ambiguous partners")
		var seeded := Model.new()
		var replay := Model.new()
		check(seeded.reset(words, 17, false, "", "", band.id) and replay.reset(words, 17, false, "", "", band.id)
			and seeded.cards == replay.cards and seeded.age_band_id == band.id, "The same seed and age reproduce the same cards")
		for topic: Dictionary in Data.adventures(eligible):
			var topic_words: Array = eligible.filter(func(word: Dictionary) -> bool: return topic.words.has(word.id))
			var available: bool = seeded._distinct_words(topic_words, 5).size() == 5
			var previous: Array = seeded.cards.duplicate(true)
			var started: bool = seeded.reset(words, 29, false, topic.id, "", band.id)
			check(started == available, "An optional topic starts only when five distinct eligible pictures exist")
			if started:
				check(seeded.lesson_words.all(func(word: Dictionary): return topic.words.has(word.id) and eligible.has(word)), "A topic request never escapes its curriculum boundary")
			else:
				check(seeded.cards == previous, "An unavailable topic preserves the active board")
	var model := Model.new()
	check(model.reset(words, 17, false, "", "", "3"), "The first learning level starts")
	var original_words: Array = model.lesson_words.duplicate(true)
	var original_cards: Array = model.cards.duplicate(true)
	check(not model.reset(words, 18, false, "", "", "unknown") and model.cards == original_cards, "An invalid age cannot destroy the active round")
	check(model.reset(words, 18, true, "", "", "3") and model.lesson_words == original_words, "Repeating a lesson retains words at the same earned level")
	check(model.reset(words, 18, true, "", "", "4") and model.age_band_id == "4", "A new earned level invalidates the old repeat-lesson age")
	for band: Dictionary in bands:
		var candidate: Dictionary = words.filter(func(word: Dictionary) -> bool: return int(word.min_age) == band.max_age and Data.supports_mode(word, "match"))[0]
		check(model.reset(words, 29, false, "", candidate.id, band.id) and model.lesson_words[0].id == candidate.id, "A required pictured word is reachable in its own level")
	var contextual: Dictionary = words.filter(func(word: Dictionary) -> bool: return word.image.is_empty())[0]
	original_cards = model.cards.duplicate(true)
	check(not model.reset(words, 20, false, "", contextual.id, "12") and model.cards == original_cards, "Context-only words cannot be forced into a picture board")
	var priorities: Array = words.duplicate(true)
	for word: Dictionary in priorities:
		word._growth_priority = 2 if int(word.min_age) == 4 else 0
	check(model.reset(priorities, 33, false, "", "", "4") and model.lesson_words.all(func(word: Dictionary): return int(word.min_age) == 4), "Unmastered current-level words lead cumulative review")
	for value in ["3", "", null, 2, 13, 3.5, true, [], {}]:
		var invalid: Array = words.slice(0, 5).duplicate(true)
		invalid[0].min_age = value
		check(not Data.validate_words(invalid).is_empty(), "Malformed or out-of-range curriculum ages are rejected")
	var missing_age: Array = words.slice(0, 5).duplicate(true)
	missing_age[0].erase("min_age")
	original_cards = model.cards.duplicate(true)
	check(not Data.validate_words(missing_age).is_empty() and not model.reset(missing_age, 1)
		and model.cards == original_cards, "Missing curriculum metadata cannot replace a playable round")
	var bounded: Array = words.slice(0, 5).duplicate(true)
	bounded[0].text = "abcdefghijklmnopqrstuvwx"
	check(Data.validate_words(bounded).is_empty(), "The curriculum supports the documented 24-letter word bound")
	bounded[0].text += "y"
	check(not Data.validate_words(bounded).is_empty(), "Vocabulary length remains bounded")
	for metadata in [{"part_of_speech": "unknown"}, {"topic": "missing-topic"}, {"confusable": "happy"}, {"confusable": [false]}, {"practice_modes": []}, {"practice_modes": ["unknown"]}, {"image": "", "practice_modes": ["match"]}]:
		var malformed: Array = words.slice(0, 5).duplicate(true)
		malformed[0].merge(metadata, true)
		check(not Data.validate_words(malformed).is_empty(), "Invalid learning and contextual-practice metadata is rejected")
	var first: Dictionary = {"id": "happy", "text": "happy", "art_key": "mulberry/happy.svg", "confusable": ["glad"]}
	var second: Dictionary = {"id": "glad", "text": "glad", "art_key": "mulberry/glad.svg"}
	check(Data.word_pair_conflicts(first, second) and Data.word_pair_conflicts(second, first), "Reviewed similar meanings cannot share a board in either order")
	first.erase("confusable")
	second.art_key = first.art_key
	check(Data.word_pair_conflicts(first, second), "Shared artwork cannot create two correct picture answers")
	second.art_key = "mulberry/glad.svg"
	check(not Data.word_pair_conflicts(first, second), "Distinct artwork remains eligible without an authored conflict")
	check(Model.new()._distinct_words([first, {"id": "blue", "text": "blue"}, second]).size() == 3, "Unrelated language categories can share a complete lesson")
	print("Age levels: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

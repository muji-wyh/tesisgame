extends SceneTree

const Model = preload("res://scripts/game_model.gd")
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
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	_test_catalog(words)
	_test_learning_rounds(words)
	_test_requested_topics(words)
	_test_required_words(words)
	_test_rejected_requests(words)
	_test_priority_and_repeat(words)
	_test_round_chest_chance(words)
	print("Word adventures: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_catalog(words: Array) -> void:
	var topics: Array = Data.adventures()
	check(words.size() == 1550 and topics.size() == 19, "The curriculum has 1,550 words and nineteen compatible topic routes")
	var all_ids: Array = words.map(func(word: Dictionary) -> String: return word.id)
	var included: Dictionary = {}
	var topic_ids: Dictionary = {}
	for topic in topics:
		check(not topic.id.is_empty() and not topic.name.is_empty() and not topic_ids.has(topic.id), "Topic routes retain unique IDs and readable names")
		topic_ids[topic.id] = true
		var within_topic: Dictionary = {}
		for id in topic.words:
			check(all_ids.has(id) and not within_topic.has(id), "A topic contains real, nonduplicated curriculum words: " + id)
			within_topic[id] = true
			included[id] = true
	check(included.size() == words.size(), "Every curriculum word remains represented by a topic")


func _test_learning_rounds(words: Array) -> void:
	for age in range(3, 13):
		var model = Model.new()
		var twin = Model.new()
		check(model.reset(words, 23, false, "", "", str(age)), "Every earned stage starts a full learning board")
		check(twin.reset(words, 23, false, "", "", str(age)) and twin.cards == model.cards and twin.theme_id == model.theme_id,
			"Equal fresh seeds reproduce the complete board and world")
		check(model.adventure_id.is_empty() and model.adventure_name == "Your learning path", "Ordinary practice draws globally instead of narrowing to a random topic")
		check(model.lesson_words.all(func(word: Dictionary) -> bool: return int(word.min_age) <= age and not str(word.image).is_empty()),
			"Match uses only unlocked pictured vocabulary")
		_check_board(model)
		_check_safe_lesson(model)
		for round_index in range(4):
			var previous: Array = model.lesson_words.map(func(word: Dictionary) -> String: return word.id)
			check(model.reset(words, -1, false, "", "", str(age)), "A fresh learning round remains playable")
			check(model.lesson_words.all(func(word: Dictionary) -> bool: return not previous.has(word.id)),
				"Freshness excludes the previous board when enough equally prioritized words remain")
			_check_board(model)


func _test_requested_topics(words: Array) -> void:
	for topic in Data.adventures():
		for seed_value in range(4):
			var model = Model.new()
			check(model.reset(words, seed_value, false, topic.id, "", "12"), "An explicit topic remains available: " + topic.id)
			check(model.adventure_id == topic.id and model.lesson_words.all(func(word: Dictionary) -> bool: return topic.words.has(word.id)),
				"Explicit topic selection retains only its own words")
			_check_board(model)
			_check_safe_lesson(model)


func _test_required_words(words: Array) -> void:
	var original: Array = words.duplicate(true)
	for pair in [["great-outdoors", "flower"], ["play-time", "ball"], ["picnic-time", "apple"], ["music-makers", "bell"], ["ocean-discovery", "shell"], ["space-trip", "rocket"]]:
		var model = Model.new()
		for seed_value in range(4):
			check(model.reset(words, seed_value, false, pair[0], pair[1], "12"), "A required pictured word can start a compatible topic")
			check(model.lesson_words[0].id == pair[1], "The required word remains present ahead of freshness ordering")
			_check_board(model)
			_check_safe_lesson(model)
		check(model.reset(words, 7, false, "", pair[1], "12") and model.lesson_words[0].id == pair[1],
			"A requested pictured word is reachable without any topic restriction")
	check(words == original, "Selection never changes the caller's vocabulary")


func _test_rejected_requests(words: Array) -> void:
	var model = Model.new()
	check(model.reset(words, 11), "A real Lv3 round is available before invalid requests")
	model.set_theme("winter")
	model.request_hint()
	model.select(model.hint_ids[0])
	var before: Dictionary = _round_snapshot(model)
	var changes: Array[int] = [0]
	model.changed.connect(func() -> void: changes[0] += 1)
	for args in [["missing-topic", "", "3"], ["", "unknown", "3"], ["", "flower", "3"], ["", "", "unknown"], ["garden-trail", "flower", "12"]]:
		check(not model.reset(words, -1, false, args[0], args[1], args[2]), "Unknown, locked or unrelated requests cannot start a board")
		check(_round_snapshot(model) == before and changes[0] == 0 and not model.error.is_empty(), "A rejected request preserves the active attempt and emits no round change")
	var insufficient: Array = words.filter(func(word: Dictionary) -> bool: return word.id in ["cat", "dog", "fish", "duck", "apple"])
	check(not model.reset(insufficient, -1, false, "animal-friends", "", "12"), "An undersized topic cannot consume the current round")
	var unsafe: Array = words.filter(func(word: Dictionary) -> bool: return word.id in ["earth", "planet", "comet", "meteor", "galaxy"])
	check(not model.reset(unsafe, -1, false, "space-trip", "", "12"), "Confusable alternatives cannot form an apparently full five-word board")
	check(_round_snapshot(model) == before and changes[0] == 0, "Unsafe and undersized pools keep every prior round field")


func _test_priority_and_repeat(words: Array) -> void:
	var prioritized: Array = words.duplicate(true)
	for word in prioritized:
		word._growth_priority = 2 if int(word.min_age) == 4 else 0
	var model = Model.new()
	check(model.reset(prioritized, 17, false, "", "", "4"), "The current cohort supplies a practice board")
	check(model.lesson_words.all(func(word: Dictionary) -> bool: return int(word.min_age) == 4), "Unmastered current-level vocabulary leads mastered earlier review")
	model.set_theme("ocean")
	var lesson: Array = model.lesson_words.duplicate(true)
	check(model.reset(prioritized, -1, true, "space-trip", "rocket", "4"), "A mode switch reuses its existing unlocked lesson")
	check(model.lesson_words == lesson and model.theme_id == "ocean", "Repeating a lesson preserves its ordered words and chosen world")
	check(model.reset(prioritized, -1, false, "", "", "4"), "Priority remains active on subsequent practice rounds")
	check(model.lesson_words.all(func(word: Dictionary) -> bool: return int(word.min_age) == 4), "Freshness cannot replace the current cohort with already mastered words")


func _round_snapshot(model) -> Dictionary:
	var snapshot: Dictionary = {}
	for property in ["cards", "lesson_words", "matched_ids", "feedback_ids", "hint_ids", "hints_remaining",
		"selected_id", "mistakes", "phase", "theme_id", "adventure_id", "adventure_name",
		"chest_state", "chest_earned", "reward_theme", "reward_id", "last_correct"]:
		snapshot[property] = model.get(property)
	return snapshot.duplicate(true)


func _test_round_chest_chance(words: Array) -> void:
	var lesson: Array = words.filter(func(word: Dictionary) -> bool: return word.id in ["cat", "dog", "fish", "duck", "apple"])
	var earned: int = 0
	var model = Model.new()
	var twin = Model.new()
	for seed_value in range(128):
		check(model.reset(lesson, seed_value, false, "", "", "3", true)
			and twin.reset(lesson, seed_value, false, "", "", "3", true), "A chance-reward round starts with a stable seed")
		var outcome: bool = model.chest_earned
		earned += 1 if outcome else 0
		check(twin.chest_earned == outcome, "The same round seed reproduces its chest outcome")
		check(not model.begin_open(), "A possible reward cannot be opened before a completed round")
		model.request_hint()
		model.set_theme("ocean")
		for word in model.lesson_words:
			model.match_spoken_word(str(word.id))
			model.resolve_feedback()
		check(model.phase == "won" and model.chest_earned == outcome,
			"Completing every pair preserves the single predetermined reward outcome")
		model.resolve_feedback()
		model.match_spoken_word(str(model.lesson_words[0].id))
		check(model.chest_earned == outcome and model.begin_open() == outcome,
			"Duplicate completion does not reroll or open an unearned chest")
		if outcome:
			check(not model.begin_open() and model.finish_open() and not model.finish_open() and not model.begin_open(),
				"The one earned chest can be claimed exactly once")
		else:
			check(model.chest_state == "closed" and model.reward_id.is_empty() and not model.finish_open(),
				"A no-chest round never creates an opening or reward ID")
		var before: Dictionary = _round_snapshot(model)
		check(not model.reset(lesson, seed_value + 1, false, "", "", "missing-level", true)
			and _round_snapshot(model) == before, "Rejected resets preserve reward ownership")
	check(earned >= 40 and earned <= 88,
		"The deterministic round sample includes both outcomes at the configured fifty-percent chance")
	check(model.reset(lesson, 19) and model.chest_earned,
		"Hosts that do not request a chance reward keep their guaranteed reward behavior")
	check(model.reset(lesson, 19, true, "", "", "3", true)
		and twin.reset(lesson, 19, true, "", "", "3", true)
		and model.chest_earned == twin.chest_earned,
		"Starting a new replay replaces the reward outcome once without carrying over a prior claim")


func _check_safe_lesson(model) -> void:
	var ids: Array = model.lesson_words.map(func(word: Dictionary) -> String: return word.id)
	check(ids.size() == 5, "Each lesson has exactly five words")
	var safe: bool = true
	for index in range(ids.size()):
		for other in range(index + 1, ids.size()):
			if ids[index] == ids[other]:
				safe = false
	for pair in [["earth", "planet"], ["acorn", "seed"], ["boot", "shoe"], ["shell", "clam"], ["flower", "rose"], ["comet", "meteor"]]:
		if ids.has(pair[0]) and ids.has(pair[1]):
			safe = false
	check(safe, "Lesson words are unique and do not contain confusable alternatives")


func _check_board(model) -> void:
	var counts: Dictionary = {}
	var kinds: Dictionary = {"word": 0, "image": 0}
	for card in model.cards:
		counts[card.word.id] = counts.get(card.word.id, 0) + 1
		kinds[card.kind] += 1
	check(model.cards.size() == 10 and counts.size() == 5 and counts.values().count(2) == 5,
		"Adventure boards contain ten cards with five complete pairs and no distractors")
	check(kinds.word == 5 and kinds.image == 5, "Adventure boards balance word and picture cards")

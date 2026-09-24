extends SceneTree

const Model = preload("res://scripts/voice_pop_model.gd")
const Data = preload("res://scripts/game_data.gd")

var checks: int = 0
var failures: int = 0
var catalog: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	_test_start_and_reset()
	_test_time_and_pause()
	_test_recognition()
	_test_homophones_vocabulary_and_feedback()
	_test_form_snapshots()
	_test_expiry_and_results()
	_test_frame_independence()
	_test_spawn_fairness()
	_test_late_throws()
	_test_complete_catalog()
	print("Voice Pop model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func words(ids: Array) -> Array:
	return catalog.filter(func(word: Dictionary) -> bool: return ids.has(word.id))


func _test_start_and_reset() -> void:
	var game := Model.new()
	check(game.phase == "ready" and not game.start(), "No round starts without illustrated vocabulary")
	check(not game.configure([null, 2, {}, {"id": "cat"}]), "Malformed input cannot create invisible targets")
	var pool: Array = words(["cat", "dog", "apple", "horn"]).duplicate(true)
	var duplicate: Dictionary = pool[0].duplicate(true)
	duplicate.id = "duplicate-cat"
	pool.append(pool[0])
	pool.append(duplicate)
	check(game.configure(pool, 71), "A valid subset configures even with duplicate input entries")
	check(game.remaining == 30.0 and game.elapsed == 0.0 and game.phase == "ready", "Permission preparation consumes no play time")
	game.advance(10.0)
	check(game.remaining == 30.0 and game.targets.is_empty(), "Ready phase never starts moving or counts down")
	check(game.start() and game.targets.size() == 1, "Permission success can immediately launch the first illustrated word")
	var initial: Array = game.targets.duplicate(true)
	check(not game.start() and game.targets == initial, "A duplicate start callback cannot reset a live round")
	var source_id: String = game.targets[0].word.id
	for entry in pool:
		if entry.id == source_id:
			entry.text = "corrupted"
	check(game.targets[0].word.text == initial[0].word.text, "The round owns its vocabulary snapshot")
	game.hit_transcript(game.targets[0].word.text)
	check(game.hits == 1 and game.score == 10, "A first recognition gives a concrete hit and score")
	check(game.configure(words(["cat", "dog", "apple", "horn"]), 71), "Reconfiguration accepts a new lesson")
	check(game.hits == 0 and game.misses == 0 and game.score == 0 and game.hit_words.is_empty(), "Reconfiguration clears the prior round's results")
	game.start()
	check(game.targets[0].word.id == source_id and game.targets == initial, "A seed reproduces the same first word and throw")


func _test_time_and_pause() -> void:
	var game := Model.new()
	game.configure(words(["cat", "dog", "apple", "horn", "sun"]), 17)
	game.start()
	game.advance(1.0)
	game.pause()
	var before: Array = game.targets.duplicate(true)
	var paused_remaining: float = game.remaining
	game.advance(100.0)
	check(game.phase == "paused" and game.remaining == paused_remaining and game.targets == before, "Paused microphone time freezes the timer and every throw")
	check(game.hit_transcript(game.targets[0].word.text).is_empty() and game.hits == 0, "Delayed speech cannot hit while the microphone is paused")
	check(not game.start(), "A start callback cannot bypass pause")
	game.resume()
	game.advance(-1.0)
	game.advance(NAN)
	game.advance(INF)
	check(game.remaining == paused_remaining, "Invalid frame deltas cannot corrupt the clock")
	game.advance(28.999)
	check(game.phase == "running" and game.remaining > 0.0, "The round remains playable up to the 30-second deadline")
	game.advance(0.001)
	check(game.phase == "finished" and game.elapsed == 30.0 and game.remaining == 0.0, "The round finishes at exactly 30 active seconds")
	check(game.targets.is_empty(), "The settlement never retains moving targets")
	var result: Dictionary = game.summary()
	game.advance(40.0)
	game.resume()
	check(game.hit_transcript("cat dog apple horn sun").is_empty() and game.summary() == result, "Finished rounds reject late transcripts, time, and resume callbacks")
	check(game.start() and game.elapsed == 0.0 and game.hits == 0, "Play again starts a full fresh round")
	game.advance(1.2)
	game.stop()
	check(game.phase == "finished" and game.targets.is_empty() and game.misses == 0, "Leaving stops the round without inventing missed words")


func _test_recognition() -> void:
	for fixture in [
		["horn", "a thorn and hornet", "The HORNS!"],
		["cat", "scatter cat2 _cat cat's caté", "I can see a CAT."],
		["apple", "pineapple", "Apples, apples!"],
		["bus", "business bu buss", "Buses!"],
		["berry", "berrie berrys", "berries"],
		["mouse", "mouses", "mice"],
		["foot", "foots", "feet"],
		["tooth", "tooths", "teeth"],
		["leaf", "leafs", "leaves"],
		["tomato", "tomatos", "tomatoes"],
		["fish", "fisher fishing", "fish"],
		["pants", "pant pantses", "pants"],
		["sunglasses", "sunglass sunglasseses", "sunglasses"],
		["monkey", "monkies", "monkeys"],
		["piano", "pianoes", "pianos"]
	]:
		var game := Model.new()
		game.configure(words([fixture[0]]), 3)
		game.start()
		check(game.hit_transcript(fixture[1]).is_empty(), "Unrelated or malformed words do not hit " + fixture[0])
		var removed: Array = game.hit_transcript(fixture[2])
		check(removed.size() == 1 and game.hits == 1 and game.targets.is_empty(), "A whole word or valid plural hits " + fixture[0])
		if removed.size() == 1:
			check(removed[0].has_all(["uid", "word", "forms", "age", "lifetime", "x_start", "x_end", "peak", "spin", "points", "combo"]), "Hit evidence preserves the throw for an impact effect")
		check(game.hit_transcript(fixture[2]).is_empty() and game.hits == 1, "Repeated speech cannot destroy a removed " + fixture[0] + " twice")
	var game := Model.new()
	game.configure(words(["cat", "dog", "horn", "apple"]), 9)
	game.start()
	game.advance(2.2)
	var spoken: String = ""
	for target in game.targets:
		spoken += target.word.text + " "
	check(game.targets.size() == 2 and game.hit_transcript(spoken).size() == 2, "One utterance can hit two different visible objects")
	check(game.hits == 2 and game.combo == 2 and game.best_combo == 2 and game.score == 22, "Consecutive visible hits build the same-round combo")
	game.advance(0.64)
	check(game.targets.is_empty(), "A new target is not retroactively hit by the previous utterance")
	game.advance(0.02)
	check(game.targets.size() == 1, "Clearing the screen launches the next throw promptly")


func _test_form_snapshots() -> void:
	for fixture in [["cat", ["cat", "cats"]], ["leaf", ["leaf", "leaves"]], ["bus", ["bus", "buses"]], ["pants", ["pants"]]]:
		var game := Model.new()
		game.configure(words([fixture[0]]), 1)
		game.start()
		check(game.targets[0].forms == fixture[1], "The browser receives authoritative equivalent word forms for " + fixture[0])
		game.targets[0].forms.append("thorn")
		check(game.hit_transcript("thorn").is_empty(), "Modifying a transport snapshot cannot broaden valid speech matches")
		check(game.hit_transcript(fixture[0]).size() == 1, "Original word matching survives changes to exported forms")


func _test_homophones_vocabulary_and_feedback() -> void:
	for pair in [["sun", "son", "sons"], ["flower", "flour", "flours"], ["pear", "pair", "pairs"], ["plane", "plain", "plains"]]:
		for alternative in pair.slice(1):
			var game := Model.new()
			game.configure(words([pair[0]]), 3)
			game.start()
			check(game.targets[0].forms.has(alternative), "The visible word publishes its vetted homophone " + alternative)
			check(game.hit_transcript("_" + alternative + " " + alternative + "2").is_empty(), "Homophones still require exact token boundaries")
			check(game.hit_transcript(alternative).size() == 1, "A true homophone or its plural hits " + pair[0])
			check(game.hit_transcript(pair[0]).is_empty() and game.hits == 1, "Alternate spellings cannot hit the same target twice")
	var pool: Array = words(["sun", "flower", "pear", "plane", "helicopter", "octopus", "bee", "eye", "nose"])
	var vocabulary_game := Model.new()
	vocabulary_game.configure(pool, 3)
	var published: Array[String] = vocabulary_game.vocabulary()
	check(published.size() == pool.size() and published.has("sun") and not published.has("son"),
		"Ready vocabulary contains the whole configured canonical pool, never homophone aliases")
	published.append("invented")
	vocabulary_game.start()
	check(vocabulary_game.vocabulary().size() == pool.size() and vocabulary_game.targets.size() == 1,
		"Canonical vocabulary is an independent snapshot, not the currently visible target list")
	for fixture in [["helicopter", "helencopter"], ["octopus", "octapus"], ["bee", "be"], ["eye", "I"], ["nose", "knows"], ["plane", "plan"]]:
		var strict := Model.new()
		strict.configure(words([fixture[0]]), 3)
		strict.start()
		check(strict.hit_transcript(fixture[1]).is_empty(), "Unvetted spelling and function-word aliases stay rejected for " + fixture[0])
	var collision := Model.new()
	collision.configure([
		{"id": "sun", "text": "sun", "image": "sun.svg", "audio": "sun.wav"},
		{"id": "son", "text": "son", "image": "son.svg", "audio": "son.wav"}
	], 1)
	collision.start()
	for frame in range(60):
		collision.advance(0.5)
		check(collision.targets.size() <= 1, "Overlapping canonical and homophone forms never appear together")
	var feedback := Model.new()
	feedback.configure(words(["sun"]), 3)
	feedback.start()
	feedback.hit_transcript("")
	check(feedback.recognition_feedback == "unclear_speech" and not feedback.recognition_message.is_empty(),
		"An empty final browser transcript gives a clear retry message")
	feedback.hit_transcript("...")
	check(feedback.recognition_feedback == "unclear_speech" and feedback.hits == 0, "Punctuation cannot manufacture a word")
	feedback.hit_transcript("hello")
	check(feedback.recognition_feedback == "no_matching_target", "A clear but unavailable solo word explains which words to use")
	feedback.hit_transcript("son")
	check(feedback.recognition_feedback.is_empty() and feedback.recognition_message.is_empty(), "A successful answer clears prior recognition feedback")
	feedback.configure(pool, 3)
	check(feedback.recognition_feedback.is_empty() and feedback.recognition_revision == 0, "New rounds reset recognition feedback")


func _test_expiry_and_results() -> void:
	var game := Model.new()
	game.configure(words(["cat"]), 1)
	game.start()
	var first_lifetime: float = game.targets[0].lifetime
	game.advance(first_lifetime)
	check(game.misses == 1 and game.targets.is_empty() and game.hit_transcript("cat").is_empty(), "A transcript arriving after an object's full flight cannot hit it")
	game.advance(1.0)
	check(game.targets.size() == 1, "A single-word lesson can throw its word again after expiry")
	game.hit_transcript("cat")
	game.advance(0.7)
	game.hit_transcript("cat")
	check(game.hits == 2 and game.hit_words.size() == 1 and game.hit_words[0].count == 2, "Pip's summary distinguishes total hits from unique learned words")
	game.advance(30.0)
	var result: Dictionary = game.summary()
	check(result.unique_words == 1 and result.hits == 2 and result.best_combo == 2 and result.score == 22, "The completed summary reports actual achievements")
	check(not result.has("accuracy") and not result.has("failed"), "Silence is not represented as fabricated speech accuracy or failure")
	check(result.hit_words[0].text == "cat" and result.missed_words[0].text == "cat", "Pip receives actual illustrated words for celebration and practice")
	var missed_count: int = 0
	for entry in result.missed_words:
		missed_count += entry.count
	check(missed_count == game.misses, "Practice word counts account for all expired opportunities")
	result.hit_words[0].text = "changed outside model"
	check(game.summary().hit_words[0].text == "cat", "Editing a settlement snapshot cannot change the model's results")


func _test_frame_independence() -> void:
	var fast := Model.new()
	var slow := Model.new()
	fast.configure(catalog, 61)
	slow.configure(catalog, 61)
	fast.start()
	slow.start()
	for _frame in range(300):
		fast.advance(0.1)
	slow.advance(30.0)
	fast.advance(0.000001)
	check(fast.summary() == slow.summary(), "Slow frames and ordinary frames produce the same complete round")
	check(fast.phase == "finished" and slow.phase == "finished", "A stalled frame cannot extend the deadline")
	var stepped := Model.new()
	var jumped := Model.new()
	stepped.configure(catalog, 29)
	jumped.configure(catalog, 29)
	stepped.start()
	jumped.start()
	for _frame in range(71):
		stepped.advance(0.1)
	jumped.advance(7.1)
	check(stepped.hits == jumped.hits and stepped.misses == jumped.misses and stepped.targets.size() == jumped.targets.size(), "Dropped frames preserve the current throw population")
	for index in range(mini(stepped.targets.size(), jumped.targets.size())):
		check(stepped.targets[index].uid == jumped.targets[index].uid and stepped.targets[index].word == jumped.targets[index].word
			and is_equal_approx(stepped.targets[index].age, jumped.targets[index].age), "Throw identity and age do not depend on render frame rate")


func _test_spawn_fairness() -> void:
	for pool in [catalog, words(["cat"]), words(["apple", "horn"]), words(["comet", "meteor", "asteroid"]), words(["flower", "rose", "sunflower", "apple"])]:
		for seed_value in range(8):
			var game := Model.new()
			game.configure(pool, seed_value)
			game.start()
			var seen: Dictionary = {}
			for frame in range(121):
				for target in game.targets:
					if not seen.has(target.uid):
						seen[target.uid] = true
						check(game.remaining + target.age + 0.00001 >= target.lifetime, "Every thrown word has its full recognition window before settlement")
						check(target.lifetime >= 3.0 and target.lifetime <= 5.6, "Every throw offers at least three seconds to recognize its word")
					check(target.x_start >= 0.2 and target.x_start <= 0.8 and target.x_end >= 0.2 and target.x_end <= 0.8
						and target.peak >= 0.18 and target.peak <= 0.45, "Throws remain inside the readable play lanes")
					for other in game.targets:
						if target.uid == other.uid:
							continue
						check(target.lane != other.lane and not Data.confusable_words(target.word.id, other.word.id), "Concurrent targets have separate lanes and unambiguous pictures")
				check(game.targets.size() <= 3, "The child-friendly screen never exceeds three live targets")
				game.advance(0.25)
			check(game.phase == "finished" and not seen.is_empty(), "Small and confusable vocabularies still finish normally")
	var game := Model.new()
	game.configure(catalog, 40)
	game.start()
	var encountered: Dictionary = {}
	for _frame in range(300):
		for target in game.targets.duplicate():
			check(not encountered.has(target.word.id), "Available unseen words appear before repeating a successful word")
			encountered[target.word.id] = true
			game.hit_transcript(target.word.text)
		game.advance(0.1)
	check(encountered.size() >= 20, "Quick successful speech leads to continued active play")


func _test_late_throws() -> void:
	var game := Model.new()
	game.configure(catalog, 14)
	game.start()
	var late_count: int = 0
	for _frame in range(301):
		for target in game.targets.duplicate():
			var born_at: float = game.elapsed - target.age
			check(born_at <= 27.000001, "No throw begins with less than three seconds left to answer")
			if born_at > 25.0:
				late_count += 1
				check(is_equal_approx(born_at + target.lifetime, 30.0), "A late throw's entire flight ends at the round deadline")
			game.hit_transcript(target.word.text)
		game.advance(0.1)
	check(late_count >= 1, "Successful players still receive active throws after the 25-second mark")
	check(game.phase == "finished" and game.targets.is_empty(), "Shorter closing throws cannot delay the settlement")


func _test_complete_catalog() -> void:
	for word in catalog:
		var game := Model.new()
		check(game.configure([word], 1) and game.start(), "Each of the 200 illustrated lesson words is eligible: " + word.id)
		check(game.hit_transcript(word.text).size() == 1, "Each displayed label is recognized exactly: " + word.text)
	for max_level in [1, 2, 3]:
		var pool: Array = catalog.filter(func(word: Dictionary) -> bool: return Data.word_level(word) <= max_level)
		var game := Model.new()
		game.configure(pool, max_level)
		game.start()
		for _frame in range(120):
			for target in game.targets:
				check(Data.word_level(target.word) <= max_level, "The model never injects vocabulary outside the supplied age pool")
			game.advance(0.25)

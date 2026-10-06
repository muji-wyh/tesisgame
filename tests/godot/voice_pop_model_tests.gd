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
	_test_combo_time_bonuses()
	_test_recognition()
	_test_bound_speech_events()
	_test_homophones_vocabulary_and_feedback()
	_test_compounds()
	_test_form_snapshots()
	_test_expiry_and_results()
	_test_frame_independence()
	_test_spawn_fairness()
	_test_simultaneous_throws()
	_test_late_throws()
	_test_complete_catalog()
	print("Voice Pop model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func words(ids: Array) -> Array:
	return catalog.filter(func(word: Dictionary) -> bool: return ids.has(word.id))


func speech_event(game, target: Dictionary, id: String, text: String = "") -> Dictionary:
	return {"event_id": id, "round_id": game.round_id, "target_uid": target.uid,
		"text": target.word.text if text.is_empty() else text, "stage": "interim", "received_at_ms": 120.0}


func _test_compounds() -> void:
	for fixture in [["seahorse", "sea horse", "sea horses", "horse"], ["sunflower", "sun flower", "sun flowers", "sun"],
		["sunglasses", "sun glasses", "sun glasses", "sun"], ["pinecone", "pine cone", "pine cones", "cone"],
		["yoyo", "yo yo", "yo yos", "yo"],
		["grandmother", "grand mother", "grand mothers", "mother"], ["grandfather", "grand father", "grand fathers", "father"],
		["milkshake", "milk shake", "milk shakes", "milk"], ["paperclip", "paper clip", "paper clips", "paper"],
		["whiteboard", "white board", "white boards", "white"], ["blackboard", "black board", "black boards", "black"],
		["raincoat", "rain coat", "rain coats", "rain"], ["wheelbarrow", "wheel barrow", "wheel barrows", "wheel"],
		["lawnmower", "lawn mower", "lawn mowers", "lawn"], ["hairdryer", "hair dryer", "hair dryers", "hair"],
		["beansprout", "bean sprout", "bean sprouts", "bean"], ["homepage", "home page", "home pages", "home"],
		["tablecloth", "table cloth", "table cloths", "table"], ["headband", "head band", "head bands", "head"],
		["playdough", "play dough", "play dough", "play"]]:
		for spelling in [fixture[1], str(fixture[1]).replace(" ", "-"), fixture[2], str(fixture[2]).replace(" ", "-")]:
			var game := Model.new()
			game.configure(words([fixture[0]]), 7)
			game.start()
			check(game.hit_transcript(spelling).size() == 1 and game.hit_words[0].id == fixture[0],
				"Pop accepts a complete reviewed compound spelling: " + spelling)
			game.configure(words([fixture[0]]), 7)
			game.start()
			check(game.hit_speech_event(speech_event(game, game.targets[0], "compound", spelling)).size() == 1,
				"Bound events use the same compound normalization: " + spelling)
		var game := Model.new()
		game.configure(words([fixture[0]]), 7)
		game.start()
		check(not game._can_spawn({"id": fixture[3], "text": fixture[3]}),
			"A live compound prevents its component from spawning: " + fixture[0])
		var component: Dictionary = {"id": fixture[3], "text": fixture[3], "image": "component.svg", "audio": "component.wav"}
		game.configure([component] + words([fixture[0]]), 7)
		for seed_value in range(10):
			game.configure([component] + words([fixture[0]]), seed_value)
			game.start()
			game.advance(4.0)
			check(game.targets.size() == 1, "Compounds and components cannot coexist after either spawn order")
	var game := Model.new()
	game.configure(words(["sun", "flower"]), 7)
	game.start()
	game.advance(2.2)
	check(game.targets.size() == 2 and game.hit_transcript("sun flower").size() == 2,
		"Separate sun and flower targets remain valid without sunflower")
	game.configure(words(["sun"]), 7)
	game.start()
	check(game.hit_transcript("sunflower").is_empty(), "An off-screen joined compound does not score its component")


func _test_bound_speech_events() -> void:
	var game := Model.new()
	game.configure(words(["cat"]), 7)
	var ready_round: String = game.round_id
	check(not ready_round.is_empty(), "A prepared round publishes a speech identity before listening")
	game.start()
	check(game.round_id == ready_round, "Starting the microphone retains the prepared speech round identity")
	var original: Dictionary = game.targets[0].duplicate(true)
	var candidate: Dictionary = speech_event(game, original, "occurrence-1", "ca")
	check(game.hit_speech_event(candidate).is_empty(), "A partial candidate cannot hit its bound target")
	for changes in [
		{"round_id": "older-round"}, {"target_uid": original.uid + 100}, {"text": "dog"},
		{"text": "cat dog"}, {"stage": "unknown"}, {"received_at_ms": -1.0},
		{"received_at_ms": INF}, {"target_uid": 1.5}, {"target_uid": "1"}, {"event_id": ""}
	]:
		var invalid: Dictionary = speech_event(game, original, "invalid")
		invalid.merge(changes, true)
		check(game.hit_speech_event(invalid).is_empty() and game.hits == 0,
			"Invalid speech metadata cannot score: " + str(changes))
	check(game.hit_speech_event({"text": "cat"}).is_empty(), "An unbound legacy string cannot enter the browser event path")
	candidate.text = "CAT!"
	var struck: Array = game.hit_speech_event(candidate)
	check(struck.size() == 1 and struck[0].uid == original.uid and game.hits == 1,
		"A completed candidate consumes its occurrence only after the bound target is hit")
	game.advance(0.66)
	check(game.targets.size() == 1 and game.targets[0].uid != original.uid, "A repeated noun gets a different target identity")
	var replacement: Dictionary = game.targets[0].duplicate(true)
	var revised: Dictionary = speech_event(game, replacement, candidate.event_id)
	revised.stage = "final"
	check(game.hit_speech_event(revised).is_empty() and game.hits == 1,
		"A consumed occurrence cannot replay against the next copy of the word")
	var stale: Dictionary = speech_event(game, original, "stale-target")
	check(game.hit_speech_event(stale).is_empty() and game.hits == 1,
		"An unconsumed result bound to the removed target cannot hit its replacement")
	var repeated: Dictionary = speech_event(game, replacement, "occurrence-2", "cats")
	struck = game.hit_speech_event(repeated)
	check(struck.size() == 1 and game.hits == 2 and game.bonus_time == 3.0,
		"A separate repeated occurrence may hit the replacement and earns the normal combo bonus")
	check(game.hit_speech_event(repeated).is_empty() and game.bonus_time == 3.0,
		"Repeating the accepted event never duplicates points or bonus time")

	game.configure(words(["cat"]), 7)
	check(game.round_id != ready_round, "Reconfiguration invalidates every old speech event even when target IDs restart")
	game.start()
	check(game.hit_speech_event(candidate).is_empty(), "A prior round event cannot match the new round's same numbered target")
	var paused_round: String = game.round_id
	candidate = speech_event(game, game.targets[0], "after-pause")
	game.pause()
	check(game.hit_speech_event(candidate).is_empty(), "Paused speech events cannot consume a target")
	game.resume()
	check(game.round_id == paused_round and game.hit_speech_event(candidate).size() == 1,
		"Pause and resume keep the round identity and do not consume a rejected event")
	game.stop()
	check(game.hit_speech_event(candidate).is_empty(), "Stopped rounds reject bound speech events")
	game.start()
	check(game.round_id != paused_round, "Starting another finished round creates a new speech identity")

	game.configure(words(["cat"]), 7)
	game.start()
	candidate = speech_event(game, game.targets[0], "late-result")
	game.advance(game.targets[0].lifetime)
	check(game.hit_speech_event(candidate).is_empty() and game.hits == 0 and game.misses == 1,
		"A result arriving at the flight boundary cannot score even with an earlier receipt field")
	game.advance(Model.DURATION)
	check(game.hit_speech_event(candidate).is_empty() and game.phase == "finished",
		"A delayed event cannot change a finished round")

	game.configure(words(["bear"]), 7)
	game.start()
	candidate = speech_event(game, game.targets[0], "homophone", "BARE")
	candidate.stage = "final"
	struck = game.hit_speech_event(candidate)
	check(struck.size() == 1 and struck[0].word.id == "bear" and game.hit_words[0].id == "bear",
		"Bound recognition accepts a vetted homophone and retains its canonical result")

	game.configure(words(["cat", "dog"]), 7)
	game.start()
	check(game._spawn_target(5.6), "The bound revision fixture has two separate visible words")
	var first: Dictionary = game.targets[0].duplicate(true)
	var second: Dictionary = game.targets[1].duplicate(true)
	candidate = speech_event(game, first, "revision")
	check(game.hit_speech_event(candidate).size() == 1, "The first stable spelling hits its bound target")
	candidate = speech_event(game, second, "revision")
	check(game.hit_speech_event(candidate).is_empty() and game.targets[0].uid == second.uid,
		"One occurrence revised into another word cannot hit a second target")
	candidate.event_id = "next-occurrence"
	check(game.hit_speech_event(candidate).size() == 1, "A distinct occurrence can hit that second target")

	game.configure(words(["cat"]), 7)
	game.start()
	var feedback: Dictionary = {"event_id": "feedback", "round_id": game.round_id, "target_uid": 0,
		"text": "", "stage": "final", "received_at_ms": 140.0}
	check(game.hit_speech_event(feedback).is_empty() and game.recognition_feedback == "unclear_speech",
		"An empty final gives retry feedback without awarding or consuming a target")
	feedback.text = "hello"
	check(game.hit_speech_event(feedback).is_empty() and game.recognition_feedback == "no_matching_target",
		"An unbound final explains an unavailable word without guessing a target")
	feedback.round_id = "old-feedback"
	feedback.text = ""
	check(game.hit_speech_event(feedback).is_empty() and game.recognition_feedback == "no_matching_target",
		"Feedback from an old round cannot overwrite the current recognition message")


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
	check(game.remaining == 50.0 and game.elapsed == 0.0 and game.phase == "ready", "Permission preparation consumes none of the 50 seconds")
	game.advance(10.0)
	check(game.remaining == Model.DURATION and game.targets.is_empty(), "Ready phase never starts moving or counts down")
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
	game.advance(Model.DURATION - 1.001)
	check(game.phase == "running" and game.remaining > 0.0, "The round remains playable up to the 50-second deadline")
	game.advance(0.001)
	check(game.phase == "finished" and game.elapsed == Model.DURATION and game.remaining == 0.0, "The round finishes at exactly 50 active seconds")
	check(game.targets.is_empty(), "The settlement never retains moving targets")
	var result: Dictionary = game.summary()
	game.advance(40.0)
	game.resume()
	check(game.hit_transcript("cat dog apple horn sun").is_empty() and game.summary() == result, "Finished rounds reject late transcripts, time, and resume callbacks")
	check(game.start() and game.elapsed == 0.0 and game.hits == 0, "Play again starts a full fresh round")
	game.advance(1.2)
	game.stop()
	check(game.phase == "finished" and game.targets.is_empty() and game.misses == 0, "Leaving stops the round without inventing missed words")


func _next_hit(game) -> Dictionary:
	for _frame in range(30):
		if not game.targets.is_empty():
			var removed: Array = game.hit_transcript(str(game.targets[0].word.text))
			return removed[0] if removed.size() == 1 else {}
		game.advance(0.1)
	return {}


func _test_combo_time_bonuses() -> void:
	var game := Model.new()
	game.configure(catalog, 17)
	game.start()
	for _frame in range(400):
		if game.targets.size() == 3:
			break
		game.advance(0.1)
	check(game.targets.size() == 3, "A seeded round provides three distinct targets for a shared utterance")
	if game.targets.size() != 3:
		return
	var sentence := PackedStringArray()
	for target in game.targets:
		sentence.append(target.word.text)
	var before: float = game.remaining
	var removed: Array = game.hit_transcript(" ".join(sentence))
	check(removed.size() == 3 and removed.map(func(hit): return hit.time_bonus) == [0, 3, 5],
		"A multiword utterance awards each crossed combo milestone to its own hit")
	check(game.combo == 3 and game.bonus_time == 8.0 and is_equal_approx(game.remaining, before + 8.0),
		"Combo two adds three seconds and combo three adds five more immediately")
	check(game.summary().base_duration == 50.0 and game.summary().bonus_time == 8.0 and game.summary().duration == 58.0,
		"Summary distinguishes base play time, earned time, and the current deadline")
	before = game.remaining
	check(game.hit_transcript(" ".join(sentence)).is_empty() and game.bonus_time == 8.0 and game.remaining == before,
		"Repeating a final hypothesis cannot earn the same time twice")
	for expected_combo in [4, 5]:
		var later: Dictionary = _next_hit(game)
		check(not later.is_empty() and later.time_bonus == 0 and game.combo == expected_combo and game.bonus_time == 8.0,
			"Higher combos preserve the streak without repeating milestone time")
	game.pause()
	before = game.remaining
	game.advance(200.0)
	check(game.remaining == before and game.bonus_time == 8.0 and game.hit_transcript("cat").is_empty(),
		"Pausing freezes earned time and cannot award a late recognition")
	game.resume()
	game.advance(0.7)
	check(not game.targets.is_empty(), "A fresh unanswered word can end the prior hit streak")
	if game.targets.is_empty():
		return
	game.advance(float(game.targets[0].lifetime) - float(game.targets[0].age))
	check(game.combo == 0 and game.bonus_time == 8.0, "A missed word resets the streak without removing time already earned")
	var bonuses: Array = []
	for _hit in range(3):
		var next: Dictionary = _next_hit(game)
		bonuses.append(next.get("time_bonus", -1))
	check(bonuses == [0, 3, 5] and game.combo == 3 and game.bonus_time == 16.0,
		"A new streak can earn its own two milestones once after a miss")
	game.advance(1000.0)
	check(game.phase == "finished" and game.remaining == 0.0 and game.elapsed == 66.0,
		"A large frame finishes at the extended deadline without stretching it further")
	var result: Dictionary = game.summary()
	game.resume()
	game.hit_transcript(" ".join(sentence))
	game.advance(50.0)
	check(game.summary() == result and game.phase == "finished", "Late results cannot resurrect an expired extended round")
	check(game.start() and game.bonus_time == 0.0 and game.remaining == 50.0 and game.combo == 0,
		"Replay resets both accumulated time and milestone eligibility")
	_next_hit(game)
	_next_hit(game)
	check(game.bonus_time == 3.0, "The new round awards its own first time milestone")
	game.configure(catalog, 17)
	check(game.bonus_time == 0.0 and game.remaining == 50.0 and game.phase == "ready",
		"Reconfiguration discards the previous round's extended deadline")
	game.start()
	game.advance(44.0)
	for _hit in range(3):
		_next_hit(game)
	check(game.bonus_time == 8.0 and game.elapsed < 50.0, "A late successful streak extends the deadline before it expires")
	game.advance(50.1 - game.elapsed)
	check(game.phase == "running" and is_equal_approx(game.remaining, 7.9),
		"Earned time keeps the round running past its original fifty-second deadline")
	game.advance(7.9)
	check(game.phase == "finished" and game.elapsed == 58.0, "The late extension still ends at its exact revised deadline")


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
		["piano", "pianoes", "pianos"],
		["yoyo", "yoyodel yo yoing", "A yo-yo!"],
		["mango", "mangoeses", "mangoes"],
		["potato", "potatos", "potatoes"],
		["domino", "dominoeses", "dominoes"],
		["volcano", "volcanoeses", "volcanoes"],
		["deer", "deers", "deer"],
		["shorts", "shortses", "shorts"],
		["dice", "dices", "dice"],
		["asparagus", "asparaguses", "asparagus"],
		["binoculars", "binocularses", "binoculars"]
	]:
		var game := Model.new()
		game.configure(words([fixture[0]]), 3)
		game.start()
		check(game.hit_transcript(fixture[1]).is_empty(), "Unrelated or malformed words do not hit " + fixture[0])
		var removed: Array = game.hit_transcript(fixture[2])
		check(removed.size() == 1 and game.hits == 1 and game.targets.is_empty(), "A whole word or valid plural hits " + fixture[0])
		if removed.size() == 1:
			check(removed[0].has_all(["uid", "word", "forms", "age", "lifetime", "x_start", "x_end", "peak", "spin", "points", "combo", "time_bonus"]), "Hit evidence preserves the throw and time award for impact feedback")
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
	for pair in [
		["sun", "son", "sons"], ["flower", "flour", "flours"], ["pear", "pair", "pare", "pairs", "pares"],
		["plane", "plain", "plains"], ["bee", "be", "b"], ["eye", "i", "aye", "ayes"],
		["nose", "knows"], ["bear", "bare", "bares"], ["deer", "dear"], ["bread", "bred"],
		["rain", "rein", "reign"], ["ball", "bawl", "bawls"], ["horse", "hoarse"],
		["carrot", "carat", "caret", "karat", "carats", "carets", "karats"], ["shoe", "shoo", "shoos"],
		["key", "quay", "quays"], ["bowl", "bole", "boll", "boles", "bolls"], ["whale", "wail", "wale", "wails", "wales"],
		["tie", "thai", "thais"], ["peas", "pees"],
		["seed", "cede", "cedes"], ["rose", "rows", "roes"], ["berry", "bury", "buries"],
		["bell", "belle", "belles"], ["ring", "wring", "wrings"],
		["cymbal", "symbol", "symbols"], ["plum", "plumb", "plumbs"], ["jam", "jamb", "jambs"],
		["beach", "beech", "beeches"], ["toe", "tow", "tows"], ["ant", "aunt", "aunts"],
		["root", "route", "routes"], ["beetle", "beatle", "beatles"], ["ferry", "fairy", "faery", "fairies", "faeries"]
	]:
		for alternative in pair.slice(1):
			var game := Model.new()
			game.configure(words([pair[0]]), 3)
			game.start()
			check(game.targets[0].forms.has(alternative), "The visible word publishes its vetted homophone " + alternative)
			check(game.hit_transcript("_" + alternative + " " + alternative + "2 " + alternative + "'s "
				+ alternative + "’s " + alternative + "é é" + alternative).is_empty(),
				"Homophones preserve whole Unicode tokens, numbers, and possessives: " + alternative)
			var removed: Array = game.hit_transcript(alternative.to_upper() + "! " + alternative + " " + pair[0])
			check(removed.size() == 1 and game.hits == 1 and game.combo == 1 and game.score == 10,
				"Repeated true homophones or plurals give exactly one hit for " + pair[0])
			check(game.hit_words.size() == 1 and game.hit_words[0].id == pair[0] and game.hit_words[0].text == pair[0],
				"Homophone results keep the illustrated vocabulary identity for " + pair[0])
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
	for fixture in [
		["helicopter", "helencopter"], ["octopus", "octapus"], ["plane", "plan"],
		["ice", "eyes"], ["peas", "peace"], ["pen", "pin"], ["ladder", "latter"],
		["bear", "beer"], ["bee", "bes"], ["nose", "knowses"], ["rose", "rowses roeses"],
		["deer", "dears"], ["bread", "breds"], ["rain", "reigns reins"], ["sun", "sonny"], ["knee", "nee"]
	]:
		var strict := Model.new()
		strict.configure(words([fixture[0]]), 3)
		strict.start()
		check(strict.hit_transcript(fixture[1]).is_empty(), "Near sounds and invented alias inflections stay rejected for " + fixture[0])
	for pair in [["sun", "son"], ["pare", "pear"], ["be", "bee"]]:
		var collision := Model.new()
		collision.configure([
			{"id": pair[0], "text": pair[0], "image": pair[0] + ".svg", "audio": pair[0] + ".wav"},
			{"id": pair[1], "text": pair[1], "image": pair[1] + ".svg", "audio": pair[1] + ".wav"}
		], 1)
		collision.start()
		for _frame in range(60):
			collision.advance(0.5)
			check(collision.targets.size() <= 1, "Overlapping canonical and homophone forms never appear together: " + pair[0])
	var custom_word: Dictionary = words(["deer"])[0].duplicate(true)
	custom_word.id = "woodland-deer"
	var canonical := Model.new()
	canonical.configure([custom_word], 3)
	canonical.start()
	var canonical_hits: Array = canonical.hit_transcript("dear")
	check(canonical_hits.size() == 1 and canonical_hits[0].word.id == "woodland-deer"
		and canonical.hit_words.size() == 1 and canonical.hit_words[0].id == "woodland-deer",
		"Homophone matching reads noun text and preserves a different configured word ID")
	var unavailable := Model.new()
	unavailable.configure(words(["cat"]), 3)
	unavailable.start()
	check(unavailable.hit_transcript("son flour bare be I dear").is_empty() and unavailable.hits == 0,
		"Accepted dictionary aliases cannot hit a word absent from the current targets")
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
	check(feedback.recognition_feedback.is_empty() and feedback.recognition_message.is_empty(), "New rounds reset recognition feedback")


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
	check(game.hits == 2 and game.hit_words.size() == 1 and game.hit_words[0].count == 2, "The review lists a repeated word once while preserving its total hits")
	game.advance(Model.DURATION + 8.0)
	var result: Dictionary = game.summary()
	check(result.hit_words.size() == 1 and result.hits == 2 and result.best_combo == 2 and result.score == 22, "The completed summary preserves the real hits and review words")
	check(not result.has("accuracy") and not result.has("failed"), "Silence is not represented as fabricated speech accuracy or failure")
	check(result.hit_words[0].text == "cat" and result.missed_words[0].text == "cat", "The review receives the actual illustrated words for practice")
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
	for _frame in range(ceili(Model.DURATION * 10.0)):
		fast.advance(0.1)
	slow.advance(Model.DURATION)
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
			for frame in range(ceili(Model.DURATION * 4.0) + 1):
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
	for _frame in range(ceili((Model.DURATION + 8.0) * 10.0) + 1):
		for target in game.targets.duplicate():
			check(not encountered.has(target.word.id), "Available unseen words appear before repeating a successful word")
			encountered[target.word.id] = true
			game.hit_transcript(target.word.text)
		game.advance(0.1)
	check(encountered.size() >= 20, "Quick successful speech leads to continued active play")


func _test_simultaneous_throws() -> void:
	var sizes_seen: Dictionary = {}
	var starts_seen: Dictionary = {}
	for fast_answers in [false, true]:
		for seed_value in range(8):
			var game := Model.new()
			game.configure(catalog, seed_value)
			game.start()
			var seen: Dictionary = {}
			var launches: Dictionary = {}
			for _frame in range(ceili((Model.DURATION + 8.0) * 10.0) + 1):
				for target in game.targets:
					if seen.has(target.uid):
						continue
					seen[target.uid] = true
					var born_at: float = game.elapsed - target.age
					var key: String = "%.4f" % born_at
					if not launches.has(key):
						launches[key] = {"time": born_at, "targets": []}
					launches[key].targets.append(target.duplicate(true))
				if fast_answers:
					for target in game.targets.duplicate():
						game.hit_transcript(target.word.text)
				game.advance(0.1)
			var singles: int = 0
			var bursts: int = 0
			var last_burst: float = -INF
			for launch in launches.values():
				if launch.targets.size() == 1:
					singles += 1
					continue
				bursts += 1
				sizes_seen[launch.targets.size()] = true
				starts_seen["%.2f" % launch.time] = true
				check(launch.targets.size() >= 2 and launch.targets.size() <= Model.MAX_TARGETS,
					"A shared throw launches two or three words together within the screen capacity")
				check(launch.time + 0.00001 >= Model.BURST_WARMUP and launch.time - last_burst >= 8.0 - 0.00001,
					"Shared throws follow the warmup and leave a cooldown before the next group")
				last_burst = launch.time
				for target in launch.targets:
					check(bool(target.get("volley", false)), "Every member retains its shared-flight marker after launch")
					check(is_zero_approx(target.age - launch.targets[0].age), "Simultaneous words share the same real launch time")
					for other in launch.targets:
						if target.uid == other.uid:
							continue
						check(target.lane != other.lane and target.word.id != other.word.id
							and not Data.confusable_words(target.word.id, other.word.id)
							and not target.forms.any(func(form): return other.forms.has(form)),
							"Each shared throw uses distinct lanes, pictures, and accepted spoken forms")
			check(game.phase == "finished" and bursts >= 1 and singles > bursts,
				"Shared throws remain occasional and occur with both quick answers and unanswered words")
	check(sizes_seen.has(2) and sizes_seen.has(3), "Seeded rounds exercise both two-word and three-word throws")
	check(starts_seen.size() > 4, "Shared throws vary their launch timing between seeded rounds")


func _test_late_throws() -> void:
	var game := Model.new()
	game.configure(catalog, 14)
	game.start()
	var late_count: int = 0
	for _frame in range(ceili((Model.DURATION + 8.0) * 10.0) + 1):
		for target in game.targets.duplicate():
			var born_at: float = game.elapsed - target.age
			var deadline: float = Model.DURATION + game.bonus_time
			check(born_at <= deadline - Model.MIN_LATE_LIFETIME + 0.000001, "No throw begins with less than three seconds left to answer")
			if born_at > deadline - 5.0:
				late_count += 1
				check(is_equal_approx(born_at + target.lifetime, deadline), "A late throw's entire flight ends at the extended deadline")
			game.hit_transcript(target.word.text)
		game.advance(0.1)
	check(late_count >= 1, "Successful players still receive active throws in the extended round's final five seconds")
	check(game.phase == "finished" and game.targets.is_empty(), "Shorter closing throws cannot delay the settlement")


func _test_complete_catalog() -> void:
	for word in catalog:
		var game := Model.new()
		check(game.configure([word], 1) and game.start(), "Each illustrated lesson word is eligible: " + word.id)
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

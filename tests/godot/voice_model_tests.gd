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
	check(model_script != null and model_script.can_instantiate(), "The model compiles")
	if model_script == null or not model_script.can_instantiate():
		quit(1)
		return
	var probe = model_script.new()
	check(probe.has_method("spoken_matches"), "The model discovers whole-word spoken candidates")
	check(probe.has_method("match_spoken_word"), "The model matches a spoken pair through select")
	if probe.has_method("spoken_matches") and probe.has_method("match_spoken_word"):
		var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
		_test_candidates(model_script, words)
		_test_homophones(model_script, words)
		_test_compounds(model_script, words)
		_test_parts_of_speech(model_script)
		_test_matching(model_script, words)
		_test_locks(model_script, words)
		_test_vocabulary(model_script, words)
	print("Voice model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _board(model_script: GDScript, words: Array):
	var model = model_script.new()
	model.reset(words, 17)
	model.cards.clear()
	for id in ["doll", "cat", "sun", "dog", "boat"]:
		var word: Dictionary = words.filter(func(value: Dictionary) -> bool: return value.id == id)[0]
		model.cards.append({"id": id + ":word", "kind": "word", "word": word})
		model.cards.append({"id": id + ":image", "kind": "image", "word": word})
	return model


func _test_candidates(model_script: GDScript, words: Array) -> void:
	var model = _board(model_script, words)
	var signals: Array[int] = [0]
	model.changed.connect(func() -> void: signals[0] += 1)
	check(model.spoken_matches("I see a doll") == ["doll"], "The requested sentence finds doll")
	check(model.spoken_matches("A DOLL! A cat? The SUN.") == ["doll", "cat", "sun"],
		"Case and punctuation preserve complete English words in spoken order")
	check(model.spoken_matches("doll, doll; DOLL cat cat") == ["doll", "cat"],
		"Repeated words produce distinct candidate IDs")
	check(model.spoken_matches("dollars caterpillar sunshine") == [],
		"Substrings cannot match doll, cat or sun")
	check(model.spoken_matches("dog boat") == ["dog", "boat"], "All five lesson words have real spoken-match targets")
	var incomplete = _board(model_script, words)
	incomplete.cards.assign(incomplete.cards.filter(func(card: Dictionary) -> bool: return card.id not in ["dog:word", "boat:image"]))
	check(incomplete.spoken_matches("dog boat") == []
		and incomplete.match_spoken_word("dog") == "ignored" and incomplete.match_spoken_word("boat") == "ignored",
		"Defensive candidate checks reject incomplete pairs without scoring")
	check(model.spoken_matches("nothing relevant") == [], "Unrelated speech has no candidates")
	check(model.spoken_matches("") == [], "Empty speech has no candidates")
	check((model.matched_ids.size() / 2) == 0 and model.mistakes == 0 and model.phase == "waiting",
		"Candidate discovery never changes scoring or phase")
	check(signals[0] == 0 and model.selected_id.is_empty() and model.matched_ids.is_empty(),
		"Candidate discovery is read-only and emits no gameplay changes")
	model.select("boat:word")
	check(model.spoken_matches("doll") == ["doll"] and model.selected_id == "boat:word",
		"Candidate discovery preserves an existing manual selection")
	model.select("cat:image")
	check(model.phase == "feedback" and model.spoken_matches("doll cat") == ["doll", "cat"],
		"Read-only candidate discovery remains available during wrong feedback")
	model.resolve_feedback()
	model.match_spoken_word("doll")
	check(model.spoken_matches("doll cat sun") == ["cat", "sun"],
		"Correct feedback excludes matched cards but still discovers queued words")


func _test_homophones(model_script: GDScript, words: Array) -> void:
	for fixture in [
		["sun", "son"], ["flower", "flour"], ["pear", "pair", "pare"], ["plane", "plain"],
		["bee", "be", "b"], ["eye", "i", "aye"], ["nose", "knows"], ["bear", "bare"],
		["deer", "dear"], ["bread", "bred"], ["rain", "rein", "reign"], ["ball", "bawl"],
		["horse", "hoarse"], ["carrot", "carat", "caret", "karat"], ["shoe", "shoo"],
		["key", "quay"], ["bowl", "bole", "boll"], ["whale", "wail", "wale"], ["seed", "cede"],
		["tie", "thai"], ["peas", "pees"],
		["rose", "rows", "roes"], ["berry", "bury"], ["bell", "belle"], ["ring", "wring"],
		["cymbal", "symbol"], ["plum", "plumb"], ["jam", "jamb"],
		["beach", "beech"], ["toe", "tow"], ["ant", "aunt"], ["root", "route"],
		["beetle", "beatle"], ["ferry", "fairy", "faery"]
	]:
		var word: Dictionary = words.filter(func(value: Dictionary) -> bool: return value.id == fixture[0])[0].duplicate(true)
		word.id = "spoken-" + word.id
		var model = model_script.new()
		model.cards.assign([
			{"id": word.id + ":word", "kind": "word", "word": word},
			{"id": word.id + ":image", "kind": "image", "word": word}
		])
		for alternative in fixture.slice(1):
			check(model.spoken_matches(alternative.to_upper() + "!") == [word.id],
				"A whole homophone resolves to the illustrated Match ID: " + alternative + " -> " + word.text)
			check(model.spoken_matches("_" + alternative + " " + alternative + "2 " + alternative + "'s "
				+ alternative + "’s " + alternative + "é é" + alternative).is_empty(),
				"Numbers, possessives, and larger Unicode tokens cannot manufacture the alias " + alternative)
			check(model.spoken_matches(alternative + " " + word.text + " " + alternative) == [word.id],
				"Repeated equivalent spellings queue the illustrated pair only once: " + word.text)
		check((model.matched_ids.size() / 2) == 0 and model.matched_ids.is_empty(), "Alias discovery stays read-only for " + word.text)
		var candidates: Array = model.spoken_matches(fixture[1])
		check(candidates.size() == 1 and model.match_spoken_word(candidates[0]) == "correct"
			and (model.matched_ids.size() / 2) == 1 and model.matched_ids == [word.id + ":word", word.id + ":image"],
			"Homophone scoring uses the real pair and canonical ID: " + word.text)
		check(model.spoken_matches(fixture[1]).is_empty(), "Matched pairs cannot be queued again through an alias")
	for fixture in [
		["cat", "cats cat2 _cat cat's cat’s caté écat"], ["sun", "sons sunny"],
		["bear", "bears bares beer"], ["plane", "planes plains plan"], ["deer", "dears"],
		["ice", "eyes"], ["peas", "peace"], ["pen", "pin"], ["ladder", "latter"],
		["helicopter", "helencopter"], ["octopus", "octapus"], ["knee", "nee"]
	]:
		var word: Dictionary = words.filter(func(value: Dictionary) -> bool: return value.id == fixture[0])[0]
		var model = model_script.new()
		model.cards.assign([
			{"id": word.id + ":word", "kind": "word", "word": word},
			{"id": word.id + ":image", "kind": "image", "word": word}
		])
		check(model.spoken_matches(fixture[1]).is_empty(),
			"Homophones do not enable fuzzy matching or new general plurals in Match: " + word.text)
	var collision = model_script.new()
	for noun in ["sun", "son"]:
		var word: Dictionary = {"id": noun, "text": noun, "image": noun + ".svg", "audio": noun + ".wav"}
		collision.cards.append({"id": noun + ":word", "kind": "word", "word": word})
		collision.cards.append({"id": noun + ":image", "kind": "image", "word": word})
	check(collision.spoken_matches("son") == ["son"] and collision.spoken_matches("sun") == ["sun"],
		"Exact available spelling wins over another simultaneously valid homophone")
	check(collision.spoken_matches("sun son") == ["sun", "son"],
		"Separate exact words can each select one of two equivalent pairs")
	check(collision.spoken_matches("son son") == ["son"],
		"Repeating one spelling does not fall through and queue a second homophone")
	collision.match_spoken_word("sun")
	check(collision.spoken_matches("sun") == ["son"],
		"An already matched exact word does not hide its remaining equivalent pair")
	var off_board = _board(model_script, words)
	check(off_board.spoken_matches("be bare flour pair").is_empty(),
		"Dictionary homophones cannot inject words outside the current board")


func _test_compounds(model_script: GDScript, words: Array) -> void:
	var speech: GDScript = load("res://scripts/speech_words.gd")
	for fixture in [["seahorse", "sea horse", "horse"], ["sunflower", "sun flower", "sun"],
		["sunglasses", "sun glasses", "sun"], ["pinecone", "pine cone", "cone"], ["yoyo", "yo yo", "yo"],
		["grandmother", "grand mother", "mother"], ["grandfather", "grand father", "father"],
		["milkshake", "milk shake", "milk"], ["paperclip", "paper clip", "paper"],
		["whiteboard", "white board", "white"], ["blackboard", "black board", "black"],
		["raincoat", "rain coat", "rain"], ["wheelbarrow", "wheel barrow", "wheel"],
		["lawnmower", "lawn mower", "lawn"], ["hairdryer", "hair dryer", "hair"],
		["beansprout", "bean sprout", "bean"], ["homepage", "home page", "home"],
		["tablecloth", "table cloth", "table"], ["headband", "head band", "head"],
		["playdough", "play dough", "play"]]:
		var model = model_script.new()
		for noun in [fixture[0], fixture[2]]:
			var word: Dictionary = {"id": noun, "text": noun}
			model.cards.append({"id": noun + ":word", "kind": "word", "word": word})
			model.cards.append({"id": noun + ":image", "kind": "image", "word": word})
		for spelling in [fixture[1], str(fixture[1]).replace(" ", "-"), str(fixture[1]).to_upper()]:
			check(model.spoken_matches(spelling) == [fixture[0]],
				"An explicit compound span selects its whole word instead of a component: " + spelling)
		check(model.spoken_matches(fixture[0]) == [fixture[0]], "A joined compound keeps the same canonical match")
		check(speech.compounds_conflict(fixture[0], fixture[2]) and speech.compounds_conflict(fixture[2], fixture[0]),
			"Compound/component exclusion is symmetric: " + fixture[0])
		var candidates: Array = [{"id": fixture[0], "text": fixture[0]}, {"id": fixture[2], "text": fixture[2]}]
		check(model._distinct_words(candidates).size() == 1, "Match dealing excludes compound/component pairs")
		candidates.reverse()
		check(model._distinct_words(candidates).size() == 1, "Deal exclusion does not depend on shuffle order")
	for parts in [["sun", "flower"], ["paper", "clip"], ["milk", "shake"]]:
		var model = model_script.new()
		for noun in parts:
			var word: Dictionary = {"id": noun, "text": noun}
			model.cards.append({"id": noun + ":word", "kind": "word", "word": word})
			model.cards.append({"id": noun + ":image", "kind": "image", "word": word})
		check(model.spoken_matches(" ".join(parts)) == parts,
			"Two intended nouns remain separate without a compound target: " + " ".join(parts))
		check(model.spoken_matches("".join(parts)).is_empty(), "A joined off-board compound never splits into component hits")
		check(not speech.compounds_conflict(parts[0], parts[1]), "Component nouns can be dealt together without their compound")
	for fixture in [["seahorse", "sea horse", "sea-horse"], ["paperclip", "paper clip", "paper-clip"],
		["grandmother", "grand mother", "grand-mother"], ["playdough", "play dough", "play-dough"]]:
		for text in [fixture[1] + "2", "_" + fixture[1], fixture[1] + "'s", fixture[1] + "’s",
			"deep-" + fixture[2], str(fixture[1]).replace(" ", ", ")]:
			check(not speech.tokens(text, [fixture[0]]).has(fixture[0]), "Compound aliases preserve token boundaries: " + text)
	check(speech.tokens("pine cones sea horses sun flowers yo yos", ["pinecones", "seahorses", "sunflowers", "yoyos"])
		== ["pinecones", "seahorses", "sunflowers", "yoyos"], "Reviewed plural compound spellings normalize as complete spans")
	check(speech.tokens("grand mothers grand fathers milk shakes paper clips white boards black boards rain coats wheel barrows play dough",
		["grandmothers", "grandfathers", "milkshakes", "paperclips", "whiteboards", "blackboards", "raincoats", "wheelbarrows", "playdough"])
		== ["grandmothers", "grandfathers", "milkshakes", "paperclips", "whiteboards", "blackboards", "raincoats", "wheelbarrows", "playdough"],
		"Expanded compound plurals normalize while playdough remains a mass noun")
	check(speech.tokens("lawn mowers hair dryers bean sprouts home pages table cloths head bands",
		["lawnmowers", "hairdryers", "beansprouts", "homepages", "tablecloths", "headbands"])
		== ["lawnmowers", "hairdryers", "beansprouts", "homepages", "tablecloths", "headbands"],
		"Common household compound plurals normalize as complete spans")
	check(speech.word_forms({"text": "playdough", "part_of_speech": "noun"}, true) == ["playdough"]
		and speech.tokens("play doughs", ["playdough"]) == ["play", "doughs"],
		"Playdough never accepts an invented plural")
	var lexicon: Dictionary = speech.browser_lexicon(words)
	check(lexicon.words.size() == words.size() and lexicon.compounds.seahorse == ["sea", "horse"],
		"The browser receives the complete catalog and shared compound definitions")
	for entry in lexicon.words:
		var authored: Dictionary = words.filter(func(word: Dictionary) -> bool: return word.text == entry.text)[0]
		check(entry.forms == speech.word_forms(authored, true), "Browser accepted forms match native Pop rules: " + entry.text)
	lexicon.compounds.seahorse[0] = "changed"
	check(speech.browser_lexicon(words).compounds.seahorse[0] == "sea", "Browser transport cannot mutate the shared alias source")


func _test_parts_of_speech(model_script: GDScript) -> void:
	var speech: GDScript = load("res://scripts/speech_words.gd")
	var pop_script: GDScript = load("res://scripts/voice_pop_model.gd")
	for fixture in [["happy", "adjective", "happies"], ["close", "verb", "closes"],
		["quickly", "adverb", "quicklies"], ["under", "preposition", "unders"], ["three", "number", "threes"]]:
		var word: Dictionary = {"id": fixture[0], "text": fixture[0], "part_of_speech": fixture[1],
			"image": "assets/images/words/" + fixture[0] + ".svg", "audio": "assets/audio/voice/word-" + fixture[0] + ".wav"}
		check(speech.word_forms(word, true) == [fixture[0]], "Non-nouns retain their authored form: " + fixture[0])
		var browser: Dictionary = speech.browser_lexicon([word])
		check(browser.words[0].forms == [fixture[0]], "Browser recognition does not invent a noun plural: " + fixture[0])
		var pop = pop_script.new()
		check(pop.configure([word], 7) and pop.start(), "Voice Pop supports " + fixture[1] + " vocabulary")
		check(pop.hit_transcript(fixture[2]).is_empty() and pop.targets.size() == 1,
			"An invented ending cannot remove a non-noun target: " + fixture[2])
		check(pop.hit_transcript(fixture[0]).size() == 1, "The exact non-noun word still scores")
		var model = model_script.new()
		model.cards.assign([{"id": word.id + ":word", "kind": "word", "word": word},
			{"id": word.id + ":image", "kind": "image", "word": word}])
		check(model.spoken_matches(fixture[0]) == [word.id] and model.spoken_matches(fixture[2]).is_empty(),
			"Match uses the same exact non-noun vocabulary")
	var noun: Dictionary = {"text": "teacher", "part_of_speech": "noun"}
	check(speech.word_forms(noun, true) == ["teacher", "teachers"]
		and speech.word_forms({"text": "teacher"}, true) == ["teacher", "teachers"],
		"Noun plurals and legacy noun records keep their existing behavior")
	var copied: Array = speech.word_forms(noun, true)
	copied.append("changed")
	check(not speech.word_forms(noun, true).has("changed"), "Callers cannot mutate cached speech forms")
	for fixture in [["goose", "geese"], ["calf", "calves"], ["wolf", "wolves"], ["shelf", "shelves"], ["half", "halves"]]:
		check(speech.word_forms({"text": fixture[0], "part_of_speech": "noun"}, true).has(fixture[1]),
			"New irregular noun forms remain recognizable: " + fixture[0])
	for text in ["furniture", "scissors", "toothpaste", "crutches"]:
		check(speech.word_forms({"text": text, "part_of_speech": "noun"}, true) == [text],
			"Mass and plural-only nouns do not receive invalid extra endings: " + text)
	for fixture in [["one", "won"], ["two", "to"], ["four", "for"], ["blue", "blew"], ["right", "write"], ["see", "sea"]]:
		var first: Dictionary = {"id": fixture[0], "text": fixture[0], "part_of_speech": "adjective"}
		var second: Dictionary = {"id": fixture[1], "text": fixture[1], "part_of_speech": "noun"}
		check(speech.word_forms(first).has(fixture[1]) and speech.words_conflict(first, second),
			"Reviewed homophones work without being dealt as two competing answers: " + fixture[0])


func _test_matching(model_script: GDScript, words: Array) -> void:
	var model = _board(model_script, words)
	check(model.request_hint() and model.hints_remaining == 2,
		"The voice round can consume the first of three hints")
	var hint: Array = model.hint_ids.duplicate()
	check(model.match_spoken_word("fish") == "ignored" and model.match_spoken_word("bear") == "ignored",
		"Words outside the current board cannot score a spoken match")
	check(model.match_spoken_word("not-a-card") == "ignored" and model.hint_ids == hint,
		"Invalid IDs leave the existing hint unchanged")
	model.select("boat:word")
	var changes: Array[String] = []
	var observe_changes := func() -> void: changes.append(model.phase)
	model.changed.connect(observe_changes)
	check(model.match_spoken_word("doll") == "correct", "A spoken word matches its real pair")
	check(changes == ["matching", "feedback"], "Voice matching routes through both select calls")
	model.changed.disconnect(observe_changes)
	check((model.matched_ids.size() / 2) == 1 and model.mistakes == 0,
		"Clearing the unrelated manual selection causes no mistake")
	check(model.selected_id.is_empty() and model.feedback_ids == ["doll:word", "doll:image"],
		"Spoken matches use normal pair feedback and clear manual selection")
	check(model.matched_ids == ["doll:word", "doll:image"] and model.last_correct,
		"Normal select scoring records the actual matched cards")
	check(model.hints_remaining == 2 and model.hint_ids.is_empty() and not model.request_hint(),
		"Voice feedback neither refills nor spends another hint")
	check(model.match_spoken_word("cat") == "ignored" and (model.matched_ids.size() / 2) == 1,
		"Feedback locks spoken scoring")
	model.resolve_feedback()
	check(model.request_hint() and model.hints_remaining == 1,
		"Voice and manual play share the second hint")
	model.select(model.hint_ids[0])
	model.select(model.hint_ids[0])
	check(model.match_spoken_word("doll") == "ignored" and (model.matched_ids.size() / 2) == 1,
		"A repeated spoken word cannot score twice")
	model.select("cat:image")
	check(model.match_spoken_word("cat") == "correct",
		"Selecting one half manually still permits exactly one spoken match")
	model.resolve_feedback()
	check(model.match_spoken_word("sun") == "correct" and model.phase == "feedback",
		"The third spoken match still waits for feedback resolution")
	check((model.matched_ids.size() / 2) == 3 and model.mistakes == 0,
		"Three spoken matches retain six completed cards without mistakes")
	model.resolve_feedback()
	check(model.phase == "waiting" and (model.matched_ids.size() / 2) == 3,
		"The third spoken match leaves the round active")
	check(model.match_spoken_word("dog") == "correct" and (model.matched_ids.size() / 2) == 4, "The fourth lesson word scores through speech")
	model.resolve_feedback()
	check(model.phase == "waiting" and (model.matched_ids.size() / 2) == 4,
		"The fourth spoken match leaves one real pair available")
	check(model.match_spoken_word("boat") == "correct" and model.phase == "feedback" and (model.matched_ids.size() / 2) == 5,
		"The fifth spoken match waits for normal feedback")
	model.resolve_feedback()
	check(model.phase == "won", "Resolving the fifth spoken match wins the round")
	check(model.spoken_matches("doll cat sun boat dog") == [],
		"Late recognition candidates are ignored after winning")
	check(model.match_spoken_word("cat") == "ignored" and (model.matched_ids.size() / 2) == 5,
		"Late spoken scoring cannot change a won round")
	check(model.hints_remaining == 1 and not model.request_hint(),
		"Winning through speech cannot refill or spend the remaining hint")


func _test_locks(model_script: GDScript, words: Array) -> void:
	var model = _board(model_script, words)
	for attempt in range(7):
		model.select("boat:word")
		model.select("dog:image")
		check(model.match_spoken_word("doll") == "ignored",
			"Spoken scoring cannot skip a wrong-feedback lock")
		model.resolve_feedback()
	check(model.phase == "waiting" and model.mistakes == 7,
		"Seven mistakes leave spoken Match available")
	check(model.spoken_matches("I see a doll") == ["doll"],
		"Recognition still finds unmatched words after repeated mistakes")
	check(model.match_spoken_word("doll") == "correct" and model.matched_ids.size() == 2 and model.mistakes == 7,
		"Spoken matching completes its real pair without resetting earlier mistakes")
	model = _board(model_script, words)
	model.select("boat:word")
	model.select("dog:image")
	model.resolve_feedback()
	check(model.match_spoken_word("doll") == "correct" and model.mistakes == 1,
		"A later spoken match preserves prior mistakes and records its pair")


func _test_vocabulary(model_script: GDScript, words: Array) -> void:
	check(words.size() == 1550, "Voice tests cover the game's complete 1,550-word vocabulary")
	for word in words:
		var model = model_script.new()
		model.cards.assign([
			{"id": word.id + ":word", "kind": "word", "word": word},
			{"id": word.id + ":image", "kind": "image", "word": word}
		])
		check(model.spoken_matches("I see a " + word.text.to_upper() + "!") == [word.id],
			"Spoken discovery reads the actual board vocabulary: " + word.id)
		if word.id == "yoyo":
			for spelling in ["yo-yo", "yo yo", "YO-YO"]:
				check(model.spoken_matches(spelling) == [word.id], "Separated yoyo speech still finds the complete word")
			check(model.spoken_matches("yoyodel yo yoing").is_empty(), "Yoyo normalization cannot match inside another word")
	var model = _board(model_script, words)
	for card in model.cards:
		if card.word.id == "doll":
			card.word = card.word.duplicate()
			card.word.id = "toy-doll"
			card.id = "toy-doll:" + card.kind
	check(model.spoken_matches("doll") == ["toy-doll"],
		"Spoken text is read from vocabulary data rather than assumed to equal the ID")
	check(model.match_spoken_word("toy-doll") == "correct",
		"Candidate IDs, not transcript text, select the real pair")

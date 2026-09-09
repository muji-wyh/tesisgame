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
		if id != "dog":
			model.cards.append({"id": id + ":word", "kind": "word", "word": word})
		if id != "boat":
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
	check(model.spoken_matches("dog boat") == [], "Both one-sided distractors are excluded")
	check(model.spoken_matches("nothing relevant") == [], "Unrelated speech has no candidates")
	check(model.spoken_matches("") == [], "Empty speech has no candidates")
	check(model.successes == 0 and model.mistakes == 0 and model.phase == "waiting",
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


func _test_matching(model_script: GDScript, words: Array) -> void:
	var model = _board(model_script, words)
	check(model.request_hint(), "The voice round can consume its one hint")
	var hint: Array = model.hint_ids.duplicate()
	check(model.match_spoken_word("boat") == "ignored" and model.match_spoken_word("dog") == "ignored",
		"Neither distractor can score a spoken match")
	check(model.match_spoken_word("not-a-card") == "ignored" and model.hint_ids == hint,
		"Invalid IDs leave the existing hint unchanged")
	model.select("boat:word")
	var changes: Array[String] = []
	var observe_changes := func() -> void: changes.append(model.phase)
	model.changed.connect(observe_changes)
	check(model.match_spoken_word("doll") == "correct", "A spoken word matches its real pair")
	check(changes == ["matching", "feedback"], "Voice matching routes through both select calls")
	model.changed.disconnect(observe_changes)
	check(model.successes == 1 and model.streak == 1 and model.mistakes == 0,
		"Clearing the unrelated manual selection causes no mistake")
	check(model.selected_id.is_empty() and model.feedback_ids == ["doll:word", "doll:image"],
		"Spoken matches use normal pair feedback and clear manual selection")
	check(model.matched_ids == ["doll:word", "doll:image"] and model.last_correct,
		"Normal select scoring records the actual matched cards")
	check(model.hint_used and model.hint_ids.is_empty() and not model.request_hint(),
		"Voice matching never refills the spent hint")
	check(model.match_spoken_word("cat") == "ignored" and model.successes == 1,
		"Feedback locks spoken scoring")
	model.resolve_feedback()
	check(model.match_spoken_word("doll") == "ignored" and model.successes == 1,
		"A repeated spoken word cannot score twice")
	model.select("cat:image")
	check(model.match_spoken_word("cat") == "correct" and model.streak == 2,
		"Selecting one half manually still permits exactly one spoken match")
	model.resolve_feedback()
	check(model.match_spoken_word("sun") == "correct" and model.phase == "feedback",
		"The third spoken match still waits for feedback resolution")
	check(model.successes == 3 and model.streak == 3 and model.mistakes == 0,
		"Three spoken matches retain the existing success and streak rules")
	model.resolve_feedback()
	check(model.phase == "won", "The existing three-match threshold wins the round")
	check(model.spoken_matches("doll cat sun boat dog") == [],
		"Late recognition candidates are ignored after winning")
	check(model.match_spoken_word("cat") == "ignored" and model.successes == 3,
		"Late spoken scoring cannot change a won round")
	check(model.hint_used and not model.request_hint(), "Winning through speech cannot refill the hint")


func _test_locks(model_script: GDScript, words: Array) -> void:
	var model = _board(model_script, words)
	for attempt in range(3):
		model.select("boat:word")
		model.select("dog:image")
		check(model.match_spoken_word("doll") == "ignored",
			"Spoken scoring cannot skip a wrong-feedback lock")
		model.resolve_feedback()
	check(model.phase == "lost" and model.mistakes == 3, "Three mistakes still end voice rounds")
	check(model.spoken_matches("I see a doll") == [],
		"Late recognition candidates are ignored after losing")
	check(model.match_spoken_word("doll") == "ignored" and model.successes == 0 and model.mistakes == 3,
		"Voice matching cannot revive a lost round or reset mistakes")
	model = _board(model_script, words)
	model.select("boat:word")
	model.select("dog:image")
	model.resolve_feedback()
	check(model.match_spoken_word("doll") == "correct" and model.mistakes == 1 and model.streak == 1,
		"A later spoken match preserves prior mistakes and starts the normal streak")


func _test_vocabulary(model_script: GDScript, words: Array) -> void:
	check(words.size() == 140, "Voice tests cover the game's current 140-word vocabulary")
	for word in words:
		var model = model_script.new()
		model.cards.assign([
			{"id": word.id + ":word", "kind": "word", "word": word},
			{"id": word.id + ":image", "kind": "image", "word": word}
		])
		check(model.spoken_matches("I see a " + word.text.to_upper() + "!") == [word.id],
			"Spoken discovery reads the actual board vocabulary: " + word.id)
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

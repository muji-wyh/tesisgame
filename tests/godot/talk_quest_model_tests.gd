extends SceneTree

const Model = preload("res://scripts/talk_quest_model.gd")
const Data = preload("res://scripts/talk_quest_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const SpeechWords = preload("res://scripts/speech_words.gd")

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
	_test_catalog()
	_test_spawning_and_budget()
	_test_bound_events()
	_test_word_matching()
	_test_pause_stop_and_retry()
	_test_full_campaign()
	_test_replay_rewards()
	_test_checkpoint_privacy_and_resume()
	_test_pending_rewards_and_migration()
	_test_corrupt_progress()
	print("Talk Quest model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func progress_with_counts(counts: Array, version: int = Model.SAVE_VERSION) -> Dictionary:
	return {"version": version, "completion_counts": counts, "run": {}}


func unlocked_game(number: int = 1):
	var game := Model.new()
	var counts: Array = []
	counts.resize(number - 1)
	counts.fill(1)
	game.import_progress(progress_with_counts(counts))
	game.start_level(number, 42)
	return game


func speech_event(game, id: String, text: String = "", stage: String = "final", target_index: int = 0) -> Dictionary:
	var target: Dictionary = game.targets[target_index]
	return {
		"event_id": id, "round_id": game.round_id, "target_uid": target.uid,
		"text": target.word.text if text.is_empty() else text, "stage": stage, "received_at_ms": 123.0
	}


func wait_for_target(game) -> void:
	for _index in range(20):
		if game.phase != "playing" or not game.targets.is_empty():
			return
		game.advance(0.25)


func complete_battle(game) -> void:
	var guard: int = 0
	while game.phase == "playing" and guard < 200:
		guard += 1
		wait_for_target(game)
		if game.targets.is_empty():
			break
		var previous_hp: int = game.hp
		var hit: Dictionary = game.submit_transcript(game.current_prompt().text)
		check(hit.matched and hit.damage == 1 and game.hp == previous_hp - 1,
			"A live word deals exactly one health segment")
	check(game.phase == "victory" and game.hp == 0, "N word hits defeat the monster")


func finish_run(game) -> Dictionary:
	complete_battle(game)
	check(game.finish_victory().accepted, "Victory leads to the chest")
	return game.open_chest()


func miss_words(game, amount: int) -> void:
	while game.phase == "playing" and game.misses < amount:
		wait_for_target(game)
		if game.targets.is_empty():
			return
		var delay: float = INF
		for target: Dictionary in game.targets:
			delay = minf(delay, target.lifetime - target.age)
		game.advance(delay + 0.00001)


func game_showing(number: int, noun: String):
	var game = unlocked_game(number)
	for seed_value in range(100):
		game.start_level(number, seed_value)
		if game.targets[0].word.text == noun:
			return game
	check(false, "The level can launch its reviewed word: " + noun)
	return game


func _test_catalog() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var ids: Dictionary = {}
	for word: Dictionary in catalog:
		ids[word.id] = word
	var scenes: Dictionary = {}
	var monsters: Dictionary = {}
	var previous_hp: int = 0
	check(Data.levels().size() == 14, "All fourteen destinations remain in the campaign")
	for number in range(1, Data.LEVEL_COUNT + 1):
		var item: Dictionary = Data.level(number)
		check(item.hp > previous_hp and item.hp == Data.HEALTH[number - 1],
			"Every later monster has more health than the previous one")
		check(item.extra_words == maxi(3, ceili(float(item.hp) / 4.0)) and item.word_budget == item.hp + item.extra_words,
			"Each level launches at most N plus m words, including its forgiving extra allowance")
		previous_hp = item.hp
		check(not item.cooperative and item.kind == ("boss" if number >= 13 else "ordinary"),
			"Both special levels use the same word combat rules")
		check(not scenes.has(item.scene_id) and not monsters.has(item.monster_id),
			"Each level retains its distinct scene and approved monster")
		scenes[item.scene_id] = true
		monsters[item.monster_id] = true
		check(item.words.size() == Data.LEVEL_WORDS[number - 1].size() and item.words.size() >= 8,
			"Every themed word is available in the reviewed word catalog")
		var seen: Dictionary = {}
		for word: Dictionary in item.words:
			check(ids.has(word.id) and word.text == ids[word.id].text and not seen.has(word.id),
				"Themed vocabulary uses distinct, vetted word descriptors")
			check(ResourceLoader.exists("res://" + word.image), "Every launched noun has a renderable picture")
			seen[word.id] = true
		check(item.chest_id == "chest-%02d" % number, "First clears retain their reviewed chest")
	check(Data.level(0).is_empty() and Data.level(15).is_empty(), "Invalid level numbers have no catalog entry")
	var copied: Dictionary = Data.level(1)
	copied.words[0].text = "changed"
	copied.scene.props.clear()
	check(Data.level(1).words[0].text == "door" and Data.level(1).scene.props.size() == 4,
		"Returned words and art metadata cannot mutate the shared catalog")
	check(Data.chests().size() == 20 and Data.chest("chest-21").is_empty(),
		"The twenty reviewed reward designs remain available")


func _test_spawning_and_budget() -> void:
	var game = unlocked_game()
	check(game.spawned == 1 and game.targets.size() == 1 and game.total_words == 8,
		"Level one begins with a live word and a finite eight-word budget")
	var target: Dictionary = game.targets[0]
	check(target.age == 0.0 and target.lifetime >= 5.8 and target.forms.has(target.word.text),
		"New targets have a fair flight lifetime and explicit speech forms")
	var descriptors: Array[Dictionary] = game.speech_targets()
	check(descriptors[0].uid == target.uid and descriptors[0].remaining_ms == target.lifetime * 1000.0,
		"Speech snapshots identify each live flight and its remaining receipt window")
	descriptors[0].forms.clear()
	check(not game.targets[0].forms.is_empty(), "Speech snapshots cannot mutate model speech forms")
	game.advance(4.5)
	check(game.targets.size() == 3 and game.spawned == 3, "Overlapping launches have no more than three live words")
	for first: Dictionary in game.targets:
		for second: Dictionary in game.targets:
			if first.uid == second.uid:
				continue
			check(first.lane != second.lane and not GameData.confusable_words(first.word.id, second.word.id),
				"Concurrent words use separate lanes without visually confusable nouns")
			check(not first.forms.any(func(form: String) -> bool: return second.forms.has(form)),
				"Concurrent flights never compete for one accepted spoken form")
	var before: float = game.elapsed
	for delta in [0.0, -1.0, INF, NAN]:
		game.advance(delta)
	check(game.elapsed == before, "Invalid frame deltas cannot advance the battle")
	game.advance(10000.0)
	check(game.phase == "lost" and game.spawned == game.total_words and game.misses == game.total_words,
		"Large deltas resolve the entire finite budget and eventually lose")
	check(game.hits == 0 and game.hp == game.max_hp and game.targets.is_empty(),
		"Missed words never damage the monster")
	check(not game.open_chest().accepted and not game.has_saved_run(), "A lost attempt cannot award or retain a pending chest")
	var slow = unlocked_game(14)
	var fast = unlocked_game(14)
	slow.advance(10000.0)
	for _index in range(10000):
		if fast.phase != "playing":
			break
		fast.advance(0.05)
	check(fast.phase == "lost" and fast.misses == slow.misses and fast.spawned == slow.spawned
		and absf(fast.elapsed - slow.elapsed) < 0.001,
		"Slow frames and small frames preserve identical launch and landing outcomes")
	var forgiving = unlocked_game()
	miss_words(forgiving, forgiving.level.extra_words)
	complete_battle(forgiving)
	check(forgiving.spawned == forgiving.total_words and forgiving.misses == forgiving.level.extra_words,
		"Exactly m missed words still leave the N hits needed to win")
	var exhausted = unlocked_game()
	miss_words(exhausted, exhausted.level.extra_words + 1)
	while exhausted.phase == "playing":
		wait_for_target(exhausted)
		if not exhausted.targets.is_empty():
			exhausted.submit_transcript(exhausted.current_prompt().text)
		else:
			exhausted.advance(10.0)
	check(exhausted.phase == "lost" and exhausted.hp == 1 and exhausted.hits == exhausted.max_hp - 1,
		"After m plus one misses, the remaining finite words cannot manufacture victory")


func _test_bound_events() -> void:
	var game = unlocked_game()
	var first: Dictionary = speech_event(game, "first")
	var malformed: Array = [
		{},
		{"event_id": true}, {"event_id": ""}, {"event_id": "x".repeat(161)},
		{"round_id": 3}, {"text": []}, {"text": "x".repeat(513)}, {"stage": "anything"},
		{"target_uid": 0}, {"target_uid": -1}, {"target_uid": 1.5}, {"target_uid": true},
		{"target_uid": INF}, {"received_at_ms": -1}, {"received_at_ms": NAN}
	]
	for edit: Dictionary in malformed:
		var event: Dictionary = first.duplicate()
		if edit.is_empty():
			event = {}
		else:
			event.merge(edit, true)
		check(not game.submit_speech_event(event).matched and game.hp == game.max_hp,
			"Malformed speech cannot damage a monster: " + str(edit))
	check(game.submit_speech_event({"event_id": "unbound"}).reason == "missing_binding",
		"An occurrence without its original target metadata cannot score")
	check(game.submit_speech_event(first).matched and game.hp == game.max_hp - 1,
		"The valid original occurrence deals one damage")
	check(game.submit_speech_event(first).reason == "duplicate_event", "A repeated occurrence is never scored twice")
	wait_for_target(game)
	var rebound: Dictionary = speech_event(game, "first")
	check(game.submit_speech_event(rebound).reason == "duplicate_event",
		"An already scored occurrence cannot be rebound to a later flight")
	var mismatch: Dictionary = speech_event(game, "mismatch", "not a visible noun")
	check(game.submit_speech_event(mismatch).reason == "word_mismatch", "A wrong final word is processed without damage")
	mismatch.text = game.current_prompt().text
	check(game.submit_speech_event(mismatch).reason == "duplicate_event",
		"Final mismatches cannot be revised into another score")
	var interim: Dictionary = speech_event(game, "interim", "wrong", "interim")
	check(not game.submit_speech_event(interim).matched, "Unmatched interim recognition does not score")
	interim.text = game.current_prompt().text
	check(game.submit_speech_event(interim).matched, "A corrected interim occurrence can hit its original live word")
	interim.stage = "final"
	check(game.submit_speech_event(interim).reason == "duplicate_event",
		"The final update of an already matched interim does not deal another hit")
	var late = unlocked_game()
	var expired: Dictionary = speech_event(late, "too-late")
	late.advance(late.targets[0].lifetime)
	check(late.submit_speech_event(expired).reason == "stale_target" and late.hits == 0,
		"An expired word cannot be hit by a delayed callback")
	var second = unlocked_game()
	second.advance(2.2)
	var second_event: Dictionary = speech_event(second, "second-live-word", "", "final", 1)
	check(second.submit_speech_event(second_event).matched and second.targets[0].uid == 1,
		"Recognition can target any live word, not only the first prompt")


func _test_word_matching() -> void:
	for pair in [["bell", "belle"], ["flower", "flowers"], ["key", "quay"], ["cat", "CAT!"]]:
		var game = game_showing(1, pair[0])
		check(game.submit_transcript(pair[1]).matched, "Reviewed case, plural, and homophone forms hit: " + pair[1])
	for spoken in ["catapult", "cat2", "cat's", "cat dog", "the cat", "caté", ""]:
		var game = game_showing(1, "cat")
		check(not game.submit_transcript(spoken).matched, "Word boundaries and extra words cannot turn into a cat hit: " + spoken)
	var compound = game_showing(11, "seahorse")
	check(compound.submit_transcript("sea horse").matched, "Reviewed compound ASR spellings match one visible noun")
	var blocked = game_showing(11, "seahorse")
	check(not blocked.submit_transcript("sea horse crab").matched, "Additional nouns do not slip through compound matching")


func _test_pause_stop_and_retry() -> void:
	var game = unlocked_game()
	game.advance(1.25)
	var delayed: Dictionary = speech_event(game, "before-pause")
	var age: float = game.targets[0].age
	var uid: int = game.targets[0].uid
	var previous_round: String = game.round_id
	check(game.pause().accepted and game.phase == "paused", "Map pauses the current battle")
	game.advance(10000.0)
	check(game.targets[0].age == age and game.spawned == 1 and game.misses == 0,
		"Pause freezes flights, launches, and misses")
	check(game.speech_targets().is_empty() and game.speech_target().target_uid == 0,
		"A paused stage exposes no scoring targets to the microphone")
	check(not game.submit_speech_event(delayed).accepted, "Speech cannot hit while paused")
	check(game.resume().accepted and game.targets[0].uid == uid and game.targets[0].age == age,
		"Resume restores the same flight without a free lifetime extension")
	check(game.round_id != previous_round and game.submit_speech_event(delayed).reason == "stale_round",
		"Pause and resume invalidate delayed recognition from the previous listening session")
	var before_retry: Dictionary = speech_event(game, "before-retry")
	game.advance(10000.0)
	check(game.start_level(1) and game.spawned == 1 and game.hits == 0 and game.misses == 0 and game.hp == game.max_hp,
		"Retry starts a fresh finite attempt with full health")
	check(game.submit_speech_event(before_retry).reason == "stale_round", "Retry rejects callbacks even when target IDs are reused")
	game.stop()
	check(game.phase == "ready" and game.targets.is_empty() and not game.has_saved_run(),
		"Stopping leaves no active word flight or pending reward")
	check(not game.start_level(14) and not game.start_level(0), "Locked and invalid destinations cannot start")


func _test_full_campaign() -> void:
	var game := Model.new()
	for number in range(1, Data.LEVEL_COUNT + 1):
		check(game.start_level(number, number), "The next unlocked monster can be challenged")
		check(game.hp == Data.HEALTH[number - 1] and not game.is_cooperative() and game.has_correct_part(),
			"Every level, including the workshop finale, uses full combat health without part gates")
		check(game.current_part_choices().is_empty() and not game.choose_part("wheel").accepted,
			"Archived workshop choices cannot alter word combat")
		var result: Dictionary = finish_run(game)
		check(result.accepted and result.first_clear and result.reward_id == "chest-%02d" % number,
			"Each campaign clear awards its original reviewed chest exactly once")
		check(game.clear_count(number) == 1 and game.unlocked_level == mini(number + 1, Data.LEVEL_COUNT),
			"A collected chest commits one clear and the next destination")
		check(not game.open_chest().accepted and not game.finish_victory().accepted,
			"Completed rewards cannot be replayed by repeating stage callbacks")
	check(game.completed_levels.size() == 14 and game.companion_unlocked and game.total_clears == 14,
		"The fourteen-monster campaign preserves all destination and companion rewards")


func _test_replay_rewards() -> void:
	var game = unlocked_game(14)
	finish_run(game)
	for number in range(15, 21):
		game.start_level(1)
		var result: Dictionary = finish_run(game)
		check(result.reward_id == "chest-%02d" % number and result.new_chest,
			"The first six replays still award the six bonus chest designs")
	check(game.collected_chests.size() == 20, "Every reviewed chest remains reachable after the gameplay migration")
	game.start_level(1)
	check(finish_run(game).reward_id == "chest-01", "Later replays cycle through the established reward catalog")


func _test_checkpoint_privacy_and_resume() -> void:
	var game = unlocked_game(3)
	game.submit_speech_event(speech_event(game, "private-event-never-save", "private-transcript-never-save", "final"))
	game.submit_transcript(game.current_prompt().text)
	game.advance(2.75)
	var delayed: Dictionary = speech_event(game, "delayed-before-restore")
	game.pause()
	var saved: Dictionary = game.export_progress()
	check(saved.version == 2 and saved.run.hits == 1 and saved.run.phase == "playing",
		"Version two checkpoints preserve finite combat progress")
	var serialized: String = JSON.stringify(saved)
	check(not serialized.contains("private-event-never-save") and not serialized.contains("private-transcript-never-save")
		and not serialized.contains("last_transcript") and not serialized.contains("round_id"),
		"Checkpoints contain no recognition text, occurrence IDs, or speech sessions")
	var restored := Model.new()
	check(restored.import_progress(JSON.parse_string(serialized)) and restored.phase == "paused",
		"A serialized browser checkpoint restores paused")
	check(restored.hits == game.hits and restored.misses == game.misses and restored.spawned == game.spawned
		and restored.hp == game.hp and restored.targets.size() == game.targets.size(),
		"Reload preserves target IDs, remaining flight windows, finite counts, and health")
	for index in range(mini(restored.targets.size(), game.targets.size())):
		var before: Dictionary = game.targets[index]
		var after: Dictionary = restored.targets[index]
		check(before.uid == after.uid and before.word.id == after.word.id and before.lane == after.lane
			and is_equal_approx(before.age, after.age) and is_equal_approx(before.lifetime, after.lifetime)
			and is_equal_approx(before.x_start, after.x_start) and is_equal_approx(before.x_end, after.x_end),
			"JSON roundtrips retain each live target identity, position, and remaining lifetime")
	check(restored.last_transcript.is_empty() and restored.feedback.is_empty(), "Restored recognition is clean")
	restored.resume()
	check(restored.submit_speech_event(delayed).reason == "stale_round", "Saved-session callbacks cannot attack a restored flight")
	check(restored.submit_speech_event(speech_event(restored, "fresh-after-load")).matched,
		"Fresh recognition can attack the restored target")
	complete_battle(restored)
	var with_misses = unlocked_game()
	miss_words(with_misses, 2)
	with_misses.pause()
	var missed_restore := Model.new()
	missed_restore.import_progress(JSON.parse_string(JSON.stringify(with_misses.export_progress())))
	check(missed_restore.misses == 2 and missed_restore.spawned == with_misses.spawned,
		"Reload never refunds expired words or adds extra attempts")
	missed_restore.resume()
	missed_restore.advance(10000.0)
	check(missed_restore.misses == missed_restore.total_words and missed_restore.phase == "lost",
		"The restored finite budget still exhausts exactly once")


func _test_pending_rewards_and_migration() -> void:
	var game = unlocked_game()
	complete_battle(game)
	var restored := Model.new()
	restored.import_progress(game.export_progress())
	check(restored.resume().phase == "victory" and restored.total_clears == 0,
		"Reload during the final animation preserves the pending victory")
	restored.finish_victory()
	restored.pause()
	var pending: Dictionary = restored.export_progress()
	# RefCounted IDs can use the signed half of Godot's 64-bit instance space.
	# Keep this actual browser-produced identity through JSON and chest resume.
	pending.run.run_id = "tq-run--9223371976255469986-18431100-1"
	var chest_restore := Model.new()
	chest_restore.import_progress(JSON.parse_string(JSON.stringify(pending)))
	check(chest_restore.export_progress().run.run_id == pending.run.run_id,
		"A signed Godot instance ID retains the pending reward identity through a JSON checkpoint")
	check(chest_restore.resume().phase == "chest" and chest_restore.current_chest().id == "chest-01",
		"Reload preserves the same pending chest")
	check(chest_restore.open_chest().accepted and chest_restore.total_clears == 1,
		"A restored pending chest commits once")
	var committed: Dictionary = chest_restore.export_progress()
	check(committed.run.is_empty(), "Committed chest progress no longer contains a pending run")
	pending.completion_counts = committed.completion_counts
	chest_restore.import_progress(pending)
	check(not chest_restore.has_saved_run() and chest_restore.total_clears == 1,
		"Combining stale pending state with committed counters cannot award twice")
	var old: Dictionary = progress_with_counts([2, 1], 1)
	old.run = {"level_number": 3, "line_index": 2, "phase": "playing", "clear_number": 1}
	var migrated := Model.new()
	check(migrated.import_progress(old) and migrated.total_clears == 3 and migrated.unlocked_level == 3,
		"Old conversation saves retain completed levels and replay reward counts")
	check(migrated.collected_chests.has("chest-15") and not migrated.has_saved_run(),
		"Migration retains earned bonus chests and safely resets unfinished conversations")
	old.run.line_index = Data.level(3).lines.size()
	old.run.phase = "chest"
	migrated.import_progress(old)
	check(migrated.resume().phase == "chest" and migrated.hp == 0 and migrated.hits == migrated.max_hp,
		"An already earned legacy chest survives migration without requiring another battle")
	check(migrated.open_chest().accepted and migrated.clear_count(3) == 1,
		"The migrated legacy reward has the same guarded one-time commit")


func _test_corrupt_progress() -> void:
	var game := Model.new()
	for root_value in [null, [], {"version": 3, "completion_counts": []}, {"version": 2, "completion_counts": "bad"}]:
		check(not game.import_progress(root_value), "Unsupported or malformed save roots are rejected")
	game.import_progress(progress_with_counts([2, 0, 9, 10]))
	check(game.total_clears == 2 and game.completed_levels == [1] and game.unlocked_level == 2,
		"A gap in completion counters cannot unlock later destinations")
	for value in [-1, 1.5, "3", true, INF, {}]:
		game.import_progress(progress_with_counts([value, 1]))
		check(game.total_clears == 0 and game.unlocked_level == 1, "Invalid clear counters cannot manufacture progress")
	game.import_progress(progress_with_counts([1.0e100, 1]))
	check(game.clear_count(1) == Model.MAX_LEVEL_CLEARS and game.total_clears == Model.MAX_LEVEL_CLEARS + 1,
		"Huge finite counts are clamped before integer conversion")
	var source = unlocked_game()
	var valid: Dictionary = source.export_progress()
	for edits in [
		{"level_number": 14}, {"level_number": -1}, {"hits": -1}, {"hits": 5}, {"hits": 1.5},
		{"misses": 100}, {"spawned": 0}, {"spawned": 9}, {"phase": "chest"}, {"phase": "complete"},
		{"phase": "unknown"}, {"clear_number": 50}, {"elapsed": INF}, {"next_spawn_in": -1}, {"targets": []}
	]:
		var corrupted: Dictionary = valid.duplicate(true)
		corrupted.run.merge(edits, true)
		game.import_progress(corrupted)
		check(not game.has_saved_run() and game.total_clears == 0,
			"Inconsistent finite combat checkpoints are discarded: " + str(edits))
	for edits in [
		{"uid": 0}, {"uid": 2}, {"word_id": "not-a-word"}, {"age": 100}, {"lifetime": INF},
		{"lane": 3}, {"x_start": NAN}, {"x_end": 20}, {"peak": -1}, {"spin": 20}
	]:
		var corrupted: Dictionary = valid.duplicate(true)
		corrupted.run.targets[0].merge(edits, true)
		game.import_progress(corrupted)
		check(not game.has_saved_run(), "Invalid saved flights are rejected: " + str(edits))
	var spoofed: Dictionary = valid.duplicate(true)
	spoofed.hp = -1
	spoofed.unlocked_level = 14
	spoofed.collected_chests = ["chest-20"]
	spoofed.run.chest_id = "chest-20"
	spoofed.run.last_transcript = "private-spoofed-transcript"
	game.import_progress(spoofed)
	check(game.hp == 5 and game.unlocked_level == 1 and game.current_chest().id == "chest-01"
		and game.collected_chests.is_empty() and game.last_transcript.is_empty(),
		"Derived health, unlocks, rewards, and recognition ignore untrusted extra fields")

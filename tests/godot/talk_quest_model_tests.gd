extends SceneTree

const Model = preload("res://scripts/talk_quest_model.gd")
const Data = preload("res://scripts/talk_quest_data.gd")

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
	_test_sentence_matching()
	_test_bound_events()
	_test_pause_stop_and_replay()
	_test_part_choice_gates()
	_test_full_campaign()
	_test_replay_rewards()
	_test_checkpoint_privacy_and_resume()
	_test_pending_rewards()
	_test_corrupt_progress()
	print("Talk Quest model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func speech_event(game, id: String, text: String = "", stage: String = "final") -> Dictionary:
	var event: Dictionary = game.speech_target()
	event.merge({
		"event_id": id, "text": game.current_prompt().text if text.is_empty() else text,
		"stage": stage, "received_at_ms": 123.0
	})
	return event


func complete_dialogue(game) -> void:
	var remaining: int = game.level.lines.size() - game.line_index
	for index in range(remaining):
		choose_required_part(game)
		var result: Dictionary = game.submit_transcript(game.current_prompt().text)
		check(result.matched, "A reviewed complete sentence advances its conversation")
	check(game.phase == "victory", "The complete conversation reaches victory")


func finish_run(game) -> Dictionary:
	complete_dialogue(game)
	check(game.finish_victory().accepted, "Victory leads to the chest stage")
	return game.open_chest()


func progress_with_counts(counts: Array) -> Dictionary:
	return {"version": 1, "completion_counts": counts, "run": {}}


func choose_required_part(game) -> void:
	if not game.is_cooperative() or game.has_correct_part():
		return
	var repair_index: int = floori(float(game.line_index) / 4.0)
	check(game.choose_part(Data.REPAIRS[repair_index].correct_part).correct,
		"The correct illustrated part opens its four-line repair conversation")


func workshop_game():
	var game := Model.new()
	var counts: Array = []
	counts.resize(13)
	counts.fill(1)
	game.import_progress(progress_with_counts(counts))
	game.start_level(14)
	return game


func _test_catalog() -> void:
	var counts: Array = [6, 6, 8, 8, 10, 10, 12, 12, 14, 14, 16, 16, 18, 20]
	var scenes: Dictionary = {}
	var creatures: Dictionary = {}
	var line_ids: Dictionary = {}
	check(Data.levels().size() == 14, "The catalog contains twelve ordinary levels and two special levels")
	for number in range(1, Data.LEVEL_COUNT + 1):
		var item: Dictionary = Data.level(number)
		check(item.number == number and item.lines.size() == counts[number - 1],
			"Level %d has its reviewed progressive conversation length" % number)
		check(not scenes.has(item.scene_id) and not creatures.has(item.monster_id),
			"Every level has a distinct scene and source creature")
		scenes[item.scene_id] = true
		creatures[item.monster_id] = true
		check(item.chest_id == "chest-%02d" % number, "First clears use their reviewed level chest")
		check(not item.scene.description.is_empty() and item.scene.props.size() >= 4,
			"Each scene describes visible context for its dialogue")
		check(item.kind == ("cooperative" if number == 14 else "boss" if number == 13 else "ordinary"),
			"Only the workshop is cooperative and only the birthday level is the boss")
		for line in item.lines:
			check(line.speaker in ["Adam", "Yoki"] and not line.text.is_empty(),
				"Every sentence belongs to one of the two child speakers")
			check(not line_ids.has(line.id), "Dialogue line IDs are globally unique")
			line_ids[line.id] = true
	check(line_ids.size() == 170, "The complete campaign contains 170 reviewed sentences")
	check(Data.level(1).lines[0].text == "Knock, knock." and Data.level(1).lines[5].text == "Come in, please.",
		"The opening level preserves the requested front-door conversation")
	check(Data.level(13).source_creature == "Yeti" and Data.level(14).source_creature == "Alien",
		"The birthday boss and sleeping workshop friend use the approved source models")
	check(Data.level(0).is_empty() and Data.level(15).is_empty(), "Out-of-range levels have no catalog entry")
	var copied: Dictionary = Data.level(1)
	copied.lines[0].text = "Changed by a caller"
	copied.scene.props.clear()
	check(Data.level(1).lines[0].text == "Knock, knock." and Data.level(1).scene.props.size() == 4,
		"Changing a returned catalog entry cannot corrupt future runs")
	var chest_ids: Dictionary = {}
	for chest in Data.chests():
		check(not chest_ids.has(chest.id), "The twenty chest designs have unique IDs")
		chest_ids[chest.id] = true
		check(chest.duration == 5.0 and chest.hold_time == 1.20 and chest.reveal_time == 3.36,
			"Chest timing preserves the reviewed hold and reveal markers")
	check(chest_ids.size() == 20 and Data.chest("chest-21").is_empty(), "Only the twenty reviewed chests are available")
	check(Data.chest("chest-14").companion_reward, "The workshop toolbox presents the companion reward")
	var workshop: Dictionary = Data.level(14)
	for repair_index in range(5):
		var repair: Dictionary = Data.REPAIRS[repair_index]
		var choice_ids: Dictionary = {}
		var correct_choices: int = 0
		check(repair.choices.size() == 3, "Every repair has three illustrated part choices")
		for choice in repair.choices:
			check(not choice_ids.has(choice.id) and choice.shape in ["wheel", "wing", "ribbon", "screw", "key"] \
				and not choice.label.is_empty(), "Part choices have distinct IDs, readable labels, and supported illustrations")
			choice_ids[choice.id] = true
			if choice.id == repair.correct_part:
				correct_choices += 1
		check(correct_choices == 1, "Every part trio contains exactly one correct part")
		var requester: String = "Adam" if repair_index % 2 == 0 else "Yoki"
		var helper: String = "Yoki" if requester == "Adam" else "Adam"
		for step in range(4):
			var line: Dictionary = workshop.lines[repair_index * 4 + step]
			check(line.repair_id == Data.REPAIRS[repair_index].id and line.repair_step == step + 1,
				"Each workshop repair has exactly four ordered lines")
			check(line.speaker == (requester if step % 2 == 0 else helper),
				"Requester and helper roles swap for each new repair")


func _test_sentence_matching() -> void:
	for pair in [
		["KNOCK KNOCK!", "Knock, knock."],
		["Who is that?", "Who's that?"],
		["  IT IS ME, ADAM.  ", "It's me, Adam."],
		["Let\u2019s wash our hands!", "Let us wash our hands."],
		["I cannot find my socks.", "I can't find my socks."],
		["We do not need a bag.", "We don't need a bag."],
		["You are welcome.\nEnjoy it!", "You're welcome. Enjoy it."],
		["I will bring the lantern", "I'll bring the lantern."]
	]:
		check(Model.sentence_matches(pair[0], pair[1]), "Case, punctuation, spacing, and explicit contractions normalize: " + pair[0])
	for text in [
		"Come in", "Please", "come", "Come in, please, Adam", "Well, come in, please",
		"Do not come in, please", "Come out, please", "Come in, please 2", "Come in, please2",
		"Come in, pleas\u00e9", "Come in, please " + String.chr(0x00e9), "", "..."
	]:
		check(not Model.sentence_matches(text, "Come in, please."), "A substring or changed full sentence cannot match: " + text)
	check(not Model.sentence_matches("We can go", "We can't go"), "Normalization never drops negation")
	check(not Model.sentence_matches("Well go", "We'll go"), "An ambiguous apostrophe-free word is not expanded")
	check(not Model.sentence_matches("Its me", "It's me"), "Possessive its cannot silently become it is")
	check(not Model.sentence_matches("a".repeat(513), "a"), "Oversized recognition text is bounded")


func _test_bound_events() -> void:
	var game := Model.new()
	var notifications: Dictionary = {"count": 0}
	game.changed.connect(func() -> void: notifications.count += 1)
	check(not game.start_level(2) and game.phase == "ready", "A fresh campaign cannot skip a locked level")
	check(game.start_level(1), "The first level starts")
	check(game.hp == 60 and game.max_hp == 60, "Combat health is derived from six required lines")
	for edits in [
		{"event_id": ""}, {"event_id": "x".repeat(161)}, {"event_id": 1}, {"round_id": "old-round"},
		{"target_uid": 0}, {"target_uid": 1.5}, {"target_uid": "1"}, {"target_uid": INF},
		{"target_uid": 2}, {"stage": "unknown"}, {"stage": 3}, {"text": 9},
		{"text": "x".repeat(513)}, {"received_at_ms": -1}, {"received_at_ms": INF}, {"received_at_ms": "now"}
	]:
		var invalid: Dictionary = speech_event(game, "invalid")
		invalid.merge(edits, true)
		var result: Dictionary = game.submit_speech_event(invalid)
		check(not result.accepted and game.line_index == 0 and game.hp == 60,
			"Invalid or stale speech metadata cannot advance: " + str(edits))
		check(result.has_all(["accepted", "matched", "completed", "damage", "repair_completed"]),
			"Every event outcome has stable result keys")
	check(not game.submit_speech_event({"text": "Knock, knock."}).accepted,
		"Unbound external transcripts cannot enter the practice path")
	var candidate: Dictionary = speech_event(game, "recognition-1", "KNOCK KNOCK", "interim")
	var result: Dictionary = game.submit_speech_event(candidate)
	check(result.accepted and not result.matched and result.damage == 0 and game.line_index == 0,
		"Even an exact interim result only updates recognition display")
	check(game.last_transcript == "KNOCK KNOCK" and game.hp == 60, "Interim recognition is visible without damage")
	candidate.stage = "final"
	result = game.submit_speech_event(candidate)
	check(result.matched and result.damage == 10 and game.line_index == 1 and game.hp == 50,
		"The final result of the same recognition advances exactly once")
	var duplicate: Dictionary = speech_event(game, "recognition-1")
	check(not game.submit_speech_event(duplicate).accepted and game.line_index == 1,
		"A consumed occurrence cannot be rebound to the following line")
	var stale: Dictionary = candidate.duplicate(true)
	stale.event_id = "late-old-target"
	check(not game.submit_speech_event(stale).accepted, "An old prompt binding cannot hit the next prompt")
	var wrong: Dictionary = speech_event(game, "wrong-final", "That is a banana")
	result = game.submit_speech_event(wrong)
	check(result.accepted and not result.matched and result.damage == 0 and game.hp == 50 and game.line_index == 1,
		"A wrong final answer has no child penalty")
	check(game.feedback.contains(game.current_prompt().text) and game.last_transcript == "That is a banana",
		"A wrong answer shows the recognition and helpful complete-sentence feedback")
	wrong.text = game.current_prompt().text
	check(not game.submit_speech_event(wrong).accepted, "A corrected final with the same event ID remains consumed")
	var fresh: Dictionary = speech_event(game, "recognition-2", "Who is that")
	fresh.erase("received_at_ms")
	check(game.submit_speech_event(fresh).matched and game.line_index == 2,
		"A fresh bound final accepts contraction expansion without requiring diagnostic timestamps")
	check(notifications.count == 5, "State changes emit notifications while rejected metadata does not")


func _test_pause_stop_and_replay() -> void:
	var game := Model.new()
	game.start_level(1)
	game.submit_speech_event(speech_event(game, "already-consumed"))
	var delayed: Dictionary = speech_event(game, "delayed")
	var old_round: String = game.round_id
	check(game.pause().accepted and game.is_paused() and game.round_id != old_round,
		"Pausing saves the active phase and invalidates in-flight recognition")
	check(game.speech_target().target_uid == 0 and not game.submit_speech_event(delayed).accepted,
		"A paused level offers no active speech target")
	var paused_round: String = game.round_id
	var resumed: Dictionary = game.resume()
	check(resumed.accepted and resumed.phase == "playing" and game.round_id != paused_round,
		"Resume reports and restores the previous phase with a fresh speech round")
	check(not game.submit_speech_event(delayed).accepted and game.line_index == 1,
		"Recognition begun before a pause cannot advance after resume")
	check(not game.submit_speech_event(speech_event(game, "already-consumed")).accepted,
		"Consumed event IDs remain consumed across pause and resume")
	check(not game.resume().accepted and game.hp == 50, "Repeated resume cannot change progress")
	var saved: Dictionary = game.export_progress()
	game.stop()
	check(game.phase == "ready" and not game.has_saved_run() and game.last_transcript.is_empty(),
		"Stopping clears the active attempt without fabricating a completion")
	check(game.import_progress(saved) and game.resume().accepted and game.line_index == 1,
		"A checkpoint taken before leaving can restore the stopped attempt")
	check(game.start_level(1) and game.line_index == 0 and game.hp == 60,
		"Explicitly replaying an unlocked level starts a fresh complete conversation")
	check(game.submit_transcript("Knock, knock.").input == "practice", "Typed practice is identified explicitly in its result")


func _test_part_choice_gates() -> void:
	var ordinary := Model.new()
	ordinary.start_level(1)
	check(ordinary.has_correct_part() and ordinary.current_part_choices().is_empty(),
		"Ordinary conversations never acquire a part-selection gate")
	check(not ordinary.choose_part("wheel").accepted and ordinary.line_index == 0,
		"Part choices cannot mutate an ordinary level")
	var game = workshop_game()
	check(not game.has_correct_part() and game.current_part_choices().size() == 3,
		"The workshop starts with three choices before its first sentence can score")
	var choices: Array = game.current_part_choices()
	choices[0].label = "Changed by a caller"
	check(game.current_part_choices()[0].label == "Wheel", "Part choice callers receive independent copies")
	var interim: Dictionary = speech_event(game, "gated-occurrence", "Tinker is sleeping", "interim")
	check(game.submit_speech_event(interim).accepted and game.line_index == 0,
		"Gated interim recognition may display without advancing")
	var final_event: Dictionary = speech_event(game, "gated-occurrence")
	var gated: Dictionary = game.submit_speech_event(final_event)
	check(gated.accepted and not gated.matched and gated.reason == "part_required" \
		and game.line_index == 0 and game.hp == 0 and game.repaired_toys.is_empty(),
		"Even the exact final sentence cannot score before its part is chosen")
	check(not game.submit_transcript(game.current_prompt().text).matched,
		"Typed practice observes the same part-selection gate")
	var wrong: Dictionary = game.choose_part("wing")
	check(wrong.accepted and not wrong.correct and wrong.damage == 0 and not wrong.repair_completed \
		and game.line_index == 0 and game.selected_parts.is_empty() and game.total_clears == 13,
		"A valid wrong illustrated choice is harmless and never awards a repair or clear")
	check(not game.feedback.is_empty(), "An incorrect part provides encouraging feedback")
	check(not game.choose_part("not-a-part").accepted and not game.choose_part("").accepted,
		"Unknown part IDs cannot open the gate")
	game.pause()
	check(not game.choose_part("wheel").accepted and not game.has_correct_part(),
		"Paused choices cannot alter repair progress")
	game.resume()
	var previous_round: String = game.round_id
	var old_binding: Dictionary = speech_event(game, "before-part-selection")
	var chosen: Dictionary = game.choose_part("wheel")
	check(chosen.accepted and chosen.correct and chosen.part_id == "wheel" and chosen.repair_id == "toy-car" \
		and game.has_correct_part() and game.selected_parts == ["wheel"] and game.line_index == 0,
		"The correct part opens only its own conversation without advancing a sentence")
	check(game.round_id != previous_round and not game.submit_speech_event(old_binding).accepted,
		"Selecting a part invalidates speech captured before the gate opened")
	check(not game.choose_part("wheel").accepted and game.selected_parts.size() == 1,
		"Repeated selection is idempotent")
	check(not game.submit_speech_event(speech_event(game, "gated-occurrence")).accepted,
		"A final occurrence consumed by the gate cannot be rebound after selection")
	for repair_index in range(5):
		if repair_index > 0:
			check(not game.has_correct_part() and game.line_index == repair_index * 4,
				"Each next toy needs its own part before its four-line group")
			choose_required_part(game)
		for step in range(4):
			check(game.has_correct_part(), "A chosen part remains selected throughout all four repair lines")
			var result: Dictionary = game.submit_transcript(game.current_prompt().text)
			check(result.matched and result.repair_completed == (step == 3) and result.damage == 0,
				"A selected part permits four sentences and completes one cooperative repair")
	check(game.phase == "victory" and game.selected_parts == ["wheel", "wing", "ribbon", "screw", "key"] \
		and game.repaired_toys.size() == 5 and game.current_part_choices().is_empty(),
		"Five correct parts and twenty sentences complete the workshop exactly once")
	check(not game.choose_part("key").accepted, "Completed conversations accept no further part changes")
	_test_part_checkpoints()


func _test_part_checkpoints() -> void:
	var game = workshop_game()
	var before_choice: Dictionary = game.export_progress()
	var restored := Model.new()
	check(restored.import_progress(before_choice) and not restored.has_correct_part() \
		and restored.selected_parts.is_empty(), "A save before choosing retains the closed part gate")
	game.choose_part("wheel")
	var selected_before_line: Dictionary = game.export_progress()
	restored.import_progress(selected_before_line)
	check(restored.has_correct_part() and restored.line_index == 0 and restored.selected_parts == ["wheel"],
		"A selected part survives a save before the first spoken line")
	for step in range(4):
		game.submit_transcript(game.current_prompt().text)
	var next_gate: Dictionary = game.export_progress()
	restored.import_progress(next_gate)
	check(not restored.has_correct_part() and restored.selected_parts == ["wheel"] \
		and restored.line_index == 4 and restored.repaired_toys.size() == 1,
		"A checkpoint at the next repair boundary preserves its unchosen gate")
	game.choose_part("wing")
	game.submit_transcript(game.current_prompt().text)
	var mid_group: Dictionary = game.export_progress()
	restored.import_progress(mid_group)
	check(restored.has_correct_part() and restored.selected_parts == ["wheel", "wing"] \
		and restored.line_index == 5 and restored.last_transcript.is_empty(),
		"A mid-group checkpoint preserves both canonical parts without retaining speech")
	check(restored.resume().accepted and restored.submit_transcript(restored.current_prompt().text).matched,
		"A resumed group can continue without asking for the same part again")
	for bad_parts in [[], ["wing"], ["wheel", "wheel"], ["wheel", "wing", "ribbon"], ["wheel", 2], "wheel"]:
		var bad: Dictionary = mid_group.duplicate(true)
		bad.run.selected_parts = bad_parts
		restored.import_progress(bad)
		check(not restored.has_saved_run() and restored.total_clears == 13,
			"Malformed, incomplete, or future part selections reject only the pending run: " + str(bad_parts))
	var poisoned: Dictionary = before_choice.duplicate(true)
	poisoned.run.selected_parts = ["Private speech must not persist"]
	restored.import_progress(poisoned)
	check(not restored.has_saved_run() and not JSON.stringify(restored.export_progress()).contains("Private speech"),
		"Only canonical part IDs may enter persistent progress")
	var legacy: Dictionary = mid_group.duplicate(true)
	legacy.run.erase("selected_parts")
	restored.import_progress(legacy)
	check(restored.has_saved_run() and restored.line_index == 5 and restored.selected_parts == ["wheel", "wing"],
		"Older version-one saves infer only parts for repair groups already begun")
	legacy = next_gate.duplicate(true)
	legacy.run.erase("selected_parts")
	restored.import_progress(legacy)
	check(restored.selected_parts == ["wheel"] and not restored.has_correct_part(),
		"Legacy checkpoints do not automatically choose a future repair's part")
	game.start_level(14)
	check(game.selected_parts.is_empty() and not game.has_correct_part(),
		"Replaying the workshop resets every part gate")


func _test_full_campaign() -> void:
	var game := Model.new()
	for number in range(1, Data.LEVEL_COUNT + 1):
		check(game.start_level(number), "A cleared level unlocks the following conversation")
		var repairs: int = 0
		for index in range(game.level.lines.size()):
			choose_required_part(game)
			var before_hp: int = game.hp
			var result: Dictionary = game.submit_transcript(game.current_prompt().text)
			check(result.matched and result.damage == (0 if number == 14 else 10),
				"Only combat levels deal damage for a complete spoken sentence")
			check(game.hp == before_hp - result.damage, "Each accepted line changes HP exactly once")
			check(result.completed == (index == game.level.lines.size() - 1),
				"Only the final line reports the conversation complete")
			if result.repair_completed:
				repairs += 1
			if number == 14:
				check(game.hp == 0 and game.max_hp == 0 and game.repaired_toys.size() == floori(float(index + 1) / 4.0),
					"Workshop progress is five repairs with no health or combat state")
		check(game.phase == "victory" and game.hp == 0 and game.current_prompt().is_empty(),
			"Completing the dialogue starts its final animation stage")
		check(repairs == (5 if number == 14 else 0), "Only the workshop completes exactly five repair events")
		check(game.total_clears == number - 1 and not game.open_chest().accepted,
			"A dialogue victory does not prematurely award its chest")
		check(game.finish_victory().accepted and game.phase == "chest", "The final animation completes before the chest stage")
		check(game.current_chest().id == "chest-%02d" % number, "A first clear receives its matching scene chest")
		var reward: Dictionary = game.open_chest()
		check(reward.accepted and reward.first_clear and reward.new_chest and game.phase == "complete",
			"Opening the chest atomically commits the first-clear reward")
		check(game.total_clears == number and game.unlocked_level == mini(number + 1, 14),
			"Campaign progression advances once per committed clear")
		check(game.companion_unlocked == (number == 14), "The companion unlocks only after all workshop repairs and its chest")
		check(not game.open_chest().accepted and game.total_clears == number,
			"Opening a chest twice cannot duplicate any reward")
	check(game.completed_levels.size() == 14 and game.collected_chests.size() == 14,
		"The initial campaign awards exactly fourteen distinct themed chests")


func _test_replay_rewards() -> void:
	var game := Model.new()
	var completed: Array = []
	completed.resize(14)
	completed.fill(1)
	check(game.import_progress(progress_with_counts(completed)), "Completed campaign progress restores")
	for index in range(6):
		game.start_level(1)
		check(game.current_chest().id == "chest-%02d" % (index + 15), "The first six replays reach all six additional chest designs")
		var reward: Dictionary = finish_run(game)
		check(reward.accepted and not reward.first_clear and reward.new_chest,
			"A legitimate replay earns its new collection design")
		check(game.unlocked_level == 14 and game.completed_levels.size() == 14,
			"Replays never inflate campaign unlocks or completed-level entries")
	check(game.collected_chests.size() == 20 and game.total_clears == 20,
		"All twenty reviewed designs are reachable through the campaign and six replays")
	game.start_level(1)
	check(game.current_chest().id == "chest-01", "Later replays cycle through the complete chest catalog")
	var repeated_reward: Dictionary = finish_run(game)
	check(repeated_reward.accepted and not repeated_reward.new_chest and game.collected_chests.size() == 20,
		"Repeated designs do not duplicate collection IDs")
	var restored := Model.new()
	restored.import_progress(game.export_progress())
	check(restored.collected_chests == game.collected_chests and restored.total_clears == 21,
		"Saved clear counters reconstruct the collection and replay rotation")
	var early := Model.new()
	early.import_progress(progress_with_counts([20]))
	early.start_level(1)
	check(early.current_chest().id != "chest-14" and not early.companion_unlocked,
		"Replaying the first level cannot obtain the workshop companion early")


func _test_checkpoint_privacy_and_resume() -> void:
	var game := Model.new()
	game.start_level(1)
	game.submit_speech_event(speech_event(game, "private-recognition-never-save", "KNOCK KNOCK!"))
	var delayed: Dictionary = speech_event(game, "old-round-result")
	var checkpoint: Dictionary = game.export_progress()
	var serialized: String = JSON.stringify(checkpoint)
	check(not serialized.contains("KNOCK") and not serialized.contains("private-recognition") \
		and not serialized.contains("transcript") and not serialized.contains(game.round_id),
		"Persistent progress contains no spoken text, recognition ID, or speech round ID")
	check(checkpoint.run.line_index == 1 and checkpoint.run.phase == "playing",
		"The checkpoint records the completed prompt count")
	var restored := Model.new()
	check(restored.import_progress(checkpoint) and restored.has_saved_run() and restored.phase == "paused",
		"A saved conversation restores paused for an explicit Continue action")
	check(restored.line_index == 1 and restored.hp == 50 and restored.last_transcript.is_empty() and restored.feedback.is_empty(),
		"HP is reconstructed while recognition text and feedback are reset")
	check(restored.resume().phase == "playing" and restored.current_prompt().text == "Who's that?",
		"Continue returns to the exact next sentence")
	check(not restored.submit_speech_event(delayed).accepted, "Old recognition callbacks cannot reach a restored session")
	check(restored.submit_speech_event(speech_event(restored, "private-recognition-never-save")).matched,
		"Recognition receipt sets are transient and the new round safely owns new occurrences")
	var workshop := Model.new()
	var counts: Array = []
	counts.resize(13)
	counts.fill(1)
	workshop.import_progress(progress_with_counts(counts))
	workshop.start_level(14)
	for index in range(9):
		choose_required_part(workshop)
		workshop.submit_transcript(workshop.current_prompt().text)
	workshop.pause()
	var resumed_workshop := Model.new()
	resumed_workshop.import_progress(workshop.export_progress())
	check(resumed_workshop.repaired_toys == ["toy-car", "toy-plane"] and resumed_workshop.line_index == 9,
		"Workshop restoration derives exactly the completed four-line repairs")
	check(resumed_workshop.selected_parts == ["wheel", "wing", "ribbon"] and resumed_workshop.has_correct_part(),
		"The third repair keeps its selected ribbon when resumed after its first sentence")
	check(resumed_workshop.hp == 0 and resumed_workshop.max_hp == 0,
		"A cooperative checkpoint can never restore combat health")


func _test_pending_rewards() -> void:
	var game := Model.new()
	game.start_level(1)
	complete_dialogue(game)
	var victory_save: Dictionary = game.export_progress()
	var victory_restore := Model.new()
	victory_restore.import_progress(victory_save)
	check(victory_restore.resume().phase == "victory" and victory_restore.total_clears == 0,
		"Leaving during the final animation preserves the earned pending victory")
	victory_restore.finish_victory()
	victory_restore.pause()
	var chest_save: Dictionary = victory_restore.export_progress()
	check(chest_save.run.phase == "chest", "A paused chest checkpoint retains the chest phase")
	var chest_restore := Model.new()
	chest_restore.import_progress(chest_save)
	check(chest_restore.resume().phase == "chest" and chest_restore.current_chest().id == "chest-01",
		"Returning to a pending chest preserves its deterministic reward")
	check(chest_restore.open_chest().accepted and chest_restore.total_clears == 1,
		"The pending chest can be claimed exactly once after restoration")
	var committed: Dictionary = chest_restore.export_progress()
	check(committed.run.is_empty(), "A committed chest leaves no pending reward in the save")
	var committed_restore := Model.new()
	committed_restore.import_progress(committed)
	check(not committed_restore.has_saved_run() and not committed_restore.open_chest().accepted,
		"A restored committed save cannot award its previous chest again")
	var stale_pending: Dictionary = chest_save.duplicate(true)
	stale_pending.completion_counts = committed.completion_counts
	committed_restore.import_progress(stale_pending)
	check(not committed_restore.has_saved_run() and committed_restore.total_clears == 1,
		"A stale pending run cannot be combined with already committed counters to duplicate a reward")


func _test_corrupt_progress() -> void:
	var game := Model.new()
	check(not game.import_progress(null) and not game.import_progress([]) \
		and not game.import_progress({"version": 2, "completion_counts": []}) \
		and not game.import_progress({"version": 1, "completion_counts": "bad"}),
		"Unsupported or malformed save roots are rejected")
	game.import_progress(progress_with_counts([2, 0, 9, 10]))
	check(game.completed_levels == [1] and game.unlocked_level == 2 and game.total_clears == 2,
		"Completion gaps cannot unlock later levels from corrupt progress")
	for value in [-1, 1.5, "3", true, INF, {}]:
		game.import_progress(progress_with_counts([value, 1]))
		check(game.total_clears == 0 and game.unlocked_level == 1,
			"Invalid count types and values cannot manufacture clears: " + str(value))
	game.import_progress(progress_with_counts([1.0e100, 1]))
	check(game.clear_count(1) == Model.MAX_LEVEL_CLEARS and game.total_clears == Model.MAX_LEVEL_CLEARS + 1,
		"Finite oversized counters are clamped before integer conversion")
	var huge: Array = []
	huge.resize(1000)
	huge.fill(1)
	game.import_progress(progress_with_counts(huge))
	check(game.total_clears == 14 and game.unlocked_level == 14,
		"Extra completion counters beyond the campaign are ignored")
	var source := Model.new()
	source.start_level(1)
	source.submit_transcript("Knock, knock.")
	var valid: Dictionary = source.export_progress()
	for edits in [
		{"level_number": 14}, {"level_number": -1}, {"line_index": -1}, {"line_index": 1000000},
		{"line_index": 1.5}, {"line_index": "1"}, {"phase": "chest"}, {"phase": "complete"},
		{"phase": "unknown"}, {"clear_number": 50}, {"clear_number": 0}
	]:
		var corrupted: Dictionary = valid.duplicate(true)
		corrupted.run.merge(edits, true)
		game.import_progress(corrupted)
		check(not game.has_saved_run() and game.total_clears == 0,
			"Inconsistent saved run state cannot bypass conversation progress: " + str(edits))
	var spoofed: Dictionary = valid.duplicate(true)
	spoofed.hp = -10
	spoofed.unlocked_level = 14
	spoofed.collected_chests = ["chest-20"]
	spoofed.run.run_id = "x".repeat(1000)
	spoofed.run.chest_id = "chest-20"
	spoofed.run.last_transcript = "Private input must not survive"
	game.import_progress(spoofed)
	check(game.hp == 50 and game.unlocked_level == 1 and game.collected_chests.is_empty(),
		"Derived state ignores untrusted HP, unlock, and collection fields")
	check(game.current_chest().id == "chest-01" and game.last_transcript.is_empty() \
		and not JSON.stringify(game.export_progress()).contains("Private input"),
		"Run restoration derives its reward and drops unrecognized input fields")

extends SceneTree

const Model = preload("res://scripts/voice_pop_model.gd")
const NAMES: Array[String] = ["Ada", "Ben", "Cleo", "Drew", "Eli"]
const EMOJIS: Array[String] = ["🐱", "🐶", "🦊", "🐼", "🐸"]


func _vector(values: Array) -> Array:
	var result: Array = values.duplicate()
	result.resize(256)
	for index in range(values.size(), result.size()):
		result[index] = 0.0
	return result


func _voice(index: int) -> Array:
	var result: Array = _vector([])
	result[index] = 1.0
	return result


func _profiles(count: int = 5) -> Array:
	var profiles: Array = []
	for index in range(count):
		profiles.append({"id": "voice-%d" % index, "name": NAMES[index % NAMES.size()],
			"emoji": EMOJIS[index % EMOJIS.size()], "embedding": _voice(index)})
	return profiles


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
	_test_modes_and_round_identity()
	_test_joining_and_capacity()
	_test_profile_validation_and_snapshots()
	_test_multiple_voice_templates()
	_test_normalization_and_reference_protection()
	_test_bad_events()
	_test_historical_hits()
	_test_settling_and_deadline()
	_test_pause_and_ranking()
	_test_multiword_and_timestamp_order()
	_test_recognition_feedback()
	print("Voice Pop multiplayer model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _game(ids: Array = ["cat", "dog", "apple", "horn"]) -> Variant:
	var game = Model.new()
	var words: Array = []
	for id in ids:
		words.append({"id": id, "text": id, "image": "image.png", "audio": "word.wav"})
	check(game.configure(words, 7), "Fixture configures illustrated vocabulary")
	check(game.set_voice_profiles(_profiles()), "The fixture loads saved voice profiles")
	check(game.set_play_mode("multi"), "Ready game accepts multiplayer")
	check(game.start(), "Multiplayer starts through the existing start interface")
	return game


func _event(game: Variant, event_id: String, text: String, embedding: Variant,
		start_ms: float = -1.0, end_ms: float = -1.0) -> Dictionary:
	return {
		"round_id": game.round_id, "event_id": event_id, "text": text,
		"start_ms": game.elapsed * 1000.0 - 50.0 if start_ms < 0.0 else start_ms,
		"end_ms": game.elapsed * 1000.0 if end_ms < 0.0 else end_ms,
		"embedding": embedding
	}


func _hit_next(game: Variant, id: String, embedding: Variant) -> Array:
	if game.targets.is_empty():
		game.advance(0.7)
	game.advance(0.1)
	return game.hit_speech_event(_event(game, id, game.targets[0].word.text, embedding))


func _test_multiple_voice_templates() -> void:
	var game = _game()
	var profiles: Array = _profiles(2)
	profiles[0].embedding = _vector([1.6, 3.2])
	profiles[0].templates = [_vector([0.8, 0.6]), _vector([0.8, 0.6]), _voice(1), _voice(1)]
	profiles[1].embedding = _voice(2)
	game.stop()
	check(game.set_voice_profiles(profiles) and game.start(), "Multiple valid samples join the next round atomically")
	profiles[0].templates[0][0] = 0.0
	check(is_equal_approx(game._round_profiles[0].templates[0][0], 0.8), "Round templates do not share caller-owned arrays")
	check(_hit_next(game, "supported-variation", _voice(0)).size() == 1,
		"Two supporting samples can recognize a voice variation lost in the overall average")
	check(game.players_snapshot()[0].id == "voice-0", "Multiple templates still represent one registered identity")
	var previous: Array = game._voice_profiles.duplicate(true)
	for templates in [[], [_vector([])], [_voice(0), []], "invalid", [_voice(0), _voice(0), _voice(0),
			_voice(0), _voice(0), _voice(0), _voice(0), _voice(0), _voice(0)]]:
		var invalid: Array = _profiles(1)
		invalid[0].templates = templates
		check(not game.set_voice_profiles(invalid) and game._voice_profiles == previous,
			"Malformed or oversized template sets cannot erase the saved library")
	game.stop()
	var outlier: Array = _profiles(1)
	outlier[0].templates = [_voice(0), _voice(1), _voice(1)]
	check(game.set_voice_profiles(outlier) and game.start(), "Outlier fixture starts")
	check(_hit_next(game, "one-close-sample", _voice(0)).is_empty(),
		"One close template cannot override two incompatible saved samples")
	game.stop()
	var ambiguous: Array = _profiles(2)
	for profile in ambiguous:
		profile.templates = [_voice(0), _voice(0)]
	check(game.set_voice_profiles(ambiguous) and game.start(), "Ambiguous template fixture starts")
	check(_hit_next(game, "ambiguous-templates", _voice(0)).is_empty(),
		"The runner-up margin compares people, never templates within one person")
	check(_hit_next(game, "unknown-templates", _voice(20)).is_empty(), "Multi-template matching still rejects unknown voices")


func _test_modes_and_round_identity() -> void:
	var game = _game()
	check(game.play_mode == "multi" and not game.round_id.is_empty(), "A live multiplayer round has a transport identity")
	check(not game.set_play_mode("single") and not game.start(), "Duplicate starts and mode changes cannot reset a live game")
	check(game.hit_transcript(game.targets[0].word.text).is_empty(), "The single-player transcript backend cannot score a multiplayer round")
	var first_round: String = game.round_id
	var saved: Dictionary = _event(game, "old", game.targets[0].word.text, _voice(0), 0.0, 100.0)
	_hit_next(game, "first", _voice(0))
	game.stop()
	check(game.start() and game.round_id != first_round, "Each new round gets a new ID")
	check(game.players_snapshot().is_empty() and game.hits == 0, "A new round clears players and their scores")
	game.advance(0.2)
	check(game.hit_speech_event(saved).is_empty(), "A callback carrying an old round ID cannot score")
	game.stop()
	check(game.set_play_mode("single") and not game.set_play_mode("unknown"), "The stopped game accepts only known modes")
	game.start()
	game.advance(0.2)
	check(game.hit_speech_event(_event(game, "wrong-backend", game.targets[0].word.text, _voice(0))).is_empty(), "Local speech events cannot score a single-player round")
	check(game.hit_transcript(game.targets[0].word.text).size() == 1, "Switching back preserves the existing single-player recognizer")


func _test_joining_and_capacity() -> void:
	var game = _game()
	game.advance(0.2)
	check(game.hit_speech_event(_event(game, "chatter", "unrelated chatter", _voice(4))).is_empty(), "Chatter cannot score")
	check(game.players_snapshot().is_empty() and game.voice_profile_count() == 5, "No-hit speech does not join the round or change the voice library")
	for index in range(4):
		var hits: Array = _hit_next(game, "join-%d" % index, _voice(index))
		check(hits.size() == 1 and hits[0].player_id == "voice-%d" % index and hits[0].player_index == index, "Distinct successful voice joins in P1–P4 order")
	check(game.players_snapshot().size() == 4 and game.hits == 4, "Exactly four registered players have joined this round")
	check(_hit_next(game, "fifth", _voice(4)).is_empty() and game.players_snapshot().size() == 4 and game.hits == 4, "A fifth registered speaker is ignored after the round reaches capacity")
	check(_hit_next(game, "p1-again", _voice(0))[0].player_id == "voice-0", "A returning player keeps their saved identity")
	var players: Array = game.players_snapshot()
	check(players[0].hits == 2 and players[1].hits == 1, "Each player owns only their successful targets")
	players[0].hits = 900
	check(game.players_snapshot()[0].hits == 2 and not game.players_snapshot()[0].has("embedding"), "UI snapshots do not expose or mutate voice references")
	var report: Dictionary = game.summary()
	check(report.play_mode == "multi" and report.round_id == game.round_id and report.players.size() == 4, "The summary carries mode, round, and personal results")
	check(report.ranking[0].id == "voice-0" and report.ranking[0].rank == 1 and report.ranking[1].rank == 2 and report.ranking[3].rank == 2, "Ranking uses hit count and assigns tied ranks")


func _test_normalization_and_reference_protection() -> void:
	var game = _game()
	_hit_next(game, "original", _vector([10.0]))
	check(_hit_next(game, "quiet", _vector([0.1]))[0].player_id == "voice-0", "Cosine normalization is independent of vector magnitude")
	var before: Array = game._round_profiles.duplicate(true)
	var ambiguous: Array = _vector([sqrt(0.5), sqrt(0.5)])
	check(_hit_next(game, "ambiguous", ambiguous).is_empty() and game.players_snapshot().size() == 1,
		"A voice equally close to two saved profiles cannot score or join")
	check(_hit_next(game, "low-confidence", _vector([0.5, 0.0, 0.0, 0.0, 0.0, sqrt(0.75)])).is_empty(),
		"A weak match is ignored even when it has no close runner-up")
	check(_hit_next(game, "unknown", _voice(15)).is_empty() and game.players_snapshot().size() == 1,
		"An unregistered correct speaker never gets an automatic identity")
	check(_hit_next(game, "confident", _vector([0.95, 0.1]))[0].player_id == "voice-0",
		"A sufficiently clear saved voice still scores the unclaimed target")
	check(game._round_profiles == before and game._voice_profiles == before,
		"No speech event adapts or contaminates the saved voice references")
	check(not game.configure_speaker_matching(0.7, 0.1), "Recognition thresholds cannot move mid-round")
	game.stop()
	check(game.configure_speaker_matching(0.65, 0.12), "A measured study may tune confidence and runner-up margin between rounds")
	check(not game.configure_speaker_matching(NAN, 0.1) and not game.configure_speaker_matching(0.6, INF)
		and not game.configure_speaker_matching(-0.1, 0.1) and not game.configure_speaker_matching(0.6, 1.1),
		"Invalid confidence or margin configurations are rejected")


func _test_profile_validation_and_snapshots() -> void:
	var game = _game()
	var original: Array = game._voice_profiles.duplicate(true)
	for invalid in [[{}], _profiles(11), [_profiles()[0], _profiles()[0]]]:
		check(not game.set_voice_profiles(invalid) and game._voice_profiles == original,
			"Malformed, duplicate, and over-capacity profile libraries are rejected atomically")
	for change in [{"id": ""}, {"name": "  "}, {"emoji": ""}, {"embedding": [1.0]},
		{"embedding": _vector([])}, {"embedding": _vector([NAN])}, {"avatar_png": 3}]:
		var invalid: Array = _profiles()
		invalid[0].merge(change, true)
		check(not game.set_voice_profiles(invalid) and game._voice_profiles == original,
			"Invalid profile metadata or voice data leaves the confirmed library intact")
	var changed: Array = _profiles(10)
	changed[0].name = "Renamed"
	changed[0].emoji = "🦁"
	changed[0].embedding = _voice(20)
	check(game.set_voice_profiles(changed) and game.voice_profile_count() == 10,
		"The library accepts ten saved users while an existing round continues")
	changed[0].name = "External mutation"
	changed[0].embedding[20] = 0.0
	var hit: Dictionary = _hit_next(game, "old-reference", _voice(0))[0]
	check(hit.player_id == "voice-0" and hit.player_name == "Ada" and hit.player_emoji == "🐱",
		"A running round retains its original voice, name and avatar snapshot")
	game.pause()
	check(game.set_voice_profiles([]), "Deleting the pending library is allowed while paused")
	game.resume()
	check(_hit_next(game, "old-after-pause", _voice(0))[0].player_id == "voice-0",
		"Pause and library deletion preserve the active round's enrolled voice")
	game.stop()
	check(not game.start() and game.phase == "finished", "A new multiplayer round cannot start without registered users")
	check(game.set_voice_profiles(_profiles(10)) and game.start(), "A new round can start after profiles are supplied")
	check(game._round_profiles.size() == 10 and game.players_snapshot().is_empty(),
		"The next round snapshots all ten profiles with no automatically joined players")
	var one_profile: Array = _profiles(1)
	one_profile[0].name = "New name"
	one_profile[0].embedding = _voice(20)
	game.stop()
	check(game.set_voice_profiles(one_profile) and game.start(), "A replaced saved profile is used on the next round")
	check(_hit_next(game, "obsolete-voice", _voice(0)).is_empty(), "An obsolete voice does not match its replaced profile")
	check(_hit_next(game, "replacement", _voice(20))[0].player_name == "New name",
		"The replacement voice resolves to its saved name")
	var report: Dictionary = game.summary()
	check(report.players[0].emoji == "🐱" and not report.players[0].has("embedding")
		and not report.ranking[0].has("embedding"), "HUD and ranking snapshots include identity but never voice vectors")
	report.players[0].name = "Tampered"
	check(game.players_snapshot()[0].name == "New name", "Public profile metadata cannot mutate the round snapshot")


func _test_bad_events() -> void:
	var game = _game()
	game.advance(0.2)
	var template: Dictionary = _event(game, "bad", game.targets[0].word.text, _voice(0))
	var bad_events: Array = []
	for missing_key in template.keys():
		var missing: Dictionary = template.duplicate(true)
		missing.erase(missing_key)
		bad_events.append(missing)
	for change in [
		{"event_id": ""}, {"event_id": 2}, {"round_id": "obsolete"}, {"round_id": 1},
		{"text": null}, {"start_ms": "0"}, {"start_ms": -1.0}, {"start_ms": NAN},
		{"start_ms": 1000.0, "end_ms": 1100.0}, {"end_ms": 0.0}, {"end_ms": INF},
		{"end_ms": 30001.0}, {"embedding": []}, {"embedding": [0.0, 0.0]},
		{"embedding": [NAN]}, {"embedding": [INF]}, {"embedding": ["1"]},
		{"embedding": [true]}, {"embedding": "voice"}, {"embedding": null}
	]:
		var invalid: Dictionary = template.duplicate(true)
		invalid.merge(change, true)
		bad_events.append(invalid)
	for invalid in bad_events:
		check(game.hit_speech_event(invalid).is_empty() and game.players_snapshot().is_empty(), "Malformed events cannot allocate voices or score")
	var oversized: Array = []
	oversized.resize(4097)
	oversized.fill(1.0)
	check(game.hit_speech_event(_event(game, "huge", game.targets[0].word.text, oversized)).is_empty(), "Unbounded vectors are rejected")
	check(game.hit_speech_event(template).size() == 1, "Rejected malformed events do not poison a later valid event ID")
	game.advance(0.7)
	game.advance(0.1)
	check(game.hit_speech_event(_event(game, "wrong-shape", game.targets[0].word.text, [1.0, 0.0])).is_empty(), "The embedding dimension cannot change after a successful player joins")


func _test_historical_hits() -> void:
	var game = _game(["cat"])
	var first_uid: int = game.targets[0].uid
	var late: Dictionary = _event(game, "late", "cat", _voice(0), 100.0, 200.0)
	game.advance(6.5)
	check(game.misses == 1 and game.targets.size() == 1 and game.targets[0].uid != first_uid, "Fixture has an expired cat followed by a different cat target")
	var second_uid: int = game.targets[0].uid
	var result: Array = game.hit_speech_event(late)
	check(result.size() == 1 and result[0].uid == first_uid, "Delayed audio matches its historical target")
	check(game.targets.size() == 1 and game.targets[0].uid == second_uid, "A delayed result cannot remove a later same-word throw")
	check(game.hits == 1 and game.misses == 0 and game.missed_words.is_empty(), "An accepted late hit corrects its provisional miss")
	check(game.hit_speech_event(late).is_empty() and game.hits == 1, "Repeated event IDs never score twice")
	late.event_id = "competing-player"
	late.embedding = _voice(1)
	check(game.hit_speech_event(late).is_empty() and game.players_snapshot().size() == 1, "The same historical target cannot join or score for a second player")
	var at_expiry: Dictionary = _event(game, "boundary", "cat", _voice(1), 5600.0, 5700.0)
	check(game.hit_speech_event(at_expiry).is_empty(), "Speech exactly at a target's expiry has no valid target")
	check(_hit_next(game, "current", _voice(1)).size() == 1 and game.hits == 2, "Current speech can separately hit the new throw")
	var gap: Dictionary = _event(game, "between", "cat", _voice(2), 6000.0, 6100.0)
	check(game.hit_speech_event(gap).is_empty() and game.players_snapshot().size() == 2, "Speech between target lifetimes creates no player")


func _test_settling_and_deadline() -> void:
	var game = _game(["cat"])
	var pending: Dictionary = _event(game, "pending", "cat", _voice(0), 100.0, 200.0)
	game.advance(30.0)
	check(game.phase == "settling" and game.elapsed == 30.0 and game.targets.is_empty(), "Multiplayer closes live play at exactly 30 seconds and waits for captured audio")
	check(not game.start(), "A duplicate microphone callback cannot restart a settling round")
	game.advance(20.0)
	check(game.phase == "settling" and game.elapsed == 30.0, "Normal game time cannot extend or consume the settlement timeout")
	check(game.hit_speech_event(pending).size() == 1, "A valid pre-deadline recording may settle after the game ends")
	check(game.hit_speech_event(_event(game, "too-late", "cat", _voice(1), 30000.0, 30010.0)).is_empty(), "Post-deadline audio is ignored")
	game.finish_settling(-1.0)
	game.finish_settling(NAN)
	game.finish_settling(INF)
	check(game.phase == "settling", "Invalid timeout deltas cannot freeze results prematurely")
	game.finish_settling(2.99)
	check(game.phase == "settling", "Settlement leaves the complete three-second grace period")
	game.finish_settling(0.01)
	check(game.phase == "finished", "The leaderboard freezes after three seconds")
	check(game._round_profiles.is_empty() and game._target_history.is_empty(), "Finishing releases per-round voice evidence")
	var frozen: Dictionary = game.summary()
	check(game.hit_speech_event(pending).is_empty(), "A finished leaderboard rejects delayed callbacks")
	game.finish_settling(3.0)
	game.resume()
	check(game.summary() == frozen, "Repeated flush and resume callbacks preserve settled results")
	var flushed = _game()
	flushed.advance(30.0)
	flushed.finish_settling(3.0)
	check(flushed.phase == "finished", "A completed backend flush can immediately finish the settlement")


func _test_pause_and_ranking() -> void:
	var game = _game()
	_hit_next(game, "p1", _voice(0))
	_hit_next(game, "p2", _voice(1))
	var before: Dictionary = game.summary()
	game.pause()
	game.advance(100.0)
	check(game.summary() == before and game.phase == "paused", "Pause preserves identity, scores and active audio time")
	check(game.hit_speech_event(_event(game, "during-pause", "cat", _voice(2), 0.0, 100.0)).is_empty(), "Paused games reject speech events")
	game.resume()
	check(_hit_next(game, "p1-back", _voice(0))[0].player_id == "voice-0", "Resuming retains the original speaker references")
	_hit_next(game, "p3", _voice(2))
	_hit_next(game, "p2-tie", _voice(1))
	var ranked: Array = game.ranking()
	check(ranked[0].id == "voice-0" and ranked[1].id == "voice-1" and ranked[0].rank == 1 and ranked[1].rank == 1 and ranked[2].rank == 3, "Equal hits share ranks and first-hit order breaks display ties")
	game.stop()
	check(game.summary().ranking == ranked and game._round_profiles.is_empty(), "Stopping retains reviewable results while releasing voice evidence")


func _test_multiword_and_timestamp_order() -> void:
	var game = _game()
	game.advance(2.3)
	var text: String = ""
	for target in game.targets:
		text += target.word.text + " "
	var hits: Array = game.hit_speech_event(_event(game, "phrase", text, _voice(0), 2200.0, 2300.0))
	check(hits.size() == 2 and game.players_snapshot()[0].hits == 2 and game.score == 22, "A phrase may hit different targets once each for its single speaker")
	var early = _game(["cat"])
	var late = _game(["cat"])
	early.advance(0.2)
	early.hit_speech_event(_event(early, "early", "cat", _voice(0), 100.0, 200.0))
	# Explicitly compare chronological settlement over identical target history;
	# clearing a screen sooner legitimately changes the next-spawn schedule.
	late.advance(6.5)
	late.hit_speech_event(_event(late, "late", "cat", _voice(0), 100.0, 200.0))
	late.advance(0.1)
	late.hit_speech_event(_event(late, "second", "cat", _voice(0), 6500.0, 6600.0))
	check(late.hits == 2 and late.misses == 0 and late.best_combo == 2 and late.score == 22, "Late recognition reconstructs scores without leaving an expired-target combo break")


func _test_recognition_feedback() -> void:
	var game = _game(["sun"])
	game.advance(0.2)
	var uncertain: Dictionary = _event(game, "unknown-voice", "son", _voice(20))
	check(game.hit_speech_event(uncertain).is_empty() and game.recognition_feedback == "identity_unconfirmed"
		and game.players_snapshot().is_empty(), "A valid homophone with an unknown voice explains identity rejection without joining")
	var revision: int = game.recognition_revision
	uncertain.embedding = _voice(0)
	check(game.hit_speech_event(uncertain).is_empty() and game.recognition_revision == revision,
		"A repeated event cannot revise feedback or turn a rejected identity into a hit")
	game.hit_speech_event(_event(game, "no-word", "hello", _voice(20)))
	check(game.recognition_feedback == "no_matching_target" and game.players_snapshot().is_empty(),
		"Unavailable targets are classified before identity matching")
	var diagnosis: Dictionary = _event(game, "diagnosis", "son", [])
	diagnosis.erase("embedding")
	diagnosis.reason = "identity_unconfirmed"
	check(game.accept_speech_feedback(diagnosis) and game.recognition_feedback == "identity_unconfirmed" and game.hits == 0,
		"Terminal worker diagnostics can show recognized text without an embedding or scoring")
	revision = game.recognition_revision
	for change in [{"event_id": "diagnosis"}, {"event_id": "wrong-round", "round_id": "old"},
		{"event_id": "wrong-time", "start_ms": -1.0}, {"event_id": "future", "start_ms": 1000.0},
		{"event_id": "bad-text", "text": null}, {"event_id": "bad-reason", "reason": "invented"},
		{"event_id": "bad-end", "end_ms": INF}, {"event_id": 17}]:
		var invalid: Dictionary = diagnosis.duplicate(true)
		invalid.merge(change, true)
		check(not game.accept_speech_feedback(invalid) and game.recognition_revision == revision
			and game.recognition_feedback == "identity_unconfirmed", "Malformed, stale and duplicate feedback leaves the current caption intact")
	var malformed: Dictionary = _event(game, "bad-vector", "sun", [])
	check(game.hit_speech_event(malformed).is_empty() and game.recognition_revision == revision,
		"An invalid scoring event cannot replace the current feedback")
	var consumed: Dictionary = _event(game, "diagnosis", "sun", _voice(0))
	check(game.hit_speech_event(consumed).is_empty(), "A terminal diagnostic ID cannot be reused as a scoring event")
	var hit: Array = game.hit_speech_event(_event(game, "clear-voice", "son", _voice(0)))
	check(hit.size() == 1 and game.hits == 1 and game.recognition_feedback.is_empty()
		and game.recognition_message.is_empty(), "A registered voice scores the homophone once and clears rejection feedback")
	var late = _game(["sun"])
	late.advance(6.0)
	check(late.hit_speech_event(_event(late, "expired", "son", _voice(0), 5600.0, 5700.0)).is_empty()
		and late.recognition_feedback == "target_expired" and late.players_snapshot().is_empty(),
		"Speech beginning after a target expires explains the unavailable target without joining a player")
	check(late.hit_speech_event(_event(late, "historical", "son", _voice(0), 100.0, 200.0)).size() == 1
		and late.recognition_feedback.is_empty(), "Feedback never introduces grace: valid historical speech still scores its original target")
	var unclear: Dictionary = _event(late, "unclear", "", [])
	unclear.erase("embedding")
	unclear.reason = "unclear_speech"
	check(late.accept_speech_feedback(unclear) and late.recognition_feedback == "unclear_speech",
		"An empty local transcript can explain unclear speech without fabricating a score")
	late.pause()
	revision = late.recognition_revision
	check(late.recognition_feedback.is_empty(), "Pausing clears the previous recognition message")
	unclear.event_id = "paused"
	check(not late.accept_speech_feedback(unclear) and late.recognition_revision == revision, "Paused rounds reject diagnostic callbacks")
	late.resume()
	late.stop()
	revision = late.recognition_revision
	unclear.event_id = "finished"
	check(not late.accept_speech_feedback(unclear) and late.recognition_revision == revision, "Finished rounds keep their feedback frozen")

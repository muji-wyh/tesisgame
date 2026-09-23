extends SceneTree

const Model = preload("res://scripts/voice_pop_model.gd")
const VOICES: Array = [
	[1.0, 0.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0, 0.0],
	[0.0, 0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 0.0, 1.0, 0.0],
	[0.0, 0.0, 0.0, 0.0, 1.0]
]

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
	_test_normalization_and_centroid_protection()
	_test_bad_events()
	_test_historical_hits()
	_test_settling_and_deadline()
	_test_pause_and_ranking()
	_test_multiword_and_timestamp_order()
	print("Voice Pop multiplayer model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _game(ids: Array = ["cat", "dog", "apple", "horn"]) -> Variant:
	var game = Model.new()
	var words: Array = []
	for id in ids:
		words.append({"id": id, "text": id, "image": "image.png", "audio": "word.wav"})
	check(game.configure(words, 7), "Fixture configures illustrated vocabulary")
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


func _test_modes_and_round_identity() -> void:
	var game = _game()
	check(game.play_mode == "multi" and not game.round_id.is_empty(), "A live multiplayer round has a transport identity")
	check(not game.set_play_mode("single") and not game.start(), "Duplicate starts and mode changes cannot reset a live game")
	check(game.hit_transcript(game.targets[0].word.text).is_empty(), "The single-player transcript backend cannot score a multiplayer round")
	var first_round: String = game.round_id
	var saved: Dictionary = _event(game, "old", game.targets[0].word.text, VOICES[0], 0.0, 100.0)
	_hit_next(game, "first", VOICES[0])
	game.stop()
	check(game.start() and game.round_id != first_round, "Each new round gets a new ID")
	check(game.players_snapshot().is_empty() and game.hits == 0, "A new round clears players and their scores")
	game.advance(0.2)
	check(game.hit_speech_event(saved).is_empty(), "A callback carrying an old round ID cannot score")
	game.stop()
	check(game.set_play_mode("single") and not game.set_play_mode("unknown"), "The stopped game accepts only known modes")
	game.start()
	game.advance(0.2)
	check(game.hit_speech_event(_event(game, "wrong-backend", game.targets[0].word.text, VOICES[0])).is_empty(), "Local speech events cannot score a single-player round")
	check(game.hit_transcript(game.targets[0].word.text).size() == 1, "Switching back preserves the existing single-player recognizer")


func _test_joining_and_capacity() -> void:
	var game = _game()
	game.advance(0.2)
	check(game.hit_speech_event(_event(game, "chatter", "unrelated chatter", VOICES[4])).is_empty(), "Chatter cannot score")
	check(game.players_snapshot().is_empty() and game._embedding_size == 0, "No-hit speech does not allocate a voice or fix embedding dimensions")
	for index in range(4):
		var hits: Array = _hit_next(game, "join-%d" % index, VOICES[index])
		check(hits.size() == 1 and hits[0].player_id == "P%d" % (index + 1) and hits[0].player_index == index, "Distinct successful voice joins in P1–P4 order")
	check(game.players_snapshot().size() == 4 and game.hits == 4, "Exactly four successful players are registered")
	check(_hit_next(game, "fifth", VOICES[4]).is_empty() and game.players_snapshot().size() == 4 and game.hits == 4, "A clearly different fifth speaker is ignored")
	check(_hit_next(game, "p1-again", VOICES[0])[0].player_id == "P1", "Returning P1 keeps their original identity")
	var players: Array = game.players_snapshot()
	check(players[0].hits == 2 and players[1].hits == 1, "Each player owns only their successful targets")
	players[0].hits = 900
	check(game.players_snapshot()[0].hits == 2 and not game.players_snapshot()[0].has("centroid"), "UI snapshots do not expose or mutate voice references")
	var report: Dictionary = game.summary()
	check(report.play_mode == "multi" and report.round_id == game.round_id and report.players.size() == 4, "The summary carries mode, round, and personal results")
	check(report.ranking[0].id == "P1" and report.ranking[0].rank == 1 and report.ranking[1].rank == 2 and report.ranking[3].rank == 2, "Ranking uses hit count and assigns tied ranks")


func _test_normalization_and_centroid_protection() -> void:
	var game = _game()
	_hit_next(game, "original", [10.0, 0.0, 0.0, 0.0, 0.0])
	check(_hit_next(game, "quiet", [0.1, 0.0, 0.0, 0.0, 0.0])[0].player_id == "P1", "Cosine normalization is independent of vector magnitude")
	var before: Array = game._players[0].centroid.duplicate()
	var ambiguous: Array = [0.5, sqrt(0.75), 0.0, 0.0, 0.0]
	check(_hit_next(game, "ambiguous", ambiguous)[0].player_id == "P1" and game.players_snapshot().size() == 1, "An ambiguous voice goes to the nearest existing player")
	check(game._players[0].centroid == before, "Ambiguous speech cannot contaminate a player's voice centroid")
	_hit_next(game, "confident", [0.95, 0.1, 0.0, 0.0, 0.0])
	check(game._players[0].centroid != before, "A confident returning voice adapts its reference gradually")
	check(not game.configure_speaker_matching(0.2, 0.5), "Recognition thresholds cannot move mid-round")
	game.stop()
	check(game.configure_speaker_matching(0.25, 0.65), "A measured study may configure experimental thresholds between rounds")
	check(not game.configure_speaker_matching(NAN, 0.6) and not game.configure_speaker_matching(0.7, 0.6)
		and not game.configure_speaker_matching(-2.0, 0.6), "Invalid or inverted threshold configurations are rejected")


func _test_bad_events() -> void:
	var game = _game()
	game.advance(0.2)
	var template: Dictionary = _event(game, "bad", game.targets[0].word.text, VOICES[0])
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
	var late: Dictionary = _event(game, "late", "cat", VOICES[0], 100.0, 200.0)
	game.advance(6.5)
	check(game.misses == 1 and game.targets.size() == 1 and game.targets[0].uid != first_uid, "Fixture has an expired cat followed by a different cat target")
	var second_uid: int = game.targets[0].uid
	var result: Array = game.hit_speech_event(late)
	check(result.size() == 1 and result[0].uid == first_uid, "Delayed audio matches its historical target")
	check(game.targets.size() == 1 and game.targets[0].uid == second_uid, "A delayed result cannot remove a later same-word throw")
	check(game.hits == 1 and game.misses == 0 and game.missed_words.is_empty(), "An accepted late hit corrects its provisional miss")
	check(game.hit_speech_event(late).is_empty() and game.hits == 1, "Repeated event IDs never score twice")
	late.event_id = "competing-player"
	late.embedding = VOICES[1]
	check(game.hit_speech_event(late).is_empty() and game.players_snapshot().size() == 1, "The same historical target cannot join or score for a second player")
	var at_expiry: Dictionary = _event(game, "boundary", "cat", VOICES[1], 5600.0, 5700.0)
	check(game.hit_speech_event(at_expiry).is_empty(), "Speech exactly at a target's expiry has no valid target")
	check(_hit_next(game, "current", VOICES[1]).size() == 1 and game.hits == 2, "Current speech can separately hit the new throw")
	var gap: Dictionary = _event(game, "between", "cat", VOICES[2], 6000.0, 6100.0)
	check(game.hit_speech_event(gap).is_empty() and game.players_snapshot().size() == 2, "Speech between target lifetimes creates no player")


func _test_settling_and_deadline() -> void:
	var game = _game(["cat"])
	var pending: Dictionary = _event(game, "pending", "cat", VOICES[0], 100.0, 200.0)
	game.advance(30.0)
	check(game.phase == "settling" and game.elapsed == 30.0 and game.targets.is_empty(), "Multiplayer closes live play at exactly 30 seconds and waits for captured audio")
	check(not game.start(), "A duplicate microphone callback cannot restart a settling round")
	game.advance(20.0)
	check(game.phase == "settling" and game.elapsed == 30.0, "Normal game time cannot extend or consume the settlement timeout")
	check(game.hit_speech_event(pending).size() == 1, "A valid pre-deadline recording may settle after the game ends")
	check(game.hit_speech_event(_event(game, "too-late", "cat", VOICES[1], 30000.0, 30010.0)).is_empty(), "Post-deadline audio is ignored")
	game.finish_settling(-1.0)
	game.finish_settling(NAN)
	game.finish_settling(INF)
	check(game.phase == "settling", "Invalid timeout deltas cannot freeze results prematurely")
	game.finish_settling(2.99)
	check(game.phase == "settling", "Settlement leaves the complete three-second grace period")
	game.finish_settling(0.01)
	check(game.phase == "finished", "The leaderboard freezes after three seconds")
	check(not game._players[0].has("centroid") and game._target_history.is_empty(), "Finishing releases per-round voice evidence")
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
	_hit_next(game, "p1", VOICES[0])
	_hit_next(game, "p2", VOICES[1])
	var before: Dictionary = game.summary()
	game.pause()
	game.advance(100.0)
	check(game.summary() == before and game.phase == "paused", "Pause preserves identity, scores and active audio time")
	check(game.hit_speech_event(_event(game, "during-pause", "cat", VOICES[2], 0.0, 100.0)).is_empty(), "Paused games reject speech events")
	game.resume()
	check(_hit_next(game, "p1-back", VOICES[0])[0].player_id == "P1", "Resuming retains the original speaker references")
	_hit_next(game, "p3", VOICES[2])
	_hit_next(game, "p2-tie", VOICES[1])
	var ranked: Array = game.ranking()
	check(ranked[0].id == "P1" and ranked[1].id == "P2" and ranked[0].rank == 1 and ranked[1].rank == 1 and ranked[2].rank == 3, "Equal hits share ranks and enrollment order breaks display ties")
	game.stop()
	check(game.summary().ranking == ranked and not game._players[0].has("centroid"), "Stopping retains reviewable results while releasing voice evidence")


func _test_multiword_and_timestamp_order() -> void:
	var game = _game()
	game.advance(2.3)
	var text: String = ""
	for target in game.targets:
		text += target.word.text + " "
	var hits: Array = game.hit_speech_event(_event(game, "phrase", text, VOICES[0], 2200.0, 2300.0))
	check(hits.size() == 2 and game.players_snapshot()[0].hits == 2 and game.score == 22, "A phrase may hit different targets once each for its single speaker")
	var early = _game(["cat"])
	var late = _game(["cat"])
	early.advance(0.2)
	early.hit_speech_event(_event(early, "early", "cat", VOICES[0], 100.0, 200.0))
	# Explicitly compare chronological settlement over identical target history;
	# clearing a screen sooner legitimately changes the next-spawn schedule.
	late.advance(6.5)
	late.hit_speech_event(_event(late, "late", "cat", VOICES[0], 100.0, 200.0))
	late.advance(0.1)
	late.hit_speech_event(_event(late, "second", "cat", VOICES[0], 6500.0, 6600.0))
	check(late.hits == 2 and late.misses == 0 and late.best_combo == 2 and late.score == 22, "Late recognition reconstructs scores without leaving an expired-target combo break")

extends "res://tests/godot/professional_application_flow_tests.gd"
## Synthetic readiness exercises consumers; actual module/media gates stay closed.

const Content = preload("res://scripts/learning_content_resolver.gd")
const ActualCatalog = preload("res://scripts/professional_catalog.gd")
const Progress = preload("res://scripts/professional_progress.gd")
const Analysis = preload("res://scripts/morphology_analysis.gd")
const Composition = preload("res://scripts/morphology_resolver.gd")
const PopModel = preload("res://scripts/voice_pop_model.gd")
const Speech = preload("res://scripts/speech_words.gd")
const Sampler = preload("res://scripts/word_sampler.gd")
const REVISION := "professional-v2-foundation02-held-six-r01"
const ACTIVE := ["collect.bring-together.v", "inform.give-information.v", "ensure.make-certain.v"]
const RETIRED := ["collect.gather.v", "notify.inform.v", "verify.establish-accuracy.v"]
const GATHER := "expr.foundation.module02.08"
const FOCUSES := ["assist.help.v", "collect.bring-together.v", "return.send-back.v"]
const GATHER_TEXT := "Could you assist me while I collect one form from each team and return the borrowed key?"

class HeldCatalog extends RefCounted:
	var source: Dictionary
	func _init(value: Dictionary) -> void:
		source = value.duplicate(true)
	func load_index() -> bool:
		return true
	func courses() -> Array:
		return [{"id": "retail", "title": "Synthetic route fixture", "description": "Test-only readiness.", "theme_id": "professional_retail"}]
	func course(_id: String) -> Dictionary:
		return source.course.duplicate(true)
	func theme_profile(id: String) -> Dictionary:
		return {"id": id, "title": "Synthetic route fixture", "palette": {}, "art": {}}
	func resolve(context: Dictionary, seed_value: int = -1) -> Dictionary:
		var result: Dictionary = Content.resolve_professional(context, source.course, source.lexemes, source.expressions, seed_value)
		if not result.ok:
			return result
		# A three-expression round drawn from the ten-expression requirements.
		result.expressions = result.expressions.filter(func(row: Dictionary) -> bool:
			return row.id in [GATHER, "expr.foundation.module02.02", "expr.foundation.module02.04"])
		result.theme_profile = theme_profile(source.course.theme_id)
		result.media_manifest = {}
		result.required_resource_ids = ["sha256:" + IMAGE_HASH, "sha256:" + AUDIO_HASH]
		return result

var _lexemes: Dictionary = {}
var _expressions: Dictionary = {}
var _course: Dictionary = {}
var _module: Dictionary = {}


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	var lexical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/foundation-module02.json"))
	var expressions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/expressions/foundation-module02.json"))
	_course = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/courses/retail.json"))
	for entry: Dictionary in lexical.get("lexemes", []):
		_lexemes[entry.id] = entry
	for entry: Dictionary in expressions.get("expressions", []):
		_expressions[entry.id] = entry
	for candidate: Dictionary in _course.get("modules", []):
		if candidate.id == "module02":
			_module = candidate
	check(_lexemes.size() == 50 and _expressions.size() == 10 and _module.size() > 0,
		"The route suite reads the actual complete Foundation02 candidate")
	check(_course.get("curriculum_revision") == REVISION and ACTIVE.all(func(id: String) -> bool: return _lexemes.has(id)),
		"Run these proposed checks only against the coordinated held-six candidate")
	if failures > 0:
		_finish()
		return
	var actual_before: String = Progress.canonical([_lexemes, _expressions, _course])
	_actual_gates()
	_composition_and_variant()
	await _application_routes(_synthetic_ready_content())
	check(Progress.canonical([_lexemes, _expressions, _course]) == actual_before,
		"Synthetic readiness and answer fixtures never alter actual draft content")
	_finish()


func _finish() -> void:
	print("Professional held-six routes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _actual_gates() -> void:
	var catalog := ActualCatalog.new()
	check(catalog.load_index(), "The real catalog loads candidate metadata")
	for old_id: String in RETIRED:
		check(not _lexemes.has(old_id) and not _module.lexeme_ids.has(old_id), "Retired identity is absent from active content: " + old_id)
	for mode: String in ["match", "memory", "jelly", "pop", "word_jelly", "phrase"]:
		var context: Dictionary = Context.professional("retail", "module02", REVISION, mode)
		var direct: Dictionary = Content.resolve_professional(context, _course, _lexemes, _expressions, 42)
		var loaded: Dictionary = catalog.resolve(context, 42)
		check(not direct.ok and direct.code == "content_pending" and not loaded.ok and loaded.code == "content_pending",
			"Actual draft Foundation02 remains unavailable in " + mode)
	for id: String in ACTIVE + ["postpone.delay-until-later.v", "unsafe.presenting-danger.adj", "hazard.possible-harm.n"]:
		var entry: Dictionary = _lexemes[id]
		check(entry.review.language == "reviewed" and not Content._lexeme_ready(entry), "Language acceptance alone cannot admit " + id)
		for kind: String in ["image", "audio"]:
			check(entry.media[kind].status == "pending" and entry.media[kind].review.status == "pending"
				and entry.media[kind].path == null and not Content._media_ready(entry.media[kind]), "Missing reviewed media stays pending: " + id + "/" + kind)
	check(_lexemes["unsafe.presenting-danger.adj"].review.domain == "pending"
		and _lexemes["hazard.possible-harm.n"].review.domain == "pending", "Safety-language acceptance does not grant specialist approval")
	for id: String in [GATHER, "expr.foundation.module02.02", "expr.foundation.module02.04"]:
		check(not Content._expression_ready(_expressions[id]) and _expressions[id].media.audio.path == null,
			"Exact revised expression still needs its recording: " + id)


func _composition_and_variant() -> void:
	var resolver := Composition.new()
	var graphs: Array = ACTIVE.map(func(id: String) -> Dictionary: return _lexemes[id].morphology)
	check(resolver.configure(graphs), "The three independently reviewed graphs admit normally")
	for id: String in ACTIVE.slice(0, 2):
		var graph: Dictionary = _lexemes[id].morphology
		var tiles: Array = resolver.source_tiles(graph.id)
		check(Analysis.compile(graph).ok and tiles.size() == 1, "Atomic selected teaching base stays intact: " + id)
		if tiles.size() == 1:
			check(tiles[0].complete and tiles[0].lexeme_id == id and not tiles[0].composed and not tiles[0].mastery_eligible,
				"An intact source tile grants exposure rather than spelling mastery: " + id)
	var graph: Dictionary = _lexemes[ACTIVE[2]].morphology
	var pieces: Array = resolver.source_tiles(graph.id)
	check(Analysis.compile(graph).ok and pieces.size() == 2, "Canonical ensure uses exactly two authored parts")
	if pieces.size() == 2:
		check(pieces[0].canonical_id == "english.affix.en.causative" and pieces[0].text == "en"
			and pieces[1].canonical_id == "english.stem.sure.certain" and pieces[1].text == "sure", "Ensure retains the selected prefix and stem families")
		var completed: Dictionary = resolver.resolve(pieces[0], pieces[1])
		check(completed.status == "complete" and completed.tile.text == "ensure" and completed.tile.lexeme_id == ACTIVE[2]
			and completed.tile.mastery_eligible, "The canonical graph completes ensure under its fresh sense")
		check(resolver.resolve(pieces[1], pieces[0]).status == "invalid", "The reverse unauthored join cannot score")
	check(_lexemes[ACTIVE[2]].accepted_forms == ["ensure", "insure"], "The canonical graph preserves the independently accepted alternative")
	# This direct adapter fixture adds synthetic Pop capability. Actual ensure has
	# no accepted picture route; no new exercise or media approval is implied.
	var word: Dictionary = _lexemes[ACTIVE[2]].duplicate(true)
	word.track = "professional"
	word.practice_modes = ["pop"]
	word.image = "professional://held-six-fixture/image"
	word.audio = "professional://held-six-fixture/audio"
	check(Speech.word_forms(word, true) == ["ensure", "insure"], "Speech forms retain both outcome spellings")
	var pop := PopModel.new()
	var attempts: Array = []
	pop.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		attempts.append({"id": id, "ids": ids.duplicate(), "correct": correct}))
	check(pop.configure([word], 42) and pop.start(), "The synthetic adapter can present the selected outcome sense")
	for unrelated: String in ["verify", "assure", "insurance"]:
		check(pop.hit_transcript(unrelated).is_empty(), "Unaccepted answer cannot acquire the ensure sense: " + unrelated)
	var hits: Array = pop.hit_transcript("insure")
	check(hits.size() == 1 and hits[0].word.id == ACTIVE[2] and attempts.size() == 1
		and attempts[0].ids == [ACTIVE[2]] and attempts[0].correct, "Accepted insure scores exactly the fresh ensure sense")
	check(not _lexemes[ACTIVE[2]].practice_modes.has("pop") and not _lexemes[ACTIVE[2]].media.image.picture_suitable,
		"The adapter fixture leaves actual ensure picture and Pop eligibility unchanged")


func _fixture_media(kind: String) -> Dictionary:
	return {"status": "integrated", "path": "res://fixture/held-six/" + kind,
		"sha256": IMAGE_HASH if kind == "image" else AUDIO_HASH, "source": "synthetic-route-fixture",
		"creator": "synthetic-route-fixture", "license": "fixture-only", "review": {"status": "reviewed"}, "picture_suitable": true}


func _synthetic_ready_content() -> Dictionary:
	var words: Dictionary = _lexemes.duplicate(true)
	var expressions: Dictionary = _expressions.duplicate(true)
	for entry: Dictionary in words.values():
		entry.review = {"status": "reviewed", "language": "reviewed", "domain": "not_required"}
		entry.media = {"image": _fixture_media("image"), "audio": _fixture_media("audio")}
		if not ACTIVE.has(entry.id):
			# The other 47 entries supply test-only routes, not accepted analyses.
			entry.practice_modes = ["pop", "phrase", "word_jelly"]
			entry.morphology = {"schema": 1, "id": "fixture." + entry.id, "lexeme_id": entry.id, "text": entry.text,
				"kind": "atomic", "review": {"status": "reviewed"}, "nodes": [], "roots": ["whole"],
				"parts": [{"id": "whole", "canonical_id": "fixture." + entry.id, "type": "atomic",
					"canonical": entry.text, "surface": entry.text, "break_offsets": []}]}
	for entry: Dictionary in expressions.values():
		entry.review = {"status": "reviewed", "language": "reviewed", "domain": "not_required"}
		entry.media = {"audio": _fixture_media("audio")}
	var course: Dictionary = _course.duplicate(true)
	var module: Dictionary = _module.duplicate(true)
	module.status = "ready"
	course.modules = [module]
	return {"course": course, "lexemes": words, "expressions": expressions}


func _application_routes(fixture: Dictionary) -> void:
	directory = "user://professional-held-six-routes-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated application route storage")
	app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = Medal.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.reduced_motion = true
	app._presentation.save_preferences()
	app.professional.loader.media.free()
	app.professional.loader.media = MediaFixture.FixtureMedia.new()
	app.professional.loader.catalog = HeldCatalog.new(fixture)
	app.professional.loader._owner.free()
	app.professional.loader._owner = MediaFixture.FixtureOwner.new(app.professional.loader.catalog)
	app.professional.loader.media.cache.values["sha256:" + IMAGE_HASH] = load("res://assets/images/words/absent.png")
	app.professional.loader.media.cache.values["sha256:" + AUDIO_HASH] = load("res://assets/audio/jelly-match/collect-do.wav")
	root.add_child(app)
	await settle()
	var growth_before: Dictionary = app.growth.snapshot().duplicate(true)
	app._show_mode_menu()
	app._select_learning_context(Context.professional("retail", "module02", REVISION, "phrase"))
	app.choose_mode("phrase")
	var selection: int = app.professional.pending.get("selection", -1)
	var media_started := false
	for unused in range(120):
		await process_frame
		var preparation: Dictionary = app.professional.loader._preparation
		if preparation.get("selection") == selection and preparation.get("phase") == "media" \
			and preparation.get("media_generation", -1) == app.professional.loader.media.generation:
			media_started = true
			break
		if app.professional.phase == "failed":
			break
	check(media_started, "Synthetic readiness reaches the existing bounded media fixture")
	if media_started:
		app.professional.loader.media.finish(app.professional.loader.media.generation)
		await settle()
	check(app._round_context == Context.professional("retail", "module02", REVISION, "phrase")
		and app.professional.can_play(app._round_id), "A synthetic prepared round reaches the real application consumers")
	if app.professional.can_play(app._round_id):
		await _identity_consumers()
		await _gather_answer_route()
	check(app.growth.snapshot() == growth_before, "Professional route fixtures leave Growth progress unchanged")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file: String in DirAccess.get_files_at(directory):
		check(DirAccess.remove_absolute(directory.path_join(file)) == OK, "Remove only isolated route fixture files")
	check(DirAccess.remove_absolute(directory) == OK, "Remove isolated route fixture directory")


func _identity_consumers() -> void:
	var saved: Dictionary = app.professional.session._progress.duplicate(true)
	var state: Dictionary = Progress.empty_progress()
	var row: Dictionary = app._round_content.requirements
	var key: String = Progress.requirement_key(row)
	state.requirements[key] = Progress.requirement_fingerprint(row)
	for term: Dictionary in row.terms:
		if not ACTIVE.has(term.sense_id):
			state.skills[term.sense_id] = {str(term.skills[0]): {"earned": true, "streak": 3, "exposures": 3}}
	for id: String in RETIRED:
		state.skills[id] = {"context": {"earned": true, "streak": 3, "exposures": 3}}
	var original: Dictionary = state.duplicate(true)
	# In-memory display inputs only; the separate populated progress suite owns
	# persisted legacy events, retries, fingerprints, outbox and wallet parity.
	app.professional.session._progress = state
	app._refresh_growth()
	check(app._professional_progress_label.text == "47 / 50 learned", "Fifty old mastered identities leave the three fresh objectives unlearned")
	app._show_collection()
	await settle()
	var view = app._professional_library
	check(view.snapshot().configured and view.snapshot().term_count == 50, "The real library exposes all current module identities")
	for id: String in ACTIVE:
		var index: int = -1
		for candidate in range(view._words.size()):
			if view._words[candidate].id == id:
				index = candidate
		check(index >= 0, "The library contains the fresh sense: " + id)
		if index >= 0:
			view._select(index)
			check(view.snapshot().selected_id == id and view.snapshot().skills_text.contains("Context: 0 / 3")
				and not view.snapshot().skills_text.contains("Mastered"), "Old lexical history cannot master the new library entry: " + id)
			check(app._practice_weight(view._words[index]) == 1.0, "New sense retains full practice weight: " + id)
	check(app._practice_weight({"id": RETIRED[0], "track": "professional"}) == Sampler.MASTERED_WEIGHT,
		"The old history is present; absence of new mastery is not an empty-fixture accident")
	for old_id: String in RETIRED:
		check(not view._words.any(func(word: Dictionary) -> bool: return word.id == old_id), "Retired sense is not a library row: " + old_id)
	check(state == original, "Library and practice reads do not mutate the supplied old history")
	state.skills[ACTIVE[0]] = {"context": {"earned": true, "streak": 3, "exposures": 3}}
	state.skills[ACTIVE[2]] = {"spelling": {"earned": true, "streak": 3, "exposures": 3}, "context": {"earned": true, "streak": 3, "exposures": 3}}
	# An ineligible historical skill must not count as a learned module objective.
	state.skills[ACTIVE[1]] = {"spelling": {"earned": true, "streak": 3, "exposures": 3}}
	app._refresh_growth()
	view.set_progress(app.professional.session.snapshot())
	check(app._professional_progress_label.text == "49 / 50 learned", "Only active eligible mastery counts, and two mastered skills count one term")
	check(app._practice_weight({"id": ACTIVE[0], "track": "professional"}) == Sampler.MASTERED_WEIGHT
		and app._practice_weight({"id": ACTIVE[2], "track": "professional"}) == Sampler.MASTERED_WEIGHT,
		"Legitimate fresh canonical mastery reduces current practice weight")
	for index in range(view._words.size()):
		if view._words[index].id == ACTIVE[1]:
			view._select(index)
			check(view.snapshot().skills_text.contains("Spelling: Not assessed here")
				and view.snapshot().skills_text.contains("Context: 0 / 3"), "Atomic inform does not present spelling as an assessed skill")
	app._hide_collection()
	app.professional.session._progress = saved
	app._refresh_growth()


func _fill_gather(wrong_order: bool) -> void:
	var model = app._phrase.game
	model.clear()
	var positions: Array = range(model.current_question().tokens.size())
	if wrong_order:
		positions[0] = 1
		positions[1] = 0
	for position: int in positions:
		var token: Dictionary = model.current_question().tokens[position]
		var selected := -1
		for index in range(model.options.size()):
			if model.options[index].text == token.text and not model.answer.has(index):
				selected = index
				break
		check(selected >= 0 and model.select(selected), "Every gather token has its own selectable occurrence")
	app._phrase._refresh()


func _gather_answer_route() -> void:
	var model = app._phrase.game
	var chosen := false
	# Keep the real round content and token-bank construction, selecting a seed
	# with gather first so the test does not score unrelated expressions.
	for seed_value in range(64):
		if model.reset_professional(app._round_content.expressions, seed_value) and model.current_question().id == GATHER:
			chosen = true
			break
	check(chosen, "A bounded deterministic seed puts the exact gathering expression first")
	if not chosen:
		return
	app._phrase._refresh()
	var question: Dictionary = model.current_question()
	check(question.text == GATHER_TEXT and question.tokens.size() == 18 and question.focus_lexeme_ids == FOCUSES,
		"The actual Phrase view carries all eighteen authored tokens and the three selected senses")
	var token_ids: Dictionary = {}
	for index in range(question.tokens.size()):
		var token: Dictionary = question.tokens[index]
		token_ids[question.words[index]] = true
		check(token.index == index and question.text.substr(token.start, token.end - token.start) == token.text,
			"Gather preserves exact token offsets and punctuation")
	check(token_ids.size() == 18 and question.tokens.back().text == "?", "The question mark is a distinct final tile")
	var before: Dictionary = app.professional.session.snapshot().progress
	var sequence: int = before.sequence
	var signals: Array = []
	app._phrase.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		signals.append({"id": id, "ids": ids.duplicate(), "correct": correct}))
	_fill_gather(true)
	app._phrase.action_button.pressed.emit()
	await settle()
	check(model.feedback == "wrong" and signals.size() == 1 and signals[0].ids == FOCUSES and not signals[0].correct,
		"A complete wrong order emits one attributable attempt for exactly the three focus senses")
	check(app.professional.session.snapshot().progress.sequence == sequence + 3, "Wrong order records one context event per focus")
	_fill_gather(false)
	app._phrase.action_button.pressed.emit()
	await settle()
	var progress: Dictionary = app.professional.session.snapshot().progress
	check(model.feedback == "correct" and signals.size() == 2 and signals[1].ids == FOCUSES and signals[1].correct,
		"The corrected complete sentence emits the real successful phrase attempt")
	check(progress.sequence == sequence + 6, "The two answers produce exactly six canonical context events")
	for id: String in FOCUSES:
		# Earlier focus events reload through JSON; compare exact numeric values across int/float storage.
		check(Progress.canonical(progress.skills.get(id, {}).get("context", {})) == Progress.canonical({"streak": 1, "earned": false, "exposures": 2}),
			"One correction supplies fresh evidence without premature mastery: " + id)
	for id: String in RETIRED:
		check(progress.skills.get(id, {}) == before.skills.get(id, {}), "No phrase answer is routed into retired evidence: " + id)
	var key: String = Progress.requirement_key(app._round_content.requirements)
	check(progress.expressions.get(key, {}) == {GATHER: true}, "Only the current gathering expression becomes practised")
	check(progress.completions.is_empty(), "One practiced expression cannot complete the synthetic fifty-term module")
	for event: Dictionary in app.professional.session._events.values():
		var answer: Dictionary = event.event
		check(answer.context == app._round_context and answer.skill == "context" and answer.expression_id == GATHER
			and FOCUSES.has(answer.sense_id) and not answer.assisted and not answer.atomic, "The actual UI submission preserves focus, current revision and assessment kind")

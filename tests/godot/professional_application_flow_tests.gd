extends SceneTree
## Synthetic reviewed fixtures exercise routing; their art is not curriculum art.

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const MediaFixture = preload("res://tests/godot/professional_round_loader_tests.gd")
const Context = preload("res://scripts/learning_context.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const Medal = preload("res://scripts/medal_progress.gd")
const IMAGE_HASH = MediaFixture.IMAGE_HASH
const AUDIO_HASH = MediaFixture.AUDIO_HASH

class Catalog extends RefCounted:
	var reject := false
	func load_index() -> bool: return true
	func courses() -> Array: return [{"id": "retail", "title": "Fixture Retail", "description": "Fixture workplace.", "theme_id": "professional_retail"}, {"id": "nursing", "title": "Fixture Nursing", "description": "Fixture care.", "theme_id": "professional_nursing"}]
	func course(id: String) -> Dictionary:
		return {"id": id, "title": "Fixture " + id, "curriculum_revision": "v1", "theme_id": "professional_" + id,
			"modules": [{"id": "module03", "title": "Fixture equipment", "status": "ready"}]}
	func theme_profile(id: String) -> Dictionary:
		var palette: Dictionary = {}
		if id == "professional_retail":
			palette = {"accent": "#8c4e34", "background": "#f4ece6", "light": "#f4d9c6", "spark": "#b27650"}
		elif id == "professional_nursing":
			palette = {"accent": "#376a80", "background": "#e8f2f4", "light": "#d1e8ee", "spark": "#6ba2b6"}
		return {"id": id, "title": "Fixture workplace", "palette": palette, "art": {},
			"rewards": {"legacy_theme_id": "spring"}}
	func resolve(context: Dictionary, _seed: int = -1) -> Dictionary:
		if reject:
			return {"ok": false, "error": "Injected unavailable curriculum."}
		var words: Array = []
		var terms: Array = []
		var expressions: Array = []
		var expression_ids: Array = []
		for index in range(50):
			var id: String = "fixture.sense.%d" % index
			var label: String = ["MRI", "USB-C", "invoice", "nurse", "colleague"][index] if index < 5 else "fixture%d" % index
			words.append({"id": id, "text": label, "display_text": label, "track": "professional", "pos": "noun",
				"definition": "An application fixture meaning for " + label + ".", "example": "This is a test fixture.",
				"practice_modes": ["match", "memory", "pop", "phrase", "jelly", "word_jelly"], "accepted_forms": [label],
				"image": "", "audio": "", "media": {"image": {"sha256": IMAGE_HASH}, "audio": {"sha256": AUDIO_HASH}},
				"morphology": {"schema": 1, "id": "fixture.analysis.%d" % index, "lexeme_id": id, "text": label,
					"kind": "atomic", "review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
					"parts": [{"id": "whole", "canonical_id": id, "type": "atomic", "canonical": label, "surface": label}], "nodes": [], "roots": ["whole"]}})
			terms.append({"sense_id": id, "skills": ["recognition", "speaking", "context", "spelling"]})
		for index in range(10):
			var label: String = "Check the invoice."
			var tokens: Array = []
			var offset := 0
			for token in label.split(" "):
				tokens.append({"index": tokens.size(), "text": token, "start": offset, "end": offset + token.length()})
				offset += token.length() + 1
			var id: String = "fixture.expression.%d" % index
			expression_ids.append(id)
			expressions.append({"id": id, "text": label, "tokens": tokens, "focus_lexeme_ids": ["fixture.sense.2"],
				"media": {"audio": {"sha256": AUDIO_HASH}}})
		return {"ok": true, "context": context.duplicate(), "words": words, "module_words": words.duplicate(true), "expressions": expressions,
			"course_title": "Fixture " + context.course_id, "module_title": "Fixture module",
			"theme_id": "professional_" + context.course_id, "theme_profile": theme_profile("professional_" + context.course_id),
			"media_manifest": {}, "required_resource_ids": ["sha256:" + IMAGE_HASH, "sha256:" + AUDIO_HASH],
			"requirements": {"course_id": context.course_id, "module_id": context.module_id, "curriculum_revision": context.curriculum_revision,
				"requirements_revision": "v1", "terms": terms, "expressions": expression_ids}}

var checks := 0
var failures := 0
var app
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for unused in range(120):
		await process_frame
		if not is_instance_valid(app):
			return
		if unused >= 3 and app.professional.session.snapshot().blocked:
			return
		if unused >= 3 and not app._vocabulary_booting and app.professional.session.snapshot().pending_count == 0 \
			and app.professional.phase not in ["media", "storage", "restoring", "ready"]:
			return
	check(false, "Application reaches a terminal preparation/storage state within bounded frames")


func start_course(course: String, mode: String, fresh_round: bool = false) -> void:
	app._show_mode_menu()
	app._select_learning_context(Context.professional(course, "module03", "v1", mode))
	if fresh_round:
		app.new_round(-1, false, "", mode, "", false)
	else:
		app.choose_mode(mode)
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
	check(media_started, "Asynchronous policy reaches the exact selected media request before fixture completion")
	if media_started:
		app.professional.loader.media.finish(app.professional.loader.media.generation)
	await settle()


func check_course_palette(course: String, stage: String) -> void:
	var expected: Dictionary = app.professional.loader.catalog.theme_profile("professional_" + course).palette
	check(not expected.is_empty() and app.model.theme_id == "spring", stage + ": course colors override a shared legacy reward theme")
	for target: Dictionary in [
		{"name": "application", "palette": app._active_palette},
		{"name": "Memory", "palette": app._memory._palette},
		{"name": "Phrase", "palette": app._phrase._palette},
		{"name": "Jelly", "palette": app._jelly._theme},
		{"name": "Word Jelly", "palette": app._word_jelly._theme}]:
		var matches := true
		for key: String in expected:
			matches = matches and target.palette.get(key) == Color(str(expected[key]))
		check(matches, stage + ": " + target.name + " retains the selected course palette")
	var accent := Color(str(expected.accent))
	if app._mode_id == "match":
		check(app.cards.size() == 10, stage + ": actual Match cards exist for color verification")
		for card in app.cards.values():
			check(card.accent == accent, stage + ": Match card renders the course accent")
	if app._mode_id == "memory":
		check(app._memory.card_buttons.size() == 10, stage + ": actual Memory cards exist for color verification")
		for card in app._memory.card_buttons:
			check(card.accent == accent and card._back.accent == accent, stage + ": Memory face and back render the course accent")
	if app._mode_id == "phrase":
		check(app._phrase.pip.accent == accent, stage + ": Phrase mascot renders the course accent")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	directory = "user://professional-application-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Application uses isolated progress")
	app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = Medal.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.save_preferences()
	app.professional.loader.media.free()
	app.professional.loader.media = MediaFixture.FixtureMedia.new()
	app.professional.loader.catalog = Catalog.new()
	app.professional.loader._owner.free()
	app.professional.loader._owner = MediaFixture.FixtureOwner.new(app.professional.loader.catalog)
	app.professional.loader.media.cache.values["sha256:" + IMAGE_HASH] = load("res://assets/images/words/absent.png")
	app.professional.loader.media.cache.values["sha256:" + AUDIO_HASH] = load("res://assets/audio/jelly-match/collect-do.wav")
	root.add_child(app)
	await settle()
	var growth_before: Dictionary = app.growth.snapshot()
	app.growth.ready = false
	await start_course("nursing", "memory")
	check(app._round_context == Context.professional("nursing", "module03", "v1", "memory"), "Nursing starts with its distinct course theme")
	check_course_palette("nursing", "Nursing Memory entry")
	app._memory.start_button.pressed.emit()
	check(app._memory.memory.studying and app._professional_assisted.is_empty(), "Required Memory observation does not mark professional practice as assisted")
	app._memory_peek_countdown.action_button.pressed.emit()
	check(app.coin_wallet.credit("fixture:professional-memory-peek", 2).ok, "Fund an optional professional Memory observation")
	app._memory.study_button.pressed.emit()
	check(app._memory.memory.studying and app._professional_assisted.size() == 5, "A purchased observation still records assisted professional practice")
	app._memory.end_peek()
	var previous_path: String = app._round_content.words[0].image
	for mode in ["match", "memory", "phrase", "pop", "jelly", "word_jelly"]:
		await start_course("retail", mode)
		if app._round_context != Context.professional("retail", "module03", "v1", mode):
			printerr("Preparation failed for %s: %s" % [mode, str(app.professional.snapshot())])
			quit(1)
			return
		check(app._round_context == Context.professional("retail", "module03", "v1", mode), "Home starts a frozen professional %s round" % mode)
		check(app._mode_id == mode and not app._mode_menu_open(), "Prepared %s enters its actual view" % mode)
		check(app.professional.can_play(app._round_id), "Professional %s starts only after saved context is ready" % mode)
		check_course_palette("retail", "Retail %s entry" % mode)
		check(not app._message.is_visible_in_tree(), "Unavailable Growth storage does not obscure the independent professional %s game" % mode)
		check(app.model.cards.size() == (10 if mode in ["match", "memory"] else 0), "No phantom Match lesson for %s" % mode)
		check(app._growth_button.is_visible_in_tree() and not app._professional_button.is_visible_in_tree(), "Professional %s header retains the shared Pip progress badge" % mode)
		app._show_collection()
		await settle()
		var library: Dictionary = app._professional_library.snapshot()
		check(library.configured and library.term_count == 50 and library.visible_rows == 8, "Professional %s word library pages the entire module" % mode)
		check(not app._age_catalog.is_visible_in_tree() and library.image_count == 1, "Professional %s library owns only its selected image and no Growth catalog" % mode)
		app._hide_collection()
		check(app._professional_library.snapshot().image_count == 0 and app._round_context.mode == mode, "Closing the professional library releases its picture and preserves the frozen game")
		if not previous_path.is_empty():
			check(Access.resource(previous_path) == null, "Replacing %s releases the prior media scope" % mode)
		var first_round: String = app._round_id
		var first_path: String = app._round_content.words[0].image
		await start_course("retail", mode, true)
		check(app._round_id != first_round and app._round_context == Context.professional("retail", "module03", "v1", mode)
			and app.professional.can_play(app._round_id) and not app._mode_menu_open(), "Same-theme %s starts a fresh playable round instead of resuming" % mode)
		check_course_palette("retail", "Retail %s same-theme fresh round" % mode)
		check(Access.resource(first_path) == null, "Fresh %s round releases its replaced media scope" % mode)
		previous_path = app._round_content.words[0].image
	check(app._word_jelly.game.uses_authored_morphology(), "Actual professional Jelly view uses authored morphology")
	var round_id: String = app._round_id
	var generation: int = app._word_jelly.game._generation
	var word: Dictionary = app._round_content.words[0]
	check(not str(word.image).is_empty(), "The pictured fixture requires a word-and-picture merge")
	var payload: Dictionary = {"event_id": "fixture-collection", "generation": generation, "word": word, "coins": 0,
		"a": {"assisted": false}}
	var collection_commit: Dictionary = app._commit_professional_collection(payload)
	check(collection_commit.get("pending", false), "Even zero-coin picture collection waits for durable evidence: " + str(collection_commit))
	await settle()
	var evidence: Dictionary = app.professional.session.snapshot().progress.skills.get(word.id, {}).get("spelling", {})
	check(evidence.get("exposures", 0) == 1 and not evidence.get("earned", false) and evidence.get("streak", 0) == 1,
		"An unassisted word-and-picture collection advances spelling mastery")
	check(app._commit_professional_collection(payload).get("ok", false), "Collection retry reuses its permanent answer receipt")
	await settle()
	check(app.professional.session.snapshot().progress.skills.get(word.id, {}).get("spelling", {}).get("exposures", 0) == 1,
		"Retry cannot duplicate exposure")
	app._record_growth("picture-invalid-merge", [word.id], false)
	await settle()
	check(app.professional.can_play(round_id), "An invalid word-and-picture merge keeps the round playable")
	var after_mistake: Dictionary = app.professional.session.snapshot().progress.skills.get(word.id, {}).get("spelling", {})
	check(after_mistake.get("exposures", 0) == 2 and after_mistake.get("streak", -1) == 0,
		"An invalid pictured-word merge resets the current spelling streak")
	app._show_mode_menu()
	app._select_learning_context(Context.professional("nursing", "module03", "v1", "word_jelly"))
	app.choose_mode("word_jelly")
	check(app._round_id == round_id and app._round_context.course_id == "retail", "Choosing the same mode in another career does not resume the old course")
	app._cancel_professional()
	await settle()
	check(app.professional.can_play(round_id) and Access.resource(previous_path) != null, "Cancelled replacement safely restores the original context and media")
	app.professional.loader.catalog.reject = true
	app.choose_mode("word_jelly")
	await settle()
	check(app.professional.phase == "failed" and app._round_id == round_id, "Missing curriculum retains the playable round and exposes failure")
	app._cancel_professional()
	app.professional.loader.catalog.reject = false
	await settle()
	await start_course("retail", "match")
	var sense: String = app.model.lesson_words[0].id
	app._professional_assisted[sense] = true
	app._record_growth("assisted-fixture", [sense], true)
	await settle()
	check(app.professional.session.snapshot().progress.skills[sense].recognition.streak == 0, "Assisted answer does not advance professional mastery")
	app._professional_assisted.clear()
	for index in range(3):
		app._record_growth("correct-%d" % index, [sense], true)
	await settle()
	check(app.professional.session.snapshot().progress.skills[sense].recognition.earned, "Three unassisted answers establish professional skill mastery")
	app.professional.store.before_commit = func(operation: String) -> bool: return operation != "record"
	app._record_growth("failed-wrong", [sense], false)
	await settle()
	check(app.professional.phase == "failed" and app._professional_input_blocked(), "Storage failure freezes professional input with an explicit error")
	var selection_before: String = app.model.selected_id
	app._select_card(app.model.cards[0].id)
	check(app.model.selected_id == selection_before, "A tap cannot add another answer while saving has failed")
	check(app.professional.session.snapshot().progress.skills[sense].recognition.earned, "Failure never displays a fabricated empty profile")
	app.professional.store.before_commit = Callable()
	app._retry_professional()
	await settle()
	check(app.professional.can_play(app._round_id), "Retry completes the original event before unlocking the round")
	check(app.professional.session.snapshot().progress.skills[sense].recognition.streak == 0 \
		and app.professional.session.snapshot().progress.skills[sense].recognition.earned,
		"Retried wrong answer resets the current streak without revoking earned mastery")
	var old_cards: Array = app.cards.keys()
	var old_source: String = app._round_id
	var old_path: String = app._round_content.words[0].image
	check(not app.new_round(-1, false, "", "match", "", false, app._round_content, "obsolete-source"),
		"Claim preflight rejects an obsolete source before destructive view teardown")
	check(app.cards.keys() == old_cards and app._round_id == old_source and Access.resource(old_path) != null,
		"Rejected claim preserves the current controls, source and claimed lease")
	# Retire after Play starts a real Session open, before its deferred storage
	# pump can finish. Existing claimed views and accepted progress must survive.
	var retired: Array = [false]
	app.professional.loader.prepared.connect(func(_selection: int, _content: Dictionary) -> void:
		if not retired[0]:
			retired[0] = true
			app.professional.loader._owner.retire())
	await start_course("nursing", "match")
	check(retired[0] and app.professional.pending.is_empty() and app._round_id == old_source,
		"Owner retirement during real storage opening never installs the replacement view")
	check(app.professional.can_play(old_source) and Access.resource(old_path) != null,
		"Retirement restores the previous session while preserving its media lease")
	app.growth.ready = true
	check(app.growth.snapshot() == growth_before, "All six professional games and evidence leave Growth untouched")
	app._show_mode_menu()
	app._select_learning_context(Context.growth(3, "match"))
	app.choose_mode("match")
	await settle()
	check(app._round_context.track == "growth" and app.professional.active.is_empty(), "Growth selection restores Growth content and releases professional ownership")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Professional application flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

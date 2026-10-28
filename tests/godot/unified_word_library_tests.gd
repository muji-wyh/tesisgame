extends SceneTree
## Reviewed synthetic content verifies routing without downloading career media.

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const ApplicationFixture = preload("res://tests/godot/professional_application_flow_tests.gd")
const MediaFixture = preload("res://tests/godot/professional_round_loader_tests.gd")
const PipProgress = preload("res://scripts/professional_pip_progress.gd")
const Progress = preload("res://scripts/professional_progress.gd")
const Context = preload("res://scripts/learning_context.gd")
const Medal = preload("res://scripts/medal_progress.gd")


class CareerCatalog extends ApplicationFixture.Catalog:
	func course(id: String) -> Dictionary:
		var value: Dictionary = super.course(id)
		var ids: Array = []
		var expressions: Array = []
		for index in range(50):
			ids.append(id + ".fixture.sense.%d" % index)
		for index in range(10):
			expressions.append("fixture.expression.%d" % index)
		value.modules[0].merge({"lexeme_ids": ids, "expression_ids": expressions, "requirements_revision": "v1"})
		value.modules.append({"id": "module04", "title": "Preparing next module", "status": "draft",
			"requirements_revision": "v1", "lexeme_ids": ids, "expression_ids": expressions})
		return value

	func resolve(context: Dictionary, seed_value: int = -1) -> Dictionary:
		var result: Dictionary = super.resolve(context, seed_value)
		if not result.get("ok", false):
			return result
		for word: Dictionary in result.words:
			word.id = str(context.course_id) + "." + str(word.id)
			word.morphology.lexeme_id = word.id
			word.morphology.parts[0].canonical_id = word.id
		result.module_words = result.words.duplicate(true)
		for term: Dictionary in result.requirements.terms:
			term.sense_id = str(context.course_id) + "." + str(term.sense_id)
		for expression: Dictionary in result.expressions:
			for index in range(expression.focus_lexeme_ids.size()):
				expression.focus_lexeme_ids[index] = str(context.course_id) + "." + str(expression.focus_lexeme_ids[index])
		return result


var checks: int = 0
var failures: int = 0
var app
var directory: String


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(150):
		await process_frame
		if not is_instance_valid(app):
			return
		if frame >= 5 and not app._vocabulary_booting and app.professional.session.snapshot().pending_count == 0 \
			and app.professional.phase not in ["media", "storage", "restoring", "ready"]:
			return
	check(false, "The library operation settles within bounded frames")


func _press(name: String) -> void:
	var button: BaseButton = app.find_child(name, true, false) as BaseButton
	check(button != null and button.is_visible_in_tree() and not button.disabled, name + " is an available player control")
	if button != null and button.is_visible_in_tree() and not button.disabled:
		button.pressed.emit()
	await _settle()


func _make_app() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = Medal.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.load_preferences(true)
	app._presentation.muted = true
	app._presentation.save_preferences()
	app.professional.loader.media.free()
	app.professional.loader.media = MediaFixture.FixtureMedia.new()
	app.professional.loader.catalog = CareerCatalog.new()
	app.professional.loader._owner.free()
	app.professional.loader._owner = MediaFixture.FixtureOwner.new(app.professional.loader.catalog)
	app.professional.loader.media.cache.values["sha256:" + MediaFixture.IMAGE_HASH] = load("res://assets/images/words/absent.png")
	app.professional.loader.media.cache.values["sha256:" + MediaFixture.AUDIO_HASH] = load("res://assets/audio/jelly-match/collect-do.wav")
	root.add_child(app)
	await _settle()


func _open_professional() -> void:
	if not app._mode_menu_open():
		app._show_mode_menu()
		await _settle()
	await _press("HomeCollection")
	await _press("LibraryProfessional")
	check(app.collection_page.visible and app.collection_page.is_ancestor_of(app._mode_panel.learning), "Career choices belong to the Word Library")
	check(not app._mode_panel.learning._paths.is_visible_in_tree(), "The Word Library does not offer a second app-level path picker")


func _browse_course(course: String, module: String = "module03") -> void:
	var choice: BaseButton = app.find_child("Career_" + course, true, false) as BaseButton
	if choice == null or not choice.is_visible_in_tree():
		await _press("ChangeCareer")
	await _press("Career_" + course)
	await _press("Module_" + module)


func _use_course(course: String) -> void:
	await _open_professional()
	await _browse_course(course)
	await _press("ContinueLearningPath")
	check(app._mode_menu_open() and not app.collection_page.visible, "Using a career vocabulary returns to the shared Home")
	check(app._home_context.get("course_id") == course, "The selected career becomes Home's vocabulary")


func _start_professional_match() -> void:
	app.choose_mode("match")
	var started: bool = false
	for frame in range(150):
		await process_frame
		var preparation: Dictionary = app.professional.loader._preparation
		if preparation.get("phase") == "media" and preparation.get("media_generation", -1) == app.professional.loader.media.generation:
			started = true
			app.professional.loader.media.finish(app.professional.loader.media.generation)
			break
		if app.professional.phase == "failed":
			break
	check(started, "Choosing a game starts the selected career's guarded media preparation")
	await _settle()
	check(not app._mode_menu_open() and app._round_context.track == "professional" and app.professional.can_play(app._round_id), "The selected career enters a playable round")


func _learn_terms(count: int, prefix: String) -> void:
	for index in range(count):
		var id: String = str(app.model.lesson_words[index].id)
		for answer in range(3):
			app._record_growth("%s-%d-%d" % [prefix, index, answer], [id], true)
	await _settle()


func _check_home(course: String, level: int) -> void:
	var home: Dictionary = app._mode_panel.snapshot()
	check(home.brand == "Pip's world" and home.vocabulary.kind == "professional", "Professional vocabulary retains the shared Pip's world identity")
	check(home.vocabulary.selection.course_id == course and home.vocabulary.title == "Playing professional English", "Home explicitly identifies the active professional vocabulary")
	check(home.professional.ready and home.professional.course_id == course and home.professional.level == level, "Home shows this career's independently derived Pip level")
	check(home.hero.title == "Pip · Lv%d" % level and home.hero.goal == home.professional.course_title, "The shared hero pairs Pip's level with the career title")
	check(app._mode_panel.pip.professional_profile.get("course_id") == course and app._mode_panel.pip.professional_profile.get("level") == level, "The Home mascot uses this career's artwork and level")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	directory = "user://unified-library-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Use isolated learning and preference saves")
	await _make_app()
	app.choose_mode("match")
	await _settle()
	await _learn_terms(1, "everyday")
	var growth_before: Dictionary = app.growth.snapshot()
	var daily_round: String = app._round_id
	var daily_cards: Array = app.cards.keys()
	app._show_mode_menu()
	await _settle()
	var selected_before: Dictionary = app._home_context.duplicate(true)
	var professional_before: String = Progress.canonical(app.professional.session.snapshot().progress)
	await _open_professional()
	await _browse_course("nursing")
	check(app._home_context == selected_before and app._round_id == daily_round, "Browsing a different career does not apply it or replace the unfinished round")
	await _press("GrowthBack")
	check(app._home_context == selected_before and app._mode_menu_open(), "Back from the library preserves the active vocabulary")
	await _open_professional()
	await _browse_course("retail", "module04")
	check(app._mode_panel.learning.snapshot().continue_enabled and app._mode_panel.learning._continue.visible, "A preparing module can be selected as vocabulary without unlocking its games")
	check(app._home_context == selected_before, "Inspecting a preparing module does not change the active vocabulary")
	await _press("ContinueLearningPath")
	_check_home("retail", 0)
	check(app._mode_panel.buttons.all(func(button: Button) -> bool: return button.disabled), "A selected preparing module keeps every game unavailable")
	check(app._round_id == daily_round and app.professional.loader.media.request_count == 0, "Selecting preparing vocabulary preserves the round and requests no professional media")
	await _open_professional()
	await _browse_course("retail")
	check(app._mode_panel.learning._continue.text == "Use this vocabulary", "The available module explains the vocabulary selection action")
	await _press("ContinueLearningPath")
	_check_home("retail", 0)
	check(app._round_id == daily_round and app.cards.keys() == daily_cards, "Applying a vocabulary keeps the unfinished game's exact board until a new game is chosen")
	check(app.professional.loader.media.request_count == 0 and app.professional.active.is_empty(), "Browsing and applying vocabulary do not acquire professional media or start a round")
	check(Progress.canonical(app.professional.session.snapshot().progress) == professional_before and app.growth.snapshot() == growth_before, "Vocabulary selection does not change either learning history")
	await _press("ContinueCurrentRound")
	check(app._round_id == daily_round and app._round_context.track == "growth" and not app._mode_menu_open(), "The preserved everyday round remains resumable")
	await _use_course("retail")
	await _start_professional_match()
	await _learn_terms(1, "retail")
	check(app._growth_button.is_visible_in_tree() and not app._professional_button.is_visible_in_tree(), "Professional gameplay uses the same Pip progress badge")
	check(app._growth_button.level_label.text == "Lv1" and app.duck.professional_profile.get("course_id") == "retail", "The gameplay badge and companion show the active career's earned level and appearance")
	app._show_mode_menu()
	await _settle()
	_check_home("retail", 1)
	var retail_round: String = app._round_id
	await _use_course("nursing")
	_check_home("nursing", 0)
	check(app._round_id == retail_round and app._round_context.course_id == "retail", "Switching career selection retains the unfinished Retail round")
	await _start_professional_match()
	await _learn_terms(3, "nursing")
	app._show_mode_menu()
	await _settle()
	_check_home("nursing", 2)
	var nursing_round: String = app._round_id
	await _use_course("retail")
	_check_home("retail", 1)
	check(app._round_id == nursing_round and app._round_context.course_id == "nursing", "Returning to Retail restores its level without discarding the Nursing round")
	await _press("HomeCollection")
	await _press("LibraryEveryday")
	await _press("PlayEverydayVocabulary")
	var home: Dictionary = app._mode_panel.snapshot()
	check(home.vocabulary.kind == "everyday" and app._home_context.track == "growth" and app._mode_menu_open(), "Everyday vocabulary is selected through the same Word Library")
	check(app._mode_panel.pip.professional_profile.is_empty() and app._mode_panel.pip.growth_age == growth_before.age \
		and app._mode_panel._growth.level == growth_before.level, "Everyday selection restores the original Pip appearance and level")
	check(app.growth.snapshot() == growth_before and app._round_id == nursing_round, "Career play and switching never overwrite everyday mastery or the unfinished round")
	await _open_professional()
	await _browse_course("retail", "module04")
	await _press("ContinueLearningPath")
	var selected_vocabulary: Dictionary = app._home_context.duplicate(true)
	check(selected_vocabulary.course_id == "retail" and selected_vocabulary.module_id == "module04", "A preparing vocabulary can become the saved Home selection")
	var durable: Dictionary = app.professional.session.snapshot().progress.duplicate(true)
	app.audio.halt()
	app.queue_free()
	await process_frame
	await process_frame
	await _make_app()
	check(Progress.canonical(app.professional.session.snapshot().progress) == Progress.canonical(durable), "Reloading preserves career mastery without JSON number or key-type differences")
	check(app.growth.snapshot() == growth_before, "Reloading preserves everyday progress")
	check(app._home_context == selected_vocabulary and app._mode_menu_open(), "Reloading restores the preparing career vocabulary and module on Home")
	_check_home("retail", 1)
	check(app._mode_panel.buttons.all(func(button: Button) -> bool: return button.disabled), "Restoring preparing vocabulary does not unlock unready games")
	check(app.professional.loader.media.request_count == 0 and app.professional.active.is_empty(), "Restoring the saved vocabulary does not start a game or download career media")
	await _use_course("retail")
	_check_home("retail", 1)
	await _use_course("nursing")
	_check_home("nursing", 2)
	app.audio.halt()
	app.queue_free()
	await process_frame
	await process_frame
	for file in DirAccess.get_files_at(directory):
		check(DirAccess.remove_absolute(directory.path_join(file)) == OK, "Remove an isolated test save")
	check(DirAccess.remove_absolute(directory) == OK, "Remove the isolated test directory")
	print("Unified word library: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

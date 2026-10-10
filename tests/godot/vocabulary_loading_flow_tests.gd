extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Loader = preload("res://scripts/vocabulary_loader.gd")
const Progress = preload("res://scripts/medal_progress.gd")
const Growth = preload("res://scripts/growth_state.gd")

var checks: int = 0
var failures: int = 0
var directories: Array[String] = []


class DownloadHost extends RefCounted:
	var requests: Array[int] = []
	var callbacks: Dictionary = {}

	func requestVocabulary(age: int, callback: Callable) -> void:
		requests.append(age)
		callbacks[age] = callback

	func reply(age: int, state: String, progress: float = 0.0) -> void:
		assert(callbacks.has(age), "The fixture only completes a requested age.")
		var payload := {"age": age, "state": state, "progress": progress,
			"path": "/vocabulary-%d-0123456789abcdef.pck" % age,
			"error": "The connection was interrupted. Please try again." if state == "failed" else ""}
		callbacks[age].call([JSON.stringify(payload)])


class DelayedLoader extends Loader:
	var downloads := DownloadHost.new()

	func configure(_host_override: Object = null, _mount_override: Callable = Callable()) -> void:
		super.configure(downloads, func(_path: String, replace: bool) -> bool:
			assert(not replace, "Age packs must not replace shared resources.")
			return true)


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func make_app(earned_age_three: bool = false):
	var directory := "user://vocabulary-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Vocabulary flow uses isolated saves")
	directories.append(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	check(app._presentation.save_preferences(), "The loading fixture starts muted")
	app.vocabulary_loader.free()
	app.vocabulary_loader = DelayedLoader.new()
	if earned_age_three:
		check(app.data.load_all() and app.growth.configure(app.data.words) and app.growth.load_state(),
			"A returning learner fixture loads the real curriculum and durable progress")
		var ids: Array = cohort(app, 3)
		for index in range(Growth.MASTERY_STREAK):
			var result: Dictionary = app.growth.record_attempt("saved-age-three-%d" % index, ids, true)
			check(result.save_ok, "The earned age fixture persists its word evidence")
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	return app


func dispose(app) -> void:
	app.audio.halt()
	app.queue_free()
	await settle()


func cohort(app, age: int) -> Array:
	return app.data.words.filter(func(word: Dictionary) -> bool: return int(word.min_age) == age).map(
		func(word: Dictionary) -> String: return str(word.id))


func master(app, ids: Array, prefix: String) -> void:
	for index in range(Growth.MASTERY_STREAK):
		app._record_growth("%s-%d" % [prefix, index], ids, true)


func press_retry(app) -> void:
	check(app._vocabulary_retry.is_visible_in_tree() and not app._vocabulary_retry.disabled,
		"A failed required download exposes an enabled retry action")
	app._vocabulary_retry.pressed.emit()


func startup_and_prefetch() -> void:
	var app = await make_app()
	var host = app.vocabulary_loader.downloads
	check(host.requests == [3], "Baby Pip requests only the current age-three learning pack on startup")
	check(app.growth.age == 0 and app.growth.level == 0 and app.growth.learning_age() == 3,
		"Loading uses learning age independently of Baby Pip and Lv0")
	check(app.model.cards.is_empty() and app._vocabulary_prompt.is_visible_in_tree(),
		"A board is not constructed with missing word artwork or pronunciation")
	host.reply(3, "loading", 0.45)
	check(is_equal_approx(float(app._vocabulary_snapshot().states["3"].progress), 0.45),
		"The required age download exposes real progress")
	host.reply(3, "failed")
	check(app.model.cards.is_empty(), "Download failure leaves the initial board unstarted")
	press_retry(app)
	check(host.requests == [3, 3], "Retry requests the same required age without fetching future ages")
	host.reply(3, "ready", 1.0)
	await settle()
	check(app.model.cards.size() == 10 and not app._vocabulary_prompt.is_visible_in_tree(),
		"A successful retry resumes the original startup action")
	var round_id: String = app._round_id
	app.vocabulary_loader.age_ready.emit(3)
	await settle()
	check(app._round_id == round_id, "A duplicate ready notification cannot restart the live board")
	var ids: Array = cohort(app, 3)
	master(app, ids.slice(0, 1), "first-mastered-word")
	check(app.growth.level == 1 and host.requests == [3, 3],
		"A Lv upgrade alone does not download an age pack")
	master(app, ids.slice(1, 71), "below-prefetch-threshold")
	check(app.growth.snapshot().mastered == 71 and host.requests == [3, 3],
		"Eighty-eight percent cohort mastery does not prefetch the next age")
	master(app, ids.slice(71, 72), "at-prefetch-threshold")
	check(host.requests == [3, 3, 4] and app.growth.age == 0 and app.growth.learning_age() == 3,
		"Ninety percent current-cohort mastery quietly prefetches age four")
	app._refresh_growth()
	app._refresh_growth()
	check(host.requests.count(4) == 1 and app._round_id == round_id
		and not app._vocabulary_prompt.is_visible_in_tree(),
		"Repeated refreshes neither duplicate a background download nor interrupt play")
	host.reply(4, "ready", 1.0)
	await settle()
	check(app._round_id == round_id and app.growth.learning_age() == 3,
		"Prefetch completion preserves the active lesson and earned age")
	await dispose(app)


func pending_round_and_rewards() -> void:
	var app = await make_app()
	var host = app.vocabulary_loader.downloads
	host.reply(3, "ready", 1.0)
	await settle()
	Fixture.earn_pair_chest(app)
	var old_round: String = app._round_id
	var old_lesson: Array = app.model.lesson_words.duplicate(true)
	master(app, cohort(app, 3), "complete-age-three")
	check(app.growth.age == 3 and app.growth.learning_age() == 4 and host.requests.count(4) == 1,
		"Completing the current cohort requests its successor independently of earned Lv")
	check(not app.new_round(923, false, "", "memory"),
		"Starting the next age waits for its unready media pack")
	check(app._round_id == old_round and app.model.lesson_words == old_lesson
		and app.coin_wallet.balance == 0 and not app.medal_progress.pair_round("match").settled,
		"Waiting preserves the previous board and its unopened earned chest")
	host.reply(4, "failed")
	check(app._round_id == old_round and app.coin_wallet.balance == 0,
		"A failed next-age download does not discard or silently settle rewards")
	press_retry(app)
	check(host.requests.count(4) == 2, "Next-round retry downloads the failed target exactly once")
	host.reply(4, "ready", 1.0)
	await settle()
	check(app._mode_id == "memory" and app.model.age_band_id == "4" and app._round_id != old_round,
		"Readiness resumes the requested Memory action rather than the old mode")
	check(app._memory.memory.cards.size() == 10 and app.model.lesson_words.all(
		func(word: Dictionary) -> bool: return int(word.min_age) == 4),
		"The resumed Memory board uses only the newly current age cohort")
	check(app.coin_wallet.balance == 50 and app.medal_progress.pair_round("match").settled,
		"Successful navigation settles the previous earned ordinary chest exactly once")
	var resumed_round: String = app._round_id
	app.vocabulary_loader.age_ready.emit(4)
	await settle()
	check(app._round_id == resumed_round and app.coin_wallet.balance == 50,
		"Repeated completion cannot duplicate reward credit or a round transition")
	await dispose(app)


func notebook_requests_and_stale_callbacks() -> void:
	var app = await make_app()
	var host = app.vocabulary_loader.downloads
	host.reply(3, "ready", 1.0)
	await settle()
	var old_round: String = app._round_id
	var saved: Dictionary = app.growth.snapshot().duplicate(true)
	app._show_collection()
	app._choose_age_band("7")
	check(host.requests == [3, 7] and app._age_catalog.snapshot().loading_state == "loading"
		and app._age_catalog.word_buttons.is_empty(),
		"An unopened notebook cohort loads on demand and shows no missing-media cards")
	app._choose_age_band("8")
	host.reply(7, "ready", 1.0)
	await settle()
	check(app._catalog_age == 8 and app._age_catalog.snapshot().loading_state == "loading"
		and app._age_catalog.word_buttons.is_empty(),
		"A stale age-seven completion cannot replace the selected age-eight notebook")
	host.reply(8, "ready", 1.0)
	await settle()
	check(app._age_catalog.snapshot().age_band == "8" and app._age_catalog.snapshot().loading_state == "ready"
		and app._age_catalog.word_count() == cohort(app, 8).size(),
		"The latest selected age displays its complete cohort only after readiness")
	app._choose_age_band("9")
	app._hide_collection()
	host.reply(9, "ready", 1.0)
	await settle()
	check(not app.collection_page.visible and app._round_id == old_round,
		"Returning to play prevents a late notebook callback from reopening or restarting anything")
	app._show_collection()
	check(app._catalog_age == 3 and host.requests.count(3) == 1,
		"Returning to the notebook restores the current age from the mounted pack")
	app._choose_age_band("10")
	host.reply(10, "failed")
	check(app._age_catalog.snapshot().loading_state == "failed", "Notebook download failures remain recoverable in place")
	var retry: Button = app._age_catalog.find_child("AgeVocabularyRetry", true, false)
	check(is_instance_valid(retry) and retry.is_visible_in_tree() and not retry.disabled,
		"The failed notebook age has a usable retry control")
	if is_instance_valid(retry):
		retry.pressed.emit()
	check(host.requests.count(10) == 2 and host.requests.count(3) == 1,
		"Notebook retry targets its selected age rather than the learning age")
	host.reply(10, "ready", 1.0)
	await settle()
	check(app._age_catalog.snapshot().age_band == "10" and app._age_catalog.word_count() == cohort(app, 10).size(),
		"A successful notebook retry renders the originally selected age")
	app._choose_age_band("7")
	app._choose_age_band("8")
	check(host.requests.count(7) == 1 and host.requests.count(8) == 1,
		"Previously mounted age packs are reused when switching notebook tabs")
	check(app.growth.snapshot() == saved and app._round_id == old_round,
		"Browsing, retries and completions never award learning progress or change the active round")
	await dispose(app)


func canceled_and_background_rounds() -> void:
	var app = await make_app()
	var host = app.vocabulary_loader.downloads
	host.reply(3, "ready", 1.0)
	await settle()
	master(app, cohort(app, 3), "cancel-complete-age-three")
	var previous_round: String = app._round_id
	check(not app.new_round(941, false, "", "jelly"), "A next-age Jelly request waits for its pack")
	check(not app._open_speech_debug() and not app._speech_debug_active and paused,
		"Diagnostics cannot steal pause ownership from an in-flight vocabulary request")
	check(app._vocabulary_back.is_visible_in_tree() and not app._vocabulary_back.disabled,
		"Players can return to their intact board while the next age is downloading")
	app._vocabulary_back.pressed.emit()
	host.reply(4, "ready", 1.0)
	await settle()
	check(app._round_id == previous_round and app._mode_id == "match" and app._pending_vocabulary_round.is_empty()
		and not app._vocabulary_prompt.is_visible_in_tree(),
		"Cancel removes the pending action so a late ready callback cannot start Jelly")
	check(app.new_round(942, false, "", "memory"), "The same downloaded pack can serve a later explicit choice")
	master(app, cohort(app, 4), "background-complete-age-four")
	previous_round = app._round_id
	check(not app.new_round(943, false, "", "pop"), "A Voice Pop choice preserves its pending target age")
	app.on_page_hidden()
	host.reply(5, "ready", 1.0)
	await settle()
	check(app._round_id == previous_round and app._mode_id == "memory",
		"Finishing a pack in the background cannot start a replacement round")
	app.on_page_visible()
	await settle()
	check(app._mode_id == "pop" and app.model.age_band_id == "5" and app._round_id != previous_round,
		"Returning to the foreground resumes the same requested action after its pack is ready")
	check(host.requests == [3, 4, 5], "Cancellation and page visibility never redownload mounted cohorts")
	await dispose(app)

func returning_learner() -> void:
	var app = await make_app(true)
	var host = app.vocabulary_loader.downloads
	check(app.growth.age == 3 and app.growth.level == 19 and app.growth.learning_age() == 4,
		"The saved fixture distinguishes earned Age 3, Lv19 and the age-four curriculum")
	check(host.requests == [4] and app.model.cards.is_empty(),
		"Returning players initially fetch only their current learning age")
	host.reply(4, "ready", 1.0)
	await settle()
	for mode: String in ["match", "memory", "pop", "jelly", "phrase"]:
		check(app.new_round(814, false, "", mode), "%s starts from the already mounted current-age pack" % mode)
		check(host.requests == [4] and app.model.age_band_id == "4",
			"%s does not download earlier review ages or future ages while starting" % mode)
		check(app.duck.growth_age == 3, "%s retains the earned Pip appearance" % mode)
	await dispose(app)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	await startup_and_prefetch()
	await pending_round_and_rewards()
	await notebook_requests_and_stale_callbacks()
	await canceled_and_background_rounds()
	await returning_learner()
	for directory in directories:
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)
	print("Vocabulary loading flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

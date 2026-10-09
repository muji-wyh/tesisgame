extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Growth = preload("res://scripts/growth_state.gd")
var checks := 0
var failures := 0

class BlockedStorage extends RefCounted:
	var text: Variant = null
	func growthState() -> Variant:
		return text
	func saveGrowthState(_text: String, _expected_text: Variant) -> bool:
		return false

class UnreadableStorage extends RefCounted:
	var readable := false
	func growthState() -> Variant:
		return null if readable else false
	func saveGrowthState(_text: String, _expected_text: Variant) -> bool:
		return true

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

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var directory := "user://growth_flow_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	Fixture.install(app, directory)
	root.add_child(app)
	await settle()
	check(app.growth.ready and app.growth.level == 3, "A new device starts at Lv3 without a player gate")
	check(app.model.cards.size() == 10, "The real game starts with a playable Match board")
	if app.model.cards.size() != 10:
		app.queue_free()
		quit(1)
		return
	app.audio.set_muted(true)
	check(app._growth_button.is_visible_in_tree(), "Learning progress has a persistent entry")
	for viewport_size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = viewport_size
		await settle()
		var progress_rect: Rect2 = app._growth_button.get_global_rect()
		var board_rect: Rect2 = app._match_playfield.get_global_rect()
		check(progress_rect.end.y <= board_rect.position.y - 2.0,
			"Growth text stays above the playable board at %s" % viewport_size)
	check(app.find_child("LeaderboardOverlay", true, false) == null and app.find_child("PipsRoom", true, false) == null, "Identity and room views are absent")
	await _match(app)
	await _memory(app)
	await _phrase(app)
	await _pop(app)
	app._show_collection()
	await settle()
	check(app.collection_page.visible and app._age_catalog.word_count() == 80, "Notebook lists the complete current cohort")
	check(app._age_catalog.snapshot().growth.level == 3, "Notebook shows saved mastery state")
	app._choose_age_band("12")
	await settle()
	check(app.growth.level == 3 and app._catalog_age == 12, "Future preview cannot change the earned level")
	check(app._age_catalog.word_count() > 0 and app._age_notice.text.begins_with("Preview only"), "Future words are labelled as locked previews")
	app._hide_collection()
	app.on_page_hidden()
	var saved: Dictionary = app.growth.snapshot().streaks.duplicate()
	app._pop.game.word_attempted.emit("background", ["cat"] as Array[String], true)
	check(app.growth.snapshot().streaks == saved, "Background callbacks cannot credit a word")
	app.on_page_visible()
	var reloaded = Growth.new(directory + "/growth.cfg")
	check(reloaded.configure(app.data.words) and reloaded.load_state(), "A separate state object reloads the saved growth")
	check(reloaded.snapshot().streaks == saved, "Mastery survives closing the game independently of chest claims")
	app.audio.halt()
	app.queue_free()
	await settle()
	await _load_failure(directory)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Growth flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _load_failure(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory, "load-recovery.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	var storage := UnreadableStorage.new()
	app.growth._host = storage
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	check(not app.growth.ready and app.model.cards.is_empty(), "An unreadable growth save blocks scored play")
	check(app._storage_retry_button.is_visible_in_tree() and app._message.visible,
		"The initial load failure explains how to recover")
	check(not app.new_round(101, false, "", "pop"), "Mode switching cannot bypass the growth load gate")
	storage.readable = true
	app._storage_retry_button.pressed.emit()
	await settle()
	check(app.growth.ready and app.model.cards.size() == 10 and not app._message.visible,
		"Successful retry loads progress before starting a playable board")
	app.audio.halt()
	app.queue_free()
	await settle()

func _match(app) -> void:
	var word: Dictionary = app.model.lesson_words[0]
	app.hint_button.pressed.emit()
	check(app.growth.streak(word.id) == 0, "Hints do not create evidence")
	app.cards[word.id + ":word"].pressed.emit()
	check(app.growth.streak(word.id) == 0, "First Match selection is neutral")
	app.cards[word.id + ":image"].pressed.emit()
	check(app.growth.streak(word.id) == 1, "Match pair credits its word once")
	app.cards[word.id + ":image"].pressed.emit()
	check(app.growth.streak(word.id) == 1, "Repeated Match presses cannot double-credit")
	app._continue_match()
	var first: Dictionary = app.model.lesson_words[1]
	var second: Dictionary = app.model.lesson_words[2]
	app.growth.record_attempt("seed-match", [first.id, second.id], true)
	app.cards[first.id + ":word"].pressed.emit()
	app.cards[second.id + ":image"].pressed.emit()
	check(app.growth.streak(first.id) == 0 and app.growth.streak(second.id) == 0, "A wrong Match resets both involved words")
	app._continue_match()
	await settle()

func _memory(app) -> void:
	check(app.new_round(928, false, "", "memory"), "Memory starts without changing earned level")
	await settle()
	var view = app._memory
	var word: Dictionary = view.memory.cards[0].word
	var before: int = app.growth.streak(word.id)
	view.begin_peek()
	view.end_peek()
	check(app.growth.streak(word.id) == before, "Memory peek is neutral")
	var pair: Array[int] = []
	for index in range(view.memory.cards.size()):
		if view.memory.cards[index].word.id == word.id:
			pair.append(index)
	view.card_buttons[pair[0]].pressed.emit()
	check(app.growth.streak(word.id) == before, "First Memory reveal is neutral")
	view.card_buttons[pair[1]].pressed.emit()
	check(app.growth.streak(word.id) == mini(6, before + 1), "Memory pair credits one unique word")
	view.continue_feedback()
	var next_word: Dictionary = view.memory.cards.filter(func(card: Dictionary) -> bool: return card.word.id != word.id)[0].word
	var next_before: int = app.growth.streak(next_word.id)
	var storage := BlockedStorage.new()
	storage.text = FileAccess.get_file_as_string(app.growth._path)
	app.growth._host = storage
	for index in range(view.memory.cards.size()):
		if view.memory.cards[index].word.id == next_word.id:
			view.card_buttons[index].pressed.emit()
	await settle()
	check(app.growth.streak(next_word.id) == next_before and app.growth.snapshot().pending_count == 1,
		"A failed write holds the Memory answer without publishing false mastery")
	check(app._storage_retry_button.is_visible_in_tree(), "Memory immediately exposes the shared Retry saving action")
	app.growth._host = null
	app._storage_retry_button.pressed.emit()
	check(app.growth.streak(next_word.id) == mini(6, next_before + 1) and app.growth.snapshot().pending_count == 0,
		"Retry saves the queued Memory answer exactly once")
	view.continue_feedback()

func _phrase(app) -> void:
	check(app.new_round(937, false, "", "phrase"), "Phrase Builder loads the ESL curriculum")
	await settle()
	var view = app._phrase
	var ids: Array = view.game.current_question().words
	var before: Dictionary = app.growth.snapshot().streaks.duplicate()
	view.action_button.pressed.emit()
	check(app.growth.snapshot().streaks == before, "An incomplete phrase is neutral")
	for id in ids:
		for index in range(view.game.options.size()):
			if view.game.options[index].id == id:
				view.option_buttons[index].pressed.emit()
	check(app.growth.snapshot().streaks == before, "Placing and hearing phrase words is neutral")
	view.action_button.pressed.emit()
	for id in ids:
		check(app.growth.streak(id) == mini(6, int(before.get(id, 0)) + 1), "A correct phrase credits " + id + " once")
	var after: Dictionary = app.growth.snapshot().streaks.duplicate()
	view.action_button.pressed.emit()
	check(app.growth.snapshot().streaks == after, "Repeated phrase confirmation cannot duplicate evidence")

func _pop(app) -> void:
	check(app.new_round(945, false, "", "pop"), "Voice Pop starts without player selection")
	await settle()
	var game = app._pop.game
	check(game.start(), "Voice Pop's actual model begins a round")
	var target: Dictionary = game.targets[0]
	var before: int = app.growth.streak(target.word.id)
	var event := {"event_id": "growth-pop", "round_id": game.round_id, "target_uid": target.uid,
		"text": target.word.text, "stage": "interim", "received_at_ms": 1}
	game.hit_speech_event(event)
	check(app.growth.streak(target.word.id) == mini(6, before + 1), "Voice Pop credits the successfully spoken target")
	event.stage = "final"
	game.hit_speech_event(event)
	check(app.growth.streak(target.word.id) == mini(6, before + 1), "Speech interim/final pair earns one credit")
	var after: Dictionary = app.growth.snapshot().streaks.duplicate()
	game.advance(60)
	check(app.growth.snapshot().streaks == after, "Voice Pop expiry and silence never reset mastery")

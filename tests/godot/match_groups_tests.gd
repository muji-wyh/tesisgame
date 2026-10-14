extends SceneTree

const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
const Growth = preload("res://scripts/growth_state.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func _prepare_learner(app, directory: String) -> bool:
	var words: Array = app.data.words.filter(func(word: Dictionary) -> bool: return word.id == "microphone")
	check(words.size() == 1, "The long-word fixture resolves one curriculum word")
	if words.size() != 1:
		return false
	var age: int = int(words[0].min_age)
	var path: String = directory + "/growth-age-%d.cfg" % age
	var saved := ConfigFile.new()
	saved.set_value("growth", "version", 1)
	saved.set_value("growth", "level", age)
	saved.set_value("growth", "streaks", {})
	saved.set_value("growth", "receipts", [])
	var written: bool = saved.save(path) == OK
	check(written, "The long-word fixture saves its isolated learner")
	if not written:
		return false
	var growth := Growth.new(path)
	var ready: bool = growth.configure(app.data.words) and growth.load_state() and growth.learning_age() == age
	check(ready, "The isolated learner is eligible for the long word's age cohort")
	if not ready:
		return false
	app.growth = growth
	app.vocabulary_loader.request_age(age)
	app._refresh_growth()
	PlayerFixture.enter_mode(app, "match")
	var entered: bool = app._mode_id == "match" and not app._mode_menu_open()
	check(entered, "The grouping fixture enters Match through Home")
	return entered


func _finish(app, directory: String) -> void:
	app.audio.halt()
	app.queue_free()
	await settle()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Match groups: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func state(app) -> Array:
	return [app.model.cards.duplicate(true), app.model.lesson_words.duplicate(true),
		app.model.selected_id, app.model.matched_ids.duplicate(), app.model.hint_ids.duplicate(),
		app.model.hints_remaining, (app.model.matched_ids.size() / 2), app.model.mistakes, app.model.phase,
		app.model.age_band_id, app.model.theme_id]


func check_groups(app) -> void:
	var pictures: Array = app.grid.get_children().filter(func(card: Button) -> bool: return card.card_data.kind == "image")
	var words: Array = app.grid.get_children().filter(func(card: Button) -> bool: return card.card_data.kind == "word")
	check(pictures.size() == 5 and words.size() == 5 and app.grid.get_child_count() == 10,
		"Match still has exactly five pictures and five words")
	if pictures.size() != 5 or words.size() != 5:
		return
	for kind in ["image", "word"]:
		var expected: Array = app.model.cards.filter(func(card: Dictionary) -> bool: return card.kind == kind).map(
			func(card: Dictionary) -> String: return card.id)
		var displayed: Array = (pictures if kind == "image" else words).map(
			func(card: Button) -> String: return card.card_data.id)
		check(displayed == expected, "Grouping retains the model's shuffled " + kind + " order")
	for picture in pictures:
		for word in words:
			var image_rect: Rect2 = picture.get_global_rect()
			var word_rect: Rect2 = word.get_global_rect()
			check(image_rect.end.x <= word_rect.position.x if app.grid.columns == 2 else image_rect.end.y <= word_rect.position.y,
				"Pictures and words occupy separate " + ("left/right columns" if app.grid.columns == 2 else "top/bottom rows"))
	for card in app.grid.get_children():
		check(app._match_playfield.get_global_rect().grow(1).encloses(card.get_global_rect()),
			"Grouped cards keep their full playfield and touch targets")
		check(card.size.x * app.Style.ui_scale(app) >= 48 and card.size.y * app.Style.ui_scale(app) >= 48,
			"Grouping does not shrink card input targets")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://match-groups-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	PlayerFixture.install(app, directory)
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	if not _prepare_learner(app, directory):
		await _finish(app, directory)
		return
	for seed_value in range(8):
		var started: bool = app.new_round(seed_value, false, "", "match", "microphone")
		await settle()
		var playable: bool = started and app._mode_id == "match" and not app._mode_menu_open() \
			and app.cards.has("microphone:image") and app.cards.has("microphone:word") and app.cards.size() == 10
		check(playable, "A long-word Match lesson starts from the full current-age pool")
		if not playable:
			await _finish(app, directory)
			return
		var age: int = app.growth.learning_age()
		check(app.model.lesson_words.all(func(word: Dictionary) -> bool: return int(word.min_age) == age),
			"Every grouped lesson word belongs to the isolated learner's age")
		var default_focus = app._default_focus()
		check(default_focus != null and default_focus.get("card_data") is Dictionary
			and default_focus.card_data.kind == "image", "Board focus starts with a picture")
		var price: int = app._match_hint_price()
		var funded: Dictionary = app.coin_wallet.credit("fixture:group-hint:%d" % seed_value,
			int(price / app.Economy.COINS_PER_TIER))
		check(funded.ok and int(funded.amount) == price, "Fund this board's actual paid grouping hint price")
		if not funded.ok:
			await _finish(app, directory)
			return
		var before_hint: int = app.coin_wallet.balance
		app._request_hint()
		var hinted: bool = app.model.hint_ids.size() == 2 \
			and app.model.hint_ids.all(func(id: String) -> bool: return app.cards.has(id))
		check(hinted and app.coin_wallet.balance == before_hint - price,
			"The paid grouping hint identifies two live cards and deducts its current price")
		if not hinted:
			await _finish(app, directory)
			return
		var first: String = app.model.hint_ids[0]
		var partner: String = app.model.hint_ids[1]
		app.cards[first].pressed.emit()
		app.cards[first].grab_focus()
		var original: Array = state(app)
		var instances: Dictionary = {}
		for id in app.cards:
			instances[id] = app.cards[id].get_instance_id()
		for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768), Vector2i(320, 568)]:
			root.size = dimensions
			await settle()
			check_groups(app)
			check(state(app) == original and app.cards[first].has_focus(),
				"Changing grouping orientation preserves the active round, hint and focus")
			check(app.cards.keys().all(func(id: String) -> bool: return app.cards[id].get_instance_id() == instances[id]),
				"Resizing repositions existing cards rather than rebuilding them")
			var pictures: Array = app.grid.get_children().filter(func(card: Button) -> bool: return card.card_data.kind == "image")
			pictures[0].grab_focus()
			app._move_focus(Vector2.RIGHT if app.grid.columns == 2 else Vector2.DOWN)
			check(root.gui_get_focus_owner().card_data.kind == "word",
				"Directional navigation crosses naturally from the picture group to the word group")
			app.cards[first].grab_focus()
		app.cards[partner].pressed.emit()
		check((app.model.matched_ids.size() / 2) == 1 and app.model.mistakes == 0, "A cross-group match still scores exactly once")
		app._resolve_feedback()
		var picture: Dictionary = app.model.cards.filter(func(card: Dictionary) -> bool:
			return card.kind == "image" and not app.model.matched_ids.has(card.id))[0]
		var word: Dictionary = app.model.cards.filter(func(card: Dictionary) -> bool:
			return card.kind == "word" and card.word.id != picture.word.id and not app.model.matched_ids.has(card.id))[0]
		app.cards[picture.id].pressed.emit()
		app.cards[word.id].pressed.emit()
		check(app.model.mistakes == 1 and (app.model.matched_ids.size() / 2) == 1, "Wrong cross-group pairs retain normal feedback and scoring")
		app._resolve_feedback()
	var lesson: Array = app.model.lesson_words.duplicate(true)
	PlayerFixture.enter_mode(app, "memory")
	await settle()
	check(app._mode_id == "memory" and not app._mode_menu_open(), "Memory is selected through Home")
	var memory_cards: Array = app._memory.memory.cards.duplicate(true)
	root.size = Vector2i(1366, 768)
	await settle()
	check(app.model.lesson_words == lesson and app._memory.memory.cards == memory_cards and app._memory.card_buttons.size() == 10
		and not app.grid.is_visible_in_tree(), "Memory keeps its own ten-card board and order")
	PlayerFixture.enter_mode(app, "pop")
	PlayerFixture.choose_pop_player(app)
	await settle()
	check(app._mode_id == "pop" and not app._mode_menu_open(), "Voice Pop is selected through Home")
	check(app.model.lesson_words == lesson and app._pop.is_visible_in_tree()
		and not app.grid.is_visible_in_tree() and not app._memory.is_visible_in_tree(),
		"Voice Pop replaces the board without losing the shared five-word adventure")
	PlayerFixture.enter_mode(app, "match")
	await settle()
	check(app._mode_id == "match" and not app._mode_menu_open(), "Match is selected through Home")
	check(app.model.lesson_words == lesson, "Returning to Match retains the shared adventure words")
	check_groups(app)
	await _finish(app, directory)

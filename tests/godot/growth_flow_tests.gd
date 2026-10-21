extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Growth = preload("res://scripts/growth_state.gd")
const Badge = preload("res://scripts/growth_badge.gd")
const Context = preload("res://scripts/learning_context.gd")
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
	await _badge_states()
	var directory := "user://growth_flow_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	Fixture.install(app, directory)
	root.add_child(app)
	await settle()
	check(app.growth.ready and app.growth.level == 0 and app.growth.age == 0, "A new device starts at Lv0 with Baby Pip without a player gate")
	check(app.model.cards.size() == 10, "The real game starts with a playable Match board")
	if app.model.cards.size() != 10:
		app.queue_free()
		quit(1)
		return
	app.audio.set_muted(true)
	check(app._growth_button.is_visible_in_tree(), "Learning progress has a persistent entry")
	await _responsive_badge(app)
	check(app.find_child("LeaderboardOverlay", true, false) == null and app.find_child("PipsRoom", true, false) == null, "Identity and room views are absent")
	await _match(app)
	await _memory(app)
	await _phrase(app)
	await _pop(app)
	app._show_collection()
	await settle()
	check(app.collection_page.visible and app._age_catalog.word_count() == 80, "Notebook lists the complete current cohort")
	check(app._age_catalog.snapshot().growth.age == 0, "Notebook shows saved mastery state")
	app._choose_age_band("12")
	await settle()
	check(app.growth.age == 0 and app._catalog_age == 12, "Future preview cannot change the earned level")
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
	await _age_milestones(directory)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Growth flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _age_milestones(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory, "age-milestones.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	var words: Array = app.data.words.filter(func(word: Dictionary) -> bool: return int(word.min_age) == 3)
	var ids: Array = words.map(func(word: Dictionary) -> String: return str(word.id))
	for index in range(Growth.MASTERY_STREAK):
		app._record_growth("age-three-%d" % index, ids, true)
	check(app.growth.age == 3 and app.growth.level == 19 and app.growth.learning_age() == 4,
		"Completing the real 80-word age-three set earns Age 3 independently of Lv19")
	check(app._pip_age_description == "Age 3" and app.duck.growth_age == 3, "Pip wears the earned Age 3 appearance after promotion")
	for mascot in [app.duck, app._phrase.pip, app._round_celebration.pip]:
		check(mascot.growth_age == 3, "Every gameplay and celebration Pip follows earned age")
	for mode: String in ["match", "memory", "phrase", "pop", "jelly"]:
		var opened: bool = app.new_round(813, false, "", mode)
		if not opened and not app._pending_vocabulary_round.is_empty():
			await settle()
			opened = app._pending_vocabulary_round.is_empty() and app._mode_id == mode and app.model.age_band_id == "4"
		check(opened, "%s uses the next age cohort independently of Lv19" % mode)
		check(app.model.age_band_id == "4", "%s shares the age-four learning target" % mode)
		check(app.duck.growth_age == 3, "Starting %s cannot promote Pip from Lv19" % mode)
	app._show_collection()
	await settle()
	check(app._catalog_age == 4 and app._age_catalog.word_count() == 99 and app._collection_title.text == "Word library"
		and app._pip_age_description == "Age 3" and app._growth_summary.text.contains("Age 4"),
		"Word library distinguishes earned Age 3 from the next 99-word Age 4 vocabulary set")
	app._hide_collection()
	app._record_growth("age-three-mistake", [ids[0]], false)
	check(app.growth.level == 19 and app.growth.age == 3 and app.duck.growth_age == 3,
		"A later mistake resets a word without regressing either growth axis or appearance")
	for next_age in range(4, 13):
		var next_words: Array = app.data.words.filter(func(word: Dictionary) -> bool: return int(word.min_age) == next_age)
		var next_ids: Array = next_words.map(func(word: Dictionary) -> String: return str(word.id))
		for index in range(Growth.MASTERY_STREAK):
			app._record_growth("age-%d-%d" % [next_age, index], next_ids, true)
	check(app.growth.age == 12 and app._pip_age_description == "Age 12+" and app.duck.growth_age == 12,
		"The final appearance and accessible Age 12+ description remain independent of numeric Lv")
	for viewport_size: Vector2i in [Vector2i(320, 568), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = viewport_size
		await settle()
		_badge_geometry(app, viewport_size, "Age 12+ Jelly")
	root.size = Vector2i(1366, 768)
	app.audio.halt()
	app.queue_free()
	await settle()

func _badge_states() -> void:
	var badge = Badge.new()
	root.add_child(badge)
	var states: Array[Dictionary] = [
		{"ready": true, "level": 0, "label": "Lv0", "age_label": "Baby", "level_mastered": 0, "level_required": 1, "level_remaining": 1, "level_progress": 0.0, "mastered": 0, "total": 80, "progress": 0.0, "practice_progress": 0.75},
		{"ready": true, "level": 1, "label": "Lv1", "age_label": "Baby", "level_mastered": 1, "level_required": 2, "level_remaining": 1, "level_progress": 0.5, "mastered": 2, "total": 80, "progress": 2.0 / 80.0},
		{"ready": true, "level": 20, "label": "Lv20", "age_label": "Age 3", "level_mastered": 3, "level_required": 7, "level_remaining": 4, "level_progress": 3.0 / 7.0, "mastered": 19, "total": 99, "progress": 19.0 / 99.0},
		{"ready": true, "level": 98, "label": "Lv98", "age_label": "Age 11", "level_mastered": 29, "level_required": 30, "level_remaining": 1, "level_progress": 29.0 / 30.0, "mastered": 88, "total": 89, "progress": 88.0 / 89.0},
		{"ready": true, "level": 99, "label": "Lv99", "age_label": "Age 12+", "level_mastered": 0, "level_required": 0, "level_remaining": 0, "level_progress": 1.0, "level_completed": true, "mastered": 89, "total": 89, "progress": 1.0, "completed": true},
		{"ready": false, "level": 0, "label": "Lv0", "level_progress": 0.0, "mastered": 0, "total": 80, "progress": 0.0, "save_ok": false}
	]
	for state: Dictionary in states:
		badge.configure(state)
		var description: String = str(badge.get("accessibility_name"))
		check(badge.tooltip_text.is_empty(), "Growth details remain accessible without a hover popup")
		check(absf(badge.bar.value - float(state.level_progress) * 100.0) <= badge.bar.step * 0.5 + 0.0001,
			"The badge fills only for mastered words, never partial practice evidence")
		if bool(state.ready):
			check(badge.level_label.text == state.label
				and badge.count_label.text == ("MAX" if state.get("level_completed", false) else "%d / %d" % [state.level_mastered, state.level_required]),
				"Growth facts retain the exact earned level and new-word progress")
			check(description.contains(state.label) and not description.contains(state.age_label)
				and not description.contains("current age set") and description.contains("Open word library"),
				"The Lv description retains the level target and Word library action without Pip age")
			if int(state.level) < 99:
				var next_level: String = "Lv%d" % (int(state.level) + 1)
				check(description.contains("reach " + next_level),
					"The earned level retains the correct next-stage target without crowding the badge")
			else:
				check(not description.contains("Lv100") and not description.contains("reach "),
					"The final stage offers word review without inventing a further level")
				if bool(state.get("completed", false)):
					check(description.contains("Maximum level reached"),
						"The completed final stage keeps its completion meaning accessible")
		else:
			check(badge.level_label.text == "Lv…" and badge.count_label.text == "Unavailable"
				and description.contains("unavailable") and badge.bar.value == 0.0,
				"Unreadable storage is shown as unavailable instead of a false starting level")
		for footprint: Vector2 in [Vector2(168, 52), Vector2(68, 44), Vector2(52, 44)]:
			var compact: bool = footprint.x < 168
			badge.fit(1.0, compact, footprint.x == 52)
			await settle()
			check(badge.size.is_equal_approx(footprint), "The growth entry honors its %s toolbar footprint" % footprint)
			check(badge.get_global_rect().encloses(badge.bar.get_global_rect())
				and badge.bar.is_visible_in_tree() and not badge.bar.show_percentage,
				"Every badge size keeps its actual mastery bar inside the clickable entry")
			for label: Label in [badge.level_label, badge.count_label]:
				if label.is_visible_in_tree():
					check(badge.get_global_rect().grow(0.5).encloses(label.get_global_rect()),
						"Visible badge text stays inside the %s entry" % footprint)
					var font: Font = label.get_theme_font("font")
					var font_size: int = label.get_theme_font_size("font_size")
					check(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x + 0.5,
						"The full %s label fits without clipping in the %s entry" % [label.text, footprint])
			check(badge.count_label.visible == not compact,
				"Compact badges keep level and progress while the count remains available in the description")
			check(badge.bar.size.y >= (7.5 if compact else 19.5),
				"The mastery track remains visibly substantial instead of resembling a divider")
			if not compact:
				var track: Rect2 = badge.bar.get_global_rect()
				var count: Rect2 = badge.count_label.get_global_rect()
				check(track.grow(0.5).encloses(count) and track.get_center().distance_to(count.get_center()) < 0.5
					and badge.count_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
					and badge.count_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
					"The wide badge centers its readable count within the recessed mastery track")
				check(badge.count_label.z_index > badge.bar.z_index
					or (badge.count_label.z_index == badge.bar.z_index and badge.count_label.get_index() > badge.bar.get_index()),
					"The mastery count paints above the track and remains readable across its fill")
			check(absf(badge.bar.value - float(state.level_progress) * 100.0) <= badge.bar.step * 0.5 + 0.0001,
				"Responsive fitting cannot change saved mastery progress")
	badge.configure(states[1])
	badge.focus_mode = Control.FOCUS_NONE
	badge.fit(1.0, true)
	check(badge.focus_mode == Control.FOCUS_NONE,
		"Fitting the badge cannot re-enable toolbar focus behind an open menu")
	badge.free()


func _badge_geometry(app, viewport_size: Vector2i, context: String) -> void:
	var badge = app._growth_button
	var rect: Rect2 = badge.get_global_rect()
	check(badge.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(rect),
		"%s keeps the growth entry within %s" % [context, viewport_size])
	check(rect.encloses(app._growth_bar.get_global_rect()) and app._growth_bar.is_visible_in_tree(),
		"%s keeps the real progress bar visible inside its toolbar entry" % context)
	for child in app._toolbar.get_children():
		if child is Control and child != badge and child.is_visible_in_tree():
			check(not rect.intersects(child.get_global_rect()), "%s keeps growth separate from neighboring toolbar actions" % context)
	check(not rect.intersects(app._mode_heading_button.get_global_rect()),
		"%s keeps growth separate from the game selector" % context)
	var pip_rect: Rect2 = app.duck.get_global_rect()
	check(app.find_child("PipAgeLabel", true, false) == null and app.duck.growth_age == app.growth.age,
		"%s expresses earned age with Pip artwork instead of a visible caption" % context)
	check(rect.encloses(badge.level_label.get_global_rect()) and not badge.level_label.get_global_rect().intersects(app._growth_bar.get_global_rect()),
		"%s keeps Lv and its progress track readable beside Pip" % context)
	check(pip_rect.size.x >= 43.5 and pip_rect.size.y >= 43.5
		and str(app.duck.get("accessibility_name")).contains(app.growth.snapshot().age_label)
		and str(app.duck.get("accessibility_name")).contains("Press for a new move"),
		"%s preserves Pip's reachable gesture action and announces age with the character" % context)
	var targets: Array = [app.duck, badge, app._mode_heading_button, app._voice_button, app.hint_button, app._memory.study_button, app._storage_retry_button]
	for index in range(targets.size()):
		var target: Control = targets[index]
		if not target.is_visible_in_tree():
			continue
		var bounds: Rect2 = target.get_global_rect()
		check(bounds.size.x >= 43.5 and bounds.size.y >= 43.5 and app._header.get_global_rect().grow(0.5).encloses(bounds),
			"%s keeps %s reachable within the header" % [context, target.name])
		check(not bounds.intersects(app._coin_counter.get_global_rect()), "%s separates the wallet from %s" % [context, target.name])
		for other in targets.slice(index + 1):
			if other.is_visible_in_tree():
				check(not bounds.intersects(other.get_global_rect()), "%s separates %s from %s" % [context, target.name, other.name])
	check(app._mode_heading_button.visible and app._mode_heading.get_minimum_size().x <= app._mode_heading_button.size.x,
		"%s keeps the complete mode selector visible" % context)


func _responsive_badge(app) -> void:
	check(app.collection_button == app._growth_button and app._growth_button.get_parent() == app._header_duck_slot
		and app._growth_bar == app._growth_button.bar and app.find_child("GrowthProgress", true, false) == null,
		"The notebook entry and mastery bar share Pip's compact companion cluster")
	check(app._growth_button.level_label.text == "Lv0" and app._growth_button.count_label.text == "0 / 1" and app.duck.growth_age == 0
		and app._growth_bar.value == 0.0,
		"A new device presents the first one-word level target independently of Baby age")
	for mode: String in ["match", "memory", "phrase", "pop", "jelly"]:
		check(app.new_round(720, false, "", mode), "%s starts for growth HUD layout coverage" % mode)
		for viewport_size: Vector2i in [Vector2i(320, 320), Vector2i(320, 568), Vector2i(390, 844), Vector2i(568, 320), Vector2i(844, 390), Vector2i(1366, 768)]:
			root.size = viewport_size
			await settle()
			_badge_geometry(app, viewport_size, mode)
			var playfield: Control = {"match": app._match_playfield, "memory": app._memory,
				"phrase": app._phrase, "pop": app._pop, "jelly": app._jelly}[mode]
			check(app._growth_button.get_global_rect().end.y <= playfield.get_global_rect().position.y,
				"%s keeps the growth entry above its playable region at %s" % [mode, viewport_size])
		root.size = Vector2i(320, 568)
		await settle()
		app._growth_button.pressed.emit()
		await settle()
		check(app.collection_page.visible and app._age_catalog.word_count() == 80,
			"The compact growth entry opens the current word notebook from %s" % mode)
		app._hide_collection()
		await settle()
	root.size = Vector2i(1366, 768)
	check(app.new_round(721, false, "", "match"), "Responsive checks restore a fresh Match round for learning assertions")
	await settle()


func _load_failure(directory: String) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory, "load-recovery.cfg")
	app._presentation.path = directory + "/load-recovery-presentation.cfg"
	app.professional_save_path = directory + "/load-recovery-professional.json"
	var storage := UnreadableStorage.new()
	app.growth._host = storage
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	check(not app.growth.ready and app.model.cards.is_empty(), "An unreadable growth save blocks scored play")
	check(app._growth_button.level_label.text == "Lv…" and app._growth_bar.value == 0.0,
		"The persistent entry shows unavailable progress while the saved level cannot be loaded")
	check(app._pip_age_description.is_empty(), "An unreadable save does not invent a starting Pip age")
	var home_retry: Button = app._mode_panel._home_retry
	check(app._mode_menu_open() and app._mode_panel._home_status.is_visible_in_tree()
		and app._mode_panel._home_status.text.contains("could not be loaded")
		and home_retry.is_visible_in_tree() and home_retry.text == "Retry saving"
		and home_retry.get("accessibility_description") == app.growth.error
		and app._valid_focus(home_retry) and app._default_focus() == home_retry,
		"The initial load failure explains recovery through a visible, accessible Retry saving action inside Home")
	check(not app.new_round(101, false, "", "pop"), "Mode switching cannot bypass the growth load gate")
	var course: Dictionary = app.professional.loader.catalog.course("retail")
	app._select_learning_context(Context.professional(course.id, course.modules[0].id, course.curriculum_revision, "match"))
	app.professional.phase = "failed"
	app.professional.error = "Pictures could not be loaded."
	app._refresh_learning_home()
	app._refresh()
	await settle()
	check(not app.growth.ready and home_retry.is_visible_in_tree() and home_retry.text == "Retry"
		and app._mode_panel._home_cancel.is_visible_in_tree()
		and app._mode_panel._home_status.text == app.professional.error
		and not app._mode_panel._home_retry_storage,
		"Unreadable everyday progress cannot displace the independent professional retry and cancel actions")
	app._select_learning_context(Context.growth(3, "match"))
	await settle()
	check(home_retry.is_visible_in_tree() and home_retry.text == "Retry saving" and app._mode_panel._home_retry_storage,
		"Returning to everyday vocabulary restores its unresolved storage recovery action")
	storage.readable = true
	home_retry.grab_focus()
	check(home_retry.has_focus(), "Keyboard users can reach Home's storage recovery action")
	home_retry.pressed.emit()
	await settle()
	check(app.growth.ready and app.model.cards.size() == 10 and not app._message.visible
		and not app._mode_panel._home_status_box.visible and not home_retry.visible,
		"Successful retry loads progress before starting a playable board")
	app.audio.halt()
	app.queue_free()
	await settle()

func _match(app) -> void:
	var word: Dictionary = app.model.lesson_words[0]
	check(app.coin_wallet.credit("fixture:growth-match-hint", 4).ok, "Fund the paid hint used to verify mastery evidence")
	app.hint_button.pressed.emit()
	check(app.model.hints_used == 1 and app.growth.streak(word.id) == 0, "Purchased hints do not create evidence")
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
	view.start_button.pressed.emit()
	check(view.memory.studying and view.memory.peek_duration == 10.0, "Memory Start opens the initial observation")
	view.end_peek()
	check(app.growth.streak(word.id) == before, "Memory observation is neutral")
	var pair: Array[int] = []
	for index in range(view.memory.cards.size()):
		if view.memory.cards[index].word.id == word.id:
			pair.append(index)
	view.card_buttons[pair[0]].pressed.emit()
	check(app.growth.streak(word.id) == before, "The concealed first Memory choice is neutral")
	view.card_buttons[pair[1]].pressed.emit()
	check(app.growth.streak(word.id) == mini(Growth.MASTERY_STREAK, before + 1), "Memory pair credits one unique word")
	view.continue_feedback()
	var next_word: Dictionary = view.memory.cards.filter(func(card: Dictionary) -> bool: return card.word.id != word.id)[0].word
	var next_before: int = app.growth.streak(next_word.id)
	for index in range(next_before, Growth.MASTERY_STREAK - 1):
		app.growth.record_attempt("seed-memory-mastery-%d" % index, [next_word.id], true)
	app._refresh_growth()
	next_before = app.growth.streak(next_word.id)
	var progress_before: float = app._growth_bar.value
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
	check(app._growth_bar.value == progress_before,
		"A failed mastery-answer save does not advertise mastery before it is committed")
	for viewport_size: Vector2i in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(844, 390)]:
		root.size = viewport_size
		await settle()
		_badge_geometry(app, viewport_size, "Pending save")
		check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(app._storage_retry_button.get_global_rect()),
			"Retry saving remains reachable alongside growth progress at %s" % viewport_size)
	root.size = Vector2i(1366, 768)
	await settle()
	app.growth._host = null
	app._storage_retry_button.pressed.emit()
	check(app.growth.streak(next_word.id) == mini(Growth.MASTERY_STREAK, next_before + 1) and app.growth.snapshot().pending_count == 0,
		"Retry saves the queued Memory answer exactly once")
	check(app.growth.level == 1 and app._growth_button.level_label.text == "Lv1" and app.growth.age == 0 and app.duck.growth_age == 0 and is_equal_approx(app._growth_bar.value, 0.0),
		"The first mastered word earns Lv1 while Baby Pip and the age cohort remain unchanged")
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
		check(app.growth.streak(id) == mini(Growth.MASTERY_STREAK, int(before.get(id, 0)) + 1), "A correct phrase credits " + id + " once")
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
	check(app.growth.streak(target.word.id) == mini(Growth.MASTERY_STREAK, before + 1), "Voice Pop credits the successfully spoken target")
	event.stage = "final"
	game.hit_speech_event(event)
	check(app.growth.streak(target.word.id) == mini(Growth.MASTERY_STREAK, before + 1), "Speech interim/final pair earns one credit")
	var after: Dictionary = app.growth.snapshot().streaks.duplicate()
	game.advance(60)
	check(app.growth.snapshot().streaks == after, "Voice Pop expiry and silence never reset mastery")

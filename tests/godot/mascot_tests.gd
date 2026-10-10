extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var path := "res://scripts/duck_mascot.gd"
	check(FileAccess.file_exists(path), "The animated duck mascot exists")
	if not FileAccess.file_exists(path):
		print("Mascot: %d assertions, %d failures" % [checks, failures])
		quit(1)
		return
	var duck = load(path).new()
	root.add_child(duck)
	duck.size = Vector2(72, 72)
	check(duck.pose == 0, "Pip starts with an innocent resting expression")
	_check_idle_actions(duck)
	if DisplayServer.get_name() != "headless":
		await _check_drawn_idle_dances(duck)
	duck.set_speaking(true)
	check(duck.pose == 1, "Actual speech opens Pip's beak immediately")
	duck._process(0.15)
	check(duck.pose == 0, "Speech alternates beak poses without creating animation nodes")
	duck.set_speaking(false)
	check(duck.pose == 0, "Stopping speech closes the beak")
	for index in range(30):
		duck.react("happy")
	check(duck.reaction_left <= 0.65, "Rapid interactions replace rather than stack duck reactions")
	duck._process(0.8)
	check(is_zero_approx(duck.reaction_left), "Duck reactions finish on their own")
	duck.set_reduced_motion(true)
	duck.set_speaking(true)
	duck._process(0.5)
	check(duck.pose == 1 and duck.scale == Vector2.ONE, "Reduced motion uses a static speaking pose")
	duck.set_speaking(false)
	duck.react("happy")
	check(duck.scale == Vector2.ONE and is_zero_approx(duck.rotation), "Reduced-motion greetings never move the hit target")
	check(duck.pose == 3, "Reduced-motion greetings still give a static wave")
	duck.free()
	var app = load("res://scenes/main.tscn").instantiate()
	var integrated: bool = app.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "duck")
	check(integrated, "The duck is integrated into every native page")
	if integrated:
		var directory := "user://duck-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		DirAccess.make_dir_recursive_absolute(directory)
		app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
		app._mode_id = "match"
		preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
		# Godot consumes Escape to dismiss a hovered tooltip before scene input.
		# Keep this keyboard fixture independent of the inherited pointer position.
		var pointer := InputEventMouseMotion.new()
		pointer.position = Vector2(-100, -100)
		Input.parse_input_event(pointer)
		root.add_child(app)
		await process_frame
		await process_frame
		app.audio.halt()
		app._update_duck()
		check(app.duck.visible and not app.duck.speaking, "The board duck is idle without spoken audio")
		_check_quiet_side_effects(app, directory)
		var cards: Array = app.model.cards.duplicate(true)
		app.duck.pressed.emit()
		check(app.model.cards == cards and (app.model.matched_ids.size() / 2) == 0 and app.model.hints_remaining == 3,
			"Opening Pip's game-mode menu never changes game progress")
		check(app._mode_menu_open() and not app.audio.voice.playing,
			"The header Pip opens game modes without starting a companion trick or greeting")
		app._hide_mode_menu()
		var playing_phase: String = app.model.phase
		# This fixture exercises an earned chest; chance outcomes have separate coverage.
		app.model.chest_earned = true
		app.model.phase = "won"
		app._refresh()
		preload("res://tests/godot/player_flow_fixture.gd").finish_celebration(app)
		app._layout()
		await process_frame
		await process_frame
		app.audio.halt()
		app.duck.settle()
		app.duck.pressed.emit()
		check(app.model.cards == cards and (app.model.matched_ids.size() / 2) == 0 and app.model.hints_remaining == 3,
			"Playing with the result companion never changes earned game progress")
		check(not app.audio.voice.playing and (app.audio.pip_reaction == null or not app.audio.pip_reaction.playing),
			"Match result Pip performs its visual trick without a duck sound")
		check(app.duck._idle_action == "wave", "The Lv3 result companion performs its unlocked greeting")
		app.audio.halt()
		app.duck.settle()
		app.model.phase = playing_phase
		app._refresh()
		app._layout()
		app.audio.interact(app.model.theme_id, false)
		app.audio.cue("select")
		app._update_duck()
		check(not app.duck.speaking, "Sound effects do not make Pip pretend to speak")
		app.audio.say("res://" + app.model.cards[0].word.audio)
		app._update_duck()
		check(app.audio.voice.playing and app.duck.speaking, "Pip speaks with the actual pronunciation player")
		var selected: String = app.model.cards[0].id
		app.cards[selected].grab_focus()
		app.cards[selected].pressed.emit()
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		Input.parse_input_event(escape)
		await process_frame
		check(app.model.selected_id.is_empty(), "Escape still cancels a card with the mascot present")
		escape.pressed = false
		Input.parse_input_event(escape)
		app._show_collection()
		await process_frame
		app._update_duck()
		check(not app.duck.is_visible_in_tree() and not app.duck.speaking,
			"The word catalog hides the covered game's companion and stops its speech")
		app.duck.pressed.emit()
		app._update_duck()
		check(app.duck._idle_action.is_empty() and not app.audio.voice.playing,
			"A hidden companion cannot start an action or greeting over the word catalog")
		app.on_page_hidden()
		check(not app.duck.speaking, "Hiding the page silences Pip along with the audio")
		if app.duck.has_method("set_idle_paused"):
			check(not app.duck.is_processing(), "Background pages stop Pip's idle animation loop")
			app.on_page_visible()
			check(not app.duck.is_visible_in_tree()
				and not app.duck.speaking and app.audio.active and app.audio.music.playing
				and not app.audio.voice.playing and not app.audio.effect.playing,
				"Returning to the catalog restores music without revealing Pip or replaying old speech")
			await process_frame
			await process_frame
			check(not app.duck.is_processing() and app.audio.music.playing and not app.audio.voice.playing,
				"The catalog keeps its covered companion suspended after foreground recovery")
		app._hide_collection()
		app._on_voice_state([true, true, "Listening"])
		app._update_duck()
		check(app.duck.is_visible_in_tree() and app.duck.get_parent() == app._header_duck_art_slot
			and app.duck.tooltip_text == "Pip: change game mode"
			and app.duck.get("accessibility_name") == "Pip: change game mode. Current mode: Match",
			"Match voice input retains the visible, named Pip header trigger for game modes")
		app._stop_voice()
		app.audio.halt()
		app._update_duck()
		check(app.duck.is_visible_in_tree() and not app.duck.speaking
			and app.duck.tooltip_text == "Pip: change game mode",
			"Leaving voice mode keeps the quiet Pip game-mode trigger available")
		for dimensions in [Vector2i(320, 320), Vector2i(390, 844), Vector2i(844, 390)]:
			root.size = dimensions
			await process_frame
			await process_frame
			app._update_duck()
			check(root.get_visible_rect().encloses(app.duck.get_global_rect()), "The duck fits the supported viewport")
			var css_size: Vector2 = app.duck.size * app.Style.ui_scale(app)
			check(css_size.is_equal_approx(Vector2(52, 52)) and css_size.x >= 44,
				"Pip's compact header art retains its 52 CSS-pixel accessible touch target")
		# Headless frames can finish before the audio thread consumes its stop queue.
		await create_timer(0.1).timeout
		app.queue_free()
		await process_frame
		var files := DirAccess.open(directory)
		for filename in files.get_files():
			DirAccess.remove_absolute(directory + "/" + filename)
		DirAccess.remove_absolute(directory)
	else:
		app.free()
	print("Mascot: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_idle_actions(duck: Button) -> void:
	check(duck.has_method("set_idle_paused") and duck.has_method("set_proactive_allowed"),
		"Pip supports separately allowed autonomous gestures and page suspension")
	if not duck.has_method("set_idle_paused") or not duck.has_method("set_proactive_allowed"):
		return
	duck.set_proactive_allowed(true)
	var original_rect: Rect2 = duck.get_rect()
	var children: int = duck.get_child_count()
	var stable_bounds := true
	var gestures: Array[String] = []
	var previous := ""
	for step in range(1800):
		duck._process(0.1)
		stable_bounds = stable_bounds and duck.get_rect() == original_rect and duck.scale == Vector2.ONE \
			and is_zero_approx(duck.rotation) and duck.get_child_count() == children
		var action: String = duck._idle_action
		if not action.is_empty() and previous.is_empty():
			gestures.append(action)
		previous = action
		if gestures.size() == 4:
			break
	check(gestures == ["wave", "wave", "wave", "wave"],
		"The initial companion offers only the first unlocked greeting during quiet intervals")
	check(stable_bounds, "Autonomous motion preserves the button hit target and creates no effect or audio nodes")
	duck.set_speaking(true)
	check(duck._idle_action.is_empty(), "Pronunciation immediately interrupts idle gestures")
	for step in range(200):
		duck._process(0.1)
	check(duck._idle_action.is_empty(), "Pip never starts an idle gesture over sustained speech")
	duck.set_speaking(false)
	duck.react("happy")
	check(duck._idle_action.is_empty() and duck.pose == 3, "Player feedback takes priority over autonomous animation")
	duck.perform_trick("wave")
	duck._process(0.3)
	check(duck._idle_action == "wave" and duck._growth_action_manual, "An explicit trick stays in charge")
	duck.settle()
	duck._process(0.2)
	check(duck._idle_action.is_empty(), "Reset leaves a quiet interval before the next autonomous action")
	duck._process(60.0)
	check(duck._idle_action.is_empty(), "A stalled frame cannot replay missed idle actions")
	duck.set_idle_paused(true)
	for step in range(200):
		duck._process(0.1)
	check(duck._idle_action.is_empty() and not duck.is_processing(), "Page suspension stops both action and animation processing")
	duck.set_idle_paused(false)
	check(duck.is_processing(), "Returning to a visible page resumes the idle scheduler")
	duck.hide()
	check(duck._idle_action.is_empty() and not duck.is_processing(), "A hidden mascot has no idle work")
	duck.show()
	duck.set_reduced_motion(true)
	for step in range(200):
		duck._process(0.1)
	check(duck._idle_action.is_empty() and not duck.is_processing(), "Reduced motion suppresses all autonomous gestures")
	duck.set_reduced_motion(false)
	duck.settle()


func _capture_dance(viewport: SubViewport, duck: Button) -> Image:
	duck.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _major_pixel_difference_ratio(reference: Image, candidate: Image) -> float:
	if reference.is_empty() or candidate.is_empty() or reference.get_size() != candidate.get_size():
		return 1.0
	var reference_rgba: Image = reference.duplicate()
	var candidate_rgba: Image = candidate.duplicate()
	reference_rgba.convert(Image.FORMAT_RGBA8)
	candidate_rgba.convert(Image.FORMAT_RGBA8)
	var reference_bytes: PackedByteArray = reference_rgba.get_data()
	var candidate_bytes: PackedByteArray = candidate_rgba.get_data()
	var changed_pixels := 0
	for offset in range(0, reference_bytes.size(), 4):
		for channel in range(4):
			if absi(int(reference_bytes[offset + channel]) - int(candidate_bytes[offset + channel])) > 60:
				changed_pixels += 1
				break
	return float(changed_pixels) / (reference_bytes.size() / 4.0)


func _check_drawn_idle_dances(duck: Button) -> void:
	var evidence_directory := ProjectSettings.globalize_path("res://build/lively-pip-native")
	check(DirAccess.make_dir_recursive_absolute(evidence_directory) == OK, "Native dance evidence directory is available")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(168, 168)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var original_position: Vector2 = duck.position
	var original_size: Vector2 = duck.size
	var original_processing: bool = duck.is_processing()
	var original_filter: int = duck.mouse_filter
	duck.reparent(viewport)
	duck.position = Vector2(28, 28)
	duck.size = Vector2(112, 112)
	duck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	duck.settle()
	duck.set_proactive_allowed(true)
	duck.set_growth_level(12)
	var resting_image: Image = await _capture_dance(viewport, duck)
	check(resting_image.save_png(evidence_directory + "/idle.png") == OK, "The original resting mascot is saved for visual comparison")
	var resting: PackedByteArray = resting_image.get_data()
	var original_rect: Rect2 = duck.get_rect()
	var seen: Array[String] = []
	for kind in ["dance-wave", "dance-sway", "dance-hop"]:
		duck.settle()
		check(duck.perform_growth_action(kind), kind + " is unlocked for the mature companion")
		seen.append(kind)
		# The first real rendered frame must retain Pip's complete resting shape.
		# Tolerate small layering/filtering differences, but reject atlas crop/scale errors.
		var starting_image: Image = await _capture_dance(viewport, duck)
		var changed_ratio := _major_pixel_difference_ratio(resting_image, starting_image)
		check(changed_ratio < 0.08,
			"%s begins with Pip's complete resting proportions (%.2f%% major pixel differences)" % [kind, changed_ratio * 100.0])
		check(starting_image.save_png(evidence_directory + "/%s-0000ms.png" % kind) == OK,
			kind + " saves its initial complete silhouette for visual review")
		var frames: Array[PackedByteArray] = []
		var lower_frames: Array[PackedByteArray] = []
		var elapsed := 0.0
		var bounds_stable := true
		for at in [0.25, 0.8, 1.3, 1.9, 2.5]:
			while elapsed + 0.001 < at:
				duck._process(0.05)
				elapsed += 0.05
			var image: Image = await _capture_dance(viewport, duck)
			check(image.save_png(evidence_directory + "/%s-%04dms.png" % [kind, roundi(at * 1000.0)]) == OK,
				kind + " saves its actual rendered frame for independent visual review")
			var pixels: PackedByteArray = image.get_data()
			var lower: PackedByteArray = image.get_region(Rect2i(28, 92, 112, 48)).get_data()
			if not frames.has(pixels):
				frames.append(pixels)
			if not lower_frames.has(lower):
				lower_frames.append(lower)
			bounds_stable = bounds_stable and duck.get_rect() == original_rect \
				and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation)
		check(frames.size() >= 3 and not frames.has(resting), kind + " renders several distinct moving poses throughout its phrase")
		check(lower_frames.size() >= 3, kind + " visibly moves wings, body or feet rather than only blinking")
		check(bounds_stable, kind + " keeps the input bounds fixed throughout actual rendered motion")
		duck.settle()
		check((await _capture_dance(viewport, duck)).get_data() == resting,
			"Explicit cleanup removes every " + kind + " layer from the rendered mascot")
		if seen.size() == 3:
			break
	check(seen.size() == 3, "Actual rendered frames cover all three retained articulated dances")
	duck.set_reduced_motion(true)
	var still: PackedByteArray = (await _capture_dance(viewport, duck)).get_data()
	for step in range(240):
		duck._process(0.05)
	check((await _capture_dance(viewport, duck)).get_data() == still and duck._idle_action.is_empty(),
		"Reduced motion keeps the actual mascot pixels still beyond the next invitation interval")
	duck.set_reduced_motion(false)
	duck.settle()
	duck.set_growth_level(3)
	duck.reparent(root)
	duck.position = original_position
	duck.size = original_size
	duck.mouse_filter = original_filter
	duck.set_process(original_processing)
	viewport.queue_free()
	await process_frame


func _check_quiet_side_effects(app, directory: String) -> void:
	if not app.duck.has_method("set_proactive_allowed") or not app.duck.has_method("note_activity"):
		return
	var allowed_before: bool = app.duck._proactive_allowed
	var state_before: Array = _quiet_state(app)
	var labels: Array = app.find_children("*", "Label", true, false)
	var text_before: Array = labels.map(func(label: Label) -> String: return label.text)
	var players: Array = app.find_children("*", "AudioStreamPlayer", true, false)
	var audio_before: Array = players.map(func(player: AudioStreamPlayer) -> Array: return [player.playing, player.stream])
	var files_before := _saved_files(directory)
	var events: Array[String] = []
	var record_press := func() -> void: events.append("pressed")
	app.duck.pressed.connect(record_press)
	app.duck.settle()
	app.duck.set_proactive_allowed(true)
	app.duck.note_activity()
	var invitations := 0
	var offered: Array[String] = []
	var previous := ""
	for step in range(1000):
		app.duck._process(0.1)
		if not app.duck._idle_action.is_empty() and previous.is_empty():
			invitations += 1
			if not offered.has(app.duck._idle_action):
				offered.append(app.duck._idle_action)
		previous = app.duck._idle_action
	check(invitations >= 5 and offered == ["wave"], "The integrated Lv3 mascot repeatedly offers only its unlocked greeting")
	check(_quiet_state(app) == state_before and _saved_files(directory) == files_before,
		"Quiet invitations never alter learning progress, hints, rewards or saved files")
	check(events.is_empty() and labels.map(func(label: Label) -> String: return label.text) == text_before,
		"Quiet invitations emit no button activation or status caption")
	check(not app.audio.active and not app.duck.speaking
		and players.map(func(player: AudioStreamPlayer) -> Array: return [player.playing, player.stream]) == audio_before,
		"Quiet invitations never start audio, speech or a pronunciation")
	app.duck.pressed.disconnect(record_press)
	app.duck.note_activity()
	app.duck.set_proactive_allowed(allowed_before)


func _quiet_state(app) -> Array:
	return [app.model.cards.duplicate(true), app.model.phase, (app.model.matched_ids.size() / 2), app.model.mistakes,
		app.model.hints_remaining, app.medal_progress.counts.duplicate(true),
		app.growth.snapshot(), app.growth._streaks.duplicate(true)]


func _saved_files(directory: String) -> Dictionary:
	var files: Dictionary = {}
	for filename in DirAccess.get_files_at(directory):
		files[filename] = FileAccess.get_file_as_bytes(directory + "/" + filename)
	return files

extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const ChestCelebration = preload("res://scripts/jelly_chest_celebration.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const COIN_REWARD_SEED: int = 208
const RESPONSIVE_SIZES: Array[Vector2i] = [Vector2i(320, 480), Vector2i(393, 852), Vector2i(624, 1119),
	Vector2i(768, 1024), Vector2i(834, 1194), Vector2i(568, 320), Vector2i(844, 390),
	Vector2i(1366, 768), Vector2i(1473, 1175)]
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func pointer_event(point: Vector2, pressed: bool, touch: bool = false) -> void:
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event)
	await process_frame


func key_event(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		root.push_input(event)
		await process_frame


func controller_back_event() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_B
		event.pressed = pressed
		root.push_input(event)


func check_tab_reachability(view, context: String) -> void:
	view.set_process(false)
	view.cancel_input()
	check(view.game.drop_now(), "The keyboard fixture evolves the board with new supply in " + context)
	view.game.step(1.0)
	view._process(0.0)
	await pointer_event(view._global_rect(view._board).position - Vector2(2.0, 2.0), true)
	await pointer_event(view._global_rect(view._board).position - Vector2(2.0, 2.0), false)
	var remaining: Array[int] = []
	for id: int in view._tiles:
		if not view._tiles[id].disabled:
			remaining.append(id)
	var total: int = remaining.size()
	for index in range(128):
		await key_event(KEY_TAB)
		var focused: Control = root.gui_get_focus_owner()
		for id: int in remaining.duplicate():
			if view._tiles[id] == focused:
				remaining.erase(id)
		if remaining.is_empty():
			break
	check(total > 0 and remaining.is_empty(),
		"Repeated Tab reaches every settled jelly after new supply in %s; unreachable IDs: %s" % [context, remaining])
	view.set_process(true)


func check_input_focus(app) -> void:
	var original_size: Vector2i = root.size
	root.size = Vector2i(1366, 768)
	app._show_mode_menu()
	await settle()
	app._mode_panel.ensure_mode_visible("word_jelly")
	await settle()
	var mode_button: Button = app._mode_panel.button_for_mode("word_jelly")
	await pointer_event(mode_button.get_global_rect().get_center(), true)
	await pointer_event(mode_button.get_global_rect().get_center(), false)
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	check(app._mode_id == "word_jelly" and not app._mode_menu_open() and view.has_focus(),
		"A real mouse click starts Jelly Words with focus on the neutral board")
	check(view._tiles.values().all(func(tile) -> bool: return not tile.has_focus() and tile._mark == 0 \
		and not tile.selected and not tile.highlighted and not tile.completion_hint)
		and view._source == -1 and view._keyboard_source == -1,
		"Pointer entry does not paint an unsolicited selection, focus rim, or completion hint")
	var first: Control = view.navigation_controls()[0]
	await key_event(KEY_TAB)
	check(first.has_focus() and first._mark == 1 and not first.selected,
		"The first Tab from the neutral board focuses the first playable jelly without selecting it")
	await key_event(KEY_ENTER, true)
	check(view._keyboard_source == first.tile_id and first.selected and first._mark == 2,
		"Shift+Enter still intentionally selects the keyboard-focused jelly")
	await key_event(KEY_ESCAPE)
	check(view._keyboard_source == -1 and not first.selected,
		"Escape cancels the intentional keyboard selection")
	var next: Control = view.navigation_controls()[1]
	await pointer_event(next.get_global_rect().get_center(), true)
	check(not first.has_focus() and first._mark < 1 and view._source == next.tile_id,
		"A pointer gesture clears the old keyboard rim while selecting its own jelly")
	await pointer_event(next.get_global_rect().get_center(), false)
	app._show_mode_menu()
	await settle()
	app._mode_panel.ensure_mode_visible("word_jelly")
	await settle()
	var round_id: String = app._round_id
	await pointer_event(mode_button.get_global_rect().get_center(), true, true)
	await pointer_event(mode_button.get_global_rect().get_center(), false, true)
	await settle()
	check(not app._mode_menu_open() and app._round_id == round_id and view.has_focus()
		and view._tiles.values().all(func(tile) -> bool: return not tile.has_focus() and tile._mark == 0),
		"Touch Continue preserves the round without restoring an unsolicited jelly rim")
	view.set_process(true)
	app._pending_vocabulary_round = [405, false, "", "word_jelly", "", true]
	app._resume_vocabulary_round()
	await settle()
	view.set_process(false)
	check(view.has_focus() and view._tiles.values().all(func(tile) -> bool: return not tile.has_focus() and tile._mark == 0),
		"A delayed vocabulary handoff preserves neutral focus after pointer or touch entry")
	await key_event(KEY_RIGHT)
	check(view.default_focus().has_focus(),
		"The first direction key from a touch-started board reaches the first playable jelly (focus=%s, default=%s)"
		% [root.gui_get_focus_owner(), view.default_focus()])
	app._show_mode_menu()
	await settle()
	mode_button.grab_focus()
	await key_event(KEY_ENTER)
	await settle()
	check(not app._mode_menu_open() and view.default_focus().has_focus(),
		"Keyboard activation of Continue retains intentional focus on a playable jelly")
	app._show_mode_menu()
	app.choose_mode("match")
	app._show_mode_menu()
	await settle()
	mode_button.grab_focus()
	await key_event(KEY_ENTER)
	await settle()
	view.set_process(false)
	check(app._mode_id == "word_jelly" and not app._mode_menu_open() and view.default_focus().has_focus(),
		"Keyboard activation of a new Jelly Words round retains intentional tile focus")
	await pointer_event(view._global_rect(view._board).position - Vector2(2.0, 2.0), true)
	await pointer_event(view._global_rect(view._board).position - Vector2(2.0, 2.0), false)
	check(view.has_focus(), "Pointer takeover restores the neutral Jelly focus anchor")
	var idle_stick := InputEventJoypadMotion.new()
	idle_stick.axis = JOY_AXIS_LEFT_X
	for amount: float in [0.0, 0.20, -0.20]:
		idle_stick.axis_value = amount
		root.push_input(idle_stick)
	check(view.has_focus(), "Idle controller samples cannot add a focus rim to a pointer-started board")
	app._enter_controller_mode()
	check(view.default_focus().has_focus(),
		"Controller activation promotes the neutral board to a playable jelly")
	app._controller_mode = false
	await check_tab_reachability(view, "Jelly Words")
	Fixture.enter_mode(app, "jelly")
	await settle()
	await check_tab_reachability(app._jelly, "Jelly Match")
	view.cancel_input()
	view.set_process(true)
	root.size = original_size
	await settle()


func merged_word(view, word: Dictionary, fragments: int = 0, level: int = 1) -> Dictionary:
	var game = view.game
	for frame in range(400):
		if not game.powerup_active() and game._blast_queue.is_empty():
			break
		view._process(0.04)
	check(not game.powerup_active() and game._blast_queue.is_empty(),
		"The preceding collection's free matching settles before another manual word is built")
	# Existing persistence fixtures deliberately exercise the rare winning branch.
	game._coin_rng.seed = COIN_REWARD_SEED
	game.step(0.4)
	var pair: Array[int] = []
	for supply_attempt in range(20):
		for first: Dictionary in game.cells:
			if str(first.get("jelly_kind", "")) != "root" or str(first.get("word_candidate", {}).get("id", "")) != str(word.id):
				continue
			for second: Dictionary in game.cells:
				if str(second.get("jelly_kind", "")) == "picture" and str(second.image_word.id) == str(word.id) \
					and game.is_settled(first) and game.is_settled(second) and game.can_merge(first, second):
					pair.assign([int(first.id), int(second.id)])
					break
			if not pair.is_empty():
				break
		if not pair.is_empty():
			break
		game.drop_now()
		game.step(4.0)
	check(not pair.is_empty(), "Bounded real supply contains the requested text and exact word picture")
	if pair.is_empty():
		return {}
	for tile: Dictionary in game.cells:
		if int(tile.id) in pair:
			tile.fragments = fragments if int(tile.id) == pair[0] else 0
			tile.chest = int(tile.fragments) > 0
	check(game.try_merge(pair[0], pair[1]) == "merged", "The gameplay model accepts a word-picture merge")
	var result_id: int = int(game.fusions.back().result.id)
	game.step(game.FUSION_SECONDS + game.SETTLE_SECONDS * 2.0)
	var result: Dictionary = game.cell(result_id)
	check(not result.is_empty() and result.word.id == word.id, "The resulting word persists on the board")
	if level == 2:
		var partner: Dictionary = merged_word(view, word)
		check(game.try_merge(result.id, partner.id) == "merged", "A payment fixture upgrades two genuine Lv1 words to Lv2")
		result_id = int(game.fusions.back().result.id)
		game.step(game.FUSION_SECONDS + game.SETTLE_SECONDS * 2.0)
		result = game.cell(result_id)
		check(int(result.merge_level) == 2 and int(result.fragments) == fragments,
			"The eligible Lv2 payment fixture retains exactly its assigned fragments")
	return result


func check_finish_header(app, view) -> void:
	var original_size: Vector2i = root.size
	var reveal_word: Dictionary = app._learning_words()[0]
	for dimensions: Vector2i in RESPONSIVE_SIZES:
		root.size = dimensions
		await settle()
		var s: float = app.Style.ui_scale(app)
		var finish: Rect2 = view.finish_button.get_global_rect()
		var playfield: Rect2 = view.get_global_rect()
		var collect: Rect2 = view.collect_button.get_global_rect()
		var context: String = " at %s" % dimensions
		check(view.finish_button.is_visible_in_tree() and not view.finish_button.disabled
			and app._header.get_global_rect().grow(0.1).encloses(finish),
			"The active round places Finish inside the game header" + context)
		check(finish.end.y + 4.0 / s <= playfield.position.y + 0.1
			and collect.position.y - finish.end.y >= 16.0 / s - 0.1,
			"Finish is separated from the playfield and Collect words" + context)
		check(finish.size.x * s >= 44.0 - 0.1 and finish.size.y * s >= 44.0 - 0.1
			and not finish.intersects(app._mode_heading.get_global_rect()),
			"The header keeps a full touch target and an unobstructed mode title" + context)
		var bottom: float = maxf(view._global_rect(view._board).end.y, collect.end.y)
		for button: Control in view.powerup_buttons.values():
			bottom = maxf(bottom, button.get_global_rect().end.y)
		check(absf(bottom - (playfield.end.y - 12.0 / s)) < 0.1,
			"The board and collection controls retain twelve-pixel bottom padding" + context)
		var chest: Rect2 = view._global_rect(view.chest_meter_rect())
		var icon: Rect2 = view._global_rect(view.chest_anchor_rect())
		check(view.has_header_chest() and view._chest_tap.is_visible_in_tree()
			and app._header.get_global_rect().grow(0.1).encloses(chest),
			"The active chest belongs to the existing header instead of reserving a playfield band" + context)
		check(chest.is_equal_approx(view._chest_tap.get_global_rect()) and chest.encloses(icon)
			and chest.get_center().distance_to(icon.get_center()) < 0.1
			and chest.size.x * s >= 44.0 - 0.1 and chest.size.y * s >= 44.0 - 0.1,
			"The chest artwork remains centered inside its full-size meter and tap target" + context)
		check(view._reward_presentation._anchor.is_equal_approx(view.chest_anchor_rect()),
			"The milestone flight returns to the current local chest artwork anchor" + context)
		var header_neighbors: Dictionary = {"Pip profile": app._header_duck_slot.get_global_rect(),
			"Home": app._mode_heading_button.get_global_rect(), "mode title": app._mode_heading.get_global_rect(),
			"coin balance": app._coin_counter.get_global_rect(), "Finish": finish}
		for name: String in header_neighbors:
			check(not chest.intersects(header_neighbors[name]),
				"The header chest stays clear of " + name + context)
		var board: Rect2 = view._global_rect(view._board)
		# Inspect actual controls after their minimum sizes resolve, including
		# the hosted 320-pixel viewport where nominal footer widths can be smaller.
		var actions: Dictionary = {"Auto merge": view.powerup_buttons.auto_merge.get_global_rect(),
			"Collect": collect, "Treasure": view.powerup_buttons.fragments.get_global_rect()}
		var auto_merge: Rect2 = actions["Auto merge"]
		check(absf(collect.position.x - auto_merge.position.x) < 0.1
			and absf(auto_merge.position.y - collect.end.y - 20.0 / s) < 0.1,
			"Collect sits directly above Auto merge with a separate twenty-pixel divider band" + context)
		var divider_state: Dictionary = view.snapshot().get("action_divider", {})
		var divider_rect: Array = divider_state.get("rect", [])
		check(bool(divider_state.get("visible", false)) and divider_rect.size() == 4,
			"The free Collect action has a visible separator from the paid tools" + context)
		if divider_rect.size() == 4:
			var divider := Rect2(float(divider_rect[0]), float(divider_rect[1]), float(divider_rect[2]), float(divider_rect[3]))
			var divider_right: float = auto_merge.end.x if view._compact_hud else actions["Treasure"].end.x
			check(divider.size.x > 0.0 and divider.size.y > 0.0 and playfield.grow(0.1).encloses(divider)
				and divider.position.y >= collect.end.y and divider.end.y <= auto_merge.position.y,
				"The divider remains inside the empty band between free and paid actions" + context)
			check(absf(divider.position.x - auto_merge.position.x) < 0.1 and absf(divider.end.x - divider_right) < 0.1,
				"The divider spans the action rail or the complete paid-tool footer" + context)
		var action_names: Array = actions.keys()
		for action_index in range(action_names.size()):
			var action: Rect2 = actions[action_names[action_index]]
			check(playfield.grow(0.1).encloses(action) and not action.intersects(board),
				str(action_names[action_index]) + " fits the hosted playfield without covering the board" + context)
			for other_index in range(action_index + 1, action_names.size()):
				var other: Rect2 = actions[action_names[other_index]]
				var horizontal_gap: float = maxf(other.position.x - action.end.x, action.position.x - other.end.x)
				var vertical_gap: float = maxf(other.position.y - action.end.y, action.position.y - other.end.y)
				check(not action.intersects(other) and maxf(horizontal_gap, vertical_gap) >= 8.0 / s - 0.1,
					str(action_names[action_index]) + " and " + str(action_names[other_index])
					+ " retain eight display pixels between their actual touch targets" + context)
			if view._compact_hud:
				check(action.position.x >= board.end.x + 8.0 / s - 0.1
					and absf(action.position.x - collect.position.x) < 0.1,
					str(action_names[action_index]) + " shares one action rail to the right of the board" + context)
			else:
				check(action.position.y >= board.end.y - 0.1,
					str(action_names[action_index]) + " stays in the action footer beneath the board" + context)
				if action_names[action_index] != "Collect":
					check(absf(action.position.y - auto_merge.position.y) < 0.1,
						str(action_names[action_index]) + " stays in the paid-tool footer beneath the board" + context)
		_check_playfield_layout(view, s, context)
		if not view._compact_hud:
			check(chest.end.y <= playfield.position.y + 0.1,
				"Portrait treasure stays above the playfield and supply tray" + context)
			check(absf(collect.position.x - auto_merge.position.x) < 0.1 and collect.position.y >= board.end.y,
				"Hosted Collect remains above the left paid tool in the phone footer" + context)
			view._word_reveal.set_reduced_motion(false)
			view._word_reveal._rng.seed = 4821
			for index in range(3):
				view._word_reveal.present(reveal_word, view._picture(reveal_word), app.Style.GOOD)
				view._word_reveal.advance(0.10)
			check(view._word_reveal.is_visible_in_tree() and view._word_reveal.snapshot().entries.size() == 3,
				"Rapid collected words coexist beside the hosted chest" + context)
			for tick in range(16):
				for entry: Dictionary in view._word_reveal.snapshot().entries:
					var rect: Array = entry.rect
					var card := Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
					check(not card.intersects(chest) and not card.intersects(collect)
						and playfield.grow(0.1).encloses(card),
						"Every collected-word card stays clear of the chest and Collect action throughout its elastic motion" + context)
				view._word_reveal.advance(0.025)
			view._word_reveal.reset()
			view._word_reveal.set_reduced_motion(view.reduced_motion)
		if dimensions == Vector2i(624, 1119):
			check(view._pitch * s >= 90.0,
				"The reported portrait size keeps at least ninety display pixels per square cell")
		if dimensions == Vector2i(320, 480):
			check(view._pitch * s >= 30.0,
				"The small phone keeps at least thirty display pixels per board column beside the responsive action rail")
	root.size = original_size
	await settle()
	var source: Vector2 = view._tiles[int(view.game.cells[0].id)].get_global_rect().get_center()
	check(view._press(-1, source), "A settled root can begin the header Finish drag guard check")
	view._move(source + Vector2(24.0 / app.Style.ui_scale(app), 0))
	view._process(0.0)
	check(view._dragging and view.finish_button.disabled, "Dragging a root disables the header Finish target")
	view.finish_button.accessibility_requested.emit()
	check(view.game.phase == "playing" and app._round_result.is_empty(), "A Finish signal cannot end an owned board drag")
	view.cancel_input()
	view._refresh_controls()
	view.finish_button.accessibility_requested.emit()
	await settle()
	check(app._finish_confirmation_open() and view.game.phase == "playing" and view.game.paused,
		"A deliberate header Finish pauses the round for confirmation")
	app._finish_confirmation.finish_button.pressed.emit()
	await settle()
	check(view.game.phase == "finished" and app._round_end.is_active() and not app._settlement_dialog.is_visible_in_tree(),
		"Confirming Finish first presents the end effect over the frozen word board")
	Fixture.finish_celebration(app)
	check(view.game.phase == "finished" and app._settlement_dialog.is_visible_in_tree() and not view.snapshot().result.visible and not view.finish_button.is_visible_in_tree(),
		"The completed end effect opens settlement and removes the round action")
	app._jelly_rewards._back.pressed.emit()
	await settle()
	view._process(0.0)
	check(view.game.phase == "playing" and view.finish_button.is_visible_in_tree(), "Replay restores Finish to the active header")
	Fixture.enter_mode(app, "match")
	await settle()
	check(not view.finish_button.is_visible_in_tree(), "Switching to Match leaves no Jelly Words Finish in its header")
	Fixture.enter_mode(app, "word_jelly")
	await settle()
	check(view.finish_button.is_visible_in_tree(), "Returning to Jelly Words restores its own Finish control")


func check_size_paused_finish(app, view) -> void:
	var original_size: Vector2i = root.size
	root.size = Vector2i(568, 320)
	await settle()
	check(view._layout_too_small and view.game.paused and view.can_finish_round(),
		"A short landscape viewport pauses the authored board while keeping Finish available")
	var button = view.finish_button
	var start: Vector2 = button.get_global_rect().get_center()
	var end: Vector2 = start + Vector2(0, float(button.snapshot().threshold) * 1.15)
	var elapsed: float = view.game.spawn_elapsed
	var cells: Array = view.game.cells.duplicate(true)
	await pointer_event(start, true)
	view._process(1.0 / 60.0)
	check(button.is_pulling() and view.game.paused and view.game.spawn_elapsed == elapsed and view.game.cells == cells,
		"A real Finish press survives the next frame without advancing the size-paused board")
	view.pause(true)
	view._process(1.0 / 60.0)
	await pointer_event(end, false)
	check(not button.is_pulling() and not view.can_finish_round() and view.game.phase == "playing"
		and app._round_result.is_empty(),
		"An external pause cancels the size-paused Finish gesture and rejects its later release")
	view.pause(false)
	check(view.game.paused and view.can_finish_round() and button.is_visible_in_tree() and not button.disabled,
		"Clearing an external pause restores Finish while the small board stays paused")
	await pointer_event(start, true)
	view._process(1.0 / 60.0)
	var motion := InputEventMouseMotion.new()
	motion.position = end
	motion.global_position = end
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion)
	view._process(1.0 / 60.0)
	check(button.snapshot().armed and view.game.paused and view.game.spawn_elapsed == elapsed and view.game.cells == cells,
		"The size-paused Finish pull remains armed across frames while board state stays unchanged")
	await pointer_event(end, false)
	await settle()
	check(view.game.phase == "finished" and app._round_end.is_active() and not app._settlement_dialog.is_visible_in_tree(),
		"A size-paused Finish still presents its end effect before settlement")
	Fixture.finish_celebration(app)
	check(view.game.phase == "finished" and app._settlement_dialog.is_visible_in_tree() and not button.is_pulling(),
		"The size-paused end effect hands off to settlement")
	root.size = original_size
	app._jelly_rewards._back.pressed.emit()
	await settle()
	check(view.game.phase == "playing" and not view.game.paused,
		"Replay at the original viewport resumes a playable round after the size-paused finish")


func _check_playfield_layout(view, s: float, context: String) -> void:
	var bounds: Rect2 = view.get_global_rect().grow(0.1)
	var board: Rect2 = view._global_rect(view._board)
	var tray: Rect2 = view.drop_button.get_global_rect()
	var regions: Dictionary = {"board": board, "supply tray": tray,
		"Collect words": view.collect_button.get_global_rect()}
	for kind: String in view.powerup_buttons:
		regions[kind + " powerup"] = view.powerup_buttons[kind].get_global_rect()
	var names: Array = regions.keys()
	for index in range(names.size()):
		var rectangle: Rect2 = regions[names[index]]
		check(bounds.encloses(rectangle), str(names[index]) + " stays inside the playfield" + context)
		if names[index] != "board":
			check(rectangle.size.x * s >= 44.0 - 0.1 and rectangle.size.y * s >= 44.0 - 0.1,
				str(names[index]) + " retains a full touch target" + context)
		for next in range(index + 1, names.size()):
			check(not rectangle.intersects(regions[names[next]]),
				str(names[index]) + " stays clear of " + str(names[next]) + context)
	check(is_equal_approx(board.size.x / board.size.y, 5.0 / 8.0)
		and is_equal_approx(tray.position.x, board.position.x) and is_equal_approx(tray.size.x, board.size.x),
		"Five square-cell columns keep an aligned supply tray without stretching the board" + context)
	# The occupied width includes the single side rail when it enlarges the well.
	var occupied: Rect2 = board
	if view._compact_hud:
		for rectangle: Rect2 in regions.values():
			occupied = occupied.merge(rectangle)
	var horizontal_slack: float = view.size.x - occupied.size.x
	var top_slack: float = tray.position.y - view.global_position.y
	var stage_badge: Rect2 = view._stage_banner._label.get_global_rect()
	if view._stage_banner.visible and stage_badge.position.x < tray.end.x and stage_badge.end.y <= tray.position.y:
		top_slack -= stage_badge.size.y + 6.0 / s
	check(horizontal_slack * s <= 24.0 or top_slack * s <= 16.0,
		"The board uses the available width or height instead of leaving spare room in both directions" + context)


func check_rejected_drop_flow(app, view, word: Dictionary) -> void:
	var cues: Array[String] = []
	var spoken: Array[Dictionary] = []
	var observe_cue: Callable = func(cue: String) -> void: cues.append(cue)
	var observe_word: Callable = func(value: Dictionary) -> void: spoken.append(value)
	view.audio_requested.connect(observe_cue)
	view.word_requested.connect(observe_word)
	check(not word.is_empty(), "The flow fixture uses a real whole-word root")
	var wallet_before: int = app.coin_wallet.balance
	var growth_before: Dictionary = app.growth.snapshot().streaks.duplicate(true)
	for interruption: String in ["next_pick", "home", "finish_confirmation", "mute", "page_hidden", "round_end"]:
		var game = view.game
		game.cells.clear()
		var children: Array[Dictionary] = []
		for index in range(2):
			var child: Dictionary = game._new_word_root(word, index + 1)
			child.column = index * 4
			child.row = game.ROWS - 1
			game.cells.append(child)
			children.append(child.duplicate(true))
		view._sync_tiles()
		view._layout()
		game.spawn_interval = 10000.0
		app.audio.set_muted(false)
		# Direct board calls bypass GameUI's trusted-input audio activation.
		app.audio.interact(app.model.theme_id, false)
		check(app.audio.active, interruption + ": the fixture activates audio through the trusted interaction route")
		cues.clear()
		var source: int = int(children[1].id)
		var target: int = int(children[0].id)
		var from: Vector2 = view._tiles[source].get_global_rect().get_center()
		var to: Vector2 = view._tiles[target].get_global_rect().get_center()
		check(view._press(-1, from), interruption + ": a real held root starts the rejection flow")
		view._move(to)
		check(view._contact_state().kind == "touch" and cues.count("wrong") == 0
			and not app.audio.pair_feedback.playing, interruption + ": hover uses physical contact without a negative sound")
		view.cancel_input()
		view._release(to)
		check(cues.count("wrong") == 0 and game.fusions.is_empty(), interruption + ": cancellation never sounds or commits a wrong merge")
		view._press(-1, from)
		view._move(to)
		view._release(to)
		check(cues.count("wrong") == 1 and cues.count("merge") == 0 and cues.count("pop") == 0,
			interruption + ": committed rejection emits exactly one negative cue and no merge or disappearance cue")
		check(app.audio.pair_feedback.playing
			and app.audio.pair_feedback.stream == load("res://assets/imported-audio/pair-feedback/wrong.wav"),
			interruption + ": the application plays the existing negative feedback recording")
		check(not app.audio.voice.playing and spoken.is_empty(), interruption + ": rejection adds no spoken correction")
		check(game.fusions.is_empty() and game.cells.size() == 2 and game.collected_coins == 0 and game.fragment_count == 0
			and app.coin_wallet.balance == wallet_before and app.growth.snapshot().streaks == growth_before,
			interruption + ": failed merges cannot change wallet, learning progress, or chest progress")
		for child: Dictionary in children:
			var current: Dictionary = game.cell(int(child.id))
			check(current.text == child.text and current.mass == child.mass and current.fragments == child.fragments
				and view._tiles[int(child.id)].visible_fragment_badges() == int(child.fragments),
				interruption + ": rejection keeps each original body and its own chest fragments")
		match interruption:
			"next_pick":
				check(view._press(-1, from), "A new pick can begin immediately after a rejected drop")
				view.cancel_input()
			"home": app._show_mode_menu()
			"finish_confirmation": view.finish_button.accessibility_requested.emit()
			"mute": app.audio.set_muted(true)
			"page_hidden": app.on_page_hidden()
			"round_end": game.finish_round()
		check(not app.audio.pair_feedback.playing, interruption + ": interruption stops the negative recording immediately")
		check(cues.count("wrong") == 1 and spoken.is_empty(), interruption + ": stopping feedback never replays it or speaks a correction")
		match interruption:
			"home": app._hide_mode_menu()
			"finish_confirmation":
				check(app._finish_confirmation_open(), "Finish opens the existing confirmation while stopping feedback")
				app._finish_confirmation.keep_playing_button.pressed.emit()
			"mute": app.audio.set_muted(false)
			"page_hidden": app.on_page_visible()
			"round_end":
				check(game.phase == "finished" and not app._round_result.is_empty(),
					"Ending the round routes through the application result before silencing feedback")
				Fixture.finish_celebration(app)
				app._jelly_rewards._back.pressed.emit()
				view.set_process(false)
		check(game.phase == "playing" and not game.paused, interruption + ": continuing returns to the same playable word round")
		view.cancel_input()
		view._process(0.0)
	view.audio_requested.disconnect(observe_cue)
	view.word_requested.disconnect(observe_word)
	check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, true, 405),
		"The integration fixture restores its real current-age supply after the rejection checks")
	app._sync_jelly()
	view.set_process(false)


func check_finish_visibility_stable(view, expected_visible: bool, context: String) -> void:
	var changes: Array[bool] = []
	var observe: Callable = func() -> void: changes.append(view.finish_button.visible)
	view.finish_button.visibility_changed.connect(observe)
	for index in range(6):
		view._refresh_controls()
	view.finish_button.visibility_changed.disconnect(observe)
	check(changes.is_empty() and view.finish_button.is_visible_in_tree() == expected_visible,
		"Repeated refreshes preserve Finish visibility without triggering header reflow " + context)


func check_collection_mastery(app, view, word: Dictionary) -> void:
	var game = view.game
	var word_ids: Array[String] = [str(word.id)]
	check(app.growth.streak(word.id) == 0, "The collection mastery fixture starts with an unlearned word")
	for attempt in range(3):
		game.spawn_interval = 10000.0
		var merged: Dictionary = merged_word(view, word)
		game._coin_rng.seed = 0
		check(app.growth.streak(word.id) == attempt and not app.growth.is_mastered(word.id),
			"Merging alone does not advance the word's saved mastery")
		var open_home: Callable = func(_id: String, _word: Dictionary, _coins: int, _fragments: int, _origin: Vector2) -> void:
			app._show_mode_menu()
		view.collected.connect(open_home, CONNECT_ONE_SHOT)
		check(game.collect(merged.id), "The merged word starts a zero-coin collection")
		var event_id: String = str(game.fusions.back().attempt_id)
		game.step(game.COLLECT_SECONDS)
		check(game.cell(merged.id).is_empty() and app._mode_menu_open(),
			"Collection completes even when its presentation callback opens Home")
		check(app.growth.streak(word.id) == attempt + 1 and app.growth.is_mastered(word.id) == (attempt == 2),
			"Each committed collection is saved before Home pauses the board; the third grants mastery")
		app._hide_mode_menu()
		view.word_attempted.emit(event_id, word_ids, true)
		check(app.growth.streak(word.id) == attempt + 1,
			"Replaying the collection receipt cannot count the word twice")
	var reloaded = preload("res://scripts/growth_state.gd").new(app.growth._path)
	check(reloaded.configure(app.data.words) and reloaded.load_state() and reloaded.is_mastered(word.id),
		"Collection mastery survives reopening saved progress")
	app.growth.record_attempt("collection-mastery-reset", word_ids, false)
	check(app.new_round(407, false, "", "word_jelly"), "Paused settlement starts in its own round namespace")
	check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, true, 405),
		"Paused settlement uses a current-age word")
	app._sync_jelly()
	view.set_process(false)
	app.growth.record_attempt("collection-mastery-seed-1", word_ids, true)
	app.growth.record_attempt("collection-mastery-seed-2", word_ids, true)
	var merged: Dictionary = merged_word(view, word, 0, 2)
	var credit: Callable = game.credit_collection
	game.credit_collection = func(event_id: String, amount: int) -> Dictionary:
		var result: Dictionary = credit.call(event_id, amount)
		app._show_mode_menu()
		return result
	check(game.collect(merged.id), "The paid collection starts before Home interrupts its completion")
	var old_receipt: String = app._round_id + ":" + str(game.fusions.back().attempt_id)
	game.step(game.COLLECT_SECONDS)
	check(game.paused and game.fusions.size() == 1 and game.fusions[0].credited and app.growth.streak(word.id) == 2,
		"A saved coin reward leaves its paused word awaiting collection, without early mastery")
	game.credit_collection = credit
	app.choose_mode("match")
	check(app._mode_id == "match" and app.growth.is_mastered(word.id),
		"Switching modes settles the accepted collection and records mastery for the old round")
	var duplicate: Dictionary = app.growth.record_attempt(old_receipt, word_ids, true)
	check(duplicate.duplicate and app.growth.streak(word.id) == 3,
		"Paused settlement keeps the original collection receipt for deduplication")
	# Restore the learning and wallet baseline expected by the following reward fixtures.
	app.growth.record_attempt("collection-mastery-fixture-reset", word_ids, false)
	check(app.coin_wallet.spend("collection-mastery-fixture-coins", 50).ok, "Restore the isolated fixture's wallet")
	check(app.new_round(408, false, "", "word_jelly"), "Reward fixtures resume in a fresh Jelly Words round")
	check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, true, 405),
		"Reward fixtures restore their current-age word")
	app._sync_jelly()
	view.set_process(false)


func check_ordinary_collection(app, view, word: Dictionary) -> void:
	var game = view.game
	game.spawn_interval = 10000.0
	var merged: Dictionary = merged_word(view, word, 2)
	game._coin_rng.seed = 0
	app._coin_flight.sync(app.coin_wallet.balance)
	app.audio.interact(app.model.theme_id, false)
	app.audio.stop_voice()
	var balance: int = app.coin_wallet.balance
	var receipts: Dictionary = app.coin_wallet._receipts.duplicate()
	var saved: Variant = app.coin_wallet._saved_text
	var streak: int = int(app.growth.snapshot().streaks.get(word.id, 0))
	var coin_cues: Array[String] = []
	var on_release: Callable = func() -> void: coin_cues.append("release")
	var on_arrival: Callable = func() -> void: coin_cues.append("arrival")
	app._coin_flight.release_sound.connect(on_release)
	app._coin_flight.arrival_sound.connect(on_arrival)
	app.coin_wallet.ready = false
	check(game.collect(merged.id), "An ordinary merged word accepts collection while coin storage is unavailable")
	game.step(game.COLLECT_SECONDS)
	app._coin_flight.advance(2.0)
	check(game.cell(merged.id).is_empty() and game.cleared_pairs == 1 and game.collected_coins == 0
		and game.error.is_empty(), "The ordinary pickup completes without a coin award or a wallet error")
	check(app.coin_wallet.balance == balance and app.coin_wallet._receipts == receipts
		and app.coin_wallet._saved_text == saved and app.coin_wallet.error.is_empty(),
		"An ordinary pickup does not create a zero-value receipt or touch unavailable coin storage")
	check(game.fragment_count == 2 and int(app.growth.snapshot().streaks.get(word.id, 0)) == streak + 1,
		"Removing an ordinary word retains every carried fragment and its learning answer")
	check(not app._coin_flight.snapshot().active and app._word_jelly_credits.is_empty()
		and app._coin_counter.target == balance and coin_cues.is_empty(),
		"An ordinary pickup creates no coin burst, HUD deposit, counter increment, or coin sound")
	for player: AudioStreamPlayer in app.audio._coin_players:
		check(not player.playing, "Ordinary collection leaves every coin audio channel silent")
	app._coin_flight.release_sound.disconnect(on_release)
	app._coin_flight.arrival_sound.disconnect(on_arrival)
	check(app.coin_wallet.load_state(), "Coin storage can recover after a successful ordinary collection")
	check(app.new_round(406, false, "", "word_jelly"), "Rare-drop fixtures resume in a fresh round namespace")
	check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, true, 405),
		"Rare-drop fixtures restore the same current-age vocabulary after ordinary collection")
	app._sync_jelly()
	view.set_process(false)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 800)
	var directory := "user://word-jelly-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	Fixture.enter_mode(app, "match")
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	await check_input_focus(app)
	check(app.new_round(405, false, "", "word_jelly"), "The new mode starts through the application route")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	check(app._active_jelly() == view and view.is_visible_in_tree() and not app._jelly.is_visible_in_tree(), "Only the selected Jelly board is visible")
	check(app._jelly_backdrop.visible and app._mode_heading.text.begins_with("Jelly Words"), "The new game has its heading and shared woodland")
	check(app._round_id.begins_with("word_jelly:"), "Word treasure and coin receipts use a distinct round namespace")
	await check_finish_header(app, view)
	await check_size_paused_finish(app, view)
	var vocabulary: Array = app._learning_words()
	var word: Dictionary = vocabulary.filter(func(item: Dictionary) -> bool: return str(item.text).length() >= 2 and str(item.text).length() <= 6)[0]
	check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, true, 405), "The integration fixture uses a real current-age word")
	app._sync_jelly()
	app.audio.set_muted(false)
	view.word_requested.emit(word)
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + str(word.audio)), "The new mode routes a complete word to its exact pronunciation")
	app.audio.halt()
	check_rejected_drop_flow(app, view, word)
	check_collection_mastery(app, view, word)
	check_ordinary_collection(app, view, word)
	app.audio.set_muted(true)
	var game = view.game
	game.spawn_interval = 10000.0
	var prior_wallet_coins: int = app.coin_wallet.balance
	var prior_combo_coins: int = game.combo_coins
	var initial_streak: int = int(app.growth.snapshot().streaks.get(word.id, 0))
	var merged: Dictionary = merged_word(view, word, 2, 2)
	check(game.fragment_count == 0 and app.coin_wallet.balance == prior_wallet_coins + game.combo_coins - prior_combo_coins,
		"Merging saves its exact combo coins while keeping carried fragments and collection bonuses uncollected")
	check(game.collect(merged.id), "A valid word can be collected through the shared view model")
	var receipt_event: String = str(game.fusions.back().attempt_id)
	game.step(game.COLLECT_SECONDS)
	check(game.cell(merged.id).is_empty() and app.coin_wallet.balance == 50 + prior_wallet_coins + game.combo_coins - prior_combo_coins,
		"A Lv2 word's reserved drop adds its fifty collection bonus coins to the saved combo rewards")
	check(game.fragment_count == 2 and int(app.growth.snapshot().streaks.get(word.id, 0)) == initial_streak + 1, "The collection credits every carried fragment and one learning answer")
	check(app._coin_flight.snapshot().active, "The rare coin drop launches the shared coin flight")
	var duplicate: Dictionary = app._credit_word_jelly(receipt_event, 50)
	app._word_jelly_collected(receipt_event, word, 50, 2, Vector2.ZERO)
	check(duplicate.ok and duplicate.duplicate and app.coin_wallet.balance == 50 + prior_wallet_coins + game.combo_coins - prior_combo_coins,
		"A retried collection receipt cannot pay twice or repeat a combo reward")
	var growth_before: Dictionary = app.growth.snapshot().streaks.duplicate()
	app._jelly.word_attempted.emit("hidden-match", [str(word.id)] as Array[String], true)
	app._jelly.round_finished.emit({"score": 900, "chest_count": 1, "chest_tier": 6})
	check(app.growth.snapshot().streaks == growth_before and app._round_result.is_empty(), "Hidden Jelly Match callbacks cannot change this mode's progress or result")
	merged = merged_word(view, word, 2, 2)
	check(game.collect(merged.id), "The next complete word accepts collection")
	game.step(0.1)
	var paused_time: float = float(game.fusions.back().elapsed)
	app._show_mode_menu()
	game.step(2.0)
	check(game.paused and app.coin_wallet.balance == 50 + prior_wallet_coins + game.combo_coins - prior_combo_coins
		and is_equal_approx(float(game.fusions.back().elapsed), paused_time), "The library freezes a pending collection before its wallet commit")
	check(not view.finish_button.is_visible_in_tree(), "Home hides the hosted Finish action while the round is paused")
	check_finish_visibility_stable(view, false, "on Home")
	app._hide_mode_menu()
	check(view.finish_button.is_visible_in_tree(), "Returning from Home restores the active Finish action")
	check_finish_visibility_stable(view, true, "during play")
	app.set_reduced_motion(false)
	game.step(game.COLLECT_SECONDS)
	check(not game.paused and game.fragment_count == 4 and game.chest_tier == 1
		and app.coin_wallet.balance == 100 + prior_wallet_coins + game.combo_coins - prior_combo_coins,
		"Returning to play completes collection and unlocks the first chest")
	check(view._reward_presentation.snapshot().kind == "synthesis", "The first chest uses the shared fragment-synthesis presentation")
	view.advance_reward_presentation(ChestCelebration.ARRIVAL_SECONDS + ChestCelebration.REVEAL_SECONDS + 0.03)
	check(not app._reward_confetti.is_active(), "Chest acquisition keeps its reveal without launching stage confetti")
	var reward_elapsed: float = float(view._reward_presentation.snapshot().elapsed)
	app._show_mode_menu()
	check(game.paused and not view._reward_presentation._flight_surface.is_visible_in_tree(),
		"Home hides the independent chest flight layer while retaining its earned reward")
	app._hide_mode_menu()
	check(not game.paused and view._reward_presentation._flight_surface.is_visible_in_tree()
		and is_equal_approx(float(view._reward_presentation.snapshot().elapsed), reward_elapsed),
		"Returning from Home restores the same in-progress chest flight")
	app._show_collection()
	check(game.paused and not view._reward_presentation._flight_surface.is_visible_in_tree(),
		"The vocabulary page is never covered by a paused chest flight")
	check(not view.finish_button.is_visible_in_tree(), "Vocabulary hides the hosted Finish action")
	app._hide_collection()
	check(not game.paused and view._reward_presentation._flight_surface.is_visible_in_tree()
		and is_equal_approx(float(view._reward_presentation.snapshot().elapsed), reward_elapsed),
		"Closing vocabulary resumes the original flight without replaying its reveal")
	view.advance_reward_presentation(ChestCelebration.PERFORMANCE_SECONDS - ChestCelebration.REVEAL_SECONDS)
	merged = merged_word(view, word, 1, 2)
	var save_test_size: Vector2i = root.size
	root.size = Vector2i(320, 480)
	await settle()
	view._process(0.0)
	var normal_board: Rect2 = view._board
	var normal_tray: Rect2 = view._preview_rect
	var wallet_path: String = app.coin_wallet._path
	app.coin_wallet._path = directory + "/missing/coins.cfg"
	check(game.collect(merged.id), "A word reserves its collection before storage is attempted")
	var retry_event: String = str(game.fusions.back().attempt_id)
	game.step(game.COLLECT_SECONDS)
	check(not game.cell(merged.id).is_empty() and app.coin_wallet.balance == 100 + prior_wallet_coins + game.combo_coins - prior_combo_coins
		and game.fragment_count == 4, "A failed wallet write keeps the word and its fragments recoverable")
	view._process(0.0)
	await settle()
	var notice: Rect2 = view._notice.get_global_rect()
	check(view._notice.is_visible_in_tree() and view._notice.text == game.error and not game.error.is_empty(),
		"A real failed collection exposes its retry instruction on the short phone")
	check(view.get_global_rect().grow(0.1).encloses(notice),
		"The failed-save instruction stays within the short phone playfield")
	var error_regions: Array[Rect2] = [view._global_rect(view._board), view.drop_button.get_global_rect(),
		view.collect_button.get_global_rect()]
	for button: Control in view.powerup_buttons.values():
		error_regions.append(button.get_global_rect())
	for region: Rect2 in error_regions:
		check(not notice.intersects(region) and view.get_global_rect().grow(0.1).encloses(region),
			"The failed-save instruction leaves incoming roots, the board, and actions visible and inside the short phone")
	app.coin_wallet._path = wallet_path
	check(app.coin_wallet.load_state(), "The wallet reloads after storage recovers")
	app._refresh()
	check(game.collect(merged.id) and str(game.fusions.back().attempt_id) == retry_event, "Retrying the same word keeps its original receipt identity")
	game.step(game.COLLECT_SECONDS)
	check(game.cell(merged.id).is_empty() and app.coin_wallet.balance == 150 + prior_wallet_coins + game.combo_coins - prior_combo_coins
		and game.fragment_count == 5, "The successful retry credits coins and fragments once")
	view._process(0.0)
	await settle()
	check(game.error.is_empty() and not view._notice.is_visible_in_tree(),
		"A successful saved collection removes the retry instruction")
	check(view._board.is_equal_approx(normal_board) and view._preview_rect.is_equal_approx(normal_tray),
		"Recovery returns the temporary instruction space to the board and supply tray")
	root.size = save_test_size
	await settle()
	app.on_page_hidden()
	var spawn_before: float = game.spawn_elapsed
	game.step(2.0)
	check(game.paused and game.spawn_elapsed == spawn_before and not app._jelly_backdrop.visible, "Backgrounding freezes the word board and its scenery")
	app.on_page_visible()
	check(not game.paused, "The word board resumes when its page returns")
	app._show_collection()
	check(game.paused and app.collection_page.visible and not app._jelly_interaction_allowed(), "The vocabulary page pauses and blocks the new board")
	app._hide_collection()
	check(not game.paused and view.is_visible_in_tree(), "Closing vocabulary restores the current word board")
	app.set_reduced_motion(false)
	check(not view.reduced_motion, "Motion preferences reach the new mode")
	for index in range(2):
		merged = merged_word(view, word, 2, 2)
		check(game.collect(merged.id), "Another word can contribute to the same chest")
		game.step(game.COLLECT_SECONDS)
	check(game.fragment_count == 9 and game.chest_tier == 2, "Additional collections upgrade the earned chest")
	check(view._reward_presentation.snapshot().kind == "upgrade", "The next chest tier uses the enlarged spinning upgrade presentation")
	view.advance_reward_presentation(ChestCelebration.ARRIVAL_SECONDS + ChestCelebration.REVEAL_SECONDS + 0.03)
	check(not app._reward_confetti.is_active(), "Chest upgrades do not launch stage confetti")
	var earned_round: String = app._round_id
	var earned_combo_balance: int = prior_wallet_coins + game.combo_coins - prior_combo_coins
	Fixture.enter_mode(app, "jelly")
	await settle()
	check(app._mode_id == "jelly" and app._jelly_rewards_shown and app._jelly_rewards.has_pending(), "Switching Jelly games preserves and opens the saved treasure room")
	check(not view.finish_button.is_visible_in_tree(), "The treasure room and the other Jelly mode cannot expose Jelly Words Finish")
	check(app._jelly_rewards.rewards.entries[0].tier == 2 and app._jelly_rewards.rewards.round_id == earned_round
		and app._jelly_rewards.rewards.entries[0].reward_id == "jelly:" + earned_round + ":0", "The saved reward retains the exact upgraded tier and mode namespace")
	var earned_chest_reward: Dictionary = app.coin_wallet.chest_reward("jelly:" + earned_round + ":0").duplicate(true)
	growth_before = app.growth.snapshot().streaks.duplicate()
	view.word_attempted.emit("hidden-words", [str(word.id)] as Array[String], true)
	check(app.growth.snapshot().streaks == growth_before, "A stopped Jelly Words callback cannot credit Jelly Match")
	check(app.coin_wallet.balance == 250 + earned_combo_balance,
		"Switching modes preserves every rare word bonus and exact combo coin from the winning fixtures")
	Fixture.enter_mode(app, "word_jelly")
	view.set_process(false)
	await settle()
	var room = app._jelly_rewards
	var restored_board_id: String = app._round_id
	check(app._jelly_rewards_shown and app._settlement_dialog.is_visible_in_tree()
		and app._settlement_dialog.is_ancestor_of(room) and app._settlement_dialog.snapshot().title == "Your treasure",
		"Returning to Jelly Words restores saved treasure inside the shared modal")
	check(view.is_visible_in_tree() and view.game.paused and view.game.phase == "playing"
		and app._jelly_backdrop.is_visible_in_tree() and not view.finish_button.is_visible_in_tree(),
		"The restored Jelly Words modal keeps its fresh board visible and blocks gameplay controls")
	check(app._round_result.is_empty() and room.snapshot().result_context.is_empty()
		and not room._result_score.is_visible_in_tree(),
		"Restored Jelly Words treasure does not fabricate a score for the new board")
	app.on_page_hidden()
	check(not app._settlement_dialog.is_visible_in_tree() and room._paused,
		"Backgrounding hides and pauses the restored Jelly Words modal")
	app.on_page_visible()
	check(app._settlement_dialog.is_visible_in_tree() and app._settlement_dialog.is_ancestor_of(room)
		and app._round_id == restored_board_id and view.game.paused,
		"Foregrounding restores the same saved modal without starting or finishing a board")
	app.set_reduced_motion(true)
	room.set_process(false)
	room._cards[0].button.grab_focus()
	app._controller_accept()
	room.advance_hold(0.2)
	check(room.snapshot().holding and app._controller_holding_jelly_chest,
		"Controller Accept starts a cancellable hold on the restored chest")
	controller_back_event()
	check(not room.snapshot().holding and not app._controller_holding_jelly_chest
		and app._settlement_dialog.is_visible_in_tree() and room.has_pending()
		and app.coin_wallet.balance == 250 + earned_combo_balance,
		"Controller Back cancels an incomplete restored chest hold without claiming or closing the modal")
	room.begin_hold(room._cards[0].button)
	room.advance_hold(Feel.HOLD_SECONDS)
	check(not room.has_pending() and app.coin_wallet.balance == 250 + earned_combo_balance + int(earned_chest_reward.get("total", -1))
		and room.rewards.entries[0].reward_id == "jelly:" + earned_round + ":0"
		and app.coin_wallet.chest_reward("jelly:" + earned_round + ":0") == earned_chest_reward,
		"The restored tier-two chest keeps its original receipt and credits its reserved Pip-adjusted amount")
	controller_back_event()
	check(not app._settlement_dialog.is_visible_in_tree() and not app._jelly_rewards_shown
		and not app._mode_menu_open() and view.is_visible_in_tree() and not view.game.paused
		and app._round_id == restored_board_id and app._round_result.is_empty()
		and view.finish_button.is_visible_in_tree(),
		"Controller Back after claiming restores Jelly Words input on the same fresh board and closes the modal")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly Words application flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

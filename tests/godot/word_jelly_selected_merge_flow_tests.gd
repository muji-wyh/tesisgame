extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
var checks: int = 0
var failures: int = 0
var seed_value: int = 1900


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await process_frame


func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	await settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-revision")
	check(root.get_texture().get_image().save_png("res://build/qa/jelly-revision/" + name + ".png") == OK,
		"Capture the actual " + name)


func prepare(app) -> Array:
	seed_value += 1
	check(app.new_round(seed_value, false, "", "word_jelly"), "Start the actual application's Word Jelly route")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	var words: Array = app._learning_words().filter(func(word: Dictionary) -> bool:
		return not str(word.get("image", "")).is_empty()).slice(0, 2).map(
			func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(view.configure(words, app.growth.learning_age(), Data.theme(app.model.theme_id),
		app.data.chests, false, seed_value), "Use current-age production words, pictures and the real control layout")
	check(view.game.bind_stage(Catalog.make_plan(1, words, app.growth.learning_age(), seed_value)),
		"Bind actual pending word goals before testing their paid actions")
	view.set_stage_progress(view.game.stage_run.snapshot())
	view.game.cells.clear()
	view.game.spawn_interval = 10000.0
	view.game._stage_spawn_interval = 10000.0
	for index in range(4):
		var tile: Dictionary = view.game._new_word_root(words[index / 2]) if index % 2 == 0 \
			else view.game._new_picture_tile(words[index / 2])
		put(view.game, tile)
	Fixture.unlock_auto_collect(app)
	app._sync_jelly()
	view.set_process(false)
	view._sync_tiles()
	view._layout()
	view._process(0.0)
	for frame in range(100):
		if not view._stage_banner.ready_pending():
			break
		view._process(0.05)
	view._refresh_controls()
	await settle()
	return words


func goal_button(view, word_id: String) -> Button:
	for item: Dictionary in view.snapshot().practice.words:
		if str(item.get("word_id", item.id)) == word_id:
			return view._practice_panel.button_for_goal(str(item.id))
	return null


func move_mouse(at: Vector2, buttons: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.button_mask = buttons
	root.push_input(motion)
	await process_frame


func put(model, tile: Dictionary) -> void:
	var at: Vector2i = model._free_position(model._occupied(), 1, 1)
	tile.column = at.x
	tile.row = at.y
	tile.age = 100.0
	tile.settling = false
	tile.arrival = false
	model.cells.append(tile)


func test_auto_hover(app) -> void:
	root.size = Vector2i(1366, 768)
	await settle()
	app.set_reduced_motion(false)
	var words: Array = await prepare(app)
	check(app.coin_wallet.credit_amount("fixture:auto-hover-funding", 200).ok, "Fund only this isolated Auto merge use")
	app._coin_flight.sync(app.coin_wallet.balance)
	var view = app._word_jelly
	var model = view.game
	model.cells.clear()
	for index in range(6):
		var definition: Dictionary = words[0 if index < 4 else 1]
		for tile: Dictionary in [model._new_word_root(definition), model._new_picture_tile(definition)]:
			put(model, tile)
	view._sync_tiles()
	view._layout()
	view._refresh_controls()
	var button = view.powerup_buttons.auto_merge
	button.release_focus()
	await move_mouse(Vector2(1300, 40))
	var before: Dictionary = model.snapshot()
	var balance: int = app.coin_wallet.balance
	var receipts: int = app.coin_wallet._receipts.size()
	var expected: Array = model.auto_merge_preview().input_ids
	await capture("auto-merge-preview-idle")
	await move_mouse(button.get_global_rect().get_center())
	check(view.snapshot().auto_merge_hover.active and view.snapshot().auto_merge_hover.input_ids == expected
		and expected.size() == 6 and button.snapshot().preview_active,
		"A genuine Auto merge hover names only the next complete products: " + JSON.stringify({
			"preview": view.snapshot().auto_merge_hover, "expected": expected,
			"hovered": button.is_hovered(), "consumed": button._preview_consumed,
			"disabled": button.disabled, "goal": view.snapshot().goal_hover}))
	check(model.snapshot() == before and app.coin_wallet.balance == balance
		and app.coin_wallet._receipts.size() == receipts,
		"Entering the real button neither spends, pauses, allocates a receipt nor changes the board")
	for tile: Dictionary in model.cells:
		var visual = view._tiles[int(tile.id)]
		check(visual.completion_hint == (int(tile.id) in expected)
			and visual.match_dimmed == (int(tile.id) not in expected),
			"Forecasted ingredients reuse the real matching halo while unused same-family bodies remain unselected")
	view._process(0.1)
	check(is_equal_approx(model.stage_run.elapsed, float(before.campaign.time_elapsed) + 0.1)
		and not model.powerup_active(), "Hover cannot freeze the stage or secretly begin an automatic use")
	await capture("auto-merge-preview-hover")
	var removed: Dictionary = model.cells[1]
	model.cells.remove_at(1)
	model.changed.emit()
	check(view.snapshot().auto_merge_hover.input_ids == model.auto_merge_preview().input_ids
		and int(removed.id) not in view.snapshot().auto_merge_hover.input_ids,
		"Live board changes refresh hover targets instead of keeping a vanished ingredient highlighted")
	model.cells.insert(1, removed)
	model.changed.emit()
	expected = model.auto_merge_preview().input_ids
	await move_mouse(Vector2(1300, 40))
	check(not view.snapshot().auto_merge_hover.active and view._tiles.values().all(
		func(tile) -> bool: return not tile.completion_hint and not tile.match_dimmed),
		"Leaving the Auto merge target restores all original acquired gel surfaces")
	button._pointer_input = false
	button.grab_focus()
	await process_frame
	check(view.snapshot().auto_merge_hover.input_ids == expected, "Keyboard/controller focus exposes the same legal input prediction")
	view._fill_button.grab_focus()
	await process_frame
	check(not view.snapshot().auto_merge_hover.active, "Focus navigation removes the old Auto merge prediction")
	var saved_balance: Callable = view.coin_balance
	view.coin_balance = func() -> int: return 0
	view._refresh_controls()
	await move_mouse(button.get_global_rect().get_center())
	check(view.snapshot().auto_merge_hover.active and not button.snapshot().affordable
		and app.coin_wallet.balance == balance,
		"An unaffordable preview is still free and never masquerades as a paid use")
	view.coin_balance = saved_balance
	view._refresh_controls()
	await click(button)
	check(model.powerup_active() and model.hit_stop_snapshot().active
		and not view.snapshot().auto_merge_hover.active and not button.has_focus(),
		"Accepted pointer activation consumes its preview and keeps the existing immediate hit-stop")
	model.finish_powerup()
	view._process(0.0)
	var consumed: Array = model._powerup.used_input_ids.keys()
	consumed.sort()
	expected.sort()
	check(consumed == expected and app.coin_wallet.balance == balance - 200
		and model.powerup_snapshot().completed_results == 3,
		"The saved actual click consumes exactly the highlighted originals for one existing price")
	check(not view.snapshot().auto_merge_hover.active and view._tiles.values().all(
		func(tile) -> bool: return not tile.completion_hint and not tile.match_dimmed),
		"Finishing the paid use cannot latch mouse-acquired focus or leave an eternal selection")
	await move_mouse(Vector2(1300, 40))
	await move_mouse(button.get_global_rect().get_center())
	check(view.snapshot().auto_merge_hover.active, "Leaving and entering again starts a fresh post-merge prediction")
	view.pause(true)
	check(not view.snapshot().auto_merge_hover.active, "Explicit pause clears the Auto merge prediction")
	view.pause(false)
	app.set_reduced_motion(true)
	await move_mouse(Vector2(1300, 40))
	await move_mouse(button.get_global_rect().get_center())
	for frame in range(12):
		view._process(0.05)
	view._refresh_marks()
	check(view.snapshot().auto_merge_hover.active and view._tiles.values().filter(
		func(tile) -> bool: return tile.completion_hint).all(
		func(tile) -> bool: return is_equal_approx(tile.completion_scale, 1.0)),
		"Reduced motion retains exact input highlights without gel growth: " + JSON.stringify({
			"preview": view.snapshot().auto_merge_hover, "reduced": view.reduced_motion,
			"hovered": button.is_hovered(), "button_preview": button._preview_active,
			"consumed": button._preview_consumed, "disabled": button.disabled,
			"paused": model.paused, "requested_pause": view._requested_pause, "error": model.error,
			"hover_flag": view._auto_merge_hovered, "goal": view._goal_hover_word,
			"pointer": view._pointer, "source": view._source, "selected": view._keyboard_source,
			"settling": model._settling_remaining(false),
			"scales": view._tiles.values().filter(func(tile) -> bool: return tile.completion_hint).map(
				func(tile) -> float: return tile.completion_scale)}))
	await capture("auto-merge-preview-reduced")
	await move_mouse(Vector2(1300, 40))
	app.set_reduced_motion(false)


func test_selection(app) -> void:
	root.size = Vector2i(1366, 768)
	await settle()
	var words: Array = await prepare(app)
	var view = app._word_jelly
	var model = view.game
	for level in [2, 3]:
		var body: Dictionary = model._new_word_root(words[0])
		model._set_merged_word(body, words[0], level, true)
		put(model, body)
	view._sync_tiles()
	view._layout()
	view._process(0.0)
	await settle()
	var unrelated: Array[int] = [int(model.cells[2].id), int(model.cells[3].id)]
	var before: int = app.coin_wallet.balance
	var receipts: int = app.coin_wallet._receipts.size()
	var growth: Dictionary = app.growth.snapshot().streaks.duplicate(true)
	var spoken: Array = []
	var on_word: Callable = func(word: Dictionary) -> void: spoken.append(word.id)
	view.word_requested.connect(on_word)
	check(not view.powerup_buttons.has("family_merge") and view.find_child("PowerupMagnet", true, false) == null,
		"Magnet is removed, including its native focus and input target")
	var button = goal_button(view, str(words[0].id))
	check(button != null and not button.disabled and button.snapshot().price == 150,
		"The actual pending goal advertises its exact first family-merge price")
	if button == null:
		return
	var other_button = goal_button(view, str(words[1].id))
	var balance_callback: Callable = view.coin_balance
	view.coin_balance = func() -> int: return 100
	view._refresh_controls()
	check(other_button != null and button.snapshot().price == 150 and not button.snapshot().affordable
		and other_button.snapshot().price == 50 and other_button.snapshot().affordable,
		"The same wallet affords the smaller family while the larger family's own quantity quote remains unaffordable")
	view.coin_balance = balance_callback
	view._refresh_controls()
	await capture("goal-idle")
	await move_mouse(button.get_global_rect().get_center())
	view._process(0.25)
	check(view.snapshot().goal_hover.word_id == words[0].id and button.snapshot().targeting
		and app.coin_wallet.balance == before and not model.powerup_active(),
		"A genuine goal hover acknowledges its row and never charges")
	for tile: Dictionary in model.cells:
		var visual = view._tiles[int(tile.id)]
		var matching: bool = model.family_word_id(int(tile.id)) == str(words[0].id)
		check(visual.completion_hint == matching and visual.match_dimmed == not matching,
			"Goal hover uses the ordinary drag-match halo and family-aware dimming")
	check(view._tiles[int(model.cells[0].id)].completion_scale > 1.0,
		"The corresponding acquired gel grows through the same live matching animation")
	await capture("goal-hover")
	await move_mouse(Vector2(1300, 720))
	check(view.snapshot().goal_hover.word_id.is_empty()
		and view._tiles.values().all(func(tile) -> bool: return not tile.completion_hint and not tile.match_dimmed),
		"Leaving a goal restores all original Jelly surfaces without stale highlights")
	var coin_rect: Rect2 = button.get("_coin_rect")
	var destination: Vector2 = button.get_global_transform() * coin_rect.get_center()
	await click(button)
	check(model.powerup_active() and model.powerup_snapshot().kind == "family_merge"
		and model.powerup_snapshot().family_word_id == words[0].id
		and app.coin_wallet.balance == before - 150 and app.coin_wallet._receipts.size() == receipts + 1
		and app._status_announcement.contains("Auto merge " + str(words[0].text)),
		"One actual goal click durably buys only the named family, without a second target-selection gesture")
	check(app._coin_flight.snapshot().debit_active and app._coin_flight.snapshot().debit_amount == 150
		and app._coin_flight._debit.destination.is_equal_approx(destination)
		and app._coin_counter.target == before - 150
		and app._coin_counter.displayed >= float(before - 150) and app._coin_counter.displayed <= float(before),
		"The accepted receipt owns the downward wallet roll, exact negative amount and coin flight into this goal")
	check(not app._coin_flight._debit.inline_caption,
		"A desktop goal puts its debit below the wallet, never across the neighboring Pause control")
	check(button.snapshot().spent_coins == 150 and button.snapshot().price == 225,
		"The paid feedback keeps its actual debit separate from the next advertised price")
	var paid_receipt: String = str(model.powerup_snapshot().receipt_id)
	var mismatched: Dictionary = app._purchase_word_jelly_powerup(paid_receipt, "family_merge", 225)
	check(not bool(mismatched.get("ok", false)) and app.coin_wallet.balance == before - 150
		and app.coin_wallet._receipts.size() == receipts + 1,
		"The next family quote cannot rewrite the amount of the already paid receipt")
	var duplicate: Dictionary = app._purchase_word_jelly_powerup(paid_receipt, "family_merge", 150)
	check(bool(duplicate.get("ok", false)) and bool(duplicate.get("duplicate", false))
		and app.coin_wallet.balance == before - 150 and app.coin_wallet._receipts.size() == receipts + 1,
		"Retrying the original quantity-priced receipt preserves its exact amount without a second debit")
	await click(button)
	check(app.coin_wallet._receipts.size() == receipts + 1 and app.coin_wallet.balance == before - 150,
		"A repeat press during the paid operation cannot debit another goal")
	view._process(0.16)
	app._coin_flight.advance(0.16)
	check(not view._powerup_effects.stamps.is_empty(), "Selected-family motion uses the actual automatic-flight presentation")
	await capture("goal-paid")
	for frame in range(300):
		if not model.powerup_active():
			break
		view._process(0.04)
	check(not model.powerup_active() and model.cells.size() == 3
		and model.cells.any(func(tile: Dictionary) -> bool: return tile.get("word", {}).get("id") == words[0].id and tile.merge_level == 6),
		"Roots, pictures and different levels of the chosen family finish one real Lv6 Jelly")
	check(not model.cell(unrelated[0]).is_empty() and not model.cell(unrelated[1]).is_empty()
		and spoken.is_empty() and model.cleared_pairs == 0 and model.combo_coins == 0
		and app.growth.snapshot().streaks == growth and app.coin_wallet.balance == before - 150,
		"A paid goal cannot accidentally collect, pronounce, spend again or consume another family")
	check(button.disabled and button.snapshot().price == 75
		and other_button.snapshot().price == 75 and not other_button.disabled,
		"Settlement recomputes each family's remaining quantity and disables a card without another complete path")
	view._process(1.3)
	await settle()
	check(not button.snapshot().targeting and not button.has_focus()
		and view.snapshot().goal_hover.word_id.is_empty(),
		"A completed pointer purchase restores its ordinary card even while the pointer stays over it")
	await capture("goal-after-click")
	await move_mouse(Vector2(1300, 720))
	check(view.snapshot().goal_hover.word_id.is_empty()
		and view._tiles.values().all(func(tile) -> bool: return not tile.completion_hint and not tile.match_dimmed),
		"Moving away after purchasing cannot leave a mouse-acquired focus or board-family highlight behind")
	await move_mouse(other_button.get_global_rect().get_center())
	check(other_button.snapshot().targeting and view.snapshot().goal_hover.word_id == str(words[1].id),
		"A fresh hover can preview the remaining legal family without spending")
	await move_mouse(Vector2(1300, 720))
	view.word_requested.disconnect(on_word)


func test_tiered_prices(app) -> void:
	root.size = Vector2i(1366, 768)
	await settle()
	var words: Array = await prepare(app)
	var view = app._word_jelly
	var model = view.game
	model.set_fill_mode(false)
	var prices: Array[int] = [50, 75, 100, 100]
	for index in range(prices.size()):
		model.cells.clear()
		var word: Dictionary = words[index % words.size()]
		put(model, model._new_word_root(word))
		put(model, model._new_picture_tile(word))
		view._sync_tiles()
		view._layout()
		view._refresh_controls()
		await settle()
		var button = goal_button(view, str(word.id))
		check(button != null and not button.disabled and button.snapshot().price == prices[index],
			"Different pending goals share the real fifty, seventy-five and capped one-hundred quotes")
		if button == null:
			return
		var before: int = app.coin_wallet.balance
		var receipts: Dictionary = app.coin_wallet._receipts.duplicate()
		app._coin_flight.sync(before)
		await click(button)
		var ids: Array = app.coin_wallet._receipts.keys().filter(func(id: String) -> bool:
			return not receipts.has(id))
		check(model.powerup_active() and app.coin_wallet.balance == before - prices[index]
			and ids.size() == 1 and app.coin_wallet.has_purchase(str(ids[0]), prices[index]),
			"Every real goal click persists exactly its visible price, including seventy-five coins")
		check(app._coin_flight.snapshot().debit_active and app._coin_flight.snapshot().debit_amount == prices[index]
			and app._coin_counter.target == before - prices[index] and button.snapshot().spent_coins == prices[index],
			"The wallet display, row feedback and flight all use the exact accepted debit")
		var reloaded := Wallet.new(app.coin_wallet._path)
		check(reloaded.load_state() and reloaded.balance == before - prices[index]
			and reloaded._receipts == app.coin_wallet._receipts,
			"The actual application's saved purchase reloads without rounding or changing its receipt")
		if prices[index] == 75:
			await capture("goal-paid-75")
		for frame in range(300):
			if not model.powerup_active():
				break
			view._process(0.04)
			app._coin_flight.advance(0.04)
		check(not model.powerup_active(), "Every newly priced family operation completes normally")
		var next_price: int = 75 if index == 0 else 100
		check(view.snapshot().practice.words.all(func(item: Dictionary) -> bool:
			return item.purchase.price == next_price), "All goal rows show the same correct next tier")


func test_cancel_and_fill(app) -> void:
	await prepare(app)
	var view = app._word_jelly
	var before: int = app.coin_wallet.balance
	var button: Button = goal_button(view, str(view.game._words[0].id))
	view.pause(true)
	await click(button)
	check(view.snapshot().goal_hover.word_id.is_empty() and app.coin_wallet.balance == before,
		"Pause clears goal hover and blocks payment, not just the board gesture")
	view.pause(false)
	var generated: int = view.game.generated_tiles
	check(view.navigation_controls().has(view._fill_button),
		"The optional Fill switch belongs to the actual controller navigation surface")
	await click(view._fill_button)
	view._process(0.01)
	check(view.game.fill_mode and view.game.generated_tiles > generated,
		"The real unified Fill switch starts normal advertised supply flights")
	await click(view._fill_button)
	check(not view.game.fill_mode, "Main/unbound play can turn Fill back off while already launched pieces settle")
	view._process(2.0)
	await click(view._fill_button)
	check(view.game.fill_mode, "The ordinary Fill preference can be on before entering Challenge")
	var words: Array = view.game._words.duplicate(true)
	var plan: Dictionary = Catalog.make_plan(0, words, app.growth.learning_age(), seed_value, true)
	check(view.game.bind_stage(plan), "Bind the actual ninety-second Challenge model: " + str(plan.get("error", "")) + view.game.error)
	view._refresh_controls()
	view._layout()
	await click(view._fill_button)
	check(view._fill_button.disabled and view._fill_button.button_pressed and view.game.fill_mode
		and view.snapshot().fill_control.locked and view._fill_button.snapshot().unified_switch,
		"Challenge keeps the single whole-row switch On and rejects a real attempt to turn it off")
	check(view.configure(words, app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, false, seed_value)
		and view.game.fill_mode and not view.game.fill_mode_locked(),
		"Leaving Challenge restores the independent ordinary Fill preference rather than persisting the forced lock")


func test_keyboard_and_controller(app) -> void:
	for controller: bool in [false, true]:
		var words: Array = await prepare(app)
		var view = app._word_jelly
		var before: int = app.coin_wallet.balance
		var button: Button = goal_button(view, str(words[0].id))
		button.grab_focus()
		check(view.navigation_controls().has(button) and view.snapshot().goal_hover.word_id == words[0].id,
			"Keyboard and controller focus expose the same goal-family highlight as mouse hover")
		for pressed: bool in [true, false]:
			if controller:
				var joy := InputEventJoypadButton.new()
				joy.button_index = JOY_BUTTON_A
				joy.pressed = pressed
				Input.parse_input_event(joy)
			else:
				var key := InputEventKey.new()
				key.keycode = KEY_ENTER
				key.pressed = pressed
				Input.parse_input_event(key)
			await process_frame
		check(view.game.powerup_active() and view.game.powerup_snapshot().family_word_id == words[0].id
			and app.coin_wallet.balance == before - 50 and view.game.cleared_pairs == 0,
			"A focused keyboard/controller goal buys its explicit family instead of pronouncing or collecting it")
		view.game.finish_powerup()
		view._process(1.3)
		check(not button.snapshot().targeting and view.snapshot().goal_hover.word_id.is_empty(),
			"Keyboard/controller activation also finishes its temporary family preview")


func test_goal_rejection(app) -> void:
	var words: Array = await prepare(app)
	var view = app._word_jelly
	var button = goal_button(view, str(words[0].id))
	var balance: int = app.coin_wallet.balance
	check(app.coin_wallet.spend("fixture:partial-goal-wallet", balance - 25).ok,
		"Create an actual partially funded isolated wallet")
	app._coin_flight.sync(app.coin_wallet.balance)
	view._refresh_controls()
	var saved: Variant = app.coin_wallet._saved_text
	await click(button)
	view._process(0.10)
	check(button.snapshot().funds_warning and button.snapshot().missing_coins == 25
		and button.snapshot().price_text == "50" and not view.game.powerup_active()
		and app.coin_wallet.balance == 25 and app.coin_wallet._saved_text == saved
		and not app._coin_flight.snapshot().debit_active,
		"A real rejected goal click explains exactly twenty-five missing coins without a debit, merge or price increase")
	await capture("goal-needs-coins")
	view.set_reduced_motion(true)
	check(button.snapshot().price_offset == [0.0, 0.0] and button.snapshot().coin_scale == 1.0,
		"Changing reduced motion preserves the money explanation without a moving cost")
	view.set_reduced_motion(false)
	for frame in range(24):
		view._process(0.05)
	check(not button.snapshot().feedback_active and button.snapshot().title == words[0].text,
		"The goal recovers its ordinary word label after the bounded shortfall")
	check(not button.snapshot().targeting and not button.has_focus() and view.snapshot().goal_hover.word_id.is_empty(),
		"A rejected pointer purchase returns to the ordinary card after its funds message")
	check(app.coin_wallet.credit_amount("fixture:goal-retry-funding", 1000).ok, "Fund a later legitimate retry")
	app._coin_flight.sync(app.coin_wallet.balance)
	var partner: Dictionary = view.game.cells.filter(func(tile: Dictionary) -> bool:
		return tile.jelly_kind == "picture" and tile.image_word.id == words[0].id)[0]
	view.game.cells.erase(partner)
	view._sync_tiles()
	view._refresh_controls()
	balance = app.coin_wallet.balance
	await click(button)
	check(not view.game.powerup_active() and app.coin_wallet.balance == balance
		and not button.snapshot().funds_warning and button.snapshot().feedback_active,
		"A pending word with no legal partner rejects without paying or borrowing another goal's pair")
	view._activate_goal_merge(str(button.get("_goal").id), str(words[1].id))
	check(app.coin_wallet.balance == balance and not view.game.powerup_active(),
		"A stale or mismatched goal identity cannot redirect its payment to another family")


func test_goal_scroll(app) -> void:
	root.size = Vector2i(393, 852)
	await settle()
	var words: Array = await prepare(app)
	var view = app._word_jelly
	var button: Button = goal_button(view, str(words[0].id))
	var balance: int = app.coin_wallet.balance
	var receipts: int = app.coin_wallet._receipts.size()
	var panel = view._practice_panel
	var full_area: Rect2 = panel.get_rect()
	var scale_value: float = app.Style.ui_scale(view)
	panel.configure_layout(Rect2(full_area.position, Vector2(full_area.size.x, 96.0 / scale_value)),
		scale_value, false)
	await settle()
	var at: Vector2 = button.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.global_position = at
	root.push_input(event)
	await process_frame
	await move_mouse(at - Vector2(0, 45), MOUSE_BUTTON_MASK_LEFT)
	event.pressed = false
	event.position = at - Vector2(0, 45)
	event.global_position = event.position
	root.push_input(event)
	await process_frame
	check(view._practice_panel._scroll.scroll_vertical > 0 and app.coin_wallet.balance == balance
		and app.coin_wallet._receipts.size() == receipts and not view.game.powerup_active(),
		"A real vertical swipe scrolls the left goals without turning its release into a paid click")
	view._practice_panel._scroll.cancel_drag()
	view._practice_panel._scroll.scroll_vertical = 0
	panel.configure_layout(full_area, scale_value, false)
	await settle()
	at = button.get_global_rect().get_center()
	for step: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 0)]:
		var touch := InputEventScreenTouch.new()
		touch.index = step.x
		touch.pressed = step.y == 1
		touch.position = at + Vector2(step.x * 4.0, 0)
		root.push_input(touch)
		await process_frame
	check(app.coin_wallet.balance == balance and app.coin_wallet._receipts.size() == receipts,
		"A second touch cancels the goal gesture rather than paying twice")
	await click(button)
	check(app.coin_wallet.balance == balance - 50 and app._coin_flight._debit.inline_caption,
		"One settled phone tap buys its goal and uses the actual stacked-header debit placement")
	view._process(0.12)
	app._coin_flight.advance(0.12)
	await capture("goal-paid-phone")
	view.game.finish_powerup()
	for reduced: bool in [false, true]:
		words = await prepare(app)
		view.set_reduced_motion(reduced)
		button = goal_button(view, str(words[0].id))
		balance = app.coin_wallet.balance
		await move_mouse(Vector2(390, 820))
		at = button.get_global_rect().get_center()
		for pressed: bool in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 7
			touch.position = at
			touch.pressed = pressed
			root.push_input(touch)
			await process_frame
		check(app.coin_wallet.balance == balance - 50 and view.game.powerup_active(),
			"A real single-finger tap still buys exactly one named goal")
		view.game.finish_powerup()
		view._process(1.3)
		await settle()
		check(not button.snapshot().targeting and not button.has_focus() and view.snapshot().goal_hover.word_id.is_empty(),
			"Touch purchases cannot leave a selected card in normal or reduced motion")
		await capture("goal-after-touch-" + ("reduced" if reduced else "normal"))
	view.set_reduced_motion(false)


func test_reentrant_goal(app) -> void:
	var words: Array = await prepare(app)
	var view = app._word_jelly
	var first = goal_button(view, str(words[0].id))
	var other = goal_button(view, str(words[1].id))
	var before: int = app.coin_wallet.balance
	var receipts: int = app.coin_wallet._receipts.size()
	var original: Callable = view.purchase_powerup
	var calls: Array = []
	view.purchase_powerup = func(id: String, kind: String, price: int) -> Dictionary:
		calls.append([id, kind, price])
		other.pressed.emit()
		return original.call(id, kind, price)
	await click(first)
	view.purchase_powerup = original
	check(calls.size() == 1 and app.coin_wallet.balance == before - 50
		and app.coin_wallet._receipts.size() == receipts + 1 and view.game.powerup_snapshot().family_word_id == words[0].id,
		"A nested goal press cannot pay again or redirect the original family")
	check(first.snapshot().spent_coins == 50 and app._coin_flight.snapshot().debit_active
		and app._status_announcement.contains("Auto merge " + str(words[0].text)),
		"Rejecting nested input preserves the original goal's payment context and real debit feedback")
	view.game.finish_powerup()


func test_layouts(app) -> void:
	await prepare(app)
	var view = app._word_jelly
	var words: Array = view.game._words.duplicate(true)
	var plan: Dictionary = Catalog.make_plan(2, words, app.growth.learning_age(), seed_value)
	check(view.game.bind_stage(plan), "Use a real main plan with the three remaining paid tools: " + str(plan.get("error", "")) + view.game.error)
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(768, 1024), Vector2i(393, 852), Vector2i(320, 480), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		view.set_process(false)
		view._layout()
		view._refresh_controls()
		var controls: Array = [view._fill_button, view.collect_button]
		controls.append_array(view.powerup_buttons.values())
		for index in range(controls.size()):
			var bounds: Rect2 = controls[index].get_global_rect()
			check(view.get_global_rect().grow(0.1).encloses(bounds)
				and not bounds.intersects(view._global_rect(view._board))
				and bounds.size.x * app.Style.ui_scale(app) >= 43.9
				and bounds.size.y * app.Style.ui_scale(app) >= 43.9,
				"Fill, Collect and every paid target fit without covering Jelly reading space at %s: %s" % [dimensions, bounds])
			for previous in range(index):
				check(not bounds.intersects(controls[previous].get_global_rect()),
					"No paid, free or fill targets overlap at %s" % dimensions)
		check(not view._fill_button.get_global_rect().intersects(view.collect_button.get_global_rect())
			and is_equal_approx(view._fill_button.size.x * app.Style.ui_scale(app), 56.0),
			"Fill stays compact beside Collect, or above it only when the rail cannot fit both")
		if dimensions.x == 393:
			await capture("phone-controls")


func review_rendered_states(app) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	var view = app._word_jelly
	root.size = Vector2i(1011, 663)
	await settle()
	view.set_process(false)
	view.game.set_fill_mode(true)
	for frame in range(480):
		view._process(0.025)
		if view.game.cells.size() == view.WordModel.CAPACITY and view.game._settling_remaining() <= view.WordModel.EPSILON:
			break
	check(view.game.cells.size() == view.WordModel.CAPACITY,
		"The failure review uses a genuinely full busy board, not an easier empty background")
	var main: Dictionary = view.game.stage_run.snapshot()
	view.set_stage_progress(main)
	view._layout()
	await capture("main-rating-and-controls")
	app._round_end.begin(app._round_id + ":review-desktop", true, false)
	app._round_end.advance(1.45)
	await capture("game-over-desktop")
	app._round_end.stop()
	root.size = Vector2i(393, 852)
	await settle()
	view.set_process(false)
	view._layout()
	app._round_end.begin(app._round_id + ":review-phone", true, false)
	app._round_end.advance(1.45)
	await capture("game-over-phone")
	app._round_end.stop()
	var plan: Dictionary = Catalog.make_plan(0, view.game._words, app.growth.learning_age(), seed_value, true)
	check(view.game.bind_stage(plan), "The rendering fixture binds its real Challenge mode")
	var run = view.game.stage_run
	run.challenge_stage = 7
	run._challenge_goals.clear()
	run._append_challenge_stage()
	view.game._sync_challenge_pressure()
	var state: Dictionary = run.snapshot()
	state.challenge_best_stage = 7
	view.set_stage_progress(state)
	app._sync_stage_heading()
	view._layout()
	view._refresh_controls()
	await capture("challenge-stage-7")
	check(view._practice_panel._record_badge.snapshot().text == "Stage 7",
		"The rendered compact medal explicitly includes Stage before its seventh-stage numeral")
	app._reward_confetti.set_paused(false)
	app._reward_confetti.burst("review:upper-launch")
	app._reward_confetti.advance(0.95)
	check(app._reward_confetti.snapshot().visible and app._reward_confetti.is_active(),
		"The native upper-launch capture contains actual visible paper")
	await capture("paper-upper-launch")
	app._reward_confetti.advance(1.8)
	await capture("paper-natural-descent")
	app._reward_confetti.clear()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 800)
	var directory: String = "user://selected-jelly-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	Fixture.enter_mode(app, "match")
	app.set_process(false)
	app.audio.set_muted(true)
	check(app.coin_wallet.credit_amount("fixture:magnet-funding", 2000).ok, "Fund only isolated native test storage")
	app._coin_flight.sync(app.coin_wallet.balance)
	await test_auto_hover(app)
	if not OS.get_cmdline_user_args().has("--auto-hover-only"):
		await test_selection(app)
		await test_keyboard_and_controller(app)
		await test_goal_rejection(app)
		await test_goal_scroll(app)
		await test_reentrant_goal(app)
		await test_cancel_and_fill(app)
		await test_layouts(app)
		await test_tiered_prices(app)
		await review_rendered_states(app)
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Paid goal input and unified Fill UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

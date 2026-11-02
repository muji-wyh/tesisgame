extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
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


func advance(app, delta: float) -> void:
	app._word_jelly._process(delta)
	app._word_jelly.set_process(false)
	app._advance_ui(delta)
	if app._round_celebration_active():
		Fixture.finish_celebration(app)
	var room = app._jelly_rewards
	room.advance_hold(delta)
	for card: Dictionary in room._cards:
		if card.art.mode == "opening":
			card.art._advance_animation(delta)


func tap(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = at
		event.pressed = pressed
		root.push_input(event)
		await process_frame


func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	var directory := "res://build/qa/jelly-failure-upgrades"
	DirAccess.make_dir_recursive_absolute(directory)
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory + "/" + name + ".png") == OK,
		"Capture the actual " + name)


func ready(room) -> bool:
	return room._challenge_return_ready or room._stage_failure_ready


func capture_taunt_film(app) -> void:
	var directory := "res://build/qa/jelly-taunt-film"
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in range(30):
		advance(app, 1.0 / 24.0)
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory + "/frame-%03d.png" % frame) == OK,
			"Capture an actual native taunt frame without a simulated character")


func cleanup(app, directory: String) -> void:
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)


func _case(settings: Dictionary) -> void:
	root.size = Vector2i(393, 852) if settings.size == Vector2i(320, 480) else settings.size
	var directory := "user://failure-upgrades-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Use only isolated failure-navigation saves")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.set_process(false)
	app.audio.set_muted(true)
	app.set_reduced_motion(bool(settings.get("reduce", false)))
	check(app.coin_wallet.credit_amount("fixture:failure-upgrades", 1000).ok, "Fund only this isolated upgrade journey")
	app._coin_flight.sync(app.coin_wallet.balance)
	app._show_mode_menu()
	app.choose_mode("word_jelly")
	await settle()
	var campaign = app._campaign
	var challenge: bool = bool(settings.get("challenge", false))
	if challenge:
		campaign.request_challenge()
	else:
		campaign.request_stage(1)
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	for frame in range(100):
		if not view._stage_banner.ready_pending():
			break
		advance(app, 0.05)
	var model = view.game
	model.set_fill_mode(false)
	model.spawn_interval = 10000.0
	model._stage_spawn_interval = 10000.0
	model.cells.clear()
	var word: Dictionary = model.stage_run.words[0]
	var blocked: bool = settings.reason == "blocked"
	var treasure: bool = bool(settings.get("treasure", false))
	var count: int = model.CAPACITY if blocked else 1 if treasure else 0
	for index in range(count):
		var tile: Dictionary = model._new_word_root(word, 4 if treasure and index == 0 else 0)
		if treasure and index == 0:
			model._set_merged_word(tile, word, 1, true)
		tile.merge({"column": index % model.COLUMNS, "row": model.ROWS - 1 - int(index / model.COLUMNS),
			"age": 100.0, "falling": false, "settling": false, "arrival": false}, true)
		model.cells.append(tile)
	view._sync_tiles()
	if blocked:
		model.full_elapsed = model.FULL_SECONDS - 0.01
	else:
		model.stage_run.advance(model.stage_run.remaining)
	var save_path: String = campaign.store._path
	var blocked_save := false
	for frame in range(1600):
		advance(app, 0.05)
		if frame % 20 == 0:
			await process_frame
		if bool(settings.get("save_failure", false)) and campaign.settling and not blocked_save:
			blocked_save = true
			campaign.store._path = directory + "/missing/campaign.cfg"
		if blocked_save and not campaign.error.is_empty():
			break
		if ready(app._jelly_rewards):
			break
	var room = app._jelly_rewards
	if blocked_save:
		check(not ready(room) and not room._upgrades.visible and room._retry.visible,
			"An unsaved failure exposes Retry save, never a way to discard the earned result: %s" % {
				"case": settings.name, "phase": model.phase, "outcome": model.stage_run.outcome,
				"error": campaign.error, "settling": campaign.settling, "pending": room.has_pending(),
				"opening": room._opening, "holding": room._holding, "paused": room._paused})
		check(room._retry.size.y * app.Style.ui_scale(room) >= 44.0 - 0.1
			and not room._retry.get_global_rect().grow(-0.02).intersects(room._scroll.get_global_rect()),
			"A campaign save error gives Retry save its own real target outside the scroll surface")
		check(room._cards.all(func(card: Dictionary) -> bool: return not card.hint.is_visible_in_tree()),
			"A save error owns the caption instead of overlapping the saved coin breakdown")
		check(not room._result_boss.visible and not room._result_boss.snapshot().active,
			"A storage error is never presented as a Boss mocking the player")
		var balance: int = app.coin_wallet.balance
		room._upgrades.pressed.emit()
		campaign.accept_result("upgrades")
		advance(app, 0.1)
		check(not campaign.upgrades.visible and campaign.settling and app.coin_wallet.balance == balance,
			"Hidden or stale upgrade requests cannot bypass a failed settlement")
		await capture(str(settings.name) + "-save-error")
		campaign.store._path = save_path
		await tap(room._retry)
		for frame in range(1600):
			advance(app, 0.05)
			if frame % 20 == 0:
				await process_frame
			if ready(room):
				break
	check(ready(room) and campaign.settling and not campaign.map.visible
		and campaign.store.pending("growth").is_empty() and campaign.error.is_empty(),
		"Main and Challenge game over stop on a durable result rather than disappearing before the player chooses: %s" % {
			"case": settings.name, "phase": model.phase, "outcome": model.stage_run.outcome,
			"error": campaign.error, "settling": campaign.settling, "pending": room.has_pending(),
			"opening": room._opening, "holding": room._holding, "paused": room._paused})
	if not ready(room):
		await cleanup(app, directory)
		return
	check(campaign.store.highest_cleared("growth") == 0 and campaign.store.best_stars("growth", 1) == 0,
		"Offering upgrades after Game over cannot unlock a numbered stage or award a clear rating")
	root.size = settings.size
	await settle()
	app._sync_jelly()
	room._layout()
	check(room._upgrades.visible and not room._upgrades.disabled and room._upgrades.text == "Jelly Upgrades"
		and room.navigation_controls().has(room._upgrades) and app._valid_focus(room._upgrades),
		"The saved Game over modal exposes the real upgrades route for touch, keyboard and controller")
	check(room.snapshot().result_boss.visible and room.snapshot().result_boss.model_loaded,
		"Both numbered and Challenge failures show the acquired animated Boss inside the saved modal")
	var actions: Array[Control] = [room._back, room._home, room._upgrades]
	for index in range(actions.size()):
		var bounds: Rect2 = actions[index].get_global_rect()
		check(app._settlement_dialog.panel.get_global_rect().grow(0.1).encloses(bounds)
			and actions[index].size.y * app.Style.ui_scale(app) >= 44.0 - 0.1,
			"Every failure action is fully inside the modal with a real touch target")
		for previous in range(index):
			check(not bounds.grow(-0.02).intersects(actions[previous].get_global_rect()),
				"Retry, upgrades and Back to map never overlap on this viewport")
		check(not bounds.grow(-0.02).intersects(room._result_boss.get_global_rect()),
			"The complete Boss performance stays away from every live action")
	if room._challenge_record.visible:
		check(not room._challenge_record.get_rect().grow(-0.02).intersects(room._result_boss.get_rect()),
			"A new-best medal remains readable beside the playful Boss response")
	var coins: int = app.coin_wallet.balance
	var receipts: Dictionary = app.coin_wallet._receipts.duplicate()
	var round_id: String = app._round_id
	if OS.get_cmdline_user_args().has("--taunt-film"):
		await capture_taunt_film(app)
	var peak: float = 1.0 - float(room._result_boss.snapshot().elapsed)
	if peak > 0.0:
		advance(app, peak)
	check(room.snapshot().result_boss.effects >= (0.15 if app.reduced_motion else 0.5),
		"The captured taunt includes its actual local hand effect, not only a still character: %s"
		% JSON.stringify(room.snapshot().result_boss))
	await capture(str(settings.name) + "-taunt-peak")
	var elapsed: float = room._result_boss.snapshot().elapsed
	room.set_result_context(app._round_result, app._round_id)
	check(room._result_boss.snapshot().elapsed == elapsed, "Refreshing the saved popup cannot restart its Boss")
	for frame in range(0 if settings.get("leave_at_peak", false) else 120):
		advance(app, 0.05)
	check(campaign.settling and room.is_visible_in_tree() and not campaign.map.visible,
		"An idle saved failure keeps the upgrade entry available")
	await capture(str(settings.name))
	if settings.action == "upgrades":
		app._page_hidden = true
		app._sync_jelly()
		var hidden_elapsed: float = room._result_boss.snapshot().elapsed
		advance(app, 0.3)
		check(room._result_boss.snapshot().elapsed == hidden_elapsed
			and room._result_boss._actor.render_target_update_mode == SubViewport.UPDATE_DISABLED,
			"Backgrounding the result stops its Boss without consuming the one-shot performance")
		room._upgrades.pressed.emit()
		campaign.accept_result("upgrades")
		check(not campaign.upgrades.visible, "A hidden page cannot navigate or buy from a stale failure action")
		app._page_hidden = false
		app._sync_jelly()
		await tap(room._upgrades)
		room._upgrades.pressed.emit()
		room._home.pressed.emit()
		room._back.pressed.emit()
		advance(app, 0.05)
		await settle()
		check(campaign.upgrades.visible and not campaign.settling and not app._jelly_rewards_shown
			and not app._settlement_dialog.visible and not campaign.map.visible,
			"One explicit upgrade choice closes the saved result and opens the existing upgrade page")
		check(not room._result_boss.snapshot().active
			and room._result_boss._actor.render_target_update_mode == SubViewport.UPDATE_DISABLED,
			"Leaving immediately during the taunt never keeps a hidden model or effect alive")
		check(app.coin_wallet.balance == coins and app.coin_wallet._receipts == receipts
			and app._round_id == round_id and campaign.store.merged_level() == 1,
			"Repeated navigation cannot repeat rewards, restart the game or buy a level automatically")
		await capture(str(settings.name) + "-upgrade-page")
		await tap(campaign.upgrades._buy)
		check(campaign.store.merged_level() == 2 and app.coin_wallet.balance == coins - 50,
			"The actual upgrade page still requires one explicit fifty-coin purchase")
		var wallet := Wallet.new(app.coin_wallet._path)
		check(wallet.load_state() and wallet.balance == coins - 50, "The upgrade debit persists in the real isolated wallet")
		await tap(campaign.upgrades._back)
		check(campaign.map.visible and not campaign.upgrades.visible,
			"Back from upgrades follows the existing map return route")
	elif settings.action == "retry":
		await tap(room._home)
		room._home.pressed.emit()
		room._back.pressed.emit()
		advance(app, 0.05)
		await settle()
		check(not campaign.settling and not campaign.map.visible and app._round_id != round_id
			and model.stage_run.kind == "main" and model.stage_run.number == 1,
			"Try again restarts the same numbered stage exactly once")
		check(app.coin_wallet.balance == coins and app.coin_wallet._receipts == receipts,
			"Restarting cannot credit the old failure a second time")
	else:
		await tap(room._back)
		advance(app, 0.05)
		check(campaign.map.visible and not campaign.settling and not app._settlement_dialog.visible,
			"Back to map keeps its existing safe destination")
	await cleanup(app, directory)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for settings: Dictionary in [
			{"name": "timeout-phone", "size": Vector2i(393, 852), "reason": "timeout", "action": "upgrades"},
			{"name": "blocked-treasure-desktop", "size": Vector2i(1366, 900), "reason": "blocked",
				"treasure": true, "save_failure": true, "action": "upgrades"},
			{"name": "retry-landscape", "size": Vector2i(844, 390), "reason": "timeout", "action": "retry"},
			{"name": "map-small-phone", "size": Vector2i(320, 480), "reason": "blocked", "reduce": true, "action": "map"},
			{"name": "challenge-phone", "size": Vector2i(393, 852), "reason": "timeout",
				"challenge": true, "leave_at_peak": true, "action": "upgrades"}]:
		if OS.get_cmdline_user_args().has("--save-error-only") and not settings.get("save_failure", false):
			continue
		if OS.get_cmdline_user_args().has("--taunt-film") and settings.name != "timeout-phone":
			continue
		await _case(settings)
	print("Game over upgrade entry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

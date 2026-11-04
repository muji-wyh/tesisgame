extends SceneTree

const Page = preload("res://scripts/word_jelly_upgrades.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Store = preload("res://scripts/word_jelly_campaign_store.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
var checks := 0
var failures := 0
var word: Dictionary = {"id": "cat", "text": "cat", "image": "res://assets/images/ui/modes/cat.webp"}
var page
var holder := Control.new()
var requests: Array[Dictionary] = []
var cues: Array[String] = []
var legacy_requests := 0
var retries := 0
var charge_states: Array[bool] = []


class Host extends RefCounted:
	var campaign: Variant = null
	var coins: Variant = null
	var campaign_writable := true

	func jellyCampaignState() -> Variant:
		return campaign

	func saveJellyCampaignState(next: String, expected: Variant) -> bool:
		if not campaign_writable or campaign != expected:
			return false
		campaign = next
		return true

	func coinWalletState() -> Variant:
		return coins

	func saveCoinWalletState(next: String, expected: Variant) -> bool:
		if coins != expected:
			return false
		coins = next
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _initial_state() -> Dictionary:
	return {"level": 1, "auto_merge_level": 1, "funded": {"jelly": 0, "auto_merge": 0},
		"pending": {}, "intro": "guide", "balance": 5000, "error": "", "busy": false, "retry": false}


func _saved_state(store, wallet) -> Dictionary:
	var state: Dictionary = store.upgrade_state()
	state.merge({"balance": wallet.balance, "error": "", "busy": false, "retry": false}, true)
	return state


func _frames(count: int) -> void:
	for index in range(count):
		page.advance(0.05)


func _reset(state: Dictionary = {}) -> void:
	holder.show()
	page.set_active(true)
	requests.clear()
	cues.clear()
	charge_states.clear()
	check(page.present(_initial_state() if state.is_empty() else state, word, false),
		"Present acquired Jelly and cat artwork with a saved upgrade state")


func _test_previews_and_no_fake_progress() -> void:
	_reset()
	var deposits: int = page.snapshot().deposit_count
	var milestones: int = page.snapshot().level_up_count
	var counts: Array[int] = [2, 4, 6, 8, 7, 13, 12, 22, 55]
	for level in range(1, 10):
		page.select_level(level)
		var actual: Dictionary = page.snapshot()
		check(actual.preview.level == level and actual.preview.target_count == counts[level - 1],
			"Lv%d retains the exact campaign ability target count" % level)
		check(actual.preview.columns == Model.COLUMNS and actual.preview.rows == Model.ROWS
			and actual.preview.targets.all(func(target: Dictionary) -> bool:
				return target.column >= 0 and target.column < 7 and target.row >= 0 and target.row < 8),
			"Every inspected ability uses real in-bounds seven-by-eight board cells")
		if level == 5:
			check(actual.preview.targets.all(func(target: Dictionary) -> bool:
				return target.column == actual.preview.origin[0]), "Lv5 reaches the entire source column")
		if level == 6:
			check(actual.preview.targets.all(func(target: Dictionary) -> bool:
				return target.column == actual.preview.origin[0] or target.row == actual.preview.origin[1]),
				"Lv6 reaches the source row and column")
		check(actual.owned_level == 1 and actual.balance == 5000 and actual.funded == 0
			and actual.buy.enabled and requests.is_empty(),
			"Every tier is preview only while the charge button continues targeting the next owned level")
	page._buy.pressed.emit()
	check(requests.is_empty() and legacy_requests == 0,
		"A click does not bypass the hold gesture or emit a whole-price purchase")
	page.start_charging()
	_frames(3)
	check(page.snapshot().charging and requests.is_empty() and page.snapshot().selected_level == 2,
		"Holding previews the next owned level and waits through the initial lead-in")
	_frames(1)
	check(requests == [{"kind": "jelly", "amount": 25}] and not page.snapshot().charging,
		"The first pulse requests exactly twenty-five coins and stops if no coordinator commits it")
	_frames(16)
	var stalled: Dictionary = page.snapshot()
	check(stalled.progress == 0.0 and stalled.visual_progress == 0.0 and stalled.funded == 0
		and stalled.balance == 5000 and stalled.owned_level == 1 and requests.size() == 1
		and stalled.deposit_count == deposits and stalled.level_up_count == milestones
		and stalled.coin_flights == 0 and cues.is_empty() and stalled.notice.is_empty(),
		"An unacknowledged hold cannot fake saved progress, debit, visual feedback or audio")
	page.select_upgrade("auto_merge")
	for level in range(1, 10):
		page.select_level(level)
		var actual: Dictionary = page.snapshot()
		check(actual.preview.kind == "auto_merge" and actual.preview.capacity == level + 2
			and actual.preview.description.contains(str(level + 2)) and actual.owned_level == 1
			and actual.level == 1 and actual.buy.enabled,
			"Every Auto merge preview retains its real capacity without changing either owned track")
	page.start_charging()
	_frames(4)
	check(requests.back() == {"kind": "auto_merge", "amount": 25}
		and page.snapshot().selected_level == 2 and page.snapshot().auto_merge_level == 1,
		"A future Auto merge preview still contributes toward its own next level")


func _cancel_check(action: Callable, reason: String) -> void:
	holder.show()
	page.set_active(true)
	page.present(_initial_state(), word, false)
	requests.clear()
	page.start_charging()
	_frames(1)
	action.call()
	_frames(8)
	check(not page.snapshot().charging and requests.is_empty(),
		"%s cancels the hold before any debit request" % reason)


func _test_hold_cancellation() -> void:
	_cancel_check(func() -> void: page._buy.button_up.emit(), "Button release")
	_cancel_check(func() -> void: page._buy.mouse_exited.emit(), "Pointer exit")
	_cancel_check(func() -> void:
		var event := InputEventMouseButton.new()
		event.pressed = false
		page._input(event), "A mouse release anywhere")
	_cancel_check(func() -> void:
		var event := InputEventScreenTouch.new()
		event.pressed = false
		page._input(event), "A touch release anywhere")
	_cancel_check(func() -> void:
		var event := InputEventScreenDrag.new()
		event.position = page._buy.get_global_rect().end + Vector2(30, 30)
		page._input(event), "Dragging a touch outside the button")
	_cancel_check(func() -> void: page.set_active(false), "An inactive application view")
	page.set_active(true)
	_frames(8)
	check(not page.snapshot().charging and requests.is_empty(), "Reactivation never resumes a previous hold")
	_cancel_check(func() -> void: page.hide(), "Hiding the upgrade page")
	_cancel_check(func() -> void: holder.hide(), "Hiding an ancestor of the upgrade page")
	_cancel_check(func() -> void: page.close(), "Closing the upgrade page")
	_cancel_check(func() -> void: page._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT),
		"Backgrounding the application")
	_cancel_check(func() -> void: page._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT),
		"Losing window focus")
	_cancel_check(func() -> void: page.advance(0.3), "Resuming after a long frame")
	_reset()
	page.start_charging()
	var inside := InputEventScreenDrag.new()
	inside.position = page._buy.get_global_rect().get_center()
	page._input(inside)
	check(page.snapshot().charging, "A touch moving within the button retains its active hold")
	page.select_level(8)
	_frames(8)
	check(not page.snapshot().charging and requests.is_empty(), "Choosing a different preview cancels a hold")
	page.start_charging()
	page.select_upgrade("auto_merge")
	_frames(8)
	check(not page.snapshot().charging and requests.is_empty(), "Changing upgrade tracks cancels a hold")


func _test_committed_feedback_and_independent_tracks() -> void:
	var host := Host.new()
	var store := Store.new("user://upgrade-view-feedback.cfg", host)
	var wallet := Wallet.new("user://upgrade-view-feedback-coins.cfg", host)
	check(store.load_state() and wallet.load_state() and wallet.credit_amount("fixture:view-feedback", 1000).ok,
		"Feedback tests use the real campaign journal and wallet with isolated storage")
	_reset(_saved_state(store, wallet))
	var baseline: Dictionary = page.snapshot()
	var control: Dictionary = {"fail_commit": false, "store": store}
	var commit := func(kind: String, amount: int) -> void:
		var current_store = control.store
		if not current_store.begin_upgrade_contribution(kind, amount):
			return
		var pending: Dictionary = current_store.upgrade_state().pending
		if not wallet.spend(pending.id, pending.amount).ok:
			return
		if bool(control.fail_commit):
			host.campaign_writable = false
		var committed: bool = current_store.complete_upgrade_contribution(wallet)
		var state: Dictionary = _saved_state(current_store, wallet)
		if not committed:
			state.error = current_store.error
			state.retry = true
		page.configure(state)
	page.contribution_requested.connect(commit)
	page.start_charging()
	_frames(4)
	var partial: Dictionary = page.snapshot()
	check(partial.charging and partial.funded == 25 and partial.remaining == 25 and partial.progress == 0.5
		and partial.balance == 975 and partial.owned_level == 1 and partial.coin_flights == 0
		and partial.deposit_count == baseline.deposit_count + 1 and partial.level_up_count == baseline.level_up_count
		and cues == ["upgrade_coin"] and partial.notice.is_empty(),
		"One committed partial deposit fills the real rail and cues the wallet without a coin flight")
	page.configure(_saved_state(store, wallet))
	check(cues == ["upgrade_coin"] and page.snapshot().deposit_count == partial.deposit_count,
		"Repeated configuration of the same saved state never repeats deposit feedback")
	control.fail_commit = true
	_frames(5)
	var blocked: Dictionary = page.snapshot()
	check(not blocked.charging and blocked.funded == 25 and blocked.owned_level == 1
		and blocked.balance == 950 and not blocked.pending.is_empty()
		and blocked.deposit_count == partial.deposit_count and blocked.level_up_count == baseline.level_up_count
		and cues == ["upgrade_coin", "upgrade_coin"],
		"A saved debit cues the wallet while an uncommitted milestone produces no pretend unlock or success audio")
	var retry_count: int = retries
	page._buy.button_up.emit()
	page._buy.pressed.emit()
	check(retries == retry_count and page.snapshot().pending == blocked.pending,
		"Releasing the failed charge cannot also activate its newly displayed Retry action")
	page._buy.button_down.emit()
	page._buy.button_up.emit()
	page._buy.pressed.emit()
	page.start_charging()
	_frames(8)
	check(retries == retry_count + 1 and requests.size() == 2 and not page.snapshot().charging,
		"Retry delegates recovery without requesting another contribution")
	host.campaign_writable = true
	control.fail_commit = false
	var restored := Store.new("user://upgrade-view-feedback.cfg", host)
	check(restored.load_state() and restored.complete_upgrade_contribution(wallet),
		"The paid milestone commits through real journal recovery")
	store = restored
	control.store = restored
	page.configure(_saved_state(store, wallet))
	var unlocked: Dictionary = page.snapshot()
	check(unlocked.owned_level == 2 and unlocked.funded == 0 and unlocked.progress == 1.0
		and unlocked.selected_level == 2 and unlocked.milestone_pending and unlocked.payoff == 0.0 and unlocked.notice.is_empty()
		and unlocked.deposit_count == baseline.deposit_count + 2
		and unlocked.level_up_count == baseline.level_up_count + 1
		and cues == ["upgrade_coin", "upgrade_coin"],
		"A committed recovered level queues its milestone without replaying the already saved debit")
	_frames(2)
	check(page.snapshot().visual_progress < 1.0 and page.snapshot().payoff == 0.0 and cues.size() == 2,
		"The saved rail approaches the milestone before its success effect")
	_frames(1)
	check(page.snapshot().visual_progress == 1.0 and page.snapshot().payoff > 0.0
		and not page.snapshot().milestone_pending and cues == ["upgrade_coin", "upgrade_coin", "goal_complete"],
		"Reaching the exact saved marker starts the milestone rays and fanfare together")
	page.configure(_saved_state(store, wallet))
	check(cues.size() == 3 and page.snapshot().level_up_count == unlocked.level_up_count,
		"A repeated saved milestone cannot repeat its fanfare")
	check(page.present(_saved_state(store, wallet), word, false)
		and page.snapshot().deposit_count == unlocked.deposit_count
		and page.snapshot().level_up_count == unlocked.level_up_count and cues.size() == 3,
		"Reopening preserves diagnostic counters without celebrating an already owned level")
	check(store.begin_upgrade_contribution("auto_merge"), "Reserve a saved contribution on the other track")
	var other: Dictionary = store.upgrade_state().pending
	check(wallet.spend(other.id, other.amount).ok and store.complete_upgrade_contribution(wallet),
		"Commit the independent Auto merge contribution")
	page.configure(_saved_state(store, wallet))
	check(page.snapshot().kind == "auto_merge" and page.snapshot().funded == 25
		and page.snapshot().level == 2 and page.snapshot().auto_merge_level == 1 and cues.size() == 4,
		"An independently committed Auto merge deposit follows its exact saved track without changing Jelly ownership")
	page.configure(_saved_state(store, wallet))
	page.select_upgrade("jelly")
	page.select_upgrade("auto_merge")
	check(page.snapshot().funded == 25 and page.snapshot().visual_progress == 0.5
		and page.snapshot().level == 2 and page.snapshot().owned_level == 1 and cues.size() == 4,
		"Switching tracks reveals saved partial progress without inventing a new deposit")
	page.start_charging()
	_frames(4)
	page.stop_charging()
	check(page.snapshot().auto_merge_level == 2 and page.snapshot().level == 2
		and page.snapshot().level_up_count == unlocked.level_up_count + 1,
		"The Auto merge milestone advances its own permanent ownership")
	page.select_level(9)
	page.start_charging()
	_frames(4)
	page.stop_charging()
	check(page.snapshot().selected_level == 3 and page.snapshot().auto_merge_level == 2
		and page.snapshot().funded == 25 and page.snapshot().price == 100
		and requests.back() == {"kind": "auto_merge", "amount": 25},
		"Charging from a distant preview still funds only the next Auto merge level")
	page.contribution_requested.disconnect(commit)


func _test_continuous_charge_feedback() -> void:
	_reset()
	page.advance(0.05)
	var preview_clock: float = page.snapshot().preview.elapsed
	page.start_charging()
	check(page.snapshot().preview.elapsed == preview_clock,
		"Charging the visible next level preserves its running demonstration")
	var energy: float = page.snapshot().charge_energy
	check(energy > 0.0 and charge_states == [true] and page.snapshot().wallet_energy == 0.0,
		"Press acknowledges charging immediately without pretending to debit the wallet")
	for index in range(5):
		page.advance(0.025)
		var next_energy: float = page.snapshot().charge_energy
		check(next_energy > energy and next_energy < 1.0 and page.snapshot().balance == 5000,
			"Held button energy grows between payment pulses without changing saved coins")
		energy = next_energy
	page.stop_charging()
	page.stop_charging()
	check(charge_states == [true, false], "Repeated cancellation releases the continuous charging sound only once")
	page.advance(0.025)
	check(page.snapshot().charge_energy < energy, "Release lets the button light settle without a visual cut")
	var state: Dictionary = _initial_state()
	state.balance = 4975
	state.funded.jelly = 25
	var styles: StyleBox = page._buy.get_theme_stylebox("normal")
	var layouts: int = page.snapshot().layout_count
	page.configure(state)
	check(page.snapshot().visual_balance == 5000.0 and cues == ["upgrade_coin"]
		and page.snapshot().wallet_energy > 0.0 and page.snapshot().coin_flights == 0,
		"A saved debit starts wallet feedback and retargets the count without flying coins")
	check(page.snapshot().layout_count == layouts and page._buy.get_theme_stylebox("normal") == styles,
		"Ordinary deposits retain the existing layout and button styles")
	var displayed: float = page.snapshot().visual_balance
	for index in range(10):
		page.advance(1.0 / 60.0)
		var next_displayed: float = page.snapshot().visual_balance
		check(next_displayed < displayed and next_displayed > 4975.0,
			"The wallet count decreases on consecutive frames between committed receipts")
		displayed = next_displayed
	state.balance = 4950
	state.funded.jelly = 50
	page.configure(state)
	check(page.snapshot().visual_balance == displayed and page.snapshot().layout_count == layouts,
		"The next debit retargets the running count without resetting its position or rebuilding the page")
	page.configure(state)
	check(cues == ["upgrade_coin", "upgrade_coin"], "Repeated saved state cannot replay a wallet debit sound")
	_frames(30)
	check(page.snapshot().visual_balance == 4950.0 and page._wallet.text == "4950"
		and page.snapshot().wallet_energy < 0.02 and page.snapshot().charge_energy < 0.02,
		"The count settles on the exact saved balance and both local effects become quiet")
	page.set_reduced_motion(true)
	page.start_charging()
	state.balance = 4925
	state.funded.jelly = 75
	page.configure(state)
	page.advance(0.05)
	check(page.snapshot().charge_energy > 0.0 and page.snapshot().wallet_energy > 0.0
		and page._wallet_icon.scale == Vector2.ONE and page.snapshot().coin_flights == 0,
		"Reduced motion preserves charging and spend light while suppressing moving wallet artwork")
	page.stop_charging()
	_reset()
	state = _initial_state()
	state.level = 2
	state.balance = 4950
	page.configure(state)
	page.start_charging()
	check(page.snapshot().milestone_pending and page.snapshot().selected_level == 2,
		"A quick repress retains the earned level until its pending milestone is revealed")
	_frames(3)
	check(page.snapshot().payoff > 0.0 and page.snapshot().selected_level == 2 and requests.is_empty(),
		"The exact marker reveals its earned preview before a fresh hold can request more coins")
	page.stop_charging()
	page.start_charging()
	check(page.snapshot().payoff > 0.0 and page.snapshot().selected_level == 2,
		"Repressing during an active milestone preserves the earned preview under its rays")
	page._charge_wait = 2.0
	var earned_preview_retained := true
	for index in range(20):
		page.advance(0.05)
		if page.snapshot().payoff > 0.0 and page.snapshot().selected_level != 2:
			earned_preview_retained = false
	check(earned_preview_retained and page.snapshot().payoff == 0.0 and page.snapshot().selected_level == 3,
		"The next preview appears only after the earned milestone finishes")
	page.stop_charging()
	_reset()
	page.configure(state)
	_frames(3)
	page.select_level(9)
	check(page.snapshot().payoff == 0.0 and page.snapshot().selected_level == 9,
		"Inspecting a locked preview clears the previous earned level's celebration")
	page.stop_charging()
	_reset()
	state = _initial_state()
	state.level = 2
	state.balance = 4950
	page.configure(state)
	page.set_active(false)
	page.set_active(true)
	_frames(8)
	check(not page.snapshot().milestone_pending and page.snapshot().payoff == 0.0
		and cues == ["upgrade_coin"],
		"Background cancellation cannot replay a queued milestone sound on return")


func _test_reduced_motion_and_charge_gates() -> void:
	_reset()
	page.set_reduced_motion(true)
	var state: Dictionary = _initial_state()
	state.funded.jelly = 25
	state.balance = 4975
	page.configure(state)
	_frames(1)
	check(page.snapshot().visual_progress == 0.5 and page.snapshot().coin_flights == 0
		and page._hero.scale == Vector2.ONE and page._hero.position == page._hero_base
		and cues == ["upgrade_coin"],
		"Reduced motion shows committed progress and audio without flying coins or Jelly squash")
	var elapsed: float = page.snapshot().preview.elapsed
	state.level = 2
	state.funded.jelly = 0
	state.balance = 4950
	state.intro = "complete"
	page.configure(state)
	_frames(4)
	check(page.snapshot().preview.elapsed == elapsed and page.snapshot().preview.reduced_motion
		and page.snapshot().visual_progress == 1.0 and page.snapshot().payoff > 0.0
		and page.snapshot().coin_flights == 0 and page._hero.scale == Vector2.ONE
		and page._hero.position == page._hero_base and is_zero_approx(page._wand.rotation)
		and cues == ["upgrade_coin", "upgrade_coin", "goal_complete"],
		"Reduced motion retains a milestone glow and sound while freezing motion in the real ability preview")
	page.set_reduced_motion(false)
	_frames(1)
	check(page.snapshot().preview.elapsed > elapsed, "The ability demonstration resumes when motion is enabled")
	for gate: String in ["balance", "busy", "error", "pending", "capped"]:
		var gated: Dictionary = _initial_state()
		match gate:
			"balance": gated.balance = 24
			"busy": gated.busy = true
			"error": gated.error = "Storage is unavailable."
			"pending": gated.pending = {"kind": "jelly", "level": 2, "price": 50, "id": "reserved"}
			"capped":
				gated.level = 9
				gated.intro = "complete"
		page.present(gated, word, false)
		requests.clear()
		page.start_charging()
		_frames(8)
		check(not page.snapshot().buy.enabled and not page.snapshot().charging and requests.is_empty(),
			"The %s gate blocks all contribution requests" % gate)
	page.present(_initial_state(), word, true, 2, true)
	requests.clear()
	page.start_charging()
	_frames(8)
	check(page.is_offer() and page.navigation_controls().size() == 2 and requests.is_empty(),
		"The first-clear offer owns only its two introduction actions and cannot charge")
	page.set_active(false)
	check(page.navigation_controls().is_empty() and page._offer_accept.disabled,
		"Inactive application state cannot advance the introduction")


func capture_ui(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-upgrades")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/qa/jelly-upgrades/" + name + ".png") == OK,
		"Capture the actual " + name)


func _test_responsive_layout() -> void:
	_reset()
	for dimensions: Vector2i in [Vector2i(320, 480), Vector2i(390, 664), Vector2i(393, 852),
			Vector2i(844, 390), Vector2i(1366, 900)]:
		root.size = dimensions
		holder.size = Vector2(dimensions)
		page.size = Vector2(dimensions)
		await process_frame
		page._layout()
		var bounds := Rect2(Vector2.ZERO, page.size)
		var footer_bounds: Rect2 = page._footer.get_global_rect()
		check(bounds.grow(0.1).encloses(page._stage.get_rect())
			and bounds.grow(0.1).encloses(page._footer.get_rect())
			and not page._stage.get_rect().intersects(page._footer.get_rect()),
			"The Jelly stage and charge footer remain separate within %s" % dimensions)
		check(footer_bounds.grow(0.1).encloses(page._scroll.get_global_rect())
			and footer_bounds.grow(0.1).encloses(page._buy.get_global_rect())
			and not page._scroll.get_global_rect().intersects(page._buy.get_global_rect())
			and not page._progress.get_global_rect().intersects(page._buy.get_global_rect()),
			"The level rail, funded amount and hold button have distinct reachable space")
		check(page._buy.size.y * page.Style.ui_scale(page) >= 44.0 - 0.1
			and page._back.size.y * page.Style.ui_scale(page) >= 44.0 - 0.1,
			"Primary and back actions retain full touch targets")
		check(not page._back.get_rect().intersects(page._heading.get_rect())
			and not page._heading.get_rect().intersects(page._wallet_icon.get_rect()),
			"Back, title and saved coins keep distinct header space")
		for category: Button in page._category_buttons.values():
			check(category.size.y * page.Style.ui_scale(page) >= 44.0 - 0.1
				and bounds.grow(0.1).encloses(category.get_global_rect())
				and not category.get_global_rect().intersects(page._stage.get_global_rect()),
				"Both upgrade categories remain full-size targets above the Jelly stage")
		for tab: Dictionary in page._tabs:
			check(Rect2(Vector2.ZERO, page._levels.size).grow(0.1).encloses(tab.button.get_rect())
				and tab.button.size.y * page.Style.ui_scale(page) >= 44.0 - 0.1,
				"Every level marker has a reachable full-size preview target")
		page._scroll.scroll_horizontal = 100000
		await process_frame
		check(page._scroll.get_global_rect().grow(0.1).has_point(page._tabs.back().button.get_global_rect().get_center()),
			"The last level marker remains reachable by scrolling the rail")
		page.select_upgrade("auto_merge")
		check(Rect2(Vector2.ZERO, page._stage.size).grow(0.1).encloses(page._wand.get_rect())
			and Rect2(Vector2.ZERO, page._stage.size).grow(0.1).encloses(page._preview.get_rect()),
			"Auto merge artwork and its actual capacity preview stay inside the stage")
		await capture_ui("hold-upgrade-%dx%d" % [dimensions.x, dimensions.y])
		var error_state: Dictionary = _initial_state()
		error_state.error = "Your campaign has not saved. Retry saving."
		page.configure(error_state)
		check(bounds.grow(0.1).encloses(page._notice.get_global_rect()),
			"A real save failure remains readable inside the screen at %s" % dimensions)
		page.configure(_initial_state())
		page.select_upgrade("jelly")


func _capture_charge_feedback() -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(1366, 768)]:
		root.size = dimensions
		holder.size = Vector2(dimensions)
		page.size = Vector2(dimensions)
		var state: Dictionary = _initial_state()
		state.level = 3
		_reset(state)
		page._layout()
		var commit := func(_kind: String, _amount: int) -> void:
			state.balance -= 25
			state.funded.jelly += 25
			page.configure(state)
		page.contribution_requested.connect(commit)
		page.start_charging()
		for frame in range(24):
			page.advance(1.0 / 60.0)
			await process_frame
		await capture_ui("charging-%dx%d" % [dimensions.x, dimensions.y])
		page.stop_charging()
		for frame in range(8):
			page.advance(1.0 / 60.0)
			await process_frame
		await capture_ui("charge-release-%dx%d" % [dimensions.x, dimensions.y])
		page.set_reduced_motion(true)
		page.start_charging()
		for frame in range(12):
			page.advance(1.0 / 60.0)
			await process_frame
		await capture_ui("charging-reduced-%dx%d" % [dimensions.x, dimensions.y])
		page.stop_charging()
		page.contribution_requested.disconnect(commit)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	root.add_child(holder)
	holder.size = Vector2(root.size)
	page = Page.new()
	holder.add_child(page)
	page.size = Vector2(root.size)
	page.contribution_requested.connect(func(kind: String, amount: int) -> void:
		requests.append({"kind": kind, "amount": amount}))
	page.purchase_requested.connect(func(_level: int, _kind: String) -> void: legacy_requests += 1)
	page.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	page.charging_changed.connect(func(active: bool) -> void: charge_states.append(active))
	page.retry_requested.connect(func() -> void: retries += 1)
	_test_previews_and_no_fake_progress()
	_test_hold_cancellation()
	_test_committed_feedback_and_independent_tracks()
	_test_continuous_charge_feedback()
	_test_reduced_motion_and_charge_gates()
	await _test_responsive_layout()
	await _capture_charge_feedback()
	page.free()
	print("Jelly hold-to-charge view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

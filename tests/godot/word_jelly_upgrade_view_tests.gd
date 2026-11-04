extends SceneTree

const Page = preload("res://scripts/word_jelly_upgrades.gd")
const Preview = preload("res://scripts/word_jelly_ability_preview.gd")
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


func _advance_to_marker() -> void:
	for frame in range(24):
		if not page.snapshot().milestone_pending:
			break
		page.advance(0.025)
	check(not page.snapshot().milestone_pending,
		"The earned stored marker is reached within its bounded presentation glide")


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
	check(not stalled.wallet_digits_rolling,
		"An unacknowledged hold cannot animate a debit through the wallet digits")
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
	_advance_to_marker()
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
	check(page.snapshot().displayed_level == 1 and page.snapshot().selected_level == 2
		and page._tier.text == "Lv 1" and page._name.text == Preview.NAMES[1]
		and page._hero.merge_level == 1,
		"The first hold shows the current owned level while previewing its next ability")
	check(not page.snapshot().wallet_digits_rolling,
		"Holding the charge button alone leaves the saved wallet digits still")
	for index in range(5):
		page.advance(0.025)
		var next_energy: float = page.snapshot().charge_energy
		check(next_energy > energy and next_energy < 1.0 and page.snapshot().balance == 5000,
			"Held button energy grows between payment pulses without changing saved coins")
		check(is_equal_approx(page.snapshot().subject_charge_energy, next_energy)
			and (not page._hero.scale.is_equal_approx(Vector2.ONE)
				or not page._hero.position.is_equal_approx(page._hero_base)),
			"The subject continuously responds to the same held-charge energy before any debit")
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
		check(page.snapshot().wallet_digits_rolling,
			"A real saved debit keeps the visible numeral transition active between receipts")
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
	check(not page.snapshot().wallet_digits_rolling and page._wallet.self_modulate.a > 0.99,
		"Settling restores one fully visible exact balance without a lingering rolling layer")
	page.set_reduced_motion(true)
	page.start_charging()
	state.balance = 4925
	state.funded.jelly = 75
	page.configure(state)
	page.advance(0.05)
	check(page.snapshot().charge_energy > 0.0 and page.snapshot().wallet_energy > 0.0
		and page._wallet_icon.scale == Vector2.ONE and page.snapshot().coin_flights == 0,
		"Reduced motion preserves charging and spend light while suppressing moving wallet artwork")
	check(is_equal_approx(page.snapshot().subject_charge_energy, page.snapshot().charge_energy)
		and page._hero.scale == Vector2.ONE and page._hero.position == page._hero_base,
		"Reduced motion retains subject charge light without moving or squashing the Jelly")
	check(not page.snapshot().wallet_digits_rolling and page._wallet.self_modulate.a > 0.99,
		"Reduced motion keeps the saved amount readable without sliding numeral columns")
	page.stop_charging()
	_reset()
	state = _initial_state()
	state.level = 2
	state.balance = 4950
	page.configure(state)
	page.start_charging()
	check(page.snapshot().milestone_pending and page.snapshot().selected_level == 2,
		"A quick repress retains the earned level until its pending milestone is revealed")
	_advance_to_marker()
	check(page.snapshot().payoff > 0.0 and page.snapshot().selected_level == 2 and requests.size() <= 1
		and requests.all(func(request: Dictionary) -> bool: return request == {"kind": "jelly", "amount": 25}),
		"The pending earned preview survives a quick repress and any unacknowledged next contribution")
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
	_advance_to_marker()
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


func _test_displayed_level_milestones() -> void:
	_reset()
	page.start_charging()
	check(page.snapshot().displayed_level == 1 and page.snapshot().selected_level == 2
		and page._tier.text == "Lv 1" and page._name.text == Preview.NAMES[1]
		and page._hero.merge_level == 1 and not page.snapshot().level_reveal_pending,
		"A normal first hold begins with the current Lv rather than displaying an unearned Lv")
	var earned: Dictionary = _initial_state()
	earned.level = 2
	earned.balance = 4950
	earned.intro = "complete"
	page.configure(earned)
	page.stop_charging()
	check(page.snapshot().selected_level == 2 and page.snapshot().displayed_level == 1
		and page.snapshot().milestone_pending and page.snapshot().level_reveal_pending
		and page.snapshot().payoff == 0.0 and page._tier.text == "Lv 1"
		and page._name.text == Preview.NAMES[1] and page._hero.merge_level == 1,
		"A committed level keeps the current visible Lv while its earned marker approaches")
	_frames(2)
	check(page.snapshot().displayed_level == 1 and page.snapshot().payoff == 0.0
		and page.snapshot().milestone_pending and page._tier.text == "Lv 1"
		and page._name.text == Preview.NAMES[1] and page._hero.merge_level == 1,
		"The prior Lv remains visible for the full rail approach")
	_advance_to_marker()
	check(page.snapshot().payoff > 0.0 and not page.snapshot().milestone_pending
		and page.snapshot().level_reveal_pending and page.snapshot().displayed_level == 1
		and page._tier.text == "Lv 1" and page._name.text == Preview.NAMES[1]
		and page._hero.merge_level == 1 and cues == ["upgrade_coin", "goal_complete"],
		"The saved marker begins its burst and sound before replacing the visible Lv")
	page.advance(0.04)
	page.configure(earned)
	check(page.snapshot().displayed_level == 1 and page.snapshot().level_reveal_pending
		and page._tier.text == "Lv 1" and page._name.text == Preview.NAMES[1]
		and page._hero.merge_level == 1 and cues == ["upgrade_coin", "goal_complete"],
		"A repeated saved state preserves the short old-Lv reveal beat without repeating audio")
	_frames(3)
	check(page.snapshot().displayed_level == 2 and not page.snapshot().level_reveal_pending
		and page.snapshot().payoff > 0.0 and page._tier.text == "Lv 2"
		and page._name.text == Preview.NAMES[2] and page._hero.merge_level == 2,
		"The earned Lv replaces the old Lv during the milestone's visible payoff")
	page.configure(earned)
	_frames(20)
	check(page.snapshot().displayed_level == 2 and page._tier.text == "Lv 2"
		and page._name.text == Preview.NAMES[2] and page._hero.merge_level == 2
		and not page.snapshot().level_reveal_pending and cues == ["upgrade_coin", "goal_complete"],
		"The earned Lv settles once and duplicate configuration cannot replay its reveal")
	page.start_charging()
	_frames(1)
	check(page.snapshot().selected_level == 3 and page.snapshot().displayed_level == 2
		and page._tier.text == "Lv 2" and page._name.text == Preview.NAMES[2]
		and page._hero.merge_level == 2,
		"A subsequent hold keeps the earned Lv visible while previewing the next ability")
	page.stop_charging()
	for beat: String in ["rail", "reveal"]:
		for action: String in ["hide", "inactive", "category", "selection", "present"]:
			_reset()
			page.start_charging()
			page.configure(earned)
			page.stop_charging()
			if beat == "reveal":
				_advance_to_marker()
			var cue_count: int = cues.size()
			match action:
				"hide": page.hide()
				"inactive": page.set_active(false)
				"category": page.select_upgrade("auto_merge")
				"selection": page.select_level(8)
				"present": page.present(earned, word, false)
			var settled: Dictionary = page.snapshot()
			check(not settled.level_reveal_pending and settled.displayed_level == settled.selected_level
				and page._tier.text == "Lv %d" % settled.selected_level,
				"The %s action settles the selected Lv and cancels the queued %s reveal" % [action, beat])
			page.show()
			page.set_active(true)
			_frames(8)
			check(cues.size() == cue_count and not page.snapshot().level_reveal_pending,
				"Returning after %s cannot replay the cancelled %s reveal or sound" % [action, beat])
	_reset()
	page.set_reduced_motion(true)
	page.start_charging()
	page.configure(earned)
	check(page.snapshot().visual_progress == 1.0 and page.snapshot().payoff > 0.0
		and page.snapshot().displayed_level == 2 and not page.snapshot().level_reveal_pending
		and page._tier.text == "Lv 2" and page._name.text == Preview.NAMES[2]
		and page._hero.merge_level == 2 and page._hero.scale == Vector2.ONE
		and page._hero.position == page._hero_base and cues == ["upgrade_coin", "goal_complete"],
		"Reduced motion reveals the earned Lv immediately with milestone light and sound")
	page.stop_charging()


func _check_progress_caption(message: String) -> void:
	var actual: Dictionary = page.snapshot()
	var visual: float = float(actual.visual_progress)
	if int(actual.owned_level) == 9 and visual >= 8.0 - 0.0000001:
		check(page._progress.text.replace(" ", "") == "Lv9" and not page._progress_coin.visible,
			"%s settles on the completed Lv9 caption at the final marker" % message)
		return
	var parts: PackedStringArray = page._progress.text.split(" / ", false)
	var valid: bool = parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int()
	check(valid, "%s keeps one readable funded amount and price" % message)
	if not valid:
		return
	var segment: int = clampi(floori(visual + 0.0000001), 0, 7)
	var price: int = Page.Economy.permanent_upgrade_price(actual.kind, segment + 2)
	var phase: float = clampf(visual - segment, 0.0, 1.0)
	var amount: int = int(parts[0])
	var paid_limit: int = int(actual.funded) if segment == int(actual.owned_level) - 1 else price
	check(int(parts[1]) == price and absf(float(amount) - phase * price) <= 1.000001,
		"%s aligns its visible amount and denominator with the moving rail segment: %s at %.6f" % [message, page._progress.text, visual])
	check(amount >= 0 and amount <= paid_limit,
		"%s never displays coins beyond the acknowledged funding of that segment" % message)
	var accessible: bool = page._progress.accessibility_name.contains("All milestones complete") \
		if int(actual.owned_level) == 9 else page._progress.accessibility_name.contains("%d of %d" % [actual.funded, actual.price])
	check(accessible,
		"%s preserves the exact committed amount and current price for accessibility" % message)


func _test_held_progress_continuity() -> void:
	var state: Dictionary = _initial_state()
	state.level = 8
	state.intro = "complete"
	_reset(state)
	var layouts: int = page.snapshot().layout_count
	var receipts: Array[int] = []
	var baseline_deposits: int = page.snapshot().deposit_count
	var commit := func(kind: String, amount: int) -> void:
		state.balance -= amount
		state.funded[kind] += amount
		page.configure(state)
		receipts.append(amount)
	page.contribution_requested.connect(commit)
	page.start_charging()
	var first_receipt := false
	var still_frames := 0
	var longest_still := 0
	var elapsed_frames := 0
	for frame in range(180):
		var previous: Dictionary = page.snapshot()
		page.advance(1.0 / 60.0)
		var actual: Dictionary = page.snapshot()
		_check_progress_caption("A held Lv8 funding frame")
		check(is_finite(actual.visual_progress) and actual.visual_progress >= previous.visual_progress
			and actual.visual_progress <= actual.progress + 0.000001,
			"Held funding moves forward without displaying unsaved rail progress")
		check(actual.balance == state.balance and actual.funded == state.funded.jelly
			and actual.owned_level == 8 and actual.deposit_count == baseline_deposits + receipts.size(),
			"Every visible held receipt corresponds to one acknowledged deposit on the current track")
		if first_receipt:
			elapsed_frames += 1
			if actual.visual_progress <= previous.visual_progress + 0.0000001:
				still_frames += 1
				longest_still = maxi(longest_still, still_frames)
			else:
				still_frames = 0
			check(actual.visual_balance < previous.visual_balance,
				"The visible wallet keeps decreasing between acknowledged held receipts")
		first_receipt = first_receipt or not receipts.is_empty()
	check(receipts.size() >= 10 and elapsed_frames >= 150 and longest_still <= 1,
		"A sustained three-second hold has no perceptible stop between committed funding pulses")
	check(page.snapshot().charging and charge_states == [true]
		and page.snapshot().layout_count == layouts and page.snapshot().coin_flights == 0,
		"One uninterrupted hold keeps its charging channel and layout without restarted coin flights")
	page.stop_charging()
	var frozen_receipts: int = receipts.size()
	_frames(16)
	check(receipts.size() == frozen_receipts and charge_states == [true, false]
		and page.snapshot().visual_progress == page.snapshot().progress,
		"Release settles on the exact last committed progress without requesting another payment")
	var resting: Dictionary = page.snapshot()
	check(page._progress.text == "%d / %d" % [resting.funded, resting.price],
		"The resting funding caption settles on the exact acknowledged amount")
	page.start_charging()
	_frames(2)
	page.stop_charging()
	check(receipts.size() == frozen_receipts and charge_states == [true, false, true, false],
		"A short repeated hold restarts acknowledgement and cancels before another debit")
	page.contribution_requested.disconnect(commit)


func _test_milestone_funding_cadence() -> void:
	for kind: String in ["jelly", "auto_merge"]:
		var state: Dictionary = _initial_state()
		state["level" if kind == "jelly" else "auto_merge_level"] = 7
		state.funded[kind] = Page.Economy.permanent_upgrade_price(kind, 8) - Page.PULSE_AMOUNT
		state.intro = "complete"
		_reset(state)
		if kind == "auto_merge":
			page.select_upgrade(kind)
		var clock := {"elapsed": 0.0}
		var receipts: Array[float] = []
		var baseline_milestones: int = page.snapshot().level_up_count
		var commit := func(track: String, amount: int) -> void:
			state.balance -= amount
			state.funded[track] += amount
			var key: String = "level" if track == "jelly" else "auto_merge_level"
			if state.funded[track] == Page.Economy.permanent_upgrade_price(track, int(state[key]) + 1):
				state[key] += 1
				state.funded[track] = 0
			page.configure(state)
			receipts.append(clock.elapsed)
		page.contribution_requested.connect(commit)
		page.start_charging()
		var saw_old_level := false
		var saw_earned_level := false
		var first_receipt := false
		var still_frames := 0
		var longest_still := 0
		for frame in range(150):
			var previous: Dictionary = page.snapshot()
			clock.elapsed += 1.0 / 60.0
			page.advance(1.0 / 60.0)
			var actual: Dictionary = page.snapshot()
			_check_progress_caption("The %s milestone funding frame" % kind)
			saw_old_level = saw_old_level or actual.displayed_level == 7
			saw_earned_level = saw_earned_level or actual.displayed_level == 8
			check(actual.charging and charge_states == [true]
				and actual.visual_progress <= actual.progress + 0.000001,
				"A committed %s milestone preserves the held gesture without speculative funding" % kind)
			if first_receipt:
				if actual.visual_progress <= previous.visual_progress + 0.0000001:
					still_frames += 1
					longest_still = maxi(longest_still, still_frames)
				else:
					still_frames = 0
			first_receipt = first_receipt or not receipts.is_empty()
		check(receipts.size() >= 10 and saw_old_level and saw_earned_level,
			"A sustained %s hold reveals the earned Lv and keeps funding the next one" % kind)
		var longest_gap := 0.0
		for index in range(1, receipts.size()):
			longest_gap = maxf(longest_gap, receipts[index] - receipts[index - 1])
		check(longest_gap <= 0.25 and page.snapshot().owned_level == 8,
			"A %s upgrade adds no artificial funding pause around its level-switch effect" % kind)
		check(longest_still <= 1,
			"The %s rail keeps moving across its milestone and next receipt without a stationary beat" % kind)
		check(page.snapshot().level_up_count == baseline_milestones + 1
			and cues.count("goal_complete") == 1,
			"The %s marker triggers one milestone even when another deposit retargets the moving rail" % kind)
		page.configure(state)
		check(cues.count("goal_complete") == 1,
			"Repeating the final saved %s snapshot cannot replay its level-switch sound" % kind)
		page.stop_charging()
		_frames(16)
		var resting: Dictionary = page.snapshot()
		check(page._progress.text == "%d / %d" % [resting.funded, resting.price],
			"The %s post-milestone caption settles on exact next-tier funding" % kind)
		page.contribution_requested.disconnect(commit)


func _test_final_funding_caption() -> void:
	var state: Dictionary = _initial_state()
	state.level = 8
	state.intro = "complete"
	state.funded.jelly = Page.Economy.permanent_upgrade_price("jelly", 9) - Page.PULSE_AMOUNT
	_reset(state)
	_check_progress_caption("The last paid segment before Lv9")
	page.start_charging()
	state.balance -= Page.PULSE_AMOUNT
	state.level = 9
	state.funded.jelly = 0
	page.configure(state)
	check(page.snapshot().owned_level == 9 and not page.snapshot().charging
		and not page.snapshot().buy.enabled,
		"The final saved receipt stops further charging while its marker approaches")
	_check_progress_caption("The committed Lv9 receipt before its visual crossing")
	for frame in range(20):
		page.advance(1.0 / 60.0)
		_check_progress_caption("The final marker approach and completed caption")
	check(page.snapshot().visual_progress == 8.0 and cues.count("goal_complete") == 1,
		"The final caption reaches Lv9 once with its earned marker effect")
	page.configure(state)
	check(cues.count("goal_complete") == 1,
		"A duplicate final receipt cannot repeat its completed caption milestone")
	state.level = 8
	state.funded.jelly = Page.Economy.permanent_upgrade_price("jelly", 9) - Page.PULSE_AMOUNT
	_reset(state)
	page.set_reduced_motion(true)
	state.balance -= Page.PULSE_AMOUNT
	state.level = 9
	state.funded.jelly = 0
	page.configure(state)
	_check_progress_caption("The reduced-motion final milestone")
	check(page.snapshot().visual_progress == 8.0,
		"Reduced motion settles the final caption on its committed marker immediately")


func _test_reduced_motion_and_charge_gates() -> void:
	_reset()
	page.set_reduced_motion(true)
	var state: Dictionary = _initial_state()
	state.funded.jelly = 25
	state.balance = 4975
	page.configure(state)
	_frames(1)
	_check_progress_caption("A reduced-motion partial contribution")
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
	_check_progress_caption("A reduced-motion milestone")
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


func _wallet_ink_bounds() -> Rect2:
	var ink := Rect2()
	for index in range(page._wallet.text.length()):
		var glyph: Rect2 = page._wallet.get_character_bounds(index)
		if glyph.has_area():
			ink = ink.merge(glyph) if ink.has_area() else glyph
	return page._wallet.get_global_transform() * ink


func _coin_ink_bounds() -> Rect2:
	var icon: TextureRect = page._wallet_icon
	var texture: Texture2D = icon.texture
	var source_size := Vector2(texture.get_width(), texture.get_height())
	var scale: float = minf(icon.size.x / source_size.x, icon.size.y / source_size.y)
	var offset: Vector2 = (icon.size - source_size * scale) * 0.5
	var painted: Rect2i = texture.get_image().get_used_rect()
	var local := Rect2(offset + Vector2(painted.position) * scale, Vector2(painted.size) * scale)
	return icon.get_global_transform() * local


func _check_wallet_spacing(message: String) -> void:
	var ink: Rect2 = _wallet_ink_bounds()
	var coin: Rect2 = _coin_ink_bounds()
	var gap: float = (ink.position.x - coin.end.x) * page.Style.ui_scale(page)
	check(ink.has_area() and gap >= 3.0 and gap <= 16.0,
		"%s keeps the painted coin close to the visible digits: %.2f design pixels" % [message, gap])
	check(Rect2(Vector2.ZERO, page.size).grow(0.1).encloses(ink)
		and not page._heading.get_global_rect().intersects(coin),
		"%s leaves the amount on screen and clear of the title" % message)


func _test_wallet_digit_boundary() -> void:
	var state: Dictionary = _initial_state()
	state.balance = 1000
	_reset(state)
	await process_frame
	check(page._wallet.text == "1000", "The boundary transition starts from the real four-digit balance")
	var layouts: int = page.snapshot().layout_count
	var right_edge: float = _wallet_ink_bounds().end.x
	state.balance = 975
	state.funded.jelly = 25
	page.configure(state)
	var saw_three_digits: bool = false
	for index in range(60):
		page.advance(1.0 / 60.0)
		await process_frame
		if page._wallet.text.length() == 3:
			saw_three_digits = true
		_check_wallet_spacing("A debit crossing 1000 to 975")
		check(absf(_wallet_ink_bounds().end.x - right_edge) * page.Style.ui_scale(page) <= 2.0
			and page.snapshot().layout_count == layouts,
			"Digit-width changes keep the wallet's right edge fixed without rebuilding the upgrade page")
	check(saw_three_digits and not page.snapshot().wallet_digits_rolling and page._wallet.text == "975",
		"Crossing to three digits completes on the exact committed amount and ends the transition")
	state.balance = 950
	state.funded.jelly = 50
	page.configure(state)
	check(page.snapshot().wallet_digits_rolling, "A subsequent saved debit can start another visible numeral transition")
	page.set_active(false)
	check(not page.snapshot().wallet_digits_rolling,
		"Backgrounding removes the moving numeral layer immediately")
	_reset(state)
	state.balance = 925
	state.funded.jelly = 75
	page.configure(state)
	page.close()
	check(not page.snapshot().wallet_digits_rolling,
		"Closing the upgrade page cannot leave a hidden debit animation running")


func _test_responsive_layout() -> void:
	_reset()
	for dimensions: Vector2i in [Vector2i(320, 480), Vector2i(390, 664), Vector2i(393, 852),
			Vector2i(844, 390), Vector2i(1280, 720), Vector2i(1366, 900)]:
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
		var stage_values: Array = page.snapshot().stage
		var hero_values: Array = page.snapshot().hero
		var stage := Rect2(stage_values[0], stage_values[1], stage_values[2], stage_values[3])
		var hero := Rect2(hero_values[0], hero_values[1], hero_values[2], hero_values[3])
		var preview: Rect2 = page._preview.get_global_rect()
		var showcase: Rect2 = hero.merge(preview)
		check(stage.grow(0.1).encloses(showcase)
			and not showcase.intersects(page._tier.get_global_rect())
			and not showcase.intersects(page._name.get_global_rect()),
			"The hero and readable ability preview stay together inside the stage below its title at %s" % dimensions)
		check(not stage.intersects(page._heading.get_global_rect())
			and not stage.intersects(footer_bounds) and not hero.intersects(footer_bounds),
			"The showcase stage and hero remain clear of the page title and charge footer at %s" % dimensions)
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
		for balance: int in [437, 0, 99, 1000, 100000]:
			var state: Dictionary = _initial_state()
			state.balance = balance
			_reset(state)
			await process_frame
			_check_wallet_spacing("Wallet %d at %s" % [balance, dimensions])
		_reset()
		await process_frame
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


func _test_rail_marker_bounds() -> void:
	for dimensions: Vector2i in [Vector2i(320, 480), Vector2i(393, 852), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = dimensions
		holder.size = Vector2(dimensions)
		page.size = Vector2(dimensions)
		for level in range(1, 10):
			var state: Dictionary = _initial_state()
			state.level = level
			state.intro = "complete"
			state.funded.jelly = 125 if level == 8 else 0
			_reset(state)
			page.select_level(level)
			await process_frame
			page._layout()
			var u: float = 1.0 / page.Style.ui_scale(page)
			var bounds := Rect2(Vector2.ZERO, page._levels.size)
			var rail_top: float = page._rail_origin.y - 7 * u
			for index in range(page._tabs.size()):
				var button: Button = page._tabs[index].button
				check(bounds.grow(0.1).encloses(button.get_rect())
					and button.size.x <= page._rail_pitch + 0.1
					and button.get_rect().end.y <= rail_top + 0.1,
					"Lv%d stays within its marker slot and above the rail at %s" % [index + 1, dimensions])
				check(button.size.x * page.Style.ui_scale(page) >= 44.0 - 0.1
					and button.size.y * page.Style.ui_scale(page) >= 44.0 - 0.1,
					"A compact marker retains its full preview touch target")
				if index > 0:
					check(not button.get_rect().intersects(page._tabs[index - 1].button.get_rect()),
						"Adjacent level preview markers never cover one another")
				for style_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
					var surface: StyleBox = button.get_theme_stylebox(style_name)
					check(surface is StyleBoxEmpty or surface is StyleBoxFlat and surface.bg_color.a == 0.0,
						"The %s marker state cannot paint an opaque panel across the rail" % style_name)
			page._scroll.scroll_horizontal = 100000
			await process_frame
			check(page._scroll.get_global_rect().grow(0.1).encloses(page._tabs.back().button.get_global_rect()),
				"The whole Lv9 label and preview target remain reachable without edge clipping")
		var screenshot: Dictionary = _initial_state()
		screenshot.level = 8
		screenshot.intro = "complete"
		screenshot.funded.jelly = 125
		_reset(screenshot)
		await process_frame
		page.select_level(7)
		page._tabs.back().button.grab_focus()
		var motion := InputEventMouseMotion.new()
		motion.position = page._tabs[6].button.get_global_rect().get_center()
		motion.global_position = motion.position
		root.push_input(motion)
		await capture_ui("rail-owned8-selected7-%dx%d" % [dimensions.x, dimensions.y])


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


func _capture_charge_motion() -> void:
	if not OS.get_cmdline_user_args().has("--capture-motion") or DisplayServer.get_name() == "headless":
		return
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(1366, 768)]:
		root.size = dimensions
		holder.size = Vector2(dimensions)
		page.size = Vector2(dimensions)
		var state: Dictionary = _initial_state()
		state.level = 7
		state.intro = "complete"
		state.funded.jelly = Page.Economy.permanent_upgrade_price("jelly", 8) - Page.PULSE_AMOUNT
		_reset(state)
		page._layout()
		var directory: String = "res://build/qa/jelly-upgrades/motion-%dx%d" % [dimensions.x, dimensions.y]
		check(DirAccess.make_dir_recursive_absolute(directory) == OK,
			"Keep charging motion captures in ignored QA output")
		var commit := func(kind: String, amount: int) -> void:
			state.balance -= amount
			state.funded[kind] += amount
			if state.funded[kind] == Page.Economy.permanent_upgrade_price(kind, int(state.level) + 1):
				state.level += 1
				state.funded[kind] = 0
			page.configure(state)
		page.contribution_requested.connect(commit)
		page.start_charging()
		for frame in range(65):
			page.advance(1.0 / 20.0)
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(directory + "/frame-%04d.png" % frame) == OK,
				"Capture the continuous held deposit and earned level reveal")
		page.stop_charging()
		page.contribution_requested.disconnect(commit)
		print("Charging motion: %s (65 frames at 20 fps)" % directory)


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
	_test_displayed_level_milestones()
	_test_held_progress_continuity()
	_test_milestone_funding_cadence()
	_test_final_funding_caption()
	_test_reduced_motion_and_charge_gates()
	await _test_wallet_digit_boundary()
	await _test_responsive_layout()
	await _test_rail_marker_bounds()
	await _capture_charge_feedback()
	await _capture_charge_motion()
	page.free()
	print("Jelly hold-to-charge view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

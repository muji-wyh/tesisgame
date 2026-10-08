extends SceneTree

const PopView = preload("res://scripts/voice_pop.gd")
const PopModel = preload("res://scripts/voice_pop_model.gd")

class FrameCountView:
	extends "res://scripts/voice_pop.gd"

	var geometry_updates: int = 0
	var hud_updates: int = 0
	var feedback_updates: int = 0

	func _refresh_targets() -> void:
		geometry_updates += 1
		super._refresh_targets()

	func _update_hud() -> void:
		hud_updates += 1
		super._update_hud()

	func _apply_hud_feedback() -> void:
		feedback_updates += 1
		super._apply_hud_feedback()

	func reset_counts() -> void:
		geometry_updates = 0
		hud_updates = 0
		feedback_updates = 0


var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in range(8):
		await process_frame


func result_pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func result_touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 23
	event.position = point
	event.pressed = pressed
	# Browser touchcancel reaches Godot as this ordinary release. The host
	# callback must have invalidated its original pending tap beforehand.
	root.push_input(event, true)
	await process_frame


func check_result_input_cancellation(app) -> void:
	var view = app._pop
	var activations: Array[String] = []
	var on_replay: Callable = func() -> void: activations.append("replay")
	var on_hear: Callable = func(_word: Dictionary) -> void: activations.append("hear")
	view.request_listening.connect(on_replay)
	view.hear_requested.connect(on_hear)
	var summary: Dictionary = view.game.summary()
	for cause in ["browser-cancel", "pause", "background", "modal"]:
		for touch_first in [true, false]:
			for button in [view.replay_button, view._review_buttons[0]]:
				view._results.scroll_vertical = 0
				view._ensure_result_control(button)
				await settle()
				var point: Vector2 = button.get_global_rect().intersection(view._results.get_global_rect()).get_center()
				var before: int = activations.size()
				if touch_first:
					await result_touch(point, true)
					await result_pointer(point, true)
				else:
					await result_pointer(point, true)
					await result_touch(point, true)
				check(view._results.is_pointer_active(), "The completed result owns a pending contact before " + cause)
				match cause:
					"browser-cancel":
						app._on_input_canceled([])
					"pause":
						view.pause()
					"background":
						app.on_page_hidden()
					"modal":
						app._show_leaderboard("boards", false)
				check(not view._results.is_pointer_active() and button.self_modulate.is_equal_approx(Color.WHITE),
					"%s immediately clears the completed result's pending tap and press tint" % cause)
				if cause == "background":
					app.on_page_visible()
				elif cause == "modal":
					app._hide_leaderboard()
				# Release only after the page/modal has returned: stale releases
				# must stay canceled even when result interaction is allowed again.
				if touch_first:
					await result_touch(point, false)
					await result_pointer(point, false)
				else:
					await result_pointer(point, false)
					await result_touch(point, false)
				check(activations.size() == before and not app._leaderboard_overlay.visible
					and view.game.phase == "finished" and view.game.summary() == summary,
					"An ordinary late release cannot activate %s after %s (touch first=%s)" % [button.name, cause, touch_first])
	view.request_listening.disconnect(on_replay)
	view.hear_requested.disconnect(on_hear)
	view._results.scroll_vertical = 0
	await settle()


func check_result_touch_scroll(view) -> void:
	# ScrollContainer consumes the mouse events emulated from touch. Enable the
	# touchscreen hint for the headless display, then send real viewport input.
	var original_touch_hint: bool = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	check(DisplayServer.is_touchscreen_available(), "The headless drag fixture exposes the touchscreen hint")
	var buttons: Array = [view.replay_button, view._review_buttons[0]]
	for button in buttons:
		view._results.scroll_vertical = 0
		await settle()
		button.grab_focus()
		view._ensure_result_control(button)
		await settle()
		var pressed: Array[bool] = []
		var record: Callable = func() -> void: pressed.append(true)
		button.pressed.connect(record)
		var point: Vector2 = button.get_global_rect().intersection(view._results.get_global_rect()).get_center()
		var before: int = view._results.scroll_vertical
		await result_pointer(point, true)
		for step in range(1, 7):
			var motion := InputEventMouseMotion.new()
			motion.device = InputEvent.DEVICE_ID_EMULATION
			motion.position = point + Vector2(0, -20 * step)
			motion.global_position = motion.position
			motion.relative = Vector2(0, -20)
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			root.push_input(motion, true)
			await process_frame
		check(view._results.scroll_vertical > before + 40,
			"Dragging from %s continuously scrolls beyond any focus reveal (before=%d after=%d max=%.1f point=%s button=%s viewport=%s filter=%d parent_filter=%d)" % [
				button.name, before, view._results.scroll_vertical, float(view.snapshot().results_scroll_max), point,
				button.get_global_rect(), view._results.get_global_rect(), button.mouse_filter, button.get_parent().mouse_filter])
		await result_pointer(point + Vector2(0, -120), false)
		check(pressed.is_empty() and view.game.phase == "finished",
			"Dragging from %s cancels its click without leaving the results" % button.name)
		button.pressed.disconnect(record)
		view._results.set_process_internal(false)
	var heard: Array[Dictionary] = []
	var on_hear: Callable = func(word: Dictionary) -> void: heard.append(word)
	view.hear_requested.connect(on_hear)
	var review: Button = view._review_buttons[0]
	view._ensure_result_control(review)
	await settle()
	var tap: Vector2 = review.get_global_rect().get_center()
	await result_pointer(tap, true)
	await result_pointer(tap, false)
	check(heard.size() == 1, "A stationary result word tap still plays exactly once after dragging")
	view.hear_requested.disconnect(on_hear)
	Input.emulate_touch_from_mouse = original_touch_hint
	view._results.scroll_vertical = 0
	await settle()


func check_result_actions(view, dimensions: Vector2i, context: String) -> void:
	check(view._results.scroll_vertical == 0, "%s stays at scroll zero at %s" % [context, dimensions])
	var viewport_rect: Rect2 = view._results.get_global_rect()
	check(view.replay_button.is_visible_in_tree() and viewport_rect.grow(1.0).encloses(view.replay_button.get_global_rect()),
		"%s keeps Play again fully visible at %s: viewport=%s button=%s" % [
			context, dimensions, viewport_rect, view.replay_button.get_global_rect()])
	check(view._result_hero.is_visible_in_tree() and viewport_rect.grow(1.0).encloses(view._result_hero.get_global_rect()),
		"%s keeps the HITS celebration fully visible at %s" % [context, dimensions])
	check(view.replay_button.get_global_rect().position.y >= view._result_hero.get_global_rect().end.y - 1.0,
		"Play again sits below the hit celebration without covering it")
	if not view._review_buttons.is_empty():
		check(view.replay_button.get_global_rect().end.y <= view._review_buttons[0].get_global_rect().position.y + 1.0,
			"Play again remains above the word lists")
	check(view.default_focus() == (view.replay_button if view.chests_button.disabled else view.chests_button),
		"Results focus earned chests first, or Play again when no chest was earned")


func check_result_contents(view, summary: Dictionary) -> void:
	check(view._result_hits_caption.text == "HITS" and int(view.snapshot().results_hits.total) == int(summary.hits),
		"The result hero celebrates the actual hit total")
	var labels: PackedStringArray = []
	for label in view._results.find_children("*", "Label", true, false):
		labels.append(str(label.text))
		check(not str(label.text).contains("×"), "Result words have no repetition-count suffix")
	check(not "WORDS" in labels and not "BEST COMBO" in labels and not "SCORE" in labels,
		"Secondary statistics have been removed from results")
	for node_name in ["Pip", "ResultPip", "HearPip", "NextReport", "Back"]:
		check(view._results.find_child(node_name, true, false) == null,
			"Results do not retain the removed " + node_name + " control")
	for button in view._results.find_children("*", "Button", true, false):
		check(button == view.replay_button or button == view.chests_button or str(button.name).begins_with("Hear_")
			or str(button.name) in ["LeaderboardSaveScore", "LeaderboardRetryLoad"],
			"Results offer earned chests, replay, word playback, and persistence recovery")
	var listed_words: Array = summary.hit_words + summary.missed_words
	check(view._review_buttons.size() == listed_words.size(), "Every recorded word remains available in its result list")
	for button in view._review_buttons:
		var word_labels: Array = button.find_children("*", "Label", true, false)
		check(word_labels.size() == 1 and str(word_labels[0].text) == str(button.tooltip_text).trim_prefix("Hear "),
			"A review card shows its word once without a hidden count label")
	if not summary.hit_words.is_empty():
		check(Array(labels).any(func(text: String) -> bool: return text.begins_with("Words you popped")),
			"Successful words retain their group caption")
	if not summary.missed_words.is_empty():
		check(Array(labels).any(func(text: String) -> bool: return text.begins_with("Try these next time")),
			"Missed words retain their practice group caption")


func check_result_word_snapshot_ignores_tooltip(view, word: Dictionary) -> void:
	var button: Button = view._review_buttons[0]
	var before: Dictionary = view.game.summary()
	var original_scroll: int = view._results.scroll_vertical
	var original_size: Vector2 = button.size
	var tooltip := Control.new()
	tooltip.name = "ReviewTooltipFixture"
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.hide()
	var tooltip_label := Label.new()
	tooltip_label.text = "Hear " + str(word.text)
	tooltip.add_child(tooltip_label)
	button.add_child(tooltip)
	view._ensure_result_control(button)
	await settle()
	check(button.find_children("*", "Label", true, false).size() >= 2,
		"The tooltip fixture adds a second descendant label to a real review card")
	check(view._results.get_global_rect().grow(0.5).encloses(button.get_global_rect()),
		"The tooltip regression inspects a review card that is actually visible after scrolling")
	var matching_controls: Array = view.snapshot().controls.filter(
		func(control: Dictionary) -> bool: return control.name == str(button.name))
	check(matching_controls.size() == 1 and matching_controls[0].text == str(word.text),
		"A review snapshot reports the vocabulary word once without appending its hover tooltip")
	tooltip.free()
	view._results.scroll_vertical = original_scroll
	await settle()
	check(button.size.is_equal_approx(original_size) and view.game.summary() == before,
		"Inspecting tooltip descendants preserves the real card layout and earned round")


func check_result_player(view, profile: Dictionary, dimensions: Vector2i) -> void:
	var snapshot: Dictionary = view.snapshot().results_hits
	var player: Dictionary = snapshot.player
	check(player.get("id") == profile.id and player.get("name") == profile.name and player.get("avatar") == profile.avatar,
		"The result preserves the selected player's exact identity at " + str(dimensions))
	if player.is_empty():
		return
	var bounds: Rect2 = view._result_hero.get_global_rect()
	var group := Rect2(Vector2(player.rect[0], player.rect[1]), Vector2(player.rect[2], player.rect[3]))
	var avatar := Rect2(Vector2(player.avatar_rect[0], player.avatar_rect[1]), Vector2(player.avatar_rect[2], player.avatar_rect[3]))
	var name_rect := Rect2(Vector2(player.name_rect[0], player.name_rect[1]), Vector2(player.name_rect[2], player.name_rect[3]))
	var score := Rect2(Vector2(snapshot.rect[0], snapshot.rect[1]), Vector2(snapshot.rect[2], snapshot.rect[3]))
	check(bounds.grow(1).encloses(group) and bounds.grow(1).encloses(score)
		and group.end.x <= score.position.x + 1.0,
		"The avatar/name group stays to the left of the visible hit total at " + str(dimensions))
	check(group.grow(1).encloses(avatar) and group.grow(1).encloses(name_rect)
		and avatar.end.x <= name_rect.position.x + 1.0 and name_rect.size.x > 0.0,
		"The avatar and name share one bounded row without overlap at " + str(dimensions))
	check(view._result_name.text == profile.name and view._result_name.tooltip_text == profile.name
		and view._result_name.clip_text and view._result_name.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
		"Long player names retain their full identity while fitting the allotted space")
	check(view._result_avatar.texture != null
		and view._result_avatar.texture.resource_path == "res://assets/avatars/" + str(profile.avatar) + ".svg",
		"The result displays the chosen player's actual avatar")


func check_result_feedback(view, total: int) -> void:
	var summary: Dictionary = view.game.summary()
	var initial: int = int(view.snapshot().results_hits.text)
	check(initial >= 0 and initial <= total, "The result counter starts inside the earned hit range")
	if not view.reduced_motion:
		check(bool(view.snapshot().results_hits.active), "A fresh result starts its hit celebration")
		view._advance_result_feedback(0.18)
		var advanced: int = int(view.snapshot().results_hits.text)
		check(advanced >= initial and advanced <= total, "The count-up moves toward the earned total without overshooting")
		if total >= 20:
			check(advanced > 0 and advanced < total, "A larger result visibly counts through intermediate values")
	view._advance_result_feedback(PopView.RESULT_HIT_DURATION + 0.1)
	check(str(view.snapshot().results_hits.text) == str(total) and not bool(view.snapshot().results_hits.active)
		and view._result_hits.scale.is_equal_approx(Vector2.ONE),
		"The celebration settles on the exact hit total with a stable readable label")
	view._advance_result_feedback(0.5)
	check(str(view.snapshot().results_hits.text) == str(total) and view.game.summary() == summary,
		"Finishing the celebration neither replays the count-up nor changes earned results")


func check_live_hud(view, dimensions: Vector2i) -> void:
	var time_rect: Rect2 = view.time_label.get_global_rect()
	var hits_rect: Rect2 = view.hits_label.get_global_rect()
	var transcript_rect: Rect2 = view.transcript_label.get_global_rect()
	var field: Rect2 = view.get_global_rect()
	check(time_rect.end.x <= transcript_rect.position.x + 0.01
		and transcript_rect.end.x <= hits_rect.position.x + 0.01,
		"Live speech sits between the timer and hit count at " + str(dimensions))
	check(transcript_rect.position.y < time_rect.end.y and transcript_rect.end.y > time_rect.position.y
		and transcript_rect.position.y < hits_rect.end.y and transcript_rect.end.y > hits_rect.position.y,
		"Timer, live speech and hits share the top HUD row at " + str(dimensions))
	check(field.grow(1.0).encloses(time_rect) and field.grow(1.0).encloses(hits_rect)
		and field.grow(1.0).encloses(transcript_rect), "The complete top row fits at " + str(dimensions))
	check(view.hits_label.get_rect().get_center().x > view.size.x * 0.75
		and view.hits_label.text == str(view.game.hits) and view._hits_caption.text == "HITS",
		"The upper-right field shows the actual hit count at " + str(dimensions))
	var legacy_labels: Array[String] = []
	for label in view._hud.find_children("*", "Label", true, false):
		if label.text in ["SECONDS", "VOICE POP", "SCORE"]:
			legacy_labels.append(label.text)
	check(legacy_labels.is_empty() and view._hud.find_child("Score", true, false) == null,
		"The live field contains no legacy seconds, title or score labels")
	check(view._live_caption.text.is_empty(), "Ordinary listening keeps the top row free of secondary status copy")
	check(view.clip_contents and view._target_canvas.get_parent() == view._hud.get_parent()
		and view._target_canvas.get_index() > view._hud.get_index() and bool(view.snapshot().hud.targets_above_hud),
		"Flying cards paint above the field HUD while remaining clipped to their own view")


func check_high_flight(app, dimensions: Vector2i) -> void:
	var view = app._pop
	var was_reduced: bool = view.reduced_motion
	view.set_reduced_motion(false)
	var original: Dictionary = view.game.targets[0].duplicate(true)
	var launch: Dictionary = view._draw_targets[0].duplicate(true)
	view.game.targets[0].age = float(original.lifetime) * 0.5
	view.game.targets[0].x_start = 0.5
	view.game.targets[0].x_end = 0.5
	view.game.targets[0].peak = 0.18
	view.game.targets[0].spin = 0.0
	view._refresh_targets()
	var apex: Dictionary = view._draw_targets[0]
	var apex_rect: Rect2 = view._global_target_rect(apex)
	check(float(apex.center.y) < float(launch.center.y) and apex.size == launch.size,
		"The higher throw retains the launch card's visible size at " + str(dimensions))
	check(apex_rect.intersects(view.transcript_label.get_global_rect()),
		"A central throw reaches and may cover the field's transcript row at " + str(dimensions))
	check(view.get_global_rect().grow(1.0).encloses(apex_rect),
		"The high apex stays inside the clipped Voice Pop field at " + str(dimensions))
	check(view.get_global_rect().position.y >= app._header.get_global_rect().end.y - 1.0,
		"The flight clipping boundary remains below the compact Pip header at " + str(dimensions))
	view.game.targets[0] = original
	view.set_reduced_motion(was_reduced)


func begin_bonus_round(view, words: Array, reduced: bool = false) -> void:
	view.configure(words, reduced, 71)
	check(view.game.remaining == 50.0 and view.game.remaining == PopModel.DURATION
		and view._gate_note.text.contains("50 seconds"), "A fresh round and its microphone note agree on fifty seconds")
	check(view.snapshot().bonus_time == 0.0 and view.snapshot().combo == 0
		and not view.snapshot().hud.bonus_effect.active and view.snapshot().hud.bonus_effect.serial == 0,
		"A fresh round has no inherited combo reward or popup")
	check(not view._time_bonus_badge.is_visible_in_tree(), "A fresh round does not show an unearned bonus badge")
	view.set_listening(true, false, "Waiting for microphone audio...")
	check(view.game.phase == "ready" and view.game.remaining == 50.0 and view._pending and view.retry_button.disabled,
		"Waiting for actual audio is a transient gate and cannot advance a fresh round")
	view.set_listening(true, true, "Listening.")
	view.set_process(false)
	view._listening_tick_usec = -1


func strike_next_bonus_word(view) -> String:
	if view.game.targets.is_empty():
		view._advance_game(0.66)
	check(not view.game.targets.is_empty(), "The bonus fixture has a real visible word to speak")
	if view.game.targets.is_empty():
		return ""
	var word: String = view.game.targets[0].word.text
	view._listening_tick_usec = -1
	view.receive_transcript(word)
	return word


func check_bonus_feedback(words: Array) -> void:
	var view = PopView.new()
	root.add_child(view)
	view.size = Vector2(320, 420)
	begin_bonus_round(view, words)
	strike_next_bonus_word(view)
	check(view.snapshot().combo == 1 and view.snapshot().bonus_time == 0.0
		and not view.snapshot().hud.bonus_effect.active, "The first hit starts a streak without inventing extra time")
	view._advance_hud_feedback(0.65)
	var second_word: String = strike_next_bonus_word(view)
	var second: Dictionary = view.snapshot()
	check(second.combo == 2 and second.bonus_time == 3.0 and second.hud.time_bonus.text == "+3s"
		and second.hud.bonus_effect.active and second.hud.bonus_effect.amount == 3
		and second.hud.bonus_effect.awards == [3] and second.hud.bonus_effect.serial == 1,
		"Two consecutive real hits award and display three extra seconds")
	check(view.time_label.text == "%02d" % ceili(view.game.remaining), "The countdown immediately includes earned time")
	check(view._bonus_overlay.get_parent() == view._target_canvas.get_parent()
		and view._bonus_overlay.get_index() > view._target_canvas.get_index()
		and view._bonus_overlay.get_index() > view._slice_clip.get_index()
		and second.hud.bonus_effect.above_targets,
		"The earned-time notice paints above both flying words and their slice effects")
	check(view._bonus_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and view._time_bonus_badge.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Foreground time feedback never blocks game input")
	check(view._time_bonus_badge.is_visible_in_tree() and view._time_bonus_caption.is_visible_in_tree()
		and second.hud.time_bonus_caption.text == "TIME BONUS" and second.hud.bonus_effect.duration == 1.8,
		"The earned seconds include an explicit readable caption and a full 1.8-second presentation")
	view._advance_hud_feedback(0.16)
	check(view.time_label.scale.x > 1.0 and view._time_bonus_badge.position != view._time_bonus_anchor,
		"Normal reward feedback pulses the timer and moves its foreground bonus badge")
	view._advance_hud_feedback(0.19)
	for dimensions in [Vector2(180, 180), Vector2(320, 420), Vector2(640, 190), Vector2(1000, 650)]:
		view.size = dimensions
		view._layout()
		var rect: Rect2 = view._time_bonus_label.get_global_rect()
		var text_width: float = view._time_bonus_label.get_theme_font("font").get_string_size("+8s",
			HORIZONTAL_ALIGNMENT_LEFT, -1, view._time_bonus_label.get_theme_font_size("font_size")).x
		check(view.get_global_rect().grow(1.0).encloses(rect) and text_width <= rect.size.x + 0.01,
			"Both individual and combined time rewards remain readable at " + str(dimensions))
		var caption_rect: Rect2 = view._time_bonus_caption.get_global_rect()
		var caption_width: float = view._time_bonus_caption.get_theme_font("font").get_string_size("TIME BONUS",
			HORIZONTAL_ALIGNMENT_LEFT, -1, view._time_bonus_caption.get_theme_font_size("font_size")).x
		check(view.get_global_rect().grow(1.0).encloses(caption_rect) and caption_width <= caption_rect.size.x + 0.01,
			"The time reward caption fits without clipping at " + str(dimensions))
		check(view._time_bonus_label.get_theme_font_size("font_size") * PopView.Style.ui_scale(view) >= 32.0,
			"Earned seconds use a prominent type size at " + str(dimensions))
		check(caption_rect.position.y >= rect.end.y - 1.0,
			"The time reward caption remains distinct from the large earned number at " + str(dimensions))
		check(rect.position.y >= view.time_label.get_rect().end.y + view.global_position.y - 1.0,
			"The reward badge stays below the stable countdown at " + str(dimensions))
	view._listening_tick_usec = -1
	view.receive_transcript(second_word)
	check(view.snapshot().bonus_time == 3.0 and view.snapshot().hud.bonus_effect.serial == 1,
		"A duplicate final hypothesis cannot replay or double the earned time")
	view._advance_hud_feedback(0.65)
	strike_next_bonus_word(view)
	var third: Dictionary = view.snapshot()
	check(third.combo == 3 and third.bonus_time == 8.0 and third.hud.time_bonus.text == "+5s"
		and third.hud.bonus_effect.awards == [5] and third.hud.bonus_effect.serial == 2,
		"A later third hit shows its own five-second reward instead of merging unrelated throws")
	view._advance_hud_feedback(0.65)
	strike_next_bonus_word(view)
	check(view.snapshot().combo == 4 and view.snapshot().bonus_time == 8.0
		and view.snapshot().hud.bonus_effect.serial == 2, "Longer streaks cannot replay either milestone reward")
	view._advance_hud_feedback(PopView.HUD_BONUS_DURATION)
	check(not view.snapshot().hud.bonus_effect.active and view.snapshot().hud.time_bonus.text.is_empty()
		and not view._time_bonus_badge.is_visible_in_tree() and view.time_label.scale.is_equal_approx(Vector2.ONE),
		"The bonus popup expires, hides its entire foreground badge and restores a stable countdown")
	view._advance_game(7.0)
	check(view.snapshot().combo == 0, "An actual missed target resets the streak")
	strike_next_bonus_word(view)
	view._advance_hud_feedback(0.65)
	strike_next_bonus_word(view)
	check(view.snapshot().bonus_time == 11.0 and view.snapshot().hud.time_bonus.text == "+3s",
		"A new streak after a miss can earn its own second-hit reward")
	view.pause()
	check(not view.snapshot().hud.bonus_effect.active and not view._time_bonus_label.visible
		and view.time_label.scale.is_equal_approx(Vector2.ONE) and view.snapshot().bonus_time == 11.0,
		"Explicit pause clears cosmetic feedback while retaining earned seconds")
	view.set_listening(true, true, "Listening.")
	strike_next_bonus_word(view)
	var before_rollover: Dictionary = view.snapshot().hud.bonus_effect
	view.set_listening(true, false, "Listening paused. Continuing...")
	check(view.snapshot().hud.bonus_effect == before_rollover and view.snapshot().hud.time_bonus.text == "+5s",
		"A transient browser utterance rollover does not erase an earned timer reward")
	view.set_listening(true, false, "Waiting for microphone audio...")
	check(view._reconnecting and view.retry_button.disabled and view.snapshot().hud.bonus_effect == before_rollover,
		"Capture startup during reconnection remains transient and preserves the earned bonus")
	view.set_listening(true, true, "Listening.")
	view.set_reduced_motion(true)
	var static_position: Vector2 = view._time_bonus_badge.position
	view._advance_hud_feedback(0.4)
	check(view.snapshot().hud.bonus_effect.reduced_motion and view.time_label.scale.is_equal_approx(Vector2.ONE)
		and view._time_bonus_badge.position == static_position and view._time_bonus_badge.scale.is_equal_approx(Vector2.ONE)
		and view._time_bonus_badge.modulate.a == 1.0 and view._time_bonus_caption.is_visible_in_tree(),
		"Reduced motion keeps the earned label steady and fully readable without pulsing or drifting")
	view.set_listening(true, false, "Speech network error. Tap Retry.")
	check(not view.snapshot().hud.bonus_effect.active and view.snapshot().hud.time_bonus.text.is_empty(),
		"A real listening failure clears the temporary timer reward")
	view.set_listening(true, true, "Listening.")
	view._advance_game(view.game.remaining + 1.0)
	check(view.game.phase == "finished" and not view.snapshot().hud.bonus_effect.active,
		"Completing an extended round leaves no live timer reward behind")
	begin_bonus_round(view, words)
	check(view.game._spawn_target(5.6) and view.game._spawn_target(5.6), "The multiword fixture has three distinct real targets")
	var phrase := PackedStringArray()
	for target in view.game.targets:
		phrase.append(target.word.text)
	view._listening_tick_usec = -1
	view.receive_transcript(" ".join(phrase))
	var combined: Dictionary = view.snapshot()
	check(combined.hits == 3 and combined.bonus_time == 8.0 and combined.hud.time_bonus.text == "+8s"
		and combined.hud.bonus_effect.awards == [3, 5] and combined.hud.bonus_effect.serial == 1,
		"One three-word result combines both milestones into an accurate eight-second reward")
	view._advance_hud_feedback(1.3)
	check(view.snapshot().hud.bonus_effect.active and view._time_bonus_badge.is_visible_in_tree()
		and view._time_bonus_badge.modulate.a > 0.9 and view._time_bonus_label.text == "+8s",
		"The bonus remains fully readable for at least 1.3 seconds before returning to the timer")
	view._advance_hud_feedback(PopView.HUD_BONUS_DURATION - 1.3 - 0.01)
	check(view.snapshot().hud.bonus_effect.active, "The bonus stays active through its defined exit animation")
	view._advance_hud_feedback(0.02)
	check(not view.snapshot().hud.bonus_effect.active and not view._time_bonus_badge.is_visible_in_tree(),
		"Crossing the presentation duration removes the foreground reward exactly once")
	begin_bonus_round(view, words)
	check(view.game._spawn_target(5.6) and view.game._spawn_target(5.6), "Separate lexical callbacks share one three-target fixture")
	strike_next_bonus_word(view)
	strike_next_bonus_word(view)
	view._advance_hud_feedback(0.05)
	strike_next_bonus_word(view)
	check(view.snapshot().hud.time_bonus.text == "+8s" and view.snapshot().hud.bonus_effect.awards == [3, 5]
		and view.snapshot().hud.bonus_effect.serial == 2 and view.snapshot().bonus_time == 8.0,
		"Lexical callbacks arriving within one short frame merge their reward text without losing either award")
	view.hide()
	check(not view.snapshot().hud.bonus_effect.active and not view._time_bonus_label.visible,
		"Hiding the game discards the active timer effect")
	view.show()
	view.stop()
	check(not view.snapshot().hud.bonus_effect.active and view.time_label.scale.is_equal_approx(Vector2.ONE),
		"Leaving Voice Pop cannot carry a reward animation into another mode")
	view.free()


func check_homophone_feedback(words: Array) -> void:
	var view = PopView.new()
	root.add_child(view)
	view.size = Vector2(640, 480)
	var accepted: Array[String] = []
	view.hit.connect(func(word: Dictionary) -> void: accepted.append(word.id))
	for fixture in [["bee", "be"], ["eye", "I"], ["nose", "knows"], ["deer", "dear"], ["cymbal", "symbol"]]:
		accepted.clear()
		begin_bonus_round(view, words.filter(func(word: Dictionary) -> bool: return word.id == fixture[0]))
		check(view.snapshot().targets[0].forms.has(str(fixture[1]).to_lower()),
			"The browser receives the same homophone used for scoring: " + fixture[1])
		var transcript: String = "The " + fixture[1] + "!"
		view.show_transcript(transcript, true)
		view.receive_transcript(fixture[1])
		check(accepted == [fixture[0]] and view.game.hits == 1 and view.game.hit_words[0].id == fixture[0],
			"The homophone emits a single canonical hit for effects, scoring and review")
		check(view.snapshot().transcript == transcript and view._hud_transcript_hit
			and view.snapshot().hud.hit_effect.active and view.snapshot().hud.hit_effect.words == [fixture[0]],
			"A homophone keeps the raw caption and highlights the hit with the canonical word")
		view.receive_transcript(fixture[0])
		check(view.game.hits == 1 and accepted.size() == 1,
			"Repeating the canonical spelling cannot hit the removed target again")
	for fixture in [["seahorse", "sea horse"], ["sunflower", "sun-flowers"], ["sunglasses", "sun glasses"],
		["pinecone", "pine cones"], ["yoyo", "yo-yo"]]:
		accepted.clear()
		begin_bonus_round(view, words.filter(func(word: Dictionary) -> bool: return word.id == fixture[0]))
		view.show_transcript(fixture[1], true)
		view.receive_transcript(fixture[1])
		check(accepted == [fixture[0]] and view._hud_transcript_hit and view.snapshot().transcript == fixture[1],
			"A compound preserves its raw caption while celebrating the canonical hit: " + fixture[1])
	view.free()


func bound_scene_event(view, id: String) -> Dictionary:
	var target: Dictionary = view.game.targets[0]
	return {"event_id": id, "round_id": view.snapshot().round_id, "target_uid": target.uid,
		"text": target.word.text, "stage": "interim", "received_at_ms": 100.0}


func check_bound_speech_events(words: Array) -> void:
	var view = PopView.new()
	root.add_child(view)
	view.size = Vector2(640, 480)
	var pool: Array = words.filter(func(word: Dictionary) -> bool: return word.id == "cat")
	var accepted: Array[String] = []
	view.hit.connect(func(word: Dictionary) -> void: accepted.append(word.id))
	view.configure(pool, false, 71)
	var prepared_id: String = view.snapshot().round_id
	view.set_listening(true, true, "Listening.")
	view.set_process(false)
	view._listening_tick_usec = -1
	check(not prepared_id.is_empty() and view.snapshot().round_id == prepared_id,
		"The browser sees one round identity from preparation through actual listening")
	var event: Dictionary = bound_scene_event(view, "scene-occurrence")
	view.show_transcript("The cat!", false)
	check(not view.receive_speech_event("[]") and view.game.hits == 0,
		"Non-object event JSON cannot enter native scoring")
	check(view.receive_speech_event(JSON.stringify(event)) and accepted == ["cat"] and view.game.hits == 1,
		"The bridge acknowledges one bound hit and emits its canonical gameplay reaction")
	check(view.snapshot().transcript == "The cat!" and view.snapshot().hud.hit_effect.active,
		"Bound scoring preserves the raw transcript and existing hit celebration")
	var effect_serial: int = view.snapshot().hud.hit_effect.serial
	check(not view.receive_speech_event(JSON.stringify(event)) and accepted.size() == 1
		and view.snapshot().hud.hit_effect.serial == effect_serial,
		"An event replay returns false without duplicating feedback or reactions")
	view._advance_game(0.66)
	view._listening_tick_usec = -1
	var replacement: Dictionary = bound_scene_event(view, event.event_id)
	check(not view.receive_speech_event(JSON.stringify(replacement)) and view.game.hits == 1,
		"A replay cannot bind a consumed occurrence to the next visible copy")
	replacement.event_id = "scene-second-occurrence"
	check(view.receive_speech_event(JSON.stringify(replacement)) and view.game.hits == 2
		and view.snapshot().hud.bonus_effect.amount == 3,
		"A distinct repeated occurrence scores and presents its normal time reward")

	begin_bonus_round(view, pool)
	check(view.snapshot().round_id != prepared_id and not view.receive_speech_event(JSON.stringify(event))
		and view.game.hits == 0, "Starting over rejects callbacks from the previous published round")
	event = bound_scene_event(view, "scene-paused")
	var current_id: String = view.snapshot().round_id
	view.pause()
	check(not view.receive_speech_event(JSON.stringify(event)) and view.game.hits == 0,
		"A paused view returns false without consuming a speech event")
	view.set_listening(true, true, "Listening.")
	view._listening_tick_usec = -1
	check(view.snapshot().round_id == current_id and view.receive_speech_event(JSON.stringify(event)),
		"Resuming preserves the speech round and its unconsumed target")

	begin_bonus_round(view, pool)
	event = bound_scene_event(view, "scene-expired")
	view.game.targets[0].age = float(view.game.targets[0].lifetime) - 0.01
	view._listening_tick_usec = maxi(0, Time.get_ticks_usec() - 100000)
	check(not view.receive_speech_event(JSON.stringify(event)) and view.game.hits == 0 and view.game.misses == 1,
		"Event receipt catches the clock up before checking the bound target's flight deadline")

	begin_bonus_round(view, pool)
	event = bound_scene_event(view, "scene-round-deadline")
	view.game.elapsed = PopModel.DURATION - 0.01
	view.game.remaining = 0.01
	view.game._next_spawn_at = INF
	view.game.targets[0].lifetime = 0.01
	view._listening_tick_usec = maxi(0, Time.get_ticks_usec() - 100000)
	check(not view.receive_speech_event(JSON.stringify(event)) and view.game.phase == "finished"
		and view.game.hits == 0 and view._finished_sent,
		"A callback after the round deadline cannot delay or alter settlement")
	view.free()


func check_independent_card_flight(words: Array) -> void:
	var view = PopView.new()
	root.add_child(view)
	view.size = Vector2(640, 480)
	for reduced in [false, true]:
		begin_bonus_round(view, words, reduced)
		check(view.game._spawn_target(5.6), "The overlap fixture has two distinct scoreable words")
		var first: Dictionary = view.game.targets[0].duplicate(true)
		var second: Dictionary = view.game.targets[1].duplicate(true)
		for target in [first, second]:
			target.lifetime = 5.6
			target.age = 2.0
			target.x_start = 0.30
			target.x_end = 0.60
			target.peak = 0.25
			target.spin = 0.0
			target.lane = 0
		view.game.targets.assign([first])
		view._refresh_targets()
		var original: Dictionary = view._draw_targets[0].duplicate(true)
		var room: float = view._arena.size.x - float(original.size.x) - 12.0 / PopView.Style.ui_scale(view)
		for separation in [0.30, 0.0]:
			second.x_start = first.x_start + float(original.size.x) * separation / room * 0.60
			second.x_end = first.x_end + float(original.size.x) * separation / room * 0.60
			view.game.targets.assign([second])
			view._refresh_targets()
			var second_alone: Dictionary = view._draw_targets[0].duplicate(true)
			view.game.targets.assign([first, second])
			view._refresh_targets()
			check(view._draw_targets[0].center.is_equal_approx(original.center)
				and view._draw_targets[1].center.is_equal_approx(second_alone.center),
				"Overlapping and coincident cards retain their independent positions (reduced=%s separation=%s)" % [reduced, separation])
			check(view._draw_targets[0].size == original.size and view._draw_targets[1].size == original.size
				and view._global_target_rect(view._draw_targets[0]).intersects(view._global_target_rect(view._draw_targets[1])),
				"Cards pass through one another without shrinking their illustrations")
		view.receive_transcript(first.word.text)
		check(view.game.hits == 1 and view.game.targets.size() == 1
			and int(view.game.targets[0].uid) == int(second.uid) and view._draw_targets[0].size == original.size,
			"An overlapping word still scores independently and leaves its neighbor at full size")
		view._listening_tick_usec = -1
		view.receive_transcript(second.word.text)
		check(view.game.hits == 2 and view.game.targets.is_empty(),
			"Both coincident words remain separately scoreable by speech")
	view.free()


func check_portrait_volley_flight(words: Array) -> void:
	var view = PopView.new()
	root.add_child(view)
	view.size = Vector2(360, 560)
	begin_bonus_round(view, words)
	var original: Dictionary = view.game.targets[0].duplicate(true)
	var volley: Array[Dictionary] = []
	for lane in range(3):
		var target: Dictionary = original.duplicate(true)
		target.uid = int(original.uid) + lane
		target.lane = lane
		target.volley = true
		target.x_start = 0.23 + float(lane) * 0.27
		target.x_end = target.x_start
		target.peak = 0.30
		target.spin = -0.12 if lane == 0 else 0.12
		volley.append(target)
	for progress in [0.25, 0.5, 0.75]:
		for target in volley:
			target.age = float(target.lifetime) * progress
		view.game.targets.assign(volley)
		view._refresh_targets()
		var middle: Dictionary = view._draw_targets[1].duplicate(true)
		var middle_rect: Rect2 = view._global_target_rect(middle)
		check(not middle_rect.intersects(view._global_target_rect(view._draw_targets[0]))
			and not middle_rect.intersects(view._global_target_rect(view._draw_targets[2])),
			"The lower center volley keeps all three portrait word cards readable at " + str(progress))
		view.game.targets.assign([volley[1]])
		view._refresh_targets()
		check(view._draw_targets[0].center.is_equal_approx(middle.center)
			and view._draw_targets[0].size == middle.size,
			"A surviving volley word retains its trajectory and visual size after neighboring hits")
	view.free()


func check_volley_launches(words: Array) -> void:
	var view = PopView.new()
	root.add_child(view)
	view.size = Vector2(640, 480)
	var launches: Array[int] = []
	view.launched.connect(func(uid: int) -> void: launches.append(uid))
	begin_bonus_round(view, words)
	var latest_uid: int = int(view.game.targets[0].uid)
	var found_volley: bool = false
	for frame in range(480):
		var previous_launches: int = launches.size()
		view._advance_game(0.05)
		var fresh: Array[Dictionary] = []
		for target in view.snapshot().targets:
			if int(target.uid) > latest_uid:
				fresh.append(target)
			latest_uid = maxi(latest_uid, int(target.uid))
		if fresh.size() < 2:
			continue
		found_volley = true
		check(fresh.size() <= 3 and launches.size() == previous_launches + 1,
			"A naturally scheduled two- or three-word volley emits one launch sound")
		var shared_launch: bool = true
		for target in fresh:
			shared_launch = shared_launch and absf(float(target.spawned_at) - float(fresh[0].spawned_at)) < 0.0001 \
				and float(target.age) <= 0.051
		check(shared_launch, "Browser snapshots expose the shared launch time and fresh target ages")
		view._emit_launches()
		view._refresh_targets()
		view._emit_launches()
		check(launches.size() == previous_launches + 1, "Repeated refreshes cannot replay a volley's whoosh")
		break
	check(found_volley, "The deterministic scene reaches an occasional natural multiword volley")
	view.free()


func check_frame_presentation(words: Array) -> void:
	var view = FrameCountView.new()
	root.add_child(view)
	view.size = Vector2(640, 480)
	begin_bonus_round(view, words)
	view.game._next_spawn_at = INF
	var reports: Array[Dictionary] = []
	view.status_changed.connect(func(report: Dictionary) -> void: reports.append(report))
	var before: Vector2 = view._draw_targets[0].center
	view._publish_key = ""
	view._listening_tick_usec = maxi(0, Time.get_ticks_usec() - 16000)
	view.reset_counts()
	view._process(1.0 / 60.0)
	check(view.geometry_updates == 1 and view.hud_updates == 1 and view.feedback_updates == 1,
		"A running frame presents targets and HUD once, including its published geometry")
	check(not view._draw_targets[0].center.is_equal_approx(before)
		and is_equal_approx(float(view._draw_targets[0].age), float(view.game.targets[0].age))
		and reports.size() == 1 and is_equal_approx(float(reports[0].targets[0].age), float(view.game.targets[0].age)),
		"The single presentation pass moves the card and publishes the current model age")
	view.reset_counts()
	before = view._draw_targets[0].center
	view._advance_game(0.125)
	check(view.geometry_updates == 1 and view.hud_updates == 1 and view.feedback_updates == 1
		and not view._draw_targets[0].center.is_equal_approx(before)
		and view.time_label.text == "%02d" % ceili(view.game.remaining),
		"A direct simulation tick still updates visual geometry and counters immediately")
	view._hud_hit_age = PopView.HUD_HIT_DURATION - 0.01
	view._hud_bonus_age = PopView.HUD_BONUS_DURATION - 0.01
	view._chest_fx_age = PopView.CHEST_FX_DURATION - 0.01
	view._apply_hud_feedback()
	reports.clear()
	view._listening_tick_usec = -1
	view.reset_counts()
	view._process(0.02)
	check(view.geometry_updates == 1 and view.hud_updates == 1 and view.feedback_updates == 1,
		"Expiring simultaneous hit, time and chest effects still presents one frame")
	check(reports.size() == 1 and not reports[0].hud.hit_effect.active
		and not reports[0].hud.bonus_effect.active and not reports[0].chest_fx.active
		and not view._time_bonus_badge.visible and not view._chest_badge.visible,
		"Feedback expiry publishes and clears all three effects even when score and target IDs are unchanged")
	view.game.remaining = 4.5
	view._update_hud()
	check(view.time_label.get_theme_color("font_color") == PopView.PINK,
		"The cached HUD palette enters the low-time warning")
	view._hud_bonus_age = 0.0
	view._apply_hud_feedback()
	check(view.time_label.get_theme_color("font_color") == PopView.BONUS_COLOR,
		"An earned bonus immediately overrides the cached low-time palette")
	view._advance_hud_feedback(PopView.HUD_BONUS_DURATION)
	check(view.time_label.get_theme_color("font_color") == PopView.PINK
		and view.time_label.scale == Vector2.ONE,
		"Direct feedback ticks restore the warning color and resting scale after the bonus")
	view.free()


func check_draw_caches() -> void:
	var view = PopView.new()
	view._ensure_draw_styles(1.0)
	var first: StyleBoxFlat = view._card_face_styles[0]
	var shadow: StyleBoxFlat = view._card_shadow_style
	view._ensure_draw_styles(1.0)
	check(view._card_face_styles[0] == first and view._card_shadow_style == shadow,
		"Static card resources survive repeated draws at the same scale")
	check(view._card_face_styles.size() == PopView.CARD_COLORS.size()
		and view._card_glow_styles.size() == PopView.CARD_COLORS.size(),
		"The style cache has one fixed entry per illustrated card palette")
	view._ensure_draw_styles(2.0)
	check(view._card_face_styles[0] != first and view._card_face_styles[0].corner_radius_top_left == 10
		and view._card_face_styles[0].bg_color == first.bg_color,
		"A changed UI scale replaces the radii without altering artwork colors")
	var fit: Dictionary = view._fit_word("strawberry", Vector2(202, 162), 1.0)
	var repeated: Dictionary = view._fit_word("strawberry", Vector2(202, 162), 1.0)
	check(is_same(fit, repeated), "Unchanged word and card geometry reuse the text fit")
	var smaller: Dictionary = view._fit_word("strawberry", Vector2(112, 96), 1.0)
	check(not is_same(fit, smaller) and int(smaller.font_size) < int(fit.font_size)
		and float(smaller.width) <= 96.0,
		"A narrower card refits the same word without clipped text")
	var scaled: Dictionary = view._fit_word("strawberry", Vector2(56, 48), 2.0)
	check(not is_same(smaller, scaled) and float(scaled.width) <= 48.0,
		"A changed UI scale refits the illustrated card word")
	check(view._word_fits.size() == 1,
		"Resizing and older slices replace a word's fit instead of accumulating cache entries")
	view.free()


func _run() -> void:
	var directory: String = "user://voice-pop-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.size = Vector2i(390, 844)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	check(app._mode_id == "match" and not app._pop.is_visible_in_tree(), "Startup preserves Match without activating speech")
	check(app.find_child("VoiceProfiles", true, false) == null, "More has no voice-user enrollment entry")
	check(not app.collection_button.tooltip_text.contains("voice users"), "More describes only the available room settings")
	var modes: Array[String] = ["match", "memory", "pop"]
	var saw_scrollable_results: bool = false
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(679, 900), Vector2i(680, 900), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		var original_positions: Array[Vector2] = []
		for mode in modes:
			app.choose_mode(mode)
			if mode == "pop":
				preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
			await settle()
			var current_positions: Array[Vector2] = []
			current_positions.append(app._header.global_position)
			check(app._mode_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()),
				"Mode choices stay hidden until Pip is opened at %s in %s" % [dimensions, mode])
			if original_positions.is_empty():
				original_positions = current_positions
			else:
				check(current_positions == original_positions, "The compact Pip header stays in the same position at %s in %s" % [dimensions, mode])
		var view = app._pop
		view.set_process(false)
		check(view.find_child("ChoosePopMode", true, false) == null and view.find_child("MultiplayerStatus", true, false) == null,
			"Voice Pop uses browser listening without the removed multiplayer selector")
		check(view.is_visible_in_tree() and not app.grid.is_visible_in_tree() and not app._memory.visible,
			"Voice Pop owns the visible playfield at " + str(dimensions))
		check(not app.hint_button.visible and not app._voice_button.visible and not app._memory.study_button.visible,
			"Other modes' actions do not intrude into Voice Pop")
		check(view.game.phase == "ready" and view.game.remaining == PopModel.DURATION, "Waiting for microphone does not consume time")
		view.show_transcript("This arrived before listening", false)
		check(not view.transcript_label.is_visible_in_tree() and str(view.snapshot().transcript).is_empty(),
			"Permission waiting cannot display a transcript from an inactive recognizer")
		view._process(2.0)
		check(view.game.remaining == PopModel.DURATION and view.game.targets.is_empty(), "Permission waiting never starts target motion")
		app._on_voice_state([true, true, "Listening. Say an English word."])
		check(view.game.phase == "running" and view.game.targets.size() == 1, "A live microphone starts the actual arcade round")
		view.show_transcript("I am still thinking", false)
		check(view.transcript_label.is_visible_in_tree() and view.transcript_label.text.contains("I am still thinking"),
			"The HUD displays a whole unmatched interim sentence at " + str(dimensions))
		check(view.game.hits == 0 and not bool(view.snapshot().transcript_final), "Displaying an interim sentence does not award a hit")
		check(view.get_global_rect().grow(1).encloses(view.transcript_label.get_global_rect()),
			"The live transcript fits inside the playfield at " + str(dimensions))
		check_live_hud(view, dimensions)
		check_high_flight(app, dimensions)
		view._advance_game(1.5)
		var before_catchup: float = view.game.remaining
		var catchup_started: int = Time.get_ticks_usec()
		var missed_frame_usec: int = mini(250000, catchup_started / 2)
		view._listening_tick_usec = catchup_started - missed_frame_usec
		view._process(0.000001)
		var caught_up: float = before_catchup - view.game.remaining
		var catchup_limit: float = float(Time.get_ticks_usec() - catchup_started + missed_frame_usec) / 1000000.0
		check(caught_up >= float(missed_frame_usec) / 1000000.0 - 0.00001 and caught_up <= catchup_limit + 0.00001,
			"A tiny engine delta still consumes the full monotonic interval after a missed frame")
		check(caught_up > 0.000001 and view._listening_tick_usec >= catchup_started,
			"Low frame rates cannot stretch the round by repeatedly consuming clamped engine deltas")
		var before: int = view.game.hits
		var word: Dictionary = view.game.targets[0].word.duplicate(true)
		var sentence: String = "I think it is a " + str(word.text)
		view.show_transcript(sentence, false)
		check(view.transcript_label.text.contains(sentence) and str(view.snapshot().transcript) == sentence and view.game.hits == before,
			"A complete hypothesis remains visible independently of target scoring")
		view.receive_transcript(word.text)
		check(view.game.hits == before + 1 and view.game.hit_words[0].id == word.id, "A spoken visible word produces an exact hit")
		check(view.hits_label.text == str(before + 1) and view.hits_label.text != str(view.game.score),
			"A spoken hit updates the upper-right count rather than displaying combo points")
		check(view.game.targets.all(func(target: Dictionary) -> bool: return target.word.id != word.id), "A popped target is removed immediately")
		check(view.transcript_label.text.contains(sentence), "Hit feedback does not replace the full sentence with the popped noun")
		var success_caption: String = view._live_caption.text
		view.receive_transcript("please")
		check(view.snapshot().recognition_feedback.is_empty() and view._live_caption.text == success_caption
			and bool(view.snapshot().hud.hit_effect.active), "A trailing solo filler cannot erase the current hit celebration")
		var revised: String = "I think it is the " + str(word.text) + ", please"
		view.show_transcript(revised, false)
		check(view.transcript_label.text.contains(revised) and not bool(view.snapshot().transcript_final), "Interim revisions replace the displayed hypothesis immediately")
		view.show_transcript(revised, true)
		check(view.transcript_label.text.contains(revised) and bool(view.snapshot().transcript_final) and view.game.hits == before + 1,
			"A final hypothesis updates the HUD state without scoring the noun a second time")
		var long_sentence: String = "I am trying to speak clearly and I would like you to hear the whole sentence before I finish"
		view.show_transcript(long_sentence, false)
		check(view.transcript_label.text.contains(long_sentence) and str(view.snapshot().transcript) == long_sentence,
			"Long hypotheses retain every recognized word instead of keeping only a matched noun")
		var transcript_lines: int = view.transcript_label.get_line_count()
		check(view.transcript_label.get_visible_line_count() == mini(2, transcript_lines)
			and view.transcript_label.lines_skipped == maxi(0, transcript_lines - 2),
			"The live HUD shows the latest two full lines, or the whole shorter sentence: viewport=%s total=%d visible=%d skipped=%d" % [
				dimensions, transcript_lines, view.transcript_label.get_visible_line_count(), view.transcript_label.lines_skipped])
		check(view.get_global_rect().grow(1).encloses(view.transcript_label.get_global_rect()),
			"A long live sentence stays inside the HUD at " + str(dimensions))
		view.show_transcript("earlier words ".repeat(170) + "newest cat", false)
		check(view.transcript_label.text.length() <= 2000 and view.transcript_label.text.ends_with("newest cat")
			and str(view.snapshot().transcript).ends_with("newest cat"),
			"The bounded speech buffer retains new words after a very long hypothesis")
		view._process(1.16)
		view.receive_transcript("please")
		check(view.snapshot().recognition_feedback == "no_matching_target" and view._live_caption.text == view.snapshot().recognition_message,
			"An unrelated solo answer after the celebration window gets useful feedback")
		view.receive_transcript("")
		check(view.snapshot().recognition_feedback == "unclear_speech", "An empty final browser result shows a retry message")
		view.show_transcript("A new raw hypothesis", false)
		check(view._live_caption.text == view.snapshot().recognition_message,
			"Raw hypotheses do not overwrite a specific recognition reason with generic encouragement")
		app._on_voice_state([true, false, "Speech network error. Tap Retry."])
		check(not view.transcript_label.is_visible_in_tree() and str(view.snapshot().transcript).is_empty(), "Pausing clears the live transcript")
		check(view.snapshot().recognition_feedback.is_empty() and view.snapshot().recognition_message.is_empty(),
			"Background or listening pauses clear stale recognition feedback")
		view.show_transcript("This is a stale paused hypothesis", false)
		check(str(view.snapshot().transcript).is_empty(), "A late hypothesis cannot repopulate the paused HUD")
		var remaining: float = view.game.remaining
		check(view._listening_tick_usec == -1, "Speech failure clears the active listening clock baseline")
		view._listening_tick_usec = 0
		view._process(3.0)
		check(view.game.phase == "paused" and view.game.remaining == remaining, "Speech failure pauses both targets and the clock")
		view._listening_tick_usec = 0
		var resumed_at: int = Time.get_ticks_usec()
		app._on_voice_state([true, true, "Listening."])
		check(view.game.phase == "running" and view.game.remaining == remaining and view.game.hits == before + 1,
			"Speech recovery resumes the same round")
		check(view._listening_tick_usec >= resumed_at, "Resuming replaces the stale baseline from before the pause")
		view._process(0.000001)
		var resume_limit: float = float(Time.get_ticks_usec() - resumed_at) / 1000000.0
		check(remaining - view.game.remaining >= 0.0 and remaining - view.game.remaining <= resume_limit + 0.00001,
			"The first resumed frame excludes all time spent paused")
		app._show_collection()
		check(view.game.phase == "paused", "More pauses Voice Pop")
		remaining = view.game.remaining
		app._hide_collection()
		check(view.game.phase == "paused" and view.game.remaining == remaining, "Returning from More waits for an explicit Resume without consuming time")
		app._on_voice_state([true, true, "Listening."])
		app.on_page_hidden()
		remaining = view.game.remaining
		check(view._listening_tick_usec == -1, "Hiding the page clears the active listening clock baseline")
		view._listening_tick_usec = 0
		view._process(3.0)
		check(view.game.phase == "paused" and view.game.remaining == remaining, "Hidden pages preserve the remaining round")
		app.on_page_visible()
		app._on_voice_state([true, true, "Listening."])
		view._advance_game(view.game.remaining + 1.0)
		preload("res://tests/godot/player_flow_fixture.gd").finish_celebration(app)
		await settle()
		check(view.game.phase == "finished" and view.game.remaining == 0.0, "The view reaches results at its earned deadline")
		var result: Dictionary = view.game.summary()
		check(result.hits == before + 1 and result.hit_words.size() == 1 and result.best_combo >= 1,
			"The result preserves the real spoken hits")
		check(Rect2(Vector2.ZERO, app.size).grow(1).encloses(view.get_global_rect()), "The result view fits at " + str(dimensions))
		var snapshot: Dictionary = view.snapshot()
		check(snapshot.phase == "finished", "Accessible state reflects the visible results")
		check(view.find_child("PlayerLeaderboard", true, false) == null and not snapshot.has("ranking")
			and not snapshot.has("players"), "Results show individual progress without player rankings")
		check(str(snapshot.transcript).is_empty() and not view.transcript_label.is_visible_in_tree(), "Results clear the completed round's transcript")
		view.show_transcript("This is a stale finished hypothesis", true)
		check(str(view.snapshot().transcript).is_empty(), "Late hypotheses cannot revive a completed round's transcript")
		check_result_contents(view, result)
		check_result_actions(view, dimensions, "Completed round")
		check_result_feedback(view, int(result.hits))
		check_result_player(view, app.leaderboard_state.profiles[0], dimensions)
		await check_result_word_snapshot_ignores_tooltip(view, result.hit_words[0])
		check(not app.audio.voice.playing,
			"Finishing Voice Pop does not request or play a removed Pip report")
		var heard: Array[Dictionary] = []
		var on_hear: Callable = func(item: Dictionary) -> void: heard.append(item)
		view.hear_requested.connect(on_hear)
		view._review_buttons[0].pressed.emit()
		check(heard.size() == 1 and heard[0].id == word.id,
			"The successful word remains individually playable from its result card")
		view.hear_requested.disconnect(on_hear)
		check(view.game.summary() == result, "Reviewing an individual word leaves the earned result unchanged")
		await settle()
		check(not bool(view.snapshot().results_scrollbar_visible) and not view._results.get_v_scroll_bar().is_visible_in_tree(),
			"Results never paint a scrollbar at " + str(dimensions))
		if float(view.snapshot().results_scroll_max) > 1.0:
			saw_scrollable_results = true
			if dimensions == Vector2i(320, 568):
				await check_result_touch_scroll(view)
				await check_result_input_cancellation(app)
			view._results.scroll_vertical = mini(100, int(view.snapshot().results_scroll_max))
			await settle()
			check(view._results.scroll_vertical > 0 and float(view.snapshot().results_scroll) > 0,
				"Hiding the result scrollbar preserves actual scrolling")
			var last_review: Control = view._review_buttons.back()
			last_review.grab_focus()
			await settle()
			check(view._results.get_global_rect().grow(1).encloses(last_review.get_global_rect()),
				"Keyboard focus reveals the final review word without a visible scrollbar: viewport=%s scroll_rect=%s button=%s button_rect=%s scroll=%s scroll_max=%s scroll_page=%s focus=%s" % [
					dimensions, view._results.get_global_rect(), last_review.name, last_review.get_global_rect(),
					view._results.scroll_vertical, view._results.get_v_scroll_bar().max_value,
					view._results.get_v_scroll_bar().page, root.gui_get_focus_owner()])
			view._results.scroll_vertical = 0
			await settle()
		view.replay_button.pressed.emit()
		preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
		check(view.game.phase == "ready" and view.game.hits == 0 and view.game.remaining == PopModel.DURATION,
			"Play again returns to a fresh round that waits for microphone permission")
		check(not view._results.visible and not bool(view.snapshot().results_hits.active),
			"Replaying hides results and clears the previous hit celebration")
		app.choose_mode("match")
		check(not view.is_visible_in_tree() and view.snapshot().phase == "idle"
			and not bool(view.snapshot().results_hits.active),
			"Leaving Voice Pop retains no active result celebration")
		view.set_process(true)
	check(saw_scrollable_results, "Compact result layouts exercise scrolling with the scrollbar hidden")
	app.playroom_state.age_band_id = "4-6"
	app.choose_mode("pop")
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	check(app._pop.game._words.all(func(word: Dictionary) -> bool: return app.Data.word_level(word) == 1),
		"Voice Pop uses only the selected age group's vocabulary")
	app._pop.set_process(false)
	app._on_voice_state([true, true, "Listening."])
	app._pop._advance_game(app._pop.game.remaining + 1.0)
	await settle()
	var empty_round: Dictionary = app._pop.game.summary()
	check(empty_round.hits == 0 and empty_round.score == 0 and empty_round.hit_words.is_empty(),
		"The no-hit fixture completes an actual round without invented results")
	check_result_contents(app._pop, empty_round)
	app._pop._advance_result_feedback(PopView.RESULT_HIT_DURATION + 0.1)
	check(str(app._pop.snapshot().results_hits.text) == "0" and not empty_round.missed_words.is_empty(),
		"A no-hit round shows zero and keeps its missed words available for practice")
	for dimensions in [Vector2i(320, 568), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		check_result_actions(app._pop, dimensions, "Zero-hit round")
	check(app._pop.game.summary() == empty_round, "Zero-hit presentation preserves the actual round result")
	var long_words: Array = app.data.words.duplicate(true)
	long_words.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.text).length() > str(b.text).length())
	var long_profile: Dictionary = {"id": "long-name-layout-player", "name": "WWWWWWWWWWWWWWWWWWWW", "avatar": "unicorn"}
	var assigned_profile: Dictionary = long_profile.duplicate(true)
	app._pop.set_round_player(assigned_profile)
	assigned_profile.name = "Changed outside the round"
	var layout_viewport_size: Vector2i = root.size
	for count in [20, 21, 123]:
		var long_result: Dictionary = empty_round.duplicate(true)
		long_result.hits = count
		long_result.best_combo = count
		long_result.score = 200
		long_result.hit_words = long_words.slice(0, 2).duplicate(true)
		long_result.missed_words = long_words.slice(2, 3).duplicate(true)
		long_result.hit_words[0].count = 8
		long_result.hit_words[1].count = 12
		long_result.missed_words[0].count = 7
		app._pop.set_reduced_motion(false)
		app._pop._build_results(long_result)
		await settle()
		check_result_contents(app._pop, long_result)
		check_result_feedback(app._pop, count)
		for dimensions in [Vector2i(320, 568), Vector2i(844, 390), Vector2i(1366, 768)]:
			root.size = dimensions
			await settle()
			check_result_actions(app._pop, dimensions, "Long words, %d hits" % count)
			check_result_player(app._pop, long_profile, dimensions)
			var counter: Label = app._pop._result_hits
			var text_width: float = counter.get_theme_font("font").get_string_size(counter.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, counter.get_theme_font_size("font_size")).x
			check(text_width <= counter.size.x + 1.0, "The full hit total remains readable on compact result screens")
		app._pop.set_reduced_motion(true)
		app._pop._build_results(long_result)
		check(str(app._pop.snapshot().results_hits.text) == str(count)
			and not bool(app._pop.snapshot().results_hits.active) and app._pop._result_hits.scale.is_equal_approx(Vector2.ONE),
			"Reduced motion presents the complete hit total immediately without a count-up or scale animation")
		app._pop._advance_result_feedback(0.5)
		check(str(app._pop.snapshot().results_hits.text) == str(count),
			"Advancing reduced-motion feedback cannot rewind or recount the displayed total")
	root.size = layout_viewport_size
	await settle()
	check(app._pop.game.summary() == empty_round, "Result-only layout fixtures never alter the underlying scored round")
	app._pop.configure(app.data.words, true, 42)
	check(app._pop._round_player.is_empty() and app._pop.snapshot().results_hits.player.is_empty(),
		"Preparing a new round clears the previous result identity")
	check_bonus_feedback(app.data.words)
	check_homophone_feedback(app.data.words)
	check_bound_speech_events(app.data.words)
	check_independent_card_flight(app.data.words)
	check_portrait_volley_flight(app.data.words)
	check_volley_launches(app.data.words)
	check_frame_presentation(app.data.words)
	check_draw_caches()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Voice Pop scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Countdown = preload("res://scripts/memory_peek_countdown.gd")
const Badge = preload("res://scripts/memory_reward_badge.gd")

var checks: int = 0
var failures: int = 0
var skips: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	var data := Data.new()
	if not data.load_all():
		check(false, "Memory reward UI requires the acquired chest manifest")
		quit(1)
		return
	var clock := Countdown.new()
	root.add_child(clock)
	clock.skip_requested.connect(func() -> void: skips += 1)
	for dimensions: Vector2 in [Vector2(238, 52), Vector2(184, 52), Vector2(500, 44)]:
		clock.size = dimensions
		clock.configure(10.0, 10.0, Data.theme("spring"), false)
		clock.show()
		await process_frame
		var state: Dictionary = clock.snapshot()
		var action: Rect2 = clock.action_button.get_rect()
		check(state.phase == "observation" and not state.phase_label.is_empty(), "The live clock explicitly labels observation")
		check(action.size.y >= 44.0 and action.size.x >= 96.0, "Start matching retains its touch target at %s" % dimensions)
		check(Rect2(Vector2.ZERO, dimensions).encloses(action), "The action stays inside its fixed header row at %s" % dimensions)
		check(clock.bar_rect().end.x <= action.position.x - 4.0, "The countdown does not overlap its Start matching action")
		check(clock.action_button.focus_mode == Control.FOCUS_ALL, "The host can include the real action in keyboard/controller focus")
	clock.set_paused(true)
	clock.action_button.pressed.emit()
	check(skips == 0 and clock.action_button.disabled, "Pause suppresses skip activation")
	clock.set_paused(false)
	clock.action_button.pressed.emit()
	clock.action_button.pressed.emit()
	check(skips == 1 and clock.action_button.disabled, "One observation can request its transition only once")
	clock.configure(0.0, 10.0, Data.theme("spring"), true)
	check(not clock.action_button.visible and clock.progress() == 0.0, "Expiry removes the obsolete observation action")
	clock.configure(5.0, 5.0, Data.theme("spring"), true)
	check(not clock.action_button.disabled and clock.snapshot().seconds == 5, "A later real observation restores the action and accurate time")
	check(not clock.is_processing(), "Reduced motion keeps the clock legible without its ambient animation")

	var badge := Badge.new()
	root.add_child(badge)
	badge.position = Vector2(12, 100)
	badge.size = Vector2(112, 52)
	check(badge.configure("memory-a", 6, data.chests, Data.theme("spring"), false), "A fresh round configures the highest available production chest")
	await process_frame
	check(badge.snapshot().tier == 6 and badge.snapshot().theme_id == "winter" and badge.chest.closed_art_rect().has_area(),
		"The top Memory reward uses the integrated Crystal chest")
	check(not badge.snapshot().animating and badge.snapshot().change_count == 0, "A fresh header does not play a damage reaction")
	var original: Rect2 = badge.get_rect()
	var chest_origin: Vector2 = badge.chest.position
	for tier in [5, 4, 3, 2, 1, 0]:
		check(badge.configure("memory-a", tier, data.chests, Data.theme("spring"), false), "A mismatch accepts the model's lower tier")
		check(badge.snapshot().display_tier == tier + 1, "The previous chest stays visible until the contraction commits its replacement")
		var art_center: Vector2 = badge.chest.get_global_transform() * badge.chest.closed_art_rect().get_center()
		badge.advance(0.12)
		check(badge.snapshot().animating and badge.chest.scale.x < 0.82 and is_zero_approx(badge.chest.rotation)
			and badge.chest._model_view.snapshot().model_rotation.y < -0.25
			and badge.chest.modulate.r < 0.8,
			"A decrement immediately compresses and darkens the chest while starting its reverse turn")
		check((badge.chest.get_global_transform() * badge.chest.closed_art_rect().get_center()).distance_to(art_center) < 0.001,
			"The reverse turn pivots on the chest artwork without an orbital flight")
		check(badge.get_rect() == original and badge.chest.position == chest_origin, "A decrement never moves the header or chest anchor")
		var elapsed: float = badge.snapshot().elapsed
		badge.configure("memory-a", tier, data.chests, Data.theme("spring"), false)
		check(badge.snapshot().elapsed == elapsed and badge.snapshot().change_count == 6 - tier, "A layout refresh cannot replay the same decrement")
		badge.set_paused(true)
		badge.advance(1.0)
		check(badge.snapshot().elapsed == elapsed, "Pause freezes the reaction without changing the earned tier")
		badge.set_paused(false)
		badge.advance(0.23)
		check(badge.snapshot().display_tier == tier and badge.chest.scale.x < 0.45 and is_zero_approx(badge.chest.rotation)
			and (tier == 0 or badge.chest._model_view.snapshot().model_rotation.y < -2.9),
			"The smaller chest replaces the previous tier at the contracted half turn")
		check(badge.chest.scale.x < 0.2 if tier == 0 else badge.chest.scale.x >= 0.39,
			"The final loss contracts visibly deeper than an ordinary one-tier downgrade")
		check(badge.get_rect() == original and badge.chest.position == chest_origin,
			"The tier swap leaves both the marker and playfield anchor fixed")
		badge.advance(1.0)
		check(not badge.snapshot().animating and badge.chest.scale == Vector2.ONE and badge.chest.rotation == 0.0
			and badge.chest.modulate == Color.WHITE,
			"The reaction settles exactly at the original pose")
	check(badge.visible and badge.snapshot().grey and badge.snapshot().text == "No chest", "Tier zero retains a grey production chest and clear text")
	check(badge.chest._pieces[0].node.material == badge._empty_material, "Tier zero desaturates this instance's artwork")
	var hold_samples: Array[Dictionary] = []
	for final_loss: bool in [false, true]:
		badge.configure("memory-loss-%s" % final_loss, 1 if final_loss else 6, data.chests, Data.theme("spring"), false)
		badge.configure("memory-loss-%s" % final_loss, 0 if final_loss else 5, data.chests, Data.theme("spring"), false)
		var hold_until: float = Badge.EMPTY_HOLD_SECONDS if final_loss else Badge.LOSS_HOLD_SECONDS
		var previous_scale: float = 1.0
		var previous_shade: float = 1.0
		var steady_center: Vector2 = badge.chest.get_global_transform() * badge.chest.closed_art_rect().get_center()
		var shown_tier: int = badge.snapshot().display_tier
		for frame in range(78):
			badge.advance(0.01)
			var state: Dictionary = badge.snapshot()
			if frame == 43:
				hold_samples.append(state)
			check(state.scale <= 1.0001 and state.shade <= 1.0001,
				"Loss never enlarges or brightens like a reward at frame %d" % frame)
			if state.elapsed < Badge.SWAP_SECONDS:
				check(state.scale <= previous_scale + 0.0001, "The loss contracts continuously into its material swap")
			elif state.elapsed >= hold_until:
				check(state.scale + 0.0001 >= previous_scale and state.shade + 0.0001 >= previous_shade,
					"The chest recovers quietly without a second bounce or a repeated flash")
			if state.display_tier == shown_tier:
				var current_center: Vector2 = badge.chest.get_global_transform() * badge.chest.closed_art_rect().get_center()
				check(current_center.distance_to(steady_center) < 0.001, "Every loss pose stays at the artwork's original center")
			else:
				shown_tier = state.display_tier
				steady_center = badge.chest.get_global_transform() * badge.chest.closed_art_rect().get_center()
			previous_scale = state.scale
			previous_shade = state.shade
		badge.advance(0.01)
		check(not badge.snapshot().animating and badge.chest.modulate == Color.WHITE,
			"Ordinary and final losses both finish within the same bounded reaction time")
	check(hold_samples[1].scale < 0.2 and hold_samples[0].scale > 0.4 and hold_samples[1].shade < hold_samples[0].shade,
		"Losing the final chest holds its deeper, darker collapse while an ordinary downgrade already recovers")
	badge.configure("memory-repeated", 6, data.chests, Data.theme("spring"), false)
	badge.configure("memory-repeated", 5, data.chests, Data.theme("spring"), false)
	badge.advance(0.18)
	badge.configure("memory-repeated", 4, data.chests, Data.theme("spring"), false)
	check(badge.snapshot().tier == 4 and badge.snapshot().display_tier == 5 and badge.snapshot().elapsed == 0.0
		and badge.snapshot().change_count == 2, "A rapid second decrement restarts from the most recently committed tier")
	badge.advance(1.0)
	check(badge.snapshot().display_tier == 4 and badge.snapshot().theme_id == "space" and not badge.snapshot().animating,
		"Rapid decrements settle on the current tier without a late previous replacement")
	badge.configure("memory-b", 6, data.chests, Data.theme("spring"), true)
	badge.configure("memory-b", 5, data.chests, Data.theme("spring"), true)
	check(badge.snapshot().tier == 5 and not badge.snapshot().animating and badge.chest.scale == Vector2.ONE and badge.chest.rotation == 0.0,
		"Reduced motion communicates the changed tier without a moving marker")
	badge.configure("memory-b", 4, data.chests, Data.theme("spring"), false)
	badge.advance(0.12)
	badge.configure("memory-b", 4, data.chests, Data.theme("spring"), true)
	check(badge.snapshot().display_tier == 4 and badge.snapshot().theme_id == "space"
		and not badge.snapshot().animating and badge.chest.scale == Vector2.ONE and badge.chest.rotation == 0.0
		and badge.chest.modulate == Color.WHITE,
		"Enabling reduced motion mid-turn immediately shows the actual tier at rest")
	badge.configure("memory-reset", 1, data.chests, Data.theme("spring"), false)
	badge.configure("memory-reset", 0, data.chests, Data.theme("spring"), false)
	badge.advance(0.22)
	badge.reset()
	badge.advance(5.0)
	check(not badge.visible and badge.snapshot().round_id.is_empty() and not badge.snapshot().animating
		and badge.chest.modulate == Color.WHITE and badge.chest.scale == Vector2.ONE and badge.chest.rotation == 0.0,
		"Reset cancels pending feedback and removes the old round")
	badge.configure("memory-c", 6, data.chests, Data.theme("spring"), false)
	check(badge.snapshot().change_count == 0 and not badge.snapshot().animating, "A later round never replays a previous mismatch")
	check(not badge.configure("", 6, data.chests, Data.theme("spring"), false) and badge.snapshot().round_id == "memory-c",
		"An invalid configuration preserves the current marker")
	# At 320 CSS pixels the real reserved badge is 85.84 CSS pixels wide.
	# Exercise that allocation at the same 2/3 canvas scale as the web export.
	root.content_scale_size = Vector2i(480, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(320, 640)
	await process_frame
	var ui_scale: float = Style.ui_scale(badge)
	badge.size = Vector2(85.84, 52.0) / ui_scale
	for tier in [6, 0]:
		badge.configure("memory-narrow", tier, data.chests, Data.theme("spring"), true)
		var font_size: int = badge.tier_label.get_theme_font_size("font_size")
		check(font_size * ui_scale >= 11.0, "Narrow reward text never shrinks below 11 CSS pixels")
		check(badge.tier_label.text == ("Chest\nLv 6" if tier > 0 else "No\nchest"),
			"A narrow badge uses complete compact text without reducing its artwork")
		for line: String in badge.tier_label.text.split("\n"):
			check(Style.HEADING_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= badge.tier_label.size.x,
				"Every displayed narrow reward line fits: %s" % line)
		check(is_equal_approx(badge.chest.size.x * ui_scale, 56.0), "Compact text preserves the production chest display size")
	badge.size = Vector2(112, 52) / ui_scale
	badge.configure("memory-wide", 6, data.chests, Data.theme("spring"), true)
	check(badge.tier_label.text == "Chest\nLevel 6", "Wider layouts retain the full level label")
	badge.configure("memory-wide", 0, data.chests, Data.theme("spring"), true)
	check(badge.tier_label.text == "No chest", "Wider layouts retain the single-line empty label")
	clock.queue_free()
	badge.queue_free()
	await process_frame
	print("Memory reward UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

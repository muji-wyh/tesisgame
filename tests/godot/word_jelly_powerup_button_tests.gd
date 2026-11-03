extends SceneTree

const Powerup = preload("res://scripts/word_jelly_powerup_button.gd")

class ObservedPowerup extends "res://scripts/word_jelly_powerup_button.gd":
	var accessibility_updates: int = 0
	func _update_accessibility() -> void:
		accessibility_updates += 1
		super._update_accessibility()

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _check_unchanged_availability() -> void:
	var button := ObservedPowerup.new()
	root.add_child(button)
	button.set_availability(true, true)
	var updates: int = button.accessibility_updates
	for frame in range(120):
		button.set_availability(true, true)
	check(button.accessibility_updates == updates,
		"Stable game frames do not rebuild unchanged purchase accessibility or trigger extra redraw work")
	button.grab_focus()
	button.clear_preview()
	button.set_availability(true, true)
	check(button.snapshot().preview_active,
		"A cached availability update still restores the actual focused hover preview after temporary cancellation")
	button.set_availability(false, true)
	check(button.disabled and button.accessibility_updates == updates + 1 and not button.snapshot().preview_active,
		"Real board availability changes immediately update input, preview and accessibility")
	button.set_availability(true, false, false, false)
	check(not button.disabled and str(button.get("accessibility_name")).contains("Coin balance unavailable"),
		"Affordability and storage changes remain explicit even when the board is playable")
	button.free()


func _check_goal() -> void:
	var goal := Powerup.new()
	root.add_child(goal)
	var item := {"id": "cat", "word_id": "cat", "text": "cat", "current": 0, "required": 2, "mastered": false}
	goal.configure_goal(item, 200, false)
	for scale_value: float in [0.65, 1.0, 1175.0 / 480.0]:
		for compact: bool in [false, true]:
			var width: float = 140.0 if compact else 152.0
			var height: float = 44.0 if compact else 52.0
			var left: float = 36.0 if compact else 54.0
			var y: float = height - 23.0
			goal.size = Vector2(width, height) / scale_value
			var picture_edge: float = 24.0 if compact else 38.0
			goal.layout_goal(Rect2(Vector2(6, 7) / scale_value, Vector2.ONE * picture_edge / scale_value),
				Rect2(Vector2(left, 0) / scale_value, Vector2(width - left - 10, y) / scale_value),
				Rect2(Vector2(left, y) / scale_value, Vector2(46, 21) / scale_value),
				Rect2(Vector2(width - 42, y) / scale_value, Vector2(34, 21) / scale_value), scale_value, compact)
			var state: Dictionary = goal.snapshot()
			for key: String in ["icon_rect", "title_rect", "price_rect", "coin_rect"]:
				var area: Array = state[key]
				check(Rect2(Vector2.ZERO, goal.size).encloses(Rect2(area[0], area[1], area[2], area[3])),
					"Goal word and price fit both genuine sidebar and compact layouts at every scale")
			check(state.title == "cat" and state.price_text == "200"
				and goal._title.get_theme_font_size("font_size") * scale_value >= 11.0,
				"A goal retains a readable word name and truthful price, not a Magnet title")
	goal.set_availability(true, true)
	goal.feedback(true, 200)
	goal.advance(0.12)
	goal.set_price(300)
	check(goal.snapshot().spent_coins == 200 and goal.snapshot().price_text == "300"
		and goal.snapshot().coin_scale > 1.0 and goal.snapshot().price_offset != [0.0, 0.0],
		"The shared feedback emphasizes the actually spent cost while preserving the next quote")
	goal.advance(1.0)
	check(goal.snapshot().spent_coins == 0 and not goal.snapshot().feedback_active,
		"Actual payment feedback ends cleanly without changing the goal's quote")
	goal.set_availability(true, false)
	goal.feedback(false)
	goal.insufficient_coins(50)
	check(goal.snapshot().title == "Need coins" and goal.snapshot().missing_coins == 50
		and goal.snapshot().price_text == "300" and goal.snapshot().spent_coins == 0
		and str(goal.get("accessibility_name")).contains("Auto merge cat"),
		"A rejected goal keeps its family, real price and shortage without claiming a debit")
	goal.set_reduced_motion(true)
	check(goal.snapshot().price_offset == [0.0, 0.0] and goal.snapshot().coin_scale == 1.0
		and goal.snapshot().funds_warning,
		"The shared reduced-motion path retains a goal's explicit money explanation")
	goal.pause_feedback(true)
	var age: float = goal.snapshot().feedback_elapsed
	goal.advance(5.0)
	check(goal.snapshot().feedback_elapsed == age and not goal.snapshot().funds_warning,
		"A paused goal never consumes or displays an active warning")
	goal.pause_feedback(false)
	goal.advance(2.0)
	check(goal.snapshot().title == "cat" and not goal.snapshot().feedback_active,
		"Resume returns the bounded goal feedback to its ordinary family name")
	item.current = 2
	item.mastered = true
	goal.set_goal(item)
	check(goal.snapshot().progress_ratio == 1.0 and not goal.snapshot().price_visible,
		"Completed goals expose their true progress without an obsolete purchase cost")
	goal.queue_free()


func _check_tool_layout() -> void:
	var button := Powerup.new()
	root.add_child(button)
	for scale_value: float in [0.65, 1.0, 1.5, 1175.0 / 480.0, 3.2]:
		for width: float in [88.0, 112.0, 144.0, 184.0, 220.0]:
			for height: float in [44.0, 56.0]:
				for kind: String in ["auto_merge", "fragments", "extra_time"]:
					button.configure(kind, 1200 if kind == "auto_merge" else 400, false)
					button.set_ui_scale(scale_value, height < 55.0)
					button.size = Vector2(width, height) / scale_value
					button._layout()
					var state: Dictionary = button.snapshot()
					var areas: Dictionary = {}
					for key: String in ["icon_rect", "title_rect", "price_rect", "coin_rect"]:
						var values: Array = state[key]
						areas[key] = Rect2(values[0], values[1], values[2], values[3])
						check(Rect2(Vector2.ZERO, button.size).grow(0.01).encloses(areas[key]),
							"Actual paid-tool content fits at width %s, height %s, scale %s" % [width, height, scale_value])
					for label: Label in [button._title, button._price_label]:
						var font: Font = label.get_theme_font("font")
						var font_size: int = label.get_theme_font_size("font_size")
						check(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x + 0.01
							and font.get_height(font_size) <= label.size.y + 0.01
							and font_size * scale_value * label.scale.x >= 10.0,
							"Tool text '%s' fits at width %s, height %s, scale %s, font %s, area %s" % [
								label.text, width, height, scale_value, font_size * scale_value * label.scale.x, label.size])
					check(not Rect2(areas.icon_rect).intersects(areas.title_rect)
						and not Rect2(areas.icon_rect).intersects(areas.coin_rect)
						and not Rect2(areas.title_rect).intersects(areas.price_rect),
						"Artwork, name and cost have separate content areas")
					if width >= (180.0 if kind == "auto_merge" else 144.0):
						check(button._title.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT
							and is_equal_approx(Rect2(areas.title_rect).position.x, Rect2(areas.coin_rect).position.x)
							and Rect2(areas.icon_rect).end.x + 6.0 / scale_value <= Rect2(areas.title_rect).position.x
							and Rect2(areas.title_rect).end.y <= Rect2(areas.coin_rect).position.y
							and is_equal_approx(Rect2(areas.icon_rect).get_center().y, button.size.y * 0.5),
							"Wide tools align name and cost beside a vertically centered sourced icon")
					else:
						check(button._title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
							"Narrow tools preserve a full-width readable title above art, price and capacity")
	button.queue_free()


func _run() -> void:
	_check_unchanged_availability()
	var button := Powerup.new()
	root.add_child(button)
	for scale_value: float in [0.65, 1.0, 1.5]:
		for width: float in [88.0, 100.0, 120.0]:
			for kind: String in ["auto_merge", "fragments"]:
				button.configure(kind, 1200 if kind == "auto_merge" else 400, false)
				button.set_ui_scale(scale_value)
				button.size = Vector2(width, 64.0) / scale_value
				button._layout()
				var state: Dictionary = button.snapshot()
				check(state.kind == kind, "canonical powerup kind survives configuration")
				check((button.custom_minimum_size * scale_value).is_equal_approx(Vector2(88.0, 56.0)), "minimum physical purchase target is comfortable")
				for key: String in ["title_rect", "price_rect"]:
					var values: Array = state[key]
					var rect := Rect2(values[0], values[1], values[2], values[3])
					check(Rect2(Vector2.ZERO, button.size).encloses(rect), "purchase content fits: %s %s scale=%s bounds=%s content=%s" % [kind, key, scale_value, button.size, rect])
				check(button._title.get_visible_line_count() >= button._title.get_line_count(), "complete title remains visible")
				check(button.tooltip_text.is_empty(), "purchase controls never show tooltips")
	var desktop_scale: float = 1175.0 / 480.0
	for desktop_width: float in [100.0, 104.0]:
		button.configure("auto_merge", 1200, false)
		button.set_ui_scale(desktop_scale)
		button.size = Vector2(desktop_width, 72.0) / desktop_scale
		button._layout()
		var title: Label = button._title
		var physical_font_size: float = title.get_theme_font_size("font_size") * desktop_scale * title.scale.x
		var physical_line_height: float = title.get_line_height() * desktop_scale * title.scale.y
		check(physical_font_size >= 10.0, "desktop Auto merge lettering stays at least 10 physical pixels at width=%s; actual=%s" % [desktop_width, physical_font_size])
		check(physical_line_height >= 10.0, "desktop Auto merge line height remains readable at width=%s" % desktop_width)
		check(title.get_visible_line_count() == title.get_line_count(), "desktop Auto merge shows every title line at width=%s" % desktop_width)
		check(Rect2(Vector2.ZERO, button.size).encloses(Rect2(title.position, title.size * title.scale)),
			"desktop Auto merge title stays inside its physical purchase target at width=%s" % desktop_width)
	button.configure("auto_merge", 1200, false)
	button.set_availability(true, false)
	check(not button.disabled and not button.snapshot().affordable, "low funds remains clickable")
	button.feedback(false)
	button.advance(0.08)
	var rejected: Dictionary = button.snapshot()
	check(rejected.feedback_active and not rejected.feedback_success and rejected.light > 0.0, "rejection presents warm feedback")
	check(rejected.icon_offset != [0.0, 0.0], "normal rejection visibly recoils")
	button.pause_feedback(true)
	button.advance(2.0)
	check(button.snapshot().feedback_elapsed == rejected.feedback_elapsed, "pause freezes feedback clock")
	check(button.snapshot().light == 0.0 and button.snapshot().icon_scale == 1.0, "pause hides transient visual feedback")
	button.pause_feedback(false)
	button.advance(1.0)
	check(not button.snapshot().feedback_active, "rejection settles")
	button.feedback(true)
	button.advance(0.18)
	check(button.snapshot().icon_scale > 1.0 and button.snapshot().light > 0.0, "success lifts artwork with local light")
	var success_time: float = button.snapshot().feedback_elapsed
	button.set_price(900)
	check(button.snapshot().price == 900 and button.snapshot().price_text == "900"
		and button.snapshot().feedback_elapsed == success_time and button.snapshot().feedback_success,
		"refreshing the next price keeps the current successful-purchase animation intact")
	check(str(button.get("accessibility_name")).contains("900 coins"), "the updated accessible price matches the visible price")
	button.hide()
	var hidden_time: float = button.snapshot().feedback_elapsed
	button.advance(1.0)
	check(button.snapshot().feedback_elapsed == hidden_time, "hidden owner cannot leak feedback clock")
	button.show()
	button.reset()
	check(not button.snapshot().feedback_active and button.snapshot().icon_scale == 1.0, "reset clears the visual without changing the purchase")
	button.set_availability(true, true, true)
	check(button.disabled, "busy action blocks repeated activation")
	button.set_availability(false, true)
	check(button.disabled, "unavailable action is disabled")
	button.configure("treasure", 200, true)
	check(button.snapshot().kind == "fragments" and button.snapshot().title == "Treasure", "Treasure alias keeps the model's fragment identity")
	button.set_availability(true, true)
	for success: bool in [true, false]:
		button.feedback(success)
		button.advance(0.12)
		var state: Dictionary = button.snapshot()
		check(state.icon_scale == 1.0 and state.icon_rotation == 0.0 and state.icon_offset == [0.0, 0.0], "reduced motion keeps the sourced icon still")
		check(state.light > 0.0, "reduced motion still indicates outcome")
		button.advance(1.0)
		check(not button.snapshot().feedback_active, "reduced feedback clears promptly")
	button.configure("auto_merge", 600, false)
	button.set_ui_scale(1.0)
	button.size = Vector2(88, 56)
	button.set_availability(true, false)
	var target: Rect2 = button.get_rect()
	button.feedback(false)
	button.insufficient_coins(150)
	button.advance(0.08)
	var funds: Dictionary = button.snapshot()
	check(funds.funds_warning and funds.missing_coins == 150 and funds.title == "Need coins"
		and funds.price_text == "600", "The actual shortage is explicit without replacing the quoted price")
	check(funds.price_offset != [0.0, 0.0] and funds.coin_scale > 1.0
		and funds.icon_offset == [0.0, 0.0] and funds.icon_scale == 1.0,
		"Low funds highlights the money instead of making the purchased tool look broken")
	check(button.get_rect() == target and button.tooltip_text.is_empty(),
		"The local warning never moves the touch target or creates a tooltip")
	button.advance(0.5)
	check(button.snapshot().funds_warning, "The cause remains readable after the short initial recoil settles")
	var retry_serial: int = button.snapshot().feedback_serial
	button.feedback(false)
	button.insufficient_coins(150)
	check(button.snapshot().feedback_serial == retry_serial + 1 and button.snapshot().feedback_elapsed == 0.0,
		"A repeated rejected click restarts one bounded response, not an accumulating animation")
	button.pause_feedback(true)
	var funds_time: float = button.snapshot().feedback_elapsed
	button.advance(2.0)
	check(button.snapshot().feedback_elapsed == funds_time and not button.snapshot().funds_warning,
		"Pause hides and freezes the transient money warning")
	button.pause_feedback(false)
	check(button.snapshot().funds_warning, "Resume restores the same warning rather than announcing a new purchase")
	button.set_reduced_motion(true)
	button.advance(0.1)
	check(button.snapshot().funds_warning and button.snapshot().price_offset == [0.0, 0.0]
		and button.snapshot().coin_scale == 1.0 and button.snapshot().title == "Need coins",
		"Reduced motion retains the explicit reason without shaking the price or scaling the coin")
	button.advance(2.0)
	check(not button.snapshot().funds_warning and button.snapshot().title == "Auto merge"
		and button.snapshot().price_text == "600" and button.snapshot().missing_coins == 0,
		"The original tool and price return cleanly after the warning")
	button.feedback(false)
	check(not button.snapshot().funds_warning and button.snapshot().title == "Auto merge",
		"Other rejection causes cannot inherit a stale insufficient-funds explanation")
	button.set_availability(true, false, false, false)
	check(str(button.get("accessibility_name")).contains("Coin balance unavailable"),
		"An unavailable wallet is not announced as a known low balance")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	root.add_child(viewport)
	button.set_chest_texture(viewport.get_texture())
	check(button._chest == viewport.get_texture(), "a new viewport chest is accepted without a GPU readback")
	viewport.queue_free()
	_check_goal()
	_check_tool_layout()
	button.queue_free()
	await process_frame
	print("Powerup button checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures > 0 else 0)

extends SceneTree

const Powerup = preload("res://scripts/word_jelly_powerup_button.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var button := Powerup.new()
	root.add_child(button)
	for scale_value: float in [0.65, 1.0, 1.5]:
		for width: float in [88.0, 100.0, 120.0]:
			for kind: String in ["auto_merge", "fragments"]:
				button.configure(kind, 2000 if kind == "auto_merge" else 500, false)
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
		button.configure("auto_merge", 2000, false)
		button.set_ui_scale(desktop_scale)
		button.size = Vector2(desktop_width, 72.0) / desktop_scale
		button._layout()
		var title: Label = button._title
		var physical_font_size: float = title.get_theme_font_size("font_size") * desktop_scale
		var physical_line_height: float = title.get_line_height() * desktop_scale
		check(physical_font_size >= 10.0, "desktop Auto merge lettering stays at least 10 physical pixels at width=%s; actual=%s" % [desktop_width, physical_font_size])
		check(physical_line_height >= 10.0, "desktop Auto merge line height remains readable at width=%s" % desktop_width)
		check(title.get_visible_line_count() == title.get_line_count(), "desktop Auto merge shows every title line at width=%s" % desktop_width)
		check(Rect2(Vector2.ZERO, button.size).encloses(title.get_rect()), "desktop Auto merge title stays inside its physical purchase target at width=%s" % desktop_width)
	button.configure("auto_merge", 2000, false)
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
	button.configure("treasure", 500, true)
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
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	root.add_child(viewport)
	button.set_chest_texture(viewport.get_texture())
	check(button._chest == viewport.get_texture(), "a new viewport chest is accepted without a GPU readback")
	viewport.queue_free()
	button.queue_free()
	await process_frame
	print("Powerup button checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures > 0 else 0)

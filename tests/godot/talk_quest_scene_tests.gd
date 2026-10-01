extends SceneTree

const Quest = preload("res://scripts/talk_quest.gd")
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
	for frame in range(4):
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 740)
	var file: String = "user://quest-scene-%d.cfg" % Time.get_ticks_usec()
	var quest = Quest.new()
	quest.save_path = file
	root.add_child(quest)
	quest.size = Vector2(366, 610)
	await settle()
	check(quest._level_buttons.size() == 14 and quest._album_grid.get_child_count() == 20, "The map and shelf expose all reviewed designs")
	check(not quest._level_buttons[0].disabled and quest._level_buttons[1].disabled, "Only the first level starts unlocked")
	quest.start_level(1)
	await settle()
	check(quest.game.phase == "playing" and quest._monster.creature_id == "lpm-goleing", "Starting level one creates the acquired creature")
	quest._submit_text("wrong sentence")
	check(quest.game.line_index == 0, "Typed fallback cannot skip a mismatched sentence")
	quest._submit_text(quest.game.current_prompt().text)
	quest._process(1.0)
	quest.pause()
	check(quest.game.phase == "paused" and not quest._auto_listen, "Pause freezes the run without enabling automatic microphone resume")
	var snapshot: Dictionary = quest.game.export_progress()
	check(not JSON.stringify(snapshot).contains("Knock"), "The scene's saved progress excludes recognized words")
	quest._show_map()
	quest._continue_run()
	check(quest.game.phase == "playing" and quest.game.line_index == 1, "Continue resumes the exact prompt")
	for number in range(1, 15):
		if number > 1:
			quest.start_level(number)
		await settle()
		check(quest._monster.creature_id == quest.game.level.monster_id, "The scene uses the level's specific monster")
		check(quest._monster.process_mode == Node.PROCESS_MODE_INHERIT, "New levels resume character animation")
		while quest.game.phase == "playing":
			if quest._part_required():
				quest._choose_part(["wheel", "wing", "ribbon", "screw", "key"][quest.game.repaired_toys.size()])
			quest._submit_text(quest.game.current_prompt().text)
			quest._process(0.9)
		check(quest.game.phase == "victory", "Every dialogue produces a victory sequence")
		if number == 14:
			check(quest.game.hp == 0 and quest.game.repaired_toys.size() == 5 and quest._monster.state != "defeated", "The workshop repairs all five toys without combat")
		quest._process(3.2)
		check(quest.game.phase == "chest" and quest._chest_button.visible, "Victory leads to an explicit chest interaction")
		quest._open_chest()
		quest._chest._process(3.5)
		check(quest.game.phase == "complete" and quest.game.total_clears == number, "The reveal commits exactly one reward")
		quest._reward_revealed()
		check(quest.game.total_clears == number, "A duplicate reveal cannot add a reward")
		quest._chest._process(1.6)
		check(not quest._next.disabled, "Next becomes available after the chest settles and saves")
	check(quest.game.completed_levels.size() == 14 and quest.game.collected_chests.size() == 14, "The whole campaign persists its first-clear collection")
	quest._show_album()
	check(quest._album.visible and quest._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "The album stops rendering the hidden 3D stage")
	quest.set_reduced_motion(true)
	check(quest._chest.reduced_motion and quest._monster.reduced_motion, "Reduced motion reaches both art systems")
	quest._show_map()
	quest.start_level(14)
	quest._choose_part("wheel")
	quest._toggle_type()
	await settle()
	for control in [quest._prompt, quest._speak, quest._hear, quest._type, quest._input, quest._submit]:
		check(control.get_global_rect().end.x <= quest.get_global_rect().end.x + 1, "Mobile controls remain within the available width")
	quest.pause()
	quest.queue_free()
	await process_frame
	var restored = Quest.new()
	restored.save_path = file
	root.add_child(restored)
	await settle()
	check(restored.game.completed_levels.size() == 14 and restored.game.has_saved_run(), "A new scene loads progression and the pending workshop")
	restored._continue_run()
	check(restored.game.level_number == 14 and restored.game.phase == "playing", "The restored workshop is playable")
	restored.queue_free()
	await process_frame
	DirAccess.remove_absolute(file)
	print("Talk Quest scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

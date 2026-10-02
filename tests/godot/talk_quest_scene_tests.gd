extends SceneTree

const Quest = preload("res://scripts/talk_quest.gd")
const Feel = preload("res://scripts/chest_feel.gd")
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
	quest.set_process(false)
	quest._effects.set_process(false)
	await settle()
	check(quest._level_buttons.size() == 14 and quest._album_grid.get_child_count() == 20, "The map and shelf expose all reviewed designs")
	check(not quest._level_buttons[0].disabled and quest._level_buttons[1].disabled, "Only the first level starts unlocked")
	check(not quest._level_buttons[0].has_meta("portrait"), "Map destinations do not expose monster portraits")
	check(quest._atlas.get_parent() == quest._map and quest._atlas.custom_minimum_size == Vector2.ZERO,
		"The map uses a bounded chapter atlas without a scroll container")
	for control_name in ["speak", "hear", "type", "submit", "input"]:
		check(not quest._controls.has(control_name), "The word arena omits the old dialogue control: " + control_name)
	quest.start_level(1)
	await settle()
	check(quest.game.phase == "playing" and quest._monster.creature_id == "giant-rock-guardian", "Starting level one creates the acquired stone guardian")
	quest._submit_text("unmatchedword")
	check(quest.game.hits == 0 and not quest._impact_pending, "Unmatched speech cannot damage the monster or launch a bullet")
	var initial_hp: int = quest.game.hp
	var paused_uid: int = int(quest.game.current_prompt().uid)
	quest._submit_text(quest.game.current_prompt().text)
	check(quest.game.hits == 1 and quest.game.hp == initial_hp - 1 and quest._impact_pending,
		"A recognized live word launches one attack and reserves exactly one health point")
	check(quest._display_hp == initial_hp and quest._effects._attacks.size() == 1,
		"The visible health waits for the flying word to reach the monster")
	quest.pause()
	check(quest.game.phase == "paused" and not quest._auto_listen, "Pause freezes the run without enabling automatic microphone resume")
	check(not quest._impact_pending and quest._effects._attacks.is_empty(), "Pausing cancels pending visual attacks")
	var paused_hits: int = quest.game.hits
	quest._spell_impact(paused_uid)
	check(quest.game.hits == paused_hits and quest.game.phase == "paused", "Late visual callbacks cannot score or resume a paused run")
	var snapshot: Dictionary = quest.game.export_progress()
	check(not snapshot.has("last_transcript"), "The scene's saved progress excludes recognized speech")
	quest._show_map()
	quest._continue_run()
	check(quest.game.phase == "playing" and quest.game.hits == 1 and quest.game.hp == initial_hp - 1,
		"Continue resumes the earned damage without replaying a canceled visual attack")
	_check_projectile_binding(quest)
	var previous_hp: int = 0
	for number in range(1, 15):
		if number > 1:
			quest.start_level(number)
		await settle()
		check(quest._monster.creature_id == quest.game.level.monster_id, "The scene uses the level's specific monster")
		check(quest._monster.process_mode == Node.PROCESS_MODE_INHERIT, "New levels resume character animation")
		check(quest.game.max_hp > previous_hp and quest.game.total_words > quest.game.max_hp,
			"Each later monster has more health and a finite word budget with extra chances")
		previous_hp = quest.game.max_hp
		for turn in range(300):
			if quest.game.phase != "playing":
				break
			var prompt: Dictionary = quest.game.current_prompt()
			if prompt.is_empty():
				quest._process(0.5)
				continue
			var hp_before: int = quest.game.hp
			quest._submit_text(str(prompt.text))
			check(quest.game.hp == hp_before - 1 and quest._impact_pending and not quest._pending_hits.is_empty(),
				"Every matched live word launches exactly one monster projectile")
			quest._process(0.65)
			check(not quest._impact_pending and quest._display_hp == quest.game.hp,
				"Projectile arrival applies its visible damage exactly once")
		check(quest.game.phase == "victory" and quest.game.hp == 0 and quest.game.hits == quest.game.max_hp,
			"All fourteen word battles end with the required number of hits")
		check(quest._monster.state == "defeated", "Every campaign monster, including level fourteen, plays its defeat animation")
		quest._process(3.2)
		check(quest.game.phase == "chest" and quest._chest_button.visible, "Victory leads to an explicit chest interaction")
		if number == 1:
			quest._open_chest()
			check(not quest._opening, "A tap cannot bypass the confirmation hold")
			quest.start_chest_hold()
			quest._advance_chest_hold(0.4)
			quest.end_chest_hold()
			check(not quest._holding_chest and quest._chest.mode == "closed" and quest.game.total_clears == 0, "Releasing during confirmation cancels without a reward")
			quest.start_chest_hold()
			quest._advance_chest_hold(Feel.HOLD_SECONDS)
			quest._chest._advance_animation(1.0)
			quest.end_chest_hold()
			check(not quest._opening and quest._chest.mode == "closed" and quest.game.phase == "chest", "Releasing after confirmation still cancels before physical release")
			quest._reward_finished()
			check(quest.game.total_clears == 0, "A late canceled opening callback cannot award treasure")
			quest.start_chest_hold()
			var drag := InputEventScreenDrag.new()
			drag.relative = Vector2(25, 0)
			drag.position = Vector2(125, 100)
			quest._chest_input(drag)
			check(not quest._holding_chest and not quest._opening, "Dragging the chest cancels the hold like Match")
			quest.end_chest_hold()
			quest.start_chest_hold()
			quest._advance_chest_hold(Feel.HOLD_SECONDS)
			quest.pause()
			check(not quest._opening and quest.game.phase == "paused" and quest.game.total_clears == 0, "Backgrounding cancels an uncommitted opening")
			quest._continue_run()
			check(quest.game.phase == "chest" and quest._chest.mode == "closed", "Resume requires a fresh chest gesture")
		quest.start_chest_hold()
		quest._advance_chest_hold(Feel.HOLD_SECONDS)
		check(quest._opening and quest._chest.mode == "opening", "A full confirmation begins the shared performance")
		quest._chest._advance_animation(Feel.RELEASE_TIME + 0.01)
		check(quest.game.phase == "chest" and quest.game.total_clears == number - 1, "Physical release commits the gesture but waits for opening completion to award")
		quest.end_chest_hold()
		check(quest._opening and quest._chest.opening_committed(), "Releasing after the flash preserves the opening tail")
		if number == 2:
			quest.pause()
			check(quest.game.phase == "complete" and quest.game.total_clears == number, "Backgrounding after release silently settles and saves once")
			quest._continue_run()
		else:
			quest._chest._advance_animation(Feel.OPEN_SECONDS)
		check(quest.game.phase == "complete" and quest.game.total_clears == number, "Opening completion commits exactly one reward")
		quest._reward_finished()
		check(quest.game.total_clears == number, "A duplicate completion cannot add a reward")
		check(not quest._next.disabled, "Next becomes available after the chest settles and saves")
	check(quest.game.completed_levels.size() == 14 and quest.game.collected_chests.size() == 14, "The whole campaign persists its first-clear collection")
	quest._show_album()
	check(quest._album.visible and quest._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "The album stops rendering the hidden 3D stage")
	quest.set_reduced_motion(true)
	check(quest._chest.reduced_motion and quest._monster.reduced_motion, "Reduced motion reaches both art systems")
	check(quest._atlas.reduced_motion and quest._effects.reduced_motion and quest._meter.reduced_motion, "Reduced motion reaches map, spells, and health presentation")
	quest._show_map()
	quest.start_level(14)
	quest._process(200.0)
	check(quest.game.phase == "lost" and quest._retry.visible, "Exhausting the final battle's finite words exposes Try again")
	quest.pause()
	check(quest._suspended and quest._resume.visible and not quest._retry.visible,
		"Backgrounding a lost battle presents its explicit resume control")
	quest._continue_run()
	check(not quest._suspended and quest.game.phase == "lost" and quest._retry.visible and not quest._resume.visible,
		"Resuming after a loss restores the retry screen instead of trapping Continue adventure")
	check(quest.game.total_clears == 14 and not quest.game.has_saved_run(), "Resuming a loss never awards treasure or invents a checkpoint")
	quest._retry.pressed.emit()
	check(quest.game.phase == "playing" and quest.game.hp == quest.game.max_hp and quest.game.misses == 0,
		"The restored Try again control starts a fresh word battle")
	await settle()
	for control in [quest._words, quest._transcript, quest._feedback, quest._meter, quest._back]:
		check(control.get_global_rect().end.x <= quest.get_global_rect().end.x + 1
			and control.get_global_rect().end.y <= quest.get_global_rect().end.y + 1,
			"Mobile word arena and controls remain within the available viewport")
	quest.pause()
	quest.queue_free()
	await process_frame
	var restored = Quest.new()
	restored.save_path = file
	root.add_child(restored)
	await settle()
	check(restored.game.completed_levels.size() == 14 and restored.game.has_saved_run(), "A new scene loads progression and the pending final battle")
	restored._continue_run()
	check(restored.game.level_number == 14 and restored.game.phase == "playing", "The restored final word battle is playable")
	restored.queue_free()
	await process_frame
	DirAccess.remove_absolute(file)
	print("Talk Quest scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_projectile_binding(quest) -> void:
	quest._process(0.5)
	var first: Dictionary = quest.game.current_prompt()
	check(not first.is_empty(), "The resumed battle produces the first projectile timing target")
	if first.is_empty():
		return
	var hp_before: int = quest._display_hp
	quest._submit_text(str(first.text))
	quest._process(0.46)
	quest._effects._process(0.46)
	var second: Dictionary = quest.game.current_prompt()
	check(not second.is_empty(), "A second live word can launch while the first bullet is still flying")
	if second.is_empty():
		return
	quest._submit_text(str(second.text))
	# The parent crosses its fallback threshold before the child's same-frame
	# visual signal. The second bullet is still far from the monster.
	quest._process(0.11)
	check(quest._pending_hits.size() == 1 and int(quest._pending_hits[0].uid) == int(second.uid)
		and quest._display_hp == hp_before - 1,
		"The fallback settles only its own older projectile")
	quest._effects._process(0.11)
	check(quest._pending_hits.size() == 1 and int(quest._pending_hits[0].uid) == int(second.uid)
		and quest._display_hp == hp_before - 1,
		"The older bullet's delayed visual callback cannot damage or consume the younger bullet")
	quest._process(0.4)
	quest._effects._process(0.4)
	check(quest._pending_hits.is_empty() and quest._display_hp == hp_before - 2,
		"The younger bullet applies its own visible damage when it reaches the monster")
	quest._effects.word_landed.emit(int(first.uid))
	quest._effects.word_landed.emit(int(second.uid))
	check(quest._pending_hits.is_empty() and quest._display_hp == hp_before - 2,
		"Duplicate visual callbacks never apply additional damage")

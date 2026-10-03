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
		"The horizontally scrolling world stays inside a bounded map viewport")
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
	quest._process(0.5)
	check(not quest.game.targets.is_empty(), "A second live target exists before the encounter is paused")
	quest.pause()
	check(quest.game.phase == "paused" and not quest._auto_listen, "Pause freezes the run without enabling automatic microphone resume")
	check(not quest._impact_pending and quest._effects._attacks.is_empty(), "Pausing cancels pending visual attacks")
	_check_pause_presentation(quest, "playing")
	check(quest._viewport_box.visible and not quest._chest.visible,
		"A paused word battle retains its encounter artwork instead of showing treasure")
	var frozen_targets: Array = quest.game.targets.duplicate(true)
	var frozen_elapsed: float = quest.game.elapsed
	var frozen_spawned: int = quest.game.spawned
	var frozen_misses: int = quest.game.misses
	quest._process(8.0)
	check(quest.game.targets == frozen_targets and is_equal_approx(quest.game.elapsed, frozen_elapsed)
		and quest.game.spawned == frozen_spawned and quest.game.misses == frozen_misses,
		"The pause presentation cannot age, spawn, or expire any live words")
	await _check_result_layouts(quest, quest._pause_card, "Pause")
	var paused_hits: int = quest.game.hits
	quest._spell_impact(paused_uid)
	check(quest.game.hits == paused_hits and quest.game.phase == "paused", "Late visual callbacks cannot score or resume a paused run")
	var snapshot: Dictionary = quest.game.export_progress()
	check(not snapshot.has("last_transcript"), "The scene's saved progress excludes recognized speech")
	quest._resume.pressed.emit()
	check(quest.game.phase == "playing" and quest.game.hits == paused_hits and quest.game.hp == initial_hp - 1
		and not quest._pause_card.visible and not quest._resume.is_visible_in_tree(),
		"The visible resume action restores earned health damage and hides the pause presentation")
	quest.pause()
	quest._pause_card.map_button.pressed.emit()
	check(quest.view == "map" and not quest._pause_card.visible and not quest.snapshot().pause_result.visible,
		"The pause card's map action hides the entire pause presentation on the map")
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
		if number == 1:
			quest.pause()
			_check_pause_presentation(quest, "victory")
			var victory_clears: int = quest.game.total_clears
			quest._process(4.0)
			check(quest.game.phase == "paused" and quest.game.total_clears == victory_clears
				and quest._viewport_box.visible and quest._monster.state == "defeated",
				"Pausing victory retains the defeated encounter without advancing or awarding treasure")
			quest._resume.pressed.emit()
			check(quest.game.phase == "victory" and not quest._pause_card.visible,
				"Resuming victory restores the victory transition before its chest")
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
			_check_pause_presentation(quest, "chest")
			check(quest._chest.visible and quest._treasure_backdrop.visible and not quest._viewport_box.visible
				and not quest._chest_button.visible,
				"Pausing an unopened chest retains its treasure scene without an active opening surface")
			quest._process(4.0)
			check(quest.game.phase == "paused" and quest.game.total_clears == 0,
				"A paused uncommitted chest cannot finish or award itself")
			quest._resume.pressed.emit()
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
			_check_pause_presentation(quest, "complete")
			check(quest._chest.visible and quest._treasure_backdrop.visible and not quest._next.visible,
				"A paused collection keeps the open treasure scene behind its resume action")
			var complete_progress: Dictionary = quest.game.export_progress().duplicate(true)
			quest._process(4.0)
			quest._reward_finished()
			check(quest.game.export_progress() == complete_progress,
				"Pause presentation and late completion cannot duplicate a committed chest")
			quest._resume.pressed.emit()
			check(not quest._pause_card.visible and quest.game.phase == "complete" and quest._next.visible,
				"Resuming a collected chest restores its next-adventure action")
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
	var cleared_before_loss: Array = quest.game.export_progress().completion_counts.duplicate()
	quest._process(200.0)
	check(quest.game.phase == "lost" and quest._retry.visible, "Exhausting the final battle's finite words exposes Try again")
	check(quest._loss.visible and quest._loss.retry == quest._retry and quest._loss.hits == 0
		and quest._loss.max_hp == quest.game.max_hp and quest._loss.remaining_hp == quest.game.max_hp,
		"An exhausted encounter presents an accurate zero-hit result with the existing retry action")
	check(quest._loss.reduced_motion and is_equal_approx(quest._loss.reveal, 1.0),
		"Reduced motion presents the complete loss result without waiting for an entrance animation")
	check(quest._loss.pip.is_visible_in_tree() and quest._loss.loss_emotion == "sad"
		and not quest._viewport_box.visible,
		"The exhausted encounter brings disappointed Pip forward in place of the guardian")
	var saved_loss := ConfigFile.new()
	check(saved_loss.load(file) == OK, "The loss result persists progression successfully")
	var loss_progress: Dictionary = JSON.parse_string(saved_loss.get_value("quest", "progress", "{}"))
	# JSON restores number arrays as floats; compare both sides in their persisted form.
	var expected_saved_counts: Array = JSON.parse_string(JSON.stringify(cleared_before_loss))
	check(loss_progress.get("completion_counts", []) == expected_saved_counts and loss_progress.get("run", {}).is_empty(),
		"A loss preserves saved rewards and clears the exhausted checkpoint")
	await _check_result_layouts(quest, quest._loss, "Loss")
	quest.pause()
	check(quest._suspended and quest._resume.visible and not quest._retry.is_visible_in_tree() and not quest._loss.visible,
		"Backgrounding a lost battle presents its explicit resume control")
	_check_pause_presentation(quest, "lost")
	check(quest._pause_card.reduced_motion and is_equal_approx(quest._pause_card.reveal, 1.0),
		"Reduced motion presents a fully visible pause card without its entrance animation")
	quest._process(4.0)
	check(quest.game.phase == "lost" and quest.game.hits == 0 and quest.game.total_clears == 14,
		"A paused loss preserves its exact final result and existing reward count")
	quest._resume.pressed.emit()
	check(not quest._suspended and quest.game.phase == "lost" and quest._retry.is_visible_in_tree()
		and quest._loss.visible and quest._loss.hits == 0 and not quest._resume.visible,
		"Resuming after a loss restores the retry screen instead of trapping Continue adventure")
	check(quest.game.total_clears == 14 and not quest.game.has_saved_run(), "Resuming a loss never awards treasure or invents a checkpoint")
	check(quest._loss.pip.is_visible_in_tree() and quest._loss.loss_emotion == "encouraging",
		"Returning from a paused loss offers encouragement without replaying disappointment")
	quest._retry.pressed.emit()
	check(quest.game.phase == "playing" and quest.game.hp == quest.game.max_hp and quest.game.misses == 0
		and quest.game.hits == 0 and not quest._loss.visible,
		"The restored Try again control starts a fresh word battle")
	_check_near_win_loss(quest)
	quest.start_level(14)
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


func _check_pause_presentation(quest, context_phase: String) -> void:
	check(quest._pause_card.visible and quest._pause_card.is_visible_in_tree()
		and quest._pause_card.retry == quest._resume and quest._pause_card.context_phase == context_phase,
		"The pause card owns the resume action and preserves its " + context_phase + " context")
	check(quest._pause_card.hits == quest.game.hits and quest._pause_card.max_hp == quest.game.max_hp
		and quest._pause_card.remaining_hp == quest.game.hp and not quest._loss.visible,
		"The pause card reports actual earned hits and health without exposing the rematch card")
	check(quest.default_focus() == quest._resume and not quest._resume.disabled,
		"The primary pause action remains enabled and owns keyboard focus")
	var state: Dictionary = quest.snapshot()
	check(state.pause_result.visible and state.pause_result.context_phase == context_phase
		and state.pause_result.hits == quest.game.hits and state.pause_result.remaining_hp == quest.game.hp
		and state.pause_result.max_hp == quest.game.max_hp and state.controls.pause_panel.visible
		and state.controls.pause_card.visible and state.controls.resume.visible and state.controls.map.visible,
		"The browser snapshot exposes the visible pause card, its exact stats, and both actions")
	check(quest._monster.process_mode == Node.PROCESS_MODE_DISABLED
		and quest._chest.process_mode == Node.PROCESS_MODE_DISABLED,
		"Pause presentation freezes both encounter and treasure animation")


func _check_result_layouts(quest, result, label: String) -> void:
	result._process(1.0)
	for viewport_size in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(390, 740)]:
		root.size = viewport_size
		quest.size = Vector2(viewport_size) - Vector2(24, 130)
		quest._layout()
		await settle()
		var bounds: Rect2 = quest.get_global_rect().grow(1.0)
		var card: Rect2 = result.card
		card.position += result.global_position
		check(bounds.encloses(card), label + " card fits the available portrait or landscape play area")
		var retry_bounds: Rect2 = result.retry.get_global_rect()
		var map_bounds: Rect2 = result.map_button.get_global_rect()
		check(card.grow(1.0).encloses(retry_bounds) and card.grow(1.0).encloses(map_bounds),
			label + " actions remain inside their card after resizing")
		check(retry_bounds.size.x >= 44 and retry_bounds.size.y >= 44
			and map_bounds.size.x >= 44 and map_bounds.size.y >= 44,
			label + " actions retain usable touch targets in short landscape layouts")
		check(not retry_bounds.intersects(map_bounds), label + " actions never overlap")
		check(quest._stage_scroll.scroll_vertical == 0 and quest._stage.size.y <= quest.size.y + 1,
			label + " presentation needs no scrolling")


func _check_near_win_loss(quest) -> void:
	quest.start_level(1)
	var clears_before: int = quest.game.total_clears
	var chests_before: Array = quest.game.collected_chests.duplicate()
	var misses_needed: int = quest.game.total_words - quest.game.max_hp + 1
	var final_projectile_checked: bool = false
	for step in range(240):
		if quest.game.phase != "playing":
			break
		var prompt: Dictionary = quest.game.current_prompt()
		if quest.game.misses < misses_needed or prompt.is_empty():
			quest._process(0.25)
			continue
		quest._submit_text(str(prompt.text))
		if quest.game.targets.is_empty() and quest.game.spawned == quest.game.total_words:
			quest._process(0.01)
			check(quest.game.phase == "lost" and quest._impact_pending and not quest._loss.visible,
				"The result waits for an already earned final projectile to reach the monster")
			check(not quest._loss.pip.is_visible_in_tree(), "Pip's loss reaction waits until the final projectile settles")
			quest._spell_impact(int(prompt.uid))
			check(not quest._impact_pending and quest._display_hp == quest.game.hp and quest._loss.visible,
				"The final impact settles visible health before revealing the loss result")
			check(quest._loss.pip.is_visible_in_tree() and quest._loss.loss_emotion == "sad",
				"A new loss re-arms Pip's reaction after an earlier attempt")
			final_projectile_checked = true
			break
		quest._process(0.65)
	check(final_projectile_checked, "The finite word encounter exercises a near-win with a final in-flight attack")
	check(quest.game.phase == "lost" and quest.game.hp == 1 and quest._loss.visible
		and quest._loss.hits == quest.game.max_hp - 1 and quest._loss.remaining_hp == 1,
		"A near-win result reports earned hits and the exact remaining monster health")
	check(quest.game.total_clears == clears_before and quest.game.collected_chests == chests_before,
		"A near-win cannot award a clear or chest")
	quest._loss.map_button.pressed.emit()
	check(quest.view == "map" and not quest._loss.is_visible_in_tree() and not quest.game.has_saved_run(),
		"The result's map action leaves the exhausted encounter without creating a checkpoint")


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

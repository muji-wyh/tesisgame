extends SceneTree
## Render the real quest interface with all fourteen environments and responsive maps.

const Quest = preload("res://scripts/talk_quest.gd")
const OUTPUT := "res://build/talk-quest-words"
var quest: Control
var captures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(OUTPUT + "/" + name + ".png") != OK:
		printerr("Unable to capture " + name)
		quit(1)
		return
	captures += 1


func resize_to(dimensions: Vector2i) -> void:
	root.size = dimensions
	quest.position = Vector2(24, 24)
	quest.size = Vector2(dimensions) - Vector2(48, 48)
	await process_frame
	await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	quest = Quest.new()
	quest.save_path = "user://quest-visual-review-%d.cfg" % Time.get_ticks_usec()
	root.add_child(quest)
	quest.set_process(false)
	await resize_to(Vector2i(1280, 900))
	await capture("map-desktop")
	quest.game.unlocked_level = 14
	for number in range(1, 15):
		quest.start_level(number)
		quest.game.advance(2.8)
		quest._refresh_word_field()
		await create_timer(0.35).timeout
		await capture("scene-%02d" % number)
		quest.game.stop()
	quest.start_level(1)
	quest.game.advance(2.8)
	quest._refresh_word_field()
	await create_timer(0.2).timeout
	await capture("idle-a")
	await create_timer(0.4).timeout
	await capture("idle-b")
	quest._submit_text(quest.game.current_prompt().text)
	await create_timer(0.24).timeout
	await capture("word-spell")
	await create_timer(0.31).timeout
	await capture("impact")
	await create_timer(0.5).timeout
	await resize_to(Vector2i(390, 844))
	await capture("scene-phone")
	for number in [8, 11, 14]:
		quest.game.stop()
		quest.start_level(number)
		await create_timer(0.25).timeout
		await capture("scene-phone-%02d" % number)
	quest._show_map()
	quest._atlas.set_chapter(1)
	await capture("map-phone")
	await resize_to(Vector2i(320, 640))
	await capture("map-small")
	await resize_to(Vector2i(844, 390))
	await capture("map-landscape")
	await resize_to(Vector2i(320, 640))
	quest._continue_run()
	await capture("scene-small")
	quest.set_reduced_motion(true)
	await capture("reduced-motion")
	quest.set_reduced_motion(false)
	await resize_to(Vector2i(1280, 900))
	quest.game.stop()
	quest.start_level(1)
	while quest.game.phase == "playing":
		if quest.game.targets.is_empty():
			quest.game.advance(0.5)
			quest._refresh_word_field()
			continue
		quest._submit_text(quest.game.current_prompt().text)
		quest._process(0.6)
	quest._process(0.3)
	await create_timer(0.85).timeout
	await capture("victory")
	quest._process(2.0)
	await create_timer(1.5).timeout
	await capture("chest")
	quest.pause()
	var save_path: String = quest.save_path
	quest.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	print("Talk Quest polish: %d rendered captures" % captures)
	quit()

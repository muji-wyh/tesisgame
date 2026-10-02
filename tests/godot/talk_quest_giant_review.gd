extends SceneTree
## Capture the acquired giants in gameplay, including motion and small screens.

const Quest = preload("res://scripts/talk_quest.gd")
const OUTPUT := "res://build/talk-quest-giants/review"
var quest: Control
var captures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(OUTPUT + "/" + label + ".png") != OK:
		printerr("Unable to capture giant creature: " + label)
		quit(1)
		return
	captures += 1


func show_level(number: int) -> void:
	quest.game.stop()
	quest.start_level(number)
	quest.game.advance(2.8)
	quest._refresh_word_field()
	await create_timer(0.25).timeout


func resize_to(dimensions: Vector2i) -> void:
	root.size = dimensions
	quest.position = Vector2(16, 16)
	quest.size = Vector2(dimensions) - Vector2(32, 32)
	await process_frame
	await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	quest = Quest.new()
	quest.save_path = "user://quest-giant-review-%d.cfg" % Time.get_ticks_usec()
	root.add_child(quest)
	quest.set_process(false)
	quest.game.unlocked_level = 14
	await resize_to(Vector2i(1280, 900))
	for number: int in [1, 12, 14]:
		await show_level(number)
		await capture("desktop-%02d-idle" % number)
		await create_timer(0.48).timeout
		await capture("desktop-%02d-idle-b" % number)
		quest._monster.play_attack()
		await create_timer(0.30).timeout
		await capture("desktop-%02d-attack" % number)
		quest._monster.react_hit()
		await create_timer(0.15).timeout
		await capture("desktop-%02d-impact" % number)
		quest._monster.defeat()
		await create_timer(clampf(quest._monster.source_animation_duration("Defeat") * 0.5, 0.12, 1.0)).timeout
		await capture("desktop-%02d-defeat" % number)
	await resize_to(Vector2i(390, 844))
	for number: int in [1, 12, 14]:
		await show_level(number)
		await capture("phone-%02d" % number)
		quest._monster.play_attack()
		await create_timer(0.30).timeout
		await capture("phone-%02d-attack" % number)
		quest._monster.react_hit()
		await create_timer(0.15).timeout
		await capture("phone-%02d-impact" % number)
	await resize_to(Vector2i(844, 390))
	await show_level(14)
	await capture("landscape-14")
	await resize_to(Vector2i(320, 640))
	await show_level(1)
	quest.set_reduced_motion(true)
	await capture("small-reduced-motion")
	quest.pause()
	var save_path: String = quest.save_path
	quest.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	print("Talk Quest giants: %d rendered captures" % captures)
	quit()

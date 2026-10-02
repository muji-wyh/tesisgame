extends SceneTree
## Capture the real reward layout and the shared chest effects deterministically.

const Quest = preload("res://scripts/talk_quest.gd")
const Data = preload("res://scripts/talk_quest_data.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const OUTPUT := "res://build/talk-quest-reward"
var quest: Control
var captures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func capture(name: String) -> void:
	for frame in range(2):
		await process_frame
		await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUTPUT + "/" + name + ".png") != OK:
		printerr("Unable to capture " + name)
		quit(1)
		return
	captures += 1


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
	quest.save_path = "user://quest-reward-visual-%d.cfg" % Time.get_ticks_usec()
	root.add_child(quest)
	await resize_to(Vector2i(1280, 900))
	quest.start_level(1)
	while quest.game.phase == "playing":
		quest.game.submit_transcript(quest.game.current_prompt().text)
	quest.game.finish_victory()
	quest._banner.text = quest.game.current_chest().name
	quest._refresh()
	quest.set_process(false)
	quest._chest.set_process(false)
	await capture("desktop-idle")
	quest.start_chest_hold()
	quest._advance_chest_hold(0.6)
	await capture("desktop-holding")
	quest._advance_chest_hold(0.6)
	quest._chest._advance_animation(1.0)
	await capture("desktop-gathering")
	quest._chest._advance_animation(Feel.RELEASE_TIME - 1.02)
	await capture("desktop-anticipation")
	quest._chest._advance_animation(0.08)
	await capture("desktop-release")
	quest._chest._advance_animation(Feel.OPEN_SECONDS)
	await capture("desktop-opened")
	await resize_to(Vector2i(390, 844))
	await capture("phone-opened")
	for data: Dictionary in Data.chests():
		quest._chest.configure(data)
		quest._chest.set_process(false)
		quest._banner.text = data.name
		quest._chest.set_preview_time(Feel.RELEASE_TIME + 0.06)
		await capture("phone-release-%02d" % int(quest._chest.chest_index))
	quest._chest.configure(Data.chest("chest-01"))
	quest._chest.set_process(false)
	quest._chest.set_preview_time(Feel.OPEN_SECONDS)
	await resize_to(Vector2i(320, 640))
	await capture("small-opened")
	quest.pause()
	var save_path: String = quest.save_path
	quest.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	print("Talk Quest rewards: %d rendered captures" % captures)
	quit()

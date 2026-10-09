extends SceneTree
## Render every main page with isolated saves and the real production scene.

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const OUTPUT := "res://build/presentation-review"
var directory := ""
var captures := 0

func _initialize() -> void:
	_run.call_deferred()

func capture(label: String) -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png") == OK)
	captures += 1

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Visual review needs a real renderer")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	directory = "user://presentation-review-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for layout in [{"name": "desktop", "size": Vector2i(1280, 800)}, {"name": "phone", "size": Vector2i(390, 844)}]:
		root.size = layout.size
		var app = load("res://scenes/main.tscn").instantiate()
		Fixture.install(app, directory, str(layout.name) + ".cfg")
		app.pop_reward_save_path = directory + "/" + str(layout.name) + "-pop-rewards.cfg"
		app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
		root.add_child(app)
		app.audio.set_muted(true)
		app.set_reduced_motion(true)
		app.choose_theme("spring")
		app.new_round(105)
		var prefix: String = str(layout.name) + "-"
		await capture(prefix + "match")
		app._show_mode_menu()
		await capture(prefix + "library")
		app._hide_mode_menu()
		app.choose_mode("memory")
		await capture(prefix + "memory")
		app._show_collection()
		await capture(prefix + "growth")
		app._hide_collection()
		app.choose_mode("match")
		for word: Dictionary in app.model.lesson_words:
			app.model.select(str(word.id) + ":word")
			app.model.select(str(word.id) + ":image")
			app.model.resolve_feedback()
		await capture(prefix + "match-reward")
		app.new_round(105)
		app.choose_mode("pop")
		Fixture.choose_pop_player(app)
		await capture(prefix + "microphone")
		app._pop.set_listening(true, true, "Listening.")
		app._pop.set_process(false)
		app._pop._advance_game(1.0)
		await capture(prefix + "voice-pop")
		app._pop._advance_game(app._pop.game.remaining + 1)
		await capture(prefix + "voice-pop-result")
		app._round_result["chest_count"] = 2
		app._show_pop_rewards()
		await capture(prefix + "voice-pop-treasures")
		app._hide_pop_rewards()
		app.queue_free()
		await process_frame
	var library = load("res://scripts/game_library.gd").new()
	root.add_child(library)
	for layout in [{"name": "small", "size": Vector2i(320, 320)}, {"name": "landscape", "size": Vector2i(844, 390)}]:
		root.size = layout.size
		library.configure("match", true, true)
		library.fit(Vector2(layout.size) - Vector2(24, 24), 1.0)
		for frame in range(8):
			await process_frame
		library.fit(Vector2(layout.size) - Vector2(24, 24), 1.0)
		library.position = (Vector2(layout.size) - library.size) * 0.5
		await capture(str(layout.name) + "-library")
	library.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Presentation visual review: %d rendered captures" % captures)
	quit()

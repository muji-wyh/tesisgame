extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Progress = preload("res://scripts/medal_progress.gd")
const Context = preload("res://scripts/learning_context.gd")

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
	root.size = Vector2i(390, 844)
	var directory: String = "user://learning-context-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The flow fixture owns separate saves")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.save_preferences()
	root.add_child(app)
	await settle()
	check(app._round_context == Context.growth(3, "match"), "Startup freezes the real Growth learning context")
	var all_words: Array = app.data.words.duplicate(true)
	var cat: Dictionary = {}
	for word in all_words:
		if word.id == "cat":
			cat = word
			break
	app.data.words = [cat]
	for mode in ["jelly", "word_jelly", "pop"]:
		check(app.new_round(42, false, "", mode), "A one-term %s round does not require a Match lesson" % mode)
		check(app.model.cards.is_empty() and app.cards.is_empty(), "No hidden Match controls are built for %s" % mode)
		check(app._round_context == Context.growth(3, mode), "The %s round freezes its own mode" % mode)
	var round_id: String = app._round_id
	check(not app.new_round(42, false, "", "match"), "Insufficient Match content is rejected before replacing the current round")
	check(app._round_id == round_id and app._mode_id == "pop", "A failed eligibility preflight retains the active round identity")
	app.data.words = all_words
	check(app.new_round(42, false, "", "phrase"), "Phrase resolves its own lower-age dependencies")
	check(app._phrase.game.questions.size() == 3 and app.model.cards.is_empty(), "Phrase constructs questions without an invisible Match board")
	var before: Dictionary = app.growth.snapshot()
	app._round_context = Context.freeze(Context.professional("nursing", "module03", "professional-v1", "match"))
	app._record_growth("professional-fixture", ["cat"], true)
	check(app.growth.snapshot() == before, "A professional context can never write Growth evidence")
	app.audio.halt()
	app.queue_free()
	await settle()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Learning context flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

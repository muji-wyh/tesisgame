extends Node

# Load dependencies before their users so each script compiles in its own frame.
# Retain them until the main scene owns the preloads; the resource cache is weak.
const SCRIPTS := [
	"game_data", "ui_style", "game_model", "word_card", "game_audio",
	"chest_view", "celebration", "medal_view", "medal_progress", "duck_mascot",
	"word_lesson", "choice_game", "memory_game_model", "memory_garden",
	"playroom_state", "playroom_view", "adventure_book", "game_ui"
]


func _ready() -> void:
	# The first process_frame can still occur inside the engine's callMain.
	await get_tree().process_frame
	await get_tree().process_frame
	var scripts: Array[Resource] = []
	for id in SCRIPTS:
		var script: Script = load("res://scripts/%s.gd" % id)
		if script == null or not script.can_instantiate():
			_fail("The game could not load. Please try again.")
			return
		scripts.append(script)
		await get_tree().process_frame
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null or get_tree().change_scene_to_packed(scene) != OK:
		_fail("The game could not start. Please try again.")


func _fail(message: String) -> void:
	var host = JavaScriptBridge.get_interface("wordBuddiesHost")
	if host != null:
		host.fail(message)

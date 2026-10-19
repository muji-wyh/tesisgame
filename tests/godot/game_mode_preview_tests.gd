extends SceneTree

const Preview = preload("res://scripts/game_mode_preview.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in range(4):
		await process_frame

func _run() -> void:
	for mode: String in ["match", "memory", "pop", "phrase", "jelly", "word_jelly"]:
		var container := Control.new()
		container.hide()
		var preview := Preview.new()
		preview.configure(mode)
		container.add_child(preview)
		root.add_child(container)
		preview.set_reduced_motion(true)
		await settle()
		check(not preview.is_visible_in_tree(), "%s starts under an already-hidden parent" % mode)
		check(not preview.is_processing(), "%s hidden reduced-motion startup never processes" % mode)
		var initial: float = preview._elapsed
		await settle()
		check(is_equal_approx(preview._elapsed, initial), "%s hidden startup keeps its timeline still" % mode)
		container.show()
		await settle()
		check(not preview.is_processing(), "%s stays still when its reduced-motion parent opens" % mode)
		preview.set_reduced_motion(false)
		await settle()
		check(preview.is_processing(), "%s starts after motion is explicitly enabled" % mode)
		container.hide()
		await settle()
		check(not preview.is_processing(), "%s stops when its parent closes" % mode)
		container.free()
	print("Game mode preview tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

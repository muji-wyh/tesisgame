extends SceneTree

const Play = preload("res://scripts/professional_play.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _settle(play) -> void:
	for frame in range(60):
		await process_frame
		var state: Dictionary = play.session.snapshot()
		if frame >= 3 and (state.blocked or state.pending_count == 0):
			return
	check(false, "Professional recovery settles within a bounded number of frames")


func _run() -> void:
	var directory: String = "user://professional-play-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var unavailable: String = directory.path_join("unavailable")
	check(DirAccess.make_dir_absolute(directory) == OK, "Recovery regression uses isolated storage")
	var play := Play.new()
	root.add_child(play)
	check(play.configure(null, func(_id: String, _tier: int) -> Dictionary: return {"ok": true}, unavailable.path_join("progress.json")),
		"Professional preparation configures before its storage path becomes available")
	await _settle(play)
	check(play.phase == "failed" and play.session.snapshot().blocked, "An initial load failure exposes a retryable state")
	check(not play.session.snapshot().progress_loaded and play.active.is_empty() and play.pending.is_empty(),
		"An unavailable initial profile has no invented progress or playable round")
	check(DirAccess.make_dir_absolute(unavailable) == OK, "Restore the initial storage path")
	play.retry()
	check(play.phase == "restoring", "The initial load retry stays busy while recovery is pending")
	await _settle(play)
	var state: Dictionary = play.session.snapshot()
	check(play.phase == "idle" and play.error.is_empty() and not state.blocked and state.pending_count == 0,
		"Successful recovery without an active round returns Home to idle")
	check(state.progress_loaded and not state.ready and play.active.is_empty() and play.pending.is_empty(),
		"Recovery loads the profile without pretending a course is already prepared")
	check(not play.can_play(""), "An idle recovered profile still requires a real round source")
	play.queue_free()
	await process_frame
	check(DirAccess.remove_absolute(unavailable) == OK and DirAccess.remove_absolute(directory) == OK,
		"Remove the isolated recovery fixture")
	print("Professional play: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

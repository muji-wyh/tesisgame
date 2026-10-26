extends SceneTree

const Effects = preload("res://scripts/word_jelly_collection_fx.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var board = Effects.new()
	root.add_child(board)
	check(board.has_method("set_board_burst"), "The board has a compact burst-only preset separate from the popover")
	if not board.has_method("set_board_burst"):
		board.free()
		print("Jelly board bursts: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	var popover = Effects.new()
	root.add_child(popover)
	var pitch: float = 64.0
	for level in range(4, 10):
		board.reset()
		popover.reset()
		board.configure_layout(Rect2(0, 0, 960, 720), 1.0)
		popover.configure_layout(Rect2(0, 0, 960, 720), 1.0)
		board.call("set_board_burst", pitch)
		board.present(Vector2(480, 360), level, Color.WHITE)
		popover.present(Vector2(480, 360), level, Color.WHITE)
		var compact: Dictionary = board.snapshot().entries[0]
		var large: Dictionary = popover.snapshot().entries[0]
		check(compact.get("burst_only", false) and float(compact.duration) < 0.9
			and float(compact.get("radius", INF)) < pitch * 0.6,
			"Lv%d board explosion stays close to its own jelly and finishes before a falling tail" % level)
		check(not large.get("burst_only", false) and float(large.duration) >= 2.8,
			"The separate top-popover retains its full large firework profile")
		var burst: Dictionary = board._entries[0]
		check(board._phase(burst, float(burst.duration) * 0.85) != "falling_embers",
			"The board never switches into the unwanted falling-ember phase")
		var before: Vector2 = board.call("_firework_trajectory", 0.0, 0.15, 0.5, 30.0, level, true)
		var after: Vector2 = board.call("_firework_trajectory", 0.0, 0.65, 0.5, 30.0, level, true)
		check(is_zero_approx(before.y) and is_zero_approx(after.y) and after.x > before.x,
			"The board trajectory really expands outward without a gravity-driven descent")
		board.advance(0.95)
		check(board.snapshot().active_count == 0 and popover.snapshot().active_count == 1,
			"Trimming the board tail does not prematurely end its independent popover")
	board.free()
	popover.free()
	print("Jelly board bursts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree

const Jelly = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
const GrowthMorphology = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0
var cues: Array[String] = []
var attempts: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _advance(view, seconds: float) -> void:
	while seconds > 0.00001:
		var step: float = minf(seconds, 0.025)
		view._process(step)
		seconds -= step

func _install(view, tiles: Array) -> void:
	view.game.cells.clear()
	for index in range(tiles.size()):
		tiles[index].column = index
		tiles[index].row = 7
		tiles[index].age = view.game.SETTLE_SECONDS
		tiles[index].settling = false
		tiles[index].falling = false
		tiles[index].arrival = false
		view.game.cells.append(tiles[index])
	view._sync_tiles()
	view._layout()
	# Reusing an existing body at a new fixture column starts its normal reflow.
	# Let that real presentation settle before reading pointer coordinates.
	_advance(view, view.game.SETTLE_SECONDS + 0.05)

func _drag(view, first: int, second: int) -> void:
	var from: Vector2 = view._tiles[first].get_global_rect().get_center()
	var to: Vector2 = view._tiles[second].get_global_rect().get_center()
	check(from.distance_to(to) > 7.0, "The drag fixture has distinct displayed source and target positions")
	check(view._press(-1, from), "The root or merged Jelly can be picked up")
	view._move(to)
	check(view._dragging and view._target == second, "A dragged body contacts the intended partner")
	view._release(to)
	_advance(view, 1.1)

func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Production vocabulary and art load")
	var cat: Dictionary
	for word: Dictionary in data.words:
		if word.id == "cat":
			cat = GrowthMorphology.decorate(word)
	var view := Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(1000, 720)
	view.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	view.word_attempted.connect(func(id: String, _ids: Array[String], correct: bool) -> void:
		if correct: attempts.append(id))
	check(view.configure([cat], 3, Data.theme("spring"), data.chests, false, 42), "Hybrid view configures")
	view.game.spawn_interval = 10000.0
	var root_tile: Dictionary = view.game._new_composition_tile(view.game._morphology.source_tiles(cat.morphology.id)[0])
	var picture: Dictionary = view.game._new_picture_tile(cat)
	_install(view, [root_tile, picture])
	var before: Dictionary = view.snapshot()
	check(before.tiles[0].label_visible and not before.tiles[0].picture_visible, "A root shows only text")
	check(not before.tiles[1].label_visible and before.tiles[1].picture_visible, "A picture shows only artwork")
	view._show_read(int(picture.id))
	check(not view._read_panel.visible, "Picture Read cannot expose the matching word")
	_drag(view, int(root_tile.id), int(picture.id))
	check(view.game.cells.size() == 1 and view.game.cells[0].jelly_kind == "merged", "Dragging word onto picture creates a merged Jelly")
	var merged: Dictionary = view.game.cells[0]
	check(view._tiles[int(merged.id)]._picture.visible and view._tiles[int(merged.id)]._label.visible, "Merged Jelly displays picture and word")
	check(attempts.is_empty(), "Picture fusion does not prematurely grant mastery")
	var second: Dictionary = merged.duplicate(true)
	second.id = view.game._next_tile_id
	view.game._next_tile_id += 1
	_install(view, [merged, second])
	_drag(view, int(merged.id), int(second.id))
	check(view.game.cells.size() == 1 and view.game.cells[0].merge_level == 2, "Dragging identical Lv1 Jellies upgrades to Lv2")
	merged = view.game.cells[0]
	check(view._tiles[int(merged.id)].presentation_snapshot().level_badge == "2", "Lv2 badge is visible")
	check(attempts.is_empty(), "Upgrade does not prematurely grant mastery")
	# The same actual tile is promoted for focused presentation checks; model
	# tests separately prove every legal upgrade and the Lv9 cap.
	for level in range(1, 10):
		var tile: Dictionary = merged.duplicate(true)
		tile.id = view.game._next_tile_id
		view.game._next_tile_id += 1
		tile.merge_level = level
		_install(view, [tile])
		cues.clear()
		var previous_attempts: int = attempts.size()
		view._collect(int(tile.id))
		check(view._collection_effects.snapshot().active_count == 1, "Lv%d schedules one collection effect" % level)
		_advance(view, 0.19)
		check(cues.has("pop" if level == 1 else "jelly-collect-lv%d" % level), "Lv%d sound follows collection pop" % level)
		_advance(view, 0.35)
		check(view.game.cells.is_empty() and attempts.size() == previous_attempts + 1, "Lv%d collection credits once" % level)
		view.pause(true)
		check(view._collection_effects.snapshot().active_count == 0, "Pause clears Lv%d visual tail" % level)
		view.pause(false)
	var no_picture: Dictionary = cat.duplicate(true)
	no_picture.image = ""
	check(view.configure([no_picture], 3, Data.theme("spring"), data.chests, true, 43), "Image-free word configures")
	view.game.spawn_interval = 10000.0
	var ready: Dictionary = view.game.cells[0]
	check(ready.jelly_kind == "merged", "Image-free whole word arrives ready")
	view._collect(int(ready.id))
	check(view._word_reveal.snapshot().visible and view._word_reveal.snapshot().spelling == "cat", "Image-free collection still presents readable spelling")
	_advance(view, 0.5)
	view.stop()
	check(view._collection_effects.snapshot().active_count == 0, "Stop clears all effects")
	view.free()
	print("Word Jelly hybrid view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree

const AmbientBudget = preload("res://scripts/word_jelly_ambient_budget.gd")
const WordArt = preload("res://scripts/word_art.gd")
const WordTile = preload("res://scripts/word_jelly_tile.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixture = preload("res://tests/performance/jelly_drag_fixture.gd")
const JellyView = preload("res://scripts/word_jelly.gd")
const Model = preload("res://scripts/word_jelly_model.gd")

class BudgetOwner extends Control:
	var tile_id: int = -1
	var animated: bool = true

	func set_ambient_animation(enabled: bool) -> void:
		animated = enabled


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
	root.size = Vector2i(1100, 800)
	_check_cohort()
	_check_duplicate_pictures()
	_check_merged_motion()
	_check_board_updates()
	print("Word Jelly ambient budget: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_cohort() -> void:
	var budget = AmbientBudget.new()
	var owners: Array[BudgetOwner] = []
	for id in range(9):
		var tile := BudgetOwner.new()
		tile.tile_id = id
		root.add_child(tile)
		owners.append(tile)
		budget.register(tile)
	var first: Array[int] = budget.animated_ids()
	check(first.size() == AmbientBudget.IDLE_SLOTS, "A crowded board animates only three idle owners")
	budget.advance(0.01)
	check(budget.advance(0.01).is_empty(), "Steady frames produce no owner transitions")
	for tick in range(30):
		budget.advance(0.1)
	var rotated: Array[int] = budget.animated_ids()
	check(rotated.size() == AmbientBudget.IDLE_SLOTS and rotated != first, "The bounded cohort rotates to other idle owners")
	budget.set_priority(8, true)
	check(owners[8].animated and budget.animated_ids().size() == AmbientBudget.IDLE_SLOTS + 1,
		"An active owner bypasses the idle limit immediately")
	owners[7].mouse_entered.emit()
	check(owners[7].animated, "Native hover enables motion without waiting for a board tick")
	owners[7].focus_entered.emit()
	owners[7].mouse_exited.emit()
	check(owners[7].animated, "Keyboard focus retains priority after the pointer leaves")
	owners[7].focus_exited.emit()
	budget.set_priority(8, false)
	check(budget.animated_ids().size() == AmbientBudget.IDLE_SLOTS, "Ending interaction restores the idle budget")
	budget.set_playing(false)
	check(budget.animated_ids().is_empty(), "Pause and background state suspend all cohort motion")
	budget.set_priority(8, true)
	check(not owners[8].animated, "Pointer and gameplay priorities cannot animate a paused board")
	budget.set_playing(true)
	check(owners[8].animated, "Resuming restores an active interaction immediately")
	budget.set_reduced_motion(true)
	check(budget.animated_ids().is_empty(), "Reduced motion keeps every idle and priority owner still")
	budget.set_reduced_motion(false)
	check(owners[8].animated, "Leaving reduced motion restores active feedback")
	owners[0].free()
	for tick in range(30):
		budget.advance(0.1)
	check(not budget.animated_ids().has(0), "Freed weak owners disappear safely on the next cohort rotation")
	budget.unregister(8)
	check(not owners[8].animated and not budget.animated_ids().has(8), "Unregistering removes priority and disables the old owner")
	budget.clear()
	check(budget.animated_ids().is_empty() and owners[1].get_signal_connection_list("mouse_entered").is_empty(),
		"Disposal clears membership and disconnects native interaction callbacks")
	for index in range(1, owners.size()):
		owners[index].free()


func _picture() -> TextureRect:
	var result := TextureRect.new()
	root.add_child(result)
	result.size = Vector2(128, 128)
	result.texture = WordArt.texture("res://assets/images/word-library/apple.webp", result)
	return result


func _check_duplicate_pictures() -> void:
	WordArt.set_reduced_motion(false)
	var first := _picture()
	var second := _picture()
	var outside := _picture()
	var canonical: Texture2D = first.texture
	check(first.texture == second.texture and canonical == outside.texture, "Unbudgeted views retain their shared animated wrapper")
	WordArt.set_owner_animation(first, false)
	WordArt.set_owner_animation(second, false)
	var poster := first.texture as AtlasTexture
	var poster_region: Rect2 = poster.region
	check(poster != canonical and second.texture == poster and poster.atlas.get_size() == Vector2(128, 128),
		"Duplicate settled owners share a separate small poster wrapper")
	for tick in range(4):
		WordArt.advance(0.1)
	check(poster.region == poster_region and poster.atlas.get_size() == Vector2(128, 128)
		and outside.texture == canonical and (canonical as AtlasTexture).atlas.get_width() > 128,
		"A live duplicate cannot animate frozen owners through its shared atlas")
	WordArt.set_owner_animation(first, true)
	check(first.texture == canonical and second.texture == poster
		and WordArt.source_path(first.texture) == WordArt.source_path(second.texture),
		"Priority reactivation retains the exact word and leaves other owners frozen")
	check(not WordArt.set_owner_animation(first, true), "Repeating the same owner state does not replace resources")
	first.free()
	second.free()
	outside.free()
	canonical = null
	poster = null
	WordArt.advance(0.1)


func _check_merged_motion() -> void:
	var data = Data.new()
	check(data.load_all(), "Merged motion uses the production word and acquired gel artwork")
	var word: Dictionary = {}
	for candidate: Dictionary in data.words:
		if candidate.id == "apple":
			word = candidate
			break
	var tiles: Array = []
	for id in range(2):
		var tile = WordTile.new()
		tile.tile_id = id + 20
		root.add_child(tile)
		tile.size = Vector2(120, 120)
		tile.configure({"id": id + 20, "kind": "word", "jelly_kind": "merged", "word": word, "text": "apple", "mass": 2},
			load("res://assets/images/jelly-match/gel-mint.png"),
			WordArt.texture("res://assets/images/word-library/apple.webp"), null, Color.WHITE)
		tile.set_merged_presentation(1.2, false)
		tiles.append(tile)
	check(tiles[0]._merged_glow.material == tiles[1]._merged_glow.material,
		"Constant readiness light materials are shared across merged bodies")
	var tile = tiles[0]
	tile.set_ambient_animation(false)
	var still_pose: Vector2 = tile._merged_glints[0].scale
	tile.set_merged_presentation(9.8, false)
	check(tile._merged_glints[0].scale == still_pose and tile._gel.get_shader_parameter("completion_glint") == -2.0,
		"Noncohort merged bodies retain a stable accent and disable their gel sweep")
	check(tile._picture_shadow.texture == tile._picture.texture and tile._picture.texture.has_meta("word_art_frozen"),
		"Picture shadows follow an owner poster swap without a position update")
	tile.set_ambient_animation(true)
	check(tile._picture_shadow.texture == tile._picture.texture and not tile._picture.texture.has_meta("word_art_frozen")
		and tile._gel.get_shader_parameter("completion_glint") != -2.0,
		"Active merged feedback resumes both the picture and sourced gel sweep")
	for entry: Control in tiles:
		entry.free()


func _frames(view, count: int, delta: float = 1.0 / 60.0) -> void:
	for frame in range(count):
		WordArt.advance(delta, view._can_play())
		view._process(delta)


func _grid_matches(view) -> bool:
	for cell: Dictionary in view.game.cells:
		var tile = view._tiles[int(cell.id)]
		if not tile.get_rect().is_equal_approx(view._tile_rect(cell)):
			return false
	return true


func _check_board_updates() -> void:
	var data = Data.new()
	check(data.load_all(), "Dirty-view regression uses production game data")
	var view = JellyView.new()
	root.add_child(view)
	view.size = Vector2(1366, 768)
	var pair: Array[int] = Fixture.install(view, data, 49)
	check(view.has_method("presentation_work_snapshot"), "The view exposes cumulative presentation work for regression checks")
	if not view.has_method("presentation_work_snapshot"):
		view.free()
		return
	_frames(view, 60)
	var before: Dictionary = view.presentation_work_snapshot()
	var first_age: float = float(view.game.cells[0].age)
	var clock: float = view._presentation_elapsed
	var spawn_clock: float = view.game.spawn_elapsed
	_frames(view, 20)
	var after: Dictionary = view.presentation_work_snapshot()
	check(int(after.tiles_posed) == int(before.tiles_posed),
		"An untouched settled 49-body board performs no repeated tile geometry writes")
	check(float(view.game.cells[0].age) > first_age and view.game.spawn_elapsed > spawn_clock
		and view._presentation_elapsed > clock and view.game.cells.size() == 49,
		"Skipping settled geometry preserves model ages, spawn cadence and the presentation clock")
	var hovered: int = int(view.game.cells[47].id)
	var hover := InputEventMouseMotion.new()
	hover.position = view._tiles[hovered].get_global_rect().get_center()
	view._input(hover)
	check(view._ambient_budget.animated_ids().has(hovered),
		"Mouse hover on a real picture owner bypasses the idle cohort immediately")
	hover.position = Vector2(-100, -100)
	view._input(hover)
	_frames(view, 1)
	check(not view._ambient_budget.animated_ids().has(hovered),
		"Moving off the board releases logical pointer-hover priority")
	var first = view._tiles[pair[0]]
	var old_rect: Rect2 = first.get_rect()
	view._begin_view_update()
	view._sync_positions()
	view.size = Vector2(1440, 900)
	view._layout()
	check(not first.get_rect().is_equal_approx(old_rect)
		and view._view_update_active and _grid_matches(view),
		"An in-pass resize immediately moves every settled body to its current reserved rectangle")
	check(view._tile_at(first.get_rect().get_center()) == int(first.tile_id),
		"The resized body's visible center is a working hit target before the next frame")
	view._end_view_update()
	view.apply_theme(Data.theme("summer"), data.chests)
	check(first._picture_shadow.texture == first._picture.texture and not first._label.text.is_empty()
		and view._theme.name == "Summer",
		"Theme refresh retains the learning face and picture-shadow texture identity")
	view.set_reduced_motion(true)
	check(view._ambient_budget.animated_ids().is_empty(), "Reduced motion immediately suspends a real board's ambient cohort")
	view.set_reduced_motion(false)
	_frames(view, 1)
	check(view._ambient_budget.animated_ids().size() == AmbientBudget.IDLE_SLOTS,
		"Leaving reduced motion restores only the bounded idle cohort")
	view.pause(true)
	first_age = float(view.game.cells[0].age)
	_frames(view, 2)
	check(view._ambient_budget.animated_ids().is_empty() and float(view.game.cells[0].age) == first_age,
		"A paused real board suspends both ambient owners and model time")
	view._begin_view_update()
	view._sync_positions()
	view.size = Vector2(1000, 720)
	view._layout()
	check(view._view_update_active and _grid_matches(view) and float(view.game.cells[0].age) == first_age,
		"A paused in-pass resize updates every body immediately without advancing the model")
	view._end_view_update()
	view.pause(false)
	_frames(view, 1)
	check(float(view.game.cells[0].age) > first_age and not view._ambient_budget.animated_ids().is_empty(),
		"Resume restores the model and selected ambient motion")
	var start: Vector2 = view._tiles[pair[0]].get_global_rect().get_center()
	check(view._press(7, start), "The resting cached board can still pick up a real word")
	_frames(view, 1)
	check(view._tiles[pair[1]].completion_hint and view._ambient_budget.animated_ids().has(pair[1]),
		"A matching teaching target receives immediate hint feedback outside the idle budget")
	view.cancel_input()
	_frames(view, 1)
	check(not view._tiles[pair[1]].completion_hint
		and view._ambient_budget.animated_ids().size() == AmbientBudget.IDLE_SLOTS,
		"Cancelling a teaching hint releases its priority and restores the ordinary cohort")
	start = view._tiles[pair[0]].get_global_rect().get_center()
	check(view._press(7, start), "A second pointer gesture starts after hint cancellation")
	Fixture.motion(view, start + Vector2(40, 0))
	var target: Vector2 = view._tiles[pair[1]].get_global_rect().get_center()
	view._release(target)
	check(view.game.fusions.size() == 1 and str(view.game.fusions[0].operation) == "merge"
		and view._pointer == view.NO_POINTER and not view._motion_pending,
		"Pointer-up before the next presentation frame still merges the correct real word-picture pair")
	Fixture.install(view, data, Model.INITIAL_SETTLED_TILES)
	var known: Dictionary = {}
	for cell: Dictionary in view.game.cells:
		known[int(cell.id)] = true
	check(view.game.drop_now(), "The optimized board still accepts a genuine supply drop")
	var arrivals: Array[int] = []
	for cell: Dictionary in view.game.cells:
		if not known.has(int(cell.id)):
			arrivals.append(int(cell.id))
	check(not arrivals.is_empty(), "Supply creates actual new model and presentation owners")
	_frames(view, 1)
	var airborne: Array[int] = []
	for id: int in arrivals:
		if view._tiles.has(id) and view._tiles[id].is_visible_in_tree() and not view.game.is_settled(view.game.cell(id)):
			airborne.append(id)
	check(not airborne.is_empty() and airborne.all(func(id: int) -> bool: return view._ambient_budget.animated_ids().has(id)),
		"Every airborne supply owner receives unbudgeted motion feedback")
	var settling_seconds: float = 0.0
	for id: int in arrivals:
		var cell: Dictionary = view.game.cell(id)
		settling_seconds = maxf(settling_seconds, Model.settle_duration(cell) - float(cell.age))
	_frames(view, ceili((settling_seconds + 0.1) * 60.0))
	var settled: bool = true
	for id: int in arrivals:
		settled = settled and view.game.is_settled(view.game.cell(id)) \
			and view._tiles[id].get_rect().is_equal_approx(view._tile_rect(view.game.cell(id)))
	check(settled,
		"Spawn and settling finish at their exact reserved board rectangles")
	view.stop()
	check(view._ambient_budget.animated_ids().is_empty() and view._tiles.is_empty(),
		"Stopping a real game removes every old owner and budget membership")
	view.free()

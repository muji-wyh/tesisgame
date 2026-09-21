extends SceneTree

var checks := 0
var failures := 0
var coverage := {2: {"aligned": false, "offset": false}, 4: {"aligned": false, "offset": false}}


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func global_path(link) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in link.path:
		result.append(link.get_global_transform() * point)
	return result


func same_path(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if not first[index].is_equal_approx(second[index]):
			return false
	return true


func crosses_rect(first: Vector2, second: Vector2, bounds: Rect2) -> bool:
	if bounds.has_point(first) or bounds.has_point(second):
		return true
	var corners := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	for edge in range(4):
		if Geometry2D.segment_intersects_segment(first, second, corners[edge], corners[(edge + 1) % 4]) != null:
			return true
	return false


func check_link(app, image_id: String, word_id: String, columns: int, stage: String) -> void:
	var link = app._hint_link
	check(app.grid.columns == columns, stage + ": the real board uses the expected column count")
	check(link.active and link.is_visible_in_tree() and link.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		stage + ": the active link stays visible without blocking card input")
	check(link.source == app.cards[image_id] and link.target == app.cards[word_id],
		stage + ": direction always runs from picture to word, regardless of hint order")
	var points: PackedVector2Array = global_path(link)
	check(points.size() >= 2, stage + ": the link has a drawable path")
	if points.size() < 2:
		return
	var picture: Rect2 = app.cards[image_id].get_global_rect()
	var word: Rect2 = app.cards[word_id].get_global_rect()
	var first: Vector2 = points[0]
	var last: Vector2 = points[points.size() - 1]
	var vertical: bool = columns == 2
	var low: float = picture.end.x if vertical else picture.end.y
	var high: float = word.position.x if vertical else word.position.y
	check(absf((first.x if vertical else first.y) - low) <= 1.0
		and picture.grow(1.0).has_point(first), stage + ": the path starts on the picture's facing edge")
	check(absf((last.x if vertical else last.y) - high) <= 1.0
		and word.grow(1.0).has_point(last), stage + ": the path ends on the word's facing edge")
	var inside_gutter := true
	var inside_board := true
	for point in points:
		var across: float = point.x if vertical else point.y
		inside_gutter = inside_gutter and across >= low - 1.0 and across <= high + 1.0
		inside_board = inside_board and app._match_playfield.get_global_rect().grow(1.0).has_point(point)
	check(high > low and inside_gutter, stage + ": every segment stays in the central " + ("vertical" if vertical else "horizontal") + " gutter")
	check(inside_board, stage + ": the entire link remains inside the board")
	for id in app.cards:
		if id == image_id or id == word_id:
			continue
		var interior: Rect2 = app.cards[id].get_global_rect().grow(-1.0)
		var crossed := false
		for index in range(1, points.size()):
			crossed = crossed or crosses_rect(points[index - 1], points[index], interior)
		check(not crossed, stage + ": the link never crosses unrelated card " + id)
	var offset: float = picture.get_center().y - word.get_center().y if vertical else picture.get_center().x - word.get_center().x
	coverage[columns]["aligned" if absf(offset) <= 1.0 else "offset"] = true


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 900)
	var directory := "user://hint-link-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	for seed_value in range(8):
		app.new_round(seed_value, false, "", "match")
		await settle()
		check(app.grid.get_child_count() == 8 and app._hint_link is Control,
			"The real board keeps eight cards and one independent link control")
		for data in app.model.cards:
			var word_id: String = data.word.id + ":word"
			if data.kind != "image" or not app.cards.has(word_id):
				continue
			var image_id: String = data.id
			root.size = Vector2i(480, 900)
			app.model.hint_ids.assign([word_id, image_id])
			app.model.changed.emit()
			await settle()
			var stage: String = "Seed %d %s" % [seed_value, data.word.id]
			check_link(app, image_id, word_id, 2, stage + " portrait, reversed hint")
			var portrait_path: PackedVector2Array = global_path(app._hint_link)
			app.model.hint_ids.assign([image_id, word_id])
			app.model.changed.emit()
			await settle()
			check(same_path(global_path(app._hint_link), portrait_path),
				stage + ": swapping hint order leaves the picture-to-word geometry unchanged")
			var image_instance: int = app.cards[image_id].get_instance_id()
			var word_instance: int = app.cards[word_id].get_instance_id()
			root.size = Vector2i(900, 480)
			await settle()
			check_link(app, image_id, word_id, 4, stage + " landscape after resize")
			check(app.model.hint_ids == [image_id, word_id]
				and app.cards[image_id].get_instance_id() == image_instance
				and app.cards[word_id].get_instance_id() == word_instance,
				stage + ": resize preserves the active hint and both existing cards")
			check(not same_path(global_path(app._hint_link), portrait_path),
				stage + ": resize updates endpoints automatically without manually refreshing geometry")
		if coverage[2].aligned and coverage[2].offset and coverage[4].aligned and coverage[4].offset:
			break
	for columns in [2, 4]:
		check(coverage[columns].aligned and coverage[columns].offset,
			"%d-column fixtures cover both aligned pairs and pairs in different rows or columns" % columns)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Hint link geometry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

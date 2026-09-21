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


func facing_boundary(bounds: Rect2, other_center: Vector2) -> Vector2:
	var corners := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	for edge in range(4):
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			bounds.get_center(), other_center, corners[edge], corners[(edge + 1) % 4])
		if intersection != null:
			return intersection
	return Vector2(INF, INF)


func check_link(app, image_id: String, word_id: String, columns: int, stage: String) -> void:
	var link = app._hint_link
	check(app.grid.columns == columns, stage + ": the real board uses the expected column count")
	check(link.active and link.is_visible_in_tree() and link.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		stage + ": the active link stays visible without blocking card input")
	check(link.source == app.cards[image_id] and link.target == app.cards[word_id],
		stage + ": direction always runs from picture to word, regardless of hint order")
	var points: PackedVector2Array = global_path(link)
	check(points.size() == 2, stage + ": one direct segment joins the cards without gutter detours")
	if points.size() != 2:
		return
	var picture: Rect2 = app.cards[image_id].get_global_rect()
	var word: Rect2 = app.cards[word_id].get_global_rect()
	var first: Vector2 = points[0]
	var last: Vector2 = points[1]
	var axis: Vector2 = (word.get_center() - picture.get_center()).normalized()
	var pixel_scale: float = app.Style.ui_scale(link)
	check(picture.has_point(first) and word.has_point(last),
		stage + ": the electricity reaches inside both intended cards")
	check(absf((first - picture.get_center()).cross(axis)) * pixel_scale <= 0.5
		and absf((last - word.get_center()).cross(axis)) * pixel_scale <= 0.5,
		stage + ": both endpoints lie on the picture-to-word center axis")
	check((first - picture.get_center()).dot(axis) > 0.0
		and (word.get_center() - last).dot(axis) > 0.0 and (last - first).dot(axis) > 0.0,
		stage + ": the segment connects the facing halves of the cards in picture-to-word order")
	var picture_edge: Vector2 = facing_boundary(picture, word.get_center())
	var word_edge: Vector2 = facing_boundary(word, picture.get_center())
	check(picture_edge.is_finite() and word_edge.is_finite(),
		stage + ": the center ray crosses both card boundaries")
	check(absf(first.distance_to(picture_edge) * pixel_scale - 18.0) <= 1.0
		and absf(last.distance_to(word_edge) * pixel_scale - 18.0) <= 1.0,
		stage + ": endpoints extend about 18 screen pixels inside each facing boundary")
	var board: Rect2 = app._match_playfield.get_global_rect().grow(1.0)
	check(board.has_point(first) and board.has_point(last), stage + ": the direct link remains inside the board")
	var offset: float = picture.get_center().y - word.get_center().y if columns == 2 else picture.get_center().x - word.get_center().x
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

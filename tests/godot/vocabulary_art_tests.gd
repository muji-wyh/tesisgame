extends SceneTree

const Data = preload("res://scripts/game_data.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	var data := Data.new()
	check(data.load_all(), "The shared production vocabulary loads: " + data.error)
	var reviewed := 0
	var contextual := 0
	var ages: Dictionary = {}
	for word in data.words:
		var age: int = int(word.min_age)
		if not ages.has(age):
			ages[age] = {"pictures": 0, "contextual": 0}
		if word.image.is_empty():
			contextual += 1
			ages[age].contextual += 1
			check(word.practice_modes == ["phrase"], "Context-only words retain phrase practice: " + str(word.id))
			check(not ResourceLoader.exists("res://assets/images/word-library/%s.webp" % word.id), "Context-only words do not gain an arbitrary picture: " + str(word.id))
			continue
		reviewed += 1
		ages[age].pictures += 1
		check(word.image == "assets/images/word-library/%s.webp" % word.id, "Every mode and catalogue receives the reviewed picture: " + str(word.id))
		check(word.art_key == "library/" + str(word.id), "The active provenance key identifies the shared library: " + str(word.id))
		var texture: Texture2D = load("res://" + word.image)
		check(texture != null and texture.get_size() == Vector2(256, 256), "The reviewed picture keeps its source dimensions: " + str(word.id))
		if texture == null:
			continue
		var image: Image = texture.get_image()
		if image.is_compressed():
			image.decompress()
		var bounds: Rect2i = image.get_used_rect()
		check(bounds.has_area(), "The reviewed image is visible: " + str(word.id))
		check(bounds.position.x >= 10 and bounds.position.y >= 10 and bounds.end.x <= 246 and bounds.end.y <= 246,
			"Transparent margins keep artwork away from card edges: " + str(word.id))
		check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(255, 0).a == 0.0 and image.get_pixel(0, 255).a == 0.0 and image.get_pixel(255, 255).a == 0.0,
			"The shared picture blends onto cards without a backplate: " + str(word.id))
	check(reviewed == 1285 and contextual == 265, "The complete library retains 1285 pictures and 265 context-only words")
	check(ages.size() == 10, "The artwork review covers every age from three through twelve plus")
	for age in range(3, 13):
		check(ages.has(age) and int(ages[age].pictures) > 0, "Every age contains reviewed production pictures: " + str(age))
	check(ages[3].pictures == 69 and ages[3].contextual == 11, "The Lv3 cohort preserves its 69 pictures and eleven context-only words")
	print("Vocabulary art: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

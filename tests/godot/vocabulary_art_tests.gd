extends SceneTree

const Data = preload("res://scripts/game_data.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	var data := Data.new()
	check(data.load_all(), "The shared production vocabulary loads: " + data.error)
	var reviewed := 0
	var contextual := 0
	for word in data.words:
		if int(word.min_age) != 3:
			continue
		if word.image.is_empty():
			contextual += 1
			continue
		reviewed += 1
		check(word.image == "assets/images/words/lv3-%s.png" % word.id, "Every Lv3 consumer receives the reviewed picture: " + str(word.id))
		var texture: Texture2D = load("res://" + word.image)
		check(texture != null and texture.get_size() == Vector2(256, 256), "The reviewed picture keeps its source dimensions: " + str(word.id))
		if texture == null:
			continue
		var image: Image = texture.get_image()
		if image.is_compressed():
			image.decompress()
		check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(255, 255).a == 0.0, "The shared picture blends onto cards without a backplate: " + str(word.id))
	check(reviewed == 69 and contextual == 11, "The complete Lv3 cohort retains 69 pictures and eleven context-only words")
	print("Vocabulary art: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

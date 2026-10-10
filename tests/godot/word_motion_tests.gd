extends SceneTree

const WordArt = preload("res://scripts/word_art.gd")
const Data = preload("res://scripts/game_data.gd")
const WordCard = preload("res://scripts/word_card.gd")
const PhraseView = preload("res://scripts/phrase_game.gd")
const JellyTile = preload("res://scripts/jelly_tile.gd")
const PopView = preload("res://scripts/voice_pop.gd")

var checks := 0
var failures := 0
var data = Data.new()


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1100, 800)
	check(data.load_all(), "Motion fixtures use the production vocabulary")
	_check_atlases()
	_check_clock()
	_check_memory_card()
	await _check_phrase()
	_check_jelly()
	await _check_pop()
	WordArt.set_reduced_motion(false)
	print("Animated vocabulary: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _word(id: String) -> Dictionary:
	for word: Dictionary in data.words:
		if str(word.id) == id:
			return word
	return {}


func _owner(parent: Node = null) -> Control:
	var result := Control.new()
	(root if parent == null else parent).add_child(result)
	result.position = Vector2(20, 20)
	result.size = Vector2(128, 128)
	return result


func _reset_clock() -> void:
	WordArt.set_reduced_motion(true)
	WordArt.set_reduced_motion(false)


func _check_atlases() -> void:
	var expected := {"walk": 40, "run": 20, "jump": 64, "open": 80,
		"close": 80, "drink": 80, "eat": 80, "hello": 72}
	check(WordArt.CLIPS.size() == expected.size(), "Exactly the eight approved teaching actions are animated")
	check(WordArt.FRAME_SIDE == 128 and is_equal_approx(WordArt.FPS, 24.0),
		"Runtime pictures retain the approved 24 fps timing at card resolution")
	check(WordArt.texture("") == null, "Context-only vocabulary retains no invented illustration")
	var static_path: String = str(_word("apple").image)
	var still: Texture2D = WordArt.texture(static_path)
	check(still == load("res://" + static_path) and not still is AtlasTexture,
		"Words outside the eight reviewed motions retain their existing picture")
	for id: String in expected:
		var owner := _owner()
		var source: String = str(_word(id).image)
		var texture: Texture2D = WordArt.texture(source, owner)
		check(texture is AtlasTexture, "The live %s picture resolves to its imported motion atlas" % id)
		if not texture is AtlasTexture:
			owner.free()
			continue
		var atlas: AtlasTexture = texture
		check(WordArt.texture("res://" + source) == atlas,
			"All copies of %s share the same frame resource" % id)
		check(WordArt.source_path(atlas) == "res://" + source,
			"%s preserves its source identity for accessibility and diagnostics" % id)
		check(atlas.atlas.get_size() == Vector2(1024, ceili(float(expected[id]) / 8.0) * 128),
			"%s includes every frame without an oversized runtime sheet" % id)
		check(atlas.filter_clip and atlas.get_size() == Vector2(128, 128),
			"%s reports a single clipped square frame to card layout" % id)
		_reset_clock()
		var seen := {}
		for frame in range(int(expected[id])):
			seen[atlas.region.position] = true
			check(Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region)
				and atlas.region.size == Vector2(128, 128),
				"%s frame %d stays inside its source sheet" % [id, frame])
			WordArt.advance(1.0 / 24.0 + 0.000001)
		check(seen.size() == int(expected[id]) and atlas.region.position == Vector2.ZERO,
			"%s plays every frame once before wrapping" % id)
		owner.free()


func _check_clock() -> void:
	var parent := _owner()
	parent.size = Vector2(200, 200)
	parent.clip_contents = true
	var owner := _owner(parent)
	var atlas := WordArt.texture(str(_word("walk").image), owner) as AtlasTexture
	if atlas == null:
		parent.free()
		return
	_reset_clock()
	WordArt.advance(0.02)
	check(atlas.region.position == Vector2.ZERO, "A teaching frame holds until its 24 fps interval elapses")
	WordArt.advance(0.03)
	var frame: Rect2 = atlas.region
	check(frame.position == Vector2(128, 0), "Visible art advances once its frame interval passes")
	owner.hide()
	WordArt.advance(0.1)
	check(atlas.region == frame, "Hidden pictures do not consume animation time")
	owner.show()
	owner.position = Vector2(300, 20)
	WordArt.advance(0.1)
	check(atlas.region == frame, "Pictures outside a clipping parent pause even inside the viewport")
	owner.position = Vector2(2000, 20)
	WordArt.advance(0.1)
	check(atlas.region == frame, "Offscreen pictures do not consume animation time")
	owner.position = Vector2(20, 20)
	WordArt.advance(0.1, false)
	check(atlas.region == frame, "The host's menu or background gate pauses all vocabulary art")
	for delta in [0.0, -1.0, INF, NAN]:
		WordArt.advance(delta)
	check(atlas.region == frame, "Invalid or nonpositive clock deltas cannot corrupt the current frame")
	WordArt.advance(0.05)
	check(atlas.region != frame, "Resuming continues the paused teaching action")
	_reset_clock()
	WordArt.advance(30.0)
	check(atlas.region.position == Vector2(256, 0), "A stalled browser frame cannot skip an entire teaching action")
	WordArt.set_reduced_motion(true)
	frame = atlas.region
	check(frame.position == Vector2(384, 256), "Reduced motion selects the approved readable walk poster")
	WordArt.advance(0.1)
	check(atlas.region == frame, "Reduced motion remains static while the game clock runs")
	WordArt.set_reduced_motion(false)
	check(atlas.region.position == Vector2.ZERO, "Restoring motion restarts from a complete teaching action")
	owner.hide()
	var second := _owner()
	WordArt.bind(atlas, second)
	WordArt.advance(0.1)
	check(atlas.region.position != Vector2.ZERO, "A second visible copy keeps a shared animation alive")
	frame = atlas.region
	second.free()
	WordArt.advance(0.1)
	check(atlas.region == frame, "Freed consumers are discarded safely and cannot keep playback running")
	parent.free()
	var reused := TextureRect.new()
	root.add_child(reused)
	reused.size = Vector2(128, 128)
	reused.texture = WordArt.texture(str(_word("walk").image), reused)
	_reset_clock()
	WordArt.advance(0.1)
	frame = atlas.region
	reused.texture = WordArt.texture(str(_word("apple").image), reused)
	WordArt.advance(0.1)
	check(atlas.region == frame, "A reused picture control cannot keep its previous word playing")
	reused.free()


func _check_memory_card() -> void:
	var card := WordCard.new()
	card.setup({"id": "walk:image", "kind": "image", "word": _word("walk")})
	root.add_child(card)
	card.position = Vector2(40, 40)
	card.size = Vector2(150, 150)
	card.set_back(Control.new())
	card.set_face_up(false, false)
	var atlas := card.picture.texture as AtlasTexture
	check(atlas != null, "Match and Memory cards use the shared animated word picture")
	if atlas != null:
		_reset_clock()
		WordArt.advance(0.1)
		check(not card.picture.is_visible_in_tree() and atlas.region.position == Vector2.ZERO,
			"A concealed Memory card neither reveals nor advances its illustration")
		card.set_face_up(true, false)
		WordArt.advance(0.1)
		check(card.picture.is_visible_in_tree() and atlas.region.position != Vector2.ZERO,
			"Revealing a Memory card resumes its real word animation")
		var frame: Rect2 = atlas.region
		card.set_face_up(false, false)
		WordArt.advance(0.1)
		check(not card.picture.is_visible_in_tree() and atlas.region == frame,
			"Reconcealing the card stops its animation without leaking the answer")
	card.free()


func _check_phrase() -> void:
	var view := PhraseView.new()
	root.add_child(view)
	view.size = Vector2(1000, 650)
	var option := -1
	for seed in range(32):
		if not view.configure(data.words, "3", "spring", seed):
			break
		for index in range(view.game.options.size()):
			if WordArt.CLIPS.has(str(view.game.options[index].id)):
				option = index
				break
		if option >= 0:
			break
	check(option >= 0, "A real Phrase Builder word bank includes a reviewed action fixture")
	if option >= 0:
		view.set_process(false)
		var original: Texture2D = view.option_buttons[option].icon
		check(original is AtlasTexture, "The candidate button displays its animated vocabulary picture")
		view.option_buttons[option].pressed.emit()
		check(view.game.answer == [option] and view.answer_buttons[0].icon == original,
			"Moving a candidate to the answer preserves its shared animation resource")
		check(not view.option_buttons[option].visible and view.answer_buttons[0].is_visible_in_tree(),
			"Only the placed answer copy remains visible")
		if original is AtlasTexture:
			_reset_clock()
			WordArt.advance(0.1)
			check(original.region.position != Vector2.ZERO,
				"The answer remains bound to playback after its candidate is hidden")
		view.answer_buttons[0].pressed.emit()
		check(view.game.answer.is_empty() and view.option_buttons[option].icon == original,
			"Returning an answer restores the same animated candidate")
	view.queue_free()
	await process_frame


func _check_jelly() -> void:
	var tile := JellyTile.new()
	root.add_child(tile)
	tile.position = Vector2(40, 40)
	tile.size = Vector2(150, 150)
	var picture: Texture2D = WordArt.texture(str(_word("jump").image))
	var cell := {"id": 1, "word": _word("jump"), "kind": "picture", "chest": false}
	var surface: Texture2D = load("res://assets/images/jelly-match/gel-mint.png")
	tile.configure(cell, surface, picture, null, Color.CORAL)
	check(tile._picture.texture == picture and picture is AtlasTexture,
		"Jelly picture tiles display the same shared motion as the other modes")
	if picture is AtlasTexture:
		_reset_clock()
		WordArt.advance(0.1)
		check(picture.region.position != Vector2.ZERO, "Visible jelly pictures register their playback owner")
		var frame: Rect2 = picture.region
		tile.set_projection(true)
		WordArt.advance(0.1)
		check(not tile._picture.visible and picture.region == frame,
			"A landing projection does not expose or animate the picture")
		tile.set_projection(false)
		cell.kind = "word"
		tile.configure(cell, surface, picture, null, Color.CORAL, true)
		WordArt.advance(0.1)
		check(tile._picture.visible and tile._label.visible and picture.region != frame,
			"A fused jelly retains its animated picture alongside the readable word")
	tile.free()


func _check_pop() -> void:
	var view := PopView.new()
	root.add_child(view)
	view.size = Vector2(900, 650)
	var words: Array = data.words.filter(func(word: Dictionary) -> bool: return WordArt.CLIPS.has(str(word.id)))
	view.configure(words, false, 71)
	view.set_listening(true, true, "Listening.")
	view.set_process(false)
	view._listening_tick_usec = -1
	check(not view.game.targets.is_empty(), "Voice Pop starts a real target using reviewed action words")
	if not view.game.targets.is_empty():
		var word: Dictionary = view.game.targets[0].word
		var original: Texture2D = view._textures.get(str(word.id))
		check(original is AtlasTexture, "Voice Pop's custom drawing uses the animated picture cache")
		_reset_clock()
		WordArt.advance(0.1)
		var frame: Rect2 = original.region if original is AtlasTexture else Rect2()
		view.receive_transcript(str(word.text))
		check(view._bursts.size() == 1, "A recognized animated word creates one real slice effect")
		if not view._bursts.is_empty() and original is AtlasTexture:
			var frozen := view._bursts[0].picture as AtlasTexture
			check(frozen != null and frozen != original and frozen.region == frame,
				"Both slice halves capture an independent copy of the exact impact frame")
			WordArt.advance(0.1)
			check(frozen != null and original.region != frame and frozen.region == frame and frozen.atlas == original.atlas,
				"Live targets keep playing while the slice preserves its pose without duplicating the atlas")
			view._add_review("Try these words", [word], Color.CORAL)
			var row: Button = view._review_buttons.back()
			var art: TextureRect = row.find_children("*", "TextureRect", true, false)[0]
			check(art.texture == original, "The result review reuses the same animated vocabulary picture")
	await process_frame
	view.free()

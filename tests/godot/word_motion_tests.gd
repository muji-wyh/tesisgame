extends SceneTree

const WordArt = preload("res://scripts/word_art.gd")
const Data = preload("res://scripts/game_data.gd")
const WordCard = preload("res://scripts/word_card.gd")
const PhraseView = preload("res://scripts/phrase_game.gd")
const JellyTile = preload("res://scripts/jelly_tile.gd")
const PopView = preload("res://scripts/voice_pop.gd")
const Catalog = preload("res://scripts/age_word_catalog.gd")

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
	_check_catalog()
	_check_residency()
	_check_atlases()
	_check_generated_profiles()
	_check_clock()
	_check_memory_card()
	await _check_phrase()
	_check_jelly()
	await _check_pop()
	await _check_notebook()
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
	WordArt.advance(0.000001)


func _check_catalog() -> void:
	var before: Dictionary = WordArt.cache_snapshot()
	var profiles: Dictionary = WordArt.motion_catalog()
	var pictured := 0
	for word: Dictionary in data.words:
		if str(word.image).is_empty():
			check(not profiles.has(word.id), "Context-only language has no invented motion: " + str(word.id))
			continue
		pictured += 1
		check(profiles.has(word.id), "Every pictured word has a motion profile: " + str(word.id))
		if not profiles.has(word.id):
			continue
		var profile: Dictionary = profiles[word.id]
		check(profile.path == "assets/images/word-motion/%s.webp" % word.id
			and int(profile.frameSide) == 128 and int(profile.columns) == 8
			and ResourceLoader.exists("res://" + str(profile.path)),
			"Every motion record identifies its own imported card-sized atlas: " + str(word.id))
		if WordArt.CLIPS.has(word.id):
			check(int(profile.frames) == int(WordArt.CLIPS[word.id][0]) and int(profile.fps) == 24,
				"The eight skeletal teaching actions retain their original timing: " + str(word.id))
		else:
			check(int(profile.frames) == 32 and int(profile.fps) == 12 and int(profile.posterFrame) == 0,
				"The full-library motion uses its authored 32-frame cycle: " + str(word.id))
	check(pictured == 1285 and profiles.size() == pictured, "Motion covers every pictured word exactly once")
	check(WordArt.cache_snapshot() == before, "Reviewing all 1285 metadata records loads no atlas or poster textures")
	profiles.clear()
	check(WordArt.motion_catalog().size() == pictured, "Consumers cannot mutate shared motion metadata")


func _check_residency() -> void:
	var owner := TextureRect.new()
	root.add_child(owner)
	owner.size = Vector2(128, 128)
	owner.hide()
	owner.texture = WordArt.texture(str(_word("apple").image), owner)
	var atlas := owner.texture as AtlasTexture
	check(atlas != null and atlas.get_size() == Vector2(128, 128), "Unseen art has a stable card-sized poster wrapper")
	if atlas == null:
		owner.free()
		return
	WordArt.advance(0.1)
	check(WordArt.cache_snapshot().resident_sheets == 0 and atlas.atlas.get_size() == Vector2(128, 128),
		"Hidden requests never decode a full motion sheet")
	owner.show()
	WordArt.advance(0.1)
	check(WordArt.cache_snapshot().resident_ids == ["apple"] and atlas.atlas.get_size() == Vector2(1024, 512),
		"A visible owner lazily activates only its own sheet")
	var identity: int = atlas.get_instance_id()
	var sheet_reference: WeakRef = weakref(atlas.atlas)
	var frozen := atlas.duplicate() as AtlasTexture
	var frozen_region: Rect2 = frozen.region
	owner.hide()
	WordArt.advance(WordArt.IDLE_SECONDS + 0.1)
	check(WordArt.cache_snapshot().resident_sheets == 0 and atlas.atlas.get_size() == Vector2(128, 128)
		and atlas.get_size() == Vector2(128, 128), "Hidden sheets return to a small poster after the residency timeout")
	check(frozen.region == frozen_region and frozen.atlas == sheet_reference.get_ref(),
		"Eviction preserves the independent frozen impact pose")
	frozen = null
	check(sheet_reference.get_ref() == null, "Dropping the last frozen copy actually releases the decoded sheet")
	owner.show()
	WordArt.advance(0.1)
	check(atlas.get_instance_id() == identity and WordArt.texture(str(_word("apple").image)) == atlas
		and WordArt.cache_snapshot().resident_sheets == 1, "Reactivation keeps the same shared wrapper identity")
	var reloaded_reference: WeakRef = weakref(atlas.atlas)
	WordArt.set_reduced_motion(true)
	check(WordArt.cache_snapshot().resident_sheets == 0 and reloaded_reference.get_ref() == null,
		"Reduced motion immediately releases animation memory and retains its poster")
	WordArt.set_reduced_motion(false)
	owner.texture = null
	WordArt.advance(0.1)
	check(WordArt.cache_snapshot().owners == 0, "Reused texture controls stop owning their previous word")
	owner.free()
	var wrapper_reference: WeakRef = weakref(atlas)
	atlas = null
	WordArt.advance(0.1)
	check(wrapper_reference.get_ref() == null and WordArt.cache_snapshot().entries == 0,
		"The registry does not retain orphan wrappers or their posters")
	_check_sheet_budget()


func _check_sheet_budget() -> void:
	var owners: Array[Control] = []
	var textures: Array[Texture2D] = []
	var words: Array = data.words.filter(func(word: Dictionary) -> bool:
		return not str(word.image).is_empty() and not WordArt.CLIPS.has(word.id))
	for word: Dictionary in words.slice(0, WordArt.MAX_RESIDENT_SHEETS + 1):
		var owner := _owner()
		owners.append(owner)
		textures.append(WordArt.texture(str(word.image), owner))
	WordArt.advance(0.01)
	check(WordArt.cache_snapshot().resident_sheets == WordArt.MAX_LOADS_PER_TICK,
		"A page reveal bounds synchronous sheet uploads per frame")
	for tick in range(ceili(float(WordArt.MAX_RESIDENT_SHEETS) / WordArt.MAX_LOADS_PER_TICK) + 2):
		WordArt.advance(0.01)
	check(WordArt.cache_snapshot().resident_sheets == WordArt.MAX_RESIDENT_SHEETS,
		"Even oversized visible demand cannot exceed the resident sheet budget")
	var waiting_id: String = str(words[WordArt.MAX_RESIDENT_SHEETS].id)
	check(not WordArt.cache_snapshot().resident_ids.has(waiting_id), "Excess demand keeps its readable poster")
	owners[0].hide()
	WordArt.advance(0.01)
	check(WordArt.cache_snapshot().resident_sheets == WordArt.MAX_RESIDENT_SHEETS
		and WordArt.cache_snapshot().resident_ids.has(waiting_id)
		and not WordArt.cache_snapshot().resident_ids.has(str(words[0].id)),
		"New visible art evicts a hidden sheet before the timeout when capacity is full")
	for owner: Control in owners:
		owner.free()
	owners.clear()
	textures.clear()
	WordArt.advance(WordArt.IDLE_SECONDS + 0.1, false)
	check(WordArt.cache_snapshot().resident_sheets == 0, "Leaving an oversized page releases every sheet")


func _check_atlases() -> void:
	var expected := {"walk": 40, "run": 20, "jump": 64, "open": 80,
		"close": 80, "drink": 80, "eat": 80, "hello": 72}
	check(WordArt.CLIPS.size() == expected.size(), "The eight skeletal teaching actions retain their compatibility metadata")
	check(WordArt.FRAME_SIDE == 128 and is_equal_approx(WordArt.FPS, 24.0),
		"Runtime pictures retain the approved 24 fps timing at card resolution")
	check(WordArt.texture("") == null, "Context-only vocabulary retains no invented illustration")
	var static_path := "assets/images/jelly-match/gel-mint.png"
	var still: Texture2D = WordArt.texture(static_path)
	check(still == load("res://" + static_path) and not still is AtlasTexture,
		"Non-vocabulary production artwork remains an ordinary static texture")
	for id: String in expected:
		var owner := _owner()
		var source: String = str(_word(id).image)
		var texture: Texture2D = WordArt.texture(source, owner)
		check(texture is AtlasTexture, "The live %s picture resolves to its imported motion atlas" % id)
		if not texture is AtlasTexture:
			owner.free()
			continue
		var atlas: AtlasTexture = texture
		_reset_clock()
		check(WordArt.texture("res://" + source) == atlas,
			"All copies of %s share the same frame resource" % id)
		check(WordArt.source_path(atlas) == "res://" + source,
			"%s preserves its source identity for accessibility and diagnostics" % id)
		check(atlas.atlas.get_size() == Vector2(1024, ceili(float(expected[id]) / 8.0) * 128),
			"%s includes every frame without an oversized runtime sheet" % id)
		check(atlas.filter_clip and atlas.get_size() == Vector2(128, 128),
			"%s reports a single clipped square frame to card layout" % id)
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


func _check_generated_profiles() -> void:
	for id in ["apple", "happy", "mother", "red", "triangle", "thermometer"]:
		var owner := _owner()
		var atlas := WordArt.texture(str(_word(id).image), owner) as AtlasTexture
		check(atlas != null, "Different vocabulary categories share the motion path: " + id)
		if atlas == null:
			owner.free()
			continue
		_reset_clock()
		var seen := {}
		for frame in range(32):
			seen[atlas.region.position] = true
			check(atlas.get_size() == Vector2(128, 128)
				and Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region),
				"Generated motion remains inside the authored sheet: %s/%d" % [id, frame])
			WordArt.advance(1.0 / 12.0 + 0.000001)
		check(seen.size() == 32 and atlas.region.position == Vector2.ZERO,
			"The complete 12 fps cycle plays once before wrapping: " + id)
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
	check(frame == Rect2(0, 0, 128, 128) and atlas.atlas.get_size() == Vector2(128, 128)
		and WordArt.cache_snapshot().resident_sheets == 0, "Reduced motion uses the reviewed walk poster without a decoded sheet")
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
			check(frozen != null and frozen.region == frame and frozen.atlas == original.atlas,
				"A sliced target preserves its exact pose without duplicating the decoded atlas")
			view._add_review("Try these words", [word], Color.CORAL)
			var row: Button = view._review_buttons.back()
			var art: TextureRect = row.find_children("*", "TextureRect", true, false)[0]
			check(art.texture == original, "The result review reuses the same animated vocabulary picture")
	view._cache_texture(_word("apple"))
	WordArt.advance(0.1)
	check(not view.is_word_art_visible("apple") and not WordArt.cache_snapshot().resident_ids.has("apple"),
		"Voice Pop cannot animate an old cached word that is absent from its drawn targets")
	await process_frame
	view.free()


func _check_notebook() -> void:
	WordArt.advance(WordArt.IDLE_SECONDS + 0.1, false)
	var view := Catalog.new()
	root.add_child(view)
	view.position = Vector2(20, 20)
	view.size = Vector2(600, 500)
	view.configure([_word("apple"), _word("walk")], Data.age_band("3"), Data.theme("spring"))
	for frame in range(5):
		await process_frame
	_reset_clock()
	WordArt.advance(0.1)
	for button: Button in view.word_buttons:
		var picture: TextureRect = button.get_meta("word_art")
		check(picture.texture is AtlasTexture and picture.texture.region.position != Vector2.ZERO,
			"Visible notebook illustrations play both generated and skeletal motion")
	view.hide()
	WordArt.advance(WordArt.IDLE_SECONDS + 0.1)
	check(WordArt.cache_snapshot().resident_sheets == 0, "Closing the notebook releases its sheet residency")
	view.free()

extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/game_model.gd")
const Progress = preload("res://scripts/medal_progress.gd")
const RoomState = preload("res://scripts/playroom_state.gd")
const NEW_WORLDS := [
	{"id": "jungle", "name": "Jungle", "word": "monkey", "topic": "animal-friends", "chest": "royal"},
	{"id": "candy", "name": "Candy", "word": "cake", "topic": "picnic-time", "chest": "crystal"}
]

var checks: int = 0
var failures: int = 0


class Storage extends RefCounted:
	var medals: String
	var room: String

	func _init() -> void:
		var record := ConfigFile.new()
		record.set_value("medals", "version", 1)
		record.set_value("medals", "counts", {"spring-1": 3, "space-2": 1})
		medals = record.encode_to_text()
		record.clear()
		record.set_value("playroom", "version", 1)
		record.set_value("playroom", "toy", "toy-ball")
		record.set_value("playroom", "backdrop", "backdrop-home")
		record.set_value("playroom", "favorite", "spring-7")
		room = record.encode_to_text()

	func medalProgress() -> String:
		return medals

	func saveMedalProgress(value: String) -> bool:
		medals = value
		return true

	func playroomState() -> String:
		return room

	func savePlayroomState(value: String) -> bool:
		room = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "New worlds use the complete existing vocabulary and chest manifest")
	_check_catalog()
	_check_game_models(data.words)
	_check_age_limited_gifts(data.words)
	_check_progress_and_room()
	await _check_chests_and_celebration(data.chests)
	print("New themes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_catalog() -> void:
	check(Data.THEMES.size() == 8 and Model.THEMES.size() == 8, "Both theme catalogs expose eight worlds")
	var illustrations: Dictionary = {}
	for world in NEW_WORLDS:
		check(Data.THEMES.has(world.id) and Model.THEMES.has(world.id), "The data and game model both accept " + world.id)
		var palette: Dictionary = Data.theme(world.id)
		check(palette.name == world.name and palette.chest == world.chest,
			"The new world has its intended title and supported chest skin")
		check(ResourceLoader.exists(palette.symbol) and load(palette.symbol) is Texture2D,
			"The theme chooser and celebration can load the new world symbol")
		var medals: Array = Data.medals(world.id)
		check(medals.size() == 6 and Data.rewards(world.id).size() == 6, "Each new world contains six active medals")
		for index in range(medals.size()):
			var medal: Dictionary = medals[index]
			check(medal.id == "%s-%d" % [world.id, index + 1] and medal.theme == world.id
				and Data.medal(medal.id) == medal and Data.reward(medal.id) == medal,
				"New medal IDs resolve consistently for progress, collection and favorites")
			check(load(medal.symbol) is Texture2D, "Every new medal has loadable SVG artwork: " + medal.id)
			var artwork: String = FileAccess.get_file_as_string(medal.symbol)
			check(not illustrations.has(artwork), "Each new medal uses a different illustration")
			illustrations[artwork] = true
		check(Data.medal(world.id + "-7").is_empty(), "New worlds have no phantom seventh medal")
		var toy: Dictionary = RoomState.item("toy-" + world.id)
		check(toy.word_id == world.word and toy.medal_id == world.id + "-1"
			and toy.required_pieces == Data.PIECES_PER_MEDAL and RoomState._known_word(toy.word_id),
			"The first medal unlocks a toy with a real existing vocabulary word")


func _check_game_models(words: Array) -> void:
	for world in NEW_WORLDS:
		var model := Model.new()
		check(model.reset(words, 83, false, world.topic, world.word), "A new-world gift starts a safe lesson containing its noun")
		check(model.lesson_words.any(func(word: Dictionary) -> bool: return word.id == world.word),
			"The gift's pronunciation word is present in the lesson")
		var cards: Array = model.cards.duplicate(true)
		check(model.set_theme(world.id) and model.theme_id == world.id and model.cards == cards,
			"Choosing a new world preserves the live lesson")
		for word in model.lesson_words.slice(0, 3):
			check(model.match_spoken_word(word.id) == "correct", "The new world keeps normal pair scoring")
			model.resolve_feedback()
		check(model.phase == "won" and model.successes == 3, "Three correct pairs win in the new world")
		check(model.begin_open(world.id + "-1") and model.reward_theme == world.id,
			"Winning captures the new world's reward identity")
		check(not model.set_theme("spring") and model.finish_open() and model.reward_id == world.id + "-1",
			"Opening locks the earned world until its new medal is delivered")
		check(model.set_theme("spring") and model.reward_theme == world.id,
			"A later theme choice never rewrites the already earned new-world reward")


func _check_age_limited_gifts(words: Array) -> void:
	var gifts: Array = NEW_WORLDS.duplicate(true)
	gifts.append_array([
		{"id": "spring", "word": "flower", "topic": "great-outdoors"},
		{"id": "summer", "word": "ball", "topic": "play-time"},
		{"id": "autumn", "word": "apple", "topic": "picnic-time"},
		{"id": "winter", "word": "bell", "topic": "music-makers"},
		{"id": "ocean", "word": "shell", "topic": "ocean-discovery"},
		{"id": "space", "word": "rocket", "topic": "space-trip"}
	])
	var band: Dictionary = Data.age_band("4-6")
	for gift in gifts:
		var model := Model.new()
		var topic: Dictionary = Data.ADVENTURES.filter(func(adventure: Dictionary) -> bool: return adventure.id == gift.topic)[0]
		for seed_value in [0, 17, 83, -1]:
			var started: bool = model.reset(words, seed_value, false, gift.topic, gift.word, band.id)
			check(started, "Ages 4-6 can start the " + gift.id + " gift lesson, including the live random entry point")
			if not started:
				continue
			check(model.age_band_id == band.id and model.lesson_words.size() == 5 and model.cards.size() == 8,
				"A gift lesson preserves the selected age and complete board")
			check(model.lesson_words[0].id == gift.word
				and not model.card_by_id(gift.word + ":word").is_empty()
				and not model.card_by_id(gift.word + ":image").is_empty(),
				"The requested gift noun is the first lesson word and a playable matching pair")
			check(model.lesson_words.slice(1).all(func(word: Dictionary) -> bool: return word.id != gift.word and Data.word_level(word) <= band.max_level),
				"Only the requested gift noun may exceed the age limit; the four other words remain age-appropriate")
			check(model.lesson_words.all(func(word: Dictionary) -> bool: return topic.words.has(word.id)),
				"An age exception never adds a word from another adventure")
			var lesson: Array = model.lesson_words.duplicate(true)
			check(model.reset(words, seed_value, true, "", "", "10-plus")
				and model.lesson_words == lesson and model.age_band_id == band.id,
				"Switching modes preserves a gift lesson and its original age selection")
			check(model.reset(words, seed_value, false, gift.topic, "", band.id)
				and model.age_band_id == band.id
				and model.lesson_words.all(func(word: Dictionary) -> bool: return Data.word_level(word) <= band.max_level),
				"The next ordinary lesson applies the full age limit without retaining the gift exception")
	var failure_model := Model.new()
	check(failure_model.reset(words, 17, false, "animal-friends", "", band.id), "The failure fixture starts with a normal age-limited lesson")
	var previous_words: Array = failure_model.lesson_words.duplicate(true)
	var previous_cards: Array = failure_model.cards.duplicate(true)
	check(not failure_model.reset(words, 17, false, "picnic-time", "monkey", band.id)
		and failure_model.lesson_words == previous_words and failure_model.cards == previous_cards and failure_model.age_band_id == band.id,
		"An invalid gift-topic combination is rejected without replacing the active lesson")
	var too_few: Array = words.filter(func(word: Dictionary) -> bool: return word.id in ["monkey", "tiger", "elephant", "cat", "dog", "fish"])
	check(not failure_model.reset(too_few, 17, false, "animal-friends", "monkey", band.id)
		and failure_model.lesson_words == previous_words and failure_model.cards == previous_cards and failure_model.age_band_id == band.id,
		"A gift never fills missing age-appropriate slots with other older-level words or loses the active lesson")


func _check_progress_and_room() -> void:
	var storage := Storage.new()
	var fixture := "user://new-theme-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var progress := Progress.new(fixture + "-medals.cfg", fixture + "-legacy.cfg", storage)
	var state := RoomState.new(fixture + "-room.cfg", storage)
	check(progress.load_progress() and state.load_state(), "Existing saves load with new worlds available")
	check(progress.counts == {"spring-1": 3, "space-2": 1} and state.favorite_id == "spring-7",
		"Adding worlds preserves prior progress and archived favorites")
	for world in NEW_WORLDS:
		var toy_id: String = "toy-" + world.id
		check(state.set_goal(toy_id, progress.counts) and state.preferred_theme_id == world.id
			and state.selected_goal(progress.counts).remaining_pieces == 3,
			"A new toy goal stores its world and exact three-piece requirement")
		check(not state.select_item(toy_id, progress.counts), "A new toy cannot be equipped before it is earned")
		for piece in range(18):
			var fragment: Dictionary = progress.next_fragment(world.id)
			check(fragment.get("medal_id") == "%s-%d" % [world.id, piece / 3 + 1]
				and fragment.get("after") == piece % 3 + 1 and progress.claim(fragment),
				"New medals award three pieces each in the established order")
			check(RoomState.owned(RoomState.item(toy_id), progress.counts) == (piece >= 2),
				"A new toy unlocks exactly when its first medal is complete")
		check(progress.completed_count(world.id) == 6 and progress.next_fragment(world.id).is_empty(),
			"Eighteen pieces complete the six-medal world without duplicate rewards")
		check(state.select_item(toy_id, progress.counts) and state.select_item("backdrop-" + world.id, progress.counts)
			and state.set_favorite(world.id + "-6"), "Earned new toys, legacy-compatible rooms and favorites can be saved")
		var reloaded := RoomState.new(fixture + "-room.cfg", storage)
		check(reloaded.load_state() and reloaded.toy_id == toy_id and reloaded.backdrop_id == "backdrop-" + world.id
			and reloaded.favorite_id == world.id + "-6" and reloaded.preferred_theme_id == world.id,
			"New-world room choices and preferences survive a reload")
	var reloaded_progress := Progress.new(fixture + "-medals.cfg", fixture + "-legacy.cfg", storage)
	check(reloaded_progress.load_progress() and reloaded_progress.counts == progress.counts
		and reloaded_progress.count_for("spring-1") == 3 and reloaded_progress.count_for("space-2") == 1,
		"Saved new-world progress reloads without changing old medal pieces")


func _check_chests_and_celebration(manifest: Dictionary) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	var effects = load("res://scripts/celebration.gd").new()
	root.add_child(chest)
	root.add_child(effects)
	chest.size = Vector2(240, 240)
	effects.size = Vector2(240, 240)
	effects.configure(manifest)
	for world in NEW_WORLDS:
		var palette: Dictionary = Data.theme(world.id)
		chest.configure_skin(palette, manifest)
		check(chest.theme_id == world.id and chest.piece_count() == (9 if world.chest == "crystal" else 2),
			"The new world renders a complete supported chest")
		effects.start(palette, false, true)
		check(effects.particle_count() == 24 and effects._token != null, "A new-world fragment starts its own symbol celebration")
		effects._process(0.8)
		await process_frame
		effects.start(palette, true)
		check(effects.particle_count() == 0, "New-world celebrations honor reduced motion")
	chest.queue_free()
	effects.queue_free()
	await process_frame

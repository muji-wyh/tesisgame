extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/game_model.gd")
const Progress = preload("res://scripts/medal_progress.gd")
const NEW_WORLDS := [
	{"id": "jungle", "name": "Jungle", "word": "monkey", "topic": "animal-friends", "chest": "bramble"},
	{"id": "candy", "name": "Candy", "word": "cake", "topic": "picnic-time", "chest": "bonbon"}
]

var checks: int = 0
var failures: int = 0


class Storage extends RefCounted:
	var medals: String

	func _init() -> void:
		var record := ConfigFile.new()
		record.set_value("medals", "version", 1)
		record.set_value("medals", "counts", {"spring-1": 3, "space-2": 1})
		medals = record.encode_to_text()

	func medalProgress() -> String:
		return medals

	func saveMedalProgress(value: String) -> bool:
		medals = value
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
	_check_progress()
	await _check_chests(data.chests)
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
			"The theme chooser can load the new world symbol")
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


func _check_game_models(words: Array) -> void:
	for world in NEW_WORLDS:
		var model := Model.new()
		check(model.reset(words, 83, false, "", "", "12"), "A new world starts a normal eligible lesson")
		var cards: Array = model.cards.duplicate(true)
		check(model.set_theme(world.id) and model.theme_id == world.id and model.cards == cards,
			"Choosing a new world preserves the live lesson")
		for word in model.lesson_words:
			check(model.match_spoken_word(word.id) == "correct", "The new world keeps normal pair scoring")
			model.resolve_feedback()
		check(model.phase == "won" and (model.matched_ids.size() / 2) == 5, "Five correct pairs win in the new world")
		check(model.begin_open(world.id + "-1") and model.reward_theme == world.id,
			"Winning captures the new world's reward identity")
		check(not model.set_theme("spring") and model.finish_open() and model.reward_id == world.id + "-1",
			"Opening locks the earned world until its new medal is delivered")
		check(model.set_theme("spring") and model.reward_theme == world.id,
			"A later theme choice never rewrites the already earned new-world reward")


func _check_progress() -> void:
	var fixture: String = "user://new-theme-progress-%d" % Time.get_ticks_usec()
	var storage := Storage.new()
	var progress := Progress.new(fixture + "-medals.cfg", fixture + "-legacy.cfg", storage)
	check(progress.load_progress() and progress.count_for("spring-1") == 3 and progress.count_for("space-2") == 1,
		"New worlds preserve existing earned pieces")
	for world in NEW_WORLDS:
		for piece in range(Data.PIECES_PER_MEDAL):
			check(progress.claim(progress.next_fragment(world.id)), "A new world saves its next earned chest piece")
		check(progress.count_for(world.id + "-1") == Data.PIECES_PER_MEDAL,
			"A complete new-world reward remains saved independently of retired room features")
	var reloaded := Progress.new(fixture + "-medals.cfg", fixture + "-legacy.cfg", storage)
	check(reloaded.load_progress() and reloaded.counts == progress.counts, "All eight worlds keep their durable rewards")


func _check_chests(manifest: Dictionary) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(240, 240)
	for world in NEW_WORLDS:
		var palette: Dictionary = Data.theme(world.id)
		chest.configure_skin(palette, manifest)
		var live: Dictionary = chest.hold_effect_snapshot().get("live_model", {})
		check(chest.theme_id == world.id and chest.piece_count() == 1
			and not live.is_empty() and live.mesh_count > 0 and not live.parts.is_empty()
			and chest.hold_effect_snapshot().style == world.chest,
			"The new world renders its own detailed chest with a live animated mechanism")
		await process_frame
	chest.queue_free()
	await process_frame

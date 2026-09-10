extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const SAVE_VERSION: int = 1
const WORLD_TOYS: Array[Dictionary] = [
	{"theme": "spring", "word": "flower", "action": "water", "name": "Spring flower"},
	{"theme": "summer", "word": "ball", "action": "roll", "name": "Summer ball"},
	{"theme": "autumn", "word": "apple", "action": "offer", "name": "Autumn apple"},
	{"theme": "winter", "word": "bell", "action": "ring", "name": "Winter bell"},
	{"theme": "ocean", "word": "shell", "action": "open", "name": "Ocean shell"},
	{"theme": "space", "word": "rocket", "action": "launch", "name": "Space rocket"}
]

var toy_id: String = "toy-ball"
var backdrop_id: String = "backdrop-home"
var favorite_id: String = ""
var error: String = ""

var _save_path: String
var _browser_storage: Object
var _loaded: bool = false


func _init(save_path: String = "user://playroom-v2.cfg", browser_storage: Object = null) -> void:
	_save_path = save_path
	_browser_storage = browser_storage
	if _browser_storage == null and OS.has_feature("web"):
		_browser_storage = JavaScriptBridge.get_interface("wordBuddiesHost")


static func catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"id": "toy-ball", "slot": "toy", "theme": "", "name": "Ball", "word_id": "ball", "action": "roll",
			"art": "res://assets/images/words/ball.svg", "medal_id": "", "required_pieces": 0},
		{"id": "backdrop-home", "slot": "backdrop", "theme": "", "name": "Pip's home", "word_id": "", "action": "",
			"art": "res://assets/images/rewards/spring.svg", "medal_id": "", "required_pieces": 0}
	]
	for world in WORLD_TOYS:
		result.append({"id": "toy-" + world.theme, "slot": "toy", "theme": world.theme, "name": world.name,
			"word_id": world.word, "action": world.action, "art": "res://assets/images/words/%s.svg" % world.word,
			"medal_id": world.theme + "-1", "required_pieces": Data.PIECES_PER_MEDAL})
		result.append({"id": "backdrop-" + world.theme, "slot": "backdrop", "theme": world.theme,
			"name": Data.THEMES[world.theme].name + " room", "word_id": "", "action": "",
			"art": "res://assets/images/rewards/%s.svg" % world.theme,
			"medal_id": world.theme + "-3", "required_pieces": Data.PIECES_PER_MEDAL})
	return result


static func item(id: String) -> Dictionary:
	for entry in catalog():
		if entry.id == id:
			return entry
	return {}


static func owned(entry: Dictionary, counts: Dictionary) -> bool:
	if not entry.get("id") is String:
		return false
	var known := item(entry.id)
	return not known.is_empty() and (known.required_pieces == 0 or _pieces(counts, known.medal_id) >= known.required_pieces)


static func next_gift(counts: Dictionary, theme_id: String = "") -> Dictionary:
	var result: Dictionary = {}
	for entry in catalog():
		if (not theme_id.is_empty() and entry.theme != theme_id) or owned(entry, counts):
			continue
		var remaining: int = 0
		for medal in Data.medals(entry.theme):
			var required: int = entry.required_pieces if medal.id == entry.medal_id else Data.PIECES_PER_MEDAL
			remaining += maxi(0, required - _pieces(counts, medal.id))
			if medal.id == entry.medal_id:
				break
		if result.is_empty() or remaining < result.remaining_pieces:
			result = entry
			result.remaining_pieces = remaining
	return result


static func _pieces(counts: Dictionary, id: String) -> int:
	var value: Variant = counts.get(id, 0)
	return value if typeof(value) == TYPE_INT and value >= 0 and value <= Data.PIECES_PER_MEDAL else 0


func load_state(legacy_favorite: String = "") -> bool:
	error = ""
	_loaded = false
	if _save_path.is_empty():
		return _fail("The playroom needs a nonempty save path.")
	if OS.has_feature("web") and _browser_storage == null:
		return _fail("Browser playroom storage is unavailable.")
	var config := ConfigFile.new()
	var browser_text: Variant = _browser_storage.playroomState() if _browser_storage != null else null
	var status: int
	if browser_text != null:
		if not browser_text is String:
			return _fail("Could not read browser playroom choices. Browser storage may be unavailable.")
		status = config.parse(browser_text)
		if status != OK:
			return _fail("Could not load browser playroom choices: %s." % error_string(status))
	else:
		if not _restore_previous():
			return false
		status = config.load(_save_path)
		if status != OK and (status != ERR_FILE_NOT_FOUND or FileAccess.file_exists(_save_path) or DirAccess.dir_exists_absolute(_save_path)):
			return _fail("Could not load playroom choices from %s: %s." % [_save_path, error_string(status)])
	var next_toy: String = "toy-ball"
	var next_backdrop: String = "backdrop-home"
	var next_favorite: String = legacy_favorite
	if status != ERR_FILE_NOT_FOUND:
		var version: Variant = config.get_value("playroom", "version", null)
		if typeof(version) != TYPE_INT or version != SAVE_VERSION:
			return _fail("The playroom save version is missing, invalid, or unsupported; expected version %d." % SAVE_VERSION)
		var saved_toy: Variant = config.get_value("playroom", "toy", null)
		var saved_backdrop: Variant = config.get_value("playroom", "backdrop", null)
		var saved_favorite: Variant = config.get_value("playroom", "favorite", null)
		if not saved_toy is String or item(saved_toy).get("slot", "") != "toy":
			return _fail("The playroom save needs a known toy ID.")
		if not saved_backdrop is String or item(saved_backdrop).get("slot", "") != "backdrop":
			return _fail("The playroom save needs a known backdrop ID.")
		if not saved_favorite is String:
			return _fail("The playroom save needs a favorite reward ID or an empty string.")
		next_toy = saved_toy
		next_backdrop = saved_backdrop
		next_favorite = saved_favorite
	if not next_favorite.is_empty() and Data.reward(next_favorite).is_empty():
		return _fail("The playroom favorite needs a known reward ID.")
	if (status == ERR_FILE_NOT_FOUND or (_browser_storage != null and browser_text == null)) and not _persist(next_toy, next_backdrop, next_favorite):
		return false
	toy_id = next_toy
	backdrop_id = next_backdrop
	favorite_id = next_favorite
	_loaded = true
	return true


func select_item(id: String, counts: Dictionary) -> bool:
	error = ""
	if not _loaded:
		return _fail("Load playroom choices successfully before selecting an item.")
	var selected := item(id)
	if selected.is_empty():
		return _fail("Choose a known playroom item.")
	if not owned(selected, counts):
		return _fail("Earn the medal pieces for %s before selecting it." % selected.name)
	var next_toy: String = id if selected.slot == "toy" else toy_id
	var next_backdrop: String = id if selected.slot == "backdrop" else backdrop_id
	if next_toy == toy_id and next_backdrop == backdrop_id:
		return true
	if not _persist(next_toy, next_backdrop, favorite_id):
		return false
	toy_id = next_toy
	backdrop_id = next_backdrop
	return true


func set_favorite(id: String) -> bool:
	error = ""
	if not _loaded:
		return _fail("Load playroom choices successfully before choosing a favorite.")
	if not id.is_empty() and Data.reward(id).is_empty():
		return _fail("Choose a known reward for Pip's favorite.")
	if favorite_id == id:
		return true
	if not _persist(toy_id, backdrop_id, id):
		return false
	favorite_id = id
	return true


func _persist(next_toy: String, next_backdrop: String, next_favorite: String) -> bool:
	var config := ConfigFile.new()
	config.set_value("playroom", "version", SAVE_VERSION)
	config.set_value("playroom", "toy", next_toy)
	config.set_value("playroom", "backdrop", next_backdrop)
	config.set_value("playroom", "favorite", next_favorite)
	if _browser_storage != null:
		if not bool(_browser_storage.savePlayroomState(config.encode_to_text())):
			return _fail("Could not save browser playroom choices. Browser storage may be unavailable or full.")
		return true
	if not _restore_previous():
		return false
	var staged := _save_path + ".pending"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		_fail("Could not open the staged playroom save at %s: %s." % [staged, error_string(FileAccess.get_open_error())])
		_discard_staged(staged)
		return false
	var written: bool = file.store_string(config.encode_to_text())
	file.flush()
	var status := file.get_error()
	file.close()
	if not written or status != OK:
		_fail("Could not write playroom choices to %s: %s." % [staged, error_string(status if status != OK else ERR_FILE_CANT_WRITE)])
		_discard_staged(staged)
		return false
	# Match medal saves: Windows may delete a rename destination before a failed move.
	var previous := _save_path + ".previous"
	var moved_previous: bool = FileAccess.file_exists(_save_path)
	if moved_previous:
		status = DirAccess.rename_absolute(_save_path, previous)
		if status != OK:
			_fail("Could not preserve the previous playroom save at %s: %s." % [_save_path, error_string(status)])
			_discard_staged(staged)
			return false
	status = DirAccess.rename_absolute(staged, _save_path)
	if status != OK:
		_fail("Could not replace the playroom save at %s: %s." % [_save_path, error_string(status)])
		if moved_previous:
			var restored := DirAccess.rename_absolute(previous, _save_path)
			if restored != OK:
				error += " Previous choices remain at %s; restoring them failed: %s." % [previous, error_string(restored)]
		_discard_staged(staged)
		return false
	return true


func _restore_previous() -> bool:
	if FileAccess.file_exists(_save_path) or DirAccess.dir_exists_absolute(_save_path):
		return true
	var previous := _save_path + ".previous"
	if DirAccess.dir_exists_absolute(previous):
		return _fail("The interrupted playroom save has an unreadable previous-save path: " + previous + ".")
	if FileAccess.file_exists(previous):
		var status := DirAccess.rename_absolute(previous, _save_path)
		if status != OK:
			return _fail("Could not restore previous playroom choices from %s: %s." % [previous, error_string(status)])
	return true


func _discard_staged(path: String) -> void:
	if FileAccess.file_exists(path):
		var status := DirAccess.remove_absolute(path)
		if status != OK:
			error += " Could not remove the unfinished save: %s." % error_string(status)


func _fail(message: String) -> bool:
	error = message
	return false

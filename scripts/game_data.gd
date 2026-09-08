extends RefCounted

const THEMES: Dictionary = {
	"spring": {"name": "Spring", "background": Color("#edf8ec"), "accent": Color("#438363"),
		"light": Color("#d7efc7"), "spark": Color("#75c66f"), "tint": Color("#dff6de"),
		"chest": "royal", "prize": "A spring flower!"},
	"summer": {"name": "Summer", "background": Color("#ffe6e6"), "accent": Color("#b53640"),
		"light": Color("#ffc6cb"), "spark": Color("#ff8f9d"), "tint": Color("#ffe3e8"),
		"chest": "energy", "prize": "A summer sun!"},
	"autumn": {"name": "Autumn", "background": Color("#fff8cf"), "accent": Color("#8f7400"),
		"light": Color("#ffe07a"), "spark": Color("#ffd24d"), "tint": Color("#fff0ad"),
		"chest": "royal", "prize": "An autumn leaf!"},
	"winter": {"name": "Winter", "background": Color.WHITE, "accent": Color("#606a73"),
		"light": Color("#eef2f4"), "spark": Color("#d8dee3"), "tint": Color("#f5f7f8"),
		"chest": "crystal", "prize": "A winter snowflake!"}
}
const REWARD_NAMES: Dictionary = {
	"spring": ["Blossom", "Ladybug", "Bee", "Tulip", "Rainbow", "Bunny", "Sprout", "Butterfly", "Nest", "Dewdrop"],
	"summer": ["Sunbeam", "Seashell", "Lemon", "Kite", "Sandcastle", "Watermelon", "Sunglasses", "Starfish", "Surfboard", "Firefly"],
	"autumn": ["Maple Leaf", "Acorn", "Pumpkin", "Mushroom", "Apple", "Scarf", "Pinecone", "Lantern", "Squirrel", "Harvest Moon"],
	"winter": ["Snowflake", "Mitten", "Snowman", "Ice Crystal", "Sled", "Penguin", "Cocoa", "Polar Bear", "Bell", "Northern Star"]
}

var words: Array = []
var chests: Dictionary = {}
var error: String = ""


static func theme(id: String) -> Dictionary:
	assert(THEMES.has(id), "Unknown season: " + id)
	var result: Dictionary = THEMES[id].duplicate(true)
	result.id = id
	result.symbol = "res://assets/images/rewards/" + id + ".svg"
	return result


static func rewards(theme_id: String) -> Array:
	var result: Array = []
	if not REWARD_NAMES.has(theme_id):
		return result
	var palette: Dictionary = theme(theme_id)
	for index in range(REWARD_NAMES[theme_id].size()):
		result.append({
			"id": "%s-%d" % [theme_id, index + 1],
			"theme": theme_id,
			"name": REWARD_NAMES[theme_id][index],
			"number": index + 1,
			"symbol": palette.symbol
		})
	return result


static func reward(id: String) -> Dictionary:
	for theme_id in REWARD_NAMES:
		for value in rewards(theme_id):
			if value.id == id:
				return value
	return {}


static func validate_words(value: Variant) -> String:
	if not value is Array or value.size() < 5:
		return "Please add at least five words to words.json."
	var ids: Dictionary = {}
	var texts: Dictionary = {}
	var images: Dictionary = {}
	var id_pattern := RegEx.new()
	var text_pattern := RegEx.new()
	id_pattern.compile("^[a-z][a-z0-9-]*$")
	text_pattern.compile("^[a-z]{2,6}$")
	for entry in value:
		if not entry is Dictionary:
			return "Each word must have an id, text, image and audio."
		for key in ["id", "text", "image", "audio"]:
			if not entry.has(key) or not entry[key] is String:
				return "Each word must have an id, text, image and audio."
		if id_pattern.search(entry.id) == null or text_pattern.search(entry.text) == null:
			return "Use a unique word ID and a lowercase English word with 2 to 6 letters."
		if ids.has(entry.id) or texts.has(entry.text) or images.has(entry.image):
			return "Word IDs, words and pictures must be unique."
		if not _local_path(entry.image, "assets/images/words/", ["svg", "png", "webp"]):
			return "Keep word pictures together in assets/images/words."
		if not _local_path(entry.audio, "assets/audio/voice/", ["wav", "ogg"]):
			return "Keep word recordings in assets/audio/voice."
		ids[entry.id] = true
		texts[entry.text] = true
		images[entry.image] = true
	return ""


static func _local_path(path: String, prefix: String, extensions: Array) -> bool:
	if not path.begins_with(prefix) or path.contains("..") or path.contains("\\") or path.contains(":"):
		return false
	return not path.trim_prefix(prefix).contains("/") and extensions.has(path.get_extension())


func load_all() -> bool:
	error = ""
	words.clear()
	chests.clear()
	var value: Variant = _read_json("res://words.json")
	if not error.is_empty():
		return false
	error = validate_words(value)
	if not error.is_empty():
		return false
	words = value
	for word in words:
		if not ResourceLoader.exists("res://" + word.image):
			error = "Could not load the picture for " + word.text + ". Please rebuild the game."
			return false
	value = _read_json("res://assets/chests/manifest.json")
	if not error.is_empty():
		return false
	if not value is Dictionary or value.get("version") != 1:
		error = "The chest artwork manifest is missing or unsupported."
		return false
	if not value.get("styles") is Dictionary or not value.get("particles") is Dictionary:
		error = "The chest artwork manifest is incomplete."
		return false
	for style in ["royal", "energy", "crystal"]:
		if not value.styles.get(style) is Dictionary:
			error = "The " + style + " chest is missing."
			return false
	if not value.styles.crystal.get("parts") is Array or value.styles.crystal.parts.size() != 9:
		error = "The Crystal chest needs all nine pieces."
		return false
	if not value.get("files") is Array or value.files.size() != 19:
		error = "The chest artwork import is incomplete."
		return false
	for file in value.files:
		if not file is Dictionary or not file.get("path") is String:
			error = "The chest artwork path is invalid."
			return false
		var path: String = file.path
		if not path.begins_with("assets/chests/") or path.contains("..") or path.contains("\\"):
			error = "Chest artwork must be inside assets/chests."
			return false
		if not ResourceLoader.exists("res://" + path):
			error = "Could not load chest artwork. Please rebuild the game."
			return false
	chests = value
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		error = "Could not load " + path.get_file() + ". Please rebuild the game."
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		error = "%s has invalid JSON on line %d." % [path.get_file(), parser.get_error_line() + 1]
		return null
	return parser.data

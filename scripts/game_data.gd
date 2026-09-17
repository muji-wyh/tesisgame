extends RefCounted

const GAME_NAME: String = "Pip and Words"
const PIECES_PER_MEDAL: int = 3
const AGE_BANDS: Array[Dictionary] = [
	{"id": "all", "name": "All words", "label": "All", "max_level": 3},
	{"id": "4-6", "name": "Ages 4-6", "label": "4-6", "max_level": 1},
	{"id": "7-9", "name": "Ages 7-9", "label": "7-9", "max_level": 2},
	{"id": "10-plus", "name": "Ages 10+", "label": "10+", "max_level": 3}
]
const ADVENTURES: Array[Dictionary] = [
	{"id": "animal-friends", "name": "Animal friends", "words": [
		"cat", "dog", "fish", "duck", "cow", "pig", "hen", "sheep", "horse", "goat", "rabbit", "mouse",
		"bear", "lion", "tiger", "monkey", "panda", "zebra", "fox", "owl", "frog", "turtle", "bee", "ant",
		"elephant", "giraffe", "kangaroo", "penguin", "squirrel"]},
	{"id": "picnic-time", "name": "Picnic time", "words": [
		"apple", "banana", "orange", "pear", "grape", "cherry", "melon", "carrot", "tomato", "corn", "peas",
		"egg", "bread", "cake", "cookie", "cheese", "milk", "water", "juice", "rice",
		"pumpkin", "coconut", "pineapple", "watermelon", "strawberry"]},
	{"id": "great-outdoors", "name": "Great outdoors", "words": [
		"sun", "moon", "star", "cloud", "rain", "snow", "tree", "leaf", "flower",
		"river", "lake", "mountain", "rainbow", "waterfall"]},
	{"id": "dress-up", "name": "Dress up", "words": [
		"hat", "coat", "shirt", "dress", "sock", "shoe", "glove", "scarf",
		"boot", "skirt", "pants", "vest", "tie", "ring", "watch", "crown",
		"helmet", "sweater", "necklace", "bracelet", "sunglasses"]},
	{"id": "on-the-move", "name": "On the move", "words": [
		"car", "bus", "train", "truck", "plane", "boat", "bike",
		"scooter", "tractor", "ambulance", "helicopter", "submarine"]},
	{"id": "play-time", "name": "Play time", "words": [
		"ball", "book", "doll", "kite", "drum", "block",
		"robot", "puzzle", "marble", "balloon", "skateboard"]},
	{"id": "at-home", "name": "At home", "words": [
		"bed", "chair", "table", "door", "lamp", "clock", "key", "phone", "cup", "bowl", "plate", "spoon",
		"fork", "soap", "brush", "towel", "window", "mirror", "pillow", "blanket", "sofa"]},
	{"id": "head-to-toe", "name": "Head to toe", "words": [
		"eye", "ear", "nose", "mouth", "hand", "foot", "arm", "leg", "head", "tooth",
		"finger", "thumb", "elbow", "knee", "ankle"]},
	{"id": "ocean-discovery", "name": "Ocean discovery", "words": [
		"whale", "shark", "crab", "seal", "shell", "coral", "squid", "clam",
		"dolphin", "octopus", "jellyfish", "seahorse", "starfish"]},
	{"id": "space-trip", "name": "Space trip", "words": [
		"earth", "rocket", "planet", "comet", "meteor", "alien", "rover", "galaxy",
		"astronaut", "satellite", "telescope", "spaceship", "asteroid"]},
	{"id": "garden-trail", "name": "Garden trail", "words": [
		"seed", "root", "grass", "rose", "berry", "acorn", "pebble", "pond",
		"mushroom", "cactus", "bamboo", "pinecone", "sunflower"]},
	{"id": "music-makers", "name": "Music makers", "words": [
		"piano", "flute", "violin", "guitar", "bell", "harp", "horn", "tuba",
		"trumpet", "saxophone", "xylophone", "cymbal", "microphone"]}
]
const THEMES: Dictionary = {
	"spring": {"name": "Spring", "background": Color("#effbef"), "accent": Color("#237a57"),
		"light": Color("#bfe9c5"), "spark": Color("#ffa8bb"), "tint": Color("#eefbd6"),
		"chest": "royal", "prize": "A spring flower!"},
	"summer": {"name": "Summer", "background": Color("#fff4df"), "accent": Color("#b94545"),
		"light": Color("#ffd192"), "spark": Color("#21afbc"), "tint": Color("#fff0cd"),
		"chest": "energy", "prize": "A summer sun!"},
	"autumn": {"name": "Autumn", "background": Color("#fff2e5"), "accent": Color("#995323"),
		"light": Color("#ffd19b"), "spark": Color("#b46386"), "tint": Color("#ffe6c5"),
		"chest": "royal", "prize": "An autumn leaf!"},
	"winter": {"name": "Winter", "background": Color("#eef5ff"), "accent": Color("#456791"),
		"light": Color("#c9dcf5"), "spark": Color("#aa97d4"), "tint": Color("#e6edff"),
		"chest": "crystal", "prize": "A winter snowflake!"},
	"ocean": {"name": "Ocean", "background": Color("#e7f8fa"), "accent": Color("#13758b"),
		"light": Color("#afdee6"), "spark": Color("#ffad87"), "tint": Color("#e1f4ef"),
		"chest": "crystal", "prize": "An ocean treasure!"},
	"space": {"name": "Space", "background": Color("#f1edfb"), "accent": Color("#694a99"),
		"light": Color("#d6c8f0"), "spark": Color("#efb451"), "tint": Color("#eae3ff"),
		"chest": "energy", "prize": "A space treasure!"}
}
const REWARD_NAMES: Dictionary = {
	"spring": ["Blossom", "Ladybug", "Bee", "Tulip", "Rainbow", "Bunny", "Sprout", "Butterfly", "Nest", "Dewdrop"],
	"summer": ["Sunbeam", "Seashell", "Lemon", "Kite", "Sandcastle", "Watermelon", "Sunglasses", "Starfish", "Surfboard", "Firefly"],
	"autumn": ["Maple Leaf", "Acorn", "Pumpkin", "Mushroom", "Apple", "Scarf", "Pinecone", "Lantern", "Squirrel", "Harvest Moon"],
	"winter": ["Snowflake", "Mitten", "Snowman", "Ice Crystal", "Sled", "Penguin", "Cocoa", "Polar Bear", "Bell", "Northern Star"],
	"ocean": ["Whale", "Seashell", "Crab", "Coral", "Squid", "Pearl"],
	"space": ["Rocket", "Ringed Planet", "Comet", "Moon Rover", "Galaxy", "Earth"]
}

var words: Array = []
var chests: Dictionary = {}
var error: String = ""


static func age_bands() -> Array[Dictionary]:
	return AGE_BANDS.duplicate(true)


static func age_band(id: String) -> Dictionary:
	for band in AGE_BANDS:
		if band.id == id:
			return band.duplicate(true)
	return {}


static func word_level(word: Dictionary) -> int:
	match word.get("level", "basic"):
		"basic": return 1
		"growing": return 2
		"advanced": return 3
	return 0


static func confusable_words(first: String, second: String) -> bool:
	if first == second:
		return true
	for pair in [["earth", "planet"], ["acorn", "seed"], ["boot", "shoe"],
		["shell", "clam"], ["flower", "rose"], ["comet", "meteor"],
		["rocket", "spaceship"], ["asteroid", "meteor"], ["asteroid", "comet"],
		["flower", "sunflower"], ["rose", "sunflower"], ["melon", "watermelon"],
		["berry", "strawberry"]]:
		if first in pair and second in pair:
			return true
	return false


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
			"symbol": "res://assets/images/rewards/%s-%d.svg" % [theme_id, index + 1]
		})
	return result


static func reward(id: String) -> Dictionary:
	for theme_id in REWARD_NAMES:
		for value in rewards(theme_id):
			if value.id == id:
				return value
	return {}


static func medals(theme_id: String) -> Array:
	return rewards(theme_id).slice(0, 6)


static func medal(id: String) -> Dictionary:
	var result: Dictionary = reward(id)
	return result if not result.is_empty() and result.number <= 6 else {}


static func validate_words(value: Variant) -> String:
	if not value is Array or value.size() < 5:
		return "Please add at least five words to words.json."
	var ids: Dictionary = {}
	var texts: Dictionary = {}
	var images: Dictionary = {}
	var id_pattern := RegEx.new()
	var text_pattern := RegEx.new()
	id_pattern.compile("^[a-z][a-z0-9-]*$")
	text_pattern.compile("^[a-z]{2,10}$")
	for entry in value:
		if not entry is Dictionary:
			return "Each word must have an id, text, image and audio."
		for key in ["id", "text", "image", "audio"]:
			if not entry.has(key) or not entry[key] is String:
				return "Each word must have an id, text, image and audio."
		if id_pattern.search(entry.id) == null or text_pattern.search(entry.text) == null:
			return "Use a unique word ID and a lowercase English word with 2 to 10 letters."
		if word_level(entry) == 0:
			return "Word levels must be basic, growing or advanced."
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
		var imported_image: String = "assets/imported-unity/" + word.id + ".png"
		if ResourceLoader.exists("res://" + imported_image):
			word.image = imported_image
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

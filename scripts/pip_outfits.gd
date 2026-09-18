extends RefCounted

const THEME_IDS := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]
const DIRECTORY := "res://assets/images/mascots/outfits/"


static func normalize_theme(value: String) -> String:
	return value if value in THEME_IDS else "spring"


static func load_sheets(value: String) -> Array[Texture2D]:
	var chosen := normalize_theme(value)
	var result: Array[Texture2D] = []
	# Load only the active wardrobe. Pip instances share Godot's resource cache.
	for suffix in ["", "-idle", "-parts"]:
		result.append(load(DIRECTORY + "pip-" + chosen + suffix + ".svg") as Texture2D)
	return result

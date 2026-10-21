extends RefCounted
## Career artwork is independent of growth age, world color and mastery level.

const CATALOG_PATH := "res://data/pip-professional.json"
static var _profiles: Dictionary = {}


static func profile(course_id: String) -> Dictionary:
	if _profiles.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if parsed is Dictionary and parsed.get("schema_version") == 1:
			for entry: Variant in parsed.get("profiles", []):
				if entry is Dictionary and entry.get("course_id") is String:
					_profiles[entry.course_id] = entry
	return _profiles.get(course_id, {}).duplicate(true)


static func portrait(course_id: String) -> Texture2D:
	var selected: Dictionary = profile(course_id)
	if selected.is_empty():
		return null
	var texture: Texture2D = load("res://" + str(selected.art.regular)) as Texture2D
	if texture == null:
		return null
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(0, 0, texture.get_height(), texture.get_height())
	return frame

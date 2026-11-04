extends Sprite2D
## Four source-derived illustrations; the caller owns transitions and rewards.

const CATALOG_PATH: String = "res://assets/chests/catalog/chest-states.json"
const STATES: Array[String] = ["closed", "open", "treasure", "magic"]

@export var asset_id: String = ""
@export_enum("closed", "open", "treasure", "magic") var initial_state: String = "closed"

var last_error: String = ""
var _entry: Dictionary = {}
var _textures: Dictionary = {}
var _state: String = "closed"


func _ready() -> void:
	if not asset_id.is_empty() and _textures.is_empty():
		if configure(asset_id):
			set_state(initial_state)


func configure(id: String) -> bool:
	_entry.clear()
	_textures.clear()
	texture = null
	last_error = ""
	asset_id = id
	if not FileAccess.file_exists(CATALOG_PATH):
		return _fail("Chest state catalog is missing")
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not catalog is Dictionary or not catalog.get("variants") is Array:
		return _fail("Chest state catalog is invalid")
	for candidate: Variant in catalog.variants:
		if candidate is Dictionary and str(candidate.get("id", "")) == id:
			_entry = candidate.duplicate(true)
			break
	if _entry.is_empty() or str(_entry.get("asset_type", "")) != "sprites":
		return _fail("Unknown 2D chest asset: " + id)
	var dimensions := Vector2.ZERO
	for state: String in STATES:
		var filename: String = str(_entry.get("states", {}).get(state, ""))
		var resource_path: String = filename if filename.begins_with("res://") else "res://" + filename
		if not resource_path.begins_with("res://assets/chests/sprites/") \
			or resource_path.contains("..") or resource_path.contains("\\") \
			or not ResourceLoader.exists(resource_path, "Texture2D"):
			return _fail("Source-derived chest state image is missing: " + id + "/" + state)
		var image := load(resource_path) as Texture2D
		if image == null or image.get_width() <= 0 or image.get_height() <= 0:
			return _fail("Source-derived chest state image is invalid: " + resource_path)
		if dimensions == Vector2.ZERO:
			dimensions = image.get_size()
		elif image.get_size() != dimensions:
			return _fail("Chest state images do not share the same framing: " + id)
		_textures[state] = image
	return set_state("closed")


func set_state(value: String) -> bool:
	if not value in STATES or not _textures.has(value):
		return false
	_state = value
	texture = _textures[value]
	return true


func debug_state() -> Dictionary:
	return {"id": asset_id, "state": _state,
		"configured": texture != null and last_error.is_empty(),
		"texture": texture.resource_path if texture != null else "",
		"dimensions": texture.get_size() if texture != null else Vector2.ZERO,
		"authorship": _entry.get("authorship", ""), "error": last_error}


func _fail(message: String) -> bool:
	_entry.clear()
	_textures.clear()
	texture = null
	last_error = message
	return false

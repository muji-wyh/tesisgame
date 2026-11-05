extends RefCounted
## Sequential gameplay levels use the selected Atelier models and their authored finishes.

const MAX_TIER: int = 99
const MATERIAL_COUNT: int = 28
const PRESETS_PATH: String = "res://assets/chests/catalog/gameplay-chests.json"
const THEME_TIERS: Dictionary = {
	"spring": 15, "royal": 15, "summer": 21, "energy": 21,
	"autumn": 9, "harvest": 9, "winter": 20, "crystal": 20,
	"ocean": 16, "tide": 16, "space": 28, "nebula": 28,
	"jungle": 11, "bramble": 11, "candy": 12, "bonbon": 12}

static var _loaded: bool = false
static var _presets: Dictionary = {}
static var _manifest: Dictionary = {}
static var _last_error: String = ""


static func preset(tier: int) -> Dictionary:
	_last_error = ""
	if not _valid_tier(tier) or not _load_catalog():
		return {}
	return _presets[tier].duplicate(true)


static func manifest() -> Dictionary:
	_last_error = ""
	return _manifest.duplicate(true) if _load_catalog() else {}


static func error() -> String:
	return _last_error


static func style(tier: int, supplied_manifest: Dictionary = {}) -> Dictionary:
	var recipe: Dictionary = preset(tier)
	if recipe.is_empty():
		return {}
	var source_id: String = str(recipe.base_source_id)
	var supplied_styles: Variant = supplied_manifest.get("styles", {})
	var source: Variant = supplied_styles.get(source_id, {}) if supplied_styles is Dictionary else {}
	if not source is Dictionary or str(source.get("model", "")) != str(recipe.base_model):
		source = _manifest.styles.get(source_id, {})
	if not source is Dictionary or source.is_empty():
		_fail("Chest level %d needs its selected Atelier source style." % tier)
		return {}
	var result: Dictionary = source.duplicate(true)
	result["tier"] = tier
	result["preset_id"] = str(recipe.id)
	result["name"] = str(recipe.name)
	result["base_source_id"] = source_id
	result["source_model"] = str(recipe.base_model)
	result["model"] = str(recipe.base_model)
	result["material_style"] = str(recipe.material_style)
	result["repeated_material"] = bool(recipe.repeated_material)
	# The Atelier GLBs already contain fitted details and finished materials.
	# Recoloring or attaching the former ornaments would alter the approved asset.
	result["decorations"] = []
	result["material_profile"] = {}
	result["material_authorship"] = "atelier-authored-source-materials"
	result["normalize_model"] = false
	result["atlas_trim"] = {}
	return result


static func theme_tier(theme: String) -> int:
	_last_error = ""
	var key: String = theme.to_lower()
	if THEME_TIERS.has(key):
		return int(THEME_TIERS[key])
	_fail("Unknown chest theme/style alias: " + theme)
	return 0


static func atlas_regions(_path: String) -> Dictionary:
	# Authored Atelier finishes have no runtime metal recoloring masks.
	return {}


static func _valid_tier(tier: int) -> bool:
	if tier >= 1 and tier <= MAX_TIER:
		return true
	_last_error = "Chest tier must be 1..%d, received %d" % [MAX_TIER, tier]
	return false


static func _load_catalog() -> bool:
	if _loaded:
		return _presets.size() == MAX_TIER
	if not FileAccess.file_exists(PRESETS_PATH):
		return _fail("Missing selected Atelier chest catalog: " + PRESETS_PATH)
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESETS_PATH))
	if not content is Dictionary or content.get("version") != 1 \
		or not content.get("tiers") is Array or not content.get("styles") is Dictionary \
		or not content.get("particles") is Dictionary or not content.get("files") is Array:
		return _fail("Invalid selected Atelier chest catalog: " + PRESETS_PATH)
	if int(content.get("max_tier", 0)) != MAX_TIER or int(content.get("tier_count", 0)) != MAX_TIER \
		or content.tiers.size() != MAX_TIER or int(content.get("material_count", 0)) != MATERIAL_COUNT \
		or not content.get("material_ids") is Array or content.material_ids.size() != MATERIAL_COUNT:
		return _fail("The selected Atelier catalog needs 99 gameplay levels and 28 source materials.")
	var parsed: Dictionary = {}
	var ids: Dictionary = {}
	var sources: Array[String] = []
	for value: Variant in content.tiers:
		if not value is Dictionary or not value.has_all([
			"level", "id", "name", "asset_id", "base_model", "base_source_id",
			"material_style", "decorations", "repeated_material"]):
			return _fail("Incomplete selected Atelier chest level.")
		var tier: int = int(value.level)
		var source_id: String = str(value.base_source_id)
		var source: Variant = content.styles.get(source_id, {})
		if tier < 1 or tier > MAX_TIER or parsed.has(tier) or ids.has(str(value.id)) \
			or not str(value.id).begins_with("tier-%02d-" % tier) \
			or source_id != str(value.asset_id) or source_id != str(value.material_style) \
			or not _safe_model_path(str(value.base_model)) \
			or not value.decorations is Array or not value.decorations.is_empty() \
			or not source is Dictionary or str(source.get("model", "")) != str(value.base_model):
			return _fail("Invalid selected Atelier chest level: " + str(value.id))
		if not source.get("state_asset_id") is String or str(source.state_asset_id) != source_id \
			or not _safe_state_path(str(source.get("state_scene", ""))) \
			or not source.get("model_parts") is Array or str(source.get("open_animation", "")) != "Open" \
			or not source.get("closed_bounds_3d") is Dictionary or not source.get("treasure") is Dictionary \
			or not source.get("magic") is Dictionary:
			return _fail("Selected Atelier chest states are incomplete: " + source_id)
		if tier <= MATERIAL_COUNT:
			if sources.has(source_id) or bool(value.repeated_material) \
				or str(content.material_ids[tier - 1]) != source_id:
				return _fail("Selected Atelier chest materials must retain their unique ranking order.")
			sources.append(source_id)
		elif source_id != str(content.material_ids[MATERIAL_COUNT - 1]) or not bool(value.repeated_material):
			return _fail("Later chest levels must reuse the last selected Atelier material.")
		parsed[tier] = value.duplicate(true)
		ids[str(value.id)] = true
	for tier in range(1, MAX_TIER + 1):
		if not parsed.has(tier):
			return _fail("Missing selected Atelier chest level %d." % tier)
	for alias: String in THEME_TIERS:
		if int(content.get("theme_tiers", {}).get(alias, 0)) != int(THEME_TIERS[alias]):
			return _fail("The selected Atelier chest theme mapping is inconsistent: " + alias)
	for alias: String in ["royal", "energy", "harvest", "crystal", "tide", "nebula", "bramble", "bonbon"]:
		if not content.styles.get(alias) is Dictionary:
			return _fail("The selected Atelier chest palette alias is missing: " + alias)
	_presets = parsed
	_manifest = content.duplicate(true)
	_loaded = true
	return true


static func _safe_model_path(path: String) -> bool:
	return path.begins_with("assets/chests/models/atelier/") and path.ends_with(".glb") \
		and not path.contains("..") and not path.contains("\\")


static func _safe_state_path(path: String) -> bool:
	return path.begins_with("assets/chests/models/atelier/") and path.ends_with("-states.tscn") \
		and not path.contains("..") and not path.contains("\\")


static func _fail(message: String) -> bool:
	_last_error = message
	push_error(message)
	return false

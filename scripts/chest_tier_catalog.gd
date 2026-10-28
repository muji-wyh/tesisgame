extends RefCounted
## Game-authored assemblies of nine acquired bases, not thirty native meshes.

const MAX_TIER: int = 30
const PRESETS_PATH: String = "res://assets/chests/tier-presets.json"
const POLISHED_MODELS: Dictionary = {
	"assets/chests/catalog-cc0/kenney-survival/chest.glb": "assets/chests/polished-cc0/kenney-survival.glb",
	"assets/chests/catalog-cc0/kenney-platformer/chest.glb": "assets/chests/polished-cc0/kenney-platformer.glb",
	"assets/chests/catalog-cc0/kenney-mini-dungeon/chest.glb": "assets/chests/polished-cc0/kenney-mini-dungeon.glb",
	"assets/chests/catalog-cc0/kaykit-dungeon/chest.glb": "assets/chests/polished-cc0/kaykit-dungeon.glb"
}
const THEME_TIERS: Dictionary = {
	"spring": 30, "royal": 30,
	"summer": 10, "energy": 10,
	"autumn": 16, "harvest": 16,
	"winter": 28, "crystal": 28,
	"ocean": 19, "tide": 19,
	"space": 27, "nebula": 27,
	"jungle": 13, "bramble": 13,
	"candy": 23, "bonbon": 23
}

static var _loaded: bool = false
static var _presets: Dictionary = {}
static var _profiles: Dictionary = {}
static var _last_error: String = ""


static func preset(tier: int) -> Dictionary:
	_last_error = ""
	if not _valid_tier(tier) or not _load_catalog():
		if _last_error.is_empty():
			_last_error = "The acquired thirty-tier chest catalog is unavailable"
		return {}
	return _presets[tier].duplicate(true)


static func error() -> String:
	return _last_error


static func style(tier: int, manifest: Dictionary) -> Dictionary:
	var recipe: Dictionary = preset(tier)
	if recipe.is_empty():
		return {}
	var path: String = str(recipe.base_model)
	var result: Dictionary = {}
	if path.begins_with("assets/chests/models/"):
		for source: Variant in manifest.get("styles", {}).values():
			if source is Dictionary and source.get("model", "") == path:
				result = source.duplicate(true)
				break
		if result.is_empty():
			_last_error = "Chest tier %d requires its original model/animation style: %s" % [tier, path]
			push_error(_last_error)
			return {}
	else:
		var kaykit: bool = path.contains("/kaykit-")
		result = {
			"model": path,
			"open_animation": "" if kaykit else str(recipe.get("open_animation", "open")),
			"open_start": 0.0,
			"open_end": 0.3,
			"model_parts": [{
				"node": "chest_lid" if kaykit else "lid",
				"role": "lid", "axis": [1, 0, 0],
				"angle": -PI * 0.51
			}],
			"camera_direction": [0.56, 0.46, 1.0],
			"camera_margin": 1.12
		}
	result["tier"] = tier
	result["source_model"] = path
	result["model"] = str(POLISHED_MODELS.get(path, path))
	result["preset_id"] = str(recipe.id)
	result["name"] = str(recipe.name)
	result["base_source_id"] = str(recipe.base_source_id)
	result["decorations"] = recipe.decorations.duplicate(true)
	result["material_style"] = str(recipe.material_style)
	result["material_profile"] = _profiles[recipe.material_style].duplicate(true)
	result["material_authorship"] = "game-authored-runtime-adaptation"
	result["normalize_model"] = true
	# These GLBs are already +Y-up/+Z-front, including the private root transforms.
	result["source_rotation_degrees"] = [0, 0, 0]
	result["attachment_target"] = "body"
	result["atlas_trim"] = atlas_regions(path)
	return result


static func theme_tier(theme: String) -> int:
	_last_error = ""
	var key: String = theme.to_lower()
	if THEME_TIERS.has(key):
		return int(THEME_TIERS[key])
	_last_error = "Unknown chest theme/style alias: " + theme
	return 0


static func atlas_regions(path: String) -> Dictionary:
	# Original GLB UVs and their atlas pixels were sampled before assigning roles.
	# Brown wood swatches are deliberately outside these binding/metal masks.
	if path.ends_with("/kenney-survival/chest.glb"):
		return {"regions": [[0.32, 0.75, 0.37, 1.0]], "reference": "#9da4c4",
			"evidence": "colormap: u=0.34375, v=0.775..0.975; blue-grey binding"}
	if path.ends_with("/kenney-platformer/chest.glb"):
		return {"regions": [[0.19, 0.50, 0.245, 0.75]], "reference": "#9da4c4",
			"evidence": "colormap: u=0.21875, v=0.525..0.675; blue-grey binding"}
	if path.ends_with("/kenney-mini-dungeon/chest.glb"):
		return {"regions": [[0.07, 0.75, 0.12, 1.0]], "reference": "#9da4c4",
			"evidence": "colormap: u=0.09375, v=0.775..0.975; blue-grey binding"}
	if path.ends_with("/kaykit-dungeon/chest.glb"):
		return {"regions": [[0.12, 0.045, 0.24, 0.23]], "reference": "#7e888d",
			"evidence": "dungeon_texture: u=0.132..0.223, v=0.054..0.218; iron; brown wood at u=0.51..0.60"}
	if path.ends_with("/shield-rectangle.glb"):
		return {"regions": [[0.82, 0.75, 0.87, 1.0]], "reference": "#9da4c4"}
	if path.ends_with("/shield-round.glb"):
		return {"regions": [[0.82, 0.75, 0.87, 1.0], [0.57, 0.75, 0.62, 1.0]],
			"reference": "#9da4c4"}
	if path.ends_with("/coin-gold.glb"):
		return {"regions": [[0.07, 0.25, 0.12, 0.50]], "reference": "#ffb349"}
	if path.ends_with("/lock.glb"):
		return {"regions": [[0.07, 0.25, 0.12, 0.50], [0.94, 0.75, 0.995, 1.0]],
			"reference": "#ffb349"}
	return {}


static func _valid_tier(tier: int) -> bool:
	if tier >= 1 and tier <= MAX_TIER:
		return true
	_last_error = "Chest tier must be 1..%d, received %d" % [MAX_TIER, tier]
	return false


static func _load_catalog() -> bool:
	if _loaded:
		return _presets.size() == MAX_TIER
	_loaded = true
	if not FileAccess.file_exists(PRESETS_PATH):
		push_error("Missing acquired chest tier catalog: " + PRESETS_PATH)
		return false
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESETS_PATH))
	if not content is Dictionary or not content.get("tiers") is Array:
		push_error("Invalid chest tier catalog: " + PRESETS_PATH)
		return false
	var profiles: Variant = content.get("source_notes", {}).get("material_styles", {})
	if not profiles is Dictionary or content.tiers.size() != MAX_TIER:
		push_error("Chest tier catalog must define thirty tiers and material profiles")
		return false
	var parsed: Dictionary = {}
	var ids: Dictionary = {}
	for value: Variant in content.tiers:
		if not value is Dictionary or not value.has_all([
			"level", "id", "name", "base_model", "base_source_id", "material_style", "decorations"
		]):
			push_error("Incomplete chest tier recipe")
			return false
		var tier: int = int(value.level)
		if tier < 1 or tier > MAX_TIER or parsed.has(tier) or ids.has(str(value.id)) \
			or not str(value.id).begins_with("tier-%02d-" % tier) \
			or not _safe_model_path(str(value.base_model)) \
			or not profiles.get(value.material_style) is Dictionary \
			or not value.decorations is Array:
			push_error("Invalid or duplicate chest tier recipe: " + str(value.id))
			return false
		var slots: Dictionary = {}
		for entry: Variant in value.decorations:
			if not entry is Dictionary or not entry.has_all(["model", "slot", "scale", "rotation_degrees"]):
				push_error("Incomplete source ornament in " + str(value.id))
				return false
			var slot: String = str(entry.slot)
			if not _safe_model_path(str(entry.model)) or slots.has(slot) \
				or slot not in ["front", "left", "right", "front-left", "front-right"] \
				or not is_finite(float(entry.scale)) or float(entry.scale) <= 0.0 \
				or not entry.rotation_degrees is Array or entry.rotation_degrees.size() != 3:
				push_error("Invalid source ornament in " + str(value.id))
				return false
			for component: Variant in entry.rotation_degrees:
				if not (component is int or component is float) or not is_finite(float(component)):
					push_error("Invalid ornament orientation in " + str(value.id))
					return false
			slots[slot] = true
		parsed[tier] = value.duplicate(true)
		ids[str(value.id)] = true
	for tier in range(1, MAX_TIER + 1):
		if not parsed.has(tier):
			push_error("Missing chest tier %d" % tier)
			return false
	_presets = parsed
	_profiles = profiles.duplicate(true)
	return true


static func _safe_model_path(path: String) -> bool:
	return path.begins_with("assets/chests/") and path.ends_with(".glb") \
		and not path.contains("..") and not path.contains("\\")

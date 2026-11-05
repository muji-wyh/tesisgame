extends Node
## Reuses the production closed chest render for markers and final-tier rewards.

const Chest = preload("res://scripts/chest_view.gd")
const Data = preload("res://scripts/game_data.gd")
const Progress = preload("res://scripts/jelly_reward_progress.gd")
const Tiers = preload("res://scripts/chest_tier_catalog.gd")
const FALLBACK = preload("res://assets/chests/shared/ui/chest.png")

var _manifest: Dictionary = {}
var _cache: Dictionary = {}


func configure(manifest: Dictionary) -> void:
	_manifest = manifest
	texture(1)
	texture(2)


func texture(tier: int) -> Texture2D:
	if _manifest.is_empty() or not is_inside_tree():
		return FALLBACK
	var selected: int = clampi(tier, 1, Progress.MAX_TIER)
	var recipe: Dictionary = Tiers.preset(selected)
	if recipe.is_empty():
		return FALLBACK
	var id: String = Progress.theme_for_tier(selected)
	# Levels 29..99 deliberately reuse the last source model. Visual caches
	# follow that source identity rather than retaining another renderer per Lv.
	var key: String = str(recipe.asset_id)
	if not _cache.has(key):
		var viewport := SubViewport.new()
		viewport.name = "VoicePopChest_" + key
		viewport.size = Vector2i(768, 768)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var art := Chest.new()
		viewport.add_child(art)
		art.size = Vector2(768, 768)
		art.reduced_motion = true
		art.configure_tier(selected, Data.theme(id), _manifest)
		# Updating this wrapper also updates references already stored by the
		# HUD or reward queue, before the old render texture is released.
		var artwork := AtlasTexture.new()
		artwork.atlas = viewport.get_texture()
		artwork.region = Rect2(Vector2.ZERO, Vector2(viewport.size))
		artwork.filter_clip = true
		_cache[key] = {"asset_id": key, "viewport": viewport, "art": art,
			"frames": 0, "texture": artwork, "image_texture": null,
			"cropped": false, "paused": false, "capture_wait": 0}
		set_process(true)
	return _cache[key].texture


func _process(_delta: float) -> void:
	var pending: bool = false
	for key: String in _cache.keys():
		var entry: Dictionary = _cache[key]
		var viewport: SubViewport = entry.get("viewport")
		if not is_instance_valid(viewport):
			continue
		entry.frames = mini(6, int(entry.frames) + 1)
		if int(entry.frames) < 6:
			pending = true
			continue
		if not bool(entry.paused):
			entry.art.set_idle_paused(true)
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			entry.paused = true
		if DisplayServer.get_name() == "headless":
			continue
		if int(entry.capture_wait) > 0:
			entry.capture_wait -= 1
			pending = true
			continue
		if not _capture(key, entry, viewport):
			entry.capture_wait = 5
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			pending = true
	set_process(pending)


func _capture(key: String, entry: Dictionary, viewport: SubViewport) -> bool:
	var picture: Image = viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		return false
	var bounds: Rect2i = picture.get_used_rect()
	if not bounds.has_area():
		return false
	bounds = bounds.grow(2).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	var captured := ImageTexture.create_from_image(picture.get_region(bounds))
	var artwork: AtlasTexture = entry.texture
	artwork.atlas = captured
	artwork.region = Rect2(Vector2.ZERO, captured.get_size())
	entry.image_texture = captured
	entry.cropped = true
	entry.viewport = null
	entry.art = null
	_cache[key] = entry
	remove_child(viewport)
	viewport.queue_free()
	return true

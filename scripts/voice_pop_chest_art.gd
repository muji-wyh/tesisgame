extends Node
## Reuses the production closed chest render for markers and final-tier rewards.

const Chest = preload("res://scripts/chest_view.gd")
const Data = preload("res://scripts/game_data.gd")
const Progress = preload("res://scripts/jelly_reward_progress.gd")
const FALLBACK = preload("res://assets/chests/royal/closed.png")

var _manifest: Dictionary = {}
var _cache: Dictionary = {}
var _fallback: AtlasTexture


func configure(manifest: Dictionary) -> void:
	_manifest = manifest
	texture(1)
	texture(2)


func texture(tier: int) -> Texture2D:
	if _manifest.is_empty() or not is_inside_tree():
		if _fallback == null:
			_fallback = AtlasTexture.new()
			_fallback.atlas = FALLBACK
			_fallback.region = Rect2(39, 309, 798, 596)
		return _fallback
	var id: String = Progress.theme_for_tier(tier)
	if not _cache.has(id):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(768, 768)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var art := Chest.new()
		viewport.add_child(art)
		art.size = Vector2(768, 768)
		art.reduced_motion = true
		art.configure_skin(Data.theme(id), _manifest)
		_cache[id] = {"viewport": viewport, "art": art, "frames": 0, "texture": viewport.get_texture()}
	return _cache[id].texture


func _process(_delta: float) -> void:
	for entry: Dictionary in _cache.values():
		if int(entry.frames) >= 6:
			continue
		entry.frames += 1
		if int(entry.frames) != 6:
			continue
		if DisplayServer.get_name() != "headless":
			var picture: Image = entry.viewport.get_texture().get_image()
			if picture != null and not picture.is_empty():
				var bounds: Rect2i = picture.get_used_rect()
				if bounds.has_area():
					bounds = bounds.grow(2).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
					entry.texture = ImageTexture.create_from_image(picture.get_region(bounds))
		entry.art.set_idle_paused(true)
		entry.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

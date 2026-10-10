extends Node
## Two reusable closed-model surfaces for an uninterrupted reward transition.

const ModelView = preload("res://scripts/chest_model_view.gd")
const Data = preload("res://scripts/game_data.gd")
const Progress = preload("res://scripts/jelly_reward_progress.gd")
const MANIFEST_PATH: String = "res://assets/chests/downloaded/manifest.json"
const POOL_LIMIT: int = 2

var _styles: Dictionary = {}
var _loaded: bool = false
var _pool: Dictionary = {}
var _order: Array[int] = []
var _active: bool = true


func prepare(tier: int) -> void:
	if tier < 1 or tier > 4 or _pool.has(tier):
		return
	if not _loaded:
		_loaded = true
		var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if content is Dictionary and content.get("styles") is Dictionary:
			_styles = content.styles
	var theme: Dictionary = Data.theme(Progress.theme_for_tier(tier))
	var source: Variant = _styles.get(str(theme.get("chest", "")))
	if not source is Dictionary or not source.has("model"):
		return
	var style: Dictionary = source.duplicate(true)
	# A full yaw needs a wider volume than the original lid-opening envelope.
	# Override only this private instance; the normal opening camera is intact.
	var box: Dictionary = style.get("closed_bounds_3d", {})
	var minimum: Array = box.get("min", [])
	var maximum: Array = box.get("max", [])
	if minimum.size() != 3 or maximum.size() != 3:
		return
	var half_x: float = maxf(absf(float(minimum[0])), absf(float(maximum[0])))
	var half_z: float = maxf(absf(float(minimum[2])), absf(float(maximum[2])))
	var radius: float = Vector2(half_x, half_z).length()
	style["motion_bounds_3d"] = {
		"min": [-radius, float(minimum[1]), -radius],
		"max": [radius, float(maximum[1]), radius]
	}
	style["camera_margin"] = 1.12
	style["max_resolution"] = 512
	while _order.size() >= POOL_LIMIT:
		_release(_order[0])
	var view := ModelView.new()
	add_child(view)
	if not view.configure(style):
		remove_child(view)
		view.queue_free()
		return
	_pool[tier] = view
	_order.append(tier)
	view.set_closed_turn(0.0)
	view.set_render_active(_active)


func sample(tier: int, yaw: float) -> Dictionary:
	if not is_finite(yaw):
		return {}
	prepare(tier)
	if not _pool.has(tier):
		return {}
	var view: ModelView = _pool[tier]
	view.set_closed_turn(yaw)
	return {"texture": view.get_texture(), "bounds": view.closed_bounds(),
		"turn_bounds": view.closed_turn_bounds()}


func set_active(enabled: bool) -> void:
	_active = enabled
	for view: ModelView in _pool.values():
		view.set_render_active(enabled)


func clear() -> void:
	for tier: int in _order.duplicate():
		_release(tier)


func _release(tier: int) -> void:
	var view: ModelView = _pool.get(tier)
	if is_instance_valid(view):
		view.set_render_active(false)
		remove_child(view)
		view.queue_free()
	_pool.erase(tier)
	_order.erase(tier)

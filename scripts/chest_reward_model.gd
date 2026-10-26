extends Node
## Two reusable closed-model surfaces for an uninterrupted reward transition.

const ModelView = preload("res://scripts/chest_model_view.gd")
const TierCatalog = preload("res://scripts/chest_tier_catalog.gd")
const MANIFEST_PATH: String = "res://assets/chests/downloaded/manifest.json"
const POOL_LIMIT: int = 2

var _styles: Dictionary = {}
var _manifest: Dictionary = {}
var _loaded: bool = false
var _pool: Dictionary = {}
var _order: Array[int] = []
var _active: bool = true
var last_error: String = ""
var _reported_errors: Dictionary = {}


func prepare(tier: int) -> void:
	if tier < 1 or tier > TierCatalog.MAX_TIER:
		_report_error("tier-%d" % tier, "Reward chest tier must be 1..30, received %d" % tier, false)
		return
	if _pool.has(tier):
		return
	if not _loaded:
		_loaded = true
		var content: Variant = null
		if FileAccess.file_exists(MANIFEST_PATH):
			content = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if content is Dictionary and content.get("styles") is Dictionary:
			_manifest = content
			_styles = content.styles
	if _manifest.is_empty():
		_report_error("manifest", "Reward chest source manifest is missing or invalid: " + MANIFEST_PATH)
		return
	var style: Dictionary = TierCatalog.style(tier, _manifest)
	if style.is_empty():
		_report_error("style-%d" % tier, "Reward chest tier %d has no genuine model recipe" % tier)
		return
	style["camera_margin"] = 1.12
	style["max_resolution"] = 512
	while _order.size() >= POOL_LIMIT:
		_release(_order[0])
	var view := ModelView.new()
	add_child(view)
	if not view.configure(style):
		var reason: String = view.last_error
		remove_child(view)
		view.free()
		_report_error("model-%d" % tier, "Reward chest tier %d is unavailable: %s" % [tier, reason])
		return
	# Measure first: the new CC0 sources do not need exported manifest bounds.
	# Only this private surface receives the closed-flight camera envelope.
	var box: AABB = view.closed_box()
	if not box.position.is_finite() or not box.size.is_finite() \
		or box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0 \
		or not view.frame_closed_turn(0.24):
		remove_child(view)
		view.free()
		_report_error("bounds-%d" % tier, "Reward chest tier %d has no finite measured turn envelope" % tier)
		return
	_pool[tier] = view
	_order.append(tier)
	view.set_closed_turn(0.0)
	view.set_render_active(_active)
	last_error = ""


func sample(tier: int, yaw: float, pitch: float = 0.0) -> Dictionary:
	if not is_finite(yaw) or not is_finite(pitch):
		_report_error("angles", "Reward chest rotation requires finite yaw and pitch", false)
		return {}
	prepare(tier)
	if not _pool.has(tier):
		return {}
	var view: ModelView = _pool[tier]
	view.set_closed_turn(yaw, pitch)
	last_error = ""
	return {"texture": view.get_texture(), "bounds": view.closed_bounds(),
		"turn_bounds": view.closed_turn_bounds()}


func set_active(enabled: bool) -> void:
	_active = enabled
	for view: ModelView in _pool.values():
		view.set_render_active(enabled)


func clear() -> void:
	for tier: int in _order.duplicate():
		_release(tier)
	last_error = ""


func _release(tier: int) -> void:
	var view: ModelView = _pool.get(tier)
	if is_instance_valid(view):
		view.set_render_active(false)
		remove_child(view)
		view.queue_free()
	_pool.erase(tier)
	_order.erase(tier)


func _report_error(key: String, message: String, report: bool = true) -> void:
	last_error = message
	if report and not _reported_errors.has(key):
		_reported_errors[key] = true
		push_error(message)

extends Control
## Sourced scenery and light sprites for the Talk Quest treasure presentation.
## This decorative layer never advances chest state or receives input.

const ROOT := "res://assets/talk_quest/treasure/"
const ART_MANIFEST := ROOT + "manifest.json"
const Style = preload("res://scripts/ui_style.gd")
const ACCENTS: Dictionary = {
	"spring": Color("#ffe8ad"), "summer": Color("#ffdc92"),
	"autumn": Color("#ffc795"), "winter": Color("#d6ecff"),
	"ocean": Color("#b9eff2"), "space": Color("#e2cbff"),
	"jungle": Color("#d7efb0"), "candy": Color("#ffd3e8")
}

var theme_id: String = "spring"
var reduced_motion: bool = false
var show_theme_name: bool = false
var _active: bool = true
var _clock: float = 0.0
var _frame_time: float = 0.0
var _reveal: float = 0.0
var _title_rect := Rect2()
var _chest_rect := Rect2()
var _accent := Color("#ffe8ad")
var _alcove: Texture2D
var _parlour: Texture2D
var _halo: Texture2D
var _ray: Texture2D
var _sparkle: Texture2D
var _title_panel: StyleBoxTexture
var _frame: StyleBoxTexture


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_alcove = load(ROOT + "alcove.jpg")
	_parlour = load(ROOT + "parlour.jpg")
	_halo = load(ROOT + "halo.png")
	_ray = load(ROOT + "ray.png")
	_sparkle = load(ROOT + "sparkle.png")
	_title_panel = StyleBoxTexture.new()
	_title_panel.texture = load(ROOT + "title-panel.png")
	_title_panel.set_texture_margin_all(8)
	_title_panel.modulate_color = Color(0.42, 0.37, 0.32, 0.92)
	_frame = StyleBoxTexture.new()
	_frame.texture = load(ROOT + "frame.png")
	_frame.set_texture_margin_all(8)
	_frame.draw_center = false
	_frame.modulate_color = Color(1.0, 0.88, 0.61, 0.70)
	resized.connect(queue_redraw)
	visibility_changed.connect(_sync_process)


func _ready() -> void:
	_sync_process()
	queue_redraw()


func configure(theme: Dictionary) -> void:
	theme_id = str(theme.get("id", "spring"))
	_accent = ACCENTS.get(theme_id, ACCENTS.spring)
	queue_redraw()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_sync_process()
	queue_redraw()


func set_active(enabled: bool) -> void:
	_active = enabled
	_sync_process()


func set_reveal(value: float) -> void:
	var next_reveal: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(_reveal, next_reveal):
		return
	_reveal = next_reveal
	queue_redraw()


func set_presentation_rects(title: Rect2, chest: Rect2) -> void:
	if _title_rect == title and _chest_rect == chest:
		return
	_title_rect = title
	_chest_rect = chest
	queue_redraw()


func _sync_process() -> void:
	set_process(_active and is_visible_in_tree() and not reduced_motion)


func _process(delta: float) -> void:
	if not _active or reduced_motion or not is_visible_in_tree():
		return
	_clock += delta
	_frame_time += delta
	if _frame_time >= 1.0 / 24.0:
		_frame_time = 0.0
		queue_redraw()


func _effective_chest_rect() -> Rect2:
	if _chest_rect.has_area():
		return _chest_rect
	return Rect2(size * Vector2(0.18, 0.28), size * Vector2(0.64, 0.61))


func _background(texture: Texture2D) -> void:
	if texture == null:
		return
	var cover: float = maxf(size.x / texture.get_width(), size.y / texture.get_height())
	var region_size: Vector2 = size / cover
	var region := Rect2((texture.get_size() - region_size) * 0.5, region_size)
	# Keep the authored walls and floor visible while protecting bright chest art.
	var tint := Color(0.58, 0.52, 0.47)
	if theme_id in ["winter", "ocean", "space"]:
		tint = Color(0.43, 0.49, 0.60)
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), region, tint)


func _draw() -> void:
	if size.x < 2 or size.y < 2:
		return
	# The uncluttered alcove preserves the complete focal area on narrow phones.
	_background(_parlour if _use_parlour() else _alcove)
	var chest: Rect2 = _effective_chest_rect()
	var center: Vector2 = chest.position + chest.size * Vector2(0.5, 0.56)
	var edge: float = minf(chest.size.x, chest.size.y)
	var breathing: float = 1.0 if reduced_motion else 1.0 + sin(_clock * 0.8) * 0.025
	var halo_size := Vector2(edge * 1.35, edge * 1.12) * breathing
	if _halo != null:
		draw_texture_rect(_halo, Rect2(center - halo_size * 0.5, halo_size), false, Color(_accent, 0.18 + _reveal * 0.22))
	_draw_rays(center, edge)
	_draw_sparkles(chest, edge)
	if _title_rect.has_area():
		var panel: Rect2 = _title_rect.grow_individual(8, 7, 8, 7).intersection(Rect2(Vector2.ZERO, size))
		draw_style_box(_title_panel, panel)
	var border: float = minf(7, minf(size.x, size.y) * 0.025)
	draw_style_box(_frame, Rect2(Vector2.ONE * border, size - Vector2.ONE * border * 2))


func _draw_rays(center: Vector2, edge: float) -> void:
	if _ray == null:
		return
	for index in range(7):
		var angle: float = -PI * 0.5 + (index - 3) * 0.22
		if not reduced_motion:
			angle += sin(_clock * 0.18 + index) * 0.025
		draw_set_transform(center, angle)
		var ray_size := Vector2(edge * (1.1 + _reveal * 0.12), edge * 0.13)
		draw_texture_rect(_ray, Rect2(Vector2(0, -ray_size.y * 0.5), ray_size), false, Color(_accent, 0.035 + _reveal * 0.11))
	draw_set_transform(Vector2.ZERO)


func _draw_sparkles(chest: Rect2, edge: float) -> void:
	if _sparkle == null:
		return
	for index in range(12):
		var phase: float = float(index) * 2.39996
		var cycle: float = fposmod(float(index) * 0.173 + (0.0 if reduced_motion else _clock * 0.033), 1.0)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var point := chest.position + chest.size * Vector2(0.5 + side * (0.34 + sin(phase) * 0.11), 0.85 - cycle * 0.76)
		var alpha: float = 0.42 if reduced_motion else sin(cycle * PI) * (0.35 + _reveal * 0.32)
		var diameter: float = clampf(edge * (0.025 + fposmod(phase, 1.0) * 0.024), 4, 15)
		draw_texture_rect(_sparkle, Rect2(point - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), false, Color(_accent, alpha))


func _use_parlour() -> bool:
	var physical: Vector2 = size * Style.ui_scale(self)
	return physical.x > 700 and physical.y >= 350


func snapshot() -> Dictionary:
	return {"theme": theme_id, "active": _active, "reduced_motion": reduced_motion,
		"reveal": _reveal, "clock": _clock, "manifest": ART_MANIFEST,
		"background": ROOT + ("parlour.jpg" if _use_parlour() else "alcove.jpg"),
		"chest_rect": _effective_chest_rect(), "title_rect": _title_rect}

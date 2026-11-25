extends Button
## Compact tactile Companion Skill trigger button for Jelly World campaign & Challenge.
## Charges freely from manual merges, word collections, and Boss dodges (never spends coins).

const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/shared/effects/portal_glow.png")
const SPARKLE = preload("res://assets/chests/shared/effects/sparkle.png")
const STAR = preload("res://assets/images/ui/jelly-goals/star.webp")
const STANCE_ICONS: Dictionary = {
	"Starburst": preload("res://assets/images/ui/jelly-rpg/stance-scholar.webp"),
	"Compass Strike": preload("res://assets/images/ui/jelly-rpg/stance-hunter.webp"),
	"Lucky Shower": preload("res://assets/images/ui/jelly-rpg/stance-seeker.webp")
}

var reduced_motion: bool = false
var _energy: float = 0.0
var _ready: bool = false
var _skill_name: String = "Starburst"
var _accent: Color = Color("#2a8c76")
var _scale: float = 1.0
var _elapsed: float = 0.0


func _init() -> void:
	name = "WordJellyCompanionSkill"
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = false
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	hide()


func set_ui_scale(ui_scale: float) -> void:
	_scale = maxf(0.1, ui_scale)
	queue_redraw()


func set_skill_state(state: Dictionary, accent: Color, steady: bool = false) -> void:
	reduced_motion = steady
	_accent = accent
	_energy = clampf(float(state.get("energy", 0.0)), 0.0, 100.0)
	_ready = bool(state.get("ready", false))
	_skill_name = str(state.get("name", "Starburst"))
	var pct: int = roundi(_energy)
	tooltip_text = "%s (%d%%) — Press E when ready" % [_skill_name, pct]
	set("accessibility_name", "%s. %d percent charged.%s" % [
		_skill_name, pct, " Ready! Activate to trigger." if _ready else ""])
	queue_redraw()


func advance(delta: float) -> void:
	if not visible or reduced_motion or not _ready or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = fmod(_elapsed + delta, 100.0)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u: float = 1.0 / _scale
	var bounds := Rect2(Vector2.ZERO, size)
	var radius: int = ceili(12.0 * u)
	var pulse: float = 0.0 if reduced_motion or not _ready else 0.5 + 0.5 * sin(_elapsed * 5.0)
	if _ready and not disabled:
		draw_texture_rect(GLOW, bounds.grow(8.0 * u), false, Color(_accent.lightened(0.35), 0.25 + 0.22 * pulse))
	var bg: Color = _accent.lightened(0.84) if _ready and not disabled else Style.PAPER
	var border: Color = _accent if _ready and not disabled else Style.EDGE
	var box := Style.box(bg, border, radius, maxi(1, roundi((2.0 if _ready else 1.0) * u)))
	box.border_width_bottom = ceili((3.0 if _ready and not button_pressed else 1.5) * u)
	draw_style_box(box, bounds)
	var fill_w: float = (size.x - 8.0 * u) * (_energy / 100.0)
	if fill_w > 1.0:
		var track := Rect2(Vector2(4.0 * u, size.y - 7.0 * u), Vector2(fill_w, 4.0 * u))
		var bar_style := Style.box(_accent if _ready else _accent.lightened(0.25), Color.TRANSPARENT, maxi(1, ceili(2.0 * u)), 0)
		draw_style_box(bar_style, track)
	var icon_edge: float = minf(20.0 * u, size.y * 0.58)
	var icon_pos := Vector2(8.0 * u, (size.y - icon_edge) * 0.5 - 1.5 * u)
	var skill_icon: Texture2D = STANCE_ICONS.get(_skill_name, STAR)
	draw_texture_rect(skill_icon, Rect2(icon_pos, Vector2.ONE * icon_edge), false,
		Color.WHITE if _ready else Color(0.75, 0.78, 0.78, 0.72))
	var label_text: String = _skill_name if _ready else "%d%%" % roundi(_energy)
	var font: Font = Style.HEADING_FONT
	var pixels: int = ceili(12.0 * u)
	var text_left: float = icon_pos.x + icon_edge + 5.0 * u
	var avail_w: float = maxf(1.0, size.x - text_left - 6.0 * u)
	while pixels > ceili(8.0 * u) and font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > avail_w:
		pixels -= 1
	var baseline: float = (size.y - font.get_height(pixels)) * 0.5 + font.get_ascent(pixels) - 1.5 * u
	draw_string(font, Vector2(text_left, baseline), label_text, HORIZONTAL_ALIGNMENT_LEFT, avail_w, pixels,
		_accent.darkened(0.15) if _ready else Style.MUTED)
	if _ready and not disabled and not reduced_motion:
		var sp_edge: float = (9.0 + 3.0 * pulse) * u
		draw_texture_rect(SPARKLE, Rect2(Vector2(size.x - sp_edge - 3.0 * u, 2.0 * u), Vector2.ONE * sp_edge),
			false, Color(1.0, 0.92, 0.52, 0.7 + 0.3 * pulse))


func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "enabled": not disabled, "ready": _ready,
		"energy": _energy, "name": _skill_name}

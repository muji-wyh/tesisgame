extends ColorRect
## Rim light follows the rescue clock; this node never advances gameplay.

const LIGHT = preload("res://assets/chests/particles/portal_glow.png")
const GLINT = preload("res://assets/chests/milestone/sparkle.png")
const FRAME_SHADER = preload("res://scripts/jelly_danger_frame.gdshader")
const HALO_MARGIN: float = 80.0

var state: Dictionary = {}

func _init() -> void:
	name = "JellyDangerLight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 3
	var effect := ShaderMaterial.new()
	effect.shader = FRAME_SHADER
	effect.set_shader_parameter("light_texture", LIGHT)
	effect.set_shader_parameter("glint_texture", GLINT)
	material = effect
	hide()

func layout_frame(bounds: Rect2, ui_scale: float, radius: float) -> void:
	var expanded: Rect2 = bounds.grow(HALO_MARGIN / ui_scale)
	position = expanded.position
	size = expanded.size
	material.set_shader_parameter("region_size", size * ui_scale)
	material.set_shader_parameter("frame_half", bounds.size * ui_scale * 0.5)
	# Match the well's rounded StyleBox after its pixel-to-canvas conversion.
	material.set_shader_parameter("corner_radius", ceilf(radius / ui_scale) * ui_scale)

static func primary_pulse(elapsed: float, reduced: bool) -> float:
	return 1.0 if reduced else 1.0 - smoothstep(0.18, 0.55, fposmod(elapsed, 1.0))

static func sample(elapsed: float, duration: float, reduced: bool) -> Dictionary:
	var progress: float = clampf(elapsed / maxf(0.001, duration), 0.0, 1.0)
	var urgency: float = smoothstep(0.0, 1.0, progress)
	# Integrating the speed keeps the orbit continuous as the rescue clock advances.
	var travel_speed: float = 0.07 + 0.65 * progress * progress
	var travel: float = duration * (0.07 * progress + 0.65 * pow(progress, 3.0) / 3.0)
	var beat: float = fposmod(elapsed, 1.0)
	# A quieter second beat enters halfway through the actual rescue window.
	var echo: float = smoothstep(0.46, 0.53, beat) * (1.0 - smoothstep(0.63, 0.88, beat))
	echo *= smoothstep(0.38, 0.82, progress) * 0.82
	return {
		"urgency": urgency,
		"glow_extent": lerpf(12.0, 72.0, urgency),
		"travel_speed": travel_speed,
		"pulse": 0.65 if reduced else maxf(primary_pulse(elapsed, false), echo),
		"travel": 0.125 if reduced else travel,
		"moving": not reduced,
	}

func set_warning(active: bool, elapsed: float, duration: float, reduced: bool) -> void:
	visible = active
	if not active:
		state = {}
		return
	state = sample(elapsed, duration, reduced)
	for parameter: String in state:
		material.set_shader_parameter(parameter, state[parameter])

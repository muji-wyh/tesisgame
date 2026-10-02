extends RefCounted
## Shared UV-free surface detail for the quest's dimensional environments.

const SURFACE_SHADER: Shader = preload("res://scripts/shaders/talk_quest_surface.gdshader")
const KINDS: Dictionary = {
	"wood": 0,
	"plaster": 1,
	"stone": 2,
	"tile": 3,
	"sand": 4,
	"fabric": 5
}


static func make(kind: String, color: Color, roughness: float = 0.8, scale_value: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	material.set_shader_parameter("surface_kind", int(KINDS.get(kind.to_lower(), 1)))
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("surface_roughness", clampf(roughness, 0.15, 1.0) if is_finite(roughness) else 0.8)
	material.set_shader_parameter("detail_scale", clampf(scale_value, 0.02, 128.0) if is_finite(scale_value) else 1.0)
	return material

shader_type canvas_item;
render_mode unshaded;

uniform float bend = 0.0;
uniform float beat = 0.0;
varying vec4 gel_modulate;

void vertex() {
	gel_modulate = COLOR;
}

void fragment() {
	vec2 sample_uv = UV;
	sample_uv.x += sin(UV.y * 3.14159265) * sin(beat + UV.y * 3.14159265) * bend;
	sample_uv.y += sin(UV.x * 3.14159265) * cos(beat + UV.x * 3.14159265) * bend * 0.55;
	COLOR = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0))) * gel_modulate;
}

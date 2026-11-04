shader_type canvas_item;
render_mode unshaded;

uniform float tier_row : hint_range(0.0, 8.0) = 0.0;
uniform float frame : hint_range(0.0, 32.0) = 0.0;
varying vec4 effect_tint;

void vertex() {
	effect_tint = COLOR;
}

vec2 frame_uv(float index, vec2 local_uv) {
	vec2 cell = vec2(mod(index, 16.0), floor(index / 16.0) + tier_row * 2.0);
	// Half-texel insets keep neighboring tiers out of the filtered sprite edge.
	vec2 inset = clamp(local_uv, vec2(0.5 / 96.0), vec2(1.0 - 0.5 / 96.0));
	return (cell + inset) / vec2(16.0, 18.0);
}

void fragment() {
	// Uniform uploads can round the last double-precision sample to 32.0.
	float current = mod(floor(frame), 32.0);
	float blend = fract(frame);
	vec4 sprite = texture(TEXTURE, frame_uv(current, UV));
	if (blend > 0.001) {
		vec4 next = texture(TEXTURE, frame_uv(mod(current + 1.0, 32.0), UV));
		float alpha = mix(sprite.a, next.a, blend);
		vec3 color = mix(sprite.rgb * sprite.a, next.rgb * next.a, blend) / max(alpha, 0.00001);
		sprite = vec4(color, alpha);
	}
	COLOR = sprite * effect_tint;
}

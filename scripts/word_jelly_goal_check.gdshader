shader_type canvas_item;
render_mode unshaded;

uniform float check_progress : hint_range(0.0, 1.0) = 1.0;
varying vec4 icon_tint;

void vertex() {
	icon_tint = COLOR;
}

void fragment() {
	vec4 icon = texture(TEXTURE, UV) * icon_tint;
	// Keep the source circle intact while revealing its left-to-right tick.
	float ring = step(0.30, length(UV - vec2(0.5)));
	float tip = mix(0.29, 0.71, check_progress);
	float tick = 1.0 - smoothstep(tip - 0.01, tip + 0.01, UV.x);
	icon.a *= max(ring, tick);
	COLOR = icon;
}

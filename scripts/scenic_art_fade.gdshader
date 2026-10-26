shader_type canvas_item;

void fragment() {
	float sides = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
	COLOR.a *= sides * (1.0 - smoothstep(0.20, 1.0, UV.y));
}

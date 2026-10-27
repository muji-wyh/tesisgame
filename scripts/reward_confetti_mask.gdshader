shader_type canvas_item;

uniform vec4 reading_rect = vec4(0.0);

void fragment() {
	if (reading_rect.z > reading_rect.x && reading_rect.w > reading_rect.y &&
		all(greaterThanEqual(SCREEN_UV, reading_rect.xy)) &&
		all(lessThanEqual(SCREEN_UV, reading_rect.zw))) {
		COLOR.a = 0.0;
	}
}

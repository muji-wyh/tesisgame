shader_type canvas_item;
render_mode unshaded;

uniform vec4 light_color : source_color = vec4(1.0);
uniform float light_strength = 0.0;
uniform vec2 light_origin = vec2(0.5);
uniform vec2 light_distance = vec2(1.0);

void fragment() {
	// Light reflects from the painted surface instead of replacing its texture.
	// UV falloff follows the cavity through each part's hinge and slow sway.
	if (light_strength > 0.0) {
		vec2 distance_from_cavity = (UV - light_origin) * light_distance;
		float diffuse = exp(-dot(distance_from_cavity, distance_from_cavity) * 2.2);
		float detail = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
		vec3 reflection = min(vec3(0.98), light_color.rgb * diffuse * light_strength * (0.28 + detail * 0.42));
		COLOR.rgb = vec3(1.0) - (vec3(1.0) - COLOR.rgb) * (vec3(1.0) - reflection);
	}
}

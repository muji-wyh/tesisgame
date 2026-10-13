shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 ellipse_radius = vec2(0.8, 0.8);
uniform float band_width = 0.13;
uniform float strength = 0.0;
uniform float light_phase = 0.0;
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 position = (UV * 2.0 - 1.0) / max(ellipse_radius, vec2(0.001));
	float radius = length(position);
	float angle = atan(-position.y, position.x);
	float ends = smoothstep(0.02, 0.40, angle) * (1.0 - smoothstep(2.74, 3.12, angle));
	// Follow the bow from the left foot, over its crown, to the right foot.
	// Feather the moving light front without drawing an unearned track or cursor.
	float arc_progress = 1.0 - angle / 3.14159265359;
	float progress = clamp(reveal_progress, 0.0, 1.0);
	float revealed = (1.0 - smoothstep(progress - 0.025, progress + 0.025, arc_progress))
		* smoothstep(0.0, 0.025, progress);
	if (progress >= 1.0) revealed = 1.0;
	float spectrum = (1.0 + band_width * 0.5 - radius) / max(band_width, 0.001);
	// Overlapping optical bands have no painted edges, bevel or unfilled rail.
	vec3 light = vec3(0.0);
	float weight = 0.0;
	for (int band = 0; band < 7; band++) {
		float center = float(band) / 6.0;
		float profile = exp(-pow((spectrum - center) / 0.20, 2.0));
		vec3 tint = vec3(0.92, 0.38, 0.43);
		if (band == 1) tint = vec3(0.96, 0.62, 0.29);
		if (band == 2) tint = vec3(0.92, 0.80, 0.38);
		if (band == 3) tint = vec3(0.36, 0.72, 0.49);
		if (band == 4) tint = vec3(0.33, 0.69, 0.80);
		if (band == 5) tint = vec3(0.43, 0.51, 0.84);
		if (band == 6) tint = vec3(0.69, 0.44, 0.80);
		light += tint * profile;
		weight += profile;
	}
	light /= max(weight, 0.001);
	// The acquired clouded glow supplies gentle irregularity to the light.
	vec2 cloud_uv = vec2(0.5 + position.x * 0.26, 0.5 + sin(angle + light_phase * 0.14) * 0.28);
	vec4 cloud = texture(TEXTURE, cloud_uv);
	float veil = mix(0.78, 1.0, cloud.a);
	float feather = exp(-pow((spectrum - 0.5) / 0.68, 4.0));
	float alpha = min(weight, 1.0) * feather * ends * veil * strength * revealed;
	COLOR = vec4(light, alpha);
}

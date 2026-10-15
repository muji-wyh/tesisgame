// Shared daylight response for the acquired jelly paint. Distance is measured
// inward from its real silhouette in units of the smaller body dimension.
// This changes color only; source coverage and gameplay rims stay independent.
vec3 jelly_light(vec3 paint, float depth, vec2 gradient) {
	vec2 normal = gradient / max(length(gradient), 0.0001);
	float edge = 1.0 - smoothstep(0.0, 0.105, max(depth, 0.0));
	float upper = max(0.0, dot(normal, normalize(vec2(-0.55, -0.85))));
	float lower = max(0.0, dot(normal, normalize(vec2(0.40, 0.92))));
	// A colored dense edge sits outside a softly transmitted lower shoulder.
	// Keep the broad center calm for letters and pictures.
	paint *= 1.0 - lower * edge * 0.16;
	float transmission = smoothstep(0.004, 0.025, depth)
		* (1.0 - smoothstep(0.025, 0.095, depth));
	paint = mix(paint, vec3(1.0, 0.97, 0.88), lower * transmission * 0.24);
	// The upper wet edge follows the existing upper-left painted reflections.
	float meniscus = 1.0 - smoothstep(0.008, 0.045, max(depth, 0.0));
	paint = mix(paint, vec3(1.0, 0.995, 0.96), pow(upper, 2.0) * meniscus * 0.34);
	return paint;
}

vec3 jelly_source_light(vec3 paint, sampler2D shape, vec2 uv, vec2 extent) {
	// All four acquired skins have identical alpha. Only the distance channel
	// is read here, after the skin's deformation and gameplay hue remapping.
	float depth = (0.5 - texture(shape, uv).a) * 0.4;
	vec2 step_uv = vec2(0.009375);
	vec2 aspect = max(extent, vec2(1.0));
	vec2 gradient = vec2(
		texture(shape, uv + vec2(step_uv.x, 0.0)).a - texture(shape, uv - vec2(step_uv.x, 0.0)).a,
		texture(shape, uv + vec2(0.0, step_uv.y)).a - texture(shape, uv - vec2(0.0, step_uv.y)).a
	) * min(aspect.x, aspect.y) / aspect;
	return jelly_light(paint, depth, gradient);
}

shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/jelly_optics.gdshaderinc"

// RGB is the acquired painted surface with edge bleed. Alpha stores the
// signed distance to that artwork's silhouette, not a replacement shape.
uniform sampler2D material_a : source_color, filter_linear, repeat_disable;
uniform sampler2D material_b : source_color, filter_linear, repeat_disable;
uniform vec2 canvas_size = vec2(200.0);
uniform vec4 body_a = vec4(70.0, 100.0, 100.0, 100.0);
uniform vec4 body_b = vec4(130.0, 100.0, 100.0, 100.0);
uniform float neck = 10.0;
uniform float flow = 0.0;
uniform float mixing = 0.0;
uniform float charge = 0.0;
uniform float opacity = 1.0;
uniform float palette_hue_a = -1.0;
uniform float palette_hue_b = -1.0;

vec3 palette(vec3 paint, float hue_value) {
	if (hue_value < 0.0) { return paint; }
	float high = max(max(paint.r, paint.g), paint.b);
	float low = min(min(paint.r, paint.g), paint.b);
	vec3 hue = clamp(abs(fract(vec3(hue_value) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return mix(vec3(low), vec3(high), hue);
}

vec2 body_uv(vec2 point, vec4 body) {
	vec2 uv = (point - body.xy) / body.zw + vec2(0.5);
	// A traveling pressure ripple bends the painted contour and highlights.
	uv.x += sin(uv.y * 6.28318 + flow * 5.0) * sin(flow * 3.14159) * 0.014;
	return uv;
}

float body_distance(sampler2D image, vec2 point, vec4 body) {
	vec2 uv = body_uv(point, body);
	vec2 bounded = clamp(uv, vec2(0.0), vec2(1.0));
	float distance = (texture(image, bounded).a - 0.5) * 0.4 * min(body.z, body.w);
	return distance + length((uv - bounded) * body.zw);
}

vec2 union_distance(vec2 point) {
	float a = body_distance(material_a, point, body_a);
	float b = body_distance(material_b, point, body_b);
	float h = clamp(0.5 + 0.5 * (b - a) / max(neck, 0.01), 0.0, 1.0);
	return vec2(mix(b, a, h) - neck * h * (1.0 - h), h);
}

void fragment() {
	vec2 point = UV * canvas_size;
	vec2 field = union_distance(point);
	float aa = max(fwidth(field.x), 0.65);
	float alpha = 1.0 - smoothstep(-aa, aa, field.x);
	if (alpha <= 0.0) {
		discard;
	}
	vec3 a = texture(material_a, clamp(body_uv(point, body_a), vec2(0.0), vec2(1.0))).rgb;
	vec3 b = texture(material_b, clamp(body_uv(point, body_b), vec2(0.0), vec2(1.0))).rgb;
	a = palette(a, palette_hue_a);
	b = palette(b, palette_hue_b);
	// Paint flows across the connected neck and settles into the destination
	// skin, so the finished body does not retain a hard two-color seam.
	vec3 paint = mix(b, a, field.y * (1.0 - mixing));
	float unit = min(body_b.z, body_b.w);
	float epsilon = max(0.8, unit * 0.012);
	vec2 normal = vec2(
		union_distance(point + vec2(epsilon, 0.0)).x - union_distance(point - vec2(epsilon, 0.0)).x,
		union_distance(point + vec2(0.0, epsilon)).x - union_distance(point - vec2(0.0, epsilon)).x
	) / (epsilon * 2.0);
	paint = jelly_light(paint, -field.x / max(unit, 1.0), normal);
	float edge = 1.0 - smoothstep(0.0, unit * 0.105, -field.x);
	vec2 local = (point - mix(body_a.xy, body_b.xy, 0.5)) / body_b.zw;
	float sheen = exp(-pow((local.x + 0.23 - flow * 0.12) / 0.07, 2.0)
		- pow((local.y + 0.18) / 0.18, 2.0));
	paint = mix(paint, vec3(1.0, 0.995, 0.94), sheen * charge * 0.25);
	paint += vec3(0.06, 0.10, 0.07) * charge * (1.0 - edge);
	COLOR = vec4(paint, alpha * opacity);
}

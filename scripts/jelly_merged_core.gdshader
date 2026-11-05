shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

void fragment() {
	// Each source child already received its full ancestor tint before baking.
	// Applying COLOR again would change overlapping translucent artwork.
	COLOR = texture(TEXTURE, UV);
}

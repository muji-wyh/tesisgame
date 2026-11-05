extends RefCounted
## glTF stores linear COLOR_0; Compatibility consumes display-encoded vertex colors.

const ENCODING_KEY: String = "pirate_vertex_color_encoding"


static func to_srgb_mesh(source: ArrayMesh) -> ArrayMesh:
	if source.get_meta(ENCODING_KEY, "") == "srgb":
		return source
	var converted := ArrayMesh.new()
	converted.resource_name = source.resource_name
	for key: StringName in source.get_meta_list():
		converted.set_meta(key, source.get_meta(key))
	for index: int in range(source.get_blend_shape_count()):
		converted.add_blend_shape(source.get_blend_shape_name(index))
	converted.blend_shape_mode = source.blend_shape_mode
	for surface: int in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for index: int in range(colors.size()):
			colors[index] = colors[index].linear_to_srgb()
		arrays[Mesh.ARRAY_COLOR] = colors
		# LOD generation is disabled for this small asset: ArrayMesh exposes no
		# public LOD-array getter for a color-only rebuild. Morph geometry is kept.
		converted.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays,
			source.surface_get_blend_shape_arrays(surface))
		converted.surface_set_material(surface, source.surface_get_material(surface))
		converted.surface_set_name(surface, source.surface_get_name(surface))
	converted.custom_aabb = source.custom_aabb
	converted.shadow_mesh = source.shadow_mesh
	converted.set_meta(ENCODING_KEY, "srgb")
	return converted

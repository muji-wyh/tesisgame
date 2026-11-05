@tool
extends EditorScenePostImport
## Preserve the packed glTF palette in raw Godot scene instances on every renderer.

const Palette = preload("res://scripts/pirate_asset_color.gd")


func _post_import(scene: Node) -> Object:
	_configure(scene)
	return scene


func _configure(node: Node) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh is ArrayMesh:
			instance.mesh = Palette.to_srgb_mesh(instance.mesh as ArrayMesh)
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var source: StandardMaterial3D = instance.get_active_material(surface) as StandardMaterial3D
			if colors.is_empty() or source == null:
				continue
			var material: StandardMaterial3D = source.duplicate() as StandardMaterial3D
			material.vertex_color_use_as_albedo = true
			# Compatibility uses the encoded values directly; linear renderers decode.
			material.vertex_color_is_srgb = true
			instance.set_surface_override_material(surface, material)
	for child: Node in node.get_children():
		_configure(child)

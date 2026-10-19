extends RefCounted
## Authored, bounded lower-hem bend of the acquired textile. This is not a source clip or cloth simulation.
const MIN_Y := 0.20000000298023224
const MAX_Y := 2.4200000762939453
const ACTIVE_FRACTION := 0.45
const AMPLITUDE := 0.02
const CUTS := [0.0, 0.075, 0.15, 0.225, 0.30, 0.375, 0.45, 1.0]
var textile: MeshInstance3D
var material: Material
var base_positions := PackedVector3Array()
var base_normals := PackedVector3Array()
var base_uvs := PackedVector2Array()
var hardware: Array = []
var records: Array = []
var base_bounds: AABB

func _intersection(a: Dictionary, b: Dictionary, height: float) -> Dictionary:
	var t: float = (height - a.p.y) / (b.p.y - a.p.y)
	return {"p": a.p.lerp(b.p,t), "n": a.n.lerp(b.n,t), "uv": a.uv.lerp(b.uv,t)}

func _clip(polygon: Array, height: float, keep_above: bool) -> Array:
	var result: Array = []
	if polygon.is_empty(): return result
	var previous: Dictionary = polygon[-1]
	var previous_inside: bool = previous.p.y >= height if keep_above else previous.p.y <= height
	for current: Dictionary in polygon:
		var inside: bool = current.p.y >= height if keep_above else current.p.y <= height
		if inside != previous_inside: result.append(_intersection(previous,current,height))
		if inside: result.append(current)
		previous = current
		previous_inside = inside
	return result

func _triangle(a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	if (b.p-a.p).cross(c.p-a.p).length_squared() < 0.0000000000000001: return
	for item: Dictionary in [a,b,c]:
		base_positions.append(item.p)
		base_normals.append(item.n)
		base_uvs.append(item.uv)

func setup(model: Node3D) -> Dictionary:
	var correction: Dictionary = load("res://build/professional-english/nursing-theme-review/static-r01/textile-normal-adapter.gd").adapt(model)
	for item: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if "Pleated" in item.name: textile = item
		else: hardware.append({"node":item,"transform":item.transform,"mesh":item.mesh})
	assert(textile != null)
	material = textile.mesh.surface_get_material(0)
	base_bounds = textile.mesh.get_aabb()
	var arrays := textile.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert(positions.size() == 3180)
	var side_triangles := 0
	for i in range(0,positions.size(),3):
		var original: Array = []
		for offset in range(3): original.append({"p":positions[i+offset],"n":normals[i+offset],"uv":uvs[i+offset]})
		if is_equal_approx(positions[i].y,positions[i+1].y) and is_equal_approx(positions[i].y,positions[i+2].y):
			_triangle(original[0],original[1],original[2])
			continue
		side_triangles += 1
		for band in range(CUTS.size()-1):
			var low: float = lerpf(MIN_Y,MAX_Y,CUTS[band])
			var high: float = lerpf(MIN_Y,MAX_Y,CUTS[band+1])
			var polygon := _clip(_clip(original,low,true),high,false)
			for index in range(1,polygon.size()-1): _triangle(polygon[0],polygon[index],polygon[index+1])
	set_phase(0.0)
	assert(textile.mesh.get_aabb().is_equal_approx(base_bounds))
	return {"source_normal_correction":correction,"source_side_triangles":side_triangles,"source_total_triangles":1060,
		"authored_triangles":base_positions.size()/3,"authored_vertices":base_positions.size(),"vertical_fraction_cuts":CUTS,
		"topology_adaptation":"Clipped each original side triangle into seven horizontal bands, adding only barycentric points on its original plane; preserved original cap triangles. Rest positions and UVs use exact edge interpolation.",
		"deformation":"Only the lower 45 percent bends in local depth by smoothstep weight times a sine wave; the upper 55 percent and every hardware mesh remain fixed.",
		"normal_adaptation":"Apply the inverse transpose of the depth-bend Jacobian to the corrected source normal at each authored vertex, then normalize.",
		"maximum_hem_displacement_meters":AMPLITUDE,"source_available_animations":[],"authored_animation":"nursing-curtain-hem-sway","cloth_simulation":false,
		"unchanged":["Original GLB bytes","All source materials/textures","Fold cross-sections","All hardware mesh/transform data","Entire model transform"],"hardware_mesh_count":hardware.size()}

func set_phase(phase: float) -> Dictionary:
	var strength := sin(TAU*phase)
	if absf(strength) < 0.0000001: strength = 0
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var max_fixed_delta := 0.0
	var max_displacement := 0.0
	var max_normal_y := 0.0
	for i in range(base_positions.size()):
		var original := base_positions[i]
		var t := (original.y-MIN_Y)/(MAX_Y-MIN_Y)
		var u := clampf((ACTIVE_FRACTION-t)/ACTIVE_FRACTION,0,1)
		var weight := u*u*(3.0-2.0*u)
		var derivative := -6.0*u*(1.0-u)/(ACTIVE_FRACTION*(MAX_Y-MIN_Y))
		var p := original
		p.z += AMPLITUDE*strength*weight
		var n := base_normals[i]
		n.y -= AMPLITUDE*strength*derivative*n.z
		n = n.normalized()
		positions.append(p)
		normals.append(n)
		max_displacement = maxf(max_displacement,p.distance_to(original))
		if t >= ACTIVE_FRACTION:
			max_fixed_delta = maxf(max_fixed_delta,p.distance_to(original))
		if absf(base_normals[i].y) < 0.1: max_normal_y = maxf(max_normal_y,absf(n.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = base_uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,material)
	textile.mesh = mesh
	var hardware_fixed := true
	for item: Dictionary in hardware: hardware_fixed = hardware_fixed and item.node.transform == item.transform and item.node.mesh == item.mesh
	assert(hardware_fixed and max_fixed_delta == 0.0)
	assert(max_displacement <= AMPLITUDE+0.000001)
	var record := {"phase":phase,"signed_strength":strength,"maximum_displacement_meters":max_displacement,"fixed_upper_region_delta_meters":max_fixed_delta,"hardware_fixed":hardware_fixed,"maximum_side_normal_y":max_normal_y}
	records.append(record)
	return record

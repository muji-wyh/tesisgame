extends Node3D
## Full-frame adventure locations with authored architecture and natural surfaces.
## Creature floor is y=0; the central x +/-0.9, z >=-0.5 area stays clear.
## The host supplies WorldEnvironment ambient light; this node supplies scene lights.

const Surfaces = preload("res://scripts/talk_quest_surfaces.gd")
const PALETTES: Array = [
	["#78604e", "#706454"], ["#2f6665", "#889894"],
	["#546457", "#765334"], ["#47556d", "#6d4b38"],
	["#71969e", "#566a3c"], ["#66796e", "#75513a"],
	["#7b684d", "#8c7350"], ["#243845", "#563e2c"],
	["#74918c", "#566544"], ["#415d69", "#4d6066"],
	["#7aa9b6", "#bca376"], ["#152637", "#435047"],
	["#6a4a53", "#75513d"], ["#355650", "#684b35"]
]
const WOOD := Color("#805b3d")
const DARK_WOOD := Color("#42352a")
const CREAM := Color("#dcd3ba")
const METAL := Color("#6c858c")
const LEAF := Color("#3f6949")
const DARK := Color("#25353b")
const GOLD := Color("#b58a48")
const SPARK_RADIUS: float = 0.035

var level: int = 1
var reduced_motion: bool = false
var _active: bool = true
var _progress: float = 0.0
var _repair_count: int = 0
var _time: float = 0.0
var _celebration: float = 0.0
var _root: Node3D
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _moving: Array[Dictionary] = []
var _repair_lamps: Array[MeshInstance3D] = []
var _sparkles: Array[MeshInstance3D] = []
var _shadow_texture: ImageTexture
var _scene_data: Dictionary = {}


func configure(next_level: int, scene_data: Dictionary = {}) -> void:
	level = clampi(next_level, 1, 14)
	_scene_data = scene_data.duplicate(true)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_materials.clear()
	_meshes.clear()
	_moving.clear()
	_repair_lamps.clear()
	_sparkles.clear()
	_progress = 0.0
	_repair_count = 0
	_time = 0.0
	_celebration = 0.0
	_root = Node3D.new()
	_root.name = "DioramaGeometry"
	add_child(_root)
	_lighting()
	match level:
		1: _porch()
		2: _bathroom()
		3: _kitchen()
		4: _bedroom()
		5: _playground()
		6: _classroom()
		7: _market()
		8: _library()
		9: _zoo()
		10: _bus()
		11: _beach()
		12: _camp()
		13: _birthday()
		14: _workshop()
	_finish_location()
	_contact(Vector3(0, -0.005, 0.05), Vector2(1.9, 1.15), 0.26)
	for index: int in range(10):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var spark := _sphere(Vector3(side * (1.35 + float(index % 3) * 0.30), 0.8 + float(index) * 0.12, 0.5), Vector3.ONE * SPARK_RADIUS, GOLD, _root, 0.6)
		spark.visible = false
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sparkles.append(spark)
	set_active(_active)
	_update_repairs()


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	_update_repairs()


func set_repair_count(value: int) -> void:
	_repair_count = clampi(value, 0, 5)
	_progress = float(_repair_count) / 5.0
	_update_repairs()


func celebrate() -> void:
	set_progress(1.0)
	_celebration = 3.2
	for spark: MeshInstance3D in _sparkles:
		spark.visible = _active and not reduced_motion


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		for entry: Dictionary in _moving:
			var node: Node3D = entry.node
			node.position = entry.origin
			node.rotation = entry.rotation
		for spark: MeshInstance3D in _sparkles:
			spark.visible = false


func set_active(enabled: bool) -> void:
	_active = enabled
	# A paused adventure retains its complete scene; the host controls visibility.
	set_process(enabled)


func _process(delta: float) -> void:
	if not _active or not is_visible_in_tree():
		return
	_celebration = maxf(0.0, _celebration - delta)
	if not reduced_motion:
		_time += minf(delta, 0.1)
		for entry: Dictionary in _moving:
			var node: Node3D = entry.node
			var wave: float = sin(_time * float(entry.speed) + float(entry.phase)) * float(entry.amount)
			if entry.kind == "float":
				node.position = Vector3(entry.origin) + Vector3(0, wave, 0)
			else:
				node.rotation = Vector3(entry.rotation) + Vector3(wave, 0, wave * 0.25)
	for index: int in range(_sparkles.size()):
		var spark: MeshInstance3D = _sparkles[index]
		spark.visible = _celebration > 0.0 and not reduced_motion
		if spark.visible:
			spark.position.y = 0.5 + fmod((3.2 - _celebration) * 0.65 + float(index) * 0.17, 2.3)
			spark.scale = Vector3.ONE * SPARK_RADIUS * (0.65 + 0.35 * sin(_time * 3.0 + float(index)))


func _animate(node: Node3D, kind: String, amount: float, speed: float, phase: float = 0.0) -> void:
	_moving.append({"node": node, "kind": kind, "amount": amount, "speed": speed,
		"phase": phase, "origin": node.position, "rotation": node.rotation})


func _update_repairs() -> void:
	for index: int in range(_repair_lamps.size()):
		var on: bool = _progress + 0.001 >= float(index + 1) / 5.0
		_repair_lamps[index].material_override = _material(Color("#ffe3a0") if on else Color("#7a887f"), 0.35, 0.85 if on else 0.0)


func _lighting() -> void:
	var key := DirectionalLight3D.new()
	key.name = "DioramaKey"
	key.rotation_degrees = Vector3(-36, -42, 0)
	key.light_color = Color("#9cc9ed") if level == 12 else Color("#ffe5bc")
	key.light_energy = 0.60 if level == 12 else 0.82
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 28.0
	key.shadow_bias = 0.08
	key.shadow_normal_bias = 1.3
	add_child(key)
	var fill := OmniLight3D.new()
	fill.name = "DioramaSkyFill"
	fill.position = Vector3(2.8, 3.0, 3.4)
	fill.omni_range = 12.0
	fill.light_color = Color("#9bc3df")
	fill.light_energy = 0.60 if level == 12 else 0.72
	fill.shadow_enabled = false
	add_child(fill)
	var rim := OmniLight3D.new()
	rim.name = "CreatureRim"
	rim.position = Vector3(-1.8, 2.9, -0.5)
	rim.light_color = Color("#7baec7") if level in [2, 8, 10, 12] else Color("#ffd08d")
	rim.light_energy = 0.95
	rim.omni_range = 5.0
	rim.shadow_enabled = false
	add_child(rim)


func _practical(position_value: Vector3, color: Color, energy: float = 0.5) -> void:
	var light := OmniLight3D.new()
	light.position = position_value
	light.light_color = color
	light.light_energy = energy * 0.70
	light.omni_range = 2.4
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	_root.add_child(light)


func _material(color: Color, roughness: float = 0.72, emission: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s/%.2f/%.2f" % [color.to_html(), roughness, emission]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.12 if roughness < 0.35 else 0.0
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material


func _node(position_value: Vector3, parent: Node3D = null) -> Node3D:
	var result := Node3D.new()
	result.position = position_value
	(parent if parent != null else _root).add_child(result)
	return result


func _mesh(shape: Mesh, position_value: Vector3, color: Color, parent: Node3D = null, roughness: float = 0.72, emission: float = 0.0) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = shape
	result.material_override = _material(color, roughness, emission)
	result.position = position_value
	(parent if parent != null else _root).add_child(result)
	return result


func _box(position_value: Vector3, dimensions: Vector3, color: Color, parent: Node3D = null, bevel: float = 0.025) -> MeshInstance3D:
	var amount: float = minf(bevel, minf(dimensions.x, minf(dimensions.y, dimensions.z)) * 0.22)
	var key: String = "box/%s/%.3f" % [dimensions, amount]
	if not _meshes.has(key):
		_meshes[key] = _beveled_mesh(dimensions, amount)
	return _mesh(_meshes[key], position_value, color, parent)


func _beveled_mesh(dimensions: Vector3, bevel: float) -> ArrayMesh:
	var half: Vector3 = dimensions * 0.5
	var inner: Vector3 = half - Vector3.ONE * bevel
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis: int in range(3):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for sign_value: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var points: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point := Vector3.ZERO
				point[axis] = half[axis] * sign_value
				point[u] = inner[u] * corner.x
				point[v] = inner[v] * corner.y
				points.append(point)
			_face(surface, points, normal)
		for sign_u: float in [-1.0, 1.0]:
			for sign_v: float in [-1.0, 1.0]:
				var points: Array[Vector3] = []
				for corner: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)]:
					var point := Vector3.ZERO
					point[axis] = inner[axis] * corner.x
					point[u] = sign_u * (half[u] if corner.y == 0.0 else inner[u])
					point[v] = sign_v * (inner[v] if corner.y == 0.0 else half[v])
					points.append(point)
				var normal := Vector3.ZERO
				normal[u] = sign_u
				normal[v] = sign_v
				_face(surface, points, normal.normalized())
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				_face(surface, [Vector3(x * half.x, y * inner.y, z * inner.z),
					Vector3(x * inner.x, y * half.y, z * inner.z),
					Vector3(x * inner.x, y * inner.y, z * half.z)], Vector3(x, y, z).normalized())
	return surface.commit()


func _face(surface: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	for index: int in range(1, points.size() - 1):
		var vertices: Array[Vector3] = [points[0], points[index], points[index + 1]]
		# Godot front faces use clockwise winding.
		if (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).dot(normal) > 0.0:
			vertices.reverse()
		for point: Vector3 in vertices:
			surface.set_normal(normal)
			surface.add_vertex(point)


func _sphere(position_value: Vector3, radii: Vector3, color: Color, parent: Node3D = null, emission: float = 0.0) -> MeshInstance3D:
	if not _meshes.has("sphere"):
		var shape := SphereMesh.new()
		shape.radius = 1.0
		shape.height = 2.0
		shape.radial_segments = 16
		shape.rings = 8
		_meshes["sphere"] = shape
	var result := _mesh(_meshes.sphere, position_value, color, parent, 0.58, emission)
	result.scale = radii
	return result


func _cylinder(position_value: Vector3, radius: float, height: float, color: Color, parent: Node3D = null, top_radius: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.height = height
	shape.radial_segments = 20
	shape.rings = 1
	return _mesh(shape, position_value, color, parent)


func _ring(position_value: Vector3, radius: float, thickness: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = maxf(0.005, radius - thickness)
	shape.outer_radius = radius + thickness
	shape.rings = 20
	shape.ring_segments = 8
	return _mesh(shape, position_value, color, parent, 0.32)


func _beam(first: Vector3, second: Vector3, radius: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var delta: Vector3 = second - first
	var result := _cylinder((first + second) * 0.5, radius, delta.length(), color, parent)
	result.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return result


func _plank(first: Vector3, second: Vector3, width: float, thickness: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var delta: Vector3 = second - first
	var result := _box((first + second) * 0.5, Vector3(width, delta.length(), thickness), color, parent)
	result.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return result


func _contact(position_value: Vector3, dimensions: Vector2, opacity: float = 0.2) -> void:
	if _shadow_texture == null:
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		for y: int in range(48):
			for x: int in range(48):
				var distance: float = Vector2(float(x) - 23.5, float(y) - 23.5).length() / 23.5
				image.set_pixel(x, y, Color(0.16, 0.20, 0.21, pow(maxf(0.0, 1.0 - distance), 2.0)))
		_shadow_texture = ImageTexture.create_from_image(image)
	var shape := PlaneMesh.new()
	shape.size = dimensions
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _shadow_texture
	material.albedo_color.a = opacity
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shadow := _mesh(shape, position_value, Color.WHITE)
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _floor(color: Color, boards: bool = true) -> void:
	# A continuous floor reaches beyond every camera crop; there is no toy plinth.
	var floor_node := _box(Vector3(0, -0.065, 2.0), Vector3(32, 0.10, 22), color, null, 0.0)
	floor_node.name = "LocationGround"
	var kind: String = "wood" if boards else "tile" if level == 2 else "stone"
	if level in [5, 9, 11, 12]:
		kind = "sand"
	floor_node.material_override = _surface(kind, color, 0.86, 0.8)
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _room(wall: Color, floor_color: Color, boards: bool = true) -> void:
	_floor(floor_color, boards)
	var wall_mesh := _box(Vector3(0, 3.0, -1.94), Vector3(32, 6.1, 0.18), wall, null, 0.0)
	wall_mesh.name = "LocationWall"
	wall_mesh.material_override = _surface("stone" if level == 1 else "plaster", wall, 0.92, 0.7)
	wall_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(0, 0.10, -1.79), Vector3(32, 0.18, 0.10), DARK_WOOD)
	_box(Vector3(0, 3.65, -1.72), Vector3(32, 0.16, 0.18), DARK_WOOD)
	# Recurring bays give wide screens real architecture instead of blank margins.
	for side: float in [-1.0, 1.0]:
		for bay: int in range(3):
			var x: float = side * (4.1 + float(bay) * 3.2)
			var post := _box(Vector3(x, 1.8, -1.66), Vector3(0.18, 3.6, 0.30), METAL if level in [2, 10] else DARK_WOOD)
			if level not in [2, 10]:
				post.material_override = _surface("wood", DARK_WOOD, 0.82)
			if level in [1, 4, 6, 8, 13, 14] and (int(side) + bay + level) % 3 == 0:
				_window(Vector3(x + side * 1.55, 2.0, -1.72), Vector2(1.1, 1.55), level in [8, 13, 14])
				_box(Vector3(x + side * 1.55, 0.7, -1.76), Vector3(2.7, 1.15, 0.05), wall.darkened(0.17))


func _outdoors(ground: Color, sky: Color) -> void:
	_floor(ground, false)
	var sky_node := _box(Vector3(0, 5, -13), Vector3(45, 18, 0.12), sky, null, 0.0)
	var sky_material := StandardMaterial3D.new()
	sky_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_material.albedo_color = sky
	sky_node.material_override = sky_material
	sky_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ridge(-11.0, sky.lerp(ground, 0.28), 3.8, 1.1)
	_ridge(-8.2, sky.lerp(ground, 0.55), 2.8, 3.0)
	_ridge(-5.8, ground.darkened(0.13), 1.9, 5.2)
	for side: float in [-1.0, 1.0]:
		for index: int in range(3):
			_tree(Vector3(side * (4.2 + float(index) * 2.4), 0, -2.5 - float(index) * 0.8), 3.1 + float(index % 2) * 0.7, level == 12)
	if level != 12:
		_cloud(Vector3(-5.3, 4.7, -10), 1.9)
		_cloud(Vector3(4.2, 5.3, -11), 2.6)


func _surface(kind: String, color: Color, roughness: float = 0.8, detail_scale: float = 1.0) -> ShaderMaterial:
	var key: String = "surface/%s/%s/%.2f/%.2f" % [kind, color.to_html(), roughness, detail_scale]
	if not _materials.has(key):
		_materials[key] = Surfaces.make(kind, color, roughness, detail_scale)
	return _materials[key] as ShaderMaterial


func _ridge(depth: float, color: Color, height: float, phase: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(24):
		var x: float = -24.0 + float(index) * 2.0
		var a: float = height + sin(x * 0.37 + phase) * 0.65 + sin(x * 0.87 + phase) * 0.3
		var b: float = height + sin((x + 2.0) * 0.37 + phase) * 0.65 + sin((x + 2.0) * 0.87 + phase) * 0.3
		_face(surface, [Vector3(x, -0.06, depth), Vector3(x + 2, -0.06, depth), Vector3(x + 2, b, depth), Vector3(x, a, depth)], Vector3.BACK)
	var ridge := _mesh(surface.commit(), Vector3.ZERO, color)
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _finish_location() -> void:
	# Texture large structural surfaces; tiny props retain simple readable colors.
	for mesh: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if not instance.material_override is StandardMaterial3D:
			continue
		var material := instance.material_override as StandardMaterial3D
		if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.emission_enabled:
			continue
		var color: Color = material.albedo_color
		if color.is_equal_approx(WOOD) or color.is_equal_approx(DARK_WOOD):
			instance.material_override = _surface("wood", color, 0.79, 0.65)
		elif color.is_equal_approx(CREAM):
			instance.material_override = _surface("plaster", color, 0.75, 1.2)
	# Each room extends its own purpose into the wide-camera margins.
	match level:
		1:
			_plant(Vector3(-5.2, 0, 0.35), 1.3, LEAF.darkened(0.12))
			_table(Vector3(5.1, 0, -0.8), Vector2(2.2, 0.7), 0.52, DARK_WOOD)
		3:
			for side: float in [-1.0, 1.0]:
				var cabinet := _box(Vector3(side * 5.5, 0.49, -1.25), Vector3(2.4, 0.96, 0.85), Color("#344e43"))
				cabinet.material_override = _surface("wood", Color("#344e43"), 0.74)
				_box(Vector3(side * 5.5, 1.02, -1.22), Vector3(2.5, 0.10, 0.91), Color("#bbb29a"))
				for panel: int in range(3):
					_box(Vector3(side * 5.5 - 0.78 + float(panel) * 0.78, 0.82, -0.77), Vector3(0.27, 0.025, 0.05), GOLD)
				_box(Vector3(side * 5.5, 2.27, -1.65), Vector3(2.5, 0.075, 0.38), WOOD)
				for jar: int in range(4):
					_cylinder(Vector3(side * 5.5 - 0.8 + float(jar) * 0.51, 2.48, -1.57), 0.12, 0.32, Color("#856646").lightened(float(jar % 2) * 0.12))
		4:
			_chair(Vector3(-5.1, 0, -0.3), Color("#67526b"), 0.24)
			_bookshelf(Vector3(5.2, 0, -1.4), Vector2(1.5, 2.2))
		6, 8:
			for side: float in [-1.0, 1.0]:
				_bookshelf(Vector3(side * 5.0, 0, -1.40), Vector2(2.5, 2.9 if level == 8 else 1.8))
		7:
			for side: float in [-1.0, 1.0]:
				_crate(Vector3(side * 4.6, 0, -0.25))
				_crate(Vector3(side * 5.0, 0.65, -0.5))
		13:
			_table(Vector3(-5.0, 0, -0.75), Vector2(2.0, 0.9), 0.9)
			_gift(Vector3(5.1, 0, -0.4), 0.8, Color("#9e694c"))
		14:
			for side: float in [-1.0, 1.0]:
				_table(Vector3(side * 5.1, 0, -0.75), Vector2(2.1, 0.85), 0.9)
				_toy(Vector3(side * 5.1, 0.98, -0.75), 0 if side < 0 else 1)


func _cloud(position_value: Vector3, size_value: float) -> void:
	var cloud := _node(position_value)
	for index: int in range(3):
		_sphere(Vector3((float(index) - 1.0) * 0.3, 0.05 if index == 1 else 0.0, 0), Vector3(0.35, 0.17 + (0.09 if index == 1 else 0.0), 0.10) * size_value, Color("#eff6ed"), cloud)
	_animate(cloud, "float", 0.025, 0.45, position_value.x)


func _window(position_value: Vector3, dimensions: Vector2 = Vector2(1.3, 1.2), night: bool = false, curtains: bool = false) -> void:
	var frame := _node(position_value)
	_box(Vector3(0, 0, -0.04), Vector3(dimensions.x + 0.16, dimensions.y + 0.16, 0.13), DARK_WOOD, frame)
	_box(Vector3.ZERO, Vector3(dimensions.x, dimensions.y, 0.09), Color("#627f9a") if night else Color("#aed6dc"), frame)
	_sphere(Vector3(dimensions.x * 0.26, dimensions.y * 0.23, 0.052), Vector3(0.13, 0.13, 0.018), Color("#fff0b5"), frame, 0.15)
	_box(Vector3(0, 0, 0.09), Vector3(0.065, dimensions.y, 0.08), CREAM, frame)
	_box(Vector3(0, -0.05, 0.09), Vector3(dimensions.x, 0.055, 0.08), CREAM, frame)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * (dimensions.x * 0.5 + 0.025), 0, 0.06), Vector3(0.07, dimensions.y + 0.08, 0.12), CREAM, frame)
		_box(Vector3(0, side * (dimensions.y * 0.5 + 0.025), 0.06), Vector3(dimensions.x + 0.10, 0.07, 0.12), CREAM, frame)
	_box(Vector3(0, -dimensions.y * 0.5 - 0.06, 0.11), Vector3(dimensions.x + 0.3, 0.09, 0.32), CREAM, frame)
	if curtains:
		for side: float in [-1.0, 1.0]:
			for fold: int in range(3):
				_cylinder(Vector3(side * (dimensions.x * 0.5 + 0.05 + float(fold) * 0.055), 0, 0.17), 0.08, dimensions.y + 0.12, Color("#d49b85"), frame)
		_beam(Vector3(-dimensions.x * 0.7, dimensions.y * 0.6, 0.12), Vector3(dimensions.x * 0.7, dimensions.y * 0.6, 0.12), 0.025, DARK_WOOD, frame)


func _plant(position_value: Vector3, size_value: float = 1.0, color: Color = LEAF) -> void:
	var plant := _node(position_value)
	plant.scale = Vector3.ONE * size_value
	_cylinder(Vector3(0, 0.21, 0), 0.21, 0.4, Color("#bb795b"), plant, 0.28)
	_cylinder(Vector3(0, 0.405, 0), 0.24, 0.035, DARK_WOOD, plant)
	_ring(Vector3(0, 0.39, 0), 0.265, 0.035, Color("#d59474"), plant)
	for index: int in range(5):
		var angle: float = float(index) * TAU / 5.0
		var tip := Vector3(cos(angle) * 0.23, 0.62 + float(index % 2) * 0.16, sin(angle) * 0.19)
		_beam(Vector3(0, 0.38, 0), tip, 0.018, color.darkened(0.2), plant)
		var leaf := _sphere(tip, Vector3(0.12, 0.27, 0.065), color.lightened(float(index % 3) * 0.05), plant)
		leaf.rotation.z = -cos(angle) * 0.6
	_animate(plant, "sway", 0.012, 1.1, position_value.x)
	_contact(position_value + Vector3(0, 0.001, 0), Vector2.ONE * 0.8 * size_value, 0.25)


func _table(position_value: Vector3, dimensions: Vector2, height: float, color: Color = WOOD) -> Node3D:
	var table := _node(position_value)
	_box(Vector3(0, height, 0), Vector3(dimensions.x, 0.13, dimensions.y), color.lightened(0.1), table, 0.055)
	_box(Vector3(0, height - 0.14, 0), Vector3(dimensions.x - 0.14, 0.16, dimensions.y - 0.12), color.darkened(0.04), table)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_box(Vector3(x * (dimensions.x * 0.5 - 0.13), height * 0.48, z * (dimensions.y * 0.5 - 0.13)), Vector3(0.10, height, 0.10), color.darkened(0.15), table)
	_contact(position_value + Vector3(0, 0.002, 0), dimensions * 1.25, 0.3)
	return table


func _sign(text: String, position_value: Vector3, width: float, color: Color = CREAM, parent: Node3D = null) -> void:
	_box(position_value, Vector3(width, 0.31, 0.06), color, parent)
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.0042
	label.modulate = DARK
	label.outline_size = 0
	label.position = position_value + Vector3(0, 0, 0.036)
	label.no_depth_test = false
	(parent if parent != null else _root).add_child(label)


func _porch() -> void:
	_room(Color(PALETTES[0][0]), Color(PALETTES[0][1]), false)
	for row: int in range(6):
		for column: int in range(9):
			var x: float = -3.0 + float(column) * 0.73 + (0.18 if row % 2 else 0.0)
			_box(Vector3(x, 0.3 + float(row) * 0.43, -1.827), Vector3(0.69, 0.022, 0.012), Color("#d6b6a3"), null, 0.004)
	_box(Vector3(0, 1.35, -1.67), Vector3(1.72, 2.70, 0.21), CREAM, null, 0.06)
	_box(Vector3(0, 1.34, -1.53), Vector3(1.44, 2.49, 0.13), Color("#577c81"), null, 0.035)
	for x: float in [-0.36, 0.36]:
		for y: float in [0.62, 1.35]:
			_box(Vector3(x, y, -1.448), Vector3(0.55, 0.61, 0.035), Color("#789b9c"))
	_box(Vector3(0, 2.18, -1.43), Vector3(1.14, 0.48, 0.03), Color("#b8d5d0"))
	_sphere(Vector3(0.54, 1.2, -1.35), Vector3.ONE * 0.065, GOLD)
	_sign("12", Vector3(0, 2.92, -1.64), 0.5)
	_window(Vector3(-2.17, 1.92, -1.7), Vector2(1.0, 0.96), false, true)
	_box(Vector3(1.1, 1.43, -1.65), Vector3(0.14, 0.23, 0.10), GOLD)
	_sphere(Vector3(1.1, 1.46, -1.58), Vector3(0.045, 0.045, 0.025), CREAM)
	_plant(Vector3(2.35, 0, -0.65), 1.45)
	_plant(Vector3(-2.78, 0, 0.40), 0.94)
	_box(Vector3(0, 0.011, 0.84), Vector3(1.8, 0.025, 0.70), Color("#94734f"))
	for line: int in range(7):
		_box(Vector3(-0.73 + float(line) * 0.245, 0.027, 0.84), Vector3(0.04, 0.006, 0.56), Color("#b19269"), null, 0.0)
	_box(Vector3(2.12, 0.57, -1.18), Vector3(1.25, 0.14, 0.55), DARK_WOOD)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(2.12 + side * 0.48, 0.28, -1.18), Vector3(0.09, 0.55, 0.4), DARK_WOOD)
	_practical(Vector3(1.15, 2.55, -0.95), Color("#ffd5a4"), 0.45)
	_box(Vector3(1.14, 2.43, -1.58), Vector3(0.21, 0.30, 0.23), DARK)
	_sphere(Vector3(1.14, 2.41, -1.43), Vector3(0.075, 0.12, 0.03), Color("#ffe2a7"), null, 0.55)


func _bathroom() -> void:
	_room(Color(PALETTES[1][0]), Color(PALETTES[1][1]), false)
	for column: int in range(12):
		for row: int in range(3):
			_box(Vector3(-3.15 + float(column) * 0.57, 0.28 + float(row) * 0.42, -1.805), Vector3(0.54, 0.39, 0.045), Color("#bedbd7").lightened(float((column + row) % 3) * 0.04), null, 0.012)
	var sink := _node(Vector3(-2.02, 0, -0.75))
	_box(Vector3(0, 0.43, 0), Vector3(1.21, 0.82, 0.68), Color("#799b92"), sink, 0.045)
	_box(Vector3(0, 0.83, 0), Vector3(1.38, 0.15, 0.82), CREAM, sink, 0.065)
	_sphere(Vector3(0, 0.87, 0.05), Vector3(0.47, 0.035, 0.27), Color("#cadcdb"), sink)
	var basin := _ring(Vector3(0, 0.9, 0.05), 0.34, 0.09, Color("#faf6e8"), sink)
	basin.scale.z = 0.74
	_beam(Vector3(0, 0.9, -0.26), Vector3(0, 1.2, -0.26), 0.035, METAL, sink)
	_beam(Vector3(0, 1.2, -0.26), Vector3(0, 1.2, -0.01), 0.035, METAL, sink)
	_box(Vector3(0, 0.42, 0.365), Vector3(1.04, 0.62, 0.055), Color("#93afa1"), sink)
	_box(Vector3(0, 0.65, 0.412), Vector3(0.27, 0.035, 0.07), GOLD, sink)
	var mirror := _ring(Vector3(-2.02, 2.05, -1.72), 0.5, 0.055, GOLD)
	mirror.rotation.x = PI * 0.5
	_sphere(Vector3(-2.02, 2.05, -1.715), Vector3(0.45, 0.45, 0.035), Color("#bfd9df"))
	_beam(Vector3(-2.32, 2.2, -1.666), Vector3(-2.04, 2.46, -1.666), 0.025, Color("#e8f3ed"))
	_cylinder(Vector3(-2.49, 1.05, -0.58), 0.10, 0.28, Color("#e2b274"))
	_box(Vector3(-2.49, 1.22, -0.58), Vector3(0.18, 0.045, 0.055), DARK)
	var tub := _node(Vector3(2.05, 0, -0.52))
	_sphere(Vector3(0, 0.40, 0), Vector3(0.81, 0.42, 0.53), CREAM, tub)
	_sphere(Vector3(0, 0.69, 0), Vector3(0.69, 0.03, 0.41), Color("#8ec1cc"), tub)
	var rim := _ring(Vector3(0, 0.67, 0), 0.56, 0.10, Color("#fff9e9"), tub)
	rim.scale.x = 1.35
	rim.scale.z = 0.8
	for index: int in range(4):
		_sphere(Vector3(-0.35 + float(index) * 0.18, 0.72, 0.1 * sin(float(index) * 2.0)), Vector3.ONE * (0.07 + float(index % 2) * 0.03), Color("#eaf4e5"), tub)
	_beam(Vector3(1.46, 1.94, -1.60), Vector3(2.65, 1.94, -1.60), 0.028, GOLD)
	_box(Vector3(2.04, 1.61, -1.54), Vector3(0.59, 0.70, 0.07), Color("#d0a17e"))
	for index: int in range(3):
		_box(Vector3(1.84 + float(index) * 0.2, 1.60, -1.492), Vector3(0.015, 0.62, 0.007), Color("#edc8a0"), null, 0.0)
	_plant(Vector3(2.98, 0, 0.38), 0.68)
	_contact(Vector3(2.0, 0.007, -0.5), Vector2(2.0, 1.45), 0.4)


func _kitchen() -> void:
	_room(Color(PALETTES[2][0]), Color(PALETTES[2][1]))
	_window(Vector3(-0.1, 2.26, -1.73), Vector2(1.3, 1.03), false, true)
	var fridge := _node(Vector3(-2.68, 0, -1.10))
	_box(Vector3(0, 1.18, 0), Vector3(0.95, 2.32, 0.73), Color("#d3ded4"), fridge, 0.08)
	for height: float in [0.72, 1.83]:
		_box(Vector3(0, height, 0.39), Vector3(0.84, 0.84 if height > 1.0 else 1.25, 0.055), Color("#e3e6d7"), fridge)
		_box(Vector3(0.31, height, 0.46), Vector3(0.035, 0.31, 0.055), METAL, fridge)
	_box(Vector3(-0.16, 1.94, 0.46), Vector3(0.31, 0.26, 0.014), Color("#d7a080"), fridge)
	var counter := _node(Vector3(2.03, 0, -1.12))
	_box(Vector3(0, 0.5, 0), Vector3(2.15, 0.98, 0.83), Color("#87a296"), counter, 0.05)
	_box(Vector3(0, 1.04, 0.04), Vector3(2.28, 0.12, 0.97), CREAM, counter, 0.04)
	for index: int in range(3):
		_box(Vector3(-0.7 + float(index) * 0.70, 0.53, 0.46), Vector3(0.60, 0.76, 0.04), Color("#a9bcaa"), counter)
		_box(Vector3(-0.7 + float(index) * 0.70, 0.78, 0.50), Vector3(0.22, 0.035, 0.05), GOLD, counter)
	_box(Vector3(0.36, 1.11, 0), Vector3(0.72, 0.035, 0.63), DARK, counter)
	for x: float in [0.16, 0.55]:
		for z: float in [-0.16, 0.15]:
			_ring(Vector3(x, 1.14, z), 0.11, 0.018, METAL, counter)
	_cylinder(Vector3(0.2, 1.29, -0.12), 0.15, 0.28, Color("#b7624e"), counter)
	_box(Vector3(0.4, 1.35, -0.12), Vector3(0.22, 0.045, 0.05), DARK, counter)
	_box(Vector3(2.18, 2.30, -1.60), Vector3(1.65, 0.85, 0.39), Color("#a4b7a2"))
	for x: float in [1.78, 2.57]:
		_box(Vector3(x, 2.29, -1.365), Vector3(0.73, 0.70, 0.04), CREAM)
		_sphere(Vector3(x + 0.24, 2.20, -1.32), Vector3.ONE * 0.034, GOLD)
	var table := _table(Vector3(-1.87, 0, 0.30), Vector2(1.48, 0.83), 0.83)
	_cylinder(Vector3(0, 0.92, 0), 0.27, 0.035, CREAM, table)
	_box(Vector3(-0.02, 0.98, 0), Vector3(0.35, 0.08, 0.32), Color("#a66d3d"), table, 0.03)
	_box(Vector3(-0.02, 1.023, 0), Vector3(0.29, 0.016, 0.26), Color("#e5bb78"), table)
	_cylinder(Vector3(0.45, 1.05, -0.12), 0.11, 0.26, Color("#f1e4c7"), table)
	var handle := _ring(Vector3(0.58, 1.07, -0.12), 0.07, 0.021, CREAM, table)
	handle.rotation.x = PI * 0.5
	_plant(Vector3(3.0, 1.10, -1.13), 0.5)


func _bedroom() -> void:
	_room(Color(PALETTES[3][0]), Color(PALETTES[3][1]))
	_window(Vector3(-0.05, 2.2, -1.72), Vector2(1.15, 1.15), false, true)
	var bed := _node(Vector3(-2.12, 0, -0.46))
	_box(Vector3(0, 0.32, 0), Vector3(1.40, 0.28, 2.04), WOOD, bed, 0.07)
	_box(Vector3(0, 0.56, 0), Vector3(1.32, 0.27, 1.95), CREAM, bed, 0.10)
	_box(Vector3(0, 0.72, 0.29), Vector3(1.37, 0.12, 1.35), Color("#8a9ea9"), bed, 0.04)
	_box(Vector3(0, 0.76, -0.60), Vector3(0.88, 0.20, 0.44), Color("#eadfce"), bed, 0.08)
	_box(Vector3(0, 0.76, -1.01), Vector3(1.50, 1.04, 0.10), Color("#967360"), bed, 0.09)
	for x: float in [-0.47, 0.0, 0.47]:
		_box(Vector3(x, 0.79, 0.27), Vector3(0.021, 0.02, 1.21), Color("#bac8c5"), bed, 0.0)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 0.57, 0.16, 0.71), Vector3(0.12, 0.34, 0.12), DARK_WOOD, bed)
	_contact(Vector3(-2.12, 0.007, -0.35), Vector2(1.95, 2.50), 0.37)
	var wardrobe := _node(Vector3(2.22, 0, -1.12))
	_box(Vector3(0, 1.22, 0), Vector3(1.50, 2.42, 0.74), Color("#987e9c"), wardrobe, 0.08)
	_box(Vector3(0.33, 1.26, 0.40), Vector3(0.62, 2.16, 0.065), Color("#bba4b8"), wardrobe, 0.04)
	_box(Vector3(-0.36, 1.26, 0.39), Vector3(0.62, 2.10, 0.025), DARK_WOOD, wardrobe)
	var open_door := _box(Vector3(-0.92, 1.26, 0.66), Vector3(0.62, 2.16, 0.07), Color("#bba4b8"), wardrobe, 0.04)
	open_door.rotation.y = -0.72
	_beam(Vector3(-0.64, 1.90, 0.48), Vector3(-0.05, 1.90, 0.48), 0.016, GOLD, wardrobe)
	_box(Vector3(-0.33, 1.49, 0.47), Vector3(0.37, 0.53, 0.07), Color("#6699b3"), wardrobe)
	_box(Vector3(-0.33, 1.68, 0.47), Vector3(0.63, 0.17, 0.08), Color("#6699b3"), wardrobe)
	_sphere(Vector3(0.12, 1.22, 0.47), Vector3.ONE * 0.035, GOLD, wardrobe)
	for side: float in [-1.0, 1.0]:
		_sphere(Vector3(1.77 + side * 0.19, 0.09, 0.77), Vector3(0.13, 0.09, 0.24), Color("#c69c57"))
	var nightstand := _table(Vector3(-3.04, 0, -1.35), Vector2(0.5, 0.53), 0.68)
	_cylinder(Vector3(0, 0.85, 0), 0.035, 0.34, GOLD, nightstand)
	_cylinder(Vector3(0, 1.10, 0), 0.23, 0.31, Color("#e8be8c"), nightstand, 0.12)
	_practical(Vector3(-3.04, 1.0, -1.10), Color("#ffd4a0"), 0.55)


func _tree(position_value: Vector3, height: float = 2.1, pine: bool = false) -> void:
	var tree := _node(position_value)
	_cylinder(Vector3(0, height * 0.28, 0), 0.10, height * 0.6, DARK_WOOD, tree, 0.07)
	if pine:
		for index: int in range(3):
			_cylinder(Vector3(0, height * (0.42 + float(index) * 0.18), 0), height * (0.28 - float(index) * 0.055), height * 0.5, LEAF.darkened(float(index) * 0.04), tree, 0.03)
	else:
		for index: int in range(3):
			_sphere(Vector3((float(index) - 1.0) * height * 0.17, height * (0.74 + (0.09 if index == 1 else 0.0)), 0), Vector3(0.35, 0.40, 0.30) * height, LEAF.lightened(float(index) * 0.03), tree)
	_contact(position_value + Vector3(0, 0.008, 0), Vector2(height, height * 0.7), 0.23)


func _fence(z: float, color: Color = CREAM) -> void:
	for index: int in range(14):
		_box(Vector3(-3.24 + float(index) * 0.50, 0.45, z), Vector3(0.10, 0.92, 0.09), color)
	for y: float in [0.25, 0.68]:
		_box(Vector3(0, y, z + 0.03), Vector3(6.8, 0.09, 0.09), color)


func _playground() -> void:
	_outdoors(Color(PALETTES[4][1]), Color(PALETTES[4][0]))
	_fence(-1.72, Color("#c9bda0"))
	_tree(Vector3(-3.0, 0, -1.47), 2.25)
	var slide := _node(Vector3(-1.90, 0, -0.20))
	_box(Vector3(0, 1.26, -0.59), Vector3(0.81, 0.13, 0.83), WOOD, slide)
	for x: float in [-0.34, 0.34]:
		for z: float in [-0.9, -0.27]:
			_beam(Vector3(x, 0, z), Vector3(x, 1.89, z), 0.052, WOOD, slide)
	_plank(Vector3(0, 1.30, -0.27), Vector3(0, 0.12, 1.14), 0.67, 0.07, Color("#c77560"), slide)
	for side: float in [-1.0, 1.0]:
		_beam(Vector3(side * 0.35, 1.43, -0.28), Vector3(side * 0.35, 0.25, 1.16), 0.045, Color("#ecc090"), slide)
		_beam(Vector3(side * 0.31, 0.02, -1.0), Vector3(side * 0.31, 1.34, -0.59), 0.035, CREAM, slide)
	for step: int in range(5):
		_beam(Vector3(-0.31, 0.18 + float(step) * 0.22, -0.94 + float(step) * 0.07), Vector3(0.31, 0.18 + float(step) * 0.22, -0.94 + float(step) * 0.07), 0.035, CREAM, slide)
	var roof := PrismMesh.new()
	roof.size = Vector3(1.14, 0.55, 1.10)
	_mesh(roof, Vector3(0, 2.06, -0.6), Color("#719b9c"), slide)
	var swing := _node(Vector3(2.0, 0, -0.58))
	for x: float in [-0.73, 0.73]:
		_beam(Vector3(x, 0, 0.62), Vector3(x, 2.16, -0.04), 0.055, Color("#d7a452"), swing)
		_beam(Vector3(x, 0, -0.63), Vector3(x, 2.16, -0.04), 0.055, Color("#d7a452"), swing)
	_beam(Vector3(-0.88, 2.16, -0.04), Vector3(0.88, 2.16, -0.04), 0.075, Color("#d7a452"), swing)
	var seat := _node(Vector3(0, 2.05, -0.04), swing)
	for x: float in [-0.30, 0.30]:
		_beam(Vector3(x, 0, 0), Vector3(x, -1.49, 0), 0.012, DARK, seat)
	_box(Vector3(0, -1.52, 0), Vector3(0.74, 0.10, 0.36), Color("#799caa"), seat)
	_animate(seat, "sway", 0.075, 1.2)
	_sphere(Vector3(1.35, 0.16, 0.92), Vector3.ONE * 0.17, Color("#c46c58"))


func _book(position_value: Vector3, dimensions: Vector3, color: Color, parent: Node3D = null) -> void:
	_box(position_value, dimensions, color, parent, 0.01)
	_box(position_value + Vector3(0, dimensions.y * 0.24, dimensions.z * 0.51), Vector3(dimensions.x * 0.6, 0.016, 0.01), GOLD, parent, 0.0)


func _bookshelf(position_value: Vector3, dimensions: Vector2, parent: Node3D = null) -> void:
	var shelf := _node(position_value, parent)
	_box(Vector3(0, dimensions.y * 0.5, -0.17), Vector3(dimensions.x, dimensions.y, 0.10), DARK_WOOD, shelf)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * dimensions.x * 0.5, dimensions.y * 0.5, 0), Vector3(0.095, dimensions.y, 0.47), WOOD, shelf)
	var colors: Array[Color] = [Color("#a9685b"), Color("#779b9b"), Color("#bfad78"), Color("#8c819c"), Color("#7b9472")]
	for row: int in range(3):
		var y: float = 0.12 + float(row) * dimensions.y * 0.32
		_box(Vector3(0, y, 0), Vector3(dimensions.x + 0.1, 0.085, 0.5), WOOD, shelf)
		for index: int in range(7):
			var height: float = dimensions.y * (0.19 + float((index + row) % 3) * 0.024)
			_book(Vector3(-dimensions.x * 0.43 + float(index) * dimensions.x * 0.135, y + height * 0.5 + 0.046, 0.04), Vector3(dimensions.x * 0.09, height, 0.28), colors[(index + row) % colors.size()], shelf)
	_box(Vector3(0, dimensions.y, 0), Vector3(dimensions.x + 0.17, 0.11, 0.56), WOOD.lightened(0.14), shelf)


func _classroom() -> void:
	_room(Color(PALETTES[5][0]), Color(PALETTES[5][1]))
	_box(Vector3(-1.74, 2.12, -1.70), Vector3(2.00, 1.17, 0.16), WOOD)
	_box(Vector3(-1.74, 2.12, -1.59), Vector3(1.81, 0.99, 0.035), Color("#4b746b"))
	_box(Vector3(-1.74, 1.53, -1.50), Vector3(2.10, 0.08, 0.24), WOOD)
	var sun := _ring(Vector3(-2.2, 2.3, -1.55), 0.17, 0.012, CREAM)
	sun.rotation.x = PI * 0.5
	for side: float in [-1.0, 1.0]:
		_beam(Vector3(-1.5, 2.29, -1.54), Vector3(-1.5 + side * 0.3, 1.97, -1.54), 0.011, CREAM)
	_box(Vector3(-1.5, 1.81, -1.54), Vector3(0.47, 0.32, 0.016), Color("#82a496"))
	var table := _table(Vector3(-1.98, 0, 0.02), Vector2(1.77, 0.95), 0.77)
	_box(Vector3(-0.14, 0.85, 0.04), Vector3(0.71, 0.012, 0.57), CREAM, table, 0.002)
	for index: int in range(4):
		var crayon := _cylinder(Vector3(-0.32 + float(index) * 0.18, 0.91, 0.04), 0.025, 0.40, [Color("#cb7860"), Color("#d2b664"), Color("#739eaa"), LEAF][index], table)
		crayon.rotation.z = PI * 0.5
	_bookshelf(Vector3(2.32, 0, -1.19), Vector2(1.51, 1.56))
	_box(Vector3(2.12, 2.35, -1.70), Vector3(1.86, 0.76, 0.12), Color("#ac885c"))
	for index: int in range(4):
		var paper := _box(Vector3(1.49 + float(index) * 0.43, 2.33 + float(index % 2) * 0.05, -1.60), Vector3(0.33, 0.46, 0.015), CREAM)
		paper.rotation.z = -0.09 + float(index % 3) * 0.09
		_sphere(Vector3(paper.position.x, 2.38, -1.58), Vector3(0.085, 0.09, 0.016), Color("#9cb97e"))
	_clock(Vector3(0.04, 2.65, -1.72), 0.28)
	_plant(Vector3(3.01, 0, 0.54), 0.88)


func _clock(position_value: Vector3, radius: float) -> void:
	var ring := _ring(position_value, radius, 0.04, DARK_WOOD)
	ring.rotation.x = PI * 0.5
	_sphere(position_value + Vector3(0, 0, 0.005), Vector3(radius * 0.9, radius * 0.9, 0.025), CREAM)
	_beam(position_value + Vector3(0, 0, 0.04), position_value + Vector3(0, radius * 0.61, 0.04), 0.011, DARK)
	_beam(position_value + Vector3(0, 0, 0.043), position_value + Vector3(radius * 0.47, -radius * 0.15, 0.043), 0.015, DARK)


func _crate(position_value: Vector3, color: Color = WOOD) -> Node3D:
	var crate := _node(position_value)
	_box(Vector3(0, 0.07, 0), Vector3(1.22, 0.1, 0.78), color, crate)
	for row: int in range(3):
		for side: float in [-1.0, 1.0]:
			_box(Vector3(0, 0.16 + float(row) * 0.15, side * 0.38), Vector3(1.25, 0.11, 0.05), color.lightened(float(row) * 0.04), crate)
			_box(Vector3(side * 0.59, 0.16 + float(row) * 0.15, 0), Vector3(0.06, 0.11, 0.77), color, crate)
	return crate


func _market() -> void:
	_room(Color(PALETTES[6][0]), Color(PALETTES[6][1]), false)
	_box(Vector3(0, 1.70, -1.80), Vector3(5.75, 1.94, 0.12), Color("#708c70"))
	_sign("FRESH FRUIT", Vector3(0, 2.64, -1.52), 2.19)
	for index: int in range(12):
		var panel := _box(Vector3(-2.75 + float(index) * 0.5, 2.85, -1.24), Vector3(0.505, 0.095, 1.1), Color("#7e9c78") if index % 2 == 0 else CREAM)
		panel.rotation.x = -0.13
		_box(Vector3(panel.position.x, 2.62, -0.69), Vector3(0.49, 0.28, 0.065), Color("#7e9c78") if index % 2 == 0 else CREAM)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 2.95, 1.33, -0.96), Vector3(0.085, 2.64, 0.085), DARK_WOOD)
		var crate := _crate(Vector3(side * 2.10, 0.39, -0.37))
		_box(Vector3(0, -0.2, 0), Vector3(1.12, 0.45, 0.72), WOOD.darkened(0.16), crate)
		for index: int in range(8):
			var fruit := Vector3(-0.42 + float(index % 4) * 0.28, 0.48 + float(index / 4) * 0.04, -0.18 + float(index / 4) * 0.34)
			_sphere(fruit, Vector3.ONE * 0.15, Color("#bc6f57") if side < 0.0 else Color("#d7b15f"), crate)
			_beam(fruit + Vector3(0, 0.14, 0), fruit + Vector3(0.018, 0.21, 0), 0.013, DARK_WOOD, crate)
		_contact(Vector3(side * 2.1, 0.007, -0.37), Vector2(1.65, 1.15), 0.3)
	var bag := _box(Vector3(1.61, 0.29, 0.75), Vector3(0.47, 0.58, 0.33), Color("#cba56b"), null, 0.03)
	var handle := _ring(bag.position + Vector3(0, 0.34, 0), 0.12, 0.015, DARK_WOOD)
	handle.rotation.x = PI * 0.5
	_box(Vector3(-2.79, 0.71, 0.7), Vector3(0.65, 1.04, 0.10), WOOD)
	_box(Vector3(-2.79, 0.74, 0.765), Vector3(0.53, 0.85, 0.022), DARK)
	_sign("APPLES", Vector3(-2.79, 0.9, 0.8), 0.57, CREAM)
	_plant(Vector3(3.12, 0, 0.72), 0.66)


func _chair(position_value: Vector3, color: Color, angle: float = 0.0) -> void:
	var chair := _node(position_value)
	chair.rotation.y = angle
	_box(Vector3(0, 0.47, 0), Vector3(0.95, 0.22, 0.86), color, chair, 0.08)
	_box(Vector3(0, 0.94, -0.34), Vector3(0.95, 0.94, 0.22), color, chair, 0.10)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 0.46, 0.66, 0.02), Vector3(0.16, 0.28, 0.83), color.darkened(0.08), chair, 0.06)
		for z: float in [-0.3, 0.3]:
			_box(Vector3(side * 0.34, 0.20, z), Vector3(0.08, 0.40, 0.08), DARK_WOOD, chair)
	_contact(position_value + Vector3(0, 0.007, 0), Vector2(1.5, 1.3), 0.32)


func _library() -> void:
	_room(Color(PALETTES[7][0]), Color(PALETTES[7][1]))
	_window(Vector3(0, 2.05, -1.73), Vector2(1.13, 1.66), true)
	_bookshelf(Vector3(-2.31, 0, -1.38), Vector2(1.65, 2.5))
	_bookshelf(Vector3(2.31, 0, -1.38), Vector2(1.65, 2.5))
	_chair(Vector3(-1.94, 0, 0.44), Color("#b68b6b"), 0.15)
	_chair(Vector3(1.94, 0, 0.44), Color("#80988b"), -0.15)
	_cylinder(Vector3(-2.89, 0.52, 0.50), 0.025, 1.05, GOLD)
	_cylinder(Vector3(-2.89, 0.06, 0.50), 0.23, 0.08, DARK_WOOD)
	_cylinder(Vector3(-2.89, 1.13, 0.50), 0.31, 0.36, Color("#e1bd83"), null, 0.13)
	_practical(Vector3(-2.89, 1.03, 0.55), Color("#ffdc9b"), 0.72)
	_sign("STORIES", Vector3(0, 2.97, -1.67), 1.45)


func _zoo() -> void:
	_outdoors(Color(PALETTES[8][1]), Color(PALETTES[8][0]))
	_fence(-1.30, Color("#8b785c"))
	_tree(Vector3(-2.71, 0, -1.65), 2.36)
	_tree(Vector3(2.80, 0, -1.68), 2.07)
	_sphere(Vector3(-2.10, 0.04, 0.46), Vector3(0.96, 0.045, 0.75), Color("#719f9c"))
	for index: int in range(9):
		var angle: float = float(index) * TAU / 9.0
		_sphere(Vector3(-2.10 + cos(angle) * 0.94, 0.07, 0.46 + sin(angle) * 0.72), Vector3(0.18, 0.11, 0.15), Color("#a7ac94"))
	_sphere(Vector3(-2.3, 0.099, 0.4), Vector3(0.18, 0.013, 0.15), Color("#83a879"))
	var map_node := _node(Vector3(2.05, 0, -0.11))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 0.54, 0.92, 0), Vector3(0.09, 1.85, 0.10), DARK_WOOD, map_node)
	_box(Vector3(0, 1.40, 0), Vector3(1.46, 1.05, 0.14), WOOD, map_node)
	_box(Vector3(0, 1.41, 0.09), Vector3(1.28, 0.86, 0.03), CREAM, map_node)
	_sign("ZOO MAP", Vector3(0, 2.02, 0.02), 1.23, Color("#e0c995"), map_node)
	for index: int in range(4):
		_sphere(Vector3(-0.41 + float(index) * 0.28, 1.35 + sin(float(index) * 1.7) * 0.20, 0.13), Vector3(0.12, 0.09, 0.014), LEAF, map_node)
	_beam(Vector3(-0.44, 1.12, 0.145), Vector3(0.45, 1.65, 0.145), 0.025, Color("#d6b064"), map_node)
	var giraffe := _node(Vector3(-0.90, 0.24, -1.75))
	_sphere(Vector3(0, 0.63, 0), Vector3(0.36, 0.25, 0.20), Color("#c9a467"), giraffe)
	_cylinder(Vector3(0.20, 1.03, 0), 0.095, 0.77, Color("#c9a467"), giraffe)
	_sphere(Vector3(0.29, 1.43, 0.06), Vector3(0.22, 0.13, 0.12), Color("#c9a467"), giraffe)
	for side: float in [-1.0, 1.0]:
		_beam(Vector3(side * 0.23, 0.5, 0.07), Vector3(side * 0.26, 0.02, 0.08), 0.045, Color("#bd9458"), giraffe)
	for index: int in range(4):
		_sphere(Vector3(-0.21 + float(index) * 0.13, 0.69, 0.177), Vector3(0.042, 0.055, 0.021), DARK_WOOD, giraffe)
	for index: int in range(6):
		_box(Vector3(-0.35 + float(index % 2) * 0.67, 0.012, 0.6 - float(index / 2) * 0.73), Vector3(0.59, 0.025, 0.52), Color("#c2b590"), null, 0.06)


func _bus() -> void:
	_room(Color(PALETTES[9][0]), Color(PALETTES[9][1]), false)
	_box(Vector3(0, 0.66, -1.79), Vector3(6.67, 1.20, 0.16), Color("#59879c"))
	for x: float in [-2.2, 0.0, 2.2]:
		_window(Vector3(x, 2.0, -1.64), Vector2(1.72, 1.28))
		_box(Vector3(x + 0.97, 1.8, -1.48), Vector3(0.09, 2.30, 0.12), METAL)
	for side: float in [-1.0, 1.0]:
		var seat := _node(Vector3(side * 2.02, 0, -0.27))
		_box(Vector3(0, 0.56, 0), Vector3(1.09, 0.25, 0.95), Color("#b8916f"), seat, 0.075)
		_box(Vector3(0, 1.12, -0.35), Vector3(1.09, 1.0, 0.22), Color("#70919b"), seat, 0.10)
		for index: int in range(3):
			_box(Vector3(-0.28 + float(index) * 0.28, 1.10, -0.22), Vector3(0.024, 0.70, 0.015), Color("#a2b3aa"), seat, 0.0)
		_box(Vector3(0, 0.26, 0), Vector3(0.11, 0.52, 0.53), METAL, seat)
		_beam(Vector3(side * 1.35, 0.08, -0.84), Vector3(side * 1.35, 2.65, -0.84), 0.038, GOLD)
		_contact(Vector3(side * 2.0, 0.007, -0.25), Vector2(1.55, 1.35), 0.35)
	_beam(Vector3(-2.84, 2.73, -0.77), Vector3(2.84, 2.73, -0.77), 0.037, GOLD)
	for x: float in [-2.15, 2.15]:
		_beam(Vector3(x, 2.70, -0.77), Vector3(x, 2.40, -0.77), 0.015, DARK)
		var handle := _ring(Vector3(x, 2.32, -0.77), 0.105, 0.028, Color("#a88255"))
		handle.rotation.x = PI * 0.5
	_sign("PARK  02", Vector3(0, 2.98, -1.52), 1.7, Color("#d6c58b"))
	_box(Vector3(2.28, 0.32, 0.48), Vector3(0.44, 0.59, 0.29), Color("#a66755"), null, 0.06)
	var strap := _ring(Vector3(2.28, 0.67, 0.47), 0.14, 0.025, DARK_WOOD)
	strap.rotation.x = PI * 0.5


func _beach() -> void:
	_outdoors(Color(PALETTES[10][1]), Color(PALETTES[10][0]))
	_box(Vector3(0, 0.32, -1.82), Vector3(7.0, 0.20, 0.72), Color("#79b4bf"), null, 0.09)
	for index: int in range(7):
		_sphere(Vector3(-3.0 + float(index) * 1.0, 0.44, -1.41), Vector3(0.67, 0.05, 0.14), Color("#d6eae0"))
	var castle := _node(Vector3(-2.04, 0, 0.11))
	_box(Vector3(0, 0.34, 0), Vector3(1.10, 0.66, 0.75), Color("#c5aa73"), castle, 0.07)
	for x: float in [-0.53, 0.53]:
		_cylinder(Vector3(x, 0.5, 0), 0.28, 1.0, Color("#dac48f"), castle, 0.24)
		for index: int in range(4):
			var angle: float = float(index) * TAU / 4.0
			_box(Vector3(x + cos(angle) * 0.20, 1.05, sin(angle) * 0.20), Vector3(0.17, 0.17, 0.17), Color("#dac48f"), castle)
	_box(Vector3(0, 0.25, 0.39), Vector3(0.26, 0.49, 0.05), Color("#917249"), castle, 0.06)
	_beam(Vector3(-0.53, 1.03, 0), Vector3(-0.53, 1.66, 0), 0.015, WOOD, castle)
	_flag(Vector3(-0.53, 1.55, 0), Color("#b66c59"), castle)
	var umbrella := _node(Vector3(2.16, 0, -0.34))
	_beam(Vector3(0, 0, 0), Vector3(0, 2.33, 0), 0.03, WOOD, umbrella)
	for index: int in range(10):
		var first: float = float(index) * TAU / 10.0
		var second: float = float(index + 1) * TAU / 10.0
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points: Array[Vector3] = [Vector3(0, 2.45, 0), Vector3(cos(first) * 0.99, 2.05, sin(first) * 0.99), Vector3(cos(second) * 0.99, 2.05, sin(second) * 0.99)]
		_face(surface, points, Vector3(cos((first + second) * 0.5) * 0.36, 0.93, sin((first + second) * 0.5) * 0.36))
		var cloth := _mesh(surface.commit(), Vector3.ZERO, Color("#bd7c62") if index % 2 == 0 else CREAM, umbrella)
		var material := cloth.material_override.duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloth.material_override = material
	_chair(Vector3(2.38, 0, -0.23), Color("#a7b8a5"), -0.18)
	_cylinder(Vector3(1.55, 0.24, 0.75), 0.22, 0.45, Color("#ba6454"), null, 0.27)
	var bucket_handle := _ring(Vector3(1.55, 0.55, 0.75), 0.22, 0.022, CREAM)
	bucket_handle.rotation.x = PI * 0.5
	_beam(Vector3(2.11, 0.07, 0.90), Vector3(2.18, 0.78, 0.91), 0.023, WOOD)
	_box(Vector3(2.10, 0.13, 0.90), Vector3(0.17, 0.23, 0.045), Color("#709b9e"))
	for index: int in range(6):
		_sphere(Vector3(-2.8 + float(index) * 1.05, 0.035, 1.11 + sin(float(index)) * 0.12), Vector3(0.085, 0.037, 0.11), CREAM)


func _flag(position_value: Vector3, color: Color, parent: Node3D = null) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_face(surface, [Vector3(0, 0.1, 0), Vector3(0.42, -0.03, 0), Vector3(0, -0.15, 0)], Vector3.FORWARD)
	var flag := _mesh(surface.commit(), position_value, color, parent)
	var material := flag.material_override.duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag.material_override = material
	_animate(flag, "sway", 0.045, 1.25)


func _camp() -> void:
	_outdoors(Color(PALETTES[11][1]), Color(PALETTES[11][0]))
	for x: float in [-3.0, -1.05, 1.22, 2.96]:
		_tree(Vector3(x, 0, -1.76), 2.5 if absf(x) > 2.0 else 1.9, true)
	for index: int in range(19):
		_sphere(Vector3(-3.1 + float(index) * 0.34, 2.62 + sin(float(index) * 1.73) * 0.40, -2.19), Vector3.ONE * (0.017 if index % 3 else 0.029), Color("#f8edcc"), null, 0.8)
	_sphere(Vector3(1.64, 2.86, -2.13), Vector3(0.22, 0.22, 0.06), Color("#ecdfb9"), null, 0.35)
	var tent := _node(Vector3(-2.06, 0, -0.29))
	var shape := PrismMesh.new()
	shape.size = Vector3(1.77, 1.44, 1.65)
	_mesh(shape, Vector3(0, 0.72, 0), Color("#ae9471"), tent)
	var door := SurfaceTool.new()
	door.begin(Mesh.PRIMITIVE_TRIANGLES)
	_face(door, [Vector3(-0.58, 0.025, 0.835), Vector3(0.58, 0.025, 0.835), Vector3(0, 1.19, 0.835)], Vector3.BACK)
	_mesh(door.commit(), Vector3.ZERO, Color("#354b51"), tent)
	for side: float in [-1.0, 1.0]:
		_beam(Vector3(0, 1.42, 0.84), Vector3(side * 0.89, 0.015, 0.84), 0.027, CREAM, tent)
		_beam(Vector3(side * 0.65, 0.35, 0.65), Vector3(side * 1.02, 0.02, 1.03), 0.009, CREAM, tent)
	_box(Vector3(0, 0.11, 0.4), Vector3(0.46, 0.16, 0.96), Color("#7e9b8b"), tent, 0.07)
	_sphere(Vector3(2.0, 0.19, 0.1), Vector3(0.61, 0.23, 0.51), Color("#7f8a83"))
	_cylinder(Vector3(2.0, 0.69, 0.1), 0.18, 0.49, Color("#e9ca85"))
	_cylinder(Vector3(2.0, 0.98, 0.1), 0.24, 0.12, DARK, null, 0.13)
	_cylinder(Vector3(2.0, 0.42, 0.1), 0.24, 0.09, DARK)
	for side: float in [-1.0, 1.0]:
		_beam(Vector3(2.0 + side * 0.15, 0.43, 0.23), Vector3(2.0 + side * 0.15, 0.96, 0.23), 0.018, DARK)
	var handle := _ring(Vector3(2.0, 1.12, 0.1), 0.16, 0.019, DARK)
	handle.rotation.x = PI * 0.5
	_practical(Vector3(2.0, 0.80, 0.35), Color("#ffc778"), 1.25)
	var log_node := _cylinder(Vector3(2.57, 0.22, 0.91), 0.22, 1.12, WOOD)
	log_node.rotation.z = PI * 0.5
	for index: int in range(5):
		var firefly := _sphere(Vector3(1.22 + float(index) * 0.27, 1.15 + float(index % 3) * 0.33, -0.40), Vector3.ONE * 0.025, Color("#eddb8b"), null, 0.85)
		_animate(firefly, "float", 0.09, 0.8, float(index))


func _bunting() -> void:
	for index: int in range(12):
		var x: float = -2.92 + float(index) * 0.53
		var y: float = 2.90 - cos(x * 0.48) * 0.20
		_beam(Vector3(x - 0.23, y + 0.08, -1.39), Vector3(x + 0.25, y + 0.08, -1.39), 0.008, DARK_WOOD)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_face(surface, [Vector3(-0.18, 0.08, 0), Vector3(0.18, 0.08, 0), Vector3(0, -0.23, 0)], Vector3.BACK)
		_mesh(surface.commit(), Vector3(x, y, -1.36), [Color("#b96c6a"), Color("#bba063"), Color("#839e99"), Color("#9686a9")][index % 4])


func _gift(position_value: Vector3, size_value: float, color: Color) -> void:
	_box(position_value + Vector3(0, size_value * 0.5, 0), Vector3(size_value, size_value, size_value * 0.8), color, null, 0.035)
	_box(position_value + Vector3(0, size_value * 0.5, 0), Vector3(size_value * 0.13, size_value + 0.014, size_value * 0.82), CREAM)
	_box(position_value + Vector3(0, size_value * 0.5, 0), Vector3(size_value + 0.014, size_value + 0.017, size_value * 0.11), CREAM)
	for side: float in [-1.0, 1.0]:
		var bow := _ring(position_value + Vector3(side * size_value * 0.14, size_value + 0.05, 0), size_value * 0.14, 0.018, CREAM)
		bow.rotation.z = side * 0.45


func _birthday() -> void:
	_room(Color(PALETTES[12][0]), Color(PALETTES[12][1]))
	for x: float in [-2.64, -1.32, 0, 1.32, 2.64]:
		_box(Vector3(x, 1.78, -1.80), Vector3(0.96, 2.15, 0.045), Color("#d6b8c4"), null, 0.04)
		_box(Vector3(x, 1.78, -1.76), Vector3(0.82, 2.02, 0.025), Color("#e6cdd0"), null, 0.04)
	_bunting()
	var table := _table(Vector3(-2.08, 0, -0.19), Vector2(1.54, 1.01), 0.84)
	_box(Vector3(0, 0.94, 0), Vector3(1.62, 0.05, 1.07), CREAM, table)
	for tier: int in range(3):
		var radius: float = 0.45 - float(tier) * 0.10
		_cylinder(Vector3(0, 1.11 + float(tier) * 0.25, 0), radius, 0.24, Color("#d6a79c") if tier % 2 == 0 else CREAM, table)
		_cylinder(Vector3(0, 1.24 + float(tier) * 0.25, 0), radius + 0.014, 0.04, CREAM, table)
	for index: int in range(3):
		var x: float = (float(index) - 1.0) * 0.15
		_cylinder(Vector3(x, 1.88, 0), 0.017, 0.24, Color("#be9470"), table)
		_sphere(Vector3(x, 2.035, 0), Vector3(0.027, 0.053, 0.027), Color("#ffe0a0"), table, 0.7)
	_gift(Vector3(2.03, 0.01, -0.12), 0.68, Color("#809c9e"))
	_gift(Vector3(2.53, 0.01, 0.62), 0.51, Color("#bc916b"))
	_gift(Vector3(2.03, 0.72, -0.12), 0.43, Color("#b87e93"))
	for side: float in [-1.0, 1.0]:
		for index: int in range(3):
			var position_value := Vector3(side * (2.70 + float(index % 2) * 0.30), 2.0 + float(index) * 0.32, -1.05)
			var balloon := _sphere(position_value, Vector3(0.23, 0.30, 0.22), [Color("#c68885"), Color("#d2b779"), Color("#91afb0")][index])
			_animate(balloon, "float", 0.035, 1.0, float(index))
			_beam(position_value - Vector3(0, 0.31, 0), Vector3(side * 2.7, 0.4, -1.05), 0.006, CREAM)
	_practical(Vector3(-2.1, 1.8, 0.6), Color("#ffe0b2"), 0.55)


func _toy(position_value: Vector3, type: int, parent: Node3D = null) -> void:
	var toy := _node(position_value, parent)
	match type:
		0:
			_box(Vector3(0, 0.12, 0), Vector3(0.58, 0.18, 0.30), Color("#b9735a"), toy)
			_box(Vector3(0.03, 0.27, 0), Vector3(0.29, 0.19, 0.26), Color("#bd976d"), toy)
			for x: float in [-0.19, 0.19]:
				for z: float in [-0.18, 0.18]:
					var wheel := _cylinder(Vector3(x, 0.08, z), 0.085, 0.05, DARK, toy)
					wheel.rotation.x = PI * 0.5
		1:
			_sphere(Vector3(0, 0.17, 0), Vector3(0.33, 0.085, 0.09), Color("#bca56a"), toy)
			_box(Vector3(0, 0.16, 0), Vector3(0.22, 0.055, 0.70), Color("#7c9c9c"), toy)
			_box(Vector3(-0.23, 0.22, 0), Vector3(0.12, 0.15, 0.31), Color("#7c9c9c"), toy)
		2:
			_sphere(Vector3(0, 0.15, 0), Vector3(0.15, 0.18, 0.11), Color("#b58a5c"), toy)
			_sphere(Vector3(0, 0.37, 0), Vector3.ONE * 0.13, Color("#bd966b"), toy)
			for side: float in [-1.0, 1.0]:
				_sphere(Vector3(side * 0.12, 0.47, 0), Vector3.ONE * 0.06, Color("#b58a5c"), toy)
				_sphere(Vector3(side * 0.05, 0.39, 0.12), Vector3.ONE * 0.015, DARK, toy)
				_sphere(Vector3(side * 0.10, 0.04, 0.05), Vector3(0.09, 0.05, 0.09), Color("#b58a5c"), toy)
			_box(Vector3(0, 0.27, 0.11), Vector3(0.17, 0.046, 0.035), Color("#a9605f"), toy)
		3:
			_box(Vector3(0, 0.19, 0), Vector3(0.29, 0.27, 0.22), Color("#7c9b99"), toy)
			_box(Vector3(0, 0.42, 0), Vector3(0.32, 0.23, 0.25), Color("#a6b8aa"), toy)
			for side: float in [-1.0, 1.0]:
				_sphere(Vector3(side * 0.07, 0.43, 0.13), Vector3.ONE * 0.028, DARK, toy)
				_box(Vector3(side * 0.21, 0.20, 0), Vector3(0.09, 0.26, 0.10), Color("#bfa36e"), toy)
				_box(Vector3(side * 0.09, 0.04, 0), Vector3(0.12, 0.09, 0.19), DARK, toy)
		4:
			_box(Vector3(0, 0.13, 0), Vector3(0.47, 0.24, 0.35), Color("#ab8394"), toy)
			_box(Vector3(0, 0.29, -0.12), Vector3(0.49, 0.07, 0.36), CREAM, toy)
			var key := _ring(Vector3(0.28, 0.17, 0), 0.06, 0.018, GOLD, toy)
			key.rotation.z = PI * 0.5


func _workshop() -> void:
	_room(Color(PALETTES[13][0]), Color(PALETTES[13][1]))
	_box(Vector3(0, 2.15, -1.78), Vector3(5.91, 1.18, 0.11), Color("#b59771"))
	var peg_mesh := MultiMesh.new()
	peg_mesh.transform_format = MultiMesh.TRANSFORM_3D
	var peg_shape := SphereMesh.new()
	peg_shape.radius = 0.018
	peg_shape.height = 0.036
	peg_shape.radial_segments = 6
	peg_shape.rings = 3
	peg_mesh.mesh = peg_shape
	peg_mesh.instance_count = 81
	for index: int in range(81):
		peg_mesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(-2.7 + float(index % 27) * 0.207, 1.83 + float(index / 27) * 0.33, -1.715)))
	var holes := MultiMeshInstance3D.new()
	holes.multimesh = peg_mesh
	holes.material_override = _material(Color("#786b58"))
	_root.add_child(holes)
	for side: float in [-1.0, 1.0]:
		var bench := _table(Vector3(side * 2.13, 0, -0.45), Vector2(1.65, 1.02), 0.86)
		_box(Vector3(0, 0.53, 0.12), Vector3(1.37, 0.47, 0.73), Color("#7e9992"), bench)
		for drawer: int in range(2):
			_box(Vector3(0, 0.39 + float(drawer) * 0.24, 0.50), Vector3(1.24, 0.19, 0.045), Color("#9eafa0"), bench)
			_box(Vector3(0, 0.40 + float(drawer) * 0.24, 0.55), Vector3(0.22, 0.025, 0.05), GOLD, bench)
		_box(Vector3(-0.35, 0.95, 0.04), Vector3(0.21, 0.05, 0.55), Color("#827269"), bench)
		_cylinder(Vector3(0.52, 1.1, -0.16), 0.13, 0.33, Color("#b78a64"), bench)
		for index: int in range(3):
			_beam(Vector3(0.46 + float(index) * 0.07, 1.1, -0.16), Vector3(0.43 + float(index) * 0.1, 1.56, -0.15), 0.018, [WOOD, GOLD, Color("#ad7560")][index], bench)
	for index: int in range(5):
		var x: float = -2.42 + float(index) * 1.21
		_box(Vector3(x, 1.53, -1.31), Vector3(0.87, 0.075, 0.62), WOOD)
		_toy(Vector3(x, 1.57, -1.18), index)
		_cylinder(Vector3(x, 2.74, -1.57), 0.095, 0.09, DARK)
		var lamp := _sphere(Vector3(x, 2.72, -1.54), Vector3(0.095, 0.11, 0.085), Color("#7a887f"))
		_repair_lamps.append(lamp)
	_clock(Vector3(0, 2.24, -1.62), 0.24)
	for x: float in [-1.08, 1.08]:
		_beam(Vector3(x, 1.92, -1.64), Vector3(x, 2.47, -1.64), 0.045, WOOD)
		_box(Vector3(x, 2.46, -1.62), Vector3(0.35, 0.13, 0.11), METAL)
	_practical(Vector3(-2.10, 1.68, -0.32), Color("#ffdbad"), 0.52)
	_practical(Vector3(2.10, 1.68, -0.32), Color("#dceaca"), 0.42)

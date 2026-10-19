extends SceneTree
## Review compositions use acquired source meshes only; no production profile is changed.

const OUTPUT: String = "res://build/professional-english/theme-review"
var source_root: String = "Q:/uwok/Kenney Game Assets All-in-1 3.7.0/3D assets"
var scene: Node3D
var camera: Camera3D
var models: Dictionary = {}
var source_records: Dictionary = {}
var captures: Array[Dictionary] = []
var contacts: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first: bool = true
	for child: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var transform: Transform3D = node.global_transform.affine_inverse() * child.global_transform
		var part: AABB = transform * child.get_aabb()
		if first:
			result = part
			first = false
		else:
			result = result.merge(part)
	return result


func _model(pack: String, item: String, at: Vector3, yaw: float = 0.0, factor: float = 1.0) -> Node3D:
	var format: String = "GLTF format" if pack == "Furniture Kit" else "GLB format"
	var key: String = pack + "/" + item
	var path: String = source_root.path_join(pack + "/Models/" + format + "/" + item + ".glb")
	return _model_file(key, path, at, yaw, factor)


func _model_file(key: String, path: String, at: Vector3, yaw: float = 0.0, factor: float = 1.0) -> Node3D:
	if not models.has(key):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(path, state) == OK, "Source GLB must load: " + path)
		var original: Node3D = document.generate_scene(state)
		root.add_child(original)
		var bounds: AABB = _bounds(original)
		source_records[key] = {"source_path": path, "sha256": FileAccess.get_sha256(path),
			"bounds": [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z],
			"available_animations": Array(state.get_animations()).size()}
		root.remove_child(original)
		models[key] = original
	var holder := Node3D.new()
	scene.add_child(holder)
	var copy: Node3D = models[key].duplicate()
	holder.add_child(copy)
	var b: AABB = _bounds(copy)
	copy.position = Vector3(-b.get_center().x, -b.position.y, -b.get_center().z)
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw)
	holder.scale = Vector3.ONE * factor
	return holder


func _room(pack: String) -> void:
	var floor_name: String = "floorFull" if pack == "Furniture Kit" else "floor"
	for x in range(4):
		for z in range(3):
			_model(pack, floor_name, Vector3(x - 1.5, 0, z - 1))
	for x in range(4):
		_model(pack, "wallWindow" if pack == "Furniture Kit" and x % 2 == 1 else ("wall-window" if pack == "Mini Market" and x % 2 == 1 else "wall"), Vector3(x - 1.5, 0.03, -1.55))
	for z in range(3):
		_model(pack, "wall", Vector3(-2.0, 0.03, z - 1), 90)


func _retail() -> void:
	_room("Mini Market")
	_model("Mini Market", "freezers-standing", Vector3(1.15, 0.03, -1.05))
	_model("Mini Market", "shelf-boxes", Vector3(-0.75, 0.03, -0.45))
	_model("Mini Market", "shelf-bags", Vector3(0.35, 0.03, -0.30))
	_model("Mini Market", "display-fruit", Vector3(-1.25, 0.03, 0.62))
	_model("Mini Market", "display-bread", Vector3(-0.25, 0.03, 0.78))
	_model("Mini Market", "cash-register", Vector3(1.25, 0.03, 0.78))
	_model("Mini Market", "shopping-cart", Vector3(0.52, 0.03, 1.05), -20)
	_model("Mini Market", "shopping-basket", Vector3(1.65, 0.03, -0.22))


func _software() -> void:
	_room("Furniture Kit")
	for x: float in [-0.95, 0.7]:
		_model("Furniture Kit", "desk", Vector3(x, 0.05, -0.35), 180, 1.5)
		_model("Furniture Kit", "computerScreen", Vector3(x - 0.07, 0.627, -0.48), 0, 1.3)
		_model("Furniture Kit", "computerKeyboard", Vector3(x - 0.07, 0.627, -0.18), 180, 1.3)
		_model("Furniture Kit", "computerMouse", Vector3(x + 0.27, 0.627, -0.15), 180, 1.3)
		_model("Furniture Kit", "chairDesk", Vector3(x, 0.05, 0.48), 180, 1.5)
	_model("Furniture Kit", "bookcaseOpen", Vector3(-1.55, 0.05, -0.9), 180, 1.3)
	_model("Furniture Kit", "books", Vector3(-1.55, 0.62, -0.84), 0, 1.5)
	_model("Furniture Kit", "pottedPlant", Vector3(1.5, 0.05, -1.0), 0, 1.4)
	_model("Furniture Kit", "pottedPlant", Vector3(-1.5, 0.05, 0.9), 0, 1.3)
	_model("Furniture Kit", "lampRoundFloor", Vector3(1.55, 0.05, 0.6), 0, 1.5)


func _caregiving() -> void:
	_room("Furniture Kit")
	_model("Furniture Kit", "loungeSofa", Vector3(-0.6, 0.05, -0.85), 0, 1.5)
	_model("Furniture Kit", "loungeChair", Vector3(1.15, 0.05, -0.35), -35, 1.5)
	_model("Furniture Kit", "sideTable", Vector3(1.25, 0.05, -1.1), 0, 1.5)
	_model("Furniture Kit", "lampRoundTable", Vector3(1.25, 0.627, -1.1), 0, 1.2)
	_model("Furniture Kit", "tableCoffee", Vector3(0.0, 0.05, 0.28), 0, 1.2)
	_model("Furniture Kit", "books", Vector3(-0.1, 0.33, 0.28), 0, 1.0)
	_model("Mini Characters", "wheelchair", Vector3(-1.2, 0.05, 0.65), -25, 1.5)
	_model("Furniture Kit", "pottedPlant", Vector3(-1.5, 0.05, -1.05), 0, 1.4)


func _food_service() -> void:
	_room("Furniture Kit")
	_model("Furniture Kit", "kitchenFridge", Vector3(-1.5, 0.05, -1.0), 0, 1.5)
	_model("Furniture Kit", "kitchenStove", Vector3(-0.65, 0.05, -1.1), 0, 1.5)
	_model("Furniture Kit", "hoodLarge", Vector3(-0.65, 0.9, -1.1), 0, 1.5)
	_model("Furniture Kit", "kitchenSink", Vector3(0.15, 0.05, -1.1), 0, 1.5)
	_model("Furniture Kit", "kitchenCabinet", Vector3(0.95, 0.05, -1.1), 0, 1.5)
	_model("Furniture Kit", "kitchenCoffeeMachine", Vector3(0.95, 0.725, -1.1), 0, 1.3)
	for x: float in [-0.9, 0.95]:
		_model("Furniture Kit", "tableCloth", Vector3(x, 0.05, 0.45), 0, 1.3)
		_model("Furniture Kit", "chair", Vector3(x - 0.53, 0.05, 0.45), 90, 1.3)
		_model("Furniture Kit", "chair", Vector3(x + 0.53, 0.05, 0.45), -90, 1.3)
		_model("Food Kit", "plate-dinner", Vector3(x, 0.475, 0.45), 0, 0.24)
	_model("Furniture Kit", "pottedPlant", Vector3(1.65, 0.05, -0.45), 0, 1.1)


func _surface_y(object: Node3D) -> float:
	return object.position.y + _bounds(object).end.y * object.scale.y


func _office_admin() -> void:
	_room("Furniture Kit")
	_model("Furniture Kit", "bookcaseClosedWide", Vector3(-1.05, 0.05, -1.1), 0, 1.4)
	_model("Furniture Kit", "bookcaseClosedDoors", Vector3(0.1, 0.05, -1.1), 0, 1.4)
	var desk: Node3D = _model("Furniture Kit", "deskCorner", Vector3(-0.7, 0.05, 0.15), 180, 1.5)
	var desk_top: float = _surface_y(desk)
	_model("Furniture Kit", "laptop", Vector3(-0.7, desk_top, 0.05), 0, 1.3)
	_model("Furniture Kit", "books", Vector3(-1.1, desk_top, 0.4), 30, 1.15)
	_model("Furniture Kit", "chairDesk", Vector3(-0.65, 0.05, 0.85), 180, 1.5)
	var table: Node3D = _model("Furniture Kit", "tableRound", Vector3(1.05, 0.05, 0.2), 0, 1.35)
	_model("Furniture Kit", "books", Vector3(1.05, _surface_y(table), 0.2), 20, 1.0)
	_model("Furniture Kit", "chairCushion", Vector3(1.05, 0.05, 0.9), 180, 1.35)
	_model("Furniture Kit", "chairCushion", Vector3(1.05, 0.05, -0.5), 0, 1.35)
	_model("Furniture Kit", "coatRackStanding", Vector3(1.65, 0.05, -1.0), 0, 1.5)
	_model("Furniture Kit", "pottedPlant", Vector3(-1.6, 0.05, 0.9), 0, 1.3)


func _hr_recruitment() -> void:
	_room("Furniture Kit")
	var table: Node3D = _model("Furniture Kit", "tableRound", Vector3(-0.55, 0.05, 0.05), 0, 2.0)
	var table_top: float = _surface_y(table)
	_model("Furniture Kit", "laptop", Vector3(-0.65, table_top, -0.12), 0, 1.15)
	_model("Furniture Kit", "books", Vector3(-0.3, table_top, 0.2), 25, 0.9)
	_model("Furniture Kit", "chairRounded", Vector3(-0.55, 0.05, -0.85), 0, 1.5)
	_model("Furniture Kit", "chairRounded", Vector3(-1.35, 0.05, 0.55), 125, 1.5)
	_model("Furniture Kit", "chairRounded", Vector3(0.25, 0.05, 0.55), -125, 1.5)
	_model("Furniture Kit", "benchCushion", Vector3(1.35, 0.05, -0.55), -90, 1.6)
	_model("Furniture Kit", "pottedPlant", Vector3(1.4, 0.05, 0.85), 0, 1.5)
	_model("Furniture Kit", "coatRackStanding", Vector3(1.4, 0.05, -1.15), 0, 1.5)
	_model("Furniture Kit", "lampRoundFloor", Vector3(-1.55, 0.05, -1.1), 0, 1.6)


func _nursing() -> void:
	_room("Furniture Kit")
	_model_file("Innerscene/hospital-bed-raised-backrest",
		ProjectSettings.globalize_path("res://docs/assets/sources/innerscene-hospital-bed/hospital-bed-raised-backrest.glb"),
		Vector3(-0.65, 0.05, -0.15), 90, 0.9)
	_model("Furniture Kit", "cabinetBedDrawerTable", Vector3(0.25, 0.05, -0.95), 0, 1.5)
	_model("Furniture Kit", "chairCushion", Vector3(0.85, 0.05, -0.1), -60, 1.5)
	_model("Mini Characters", "wheelchair", Vector3(1.2, 0.05, 0.8), -20, 1.5)
	_model("Furniture Kit", "bookcaseClosedDoors", Vector3(1.45, 0.05, -1.05), 0, 1.3)


func _hospitality() -> void:
	_room("Furniture Kit")
	var counter: Node3D = _model("Furniture Kit", "kitchenBar", Vector3(-0.45, 0.05, -0.38), 0, 1.8)
	_model("Furniture Kit", "kitchenBar", Vector3(-1.2, 0.05, -0.38), 0, 1.8)
	_model("Furniture Kit", "laptop", Vector3(-0.45, _surface_y(counter), -0.38), 180, 1.25)
	_model("Furniture Kit", "books", Vector3(-1.2, _surface_y(counter), -0.38), 0, 1.0)
	_model("Furniture Kit", "chairDesk", Vector3(-0.65, 0.05, -1.05), 0, 1.4)
	_model("Furniture Kit", "loungeDesignSofa", Vector3(1.15, 0.05, -0.25), -90, 1.4)
	var table: Node3D = _model("Furniture Kit", "tableCoffeeGlassSquare", Vector3(0.68, 0.05, 0.65), 0, 1.4)
	_model("Furniture Kit", "books", Vector3(0.68, _surface_y(table), 0.65), 25, 1.1)
	_model("Furniture Kit", "pottedPlant", Vector3(1.6, 0.05, -1.05), 0, 1.5)
	_model("Furniture Kit", "coatRackStanding", Vector3(-1.65, 0.05, 0.8), 0, 1.5)
	_model("Furniture Kit", "rugDoormat", Vector3(-0.55, 0.055, 0.85), 0, 1.7)

func _education() -> void:
	_room("Furniture Kit")
	_model("Furniture Kit", "bookcaseOpenLow", Vector3(-1.15, 0.05, -1.05), 0, 1.65)
	_model("Furniture Kit", "bookcaseOpenLow", Vector3(0.35, 0.05, -1.05), 0, 1.65)
	_model("Furniture Kit", "books", Vector3(-1.15, 0.35, -0.98), 0, 1.7)
	_model("Furniture Kit", "books", Vector3(0.35, 0.35, -0.98), 0, 1.7)
	var table: Node3D = _model("Furniture Kit", "tableRound", Vector3(-0.65, 0.05, 0.45), 0, 1.45)
	_model("Furniture Kit", "books", Vector3(-0.65, _surface_y(table), 0.45), 20, 1.0)
	_model("Furniture Kit", "chairRounded", Vector3(-1.3, 0.05, 0.45), 90, 1.05)
	_model("Furniture Kit", "chairRounded", Vector3(-0.65, 0.05, 1.1), 180, 1.05)
	_model("Furniture Kit", "chairRounded", Vector3(0.0, 0.05, 0.45), -90, 1.05)
	_model("Furniture Kit", "rugRound", Vector3(1.15, 0.055, 0.42), 0, 1.6)
	_model("Furniture Kit", "bear", Vector3(1.1, 0.065, 0.35), -25, 1.3)
	_model("Furniture Kit", "pillowBlue", Vector3(1.55, 0.065, 0.65), 20, 1.3)
	_model("Furniture Kit", "pottedPlant", Vector3(1.55, 0.05, -1.0), 0, 1.2)

func _warehouse() -> void:
	for x in range(4):
		for z in range(3):
			_model("Factory Kit", "floor", Vector3(x - 1.5, 0, z - 1))
	for x in range(4):
		_model("Furniture Kit", "wall", Vector3(x - 1.5, 0.03, -1.55))
	for z in range(3):
		_model("Furniture Kit", "wall", Vector3(-2.0, 0.03, z - 1), 90)
	for z: float in [-0.8, 0.65]:
		var pallet: Node3D = _model("Mini Skate", "pallet", Vector3(-1.2, 0.05, z), 0, 1.2)
		var first: Node3D = _model("Furniture Kit", "cardboardBoxClosed", Vector3(-1.2, _surface_y(pallet), z), 0, 1.6)
		_model("Furniture Kit", "cardboardBoxClosed", Vector3(-1.2, _surface_y(first), z), 15, 1.15)
	_model_file("Innerscene/electric-counterbalance-forklift", ProjectSettings.globalize_path("res://docs/assets/sources/innerscene-forklift/electric-counterbalance-forklift.glb"), Vector3(0.8, 0.05, 0.2), -25, 0.55)

func _sized(pack: String, item: String, at: Vector3, yaw: float, height: float) -> Node3D:
	var object: Node3D = _model(pack, item, at, yaw)
	object.scale = Vector3.ONE * height / _bounds(object).size.y
	return object

func _transport() -> void:
	_room("Furniture Kit")
	_sized("Car Kit", "delivery", Vector3(-0.65, 0.05, 0.25), -25, 1.28)
	var pallet: Node3D = _model("Mini Skate", "pallet", Vector3(1.15, 0.05, 0.65), 0, 1.1)
	var carton: Node3D = _model("Furniture Kit", "cardboardBoxClosed", Vector3(1.15, _surface_y(pallet), 0.65), 0, 1.7)
	_model("Furniture Kit", "cardboardBoxClosed", Vector3(1.15, _surface_y(carton), 0.65), 0, 1.1)
	var desk: Node3D = _model("Furniture Kit", "desk", Vector3(1.05, 0.05, -0.95), 0, 1.3)
	_model("Furniture Kit", "laptop", Vector3(1.05, _surface_y(desk), -0.95), 180, 1.0)
	_model("Furniture Kit", "chairDesk", Vector3(1.05, 0.05, -0.3), 180, 1.1)

func _manufacturing() -> void:
	for x in range(4):
		for z in range(3):
			_model("Factory Kit", "floor", Vector3(x - 1.5, 0, z - 1))
	for x in range(4):
		_model("Furniture Kit", "wall", Vector3(x - 1.5, 0.03, -1.55))
	for z in range(3):
		_model("Furniture Kit", "wall", Vector3(-2.0, 0.03, z - 1), 90)
	_sized("Factory Kit", "machine-window", Vector3(-1.0, 0.05, -0.55), 0, 1.15)
	_sized("Factory Kit", "machine-fortified", Vector3(0.3, 0.05, -0.65), 0, 1.0)
	var belt: Node3D = _sized("Factory Kit", "conveyor-sides", Vector3(-0.95, 0.05, 0.65), 0, 0.35)
	_sized("Factory Kit", "box-small", Vector3(-0.95, _surface_y(belt), 0.65), 0, 0.28)
	var bench: Node3D = _model("Furniture Kit", "desk", Vector3(1.2, 0.05, 0.5), -90, 1.3)
	_model("Furniture Kit", "laptop", Vector3(1.2, _surface_y(bench), 0.6), -90, 0.95)
	_sized("Factory Kit", "cog-c", Vector3(1.2, _surface_y(bench), 0.15), 0, 0.12)

func _facilities() -> void:
	_room("Furniture Kit")
	_model("Furniture Kit", "bookcaseClosedDoors", Vector3(-1.2, 0.05, -1.05), 0, 1.6)
	_model("Furniture Kit", "kitchenSink", Vector3(0.3, 0.05, -1.05), 0, 1.65)
	_model("Furniture Kit", "kitchenCabinet", Vector3(1.2, 0.05, -1.05), 0, 1.65)
	_model_file("Innerscene/wringer-bucket", ProjectSettings.globalize_path("res://docs/assets/sources/innerscene-wringer-bucket/wringer-bucket.glb"), Vector3(0.4, 0.05, 0.45), -25, 1.55)
	_model_file("Innerscene/wet-dry-vacuum", ProjectSettings.globalize_path("res://docs/assets/sources/innerscene-wet-dry-vacuum/wet-dry-vacuum.glb"), Vector3(-0.9, 0.05, 0.55), 20, 1.4)
	var mop: Node3D = _model_file("Innerscene/sponge-mop", ProjectSettings.globalize_path("res://docs/assets/sources/innerscene-sponge-mop/sponge-mop.glb"), Vector3(-1.6, 0.05, 0.6), 0, 1.25)
	mop.rotation_degrees.z = 13.0

func _array(bounds: AABB) -> Array:
	return [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z]

func _extra_source(folder: String, filename: String, at := Vector3.ZERO, degrees := Vector3.ZERO, factor := 1.0) -> Node3D:
	var object := _model_file("Innerscene/" + filename,
		ProjectSettings.globalize_path("res://docs/assets/sources/" + folder + "/" + filename + ".glb"), at, degrees.y, factor)
	object.rotation_degrees = degrees
	return object

func _extra_kenney(pack: String, item: String, at: Vector3, yaw := 0.0, factor := 1.0) -> Node3D:
	var format: String = "GLTF format" if pack == "Furniture Kit" else "GLB format"
	return _model_file(pack + "/" + item,
		ProjectSettings.globalize_path("res://docs/assets/sources/kenney-extra-theme-assets/" + pack + "/Models/" + format + "/" + item + ".glb"), at, yaw, factor)

func _part_surface_y(object: Node3D, token: String) -> float:
	for mesh: MeshInstance3D in object.find_children("*", "MeshInstance3D", true, false):
		if token.to_lower() in mesh.name.to_lower():
			var world_bounds: AABB = mesh.global_transform * mesh.get_aabb()
			contacts[token] = {"node_name": mesh.name, "world_bounds": _array(world_bounds), "contact_y": world_bounds.end.y}
			return world_bounds.end.y
	assert(false, "Missing authored surface: " + token)
	return 0.0

func _rest_on(object: Node3D, y: float) -> void:
	var world_bounds: AABB = object.global_transform * _bounds(object)
	object.position.y += y - world_bounds.position.y

func _construction() -> void:
	_room("Furniture Kit")
	var bench := _extra_source("innerscene-carpentry-workbench", "carpenters-workbench-with-vise", Vector3(0.25, 0.05, 0.23), Vector3.ZERO, 1.12)
	var tabletop := _part_surface_y(bench, "slab")
	_extra_source("innerscene-cordless-drill", "cordless-drill-driver", Vector3(0.7, tabletop, 0.12), Vector3(0, -35, 0), 1.5)
	_extra_source("innerscene-step-ladder", "folding-step-ladder", Vector3(-1.3, 0.05, -0.4), Vector3(0, 18, 0), 1.35)
	_extra_kenney("Survival Kit", "resource-planks", Vector3(1.35, 0.05, -0.85), 90, 1.2)
	_extra_kenney("Survival Kit", "resource-planks", Vector3(-1.25, 0.05, 0.9), 15, 1.15)
	var hammer := _extra_kenney("Survival Kit", "tool-hammer", Vector3(-0.22, tabletop, 0.14), -25, 1.1)
	# The acquired hammer is stored upright; lay the original model on the slab.
	hammer.rotation_degrees.x = 90
	_rest_on(hammer, tabletop)
	_extra_kenney("Furniture Kit", "cardboardBoxOpen", Vector3(1.5, 0.05, 0.65), 15, 1.2)

func _it_support() -> void:
	_room("Furniture Kit")
	var bench := _extra_source("innerscene-electronics-repair-bench", "electronics-repair-bench", Vector3(-0.2, 0.05, -0.32), Vector3.ZERO, 1.25)
	var tabletop := _part_surface_y(bench, "Antistatic")
	_extra_kenney("Furniture Kit", "laptop", Vector3(-0.65, tabletop, -0.25), 0, 1.3)
	_extra_source("innerscene-network-switch", "eight-port-network-switch", Vector3(0.04, tabletop, -0.16), Vector3.ZERO, 2.3)
	_extra_source("innerscene-screwdriver", "hand-screwdriver-tool", Vector3(-0.6, tabletop, 0.03), Vector3(0, -90, 0), 1.35)
	var shelf := _extra_kenney("Furniture Kit", "bookcaseOpenLow", Vector3(1.3, 0.05, 0.08), 0, 1.65)
	var shelf_top: float = shelf.position.y + _bounds(shelf).end.y * shelf.scale.y
	_extra_kenney("Furniture Kit", "computerScreen", Vector3(1.3, shelf_top, 0.08), 0, 1.3)
	_extra_kenney("Furniture Kit", "cardboardBoxOpen", Vector3(-1.3, 0.05, 0.8), -15, 1.4)
	_extra_kenney("Furniture Kit", "chairDesk", Vector3(0.05, 0.05, 0.95), 150, 1.35)


func _remaining_source(item: String, at: Vector3, yaw := 0.0, factor := 1.0) -> Node3D:
	var folder := "res://docs/assets/sources/innerscene-" + item
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "/source-inventory.json"))
	var path := ProjectSettings.globalize_path(folder + "/" + item + ".glb")
	assert(FileAccess.get_sha256(path) == inventory.sha256, "Changed inspected source: " + item)
	return _model_file("Innerscene/" + item, path, at, yaw, factor)


func _remaining_surface_y(object: Node3D, key: String) -> float:
	var world_bounds: AABB = object.global_transform * _bounds(object)
	contacts[key] = {"world_bounds": _array(world_bounds), "contact_y": world_bounds.end.y}
	return world_bounds.end.y


func _customer_support() -> void:
	_room("Furniture Kit")
	var desk := _model("Furniture Kit", "desk", Vector3(-0.25, 0.05, 0.1), 180, 1.9)
	var top := _remaining_surface_y(desk, "customer-support/desk")
	_model("Furniture Kit", "computerScreen", Vector3(-0.54, top, -0.08), 0, 1.3)
	_model("Furniture Kit", "computerKeyboard", Vector3(-0.54, top, 0.18), 180, 1.3)
	_remaining_source("office-phone", Vector3(0.14, top, 0.19), -15, 2.2)
	_model("Furniture Kit", "chairDesk", Vector3(-0.4, 0.05, 0.99), 155, 1.6)
	_model("Furniture Kit", "bookcaseClosedDoors", Vector3(-1.35, 0.05, -1.02), 0, 1.35)
	_model("Furniture Kit", "chairCushion", Vector3(1.33, 0.05, -0.28), -50, 1.4)
	_model("Furniture Kit", "pottedPlant", Vector3(1.4, 0.05, -1.05), 0, 1.35)


func _accounting_finance() -> void:
	_room("Furniture Kit")
	var desk := _model("Furniture Kit", "desk", Vector3(-0.38, 0.05, 0.16), 180, 1.8)
	var top := _remaining_surface_y(desk, "accounting-finance/desk")
	_remaining_source("calculator", Vector3(0, top, 0.18), -18, 3.0)
	_model("Furniture Kit", "laptop", Vector3(-0.65, top, -0.01), 0, 1.2)
	_model("Furniture Kit", "books", Vector3(-0.7, top, 0.35), 20, 1.0)
	_model("Furniture Kit", "chairDesk", Vector3(-0.4, 0.05, 1.03), 160, 1.6)
	var cabinet := _remaining_source("lateral-filing-cabinet", Vector3(1.16, 0.05, -0.72), 0, 1.0)
	_remaining_source("document-scanner", Vector3(1.16, _remaining_surface_y(cabinet, "accounting-finance/cabinet"), -0.72), 0, 1.15)
	_model("Furniture Kit", "bookcaseClosedDoors", Vector3(-1.4, 0.05, -1.0), 0, 1.5)


func _sales_marketing() -> void:
	_room("Furniture Kit")
	var pedestal := _remaining_source("display-pedestal", Vector3(-0.72, 0.05, 0.25), 0, 0.975)
	_remaining_source("studio-headphones", Vector3(-0.72, _remaining_surface_y(pedestal, "sales-marketing/pedestal"), 0.25), 0, 1.8)
	var table := _model("Furniture Kit", "tableRound", Vector3(0.95, 0.05, 0.22), 0, 1.6)
	_model("Furniture Kit", "laptop", Vector3(0.95, _remaining_surface_y(table, "sales-marketing/table"), 0.15), 0, 1.1)
	_model("Furniture Kit", "chairRounded", Vector3(0.95, 0.05, 1.0), 180, 1.3)
	_model("Furniture Kit", "chairRounded", Vector3(0.95, 0.05, -0.58), 0, 1.3)
	_model("Furniture Kit", "loungeSofa", Vector3(-0.95, 0.05, -1.03), 0, 1.5)
	_model("Furniture Kit", "pottedPlant", Vector3(1.55, 0.05, -1.0), 0, 1.35)
	_model("Furniture Kit", "lampRoundFloor", Vector3(-1.55, 0.05, 0.9), 0, 1.4)


func _clinical_medicine() -> void:
	_room("Furniture Kit")
	_remaining_source("clinical-exam-table", Vector3(-0.62, 0.05, 0.1), 0, 1.08)
	_remaining_source("medical-supply-cart", Vector3(1.18, 0.05, 0.62), -15, 1.0)
	_model("Furniture Kit", "kitchenSink", Vector3(-1.35, 0.05, -1.08), 0, 1.4)
	_model("Furniture Kit", "bookcaseClosedDoors", Vector3(-0.55, 0.05, -1.08), 0, 1.4)
	var desk := _model("Furniture Kit", "desk", Vector3(1.1, 0.05, -0.87), 0, 1.3)
	_model("Furniture Kit", "laptop", Vector3(1.1, _remaining_surface_y(desk, "clinical-medicine/desk"), -0.87), 0, 1.0)
	_model("Furniture Kit", "chairCushion", Vector3(1.1, 0.05, -0.12), 180, 1.2)


func _justice_art() -> void:
	var path := ProjectSettings.globalize_path("res://docs/assets/sources/perhelion-justice/balanced-scale-of-justice.svg")
	assert(FileAccess.get_sha256(path) == "27dfbd55daa3207f77fd23eb5d1b3645509755af0f1584926adc5f927ec42c70", "Changed inspected scales illustration")
	var picture := Image.new()
	assert(picture.load_svg_from_string(FileAccess.get_file_as_string(path), 0.5) == OK)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(picture)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# This transparent surface only carries the unchanged sourced illustration on the room wall.
	var plane := QuadMesh.new()
	plane.size = Vector2(0.68, 0.68 * 1256.0 / 1600.0)
	var artwork := MeshInstance3D.new()
	artwork.mesh = plane
	artwork.material_override = material
	artwork.position = Vector3(0.43, 1.0, -1.475)
	scene.add_child(artwork)
	source_records["Perhelion/Balanced scale of Justice"] = {"source_path": path, "sha256": FileAccess.get_sha256(path), "available_animations": 0, "use": "Unmodified sourced wall illustration on a transparent carrier surface; no generated icon or primitive replacement art."}


func _legal_paralegal() -> void:
	_room("Furniture Kit")
	_remaining_source("filled-bookshelf", Vector3(-1.3, 0.05, -1.03), 0, 0.75)
	_remaining_source("lateral-filing-cabinet", Vector3(1.32, 0.05, -1.02), 0, 1.1)
	var desk := _model("Furniture Kit", "desk", Vector3(-0.25, 0.05, 0.35), 180, 2.0)
	var top := _remaining_surface_y(desk, "legal-paralegal/desk")
	_model("Furniture Kit", "books", Vector3(0.2, top, 0.35), -15, 1.55)
	_model("Furniture Kit", "laptop", Vector3(-0.6, top, 0.3), 0, 1.1)
	_model("Furniture Kit", "chairDesk", Vector3(-0.25, 0.05, 1.05), 180, 1.35)
	_model("Furniture Kit", "chairCushion", Vector3(1.24, 0.05, 0.5), -60, 1.25)
	_justice_art()


func _capture(id: String) -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	assert(picture.save_png(OUTPUT + "/" + id + "-source-composition.png") == OK)
	var phone: Image = picture.duplicate()
	phone.resize(296, 185, Image.INTERPOLATE_LANCZOS)
	assert(phone.save_png(OUTPUT + "/" + id + "-phone-review.png") == OK)
	var preview: Image = picture.duplicate()
	preview.resize(512, 320, Image.INTERPOLATE_LANCZOS)
	assert(preview.save_png(OUTPUT + "/" + id + "-preview-candidate.png") == OK)
	captures.append({"id": id, "review_status": "pending_visual_inspection", "source_composition": id + "-source-composition.png", "phone_review": id + "-phone-review.png", "preview_candidate": id + "-preview-candidate.png"})


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Theme review requires a real renderer.")
		quit(1)
		return
	var override: String = OS.get_environment("KENNEY_LIBRARY")
	if not override.is_empty():
		source_root = override.path_join("3D assets")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1280, 800)
	root.msaa_3d = Viewport.MSAA_4X
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("f6f3e9")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.25
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fffaf0")
	sun.light_energy = 0.6
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	root.add_child(camera)
	camera.position = Vector3(6, 5, 8)
	camera.look_at(Vector3(0, 0.52, 0))
	for id: String in ["retail", "software-data", "caregiving", "food-service", "office-admin", "hr-recruitment", "nursing", "warehouse-logistics", "hospitality-tourism", "education-childcare", "transport-delivery", "manufacturing-maintenance", "cleaning-facilities", "construction-trades", "it-support", "customer-support", "accounting-finance", "sales-marketing", "clinical-medicine", "legal-paralegal"]:
		sun.light_energy = 0.48 if id == "nursing" else (0.52 if id in ["construction-trades", "it-support", "customer-support", "accounting-finance", "sales-marketing", "clinical-medicine", "legal-paralegal"] else 0.6)
		scene = Node3D.new()
		root.add_child(scene)
		match id:
			"customer-support": _customer_support()
			"accounting-finance": _accounting_finance()
			"sales-marketing": _sales_marketing()
			"clinical-medicine": _clinical_medicine()
			"legal-paralegal": _legal_paralegal()
			"construction-trades": _construction()
			"it-support": _it_support()
			"transport-delivery": _transport()
			"manufacturing-maintenance": _manufacturing()
			"cleaning-facilities": _facilities()
			"warehouse-logistics": _warehouse()
			"hospitality-tourism": _hospitality()
			"education-childcare": _education()
			"retail": _retail()
			"software-data": _software()
			"caregiving": _caregiving()
			"food-service": _food_service()
			"office-admin": _office_admin()
			"hr-recruitment": _hr_recruitment()
			"nursing": _nursing()
		await _capture(id)
		scene.queue_free()
		await process_frame
	var report := {"notice": "Actual acquired source models, composed and rendered for art review. These are review candidates, not integrated themes or occupationally reviewed scenes. No source preview image is used as scene art.", "renderer": RenderingServer.get_video_adapter_name(), "sources": source_records, "captures": captures, "contacts": contacts}
	var output := FileAccess.open(OUTPUT + "/source-composition-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for original: Node3D in models.values():
		original.free()
	print("Theme source review: %d compositions, %d PNGs, %d distinct source assets" % [captures.size(), captures.size() * 3, source_records.size()])
	quit(0)

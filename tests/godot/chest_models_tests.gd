extends SceneTree

const Model = preload("res://scripts/chest_model_view.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Feel = preload("res://scripts/chest_feel.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var data = load("res://scripts/game_data.gd").new()
	check(data.load_all(), "All chest catalogs load")
	for id: String in ["harvest", "tide", "nebula", "bramble", "bonbon"]:
		_check_model(id, data.chests.styles[id])
	_check_release_arrival(data)
	_check_idle_render_budget(data)
	_check_lifecycle(data)
	_check_original_styles(data)
	_check_independent_surfaces(data)
	print("Live chest models: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_model(id: String, style: Dictionary) -> void:
	var model := Model.new()
	root.add_child(model)
	if not model.configure(style):
		check(false, id + " loads an articulated model with renderable geometry")
		model.free()
		return
	var state: Dictionary = model.snapshot()
	check(state.mesh_count > 0 and not state.parts.is_empty(), id + " retains source meshes and separate articulated parts")
	check(not model.is_processing(), id + " has no independent clock or reward lifecycle")
	var bounds: Rect2 = model.design_bounds()
	var closed: Rect2 = model.closed_bounds()
	var cavity: Vector2 = model.cavity_point()
	var seam: PackedVector2Array = model.seam_points()
	check(Rect2(0, 0, 1024, 1024).encloses(bounds) and bounds.encloses(closed),
		id + " fits the complete open envelope in its fixed design canvas")
	check(bounds.has_point(cavity) and seam.size() >= 2, id + " anchors shared effects to its real cavity and lid seam")
	model.set_display_size(Vector2(180, 240))
	check(model.snapshot().resolution == 512, id + " keeps a crisp minimum surface on small screens")
	model.set_display_size(Vector2(769, 600))
	check(model.snapshot().resolution == 832, id + " adapts to physical display pixels in stable allocation steps")
	model.set_display_size(Vector2(3000, 2200))
	check(model.snapshot().resolution == 1024, id + " bounds mobile memory even for an oversized display request")
	check(model.design_bounds() == bounds and model.closed_bounds() == closed and model.cavity_point() == cavity
		and model.seam_points() == seam, id + " keeps framing and effect anchors fixed as render resolution changes")
	model.set_render_active(true)
	check(model.snapshot().active and model.render_target_update_mode == SubViewport.UPDATE_ONCE,
		id + " requests a render without running an unconditional viewport loop")
	model.set_pose(0, 0, 0, 0, 0, Color.WHITE, false)
	var rest: Array = model.snapshot().parts.duplicate(true)
	model.set_pose(0, 0.8, 0.45, 0, 0, Color.WHITE, false)
	state = model.snapshot()
	check(state.parts != rest and state.open_amount == 0.0,
		id + " visibly loads real mechanisms without opening its cavity early")
	model.set_pose(0, 0, 0, 0, 0, Color.WHITE, false)
	check(model.snapshot().parts == rest, id + " restores its exact closed mechanism after cancelled pressure")
	model.set_pose(0.143, 0, 0, 0, 0, Color.WHITE, false)
	var fractional: Array = model.snapshot().parts.duplicate(true)
	model.set_pose(0.151, 0, 0, 0, 0, Color.WHITE, false)
	var adjacent: Array = model.snapshot().parts.duplicate(true)
	check(fractional != adjacent and _maximum_angle(fractional, adjacent) < 0.20,
		id + " interpolates geometry at nearby fractional positions instead of selecting baked frames")
	model.set_pose(0.61, 0.5, 0.8, 5, 1.2, Color.YELLOW, false)
	model.set_pose(0.143, 0, 0, 0, 0, Color.WHITE, false)
	check(model.snapshot().parts == fractional,
		id + " samples absolute poses without accumulating lock, handle or bone offsets")
	model.set_pose(1, 0, 0, 0, 1, Color.WHITE, false)
	var open_parts: Array = model.snapshot().parts.duplicate(true)
	check(_maximum_angle(rest, open_parts, "lid") > 0.5
		or _maximum_displacement(rest, open_parts, "lid") > 0.25,
		id + " has a substantial real lid opening, not only whole-body shaking")
	model.set_pose(1, 0.8, 0.7, 9, 1, Color.WHITE, true)
	var reduced: Dictionary = model.snapshot()
	model.set_pose(1, 0, 0, 0, 1, Color.WHITE, true)
	check(model.snapshot().parts == reduced.parts and reduced.pressure == 0.0 and reduced.idle_time == 0.0
		and reduced.model_rotation == Vector3.ZERO,
		id + " preserves an open final model while suppressing pressure, sway and idle motion when reduced")
	model.set_render_active(false)
	model.set_pose(0.5, 0, 0, 0, 0, Color.WHITE, false)
	check(not model.snapshot().active and model.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		id + " performs no rendering while its owning view is paused or hidden")
	model.free()


func _maximum_angle(first: Array, second: Array, role: String = "") -> float:
	var distance: float = 0.0
	for index in range(mini(first.size(), second.size())):
		if not role.is_empty() and (first[index].role != role or second[index].role != role):
			continue
		var a: Quaternion = first[index].rotation
		var b: Quaternion = second[index].rotation
		distance = maxf(distance, a.angle_to(b))
	return distance


func _maximum_displacement(first: Array, second: Array, role: String) -> float:
	var distance: float = 0.0
	for index in range(mini(first.size(), second.size())):
		if first[index].role != role or second[index].role != role:
			continue
		var a: Vector3 = first[index].position
		var b: Vector3 = second[index].position
		distance = maxf(distance, a.distance_to(b))
	return distance


func _check_release_arrival(data) -> void:
	var chest := Chest.new()
	root.add_child(chest)
	chest.size = Vector2(440, 360)
	chest.set_process(false)
	for theme: String in ["autumn", "ocean", "space", "jungle", "candy"]:
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		chest.start_open(false)
		chest._advance_animation(Feel.SETTLE_TIME - 0.060)
		var late: float = chest.hold_effect_snapshot().live_model.open_amount
		chest._advance_animation(0.050)
		var before_stop: float = chest.hold_effect_snapshot().live_model.open_amount
		check(late > 0.0 and before_stop > late and before_stop < 1.0,
			theme + " keeps moving its lid through the final approach to its open position")
		chest._advance_animation(Feel.SETTLE_TIME - chest._elapsed)
		check(is_equal_approx(chest.hold_effect_snapshot().live_model.open_amount, 1.0)
			and chest.mode == "opening",
			theme + " reaches its final source pose at the settle cue while preserving the completion tail")
	chest.free()


func _check_lifecycle(data) -> void:
	var chest := Chest.new()
	root.add_child(chest)
	chest.size = Vector2(440, 360)
	var events := {"opened": 0, "release": 0}
	chest.opened.connect(func() -> void: events.opened += 1)
	chest.release_reached.connect(func() -> void: events.release += 1)
	for theme: String in ["autumn", "ocean", "space", "jungle", "candy"]:
		chest.clear()
		chest.reduced_motion = false
		chest.configure_skin(data.theme(theme), data.chests)
		chest.set_process(false)
		var rest: Array = chest.hold_effect_snapshot().live_model.parts.duplicate(true)
		chest.begin_hold()
		chest.set_hold_progress(0.8)
		check(chest.hold_effect_snapshot().live_model.parts != rest, theme + " routes real part pressure through the shared hold")
		chest.cancel_hold()
		chest._advance_animation(Feel.CANCEL_SECONDS + 0.01)
		check(chest.hold_effect_snapshot().live_model.parts == rest and chest.mode == "closed",
			theme + " restores its source mechanism after a cancelled hold")
		chest.start_open(false)
		chest._advance_animation(Feel.RELEASE_TIME - 0.2)
		chest.cancel_open()
		chest._advance_animation(Feel.CANCEL_SECONDS + 0.01)
		check(chest.hold_effect_snapshot().live_model.parts == rest and events.opened == 0 and events.release == 0,
			theme + " safely cancels a pre-release performance without granting a reward")
		chest.start_open(false)
		chest._advance_animation(Feel.RELEASE_TIME + 0.18)
		var before_hide: Dictionary = chest.hold_effect_snapshot().live_model.duplicate(true)
		chest.hide()
		chest._advance_animation(5.0)
		var hidden: Dictionary = chest.hold_effect_snapshot().live_model
		check(hidden.parts == before_hide.parts and hidden.open_amount == before_hide.open_amount and not hidden.active,
			theme + " freezes geometry and its renderer when hidden")
		chest.show()
		chest.finish_immediately()
		chest.set_idle_paused(true)
		var paused: Dictionary = chest.hold_effect_snapshot().live_model.duplicate(true)
		chest._advance_animation(5.0)
		var after: Dictionary = chest.hold_effect_snapshot().live_model
		check(after.parts == paused.parts and after.model_rotation == paused.model_rotation and not after.active,
			theme + " stops idle model animation and rendering when paused")
		chest.set_idle_paused(false)
		events.opened = 0
		events.release = 0
	chest.free()


func _check_idle_render_budget(data) -> void:
	var model := Model.new()
	root.add_child(model)
	check(model.configure(data.chests.styles.harvest), "Idle render budget uses a real articulated model")
	model.set_render_active(true)
	model.set_pose(1, 0, 0, 2.001, 0.94, Color.WHITE, false, false)
	var first: Dictionary = model.snapshot()
	# Simulate consumption of UPDATE_ONCE without depending on GPU timing.
	model.render_target_update_mode = SubViewport.UPDATE_DISABLED
	model.set_pose(1, 0, 0, 2.030, 0.945, Color.WHITE, false, false)
	check(model.render_target_update_mode == SubViewport.UPDATE_DISABLED
		and model.snapshot().parts == first.parts and model.snapshot().light_strength == first.light_strength,
		"Idle geometry and varying light share a 15 Hz render budget")
	model.set_pose(1, 0, 0, 2.071, 0.95, Color.WHITE, false, false)
	check(model.render_target_update_mode == SubViewport.UPDATE_ONCE
		and model.snapshot().idle_time > first.idle_time,
		"The next idle sample requests a fresh model surface")
	model.render_target_update_mode = SubViewport.UPDATE_DISABLED
	model.set_pose(1, 0.3, 0.2, 2.072, 0.955, Color.WHITE, false, true)
	check(model.render_target_update_mode == SubViewport.UPDATE_ONCE
		and is_equal_approx(model.snapshot().idle_time, 2.072)
		and is_equal_approx(model.snapshot().light_strength, 0.955),
		"An active performance bypasses idle sampling for responsive pressure and lighting")
	model.set_pose(1, 0, 0, 9, 0.94, Color.WHITE, true, false)
	model.render_target_update_mode = SubViewport.UPDATE_DISABLED
	model.set_pose(1, 0, 0, 19, 0.96, Color.WHITE, true, false)
	check(model.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"Reduced idle motion does not continuously render a static model")
	model.free()


func _check_original_styles(data) -> void:
	var chest := Chest.new()
	root.add_child(chest)
	chest.size = Vector2(320, 320)
	for theme: String in ["spring", "summer", "winter"]:
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		check(chest.hold_effect_snapshot().get("live_model", {}).is_empty() and chest.piece_count() >= 4,
			theme + " preserves its original layered artwork")
	chest.free()


func _check_independent_surfaces(data) -> void:
	var chests: Array = []
	var sources: Dictionary = {}
	for theme: String in ["ocean", "space", "jungle"]:
		var chest := Chest.new()
		root.add_child(chest)
		chest.size = Vector2(240, 320)
		chest.configure_skin(data.theme(theme), data.chests)
		chest.set_process(false)
		chests.append(chest)
		sources[chest.hold_effect_snapshot().live_model.source] = true
	var other_parts: Array = chests[1].hold_effect_snapshot().live_model.parts.duplicate(true)
	chests[0].start_open(true)
	check(sources.size() == 3 and chests[0].hold_effect_snapshot().live_model.open_amount == 1.0
		and chests[1].hold_effect_snapshot().live_model.parts == other_parts
		and chests[2].hold_effect_snapshot().live_model.open_amount == 0.0,
		"Three simultaneous reward chests retain separate models, textures and opening states")
	for chest in chests:
		chest.free()

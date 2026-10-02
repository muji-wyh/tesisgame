extends SceneTree

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
	check(data.load_all(), "Chest reveal assets load")
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(320, 320)
	chest.configure_skin(data.theme("spring"), data.chests)
	var rest: Dictionary = chest._physical_pose.duplicate(true)
	chest.begin_hold()
	check(chest._physical_pose != rest, "A short press immediately loads the closed chest")
	for tap in range(20):
		chest.cancel_hold()
		chest.begin_hold()
	check(chest._hold_active and is_zero_approx(chest._cancel_remaining),
		"Rapid presses replace the return motion without blocking new input")
	chest.cancel_hold()
	chest._advance_animation(Feel.CANCEL_SECONDS + 0.01)
	check(is_zero_approx(chest._cancel_remaining) and chest._physical_pose == rest,
		"The short-press reaction returns to rest")
	check(chest.mode == "closed", "A short press never opens a chest")
	chest.set_hold_progress(0.8)
	check(chest._glint.visible, "Holding reveals a native latch glow")
	chest.cancel_hold()
	check(not chest._glint.visible, "Cancelling the hold removes its glow")
	chest.reduced_motion = true
	chest.begin_hold()
	chest.set_hold_progress(0.8)
	check(is_zero_approx(chest._art.rotation) and not chest._glint.visible,
		"Reduced motion keeps press and hold reactions static")
	chest.set_hold_progress(0.0)
	chest.start_open(false)
	chest.begin_hold()
	check(not chest._hold_active, "An opening chest ignores new presses")
	chest.free()
	_check_themed_chests(data)
	_check_opened_ambience(data)
	_check_opened_light_handoff(data)
	_check_release_light(data)
	_check_opened_bounds(data)
	_check_opening_cancel(data)
	_check_release_commitment(data)
	_check_hold_feedback(data)
	_check_crown_effects(data)
	_check_buildup_glow(data)
	_check_hold_bounds(data)
	var medal_path := "res://scripts/medal_view.gd"
	check(FileAccess.file_exists(medal_path), "The saved favorite medal view exists")
	if FileAccess.file_exists(medal_path):
		var medal = load(medal_path).new()
		root.add_child(medal)
		medal.size = Vector2(120, 90)
		var texture: Texture2D = load("res://assets/images/rewards/spring-1.svg")
		for count in range(4):
			medal.configure(texture, count, Color("#438363"))
			check(medal.pieces == count and medal.texture == texture,
				"The shared medal view represents zero through three pieces")
		medal.configure(null, 0, Color("#606a73"))
		check(medal.texture == null and medal.pieces == 0, "Empty medals need no eagerly loaded image")
		medal.free()
	print("Chest reveal: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_themed_chests(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(320, 320)
	var opened_themes: Array[String] = []
	chest.opened.connect(func() -> void: opened_themes.append(chest.theme_id))
	for theme_id in data.THEMES:
		chest.clear()
		chest.reduced_motion = true
		var palette: Dictionary = data.theme(theme_id)
		chest.configure_skin(palette, data.chests)
		var before: int = opened_themes.size()
		chest.start_open(true)
		chest.configure_skin(palette, data.chests)
		chest.start_open(true)
		chest.finish_immediately()
		check(chest.mode == "opened" and chest.theme_id == theme_id
			and opened_themes.size() == before + 1 and opened_themes.back() == theme_id,
			"Refreshing the earned " + theme_id + " chest keeps it open without awarding again")
		var state: Dictionary = chest.hold_effect_snapshot()
		check(state.opened_glow > 0.0 and not state.opened_animated and is_zero_approx(state.opened_idle_time)
			and is_zero_approx(state.release_impact) and is_zero_approx(state.release_flash),
			"The reduced-motion " + theme_id + " chest opens directly into a steady themed light")
		for dimensions in [Vector2(320, 190), Vector2(180, 400), Vector2(640, 420)]:
			chest.size = dimensions
			chest.set_drag_offset(Vector2.ZERO)
			var stage := Rect2(Vector2.ZERO, chest.size).grow(0.5)
			var visible_pieces := 0
			var outside: Array[String] = []
			for piece in chest._pieces:
				var sprite: Sprite2D = piece.node
				if not sprite.is_visible_in_tree() or sprite.modulate.a <= 0.001:
					continue
				visible_pieces += 1
				var transform: Transform2D = chest.get_global_transform().affine_inverse() * sprite.get_global_transform()
				var bounds: Rect2 = sprite.get_rect()
				for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
					if not stage.has_point(transform * corner):
						outside.append(str(piece.role) + " at " + str(transform * corner))
			check(visible_pieces > 0 and outside.is_empty(),
				"The opened %s chest keeps every transformed artwork corner inside %s without clipping: %s" % [theme_id, dimensions, outside])
	chest.free()


func _check_opened_ambience(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(440, 360)
	var openings: Array[String] = []
	var cues: Array = []
	chest.opened.connect(func() -> void: openings.append(chest.theme_id))
	chest.cue_requested.connect(func(theme: String, cue: String, step: int) -> void:
		cues.append([theme, cue, step]))
	for theme in data.THEMES:
		chest.clear()
		chest.reduced_motion = false
		chest.configure_skin(data.theme(theme), data.chests)
		var state: Dictionary = chest.hold_effect_snapshot()
		check(is_zero_approx(state.opened_glow) and not state.opened_animated,
			theme + " keeps its idle light and sway exclusive to the earned opening")
		var previous_openings: int = openings.size()
		chest.start_open(false)
		chest._advance_animation(Feel.OPEN_SECONDS - 0.02)
		state = chest.hold_effect_snapshot()
		var fitted_scale: float = state.fitted_scale
		check(state.opened_glow > 0.0 and chest.mode == "opening" and openings.size() == previous_openings,
			theme + " carries its settling light into the saved result without rewarding early")
		chest._advance_animation(0.03)
		state = chest.hold_effect_snapshot()
		check(chest.mode == "opened" and openings.size() == previous_openings + 1
			and state.opened_glow > 0.0 and state.opened_animated and not state.active,
			theme + " retains light and starts a gentle idle after its single opening completes")
		check(state.release_color == Feel.FLASH_COLORS[theme].to_html(false)
			and is_zero_approx(state.release_flash) and is_equal_approx(state.fitted_scale, fitted_scale),
			theme + " keeps its themed light and fitted size after the one-shot flash finishes")
		var saved_scale: Vector2 = chest._art.scale
		var cue_count: int = cues.size()
		var minimum_rotation: float = chest._art.rotation
		var maximum_rotation: float = chest._art.rotation
		var previous_rotation: float = chest._art.rotation
		var maximum_step: float = 0.0
		var stays_lit: bool = true
		var minimum_beam: float = INF
		var minimum_surface: float = INF
		var light_issues: Array[String] = []
		var fixed_scale: bool = true
		for frame in range(48):
			chest._advance_animation(0.25)
			state = chest.hold_effect_snapshot()
			stays_lit = stays_lit and state.opened_glow > 0.0 and is_zero_approx(state.release_flash)
			minimum_beam = minf(minimum_beam, state.opened_beam_strength)
			minimum_surface = minf(minimum_surface, state.opened_surface_light)
			var surface: Dictionary = _surface_light_snapshot(chest, state)
			if surface.visible == 0 or surface.minimum < 0.60 or not surface.issues.is_empty():
				light_issues.append("%.2fs: %s" % [state.opened_idle_time, surface])
			fixed_scale = fixed_scale and chest._art.scale.is_equal_approx(saved_scale) and is_equal_approx(state.fitted_scale, fitted_scale)
			minimum_rotation = minf(minimum_rotation, chest._art.rotation)
			maximum_rotation = maxf(maximum_rotation, chest._art.rotation)
			maximum_step = maxf(maximum_step, absf(chest._art.rotation - previous_rotation))
			previous_rotation = chest._art.rotation
		check(stays_lit and fixed_scale, theme + " stays illuminated for twelve seconds without resizing or squashing its open body")
		check(minimum_beam >= 0.65 and minimum_surface >= 0.60,
			"%s sustains strong cavity rays and reflected body light after the flash: beam %.3f, surface %.3f" % [theme, minimum_beam, minimum_surface])
		check(light_issues.is_empty(),
			"%s lights every visible body, lid and facet from its moving cavity: %s" % [theme, light_issues])
		check(state.opened_light_color == Feel.FLASH_COLORS[theme].to_html(false),
			theme + " uses its theme color for the persistent cavity light")
		check(maximum_rotation > 0.005 and minimum_rotation < -0.005 and maximum_rotation <= 0.05
			and minimum_rotation >= -0.05 and maximum_step < 0.02,
			theme + " sways gently in both directions instead of resuming its fast opening shake")
		check(cues.size() == cue_count and openings.size() == previous_openings + 1,
			theme + " never repeats opening sounds or reward signals during its idle")

		chest.hide()
		var hidden_time: float = chest.hold_effect_snapshot().opened_idle_time
		chest._advance_animation(7.0)
		state = chest.hold_effect_snapshot()
		check(not chest.is_processing() and not state.opened_animated and state.opened_idle_time == hidden_time,
			theme + " freezes its idle clock while the result is hidden")
		chest.show()
		chest._advance_animation(0.25)
		state = chest.hold_effect_snapshot()
		check(state.opened_glow > 0.0 and state.opened_animated and state.opened_idle_time > hidden_time
			and cues.size() == cue_count and openings.size() == previous_openings + 1,
			theme + " resumes the earned ambience without replaying its opening")

		chest.set_idle_paused(true)
		var paused: Dictionary = chest.hold_effect_snapshot()
		chest._advance_animation(9.0)
		state = chest.hold_effect_snapshot()
		check(not state.opened_animated and state.opened_idle_time == paused.opened_idle_time
			and state.pose_signature == paused.pose_signature and state.opened_glow == paused.opened_glow,
			theme + " freezes its pose and light when the page explicitly pauses the result")
		chest.set_idle_paused(false)
		chest._advance_animation(0.25)
		check(chest.hold_effect_snapshot().opened_animated
			and chest.hold_effect_snapshot().opened_idle_time > paused.opened_idle_time,
			theme + " resumes its slow idle after the page returns")

		chest.reduced_motion = true
		chest._advance_animation(0.01)
		var static_state: Dictionary = chest.hold_effect_snapshot()
		var static_surface: Dictionary = _surface_light_snapshot(chest, static_state)
		var static_result: bool = static_state.opened_glow > 0.0 and not static_state.opened_animated \
			and static_state.opened_beam_strength >= 0.65 and static_state.opened_surface_light >= 0.60 \
			and static_surface.visible > 0 and static_surface.minimum >= 0.60 and static_surface.issues.is_empty()
		for delta in [0.3, 4.0, 12.0]:
			chest._advance_animation(delta)
			state = chest.hold_effect_snapshot()
			static_result = static_result and state.pose_signature == static_state.pose_signature \
				and state.opened_glow == static_state.opened_glow and state.opened_idle_time == static_state.opened_idle_time \
				and state.opened_beam_strength == static_state.opened_beam_strength \
				and state.opened_surface_light == static_state.opened_surface_light \
				and state.opened_light_color == static_state.opened_light_color \
				and state.opened_beam_bounds == static_state.opened_beam_bounds \
				and _surface_light_snapshot(chest, state) == static_surface
		check(static_result, theme + " retains strong static rays and surface light with no sway or breathing when reduced motion is enabled")
		chest.start_open(false)
		chest.finish_immediately()
		check(openings.size() == previous_openings + 1 and cues.size() == cue_count,
			theme + " ignores duplicate starts and finishes while showing the lit result")

		chest.clear()
		state = chest.hold_effect_snapshot()
		check(chest.mode == "closed" and is_zero_approx(state.opened_glow) and not state.opened_animated
			and is_zero_approx(state.opened_idle_time) and is_zero_approx(state.opened_beam_strength)
			and is_zero_approx(state.opened_surface_light) and is_zero_approx(_surface_light_snapshot(chest, state).maximum),
			theme + " clears every opened idle effect and surface light for the next reward")
		chest.configure_skin(data.theme(theme), data.chests)
		chest.start_open(false)
		cue_count = cues.size()
		chest.finish_immediately()
		chest._advance_animation(2.0)
		state = chest.hold_effect_snapshot()
		check(chest.mode == "opened" and state.opened_glow > 0.0 and state.opened_animated
			and is_zero_approx(state.release_flash) and is_zero_approx(state.release_impact) and cues.size() == cue_count
			and openings.size() == previous_openings + 2,
			theme + " shows earned idle light after skipping without a delayed flash, sound or reward")
		var next_theme: String = "winter" if theme != "winter" else "spring"
		chest.configure_skin(data.theme(next_theme), data.chests)
		state = chest.hold_effect_snapshot()
		check(chest.mode == "closed" and is_zero_approx(state.opened_glow)
			and is_zero_approx(state.opened_idle_time) and not state.opened_animated,
			theme + " cannot carry its open ambience into a newly configured chest")
	chest.free()


func _surface_light_snapshot(chest, state: Dictionary) -> Dictionary:
	var visible: int = 0
	var minimum: float = INF
	var maximum: float = 0.0
	var issues: Array[String] = []
	var uniforms: Array[Dictionary] = []
	var cavity := Vector2(state.cavity_origin.x, state.cavity_origin.y)
	for piece in chest._pieces:
		var sprite: Sprite2D = piece.node
		if not sprite.is_visible_in_tree() or sprite.modulate.a <= 0.001:
			continue
		visible += 1
		var material := sprite.material as ShaderMaterial
		if material == null or material.shader == null:
			issues.append(str(piece.role) + " has no surface-light shader")
			continue
		var strength: Variant = material.get_shader_parameter("light_strength")
		var origin: Variant = material.get_shader_parameter("light_origin")
		var distance: Variant = material.get_shader_parameter("light_distance")
		var color: Variant = material.get_shader_parameter("light_color")
		if not strength is float or not origin is Vector2 or not distance is Vector2 or not color is Color:
			issues.append(str(piece.role) + " is missing a surface-light uniform")
			continue
		if not is_finite(strength) or not origin.is_finite() or not distance.is_finite() or distance.x <= 0.0 or distance.y <= 0.0:
			issues.append(str(piece.role) + " has an invalid surface-light uniform")
			continue
		minimum = minf(minimum, strength)
		maximum = maxf(maximum, strength)
		uniforms.append({"role": piece.role, "strength": strength, "origin": origin,
			"distance": distance, "color": color})
		# Reverse the actual shader UVs through the sprite's full transform.
		# A shared world-space light must stay inside the cavity as parts move.
		var texture_position: Vector2 = origin
		if sprite.flip_h:
			texture_position.x = 1.0 - texture_position.x
		if sprite.flip_v:
			texture_position.y = 1.0 - texture_position.y
		var local_source: Vector2 = sprite.offset + texture_position * sprite.texture.get_size()
		if sprite.region_enabled:
			local_source -= sprite.region_rect.position
		var source: Vector2 = chest._art.transform * sprite.transform * local_source
		if source.distance_to(cavity) > 0.02:
			issues.append("%s light source is %.3f pixels from the cavity" % [piece.role, source.distance_to(cavity)])
	return {"visible": visible, "minimum": minimum, "maximum": maximum,
		"issues": issues, "uniforms": uniforms}


func _check_opened_light_handoff(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(440, 360)
	for theme in data.THEMES:
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		chest.start_open(false)
		chest._advance_animation(Feel.RELEASE_TIME + 0.08)
		var state: Dictionary = chest.hold_effect_snapshot()
		var previous: Dictionary = state
		var minimum_beam: float = state.opened_beam_strength
		var minimum_surface: float = state.opened_surface_light
		var largest_step: float = 0.0
		var completion_step: float = INF
		var last_mode: String = chest.mode
		# Dense sampling spans the burst, its fade, completion, and the first idle.
		for frame in range(220):
			chest._advance_animation(1.0 / 120.0)
			state = chest.hold_effect_snapshot()
			minimum_beam = minf(minimum_beam, state.opened_beam_strength)
			minimum_surface = minf(minimum_surface, state.opened_surface_light)
			var change: float = maxf(absf(state.opened_beam_strength - previous.opened_beam_strength),
				absf(state.opened_surface_light - previous.opened_surface_light))
			largest_step = maxf(largest_step, change)
			if last_mode == "opening" and chest.mode == "opened":
				completion_step = change
			last_mode = chest.mode
			previous = state
		check(minimum_beam >= 0.65 and minimum_surface >= 0.60,
			"%s has no dark gap as the release burst becomes lasting light: beam %.3f, surface %.3f" % [theme, minimum_beam, minimum_surface])
		check(largest_step < 0.08 and completion_step < 0.04,
			"%s blends into its opened light without a brightness jump: sample %.3f, completion %.3f" % [theme, largest_step, completion_step])
		check(chest.mode == "opened" and is_zero_approx(state.release_flash)
			and state.opened_beam_strength >= 0.65 and state.opened_surface_light >= 0.60,
			theme + " retains strong light after the one-shot release flash has fully ended")
	chest.free()


func _check_release_light(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.set_process(false)
	for theme in data.THEMES:
		for dimensions in [Vector2(320, 72), Vector2(180, 400), Vector2(440, 360)]:
			chest.clear()
			chest.size = dimensions
			chest.reduced_motion = false
			chest.configure_skin(data.theme(theme), data.chests)
			chest.start_open(false)
			chest._advance_animation(Feel.RELEASE_TIME - 0.01)
			var before: Dictionary = chest.hold_effect_snapshot()
			check(is_zero_approx(before.release_impact) and is_zero_approx(before.release_flash),
				"%s reserves its release impact for the physical opening at %s" % [theme, dimensions])
			var samples: Array[Dictionary] = []
			var geometry_issues: Array[String] = []
			for age in [0.016, 0.10, 0.22, 0.42, 0.66, 1.10]:
				chest._advance_animation(Feel.RELEASE_TIME + age - chest.hold_effect_snapshot().opening_time)
				var state: Dictionary = chest.hold_effect_snapshot()
				samples.append(state)
				if state.release_impact > 0.0:
					_record_release_geometry(chest, state, geometry_issues)
				if is_equal_approx(age, 0.10):
					for drag in [Vector2(-dimensions.x, 0.0), Vector2(dimensions.x, 0.0)]:
						chest.set_drag_offset(drag)
						_record_release_geometry(chest, chest.hold_effect_snapshot(), geometry_issues)
					chest.set_drag_offset(Vector2.ZERO)
			var onset: Dictionary = samples[0]
			var peak: Dictionary = samples[1]
			var fading: Dictionary = samples[2]
			var late: Dictionary = samples[3]
			var ambient: Dictionary = samples[5]
			check(onset.release_impact > 0.0 and peak.release_impact >= 0.60
				and peak.release_impact > onset.release_impact and peak.release_additive,
				"%s rapidly builds a bright additive release at %s" % [theme, dimensions])
			check(peak.opened_beam_strength >= ambient.opened_beam_strength * 1.35
				and peak.opened_surface_light >= ambient.opened_surface_light * 1.20,
				"%s has a stronger release than its lasting cavity and surface light at %s" % [theme, dimensions])
			var first_bloom: Dictionary = onset.release_bloom_bounds
			var bloom: Dictionary = peak.release_bloom_bounds
			check(bloom.width >= dimensions.x * 0.80 and bloom.height >= dimensions.y * 0.75
				and bloom.width * bloom.height > first_bloom.width * first_bloom.height * 1.35,
				"%s expands its cavity bloom across the stage within 100 milliseconds at %s" % [theme, dimensions])
			var first_wave: Dictionary = onset.release_wave_bounds
			var wave: Dictionary = fading.release_wave_bounds
			check(wave.width * wave.height > first_wave.width * first_wave.height * 2.0,
				"%s visibly pushes its release wave outward from the cavity at %s" % [theme, dimensions])
			check(geometry_issues.is_empty(),
				"%s keeps its broad bloom, hot core and actual wave inside %s, including dragged positions: %s" % [theme, dimensions, geometry_issues])
			check(fading.release_impact > late.release_impact and late.release_impact > 0.0
				and is_zero_approx(samples[4].release_impact) and is_zero_approx(ambient.release_impact)
				and is_zero_approx(ambient.release_flash) and ambient.opened_glow > 0.0,
				"%s has one finite release attack and decay before retaining only its opened light at %s" % [theme, dimensions])
			chest.finish_immediately()
			var opened: Dictionary = chest.hold_effect_snapshot()
			check(is_zero_approx(opened.release_impact) and is_zero_approx(opened.release_flash),
				"%s cannot retain or replay its release impact after completion at %s" % [theme, dimensions])
	chest.free()


func _record_release_geometry(chest, state: Dictionary, issues: Array[String]) -> void:
	var stage := Rect2(Vector2.ZERO, chest.size).grow(0.5)
	var safe_data: Dictionary = state.release_bounds
	var safe := Rect2(Vector2(safe_data.x, safe_data.y), Vector2(safe_data.width, safe_data.height))
	var cavity := Vector2(state.cavity_origin.x, state.cavity_origin.y)
	var origin := Vector2(state.release_burst_origin.x, state.release_burst_origin.y)
	if not origin.is_finite() or not stage.has_point(origin) or origin.distance_to(cavity.clamp(safe.position, safe.end)) > 0.02:
		issues.append("Release source does not follow its fitted cavity: %s / %s" % [origin, cavity])
	for field in ["release_bloom_bounds", "release_core_bounds", "release_wave_bounds"]:
		var geometry: Dictionary = state[field]
		var bounds := Rect2(Vector2(geometry.x, geometry.y), Vector2(geometry.width, geometry.height))
		if not bounds.has_area() or not stage.encloses(bounds):
			issues.append("%s at %.3fs: %s" % [field, state.opening_time, bounds])
		if field != "release_wave_bounds" and not bounds.grow(0.01).has_point(origin):
			issues.append(field + " no longer encloses its cavity source")
	var wave: Dictionary = state.release_wave_bounds
	var wave_bounds := Rect2(Vector2(wave.x, wave.y), Vector2(wave.width, wave.height)).grow(0.01)
	var points: PackedVector2Array = chest._release_wave_points()
	if points.size() < 12:
		issues.append("Release wave has no substantial drawable contour")
	for point in points:
		if not point.is_finite() or not stage.has_point(point) or not wave_bounds.has_point(point):
			issues.append("Release wave point is outside its measured stage bounds: %s" % point)


func _check_opened_bounds(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	for theme in data.THEMES:
		for dimensions in [Vector2(320, 320), Vector2(320, 110), Vector2(320, 72), Vector2(180, 120), Vector2(180, 400), Vector2(640, 190)]:
			chest.clear()
			chest.size = dimensions
			chest.configure_skin(data.theme(theme), data.chests)
			chest.start_open(false)
			chest.finish_immediately()
			var stage := Rect2(Vector2.ZERO, dimensions).grow(0.5)
			var outside: Array[String] = []
			var light_outside: Array[String] = []
			for frame in range(25):
				chest._advance_animation(0.5)
				var state: Dictionary = chest.hold_effect_snapshot()
				var physical: Dictionary = state.physical_bounds
				var bounds := Rect2(Vector2(physical.x, physical.y), Vector2(physical.width, physical.height))
				if not stage.encloses(bounds) or not bounds.has_area():
					outside.append("%.2fs: %s" % [state.opened_idle_time, bounds])
				var beam := Rect2(Vector2(state.opened_beam_bounds.x, state.opened_beam_bounds.y),
					Vector2(state.opened_beam_bounds.width, state.opened_beam_bounds.height))
				var core := Rect2(Vector2(state.cavity_glow_bounds.x, state.cavity_glow_bounds.y),
					Vector2(state.cavity_glow_bounds.width, state.cavity_glow_bounds.height))
				var origin := Vector2(state.cavity_origin.x, state.cavity_origin.y)
				if not stage.encloses(beam) or not stage.encloses(core) or not core.has_area() \
					or not stage.has_point(origin) or not core.grow(0.01).has_point(origin) \
					or beam.size.x < bounds.size.x * 0.75 or beam.size.y < bounds.size.y * 0.25 \
					or absf(beam.end.y - origin.y) > 0.01 or absf(beam.get_center().x - origin.x) > 0.01:
					light_outside.append("%.2fs: beam %s, core %s, cavity %s, chest %s" % [
						state.opened_idle_time, beam, core, origin, bounds])
			check(outside.is_empty(), "The opened %s chest sways without cropping its lid or facets at %s: %s" % [theme, dimensions, outside])
			check(light_outside.is_empty(),
				"The opened %s chest keeps substantial cavity-centered rays and its bright core inside %s: %s" % [theme, dimensions, light_outside])
	chest.free()


func _check_opening_cancel(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(440, 360)
	var openings: Array[String] = []
	var cues: Array = []
	chest.opened.connect(func() -> void: openings.append(chest.theme_id))
	chest.cue_requested.connect(func(theme: String, cue: String, step: int) -> void:
		cues.append([theme, cue, step]))
	for theme in data.THEMES:
		for release_time in [0.8, Feel.UNLOCK_TIME, Feel.RELEASE_TIME - 0.01]:
			chest.clear()
			chest.reduced_motion = false
			chest.configure_skin(data.theme(theme), data.chests)
			var rest: String = chest.hold_effect_snapshot().pose_signature
			chest.begin_hold()
			chest.set_hold_progress(1.0)
			chest.start_open(false)
			chest._advance_animation(release_time)
			chest.cancel_open(true)
			var state: Dictionary = chest.hold_effect_snapshot()
			check(chest.mode == "closed" and not state.active and state.percent == 0
				and is_zero_approx(state.opening_time) and is_zero_approx(state.release_flash)
				and is_zero_approx(state.release_impact) and is_zero_approx(state.opened_glow),
				"%s clears opening progress and light immediately when released at %.2f seconds" % [theme, Feel.HOLD_SECONDS + release_time])
			check(is_equal_approx(state.cancel_remaining, Feel.CANCEL_SECONDS),
				theme + " returns its cancelled opening without blocking a new press")
			var cue_count: int = cues.size()
			chest._advance_animation(Feel.CANCEL_SECONDS + 0.01)
			state = chest.hold_effect_snapshot()
			check(state.pose_signature == rest and is_zero_approx(state.cancel_remaining)
				and is_zero_approx(state.interior_open),
				theme + " returns every lid, latch or crystal facet to the closed pose within 120 milliseconds")
			chest._advance_animation(Feel.OPEN_SECONDS + 1.0)
			chest.finish_immediately()
			check(openings.is_empty() and cues.size() == cue_count and chest.mode == "closed",
				theme + " cannot finish or replay a physical cue after cancellation")
			chest.begin_hold()
			check(chest.hold_effect_snapshot().active and chest.hold_effect_snapshot().percent == 0,
				theme + " allows the earned chest to be held again from zero")
		chest.start_open(false)
		chest._advance_animation(0.8)
		chest.cancel_open(true)
		chest.begin_hold()
		chest.set_hold_progress(0.1)
		var next: Dictionary = chest.hold_effect_snapshot()
		check(chest.mode == "closed" and next.active and next.percent < 10 and is_zero_approx(next.cancel_remaining),
			theme + " immediately replaces rollback with a fresh press")
		chest.start_open(false)
		chest._advance_animation(0.8)
		chest.cancel_open(false)
		check(chest.mode == "closed" and is_zero_approx(chest.hold_effect_snapshot().cancel_remaining),
			theme + " supports immediate cancellation on background or navigation")
		chest.start_open(true)
		var earned: int = openings.size()
		chest.cancel_open(true)
		check(chest.mode == "opened" and openings.size() == earned and chest.hold_effect_snapshot().opened_glow > 0.0,
			theme + " cannot retract an already completed reduced-motion reward")
		openings.clear()
	chest.free()


func _check_release_commitment(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(440, 360)
	var openings: Array[String] = []
	var releases: Array[String] = []
	var cues: Array = []
	chest.opened.connect(func() -> void: openings.append(chest.theme_id))
	chest.release_reached.connect(func() -> void: releases.append(chest.theme_id))
	chest.cue_requested.connect(func(theme: String, cue: String, step: int) -> void:
		cues.append([theme, cue, step]))
	for theme in data.THEMES:
		for elapsed in [Feel.RELEASE_TIME, Feel.RELEASE_TIME + 0.24, Feel.OPEN_SECONDS - 0.01]:
			chest.clear()
			chest.reduced_motion = false
			chest.configure_skin(data.theme(theme), data.chests)
			var before_openings: int = openings.size()
			var before_releases: int = releases.size()
			chest.start_open(false)
			chest._advance_animation(Feel.RELEASE_TIME - 0.001)
			check(not chest.opening_committed() and releases.size() == before_releases,
				theme + " remains cancellable right up to the physical lid release")
			cues.clear()
			chest._advance_animation(elapsed - chest.hold_effect_snapshot().opening_time)
			var committed: Dictionary = chest.hold_effect_snapshot()
			check(chest.opening_committed() and chest.mode == "opening" and releases.size() == before_releases + 1
				and openings.size() == before_openings,
				theme + " commits its opening at the physical release without saving the reward early")
			if elapsed > Feel.RELEASE_TIME + 0.20:
				check(not cues.any(func(item): return item[1] == "release"),
					theme + " commits even when a stalled frame intentionally suppresses its stale release sound")
			chest.cancel_open(true)
			chest.cancel_open(false)
			var released: Dictionary = chest.hold_effect_snapshot()
			check(chest.mode == "opening" and released.opening_time == committed.opening_time
				and released.pose_signature == committed.pose_signature and released.release_flash == committed.release_flash
				and is_zero_approx(released.cancel_remaining),
				theme + " cannot close, rewind or truncate its light after the lid has released")
			chest._advance_animation(Feel.OPEN_SECONDS - released.opening_time - 0.001)
			check(chest.mode == "opening" and openings.size() == before_openings,
				theme + " preserves the complete flash and settling tail before awarding")
			chest._advance_animation(0.002)
			chest.cancel_open(true)
			chest.finish_immediately()
			check(chest.mode == "opened" and openings.size() == before_openings + 1
				and releases.size() == before_releases + 1 and chest.hold_effect_snapshot().opened_glow > 0.0,
				theme + " completes exactly once and keeps its opened glow after release")
	chest.free()


func _check_hold_feedback(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(320, 240)
	chest.configure_skin(data.theme("spring"), data.chests)
	var openings: Array[String] = []
	chest.opened.connect(func() -> void: openings.append(chest.theme_id))
	chest.begin_hold()
	var state: Dictionary = chest.hold_effect_snapshot()
	check(state.active and state.phase == "holding" and state.percent == 0 and state.text.contains("0%"),
		"Holding exposes semantic zero-percent progress before the first game frame")
	chest.set_hold_progress(0.45)
	state = chest.hold_effect_snapshot()
	check(state.active and state.percent == 16 and state.text.contains("16%") and not state.status.is_empty()
		and state.animated and state.spark_count > 0,
		"Confirmation contributes its real elapsed share of the complete progress")
	chest.set_hold_progress(2.0)
	chest._advance_animation(2.0)
	check(chest.hold_effect_snapshot().percent == 35 and chest.mode == "closed" and openings.is_empty(),
		"Completing confirmation never opens the chest or reports the whole buildup complete")
	chest.set_hold_progress(0.0)
	check(not chest.hold_effect_snapshot().active and not chest._charge.visible and not chest._glint.visible
		and is_zero_approx(chest.hold_progress), "Releasing immediately clears the ring, glow and hold state")
	chest._advance_animation(3.0)
	check(not chest.hold_effect_snapshot().active and chest.mode == "closed" and openings.is_empty(),
		"Cancelled charging has no delayed animation or open callback")
	chest.begin_hold()
	check(chest.hold_effect_snapshot().percent == 0, "A new hold starts at zero instead of inheriting the cancelled charge")
	chest.set_hold_progress(0.7)
	chest.stop_reaction()
	check(not chest.hold_effect_snapshot().active and is_zero_approx(chest.hold_progress),
		"Stopping a reaction clears every hold effect immediately")
	chest.set_hold_progress(0.6)
	chest.hide()
	chest.set_hold_progress(0.9)
	check(not chest.hold_effect_snapshot().active and not chest.is_processing() and is_zero_approx(chest.hold_progress),
		"Hidden chests stop charging and reject late progress updates")
	chest.show()
	check(not chest.hold_effect_snapshot().active, "Returning to the chest cannot resurrect an interrupted hold")
	chest.reduced_motion = true
	chest.begin_hold()
	chest.set_hold_progress(0.63)
	var pose: Transform2D = chest._art.transform
	var effect_bounds: Dictionary = chest.hold_effect_snapshot().bounds
	for delta in [0.08, 0.25, 1.5]:
		chest._advance_animation(delta)
		state = chest.hold_effect_snapshot()
		check(state.active and state.percent == 63 and state.text.contains("63%") and not state.animated
			and state.spark_count == 0 and chest._art.transform == pose and state.bounds == effect_bounds,
			"Reduced motion retains semantic progress without bob, shake, moving sparks or shifting effects")
	chest.set_hold_progress(0.0)
	check(not chest.hold_effect_snapshot().active, "Reduced-motion progress also clears immediately on cancel")
	chest.reduced_motion = false
	chest.begin_hold()
	chest.set_hold_progress(1.0)
	chest.start_open(false)
	state = chest.hold_effect_snapshot()
	check(state.active and state.phase == "gathering" and state.percent == 35 and not state.status.is_empty()
		and chest.mode == "opening" and openings.is_empty(),
		"Confirmation flows into automatic gathering without resetting or finishing progress")
	chest.start_open(false)
	chest._advance_animation(1.0)
	state = chest.hold_effect_snapshot()
	check(state.active and state.percent > 50 and state.percent < 70 and state.phase == "building"
		and state.spark_count > 0 and openings.is_empty(),
		"Automatic buildup keeps semantic progress advancing with gathering sparks")
	chest._advance_animation(Feel.RELEASE_TIME - 1.0 + 0.01)
	state = chest.hold_effect_snapshot()
	check(state.active and state.percent == 100 and state.phase == "release" and state.spark_count > 0,
		"Only the final physical release reaches 100 percent and scatters sparks")
	chest._advance_animation(Feel.SETTLE_TIME - Feel.RELEASE_TIME)
	check(not chest.hold_effect_snapshot().active and chest.mode == "opening" and openings.is_empty(),
		"The progress effects finish after release while the reward settles")
	chest._advance_animation(Feel.OPEN_SECONDS - chest.hold_effect_snapshot().opening_time - 0.01)
	check(chest.mode == "opening" and openings.is_empty(), "The complete 3.8-second automatic opening precedes the reward")
	chest._advance_animation(0.02)
	chest.start_open(false)
	chest.finish_immediately()
	check(chest.mode == "opened" and openings.size() == 1 and not chest.hold_effect_snapshot().active,
		"Completion emits exactly once, even after repeated open and finish calls")
	chest.clear()
	chest.configure_skin(data.theme("winter"), data.chests)
	chest.begin_hold()
	chest.set_hold_progress(1.0)
	chest.start_open(false)
	chest.clear()
	chest._advance_animation(Feel.OPEN_SECONDS + 1.0)
	check(chest.mode == "closed" and not chest.hold_effect_snapshot().active and openings.size() == 1,
		"Clearing during release removes the effect and prevents a stale open callback")
	chest.free()


func _check_crown_effects(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(440, 360)
	var duration: float = Feel.HOLD_SECONDS + Feel.RELEASE_TIME
	for theme in data.THEMES:
		chest.clear()
		chest.reduced_motion = false
		chest.configure_skin(data.theme(theme), data.chests)
		chest.begin_hold()
		var early_start: Dictionary = _advance_crown_to(chest, 0.25)
		var early_end: Dictionary = _advance_crown_to(chest, 0.45)
		var before: Dictionary = _advance_crown_to(chest, Feel.HOLD_SECONDS)
		chest.start_open(false)
		var after: Dictionary = chest.hold_effect_snapshot()
		check(is_equal_approx(after.crown_clock, before.crown_clock)
			and is_equal_approx(after.crown_flow_phase, before.crown_flow_phase)
			and after.crown_streaks == before.crown_streaks and after.crown_milestones == before.crown_milestones,
			theme + " preserves crown travelers and milestone effects across the hold-to-opening handoff")
		var late_start: Dictionary = _advance_crown_to(chest, 2.70)
		var late_end: Dictionary = _advance_crown_to(chest, 2.90)
		check(early_end.crown_flow_phase > early_start.crown_flow_phase
			and late_end.crown_flow_phase - late_start.crown_flow_phase >
				(early_end.crown_flow_phase - early_start.crown_flow_phase) * 2.0,
			theme + " visibly accelerates crown energy during equal-duration early and late intervals")
		var valid_streaks: bool = true
		for state in [early_start, early_end, before, after, late_start, late_end]:
			valid_streaks = valid_streaks and not state.crown_streaks.is_empty()
			for streak in state.crown_streaks:
				valid_streaks = valid_streaks and streak.start >= 0.0 and streak.end > streak.start \
					and streak.end <= state.performance_progress + 0.000001
		check(valid_streaks, theme + " clips every traveling streak to earned progress instead of lighting the unfilled rail")
		chest.cancel_open(true)
		var cancelled: Dictionary = chest.hold_effect_snapshot()
		check(not cancelled.active and is_zero_approx(cancelled.crown_clock) and cancelled.crown_streaks.is_empty()
			and cancelled.crown_milestones.all(func(value: float) -> bool: return is_zero_approx(value))
			and is_zero_approx(cancelled.crown_crest),
			theme + " immediately clears crown travelers and bursts when an opening is cancelled")
		chest.reduced_motion = true
		chest.begin_hold()
		chest.set_hold_progress(0.8)
		var reduced: Dictionary = chest.hold_effect_snapshot()
		chest._advance_animation(0.5)
		var static_state: Dictionary = chest.hold_effect_snapshot()
		check(static_state.active and static_state.percent == 80 and static_state.crown_streaks.is_empty()
			and static_state.crown_milestones.all(func(value: float) -> bool: return is_zero_approx(value))
			and is_zero_approx(static_state.crown_crest) and static_state.crown_flow_phase == reduced.crown_flow_phase
			and static_state.crown_effect_bounds == reduced.crown_effect_bounds,
			theme + " keeps a readable static crown without travelers or bursts in reduced motion")

		chest.clear()
		chest.reduced_motion = false
		chest.configure_skin(data.theme(theme), data.chests)
		chest.begin_hold()
		for index in range(3):
			var threshold: float = duration * float(index + 1) / 3.0
			var unearned: Dictionary = _advance_crown_to(chest, threshold - 0.005)
			var burst: Dictionary = _advance_crown_to(chest, threshold + 0.08)
			var settled: Dictionary = _advance_crown_to(chest, threshold + 0.36)
			check(is_zero_approx(unearned.crown_milestones[index]) and burst.crown_milestones[index] > 0.0
				and is_zero_approx(settled.crown_milestones[index]),
				"%s milestone %d celebrates its real threshold once and then settles" % [theme, index + 1])
			if index == 2:
				check(unearned.crown_crest == 0.0 and burst.crown_crest > 0.0 and settled.crown_crest == 0.0
					and burst.release_flash > 0.0 and settled.release_flash > 0.0,
					theme + " briefly crowns completion before yielding to the existing cavity release flash")
	chest.free()


func _advance_crown_to(chest, elapsed: float) -> Dictionary:
	if elapsed <= Feel.HOLD_SECONDS:
		chest.set_hold_progress(elapsed / Feel.HOLD_SECONDS)
	else:
		if chest.mode == "closed":
			chest.set_hold_progress(1.0)
			chest.start_open(false)
		chest._advance_animation(elapsed - Feel.HOLD_SECONDS - chest.hold_effect_snapshot().opening_time)
	return chest.hold_effect_snapshot()


func _check_buildup_glow(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.set_process(false)
	for theme in data.THEMES:
		for dimensions in [Vector2(320, 72), Vector2(180, 400), Vector2(440, 360), Vector2(768, 480)]:
			chest.clear()
			chest.size = dimensions
			chest.reduced_motion = false
			chest.configure_skin(data.theme(theme), data.chests)
			check(is_zero_approx(chest.hold_effect_snapshot().buildup_glow),
				"The idle %s chest has no buildup glow at %s" % [theme, dimensions])
			var previous_intensity: float = 0.0
			var previous_glow: float = 0.0
			chest.begin_hold()
			for elapsed in [0.16, 1.65, 3.22]:
				if elapsed < Feel.HOLD_SECONDS:
					chest.set_hold_progress(elapsed / Feel.HOLD_SECONDS)
				else:
					if chest.mode == "closed":
						chest.set_hold_progress(1.0)
						chest.start_open(false)
					chest._advance_animation(elapsed - Feel.HOLD_SECONDS - chest.hold_effect_snapshot().opening_time)
				var state: Dictionary = chest.hold_effect_snapshot()
				var geometry: Dictionary = state.buildup_bounds
				var halo := Rect2(Vector2(geometry.x, geometry.y), Vector2(geometry.width, geometry.height))
				check(state.buildup_intensity > previous_intensity and state.buildup_glow > previous_glow
					and state.buildup_color == Feel.FLASH_COLORS[theme].to_html(false),
					"The %s actual themed buildup light grows from press to middle to final strain at %s" % [theme, dimensions])
				check(halo.has_area() and Rect2(Vector2.ZERO, dimensions).grow(0.5).encloses(halo)
					and is_zero_approx(state.release_flash) and not chest.opening_committed(),
					"The %s buildup halo has visible safe geometry without prematurely flashing or opening at %s" % [theme, dimensions])
				previous_intensity = state.buildup_intensity
				previous_glow = state.buildup_glow
			check(previous_glow >= 0.6,
				"The %s final buildup has substantial visible light at %s" % [theme, dimensions])
			chest.cancel_open(true)
			check(is_zero_approx(chest.hold_effect_snapshot().buildup_glow)
				and is_zero_approx(chest.hold_effect_snapshot().buildup_intensity),
				"Cancelling %s removes its buildup light immediately while the body returns at %s" % [theme, dimensions])
			chest._advance_animation(0.13)
			chest.reduced_motion = true
			chest.begin_hold()
			chest.set_hold_progress(0.9)
			var static_pose: String = chest.hold_effect_snapshot().pose_signature
			chest._advance_animation(0.4)
			check(is_zero_approx(chest.hold_effect_snapshot().buildup_glow)
				and chest.hold_effect_snapshot().pose_signature == static_pose,
				"Reduced-motion %s retains only readable progress without shaking or growing light at %s" % [theme, dimensions])
			chest.reduced_motion = false
			chest.set_hold_progress(1.0)
			chest.start_open(false)
			chest._advance_animation(Feel.RELEASE_TIME + 0.101)
			check(is_zero_approx(chest.hold_effect_snapshot().buildup_glow)
				and chest.hold_effect_snapshot().release_flash > 0.0,
				"The %s buildup hands its light to the release within 100 milliseconds at %s" % [theme, dimensions])
	chest.free()


func _check_hold_bounds(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	for theme_id in data.THEMES:
		for dimensions in [Vector2(320, 320), Vector2(320, 110), Vector2(320, 72), Vector2(180, 120), Vector2(180, 400), Vector2(640, 190)]:
			chest.clear()
			chest.size = dimensions
			chest.configure_skin(data.theme(theme_id), data.chests)
			chest.reduced_motion = false
			chest.begin_hold()
			chest.set_hold_progress(0.95)
			var stage := Rect2(Vector2.ZERO, dimensions).grow(0.5)
			check(chest._charge_color == data.theme(theme_id).accent,
				"The %s charge ring follows its chest's theme palette" % theme_id)
			for phase in ["hold", "gathering", "building", "anticipation", "release"]:
				if phase == "gathering":
					chest.start_open(false)
				elif phase == "building":
					chest._advance_animation(1.0)
				elif phase == "anticipation":
					chest._advance_animation(Feel.ANTICIPATION_TIME - 1.0 + 0.01)
				elif phase == "release":
					chest._advance_animation(Feel.RELEASE_TIME - Feel.ANTICIPATION_TIME)
				var state: Dictionary = chest.hold_effect_snapshot()
				var bounds := Rect2(Vector2(state.bounds.x, state.bounds.y), Vector2(state.bounds.width, state.bounds.height))
				check(state.active and bounds.has_area() and stage.encloses(bounds),
					"The %s %s halo and sparks stay inside %s" % [theme_id, phase, dimensions])
				var crown: Dictionary = state.crown_effect_bounds
				var crown_bounds := Rect2(Vector2(crown.x, crown.y), Vector2(crown.width, crown.height))
				check(crown_bounds.has_area() and stage.encloses(crown_bounds),
					"The %s %s crown rail, comet and milestone bursts fit inside %s: %s" % [theme_id, phase, dimensions, crown_bounds])
				var outside: Array[String] = []
				for piece in chest._pieces:
					var sprite: Sprite2D = piece.node
					if sprite.modulate.a <= 0.001:
						continue
					var transform: Transform2D = chest.get_global_transform().affine_inverse() * sprite.get_global_transform()
					var rect: Rect2 = sprite.get_rect()
					for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
						if not stage.has_point(transform * corner):
							outside.append(str(piece.role) + " at " + str(transform * corner))
				check(outside.is_empty(), "The %s %s chest artwork remains unclipped in %s: %s" % [theme_id, phase, dimensions, outside])
	chest.free()

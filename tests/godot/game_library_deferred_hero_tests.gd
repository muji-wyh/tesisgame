extends SceneTree

const Library = preload("res://scripts/game_library.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")
const Context = preload("res://scripts/learning_context.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func growth_state(age: int, mastered: int) -> Dictionary:
	return {"ready": true, "completed": false, "age": age, "learning_age": age + 1,
		"mastered": mastered, "total": 80, "progress": float(mastered) / 80.0,
		"lifetime_mastered": 160 + mastered}


func hero_geometry(library: Library) -> Array:
	# Outer Home containers may legitimately resize while hidden. These are the
	# interior rectangles and typography owned by the hero's layout pass.
	return [library._journey.get_rect(), library.pip.get_rect(), library.heading.get_rect(),
		library._journey_heading.position, library._journey_bar.get_rect(), library._next_pip.get_rect(),
		library._pip_caption.get_rect(), library._next_label.get_rect(), library._journey_count.position,
		library.heading.get_theme_font_size("font_size"), library._journey_heading.get_theme_font_size("font_size"),
		library._journey_count.get_theme_font_size("font_size"), library._hero.custom_minimum_size]


func check_frozen(library: Library, panel: StyleBox, geometry: Array, context: String) -> void:
	check(library._journey.get_theme_stylebox("panel") == panel,
		context + ": hidden progress does not allocate another hero panel style")
	check(hero_geometry(library) == geometry,
		context + ": hidden progress preserves the last applied interior geometry and fonts")
	check(library._hero_layout_pending,
		context + ": the latest hero layout remains pending until effective visibility returns")


func check_growth_data(library: Library, state: Dictionary, context: String) -> void:
	var snapshot: Dictionary = library.snapshot()
	check(library._growth == state and snapshot.pip_age == state.age,
		context + ": saved growth and the public Pip age are immediately current")
	check(snapshot.hero.title == "Let's grow together." and snapshot.pip_profile.is_empty(),
		context + ": the latest everyday selection owns the hero and Pip appearance")
	check(snapshot.hero.next_age == state.learning_age and library._next_pip.visible,
		context + ": the next portrait cache key follows the latest growth destination")
	var portrait: AtlasTexture = library._next_pip.texture as AtlasTexture
	check(portrait != null and portrait.atlas.resource_path.ends_with("pip-lv%d.png" % state.learning_age),
		context + ": the destination uses the actual current Pip artwork")
	check(snapshot.hero.count.replace("\n", " ") == "%d / %d mastered" % [state.mastered, state.total]
		and snapshot.hero.goal == "%d more words to grow" % (int(state.total) - int(state.mastered)),
		context + ": explicit snapshots expose the latest mastery count and goal without flushing paint")
	check(is_equal_approx(float(snapshot.hero.progress), float(state.progress))
		and is_equal_approx(float(library._growth_meter.get_shader_parameter("fraction")), float(state.progress)),
		context + ": progress and the shader fraction update before a visible layout")
	check(str(library._journey_bar.get("accessibility_name")).contains("%d / %d mastered" % [state.mastered, state.total])
		and str(library._next_pip.get("accessibility_name")).contains("age %d" % state.learning_age),
		context + ": accessibility reflects the same latest growth state")


func check_professional_data(library: Library, profile: Dictionary, context: String) -> void:
	var snapshot: Dictionary = library.snapshot()
	check(snapshot.professional == profile and snapshot.pip_profile.course_id == profile.course_id
		and snapshot.pip_profile.level == profile.level,
		context + ": the copied profile and career Pip level update immediately")
	check(snapshot.hero.title == "Pip · Lv%d" % profile.level and snapshot.hero.goal == profile.course_title
		and snapshot.hero.next_age == -1 and not library._next_pip.visible,
		context + ": the current career presentation replaces the everyday destination")
	check(snapshot.hero.count == "%d / %d to Lv%d\n%d career words learned" % [profile.level_mastered,
		profile.level_required, int(profile.level) + 1, profile.lifetime_mastered],
		context + ": professional count projection is eager even when its layout is skipped")
	check(is_equal_approx(float(snapshot.hero.progress), float(profile.level_progress))
		and str(library._journey_bar.get("accessibility_name")).contains("%d career words learned" % profile.lifetime_mastered),
		context + ": career progress and accessibility stay current while hidden")


func check_containment(library: Library, context: String) -> void:
	var bounds: Rect2 = library._journey.get_global_rect().grow(1.0)
	for child: Control in [library.pip, library.heading, library._journey_heading,
		library._journey_count, library._journey_bar, library._pip_caption]:
		check(bounds.encloses(child.get_global_rect()), context + ": hero contains " + str(child.name))
	if library._next_pip.visible:
		check(bounds.encloses(library._next_pip.get_global_rect()), context + ": hero contains its current destination")


func check_detached_initialization() -> void:
	var library := Library.new()
	var state: Dictionary = growth_state(6, 12)
	library.configure_growth(state)
	check(not library.is_inside_tree() and library.pip.growth_age == 6 and library._next_age == 7,
		"Detached configuration retains the requested growth age and destination")
	check(library._hero_layout_pending and not library._journey.has_theme_stylebox_override("panel"),
		"A detached zero-width hero leaves layout pending instead of claiming a successful paint")
	library._hero.size = Vector2(1040, 208)
	library.fit(Vector2(1366, 768), 1.0)
	var panel: StyleBox = library._journey.get_theme_stylebox("panel")
	state = growth_state(9, 24)
	library.configure_growth(state)
	check(not library._hero_layout_pending and library._journey.has_theme_stylebox_override("panel")
		and library._journey.get_theme_stylebox("panel") != panel,
		"A detached hero with a valid width preserves immediate initialization layout")
	check(library.pip.growth_age == 9 and library._journey_count.text == "24 / 80 mastered",
		"Detached initialization applies the latest count rather than retaining its first request")
	library.free()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	check_detached_initialization()
	var catalog := Catalog.new()
	check(catalog.load_index(), "Deferred hero checks use the real learning catalog and Pip art")
	var course: Dictionary = catalog.course("retail")
	var career: Dictionary = Context.professional(str(course.id), str(course.modules[0].id),
		str(course.curriculum_revision), "word_jelly")
	var everyday: Dictionary = Context.growth(7, "word_jelly")
	var ancestor := Control.new()
	ancestor.size = Vector2(root.size)
	root.add_child(ancestor)
	var library := Library.new()
	ancestor.add_child(library)
	library.configure("word_jelly", true, true)
	library.configure_learning(catalog, everyday, {"phase": "idle"})
	var state: Dictionary = growth_state(6, 12)
	library.configure_growth(state)
	library.fit(Vector2(root.size), 1.0)
	await settle()
	check(library.is_visible_in_tree() and not library._hero_layout_pending,
		"A visible Home finishes its initial layout normally")
	check_growth_data(library, state, "Visible baseline")
	check_containment(library, "Visible baseline")
	var panel: StyleBox = library._journey.get_theme_stylebox("panel")
	state.mastered = 13
	state.progress = 13.0 / 80.0
	library.configure_growth(state)
	check(not library._hero_layout_pending and library._journey.get_theme_stylebox("panel") != panel,
		"Visible growth refreshes still apply the hero layout synchronously")
	check_growth_data(library, state, "Visible refresh")
	await settle()
	ancestor.hide()
	await settle()
	check(library.visible and not library.is_visible_in_tree() and library.pip._idle_paused,
		"The ancestor hides Home effectively while its own visible flag remains true")
	panel = library._journey.get_theme_stylebox("panel")
	var geometry: Array = hero_geometry(library)
	var portrait: Texture2D = library._next_pip.texture
	for mastered in range(14, 38):
		# Reuse and mutate the same dictionary to catch aliased-state shortcuts.
		state.mastered = mastered
		state.progress = float(mastered) / 80.0
		state.lifetime_mastered = 160 + mastered
		library.configure_growth(state)
		library.configure_professional({})
		check_frozen(library, panel, geometry, "Hidden mastery %d" % mastered)
	check(library._next_pip.texture == portrait,
		"Mastery-only updates retain the actual existing destination texture")
	state.age = 9
	state.learning_age = 10
	library.configure_growth(state)
	check_growth_data(library, state, "Hidden age transition")
	check_frozen(library, panel, geometry, "Hidden age transition")
	library.set_growth_age(8)
	check(library.pip.growth_age == 8 and library._growth.age == 9,
		"The public age setter remains immediate and independent of the configured growth dictionary")
	library.configure_growth(state)
	ancestor.show()
	check(not library._hero_layout_pending and library._journey.get_theme_stylebox("panel") != panel,
		"Showing an already sized ancestor flushes the latest hero layout before the next frame")
	check_growth_data(library, state, "Synchronous Home return")
	check(not library.pip._idle_paused, "The existing visibility callback resumes Home Pip after the flush")
	await settle()
	ancestor.hide()
	panel = library._journey.get_theme_stylebox("panel")
	geometry = hero_geometry(library)
	root.size = Vector2i(390, 844)
	ancestor.size = Vector2(root.size)
	library.fit(Vector2(root.size), 1.0)
	await settle()
	check_frozen(library, panel, geometry, "Hidden responsive resize")
	check(library._available == Vector2(390, 844), "Hidden Home retains the latest requested viewport")
	ancestor.show()
	check(not library._hero_layout_pending and library._journey.get_theme_stylebox("panel") != panel,
		"Returning to a resized Home synchronously flushes its valid hero layout")
	check_growth_data(library, state, "Resized Home return")
	await settle()
	check(library.heading.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and library.heading.get_theme_font_size("font_size") == 24,
		"Normal container sizing applies the latest narrow layout after returning Home")
	check_containment(library, "Resized Home return")
	ancestor.hide()
	panel = library._journey.get_theme_stylebox("panel")
	geometry = hero_geometry(library)
	var word_library := VBoxContainer.new()
	root.add_child(word_library)
	library.learning.reparent(word_library)
	library.learning.set_library_mode(true)
	library.learning.show()
	var profile := {"course_id": course.id, "course_title": course.title, "module_title": course.modules[0].title,
		"ready": true, "level": 3, "lifetime_mastered": 18, "mastered": 18, "total": 500,
		"level_mastered": 3, "level_required": 15, "level_progress": 0.2, "level_completed": false}
	library.configure_learning(catalog, career, {"phase": "media", "session": {"progress_loaded": false}}, career)
	library.configure_professional(profile)
	check_professional_data(library, profile, "Hidden career selection")
	check(library.learning.get_parent() == word_library and library.learning.is_visible_in_tree()
		and library.learning.snapshot().selection == career and library.learning.snapshot().busy,
		"A visible reparented selector still receives current career selection and loading state")
	check(library._continue_round.visible and library._continue_round.disabled
		and library._home_cancel.visible and library._vocabulary_context.disabled,
		"Hidden Home retains eager continuation, cancellation and vocabulary availability state")
	check(library.snapshot().vocabulary.detail.contains(str(course.title))
		and not library.snapshot().controls.any(func(control: Dictionary) -> bool: return control.name == "ChangeCareer"),
		"The current vocabulary is published without treating reparented controls as Home navigation")
	check_frozen(library, panel, geometry, "Hidden career selection")
	for level in range(4, 9):
		profile.level = level
		profile.level_mastered = level
		profile.level_progress = float(level) / 15.0
		profile.lifetime_mastered = 18 + level
		library.configure_professional(profile)
		check_frozen(library, panel, geometry, "Hidden career level %d" % level)
	check_professional_data(library, profile, "Latest hidden career level")
	profile.level = 99
	check(library._professional_profile.level == 8,
		"Hidden career configuration owns its copied profile rather than aliasing the caller")
	library.configure_learning(catalog, Context.growth(10, "word_jelly"), {"phase": "idle"})
	library.configure_professional({})
	check_growth_data(library, state, "Latest hidden everyday selection")
	check(library.learning.is_visible_in_tree() and library.learning.snapshot().selection.track == "growth"
		and not library.learning.snapshot().busy and not library._vocabulary_context.disabled,
		"Returning to everyday words updates the visible external selector and clears loading state")
	check_frozen(library, panel, geometry, "Latest hidden everyday selection")
	ancestor.show()
	check(not library._hero_layout_pending and library._journey.get_theme_stylebox("panel") != panel,
		"Showing Home applies only the latest selection instead of replaying an obsolete career layout")
	check_growth_data(library, state, "Selection return")
	await settle()
	check_containment(library, "Selection return")
	library.configure_learning(catalog, career, {"phase": "idle"})
	profile.level = 8
	library.configure_professional(profile)
	check(not library._hero_layout_pending, "Visible career configuration still lays out immediately")
	check_professional_data(library, profile, "Visible career refresh")
	word_library.queue_free()
	ancestor.queue_free()
	await settle()
	print("Deferred Home hero checks: %d; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)

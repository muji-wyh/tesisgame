extends SceneTree

const Mascot = preload("res://scripts/duck_mascot.gd")
const ProfessionalPip = preload("res://scripts/professional_pip.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/catalog.json"))
	var duck = Mascot.new()
	root.add_child(duck)
	duck.size = Vector2(96, 96)
	duck.set_proactive_allowed(false)
	duck.set_growth_age(6)
	var paths: Array[String] = []
	for course: Dictionary in catalog.courses:
		var profile: Dictionary = ProfessionalPip.profile(str(course.id))
		check(not profile.is_empty() and profile.title == course.title, "Every catalog career has its own authored Pip")
		duck.set_professional_profile({"course_id": course.id, "level": 7})
		check(duck.professional_profile.course_id == course.id and duck.professional_profile.level == 7, "The selected career and its level stay associated")
		check(duck.growth_age == 6, "A career wardrobe cannot spend or overwrite everyday growth")
		var art: Texture2D = duck._outfit_sheet
		check(art.resource_path == "res://" + str(profile.art.regular), "The active career owns the actual production appearance")
		paths.append(art.resource_path)
		var sheets: Array = [art, duck._outfit_idle_sheet, duck._outfit_dance_sheet, duck._expression_sheet, duck._expression_heads]
		var cells: Array[int] = [4, 4, 6, 10, 10]
		for index in range(sheets.size()):
			check(sheets[index] != null and sheets[index].get_height() == 360 and sheets[index].get_width() == 360 * cells[index], "Career sheets preserve every pose, expression and layer")
		var portrait: AtlasTexture = ProfessionalPip.portrait(str(course.id)) as AtlasTexture
		check(portrait != null and portrait.region == Rect2(0, 0, 360, 360), "Library portraits share the exact career artwork")
		duck.set_outfit_theme("space")
		check(duck._outfit_sheet == art, "A world color cannot replace the selected career outfit")
		duck.react_gameplay(true)
		var reaction_time: float = duck._gameplay_left
		duck.set_professional_profile({"course_id": course.id, "level": 8})
		check(duck._gameplay_left == reaction_time and duck._outfit_sheet == art, "A level update preserves the reaction clock and texture")
		for fraction in [0.0, 0.2, 0.5, 0.85, 1.0]:
			var transforms: Array[Transform2D] = duck._growth_transforms(Mascot._celebration_transforms(fraction))
			for part in [2, 3]:
				var joint: Array = profile.motionPivots[part]
				var shoulder := Vector2(joint[0], joint[1])
				check((transforms[part] * shoulder).is_equal_approx(transforms[0] * shoulder), "Career sleeves and wings stay attached throughout celebration")
		duck.settle()
		check(duck.perform_growth_action(), "A career Pip retains an intentional companion gesture")
		duck.set_reduced_motion(true)
		check(duck.reduced_motion, "Career feedback respects reduced motion")
		duck.set_reduced_motion(false)
		duck.settle()
	check(paths.size() == 20 and paths.all(func(value: String) -> bool: return paths.count(value) == 1), "Twenty careers have twenty distinct production wardrobes")
	duck.set_growth_age(9)
	check(duck.professional_profile.course_id == str(catalog.courses[-1].id), "Updating earned everyday growth does not clear the selected career")
	duck.set_professional_profile({})
	check(duck.growth_age == 9 and duck.professional_profile.is_empty() and duck._outfit_sheet.resource_path.ends_with("growth/pip-lv9.png"), "Returning to everyday words restores the latest earned age")
	check(ProfessionalPip.profile("unknown-career").is_empty() and ProfessionalPip.portrait("unknown-career") == null, "Unknown careers cannot borrow another career's portrait")
	duck.free()
	print("Professional Pip: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

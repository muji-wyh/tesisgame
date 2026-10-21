extends SceneTree

const PipProgress = preload("res://scripts/professional_pip_progress.gd")
const Progress = preload("res://scripts/professional_progress.gd")
const Growth = preload("res://scripts/growth_state.gd")
const Catalog = preload("res://scripts/professional_catalog.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _course(id: String = "retail") -> Dictionary:
	return {"id": id, "title": "Retail & Checkout" if id == "retail" else "Nursing", "theme_id": "professional_" + id,
		"modules": [{"id": "module01", "title": "Shared workplace words", "lexeme_ids": ["shared.work.n", id + ".first.n"]},
			{"id": "module02", "title": "Career practice", "lexeme_ids": [id + ".first.n", id + ".second.n"]}]}


func _session(progress: Dictionary = {}) -> Dictionary:
	return {"progress_loaded": true, "blocked": false, "pending_count": 0,
		"progress": Progress.empty_progress() if progress.is_empty() else progress}


func _evidence(earned: bool = true, streak: int = 3) -> Dictionary:
	return {"earned": earned, "streak": streak, "exposures": 3}


func _run() -> void:
	_test_scope_and_saved_mastery()
	_test_unavailable_progress()
	_test_level_curve()
	_test_catalog_metadata()
	print("Professional Pip progress: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_scope_and_saved_mastery() -> void:
	var course: Dictionary = _course()
	var context: Dictionary = {"course_id": "retail", "module_id": "module02"}
	var saved: Dictionary = Progress.empty_progress()
	var fresh: Dictionary = PipProgress.summary(course, _session(saved), context)
	check(fresh.ready and fresh.save_ok and fresh.level == 0 and fresh.label == "Lv0", "A new valid career starts with Pip at Lv0")
	check(fresh.total == 3 and fresh.module_total == 2 and fresh.mastered == 0, "Course and module vocabulary use distinct sense IDs")
	check(fresh.module_title == "Career practice" and fresh.course_title == "Retail & Checkout" and fresh.theme_id == "professional_retail", "Profile carries the selected career identity and module")
	saved.skills = {"shared.work.n": {"recognition": _evidence()},
		"retail.first.n": {"recognition": _evidence(), "listening": _evidence()},
		"retail.second.n": {"spelling": _evidence(false, 0)},
		"nursing.first.n": {"context": _evidence()}, "unrelated.word.n": {"recognition": _evidence()}}
	var before: String = Progress.canonical(saved)
	var profile: Dictionary = PipProgress.summary(course, _session(saved), context)
	check(profile.mastered == 2 and profile.lifetime_mastered == 2 and profile.total_mastered == 2, "Only this career's senses contribute once even with multiple earned skills")
	check(profile.module_mastered == 1 and is_equal_approx(profile.progress, 2.0 / 3.0), "Module mastery remains scoped while career progress covers all modules")
	check(profile.level == 1 and profile.level_mastered == 1 and profile.level_required == 2 and profile.level_remaining == 1, "Career level derives from the established Pip experience curve")
	check(is_equal_approx(profile.level_progress, 0.5) and not profile.completed, "Level meter describes the next level, separately from career completion")
	var nursing: Dictionary = PipProgress.summary(_course("nursing"), _session(saved))
	check(nursing.mastered == 2 and nursing.theme_id == "professional_nursing", "Shared sense mastery carries into another career while career-only words stay separate")
	check(Progress.canonical(saved) == before, "Summaries never mutate saved professional evidence or add an independent counter")
	saved.skills["retail.first.n"].recognition.streak = 0
	saved.skills["retail.first.n"].listening.streak = 0
	check(PipProgress.summary(course, _session(saved)).mastered == 2, "Mistakes cannot revoke an earned career level")
	saved.skills["retail.second.n"].spelling = _evidence(false, 2)
	check(PipProgress.summary(course, _session(saved)).mastered == 2, "Two answers and exposure-only collection do not grant mastery")
	saved.skills["retail.second.n"].spelling = _evidence()
	var complete: Dictionary = PipProgress.summary(course, _session(saved))
	check(complete.completed and complete.mastered == 3 and complete.level == 2, "All vocabulary may be learned without falsely reaching the universal level cap")
	var decoded: Variant = JSON.parse_string(JSON.stringify(saved))
	check(PipProgress.summary(course, _session(decoded)) == complete, "Reloading serialized evidence produces the same career profile")
	var pending: Dictionary = _session(saved)
	pending.pending_count = 1
	var pending_profile: Dictionary = PipProgress.summary(course, pending)
	check(pending_profile.ready and not pending_profile.save_ok and pending_profile.mastered == 3, "Pending answers retain the last durable profile until settlement")


func _test_unavailable_progress() -> void:
	check(not PipProgress.summary(_course(), {}).ready, "A missing session is unavailable rather than a new Lv0 save")
	var unloaded: Dictionary = _session()
	unloaded.progress_loaded = false
	check(not PipProgress.summary(_course(), unloaded).ready, "A not-yet-loaded save is unavailable")
	var blocked: Dictionary = _session()
	blocked.blocked = true
	blocked.error = {"error": "Saved progress needs a retry."}
	var blocked_profile: Dictionary = PipProgress.summary(_course(), blocked)
	check(not blocked_profile.ready and blocked_profile.error == "Saved progress needs a retry.", "Persistence failures remain visible")
	var damaged: Dictionary = _session()
	damaged.progress.skills["retail.first.n"] = {"recognition": {"earned": true, "streak": 9, "exposures": 3}}
	check(not PipProgress.summary(_course(), damaged).ready, "Invalid evidence cannot grant a career level")
	check(not PipProgress.summary({}, _session()).ready, "Missing course metadata is unavailable")
	var invalid: Dictionary = _course()
	invalid.modules[0].lexeme_ids.append("bad sense id")
	check(not PipProgress.summary(invalid, _session()).ready, "Malformed career sense IDs do not produce partial progress")
	var foreign: Dictionary = PipProgress.summary(_course(), _session(), {"course_id": "nursing", "module_id": "module01"})
	check(foreign.ready and foreign.module_id.is_empty() and foreign.module_total == 0, "Another career's context cannot label this career's module")


func _test_level_curve() -> void:
	var ids: Array[String] = []
	var saved: Dictionary = Progress.empty_progress()
	var maximum: int = Growth.level_threshold(Growth.LAST_LEVEL)
	for index in range(maximum):
		ids.append("term-%d" % index)
	var course: Dictionary = {"id": "curve", "title": "Curve", "modules": [{"id": "all", "lexeme_ids": ids}]}
	var previous: int = 0
	for level in range(1, Growth.LAST_LEVEL + 1):
		var count: int = Growth.level_threshold(level)
		for index in range(previous, count):
			saved.skills[ids[index]] = {"recognition": _evidence()}
		var profile: Dictionary = PipProgress.summary(course, _session(saved))
		check(profile.level == level and profile.lifetime_mastered == count, "Every existing experience threshold is preserved at Lv%d" % level)
		check(profile.level_mastered == 0 and profile.level_progress == (1.0 if level == Growth.LAST_LEVEL else 0.0), "Each level starts a fresh progress meter at Lv%d" % level)
		previous = count
	var capped: Dictionary = PipProgress.summary(course, _session(saved))
	check(capped.level_completed and capped.level_remaining == 0 and capped.level_required == 0, "The level cap has no further mastery requirement")


func _test_catalog_metadata() -> void:
	var catalog = Catalog.new()
	check(catalog.load_index(), "Load the lightweight professional course catalog")
	for entry: Dictionary in catalog.courses():
		var course: Dictionary = catalog.course(entry.id)
		var profile: Dictionary = PipProgress.summary(course, _session(), {"course_id": entry.id, "module_id": "module01"})
		check(profile.ready and profile.level == 0 and profile.total == 500, "%s derives its complete scope from metadata alone" % entry.id)
		check(profile.module_total == 50 and profile.theme_id == entry.theme_id, "%s retains its own module and appearance identity" % entry.id)

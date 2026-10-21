extends RefCounted
## A career's Pip level is a view of existing, durable vocabulary mastery.
## The selected course metadata supplies IDs; no media or new save is needed.

const Growth = preload("res://scripts/growth_state.gd")
const Progress = preload("res://scripts/professional_progress.gd")


static func summary(course: Dictionary, session: Dictionary, context: Dictionary = {}) -> Dictionary:
	var words: Dictionary = {}
	var module_words: Dictionary = {}
	var course_id: String = str(course.get("id", ""))
	var title: String = str(course.get("title", "Professional English"))
	var module_id: String = str(context.get("module_id", "")) if context.get("course_id", course_id) == course_id else ""
	var module_title: String = ""
	var metadata_ok: bool = Progress.identity(course_id) and course.get("modules") is Array
	if metadata_ok:
		for module in course.modules:
			if not module is Dictionary or not module.get("lexeme_ids") is Array:
				metadata_ok = false
				break
			var selected: bool = module.get("id") == module_id
			if selected:
				module_title = str(module.get("title", module_id))
			for id in module.lexeme_ids:
				if not Progress.identity(id):
					metadata_ok = false
					break
				words[id] = true
				if selected:
					module_words[id] = true
		metadata_ok = metadata_ok and not words.is_empty()
	var progress: Variant = session.get("progress", {})
	var problem: String = Progress.validate_progress(progress)
	var ready: bool = metadata_ok and session.get("progress_loaded", false) \
		and not session.get("blocked", false) and problem.is_empty()
	var mastered: int = 0
	var module_mastered: int = 0
	if ready:
		for id in words:
			# A shared sense can contribute to several careers, once per career.
			# Earned mastery survives mistakes; exposures and streaks alone do not.
			for evidence: Dictionary in progress.skills.get(id, {}).values():
				if evidence.earned:
					mastered += 1
					if module_words.has(id):
						module_mastered += 1
					break
	var level: int = Growth.level_for_mastered(mastered)
	var max_level: bool = level == Growth.LAST_LEVEL
	var requirement: int = Growth.level_cost(level + 1)
	var level_mastered: int = 0 if max_level else mastered - Growth.level_threshold(level)
	var total: int = words.size() if metadata_ok else 0
	var pending: int = maxi(0, int(session.get("pending_count", 0)))
	var message: String = ""
	if not ready:
		message = "Professional vocabulary is unavailable." if not metadata_ok else "Professional progress is unavailable. Please retry."
		if metadata_ok and session.get("error") is Dictionary:
			message = str(session.error.get("error", message))
	return {"track": "professional", "course_id": course_id, "course_title": title, "title": title,
		"theme_id": str(course.get("theme_id", "")), "module_id": module_id, "module_title": module_title,
		"level": level, "label": "Lv%d" % level,
		"mastered": mastered, "lifetime_mastered": mastered, "total_mastered": mastered,
		"total": total, "total_words": total,
		"progress": float(mastered) / float(total) if total > 0 else 0.0,
		"module_mastered": module_mastered, "module_total": module_words.size() if metadata_ok else 0,
		"level_progress": 1.0 if max_level else float(level_mastered) / float(requirement),
		"level_mastered": level_mastered, "level_required": requirement,
		"level_remaining": maxi(0, requirement - level_mastered), "level_completed": max_level,
		# Vocabulary completion does not replace the existing expression/module receipts.
		"completed": ready and total > 0 and mastered == total,
		"threshold": Growth.MASTERY_STREAK, "ready": ready, "save_ok": ready and pending == 0,
		"pending_count": pending, "error": message}

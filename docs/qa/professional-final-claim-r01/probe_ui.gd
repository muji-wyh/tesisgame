extends "res://scripts/game_ui.gd"
## Observe the real UI methods without replacing their results or behavior.

var preflight_observer: Callable
var round_return_observer: Callable


func _preflight_professional_round(content: Dictionary, seed_value: int) -> String:
	var problem: String = super._preflight_professional_round(content, seed_value)
	if preflight_observer.is_valid():
		preflight_observer.call({"problem": problem, "context": content.context.duplicate(true),
			"selection": professional.pending.get("selection", -1),
			"source": professional.pending.get("source", ""),
			"phase": professional.phase, "rebuilding": _rebuilding,
			"session": professional.session.snapshot()})
	return problem


func new_round(seed_value: int = -1, repeat_lesson: bool = false, adventure_id: String = "", next_mode: String = "", required_word_id: String = "", resume_saved_treasure: bool = true, prepared_content: Dictionary = {}, source_id: String = "") -> bool:
	var result: bool = super.new_round(seed_value, repeat_lesson, adventure_id, next_mode,
		required_word_id, resume_saved_treasure, prepared_content, source_id)
	if not prepared_content.is_empty() and round_return_observer.is_valid():
		round_return_observer.call({"result": result, "source": source_id,
			"context": prepared_content.get("context", {}).duplicate(true),
			"rebuilding": _rebuilding, "phase": professional.phase,
			"message": _message.text, "message_visible": _message.is_visible_in_tree(),
			"grid_visible": grid.is_visible_in_tree()})
	return result

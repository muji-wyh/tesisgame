extends SceneTree
## Vocabulary choice persists as a preference without creating professional evidence.

const Preferences = preload("res://scripts/presentation_preferences.gd")
const Context = preload("res://scripts/learning_context.gd")

var checks: int = 0
var failures: int = 0

class Storage extends RefCounted:
	var text: Variant = null
	var readable: bool = true
	var writable: bool = true

	func presentationState() -> Variant:
		return text if readable else false

	func savePresentationState(value: String) -> bool:
		if not writable:
			return false
		text = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _selection() -> Dictionary:
	return Context.professional("retail", "module01", "professional-v2-foundation02-held-six-r01", "memory")


func _run() -> void:
	_test_browser()
	_test_native()
	print("Vocabulary preferences: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_browser() -> void:
	var storage := Storage.new()
	var preferences := Preferences.new(storage)
	preferences.load_preferences(true)
	check(preferences.vocabulary.is_empty() and preferences.reduced_motion, "A missing browser preference adds no vocabulary or motion override")
	preferences.preferred_theme = "candy"
	preferences.muted = true
	preferences.vocabulary = _selection()
	preferences.vocabulary["earned"] = true
	preferences.vocabulary["progress"] = {"level": 99}
	check(preferences.save_preferences(), "A selected preparing module can be saved without an assessed session")
	var saved: Dictionary = JSON.parse_string(storage.text)
	check(saved.vocabulary == _selection() and saved.muted and saved.preferred_theme == "candy" and not saved.has("reduced_motion"),
		"Browser preferences keep the validated vocabulary identity beside compatible theme and sound fields")
	check(preferences.vocabulary == _selection(), "Saving sanitizes extra fields from the in-memory preference")
	var restored := Preferences.new(storage)
	restored.load_preferences(false)
	check(restored.vocabulary == _selection() and restored.muted and not restored.reduced_motion,
		"The selected professional vocabulary survives reload independently of progress and system motion")
	var same_selection: Dictionary = _selection()
	same_selection["earned"] = true
	storage.text = JSON.stringify({"muted": false, "preferred_theme": "space", "vocabulary": same_selection})
	restored.load_preferences(true)
	check(restored.vocabulary == _selection() and not restored.muted and restored.preferred_theme == "space",
		"Browser loads sanitize optional vocabulary fields while preserving unrelated preferences")
	for invalid: Variant in [null, false, "retail", [], {"track": "professional"},
		{"track": "growth", "course_id": "growth", "module_id": "99", "curriculum_revision": "growth-v1", "mode": "match"}]:
		storage.text = JSON.stringify({"muted": true, "preferred_theme": "ocean", "vocabulary": invalid})
		restored.load_preferences(false)
		check(restored.vocabulary.is_empty() and restored.muted and restored.preferred_theme == "ocean",
			"Malformed optional vocabulary does not discard usable browser sound or theme preferences")
	storage.text = JSON.stringify({"muted": true, "preferred_theme": "ocean"})
	restored.vocabulary = _selection()
	restored.load_preferences(true)
	check(restored.vocabulary.is_empty(), "Loading legacy browser settings clears a previously selected in-memory vocabulary")
	check(restored.save_preferences() and JSON.parse_string(storage.text) == {"muted": true, "preferred_theme": "ocean"},
		"Unselected vocabulary preserves the legacy browser payload shape")
	restored.vocabulary = {"track": "professional"}
	check(restored.save_preferences() and restored.vocabulary.is_empty() and not JSON.parse_string(storage.text).has("vocabulary"),
		"An invalid in-memory choice is never persisted as a partially valid identity")
	restored.vocabulary = Context.growth(7, "word_jelly")
	check(restored.save_preferences(), "Everyday vocabulary is also a valid optional selection")
	var previous: String = storage.text
	storage.writable = false
	restored.vocabulary = _selection()
	check(not restored.save_preferences() and storage.text == previous and restored.vocabulary == _selection(),
		"A failed browser preference write retains its previous durable selection and allows retry")
	storage.readable = false
	restored.load_preferences(false)
	check(restored.vocabulary.is_empty(), "Unreadable browser preferences never leave a stale selected vocabulary")


func _test_native() -> void:
	var directory: String = "user://vocabulary-preferences-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var preferences := Preferences.new()
	preferences.path = directory + "/settings.cfg"
	preferences.preferred_theme = "space"
	preferences.muted = true
	preferences.vocabulary = _selection()
	preferences.vocabulary["mastered"] = 500
	check(preferences.save_preferences(), "Native settings save vocabulary without professional progress storage")
	var restored := Preferences.new()
	restored.path = preferences.path
	restored.load_preferences(true)
	check(restored.vocabulary == _selection() and restored.muted and restored.preferred_theme == "space" and restored.reduced_motion,
		"Native reload restores the selected vocabulary, sound, and theme while honoring system motion")
	var config := ConfigFile.new()
	check(config.load(preferences.path) == OK and config.get_value("presentation", "vocabulary") == _selection(),
		"Native settings contain only the sanitized learning identity")
	config.set_value("presentation", "vocabulary", "invalid")
	check(config.save(preferences.path) == OK, "The native malformed preference fixture is written")
	restored.load_preferences(false)
	check(restored.vocabulary.is_empty() and restored.muted and restored.preferred_theme == "space",
		"Invalid native vocabulary does not discard unrelated settings")
	restored.vocabulary = Context.growth(9, "jelly")
	check(restored.save_preferences(), "Switching back to everyday vocabulary persists natively")
	preferences.load_preferences(false)
	check(preferences.vocabulary == Context.growth(9, "jelly"), "Native vocabulary can change from professional to everyday")
	restored.vocabulary = {}
	check(restored.save_preferences(), "Clearing optional vocabulary saves successfully")
	config = ConfigFile.new()
	check(config.load(preferences.path) == OK and not config.has_section_key("presentation", "vocabulary")
		and config.get_value("presentation", "muted") == true,
		"A cleared native selection removes its optional key and keeps mute compatibility")
	preferences.load_preferences(false)
	check(preferences.vocabulary.is_empty(), "Reloading a legacy-shaped native record clears stale vocabulary")
	restored.path = directory + "/missing/settings.cfg"
	restored.vocabulary = _selection()
	check(not restored.save_preferences() and restored.vocabulary == _selection(),
		"Native persistence failure reports failure without altering the requested selection")
	DirAccess.remove_absolute(preferences.path)
	DirAccess.remove_absolute(directory)

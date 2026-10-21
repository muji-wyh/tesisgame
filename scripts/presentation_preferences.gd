extends RefCounted
## Optional presentation choices, separate from scores and campaign saves.

const KEY := "pipAndWords.presentation.v1"
const Context = preload("res://scripts/learning_context.gd")
var path := "user://presentation.cfg"
var preferred_theme := ""
var muted := false
var reduced_motion := false
var vocabulary: Dictionary = {}
var _host: Object

func _init(host: Object = null) -> void:
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")

func load_preferences(default_reduced: bool) -> void:
	reduced_motion = default_reduced
	vocabulary = {}
	if _host != null:
		var raw: Variant = _host.presentationState()
		var value: Variant = JSON.parse_string(raw) if raw is String else null
		if value is Dictionary:
			preferred_theme = str(value.get("preferred_theme", ""))
			muted = value.get("muted", false) == true
			vocabulary = _validated_vocabulary(value.get("vocabulary", {}))
		return
	if OS.has_feature("web"):
		return
	var config := ConfigFile.new()
	if config.load(path) == OK:
		preferred_theme = str(config.get_value("presentation", "preferred_theme", ""))
		muted = config.get_value("presentation", "muted", false) == true
		vocabulary = _validated_vocabulary(config.get_value("presentation", "vocabulary", {}))

func save_preferences() -> bool:
	vocabulary = _validated_vocabulary(vocabulary)
	if _host != null:
		var values := {"muted": muted, "preferred_theme": preferred_theme}
		if not vocabulary.is_empty():
			values["vocabulary"] = vocabulary
		return _host.savePresentationState(JSON.stringify(values)) == true
	if OS.has_feature("web"):
		return false
	var config := ConfigFile.new()
	config.set_value("presentation", "preferred_theme", preferred_theme)
	config.set_value("presentation", "muted", muted)
	if not vocabulary.is_empty():
		config.set_value("presentation", "vocabulary", vocabulary)
	return config.save(path) == OK


func _validated_vocabulary(value: Variant) -> Dictionary:
	return Context.freeze(value).duplicate(true) if value is Dictionary else {}

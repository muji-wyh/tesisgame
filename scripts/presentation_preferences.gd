extends RefCounted
## Optional presentation choices, separate from scores and campaign saves.

const KEY := "pipAndWords.presentation.v1"
var path := "user://presentation.cfg"
var preferred_theme := ""
var muted := false
var reduced_motion := false
var _host: Object

func _init(host: Object = null) -> void:
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")

func load_preferences(default_reduced: bool) -> void:
	reduced_motion = default_reduced
	if _host != null:
		var raw: Variant = _host.presentationState()
		var value: Variant = JSON.parse_string(raw) if raw is String else null
		if value is Dictionary:
			preferred_theme = str(value.get("preferred_theme", ""))
			muted = value.get("muted", false) == true
		return
	if OS.has_feature("web"):
		return
	var config := ConfigFile.new()
	if config.load(path) == OK:
		preferred_theme = str(config.get_value("presentation", "preferred_theme", ""))
		muted = config.get_value("presentation", "muted", false) == true

func save_preferences() -> bool:
	if _host != null:
		var values := {"muted": muted, "preferred_theme": preferred_theme}
		return _host.savePresentationState(JSON.stringify(values)) == true
	if OS.has_feature("web"):
		return false
	var config := ConfigFile.new()
	config.set_value("presentation", "preferred_theme", preferred_theme)
	config.set_value("presentation", "muted", muted)
	return config.save(path) == OK

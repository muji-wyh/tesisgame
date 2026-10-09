extends RefCounted
## Optional presentation choices, separate from scores and campaign saves.

const KEY := "pipAndWords.presentation.v1"
var path := "user://presentation.cfg"
var preferred_theme := ""
var muted := false
var reduced_motion := false
var has_motion_override := false
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
			has_motion_override = value.get("reduced_motion") is bool
			if has_motion_override:
				reduced_motion = value.reduced_motion
		return
	if OS.has_feature("web"):
		return
	var config := ConfigFile.new()
	if config.load(path) == OK:
		preferred_theme = str(config.get_value("presentation", "preferred_theme", ""))
		muted = config.get_value("presentation", "muted", false) == true
		has_motion_override = config.has_section_key("presentation", "reduced_motion") and config.get_value("presentation", "reduced_motion") is bool
		if has_motion_override:
			reduced_motion = config.get_value("presentation", "reduced_motion")

func save_preferences() -> bool:
	if _host != null:
		var values := {"muted": muted, "preferred_theme": preferred_theme}
		if has_motion_override:
			values["reduced_motion"] = reduced_motion
		return _host.savePresentationState(JSON.stringify(values)) == true
	if OS.has_feature("web"):
		return false
	var config := ConfigFile.new()
	config.set_value("presentation", "preferred_theme", preferred_theme)
	config.set_value("presentation", "muted", muted)
	if has_motion_override:
		config.set_value("presentation", "reduced_motion", reduced_motion)
	return config.save(path) == OK

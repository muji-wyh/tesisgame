extends RefCounted
## Optional presentation choices, separate from scores and campaign saves.

const KEY := "pipAndWords.presentation.v1"
var path := "user://presentation.cfg"
var muted := false
var reduced_motion := false
var has_motion_override := false

func load_preferences(default_reduced: bool) -> void:
	reduced_motion = default_reduced
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("(() => { try { return localStorage.getItem('" + KEY + "'); } catch (_) { return null; } })()")
		var value: Variant = JSON.parse_string(str(raw)) if raw != null else null
		if value is Dictionary:
			muted = value.get("muted", false) == true
			has_motion_override = value.get("reduced_motion") is bool
			if has_motion_override:
				reduced_motion = value.reduced_motion
		return
	var config := ConfigFile.new()
	if config.load(path) == OK:
		muted = config.get_value("presentation", "muted", false) == true
		has_motion_override = config.get_value("presentation", "reduced_motion", null) is bool
		if has_motion_override:
			reduced_motion = config.get_value("presentation", "reduced_motion")

func save_preferences() -> bool:
	if OS.has_feature("web"):
		var values := {"muted": muted}
		if has_motion_override:
			values["reduced_motion"] = reduced_motion
		var json := JSON.stringify(values)
		return JavaScriptBridge.eval("(() => { try { localStorage.setItem('" + KEY + "', " + JSON.stringify(json) + "); return true; } catch (_) { return false; } })()") == true
	var config := ConfigFile.new()
	config.set_value("presentation", "muted", muted)
	if has_motion_override:
		config.set_value("presentation", "reduced_motion", reduced_motion)
	return config.save(path) == OK

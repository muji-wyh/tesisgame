extends RefCounted


static func has_pip_resources(audio: Node) -> bool:
	# Check cached resources as well as players so a short or stopped call cannot
	# escape a gameplay assertion merely because its playback already finished.
	for path: String in audio.cache:
		if _is_pip_path(path):
			return true
	var pending: Array[Node] = [audio]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is AudioStreamPlayer and node.stream != null and _is_pip_path(node.stream.resource_path):
			return true
		pending.append_array(node.get_children())
	return false


static func _is_pip_path(path: String) -> bool:
	return path.begins_with("res://assets/audio/pip/") or path.begins_with("res://assets/audio/pip-growth/") \
		or (path.begins_with("res://assets/audio/voice/") and path.ends_with("-theme.wav"))

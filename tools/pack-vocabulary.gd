extends SceneTree
## Package imported vocabulary without exporting a second copy of game code.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Pass the vocabulary build manifest.")
		quit(1)
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not manifest is Dictionary or manifest.get("schema") != 2 or not manifest.get("packs") is Dictionary:
		printerr("Invalid vocabulary build manifest.")
		quit(1)
		return
	for id: String in manifest.packs:
		var pack: Dictionary = manifest.packs[id]
		var writer := PCKPacker.new()
		if writer.pck_start(str(pack.file)) != OK:
			printerr("Could not create vocabulary pack " + id)
			quit(1)
			return
		for entry: Dictionary in pack.entries:
			if writer.add_file(str(entry.path), str(entry.source)) != OK:
				printerr("Could not pack vocabulary resource: " + str(entry.path))
				quit(1)
				return
		if writer.flush() != OK:
			printerr("Could not finish vocabulary pack " + id)
			quit(1)
			return
		print("Vocabulary %s: %d imported resources packed." % [id, pack.entries.size()])
	quit(0)

extends SceneTree

const Preferences = preload("res://scripts/presentation_preferences.gd")
const Library = preload("res://scripts/game_library.gd")
const Style = preload("res://scripts/ui_style.gd")
var failures := 0
var checks := 0

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

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	_test_host_preferences()
	var directory := "user://presentation-test-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var preferences := Preferences.new()
	preferences.path = directory + "/settings.cfg"
	preferences.load_preferences(true)
	check(preferences.reduced_motion and not preferences.muted, "First visit respects the system motion preference")
	preferences.muted = true
	preferences.reduced_motion = false
	preferences.has_motion_override = true
	check(preferences.save_preferences(), "Presentation choices save independently of game progress")
	var restored := Preferences.new()
	restored.path = preferences.path
	restored.load_preferences(true)
	check(restored.muted and not restored.reduced_motion, "Explicit saved choices override defaults after restart")
	restored.path = directory + "/missing/settings.cfg"
	check(not restored.save_preferences(), "Unwritable preferences report failure without pretending to persist")
	check(Style.HEADING_FONT.variation_opentype.get(2003265652) == 850.0, "Godot receives the numeric OpenType weight axis")
	check(Style.HEADING_FONT.has_char(0x203a), "The game chooser indicator is included in the bundled font")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var library := Library.new()
	root.add_child(library)
	library.configure("memory", true, true)
	for dimensions in [Vector2i(320, 320), Vector2i(320, 568), Vector2i(390, 420), Vector2i(390, 600), Vector2i(390, 640), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = dimensions
		library.fit(Vector2(dimensions) - Vector2(24, 24), 1.0)
		for frame in range(8):
			await process_frame
		library.fit(Vector2(dimensions) - Vector2(24, 24), 1.0)
		for frame in range(8):
			await process_frame
		check(library.size.x <= dimensions.x - 23 and library.size.y <= dimensions.y - 23, "Library fits " + str(dimensions))
		for button in library.buttons + [library.sound_button, library.motion_button, library.close_button]:
			check(library.get_global_rect().grow(1).encloses(button.get_global_rect()) and button.size.y >= 44, "All choices and settings remain reachable at " + str(dimensions))
	library.queue_free()
	DirAccess.remove_absolute(preferences.path)
	DirAccess.remove_absolute(directory)
	await process_frame
	print("Presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_host_preferences() -> void:
	var storage := Storage.new()
	var preferences := Preferences.new(storage)
	preferences.load_preferences(true)
	check(preferences.reduced_motion and not preferences.has_motion_override,
		"Missing browser preferences keep the system motion default")
	preferences.preferred_theme = "candy"
	preferences.muted = true
	check(preferences.save_preferences(), "A verified host write reports successful preference persistence")
	var decoded: Dictionary = JSON.parse_string(storage.text)
	check(decoded.preferred_theme == "candy" and decoded.muted and not decoded.has("reduced_motion"),
		"Browser saves preserve the theme and mute state without inventing a motion override")
	preferences.reduced_motion = false
	preferences.has_motion_override = true
	check(preferences.save_preferences(), "Explicit browser motion preference can be saved")
	var restored := Preferences.new(storage)
	restored.load_preferences(true)
	check(restored.preferred_theme == "candy" and restored.muted and restored.has_motion_override and not restored.reduced_motion,
		"Theme, mute and explicit motion preferences survive a host-backed reload")
	var previous: String = storage.text
	storage.writable = false
	restored.preferred_theme = "space"
	check(not restored.save_preferences() and storage.text == previous,
		"Failed host persistence leaves earlier preferences intact and reports failure")
	storage.writable = true
	check(restored.save_preferences(), "The same in-memory choices can be retried after storage recovers")
	storage.readable = false
	var unavailable := Preferences.new(storage)
	unavailable.load_preferences(true)
	check(unavailable.reduced_motion and not unavailable.has_motion_override and unavailable.preferred_theme.is_empty(),
		"Unreadable browser preferences use presentation defaults without inventing an override")

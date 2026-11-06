extends SceneTree
## Word faces skip the superseded base fit while preserving visible native geometry.

const Style = preload("res://scripts/ui_style.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")
const PICTURE = preload("res://assets/images/ui/modes/cat.webp")
const CHEST = preload("res://assets/chests/shared/ui/chest.png")

class BaseProbe:
	extends "res://scripts/jelly_tile.gd"
	var face_layouts: int = 0

	func _layout_learning_face() -> void:
		face_layouts += 1
		super._layout_learning_face()


class WordProbe:
	extends "res://scripts/word_jelly_tile.gd"
	var base_face_layouts: int = 0

	func _layout_learning_face() -> void:
		base_face_layouts += 1
		super._layout_learning_face()


class ReferenceWord:
	extends "res://scripts/word_jelly_tile.gd"
	var restoring_base_face: bool = false

	func _layout_surface_geometry() -> void:
		super._layout_surface_geometry()
		# Restore the former base face pass before the specialized face replaces it.
		restoring_base_face = true
		_layout_learning_face()
		restoring_base_face = false

	func _layout_picture_geometry() -> void:
		# The former base pass already performs this geometry update exactly once.
		if restoring_base_face:
			super._layout_picture_geometry()


var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _cell(face: String, level: int, fragments: int, spelling: String) -> Dictionary:
	var word := {"id": "fixture:cat", "text": spelling}
	return {"id": 12, "kind": "picture" if face == "picture" else "word", "jelly_kind": face,
		"text": spelling, "display_text": spelling, "word": word if face == "merged" else {},
		"image_word": word if face != "root" else {}, "merge_level": level,
		"mass": 1, "fragments": fragments, "width": 1, "height": 1,
		"approved_break_offsets": [2, 9] if spelling == "unbelievable" else []}


func _visible_state(node: Control) -> Dictionary:
	if node == null or not node.visible:
		return {"visible": false}
	var result: Dictionary = {"visible": true, "rect": node.get_rect(), "scale": node.scale,
		"pivot": node.pivot_offset, "rotation": node.rotation, "modulate": node.modulate,
		"self_modulate": node.self_modulate, "z_index": node.z_index}
	if node is Label:
		result["text"] = node.text
		result["font_size"] = node.get_theme_font_size("font_size")
		result["autowrap"] = node.autowrap_mode
		result["overrun"] = node.text_overrun_behavior
		result["clip_text"] = node.clip_text
	elif node is TextureRect:
		result["texture"] = node.texture
		result["stretch_mode"] = node.stretch_mode
	return result


func _state(tile) -> Dictionary:
	var result: Dictionary = {"body_size": tile.size, "visual": _visible_state(tile._visual),
		"surface": _visible_state(tile._surface), "shadow": _visible_state(tile._shadow),
		"picture": _visible_state(tile._picture), "picture_shadow": _visible_state(tile._picture_shadow),
		"label": _visible_state(tile._label), "level": _visible_state(tile._level_badge),
		"fragment_holder": _visible_state(tile._fragment_holder), "fragment_badges": [],
		"fragment_count": _visible_state(tile._fragment_count), "glow": _visible_state(tile._merged_glow),
		"effect": _visible_state(tile._merged_effect), "glints": [],
		"requires_read": tile.requires_read, "tooltip": tile.tooltip_text,
		"accessibility": tile.get("accessibility_name"), "contact_outline": tile.contact_outline(), "uniforms": {}}
	for badge: TextureRect in tile._fragment_badges:
		result.fragment_badges.append(_visible_state(badge))
	for glint: TextureRect in tile._merged_glints:
		result.glints.append(_visible_state(glint))
	for parameter: StringName in [&"surface_size", &"rim_uv", &"rim_color", &"rim_strength", &"rim_width",
		&"bend", &"beat", &"preview_pressure", &"preview_sway", &"preview_pull", &"completion_strength", &"completion_glint"]:
		result.uniforms[parameter] = tile._gel.get_shader_parameter(parameter)
	return result


func _differences(actual: Dictionary, expected: Dictionary, prefix: String = "") -> Array[String]:
	var result: Array[String] = []
	for key: Variant in expected:
		var field: String = prefix + str(key)
		if not actual.has(key):
			result.append(field + ": missing")
		elif actual[key] is Dictionary and expected[key] is Dictionary:
			result.append_array(_differences(actual[key], expected[key], field + "."))
		elif actual[key] != expected[key]:
			result.append("%s: %s != %s" % [field, str(actual[key]), str(expected[key])])
	return result


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	var basic := BaseProbe.new()
	var tile := WordProbe.new()
	var reference := ReferenceWord.new()
	for subject in [basic, tile, reference]:
		root.add_child(subject)
	for subject in [tile, reference]:
		subject.set_ambient_animation(false)
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(3840, 2160), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		await process_frame
		var scale: float = Style.ui_scale(tile)
		for display_size: Vector2 in [Vector2(44, 44), Vector2(88, 88), Vector2(176, 88), Vector2(88, 176)]:
			for subject in [basic, tile, reference]:
				subject.size = display_size / scale
			for face: Dictionary in [{"kind": "root", "level": 0, "fragments": 0, "text": "unbelievable"},
				{"kind": "picture", "level": 0, "fragments": 8, "text": "cat"},
				{"kind": "merged", "level": 1, "fragments": 0, "text": "cat"},
				{"kind": "merged", "level": 9, "fragments": 8, "text": "unbelievable"}]:
				var cell: Dictionary = _cell(face.kind, face.level, face.fragments, face.text)
				var basic_cell: Dictionary = cell.duplicate()
				basic_cell.word = {"id": "fixture:cat", "text": str(face.text)}
				basic.configure(basic_cell, SKIN, PICTURE, CHEST, Style.GOOD)
				for subject in [tile, reference]:
					subject.configure(cell, SKIN, PICTURE, CHEST, Style.GOOD)
				for projected: bool in [false, true, false]:
					for reduced: bool in [false, true]:
						for subject in [tile, reference]:
							subject.set_projection(projected)
							subject.set_merged_presentation(1.25, reduced)
							subject.deform(0.0, 0.0, Vector2(0.96, 1.08))
							subject.set_preview_pressure(0.03, 0.002, 0.04, false)
							subject.set_support(12.0 / scale, 0.4, not projected)
						await process_frame
						var actual: Dictionary = _state(tile)
						var expected: Dictionary = _state(reference)
						if actual != expected and failures < 8:
							printerr("LAYOUT DIFF: " + "; ".join(_differences(actual, expected)))
						check(actual == expected,
							"Skipping the base face fit preserves %s level %d at %s/%s with projection %s, reduced %s"
							% [face.kind, face.level, dimensions, display_size, projected, reduced])
						check(tile.base_face_layouts == 0, "Word faces never shape the superseded base caption")
	check(basic.face_layouts > 0, "Ordinary Jelly tiles retain their original learning-face fitting")
	for subject in [basic, tile, reference]:
		subject.free()
	print("Word Jelly layout parity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

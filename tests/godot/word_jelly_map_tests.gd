extends SceneTree
## Standalone real-view contracts; missing implementation is an ordinary red test.

const MAP_PATH: String = "res://scripts/word_jelly_map.gd"
const SCROLL_PATH: String = "res://scripts/result_scroll.gd"
const CAPTURE_DIRECTORY: String = "res://build/qa/jelly-campaign-map"
const CHAPTERS: Array[String] = ["Meadow", "Grove", "Pine Trail", "Cottage Creek",
	"Amber Orchard", "Snowfields", "Frost Pines", "Palm Lagoon", "Cactus Valley",
	"High Peaks", "Castle Gardens"]
const CHAPTER_ART: Array[String] = [
	"res://assets/images/jelly-match/garden/hills.png",
	"res://assets/images/jelly-match/garden/tree.png",
	"res://assets/images/jelly-campaign/tree-pine.png",
	"res://assets/images/jelly-campaign/cottage.png",
	"res://assets/images/jelly-campaign/tree-orange.png",
	"res://assets/images/jelly-campaign/tree-snow.png",
	"res://assets/images/jelly-campaign/tree-pine-snow.png",
	"res://assets/images/jelly-campaign/tree-palm.png",
	"res://assets/images/jelly-campaign/cactus.png",
	"res://assets/images/jelly-campaign/mountains.png",
	"res://assets/images/jelly-campaign/castle.png"]
const STAR_SOURCE: String = "res://assets/images/ui/jelly-goals/star.webp"
const SIZES: Array[Vector2i] = [Vector2i(1366, 768), Vector2i(393, 852),
	Vector2i(320, 480), Vector2i(844, 390)]

var checks: int = 0
var failures: int = 0
var _stage_events: Array[int] = []
var _action_events: Array[String] = []
var _holder: Control


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _settle(frames: int = 3) -> void:
	for frame in range(frames):
		await process_frame


func _finish() -> void:
	print("Word Jelly map: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _state(highest: int = 12) -> Dictionary:
	var stars: Dictionary = {}
	for number in range(1, highest + 1):
		stars[str(number)] = 1 + (number - 1) % 3
	return {"highest_cleared": highest, "best_stars": stars,
		"frontier": mini(99, highest + 1), "coins": 3170, "error": "",
		"loading": false, "pending_stage": 0}


func _snapshot(view: Control) -> Dictionary:
	var result: Variant = view.call("snapshot")
	check(result is Dictionary, "The real map publishes a dictionary snapshot")
	return result if result is Dictionary else {}


func _rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	if value is Dictionary and value.has_all(["x", "y", "width", "height"]):
		return Rect2(float(value.x), float(value.y), float(value.width), float(value.height))
	return Rect2()


func _stage(snapshot: Dictionary, number: int) -> Dictionary:
	for item: Dictionary in snapshot.get("stage_nodes", []):
		if int(item.get("number", 0)) == number:
			return item
	return {}


func _buttons(view: Node) -> Array[BaseButton]:
	var result: Array[BaseButton] = []
	for child: Node in view.find_children("*", "BaseButton", true, false):
		result.append(child as BaseButton)
	return result


func _control_at_rect(view: Control, rect: Rect2) -> BaseButton:
	if not rect.has_area():
		return null
	for button: BaseButton in _buttons(view):
		if button.get_global_rect().is_equal_approx(rect):
			return button
	return null


func _stage_button(view: Control, number: int, snapshot: Dictionary = {}) -> BaseButton:
	var current: Dictionary = _snapshot(view) if snapshot.is_empty() else snapshot
	return _control_at_rect(view, _rect(_stage(current, number).get("rect")))


func _action_button(view: Control, key: String) -> BaseButton:
	return _control_at_rect(view, _rect(_snapshot(view).get(key, {}).get("rect")))


func _inherits_script(script: Script, path: String) -> bool:
	while script != null:
		if script.resource_path == path:
			return true
		script = script.get_base_script()
	return false


func _scroll(view: Control) -> ScrollContainer:
	for child: Node in view.find_children("*", "ScrollContainer", true, false):
		var scroll: ScrollContainer = child as ScrollContainer
		if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
			and _inherits_script(scroll.get_script(), SCROLL_PATH):
			return scroll
	return null


func _navigation(view: Control) -> Array[Control]:
	var result: Array[Control] = []
	var supplied: Variant = view.call("navigation_controls")
	check(supplied is Array, "Navigation returns the real native controls")
	if not supplied is Array:
		return result
	for value: Variant in supplied:
		check(value is Control, "Every navigation entry is a Control")
		if not value is Control:
			continue
		var control: Control = value
		check(not result.has(control), "Navigation never repeats a control")
		check(control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL,
			"Navigation contains only visible keyboard/controller focus targets")
		if control is BaseButton:
			check(not (control as BaseButton).disabled, "Disabled stages never enter the navigation list")
		result.append(control)
	return result


func _normal(text: String) -> String:
	return text.to_lower().replace(" ", "").replace(",", "").replace(":", "").replace("\n", "")


func _text_controls(view: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in view.find_children("*", "Control", true, false):
		var control: Control = child as Control
		if (control is Label or control is Button) and control.is_visible_in_tree():
			result.append(control)
	return result


func _text(control: Control) -> String:
	if control is Label:
		return (control as Label).text
	if control is Button:
		return (control as Button).text
	return ""


func _visible_copy(view: Node) -> String:
	var result: String = ""
	for control: Control in _text_controls(view):
		result += _text(control) + "\n"
	return result


func _pixel_scale() -> float:
	return float(root.size.x) / maxf(1.0, root.get_visible_rect().size.x)


func _source(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture.has_meta("word_art_source"):
		return str(texture.get_meta("word_art_source"))
	if not texture.resource_path.is_empty():
		return texture.resource_path
	if texture is AtlasTexture:
		return _source((texture as AtlasTexture).atlas)
	return ""


func _art(view: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var controls: Array[Node] = view.find_children("*", "Control", true, false)
	if view is Control:
		controls.append(view)
	for child: Node in controls:
		if child is TextureRect:
			var image: TextureRect = child as TextureRect
			if image.texture != null:
				result.append({"node": image, "texture": image.texture})
		elif child is Button:
			var button: Button = child as Button
			if button.icon != null:
				result.append({"node": button, "texture": button.icon})
			var surface: StyleBox = button.get_theme_stylebox("normal")
			if surface is StyleBoxTexture:
				result.append({"node": button, "texture": (surface as StyleBoxTexture).texture})
		elif child is Panel:
			var surface: StyleBox = (child as Panel).get_theme_stylebox("panel")
			if surface is StyleBoxTexture:
				result.append({"node": child, "texture": (surface as StyleBoxTexture).texture})
	return result


func _star_tint(star: CanvasItem, button: BaseButton) -> Color:
	var tint: Color = star.self_modulate
	var ancestor: Node = star
	while ancestor is CanvasItem:
		tint *= (ancestor as CanvasItem).modulate
		if ancestor == button:
			break
		ancestor = ancestor.get_parent()
	return tint


func _poses(view: Control) -> Array:
	var result: Array = []
	for entry: Dictionary in _art(view):
		var item: CanvasItem = entry.node
		var pose: Array = [item.get_instance_id(), item.get_global_transform_with_canvas(),
			item.modulate, item.self_modulate]
		if item.material is ShaderMaterial:
			var material: ShaderMaterial = item.material
			if material.shader != null:
				for uniform: Dictionary in material.shader.get_shader_uniform_list():
					var value: Variant = material.get_shader_parameter(str(uniform.name))
					if not value is Resource:
						pose.append([uniform.name, value])
		result.append(pose)
	return result


func _processing(view: Control) -> Array[String]:
	var result: Array[String] = []
	if view.is_processing():
		result.append(str(view.name))
	for child: Node in view.find_children("*", "Node", true, false):
		if child.is_processing():
			result.append(str(child.get_path()))
	return result


func _geometry(view: Control) -> Array:
	var result: Array = []
	for button: BaseButton in _buttons(view):
		result.append([button.get_instance_id(), button.get_global_rect()])
	return result


func _resize(dimensions: Vector2i, scaled: bool = false) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if scaled \
		else Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480) if scaled else Vector2i.ZERO
	root.size = dimensions
	await _settle()


func _click(button: BaseButton) -> void:
	check(button != null and button.is_visible_in_tree() and not button.disabled,
		"The pointer activation uses a visible enabled native button")
	if button == null:
		return
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _accept(button: BaseButton, controller: bool = false) -> void:
	check(button != null and not button.disabled, "Keyboard/controller activation has a playable control")
	if button == null:
		return
	button.grab_focus()
	await _settle()
	for pressed: bool in [true, false]:
		if controller:
			var event := InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_A
			event.pressed = pressed
			root.push_input(event, true)
		else:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			root.push_input(event, true)
		await process_frame


func _touch(point: Vector2, pressed: bool, index: int = 7) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _touch_move(point: Vector2, index: int = 7) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = Vector2(0, -80)
	root.push_input(event, true)
	await process_frame


func _reveal(scroll: ScrollContainer, button: BaseButton) -> void:
	check(button != null, "The requested real stage button exists")
	if button != null:
		scroll.ensure_control_visible(button)
		await _settle()


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	check(DirAccess.make_dir_recursive_absolute(CAPTURE_DIRECTORY) == OK,
		"Runtime captures use the ignored project QA directory")
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(), "Capture reads an actual rendered viewport")
	if image != null and not image.is_empty():
		check(image.save_png(CAPTURE_DIRECTORY + "/" + name + ".png") == OK,
			"Save actual campaign pixels: " + name)


func _check_api(view: Control) -> bool:
	var valid: bool = true
	for method: String in ["configure", "open", "close", "navigation_controls", "focus_frontier", "snapshot"]:
		var exists: bool = view.has_method(method)
		check(exists, "Map public method exists: " + method)
		valid = valid and exists
	for signal_name: String in ["stage_selected", "challenge_selected", "home_requested", "retry_requested"]:
		var exists: bool = view.has_signal(signal_name)
		check(exists, "Map signal exists: " + signal_name)
		valid = valid and exists
	for description: Dictionary in view.get_signal_list():
		var signal_name: String = str(description.name)
		if signal_name not in ["stage_selected", "challenge_selected", "home_requested", "retry_requested"]:
			continue
		var expected: int = 1 if signal_name == "stage_selected" else 0
		var signature_valid: bool = description.args.size() == expected
		if signal_name == "stage_selected" and signature_valid:
			signature_valid = int(description.args[0].type) == TYPE_INT
		check(signature_valid, signal_name + " has its required public signal signature")
		valid = valid and signature_valid
	return valid


func _check_assets() -> void:
	var paths: Array[String] = CHAPTER_ART.duplicate()
	paths.append(STAR_SOURCE)
	paths.append("res://assets/images/jelly-match/sky/day.png")
	for color: String in ["coral", "mint", "sky", "lilac"]:
		paths.append("res://assets/images/jelly-match/gel-" + color + ".png")
	for path: String in paths:
		var exists: bool = ResourceLoader.exists(path)
		check(exists, "Acquired production artwork exists: " + path)
		if exists:
			var texture: Texture2D = load(path) as Texture2D
			check(texture != null and texture.get_width() > 0 and texture.get_height() > 0,
				"Acquired artwork loads without a generated replacement: " + path)


func _check_schema(view: Control) -> void:
	var snapshot: Dictionary = _snapshot(view)
	check(snapshot.has_all(["visible", "map_rect", "scroll_rect", "scroll_offset",
		"stage_nodes", "challenge", "home", "retry", "loading", "error"]),
		"The snapshot exposes map bounds, scrolling, stages, actions and honest status")
	check(_rect(snapshot.get("map_rect")).is_equal_approx(view.get_global_rect()),
		"Published map bounds match the real component")
	var stages: Array = snapshot.get("stage_nodes", [])
	check(stages.size() == 99, "The map exposes all 99 stages, not just the current viewport")
	var seen: Dictionary = {}
	var chapters: Dictionary = {}
	for item: Dictionary in stages:
		check(item.has_all(["number", "chapter", "unlocked", "best_stars", "rect", "visible"]),
			"Every stage publishes its identity, rating, lock state and current hit bounds")
		var number: int = int(item.get("number", 0))
		check(number >= 1 and number <= 99 and not seen.has(number),
			"Stage identities are unique and remain within stage 1 through 99")
		seen[number] = true
		var chapter: int = ceili(float(number) / 9.0)
		check(int(item.get("chapter", 0)) == chapter, "Nine consecutive stages belong to their authored chapter")
		chapters[chapter] = int(chapters.get(chapter, 0)) + 1
	check(chapters.size() == 11, "The route has exactly eleven themed chapters")
	for count: int in chapters.values():
		check(count == 9, "Every chapter contains exactly nine stage nodes")
	var scroll: ScrollContainer = _scroll(view)
	check(scroll != null, "The vertical route reuses the production ResultScroll gesture helper")
	if scroll != null:
		check(_rect(snapshot.get("scroll_rect")).is_equal_approx(scroll.get_global_rect())
			and int(snapshot.get("scroll_offset", -1)) == scroll.scroll_vertical,
			"Published scroll bounds and offset describe the live viewport")
		check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
			"The route never depends on horizontal scrolling")


func _check_semantics(view: Control, source: Dictionary) -> void:
	var snapshot: Dictionary = _snapshot(view)
	var blocked: bool = bool(source.loading) or not str(source.error).is_empty()
	var highest: int = int(source.highest_cleared)
	var frontier: int = mini(99, highest + 1)
	var navigation: Array[Control] = _navigation(view)
	for number in range(1, 100):
		var item: Dictionary = _stage(snapshot, number)
		var playable: bool = number <= highest or (highest < 99 and number == frontier)
		var stars: int = int(source.best_stars.get(str(number), 0))
		check(bool(item.get("unlocked", false)) == playable,
			"Stage %d is replayable/frontier only when earned progress permits it" % number)
		check(int(item.get("best_stars", -1)) == stars,
			"Stage %d preserves its exact best earned rating" % number)
		var button: BaseButton = _stage_button(view, number, snapshot)
		check(button != null, "Stage %d has a real native interaction control" % number)
		if button == null:
			continue
		check(button.disabled == (not playable or blocked),
			"Stage %d native disabled state matches lock/loading/error state" % number)
		check(navigation.has(button) == (playable and not blocked),
			"Stage %d keyboard navigation matches its playable state" % number)
		var name: String = _normal(str(button.get("accessibility_name")))
		var action: String = "replay" if number <= highest else ("next" if playable else "locked")
		check(name.contains("stage" + str(number)) and name.contains("%dof3stars" % stars)
			and name.contains(action),
			"Stage %d has its number, best stars and Replay/Next/Locked in its accessible name" % number)
	for key: String in ["challenge", "home", "retry"]:
		var info: Dictionary = snapshot.get(key, {})
		check(info.has_all(["visible", "enabled", "rect"]), key + " publishes its real native control state")
	var challenge: BaseButton = _action_button(view, "challenge")
	var home: BaseButton = _action_button(view, "home")
	check(challenge != null and home != null, "Challenge and library/back are separate real actions")
	if challenge != null:
		check(challenge.disabled == blocked and navigation.has(challenge) == (not blocked),
			"The untimed challenge is available independently of stage unlocks, except while blocked")
		check(_normal(str(challenge.get("accessibility_name"))).contains("challenge"),
			"Assistive technology identifies the independent challenge entrance")
	if home != null:
		check(not home.disabled and navigation.has(home), "Library/back remains available while loading or in error")
		var name: String = _normal(str(home.get("accessibility_name")))
		check(name.contains("library") or name.contains("home") or name.contains("back"),
			"Assistive technology identifies the return-to-library action")
	check(bool(snapshot.get("loading", false)) == bool(source.loading)
		and str(snapshot.get("error", "")) == str(source.error),
		"Loading and error snapshots never substitute a success state")


func _check_number(button: BaseButton, number: int, context: String) -> void:
	var label: Control = null
	if button is Button and _normal((button as Button).text) in [str(number), "stage" + str(number)]:
		label = button
	else:
		for child: Node in button.find_children("*", "Label", true, false):
			var candidate: Label = child as Label
			if candidate.is_visible_in_tree() and _normal(candidate.text) in [str(number), "stage" + str(number)]:
				label = candidate
				break
	check(label != null, context + ": the stage number is visible text, not only a tooltip")
	if label == null:
		return
	var pixels: float = label.get_theme_font_size("font_size") * _pixel_scale()
	check(pixels >= 16.0, context + ": stage numbers remain at least 16 displayed pixels")
	check(button.get_global_rect().grow(0.2).encloses(label.get_global_rect()),
		context + ": the number's layout stays within its own interaction rectangle")
	if label is Label:
		var number_label: Label = label as Label
		check(number_label.get_visible_line_count() >= number_label.get_line_count(),
			context + ": the stage number is not vertically clipped")


func _check_stars(view: Control, source: Dictionary, context: String) -> void:
	var snapshot: Dictionary = _snapshot(view)
	for number in range(1, int(source.highest_cleared) + 1):
		var button: BaseButton = _stage_button(view, number, snapshot)
		if button == null:
			continue
		var slots: Array[Dictionary] = []
		for entry: Dictionary in _art(button):
			if _source(entry.texture) == STAR_SOURCE and entry.node.is_visible_in_tree():
				slots.append(entry)
		check(slots.size() == 3,
			context + ": cleared stage %d prominently keeps three actual sourced star slots" % number)
		var filled: int = 0
		var rects: Array[Rect2] = []
		for entry: Dictionary in slots:
			var star: Control = entry.node
			var rect: Rect2 = star.get_global_rect()
			check(rect.size.x * _pixel_scale() >= 18.0 and rect.size.y * _pixel_scale() >= 18.0,
				context + ": rating artwork remains clearly readable at phone size")
			check(button.get_global_rect().grow(0.2).encloses(rect),
				context + ": rating slots are part of the visible stage face, not clipped beneath it")
			var tint: Color = _star_tint(star, button)
			if tint.a >= 0.8 and tint.get_luminance() >= 0.78:
				filled += 1
			else:
				check(tint.a <= 0.7 or tint.get_luminance() <= 0.65,
					context + ": unearned slots are clearly muted instead of looking earned")
			for previous: Rect2 in rects:
				check(not rect.intersects(previous), context + ": the three stars have separate readable slots")
			rects.append(rect)
		check(filled == int(source.best_stars.get(str(number), 0)),
			context + ": the actual bright/muted star count equals the preserved best rating for stage %d" % number)


func _check_scenery(view: Control) -> void:
	var snapshot: Dictionary = _snapshot(view)
	var artwork: Array[Dictionary] = _art(view)
	var copy: String = _visible_copy(view)
	var found_sky: bool = false
	var found_badge: bool = false
	for entry: Dictionary in artwork:
		found_sky = found_sky or _source(entry.texture) == "res://assets/images/jelly-match/sky/day.png"
		found_badge = found_badge or _source(entry.texture).begins_with("res://assets/images/ui/jelly-map/stage-")
	check(found_sky and found_badge, "The route uses the acquired scenic sky and inspected adventure medallions")
	check(is_equal_approx(float(view.get("_sky").modulate.a), 1.0),
		"The scenic map is opaque so a finished board and its header cannot ghost through")
	for index in range(CHAPTERS.size()):
		check(copy.contains(CHAPTERS[index]), "The authored chapter heading is present: " + CHAPTERS[index])
		var first: Rect2 = _rect(_stage(snapshot, index * 9 + 1).get("rect"))
		var last: Rect2 = _rect(_stage(snapshot, index * 9 + 9).get("rect"))
		var minimum_y: float = minf(first.position.y, last.position.y) - 180.0 / _pixel_scale()
		var maximum_y: float = maxf(first.end.y, last.end.y) + 180.0 / _pixel_scale()
		var found: bool = false
		for entry: Dictionary in artwork:
			var node: Control = entry.node
			var center: Vector2 = node.get_global_rect().get_center()
			if _source(entry.texture) == CHAPTER_ART[index] and node.is_visible_in_tree() \
				and node.size.x > 4.0 and node.size.y > 4.0 \
				and center.y >= minimum_y and center.y <= maximum_y:
				found = true
		check(found, CHAPTERS[index] + " actually presents its distinct acquired landscape/prop")
		var centers: Array[float] = []
		var reversals: int = 0
		var previous_delta: float = 0.0
		for number in range(index * 9 + 1, index * 9 + 10):
			var current: Rect2 = _rect(_stage(snapshot, number).get("rect"))
			centers.append(current.get_center().x)
			if number > index * 9 + 1:
				var previous: Rect2 = _rect(_stage(snapshot, number - 1).get("rect"))
				check(current.get_center().y < previous.get_center().y,
					"Stage numbers climb upwards along the storybook route")
				var delta: float = current.get_center().x - previous.get_center().x
				if delta * previous_delta < 0.0:
					reversals += 1
				if absf(delta) > 0.01:
					previous_delta = delta
		check((centers.max() - centers.min()) * _pixel_scale() >= 40.0 and reversals >= 1,
			CHAPTERS[index] + " has a genuinely winding route")
	var challenge: BaseButton = _action_button(view, "challenge")
	if challenge != null:
		check(_normal(str(challenge.get("accessibility_name"))).contains("notimer")
			and challenge.tooltip_text == "Endless Challenge",
			"The compact challenge icon retains its explicit accessible no-timer description and tooltip")
		check(not _art(challenge).is_empty(), "The challenge entrance also uses sourced icon/gel artwork")


func _check_layout(view: Control, context: String) -> void:
	var snapshot: Dictionary = _snapshot(view)
	var bounds: Rect2 = view.get_global_rect()
	var scroll: ScrollContainer = _scroll(view)
	if scroll == null:
		return
	var viewport: Rect2 = scroll.get_global_rect()
	check(root.get_visible_rect().grow(0.2).encloses(bounds) and bounds.grow(0.2).encloses(viewport),
		context + ": the actual map and scroll viewport fit the parent with no horizontal overflow")
	check(scroll.scroll_horizontal == 0 and not scroll.get_h_scroll_bar().visible,
		context + ": no stage is hidden behind a horizontal scrolling requirement")
	for child: Node in scroll.get_children():
		if child is Control and not child is ScrollBar:
			var content: Control = child as Control
			check(is_zero_approx(content.custom_minimum_size.x),
				context + ": vertical content clears its cross-axis minimum after earlier wide layouts")
			check(content.get_combined_minimum_size().x <= viewport.size.x + 0.2
				and content.size.x <= viewport.size.x + 0.2,
				context + ": the real content width, not just its published bounds, fits the viewport")
	var rects: Array[Rect2] = []
	for item: Dictionary in snapshot.get("stage_nodes", []):
		var number: int = int(item.number)
		var rect: Rect2 = _rect(item.rect)
		var button: BaseButton = _stage_button(view, number, snapshot)
		if button == null:
			continue
		check(rect.is_equal_approx(button.get_global_rect()), context + ": stage hit bounds track actual children")
		check(rect.size.x * _pixel_scale() >= 56.0 and rect.size.y * _pixel_scale() >= 56.0,
			context + ": every stage keeps a 56+ displayed-pixel interaction target")
		check(rect.position.x >= viewport.position.x - 0.2 and rect.end.x <= viewport.end.x + 0.2,
			context + ": stage %d remains inside the narrow horizontal gutters" % number)
		_check_number(button, number, context)
		var separate: bool = true
		for previous: Rect2 in rects:
			separate = separate and not rect.grow(3.0 / _pixel_scale()).intersects(previous)
		check(separate, context + ": nearby stage interaction targets stay separate")
		rects.append(rect)
	var action_rects: Array[Rect2] = []
	for key: String in ["home", "challenge"]:
		var button: BaseButton = _action_button(view, key)
		if button == null:
			continue
		var rect: Rect2 = button.get_global_rect()
		check(bounds.grow(0.2).encloses(rect), context + ": " + key + " remains prominent and onscreen")
		var minimum: float = 44.0
		check(rect.size.x * _pixel_scale() >= minimum and rect.size.y * _pixel_scale() >= minimum,
			context + ": " + key + " retains a usable displayed-pixel target")
		check(not rect.intersects(viewport), context + ": prominent actions never cover the scroll viewport")
		for previous: Rect2 in action_rects:
			check(not rect.intersects(previous), context + ": prominent actions never overlap each other")
		action_rects.append(rect)
	check(_rect(snapshot.get("scroll_rect")).is_equal_approx(viewport)
		and int(snapshot.get("scroll_offset", -1)) == scroll.scroll_vertical,
		context + ": snapshots never retain stale pre-resize/pre-scroll geometry")
	var home: BaseButton = _action_button(view, "home")
	var heading: Label = view.get("_heading")
	var wallet: Label = view.get("_wallet")
	check(not home.get_global_rect().grow(6.0 / _pixel_scale()).intersects(heading.get_global_rect())
		and (not wallet.visible or not wallet.get_global_rect().intersects(heading.get_global_rect())),
		context + ": the actual Home control and wallet leave a separate title region")
	var ink: Vector2 = heading.get_theme_font("font").get_string_size(heading.text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, heading.get_theme_font_size("font_size"))
	check(ink.x <= heading.size.x + 0.1 and heading.get_line_count() == 1,
		context + ": the complete map title fits on one line without going under Home")
	var challenge: Button = _action_button(view, "challenge")
	var icon_pixels: Vector2 = challenge.get_global_rect().size * _pixel_scale()
	check(icon_pixels.x >= 44.0 and icon_pixels.x <= 46.0 and icon_pixels.y >= 44.0 and icon_pixels.y <= 46.0
		and not challenge.get_global_rect().intersects(heading.get_global_rect())
		and (not wallet.visible or not challenge.get_global_rect().intersects(wallet.get_global_rect())),
		context + ": a compact upper-right challenge icon stays clear of the title and wallet")
	check(challenge.get_global_rect().end.y <= _scroll(view).get_global_rect().position.y,
		context + ": the challenge entrance is in the header, not a large map footer")


func _check_status_copy(view: Control, source: Dictionary, context: String) -> void:
	var found: bool = false
	for control: Control in _text_controls(view):
		var text: String = _text(control)
		var expected: bool = text.contains(str(source.error)) if not str(source.error).is_empty() \
			else (text.to_lower().contains("load") and text.contains(str(source.pending_stage)))
		if not expected:
			continue
		found = true
		check(view.get_global_rect().grow(0.2).encloses(control.get_global_rect()),
			context + ": actual status copy stays fully onscreen")
		check(control.get_theme_font_size("font_size") * _pixel_scale() >= 14.0,
			context + ": actual loading/error copy remains legible")
		if control is Label:
			var label: Label = control as Label
			check(label.get_visible_line_count() >= label.get_line_count(),
				context + ": multiline status copy is not vertically clipped")
	check(found, context + ": visible status explains the exact pending stage or genuine load error")


func _check_configuration_and_isolation(view: Control) -> void:
	var source: Dictionary = _state()
	var original: Dictionary = source.duplicate(true)
	view.call("close")
	view.call("configure", source)
	await _settle()
	check(not view.visible, "Configuring a closed map cannot reopen it over another screen")
	view.call("open", source, true)
	await _settle()
	check(view.is_visible_in_tree() and bool(_snapshot(view).get("visible", false)), "Open shows the real map")
	_check_schema(view)
	_check_semantics(view, source)
	for refresh in range(4):
		view.call("configure", source, true)
	await _settle()
	check(source == original, "Opening and repeated refreshes never mutate supplied progress or coins")
	_check_stars(view, source, "Repeated configure")
	source.best_stars["1"] = 3
	source.highest_cleared = 98
	source.coins = 0
	check(int(_stage(_snapshot(view), 1).get("best_stars", 0)) == 1
		and not bool(_stage(_snapshot(view), 99).get("unlocked", false)),
		"The map owns duplicated inert view data, not references into a supplied progress store")
	var leaked: Dictionary = _snapshot(view)
	var leaked_stages: Array = leaked.get("stage_nodes", [])
	if not leaked_stages.is_empty():
		leaked_stages[0]["best_stars"] = 0
		leaked_stages.clear()
	check(_snapshot(view).get("stage_nodes", []).size() == 99
		and int(_stage(_snapshot(view), 1).get("best_stars", 0)) == 1,
		"Mutating a published snapshot cannot erase preserved rating state")
	var improved: Dictionary = original.duplicate(true)
	improved.best_stars["1"] = 3
	view.call("configure", improved, true)
	view.call("configure", improved, true)
	await _settle()
	_check_stars(view, improved, "Improved best rating")
	check(original.best_stars["1"] == 1 and improved.best_stars["1"] == 3
		and improved.coins == original.coins,
		"Displaying a better saved rating neither downgrades it nor awards/spends coins")
	var stale_frontier: Dictionary = _state()
	stale_frontier.frontier = 88
	view.call("open", stale_frontier, true)
	await _settle()
	_check_semantics(view, stale_frontier)
	var next_button: BaseButton = _stage_button(view, 13)
	check(next_button != null and root.gui_get_focus_owner() == next_button,
		"An inconsistent frontier hint cannot focus or unlock an unearned future stage")


func _check_actions_and_status(view: Control) -> void:
	var source: Dictionary = _state()
	var original: Dictionary = source.duplicate(true)
	view.call("open", source, true)
	await _settle()
	var scroll: ScrollContainer = _scroll(view)
	if scroll == null:
		return
	_stage_events.clear()
	_action_events.clear()
	var replay: BaseButton = _stage_button(view, 3)
	await _reveal(scroll, replay)
	await _click(replay)
	check(_stage_events == [3], "A cleared stage replays exactly once after repeated configuration")
	await _accept(_stage_button(view, 13), true)
	check(_stage_events == [3, 13], "Controller accept enters exactly the next frontier stage")
	var locked: BaseButton = _stage_button(view, 14)
	if locked != null:
		locked.pressed.emit()
	check(_stage_events == [3, 13], "A stale/programmatic signal cannot bypass a locked stage")
	await _accept(_action_button(view, "challenge"))
	await _click(_action_button(view, "home"))
	check(_action_events == ["challenge", "home"],
		"No-timer challenge and game-library return have distinct one-shot signals")
	check(source == original, "Selection signals never clear stars or mutate the supplied wallet/progress")
	var loading: Dictionary = original.duplicate(true)
	loading.loading = true
	loading.pending_stage = 13
	view.call("configure", loading, true)
	await _settle()
	_check_semantics(view, loading)
	_check_status_copy(view, loading, "Pending stage 13")
	for number in [3, 13]:
		var button: BaseButton = _stage_button(view, number)
		if button != null:
			button.pressed.emit()
	var challenge: BaseButton = _action_button(view, "challenge")
	if challenge != null:
		challenge.pressed.emit()
	check(_stage_events == [3, 13] and _action_events == ["challenge", "home"],
		"Loading suppresses replay, frontier and challenge, including stale activation signals")
	await _capture("loading-stage-13")
	var error_state: Dictionary = original.duplicate(true)
	error_state.error = "Stage progress could not be loaded. Please retry."
	view.call("configure", error_state, true)
	await _settle()
	_check_semantics(view, error_state)
	_check_status_copy(view, error_state, "Genuine load failure")
	var retry: BaseButton = _action_button(view, "retry")
	check(retry != null and retry.is_visible_in_tree() and not retry.disabled
		and _navigation(view).has(retry), "Failed loads expose an enabled keyboard/controller Retry")
	if retry != null:
		await _accept(retry, true)
	check(_action_events == ["challenge", "home", "retry"], "Retry emits the retry request, not a stage start")
	check(source == original and error_state.best_stars == original.best_stars
		and error_state.coins == original.coins, "Failure and retry preserve earned progress and coins")
	await _capture("visible-load-error")
	for dimensions: Vector2i in SIZES:
		await _resize(dimensions)
		for status: Dictionary in [loading, error_state]:
			view.call("configure", status, true)
			await _settle()
			_check_status_copy(view, status, "Responsive status at " + str(dimensions))
			if not str(status.error).is_empty():
				retry = _action_button(view, "retry")
				check(retry != null and view.get_global_rect().grow(0.2).encloses(retry.get_global_rect())
					and retry.size.x * _pixel_scale() >= 44.0 and retry.size.y * _pixel_scale() >= 44.0,
					"Retry remains an onscreen 44+ displayed-pixel target at " + str(dimensions))
	view.call("configure", original, true)
	await _settle()
	check(not bool(_snapshot(view).get("retry", {}).get("visible", true)),
		"A successful refresh removes the stale retry/error presentation")
	_check_stars(view, original, "After loading and error")


func _check_endpoints_and_focus(view: Control) -> void:
	var published: Array[Dictionary] = []
	var observe: Callable = func() -> void: published.append(view.call("snapshot"))
	check(view.has_signal("changed"), "Map geometry changes can publish fresh live input coordinates")
	if view.has_signal("changed"):
		view.connect("changed", observe)
	view.call("open", _state(0), true)
	await _settle()
	_check_semantics(view, _state(0))
	check(root.gui_get_focus_owner() == _stage_button(view, 1),
		"A new campaign starts at stage one, not a locked stage or challenge")
	var initial_scroll: ScrollContainer = _scroll(view)
	check(initial_scroll.scroll_vertical > 0
		and initial_scroll.get_global_rect().grow(0.5).encloses(_stage_button(view, 1).get_global_rect()),
		"A fresh map opens at the bottom with stage one completely visible")
	await _capture("entry-bottom-stage-1")
	check(published.any(func(state: Dictionary) -> bool:
		return _rect(state.scroll_rect).grow(0.5).encloses(_rect(_stage(state, 1).rect))),
		"Opening an upward map publishes the revealed stage-one coordinates after its deferred scroll")
	if view.has_signal("changed"):
		view.disconnect("changed", observe)
	var initial: Dictionary = _snapshot(view)
	for number in range(2, 100):
		check(_rect(_stage(initial, number).rect).get_center().y < _rect(_stage(initial, number - 1).rect).get_center().y,
			"Ascending order continues across chapter boundaries at stage %d" % number)
	var source: Dictionary = _state(98)
	view.call("open", source, true)
	await _settle()
	var scroll: ScrollContainer = _scroll(view)
	if scroll == null:
		return
	check(scroll.scroll_vertical < initial_scroll.get_v_scroll_bar().max_value - initial_scroll.get_v_scroll_bar().page,
		"The final frontier is above the bottom of the route")
	var final_button: BaseButton = _stage_button(view, 99)
	check(final_button != null and root.gui_get_focus_owner() == final_button
		and scroll.get_global_rect().grow(0.5).encloses(final_button.get_global_rect()),
		"Stage 99 is focused and fully reachable on entry")
	for number in range(1, 100):
		var button: BaseButton = _stage_button(view, number)
		if button == null:
			continue
		button.grab_focus()
		await _settle(2)
		check(root.gui_get_focus_owner() == button
			and scroll.get_global_rect().grow(0.5).encloses(button.get_global_rect()),
			"Native focus reveals stage %d: viewport=%s button=%s offset=%d content=%s range=%f page=%f loading=%s" % [
				number, scroll.get_global_rect(), button.get_global_rect(), scroll.scroll_vertical,
				view.get("_content").size, scroll.get_v_scroll_bar().max_value,
				scroll.get_v_scroll_bar().page, view.get("_state").get("loading", false)])
		check(bool(_stage(_snapshot(view), number).get("visible", false)),
			"Published visibility includes the genuinely revealed focused stage")
	scroll.scroll_vertical = roundi(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	view.call("focus_frontier")
	await _settle()
	check(root.gui_get_focus_owner() == final_button
		and scroll.get_global_rect().grow(0.5).encloses(final_button.get_global_rect()),
		"The explicit focus helper restores the frontier after manual scrolling")
	view.call("open", _state(99), true)
	await _settle()
	_check_semantics(view, _state(99))
	var snapshot: Dictionary = _snapshot(view)
	check(snapshot.get("stage_nodes", []).size() == 99 and _stage(snapshot, 100).is_empty()
		and root.gui_get_focus_owner() == _stage_button(view, 99, snapshot),
		"Completing stage 99 keeps every replay available and never creates or focuses stage 100")


func _check_resize_histories(view: Control) -> void:
	var source: Dictionary = _state(98)
	view.call("open", source, true)
	await _settle()
	var identity: int = view.get_instance_id()
	var history: Array[Vector2i] = [SIZES[0], SIZES[1], SIZES[2], SIZES[3],
		SIZES[0], SIZES[2], SIZES[1]]
	for scaled: bool in [false, true]:
		for index in range(history.size()):
			var dimensions: Vector2i = history[index]
			await _resize(dimensions, scaled)
			check(view.get_instance_id() == identity, "Resize regression tests reuse the same real map instance")
			var context: String = "%dx%d history %d, project scaling=%s" % [
				dimensions.x, dimensions.y, index, str(scaled)]
			_check_layout(view, context)
			_check_stars(view, source, context)
			var scroll: ScrollContainer = _scroll(view)
			if scroll != null:
				for number in [1, 9, 10, 45, 90, 99]:
					var button: BaseButton = _stage_button(view, number)
					if button != null:
						button.grab_focus()
						await _settle(2)
						check(scroll.get_global_rect().grow(0.5).encloses(button.get_global_rect()),
							context + ": focus still reveals stage %d after an earlier wider/taller layout" % number)
			if not scaled and index < SIZES.size():
				await _capture("responsive-%dx%d" % [dimensions.x, dimensions.y])
	await _resize(SIZES[1])
	view.call("open", source, true)
	await _settle()
	_check_scenery(view)


func _check_gesture_and_lifecycle(view: Control) -> void:
	var source: Dictionary = _state(98)
	view.call("open", source, true)
	await _settle()
	var scroll: ScrollContainer = _scroll(view)
	if scroll == null:
		return
	await _reveal(scroll, _stage_button(view, 2))
	var point: Vector2 = _stage_button(view, 2).get_global_rect().get_center()
	var offset: int = scroll.scroll_vertical
	var events: int = _stage_events.size()
	await _touch(point, true)
	await _touch_move(point - Vector2(0, 80.0 / _pixel_scale()))
	await _touch(point - Vector2(0, 80.0 / _pixel_scale()), false)
	check(scroll.scroll_vertical > offset and _stage_events.size() == events,
		"A real touch swipe scrolls the route without accidentally entering a stage")
	scroll.call("cancel_drag")
	var frozen: Array = _poses(view)
	check(_processing(view).is_empty(), "Reduced motion disables decorative frame processing")
	await _settle(6)
	check(_poses(view) == frozen, "Reduced-motion stars, frontier art and scenic shader parameters remain still")
	view.call("configure", source, false)
	await _settle()
	var geometry: Array = _geometry(view)
	await _settle(8)
	check(_geometry(view) == geometry, "Gentle motion never moves stage or action interaction rectangles")
	_holder.hide()
	await _settle()
	frozen = _poses(view)
	check(_processing(view).is_empty(), "A hidden ancestor stops all map decorative effects")
	await _settle(6)
	check(_poses(view) == frozen, "Hidden scenery does not advance or catch up behind another page")
	_holder.show()
	await _settle()
	if view.has_method("set_active"):
		view.call("set_active", false)
	view.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _settle()
	view.call("configure", source, false)
	await _resize(SIZES[3])
	frozen = _poses(view)
	check(_processing(view).is_empty(), "Background state survives refresh and resize without restarting effects")
	await _settle(6)
	check(_poses(view) == frozen, "Backgrounded atmospheric and frontier motion remains stopped")
	view.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	if view.has_method("set_active"):
		view.call("set_active", true)
	await _resize(SIZES[1])
	view.call("focus_frontier")
	await _settle()
	point = scroll.get_global_rect().get_center()
	await _touch(point, true, 9)
	check(bool(scroll.call("is_pointer_active")), "The close fixture owns a real in-flight route contact")
	view.call("close")
	await _settle()
	check(not view.is_visible_in_tree() and not bool(_snapshot(view).get("visible", true))
		and not bool(scroll.call("is_scrolling")), "Close hides the map and cancels gesture ownership/inertia")
	check(_navigation(view).is_empty() and _processing(view).is_empty(),
		"Closed controls cannot trap navigation or continue decorative processing")
	frozen = _poses(view)
	await _touch(point, false, 9)
	await _settle(6)
	check(_poses(view) == frozen and _stage_events.size() == events,
		"Releasing an old contact after close cannot select a stage or resume motion")
	view.call("open", source, true)
	await _settle()
	check(view.is_visible_in_tree() and root.gui_get_focus_owner() == _stage_button(view, 99),
		"Reopening restores the saved frontier without retaining the abandoned gesture")


func _capture_chapters(view: Control) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	for dimensions: Vector2i in [SIZES[0], SIZES[1]]:
		await _resize(dimensions)
		view.call("open", _state(45), true)
		await _settle()
		var scroll: ScrollContainer = _scroll(view)
		if scroll == null:
			return
		for chapter in range(1, 12):
			await _reveal(scroll, _stage_button(view, (chapter - 1) * 9 + 5))
			await _capture("chapter-%02d-%dx%d" % [chapter, dimensions.x, dimensions.y])


func _run() -> void:
	var exists: bool = ResourceLoader.exists(MAP_PATH)
	check(exists, "The self-contained stage map resource exists: " + MAP_PATH)
	if not exists:
		_finish()
		return
	var script: GDScript = load(MAP_PATH) as GDScript
	check(script != null and script.can_instantiate(), "The real stage map script compiles")
	if script == null or not script.can_instantiate():
		_finish()
		return
	var instance: Variant = script.new()
	check(instance is Control, "The map is an independently instantiable Control")
	if not instance is Control:
		if instance is Node:
			instance.free()
		_finish()
		return
	var view: Control = instance
	if not _check_api(view):
		view.free()
		_finish()
		return
	_check_assets()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = SIZES[0]
	_holder = Control.new()
	root.add_child(_holder)
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.connect("stage_selected", func(number: int) -> void: _stage_events.append(number))
	view.connect("challenge_selected", func() -> void: _action_events.append("challenge"))
	view.connect("home_requested", func() -> void: _action_events.append("home"))
	view.connect("retry_requested", func() -> void: _action_events.append("retry"))
	await _settle()
	await _check_configuration_and_isolation(view)
	await _check_actions_and_status(view)
	await _resize(SIZES[1])
	await _check_endpoints_and_focus(view)
	await _check_resize_histories(view)
	await _check_gesture_and_lifecycle(view)
	await _capture_chapters(view)
	_holder.free()
	await process_frame
	_finish()

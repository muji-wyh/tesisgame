extends SceneTree

const Style = preload("res://scripts/ui_style.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const BossActor = preload("res://scripts/word_jelly_boss_actor.gd")
const ChestModelView = preload("res://scripts/chest_model_view.gd")
const ScreenVeil = preload("res://scripts/screen_veil.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	_check_typography_and_materials()
	_check_screen_veil()
	await _check_music_lpf_and_crossfade()
	await _check_atmosphere_and_3d_lighting()
	await create_timer(0.15).timeout
	print("Premium craftsmanship: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_typography_and_materials() -> void:
	check(Style.DISPLAY_FONT != null and Style.DISPLAY_FONT != Style.HEADING_FONT and Style.DISPLAY_FONT != Style.BODY_FONT,
		"Display font loads as a distinct storybook display resource alongside Nunito body/heading")
	check(Style.DISPLAY_FONT.get_string_size("Pip's world", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x > 40.0,
		"Display font shapes readable display headings")
	var label := Style.display_heading("Jelly Journey", 30)
	check(label.get_theme_font("font") == Style.DISPLAY_FONT, "display_heading applies the display font")
	label.free()
	var card := Style.card_box(Style.PAPER, Style.EDGE, 20, 1, 1.0, 1.0)
	check(card.shadow_size >= 4 and card.shadow_color.a > 0.0, "card_box creates soft diffused elevation")
	var mat := Style.paper_material(Style.PAPER)
	check(mat != null and mat.shader == Style.PAPER_GRAIN, "paper_material attaches the paper grain shader")
	var btn := Button.new()
	Style.action_button(btn, Style.GOOD, true)
	var normal: StyleBox = btn.get_theme_stylebox("normal")
	var pressed: StyleBox = btn.get_theme_stylebox("pressed")
	check(normal != null and pressed != null and normal != pressed,
		"action_button has distinct normal and pressed tactile states")
	if normal is StyleBoxFlat and pressed is StyleBoxFlat:
		check((normal as StyleBoxFlat).border_width_bottom > (pressed as StyleBoxFlat).border_width_bottom,
			"flat action_button has a tactile 3D lip that compresses on press")
	elif normal is StyleBoxTexture and pressed is StyleBoxTexture:
		check((normal as StyleBoxTexture).texture != (pressed as StyleBoxTexture).texture,
			"textured action_button switches to a distinct compressed pressed surface")
	check(pressed.content_margin_top > normal.content_margin_top,
		"action_button shifts content down cleanly on press without changing hit rect")
	btn.free()


func _check_screen_veil() -> void:
	var veil := ScreenVeil.new()
	root.add_child(veil)
	veil.size = Vector2(800, 600)
	check(veil.mouse_filter == Control.MOUSE_FILTER_IGNORE and veil.focus_mode == Control.FOCUS_NONE,
		"ScreenVeil never blocks pointer input or keyboard focus")
	veil.pulse(Style.PAPER)
	check(veil.is_active() and veil.visible and veil.is_processing(),
		"ScreenVeil activates and animates on screen handoff")
	for _frame in range(8):
		veil._process(0.05)
	check(not veil.is_active() and not veil.visible and not veil.is_processing(),
		"ScreenVeil finishes cleanly and stops processing")
	veil.set_reduced_motion(true)
	veil.pulse(Style.PAPER)
	check(not veil.is_active() and not veil.visible and not veil.is_processing(),
		"ScreenVeil is an immediate no-op under reduced motion")
	veil.queue_free()
	await process_frame


func _check_music_lpf_and_crossfade() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring", true)
	check(audio.music.playing and audio.music.bus == Audio.MUSIC_BUS_NAME,
		"BGM plays through the dedicated Music bus")
	check(is_equal_approx(audio.music_lpf_cutoff(), Audio.MUSIC_LPF_OPEN_HZ),
		"Active gameplay starts with an open low-pass filter")
	audio.set_music_muffled(true)
	for _step in range(12):
		audio._process(0.04)
	check(audio.music_muffled() and audio.music_lpf_cutoff() < 1100.0,
		"Pause/overlay smoothly engages the warm low-pass filter on BGM")
	audio.set_music_muffled(false)
	for _step in range(14):
		audio._process(0.04)
	check(not audio.music_muffled() and audio.music_lpf_cutoff() > 19000.0,
		"Resuming gameplay restores full-spectrum BGM clarity")
	audio.interact("ocean", true)
	check(audio._music_fade != null and audio._music_fade.playing and audio.music.playing,
		"Switching BGM theme initiates a smooth dual-player crossfade")
	for _step in range(12):
		audio._process(0.05)
	check(not audio._music_fade.playing and audio.music.playing and audio.current_theme == "ocean",
		"Crossfade completes and stops the outgoing BGM player cleanly")
	audio.stop_music()
	check(not audio.music.playing and not audio._music_fade.playing,
		"stop_music immediately silences both primary and crossfade BGM players")
	audio.interact("spring", false)
	audio.play_fragment_arrival()
	var first_pitch: float = audio._fragment_players[0].pitch_scale
	audio._fragment_last_ms.clear()
	audio.play_fragment_arrival()
	var second_pitch: float = audio._fragment_players[1].pitch_scale
	check(is_equal_approx(first_pitch, 1.0) and second_pitch > first_pitch and second_pitch <= 2.0,
		"Consecutive fragment arrivals ascend cleanly along the pentatonic scale")
	audio.halt()
	audio.queue_free()
	await process_frame


func _check_atmosphere_and_3d_lighting() -> void:
	var backdrop := Backdrop.new()
	root.add_child(backdrop)
	backdrop.size = Vector2(800, 600)
	backdrop.set_chapter(5)
	var autumn: Dictionary = backdrop.atmosphere()
	backdrop.set_chapter(6)
	var snow: Dictionary = backdrop.atmosphere()
	check(autumn.well_tint != snow.well_tint and autumn.key_light != snow.key_light,
		"Each chapter supplies distinct synchronized atmosphere lighting colors")
	backdrop.set_reduced_motion(true)
	check(is_zero_approx(float(backdrop._sky_material.get_shader_parameter("mote_strength"))),
		"Reduced motion disables ambient sky motes cleanly")
	backdrop.set_reduced_motion(false)
	check(float(backdrop._sky_material.get_shader_parameter("mote_strength")) > 0.5,
		"Normal motion enables gentle shader-driven ambient sky motes")
	var boss := BossActor.new()
	root.add_child(boss)
	var before_key: Color = boss._key_light.light_color
	boss.set_atmosphere(autumn.key_light, autumn.ambient_light)
	check(boss._key_light.light_color != before_key,
		"Boss 3D studio key light blends with chapter atmosphere")
	var chest := ChestModelView.new()
	root.add_child(chest)
	var before_chest_key: Color = chest._key_light.light_color
	chest.set_atmosphere(snow.key_light, snow.ambient_light)
	check(chest._key_light.light_color != before_chest_key,
		"Chest 3D studio key light blends with world atmosphere")
	backdrop.queue_free()
	boss.queue_free()
	chest.queue_free()
	await process_frame

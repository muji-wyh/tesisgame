extends SceneTree

# Render with Godot Movie Maker, for example:
# node tools/run-godot.cjs --path . --resolution 960x720 --fixed-fps 60 \
#   --write-movie build/chest-feel/autumn.avi --script res://tools/capture-chest-feel.gd -- --theme=autumn
# This isolated art/audio preview never loads or writes player reward storage.
const Chest = preload("res://scripts/chest_view.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Data = preload("res://scripts/game_data.gd")
const Feel = preload("res://scripts/chest_feel.gd")

var chest
var sound
var clock_seconds: float = 0.0
var ready_to_capture: bool = false
var theme_id: String = "autumn"
var phase: int = 0
var cues: Array = []
var reward_time: float = -1.0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--theme="):
			theme_id = argument.trim_prefix("--theme=")
	if not Data.THEMES.has(theme_id):
		printerr("Unknown chest theme: " + theme_id)
		quit(1)
		return
	_start.call_deferred()


func _start() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	# Movie Maker fixes its dimensions before this script starts. Match the
	# project's 960 x 720 viewport to avoid stretching a resized capture.
	root.size = Vector2i(960, 720)
	var data := Data.new()
	if not data.load_all():
		printerr(data.error)
		quit(1)
		return
	var background := ColorRect.new()
	background.color = Color("#f6f4ee")
	background.size = Vector2(960, 720)
	root.add_child(background)
	chest = Chest.new()
	root.add_child(chest)
	chest.position = Vector2(180, 75)
	chest.size = Vector2(600, 560)
	chest.configure_skin(data.theme(theme_id), data.chests)
	chest.set_process(false)
	sound = Audio.new()
	root.add_child(sound)
	sound.prepare_chest(theme_id)
	sound.interact(theme_id, false)
	chest.cue_requested.connect(_on_cue)
	chest.opened.connect(func() -> void:
		reward_time = clock_seconds
		sound.finish_chest_motion()
		sound.chest_reward(theme_id))
	ready_to_capture = true


func _on_cue(theme: String, cue: String, step: int) -> void:
	cues.append({"theme": theme, "cue": cue, "step": step, "time": clock_seconds})
	sound.chest_cue(theme, cue, step)


func _process(delta: float) -> bool:
	if not ready_to_capture:
		return false
	clock_seconds += delta
	if phase == 0 and clock_seconds >= 0.3:
		chest.begin_hold()
		sound.set_chest_charge(0.0)
		phase = 1
	if phase == 1:
		var progress: float = clampf((clock_seconds - 0.3) / Feel.HOLD_SECONDS, 0.0, 1.0)
		chest.set_hold_progress(maxf(0.001, progress))
		sound.set_chest_charge(progress)
		if clock_seconds >= 0.48:
			chest.cancel_hold()
			sound.stop_chest_charge()
			phase = 2
	if phase == 2 and clock_seconds >= 0.85:
		chest.begin_hold()
		sound.set_chest_charge(0.0)
		phase = 3
	if phase == 3:
		var progress: float = clampf((clock_seconds - 0.85) / Feel.HOLD_SECONDS, 0.0, 1.0)
		chest.set_hold_progress(maxf(0.001, progress))
		sound.set_chest_charge(progress)
		if progress >= 1.0:
			chest.start_open(false)
			phase = 4
	# Retain the runtime frame-origin guard: this frame's delta predates an
	# opening or cancel initiated above and must not advance that new action.
	chest._process(delta)
	if phase == 4:
		sound.set_chest_tension(chest.tension_progress())
	if clock_seconds >= 7.5:
		print(JSON.stringify({"theme": theme_id, "cues": cues, "reward_time": reward_time,
			"state": chest.hold_effect_snapshot()}))
		quit()
	return false

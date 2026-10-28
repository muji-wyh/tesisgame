extends Control

signal exit_requested
signal replay_requested
signal home_requested
signal changed(state: Dictionary)
signal chest_audio_requested(action: String, theme_id: String, progress: float)
signal chest_cue_requested(theme_id: String, cue: String, step: int)
signal coins_released(id: String, reward: Dictionary, origin: Vector2, animate: bool)
signal settlement_retry_requested
signal challenge_result_accepted
signal challenge_retry_requested
signal challenge_record_broken(round_id: String)

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const State = preload("res://scripts/pop_reward_state.gd")
const Chest = preload("res://scripts/chest_view.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const JellyRewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const TreasureScroll = preload("res://scripts/treasure_scroll.gd")
const Mascot = preload("res://scripts/duck_mascot.gd")
const RewardLayout = preload("res://scripts/round_reward_layout.gd")
const CoinBreakdown = preload("res://scripts/chest_coin_breakdown.gd")
const TREASURE_LIGHT = preload("res://assets/chests/particles/portal_glow.png")
const RATING_STAR = preload("res://assets/images/ui/jelly-goals/star.webp")
const JellyRating = preload("res://scripts/word_jelly_stage_banner.gd")
const RATING_SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const SkillReveal = preload("res://scripts/word_jelly_skill_reveal.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const RecordBadge = preload("res://scripts/word_jelly_record_badge.gd")
const STAR_STEP_SECONDS: float = 0.18
const STAR_APPEAR_SECONDS: float = 0.42
const STAGE_BONUS_SECONDS: float = 0.70

var rewards := State.new()
var _settlement_error: String = ""
var save_path: String = "user://pop-rewards-v1.cfg"
var storage_kind: String = "pop"
var max_chests: int = 3
var allow_repeated_themes: bool = false
var page_size: int = 3
var reduced_motion: bool = false
var interaction_allowed: Callable
var credit_coins: Callable
var reserve_chest_reward: Callable
var chest_reward: Callable
var _cards: Array[Dictionary] = []
var _manifest: Dictionary = {}
var _configured_id: String = ""
var _draft_themes: Array[String] = []
var _draft_tiers: Array[int] = []
var _active: int = -1
var _holding: bool = false
var _opening: bool = false
var _elapsed: float = 0.0
var _hold_frame: int = -1
var _paused: bool = false
var _settling: bool = false
var _save_failed: bool = false
var _unsaved_index: int = -1
var _pointer_origin: Vector2
var _pointer_set: bool = false
var _layout_pending: bool = false
var _heading: Label
var _progress: Label
var _scroll: TreasureScroll
var _content: Control
var _notice: Label
var _back: Button
var _home: Button
var _retry: Button
var _previous_page: Button
var _next_page: Button
var _page_label: Label
var _page_index: int = 0
var _result_context: Dictionary = {}
var _result_reward_id: String = ""
var _empty_result_id: String = ""
var _result_score: Label
var _result_caption: Label
var pip: Mascot
var _companion_theme: String = ""
var _companion_age: int = 0
var _collecting: bool = false
var _collect_pending: bool = false
var _stage_rating: Control
var _stage_stars: Array[TextureRect] = []
var _stage_bonus_label: Label
var _stage_feedback_round: String = ""
var _stage_intro_elapsed: float = 1.0
var _stage_bonus_elapsed: float = STAGE_BONUS_SECONDS
var _stage_bonus_receipt: String = ""
var _stage_bonus_reward: Dictionary = {}
var _stage_publish_elapsed: float = 0.0
var _skill_reveal := SkillReveal.new()
var _challenge_record := RecordBadge.new()
var _challenge_return_ready: bool = false
var _record_announced_round: String = ""
var _return_glow := TextureRect.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_skill_reveal)
	_skill_reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skill_reveal.accepted.connect(func() -> void:
		_content.show()
		changed.emit(snapshot()))
	_heading = _label("Your treasure", 28)
	_progress = _label("", 14)
	_result_score = _label("", 14)
	_result_score.add_theme_color_override("font_color", Style.MUTED)
	_result_score.hide()
	for label in [_heading, _progress, _result_score]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
		# Font shaping settles after a viewport-scale change. Reflow once its
		# actual metrics arrive so old text heights cannot squeeze the chest.
		label.minimum_size_changed.connect(_queue_layout)
	_progress.add_theme_color_override("font_color", Style.MUTED)
	_scroll = TreasureScroll.new()
	_scroll.name = "TreasureScroll"
	_scroll.interaction_allowed = func() -> bool:
		return not _paused and (not interaction_allowed.is_valid() or interaction_allowed.call())
	add_child(_scroll)
	_scroll.hold_started.connect(begin_hold)
	_scroll.hold_finished.connect(end_hold)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:
		changed.emit(snapshot())
		_queue_layout())
	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)
	_heading.reparent(_content)
	_progress.reparent(_content)
	_result_score.reparent(_content)
	_result_caption = _label("", 16)
	_result_caption.reparent(_content)
	_stage_rating = Control.new()
	_stage_rating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_stage_rating)
	_stage_rating.draw.connect(_draw_stage_feedback)
	for index in range(3):
		var star := TextureRect.new()
		star.texture = JellyRating.STAR_TEXTURES[index]
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage_rating.add_child(star)
		_stage_stars.append(star)
	_stage_bonus_label = _label("", 15)
	_stage_bonus_label.reparent(_stage_rating)
	_stage_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_bonus_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stage_rating.hide()
	_result_caption.hide()
	pip = Mascot.new()
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.focus_mode = Control.FOCUS_NONE
	pip.set_proactive_allowed(false)
	_content.add_child(pip)
	pip.name = "SettlementPip"
	pip.hide()
	_content.add_child(_challenge_record)
	_challenge_record.hide()
	_notice = _label("", 14)
	_notice.add_theme_color_override("font_color", Style.WRONG)
	_back = Button.new()
	UiClick.bind_button(_back)
	_back.name = "PopTreasureBack"
	_back.text = "Back"
	add_child(_back)
	Style.action_button(_back, Style.GOOD)
	_back.pressed.connect(func() -> void:
		if _result_context.get("campaign", {}).get("kind") == "challenge":
			if _challenge_action_allowed():
				challenge_result_accepted.emit()
			return
		if not _result_context.is_empty():
			if not _paused and (not interaction_allowed.is_valid() or interaction_allowed.call()):
				replay_requested.emit()
			return
		pause()
		exit_requested.emit())
	_return_glow.texture = TREASURE_LIGHT
	_return_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_return_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_return_glow.z_index = -1
	_back.add_child(_return_glow)
	_return_glow.hide()
	_home = Button.new()
	UiClick.bind_button(_home)
	_home.name = "GameOverHome"
	_home.text = "Home"
	add_child(_home)
	Style.action_button(_home, Style.GOOD)
	_home.hide()
	_home.pressed.connect(func() -> void:
		if _result_context.get("campaign", {}).get("kind") == "challenge":
			if _challenge_action_allowed():
				challenge_retry_requested.emit()
			return
		if _is_result_dialog() and not _paused and (not interaction_allowed.is_valid() or interaction_allowed.call()):
			home_requested.emit())
	_retry = Button.new()
	UiClick.bind_button(_retry)
	_retry.name = "PopTreasureRetry"
	_retry.text = "Retry save"
	add_child(_retry)
	Style.action_button(_retry, Style.GOOD, true)
	_retry.pressed.connect(_retry_result)
	_previous_page = Button.new()
	_previous_page.name = "TreasurePreviousPage"
	_previous_page.text = "Previous"
	UiClick.bind_button(_previous_page)
	Style.action_button(_previous_page, Style.GOOD, true)
	add_child(_previous_page)
	_previous_page.pressed.connect(func() -> void: set_page(_page_index - 1))
	_previous_page.focus_entered.connect(_ensure_result_pager_visible.bind(_previous_page))
	_next_page = Button.new()
	_next_page.name = "TreasureNextPage"
	_next_page.text = "Next"
	UiClick.bind_button(_next_page)
	Style.action_button(_next_page, Style.GOOD, true)
	add_child(_next_page)
	_next_page.pressed.connect(func() -> void: set_page(_page_index + 1))
	_next_page.focus_entered.connect(_ensure_result_pager_visible.bind(_next_page))
	_scroll.tap_controls = [_previous_page, _next_page]
	_page_label = _label("", 16)
	item_rect_changed.connect(_queue_layout)
	get_viewport().size_changed.connect(_queue_layout)
	visibility_changed.connect(_visibility_changed)
	_refresh()


func _label(text: String, pixels: int) -> Label:
	var label := Style.label(text, pixels)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	add_child(label)
	return label


func connect_storage(host: Object) -> bool:
	if not _configured_id.is_empty():
		return rewards.ready
	rewards = State.new(save_path, host)
	rewards.storage_kind = storage_kind
	rewards.max_chests = max_chests
	rewards.allow_repeated_themes = allow_repeated_themes
	_save_failed = not rewards.load_state()
	_refresh()
	return not _save_failed


func has_pending() -> bool:
	if not rewards.ready and not rewards.load_state():
		_save_failed = true
	return _save_failed or _unsaved_index >= 0 or rewards.has_pending()


func _saved_chest_reward(id: String) -> Dictionary:
	return chest_reward.call(id) if chest_reward.is_valid() else {}


func result_chest_reward() -> Dictionary:
	var id: String = _result_reward_id
	if id.is_empty() and not _cards.is_empty():
		id = str(_cards[0].reward_id)
	return _saved_chest_reward(id) if not id.is_empty() else {}


func _prepare_chest_rewards() -> bool:
	if not reserve_chest_reward.is_valid():
		return true
	for entry: Dictionary in _batch_entries():
		if bool(entry.opened):
			continue
		var result: Dictionary = reserve_chest_reward.call(str(entry.reward_id), maxi(1, int(entry.get("tier", 0))))
		if not bool(result.get("ok", false)):
			rewards.error = str(result.get("error", "Could not save the chest reward. Please retry."))
			return false
	return true


func set_result_context(result: Dictionary, earned_round_id: String = "") -> void:
	var previous_page_size: int = _effective_page_size()
	var had_empty_result: bool = not _empty_result_id.is_empty()
	var previous_reward_id: String = _result_reward_id
	var feedback_round: String = earned_round_id if result.has("campaign") else ""
	if feedback_round != _stage_feedback_round:
		_skill_reveal.hide()
		_content.show()
		_release_stage_bonus(false)
		_stage_feedback_round = feedback_round
		_stage_intro_elapsed = 1.0 if reduced_motion else 0.0
		_stage_bonus_receipt = ""
		_stage_bonus_elapsed = STAGE_BONUS_SECONDS
		_challenge_return_ready = false
		_record_announced_round = ""
		_back.scale = Vector2.ONE
		_challenge_record.reset()
	if _result_context != result:
		_settlement_error = ""
	_result_context = result.duplicate(true)
	_result_reward_id = ""
	if _is_result_dialog() and int(result.get("chest_count", 0)) > 0:
		_result_reward_id = rewards._reward_id(earned_round_id if not earned_round_id.is_empty() else _configured_id, 0)
	if result.is_empty():
		_empty_result_id = ""
	if is_instance_valid(_scroll) and (previous_page_size != _effective_page_size()
		or previous_reward_id != _result_reward_id or (had_empty_result and _empty_result_id.is_empty())):
		_page_index = 0
		_select_result_chest()
		_build_cards()
		return
	_refresh()


func stage_feedback_active() -> bool:
	var rating: int = int(_result_context.get("campaign", {}).get("stars", 0))
	return _skill_reveal.visible or (_challenge_record.visible and _challenge_record.feedback_active()) \
		or not _stage_bonus_reward.is_empty() or not reduced_motion \
		and rating > 0 and _stage_intro_elapsed < (rating - 1) * STAR_STEP_SECONDS + STAR_APPEAR_SECONDS


func _challenge_action_allowed() -> bool:
	return _challenge_return_ready and not _paused and not _save_failed and _settlement_error.is_empty() \
		and (not interaction_allowed.is_valid() or interaction_allowed.call())


func present_challenge_result(summary: Dictionary) -> void:
	if _result_context.get("campaign", {}).get("kind") != "challenge" or _challenge_return_ready:
		return
	_result_context["challenge_result"] = summary.duplicate(true)
	_challenge_return_ready = true
	_return_glow.modulate = Color(1.0, 0.84, 0.36, 0.30)
	_refresh()
	if bool(summary.get("new_best", false)) and _record_announced_round != _stage_feedback_round:
		_record_announced_round = _stage_feedback_round
		_challenge_record.set_record(int(summary.best), true, int(summary.previous_best))
		challenge_record_broken.emit(_stage_feedback_round)
	changed.emit(snapshot())


func present_stage_bonus(receipt: String, reward: Dictionary) -> void:
	if receipt == _stage_bonus_receipt or reward.get("duplicate", false) or int(reward.get("amount", 0)) <= 0:
		return
	_stage_bonus_receipt = receipt
	_stage_bonus_reward = reward.duplicate(true)
	_stage_bonus_elapsed = 0.0
	_pose_stage_feedback()


func present_skill_unlock(level: int, word: Dictionary) -> bool:
	if not _skill_reveal.present(level, word, reduced_motion):
		return false
	_content.hide()
	changed.emit(snapshot())
	return true


func advance_stage_feedback(delta: float) -> void:
	if _paused or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	if not stage_feedback_active():
		return
	_challenge_record.advance(delta)
	_stage_intro_elapsed += delta
	if _skill_reveal.visible:
		_skill_reveal.advance(delta)
	if not _stage_bonus_reward.is_empty():
		_stage_bonus_elapsed = STAGE_BONUS_SECONDS if reduced_motion else minf(STAGE_BONUS_SECONDS, _stage_bonus_elapsed + delta)
		if _stage_bonus_elapsed >= STAGE_BONUS_SECONDS:
			_release_stage_bonus(true)
	_pose_stage_feedback()
	_stage_publish_elapsed += delta
	if _stage_publish_elapsed >= 0.08 or not stage_feedback_active():
		_stage_publish_elapsed = 0.0
		changed.emit(snapshot())


func _release_stage_bonus(animate: bool) -> void:
	if _stage_bonus_reward.is_empty():
		return
	var reward: Dictionary = _stage_bonus_reward
	_stage_bonus_reward = {}
	_stage_bonus_elapsed = STAGE_BONUS_SECONDS
	var origin: Vector2 = _stage_bonus_label.get_global_rect().get_center()
	coins_released.emit(_stage_bonus_receipt, reward, origin, animate)


func _pose_stage_feedback() -> void:
	if _stage_rating == null or not _stage_rating.visible:
		return
	var rating: int = int(_result_context.get("campaign", {}).get("stars", 0))
	var boost: float = 0.0 if reduced_motion or _stage_bonus_reward.is_empty() \
		else sin(PI * _stage_bonus_elapsed / STAGE_BONUS_SECONDS)
	for index in range(3):
		var p: float = 1.0 if reduced_motion else clampf(
			(_stage_intro_elapsed - index * STAR_STEP_SECONDS) / STAR_APPEAR_SECONDS, 0.0, 1.0)
		var earned: bool = index < rating
		_stage_stars[index].scale = Vector2.ONE * ((0.60 + 0.40 * (1.0 - pow(1.0 - p, 3.0))
			+ 0.12 * sin(p * PI) + 0.12 * boost) if earned else 1.0)
		_stage_stars[index].modulate = Color(1, 1, 1, smoothstep(0.0, 0.22, p)) if earned \
			else Color(0.4, 0.46, 0.42, 0.40)
	var quote: Dictionary = _result_context.get("stage_bonus", {})
	if quote.get("ok", false) and rating > 0:
		var amount: int = int(quote.bonus)
		if not _stage_bonus_reward.is_empty():
			amount = roundi(amount * (1.0 - pow(1.0 - _stage_bonus_elapsed / STAGE_BONUS_SECONDS, 3.0)))
		_stage_bonus_label.text = "+%d\nclear coins" % amount
	_stage_bonus_label.scale = Vector2.ONE * (1.0 + 0.08 * boost)
	_result_score.scale = Vector2.ONE * (1.0 + 0.06 * boost)
	_stage_rating.queue_redraw()


func _draw_stage_feedback() -> void:
	if reduced_motion:
		return
	var s: float = Style.ui_scale(self)
	var rating: int = int(_result_context.get("campaign", {}).get("stars", 0))
	if not _stage_bonus_reward.is_empty():
		var glow: float = sin(PI * _stage_bonus_elapsed / STAGE_BONUS_SECONDS)
		var formula: Rect2 = _result_score.get_rect()
		formula.position -= _stage_rating.position
		_stage_rating.draw_texture_rect(TREASURE_LIGHT, formula.grow(12.0 / s),
			false, Color(1.0, 0.82, 0.32, glow * 0.45))
	for index in range(rating):
		var star: TextureRect = _stage_stars[index]
		var p: float = clampf((_stage_intro_elapsed - index * STAR_STEP_SECONDS) / STAR_APPEAR_SECONDS, 0.0, 1.0)
		var center: Vector2 = star.position + star.size * 0.5
		if p > 0.0 and p < 1.0:
			var glow: float = sin(p * PI)
			_stage_rating.draw_texture_rect(TREASURE_LIGHT, Rect2(center - star.size * 0.9, star.size * 1.8),
				false, Color(1.0, 0.84, 0.35, glow * 0.58))
			for mote in range(4):
				var angle: float = TAU * float(mote) / 4.0
				var at: Vector2 = center + Vector2(cos(angle), sin(angle)) * (star.size.x * 0.4 + p * 16.0 / s)
				_stage_rating.draw_texture_rect(RATING_SPARKLE, Rect2(at - Vector2.ONE * 5.0 / s, Vector2.ONE * 10.0 / s),
					false, Color(1.0, 0.87, 0.40, glow))
		if not _stage_bonus_reward.is_empty():
			var travel: float = clampf((_stage_bonus_elapsed / STAGE_BONUS_SECONDS - index * 0.08) / 0.75, 0.0, 1.0)
			var at: Vector2 = center.lerp(_stage_bonus_label.get_rect().get_center(), travel)
			at.y -= sin(travel * PI) * 18.0 / s
			var edge: float = 16.0 / s * (1.0 - travel * 0.35)
			_stage_rating.draw_texture_rect(JellyRating.STAR_TEXTURES[index], Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
				false, Color(1, 1, 1, sin(travel * PI)))


func set_settlement_error(message: String) -> void:
	if _settlement_error == message:
		return
	_settlement_error = message
	_refresh()


func _retry_result() -> void:
	if _result_context.has("campaign"):
		settlement_retry_requested.emit()
	else:
		retry_save()


func _select_result_chest() -> void:
	if _result_reward_id.is_empty():
		return
	# Retained treasure stays in storage order. Settlement starts on this round's
	# final reward, independent of older chests or unfinished upgrade animations.
	var entries: Array[Dictionary] = _batch_entries()
	for index in range(entries.size()):
		if str(entries[index].get("reward_id", "")) == _result_reward_id:
			_page_index = floori(float(index) / _effective_page_size())
			return


func configure_empty_result(id: String, manifest: Dictionary, reduce: bool) -> bool:
	# An empty round is presentation only. It must neither display an earlier
	# opened batch as a new reward nor replace any durable unopened treasure.
	if _unsaved_index >= 0:
		_refresh()
		return false
	pause()
	_manifest = manifest
	reduced_motion = reduce
	_empty_result_id = id
	_page_index = 0
	if not rewards.ready and not rewards.load_state():
		_save_failed = true
	_build_cards()
	resume()
	return not _save_failed


func _is_danger_result() -> bool:
	return str(_result_context.get("reason", "")) == "danger"


func _is_result_dialog() -> bool:
	return not _result_context.is_empty()


func set_companion(theme_id: String, age: int) -> void:
	_companion_theme = theme_id
	_companion_age = age
	_sync_companion()


func _sync_companion() -> void:
	if not is_instance_valid(pip):
		return
	pip.visible = _is_result_dialog()
	var theme: String = _companion_theme
	if theme.is_empty():
		theme = str(_cards[0].theme) if not _cards.is_empty() else "spring"
	pip.set_growth_age(_companion_age)
	pip.set_outfit_theme(theme)
	pip.set_reduced_motion(reduced_motion)
	pip.set_celebration_progress(1.0)
	pip.set_idle_paused(_paused or not is_visible_in_tree())


func result_summary() -> String:
	var score: int = maxi(0, int(_result_context.get("score", 0)))
	var is_pop: bool = _result_context.has("hits")
	var completed: int = maxi(0, int(_result_context.get("hits" if is_pop else "cleared_pairs", 0)))
	var words: String = "%d %s" % [completed, "word" if completed == 1 else "words"]
	var summary: String = "%d %s · %s" % [score, "point" if score == 1 else "points", words] if is_pop or score != completed else words
	var tier: int = maxi(0, int(_result_context.get("chest_tier", 0)))
	if tier > 0:
		summary += " · Level %d chest" % tier
	elif int(_result_context.get("chest_count", 0)) > 1:
		summary += " · %d chests" % int(_result_context.chest_count)
	return summary


func _effective_page_size() -> int:
	return 1 if _is_result_dialog() else maxi(1, page_size)


func collect_all_coins() -> bool:
	if _collecting:
		return false
	_collecting = true
	_collect_pending = true
	var was_paused: bool = _paused
	# Pause resolves a released lid silently and cancels any incomplete hold.
	# Unopened chests below are consumed directly, without playing their opening.
	pause()
	if not rewards.load_state():
		return _finish_collection(false, was_paused)
	if not _configured_id.is_empty() and rewards.round_id != _configured_id and not _draft_themes.is_empty():
		# A failed initial batch write must be recovered before Play again can
		# retire this round. Existing batch receipts make this idempotent.
		if not rewards.create_batch(_configured_id, _draft_themes, _draft_tiers):
			return _finish_collection(false, was_paused)
	_sync_saved_batch()
	var batch_id: String = rewards.round_id
	var entries: Array[Dictionary] = rewards.entries.duplicate(true)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if bool(entry.opened):
			continue
		if not credit_coins.is_valid():
			rewards.error = "Coin storage is unavailable. Please retry."
			return _finish_collection(false, was_paused)
		var reward_id: String = str(entry.get("reward_id", ""))
		var credit: Dictionary = credit_coins.call(reward_id, maxi(1, int(entry.get("tier", 0))))
		if not bool(credit.get("ok", false)):
			rewards.error = "Could not save your coins. Please retry."
			return _finish_collection(false, was_paused)
		if not rewards.mark_opened(batch_id, index):
			return _finish_collection(false, was_paused)
		coins_released.emit(reward_id, credit, global_position + size * 0.5, false)
	return _finish_collection(true, was_paused)


func _finish_collection(success: bool, was_paused: bool) -> bool:
	_collecting = false
	_collect_pending = not success
	_save_failed = not success
	_unsaved_index = -1
	# Rebuild only from this configured batch. Failed draft writes keep their
	# original identity and recovery arguments until the next retry succeeds.
	_build_cards()
	if not was_paused:
		resume()
	else:
		_refresh()
	if success:
		# Also reconcile a flight from a chest opened just before Play again.
		coins_released.emit("", {}, global_position + size * 0.5, false)
	return success


func configure(id: String, chest_count: int, preferred_theme: String, manifest: Dictionary, reduce: bool, final_chest_tier: int = 0) -> bool:
	_manifest = manifest
	reduced_motion = reduce
	if not _configured_id.is_empty() and _configured_id != id and (_unsaved_index >= 0 or _save_failed):
		_refresh()
		return false
	_empty_result_id = ""
	if _configured_id == id and not _cards.is_empty():
		set_reduced_motion(reduce)
		_refresh()
		return not _save_failed
	pause()
	_configured_id = id
	_page_index = 0
	var count: int = maxi(0, chest_count) if max_chests == 0 else clampi(chest_count, 0, max_chests)
	_draft_themes = _choose_themes(id, count, preferred_theme, allow_repeated_themes)
	_draft_tiers.clear()
	if final_chest_tier > 0 and count == 1:
		_draft_tiers.append(final_chest_tier)
	_save_failed = not rewards.create_batch(id, _draft_themes, _draft_tiers)
	if not _save_failed:
		_sync_saved_batch()
		_save_failed = not _prepare_chest_rewards()
	_unsaved_index = -1
	_build_cards()
	resume()
	return not _save_failed


func _sync_saved_batch() -> void:
	_configured_id = rewards.round_id
	_draft_themes.clear()
	_draft_tiers.clear()
	for entry in rewards.entries:
		_draft_themes.append(str(entry.theme))
		_draft_tiers.append(int(entry.get("tier", 0)))


func configure_saved(manifest: Dictionary, reduce: bool) -> bool:
	_manifest = manifest
	reduced_motion = reduce
	if _unsaved_index >= 0 or (_save_failed and not _configured_id.is_empty()):
		resume()
		return false
	_empty_result_id = ""
	pause()
	_save_failed = not rewards.load_state()
	if not _save_failed and rewards.entries.is_empty():
		return false
	_sync_saved_batch()
	if not _save_failed:
		_save_failed = not _prepare_chest_rewards()
	_page_index = 0
	for index in range(rewards.entries.size()):
		if not bool(rewards.entries[index].opened):
			_page_index = floori(float(index) / _effective_page_size())
			break
	_select_result_chest()
	_build_cards()
	resume()
	return not _save_failed


static func _choose_themes(id: String, count: int, preferred: String, repeat_preferred: bool = false) -> Array[String]:
	var available: Array[String] = []
	for key in Data.THEMES:
		available.append(str(key))
	if repeat_preferred:
		var repeated: Array[String] = []
		var selected: String = preferred if available.has(preferred) else available[0]
		for index in range(maxi(0, count)):
			repeated.append(selected)
		return repeated
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	for index in range(available.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var value: String = available[index]
		available[index] = available[other]
		available[other] = value
	if available.has(preferred):
		available.erase(preferred)
		available.push_front(preferred)
	var result: Array[String] = []
	var types: Array[String] = []
	for theme_id in available:
		var chest_type: String = str(Data.THEMES[theme_id].chest)
		if types.has(chest_type):
			continue
		if result.size() >= count:
			break
		result.append(theme_id)
		types.append(chest_type)
	return result


func _build_cards() -> void:
	_scroll.cancel_drag()
	_scroll.scroll_vertical = 0
	for card in _cards:
		card.panel.free()
	_cards.clear()
	var entries: Array[Dictionary] = _batch_entries()
	_page_index = clampi(_page_index, 0, _page_count() - 1)
	var start: int = _page_index * _effective_page_size()
	for entry_index in range(start, mini(entries.size(), start + _effective_page_size())):
		var index: int = _cards.size()
		var entry: Dictionary = entries[entry_index]
		var palette: Dictionary = Data.theme(str(entry.theme))
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_content.add_child(panel)
		var light := TextureRect.new()
		light.texture = TREASURE_LIGHT
		light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		light.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		light.modulate = Color("#e8d19c", 0.36)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(light)
		var art := Chest.new()
		panel.add_child(art)
		var tier: int = int(entry.get("tier", 0))
		if tier > 0:
			art.configure_tier(clampi(tier, 1, JellyRewardProgress.MAX_TIER), palette, _manifest)
		else:
			art.configure_skin(palette, _manifest)
		art.reduced_motion = reduced_motion
		var tier_label := Style.label(JellyRewardProgress.title_for_tier(tier) if tier > 0 else "", 14)
		tier_label.name = "ChestTier"
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.add_theme_color_override("font_color", Style.GOOD)
		tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tier_label)
		var button := Button.new()
		button.name = "%sTreasureChest%d" % ["Jelly" if storage_kind == "jelly" else "Pop", entry_index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style_name in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		panel.add_child(button)
		# The chest owns input. Its instruction is plain, non-interactive text.
		var hint := Panel.new()
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		panel.add_child(hint)
		var caption := Style.label("Hold to open", 16)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_child(caption)
		var breakdown := CoinBreakdown.new()
		hint.add_child(breakdown)
		var quote: Dictionary = _saved_chest_reward(str(entry.get("reward_id", "")))
		breakdown.set_reward(quote)
		breakdown.hide()
		_cards.append({"panel": panel, "light": light, "art": art, "entry_index": entry_index,
			"button": button, "hint": hint, "caption": caption,
			"breakdown": breakdown, "chest_reward": quote,
			"theme": str(entry.theme), "tier": tier, "tier_label": tier_label,
			"opened": bool(entry.opened), "announced": bool(entry.opened),
			"reward_id": str(entry.get("reward_id", "")), "coin_reward": {}})
		button.focus_entered.connect(_ensure_chest_visible.bind(button))
		button.focus_entered.connect(_refresh_captions)
		button.mouse_entered.connect(_refresh_captions)
		button.mouse_exited.connect(_refresh_captions)
		button.button_down.connect(begin_hold.bind(button))
		button.button_up.connect(func() -> void:
			if _active == index:
				end_hold())
		button.gui_input.connect(_card_input.bind(index))
		button.focus_exited.connect(func() -> void:
			if _active == index:
				cancel_input()
			_refresh_captions())
		art.release_reached.connect(_released.bind(index))
		art.opened.connect(_finished.bind(index))
		art.cue_requested.connect(_cue.bind(index))
		if bool(entry.opened):
			# Restoring a completed chest must not replay its release or opening flourish.
			art.mode = "opening"
			art.finish_immediately()
	_refresh()


func _batch_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not _empty_result_id.is_empty():
		return entries
	if rewards.round_id == _configured_id:
		entries.assign(rewards.entries)
	if entries.is_empty():
		for index in range(_draft_themes.size()):
			var entry: Dictionary = {"theme": _draft_themes[index], "opened": false}
			if index < _draft_tiers.size() and _draft_tiers[index] > 0:
				entry["tier"] = _draft_tiers[index]
			entries.append(entry)
	return entries


func _page_count() -> int:
	return maxi(1, ceili(float(_batch_entries().size()) / _effective_page_size()))


func set_page(index: int) -> bool:
	if not is_visible_in_tree() or _paused or _holding or _opening or _save_failed or _unsaved_index >= 0:
		return false
	if interaction_allowed.is_valid() and not interaction_allowed.call():
		return false
	var target: int = clampi(index, 0, _page_count() - 1)
	if target == _page_index:
		return false
	var move_focus: bool = _previous_page.has_focus() or _next_page.has_focus()
	cancel_input()
	_page_index = target
	_build_cards()
	if move_focus:
		var controls: Array[Control] = navigation_controls()
		if not controls.is_empty():
			controls[0].grab_focus()
	return true


func navigation_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _skill_reveal.visible:
		controls.append(_skill_reveal if _skill_reveal._continue.disabled else _skill_reveal._continue)
		return controls
	for card in _cards:
		if not card.button.disabled:
			controls.append(card.button)
	if _retry.visible:
		controls.append(_retry)
	for button in [_previous_page, _next_page]:
		if is_instance_valid(button) and button.visible and not button.disabled:
			controls.append(button)
	if is_instance_valid(_home) and _home.visible:
		controls.append(_home)
	controls.append(_back)
	return controls


func is_chest_control(control: Control) -> bool:
	for card in _cards:
		if card.button == control:
			return not card.button.disabled and is_visible_in_tree() and not _paused
	return false


func begin_hold(control: Control) -> void:
	if _active >= 0 or _paused or _save_failed or not is_chest_control(control):
		return
	if interaction_allowed.is_valid() and not interaction_allowed.call():
		return
	_ensure_chest_visible(control)
	for index in range(_cards.size()):
		if _cards[index].button == control:
			_active = index
			break
	if _active < 0:
		return
	_holding = true
	_elapsed = 0.0
	_hold_frame = Engine.get_process_frames()
	_pointer_set = false
	var card: Dictionary = _cards[_active]
	chest_audio_requested.emit("prepare", card.theme, 0.0)
	card.art.begin_hold()
	chest_audio_requested.emit("charge", card.theme, 0.0)
	_refresh()


func end_hold() -> void:
	_cancel(true)


func cancel_input() -> void:
	_cancel(false)
	if is_instance_valid(_scroll):
		_scroll.cancel_drag()


func _cancel(animate: bool) -> void:
	_holding = false
	_elapsed = 0.0
	_hold_frame = -1
	_pointer_set = false
	if _active < 0:
		return
	var card: Dictionary = _cards[_active]
	if _opening and card.art.opening_committed():
		return
	if _opening:
		card.art.cancel_open(animate)
	elif animate:
		card.art.cancel_hold()
	else:
		card.art.set_hold_progress(0.0)
	chest_audio_requested.emit("cancel" if animate else "stop", card.theme, 0.0)
	_active = -1
	_opening = false
	_refresh()


func _process(delta: float) -> void:
	if Engine.get_process_frames() != _hold_frame:
		advance_hold(delta)


func advance_hold(delta: float) -> void:
	if _paused or _active < 0 or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	var card: Dictionary = _cards[_active]
	if _holding and not _opening:
		_elapsed += delta
		var progress: float = minf(1.0, _elapsed / Feel.HOLD_SECONDS)
		card.art.set_hold_progress(progress)
		chest_audio_requested.emit("charge", card.theme, progress)
		if progress >= 1.0:
			_opening = true
			card.art.start_open(reduced_motion)
	if _opening:
		chest_audio_requested.emit("release" if card.art.opening_committed() else "tension", card.theme, card.art.tension_progress())
	_refresh_captions()


func _released(index: int) -> void:
	if index != _active or not _opening or not _cards[index].art.opening_committed():
		return
	_holding = false
	_hold_frame = -1
	_pointer_set = false
	_commit(index)
	if not _settling:
		chest_audio_requested.emit("release", _cards[index].theme, 1.0)
	_refresh()


func _commit(index: int) -> bool:
	if _cards[index].opened:
		return true
	# Validate ownership against the current durable batch before a coin receipt
	# can be issued. A different tab may have appended and moved these entries.
	if not rewards.load_state() or rewards.round_id != _configured_id:
		_save_failed = true
		_unsaved_index = index
		return false
	var entry_index: int = _cards[index].entry_index
	if entry_index >= rewards.entries.size() or str(rewards.entries[entry_index].get("reward_id", "")) != _cards[index].reward_id:
		_save_failed = true
		_unsaved_index = index
		return false
	if not rewards.entries[entry_index].opened and credit_coins.is_valid():
		var credit: Dictionary = credit_coins.call(_cards[index].reward_id, maxi(1, int(_cards[index].tier)))
		if not bool(credit.get("ok", false)):
			rewards.error = "Could not save your coins. Please retry."
			_save_failed = true
			_unsaved_index = index
			return false
		if int(credit.get("amount", 0)) > 0:
			_cards[index].coin_reward = credit
		_cards[index].chest_reward = credit.get("chest_reward", _saved_chest_reward(str(_cards[index].reward_id)))
		_cards[index].breakdown.set_reward(_cards[index].chest_reward)
	if rewards.mark_opened(_configured_id, int(_cards[index].entry_index)):
		_cards[index].opened = true
		if rewards.last_open_was_duplicate:
			_cards[index].announced = true
		_unsaved_index = -1
		_save_failed = false
		return true
	_save_failed = true
	_unsaved_index = index
	return false


func _finished(index: int) -> void:
	if index != _active or not _opening or _cards[index].art.mode != "opened":
		return
	_commit(index)
	_holding = false
	_opening = false
	_active = -1
	_elapsed = 0.0
	_hold_frame = -1
	if not _settling:
		chest_audio_requested.emit("finish", _cards[index].theme, 1.0)
	_announce(index)
	_refresh()


func _announce(index: int) -> void:
	if _cards[index].announced or not _cards[index].opened:
		return
	_cards[index].announced = true
	coins_released.emit(_cards[index].reward_id, _cards[index].coin_reward,
		_cards[index].art.get_global_transform() * _cards[index].art._cavity_origin(),
		not _settling and not _paused and is_visible_in_tree())
	if _settling or _paused or not is_visible_in_tree():
		return
	chest_audio_requested.emit("reward", _cards[index].theme, 0.0)


func _cue(theme_id: String, cue: String, step: int, index: int) -> void:
	if index != _active or _settling or _paused or not is_visible_in_tree():
		return
	if cue in ["press", "hold_pulse"] and (not _holding or _opening):
		return
	if cue in ["opening", "tension_pulse", "anticipation", "unlock", "release", "settle"] and not _opening:
		return
	chest_cue_requested.emit(theme_id, cue, step)


func retry_save() -> void:
	if _collect_pending:
		collect_all_coins()
		return
	if not _empty_result_id.is_empty():
		_save_failed = not rewards.load_state()
		if not _save_failed and not _configured_id.is_empty() and rewards.round_id != _configured_id and not _draft_themes.is_empty():
			_save_failed = not rewards.create_batch(_configured_id, _draft_themes, _draft_tiers)
		if not _save_failed:
			_sync_saved_batch()
			_save_failed = not _prepare_chest_rewards()
		_build_cards()
		return
	if _unsaved_index >= 0:
		if (storage_kind == "jelly" or max_chests == 0) and rewards.load_state() and rewards.round_id != _configured_id:
			# Another tab appended loot and changed indexes. Reload rather than
			# applying this old chest's callback to a different saved chest.
			pause()
			_unsaved_index = -1
			_save_failed = false
			configure_saved(_manifest, reduced_motion)
			return
		var index: int = _unsaved_index
		if _commit(index) and _cards[index].art.mode == "opened":
			_announce(index)
	elif _configured_id.is_empty():
		_save_failed = not rewards.load_state()
		if not _save_failed and not rewards.entries.is_empty():
			configure_saved(_manifest, reduced_motion)
	elif storage_kind != "jelly" and max_chests > 0 and rewards.has_pending() and rewards.round_id != _configured_id:
		# Another tab may have earned a batch while this round was in play.
		# Keep that durable batch intact and let the player resume it.
		_save_failed = false
		configure_saved(_manifest, reduced_motion)
	else:
		_save_failed = not rewards.create_batch(_configured_id, _draft_themes, _draft_tiers)
		if not _save_failed:
			_sync_saved_batch()
			_save_failed = not _prepare_chest_rewards()
			_select_result_chest()
			_build_cards()
	_refresh()


func pause() -> void:
	_release_stage_bonus(false)
	_settling = true
	cancel_input()
	if _active >= 0 and _opening and _cards[_active].art.opening_committed():
		chest_audio_requested.emit("stop", _cards[_active].theme, 0.0)
		_cards[_active].art.finish_immediately()
	_settling = false
	_paused = true
	for card in _cards:
		card.art.set_idle_paused(true)
	_refresh()


func resume() -> void:
	_paused = false
	for card in _cards:
		card.art.set_idle_paused(false)
	_refresh()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_skill_reveal.reduced_motion = enabled
	for card in _cards:
		card.art.reduced_motion = enabled
	if enabled and _active >= 0 and _opening:
		# A settings change never completes a cancellable hold on the player's behalf.
		if _cards[_active].art.opening_committed():
			_cards[_active].art.finish_immediately()
		else:
			cancel_input()
	_refresh()


func _card_input(event: InputEvent, index: int) -> void:
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and not event.echo:
		if event.pressed:
			begin_hold(_cards[index].button)
		else:
			end_hold()
		accept_event()
	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			begin_hold(_cards[index].button)
			_pointer_origin = event.position
			_pointer_set = true
		elif _active == index:
			end_hold()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _active == index and _pointer_set:
		if event.position.distance_to(_pointer_origin) * Style.ui_scale(self) > 10.0:
			end_hold()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		pause()
	else:
		_queue_layout()


func _refresh_captions() -> void:
	var s: float = Style.ui_scale(self)
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		var message: String = "Opened!" if card.opened else ("Hold the chest to open" if _is_result_dialog() else "Hold to open")
		if _unsaved_index == index:
			message = "Opened - retry save"
		elif index == _active:
			message = "You can let go!" if card.art.opening_committed() else "Keep holding..."
		card.button.accessibility_name = str(Data.theme(card.theme).name) + " chest. " + message
		if int(card.tier) > 0:
			card.button.accessibility_name = "Tier %d. " % int(card.tier) + card.button.accessibility_name
		if index == _active and not card.art.opening_committed():
			card.button.accessibility_name += " Release to cancel."
		card.caption.text = message
		var show_reward: bool = bool(card.opened) and not _save_failed and not card.chest_reward.is_empty()
		card.breakdown.visible = show_reward
		card.caption.visible = not show_reward
		if show_reward:
			card.button.accessibility_name += " " + CoinBreakdown.description(card.chest_reward)
		var active: bool = index == _active
		var focused: bool = card.button.has_focus() and not card.button.disabled
		var hovered: bool = card.button.is_hovered() and not card.button.disabled
		var appearance: Array = [active, focused, hovered, card.opened, s]
		if card.hint.get_meta("appearance", []) == appearance:
			continue
		card.hint.set_meta("appearance", appearance)
		# Focus belongs to the reward itself, never a button-shaped instruction.
		card.light.modulate = Color("#ebcd85", 0.64 if active else 0.52 if focused else 0.38 if hovered else 0.22)
		card.caption.add_theme_color_override("font_color", Style.GOOD if active or focused or card.opened else Style.MUTED)


func _refresh() -> void:
	if not is_instance_valid(_back):
		return
	var failed: bool = _save_failed or not _settlement_error.is_empty()
	var failure: String = _settlement_error if not _settlement_error.is_empty() else rewards.error if _save_failed else ""
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		card.button.disabled = _paused or failed or card.opened or (_active >= 0 and _active != index)
	_retry.visible = failed
	_retry.text = "Resume saved treasure" if storage_kind != "jelly" and max_chests > 0 and rewards.has_pending() and rewards.round_id != _configured_id else "Retry save"
	_retry.disabled = _opening
	_notice.text = failure
	_notice.visible = failed and not _is_result_dialog()
	var state: Dictionary = snapshot()
	var result_mode: bool = not _result_context.is_empty()
	var danger_result: bool = _is_danger_result()
	_home.visible = _is_result_dialog()
	_home.disabled = _paused
	_home.text = "Home"
	_back.text = "Play again" if result_mode else "Back"
	_result_score.visible = result_mode
	_result_score.scale = Vector2.ONE
	_progress.visible = not result_mode
	_result_caption.visible = result_mode and (_cards.is_empty() or failed)
	_sync_companion()
	var campaign: Dictionary = _result_context.get("campaign", {})
	var campaign_result: bool = campaign.get("kind", "") == "main"
	var challenge_result: bool = campaign.get("kind", "") == "challenge"
	_stage_rating.visible = campaign_result
	_challenge_record.visible = challenge_result
	_return_glow.visible = challenge_result and _challenge_return_ready
	if campaign_result or challenge_result:
		pip.hide()
	if result_mode:
		var earned_count: int = maxi(0, int(_result_context.get("chest_count", 0)))
		_heading.text = ("You earned a chest!" if earned_count == 1 else "You earned chests!") if earned_count > 0 else ("Game over" if danger_result else "Round complete")
		_result_score.text = result_summary()
		_result_caption.text = failure if failed else "No chest this round"
		_result_caption.add_theme_color_override("font_color", Style.WRONG if failed else Style.MUTED)
		if challenge_result:
			var summary: Dictionary = _result_context.get("challenge_result", {})
			var reached: int = int(summary.get("stage", campaign.get("challenge_stage", 1)))
			_heading.text = "New best!" if _challenge_return_ready and summary.get("new_best", false) else "Challenge over"
			_result_score.text = "Reached Stage %d · %d collected" % [reached, int(summary.get("collection_count", campaign.get("collection_count", 0)))]
			_challenge_record.reduced_motion = reduced_motion
			_challenge_record.set_record(int(summary.get("best", reached)))
			_result_caption.text = failure if failed else "Your record is saved." if _challenge_return_ready else "Saving your results..."
			_result_caption.visible = _cards.is_empty() or failed
		if campaign_result:
			var rating: int = int(campaign.get("stars", 0))
			_heading.text = "Stage %d cleared!" % int(campaign.number) if rating > 0 else "Time's up" \
				if campaign.get("outcome") == "timeout" else "Try again"
			if _result_context.get("boss", {}).get("outcome") == "ambushed":
				_heading.text = "The chase begins!"
			var quote: Dictionary = _result_context.get("stage_bonus", {})
			var quoted: bool = bool(quote.get("ok", false))
			_result_score.text = ("%d stars  ·  %d ×%s = %d coins" % [rating,
				int(quote.chest_coins) + int(quote.base), str(quote.factor).trim_suffix(".0"), int(quote.total)] if quoted \
				else "%d stars  ·  Reward pending" % rating) if rating > 0 else "No clear bonus. Treasure is kept."
			_stage_bonus_label.text = ("+%d\nclear coins" % int(quote.bonus) if quoted else "Reward\npending") \
				if rating > 0 else "No clear\nbonus"
			for index in range(3):
				_stage_stars[index].modulate = Color.WHITE if index < rating else Color(0.4, 0.46, 0.42, 0.40)
			if _cards.is_empty() and not failed:
				_result_caption.text = "Saving your stars and returning to the map..."
				if int(_result_context.get("merged_level_unlocked", 0)) > 0:
					_result_caption.text = "New merged Lv%d! Saving..." % int(_result_context.merged_level_unlocked)
				elif _result_context.get("boss", {}).get("outcome") == "ambushed":
					_result_caption.text = "The chase begins. Find Bramble at stage %d!" % BossCatalog.STAGES[0]
				_result_caption.visible = true
		if _result_context.has("campaign"):
			_back.visible = challenge_result and _challenge_return_ready
			_back.text = "Back to map" if challenge_result else _back.text
			_back.disabled = _paused or failed or not _challenge_return_ready
			_home.visible = challenge_result and _challenge_return_ready
			_home.text = "Try again" if challenge_result else "Home"
			_home.disabled = _back.disabled
		_result_score.accessibility_name = "Score: %d. %s" % [maxi(0, int(_result_context.get("score", 0))), _result_score.text]
		var tier: int = maxi(0, int(_result_context.get("chest_tier", 0)))
		var is_pop: bool = _result_context.has("hits")
		var completed: int = maxi(0, int(_result_context.get("hits" if is_pop else "cleared_pairs", 0)))
		var words: String = ("word popped" if completed == 1 else "words popped") if is_pop else ("word completed" if completed == 1 else "words completed")
		_progress.text = "%d %s" % [completed, words] if is_pop or completed != int(_result_context.get("score", 0)) else words
		if tier <= 0:
			_progress.text += "\nNo chest this round"
	else:
		_heading.text = JellyRewardProgress.title_for_tier(int(_cards[0].tier)) if state.chest_count == 1 and not _cards.is_empty() and int(_cards[0].tier) > 0 else "Your treasure"
		_progress.text = "%d / %d opened" % [state.opened_count, state.chest_count]
	var pages: int = _page_count()
	_previous_page.visible = pages > 1
	_next_page.visible = pages > 1
	_page_label.visible = pages > 1
	_previous_page.disabled = _paused or _holding or _opening or _save_failed or _page_index == 0
	_next_page.disabled = _paused or _holding or _opening or _save_failed or _page_index + 1 >= pages
	_page_label.text = "%d / %d" % [_page_index + 1, pages]
	_refresh_captions()
	_pose_stage_feedback()
	_layout()
	changed.emit(snapshot())
	_queue_layout()


func _queue_layout() -> void:
	if _layout_pending or not is_inside_tree():
		return
	_layout_pending = true
	_settle_layout.call_deferred()


func _settle_layout() -> void:
	_layout_pending = false
	if not is_inside_tree():
		return
	_layout()
	# Layout queues a ScrollContainer sort. Publish after it has assigned child
	# positions and scroll limits, including when a restored room first appears.
	_publish_layout.call_deferred()


func _publish_layout() -> void:
	if is_inside_tree():
		changed.emit(snapshot())


func _layout() -> void:
	if not is_instance_valid(_back):
		return
	var s: float = Style.ui_scale(self)
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	if _is_result_dialog():
		_layout_result_dialog(s, w, h)
		return
	_reparent_pager(self)
	if _back.get_meta("result_appearance", []) != [s, false]:
		# Restore ordinary result actions after leaving a result modal, including
		# physical font and button minimums when the viewport scale changes.
		Style.action_button(_back, Style.GOOD)
		Style.action_button(_retry, Style.GOOD, true)
		_back.set_meta("result_appearance", [s, false])
	var compact: bool = h * s < 430.0
	var gap: float = 24 / s
	var margin: float = 12 / s
	var heading_height: float = (72 if compact else 80) / s
	var result_height: float = 60 / s if not _result_context.is_empty() else 0.0
	heading_height += result_height
	_heading.add_theme_font_size_override("font_size", ceili((24 if compact else 28) / s))
	_progress.add_theme_font_size_override("font_size", ceili(14 / s))
	var pager_height: float = 52 / s if _page_count() > 1 else 0.0
	var footer: float = (110 if _save_failed else 62) / s + pager_height
	_scroll.position = Vector2(margin, 8 / s)
	_scroll.size = Vector2(maxf(1, w - margin * 2), maxf(64 / s, h - footer - 8 / s))
	var count: int = maxi(1, _cards.size())
	var wide_single: bool = compact and count == 1 and w * s >= 620
	var columns: int = mini(count, 3 if w * s >= 960 else 2 if w * s >= 620 else 1)
	var card_w: float = minf((600 if wide_single else 480 if count == 1 else 360) / s, (_scroll.size.x - gap * (columns - 1)) / columns)
	var art_h: float = clampf(card_w * 0.82, 240 / s if count == 1 else 220 / s, (360 if count == 1 else 300) / s)
	var has_reward: bool = _cards.any(func(card: Dictionary) -> bool: return not card.chest_reward.is_empty())
	var hint_height: float = (CoinBreakdown.HEIGHT if has_reward else 28.0) / s
	var caption_space: float = (CoinBreakdown.HEIGHT + 16.0 if has_reward else 56.0) / s
	if compact or count == 1:
		# A single restored chest must keep its hold hint inside the modal's
		# viewport, including taller dialogs that use the regular heading size.
		art_h = maxf(128 / s, minf(art_h, _scroll.size.y - heading_height - (0.0 if wide_single else caption_space)))
	var card_h: float = art_h + (0.0 if wide_single else caption_space)
	var rows: int = ceili(float(count) / columns)
	var content_height: float = heading_height + card_h * rows + gap * (rows - 1)
	# Let the viewport own width so a desktop layout can shrink to a phone.
	_content.custom_minimum_size = Vector2(0, content_height)
	_content.size = Vector2(_scroll.size.x, maxf(content_height, _scroll.size.y))
	var left: float = (_scroll.size.x - card_w * columns - gap * (columns - 1)) * 0.5
	var top: float = maxf(0.0, (_scroll.size.y - content_height) * 0.42)
	_heading.position = Vector2(0, top)
	_heading.size = Vector2(_scroll.size.x, (40 if compact else 48) / s)
	_result_score.position = Vector2(0, top + (40 if compact else 48) / s)
	_result_score.size = Vector2(_scroll.size.x, result_height)
	_result_score.add_theme_font_size_override("font_size", ceili(44 / s))
	_progress.position = Vector2(0, top + (40 if compact else 48) / s + result_height)
	_progress.size = Vector2(_scroll.size.x, 24 / s)
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		card.hint.show()
		card.panel.position = Vector2(left + (index % columns) * (card_w + gap), top + heading_height + floori(float(index) / columns) * (card_h + gap))
		card.panel.size = Vector2(card_w, card_h)
		card.button.custom_minimum_size = Vector2(44 / s, 44 / s)
		card.art.position = Vector2.ZERO
		card.art.size = Vector2(card_w, art_h)
		card.tier_label.visible = int(card.tier) > 0 and _batch_entries().size() > 1
		card.tier_label.position = Vector2.ZERO
		card.tier_label.size = Vector2(card_w, 24 / s)
		card.tier_label.add_theme_font_size_override("font_size", ceili(14 / s))
		if card.tier_label.visible:
			card.art.position.y = 24 / s
			card.art.size.y -= 24 / s
		card.light.size = Vector2.ONE * minf(card_w, art_h * 1.15)
		card.light.position = Vector2((card_w - card.light.size.x) * 0.5, art_h * 0.55 - card.light.size.y * 0.5)
		var hint_width: float = minf(card_w, (280.0 if has_reward else 184.0) / s)
		card.hint.position = Vector2((card_w - hint_width) * 0.5, art_h + 8 / s)
		card.hint.size = Vector2(hint_width, hint_height)
		card.caption.position = Vector2.ZERO
		card.caption.add_theme_font_size_override("font_size", ceili(14 / s))
		card.caption.size = card.hint.size
		if wide_single:
			# A short landscape screen places the instruction beside the chest.
			card.art.size.x = card_w - hint_width - 20.0 / s
			card.hint.position = Vector2(card_w - hint_width, (card_h - card.hint.size.y) * 0.5)
			card.light.size = Vector2.ONE * art_h
			card.light.position = Vector2((card.art.size.x - art_h) * 0.5, art_h * 0.05)
		card.button.position = card.art.position
		card.button.size = card.art.size
		card.breakdown.position = Vector2.ZERO
		card.breakdown.size = card.hint.size
		card.breakdown._layout()
	var button_y: float = h - 54 / s
	_back.size = Vector2((132 if not _result_context.is_empty() else 104) / s, 46 / s)
	_back.position = Vector2(margin if _save_failed else w - margin - _back.size.x, button_y)
	_retry.size = Vector2(minf(208 / s, w - margin * 2 - _back.size.x - 8 / s), 46 / s)
	_retry.position = Vector2(w - margin - _retry.size.x, button_y)
	_notice.add_theme_font_size_override("font_size", ceili(14 / s))
	_notice.position = Vector2(margin, button_y - pager_height - 48 / s)
	_notice.size = Vector2(w - margin * 2, 44 / s)
	var page_gap: float = 8 / s
	var page_button_width: float = minf(130 / s, maxf(44 / s, (w - margin * 2 - 80 / s - page_gap * 2) * 0.5))
	page_button_width = maxf(page_button_width, maxf(_previous_page.get_combined_minimum_size().x,
		_next_page.get_combined_minimum_size().x))
	_previous_page.position = Vector2(margin, button_y - pager_height)
	_previous_page.size = Vector2(page_button_width, 44 / s)
	_next_page.position = Vector2(w - margin - page_button_width, button_y - pager_height)
	_next_page.size = Vector2(page_button_width, 44 / s)
	_page_label.position = Vector2(margin + page_button_width + page_gap, button_y - pager_height)
	_page_label.size = Vector2(maxf(1.0, w - margin * 2 - page_button_width * 2 - page_gap * 2), 44 / s)
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", ceili(16 / s))
	_refresh_captions()
	_update_navigation(columns)


func _layout_result_dialog(s: float, w: float, h: float) -> void:
	var challenge_result: bool = _result_context.get("campaign", {}).get("kind") == "challenge"
	var appearance: Array = [s, true, challenge_result]
	if _back.get_meta("result_appearance", []) != appearance:
		Style.action_button(_back, Style.GOOD, not challenge_result)
		Style.action_button(_home, Style.GOOD, challenge_result)
		Style.action_button(_retry, Style.GOOD)
		Style.action_button(_previous_page, Style.GOOD)
		Style.action_button(_next_page, Style.GOOD)
		_back.set_meta("result_appearance", appearance)
	var has_reward: bool = _cards.any(func(card: Dictionary) -> bool: return not card.chest_reward.is_empty())
	var layout: Dictionary = RewardLayout.measure(Vector2(w, h), s, not _cards.is_empty(), _save_failed, true, has_reward)
	_heading.add_theme_font_size_override("font_size", layout.heading_size)
	_result_score.add_theme_font_size_override("font_size", layout.summary_size)
	_result_caption.add_theme_font_size_override("font_size", layout.caption_size)
	for item: Array in [[_heading, "heading"], [_result_score, "summary"], [pip, "pip"],
		[_result_caption, "caption"], [_home, "home"], [_back, "replay"], [_retry, "retry"]]:
		var control: Control = item[0]
		var rect: Rect2 = layout[item[1]]
		control.custom_minimum_size = Vector2.ZERO
		control.position = rect.position
		control.size = rect.size
	_result_score.pivot_offset = _result_score.size * 0.5
	if _challenge_record.visible:
		_challenge_record.layout_badge(layout.pip, s)
	if _challenge_return_ready:
		_back.position = layout.home.position
		_back.size = layout.home.size
		_home.position = layout.replay.position
		_home.size = layout.replay.size
		_back.pivot_offset = _back.size * 0.5
		_return_glow.position = -Vector2.ONE * 12.0 / s
		_return_glow.size = _back.size + Vector2.ONE * 24.0 / s
	if _stage_rating != null and _stage_rating.visible:
		var hero: Rect2 = layout.pip
		_stage_rating.position = hero.position
		_stage_rating.size = hero.size
		var edge: float = minf(48.0 / s, minf(hero.size.x / 3.2, hero.size.y * 0.36))
		var total: float = edge * 3.0
		var top: float = maxf(0.0, (hero.size.y - edge - 56.0 / s) * 0.5)
		for index in range(3):
			_stage_stars[index].position = Vector2((hero.size.x - total) * 0.5 + index * edge, top)
			_stage_stars[index].size = Vector2.ONE * edge
			_stage_stars[index].pivot_offset = _stage_stars[index].size * 0.5
		_stage_bonus_label.add_theme_font_size_override("font_size", ceili(14.0 / s))
		_stage_bonus_label.update_minimum_size()
		_stage_bonus_label.position = Vector2(0, top + edge + 4.0 / s)
		_stage_bonus_label.size = Vector2(hero.size.x, 48.0 / s)
		_stage_bonus_label.pivot_offset = _stage_bonus_label.size * 0.5
		_pose_stage_feedback()
	var gap: float = 8 / s
	var footer_top: float = minf(_home.position.y, _retry.position.y) if _save_failed else _home.position.y
	_scroll.position = Vector2.ZERO
	_scroll.size = Vector2(w, maxf(1.0, footer_top - gap))
	var caption_rect: Rect2 = layout.caption
	var content_h: float = _scroll.size.y
	_reparent_pager(_content)
	if _page_count() > 1:
		# Earlier unopened treasure stays reachable without moving the new reward
		# away from the celebration's final pose. Only the pager extends below it.
		var margin: float = 4 / s
		var inner_w: float = maxf(1.0, w - margin * 2)
		var page_y: float = caption_rect.end.y + gap
		var page_h: float = 48 / s
		if page_y + page_h > _scroll.size.y:
			page_y = maxf(page_y, _scroll.size.y + gap)
		var page_w: float = (inner_w - 56 / s - gap * 2) * 0.5
		_previous_page.position = Vector2(margin, page_y)
		_previous_page.size = Vector2(page_w, page_h)
		_next_page.position = Vector2(w - margin - page_w, page_y)
		_next_page.size = Vector2(page_w, page_h)
		_page_label.position = Vector2(margin + page_w + gap, page_y)
		_page_label.size = Vector2(56 / s, page_h)
		_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_page_label.add_theme_font_size_override("font_size", ceili(13 / s))
		content_h = maxf(content_h, page_y + page_h + margin)
	_content.custom_minimum_size = Vector2(0, content_h)
	_content.size = Vector2(w, content_h)
	if not _cards.is_empty():
		var card: Dictionary = _cards[0]
		var chest_rect: Rect2 = layout.chest
		card.panel.position = Vector2.ZERO
		card.panel.size = _content.size
		card.art.position = chest_rect.position
		card.art.size = chest_rect.size
		card.tier_label.hide()
		card.light.size = Vector2.ONE * minf(chest_rect.size.x, chest_rect.size.y * 1.15)
		card.light.position = chest_rect.position + Vector2(chest_rect.size.x * 0.5, chest_rect.size.y * 0.60) - card.light.size * 0.5
		card.button.custom_minimum_size = Vector2(44 / s, 44 / s)
		card.button.position = card.art.position
		card.button.size = card.art.size
		card.hint.visible = not _save_failed
		card.hint.position = caption_rect.position
		card.hint.size = caption_rect.size
		card.caption.position = Vector2.ZERO
		card.caption.add_theme_font_size_override("font_size", layout.caption_size)
		card.caption.size = card.hint.size
		card.breakdown.position = Vector2.ZERO
		card.breakdown.size = card.hint.size
		card.breakdown._layout()
	_refresh_captions()
	_update_navigation(1)


func _reparent_pager(target: Control) -> void:
	for control: Control in [_previous_page, _next_page, _page_label]:
		if control.get_parent() != target:
			control.reparent(target, false)



func _ensure_chest_visible(control: Control) -> void:
	if _scroll.is_pointer_active():
		return
	_scroll.cancel_drag()
	_scroll.ensure_control_visible(control)


func _ensure_result_pager_visible(control: Control) -> void:
	if _is_result_dialog():
		_ensure_chest_visible(control)


func _update_navigation(columns: int) -> void:
	var controls: Array[Control] = navigation_controls()
	for index in range(controls.size()):
		var control: Control = controls[index]
		var previous: Control = controls[posmod(index - 1, controls.size())]
		var next: Control = controls[(index + 1) % controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
	for index in range(_cards.size()):
		var button: Button = _cards[index].button
		for direction in [Vector2i(-1, SIDE_LEFT), Vector2i(1, SIDE_RIGHT),
			Vector2i(-columns, SIDE_TOP), Vector2i(columns, SIDE_BOTTOM)]:
			var candidate: int = index + direction.x
			var horizontal: bool = direction.y in [SIDE_LEFT, SIDE_RIGHT]
			if candidate >= 0 and candidate < _cards.size() and not _cards[candidate].button.disabled \
				and (not horizontal or floori(float(index) / columns) == floori(float(candidate) / columns)):
				button.set_focus_neighbor(direction.y, button.get_path_to(_cards[candidate].button))
			elif horizontal:
				button.set_focus_neighbor(direction.y, button.get_path_to(button))


func snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []
	var actions: Array[Dictionary] = []
	for button: Button in [_home, _retry, _back]:
		if not is_instance_valid(button):
			continue
		var action_rect: Rect2 = button.get_global_rect()
		actions.append({"name": str(button.name), "text": button.text,
			"rect": [action_rect.position.x, action_rect.position.y, action_rect.size.x, action_rect.size.y],
			"visible": button.visible, "disabled": button.disabled})
	var opened: int = 0
	var batch: Array[Dictionary] = _batch_entries()
	for entry in batch:
		opened += int(entry.opened)
	for card in _cards:
		var rect: Rect2 = card.button.get_global_rect()
		var art_rect: Rect2 = card.art.get_global_rect()
		var hint_rect: Rect2 = card.hint.get_global_rect()
		entries.append({"index": card.entry_index, "reward_id": card.reward_id,
			"theme": card.theme, "type": str(Data.THEMES[card.theme].chest), "opened": card.opened,
			"tier": int(card.tier),
			"chest_reward": card.chest_reward.duplicate(true), "coin_breakdown": card.breakdown.snapshot(),
			"mode": card.art.mode, "progress": card.art.performance_progress(),
			"rainbow_visible": card.art._rainbow_light.is_visible_in_tree(),
			"phase": card.art.performance_phase(), "committed": card.art.opening_committed(),
			"disabled": card.button.disabled, "control": str(card.button.name),
			"caption": card.caption.text,
			"hint_rect": {"x": hint_rect.position.x, "y": hint_rect.position.y,
				"width": hint_rect.size.x, "height": hint_rect.size.y},
			"art_rect": {"x": art_rect.position.x, "y": art_rect.position.y,
				"width": art_rect.size.x, "height": art_rect.size.y},
			"rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}})
	var viewport_rect: Rect2 = _scroll.get_global_rect() if is_instance_valid(_scroll) else Rect2()
	var pip_rect: Rect2 = pip.get_global_rect() if is_instance_valid(pip) else Rect2()
	return {"round_id": _empty_result_id if not _empty_result_id.is_empty() else _configured_id, "chest_count": batch.size(), "opened_count": opened,
		"skill_unlock": _skill_reveal.snapshot(),
		"challenge_record": _challenge_record.snapshot(),
		"challenge_return_ready": _challenge_return_ready,
		"stage_feedback": {"phase": "record" if _challenge_record.visible and _challenge_record.feedback_active() else "skill" if _skill_reveal.visible else "bonus" if not _stage_bonus_reward.is_empty() \
			else "stars" if stage_feedback_active() else "done",
			"round_id": _stage_feedback_round, "star_elapsed": _stage_intro_elapsed,
			"bonus_elapsed": _stage_bonus_elapsed, "formula": _result_score.text \
				if int(_result_context.get("campaign", {}).get("stars", 0)) > 0 else "",
			"stars": _stage_stars.map(func(star: TextureRect) -> Dictionary:
				return {"alpha": star.modulate.a, "scale": star.scale.x})},
		"result_context": _result_context.duplicate(true), "collect_pending": _collect_pending,
		"empty_result": not _empty_result_id.is_empty(), "actions": actions,
		"score_text": str(maxi(0, int(_result_context.get("score", 0)))) if not _result_context.is_empty() else "",
		"summary_text": _result_score.text if is_instance_valid(_result_score) and not _result_context.is_empty() else "",
		"pip_visible": is_instance_valid(pip) and pip.is_visible_in_tree(),
		"pip_rect": [pip_rect.position.x, pip_rect.position.y, pip_rect.size.x, pip_rect.size.y],
		"replay_action": not _result_context.is_empty(),
		"heading": _heading.text if is_instance_valid(_heading) else "",
		"progress_text": _progress.text if is_instance_valid(_progress) else "",
		"page": _page_index, "page_count": _page_count(), "page_size": _effective_page_size(), "visible_chest_count": _cards.size(),
		"scroll_rect": {"x": viewport_rect.position.x, "y": viewport_rect.position.y,
			"width": viewport_rect.size.x, "height": viewport_rect.size.y},
		"scroll_offset": _scroll.scroll_vertical if is_instance_valid(_scroll) else 0,
		"scroll_max": _scroll._maximum() if is_instance_valid(_scroll) else 0.0,
		"chests": entries, "active": _active, "holding": _holding, "opening": _opening,
		"pending": _unsaved_index >= 0 or rewards.has_pending(),
		"save_failed": _save_failed or not _settlement_error.is_empty(),
		"error": _settlement_error if not _settlement_error.is_empty() else rewards.error if _save_failed else "", "paused": _paused}


func _exit_tree() -> void:
	pause()

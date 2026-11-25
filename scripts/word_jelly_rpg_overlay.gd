extends Control
## Dedicated Jelly World RPG Adventurer Pack & Quest Board overlay:
## Tab 1 (Pip Build): 4-stat character sheet, 3 Stances, and Boss Ascension selector.
## Tab 2 (Relics): 8 Pirate Boss relics with 1-3 equip slots and Lv1->Lv3 upgrades.
## Tab 3 (Bounties): 3 active Jelly World bounties, 12 permanent deeds, and active days.
## Tab 4 (Codex): 12 thematic Word Codex synergies powered by mastered vocabulary.

signal closed
signal stance_selected(stance_id: String)
signal relic_toggled(relic_id: String)
signal relic_upgrade_requested(relic_id: String)
signal bounty_claimed(uid: String)
signal deed_claimed(deed_id: String)
signal ascension_selected(boss_id: int, tier: int)

const Style = preload("res://scripts/ui_style.gd")
const UiClick = preload("res://scripts/ui_click.gd")
const RpgCatalog = preload("res://scripts/word_jelly_rpg_catalog.gd")
const RpgStore = preload("res://scripts/word_jelly_rpg_store.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const COIN = preload("res://assets/coins/gold-coin.png")
const STAR = preload("res://assets/images/ui/jelly-goals/star.webp")
const MEDAL = preload("res://assets/images/ui/mastery-medal.webp")

var _shade := ColorRect.new()
var _panel := Panel.new()
var _paper := ColorRect.new()
var _heading: Label
var _subline: Label
var _close_button := Button.new()
var _tabs_bar := HBoxContainer.new()
var _tab_buttons: Dictionary = {}
var _scroll := ScrollContainer.new()
var _body := VBoxContainer.new()
var _notice: Label
var _active_tab: String = "build"
var _data: Dictionary = {}
var _reduced_motion: bool = false


func _init() -> void:
	name = "JellyRpgOverlay"
	z_index = 140
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.color = Color(Style.INK, 0.50)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.name = "JellyRpgPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_panel)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.material = Style.paper_material(Style.PAPER, Color("#eaf3eb"), 0.28, 0.015)
	_panel.add_child(_paper)
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heading = Style.display_heading("Pip's Adventurer Pack", 26)
	_panel.add_child(_heading)
	_subline = Style.label("", 13)
	_subline.add_theme_color_override("font_color", Style.MUTED)
	_panel.add_child(_subline)
	_close_button.name = "RpgClose"
	_close_button.text = "Close"
	_close_button.accessibility_name = "Close Pip's Adventurer Pack"
	UiClick.bind_button(_close_button)
	_close_button.pressed.connect(close)
	_panel.add_child(_close_button)
	_tabs_bar.name = "RpgTabs"
	_panel.add_child(_tabs_bar)
	for spec: Array in [["build", "Pip Build"], ["relics", "Relics"], ["bounties", "Quests"], ["codex", "Codex"]]:
		var btn := Button.new()
		btn.name = "RpgTab_" + str(spec[0])
		btn.text = str(spec[1])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiClick.bind_button(btn)
		btn.pressed.connect(_select_tab.bind(str(spec[0])))
		_tabs_bar.add_child(btn)
		_tab_buttons[str(spec[0])] = btn
	_notice = Style.label("", 13)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_color_override("font_color", Style.WRONG)
	_panel.add_child(_notice)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_panel.add_child(_scroll)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	resized.connect(_layout)
	hide()


func open(payload: Dictionary, tab: String = "", reduced: bool = false) -> void:
	_reduced_motion = reduced
	if not tab.is_empty() and _tab_buttons.has(tab):
		_active_tab = tab
	configure(payload, reduced)
	show()
	_layout()
	_close_button.grab_focus.call_deferred()


func configure(payload: Dictionary, reduced: bool = false) -> void:
	_reduced_motion = reduced
	_data = payload.duplicate(true)
	_notice.text = str(_data.get("notice", ""))
	_notice.visible = not _notice.text.is_empty()
	var profile: Dictionary = _data.get("profile", {})
	var tokens: int = int(_data.get("boss_tokens", 0))
	var coins: int = int(_data.get("coins", 0))
	var claimable: int = int(_data.get("claimable_count", 0))
	_subline.text = "%d coins · %d Boss token%s · %d/%d relics equipped" % [
		coins, tokens, "" if tokens == 1 else "s",
		profile.get("equipped_relics", []).size(), int(profile.get("slot_capacity", 1))]
	if _tab_buttons.has("bounties"):
		_tab_buttons["bounties"].text = "Quests (%d)" % claimable if claimable > 0 else "Quests"
	_rebuild_content()
	_layout()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _select_tab(tab: String) -> void:
	if _active_tab == tab:
		return
	_active_tab = tab
	_scroll.scroll_vertical = 0
	_rebuild_content()
	_layout()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _rebuild_content() -> void:
	for child: Node in _body.get_children():
		child.queue_free()
	var s: float = Style.ui_scale(self)
	_body.add_theme_constant_override("separation", ceili(10.0 / s))
	if _active_tab == "build":
		_build_character_tab(s)
	elif _active_tab == "relics":
		_build_relics_tab(s)
	elif _active_tab == "bounties":
		_build_bounties_tab(s)
	else:
		_build_codex_tab(s)


func _card(fill: Color, border: Color, s: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = Style.card_box(fill, border, ceili(16.0 / s), maxi(1, roundi(1.2 / s)), 0.85, s)
	box.set_content_margin_all(12.0 / s)
	panel.add_theme_stylebox_override("panel", box)
	_body.add_child(panel)
	return panel


func _build_character_tab(s: float) -> void:
	var profile: Dictionary = _data.get("profile", {})
	var stats: Dictionary = profile.get("stats", {"wit": 10, "spark": 10, "tempo": 10, "fortune": 10})
	var stats_card := _card(Color("#f8f5ea"), Color("#d6dfd3"), s)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", ceili(6.0 / s))
	stats_card.add_child(stats_box)
	var header := Style.label("Pip Attributes (Lv%d · Crown ★%d)" % [int(_data.get("pip_level", 0)), int(profile.get("prestige_rank", 0))], ceili(16.0 / s))
	header.add_theme_font_override("font", Style.HEADING_FONT)
	stats_box.add_child(header)
	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", ceili(10.0 / s))
	stat_grid.add_theme_constant_override("v_separation", ceili(6.0 / s))
	stats_box.add_child(stat_grid)
	var stat_rows: Array = [
		["WIT %d" % int(stats.wit), "Boss +%d%% dmg" % roundi(float(profile.get("boss_damage_bonus", 0.0)) * 100.0), Color("#366c57")],
		["SPARK %d" % int(stats.spark), "Skill %d%% charge rate" % roundi(float(profile.get("skill_charge_scale", 1.0)) * 100.0), Color("#6d4da6")],
		["TEMPO %d" % int(stats.tempo), "Combo +%.1fs · Rescue +%.1fs" % [float(profile.get("combo_window_bonus", 0.0)), float(profile.get("danger_bonus", 0.0))], Color("#247b96")],
		["FORTUNE %d" % int(stats.fortune), "Treasure +%d%% · Coins +%d%%" % [roundi(float(profile.get("fragment_bonus", 0.0)) * 100.0), roundi(float(profile.get("clear_coin_bonus", 0.0)) * 100.0)], Color("#a36b20")]
	]
	for item: Array in stat_rows:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Style.label(str(item[0]), ceili(14.0 / s))
		title.add_theme_font_override("font", Style.HEADING_FONT)
		title.add_theme_color_override("font_color", item[2])
		var detail := Style.label(str(item[1]), ceili(11.5 / s))
		detail.add_theme_color_override("font_color", Style.MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(title)
		cell.add_child(detail)
		stat_grid.add_child(cell)

	var current_stance: String = str(profile.get("stance", "scholar"))
	var stance_heading := Style.label("Choose Adventure Stance & Active Skill (press E in battle)", ceili(14.0 / s))
	stance_heading.add_theme_font_override("font", Style.HEADING_FONT)
	_body.add_child(stance_heading)
	for stance: Dictionary in RpgCatalog.STANCES:
		var sid: String = str(stance.id)
		var selected: bool = sid == current_stance
		var card := _card(stance.tint if selected else Style.SURFACE, stance.accent if selected else Style.EDGE, s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ceili(10.0 / s))
		card.add_child(row)
		var stance_icon_path: String = str(stance.get("icon", ""))
		if not stance_icon_path.is_empty() and ResourceLoader.exists(stance_icon_path):
			var stance_icon := TextureRect.new()
			stance_icon.texture = load(stance_icon_path)
			stance_icon.custom_minimum_size = Vector2.ONE * 42.0 / s
			stance_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stance_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			stance_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(stance_icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", ceili(3.0 / s))
		var name_lbl := Style.label("%s  ·  Active: %s" % [stance.name, stance.skill_name], ceili(15.0 / s))
		name_lbl.add_theme_font_override("font", Style.HEADING_FONT)
		name_lbl.add_theme_color_override("font_color", stance.accent)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var passive_lbl := Style.label(str(stance.passive), ceili(12.0 / s))
		passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var skill_lbl := Style.label("Skill: " + str(stance.skill_desc), ceili(12.0 / s))
		skill_lbl.add_theme_color_override("font_color", Style.MUTED)
		skill_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(name_lbl)
		info.add_child(passive_lbl)
		info.add_child(skill_lbl)
		row.add_child(info)
		var btn := Button.new()
		btn.name = "SelectStance_" + sid
		btn.text = "Active" if selected else "Equip"
		btn.disabled = selected
		Style.action_button(btn, stance.accent, not selected)
		btn.custom_minimum_size = Vector2(88.0 / s, 44.0 / s)
		UiClick.bind_button(btn)
		btn.pressed.connect(func() -> void: stance_selected.emit(sid))
		row.add_child(btn)

	# Boss Ascension selector for already-defeated story Bosses
	var victories: Array = _data.get("boss_victories", [])
	if not victories.is_empty():
		var asc_title := Style.label("Pirate Boss Ascension (replay defeated Bosses for tokens & bounties)", ceili(14.0 / s))
		asc_title.add_theme_font_override("font", Style.HEADING_FONT)
		asc_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(asc_title)
		var selected_tiers: Dictionary = _data.get("selected_ascensions", {})
		var cleared_tiers: Dictionary = _data.get("boss_ascensions", {})
		for raw_id: Variant in victories:
			var bid: int = int(raw_id)
			if bid < 1 or bid > BossCatalog.STAGES.size():
				continue
			var card := _card(Style.SURFACE, Style.EDGE, s)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", ceili(8.0 / s))
			card.add_child(row)
			var lbl := Style.label("Stage %d · %s (Best: %s)" % [
				BossCatalog.STAGES[bid - 1], BossCatalog.TITLES[bid - 1],
				RpgCatalog.ascension_by_tier(int(cleared_tiers.get(str(bid), 0))).badge], ceili(13.0 / s))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(lbl)
			var cur_tier: int = int(selected_tiers.get(str(bid), 0))
			for t: int in [0, 1, 2]:
				var tier_spec: Dictionary = RpgCatalog.ascension_by_tier(t)
				var tbtn := Button.new()
				tbtn.name = "BossAsc_%d_%d" % [bid, t]
				tbtn.text = str(tier_spec.badge)
				Style.action_button(tbtn, Color("#8c4fa8") if t > 0 else Style.GOOD, cur_tier == t)
				tbtn.custom_minimum_size = Vector2(68.0 / s, 44.0 / s)
				tbtn.add_theme_font_size_override("font_size", ceili(12.0 / s))
				UiClick.bind_button(tbtn)
				tbtn.pressed.connect(func() -> void: ascension_selected.emit(bid, t))
				row.add_child(tbtn)


func _build_relics_tab(s: float) -> void:
	var profile: Dictionary = _data.get("profile", {})
	var equipped: Array = profile.get("equipped_relics", [])
	var relic_levels: Dictionary = _data.get("relic_levels", {})
	var slots: int = int(profile.get("slot_capacity", 1))
	var tokens: int = int(_data.get("boss_tokens", 0))
	var coins: int = int(_data.get("coins", 0))
	var intro := Style.label("Defeat Pirate Bosses to claim 8 Compass Relics. Equip up to %d (%d/3 slots unlocked by Bosses or Pip Lv10/25)." % [slots, slots], ceili(12.5 / s))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Style.MUTED)
	_body.add_child(intro)
	for relic: Dictionary in RpgCatalog.RELICS:
		var rid: String = str(relic.id)
		var lv: int = int(relic_levels.get(rid, 0))
		var owned: bool = lv > 0
		var is_eq: bool = equipped.has(rid)
		var card := _card(Color("#fff9ea") if is_eq else Style.SURFACE if owned else Style.SOFT,
			relic.accent if is_eq else Style.EDGE, s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ceili(10.0 / s))
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = load(str(relic.icon))
		icon.custom_minimum_size = Vector2.ONE * 40.0 / s
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color.WHITE if owned else Color(0.55, 0.58, 0.58, 0.5)
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Style.label("%s  %s" % [relic.name, "Lv%d/3" % lv if owned else "Locked (Boss Stage %d)" % int(relic.stage)], ceili(14.5 / s))
		title.add_theme_font_override("font", Style.HEADING_FONT)
		title.add_theme_color_override("font_color", relic.accent if owned else Style.MUTED)
		var desc := Style.label(str(relic.levels[maxi(0, lv - 1)]), ceili(12.0 / s))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(title)
		info.add_child(desc)
		row.add_child(info)
		if owned:
			var actions := VBoxContainer.new()
			actions.add_theme_constant_override("separation", ceili(4.0 / s))
			var eq_btn := Button.new()
			eq_btn.name = "RelicEquip_" + rid
			eq_btn.text = "Unequip" if is_eq else "Equip"
			Style.action_button(eq_btn, relic.accent, not is_eq)
			eq_btn.custom_minimum_size = Vector2(96.0 / s, 44.0 / s)
			eq_btn.add_theme_font_size_override("font_size", ceili(12.0 / s))
			UiClick.bind_button(eq_btn)
			eq_btn.pressed.connect(func() -> void: relic_toggled.emit(rid))
			actions.add_child(eq_btn)
			if lv < RpgCatalog.MAX_RELIC_LEVEL:
				var cost: Dictionary = RpgCatalog.relic_upgrade_cost(lv)
				var up_btn := Button.new()
				up_btn.name = "RelicUpgrade_" + rid
				up_btn.text = "Lv%d (%dc · %dt)" % [lv + 1, int(cost.coins), int(cost.tokens)]
				var can_buy: bool = coins >= int(cost.coins) and tokens >= int(cost.tokens)
				up_btn.disabled = not can_buy
				Style.action_button(up_btn, Color("#b57622"), can_buy)
				up_btn.custom_minimum_size = Vector2(96.0 / s, 44.0 / s)
				up_btn.add_theme_font_size_override("font_size", ceili(11.0 / s))
				UiClick.bind_button(up_btn)
				up_btn.pressed.connect(func() -> void: relic_upgrade_requested.emit(rid))
				actions.add_child(up_btn)
			row.add_child(actions)


func _build_bounties_tab(s: float) -> void:
	var rpg: Dictionary = _data.get("rpg_state", {})
	var days: int = rpg.get("active_days", []).size()
	var header_lbl := Style.label("Active Bounties (refresh on claim) · Adventure Days: %d" % days, ceili(14.0 / s))
	header_lbl.add_theme_font_override("font", Style.HEADING_FONT)
	_body.add_child(header_lbl)
	for bounty: Dictionary in rpg.get("bounties", []):
		var done: bool = int(bounty.progress) >= int(bounty.target)
		var card := _card(Color("#eef9ef") if done else Style.SURFACE, Style.GOOD if done else Style.EDGE, s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ceili(10.0 / s))
		card.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Style.label("%s  (%d / %d)" % [bounty.title, int(bounty.progress), int(bounty.target)], ceili(14.5 / s))
		title.add_theme_font_override("font", Style.HEADING_FONT)
		var reward_text: String = "+%d coins" % int(bounty.coins) + (" · +%d token" % int(bounty.tokens) if int(bounty.tokens) > 0 else "")
		var desc := Style.label("%s  ·  %s" % [bounty.desc, reward_text], ceili(12.0 / s))
		desc.add_theme_color_override("font_color", Style.MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(title)
		info.add_child(desc)
		row.add_child(info)
		var btn := Button.new()
		btn.name = "ClaimBounty_" + str(bounty.uid)
		btn.text = "Claim" if done else "Active"
		btn.disabled = not done
		Style.action_button(btn, Style.GOOD, done)
		btn.custom_minimum_size = Vector2(88.0 / s, 44.0 / s)
		UiClick.bind_button(btn)
		btn.pressed.connect(func() -> void: bounty_claimed.emit(str(bounty.uid)))
		row.add_child(btn)

	var deeds_lbl := Style.label("Jelly World Adventure Deeds", ceili(14.0 / s))
	deeds_lbl.add_theme_font_override("font", Style.HEADING_FONT)
	_body.add_child(deeds_lbl)
	var claimed_deeds: Array = rpg.get("claimed_deeds", [])
	var deeds_progress: Dictionary = _data.get("deed_progress", {})
	for deed: Dictionary in RpgStore.DEEDS:
		var did: String = str(deed.id)
		var claimed: bool = claimed_deeds.has(did)
		var prog: int = int(deeds_progress.get(did, 0))
		var target: int = int(deed.target)
		var done: bool = prog >= target and not claimed
		var card := _card(Color("#f4faf3") if done else Style.SOFT if claimed else Style.SURFACE,
			Style.GOOD if done else Style.EDGE, s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ceili(8.0 / s))
		card.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Style.label("%s (%d / %d)" % [deed.title, mini(prog, target), target], ceili(13.5 / s))
		title.add_theme_font_override("font", Style.HEADING_FONT)
		var rtxt: String = "+%d coins" % int(deed.coins) + (" · +%d token" % int(deed.tokens) if int(deed.tokens) > 0 else "")
		var desc := Style.label("%s · %s" % [deed.desc, rtxt], ceili(11.5 / s))
		desc.add_theme_color_override("font_color", Style.MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(title)
		info.add_child(desc)
		row.add_child(info)
		var btn := Button.new()
		btn.name = "ClaimDeed_" + did
		btn.text = "Done" if claimed else "Claim" if done else "Locked"
		btn.disabled = not done
		Style.action_button(btn, Color("#b57622") if done else Style.GOOD, done)
		btn.custom_minimum_size = Vector2(84.0 / s, 44.0 / s)
		UiClick.bind_button(btn)
		btn.pressed.connect(func() -> void: deed_claimed.emit(did))
		row.add_child(btn)


func _build_codex_tab(s: float) -> void:
	var profile: Dictionary = _data.get("profile", {})
	var codex: Dictionary = profile.get("codex", {})
	var intro := Style.label("Master words across 12 themes to awaken permanent Jelly World bonuses (%d / %d ★). Collecting a Mastered word also deals +15%% Boss damage & +5%% Skill charge!" % [
		int(codex.get("stars", 0)), int(codex.get("max_stars", 36))], ceili(12.5 / s))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Style.MUTED)
	_body.add_child(intro)
	for theme: Dictionary in codex.get("themes", []):
		var stars: int = int(theme.stars)
		var card := _card(Color("#fff9ea") if stars >= 3 else Style.SURFACE,
			Color("#cfab65") if stars >= 3 else Style.EDGE, s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ceili(8.0 / s))
		card.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var star_marks: String = "★".repeat(stars) + "☆".repeat(3 - stars)
		var title := Style.label("%s  %s  (%d/%d)" % [theme.name, star_marks, int(theme.mastered), int(theme.total)], ceili(14.0 / s))
		title.add_theme_font_override("font", Style.HEADING_FONT)
		var bonus_str: String = "25% -> 1★ · 60% -> 2★ · 100% -> 3★"
		if stars > 0:
			var val: float = float(theme.value)
			var stat_key: String = str(theme.stat)
			bonus_str = "Active: %s +%s" % [theme.label, ("%.1fs" % val) if stat_key in ["combo_window", "danger_bonus"] else ("%d%%" % roundi(val * 100.0))]
		var desc := Style.label(bonus_str, ceili(12.0 / s))
		desc.add_theme_color_override("font_color", Style.GOOD if stars > 0 else Style.MUTED)
		info.add_child(title)
		info.add_child(desc)
		row.add_child(info)


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s: float = Style.ui_scale(self)
	var pad: float = 16.0 / s
	var panel_w: float = minf(680.0 / s, maxf(240.0 / s, size.x - 28.0 / s))
	var panel_h: float = minf(640.0 / s, maxf(240.0 / s, size.y - 28.0 / s))
	_panel.size = Vector2(panel_w, panel_h)
	_panel.position = (size - _panel.size) * 0.5
	_panel.add_theme_stylebox_override("panel", Style.parchment_panel(s, 14.0, 12.0))
	Style.action_button(_close_button, Style.GOOD)
	_close_button.size = Vector2(84.0 / s, 44.0 / s)
	_close_button.position = Vector2(panel_w - pad - _close_button.size.x, pad)
	_heading.position = Vector2(pad, pad)
	_heading.size = Vector2(maxf(1.0, _close_button.position.x - pad * 1.5), 34.0 / s)
	_heading.add_theme_font_size_override("font_size", ceili((20.0 if panel_w * s < 440.0 else 25.0) / s))
	_subline.position = Vector2(pad, pad + 34.0 / s)
	_subline.size = Vector2(panel_w - pad * 2.0, 20.0 / s)
	_subline.add_theme_font_size_override("font_size", ceili(12.5 / s))
	_tabs_bar.position = Vector2(pad, pad + 60.0 / s)
	_tabs_bar.size = Vector2(panel_w - pad * 2.0, 44.0 / s)
	_tabs_bar.add_theme_constant_override("separation", ceili(6.0 / s))
	for tab_id: String in _tab_buttons:
		var btn: Button = _tab_buttons[tab_id]
		Style.action_button(btn, Style.GOOD, tab_id == _active_tab)
		btn.custom_minimum_size = Vector2(0, 44.0 / s)
		btn.add_theme_font_size_override("font_size", ceili(13.0 / s))
	var top_y: float = _tabs_bar.position.y + _tabs_bar.size.y + 8.0 / s
	if _notice.visible:
		_notice.position = Vector2(pad, top_y)
		_notice.size = Vector2(panel_w - pad * 2.0, 26.0 / s)
		_notice.add_theme_font_size_override("font_size", ceili(12.5 / s))
		top_y += 30.0 / s
	_scroll.position = Vector2(pad, top_y)
	_scroll.size = Vector2(panel_w - pad * 2.0, maxf(40.0 / s, panel_h - top_y - pad))


func snapshot() -> Dictionary:
	return {
		"visible": is_visible_in_tree(),
		"tab": _active_tab,
		"notice": _notice.text,
		"subline": _subline.text
	}

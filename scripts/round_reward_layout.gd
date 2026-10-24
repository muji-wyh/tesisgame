extends RefCounted
## Shared geometry keeps Pip and the real chest still when celebration ends.

const HEADING_FONT = preload("res://assets/fonts/heading.tres")
const CoinBreakdown = preload("res://scripts/chest_coin_breakdown.gd")


static func measure(bounds: Vector2, scale_factor: float, has_chest: bool, save_failed: bool = false, has_summary: bool = false, has_reward: bool = false) -> Dictionary:
	var s: float = maxf(0.25, scale_factor)
	var w: float = bounds.x * s
	var h: float = bounds.y * s
	var margin: float = 4.0
	var gap: float = 8.0
	var action_h: float = 48.0
	var inner_w: float = maxf(1.0, w - margin * 2.0)
	var action_y: float = h - margin - action_h
	var wide_actions: bool = w >= 420.0
	var action_count: int = 3 if save_failed and wide_actions else 2
	var action_w: float = (inner_w - gap * (action_count - 1)) / action_count
	var home := Rect2(margin, action_y, action_w, action_h)
	var replay := Rect2(w - margin - action_w, action_y, action_w, action_h)
	var retry := Rect2()
	var stage_bottom: float = action_y - gap
	if save_failed:
		if wide_actions:
			retry = Rect2(margin + action_w + gap, action_y, action_w, action_h)
		else:
			stage_bottom -= action_h
			retry = Rect2(margin, stage_bottom, inner_w, action_h)
			stage_bottom -= gap
	var compact: bool = h < 350.0
	var heading_size: int = ceili((24.0 if compact else 28.0) / s)
	var title_h: float = maxf(36.0 if compact else 44.0, ceilf(HEADING_FONT.get_height(heading_size) * s))
	var summary_h: float = 24.0 if has_summary else 0.0
	var caption_h: float = CoinBreakdown.HEIGHT if has_chest and has_reward else 46.0 if save_failed else 32.0
	var available_hero_h: float = maxf(0.0, stage_bottom - margin - title_h - summary_h - caption_h - gap * 2.0)
	# Keep the title, companions and instruction together instead of stretching
	# the artwork's transparent stage across the full height of the dialog.
	var hero_h: float = minf(available_hero_h, minf(inner_w * 0.72, 280.0))
	var content_h: float = title_h + summary_h + gap + hero_h + gap + caption_h
	var content_top: float = margin + maxf(0.0, stage_bottom - margin - content_h) * 0.35
	var heading := Rect2(margin, content_top, inner_w, title_h)
	var summary := Rect2(margin, heading.end.y, inner_w, summary_h)
	var hero_top: float = summary.end.y + gap
	var caption := Rect2(margin, hero_top + hero_h + gap, inner_w, caption_h)
	var chest_w: float = minf(inner_w * 0.60, hero_h * 1.2)
	var pip_side: float = minf(hero_h, inner_w * (0.40 if has_chest else 0.72))
	var group_w: float = pip_side + chest_w if has_chest else pip_side
	var left: float = (w - group_w) * 0.5
	var pip := Rect2(left, hero_top + (hero_h - pip_side) * 0.5, pip_side, pip_side)
	var chest := Rect2(left + pip_side, hero_top, chest_w, hero_h)
	var center_side: float = minf(hero_h, pip_side * 1.28) if has_chest else pip_side
	var pip_center := Rect2((w - center_side) * 0.5, hero_top + (hero_h - center_side) * 0.5, center_side, center_side)
	var result: Dictionary = {"heading": heading, "summary": summary, "caption": caption, "pip": pip, "pip_center": pip_center, "chest": chest,
		"home": home, "replay": replay, "retry": retry}
	for key: String in result:
		var rect: Rect2 = result[key]
		result[key] = Rect2(rect.position / s, rect.size / s)
	result["compact"] = compact
	result["heading_size"] = heading_size
	result["caption_size"] = ceili((14.0 if compact else 16.0) / s)
	result["summary_size"] = ceili(14.0 / s)
	return result

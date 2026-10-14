extends RefCounted
## Shared geometry keeps Pip and the real chest still when celebration ends.


static func measure(bounds: Vector2, scale_factor: float, has_chest: bool, save_failed: bool = false) -> Dictionary:
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
	var title_h: float = 32.0 if compact else 54.0
	var caption_h: float = 46.0 if save_failed else 32.0
	var heading := Rect2(margin, margin, inner_w, title_h)
	var caption := Rect2(margin, stage_bottom - caption_h, inner_w, caption_h)
	var hero_top: float = heading.end.y + gap
	var hero_h: float = maxf(0.0, caption.position.y - gap - hero_top)
	var chest_w: float = minf(inner_w * 0.60, hero_h * 1.2)
	var pip_side: float = minf(hero_h, inner_w * (0.40 if has_chest else 0.72))
	var group_w: float = pip_side + chest_w if has_chest else pip_side
	var left: float = (w - group_w) * 0.5
	var pip := Rect2(left, hero_top + (hero_h - pip_side) * 0.5, pip_side, pip_side)
	var chest := Rect2(left + pip_side, hero_top, chest_w, hero_h)
	var result: Dictionary = {"heading": heading, "caption": caption, "pip": pip, "chest": chest,
		"home": home, "replay": replay, "retry": retry}
	for key: String in result:
		var rect: Rect2 = result[key]
		result[key] = Rect2(rect.position / s, rect.size / s)
	result["compact"] = compact
	result["heading_size"] = ceili((24.0 if compact else 38.0) / s)
	result["caption_size"] = ceili((13.0 if compact else 16.0) / s)
	return result

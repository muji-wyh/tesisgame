extends Control
## Displays the immutable reward quote supplied by the chest's owner.

const Style = preload("res://scripts/ui_style.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const HEIGHT: float = 56.0

var detail: Label
var total: Label
var _reward: Dictionary = {}


func _init() -> void:
	name = "ChestCoinBreakdown"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	detail = Style.label("", 14)
	detail.name = "ChestCoinDetail"
	detail.add_theme_color_override("font_color", Style.MUTED)
	total = Style.label("", 18)
	total.name = "ChestCoinTotal"
	total.add_theme_font_override("font", Style.HEADING_FONT)
	total.add_theme_color_override("font_color", Style.GOOD)
	for label: Label in [detail, total]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		add_child(label)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func set_reward(quote: Dictionary) -> void:
	_reward = quote.duplicate(true)
	detail.text = ""
	if not quote.is_empty():
		detail.text = "Previously saved chest reward" if str(quote.get("policy", "")) == Economy.LEGACY_CHEST_REWARD_POLICY else \
			"Chest %d + Pip Lv%d bonus %d" % [int(quote.get("base", 0)), int(quote.get("pip_level", 0)), int(quote.get("bonus", 0))]
	total.text = "Total %d coins" % int(quote.get("total", 0)) if not quote.is_empty() else ""
	set("accessibility_name", description(quote))
	_layout()


static func description(quote: Dictionary) -> String:
	if quote.is_empty():
		return ""
	if str(quote.get("policy", "")) == Economy.LEGACY_CHEST_REWARD_POLICY:
		return "Previously saved chest reward. Total: %d coins." % int(quote.get("total", 0))
	return "Chest: %d coins. Pip level %d bonus: %d coins. Total: %d coins." % [int(quote.get("base", 0)),
		int(quote.get("pip_level", 0)), int(quote.get("bonus", 0)), int(quote.get("total", 0))]


func _layout() -> void:
	if not is_instance_valid(total) or size.x <= 0.0:
		return
	var s: float = maxf(0.25, Style.ui_scale(self))
	var detail_size: int = ceili(14.0 / s)
	var minimum_size: int = ceili(11.0 / s)
	var font: Font = detail.get_theme_font("font")
	while detail_size > minimum_size and font.get_string_size(detail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_size).x > size.x:
		detail_size -= 1
	detail.add_theme_font_size_override("font_size", detail_size)
	total.add_theme_font_size_override("font_size", ceili(18.0 / s))
	detail.position = Vector2.ZERO
	detail.size = Vector2(size.x, minf(size.y, 25.0 / s))
	total.position = Vector2(0, detail.size.y)
	total.size = Vector2(size.x, maxf(0.0, size.y - detail.size.y))


func snapshot() -> Dictionary:
	var rect: Rect2 = get_global_rect()
	return {"visible": is_visible_in_tree(), "reward": _reward.duplicate(true),
		"detail_text": detail.text, "total_text": total.text,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}

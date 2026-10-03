extends "res://scripts/result_scroll.gd"
## Horizontal rails share pointer ownership and momentum with vertical lists.


func _init() -> void:
	super()
	horizontal = true
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

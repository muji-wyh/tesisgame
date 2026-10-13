extends "res://scripts/priced_icon_button.gd"
## Preserve Memory's hold-to-reveal instruction beside its escalating price.


func _price_description() -> String:
	return "Hold to reveal all cards. Release to hide unmatched cards. " + ("Next reveal is free." if cost == 0 else "Next reveal costs %d coins." % cost)

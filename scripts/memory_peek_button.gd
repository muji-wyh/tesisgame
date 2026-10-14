extends "res://scripts/priced_icon_button.gd"
## Keep the timed reveal instruction beside its escalating price.


func _price_description() -> String:
	return "Click to reveal all cards for %d seconds. " % (10 if cost == 0 else 5) + ("First reveal is free." if cost == 0 else "Next reveal costs %d coins." % cost)

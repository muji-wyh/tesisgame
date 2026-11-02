extends SceneTree

const Page = preload("res://scripts/word_jelly_upgrades.gd")
const Preview = preload("res://scripts/word_jelly_ability_preview.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
var checks := 0
var failures := 0
var word: Dictionary = {"id": "cat", "text": "cat", "image": "res://assets/images/ui/modes/cat.webp"}


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func capture_ui(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-upgrades")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/qa/jelly-upgrades/" + name + ".png") == OK,
		"Capture the actual " + name)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var page := Page.new()
	root.add_child(page)
	page.size = Vector2(root.size)
	var state: Dictionary = {"level": 1, "pending": {}, "intro": "guide",
		"balance": 50, "error": "", "busy": false, "paid": false}
	check(page.present(state, word, false), "The shop previews the actual acquired cat and Jelly artwork")
	var purchases: Array[int] = []
	var purchase_kinds: Array[String] = []
	page.purchase_requested.connect(func(level: int, kind: String) -> void:
		purchases.append(level)
		purchase_kinds.append(kind))
	var counts: Array[int] = [2, 4, 6, 8, 7, 13, 12, 22, 55]
	for level in range(1, 10):
		page.select_level(level)
		var actual: Dictionary = page.snapshot()
		check(actual.preview.level == level and actual.preview.target_count == counts[level - 1],
			"Lv%d previews the exact real seven-by-eight campaign ability" % level)
		check(actual.preview.columns == Model.COLUMNS and actual.preview.rows == Model.ROWS
			and actual.preview.targets.all(func(target: Dictionary) -> bool:
				return target.column >= 0 and target.column < 7 and target.row >= 0 and target.row < 8),
			"Every inspected ability uses actual in-bounds board cells")
		if level == 5:
			check(actual.preview.targets.all(func(target: Dictionary) -> bool:
				return target.column == actual.preview.origin[0]), "Column preview reaches all seven other rows")
		if level == 6:
			check(actual.preview.targets.all(func(target: Dictionary) -> bool:
				return target.column == actual.preview.origin[0] or target.row == actual.preview.origin[1]),
				"Cross preview reaches the actual full row and column")
		check(actual.level == 1 and actual.balance == 50 and purchases.is_empty(),
			"Inspecting a locked level cannot grant it, spend coins or emit a purchase")
		check(actual.buy.enabled == (level == 2),
			"Only the next affordable permanent level is purchasable")
		await capture_ui("ability-lv%d" % level)
	for dimensions: Vector2i in [Vector2i(320, 480), Vector2i(390, 664), Vector2i(393, 852),
			Vector2i(844, 390), Vector2i(1366, 900)]:
		root.size = dimensions
		page.size = Vector2(dimensions)
		await process_frame
		page._layout()
		var bounds := Rect2(Vector2.ZERO, page.size)
		check(bounds.grow(0.1).encloses(page._footer.get_rect())
			and bounds.grow(0.1).encloses(page._scroll.get_rect())
			and not page._footer.get_rect().intersects(page._scroll.get_rect()),
			"Fixed purchase and scrollable previews remain separate at %s" % dimensions)
		check(page._buy.size.y * page.Style.ui_scale(page) >= 44.0 - 0.1,
			"The upgrade has a full purchase touch target")
		check(not page._back.get_rect().intersects(page._heading.get_rect())
			and not page._heading.get_rect().intersects(page._wallet_icon.get_rect()),
			"Back, page title and saved coins keep distinct header space")
		for category: Button in page._category_buttons.values():
			check(category.size.y * page.Style.ui_scale(page) >= 44.0 - 0.1
				and bounds.grow(0.1).encloses(category.get_global_rect())
				and not category.get_global_rect().intersects(page._scroll.get_global_rect()),
				"Both upgrade categories have separate full-size targets above the scrollable choices")
		for tab: Dictionary in page._tabs:
			check(Rect2(Vector2.ZERO, page._levels.size).grow(0.1).encloses(tab.button.get_rect())
				and tab.button.size.y * page.Style.ui_scale(page) >= 44.0 - 0.1,
				"All nine preview choices remain reachable and fully sized")
	page.select_level(2)
	check(page.snapshot().buy.guided and page.snapshot().buy.enabled
		and page.default_focus() == page._buy, "The first-use experience points to the actual fifty-coin Lv2 action")
	page._buy.pressed.emit()
	check(purchases == [2] and page.snapshot().level == 1,
		"The FRE emits one explicit Lv2 request and never pretends the host saved it")
	state.balance = 25
	page.configure(state)
	check(not page.snapshot().buy.enabled and page.snapshot().notice.contains("25"),
		"Insufficient funds show the exact shortfall without purchasing")
	state.balance = 0
	state.pending = {"level": 2, "price": 50, "id": "jelly-level-v1:2"}
	state.paid = true
	page.configure(state)
	check(page.snapshot().buy.enabled and page.snapshot().notice.contains("not be charged again"),
		"A paid-but-uncommitted upgrade can finish even with no remaining coins")
	page.set_reduced_motion(true)
	var elapsed: float = page.snapshot().preview.elapsed
	page.advance(0.1)
	check(page.snapshot().preview.elapsed == elapsed and page.snapshot().preview.reduced_motion,
		"Reduced motion keeps the real ability footprint without a moving demonstration")
	state.level = 2
	state.pending = {}
	state.paid = false
	state.intro = "complete"
	page.configure(state)
	check(not page.snapshot().buy.enabled and not page.snapshot().buy.guided
		and page.snapshot().buy.text == "Unlocked", "Only a committed host response ends the purchase FRE")
	state.balance = 150
	state.auto_merge_level = 1
	page.configure(state)
	page.select_upgrade("auto_merge")
	check(page.snapshot().kind == "auto_merge" and page.snapshot().owned_level == 1
		and page.snapshot().level == 2 and not page.snapshot().buy.guided,
		"Auto merge has its own free Lv1 without changing Jelly ownership or inheriting its FRE")
	for level in range(1, 10):
		page.select_level(level)
		var actual: Dictionary = page.snapshot()
		check(actual.preview.kind == "auto_merge" and actual.preview.capacity == level + 2
			and actual.preview.description.contains(str(level + 2)),
			"Every Auto merge preview states the exact same capacity as real play")
		check(actual.buy.enabled == (level == 2) and purchases == [2] and purchase_kinds == ["jelly"],
			"Inspecting Auto merge levels cannot buy, skip or reuse a Jelly request")
		await capture_ui("auto-merge-lv%d" % level)
	page.select_level(2)
	page._buy.pressed.emit()
	check(purchases == [2, 2] and purchase_kinds == ["jelly", "auto_merge"]
		and page.snapshot().auto_merge_level == 1,
		"The real purchase target names Auto merge and never pretends that a request is a saved upgrade")
	state.balance = 0
	state.pending = {"kind": "auto_merge", "level": 2, "price": 50, "id": "auto-merge-level-v1:2"}
	state.paid = true
	page.configure(state)
	check(page.snapshot().buy.enabled and page.snapshot().notice.contains("not be charged again"),
		"A paid Auto merge intent can finish without any remaining coins")
	page.select_upgrade("jelly")
	check(not page.snapshot().buy.enabled and page.snapshot().notice.contains("Auto merge"),
		"The other track cannot spend the pending Auto merge receipt")
	page.select_upgrade("auto_merge")
	state.auto_merge_level = 2
	state.pending = {}
	state.paid = false
	page.configure(state)
	check(page.snapshot().owned_level == 2 and not page.snapshot().buy.enabled
		and page.snapshot().level == 2, "The saved capacity upgrade changes only Auto merge ownership")
	for dimensions: Vector2i in [Vector2i(320, 480), Vector2i(393, 852), Vector2i(844, 390), Vector2i(1366, 900)]:
		root.size = dimensions
		page.size = Vector2(dimensions)
		await process_frame
		page._layout()
		check(not page._description.get_rect().intersects(page._benefits.get_rect())
			and Rect2(Vector2.ZERO, page._detail.size).grow(0.1).encloses(page._benefits.get_rect()),
			"Auto merge capacity and per-use prices stay in separate readable rows without clipping at %s" % dimensions)
		await capture_ui("auto-merge-owned-%dx%d" % [dimensions.x, dimensions.y])
	check(page.present(state, word, true, 2, true) and page.is_offer()
		and page.navigation_controls().size() == 2,
		"The first-clear modal owns only its primary upgrade route and an optional later action")
	page.set_active(false)
	check(page.navigation_controls().is_empty() and page._offer_accept.disabled,
		"Hidden or blocked application state cannot advance the introduction")
	page.free()
	print("Jelly upgrade page: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

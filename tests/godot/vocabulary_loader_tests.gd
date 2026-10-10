extends SceneTree

const Loader = preload("res://scripts/vocabulary_loader.gd")
const Catalog = preload("res://scripts/age_word_catalog.gd")
var checks: int = 0
var failures: int = 0

class Host extends RefCounted:
	var requests: Array = []
	func requestVocabulary(age: int, callback: Callable) -> void:
		requests.append({"age": age, "callback": callback})
	func reply(index: int, state: String, progress: Variant = 0.0, path: String = "", error: String = "") -> void:
		requests[index].callback.call([JSON.stringify({"age": requests[index].age, "state": state,
			"progress": progress, "path": path, "error": error})])


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var native := Loader.new()
	root.add_child(native)
	native.configure()
	check(native.process_mode == Node.PROCESS_MODE_ALWAYS, "Downloads remain observable while startup disables the parent")
	check(native.status(3).state == "idle", "Construction does not load an age")
	native.request_age(3)
	check(native.is_ready(3) and not native.is_ready(4), "Native resources need no network but still track the requested age")
	native.free()

	var loader := Loader.new()
	root.add_child(loader)
	var host := Host.new()
	var mounts: Array = []
	var ready: Array = []
	var errors: Array = []
	var progress: Array = []
	loader.age_ready.connect(func(age: int) -> void: ready.append(age))
	loader.age_failed.connect(func(age: int, message: String) -> void: errors.append([age, message]))
	loader.progress_changed.connect(func(age: int, value: float) -> void: progress.append([age, value]))
	loader.configure(host, func(path: String, replace: bool) -> bool:
		mounts.append([path, replace])
		return true)
	loader.request_age(3)
	loader.request_age(3)
	check(host.requests.size() == 1 and loader.status(3).state == "loading", "Concurrent age requests share one retained callback")
	host.reply(0, "loading", 0.6)
	host.reply(0, "loading", 0.4)
	check(loader.status(3).progress == 0.6 and not loader.is_ready(3), "Progress never regresses or grants readiness")
	var age_three_path: String = "/vocabulary-3-0123456789abcdef.pck"
	host.reply(0, "ready", 1.0, age_three_path)
	check(loader.is_ready(3) and ready == [3] and mounts == [[age_three_path, false]], "Verified resources become ready only after a non-replacing pack mount")
	host.reply(0, "ready", 1.0, age_three_path)
	loader.request_age(3)
	check(host.requests.size() == 1 and mounts.size() == 1 and ready == [3], "Duplicate ready notifications cannot remount or restart a lesson")
	loader.request_age(4)
	host.reply(1, "failed", 0.2, "", "Connection interrupted. Please try again.")
	check(loader.status(4).state == "failed" and loader.is_ready(3), "A failed future age leaves current words available")
	loader.request_age(4)
	check(host.requests.size() == 3 and loader.status(4).state == "loading", "A failed download can be retried")
	host.reply(1, "ready", 1.0, "/vocabulary-4-0123456789abcdef.pck")
	check(not loader.is_ready(4), "Callbacks from an earlier request cannot finish its retry")
	host.reply(2, "ready", 1.0, "/vocabulary-4-0123456789abcdef.pck")
	check(loader.is_ready(4), "The current retry can complete normally")
	loader.request_age(5)
	host.reply(3, "ready", 1.0, "/vocabulary-12-0123456789abcdef.pck")
	check(loader.status(5).state == "failed" and mounts.size() == 2, "Another age's path is rejected before resource mounting")
	loader.request_age(6)
	host.reply(4, "loading", -0.2)
	check(loader.status(6).state == "failed", "Malformed progress is rejected")
	loader.request_age(7)
	var previous: Callable = host.requests[5].callback
	loader.configure(host, func(_path: String, _replace: bool) -> bool: return false)
	loader.request_age(7)
	previous.call([JSON.stringify({"age": 7, "state": "ready", "progress": 1.0,
		"path": "/vocabulary-7-0123456789abcdef.pck"})])
	check(loader.status(7).state == "loading", "Reconfiguration rejects callbacks from the previous lifecycle")
	host.reply(6, "ready", 1.0, "/vocabulary-7-0123456789abcdef.pck")
	check(loader.status(7).state == "failed" and not loader.is_ready(7), "An engine mount failure remains retryable and never reports ready")
	var before: int = host.requests.size()
	loader.request_age(2)
	loader.request_age(13)
	check(host.requests.size() == before, "Invalid ages do not reach the host")
	check(not errors.is_empty() and not progress.is_empty(), "Failures and download progress are observable by the UI")
	loader.free()
	_check_shared_mounts()
	_check_catalog_loading()
	print("Vocabulary loader: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_catalog_loading() -> void:
	var catalog := Catalog.new()
	check(catalog.snapshot().visible_word_ids.is_empty(), "An unmounted catalog snapshot is safe before its controls are built")
	root.add_child(catalog)
	var band: Dictionary = {"id": "3", "name": "Age 3 words"}
	var words: Array = [{"id": "the", "text": "the", "image": "", "audio": "", "practice_modes": ["phrase"]}]
	catalog.configure(words, band, {})
	check(catalog.word_buttons.size() == 1, "A ready catalog renders its word controls")
	catalog.show_loading({"id": "4", "name": "Age 4 words"}, 99,
		{"age": 4, "state": "loading", "progress": 0.5, "path": "", "error": ""})
	check(catalog.word_buttons.is_empty() and catalog._textures.is_empty() and catalog.snapshot().visible_word_ids.is_empty(),
		"An unmounted age clears the previous cards without requesting word art")
	check(catalog.snapshot().loading_state == "loading" and catalog.snapshot().loading_progress == 0.5,
		"The catalog exposes the current age's download progress")
	check(catalog.count_label.text == "99 words" and not catalog.retry_button.visible,
		"The loading view retains the complete cohort count without presenting playable cards")
	var retries: Array = []
	catalog.retry_requested.connect(func() -> void: retries.append(true))
	catalog.show_loading({"id": "4", "name": "Age 4 words"}, 99,
		{"age": 4, "state": "failed", "progress": 0.5, "path": "", "error": "Connection interrupted."})
	check(catalog.retry_button.visible and not catalog.retry_button.disabled
		and catalog.retry_button.name == "AgeVocabularyRetry", "A failed age download provides an accessible retry control")
	catalog.retry_button.pressed.emit()
	check(retries.size() == 1, "Retry requests are delegated without changing progress or the selected age")
	catalog.configure(words, band, {})
	check(catalog.snapshot().loading_state == "ready" and catalog.snapshot().loading.is_empty()
		and catalog.word_buttons.size() == 1 and not catalog._loading_box.visible, "Successful mounting restores cards and clears stale download errors")
	catalog.free()


func _reply_paths(host: Host, index: int, paths: Array, base: String) -> void:
	host.requests[index].callback.call([JSON.stringify({"age": host.requests[index].age,
		"state": "ready", "progress": 1.0, "path": base, "paths": paths, "error": ""})])


func _check_shared_mounts() -> void:
	var shared: String = "/vocabulary-shared-3-4-0123456789abcdef.pck"
	var base_three: String = "/vocabulary-3-0123456789abcdef.pck"
	var base_four: String = "/vocabulary-4-0123456789abcdef.pck"
	var loader := Loader.new()
	root.add_child(loader)
	var host := Host.new()
	var mounts: Array = []
	var ready: Array = []
	loader.age_ready.connect(func(age: int) -> void: ready.append(age))
	var mount: Callable = func(path: String, replace: bool) -> bool:
		check(not replace, "Every shared or unique pack is mounted without replacing earlier resources")
		mounts.append(path)
		return true
	loader.configure(host, mount)
	loader.request_age(3)
	_reply_paths(host, 0, [shared, base_three], base_three)
	check(loader.is_ready(3) and mounts == [shared, base_three] and ready == [3],
		"An age mounts every dependency before announcing its resources ready")
	check(loader.status(3).paths == [shared, base_three], "Ready snapshots retain dependency-first resource paths")
	loader.request_age(4)
	_reply_paths(host, 1, [shared, base_four], base_four)
	check(loader.is_ready(4) and mounts == [shared, base_three, base_four],
		"Resources shared by two ages are mounted only once")
	loader.configure(host, mount)
	loader.request_age(3)
	_reply_paths(host, 2, [shared, base_three], base_three)
	check(loader.is_ready(3) and mounts.size() == 3, "Reconfiguration preserves already mounted resources")
	loader.free()

	loader = Loader.new()
	root.add_child(loader)
	host = Host.new()
	mounts = []
	var other: String = "/vocabulary-shared-3-5-0123456789abcdef.pck"
	var fail_next: Array = [true]
	loader.configure(host, func(path: String, _replace: bool) -> bool:
		mounts.append(path)
		if path == other and fail_next[0]:
			fail_next[0] = false
			return false
		return true)
	loader.request_age(3)
	_reply_paths(host, 0, [shared, other, base_three], base_three)
	check(loader.status(3).state == "failed" and mounts == [shared, other],
		"A dependency mount failure cannot expose a partially mounted age")
	loader.request_age(3)
	_reply_paths(host, 1, [shared, other, base_three], base_three)
	check(loader.is_ready(3) and mounts == [shared, other, other, base_three],
		"Retry skips successful mounts and retries the failed dependency before the base")
	loader.free()

	loader = Loader.new()
	root.add_child(loader)
	host = Host.new()
	mounts = []
	loader.configure(host, func(path: String, _replace: bool) -> bool:
		mounts.append(path)
		return true)
	var invalid_paths: Array = [
		["/vocabulary-shared-4-5-0123456789abcdef.pck", base_three],
		["/vocabulary-shared-3-3-4-0123456789abcdef.pck", base_three],
		["/vocabulary-shared-4-3-0123456789abcdef.pck", base_three],
		["/vocabulary-shared-03-4-0123456789abcdef.pck", base_three],
		["/vocabulary-shared-3-13-0123456789abcdef.pck", base_three],
		[shared, shared, base_three], [base_three, shared], [base_four, base_three], [shared], []]
	for paths in invalid_paths:
		loader.request_age(3)
		_reply_paths(host, host.requests.size() - 1, paths, base_three)
		check(loader.status(3).state == "failed" and mounts.is_empty(),
			"Invalid or unrelated dependencies are rejected before any resource mount")
	loader.free()

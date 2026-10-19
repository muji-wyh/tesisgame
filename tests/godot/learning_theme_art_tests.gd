extends SceneTree
## Existing licensed images are technical fixtures, not workplace art delivery.

const Art = preload("res://scripts/learning_theme_art.gd")
const Access = preload("res://scripts/professional_media_access.gd")
const Motion = preload("res://scripts/learning_theme_motion.gd")
const HASH: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

class Cache extends RefCounted:
	var texture: Texture2D
	func pin_round(_ids: Array) -> Dictionary: return {"ok": true, "lease": "fixture"}
	func get_resource(_id: String, _lease: String) -> Resource: return texture
	func release_round(_lease: String) -> void: pass

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func profile(id: String, scope: String) -> Dictionary:
	var descriptor := {"path": Access.path(scope, HASH), "sha256": HASH, "status": "integrated",
		"review": {"status": "reviewed"}, "source": "test fixture", "creator": "Kenney", "license": "CC0"}
	return {"id": id, "art": {"environment": descriptor, "props": descriptor.duplicate(true)}}


func _run() -> void:
	var cache_a := Cache.new()
	cache_a.texture = load("res://assets/images/jelly-match/garden/sky.png")
	var cache_b := Cache.new()
	cache_b.texture = load("res://assets/images/jelly-match/garden/hills.png")
	var a: String = Access.acquire(cache_a, ["sha256:" + HASH]).scope
	var b: String = Access.acquire(cache_b, ["sha256:" + HASH]).scope
	var art := Art.new()
	root.add_child(art)
	art.size = Vector2(390, 844)
	check(art.show_profile(profile("first", a), "environment", true), "Scoped reviewed environment and props are available")
	check(art.snapshot().current_images == 2 and art.snapshot().previous_images == 0 and not art.snapshot().transitioning,
		"Reduced motion presents the complete composition immediately")
	check(art._current.get_node("environment").stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"Environment presentation preserves the source aspect ratio")
	art.show_profile(profile("second", b), "environment")
	check(art.snapshot().transitioning and art.snapshot().previous_images == 2, "A changed workplace crossfades from the prior artwork")
	art.show_profile(profile("latest", a), "environment")
	check(art.snapshot().theme_id == "latest" and art.snapshot().current_images + art.snapshot().previous_images == 4,
		"Rapid changes retain no more than two complete compositions")
	await create_timer(0.3).timeout
	check(art.snapshot().theme_id == "latest" and art.snapshot().previous_images == 0 and not art.snapshot().transitioning,
		"Only the latest transition completes and it releases the outgoing references")
	var draft: Dictionary = profile("draft", b)
	draft.art.environment.review.status = "pending"
	check(not art.show_profile(draft, "environment") and not art.visible and art.snapshot().current_images == 0,
		"Unreviewed art never appears through an earlier ready theme")
	check(not art.show_profile({"id": "missing"}, "preview") and not art.visible, "Missing career previews remain missing instead of receiving placeholder art")
	var outside: Dictionary = profile("outside", a)
	outside.preview = outside.art.environment.duplicate(true)
	outside.preview.path = "res://assets/images/jelly-match/garden/sky.png"
	check(not art.show_profile(outside, "preview"), "A metadata preview cannot load arbitrary or large local art")
	var animated: Dictionary = profile("animated", a)
	animated.ambient_motion = {"status": "ready", "review": {"status": "reviewed"}, "clips": [{
		"id": "fixture", "image": animated.art.environment.duplicate(true), "columns": 2, "rows": 1,
		"frame_count": 2, "rest_frame": 1, "frames_per_second": 2.0, "rect": [0.25, 0.25, 0.5, 0.5]}]}
	check(art.show_profile(animated, "environment", true) and art.snapshot().motion_frames == [1] and not art.is_processing(),
		"Reduced motion uses the authored resting frame without a running animation")
	art.show_profile(animated, "environment", false)
	art._process(0.6)
	check(art.snapshot().motion_frames == [0] and art.is_processing(), "Authored sheet frames advance at their declared rate")
	art.size = Vector2(844, 390)
	art._layout_motion()
	var sprite: Sprite2D = art._current.get_node("ambient/fixture")
	var environment_size: Vector2 = cache_a.texture.get_size()
	var covered: Vector2 = environment_size * maxf(844.0 / environment_size.x, 390.0 / environment_size.y)
	var atlas: AtlasTexture = sprite.texture
	check((sprite.scale * atlas.region.size).is_equal_approx(covered * 0.5) and sprite.position.is_equal_approx((art.size - covered) * 0.5 + covered * 0.25),
		"Animated detail stays registered to the environment's covered crop after resize")
	check(root.gui_snap_controls_to_pixels and not sprite.centered and art.clip_contents,
		"Fractional ambient drawing keeps whole-UI pixel snapping and parent clipping")
	check(art._current.get_node("ambient").get_index() > art._current.get_node("props").get_index() and atlas.filter_clip,
		"Ambient patches preserve foreground order and restrict filtering to the selected atlas cell")
	var fractional: Dictionary = animated.duplicate(true)
	fractional.id = "fractional"
	fractional.ambient_motion.clips[0].rect = [0.4775390625, 0.345703125, 0.255859375, 0.20703125]
	art.size = Vector2(297, 301)
	check(art.show_profile(fractional, "environment", true), "A fractional authored crop loads with motion reduced")
	sprite = art._current.get_node("ambient/fixture")
	atlas = sprite.texture
	covered = environment_size * maxf(art.size.x / environment_size.x, art.size.y / environment_size.y)
	var rect: Array = fractional.ambient_motion.clips[0].rect
	var expected_position := (art.size - covered) * 0.5 + covered * Vector2(rect[0], rect[1])
	var expected_extent := covered * Vector2(rect[2], rect[3])
	check(not expected_position.is_equal_approx(expected_position.round())
		and sprite.transform.origin.is_equal_approx(expected_position)
		and (sprite.transform.basis_xform(atlas.region.size)).is_equal_approx(expected_extent),
		"The rendered Node2D transform retains subpixel placement and extent under default GUI snapping")
	check(atlas.region == Rect2(Vector2(environment_size.x * 0.5, 0), Vector2(environment_size.x * 0.5, environment_size.y)),
		"Reduced motion selects the bounded authored rest cell after a fractional layout")
	art.show_profile(animated, "environment", false)
	art.hide()
	check(not art.is_processing(), "A hidden backdrop stops its frame updates")
	art.show()
	check(art.is_processing(), "A shown backdrop resumes only when motion is allowed")
	art.show_profile(animated, "environment", true)
	check(art.snapshot().motion_frames == [1] and not art.is_processing(), "Changing reduced-motion preference immediately restores the resting frame")
	var invalid_motion: Dictionary = animated.duplicate(true)
	invalid_motion.ambient_motion.clips[0].rest_frame = 2
	check(not Motion.compile(invalid_motion, true).ok and not art.show_profile(invalid_motion, "environment"),
		"Out-of-range frames are rejected instead of sampling outside a reviewed image")
	invalid_motion = animated.duplicate(true)
	invalid_motion.ambient_motion.clips[0].rect = [0.8, 0, 0.4, 1]
	check(not Motion.compile(invalid_motion, true).ok, "Out-of-composition placements are rejected")
	invalid_motion = animated.duplicate(true)
	invalid_motion.ambient_motion.review.status = "pending"
	check(not art.show_profile(invalid_motion, "environment"), "Still-image approval alone does not approve motion timing")
	art.show_profile(animated, "environment")
	art.show_profile(profile("static-after-motion", b), "environment", true)
	check(art.snapshot().motion_frames.is_empty() and art.snapshot().current_images == 2 and art.snapshot().previous_images == 0,
		"Switching to a static composition clears every outgoing animation reference")
	art.show_profile(profile("leaving", b), "environment")
	art.clear()
	Access.release(a)
	Access.release(b)
	await create_timer(0.3).timeout
	check(art.snapshot().current_images == 0 and art.snapshot().previous_images == 0 and not art.visible,
		"Teardown cancels transitions and clears every image before media leases are released")
	check(Access.resource(Access.path(b, HASH)) == null, "A released workplace cannot be restored by a late callback")
	art.queue_free()
	await process_frame
	print("Learning theme art: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

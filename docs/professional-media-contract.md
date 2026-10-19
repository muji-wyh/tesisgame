# Professional raw media delivery

The professional delivery layer is independent of Growth's imported resources and resource packs. It does not create artwork, approve content, change voice settings, or mark draft modules ready. It loads only a selected, immutable module inventory and releases inactive decoded resources.

## Delivery files and metadata

A course module may declare `media_manifest: {path, sha256}`. `path` is a small JSON file under `res://data/professional/media-manifests/`; `sha256` hashes its exact UTF-8 file bytes. Read at most 256 KiB and call `ProfessionalMediaManifest.parse_manifest(bytes, sha256, context)` before passing its `manifest` result to the loader. The browser/build counterpart is `ProfessionalMedia.validateManifest(manifest, context)`; the caller verifies the manifest file's hash before JSON parsing.

```json
{
  "schema_version": 1,
  "course_id": "retail",
  "module_id": "module01",
  "curriculum_revision": "reviewed-content-1",
  "resources": [
    {
      "id": "sha256:<64 lowercase hexadecimal characters>",
      "sha256": "<64 lowercase hexadecimal characters>",
      "path": "professional-media/<same hash>.webp",
      "kind": "image",
      "format": "webp",
      "compressed_bytes": 25000,
      "width": 512,
      "height": 512,
      "decoded_bytes": 2097152
    }
  ]
}
```

The hash placeholders above are illustrative and fail validation. Actual manifests use measured file bytes and dimensions. Version 1 remains a single delivery bundle, capped at 32 MiB decoded. Image formats are `png`, `webp`, and `jpg`. Still-image dimensions are checked before decoding, checked again afterward, and converted to RGBA8 without mipmaps. The declared cost is exactly `width * height * 8`, conservatively allowing both CPU and GPU pixel payloads. WebP canvas and encoded image dimensions must agree; animated WebP is rejected.

### Shared bundles for larger modules

Version 2 retains the same flat, deduplicated `resources` inventory and adds
`bundles`, an array of `{id, revision, resource_ids}` records. Every flat resource
must belong to at least one bundle. A bundle contains a nonempty list of unique
resource IDs present in the flat inventory and must remain within 32 MiB decoded.
The full unique inventory remains within 10 MiB encoded and 128 MiB decoded.
Version 1 cannot declare these fields or bypass its original 32 MiB total limit.

Author stable shared groups around a canonical term's media or a theme, instead
of generating a group for every combination of career memberships. For example,
the same version of a shared term's picture/pronunciation group can appear in
Retail and Nursing. `(id, revision)` identifies exactly the same sorted member
set in every module; changed membership requires a new bundle revision and new
module curriculum revision. The release auditor, packager and runtime cache
reject conflicting definitions. Source manifest hashes still protect the exact
bytes, and existing resource hashes still protect both bytes and metadata.

Bundles may share a resource; the flat inventory lists, transfers and allocates
it once. Bundle declarations do not create archives, PCK mounts or parallel
decoders. Loading stays sequential, and only a complete module becomes active.
A valid 128 MiB inventory may still encounter retryable pressure when another
round holds resources; validation does not authorize evicting those leases or
raising the cache limit. Prefer compact reviewed delivery images so switching
has headroom. Closing a round clears its views/audio first, cancels preparation,
releases pending and active scopes, then deactivates and trims unused cache data.
Ordinary preparation/cancellation continues to preserve the recoverable old round.

Audio currently supports `kind: "audio", format: "wav"` with uncompressed PCM16. Replace image dimensions with `frames`, `channels` (1 or 2), and `sample_rate` (8000–96000 Hz); `decoded_bytes` is exactly `frames * channels * 2`. WAV chunk structure, actual frame payload, encoding, byte rate, and channel count are checked before constructing an `AudioStreamWAV`. MP3, OGG, SVG, animated media, and other codecs fail explicitly. Adding codecs requires truthful allocation accounting and decode tests. Runtime decoding does not change the approved `ava-sweet` pronunciation settings or perform audio postprocessing.

The content hash is the shared resource identity across careers. A module lists a shared resource once. Every picture, pronunciation, expression, environment, and other required runtime dependency must be in the inventory. Pass all required canonical IDs to `validate_dependencies(manifest, required_ids, context)` (JavaScript: `validateDependencies`) or the loader's optional third argument; a missing ID rejects activation. The resolver/content pipeline derives that list from every required content and theme reference. An empty inventory cannot start a round. Revision identity is `(course_id, module_id, curriculum_revision)`. Changing an inventory requires a new curriculum revision. An existing resource hash cannot change its metadata within the cache lifetime.

Native delivery uses loose files under `<native_root>/professional-media/<hash>.<format>`. In the editor the default root is the project directory; a native export defaults to the executable's directory. Browser delivery uses the same relative paths beneath the configured same-origin base URL. No professional resource pack is mounted and `ResourceLoader` is never used by this layer. Packaging must copy the required raw files as sidecars; the runtime does not manufacture or download missing native sidecars.

## Budgets and ownership

Validation enforces these upper bounds before any transfer or decode:

| Budget | Limit |
|---|---:|
| UTF-8 module manifest | 256 KiB |
| Unique resources per module | 256 |
| Entire first-use module media | 10 MiB of raw encoded file bytes |
| Each decoded delivery bundle (version 1: entire inventory) | 32 MiB |
| Unique version 2 decoded inventory | 128 MiB, subject to available cache space |
| Resident professional decoded payload plus reservations | 128 MiB |

The cache reserves missing resources before loading, pins dependencies during staging, and activates only a complete inventory. It evicts the least recently used resource that belongs to neither the active module, current staging request, nor a round lease. If protected resources leave insufficient space, it returns `budget_pressure` with `retryable: true`; it never silently raises a limit. Tests may configure a lower resident limit.

These are decoded **resource payload** budgets, not whole-process RSS limits. Engine objects, codec working memory, HTTP buffers, and bridge/base64 transfer copies are transient overhead outside that accounting. The loader fetches and decodes one resource at a time; each raw encoded transfer is independently capped and never exceeds the module's 10 MiB limit. The bridge allocates only the declared raw size and aborts an oversized stream. Image accounting includes CPU and GPU pixel copies. Native local file reads and decoding run synchronously one resource per deferred step; this foundation does not provide a worker-thread decoder or an interrupt inside an individual codec call.

Godot resources are reference-counted and shared resources must be treated as immutable. Before releasing a round lease, stop its audio, clear `AudioStreamPlayer.stream`, clear texture/image references, and drop game-owned resource references. Do not put professional resources into an unbounded static WordArt or audio cache. A consumer that retains references after releasing its lease violates the residency contract. Browser HTTP caching is managed by the browser and is separate from decoded residency; failed integrity/size responses are fetched with `cache: "reload"` on retry.

## Godot integration

```gdscript
const MediaLoader = preload("res://scripts/professional_media_loader.gd")
var media = MediaLoader.new()
add_child(media)
media.configure()
media.completed.connect(_media_completed)
var selected_generation: int = media.request_module(resolved.media_manifest, resolved.context, required_resource_ids)
```

`request_module()` returns immediately. `completed(generation, result)` reports success only after every resource is verified and decoded. Success contains `ok`, `generation`, `resource_ids`, and a frozen module identity in `context`. The caller must compare the returned generation with the current selection before activating gameplay. Selection previews can update immediately, while the last complete module stays active during loading or failure. Call `cancel()` on a superseding selection or when leaving the professional path. Stale callbacks are ignored and cannot insert or activate media.

At round creation, call `media.cache.pin_round(resource_ids)` and retain its integer `lease`. Resource lookup is `media.cache.get_resource("sha256:<hash>", lease)`, returning `Texture2D`, `AudioStreamWAV`, or `null`. With no lease, lookup is restricted to the active module. A lease continues to work for an old round after a newer module activates. Release with `media.cache.release_round(lease)` after clearing consumer references. `deactivate()` removes the active-module protection; `trim_inactive()` drops all unpinned inactive entries. `stats()` reports residency, reservations, limits, leases, and active IDs.

The integrated path-string convention for WordArt and GameAudio adapters is `professional://roundN/<sha256hex>`. The root adapter resolves the round scope to its cache weak reference and lease, then looks up the canonical `sha256:<sha256hex>` ID. This namespace must bypass `ResourceLoader.exists()` and `load()`. Preserve all existing Growth audio selection and playback behavior. Do not silently fall back to a Growth image or another pronunciation when professional lookup fails.

Failures contain `ok: false`, `retryable: true`, `code`, and an English `error`. Codes include `invalid_manifest`, `budget_pressure`, `revision_mismatch`, `identity_mismatch`, `missing_dependency`, `missing_asset`, `size_mismatch`, `hash_mismatch`, `decoded_size_mismatch`, `decode_failed`, `timeout`, `cancelled`, and `unavailable`. A changed invalid manifest requires corrected content; retryable indicates that the loading UI remains recoverable rather than that an automatic retry will fix every cause. Partial validated resources remain inactive and available for a later retry. The last complete active inventory and round leases survive loading failures.

## Authored ambient motion

An environment may include up to four reviewed sprite-sheet clips in
`theme_profile.ambient_motion.clips`. This is authored artwork, not a procedural
effect or a replacement for missing scene assets. Each clip contains `id`, an
`image` media descriptor, integer `columns` and `rows` (1-8), `frame_count`
(2 through the sheet's cell count), `rest_frame`, `frames_per_second` (0.5-24),
and a four-number `rect` within the environment: normalized x, y, width, height.
Frames are read left-to-right, then top-to-bottom. The sheet dimensions must
divide exactly into the declared grid. Transparent margins belong to the source
art. Composition review must verify the frame aspect ratio and seamless loop.

The sheet is a normal still-image resource under the existing byte, decoded
memory, hash, and lease limits. Every sheet is a mandatory manifest dependency,
including in reduced-motion mode. The loader binds it to the round's scope before
activation; a missing sheet or invalid grid rejects activation. Animation adds no
new decoder or permanent cache. `ambient_motion.status` must be `ready` and its
separate `review.status` must be `reviewed`; still-image review alone does not
approve timing, placement, or the resting presentation.

Clips remain registered to the environment's covered crop on resize. Reduced
motion displays the authored `rest_frame` immediately and stops updates. Hidden
views stop updating. A theme transition retains at most the current and outgoing
compositions; completion, replacement, and teardown clear sheet references before
round leases are released. Local career previews remain static.

This runtime contract does not itself approve theme artwork. Retail and Nursing
have separate reviewed full-theme deliveries recorded in
`docs/assets/professional-retail-theme.md` and
`docs/assets/professional-nursing-theme.md`. The remaining full theme deliveries
and their required source, motion and presentation reviews remain unfinished.

## Browser bridge

Include `web/professional-media.js` in the prepared shell, then lazily create one bridge:

```javascript
const mediaBridge = ProfessionalMedia.createProfessionalMediaBridge();
wordBuddiesHost.professionalMediaRequest = mediaBridge.professionalMediaRequest;
wordBuddiesHost.professionalMediaCancel = mediaBridge.professionalMediaCancel;
```

The request is JSON `{request_id, generation, resource}`. The callback receives JSON with matching IDs, `ok`, and on success `resource_id` plus `data_base64`. Callbacks are asynchronous to avoid reentering a running WASM call. Godot verifies the bytes again before decoding. Fetches are same-origin, reject redirects, use bounded streaming reads, verify SHA-256 with Web Crypto, and default to a 15-second timeout. A newer generation aborts older fetches. Godot also enforces a request timeout if the host fails to respond.

For deterministic tests, `fetch_override(metadata, generation, complete)` can replace the loader transport; complete with `{ok: true, bytes: PackedByteArray}` or the failure shape. It bypasses transport only: actual hashing, header validation, decoding, budget checks, and activation still run. The JavaScript bridge also accepts injected `fetch`, `crypto`, `baseURL`, and a bounded `timeoutMs`.

## Focused validation

Run `node --test tests/professional-media.test.cjs` and `node tools/run-godot.cjs --headless --path . --script res://tests/godot/professional_media_tests.gd`. Tests use existing production artwork and WAV audio for actual decoding, plus tiny generated images solely as cache fixtures. They exercise manifest/hash validation, decoded dimensions, PCM frame budgets, missing assets, corrupt responses, bounded streaming, redirects, timeout/retry, cached-corruption recovery, stale selection callbacks, shared-resource reuse, leases, inactive LRU eviction, and retryable budget pressure. No test fixture is published as curriculum artwork or reviewed content.

For version 2 groups, also run `tests/professional-media-bundles.test.cjs`,
`tests/professional-media-package.test.cjs` and the native
`tests/godot/professional_media_bundles_tests.gd`. These cover stable cross-course
membership, unique resource accounting, actual decoding above the old 32 MiB
module limit, failed-pressure registration, old-round preservation and teardown.
The recorded result and retained failed attempts are in
`docs/qa/2026-10-16-professional-media-bundles.md`.

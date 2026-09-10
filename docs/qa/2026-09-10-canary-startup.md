# Chrome Canary startup and compiled-code caching

The user corrected the earlier local/production comparison: Chrome Canary
stalls, while non-Canary Chrome does not. The following comparison uses the
installed browsers on the same machine and the same game export, rather than
assuming the bundled test browser represents Canary.

## Diagnosis

Windows Chrome 152.0.7977.83 and Canary 155.0.8049.1 both use the NVIDIA T1000
through ANGLE D3D11. Fresh headed profiles, without request interception or CPU
profiling, reproduce maximum startup tasks of 2,372 ms and 11,091 ms respectively.
Same-process reloads fall to approximately 480 ms and 330 ms. Both browsers spend
approximately 1.8 seconds compiling the same graphics shaders on their first run.

Separate phase markers and CPU profiles place Canary's additional work inside
cold WASM execution. In an isolated diagnostic launch, disabling lazy WASM
compilation moves the long interval into asynchronous module preparation. Turning
off optimizing tier-up does not remove the pause. Neither flag is a product fix;
user browser settings were not changed.

The Godot 4.7.1 loader reconstructs the fetched WASM Response twice: once to
measure download progress, then again to supply its MIME type. Constructed
Responses have no Chromium cached-metadata handler. This prevents streaming
compilation from preserving compiled code across browser restarts even though
the deployment already supplies immutable asset URLs and the correct MIME type.

## Repair and scope

The existing version-checked export patch now observes download bytes through a
drained native Response clone and passes the fetched Response through unchanged.
Initialization also retains a native clone when its MIME type is already
application/wasm. Missing or incorrect MIME types retain the compatibility
wrapper. The original response consumer owns download failures; the independent
progress reader terminates and releases its lock on success or failure.

This restores persistent WASM compilation caching. It does **not** remove
Canary's first uncached compilation cost, guarantee cache retention in private
browsing, or change Godot 4.7.1. Progress still follows 20/50/80/98%, with 100%
reserved for the actual game-ready callback.

## Browser restart experiment

The isolated experiment served identical WASM bytes with production-like cache
headers on port 4182. Each variant used a separate fresh persistent Canary
profile. The browser stayed open for 12 seconds after readiness so background
code serialization could finish, then closed completely before the second run.
No request routing or CPU profiling was enabled.

| Variant | Maximum main-thread task | Maximum chest input delay | Game revealed |
| --- | ---: | ---: | ---: |
| Original loader, first visit | 11,023 ms | 11,060 ms | 15,310 ms |
| Original loader, browser restarted | 9,160 ms | 9,224 ms | 13,449 ms |
| Repaired loader, first visit | 11,253 ms | 11,321 ms | 15,518 ms |
| Repaired loader, browser restarted | 773 ms | 733 ms | 3,666 ms |

The original profile's WASM code-cache directory contains no entries. The
repaired first run emits `wasm.SerializeModule` and creates cache entries; the
restart emits `wasm.Deserialize`, `wasm.GetNativeModuleFromCache`, and
`wasm.CompilationAfterDeserialization`. This establishes cache reuse independently
of timing. All four runs reach the game with no page errors.

Raw local evidence is under ignored `build/qa-canary-cache`. Earlier direct
channel comparisons are in `build/qa-canary-control` and
`build/qa-canary-stable-control`.

## Regression coverage

Node regressions check original-response identity, native-clone identity,
incremental byte totals, MIME fallback, download rejection propagation, and
exact template-anchor matching. The three new checks failed before the repair.

The real-engine browser regression checks the response passed to
`instantiateStreaming`: it must retain its fetched WASM URL and `basic` response
type. It failed against the previous exported loader because the URL was empty.
This checks the prerequisite for browser caching; the restart trace above proves
actual persistent-cache use.

The release build passed 20 Node export/deployment checks and 125 browser checks
across desktop Chromium, iPhone WebKit, and iPad WebKit; four Chromium-only CPU
cases were skipped on WebKit. The browser set includes real network/body
failures, storage recovery, loading input, and staged progress. The Godot export
verified 140 word pronunciations and 56 optional paths with zero failures.

Release engine: `engine-b450c3c96fc33a1d`. Game pack remains
`game-06d1f7bfbcd93d2d.pck`. HTML SHA256:
`f77b93d79de6f8fd997c09cf0f9afac66c48a88339a10bd91d7ca8166d8c0cf5`.

The final fingerprinted export was also checked in fresh persistent profiles,
resetting test-only local storage before each navigation. Stable Chrome's first
visit/restart revealed the game at 4,392/2,003 ms with maximum tasks of
2,338/207 ms. Canary's first visit/restart took 15,352/3,739 ms with maximum tasks
of 11,109/1,502 ms. Both restart traces consumed the native module cache. All
runs had zero page errors, and all five progress milestones appeared. Canary's
remaining 1,502 ms restart task occurred at 98%, not at a middle milestone.

## Source references

- [Chromium response metadata and WASM cache](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/bindings/core/v8/v8_wasm_response_extensions.cc)
- [Chromium native clone preserves metadata](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/fetch/body_stream_buffer.cc)
- [V8 15.5.25 WASM serialization](https://github.com/v8/v8/blob/15.5.25/src/wasm/wasm-serialization.cc)

V8's eager compilation hints remain experimental and cannot be enabled through
standard page compilation options. An unsupported binary hint or browser flag
is not part of this release.

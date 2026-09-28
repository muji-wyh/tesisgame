# Eight-theme chest feel — 2026-09-28

The eight worlds now share a staged physical clock with distinct pressure,
material motion and sound. Royal and Energy use derived body, lid, lock/core
and cavity layers. Crystal retains its nine source parts and gains an aligned
interior mask. Space separates its cover; Candy separates its facets in two
waves; Autumn uses a heavier hinge and landing. The other five profiles add
their own opening curves, recoil, stagger and local decoration.

The existing 1.2-second hold, three progress stars and 1.8-second opening are
retained. Contact feedback begins synchronously with the accepted press.
Canceling clears real progress and stops charge audio immediately, then returns
the physical pose over 120 ms. Reholding interrupts that return. The opening
keeps one fitting scale even after the progress badge disappears.

Browser cue observations exposed an opening that could run approximately one
frame early: the chest inherited the delta preceding the hold-to-open transition.
Hold and opening clocks now exclude that transition frame. Native focus loss
also follows the interruption path, with an unfinished hold canceled and an
already-earned opening settled silently.

The saved reward remains the transaction boundary. A success accent and reward
presentation happen only after saving succeeds. Failed saves can be retried;
background completion and new-round auto-claims are silent. Reduced motion
preserves hold progress and skips the physical opening beats. Duplicate inputs
and callbacks cannot grant a second piece.

## Assets and delivery

- Ten derived Royal/Energy PNGs total 1,657,314 bytes. The original 19 chest PNGs
  and the original manifest remain unchanged. The preparation script, source
  hashes, layer geometry and closed-composite checks are committed alongside
  the derived artwork.
- Seventy-two original procedural Foley WAVs total 1,252,096 bytes. Each theme
  has contact, charge loop, milestone, cancel, tension, unlock, release, settle
  and saved-reward clips. These are synthesized material textures, not recorded
  Foley or externally licensed recordings.
- The exported sound bank is optional and content-hashed: 282,040 bytes of
  imported samples, 239,193 bytes with Brotli. Only the selected theme is
  preloaded. Animation and rewards do not await a network resource; small local
  fallback sounds cover missing or invalid samples. Late downloads cannot replay
  missed cues.
- One charge-loop player and three rotating one-shot players bound audio
  overlap. Mute, page changes, theme changes and backgrounding stop these
  players independently of music and speech.
- The final Web export is 13.87 MB at startup, with 141 optional audio assets
  in total. `game-e622ca13c51a224b.pck` passed the startup-pack check: 200 bundled
  word pronunciations and 282 optional source/import paths verified absent.

## Automated and visual evidence

The implementation guide and reproduction commands are in
[`docs/assets/chest-feel.md`](../assets/chest-feel.md).

- Forty-one relevant native Godot suites passed across the core/flow, chest,
  theme and release-layout groups. The chest-specific coverage includes real
  input routing, short presses, drag cancellation, continuous reholding,
  controller release, saved-reward deduplication, save failure/retry, mute,
  background completion, resource failure and reduced motion.
  After the timing correction, chest reveal passed 577 assertions, chest feel
  passed 277, audio passed 500 and real-scene hold/save flow passed 105
  (1,459 chest assertions in total). The new timing cases reject a 250 ms delta
  on the same frame as a press/open; focus cases exercise actual native
  notifications rather than only calling lifecycle helpers.
- The Node asset, web-packaging, deployment, test-runner, wardrobe and audio
  contracts passed: 95 tests, no failures. Old fixture counts were updated for
  the ten added textures and optional chest audio directory.
- All nine exported-game chest cases passed in desktop Chromium, iPhone WebKit
  and iPad WebKit: normal cancel/rehold/reward, reduced motion and invalid
  optional samples. Browser tests use real Match wins, rendered chest input
  and persisted reward counts.
- Twelve browser recovery cases passed across those three profiles after
  correcting the test coordinates for the wider recovery header. Coverage
  includes unavailable reward storage, explicit retries and preserving unopened
  victory pieces across new rounds and reloads. Four additional desktop audio
  cases passed: nonblocking downloads, hidden-page recovery, theme changes and
  opening a one-shot reward while downloads remain pending. Together these are
  25 distinct passing browser cases; retries are not counted again.
- Final browser checks record transient progress through a DOM observer, avoiding
  screenshots that can outlast the complete opening on software rendering.
  Optional-download fixtures now bound response-body observation to five seconds
  and retain HTTP, lifecycle and exact playback assertions. In the theme-switch
  sample, all 66 requests returned HTTP 200; 44 bodies completed and 22 old
  Spring/Summer bodies remained unread after being held for 16.1-22.7 seconds.
  The current Space music completed and started once, without obsolete prompts.
  No explicit network failures were observed; the old body's precise browser
  cancellation behavior is not inferred from a successful header response.
- Native bounds checks cover all eight themes and six stage sizes, including
  short landscape stages. Rendered phone/tablet screenshots and same-size
  motion grids were inspected for clipping, badge overlap and fitting jumps.
  A detached source hinge fragment exposed by Space was removed from Energy's
  cavity; Summer retains that hinge in its actual lid layer.
- Eight 640 x 640, 60 fps, approximately five-second MP4s include the actual
  Godot audio mix. Each shows a short canceled press and a full opening.
  `build/chest-feel/index.html` offers theme-name and sound controls; JSON
  reports include resource hashes, cue order, media dimensions and non-silent
  audio checks. The capture reads and writes no player reward storage.
- The final desktop browser sample observed press notifications after 1.5 and
  2.8 ms, and opening-relative unlock/release/settle notifications after
  160.7/309.7/949.7 ms. Corresponding WebAudio start calls followed those three
  notifications by 5.4/64.7/4.6 ms. The release sample exceeds the 50 ms target;
  this software-rendered run does not establish device-level synchronization.
  The fixed-rate native capture emits the same beats at 133/333/950 ms with no
  early unlock or release.

Evidence is generated under ignored `build/` paths. Existing logs include
`chest-feel-regression.log`, `chest-feel-targeted.log`,
`chest-feel-theme-layout.log`, `chest-feel-node.log` and
`chest-feel-browser.log`. Final focused browser evidence is in
`chest-final-no-trace/`, `chest-final-ipad/` and `chest-bounded-final/`, with
adjacent logs. Earlier combined runs stopped at obsolete fixture counts,
coordinates or unbounded browser-body waits; the corrected affected contracts
were rerun successfully. Product code was unchanged during these last fixture
corrections; the final exported pack remains `game-e622ca13c51a224b.pck`.

## Remaining device and perception checks

The 80 ms physical response and 50 ms audible-alignment targets require real
devices. JavaScript cue timestamps and WebAudio start calls do not measure
display scanout, speaker or Bluetooth latency. Fixed-rate offline recordings
do not establish mobile frame rate.

The Windows Playwright WebKit runtime exposes no WebAudio; those passes cover
rendering, input, saved rewards and the honest sound-unavailable state. Actual
macOS Safari, Android Chrome and iPhone/iPad Safari performance and audio remain
unverified. A blinded human review of all eight motion/sound signatures also
remains to be performed; distinct parameters and waveforms alone do not prove
that listeners can identify every theme.

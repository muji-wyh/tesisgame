# Original vocabulary semantic audit

The catalog review covers all **140 words in twelve topics**. The original doll
looked like an ordinary girl, and brush could be read as a hand mirror. Doll now
has yarn hair, button eyes, soft limbs and a stitched patch. Brush is shown at an
angle with projecting bristles. Both fixes retain the existing palette and SVG
generator. Their subjects remain recognizable at 320px and 64px.

The isolated kite recording was transcribed as tight by two independent engines.
Its replacement says **"A kite."** using the existing Jenny neural voice, friendly
style and -8% rate. The generator preserves this natural phrase on regeneration.
The other 139 recordings and all stable vocabulary IDs are preserved.

## Per-word evidence

The [JSON companion](2026-09-11-catalog-semantic-audit.json) records every word's
topic, visually observed referent, image hash, recording hash, actual transcripts
and acoustic assessment. SVG hashes normalize CRLF to LF so they remain meaningful
across Windows checkouts. WAV hashes identify the exact binary recordings.

All original SVGs were rendered in twelve contact sheets and visually inspected.
Two agent reviewers separately checked the revised doll and brush at lesson and
card sizes. Unchanged pictures were compared with revision `0017bcf`, normalizing
only line endings. No other illustration changed semantically.

Actual WAV files were processed through installed Windows English dictation and
offline Whisper base.en. The decoders received no expected-word prompts, custom
vocabulary or constrained grammar. Whisper reviewed fourteen ten-word batches;
temporary 16kHz copies had 600ms silence between nouns. The source WAVs were not
processed in place. Binary/model versions and verified hashes are in the JSON.

- Whisper exactly transcribed **138 of the 140 original nouns**.
- Sun was transcribed as son, which has the same English pronunciation.
- Original kite was transcribed as tight in both engines and in a separate direct
  Whisper check. The replacement's actual source WAV yields **"A kite"** in
  Whisper, and the independent batch yields adjacent a + kite tokens.
- Windows dictation still transcribes the replacement as "But tight" with 0.0241
  confidence. Its original catalog accuracy was only 37/140, so its other errors
  were not treated as proof of bad recordings.

This is acoustic recognition evidence, **not human listening or a pronunciation
study**. The article supplies natural context and may help transcription. The
original kite clip is not claimed definitively incorrect. No global speech tools
or game dependencies were installed; offline QA tools/models remain in ignored
build storage. Synthesis used the game's existing F0 Speech resource.

Final kite WAV: PCM16 mono, 22050Hz, 0.999 seconds, SHA256
`f5df8d178072ec11aa01b6ef385d6a99c1aeef9a05b963975bb3f1256fa73fad`.

## Verification and release

The complete `npm test` run passed after the final asset changes: **25 native
suites, 12,563 checks/assertions, zero failures; 97 Node passes and one existing
unavailable-source skip**. Source code and SVG syntax checks and `git diff --check`
also passed. Independent final review found no actionable issue in the source,
140-row evidence, raw ASR boundaries, final recording or tool/model provenance.

`npm run build:web` passed with Godot 4.7.1, **10.98 MB startup transfer** and 28
optional audio assets. Browser regression passed **9/9** across desktop Chromium
and iPhone/iPad WebKit profiles: lesson continuity across modes, picture
pronunciation, correct Match discovery, save/reload and album display/navigation.

An additional isolated Chromium session used real Explore, lesson Previous/Next
and Hear controls to reach doll, brush and kite at 390x844 and 1366x768. All six
Learn screenshots were visually inspected. The expected picture/word pair and
Hear feedback appeared without page or console errors. No real browser profile
or player's saved progress was modified.

Tested export at port 4181:

- HTML SHA256: `6d05503d98b0777cab93b6bc4759490b03ff88e8435a719114dbc2d33be0ad3f`
- Pack: `game-c23c4b847597f895.pck`
- Pack SHA256: `c23c4b847597f895616556d4b0b0577b40b39cb7678bcfd357831acc5a1883f6`

Deployment verification will be recorded after the tested export is published.

Ignored detailed evidence is in `build/semantic-audit/`: original topic sheets,
two before/after comparisons, independent revised renders, raw ASR results,
model provenance, candidate/source recording hashes and the final direct-file
checks. The logs are `build/catalog-native-final.log`,
`build/catalog-build-final.log`, `build/catalog-browser-final.log` and
`build/catalog-game-inspection.log`. Browser regression screenshots are in
`build/qa-catalog/`; the six targeted Learn views and their control/status record
are in `build/semantic-audit/game/`.

## Open external requirement

This review covers original artwork. No Food Icons Pack package has been acquired,
imported through Unity CLI or shipped. Stable Chrome reached Unity sign-in; the
user's authentication remains pending. The in-app connector separately reports a
missing Codex auth token. This was not an automatic safety rejection. The actual
Unity acquisition/import/deployed-art requirement remains open in the learning
plan and [Unity provenance record](../assets/unity-art.md).

Godot remains 4.7.1. This asset change does not establish a fix for Canary's first
uncached WASM compilation stall. Physical iPhone/iPad validation remains separate
from the automated WebKit profiles.

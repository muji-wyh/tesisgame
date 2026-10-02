# Capture readiness, compound matching, and real-device speech diagnostics

## Changes under test

Match and Voice Pop share reviewed compound forms for seahorse, sunflower,
sunglasses, pinecone, and yoyo. Their legal Voice Pop plurals are explicit.
The native matcher resolves complete phrases against current eligible words;
the browser preserves occurrence identities through joined/spaced revisions.
Compound/component co-spawn exclusion and consumed-span inheritance prevent
`sea horse` from taking a horse target and prevent a consumed `cat` revised to
`sunflower` and then `flower` from awarding another hit. A genuinely new
occurrence can still score.

Capture-capable APIs keep the round waiting after service startup. Actual
`audiostart`, or an earlier nonempty valid result, starts listening. A bounded
eight-second watchdog runs only after service startup, not while permission
is pending. Older APIs keep their explicit compatibility fallback. New
capture events are protected by the same recognizer/round generation checks.

The first exported-browser check exposed a bridge issue hidden by JavaScript
unit mocks: Godot discards Callable return values. Native hits therefore did not
confirm browser-side consumption, and diagnostic activation paused the game
without opening its panel. Both paths now use an explicit synchronous response
object. The browser regression exercises the actual native acknowledgement and
checks that a revised consumed occurrence cannot score another live target.

The `?speechDebug=1` panel pauses the native scene and uses the same browser
candidate matcher with an independent, nonexpiring practice target. Native
gameplay callbacks remain isolated throughout practice, including failed
microphone shutdown. Closing resets temporary audio gains and leaves Voice
Pop paused for manual retry. Normal visits add no panel or audio behavior.

## Automated evidence

The focused native suites cover matching, actual scene state, target generation,
real bundled sound gains, paused input/timers, and safe diagnostic exit. The
Node suites exercise real maintained shell functions with mocked browser APIs,
including capture ordering/timeouts, result revisions, span consumption,
bounded reports, clipboard fallback, and safe retries. Exported browser checks
use the real Godot game, with only recognition events simulated.

Verification outputs are recorded locally under `build/speech-ios-*`. These
are integration checks; the simulated transcripts are not an acoustic dataset.
The nine native suites passed 36,100 assertions/checks with no failures:

| Native suite | Passed |
| --- | ---: |
| Voice matching | 1,051 |
| Voice Pop model | 30,317 |
| Voice Pop scene | 1,641 |
| Voice Pop audio | 51 |
| UI audio flow | 213 |
| Match voice feedback | 205 |
| Match groups | 2,531 |
| UI recovery | 60 |
| Three-mode flow | 31 |

The complete Node run passed 248 tests. The release Web export passed pack
verification and produced an 18.07 MB compressed startup download, including
all 350 pronunciations and required game audio. Generated artifacts remain in
`build/web`; no production deployment was performed as part of this check.

All nine diagnostic browser cases passed across desktop Chromium, iPhone
WebKit, and iPad WebKit after correcting the test's audio-capability assumption.
Windows WebKit exposes no WebAudio in this environment, so those profiles
validate flow and layout only. Their test annotations record this limit.
Chromium verifies actual normal/reduced cue playback and silent suppression;
native tests verify the exact 35% gain. Screenshots show readable controls and
reports without horizontal overflow at desktop and phone widths.

Six additional exported-game regressions passed in desktop and Android Chromium
profiles: microphone denial/retry/mode exit, natural recognition endings with
paused countdown and safe restart, and canonical Match homophone scoring with
one hit sound. Together the browser runs cover 15 passing cases.

Reproduction commands:

```powershell
node --test tests/*.test.cjs
npm run build:web
npx playwright test speech-debug.spec.cjs --project=desktop-chromium --project=iphone-webkit --project=ipad-webkit
npx playwright test voice-pop.spec.cjs voice.spec.cjs --grep 'requests permission on entry|natural recognizer ending|Match homophones' --project=desktop-chromium --project=android-chromium
```

## Physical-device comparison protocol

Use the actual affected iPhone/iPad and installed Chrome version. Record the
device, OS, adult/child speaker category, audio output, speaking distance, and
device volume. Open the speech check and run the fixed 24-word list with normal
sounds, reduced sounds, and silence. Repeat with headphones. Alternate the
condition order across speakers to reduce practice-order bias.
Copy each completed 24-word pass before changing conditions; the in-memory
report keeps bounded recent history rather than a permanent study dataset.

Mark the displayed recognition as Correct, Wrong, or No result; count valid
homophones as correct. The raw first candidate, other returned candidates,
and actual game matcher result are separate observations. Use the different-word
and silence controls for false-hit trials. A condition without control trials
has no measured false-hit rate, rather than a zero rate.

Copy the report deliberately when analysis is needed. No audio is recorded or
retained by the diagnostic code, and no report or recognized text is stored persistently
or uploaded by the game. Reports are bounded tab-memory records. Callback
timestamps describe API activity; they cannot establish when a spoken word
ended. The browser recognition service may process speech remotely.

## Limits and release defaults

Physical iPhone/iPad speech accuracy and word-end latency have not been
measured by this implementation run. WebKit emulation verifies code and layout
only. No acoustic accuracy improvement, child-speaker threshold, or latency
target is claimed from passing tests.

The ordinary browser backend, normal game volume, 50-second round, combo
bonuses, first-candidate scoring, and 150 ms observation window remain the
defaults. Diagnostic practice explicitly uses the ordinary browser backend,
even when the independent desktop local experiment is enabled. Alternative
candidates do not grant hits, and no paid service, additional microphone
stream, local model download, or post-drop scoring is introduced.
